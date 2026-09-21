class_name SaveCodec
extends RefCounted

const HEADER := "《哈利·波特·魔法纪元·完整人生存档》"
const SAVE_VERSION := 1
const MARKER_PAYLOAD := "payload:"

static func checksum(payload: String) -> String:
	return payload.sha256_text()

# 载荷字段的结构校验：校验和只能证明内容未被改动，不能证明结构合法。
# 若直接把畸形字段交给 WorldState.from_dict，会在类型化赋值处运行期报错；
# 而 decode 的契约是「所有失败路径都返回 ok=false 且 world=null，绝不崩溃」，
# 因此在校验和通过后、from_dict 之前先做一次顶层类型检查（嵌套字段仍由 to_dict 生产者保证）。
static func _validate_payload(parsed: Dictionary) -> String:
	var dict_fields := ["clock", "player", "npcs", "factions", "locations", "world_vars", "flags", "rng_state", "economy"]
	for field in dict_fields:
		if parsed.has(field) and typeof(parsed[field]) != TYPE_DICTIONARY:
			return "存档载荷字段类型错误：%s 应为对象" % field
	var array_fields := ["history", "pending", "log"]
	for field in array_fields:
		if parsed.has(field) and typeof(parsed[field]) != TYPE_ARRAY:
			return "存档载荷字段类型错误：%s 应为数组" % field
	for field in ["save_version", "game_seed", "era_start_year"]:
		if parsed.has(field) and typeof(parsed[field]) != TYPE_FLOAT and typeof(parsed[field]) != TYPE_INT:
			return "存档载荷字段类型错误：%s 应为数字" % field
	if parsed.has("era_id") and typeof(parsed["era_id"]) != TYPE_STRING:
		return "存档载荷字段类型错误：era_id 应为字符串"
	# 计划 03a：player.standing 必须是对象（faction_id -> 整数）
	if parsed.has("player") and typeof(parsed["player"]) == TYPE_DICTIONARY:
		var p: Dictionary = parsed["player"]
		if p.has("standing") and typeof(p["standing"]) != TYPE_DICTIONARY:
			return "存档载荷字段类型错误：player.standing 应为对象"
	return ""

static func encode(world: WorldState) -> String:
	var payload := JSON.stringify(world.to_dict(), "", true, true)
	var lines: Array[String] = []
	lines.append("%s v%d" % [HEADER, SAVE_VERSION])
	lines.append("checksum: %s" % checksum(payload))
	lines.append(MARKER_PAYLOAD)
	lines.append(payload)
	return "\n".join(lines)

static func decode(text: String, registry: Registry) -> Dictionary:
	var fail := func(message: String) -> Dictionary:
		return {"ok": false, "error": message, "world": null}

	var lines := text.strip_edges().split("\n")
	if lines.size() < 4:
		return fail.call("存档格式错误：内容过短，缺少标题或载荷")
	var head := str(lines[0]).strip_edges()
	if not head.begins_with(HEADER):
		return fail.call("存档格式错误：缺少标题 %s" % HEADER)
	var version_part := head.substr(HEADER.length()).strip_edges()
	if version_part != "v%d" % SAVE_VERSION:
		return fail.call("存档版本不符：期望 v%d，实际 %s" % [SAVE_VERSION, version_part])
	var checksum_line := str(lines[1]).strip_edges()
	if not checksum_line.begins_with("checksum:"):
		return fail.call("存档格式错误：缺少校验和行")
	var expected := checksum_line.substr("checksum:".length()).strip_edges()
	if str(lines[2]).strip_edges() != MARKER_PAYLOAD:
		return fail.call("存档格式错误：缺少 %s 标记" % MARKER_PAYLOAD)

	var payload_lines: Array[String] = []
	for i in range(3, lines.size()):
		payload_lines.append(str(lines[i]))
	var payload := "\n".join(payload_lines).strip_edges()
	if checksum(payload) != expected:
		return fail.call("存档校验失败：内容已被修改")

	var parsed = JSON.parse_string(payload)
	if typeof(parsed) != TYPE_DICTIONARY:
		return fail.call("存档校验失败：载荷不是合法 JSON")

	# 先做结构校验，再读取 save_version：否则 {"save_version":null} 会在 int() 处运行期报错，
	# 使 decode 无法走 fail 路径（返回类型退化），违反「所有失败路径 ok=false」契约。
	var malformed := _validate_payload(parsed as Dictionary)
	if not malformed.is_empty():
		return fail.call(malformed)
	var version := int((parsed as Dictionary).get("save_version", -1))
	if version != SAVE_VERSION:
		return fail.call("存档版本不符：载荷版本 %d" % version)

	# from_dict 内部依赖类型化赋值，嵌套畸形会让子对象为 null（毒对象）；此处兜底为失败。
	var world := WorldState.from_dict(parsed, registry)
	if world == null or world.player == null or world.clock == null:
		return fail.call("存档载荷结构不完整：无法重建完整的世界状态")
	return {"ok": true, "error": "", "world": world}
