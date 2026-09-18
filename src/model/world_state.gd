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
	return w
