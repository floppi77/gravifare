extends RefCounted
## Runde 86: Kalender-Kleinigkeiten nach der echten Ortszeit (nur Darstellung, nie Spielregeln).
##   Jahrestag (8. November, Veröffentlichung von 1.0)  → Partyhut auf dem Taxi
##   1.–26. Dezember                                    → Weihnachtsmütze auf dem Taxi
##   31. Dezember und 1. Januar                         → Feuerwerk über der Stadt im Hauptmenü
##   6. Dezember und 24.–26. Dezember                   → Schnee über allem (snow_view.gd)
##   2:00–4:59 Uhr                                      → Leuchtreklame: „SLEEP“ bzw. „ZZZ“ statt „24H“
##   Karfreitag bis Ostermontag                         → ein buntes Osterei je Level (easter_egg.gd)
##   14. Februar                                        → Fahrgäste werfen Kusshände, das Taxi errötet
##   Feiertage (holiday_for)                            → Erfolge „An … gespielt“
## Dev: --date=JJJJ-MM-TT und --hour=H geben Datum und Stunde vor (Bildschirmfotos, Tests).

# Debug-Menü „Eastereggs“: vorgeben statt nach Datum ("auto" bzw. -1 = nach Datum und Uhrzeit)
static var force_hat := "auto"           # "auto" | "none" | "party" | "xmas"
static var force_fireworks := -1          # -1 auto, 0 aus, 1 an
static var force_late := -1
static var force_snow := -1
static var force_easter := -1
static var force_valentine := -1

static func now() -> Dictionary:
	var d := Time.get_datetime_dict_from_system()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--date="):
			var p := a.substr(7).split("-")
			if p.size() == 3:
				d.year = int(p[0]); d.month = int(p[1]); d.day = int(p[2])
		elif a.begins_with("--hour="):
			d.hour = int(a.substr(7))
	return d

## "party", "xmas" oder "" für das Datum `d` ({month, day}).
static func hat_for(d: Dictionary) -> String:
	if int(d.month) == 11 and int(d.day) == 8:
		return "party"
	if int(d.month) == 12 and int(d.day) <= 26:
		return "xmas"
	return ""

static func fireworks_for(d: Dictionary) -> bool:
	return (int(d.month) == 12 and int(d.day) == 31) or (int(d.month) == 1 and int(d.day) == 1)

## Schnee an Nikolaus und den Weihnachtstagen.
static func snow_for(d: Dictionary) -> bool:
	return int(d.month) == 12 and int(d.day) in [6, 24, 25, 26]

static func snow() -> bool:
	return force_snow == 1 if force_snow >= 0 else snow_for(now())

static func late_night_for(d: Dictionary) -> bool:
	return int(d.hour) >= 2 and int(d.hour) < 5

static func hat() -> String:
	if force_hat != "auto":
		return "" if force_hat == "none" else force_hat
	return hat_for(now())

static func fireworks() -> bool:
	return force_fireworks == 1 if force_fireworks >= 0 else fireworks_for(now())

static func late_night() -> bool:
	return force_late == 1 if force_late >= 0 else late_night_for(now())

## Ostersonntag des Jahres (gregorianisch, Anonymer Algorithmus nach Meeus/Jones/Butcher): {month, day}.
static func easter_sunday(year: int) -> Dictionary:
	var a := year % 19
	var b := year / 100
	var c := year % 100
	var d := b / 4
	var e := b % 4
	var f := (b + 8) / 25
	var g := (b - f + 1) / 3
	var h := (19 * a + b - d - g + 15) % 30
	var i := c / 4
	var k := c % 4
	var l := (32 + 2 * e + 2 * i - h - k) % 7
	var m := (a + 11 * h + 22 * l) / 451
	return {"month": (h + l - 7 * m + 114) / 31, "day": (h + l - 7 * m + 114) % 31 + 1}

static func _day_number(year: int, month: int, day: int) -> int:
	return int(Time.get_unix_time_from_datetime_dict({"year": year, "month": month, "day": day, "hour": 12, "minute": 0, "second": 0}) / 86400)

## Karfreitag bis Ostermontag.
static func easter_for(d: Dictionary) -> bool:
	var es := easter_sunday(int(d.year))
	var off := _day_number(int(d.year), int(d.month), int(d.day)) - _day_number(int(d.year), int(es.month), int(es.day))
	return off >= -2 and off <= 1

static func easter() -> bool:
	return force_easter == 1 if force_easter >= 0 else easter_for(now())

static func valentine_for(d: Dictionary) -> bool:
	return int(d.month) == 2 and int(d.day) == 14

static func valentine() -> bool:
	return force_valentine == 1 if force_valentine >= 0 else valentine_for(now())

## Feiertag für die Erfolge „An … gespielt“: "nikolaus", "xmas" (24.–26.12.), "silvester", "valentine" oder "".
static func holiday_for(d: Dictionary) -> String:
	var mo := int(d.month)
	var dy := int(d.day)
	if mo == 12 and dy == 6:
		return "nikolaus"
	if mo == 12 and dy >= 24 and dy <= 26:
		return "xmas"
	if mo == 12 and dy == 31:
		return "silvester"
	if mo == 2 and dy == 14:
		return "valentine"
	return ""

static func holiday() -> String:
	return holiday_for(now())
