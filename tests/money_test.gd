class_name MoneyTest
extends RefCounted

func run() -> int:
	var a := TestAssert.new()

	# 第十八章：1加隆 = 17西可 = 493纳特
	a.eq(Money.KNUTS_PER_GALLEON, 493, "1加隆=493纳特")
	a.eq(Money.from_knuts(493).parts(), [1, 0, 0], "493纳特=1加隆")
	a.eq(Money.from_knuts(17).parts(), [0, 1, 0], "17纳特=1西可")
	a.eq(Money.from_knuts(510).parts(), [1, 1, 0], "493+17 = 1加隆1西可（17纳特进位为1西可）")
	a.eq(Money.from_knuts(511).parts(), [1, 1, 1], "493+17+1 = 1加隆1西可1纳特")

	# 展示格式
	a.eq(Money.from_knuts(493 + 17 + 1).formatted(), "1加隆 1西可 1纳特", "格式")
	a.eq(Money.from_knuts(0).formatted(), "0加隆 0西可 0纳特", "零")

	# 一根普通魔杖 7–10 加隆（第十八章），必须落在同一货币体系内
	var wand_price := Money.from_knuts(7 * Money.KNUTS_PER_GALLEON)
	a.eq(wand_price.parts(), [7, 0, 0], "魔杖 7 加隆")
	a.is_true(Money.from_knuts(10 * Money.KNUTS_PER_GALLEON).total_knuts() > wand_price.total_knuts(), "10加隆 > 7加隆")

	# 值语义：add/subtract 不得修改原对象
	var base := Money.from_knuts(100)
	var plus := base.add(Money.from_knuts(50))
	a.eq(base.total_knuts(), 100, "add 不修改原对象")
	a.eq(plus.total_knuts(), 150, "add 返回新对象")
	a.eq(plus.subtract(Money.from_knuts(200)).total_knuts(), -50, "允许负债（第十九章：家族破产）")

	# 负值分段/格式（计划 03b Task 3，E9 债务形态；HANDOFF §8#5 裁定落地）
	# ⚠️ parts() 返回 [-g, -s, -k]，第三位是**纳特**不是西可（-1002 = 2×493 + 16）
	var debt := Money.from_knuts(-50)
	a.eq(debt.parts(), [0, -2, -16], "负值分段不变（parts() 契约未动）")
	a.eq(Money.from_dict(debt.to_dict()).total_knuts(), -50, "负值往返一致")

	# ---- E9 债务形态（实算，不是猜：每档都按 parts 的纳特位反推）----
	a.eq(Money.from_knuts(-1002).debt_formatted(), "负债 2加隆 16纳特", "-1002 = 2×493 + 16纳特")
	a.eq(Money.from_knuts(-17).debt_formatted(), "负债 1西可", "-17 = 1西可")
	a.eq(Money.from_knuts(-5).debt_formatted(), "负债 5纳特", "-5 = 5纳特")
	a.eq(Money.from_knuts(-493).debt_formatted(), "负债 1加隆", "-493 = 1加隆（0 值低位单位省略）")
	a.eq(Money.from_knuts(-510).debt_formatted(), "负债 1加隆 1西可", "-510 = 1加隆1西可")
	a.eq(Money.from_knuts(-511).debt_formatted(), "负债 1加隆 1西可 1纳特", "-511 三位齐全")
	a.eq(Money.from_knuts(-50).debt_formatted(), "负债 2西可 16纳特", "-50 = 2西可16纳特")
	# 负债 1加隆整时**不得**出现「0西可 0纳特」尾巴
	a.is_false(Money.from_knuts(-493).debt_formatted().contains("0西可"),
		"-493 不出现 0 值单位尾巴")

	a.is_true(Money.from_knuts(-1).is_debt(), "-1 是负债")
	a.is_true(Money.from_knuts(-50).is_debt(), "-50 是负债")
	a.is_false(Money.from_knuts(0).is_debt(), "0 不是负债")
	a.is_false(Money.from_knuts(7).is_debt(), "正数不是负债")

	# ---- Task 12 收尾：债务形态的**结构化**分解契约 ----
	# 全部期望值由整数运算核过（`v/493`, `v%493`, `r/17`, `r%17`）—— **不手算**。
	a.eq(Money.from_knuts(-100).debt_parts(),
		{"debt": true, "galleons": 0, "sickles": 5, "knuts": 15},
		"debt_parts 对 -100（= 0加隆 5西可 15纳特）")
	a.eq(Money.from_knuts(-1002).debt_parts(),
		{"debt": true, "galleons": 2, "sickles": 0, "knuts": 16},
		"debt_parts 对 -1002")
	a.eq(Money.from_knuts(-493).debt_parts(),
		{"debt": true, "galleons": 1, "sickles": 0, "knuts": 0},
		"debt_parts 的 0 值单位是 int 0（不是 -0.0）")
	a.eq(Money.from_knuts(100).debt_parts(),
		{"debt": false, "galleons": 0, "sickles": 5, "knuts": 15},
		"debt_parts 非负分支（100 = 5西可 15纳特，无加隆）")
	a.eq(Money.from_knuts(0).debt_parts(),
		{"debt": false, "galleons": 0, "sickles": 0, "knuts": 0},
		"debt_parts 零值")
	# 关键判别力：`debt_parts()` 的分段是**绝对值**，与 `parts()` 的带符号分段不同。
	# 若把 `absi()` 换成直接透传，下面这条会红（`-1` != `1`）—— 反向控制已验证。
	a.eq(Money.from_knuts(-493).debt_parts()["galleons"], 1,
		"debt_parts 的加隆位是正数（负债金额不带符号）")
	a.eq(Money.from_knuts(-493).parts()[0], -1,
		"而 parts() 的加隆位仍是负数（两函数语义不同，不可互相替代）")

	# ---- signed_formatted()：带符号形态（面板【经济】行消费）----
	a.eq(Money.from_knuts(29).signed_formatted(), "+0加隆 1西可 12纳特",
		"signed_formatted 非负补 +（金额本身仍是三位全写形态）")
	a.eq(Money.from_knuts(0).signed_formatted(), "+0加隆 0西可 0纳特", "signed_formatted 零也带 +")
	a.eq(Money.from_knuts(-1002).signed_formatted(), "负债 2加隆 16纳特",
		"signed_formatted 负值走债务形态")
	a.eq(Money.from_knuts(-50).signed_formatted(), "负债 2西可 16纳特", "signed_formatted -50")
	# 非负分支与 formatted() **逐字同构**（只多一个前缀 +）—— 防「顺手改 formatted 本体」
	for v in [0, 1, 29, 493, 510, 511, 3451]:
		a.eq(Money.from_knuts(v).signed_formatted(), "+" + Money.from_knuts(v).formatted(),
			"signed_formatted(%d) == \"+\" + formatted()" % v)

	# formatted() 负值走债务形态，非负分支**逐字不变**
	a.eq(Money.from_knuts(-1002).formatted(), "负债 2加隆 16纳特", "formatted 负值走债务形态")
	a.eq(Money.from_knuts(-50).formatted(), "负债 2西可 16纳特", "formatted -50")
	a.eq(Money.from_knuts(0).formatted(), "0加隆 0西可 0纳特", "0 不是负债（保持原形态）")
	a.eq(Money.from_knuts(493 + 17 + 1).formatted(), "1加隆 1西可 1纳特", "非负分支逐字不变")
	a.eq(Money.from_knuts(1).formatted(), "0加隆 0西可 1纳特", "非负小值仍写满三位")

	# ---- 正典 223 行量级：债务显示不得把加隆和纳特搞混 ----
	a.eq(Money.from_knuts(-3451).debt_formatted(), "负债 7加隆", "普通魔杖价对应的债务")
	a.eq(Money.from_knuts(-49300).debt_formatted(), "负债 100加隆", "光轮扫帚价对应的债务")

	# to_dict / parts 对负值的既有行为**一条不改**（防「顺手把 parts 也改了」）
	a.eq(Money.from_knuts(-1002).parts(), [-2, 0, -16], "parts 负值契约未动")
	a.eq(Money.from_knuts(-1002).to_dict(), {"galleons": -2, "sickles": 0, "knuts": -16},
		"to_dict 负值契约未动")

	return a.report("money")

	# 往返
	var d := Money.from_knuts(493 * 3 + 17 * 2 + 5).to_dict()
	a.eq(d, {"galleons": 3, "sickles": 2, "knuts": 5}, "to_dict 归一")
	a.eq(Money.from_dict(d).total_knuts(), Money.from_knuts(493 * 3 + 17 * 2 + 5).total_knuts(), "往返一致")
	a.eq(Money.from_dict({}).total_knuts(), 0, "空字典=0")

	return a.report("money")
