class_name TestAssert
extends RefCounted

var checks: int = 0
var failures: PackedStringArray = PackedStringArray()

func eq(actual, expected, msg: String = "") -> void:
	checks += 1
	if actual != expected:
		failures.append("%s: 期望 <%s>，实际 <%s>" % [msg, str(expected), str(actual)])

func ne(actual, unexpected, msg: String = "") -> void:
	checks += 1
	if actual == unexpected:
		failures.append("%s: 不应等于 <%s>" % [msg, str(unexpected)])

func is_true(cond: bool, msg: String = "") -> void:
	checks += 1
	if not cond:
		failures.append("%s: 期望为真" % msg)

func is_false(cond: bool, msg: String = "") -> void:
	checks += 1
	if cond:
		failures.append("%s: 期望为假" % msg)

func near(actual: float, expected: float, eps: float, msg: String = "") -> void:
	checks += 1
	if absf(actual - expected) > eps:
		failures.append("%s: 期望 %f ± %f，实际 %f" % [msg, expected, eps, actual])

func between(actual: float, lo: float, hi: float, msg: String = "") -> void:
	checks += 1
	if actual < lo or actual > hi:
		failures.append("%s: 期望落在 [%f, %f]，实际 %f" % [msg, lo, hi, actual])

func has_key(d: Dictionary, key, msg: String = "") -> void:
	checks += 1
	if not d.has(key):
		failures.append("%s: 缺少键 <%s>" % [msg, str(key)])

func fail(msg: String) -> void:
	checks += 1
	failures.append(msg)

func report(suite: String) -> int:
	for f in failures:
		printerr("[%s] %s" % [suite, f])
	print("[%s] 断言=%d 失败=%d" % [suite, checks, failures.size()])
	return failures.size()
