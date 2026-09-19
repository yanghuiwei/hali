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

	# ---- LlmSettings ----
	var s := LlmSettings.new()
	a.is_false(s.is_configured(), "默认未配置")
	s.base_url = "https://x/v1"
	s.model = "m"
	s.api_key = "k"
	a.is_true(s.is_configured(), "三要素齐全即已配置")
	var path := "user://test_llm_settings.json"
	a.eq(s.save_to(path), OK, "写设置成功")
	var s2 := LlmSettings.load_from(path)
	a.eq(s2.base_url, "https://x/v1", "读回 base_url")
	a.eq(s2.model, "m", "读回 model")
	a.eq(s2.api_key, "k", "读回 api_key")
	DirAccess.remove_absolute(path)
	var s3 := LlmSettings.load_from("user://no_such_settings.json")
	a.is_false(s3.is_configured(), "缺失文件回退默认")

	# ---- GmResponseParser ----
	var ok := GmResponseParser.parse('{"narration":"你好","ops":[{"op":"set_job","job":"学生"}],"tags":["train","bogus"]}')
	a.is_true(ok.ok, "合法 JSON 解析成功")
	a.eq(ok.narration, "你好", "narration 取出")
	a.eq(ok.ops.size(), 1, "ops 取出")
	a.eq(ok.tags, PackedStringArray(["train"]), "tags 白名单过滤未知")
	var fenced := GmResponseParser.parse("```json\n{\"narration\":\"裹住\",\"ops\":[],\"tags\":[]}\n```")
	a.is_true(fenced.ok, "markdown 围栏可剥离")
	var no_narr := GmResponseParser.parse('{"ops":[]}')
	a.is_false(no_narr.ok, "缺 narration 失败")
	var bad_json := GmResponseParser.parse("不是 JSON")
	a.is_false(bad_json.ok, "非法 JSON 失败")
	var bad_ops := GmResponseParser.parse('{"narration":"x","ops":{}}')
	a.is_false(bad_ops.ok, "ops 非数组失败")
	var long_text := "{\"narration\":\"%s\",\"ops\":[],\"tags\":[]}" % "长".repeat(5000)
	var long_res := GmResponseParser.parse(long_text)
	a.is_true(long_res.ok, "超长叙事仍可解析")
	a.eq(long_res.narration.length(), GmResponseParser.MAX_NARRATION, "超长叙事被截断")

	return a.report("llm")
