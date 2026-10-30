class_name Pathing
extends RefCounted
## Statische Pfadplanung für Bot und Level-Metrik: BFS über ein 8-px-Raster mit Sicherheitsrand um die
## Hülle, danach Sichtlinien-Glättung. `margin` = zusätzlicher Abstand zu Wänden in Pixeln.

static func free_at(level: LevelData, p: Vector2, margin: float) -> bool:
	return not level.box_hits_solid(p, Tuning.HULL_HALF + Vector2(margin, margin))

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
		var p := Vector2(pad.center, pad.row * Tuning.TILE - h)
		if free_at(level, p, margin):
			return p
	return Vector2(pad.center, pad.row * Tuning.TILE - 32.0)

static func exit_goal(level: LevelData) -> Vector2:
	return level.exit_rect().get_center()

## Anflugpunkt unter dem Tor (für die Metrik: das Tor selbst ist nur 32 px hoch und würde den Korridor künstlich begrenzen).
static func gate_approach(level: LevelData) -> Vector2:
	var r := level.exit_rect()
	return Vector2(r.get_center().x, r.end.y + 60.0)
