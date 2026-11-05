extends Button
## Knopf mit gezeichnetem Symbol (Editor-Paletten); das Symbol wird über die Knopffläche gelegt. Ids siehe editor_icons.gd.

const EditorIcons := preload("res://src/ui/editor_icons.gd")

var icon_id := ""

func _draw() -> void:
	EditorIcons.draw(self, icon_id, Rect2(3.0, 3.0, size.x - 6.0, size.y - 6.0))
