extends SceneTree

# 每个任务把自己的套件追加到这里。路径必须真实存在，缺失即失败。
const SUITES: Array[String] = [
	"res://tests/harness_test.gd",
	"res://tests/registry_test.gd",
]

func _initialize() -> void:
	var total_failures := 0
	var failed_suites := 0
	for path in SUITES:
		if not FileAccess.file_exists(path):
			printerr("缺少测试套件: ", path)
			total_failures += 1
			failed_suites += 1
			continue
		var script: GDScript = load(path)
		if script == null:
			# 语法错误会让 load() 返回 null
			printerr("套件无法加载（语法错误？）: ", path)
			total_failures += 1
			failed_suites += 1
			continue
		var suite = script.new()
		var failures := int(suite.run())
		if failures > 0:
			failed_suites += 1
		total_failures += failures
	print("==== 总计失败=%d，失败套件=%d ====" % [total_failures, failed_suites])
	if total_failures > 0:
		quit(1)
	else:
		print("ALL TESTS PASSED")
		quit(0)
