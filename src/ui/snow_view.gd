extends Control
## Runde 86: Schnee über allem (Menü, Level, Credits …) an Nikolaus (6.12.) und den Weihnachtstagen (24.–26.12.); Debug-Menü kann ihn erzwingen.
## Liegt in einer eigenen CanvasLayer über allen Szenen (angelegt von Flow), fängt keine Maus ab. Leicht und halbdurchsichtig, damit Anzeigen lesbar bleiben.
## Bei „Weniger Bewegung“ fallen weniger Flocken langsamer.

const Calendar := preload("res://src/core/calendar.gd")
const COUNT := 220
var flakes: Array = []            # [x 0–1, y 0–1, Größe, Fallgeschwindigkeit, Phase]
var rng := RandomNumberGenerator.new()
var t := 0.0
var _check := 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rng.seed = 6122
	for i in COUNT:
		flakes.append([rng.randf(), rng.randf(), rng.randf_range(0.8, 2.4), rng.randf_range(0.035, 0.09), rng.randf() * TAU])
	visible = Calendar.snow()

func _process(delta: float) -> void:
	_check -= delta
	if _check <= 0.0:
		_check = 1.0
		visible = Calendar.snow()
	if not visible:
		return
	var calm: bool = Settings.values.reduce_motion
	t += delta
	for f in flakes:
		f[1] += f[3] * delta * (0.4 if calm else 1.0)
		if f[1] > 1.02:
			f[1] = -0.02
			f[0] = rng.randf()
	queue_redraw()

func _draw() -> void:
	var s := size
	var u := s.y / 360.0                                     # Größe in Bildpunkten je Spieleinheit (Fenster 640×360 × n)
	var n := COUNT / 2 if Settings.values.reduce_motion else COUNT
	for i in n:
		var f: Array = flakes[i]
		var x: float = fmod(float(f[0]) + 0.012 * sin(t * 0.8 + float(f[4])), 1.0) * s.x
		var y: float = float(f[1]) * s.y
		var r: float = float(f[2]) * u
		draw_rect(Rect2(roundf(x), roundf(y), maxf(1.0, roundf(r)), maxf(1.0, roundf(r))), Color(1, 1, 1, 0.6 + 0.2 * (float(f[2]) - 0.8)))
