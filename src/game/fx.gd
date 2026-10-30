extends Node2D
## Licht, Schattenwurf und Umgebungspartikel des Levels: Lichtquellen an Pads/Tor/Unterständen,
## Occluder aus den Fels-Tiles, Schwebestaub. Taxi-eigene Effekte liegen in taxi_view.gd.

const T := Tuning.TILE
static var _tex: GradientTexture2D

var run: Run
var level: LevelData
var pad_lights := {}
var gate_light: PointLight2D
var gate_occluder: LightOccluder2D

static func light_texture() -> GradientTexture2D:
	if _tex == null:
		var g := Gradient.new()
		g.offsets = PackedFloat32Array([0.0, 0.35, 0.7, 1.0])
		g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.55), Color(1, 1, 1, 0.16), Color(1, 1, 1, 0)])
		_tex = GradientTexture2D.new()
		_tex.gradient = g
		_tex.fill = GradientTexture2D.FILL_RADIAL
		_tex.fill_from = Vector2(0.5, 0.5)
		_tex.fill_to = Vector2(1.0, 0.5)
		_tex.width = 256
		_tex.height = 256
	return _tex

static func make_light(color: Color, radius: float, energy: float, shadows := false) -> PointLight2D:
	var l := PointLight2D.new()
	l.texture = light_texture()
	l.texture_scale = radius * 2.0 / 256.0
	l.color = color
	l.energy = energy
	l.height = radius * 0.55          # Höhe über der Ebene: Normal-Maps der Tiles reagieren darauf
	l.shadow_enabled = shadows
	l.shadow_filter = Light2D.SHADOW_FILTER_NONE
	l.shadow_color = Color(0, 0, 0, 0.7)
	return l

## Gemeinsame Partikel-Fabrik im Pixel-Art-Stil (eckige Teilchen, additive Mischung optional).
static func make_particles(amount: int, lifetime: float, speed: Vector2, size: float, c0: Color, c1: Color, additive := true) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.amount = amount
	p.lifetime = lifetime
	p.local_coords = false
	p.emitting = false
	p.initial_velocity_min = speed.x
	p.initial_velocity_max = speed.y
	p.scale_amount_min = size * 0.7
	p.scale_amount_max = size
	var g := Gradient.new()
	g.colors = PackedColorArray([c0, c1])
	p.color_ramp = g
	var tex := PlaceholderTexture2D.new()
	tex.size = Vector2(1, 1)
	p.texture = tex
	p.gravity = Vector2.ZERO
	if additive:
		var m := CanvasItemMaterial.new()
		m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		m.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
		p.material = m
	else:
		var m2 := CanvasItemMaterial.new()
		m2.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
		p.material = m2
	return p

func setup(r: Run) -> void:
	run = r
	level = r.level
	for c in get_children():
		c.queue_free()
	pad_lights.clear()
	_build_occluders()
	_build_lights()
	if not Settings.values.reduce_motion:
		_build_motes()

func _build_occluders() -> void:
	# Zusammenhängende Fels-Läufe je Zeile -> ein Rechteck-Occluder (wenige Knoten).
	for cy in level.height:
		var cx := 0
		while cx < level.width:
			if level.cell(cx, cy) == "#" or level.cell(cx, cy) == "^" or (level.cell(cx, cy) >= "1" and level.cell(cx, cy) <= "9") or level.cell(cx, cy) == "F":
				var x1 := cx
				while x1 + 1 < level.width and _opaque(x1 + 1, cy):
					x1 += 1
				add_child(_occluder(Rect2(cx * T, cy * T, (x1 - cx + 1) * T, T)))
				cx = x1 + 1
			else:
				cx += 1
	if not level.exit_cells.is_empty():
		gate_occluder = _occluder(level.exit_rect())
		gate_occluder.visible = not run.exit_open
		add_child(gate_occluder)

func _opaque(cx: int, cy: int) -> bool:
	var c := level.cell(cx, cy)
	return c == "#" or c == "^" or (c >= "1" and c <= "9") or c == "F"

func _occluder(r: Rect2) -> LightOccluder2D:
	var o := LightOccluder2D.new()
	var poly := OccluderPolygon2D.new()
	poly.polygon = PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)])
	o.occluder = poly
	return o

func _build_lights() -> void:
	for id in level.pads:
		var p: Dictionary = level.pads[id]
		var col := Color("#ffa530") if p.fuel else Color("#35e0d2")
		var l := make_light(col, 90.0, 2.3)
		l.position = Vector2(p.center, p.row * T - 6.0)
		add_child(l)
		pad_lights[id] = l
		var sh: Rect2 = p.get("shelter", Rect2())
		if sh.size.x > 0.0:
			var w := make_light(Color("#ffd27a"), 52.0, 2.4)
			w.position = sh.get_center() + Vector2(0, 2)
			add_child(w)
	if not level.exit_cells.is_empty():
		gate_light = make_light(Color("#ff4d6d"), 90.0, 0.5)
		gate_light.position = level.exit_rect().get_center() + Vector2(0, 10)
		add_child(gate_light)

func _build_motes() -> void:
	var motes := make_particles(46, 9.0, Vector2(2, 7), 1.0, Color(0.8, 0.85, 1.0, 0.35), Color(0.8, 0.85, 1.0, 0.0), true)
	var sz := level.pixel_size()
	motes.position = sz * 0.5
	motes.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	motes.emission_rect_extents = sz * 0.5
	motes.direction = Vector2(0.4, -1.0)
	motes.spread = 60.0
	motes.preprocess = 9.0
	motes.emitting = true
	add_child(motes)

var _t := 0.0
func _process(delta: float) -> void:
	if run == null:
		return
	_t += delta
	var target := run.target_pad()
	for id in pad_lights:
		var l: PointLight2D = pad_lights[id]
		var base_col := Color("#ffa530") if level.pads[id].fuel else Color("#35e0d2")
		if id == target:
			l.color = base_col.lerp(Color("#ffe14a"), 0.6)
			l.energy = 3.0 + 0.8 * sin(_t * 6.0)
		else:
			l.color = base_col
			l.energy = 2.0
	if gate_light != null:
		if run.exit_open:
			gate_light.color = Color("#5dff9a")
			gate_light.energy = 3.0 + 0.4 * sin(_t * 4.0)
		else:
			gate_light.color = Color("#ff4d6d")
			gate_light.energy = 0.8 + (0.5 if int(_t * 3.0) % 2 == 0 else 0.0)
	if gate_occluder != null:
		gate_occluder.visible = not run.exit_open
