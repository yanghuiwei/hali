class_name AssetSlots
extends RefCounted

# 计划 03a-P P5：素材槽位的**解析与回退**层。
#
# 契约（spec §1/§2 + §4）：
#   * **缺键 / 缺文件 / 路径不存在 / 清单为 null ⇒ 槽位不可见**，永不报错、永不往 stderr 打噪音。
#   * 「加素材 = 放文件 + 改一行 JSON」：槽位用的键名与九宫格边距**全部来自清单**，这里不写死任何素材名/尺寸。
#   * 槽位不可见时**不占位**：Godot 的 Container 会跳过 `visible == false` 的子节点，
#     所以「素材没到之前，界面与加槽位之前逐像素一致」是靠 `visible = false` 保证的（有断言钉住）。
#
# ⚠️ **本文件是 `Presentation` 的只读消费者**：不许改 `Presentation` 的 API（spec §2 接口冻结）。
#
# ⚠️ **九宫格边距的数组顺序**（全项目只在这一处翻译，务必看明白）：
#   `Presentation.nine_patch()` 的冻结契约是 **上/右/下/左**（见 `presentation.gd:165`，CSS `border-image-slice` 同款顺时针）。
#   Godot 的 `StyleBoxTexture` 是四个独立字段（left/top/right/bottom）。
#   ⇒ 映射：清单 `[上, 右, 下, 左]` → Godot `left=arr[3], top=arr[0], right=arr[1], bottom=arr[2]`。
#   这条映射由 `tests/asset_slots_test.gd` 用一组**非对称**数据（1/2/3/4）钉住——
#   用对称值（如 12,12,12,12）测是测不出左右/上下写反的。

const SLOT_LOGO := "ui.logo"
const SLOT_PLAYER_PORTRAIT := "portraits.player.default"
const BACKDROP_LOCATION_PREFIX := "backdrops.location."
const BACKDROP_ERA_PREFIX := "backdrops.era."
const HOUSE_EMBLEM_PREFIX := "emblems.house."


# 取槽位贴图；清单为 null / 键为空 / 键不存在 / 文件不存在 ⇒ null（不报错）。
static func texture_for(presentation: Presentation, key: String) -> Texture2D:
	if presentation == null or key.is_empty():
		return null
	return presentation.texture(key)


# 把槽位贴图应用到 `TextureRect`：**无素材就把 `visible` 关掉**（占位与否完全由这条决定）。
# `rect == null` 也安全（返回 false）——启动早期或测试夹具里可能还没有控件。
static func apply_to(rect: TextureRect, presentation: Presentation, key: String) -> bool:
	if rect == null:
		return false
	var tex := texture_for(presentation, key)
	rect.texture = tex
	rect.visible = tex != null
	return tex != null


# 清单 `[上, 右, 下, 左]` → Godot 顺序 `(x=left, y=top, z=right, w=bottom)`。
# 缺失 / 非 4 元素 / 非数值 ⇒ 全 0（调用方据此退化为「整张拉伸」，而不是崩）。
static func patch_insets(presentation: Presentation, key: String) -> Vector4i:
	if presentation == null or key.is_empty():
		return Vector4i.ZERO
	var raw := presentation.nine_patch(key)
	if raw.size() != 4:
		return Vector4i.ZERO
	for v in raw:
		if typeof(v) != TYPE_INT and typeof(v) != TYPE_FLOAT:
			return Vector4i.ZERO
	return Vector4i(int(raw[3]), int(raw[0]), int(raw[1]), int(raw[2]))


# 用清单里的贴图 + 九宫格边距造 `StyleBoxTexture`；缺贴图 ⇒ null（调用方保留原样式，不套空盒子）。
# ⚠️ 本轮（P5 收紧范围版）**不**把它套到 `ui.panel_bg` / `button_*` 上：
#    那需要真实切片的尺寸与边距，切片未到场时做必然返工。切片到场后只需加清单行，**零代码改动**。
static func stylebox_for(presentation: Presentation, key: String) -> StyleBoxTexture:
	var tex := texture_for(presentation, key)
	if tex == null:
		return null
	var insets := patch_insets(presentation, key)
	var box := StyleBoxTexture.new()
	box.texture = tex
	box.texture_margin_left = float(insets.x)
	box.texture_margin_top = float(insets.y)
	box.texture_margin_right = float(insets.z)
	box.texture_margin_bottom = float(insets.w)
	return box


# 背景槽位的键：**地点优先、时代兜底**（spec §4 的 BGM 同款口径）。
# 只认「真的能加载出贴图」的键；两个都取不到 ⇒ ""（调用方据此关闭槽位）。
static func backdrop_key(presentation: Presentation, location_id: String, era_id: String) -> String:
	if presentation == null:
		return ""
	if not location_id.is_empty():
		var location_key := "%s%s" % [BACKDROP_LOCATION_PREFIX, location_id]
		if presentation.texture(location_key) != null:
			return location_key
	if not era_id.is_empty():
		var era_key := "%s%s" % [BACKDROP_ERA_PREFIX, era_id]
		if presentation.texture(era_key) != null:
			return era_key
	return ""


# 学院徽记的键；`house_id` 为空 ⇒ ""（不拼出 `emblems.house.` 这种半截键）。
static func house_emblem_key(house_id: String) -> String:
	if house_id.is_empty():
		return ""
	return "%s%s" % [HOUSE_EMBLEM_PREFIX, house_id]


# 一组槽位里有没有任何一个是可见的（用来决定承载它们的行是否占位）。
static func any_visible(rects: Array) -> bool:
	for r in rects:
		if r is CanvasItem and (r as CanvasItem).visible:
			return true
	return false
