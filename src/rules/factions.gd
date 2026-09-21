class_name WorldFactions
extends RefCounted

# 机构 id 枚举：顺序即势力面板的展示顺序（第六十五章）。代码只硬编码 id，中文标签进 data/factions.json 的 institutions。
const INSTITUTIONS: Array[String] = ["law_enforcement", "auror_office", "wizengamot", "mysteries",
	"hogwarts", "gringotts", "daily_prophet", "international"]

# 派系类别枚举（第十二章权力四角 + 第六/二十六章）
const KINDS: Array[String] = ["ministry", "institution", "pureblood", "school", "commerce",
	"media", "resistance", "dark", "foreign", "society"]
const LEGAL_STATUS: Array[String] = ["legal", "shadow", "outlaw"]
const SECRECY: Array[String] = ["public", "semi", "secret"]

# kind → 权力四角（第十二章）。不在表里的 kind（resistance/dark/foreign/society）不进四角，
# 它们通过 control 与政体判定体现影响力。
const CORNERS: Dictionary = {
	"ministry": ["ministry", "institution"],
	"pureblood": ["pureblood"],
	"hogwarts": ["school"],
	"commerce": ["commerce", "media"],
}

const MINISTRY_ID := "ministry"
const RESISTANCE_ID := "order_of_phoenix"

# 状态键（都存在既有容器里：tension 进 world.flags，政体进 world.flags，派系状态进 world.factions）
const TENSION_FLAG := "social_tension"
const GOVERNMENT_FLAG := "government_type"

# domains 白名单（Task 1 审查 Minor 收口：domains 此前零消费零校验，写错没有任何测试会失败）
const DOMAINS: Array[String] = ["law", "administration", "education", "economy", "media",
	"secrecy_enforcement", "warfare", "intelligence"]

# ---------- 内容校验（枚举 + 引用完整性 + 字段类型；registry.validate 只管字段与值域，避免反向依赖） ----------

static func validate_content(registry: Registry) -> PackedStringArray:
	var errors := PackedStringArray()
	for fid in registry.ids("factions"):
		var id := str(fid)
		var e := registry.entry("factions", id)
		if not e.has("institutions"):
			errors.append("factions/%s: institutions 缺失" % id)
		elif typeof(e["institutions"]) != TYPE_ARRAY:
			errors.append("factions/%s: institutions 必须是数组" % id)
		else:
			for inst in (e["institutions"] as Array):
				if not INSTITUTIONS.has(str(inst)):
					errors.append("factions/%s: 机构非法（%s）" % [id, str(inst)])
		for field in ["rivals", "allies"]:
			if not e.has(field):
				errors.append("factions/%s: %s 缺失" % [id, field])
			elif typeof(e[field]) != TYPE_ARRAY:
				errors.append("factions/%s: %s 必须是数组" % [id, field])
			else:
				for other in (e[field] as Array):
					if not registry.has("factions", str(other)):
						errors.append("factions/%s: %s 引用不存在的派系（%s）" % [id, field, str(other)])
		if not e.has("era_overrides"):
			errors.append("factions/%s: era_overrides 缺失" % id)
		elif typeof(e["era_overrides"]) != TYPE_DICTIONARY:
			errors.append("factions/%s: era_overrides 必须是 Dictionary" % id)
		else:
			for era_id in (e["era_overrides"] as Dictionary).keys():
				if not registry.has("eras", str(era_id)):
					errors.append("factions/%s: era_overrides 引用不存在的时代（%s）" % [id, str(era_id)])
		if not e.has("domains"):
			errors.append("factions/%s: domains 缺失" % id)
		elif typeof(e["domains"]) != TYPE_ARRAY:
			errors.append("factions/%s: domains 必须是数组" % id)
		else:
			for domain in (e["domains"] as Array):
				if not DOMAINS.has(str(domain)):
					errors.append("factions/%s: domain 非法（%s）" % [id, str(domain)])
		if not e.has("aliases"):
			errors.append("factions/%s: aliases 缺失" % id)
		elif typeof(e["aliases"]) != TYPE_ARRAY:
			errors.append("factions/%s: aliases 必须是数组" % id)
		elif (e["aliases"] as Array).is_empty():
			errors.append("factions/%s: aliases 为空" % id)
		else:
			for alias in (e["aliases"] as Array):
				if str(alias).strip_edges().is_empty():
					errors.append("factions/%s: alias 为空（第 %d 项）" % [id, (e["aliases"] as Array).find(alias)])
		if not e.has("base_power"):
			errors.append("factions/%s: base_power 缺失" % id)
		elif typeof(e["base_power"]) != TYPE_INT and typeof(e["base_power"]) != TYPE_FLOAT:
			errors.append("factions/%s: base_power 类型非法（%s）" % [id, str(e["base_power"])])
	for rid in registry.ids("rumors"):
		var target := str(registry.entry("rumors", str(rid)).get("reveals_faction", ""))
		if not target.is_empty() and not registry.has("factions", target):
			errors.append("rumors/%s: reveals_faction 引用不存在的派系（%s）" % [str(rid), target])
	return errors

# ---------- 初始化与读取 ----------

# 幂等：只为「还没有状态」的派系建状态；旧存档/已演化的值一律不动。
# clock 为 null 时直接返回：畸形载荷的负例路径（save_test 的毒对象用例）会让 `GameClock.from_dict` 失败并留下 null clock，
# 此时不能再去读 `clock.turn`（会往 stderr 喷 17 条 SCRIPT ERROR）。
static func initialize(world: WorldState) -> void:
	if world == null or world.registry == null or world.clock == null:
		return
	if typeof(world.factions) != TYPE_DICTIONARY:
		world.factions = {}
	for fid in world.registry.ids("factions"):
		ensure_state(world, str(fid))

static func entry_of(world: WorldState, faction_id: String) -> Dictionary:
	return world.registry.entry("factions", faction_id)

static func base_power(world: WorldState, faction_id: String) -> float:
	var entry := entry_of(world, faction_id)
	var p := float(entry.get("base_power", 0.0))
	var overrides = entry.get("era_overrides", {})
	if typeof(overrides) == TYPE_DICTIONARY and (overrides as Dictionary).has(world.era_id):
		var o = (overrides as Dictionary)[world.era_id]
		if typeof(o) == TYPE_DICTIONARY and (o as Dictionary).has("base_power"):
			p = float((o as Dictionary)["base_power"])
	return clampf(p, 0.0, 1.0)

static func ensure_state(world: WorldState, faction_id: String) -> Dictionary:
	if typeof(world.factions) != TYPE_DICTIONARY:
		world.factions = {}
	var existing = world.factions.get(faction_id, null)
	if typeof(existing) == TYPE_DICTIONARY:
		return existing
	var entry := entry_of(world, faction_id)
	if entry.is_empty():
		return {}
	var power := base_power(world, faction_id)
	var control := {}
	for inst in (entry.get("institutions", []) as Array):
		control[str(inst)] = power
	var st := {
		"power": power,
		"control": control,
		"stance_to_player": 0,
		"revealed": str(entry.get("secrecy", "public")) == "public",
		"last_change_turn": world.clock.turn if world.clock != null else 0,
		"notes": [],
	}
	world.factions[faction_id] = st
	return st

static func state_of(world: WorldState, faction_id: String) -> Dictionary:
	if typeof(world.factions) != TYPE_DICTIONARY:
		return {}
	var st = world.factions.get(faction_id, null)
	return st if typeof(st) == TYPE_DICTIONARY else {}

static func power_of(world: WorldState, faction_id: String) -> float:
	return clampf(float(state_of(world, faction_id).get("power", 0.0)), 0.0, 1.0)

# 信息保护（第四十三/五十七章）：只有 revealed 的派系对玩家可见。
# 调用方注意：`PackedStringArray == Array` 是解析期错误，只能用 `.has(x)` 判断。
static func visible_faction_ids(world: WorldState) -> PackedStringArray:
	var out := PackedStringArray()
	for fid in world.registry.ids("factions"):
		if bool(state_of(world, str(fid)).get("revealed", false)):
			out.append(str(fid))
	return out

# ---------- 权力四角（第十二章） ----------

static func power_share(world: WorldState) -> Dictionary:
	var totals := {"ministry": 0.0, "pureblood": 0.0, "hogwarts": 0.0, "commerce": 0.0}
	for fid in world.registry.ids("factions"):
		var kind := str(entry_of(world, str(fid)).get("kind", ""))
		for corner in CORNERS.keys():
			if (CORNERS[corner] as Array).has(kind):
				totals[corner] = float(totals[corner]) + power_of(world, str(fid))
	var sum := 0.0
	for key in totals.keys():
		sum += float(totals[key])
	if sum <= 0.0:
		return {"ministry": 0.25, "pureblood": 0.25, "hogwarts": 0.25, "commerce": 0.25}
	var out := {}
	for key in totals.keys():
		out[key] = float(totals[key]) / sum
	return out

# ---------- 机构控制权（第二十六章） ----------

static func institution_control(world: WorldState) -> Dictionary:
	var out := {}
	for inst in INSTITUTIONS:
		out[inst] = {"value": 0.0, "holder": ""}
	for fid in world.registry.ids("factions"):
		var id := str(fid)
		var control = state_of(world, id).get("control", {})
		if typeof(control) != TYPE_DICTIONARY:
			continue
		for inst in (control as Dictionary).keys():
			if not out.has(str(inst)):
				continue
			var value := clampf(float((control as Dictionary)[inst]), 0.0, 1.0)
			var current: Dictionary = out[str(inst)]
			var better := value > float(current["value"])
			if is_equal_approx(value, float(current["value"])):
				better = power_of(world, id) > power_of(world, str(current["holder"]))
			if better:
				out[str(inst)] = {"value": value, "holder": id}
	return out

# ---------- 月度演化（第十二/四十六/四十七/四十九章） ----------

const EVOLVE_REGRESSION := 0.04   # 每月向「目标实力」回归的比例
const EVOLVE_NOISE := 0.02        # ±0.02 扰动（单侧幅值）
const SUPPRESS_RATE := 0.03       # 敌对压制：每月按实力差比例削弱败者
const SUPPRESS_FLOOR := 0.05      # 弱者实力的绝对下限（不会被压到 0）

# 计划 01 Task 10 的设计不变量是「存档往返逐字一致」。但 Godot 的 JSON 对 17 位有效数字的 double
# **不保证逐位往返**（实测：内存 0.21739610501640022 → 存盘文本逐字正确 → 解析回 0.21739610501640025），
# 而回归+噪声产生的连续浮点恰好都是这种「长尾」值——会让 save_test 的整字典相等断言变红（§8#50 的新触发面）。
# 量化到 4 位小数后，文本短、往返稳定，且 4 位小数远超玩法精度需求（面板只显示 2 位）。
const QUANTIZE_DECIMALS := 4

static func quantize(value: float) -> float:
	var factor := pow(10.0, float(QUANTIZE_DECIMALS))
	return round(value * factor) / factor

# 把演化产生的一切对外持久化数值定量化（幂等）：power / control / tension。
static func quantize_state(world: WorldState) -> void:
	for fid in world.registry.ids("factions"):
		var st := state_of(world, str(fid))
		if st.is_empty():
			continue
		st["power"] = clampf(quantize(float(st.get("power", 0.0))), 0.0, 1.0)
		var control: Dictionary = st.get("control", {})
		for inst in control.keys():
			control[inst] = clampf(quantize(float(control[inst])), 0.0, 1.0)

# 结构性拉力：世界变量如何推动某类派系（正典第十二/十七/四十九章的定性关系）
static func structure_pull(world: WorldState, faction_id: String) -> float:
	var kind := str(entry_of(world, faction_id).get("kind", ""))
	var v := world.world_vars
	match kind:
		"ministry":
			return float(v.get("ministry_stability", 0.5)) * 0.10 - float(v.get("corruption", 0.3)) * 0.20
		"institution":
			return float(v.get("ministry_stability", 0.5)) * 0.05
		"pureblood":
			return float(v.get("pureblood_influence", 0.3)) * 0.15
		"dark":
			return float(v.get("war_pressure", 0.2)) * 0.30 + float(v.get("corruption", 0.3)) * 0.10
		"resistance":
			return float(v.get("war_pressure", 0.2)) * 0.25
		"commerce", "media":
			return (float(v.get("economy_index", 0.6)) - 0.5) * 0.20
		"foreign":
			return float(v.get("muggle_relations", 0.5)) * 0.10
		"school":
			return float(v.get("secrecy_integrity", 0.8)) * 0.10
		_:
			return 0.0

# 敌对压制：对每一对 rivals 只处理一次（**无向对**语义，与哪一方声明无关），强者压低弱者、自己小幅获益。
# 注意：内容表的 `rivals` 是**非对称**的（黑市视傲罗为敌，傲罗的主要敌人却是食死徒），
# 因此去重必须按「无向对键」——用 `oid <= id` 会把「只有字典序较大的一方声明」的敌对对静默丢弃
# （实测 11 个已声明敌对对中有 5 个被丢，见 Task 4 审查 I1）。
static func apply_rival_pressure(world: WorldState) -> void:
	var seen: Dictionary = {}
	for fid in world.registry.ids("factions"):
		var id := str(fid)
		var rivals_raw = entry_of(world, id).get("rivals", [])
		if typeof(rivals_raw) != TYPE_ARRAY:
			continue
		for other in (rivals_raw as Array):
			var oid := str(other)
			if oid.is_empty() or oid == id:
				continue
			var pair_key := id + "|" + oid if id < oid else oid + "|" + id
			if seen.has(pair_key):
				continue
			seen[pair_key] = true
			var pa := power_of(world, id)
			var pb := power_of(world, oid)
			if is_equal_approx(pa, pb):
				continue
			var winner := id if pa > pb else oid
			var loser := oid if pa > pb else id
			var gap := absf(pa - pb)
			var loser_state := ensure_state(world, loser)
			if not loser_state.is_empty():
				var floor := maxf(SUPPRESS_FLOOR, base_power(world, loser) * 0.25)
				loser_state["power"] = clampf(float(loser_state["power"]) - SUPPRESS_RATE * gap, floor, 1.0)
			var winner_state := ensure_state(world, winner)
			if not winner_state.is_empty():
				winner_state["power"] = clampf(float(winner_state["power"]) + SUPPRESS_RATE * gap * 0.5, 0.0, 1.0)

# 单回合演化：就地更新 world.factions / world.flags，返回事件数组（结构与 tick 的 events 一致）。
# 随机数全部走命名流，保证同 seed + 同回合 ⇒ 同结果。
static func evolve(world: WorldState) -> Array:
	# M3（Task 4 审查修复轮 1）：与 initialize() 同样早退——否则紧接着的 world.clock.turn 会在
	# 裸世界 / 畸形载荷（registry 或 clock 为 null）上直接崩。
	if world == null or world.registry == null or world.clock == null:
		return []
	initialize(world)
	var rng := RngService.new(world.game_seed + world.clock.turn * 31337)
	# M2（修复轮 1）：先快照本回合开始时的**量化持久值**，等本回合所有写入（回归、敌对压制、量化）
	# 都做完后再统一判定「持久值是否真的变了」。若在回归循环里就地判定，会出现两类不自洽：
	# ① 用未量化的 next 判定 → 持久值没变却标记变化；② 敌对压制把值改回来后标记与实际不符。
	var power_before: Dictionary = {}
	for fid in world.registry.ids("factions"):
		power_before[str(fid)] = quantize(power_of(world, str(fid)))
	for fid in world.registry.ids("factions"):
		var id := str(fid)
		var st := ensure_state(world, id)
		if st.is_empty():
			continue
		var target := clampf(base_power(world, id) + structure_pull(world, id), 0.0, 1.0)
		var current := clampf(float(st.get("power", target)), 0.0, 1.0)
		var noise := rng.stream_float("faction_%s" % id) * (EVOLVE_NOISE * 2.0) - EVOLVE_NOISE
		var next := clampf(current + (target - current) * EVOLVE_REGRESSION + noise, 0.0, 1.0)
		var nq := clampf(quantize(next), 0.0, 1.0)
		st["power"] = nq
		var control: Dictionary = st.get("control", {})
		for inst in control.keys():
			control[inst] = clampf(float(control[inst]) + (nq - float(control[inst])) * 0.5, 0.0, 1.0)
	apply_rival_pressure(world)
	quantize_state(world)
	# 统一判定（M2）：本回合所有写入都结束后，只有「量化持久值真的变了」的派系才标记本月变化。
	for fid in world.registry.ids("factions"):
		var mark_id := str(fid)
		var mark_state := state_of(world, mark_id)
		if mark_state.is_empty():
			continue
		if not is_equal_approx(quantize(float(mark_state.get("power", 0.0))), float(power_before.get(mark_id, 0.0))):
			mark_state["last_change_turn"] = world.clock.turn
	world.flags[GOVERNMENT_FLAG] = government_type(world)
	world.flags[TENSION_FLAG] = quantize(compute_tension(world))
	var events: Array = []
	var picked := pick_political_event(world)
	if not picked.is_empty():
		events.append(picked)
	return events

# ---------- 社会矛盾与政治事件（第四十六/四十九/六十八章） ----------

const TENSION_THRESHOLD := 0.55

# 社会矛盾：腐败、纯血垄断、保密法紧张、战争、经济衰退、四角失衡共同累积（正典第四十九章）
static func compute_tension(world: WorldState) -> float:
	var v := world.world_vars
	var corruption := float(v.get("corruption", 0.3))
	var pureblood := float(v.get("pureblood_influence", 0.3))
	var muggle := float(v.get("muggle_relations", 0.5))
	var war := float(v.get("war_pressure", 0.2))
	var economy := float(v.get("economy_index", 0.6))
	var secrecy := float(v.get("secrecy_integrity", 0.8))
	var raw := corruption * 0.25 + pureblood * 0.20 + (1.0 - muggle) * 0.15 \
		+ war * 0.20 + (1.0 - economy) * 0.15 + (1.0 - secrecy) * 0.05
	var share := power_share(world)
	var top := 0.0
	for key in share.keys():
		top = maxf(top, float(share[key]))
	raw += clampf((top - 0.25) * 0.5, 0.0, 0.25)
	return clampf(raw, 0.0, 1.0)

static func tension_of(world: WorldState) -> float:
	if world.flags.has(TENSION_FLAG):
		return clampf(float(world.flags[TENSION_FLAG]), 0.0, 1.0)
	return compute_tension(world)

# 事件条件：代码判定，文案在 data/political_events.json（内容进 data）
static func event_condition_met(world: WorldState, condition: String) -> bool:
	var v := world.world_vars
	match condition:
		"economic_slump":
			# ⚠️ 阈值只有一个来源：Economy.CRISIS_THRESHOLD（计划 03b Global Constraint）。
			# 不要在这里写 0.35 字面量 —— 调阈值时漏改一处会出现「物价已断供但派系层认为没危机」的静默不一致。
			return float(v.get("economy_index", 0.6)) <= Economy.CRISIS_THRESHOLD
		"oligarchy_pressure":
			return float(power_share(world).get("pureblood", 0.0)) >= 0.26 \
				or float(v.get("pureblood_influence", 0.3)) >= 0.65
		"lawlessness":
			return float(v.get("corruption", 0.3)) >= 0.65 \
				or government_type(world) == "death_eater_dictatorship"
		"war_exhaustion":
			return float(v.get("war_pressure", 0.2)) >= 0.65
		"secrecy_crisis":
			return float(v.get("secrecy_integrity", 0.8)) <= 0.30
		_:
			return false

# 选举本月政治事件：必须同时满足「tension 过阈」「条件成立」「重大事件配额可用」（第六十八章）。
# 注意：本函数有副作用（命中时写 history 并占用 last_major_turn 配额），不是纯查询；请勿用于预览/面板。
static func pick_political_event(world: WorldState) -> Dictionary:
	if tension_of(world) < TENSION_THRESHOLD:
		return {}
	var last_major := int(world.flags.get("last_major_turn", -WorldState.MAJOR_EVENT_GAP))
	if world.clock.turn - last_major < WorldState.MAJOR_EVENT_GAP:
		return {}
	var candidates: Array = []
	for eid in world.registry.ids("political_events"):
		var entry := world.registry.entry("political_events", str(eid))
		if event_condition_met(world, str(entry.get("condition", ""))):
			candidates.append(entry)
	if candidates.is_empty():
		return {}
	var rng := RngService.new(world.game_seed + world.clock.turn * 524287)
	var picked: Dictionary = rng.stream_pick("political_event", candidates)
	if picked.is_empty():
		return {}
	world.flags["last_major_turn"] = world.clock.turn
	var ev := {
		"kind": "faction",
		"category": str(picked.get("category", "politics")),
		"text": str(picked.get("text", "")),
		"major": bool(picked.get("major", true)),
		"turn": world.clock.turn,
		"event_id": str(picked.get("id", "")),
	}
	world.add_fact("major", str(picked.get("text", "")))
	return ev

# 揭示一个派系。约束：来源必须非空且不是 system（与 StateOps.know_fact 同源，第四十三/五十七章）。
# 已揭示时返回 false（幂等），调用方可据此跳过重复叙事。
static func reveal(world: WorldState, faction_id: String, source: String) -> bool:
	# 对外 API（Task 7/8 的面板与提示词也会调）：畸形存档（null registry/clock）不得崩，与 initialize/evolve 同口径早退。
	if world == null or world.registry == null or world.clock == null:
		return false
	var src := source.strip_edges()
	if src.is_empty() or src == "system":
		return false
	if not world.registry.has("factions", faction_id):
		return false
	var st := ensure_state(world, faction_id)
	if st.is_empty() or bool(st.get("revealed", false)):
		return false
	st["revealed"] = true
	# ⚠️ **不写** `last_change_turn`：该字段的语义严格定义为「**power 变更回合**」（Task 4/5 的统一判定所写）。
	# 揭示是另一种变化，由 `revealed` 布尔本身表达；若这里也写该字段，Task 5 的不变量
	# 「`last_change_turn == clock.turn` ⟺ 量化持久值本回合变化」会在「被揭示但当月 power 恰好没变」时变红
	# （Task 6 审查 Minor 1，2026-09-20 控制器裁定：字段语义单一化，不给揭示再记一个回合）。
	world.add_fact("faction_revealed", "你得知了「%s」的存在（来源：%s）。" % [
		str(entry_of(world, faction_id).get("label", faction_id)), src])
	return true

# 传闻揭示（第四十三/五十七章）：内容表里带 reveals_faction 的传闻被玩家听到时，该派系转为已知。
# 事件由 WorldState.tick() 的传闻阶段产出，字典里带 "rumor_id"；无效/无指向的事件直接跳过。
static func apply_rumor_reveals(world: WorldState, events: Array) -> void:
	for ev in events:
		if typeof(ev) != TYPE_DICTIONARY:
			continue
		var rumor_id := str((ev as Dictionary).get("rumor_id", ""))
		if rumor_id.is_empty():
			continue
		var entry := world.registry.entry("rumors", rumor_id)
		var target := str(entry.get("reveals_faction", ""))
		if target.is_empty():
			continue
		reveal(world, target, "传闻：%s" % str((ev as Dictionary).get("category", "街谈巷议")))

# ---------- 政体推导（第十一章 + 第十二章） ----------

# 计划 03a Task 11（Task 8 审查 M5）：政体 id 的**唯一取法**——缓存优先、无缓存（空串）现算。
# 面板与提示词原本各抄一份这 3 行（DRY 破损，改一处容易漏另一处）。
static func government_id(world: WorldState) -> String:
	var cached := str(world.flags.get(GOVERNMENT_FLAG, ""))
	if not cached.is_empty():
		return cached
	return government_type(world)

static func government_type(world: WorldState) -> String:
	# 1) 凤凰社抵抗：战争压力高 + 抵抗组织强于魔法部（第十一章第 4 条）
	if float(world.world_vars.get("war_pressure", 0.0)) >= 0.6 \
			and power_of(world, RESISTANCE_ID) > power_of(world, MINISTRY_ID):
		return "order_resistance"
	# 2) 食死徒独裁：黑暗势力掌握执法与司法（第十一章第 3 条）
	# 缺失键按 0 计（Task 2 审查 Minor 1）：旧实现回退到「全局归并持有值」，会把「非黑暗派系控制执法司」
	# 算成黑暗势力的控制权，与 institution_control() 的「未声明=不参与」语义矛盾。
	var dark_sum := 0.0
	var dark_count := 0
	for fid in world.registry.ids("factions"):
		var id := str(fid)
		if str(entry_of(world, id).get("kind", "")) != "dark":
			continue
		var control: Dictionary = state_of(world, id).get("control", {})
		for inst in ["law_enforcement", "wizengamot"]:
			dark_sum += clampf(float(control.get(inst, 0.0)), 0.0, 1.0)
			dark_count += 1
	if dark_count > 0 and (dark_sum / float(dark_count)) >= 0.6:
		return "death_eater_dictatorship"
	# 3) 纯血寡头：纯血权重高 + 魔法部弱（第十一章第 2 条）
	# 阈值 0.28：四角归一化下单角现实上限约 1/3（构造用例 0.3010、理论上限 0.3017、默认 0.1627）；原稿 0.45 不可达，见 spec §13.2 勘误（人类裁定 A，2026-09-20）。
	if float(power_share(world).get("pureblood", 0.0)) >= 0.28 and power_of(world, MINISTRY_ID) < 0.5:
		return "pureblood_oligarchy"
	# 4) 默认：官僚制（第十一章第 1 条）
	return "ministry_bureaucracy"
