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
	_draw_doors()
	_draw_movers()
	_draw_actors()
	_draw_taxi_shadow()

func _draw_pads() -> void:
	var font := Fonts.hud
	var target := run.marker_pad()
	for id in level.pads:
		var p: Dictionary = level.pads[id]
		var cxm: float = p.center
		var y: float = p.row * T
		var is_target: bool = id == target
		var col := Color("#ff6aa0") if p.life else (Color("#35e0d2") if not p.fuel else Color("#ffa530"))
		# Wartebereich-Unterstand, Pfosten mit Signalbaken nur am freien Ende
		var shelter: Rect2 = p.get("shelter", Rect2())
		if shelter.size.x > 0.0:
			draw_texture_rect(shelter_tex, shelter, false)
			var rx := shelter.get_center().x
			draw_rect(Rect2(rx - 1.5, shelter.position.y - 2.0, 3, 2), col.darkened(0.3))
		var poles: Array = [p.x0 + 2.0, p.x1 - 3.0]
		if shelter.size.x > 0.0:
			poles = [p.x1 - 3.0] if p.side < 0 else [p.x0 + 2.0]
		var label: String = tr("PAD_FUEL") if p.fuel else ("L" if p.life else id)
		for x in poles:
			draw_rect(Rect2(x, y - 18, 1, 18), Color("#0c0f24"))
			draw_rect(Rect2(x + PX, y - 18, PX * 2, 18), Color("#4a5596"))
			# Dreieckiger Wimpel mit der Plattformzahl, weht leicht und zeigt zur Padmitte
			var dir := 1.0 if x < cxm else -1.0
			var top := y - 19.0
			var tip := Vector2(x + 0.5 + dir * 19.0, top + 6.5 + sin(t * 3.0 + x) * 0.9)
			var tri := PackedVector2Array([Vector2(x + 0.5, top), Vector2(x + 0.5, top + 13.0), tip])
			var fc := col.darkened(0.1)
			if is_target:
				fc = Color("#ffe14a").lerp(col, 0.5 - 0.5 * sin(t * 6.0))
			draw_colored_polygon(tri, fc)
			draw_polyline(PackedVector2Array([tri[0], tri[1], tri[2], tri[0]]), Color("#0c0f24"), PX * 2)
			var tx: float = x + 1.0 if dir > 0.0 else x - 9.0
			draw_string(font, Vector2(tx, top + 8.8), label, HORIZONTAL_ALIGNMENT_CENTER, 8, 7, Color("#0c0f24"))
		if p.life:
			_draw_life_sign(cxm, y, run.lives >= Tuning.MAX_LIVES, run.money >= Tuning.LIFE_PRICE)
		if is_target:
			var pulse := 0.5 + 0.5 * sin(t * 6.0)
			var c2 := Color("#ffe14a")
			c2.a = 0.55 + 0.45 * pulse
			draw_rect(Rect2(p.x0, y - PX * 2, p.x1 - p.x0, PX * 2), c2)
			var ay: float = y - 30 - 3.0 * sin(t * 5.0)
			var tri := PackedVector2Array([Vector2(cxm - 5, ay), Vector2(cxm + 5, ay), Vector2(cxm, ay + 7)])
			draw_colored_polygon(tri, Color("#ffe14a"))
			draw_polyline(PackedVector2Array([tri[0], tri[1], tri[2], tri[0]]), Color("#0c0f24"), PX * 2)

## Bewegliche Tore (Schleusen): geschlossen = Schott mit Warnstreifen und roter Lampe, offen = grüner Rahmen,
## kurz vor dem Schließen blinkt der Rahmen gelb.
func _draw_doors() -> void:
	if level == null or not level.has_doors():
		return
	for ch in level.doors:
		var d: Dictionary = level.doors[ch]
		var open := level.door_is_open(ch, level.clock)
		var ttc := level.door_time_to_close(ch, level.clock)
		var warn := open and ttc > 0.0 and ttc < 1.3 and int(t * 8.0) % 2 == 0
		for c in d.cells:
			var r := Rect2(c.x * T, c.y * T, T, T)
			if open:
				var rc := Color("#ffd24a") if warn else Color(0.36, 1.0, 0.6, 0.55)
				draw_rect(r.grow(-0.6), rc, false, 0.8)
			else:
				draw_rect(r, Color("#161c45"))
				for i in 4:
					var yy := r.position.y + 1.5 + i * 3.8
					draw_rect(Rect2(r.position.x + 1.0, yy, T - 2.0, 1.8), Color("#ffc23a") if i % 2 == 0 else Color("#0c0f24"))
				draw_rect(r.grow(-0.4), Color("#7f8fe0"), false, 0.8)
				draw_rect(Rect2(r.position.x + T * 0.5 - 1.0, r.position.y + T * 0.5 - 1.0, 2.0, 2.0), Color("#ff4d6d") if int(t * 3.0) % 2 == 0 else Color("#7a2438"))

## Bewegliche Hindernisse: Trümmer (zerklüfteter Brocken mit orangem Warnrand), Schieber (Block mit Warnstreifen) und
## fahrende Landeplattformen (Platte auf Schiene mit leuchtender Landefläche; der Unterstand fährt mit).
func _draw_movers() -> void:
	if level == null or not level.has_movers():
		return
	for m in level.movers:
		var r: Rect2 = m.rect
		if level.movers_ignore and m.kind != "pad":
			continue                         # beim Einflug ausgeblendet
		if m.kind == "pad":
			# Schiene über den ganzen Fahrweg
			var rail_y := r.end.y + 1.0
			draw_rect(Rect2(float(m.x) - float(m.ax), rail_y, float(m.w) + 2.0 * float(m.ax), 1.5), Color("#2a3266"))
			draw_rect(r, Color("#161c45"))
			draw_rect(Rect2(r.position.x, r.position.y + 3.0, r.size.x, r.size.y - 3.0), Color("#2a3266"))
			draw_rect(Rect2(r.position.x, r.position.y, r.size.x, 3.0), Color("#35e0d2"))
			for i in int(r.size.x / 16.0):
				draw_rect(Rect2(r.position.x + 3.0 + i * 16.0, r.position.y + 9.0, 10.0, 2.0), Color("#0c0f24"))
			draw_rect(r, Color("#7f8fe0"), false, 0.8)
			continue
		var col := Color("#3b3f5e") if m.kind == "debris" else Color("#232a52")
		draw_rect(r, col)
		draw_rect(Rect2(r.position.x + 1.5, r.position.y + 1.5, r.size.x - 3.0, r.size.y - 3.0), col.lightened(0.12))
		# Nieten und Kratzer
		for i in int(maxf(r.size.x / 8.0, 1.0)):
			draw_rect(Rect2(r.position.x + 2.0 + i * 8.0, r.position.y + 2.5 + float((i * 5) % 3), 1.5, 1.5), Color("#0c0f24"))
		var warn := Color("#ffb02e") if m.kind == "debris" else Color("#ffc23a")
		draw_rect(r, warn, false, 1.0)
		if m.kind == "slider":
			var n := int(r.size.x / 6.0)
			for i in n:
				if i % 2 == 0:
					draw_rect(Rect2(r.position.x + i * 6.0, r.end.y - 3.0, 6.0, 3.0), warn)
		else:
			draw_colored_polygon(PackedVector2Array([r.position + Vector2(0, 0), r.position + Vector2(5, 0), r.position + Vector2(0, 5)]), Color("#0c0f24"))

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
	if a.state == PassengerActor.S.FALLING or a.state == PassengerActor.S.DEAD:
		_draw_falling(a, pos)
		return
	var is_extra := not run.extra_of(a).is_empty()
	var col := Color(0.72, 0.88, 1.0, a.fade * 0.8) if is_extra else Color(1, 1, 1, a.fade)       # Zusatzfahrgäste wirken blasser/bläulich
	draw_set_transform(Vector2(pos.x, 0), 0.0, Vector2(a.facing if a.is_walking() else 1.0, 1.0))
	draw_texture_rect_region(pass_tex, Rect2(-Tuning.PASS_W * 0.5, pos.y - Tuning.PASS_H, Tuning.PASS_W, Tuning.PASS_H), Rect2(_actor_frame(a) * 24, a.look * 36, 24, 36), col)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	_draw_amount(a, pos)
	var dest := run.dest_of(a)
	if a.wave_t <= 0.0 and not a.angry and dest != "" and (a.state == PassengerActor.S.WAITING or a.state == PassengerActor.S.EMERGING):
		_draw_dest_bubble(pos, dest, a.fade, run.extra_of(a).is_empty())
	if a.wave_t > 0.0 or a.angry:
		var bx := pos.x + 4.0
		var by := pos.y - 18.0 - sin(t * (14.0 if a.angry else 8.0))
		var bubble := Color("#ff4d6d") if a.angry else Color("#ffe14a")
		var label := "#!" if a.angry else "!"
		draw_rect(Rect2(bx - 4, by - 3, 8, 8), Color("#0c0f24"))
		draw_rect(Rect2(bx - 4 + PX * 2, by - 3 + PX * 2, 8 - PX * 4, 8 - PX * 4), bubble)
		draw_string(Fonts.hud, Vector2(bx - 4, by + 4), label, HORIZONTAL_ALIGNMENT_CENTER, 8, 8, Color("#0c0f24") if not a.angry else Color.WHITE)

## Kleiner goldener Stern über wartenden Pflichtfahrgästen.
func _gold_star(c: Vector2, r: float, fade: float) -> void:
	var pts := PackedVector2Array()
	for i in 10:
		var rad := r if i % 2 == 0 else r * 0.45
		var an := -PI * 0.5 + i * PI / 5.0
		pts.append(c + Vector2(cos(an), sin(an)) * rad)
	draw_colored_polygon(pts, Color(1.0, 0.82, 0.2, fade))

## Lebens-Station: Herz und Preis über der Plattform (grau, wenn voll oder zu wenig Credits).
func _draw_life_sign(cx: float, y: float, full: bool, can_pay: bool) -> void:
	var ok := not full and can_pay
	var hc := Color("#ff6aa0") if ok else Color("#7a5a70")
	var hy := y - 30.0 - (1.2 * sin(t * 3.0) if ok else 0.0)
	draw_circle(Vector2(cx - 2.2, hy), 2.6, hc)
	draw_circle(Vector2(cx + 2.2, hy), 2.6, hc)
	draw_colored_polygon(PackedVector2Array([Vector2(cx - 4.7, hy + 0.9), Vector2(cx + 4.7, hy + 0.9), Vector2(cx, hy + 6.4)]), hc)
	draw_string(Fonts.hud, Vector2(cx - 14.0, hy + 15.0), "¢%d" % int(Tuning.LIFE_PRICE) if not full else "MAX", HORIZONTAL_ALIGNMENT_CENTER, 28, 7, Color("#ffe14a") if ok else Color("#8a7a80"))

## Sprechblase mit der Zielplattform (Zahl) bzw. Pfeil nach oben für den Ausgang, nachdem das „!“ verklungen ist.
func _draw_dest_bubble(pos: Vector2, dest: String, fade: float, mandatory: bool) -> void:
	var bx := pos.x + 17.0
	var by := pos.y - 17.0 - 0.6 * sin(t * 3.0)
	var ink := Color("#0c0f24")
	draw_colored_polygon(PackedVector2Array([Vector2(bx - 5.5, by + 3.0), Vector2(bx - 3.0, by + 4.0), Vector2(bx - 8.0, by + 8.5)]), Color(ink.r, ink.g, ink.b, fade))
	var edge_c := Color(1.0, 0.82, 0.2, fade) if mandatory else Color(0.3, 0.85, 0.95, fade)
	draw_rect(Rect2(bx - 5.0, by - 5.0, 10, 10), edge_c)
	draw_rect(Rect2(bx - 5.0 + PX * 2, by - 5.0 + PX * 2, 10 - PX * 4, 10 - PX * 4), Color(1.0, 0.97, 0.8, fade) if mandatory else Color(0.9, 0.97, 1.0, fade))
	if dest == "exit":
		var g := Color(0.1, 0.55, 0.3, fade)
		draw_colored_polygon(PackedVector2Array([Vector2(bx, by - 3.2), Vector2(bx + 3.0, by + 0.2), Vector2(bx - 3.0, by + 0.2)]), g)
		draw_rect(Rect2(bx - 1.0, by + 0.2, 2, 3.0), g)
	else:
		draw_string(Fonts.hud, Vector2(bx - 5.0, by + 3.2), dest, HORIZONTAL_ALIGNMENT_CENTER, 10, 9, Color(ink.r, ink.g, ink.b, fade))

## Rausgeworfener Fahrgast: dreht sich im Fall und schreit („AAAH!“), nach dem Aufprall liegt er platt am Boden.
func _draw_falling(a: PassengerActor, pos: Vector2) -> void:
	var frame := 2 + int(a.age * 10.0) % 2
	var rot := a.age * 9.0 if a.state == PassengerActor.S.FALLING else PI * 0.5
	var col := Color(1, 1, 1, a.fade) if a.state == PassengerActor.S.FALLING else Color(0.8, 0.7, 0.7, a.fade)
	var cy := pos.y - Tuning.PASS_H * 0.5 if a.state == PassengerActor.S.FALLING else pos.y - 2.5
	draw_set_transform(Vector2(pos.x, cy), rot, Vector2.ONE)
	draw_texture_rect_region(pass_tex, Rect2(-Tuning.PASS_W * 0.5, -Tuning.PASS_H * 0.5, Tuning.PASS_W, Tuning.PASS_H), Rect2(frame * 24, a.look * 36, 24, 36), col)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if a.state == PassengerActor.S.FALLING:
		var shake := sin(t * 40.0) * 0.6
		draw_string(Fonts.hud, Vector2(pos.x - 14.0 + shake, pos.y - 16.0), tr("VOICE_SCREAM_SHORT"), HORIZONTAL_ALIGNMENT_CENTER, 28, 7, Color(1.0, 0.35, 0.4, a.fade))
	else:
		draw_rect(Rect2(pos.x - 6.0, pos.y - 1.2, 12.0, 1.6), Color(0.55, 0.1, 0.16, 0.85 * a.fade))
		draw_rect(Rect2(pos.x - 3.0, pos.y - 2.4, 6.0, 1.2), Color(0.7, 0.14, 0.2, 0.8 * a.fade))

func _draw_actors() -> void:
	for l in run.leavers:
		_draw_actor(l)
	for ex in run.extras:
		_draw_actor(ex.actor)
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
	var ex := run.extra_of(a)
	if not ex.is_empty() and a.state != PassengerActor.S.EXITING:
		value = run.extra_prospect(ex)
		factor = run.extra_factor(ex)
		if int(ex.state) == Run.ES.WAIT:                     # Geduld: schrumpfender Balken unter dem Betrag
			var frac := clampf(float(ex.patience) / float(ex.patience_max), 0.0, 1.0)
			draw_rect(Rect2(pos.x - 8.0, pos.y - 13.6, 16.0, 1.4), Color(0.04, 0.05, 0.14, 0.8 * a.fade))
			draw_rect(Rect2(pos.x - 8.0, pos.y - 13.6, 16.0 * frac, 1.4), Color("#5dff9a").lerp(Color("#ff4d6d"), 1.0 - frac))
	elif a.state == PassengerActor.S.EXITING and not a.pay_info.is_empty():
		value = a.pay_for(0.0)
		factor = a.factor_for(0.0)
	if value < 0.0:
		return
	var col := Color("#5dff9a") if factor > 1.05 else (Color("#ffe14a") if factor > 0.8 else Color("#ff8a5a"))
	col.a = a.fade
	var txt := "¢%d" % int(round(value))
	var font := Fonts.hud
	var tw := maxf(16.0, font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 7).x + 4.0)     # Betrag nie abschneiden
	var mand := run.extra_of(a).is_empty() and a == run.actor
	draw_rect(Rect2(pos.x - tw * 0.5, pos.y - 21.0, tw, 7.2), Color(0.04, 0.05, 0.14, 0.72 * a.fade))
	draw_rect(Rect2(pos.x - tw * 0.5, pos.y - 21.0, tw, 7.2), Color(1.0, 0.82, 0.2, a.fade) if mand else Color(0.3, 0.85, 0.95, 0.7 * a.fade), false, 0.7)
	if mand and (a.state == PassengerActor.S.WAITING or a.state == PassengerActor.S.EMERGING):
		_gold_star(Vector2(pos.x, pos.y - 28.0 - sin(t * 4.0) * 1.0), 3.6, a.fade)
	draw_string(font, Vector2(pos.x - tw * 0.5, pos.y - 15.2), txt, HORIZONTAL_ALIGNMENT_CENTER, tw, 7, col)

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
