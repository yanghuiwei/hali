class_name GmResponseParser
extends RefCounted

const MAX_NARRATION := 4000
const TAG_WHITELIST: Array[String] = ["train", "work", "social", "rest", "cast", "idle"]

class Result:
	var ok: bool = false
	var error: String = ""
	var narration: String = ""
	var ops: Array = []
	var tags: PackedStringArray = PackedStringArray()

static func parse(text: String) -> Result:
	var out := Result.new()
	var cleaned := _strip_fences(text).strip_edges()
	if cleaned.is_empty():
		out.error = "空响应"
		return out
	var parsed = JSON.parse_string(cleaned)
	if typeof(parsed) != TYPE_DICTIONARY:
		out.error = "响应不是合法 JSON 对象"
		return out
	var d: Dictionary = parsed
	var narration := str(d.get("narration", "")).strip_edges()
	if narration.is_empty():
		out.error = "缺少 narration"
		return out
	if narration.length() > MAX_NARRATION:
		narration = narration.substr(0, MAX_NARRATION)
	var raw_ops = d.get("ops", [])
	if typeof(raw_ops) != TYPE_ARRAY:
		out.error = "ops 不是数组"
		return out
	out.ops = (raw_ops as Array).duplicate(true)
	var raw_tags = d.get("tags", [])
	if typeof(raw_tags) == TYPE_ARRAY:
		for t in (raw_tags as Array):
			var tag := str(t)
			if TAG_WHITELIST.has(tag):
				out.tags.append(tag)
	out.narration = narration
	out.ok = true
	return out

static func _strip_fences(text: String) -> String:
	var t := text.strip_edges()
	if t.begins_with("```"):
		var first_nl := t.find("\n")
		if first_nl >= 0:
			t = t.substr(first_nl + 1)
		if t.ends_with("```"):
			t = t.substr(0, t.length() - 3)
	return t
