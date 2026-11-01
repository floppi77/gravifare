class_name LevelPreview
extends Control
## Kleiner Grundriss eines Levels: Fels in der Sektorfarbe, Plattformen in ihren Funktionsfarben (wie im Spiel), Ausgang oben.

var level: LevelData

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.03, 0.04, 0.1, 0.88))
	if level == null:
		return
	var k := minf((size.x - 6.0) / float(level.width), (size.y - 6.0) / float(level.height))
	var o := (size - Vector2(level.width, level.height) * k) * 0.5
	var rock: Color = SectorLook.of(level.sector).edge
	for y in level.height:
		for x in level.width:
			var c := level.cell(x, y)
			var col := Color(0, 0, 0, 0)
			if c == "#":
				col = rock.darkened(0.25)
			elif c == "^":
				col = Color("#ff4d6d")
			elif (c >= "1" and c <= "9"):
				col = Color("#3fe0f0")
			elif c == "F":
				col = Color("#ffb02e")
			elif c == "L":
				col = Color("#ff7ac8")
			elif c == "H":
				col = Color("#ffffff")
			elif c == "E":
				col = Color("#ffe14a")
			elif LevelData.DOOR_CHARS.contains(c):
				col = Color("#a9b8ff")
			if col.a > 0.0:
				draw_rect(Rect2(o + Vector2(x, y) * k, Vector2(k, k)), col)
	draw_circle(o + level.spawn / float(Tuning.TILE) * k, k * 0.8, Color("#ffe14a"))
	draw_rect(Rect2(Vector2.ZERO, size), Color("#3a4580"), false, 1.0)
