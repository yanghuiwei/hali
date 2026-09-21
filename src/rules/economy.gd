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


static func local_mult_for(_world: WorldState, _good_id: String) -> float:
	## 地点系数。缺省必须安全：未标记的地点一律平价（不得因缺字段变成 0 倍价）。
	var tag := str(_world.world_vars.get("location_tag", ""))
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
	## 算价四因子（**没有 supply_mult**，C5）。
	var e := world.registry.entry("goods", good_id)
	return {
		"base": int(e.get("base_price_knuts", 0)),
		"era_mult": era_mult_for(world),
		"scarcity_mult": scarcity_mult_for(world, str(e.get("industry_id", ""))),
		"local_mult": local_mult_for(world, good_id),
	}


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


