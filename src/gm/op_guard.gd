class_name OpGuard
extends RefCounted

const MAX_OPS := 20
const MAX_MONEY_GAIN := 1000
const MAX_RELATION_DELTA := 20
const MAX_STANDING_DELTA := 20
const TRAIN_BASE_GAIN := 4

# ---- 计划 03b Task 4：经济 op 的钳制（spec §7.5 / §13 风险 7）----
const MAX_BANK_MOVE := 100000      # 单笔存取/汇兑上限（纳特）
const MAX_TRADE_QTY := 100         # 单笔交易件数上限
## ⚠️ **货值闸门**：单笔交易的 `base_price_knuts × qty <= MAX_TRADE_VALUE`（纳特，**不含**任何倍数与路费）。
## 这是防「高价商品套利」的唯一有效闸门 —— `MAX_TRADE_QTY` 是**件数**上限，对高价商品形同虚设：
## 实算「产区 0.85 → 偏远 1.2，扣两次路费」得 `broom_nimbus` 净利 17 135 纳特/件，
## `qty=100` ⇒ 单笔 1 713 500 纳特 = 3 476 加隆 ≈ **11.6 倍「普通家庭年收入数百加隆」**（正典 223 行）。
## 加闸后 qty 上限：`svc_owl_post` 100 / `potion_common` 5 / `wand_standard` 1 / `broom_nimbus` **0（拒绝）**。
const MAX_TRADE_VALUE := 5000

## 禁止 LLM 触碰的经济 op（**一律拒绝**，与 03a 的 `set_faction_*` 不同：
## 那些透传给 `StateOps` 拒绝，这些连 `StateOps` 都没有实现，必须在 OpGuard 层就拦掉）。
const _ECONOMY_FORBIDDEN := [
	"set_economy_index", "set_gringotts_balance", "set_gringotts_interest_rate",
	"set_prices", "set_smuggling_heat", "set_foreign_rate",
	"set_economy", "set_crisis",
]

## 单条 op 的净化入口（返回 `Result`）。既有代码用 `sanitize`/`sanitize_detailed`，
## 本函数是 03b 为「逐条判定」新增的薄封装 —— 便于测试与调用方按条询问「这条能不能放行」。
static func sanitize_op(world: WorldState, raw) -> Result:
	## ⚠️ 故意的**无状态**封装：`sanitize_detailed` 内部的 `money_gain` 累加器是**每批**共享的，
	## 逐条调用时每批只有一条 ⇒ 各自全新累加器。对本函数的用途（合法/非法判定）无影响，
	## 但**不要**用逐条调用的结果替代批量调用的结果（`add_money` 的批内累计上限会不同）。
	if typeof(raw) != TYPE_DICTIONARY:
		var bad := Result.new()
		bad.ok = false
		bad.warnings.append("非字典 op 一律拒绝")
		return bad
	var res := sanitize_detailed(world, [raw])
	# 单条判定的「通过」定义：**恰好产出了一条 op**。被拦的 op 一律不产出（`continue`），
	# 故 0 条 ⇒ 被拒；不会出现 >1 条。
	res.ok = res.ops.size() == 1
	return res

class Result:
	var ops: Array = []
	var warnings: PackedStringArray = PackedStringArray()
	## 逐条判定用的结论位。`sanitize_detailed` 不设置它（批量语义下「一批」是否通过无意义 ——
	## 部分通过、部分被拦是常态）；只有 `sanitize_op`（单条入口）才填。
	## 默认 `true`：让「直接用 ops/warnings 的既有调用方」不受影响。
	var ok: bool = true

# LLM 输出不可信：字段类型错时返回 fallback，绝不在 int() 处崩。
static func _to_int(value, fallback: int = 0) -> int:
	if typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT:
		return int(value)
	return fallback

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
				var knuts := _to_int(raw.get("knuts", 0))
				if knuts < 0:
					out.warnings.append("支出未经校验（%d 纳特）" % knuts)
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
				var tier := clampi(_to_int(raw.get("tier", world.player.magic_tier)), world.player.magic_tier - 1, world.player.magic_tier + 1)
				tier = clampi(tier, 0, MagicLevel.LABELS.size() - 1)
				out.ops.append({"op": "set_magic_tier", "tier": tier})
			"relation_delta":
				var npc_id := str(raw.get("npc_id", ""))
				if npc_id.is_empty():
					out.warnings.append("忽略缺 npc_id 的 relation_delta")
					continue
				out.ops.append({
					"op": "relation_delta", "npc_id": npc_id,
					"trust": clampi(_to_int(raw.get("trust", 0)), -MAX_RELATION_DELTA, MAX_RELATION_DELTA),
					"interest": clampi(_to_int(raw.get("interest", 0)), -MAX_RELATION_DELTA, MAX_RELATION_DELTA),
					"hostility": clampi(_to_int(raw.get("hostility", 0)), -MAX_RELATION_DELTA, MAX_RELATION_DELTA),
				})
			"join_faction", "leave_faction":
				if op == "join_faction":
					var fid := str(raw.get("faction_id", ""))
					if fid.is_empty():
						out.warnings.append("忽略缺 faction_id 的 join_faction")
						continue
					out.ops.append({"op": "join_faction", "faction_id": fid})
				else:
					out.ops.append({"op": "leave_faction"})
			"faction_standing_delta":
				var sid := str(raw.get("faction_id", ""))
				if sid.is_empty():
					out.warnings.append("忽略缺 faction_id 的 faction_standing_delta")
					continue
				out.ops.append({"op": "faction_standing_delta", "faction_id": sid,
					"delta": clampi(_to_int(raw.get("delta", 0)), -MAX_STANDING_DELTA, MAX_STANDING_DELTA)})
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
			# ---- 计划 03b Task 4：经济 op（LLM 只能动玩家侧，不能动世界经济）----
			"deposit_money", "withdraw_money":
				var bank_knuts := _to_int(raw.get("knuts", 0))
				if bank_knuts <= 0:
					out.warnings.append("忽略非正金额的 %s" % op)
					continue
				if bank_knuts > MAX_BANK_MOVE:
					bank_knuts = MAX_BANK_MOVE
					out.warnings.append("%s 金额已钳到上限 %d" % [op, MAX_BANK_MOVE])
				out.ops.append({"op": op, "knuts": bank_knuts})
			"exchange_money":
				var fx_knuts := _to_int(raw.get("knuts", 0))
				var direction := str(raw.get("direction", ""))
				if direction != "buy" and direction != "sell":
					out.warnings.append("忽略非法方向的 exchange_money: %s" % direction)
					continue
				if fx_knuts <= 0:
					out.warnings.append("忽略非正金额的 exchange_money")
					continue
				if fx_knuts > MAX_BANK_MOVE:
					fx_knuts = MAX_BANK_MOVE
					out.warnings.append("exchange_money 金额已钳到上限 %d" % MAX_BANK_MOVE)
				out.ops.append({"op": "exchange_money", "knuts": fx_knuts, "direction": direction})
			"trade_money":
				var good_id := str(raw.get("good_id", ""))
				if good_id.is_empty() or not world.registry.has("goods", good_id):
					out.warnings.append("忽略未知商品的 trade_money: %s" % good_id)
					continue
				var mode := str(raw.get("mode", ""))
				if mode != "buy" and mode != "sell":
					out.warnings.append("忽略非法模式的 trade_money: %s" % mode)
					continue
				var qty := clampi(_to_int(raw.get("qty", 0)), 0, MAX_TRADE_QTY)
				# 货值闸门：按 base_price_knuts 判（不含倍数/路费），超限则 qty 归零 ⇒ 下游必然拒绝
				var base_price := int(world.registry.entry("goods", good_id).get("base_price_knuts", 0))
				if base_price > 0:
					var qty_by_value := int(MAX_TRADE_VALUE / base_price)
					if qty > qty_by_value:
						qty = qty_by_value
						out.warnings.append("货值超限：%s 单笔最多 %d 件（base %d × qty <= %d）"
							% [good_id, qty_by_value, base_price, MAX_TRADE_VALUE])
				out.ops.append({
					"op": "trade_money", "good_id": good_id, "qty": qty, "mode": mode,
					"origin_location_id": str(raw.get("origin_location_id", "")),
					"location_id": str(raw.get("location_id", "")),
				})
			_:
				if _ECONOMY_FORBIDDEN.has(op):
					out.warnings.append("拒绝 LLM 改世界经济: %s" % op)
					continue
				out.warnings.append("未知 op 交给 StateOps 判定: %s" % op)
				out.ops.append(raw)
	return out
