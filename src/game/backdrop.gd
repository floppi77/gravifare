extends Control
## Parallax-Hintergrund (Sektor 1). Zwei Ebenen, Offsets ganzzahlig gerundet.

var far: Texture2D = preload("res://assets/art/bg_s1_far.png")
var near: Texture2D = preload("res://assets/art/bg_s1_near.png")
var cam_ref: Camera2D
var lvl: LevelData

func setup(l: LevelData) -> void:
	lvl = l

func _process(_d: float) -> void:
	queue_redraw()

func _draw() -> void:
	draw_texture(far, Vector2.ZERO)
	var cam := get_viewport().get_camera_2d()
	var off := Vector2.ZERO
	if cam != null and lvl != null:
		off = cam.get_screen_center_position() - Vector2(320, 180)
	var nx := -floorf(off.x * 0.25)
	draw_texture(near, Vector2(nx, -floorf(off.y * 0.1)))
