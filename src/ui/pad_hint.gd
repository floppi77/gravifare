extends Control
## Hinweis nach dem Startbildschirm: „Controller empfohlen“ – ein nachgezeichneter Controller im Xbox-Layout (aus Formen gezeichnet,
## kein Herstellerlogo) und der Hinweistext gleichzeitig auf Deutsch und Englisch (die eingestellte Sprache zuerst). Darunter, ob gerade
## ein Controller verbunden ist (live). Jede Taste, jeder Controllerknopf und jeder Mausklick geht weiter, sonst nach T_END ins Hauptmenü.
## „Weniger Bewegung“: nur Überblendungen. Inhalt auf der zentrierten 640×360-Fläche, der Hintergrund füllt das ganze Fenster (Ultrawide).
## Dev: --scene=pad_hint öffnet ihn direkt, --pad-hint-t=<s> hält die Zeit bei s Sekunden an, --pad-hint-pad=on|off täuscht den Status vor.

const Stage := preload("res://src/core/stage.gd")
const PadGlyph := preload("res://src/ui/pad_glyph.gd")

const BG := Color(0.02, 0.02, 0.055)
const CYAN := Color("#35e0d2")
const YEL := Color("#ffe14a")
const LAV := Color("#8c9cff")
const WHITE := Color("#f0f4ff")
const DIM := Color(0.47, 0.5, 0.67)
const GREEN := Color("#4cc35a")
const ORANGE := Color("#ffb02e")

const BODY_TOP := Color("#343d74")
const BODY_BOT := Color("#151a38")
const WELL := Color("#0b0e21")
const CAP := Color("#2b3262")
const CAP_RIM := Color("#4a5596")

const PAD_C := Vector2(320, 120)                # Mitte des Controllers
const PAD_K := 0.92                             # Maßstab der Controller-Einheiten (Breite ≈ 2·121·K)
const TITLE_Y := 246.0
const BODY_Y := 281.0
const STATUS_Y := 322.0

const T_IN := 0.35
const T_END := 4.8
const FADE_OUT := 0.4
const SKIP_FADE := 0.22

## Rechte Hälfte des Umrisses (oben Mitte → unten Mitte), gespiegelt ergibt das den ganzen Körper; geglättet mit Catmull-Rom.
const OUTLINE := [Vector2(0, -48), Vector2(28, -51), Vector2(54, -56), Vector2(76, -55), Vector2(92, -47), Vector2(103, -32),
	Vector2(109, -12), Vector2(114, 14), Vector2(119, 40), Vector2(121, 62), Vector2(116, 78), Vector2(103, 86), Vector2(89, 82),
	Vector2(78, 68), Vector2(66, 50), Vector2(52, 40), Vector2(28, 36), Vector2(0, 37)]
const L_STICK := Vector2(-57, -16)
const R_STICK := Vector2(29, 20)
const DPAD := Vector2(-29, 20)
const FACE := Vector2(57, -16)                  # Mitte der vier Knöpfe
const FACE_D := 12.0
const ORDER := ["A", "B", "X", "Y"]             # Reihenfolge, in der die Knöpfe aufleuchten

var t := 0.0
var frozen := false
var still := false
var leaving := false
var out_t := 0.0
var out_dur := FADE_OUT
var hold_t := 0.0
var fake_pad := ""
var stage: Control
var canvas: Control
var fade: ColorRect
var glow_tex: GradientTexture2D
var stars: Array = []
var body_pts := PackedVector2Array()

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	still = Settings.values.reduce_motion
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--pad-hint-t="):
			t = float(a.substr(13))
			frozen = true
		elif a.begins_with("--pad-hint-pad="):
			fake_pad = a.substr(15)
	if is_inside_tree():                         # (Tests rufen _ready ohne Baum auf: dann kein Vorladen, keine Musik)
		if ResourceLoader.load_threaded_get_status(Flow.MENU) == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			ResourceLoader.load_threaded_request(Flow.MENU)
		Music.play_theme("menu")
	glow_tex = GradientTexture2D.new()
	glow_tex.fill = GradientTexture2D.FILL_RADIAL
	glow_tex.fill_from = Vector2(0.5, 0.5)
	glow_tex.fill_to = Vector2(1.0, 0.5)
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	glow_tex.gradient = g
	glow_tex.width = 64
	glow_tex.height = 64
	var rng := RandomNumberGenerator.new()
	rng.seed = 1771                              # derselbe Sternenhimmel wie im Startbildschirm
	for i in 170:
		stars.append([rng.randf(), rng.randf(), rng.randf_range(0.12, 0.5), rng.randf() * TAU, rng.randf_range(0.6, 1.8)])
	body_pts = _body_outline()
	stage = Stage.make(self)
	canvas = Control.new()
	canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.size = Stage.SIZE
	canvas.draw.connect(_draw_canvas)
	stage.add_child(canvas)
	fade = ColorRect.new()
	fade.color = Color(0, 0, 0, 1)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(fade)
	_apply()

func _process(delta: float) -> void:
	if not frozen:
		t += delta
	if leaving:
		out_t += delta
		if out_t >= out_dur:
			if Input.is_anything_pressed() and hold_t < 1.5:      # gehaltene Taste nicht ins Menü mitnehmen
				hold_t += delta
			else:
				_to_menu()
				return
	elif not frozen and t >= T_END:
		_leave(FADE_OUT)
	_apply()

func _input(e: InputEvent) -> void:
	if not (e is InputEventKey or e is InputEventJoypadButton or e is InputEventMouseButton):
		return
	if is_inside_tree():
		get_viewport().set_input_as_handled()
	var press := e.is_pressed() and not e.is_echo()
	if press and not leaving and (t > 0.3 or frozen):
		_leave(SKIP_FADE)

func _leave(dur: float) -> void:
	leaving = true
	out_t = 0.0
	out_dur = dur

func _to_menu() -> void:
	set_process(false)
	var ps: PackedScene = null
	if ResourceLoader.load_threaded_get_status(Flow.MENU) != ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
		ps = ResourceLoader.load_threaded_get(Flow.MENU) as PackedScene
	if ps != null:
		get_tree().change_scene_to_packed(ps)
	else:
		get_tree().change_scene_to_file(Flow.MENU)

static func _ramp(x: float, a: float, b: float) -> float:
	return clampf((x - a) / (b - a), 0.0, 1.0)

static func _ease_out(x: float) -> float:
	x = clampf(x, 0.0, 1.0)
	return 1.0 - pow(1.0 - x, 3.0)

## Ist gerade ein Controller verbunden? (--pad-hint-pad=on|off für Screenshots)
func pad_connected() -> bool:
	if fake_pad == "on":
		return true
	if fake_pad == "off":
		return false
	return not Input.get_connected_joypads().is_empty()

## Sprachen in Anzeigereihenfolge: die eingestellte zuerst, die andere darunter.
static func lang_order() -> Array:
	if Loc.available().size() < 2:               # Browser-Fassung: nur Englisch, keine zweite Zeile
		return ["en"]
	var cur := TranslationServer.get_locale().substr(0, 2)
	if cur == "de" or cur == "en":
		return ["en", "de"] if cur == "en" else ["de", "en"]
	return [cur, "en"]                            # Französisch/Spanisch: eingestellte Sprache und Englisch

func _txt(lang: String, key: String) -> String:
	return Loc.text_in(lang, key) if Loc != null and Loc.has_method("text_in") else tr(key)

func _apply() -> void:
	var fa := 1.0 - _ramp(t, 0.0, T_IN)
	if leaving:
		fa = maxf(fa, clampf(out_t / out_dur, 0.0, 1.0))
	fade.color.a = fa
	queue_redraw()
	canvas.queue_redraw()

func _draw() -> void:
	var sz := size
	draw_rect(Rect2(Vector2.ZERO, sz), BG)
	var c := Stage.margin(self) + PAD_C
	var r := Vector2(460, 260)
	draw_texture_rect(glow_tex, Rect2(c - r, r * 2.0), false, Color(0.09, 0.08, 0.22, 0.55))
	for s in stars:
		var tw := 1.0 if still else 0.7 + 0.3 * sin(t * s[4] + s[3])
		draw_rect(Rect2(Vector2(s[0] * sz.x, s[1] * sz.y), Vector2(0.5, 0.5)), Color(0.75, 0.8, 1.0, s[2] * tw))

# ---------- Controller ----------

static func _catmull(pts: Array, steps: int) -> PackedVector2Array:
	var out := PackedVector2Array()
	var n := pts.size()
	for i in n:
		var p0: Vector2 = pts[(i - 1 + n) % n]
		var p1: Vector2 = pts[i]
		var p2: Vector2 = pts[(i + 1) % n]
		var p3: Vector2 = pts[(i + 2) % n]
		for s in steps:
			var u := float(s) / steps
			var u2 := u * u
			var u3 := u2 * u
			out.append(0.5 * ((2.0 * p1) + (-p0 + p2) * u + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * u2 + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * u3))
	return out

## Geschlossener Umriss des Körpers in Controller-Einheiten (Mitte 0,0).
static func _body_outline() -> PackedVector2Array:
	var ring: Array = []
	for p in OUTLINE:
		ring.append(p)
	for i in range(OUTLINE.size() - 2, 0, -1):
		ring.append(Vector2(-OUTLINE[i].x, OUTLINE[i].y))
	return _catmull(ring, 6)

func _p(v: Vector2, lift := 0.0) -> Vector2:
	return PAD_C + v * PAD_K + Vector2(0, lift)

func _glow(c: Vector2, r: float, col: Color) -> void:
	canvas.draw_texture_rect(glow_tex, Rect2(c - Vector2(r, r), Vector2(r, r) * 2.0), false, col)

func _neon(pts: PackedVector2Array, col: Color, w: float) -> void:
	canvas.draw_polyline(pts, Color(col, col.a * 0.07), w * 4.5, true)
	canvas.draw_polyline(pts, Color(col, col.a * 0.18), w * 2.2, true)
	canvas.draw_polyline(pts, col, w, true)

## Offene, geglättete Linie durch die Punkte (Catmull-Rom, Endpunkte doppelt).
static func _smooth(pts: Array, steps: int) -> PackedVector2Array:
	var ring: Array = [pts[0]] + pts + [pts[-1]]
	var out := PackedVector2Array()
	for i in range(1, ring.size() - 2):
		for s in steps:
			var u := float(s) / steps
			var p0: Vector2 = ring[i - 1]
			var p1: Vector2 = ring[i]
			var p2: Vector2 = ring[i + 1]
			var p3: Vector2 = ring[i + 2]
			out.append(0.5 * ((2.0 * p1) + (-p0 + p2) * u + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * u * u + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * u * u * u))
	out.append(pts[-1])
	return out

## Dicke Linie mit runden Enden.
func _band(pts: PackedVector2Array, col: Color, w: float) -> void:
	canvas.draw_polyline(pts, col, w, true)
	canvas.draw_circle(pts[0], w * 0.5, col, true, -1.0, true)
	canvas.draw_circle(pts[-1], w * 0.5, col, true, -1.0, true)

## Schultertaste (Bumper) auf der Oberkante und dahinter der Trigger.
func _shoulder(side: float, lift: float, a: float) -> void:
	var tr_pts: Array = []
	for v in [Vector2(46, -63), Vector2(62, -67), Vector2(77, -64.5)]:
		tr_pts.append(_p(Vector2(v.x * side, v.y), lift))
	var bu_pts: Array = []
	for v in [Vector2(34, -56.5), Vector2(55, -61), Vector2(75, -59.5), Vector2(90, -52.5), Vector2(99, -42)]:
		bu_pts.append(_p(Vector2(v.x * side, v.y), lift))
	var trig := _smooth(tr_pts, 6)
	var bump := _smooth(bu_pts, 6)
	_band(trig, Color(0.07, 0.08, 0.17, a), 9.0 * PAD_K)
	canvas.draw_polyline(trig, Color(LAV, 0.18 * a), 0.8, true)
	_band(bump, Color(0.15, 0.17, 0.34, a), 6.5 * PAD_K)
	var hi := PackedVector2Array()
	for p in bump:
		hi.append(p + Vector2(0, -1.9 * PAD_K))
	canvas.draw_polyline(hi, Color(CAP_RIM, 0.75 * a), 1.0 * PAD_K, true)

func _stick(c: Vector2, off: Vector2, a: float) -> void:
	var k := PAD_K
	canvas.draw_circle(c, 17.0 * k, Color(WELL, a), true, -1.0, true)
	canvas.draw_arc(c, 17.0 * k, 0.0, TAU, 40, Color(CAP_RIM, 0.5 * a), 1.0, true)
	var cc := c + off * k
	canvas.draw_circle(cc + Vector2(0, 1.6) * k, 13.0 * k, Color(0, 0, 0, 0.5 * a), true, -1.0, true)
	canvas.draw_circle(cc, 13.0 * k, Color(CAP, a), true, -1.0, true)
	canvas.draw_arc(cc, 9.0 * k, 0.0, TAU, 32, Color(0.1, 0.12, 0.26, a), 2.4 * k, true)
	canvas.draw_arc(cc, 13.0 * k, PI * 1.05, PI * 1.75, 16, Color(1, 1, 1, 0.22 * a), 1.2 * k, true)

func _dpad(c: Vector2, a: float) -> void:
	var k := PAD_K
	canvas.draw_circle(c, 17.0 * k, Color(WELL, a), true, -1.0, true)
	canvas.draw_arc(c, 17.0 * k, 0.0, TAU, 40, Color(CAP_RIM, 0.5 * a), 1.0, true)
	var l := 12.5 * k
	var w := 4.6 * k
	for r in [Rect2(c.x - l, c.y - w, l * 2.0, w * 2.0), Rect2(c.x - w, c.y - l, w * 2.0, l * 2.0)]:
		canvas.draw_rect(Rect2(r.position + Vector2(0, 1.4 * k), r.size), Color(0, 0, 0, 0.5 * a))
		canvas.draw_rect(r, Color(CAP, a))
	canvas.draw_rect(Rect2(c.x - l, c.y - w, l * 2.0, 1.0 * k), Color(1, 1, 1, 0.16 * a))
	canvas.draw_rect(Rect2(c.x - w, c.y - l, w * 2.0, 1.0 * k), Color(1, 1, 1, 0.16 * a))
	canvas.draw_circle(c, 2.6 * k, Color(0.1, 0.12, 0.26, a), true, -1.0, true)

## Leuchtstärke eines Knopfs: nacheinander kurz aufleuchten (A, B, X, Y), danach eine ruhige Wiederholung.
func _lit(i: int) -> float:
	if still:
		return 0.0
	var st := 0.75 + 0.22 * i
	var p := _ramp(t, st, st + 0.12) * (1.0 - _ramp(t, st + 0.2, st + 0.55))
	var lp := fposmod(t - 2.4, 2.2)
	var st2 := 0.22 * i
	return maxf(p, 0.55 * _ramp(lp, st2, st2 + 0.1) * (1.0 - _ramp(lp, st2 + 0.18, st2 + 0.5)) * _ramp(t, 2.4, 2.5))

func _face(a: float) -> void:
	var k := PAD_K
	var offs := {"A": Vector2(0, 1), "B": Vector2(1, 0), "X": Vector2(-1, 0), "Y": Vector2(0, -1)}
	for i in ORDER.size():
		var id: String = ORDER[i]
		var c := _p(FACE + offs[id] * FACE_D)
		var d := 15.0 * k
		var col: Color = PadGlyph.COLORS[id]
		var lit := _lit(i)
		if lit > 0.0:
			_glow(c, d * 1.5, Color(col, 0.6 * lit * a))
		canvas.draw_circle(c + Vector2(0, 1.4 * k), d * 0.5, Color(0, 0, 0, 0.55 * a), true, -1.0, true)
		canvas.draw_circle(c, d * 0.5, Color(col.lerp(Color.WHITE, 0.35 * lit), a), true, -1.0, true)
		canvas.draw_arc(c, d * 0.5 - 0.6 * k, PI * 1.1, PI * 1.7, 12, Color(1, 1, 1, 0.35 * a), 1.0 * k, true)
		var f: Font = Fonts.hud
		var fs := maxi(5, int(round(d * 0.6)))
		var w := f.get_string_size(id, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		canvas.draw_string(f, Vector2(c.x - w * 0.5, c.y + float(fs) * 0.36), id, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0.05, 0.06, 0.15, a))

func _small_buttons(a: float) -> void:
	var k := PAD_K
	# Ansicht (links), Teilen (Mitte), Menü (rechts)
	var vc := _p(Vector2(-16, -19))
	var mc := _p(Vector2(16, -19))
	for c in [vc, mc]:
		canvas.draw_circle(c, 4.6 * k, Color(WELL, a), true, -1.0, true)
		canvas.draw_arc(c, 4.6 * k, 0.0, TAU, 20, Color(CAP_RIM, 0.7 * a), 0.9 * k, true)
	var q := 1.6 * k
	canvas.draw_rect(Rect2(vc + Vector2(-q * 1.2, -q * 1.2), Vector2(q * 1.5, q * 1.5)), Color(WHITE, 0.75 * a), false, 0.7 * k)
	canvas.draw_rect(Rect2(vc + Vector2(-q * 0.3, -q * 0.3), Vector2(q * 1.5, q * 1.5)), Color(WHITE, 0.75 * a), false, 0.7 * k)
	for j in 3:
		var y := mc.y + (j - 1) * 1.5 * k
		canvas.draw_line(Vector2(mc.x - 2.2 * k, y), Vector2(mc.x + 2.2 * k, y), Color(WHITE, 0.75 * a), 0.7 * k, true)
	var sc := _p(Vector2(0, -8))
	canvas.draw_rect(Rect2(sc - Vector2(3.6, 1.8) * k, Vector2(7.2, 3.6) * k), Color(WELL, a))
	canvas.draw_rect(Rect2(sc - Vector2(3.6, 1.8) * k, Vector2(7.2, 3.6) * k), Color(CAP_RIM, 0.6 * a), false, 0.8 * k)
	# Leuchtknopf oben in der Mitte: eigenes Zeichen des Spiels (Taxi-Gelb im Neonring), kein Herstellerlogo
	var gc := _p(Vector2(0, -36))
	var pulse := 1.0 if still else 0.75 + 0.25 * sin(t * 2.6)
	_glow(gc, 15.0 * k, Color(CYAN, 0.45 * pulse * a))
	canvas.draw_circle(gc, 8.5 * k, Color(WELL, a), true, -1.0, true)
	canvas.draw_arc(gc, 8.5 * k, 0.0, TAU, 32, Color(CYAN, 0.9 * pulse * a), 1.4 * k, true)
	canvas.draw_circle(gc, 3.2 * k, Color(YEL, a), true, -1.0, true)

func _draw_pad(a: float, lift: float) -> void:
	_shoulder(1.0, lift, a)
	_shoulder(-1.0, lift, a)
	var pts := PackedVector2Array()
	var cols := PackedColorArray()
	for v in body_pts:
		pts.append(_p(v, lift))
		cols.append(Color(BODY_TOP.lerp(BODY_BOT, clampf((v.y + 55.0) / 150.0, 0.0, 1.0)), a))
	canvas.draw_polygon(pts, cols)
	# Schatten unten in den Griffen und Glanz an der Oberkante
	var top_v: Array = []
	for v in body_pts:
		if v.y < -44.0 and absf(v.x) < 92.0:
			top_v.append(v)
	top_v.sort_custom(func(p: Vector2, q: Vector2) -> bool: return p.x < q.x)
	var top := PackedVector2Array()
	for v in top_v:
		top.append(_p(v * 0.97 + Vector2(0, 1.5), lift))
	if top.size() > 1:
		canvas.draw_polyline(top, Color(1, 1, 1, 0.12 * a), 1.4 * PAD_K, true)
	var loop := pts.duplicate()
	loop.append(pts[0])
	_neon(loop, Color(CYAN, 0.7 * a), 1.1)
	var wob := Vector2.ZERO
	if not still:
		var w := _ramp(t, 1.6, 2.0)
		wob = Vector2(cos(t * 2.2), sin(t * 2.2)) * 2.6 * w
	_stick(_p(L_STICK, lift), wob, a)
	_stick(_p(R_STICK, lift), Vector2.ZERO, a)
	_dpad(_p(DPAD, lift), a)
	_face(a)
	_small_buttons(a)

# ---------- Texte ----------

func _center(f: Font, y: float, txt: String, fs: int, col: Color, glow := 0.0) -> void:
	var w := f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var x := 320.0 - w * 0.5
	if glow > 0.0:
		canvas.draw_string_outline(f, Vector2(x, y), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 4, Color(col, 0.10 * glow * col.a))
		canvas.draw_string_outline(f, Vector2(x, y), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 2, Color(col, 0.22 * glow * col.a))
	canvas.draw_string(f, Vector2(x, y), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)

func _draw_canvas() -> void:
	var pa := _ramp(t, 0.1, 0.55)
	var lift := 0.0 if still else 8.0 * (1.0 - _ease_out(_ramp(t, 0.1, 0.7)))
	if pa > 0.0:
		_draw_pad(pa, lift)
	var langs := lang_order()
	var ta := _ramp(t, 0.35, 0.8)
	if ta > 0.0:
		_center(Fonts.title, TITLE_Y, _txt(langs[0], "PAD_HINT_TITLE"), 26, Color(YEL, ta), 1.0)
		if langs.size() > 1:
			_center(Fonts.title, TITLE_Y + 17.0, _txt(langs[1], "PAD_HINT_TITLE"), 18, Color(LAV, ta), 0.6)
	var ba := _ramp(t, 0.55, 1.0)
	if ba > 0.0:
		_center(Fonts.ui, BODY_Y, _txt(langs[0], "PAD_HINT_BODY"), 9, Color(WHITE, 0.92 * ba))
		if langs.size() > 1:
			_center(Fonts.ui, BODY_Y + 12.0, _txt(langs[1], "PAD_HINT_BODY"), 8, Color(DIM, ba))
	var sa := _ramp(t, 0.75, 1.2)
	if sa > 0.0:
		var on := pad_connected()
		var key := "PAD_HINT_ON" if on else "PAD_HINT_OFF"
		var txt := "  ·  ".join(langs.map(func(l): return _txt(l, key)))
		var f: Font = Fonts.hud
		var fs := 8
		var w := f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var x := 320.0 - (w + 10.0) * 0.5
		var col := GREEN if on else ORANGE
		var dc := Vector2(x + 3.0, STATUS_Y - 2.8)
		_glow(dc, 7.0, Color(col, 0.5 * sa))
		canvas.draw_circle(dc, 2.6, Color(col, sa), true, -1.0, true)
		canvas.draw_string(f, Vector2(x + 10.0, STATUS_Y), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(col.lerp(WHITE, 0.35), sa))
	var ha := _ramp(t, 1.0, 1.4) * 0.8
	if ha > 0.0:
		var hint := "  ·  ".join(langs.map(func(l): return _txt(l, "PAD_HINT_GO")))
		var hf: Font = Fonts.hud
		var hw := hf.get_string_size(hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 7).x
		canvas.draw_string(hf, Vector2(634.0 - hw, 352.0), hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 7, Color(DIM, ha))
