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
	lines.append("【财富】%s 【家庭】%s" % [p.money().formatted(), _label(world, "birth_identities", p.birth_identity_id)])
	lines.append("【社会地位】%s 【魔法能力】%s 【战斗能力】%s" % [_label(world, "political_leanings", p.political_leaning_id), _magic_level_label(p), _top_skill(p, world)])
	lines.append("【魔药/治疗】%s 【技能】%s" % [str(p.skill("potions")), _skills_line(p, world)])
	lines.append("【声望】%d 【重要关系】%d人 【所属势力】%s" % [p.reputation, p.relations.size(), (p.faction_id if not p.faction_id.is_empty() else "无")])
	lines.append("【当前目标】%s" % (p.current_goal if not p.current_goal.is_empty() else UNKNOWN))
	return "\n".join(lines)

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

# 第六十五章
static func power_panel(world: WorldState) -> String:
	var vars := world.world_vars
	var lines: Array[String] = []
	lines.append("《哈利·波特·魔法纪元·势力面板》")
	lines.append("【魔法部状态】部长：%s 法律执行：%.2f 傲罗：%.2f 威森加摩：%.2f 财政：%.2f 国际：%.2f 稳定度：%.2f 腐败度：%.2f 纯血影响：%.2f 麻瓜关系：%.2f" % [
		str(vars.get("minister", "待定")),
		float(vars.get("war_pressure", 0.0)), float(vars.get("ministry_stability", 0.0)),
		float(vars.get("corruption", 0.0)), float(vars.get("economy_index", 0.0)),
		float(vars.get("muggle_relations", 0.0)), float(vars.get("ministry_stability", 0.0)),
		float(vars.get("corruption", 0.0)), float(vars.get("pureblood_influence", 0.0)),
		float(vars.get("muggle_relations", 0.0))])
	lines.append("【霍格沃茨】学院：%s 院长：待定 学业：%s 学院杯：待定 魁地奇：待定 禁林状况：%s 秘密：未知 派系：未知 师生关系：%d人" % [
		_label(world, "houses", world.player.house_id),
		_top_skill(world.player, world),
		str(world.flags.get("forbidden_forest_status", "常态")),
		world.player.relations.size()])
	var family: Dictionary = world.player.flags.get("family", {})
	lines.append("【家族】姓氏：%s 祖宅：%s 财富：%s 成员：%d 婚姻：%s 盟友：%d 敌人：%d 声望：%d 家族秘密：%s 继承人：%s 魔杖传承：%s" % [
		str(family.get("surname", "无家族")), str(family.get("seat", "无")),
		world.player.money().formatted(), int(family.get("members", 0)),
		str(family.get("marriage", "未婚")), int(family.get("allies", 0)), int(family.get("enemies", 0)),
		world.player.reputation, str(family.get("secret", "未知")),
		str(family.get("heir", "未定")), str(family.get("wand_legacy", "无"))])
	return "\n".join(lines)

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
