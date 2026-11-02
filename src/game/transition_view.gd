extends Control
## Levelwechsel-Overlay. Zeitachse t (Sekunden):
##   0 – 2,0   altes Level blendet in den Weltraum aus
##   2,0 – 5,6 Zwischensequenz: Taxi fliegt durchs All (Sterne, Planeten, Titelkarte)
##   5,6 – 7,6 neues Level blendet ein; darunter fliegt das Taxi zur Startplattform
## Zeichnet nur; die Steuerung (Laden, Anflug, Überspringen) liegt in game.gd.

const T_OUT := 2.0
const T_IN := 5.6
const T_END := 7.6

var t := -1.0
var last_t := -1.0
var vt := -1.0                    # Anzeigezeit: läuft weiter, auch wenn die Zeitachse t auf den Funkspruch wartet (Taxi, Planeten und Sterne bleiben in Bewegung)
var title_sector := ""
var title_level := ""
var info := ""
var radio_speaker := ""
var radio_text := ""
var radio_t0 := 2.15
var radio_len := 3.0
var radio_age := 0.0              # Sekunden seit Beginn des Funkspruchs (unabhängig von der Flugzeit: Text bleibt, bis die Sprache zu Ende ist)
var skip_hint := ""
var space_bg: Texture2D = preload("res://assets/art/space_bg.png")
var taxi_tex: Texture2D = Cosmetics.paint_texture()
var sticker_tex: Texture2D = Cosmetics.sticker_texture()
var planets: Array[Texture2D] = [preload("res://assets/art/planet_1.png"), preload("res://assets/art/planet_2.png"), preload("res://assets/art/planet_3.png")]
## [Startzeit, y, Größe (Einheiten), Planet, Geschwindigkeit]
const PLANET_SCHEDULE := [[0.6, 72.0, 128.0, 0, 62.0], [2.7, 250.0, 192.0, 1, 95.0], [4.3, 118.0, 64.0, 2, 80.0]]
var stars: Array = []
var scroll := 0.0
const Stage := preload("res://src/core/stage.gd")      # Ränder bei Ultrawide/hohen Fenstern: Weltraum füllt alles, Texte bleiben auf 640×360

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261030
	for i in 170:
		var layer := rng.randi_range(0, 2)
		stars.append([rng.randf() * 640.0, rng.randf() * 360.0, layer, rng.randf()])

static func smooth(x: float) -> float:
	x = clampf(x, 0.0, 1.0)
	return x * x * (3.0 - 2.0 * x)

func overlay_alpha() -> float:
	if t < 0.0:
		return 0.0
	if t < T_OUT:
		return smooth(t / T_OUT)
	if t < T_IN:
		return 1.0
	return 1.0 - smooth((t - T_IN) / ((T_END - T_IN) * 0.85))

func flight_speed() -> float:
	## Sternscroll-Geschwindigkeit (Einheiten/s): beschleunigt beim Ausblenden, bremst vor dem Anflug.
	return lerpf(30.0, 260.0, smooth(vt / T_OUT)) * (1.0 - 0.75 * smooth((vt - 5.0) / 1.4))

func _process(delta: float) -> void:
	if t < 0.0:
		vt = -1.0
	else:
		var restarted := t < last_t - 0.001                       # neue Sequenz: Anzeigezeit beginnt wieder bei t
		vt = maxf(vt + delta, t) if vt >= 0.0 and not restarted else t          # nie hinter t (Überspringen springt vor), bleibt aber beim Warten nicht stehen
		scroll += flight_speed() * delta
		queue_redraw()
	last_t = t

func _draw() -> void:
	var a := overlay_alpha()
	if t < 0.0 or a <= 0.002:
		return
	var white := Color(1, 1, 1, a)
	var m := Stage.margin(self)
	draw_texture_rect(space_bg, Rect2(-m, Stage.view(self)), false, white)
	_draw_planets(a)
	_draw_stars(a)
	if vt >= T_OUT - 0.4 and vt < T_IN + 0.3:
		_draw_taxi(a)
	_draw_titles(a)

func _draw_stars(a: float) -> void:
	var sp := flight_speed()
	var cols := [Color(0.65, 0.7, 1.0), Color(0.9, 0.92, 1.0), Color(1.0, 0.95, 0.8)]
	for s in stars:
		var layer: int = s[2]
		var factor: float = [0.25, 0.6, 1.4][layer]
		var vs := Stage.view(self)
		var m := Stage.margin(self)
		var x := fposmod(float(s[0]) * vs.x / 640.0 - scroll * factor, vs.x) - m.x
		var y: float = float(s[1]) * vs.y / 360.0 - m.y
		var c: Color = cols[layer]
		c.a = a * (0.55 + 0.45 * float(s[3]))
		var size: float = [0.67, 1.0, 1.33][layer]
		if layer == 2 and sp > 90.0:
			var ln: float = (sp - 60.0) * 0.12 * (0.5 + float(s[3]))
			draw_rect(Rect2(x, y, ln, size * 0.67), Color(c.r, c.g, c.b, c.a * 0.55))
		draw_rect(Rect2(x, y, size, size), c)

func _draw_planets(a: float) -> void:
	for p in PLANET_SCHEDULE:
		var mx := Stage.margin(self).x
		var x: float = 700.0 + mx - (vt - float(p[0])) * float(p[4])
		var sz: float = p[2]
		if x < -sz - mx or x > 720.0 + mx:
			continue
		draw_texture_rect(planets[int(p[3])], Rect2(roundf(x * 3.0) / 3.0 - sz * 0.5, float(p[1]) - sz * 0.5, sz, sz), false, Color(1, 1, 1, a))

## Fortschritt 0..1 des Taxiflugs → Wegstrecke 0..1: Mindesttempo 55 % des Mittelwerts, nie Stillstand.
static func taxi_path(p: float) -> float:
	p = clampf(p, 0.0, 1.0)
	return 0.55 * p + 0.45 * smooth(p)

func _draw_taxi(a: float) -> void:
	## Ein durchgehender Flug von links nach rechts über das ganze Bild: nie Stillstand (Mindesttempo 55 % des mittleren Tempos), am Ende etwas schneller.
	var p := clampf((vt - (T_OUT - 0.4)) / (T_IN - (T_OUT - 0.4)), 0.0, 1.0)
	var u := taxi_path(p)
	var leave := clampf((p - 0.65) / 0.35, 0.0, 1.0)
	var mx := Stage.margin(self).x
	var x := lerpf(-70.0 - mx, 735.0 + mx, u)
	var y := 176.0 + sin(vt * 1.9) * 6.0 - leave * leave * 10.0
	var rot := 0.12 + sin(vt * 1.3) * 0.03 + leave * 0.12
	draw_set_transform(Vector2(x, y), rot, Vector2.ONE)
	var flick := 0.7 + 0.3 * sin(vt * 55.0)
	var len := (26.0 + 18.0 * flick) * (0.8 + 0.5 * smooth(vt / T_OUT) + leave)
	# Antriebsstrahl nach hinten (links), mit Kern
	draw_colored_polygon(PackedVector2Array([Vector2(-31, -4), Vector2(-31, 4), Vector2(-31 - len, 0)]), Color(1.0, 0.5, 0.18, a * 0.9))
	draw_colored_polygon(PackedVector2Array([Vector2(-31, -2), Vector2(-31, 2), Vector2(-31 - len * 0.55, 0)]), Color(1.0, 0.94, 0.65, a))
	for i in 5:
		var lx := -34.0 - len - float(i) * 26.0 - fmod(vt * 90.0, 26.0)
		draw_rect(Rect2(lx, -7.0 + i * 3.4, 14.0 + i * 4.0, 0.67), Color(0.7, 0.85, 1.0, a * 0.35))
	draw_texture_rect(taxi_tex, Rect2(-32, -20, 64, 40), false, Color(1, 1, 1, a))
	if sticker_tex != null:
		draw_texture_rect(sticker_tex, Rect2(-26.0, -8.4, 16.0, 16.0), false, Color(1, 1, 1, a))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _draw_radio() -> void:
	var ra := smooth(radio_age / 0.35) * (1.0 - smooth((radio_age - radio_len) / 0.35))
	if ra > 0.003 and radio_text != "":
		var col := Color(0.55, 0.95, 0.9, ra)
		draw_string(Fonts.ui, Vector2(0, 244), "[ %s ]" % radio_speaker, HORIZONTAL_ALIGNMENT_CENTER, 640, 8, Color(0.4, 0.8, 0.75, ra * 0.9))
		# lange Sprüche umbrechen (höchstens 580 px breit)
		var lines: Array = []
		var line := ""
		for word in radio_text.split(" "):
			var cand := word if line == "" else line + " " + word
			if Fonts.ui.get_string_size(cand, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x > 580.0 and line != "":
				lines.append(line)
				line = word
			else:
				line = cand
		if line != "":
			lines.append(line)
		for i in lines.size():
			draw_string(Fonts.ui, Vector2(0, 258 + 13 * i), lines[i], HORIZONTAL_ALIGNMENT_CENTER, 640, 11, col)

func _draw_titles(a: float) -> void:
	_draw_radio()
	var ta := smooth((t - 2.9) / 0.6) * (1.0 - smooth((t - 5.35) / 0.4))
	if ta > 0.003:
		var font := Fonts.hud
		var cx := 320.0
		draw_string(font, Vector2(0, 286), title_sector, HORIZONTAL_ALIGNMENT_CENTER, 640, 11, Color(0.65, 0.78, 1.0, ta))
		draw_string(Fonts.title, Vector2(0, 308), title_level, HORIZONTAL_ALIGNMENT_CENTER, 640, 30, Color(1.0, 0.88, 0.3, ta))
		if info != "":
			draw_string(font, Vector2(0, 326), info, HORIZONTAL_ALIGNMENT_CENTER, 640, 10, Color(0.8, 0.85, 1.0, ta * 0.9))
	if t > 0.8 and t < T_IN:
		draw_string(Fonts.hud, Vector2(0, 350), skip_hint, HORIZONTAL_ALIGNMENT_RIGHT, 632, 8, Color(0.7, 0.75, 0.95, a * 0.6))
