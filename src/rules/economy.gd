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
