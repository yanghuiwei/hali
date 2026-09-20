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
	a.is_true(" | ".join(errs2).contains("未知魔咒"), "错误信息指出未知魔咒")
	a.is_true(" | ".join(errs2).contains("未知地点"), "错误信息指出未知地点")
	a.is_false(w.player.knows_spell("不存在的魔咒"), "非法魔咒未写入")

	# know_fact 负例：空 fact_id / 空来源 / system 来源都不得写入
	var errs3 := StateOps.apply(w, [
		{"op": "know_fact", "fact_id": "", "source": "传闻"},
		{"op": "know_fact", "fact_id": "r2", "source": ""},
		{"op": "know_fact", "fact_id": "r3", "source": "system"},
	])
	a.eq(errs3.size(), 3, "know_fact 三种非法输入各报一个错")
	a.is_false(w.player.known_facts.has("r2"), "空来源未写入")
	a.is_false(w.player.known_facts.has("r3"), "system 来源未写入")

	# 输入硬化：空 key / 非数字 add_money / 空 npc_id / 非字典条都记错误且不写入
	var money_before_bad := w.player.money_knuts
	var errs4 := StateOps.apply(w, [
		{"op": "set_flag", "key": "", "value": true},
		{"op": "set_player_flag", "key": "", "value": true},
		{"op": "add_money", "knuts": "很多"},
		{"op": "relation_delta", "npc_id": "", "trust": 5},
		42,
	])
	a.eq(errs4.size(), 5, "非法输入与非法条目都记错误")
	a.is_false(w.flags.has(""), "空 flag key 未写入")
	a.is_false(w.player.flags.has(""), "空 player flag key 未写入")
	a.eq(w.player.money_knuts, money_before_bad, "非法 add_money 不改动财富")
	a.is_false(w.player.relations.has(""), "空 npc_id 未写入")

	# 合法集合：set_flag / set_player_flag / set_magic_tier / relation_delta
	var errs5 := StateOps.apply(w, [
		{"op": "set_flag", "key": "met_dumbledore", "value": true},
		{"op": "set_player_flag", "key": "owl", "value": true},
		{"op": "set_magic_tier", "tier": 5},
		{"op": "relation_delta", "npc_id": "npc_x", "trust": 3, "interest": 2, "hostility": -1},
	])
	a.eq(errs5.size(), 0, "合法集合无错误")
	a.is_true(bool(w.flags.get("met_dumbledore", false)), "set_flag 生效")
	a.is_true(bool(w.player.flags.get("owl", false)), "set_player_flag 生效")
	a.eq(w.player.magic_tier, 5, "set_magic_tier 生效")
	a.eq(int(w.player.relations["npc_x"]["trust"]), 3, "relation_delta trust 生效")
	a.eq(int(w.player.relations["npc_x"]["interest"]), 2, "relation_delta interest 生效")
	a.eq(int(w.player.relations["npc_x"]["hostility"]), -1, "relation_delta 允许负敌意增量")

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
	a.eq(int(w2.flags.get("energy_loop_count", 0)), 3, "被拦截后叠加计数不再增长")

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
	StateOps.apply(w4, work.deltas)
	a.is_true(w4.player.money_knuts > money_before, "打工后财富增加")
	var unknown := gm.act(w4, "我对着墙思考宇宙的尽头")
	a.is_true(unknown.narration.length() > 0, "未知行动也要有叙事，而不是崩溃")
	a.is_true(unknown.tags.has("idle"), "未知行动归为 idle")

	# 施法意图必须能被识别并走 SpellResolver
	var cast_result := gm.act(w4, "我念出 照明咒")
	a.is_true(cast_result.tags.has("cast"), "识别施法意图")
	a.is_true(cast_result.narration.contains("照明咒"), "施法旁白含咒语名")

	# ---- TurnEngine：世界不会停下来等玩家（第四十七章） ----
	var w5 := make_world()
	var engine := TurnEngine.new(w5, ScriptedGameMaster.new(RngService.new(22)), RngService.new(22))
	var before_year := w5.clock.year
	var before_turn := w5.clock.turn
	var r := engine.submit("我要去上课")
	a.has_key(r, "narration", "返回叙事")
	a.has_key(r, "events", "返回本月事件")
	a.eq(w5.clock.turn, before_turn + 1, "每次提交推进一个回合")
	a.eq(w5.clock.year, before_year, "9→10 月不跨年")
	a.eq(w5.clock.month, 10, "回合推进使月份前进（9→10）")

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

	var turn_before_block := w6.clock.turn
	var blocked_res := engine6.submit("我要继续上课")
	a.is_true(bool(blocked_res.get("blocked", false)), "未确认自检前拒绝继续剧情")
	a.eq(w6.clock.turn, turn_before_block, "被拒提交不推进回合")
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

	# ---- train_skill：反刷记账在 StateOps 内，GM 不再直改 world ----
	var wt := make_world()
	var before_skill := wt.player.skill("potions")
	StateOps.apply(wt, [{"op": "train_skill", "skill_id": "potions", "base_gain": 4}])
	var first_gain := wt.player.skill("potions") - before_skill
	a.eq(first_gain, 4, "首次训练满额（经 StateOps）")
	StateOps.apply(wt, [{"op": "train_skill", "skill_id": "potions", "base_gain": 4}])
	var second_gain := wt.player.skill("potions") - before_skill - first_gain
	a.is_true(second_gain < first_gain, "同地点重复训练收益下降")
	a.is_true(wt.flags.has("recent_training"), "反刷记账写入 world.flags")
	var bad_train := StateOps.apply(wt, [{"op": "train_skill", "skill_id": "不存在", "base_gain": 4}])
	a.eq(bad_train.size(), 1, "未知技能报错")

	# ---- 计划 03a：派系 op 的守卫与端到端 ----
	var fe := StateOps.apply(w, [{"op": "join_faction", "faction_id": "nope"}])
	a.is_true(" | ".join(fe).contains("未知派系"), "join_faction 未知 id 被拒")
	a.eq(w.player.faction_id, "", "被拒的加入不写状态")
	var fe2 := StateOps.apply(w, [{"op": "join_faction", "faction_id": "death_eaters"}])
	a.is_true(" | ".join(fe2).contains("未揭示"), "未揭示的派系不能加入（第四十三/五十七章）")
	var fe3 := StateOps.apply(w, [{"op": "join_faction", "faction_id": "ministry"}])
	a.eq(fe3.size(), 0, "加入公开派系无错误")
	a.eq(w.player.faction_id, "ministry", "所属写入")
	var fe4 := StateOps.apply(w, [{"op": "faction_standing_delta", "faction_id": "ministry", "delta": 5}])
	a.eq(fe4.size(), 0, "立场调整无错误")
	a.eq(w.player.standing_of("ministry"), 5, "立场累加")
	a.is_true(int(WorldFactions.state_of(w, "ministry").get("stance_to_player", 0)) > 0, "派系态度反向变化")

	# ---- 计划 03a（Task 9）：离线替身也支持派系动作（第五十章）----
	# tie-break 规则（控制器点名风险 2）：`_detect_faction()` 按 `visible_faction_ids()`（id 字典序）
	# 返回**第一个**命中者；下面「同句两个已揭示派系」的断言把这个确定性规则钉住。
	var sg := ScriptedGameMaster.new(RngService.new(7))

	# 加入：产出 join_faction，端到端写入所属
	var sw := make_world()
	WorldFactions.initialize(sw)
	var join_res := sg.act(sw, "我要加入魔法部")
	var joined := false
	for d in join_res.deltas:
		if str(d.get("op", "")) == "join_faction" and str(d.get("faction_id", "")) == "ministry":
			joined = true
	a.is_true(joined, "关键词「加入魔法部」产出 join_faction")
	a.is_true(join_res.tags.has("faction"), "派系动作打 faction 标签")
	a.is_true(join_res.narration.contains("魔法部"), "加入旁白用内容表的 label（不硬编码）")
	StateOps.apply(sw, join_res.deltas)
	a.eq(sw.player.faction_id, "ministry", "端到端：加入后所属写入")

	# 退出：产出 leave_faction，端到端清空所属
	var leave_res := sg.act(sw, "我要退出魔法部")
	var leaving := false
	for d in leave_res.deltas:
		if str(d.get("op", "")) == "leave_faction":
			leaving = true
	a.is_true(leaving, "关键词「退出」产出 leave_faction")
	StateOps.apply(sw, leave_res.deltas)
	a.eq(sw.player.faction_id, "", "端到端：退出后所属清空")

	# 支持 / 反对：产出正负立场
	var support_res := sg.act(sw, "我公开支持魔法部")
	var support_delta := 0
	for d in support_res.deltas:
		if str(d.get("op", "")) == "faction_standing_delta":
			support_delta = int(d.get("delta", 0))
	a.eq(support_delta, 5, "关键词「支持」产出 +5 立场")
	var oppose_res := sg.act(sw, "我要抗议魔法部")
	var oppose_delta := 0
	for d in oppose_res.deltas:
		if str(d.get("op", "")) == "faction_standing_delta":
			oppose_delta = int(d.get("delta", 0))
	a.eq(oppose_delta, -5, "关键词「抗议」产出 -5 立场")

	# 控制器点名风险 4：泛称别名「部长」映射到魔法部（有意），且仅在该派系可见时命中
	var minister_res := sg.act(sw, "我支持部长")
	var minister_delta := 0
	for d in minister_res.deltas:
		if str(d.get("op", "")) == "faction_standing_delta" and str(d.get("faction_id", "")) == "ministry":
			minister_delta = int(d.get("delta", 0))
	a.eq(minister_delta, 5, "泛称别名「部长」映射到魔法部")

	# 控制器点名风险 3：未揭示派系（第四十三/五十七章）
	a.eq(sg._detect_faction(sw, "我要加入食死徒"), "", "未揭示派系识别为空")
	a.eq(sg._detect_faction(sw, "我支持那个人"), "", "未揭示派系的泛称别名也不命中")
	var hidden_res := sg.act(sw, "我要加入食死徒")
	a.eq(hidden_res.deltas.size(), 0, "未揭示派系的动作不产出任何 op")
	a.is_true(hidden_res.tags.has("idle"), "未揭示派系的动作落到 idle")

	# 控制器点名风险 2：同句两个已揭示派系 → 取 id 字典序第一个（gringotts < ministry）
	var two_res := sg.act(sw, "我支持魔法部和古灵阁")
	var two_id := ""
	for d in two_res.deltas:
		if str(d.get("op", "")) == "faction_standing_delta":
			two_id = str(d.get("faction_id", ""))
	a.eq(two_id, "gringotts", "同句多派系：确定性取 id 字典序第一个")

	# 控制器点名风险 1：普通动作不得被派系分支吞掉（tags 必须走原分支，且不产出派系 op）
	var plain_cases := {
		"我去对角巷打工赚钱": "work",
		"我要练习魔药学": "train",
		"我去打听消息": "social",
		"我要休息一下": "rest",
		"我念出 照明咒": "cast",
	}
	for plain_text in plain_cases.keys():
		var plain_res := sg.act(sw, str(plain_text))
		a.is_true(plain_res.tags.has(str(plain_cases[plain_text])),
			"「%s」仍走原分支 %s" % [str(plain_text), str(plain_cases[plain_text])])
		var faction_ops := 0
		for d in plain_res.deltas:
			if ["join_faction", "leave_faction", "faction_standing_delta"].has(str(d.get("op", ""))):
				faction_ops += 1
		a.eq(faction_ops, 0, "「%s」不产出派系 op" % str(plain_text))

	# 控制器裁定：黑市别名不得含裸地点名「翻倒巷」（否则「去翻倒巷」被误判成派系动作）
	var bm_aliases: Array = sw.registry.entry("factions", "black_market").get("aliases", [])
	a.is_false(bm_aliases.has("翻倒巷"), "black_market.aliases 不再含裸地点名「翻倒巷」")
	a.is_true(bm_aliases.has("黑市"), "黑市简称保留")
	a.is_true(bm_aliases.has("翻倒巷黑市"), "黑市正式别名保留")
	a.eq(sg._detect_faction(sw, "我去翻倒巷买点材料"), "", "揭示前：裸地名不识别为派系动作")
	WorldFactions.reveal(sw, "black_market", "破釜酒吧传闻")
	a.eq(sg._detect_faction(sw, "我去翻倒巷买点材料"), "", "揭示后：裸地名仍不识别为派系动作")
	a.eq(sg._detect_faction(sw, "我要加入翻倒巷黑市"), "black_market", "揭示后：正式别名「翻倒巷黑市」可识别")
	a.eq(sg._detect_faction(sw, "我要加入黑市"), "black_market", "揭示后：简称「黑市」可识别")

	# ---- Task 9 审查 M1：畸形 aliases（非数组）不得中止整个套件 ----
	var copied := {}
	for table_name in Registry.TABLE_FILES.keys():
		var rows := []
		for rid in sw.registry.ids(table_name):
			rows.append(sw.registry.entry(table_name, str(rid)).duplicate(true))
		copied[table_name] = rows
	for row in copied["factions"]:
		if str(row.get("id", "")) == "black_market":
			row["aliases"] = "黑市"        # 畸形：应为数组，这里故意给字符串
	var bad_reg := Registry.from_tables(copied)
	var bad_p := PlayerState.new_default()
	bad_p.location_id = "diagon_alley"
	var bad_w := WorldState.create("modern", bad_p, 7, bad_reg)
	WorldFactions.ensure_state(bad_w, "black_market")["revealed"] = true
	var bad_sg := ScriptedGameMaster.new(RngService.new(7))
	a.eq(bad_sg._detect_faction(bad_w, "我要加入黑市"), "", "畸形 aliases 被安全跳过（不崩、也不误匹配）")
	a.eq(bad_sg._detect_faction(bad_w, "我要加入翻倒巷黑市"), "black_market", "畸形 aliases 不影响 label 匹配")
	# 判别性证据：`as Array` 遇非数组会**运行期报错并中止本函数**（实测不是返回 null）——
	# 旧实现在遇到 black_market（id 字典序靠前）时直接中止，后续派系再也扫不到。
	a.eq(bad_sg._detect_faction(bad_w, "我要支持古灵阁"), "gringotts",
		"畸形 aliases 不得阻断后续派系的识别（旧实现必红）")
	var bad_res := bad_sg.act(bad_w, "我要加入黑市")
	a.eq(bad_res.deltas.size(), 0, "畸形 aliases 下产出的 deltas 为空（落 idle）")

	# ---- Task 9 审查 M3：退出派系必须与旁白一致（旧行为会清错归属） ----
	var lw := make_world()
	WorldFactions.initialize(lw)
	lw.player.faction_id = "ministry"
	var lres := ScriptedGameMaster.new(RngService.new(5)).act(lw, "我要退出古灵阁")
	a.eq(lres.deltas.size(), 0, "非成员退出某派系：不产出 op")
	a.is_true(lres.narration.contains("并不属于"), "并如实说明并不属于该派系")
	a.is_true(lres.narration.contains("魔法部"), "旁白指出当前归属")
	StateOps.apply(lw, lres.deltas)
	a.eq(lw.player.faction_id, "ministry", "原归属不被误清")
	var ok_res := ScriptedGameMaster.new(RngService.new(5)).act(lw, "我要退出魔法部")
	var has_leave := false
	for d in ok_res.deltas:
		if str(d.get("op", "")) == "leave_faction":
			has_leave = true
	a.is_true(has_leave, "成员退出自己的派系：产出 leave_faction")
	StateOps.apply(lw, ok_res.deltas)
	a.eq(lw.player.faction_id, "", "退出后无所属")
	# StateOps 侧的第二道门（LLM 路径也一并堵住）
	lw.player.faction_id = "ministry"
	var lerrs := StateOps.apply(lw, [{"op": "leave_faction", "faction_id": "gringotts"}])
	a.is_true(" | ".join(lerrs).contains("不是该派系"), "指定别的派系退出被拒并给出警告")
	a.eq(lw.player.faction_id, "ministry", "被拒的退出不改变归属")
	var lerrs2 := StateOps.apply(lw, [{"op": "leave_faction"}])
	a.eq(lerrs2.size(), 0, "不带 faction_id 的退出仍兼容（清空）")
	a.eq(lw.player.faction_id, "", "兼容路径真的清空")

	return a.report("gm")
