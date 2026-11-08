class_name DayShift
extends RefCounted
## Tagschicht (früher Tagesflug): eine bereits freigespielte Karte pro Tag, immer hell, mit einer Tagesregel (je Wochentag eine andere, jede Woche neu gemischt)
## und einem Tagesziel mit Bronze, Silber und Gold. Reine Logik ohne Autoloads (testbar); `Daily` liefert Seed, Kartenwahl, Aufträge und Serie.

const RULES := ["wind", "fog", "mirror", "fuel", "glass", "rush", "tailwind"]       # Reihenfolge der ersten Woche: Mo … So
const GOALS := ["express", "precision", "clean", "profit"]
const FIRST_MONDAY := "2026-11-09"       # ab hier zählen die Wochen; davor und in der ersten Woche gilt die feste Reihenfolge oben

# Regelstärken
const WIND_ACCEL := 24.0                 # px/s² der Böen über das ganze Level (Windzonen des Levels werden um WIND_BOOST stärker)
const WIND_BOOST := 1.4
const WIND_PERIOD := 12.0
const WIND_ON := 5.0
const FOG_DENSITY := 0.9
const FUEL_CAP := 50.0                   # Fassungsvermögen des Tanks (Prozent des normalen), dauerhaft: Start, Tankstelle und neues Taxi füllen nur bis hier
const FUEL_PRICE_K := 1.6                # Spritpreise
const GLASS_DAMAGE_K := 2.2              # Schaden an der Hülle
const RUSH_PATIENCE_K := 0.55            # Geduld der Fahrgäste
const TAILWIND_GRAVITY_K := 0.6          # Schwerkraft (das Taxi schwebt, Bremsen und Landen verlangen Gefühl)
const TAILWIND_ACCEL := 14.0             # dazu leichte Böen über die ganze Karte, nur pulsierend: 2 s Böe, 3 s Pause, dann von der anderen Seite
const TAILWIND_PERIOD := 10.0
const TAILWIND_ON := 2.0

# Tagesziele: Wertung 0–150 aus dem Flug; Schwellen für Bronze / Silber / Gold. Express: 100 Punkte = 80 % des Zeitziels des Levels (das Zeitziel schafft schon der Autopilot).
const EXPRESS_REF := 0.8
const PROFIT_REF := 1.3                  # Gewinn: 100 Punkte bei 130 % des Gewinnziels (der Autopilot liegt knapp darunter)
const MEDAL_AT := {"express": [60, 85, 100], "precision": [50, 75, 95], "clean": [50, 75, 95], "profit": [60, 85, 100]}
const MEDAL_NAMES := ["", "bronze", "silver", "gold"]

# Serie und Gold belohnen mit Lackierungen und Aufklebern (data/cosmetics.json: Statistik daily_best_streak bzw. day_golds)
const REWARDS := [{"stat": "daily_best_streak", "min": 3, "item": "sun"}, {"stat": "daily_best_streak", "min": 7, "item": "sky"},
	{"stat": "day_golds", "min": 5, "item": "medal"}, {"stat": "daily_best_streak", "min": 14, "item": "platinum"}]

## Wochentag von `date` ("JJJJ-MM-TT"): 0 = Montag … 6 = Sonntag.
static func weekday(date: String) -> int:
	var d := Time.get_datetime_dict_from_datetime_string(date + "T12:00:00", true)
	return (int(d.weekday) + 6) % 7

## Tage seit dem ersten Montag (negativ davor).
static func days_since_start(date: String) -> int:
	var a := Time.get_unix_time_from_datetime_string(date + "T12:00:00")
	var b := Time.get_unix_time_from_datetime_string(FIRST_MONDAY + "T12:00:00")
	return int(floor((a - b) / 86400.0 + 0.5))

## Laufende Woche (0 = erste Woche ab dem ersten Montag, davor ebenfalls 0).
static func week_of(date: String) -> int:
	return maxi(0, int(floor(float(days_since_start(date)) / 7.0)))

## Regelreihenfolge der Woche `week`: Woche 0 wie in RULES, danach jede Woche neu gemischt – nie dieselbe Regel am selben Wochentag wie in der Vorwoche
## und nie am Montag die Regel, die der Sonntag davor hatte.
static func week_order(week: int) -> Array:
	var order: Array = RULES.duplicate()
	for w in range(1, week + 1):
		var prev := order
		var rng := RandomNumberGenerator.new()
		var tries := 0
		while true:
			rng.seed = w * 7919 + 13 + tries * 104729
			var cand: Array = RULES.duplicate()
			for i in range(cand.size() - 1, 0, -1):                         # Fisher-Yates
				var j := rng.randi() % (i + 1)
				var tmp = cand[i]
				cand[i] = cand[j]
				cand[j] = tmp
			var ok: bool = cand[0] != prev[6]
			for i in cand.size():
				if cand[i] == prev[i]:
					ok = false
			if ok:
				order = cand
				break
			tries += 1
			if tries > 500:                                                  # zur Sicherheit; praktisch nie nötig
				order = cand
				break
	return order

## Tagesregel von `date`.
static func rule_of(date: String) -> String:
	return String(week_order(week_of(date))[weekday(date)])

static func _goal_pick(date: String) -> int:
	var rng := RandomNumberGenerator.new()
	rng.seed = Daily.seed_for(date) * 53 + 9
	return rng.randi() % GOALS.size()

## Tagesziel von `date`: aus dem Datum gewürfelt, ab dem ersten Montag nie dasselbe wie am Vortag (Kette von Tag zu Tag, daher für jedes Datum eindeutig).
static func goal_of(date: String) -> String:
	var n := days_since_start(date)
	if n < 0:
		return String(GOALS[_goal_pick(date)])
	var t0 := Time.get_unix_time_from_datetime_string(FIRST_MONDAY + "T12:00:00")
	var prev := -1
	var cur := 0
	for i in range(n + 1):
		var d := Time.get_date_string_from_unix_time(int(t0) + i * 86400)
		var rng := RandomNumberGenerator.new()
		rng.seed = Daily.seed_for(d) * 53 + 9
		cur = rng.randi() % GOALS.size()
		if cur == prev:
			cur = (cur + 1 + rng.randi() % (GOALS.size() - 1)) % GOALS.size()
		prev = cur
	return String(GOALS[cur])

# --------------------------------------------------------------------------- Regeln

static func entry_fuel(rule: String) -> float:
	return fuel_cap(rule)                    # der Flug beginnt mit vollem (kleinem) Tank

## Fassungsvermögen des Tanks.
static func fuel_cap(rule: String) -> float:
	return FUEL_CAP if rule == "fuel" else Tuning.FUEL_MAX

static func patience_k(rule: String) -> float:
	return RUSH_PATIENCE_K if rule == "rush" else 1.0

## Werkstatt-Werte des Serientaxis, angepasst an die Regel (Glasdach: Hülle verträgt weniger).
static func mods(rule: String, base: Dictionary) -> Dictionary:
	var m := base.duplicate()
	if rule == "glass":
		m["damage"] = float(m.get("damage", 1.0)) * GLASS_DAMAGE_K
	return m

## Level der Tagschicht herrichten: immer hell, dazu die Regel. Gibt das Level zurück.
static func apply(lvl: LevelData, rule: String, date: String) -> LevelData:
	lvl.dark = 0.0                                   # auch Sektor 8 und alle dunklen Level sind hell
	lvl.fog = 0.0
	match rule:
		"wind":
			for z in lvl.zones:
				if z.kind == "wind":
					z["a"] = (z.a as Vector2) * WIND_BOOST
			_gusts(lvl, WIND_ACCEL, WIND_PERIOD, WIND_ON, date, 3)
		"fog":
			lvl.fog = FOG_DENSITY
		"fuel":
			lvl.fuel_price_min *= FUEL_PRICE_K
			lvl.fuel_price_max *= FUEL_PRICE_K
		"tailwind":
			lvl.gravity *= TAILWIND_GRAVITY_K
			_gusts(lvl, TAILWIND_ACCEL, TAILWIND_PERIOD, TAILWIND_ON, date, 5)
	return lvl

## Zwei Böen-Zonen über die ganze Karte, die abwechselnd von links und von rechts wehen (je `on` Sekunden im Takt `period`, dazwischen Pause); Phase aus dem Datum.
static func _gusts(lvl: LevelData, accel: float, period: float, on: float, date: String, salt: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = Daily.seed_for(date) * 17 + salt
	var ph := rng.randf_range(0.0, period)
	var w := float(lvl.width)
	var h := float(lvl.height)
	lvl._scan_zones([
		{"kind": "wind", "x": 0, "y": 0, "w": w, "h": h, "ax": accel, "ay": 0.0, "period": period, "on": on, "phase": ph},
		{"kind": "wind", "x": 0, "y": 0, "w": w, "h": h, "ax": -accel, "ay": 0.0, "period": period, "on": on, "phase": ph + period * 0.5}])

## Spiegelwelt: Das ganze Bild wird horizontal gespiegelt (Welt, Schrift, HUD); das Level selbst bleibt im Original.
static func mirrors_screen(rule: String) -> bool:
	return rule == "mirror"

# --------------------------------------------------------------------------- Tagesziel

## Wertung des Tagesziels aus den Zählwerten eines Flugs ({time, target, perfect, landings, damage, respawns, net, money_target}).
static func goal_score(goal: String, s: Dictionary) -> int:
	var v := 0.0
	match goal:
		"express":
			v = 100.0 * EXPRESS_REF * float(s.get("target", 1.0)) / maxf(float(s.get("time", 1.0)), 1.0)
		"precision":
			v = 100.0 * float(s.get("perfect", 0)) / maxf(float(s.get("landings", 1)), 1.0)
		"clean":
			v = 100.0 - float(s.get("damage", 0.0)) - 25.0 * float(s.get("respawns", 0))
		"profit":
			v = 100.0 * maxf(float(s.get("net", 0.0)), 0.0) / maxf(float(s.get("money_target", 1.0)) * PROFIT_REF, 1.0)
	return int(round(clampf(v, 0.0, 150.0)))

## Medaille (0 keine, 1 Bronze, 2 Silber, 3 Gold).
static func medal_of(goal: String, score: int) -> int:
	var at: Array = MEDAL_AT.get(goal, [50, 75, 95])
	var m := 0
	for i in at.size():
		if score >= int(at[i]):
			m = i + 1
	return m

## Nächste Belohnung, die noch nicht freigeschaltet ist: {item, stat, min, have} oder {} wenn alle erreicht sind.
static func next_reward(stats: Dictionary, unlocked: Array) -> Dictionary:
	for r in REWARDS:
		if not unlocked.has(String(r.item)):
			return {"item": r.item, "stat": r.stat, "min": r.min, "have": int(stats.get(String(r.stat), 0))}
	return {}
