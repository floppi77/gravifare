class_name LevelMetrics
extends RefCounted
## Objektive Schwierigkeitsmetrik je Level. Grundlage für den Test „Schwierigkeit steigt von Level 1 bis 99 an“.
##
## Komponenten (alle aus dem Layout/den Aufträgen, nicht geschätzt):
##   clearance  engster Flugkorridor: größter Sicherheitsrand (px) um die Hülle, bei dem die komplette
##              Route (Start, alle Abholungen/Ziele, Ausgang) noch planbar ist. Kleiner = schwerer.
##   route_len  Streckenlänge der Route bei kleinem Rand (px)
##   jobs       Anzahl Aufträge (inkl. Ausgangs-Fahrgast)
##   min_window kleinstes freies Landefenster eines Passagierpads (px): Padbreite minus Unterstand/Fahrgast-Abstand
##   hazards    Anzahl gefährlicher Elemente (Dornen; später bewegte Gefahren)
##   mechanics  im Level-JSON deklarierte Spielmechaniken (z. B. "spikes", "pump"); jede zählt als Neuigkeit
## score = 40·eng + 25·Länge + 15·Aufträge + 10·Pad + 10·Gefahren + 5·Mechaniken. Länge, Aufträge, Gefahren und
## Mechaniken sind nach oben offen (Länge bis 2, Aufträge bis 1,5, Gefahren bis 3, Mechaniken bis 12), damit
## die Rangfolge bis Level 99 nicht an eine Obergrenze von 100 stößt.

## Ab Sektor 6 kommt ein Sektorzuschlag dazu: Gefahren, Mechaniken und Länge sind in Sektor 3–5 an ihren Obergrenzen angekommen
## (Gefahren 3,0 · Mechaniken 12), die Folge steigt ab dort je Sektor neu an. Der Zuschlag steht für das, was Spielende aus den
## früheren Sektoren beherrschen müssen.
const SECTOR_BONUS_FROM := 5
const SECTOR_BONUS := 32.0
const FINAL_SECTOR_BONUS := 12.0     # Sektor 9 ist nur in den letzten drei Leveln dunkel: Ausgleich für den fehlenden Dunkelheit-Anteil

const MAX_MARGIN := 48.0
const STEP := 4.0
static var _leg_cache := {}

## Streckenzuschlag für eine Fahrt von Pad `from_id` nach Pad `to_id` (oder "exit"): 1,0 … 1,38.
## Länge der Flugroute, engster Korridor entlang der Route und Größe des Ziel-Landefensters (alles aus dem Layout).
static func leg_mult(lvl: LevelData, from_id: String, to_id: String) -> float:
	var key := "%s:%s>%s" % [lvl.id, from_id, to_id]
	if _leg_cache.has(key):
		return _leg_cache[key]
	var was_open := lvl.exit_open
	lvl.exit_open = true
	var a := Pathing.hover_point(lvl, lvl.pads[from_id], 8.0)
	var b: Vector2 = Pathing.gate_approach(lvl) if to_id == "exit" else Pathing.hover_point(lvl, lvl.pads[to_id], 8.0)
	var clearance := 8.0
	var length := a.distance_to(b)
	for m in [40.0, 32.0, 24.0, 16.0, 8.0]:
		var path := Pathing.plan(lvl, a, b, m)
		if not path.is_empty():
			clearance = m
			length = Pathing.path_length(a, path)
			break
	var win_n := 0.0
	if to_id != "exit":
		win_n = clampf((84.0 - float(lvl.pads[to_id].land_window)) / 64.0, 0.0, 1.0)
	var mult := 1.0 + Tuning.DIST_BONUS_LEN * clampf(length / 900.0, 0.0, 1.0) \
		+ Tuning.DIST_BONUS_NARROW * clampf((40.0 - clearance) / 32.0, 0.0, 1.0) + Tuning.DIST_BONUS_WINDOW * win_n
	lvl.exit_open = was_open
	_leg_cache[key] = mult
	return mult


## Geplante Flugstrecke (px) einer Fahrt von Pad `from_id` nach Pad `to_id` bzw. "exit" (Planung mit Sicherheitsrand 8 px).
static func leg_length(lvl: LevelData, from_id: String, to_id: String) -> float:
	var key := "len:%s:%s>%s" % [lvl.id, from_id, to_id]
	if _leg_cache.has(key):
		return _leg_cache[key]
	var was_open := lvl.exit_open
	lvl.exit_open = true
	var a := Pathing.hover_point(lvl, lvl.pads[from_id], 8.0)
	var b: Vector2 = Pathing.gate_approach(lvl) if to_id == "exit" else Pathing.hover_point(lvl, lvl.pads[to_id], 8.0)
	var length := a.distance_to(b)
	for m in [16.0, 8.0, 4.0]:
		var path := Pathing.plan(lvl, a, b, m)
		if not path.is_empty():
			length = Pathing.path_length(a, path)
			break
	lvl.exit_open = was_open
	_leg_cache[key] = length
	return length

static func analyze(lvl: LevelData) -> Dictionary:
	var was_open := lvl.exit_open
	lvl.exit_open = true         # Tor für die Planung passierbar
	var legs: Array = []
	var cur := _start_point(lvl)
	for job in lvl.jobs:
		var a := Pathing.hover_point(lvl, lvl.pads[String(job.from)], 8.0)
		legs.append([cur, a])
		var b: Vector2
		if String(job.to) == "exit":
			b = Pathing.gate_approach(lvl)
		else:
			b = Pathing.hover_point(lvl, lvl.pads[String(job.to)], 8.0)
		legs.append([a, b])
		cur = b
	if lvl.jobs.is_empty() or String(lvl.jobs[lvl.jobs.size() - 1].to) != "exit":
		legs.append([cur, Pathing.gate_approach(lvl)])
	var clearance := 0.0
	var m := MAX_MARGIN
	while m >= STEP:
		var ok := true
		for leg in legs:
			if Pathing.plan(lvl, leg[0], leg[1], m).is_empty():
				ok = false
				break
		if ok:
			clearance = m
			break
		m -= STEP
	var route_len := 0.0
	if clearance > 0.0:
		for leg in legs:
			route_len += Pathing.path_length(leg[0], Pathing.plan(lvl, leg[0], leg[1], minf(clearance, 8.0)))
	var min_pad := 1e9
	for id in lvl.pads:
		if lvl.is_passenger_pad(id):
			min_pad = minf(min_pad, lvl.pads[id].land_window)
	var hazards := 0
	for row in lvl.rows:
		hazards += String(row).count("^")
	for mv in lvl.movers:
		hazards += 2 if mv.kind == "pad" else (4 if mv.kind == "slider" else 3)       # bewegliche Hindernisse zählen als Gefahr (Meteoriten wie Trümmer)
	for z in lvl.zones:
		hazards += 4 if z.kind == "heat" else 2          # Zonen (Strömung, Magnet, Schwerkraft) zählen wie Hindernisse
	lvl.exit_open = was_open
	var eng := clampf((MAX_MARGIN - clearance) / (MAX_MARGIN - STEP), 0.0, 1.0)
	var length := clampf(route_len / 3500.0, 0.0, 2.0)
	var jobs := clampf(float(lvl.jobs.size()) / 6.0, 0.0, 1.5)
	var padn := clampf((84.0 - min_pad) / 64.0, 0.0, 1.0)
	var hz := clampf(float(hazards) / 20.0, 0.0, 3.0)
	var features := clampf(float((lvl.raw.get("mechanics", []) as Array).size()), 0.0, 12.0)
	return {
		"clearance": clearance, "route_len": route_len, "jobs": lvl.jobs.size(), "min_window": min_pad, "hazards": hazards,
		"score": 40.0 * eng + 25.0 * length + 15.0 * jobs + 10.0 * padn + 10.0 * hz + 5.0 * features + 12.0 * lvl.dark + SECTOR_BONUS * maxf(0.0, float(lvl.sector - SECTOR_BONUS_FROM)) + (FINAL_SECTOR_BONUS if lvl.sector >= 9 else 0.0),
		"solvable": clearance > 0.0,
	}

static func _start_point(lvl: LevelData) -> Vector2:
	for dy in range(0, 3):
		var pad := lvl.pad_at_foot(Vector2(lvl.spawn.x, lvl.spawn.y + dy * Tuning.TILE))
		if not pad.is_empty():
			return Pathing.hover_point(lvl, pad, 8.0)
	return lvl.spawn
