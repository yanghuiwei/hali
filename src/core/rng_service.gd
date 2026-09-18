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
	var out := {}
	for name in _streams.keys():
		var rng: RandomNumberGenerator = _streams[name]
		out[name] = {"seed": rng.seed, "state": rng.state}
	return out

func load_state(d: Dictionary) -> void:
	for name in d.keys():
		var entry: Dictionary = d[name]
		var rng := RandomNumberGenerator.new()
		rng.seed = int(entry.get("seed", 0))
		rng.state = int(entry.get("state", 0))
		_streams[str(name)] = rng
