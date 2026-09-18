class_name SelfCheckTest
extends RefCounted

func make_world(reg: Registry) -> WorldState:
	var p := PlayerState.new_default()
	p.name_text = "张三"
	p.bloodline_id = "half_blood"
	p.age_months = 132
	p.location_id = "hogwarts"
	var w := WorldState.create("modern", p, 1, reg)
	w.clock.year = 2010
	w.clock.month = 9
	return w

func run() -> int:
	var a := TestAssert.new()
	var reg := Registry.load_default()

	# 每 15 回合（第七十二章）
	a.is_false(SelfCheck.is_audit_turn(0), "第 0 回合不自检")
	a.is_false(SelfCheck.is_audit_turn(14), "第 14 回合不自检")
	a.is_true(SelfCheck.is_audit_turn(15), "第 15 回合自检")
	a.is_true(SelfCheck.is_audit_turn(30), "第 30 回合自检")

	# 剧情快照必须包含规则要求的七项
	var w := make_world(reg)
	w.add_fact("major", "第一次巫师战争结束")
	w.pending.append({"text": "未完成的调查：翻倒巷的假身份", "turn": 3})
	w.npcs["npc_1"] = {"name": "阿不福思", "identity": "猪头酒吧老板", "status": "在店里"}
	var snap := SelfCheck.snapshot(w)
	a.is_true(snap.contains("【剧情快照】"), "快照标题")
	for label in ["当前时间", "地点", "玩家状态", "关键NPC状态", "当前进行中事件", "已发生重大事件", "世界变量"]:
		a.is_true(snap.contains(str(label)), "快照含 %s" % str(label))
	a.is_true(snap.contains("第一次巫师战争结束"), "快照含重大事件")
	a.is_true(snap.contains("翻倒巷的假身份"), "快照含未完成事件")
	a.is_true(snap.contains("阿不福思"), "快照含关键 NPC")

	# OOC 自检必须包含四项检查
	var ooc := SelfCheck.ooc_report(w)
	a.is_true(ooc.contains("【人设OOC自检报告】"), "OOC 标题")
	for label in ["人物行为偏离设定", "魔法规则被破坏", "历史时间线错误", "玩家信息被提前泄露"]:
		a.is_true(ooc.contains(str(label)), "OOC 含 %s" % str(label))
	a.is_true(ooc.contains("通过"), "干净世界应通过")

	# 魔法规则被破坏必须被抓到
	var w2 := make_world(reg)
	w2.flags["illegal_cast_count"] = 2
	a.is_true(SelfCheck.ooc_report(w2).contains("魔法规则被破坏：异常"), "非法施法被抓到")

	# 历史时间线错误：年份早于时代锚点
	var w3 := make_world(reg)
	w3.clock.year = 1900
	a.is_true(SelfCheck.ooc_report(w3).contains("历史时间线错误：异常"), "时间线错误被抓到")

	# 玩家信息被提前泄露：来源为 system
	var w4 := make_world(reg)
	w4.player.known_facts["secret_horcrux"] = "system"
	a.is_true(SelfCheck.ooc_report(w4).contains("玩家信息被提前泄露：异常"), "系统剧透被抓到")

	# 人物 OOC 标记
	var w5 := make_world(reg)
	w5.npcs["npc_bad"] = {"name": "某人", "ooc_violation": true}
	a.is_true(SelfCheck.ooc_report(w5).contains("人物行为偏离设定：异常"), "NPC OOC 被抓到")

	# report() = 快照 + OOC
	var full := SelfCheck.report(w)
	a.is_true(full.contains("【剧情快照】") and full.contains("【人设OOC自检报告】"), "report 含两段")

	return a.report("selfcheck")
