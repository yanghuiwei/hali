class_name ThemeAudioTest
extends RefCounted

# 计划 03a-P P3：主题构建（`ThemeBuilder`）——清单缺键/缺文件/畸形时仍必须造出可用主题。
#
# ⚠️ **本套件刻意不创建任何 Node、不进场景树**（见 audio_director.gd 头注的实测结论）：
#   在 headless `-s` 模式下创建 `AudioStreamPlayer` 会在退出时打 `ERROR: N resources still in use at exit`，
#   会撞 `tools/test.sh` 的 stderr 噪音门禁 ⇒ 涉及播放的断言一律放 `tools/b1_acceptance.gd`（真场景）。

const CINZEL := "res://assets/fonts/Cinzel-Variable.ttf"


func run() -> int:
	var a := TestAssert.new()
	var p := Presentation.load_default()

	_test_theme(a, p)

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
