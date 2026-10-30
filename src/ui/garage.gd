extends Control
## Garage: Lackierung und Aufkleber wählen (nur Optik). Gesperrte Einträge zeigen ihre Freischaltbedingung.
## Fokus auf einem Eintrag zeigt eine Vorschau; A/Enter legt ihn an. „Nur Standardtaxi“ erzwingt den Challenge-Look.

class Preview extends Control:
	var paint := "std"
	var sticker := "none"
	var t := 0.0
	func _process(d: float) -> void:
		t += d
		queue_redraw()
	func _draw() -> void:
		var c := Vector2(size.x * 0.5, size.y * 0.5 + sin(t * 1.8) * 2.5)
		draw_rect(Rect2(c.x - 50, c.y + 24, 100, 3), Color(0.2, 0.9, 0.85, 0.5))
		draw_rect(Rect2(c.x - 40, c.y + 27, 80, 2), Color(0.2, 0.9, 0.85, 0.2))
		var tex := Cosmetics.paint_texture(paint)
		var fl := 0.7 + 0.3 * sin(t * 40.0)
		draw_colored_polygon(PackedVector2Array([Vector2(c.x - 5, c.y + 14), Vector2(c.x + 5, c.y + 14), Vector2(c.x, c.y + 14 + 10 * fl)]), Color("#ff8a2e"))
		if tex != null:
			draw_texture_rect(tex, Rect2(c.x - 40, c.y - 25, 80, 50), false)
		var st := Cosmetics.sticker_texture(sticker)
		if st != null:
			draw_texture_rect(st, Rect2(c.x - 32.5, c.y - 10.5, 20, 20), false)

var preview: Preview
var info: Label
var buttons: Array = []
var lang := "de"

func _ready() -> void:
	Music.play_theme("menu")
	Music.set_layers(true, false)
	Music.duck(0.0)
	theme = MenuKit.make_theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	lang = TranslationServer.get_locale().substr(0, 2)
	var backdrop := Control.new()
	backdrop.set_script(load("res://src/ui/menu_backdrop.gd"))
	add_child(backdrop)
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.03, 0.1, 0.62)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	var title := MenuKit.title(tr("MENU_GARAGE"), 36)
	title.set_anchors_preset(Control.PRESET_TOP_WIDE)
	title.offset_top = 6
	add_child(title)
	preview = Preview.new()
	preview.position = Vector2(220, 40)
	preview.size = Vector2(200, 90)
	preview.paint = Cosmetics.selected("paint")
	preview.sticker = Cosmetics.selected("sticker")
	add_child(preview)
	_column("paint", 20.0, tr("GARAGE_PAINT"))
	_column("sticker", 450.0, tr("GARAGE_STICKER"))
	info = Label.new()
	info.position = Vector2(0, 280)
	info.size = Vector2(640, 14)
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info.add_theme_color_override("font_color", Color("#ffe14a"))
	add_child(info)
	var challenge := MenuKit.button("", func(): pass)
	var cref := func(): challenge.text = tr("GARAGE_CHALLENGE") + ": " + tr("ON" if Cosmetics.challenge() else "OFF")
	cref.call()
	challenge.pressed.connect(func():
		Cosmetics.set_challenge(not Cosmetics.challenge())
		cref.call())
	challenge.position = Vector2(220, 300)
	challenge.custom_minimum_size = Vector2(200, 18)
	add_child(challenge)
	var back := MenuKit.button(tr("MENU_BACK"), func(): Flow.to_menu())
	back.position = Vector2(270, 324)
	back.custom_minimum_size = Vector2(100, 18)
	add_child(back)
	await get_tree().process_frame
	if not buttons.is_empty():
		buttons[0].grab_focus()

func _column(kind: String, x: float, head: String) -> void:
	var col := VBoxContainer.new()
	col.position = Vector2(x, 36)
	col.add_theme_constant_override("separation", 2)
	var h := Label.new()
	h.text = head
	h.add_theme_color_override("font_color", Color("#a9b8ff"))
	col.add_child(h)
	for it in Cosmetics.items:
		if it.kind != kind:
			continue
		var unlocked := Cosmetics.is_unlocked(it.id)
		var nm: String = it.name.get(lang, it.id)
		var b := Button.new()
		b.focus_mode = Control.FOCUS_ALL
		b.custom_minimum_size = Vector2(170, 18)
		b.text = ("◆ " if Cosmetics.selected(kind) == it.id else "") + (nm if unlocked else "🔒 " + nm)
		b.add_theme_font_size_override("font_size", 9)
		if not unlocked:
			b.add_theme_color_override("font_color", Color("#6a729c"))
		b.pressed.connect(func():
			if unlocked:
				Cosmetics.select(kind, it.id)
				Sfx.play("ui_ok")
				get_tree().reload_current_scene()
			else:
				Sfx.play("warn", -6.0))
		b.focus_entered.connect(func():
			Sfx.play("ui_move", -6.0)
			info.text = (Cosmetics.requirement_text(it) if not unlocked else (nm + "  ✔" if Cosmetics.selected(kind) == it.id else nm))
			if unlocked:
				if kind == "paint":
					preview.paint = it.id
				else:
					preview.sticker = it.id)
		col.add_child(b)
		buttons.append(b)
	add_child(col)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()   # vor dem Szenenwechsel, danach hat der Knoten keinen Viewport mehr
		Flow.to_menu()
