extends Control
## Hauptmenü: Weiter/Spielen, Levelauswahl, Optionen, Beenden. Vollständig per Tastatur und Gamepad bedienbar.

var box: VBoxContainer

func _ready() -> void:
	theme = MenuKit.make_theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var backdrop := Control.new()
	backdrop.set_script(load("res://src/ui/menu_backdrop.gd"))
	add_child(backdrop)
	box = VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 4)
	box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	box.grow_vertical = Control.GROW_DIRECTION_BOTH
	add_child(box)
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
	box.add_child(MenuKit.title("GRAVIFARE", 28))
	box.add_child(MenuKit.title(tr("TITLE_SUB"), 10))
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 10)
	box.add_child(spacer)
	var any_done: bool = not Save.data.completed.is_empty()
	var id := _next_open_level()
	box.add_child(MenuKit.button(tr("MENU_CONTINUE") if any_done else tr("MENU_PLAY"), func(): Flow.start_campaign(id)))
	box.add_child(MenuKit.button(tr("MENU_LEVELS"), show_levels))
	box.add_child(MenuKit.button(tr("MENU_OPTIONS"), show_options))
	box.add_child(MenuKit.button(tr("MENU_QUIT"), func(): get_tree().quit()))
	# Sprachwahl: zwei Flaggen ohne Text unter dem Menü
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 8)
	box.add_child(gap)
	box.add_child(MenuKit.flag_row(func(code): show_main(code)))
	_focus_first(focus_lang)

func show_levels() -> void:
	_clear()
	box.add_child(MenuKit.title(tr("MENU_LEVELS")))
	var ids := Flow.level_ids()
	var grid := GridContainer.new()
	grid.columns = 6
	box.add_child(grid)
	for i in ids.size():
		var lvl := LevelData.load_file(Flow.level_path(ids[i]))
		var b := MenuKit.button("%02d" % (i + 1), func(): Flow.start_campaign(ids[i]))
		b.custom_minimum_size = Vector2(36, 20)
		if Save.is_completed(ids[i]):
			b.text += " ✔"
		b.disabled = not Save.is_unlocked(ids, i)
		b.tooltip_text = lvl.names.get(TranslationServer.get_locale().substr(0, 2), lvl.id) if lvl else ids[i]
		grid.add_child(b)
	box.add_child(MenuKit.button(tr("MENU_BACK"), show_main))
	_focus_first()

func show_options() -> void:
	_clear()
	box.add_child(MenuKit.options_panel(show_main, show_options))
	_focus_first()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and box.get_child_count() > 0:
		show_main()
		get_viewport().set_input_as_handled()
