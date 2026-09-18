class_name HarnessTest
extends RefCounted

func run() -> int:
	var a := TestAssert.new()
	a.eq(1 + 1, 2, "算术")
	a.near(1.0 / 3.0, 0.3333, 0.001, "浮点容差")
	a.between(0.5, 0.0, 1.0, "区间")
	a.is_true("张三".length() == 2, "UTF-8 中文长度")
	var parsed = JSON.parse_string('{"galleons": 17}')
	a.has_key(parsed, "galleons", "JSON 解析")
	a.eq("abc".sha256_text().length(), 64, "SHA-256 可用（存档校验和依赖它）")
	# 断言库自身必须能捕获失败，否则测试会假绿
	var probe := TestAssert.new()
	probe.eq(1, 2, "故意失败")
	a.eq(probe.failures.size(), 1, "断言库记录失败")
	a.eq(probe.report("probe"), 1, "report 返回失败数（int，不是字符串）")
	return a.report("harness")
