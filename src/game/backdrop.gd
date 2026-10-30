extends Control
## Parallax-Hintergrund (Sektor 1). Zwei Ebenen, Offsets ganzzahlig gerundet.

var far: Texture2D = preload("res://assets/art/bg_s1_far.png")
var mid: Texture2D = preload("res://assets/art/bg_s1_mid.png")
var near: Texture2D = preload("res://assets/art/bg_s1_near.png")
var cam_ref: Camera2D
var lvl: LevelData

func setup(l: LevelData) -> void:
	lvl = l

func _process(_d: float) -> void:
	queue_redraw()

func _draw() -> void:
	var full := Rect2(0, 0, 640, 360)
	draw_texture_rect(far, full, false)
	var cam := get_viewport().get_camera_2d()
	var off := Vector2.ZERO
	if cam != null and lvl != null:
		off = cam.get_screen_center_position() - Vector2(320, 180)
	_layer(mid, off, 0.08)
	_layer(near, off, 0.18)

func _layer(tex: Texture2D, off: Vector2, k: float) -> void:
	var x := -roundf(off.x * k * 3.0) / 3.0
	var y := -roundf(off.y * k * 3.0) / 3.0
	for i in [-1, 0, 1]:
		draw_texture_rect(tex, Rect2(x + i * 640.0, y, 640, 360), false)
