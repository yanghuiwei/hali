### Task 3: 货币 + 魔法等级与失败率

**Files:**
- Create: `src/model/money.gd`
- Create: `src/rules/magic_level.gd`
- Create: `tests/money_test.gd`
- Create: `tests/magic_level_test.gd`
- Modify: `tests/run_tests.gd`

**Interfaces:**
- Consumes: `TestAssert`
- Produces:
  - `Money`（`extends RefCounted`，值语义，所有运算返回新对象）
    - 常量 `KNUTS_PER_SICKLE := 17`、`SICKLES_PER_GALLEON := 17`、`KNUTS_PER_GALLEON := 493`
    - `static from_knuts(total: int) -> Money`
    - `static from_dict(d: Dictionary) -> Money`（`{"galleons":int,"sickles":int,"knuts":int}`）
    - `total_knuts() -> int`、`parts() -> Array[int]`（`[加隆, 西可, 纳特]`，可为负）
    - `add(other: Money) -> Money`、`subtract(other: Money) -> Money`
    - `formatted() -> String`（`"1加隆 1西可 1纳特"`）、`to_dict() -> Dictionary`
  - `MagicLevel`（`extends RefCounted`）
    - `enum Tier { SQUIB, PRE_SCHOOL, FIRST_YEAR, OWL, NEWT, ADULT, EXPERT, MASTER, LEGEND, MYTH }`
    - `LABELS: Array[String]`（10 项，顺序即 Tier）
    - `BANDS: Array[Vector2]`（每级的失败率区间，Vector2(min, max)）
    - `MODIFIER_KEYS: Array[String]`（`combat_stress`, `injury`, `emotion`, `wand_mismatch`, `unfamiliar_spell`, `dark_magic_interference`）
    - `static label_of(tier: int) -> String`
    - `static index_of_label(label: String) -> int`（未找到返回 -1）
    - `static base_rate(tier: int) -> float`（区间中点）
    - `static effective_rate(tier: int, modifiers: Dictionary, aptitude_delta: float = 0.0) -> float`（钳制到 [0.005, 0.95]）

- [ ] **Step 1: 写失败测试**

创建 `tests/money_test.gd`：

```gdscript
class_name MoneyTest
extends RefCounted

func run() -> int:
	var a := TestAssert.new()

	# 第十八章：1加隆 = 17西可 = 493纳特
	a.eq(Money.KNUTS_PER_GALLEON, 493, "1加隆=493纳特")
	a.eq(Money.from_knuts(493).parts(), [1, 0, 0], "493纳特=1加隆")
	a.eq(Money.from_knuts(17).parts(), [0, 1, 0], "17纳特=1西可")
	a.eq(Money.from_knuts(510).parts(), [1, 0, 17], "493+17")
	a.eq(Money.from_knuts(511).parts(), [1, 1, 0], "493+17+1 归一到 1加隆1西可")

	# 展示格式
	a.eq(Money.from_knuts(493 + 17 + 1).formatted(), "1加隆 1西可 1纳特", "格式")
	a.eq(Money.from_knuts(0).formatted(), "0加隆 0西可 0纳特", "零")

	# 一根普通魔杖 7–10 加隆（第十八章），必须落在同一货币体系内
	var wand_price := Money.from_knuts(7 * Money.KNUTS_PER_GALLEON)
	a.eq(wand_price.parts(), [7, 0, 0], "魔杖 7 加隆")
	a.is_true(Money.from_knuts(10 * Money.KNUTS_PER_GALLEON).total_knuts() > wand_price.total_knuts(), "10加隆 > 7加隆")

	# 值语义：add/subtract 不得修改原对象
	var base := Money.from_knuts(100)
	var plus := base.add(Money.from_knuts(50))
	a.eq(base.total_knuts(), 100, "add 不修改原对象")
	a.eq(plus.total_knuts(), 150, "add 返回新对象")
	a.eq(plus.subtract(Money.from_knuts(200)).total_knuts(), -50, "允许负债（第十九章：家族破产）")

	# 往返
	var d := Money.from_knuts(493 * 3 + 17 * 2 + 5).to_dict()
	a.eq(d, {"galleons": 3, "sickles": 2, "knuts": 5}, "to_dict 归一")
	a.eq(Money.from_dict(d).total_knuts(), Money.from_knuts(493 * 3 + 17 * 2 + 5).total_knuts(), "往返一致")
	a.eq(Money.from_dict({}).total_knuts(), 0, "空字典=0")

	return a.report("money")
```

创建 `tests/magic_level_test.gd`：

```gdscript
class_name MagicLevelTest
extends RefCounted

func run() -> int:
	var a := TestAssert.new()

	# 第二十三章：等级序列
	a.eq(MagicLevel.LABELS.size(), 10, "十级")
	a.eq(MagicLevel.label_of(MagicLevel.Tier.SQUIB), "哑炮", "第一级")
	a.eq(MagicLevel.label_of(MagicLevel.Tier.PRE_SCHOOL), "麻瓜出身未入学", "第二级")
	a.eq(MagicLevel.label_of(MagicLevel.Tier.MYTH), "神话级", "第十级")
	a.eq(MagicLevel.index_of_label("N.E.W.T水平"), MagicLevel.Tier.NEWT, "按标签反查")
	a.eq(MagicLevel.index_of_label("不存在的等级"), -1, "未知标签返回 -1")
	a.eq(MagicLevel.label_of(99), "未知", "越界安全")

	# 第二十二章失败率区间，逐字核对
	a.eq(MagicLevel.BANDS[MagicLevel.Tier.PRE_SCHOOL], Vector2(0.60, 0.80), "未入学 60-80%")
	a.eq(MagicLevel.BANDS[MagicLevel.Tier.FIRST_YEAR], Vector2(0.30, 0.50), "低年级 30-50%")
	a.eq(MagicLevel.BANDS[MagicLevel.Tier.OWL], Vector2(0.15, 0.30), "O.W.L 15-30%")
	a.eq(MagicLevel.BANDS[MagicLevel.Tier.NEWT], Vector2(0.05, 0.15), "N.E.W.T 5-15%")
	a.eq(MagicLevel.BANDS[MagicLevel.Tier.ADULT], Vector2(0.02, 0.05), "熟练成年 2-5%")
	a.is_true(MagicLevel.BANDS[MagicLevel.Tier.MASTER].y <= 0.02, "大师级低于 2%")
	a.eq(MagicLevel.effective_rate(MagicLevel.Tier.SQUIB, {}), 0.95, "哑炮无法施法，钳制上界")

	# 无环境因素时等于区间中点
	a.near(MagicLevel.effective_rate(MagicLevel.Tier.FIRST_YEAR, {}), 0.40, 0.0001, "低年级中点 40%")
	a.near(MagicLevel.effective_rate(MagicLevel.Tier.NEWT, {}), 0.10, 0.0001, "N.E.W.T 中点 10%")

	# 第二十二章：环境因素大幅改变失败概率
	var calm := MagicLevel.effective_rate(MagicLevel.Tier.ADULT, {})
	var stressed := MagicLevel.effective_rate(MagicLevel.Tier.ADULT, {"combat_stress": 1.0, "injury": 1.0})
	a.is_true(stressed > calm, "战斗压力与受伤提高失败率")
	a.is_true(stressed - calm >= 0.20, "两项满值环境因素至少 +20 个百分点")
	a.is_true(MagicLevel.effective_rate(MagicLevel.Tier.MYTH, {"combat_stress": 1.0, "injury": 1.0, "emotion": 1.0, "wand_mismatch": 1.0, "unfamiliar_spell": 1.0, "dark_magic_interference": 1.0}) <= 0.95, "失败率上界 0.95")
	a.is_true(MagicLevel.effective_rate(MagicLevel.Tier.LEGEND, {}) >= 0.005, "失败率下界 0.005（没有绝对成功）")

	# 资质偏移（data/aptitudes.json 的 failure_delta）
	a.near(MagicLevel.effective_rate(MagicLevel.Tier.FIRST_YEAR, {}, -0.10), 0.30, 0.0001, "优秀资质降低失败率")

	# 未知修正键必须被忽略而不是崩
	a.near(MagicLevel.effective_rate(MagicLevel.Tier.FIRST_YEAR, {"不存在的因素": 5.0}), 0.40, 0.0001, "未知修正键被忽略")

	return a.report("magic_level")
```

- [ ] **Step 2: 运行测试，确认失败**

```bash
cd /e/Hali
sed -i 's|"res://tests/registry_test.gd",|"res://tests/registry_test.gd",\n\t"res://tests/money_test.gd",\n\t"res://tests/magic_level_test.gd",|' tests/run_tests.gd
bash tools/test.sh
```

预期：两个套件 `套件无法加载（语法错误？）`，退出码 1。

- [ ] **Step 3: 实现 `Money`**

创建 `src/model/money.gd`：

```gdscript
class_name Money
extends RefCounted

const KNUTS_PER_SICKLE := 17
const SICKLES_PER_GALLEON := 17
const KNUTS_PER_GALLEON := 493

var _knuts: int = 0

static func from_knuts(total: int) -> Money:
	var m := Money.new()
	m._knuts = total
	return m

static func from_dict(d: Dictionary) -> Money:
	return from_knuts(int(d.get("galleons", 0)) * KNUTS_PER_GALLEON \
		+ int(d.get("sickles", 0)) * KNUTS_PER_SICKLE \
		+ int(d.get("knuts", 0)))

func total_knuts() -> int:
	return _knuts

func add(other: Money) -> Money:
	return from_knuts(_knuts + other.total_knuts())

func subtract(other: Money) -> Money:
	return from_knuts(_knuts - other.total_knuts())

func parts() -> Array[int]:
	var negative := _knuts < 0
	var v: int = absi(_knuts)
	var g: int = v / KNUTS_PER_GALLEON
	var rest: int = v % KNUTS_PER_GALLEON
	var s: int = rest / KNUTS_PER_SICKLE
	var k: int = rest % KNUTS_PER_SICKLE
	if negative:
		return [-g, -s, -k]
	return [g, s, k]

func formatted() -> String:
	var p := parts()
	return "%d加隆 %d西可 %d纳特" % [p[0], p[1], p[2]]

func to_dict() -> Dictionary:
	var p := parts()
	return {"galleons": p[0], "sickles": p[1], "knuts": p[2]}
```

- [ ] **Step 4: 实现 `MagicLevel`**

创建 `src/rules/magic_level.gd`：

```gdscript
class_name MagicLevel
extends RefCounted

enum Tier { SQUIB, PRE_SCHOOL, FIRST_YEAR, OWL, NEWT, ADULT, EXPERT, MASTER, LEGEND, MYTH }

const LABELS: Array[String] = [
	"哑炮", "麻瓜出身未入学", "霍格沃茨新生", "O.W.L水平", "N.E.W.T水平",
	"熟练成年巫师", "专家级", "大师级", "传奇级", "神话级",
]

# 第二十二章施法失败概率，逐字编码为区间
const BANDS: Array[Vector2] = [
	Vector2(1.00, 1.00),   # 哑炮：无法施法
	Vector2(0.60, 0.80),   # 新手/未入学
	Vector2(0.30, 0.50),   # 霍格沃茨低年级
	Vector2(0.15, 0.30),   # O.W.L
	Vector2(0.05, 0.15),   # N.E.W.T
	Vector2(0.02, 0.05),   # 熟练成年巫师
	Vector2(0.02, 0.05),   # 专家级
	Vector2(0.005, 0.02),  # 大师级
	Vector2(0.005, 0.015), # 传奇级
	Vector2(0.005, 0.01),  # 神话级
]

const MODIFIER_KEYS: Array[String] = [
	"combat_stress", "injury", "emotion", "wand_mismatch", "unfamiliar_spell", "dark_magic_interference",
]

const MODIFIER_WEIGHT := 0.15

static func label_of(tier: int) -> String:
	if tier < 0 or tier >= LABELS.size():
		return "未知"
	return LABELS[tier]

static func index_of_label(label: String) -> int:
	return LABELS.find(label)

static func base_rate(tier: int) -> float:
	var band: Vector2 = BANDS[clampi(tier, 0, BANDS.size() - 1)]
	return (band.x + band.y) * 0.5

static func effective_rate(tier: int, modifiers: Dictionary, aptitude_delta: float = 0.0) -> float:
	var clamped_tier := clampi(tier, 0, BANDS.size() - 1)
	if clamped_tier == Tier.SQUIB:
		return 0.95
	var rate := base_rate(clamped_tier) + aptitude_delta
	for key in MODIFIER_KEYS:
		rate += clampf(float(modifiers.get(key, 0.0)), 0.0, 1.0) * MODIFIER_WEIGHT
	return clampf(rate, 0.005, 0.95)
```

- [ ] **Step 5: 运行测试，确认通过**

```bash
cd /e/Hali
bash tools/test.sh
```

预期：`[money] 失败=0`、`[magic_level] 失败=0`、`全部通过。`

- [ ] **Step 6: 提交**

```bash
cd /e/Hali
git add src/model/money.gd src/rules/magic_level.gd tests/money_test.gd tests/magic_level_test.gd tests/run_tests.gd
git commit -m "feat(rules): 巫师货币与魔法等级失败率"
```

---

