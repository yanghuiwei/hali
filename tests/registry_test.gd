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

	# ---- 计划 03a：派系与政体内容表 ----
	var factions := reg.ids("factions")
	a.eq(factions.size(), 17, "派系表 17 条")
	for fid in ["ministry", "auror_office", "wizengamot", "mysteries", "hogwarts",
			"sacred_twenty_eight", "reformist_pureblood", "death_eaters", "order_of_phoenix",
			"gringotts", "diagon_merchants", "daily_prophet", "black_market",
			"common_folk", "international_confederation", "continental_pureblood", "muggle_world"]:
		a.is_true(reg.has("factions", str(fid)), "派系 %s 存在" % str(fid))
	a.eq(reg.ids("governments").size(), 4, "政体表 4 条")

	# 枚举与引用完整性（后续 WorldFactions.validate_content 也要做同样的事，这里是内容表自检）
	var kinds := ["ministry", "institution", "pureblood", "school", "commerce", "media",
		"resistance", "dark", "foreign", "society"]
	var insts := ["law_enforcement", "auror_office", "wizengamot", "mysteries",
		"hogwarts", "gringotts", "daily_prophet", "international"]
	for fid in factions:
		var e := reg.entry("factions", str(fid))
		a.is_true(kinds.has(str(e.get("kind", ""))), "%s: kind 合法" % fid)
		a.is_true(["legal", "shadow", "outlaw"].has(str(e.get("legal_status", ""))), "%s: legal_status 合法" % fid)
		a.is_true(["public", "semi", "secret"].has(str(e.get("secrecy", ""))), "%s: secrecy 合法" % fid)
		a.between(float(e.get("base_power", -1.0)), 0.0, 1.0, "%s: base_power 在 0..1" % fid)
		a.is_true(not str(e.get("agenda", "")).is_empty(), "%s: 有 agenda" % fid)
		for inst in (e.get("institutions", []) as Array):
			a.is_true(insts.has(str(inst)), "%s: 机构 %s 合法" % [fid, str(inst)])
		for other in (e.get("rivals", []) as Array):
			a.is_true(reg.has("factions", str(other)), "%s: rival %s 存在" % [fid, str(other)])
		for other in (e.get("allies", []) as Array):
			a.is_true(reg.has("factions", str(other)), "%s: ally %s 存在" % [fid, str(other)])
		var overrides = e.get("era_overrides", {})
		if typeof(overrides) == TYPE_DICTIONARY:
			for era_id in (overrides as Dictionary).keys():
				a.is_true(reg.has("eras", str(era_id)), "%s: era_overrides 的 %s 是真时代" % [fid, str(era_id)])

	# 校验器必须抓到坏派系内容
	var bad := Registry.from_tables({
		"eras": [{"id": "a", "label": "甲"}],
		"factions": [{"id": "x", "label": "坏派系", "kind": "bogus", "legal_status": "legal",
			"secrecy": "public", "base_power": 0.5}],
		"governments": [{"id": "g", "label": "政体", "summary": "说明"}],
	})
	var bad_joined := " | ".join(bad.validate())
	a.is_true(bad_joined.contains("kind 非法"), "坏 kind 必须报错")
	a.is_true(bad_joined.contains("缺少数据表"), "缺失数据表仍需报错")
	var bad_power := Registry.from_tables({
		"eras": [{"id": "a", "label": "甲"}],
		"factions": [{"id": "x", "label": "坏派系", "kind": "dark", "legal_status": "legal",
			"secrecy": "public", "base_power": 1.5}],
		"governments": [{"id": "g", "label": "政体", "summary": "说明"}],
	})
	a.is_true(" | ".join(bad_power.validate()).contains("base_power 超值域"), "base_power 越界必须报错")

	# registry 的表内枚举与 WorldFactions 常量必须一致（防两处定义漂移）
	a.eq(insts, WorldFactions.INSTITUTIONS, "机构枚举两处一致")
	a.eq(kinds, WorldFactions.KINDS, "kind 枚举两处一致")

	return a.report("registry")
