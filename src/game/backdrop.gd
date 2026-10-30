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
	_layer(mid, off, 0.08, 0.86)
	_haze(off)
	_layer(near, off, 0.18, 1.0)

func _layer(tex: Texture2D, off: Vector2, k: float, alpha: float) -> void:
	var x := -roundf(off.x * k * 3.0) / 3.0
	var y := -roundf(off.y * k * 3.0) / 3.0
	for i in [-1, 0, 1]:
		draw_texture_rect(tex, Rect2(x + i * 640.0, y, 640, 360), false, Color(1, 1, 1, alpha))

var _t := 0.0
## Atmosphärischer Dunst zwischen fernen und nahen Gebäuden (zwei driftende Bänder) – gibt Tiefe.
func _haze(off: Vector2) -> void:
	_t += get_process_delta_time()
	var drift := sin(_t * 0.12) * 14.0
	for band in [[205.0, 90.0, 0.30, 0.0], [255.0, 80.0, 0.22, 1.7]]:
		var y0: float = band[0] + float(band[3]) * 0.0
		var h: float = band[1]
		var a: float = band[2]
		var ox := drift * (1.0 if int(band[3]) == 0 else -0.7)
		var c0 := Color(0.45, 0.32, 0.65, 0.0)
		var c1 := Color(0.45, 0.32, 0.65, a)
		var pts := PackedVector2Array([Vector2(-20 + ox, y0), Vector2(660 + ox, y0), Vector2(660 + ox, y0 + h * 0.5), Vector2(-20 + ox, y0 + h * 0.5)])
		draw_polygon(pts, PackedColorArray([c0, c0, c1, c1]))
		var pts2 := PackedVector2Array([Vector2(-20 + ox, y0 + h * 0.5), Vector2(660 + ox, y0 + h * 0.5), Vector2(660 + ox, y0 + h), Vector2(-20 + ox, y0 + h)])
		draw_polygon(pts2, PackedColorArray([c1, c1, c0, c0]))
