class_name Presentation
extends RefCounted

# 计划 03a-P P2：表现层清单的安全加载器 + 回退层。
# 契约（spec §2 接口冻结 / §2 约定 1）：**缺键 / 缺文件 / 路径不存在 / 类型不对 / JSON 畸形 ⇒ 一律回退**，
# 永不报错、永不阻塞；「加素材 = 放文件 + 改一行 JSON」，永不改代码。
#
# ⚠️ 本文件最容易写坏的地方是**往 stderr 打噪音**，那会破坏本项目很敏感的基线门禁。三条硬规矩（都是实测结论）：
#   ① 解析 JSON **不要**用 `JSON.parse_string()` —— 它在畸形输入时会打 `ERROR: Parse JSON failed…`；
#      用 `JSON.new().parse()`（只返回错误码 43，无噪音）。
#   ② 取资源**必须先 `ResourceLoader.exists()` 再 `load()`** —— `load()` 打在不存在/无导入器的路径上会打
#      `ERROR: Resource file not found: …`（`assets/ui/interface.psd` 就是这种「有文件但无导入器」的例子）。
#   ③ 形态可疑的路径（不以 `res://` / `user://` 开头）**根本不要送进 exists()**，直接当归缺失。
#
# 注意：上述噪音**不是** `SCRIPT ERROR`，所以 `tools/test.sh` 的 `SCRIPT ERROR == 2` 门禁抓不到它们
# （见报告中的「通道缺口」登记）。

const MANIFEST_PATH := "res://data/presentation.json"
const AUDIO_CUES_PATH := "res://data/audio_cues.json"

# 冻结的顶层键（spec §2）。缺项合法（缺 = 该命名空间整体回退）。
const MANIFEST_NAMESPACES: PackedStringArray = [
	"fonts", "ui", "icons", "textures", "emblems", "backdrops", "portraits", "palette",
]
const AUDIO_NAMESPACES: PackedStringArray = ["cues", "bgm_by_era", "bgm_by_location", "master_volume"]

# 对象形态的命名空间（条目是 `{"path":…, "size":…, "nine_patch":…}`）；其余命名空间是扁平字符串。
const OBJECT_NAMESPACES: PackedStringArray = ["fonts", "ui", "cues"]
# 对象条目里「资源路径」的字段名，按优先级认（`cues` 用 `sfx`，其余用 `path`）。
const PATH_FIELDS: PackedStringArray = ["path", "sfx", "texture"]

var _manifest: Dictionary = {}
var _cues: Dictionary = {}
# 资源缓存：path -> Resource 或 null。**失败也缓存**（负缓存），避免反复探测同一个坏路径。
var _resources: Dictionary = {}


static func load_default() -> Presentation:
	return load_from(MANIFEST_PATH, AUDIO_CUES_PATH)


# 只接受带 scheme 的路径（`res://` / `user://`）；其它一律当缺失，避免把垃圾串送进 FileAccess / ResourceLoader。
static func load_from(manifest_path: String, cues_path: String = AUDIO_CUES_PATH) -> Presentation:
	var p := Presentation.new()
	p._manifest = p._parse_json(manifest_path)
	p._cues = p._parse_json(cues_path)
	return p


# 测试与回退用：直接给字典。非字典一律当空清单（不报错）。
static func from_dicts(manifest: Variant, cues: Variant) -> Presentation:
	var p := Presentation.new()
	p._manifest = manifest if typeof(manifest) == TYPE_DICTIONARY else {}
	p._cues = cues if typeof(cues) == TYPE_DICTIONARY else {}
	return p


# ---- 通用查询（两份清单共用一套点号键空间） ----

# 点号键：`icons.castle` / `fonts.title` / `era.modern` / `cues.turn_submit` / `palette.text`
# 解析不到一律返回 null。
func resolve(key: String) -> Variant:
	if key.is_empty():
		return null
	var parts := key.split(".")
	if parts.size() < 2 or parts[0].is_empty():
		return null
	var current: Variant = _table(str(parts[0]))
	for i in range(1, parts.size()):
		if typeof(current) != TYPE_DICTIONARY:
			return null
		var d: Dictionary = current
		var seg := str(parts[i])
		if not d.has(seg):
			return null
		current = d[seg]
	return current


# has() 语义 = 「键存在且值非空」（字符串非空 / 字典非空）——**不是**「能加载成资源」。
# 形态非法的条目（数字、非路径字符串）由 font()/texture() 回退成 null 表达。
func has(key: String) -> bool:
	var v: Variant = resolve(key)
	if typeof(v) == TYPE_STRING:
		return not str(v).is_empty()
	if typeof(v) == TYPE_DICTIONARY:
		return not (v as Dictionary).is_empty()
	return false


# 解析出资源路径：字符串条目直接是路径；对象条目认 PATH_FIELDS 里第一个非空字符串字段。取不到返回 ""。
func path(key: String) -> String:
	var v: Variant = resolve(key)
	if typeof(v) == TYPE_STRING:
		return str(v)
	if typeof(v) == TYPE_DICTIONARY:
		var d: Dictionary = v
		for field in PATH_FIELDS:
			var candidate: Variant = d.get(field, null)
			if typeof(candidate) == TYPE_STRING and not str(candidate).is_empty():
				return str(candidate)
	return ""


# 对象条目本身（副本）；扁平字符串条目包成 `{"path": …}`；取不到返回 {}。
func entry(key: String) -> Dictionary:
	var v: Variant = resolve(key)
	if typeof(v) == TYPE_DICTIONARY:
		return (v as Dictionary).duplicate(true)
	if typeof(v) == TYPE_STRING and not str(v).is_empty():
		return {"path": str(v)}
	return {}


# 某个命名空间下的全部条目（副本，防外部改写内部状态）；未知命名空间返回 {}。
# 注：参数名不用 `namespace`——它是 GDScript 保留字（用作参数名会导致整个脚本解析失败，实测）。
func values(ns: String) -> Dictionary:
	var t: Variant = _table(ns)
	if typeof(t) != TYPE_DICTIONARY:
		return {}
	return (t as Dictionary).duplicate(true)


# 两份清单的原始内容（副本）；供测试做形状断言与工具排查。始终两个键都在。
func tables() -> Dictionary:
	return {"manifest": _manifest.duplicate(true), "cues": _cues.duplicate(true)}


# ---- 资源查询（缺素材一律 null，不报错） ----

func font(key: String) -> Font:
	var res: Resource = _load_resource(path(key))
	if res is Font:
		return res
	return null


func texture(key: String) -> Texture2D:
	var res: Resource = _load_resource(path(key))
	if res is Texture2D:
		return res
	return null


# 颜色只从 `palette.<name>` 取（spec §2 约定 3：代码里不许出现魔法颜色常量）。
# 解析失败或缺失 ⇒ 返回 fallback。
func palette(name: String, fallback: Color) -> Color:
	var raw := path("palette.%s" % name)
	if raw.is_empty():
		return fallback
	return Color.from_string(raw, fallback)


# 对象条目的 `size`（字号等）。缺失 / 非数值 / ≤0 ⇒ fallback。
func size_of(key: String, fallback: int) -> int:
	var d := entry(key)
	var raw: Variant = d.get("size", null)
	if typeof(raw) == TYPE_FLOAT or typeof(raw) == TYPE_INT:
		var n := int(raw)
		if n > 0:
			return n
	return fallback


# 对象条目的 `nine_patch`（上/右/下/左）。缺失 / 非数组 ⇒ 空数组（调用方据此判断「不需九宫格」）。
func nine_patch(key: String) -> Array:
	var d := entry(key)
	var raw: Variant = d.get("nine_patch", null)
	if typeof(raw) != TYPE_ARRAY:
		return []
	var out: Array = []
	for v in raw:
		out.append(int(v))
	return out


# 主音量（0..1）。缺失 / 非数值 / 越界 ⇒ clamp 或 1.0。
func master_volume() -> float:
	var raw: Variant = _cues.get("master_volume", null)
	if typeof(raw) == TYPE_FLOAT or typeof(raw) == TYPE_INT:
		return clampf(float(raw), 0.0, 1.0)
	return 1.0


# ---- 内部 ----

# 两份清单共用一个点号键空间：先查 presentation.json，再查 audio_cues.json。
func _table(ns: String) -> Variant:
	if _manifest.has(ns):
		return _manifest[ns]
	if _cues.has(ns):
		return _cues[ns]
	return null


func _has_scheme(path_str: String) -> bool:
	return path_str.begins_with("res://") or path_str.begins_with("user://")


func _parse_json(path_str: String) -> Dictionary:
	if path_str.is_empty() or not _has_scheme(path_str):
		return {}
	if not FileAccess.file_exists(path_str):
		return {}
	var text := FileAccess.get_file_as_string(path_str)
	if text.strip_edges().is_empty():
		return {}
	# ⚠️ 见文件头规矩 ①：用 JSON.new().parse()，不要用 JSON.parse_string()（后者会打 stderr 噪音）
	var parser := JSON.new()
	if parser.parse(text) != OK:
		return {}
	var parsed: Variant = parser.data
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	return parsed


func _load_resource(path_str: String) -> Resource:
	if path_str.is_empty() or not _has_scheme(path_str):
		return null
	if _resources.has(path_str):
		return _resources[path_str]
	var res: Resource = null
	# ⚠️ 见文件头规矩 ②③：先 exists 再 load，否则 `load()` 会往 stderr 打 `ERROR: Resource file not found…`
	if ResourceLoader.exists(path_str):
		var loaded: Variant = load(path_str)
		if loaded is Resource:
			res = loaded
	_resources[path_str] = res
	return res
