class_name LevelMetrics
extends RefCounted
## Objektive Schwierigkeitsmetrik je Level. Grundlage für den Test „Schwierigkeit steigt von Level 1 bis 99 an“.
##
## Komponenten (alle aus dem Layout/den Aufträgen, nicht geschätzt):
##   clearance  engster Flugkorridor: größter Sicherheitsrand (px) um die Hülle, bei dem die komplette
##              Route (Start, alle Abholungen/Ziele, Ausgang) noch planbar ist. Kleiner = schwerer.
##   route_len  Streckenlänge der Route bei kleinem Rand (px)
##   jobs       Anzahl Aufträge (inkl. Ausgangs-Fahrgast)
##   min_pad_w  schmalstes Pad (px)
##   hazards    Anzahl gefährlicher Elemente (Dornen; später bewegte Gefahren)
## score = 40·eng + 25·Länge + 15·Aufträge + 10·Pad + 10·Gefahren (jeweils auf 0..1 normiert)

const MAX_MARGIN := 48.0
const STEP := 4.0

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
		if not lvl.pads[id].fuel:
			min_pad = minf(min_pad, lvl.pads[id].x1 - lvl.pads[id].x0)
	var hazards := 0
	for row in lvl.rows:
		hazards += String(row).count("^")
	lvl.exit_open = was_open
	var eng := clampf((MAX_MARGIN - clearance) / (MAX_MARGIN - STEP), 0.0, 1.0)
	var length := clampf(route_len / 3500.0, 0.0, 1.0)
	var jobs := clampf(float(lvl.jobs.size()) / 6.0, 0.0, 1.0)
	var padn := clampf((112.0 - min_pad) / 48.0, 0.0, 1.0)
	var hz := clampf(float(hazards) / 20.0, 0.0, 1.0)
	return {
		"clearance": clearance, "route_len": route_len, "jobs": lvl.jobs.size(), "min_pad_w": min_pad, "hazards": hazards,
		"score": 40.0 * eng + 25.0 * length + 15.0 * jobs + 10.0 * padn + 10.0 * hz,
		"solvable": clearance > 0.0,
	}

static func _start_point(lvl: LevelData) -> Vector2:
	for dy in range(0, 3):
		var pad := lvl.pad_at_foot(Vector2(lvl.spawn.x, lvl.spawn.y + dy * Tuning.TILE))
		if not pad.is_empty():
			return Pathing.hover_point(lvl, pad, 8.0)
	return lvl.spawn
