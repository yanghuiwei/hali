class_name CreationTest
extends RefCounted

func base_choices() -> Dictionary:
	return {
		"era_id": "modern",
		"bloodline_id": "muggle_born",
		"birth_identity_id": "ordinary_wizard_family",
		"name_text": "张三",
		"gender": "男",
		"age_years": 11,
		"birthplace": "london_muggle",
		"family_status": "父母均为麻瓜，家中无人相信魔法",
		"aptitude_id": "normal",
		"aptitude_special": "",
		"wand": {},
		"house_id": "system",
		"political_leaning_id": "free_independent",
		"personality": ["好奇", "固执", "怕黑"],
		"life_goal": "我想知道魔法到底能走多远",
		"sim_style_id": "mixed",
	}

func run() -> int:
	var a := TestAssert.new()
	var reg := Registry.load_default()

	# 内容表新增项
	a.eq(reg.validate().size(), 0, "技能与魔杖表加入后仍无校验错误")
	a.is_true(reg.ids("skills").size() >= 19, "技能表至少 19 项")
	a.is_true(reg.ids("wand_lengths").size() >= 10, "魔杖长度档位充足")
	a.is_true(reg.ids("wand_cores").size() >= 6, "杖芯至少 6 种")
	a.is_true(reg.ids("wand_woods").size() >= 10, "木材至少 10 种")

	# 血统/身份里的 skill_bias 必须全部指向真实技能（跨表完整性）
	for bloodline_id in reg.ids("bloodlines"):
		for skill_id in reg.entry("bloodlines", bloodline_id).get("skill_bias", {}).keys():
			a.is_true(reg.has("skills", skill_id), "血统 %s 引用了未定义技能 %s" % [bloodline_id, skill_id])
	for identity_id in reg.ids("birth_identities"):
		for skill_id in reg.entry("birth_identities", identity_id).get("skill_bias", {}).keys():
			a.is_true(reg.has("skills", skill_id), "身份 %s 引用了未定义技能 %s" % [identity_id, skill_id])

	# ---- 合法创建 ----
	var rng := RngService.new(20260918)
	var result := CharacterCreation.create(base_choices(), reg, rng)
	a.eq(result.errors.size(), 0, "合法选择不应报错")
	var p := result.player
	a.eq(p.name_text, "张三", "姓名")
	a.eq(p.age_months, 132, "11 岁 = 132 个月")
	a.eq(p.money().formatted(), "10加隆 0西可 0纳特", "普通巫师家庭起始财产（第十八章自洽）")
	a.eq(p.sim_style_id, "mixed", "模拟风格")
	a.is_true(p.skill("muggle_world") >= 2, "麻瓜出身带来麻瓜世界见闻")
	a.is_true(p.skill("charms") >= 1, "普通巫师家庭带来魔咒基础")
	a.eq(p.personality.size(), 3, "三个性格关键词")
	a.is_true(p.wand.has("wood"), "生成魔杖木材")
	a.is_true(p.wand.has("label"), "魔杖有可读标签")
	a.eq(p.magic["known_spells"].size(), 0, "入学前不掌握咒语（第六十九章防主角光环）")
	a.is_true(p.alive, "活着")
	a.eq(p.location_id, "london_muggle", "出生地")

	# 魔杖长度必须来自内容表
	var length_ids := reg.ids("wand_lengths")
	a.is_true(length_ids.has(str(p.wand["length_inches"]).trim_suffix(".0")), "魔杖长度取自内容表")

	# ---- 确定性：同种子同选择 → 完全相同 ----
	var p_a := CharacterCreation.create(base_choices(), reg, RngService.new(99)).player
	var p_b := CharacterCreation.create(base_choices(), reg, RngService.new(99)).player
	a.eq(p_a.to_dict(), p_b.to_dict(), "同种子创建结果完全一致")

	# ---- 哑炮：无魔法，且不能有咒语/魔杖 ----
	var squib := base_choices()
	squib["bloodline_id"] = "squib"
	squib["aptitude_id"] = "squib"
	var squib_result := CharacterCreation.create(squib, reg, RngService.new(1))
	a.eq(squib_result.errors.size(), 0, "哑炮可以创建")
	a.eq(squib_result.player.magic_tier, MagicLevel.Tier.SQUIB, "哑炮等级")
	a.eq(squib_result.player.wand, {}, "哑炮没有魔杖")
	a.is_true(squib_result.player.magic["known_spells"].is_empty(), "哑炮没有咒语")
	a.is_true(squib_result.player.flags.has("no_magic"), "哑炮带 no_magic 标记")

	# ---- 血统与资质冲突必须报错，而不是静默修正（第七十五章：哑炮无魔法天赋） ----
	var conflict := base_choices()
	conflict["bloodline_id"] = "squib"
	conflict["aptitude_id"] = "excellent"
	var conflict_errors := CharacterCreation.validate_choices(conflict, reg)
	a.is_true(" | ".join(conflict_errors).contains("哑炮"), "哑炮血统与非哑炮资质冲突必须报错")

	# ---- 反漏洞：未选特殊资质时不得注入特殊天赋标记 ----
	var exploit := base_choices()
	exploit["aptitude_special"] = "parselmouth"
	var exploit_result := CharacterCreation.create(exploit, reg, RngService.new(11))
	a.is_true(exploit_result.errors.size() > 0, "非特殊资质携带 aptitude_special 必须被拒绝")
	a.is_true(exploit_result.player == null, "校验失败时不产出玩家")

	# ---- 出生地必须是合法地点 id（否则世界演化会静默过滤传闻） ----
	var bad_place := base_choices()
	bad_place["birthplace"] = "不存在的出生地"
	a.is_true(" | ".join(CharacterCreation.validate_choices(bad_place, reg)).contains("birthplace"), "非法出生地必须报错")

	# ---- 非法输入逐个报错 ----
	var bad := base_choices()
	bad["era_id"] = "不存在的时代"
	bad["bloodline_id"] = "不存在的血统"
	bad["age_years"] = 3
	bad["personality"] = ["只有一个"]
	bad["life_goal"] = ""
	var errs := CharacterCreation.validate_choices(bad, reg)
	var joined := " | ".join(errs)
	a.is_true(joined.contains("era_id"), "时代非法")
	a.is_true(joined.contains("bloodline_id"), "血统非法")
	a.is_true(joined.contains("age_years"), "年龄低于 11 必须报错")
	a.is_true(joined.contains("personality"), "性格不足 3 项")
	a.is_true(joined.contains("life_goal"), "目标为空")
	var empty_kw := base_choices()
	empty_kw["personality"] = ["", "好奇", "固执"]
	a.is_true(" | ".join(CharacterCreation.validate_choices(empty_kw, reg)).contains("personality"), "空性格关键词必须报错")

	# ---- 特殊资质必须指明具体天赋 ----
	var special := base_choices()
	special["aptitude_id"] = "special"
	special["aptitude_special"] = "parselmouth"
	var sp := CharacterCreation.create(special, reg, RngService.new(3))
	a.eq(sp.errors.size(), 0, "特殊资质带具体天赋")
	a.eq(sp.player.aptitude_special, "parselmouth", "记录蛇佬腔")
	a.is_true(sp.player.flags.has("parselmouth"), "蛇佬腔写入标记")
	special["aptitude_special"] = "不存在的天赋"
	a.is_true(" | ".join(CharacterCreation.validate_choices(special, reg)).contains("aptitude_special"), "非法天赋报错")

	# ---- 随机资质必须被掷定，且不能掷出哑炮（玩家没选哑炮血统） ----
	var rand_apt := base_choices()
	rand_apt["aptitude_id"] = "random"
	for i in 30:
		var r := CharacterCreation.create(rand_apt, reg, RngService.new(1000 + i))
		a.ne(r.player.aptitude_id, "squib", "随机资质不得变成哑炮")
		a.ne(r.player.aptitude_id, "random", "随机资质必须被解析")
		a.ne(r.player.aptitude_id, "special", "随机资质不得掷出未指定天赋的特殊资质")

	# ---- 学院判定 ----
	var sly := base_choices()
	sly["bloodline_id"] = "sacred_twenty_eight"
	sly["house_id"] = "system"
	sly["personality"] = ["野心", "精明", "算计"]
	var sly_house := CharacterCreation.assign_house(sly, RngService.new(7), reg)
	a.eq(sly_house, "slytherin", "血统偏置 + 性格匹配判定出斯莱特林")
	var forced := base_choices()
	forced["house_id"] = "ravenclaw"
	a.eq(CharacterCreation.assign_house(forced, RngService.new(7), reg), "ravenclaw", "玩家指定学院优先")
	var unschooled := base_choices()
	unschooled["house_id"] = "none"
	a.eq(CharacterCreation.assign_house(unschooled, RngService.new(7), reg), "none", "未入学不判学院")
	var squib_house := base_choices()
	squib_house["bloodline_id"] = "squib"
	squib_house["aptitude_id"] = "squib"
	a.eq(CharacterCreation.assign_house(squib_house, RngService.new(7), reg), "none", "哑炮不判学院")

	# ---- 全部 12 血统都能创建成功（内容全覆盖） ----
	for bloodline_id in reg.ids("bloodlines"):
		var c := base_choices()
		c["bloodline_id"] = bloodline_id
		if bloodline_id == "squib":
			c["aptitude_id"] = "squib"
		var r := CharacterCreation.create(c, reg, RngService.new(42))
		a.eq(r.errors.size(), 0, "血统 %s 可创建" % bloodline_id)

	# ---- 计划 03a（§8#69）：哑炮不进霍格沃茨 ----
	# ⚠️ 计划原文的测试片段实测有两个问题（控制器实测，见 task-12-report.md）：
	#   ① personality 只给 1 项 → validate_choices 报「需要 3 个性格关键词」⇒ player==null，
	#      后续 `squib_res.player.house_id` 是**空引用访问**，会把整个套件**中止**（红得不干净）。
	#   ② house_id="system" 时 assign_house 早就在 `magic_aptitude=false` 上返回 "none"
	#      （见本文件下方 "哑炮不判学院" 断言）⇒ 该断言**改前改后都绿 = 无判别力**。
	#   真正的缺陷路径是**玩家显式指定学院**（创建界面 house 下拉默认就是 gryffindor）⇒
	#   必须用 house_id="gryffindor" 才能判别（与 B1 探针实测到的 house_id=gryffindor 完全对应）。
	var t12_squib := {
		"era_id": "modern", "bloodline_id": "squib", "birth_identity_id": "ordinary_wizard_family",
		"name_text": "测试哑炮", "gender": "未定", "age_years": 11, "birthplace": "london_muggle",
		"family_status": "由系统生成", "aptitude_id": "squib", "aptitude_special": "", "wand": {},
		"house_id": "gryffindor", "political_leaning_id": "blood_equality",
		"personality": ["好奇", "固执", "怕黑"],
		"life_goal": "活下去", "sim_style_id": "brutal_realism",
	}
	var t12_squib_res := CharacterCreation.create(t12_squib, reg, RngService.new(5))
	a.eq(t12_squib_res.errors.size(), 0, "哑炮建角无错误")
	# 用「取不到就返回可鉴别的哨兵串」代替解引用，避免 null 中止套件（红要红得干净）
	var t12_squib_house := "<player==null>"
	if t12_squib_res.player != null:
		t12_squib_house = str(t12_squib_res.player.house_id)
	a.eq(t12_squib_house, "none", "哑炮不进霍格沃茨：显式指定 gryffindor 也必须被覆盖为 none")
	a.is_true(t12_squib_res.player != null and bool(t12_squib_res.player.flags.get("no_magic", false)),
		"哑炮仍无魔法")
	# 未显式指定学院（system）时同样是 none —— 防回归（这条改前就绿，不具判别力，只钉住不倒退）
	var t12_squib_sys := t12_squib.duplicate(true)
	t12_squib_sys["house_id"] = "system"
	var t12_squib_sys_res := CharacterCreation.create(t12_squib_sys, reg, RngService.new(5))
	var t12_squib_sys_house := "<player==null>"
	if t12_squib_sys_res.player != null:
		t12_squib_sys_house = str(t12_squib_sys_res.player.house_id)
	a.eq(t12_squib_sys_house, "none", "哑炮 + house_id=system 同样不入学")
	# 非哑炮：玩家显式指定学院必须仍然优先（不得被这次修正误伤）
	var t12_normal := t12_squib.duplicate(true)
	t12_normal["bloodline_id"] = "half_blood"
	t12_normal["aptitude_id"] = "normal"
	var t12_normal_res := CharacterCreation.create(t12_normal, reg, RngService.new(5))
	var t12_normal_house := "<player==null>"
	if t12_normal_res.player != null:
		t12_normal_house = str(t12_normal_res.player.house_id)
	a.eq(t12_normal_house, "gryffindor", "非哑炮：玩家指定学院仍然优先")

	# ---- 计划 03a（§8#21）：杖芯权重必须真的生效 ----
	# ⚠️ rarity 是字符串标签，float("common")==0.0，不能直接当权重；权重来自新增的数值字段 "weight"。
	var t12_core_entries: Array = []
	for cid in reg.ids("wand_cores"):
		t12_core_entries.append(reg.entry("wand_cores", str(cid)))
	var t12_weighted_rng := RngService.new(7)
	var t12_common_hits := 0
	var t12_rare_hits := 0
	for i in 3000:
		var t12_picked: Dictionary = t12_weighted_rng.stream_pick_weighted("wand_core_test", t12_core_entries, "weight")
		if str(t12_picked.get("rarity", "")) == "rare":
			t12_rare_hits += 1
		else:
			t12_common_hits += 1
	a.is_true(t12_common_hits > t12_rare_hits * 4,
		"常见杖芯显著多于稀有杖芯（weight 生效；全为 1 时均匀⇒必红）实际 common=%d rare=%d" % [t12_common_hits, t12_rare_hits])
	a.is_true(t12_rare_hits > 0, "稀有杖芯仍会被抽中（weight 不是硬排除）")
	# 端到端：光是 helper 正确还不够，generate_wand 必须真的走权重（把 "weight" 改回 "rarity" 时本条必红）
	var t12_wand_rare := 0
	for i in 400:
		var t12_wand := CharacterCreation.generate_wand(RngService.new(5000 + i), reg)
		if str(reg.entry("wand_cores", str(t12_wand["core"])).get("rarity", "")) == "rare":
			t12_wand_rare += 1
	a.is_true(t12_wand_rare < 120,
		"generate_wand 的稀有杖芯远低于均匀占比（400 支里 %d 支；均匀时≈200，加权时≈57）" % t12_wand_rare)

	return a.report("creation")
