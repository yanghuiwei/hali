class_name ThemeBuilder
extends RefCounted

# 计划 03a-P P3：用 `Presentation`（`data/presentation.json`）造一个 `Theme`。
#
# 契约（spec §2 + §4）：
#   * **传 null / 空清单 / 畸形清单 / 缺键 / 缺文件 ⇒ 仍然返回一个可用 Theme**，不崩、不往 stderr 打噪音。
#   * 颜色**一律**从 `palette` 取（spec §2 约定 3：代码里不许出现魔法颜色常量）。
#     本文件里的颜色字面量只作为 `palette(name, 内置回退值)` 的 **fallback** 实参，
#     含义是「清单没给就用这个安全默认」，不是把配色写死在代码里。
#   * `fonts.body` 缺失 ⇒ **不设** `default_font`（spec §2 约定 1：回退到 Godot 默认字体）。
#     中文能不能读，靠「清单里配上 CJK 字体」解决，**不在代码里兜底**——
#     `presentation_test` 有一条条件式硬断言：`fonts.body` 一旦能加载就必须含中文字形。
#   * 主题在**运行期**挂到根节点（`main.gd:_ready`），**不**提交 `.tres`：
#     清单是唯一事实来源，提交二进制主题资源会让「改一行 JSON」变成「还要重新生成 .tres」= 返工。
#
# 用法：`theme = ThemeBuilder.build(presentation)`（挂在根 Control 上，整棵子树继承）。

# `fonts.body.size` 缺失时的正文字号。这是**排版默认值**，不是配色常量。
const DEFAULT_BODY_SIZE := 16

# palette 缺键时的安全默认（唯一的颜色字面量出口；语义见文件头）。
const FALLBACK_TEXT := Color("#e8e2d0")
const FALLBACK_MUTED := Color("#9a917f")
const FALLBACK_ACCENT := Color("#c8a24a")
const FALLBACK_BACKGROUND := Color(0.075, 0.07, 0.065, 1.0)
const FALLBACK_PANEL := Color(0.11, 0.10, 0.09, 0.88)

# 上「字体/前景色」的类型。SpinBox 不在列：它的显示是内部 LineEdit（走 LineEdit 主题），
# 给它设 `font_color` 是无效项，不如不设。
const COLOR_TYPES: PackedStringArray = ["Label", "RichTextLabel", "Button", "OptionButton", "LineEdit", "CheckBox"]
# 上 StyleBox 的类型。`PanelContainer` + `Panel` 共用 `panel` 槽位。
const PANEL_TYPES: PackedStringArray = ["PanelContainer", "Panel"]


static func build(presentation: Presentation) -> Theme:
	var p: Presentation = presentation if presentation != null else Presentation.from_dicts({}, {})
	var theme := Theme.new()

	var text := p.palette("text", FALLBACK_TEXT)
	var muted := p.palette("muted", FALLBACK_MUTED)
	var accent := p.palette("accent", FALLBACK_ACCENT)
	var background := p.palette("background", FALLBACK_BACKGROUND)
	var panel_bg := p.palette("panel_bg", FALLBACK_PANEL)

	# ---- 字体（缺 fonts.body ⇒ 保持 Godot 默认字体，见文件头契约） ----
	var body_font := p.font("fonts.body")
	if body_font != null:
		theme.default_font = body_font
	theme.default_font_size = p.size_of("fonts.body", DEFAULT_BODY_SIZE)

	# ---- 前景色 ----
	for theme_type in COLOR_TYPES:
		theme.set_color("font_color", theme_type, text)
	theme.set_color("default_color", "RichTextLabel", text)
	theme.set_color("selection_color", "RichTextLabel", _with_alpha(accent, 0.35))
	theme.set_color("font_placeholder_color", "LineEdit", muted)
	theme.set_color("font_uneditable_color", "LineEdit", muted)
	theme.set_color("caret_color", "LineEdit", accent)
	theme.set_color("selection_color", "LineEdit", _with_alpha(accent, 0.35))
	for theme_type in ["Button", "OptionButton", "CheckBox"]:
		theme.set_color("font_hover_color", theme_type, accent)
		theme.set_color("font_pressed_color", theme_type, accent)
		theme.set_color("font_focus_color", theme_type, text)
		theme.set_color("font_disabled_color", theme_type, muted)

	# ---- 样式盒 ----
	for theme_type in ["Button", "OptionButton", "CheckBox"]:
		theme.set_stylebox("normal", theme_type, _box(background, muted, 1, 3))
		theme.set_stylebox("hover", theme_type, _box(background, accent, 1, 3))
		theme.set_stylebox("pressed", theme_type, _box(panel_bg, accent, 1, 3))
		theme.set_stylebox("disabled", theme_type, _box(background, muted, 1, 3, 0.5))
		theme.set_stylebox("focus", theme_type, _box(Color(0, 0, 0, 0), accent, 1, 3))
	theme.set_stylebox("normal", "LineEdit", _box(background, muted, 1, 3))
	theme.set_stylebox("focus", "LineEdit", _box(background, accent, 1, 3))
	theme.set_stylebox("read_only", "LineEdit", _box(background, muted, 1, 3, 0.6))
	for theme_type in PANEL_TYPES:
		theme.set_stylebox("panel", theme_type, _box(panel_bg, muted, 1, 4))
	theme.set_stylebox("normal", "RichTextLabel", _box(panel_bg, muted, 1, 4))

	return theme


# 统一的 StyleBoxFlat 构造：`alpha` 用来把「禁用态」压暗（1.0 = 不压）。
static func _box(fill: Color, border: Color, border_width: int, radius: int, alpha: float = 1.0) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = _with_alpha(fill, fill.a * alpha)
	box.border_color = _with_alpha(border, border.a * alpha)
	if border_width > 0:
		box.set_border_width_all(border_width)
	box.set_corner_radius_all(radius)
	box.content_margin_left = 8.0
	box.content_margin_right = 8.0
	box.content_margin_top = 4.0
	box.content_margin_bottom = 4.0
	return box


static func _with_alpha(color: Color, alpha: float) -> Color:
	return Color(color.r, color.g, color.b, clampf(alpha, 0.0, 1.0))
