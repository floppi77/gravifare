class_name GateField
extends Node2D
## Tutorial-Parcours: Tore als leuchtende Ringe. Das nächste Tor ist grün, alle anderen (auch die schon durchflogenen) sind rot.
## Die Regie (tutorial.gd) setzt `next` hoch, sobald das Taxi durch das grüne Tor geflogen ist.

const RADIUS := 16.0

var points: Array = []
var next := 0
var active := false
var t := 0.0
var done_t := -1.0                  # Restzeit des Abschlussblitzes

func start() -> void:
	next = 0
	active = true
	done_t = -1.0

func finish() -> void:
	active = false
	done_t = 1.2

func _process(delta: float) -> void:
	t += delta
	if done_t > 0.0:
		done_t -= delta
	queue_redraw()

func _draw() -> void:
	if points.is_empty():
		return
	if done_t > 0.0:
		var p: Vector2 = points[points.size() - 1]
		var k := 1.0 - done_t / 1.2
		draw_arc(p, RADIUS + 30.0 * k, 0.0, TAU, 40, Color(0.3, 1.0, 0.5, 1.0 - k), 2.0)
	if not active:
		return
	for i in points.size():
		var p: Vector2 = points[i]
		var is_next := i == next
		var col := Color(0.3, 1.0, 0.5) if is_next else Color(1.0, 0.28, 0.34)
		var pulse := 0.6 + 0.4 * sin(t * (6.0 if is_next else 2.0) + float(i))
		var a := (0.95 if is_next else 0.8) * (0.75 + 0.25 * pulse)
		draw_circle(p, RADIUS - 1.0, Color(col.r, col.g, col.b, 0.08 + (0.07 * pulse if is_next else 0.0)))
		draw_arc(p, RADIUS, 0.0, TAU, 36, Color(col.r, col.g, col.b, a), 2.4 if is_next else 2.0)
		draw_arc(p, RADIUS + 3.0, 0.0, TAU, 36, Color(col.r, col.g, col.b, a * 0.25), 1.0)
		for k in 8:                                           # kreisende Leuchtpunkte
			var ang := t * (2.2 if is_next else 0.7) + float(k) * TAU / 8.0
			draw_circle(p + Vector2(cos(ang), sin(ang)) * RADIUS, 1.1 if is_next else 0.8, Color(1, 1, 1, 0.5 * a))
		if is_next:                                           # Nummer des Tors
			draw_string(ThemeDB.fallback_font, p + Vector2(-3.0, 3.0), str(i + 1), HORIZONTAL_ALIGNMENT_CENTER, 8.0, 8, Color(1, 1, 1, 0.9))
