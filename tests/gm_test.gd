class_name GmTest
extends RefCounted

func make_world(tier := 2) -> WorldState:
	var reg := Registry.load_default()
	var p := PlayerState.new_default()
	p.name_text = "张三"
	p.bloodline_id = "half_blood"
	p.birth_identity_id = "ordinary_wizard_family"
	p.magic_tier = tier
	p.location_id = "hogwarts"
	p.sim_style_id = "mixed"
	p.age_months = 132
	p.money_knuts = 4930
	var w := WorldState.create("modern", p, 20260918, reg)
	return w

func run() -> int:
	var a := TestAssert.new()

	# ---- StateOps：未知 op 记错误但不崩 ----
	var w := make_world()
	var errs := StateOps.apply(w, [
		{"op": "add_money", "knuts": 493},
		{"op": "set_job", "job": "魔药学徒"},
		{"op": "不存在的操作", "x": 1},
		{"op": "gain_skill", "skill_id": "potions", "amount": 2},
	])
	a.eq(errs.size(), 1, "只有一个未知 op 错误")
	a.eq(w.player.money().formatted(), "11加隆 0西可 0纳特", "加钱生效")
	a.eq(w.player.job, "魔药学徒", "身份变更生效")
	a.eq(w.player.skill("potions"), 2, "技能生效")

	# 非法内容 id 不得写入
	var errs2 := StateOps.apply(w, [
		{"op": "learn_spell", "spell_id": "不存在的魔咒"},
		{"op": "set_location", "location_id": "不存在的地点"},
	])
	a.eq(errs2.size(), 2, "非法魔咒与地点都报错")
	a.is_false(w.player.knows_spell("不存在的魔咒"), "非法魔咒未写入")

	# know_fact 必须带来源（第四十三章：信息分来源可信度）
	StateOps.apply(w, [{"op": "know_fact", "fact_id": "r1", "source": "破釜酒吧传闻"}])
	a.eq(w.player.known_facts["r1"], "破釜酒吧传闻", "记录信息来源")

	# 施法 op 走 SpellResolver：过度施法不得无限累积
	var w2 := make_world(5)
	for i in 5:
		StateOps.apply(w2, [{"op": "cast_spell", "spell_id": "lumos", "conditions": {}}])
	a.is_true(int(w2.flags.get("energy_loop_count", 0)) <= 3, "低阶咒语叠加计数不超过上限")
	# 直接顶到上限，验证守卫真的拦截（不依赖掷骰结果）
	w2.flags["energy_loop_count"] = 3
	StateOps.apply(w2, [{"op": "cast_spell", "spell_id": "lumos", "conditions": {}}])
	a.is_true(str(w2.flags.get("last_cast_narration", "")).contains("上限"), "达到上限后施法被拦截")

	# ---- Progression：第七十章反刷 ----
	var w3 := make_world()
	var g1 := Progression.gain(w3, "potions", 4)
	var g2 := Progression.gain(w3, "potions", 4)
	var g3 := Progression.gain(w3, "potions", 4)
	a.eq(g1, 4, "首次训练满额")
	a.is_true(g2 < g1, "重复训练收益下降")
	a.is_true(g3 <= g2, "继续下降")
	var total := g1 + g2 + g3
	for i in 20:
		total += Progression.gain(w3, "potions", 4)
	a.eq(total, 8, "同一地点重复 23 次的总收益恰好 8（4+2+1+1，之后归零）")
	# 换地点 = 新环境（第七十章：成长来自新环境）
	w3.player.location_id = "diagon_alley"
	a.is_true(Progression.gain(w3, "potions", 4) >= 1, "换环境后重新获得成长")
	# 不同技能互不影响
	a.eq(Progression.gain(w3, "charms", 4), 4, "未训练过的技能满额")

	# ---- ScriptedGameMaster：确定性叙事替身 ----
	var w4 := make_world()
	var gm := ScriptedGameMaster.new(RngService.new(11))
	var study := gm.act(w4, "我要练习魔药学")
	a.is_true(study.narration.length() > 0, "有叙事")
	a.is_true(study.deltas.size() > 0, "产生状态增量")
	a.is_true(study.tags.has("train"), "打上 train 标签")
	var money_before := w4.player.money_knuts
	var work := gm.act(w4, "我去对角巷打工赚钱")
	a.is_true(work.deltas.size() > 0, "打工产生增量")
	a.is_true(work.tags.has("work"), "打上 work 标签")
	var unknown := gm.act(w4, "我对着墙思考宇宙的尽头")
	a.is_true(unknown.narration.length() > 0, "未知行动也要有叙事，而不是崩溃")
	a.is_true(unknown.tags.has("idle"), "未知行动归为 idle")

	# 施法意图必须能被识别并走 SpellResolver
	var cast_result := gm.act(w4, "我念出 照明咒")
	a.is_true(cast_result.tags.has("cast"), "识别施法意图")
	a.is_true(cast_result.narration.contains("照明咒") or cast_result.narration.length() > 0, "施法旁白")

	# ---- TurnEngine：世界不会停下来等玩家（第四十七章） ----
	var w5 := make_world()
	var engine := TurnEngine.new(w5, ScriptedGameMaster.new(RngService.new(22)), RngService.new(22))
	var before_year := w5.clock.year
	var before_turn := w5.clock.turn
	var r := engine.submit("我要去上课")
	a.has_key(r, "narration", "返回叙事")
	a.has_key(r, "events", "返回本月事件")
	a.eq(w5.clock.turn, before_turn + 1, "每次提交推进一个回合")
	a.is_true(w5.clock.year >= before_year, "时间向前")

	# ---- 第七十二章：第 15 回合强制自检，并且必须等待玩家确认 ----
	var w6 := make_world()
	var engine6 := TurnEngine.new(w6, ScriptedGameMaster.new(RngService.new(33)), RngService.new(33))
	var audit_seen := ""
	for i in 15:
		var res := engine6.submit("我要去上课")
		if str(res.get("audit", "")) != "":
			audit_seen = str(res["audit"])
	a.is_true(audit_seen.contains("剧情快照"), "第 15 回合输出剧情快照")
	a.is_true(audit_seen.contains("人设OOC自检报告"), "第 15 回合输出 OOC 自检报告")
	a.is_true(bool(w6.flags.get("awaiting_audit_ack", false)), "自检后挂起，等待指令")

	var blocked_res := engine6.submit("我要继续上课")
	a.is_true(bool(blocked_res.get("blocked", false)), "未确认自检前拒绝继续剧情")
	a.is_true(str(blocked_res["narration"]).contains("自检"), "提示先确认自检")
	engine6.acknowledge_audit()
	a.is_false(bool(w6.flags.get("awaiting_audit_ack", false)), "确认后解除挂起")
	var resumed := engine6.submit("我要继续上课")
	a.is_false(bool(resumed.get("blocked", false)), "确认后可以继续")

	# ---- 死亡不可逆（第五十三章）：死亡玩家不能再行动 ----
	var w7 := make_world()
	w7.player.alive = false
	var engine7 := TurnEngine.new(w7, ScriptedGameMaster.new(RngService.new(44)), RngService.new(44))
	var dead_res := engine7.submit("我要起床")
	a.is_true(bool(dead_res.get("blocked", false)), "死者无法行动")
	a.is_true(str(dead_res["narration"]).contains("死亡"), "死亡提示")

	# ---- 存档里必须留下随机流状态，读档才能续跑一致（任务 10 会用到） ----
	var w8 := make_world()
	var engine8 := TurnEngine.new(w8, ScriptedGameMaster.new(RngService.new(55)), RngService.new(55))
	engine8.submit("我要去上课")
	a.is_true(w8.rng_state.size() > 0, "回合引擎把随机流状态写回世界")

	return a.report("gm")
