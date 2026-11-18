extends Control
## Startbildschirm vor dem Hauptmenü (danach kommt der Controller-Hinweis pad_hint.gd): GraviFare-Logo mit wanderndem Glanzstreifen in den oberen zwei Dritteln, darunter links das
## Studio (Quantum Abacus Games, Neon-Abakus: Perlen gleiten auf ihre Plätze, die Quantenperle flackert zwischen zwei Zuständen,
## ein Elektron kreist) und rechts „Made with Godot“ (offizielles Logo, unverzerrt). Jede Taste, jeder Controllerknopf und jeder
## Mausklick überspringt. „Weniger Bewegung“: nur Überblendungen. Inhalt auf der zentrierten 640×360-Fläche, der Hintergrund füllt
## das ganze Fenster (Ultrawide). Dev: --splash-t=<s> hält die Zeit bei s Sekunden an (Screenshots, kein automatischer Wechsel).

const Stage := preload("res://src/core/stage.gd")
const SHINE := preload("res://src/ui/logo_shine.gdshader")
const LOGO := preload("res://assets/art/logo.png")
const HALO := preload("res://assets/art/splash/logo_halo.png")
const GODOT_LOGO := preload("res://assets/art/splash/godot_logo.png")
const PAD_HINT := "res://src/ui/pad_hint.tscn"

const LOGO_CROP := Rect2(13, 210, 1749, 426)    # sichtbarer Bereich von logo.png (wie tools/art/splash/gen_splash.py)
const HALO_PAD := 160.0                         # Rand des Scheins um LOGO_CROP (in Pixeln von logo.png)
const LOGO_W := 413.0                           # Breite des GraviFare-Logos (Spieleinheiten)
const LOGO_C := Vector2(320, 120)               # Mitte des Logos: obere zwei Drittel
const ROW_Y := 305.0                            # Mittellinie der unteren Reihe (Studio | Godot)
const LABEL_Y := 277.0                          # Grundlinie der Beschriftungen darüber
const GODOT_H := 32.0
const PAIR_GAP := 67.0                          # Abstand zwischen Studio und Godot
const ES := 0.14                                # Emblem-Einheiten → Spieleinheiten (Rahmen 300 × 230)
const EMB_TXT := 26.7                           # Abstand Emblem → Schriftzug

const BG := Color(0.02, 0.02, 0.055)
const CYAN := Color("#35e0d2")
const YEL := Color("#ffe14a")
const LAV := Color("#8c9cff")
const PINK := Color("#ff5cbe")
const WHITE := Color("#f0f4ff")
const LABEL_COL := Color(0.51, 0.55, 0.75)

const T_IN := 0.4                               # Aufblende aus Schwarz
const T_END := 6.2                              # danach Abblende und Hauptmenü
const FADE_OUT := 0.5
const SKIP_FADE := 0.25
const SWEEPS := [1.1, 3.9]                      # Start der Glanzstreifen
const SWEEP_DUR := 1.2
const ROW0 := [-112.0, -78.0, -44.0, 70.0, 104.0]     # Pixelperlen (gelb)
const ROW1 := [-112.0, -78.0]                        # feste Quantenperlen (pink)
const GHOST := [-10.0, 90.0]                         # die Perle in Überlagerung: zwei Zustände
const ROW2 := [-112.0, -78.0, -44.0, -10.0, 104.0]   # runde Perlen (lavendel)
const ORBIT := Vector3(250.0, 78.0, -0.2793)         # Halbachsen und Drehung der Umlaufbahn (Emblem-Einheiten, Bogenmaß)

var t := 0.0
var frozen := false
var still := false
var leaving := false
var out_t := 0.0
var out_dur := FADE_OUT
var hold_t := 0.0
var stage: Control
var studio: Control
var logo: Sprite2D
var halo: Sprite2D
var shine: ShaderMaterial
var fade: ColorRect
var glow_tex: GradientTexture2D
var f_q: FontVariation
var stars: Array = []
var _lay := {}

## Normaler Start ohne Entwicklerschalter zeigt den Startbildschirm; --splash erzwingt ihn auch mit anderen Schaltern.
static func wanted(args: PackedStringArray) -> bool:
	return args.is_empty() or args.has("--splash")

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	still = Settings.values.reduce_motion
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--splash-t="):
			t = float(a.substr(11))
			frozen = true
	if is_inside_tree():                         # (Tests rufen _ready ohne Baum auf: dann kein Vorladen, keine Musik)
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
	rng.seed = 1771
	for i in 170:
		stars.append([rng.randf(), rng.randf(), rng.randf_range(0.12, 0.5), rng.randf() * TAU, rng.randf_range(0.6, 1.8)])
	f_q = FontVariation.new()
	f_q.base_font = Fonts.hud.base_font if Fonts.hud is FontVariation else Fonts.hud
	f_q.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): 700}
	stage = Stage.make(self)
	var k := LOGO_W / LOGO_CROP.size.x
	halo = Sprite2D.new()
	halo.texture = HALO
	halo.position = LOGO_C
	halo.scale = (LOGO_CROP.size + Vector2.ONE * HALO_PAD * 2.0) * k / HALO.get_size()
	stage.add_child(halo)
	logo = Sprite2D.new()
	logo.texture = LOGO
	logo.region_enabled = true
	logo.region_rect = LOGO_CROP
	logo.position = LOGO_C
	logo.scale = Vector2(k, k)
	shine = ShaderMaterial.new()
	shine.shader = SHINE
	logo.material = shine
	stage.add_child(logo)
	studio = Control.new()
	studio.mouse_filter = Control.MOUSE_FILTER_IGNORE
	studio.size = Stage.SIZE
	studio.draw.connect(_draw_studio)
	stage.add_child(studio)
	fade = ColorRect.new()
	fade.color = Color(0, 0, 0, 1)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(fade)
	_layout()
	_apply()

## Maße der unteren Reihe: Studio (Emblem + Schriftzug) und Godot-Logo als gemeinsam zentriertes Paar.
func _layout() -> void:
	var wq := _spaced_w(f_q, "QUANTUM", 13, 1.33)
	var wa := _spaced_w(Fonts.title, "ABACUS", 19, 1.0)
	var text_w := wq + 5.3 + wa
	var orbit_l := (ORBIT.x - 150.0) * ES
	var emb_w := 300.0 * ES
	var studio_w := orbit_l + emb_w + EMB_TXT + text_w
	var gw := GODOT_H * float(GODOT_LOGO.get_width()) / float(GODOT_LOGO.get_height())
	var x0 := 320.0 - (studio_w + PAIR_GAP + gw) * 0.5
	_lay = {
		"emblem": Vector2(x0 + orbit_l + emb_w * 0.5, ROW_Y),
		"tx": x0 + orbit_l + emb_w + EMB_TXT, "wq": wq, "text_w": text_w,
		"studio_c": x0 + studio_w * 0.5,
		"godot": Rect2(x0 + studio_w + PAIR_GAP, ROW_Y - GODOT_H * 0.5, gw, GODOT_H),
		"div": x0 + studio_w + PAIR_GAP * 0.5,
	}

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
	if press and not leaving and (t > 0.15 or frozen):
		_leave(SKIP_FADE)

func _leave(dur: float) -> void:
	leaving = true
	out_t = 0.0
	out_dur = dur

## Weiter zum Controller-Hinweis (pad_hint.gd), der dann das hier vorgeladene Hauptmenü übernimmt.
func _to_menu() -> void:
	set_process(false)
	get_tree().change_scene_to_file(PAD_HINT)

static func _ease_out(x: float) -> float:
	x = clampf(x, 0.0, 1.0)
	return 1.0 - pow(1.0 - x, 3.0)

static func _ramp(x: float, a: float, b: float) -> float:
	return clampf((x - a) / (b - a), 0.0, 1.0)

## Zustand für die aktuelle Zeit setzen (Logo, Glanz, Blende) und neu zeichnen.
func _apply() -> void:
	var a := _ramp(t, 0.25, 1.05)
	logo.modulate.a = a
	halo.modulate.a = a
	var k := LOGO_W / LOGO_CROP.size.x
	var s := 1.0 if still else 1.06 - 0.06 * _ease_out(_ramp(t, 0.25, 1.25))
	logo.scale = Vector2(k, k) * s
	halo.scale = (LOGO_CROP.size + Vector2.ONE * HALO_PAD * 2.0) * k * s / HALO.get_size()
	var sw := -1.0
	if not still:
		for st in SWEEPS:
			var u: float = (t - st) / SWEEP_DUR
			if u >= 0.0 and u <= 1.0:
				sw = lerpf(-0.1, 1.1, u)
	var lw := float(LOGO.get_width())
	shine.set_shader_parameter("sweep", (LOGO_CROP.position.x + sw * LOGO_CROP.size.x) / lw if sw > -1.0 else -1.0)
	var fa := 1.0 - _ramp(t, 0.0, T_IN)
	if leaving:
		fa = maxf(fa, clampf(out_t / out_dur, 0.0, 1.0))
	fade.color.a = fa
	queue_redraw()
	studio.queue_redraw()

func _draw() -> void:
	var sz := size
	draw_rect(Rect2(Vector2.ZERO, sz), BG)
	var c := Stage.margin(self) + LOGO_C
	var r := Vector2(520, 300)
	draw_texture_rect(glow_tex, Rect2(c - r, r * 2.0), false, Color(0.09, 0.08, 0.22, 0.55))
	for s in stars:
		var tw := 1.0 if still else 0.7 + 0.3 * sin(t * s[4] + s[3])
		draw_rect(Rect2(Vector2(s[0] * sz.x, s[1] * sz.y), Vector2(0.5, 0.5)), Color(0.75, 0.8, 1.0, s[2] * tw))

# ---------- Studio und Godot ----------

func _spaced_w(f: Font, txt: String, fs: int, sp: float) -> float:
	var w := 0.0
	for ch in txt:
		w += f.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	return w + sp * (txt.length() - 1)

func _spaced(f: Font, pos: Vector2, txt: String, fs: int, sp: float, col: Color, glow := 0.0) -> void:
	var x := pos.x
	for ch in txt:
		if glow > 0.0:
			studio.draw_string_outline(f, Vector2(x, pos.y), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 4, Color(col, 0.10 * glow * col.a))
			studio.draw_string_outline(f, Vector2(x, pos.y), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 2, Color(col, 0.22 * glow * col.a))
		studio.draw_string(f, Vector2(x, pos.y), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
		x += f.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + sp

func _label(cx: float, txt: String, a: float) -> void:
	var f: Font = Fonts.hud
	_spaced(f, Vector2(cx - _spaced_w(f, txt, 6, 2.0) * 0.5, LABEL_Y), txt, 6, 2.0, Color(LABEL_COL, a))

## Neonlinie: zwei weiche, breite Durchgänge unter dem Kern.
func _neon(pts: PackedVector2Array, col: Color, w: float) -> void:
	studio.draw_polyline(pts, Color(col, col.a * 0.07), w * 4.5, true)
	studio.draw_polyline(pts, Color(col, col.a * 0.18), w * 2.2, true)
	studio.draw_polyline(pts, col, w, true)

func _glow(c: Vector2, r: float, col: Color) -> void:
	studio.draw_texture_rect(glow_tex, Rect2(c - Vector2(r, r), Vector2(r, r) * 2.0), false, col)

func _ellipse(c: Vector2, a0: float, a1: float, n := 64) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var cr := cos(ORBIT.z)
	var sr := sin(ORBIT.z)
	for i in n + 1:
		var a := lerpf(a0, a1, float(i) / n)
		var x := ORBIT.x * ES * cos(a)
		var y := ORBIT.y * ES * sin(a)
		pts.append(c + Vector2(x * cr - y * sr, x * sr + y * cr))
	return pts

func _rounded(c: Vector2, half: Vector2, rad: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var corners := [[Vector2(half.x - rad, -half.y + rad), -PI * 0.5], [Vector2(half.x - rad, half.y - rad), 0.0],
		[Vector2(-half.x + rad, half.y - rad), PI * 0.5], [Vector2(-half.x + rad, -half.y + rad), PI]]
	for cn in corners:
		for i in 9:
			var a: float = cn[1] + PI * 0.5 * i / 8.0
			pts.append(c + cn[0] + Vector2(cos(a), sin(a)) * rad)
	pts.append(pts[0])
	return pts

## Position einer gleitenden Perle: startet am rechten Ende der Stange und gleitet auf ihren Platz.
func _bead_x(target: float, start_t: float) -> Array:
	if still:
		return [target, _ramp(t, start_t, start_t + 0.4)]
	var u := _ramp(t, start_t, start_t + 0.45)
	return [lerpf(132.0, target, _ease_out(u)), _ramp(t, start_t, start_t + 0.12)]

func _draw_studio() -> void:
	var c: Vector2 = _lay.emblem
	var u := ES
	# Hinweis zum Überspringen (rechts unten)
	var ha := _ramp(t, 1.0, 1.4) * 0.8
	var hf: Font = Fonts.hud
	var hint := tr("TRANS_SKIP")
	var hw := hf.get_string_size(hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 7).x
	studio.draw_string(hf, Vector2(634.0 - hw, 352.0), hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 7, Color(0.47, 0.5, 0.67, ha))
	var base_a := _ramp(t, 1.3, 1.75)
	if base_a <= 0.0:
		return
	var bw := 30.0 * u
	# Umlaufbahn hinten, Rahmen, Stangen
	_neon(_ellipse(c, PI, TAU), Color(LAV, 0.55 * base_a), 3.0 * u)
	_neon(_rounded(c, Vector2(150, 115) * u, 26.0 * u), Color(CYAN, base_a), 7.0 * u)
	var rods := [c.y - 62.0 * u, c.y, c.y + 62.0 * u]
	for ry in rods:
		studio.draw_line(Vector2(c.x - 143.0 * u, ry), Vector2(c.x + 143.0 * u, ry), Color(CYAN, 0.55 * base_a), 3.0 * u, true)
	# Reihe 1: Pixelperlen
	for i in ROW0.size():
		var bx: Array = _bead_x(ROW0[i], 1.5 + 0.07 * i)
		if bx[1] <= 0.0:
			continue
		var p := Vector2(c.x + bx[0] * u, rods[0])
		_glow(p, bw * 1.3, Color(YEL, 0.35 * bx[1]))
		studio.draw_rect(Rect2(p - Vector2(bw, bw) * 0.5, Vector2(bw, bw)), Color(YEL, bx[1]))
		var q := bw / 5.0
		studio.draw_rect(Rect2(p - Vector2(bw, bw) * 0.5 + Vector2(q, q), Vector2(q, q)), Color(1, 0.99, 0.86, bx[1]))
	# Reihe 2: feste Quantenperlen und die Perle in Überlagerung
	for i in ROW1.size():
		var bx: Array = _bead_x(ROW1[i], 1.65 + 0.07 * i)
		if bx[1] <= 0.0:
			continue
		var p := Vector2(c.x + bx[0] * u, rods[1])
		_glow(p, bw * 1.3, Color(PINK, 0.4 * bx[1]))
		studio.draw_circle(p, bw * 0.5, Color(PINK, bx[1]), true, -1.0, true)
	var ga := _ramp(t, 1.85, 2.0)
	if ga > 0.0:
		var settle := _ramp(t, 2.7, 2.75)
		for j in GHOST.size():
			var on := 1.0
			if not still and settle < 1.0:          # Flackern zwischen den zwei Zuständen, immer schneller
				var ph := (t - 1.85) * (6.0 + 18.0 * _ramp(t, 1.85, 2.7))
				on = 1.0 if (int(ph) % 2 == j) else 0.15
			var a := ga * on
			var p := Vector2(c.x + GHOST[j] * u, rods[1])
			var pulse := 1.0 + (0.35 * (1.0 - _ramp(t, 2.7, 3.0)) if settle > 0.0 and not still else 0.0)
			_glow(p, bw * 1.4 * pulse, Color(PINK, 0.4 * a))
			studio.draw_arc(p, bw * 0.5 - 2.0 * u, 0.0, TAU, 32, Color(PINK, a), 4.0 * u, true)
			studio.draw_circle(p, bw * 0.25, Color(PINK, 0.45 * a), true, -1.0, true)
		var wa := _ramp(t, 2.7, 3.0) if not still else _ramp(t, 1.85, 2.2)
		if wa > 0.0:
			var x0 := c.x + (GHOST[0] + 17.0) * u
			var x1 := c.x + (GHOST[1] - 17.0) * u
			var seg := 3
			var n := 30
			for i in range(0, n, seg + 1):
				var pts := PackedVector2Array()
				for m in seg + 1:
					var f := float(i + m) / n
					pts.append(Vector2(lerpf(x0, x1, f), rods[1] + 11.0 * u * sin(f * 4.0 * PI)))
				studio.draw_polyline(pts, Color(PINK, 0.8 * wa), 3.0 * u, true)
	# Reihe 3: runde Perlen
	for i in ROW2.size():
		var bx: Array = _bead_x(ROW2[i], 1.8 + 0.07 * i)
		if bx[1] <= 0.0:
			continue
		var p := Vector2(c.x + bx[0] * u, rods[2])
		_glow(p, bw * 1.3, Color(LAV, 0.35 * bx[1]))
		studio.draw_circle(p, bw * 0.5, Color(LAV, bx[1]), true, -1.0, true)
		studio.draw_circle(p + Vector2(-0.17, -0.25) * bw, bw * 0.09, Color(0.98, 0.98, 1.0, bx[1]), true, -1.0, true)
	# Umlaufbahn vorne und Elektron
	_neon(_ellipse(c, 0.0, PI), Color(LAV, base_a), 3.0 * u)
	var ea := 0.55 if still else 0.55 + (t - 1.3) * 1.4
	var e := _ellipse(c, ea, ea, 1)[0]
	var back := fposmod(ea, TAU) > PI
	var e_a := base_a * (0.5 if back else 1.0)
	_glow(e, 22.0 * u, Color(WHITE, 0.5 * e_a))
	studio.draw_circle(e, 9.0 * u, Color(WHITE, e_a), true, -1.0, true)
	# Schriftzug
	var ta := _ramp(t, 1.6, 2.1)
	if ta > 0.0:
		var tx: float = _lay.tx
		_spaced(f_q, Vector2(tx, ROW_Y + 2.7), "QUANTUM", 13, 1.33, Color(WHITE, ta), 1.0)
		_spaced(Fonts.title, Vector2(tx + _lay.wq + 5.3, ROW_Y + 2.7), "ABACUS", 19, 1.0, Color(YEL, ta), 1.0)
		var gw := _spaced_w(Fonts.hud, "GAMES", 6, 4.0)
		_spaced(Fonts.hud, Vector2(tx + _lay.text_w * 0.5 - gw * 0.5, ROW_Y + 12.7), "GAMES", 6, 4.0, Color(CYAN, ta), 1.0)
		_label(_lay.studio_c, tr("SPLASH_BY"), ta)
	# Trenner und Godot
	var da := _ramp(t, 1.9, 2.4)
	if da > 0.0:
		studio.draw_line(Vector2(_lay.div, ROW_Y - 14.7), Vector2(_lay.div, ROW_Y + 14.7), Color(0.27, 0.31, 0.47, da), -1.0)
		var gr: Rect2 = _lay.godot
		studio.draw_texture_rect(GODOT_LOGO, gr, false, Color(1, 1, 1, da))
		_label(gr.get_center().x, tr("SPLASH_MADE_WITH"), da)
