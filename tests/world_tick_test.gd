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
	var rng := RngService.new(w.game_seed)

	var start_year := w.clock.year
	w.clock.advance_months(12)
	a.eq(w.clock.year, start_year + 1, "12 回合 = 1 年")

	for i in 24:
		var events := w.tick()
		a.is_true(events is Array, "tick 返回事件数组")
		if events.size() > 0:
			a.has_key(events[0], "kind", "事件含 kind")
			a.has_key(events[0], "text", "事件含 text")

	a.eq(w.clock.turn > 0, true, "回合推进")
	a.is_true(w.log.size() > 0, "世界产生日志（第四十三章：传闻与新闻）")

	# 世界变量必须始终落在 [0,1]（第四十九章：阶层与权力流动，不能失控）
	for key in w.world_vars.keys():
		var v := float(w.world_vars[key])
		a.between(v, 0.0, 1.0, "世界变量 %s 在界内" % key)

	# 第六十八章防过度热闹：major 事件必须稀少
	var w2 := WorldState.create("second_wizarding_war", p, 1234, reg)
	w2.player.sim_style_id = "epic_wizard_war_typo"   # 未知风格必须被安全处理
	var major_count := 0
	for i in 240:
		for e in w2.tick():
			if bool(e.get("major", false)):
				major_count += 1
	a.is_true(major_count <= 20, "240 个月内 major 事件不超过 20 次（约 1/12 月上限），实际=%d" % major_count)

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
	var leaked := false
	for i in 40:
		for e in w3.tick():
			if str(e.get("category", "")) == "魔法部内幕":
				leaked = true
	a.is_false(leaked, "未入学麻瓜出身者不应收到“魔法部内幕”级信息")

	return a.report("world_tick")
