class_name RegistryTest
extends RefCounted

func run() -> int:
	var a := TestAssert.new()
	var reg := Registry.load_default()

	# 正典内容表完整性
	var errors := reg.validate()
	for e in errors:
		a.fail("内容表校验失败: " + e)
	a.eq(errors.size(), 0, "默认内容表应无错误")

	# 第七十五章启动界面的选项数量必须与规格一致
	a.eq(reg.ids("eras").size(), 8, "时代 8 项")
	a.eq(reg.ids("bloodlines").size(), 12, "血统 12 项")
	a.eq(reg.ids("birth_identities").size(), 11, "出生身份 11 项")
	a.eq(reg.ids("aptitudes").size(), 6, "魔法资质 6 项")
	a.eq(reg.ids("houses").size(), 6, "学院倾向 6 项")
	a.eq(reg.ids("sim_styles").size(), 6, "模拟风格 6 项")
	a.eq(reg.ids("political_leanings").size(), 6, "政治倾向 6 项")

	# 标签必须与规格逐字一致
	a.eq(reg.entry("eras", "hogwarts_founding")["label"], "霍格沃茨建校早期", "第一时代标签")
	a.eq(reg.entry("eras", "custom")["label"], "自定义时代", "第八时代标签")
	a.eq(reg.entry("bloodlines", "squib")["label"], "哑炮", "哑炮标签")
	a.eq(reg.entry("bloodlines", "obscurial")["label"], "默然者", "默然者标签")
	a.eq(reg.entry("aptitudes", "squib")["label"], "哑炮无魔法天赋", "资质标签")

	# 关键字查询
	a.is_true(reg.has("bloodlines", "werewolf"), "狼人存在")
	a.is_false(reg.has("bloodlines", "dragon"), "不存在的血统")
	a.eq(reg.entry("eras", "没有这个时代"), {}, "缺失条目返回空字典")
	a.eq(reg.entry("bloodlines", "hogwarts_founding"), {}, "跨表查询不得命中")

	# 关键语义字段
	a.is_false(reg.entry("bloodlines", "squib")["magic_aptitude"], "哑炮无魔法天赋")
	a.is_true(reg.entry("bloodlines", "muggle_born")["magic_aptitude"], "麻瓜出身有魔法天赋")
	a.eq(reg.entry("eras", "witch_hunts")["start_year"], 1692, "保密法年份 1692")
	a.eq(reg.entry("eras", "custom")["start_year"], null, "自定义时代年份为空")
	a.eq(reg.entry("aptitudes", "squib")["grants"].size(), 0, "哑炮不授予特殊天赋")

	# 校验器必须能抓到坏数据
	var dup := Registry.from_tables({
		"eras": [
			{"id": "a", "label": "甲"},
			{"id": "a", "label": "乙"},
		],
	})
	var dup_errors := dup.validate()
	var joined := " | ".join(dup_errors)
	a.is_true(joined.contains("重复 id"), "重复 id 必须报错")
	a.is_true(joined.contains("缺少数据表"), "缺失数据表必须报错")

	var no_label := Registry.from_tables({"eras": [{"id": "a"}]})
	a.is_true(" | ".join(no_label.validate()).contains("缺少 label"), "缺 label 必须报错")

	# ids() 必须稳定排序，保证 UI 下拉顺序可复现
	var ids := reg.ids("houses")
	var sorted_copy := ids.duplicate()
	sorted_copy.sort()
	a.eq(ids, sorted_copy, "ids 已排序")

	return a.report("registry")
