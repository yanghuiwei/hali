class_name LlmTest
extends RefCounted

func run() -> int:
	var a := TestAssert.new()

	# ---- MockLlmProvider ----
	var mock := MockLlmProvider.new()
	mock.queue = ["{\"ok\":1}", "{\"ok\":2}"]
	var req := LlmProvider.LlmRequest.new()
	req.system_prompt = "sys"
	req.user_prompt = "usr"
	var r1: LlmProvider.LlmResponse = await mock.complete(req)
	a.is_true(r1.ok, "第一次 mock 成功")
	a.eq(r1.text, "{\"ok\":1}", "按队列出队")
	var r2: LlmProvider.LlmResponse = await mock.complete(req)
	a.eq(r2.text, "{\"ok\":2}", "第二次出队")
	var r3: LlmProvider.LlmResponse = await mock.complete(req)
	a.is_false(r3.ok, "队列空返回失败")
	a.eq(mock.requests.size(), 3, "记录每次请求")
	a.eq(mock.requests[0].system_prompt, "sys", "请求内容被记录")

	# mock 错误注入
	var mock2 := MockLlmProvider.new()
	mock2.queue = ["{\"ok\":1}", "{\"ok\":2}"]
	mock2.errors = ["boom", ""]
	var e1: LlmProvider.LlmResponse = await mock2.complete(req)
	a.is_false(e1.ok, "错误注入生效")
	a.eq(e1.error, "boom", "错误信息保留")
	var e2: LlmProvider.LlmResponse = await mock2.complete(req)
	a.is_true(e2.ok, "第二次无错误")

	return a.report("llm")
