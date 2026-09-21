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
			"deposit_money":
				_apply_deposit(world, raw, errors)
			"withdraw_money":
				_apply_withdraw(world, raw, errors)
			"exchange_money":
				_apply_exchange(world, raw, errors)
			"trade_money":
				_apply_trade(world, raw, errors)
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

# ============================================================================
# 计划 03b Task 4：经济 op（spec §7.5）
#
# 三条共同铁律：
#   ① **不部分执行** —— 全部校验通过才落任何状态（先算、后写）；
#   ② 不抛异常，失败一律 `errors.append`（与既有 op 同款）；
#   ③ **不写 `world.factions` / `player.standing`** —— 走私只记不判，法律后果属 03c（spec §10 第 2/4 条）。
# ============================================================================

## 从载荷取整数金额；非数字返回 fallback（LLM 输出不可信）。
static func _payload_int(raw: Dictionary, key: String, fallback: int = 0) -> int:
	var v = raw.get(key, fallback)
	if typeof(v) == TYPE_INT or typeof(v) == TYPE_FLOAT:
		return int(v)
	return fallback


static func _apply_deposit(world: WorldState, raw: Dictionary, errors: PackedStringArray) -> void:
	var knuts := _payload_int(raw, "knuts", 0)
	if knuts <= 0:
		errors.append("deposit_money 金额必须为正: %d" % knuts)
		return
	if knuts > OpGuard.MAX_BANK_MOVE:
		errors.append("deposit_money 超过单笔上限 %d: %d" % [OpGuard.MAX_BANK_MOVE, knuts])
		return
	if world.player.money_knuts < knuts:
		errors.append("现金不足，无法存入 %d 纳特（现有 %d）" % [knuts, world.player.money_knuts])
		return
	# 校验全过 → 才写状态（不部分执行）
	world.player.money_knuts -= knuts
	world.economy["gringotts_balance"] = int(world.economy.get("gringotts_balance", 0)) + knuts


static func _apply_withdraw(world: WorldState, raw: Dictionary, errors: PackedStringArray) -> void:
	var knuts := _payload_int(raw, "knuts", 0)
	if knuts <= 0:
		errors.append("withdraw_money 金额必须为正: %d" % knuts)
		return
	if knuts > OpGuard.MAX_BANK_MOVE:
		errors.append("withdraw_money 超过单笔上限 %d: %d" % [OpGuard.MAX_BANK_MOVE, knuts])
		return
	var balance := int(world.economy.get("gringotts_balance", 0))
	if balance < knuts:
		errors.append("古灵阁余额不足，无法取出 %d 纳特（现有 %d）" % [knuts, balance])
		return
	world.economy["gringotts_balance"] = balance - knuts
	world.player.money_knuts += knuts


static func _apply_exchange(world: WorldState, raw: Dictionary, errors: PackedStringArray) -> void:
	var knuts := _payload_int(raw, "knuts", 0)
	var direction := str(raw.get("direction", ""))
	if knuts <= 0:
		errors.append("exchange_money 金额必须为正: %d" % knuts)
		return
	if knuts > OpGuard.MAX_BANK_MOVE:
		errors.append("exchange_money 超过单笔上限 %d: %d" % [OpGuard.MAX_BANK_MOVE, knuts])
		return
	if direction != "buy" and direction != "sell":
		errors.append("exchange_money 方向非法（须为 buy/sell）: %s" % direction)
		return
	var rate := float(world.economy.get("foreign_rate", 1.0))
	var held := int(world.economy.get("foreign_held", 0))
	var spread := float(Economy.FOREIGN_SPREAD)
	if direction == "buy":
		if world.player.money_knuts < knuts:
			errors.append("现金不足，无法买入外币 %d 纳特（现有 %d）" % [knuts, world.player.money_knuts])
			return
		# 买入：付出加隆，收到「打折后」的外币等值（价差对玩家不利）
		var gained := int(round(float(knuts) * rate * (1.0 - spread)))
		world.player.money_knuts -= knuts
		world.economy["foreign_held"] = held + gained
	else:
		if held < knuts:
			errors.append("外币不足，无法卖出 %d 纳特等值（现有 %d）" % [knuts, held])
			return
		# 卖出：交出外币等值，收到「打折后」的加隆
		var cash := int(round(float(knuts) * rate * (1.0 - spread)))
		world.economy["foreign_held"] = held - knuts
		world.player.money_knuts += cash


static func _apply_trade(world: WorldState, raw: Dictionary, errors: PackedStringArray) -> void:
	var good_id := str(raw.get("good_id", ""))
	var mode := str(raw.get("mode", ""))
	var qty := _payload_int(raw, "qty", 0)

	if not world.registry.has("goods", good_id):
		errors.append("未知商品: %s" % good_id)
		return
	if qty <= 0:
		errors.append("trade_money 数量必须为正: %d" % qty)
		return
	if qty > OpGuard.MAX_TRADE_QTY:
		errors.append("trade_money 超过单笔件数上限 %d: %d" % [OpGuard.MAX_TRADE_QTY, qty])
		return
	if mode != "buy" and mode != "sell":
		errors.append("trade_money 模式非法（须为 buy/sell）: %s" % mode)
		return
	# 货值闸门：按 base_price_knuts 判（不含倍数/路费）。超限拒绝，**不**自动缩量 ——
	# 静默改成能过的量会让「玩家想买 100 把扫帚」变成「悄悄买 0 把」，语义不明。
	var entry := world.registry.entry("goods", good_id)
	var base_price := int(entry.get("base_price_knuts", 0))
	if base_price * qty > OpGuard.MAX_TRADE_VALUE:
		errors.append("货值超限：%s 单笔货值 %d 纳特 > 上限 %d（单笔最多 %d 件）"
			% [good_id, base_price * qty, OpGuard.MAX_TRADE_VALUE,
				int(OpGuard.MAX_TRADE_VALUE / maxi(base_price, 1))])
		return
	# 断供不可交易（spec §7.5）
	if not Economy.available(world, good_id):
		errors.append("商品当前断供，无法交易: %s" % good_id)
		return
	# 跨地：两地缺省 = 玩家当前地点。**两地相同就不是贸易**（没有价差），拒绝。
	var here := world.player.location_id
	var origin := str(raw.get("origin_location_id", ""))
	var dest := str(raw.get("location_id", ""))
	if origin.is_empty():
		origin = here
	if dest.is_empty():
		dest = here
	var category := str(entry.get("category", ""))
	var haul_per := int(Economy.TRADE_HAUL_KNUTS.get(category, 0))
	if mode == "buy":
		var origin_mult := Economy.local_mult_at(world, origin)
		var dest_mult := Economy.local_mult_at(world, dest)
		if is_equal_approx(origin_mult, dest_mult):
			errors.append("买入与卖出地点无价差，不构成贸易（%s → %s）" % [origin, dest])
			return
		var unit := Economy.price_at(world, good_id, origin)
		if unit <= 0:
			errors.append("商品在%s无价（断供或未知商品）: %s" % [origin, good_id])
			return
		var total := unit * qty + haul_per * qty
		if world.player.money_knuts < total:
			errors.append("现金不足，无法购入 %d 件 %s（需 %d 纳特，现有 %d）"
				% [qty, good_id, total, world.player.money_knuts])
			return
		# 校验全过 → 才写状态
		world.player.money_knuts -= total
		_record_trade_side_effects(world, category)
	else:
		var origin_mult2 := Economy.local_mult_at(world, origin)
		var dest_mult2 := Economy.local_mult_at(world, dest)
		if is_equal_approx(origin_mult2, dest_mult2):
			errors.append("卖出与买入地点无价差，不构成贸易（%s → %s）" % [origin, dest])
			return
		var unit2 := Economy.price_at(world, good_id, dest)
		if unit2 <= 0:
			errors.append("商品在%s无价（断供或未知商品）: %s" % [dest, good_id])
			return
		# 卖出：收到售价，**扣除**路费
		var gained := unit2 * qty - haul_per * qty
		world.player.money_knuts += gained
		_record_trade_side_effects(world, category)


## 交易副作用：走私**只记不判**（spec §10 第 4 条）。法律后果属 03c。
static func _record_trade_side_effects(world: WorldState, category: String) -> void:
	if category != "illegal":
		return
	world.economy["smuggling_heat"] = int(world.economy.get("smuggling_heat", 0)) + 1
	world.flags["illegal_trade"] = true

# cast_spell 需要一个随机源；由世界种子、回合与调用序号共同推导，保证可复现且同回合内不重复。
# 计数器入 world.flags（持久化），OpGuard 禁止 LLM 写以 "_" 开头的 flag key。
static func world_gm_rng(world: WorldState) -> RngService:
	var counter := int(world.flags.get("_gm_rng_counter", 0))
	world.flags["_gm_rng_counter"] = counter + 1
	return RngService.new(world.game_seed + world.clock.turn * 15485863 + counter * 2654435761)
