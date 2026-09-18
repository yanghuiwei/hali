class_name ScriptedGameMaster
extends GameMaster

const TRAIN_KEYWORDS: Array[String] = ["练习", "学习", "训练", "钻研", "研究", "复习", "上课"]
const WORK_KEYWORDS: Array[String] = ["打工", "赚钱", "上班", "经商", "接活", "做生意"]
const SOCIAL_KEYWORDS: Array[String] = ["打听", "询问", "聊天", "结交", "社交", "谈"]
const REST_KEYWORDS: Array[String] = ["休息", "睡觉", "吃饭", "喝", "闲逛", "发呆", "回家"]
const CAST_KEYWORDS: Array[String] = ["念", "施展", "使用咒语", "施法", "用魔杖"]

const SKILL_BY_KEYWORD: Dictionary = {
	"魔药": "potions", "草药": "herbology", "魔咒": "charms", "变形": "transfiguration",
	"黑魔法防御": "dada", "防御": "dada", "历史": "history_of_magic", "天文": "astronomy",
	"占卜": "divination", "魔文": "ancient_runes", "神奇生物": "care_of_magical_creatures",
	"魁地奇": "quidditch", "治疗": "healing", "社交": "social", "口才": "social",
}

var rng: RngService = null

func _init(rng_: RngService = null) -> void:
	rng = rng_ if rng_ != null else RngService.new(0)

func _contains_any(text: String, keywords: Array) -> bool:
	for k in keywords:
		if text.contains(str(k)):
			return true
	return false

func _detect_skill(text: String) -> String:
	# 第六十三章：主修科目来自玩家长期投入
	for keyword in SKILL_BY_KEYWORD.keys():
		if text.contains(str(keyword)):
			return str(SKILL_BY_KEYWORD[keyword])
	return "charms"

func _detect_spell(world: WorldState, text: String) -> String:
	for spell_id in world.registry.ids("spells"):
		var label := str(world.registry.entry("spells", spell_id).get("label", ""))
		if not label.is_empty() and text.contains(label):
			return str(spell_id)
	return ""

func act(world: WorldState, action_text: String) -> GmResult:
	var r := GmResult.new()
	var text := action_text.strip_edges()

	if text.is_empty():
		r.narration = "你没有做任何事。世界继续向前。"
		r.tags.append("idle")
		return r

	# 施法意图优先，避免「练习魔咒」被误判
	var spell_id := _detect_spell(world, text)
	if not spell_id.is_empty() and _contains_any(text, CAST_KEYWORDS):
		r.tags.append("cast")
		# 这里直接调用规则层，因为它必须产出旁白；守卫与代价由 cast() 内部结算。
		# 若由 StateOps 的 cast_spell 操作重放，会掷两次骰并重复结算守卫。
		var outcome := SpellResolver.cast(world, spell_id, {}, rng)
		r.narration = outcome.narration
		if not outcome.blocked and outcome.success:
			# 成功一次即算入门；重复施法不再重复记录（PlayerState.learn_spell 幂等）
			r.deltas.append({"op": "learn_spell", "spell_id": spell_id})
		return r

	if _contains_any(text, TRAIN_KEYWORDS):
		var skill_id := _detect_skill(text)
		var amount := Progression.gain(world, skill_id, 4)
		r.tags.append("train")
		r.deltas.append({"op": "gain_skill", "skill_id": skill_id, "amount": amount})
		var skill_label := str(world.registry.entry("skills", skill_id).get("label", skill_id))
		if amount >= 4:
			r.narration = "你花了整整一个月钻研%s，进步明显。" % skill_label
		elif amount > 0:
			r.narration = "你继续练%s，但收获不如从前（重复练习收益下降）。" % skill_label
		else:
			r.narration = "你在同一个地方反复练%s，几乎没有任何进步。你需要新的环境或新的问题。" % skill_label
		return r

	if _contains_any(text, WORK_KEYWORDS):
		var income := 30 + int(world.player.skill("social")) * 2 + int(rng.stream_int("work", 0, 20))
		r.tags.append("work")
		r.deltas.append({"op": "add_money", "knuts": income})
		r.narration = "你忙了一个月，赚到 %s。" % Money.from_knuts(income).formatted()
		return r

	if _contains_any(text, SOCIAL_KEYWORDS):
		var roll := rng.stream_float("social")
		r.tags.append("social")
		if roll < 0.5:
			r.deltas.append({"op": "know_fact", "fact_id": "rumor_%d" % world.clock.turn, "source": "破釜酒吧传闻"})
			r.narration = "你在酒吧里听人说了一些事。真假难辨，但至少有了线索。"
		else:
			r.narration = "你试着搭话，对方只是敷衍了几句。信息不会免费送上门。"
		return r

	if _contains_any(text, REST_KEYWORDS):
		r.tags.append("rest")
		r.narration = "你过了一个平常的月份：吃饭、睡觉、读《预言家日报》。"
		return r

	r.tags.append("idle")
	r.narration = "你尝试做了些别的事。世界未必回应，但它仍在继续。"
	return r
