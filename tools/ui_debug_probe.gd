extends SceneTree

# B1 辅助探针（**不是**测试套件）：headless 实例化主场景，驱动真实节点上的镜像路径，
# 供 tools/test.sh 第 4 步断言「HALI_DEBUG_LOG=1 时界面文本真的出现在 stdout」。
# 未设置该环境变量时主场景自己不 print 任何 [HALI] 行（第 3 步反向断言这一点）。
# 用法：HALI_DEBUG_LOG=1 ./Godot_..._.exe --headless --path . --script res://tools/ui_debug_probe.gd

func _initialize() -> void:
	var scene: PackedScene = load("res://src/ui/main.tscn")
	if scene == null:
		printerr("探针：无法加载主场景 res://src/ui/main.tscn")
		quit(1)
		return
	var node: Node = scene.instantiate()
	root.add_child(node)
	# _initialize 阶段 root 还没开始处理，_ready 要等第一帧才跑；主场景的 _ready 才读环境变量。
	await process_frame
	if node.get("_debug_mirror") != true:
		printerr("探针：镜像未启用（HALI_DEBUG_LOG 未生效？）")
		quit(1)
		return
	# 走一遍真实出口：叙事/面板（_append）、状态行、输入框与按钮置灰
	node.call("_append", "PROBE-APPEND-MARK")
	node.call("_set_status", "PROBE-STATUS-MARK")
	node.call("_set_input_enabled", false)
	node.call("_set_buttons_enabled", false)
	quit(0)
