extends Control
## Animierter Hauptmenü-Hintergrund: ziehender Nebel, funkelnde Sterne, Sternschnuppen, ferner Raumverkehr,
## ein Taxi im Vordergrund mit Abgasspur, driftende Skyline-Ebenen und Dunst. Bei „Weniger Bewegung“ statisch.

var far: Texture2D = preload("res://assets/art/bg_s1_far.png")
var mid: Texture2D = preload("res://assets/art/bg_s1_mid.png")
var near: Texture2D = preload("res://assets/art/bg_s1_near.png")
var art: Texture2D = preload("res://assets/art/bg_s1.png")
var shade := GradientTexture2D.new()
var taxi: Texture2D = Cosmetics.paint_texture()
var sticker: Texture2D = Cosmetics.sticker_texture()
var t := 0.0
var still := false
var stars: Array = []
var cars: Array = []
var meteors: Array = []
var meteor_timer := 2.0
var hero_t := -4.0
var hero := true                 # Taxi im Vordergrund (die Credits haben ihr eigenes)
var rng := RandomNumberGenerator.new()
var _wf := 1.0                    # Breitenfaktor (Ultrawide > 1): Sterne, Verkehr und Kacheln verteilen sich über die ganze Breite
var _oy := 0.0                    # Versatz nach unten bei höheren Fenstern (Skyline bleibt unten)
const Calendar := preload("res://src/core/calendar.gd")
var fireworks := Calendar.fireworks()     # Runde 86: Silvester und Neujahr – Feuerwerk über der Stadt
var hat := Calendar.hat()                 # Runde 86: Partyhut (Jahrestag) bzw. Weihnachtsmütze auf dem Taxi
var rockets: Array = []                   # {x, y, vy, age, fuse, col, burst: Array}
var rocket_timer := 0.6

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	still = Settings.values.reduce_motion
	var grad := Gradient.new()
	grad.set_color(0, Color(0.02, 0.03, 0.1, 0.74))
	grad.set_color(1, Color(0.02, 0.03, 0.1, 0.0))
	shade.gradient = grad
	shade.width = 256
	shade.height = 4
	rng.seed = 424242
	for i in 90:
		stars.append([rng.randf() * 640.0, rng.randf() * 120.0, rng.randf() * TAU, rng.randf_range(0.8, 2.2), rng.randf_range(0.6, 2.2)])
	for i in 7:
		var d := rng.randf()
		var dir := 1.0 if rng.randf() < 0.5 else -1.0
		cars.append({"x": rng.randf() * 700.0 - 30.0, "y": rng.randf_range(70.0, 250.0), "v": dir * rng.randf_range(10.0, 34.0) * (0.5 + d), "s": 0.2 + d * 0.32, "a": 0.28 + d * 0.5, "p": rng.randf() * TAU})

func _process(delta: float) -> void:
	if still:
		return
	t += delta
	hero_t += delta
	for c in cars:
		c.x += c.v * delta
		if c.v > 0.0 and c.x > 700.0 * _wf:
			c.x = -40.0
		elif c.v < 0.0 and c.x < -60.0:
			c.x = 690.0 * _wf
	meteor_timer -= delta
	if meteor_timer <= 0.0:
		meteor_timer = rng.randf_range(2.5, 6.5)
		meteors.append({"x": rng.randf_range(120.0, 640.0 * _wf), "y": rng.randf_range(10.0, 110.0), "age": 0.0})
	for m in meteors:
		m.age += delta
	meteors = meteors.filter(func(m): return m.age < 0.9)
	if fireworks:
		_step_fireworks(delta)
	if hero_t > 11.0:
		hero_t = -3.0
	queue_redraw()

func _draw() -> void:
	_wf = maxf(size.x, 640.0) / 640.0
	_oy = maxf(size.y - 360.0, 0.0)
	var cover := maxf(size.x / 640.0, size.y / 360.0)
	var fw := 640.0 * cover
	var fh := 360.0 * cover
	var sway := sin(t * 0.05) * 6.0 * cover        # langsames Schwenken über das Bild
	draw_texture_rect(art, Rect2((size.x - fw * 1.06) * 0.5 + sway, (size.y - fh * 1.06) * 0.5, fw * 1.06, fh * 1.06), false)
	draw_texture_rect(shade, Rect2(0, 0, size.x * 0.6, size.y), false)      # links dunkler: Menü bleibt lesbar
	_draw_stars()
	_draw_meteors()
	if fireworks:
		_draw_fireworks()
	_draw_cars(false)
	_haze(240.0, 0.16, 0.0)
	_draw_cars(true)
	_draw_hero()

func _draw_stars() -> void:
	for s in stars:
		var tw := 0.5 + 0.5 * sin(t * float(s[4]) + float(s[2]))
		var a := 0.25 + 0.75 * tw
		var sz: float = float(s[3]) * 0.67
		var c := Color(0.85, 0.9, 1.0, a)
		var sx := float(s[0]) * _wf
		draw_rect(Rect2(sx, float(s[1]), sz, sz), c)
		if sz > 1.2 and tw > 0.85:       # kurzes Funkeln als Kreuz
			draw_rect(Rect2(sx - 1.5, float(s[1]) + sz * 0.3, sz + 3.0, 0.5), Color(c.r, c.g, c.b, a * 0.6))
			draw_rect(Rect2(sx + sz * 0.3, float(s[1]) - 1.5, 0.5, sz + 3.0), Color(c.r, c.g, c.b, a * 0.6))

func _draw_meteors() -> void:
	for m in meteors:
		var k: float = m.age / 0.9
		var head := Vector2(m.x - k * 150.0, m.y + k * 60.0)
		for i in 14:
			var f := float(i) / 14.0
			var p := head + Vector2(f * 46.0, -f * 18.0)
			draw_rect(Rect2(p.x, p.y, 1.0, 0.67), Color(1, 0.95, 0.85, (1.0 - f) * (1.0 - k) * 0.9))

## Horizontal scrollende Ebene; jede zweite Kachel gespiegelt, damit die Nähte nahtlos wirken.
func _tiled(tex: Texture2D, speed: float, alpha: float) -> void:
	var off := fmod(t * speed, 1280.0)
	var base := int(floor(off / 640.0))
	var x0 := -(off - base * 640.0)
	for k in int(ceil(size.x / 640.0)) + 1:
		var flip := (base + k) % 2 == 1
		var x := roundf((x0 + k * 640.0) * 3.0) / 3.0
		if flip:
			draw_set_transform(Vector2(x + 640.0, _oy), 0.0, Vector2(-1, 1))
			draw_texture_rect(tex, Rect2(0, 0, 640, 360), false, Color(1, 1, 1, alpha))
		else:
			draw_set_transform(Vector2(x, _oy), 0.0, Vector2.ONE)
			draw_texture_rect(tex, Rect2(0, 0, 640, 360), false, Color(1, 1, 1, alpha))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _skyline(tex: Texture2D, speed: float, alpha: float) -> void:
	_tiled(tex, speed, alpha)

func _haze(y0: float, a: float, phase: float) -> void:
	var drift := sin(t * 0.15 + phase) * 16.0
	var c0 := Color(0.45, 0.32, 0.65, 0.0)
	var c1 := Color(0.45, 0.32, 0.65, a)
	y0 += _oy
	var xr := size.x + 20.0
	draw_polygon(PackedVector2Array([Vector2(-20 + drift, y0), Vector2(xr + drift, y0), Vector2(xr + drift, y0 + 45), Vector2(-20 + drift, y0 + 45)]), PackedColorArray([c0, c0, c1, c1]))
	draw_polygon(PackedVector2Array([Vector2(-20 + drift, y0 + 45), Vector2(xr + drift, y0 + 45), Vector2(xr + drift, y0 + 90), Vector2(-20 + drift, y0 + 90)]), PackedColorArray([c1, c1, c0, c0]))

## Ferner Verkehr: kleine, dunkle Taxi-Silhouetten mit Positionslichtern; front = vor der nahen Skyline.
func _draw_cars(front: bool) -> void:
	for c in cars:
		var is_front: bool = float(c.s) > 0.38
		if is_front != front:
			continue
		var dir := 1.0 if float(c.v) > 0.0 else -1.0
		var sz := taxi.get_size() / 3.0 * float(c.s)          # Größe aus der Textur, nicht fest eingetragen (das Taxi wird neu gezeichnet)
		draw_set_transform(Vector2(c.x, c.y), 0.0, Vector2(dir, 1.0))
		var tint := Color(0.55, 0.6, 0.95, c.a)
		for i in 10:       # Abgasspur
			draw_rect(Rect2(-sz.x * 0.5 - 2.0 - i * 3.0 * float(c.s) * 3.0, -0.3, 2.2 * float(c.s) * 3.0, 0.7), Color(1.0, 0.6, 0.3, float(c.a) * 0.5 * (1.0 - float(i) / 10.0)))
		draw_texture_rect(taxi, Rect2(-sz.x * 0.5, -sz.y * 0.5, sz.x, sz.y), false, tint)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		if int(t * 1.6 + float(c.p)) % 2 == 0:
			draw_rect(Rect2(float(c.x) - dir * sz.x * 0.4, float(c.y) - sz.y * 0.55, 1.0, 0.8), Color(1, 0.3, 0.4, float(c.a)))

## Großes Taxi im Vordergrund: fliegt alle ~11 s gemächlich durchs Bild, mit Funkenspur.
func _draw_hero() -> void:
	if not hero or hero_t < 0.0 or hero_t > 9.0:
		return
	var k := hero_t / 9.0
	var x := lerpf(-50.0, 700.0 * _wf, k)
	var y := 96.0 + sin(k * TAU * 1.5) * 10.0
	draw_set_transform(Vector2(x, y), 0.14 * cos(k * TAU * 1.5), Vector2.ONE)
	var ts := taxi.get_size() * (2.0 / 3.0)                                   # 96×60 → 64×40 Einheiten, aus der Textur gerechnet
	for i in 22:
		var f := float(i) / 22.0
		draw_rect(Rect2(-ts.x * 0.5 - 2.0 - i * 3.2, -1.0 + sin(t * 20.0 + i) * 0.5, 3.0, 2.0 - f), Color(1.0, 0.7 - f * 0.3, 0.3, (1.0 - f) * 0.55))
	draw_texture_rect(taxi, Rect2(-ts * 0.5, ts), false)
	if sticker != null:
		draw_texture_rect(sticker, Rect2(Vector2(-0.40625 * ts.x, -0.21 * ts.y), Vector2.ONE * 0.25 * ts.x), false)
	if hat != "":
		_draw_hat(Vector2(0.0, -ts.y * 0.47), ts.x / 26.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

# ---------------------------------------------------------------- Runde 86: Kalender
func _draw_hat(top: Vector2, u: float) -> void:
	var bl := top + Vector2(-1.6, 0.4) * u
	var br := top + Vector2(1.6, 0.4) * u
	if hat == "party":
		var tip := top + Vector2(0.0, -4.0) * u
		draw_colored_polygon(PackedVector2Array([bl, br, tip]), Color("#4fc3ff"))
		for k in 3:
			draw_line(bl.lerp(tip, 0.2 + k * 0.25), br.lerp(tip, 0.2 + k * 0.25), Color("#ff4fc8"), maxf(1.0, u * 0.5))
		draw_circle(tip, u * 0.8, Color("#ffe14a"))
	else:
		var tip := top + Vector2(2.6, -2.6 + 0.2 * sin(t * 2.0)) * u
		draw_colored_polygon(PackedVector2Array([bl, br, top + Vector2(0.8, -2.8) * u, tip]), Color("#d6283c"))
		draw_rect(Rect2(top + Vector2(-1.9, -0.2) * u, Vector2(3.8, 0.9) * u), Color("#f4f4f8"))
		draw_circle(tip, u * 0.8, Color("#f4f4f8"))

const ROCKET_COLS := [Color("#ffe14a"), Color("#ff4fc8"), Color("#4fc3ff"), Color("#5dff9a"), Color("#ff8a3a"), Color("#ffffff")]

func _step_fireworks(delta: float) -> void:
	rocket_timer -= delta
	if rocket_timer <= 0.0:
		rocket_timer = rng.randf_range(0.5, 1.4)
		rockets.append({"x": rng.randf_range(260.0, 620.0 * _wf), "y": 330.0, "vy": -rng.randf_range(190.0, 250.0), "age": 0.0,
			"fuse": rng.randf_range(0.9, 1.3), "col": ROCKET_COLS[rng.randi() % ROCKET_COLS.size()], "burst": []})
	for r in rockets:
		r.age += delta
		if r.burst.is_empty():
			r.y += r.vy * delta
			r.vy += 60.0 * delta
			if r.age >= r.fuse:
				for i in 44:
					var a := TAU * float(i) / 44.0 + rng.randf() * 0.1
					var sp := rng.randf_range(45.0, 85.0)
					r.burst.append([r.x, r.y, cos(a) * sp, sin(a) * sp])
		else:
			for p in r.burst:
				p[0] += p[2] * delta
				p[1] += p[3] * delta
				p[2] *= 1.0 - 1.4 * delta
				p[3] = p[3] * (1.0 - 1.4 * delta) + 30.0 * delta
	rockets = rockets.filter(func(r): return r.age < float(r.fuse) + 1.6)

func _draw_fireworks() -> void:
	for r in rockets:
		var col: Color = r.col
		if r.burst.is_empty():
			draw_rect(Rect2(r.x - 0.7, r.y + _oy, 1.4, 3.0), Color(1.0, 0.85, 0.6, 0.9))
			continue
		var age := float(r.age) - float(r.fuse)
		var fade := 1.0 - clampf(age / 1.6, 0.0, 1.0)
		if age < 0.15:                                                        # Blitz beim Zerplatzen
			draw_circle(Vector2(float(r.x), float(r.y) + _oy), 10.0 * (1.0 - age / 0.15), Color(col.r, col.g, col.b, 0.35))
		for p in r.burst:
			var pp := Vector2(float(p[0]), float(p[1]) + _oy)
			draw_circle(pp, 2.4, Color(col.r, col.g, col.b, fade * 0.25))      # Schein
			draw_rect(Rect2(pp - Vector2(1.1, 1.1), Vector2(2.2, 2.2)), Color(col.r, col.g, col.b, fade))
			draw_rect(Rect2(pp - Vector2(0.5, 0.5), Vector2(1.0, 1.0)), Color(1, 1, 1, fade * 0.8))
