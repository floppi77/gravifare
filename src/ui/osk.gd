extends Control
## Bildschirmtastatur für den Controller (Name und Autor im Level-Editor): Steuerkreuz/Stick wählt, A tippt, X löscht, Y Leerzeichen,
## LB/RB Groß/Klein, Start fertig, B Abbruch. Ein Fenster über allem; das Ergebnis kommt mit `finished(text, accepted)`.

signal finished(text: String, accepted: bool)

const ROWS := ["1234567890", "qwertzuiop", "asdfghjklö", "yxcvbnmäüß", ".,-_'!?:&+"]
const KEY_W := 34.0
const KEY_H := 17.0
const GAP := 3.0

var text := ""
var max_len := 40
var title_text := ""
var shift := false
var keys: Array = []                       # [Button, Zeichen]
var text_label: Label
var shift_btn: Button
var _styles := {}

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(MenuKit.dim_rect(0.8))
	var box := ColorRect.new()
	box.color = Color("#10142b")
	box.position = Vector2(112, 52)
	box.size = Vector2(416, 256)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(box)
	var t := MenuKit.title(title_text, 10)
	t.position = Vector2(112, 58)
	t.size = Vector2(416, 14)
	add_child(t)
	text_label = Label.new()
	text_label.position = Vector2(126, 78)
	text_label.size = Vector2(388, 18)
	text_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	text_label.add_theme_font_size_override("font_size", 10)
	text_label.add_theme_color_override("font_color", Color("#ffe14a"))
	text_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(text_label)
	var x0 := 112.0 + (416.0 - (10.0 * KEY_W + 9.0 * GAP)) * 0.5
	for r in ROWS.size():
		for c in 10:
			var ch: String = ROWS[r][c]
			var b := _key(ch, _press_char.bind(ch), Vector2(x0 + c * (KEY_W + GAP), 102.0 + r * (KEY_H + GAP)), Vector2(KEY_W, KEY_H))
			keys.append([b, ch])
	var y := 102.0 + ROWS.size() * (KEY_H + GAP) + 6.0
	var specs := [[tr("ED_OSK_SHIFT"), _toggle_shift, 62.0], [tr("ED_OSK_SPACE"), _press_char.bind(" "), 104.0], [tr("ED_OSK_DEL"), _backspace, 62.0],
		[tr("ED_OSK_OK"), _accept, 62.0], [tr("ED_OSK_CANCEL"), _cancel, 62.0]]
	var total := 0.0
	for s in specs:
		total += s[2] + GAP
	var x := 112.0 + (416.0 - (total - GAP)) * 0.5
	for s in specs:
		var b := _key(s[0], s[1], Vector2(x, y), Vector2(s[2], KEY_H + 2.0))
		if s[0] == tr("ED_OSK_SHIFT"):
			shift_btn = b
		x += s[2] + GAP
	var hint := Label.new()
	hint.text = tr("ED_OSK_HINT")
	hint.position = Vector2(112, 288)
	hint.size = Vector2(416, 12)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 7)
	hint.add_theme_color_override("font_color", Color("#9aa6dd"))
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hint)
	_refresh()
	(keys[10][0] as Button).grab_focus.call_deferred()          # Start auf „q“: die Buchstaben liegen am nächsten

func _key(label: String, cb: Callable, pos: Vector2, sz: Vector2) -> Button:
	var b := MenuKit.button(label, cb)
	b.custom_minimum_size = sz
	b.position = pos
	b.size = sz
	b.add_theme_font_size_override("font_size", 8)
	b.focus_mode = Control.FOCUS_ALL
	add_child(b)
	if _styles.is_empty():
		for st in ["normal", "hover", "pressed", "focus", "disabled"]:
			var sb := b.get_theme_stylebox(st)
			if sb is StyleBoxTexture:
				var c := sb.duplicate() as StyleBoxTexture
				c.content_margin_left = 2.0
				c.content_margin_right = 2.0
				_styles[st] = c
	for st in _styles:
		b.add_theme_stylebox_override(st, _styles[st])
	b.size = sz
	return b

func _refresh() -> void:
	if text_label == null:
		return
	text_label.text = text + "_"
	for k in keys:
		var b: Button = k[0]
		var ch: String = k[1]
		b.text = ch.to_upper() if shift and ch != "ß" else ch
	if shift_btn != null:
		shift_btn.modulate = Color(1.3, 1.25, 0.8) if shift else Color.WHITE

func _press_char(ch: String) -> void:
	if text.length() >= max_len:
		return
	text += ch.to_upper() if shift and ch != "ß" else ch
	if shift and ch != " ":
		shift = false                           # wie auf dem Handy: ein Großbuchstabe, dann wieder klein
	_refresh()

func _backspace() -> void:
	text = text.substr(0, maxi(0, text.length() - 1))
	_refresh()

func _toggle_shift() -> void:
	shift = not shift
	_refresh()

func _accept() -> void:
	finished.emit(text.strip_edges(), true)

func _cancel() -> void:
	finished.emit(text, false)

func _input(event: InputEvent) -> void:
	if event is InputEventJoypadButton and event.pressed:
		match event.button_index:
			JOY_BUTTON_X:
				_backspace()
			JOY_BUTTON_Y:
				_press_char(" ")
			JOY_BUTTON_LEFT_SHOULDER, JOY_BUTTON_RIGHT_SHOULDER:
				_toggle_shift()
			JOY_BUTTON_START:
				_accept()
			JOY_BUTTON_B:
				_cancel()
			_:
				return
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_cancel()
