extends Node2D
## Taxi-Darstellung: Rumpf-Sprite, Fahrwerk, Düsenflammen, Beschädigung.

var sim: TaxiSim
var tex: Texture2D = preload("res://assets/art/taxi.png")
var t := 0.0
var flame_main := 0.0
var flame_down := 0.0
var flame_side := 0.0
var flash := 0.0

func bind(s: TaxiSim) -> void:
	sim = s

func sync_state() -> void:
	## Wird einmal pro Physik-Tick aufgerufen; Position wird dank Interpolation geglättet.
	position = sim.pos
	rotation = sim.tilt
	var ti := sim.thrust_in
	flame_main = clampf(-ti.y, 0.0, 1.0) if sim.fuel > 0.0 else 0.0
	flame_down = clampf(ti.y, 0.0, 1.0) if sim.fuel > 0.0 else 0.0
	flame_side = ti.x if sim.fuel > 0.0 else 0.0

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
		var gl := Tuning.GEAR_LEN * g
		var steel := Color("#c9cfee")
		for sx in [-1.0, 1.0]:
			draw_line(Vector2(sx * 5.0, 5.5), Vector2(sx * Tuning.FOOT_X, 5 + gl), steel, 0.7)
			draw_rect(Rect2(sx * Tuning.FOOT_X - 2, 5 + gl, 4, 0.7), steel)
		if sim.gear_extended():
			var ok := sim.landing_margin()
			var lamp := Color("#5dff9a") if ok > 0.0 else Color("#ff4d6d")
			draw_rect(Rect2(-1, 7, 2, 1), lamp)
	# Flammen
	var flick := 0.6 + 0.4 * sin(t * 60.0)
	if flame_main > 0.0:
		var h := 4.0 + 8.0 * flame_main * flick
		draw_colored_polygon(PackedVector2Array([Vector2(-3, 8.5), Vector2(3, 8.5), Vector2(0, 8.5 + h)]), Color("#ff8a2e"))
		draw_colored_polygon(PackedVector2Array([Vector2(-1.5, 8.5), Vector2(1.5, 8.5), Vector2(0, 8.5 + h * 0.6)]), Color("#fff0a0"))
	if flame_down > 0.0:
		var h2 := 3.0 + 4.0 * flick
		for sx in [-1.0, 1.0]:
			draw_colored_polygon(PackedVector2Array([Vector2(sx * 9 - 1, -5), Vector2(sx * 9 + 1, -5), Vector2(sx * 9, -5 - h2)]), Color("#8fd8ff"))
	if absf(flame_side) > 0.05:
		var s := -signf(flame_side)
		var w := 3.0 + 6.0 * absf(flame_side) * flick
		var x0 := s * 15.5
		draw_colored_polygon(PackedVector2Array([Vector2(x0, -1), Vector2(x0, 1), Vector2(x0 + s * w, 0)]), Color("#8fd8ff"))
	# Rumpf
	var mod := Color.WHITE
	if flash > 0.0:
		mod = Color(1, 0.4 + 0.6 * (1.0 - flash), 0.4 + 0.6 * (1.0 - flash))
	draw_texture_rect(tex, Rect2(-16, -10, 32, 20), false, mod)
	# Schadenanzeige: Funken/Rauch
	if hurt > 0.45 and int(t * 8.0) % 2 == 0:
		draw_rect(Rect2(-6 + (int(t * 13.0) % 5), -8 - (int(t * 7.0) % 3), 1, 1), Color("#ffd37a"))
	if hurt > 0.7:
		draw_rect(Rect2(4, -9 - fmod(t * 20.0, 6.0), 2, 2), Color(0.5, 0.5, 0.55, 0.7))
