class_name DebugMirrorTest
extends RefCounted

# B1 观测通道的开关语义：默认必须**逐字不改行为**，开启时必须**稳定可 grep**。
func run() -> int:
	var a := TestAssert.new()

	# 开启态：任何非空、非假值都算启用（"debug" 这类随手写的值也应生效）
	for raw in ["1", "true", "TRUE", "True", "yes", "YES", "on", "debug", " 1 ", "  True  "]:
		a.is_true(DebugMirror.enabled(str(raw)), "HALI_DEBUG_LOG=%s 应启用镜像" % str(raw))

	# 关闭态：未设置（空串）与常见假值都不得输出任何行
	for raw in ["", " ", "0", "false", "FALSE", "off", "OFF", "no", "  Off  "]:
		a.is_false(DebugMirror.enabled(str(raw)), "HALI_DEBUG_LOG=%s 应保持默认行为（不输出）" % str(raw))

	# 前缀与格式必须稳定：人工验收与 tools/test.sh 都靠它 grep
	a.eq(DebugMirror.PREFIX, "[HALI] ", "镜像前缀")
	a.eq(DebugMirror.format("abc"), "[HALI] abc", "格式化加前缀")
	a.eq(DebugMirror.format(""), "[HALI] ", "空文本也带前缀")

	# 环境变量接线：本进程的实际取值必须与同一套语义一致
	var env_raw := OS.get_environment("HALI_DEBUG_LOG")
	if env_raw == "":
		a.is_false(DebugMirror.from_env(), "未设置 HALI_DEBUG_LOG 时默认关闭")
	else:
		a.eq(DebugMirror.from_env(), DebugMirror.enabled(env_raw), "设置了 HALI_DEBUG_LOG 时按同一语义判定")

	return a.report("debug_mirror")
