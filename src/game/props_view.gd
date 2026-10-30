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
var taxi_tex: Texture2D = Cosmetics.paint_texture()
var shelter_tex: Texture2D = preload("res://assets/art/shelter.png")
var pump_base_tex: Texture2D = preload("res://assets/art/pump_base.png")
var pump_head_tex: Texture2D = preload("res://assets/art/pump_head.png")
var pump_flash := 0.0                 # kurzes Aufblitzen der Preisanzeige bei Preiswechsel
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
	pump_flash = maxf(0.0, pump_flash - delta * 2.5)
	if door_override >= 0.0:
		door = door_override
	elif run != null:
		door = move_toward(door, 1.0 if run.exit_open else 0.0, delta * 0.9)
	queue_redraw()

func _draw() -> void:
	if level == null:
		return
	_draw_pads()
	_draw_reflections()
	_draw_pumps()
	_draw_gate()
	_draw_actors()
	_draw_taxi_shadow()

func _draw_pads() -> void:
	var font := Fonts.hud
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
	var font := Fonts.hud
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
	draw_texture_rect_region(pass_tex, Rect2(-Tuning.PASS_W * 0.5, pos.y - Tuning.PASS_H, Tuning.PASS_W, Tuning.PASS_H), Rect2(_actor_frame(a) * 24, a.look * 36, 24, 36), col)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	_draw_amount(a, pos)
	if a.wave_t > 0.0 or a.angry:
		var bx := pos.x + 4.0
		var by := pos.y - 18.0 - sin(t * (14.0 if a.angry else 8.0))
		var bubble := Color("#ff4d6d") if a.angry else Color("#ffe14a")
		var label := "#!" if a.angry else "!"
		draw_rect(Rect2(bx - 4, by - 3, 8, 8), Color("#0c0f24"))
		draw_rect(Rect2(bx - 4 + PX * 2, by - 3 + PX * 2, 8 - PX * 4, 8 - PX * 4), bubble)
		draw_string(Fonts.hud, Vector2(bx - 4, by + 4), label, HORIZONTAL_ALIGNMENT_CENTER, 8, 8, Color("#0c0f24") if not a.angry else Color.WHITE)

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
	var w := lerpf(21.0, 10.0, h)
	var a := lerpf(0.5, 0.08, h)
	var cx := s.pos.x
	for i in 3:
		var f := 1.0 - i * 0.28
		draw_rect(Rect2(cx - w * f * 0.5, gy - 1.3 + i * 0.45, w * f, 1.2), Color(0.02, 0.02, 0.09, a * (0.5 + i * 0.25)))

## Betrag dauerhaft über dem Fahrgast: von seinem Erscheinen bis zum Einsteigen und vom Aussteigen bis zum Häuschen.
## Er tickt mit der Zeit herunter (Zeitfaktor); beim Aussteigen zählt die Gehzeit mehrfach.
func _draw_amount(a: PassengerActor, pos: Vector2) -> void:
	if a.angry:
		return
	var value := -1.0
	var factor := 1.0
	if a == run.actor and (a.state == PassengerActor.S.WAITING or a.state == PassengerActor.S.EMERGING or a.state == PassengerActor.S.TO_TAXI or a.state == PassengerActor.S.RETURNING):
		value = run.prospect()
		factor = run.live_factor()
	elif a.state == PassengerActor.S.EXITING and not a.pay_info.is_empty():
		value = a.pay_for(0.0)
		factor = a.factor_for(0.0)
	if value < 0.0:
		return
	var col := Color("#5dff9a") if factor > 1.05 else (Color("#ffe14a") if factor > 0.8 else Color("#ff8a5a"))
	col.a = a.fade
	var txt := "¢%d" % int(round(value))
	var font := Fonts.hud
	draw_rect(Rect2(pos.x - 8.0, pos.y - 21.0, 16.0, 7.2), Color(0.04, 0.05, 0.14, 0.72 * a.fade))
	draw_string(font, Vector2(pos.x - 8.0, pos.y - 15.2), txt, HORIZONTAL_ALIGNMENT_CENTER, 16, 7, col)

## Zapfsäule mit Preisanzeige. Der Kopf knickt mit jeder Berührung weiter ab (Stufe 1–3); nach der dritten explodiert
## die Station (Effekte in fx.gd) und bleibt als verkohlte Säule stehen.
func _draw_pumps() -> void:
	var font := Fonts.hud
	for pm in level.pumps:
		var r: Rect2 = pm.rect
		var top := r.end.y - 32.0
		var broken := run.pump_broken
		var stage := mini(run.pump_touches, 3)
		draw_texture_rect(pump_base_tex, Rect2(r.position.x, top, 16, 32), false, Color(0.32, 0.27, 0.27) if broken else Color.WHITE)
		if broken:
			return
		var rots := [0.0, 0.2, 0.55, 1.2]
		var drops := [Vector2(0, 0), Vector2(0.3, 0.2), Vector2(0.9, 1.0), Vector2(2.2, 2.6)]
		var pivot: Vector2 = Vector2(r.position.x + 8.0, top + 11.3) + drops[stage]
		var flick := 1.0 if stage < 2 else (0.55 + 0.45 * absf(sin(t * 23.0)))
		draw_set_transform(pivot, rots[stage], Vector2.ONE)
		draw_texture_rect(pump_head_tex, Rect2(-8, -11.3, 16, 12), false, Color(1, 1, 1, 1))
		# Anzeige: Preis (farbig nach Preisniveau) bzw. Fehlermeldung bei Stufe 3
		var pf := run.fuel_price()
		var span := maxf(run.level.fuel_price_max - run.level.fuel_price_min, 0.01)
		var lvl_n := (pf - run.level.fuel_price_min) / span
		var col := Color("#5dff9a") if lvl_n < 0.34 else (Color("#ffe14a") if lvl_n < 0.67 else Color("#ff6a4a"))
		var txt := "%.2f" % pf
		if stage >= 3:
			txt = "ERR"
			col = Color("#ff4d6d")
		col.a = flick
		draw_string(font, Vector2(-8, -4.1), txt, HORIZONTAL_ALIGNMENT_CENTER, 16, 6, col)
		if pump_flash > 0.0:
			draw_rect(Rect2(-5.0, -8.0, 10.0, 5.2), Color(1, 1, 1, pump_flash * 0.55))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		if stage >= 2:      # Funken am beschädigten Kopf
			var k := int(t * 18.0)
			for i in 3:
				var rx := fmod(absf(sin(float(k * 7 + i * 13))) * 9.0, 9.0)
				var ry := fmod(absf(cos(float(k * 5 + i * 11))) * 6.0, 6.0)
				if (k + i) % 3 != 0:
					draw_rect(Rect2(pivot.x - 4.5 + rx, pivot.y - 9.0 + ry, 0.9, 0.9), Color("#ffd37a"))

## Reflexionen auf den Pads: ein Glanzstreifen läuft über die Fläche, und das Taxi spiegelt sich im Metall, wenn es
## darüber schwebt (nur die unterste Kante, wird mit der Höhe blasser). Bei „Weniger Bewegung“ aus.
func _draw_reflections() -> void:
	if Settings.values.reduce_motion:
		return
	var s := run.sim
	for id in level.pads:
		var p: Dictionary = level.pads[id]
		var surf: float = p.row * T
		var w: float = p.x1 - p.x0
		var gx: float = p.x0 + fmod(t * 22.0 + float(String(id).unicode_at(0)) * 17.0, w + 30.0) - 15.0
		var x0 := clampf(gx, p.x0, p.x1)
		var x1 := clampf(gx + 12.0, p.x0, p.x1)
		if x1 > x0:
			draw_rect(Rect2(x0, surf + 0.4, x1 - x0, 1.2), Color(1, 1, 1, 0.26))
		if s.state != TaxiSim.State.DESTROYED and s.pos.x > p.x0 and s.pos.x < p.x1:
			var bottom := s.pos.y + Tuning.HULL_HALF.y + Tuning.GEAR_LEN * s.gear
			var h := surf - bottom
			if h > -1.5 and h < 46.0:
				var a := 0.34 * (1.0 - clampf(h, 0.0, 46.0) / 46.0)
				draw_set_transform(Vector2(s.pos.x, 2.0 * surf - s.pos.y), -s.tilt, Vector2(Tuning.TAXI_SCALE, -Tuning.TAXI_SCALE))
				draw_texture_rect_region(taxi_tex, Rect2(-16, -1, 32, 11), Rect2(0, 27, 96, 33), Color(0.7, 0.92, 1.0, a))
				draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
