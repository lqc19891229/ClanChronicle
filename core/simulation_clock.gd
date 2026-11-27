extends RefCounted
## Deterministic 360-day calendar. Signals fire at every crossed boundary.
signal day_ended(day: int)
signal month_started(day: int)
signal year_started(day: int)

const DAYS_PER_MONTH = 30
const DAYS_PER_YEAR = 360

func advance(state: Dictionary, days: int) -> void:
	if days <= 0:
		return
	for i in range(days):
		var previous := int(state["day"])
		day_ended.emit(previous)
		var next := previous + 1
		state["day"] = next
		if next % DAYS_PER_MONTH == 0:
			month_started.emit(next)
		if next % DAYS_PER_YEAR == 0:
			year_started.emit(next)

static func date_text(day: int) -> String:
	return "承平 %d 年 %02d 月 %02d 日" % [floori(day / 360.0) + 1, floori((day % 360) / 30.0) + 1, day % 30 + 1]

static func age(day: int, birth_day: int) -> int:
	return floori((day - birth_day) / 360.0)
