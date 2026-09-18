class_name MagicLevelTest
extends RefCounted

func run() -> int:
	var a := TestAssert.new()

	# 第二十三章：等级序列
	a.eq(MagicLevel.LABELS.size(), 10, "十级")
	a.eq(MagicLevel.label_of(MagicLevel.Tier.SQUIB), "哑炮", "第一级")
	a.eq(MagicLevel.label_of(MagicLevel.Tier.PRE_SCHOOL), "麻瓜出身未入学", "第二级")
	a.eq(MagicLevel.label_of(MagicLevel.Tier.MYTH), "神话级", "第十级")
	a.eq(MagicLevel.index_of_label("N.E.W.T水平"), MagicLevel.Tier.NEWT, "按标签反查")
	a.eq(MagicLevel.index_of_label("不存在的等级"), -1, "未知标签返回 -1")
	a.eq(MagicLevel.label_of(99), "未知", "越界安全")

	# 第二十二章失败率区间，逐字核对
	a.eq(MagicLevel.BANDS[MagicLevel.Tier.PRE_SCHOOL], Vector2(0.60, 0.80), "未入学 60-80%")
	a.eq(MagicLevel.BANDS[MagicLevel.Tier.FIRST_YEAR], Vector2(0.30, 0.50), "低年级 30-50%")
	a.eq(MagicLevel.BANDS[MagicLevel.Tier.OWL], Vector2(0.15, 0.30), "O.W.L 15-30%")
	a.eq(MagicLevel.BANDS[MagicLevel.Tier.NEWT], Vector2(0.05, 0.15), "N.E.W.T 5-15%")
	a.eq(MagicLevel.BANDS[MagicLevel.Tier.ADULT], Vector2(0.02, 0.05), "熟练成年 2-5%")
	a.is_true(MagicLevel.BANDS[MagicLevel.Tier.MASTER].y <= 0.02, "大师级低于 2%")
	a.eq(MagicLevel.effective_rate(MagicLevel.Tier.SQUIB, {}), 0.95, "哑炮无法施法，钳制上界")

	# 无环境因素时等于区间中点
	a.near(MagicLevel.effective_rate(MagicLevel.Tier.FIRST_YEAR, {}), 0.40, 0.0001, "低年级中点 40%")
	a.near(MagicLevel.effective_rate(MagicLevel.Tier.NEWT, {}), 0.10, 0.0001, "N.E.W.T 中点 10%")

	# 第二十二章：环境因素大幅改变失败概率
	var calm := MagicLevel.effective_rate(MagicLevel.Tier.ADULT, {})
	var stressed := MagicLevel.effective_rate(MagicLevel.Tier.ADULT, {"combat_stress": 1.0, "injury": 1.0})
	a.is_true(stressed > calm, "战斗压力与受伤提高失败率")
	a.is_true(stressed - calm >= 0.20, "两项满值环境因素至少 +20 个百分点")
	a.is_true(MagicLevel.effective_rate(MagicLevel.Tier.MYTH, {"combat_stress": 1.0, "injury": 1.0, "emotion": 1.0, "wand_mismatch": 1.0, "unfamiliar_spell": 1.0, "dark_magic_interference": 1.0}) <= 0.95, "失败率上界 0.95")
	a.is_true(MagicLevel.effective_rate(MagicLevel.Tier.LEGEND, {}) >= 0.005, "失败率下界 0.005（没有绝对成功）")

	# 资质偏移（data/aptitudes.json 的 failure_delta）
	a.near(MagicLevel.effective_rate(MagicLevel.Tier.FIRST_YEAR, {}, -0.10), 0.30, 0.0001, "优秀资质降低失败率")

	# 未知修正键必须被忽略而不是崩
	a.near(MagicLevel.effective_rate(MagicLevel.Tier.FIRST_YEAR, {"不存在的因素": 5.0}), 0.40, 0.0001, "未知修正键被忽略")

	return a.report("magic_level")
