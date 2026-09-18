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

	return a.report("creation")
