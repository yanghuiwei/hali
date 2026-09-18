class_name RngService
extends RefCounted

var seed_value: int = 0
var _streams: Dictionary = {}

func _init(seed_value_: int = 0) -> void:
	seed_value = seed_value_

func stream(name: String) -> RandomNumberGenerator:
	if not _streams.has(name):
		var rng := RandomNumberGenerator.new()
		rng.seed = hash("%d|%s" % [seed_value, name])
		_streams[name] = rng
	return _streams[name]

func stream_int(name: String, from: int, to: int) -> int:
	return stream(name).randi_range(from, to)

func stream_float(name: String) -> float:
	return stream(name).randf()

func stream_pick(name: String, options: Array):
	if options.is_empty():
		return null
	return options[stream(name).randi_range(0, options.size() - 1)]

func chance(name: String, probability: float) -> bool:
	return stream_float(name) < clampf(probability, 0.0, 1.0)

func state_dict() -> Dictionary:
	# 先物化基础流：保证存档里始终有随机状态可恢复（即使本次回合没有抽过任何随机数）
	stream("world")
	var streams := {}
	for name in _streams.keys():
		var rng: RandomNumberGenerator = _streams[name]
		streams[name] = {"seed": rng.seed, "state": rng.state}
	# seed_value 也必须入档：恢复后新建的命名流要用原种子派生，否则会退回构造时的 seed
	return {"seed_value": seed_value, "streams": streams}

func load_state(d: Dictionary) -> void:
	seed_value = int(d.get("seed_value", seed_value))
	var streams: Dictionary = d.get("streams", {})
	for name in streams.keys():
		var entry: Dictionary = streams[name]
		var rng := RandomNumberGenerator.new()
		rng.seed = int(entry.get("seed", 0))
		rng.state = int(entry.get("state", 0))
		_streams[str(name)] = rng
