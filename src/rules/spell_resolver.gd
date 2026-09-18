class_name SpellResolver
extends RefCounted

# 第五十五条 / 第二十五章守卫说明（同时是唯一合法守卫集合）
const GUARDS: Dictionary = {
	"no_rare_resource_duplication": "禁止复制咒无限复制稀有资源",
	"no_resurrection": "禁止治疗咒无限复活",
	"no_time_rewind": "禁止时间转换器无限回溯",
	"no_unlimited_energy": "禁止低阶咒语无限叠加",
	"unforgivable": "不可饶恕咒：触犯法律",
	"requires_registration": "需要登记（阿尼马格斯）",
	"requires_ministry_approval": "需要魔法部批准",
	"forbidden_lifetime": "终身禁忌",
	"restricted_mind_magic": "受限心智魔法：滥用即违法",
}

# 稀有度采用 fail-closed 白名单：只有显式认定的普通稀有度才允许复制，
# 大小写/空白先归一；未知值（含繁体、拼写变体、任意字符串）一律按稀有处理，避免绕过守卫。
const COMMON_RARITIES: Array[String] = ["common", "普通", "常见"]
const ENERGY_LOOP_LIMIT := 3
const TIME_REWIND_LIMIT := 1

class Outcome:
	var ok: bool = false
	var blocked: bool = false
	var blocked_reason: String = ""
	var failure_rate: float = 1.0
	var roll: float = 1.0
	var success: bool = false
	var side_effect: String = ""
	var narration: String = ""
	var guards: PackedStringArray = PackedStringArray()
	var legal_risk: bool = false

static func modifiers_from(conditions: Dictionary) -> Dictionary:
	var out := {}
	for key in MagicLevel.MODIFIER_KEYS:
		out[key] = clampf(float(conditions.get(key, 0.0)), 0.0, 1.0)
	return out

static func _blocked_outcome(reason: String, guards: PackedStringArray) -> Outcome:
	var o := Outcome.new()
	o.ok = false
	o.blocked = true
	o.blocked_reason = reason
	o.guards = guards
	o.narration = "（%s）" % reason
	return o

static func cast(world: WorldState, spell_id: String, conditions: Dictionary, rng: RngService) -> Outcome:
	var registry := world.registry
	var spell := registry.entry("spells", spell_id)
	var guard_ids := PackedStringArray()
	for guard in (spell.get("guards", []) as Array):
		guard_ids.append(str(guard))
	if spell.is_empty():
		return _blocked_outcome("未知魔咒：%s" % spell_id, guard_ids)

	var player := world.player
	var min_tier := MagicLevel.index_of_label(str(spell.get("min_tier", "")))
	if min_tier < 0:
		min_tier = MagicLevel.Tier.MYTH
	if player.magic_tier < min_tier:
		return _blocked_outcome("魔法等级不足：%s 需要 %s，当前为 %s" % [
			str(spell.get("label", spell_id)),
			MagicLevel.label_of(min_tier),
			MagicLevel.label_of(player.magic_tier),
		], guard_ids)

	var legal_risk := false
	var target_alive := bool(conditions.get("target_alive", true))
	var target_rarity := str(conditions.get("target_rarity", "common")).strip_edges().to_lower()
	for guard in guard_ids:
		match guard:
			"no_rare_resource_duplication":
				if not COMMON_RARITIES.has(target_rarity):
					return _blocked_outcome("复制咒无法复制稀有资源（%s）：世界资源必须有成本、有产出、有消耗" % target_rarity, guard_ids)
			"no_resurrection":
				if not target_alive:
					return _blocked_outcome("治疗咒无法复活死者：死亡真实且不可逆", guard_ids)
			"no_time_rewind":
				# 终身一次性：time_rewind_count 永不由 tick() 重置
				if int(world.flags.get("time_rewind_count", 0)) >= TIME_REWIND_LIMIT:
					return _blocked_outcome("时间转换器禁止无限回溯", guard_ids)
			"no_unlimited_energy":
				# per-turn：计数由 WorldState.tick() 每回合（月）重置
				if int(world.flags.get("energy_loop_count", 0)) >= ENERGY_LOOP_LIMIT:
					return _blocked_outcome("低阶咒语叠加已达上限，无法继续累积能量", guard_ids)
			"forbidden_lifetime":
				return _blocked_outcome("终身禁忌：%s" % str(spell.get("label", spell_id)), guard_ids)
			"requires_registration":
				if not player.flags.has("animagus_registered"):
					return _blocked_outcome("未在魔法部登记，不得成为阿尼马格斯", guard_ids)
			"requires_ministry_approval":
				if not world.flags.has("ministry_approval"):
					return _blocked_outcome("缺少魔法部批准", guard_ids)
			"unforgivable":
				legal_risk = true
			"restricted_mind_magic":
				legal_risk = true

	if bool(spell.get("forbidden", false)):
		legal_risk = true

	# 失败率：等级区间 + 环境因素 + 资质偏移 + 咒语难度
	var aptitude_delta := float(registry.entry("aptitudes", player.aptitude_id).get("failure_delta", 0.0))
	var rate := MagicLevel.effective_rate(player.magic_tier, modifiers_from(conditions), aptitude_delta + float(spell.get("difficulty", 0.0)))

	var o := Outcome.new()
	o.ok = true
	o.guards = guard_ids
	o.legal_risk = legal_risk
	o.failure_rate = rate
	o.roll = rng.stream_float("spell_roll")
	o.success = o.roll > rate

	var label := str(spell.get("label", spell_id))
	if o.success:
		o.narration = "%s成功。" % label
		# 需要代价的魔法对象在成功时也要显式结算（第十五章：没有免费的魔力）
		if guard_ids.has("no_unlimited_energy"):
			world.flags["energy_loop_count"] = int(world.flags.get("energy_loop_count", 0)) + 1
		if guard_ids.has("no_time_rewind"):
			world.flags["time_rewind_count"] = int(world.flags.get("time_rewind_count", 0)) + 1
		if legal_risk:
			world.flags["illegal_cast_count"] = int(world.flags.get("illegal_cast_count", 0)) + 1
			o.narration += "（法律与道德风险已记录）"
	else:
		var effects: Array = spell.get("side_effects", [])
		o.side_effect = str(rng.stream_pick("spell_side_effect", effects)) if not effects.is_empty() else "魔力失控"
		o.narration = "%s失败：%s。" % [label, o.side_effect]
		if o.side_effect == "魔力枯竭" or o.side_effect == "分体" or o.side_effect == "时间乱流":
			world.flags["last_serious_mishap_turn"] = world.clock.turn
	return o
