class_name DebugMirror
extends RefCounted

# B1 人工 GUI 验收的观测通道：以 HALI_DEBUG_LOG=1 启动窗口时，界面文本被镜像到 stdout
# （Godot 会落进 user://logs/*.log），于是「人工点窗口 + 控制器读日志」即可完成验收，
# 不必再靠存档反推。设计约束（铁律）：**未设置 / 空 / 0 / false / off / no 时一行都不输出**，
# 程序行为与加该功能前逐字一致；镜像只读界面文本，绝不改变 UI 逻辑或游戏状态。
const PREFIX := "[HALI] "

static func enabled(raw: String) -> bool:
	var v := raw.strip_edges().to_lower()
	return not (v.is_empty() or v == "0" or v == "false" or v == "off" or v == "no")

static func from_env() -> bool:
	return enabled(OS.get_environment("HALI_DEBUG_LOG"))

static func format(text: String) -> String:
	return PREFIX + text
