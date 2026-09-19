class_name OpGuard
extends RefCounted

const MAX_OPS := 20
const MAX_MONEY_GAIN := 1000
const MAX_RELATION_DELTA := 20
const TRAIN_BASE_GAIN := 4

class Result:
	var ops: Array = []
	var warnings: PackedStringArray = PackedStringArray()

static func sanitize(world: WorldState, raw_ops: Array) -> Array:
	return sanitize_detailed(world, raw_ops).ops

static func sanitize_detailed(world: WorldState, raw_ops: Array) -> Result:
	var out := Result.new()
	var money_gain := 0
	for raw in raw_ops:
		if out.ops.size() >= MAX_OPS:
			out.warnings.append("ops 数量超过上限 %d，已截断" % MAX_OPS)
			break
		if typeof(raw) != TYPE_DICTIONARY:
			out.warnings.append("忽略非字典 op")
			continue
		var op := str(raw.get("op", ""))
		match op:
			"gain_skill":
				var skill_id := str(raw.get("skill_id", ""))
				if world.registry.has("skills", skill_id):
					out.ops.append({"op": "train_skill", "skill_id": skill_id, "base_gain": TRAIN_BASE_GAIN})
				else:
					out.warnings.append("忽略未知技能: %s" % skill_id)
			"add_money":
				var knuts := int(raw.get("knuts", 0))
				if knuts > 0:
					var room := MAX_MONEY_GAIN - money_gain
					if room <= 0:
						out.warnings.append("本回合金钱收益已达上限")
						continue
					if knuts > room:
						knuts = room
						out.warnings.append("金钱收益已钳到上限 %d" % MAX_MONEY_GAIN)
					money_gain += knuts
				out.ops.append({"op": "add_money", "knuts": knuts})
			"set_magic_tier":
				var tier := clampi(int(raw.get("tier", world.player.magic_tier)), world.player.magic_tier - 1, world.player.magic_tier + 1)
				tier = clampi(tier, 0, MagicLevel.LABELS.size() - 1)
				out.ops.append({"op": "set_magic_tier", "tier": tier})
			"relation_delta":
				var npc_id := str(raw.get("npc_id", ""))
				if npc_id.is_empty():
					out.warnings.append("忽略缺 npc_id 的 relation_delta")
					continue
				out.ops.append({
					"op": "relation_delta", "npc_id": npc_id,
					"trust": clampi(int(raw.get("trust", 0)), -MAX_RELATION_DELTA, MAX_RELATION_DELTA),
					"interest": clampi(int(raw.get("interest", 0)), -MAX_RELATION_DELTA, MAX_RELATION_DELTA),
					"hostility": clampi(int(raw.get("hostility", 0)), -MAX_RELATION_DELTA, MAX_RELATION_DELTA),
				})
			"set_flag", "set_player_flag":
				var key := str(raw.get("key", ""))
				if key.is_empty() or key.begins_with("_"):
					out.warnings.append("拒绝保留/空 flag key: %s" % key)
					continue
				out.ops.append({"op": op, "key": key, "value": raw.get("value", true)})
			"know_fact":
				var fact_id := str(raw.get("fact_id", ""))
				var source := str(raw.get("source", ""))
				if fact_id.is_empty() or source.is_empty() or source == "system":
					out.warnings.append("拒绝非法 know_fact")
					continue
				out.ops.append({"op": "know_fact", "fact_id": fact_id, "source": source})
			"cast_spell", "learn_spell", "set_location", "set_job":
				out.ops.append(raw)
			_:
				out.warnings.append("未知 op 交给 StateOps 判定: %s" % op)
				out.ops.append(raw)
	return out
