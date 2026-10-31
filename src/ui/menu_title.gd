extends Control
## Animierter Titel: Schatten, weiches Leuchten und ein Glanzlicht, das periodisch über die Buchstaben wandert.

var text := "GRAVIFARE"
var font_size := 50
var t := 0.0
var logo: Texture2D = load("res://assets/art/logo.png") if ResourceLoader.exists("res://assets/art/logo.png") else null
const LOGO_W := 130.0

func _ready() -> void:
	custom_minimum_size = Vector2(300, (LOGO_W * float(logo.get_height()) / float(logo.get_width()) + 4.0) if logo != null else font_size + 12)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _process(delta: float) -> void:
	t += delta
	queue_redraw()

func _draw() -> void:
	if logo != null:
		var h := LOGO_W * float(logo.get_height()) / float(logo.get_width())
		var bob := roundf(sin(t * 1.4) * 1.5)
		var r := Rect2(roundf((size.x - LOGO_W) * 0.5), 2.0 + bob, LOGO_W, h)
		draw_texture_rect(logo, Rect2(r.position + Vector2(2, 3), r.size), false, Color(0, 0, 0, 0.45))     # Schatten
		draw_texture_rect(logo, r, false)
		return
	var f: Font = Fonts.title
	var total := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var x0 := (size.x - total) * 0.5
	var base_y := font_size * 0.85 + sin(t * 1.4) * 1.5
	for off in [Vector2(2, 2.5)]:
		draw_string(f, Vector2(x0, base_y) + off, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(0, 0, 0, 0.5))
	var sweep := fmod(t * 0.35, 1.6) - 0.3
	var cx := x0
	for ch in text:
		var w := f.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		var u := (cx + w * 0.5 - x0) / maxf(total, 1.0)
		var shine := exp(-pow((u - sweep) * 7.0, 2.0))
		var col := Color("#ffe14a").lerp(Color("#fffbe0"), shine)
		if shine > 0.3:
			draw_string(f, Vector2(cx, base_y), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(1, 0.85, 0.3, 0.25 * shine))
		draw_string(f, Vector2(cx, base_y - 0.5 * shine), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, col)
		cx += w
