class_name MenuKit
extends RefCounted
## Gemeinsame Menü-Bausteine (Theme, Buttons, Slider) – ein einheitlicher Stil für alle Menüs.

## Knopf-Grafik mit Räumlichkeit: Verlaufsfläche, 1 px helle Kante, abgerundete Ecken und eine dunkle Unterkante (Tiefe).
## `lift` = Höhe der Unterkante in px (gedrückt: kleiner, die Fläche sinkt ab).
static func _button_box(top: Color, bot: Color, rim: Color, edge: Color, lift := 3) -> StyleBoxTexture:
	var w := 28
	var h := 24
	var r := 5.0
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var face_h := h - 3 - 2          # Platz für Unterkante (3) und Schatten (2)
	var y0 := 3 - lift               # gedrückt: Fläche sitzt tiefer
	for y in h:
		for x in w:
			var c := Color(0, 0, 0, 0)
			# Schatten unter dem Knopf
			if _in_rrect(x, y, 1, y0 + 4, w - 2, face_h + lift, r):
				c = Color(0, 0, 0, 0.28)
			# Unterkante (Dicke)
			if _in_rrect(x, y, 0, y0 + lift, w, face_h, r):
				c = edge
			# Fläche
			if _in_rrect(x, y, 0, y0, w, face_h, r):
				var u := clampf(float(y - y0) / float(face_h - 1), 0.0, 1.0)
				c = top.lerp(bot, u)
				if not _in_rrect(x, y, 1, y0 + 1, w - 2, face_h - 2, maxf(r - 1.0, 1.0)):
					c = rim                                              # dünne Kante
				elif y == y0 + 1:
					c = c.lightened(0.18)                                # Glanzkante oben
			img.set_pixel(x, y, c)
	var sb := StyleBoxTexture.new()
	sb.texture = ImageTexture.create_from_image(img)
	sb.texture_margin_left = 8.0
	sb.texture_margin_right = 8.0
	sb.texture_margin_top = 8.0
	sb.texture_margin_bottom = 9.0
	sb.content_margin_left = 8.0
	sb.content_margin_right = 8.0
	sb.content_margin_top = 4.0
	sb.content_margin_bottom = 6.0
	return sb

static func _in_rrect(x: int, y: int, rx: float, ry: float, rw: float, rh: float, r: float) -> bool:
	var px := float(x) + 0.5
	var py := float(y) + 0.5
	if px < rx or px > rx + rw or py < ry or py > ry + rh:
		return false
	var cx := clampf(px, rx + r, rx + rw - r)
	var cy := clampf(py, ry + r, ry + rh - r)
	return Vector2(px - cx, py - cy).length() <= r

static func make_theme() -> Theme:
	var th := Theme.new()
	var normal := _button_box(Color("#34407f"), Color("#1c2352"), Color("#7380c8"), Color("#0b0f2a"))
	var focus := _button_box(Color("#4a5ab5"), Color("#2a3680"), Color("#ffe14a"), Color("#0b0f2a"))
	var pressed := _button_box(Color("#2a3680"), Color("#4a5ab5"), Color("#ffe14a"), Color("#0b0f2a"), 1)
	var disabled := _button_box(Color("#232a52"), Color("#171c3c"), Color("#3a4580"), Color("#0b0f2a"))
	th.set_stylebox("normal", "Button", normal)
	th.set_stylebox("hover", "Button", focus)
	th.set_stylebox("focus", "Button", focus)
	th.set_stylebox("pressed", "Button", pressed)
	th.set_stylebox("disabled", "Button", disabled)
	th.set_color("font_color", "Button", Color("#d6dbf5"))
	th.set_color("font_focus_color", "Button", Color.WHITE)
	th.set_color("font_hover_color", "Button", Color.WHITE)
	th.set_color("font_pressed_color", "Button", Color.WHITE)
	th.set_color("font_disabled_color", "Button", Color("#5a628f"))
	th.set_color("font_outline_color", "Button", Color(0.02, 0.03, 0.1, 0.9))
	th.set_constant("outline_size", "Button", 1)
	th.set_font_size("font_size", "Button", 10)
	th.set_font_size("font_size", "Label", 10)
	th.set_color("font_color", "Label", Color("#c9cfee"))
	return th

static func button(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(128, 19)
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	b.focus_mode = Control.FOCUS_ALL
	b.pressed.connect(func():
		Sfx.play("ui_ok")
		cb.call())
	b.focus_entered.connect(func(): Sfx.play("ui_move", -6.0))
	return b

static func slider_row(label: String, value: float, on_change: Callable) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	var l := Label.new()
	l.text = label
	l.custom_minimum_size = Vector2(70, 0)
	var s := HSlider.new()
	s.min_value = 0.0
	s.max_value = 1.0
	s.step = 0.05
	s.value = value
	s.custom_minimum_size = Vector2(90, 16)
	s.focus_mode = Control.FOCUS_ALL
	s.value_changed.connect(func(v): on_change.call(v))
	row.add_child(l)
	row.add_child(s)
	return row

## Flaggenknopf für die Sprachwahl (kein Text). Gewählte Sprache: goldener Rahmen; Fokus: weißer Rahmen.
static func flag_button(tex: Texture2D, selected: bool, tip: String, cb: Callable) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(40, 26)
	b.tooltip_text = tip
	b.focus_mode = Control.FOCUS_ALL
	# Flagge als zentriertes Kind (Button-Icons sitzen nicht mittig im Rahmen)
	var flag := TextureRect.new()
	flag.texture = tex
	flag.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	flag.stretch_mode = TextureRect.STRETCH_SCALE
	flag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flag.set_anchors_preset(Control.PRESET_CENTER)
	flag.offset_left = -14.0
	flag.offset_right = 14.0
	flag.offset_top = -9.33
	flag.offset_bottom = 9.33
	flag.modulate = Color(1, 1, 1, 1.0 if selected else 0.62)
	b.add_child(flag)
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color("#10142b")
	normal.border_color = Color("#ffe14a") if selected else Color("#3a4580")
	normal.set_border_width_all(2)
	normal.set_content_margin_all(4)
	var focus := normal.duplicate() as StyleBoxFlat
	focus.border_color = Color.WHITE
	focus.set_border_width_all(3)
	for st in ["normal", "disabled"]:
		b.add_theme_stylebox_override(st, normal)
	for st in ["hover", "focus", "pressed"]:
		b.add_theme_stylebox_override(st, focus)
	b.focus_entered.connect(func(): flag.modulate = Color.WHITE)
	b.focus_exited.connect(func(): flag.modulate = Color(1, 1, 1, 1.0 if selected else 0.62))
	b.pressed.connect(func():
		Sfx.play("ui_ok")
		cb.call())
	b.focus_entered.connect(func(): Sfx.play("ui_move", -6.0))
	return b

## Sprachwahl: zwei Flaggen ohne Text (Haupt- und Pausenmenü). `on_select(code)` wird mit "de"/"en" aufgerufen.
static func flag_row(on_select: Callable) -> HBoxContainer:
	var flags := HBoxContainer.new()
	flags.alignment = BoxContainer.ALIGNMENT_CENTER
	flags.add_theme_constant_override("separation", 10)
	var cur := TranslationServer.get_locale().substr(0, 2)
	for entry in [["de", "res://assets/art/flag_de.png", "Deutsch"], ["en", "res://assets/art/flag_en.png", "English"]]:
		var code: String = entry[0]
		var fb := flag_button(load(entry[1]), cur == code, entry[2], func():
			Settings.set_value("language", code)
			on_select.call(code))
		fb.set_meta("lang", code)
		flags.add_child(fb)
	# Links/Rechts (Pfeiltasten, Stick, Steuerkreuz) wechselt zwischen den Flaggen
	var fbs := flags.get_children()
	for i in fbs.size():
		var me: Button = fbs[i]
		me.gui_input.connect(func(ev: InputEvent):
			var step := 0
			if ev.is_action_pressed("ui_right"):
				step = 1
			elif ev.is_action_pressed("ui_left"):
				step = -1
			if step != 0:
				var j := clampi(i + step, 0, fbs.size() - 1)
				if j != i:
					(fbs[j] as Button).grab_focus()
				me.accept_event())
	return flags

## Abdunklung über den Menühintergrund, reicht auf breiten Fenstern bis zum Rand.
static func dim_rect(alpha: float) -> ColorRect:
	var r := ColorRect.new()
	r.color = Color(0.02, 0.03, 0.1, alpha)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.position = Vector2(-2000, -2000)
	r.size = Vector2(4640, 4360)
	return r

## Spielversion, klein unten rechts auf der 640×360-Fläche.
static func version_label() -> Label:
	var l := Label.new()
	l.text = "v" + Flow.VERSION
	l.add_theme_font_size_override("font_size", 8)
	l.add_theme_color_override("font_color", Color("#c9cfee"))
	l.add_theme_color_override("font_outline_color", Color(0.02, 0.03, 0.1, 0.9))
	l.add_theme_constant_override("outline_size", 2)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.position = Vector2(590, 344)
	l.size = Vector2(44, 12)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	return l

static func title(text: String, size := 16) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", Color("#ffe14a"))
	if size >= 20:
		l.add_theme_font_override("font", Fonts.title)          # große Überschriften in der Pixel-Schrift
	return l

## Optionen (Kategorien-Seiten); wird von Haupt- und Pausenmenü benutzt. `back` kehrt zur vorherigen Seite zurück.
static func options_panel(back: Callable, rebuild: Callable = Callable()) -> VBoxContainer:
	return OptionsPanel.new(back, rebuild)
