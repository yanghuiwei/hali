class_name AssetSlotsTest
extends RefCounted

# 计划 03a-P P5：素材槽位的解析与回退（`AssetSlots`）。
#
# ⚠️ 尽量**不创建 Node、不进场景树**（理由见 theme_audio_test.gd 头注：headless `-s` 下闯树/资源
#    会在退出期打 `ERROR: N resources still in use at exit`，撞 stderr 噪音门禁）。
#    唯一例外：`apply_to()` 需要一个真 `TextureRect` 当目标 —— 用完在**同一个函数里显式 `free()`**。
#
# ⚠️ 对**真实清单**只用「要么空、要么指向可加载资源」这种**面向未来**的断言：
#    素材（切片/背景/徽记/立绘）到场后只需改 `data/presentation.json`，本套件**不需要改**。
#    「今天这些槽位都不可见」这种时点性断言放在 `tools/b1_acceptance.gd`（真场景里）。

const ICON := "res://assets/icons/castle.svg"
const RUNIC := "res://assets/textures/runic_codex.png"
const MISSING_PNG := "res://assets/ui/__nope__.png"


func run() -> int:
	var a := TestAssert.new()
	var p := Presentation.load_default()

	_test_texture(a, p)
	_test_apply(a, p)
	_test_nine_patch_order(a)
	_test_key_resolution_contract(a)
	_test_backdrop_and_emblem(a, p)

	return a.report("asset_slots")


# ---------------- ① 取贴图：缺键 / 缺文件 / 空清单 一律 null ----------------

func _test_texture(a: TestAssert, p: Presentation) -> void:
	a.eq(AssetSlots.texture_for(null, ICON), null, "presentation 为 null ⇒ null（不崩）")
	a.eq(AssetSlots.texture_for(p, ""), null, "空键 ⇒ null")
	a.eq(AssetSlots.texture_for(p, "icons.__nope__"), null, "键不存在 ⇒ null")
	a.is_true(AssetSlots.texture_for(p, "icons.castle") is Texture2D, "真实存在的图标键 ⇒ 拿到 Texture2D")
	a.eq(AssetSlots.texture_for(p, "ui.logo"), null, "真实清单还没有 ui 命名空间 ⇒ null（不假绿）")
	a.eq(AssetSlots.texture_for(Presentation.from_dicts({}, {}), "icons.castle"), null, "空清单 ⇒ null")


# ---------------- ② apply_to：**无素材必须把 visible 关掉**（这条决定占不占位）----------------

func _test_apply(a: TestAssert, p: Presentation) -> void:
	var rect := TextureRect.new()
	rect.visible = true

	a.is_false(AssetSlots.apply_to(null, p, ICON), "rect 为 null ⇒ false（不崩）")

	a.is_true(AssetSlots.apply_to(rect, p, "icons.castle"), "有素材 ⇒ 返回 true")
	a.is_true(rect.visible, "有素材 ⇒ 槽位可见")
	a.is_true(rect.texture != null, "有素材 ⇒ texture 真的设上了")

	a.is_false(AssetSlots.apply_to(rect, p, "icons.__nope__"), "键不存在 ⇒ false")
	a.is_false(rect.visible, "键不存在 ⇒ 槽位不可见（不占位）")
	a.eq(rect.texture, null, "键不存在 ⇒ texture 被清空（不留上一张图）")

	a.is_false(AssetSlots.apply_to(rect, p, "ui.logo"), "真实清单里的 ui.logo 还不存在 ⇒ false")
	a.is_false(rect.visible, "ui.logo 缺失 ⇒ 不可见（这就是「素材没到也不返工」的机制）")

	a.is_false(AssetSlots.apply_to(rect, null, "icons.castle"), "presentation 为 null ⇒ false 且不崩")
	a.is_false(rect.visible, "presentation 为 null ⇒ 不可见")

	rect.free()


# ---------------- ③ 九宫格边距的顺序（用**非对称**数据钉住，对称值测不出左右写反）----------------

func _test_nine_patch_order(a: TestAssert) -> void:
	# 清单顺序 = 上/右/下/左 ⇒ Godot 顺序 (left, top, right, bottom) = (左, 上, 右, 下) = (4, 1, 2, 3)
	var fx := Presentation.from_dicts({
		"ui": {
			"panel_bg": {"path": RUNIC, "nine_patch": [1, 2, 3, 4]},
			"no_patch": {"path": RUNIC},
			"short_patch": {"path": RUNIC, "nine_patch": [1, 2, 3]},
			"bad_patch": {"path": RUNIC, "nine_patch": ["a", "b", "c", "d"]},
			"missing_file": {"path": MISSING_PNG, "nine_patch": [1, 2, 3, 4]},
		},
	}, {})

	a.eq(AssetSlots.patch_insets(fx, "ui.panel_bg"), Vector4i(4, 1, 2, 3),
		"清单 [上,右,下,左]=[1,2,3,4] ⇒ Godot (left,top,right,bottom)=(4,1,2,3)")

	var box := AssetSlots.stylebox_for(fx, "ui.panel_bg")
	a.is_true(box is StyleBoxTexture, "有图 + 有四元边距 ⇒ 造出 StyleBoxTexture")
	if box != null:
		a.is_true(box.texture is Texture2D, "StyleBoxTexture 带上了清单里的贴图")
		a.eq(int(box.texture_margin_left), 4, "texture_margin_left = 清单第 4 项（左）")
		a.eq(int(box.texture_margin_top), 1, "texture_margin_top = 清单第 1 项（上）")
		a.eq(int(box.texture_margin_right), 2, "texture_margin_right = 清单第 2 项（右）")
		a.eq(int(box.texture_margin_bottom), 3, "texture_margin_bottom = 清单第 3 项（下）")

	a.eq(AssetSlots.patch_insets(fx, "ui.no_patch"), Vector4i.ZERO, "缺 nine_patch ⇒ 全 0（退化为整张拉伸）")
	var no_patch_box := AssetSlots.stylebox_for(fx, "ui.no_patch")
	a.is_true(no_patch_box is StyleBoxTexture, "缺 nine_patch 但仍要出盒子（0 边距）")
	if no_patch_box != null:
		a.eq(int(no_patch_box.texture_margin_left), 0, "缺 nine_patch ⇒ 左边距 0")

	a.eq(AssetSlots.patch_insets(fx, "ui.short_patch"), Vector4i.ZERO, "three 元素数组 ⇒ 全 0（不猜顺序）")
	a.eq(AssetSlots.patch_insets(fx, "ui.bad_patch"), Vector4i.ZERO, "非数值数组 ⇒ 全 0")
	a.eq(AssetSlots.patch_insets(fx, "ui.__nope__"), Vector4i.ZERO, "键不存在 ⇒ 全 0")
	a.eq(AssetSlots.patch_insets(null, "ui.panel_bg"), Vector4i.ZERO, "presentation 为 null ⇒ 全 0")

	a.eq(AssetSlots.stylebox_for(fx, "ui.missing_file"), null, "缺图 ⇒ null（即使清单给了边距）")
	a.eq(AssetSlots.stylebox_for(fx, "ui.__nope__"), null, "键不存在 ⇒ null")
	a.eq(AssetSlots.stylebox_for(null, "ui.panel_bg"), null, "presentation 为 null ⇒ null")

	# 真实清单：本轮还没有 ui 素材 ⇒ 必须拿不到盒子（也就是说「面板底还没套上去」，符合预期）
	a.eq(AssetSlots.stylebox_for(Presentation.load_default(), "ui.panel_bg"), null,
		"真实清单还没有 ui.panel_bg ⇒ null")


# ---------------- ③-2 点号键的解析规则（实测发现的契约缺陷，钉死不许两种写法）----------------
# `Presentation.resolve()` 是**逐层下钻嵌套字典**：`a.b.c` → `manifest["a"]["b"]["c"]`。
# ⇒ **清单必须写成嵌套对象**；写成**字面点号键**（`{"emblems": {"house.gryffindor": …}}`）是取不到的。
# ⚠️ spec §2 的示例里 `emblems` / `backdrops` / `portraits` 用的正是**字面点号键**，那是错的
# （见 task-12 同款教训：声明了但无效的旋钮）。本函数把两种写法的实际行为都钉住，防止后人又被示例带歪。
func _test_key_resolution_contract(a: TestAssert) -> void:
	var nested := Presentation.from_dicts({
		"emblems": {"house": {"gryffindor": ICON}},
		"icons": {"castle": ICON},
	}, {})
	a.eq(nested.resolve("emblems.house.gryffindor"), ICON, "嵌套写法（emblems→house→gryffindor）能解析出来")
	a.is_true(nested.texture("emblems.house.gryffindor") is Texture2D, "嵌套写法能真加载出贴图")
	a.eq(nested.resolve("icons.castle"), ICON, "两层键（icons→castle）也是嵌套写法")

	var flat := Presentation.from_dicts({"emblems": {"house.gryffindor": ICON}}, {})
	a.eq(flat.resolve("emblems.house.gryffindor"), null,
		"字面点号键（spec §2 示例的写法）⇒ **取不到** (这是实测结论，不是猜测)")
	a.eq(AssetSlots.texture_for(flat, "emblems.house.gryffindor"), null,
		"⇒ AssetSlots 在这写法下也取不到（所以清单必须嵌套）")

	# 而我们的槽位构造函数在**嵌套清单**下必须真的命中（这条是上面那个缺陷的回归护栏）
	var fx := Presentation.from_dicts({
		"emblems": {"house": {"gryffindor": ICON}},
		"backdrops": {"location": {"hogwarts": RUNIC}, "era": {"modern": ICON}},
	}, {})
	a.is_true(AssetSlots.texture_for(fx, AssetSlots.house_emblem_key("gryffindor")) is Texture2D,
		"house_emblem_key 生成的键在嵌套清单下真的能取到")
	a.eq(AssetSlots.backdrop_key(fx, "hogwarts", "modern"), "backdrops.location.hogwarts",
		"backdrop_key 生成的键在嵌套清单下真的能命中地点")


# ---------------- ④ 背景（地点优先、时代兜底）与学院徽记 ----------------

func _test_backdrop_and_emblem(a: TestAssert, p: Presentation) -> void:
	# ⚠️ 必须是**嵌套**写法（见 `_test_key_resolution_contract`）
	var fx := Presentation.from_dicts({
		"backdrops": {"location": {"hogwarts": RUNIC}, "era": {"modern": ICON}},
		"emblems": {"house": {"gryffindor": ICON}},
	}, {})
	a.eq(AssetSlots.backdrop_key(fx, "hogwarts", "modern"), "backdrops.location.hogwarts", "地点键优先")
	a.eq(AssetSlots.backdrop_key(fx, "__nope__", "modern"), "backdrops.era.modern", "地点取不到 ⇒ 退到时代")
	a.eq(AssetSlots.backdrop_key(fx, "", ""), "", "两者都空 ⇒ 空串")
	a.eq(AssetSlots.backdrop_key(fx, "__nope__", "__nope__"), "", "两者都取不到 ⇒ 空串")
	a.eq(AssetSlots.backdrop_key(null, "hogwarts", "modern"), "", "presentation 为 null ⇒ 空串")

	var broken := Presentation.from_dicts({
		"backdrops": {"location": {"hogwarts": MISSING_PNG}, "era": {"modern": MISSING_PNG}},
	}, {})
	a.eq(AssetSlots.backdrop_key(broken, "hogwarts", "modern"), "", "键在但文件不在 ⇒ 不算命中（不返回半截键）")

	a.eq(AssetSlots.house_emblem_key("gryffindor"), "emblems.house.gryffindor", "学院徽记键带命名空间前缀")
	a.eq(AssetSlots.house_emblem_key(""), "", "house_id 为空 ⇒ 空串（不拼出 emblems.house. 半截键）")
	a.eq(AssetSlots.house_emblem_key("none"), "emblems.house.none", "哑炮的 none 同样能拼键（取不到就回退）")

	# 真实清单：本轮还没有背景/徽记/立绘 ⇒ 面向未来的口径（要么空、要么指向可加载贴图）
	var real_backdrop := AssetSlots.backdrop_key(p, "hogwarts", "modern")
	a.is_true(real_backdrop.is_empty() or AssetSlots.texture_for(p, real_backdrop) != null,
		"真实清单下 backdrop_key 要么空、要么指向可加载贴图（素材到场后本套件不改）")
	a.eq(AssetSlots.texture_for(p, AssetSlots.SLOT_PLAYER_PORTRAIT), null,
		"真实清单还没有 portraits.player.default ⇒ null")

	# 「槽位不可见」的最小单元断言（真场景级的整行/根布局断言在 b1）
	var rect := TextureRect.new()
	rect.visible = true
	a.is_false(AssetSlots.apply_to(rect, p, AssetSlots.house_emblem_key("gryffindor")),
		"真实清单（还没徽记）⇒ 槽位返回 false")
	a.is_false(rect.visible, "⇒ 槽位不可见（不占位）")
	rect.free()

	# any_visible：决定承载行要不要占位
	a.is_false(AssetSlots.any_visible([]), "空数组 ⇒ false")
	a.is_false(AssetSlots.any_visible([null]), "全 null ⇒ false")
	var hidden := TextureRect.new()
	hidden.visible = false
	var shown := TextureRect.new()
	shown.visible = true
	a.is_false(AssetSlots.any_visible([hidden, null]), "都不可见 ⇒ false")
	a.is_true(AssetSlots.any_visible([hidden, shown]), "有一个可见 ⇒ true")
	hidden.free()
	shown.free()
