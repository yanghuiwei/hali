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
