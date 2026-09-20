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

# StyleBox 的内容边距（文字到边缘）。`StyleBoxFlat` 与 `StyleBoxTexture` **共用这两个值**：
# 否则「同一控件在换素材前后文字位置/最小高度会跳一下」。（内容边距 ≠ 九宫格边距，后者只影响贴图拉伸。）
const CONTENT_MARGIN_H := 8.0
const CONTENT_MARGIN_V := 4.0

# B8（P5b）：接进主题的清单键。**只列有真实消费者的**；新增一个键前先确认界面上有控件会用到它
# （否则就是「声明了但无效」的死旋钮，§8#16/#21 同类）。
# 未接的：`ui.panel_bg` / `ui.frame_*` / `ui.emblem_ring` / `ui.panel_slot` / `ui.button_close`
# —— 它们需要真实布局落点（`PanelContainer` 包裹等），留给 03b 的界面改版。
const UI_BUTTON_NORMAL := "ui.button_normal"
const UI_BUTTON_HOVER := "ui.button_hover"
const UI_BUTTON_PRESSED := "ui.button_pressed"
const UI_BUTTON_NEUTRAL := "ui.button_neutral"
const UI_TEXTFIELD := "ui.textfield"
const UI_SCROLLBAR_BG := "ui.scrollbar_bg"
const UI_SCROLLBAR_GRAB := "ui.scrollbar_grab"

# 无调制（modulate 恒等元）。
const TINT_NONE := Color(1, 1, 1, 1)

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
	# B8（P5b）：清单里配了 `ui.<键>` 就换成九宫格 `StyleBoxTexture`（边距来自清单数据，见 spec §2 约定 4），
	# 缺则**逐键独立**回退到原来的 `StyleBoxFlat`（缺一个状态不会把整组打回扁平）。
	#
	# Button 与 OptionButton 用同一套按钮贴图：OptionButton 是创建界面上最显眼的控件（7 个下拉框），
	# 若只有 Button 贴了图，两者会当场不一致。
	for theme_type in ["Button", "OptionButton"]:
		theme.set_stylebox("normal", theme_type, _pick(p, UI_BUTTON_NORMAL, _box(background, muted, 1, 3)))
		theme.set_stylebox("hover", theme_type, _pick(p, UI_BUTTON_HOVER, _box(background, accent, 1, 3)))
		theme.set_stylebox("pressed", theme_type, _pick(p, UI_BUTTON_PRESSED, _box(panel_bg, accent, 1, 3)))
		# 禁用态＝中性贴图 + `muted` 调制（保留「变暗」这个可用性信号；旧实现是 0.5 alpha 的扁盒子）
		theme.set_stylebox("disabled", theme_type,
				_pick(p, UI_BUTTON_NEUTRAL, _box(background, muted, 1, 3, 0.5), muted))
		# focus 保持**扁平**：它是叠在当前状态盒之上画的「焦点环」（透明底 + accent 描边），
		# 用不透明贴图会把按钮本体盖掉。
		theme.set_stylebox("focus", theme_type, _box(Color(0, 0, 0, 0), accent, 1, 3))
	# CheckBox **不套按钮贴图**：勾选框本体不是按钮底（本仓库当前也没有 CheckBox 实例，
	# 5 个槽位照旧全设扁平盒子 ⇒ 行为与改造前逐字一致）。
	theme.set_stylebox("normal", "CheckBox", _box(background, muted, 1, 3))
	theme.set_stylebox("hover", "CheckBox", _box(background, accent, 1, 3))
	theme.set_stylebox("pressed", "CheckBox", _box(panel_bg, accent, 1, 3))
	theme.set_stylebox("disabled", "CheckBox", _box(background, muted, 1, 3, 0.5))
	theme.set_stylebox("focus", "CheckBox", _box(Color(0, 0, 0, 0), accent, 1, 3))
	theme.set_stylebox("normal", "LineEdit", _pick(p, UI_TEXTFIELD, _box(background, muted, 1, 3)))
	theme.set_stylebox("focus", "LineEdit", _box(background, accent, 1, 3))
	# 只读态也用输入框贴图，但调暗（保留旧实现的「只读看上去更暗」信号）
	theme.set_stylebox("read_only", "LineEdit", _pick(p, UI_TEXTFIELD, _box(background, muted, 1, 3, 0.6), muted))

	# 滚动条：**改造前没设过任何滚动条样式**（一直用 Godot 内置默认主题）。
	# ⇒ 这里缺键时**不能**补一个扁盒子（那会把「没素材」变成「观感变了」），而是干脆不设 ⇒ 继续用内置默认样式。
	# 「清单缺键 ⇒ 与改造前一致」这条不变量由 `theme.has_stylebox(...)` 的断言钉住。
	for theme_type in ["VScrollBar", "HScrollBar"]:
		var trough := _textured(p, UI_SCROLLBAR_BG)
		if trough != null:
			theme.set_stylebox("scroll", theme_type, trough)
		var grabber := _textured(p, UI_SCROLLBAR_GRAB)
		if grabber != null:
			theme.set_stylebox("grabber", theme_type, grabber)
			# 没有 hover/pressed 的独立素材 ⇒ 同一张贴图 + 调制色派生。
			# ⚠️ 必须设：不设的话 Godot 会回落到内置默认主题的扁盒子，hover 时观感突变。
			theme.set_stylebox("grabber_highlight", theme_type, _textured(p, UI_SCROLLBAR_GRAB, accent))
			theme.set_stylebox("grabber_pressed", theme_type, _textured(p, UI_SCROLLBAR_GRAB, text))

	for theme_type in PANEL_TYPES:
		theme.set_stylebox("panel", theme_type, _box(panel_bg, muted, 1, 4))
	theme.set_stylebox("normal", "RichTextLabel", _box(panel_bg, muted, 1, 4))

	return theme


# 取「清单里 `ui.<键>` 对应的九宫格贴图盒」；缺贴图 / 键不存在 / 清单为 null ⇒ **null**
# （调用方自己决定是回退扁平盒子、还是不设该槽位——两种语义不同，见调用处注释）。
# `tint` 是 `StyleBoxTexture.modulate_color`（恒等元 = `TINT_NONE`）。
static func _textured(p: Presentation, key: String, tint: Color = TINT_NONE) -> StyleBoxTexture:
	var box := AssetSlots.stylebox_for(p, key)
	if box == null:
		return null
	box.content_margin_left = CONTENT_MARGIN_H
	box.content_margin_right = CONTENT_MARGIN_H
	box.content_margin_top = CONTENT_MARGIN_V
	box.content_margin_bottom = CONTENT_MARGIN_V
	box.modulate_color = tint
	return box


# 贴图优先、扁平兜底（逐键独立）。
static func _pick(p: Presentation, key: String, fallback: StyleBox, tint: Color = TINT_NONE) -> StyleBox:
	var box := _textured(p, key, tint)
	return box if box != null else fallback


# 统一的 StyleBoxFlat 构造：`alpha` 用来把「禁用态」压暗（1.0 = 不压）。
static func _box(fill: Color, border: Color, border_width: int, radius: int, alpha: float = 1.0) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = _with_alpha(fill, fill.a * alpha)
	box.border_color = _with_alpha(border, border.a * alpha)
	if border_width > 0:
		box.set_border_width_all(border_width)
	box.set_corner_radius_all(radius)
	box.content_margin_left = CONTENT_MARGIN_H
	box.content_margin_right = CONTENT_MARGIN_H
	box.content_margin_top = CONTENT_MARGIN_V
	box.content_margin_bottom = CONTENT_MARGIN_V
	return box


static func _with_alpha(color: Color, alpha: float) -> Color:
	return Color(color.r, color.g, color.b, clampf(alpha, 0.0, 1.0))
