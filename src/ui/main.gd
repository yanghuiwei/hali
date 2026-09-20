extends Control

const SAVE_SLOT := "slot1"
const SEED_SALT := 20260918

var registry: Registry = null
var world: WorldState = null
var engine: TurnEngine = null
var rng: RngService = null

var root_box: VBoxContainer = null
var creation_box: VBoxContainer = null
var play_box: VBoxContainer = null
var log_view: RichTextLabel = null
var command_edit: LineEdit = null
var status_label: Label = null
var dropdowns: Dictionary = {}
var name_edit: LineEdit = null
var goal_edit: LineEdit = null
var age_spin: SpinBox = null
var personality_edit: LineEdit = null
var creation_error: Label = null
var button_row: HBoxContainer = null

# B1 人工验收用：HALI_DEBUG_LOG=1 时把界面文本镜像到 stdout（默认关闭，行为完全不变）。
var _debug_mirror: bool = false

# §8#58/#62：等待期的上限（秒）。不设 HALI_TURN_TIMEOUT_SEC 时行为与改造前一致，
# 只是多了一层「有上限的等待」——超时后一定恢复输入与按钮。
var turn_timeout_sec: float = 180.0
var _turn_state: Dictionary = {}
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
	_build_ui()
	_show_creation()

# 镜像通道的**唯一出口**：所有对外可见的界面文本都经这里，方便 B1 从外部观测。
func _mirror(text: String) -> void:
	if _debug_mirror:
		print(DebugMirror.format(text))

func _build_ui() -> void:
	root_box = VBoxContainer.new()
	root_box.set_anchors_preset(Control.PRESET_FULL_RECT)
	root_box.add_theme_constant_override("separation", 6)
	add_child(root_box)

	status_label = Label.new()
	_set_status("《哈利·波特·魔法纪元》魔法世界沙盘·超高自由度人生模拟器")
	root_box.add_child(status_label)

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
	name_edit.text = "无名者"
	name_row.add_child(name_edit)
	creation_box.add_child(name_row)

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
				"political_leaning_id", "sim_style_id"]:
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
		"gender": "未定",
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
		_append("（自检已确认。世界继续向前。）")
		command_edit.text = ""
		return
	_set_input_enabled(false)
	_set_buttons_enabled(false)
	_append(">>> %s" % text)
	_append("（世界正在回应…）")
	# §8#58/#62：把等待变成「有上限的等待」。GDScript 的 await 链一旦在内部抛错，调用方永远不会
	# 被唤醒（无 try/catch），旧实现会把输入框与整排按钮永久留在禁用态。看门狗保证恢复出口一定会走到。
	_turn_state = {"done": false, "result": {}}
	_run_turn(text)
	var deadline := Time.get_ticks_msec() + int(maxf(turn_timeout_sec, 0.1) * 1000.0)
	while not bool(_turn_state.get("done", false)) and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	if not bool(_turn_state.get("done", false)):
		_append("（本回合超过 %.0f 秒仍未返回，已恢复输入。请求可能仍在后台；若反复发生，请检查 LLM 配置或改用本地替身。）" % turn_timeout_sec)
	else:
		_render_turn_result(_turn_state["result"])
	# 恢复出口只有这一处：无论上面走的是超时还是正常分支，输入与按钮都会回来。
	_set_status(PanelFormatter.status_line(world) + " ｜ 回合 %d" % world.clock.turn)
	_set_buttons_enabled(true)
	_set_input_enabled(true)
	command_edit.text = ""

# 单独的协程：它的失败（运行期错误使协程中止）不会阻止 _on_command_submitted 的看门狗循环（§8#62）
func _run_turn(text: String) -> void:
	_turn_state["result"] = await engine.submit_async(text)
	_turn_state["done"] = true

func _render_turn_result(result: Dictionary) -> void:
	_append(str(result["narration"]))
	var events: Array = result["events"]
	if not events.is_empty():
		_append(PanelFormatter.events_block(events))
	for err in (result["op_errors"] as PackedStringArray):
		_append("（系统提示：%s）" % str(err))
	if str(result["audit"]) != "":
		_append(str(result["audit"]))
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
	_append("存档：%s（%s）" % ["成功" if bool(result["ok"]) else "失败", str(result["path"])])

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
	_append(PanelFormatter.player_panel(world))
	command_edit.grab_focus()

func _on_audit() -> void:
	if world == null:
		return
	_append(SelfCheck.report(world))
	if engine != null:
		engine.acknowledge_audit()
		_append("（已确认自检，可继续行动。）")
