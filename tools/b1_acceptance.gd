extends SceneTree

# B1 自动验收探针（**不是**测试套件，不进 tools/test.sh）：
#   * 真的实例化 res://src/ui/main.tscn，真的调用界面处理器（相当于真的点按钮/回车）；
#   * 全程开 HALI_DEBUG_LOG 镜像（本进程内设环境变量），所以界面文本会原样出现在 stdout；
#   * 逐项核对计划 01 Step 6 的 8 项人工清单 + 计划 02 追加的 2 项（置灰恢复 / 未配置提示）；
#   * **不动仓库内文件**；跑动 `user://saves/slot1.json` 与 `user://llm_settings.json` 时先备份、结束恢复
#     （B1 需要确定性的离线路径，所以临时移走 llm_settings.json，跑完放回）。
#
# 用法：
#   bash tools/b1_acceptance.sh          # 推荐：带备份/恢复与结果汇总
#   或 HALI_DEBUG_LOG=1 ./Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tools/b1_acceptance.gd

const SETTINGS_PATH := "user://llm_settings.json"
const SLOT_PATH := "user://saves/slot1.json"

var _checks := 0
var _failures: PackedStringArray = PackedStringArray()
var _notes: PackedStringArray = PackedStringArray()

var _settings_existed := false
var _settings_backup := ""
var _slot_existed := false
var _slot_backup := ""

# 慢速 provider：让「等待 LLM 期间置灰」有一个真实的 in-flight 窗口。
class SlowProvider extends LlmProvider:
	var inner: MockLlmProvider = null
	var delay_ms := 400

	func complete(request: LlmProvider.LlmRequest) -> LlmProvider.LlmResponse:
		await Engine.get_main_loop().create_timer(delay_ms / 1000.0).timeout
		return inner.complete(request)

func check(cond: bool, msg: String) -> void:
	_checks += 1
	if cond:
		print("  [PASS] %s" % msg)
	else:
		_failures.append(msg)
		print("  [FAIL] %s" % msg)

func note(msg: String) -> void:
	_notes.append(msg)
	print("  [NOTE] %s" % msg)

func part(title: String) -> void:
	print("")
	print("===== %s =====" % title)

# ---------- 小工具 ----------

func _log_of(node: Node) -> String:
	# RichTextLabel.text 不会被 append_text() 更新（实测：读回来是空串），必须用 get_parsed_text()。
	return (node.get("log_view") as RichTextLabel).get_parsed_text()

func _new_scene() -> Node:
	var scene: PackedScene = load("res://src/ui/main.tscn")
	var node: Node = scene.instantiate()
	root.add_child(node)
	await process_frame  # _ready 要等第一帧（_initialize 阶段 root 还没开始处理）
	return node

func _select(node: Node, key: String, id: String) -> bool:
	var dd: Dictionary = node.get("dropdowns")
	if not dd.has(key):
		return false
	var option: OptionButton = dd[key]
	for i in option.item_count:
		if str(option.get_item_metadata(i)) == id:
			option.selected = i
			return true
	return false

func _selected(node: Node, key: String) -> String:
	var dd: Dictionary = node.get("dropdowns")
	var option: OptionButton = dd[key]
	return str(option.get_item_metadata(option.selected))

func _dropdown_count(node: Node) -> int:
	var n := 0
	for row in (node.get("creation_box") as VBoxContainer).get_children():
		for child in row.get_children():
			if child is OptionButton:
				n += 1
	return n

func _buttons_all(node: Node, disabled: bool) -> bool:
	for child in (node.get("button_row") as HBoxContainer).get_children():
		if child is Button and (child as Button).disabled != disabled:
			return false
	return true

func _world(node: Node) -> WorldState:
	return node.get("world")

func _turn(node: Node) -> int:
	return _world(node).clock.turn

func _money(node: Node) -> int:
	return _world(node).player.money_knuts

func _log_len(node: Node) -> int:
	return _log_of(node).length()

# 走真实提交路径，返回本次追加到日志的文本（含叙事、事件、提示）。
func _submit(node: Node, text: String) -> String:
	var before := _log_len(node)
	await node.call("_on_command_submitted", text)
	return _log_of(node).substr(before)

func _backup_user_files() -> void:
	if FileAccess.file_exists(SETTINGS_PATH):
		_settings_existed = true
		_settings_backup = FileAccess.get_file_as_string(SETTINGS_PATH)
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SETTINGS_PATH))
	if FileAccess.file_exists(SLOT_PATH):
		_slot_existed = true
		_slot_backup = FileAccess.get_file_as_string(SLOT_PATH)

func _restore_user_files() -> void:
	if _settings_existed:
		var f := FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
		if f != null:
			f.store_string(_settings_backup)
			f.close()
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SETTINGS_PATH))
	if _slot_existed:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://saves"))
		var f2 := FileAccess.open(SLOT_PATH, FileAccess.WRITE)
		if f2 != null:
			f2.store_string(_slot_backup)
			f2.close()
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SLOT_PATH))

func _verify_restored() -> void:
	part("收尾 · 用户文件还原")
	check(FileAccess.file_exists(SETTINGS_PATH) == _settings_existed,
		"llm_settings.json 还原（原本%s）" % ("存在" if _settings_existed else "不存在"))
	if _settings_existed:
		check(FileAccess.get_file_as_string(SETTINGS_PATH) == _settings_backup, "llm_settings.json 内容逐字一致")
	check(FileAccess.file_exists(SLOT_PATH) == _slot_existed,
		"slot1.json 还原（原本%s）" % ("存在" if _slot_existed else "不存在"))
	if _slot_existed:
		check(FileAccess.get_file_as_string(SLOT_PATH) == _slot_backup, "slot1.json 内容逐字一致")

# ---------- 主流程 ----------

func _initialize() -> void:
	# 本进程内开镜像：界面文本随 [HALI] 前缀一起进 stdout，作为 B1 的原始证据。
	OS.set_environment("HALI_DEBUG_LOG", "1")
	print("B1 自动验收开始（Godot %s）" % Engine.get_version_info().string)
	_backup_user_files()
	# 前置：B1 必须在离线路径上跑（不然会真的打网络、且状态行不会有「未配置」提示）
	check(not LlmSettings.load_from().is_configured(),
		"前置：离线路径（llm_settings.json 临时移走，HALI_LLM_API_KEY 为空）")

	var node: Node = await _new_scene()

	await _part1_creation_ui(node)
	await _part2_squib_start(node)
	await _part3_train_deduction(node)
	await _part4_work(node)
	await _part5_panels(node)
	await _part6_save_load_same_instance(node)
	var restarted: Node = await _part7_restart_and_load()
	await _part8_turn15_audit(restarted)
	await _part9_waiting_gate(restarted)

	_part10_summary()
	_restore_user_files()
	_verify_restored()
	print("  B1 自动验收最终：断言 %d 条，失败 %d 条" % [_checks, _failures.size()])
	quit(1 if _failures.size() > 0 else 0)

# 清单 1：窗口/创建界面
func _part1_creation_ui(node: Node) -> void:
	part("清单 1 · 窗口标题与创建界面 7 个下拉框")
	check(str(ProjectSettings.get_setting("application/config/name")) == "哈利·波特·魔法纪元",
		"窗口标题为「哈利·波特·魔法纪元」")
	check(str(ProjectSettings.get_setting("application/run/main_scene")) == "res://src/ui/main.tscn",
		"主场景指向 src/ui/main.tscn")
	check((node.get("creation_box") as VBoxContainer).visible, "开场显示创建界面")
	check(not (node.get("play_box") as VBoxContainer).visible, "开场不显示游戏界面")
	check(_dropdown_count(node) == 7, "创建界面有 7 个下拉框（实际 %d）" % _dropdown_count(node))
	for key in ["era_id", "bloodline_id", "birth_identity_id", "aptitude_id", "house_id",
			"political_leaning_id", "sim_style_id"]:
		var option: OptionButton = (node.get("dropdowns") as Dictionary)[key]
		check(option.item_count > 0, "下拉 %s 有选项（%d 项）" % [key, option.item_count])

# 清单 2：哑炮角色创建
func _part2_squib_start(node: Node) -> void:
	part("清单 2 · 哑炮 + 姓名/年龄/性格/目标 → 开始人生")
	check(_select(node, "bloodline_id", "squib"), "能选中血统「哑炮」")
	check(_select(node, "aptitude_id", "squib"), "能选中资质「哑炮无魔法天赋」")
	(node.get("name_edit") as LineEdit).text = "测试哑炮"
	(node.get("age_spin") as SpinBox).value = 11
	(node.get("goal_edit") as LineEdit).text = "我想知道魔法到底能走多远"
	var words: Array = (node.call("_personality_words") as Array)
	check(words.size() == 3, "三个性格关键词（实际 %d：%s）" % [words.size(), str(words)])

	var before := _log_len(node)
	node.call("_on_start_pressed")
	var block := _log_of(node).substr(before)
	var world := _world(node)
	check(world != null, "点「开始人生」后世界已创建")
	if world == null:
		return
	check((node.get("creation_box") as VBoxContainer).visible == false, "开始人生后创建界面关闭")
	check((node.get("play_box") as VBoxContainer).visible, "开始人生后游戏界面显示")
	check(block.contains("《哈利·波特·魔法纪元·人生状态》"), "出现人生状态面板")
	check(block.contains("【血统】哑炮"), "面板【血统】显示「哑炮」")
	check(world.player.bloodline_id == "squib", "状态里 bloodline_id=squib")
	# 计划 02 追加：未配置 LLM 时状态行必须提示（**创建路径**）
	check((node.get("status_label") as Label).text.contains("未配置 LLM"),
		"创建路径：状态行提示「未配置 LLM」")
	# 哑炮的规则后果
	check(world.player.flags.get("no_magic", false), "哑炮 no_magic=true")
	check(world.player.magic_tier == MagicLevel.Tier.SQUIB, "哑炮 magic_tier=SQUIB")
	check(world.player.wand.is_empty(), "哑炮没有魔杖")
	check(world.player.magic.get("known_spells", []).is_empty(), "哑炮没有已掌握魔咒")
	note("观察（§8#69）：哑炮的 house_id = %s（正典里哑炮不进霍格沃茨）" % world.player.house_id)
	note("观察（§8#70）：姓名来自输入框，性别恒为「%s」（创建界面没有性别输入）" % world.player.gender)

# 清单 3：练魔药收益递减
func _part3_train_deduction(node: Node) -> void:
	part("清单 3 · 连续三次「我要练习魔药学」→ 回合 +1，第三次收益下降")
	for i in 3:
		var turn_before := _turn(node)
		var block := await _submit(node, "我要练习魔药学")
		check(_turn(node) == turn_before + 1, "第 %d 次练药推进一个回合（%d → %d）" % [i + 1, turn_before, _turn(node)])
		check(block.contains("魔药"), "第 %d 次有魔药学叙事" % [i + 1])
		check((node.get("status_label") as Label).text.contains("回合 %d" % _turn(node)),
			"第 %d 次状态行回合数同步为 %d" % [i + 1, _turn(node)])
		if i == 2:
			var deducted := block.contains("收益下降") or block.contains("几乎没有任何进步")
			check(deducted, "第三次旁白体现收益递减（实际：%s）" % block.strip_edges().replace("\n", " / "))
	note("观察：连续三次练药后 potions = %d" % _world(node).player.skill("potions"))

# 清单 4：打工赚钱
func _part4_work(node: Node) -> void:
	part("清单 4 · 「我去对角巷打工赚钱」→ 财富增加")
	var before := _money(node)
	var block := await _submit(node, "我去对角巷打工赚钱")
	check(_money(node) > before, "财富增加（%d → %d 纳特）" % [before, _money(node)])
	check(block.contains("赚到"), "打工叙事出现「赚到」")

# 清单 5：魔法 / 关系 / 势力面板
func _part5_panels(node: Node) -> void:
	part("清单 5 · 「魔法」「关系」「势力」面板可读（哑炮分支）")
	var before := _log_len(node)
	node.call("_on_magic")
	var magic_block := _log_of(node).substr(before)
	check(magic_block.contains("《哈利·波特·魔法纪元·魔法能力》"), "魔法面板有标题")
	check(magic_block.contains("未拥有"), "哑炮魔法面板显示【魔杖】未拥有")
	check(magic_block.contains("无魔法天赋"), "哑炮魔法面板显示无魔法天赋")

	before = _log_len(node)
	node.call("_on_relation")
	var rel := _log_of(node).substr(before)
	check(rel.contains("《哈利·波特·魔法纪元·社会关系》"), "关系面板有标题")

	before = _log_len(node)
	node.call("_on_power")
	var power := _log_of(node).substr(before)
	check(power.contains("《哈利·波特·魔法纪元·势力面板》"), "势力面板有标题")
	# §8#7 已由计划 03a Task 7 修复：机构级指标（法律执行/傲罗/威森加摩/国际）= 派系对该机构的 control
	# 最大值 + holder；world_vars 里已经没有机构键，不再存在「7 个标签映射到 4 个 world_vars」。
	var w_panel := _world(node)
	check(not w_panel.world_vars.has("auror_office"), "world_vars 没有机构键（指标不来自标量，§8#7 已修）")
	var auror_before := float(((WorldFactions.institution_control(w_panel)["auror_office"]) as Dictionary)["value"])
	check(power.contains("傲罗：%.2f（傲罗指挥部）" % auror_before),
		"势力面板傲罗指标 = 派系控制权 %.2f" % auror_before)
	WorldFactions.ensure_state(w_panel, "auror_office")["control"]["auror_office"] = 0.93
	before = _log_len(node)
	node.call("_on_power")
	var power2 := _log_of(node).substr(before)
	check(power2.contains("傲罗：0.93（傲罗指挥部）"), "改控制权后面板随之变化（§8#7 的行为型证据）")
	check(power2.contains("【已知势力】"), "含【已知势力】行")
	note("观察：机构级指标（法律执行/傲罗/威森加摩/国际）取自派系机构控制权 + holder；§8#7 的「7 标签→4 world_vars」错映射已在本计划修好")

	before = _log_len(node)
	node.call("_on_status")
	check(_log_of(node).substr(before).contains("《哈利·波特·魔法纪元·人生状态》"), "状态面板可读")

# 清单 6：存档 / 读档（同一实例）
func _part6_save_load_same_instance(node: Node) -> void:
	part("清单 6 · 存档成功；读档后回合数与存档前一致")
	var before := _log_len(node)
	node.call("_on_save")
	var save_block := _log_of(node).substr(before)
	check(save_block.contains("存档：成功"), "点「存档」提示成功（%s）" % save_block.strip_edges())
	var saved_turn := _turn(node)
	var saved_money := _money(node)

	await _submit(node, "我去对角巷打工赚钱")
	check(_turn(node) == saved_turn + 1, "存档后继续行动推进回合（%d → %d）" % [saved_turn, _turn(node)])

	before = _log_len(node)
	node.call("_on_load")
	var load_block := _log_of(node).substr(before)
	check(load_block.contains("读档成功"), "点「读档」提示成功")
	check(_turn(node) == saved_turn, "读档后回合数回到存档时（%d）" % saved_turn)
	check(_money(node) == saved_money, "读档后财富回到存档时（%d 纳特）" % saved_money)

# 清单 7：关掉重开 → 直接读档
func _part7_restart_and_load() -> Node:
	part("清单 7 · 关掉程序重开 → 直接读档（+ 读档路径的未配置提示 F4）")
	var fresh: Node = await _new_scene()
	check((fresh.get("creation_box") as VBoxContainer).visible, "重启后先看到创建界面")
	check((fresh.get("play_box") as VBoxContainer).visible == false, "重启后游戏界面未显示")
	var before := _log_len(fresh)
	fresh.call("_on_load")
	var block := _log_of(fresh).substr(before)
	check(block.contains("读档成功"), "重启后「读取存档」成功")
	check((fresh.get("creation_box") as VBoxContainer).visible == false, "读档后创建界面关闭")
	check((fresh.get("play_box") as VBoxContainer).visible, "读档后游戏界面显示")
	check(block.contains("《哈利·波特·魔法纪元·人生状态》"), "读档后自动打印状态面板")
	# F4：读档路径的「未配置 LLM」提示不得被状态行覆盖
	check((fresh.get("status_label") as Label).text.contains("未配置 LLM"),
		"读档路径：状态行仍显示「未配置 LLM」（F4 已闭合）")
	check((fresh.get("status_label") as Label).text.contains("回合 %d" % _turn(fresh)),
		"读档路径：状态行回合数 = %d" % _turn(fresh))
	note("观察：读档后回合数 = %d，财富 = %d 纳特" % [_turn(fresh), _money(fresh)])
	return fresh

# 清单 8：第 15 回合自检挂起与「确认自检」
func _part8_turn15_audit(node: Node) -> void:
	part("清单 8 · 第 15 回合出现自检、继续行动被拒、输入「确认自检」后可继续")
	var audit_block := ""
	var guard := 0
	while _turn(node) < SelfCheck.AUDIT_INTERVAL and guard < 40:
		guard += 1
		audit_block = await _submit(node, "我去对角巷打工赚钱")
	check(_turn(node) == SelfCheck.AUDIT_INTERVAL, "回合数到达 %d（实际 %d）" % [SelfCheck.AUDIT_INTERVAL, _turn(node)])
	check(audit_block.contains("【剧情快照】"), "出现【剧情快照】")
	check(audit_block.contains("【人设OOC自检报告】"), "出现【人设OOC自检报告】")
	check(audit_block.contains("等待你的指令"), "提示等待确认自检")
	check(bool(_world(node).flags.get("awaiting_audit_ack", false)), "状态里 awaiting_audit_ack=true")

	var turn_at_audit := _turn(node)
	var blocked := await _submit(node, "我去对角巷打工赚钱")
	check(blocked.contains("上一轮自检尚未确认"), "未确认前继续行动被拒（提示确认自检）")
	check(_turn(node) == turn_at_audit, "被拒的行动没有推进回合（仍 %d）" % _turn(node))

	var ack := await _submit(node, "确认自检")
	check(ack.contains("自检已确认"), "输入「确认自检」被接受")
	check(not bool(_world(node).flags.get("awaiting_audit_ack", false)), "确认后 awaiting_audit_ack 清除")
	var resumed := await _submit(node, "我去对角巷打工赚钱")
	check(resumed.contains("赚到"), "确认后可继续行动")
	check(_turn(node) == turn_at_audit + 1, "继续行动推进回合（%d）" % _turn(node))

# 计划 02 追加：等待 LLM 期间置灰 / 结束恢复
func _part9_waiting_gate(node: Node) -> void:
	part("计划 02 追加 · 等待 LLM 期间置灰、结束后恢复（用 400ms 慢 provider 制造真实等待窗）")
	var mock := MockLlmProvider.new()
	mock.queue = ['{"narration":"（慢速模拟）你在练习魔药学。","ops":[],"tags":["train"]}']
	var slow := SlowProvider.new()
	slow.inner = mock
	var gm := LlmGameMaster.new(slow, ScriptedGameMaster.new(RngService.new(7)), null)
	node.set("engine", TurnEngine.new(_world(node), gm, node.get("rng")))

	var co = node.call("_on_command_submitted", "我要练习魔药学")
	# 此刻协程停在 provider.complete 的 timer 上，输入框与按钮必须已置灰
	check((node.get("command_edit") as LineEdit).editable == false, "等待期输入框置灰")
	check(_buttons_all(node, true), "等待期整排按钮置灰")
	await co
	check((node.get("command_edit") as LineEdit).editable, "结束后输入框恢复")
	check(_buttons_all(node, false), "结束后整排按钮恢复")
	check(_log_of(node).contains("（慢速模拟）你在练习魔药学。"), "慢 provider 的叙事真的进了日志")
	note("观察：本条不覆盖「等待期真的永不恢复」的情形（§8#58/#62 仍开放）")

func _part10_summary() -> void:
	part("汇总")
	print("  B1 自动验收：断言 %d 条，失败 %d 条" % [_checks, _failures.size()])
	for f in _failures:
		printerr("[B1-FAIL] %s" % f)
	for n in _notes:
		print("  [观察] %s" % n)
