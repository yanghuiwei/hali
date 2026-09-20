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

# 计划 03a（§8#16/#21）：按权重抽取。
# 契约：
#   ① 权重 ≤ 0 的条目**永不被抽中**（加权路径里跳过；也不会成为兜底返回）；
#   ② 权重键缺失 ⇒ 默认 1.0（等价均匀）；
#   ③ 非字典条目在**加权路径**被跳过；但总权重为 0 时会**整体回退** stream_pick ⇒ 此时非字典条目**可**被抽中。
#      这个不对称是「全零 = 退化到旧行为」的有意语义，**不是 bug**；
#   ④ 空表返回 null。
# ⚠️ 故意**不加**返回类型标注：空表返回 null，而 GDScript 对「可空返回值赋给有类型变量」是**运行期** SCRIPT ERROR
#    （实测 Trying to assign value of type 'Nil' to a variable of type 'Dictionary'），而且会**中止所在函数**。
func stream_pick_weighted(name: String, entries: Array, weight_key: String = "weight"):
	if entries.is_empty():
		return null
	var total := 0.0
	for e in entries:
		if typeof(e) == TYPE_DICTIONARY:
			total += _weight_of(e, weight_key)
	if total <= 0.0:
		return stream_pick(name, entries)
	# 用 `<` 而不是 `<=`，并跳过非正权重：否则「roll == 0.0 且首条权重为 0」会返回一条权重 0 的条目（违反契约 ①）
	return _pick_by_roll(entries, weight_key, stream_float(name) * total)

static func _weight_of(e: Variant, weight_key: String) -> float:
	return maxf(float((e as Dictionary).get(weight_key, 1.0)), 0.0)

# 把「按 roll 落区间」抽成独立私有函数，**唯一目的是让 roll == 0.0 这条边界可判别地被测到**：
# randf() 精确返回 0.0 的概率 ≈ 2^-32，黑盒永远测不出来；直接传 roll 就能测。
static func _pick_by_roll(entries: Array, weight_key: String, roll: float):
	var acc := 0.0
	var last_positive: Variant = null
	for e in entries:
		if typeof(e) != TYPE_DICTIONARY:
			continue
		var w := _weight_of(e, weight_key)
		if w <= 0.0:
			continue
		last_positive = e
		acc += w
		if roll < acc:
			return e
	# 浮点累加误差可能让所有区间都落空（roll 理论上 < total）⇒ 兜底也必须是**正权重**条目
	if last_positive != null:
		return last_positive
	return null

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
