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
	a.eq(long_res.narration.length(), 4000, "超长叙事被截断到字面量 4000（不依赖常量自指）")
	var bad_narr := GmResponseParser.parse('{"narration":123,"ops":[]}')
	a.is_false(bad_narr.ok, "narration 非字符串失败")
	var bad_tags := GmResponseParser.parse('{"narration":"x","ops":[],"tags":{}}')
	a.is_false(bad_tags.ok, "tags 非数组失败")

	# ---- OpGuard ----
	var gw := Registry.load_default()
	var gp := PlayerState.new_default()
	gp.location_id = "hogwarts"
	var gworld := WorldState.create("modern", gp, 1, gw)
	var gres := OpGuard.sanitize_detailed(gworld, [
		{"op": "gain_skill", "skill_id": "potions", "amount": 99},
		{"op": "add_money", "knuts": 999999},
		{"op": "relation_delta", "npc_id": "npc_a", "trust": 999, "hostility": -999},
		{"op": "set_magic_tier", "tier": 9},
		{"op": "set_flag", "key": "_gm_rng_counter", "value": 0},
		{"op": "know_fact", "fact_id": "f1", "source": "system"},
		{"op": "cast_spell", "spell_id": "lumos", "conditions": {}},
	])
	a.eq(gres.ops[0]["op"], "train_skill", "gain_skill 被改写为 train_skill")
	a.eq(gres.ops[0]["base_gain"], 4, "忽略 LLM 的 amount")
	a.eq(gres.ops[1]["knuts"], OpGuard.MAX_MONEY_GAIN, "add_money 钳到上限")
	a.eq(gres.ops[2]["trust"], OpGuard.MAX_RELATION_DELTA, "relation_delta 正向上限")
	a.eq(gres.ops[2]["hostility"], -OpGuard.MAX_RELATION_DELTA, "relation_delta 负向下限")
	a.is_true(absi(int(gres.ops[3]["tier"]) - gp.magic_tier) <= 1, "set_magic_tier 只允许 ±1")
	a.eq(gres.ops.size(), 5, "拒绝保留 flag 与 system 来源后剩 5 个 op")
	var has_reserved := false
	for o in gres.ops:
		if str(o.get("op", "")) == "set_flag" and str(o.get("key", "")).begins_with("_"):
			has_reserved = true
	a.is_false(has_reserved, "下划线 flag 被拒")
	a.is_false(gres.ops.has({"op": "know_fact", "fact_id": "f1", "source": "system"}), "system 来源被拒")
	a.is_true(gres.warnings.size() >= 3, "产生警告")
	var many: Array = []
	for i in 50:
		many.append({"op": "set_job", "job": "x"})
	a.eq(OpGuard.sanitize(gworld, many).size(), OpGuard.MAX_OPS, "ops 数量截断")
	var weird := OpGuard.sanitize_detailed(gworld, [{"op": "add_money", "knuts": {}}, {"op": "relation_delta", "npc_id": "n", "trust": "x"}])
	a.eq(weird.ops[0]["knuts"], 0, "畸形 knuts 视为 0，不崩")
	a.eq(weird.ops[1]["trust"], 0, "畸形 trust 视为 0，不崩")

	# ---- LlmGameMaster ----
	var mworld := Registry.load_default()
	var mp := PlayerState.new_default()
	mp.name_text = "李雷"
	mp.location_id = "hogwarts"
	var lw := WorldState.create("modern", mp, 3, mworld)
	var provider := MockLlmProvider.new()
	provider.queue = [
		"不是 JSON",
		'{"narration":"你在城堡里练了一晚魔药。","ops":[{"op":"gain_skill","skill_id":"potions","amount":99}],"tags":["train"]}',
	]
	var scripted := ScriptedGameMaster.new(RngService.new(3))
	var gm := LlmGameMaster.new(provider, scripted)
	var res: GameMaster.GmResult = await gm.act(lw, "我要练习魔药学")
	a.eq(res.narration, "你在城堡里练了一晚魔药。", "第二次尝试拿到叙事")
	a.eq(res.deltas[0]["op"], "train_skill", "ops 经 OpGuard 净化")
	a.eq(res.tags, PackedStringArray(["train"]), "tags 透传")
	# 全部失败 → 降级 Scripted
	var bad := MockLlmProvider.new()
	bad.queue = ["x", "y"]
	bad.errors = ["net", "net"]
	var gm2 := LlmGameMaster.new(bad, ScriptedGameMaster.new(RngService.new(3)))
	var res2: GameMaster.GmResult = await gm2.act(lw, "我要去对角巷打工赚钱")
	a.is_true(res2.narration.contains("本地规则结算"), "降级提示出现")
	# 无 provider → 降级
	var gm3 := LlmGameMaster.new(null, ScriptedGameMaster.new(RngService.new(3)))
	var res3: GameMaster.GmResult = await gm3.act(lw, "我要去上课")
	a.is_true(res3.narration.length() > 0, "无 provider 也有叙事")

	# ---- §8#66：settings 的 temperature/max_tokens/timeout 必须真的进入请求 ----
	var cfg := LlmSettings.new()
	cfg.temperature = 0.42
	cfg.max_tokens = 4321
	cfg.timeout_ms = 55555
	var sp := MockLlmProvider.new()
	sp.queue = [
		"不是 JSON",
		'{"narration":"修复轮之后再试一次。","ops":[],"tags":[]}',
	]
	var sgm := LlmGameMaster.new(sp, ScriptedGameMaster.new(RngService.new(3)), cfg)
	var sres: GameMaster.GmResult = await sgm.act(lw, "我要练习魔药学")
	a.eq(sp.requests.size(), 2, "两次尝试都被记录")
	a.eq(sp.requests[0].temperature, 0.42, "首次请求带上 settings.temperature")
	a.eq(sp.requests[0].max_tokens, 4321, "首次请求带上 settings.max_tokens")
	a.eq(sp.requests[0].timeout_ms, 55555, "首次请求带上 settings.timeout_ms")
	# 解析失败后的重试请求（build_repair 路径）同样必须带上，否则重试仍会撞同一个预算墙
	a.eq(sp.requests[1].max_tokens, 4321, "重试请求同样带上 settings.max_tokens")
	a.eq(sp.requests[1].timeout_ms, 55555, "重试请求同样带上 settings.timeout_ms")
	a.is_true(sres.narration.contains("修复轮"))
	# 向后兼容：不传 settings 时仍用 `LlmRequest` 类默认值（不得崩）
	a.eq(provider.requests[0].max_tokens, 1024, "未传 settings 时沿用类默认值 max_tokens")
	a.eq(provider.requests[0].temperature, 0.8, "未传 settings 时沿用类默认值 temperature")
	a.eq(provider.requests[0].timeout_ms, 30000, "未传 settings 时沿用类默认值 timeout_ms")

	# ---- TurnEngine.submit_async 端到端（mock GM，不联网） ----
	var ereg := Registry.load_default()
	var ep := PlayerState.new_default()
	ep.name_text = "韩梅梅"
	ep.location_id = "hogwarts"
	var ew := WorldState.create("modern", ep, 5, ereg)
	var rng := RngService.new(5)
	var eprovider := MockLlmProvider.new()
	eprovider.queue = [
		'{"narration":"你练成了。","ops":[{"op":"gain_skill","skill_id":"potions","amount":99}],"tags":["train"]}',
		'{"narration":"又练了一月。","ops":[{"op":"add_money","knuts":999999}],"tags":["work"]}',
	]
	var egm := LlmGameMaster.new(eprovider, ScriptedGameMaster.new(rng))
	var engine := TurnEngine.new(ew, egm, rng)
	var before_turn := ew.clock.turn
	var out: Dictionary = await engine.submit_async("我要练习魔药学")
	a.eq(str(out["narration"]), "你练成了。", "异步提交返回叙事")
	a.eq(ew.clock.turn, before_turn + 1, "推进一回合")
	a.is_true(ew.player.skill("potions") > 0, "ops 经 StateOps 生效")
	# F1：OpGuard warning 必须进 op_errors
	var out_warn: Dictionary = await engine.submit_async("我去赚一笔")
	a.is_true((out_warn["op_errors"] as PackedStringArray).size() > 0, "OpGuard warning 进入 op_errors")
	# F5：同步 submit() 不能驱动 LlmGameMaster
	var t_sync := ew.clock.turn
	var out_sync: Dictionary = engine.submit("我要上课")
	a.is_true(bool(out_sync["blocked"]), "submit() 拒绝异步 GM")
	a.eq(ew.clock.turn, t_sync, "被拒的同步提交不推进回合")
	# 死亡玩家 blocked 且不推进
	ew.player.alive = false
	var t2 := ew.clock.turn
	var out2: Dictionary = await engine.submit_async("我要起床")
	a.is_true(bool(out2["blocked"]), "死者 blocked")
	a.eq(ew.clock.turn, t2, "blocked 不推进回合")

	# ---- OpenAiCompatProvider 纯函数 ----
	var p := OpenAiCompatProvider.new(null, "https://api.example.com/v1", "test-model", "sk-secret")
	a.eq(p._chat_url(), "https://api.example.com/v1/chat/completions", "URL 拼接")
	var lreq := LlmProvider.LlmRequest.new()
	lreq.system_prompt = "sys"
	lreq.user_prompt = "usr"
	var body = JSON.parse_string(p._build_body(lreq))
	a.eq(str(body["model"]), "test-model", "body 含 model")
	a.eq(str(body["messages"][0]["role"]), "system", "body 含 system 消息")
	a.eq(str(body["response_format"]["type"]), "json_object", "json_mode 生效")
	var headers := p._build_headers()
	a.is_true(" | ".join(headers).contains("Bearer sk-secret"), "Authorization 头")
	var resp := OpenAiCompatProvider._parse_http(200, '{"choices":[{"message":{"content":"hi"}}]}')
	a.is_true(resp.ok, "2xx 解析成功")
	a.eq(resp.text, "hi", "取出 content")
	var err_resp := OpenAiCompatProvider._parse_http(500, "server error")
	a.is_false(err_resp.ok, "非 2xx 失败")
	a.is_true(err_resp.error.contains("500"), "错误含状态码")
	var bad_body := OpenAiCompatProvider._parse_http(200, "not json")
	a.is_false(bad_body.ok, "非 JSON 失败")
	var bad_choice := OpenAiCompatProvider._parse_http(200, '{"choices":[123]}')
	a.is_false(bad_choice.ok, "choices[0] 非对象失败，不崩")
	# ---- §8#67：错误串必须能区分病因 ----
	var timeout_resp := OpenAiCompatProvider._parse_http(0, "")
	a.is_false(timeout_resp.ok, "状态 0 视为失败")
	a.is_true(timeout_resp.error.contains("超时"), "状态 0 的错误串指明连接/超时中断（不再是 HTTP 0（））")
	var truncated := OpenAiCompatProvider._parse_http(200, '{"choices":[{"finish_reason":"length","message":{"content":""}}]}')
	a.is_false(truncated.ok, "空 content 仍失败")
	a.is_true(truncated.error.contains("length"), "空 content 的错误串带上 finish_reason=length")
	a.is_true(truncated.error.contains("max_tokens"), "并提示思考型模型需提高 max_tokens")
	var empty_other := OpenAiCompatProvider._parse_http(200, '{"choices":[{"finish_reason":"stop","message":{"content":""}}]}')
	a.is_true(empty_other.error.contains("stop"), "非 length 的 finish_reason 也如实报出")
	# 复审 M-b：content 非字符串（JSON null / 数字）不得被 str() 变成非空垃圾文本
	var null_content := OpenAiCompatProvider._parse_http(200, '{"choices":[{"finish_reason":"stop","message":{"content":null}}]}')
	a.is_false(null_content.ok, "content=null 不得被判为成功")
	a.eq(null_content.text, "", "content=null 时 text 为空（不再是 <null>）")
	var num_content := OpenAiCompatProvider._parse_http(200, '{"choices":[{"message":{"content":123}}]}')
	a.is_false(num_content.ok, "content 为数字同样失败")

	return a.report("llm")
