extends RefCounted
## Symbole der Editor-Paletten, gezeichnet aus Formen und Farben (keine Bilddateien: der Kachelatlas des Spiels ist fast weiß und bekommt seine Farbe erst durch die
## Beleuchtung der Spielansicht, als Symbol wäre er eine weiße Fläche; nur das Taxi kommt aus seiner Grafik). Hindernisse und Zonen sind einfache Zeichen. Verwendung: EditorIcons.draw(canvas_item, "debris", Rect2(...)). Ids: Kartenzeichen ("#", ".", "1"–"9", "F", "L", "H", "^", "P", "S",
## "a"–"e"), Arten ("debris", "slider", "pad", "meteor", "beam", "vehicle", "wind", "magnet", "gravity", "heat") und Zeichenmodi ("mode_line", "mode_rect", "mode_fill").

const ROCK_COL := Color("#5a6aa8")
const ROCK_DARK := Color("#34407f")
const ROCK_LIGHT := Color("#8a98d8")

static func _font() -> Font:
	return Fonts.ui

static func _text(ci: CanvasItem, t: String, r: Rect2, size: int, col := Color.WHITE) -> void:
	var f := _font()
	var w := f.get_string_size(t, HORIZONTAL_ALIGNMENT_CENTER, -1, size)
	var pos := Vector2(r.position.x + (r.size.x - w.x) * 0.5, r.position.y + (r.size.y + float(size) * 0.7) * 0.5)
	ci.draw_string_outline(f, pos, t, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 2, Color(0.02, 0.03, 0.1, 0.95))
	ci.draw_string(f, pos, t, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)

static func _arrow(ci: CanvasItem, a: Vector2, b: Vector2, col: Color, w := 1.5) -> void:
	ci.draw_line(a, b, col, w)
	var d := (b - a).normalized()
	var n := Vector2(-d.y, d.x)
	ci.draw_colored_polygon(PackedVector2Array([b, b - d * 4.0 + n * 2.5, b - d * 4.0 - n * 2.5]), col)

## Plattform als Balken: heller Rand oben, dunklerer Körper.
static func _bar(ci: CanvasItem, r: Rect2, body: Color, top: Color) -> void:
	ci.draw_rect(r, body)
	ci.draw_rect(Rect2(r.position.x, r.position.y, r.size.x, maxf(2.0, r.size.y * 0.22)), top)
	ci.draw_line(Vector2(r.position.x + 1, r.end.y - 1.5), Vector2(r.end.x - 1, r.end.y - 1.5), Color(0, 0, 0, 0.35), 1.0)

static func _rock(ci: CanvasItem, r: Rect2) -> void:
	ci.draw_rect(r, ROCK_COL)
	ci.draw_rect(Rect2(r.position.x, r.position.y, r.size.x, 2.0), ROCK_LIGHT)
	ci.draw_rect(Rect2(r.position.x, r.end.y - 2.0, r.size.x, 2.0), ROCK_DARK)
	ci.draw_rect(Rect2(r.end.x - 2.0, r.position.y, 2.0, r.size.y), ROCK_DARK)
	for k in [[0.25, 0.35], [0.65, 0.3], [0.45, 0.65], [0.8, 0.7], [0.18, 0.78]]:
		ci.draw_rect(Rect2(r.position.x + r.size.x * k[0], r.position.y + r.size.y * k[1], 2, 2), ROCK_DARK)

static func draw(ci: CanvasItem, id: String, r: Rect2) -> void:
	var c := r.get_center()
	var s := minf(r.size.x, r.size.y)
	match id:
		"#":
			_rock(ci, r)
		".":
			ci.draw_rect(r, Color(0.03, 0.04, 0.1, 0.9))
			for i in 4:
				for j in 3:
					ci.draw_rect(Rect2(r.position.x + 3.0 + i * (r.size.x - 6.0) / 3.0, r.position.y + 3.0 + j * (r.size.y - 6.0) / 2.0, 1, 1), Color(1, 1, 1, 0.35))
		"1", "2", "3", "4", "5", "6", "7", "8", "9":
			_bar(ci, Rect2(r.position.x, r.position.y + r.size.y * 0.58, r.size.x, r.size.y * 0.36), Color("#1f7a86"), Color("#5dffe0"))
			_text(ci, id, Rect2(r.position.x, r.position.y, r.size.x, r.size.y * 0.55), 9, Color("#ffe14a"))
		"F":
			_bar(ci, Rect2(r.position.x, r.position.y + r.size.y * 0.62, r.size.x, r.size.y * 0.32), Color("#8a6a1f"), Color("#ffd24a"))
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -s * 0.38), c + Vector2(-s * 0.2, -s * 0.02), c + Vector2(s * 0.2, -s * 0.02)]), Color("#5dff9a"))
			ci.draw_circle(c + Vector2(0, -s * 0.0), s * 0.2, Color("#5dff9a"))
		"L":
			_bar(ci, Rect2(r.position.x, r.position.y + r.size.y * 0.62, r.size.x, r.size.y * 0.32), Color("#8a6a1f"), Color("#ffd24a"))
			ci.draw_circle(c + Vector2(-s * 0.13, -s * 0.12), s * 0.15, Color("#ff8ad8"))
			ci.draw_circle(c + Vector2(s * 0.13, -s * 0.12), s * 0.15, Color("#ff8ad8"))
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-s * 0.27, -s * 0.06), c + Vector2(s * 0.27, -s * 0.06), c + Vector2(0, s * 0.26)]), Color("#ff8ad8"))
		"H":
			_bar(ci, Rect2(r.position.x, r.position.y + r.size.y * 0.62, r.size.x, r.size.y * 0.32), Color("#a8b4d0"), Color("#ffffff"))
			ci.draw_rect(Rect2(c.x - s * 0.08, c.y - s * 0.34, s * 0.16, s * 0.5), Color("#ff4d6d"))
			ci.draw_rect(Rect2(c.x - s * 0.25, c.y - s * 0.17, s * 0.5, s * 0.16), Color("#ff4d6d"))
		"^":
			ci.draw_rect(Rect2(r.position.x, r.end.y - r.size.y * 0.22, r.size.x, r.size.y * 0.22), ROCK_DARK)
			for k in 3:
				var x0 := r.position.x + r.size.x * (k / 3.0)
				ci.draw_colored_polygon(PackedVector2Array([Vector2(x0 + 1, r.end.y - r.size.y * 0.2), Vector2(x0 + r.size.x / 6.0, r.position.y + 2), Vector2(x0 + r.size.x / 3.0 - 1, r.end.y - r.size.y * 0.2)]), Color("#ff4d6d"))
		"P":
			ci.draw_rect(Rect2(c.x - s * 0.14, c.y - s * 0.38, s * 0.28, s * 0.78), Color("#2f8f5a"))
			ci.draw_rect(Rect2(c.x - s * 0.1, c.y - s * 0.3, s * 0.2, s * 0.2), Color("#7dffb0"))
			ci.draw_line(c + Vector2(s * 0.14, -s * 0.15), c + Vector2(s * 0.32, -s * 0.05), Color("#2f8f5a"), 2.0)
		"S":
			ci.draw_texture_rect(Cosmetics.paint_texture(), Rect2(c.x - s * 0.55, c.y - s * 0.34, s * 1.1, s * 0.68), false)
		"a", "b", "c", "d", "e":
			ci.draw_rect(Rect2(r.position.x + 2, r.position.y, r.size.x * 0.3, r.size.y), Color("#6a78c8"))
			ci.draw_rect(Rect2(r.end.x - 2 - r.size.x * 0.3, r.position.y, r.size.x * 0.3, r.size.y), Color("#6a78c8"))
			_arrow(ci, Vector2(c.x - s * 0.1, c.y), Vector2(r.position.x + r.size.x * 0.33, c.y), Color("#b07bff"))
			_arrow(ci, Vector2(c.x + s * 0.1, c.y), Vector2(r.end.x - r.size.x * 0.33, c.y), Color("#b07bff"))
			_text(ci, id, Rect2(r.position.x, r.position.y + r.size.y * 0.45, r.size.x, r.size.y * 0.55), 8, Color("#e0c8ff"))
		"debris":
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-s * 0.4, -s * 0.1), c + Vector2(-s * 0.15, -s * 0.38), c + Vector2(s * 0.22, -s * 0.3), c + Vector2(s * 0.4, 0),
				c + Vector2(s * 0.2, s * 0.34), c + Vector2(-s * 0.25, s * 0.3)]), Color("#8c93b0"))
			ci.draw_circle(c + Vector2(-s * 0.05, -s * 0.05), s * 0.07, Color("#5a6080"))
			ci.draw_circle(c + Vector2(s * 0.16, s * 0.1), s * 0.05, Color("#5a6080"))
		"slider":
			ci.draw_rect(Rect2(c.x - s * 0.22, c.y - s * 0.32, s * 0.44, s * 0.64), Color("#6a78c8"))
			ci.draw_rect(Rect2(c.x - s * 0.22, c.y - s * 0.32, s * 0.44, s * 0.64), Color("#ffe14a"), false, 1.0)
			_arrow(ci, Vector2(c.x, c.y + s * 0.18), Vector2(c.x, c.y - s * 0.18), Color("#ffe14a"))
		"pad":
			_bar(ci, Rect2(r.position.x + 2, c.y - s * 0.06, r.size.x - 4, s * 0.34), Color("#1f7a86"), Color("#5dffe0"))
			_arrow(ci, Vector2(c.x - s * 0.1, c.y - s * 0.22), Vector2(r.position.x + 3, c.y - s * 0.22), Color("#5dd6ff"))
			_arrow(ci, Vector2(c.x + s * 0.1, c.y - s * 0.22), Vector2(r.end.x - 3, c.y - s * 0.22), Color("#5dd6ff"))
		"meteor":
			ci.draw_line(c + Vector2(-s * 0.35, -s * 0.38), c + Vector2(-s * 0.05, -s * 0.05), Color(1, 0.6, 0.2, 0.7), 3.0)
			ci.draw_circle(c + Vector2(s * 0.05, s * 0.05), s * 0.24, Color("#ff9a4a"))
			ci.draw_circle(c + Vector2(s * 0.0, s * 0.0), s * 0.1, Color("#ffd29a"))
		"beam":
			ci.draw_rect(Rect2(c.x - s * 0.1, r.position.y + 1, s * 0.2, r.size.y - 2), Color("#ff4fd8"))
			ci.draw_rect(Rect2(c.x - s * 0.04, r.position.y + 1, s * 0.08, r.size.y - 2), Color("#ffe0f8"))
			ci.draw_rect(Rect2(c.x - s * 0.28, r.position.y + 1, s * 0.56, 3), Color("#a03090"))
			ci.draw_rect(Rect2(c.x - s * 0.28, r.end.y - 4, s * 0.56, 3), Color("#a03090"))
		"vehicle":
			ci.draw_texture_rect(Cosmetics.paint_texture(), Rect2(c.x - s * 0.5, c.y - s * 0.3, s * 0.8, s * 0.5), false)
			_arrow(ci, Vector2(r.position.x + 2, r.end.y - 4), Vector2(r.end.x - 2, r.end.y - 4), Color("#5dd6ff"))
		"wind":
			for k in 3:
				_arrow(ci, Vector2(r.position.x + 3, c.y + (k - 1) * s * 0.28), Vector2(r.end.x - 3, c.y + (k - 1) * s * 0.28), Color("#9ad8ff"))
		"magnet":
			ci.draw_arc(c, s * 0.34, 0.0, TAU, 20, Color("#ff4d6d"), 2.0)
			ci.draw_arc(c, s * 0.18, 0.0, TAU, 14, Color("#ff8a9a"), 1.5)
			ci.draw_circle(c, s * 0.06, Color("#ffe14a"))
		"gravity":
			_arrow(ci, c + Vector2(0, -s * 0.34), c + Vector2(0, s * 0.3), Color("#c4a0ff"), 2.0)
			_text(ci, "g", Rect2(c.x + s * 0.05, r.position.y, s * 0.4, r.size.y * 0.6), 9, Color("#c4a0ff"))
		"heat":
			for k in 3:
				var x := r.position.x + r.size.x * (0.25 + 0.25 * k)
				var pts := PackedVector2Array()
				for j in 7:
					pts.append(Vector2(x + sin(float(j) * 1.3 + float(k)) * 2.5, r.end.y - 3 - j * (r.size.y - 6) / 6.0))
				ci.draw_polyline(pts, Color("#ff7a3a"), 2.0)
		"mode_line":
			ci.draw_line(r.position + Vector2(3, r.size.y - 4), r.end - Vector2(3, 4 + 0), Color("#ffe14a"), 2.5)
			ci.draw_circle(r.position + Vector2(3, r.size.y - 4), 2.5, Color.WHITE)
		"mode_rect":
			ci.draw_rect(Rect2(r.position.x + 3, r.position.y + 3, r.size.x - 6, r.size.y - 6), Color(1, 0.88, 0.3, 0.3))
			ci.draw_rect(Rect2(r.position.x + 3, r.position.y + 3, r.size.x - 6, r.size.y - 6), Color("#ffe14a"), false, 2.0)
		"mode_fill":
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -s * 0.38), c + Vector2(s * 0.3, s * 0.1), c + Vector2(0, s * 0.3), c + Vector2(-s * 0.3, s * 0.1)]), Color("#ffe14a"))
			ci.draw_circle(c + Vector2(s * 0.36, s * 0.3), s * 0.08, Color("#5dd6ff"))
