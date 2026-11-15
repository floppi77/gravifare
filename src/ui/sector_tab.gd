class_name SectorTab
extends Button
## Reiter eines Sektors in der Levelauswahl. Die Fläche füllt sich von links in der Farbe des Sektors, je mehr seiner Level geschafft sind
## (Gold, wenn der Sektor alle Sterne hat). Der gewählte Sektor ist voll gesättigt, gelb umrandet und zeigt mit einer Spitze auf den Inhalt;
## die übrigen sind gedämpft. Der Tastatur-/Controller-Fokus bekommt zusätzlich einen hellen Außenrand.

const SEL := Color("#ffe14a")
const GOLD := Color("#ffcf4a")
const BASE := Color(0.07, 0.09, 0.21)
const TIP := 4.0                 # Höhe der Spitze unter dem gewählten Reiter

var number := 1
var done := 0
var total := 11
var gold := false
var accent := Color("#7f8fe0")
var selected := false:
	set(v):
		selected = v
		queue_redraw()

func _init() -> void:
	for st in ["normal", "hover", "pressed", "focus", "disabled"]:
		add_theme_stylebox_override(st, StyleBoxEmpty.new())
	focus_mode = Control.FOCUS_ALL
	custom_minimum_size = Vector2(64, 26)

## Anteil der geschafften Level (0–1).
func share() -> float:
	return clampf(float(done) / float(maxi(total, 1)), 0.0, 1.0)

## Breite der Farbfüllung in der Fläche `inner_w`: ein geschafftes Level ist immer sichtbar, ein fehlendes auch.
func fill_width(inner_w: float) -> float:
	if done <= 0:
		return 0.0
	if done >= total:
		return inner_w
	return clampf(roundf(inner_w * share()), 3.0, inner_w - 3.0)

func fill_color() -> Color:
	return GOLD if gold else accent

func _box(col: Color, radius_l: float, radius_r: float) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = col
	sb.corner_radius_top_left = int(radius_l)
	sb.corner_radius_bottom_left = int(radius_l)
	sb.corner_radius_top_right = int(radius_r)
	sb.corner_radius_bottom_right = int(radius_r)
	sb.anti_aliasing = true
	return sb

func _draw() -> void:
	var hot := selected or is_hovered() or has_focus()
	var r := Rect2(0.0, 0.0, size.x, size.y - TIP)
	var dim := 1.0 if selected else (0.86 if hot else 0.7)
	# Tiefe: dunkle Unterkante wie bei den Menüknöpfen
	draw_style_box(_box(Color(0.02, 0.03, 0.09, 0.9), 5.0, 5.0), Rect2(r.position + Vector2(0.0, 2.0), r.size))
	draw_style_box(_box(BASE, 5.0, 5.0), r)
	# Füllung von links: Fortschritt des Sektors
	var inner := r.grow(-1.0)
	var fw := fill_width(inner.size.x)
	if fw > 0.0:
		var col := fill_color()
		col = Color(col.r * dim, col.g * dim, col.b * dim)
		var full := fw >= inner.size.x
		draw_style_box(_box(col, 4.0, 4.0 if full else 0.0), Rect2(inner.position, Vector2(fw, inner.size.y)))
		draw_rect(Rect2(inner.position.x + 3.0, inner.position.y + 1.0, fw - (6.0 if full else 3.0), 1.0), Color(1, 1, 1, 0.28 * dim))      # Glanzkante
		draw_rect(Rect2(inner.position.x + 3.0, inner.end.y - 2.0, fw - (6.0 if full else 3.0), 1.0), Color(0, 0, 0, 0.22))
		if not full:
			draw_rect(Rect2(inner.position.x + fw - 1.0, inner.position.y, 1.0, inner.size.y), Color(1, 1, 1, 0.45 * dim))                # Kante der Füllung
	# Rahmen: gewählt gelb und kräftig, sonst ruhig
	var frame := _box(Color(0, 0, 0, 0), 5.0, 5.0)
	frame.draw_center = false
	frame.set_border_width_all(2 if selected else 1)
	frame.border_color = SEL if selected else (Color("#9aa8ee") if hot else Color("#3a4580"))
	draw_style_box(frame, r)
	if selected:
		var cx := size.x * 0.5
		draw_colored_polygon(PackedVector2Array([Vector2(cx - 5.0, r.end.y - 0.5), Vector2(cx + 5.0, r.end.y - 0.5), Vector2(cx, size.y)]), SEL)
	if has_focus():
		var ring := _box(Color(0, 0, 0, 0), 7.0, 7.0)
		ring.draw_center = false
		ring.set_border_width_all(1)
		ring.border_color = Color(1, 1, 1, 0.9)
		draw_style_box(ring, r.grow(2.0))
	# Beschriftung: Sektornummer groß, geschaffte Level klein
	var font := Fonts.hud
	var ink := Color(0.02, 0.03, 0.1, 0.95)
	var tc := Color.WHITE if dim > 0.75 else Color(0.84, 0.87, 0.98)
	var base_y := r.size.y * 0.5 + 5.0
	draw_string_outline(font, Vector2(8.0, base_y), str(number), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, 3, ink)
	draw_string(font, Vector2(8.0, base_y), str(number), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, tc)
	var small := "%d/%d" % [done, total]
	draw_string_outline(font, Vector2(0.0, base_y - 1.0), small, HORIZONTAL_ALIGNMENT_RIGHT, size.x - 7.0, 8, 3, ink)
	draw_string(font, Vector2(0.0, base_y - 1.0), small, HORIZONTAL_ALIGNMENT_RIGHT, size.x - 7.0, 8, Color(1, 1, 1, 0.95 if dim > 0.75 else 0.8))
