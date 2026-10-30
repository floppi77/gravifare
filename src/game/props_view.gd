extends Node2D
## Dekoration und Akteure über den Tiles: Pads mit Baken, Wartebereich-Unterstände, Ausgangstor,
## Fahrgäste mit Laufanimation und Ruf-Sprechblase. Läuft ungelit, damit Spielelemente stets lesbar bleiben.

const T := Tuning.TILE
const PX := 1.0 / 3.0
const GATE_INNER := Rect2(10.0 / 3.0, 10.0 / 3.0, 172.0 / 3.0, 76.0 / 3.0)
const LEAF_W := 86.0 / 3.0

var level: LevelData
var run: Run
var pass_tex: Texture2D = preload("res://assets/art/passengers.png")
var shelter_tex: Texture2D = preload("res://assets/art/shelter.png")
var gate_frame: Texture2D = preload("res://assets/art/gate_frame.png")
var leaf_l: Texture2D = preload("res://assets/art/gate_leaf_l.png")
var leaf_r: Texture2D = preload("res://assets/art/gate_leaf_r.png")
var t := 0.0
var door := 0.0                       # 0 = zu, 1 = offen (animiert)
var door_override := -1.0             # >= 0: Torstellung von außen vorgeben (Taxi-Anflug)

func setup(r: Run) -> void:
	run = r
	level = r.level
	door = 1.0 if r.exit_open else 0.0
	queue_redraw()

func _process(delta: float) -> void:
	t += delta
	if door_override >= 0.0:
		door = door_override
	elif run != null:
		door = move_toward(door, 1.0 if run.exit_open else 0.0, delta * 0.9)
	queue_redraw()

func _draw() -> void:
	if level == null:
		return
	_draw_pads()
	_draw_gate()
	_draw_actors()
	_draw_taxi_shadow()

func _draw_pads() -> void:
	var font := ThemeDB.fallback_font
	var target := run.target_pad()
	for id in level.pads:
		var p: Dictionary = level.pads[id]
		var cxm: float = p.center
		var y: float = p.row * T
		var is_target: bool = id == target
		var col := Color("#35e0d2") if not p.fuel else Color("#ffa530")
		# Wartebereich-Unterstand, Pfosten mit Signalbaken nur am freien Ende
		var shelter: Rect2 = p.get("shelter", Rect2())
		if shelter.size.x > 0.0:
			draw_texture_rect(shelter_tex, shelter, false)
			var rx := shelter.get_center().x
			draw_rect(Rect2(rx - 1.5, shelter.position.y - 2.0, 3, 2), col if (int(t * 3.0) % 2 == 0 or is_target) else col.darkened(0.6))
		var poles: Array = [p.x0 + 2.0, p.x1 - 3.0]
		if shelter.size.x > 0.0:
			poles = [p.x1 - 3.0] if p.side < 0 else [p.x0 + 2.0]
		for x in poles:
			draw_rect(Rect2(x, y - 14, 1, 14), Color("#0c0f24"))
			draw_rect(Rect2(x + PX, y - 14, PX * 2, 14), Color("#4a5596"))
			var on := int(t * 3.0 + x) % 2 == 0 or is_target
			draw_rect(Rect2(x - PX, y - 16, 1 + PX * 2, 2), col if on else col.darkened(0.6))
		# Nummernschild
		var lw := 14.0
		draw_rect(Rect2(cxm - lw / 2.0, y - 15, lw, 11), Color("#0c0f24"))
		draw_rect(Rect2(cxm - lw / 2.0 + PX * 2, y - 15 + PX * 2, lw - PX * 4, 11 - PX * 4), col.darkened(0.6))
		draw_string(font, Vector2(cxm - lw / 2.0, y - 6.2), tr("PAD_FUEL") if p.fuel else id, HORIZONTAL_ALIGNMENT_CENTER, lw, 9, col.lightened(0.6))
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

func _actor_frame(a: PassengerActor) -> int:
	if a.is_walking():
		return 4 + int(a.walked / 2.2) % 6
	if a.wave_t > 0.0:
		return 2 + int(a.age * 5.0) % 2
	return int(a.age * 1.4) % 2

func _draw_actor(a: PassengerActor) -> void:
	if not a.is_visible():
		return
	var pos := a.world_pos()
	var col := Color(1, 1, 1, a.fade)
	draw_set_transform(Vector2(pos.x, 0), 0.0, Vector2(a.facing if a.is_walking() else 1.0, 1.0))
	draw_texture_rect_region(pass_tex, Rect2(-4, pos.y - 12, 8, 12), Rect2(_actor_frame(a) * 24, a.look * 36, 24, 36), col)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if a.wave_t > 0.0:
		var bx := pos.x + 5.0
		var by := pos.y - 22.0 - sin(t * 8.0)
		draw_rect(Rect2(bx - 3, by - 3, 6, 8), Color("#0c0f24"))
		draw_rect(Rect2(bx - 3 + PX * 2, by - 3 + PX * 2, 6 - PX * 4, 8 - PX * 4), Color("#ffe14a"))
		draw_string(ThemeDB.fallback_font, Vector2(bx - 3, by + 4), "!", HORIZONTAL_ALIGNMENT_CENTER, 6, 9, Color("#0c0f24"))

func _draw_actors() -> void:
	for l in run.leavers:
		_draw_actor(l)
	if run.actor != null:
		_draw_actor(run.actor)

## Weicher Kontaktschatten des Taxis auf der Fläche darunter: wird mit der Höhe kleiner und blasser.
func _draw_taxi_shadow() -> void:
	var s := run.sim
	if s.state == TaxiSim.State.DESTROYED:
		return
	var y := s.pos.y + 8.0
	var gy := -1.0
	while y < s.pos.y + 90.0:
		if level.is_solid_at(Vector2(s.pos.x, y)):
			gy = floorf(y / T) * T
			break
		y += 2.0
	if gy < 0.0:
		return
	var h := clampf((gy - (s.pos.y + 10.0)) / 80.0, 0.0, 1.0)
	var w := lerpf(26.0, 12.0, h)
	var a := lerpf(0.5, 0.08, h)
	var cx := s.pos.x
	for i in 3:
		var f := 1.0 - i * 0.28
		draw_rect(Rect2(cx - w * f * 0.5, gy - 1.3 + i * 0.45, w * f, 1.2), Color(0.02, 0.02, 0.09, a * (0.5 + i * 0.25)))
