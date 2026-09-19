class_name SaveCodec
extends RefCounted

const HEADER := "《哈利·波特·魔法纪元·完整人生存档》"
const SAVE_VERSION := 1
const MARKER_PAYLOAD := "payload:"

static func checksum(payload: String) -> String:
	return payload.sha256_text()

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

	var version := int((parsed as Dictionary).get("save_version", -1))
	if version != SAVE_VERSION:
		return fail.call("存档版本不符：载荷版本 %d" % version)

	return {"ok": true, "error": "", "world": WorldState.from_dict(parsed, registry)}
