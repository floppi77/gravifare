extends Node2D
## Atmosphäre je Sektor: wenige, leise Teilchen im Spielfeld (rein optisch). Bei „Weniger Bewegung“ stehen sie still.

const KINDS := {
	1: {"n": 26, "v": Vector2(5, -2), "s": 0.67, "c": Color(0.75, 0.85, 1.0, 0.28)},      # Dunst der Stadt
	2: {"n": 34, "v": Vector2(0, -9), "s": 0.67, "c": Color(1.0, 0.45, 0.9, 0.5)},        # Neonfunken
	3: {"n": 42, "v": Vector2(7, 3), "s": 0.67, "c": Color(0.75, 0.6, 0.42, 0.35)},       # Staub
	4: {"n": 70, "v": Vector2(-6, 13), "s": 1.0, "c": Color(0.92, 0.97, 1.0, 0.75)},      # Schnee
	5: {"n": 44, "v": Vector2(3, -24), "s": 1.0, "c": Color(1.0, 0.56, 0.16, 0.85)},      # Glut
	6: {"n": 30, "v": Vector2(1, -11), "s": 1.34, "c": Color(0.7, 0.95, 1.0, 0.4)},       # Blasen
	7: {"n": 22, "v": Vector2(26, 0), "s": 0.67, "c": Color(1.0, 0.92, 0.7, 0.3)},        # Lichtspuren
	8: {"n": 26, "v": Vector2(2, -2), "s": 1.0, "c": Color(0.5, 1.0, 0.8, 0.8)},          # Glühwürmchen
	9: {"n": 50, "v": Vector2(-10, 5), "s": 0.67, "c": Color(0.72, 0.6, 1.0, 0.6)},       # Sternenstaub
}
var kind: Dictionary
var pts: Array = []
var t := 0.0
var size_v := Vector2(640, 352)

func setup(lv: LevelData) -> void:
	kind = KINDS.get(lv.sector, KINDS[1])
	size_v = lv.pixel_size()
	var rng := RandomNumberGenerator.new()
	rng.seed = lv.number
	pts.clear()
	for i in int(kind.n):
		pts.append([rng.randf() * size_v.x, rng.randf() * size_v.y, rng.randf() * TAU, rng.randf_range(0.6, 1.3)])
	queue_redraw()

func _process(delta: float) -> void:
	if Settings.values.reduce_motion or pts.is_empty():
		return
	t += delta
	var v: Vector2 = kind.v
	for p in pts:
		p[0] = fposmod(float(p[0]) + (v.x * float(p[3]) + sin(t * 0.9 + float(p[2])) * 3.0) * delta, size_v.x)
		p[1] = fposmod(float(p[1]) + (v.y * float(p[3]) + cos(t * 0.7 + float(p[2])) * 1.5) * delta, size_v.y)
	queue_redraw()

func _draw() -> void:
	if pts.is_empty():
		return
	var col: Color = kind.c
	var s: float = kind.s
	for p in pts:
		var a := col.a * (0.55 + 0.45 * sin(t * 2.0 + float(p[2])))
		draw_rect(Rect2(p[0], p[1], s, s), Color(col.r, col.g, col.b, a))
