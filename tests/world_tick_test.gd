class_name WorldTickTest
extends RefCounted

func run() -> int:
	var a := TestAssert.new()
	var reg := Registry.load_default()

	# 内容表新增项
	a.eq(reg.validate().size(), 0, "新增表后仍无校验错误")
	a.is_true(reg.ids("locations").size() >= 18, "地点表至少 18 项")
	a.is_true(reg.ids("rumors").size() >= 12, "传闻模板至少 12 条")
	a.eq(reg.entry("locations", "forbidden_forest")["danger_label"], "高危险区", "禁林危险度（第四十四章）")
	a.eq(reg.entry("locations", "diagon_alley")["danger_label"], "安全区", "对角巷安全区")
	a.eq(reg.entry("locations", "azkaban")["danger_label"], "高危险区", "阿兹卡班高危险区")
	a.eq(reg.entry("locations", "ministry_of_magic")["danger_label"], "低危险区", "魔法部公开区域低危险")

	# 月度演化：世界继续向前（第四十七章）
	var p := PlayerState.new_default()
	p.name_text = "张三"
	p.bloodline_id = "muggle_born"
	p.birth_identity_id = "ordinary_wizard_family"
	p.sim_style_id = "mixed"
	p.location_id = "london_muggle"
	var w := WorldState.create("modern", p, 20260918, reg)

	var start_year := w.clock.year
	w.clock.advance_months(12)
	a.eq(w.clock.year, start_year + 1, "12 回合 = 1 年")

	for i in 24:
		var events := w.tick()
		a.eq(w.clock.turn, 13 + i, "tick 每次推进一个回合")
		if events.size() > 0:
			a.has_key(events[0], "kind", "事件含 kind")
			a.has_key(events[0], "text", "事件含 text")

	a.eq(w.clock.turn > 0, true, "回合推进")
	a.is_true(w.log.size() > 0, "世界产生日志（第四十三章：传闻与新闻）")

	# ---- 计划 03a（Task 6 复审收口 Minor）：每个传闻事件必须带非空 rumor_id ----
	# Task 6 的 apply_rumor_reveals() 依赖它把传闻映射到 reveals_faction；先前无任何护栏。
	var rumor_log_events := 0
	for e in w.log:
		if str(e.get("kind", "")) == "rumor":
			rumor_log_events += 1
			a.is_true(not str(e.get("rumor_id", "")).is_empty(),
				"传闻事件带 rumor_id（第 %d 回合）" % int(e.get("turn", 0)))
	a.is_true(rumor_log_events >= 1, "至少有一条传闻事件可核对 rumor_id（实际 %d）" % rumor_log_events)

	# 世界变量必须始终落在 [0,1]（第四十九章：阶层与权力流动，不能失控）
	for key in w.world_vars.keys():
		var v := float(w.world_vars[key])
		a.between(v, 0.0, 1.0, "世界变量 %s 在界内" % key)

	# 第六十八章防过度热闹：major 事件必须稀少，且相邻 major 至少相隔 12 个月
	var w2 := WorldState.create("second_wizarding_war", p, 38, reg)
	w2.player.sim_style_id = "epic_wizard_war_typo"   # 未知风格必须被安全处理
	w2.player.location_id = "ministry_of_magic"       # 让 major 候选真的进入候选集，避免断言空转
	var major_count := 0
	var last_major_turn := -1000
	var min_gap := 9999
	for i in 240:
		for e in w2.tick():
			if bool(e.get("major", false)):
				major_count += 1
				min_gap = mini(min_gap, int(e["turn"]) - last_major_turn)
				last_major_turn = int(e["turn"])
	a.is_true(major_count >= 1, "该配置下至少出现一次 major，避免断言空转（实际=%d）" % major_count)
	a.is_true(major_count <= 20, "240 个月内 major 事件不超过 20 次（约 1/12 月上限），实际=%d" % major_count)
	a.is_true(min_gap >= 12, "相邻 major 事件至少相隔 12 个月（实际最小间隔=%d）" % min_gap)

	# 确定性：同种子同世界 → 同演化
	var wa := WorldState.create("modern", PlayerState.new_default(), 777, reg)
	var wb := WorldState.create("modern", PlayerState.new_default(), 777, reg)
	wa.player.sim_style_id = "mixed"
	wb.player.sim_style_id = "mixed"
	wa.player.location_id = "diagon_alley"
	wb.player.location_id = "diagon_alley"
	for i in 10:
		a.eq(wa.tick(), wb.tick(), "第 %d 个月演化完全一致" % i)

	# 信息保护（第四十三章/第五十七章）：低阶身份不得直接获知魔法部内幕
	var w3 := WorldState.create("modern", PlayerState.new_default(), 5, reg)
	w3.player.bloodline_id = "muggle_born"
	w3.player.house_id = "none"
	w3.player.location_id = "ministry_of_magic"   # 让 ministry 类传闻真的进入候选集，避免断言空转
	var leaked := false
	var events_seen := 0
	for i in 40:
		for e in w3.tick():
			events_seen += 1
			if str(e.get("category", "")) == "魔法部内幕":
				leaked = true
	a.is_true(events_seen > 0, "该配置下确实产生了事件（否则信息保护断言空转）")
	a.is_false(leaked, "未入学麻瓜出身者不应收到“魔法部内幕”级信息")

	# ---- 计划 03a：新增演化阶段不得破坏 tick 的既有语义 ----
	var pre_reg := Registry.load_default()
	var pre_w := WorldState.create("modern", PlayerState.new_default(), 4242, pre_reg)
	var age_before := pre_w.player.age_months
	var turn_before := pre_w.clock.turn
	pre_w.tick()
	a.eq(pre_w.player.age_months, age_before + 1, "年龄仍每回合 +1")
	a.eq(pre_w.clock.turn, turn_before + 1, "回合仍每回合 +1")
	a.is_true(pre_w.log.size() <= 200, "日志仍被裁剪到 200 条以内")
	a.is_true(pre_w.flags.has(WorldFactions.GOVERNMENT_FLAG), "政体缓存已写入")

	# ---- 计划 03a：tick 的传闻事件结构不变，只多一个 rumor_id（Task 6 的揭示要用） ----
	var rumor_w := WorldState.create("modern", PlayerState.new_default(), 99, pre_reg)
	# 必须给一个真实地点，否则 zones 筛选后候选集为空、传闻事件一次都不会产生（断言会空转）
	rumor_w.player.location_id = "diagon_alley"
	var rumor_events: Array = []
	var guard := 0
	while rumor_events.is_empty() and guard < 40:
		guard += 1
		for e in rumor_w.tick():
			if str(e.get("kind", "")) == "rumor":
				rumor_events.append(e)
	a.is_true(rumor_events.size() >= 1, "该配置下确实产生了传闻事件（否则下面的结构断言空转）")
	for e in rumor_events:
		a.has_key(e, "kind", "传闻事件含 kind")
		a.has_key(e, "category", "传闻事件含 category")
		a.has_key(e, "text", "传闻事件含 text")
		a.has_key(e, "major", "传闻事件含 major")
		a.has_key(e, "turn", "传闻事件含 turn")
		a.has_key(e, "rumor_id", "传闻事件含 rumor_id（Task 6 揭示用）")
		# 用 .get() 而非 e["rumor_id"]：缺键时要得到一条干净的断言失败，不能用下标访问把整个套件搞崩（§8#56 同类陷阱）
		a.is_true(rumor_w.registry.has("rumors", str(e.get("rumor_id", ""))), "rumor_id 是内容表里的真实传闻")

	# ---- 计划 03a：政治事件真的会触发，且与传闻共用 12 个月重大事件配额 ----
	# 高张力夹具：**每月重置**极端 world_vars（模拟持续紧张的世界），使 tension 恒过阈、条件恒成立，
	# 于是「事件是否触发」只由配额（MAJOR_EVENT_GAP）决定；玩家无地点 ⇒ 传闻候选集为空 ⇒ 配额纯归政治事件。
	# （旧版这段用 modern 默认格局，tension≈0.33 < 0.55 ⇒ 40 回合内事件恒 0 条，是一条永真/永绿噪声；修复轮 1 I1）
	var tense := WorldState.create("modern", PlayerState.new_default(), 777, pre_reg)
	for key in ["corruption", "pureblood_influence", "war_pressure"]:
		tense.world_vars[key] = 0.99
	tense.world_vars["muggle_relations"] = 0.01
	tense.world_vars["economy_index"] = 0.01
	tense.world_vars["secrecy_integrity"] = 0.01
	a.is_true(WorldFactions.compute_tension(tense) >= WorldFactions.TENSION_THRESHOLD,
		"前置：夹具的 tension 过阈（否则本块会静默空转——旧版就是死在这里）")
	a.is_true(WorldFactions.event_condition_met(tense, "lawlessness")
		and WorldFactions.event_condition_met(tense, "war_exhaustion")
		and WorldFactions.event_condition_met(tense, "economic_slump"),
		"前置：至少三个事件条件成立（否则本块会静默空转）")
	var faction_events := 0
	var political_gap := 9999
	var political_last := -1000
	for i in 40:
		for key in ["corruption", "pureblood_influence", "war_pressure"]:
			tense.world_vars[key] = 0.99
		tense.world_vars["muggle_relations"] = 0.01
		tense.world_vars["economy_index"] = 0.01
		tense.world_vars["secrecy_integrity"] = 0.01
		for e in tense.tick():
			if str(e.get("kind", "")) == "faction":
				faction_events += 1
				political_gap = mini(political_gap, int(e["turn"]) - political_last)
				political_last = int(e["turn"])
	a.is_true(faction_events >= 2, "高张力世界 40 回合内至少触发 2 次政治事件（实际=%d）" % faction_events)
	a.is_true(political_gap >= WorldState.MAJOR_EVENT_GAP,
		"相邻政治事件至少相隔 %d 个月（实际最小间隔=%d）" % [WorldState.MAJOR_EVENT_GAP, political_gap])

	# ---- 计划 03a：tick 跑完仍不得留下畸形 world_vars / 派系状态 ----
	for fid in pre_w.registry.ids("factions"):
		var fstate := WorldFactions.state_of(pre_w, str(fid))
		a.is_true(not fstate.is_empty(), "tick 后 %s 仍有状态" % str(fid))
		a.between(float(fstate.get("power", -1.0)), 0.0, 1.0, "%s 实力在界内" % str(fid))

	# ---- 计划 03a（§8#16）：weight 必须真的生效 ----
	var t12_wrng := RngService.new(99)
	var t12_light: Array = [{"id": "a", "weight": 0.0}, {"id": "b", "weight": 1.0}]
	var t12_picked_b := 0
	for i in 50:
		var t12_picked: Dictionary = t12_wrng.stream_pick_weighted("w_test", t12_light)
		if str(t12_picked.get("id", "")) == "b":
			t12_picked_b += 1
	a.eq(t12_picked_b, 50, "weight=0 的条目永远不会被抽中（50/50 次）")
	var t12_all_zero: Array = [{"id": "a", "weight": 0.0}, {"id": "b", "weight": 0.0}]
	a.is_true(t12_wrng.stream_pick_weighted("w_zero", t12_all_zero) != null,
		"全零权重回退到均匀抽取，不返回 null")
	a.is_true(t12_wrng.stream_pick_weighted("w_empty", []) == null, "空列表返回 null")

	# ---- 修复轮 1（审查 Minor #2/#3）：把「roll == 0.0 落在首条零权重上」这条不可测的边界变成可判别 ----
	# randf() 精确返回 0.0 的概率 ≈ 2^-32 ⇒ 黑盒永远测不出来；`_pick_by_roll(entries, key, roll)` 就是为此拆出来的。
	# 旧写法（`roll <= acc` + 不跳过零权重）会返回首条零权重条目 "z" ⇒ 违反 stream_pick_weighted 注释里的契约①。
	a.eq(_picked_id(RngService._pick_by_roll([{"id": "z", "weight": 0.0}, {"id": "o", "weight": 1.0}], "weight", 0.0)),
		"o", "roll=0.0 时不得返回前导的零权重条目（旧写法会返回 z）")
	# 兜底也必须是正权重条目（旧写法是 entries[entries.size()-1]，零权重排末位时会返回它）
	a.eq(_picked_id(RngService._pick_by_roll([{"id": "o", "weight": 5.0}, {"id": "z", "weight": 0.0}], "weight", 999.0)),
		"o", "roll 超出总权重时，兜底不得落在零权重条目上")
	# 契约③的前半：非字典条目在**加权路径**被跳过（它不得占掉区间、也不得成为兜底）
	a.eq(_picked_id(RngService._pick_by_roll(["裸字符串", {"id": "o", "weight": 1.0}], "weight", 0.0)),
		"o", "加权路径跳过非字典条目（不会被它占掉区间）")

	# ---- 计划 03a（§8#16）端到端：tick() 本身必须走权重（只测 helper 不足以证明接线）----
	# 夹具：把 rumors 表换成「同一个 zone 两条」，weight=1 的在前、weight=0 的在后。
	# 加权 ⇒ weight=0 那条永远抽不到；均匀（回到 stream_pick）⇒ 40 回合内几乎必然抽到（P(全不中)≈0.5^40）。
	# 两条 id 的字典序 "..one" < "..zero" ⇒ 注册表排序后 weight=1 稳定在前（不受 roll==0 的边界影响）。
	var t12_tables := {}
	for t12_table_name in Registry.TABLE_FILES.keys():
		var t12_entries: Array = []
		for t12_eid in reg.ids(t12_table_name):
			t12_entries.append(reg.entry(t12_table_name, str(t12_eid)))
		t12_tables[t12_table_name] = t12_entries
	a.is_true((reg.ids("rumors") as PackedStringArray).size() > 2, "E2E 前置：默认传闻表确实是多条的（未被夹具偷换）")
	t12_tables["rumors"] = [
		{"id": "t12_weight_one", "label": "权重一的传闻", "category": "测试", "text": "权重 1 的传闻",
			"weight": 1.0, "major": false, "min_year": 0, "zones": ["diagon_alley"], "requires_flags": []},
		{"id": "t12_weight_zero", "label": "权重零的传闻", "category": "测试", "text": "权重 0 的传闻",
			"weight": 0.0, "major": false, "min_year": 0, "zones": ["diagon_alley"], "requires_flags": []},
	]
	var t12_reg := Registry.from_tables(t12_tables)
	var t12_p := PlayerState.new_default()
	t12_p.name_text = "权重测试者"
	t12_p.location_id = "diagon_alley"
	var t12_world := WorldState.create("modern", t12_p, 424242, t12_reg)
	var t12_saw_one := 0
	var t12_saw_zero := 0
	for i in 40:
		for t12_ev in t12_world.tick():
			if str(t12_ev.get("kind", "")) != "rumor":
				continue
			match str(t12_ev.get("rumor_id", "")):
				"t12_weight_one":
					t12_saw_one += 1
				"t12_weight_zero":
					t12_saw_zero += 1
	a.is_true(t12_saw_one > 0, "E2E：weight=1 的传闻会被抽中（实际 %d 次）" % t12_saw_one)
	a.eq(t12_saw_zero, 0, "E2E：weight=0 的传闻 40 回合内一次都不该被抽中（tick 回到 stream_pick ⇒ 必红）")

	return a.report("world_tick")

# 修复轮 1：安全取 id。_pick_by_roll 可能返回 null / 非字典 ⇒ 直接解引用会让「红」的形态变成套件中止
# （与台账里 Task 9 M7、Task 12 首轮 personality 那条同源：中止会把后面所有断言掩盖掉）。
func _picked_id(picked) -> String:
	if picked == null:
		return "<null>"
	if typeof(picked) != TYPE_DICTIONARY:
		return "<非字典:%s>" % str(picked)
	return str((picked as Dictionary).get("id", "<无 id>"))
