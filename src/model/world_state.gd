class_name WorldState
extends RefCounted

const SAVE_VERSION := 1

var registry: Registry = null      # 瞬态：不入存档
var save_version: int = SAVE_VERSION
var game_seed: int = 0
var era_id: String = ""
var clock: GameClock = null
var player: PlayerState = null
var npcs: Dictionary = {}
var factions: Dictionary = {}
var locations: Dictionary = {}
var history: Array = []
var pending: Array = []
var world_vars: Dictionary = {}
var log: Array = []
var flags: Dictionary = {}
var rng_state: Dictionary = {}
var era_start_year: int = 0        # 时代锚点年份，供时间线自检使用

static func create(era_id_: String, player_: PlayerState, seed_: int, registry_: Registry) -> WorldState:
	var w := WorldState.new()
	w.registry = registry_
	w.game_seed = seed_
	w.era_id = era_id_
	w.player = player_
	var era: Dictionary = registry_.entry("eras", era_id_)
	var start_year := int(era.get("start_year", 1991)) if era.get("start_year", null) != null else 1991
	w.era_start_year = start_year
	w.clock = GameClock.from_dict({"year": start_year, "month": 9, "turn": 0})
	# JSON 解析出的整数值 float 必须归一，保证 create 与 from_dict 的内存类型一致（HANDOFF 第 4 节第 1 条）
	w.world_vars = JsonUtil.normalize((era.get("world_vars", {}) as Dictionary).duplicate(true))
	w.player.age_months = maxi(w.player.age_months, 0)
	WorldFactions.initialize(w)
	return w

func era() -> Dictionary:
	return registry.entry("eras", era_id)

func current_location() -> Dictionary:
	return registry.entry("locations", player.location_id)

func add_fact(kind: String, text: String) -> Dictionary:
	var fact := {"kind": kind, "text": text, "turn": clock.turn, "year": clock.year}
	history.append(fact)
	log.append({"turn": clock.turn, "kind": kind, "text": text})
	return fact

const VARS_REGRESSION := 0.05     # 每月向时代基线回归的比例
const MAJOR_EVENT_GAP := 12       # 第六十八章：重大事件之间至少相隔 12 个月
const RECENT_LOG_LIMIT := 200

func sim_style() -> Dictionary:
	var style := registry.entry("sim_styles", player.sim_style_id)
	if style.is_empty():
		style = registry.entry("sim_styles", "mixed")
	return style

func _era_baseline() -> Dictionary:
	var era_entry := era()
	var baseline: Dictionary = era_entry.get("world_vars", {})
	if baseline.is_empty():
		return {"war_pressure": 0.2, "ministry_stability": 0.6, "corruption": 0.3,
			"pureblood_influence": 0.3, "muggle_relations": 0.5,
			"economy_index": 0.6, "secrecy_integrity": 0.8}
	return baseline

# 第四十七章：每个回合（一个月）系统自动结算本月世界动态。
# 玩家不参与，世界照样发展。
func tick() -> Array:
	var events: Array = []
	clock.advance_month()
	# per-turn 语义（第五十五条·魔法体系漏洞保护 / HANDOFF §8 第 27 条裁定）：低阶咒语叠加计数每回合（月）重置；
	# time_rewind_count 为终身一次性，故意不在此重置。
	flags.erase("energy_loop_count")

	# 1) 世界变量向时代基线缓慢回归，并带轻微扰动（第六十四章：权力与秩序是流动的）
	var baseline := _era_baseline()
	var drift_rng := RngService.new(game_seed + clock.turn * 7919)
	for key in world_vars.keys():
		var target := float(baseline.get(key, world_vars[key]))
		var current := float(world_vars[key])
		var noise := drift_rng.stream_float("drift_%s" % key) * 0.04 - 0.02
		world_vars[key] = clampf(current + (target - current) * VARS_REGRESSION + noise, 0.0, 1.0)

	# 2) 本月区级动态：按玩家所在地与身份筛出可得信息（第四十三章：信息由身份、地点、人脉决定）
	var candidates: Array = []
	var last_major_turn := int(flags.get("last_major_turn", -MAJOR_EVENT_GAP))
	var major_ready := (clock.turn - last_major_turn) >= MAJOR_EVENT_GAP
	for rumor_id in registry.ids("rumors"):
		var rumor := registry.entry("rumors", rumor_id)
		if clock.year < int(rumor.get("min_year", 0)):
			continue
		var zones: Array = rumor.get("zones", [])
		if not zones.is_empty() and not zones.has(player.location_id):
			continue
		var ok_flags := true
		for required in rumor.get("requires_flags", []):
			if not flags.has(required):
				ok_flags = false
		if not ok_flags:
			continue
		if bool(rumor.get("major", false)) and not major_ready:
			continue
		candidates.append(rumor)

	var month_rng := RngService.new(game_seed + clock.turn * 104729)
	if not candidates.is_empty():
		var style := sim_style()
		var intensity := clampf(float(style.get("event_intensity", 0.5)), 0.0, 1.0)
		var mundane := clampf(float(style.get("mundane_ratio", 0.7)), 0.0, 1.0)
		var rumor_count := 1
		if month_rng.chance("extra_rumor", 0.35 * intensity):
			rumor_count = 2
		for i in rumor_count:
			var picked: Dictionary = month_rng.stream_pick("pick_%d" % i, candidates)
			if picked.is_empty():
				continue
			var is_major := bool(picked.get("major", false))
			# 只有真正掷中重大事件概率时才落地（第六十八章防过度热闹）
			if is_major:
				var prob := 0.15 * intensity * (1.0 - mundane * 0.5)
				if not month_rng.chance("major_gate", prob):
					continue
				flags["last_major_turn"] = clock.turn
			var ev := {
				"kind": "rumor",
				"category": str(picked.get("category", "")),
				"text": str(picked.get("text", "")),
				"major": is_major,
				"turn": clock.turn,
				"rumor_id": str(picked.get("id", "")),
			}
			events.append(ev)
			log.append(ev)
			if is_major:
				add_fact("major", str(picked.get("text", "")))
				break   # 同月最多一起重大事件，保证 MAJOR_EVENT_GAP 成立

	# 3) 计划 03a：传闻揭示（第四十三/五十七章）——玩家通过传闻获知秘密派系
	WorldFactions.apply_rumor_reveals(self, events)

	# 4) 计划 03a：派系与政治演化（第十二/四十六/四十七/四十九章）
	for political_event in WorldFactions.evolve(self):
		events.append(political_event)
		log.append(political_event)

	# 5) 生活基线：日常必须大量存在（第六十八章），世界不会每个月都在打仗
	var style_now := sim_style()
	var mundane_ratio := clampf(float(style_now.get("mundane_ratio", 0.7)), 0.0, 1.0)
	if month_rng.chance("mundane_day", 0.5 + mundane_ratio * 0.4):
		log.append({"turn": clock.turn, "kind": "mundane",
			"text": "%s，日子照常过。" % clock.formatted()})

	# 6) 年龄推进（玩家与世界同时变老）
	player.age_months += 1

	# 7) 日志裁剪，避免存档无限膨胀
	while log.size() > RECENT_LOG_LIMIT:
		log.pop_front()

	return events

func to_dict() -> Dictionary:
	return JsonUtil.normalize({
		"save_version": save_version,
		"game_seed": game_seed,
		"era_id": era_id,
		"era_start_year": era_start_year,
		"clock": clock.to_dict(),
		"player": player.to_dict(),
		"npcs": npcs, "factions": factions, "locations": locations,
		"history": history, "pending": pending, "world_vars": world_vars,
		"log": log, "flags": flags, "rng_state": rng_state,
	})

static func from_dict(d: Dictionary, registry_: Registry) -> WorldState:
	var w := WorldState.new()
	w.registry = registry_
	w.save_version = int(d.get("save_version", SAVE_VERSION))
	w.game_seed = int(d.get("game_seed", 0))
	w.era_id = str(d.get("era_id", ""))
	w.era_start_year = int(d.get("era_start_year", 0))
	w.clock = GameClock.from_dict(d.get("clock", {}))
	w.player = PlayerState.from_dict(d.get("player", {}))
	w.npcs = JsonUtil.normalize(d.get("npcs", {}))
	w.factions = JsonUtil.normalize(d.get("factions", {}))
	w.locations = JsonUtil.normalize(d.get("locations", {}))
	w.history = JsonUtil.normalize(d.get("history", []))
	w.pending = JsonUtil.normalize(d.get("pending", []))
	w.world_vars = JsonUtil.normalize(d.get("world_vars", {}))
	w.log = JsonUtil.normalize(d.get("log", []))
	w.flags = JsonUtil.normalize(d.get("flags", {}))
	w.rng_state = JsonUtil.normalize(d.get("rng_state", {}))
	# 老存档（无 factions 或只有部分）在此补齐；幂等，不覆盖已存档的值（设计 §9.3/§9.5）
	WorldFactions.initialize(w)
	return w
