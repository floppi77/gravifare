class_name MusicRoom
extends Control
## Musikplayer im Hauptmenü: spielt alle freigeschalteten Stücke mit allen drei Schichten. Gesperrte Stücke nennen die Bedingung;
## im Debug-Modus ist alles wählbar. Bestätigen spielt oder stoppt, LB/RB bzw. Bild auf/ab wechselt den Titel, B/Esc geht zurück.

const ROW := Vector2(236, 19)
const LEFT := 78.0
const BAR_W := 484.0

var back: Callable
var tracks: Array = []
var buttons := {}                 # Thema -> Knopf
var playing := ""                 # laufendes Thema, "" = Stopp
var now_name: Label
var now_time: Label
var bar_fill: ColorRect

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(MenuKit.dim_rect(0.62))
	add_child(_at(MenuKit.screen_title(tr("MENU_MUSIC")), Vector2(0, 3), Vector2(640, 26)))
	tracks = TrackList.all()
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 12)
	add_child(_at(cols, Vector2(LEFT, 32), Vector2(BAR_W, 220)))
	var half := (tracks.size() + 1) / 2
	var col: VBoxContainer
	for i in tracks.size():
		if i % half == 0:
			col = VBoxContainer.new()
			col.add_theme_constant_override("separation", 1)
			cols.add_child(col)
		col.add_child(_row(tracks[i]))
	now_name = _at(MenuKit.title("", 12), Vector2(0, 254), Vector2(640, 16))
	add_child(now_name)
	var bar := ColorRect.new()
	bar.color = Color("#232a52")
	add_child(_at(bar, Vector2(LEFT, 273), Vector2(BAR_W, 3)))
	bar_fill = ColorRect.new()
	bar_fill.color = Color("#ffe14a")
	add_child(_at(bar_fill, Vector2(LEFT, 273), Vector2(0, 3)))
	now_time = Label.new()
	now_time.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	now_time.add_theme_font_size_override("font_size", 8)
	add_child(_at(now_time, Vector2(0, 278), Vector2(640, 12)))
	var hint := Label.new()
	hint.text = tr("MUSIC_HINT")
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 8)
	add_child(_at(hint, Vector2(0, 302), Vector2(640, 12)))
	var bb := MenuKit.button(tr("MENU_BACK"), func(): back.call())
	add_child(_at(bb, Vector2(256, 327), Vector2(128, 19)))
	playing = Music.current
	_mark()
	_focus_first()

func _at(c: Control, pos: Vector2, sz: Vector2) -> Control:
	c.position = pos
	c.size = sz
	return c

func _row(t: Dictionary) -> Button:
	var open := _is_open(t)
	var b := MenuKit.button(_name(t) if open else _lock_text(t), _pick.bind(String(t.theme)))
	b.custom_minimum_size = ROW
	b.add_theme_font_size_override("font_size", 8)
	b.disabled = not open
	buttons[t.theme] = b
	return b

func _is_open(t: Dictionary) -> bool:
	return TrackList.unlocked(t, Save.ever_completed(), Save.debug)

func _name(t: Dictionary) -> String:
	return tr("MUSIC_%s" % String(t.theme).to_upper())

func _lock_text(t: Dictionary) -> String:
	return tr("MUSIC_LOCK_SECTOR") % int(t.sector) if int(t.sector) > 0 else tr("MUSIC_LOCK_99")

func _pick(theme_id: String) -> void:
	if theme_id == playing:
		Music.stop()
		playing = ""
	else:
		Music.play_theme(theme_id)
		Music.set_layers(true, true)
		playing = theme_id
	_mark()

## Laufendes Stück golden markieren, Anzeige darunter setzen.
func _mark() -> void:
	now_name.text = tr("MUSIC_STOPPED")
	for t in tracks:
		var on: bool = t.theme == playing
		buttons[t.theme].modulate = Color(1.25, 1.2, 0.8) if on else Color.WHITE
		if on:
			now_name.text = _name(t) if int(t.sector) == 0 else "%s · %s" % [_name(t), tr("SECTOR_%d" % int(t.sector))]

func _process(_delta: float) -> void:
	var len_s := Music.track_length()
	var pos: float = Music.track_position() if playing != "" else 0.0
	bar_fill.size.x = BAR_W * clampf(pos / len_s, 0.0, 1.0) if len_s > 0.0 else 0.0
	now_time.text = "%s / %s" % [_clock(pos), _clock(len_s)] if playing != "" else ""

func _clock(s: float) -> String:
	return "%d:%02d" % [int(s) / 60, int(s) % 60]

## Voriges/nächstes freigeschaltetes Stück.
func _step(dir: int) -> void:
	var open := tracks.filter(_is_open)
	var i := -1
	for k in open.size():
		if open[k].theme == playing:
			i = k
	var t: Dictionary = open[wrapi(i + dir, 0, open.size())]
	_pick(String(t.theme))
	buttons[t.theme].grab_focus()

func _focus_first() -> void:
	await get_tree().process_frame
	buttons[tracks[0].theme].grab_focus()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		back.call()
		return
	var step := 0
	if event is InputEventJoypadButton and event.pressed:
		step = -1 if event.button_index == JOY_BUTTON_LEFT_SHOULDER else (1 if event.button_index == JOY_BUTTON_RIGHT_SHOULDER else 0)
	elif event is InputEventKey and event.pressed and not event.echo:
		step = -1 if event.physical_keycode == KEY_PAGEUP else (1 if event.physical_keycode == KEY_PAGEDOWN else 0)
	if step != 0:
		get_viewport().set_input_as_handled()
		_step(step)
