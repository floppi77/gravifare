class_name PauseMenu
extends Control
## Pausenmenü über dem Spiel. Fokus startet auf "Fortsetzen"; B/Esc/Start schließen es wieder.

var game: Node
var box: VBoxContainer
var in_sub := false

func _ready() -> void:
	theme = MenuKit.make_theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	box = VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	box.grow_vertical = Control.GROW_DIRECTION_BOTH
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 4)
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

func show_main(focus_lang := "") -> void:
	in_sub = false
	_clear()
	box.add_child(MenuKit.title(tr("HUD_PAUSED")))
	box.add_child(MenuKit.button(tr("MENU_RESUME"), func(): game._set_paused(false)))
	box.add_child(MenuKit.button(tr("MENU_RESTART"), func():
		game._set_paused(false)
		game.load_level(game.level_path)))
	box.add_child(MenuKit.button(tr("MENU_OPTIONS"), func():
		_clear()
		in_sub = true
		box.add_child(MenuKit.options_panel(show_main, _reopen_options))
		_focus_first()))
	box.add_child(MenuKit.button(tr("MENU_TO_MENU"), func(): Flow.to_menu()))
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 8)
	box.add_child(gap)
	box.add_child(MenuKit.flag_row(func(code): show_main(code)))      # Sprachwahl auch im Spiel
	_focus_first(focus_lang)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and not event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		if in_sub:
			show_main()
		else:
			game._set_paused(false)

func _reopen_options() -> void:
	_clear()
	in_sub = true
	box.add_child(MenuKit.options_panel(show_main, _reopen_options))
	_focus_first()
