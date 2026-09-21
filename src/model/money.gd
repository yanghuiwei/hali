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
	var g: int = -p[0]
	var s: int = -p[1]
	var k: int = -p[2]
	if g == 0 and s == 0 and k == 0:
		return "0加隆 0西可 0纳特"   # 防御：不该走到这里（is_debt 已保证 < 0）
	var out := "负债"
	if g > 0:
		out += " %d加隆" % g
	if s > 0:
		out += " %d西可" % s
	if k > 0:
		out += " %d纳特" % k
	return out


func formatted() -> String:
	## 非负分支**逐字保持既有输出**（三位全写，含 0）；
	## 负值走债务形态（计划 03b Task 3 / E9）。
	if is_debt():
		return debt_formatted()
	var p := parts()
	return "%d加隆 %d西可 %d纳特" % [p[0], p[1], p[2]]

func to_dict() -> Dictionary:
	var p := parts()
	return {"galleons": p[0], "sickles": p[1], "knuts": p[2]}
