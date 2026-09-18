class_name Registry
extends RefCounted

const TABLE_FILES: Dictionary = {
	"eras": "eras.json",
	"bloodlines": "bloodlines.json",
	"birth_identities": "birth_identities.json",
	"aptitudes": "aptitudes.json",
	"houses": "houses.json",
	"sim_styles": "sim_styles.json",
	"political_leanings": "political_leanings.json",
	"locations": "locations.json",
	"rumors": "rumors.json",
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
	return errors
