class_name JsonUtil
extends RefCounted

# JSON 没有 int/float 之分，解析回来全是 float；而 Godot 的 Dictionary 深比较是类型严格的。
# 因此存档往返（to_dict → JSON → from_dict → to_dict）必须先把整数值的 float 归一为 int。
static func normalize(value):
	match typeof(value):
		TYPE_FLOAT:
			var f := float(value)
			if is_finite(f) and f == floor(f) and absf(f) < 9007199254740992.0:
				return int(f)
			return f
		TYPE_DICTIONARY:
			var out := {}
			for key in (value as Dictionary).keys():
				out[key] = normalize(value[key])
			return out
		TYPE_ARRAY:
			var arr := []
			for item in (value as Array):
				arr.append(normalize(item))
			return arr
		_:
			return value
