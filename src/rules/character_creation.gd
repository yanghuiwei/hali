class_name CharacterCreation
extends RefCounted

const MIN_AGE_YEARS := 11
const MAX_AGE_YEARS := 80
const HOUSE_TENDENCY := {
	"slytherin": ["野心", "精明", "血统", "意志", "算计", "权力"],
	"gryffindor": ["勇气", "胆识", "冲动", "正义", "鲁莽"],
	"ravenclaw": ["好奇", "智慧", "知识", "钻研", "冷静"],
	"hufflepuff": ["忠诚", "勤勉", "公平", "坚韧", "善良"],
}
const BLOODLINE_HOUSE_BIAS := {
	"sacred_twenty_eight": "slytherin",
	"pureblood_cadet": "slytherin",
	"muggle_born": "gryffindor",
	"werewolf": "gryffindor",
	"part_veela": "ravenclaw",
}

class Result:
	var player: PlayerState = null
	var errors: PackedStringArray = PackedStringArray()

static func validate_choices(choices: Dictionary, registry: Registry) -> PackedStringArray:
	var errors := PackedStringArray()
	var era_id := str(choices.get("era_id", ""))
	if not registry.has("eras", era_id):
		errors.append("era_id 非法: %s" % era_id)
	var bloodline_id := str(choices.get("bloodline_id", ""))
	if not registry.has("bloodlines", bloodline_id):
		errors.append("bloodline_id 非法: %s" % bloodline_id)
	if not registry.has("birth_identities", str(choices.get("birth_identity_id", ""))):
		errors.append("birth_identity_id 非法: %s" % str(choices.get("birth_identity_id", "")))
	if not registry.has("houses", str(choices.get("house_id", "system"))):
		errors.append("house_id 非法: %s" % str(choices.get("house_id", "")))
	if not registry.has("sim_styles", str(choices.get("sim_style_id", "mixed"))):
		errors.append("sim_style_id 非法: %s" % str(choices.get("sim_style_id", "")))
	if not registry.has("political_leanings", str(choices.get("political_leaning_id", "free_independent"))):
		errors.append("political_leaning_id 非法: %s" % str(choices.get("political_leaning_id", "")))

	if str(choices.get("name_text", "")).strip_edges().is_empty():
		errors.append("name_text 不得为空")

	var age_years := int(choices.get("age_years", 0))
	if age_years < MIN_AGE_YEARS or age_years > MAX_AGE_YEARS:
		errors.append("age_years 必须在 %d–%d 之间，实际 %d" % [MIN_AGE_YEARS, MAX_AGE_YEARS, age_years])

	var personality: Array = choices.get("personality", [])
	if personality.size() < 3:
		errors.append("personality 需要 3 个性格关键词，实际 %d 个" % personality.size())
	if str(choices.get("life_goal", "")).strip_edges().is_empty():
		errors.append("life_goal 不得为空")

	# 血统与资质必须自洽（哑炮血统 = 无魔法；有魔法血统 ≠ 哑炮资质）
	var aptitude_id := str(choices.get("aptitude_id", "normal"))
	if not registry.has("aptitudes", aptitude_id):
		errors.append("aptitude_id 非法: %s" % aptitude_id)
	var bloodline: Dictionary = registry.entry("bloodlines", bloodline_id)
	var bloodline_has_magic := bool(bloodline.get("magic_aptitude", true))
	if bloodline_id == "squib" and aptitude_id != "squib":
		errors.append("哑炮血统无法拥有魔法资质（当前 aptitude_id=%s）；请把 aptitude_id 设为 squib" % aptitude_id)
	if bloodline_has_magic and aptitude_id == "squib":
		errors.append("血统 %s 拥有魔法天赋，不能选择哑炮资质" % bloodline_id)

	if aptitude_id == "special":
		var allowed := []
		for option in (registry.entry("aptitudes", "special").get("special_options", []) as Array):
			allowed.append(str(option))
		var chosen := str(choices.get("aptitude_special", ""))
		if not allowed.has(chosen):
			errors.append("aptitude_special 非法: %s，允许值 %s" % [chosen, ", ".join(allowed)])

	var wand_choice: Dictionary = choices.get("wand", {})
	if not wand_choice.is_empty():
		if not registry.has("wand_woods", str(wand_choice.get("wood", ""))):
			errors.append("魔杖木材非法: %s" % str(wand_choice.get("wood", "")))
		if not registry.has("wand_cores", str(wand_choice.get("core", ""))):
			errors.append("魔杖杖芯非法: %s" % str(wand_choice.get("core", "")))
		if not registry.has("wand_flexibilities", str(wand_choice.get("flexibility", ""))):
			errors.append("魔杖弹性非法: %s" % str(wand_choice.get("flexibility", "")))
	return errors

static func default_skills_for(choices: Dictionary, registry: Registry) -> Dictionary:
	var skills := {}
	var pairs := [["bloodlines", "bloodline_id"], ["birth_identities", "birth_identity_id"]]
	for pair in pairs:
		var entry: Dictionary = registry.entry(str(pair[0]), str(choices.get(str(pair[1]), "")))
		var bias: Dictionary = entry.get("skill_bias", {})
		for skill_id in bias.keys():
			skills[str(skill_id)] = int(skills.get(str(skill_id), 0)) + int(bias[skill_id])
	return skills

static func generate_wand(rng: RngService, registry: Registry) -> Dictionary:
	var wood: String = str(rng.stream_pick("wand_wood", registry.ids("wand_woods").duplicate()))
	var wood_entry: Dictionary = registry.entry("wand_woods", str(wood))
	var core_ids := registry.ids("wand_cores").duplicate()
	var core_id := str(rng.stream_pick("wand_core", core_ids))
	var core_entry: Dictionary = registry.entry("wand_cores", core_id)
	var flex_ids := registry.ids("wand_flexibilities").duplicate()
	var flex_id := str(rng.stream_pick("wand_flex", flex_ids))
	var length_ids := registry.ids("wand_lengths").duplicate()
	var length_id := str(rng.stream_pick("wand_length", length_ids))
	var length_entry: Dictionary = registry.entry("wand_lengths", length_id)
	var inches := float(length_entry.get("inches", 11.0))
	return {
		"wood": str(wood),
		"core": core_id,
		"length_inches": inches,
		"flexibility": flex_id,
		"label": "%s，%s，%.2f英寸，%s" % [
			str(wood_entry.get("label", wood)),
			str(core_entry.get("label", core_id)),
			inches,
			str(registry.entry("wand_flexibilities", flex_id).get("label", flex_id)),
		],
	}

static func assign_house(choices: Dictionary, rng: RngService, registry: Registry) -> String:
	var requested := str(choices.get("house_id", "system"))
	if requested != "system":
		return requested
	var bloodline_id := str(choices.get("bloodline_id", ""))
	var bloodline: Dictionary = registry.entry("bloodlines", bloodline_id)
	var age_years := int(choices.get("age_years", 11))
	if not bool(bloodline.get("magic_aptitude", true)) or age_years < 11:
		return "none"
	var scores := {"gryffindor": 1.0, "slytherin": 1.0, "ravenclaw": 1.0, "hufflepuff": 1.0}
	var bias := str(BLOODLINE_HOUSE_BIAS.get(bloodline_id, ""))
	if not bias.is_empty():
		scores[bias] = float(scores[bias]) + 1.0
	var personality: Array = choices.get("personality", [])
	for house in HOUSE_TENDENCY.keys():
		for keyword in HOUSE_TENDENCY[house]:
			for p in personality:
				if str(p).contains(str(keyword)) or str(keyword).contains(str(p)):
					scores[house] = float(scores[house]) + 1.5
	var best := ""
	var best_score := -1.0
	var tie_break: Array = []
	for house in scores.keys():
		var s := float(scores[house])
		if s > best_score:
			best_score = s
			best = house
			tie_break = [house]
		elif is_equal_approx(s, best_score):
			tie_break.append(house)
	if tie_break.size() > 1:
		best = str(rng.stream_pick("house_tiebreak", tie_break))
	return best

static func create(choices: Dictionary, registry: Registry, rng: RngService) -> Result:
	var out := Result.new()
	out.errors = validate_choices(choices, registry)
	if out.errors.size() > 0:
		return out

	var p := PlayerState.new_default()
	p.name_text = str(choices["name_text"]).strip_edges()
	p.gender = str(choices.get("gender", ""))
	p.age_months = int(choices["age_years"]) * 12
	p.bloodline_id = str(choices["bloodline_id"])
	p.birth_identity_id = str(choices["birth_identity_id"])
	p.birthplace = str(choices.get("birthplace", ""))
	p.family_status = str(choices.get("family_status", ""))
	p.house_id = assign_house(choices, rng, registry)
	p.political_leaning_id = str(choices["political_leaning_id"])
	p.personality = choices.get("personality", [])
	p.life_goal = str(choices["life_goal"])
	p.current_goal = p.life_goal
	p.sim_style_id = str(choices["sim_style_id"])
	p.location_id = str(choices.get("birthplace", "london_muggle"))

	var bloodline: Dictionary = registry.entry("bloodlines", p.bloodline_id)
	var identity: Dictionary = registry.entry("birth_identities", p.birth_identity_id)
	p.money_knuts = int(identity.get("start_knuts", 0))

	# 资质：random 在创建时掷定，且不得掷出哑炮（玩家没选哑炮血统）
	var aptitude_id := str(choices["aptitude_id"])
	if aptitude_id == "random":
		var pool: Array = []
		for candidate in registry.ids("aptitudes"):
			var cid := str(candidate)
			if cid == "random" or cid == "squib":
				continue
			pool.append(cid)
		aptitude_id = str(rng.stream_pick("aptitude", pool))
	p.aptitude_id = aptitude_id
	var aptitude: Dictionary = registry.entry("aptitudes", aptitude_id)

	# 哑炮：无魔法、无魔杖（第七十五章）
	var has_magic := bool(bloodline.get("magic_aptitude", true)) and aptitude_id != "squib"
	if not has_magic:
		p.magic_tier = MagicLevel.Tier.SQUIB
		p.wand = {}
		p.flags["no_magic"] = true
		p.job = ""
	else:
		p.magic_tier = MagicLevel.Tier.PRE_SCHOOL
		var wand_choice: Dictionary = choices.get("wand", {})
		p.wand = wand_choice if not wand_choice.is_empty() else generate_wand(rng, registry)
		p.magic["capacity"] = 10 + int(rng.stream_int("capacity", 0, 5))
		p.magic["control"] = 10 + int(rng.stream_int("control", 0, 5))
		p.magic["affinity"] = 10 + int(rng.stream_int("affinity", 0, 5))

	# 血统自带标记与特殊资质标记（第十章：偏见真实存在）
	for flag in (bloodline.get("default_flags", []) as Array):
		p.flags[str(flag)] = true
	p.aptitude_special = str(choices.get("aptitude_special", ""))
	for granted in (aptitude.get("grants", []) as Array):
		p.flags[str(granted)] = true
	if not p.aptitude_special.is_empty():
		p.flags[p.aptitude_special] = true
	p.flags["prejudice_level"] = float(bloodline.get("prejudice", 0.0))

	# 初始技能
	var bias := default_skills_for(choices, registry)
	for skill_id in bias.keys():
		p.add_skill(str(skill_id), int(bias[skill_id]))
	if has_magic and p.skill("charms") < 1:
		p.add_skill("charms", 1)

	out.player = p
	return out
