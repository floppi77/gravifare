class_name LevelCard
extends Button
## Karte eines Levels in der Levelauswahl: große Nummer, drei gezeichnete Sterne (Zeit, Sauber, Meister), Schloss bei gesperrten Leveln.
## Geschaffte Level tragen links einen Streifen in der Sektorfarbe, das Level der laufenden Karriere eine gelbe Ecke.

enum State { LOCKED, OPEN, DONE }
const SEL := Color("#ffe14a")
const STAR := Color("#ffd24a")

var number := 1
var state := State.OPEN
var medals := {}                  # {time, clean, pro}
var accent := Color("#7f8fe0")
var current := false              # hier steht die laufende Karriere

func _init() -> void:
	for st in ["normal", "hover", "pressed", "focus", "disabled"]:
		add_theme_stylebox_override(st, StyleBoxEmpty.new())
	focus_mode = Control.FOCUS_ALL
	custom_minimum_size = Vector2(92, 40)

func star_count() -> int:
	var n := 0
	for k in ["time", "clean", "pro"]:
		n += 1 if bool(medals.get(k, false)) else 0
	return n

static func star_points(c: Vector2, r: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 10:
		var a := -PI / 2.0 + float(i) * PI / 5.0
		pts.append(c + Vector2(cos(a), sin(a)) * (r if i % 2 == 0 else r * 0.45))
	return pts

func _box(col: Color, border: Color, bw: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = col
	sb.set_corner_radius_all(5)
	sb.set_border_width_all(bw)
	sb.border_color = border
	sb.anti_aliasing = true
	return sb

func _draw() -> void:
	var hot := has_focus() or is_hovered()
	var down := 1.0 if is_pressed() else 0.0
	var r := Rect2(0.0, down, size.x, size.y - 3.0)
	var locked := state == State.LOCKED
	draw_style_box(_box(Color(0.02, 0.03, 0.09, 0.9), Color(0, 0, 0, 0), 0), Rect2(0.0, 3.0, size.x, size.y - 3.0))      # Tiefe
	var face := Color("#151a3a") if locked else (Color("#3a479a") if hot else Color("#28316c"))
	var edge := SEL if hot else (Color("#2a3266") if locked else Color("#7380c8"))
	draw_style_box(_box(face, edge, 2 if hot else 1), r)
	if not locked:
		draw_rect(Rect2(r.position.x + 4.0, r.position.y + 2.0, r.size.x - 8.0, 1.0), Color(1, 1, 1, 0.12))                # Glanzkante
	if state == State.DONE:
		draw_rect(Rect2(r.position.x + 2.0, r.position.y + 5.0, 3.0, r.size.y - 10.0), accent)                              # Streifen in Sektorfarbe
	if current:
		draw_colored_polygon(PackedVector2Array([r.position + Vector2(r.size.x - 12.0, 1.5), r.position + Vector2(r.size.x - 1.5, 1.5), r.position + Vector2(r.size.x - 1.5, 12.0)]), SEL)
	var font := Fonts.hud
	var cy := r.position.y + r.size.y * 0.5
	var num := "%02d" % number
	var nc := Color("#5a628f") if locked else Color.WHITE
	draw_string_outline(font, Vector2(11.0, cy + 6.0), num, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, 3, Color(0.02, 0.03, 0.1, 0.9))
	draw_string(font, Vector2(11.0, cy + 6.0), num, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, nc)
	if locked:
		var lx := r.size.x - 22.0                                   # Schloss
		draw_arc(Vector2(lx, cy - 2.0), 3.5, PI, TAU, 10, Color("#5a628f"), 1.5)
		draw_rect(Rect2(lx - 5.0, cy - 2.0, 10.0, 8.0), Color("#5a628f"))
		draw_rect(Rect2(lx - 0.75, cy + 0.5, 1.5, 3.0), Color("#151a3a"))
		return
	var keys := ["time", "clean", "pro"]
	for i in 3:
		var c := Vector2(r.size.x - 44.0 + float(i) * 14.0, cy)
		var got := bool(medals.get(keys[i], false))
		draw_colored_polygon(star_points(c + Vector2(0.0, 1.0), 6.0), Color(0.02, 0.03, 0.1, 0.55))
		draw_colored_polygon(star_points(c, 6.0), STAR if got else Color(0.09, 0.11, 0.26))
		if got:
			draw_colored_polygon(star_points(c + Vector2(-0.8, -1.0), 2.4), Color(1.0, 0.96, 0.75))
		else:
			draw_polyline(star_points(c, 6.0) + PackedVector2Array([star_points(c, 6.0)[0]]), Color("#4a5596") if state == State.OPEN else Color("#5f6bb5"), 1.0)
