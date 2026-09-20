class_name PlayerState
extends RefCounted

const SKILL_MAX := 100

var name_text: String = ""
var gender: String = ""
var age_months: int = 0
var bloodline_id: String = ""
var birth_identity_id: String = ""
var birthplace: String = ""
var family_status: String = ""
var aptitude_id: String = ""
var aptitude_special: String = ""
var house_id: String = "none"
var political_leaning_id: String = ""
var personality: Array = []
var life_goal: String = ""
var sim_style_id: String = "mixed"
var wand: Dictionary = {}
var magic_tier: int = MagicLevel.Tier.PRE_SCHOOL
var money_knuts: int = 0
var reputation: int = 0
var skills: Dictionary = {}
var magic: Dictionary = {}
var relations: Dictionary = {}
var faction_id: String = ""
var standing: Dictionary = {}      # 计划 03a：faction_id -> 玩家立场/声望 -100..100
var current_goal: String = ""
var location_id: String = ""
var job: String = ""
var alive: bool = true
var flags: Dictionary = {}
var known_facts: Dictionary = {}
var next_id: int = 1

static func new_default() -> PlayerState:
	var p := PlayerState.new()
	p.magic = {
		"capacity": 10, "control": 10, "affinity": 10,
		"subjects": [], "known_spells": [], "experimenting": [],
		"potions": 0, "occlumency": 0, "apparition": 0, "patronus": "",
	}
	return p

func age_years() -> int:
	return age_months / 12

func money() -> Money:
	return Money.from_knuts(money_knuts)

func set_money(m: Money) -> void:
	money_knuts = m.total_knuts()

func skill(skill_id: String) -> int:
	return int(skills.get(skill_id, 0))

func add_skill(skill_id: String, amount: int) -> void:
	skills[skill_id] = clampi(skill(skill_id) + amount, 0, SKILL_MAX)

const STANDING_MIN := -100
const STANDING_MAX := 100

func knows_spell(spell_id: String) -> bool:
	return (magic.get("known_spells", []) as Array).has(spell_id)

func learn_spell(spell_id: String) -> void:
	var known: Array = magic.get("known_spells", [])
	if not known.has(spell_id):
		known.append(spell_id)
	magic["known_spells"] = known

func standing_of(faction_id: String) -> int:
	return clampi(int(standing.get(faction_id, 0)), STANDING_MIN, STANDING_MAX)

func add_standing(faction_id: String, delta: int) -> int:
	var value := clampi(standing_of(faction_id) + delta, STANDING_MIN, STANDING_MAX)
	standing[faction_id] = value
	return value

func to_dict() -> Dictionary:
	return JsonUtil.normalize({
		"name_text": name_text, "gender": gender, "age_months": age_months,
		"bloodline_id": bloodline_id, "birth_identity_id": birth_identity_id,
		"birthplace": birthplace, "family_status": family_status,
		"aptitude_id": aptitude_id, "aptitude_special": aptitude_special,
		"house_id": house_id, "political_leaning_id": political_leaning_id,
		"personality": personality, "life_goal": life_goal, "sim_style_id": sim_style_id,
		"wand": wand, "magic_tier": magic_tier, "money_knuts": money_knuts,
		"reputation": reputation, "skills": skills, "magic": magic,
		"relations": relations, "faction_id": faction_id, "standing": standing, "current_goal": current_goal,
		"location_id": location_id, "job": job, "alive": alive,
		"flags": flags, "known_facts": known_facts, "next_id": next_id,
	})

static func from_dict(d: Dictionary) -> PlayerState:
	var p := PlayerState.new_default()
	p.name_text = str(d.get("name_text", ""))
	p.gender = str(d.get("gender", ""))
	p.age_months = int(d.get("age_months", 0))
	p.bloodline_id = str(d.get("bloodline_id", ""))
	p.birth_identity_id = str(d.get("birth_identity_id", ""))
	p.birthplace = str(d.get("birthplace", ""))
	p.family_status = str(d.get("family_status", ""))
	p.aptitude_id = str(d.get("aptitude_id", ""))
	p.aptitude_special = str(d.get("aptitude_special", ""))
	p.house_id = str(d.get("house_id", "none"))
	p.political_leaning_id = str(d.get("political_leaning_id", ""))
	p.personality = JsonUtil.normalize(d.get("personality", []))
	p.life_goal = str(d.get("life_goal", ""))
	p.sim_style_id = str(d.get("sim_style_id", "mixed"))
	p.wand = JsonUtil.normalize(d.get("wand", {}))
	p.magic_tier = int(d.get("magic_tier", MagicLevel.Tier.PRE_SCHOOL))
	p.money_knuts = int(d.get("money_knuts", 0))
	p.reputation = int(d.get("reputation", 0))
	p.skills = JsonUtil.normalize(d.get("skills", {}))
	p.magic = JsonUtil.normalize(d.get("magic", p.magic))
	p.relations = JsonUtil.normalize(d.get("relations", {}))
	p.faction_id = str(d.get("faction_id", ""))
	p.standing = JsonUtil.normalize(d.get("standing", {}))
	p.current_goal = str(d.get("current_goal", ""))
	p.location_id = str(d.get("location_id", ""))
	p.job = str(d.get("job", ""))
	p.alive = bool(d.get("alive", true))
	p.flags = JsonUtil.normalize(d.get("flags", {}))
	p.known_facts = JsonUtil.normalize(d.get("known_facts", {}))
	p.next_id = int(d.get("next_id", 1))
	return p
