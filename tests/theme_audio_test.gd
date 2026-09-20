class_name ThemeAudioTest
extends RefCounted

# 计划 03a-P P3 + P4：主题构建（`ThemeBuilder`）与音频纯逻辑（`AudioDirector` 的 static 部分）+ 两个接线纯函数。
#
# ⚠️ **本套件刻意不创建任何 Node、不进场景树**（实测结论，见 audio_director.gd 头注）：
#   在 headless `-s` 模式下创建 `AudioStreamPlayer` 会在退出时打
#   `ERROR: N resources still in use at exit`，树外 `play()` 会打
#   `ERROR: Playback can only happen when a node is inside the scene tree` —— 两者都会撞
#   `tools/test.sh` 的 stderr 噪音门禁（`ERROR == 7`）。
#   ⇒ 纯逻辑走这里；**真实播放 / 触发点接线 / 主题真的挂上去** 由 `tools/b1_acceptance.gd`
#     在真场景（界面真的在树上）里验证。

const MAIN_SCRIPT := "res://src/ui/main.gd"
const CINZEL := "res://assets/fonts/Cinzel-Variable.ttf"
const REAL_BGM := "res://assets/audio/bgm/bg_main.ogg"
const MISSING_OGG := "res://assets/audio/bgm/__nope__.ogg"

# spec §4 冻结的 8 个 cue id（代码固定、不随素材变）
const CUE_IDS: PackedStringArray = [
	"turn_submit", "turn_done", "audit_start", "audit_ack",
	"save_ok", "load_ok", "faction_revealed", "llm_fallback",
]


func run() -> int:
	var a := TestAssert.new()
	var p := Presentation.load_default()

	_test_theme(a, p)
	_test_textured_styleboxes(a, p)
	_test_audio(a, p)
	_test_wiring(a)

	return a.report("theme_audio")


# ---------------- B8（P5b）：切片接进主题 ----------------

const BUTTON_NORMAL_PNG := "res://assets/ui/button_normal.png"
const BUTTON_HOVER_PNG := "res://assets/ui/button_hover.png"
const BUTTON_PRESSED_PNG := "res://assets/ui/button_pressed.png"
const TEXTFIELD_PNG := "res://assets/ui/textfield.png"
const SCROLLBAR_BG_PNG := "res://assets/ui/scrollbar_bg.png"
const SCROLLBAR_GRAB_PNG := "res://assets/ui/scrollbar_grab.png"


# 说明：这些断言不加 `VScrollBar.new()` 这类**控件实例**——非 RefCounted 的节点不 free 会在退出时
# 报「RID allocations leaked」= 多一条 `ERROR:` ⇒ 直接打破 `tools/test.sh` 的 stderr 噪音门禁。
func _test_textured_styleboxes(a: TestAssert, p: Presentation) -> void:
	var theme := ThemeBuilder.build(p)

	# ① 真实清单：接线真的生效（防「清单元件但没人消费」的死旋钮）
	for state in ["normal", "hover", "pressed", "disabled"]:
		a.is_true(theme.get_stylebox(state, "Button") is StyleBoxTexture,
			"真实清单：Button.%s 是九宫格贴图（B8 接线生效）" % state)
	a.is_true(theme.get_stylebox("normal", "OptionButton") is StyleBoxTexture,
		"OptionButton 与 Button 用同一套按钮贴图（否则创建界面两类控件观感不一致）")
	a.is_true(theme.get_stylebox("normal", "LineEdit") is StyleBoxTexture, "真实清单：LineEdit.normal 是贴图")
	a.is_true(theme.get_stylebox("read_only", "LineEdit") is StyleBoxTexture, "真实清单：LineEdit.read_only 用同一张贴图")
	for bar in ["VScrollBar", "HScrollBar"]:
		a.is_true(theme.get_stylebox("scroll", bar) is StyleBoxTexture, "真实清单：%s.scroll 是贴图" % bar)
		a.is_true(theme.get_stylebox("grabber", bar) is StyleBoxTexture, "真实清单：%s.grabber 是贴图" % bar)
	a.is_true(theme.has_stylebox("scroll", "VScrollBar"), "真实清单 ⇒ 明确设了 VScrollBar.scroll（不是靠内置默认主题）")

	# ② 贴图路径必须就是清单里那几张（防接错文件）
	var bn := theme.get_stylebox("normal", "Button") as StyleBoxTexture
	a.is_true(bn != null and bn.texture != null
			and bn.texture.resource_path.ends_with("button_normal.png"),
		"Button.normal 的贴图就是清单里的 button_normal.png")
	var tf := theme.get_stylebox("normal", "LineEdit") as StyleBoxTexture
	a.is_true(tf != null and tf.texture != null and tf.texture.resource_path.ends_with("textfield.png"),
		"LineEdit.normal 的贴图就是清单里的 textfield.png")
	var sb := theme.get_stylebox("scroll", "VScrollBar") as StyleBoxTexture
	a.is_true(sb != null and sb.texture != null and sb.texture.resource_path.ends_with("scrollbar_bg.png"),
		"滚动条槽的贴图就是清单里的 scrollbar_bg.png")

	# ③ 不该被接的：focus 必须仍是扁平（焦点环叠在按钮之上，不透明贴图会盖住本体）；
	#    panel_bg 未接（需真实布局落点，B8 范围外）
	a.is_true(theme.get_stylebox("focus", "Button") is StyleBoxFlat, "Button.focus 仍是扁平焦点环")
	a.is_true(theme.get_stylebox("panel", "PanelContainer") is StyleBoxFlat, "PanelContainer.panel 仍是扁平（panel_bg 未接）")
	a.is_true(theme.get_stylebox("normal", "CheckBox") is StyleBoxFlat, "CheckBox 不套按钮贴图（勾选框本体不是按钮底）")

	# ④ 逐键独立回退：只配一个 hover ⇒ 只有 hover 变贴图，其余仍扁平
	var only_hover := Presentation.from_dicts({
		"ui": {"button_hover": {"path": BUTTON_HOVER_PNG, "nine_patch": [1, 2, 3, 4]}},
	}, {})
	var ht := ThemeBuilder.build(only_hover)
	a.is_true(ht.get_stylebox("hover", "Button") is StyleBoxTexture, "只配 ui.button_hover ⇒ hover 用贴图")
	a.is_true(ht.get_stylebox("normal", "Button") is StyleBoxFlat, "只配 hover ⇒ normal 仍回退扁平（逐键独立）")
	a.is_true(ht.get_stylebox("pressed", "Button") is StyleBoxFlat, "只配 hover ⇒ pressed 仍回退扁平")
	a.is_true(ht.get_stylebox("disabled", "Button") is StyleBoxFlat, "只配 hover ⇒ disabled 仍回退扁平")

	# ⑤ 九宫格顺序：[上,右,下,左]（spec §2 约定 4）。用**非对称值**，否则左右/上下写反也测不出来。
	var hb := ht.get_stylebox("hover", "Button") as StyleBoxTexture
	a.eq(hb.texture_margin_top, 1.0, "nine_patch [1,2,3,4] 的『上』= 第 1 个数")
	a.eq(hb.texture_margin_right, 2.0, "…的『右』= 第 2 个数")
	a.eq(hb.texture_margin_bottom, 3.0, "…的『下』= 第 3 个数")
	a.eq(hb.texture_margin_left, 4.0, "…的『左』= 第 4 个数")

	# ⑥ content_margin 与扁平盒一致 ⇒ 换素材不会让文字位置/最小高度跳一下
	a.eq(hb.content_margin_left, ThemeBuilder.CONTENT_MARGIN_H, "贴图盒的内容边距与扁平盒一致（横向）")
	a.eq(hb.content_margin_top, ThemeBuilder.CONTENT_MARGIN_V, "贴图盒的内容边距与扁平盒一致（纵向）")

	# ⑦ 调制色：保留「禁用/只读看上去更暗」的可用性信号；grabber 三态同图但靠调制区分
	a.ne((theme.get_stylebox("disabled", "Button") as StyleBoxTexture).modulate_color, ThemeBuilder.TINT_NONE,
		"禁用态用中性贴图 + 调制（保留「变暗」信号，不是原色贴图）")
	a.ne((theme.get_stylebox("read_only", "LineEdit") as StyleBoxTexture).modulate_color, ThemeBuilder.TINT_NONE,
		"只读输入框用同一贴图 + 调制（保留「更暗」信号）")
	a.eq((theme.get_stylebox("grabber", "VScrollBar") as StyleBoxTexture).modulate_color, ThemeBuilder.TINT_NONE,
		"grabber 常态不加调制（原色）")
	a.ne((theme.get_stylebox("grabber_highlight", "VScrollBar") as StyleBoxTexture).modulate_color, ThemeBuilder.TINT_NONE,
		"grabber 悬停态是同一贴图的调制派生（不设会回落到内置默认盒子，观感突变）")
	a.ne((theme.get_stylebox("grabber_pressed", "VScrollBar") as StyleBoxTexture).modulate_color, ThemeBuilder.TINT_NONE,
		"grabber 按下态同样有调制派生")

	# ⑧ 缺键 ⇒ **与改造前一致**：滚动条保持「未设」（继续用内置默认样式），**不得**补一个扁盒子
	var flat := ThemeBuilder.build(Presentation.from_dicts({"palette": {"text": "#010203"}}, {}))
	a.is_true(flat.get_stylebox("normal", "Button") is StyleBoxFlat, "无 ui.* ⇒ Button 回退扁平")
	a.is_false(flat.has_stylebox("scroll", "VScrollBar"), "无 ui.scrollbar_bg ⇒ **不设** VScrollBar.scroll（与改造前一致，不引入新观感）")
	a.is_false(flat.has_stylebox("grabber", "VScrollBar"), "无 ui.scrollbar_grab ⇒ 不设 grabber")
	a.is_false(flat.has_stylebox("scroll", "HScrollBar"), "HScrollBar 同理")

	# ⑨ 清单写了路径但**文件不存在** ⇒ 同样回退（不崩、不报错）
	var bad := ThemeBuilder.build(Presentation.from_dicts({
		"ui": {"button_normal": {"path": "res://assets/ui/__nope__.png", "nine_patch": [1, 2, 3, 4]}},
	}, {}))
	a.is_true(bad.get_stylebox("normal", "Button") is StyleBoxFlat, "路径指向不存在的贴图 ⇒ 回退扁平（不崩）")


# ---------------- P3：ThemeBuilder ----------------

func _test_theme(a: TestAssert, p: Presentation) -> void:
	# ① 真实清单：能造出主题，且缺 fonts.body 时**不设** default_font（spec §2 约定 1）
	var theme := ThemeBuilder.build(p)
	a.is_true(theme != null, "ThemeBuilder.build(真实清单) 返回非 null")
	a.is_true(theme.default_font == null or theme.default_font is Font, "default_font 要么未设、要么是 Font")
	a.eq(theme.default_font_size, ThemeBuilder.DEFAULT_BODY_SIZE,
		"缺 fonts.body ⇒ 用内置正文字号回退（=%d）" % ThemeBuilder.DEFAULT_BODY_SIZE)

	# ② 缺清单 / null / 畸形：都必须造出**可用**主题，不崩
	for label in ["null", "空字典", "顶层不是字典"]:
		var broken := Presentation.from_dicts({}, {}) if label == "空字典" else null
		if label == "顶层不是字典":
			broken = Presentation.from_dicts("not-a-dict", 7)
		var t := ThemeBuilder.build(broken)
		a.is_true(t != null, "%s 清单 ⇒ 仍然返回非 null 主题" % label)
		a.is_true(t.get_stylebox("normal", "Button") != null, "%s 清单 ⇒ Button 仍有可用 StyleBox" % label)
	a.is_true(ThemeBuilder.build(null) != null, "传 null ⇒ 仍然返回非 null 主题")

	# ③ 调色板真的来自清单（判别式断言：清单给哨兵色，就必须**恰好**取到它）
	var fixture := Presentation.from_dicts({
		"palette": {"text": "#010203", "accent": "#040506", "muted": "#0a0b0c", "panel_bg": "#07080980"},
		"fonts": {"body": {"path": CINZEL, "size": 21}},
	}, {})
	var ft := ThemeBuilder.build(fixture)
	var sentinel_text := Color.from_string("#010203", Color.MAGENTA)
	var sentinel_accent := Color.from_string("#040506", Color.MAGENTA)
	var sentinel_muted := Color.from_string("#0a0b0c", Color.MAGENTA)
	a.eq(ft.get_color("font_color", "Label"), sentinel_text, "Label 前景色 = 清单 palette.text（不是代码里的常量）")
	a.eq(ft.get_color("default_color", "RichTextLabel"), sentinel_text, "RichTextLabel 正文色来自 palette.text")
	a.eq(ft.get_color("font_color", "Button"), sentinel_text, "Button 前景色来自 palette.text")
	a.eq(ft.get_color("font_color", "OptionButton"), sentinel_text, "OptionButton 前景色来自 palette.text")
	a.eq(ft.get_color("font_color", "LineEdit"), sentinel_text, "LineEdit 前景色来自 palette.text")
	a.eq(ft.get_color("font_color", "CheckBox"), sentinel_text, "CheckBox 前景色来自 palette.text")
	a.eq(ft.get_color("font_hover_color", "Button"), sentinel_accent, "Button 悬停色来自 palette.accent")
	a.eq(ft.get_color("font_pressed_color", "Button"), sentinel_accent, "Button 按下色来自 palette.accent")
	var box := ft.get_stylebox("normal", "Button")
	a.is_true(box is StyleBoxFlat, "Button normal 是 StyleBoxFlat（来自 ThemeBuilder）")
	if box is StyleBoxFlat:
		a.eq((box as StyleBoxFlat).border_color, sentinel_muted, "normal 描边色来自 palette.muted")
	var hover_box := ft.get_stylebox("hover", "Button")
	a.is_true(hover_box is StyleBoxFlat, "Button hover 是 StyleBoxFlat（来自 ThemeBuilder）")
	if hover_box is StyleBoxFlat:
		a.eq((hover_box as StyleBoxFlat).border_color, sentinel_accent, "hover 描边色来自 palette.accent")
	var panel_box := ft.get_stylebox("panel", "PanelContainer")
	a.is_true(panel_box is StyleBoxFlat, "PanelContainer 的 panel 槽位已设 StyleBox")

	# ④ fonts.body 配了就真的生效（字体 + 字号都从清单来）
	a.is_true(ft.default_font != null and ft.default_font is Font, "配了 fonts.body ⇒ default_font 来自清单")
	a.is_true(ft.default_font != null and ft.default_font.has_char(65), "配上的字体可查字形（has_char('A')）")
	a.eq(ft.default_font_size, 21, "字号来自清单 fonts.body.size")

	# ⑤ 只给部分 palette 键 ⇒ 其余回退到内置默认（不崩、仍然是不透明可用色）
	var partial := ThemeBuilder.build(Presentation.from_dicts({"palette": {"text": "#010203"}}, {}))
	a.eq(partial.get_color("font_color", "Label"), sentinel_text, "只给 text ⇒ 该键生效")
	a.eq(partial.get_color("font_hover_color", "Button"), ThemeBuilder.FALLBACK_ACCENT,
		"只给 text ⇒ accent 走内置回退色（不崩、不是透明垃圾）")
	a.is_true(ThemeBuilder.FALLBACK_ACCENT.a == 1.0, "内置回退本身是不透明色")


# ---------------- P4：AudioDirector 的纯逻辑 ----------------

func _test_audio(a: TestAssert, p: Presentation) -> void:
	# ① BGM 解析：带命名空间 / 裸键（地点优先、时代兜底）/ 取不到
	a.is_true(not AudioDirector.resolve_bgm_path(p, "bgm_by_location.hogwarts").is_empty(),
		"带命名空间的 BGM key 能解析")
	a.is_true(not AudioDirector.resolve_bgm_path(p, "bgm_by_era.modern").is_empty(),
		"带命名空间的时代 key 能解析")
	a.eq(AudioDirector.resolve_bgm_path(p, "bgm_by_location.__nope__"), "", "命名空间内取不到 ⇒ 空串")
	a.eq(AudioDirector.resolve_bgm_path(p, ""), "", "空 key ⇒ 空串")
	a.eq(AudioDirector.resolve_bgm_path(null, "hogwarts"), "", "presentation 为 null ⇒ 空串（不崩）")
	a.eq(AudioDirector.resolve_bgm_path(p, "__nope__"), "", "裸键两处都取不到 ⇒ 空串")

	# ② 真实清单的音频接线：**每条被清单引用的 BGM 路径都必须真能加载成音频流**
	var bgm_paths: Array = []
	for ns in [AudioDirector.LOCATION_NS, AudioDirector.ERA_NS]:
		var table := p.values(ns)
		for key in table.keys():
			bgm_paths.append(str(table[key]))
	a.is_true(bgm_paths.size() >= 10, "清单里至少配了 10 条 BGM 映射（实际 %d）" % bgm_paths.size())
	var unloadable: Array = []
	var not_looping: Array = []
	for raw in bgm_paths:
		var stream := AudioDirector.load_stream(str(raw))
		if stream == null:
			unloadable.append(str(raw))
		elif stream.get("loop") != true:
			not_looping.append(str(raw))
	a.eq(unloadable.size(), 0, "清单里每条 BGM 都能加载成 AudioStream（坏路径: %s）" % str(unloadable))
	a.eq(not_looping.size(), 0, "每条 BGM 的导入都设了 loop=true（spec §8.4 实测事实；没设会红: %s）" % str(not_looping))

	# ③ cue：8 个 id 在**无素材**时全部安全；有映射时必须指向真能加载的文件
	for id in CUE_IDS:
		var cue_path := AudioDirector.resolve_cue_path(p, id)
		a.is_true(cue_path.is_empty() or AudioDirector.load_stream(cue_path) != null,
			"cue %s 要么未配、要么指向可加载的音频" % id)
	a.eq(AudioDirector.resolve_cue_path(p, ""), "", "空 cue id ⇒ 空串")
	a.eq(AudioDirector.resolve_cue_path(p, "__nope__"), "", "未知 cue id ⇒ 空串（静音）")
	a.eq(AudioDirector.resolve_cue_path(null, "turn_submit"), "", "presentation 为 null ⇒ 空串（不崩）")
	a.eq(AudioDirector.cue_offset_db(p, "turn_submit"), 0.0, "未配 volume_db ⇒ 0.0 偏移")

	# ④ 夹具：cues 条目的 `sfx` 字段就是路径来源；volume_db 数值生效、非数值回退
	var fixture := Presentation.from_dicts({}, {"cues": {
		"turn_submit": {"sfx": REAL_BGM, "volume_db": -6},
		"weird": {"sfx": REAL_BGM, "volume_db": "loud"},
	}})
	a.eq(AudioDirector.resolve_cue_path(fixture, "turn_submit"), REAL_BGM, "cues.<id>.sfx 就是路径来源")
	a.eq(AudioDirector.cue_offset_db(fixture, "turn_submit"), -6.0, "volume_db=-6 生效")
	a.eq(AudioDirector.cue_offset_db(fixture, "weird"), 0.0, "volume_db 非数值 ⇒ 0.0（不崩）")

	# ⑤ 音量：master 线性→dB + cue 偏移；0 ⇒ 压到静音下限（-inf 非法）
	a.near(AudioDirector.volume_db(1.0, 0.0), 0.0, 0.001, "master=1.0 ⇒ 0 dB")
	a.near(AudioDirector.volume_db(0.8, 0.0), -1.9382, 0.01, "master=0.8 ⇒ ≈-1.94 dB")
	a.near(AudioDirector.volume_db(1.0, -6.0), -6.0, 0.001, "cue 偏移直接相加")
	a.eq(AudioDirector.volume_db(0.0, 0.0), AudioDirector.SILENCE_DB, "master=0 ⇒ 压到静音下限（不是 -inf）")
	a.eq(AudioDirector.volume_db(0.0, -6.0), AudioDirector.SILENCE_DB - 6.0, "master=0 + 偏移同样安全")
	a.near(AudioDirector.volume_db(9.9, 0.0), 0.0, 0.001, "master>1 被 clamp 到 1.0")

	# ⑥ load_stream 的边界：这些都是「必须静音且不打噪音」的路径
	a.is_true(AudioDirector.load_stream(REAL_BGM) is AudioStream, "真实 ogg 能加载")
	a.eq(AudioDirector.load_stream(MISSING_OGG), null, "不存在的音频 ⇒ null（且不得打 ERROR 噪音）")
	a.eq(AudioDirector.load_stream("not-a-scheme.ogg"), null, "无 scheme ⇒ null（不送进 load）")
	a.eq(AudioDirector.load_stream(""), null, "空路径 ⇒ null")
	a.eq(AudioDirector.load_stream("res://assets/icons/castle.svg"), null, "非音频资源 ⇒ null（类型不符也回退）")


# ---------------- P4：两个「UI 层可观测信号」的纯函数（main.gd 的 static） ----------------

func _test_wiring(a: TestAssert) -> void:
	var main_script: GDScript = load(MAIN_SCRIPT)
	a.is_true(main_script != null, "能加载 src/ui/main.gd 以取它的 static 纯函数")

	# 降级检测（§8#61）：来源是 warnings → op_errors 里那条「LLM 降级：…」
	a.is_false(main_script.is_fallback_result({}), "空结果 ⇒ 非降级")
	a.is_false(main_script.is_fallback_result({"op_errors": []}), "无 op_errors 条目 ⇒ 非降级")
	a.is_false(main_script.is_fallback_result({"op_errors": ["其他提示"]}), "无关提示 ⇒ 非降级（不是「有任何 op_error 就算降级」）")
	a.is_true(main_script.is_fallback_result({"op_errors": ["LLM 降级：HTTP 状态 0（连接失败/超时中断）"]}),
		"含「LLM 降级：」（§8#61 的文案来源）⇒ 判为降级")
	a.is_true(main_script.is_fallback_result({"op_errors": PackedStringArray(["LLM 降级：解析失败"])}),
		"PackedStringArray 形态同样识别（真实结果就是这种）")
	a.is_false(main_script.is_fallback_result({"op_errors": "LLM 降级：x"}), "op_errors 形态不对 ⇒ false（不崩）")
	a.is_false(main_script.is_fallback_result({"op_errors": 123}), "op_errors 是数字 ⇒ false（不崩）")

	# 新揭示派系（faction_revealed）：回合前后差集
	a.eq(main_script.newly_revealed(PackedStringArray(["a"]), PackedStringArray(["a", "b"])),
		PackedStringArray(["b"]), "差集给出新揭示的派系")
	a.eq(main_script.newly_revealed(PackedStringArray(["a", "b"]), PackedStringArray(["a", "b"])).size(), 0,
		"没有新揭示 ⇒ 空（这条是「不要每回合乱响」的判据）")
	a.eq(main_script.newly_revealed(PackedStringArray(["a", "b"]), PackedStringArray(["a"])).size(), 0,
		"集合变小 ⇒ 不算新揭示")
	a.eq(main_script.newly_revealed(PackedStringArray(), PackedStringArray(["x", "y"])),
		PackedStringArray(["x", "y"]), "起始为空 ⇒ 全部算新揭示")
