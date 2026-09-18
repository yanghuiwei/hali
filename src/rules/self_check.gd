class_name SelfCheck
extends RefCounted

const AUDIT_INTERVAL := 15

static func is_audit_turn(turn: int) -> bool:
	return turn > 0 and turn % AUDIT_INTERVAL == 0

static func snapshot(world: WorldState) -> String:
	var lines: Array[String] = []
	lines.append("【剧情快照】")
	lines.append("当前时间：%s（第 %d 回合）" % [world.clock.formatted(), world.clock.turn])
	lines.append("地点：%s（危险度：%s）" % [
		str(world.current_location().get("label", world.player.location_id)),
		str(world.current_location().get("danger_label", "未知"))])
	lines.append("玩家状态：%s，%d岁，%s，%s，财富 %s，魔法等级 %s" % [
		world.player.name_text, world.player.age_years(),
		str(world.registry.entry("bloodlines", world.player.bloodline_id).get("label", world.player.bloodline_id)),
		("存活" if world.player.alive else "已死亡"),
		world.player.money().formatted(),
		MagicLevel.label_of(world.player.magic_tier)])
	lines.append("关键NPC状态：")
	if world.npcs.is_empty():
		lines.append("  （尚未建立关键 NPC 关系网络）")
	else:
		var npc_ids := world.npcs.keys()
		npc_ids.sort()
		for npc_id in npc_ids:
			var npc: Dictionary = world.npcs[npc_id]
			lines.append("  - %s（%s）：%s" % [
				str(npc.get("name", npc_id)), str(npc.get("identity", "未知")), str(npc.get("status", "未知"))])
	lines.append("当前进行中事件：")
	if world.pending.is_empty():
		lines.append("  （无）")
	else:
		for item in world.pending:
			lines.append("  - %s（始于第 %d 回合）" % [str(item.get("text", "")), int(item.get("turn", 0))])
	lines.append("已发生重大事件：")
	if world.history.is_empty():
		lines.append("  （尚无）")
	else:
		for fact in world.history:
			lines.append("  - %d年：%s" % [int(fact.get("year", 0)), str(fact.get("text", ""))])
	lines.append("世界变量：")
	var keys := world.world_vars.keys()
	keys.sort()
	for key in keys:
		lines.append("  - %s：%.2f" % [str(key), float(world.world_vars[key])])
	return "\n".join(lines)

static func ooc_report(world: WorldState) -> String:
	var lines: Array[String] = []
	lines.append("【人设OOC自检报告】")

	# 1) 人物行为偏离设定
	var ooc_npcs: Array[String] = []
	for npc_id in world.npcs.keys():
		var npc: Dictionary = world.npcs[npc_id]
		if bool(npc.get("ooc_violation", false)):
			ooc_npcs.append(str(npc.get("name", npc_id)))
	lines.append("人物行为偏离设定：%s%s" % [
		("异常" if not ooc_npcs.is_empty() else "通过"),
		("，涉及：%s" % "、".join(ooc_npcs) if not ooc_npcs.is_empty() else "")])

	# 2) 魔法规则被破坏
	var illegal := int(world.flags.get("illegal_cast_count", 0))
	lines.append("魔法规则被破坏：%s%s" % [
		("异常" if illegal > 0 else "通过"),
		("，本世界已记录 %d 次违禁施法" % illegal if illegal > 0 else "")])

	# 3) 历史时间线错误
	var timeline_ok := true
	var timeline_detail := ""
	if world.era_start_year > 0 and world.clock.year < world.era_start_year:
		timeline_ok = false
		timeline_detail = "，当前年份 %d 早于时代锚点 %d" % [world.clock.year, world.era_start_year]
	var era_entry := world.era()
	for fact in world.history:
		if str(fact.get("kind", "")) == "canon" and int(fact.get("year", 0)) > world.clock.year:
			timeline_ok = false
			timeline_detail = "，原著锚点事件 %s 早于其应在年份被记录" % str(fact.get("text", ""))
	lines.append("历史时间线错误：%s%s" % [
		("通过" if timeline_ok else "异常"), timeline_detail])

	# 4) 玩家信息被提前泄露
	var leaked: Array[String] = []
	for fact_id in world.player.known_facts.keys():
		var source := str(world.player.known_facts[fact_id])
		if source == "system" or source.is_empty():
			leaked.append(str(fact_id))
	lines.append("玩家信息被提前泄露：%s%s" % [
		("异常" if not leaked.is_empty() else "通过"),
		("，来源异常的事实：%s" % "、".join(leaked) if not leaked.is_empty() else "")])

	if era_entry.is_empty():
		lines.append("备注：era_id=%s 未在内容表中找到" % world.era_id)
	return "\n".join(lines)

static func report(world: WorldState) -> String:
	return snapshot(world) + "\n" + ooc_report(world)
