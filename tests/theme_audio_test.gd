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
	_test_audio(a, p)
	_test_wiring(a)

	return a.report("theme_audio")


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
