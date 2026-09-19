class_name SaveStore
extends RefCounted

static func slot_path(slot: String, base_dir: String) -> String:
	var safe := slot.strip_edges().replace("/", "_").replace("\\", "_").replace(":", "_")
	if safe.is_empty():
		safe = "slot"
	return "%s/%s.json" % [base_dir.rstrip("/"), safe]

static func save(slot: String, world: WorldState, base_dir: String = "user://saves") -> Dictionary:
	var path := slot_path(slot, base_dir)
	var dir := path.get_base_dir()
	var err := DirAccess.make_dir_recursive_absolute(dir)
	if err != OK and err != ERR_ALREADY_EXISTS:
		return {"ok": false, "path": path, "error": "无法创建目录 %s（错误码 %d）" % [dir, err]}
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return {"ok": false, "path": path, "error": "无法写入 %s（错误码 %d）" % [path, FileAccess.get_open_error()]}
	file.store_string(SaveCodec.encode(world))
	file.close()
	return {"ok": true, "path": path, "error": ""}

static func load_slot(slot: String, registry: Registry, base_dir: String = "user://saves") -> Dictionary:
	var path := slot_path(slot, base_dir)
	if not FileAccess.file_exists(path):
		return {"ok": false, "error": "存档不存在：%s" % path, "world": null}
	var text := FileAccess.get_file_as_string(path)
	var result := SaveCodec.decode(text, registry)
	result["path"] = path
	return result

static func list_slots(base_dir: String = "user://saves") -> PackedStringArray:
	var out := PackedStringArray()
	var dir := DirAccess.open(base_dir)
	if dir == null:
		return out
	for file_name in dir.get_files():
		if str(file_name).ends_with(".json"):
			out.append(str(file_name).trim_suffix(".json"))
	out.sort()
	return out

static func delete_slot(slot: String, base_dir: String = "user://saves") -> bool:
	var path := slot_path(slot, base_dir)
	if not FileAccess.file_exists(path):
		return false
	return DirAccess.remove_absolute(path) == OK
