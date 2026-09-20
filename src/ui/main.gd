extends Control

const SAVE_SLOT := "slot1"
const SEED_SALT := 20260918
# §8#70：创建界面的性别选项（原来界面没有性别输入，所有角色性别恒为「未定」）
const GENDERS: PackedStringArray = ["男", "女", "未定"]

var registry: Registry = null
var world: WorldState = null
var engine: TurnEngine = null
var rng: RngService = null

# 计划 03a-P P3/P4：表现层清单 → 主题 + 音频（清单是唯一事实来源，见 spec §2）
var presentation: Presentation = null
var audio: AudioDirector = null

var root_box: VBoxContainer = null
var creation_box: VBoxContainer = null
var play_box: VBoxContainer = null
var log_view: RichTextLabel = null
var command_edit: LineEdit = null
var status_label: Label = null
var dropdowns: Dictionary = {}
var name_edit: LineEdit = null
var gender_dropdown: OptionButton = null
var goal_edit: LineEdit = null
var age_spin: SpinBox = null
var personality_edit: LineEdit = null
var creation_error: Label = null
var button_row: HBoxContainer = null

# 计划 03a-P P5：素材槽位。**缺素材 ⇒ 不可见、不占位**（Container 跳过不可见子节点）。
# 本轮只做「解析 + 回退」；`ui.panel_bg`/`button_*` 的九宫格套用等切片到场（见 asset_slots.gd 头注）。
var backdrop_rect: TextureRect = null
var logo_rect: TextureRect = null
var assets_row: HBoxContainer = null
var emblem_rect: TextureRect = null
var portrait_rect: TextureRect = null

# B1 人工验收用：HALI_DEBUG_LOG=1 时把界面文本镜像到 stdout（默认关闭，行为完全不变）。
var _debug_mirror: bool = false

# §8#58/#62：等待期的上限（秒）。不设 HALI_TURN_TIMEOUT_SEC 时行为与改造前一致，
# 只是多了一层「有上限的等待」——超时后一定恢复输入与按钮。
var turn_timeout_sec: float = 180.0
var _llm_provider: OpenAiCompatProvider = null

func _ready() -> void:
	registry = Registry.load_default()
	var errors := registry.validate()
	errors.append_array(WorldFactions.validate_content(registry))
	for e in errors:
		push_warning("内容表问题：%s" % e)
	print("main scene ready, godot=", Engine.get_version_info().string)
	_debug_mirror = DebugMirror.from_env()
	if _debug_mirror:
		print(DebugMirror.format("调试镜像已启用：界面文本将镜像到 stdout（user://logs/*.log）；内容表问题 %d 条" % errors.size()))
	var env_timeout := OS.get_environment("HALI_TURN_TIMEOUT_SEC")
	if not env_timeout.is_empty() and env_timeout.is_valid_float():
		turn_timeout_sec = maxf(0.1, env_timeout.to_float())
	# P3：主题在运行期挂到根 Control（整棵子树继承）。**不**提交 `.tres`：
	# 清单是唯一事实来源，提交二进制主题资源会让「改一行 JSON」变成「还要重新生成 .tres」= 返工。
	presentation = Presentation.load_default()
	theme = ThemeBuilder.build(presentation)
	# P4：音频导演以子节点形式入树（AudioStreamPlayer 需要在场景树上才能播）；缺素材则全程静音。
	audio = AudioDirector.create(presentation)
	add_child(audio)
	_build_ui()
	_show_creation()
	_refresh_slots()

# ---- 计划 03a-P P4：音频触发点 ----

# 所有 cue 的唯一出口：`play_cue` 自己保证「缺素材 = 静音」，这里只负责镜像，
# 让 B1 能从外部观测到「触发点真的被调到了」（与「真的出声了」分开，见 audio_director.gd 头注）。
func _cue(id: String) -> void:
	if audio == null:
		return
	var played := audio.play_cue(id)
	_mirror("[音频] cue=%s 出声=%s" % [id, str(played)])

# BGM：**地点优先、时代兜底**（spec §4）；清单里两个都没配 ⇒ 保持当前 BGM（不切、不停）。
# `set_bgm` 是幂等的（同一首重复设置不重启），所以每回合调一次是安全的，也是「换地点」的收口。
func _sync_bgm() -> void:
	if audio == null or world == null:
		return
	var switched := false
	if not world.player.location_id.is_empty():
		switched = audio.set_bgm("%s.%s" % [AudioDirector.LOCATION_NS, world.player.location_id])
	if not switched and not world.era_id.is_empty():
		switched = audio.set_bgm("%s.%s" % [AudioDirector.ERA_NS, world.era_id])
	_mirror("[音频] bgm=%s volume_db=%.1f" % [audio.current_bgm_path() if switched else "(未切)",
		audio.bgm_volume_db()])


# 计划 03a-P P5：刷新 4 个素材槽位。**完全数据驱动**（键名与九宫格边距都来自清单）。
# 刷新点与 `_sync_bgm()` 一致（开局/读档/回合结束），因为这三处正是「地点/时代/学院可能变」的时刻。
func _refresh_slots() -> void:
	if presentation == null:
		return
	AssetSlots.apply_to(logo_rect, presentation, AssetSlots.SLOT_LOGO)
	var location_id := ""
	var era_id := ""
	var house_id := ""
	if world != null:
		location_id = world.player.location_id
		era_id = world.era_id
		house_id = world.player.house_id
	var backdrop := AssetSlots.backdrop_key(presentation, location_id, era_id)
	AssetSlots.apply_to(backdrop_rect, presentation, backdrop)
	# 先把徽记/立绘各自置好，再由「有没有任何一个可见」决定整行是否占位
	AssetSlots.apply_to(emblem_rect, presentation, AssetSlots.house_emblem_key(house_id))
	AssetSlots.apply_to(portrait_rect, presentation, AssetSlots.SLOT_PLAYER_PORTRAIT)
	if assets_row != null:
		assets_row.visible = AssetSlots.any_visible([emblem_rect, portrait_rect])
	_mirror("[素材槽] logo=%s backdrop=%s emblem=%s portrait=%s" % [
		str(logo_rect != null and logo_rect.visible), backdrop if not backdrop.is_empty() else "(无)",
		str(emblem_rect != null and emblem_rect.visible), str(portrait_rect != null and portrait_rect.visible)])

# §8#61：`LlmGameMaster` 的两条降级分支都往 `warnings` 追加「LLM 降级：<原因>」，
# `TurnEngine._resolve` 把 `warnings` 并进 `op_errors`（llm_game_master.gd:73/77 + turn_engine.gd:39）。
# 这里按**同一个来源**检测 ⇒ **GM 层零改动**（P4 的授权偏离：不在 `_fallback()` 内部接线）。
# 形态不对（不是数组）⇒ false，不崩。
const FALLBACK_MARKER := "LLM 降级"

static func is_fallback_result(result: Dictionary) -> bool:
	var errors: Variant = result.get("op_errors", null)
	if typeof(errors) != TYPE_ARRAY and typeof(errors) != TYPE_PACKED_STRING_ARRAY:
		return false
	for err in errors:
		if str(err).begins_with(FALLBACK_MARKER):
			return true
	return false

# 本回合**新**揭示的派系（用于 `faction_revealed`）。PackedStringArray 只能用 `.has()`（台账实测：`==` 会解析失败）。
static func newly_revealed(before: PackedStringArray, after: PackedStringArray) -> PackedStringArray:
	var out := PackedStringArray()
	for fid in after:
		if not before.has(str(fid)):
			out.append(str(fid))
	return out

# 镜像通道的**唯一出口**：所有对外可见的界面文本都经这里，方便 B1 从外部观测。
func _mirror(text: String) -> void:
	if _debug_mirror:
		print(DebugMirror.format(text))

func _build_ui() -> void:
	# P5：背景槽位。直接挂在根 Control 下（**不进 `root_box`**）⇒ 不参与任何容器布局；
	# 先于 root_box 入树 ⇒ 画在最底层；不可见时不占位也不吃鼠标。
	backdrop_rect = TextureRect.new()
	backdrop_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	backdrop_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	backdrop_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	backdrop_rect.visible = false
	add_child(backdrop_rect)

	root_box = VBoxContainer.new()
	root_box.set_anchors_preset(Control.PRESET_FULL_RECT)
	root_box.add_theme_constant_override("separation", 6)
	add_child(root_box)

	# P5：标题 Logo 槽（在状态行上方）。`visible=false` 时 VBoxContainer 会跳过它 ⇒ 不占位。
	logo_rect = TextureRect.new()
	logo_rect.custom_minimum_size = Vector2(0, 48)
	logo_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	logo_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	logo_rect.visible = false
	root_box.add_child(logo_rect)

	status_label = Label.new()
	_set_status("《哈利·波特·魔法纪元》魔法世界沙盘·超高自由度人生模拟器")
	# P3：标题用清单里的 `fonts.title`（拉丁显示体）；缺则保持主题默认（不报错）
	if presentation != null:
		var title_font := presentation.font("fonts.title")
		if title_font != null:
			status_label.add_theme_font_override("font", title_font)
	root_box.add_child(status_label)

	# P5：徽记 + 立绘共占一行。两个都缺 ⇒ 整行 `visible=false`（不占位，见 b1 的反返工断言）。
	assets_row = HBoxContainer.new()
	assets_row.visible = false
	root_box.add_child(assets_row)
	emblem_rect = TextureRect.new()
	emblem_rect.custom_minimum_size = Vector2(32, 32)
	emblem_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	emblem_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	emblem_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	emblem_rect.visible = false
	assets_row.add_child(emblem_rect)
	portrait_rect = TextureRect.new()
	portrait_rect.custom_minimum_size = Vector2(0, 144)
	portrait_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	portrait_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait_rect.visible = false
	assets_row.add_child(portrait_rect)

	creation_box = VBoxContainer.new()
	root_box.add_child(creation_box)

	play_box = VBoxContainer.new()
	play_box.visible = false
	root_box.add_child(play_box)

	log_view = RichTextLabel.new()
	log_view.scroll_following = true
	log_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	play_box.add_child(log_view)

	command_edit = LineEdit.new()
	command_edit.placeholder_text = "输入你的行动（例：我要练习魔药学 / 我去对角巷打工 / 我念出 照明咒）"
	command_edit.text_submitted.connect(_on_command_submitted)
	play_box.add_child(command_edit)

	button_row = HBoxContainer.new()
	play_box.add_child(button_row)
	for pair in [["状态", "_on_status"], ["魔法", "_on_magic"], ["关系", "_on_relation"], ["势力", "_on_power"],
			["存档", "_on_save"], ["读档", "_on_load"], ["自检", "_on_audit"]]:
		var b := Button.new()
		b.text = str(pair[0])
		b.pressed.connect(Callable(self, str(pair[1])))
		button_row.add_child(b)

func _add_dropdown(parent: Node, key: String, title: String, table: String) -> void:
	var row := HBoxContainer.new()
	var label := Label.new()
	label.text = title
	label.custom_minimum_size = Vector2(120, 0)
	row.add_child(label)
	var option := OptionButton.new()
	var index := 0
	for id in registry.ids(table):
		var entry := registry.entry(table, str(id))
		option.add_item("%s（%s）" % [str(entry.get("label", id)), str(id)], index)
		option.set_item_metadata(index, str(id))
		index += 1
	row.add_child(option)
	parent.add_child(row)
	dropdowns[key] = option

func _show_creation() -> void:
	for child in creation_box.get_children():
		child.queue_free()
	dropdowns.clear()
	gender_dropdown = null
	var title := Label.new()
	title.text = "【选择你的起点】（第七十五章）"
	creation_box.add_child(title)

	creation_error = Label.new()
	creation_error.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	creation_error.custom_minimum_size = Vector2(0, 48)
	creation_box.add_child(creation_error)

	_add_dropdown(creation_box, "era_id", "时代", "eras")
	_add_dropdown(creation_box, "bloodline_id", "血统/出身", "bloodlines")
	_add_dropdown(creation_box, "birth_identity_id", "出生身份", "birth_identities")
	_add_dropdown(creation_box, "aptitude_id", "魔法资质", "aptitudes")
	_add_dropdown(creation_box, "house_id", "学院倾向", "houses")
	_add_dropdown(creation_box, "political_leaning_id", "政治倾向", "political_leanings")
	_add_dropdown(creation_box, "sim_style_id", "模拟风格", "sim_styles")

	var name_row := HBoxContainer.new()
	var name_label := Label.new()
	name_label.text = "姓名"
	name_label.custom_minimum_size = Vector2(120, 0)
	name_row.add_child(name_label)
	name_edit = LineEdit.new()
	# §8#70：不再预填「无名者」——留空 + 占位提示，逼玩家给角色起名
	# （validate_choices 会拒绝空名字，不会静默给一个“无名者”角色）
	name_edit.text = ""
	name_edit.placeholder_text = "你的名字（例：艾拉·卡文迪什）"
	name_row.add_child(name_edit)
	creation_box.add_child(name_row)

	# §8#70：性别下拉。同时登记进 dropdowns，这样既能让 _selected()/镜像循环统一取用，
	# 也能让 B1 探针用通用的 _select(node, "gender", "男") 驱动。
	var gender_row := HBoxContainer.new()
	var gender_label := Label.new()
	gender_label.text = "性别"
	gender_label.custom_minimum_size = Vector2(120, 0)
	gender_row.add_child(gender_label)
	gender_dropdown = OptionButton.new()
	for index in GENDERS.size():
		gender_dropdown.add_item(GENDERS[index], index)
		gender_dropdown.set_item_metadata(index, GENDERS[index])
	dropdowns["gender"] = gender_dropdown
	gender_row.add_child(gender_dropdown)
	creation_box.add_child(gender_row)

	var age_row := HBoxContainer.new()
	var age_label := Label.new()
	age_label.text = "年龄"
	age_label.custom_minimum_size = Vector2(120, 0)
	age_row.add_child(age_label)
	age_spin = SpinBox.new()
	age_spin.min_value = 11
	age_spin.max_value = 80
	age_spin.value = 11
	age_row.add_child(age_spin)
	creation_box.add_child(age_row)

	var goal_row := HBoxContainer.new()
	var goal_label := Label.new()
	goal_label.text = "人生目标"
	goal_label.custom_minimum_size = Vector2(120, 0)
	goal_row.add_child(goal_label)
	goal_edit = LineEdit.new()
	goal_edit.text = "我想知道魔法到底能走多远"
	goal_row.add_child(goal_edit)
	creation_box.add_child(goal_row)

	var personality_row := HBoxContainer.new()
	var personality_label := Label.new()
	personality_label.text = "性格关键词"
	personality_label.custom_minimum_size = Vector2(120, 0)
	personality_row.add_child(personality_label)
	personality_edit = LineEdit.new()
	personality_edit.text = "好奇,固执,怕黑"
	personality_row.add_child(personality_edit)
	creation_box.add_child(personality_row)

	var start := Button.new()
	start.text = "开始人生"
	start.pressed.connect(_on_start_pressed)
	creation_box.add_child(start)

	# 重启后允许直接读档，不必先创建角色（否则「先创建再点读档」会覆盖刚创建的世界）
	var load_btn := Button.new()
	load_btn.text = "读取存档"
	load_btn.pressed.connect(_on_load)
	creation_box.add_child(load_btn)

	if _debug_mirror:
		for key in ["era_id", "bloodline_id", "birth_identity_id", "aptitude_id", "house_id",
				"political_leaning_id", "sim_style_id", "gender"]:
			_mirror("[创建界面] %s 选项数=%d 当前=%s" % [key, (dropdowns[key] as OptionButton).item_count, _selected(key)])

func _selected(key: String) -> String:
	var option: OptionButton = dropdowns[key]
	return str(option.get_item_metadata(option.selected))

func _on_start_pressed() -> void:
	var choices := {
		"era_id": _selected("era_id"),
		"bloodline_id": _selected("bloodline_id"),
		"birth_identity_id": _selected("birth_identity_id"),
		"name_text": name_edit.text,
		"gender": str(gender_dropdown.get_item_metadata(gender_dropdown.selected)),
		"age_years": int(age_spin.value),
		"birthplace": "london_muggle",
		"family_status": "由系统生成",
		"aptitude_id": _selected("aptitude_id"),
		"aptitude_special": "",
		"wand": {},
		"house_id": _selected("house_id"),
		"political_leaning_id": _selected("political_leaning_id"),
		"personality": _personality_words(),
		"life_goal": goal_edit.text,
		"sim_style_id": _selected("sim_style_id"),
	}
	for key in ["era_id", "bloodline_id", "birth_identity_id", "aptitude_id", "house_id", "political_leaning_id", "sim_style_id"]:
		_mirror("[创建] %s = %s" % [key, str(choices[key])])
	_mirror("[创建] 姓名=%s 性别=%s 年龄=%d 目标=%s 性格=%s" % [choices["name_text"], choices["gender"],
		choices["age_years"], choices["life_goal"], str(choices["personality"])])
	rng = RngService.new(SEED_SALT + Time.get_ticks_msec() % 100000)
	var result := CharacterCreation.create(choices, registry, rng)
	if result.errors.size() > 0:
		_show_creation_error("创建失败：\n%s" % "\n".join(result.errors))
		return
	_mirror("[创建] 成功：%s（种子 %d）" % [result.player.name_text, rng.seed_value])
	world = WorldState.create(choices["era_id"], result.player, rng.seed_value, registry)
	engine = TurnEngine.new(world, _build_gm(), rng)
	creation_box.visible = false
	play_box.visible = true
	_append("【原著优先级别已启用】本世界以《哈利·波特》原著七部小说为正典。")
	_append("%s，%d岁。你的人生开始了。" % [world.player.name_text, world.player.age_years()])
	_append(PanelFormatter.player_panel(world))
	_sync_bgm()
	_refresh_slots()
	command_edit.grab_focus()

func _personality_words() -> Array:
	# LineEdit.text.split() 返回 PackedStringArray；校验器要求 Array，这里显式转换
	var words: Array = []
	for raw in personality_edit.text.split(","):
		var word := str(raw).strip_edges()
		if not word.is_empty():
			words.append(word)
	return words

func _build_gm() -> GameMaster:
	if _llm_provider != null:
		_llm_provider.dispose()      # §8#63：避免每切一次生命周期泄漏一个 HTTPRequest
		_llm_provider = null
	var settings := LlmSettings.load_from()
	if settings.is_configured():
		_llm_provider = OpenAiCompatProvider.from_settings(self, settings)
		return LlmGameMaster.new(_llm_provider, ScriptedGameMaster.new(rng), settings)
	_set_status(status_label.text + "（未配置 LLM，使用本地叙事替身；配置见 user://llm_settings.json）")
	return ScriptedGameMaster.new(rng)

func _append(text: String) -> void:
	log_view.append_text(text + "\n")
	_mirror(text)

# 状态行是所有「未配置提示」的唯一落点（创建路径与此后的读档路径共用），故这里也镜像。
func _set_status(text: String) -> void:
	status_label.text = text
	_mirror("[状态行] " + text)

# 输入框可编辑性同样镜像：B1 要确认等待 LLM 期间置灰、结束后恢复。
func _set_input_enabled(enabled: bool) -> void:
	command_edit.editable = enabled
	_mirror("[输入框] editable=%s" % str(enabled))

# 创建/读档失败时，creation_box 可能仍在前台：错误必须写进可见的 creation_error，而不是隐藏的 log_view。
func _show_creation_error(message: String) -> void:
	if creation_error != null:
		creation_error.text = message
	push_warning(message)
	_mirror("[创建界面错误] " + message)
	if log_view != null:
		log_view.append_text(message + "\n")

func _on_command_submitted(text: String) -> void:
	if world == null:
		return
	# 第七十二章：自检后必须等玩家确认，才允许继续叙事
	if text.strip_edges() == "确认自检":
		if engine != null:
			engine.acknowledge_audit()
		_cue("audit_ack")
		_append("（自检已确认。世界继续向前。）")
		command_edit.text = ""
		return
	if engine == null:
		# 引擎尚未就绪（有 world 但没有 engine）：**立即**恢复并说明，不等满 turn_timeout_sec
		# （Task 10 审查 M-b；`_run_turn` 里那道 `engine == null` 守卫只保证不进 await，不能提供"立即"）
		_append(">>> %s" % text)
		_append("（回合引擎尚未就绪：请先创建角色或读取存档。）")
		command_edit.text = ""
		return
	_set_input_enabled(false)
	_set_buttons_enabled(false)
	_append(">>> %s" % text)
	_append("（世界正在回应…）")
	_cue("turn_submit")
	# §8#58/#62：把等待变成「有上限的等待」。GDScript 的 await 链一旦在内部抛错，调用方永远不会
	# 被唤醒（无 try/catch），旧实现会把输入框与整排按钮永久留在禁用态。看门狗保证恢复出口一定会走到。
	# ⚠️ 用**本轮私有的**字典（不是共享成员）：超时后旧协程可能迟到恢复，若共用成员字典，
	# 它会把 done=true 写到**新一轮**的字典上 → 要么渲染上一回合的叙事（错位），要么渲染空字典
	# 触发 result["narration"] 运行期错误 → 恢复两行被跳过 → **输入永久禁用（§8#62 回归）**。
	# Task 10 审查 Important 1（plan-mandated）的收口；Task 10 复审 P2-2：不再保留只写的成员镜像。
	var round_state := {"done": false, "result": {},
		"revealed_before": WorldFactions.visible_faction_ids(world)}
	_run_turn(text, round_state)
	var deadline := Time.get_ticks_msec() + int(maxf(turn_timeout_sec, 0.1) * 1000.0)
	while not bool(round_state.get("done", false)) and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	# 恢复出口**先于**渲染与状态行：GDScript 无 try/catch，渲染层任何运行期错误都会吞掉后面的语句（§8#62）
	_set_buttons_enabled(true)
	_set_input_enabled(true)
	command_edit.text = ""
	if not bool(round_state.get("done", false)):
		_append("（本回合超过 %.0f 秒仍未返回，已恢复输入。请求可能仍在后台；若反复发生，请检查 LLM 配置或改用本地替身。）" % turn_timeout_sec)
	else:
		_render_turn_result(round_state.get("result", {}))
		_cue("turn_done")
		# 势力揭示（spec §4）：回合前后各取一次可见派系集合做差集。用**本轮私有**字典里的
		# `revealed_before`，不引入跨回合的共享变量（Task 10 的 I1 教训）。
		var before_revealed: PackedStringArray = round_state.get("revealed_before", PackedStringArray())
		var revealed := newly_revealed(before_revealed, WorldFactions.visible_faction_ids(world))
		if revealed.size() > 0:
			_cue("faction_revealed")
			_mirror("[势力揭示] %s" % ",".join(revealed))
		# 降级（§8#61）：原因已在 warnings → op_errors → 上面已逐条打印，这里只负责发声
		var turn_result: Dictionary = round_state.get("result", {})
		if is_fallback_result(turn_result):
			_cue("llm_fallback")
		_sync_bgm()
		_refresh_slots()
	_set_status(PanelFormatter.status_line(world) + " ｜ 回合 %d" % world.clock.turn)

# 单独的协程：它的失败（运行期错误使协程中止）不会阻止 _on_command_submitted 的看门狗循环（§8#62）。
# `state` 是**调用方本轮的私有字典**：旧协程迟到恢复时只会写自己那本，不会污染新一轮。
func _run_turn(text: String, state: Dictionary) -> void:
	if engine == null:
		return          # 加固：engine 为 null 时不进 await（否则要等满 turn_timeout_sec 才恢复）
	state["result"] = await engine.submit_async(text)
	state["done"] = true

func _render_turn_result(result: Dictionary) -> void:
	# 一律用 `.get(...)` 兜底：畸形/空结果不得在这里抛错（它已在恢复出口之后，但没必要冒险）
	_append(str(result.get("narration", "")))
	var events: Array = result.get("events", [])
	if not events.is_empty():
		_append(PanelFormatter.events_block(events))
	for err in (result.get("op_errors", PackedStringArray()) as PackedStringArray):
		_append("（系统提示：%s）" % str(err))
	var audit_text := str(result.get("audit", ""))
	if audit_text != "":
		_append(audit_text)
		_append("（自检完毕。等待你的指令——输入“确认自检”继续。）")

# 等待 LLM 期间禁用整排按钮，防止“读档”等操作在 in-flight 回合中替换 world/engine。
func _set_buttons_enabled(enabled: bool) -> void:
	if button_row == null:
		return
	for child in button_row.get_children():
		if child is Button:
			(child as Button).disabled = not enabled
	_mirror("[按钮] 整排 %s" % ("可用" if enabled else "禁用"))

func _on_status() -> void:
	if world != null:
		_append(PanelFormatter.player_panel(world))

func _on_magic() -> void:
	if world != null:
		_append(PanelFormatter.magic_panel(world))

func _on_relation() -> void:
	if world != null:
		_append(PanelFormatter.relation_panel(world))

func _on_power() -> void:
	if world != null:
		_append(PanelFormatter.power_panel(world))

func _on_save() -> void:
	if world == null:
		return
	var result := SaveStore.save(SAVE_SLOT, world)
	var ok := bool(result["ok"])
	if ok:
		_cue("save_ok")
	_append("存档：%s（%s）" % ["成功" if ok else "失败", str(result["path"])])

func _on_load() -> void:
	var result := SaveStore.load_slot(SAVE_SLOT, registry)
	if not bool(result["ok"]):
		var msg := "读档失败：%s" % str(result["error"])
		if creation_box != null and creation_box.visible:
			_show_creation_error(msg)
		else:
			_append(msg)
		return
	world = result["world"]
	rng = RngService.new(world.game_seed)
	creation_box.visible = false
	play_box.visible = true
	_set_status(PanelFormatter.status_line(world) + " ｜ 回合 %d" % world.clock.turn)
	# 先设状态行，再建 GM：_build_gm 在未配置时会向状态行追加提示（F4）
	engine = TurnEngine.new(world, _build_gm(), rng)
	if creation_error != null:
		creation_error.text = ""
	_append("读档成功：%s" % str(result["path"]))
	_cue("load_ok")
	_append(PanelFormatter.player_panel(world))
	_sync_bgm()
	_refresh_slots()
	command_edit.grab_focus()

func _on_audit() -> void:
	if world == null:
		return
	_cue("audit_start")
	_append(SelfCheck.report(world))
	if engine != null:
		engine.acknowledge_audit()
		_append("（已确认自检，可继续行动。）")
