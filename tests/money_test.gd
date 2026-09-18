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

	# 往返
	var d := Money.from_knuts(493 * 3 + 17 * 2 + 5).to_dict()
	a.eq(d, {"galleons": 3, "sickles": 2, "knuts": 5}, "to_dict 归一")
	a.eq(Money.from_dict(d).total_knuts(), Money.from_knuts(493 * 3 + 17 * 2 + 5).total_knuts(), "往返一致")
	a.eq(Money.from_dict({}).total_knuts(), 0, "空字典=0")

	return a.report("money")
