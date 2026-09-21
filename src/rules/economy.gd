class_name Economy
extends RefCounted

## 计划 03b · 经济规则层（静态函数，纯规则，不依赖 UI/GM）
##
## 数值口径见 spec §7.4，全部经 Python 实算脚本验证（C1–C6）。
## 依赖方向（单向）：data/ → Registry → Economy → WorldState / StateOps / PanelFormatter / PromptBuilder。
## 本类**不得** preload 任何 src/ui/ 或 src/gm/ 脚本。

# ---- 价格定版常数（照抄 spec §7.4 实算结果，不要自创）----
const NEUTRAL_INDEX := 0.5             # canon 常态价的定义基准
const NEUTRAL_ERA_YEAR := 1950         # canon 价位语境的时代（era_mult == 1.0）
const MIN_SCARCITY := 0.75             # 繁荣侧地板
const MAX_SCARCITY := 1.40             # 危机侧天花板（由魔杖区间 1.4286x 反推）
const CRISIS_THRESHOLD := 0.35         # 危机态（与 factions.gd 共用，必须只有一个来源）
const SUPPLY_CUTOFF := 0.15            # 断供线（与危机线解耦：危机中仍有货）
const MONOPOLY_EXCESS_MULT := 2.0      # 垄断行业涨价侧超额部分加倍

const LOCAL_MULT := {"产地": 0.85, "常规": 1.0, "偏远": 1.2, "黑市": 1.35}
const LOCAL_MULT_DEFAULT := 1.0        # 缺省必须安全：未标记地点一律平价

## `locations.json` 的 `zone` → `LOCAL_MULT` 档位（spec §7.4 第 4 条）。
## ⚠️ 不映射的 zone（或地点缺 `zone` 字段）一律走 `LOCAL_MULT_DEFAULT`。
## 实况修正（2026-09-21 缺陷⑧）：原口径读 `world_vars["location_tag"]`，该键全仓库无写入方
## ⇒ 生产路径永远走缺省 1.0，且 `world_vars` 在玩家换地点时不变 ⇒ E7「产地买、销地卖」不可能。
const _LOCAL_ZONE_TAG := {
	"wild": "产地", "forbidden": "产地",
	"wizarding": "常规", "school": "常规",
	"muggle": "偏远",
}

## 时代系数（按时代起始年落档；缺省落在现代档）
const ERA_MULT := [
	{"y_max": 1000, "mult": 0.35},
	{"y_max": 1691, "mult": 0.55},
	{"y_max": 1945, "mult": 0.85},
	{"y_max": 1980, "mult": 1.00},
	{"y_max": 1998, "mult": 1.15},
	{"y_max": 99999, "mult": 1.10},
]

# ⚠️ 与 src/core/registry.gd 的 _GOODS_CATEGORIES / _GOODS_KINDS 白名单必须同步
#    （registry 处于 Economy 的下游，不能反向 preload Economy 常量，故两处各写字面量，
#     由 tests/registry_test.gd 的「枚举两处一致」断言钉死）。
## 顺序即面板展示顺序
const CATEGORIES: Array[String] = ["wand", "potion", "material", "broom", "book",
	"food", "service", "creature", "artifact", "illegal"]
const KINDS: Array[String] = ["goods", "service"]

## 路费（纳特/件，按 category；服务无路费）。spec §7.5 trade_money。
const TRADE_HAUL_KNUTS := {
	"service": 0, "food": 2, "material": 5, "book": 10, "potion": 20,
	"wand": 30, "artifact": 50, "broom": 60, "creature": 80, "illegal": 120,
}

const FOREIGN_SPREAD := 0.02           # 外币买卖价差（spec §7.5 exchange_money）
const INTEREST_RATE := 0.002           # 古灵阁月息（常态）
const INTEREST_RATE_CRISIS := 0.0012   # 危机期利率（spec §7.4 第 7 条）
const SMUGGLING_PROFIT_MULT_CRISIS := 1.5

# ---- Task 5：月度结算口径（spec §7.6）----
## 成年门槛（K2）：17 岁。与 character_creation / 既有年龄口径对齐。
const ADULT_MONTHS := 204
## 生活开销里的食物份数（两餐/日 × 30 日）。
const FOOD_UNITS_PER_MONTH := 60
## 自由文本职业匹配不到 job 表时的兜底月薪（店员档）。**不是 0** ——
## 自由文本职业（LLM 给的「见习傲罗」之类）不得变成零收入（spec §7.6）。
const UNKNOWN_WAGE_KNUTS := 4930

# ============================================================================
# 算价核心（spec §7.4）
# price = roundi(base × era_mult × scarcity_mult × local_mult)
# ⚠️ supply 不进这个公式（C5）—— 它只决定 available() / 断供。
# ============================================================================

static func era_mult_for(world: WorldState) -> float:
	## 时代系数：按时代起始年落档。缺省落在现代档（1.10），不抛错。
	var years := int(world.registry.entry("eras", world.era_id).get("start_year", NEUTRAL_ERA_YEAR))
	for band in ERA_MULT:
		if years <= int(band["y_max"]):
			return float(band["mult"])
	return 1.10


static func _is_monopoly(world: WorldState, industry_id: String) -> bool:
	if industry_id.is_empty():
		return false
	return bool(world.registry.entry("industries", industry_id).get("monopoly", false))


static func scarcity_mult_for(world: WorldState, industry_id: String) -> float:
	## 稀缺倍率：景气越低越贵（两侧弹性不对称 —— 危机侧 1.2 / 繁荣侧 0.2）。
	var idx := float(world.world_vars.get("economy_index", NEUTRAL_INDEX))
	var raw := 0.0
	if idx >= NEUTRAL_INDEX:
		raw = 1.0 - (idx - NEUTRAL_INDEX) * 0.2
	else:
		raw = 1.0 + (NEUTRAL_INDEX - idx) * 1.2
	# 垄断行业：涨价侧的超额部分加倍（spec §7.4 第 5 条）
	# ⚠️ 加倍后必须再过 clampf —— 否则垄断行业会突破 C3。
	if raw > 1.0 and _is_monopoly(world, industry_id):
		raw = 1.0 + (raw - 1.0) * MONOPOLY_EXCESS_MULT
	return clampf(raw, MIN_SCARCITY, MAX_SCARCITY)


static func local_mult_for(world: WorldState, _good_id: String = "") -> float:
	## 地点系数。缺省必须安全：未知/未标记的地点一律平价（不得因缺字段变成 0 倍价）。
	##
	## ⚠️ 实况修正（2026-09-21 缺陷⑧）：原读 `world_vars["location_tag"]`，该键**全仓库无写入方**，
	## 生产路径永远走缺省 1.0（`grep location_tag` 只命中本文件、测试的手动注入与 plan 文本）；
	## 更致命的是 `world_vars` 在玩家换地点时不变 ⇒「产地买、销地卖」在实现上不可能。
	## 现按 `locations.json` 的 `zone` 推导，玩家一换地点价格立刻跟着变。
	## 对 C1–C3 **无影响**：验收基准是 `local_mult == 1.0` 的常规地点（对角巷/霍格沃茨等）。
	##
	## `world == null` / `player == null` 是**畸形存档路径**（`SaveCodec.decode` 在类型校验
	## 失败前也会走 `from_dict`）⇒ 返回缺省 1.0，不得崩（2026-09-21 Task 4 实测：35 条 SCRIPT ERROR）。
	if world == null or world.player == null or world.registry == null:
		return LOCAL_MULT_DEFAULT
	var loc := world.registry.entry("locations", world.player.location_id)
	var tag := str(_LOCAL_ZONE_TAG.get(str(loc.get("zone", "")), ""))
	return float(LOCAL_MULT.get(tag, LOCAL_MULT_DEFAULT))


static func local_tag_for(world: WorldState, location_id: String) -> String:
	## 供测试与面板解释「为什么这里贵/便宜」。返回 `LOCAL_MULT` 的档位键；未标记返回 ""。
	return str(_LOCAL_ZONE_TAG.get(str(world.registry.entry("locations", location_id).get("zone", "")), ""))


static func local_mult_at(world: WorldState, location_id: String) -> float:
	## 指定地点的 `local_mult`（`trade_money` 的跨地算价用；不去改 `player.location_id`）。
	var tag := local_tag_for(world, location_id)
	return float(LOCAL_MULT.get(tag, LOCAL_MULT_DEFAULT))


static func effective_output(world: WorldState, industry_id: String) -> float:
	## 产业实际产出（供 available()/面板用；**不进价格**，C5）。
	if industry_id.is_empty():
		return 1.0
	var base := float(world.registry.entry("industries", industry_id).get("base_output", 1.0))
	var idx := float(world.world_vars.get("economy_index", NEUTRAL_INDEX))
	return clampf(base * (0.5 + idx * 0.5), 0.0, 1.0)


static func is_crisis(world: WorldState) -> bool:
	## 危机态判定。阈值只此一处（factions.gd 引用同一个常量）。
	return float(world.world_vars.get("economy_index", NEUTRAL_INDEX)) <= CRISIS_THRESHOLD


static func available(world: WorldState, good_id: String) -> bool:
	## 可得性：只有 supply_critical 商品会在 SUPPLY_CUTOFF 之下断供。
	## 与危机线**解耦**：危机中（0.16..0.35）仍可供货，只是贵。
	var e := world.registry.entry("goods", good_id)
	if e.is_empty():
		return false
	if not bool(e.get("supply_critical", false)):
		return true
	return float(world.world_vars.get("economy_index", NEUTRAL_INDEX)) > SUPPLY_CUTOFF


static func price_factors(world: WorldState, good_id: String) -> Dictionary:
	## 算价四因子（**没有 supply_mult**，C5）。地点因子取**玩家当前地点**。
	var e := world.registry.entry("goods", good_id)
	return {
		"base": int(e.get("base_price_knuts", 0)),
		"era_mult": era_mult_for(world),
		"scarcity_mult": scarcity_mult_for(world, str(e.get("industry_id", ""))),
		"local_mult": local_mult_for(world, good_id),
	}


static func price_factors_at(world: WorldState, good_id: String, location_id: String) -> Dictionary:
	## 与 `price_factors` 同式，**只把 `local_mult` 换成指定地点**（`trade_money` 跨地算价用）。
	## 抽成独立函数而不是让调用方自己乘 —— 否则算价公式就有两处实现，必然漂移。
	var f := price_factors(world, good_id)
	f["local_mult"] = local_mult_at(world, location_id)
	return f


static func price_at(world: WorldState, good_id: String, location_id: String) -> int:
	## 指定地点的价。断供/未知商品返回 0；否则恒 ≥ 1。取整与守门口径**与 `price_of` 完全一致**。
	if not available(world, good_id):
		return 0
	var f := price_factors_at(world, good_id, location_id)
	var raw := float(f["base"]) * float(f["era_mult"]) \
		* float(f["scarcity_mult"]) * float(f["local_mult"])
	return maxi(1, roundi(raw))


static func price_of(world: WorldState, good_id: String) -> int:
	## **唯一算价入口**。断供或未知商品返回 0；否则恒 ≥ 1。
	if not available(world, good_id):
		return 0
	var f := price_factors(world, good_id)
	var raw := float(f["base"]) * float(f["era_mult"]) \
		* float(f["scarcity_mult"]) * float(f["local_mult"])
	return maxi(1, roundi(raw))


# ============================================================================
# 状态初始化与价格快照（spec §7.3）
# ============================================================================

static func initialize(world: WorldState) -> void:
	## 幂等补齐 `world.economy` 的键集。老存档（无 economy）读档后由此补齐。
	##
	## ⚠️ **只补缺键，绝不覆盖已有值** —— 尤其是 `prices` 快照（2026-09-21 Task 2 实测踩到）：
	## 若在此无条件重算快照，`from_dict` 拿到的 `world_vars` 已过 `JsonUtil.normalize()`
	## （浮点尾差），会算出与存盘时**逐字不同**的价（实测 wand_standard 3644 → 3646），
	## 直接打破 save_test 的「读档后重建引擎续跑：世界状态一致」断言。
	## 快照的唯一刷新点是**世界推进**（`evolve()`，Task 6）。
	##
	## ⚠️ `player == null` ⇒ **直接返回**（2026-09-21 Task 4 实测踩到）：
	## `SaveCodec.decode` 在**类型校验失败之前**也会走一遍 `WorldState.from_dict`
	## （畸形载荷路径），此时 `player` 可能是 Nil。算价要读 `player.location_id`，
	## 在半个世界上跑必然崩 —— 实测 `save_test` 的 6 个畸形载荷共引发 35 条 SCRIPT ERROR。
	## 这是**防御性正确**：没有玩家的世界谈不上经济状态。
	if world == null or world.player == null:
		return
	var e: Dictionary = world.economy
	if not e.has("prices") or typeof(e["prices"]) != TYPE_DICTIONARY or (e["prices"] as Dictionary).is_empty():
		e["prices"] = {}
		_snapshot_prices(world)
	if not e.has("gringotts_balance"):
		e["gringotts_balance"] = 0
	if not e.has("gringotts_interest_rate"):
		e["gringotts_interest_rate"] = INTEREST_RATE
	if not e.has("foreign_rate"):
		e["foreign_rate"] = 1.0
	# ⚠️ 实况补充（2026-09-21，Task 4）：spec §7.3 的结构表漏了「玩家持有多少外币」，
	# 而 §7.5 的 `exchange_money` 要「现金/外币余额足」+ `sell` 反向 ⇒ 必须有这个账。
	# 语义：外币余额，**以纳特等值记账**（不是外币原始单位），这样它和 `gringotts_balance`
	# 与 `player.money_knuts` 三者同量纲，面板与结算都能直接相加。
	if not e.has("foreign_held"):
		e["foreign_held"] = 0
	if not e.has("smuggling_heat"):
		e["smuggling_heat"] = 0
	if not e.has("crisis"):
		e["crisis"] = false
	if not e.has("last_settlement_turn"):
		e["last_settlement_turn"] = 0
	if not e.has("last_month_income"):
		e["last_month_income"] = 0
	if not e.has("last_month_expense"):
		e["last_month_expense"] = 0


static func _snapshot_prices(world: WorldState) -> void:
	## 把当前景气/时代下的全表价格写进 `economy.prices`（面板与叙事只读此处，不重算）。
	var snap: Dictionary = world.economy.get("prices", {})
	if typeof(snap) != TYPE_DICTIONARY:
		snap = {}
	for good_id in world.registry.ids("goods"):
		snap[str(good_id)] = price_of(world, str(good_id))
	world.economy["prices"] = snap


static func snapshot_price(world: WorldState, good_id: String) -> int:
	## 读快照价（**不重算**）；快照缺失时才回落到 price_of。
	var snap: Dictionary = world.economy.get("prices", {})
	if snap.has(good_id):
		return int(snap[good_id])
	return price_of(world, good_id)


# ============================================================================
# 月度结算（E4② / spec §7.6）—— 确定性，无随机
# ============================================================================

static func _wage_for(world: WorldState, job: String) -> int:
	## 求 `job` 对应的月薪（纳特）。三级匹配（spec §7.6「工资」行）：
	##   ① 按 `label` 精确匹配（面板【职业】行显示的就是 label）
	##   ② 按 `id` 精确匹配（`player.job` 也可能是 id 形态）
	##   ③ 包含匹配（自由文本宽容：「霍格沃茨的魔药师」命中「魔药师」）
	## 全部落空 ⇒ `UNKNOWN_WAGE_KNUTS`（**不是 0**：自由文本职业不得变成零收入）。
	if world == null or world.registry == null:
		return UNKNOWN_WAGE_KNUTS
	var want := str(job).strip_edges()
	if want.is_empty():
		return UNKNOWN_WAGE_KNUTS

	# ① label 精确 / ② id 精确
	for jid in world.registry.ids("jobs"):
		var e: Dictionary = world.registry.entry("jobs", str(jid))
		if str(e.get("label", "")) == want or str(jid) == want:
			return int(e.get("wage_knuts", UNKNOWN_WAGE_KNUTS))

	# ③ 包含匹配（两侧互相包含，取最长命中键以避免短标签误伤）
	var best_wage := UNKNOWN_WAGE_KNUTS
	var best_len := 0
	for jid in world.registry.ids("jobs"):
		var e2: Dictionary = world.registry.entry("jobs", str(jid))
		var label := str(e2.get("label", ""))
		if label.is_empty():
			continue
		if want.contains(label) or label.contains(want):
			if label.length() > best_len:
				best_len = label.length()
				best_wage = int(e2.get("wage_knuts", UNKNOWN_WAGE_KNUTS))
	return best_wage


static func monthly_settlement(world: WorldState) -> Dictionary:
	## 按「玩家职业 + 所在地 + 世界景气」结算**一个月的工资/开销/利息**。
	##
	## 返回 `{"income", "expense", "interest"}`（**都是正数**，符号由调用方/面板加）。
	## 幂等：`last_settlement_turn == clock.turn` ⇒ 返回全 0 且**不改任何字段**
	## （spec §9 第 5 条 —— 同回合重复调用不得重复发钱）。
	##
	## 门槛（K2）：`age_months >= ADULT_MONTHS` **且** `job` 非空才有工资；
	## 无业者**只有支出**（会真的变穷，正典第十五章「上班」是基线）。
	##
	## ⚠️ **未成年整月跳过**（缺陷⑫，2026-09-21 裁定读法 B）：
	## `age_months < ADULT_MONTHS` ⇒ 返回全 0 且**不收生活费**（只推进 `last_settlement_turn`）。
	## 理由：正典 424 行未成年不得在校外使用魔法、563 行 17 岁前属「学徒」阶段
	## ⇒ 由家庭/学校供养。若照收 6477 纳特/月，11 岁开局到 17 岁前会累计欠 −946 加隆
	## （≈普通家庭 6 年收入），构成「必破产开局」。
	##
	## 开销**必须走 `price_of`**（不写死 base）—— 否则危机期物价翻倍而开销不变。
	##
	## ⚠️ `player == null` ⇒ 返回全 0（与 `initialize` 同款防御：畸形存档路径上
	## `SaveCodec.decode` 会在类型校验失败前走一遍 `from_dict`，此时可能没有玩家）。
	if world == null or world.player == null or world.registry == null:
		return {"income": 0, "expense": 0, "interest": 0}

	var cur_turn := int(world.clock.turn)
	if int(world.economy.get("last_settlement_turn", 0)) == cur_turn:
		return {"income": 0, "expense": 0, "interest": 0}

	var p := world.player

	# ---- 未成年整月跳过（缺陷⑫）：收支皆 0，但照常推进回合标记 ----
	if int(p.age_months) < ADULT_MONTHS:
		world.economy["last_month_income"] = 0
		world.economy["last_month_expense"] = 0
		world.economy["last_settlement_turn"] = cur_turn
		return {"income": 0, "expense": 0, "interest": 0}

	# ---- 工资：成年且有职业才有 ----
	var income := 0
	if not str(p.job).strip_edges().is_empty():
		income = _wage_for(world, str(p.job))

	# ---- 生活开销：房租 + 食物 × 份数（走 price_of，随景气浮动）----
	var expense := price_of(world, "svc_rent") \
		+ price_of(world, "food_pumpkin_pastry") * FOOD_UNITS_PER_MONTH

	# ---- 利息：只对正余额计息；负余额不计（不资本化债务）----
	var interest := 0
	var bal := int(world.economy.get("gringotts_balance", 0))
	if bal > 0:
		interest = floori(float(bal) * float(world.economy.get("gringotts_interest_rate", INTEREST_RATE)))
		world.economy["gringotts_balance"] = bal + interest

	# ---- 写回：现金按净额变更（允许为负 ⇒ 走 Money 的负债形态，Task 3 已就绪）----
	p.money_knuts = int(p.money_knuts) + income - expense
	world.economy["last_month_income"] = income
	world.economy["last_month_expense"] = expense
	world.economy["last_settlement_turn"] = cur_turn

	return {"income": income, "expense": expense, "interest": interest}


