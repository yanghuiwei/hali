class_name PanelFormatter
extends RefCounted

const UNKNOWN := "未知"

static func _label(world: WorldState, table: String, id: String) -> String:
	var label := str(world.registry.entry(table, id).get("label", ""))
	return label if not label.is_empty() else (id if not id.is_empty() else UNKNOWN)

static func _magic_level_label(player: PlayerState) -> String:
	return MagicLevel.label_of(player.magic_tier)

static func _skills_line(player: PlayerState, world: WorldState) -> String:
	var parts: Array[String] = []
	var keys := player.skills.keys()
	keys.sort()
	for skill_id in keys:
		parts.append("%s %d" % [_label(world, "skills", str(skill_id)), int(player.skills[skill_id])])
	if parts.is_empty():
		return "无"
	return "、".join(parts)

static func _top_skill(player: PlayerState, world: WorldState) -> String:
	var best_id := ""
	var best_value := -1
	for skill_id in player.skills.keys():
		var v := int(player.skills[skill_id])
		if v > best_value:
			best_value = v
			best_id = str(skill_id)
	if best_id.is_empty():
		return UNKNOWN
	return _label(world, "skills", best_id)

# 第六十二章
static func player_panel(world: WorldState) -> String:
	var p := world.player
	var lines: Array[String] = []
	lines.append("《哈利·波特·魔法纪元·人生状态》")
	lines.append("【姓名】%s" % p.name_text)
	lines.append("【时间】%s 【年龄】%d岁 【血统】%s" % [world.clock.formatted(), p.age_years(), _label(world, "bloodlines", p.bloodline_id)])
	lines.append("【身份】%s 【所在地】%s 【职业】%s" % [_label(world, "houses", p.house_id), _label(world, "locations", p.location_id), (p.job if not p.job.is_empty() else "无")])
	lines.append(_wealth_line(world))
	lines.append(_economy_line(world))
	lines.append("【社会地位】%s 【魔法能力】%s 【战斗能力】%s" % [_label(world, "political_leanings", p.political_leaning_id), _magic_level_label(p), _top_skill(p, world)])
	lines.append("【魔药/治疗】%s 【技能】%s" % [str(p.skill("potions")), _skills_line(p, world)])
	lines.append("【声望】%d 【重要关系】%d人 【所属势力】%s" % [p.reputation, p.relations.size(), (_label(world, "factions", p.faction_id) if not p.faction_id.is_empty() else "无")])
	lines.append("【当前目标】%s" % (p.current_goal if not p.current_goal.is_empty() else UNKNOWN))
	return "\n".join(lines)

# 计划 03b Task 7：【财富】= 随身现金 + 【家庭】。
# 有古灵阁存款时追加「（含古灵阁 X）」，**余额为 0 时不追加** —— 避免开局就多一个恒为 0 的括号。
static func _wealth_line(world: WorldState) -> String:
	var p := world.player
	var out := "【财富】%s" % p.money().formatted()
	var balance := int(world.economy.get("gringotts_balance", 0))
	if balance != 0:
		out += "（含古灵阁 %s）" % Money.from_knuts(balance).formatted()
	return "%s 【家庭】%s" % [out, _label(world, "birth_identities", p.birth_identity_id)]

# 计划 03b Task 7：新增【经济】行 —— 景气 / 存款月息 / 汇率 / 本月净收支。
# ⚠️ 净支出走「-" + 正数格式化」而不是把负数交给 Money.formatted()：
#    后者在 03b Task 3 之后会输出「负债 X」，与这里的「本月 -X」语义重复（spec §7.6）。
static func _economy_line(world: WorldState) -> String:
	var vars := world.world_vars
	var econ := world.economy
	var index := float(vars.get("economy_index", 0.0))
	var rate := float(econ.get("gringotts_interest_rate", 0.0))
	var rate_pct := rate * 100.0
	var foreign := float(econ.get("foreign_rate", 0.0))
	var net := int(econ.get("last_month_income", 0)) - int(econ.get("last_month_expense", 0))
	var net_text := ""
	if net > 0:
		net_text = "本月 +%s" % Money.from_knuts(net).formatted()
	elif net < 0:
		net_text = "本月 -%s" % Money.from_knuts(-net).formatted()
	else:
		net_text = "本月 无收支"
	return "【经济】景气 %.2f ｜ 存款月息 %.2f%% ｜ 汇率 %.2f ｜ %s" % [index, rate_pct, foreign, net_text]


# 第六十三章
static func magic_panel(world: WorldState) -> String:
	var p := world.player
	var lines: Array[String] = []
	lines.append("《哈利·波特·魔法纪元·魔法能力》")
	if p.magic_tier == MagicLevel.Tier.SQUIB or p.flags.has("no_magic"):
		lines.append("【魔杖】未拥有（无魔法天赋：哑炮仍可看见魔法世界，但无法施展咒语）")
		lines.append("【魔法能力】无魔法天赋 【魔力容量】— 【控制精度】— 【魔法亲和】—")
		lines.append("【主修科目】— 【已掌握魔咒】— 【实验中的魔法】—")
		lines.append("【魔药水平】%d 【大脑封闭术】— 【幻影移形】— 【守护神形态】—" % p.skill("potions"))
		return "\n".join(lines)
	var wand_label := str(p.wand.get("label", ""))
	if wand_label.is_empty():
		wand_label = "未拥有"
	var subjects: Array = p.magic.get("subjects", [])
	var subject_labels: Array[String] = []
	for s in subjects:
		subject_labels.append(_label(world, "skills", str(s)))
	var spell_labels: Array[String] = []
	for spell_id in p.magic.get("known_spells", []):
		spell_labels.append(_label(world, "spells", str(spell_id)))
	lines.append("【魔杖】%s" % wand_label)
	lines.append("【魔力容量】%d 【控制精度】%d 【魔法亲和】%d" % [
		int(p.magic.get("capacity", 0)), int(p.magic.get("control", 0)), int(p.magic.get("affinity", 0))])
	lines.append("【主修科目】%s 【已掌握魔咒】%s 【实验中的魔法】%s" % [
		("、".join(subject_labels) if not subject_labels.is_empty() else "无"),
		("、".join(spell_labels) if not spell_labels.is_empty() else "无"),
		("、".join(p.magic.get("experimenting", [])) if not (p.magic.get("experimenting", []) as Array).is_empty() else "无")])
	lines.append("【魔药水平】%d 【大脑封闭术】%d" % [int(p.magic.get("potions", p.skill("potions"))), int(p.magic.get("occlumency", 0))])
	lines.append("【幻影移形】%d 【守护神形态】%s" % [int(p.magic.get("apparition", 0)), (str(p.magic.get("patronus", "")) if not str(p.magic.get("patronus", "")).is_empty() else "未成形")])
	return "\n".join(lines)

# 第六十四章
static func relation_panel(world: WorldState) -> String:
	var p := world.player
	var lines: Array[String] = []
	lines.append("《哈利·波特·魔法纪元·社会关系》")
	if p.relations.is_empty():
		lines.append("（暂无关键人物。人脉不会自动产生，需要行动与时间。）")
		return "\n".join(lines)
	var ids := p.relations.keys()
	ids.sort()
	for npc_id in ids:
		var rel: Dictionary = p.relations[npc_id]
		lines.append("【关键人物】姓名：%s 身份：%s 血统：%s" % [
			str(rel.get("name", npc_id)), str(rel.get("identity", UNKNOWN)), str(rel.get("bloodline", UNKNOWN))])
		lines.append("关系：%s 信任：%d 利益：%d 敌意：%d" % [
			str(rel.get("relation", UNKNOWN)), int(rel.get("trust", 0)), int(rel.get("interest", 0)), int(rel.get("hostility", 0))])
		lines.append("最近动态：%s" % str(rel.get("recent", "无")))
	return "\n".join(lines)

# 第六十五章（计划 03a 重写）：机构级指标（法律执行/傲罗/威森加摩/国际/校方）来自**派系的机构控制权**，
# 标量级指标（财政/稳定度/腐败度/纯血影响/麻瓜关系）来自 `world_vars`。
# 这修掉 HANDOFF §8#7：「7 个标签被硬映射到 4 个 world_vars」（机构本来就该是实体属性，第十二章权力四角 + 第二十六章魔法部体系）。
static func power_panel(world: WorldState) -> String:
	var vars := world.world_vars
	var ic := WorldFactions.institution_control(world)
	var gov_id := WorldFactions.government_id(world)
	var lines: Array[String] = []
	lines.append("《哈利·波特·魔法纪元·势力面板》")
	lines.append("【魔法部状态】政体：%s 部长：%s 法律执行：%.2f（%s） 傲罗：%.2f（%s） 威森加摩：%.2f（%s） 财政：%.2f 国际：%.2f（%s） 稳定度：%.2f 腐败度：%.2f 纯血影响：%.2f 麻瓜关系：%.2f" % [
		_label(world, "governments", gov_id),
		_institution_holder_label(world, ic, "law_enforcement"),
		_institution_value(ic, "law_enforcement"), _institution_holder_label(world, ic, "law_enforcement"),
		_institution_value(ic, "auror_office"), _institution_holder_label(world, ic, "auror_office"),
		_institution_value(ic, "wizengamot"), _institution_holder_label(world, ic, "wizengamot"),
		float(vars.get("economy_index", 0.0)),
		_institution_value(ic, "international"), _institution_holder_label(world, ic, "international"),
		float(vars.get("ministry_stability", 0.0)), float(vars.get("corruption", 0.0)),
		float(vars.get("pureblood_influence", 0.0)), float(vars.get("muggle_relations", 0.0))])
	lines.append("【霍格沃茨】学院：%s 校方控制：%.2f（%s） 学业：%s 学院杯：仅 NPC 系统（计划 05） 魁地奇：仅 NPC 系统（计划 05） 禁林状况：%s 秘密：未调查 师生关系：%d人" % [
		_label(world, "houses", world.player.house_id),
		_institution_value(ic, "hogwarts"), _institution_holder_label(world, ic, "hogwarts"),
		_top_skill(world.player, world),
		str(world.flags.get("forbidden_forest_status", "常态")),
		world.player.relations.size()])
	var family: Dictionary = world.player.flags.get("family", {})
	if family.is_empty():
		lines.append("【家族】姓氏：无家族（家族制度属计划 03c） 祖宅：无 财富：%s 成员：0 婚姻：未婚 盟友：0 敌人：0 声望：%d 家族秘密：无 继承人：未定 魔杖传承：无" % [
			world.player.money().formatted(), world.player.reputation])
	else:
		lines.append("【家族】姓氏：%s 祖宅：%s 财富：%s 成员：%d 婚姻：%s 盟友：%d 敌人：%d 声望：%d 家族秘密：%s 继承人：%s 魔杖传承：%s" % [
			str(family.get("surname", "无家族")), str(family.get("seat", "无")),
			world.player.money().formatted(), int(family.get("members", 0)),
			str(family.get("marriage", "未婚")), int(family.get("allies", 0)), int(family.get("enemies", 0)),
			world.player.reputation, str(family.get("secret", "未知")),
			str(family.get("heir", "未定")), str(family.get("wand_legacy", "无"))])
	lines.append(_known_factions_line(world))
	return "\n".join(lines)

static func _institution_value(ic: Dictionary, institution_id: String) -> float:
	return float((ic[institution_id] as Dictionary).get("value", 0.0))

# 信息保护（第四十三/五十七章）：控制权值（世界事实）照常显示，
# 但**未揭示**的 holder 一律显示为「未知势力」——`institution_control()` 不知道揭示状态，
# 而未公开的派系（如食死徒对执法司/威森加摩、凤凰社）演化后完全可能成为某机构的 holder。
static func _institution_holder_label(world: WorldState, ic: Dictionary, institution_id: String) -> String:
	var holder := str((ic[institution_id] as Dictionary).get("holder", ""))
	if holder.is_empty():
		return "无人"
	if not WorldFactions.visible_faction_ids(world).has(holder):
		return "未知势力"
	return _label(world, "factions", holder)

# 【已知势力】：只列 revealed 派系，按实力降序；标出玩家所属与立场。
static func _known_factions_line(world: WorldState) -> String:
	var visible := WorldFactions.visible_faction_ids(world)
	if visible.is_empty():
		return "【已知势力】暂无已知势力（魔法世界对你是沉默的）"
	var rows: Array = []
	for fid in visible:
		var id := str(fid)
		rows.append({"id": id, "label": _label(world, "factions", id),
			"power": WorldFactions.power_of(world, id), "standing": world.player.standing_of(id),
			"member": world.player.faction_id == id})
	rows.sort_custom(func(x, y): return float(x["power"]) > float(y["power"]))
	var parts: Array[String] = []
	for row in rows:
		parts.append("%s：%.2f 立场 %+d%s" % [str(row["label"]), float(row["power"]),
			int(row["standing"]), "[所属]" if bool(row["member"]) else ""])
	return "【已知势力】" + " ".join(parts)

static func status_line(world: WorldState) -> String:
	return "%s ｜ %s ｜ %s ｜ %s" % [
		world.clock.formatted(),
		_label(world, "locations", world.player.location_id),
		world.player.name_text,
		MagicLevel.label_of(world.player.magic_tier),
	]

static func events_block(events: Array) -> String:
	if events.is_empty():
		return "本月没有特别的消息。"
	var lines: Array[String] = []
	for e in events:
		lines.append("· [%s] %s" % [str(e.get("category", "")), str(e.get("text", ""))])
	return "\n".join(lines)
