extends Node2D
## Taxi-Darstellung: Rumpf-Sprite, Fahrwerk, Düsenflammen, Beschädigung.

var sim: TaxiSim
var tex: Texture2D = Cosmetics.paint_texture()                    # 78×48 (nur noch Rückfall; gezeichnet wird die Größe des Bildschirms)
var sticker: Texture2D = Cosmetics.sticker_small_texture()
var size_n := 0                   # Größe des Taxis in Bildschirmpunkten je Einheit, zuletzt gezeichnet
var frame := {}
var sticker_frame := {}
var t := 0.0
var flame_main := 0.0
var flame_down := 0.0
var flame_side := 0.0
var flash := 0.0
var yaw := 0.0                    # Mischform: geglättete Drehung −1 … 1 nach der Seitengeschwindigkeit

# Runde 86 – kleine Details (nur Darstellung): Nickerchen, Kaffeetasse, Sektor-Zubehör, Hut nach Kalender, Trinkgeld-Münze
const Calendar := preload("res://src/core/calendar.gd")
static var nap_after := 9.0       # so lange gelandet ohne Eingabe, dann schläft der Fahrer ein (Debug-Menü „Eastereggs“: 2 s)
var idle_t := 0.0
var startle_t := 0.0
var slosh_t := 9.0
var slosh_k := 1.0
var coin_t := 9.0
const COIN_TIME := 0.8
var hat := Calendar.hat()
var valentine := Calendar.valentine()   # 14. Februar: Herz-Duftbaum in der Kuppel, Erröten bei Kusshänden (props_view.gd)
var blush_t := 9.0
const BLUSH_TIME := 2.4
## Waagerechte Verschiebung des Fahrerkopfs je Drehstufe der Mischform (Bildpunkte in der Größe 6, gemessen an den Augen; Mitte = 2D-Taxi).
const FACE_SHIFT_PX6 := [-5.0, -3.0, -2.0, 0.0, 2.0, 3.0, 5.0]
var face_dx := 0.0                # aktuelle Verschiebung in Bildeinheiten

var light: PointLight2D
var exhaust: CPUParticles2D
var side_l: CPUParticles2D
var side_r: CPUParticles2D
var brake_l: CPUParticles2D
var brake_r: CPUParticles2D
var dust: CPUParticles2D
var puff: CPUParticles2D
var sparks: CPUParticles2D
var smoke: CPUParticles2D
var weak_sparks: CPUParticles2D    # Sonderschicht, Schiefe Düse: Funkenschlag an der schwachen Seitendüse
var weak_t := 0.0

func _ready() -> void:
	scale = Vector2.ONE * Tuning.TAXI_SCALE            # Zeichencode bleibt in Entwurfsmaßen
	var Fx := preload("res://src/game/fx.gd")
	light = Fx.make_light(Color("#ffe2b0"), 130.0, 2.6, true)
	light.position = Vector2(0, 2)
	light.texture_scale /= Tuning.TAXI_SCALE            # Lichtradius unabhängig von der Taxi-Skalierung
	add_child(light)
	exhaust = Fx.make_particles(48, 0.34, Vector2(55, 100), 1.5, Color(1, 0.85, 0.4, 0.95), Color(1, 0.3, 0.1, 0.0))
	exhaust.position = Vector2(0, 8.8)
	exhaust.direction = Vector2(0, 1)
	exhaust.spread = 14.0
	exhaust.show_behind_parent = true
	add_child(exhaust)
	side_l = _side(-15.5, -1.0, Fx)
	side_r = _side(15.5, 1.0, Fx)
	brake_l = _brake(-9.0, Fx)
	brake_r = _brake(9.0, Fx)
	dust = Fx.make_particles(26, 0.8, Vector2(14, 40), 1.4, Color(0.72, 0.74, 0.95, 0.5), Color(0.5, 0.52, 0.8, 0.0), false)
	dust.top_level = true
	dust.direction = Vector2(0, -1)
	dust.spread = 85.0
	dust.gravity = Vector2(0, -4)
	add_child(dust)
	puff = Fx.make_particles(16, 0.7, Vector2(18, 48), 1.6, Color(0.78, 0.8, 1.0, 0.65), Color(0.5, 0.52, 0.8, 0.0), false)
	puff.top_level = true
	puff.one_shot = true
	puff.explosiveness = 0.95
	puff.direction = Vector2(0, -1)
	puff.spread = 88.0
	add_child(puff)
	sparks = Fx.make_particles(20, 0.55, Vector2(55, 130), 1.0, Color(1, 0.92, 0.55, 1), Color(1, 0.4, 0.1, 0.0))
	sparks.one_shot = true
	sparks.explosiveness = 1.0
	sparks.direction = Vector2(0, -1)
	sparks.spread = 120.0
	sparks.gravity = Vector2(0, 170)
	add_child(sparks)
	weak_sparks = Fx.make_particles(16, 0.35, Vector2(40, 95), 0.9, Color(1, 0.85, 0.35, 1), Color(1, 0.35, 0.1, 0.0))
	weak_sparks.spread = 55.0
	weak_sparks.gravity = Vector2(0, 160)
	weak_sparks.emitting = false
	add_child(weak_sparks)
	smoke = Fx.make_particles(14, 1.3, Vector2(8, 18), 1.8, Color(0.42, 0.42, 0.5, 0.65), Color(0.2, 0.2, 0.26, 0.0), false)
	smoke.position = Vector2(4, -8)
	smoke.direction = Vector2(0, -1)
	smoke.spread = 25.0
	add_child(smoke)

func _side(x: float, dir: float, Fx) -> CPUParticles2D:
	var p: CPUParticles2D = Fx.make_particles(14, 0.22, Vector2(28, 55), 0.9, Color(0.6, 0.9, 1.0, 0.9), Color(0.3, 0.6, 1.0, 0.0))
	p.position = Vector2(x, 0)
	p.direction = Vector2(dir, 0)
	p.spread = 10.0
	p.show_behind_parent = true
	add_child(p)
	return p

func _brake(x: float, Fx) -> CPUParticles2D:
	var p: CPUParticles2D = Fx.make_particles(10, 0.2, Vector2(25, 45), 0.8, Color(0.6, 0.9, 1.0, 0.9), Color(0.3, 0.6, 1.0, 0.0))
	p.position = Vector2(x, -5.3)
	p.direction = Vector2(0, -1)
	p.spread = 12.0
	p.show_behind_parent = true
	add_child(p)
	return p

var no_lamp := false            # Sonderschicht, Ampel kaputt: keine Landelampe am Taxi
var kit_draw: Callable          # Sonderschicht: zeichnet Lizenz und eingebaute Teile ans Taxi (OvertimeLook.draw_on_taxi)

## Heiße Düse (Sonderschicht): Hitzestreifen unter der Motorgondel, im Blickfeld am Taxi. Er füllt sich mit Dauerschub (gelb → rot); überhitzt läuft
## er blau-weiß leer, bis die Düse wieder zieht (voller Streifen = überhitzt).
func _draw_heat_strip() -> void:
	var x0 := 8.5
	var w := 9.0
	var y := 16.4
	var a := _u0(x0, y)
	var b := _u0(x0 + w, y + 0.7)
	var r := Rect2(a, b - a)
	if not sim.jet_hot and sim.jet_heat <= 0.01:
		return
	draw_rect(r.grow(0.35), Color(0.05, 0.06, 0.15, 0.85))
	if sim.jet_hot:
		var k := clampf((sim.jet_heat - TaxiSim.OVERHEAT_COOL) / (TaxiSim.OVERHEAT_AT + 1.0 - TaxiSim.OVERHEAT_COOL), 0.0, 1.0)
		draw_rect(Rect2(r.position, Vector2(r.size.x * k, r.size.y)), Color("#9fdcff").lerp(Color.WHITE, 0.3 * sin(t * 6.0) + 0.3))
	else:
		var k := clampf(sim.jet_heat / TaxiSim.OVERHEAT_AT, 0.0, 1.0)
		draw_rect(Rect2(r.position, Vector2(r.size.x * k, r.size.y)), Color("#ffcb3d").lerp(Color("#ff3b2e"), k))

## Taxi-Einheiten ohne Kopfversatz (Rumpfteile drehen in der Mischform nicht mit dem Fahrer).
func _u0(u: float, v: float) -> Vector2:
	return Vector2(Tuning.TAXI_RECT.position.x + u * Tuning.TAXI_RECT.size.x / Tuning.TAXI_UNITS.x, Tuning.TAXI_RECT.position.y + v * Tuning.TAXI_RECT.size.y / Tuning.TAXI_UNITS.y)

func bind(s: TaxiSim) -> void:
	sim = s

func ground_below() -> Vector2:
	## Erster fester Punkt unter dem Taxi (max. 44 px), sonst Vector2.INF.
	var y := sim.pos.y + 10.0
	while y < sim.pos.y + 54.0:
		if sim.level.is_solid_at(Vector2(sim.pos.x, y)):
			return Vector2(sim.pos.x, floorf(y / Tuning.TILE) * Tuning.TILE)
		y += 2.0
	return Vector2.INF

func burst_puff(strength := 1.0) -> void:
	if Settings.values.reduce_motion:
		return
	var g := ground_below()
	puff.global_position = (g if g != Vector2.INF else sim.pos + Vector2(0, 10)) - Vector2(0, 0.5)
	puff.amount = int(10 + 8 * strength)
	puff.restart()
	puff.emitting = true

func burst_sparks() -> void:
	if Settings.values.reduce_motion:
		return
	sparks.restart()
	sparks.emitting = true

func update_effects() -> void:
	var fuel_ok := sim.fuel > 0.0
	exhaust.emitting = flame_main > 0.05 and fuel_ok
	side_l.emitting = flame_side > 0.05 and fuel_ok       # Schub nach rechts -> linke Düse
	side_r.emitting = flame_side < -0.05 and fuel_ok
	brake_l.emitting = flame_down > 0.05 and fuel_ok
	brake_r.emitting = flame_down > 0.05 and fuel_ok
	_weak_side(fuel_ok)
	var hurt := 1.0 - sim.hull / Tuning.HULL_MAX
	smoke.emitting = hurt > 0.4 and sim.state != TaxiSim.State.DESTROYED
	light.energy = 2.4 + 1.2 * flame_main + (0.0 if sim.state == TaxiSim.State.LANDED else 0.0)
	light.color = Color("#ffe2b0").lerp(Color("#ffb060"), flame_main)
	# Bodenstaub unter dem Schub
	var g := ground_below()
	if flame_main > 0.2 and g != Vector2.INF and not Settings.values.reduce_motion:
		var near := 1.0 - clampf((g.y - sim.pos.y - 10.0) / 44.0, 0.0, 1.0)
		dust.global_position = g
		dust.emitting = near * flame_main > 0.2
	else:
		dust.emitting = false

## Schiefe Düse (Sonderschicht): An der schwachen Seitendüse schlagen Funken, sobald sie zündet, und alle paar Sekunden spuckt sie auch im Leerlauf.
## Schub nach links (side_l) kommt aus der rechten Düse, Schub nach rechts (side_r) aus der linken.
func _weak_side(fuel_ok: bool) -> void:
	if sim == null or (sim.side_l >= 0.999 and sim.side_r >= 0.999) or sim.state == TaxiSim.State.DESTROYED or Settings.values.reduce_motion:
		weak_sparks.emitting = false
		return
	var right := sim.side_l < 0.999                       # schwach nach links = rechte Düse
	var dir := 1.0 if right else -1.0
	weak_sparks.position = Vector2(15.5 * dir, 0.5)
	weak_sparks.direction = Vector2(dir, 0.3)
	var firing := fuel_ok and ((flame_side < -0.05) if right else (flame_side > 0.05))
	weak_t += Tuning.TICK
	var sputter := fmod(weak_t, 2.6) < 0.12               # kurzes Spucken im Leerlauf
	weak_sparks.emitting = firing or sputter

func sync_state() -> void:
	## Wird einmal pro Physik-Tick aufgerufen; Position wird dank Interpolation geglättet.
	position = sim.pos
	rotation = sim.tilt
	var ti := sim.thrust_in
	flame_main = clampf(-ti.y, 0.0, 1.0) if sim.fuel > 0.0 else 0.0
	flame_down = clampf(ti.y, 0.0, 1.0) if sim.fuel > 0.0 else 0.0
	flame_side = ti.x if sim.fuel > 0.0 else 0.0
	update_effects()

func _process(delta: float) -> void:
	t += delta
	flash = maxf(0.0, flash - delta * 4.0)
	if sim != null:
		var quiet := sim.state == TaxiSim.State.LANDED and sim.thrust_in.length() < 0.05
		if quiet:
			idle_t += delta
		else:
			if idle_t > nap_after:
				startle_t = 0.8                 # aus dem Nickerchen hochgeschreckt
			idle_t = 0.0
	startle_t = maxf(0.0, startle_t - delta)
	slosh_t += delta
	blush_t += delta
	var was := coin_t
	coin_t += delta
	if was < COIN_TIME and coin_t >= COIN_TIME:
		Sfx.play("coin", -9.0)                  # Münze landet klimpernd im Taxi
	if sim != null and Cosmetics.taxi_3d:
		yaw = move_toward(yaw, clampf(sim.vel.x / 60.0, -1.0, 1.0), delta * 2.5)
	queue_redraw()

func _draw() -> void:
	if sim == null:
		return
	var hurt := 1.0 - sim.hull / Tuning.HULL_MAX
	# Fahrwerk
	var g := sim.gear
	if g > 0.02:
		var gl := Tuning.GEAR_LEN / Tuning.TAXI_SCALE * g
		var steel := Color("#c9cfee")
		for sx in [-1.0, 1.0]:
			draw_line(Vector2(sx * 5.0, 5.5), Vector2(sx * Tuning.FOOT_X / Tuning.TAXI_SCALE, 5 + gl), steel, PixelDraw.wsnap(self, 0.7))
			draw_rect(Rect2(sx * Tuning.FOOT_X / Tuning.TAXI_SCALE - 2, 5 + gl, 4, 0.7), steel)
		if sim.gear_extended() and not no_lamp:
			var ok := sim.landing_margin()
			var lamp := SignalColors.good() if ok > 0.0 else SignalColors.bad()
			draw_rect(Rect2(-1, 7, 2, 1), lamp)
	# Flammen: aus Pixelzeilen (heißer Kern, flackernder Rand, Spitzen in Rot), Lenkdüsen blau
	var flick := 0.6 + 0.4 * sin(t * 60.0)
	_pixel_flames(flick)
	# Rumpf
	var mod := Color.WHITE
	if flash > 0.0:
		mod = Color(1, 0.4 + 0.6 * (1.0 - flash), 0.4 + 0.6 * (1.0 - flash))
	if sim.overheat:                          # Heiße Düse (Sonderschicht): der Rumpf glüht mit der Hitze, überhitzt pulsierend rot
		var hk := clampf(sim.jet_heat / TaxiSim.OVERHEAT_AT, 0.0, 1.0)
		if sim.jet_hot:
			hk = 0.75 + (0.25 * sin(t * 10.0) if not Settings.values.reduce_motion else 0.15)
		mod = mod * Color(1.0, 1.0 - 0.55 * hk, 1.0 - 0.6 * hk)
	var n := PixelScale.size_for(self)       # 720p … 2160p: je Bildschirmskalierung das eigens gerasterte Taxi, 1:1
	if n != size_n:
		size_n = n
		frame = Cosmetics.taxi_frame(n)
		sticker_frame = Cosmetics.sticker_frame(n)
	var f3 := Cosmetics.taxi3d_frame(n, roundi((yaw + 1.0) * 0.5 * float(Cosmetics.TAXI3D_FRAMES - 1))) if Cosmetics.taxi_3d else {}
	if not f3.is_empty():
		draw_texture_rect_region(f3.tex, Tuning.TAXI_RECT, f3.src, mod)       # Mischform: Drehstufe nach der Seitengeschwindigkeit
		face_dx = float(FACE_SHIFT_PX6[clampi(roundi((yaw + 1.0) * 0.5 * float(Cosmetics.TAXI3D_FRAMES - 1)), 0, FACE_SHIFT_PX6.size() - 1)]) / 6.0
	else:
		draw_texture_rect_region(frame.tex, Tuning.TAXI_RECT, frame.src, mod)
		face_dx = 0.0
	if not sticker_frame.is_empty():
		draw_texture_rect_region(sticker_frame.tex, Tuning.sticker_rect(int(sticker_frame.n), int(sticker_frame.src.size.x)), sticker_frame.src, mod)
	if sim.state != TaxiSim.State.DESTROYED:
		_draw_details(n)
		if kit_draw.is_valid():
			kit_draw.call(self)
		if sim.overheat:
			_draw_heat_strip()
	# Schadenanzeige: Funken/Rauch
	if hurt > 0.45 and int(t * 8.0) % 2 == 0:
		draw_rect(Rect2(-6 + (int(t * 13.0) % 5), -8 - (int(t * 7.0) % 3), 1, 1), Color("#ffd37a"))
	if hurt > 0.7:
		draw_rect(Rect2(4, -9 - fmod(t * 20.0, 6.0), 2, 2), Color(0.5, 0.5, 0.55, 0.7))


## Flamme als Pixelzeilen auf einem Raster von 1,25 Einheiten: je Zeile schmaler, Farbe vom heißen Kern zur roten Spitze, der Rand flackert je Zeile.
func _flame_rows(origin: Vector2, dir: Vector2, length: float, width: float, hot: Array, seed: float) -> void:
	var p := 1.25
	var n := int(length / p)
	var side := Vector2(-dir.y, dir.x)
	for r in n:
		var k := float(r) / maxf(1.0, float(n))
		var jit := roundf(sin(t * 41.0 + r * 2.3 + seed) * 0.8)
		var w := maxf(1.0, roundf(width * pow(1.0 - k, 0.65) + jit))
		var ci := mini(int(k * hot.size()), hot.size() - 1)
		var c: Color = hot[ci]
		var cen := origin + dir * (r * p)
		for j in int(w):
			var off := (float(j) - (w - 1.0) * 0.5) * p
			var cc: Color = c if absf(off) < w * 0.25 or ci >= hot.size() - 1 else hot[mini(ci + 1, hot.size() - 1)]
			var q := cen + side * off
			draw_rect(Rect2(Vector2(roundf(q.x), roundf(q.y)) - Vector2(p, p) * 0.5, Vector2(p, p)), cc)

const FIRE := [Color("#fff6c8"), Color("#ffd04a"), Color("#ff8a2e"), Color("#e8452c")]
const ICE := [Color("#e8fbff"), Color("#8fd8ff"), Color("#4fb8e8"), Color("#2a6ab8")]

func _pixel_flames(flick: float) -> void:
	if flame_main > 0.0:
		var h := 6.0 + 10.0 * flame_main * flick
		draw_circle(Vector2(0, 11.5), 4.0, Color(1.0, 0.6, 0.2, 0.22 * flame_main))
		_flame_rows(Vector2(0, 10.6), Vector2(0, 1), h, 6.0, FIRE, 0.0)
	if flame_down > 0.0:
		for sx in [-1.0, 1.0]:
			_flame_rows(Vector2(sx * 9, -5.5), Vector2(0, -1), 3.0 + 4.0 * flick, 2.6, ICE, sx)
	if absf(flame_side) > 0.05:
		var sd := -signf(flame_side)
		_flame_rows(Vector2(sd * 16.0, 0), Vector2(sd, 0), 3.0 + 6.0 * absf(flame_side) * flick, 2.8, ICE, 5.0)



# ---------------------------------------------------------------- Runde 86: kleine Details
## Trinkgeld: Münze springt aus der Kuppel hoch und fällt zurück (Klang beim Aufkommen).
## Valentinstag: eine Kusshand ist angekommen – der Fahrer errötet, kleine Herzen steigen auf.
func blush() -> void:
	blush_t = 0.0

func tip_coin() -> void:
	coin_t = 0.0

## Harte Landung: Kaffee schwappt aus der Tasse (k = Stärke 0–1).
func slosh(k: float) -> void:
	slosh_t = 0.0
	slosh_k = k

## Punkt im Taxibild in Bildeinheiten (26 × 16) → Zeichenkoordinaten; verschiebt mit dem Kopf in der Drehstufe der Mischform (face_dx).
func _u(u: float, v: float) -> Vector2:
	return Vector2(Tuning.TAXI_RECT.position.x + (u + face_dx) * Tuning.TAXI_RECT.size.x / Tuning.TAXI_UNITS.x,
		Tuning.TAXI_RECT.position.y + v * Tuning.TAXI_RECT.size.y / Tuning.TAXI_UNITS.y)

func _box(u: float, v: float, w: float, h: float, c: Color) -> void:
	var a := _u(u, v)
	var b := _u(u + w, v + h)
	draw_rect(Rect2(a, b - a), c)

func _draw_details(n: int) -> void:
	var sector := sim.level.sector if sim.level != null else 1
	# Sektor-Zubehör des Fahrers: Sonnenbrille in der Solarschmiede, Stirnlampe im Schattenring
	if sector == 5:
		var frame_c := Color("#0b0b14")
		var lens := Color("#2a3570")
		for lx in [11.5, 13.17]:                                              # zwei Gläser über den Augen (Augen: Zeilen 26–27, Spalten 72–73 und 82–83 in Größe 6)
			_box(lx, 4.17, 1.33, 0.83, frame_c)
			_box(lx + 0.17, 4.33, 1.0, 0.5, lens)
			_box(lx + 0.17, 4.33, 0.33, 0.17, Color(0.8, 0.9, 1.0, 0.9))
		_box(12.83, 4.33, 0.33, 0.17, frame_c)                                # Steg
	elif sector == 8:
		_box(12.67, 3.0, 0.83, 0.67, Color("#3a3f58"))
		_box(12.83, 3.17, 0.5, 0.33, Color("#fff6c8"))
		var c := _u(13.08, 3.33)
		draw_circle(c, 1.6, Color(1.0, 0.96, 0.75, 0.22 + 0.06 * sin(t * 3.0)))
	# Kaffeetasse am Armaturenbrett, rechts in der Kuppel
	_box(15.5, 5.5, 1.17, 1.17, Color("#f2f2f6"))
	_box(15.5, 5.5, 1.17, 0.17, Color("#6b3a1e"))
	_box(16.67, 5.83, 0.33, 0.5, Color("#f2f2f6"))
	_box(15.5, 6.5, 1.17, 0.17, Color("#b9bccc"))
	if not Settings.values.reduce_motion and idle_t > 1.0:                  # Dampf, solange das Taxi ruht
		for k in 2:
			var ph := fmod(t * 0.7 + k * 0.5, 1.0)
			_box(15.8 + k * 0.5 + sin(t * 2.0 + k) * 0.17, 5.2 - ph * 1.6, 0.17, 0.17, Color(1, 1, 1, 0.45 * (1.0 - ph)))
	if slosh_t < 0.7 and not Settings.values.reduce_motion:
		for k in 4:
			var dir := -1.0 if k % 2 == 0 else 1.0
			var sp := 0.6 + 0.35 * float(k)
			var tt := slosh_t
			_box(16.0 + dir * sp * tt * 3.0 * slosh_k, 5.4 - (2.4 * slosh_k) * tt + 6.0 * tt * tt, 0.17, 0.17, Color("#7a4524"))
	if valentine:
		_draw_valentine()
	# Hut nach Kalender auf der Kuppel
	if hat != "":
		_draw_hat()
	# Nickerchen und Hochschrecken
	if idle_t > nap_after:
		var f := Fonts.hud
		for k in 3:
			var ph := fmod((idle_t - nap_after) * 0.45 + k / 3.0, 1.0) if not Settings.values.reduce_motion else 0.3 + k * 0.25
			var p := _u(15.5 + ph * 4.0, 2.5 - ph * 4.0)
			draw_string(f, p, "z" if k < 2 else "Z", HORIZONTAL_ALIGNMENT_LEFT, -1, int(4 + 3 * ph), Color(0.85, 0.9, 1.0, 0.9 * (1.0 - ph * 0.7)))
	elif startle_t > 0.0:
		var p := _u(14.6, 0.2 - (0.8 - startle_t) * 2.0)
		draw_string(Fonts.hud, p, "!", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(1.0, 0.88, 0.3, minf(1.0, startle_t * 2.0)))
	# Trinkgeld-Münze
	if coin_t < COIN_TIME:
		var k := coin_t / COIN_TIME
		var cp := _u(13.6 + k * 1.2, 2.0 - 9.0 * k + 10.5 * k * k)
		var w := absf(cos(coin_t * 18.0))                        # dreht sich
		draw_set_transform(cp, 0.0, Vector2(maxf(0.25, w), 1.0))
		draw_circle(Vector2.ZERO, 1.25, Color("#ffcf3a"))
		draw_circle(Vector2.ZERO, 0.8, Color("#ffe98a"))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _heart(c: Vector2, s: float, col: Color) -> void:
	draw_circle(c + Vector2(-s * 0.5, 0), s * 0.55, col)
	draw_circle(c + Vector2(s * 0.5, 0), s * 0.55, col)
	draw_colored_polygon(PackedVector2Array([c + Vector2(-s * 1.02, s * 0.15), c + Vector2(s * 1.02, s * 0.15), c + Vector2(0, s * 1.25)]), col)

func _draw_valentine() -> void:
	# Herz-Duftbaum unter dem Kuppeldach: pendelt mit der Seitengeschwindigkeit
	var top := _u(15.9, 1.1)
	var swing := clampf(-sim.vel.x * 0.012, -0.7, 0.7) + (0.0 if Settings.values.reduce_motion else sin(t * 2.6) * 0.12)
	var hang := Vector2(0, 2.3).rotated(swing)
	draw_line(top, top + hang, Color(0.9, 0.9, 0.95, 0.8), 0.3)
	var hc := top + hang + Vector2(0, 0.6).rotated(swing)
	_heart(hc, 0.85, Color("#7a0f2c"))
	_heart(hc + Vector2(0, -0.1), 0.65, Color("#ff3d73"))
	if blush_t < BLUSH_TIME:
		var a := clampf(minf(blush_t * 6.0, (BLUSH_TIME - blush_t) * 2.0), 0.0, 1.0)
		var cheek := Color(1.0, 0.35, 0.55, 0.85 * a)
		_box(11.33, 5.0, 0.67, 0.33, cheek)                                  # Wangen unter den Augen
		_box(13.83, 5.0, 0.67, 0.33, cheek)
		if not Settings.values.reduce_motion:
			for k in 3:
				var ph := fmod(blush_t * 0.9 + k / 3.0, 1.0)
				var p := _u(12.5 + (k - 1) * 1.6 + sin(blush_t * 4.0 + k) * 0.4, 0.5 - ph * 5.0)
				_heart(p, 0.45 + 0.35 * ph, Color(1.0, 0.4, 0.6, a * (1.0 - ph)))

func _draw_hat() -> void:
	var base_l := _u(11.6, 0.6)
	var base_r := _u(14.6, 0.6)
	if hat == "party":
		var tip := _u(13.1, -3.6)
		draw_colored_polygon(PackedVector2Array([base_l, base_r, tip]), Color("#4fc3ff"))
		for k in 3:                                                   # Streifen
			var a := base_l.lerp(tip, 0.2 + k * 0.25)
			var b := base_r.lerp(tip, 0.2 + k * 0.25)
			draw_line(a, b, Color("#ff4fc8"), 0.8)
		draw_circle(tip, 0.9, Color("#ffe14a"))
	else:
		var peak := _u(13.6, -2.2)
		var tip := _u(15.8, -1.6 + 0.25 * sin(t * 2.0))                   # Zipfel hängt nach rechts und wippt
		draw_colored_polygon(PackedVector2Array([base_l, base_r, peak]), Color("#d6283c"))
		draw_colored_polygon(PackedVector2Array([_u(12.9, -1.4), _u(14.0, -1.0), tip]), Color("#b81f32"))
		draw_rect(Rect2(_u(11.3, 0.1), _u(14.9, 0.9) - _u(11.3, 0.1)), Color("#f4f4f8"))
		draw_circle(tip, 0.9, Color("#f4f4f8"))

