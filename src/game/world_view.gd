extends Node2D
## Zeichnet das statische Level aus dem Tile-Atlas (Texturen in 3-facher Detailauflösung),
## Pads mit Signalbaken, das Ausgangstor, Fahrgäste und Zielmarker.

const T := Tuning.TILE
const PX := 1.0 / 3.0                 # ein Bildschirmpixel bei 1080p in Welteinheiten
const GATE_INNER := Rect2(10.0 / 3.0, 10.0 / 3.0, 172.0 / 3.0, 76.0 / 3.0)
const LEAF_W := 86.0 / 3.0

var level: LevelData
var run: Run
var tiles_tex: Texture2D = preload("res://assets/art/tiles_s1.png")
var pass_tex: Texture2D = preload("res://assets/art/passengers.png")
var gate_frame: Texture2D = preload("res://assets/art/gate_frame.png")
var leaf_l: Texture2D = preload("res://assets/art/gate_leaf_l.png")
var leaf_r: Texture2D = preload("res://assets/art/gate_leaf_r.png")
var t := 0.0
var door := 0.0                       # 0 = zu, 1 = offen (animiert)

func setup(r: Run) -> void:
	run = r
	level = r.level
	door = 1.0 if r.exit_open else 0.0
	queue_redraw()

func _process(delta: float) -> void:
	t += delta
	if run != null:
		door = move_toward(door, 1.0 if run.exit_open else 0.0, delta * 0.9)
	queue_redraw()

func _hash(x: int, y: int) -> int:
	return int(absi((x * 73856093) ^ (y * 19349663))) % 4

func _tile(idx: int, cx: int, cy: int) -> void:
	draw_texture_rect_region(tiles_tex, Rect2(cx * T, cy * T, T, T), Rect2(idx * 48, 0, 48, 48))

func _deep(cx: int, cy: int) -> bool:
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			if not level.is_solid_cell(cx + dx, cy + dy):
				return false
	return true

func _draw() -> void:
	if level == null:
		return
	var edge := Color("#7f8fe0")
	var edge_hi := Color("#c4d0ff")
	var shadow := Color("#0c0f24")
	for cy in level.height:
		for cx in level.width:
			var c := level.cell(cx, cy)
			if c == "#":
				_tile(7 + _hash(cx, cy) % 3 if _deep(cx, cy) else _hash(cx, cy), cx, cy)
				var x := cx * T
				var y := cy * T
				if not level.is_solid_cell(cx, cy - 1):
					draw_rect(Rect2(x, y, T, PX * 2), edge_hi)
					draw_rect(Rect2(x, y + PX * 2, T, PX), edge)
				if not level.is_solid_cell(cx - 1, cy):
					draw_rect(Rect2(x, y, PX * 2, T), edge)
				if not level.is_solid_cell(cx + 1, cy):
					draw_rect(Rect2(x + T - PX * 2, y, PX * 2, T), shadow)
				if not level.is_solid_cell(cx, cy + 1):
					draw_rect(Rect2(x, y + T - PX * 2, T, PX * 2), shadow)
			elif c == "^":
				_tile(6, cx, cy)
			elif c == "F":
				_tile(5, cx, cy)
			elif c >= "1" and c <= "9":
				_tile(4, cx, cy)
	_draw_pads()
	_draw_gate()
	_draw_passenger()

func _draw_pads() -> void:
	var font := ThemeDB.fallback_font
	var target := run.target_pad()
	for id in level.pads:
		var p: Dictionary = level.pads[id]
		var cxm: float = p.center
		var y: float = p.row * T
		var is_target: bool = id == target
		var col := Color("#35e0d2") if not p.fuel else Color("#ffa530")
		# Pfosten mit Signalbaken
		for x in [p.x0 + 2.0, p.x1 - 3.0]:
			draw_rect(Rect2(x, y - 14, 1, 14), Color("#0c0f24"))
			draw_rect(Rect2(x + PX, y - 14, PX * 2, 14), Color("#4a5596"))
			var on := int(t * 3.0 + x) % 2 == 0 or is_target
			draw_rect(Rect2(x - PX, y - 16, 1 + PX * 2, 2), col if on else col.darkened(0.6))
		# Nummernschild
		var lw := 14.0
		draw_rect(Rect2(cxm - lw / 2.0, y - 15, lw, 11), Color("#0c0f24"))
		draw_rect(Rect2(cxm - lw / 2.0 + PX * 2, y - 15 + PX * 2, lw - PX * 4, 11 - PX * 4), col.darkened(0.6))
		draw_string(font, Vector2(cxm - lw / 2.0, y - 6.2), "F" if p.fuel else id, HORIZONTAL_ALIGNMENT_CENTER, lw, 9, col.lightened(0.6))
		if is_target:
			var pulse := 0.5 + 0.5 * sin(t * 6.0)
			var c2 := Color("#ffe14a")
			c2.a = 0.55 + 0.45 * pulse
			draw_rect(Rect2(p.x0, y - PX * 2, p.x1 - p.x0, PX * 2), c2)
			var ay: float = y - 30 - 3.0 * sin(t * 5.0)
			var tri := PackedVector2Array([Vector2(cxm - 5, ay), Vector2(cxm + 5, ay), Vector2(cxm, ay + 7)])
			draw_colored_polygon(tri, Color("#ffe14a"))
			draw_polyline(PackedVector2Array([tri[0], tri[1], tri[2], tri[0]]), Color("#0c0f24"), PX * 2)

func _draw_gate() -> void:
	if level.exit_cells.is_empty():
		return
	var r := level.exit_rect()
	var open := run.exit_open
	var inner := Rect2(r.position + GATE_INNER.position, GATE_INNER.size)
	# Innenraum: geschlossen dunkel, offen strahlend grün (stufenweise, Pixel-Art-Look)
	var depth := Color("#120a1c").lerp(Color("#bfffd8"), door)
	draw_rect(inner, depth)
	if door > 0.05:
		var bands := 6
		for i in bands:
			var f := float(i) / bands
			var c := Color("#5dff9a").lerp(Color("#eafff2"), f)
			c.a = door * (0.55 - f * 0.4)
			draw_rect(Rect2(inner.position.x, inner.position.y + inner.size.y * f, inner.size.x, inner.size.y / bands), c)
		# Leitchevrons nach oben
		for k in 3:
			var cy: float = inner.end.y - fmod(t * 14.0 + k * 9.0, 27.0)
			var cxm: float = inner.get_center().x
			var chev := PackedVector2Array([Vector2(cxm - 8, cy + 4), Vector2(cxm, cy - 2), Vector2(cxm + 8, cy + 4)])
			draw_polyline(chev, Color(0.05, 0.4, 0.2, door * 0.9), 1.5)
	# Torflügel schieben sich beim Öffnen seitlich in den Rahmen
	var d := door * LEAF_W
	var vis := LEAF_W - d
	if vis > PX:
		var lh := inner.size.y
		draw_texture_rect_region(leaf_l, Rect2(inner.position.x, inner.position.y, vis, lh), Rect2(d * 3.0, 0, vis * 3.0, lh * 3.0))
		draw_texture_rect_region(leaf_r, Rect2(inner.position.x + LEAF_W + d, inner.position.y, vis, lh), Rect2(0, 0, vis * 3.0, lh * 3.0))
	draw_texture_rect(gate_frame, r, false)
	# Statuslampen im Rahmen und Schild auf dem Deckenfels
	var blink := int(t * 3.0) % 2 == 0
	var lamp := Color("#5dff9a") if open else (Color("#ff4d6d") if blink else Color("#7a2438"))
	for x in [r.position.x + 2.0, r.end.x - 4.0]:
		draw_rect(Rect2(x, r.position.y + r.size.y * 0.5 - 2, 2, 4), lamp)
	var font := ThemeDB.fallback_font
	var cxm := r.get_center().x
	var sy := r.position.y - 13.0
	draw_rect(Rect2(cxm - 22, sy, 44, 10), Color("#0c0f24"))
	draw_rect(Rect2(cxm - 22 + PX * 2, sy + PX * 2, 44 - PX * 4, 10 - PX * 4), Color("#1a2150"))
	draw_string(font, Vector2(cxm - 22, sy + 7.8), tr("EXIT_SIGN") if open else tr("EXIT_LOCKED"), HORIZONTAL_ALIGNMENT_CENTER, 44, 8, lamp)
	if open:
		# Lichtkegel unter dem Tor
		var spill := Color("#5dff9a")
		spill.a = 0.10 + 0.04 * sin(t * 4.0)
		draw_colored_polygon(PackedVector2Array([Vector2(r.position.x + 6, r.end.y), Vector2(r.end.x - 6, r.end.y), Vector2(r.end.x + 22, r.end.y + 56), Vector2(r.position.x - 22, r.end.y + 56)]), spill)

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
		bob = floorf(absf(sin(t * 3.0)) * 2.0 * 3.0) / 3.0
	draw_texture_rect_region(pass_tex, Rect2(px - 4, py - bob, 8, 12), Rect2(look * 24, 0, 24, 36))
