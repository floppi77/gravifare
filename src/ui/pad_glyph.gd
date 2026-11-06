extends Control
## Controllersymbole im Xbox-Layout, gezeichnet aus Formen (keine Bilddateien): "A", "B", "X", "Y" als farbige Knöpfe, "LB", "RB", "LB/RB" und "START" als
## Schultertasten bzw. Menütaste, "DPAD" als Steuerkreuz. Verwendung: `PadGlyph.make("X", Vector2(12, 12))` als Kind eines Knopfs (nimmt keine Mausklicks an)
## oder `PadGlyph.draw(ci, "A", Rect2(...))` in einem eigenen `_draw`.

const COLORS := {"A": Color("#4cc35a"), "B": Color("#e6494f"), "X": Color("#3f7fe6"), "Y": Color("#f0c030")}
const BODY := Color("#2a3166")
const RIM := Color("#c9d3ff")

var id := "A"

static func make(glyph_id: String, sz := Vector2(12, 12)) -> Control:
	var g: Control = load("res://src/ui/pad_glyph.gd").new()
	g.id = glyph_id
	g.custom_minimum_size = sz
	g.size = sz
	g.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return g

## Breite, die ein Symbol bei der Höhe `h` braucht (Knöpfe sind rund, Schultertasten und Menü länglich).
static func width_for(glyph_id: String, h: float) -> float:
	match glyph_id:
		"LB/RB":
			return h * 2.6
		"LB", "RB", "START":
			return h * 1.5
	return h

static func _label(ci: CanvasItem, t: String, r: Rect2, col: Color, size: int) -> void:
	var f: Font = Fonts.hud if Fonts != null and Fonts.hud != null else ThemeDB.fallback_font
	var w := f.get_string_size(t, HORIZONTAL_ALIGNMENT_CENTER, -1, size)
	ci.draw_string(f, Vector2(r.position.x + (r.size.x - w.x) * 0.5, r.position.y + (r.size.y + float(size) * 0.72) * 0.5), t, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)

static func draw(ci: CanvasItem, glyph_id: String, r: Rect2) -> void:
	var c := r.get_center()
	var d := minf(r.size.x, r.size.y)
	var fs := maxi(5, int(d * 0.62))
	match glyph_id:
		"A", "B", "X", "Y":
			ci.draw_circle(c, d * 0.5, Color(0, 0, 0, 0.55))
			ci.draw_circle(c, d * 0.5 - 0.7, COLORS[glyph_id])
			_label(ci, glyph_id, Rect2(c - Vector2(d, d) * 0.5, Vector2(d, d)), Color(0.05, 0.06, 0.15), fs)
		"LB", "RB", "LB/RB":
			var rr := Rect2(c - Vector2(r.size.x, d * 0.78) * 0.5, Vector2(r.size.x, d * 0.78))
			ci.draw_rect(rr.grow(0.7), Color(0, 0, 0, 0.55))
			ci.draw_rect(rr, BODY)
			ci.draw_rect(rr, RIM, false, 0.8)
			_label(ci, glyph_id, rr, Color.WHITE, maxi(4, int(d * 0.5)))
		"START":
			var rr2 := Rect2(c - Vector2(r.size.x, d * 0.78) * 0.5, Vector2(r.size.x, d * 0.78))
			ci.draw_rect(rr2.grow(0.7), Color(0, 0, 0, 0.55))
			ci.draw_rect(rr2, BODY)
			ci.draw_rect(rr2, RIM, false, 0.8)
			for k in 3:                                                       # Menüsymbol: drei Striche
				var y := rr2.position.y + rr2.size.y * (0.28 + 0.22 * k)
				ci.draw_line(Vector2(c.x - d * 0.3, y), Vector2(c.x + d * 0.3, y), Color.WHITE, 0.9)
		"DPAD":
			var a := d * 0.5
			var t := d * 0.17
			ci.draw_rect(Rect2(c.x - a, c.y - t, a * 2.0, t * 2.0), Color(0, 0, 0, 0.55))
			ci.draw_rect(Rect2(c.x - t, c.y - a, t * 2.0, a * 2.0), Color(0, 0, 0, 0.55))
			ci.draw_rect(Rect2(c.x - a + 0.7, c.y - t + 0.7, a * 2.0 - 1.4, t * 2.0 - 1.4), BODY)
			ci.draw_rect(Rect2(c.x - t + 0.7, c.y - a + 0.7, t * 2.0 - 1.4, a * 2.0 - 1.4), BODY)
			ci.draw_rect(Rect2(c.x - t, c.y - t, t * 2.0, t * 2.0), RIM)

func _draw() -> void:
	draw(self, id, Rect2(Vector2.ZERO, size))
