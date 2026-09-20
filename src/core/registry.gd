class_name Registry
extends RefCounted

const TABLE_FILES: Dictionary = {
	"eras": "eras.json",
	"factions": "factions.json",
	"governments": "governments.json",
	"bloodlines": "bloodlines.json",
	"birth_identities": "birth_identities.json",
	"aptitudes": "aptitudes.json",
	"houses": "houses.json",
	"sim_styles": "sim_styles.json",
	"political_leanings": "political_leanings.json",
	"locations": "locations.json",
	"rumors": "rumors.json",
	"political_events": "political_events.json",
	"skills": "skills.json",
	"wand_woods": "wand_woods.json",
	"wand_cores": "wand_cores.json",
	"wand_flexibilities": "wand_flexibilities.json",
	"wand_lengths": "wand_lengths.json",
	"spells": "spells.json",
}

var duplicate_ids: PackedStringArray = PackedStringArray()
var _tables: Dictionary = {}

static func from_tables(tables: Dictionary) -> Registry:
	var r := Registry.new()
	for table_name in tables.keys():
		var index := {}
		var entries = tables[table_name]
		if typeof(entries) != TYPE_ARRAY:
			continue
		for entry in entries:
			if typeof(entry) != TYPE_DICTIONARY:
				continue
			var key := str(entry.get("id", ""))
			if index.has(key):
				r.duplicate_ids.append("%s/%s" % [table_name, key])
			index[key] = entry
		r._tables[table_name] = index
	return r

static func load_default() -> Registry:
	var tables := {}
	for table_name in TABLE_FILES.keys():
		var path := "res://data/%s" % TABLE_FILES[table_name]
		var raw := FileAccess.get_file_as_string(path)
		var parsed = JSON.parse_string(raw)
		tables[table_name] = parsed if typeof(parsed) == TYPE_ARRAY else []
	return from_tables(tables)

func entry(table_name: String, id: String) -> Dictionary:
	var index: Dictionary = _tables.get(table_name, {})
	if not index.has(id):
		return {}
	return index[id]

func has(table_name: String, id: String) -> bool:
	return (_tables.get(table_name, {}) as Dictionary).has(id)

func ids(table_name: String) -> PackedStringArray:
	var out := PackedStringArray()
	for key in (_tables.get(table_name, {}) as Dictionary).keys():
		out.append(str(key))
	out.sort()
	return out

func table_dict(table_name: String) -> Dictionary:
	return _tables.get(table_name, {})

func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	for dup in duplicate_ids:
		errors.append("重复 id: %s" % dup)
	for table_name in TABLE_FILES.keys():
		if not _tables.has(table_name):
			errors.append("缺少数据表: %s" % table_name)
			continue
		var index: Dictionary = _tables[table_name]
		if index.is_empty():
			errors.append("数据表为空: %s" % table_name)
			continue
		for key in index.keys():
			if str(key).is_empty():
				errors.append("%s: 存在空 id 条目" % table_name)
			var e: Dictionary = index[key]
			if str(e.get("label", "")).is_empty():
				errors.append("%s/%s: 缺少 label" % [table_name, key])
			errors.append_array(_validate_entry(table_name, str(key), e))
	return errors

# 计划 03a：按表做字段级校验（枚举与引用完整性由 WorldFactions.validate_content 负责，
# 这里只保证「字段存在且类型/值域合法」，避免 registry 反向依赖 rules 层造成类循环）。
const _KINDS := ["ministry", "institution", "pureblood", "school", "commerce", "media",
	"resistance", "dark", "foreign", "society"]
const _LEGAL := ["legal", "shadow", "outlaw"]
const _SECRECY := ["public", "semi", "secret"]
const _INSTITUTIONS := ["law_enforcement", "auror_office", "wizengamot", "mysteries",
	"hogwarts", "gringotts", "daily_prophet", "international"]

func _validate_entry(table_name: String, key: String, e: Dictionary) -> PackedStringArray:
	var errors := PackedStringArray()
	var where := "%s/%s" % [table_name, key]
	if table_name == "factions":
		var kind := str(e.get("kind", ""))
		if not _KINDS.has(kind):
			errors.append("%s: kind 非法（%s）" % [where, kind])
		var legal := str(e.get("legal_status", ""))
		if not _LEGAL.has(legal):
			errors.append("%s: legal_status 非法（%s）" % [where, legal])
		var secrecy := str(e.get("secrecy", ""))
		if not _SECRECY.has(secrecy):
			errors.append("%s: secrecy 非法（%s）" % [where, secrecy])
		if not e.has("base_power"):
			errors.append("%s: 缺少 base_power" % where)
		elif float(e["base_power"]) < 0.0 or float(e["base_power"]) > 1.0:
			errors.append("%s: base_power 超值域（%s）" % [where, str(e["base_power"])])
		for field in ["institutions", "rivals", "allies"]:
			if not e.has(field):
				errors.append("%s: 缺少 %s" % [where, field])
			elif typeof(e[field]) != TYPE_ARRAY:
				errors.append("%s: %s 必须是数组" % [where, field])
		for inst in (e.get("institutions", []) as Array):
			if not _INSTITUTIONS.has(str(inst)):
				errors.append("%s: 机构非法（%s）" % [where, str(inst)])
	if table_name == "rumors":
		if e.has("reveals_faction") and typeof(e["reveals_faction"]) != TYPE_STRING:
			errors.append("%s: reveals_faction 必须是字符串" % where)
	if table_name == "governments":
		if str(e.get("summary", "")).is_empty():
			errors.append("%s: 缺少 summary" % where)
	if table_name == "political_events":
		if not ["politics", "economy", "law"].has(str(e.get("category", ""))):
			errors.append("%s: category 非法" % where)
		if str(e.get("text", "")).is_empty():
			errors.append("%s: 缺少 text" % where)
		if str(e.get("condition", "")).is_empty():
			errors.append("%s: 缺少 condition" % where)
	return errors
