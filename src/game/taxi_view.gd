extends Node2D
## Taxi-Darstellung: Rumpf-Sprite, Fahrwerk, Düsenflammen, Beschädigung.

var sim: TaxiSim
var tex: Texture2D = Cosmetics.paint_texture()
var sticker: Texture2D = Cosmetics.sticker_texture()
var t := 0.0
var flame_main := 0.0
var flame_down := 0.0
var flame_side := 0.0
var flash := 0.0

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
			draw_line(Vector2(sx * 5.0, 5.5), Vector2(sx * Tuning.FOOT_X / Tuning.TAXI_SCALE, 5 + gl), steel, 0.7)
			draw_rect(Rect2(sx * Tuning.FOOT_X / Tuning.TAXI_SCALE - 2, 5 + gl, 4, 0.7), steel)
		if sim.gear_extended():
			var ok := sim.landing_margin()
			var lamp := Color("#5dff9a") if ok > 0.0 else Color("#ff4d6d")
			draw_rect(Rect2(-1, 7, 2, 1), lamp)
	# Flammen: aus Pixelzeilen (heißer Kern, flackernder Rand, Spitzen in Rot), Lenkdüsen blau
	var flick := 0.6 + 0.4 * sin(t * 60.0)
	_pixel_flames(flick)
	# Rumpf
	var mod := Color.WHITE
	if flash > 0.0:
		mod = Color(1, 0.4 + 0.6 * (1.0 - flash), 0.4 + 0.6 * (1.0 - flash))
	draw_texture_rect(tex, Rect2(-16, -10, 32, 20), false, mod)
	if sticker != null:
		draw_texture_rect(sticker, Rect2(-13.0, -4.2, 8.0, 8.0), false, mod)
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
