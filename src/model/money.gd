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

func is_debt() -> bool:
	## 是否负债（正典第十九章：家族破产允许负值）。
	return _knuts < 0


func debt_formatted() -> String:
	## 债务形态：「负债 2加隆 16纳特」。
	## ⚠️ parts() 返回 [-g, -s, -k]，第三位是**纳特**不是西可（-1002 = 2×493 + 16）。
	## 0 值单位一律省略（-493 只写「负债 1加隆」，不带「0西可 0纳特」尾巴）。
	var p := parts()
	# ⚠️ 2026-09-21（03b Task 12 收尾）踩坑记录：
	#   ① 本函数**不需要** int 强转 —— `parts()` 返回的 `Array[int]` 索引出来就是 `TYPE_INT`
	#      （实测 `typeof(p[0]) == 2`），`-p[0]` 与 `absi(p[0])` 都保持 int。
	#      （我一度以为「取负走动态分派会变 float」并据此改代码 + 改断言 —— **那是错的**，
	#       实测 `parts(-100) == [0, -5, -15]`（值全对），失败原因是**我自己的期望值算错了**：
	#       我把 -100 纳特写成「1加隆3西可」，实际是 **0加隆 5西可 15纳特**。
	#       教训：断言里的钱数一律用 `bash` 的整数运算或裸纳特表达式核一遍，别手算。）
	#   ② 真正需要修的是**空格**：「负债」与其后单位之间必须有空格，
	#      否则拼出 `负债1加隆` 与既有契约/既有断言（`负债 1加隆`）不符。
	var g: int = -p[0]
	var s: int = -p[1]
	var k: int = -p[2]
	var neg := is_debt()   # parts() 的 0 位恒为 0，无法表达 `-0` ⇒ 符号单独用布尔承载
	if g == 0 and s == 0 and k == 0 and not neg:
		return "0加隆 0西可 0纳特"   # 防御：不该走到这里（is_debt 已保证 < 0）
	var units: Array[String] = []
	if g > 0:
		units.append("%d加隆" % g)
	if s > 0:
		units.append("%d西可" % s)
	if k > 0:
		units.append("%d纳特" % k)
	var joined := " ".join(units)
	return ("负债 %s" % joined) if neg else joined


func formatted() -> String:
	## 非负分支**逐字保持既有输出**（三位全写，含 0）；
	## 负值走债务形态（计划 03b Task 3 / E9）。
	if is_debt():
		return debt_formatted()
	var p := parts()
	return "%d加隆 %d西可 %d纳特" % [p[0], p[1], p[2]]


func signed_formatted() -> String:
	## **带符号**的可读形态：非负 ≡ `formatted()`（逐字相同）；负值 ⇒ `debt_formatted()`。
	##
	## 为什么不直接复用 `formatted()`：`formatted()` 的契约是**金额形态**（它的负值分支
	## 是给「余额/余额差」这类**本身就是负数**的场合用的）。而面板【经济】行的
	## 「本月净收支」需要的是**带符号的增量**（`+0加隆 1西可 12纳特` / `负债 …`）——
	## 两者在实现上恰好都落到 `debt_formatted()`，但语义不同，故显式分开命名。
	##
	## ⚠️ 与 `formatted()` 的**唯一**区别：非负时补 `+` 号。**不改** `formatted()` 本体
	## （它被 03a 的既有断言逐字钉死）。
	if is_debt():
		return debt_formatted()
	return "+" + formatted()


## 债务形态的**结构化**分解（Task 12 收尾新增）。
## 语义：0 值单位省略；**符号落在 `debt` 布尔上**（`galleons` 等恒为非负的「欠多少」）。
## 与 `parts()` 的区别：`parts()` 是 `to_dict()` 的底层形态（0 位恒为 0，无法表达 `-0`），
## 因此「负债 1加隆 0西可 0纳特」与「1加隆 0西可 0纳特」在 `parts()` 里长得一样。
## `debt_parts()` 用 `debt` 布尔补上这个信息，便于断言与将来的 UI 复用。
func debt_parts() -> Dictionary:
	var p := parts()
	var debt := is_debt()
	return {
		"debt": debt,
		"galleons": absi(p[0]),
		"sickles": absi(p[1]),
		"knuts": absi(p[2]),
	}

func to_dict() -> Dictionary:
	var p := parts()
	return {"galleons": p[0], "sickles": p[1], "knuts": p[2]}
