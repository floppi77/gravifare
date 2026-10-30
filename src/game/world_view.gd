extends Node2D
## Zeichnet das statische Level aus dem Tile-Atlas, plus Pads, Fahrgäste und Zielmarker.

const T := Tuning.TILE
var level: LevelData
var run: Run
var tiles_tex: Texture2D = preload("res://assets/art/tiles_s1.png")
var pass_tex: Texture2D = preload("res://assets/art/passengers.png")
var t := 0.0

func setup(r: Run) -> void:
	run = r
	level = r.level
	queue_redraw()

func _process(delta: float) -> void:
	t += delta
	queue_redraw()

func _hash(x: int, y: int) -> int:
	return int(absi((x * 73856093) ^ (y * 19349663))) % 4

func _tile(idx: int, cx: int, cy: int) -> void:
	draw_texture_rect_region(tiles_tex, Rect2(cx * T, cy * T, T, T), Rect2(idx * 16, 0, 16, 16))

func _draw() -> void:
	if level == null:
		return
	var edge := Color("#6f7fd0")
	var edge_hi := Color("#a9b8ff")
	for cy in level.height:
		for cx in level.width:
			var c := level.cell(cx, cy)
			if c == "#":
				_tile(_hash(cx, cy), cx, cy)
				# Kantenlicht zu offenen Nachbarn
				if not level.is_solid_cell(cx, cy - 1):
					draw_rect(Rect2(cx * T, cy * T, T, 1), edge_hi)
					draw_rect(Rect2(cx * T, cy * T + 1, T, 1), edge)
				if not level.is_solid_cell(cx - 1, cy):
					draw_rect(Rect2(cx * T, cy * T, 1, T), edge)
				if not level.is_solid_cell(cx + 1, cy):
					draw_rect(Rect2(cx * T + T - 1, cy * T, 1, T), Color("#10142b"))
				if not level.is_solid_cell(cx, cy + 1):
					draw_rect(Rect2(cx * T, cy * T + T - 1, T, 1), Color("#10142b"))
			elif c == "^":
				_tile(6, cx, cy)
			elif c == "F":
				_tile(5, cx, cy)
			elif c >= "1" and c <= "9":
				_tile(4, cx, cy)
	_draw_pads()
	_draw_exit()
	_draw_passenger()

func _draw_pads() -> void:
	var font := ThemeDB.fallback_font
	var target := run.target_pad()
	for id in level.pads:
		var p: Dictionary = level.pads[id]
		var cxm: float = p.center
		var y: float = p.row * T
		var is_target: bool = id == target
		var col := Color("#2fd2c6") if not p.fuel else Color("#ff9f2e")
		# Pfosten + Nummernschild
		draw_rect(Rect2(p.x0 + 2, y - 14, 1, 14), Color("#10142b"))
		draw_rect(Rect2(p.x1 - 3, y - 14, 1, 14), Color("#10142b"))
		var lw := 12
		draw_rect(Rect2(cxm - lw / 2.0, y - 15, lw, 11), Color("#10142b"))
		draw_rect(Rect2(cxm - lw / 2.0 + 1, y - 14, lw - 2, 9), col.darkened(0.55))
		draw_string(font, Vector2(cxm - 3, y - 6), "F" if p.fuel else id, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, col.lightened(0.5))
		if is_target:
			var pulse := 0.5 + 0.5 * sin(t * 6.0)
			var c2 := Color("#ffe14a")
			c2.a = 0.5 + 0.5 * pulse
			draw_rect(Rect2(p.x0, y - 2, p.x1 - p.x0, 2), c2)
			var ay := y - 30 - 3.0 * sin(t * 5.0)
			draw_colored_polygon(PackedVector2Array([Vector2(cxm - 5, ay), Vector2(cxm + 5, ay), Vector2(cxm, ay + 7)]), Color("#ffe14a"))

func _draw_exit() -> void:
	if level.exit_cells.is_empty():
		return
	var open := run.exit_open
	var col := Color("#5dff9a") if open else Color("#e8506e")
	col.a = 0.25 + 0.15 * sin(t * 4.0) if open else 0.18
	for c in level.exit_cells:
		draw_rect(Rect2(c.x * T, c.y * T, T, T), col)
	var xs := level.exit_cells.map(func(c): return c.x)
	var ys := level.exit_cells.map(func(c): return c.y)
	var r := Rect2(xs.min() * T, ys.min() * T, (xs.max() - xs.min() + 1) * T, (ys.max() - ys.min() + 1) * T)
	var lc := Color("#5dff9a") if open else Color("#e8506e")
	draw_rect(r, lc, false, 1.0)
	draw_string(ThemeDB.fallback_font, r.position + Vector2(2, r.size.y * 0.5 + 3), "EXIT" if open else "LOCK", HORIZONTAL_ALIGNMENT_CENTER, r.size.x - 4, 9, lc)

func _draw_passenger() -> void:
	var job := run.current_job()
	if job.is_empty():
		return
	if run.phase == Run.Phase.CARRYING:
		return
	var pad: Dictionary = level.pads.get(String(job.from), {})
	if pad.is_empty():
		return
	var look := (run.job_index + 1) % 4
	var px: float = pad.center + 14.0
	var py: float = pad.row * T - 12
	var bob := 0.0
	if run.phase == Run.Phase.BOARDING:
		var k: float = run.phase_timer / Tuning.BOARD_TIME
		px = lerpf(px, pad.center, k)
	elif run.phase == Run.Phase.WAITING:
		bob = floorf(absf(sin(t * 3.0)) * 2.0)
	draw_texture_rect_region(pass_tex, Rect2(floorf(px) - 4, py - bob, 8, 12), Rect2(look * 8, 0, 8, 12))
