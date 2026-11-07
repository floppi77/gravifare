extends Button
## Knopf mit gezeichnetem Symbol (Editor-Paletten); das Symbol wird über die Knopffläche gelegt. Ids siehe editor_icons.gd.
## `selected` zeichnet einen kräftigen gelben Rahmen mit Eckmarke (gewählte Auswahl); der Fokus behält den Rahmen des Menü-Stils, beides bleibt so unterscheidbar.

const EditorIcons := preload("res://src/ui/editor_icons.gd")
const SEL_COL := Color("#ffe14a")

var icon_id := ""
var selected := false:
	set(v):
		selected = v
		queue_redraw()

func _draw() -> void:
	EditorIcons.draw(self, icon_id, Rect2(3.0, 3.0, size.x - 6.0, size.y - 6.0))
	if selected:
		var r := Rect2(Vector2(1.0, 1.0), size - Vector2(2.0, 2.0))
		draw_rect(r.grow(1.0), Color(0.02, 0.03, 0.1, 0.9), false, 1.0)
		draw_rect(r, SEL_COL, false, 2.0)
		draw_colored_polygon(PackedVector2Array([Vector2(size.x - 9.0, 1.0), Vector2(size.x - 1.0, 1.0), Vector2(size.x - 1.0, 9.0)]), SEL_COL)
