extends Control
## Hauptmenü: Weiter/Spielen, Levelauswahl, Musik, Optionen, Beenden. Vollständig per Tastatur und Gamepad bedienbar.

const Stage := preload("res://src/core/stage.gd")

var box: VBoxContainer
var stage: Control
var version: Label
var screen: Control = null
var code := CodeEntry.new("marvin")
var notice: Label

func _ready() -> void:
	Music.play_theme("menu")
	Music.set_layers(true, false)
	Music.duck(0.0)
	theme = MenuKit.make_theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var backdrop := Control.new()
	backdrop.set_script(load("res://src/ui/menu_backdrop.gd"))
	add_child(backdrop)
	stage = Stage.make(self)                  # Menü bleibt auf der zentrierten 640×360-Fläche (Ultrawide: Ränder zeigen nur den Hintergrund)
	box = VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_CENTER_LEFT)
	box.offset_left = 16.0
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 3)
	box.grow_horizontal = Control.GROW_DIRECTION_END
	box.grow_vertical = Control.GROW_DIRECTION_BOTH
	box.custom_minimum_size = Vector2(150, 0)
	stage.add_child(box)
	version = MenuKit.version_label()
	stage.add_child(version)
	notice = MenuKit.title("", 12)
	notice.position = Vector2(0, 4)
	notice.size = Vector2(640, 16)
	notice.modulate.a = 0.0
	stage.add_child(notice)
	if Save.slot == 0 or OS.get_cmdline_user_args().has("--slots"):      # Dev: --slots zeigt die Platzwahl
		show_slots()                                    # Spielstand wählen (beim Start)
	elif OS.get_cmdline_user_args().has("--levels"):    # Dev: direkt die Levelauswahl zeigen
		show_levels()
	elif OS.get_cmdline_user_args().has("--music"):     # Dev: direkt den Musikplayer zeigen
		show_music()
	else:
		show_main()

func _clear() -> void:
	for c in box.get_children():
		box.remove_child(c)
		c.queue_free()

func _focus_first(lang := "") -> void:
	await get_tree().process_frame
	for c in box.find_children("*", "Button", true, false):
		if lang == "" or c.get_meta("lang", "") == lang:
			c.grab_focus()
			return

func _next_open_level() -> String:
	var ids := Flow.level_ids()
	for id in ids:
		if not Save.is_completed(id):
			return id
	return ids[0] if not ids.is_empty() else ""

func show_main(focus_lang := "") -> void:
	_hide_screen()
	_clear()
	var mt := Control.new()
	mt.set_script(load("res://src/ui/menu_title.gd"))
	box.add_child(mt)
	box.add_child(MenuKit.title(tr("TITLE_SUB"), 10))
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 4)
	box.add_child(spacer)
	var any_done: bool = not Save.data.completed.is_empty()
	var id := _next_open_level()
	var ids := Flow.level_ids()
	if any_done or not Save.campaign().is_empty():
		box.add_child(MenuKit.button(tr("MENU_CONTINUE"), func():
			if not Flow.resume_campaign():
				Flow.start_campaign(id)))
	var start_new := func():
		Save.clear_campaign()
		var first: String = ids[0] if not ids.is_empty() else id
		if bool(Save.data.get("tutorial_done", false)):
			Flow.start_campaign(first)
		else:
			Flow.start_tutorial(first)                 # neuer Spielstand: erst die Flugschule, danach Level 1
	box.add_child(MenuKit.button(tr("MENU_PLAY"), func():
		if Save.campaign().is_empty():
			start_new.call()
		else:
			show_new_confirm(start_new)))
	box.add_child(MenuKit.button(tr("MENU_LEVELS"), show_levels))
	box.add_child(MenuKit.button(tr("MENU_TUTORIAL"), func(): Flow.start_tutorial("")))
	# Nebenmenüs kompakt in zwei Spalten, damit Menü und Flaggen auf den Bildschirm passen
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 3)
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	for entry in [
			[tr("MENU_DAILY"), func(): Flow.start_daily()],
			[tr("MENU_SHIFT"), func(): Flow.start_shift()],
			[tr("MENU_GARAGE"), func(): get_tree().change_scene_to_file("res://src/ui/garage.tscn")],
			[tr("MENU_STATS"), func(): get_tree().change_scene_to_file("res://src/ui/stats.tscn")],
			[tr("MENU_MUSIC"), show_music],
			[tr("MENU_OPTIONS"), show_options],
			[tr("MENU_CREDITS"), func(): get_tree().change_scene_to_file("res://src/ui/credits.tscn")],
			[tr("SLOT_CURRENT") % Save.slot, show_slots],
			[tr("MENU_KOFI"), func(): OS.shell_open(Flow.KOFI_URL)],      # per Gamepad wie jeder Eintrag anwählbar
			[tr("MENU_QUIT"), func(): get_tree().quit()]]:
		grid.add_child(_small_button(entry[0], entry[1]))
	grid.get_child(0).disabled = not Save.daily_unlocked(ids)     # Tagesflug: ab Sektor 1
	grid.get_child(1).disabled = not Save.shift_unlocked(ids)     # Nachtschicht: erst nach allen Leveln
	box.add_child(grid)
	_equalize_grid.call_deferred(grid)
	if Save.debug:
		box.add_child(MenuKit.button(tr("DEBUG_LEAVE"), func():
			Flow.set_debug(false)
			show_main()))
	# Sprachwahl: zwei Flaggen ohne Text unter dem Menü
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 3)
	box.add_child(gap)
	box.add_child(MenuKit.flag_row(func(code): show_main(code)))
	_focus_first(focus_lang)
	_slide_in()

## Alle Knöpfe des Nebenmenüs so breit wie der breiteste (z. B. „Ko-fi: Unterstützen“), damit beide Spalten gleich aussehen.
## Erst im Baum gemessen, weil die Schrift aus dem Theme kommt.
func _equalize_grid(grid: GridContainer) -> void:
	if not is_instance_valid(grid):
		return
	var w := 0.0
	for c in grid.get_children():
		w = maxf(w, (c as Control).get_combined_minimum_size().x)
	for c in grid.get_children():
		(c as Control).custom_minimum_size.x = w

func _small_button(text: String, cb: Callable) -> Button:
	var sb := MenuKit.button(text, cb)
	sb.custom_minimum_size = Vector2(62, 18)
	sb.add_theme_font_size_override("font_size", 7)
	return sb

## Menüeinträge gleiten nacheinander von links ein (nur beim ersten Aufbau, nicht bei „Weniger Bewegung“).
func _slide_in() -> void:
	if Settings.values.reduce_motion or _slid:
		return
	_slid = true
	var i := 0
	for c in box.get_children():
		if c is Button:
			c.modulate.a = 0.0
			var tw := create_tween()
			tw.tween_interval(0.12 + i * 0.07)
			tw.tween_property(c, "modulate:a", 1.0, 0.25)
			i += 1

var _slid := false

## Levelauswahl, Spielstände: eigene Vollbild-Ansichten auf der 640×360-Fläche; das Spaltenmenü ist dann ausgeblendet.
func _show_screen(c: Control) -> void:
	_clear()
	box.visible = false
	version.visible = c is SlotSelect
	if screen != null:
		screen.queue_free()
	screen = c
	stage.add_child(c)

func _hide_screen() -> void:
	if screen != null:
		screen.queue_free()
		screen = null
	box.visible = true
	version.visible = true

func show_levels() -> void:
	var ls := LevelSelect.new()
	ls.back = show_main
	_show_screen(ls)

func show_music() -> void:
	var mr := MusicRoom.new()
	mr.back = func():
		Music.play_theme("menu")
		Music.set_layers(true, false)
		show_main()
	_show_screen(mr)

## Drei unabhängige Spielstände als Disketten; beim Start ohne Abbrechen (erst wählen), später mit „Zurück“.
func show_slots() -> void:
	var ss := SlotSelect.new()
	ss.chosen = func(n: int):
		Save.select_slot(n)
		show_main()
	ss.back = show_main if Save.slot != 0 else Callable()
	_show_screen(ss)

## Neues Spiel bei laufendem Feldzug: erst nachfragen, der Fortschritt des Laufs geht sonst verloren.
func show_new_confirm(start: Callable) -> void:
	_clear()
	box.add_child(MenuKit.title(tr("MENU_NEW_CONFIRM")))
	var sub := Label.new()
	sub.text = tr("MENU_NEW_CONFIRM_SUB")
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sub.custom_minimum_size = Vector2(220, 0)
	box.add_child(sub)
	box.add_child(MenuKit.button(tr("SLOT_NO"), show_main))
	box.add_child(MenuKit.button(tr("MENU_NEW_YES"), start))
	_focus_first()

func show_options() -> void:
	_clear()
	options = MenuKit.options_panel(show_main, show_options)
	box.add_child(options)
	_focus_first()

var options: OptionsPanel = null

## Unsichtbarer Debug-Schalter: nur im Hauptmenü, nach der Speicherstandwahl.
func _input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo or event.unicode == 0:
		return
	if screen != null or Save.slot == 0 or Save.debug or not code.feed(char(event.unicode), Time.get_ticks_msec()):
		return
	Flow.set_debug(true)
	Sfx.play("exit", -4.0)
	show_main()
	notice.text = tr("DEBUG_ON")
	notice.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_interval(3.0)
	tw.tween_property(notice, "modulate:a", 0.0, 0.6)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and Save.slot != 0 and screen == null:      # Levelauswahl und Spielstände behandeln B/Esc selbst
		get_viewport().set_input_as_handled()
		if options != null and is_instance_valid(options) and options.is_inside_tree():
			options.go_back()                         # eine Ebene zurück
		elif box.get_child_count() > 0:
			show_main()
