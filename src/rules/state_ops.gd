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
				var knuts = raw.get("knuts", 0)
				if typeof(knuts) != TYPE_INT and typeof(knuts) != TYPE_FLOAT:
					errors.append("add_money 的 knuts 必须是数字: %s" % str(knuts))
				else:
					world.player.set_money(world.player.money().add(Money.from_knuts(int(knuts))))
			"gain_skill":
				var skill_id := str(raw.get("skill_id", ""))
				if not world.registry.has("skills", skill_id):
					errors.append("未知技能: %s" % skill_id)
				else:
					world.player.add_skill(skill_id, int(raw.get("amount", 0)))
			"train_skill":
				var train_skill_id := str(raw.get("skill_id", ""))
				if not world.registry.has("skills", train_skill_id):
					errors.append("未知技能: %s" % train_skill_id)
				else:
					var train_gain := Progression.gain(world, train_skill_id, int(raw.get("base_gain", 4)))
					world.player.add_skill(train_skill_id, train_gain)
			"learn_spell":
				var spell_id := str(raw.get("spell_id", ""))
				if not world.registry.has("spells", spell_id):
					errors.append("未知魔咒: %s" % spell_id)
				else:
					world.player.learn_spell(spell_id)
			"set_flag":
				var flag_key := str(raw.get("key", ""))
				if flag_key.is_empty():
					errors.append("set_flag 缺少 key")
				else:
					world.flags[flag_key] = raw.get("value", true)
			"set_player_flag":
				var pflag_key := str(raw.get("key", ""))
				if pflag_key.is_empty():
					errors.append("set_player_flag 缺少 key")
				else:
					world.player.flags[pflag_key] = raw.get("value", true)
			"know_fact":
				var fact_id := str(raw.get("fact_id", ""))
				var source := str(raw.get("source", ""))
				if fact_id.is_empty():
					errors.append("know_fact 缺少 fact_id")
				elif source.is_empty():
					errors.append("know_fact 缺少来源: %s" % fact_id)
				elif source == "system":
					errors.append("禁止系统直接告知真相（第四十三章/第五十七章）")
				else:
					world.player.known_facts[fact_id] = source
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
				if npc_id.is_empty():
					errors.append("relation_delta 缺少 npc_id")
				else:
					var rel: Dictionary = world.player.relations.get(npc_id, {"trust": 0, "interest": 0, "hostility": 0})
					rel["trust"] = int(rel.get("trust", 0)) + int(raw.get("trust", 0))
					rel["hostility"] = int(rel.get("hostility", 0)) + int(raw.get("hostility", 0))
					rel["interest"] = int(rel.get("interest", 0)) + int(raw.get("interest", 0))
					world.player.relations[npc_id] = rel
			"join_faction":
				var join_id := str(raw.get("faction_id", ""))
				if not world.registry.has("factions", join_id):
					errors.append("未知派系: %s" % join_id)
				elif not WorldFactions.visible_faction_ids(world).has(join_id):
					errors.append("该派系尚未揭示，无法加入: %s" % join_id)
				else:
					world.player.faction_id = join_id
					if str(world.registry.entry("factions", join_id).get("legal_status", "legal")) == "outlaw":
						world.flags["illegal_affiliation"] = join_id
						errors.append("警告：加入非法组织（%s），法律后果留待后续结算" % join_id)
			"leave_faction":
				# Task 9 审查 M3 的第二道门（LLM 路径也走这里）：携带 faction_id 时只在真的是成员时才清空。
				var leave_id := str(raw.get("faction_id", ""))
				if not leave_id.is_empty() and leave_id != world.player.faction_id:
					errors.append("你不是该派系成员: %s" % leave_id)
				else:
					world.player.faction_id = ""
			"faction_standing_delta":
				var standing_id := str(raw.get("faction_id", ""))
				if not world.registry.has("factions", standing_id):
					errors.append("未知派系: %s" % standing_id)
				# Task 9 审查 M8：与 join_faction 同门——未揭示的派系玩家根本不知道其存在，
				# 不该被"支持/反对"（第四十三/五十七章）。normal 路径的识别层已限定 visible，
				# 但 LLM/OpGuard 路径只有提示词层保护，故在这里补第二道门。
				elif not WorldFactions.visible_faction_ids(world).has(standing_id):
					errors.append("该派系尚未揭示，无法表态: %s" % standing_id)
				else:
					var raw_delta = raw.get("delta", 0)
					var delta := int(raw_delta) if (typeof(raw_delta) == TYPE_INT or typeof(raw_delta) == TYPE_FLOAT) else 0
					world.player.add_standing(standing_id, delta)
					var fstate := WorldFactions.ensure_state(world, standing_id)
					if not fstate.is_empty():
						fstate["stance_to_player"] = clampi(int(fstate.get("stance_to_player", 0)) + delta / 2, -100, 100)
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

# cast_spell 需要一个随机源；由世界种子、回合与调用序号共同推导，保证可复现且同回合内不重复。
# 计数器入 world.flags（持久化），OpGuard 禁止 LLM 写以 "_" 开头的 flag key。
static func world_gm_rng(world: WorldState) -> RngService:
	var counter := int(world.flags.get("_gm_rng_counter", 0))
	world.flags["_gm_rng_counter"] = counter + 1
	return RngService.new(world.game_seed + world.clock.turn * 15485863 + counter * 2654435761)
