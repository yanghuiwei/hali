extends SceneTree

const SUITE_TIMEOUT_SEC := 300.0

# 每个任务把自己的套件追加到这里。路径必须真实存在，缺失即失败。
const SUITES: Array[String] = [
	"res://tests/harness_test.gd",
	"res://tests/registry_test.gd",
	"res://tests/money_test.gd",
	"res://tests/magic_level_test.gd",
	"res://tests/model_test.gd",
	"res://tests/clock_test.gd",
	"res://tests/world_tick_test.gd",
	"res://tests/creation_test.gd",
	"res://tests/spell_test.gd",
	"res://tests/gm_test.gd",
	"res://tests/panel_test.gd",
	"res://tests/selfcheck_test.gd",
	"res://tests/save_test.gd",
	"res://tests/async_probe_test.gd",
	"res://tests/llm_test.gd",
	"res://tests/prompt_test.gd",
	"res://tests/debug_mirror_test.gd",
]

func _initialize() -> void:
	# 看门狗：async 化后，若某个套件的协程永不恢复，_initialize 会永久挂起（await 卡死）。
	# SceneTreeTimer 独立于 await 持续推进，保证任何情况下最终都能 quit()——Task 1 的硬要求。
	create_timer(SUITE_TIMEOUT_SEC).timeout.connect(func() -> void:
		printerr("测试总超时（%.0f 秒），强制退出" % SUITE_TIMEOUT_SEC)
		quit(1))
	var total_failures := 0
	var failed_suites := 0
	for path in SUITES:
		# 有风险的调用（读文件、load、new、run）全部收在 _run_suite 里：
		# 套件抛出的运行期错误只中止那个函数，_initialize 仍会走到末尾的打印与 quit()。
		var result: Variant = await _run_suite(path)
		if result == null:
			total_failures += 1
			failed_suites += 1
			continue
		var failures := int(result)
		if failures > 0:
			failed_suites += 1
		total_failures += failures
	print("==== 总计失败=%d，失败套件=%d ====" % [total_failures, failed_suites])
	if total_failures > 0:
		quit(1)
	else:
		print("ALL TESTS PASSED")
		quit(0)

# 返回套件失败数；套件缺失 / 无法加载 / 无法实例化 / 运行中抛错时返回 null。
func _run_suite(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		printerr("缺少测试套件: ", path)
		return null
	var script: GDScript = load(path)
	if script == null:
		# 有些加载失败会让 load() 返回 null
		printerr("套件无法加载（语法错误？）: ", path)
		return null
	if not script.can_instantiate():
		# 语法错误的脚本 load() 会返回非 null 的坏 GDScript，new() 会抛错并中止本函数
		printerr("套件无法实例化（语法错误？）: ", path)
		return null
	var suite = script.new()
	var reports_before := TestAssert.report_calls
	var result = await suite.run()
	# 运行期错误会让 suite.run() 提前中止（typed int 函数返回 0），单看返回值无法区分 0 失败与根本没跑完。
	# 用 report() 调用计数做哨兵：没调用 report 就说明套件中途报错。
	if TestAssert.report_calls == reports_before:
		printerr("套件未正常结束（未调用 report，运行期错误？）: ", path)
		return null
	if typeof(result) != TYPE_INT:
		printerr("套件未返回整数结果（运行期错误？）: ", path)
		return null
	return int(result)
