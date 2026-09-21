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

	# ---- 计划 03a Task 11 · §8#65③：鸭子类型判定 + blocked 非空文案 ----
	a.is_false(ScriptedGameMaster.new(RngService.new(1)).is_async(), "离线替身声明为同步")
	a.is_true(LlmGameMaster.new(null, null, null).is_async(), "LLM 主模块声明为协程")
	var sync_world := make_world()
	WorldFactions.initialize(sync_world)
	var async_engine := TurnEngine.new(sync_world, LlmGameMaster.new(null, null, null), RngService.new(1))
	var blocked_out: Dictionary = async_engine.submit("我要去上课")
	a.is_true(bool(blocked_out["blocked"]), "同步 submit 拒绝协程 GM")
	a.is_true(not str(blocked_out["narration"]).is_empty(), "拒绝时给出非空提示（UI 不会白屏）")
	a.is_true(str(blocked_out["narration"]).contains("异步"), "提示说明要走异步路径")
	a.eq(sync_world.clock.turn, 0, "被拒的提交不推进回合")

	# ---- 计划 03a Task 11 · Task 9 审查 M4：命中派系名但四关键词都不中 → 不得抢走普通分支 ----
	var fallback_w := make_world()
	WorldFactions.initialize(fallback_w)
	var plain := ScriptedGameMaster.new(RngService.new(7)).act(fallback_w, "我去魔法部打听消息")
	a.is_true(plain.tags.has("social"), "「去魔法部打听消息」仍走 social 分支（派系名不抢分支）")
	var faction_ops := 0
	for d in plain.deltas:
		var op_name := str(d.get("op", ""))
		if op_name == "join_faction" or op_name == "leave_faction" or op_name == "faction_standing_delta":
			faction_ops += 1
	a.eq(faction_ops, 0, "回退路径不产出任何派系 op")

	# ---- 计划 03a Task 11 · Task 9 审查 M5：旁白 label 来自 registry（不是硬编码）----
	var base_reg := Registry.load_default()
	var tables := {}
	for table_name in Registry.TABLE_FILES.keys():
		var rows: Array = []
		for row_id in base_reg.ids(table_name):
			rows.append((base_reg.entry(table_name, str(row_id)) as Dictionary).duplicate(true))
		tables[table_name] = rows
	for row in (tables["factions"] as Array):
		if str((row as Dictionary).get("id", "")) == "ministry":
			(row as Dictionary)["label"] = "奥术部"
	var renamed_reg := Registry.from_tables(tables)
	a.eq(str(renamed_reg.entry("factions", "ministry").get("label", "")), "奥术部", "临时 registry 改名生效（夹具自检）")
	var renamed_w := WorldState.create("modern", PlayerState.new_default(), 7, renamed_reg)
	WorldFactions.initialize(renamed_w)
	a.eq(WorldFactions.government_id(renamed_w), WorldFactions.government_type(renamed_w), "改名 registry 下 government_id 可用（前置）")
	var renamed_res := ScriptedGameMaster.new(RngService.new(9)).act(renamed_w, "我要加入奥术部")
	a.is_true(renamed_res.narration.contains("奥术部"), "旁白使用 registry 的 label（说明不是硬编码）")
	a.is_false(renamed_res.narration.contains("魔法部"), "旁白不得出现旧 label")

	# ---- 计划 03b Task 4：4 个经济 op（存 / 取 / 汇 / 贸）+ OpGuard 钳制 ----
	# 契约见 spec §7.5。共同铁律：**校验不过就完全不执行**（不部分执行），错误走 errors 不抛异常。
	var ew := make_world()
	WorldFactions.initialize(ew)
	ew.player.money_knuts = 49300        # 100 加隆现金
	ew.player.location_id = "diagon_alley"   # zone=wizarding → local_mult 1.0

	# ---- deposit_money：正常存入 ----
	var dep_errs := StateOps.apply(ew, [{"op": "deposit_money", "knuts": 4930}])
	a.eq(dep_errs.size(), 0, "正常存入无错误")
	a.eq(ew.player.money_knuts, 49300 - 4930, "存入后现金减")
	a.eq(int(ew.economy["gringotts_balance"]), 4930, "存入后余额增")

	# ---- deposit_money：超出现金被拒，且**不部分执行** ----
	var poor := make_world()
	WorldFactions.initialize(poor)
	poor.player.money_knuts = 50
	var poor_errs := StateOps.apply(poor, [{"op": "deposit_money", "knuts": 100}])
	a.is_true(poor_errs.size() > 0, "超出现金被拒")
	a.eq(poor.player.money_knuts, 50, "被拒时不扣钱（不部分执行）")
	a.eq(int(poor.economy["gringotts_balance"]), 0, "被拒时余额不变")

	# ---- deposit_money：金额 ≤ 0 / 超过 MAX_BANK_MOVE / 非数字 ----
	var bad_dep := StateOps.apply(ew, [
		{"op": "deposit_money", "knuts": 0},
		{"op": "deposit_money", "knuts": -493},
		{"op": "deposit_money", "knuts": OpGuard.MAX_BANK_MOVE + 1},
		{"op": "deposit_money", "knuts": "很多"},
	])
	a.eq(bad_dep.size(), 4, "金额 0 / 负 / 超上限 / 非数字 各报一个错")
	a.eq(ew.player.money_knuts, 49300 - 4930, "非法存入不动现金")
	a.eq(int(ew.economy["gringotts_balance"]), 4930, "非法存入不动余额")

	# ---- withdraw_money：余额不足被拒且不部分执行 ----
	var wd_errs := StateOps.apply(ew, [{"op": "withdraw_money", "knuts": 100000}])
	a.is_true(wd_errs.size() > 0, "余额不足被拒")
	a.eq(int(ew.economy["gringotts_balance"]), 4930, "被拒时余额不变（不部分执行）")
	a.eq(ew.player.money_knuts, 49300 - 4930, "被拒时现金不变")
	# 正常取款
	var wd_ok := StateOps.apply(ew, [{"op": "withdraw_money", "knuts": 4930}])
	a.eq(wd_ok.size(), 0, "正常取款无错误")
	a.eq(int(ew.economy["gringotts_balance"]), 0, "取款后余额清零")
	a.eq(ew.player.money_knuts, 49300, "取款后现金复原")

	# ---- exchange_money：buy / sell 方向、价差 2%、余额记账 ----
	var fxw := make_world()
	WorldFactions.initialize(fxw)
	fxw.player.money_knuts = 49300
	var buy_errs := StateOps.apply(fxw, [{"op": "exchange_money", "knuts": 4930, "direction": "buy"}])
	a.eq(buy_errs.size(), 0, "buy 无错误")
	# buy：付出 4930 现金，按 foreign_rate × (1 - SPREAD) 收到外币
	a.eq(fxw.player.money_knuts, 49300 - 4930, "buy 扣现金")
	var expected_buy := int(round(float(4930) * float(fxw.economy["foreign_rate"]) * (1.0 - Economy.FOREIGN_SPREAD)))
	a.eq(int(fxw.economy["foreign_held"]), expected_buy,
		"buy 收到外币 = 金额 × rate × (1 - 2%%)")
	a.is_true(expected_buy < 4930, "价差让买入侧缩水（rate=1.0 时 %d < 4930）" % expected_buy)
	# sell：反向，且**买卖价差让 round-trip 亏钱**（否则是无限套利）
	var held_before := int(fxw.economy["foreign_held"])
	var sell_errs := StateOps.apply(fxw, [{"op": "exchange_money", "knuts": held_before, "direction": "sell"}])
	a.eq(sell_errs.size(), 0, "sell 无错误")
	a.eq(int(fxw.economy["foreign_held"]), 0, "sell 清空外币")
	var cash_after_sell := fxw.player.money_knuts
	# sell 收到的是 `knuts × rate × (1 - 价差)` —— **再打一次折**，
	# 所以一次往返（buy 打折进、sell 打折出）必然亏损，这就是 2% 价差的作用。
	var expected_sell_cash := int(round(float(held_before) * float(fxw.economy["foreign_rate"]) * (1.0 - Economy.FOREIGN_SPREAD)))
	a.eq(cash_after_sell, 49300 - 4930 + expected_sell_cash,
		"sell 收到的加隆按 (1 - 价差) 打折")
	a.is_true(cash_after_sell < 49300,
		"一次买卖往返后现金减少（49430 → %d，价差真的生效）" % cash_after_sell)
	# 负例：方向非法 / 金额非法 / 外币不足
	var bad_fx := StateOps.apply(fxw, [
		{"op": "exchange_money", "knuts": 100, "direction": "偷"},
		{"op": "exchange_money", "knuts": 0, "direction": "buy"},
		{"op": "exchange_money", "knuts": OpGuard.MAX_BANK_MOVE + 1, "direction": "buy"},
		{"op": "exchange_money", "knuts": 100, "direction": "sell"},
	])
	a.eq(bad_fx.size(), 4, "方向非法 / 金额 0 / 超上限 / 外币不足 各报一个错")
	a.eq(int(fxw.economy["foreign_held"]), 0, "失败的外汇操作不动外币")

	# ---- trade_money：断供商品被拒 ----
	var tw := make_world()
	WorldFactions.initialize(tw)
	tw.player.money_knuts = 100000
	tw.player.location_id = "forbidden_forest"      # 产区
	tw.world_vars["economy_index"] = 0.10           # 低于 SUPPLY_CUTOFF ⇒ wand_standard 断供
	var cut_errs := StateOps.apply(tw, [{
		"op": "trade_money", "good_id": "wand_standard", "qty": 1, "mode": "buy",
		"origin_location_id": "forbidden_forest", "location_id": "diagon_alley",
	}])
	a.is_true(cut_errs.size() > 0, "断供商品交易被拒")
	a.eq(tw.player.money_knuts, 100000, "被拒时不动现金")
	a.eq(int(tw.economy["smuggling_heat"]), 0, "被拒时不记走私热度")

	# ---- trade_money：产区买、常规卖，扣路费后仍为正（E7 的成立条件）----
	tw.world_vars["economy_index"] = 0.5
	var buy_price := Economy.price_at(tw, "potion_common", "forbidden_forest")
	var sell_price := Economy.price_at(tw, "potion_common", "diagon_alley")
	var haul := int(Economy.TRADE_HAUL_KNUTS["potion"])
	a.is_true(buy_price < sell_price, "产区价 < 常规价（前置）")
	a.is_true(sell_price - buy_price - 2 * haul > 0,
		"扣两份路费后价差仍为正（%d - %d - %d = %d）"
			% [sell_price, buy_price, 2 * haul, sell_price - buy_price - 2 * haul])
	var cash_before_trade := tw.player.money_knuts
	var t_errs := StateOps.apply(tw, [{
		"op": "trade_money", "good_id": "potion_common", "qty": 2, "mode": "buy",
		"origin_location_id": "forbidden_forest", "location_id": "diagon_alley",
	}])
	a.eq(t_errs.size(), 0, "合法交易无错误")
	a.eq(tw.player.money_knuts, cash_before_trade - (buy_price * 2 + haul * 2),
		"买入扣 (产区价 × qty + 路费 × qty)")

	# ---- trade_money：货值闸门（防高价商品套利，缺陷⑧ 的第二半）----
	var big_errs := StateOps.apply(tw, [{
		"op": "trade_money", "good_id": "broom_nimbus", "qty": 1, "mode": "buy",
		"origin_location_id": "forbidden_forest", "location_id": "diagon_alley",
	}])
	a.is_true(big_errs.size() > 0, "broom_nimbus 即使 qty=1 也被货值闸门拒绝")
	a.is_true(" | ".join(big_errs).contains("货值"), "错误串明确指出货值超限")
	a.eq(tw.player.money_knuts, cash_before_trade - (buy_price * 2 + haul * 2),
		"被货值闸门拒绝时不动现金")

	# ---- trade_money：两地相同 = 就地原价买卖，必须拒绝（否则不是贸易）----
	var same_errs := StateOps.apply(tw, [{
		"op": "trade_money", "good_id": "potion_common", "qty": 1, "mode": "buy",
		"origin_location_id": "diagon_alley", "location_id": "diagon_alley",
	}])
	a.is_true(same_errs.size() > 0, "同地买卖被拒（无价差就不是贸易）")

	# ---- trade_money 走私：illegal 商品记 smuggling_heat + flags ----
	# ⚠️ 夹具：全表三个 illegal 商品里只有 `illegal_potion`(4930) 的货值 qty 上限 ≥ 1
	# （`illegal_relic` 9860 / `illegal_creature` 14790 都被货值闸门钳到 0，会被拒）。
	var sw2 := make_world()
	WorldFactions.initialize(sw2)
	sw2.player.money_knuts = 100000
	sw2.player.location_id = "forbidden_forest"
	sw2.world_vars["economy_index"] = 0.5
	var heat_before := int(sw2.economy["smuggling_heat"])
	var sm_errs := StateOps.apply(sw2, [{
		"op": "trade_money", "good_id": "illegal_potion", "qty": 1, "mode": "buy",
		"origin_location_id": "forbidden_forest", "location_id": "knockturn_alley",
	}])
	a.eq(sm_errs.size(), 0, "走私品交易本身无错误（后果留 03c）")
	a.eq(int(sw2.economy["smuggling_heat"]), heat_before + 1, "illegal 商品走私热度 +1")
	a.is_true(bool(sw2.flags.get("illegal_trade", false)), "illegal 商品置位 flags['illegal_trade']")
	# 只记不判：错误串里**不得**出现任何法律判定（spec §10 第 4 条）
	var sm_joined := " | ".join(sm_errs)
	a.is_false(sm_joined.contains("通缉") or sm_joined.contains("逮捕") or sm_joined.contains("罚款"),
		"不得在其中返回「已被通缉/逮捕/罚款」这类判定（只记不判）")
	a.is_false(sw2.factions.has("smuggler"), "走私不改 factions（Economy 不得跨模块写）")
	# 非 illegal 商品不得记热度
	var heat_mid := int(sw2.economy["smuggling_heat"])
	StateOps.apply(sw2, [{
		"op": "trade_money", "good_id": "mat_ore", "qty": 1, "mode": "buy",
		"origin_location_id": "forbidden_forest", "location_id": "diagon_alley",
	}])
	a.eq(int(sw2.economy["smuggling_heat"]), heat_mid, "合法商品不记走私热度")

	# ---- trade_money：qty 越界 / 未知商品 / mode 非法 / 现金不足 ----
	var bad_trade := StateOps.apply(tw, [
		{"op": "trade_money", "good_id": "potion_common", "qty": 0, "mode": "buy",
			"origin_location_id": "forbidden_forest", "location_id": "diagon_alley"},
		{"op": "trade_money", "good_id": "potion_common", "qty": OpGuard.MAX_TRADE_QTY + 1, "mode": "buy",
			"origin_location_id": "forbidden_forest", "location_id": "diagon_alley"},
		{"op": "trade_money", "good_id": "不存在的商品", "qty": 1, "mode": "buy",
			"origin_location_id": "forbidden_forest", "location_id": "diagon_alley"},
		{"op": "trade_money", "good_id": "potion_common", "qty": 1, "mode": "偷",
			"origin_location_id": "forbidden_forest", "location_id": "diagon_alley"},
	])
	a.eq(bad_trade.size(), 4, "qty=0 / qty 越界 / 未知商品 / mode 非法 各报一个错")
	var no_cash := make_world()
	WorldFactions.initialize(no_cash)
	no_cash.player.money_knuts = 10
	no_cash.player.location_id = "forbidden_forest"
	var nc_errs := StateOps.apply(no_cash, [{
		"op": "trade_money", "good_id": "potion_common", "qty": 1, "mode": "buy",
		"origin_location_id": "forbidden_forest", "location_id": "diagon_alley",
	}])
	a.is_true(nc_errs.size() > 0, "现金不足被拒")
	a.eq(no_cash.player.money_knuts, 10, "被拒时现金不变（不部分执行）")

	# ---- OpGuard：未知经济 op 一律拒绝 / 4 个合法经济 op 必须放行 ----
	# ⚠️ 夹具：`sanitize_op(world, raw)` 需要世界；给足够的钱使得钳制后的载荷仍合法。
	var gw2 := make_world()
	WorldFactions.initialize(gw2)
	gw2.player.money_knuts = 2000000
	gw2.player.location_id = "forbidden_forest"
	# 拒绝侧：这 4 个 op **StateOps 根本没有实现**，必须在 OpGuard 层就拦掉
	# （与 03a 的 `set_faction_*` 不同 —— 那些是透传给 StateOps 拒绝，这些不能透传，
	#  否则它们会一路走到 `未知操作` 分支，错误串模棱两可、且将来有人给 StateOps 加上
	#  同名 op 时会**静默放行**）。
	a.is_true(not OpGuard.sanitize_op(gw2, {"op": "set_economy_index", "value": 0.9}).ok,
		"LLM 不能改世界经济")
	a.is_true(not OpGuard.sanitize_op(gw2, {"op": "set_gringotts_balance", "knuts": 9}).ok,
		"LLM 不能直接改余额")
	a.is_true(not OpGuard.sanitize_op(gw2, {"op": "set_smuggling_heat", "value": 0}).ok,
		"LLM 不能改走私热度")
	a.is_true(not OpGuard.sanitize_op(gw2, {"op": "set_foreign_rate", "value": 99.0}).ok,
		"LLM 不能改汇率")
	a.is_true(not OpGuard.sanitize_op(gw2, {"op": "set_prices", "prices": {}}).ok,
		"LLM 不能改物价")
	a.is_true(not OpGuard.sanitize_op(gw2, {"op": "set_gringotts_interest_rate", "value": 99.0}).ok,
		"LLM 不能改利率")
	# 放行侧（不能只测拒绝 —— 否则「把 4 个 op 全拉黑」也能全绿）
	a.is_true(OpGuard.sanitize_op(gw2, {"op": "deposit_money", "knuts": 100}).ok, "deposit_money 被放行")
	a.is_true(OpGuard.sanitize_op(gw2, {"op": "withdraw_money", "knuts": 100}).ok, "withdraw_money 被放行")
	a.is_true(OpGuard.sanitize_op(gw2, {"op": "exchange_money", "knuts": 100, "direction": "buy"}).ok,
		"exchange_money 被放行")
	a.is_true(OpGuard.sanitize_op(gw2, {"op": "trade_money", "good_id": "potion_common", "qty": 1,
		"mode": "buy"}).ok, "trade_money 被放行")

	return a.report("gm")
