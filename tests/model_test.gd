class_name ModelTest
extends RefCounted

func run() -> int:
	var a := TestAssert.new()
	var reg := Registry.load_default()

	# ---- GameClock ----
	var clock := GameClock.from_dict({"year": 1991, "month": 9, "turn": 0})
	a.eq(clock.formatted(), "1991年9月", "时钟格式")
	clock.advance_month()
	a.eq(clock.formatted(), "1991年10月", "推进一个月")
	a.eq(clock.turn, 1, "回合数+1")
	for i in 4:
		clock.advance_month()
	a.eq(clock.formatted(), "1992年2月", "跨年进位")
	a.eq(clock.turn, 5, "回合数累计")
	clock.advance_months(12)
	a.eq(clock.formatted(), "1993年2月", "advance_months 跨年")
	a.eq(clock.turn, 17, "advance_months 累加回合")
	var later := GameClock.from_dict({"year": 1993, "month": 5, "turn": 0})
	a.eq(clock.months_between(later), 3, "月份差")
	a.eq(later.months_between(clock), -3, "月份差为负")
	a.eq(GameClock.from_dict(clock.to_dict()).formatted(), "1993年2月", "时钟往返")

	# ---- PlayerState ----
	var p := PlayerState.from_dict({
		"name_text": "张三",
		"gender": "男",
		"age_months": 132,
		"bloodline_id": "muggle_born",
		"money_knuts": 4930,
	})
	a.eq(p.age_years(), 11, "11岁")
	a.eq(p.money().formatted(), "10加隆 0西可 0纳特", "起始财产")
	# 正典第十八章：一根普通魔杖 7‑10 加隆；取价格下限 7 加隆 = 7 × 493 = 3451 纳特
	p.set_money(p.money().subtract(Money.from_knuts(7 * Money.KNUTS_PER_GALLEON)))
	a.eq(p.money().formatted(), "3加隆 0西可 0纳特", "买 7 加隆普通魔杖后剩 3 加隆（正典第十八章）")
	p.add_skill("potions", 3)
	p.add_skill("potions", 2)
	a.eq(p.skill("potions"), 5, "技能累加")
	p.add_skill("potions", 1000)
	a.eq(p.skill("potions"), 100, "技能上界 100")
	p.add_skill("potions", -1000)
	a.eq(p.skill("potions"), 0, "技能下界 0")
	a.eq(p.skill("未学过的技能"), 0, "未知技能为 0")
	a.is_false(p.knows_spell("wingardium_leviosa"), "尚未掌握魔咒")
	p.learn_spell("wingardium_leviosa")
	p.learn_spell("wingardium_leviosa")
	a.is_true(p.knows_spell("wingardium_leviosa"), "掌握魔咒")
	a.eq(p.magic["known_spells"].size(), 1, "不重复记录同一魔咒")
	a.has_key(p.magic, "capacity", "第六十三章面板字段存在")

	# 往返：中文与嵌套结构必须无损
	var p2 := PlayerState.from_dict(p.to_dict())
	a.eq(p2.name_text, "张三", "姓名往返")
	a.eq(p2.to_dict(), p.to_dict(), "玩家状态完全往返")
	# 端到端：经 JSON 字符串（真实存档路径）往返后仍必须逐字节相等
	var p3 := PlayerState.from_dict(JSON.parse_string(JSON.stringify(p.to_dict())))
	a.eq(p3.to_dict(), p.to_dict(), "经 JSON 字符串的玩家状态往返")

	# ---- JsonUtil：JSON 数值规范化（存读档往返一致性的唯一保障） ----
	a.is_true(typeof(JsonUtil.normalize(2.0)) == TYPE_INT, "2.0 归一为 int")
	a.is_true(typeof(JsonUtil.normalize(0.42)) == TYPE_FLOAT, "0.42 保持 float")
	a.eq(JsonUtil.normalize(0.42), 0.42, "浮点值不变")
	a.eq(JsonUtil.normalize([1.0, 2.5, {"a": 3.0}]), [1, 2.5, {"a": 3}], "递归处理数组与字典")
	a.eq(JsonUtil.normalize(true), true, "bool 原样")
	a.eq(JsonUtil.normalize(null), null, "null 原样")
	a.eq(JsonUtil.normalize("张三"), "张三", "字符串原样")
	# 未经规范化的 JSON 往返必然不等（这就是必须归一的原因）
	var raw_round_trip = JSON.parse_string(JSON.stringify({"n": 493}))
	a.ne(raw_round_trip, {"n": 493}, "JSON 解析出的 float 与 int 深比较不相等")
	a.eq(JsonUtil.normalize(raw_round_trip), {"n": 493}, "规范化后相等")

	# ---- WorldState ----
	var w := WorldState.create("first_wizarding_war", p, 20260918, reg)
	a.eq(w.clock.year, 1970, "时代锚定起始年份")
	a.eq(w.era()["label"], "第一次巫师战争", "时代查询")
	a.eq(w.world_vars["war_pressure"], 0.8, "世界变量取自时代基线")
	a.eq(w.world_vars.size(), 7, "七项世界变量")
	a.eq(w.save_version, 1, "存档版本")
	a.eq(w.player.name_text, "张三", "持有玩家")
	var fact := w.add_fact("major", "伏地魔第一次倒台")
	a.eq(w.history.size(), 1, "写入历史")
	a.eq(fact["turn"], 0, "事实带回合号")
	a.eq(w.log.size(), 1, "写入日志")

	var w2 := WorldState.from_dict(w.to_dict(), reg)
	a.eq(w2.to_dict(), w.to_dict(), "世界状态完全往返")
	a.eq(w2.registry, reg, "往返后重新挂载注册表")
	a.is_true(w2.era()["id"] == "first_wizarding_war", "往返后仍能查询内容表")
	# 端到端：经 JSON 字符串（真实存档路径）往返后仍必须相等
	var w3 := WorldState.from_dict(JSON.parse_string(JSON.stringify(w.to_dict())), reg)
	a.eq(w3.to_dict(), w.to_dict(), "经 JSON 字符串的世界状态往返")

	# create 与 from_dict 必须产出同型的 world_vars（含整数值 float，如 witch_hunts.secrecy_integrity=1.0）
	var we := WorldState.create("witch_hunts", PlayerState.from_dict({"name_text": "乙"}), 1, reg)
	var we2 := WorldState.from_dict(we.to_dict(), reg)
	a.eq(we2.world_vars, we.world_vars, "world_vars 类型在 create 与 from_dict 间一致")

	# to_dict 不得包含瞬态注册表；也不得出现非 JSON 原生类型
	var d := w.to_dict()
	a.is_false(d.has("registry"), "注册表不序列化")
	a.is_true(JSON.stringify(d).length() > 0, "世界状态可被 JSON 序列化")

	return a.report("model")
