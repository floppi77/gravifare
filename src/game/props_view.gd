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
	_draw_zones()
	_draw_movers()
	_draw_actors()
	_draw_taxi_shadow()
	if OS.get_cmdline_user_args().has("--debug-hitbox"):      # Dev: Kollisionsrechtecke der Mover und des Taxis
		for m in level.movers:
			draw_rect(m.rect, Color(1, 0.2, 0.2, 0.9), false, 0.6)
		draw_rect(Rect2(run.sim.pos - Tuning.HULL_HALF, Tuning.HULL_HALF * 2.0), Color(0.3, 1, 0.3, 0.9), false, 0.6)

func _draw_pads() -> void:
	var font := Fonts.hud
	var target := run.marker_pad()
	for id in level.pads:
		var p: Dictionary = level.pads[id]
		var cxm: float = p.center
		var y: float = p.row * T
		var is_target: bool = id == target
		var col := Color("#ff6aa0") if p.life else (Color("#35e0d2") if not p.fuel else Color("#ffa530"))
		if p.get("hospital", false):
			col = Color("#ff5a64")
		# Wartebereich-Unterstand, Pfosten mit Signalbaken nur am freien Ende
		var shelter: Rect2 = p.get("shelter", Rect2())
		if shelter.size.x > 0.0:
			draw_texture_rect(shelter_tex, shelter, false)
			_light_shelter(shelter, id)
			var rx := shelter.get_center().x
			draw_rect(Rect2(rx - 1.5, shelter.position.y - 2.0, 3, 2), col.darkened(0.3))
		var poles: Array = [p.x0 + 2.0, p.x1 - 3.0]
		if shelter.size.x > 0.0:
			poles = [p.x1 - 3.0] if p.side < 0 else [p.x0 + 2.0]
		var label: String = tr("PAD_FUEL") if p.fuel else ("L" if p.life else id)
		for x in poles:
			draw_rect(Rect2(x, y - 18, 1, 18), Color("#0c0f24"))
			draw_rect(Rect2(x + PX, y - 18, PX * 2, 18), Color("#4a5596"))
			# Dreieckiger Wimpel mit der Plattformzahl, weht leicht und zeigt nach außen (die Mitte gehört Fahrgast und Preisschild)
			var dir := -1.0 if x < cxm else 1.0
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
		if p.get("hospital", false):
			_draw_hospital_sign(p, y)
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
## Zonen: schwach getönte Flächen mit laufender Animation (Chevrons = Strömung, Ringe = Magnet, Pfeile = Schwerkraft).
func _draw_zones() -> void:
	if level == null or not level.has_zones():
		return
	for z in level.zones:
		var r: Rect2 = z.rect
		var on := level.zone_active(z, level.clock)
		var al := 1.0 if on else 0.25
		match String(z.kind):
			"wind":
				_draw_wind(z, on)
			"magnet":
				_draw_magnet(z, on)
			"heat":
				_draw_heat(z, on)
			"gravity":
				var heavy := float(z.g) > 1.0
				draw_rect(r, Color(0.9, 0.3, 0.9, 0.08 * al) if heavy else Color(0.4, 1.0, 0.7, 0.08 * al))
				for i in int(r.size.x / 18.0):
					var f := fmod(t * 0.5 + float(i) * 0.37, 1.0)
					var yy := r.position.y + (f if heavy else 1.0 - f) * r.size.y
					var xx := r.position.x + 9.0 + float(i) * 18.0
					var s := 3.0 if heavy else -3.0
					draw_polyline(PackedVector2Array([Vector2(xx - 3.0, yy - s), Vector2(xx, yy + s), Vector2(xx + 3.0, yy - s)]), Color(1, 1, 1, 0.35 * al), 1.0)

## Strömung als Wind: wehende Schlieren in Windrichtung (schneller bei stärkerem Wind), kleine Wirbel, Pfeilspitzen an der Austrittskante.
## Böen sind aus nur ein schwaches Flimmern und blenden vor dem Einschalten auf.
func _draw_wind(z: Dictionary, on: bool) -> void:
	var r: Rect2 = z.rect
	var dir: Vector2 = (z.a as Vector2).normalized()
	var spd := clampf((z.a as Vector2).length() / 55.0, 0.6, 1.4)
	var al := 1.0 if on else 0.14
	if float(z.period) > 0.0 and not on:
		var left := float(z.period) - fposmod(level.clock + float(z.phase), float(z.period))
		if left < 1.2:
			al = 0.14 + 0.7 * (1.0 - left / 1.2) * (0.6 + 0.4 * sin(t * 20.0))
	var horiz := absf(dir.x) > absf(dir.y)
	var along := r.size.x if horiz else r.size.y
	var across := r.size.y if horiz else r.size.x
	var sgn := (dir.x if horiz else dir.y)
	draw_rect(r, Color(0.7, 0.9, 1.0, 0.09 * al))
	var n := int(across / 4.0) + 4
	for i in n:
		var h := fmod(float(i) * 0.61803 + 0.13, 1.0)
		var h2 := fmod(float(i) * 0.37 + 0.41, 1.0)
		var lane := 2.0 + h * (across - 4.0)
		var ln := 7.0 + 9.0 * h2
		var fr := fmod(t * spd * (0.45 + 0.5 * h2) + h * 3.0, 1.0)
		var pos := fr * (along + ln) - ln
		var wob := sin(t * 3.0 + float(i) * 1.9) * 0.9
		var p0: Vector2
		var p1: Vector2
		if horiz:
			var xs := pos if sgn > 0.0 else along - pos
			p0 = r.position + Vector2(xs, lane + wob)
			p1 = p0 - Vector2(sgn * ln, 0.0)
		else:
			var ys := pos if sgn > 0.0 else along - pos
			p0 = r.position + Vector2(lane + wob, ys)
			p1 = p0 - Vector2(0.0, sgn * ln)
		# am Rand ausblenden
		var inside := r.grow(0.5)
		if level.is_solid_at(p0) or level.is_solid_at(p1):          # Wind weht nur durch Luft, nicht durch Fels
			continue
		var a0 := p0.clamp(r.position, r.end)
		var a1 := p1.clamp(r.position, r.end)
		if a0.distance_to(a1) < 1.5:
			continue
		draw_line(a1, a0, Color(0.85, 0.95, 1.0, (0.5 + 0.45 * h2) * al), 1.3)
		draw_line(a1.lerp(a0, 0.5), a0, Color(1.0, 1.0, 1.0, 0.5 * al), 1.0)
		# kleiner Wirbel am Schlierenkopf
		if i % 4 == 0 and inside.has_point(p0):
			draw_arc(p0 + dir * 2.0, 2.2, 0.0, TAU * 0.8, 10, Color(0.9, 0.97, 1.0, 0.5 * al), 0.8)
	# Pfeilspitzen an der Austrittskante
	var tip_n := maxi(1, int(across / 14.0))
	for k in tip_n:
		var u := (float(k) + 0.5) / float(tip_n)
		var base: Vector2 = r.position + (Vector2(along if sgn > 0.0 else 0.0, across * u) if horiz else Vector2(across * u, along if sgn > 0.0 else 0.0))
		var perp := Vector2(-dir.y, dir.x)
		var back := base - dir * 5.0
		draw_polyline(PackedVector2Array([back + perp * 3.0, base, back - perp * 3.0]), Color(0.9, 0.97, 1.0, 0.45 * al), 1.0)
	_timer_arc(r.get_center(), z, 7.0)

## Takt-Anzeige pulsierender Zonen: ein Ring um den Mittelpunkt. Grün und schrumpfend = noch aktiv; gelb und wachsend = kommt gleich wieder.
func _timer_arc(c: Vector2, z: Dictionary, rad: float) -> void:
	if float(z.period) <= 0.0:
		return
	var p := fposmod(level.clock + float(z.phase), float(z.period))
	var on_t := float(z.on)
	if p < on_t:
		draw_arc(c, rad, -PI * 0.5, -PI * 0.5 + TAU * (1.0 - p / on_t), 28, Color(0.5, 1.0, 0.6, 0.9), 1.6)
	else:
		draw_arc(c, rad, -PI * 0.5, -PI * 0.5 + TAU * ((p - on_t) / (float(z.period) - on_t)), 28, Color(1.0, 0.85, 0.3, 0.8), 1.2)

## Hitzezone als Lavablase: unregelmäßiger, wabernder Klumpen aus Magma mit Kruste, Rissen, aufsteigenden Blasen, Tropfen und
## Funken, dazu Hitzeflimmern. Pulsierende Auslässe sind aus erkaltet (dunkles Gestein mit glimmenden Rissen) und kündigen das
## Einschalten mit Aufglühen an.
func _draw_heat(z: Dictionary, on: bool) -> void:
	var r: Rect2 = z.rect
	var glow := 1.0
	if float(z.period) > 0.0 and not on:
		var left := float(z.period) - fposmod(level.clock + float(z.phase), float(z.period))
		glow = 0.12 + (0.7 * (1.0 - left / 1.2) * (0.6 + 0.4 * sin(t * 22.0)) if left < 1.2 else 0.0)
	var c := r.get_center()
	var rx := r.size.x * 0.5
	var ry := r.size.y * 0.5
	var seed := int(r.position.x) * 7 + int(r.position.y) * 13
	var n := 22
	var outline := PackedVector2Array()
	for i in n:
		var ang := float(i) / float(n) * TAU
		var k := 0.88 + 0.07 * sin(t * 1.4 + float(i) * 1.7 + float(seed % 5)) + 0.05 * sin(t * 0.9 + float(i) * 2.9)
		outline.append(c + Vector2(cos(ang) * rx * k, sin(ang) * ry * k))
	# Strahlungshalo
	for i in 4:
		var f := 1.0 + 0.22 * float(i)
		draw_colored_polygon(_scaled(outline, c, f), Color(1.0, 0.3, 0.05, 0.05 * glow))
	# Kruste (außen) und Magma
	draw_colored_polygon(outline, Color(0.16, 0.05, 0.04).lerp(Color(0.35, 0.09, 0.04), glow * 0.5))
	var body := Color(0.78, 0.18, 0.05).lerp(Color(0.2, 0.07, 0.05), 1.0 - glow)
	draw_colored_polygon(_scaled(outline, c, 0.9), body)
	draw_colored_polygon(_scaled(outline, c, 0.68), Color(1.0, 0.45, 0.08, glow).lerp(Color(0.3, 0.1, 0.06, 1.0), 1.0 - glow))
	draw_colored_polygon(_scaled(outline, c, 0.4), Color(1.0, 0.78, 0.25, glow))
	draw_colored_polygon(_scaled(outline, c, 0.18), Color(1.0, 0.97, 0.7, glow))
	# dunkle Krustenplatten, die über das Magma treiben, mit glühenden Rissen
	for i in 4:
		var ph := t * (0.25 + 0.1 * float(i)) + float(i) * 1.9 + float(seed % 7)
		var pc := c + Vector2(cos(ph), sin(ph * 0.8)) * Vector2(rx, ry) * 0.45
		var plate := PackedVector2Array()
		for j in 6:
			var aa := float(j) / 6.0 * TAU + ph
			plate.append(pc + Vector2(cos(aa) * (3.5 + 1.5 * float((i + j) % 2)), sin(aa) * (2.6 + 1.2 * float((i + j) % 3))))
		draw_colored_polygon(plate, Color(0.14, 0.05, 0.04, 0.85))
		plate.append(plate[0])
		draw_polyline(plate, Color(1.0, 0.5, 0.1, 0.7 * glow), 0.8)
	# Blasen steigen auf und platzen
	for i in 5:
		var h := fmod(float(i) * 0.618 + float(seed % 11) * 0.1, 1.0)
		var fr := fmod(t * (0.35 + 0.2 * h) + h * 3.0, 1.0)
		var bp := Vector2(c.x + (h - 0.5) * rx * 1.3, c.y + ry * 0.55 - fr * ry * 1.1)
		var rad := 1.2 + 1.6 * fr
		if fr < 0.88:
			draw_arc(bp, rad, 0.0, TAU, 12, Color(1.0, 0.85, 0.4, 0.8 * glow), 0.9)
			draw_circle(bp + Vector2(-0.4, -0.4), 0.5, Color(1.0, 1.0, 0.85, 0.7 * glow))
		else:
			var q := (fr - 0.88) / 0.12
			draw_arc(bp, rad + 3.0 * q, 0.0, TAU, 12, Color(1.0, 0.6, 0.2, (1.0 - q) * glow), 0.8)
	# Tropfen fallen unten ab, Funken steigen nach oben
	for i in 4:
		var h := fmod(float(i) * 0.37 + float(seed % 13) * 0.07, 1.0)
		var fr := fmod(t * 0.45 + h * 2.0, 1.0)
		var dp := Vector2(c.x + (h - 0.5) * rx * 1.0, c.y + ry * 0.8 + fr * (ry * 0.9 + 6.0))
		draw_circle(dp, 1.3 * (1.0 - fr * 0.4), Color(1.0, 0.5, 0.1, (1.0 - fr) * 0.9 * glow))
	for i in 6:
		var h := fmod(float(i) * 0.7 + float(seed % 9) * 0.11, 1.0)
		var fr := fmod(t * (0.5 + 0.4 * h) + h * 2.0, 1.0)
		var sp := Vector2(c.x + (h - 0.5) * rx * 1.6 + sin(t * 3.0 + float(i)) * 2.0, c.y - ry * 0.6 - fr * 14.0)
		draw_rect(Rect2(sp.x, sp.y, 1.2, 1.2), Color(1.0, 0.8 - 0.4 * fr, 0.2, (1.0 - fr) * 0.9 * glow))
	# Hitzeflimmern über der Blase
	for k in 3:
		var pts := PackedVector2Array()
		for i in 10:
			var u := float(i) / 9.0
			pts.append(Vector2(c.x - rx + u * rx * 2.0, c.y - ry * 1.15 - float(k) * 3.5 + sin(t * 4.0 + u * 8.0 + float(k)) * 1.4))
		draw_polyline(pts, Color(1.0, 0.8, 0.5, 0.12 * glow), 1.0)
	_timer_arc(c, z, minf(rx, ry) * 0.35 + 3.0)

func _scaled(poly: PackedVector2Array, c: Vector2, f: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p_ in poly:
		out.append(c + (p_ - c) * f)
	return out

## Magnetzone: Spule (Hufeisen mit Polkappen), Feldlinien, einströmende (Anziehung, warm) oder ausströmende (Abstoßung, kalt)
## Partikel und weiche Energieringe. Pulsierende Magnete zeigen vor dem Einschalten ein Flackern und sind ausgeschaltet gedämpft.
func _draw_magnet(z: Dictionary, on: bool) -> void:
	var c: Vector2 = z.center
	var R: float = z.r
	var attract := float(z.k) > 0.0
	var hot := Color(1.0, 0.45, 0.55) if attract else Color(0.4, 0.8, 1.0)
	var deep := Color(0.55, 0.12, 0.3) if attract else Color(0.1, 0.25, 0.6)
	var al := 1.0 if on else 0.22
	if float(z.period) > 0.0 and not on:
		var left := float(z.period) - fposmod(level.clock + float(z.phase), float(z.period))
		if left < 1.2:
			al = 0.22 + 0.7 * (0.5 + 0.5 * sin(t * 24.0)) * (1.0 - left / 1.2)         # kündigt das Einschalten an
	# weiches Energiefeld (konzentrische Scheiben)
	for i in 7:
		var f := float(i + 1) / 7.0
		draw_circle(c, R * f, Color(deep.r, deep.g, deep.b, 0.035 * al))
	# Feldlinien: gekrümmte Bögen um den Kern
	for i in 8:
		var ang := float(i) / 8.0 * TAU + t * 0.25 * (1.0 if attract else -1.0)
		var pts := PackedVector2Array()
		for k in 9:
			var u := float(k) / 8.0
			var rr := lerpf(7.0, R * 0.96, u)
			var aa := ang + sin(u * PI) * 0.55
			pts.append(c + Vector2(cos(aa), sin(aa)) * rr)
		draw_polyline(pts, Color(hot.r, hot.g, hot.b, 0.16 * al), 1.0)
	# Partikel strömen hinein (Anziehung) oder hinaus (Abstoßung)
	for i in 28:
		var h := fmod(float(i) * 0.6180339, 1.0)
		var ang := float(i) / 28.0 * TAU + h * 2.0
		var fr := fmod(t * (0.35 + 0.25 * h) + h * 3.0, 1.0)
		var u := (1.0 - fr) if attract else fr
		var rr := lerpf(8.0, R, u)
		var p := c + Vector2(cos(ang + u * 0.6), sin(ang + u * 0.6)) * rr
		var tail := Vector2(cos(ang + u * 0.6), sin(ang + u * 0.6)) * (4.0 if attract else -4.0)
		var fade := sin(fr * PI)
		draw_line(p, p + tail, Color(hot.r, hot.g, hot.b, 0.85 * fade * al), 1.2)
	# Wellenringe
	for i in 3:
		var f := fmod(t * 0.5 + float(i) / 3.0, 1.0)
		var rr := R * ((1.0 - f) if attract else f)
		draw_arc(c, rr, 0.0, TAU, 48, Color(hot.r, hot.g, hot.b, 0.5 * sin(f * PI) * al), 1.0)
	# Kern: metallische Kugel mit Hufeisen und Polkappen
	draw_circle(c, 6.5, Color(0.04, 0.05, 0.14, 0.9 * al))
	draw_circle(c, 5.0, Color(0.32, 0.35, 0.5, al))
	draw_circle(c + Vector2(-1.2, -1.4), 2.0, Color(0.85, 0.9, 1.0, 0.7 * al))
	var rot := t * 0.8 * (1.0 if attract else -1.0)
	draw_arc(c, 8.5, rot + 0.5, rot + PI - 0.5, 14, Color(0.7, 0.74, 0.9, al), 2.4)
	draw_arc(c, 8.5, rot + PI + 0.5, rot + TAU - 0.5, 14, Color(0.7, 0.74, 0.9, al), 2.4)
	for sgn in [1.0, -1.0]:
		var ep := c + Vector2(cos(rot + (0.5 if sgn > 0.0 else PI + 0.5)), sin(rot + (0.5 if sgn > 0.0 else PI + 0.5))) * 8.5
		draw_circle(ep, 2.0, Color(1.0, 0.3, 0.35, al) if sgn > 0.0 else Color(0.35, 0.6, 1.0, al))
	draw_circle(c, 2.2 + 0.6 * sin(t * 6.0), Color(hot.r, hot.g, hot.b, 0.9 * al))
	_timer_arc(c, z, 13.0)

func _draw_movers() -> void:
	if level == null or not level.has_movers():
		return
	_draw_movers_main()
	_draw_vehicle_portals()

## Tunnelöffnungen in den Seitenwänden an Anfang und Ende jedes Fahrzeugpfads: Fahrzeuge fahren hier ein und aus. Für das Taxi sind sie
## nicht betretbar (die Wand bleibt fest). Wird nach den Fahrzeugen gezeichnet und verdeckt so deren Ein- und Austritt.
const PAINTS := ["candy", "mint", "neon", "night", "gold"]
var _paint_tex := {}

func _vehicle_tex(i: int) -> Texture2D:
	var id: String = PAINTS[i % PAINTS.size()]
	if not _paint_tex.has(id):
		_paint_tex[id] = load("res://assets/art/taxi_%s.png" % id)
	return _paint_tex[id]

func _draw_vehicle_portals() -> void:
	var seen := {}
	for m in level.movers:
		if m.kind != "vehicle" or level.movers_ignore:
			continue
		var pts: PackedVector2Array = m.pts
		var key := str(pts)
		if seen.has(key):
			continue
		seen[key] = true
		var col: Color = Color.from_hsv(fmod(0.5 + 0.12 * float(int(m.paint)), 1.0), 0.55, 1.0)
		for pi in 2:
			var p: Vector2 = pts[0] if pi == 0 else pts[pts.size() - 1]
			var dir: Vector2 = (pts[1] - pts[0]).normalized() if pi == 0 else (pts[pts.size() - 1] - pts[pts.size() - 2]).normalized()
			var entry := pi == 0
			# Öffnung sitzt in der Wandspalte (Pfadende liegt in der Wand): senkrecht ±1,5 Felder hoch
			var r := Rect2(floorf(p.x / T) * T, p.y - T * 0.75, T, T * 1.5)
			draw_rect(r, Color("#04050c"))
			draw_rect(Rect2(r.position.x, r.position.y, r.size.x, 1.5), col.darkened(0.2))
			draw_rect(Rect2(r.position.x, r.end.y - 1.5, r.size.x, 1.5), col.darkened(0.2))
			var inner := r.position.x + (r.size.x - 1.5 if r.position.x < 8.0 else 0.0)
			draw_rect(Rect2(inner, r.position.y, 1.5, r.size.y), col)
			for k in 2:
				var f := fmod(t * 1.4 + float(k) * 0.5, 1.0)
				var cx := r.position.x + 2.0 + f * (r.size.x - 6.0)
				var cy := r.get_center().y
				var d := 1.0 if (dir.x > 0.0) == entry else -1.0
				draw_polyline(PackedVector2Array([Vector2(cx - d * 2.0, cy - 3.0), Vector2(cx + d * 1.5, cy), Vector2(cx - d * 2.0, cy + 3.0)]), Color(col.r, col.g, col.b, 0.7 * (1.0 - absf(f - 0.5) * 1.2)), 1.0)
			draw_circle(Vector2(inner + 0.7, r.get_center().y), 1.2, Color(0.4, 1.0, 0.5, 0.6 + 0.4 * sin(t * 6.0)) if entry else Color(1.0, 0.4, 0.3, 0.6 + 0.4 * sin(t * 6.0)))

func _draw_movers_main() -> void:
	for m in level.movers:
		var r: Rect2 = m.rect
		if level.movers_ignore and m.kind != "pad":
			continue                         # beim Einflug ausgeblendet
		if m.kind == "meteor":
			_draw_meteor(m)
			continue
		if m.kind == "beam":
			_draw_beam(m)
			continue
		if m.kind == "vehicle":
			_draw_vehicle(m)
			continue
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

## Verkehr: Fahrzeuge sind kleine Taxis wie das eigene (gleiche Grafik in anderen Lackierungen) mit Triebwerksflamme und Scheinwerferkegel; der Pfad
## ist eine gestrichelte Leuchtlinie mit Richtungspfeilen. Auf senkrechten Abschnitten stehen die Fahrzeuge hochkant.
func _draw_vehicle(m: Dictionary) -> void:
	var pts: PackedVector2Array = m.pts
	var col: Color = Color.from_hsv(fmod(0.5 + 0.12 * float(int(m.paint)), 1.0), 0.55, 1.0)
	# Leuchtpfad (nur beim Fahrzeug mit Phase 0 je Pfad)
	if absf(float(m.phase)) < 0.001:
		for i in range(pts.size() - 1):
			var a0: Vector2 = pts[i]
			var a1: Vector2 = pts[i + 1]
			var seg := a1 - a0
			var ln := seg.length()
			var dir := seg / maxf(ln, 0.001)
			var n := int(ln / 12.0)
			for k in n:
				var u := fmod(float(k) * 12.0 + t * 14.0, ln)
				draw_line(a0 + dir * u, a0 + dir * minf(u + 4.0, ln), Color(0.45, 0.85, 1.0, 0.2), 1.0)
			var mid := a0 + seg * 0.5
			var perp := Vector2(-dir.y, dir.x)
			draw_polyline(PackedVector2Array([mid - dir * 3.0 + perp * 2.5, mid + dir * 1.5, mid - dir * 3.0 - perp * 2.5]), Color(0.5, 0.9, 1.0, 0.3), 1.0)
	var st := level.vehicle_state(m, level.clock)
	if not st.visible:
		return
	var c: Vector2 = st.pos
	var dir: Vector2 = st.dir
	var tex := _vehicle_tex(int(m.paint))
	var ang := dir.angle() if dir.x >= 0.0 else dir.angle() + PI          # Fahrtrichtung links: Sprite gespiegelt statt auf dem Kopf
	var flip := -1.0 if dir.x < -0.01 else 1.0
	# Triebwerksflamme hinten und Scheinwerferkegel vorn (im gedrehten Koordinatensystem)
	draw_set_transform(c, ang, Vector2(1.0, 1.0))
	var fwd := 1.0 if dir.x >= 0.0 else -1.0
	for i in 4:
		var f := float(i + 1) / 4.0
		draw_circle(Vector2(-fwd * (14.0 + f * 7.0), 3.0 + sin(t * 20.0 + float(i)) * 0.6), (1.0 - f) * 2.2 + 0.4, Color(1.0, 0.6 - f * 0.3, 0.2, 0.55 * (1.0 - f)))
	draw_colored_polygon(PackedVector2Array([Vector2(fwd * 14.0, 2.0), Vector2(fwd * 22.0, -1.5), Vector2(fwd * 22.0, 5.5)]), Color(1.0, 0.98, 0.7, 0.16))
	draw_set_transform(c, ang, Vector2(flip, 1.0))                                                            # Spiegeln über die Transformation (negative Rechtecke verschieben das Bild um eine Länge)
	draw_texture_rect(tex, Rect2(-16.0, -10.0, 32.0, 20.0), false)
	draw_set_transform(c, ang, Vector2.ONE)
	draw_circle(Vector2(fwd * 13.5, 2.0), 1.4, Color(1.0, 0.98, 0.75, 0.95))                                   # Scheinwerfer sitzt an der Nase
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

## Plasmastrahl: zwei Emitter an den Enden; vor dem Einschalten flackert eine dünne Ladelinie, im Takt brennt ein weiß-orangener
## Strahl mit Glühen und zuckenden Blitzen.
func _draw_beam(m: Dictionary) -> void:
	var lr: Rect2 = level.lane_rect(m)
	var horiz := lr.size.x >= lr.size.y
	var eta := level.meteor_eta(m, level.clock)
	var active := eta <= 0.0
	var a0: Vector2 = lr.position + (Vector2(0.0, lr.size.y * 0.5) if horiz else Vector2(lr.size.x * 0.5, 0.0))
	var a1: Vector2 = lr.position + (Vector2(lr.size.x, lr.size.y * 0.5) if horiz else Vector2(lr.size.x * 0.5, lr.size.y))
	var hot := Color(1.0, 0.62, 0.2)
	# Emitter (Düsenblöcke)
	for pt in [a0, a1]:
		draw_rect(Rect2(pt.x - 5.0, pt.y - 5.0, 10.0, 10.0), Color("#1a1d3a"))
		draw_rect(Rect2(pt.x - 4.0, pt.y - 4.0, 8.0, 8.0), Color("#3a4580"))
		draw_circle(pt, 2.4, Color(1.0, 0.4 + (0.4 if active else 0.0), 0.2, 0.9 if active else 0.5 + 0.4 * sin(t * 6.0)))
	if not active and eta <= float(m.warn):
		var k := 1.0 - eta / float(m.warn)
		var fl := 0.25 + 0.5 * absf(sin(t * (10.0 + 14.0 * k)))
		draw_line(a0, a1, Color(1.0, 0.45, 0.2, fl * (0.4 + 0.6 * k)), 1.0)
		return
	if not active:
		draw_line(a0, a1, Color(0.5, 0.45, 0.6, 0.18), 1.0)
		return
	var thick := (lr.size.y if horiz else lr.size.x)
	for i in 4:
		var f := float(i) / 3.0
		var w := thick * (1.0 - f * 0.65)
		var col := Color(hot.r, hot.g - 0.25 * (1.0 - f), 0.25 + 0.7 * f, 0.18 + 0.5 * f)
		var rr := Rect2(lr.position + (Vector2(0.0, (lr.size.y - w) * 0.5) if horiz else Vector2((lr.size.x - w) * 0.5, 0.0)), Vector2(lr.size.x, w) if horiz else Vector2(w, lr.size.y))
		draw_rect(rr, col)
	# zuckender Blitz
	var pts := PackedVector2Array()
	var n := 14
	for i in n + 1:
		var u := float(i) / float(n)
		var p := a0.lerp(a1, u)
		var jit := sin(t * 40.0 + float(i) * 2.3) * 1.6 * sin(u * PI)
		pts.append(p + (Vector2(0.0, jit) if horiz else Vector2(jit, 0.0)))
	draw_polyline(pts, Color(1.0, 1.0, 0.9, 0.95), 1.0)

## Meteorit: vor dem Fall blinkt seine Bahn als Warnstreifen, im Fall zieht er einen Feuerschweif hinter sich her.
func _draw_meteor(m: Dictionary) -> void:
	var eta := level.meteor_eta(m, level.clock)
	var a0 := Vector2(float(m.x) + float(m.w) * 0.5, float(m.y) + float(m.h) * 0.5)
	var a1 := a0 + Vector2(float(m.ax), float(m.ay))
	if eta > 0.0 and eta <= float(m.warn):
		# Vorwarnung: pulsierendes rotes Band über die ganze Bahn, laufende Pfeile, helle Kanten und ein großes Warndreieck am Anfang
		var k := 1.0 - eta / float(m.warn)
		var lr: Rect2 = level.lane_rect(m)
		var pulse := 0.5 + 0.5 * sin(t * (7.0 + 12.0 * k))
		draw_rect(lr, Color(1.0, 0.2, 0.15, (0.10 + 0.22 * pulse) * (0.5 + 0.5 * k)))
		draw_line(lr.position, Vector2(lr.position.x, lr.end.y), Color(1.0, 0.45, 0.3, 0.45 + 0.5 * pulse), 1.2)
		draw_line(Vector2(lr.end.x, lr.position.y), lr.end, Color(1.0, 0.45, 0.3, 0.45 + 0.5 * pulse), 1.2)
		var horiz := lr.size.x > lr.size.y
		var dirw := (a1 - a0).normalized()
		var span := a0.distance_to(a1)
		for i in int(maxf(span / 26.0, 1.0)):
			var u := fposmod(t * 70.0 + float(i) * 26.0, maxf(span, 1.0))
			var p := a0 + dirw * u
			var nrm := Vector2(-dirw.y, dirw.x)
			draw_polyline(PackedVector2Array([p - dirw * 3.0 + nrm * 4.0, p + dirw * 2.0, p - dirw * 3.0 - nrm * 4.0]), Color(1.0, 0.5, 0.35, 0.35 + 0.5 * pulse), 1.4)
		var tp := a0 - dirw * 9.0
		draw_colored_polygon(PackedVector2Array([tp + Vector2(0, -7), tp + Vector2(7, 6), tp + Vector2(-7, 6)]), Color(1.0, 0.82, 0.15, 0.55 + 0.45 * pulse))
		draw_polyline(PackedVector2Array([tp + Vector2(0, -7), tp + Vector2(7, 6), tp + Vector2(-7, 6), tp + Vector2(0, -7)]), Color(0.45, 0.05, 0.05, 0.95), 1.2)
		draw_rect(Rect2(tp.x - 0.7, tp.y - 3.0, 1.4, 5.0), Color(0.45, 0.05, 0.05, 0.95))
		draw_rect(Rect2(tp.x - 0.7, tp.y + 3.0, 1.4, 1.4), Color(0.45, 0.05, 0.05, 0.95))
		return
	var r: Rect2 = m.rect
	if r.position.x < LevelData.OFFSCREEN * 0.5:
		return
	var dir := (a1 - a0).normalized()
	var c := r.get_center()
	# Feuerschweif
	for i in 8:
		var f := float(i + 1) / 8.0
		var p := c - dir * f * 26.0 + Vector2(sin(t * 30.0 + float(i)) * 0.8, 0.0)
		var sz := (1.0 - f) * 9.0 + 1.5
		draw_circle(p, sz * 0.5, Color(1.0, 0.6 - f * 0.35, 0.12, 0.5 * (1.0 - f)))
	# Brocken: unregelmäßige „Kartoffel“ mit Kratern, dreht sich beim Fallen
	var seed := int(m.x) * 7 + int(m.y) * 13 + int(m.phase * 10.0)
	var rot := t * (1.8 + float(seed % 5) * 0.3) * (1.0 if seed % 2 == 0 else -1.0)
	var rad := 11.0 * (float(m.w) / 16.0 * 0.5 + 0.5)
	var pts := PackedVector2Array()
	var hi := PackedVector2Array()
	for i in 11:
		var h := fmod(float(seed * 31 + i * 17) * 0.618, 1.0)
		var ang := float(i) / 11.0 * TAU + rot
		var rr := rad * (0.72 + 0.4 * h + 0.1 * sin(float(i) * 1.7))
		var v := Vector2(cos(ang), sin(ang)) * Vector2(1.0, 0.86)
		pts.append(c + v * rr)
		hi.append(c + Vector2(-1.4, -1.6) + v * rr * 0.62)
	draw_colored_polygon(pts, Color("#4b3f46"))
	draw_colored_polygon(hi, Color("#7d6a70"))
	for i in 3:
		var ca := rot * 0.6 + float(i) * 2.3 + float(seed % 7)
		var cp := c + Vector2(cos(ca), sin(ca)) * rad * (0.25 + 0.18 * float(i))
		draw_circle(cp, 1.3 + 0.5 * float(i % 2), Color(0.18, 0.14, 0.17, 0.85))
		draw_circle(cp + Vector2(-0.4, -0.4), 0.6, Color(0.55, 0.47, 0.5, 0.8))
	pts.append(pts[0])
	draw_polyline(pts, Color(1.0, 0.55, 0.2, 0.9), 1.0)

## Beleuchtete Wartehütte: warmes Fensterlicht, Halo und ein Lichtfleck auf der Plattform. Wartet dort ein Fahrgast, leuchtet sie heller
## und flackert leicht; sonst brennt ein gedämpftes Licht.
## Ampellampe auf dem Dach des Wartehäuschens: rot = niemand wartet, grün (pulsierend) = Fahrgast wartet.
func _light_shelter(sh: Rect2, id: String) -> void:
	var waiting := run.passenger_waiting_at(id)
	var c := Vector2(sh.get_center().x, sh.position.y - 5.5)
	var col := Color(0.3, 1.0, 0.45) if waiting else Color(1.0, 0.22, 0.2)
	var pulse := 0.85 + 0.15 * sin(t * 8.0) if waiting else 0.7 + 0.1 * sin(t * 2.0)
	draw_rect(Rect2(c.x - 1.0, c.y + 1.0, 2.0, 2.5), Color("#0c0f24"))              # Mast
	draw_rect(Rect2(c.x - 2.2, c.y - 2.2, 4.4, 4.4), Color("#0c0f24"))              # Gehäuse
	draw_circle(c, 6.5, Color(col.r, col.g, col.b, 0.10 * pulse))                    # Schein
	draw_circle(c, 4.0, Color(col.r, col.g, col.b, 0.16 * pulse))
	draw_circle(c, 1.8, Color(col.r, col.g, col.b, pulse))                           # Lampe
	draw_circle(c + Vector2(-0.5, -0.5), 0.6, Color(1.0, 1.0, 1.0, 0.8 * pulse))     # Glanzpunkt

## Krankenhaus-Plattform: weißes Schild mit rotem Kreuz über dem Unterstand und ein rot blinkendes Rundumlicht.
func _draw_hospital_sign(p: Dictionary, y: float) -> void:
	var sh: Rect2 = p.get("shelter", Rect2())
	var cx: float = sh.get_center().x if sh.size.x > 0.0 else float(p.center)
	var top := y - 27.0
	draw_rect(Rect2(cx - 6.0, top, 12.0, 12.0), Color("#0c0f24"))
	draw_rect(Rect2(cx - 5.0, top + 1.0, 10.0, 10.0), Color("#f4f6ff"))
	draw_rect(Rect2(cx - 1.5, top + 2.5, 3.0, 7.0), Color("#e5202e"))
	draw_rect(Rect2(cx - 3.5, top + 4.5, 7.0, 3.0), Color("#e5202e"))
	var blink := 0.5 + 0.5 * sin(t * 7.0)
	draw_circle(Vector2(cx, top - 3.0), 2.0, Color(1.0, 0.2 + 0.4 * blink, 0.2, 0.6 + 0.4 * blink))

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
	if a.medical:
		_draw_stretcher(a, pos.y, col.a)
	else:
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

## Krankenpatient: blasser Mensch liegt unter einer Decke mit rotem Kreuz auf einer Rolltrage; daneben ein Infusionsständer mit tropfendem
## Beutel. Koordinaten relativ zur Bildschirmmitte des Fahrgasts (Transform ist gesetzt), y = Plattformoberfläche.
func _draw_stretcher(a: PassengerActor, y: float, al: float) -> void:
	var bob := sin(a.walked * 0.6) * 0.3 if a.is_walking() else 0.0
	var yy := y + bob
	var ink := Color(0.05, 0.06, 0.16, al)
	# Räder und Gestell
	for wx in [-8.0, 8.0]:
		draw_circle(Vector2(wx, yy - 1.4), 1.5, ink)
		draw_circle(Vector2(wx, yy - 1.4), 0.7, Color(0.7, 0.75, 0.85, al))
		draw_line(Vector2(wx, yy - 2.6), Vector2(wx * 0.9, yy - 4.6), Color(0.55, 0.6, 0.75, al), 1.0)
	draw_rect(Rect2(-10.5, yy - 5.2, 21.0, 1.2), Color(0.6, 0.66, 0.8, al))
	# Matratze und Kissen
	draw_rect(Rect2(-10.5, yy - 7.8, 21.0, 2.8), Color(0.94, 0.96, 1.0, al))
	draw_rect(Rect2(-10.5, yy - 7.8, 21.0, 2.8), ink, false, 0.6)
	draw_rect(Rect2(-10.0, yy - 9.6, 5.0, 2.0), Color(0.98, 0.98, 1.0, al))
	# Körper unter der Decke (hellgrün), Kopf links
	draw_rect(Rect2(-5.0, yy - 10.6, 15.0, 2.8), Color(0.55, 0.82, 0.78, al))
	draw_rect(Rect2(-5.0, yy - 10.6, 15.0, 0.9), Color(0.72, 0.92, 0.88, al))
	draw_rect(Rect2(-5.0, yy - 10.6, 15.0, 2.8), ink, false, 0.6)
	draw_circle(Vector2(-7.4, yy - 10.4), 2.5, Color(0.86, 0.82, 0.74, al))             # blasses Gesicht
	draw_circle(Vector2(-7.4, yy - 10.4), 2.5, ink, false, 0.6) if false else null
	draw_rect(Rect2(-8.6, yy - 11.0, 1.1, 0.5), ink)                                       # geschlossene Augen
	draw_rect(Rect2(-6.8, yy - 11.0, 1.1, 0.5), ink)
	draw_rect(Rect2(-8.3, yy - 9.3, 1.8, 0.4), Color(0.55, 0.3, 0.3, al))                  # matter Mund
	# rotes Kreuz auf der Decke
	draw_rect(Rect2(3.2, yy - 10.2, 1.0, 2.2), Color(0.9, 0.12, 0.18, al))
	draw_rect(Rect2(2.6, yy - 9.6, 2.2, 1.0), Color(0.9, 0.12, 0.18, al))
	# Infusionsständer mit tropfendem Beutel
	draw_line(Vector2(11.5, yy - 3.5), Vector2(11.5, yy - 17.5), Color(0.65, 0.7, 0.85, al), 0.8)
	draw_line(Vector2(9.5, yy - 17.5), Vector2(13.5, yy - 17.5), Color(0.65, 0.7, 0.85, al), 0.8)
	draw_rect(Rect2(9.8, yy - 17.0, 3.0, 4.2), Color(0.55, 0.85, 1.0, al * 0.9))
	draw_line(Vector2(11.3, yy - 12.8), Vector2(5.0, yy - 9.6), Color(0.8, 0.9, 1.0, al * 0.7), 0.5)
	var drip := fmod(t * 1.3 + float(a.job_index) * 0.37, 1.0)
	draw_rect(Rect2(11.0, yy - 12.4 + drip * 3.0, 0.8, 0.8), Color(0.7, 0.95, 1.0, al * (1.0 - drip)))

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
	if dest == "H":
		draw_rect(Rect2(bx - 6.0, by - 5.0, 12.0, 12.0), Color(0.04, 0.05, 0.14, fade))
		draw_rect(Rect2(bx - 5.0, by - 4.0, 10.0, 10.0), Color(0.96, 0.97, 1.0, fade))
		draw_rect(Rect2(bx - 1.5, by - 3.0, 3.0, 8.0), Color(0.9, 0.12, 0.18, fade))
		draw_rect(Rect2(bx - 4.0, by - 0.5, 8.0, 3.0), Color(0.9, 0.12, 0.18, fade))
		return
	if dest == "exit":
		var g := Color(0.1, 0.55, 0.3, fade)
		draw_colored_polygon(PackedVector2Array([Vector2(bx, by - 3.2), Vector2(bx + 3.0, by + 0.2), Vector2(bx - 3.0, by + 0.2)]), g)
		draw_rect(Rect2(bx - 1.0, by + 0.2, 2, 3.0), g)
	else:
		draw_string(Fonts.hud, Vector2(bx - 5.0, by + 3.2), dest, HORIZONTAL_ALIGNMENT_CENTER, 10, 9, Color(ink.r, ink.g, ink.b, fade))

## Rausgeworfener Fahrgast: dreht sich im Fall und schreit („AAAH!“), nach dem Aufprall liegt er platt am Boden.
func _draw_falling(a: PassengerActor, pos: Vector2) -> void:
	if a.shattered:
		for i in 9:
			var ang := float(i) / 9.0 * TAU + 0.4
			var d := 1.6 + float(i % 3) * 0.4
			var life := clampf(a.fade, 0.0, 1.0)
			var spread := 4.0 + float(i % 3) * 3.0 + (a.dead_t - 1.6) * 40.0
			var c := Vector2(pos.x + cos(ang) * spread, pos.y - 8.0 + sin(ang) * spread * 0.7 + (a.dead_t - 1.6) * 20.0)
			draw_colored_polygon(PackedVector2Array([c + Vector2(0, -d), c + Vector2(d * 0.7, 0), c + Vector2(0, d), c + Vector2(-d * 0.7, 0)]), Color(0.6, 0.95, 1.0, life * 0.85))
		return
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
		draw_texture_rect(pump_head_tex, Rect2(-11, -14.5, 22, 16), false, Color(1, 1, 1, 1))          # Kopf größer: auch Preise wie 15.26 passen hinein
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
		draw_string(font, Vector2(-11, -4.3), txt, HORIZONTAL_ALIGNMENT_RIGHT, 17.6, 5, col)          # rechtsbündig im Display (kleiner Rand zum rechten Rahmen)
		if pump_flash > 0.0:
			draw_rect(Rect2(-7.0, -9.5, 14.0, 6.0), Color(1, 1, 1, pump_flash * 0.55))
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
