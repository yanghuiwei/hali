class_name GameClock
extends RefCounted

var year: int = 1991
var month: int = 9
var turn: int = 0

static func from_dict(d: Dictionary) -> GameClock:
	var c := GameClock.new()
	c.year = int(d.get("year", 1991))
	c.month = clampi(int(d.get("month", 1)), 1, 12)
	c.turn = int(d.get("turn", 0))
	return c

func to_dict() -> Dictionary:
	return {"year": year, "month": month, "turn": turn}

func advance_month() -> void:
	month += 1
	if month > 12:
		month = 1
		year += 1
	turn += 1

func advance_months(n: int) -> void:
	for i in maxi(n, 0):
		advance_month()

func formatted() -> String:
	return "%d年%d月" % [year, month]

func months_between(other: GameClock) -> int:
	return (other.year - year) * 12 + (other.month - month)
