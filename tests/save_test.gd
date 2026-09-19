class_name SaveTest
extends RefCounted

func make_world() -> WorldState:
	var reg := Registry.load_default()
	var p := PlayerState.new_default()
	p.name_text = "张三"
	p.gender = "男"
	p.bloodline_id = "muggle_born"
	p.birth_identity_id = "ordinary_wizard_family"
	p.house_id = "gryffindor"
	p.age_months = 132
	p.money_knuts = 4930
	p.location_id = "london_muggle"
	p.life_goal = "我想知道魔法到底能走多远"
	p.current_goal = p.life_goal
	p.wand = {"wood": "holly", "core": "phoenix_feather", "length_inches": 11.0, "flexibility": "supple", "label": "冬青木，凤凰羽毛"}
	p.learn_spell("wingardium_leviosa")
	p.relations["npc_severus"] = {"name": "西弗勒斯·斯内普", "trust": -5}
	var w := WorldState.create("modern", p, 20260918, reg)
	w.add_fact("major", "第一次巫师会议")
	w.world_vars["war_pressure"] = 0.42
	return w

func run() -> int:
	var a := TestAssert.new()
	var reg := Registry.load_default()
	var w := make_world()

	# ---- 编解码往返 ----
	var text := SaveCodec.encode(w)
	a.is_true(text.contains(SaveCodec.HEADER), "存档含标题（第七十一章）")
	a.is_true(text.contains("checksum:"), "存档含校验和")
	var decoded := SaveCodec.decode(text, reg)
	a.is_true(bool(decoded["ok"]), "解码成功: %s" % str(decoded.get("error", "")))
	var restored: WorldState = decoded["world"]
	a.eq(restored.to_dict(), w.to_dict(), "世界状态完全往返")
	a.eq(restored.player.name_text, "张三", "中文姓名无损")
	a.eq(restored.player.money().formatted(), "10加隆 0西可 0纳特", "财富无损")
	a.is_true(restored.player.knows_spell("wingardium_leviosa"), "已掌握魔咒无损")
	a.eq(restored.player.relations.size(), 1, "关系网无损")
	a.eq(restored.world_vars["war_pressure"], 0.42, "世界变量无损")

	# ---- 校验和必须能抓出篡改 ----
	var tampered := text.replace('"game_seed":20260918', '"game_seed":1')
	var tampered_result := SaveCodec.decode(tampered, reg)
	a.is_false(bool(tampered_result["ok"]), "篡改内容必须被拒绝")
	a.is_true(str(tampered_result["error"]).contains("校验"), "错误说明为校验失败")

	# ---- 头部与版本错误 ----
	var no_header := SaveCodec.decode("这不是存档", reg)
	a.is_false(bool(no_header["ok"]), "非存档文本必须被拒绝")
	a.is_true(str(no_header["error"]).contains("标题"), "错误说明为标题缺失")
	var wrong_version := text.replace("v1", "v99")
	a.is_false(bool(SaveCodec.decode(wrong_version, reg)["ok"]), "版本不符必须被拒绝")

	# ---- checksum 函数本身 ----
	a.eq(SaveCodec.checksum("abc").length(), 64, "SHA-256 十六进制长度")
	a.eq(SaveCodec.checksum("abc"), SaveCodec.checksum("abc"), "校验和稳定")
	a.ne(SaveCodec.checksum("abc"), SaveCodec.checksum("abd"), "内容变化校验和变化")

	# ---- 校验和正确但字段结构畸形：必须 ok=false 且 world=null（decode 契约，绝不崩溃） ----
	var malformed_payloads := [
		'{"save_version":1,"player":null}',
		'{"save_version":1,"clock":123}',
		'{"save_version":1,"world_vars":[]}',
		'{"save_version":1,"npcs":123}',
		'{"save_version":1,"history":{}}',
		'{"save_version":1,"flags":[]}',
		'{"save_version":1,"rng_state":[]}',
		'{"save_version":null}',
		'{"save_version":[]}',
		'{"save_version":1,"player":{"personality":123}}',
		'{"save_version":1,"clock":{"year":[]}}',
	]
	for i in malformed_payloads.size():
		var payload: String = malformed_payloads[i]
		var crafted := "%s v1\nchecksum: %s\npayload:\n%s" % [SaveCodec.HEADER, SaveCodec.checksum(payload), payload]
		var res := SaveCodec.decode(crafted, reg)
		a.is_true(res.has("ok"), "畸形载荷 #%d 必须返回结构化结果（不能是空字典）" % i)
		a.is_false(bool(res.get("ok", true)), "畸形载荷 #%d 必须被拒绝" % i)
		a.is_true(res.get("world", null) == null, "畸形载荷 #%d 不得返回半成品世界" % i)

	# ---- 读写槽（真实 IO，测试目录独立，避免污染正式存档） ----
	var test_dir := "user://test_saves"
	for slot in SaveStore.list_slots(test_dir):
		SaveStore.delete_slot(str(slot), test_dir)
	var saved := SaveStore.save("slot1", w, test_dir)
	a.is_true(bool(saved["ok"]), "保存成功: %s" % str(saved.get("error", "")))
	a.is_true(str(saved["path"]).contains("slot1"), "返回保存路径")
	a.eq(SaveStore.list_slots(test_dir).size(), 1, "列出 1 个存档")
	var loaded := SaveStore.load_slot("slot1", reg, test_dir)
	a.is_true(bool(loaded["ok"]), "读取成功")
	a.eq((loaded["world"] as WorldState).to_dict(), w.to_dict(), "读回的世界与保存前一致")
	a.is_false(bool(SaveStore.load_slot("不存在的槽", reg, test_dir)["ok"]), "缺失槽必须报错，而不是崩溃")
	a.is_true(SaveStore.delete_slot("slot1", test_dir), "删除成功")
	a.eq(SaveStore.list_slots(test_dir).size(), 0, "删除后为空")

	# 槽路径净化：不得逃逸 base_dir
	for raw_slot in ["../evil", "a/b\\c:d", "  ", ".."]:
		var p := SaveStore.slot_path(str(raw_slot), "user://test_saves")
		a.is_true(p.begins_with("user://test_saves/"), "槽路径不逃逸: %s" % str(raw_slot))
		a.is_false(p.contains("../"), "槽路径不含 ../: %s" % str(raw_slot))
	a.is_true(SaveStore.slot_path("", "user://test_saves").ends_with("slot.json"), "空槽名回退 slot")
	# 缺失目录 / 缺失槽
	a.eq(SaveStore.list_slots("user://no_such_dir_xyz").size(), 0, "缺失目录列为空")
	a.is_false(SaveStore.delete_slot("不存在槽", test_dir), "删除缺失槽返回 false")
	# 校验和负例
	a.eq(SaveCodec.checksum("").length(), 64, "空串校验和长度 64")
	a.is_false(bool(SaveCodec.decode(text.replace("checksum: ", "checksum: zz"), reg)["ok"]), "非十六进制校验和被拒")
	# 覆盖保存
	var overwrite := SaveStore.save("slot1", w, test_dir)
	a.is_true(bool(overwrite["ok"]), "覆盖保存成功")
	a.eq(SaveStore.list_slots(test_dir).size(), 1, "覆盖后仍只有一个槽")
	SaveStore.delete_slot("slot1", test_dir)

	# ---- 存读档后世界必须继续一致演化（随机流状态被持久化） ----
	var w2 := make_world()
	var rng := RngService.new(w2.game_seed)
	var engine := TurnEngine.new(w2, ScriptedGameMaster.new(rng), rng)
	# 两次都走「打工」：该分支消费引擎 RNG 的 work 流，使存档里带的是「已推进」的流状态，而不是空转的 world 流
	engine.submit("我要去对角巷打工赚钱")
	engine.submit("我要去对角巷打工赚钱")
	var snapshot_text := SaveCodec.encode(w2)
	var restored2: WorldState = SaveCodec.decode(snapshot_text, reg)["world"]

	# 存档必须携带「已推进」的 work 流，否则本块与端到端块都会空转
	var probe := RngService.new(w2.game_seed)
	probe.stream_int("work", 0, 20)
	probe.stream_int("work", 0, 20)
	var expected_third := probe.stream_int("work", 0, 20)
	var restored_probe := RngService.new(w2.game_seed)
	restored_probe.load_state(w2.rng_state)
	a.eq(restored_probe.stream_int("work", 0, 20), expected_third, "存档携带已推进的 work 流（下一次抽数等于第 3 次）")

	var rng_a := RngService.new(w2.game_seed)
	rng_a.load_state(w2.rng_state)
	var expected_draws: Array = []
	for i in 20:
		expected_draws.append(rng_a.stream_int("work", 0, 20))

	var rng_b := RngService.new(restored2.game_seed)
	rng_b.load_state(restored2.rng_state)
	for i in 20:
		a.eq(rng_b.stream_int("work", 0, 20), int(expected_draws[i]), "读档后第 %d 次 work 随机数一致" % i)

	# ---- 存档后重建引擎继续提交，必须与原时间线逐字一致（HANDOFF §8#34 端到端；Task 10 强制补充） ----
	var w3 := make_world()
	var rng3 := RngService.new(w3.game_seed)
	var engine3 := TurnEngine.new(w3, ScriptedGameMaster.new(rng3), rng3)
	# 第一击就消费 work 流，检查点才能携带已推进的随机状态；若 rng_state 未被持久化，重建引擎会重放第一次抽数
	engine3.submit("我要去对角巷打工赚钱")
	var checkpoint := SaveCodec.encode(w3)
	var w3r: WorldState = SaveCodec.decode(checkpoint, reg)["world"]
	var r_orig := engine3.submit("我要去对角巷打工赚钱")
	var rng3r := RngService.new(w3r.game_seed)
	var engine3r := TurnEngine.new(w3r, ScriptedGameMaster.new(rng3r), rng3r)
	var r_copy := engine3r.submit("我要去对角巷打工赚钱")
	a.eq(r_copy.narration, r_orig.narration, "读档后重建引擎续跑：叙事一致")
	a.eq(w3r.to_dict(), w3.to_dict(), "读档后重建引擎续跑：世界状态一致")

	return a.report("save")
