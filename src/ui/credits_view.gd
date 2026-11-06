extends Control
## Zeichnet die Credits-Zeilen; scrollt von unten nach oben und beendet am Ende.

var lines: Array = []
var lang := "de"
var owner_scene: Node
var y := 380.0
var logo: Texture2D = load("res://assets/art/logo.png") if ResourceLoader.exists("res://assets/art/logo.png") else null
const LOGO_W := 210.0               # Breite des Logos im Abspann (statt der Schrift „GRAVIFARE“)

func _text(v) -> String:
	return v if typeof(v) == TYPE_STRING else String(v.get(lang, v.get("en", "")))

func _process(delta: float) -> void:
	var speed := 26.0 + (70.0 if Input.is_action_pressed("ui_accept") or Input.is_action_pressed("gear") else 0.0)
	y -= speed * delta
	queue_redraw()
	if y < -_total_height() - 20.0:
		Flow.to_menu()

func _total_height() -> float:
	var h := 0.0
	for l in lines:
		h += _row_h(l[0])
	return h

func _row_h(kind: String) -> float:
	match kind:
		"title": return (LOGO_W * float(logo.get_height()) / float(logo.get_width()) + 10.0) if logo != null else 64.0
		"sub": return 34.0
		"head": return 30.0
	return 16.0

func _draw() -> void:
	var cy := y
	for l in lines:
		var kind: String = l[0]
		var txt := _text(l[1])
		var col := Color("#c9cfee")
		var fnt: Font = Fonts.hud
		var sz := 10
		match kind:
			"title":
				fnt = Fonts.title
				sz = 56
				col = Color("#ffe14a")
			"sub":
				fnt = Fonts.ui
				sz = 12
				col = Color("#a9b8ff")
			"head":
				sz = 12
				col = Color("#35e0d2")
		var a := clampf(minf((cy - 10.0) / 40.0, (350.0 - cy) / 40.0), 0.0, 1.0)
		col.a = a
		if kind == "title" and logo != null:                       # Titelzeile: das GraviFare-Logo statt des Schrifttextes
			if cy > -_row_h(kind) and cy < 380.0:
				var lh := LOGO_W * float(logo.get_height()) / float(logo.get_width())
				var r := Rect2((size.x - LOGO_W) * 0.5, cy + 2.0, LOGO_W, lh)
				var mid := cy + lh * 0.5                                  # die hohe Zeile blendet nach ihrer Mitte ein und aus
				a = clampf(minf((mid - 10.0) / 40.0, (350.0 - mid) / 40.0), 0.0, 1.0)
				draw_texture_rect(logo, Rect2(r.position + Vector2(2, 3), r.size), false, Color(0, 0, 0, 0.45 * a))        # Schatten wie im Hauptmenü
				draw_texture_rect(logo, r, false, Color(1, 1, 1, a))
		elif cy > -20.0 and cy < 380.0:
			draw_string(fnt, Vector2(0, cy + _row_h(kind) * 0.6), txt, HORIZONTAL_ALIGNMENT_CENTER, size.x, sz, col)
		cy += _row_h(kind)
