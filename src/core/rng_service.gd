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

# 计划 03a（§8#16/#21）：按权重抽取。权重非正（≤0）的条目永不被抽中；权重键缺失时默认 1.0（等价均匀）。
# 总权重为 0（含全部条目权重≤0）时回退到均匀抽取，保证与 stream_pick 同样「总能抽到点什么」。
# ⚠️ 故意**不加**返回类型标注：空列表时本函数返回 null，而 GDScript 对
# 「null 赋给有类型变量」是解析期错误（实测 Cannot assign a value of type "null" as "Dictionary"）。
# 权重键缺失时默认 1.0 ⇒ 传一个表里没有的键名等价于均匀抽取（不要用它假装「权重已生效」）。
func stream_pick_weighted(name: String, entries: Array, weight_key: String = "weight"):
	if entries.is_empty():
		return null
	var total := 0.0
	for e in entries:
		if typeof(e) == TYPE_DICTIONARY:
			total += maxf(float((e as Dictionary).get(weight_key, 1.0)), 0.0)
	if total <= 0.0:
		return stream_pick(name, entries)
	var roll := stream_float(name) * total
	var acc := 0.0
	for e in entries:
		if typeof(e) != TYPE_DICTIONARY:
			continue
		acc += maxf(float((e as Dictionary).get(weight_key, 1.0)), 0.0)
		if roll <= acc:
			return e
	return entries[entries.size() - 1]

func chance(name: String, probability: float) -> bool:
	return stream_float(name) < clampf(probability, 0.0, 1.0)

func state_dict() -> Dictionary:
	# 先物化基础流：保证存档里始终有随机状态可恢复（即使本次回合没有抽过任何随机数）
	stream("world")
	var streams := {}
	for name in _streams.keys():
		var rng: RandomNumberGenerator = _streams[name]
		# seed/state 是 int64，JSON 会把数字解析成 double 而丢精度，因此一律以十进制字符串入档
		streams[name] = {"seed": str(rng.seed), "state": str(rng.state)}
	# seed_value 也必须入档（同样字符串化）：恢复后新建的命名流要用原种子派生
	return {"seed_value": str(seed_value), "streams": streams}

func load_state(d: Dictionary) -> void:
	_streams.clear()   # 恢复语义是“替换”而不是“合并”
	seed_value = int(str(d.get("seed_value", seed_value)))
	var streams: Dictionary = d.get("streams", {})
	for name in streams.keys():
		var entry: Dictionary = streams[name]
		var rng := RandomNumberGenerator.new()
		rng.seed = int(str(entry.get("seed", 0)))
		rng.state = int(str(entry.get("state", 0)))
		_streams[str(name)] = rng
