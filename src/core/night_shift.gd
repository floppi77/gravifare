class_name NightShift
extends RefCounted
## Nachtschicht: eine Schicht aus 9 Karten, je eine pro Sektor (1 → 9), mit festem Tages-Seed – gleiches Datum, gleiche Karten, Aufträge und
## Schwerkraft für alle. Pflichtfahrgäste ohne Zeitlimit; gewertet wird nach Wartezeit, Landungen, Hülle und knappen Vorbeiflügen, am Ende
## zählen auch die übrigen Taxis. Reine Logik ohne Autoloads (testbar).

const MAPS := 9
const START_TAXIS := 5

# Dunkelheit: Karte 1 hat 25 %, jede weitere 8 % mehr (Karte 9: 89 %). Ein dunkleres Level behält seinen eigenen Wert.
const DARK_START := 0.25
const DARK_STEP := 0.08

# Schwerkraft: Streuung um den Sollwert des Levels, auf den ersten Karten klein, auf den letzten groß.
const SPREAD_FIRST := 0.10
const SPREAD_LAST := 0.30
const MIN_FACTOR := 0.6
const HOVER_MAX := 120.0       # ~80 % der Fahrwerksdüse (150): mit ausgefahrenem Fahrwerk bleibt Schwebereserve
const FLIGHT_MAX := 195.0      # ~85 % der Hauptdüse (230): selbst in der stärksten Zone bleibt Steigreserve
const DOWN_MARGIN := 0.7       # Anteil der Bremsdüse (110), der gegen Aufwärts-Schwerkraft reichen muss

# Auftragsketten: 3 Fahrten auf Karte 1, +1 alle zwei Karten, 7 auf Karte 9 (zuletzt der Ausgangs-Fahrgast).
static func job_count(index: int) -> int:
	return 3 + index / 2

# Wertung je Karte (max. 80): Wartezeit 25, Landungen 25, Hülle 20, Vorbeiflüge bis 10.
const W_WAIT := 25.0
const W_LANDING := 25.0
const W_HULL := 20.0
const NEAR_POINTS := 2.0
const MAX_NEAR := 5
const MAP_MAX := W_WAIT + W_LANDING + W_HULL + NEAR_POINTS * MAX_NEAR
const WAIT_BASE := 5.0         # Sekunden Grundzeit je Fahrgast
const WAIT_SPEED := 90.0       # px/s: angenommene Anflugfahrt für die Wegstrecke zum Fahrgast
const LAND_MEDIUM_VY := 35.0   # bis LAND_SOFT_VY weich, bis hier mittelmäßig, darüber hart
const LAND_SCORES := [1.0, 0.6, 0.2]
const HULL_FULL := 100.0       # Hüllenschaden, bei dem die Hüllenwertung auf 0 fällt

# Gesamtwertung (max. 100): Karten-Schnitt (bis 80), 2 Punkte je übrigem Taxi (bis 10), 1 Punkt je volle 1500 übrige Credits (bis 10). Nicht geflogene Karten zählen 0.
const MAPS_POINTS := 80.0
const TAXI_POINTS := 2.0
const CREDIT_POINTS := 10.0          # höchstens
const CREDITS_PER_POINT := 1500.0    # je volle 1500 Credits am Schichtende ein Punkt
const GRADES := [["S", 90.0], ["A", 78.0], ["B", 64.0], ["C", 50.0], ["D", 36.0]]

## Level der Karte `index` (0 = Sektor 1) an diesem Datum; `ids` sind alle Level-IDs.
static func level_for(date: String, index: int, ids: Array) -> String:
	var prefix := "s%d_" % (index + 1)
	var pool: Array = ids.filter(func(id): return String(id).begins_with(prefix))
	pool.sort()
	if pool.is_empty():
		return ""
	var rng := RandomNumberGenerator.new()
	rng.seed = Daily.seed_for(date) * 977 + index * 31 + 5
	return String(pool[rng.randi() % pool.size()])

## Alle 9 Karten der Schicht.
static func plan(date: String, ids: Array) -> Array:
	var out: Array = []
	for i in MAPS:
		var id := level_for(date, i, ids)
		if id != "":
			out.append(id)
	return out

static func dark_for(index: int) -> float:
	return clampf(DARK_START + DARK_STEP * float(index), 0.0, 1.0)

## Größte Schwerkraft, bei der das Level noch sicher fliegbar bleibt: Mit ausgefahrenem Fahrwerk muss die Düse tragen, und in der stärksten
## Schwerkraftzone samt Abwind muss das Taxi noch steigen können; eine Zone mit umgekehrter Schwerkraft darf nicht stärker ziehen, als die Bremsdüse hält.
static func gravity_limit(lvl: LevelData) -> float:
	var zone_g := 1.0
	var down := 0.0
	var up_pull := 0.0
	for z in lvl.zones:
		if z.kind == "gravity":
			zone_g = maxf(zone_g, float(z.g))
			if float(z.g) < 0.0:
				up_pull = maxf(up_pull, -float(z.g))
		elif z.kind == "wind":
			down = maxf(down, (z.a as Vector2).y)
	var limit := minf(HOVER_MAX, (FLIGHT_MAX - down) / zone_g)
	if up_pull > 0.0:
		limit = minf(limit, DOWN_MARGIN * Tuning.THRUST_DOWN / up_pull)
	return limit

## Schwerkraft der Karte: Streuung um den Sollwert des Levels, nie über der Fliegbarkeitsgrenze.
static func gravity_for(lvl: LevelData, index: int, date: String) -> float:
	var rng := RandomNumberGenerator.new()
	rng.seed = Daily.seed_for(date) * 131 + index * 17 + 3
	var spread := lerpf(SPREAD_FIRST, SPREAD_LAST, float(index) / float(MAPS - 1))
	var base := lvl.gravity
	var want := base * (1.0 + rng.randf_range(-spread, spread))
	return snappedf(clampf(want, base * MIN_FACTOR, maxf(gravity_limit(lvl), base * MIN_FACTOR)), 1.0)

static func jobs_for(lvl: LevelData, index: int, date: String) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = Daily.seed_for(date) * 31 + index * 7919 + 11
	return Run.chain_jobs(lvl, job_count(index), rng)

## Schichtregeln auf ein frisch geladenes Level anwenden: Schwerkraft, Dunkelheit und Aufträge.
static func apply(lvl: LevelData, index: int, date: String) -> void:
	lvl.gravity = gravity_for(lvl, index, date)
	lvl.dark = maxf(lvl.dark, dark_for(index))
	lvl.jobs = jobs_for(lvl, index, date)

## Kennung des Pads, auf dem das Taxi startet ("" wenn es auf keinem steht).
static func start_pad_id(lvl: LevelData) -> String:
	for dy in range(0, 3):
		var p := lvl.pad_at_foot(lvl.spawn + Vector2(0, dy * Tuning.TILE))
		if not p.is_empty():
			return String(p.id)
	return ""

## Geplante Flugstrecke (px) vom Pad `from_id` (leer = Startpunkt) zum Abholpad `to_id`.
static func leg_estimate(lvl: LevelData, from_id: String, to_id: String) -> float:
	if from_id == "" or not lvl.pads.has(from_id):
		from_id = start_pad_id(lvl)
	if from_id == "" or from_id == to_id or not lvl.pads.has(to_id):
		return 0.0
	return LevelMetrics.leg_length(lvl, from_id, to_id)

## Großzügigkeit der Wartezeit nach Sektor: Sektor 1 = 1,0, jeder weitere +6 % (Sektor 9 = 1,48) – in den späteren Sektoren sind die Fahrgäste schwerer zu erreichen.
const WAIT_SECTOR_STEP := 0.06

static func sector_factor(sector: int) -> float:
	return 1.0 + WAIT_SECTOR_STEP * float(clampi(sector, 1, MAPS) - 1)

## Wartezeit-Wertung 0..1: bis zur Richtzeit (Grundzeit + Weg, mal Sektorfaktor) voll, ab dem Zweifachen plus 6 s (mal Faktor) null.
static func wait_score(wait: float, leg: float, sector := 1) -> float:
	var f := sector_factor(sector)
	var ideal := (WAIT_BASE + leg / WAIT_SPEED) * f
	var worst := ideal * 2.0 + 6.0 * f
	return clampf(1.0 - (wait - ideal) / (worst - ideal), 0.0, 1.0)

## 0 = weich, 1 = mittelmäßig, 2 = hart (nach Sinkgeschwindigkeit beim Aufsetzen).
static func landing_class(vy: float) -> int:
	if vy <= Tuning.LAND_SOFT_VY:
		return 0
	return 1 if vy <= LAND_MEDIUM_VY else 2

## Wertung einer Karte aus den Zählwerten von `Run.shift_stats()`:
## {jobs, sector, waits: [{job, wait, leg}], landings: [{job, vy}] (Absetzen mit Fahrgast), damage, near}. Nicht beförderte Fahrgäste fehlen in den Listen und zählen 0.
static func map_result(stats: Dictionary) -> Dictionary:
	var n := maxi(1, int(stats.get("jobs", 1)))
	var wsum := 0.0
	var wait_total := 0.0
	for w in stats.get("waits", []):
		wsum += wait_score(float(w.wait), float(w.leg), int(stats.get("sector", 1)))
		wait_total += float(w.wait)
	var lsum := 0.0
	var counts := [0, 0, 0]
	for l in stats.get("landings", []):
		var c := landing_class(float(l.vy))
		counts[c] += 1
		lsum += float(LAND_SCORES[c])
	var expected_landings := maxi(1, n - 1)           # nur Landungen mit Fahrgast an Bord: eine Absetzung je Fahrt (der Ausgangs-Fahrgast fliegt durchs Tor)
	var waits_n := (stats.get("waits", []) as Array).size()
	var wait_part := clampf(wsum / float(n), 0.0, 1.0)
	var landing_part := clampf(lsum / float(expected_landings), 0.0, 1.0)
	var hull_part := 1.0 - clampf(float(stats.get("damage", 0.0)) / HULL_FULL, 0.0, 1.0)
	var near := mini(int(stats.get("near", 0)), MAX_NEAR)
	var bonus := float(near) * NEAR_POINTS
	var score := W_WAIT * wait_part + W_LANDING * landing_part + W_HULL * hull_part + bonus
	return {
		"score": score, "wait": wait_part, "landing": landing_part, "hull": hull_part, "bonus": bonus, "near": near,
		"soft": counts[0], "medium": counts[1], "hard": counts[2], "avg_wait": wait_total / float(maxi(1, waits_n)),
		"jobs": n, "carried": waits_n, "damage": float(stats.get("damage", 0.0)),
	}

## Gesamtwertung: `maps` sind die Ergebnisse der geflogenen Karten (weniger als 9 = abgebrochen), `taxis` die übrigen Taxis,
## `credits` das Guthaben am Schichtende.
static func final_result(maps: Array, taxis: int, credits := 0.0) -> Dictionary:
	var sum := 0.0
	for m in maps:
		sum += float(m.score)
	var avg := sum / float(MAPS)
	var total_time := 0.0
	for m in maps:
		total_time += float(m.get("time", 0.0))
	var map_pts := avg / MAP_MAX * MAPS_POINTS
	var taxi_pts := TAXI_POINTS * float(clampi(taxis, 0, START_TAXIS))
	var credit_pts := minf(CREDIT_POINTS, floorf(maxf(0.0, credits) / CREDITS_PER_POINT))
	var score := clampf(map_pts + taxi_pts + credit_pts, 0.0, 100.0)
	return {"score": score, "grade": grade(score), "taxis": taxis, "maps": maps.size(), "average": avg, "credits": credits,
		"map_points": map_pts, "taxi_points": taxi_pts, "credit_points": credit_pts, "total_time": total_time}

## Dauer als „m:ss“, ab einer Stunde „h:mm:ss“.
static func format_time(seconds: float) -> String:
	var s := maxi(0, int(round(seconds)))
	if s >= 3600:
		return "%d:%02d:%02d" % [s / 3600, (s / 60) % 60, s % 60]
	return "%d:%02d" % [s / 60, s % 60]

## Datum und Uhrzeit für die Auswertung: deutsch „08.11.2026, 14:32 Uhr“ (24 h), englisch „11/08/2026, 2:32 PM“ (12 h). `date` ist „JJJJ-MM-TT“.
static func format_stamp(date: String, hour: int, minute: int, lang: String) -> String:
	var p := date.split("-")
	if p.size() != 3:
		return date
	if lang == "en":
		var h12 := hour % 12
		if h12 == 0:
			h12 = 12
		return "%s/%s/%s, %d:%02d %s" % [p[1], p[2], p[0], h12, minute, "AM" if hour < 12 else "PM"]
	return "%s.%s.%s, %02d:%02d Uhr" % [p[2], p[1], p[0], hour, minute]

static func grade(score: float) -> String:
	for g in GRADES:
		if score >= float(g[1]):
			return String(g[0])
	return "E"
