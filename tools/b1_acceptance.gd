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

var _held_co: Array = []

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

# 永不返回的 provider：验证等待期看门狗（§8#58）
class HangProvider extends LlmProvider:
	func complete(_request: LlmProvider.LlmRequest) -> LlmProvider.LlmResponse:
		await Engine.get_main_loop().create_timer(3600.0).timeout
		return LlmProvider.LlmResponse.new()

# await 链内部抛运行期错误的 provider：验证提交失败也能恢复（§8#62）
# GDScript 无 try/catch：nil 访问会中止本协程，且**调用方永远不会被唤醒**（旧实现的死锁根源）。
class BrokenProvider extends LlmProvider:
	func complete(_request: LlmProvider.LlmRequest) -> LlmProvider.LlmResponse:
		await Engine.get_main_loop().create_timer(0.05).timeout
		var broken: Node = null
		var parent_node: Node = broken.get_parent()
		if parent_node != null:
			return LlmProvider.LlmResponse.new()
		return LlmProvider.LlmResponse.new()

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

# 有上限的提交：不 await 协程本身（若被测代码没有看门狗，await 会永久挂住、破坏实验就无法产出“红”）。
# 改为观测可观测信号：提交开始 → 输入框置灰；恢复 → 输入框可编辑。
# `hold_ref=true` 时会**故意持有外层**协程引用（`_held`）：用来验证「即便持有外层句柄，
# 迟到写也不会发生」——Godot 对外层协程返回后**内层挂起链**失去唯一引用即丢弃，持有**外层**
# 句柄救不回内层链（见 `_part11b` 末尾 note 与实测 `hold_ref=true` 仍全绿）。
# 生产路径无人 await，生命周期语义更弱，因此这只用于钉住可观测契约，不代表能复现 I1。
func _submit_bounded(node: Node, text: String, timeout_sec: float, hold_ref: bool = false) -> Dictionary:
	var before := _log_len(node)
	var co = node.call("_on_command_submitted", text)
	if hold_ref:
		_held_co.append(co)
	var greyed := not (node.get("command_edit") as LineEdit).editable
	var started := Time.get_ticks_msec()
	var deadline := started + int(timeout_sec * 1000.0)
	while Time.get_ticks_msec() < deadline and not (node.get("command_edit") as LineEdit).editable:
		await process_frame
	return {
		"greyed": greyed,
		"recovered": (node.get("command_edit") as LineEdit).editable,
		"elapsed_ms": Time.get_ticks_msec() - started,
		"block": _log_of(node).substr(before),
	}

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
	await _part11_watchdog(restarted)
	await _part11b_reentrancy(restarted)
	await _part11c_null_engine(restarted)

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
	check(_dropdown_count(node) == 8, "创建界面有 8 个下拉框（7 个内容表 + §8#70 新增的性别，实际 %d）" % _dropdown_count(node))
	for key in ["era_id", "bloodline_id", "birth_identity_id", "aptitude_id", "house_id",
			"political_leaning_id", "sim_style_id", "gender"]:
		var option: OptionButton = (node.get("dropdowns") as Dictionary)[key]
		check(option.item_count > 0, "下拉 %s 有选项（%d 项）" % [key, option.item_count])

# 清单 2：哑炮角色创建
func _part2_squib_start(node: Node) -> void:
	part("清单 2 · 哑炮 + 姓名/性别/年龄/性格/目标 → 开始人生")
	check(_select(node, "bloodline_id", "squib"), "能选中血统「哑炮」")
	check(_select(node, "aptitude_id", "squib"), "能选中资质「哑炮无魔法天赋」")
	# §8#70：必须在写入姓名**之前**检查默认值，否则测的是自己刚写进去的字符串
	check((node.get("name_edit") as LineEdit).text.strip_edges() == "", "姓名框默认为空（不再预填「无名者」）")
	check(not (node.get("name_edit") as LineEdit).placeholder_text.is_empty(), "姓名框带占位提示")
	check(node.get("gender_dropdown") != null, "创建界面有性别下拉")
	check(_select(node, "gender", "男"), "能选中性别「男」")
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
	check(world.player.gender == "男", "性别取自创建界面下拉（world.player.gender=男）")
	check(world.player.house_id == "none", "§8#69：哑炮不进霍格沃茨（house_id=none，即使学院下拉默认 gryffindor）")
	note("观察（§8#69）：哑炮 house_id = %s（已按正典第七章/第二十四章修正为 none）" % world.player.house_id)
	note("观察（§8#70）：性别取自创建界面下拉 =「%s」" % world.player.gender)

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
	note("观察：本条不覆盖「等待期真的永不恢复」的情形（§8#58/#62）——下一条 Part 11 专门验")

func _part11_watchdog(node: Node) -> void:
	part("计划 03a 顺手项 · 等待期看门狗（§8#58/#62）")
	# (a) 永不返回的 provider：有上限的等待
	node.set("turn_timeout_sec", 0.4)
	node.set("engine", TurnEngine.new(_world(node),
		LlmGameMaster.new(HangProvider.new(), ScriptedGameMaster.new(RngService.new(11)), null),
		node.get("rng")))
	var a_res := await _submit_bounded(node, "我要练习魔药学", 5.0)
	check(bool(a_res["greyed"]), "永不返回时：等待期已置灰（提交真的开始了）")
	check(bool(a_res["recovered"]), "永不返回时：协程仍能返回（看门狗生效，不会永久禁用）")
	check(str(a_res["block"]).contains("已恢复输入"), "永不返回时：给出恢复提示")
	check(_buttons_all(node, false), "永不返回时：整排按钮恢复")

	# (b) await 链内部抛运行期错误：同样必须恢复
	node.set("engine", TurnEngine.new(_world(node),
		LlmGameMaster.new(BrokenProvider.new(), ScriptedGameMaster.new(RngService.new(12)), null),
		node.get("rng")))
	var b_res := await _submit_bounded(node, "我要练习魔药学", 5.0)
	check(bool(b_res["greyed"]), "await 链抛错时：等待期已置灰")
	check(bool(b_res["recovered"]), "await 链抛错时：提交仍能返回（§8#62 不再需要重启）")
	check((node.get("command_edit") as LineEdit).editable, "await 链抛错时：输入框恢复")
	check(_buttons_all(node, false), "await 链抛错时：整排按钮恢复")

	# (c) provider 卫生（§8#63）：切一次生命周期不得净增 HTTPRequest 节点
	var host := Node.new()
	root.add_child(host)
	var old_prov := OpenAiCompatProvider.new(host, "https://example.invalid/v1", "m", "k")
	old_prov.ensure_http(30000)
	var before_nodes := host.get_child_count()
	old_prov.dispose()
	var new_prov := OpenAiCompatProvider.new(host, "https://example.invalid/v1", "m", "k")
	new_prov.ensure_http(30000)
	await process_frame
	check(host.get_child_count() <= before_nodes, "切换 provider 不净增 HTTPRequest（dispose 生效）")
	new_prov.dispose()

# 修复轮 1（Task 10 审查 Important 1）：看门狗超时后，**旧协程迟到恢复**不得污染新一轮。
# 构造：第一轮用 1.5s 延迟的 provider + 0.4s 看门狗（超时恢复，但协程仍在挂起）；
# 紧接着起第二轮（3s 延迟，看门狗 5s）——旧协程会在第二轮进行中就恢复。
# 若两轮共用同一本 state 字典：旧协程会把 done=true + **上一回合的叙事**写到第二轮 →
# 第二轮被提前判定完成、渲染错位叙事、本轮结果被丢。
func _part11b_reentrancy(node: Node) -> void:
	part("修复轮 1 · 迟到协程不得污染新一轮（可观测契约，非 I1 护栏）")
	node.set("turn_timeout_sec", 0.4)
	var late_mock := MockLlmProvider.new()
	late_mock.queue = ['{"narration":"【第一轮·迟到】这段叙事绝不能在第二轮出现。","ops":[],"tags":["train"]}']
	var late := SlowProvider.new()
	late.inner = late_mock
	late.delay_ms = 1500
	node.set("engine", TurnEngine.new(_world(node),
		LlmGameMaster.new(late, ScriptedGameMaster.new(RngService.new(21)), null), node.get("rng")))
	var turn_before := _turn(node)
	var first := await _submit_bounded(node, "我要练习魔药学", 5.0, true)
	check(bool(first["recovered"]), "第一轮（1.5s 迟到 + 0.4s 看门狗）超时后恢复")
	check(not str(first["block"]).contains("【第一轮·迟到】"), "超时轮不渲染未返回的结果")
	node.set("turn_timeout_sec", 5.0)
	var second_mock := MockLlmProvider.new()
	second_mock.queue = ['{"narration":"【第二轮】你忙了一个月，赚到 30 纳特。","ops":[{"op":"add_money","knuts":30}],"tags":["work"]}']
	var second_prov := SlowProvider.new()
	second_prov.inner = second_mock
	second_prov.delay_ms = 3000
	node.set("engine", TurnEngine.new(_world(node),
		LlmGameMaster.new(second_prov, ScriptedGameMaster.new(RngService.new(22)), null), node.get("rng")))
	var second := await _submit_bounded(node, "我去对角巷打工赚钱", 8.0)
	var second_block := str(second["block"])
	check(bool(second["recovered"]), "第二轮正常恢复")
	# 「提前判完」的机制无关证据：第二轮必须等满**自己**的 provider 延迟（3s）才可能结束。
	# 若旧协程把 done=true 写到新一轮的字典上，第二轮会在 ~1.0s 就"完成"（实测过）。
	check(int(second["elapsed_ms"]) >= 2500,
		"第二轮等到自己的结果才结束、没有被旧协程提前判完（实际 %d ms，期望 ≥2500）" % int(second["elapsed_ms"]))
	check(second_block.contains("【第二轮】"), "第二轮渲染的是**本轮**的叙事")
	check(not second_block.contains("【第一轮·迟到】"), "第二轮不得混入上一回合的叙事（迟到协程污染）")
	var turn_after_second := _turn(node)
	check(turn_after_second >= turn_before + 1,
		"第二轮真的结算了自己的回合（turn %d → %d，至少推进 1）" % [turn_before, turn_after_second])
	# 时序无关的稳定性检查：被超时那一轮若还要插一脚，只可能发生在它自己的 provider 延迟（1.5s）之后、
	# 而第二轮返回时早已过了那个点，所以此后 turn 不应再变。
	await Engine.get_main_loop().create_timer(1.2).timeout
	check(_turn(node) == turn_after_second,
		"此后没有迟到的回合推进插入（turn 稳定在 %d）" % turn_after_second)
	note("说明：本组断言钉的是**可观测契约**（第二轮必须等自己的结果、不得提前判完、不得混入上一轮叙事）。" +
		"实测：即便 `hold_ref=true` 持有外层协程引用，迟到写仍未发生——Godot 在外层协程返回后会丢弃内层挂起链；" +
		"语言级实验证明『旧写法会把迟到写落进当前成员字典』的机制成立，但黑盒不可达，故本组断言对 I1 无判别力。")
	check((node.get("command_edit") as LineEdit).editable, "第二轮结束后输入框可用")
	check(_buttons_all(node, false), "第二轮结束后整排按钮可用")
	# 迟到协程若真的恢复了，也不得再改状态（再等一会儿复查；这里主要看 UI 不被锁死）
	await process_frame
	check((node.get("command_edit") as LineEdit).editable, "旧协程迟到恢复后输入框仍可用")

# engine 为 null 时必须**立即**恢复，不等满 turn_timeout_sec（审查 M-b）
func _part11c_null_engine(node: Node) -> void:
	part("修复轮 1 · engine 为空时立即恢复（M-b）")
	node.set("turn_timeout_sec", 30.0)
	node.set("engine", null)
	var started := Time.get_ticks_msec()
	var res := await _submit_bounded(node, "我要练习魔药学", 5.0)
	var elapsed := Time.get_ticks_msec() - started
	check(bool(res["recovered"]), "engine 为空时输入框恢复")
	check(elapsed < 2000, "恢复是立即的、不等满 30s 超时（实际 %d ms）" % elapsed)
	check(_buttons_all(node, false), "engine 为空时整排按钮恢复")

func _part10_summary() -> void:
	part("汇总")
	print("  B1 自动验收：断言 %d 条，失败 %d 条" % [_checks, _failures.size()])
	for f in _failures:
		printerr("[B1-FAIL] %s" % f)
	for n in _notes:
		print("  [观察] %s" % n)
