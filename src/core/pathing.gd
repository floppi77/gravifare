class_name Pathing
extends RefCounted
## Statische Pfadplanung für Bot und Level-Metrik: BFS über ein 8-px-Raster mit Sicherheitsrand um die
## Hülle, danach Sichtlinien-Glättung. `margin` = zusätzlicher Abstand zu Wänden in Pixeln.

static func free_at(level: LevelData, p: Vector2, margin: float) -> bool:
	var prev := level.doors_ignore
	var prev_m := level.movers_ignore
	level.doors_ignore = true            # Planung: bewegliche Tore gelten als offen (der Bot wartet vor geschlossenen)
	level.movers_ignore = true           # … Trümmer/Schieber/Plattformen werden reaktiv umflogen
	var hit := level.box_hits_solid(p, Tuning.HULL_HALF + Vector2(margin, margin))
	level.doors_ignore = prev
	level.movers_ignore = prev_m
	var half := Tuning.HULL_HALF + Vector2(margin, margin)
	return not hit and not level.pad_sweeps_hit(p, half) and not level.heat_hit_box(p, half) and not (level.pump_aware and level.pumps_hit_box(p, half))

static func line_free(level: LevelData, a: Vector2, b: Vector2, margin: float) -> bool:
	var n := int(ceil(a.distance_to(b) / 3.0))
	for i in range(0, n + 1):
		if not free_at(level, a.lerp(b, float(i) / maxf(n, 1)), margin):
			return false
	return true

## Wegpunkte von `from` nach `to`; leer, wenn es bei diesem Sicherheitsrand keinen Weg gibt.
static func plan(level: LevelData, from: Vector2, to: Vector2, margin: float) -> Array[Vector2]:
	var res: Array[Vector2] = []
	if line_free(level, from, to, margin):
		res.append(to)
		return res
	var step := 8.0
	var cols := int(level.width * Tuning.TILE / step)
	var rows := int(level.height * Tuning.TILE / step)
	var s := Vector2i(int(from.x / step), int(from.y / step))
	var g := Vector2i(int(to.x / step), int(to.y / step))
	var prev := {}
	var q: Array[Vector2i] = [s]
	prev[s] = s
	var found := false
	var qi := 0
	while qi < q.size():
		var c := q[qi]
		qi += 1
		if c == g:
			found = true
			break
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = c + d
			if n.x < 0 or n.y < 0 or n.x >= cols or n.y >= rows or prev.has(n):
				continue
			var wp := Vector2(n.x * step + step * 0.5, n.y * step + step * 0.5)
			if n != g and not free_at(level, wp, margin):
				continue
			prev[n] = c
			q.append(n)
	if not found:
		return res
	var cells: Array[Vector2] = []
	var cur := g
	while cur != s:
		cells.push_front(Vector2(cur.x * step + step * 0.5, cur.y * step + step * 0.5))
		cur = prev[cur]
	if cells.is_empty():                 # Start und Ziel liegen in derselben Rasterzelle: kein Umweg nötig
		res.append(to)
		return res
	var anchor := from
	var i := 0
	while i < cells.size():
		var far := i
		for j in range(cells.size() - 1, i - 1, -1):
			if line_free(level, anchor, cells[j], margin):
				far = j
				break
		res.append(cells[far])
		anchor = cells[far]
		i = far + 1
	res[res.size() - 1] = to
	return res

static func path_length(from: Vector2, pts: Array[Vector2]) -> float:
	var len := 0.0
	var cur := from
	for p in pts:
		len += cur.distance_to(p)
		cur = p
	return len

## Schwebepunkt über einem Pad (höchstens 56 px, bei niedriger Decke tiefer).
static func hover_point(level: LevelData, pad: Dictionary, margin: float) -> Vector2:
	for h in [56.0, 48.0, 40.0, 32.0]:
		var p := Vector2(float(pad.get("land_mid", pad.center)), pad.row * Tuning.TILE - h)
		if free_at(level, p, margin):
			return p
	return Vector2(float(pad.get("land_mid", pad.center)), pad.row * Tuning.TILE - 32.0)

static func exit_goal(level: LevelData) -> Vector2:
	return level.exit_rect().get_center()

## Anflugpunkt unter dem Tor (für die Metrik: das Tor selbst ist nur 32 px hoch und würde den Korridor künstlich begrenzen).
## `depth`: Abstand unter der Torkante. Die Richtzeiten-Metrik nimmt 60 px; die Lösbarkeitsprüfung der Level-Werkstatt nur 24 px (`GATE_FREE_DEPTH`):
## Zwei freie Felder unter dem Tor genügen, dahinter dürfen Fels und Dornen anschließen.
const GATE_FREE_DEPTH := 24.0

static func gate_approach(level: LevelData, depth := 60.0) -> Vector2:
	var r := level.exit_rect()
	return Vector2(r.get_center().x, r.end.y + depth)

## Einflug-Pfad für den Levelwechsel: aus dem Tor in der Decke, frei von Hindernissen, bis auf die Startplattform.
## Rückgabe: Polylinie (Chaikin-geglättet, sofern die Glättung frei bleibt). `landing` = Landeposition des Taxis.
static func arrival_path(level: LevelData, landing: Vector2) -> PackedVector2Array:
	var was_open := level.exit_open
	level.exit_open = true
	var start := level.exit_rect().get_center() + Vector2(0, 4)
	var pad := level.pad_at_foot(Vector2(landing.x, landing.y + Tuning.HULL_HALF.y + Tuning.GEAR_LEN + 2.0))
	var hover := Vector2(landing.x, landing.y - 32.0) if pad.is_empty() else hover_point(level, pad, 8.0)
	if not free_at(level, hover, 0.0):       # niedrige Decke (Dornen/Fels dicht über der Plattform): so tief schweben, wie die Hülle frei bleibt
		for h in [24.0, 16.0, 8.0]:
			var lower := Vector2(hover.x, landing.y - h)
			if free_at(level, lower, 0.0):
				hover = lower
				break
	var pts: Array[Vector2] = [start, _arrival_gate_point(level, start)]
	for m in [10.0, 8.0, 6.0, 4.0, 2.0]:
		var p := plan(level, pts[1], hover, m)
		if not p.is_empty():
			pts.append_array(p)
			break
	if pts.size() == 2:
		pts.append(hover)
	pts.append(landing)
	var raw := PackedVector2Array(pts)
	var smooth := raw
	for it in 2:
		var nxt := PackedVector2Array([smooth[0]])
		for i in range(smooth.size() - 1):
			nxt.append(smooth[i].lerp(smooth[i + 1], 0.25))
			nxt.append(smooth[i].lerp(smooth[i + 1], 0.75))
		nxt.append(smooth[smooth.size() - 1])
		smooth = nxt
	var ok := true
	for i in range(2, smooth.size() - 1):     # ab dem Anflugpunkt: Hülle darf nirgends anstoßen
		var n := int(ceil(smooth[i].distance_to(smooth[i + 1]) / 3.0))
		for k in range(n + 1):
			if not free_at(level, smooth[i].lerp(smooth[i + 1], float(k) / maxf(n, 1)), 1.5):     # kleiner Rand: die Glättung schneidet sonst Ecken um Bruchteile eines Pixels
				ok = false
	level.exit_open = was_open
	return smooth if ok else raw

## Erster Wegpunkt unter dem Tor: 60 px unter der Torkante, wenn die Strecke dorthin frei ist; sonst näher am Tor (Fels oder Dornen
## direkt unter dem Tor), damit die Planung ab dort seitlich um das Hindernis herum fliegt statt durch es hindurch.
static func _arrival_gate_point(level: LevelData, start: Vector2) -> Vector2:
	for depth in [60.0, 44.0, 32.0, 24.0, 16.0]:
		var p := gate_approach(level, depth)
		if line_free(level, start, p, 2.0):
			return p
	return gate_approach(level, 16.0)

## Punkt bei Anteil `e` (0..1) der Gesamtlänge der Polylinie.
static func sample_path(path: PackedVector2Array, e: float) -> Vector2:
	var total := 0.0
	for i in range(path.size() - 1):
		total += path[i].distance_to(path[i + 1])
	var want := clampf(e, 0.0, 1.0) * total
	for i in range(path.size() - 1):
		var d := path[i].distance_to(path[i + 1])
		if want <= d or i == path.size() - 2:
			return path[i].lerp(path[i + 1], clampf(want / maxf(d, 0.0001), 0.0, 1.0))
		want -= d
	return path[path.size() - 1]
