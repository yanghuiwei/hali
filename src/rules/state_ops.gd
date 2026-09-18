class_name StateOps
extends RefCounted

# 所有玩家/世界状态变更都必须经过这里，便于审计与自检（第七十二章）。
static func apply(world: WorldState, deltas: Array) -> PackedStringArray:
	var errors := PackedStringArray()
	for raw in deltas:
		if typeof(raw) != TYPE_DICTIONARY:
			errors.append("非字典操作: %s" % str(raw))
			continue
		var op := str(raw.get("op", ""))
		match op:
			"add_money":
				var m := world.player.money().add(Money.from_knuts(int(raw.get("knuts", 0))))
				world.player.set_money(m)
			"gain_skill":
				var skill_id := str(raw.get("skill_id", ""))
				if not world.registry.has("skills", skill_id):
					errors.append("未知技能: %s" % skill_id)
				else:
					world.player.add_skill(skill_id, int(raw.get("amount", 0)))
			"learn_spell":
				var spell_id := str(raw.get("spell_id", ""))
				if not world.registry.has("spells", spell_id):
					errors.append("未知魔咒: %s" % spell_id)
				else:
					world.player.learn_spell(spell_id)
			"set_flag":
				world.flags[str(raw.get("key", ""))] = raw.get("value", true)
			"set_player_flag":
				world.player.flags[str(raw.get("key", ""))] = raw.get("value", true)
			"know_fact":
				var source := str(raw.get("source", ""))
				if source.is_empty():
					errors.append("know_fact 缺少来源: %s" % str(raw.get("fact_id", "")))
				elif source == "system":
					errors.append("禁止系统直接告知真相（第四十三章/第五十七章）")
				else:
					world.player.known_facts[str(raw.get("fact_id", ""))] = source
			"set_location":
				var location_id := str(raw.get("location_id", ""))
				if not world.registry.has("locations", location_id):
					errors.append("未知地点: %s" % location_id)
				else:
					world.player.location_id = location_id
			"set_job":
				world.player.job = str(raw.get("job", ""))
			"relation_delta":
				var npc_id := str(raw.get("npc_id", ""))
				var rel: Dictionary = world.player.relations.get(npc_id, {"trust": 0, "interest": 0, "hostility": 0})
				rel["trust"] = int(rel.get("trust", 0)) + int(raw.get("trust", 0))
				rel["hostility"] = int(rel.get("hostility", 0)) + int(raw.get("hostility", 0))
				rel["interest"] = int(rel.get("interest", 0)) + int(raw.get("interest", 0))
				world.player.relations[npc_id] = rel
			"set_magic_tier":
				world.player.magic_tier = clampi(int(raw.get("tier", world.player.magic_tier)), 0, MagicLevel.LABELS.size() - 1)
			"cast_spell":
				var outcome := SpellResolver.cast(world, str(raw.get("spell_id", "")), raw.get("conditions", {}), world_gm_rng(world))
				world.flags["last_cast_success"] = outcome.success
				world.flags["last_cast_narration"] = outcome.narration
				if outcome.blocked:
					errors.append(outcome.blocked_reason)
			_:
				errors.append("未知操作: %s" % op)
	return errors

# cast_spell 需要一个随机源；由世界种子与当前回合推导，保证可复现。
static func world_gm_rng(world: WorldState) -> RngService:
	return RngService.new(world.game_seed + world.clock.turn * 15485863)
