extends Control
## Hauptmenü: Weiter/Spielen, Levelauswahl, Optionen, Beenden. Vollständig per Tastatur und Gamepad bedienbar.

const Stage := preload("res://src/core/stage.gd")

var box: VBoxContainer

func _ready() -> void:
	Music.play_theme("menu")
	Music.set_layers(true, false)
	Music.duck(0.0)
	theme = MenuKit.make_theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var backdrop := Control.new()
	backdrop.set_script(load("res://src/ui/menu_backdrop.gd"))
	add_child(backdrop)
	var stage := Stage.make(self)             # Menü bleibt auf der zentrierten 640×360-Fläche (Ultrawide: Ränder zeigen nur den Hintergrund)
	box = VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_CENTER_LEFT)
	box.offset_left = 16.0
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 3)
	box.grow_horizontal = Control.GROW_DIRECTION_END
	box.grow_vertical = Control.GROW_DIRECTION_BOTH
	box.custom_minimum_size = Vector2(150, 0)
	stage.add_child(box)
	if Save.slot == 0 or OS.get_cmdline_user_args().has("--slots"):      # Dev: --slots zeigt die Platzwahl
		show_slots()                                    # Spielstand wählen (beim Start)
	elif OS.get_cmdline_user_args().has("--levels"):    # Dev: direkt die Levelauswahl zeigen
		show_levels()
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
	box.add_child(MenuKit.button(tr("MENU_PLAY"), func():
		Save.clear_campaign()
		var first: String = ids[0] if not ids.is_empty() else id
		if bool(Save.data.get("tutorial_done", false)):
			Flow.start_campaign(first)
		else:
			Flow.start_tutorial(first)))               # neuer Spielstand: erst die Flugschule, danach Level 1
	box.add_child(MenuKit.button(tr("MENU_LEVELS"), show_levels))
	box.add_child(MenuKit.button(tr("MENU_TUTORIAL"), func(): Flow.start_tutorial("")))
	# Nebenmenüs kompakt in zwei Spalten, damit Menü und Flaggen auf den Bildschirm passen
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 3)
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	for entry in [
			[tr("MENU_GARAGE"), func(): get_tree().change_scene_to_file("res://src/ui/garage.tscn")],
			[tr("MENU_STATS"), func(): get_tree().change_scene_to_file("res://src/ui/stats.tscn")],
			[tr("MENU_OPTIONS"), show_options],
			[tr("MENU_CREDITS"), func(): get_tree().change_scene_to_file("res://src/ui/credits.tscn")],
			[tr("SLOT_CURRENT") % Save.slot, show_slots],
			[tr("MENU_QUIT"), func(): get_tree().quit()]]:
		var sb := MenuKit.button(entry[0], entry[1])
		sb.custom_minimum_size = Vector2(62, 18)
		sb.add_theme_font_size_override("font_size", 7)
		grid.add_child(sb)
	box.add_child(grid)
	# Sprachwahl: zwei Flaggen ohne Text unter dem Menü
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 3)
	box.add_child(gap)
	box.add_child(MenuKit.flag_row(func(code): show_main(code)))
	_focus_first(focus_lang)
	_slide_in()

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

func show_levels() -> void:
	_clear()
	box.add_child(MenuKit.title(tr("MENU_LEVELS")))
	var ids := Flow.level_ids()
	# Bei 99 Leveln scrollt die Auswahl (Maus, Stick/Pfeiltasten folgen dem Fokus), die Seite bleibt niedrig
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 226)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	box.add_child(scroll)
	var grid := GridContainer.new()
	grid.columns = 8
	grid.add_theme_constant_override("h_separation", 3)
	grid.add_theme_constant_override("v_separation", 3)
	scroll.add_child(grid)
	for i in ids.size():
		var lvl := LevelData.load_file(Flow.level_path(ids[i]))
		var b := MenuKit.button("%02d" % (lvl.number if lvl else i + 1), func(): Flow.start_campaign(ids[i]))
		b.custom_minimum_size = Vector2(62, 20)
		if Save.is_completed(ids[i]):
			var mm := Save.medals_of(ids[i])
			b.text += " " + ("★" if mm.time else "☆") + ("★" if mm.clean else "☆") + ("★" if mm.pro else "☆")
		b.disabled = not Save.is_unlocked(ids, i)
		b.tooltip_text = lvl.names.get(TranslationServer.get_locale().substr(0, 2), lvl.id) if lvl else ids[i]
		grid.add_child(b)
	box.add_child(MenuKit.button(tr("MENU_BACK"), show_main))
	_focus_first()

## Drei unabhängige Spielstände: Auswahl, Löschen mit Rückfrage. Beim Start ohne Abbrechen (erst wählen), später mit „Zurück“.
func show_slots() -> void:
	_clear()
	box.add_child(MenuKit.title(tr("SLOT_TITLE")))
	for n in range(1, Save.SLOTS + 1):
		var info: Dictionary = Save.slot_summary(n)
		var row := HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override("separation", 3)
		var label := ""
		if info.exists:
			var secs: int = info.seconds
			label = "%d  ·  " % n + tr("SLOT_INFO") % [info.levels, "%d:%02d h" % [secs / 3600, (secs % 3600) / 60], info.score]
		else:
			label = "%d  ·  " % n + tr("SLOT_EMPTY")
		var b := MenuKit.button(label, func():
			Save.select_slot(n)
			show_main())
		b.custom_minimum_size = Vector2(196 if info.exists else 224, 22)
		if n == Save.slot:
			b.text += "  ◄"
		row.add_child(b)
		if info.exists:
			var d := MenuKit.button("✕", func(): show_slot_delete(n))
			d.custom_minimum_size = Vector2(24, 22)
			d.tooltip_text = tr("SLOT_DELETE")
			row.add_child(d)
		box.add_child(row)
	if Save.slot != 0:
		box.add_child(MenuKit.button(tr("MENU_BACK"), show_main))
	_focus_first()

func show_slot_delete(n: int) -> void:
	_clear()
	box.add_child(MenuKit.title(tr("SLOT_CONFIRM") % n))
	var sub := Label.new()
	sub.text = tr("SLOT_CONFIRM_SUB")
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sub.custom_minimum_size = Vector2(220, 0)
	box.add_child(sub)
	box.add_child(MenuKit.button(tr("SLOT_NO"), show_slots))
	box.add_child(MenuKit.button(tr("SLOT_YES"), func():
		Save.delete_slot(n)
		show_slots()))
	_focus_first()

func show_options() -> void:
	_clear()
	box.add_child(MenuKit.options_panel(show_main, show_options))
	_focus_first()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and box.get_child_count() > 0 and Save.slot != 0:
		show_main()
		get_viewport().set_input_as_handled()
