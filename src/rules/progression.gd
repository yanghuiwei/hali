class_name Progression
extends RefCounted

const WINDOW_TURNS := 12
const MIN_GAIN := 0

# 第七十章：禁止站在禁林砍 1000 只八眼巨蛛升级。
# 同一（技能, 地点）在 12 回合内的重复次数越多，收益越低；换环境则重新计算。
static func gain(world: WorldState, skill_id: String, base_gain: int) -> int:
	var key := "%s@%s" % [skill_id, world.player.location_id]
	var recent: Dictionary = world.flags.get("recent_training", {})
	var history: Array = recent.get(key, [])
	var kept: Array = []
	for entry in history:
		if world.clock.turn - int(entry) <= WINDOW_TURNS:
			kept.append(int(entry))
	var repeats := kept.size()
	kept.append(world.clock.turn)
	recent[key] = kept
	world.flags["recent_training"] = recent

	var factor := 1.0 / float(1 + repeats)
	# 向下取整（不是四舍五入）：重复 4 次之后收益归零
	var gained: int = maxi(MIN_GAIN, int(float(base_gain) * factor))
	# 注意：这里只计算与记账，不修改玩家技能。
	# 技能写回由 StateOps 的 gain_skill 操作统一完成，避免同一份收益被应用两次。
	return gained
