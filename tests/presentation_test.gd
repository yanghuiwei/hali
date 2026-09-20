class_name PresentationTest
extends RefCounted

# 计划 03a-P P2：`Presentation` 的形状 / 回退 / 与 CREDITS 对账。
# 断言分四组：① 真实清单的形状与可用性 ② 缺键/缺文件/类型不对的**回退**（本任务的核心契约）
# ③ 畸形 JSON 与缺失文件（真文件路径） ④ 与 `assets/CREDITS.md` 的**授权对账**。
# 另有「中文字形覆盖」一组：现在字体尚未入场 ⇒ 不阻断；但 `fonts.body` 一旦配了文件就必须含中文字形。

const MANIFEST_PATH := "res://data/presentation.json"
const AUDIO_CUES_PATH := "res://data/audio_cues.json"
const CREDITS_PATH := "res://assets/CREDITS.md"

# 与 spec §2「接口冻结」逐字一致（测试自己再抄一份：清单被改形状时必须在这里也失败）
const MANIFEST_NAMESPACES: PackedStringArray = [
	"fonts", "ui", "icons", "textures", "emblems", "backdrops", "portraits", "palette",
]
const AUDIO_NAMESPACES: PackedStringArray = ["cues", "bgm_by_era", "bgm_by_location", "master_volume"]
const OBJECT_NAMESPACES: PackedStringArray = ["fonts", "ui", "cues"]
const FLAT_NAMESPACES: PackedStringArray = [
	"icons", "textures", "emblems", "backdrops", "portraits", "palette", "bgm_by_era", "bgm_by_location",
]

const FALLBACK := Color(0.1, 0.2, 0.3, 0.4)


func run() -> int:
	var a := TestAssert.new()
	var p := Presentation.load_default()

	# ---- ① 真实清单：形状 ----
	var t := p.tables()
	var manifest: Dictionary = t["manifest"]
	var cues: Dictionary = t["cues"]
	a.is_true(not manifest.is_empty(), "presentation.json 可解析且非空")
	a.is_true(not cues.is_empty(), "audio_cues.json 可解析且非空")

	var shape_bad := _shape_violations(manifest, MANIFEST_NAMESPACES, "presentation.json")
	shape_bad.append_array(_shape_violations(cues, AUDIO_NAMESPACES, "audio_cues.json"))
	a.eq(shape_bad.size(), 0, "两份清单的形状符合冻结契约（违规: %s）" % str(shape_bad))
	# 防「清单被清空但形状仍合法」的空泛通过
	a.is_true(manifest.has("fonts") and manifest.has("icons") and manifest.has("textures") and manifest.has("palette"),
		"presentation.json 至少含 fonts/icons/textures/palette 四个命名空间")
	a.is_true(cues.has("bgm_by_era") and cues.has("bgm_by_location"), "audio_cues.json 含两个 BGM 映射")

	# ---- ② 真实清单：可用性（真的能加载出资源） ----
	a.is_true(p.has("icons.castle"), "icons.castle 存在")
	a.eq(p.path("icons.castle"), "res://assets/icons/castle.svg", "path() 解析扁平条目")
	a.eq(p.path("fonts.title"), "res://assets/fonts/Cinzel-Variable.ttf", "path() 解析对象条目的 path 字段")
	var icon := p.texture("icons.castle")
	a.is_true(icon is Texture2D, "texture(icons.castle) 真能加载出 Texture2D")
	if icon != null:
		a.eq(icon.get_size(), Vector2(512, 512), "SVG 图标导入为 512×512（spec §8.4 实测事实）")
	var tex := p.texture("textures.runic_codex")
	if tex != null:
		a.eq(tex.get_size(), Vector2(448, 384), "runic_codex.png 为 448×384（spec §8.4 实测事实）")
	else:
		a.fail("texture(textures.runic_codex) 应为 Texture2D")
	var title_font := p.font("fonts.title")
	a.is_true(title_font is Font, "font(fonts.title) 真能加载出 Font")
	a.eq(p.size_of("fonts.title", 99), 28, "size_of 读对象条目的 size")
	a.eq(p.size_of("icons.castle", 99), 99, "扁平条目没有 size ⇒ fallback")
	a.eq(p.nine_patch("ui.__nope__"), [], "无 ui 素材 ⇒ nine_patch 返回空数组（不报错）")
	a.is_true(p.values("icons").has("castle"), "values(icons) 给出条目副本")
	a.eq(p.values("__nope__").size(), 0, "未知命名空间 values() 返回空字典")

	# ---- ③ 回退：缺键 / 缺文件 / 类型不对 ----
	a.is_false(p.has("icons.__nope__"), "不存在的键 has() 为假")
	a.eq(p.texture("icons.__nope__"), null, "不存在的贴图 ⇒ null（不报错）")
	a.eq(p.font("fonts.__nope__"), null, "不存在的字体 ⇒ null（不报错）")
	a.eq(p.font("icons.castle"), null, "拿贴图当字体查 ⇒ null（类型不符也回退）")
	a.eq(p.texture("fonts.title"), null, "拿字体当贴图查 ⇒ null（类型不符也回退）")
	a.is_false(p.has(""), "空键 has() 为假")
	a.is_false(p.has("icons"), "只有命名空间、没有条目段 ⇒ 解析不到（has 假）")
	a.is_false(p.has("__nope__.castle"), "未知命名空间 ⇒ 假")
	a.eq(p.path("__nope__.castle"), "", "未知命名空间 path() 返回空串")
	a.eq(p.path(""), "", "空键 path() 返回空串")
	a.eq(p.entry("__nope__.castle").size(), 0, "取不到的 entry() 返回空字典")
	a.eq(p.palette("__nope__", FALLBACK), FALLBACK, "未知调色板键 ⇒ 返回 fallback")
	a.eq(p.palette("text", FALLBACK), Color.from_string("#e8e2d0", FALLBACK), "palette.text 解析出真实颜色")
	a.ne(p.palette("text", FALLBACK), FALLBACK, "palette 真的生效（不是在偷偷用 fallback）")
	a.ne(p.palette("panel_bg", FALLBACK), FALLBACK, "8 位十六进制（带 alpha）也能解析")

	var blanks := Presentation.from_dicts({"icons": {"empty": ""}, "fonts": {"empty_obj": {}}}, {})
	a.is_false(blanks.has("icons.empty"), "值为**空字符串**的条目 ⇒ has() 为假（不是「键存在即为真」）")
	a.is_false(blanks.has("fonts.empty_obj"), "值为**空对象**的条目 ⇒ has() 为假")
	a.eq(blanks.entry("icons.empty").size(), 0, "空字符串条目的 entry() 返回空字典")
	a.eq(blanks.path("icons.empty"), "", "空字符串条目的 path() 返回空串")
	a.eq(Presentation.from_dicts({"fonts": {"weird": {"size": 9}}}, {}).path("fonts.weird"), "",
		"对象条目里没有任何路径字段（path/sfx/texture）⇒ path() 返回空串")

	var empty := Presentation.from_dicts({}, {})
	a.is_false(empty.has("icons.castle"), "空清单：任何键都取不到")
	a.eq(empty.texture("icons.castle"), null, "空清单：texture() 回退 null")
	a.eq(empty.font("fonts.body"), null, "空清单：font() 回退 null")
	a.eq(empty.path("bgm_by_era.modern"), "", "空清单：path() 回退空串")
	a.eq(empty.palette("text", FALLBACK), FALLBACK, "空清单：palette 回退 fallback")
	a.eq(empty.master_volume(), 1.0, "空清单：master_volume 回退 1.0")

	var weird := Presentation.from_dicts("not-a-dict", 123)
	a.is_false(weird.has("icons.castle"), "顶层类型不对（String / int）⇒ 当空清单，不报错")
	a.eq(weird.master_volume(), 1.0, "顶层类型不对 ⇒ master_volume 回退 1.0")

	var bad := Presentation.from_dicts(
		{"icons": {"bad": 123}, "fonts": {"x": "not-a-path"}, "ui": 5, "palette": "nope"}, {})
	a.is_false(bad.has("icons.bad"), "条目是数字 ⇒ has() 假（形态非法即回退）")
	a.eq(bad.texture("icons.bad"), null, "条目是数字 ⇒ texture() null")
	a.eq(bad.font("fonts.x"), null, "条目不是 res:// 路径 ⇒ font() null（且不得把垃圾串送进 load()）")
	a.eq(bad.texture("fonts.x"), null, "同上 ⇒ texture() null")
	a.eq(bad.path("ui.panel_bg"), "", "命名空间不是对象 ⇒ path() 空串")
	a.eq(bad.palette("text", FALLBACK), FALLBACK, "palette 不是对象 ⇒ fallback")
	a.eq(bad.nine_patch("ui.panel_bg"), [], "命名空间不是对象 ⇒ nine_patch 空数组")

	# ---- ④ 畸形 JSON / 缺失文件（真文件路径，走 FileAccess + JSON 分支） ----
	var tmp := "user://__presentation_bad__.json"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	a.is_true(f != null, "能创建临时畸形 JSON 夹具")
	if f != null:
		f.store_string("{ this is not valid json")
		f.close()
		var broken := Presentation.load_from(tmp, "res://data/__nope__.json")
		a.is_false(broken.has("icons.castle"), "畸形 JSON ⇒ 当空清单（不报错）")
		a.eq(broken.texture("icons.castle"), null, "畸形 JSON ⇒ texture() null")
		a.eq(broken.path("icons.castle"), "", "畸形 JSON ⇒ path() 空串")
		a.eq(broken.master_volume(), 1.0, "manifest 畸形 + cues 文件缺失 ⇒ 两个都回退")
		var empty_file := "user://__presentation_empty__.json"
		var f2 := FileAccess.open(empty_file, FileAccess.WRITE)
		if f2 != null:
			f2.store_string("   \n  ")
			f2.close()
			a.is_false(Presentation.load_from(empty_file, empty_file).has("icons.castle"), "空文件 ⇒ 当空清单")
			if FileAccess.file_exists(empty_file):
				DirAccess.remove_absolute(empty_file)
		if FileAccess.file_exists(tmp):
			DirAccess.remove_absolute(tmp)
	a.is_false(FileAccess.file_exists(tmp), "临时夹具已清理")
	a.is_false(Presentation.load_from("res://data/__nope__.json", "res://data/__nope__.json").has("palette.text"),
		"两份清单文件都不存在 ⇒ 当空清单（不报错）")
	a.is_false(Presentation.load_from("not-a-scheme.json", "not-a-scheme.json").has("palette.text"),
		"路径没有 scheme ⇒ 直接当缺失，不送进 FileAccess")

	# ---- ⑤ 对象形态的额外字段（P3/P4 会用到） ----
	var fixture := Presentation.from_dicts({
		"ui": {"panel_bg": {"path": "res://assets/ui/panel_bg.png", "nine_patch": [4, 5, 6, 7]}},
		"fonts": {"body": {"path": "res://assets/fonts/body_cjk.ttf", "size": 16}},
	}, {"cues": {"turn_submit": {"sfx": "res://assets/audio/sfx/turn_submit.ogg", "volume_db": -6}}})
	a.eq(fixture.nine_patch("ui.panel_bg"), [4, 5, 6, 7], "nine_patch 读得到")
	a.eq(fixture.size_of("fonts.body", 99), 16, "对象条目的 size 读得到")
	a.eq(fixture.path("cues.turn_submit"), "res://assets/audio/sfx/turn_submit.ogg", "cues 条目的 sfx 也能当路径取出")
	a.eq(float(fixture.entry("cues.turn_submit").get("volume_db", 0.0)), -6.0, "entry() 给出对象条目原文")
	a.eq(fixture.master_volume(), 1.0, "fixture 未给 master_volume ⇒ 回退 1.0")
	a.eq(Presentation.from_dicts({}, {"master_volume": 0.0}).master_volume(), 0.0, "master_volume 读到 0.0")
	a.eq(Presentation.from_dicts({}, {"master_volume": 9.9}).master_volume(), 1.0, "master_volume 越界 ⇒ clamp 到 1.0")
	a.eq(Presentation.from_dicts({}, {"master_volume": "loud"}).master_volume(), 1.0, "master_volume 非数值 ⇒ 回退 1.0")

	# ---- ⑥ 与 assets/CREDITS.md 对账（授权台账；spec §2 接口冻结第 4 条） ----
	var patterns := _credits_patterns()
	a.is_true(patterns.size() >= 8, "CREDITS 总表解析出至少 8 条登记项（实际 %d）" % patterns.size())
	a.is_true(_is_registered(patterns, "audio/bgm/bg_main.ogg"), "精确路径能匹配登记项")
	a.is_true(_is_registered(patterns, "icons/castle.svg"), "glob 登记项 icons/*.svg 能匹配 icons/castle.svg")
	# ⚠️ 负例必须选一个**没有任何登记项（含 glob）覆盖**的路径：`icons/*.svg` 是 glob，
	#    所以 `icons/<任何>.svg` 本就会被判为已登记 —— 拿它当负例是恒真断言，没有判别力。
	a.is_false(_is_registered(patterns, "emblems/__nope__.png"), "未登记路径确实判为未登记（对账有判别力）")
	a.is_true(_is_registered(patterns, "icons/__nope__.svg"),
		"已知放松点：glob 行 `icons/*.svg` 会覆盖任何新增图标（要逐文件审计需把该行拆成 15 条）")

	var manifest_paths: Array = []
	_collect_asset_paths(manifest, manifest_paths)
	var cue_paths: Array = []
	_collect_asset_paths(cues, cue_paths)
	a.is_true(manifest_paths.size() >= 15, "presentation.json 收集到至少 15 条 res:// 路径（实际 %d，防空泛断言）" % manifest_paths.size())
	a.is_true(cue_paths.size() >= 10, "audio_cues.json 收集到至少 10 条 res:// 路径（实际 %d）" % cue_paths.size())
	var wrong_prefix: Array = []
	var unregistered: Array = []
	for raw_path in manifest_paths + cue_paths:
		var s := str(raw_path)
		if not s.begins_with("res://assets/"):
			wrong_prefix.append(s)
		elif not _is_registered(patterns, s.substr("res://assets/".length())):
			unregistered.append(s)
	a.eq(wrong_prefix.size(), 0, "清单里所有路径都以 res://assets/ 开头（违规: %s）" % str(wrong_prefix))
	a.eq(unregistered.size(), 0, "清单里每条路径都在 CREDITS 总表登记（未登记: %s）" % str(unregistered))

	# ---- ⑦ 中文字形覆盖（字体到场后才硬断言；现在不阻断） ----
	# 契约写成「条件式」而不是 if/else + 恒真占位：字体一旦入场，这两条会自动生效（含中文字形才算过）。
	var body_path := p.path("fonts.body")
	a.is_true(body_path.is_empty() or ResourceLoader.exists(body_path),
		"fonts.body 要么未配置，要么指向真实存在的字体（当前=%s）" % body_path)
	var body_font := p.font("fonts.body")
	a.is_true(body_font == null or body_font.has_char("你".unicode_at(0)),
		"fonts.body 一旦能加载，就必须含中文字形（否则中文界面是豆腐块）")
	# 判别力：现有拉丁字体确实不含中文字形 ⇒ 上面那条断言一旦生效就不是恒真
	a.is_true(title_font != null and not title_font.has_char("你".unicode_at(0)),
		"Cinzel 确实不含中文字形（证明字形覆盖断言有判别力）")

	return a.report("presentation")


# 返回形状违规清单（空 = 合法）。允许缺命名空间（缺 = 该命名空间整体回退），但不允许改形状或类型。
func _shape_violations(table: Dictionary, allowed: PackedStringArray, label: String) -> PackedStringArray:
	var bad := PackedStringArray()
	for key in table.keys():
		if not allowed.has(str(key)):
			bad.append("%s: 顶层键 %s 不在冻结集合内" % [label, str(key)])
	for ns in FLAT_NAMESPACES:
		if not table.has(ns):
			continue
		var entries: Variant = table[ns]
		if typeof(entries) != TYPE_DICTIONARY:
			bad.append("%s: %s 必须是对象" % [label, ns])
			continue
		for key in (entries as Dictionary).keys():
			if typeof((entries as Dictionary)[key]) != TYPE_STRING:
				bad.append("%s.%s.%s 必须是字符串路径" % [label, ns, str(key)])
	for ns in OBJECT_NAMESPACES:
		if not table.has(ns):
			continue
		var entries2: Variant = table[ns]
		if typeof(entries2) != TYPE_DICTIONARY:
			bad.append("%s: %s 必须是对象" % [label, ns])
			continue
		for key in (entries2 as Dictionary).keys():
			if typeof((entries2 as Dictionary)[key]) != TYPE_DICTIONARY:
				bad.append("%s.%s.%s 的条目必须是对象" % [label, ns, str(key)])
	return bad


# 递归收集 `res://` 开头的字符串（palette 的十六进制颜色与 nine_patch 的数字天然不会被收进来）
func _collect_asset_paths(value: Variant, out: Array) -> void:
	if typeof(value) == TYPE_STRING:
		var s := str(value)
		if s.begins_with("res://"):
			out.append(s)
		return
	if typeof(value) == TYPE_DICTIONARY:
		var d: Dictionary = value
		for key in d.keys():
			_collect_asset_paths(d[key], out)
		return
	if typeof(value) == TYPE_ARRAY:
		for item in (value as Array):
			_collect_asset_paths(item, out)


# 从 `assets/CREDITS.md` 的「一、素材总表」抽登记模式：每行取**第一个反引号包裹的 token**
# （「文件」列就是第一个单元格；`icons/*.svg`（15 个）这类带括号的行也能正确取到 glob）
func _credits_patterns() -> PackedStringArray:
	var out := PackedStringArray()
	if not FileAccess.file_exists(CREDITS_PATH):
		return out
	var text := FileAccess.get_file_as_string(CREDITS_PATH)
	var in_table := false
	for line in text.split("\n"):
		var s := str(line).strip_edges()
		if s.begins_with("## "):
			in_table = s.begins_with("## 一")
			continue
		if not in_table or not s.begins_with("|"):
			continue
		var token := _first_backtick_token(s)
		if not token.is_empty():
			out.append(token)
	return out


func _first_backtick_token(line: String) -> String:
	var start := line.find("`")
	if start < 0:
		return ""
	var end := line.find("`", start + 1)
	if end < 0:
		return ""
	return line.substr(start + 1, end - start - 1)


func _is_registered(patterns: PackedStringArray, rel_path: String) -> bool:
	for pattern in patterns:
		if str(pattern) == rel_path or rel_path.match(str(pattern)):
			return true
	return false
