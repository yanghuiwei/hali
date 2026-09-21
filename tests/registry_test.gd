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

	a.eq(reg.ids("political_events").size(), 5, "政治事件表 5 条")
	for eid in reg.ids("political_events"):
		var pe := reg.entry("political_events", str(eid))
		a.is_true(not str(pe.get("text", "")).is_empty(), "政治事件 %s 有文案" % str(eid))
		a.is_true(["politics", "economy", "law"].has(str(pe.get("category", ""))), "政治事件 %s category 合法" % str(eid))
		a.is_true(not str(pe.get("condition", "")).is_empty(), "政治事件 %s 有 condition" % str(eid))
	# 五个事件必须都指向 event_condition_met() 认识的条件（写错条件名会让事件永远选不出来也永远不报错）
	var known_conditions := ["economic_slump", "oligarchy_pressure", "lawlessness", "war_exhaustion", "secrecy_crisis"]
	var conditions := PackedStringArray()
	for eid in reg.ids("political_events"):
		var condition := str(reg.entry("political_events", str(eid)).get("condition", ""))
		a.is_true(known_conditions.has(condition), "政治事件 %s 的 condition 在代码白名单内（%s）" % [str(eid), condition])
		if not conditions.has(condition):
			conditions.append(condition)
	a.is_true(conditions.size() >= 4, "至少覆盖 4 种不同条件（实际 %d 种）" % conditions.size())

	# 校验器必须抓到坏政治事件
	var bad_event := Registry.from_tables({
		"eras": [{"id": "a", "label": "甲"}],
		"factions": [{"id": "x", "label": "派", "kind": "dark", "legal_status": "legal",
			"secrecy": "public", "base_power": 0.5, "institutions": [], "rivals": [], "allies": []}],
		"governments": [{"id": "g", "label": "政体", "summary": "说明"}],
		"political_events": [{"id": "bad", "label": "坏事件", "category": "bogus", "condition": "", "text": ""}],
	})
	var bad_event_errors := " | ".join(bad_event.validate())
	a.is_true(bad_event_errors.contains("category 非法"), "政治事件坏 category 必须报错")
	a.is_true(bad_event_errors.contains("缺少 text"), "政治事件缺 text 必须报错")
	a.is_true(bad_event_errors.contains("缺少 condition"), "政治事件缺 condition 必须报错")

	# ---- 计划 03a Task 6：reveals_faction 的引用完整性 ----
	var reveal_count := 0
	for rid in reg.ids("rumors"):
		var re := reg.entry("rumors", str(rid))
		var reveal_target := str(re.get("reveals_faction", ""))
		if not reveal_target.is_empty():
			reveal_count += 1
			a.is_true(reg.has("factions", reveal_target), "传闻 %s 的 reveals_faction 存在（%s）" % [str(rid), reveal_target])
	a.is_true(reveal_count >= 3, "至少 3 条传闻用于揭示派系（实际 %d）" % reveal_count)

	# 内容校验：坏类型与坏引用都要被拦（不能只看正向）
	var bad_reveal := Registry.from_tables({
		"eras": [{"id": "a", "label": "甲"}],
		"factions": [{"id": "x", "label": "派", "kind": "dark", "legal_status": "legal", "secrecy": "public",
			"base_power": 0.5, "institutions": [], "rivals": [], "allies": []}],
		"governments": [{"id": "g", "label": "政体", "summary": "说明"}],
		"rumors": [{"id": "r", "label": "传闻", "text": "t", "reveals_faction": 123}],
	})
	a.is_true(" | ".join(bad_reveal.validate()).contains("reveals_faction 必须是字符串"),
		"rumors 表坏类型的 reveals_faction 必须报错")
	a.is_true(" | ".join(WorldFactions.validate_content(bad_reveal)).contains("引用不存在的派系"),
		"validate_content 必须拦下 reveals_faction 的坏引用")

	# ---- 计划 03b：商品与产业内容表 ----
	var goods := reg.ids("goods")
	a.eq(goods.size(), 35, "商品表 35 条")
	var cats := ["wand", "potion", "material", "broom", "book", "food",
		"service", "creature", "artifact", "illegal"]
	var goods_kinds := ["goods", "service"]
	var n_service := 0
	var n_anchor := 0
	for gid in goods:
		var ge := reg.entry("goods", str(gid))
		a.is_true(cats.has(str(ge.get("category", ""))), "%s: category 合法" % gid)
		a.is_true(goods_kinds.has(str(ge.get("kind", ""))), "%s: kind 合法" % gid)
		a.is_true(int(ge.get("base_price_knuts", 0)) > 0, "%s: base_price > 0" % gid)
		a.is_true(int(ge.get("canon_price_knuts", 0)) >= 0, "%s: canon_price >= 0" % gid)
		a.is_true(not str(ge.get("unit", "")).is_empty(), "%s: 有 unit" % gid)
		var iid := str(ge.get("industry_id", ""))
		if str(ge.get("kind", "")) == "service":
			n_service += 1
		elif iid.is_empty():
			# 缺陷⑨：食物（黄油啤酒/南瓜馅饼）无产业归属，`industry_id == ""`。
			# 与 `svc_*` 服务行同款语义：空 = 无产业，不是坏引用。
			pass
		else:
			a.is_true(reg.has("industries", iid), "%s: industry_id %s 存在" % [gid, iid])
		if int(ge.get("canon_price_knuts", 0)) > 0:
			n_anchor += 1
			a.eq(int(ge.get("canon_line", 0)), 223, "%s: 锚点商品 canon_line=223" % gid)
	a.eq(n_service, 10, "服务类 10 条")
	a.eq(n_anchor, 4, "正典锚点商品 4 条")

	# 正典锚点必须与正典原文数值一致（钉死，防改价时忘了正典）
	a.eq(int(reg.entry("goods", "wand_standard")["canon_price_knuts"]), 3451, "普通魔杖 canon 7 加隆")
	a.eq(int(reg.entry("goods", "potion_healing")["canon_price_knuts"]), 2465, "优质疗伤 canon 5 加隆")
	a.eq(int(reg.entry("goods", "broom_nimbus")["canon_price_knuts"]), 49300, "光轮 canon 100 加隆")

	var inds := reg.ids("industries")
	a.eq(inds.size(), 9, "产业表 9 条")
	for iid2 in ["potion_brewing", "wandmaking", "broommaking", "publishing", "quidditch",
			"creature_breeding", "archaeology", "curse_breaking", "finance"]:
		a.is_true(reg.has("industries", str(iid2)), "产业 %s 存在" % str(iid2))
	for iid3 in inds:
		var ie := reg.entry("industries", str(iid3))
		a.between(float(ie.get("base_output", -1.0)), 0.0, 1.0, "%s: base_output 在 0..1" % iid3)
		for p in (ie.get("produces", []) as Array):
			a.is_true(reg.has("goods", str(p)), "%s: produces %s 存在" % [iid3, str(p)])

	# registry 的表内枚举与 Economy 常量必须一致（防两处定义漂移；与 03a 的机构枚举同款做法）
	a.eq(cats, Economy.CATEGORIES, "商品 category 枚举两处一致")
	a.eq(goods_kinds, Economy.KINDS, "商品 kind 枚举两处一致")

	# 校验器必须抓到坏商品内容
	var bad_goods := Registry.from_tables({
		"eras": [{"id": "a", "label": "甲"}],
		"goods": [{"id": "x", "label": "坏商品", "category": "bogus", "kind": "goods",
			"base_price_knuts": 10, "industry_id": "", "unit": "个"}],
		"industries": [{"id": "i", "label": "产业", "produces": [], "base_output": 0.5}],
	})
	a.is_true(" | ".join(bad_goods.validate()).contains("category 非法"), "坏 category 被抓到")

	# kind 非法也要被抓到
	var bad_kind := Registry.from_tables({
		"eras": [{"id": "a", "label": "甲"}],
		"goods": [{"id": "x", "label": "坏商品", "category": "wand", "kind": "bogus",
			"base_price_knuts": 10, "industry_id": "i", "unit": "个"}],
		"industries": [{"id": "i", "label": "产业", "produces": ["x"], "base_output": 0.5}],
	})
	a.is_true(" | ".join(bad_kind.validate()).contains("kind 非法"), "坏 kind 被抓到")

	# 引用不存在的 industry 也要被抓到
	var bad_ref := Registry.from_tables({
		"eras": [{"id": "a", "label": "甲"}],
		"goods": [{"id": "y", "label": "孤儿商品", "category": "wand", "kind": "goods",
			"base_price_knuts": 10, "industry_id": "nonexistent", "unit": "根"}],
		"industries": [{"id": "i", "label": "产业", "produces": [], "base_output": 0.5}],
	})
	a.is_true(" | ".join(bad_ref.validate()).contains("industry_id 不存在"), "坏 industry_id 引用被抓到")

	# 服务类允许 industry_id 为空（不参与断供）
	var svc_ok := Registry.from_tables({
		"eras": [{"id": "a", "label": "甲"}],
		"goods": [{"id": "s", "label": "服务", "category": "service", "kind": "service",
			"base_price_knuts": 17, "industry_id": "", "unit": "次"}],
		"industries": [{"id": "i", "label": "产业", "produces": [], "base_output": 0.5}],
	})
	a.is_false(" | ".join(svc_ok.validate()).contains("service/s"),
		"服务类空 industry_id 合法（s）")

	# base_price 落到正典合理带之外要被抓到（C6：常态价必须落在 canon 区间内）
	var bad_band := Registry.from_tables({
		"eras": [{"id": "a", "label": "甲"}],
		"goods": [{"id": "z", "label": "价格离谱", "category": "wand", "kind": "goods",
			"canon_price_knuts": 3451, "canon_price_hi_knuts": 4930, "canon_line": 223,
			"base_price_knuts": 999999, "industry_id": "i", "unit": "根"}],
		"industries": [{"id": "i", "label": "产业", "produces": ["z"], "base_output": 0.7}],
	})
	a.is_true(" | ".join(bad_band.validate()).contains("超出正典合理带"),
		"base_price 超出正典合理带被抓到")

	# base 在 canon 区间内、但危机峰价突破 canon_hi —— 也必须被抓到（这才是 C3 的本体）
	var bad_peak := Registry.from_tables({
		"eras": [{"id": "a", "label": "甲"}],
		"goods": [{"id": "z2", "label": "危机越界", "category": "wand", "kind": "goods",
			"canon_price_knuts": 3451, "canon_price_hi_knuts": 4930, "canon_line": 223,
			"base_price_knuts": 4560, "industry_id": "i", "unit": "根"}],
		"industries": [{"id": "i", "label": "产业", "produces": ["z2"], "base_output": 0.7}],
	})
	a.is_true(" | ".join(bad_peak.validate()).contains("危机峰价突破正典上沿"),
		"危机峰价突破 canon_hi 被抓到")

	# 锚点商品缺 canon_line 也要被抓到
	var bad_line := Registry.from_tables({
		"eras": [{"id": "a", "label": "甲"}],
		"goods": [{"id": "w", "label": "缺行号", "category": "wand", "kind": "goods",
			"canon_price_knuts": 3451, "canon_price_hi_knuts": 4930, "canon_line": 0,
			"base_price_knuts": 3451, "industry_id": "i", "unit": "根"}],
		"industries": [{"id": "i", "label": "产业", "produces": ["w"], "base_output": 0.7}],
	})
	a.is_true(" | ".join(bad_line.validate()).contains("canon_line"),
		"锚点商品缺 canon_line 被抓到")

	# 锚点商品缺 canon_price_hi_knuts 也要被抓到（补这个字段是为了让 C3 有真上界）
	var bad_hi := Registry.from_tables({
		"eras": [{"id": "a", "label": "甲"}],
		"goods": [{"id": "w2", "label": "缺上沿", "category": "wand", "kind": "goods",
			"canon_price_knuts": 3451, "canon_price_hi_knuts": 0, "canon_line": 223,
			"base_price_knuts": 3451, "industry_id": "i", "unit": "根"}],
		"industries": [{"id": "i", "label": "产业", "produces": ["w2"], "base_output": 0.7}],
	})
	a.is_true(" | ".join(bad_hi.validate()).contains("canon_price_hi_knuts"),
		"锚点商品缺 canon_price_hi 被抓到")

	# 顶级疗伤药剂（共享 canon 区间、base 取上段）必须**不被**误判 —— 这正是补 canon_price_hi 字段的原因
	var premium_ok := Registry.from_tables({
		"eras": [{"id": "a", "label": "甲"}],
		"goods": [{"id": "p", "label": "顶级", "category": "potion", "kind": "goods",
			"canon_price_knuts": 2465, "canon_price_hi_knuts": 9860, "canon_line": 223,
			"base_price_knuts": 6162, "industry_id": "i", "unit": "瓶"}],
		"industries": [{"id": "i", "label": "产业", "produces": ["p"], "base_output": 0.75}],
	})
	a.is_false(" | ".join(premium_ok.validate()).contains("goods/p"),
		"共享 canon 区间取上段的条目不被误判（p）")

	# 锚点商品的 canon_price_hi 必须严格不小于 canon_price_lo（写反了会让 C3 形同虚设）
	for gid4 in goods:
		var ge4 := reg.entry("goods", str(gid4))
		if int(ge4.get("canon_price_knuts", 0)) > 0:
			a.is_true(int(ge4.get("canon_price_hi_knuts", 0)) >= int(ge4["canon_price_knuts"]),
				"%s: canon_hi >= canon_lo" % gid4)
			a.is_true(roundi(float(ge4["base_price_knuts"]) * Economy.MAX_SCARCITY)
				<= int(ge4["canon_price_hi_knuts"]),
				"%s: 危机峰价守 canon_hi" % gid4)

	# 产业 produces 引用不存在的商品要被抓到
	var bad_produce := Registry.from_tables({
		"eras": [{"id": "a", "label": "甲"}],
		"goods": [{"id": "g1", "label": "商品", "category": "wand", "kind": "goods",
			"base_price_knuts": 10, "industry_id": "i", "unit": "根"}],
		"industries": [{"id": "i", "label": "产业", "produces": ["不存在"], "base_output": 0.5}],
	})
	a.is_true(" | ".join(bad_produce.validate()).contains("produces 引用不存在的商品"),
		"产业 produces 坏引用被抓到")

	# 产业 base_output 越界要被抓到
	var bad_output := Registry.from_tables({
		"eras": [{"id": "a", "label": "甲"}],
		"goods": [{"id": "g1", "label": "商品", "category": "wand", "kind": "goods",
			"base_price_knuts": 10, "industry_id": "i", "unit": "根"}],
		"industries": [{"id": "i", "label": "产业", "produces": ["g1"], "base_output": 1.7}],
	})
	a.is_true(" | ".join(bad_output.validate()).contains("base_output 超值域"),
		"产业 base_output 越界被抓到")

	# ---- 计划 03b Task 5：jobs 表（缺陷⑩）----
	var jobs := reg.ids("jobs")
	a.eq(jobs.size(), 9, "职业表 9 条（正典 198 行逐条对应）")
	for jid in jobs:
		var je := reg.entry("jobs", str(jid))
		a.is_true(not str(je.get("label", "")).is_empty(), "job/%s: 有 label" % jid)
		a.is_true(int(je.get("wage_knuts", 0)) > 0, "job/%s: wage_knuts 为正" % jid)
		a.eq(int(je.get("canon_line", 0)), 198, "job/%s: canon_line == 198" % jid)
	# 量级锚点上下沿（spec §7.6 + 缺陷⑪修正）：下沿 2958 硬约束；
	# 上沿 9860 只有 quidditch_pro 可达，其余 8 条**严格小于**。
	a.eq(int(reg.entry("jobs", "quidditch_pro")["wage_knuts"]), 9860, "魁地奇球员 20 加隆")
	for jid2 in jobs:
		var w2 := int(reg.entry("jobs", str(jid2))["wage_knuts"])
		a.is_true(w2 >= 2958, "job/%s: >= 6 加隆下沿" % jid2)
		if str(jid2) != "quidditch_pro":
			a.is_true(w2 < 9860, "job/%s: 不触及 20 加隆上沿" % jid2)

	# 坏职业：工资越界要被抓到
	var bad_job := Registry.from_tables({
		"eras": [{"id": "a", "label": "甲"}],
		"jobs": [{"id": "cheat", "label": "作弊职业", "wage_knuts": 100000, "canon_line": 198}],
	})
	a.is_true(" | ".join(bad_job.validate()).contains("wage_knuts 超出量级锚点"),
		"职业工资越界被抓到")

	# 坏职业：缺 canon_line 要被抓到
	var bad_job_line := Registry.from_tables({
		"eras": [{"id": "a", "label": "甲"}],
		"jobs": [{"id": "noline", "label": "无行号", "wage_knuts": 4930, "canon_line": 0}],
	})
	a.is_true(" | ".join(bad_job_line.validate()).contains("canon_line"),
		"职业缺 canon_line 被抓到")

	return a.report("registry")
