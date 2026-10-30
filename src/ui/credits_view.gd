extends Control
## Zeichnet die Credits-Zeilen; scrollt von unten nach oben und beendet am Ende.

var lines: Array = []
var lang := "de"
var owner_scene: Node
var y := 380.0

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
		"title": return 64.0
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
		if cy > -20.0 and cy < 380.0:
			draw_string(fnt, Vector2(0, cy + _row_h(kind) * 0.6), txt, HORIZONTAL_ALIGNMENT_CENTER, 640, sz, col)
		cy += _row_h(kind)
