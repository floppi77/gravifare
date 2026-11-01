extends Control
## Werkstatt-Bildschirm: drei Einbauten mit je drei Stufen, bezahlt mit den Credits des laufenden Feldzugs.

const Stage := preload("res://src/core/stage.gd")
var box: VBoxContainer
var credits: Label

func _ready() -> void:
	Music.play_theme("menu")
	Music.set_layers(true, false)
	Music.duck(0.0)
	theme = MenuKit.make_theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var backdrop := Control.new()
	backdrop.set_script(load("res://src/ui/menu_backdrop.gd"))
	add_child(backdrop)
	var stage := Stage.make(self)
	stage.add_child(MenuKit.dim_rect(0.66))
	box = VBoxContainer.new()
	box.position = Vector2(90, 24)
	box.size = Vector2(460, 310)
	box.add_theme_constant_override("separation", 7)
	stage.add_child(box)
	_build(0)

func _build(focus_i: int) -> void:
	for c in box.get_children():
		box.remove_child(c)
		c.queue_free()
	box.add_child(MenuKit.title(tr("MENU_WORKSHOP"), 16))
	var has_run := not Save.campaign().is_empty()
	credits = Label.new()
	credits.text = tr("WS_CREDITS") % int(Workshop.credits(Save.data)) if has_run else tr("WS_NO_CAMPAIGN")
	credits.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	credits.add_theme_color_override("font_color", Color("#ffe14a"))
	box.add_child(credits)
	var first: Button = null
	var i := 0
	for id in Workshop.ITEMS:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var col := VBoxContainer.new()
		col.custom_minimum_size = Vector2(320, 44)
		var name_l := Label.new()
		var l := Workshop.level_of(Save.data, id)
		name_l.text = "%s  %s" % [tr("WS_%s" % id.to_upper()), "■".repeat(l) + "□".repeat(Workshop.MAX_LEVEL - l)]
		name_l.add_theme_color_override("font_color", Color.WHITE)
		col.add_child(name_l)
		var desc := Label.new()
		desc.text = tr("WS_%s_DESC" % id.to_upper())
		desc.add_theme_font_size_override("font_size", 9)
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc.custom_minimum_size = Vector2(320, 0)
		col.add_child(desc)
		row.add_child(col)
		var idx := i
		var b := MenuKit.button(tr("WS_MAX") if l >= Workshop.MAX_LEVEL else "¢ %d" % Workshop.price(Save.data, id), func():
			if Workshop.buy(Save.data, id):
				Save.write()
				Sfx.play("coin")
				_build(idx)
			else:
				Sfx.play("warn", -6.0))
		b.custom_minimum_size = Vector2(120, 24)
		row.add_child(b)
		box.add_child(row)
		if i == focus_i:
			first = b
		i += 1
	var back := MenuKit.button(tr("MENU_BACK"), func(): Flow.to_menu())
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(back)
	await get_tree().process_frame
	if first != null and is_instance_valid(first):
		first.grab_focus()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		Flow.to_menu()
