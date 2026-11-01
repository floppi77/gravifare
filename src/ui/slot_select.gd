class_name SlotSelect
extends Control
## Startbildschirm: drei Spielstände als Disketten nebeneinander, mittig. Links/Rechts wählt, A/Enter legt die Diskette ein;
## darunter löscht „✕“ nach Rückfrage. `back` ist leer, solange noch kein Spielstand gewählt wurde.

var chosen: Callable
var back: Callable = Callable()
var row: HBoxContainer
var dialog: Control = null

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(MenuKit.dim_rect(0.42))
	var logo := Control.new()
	logo.set_script(load("res://src/ui/menu_title.gd"))
	add_child(logo)
	logo.position = Vector2(170, 10)
	logo.size = Vector2(300, 90)
	var head := MenuKit.title(tr("SLOT_TITLE"), 14)
	head.position = Vector2(0, 100)
	head.size = Vector2(640, 20)
	add_child(head)
	row = HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 14)
	row.position = Vector2(0, 124)
	row.size = Vector2(640, 196)
	add_child(row)
	_build()

func _build() -> void:
	for c in row.get_children():
		row.remove_child(c)
		c.queue_free()
	var first: Control = null
	for n in range(1, Save.SLOTS + 1):
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 3)
		var card := SlotCard.new()
		card.setup(n, Save.slot_summary(n), n == Save.slot)
		card.pressed.connect(func():
			Sfx.play("ui_ok")
			chosen.call(n))
		card.focus_entered.connect(func(): Sfx.play("ui_move", -6.0))
		col.add_child(card)
		var d := MenuKit.button("✕ " + tr("SLOT_DELETE"), _ask_delete.bind(n))
		d.custom_minimum_size = Vector2(150, 16)
		d.add_theme_font_size_override("font_size", 8)
		d.modulate.a = 1.0 if Save.slot_summary(n).exists else 0.0
		d.disabled = not Save.slot_summary(n).exists
		d.focus_mode = Control.FOCUS_ALL if Save.slot_summary(n).exists else Control.FOCUS_NONE
		col.add_child(d)
		row.add_child(col)
		if first == null or n == Save.slot:
			first = card
	if back.is_valid():
		var bb := MenuKit.button(tr("MENU_BACK"), func(): back.call())
		bb.position = Vector2(256, 334)
		add_child(bb)
	_focus(first)

func _focus(c: Control) -> void:
	await get_tree().process_frame
	if c != null and is_instance_valid(c):
		c.grab_focus()

func _ask_delete(n: int) -> void:
	row.visible = false
	dialog = VBoxContainer.new()
	dialog.alignment = BoxContainer.ALIGNMENT_CENTER
	dialog.add_theme_constant_override("separation", 5)
	dialog.position = Vector2(180, 140)
	dialog.size = Vector2(280, 120)
	dialog.add_child(MenuKit.title(tr("SLOT_CONFIRM") % n))
	var sub := Label.new()
	sub.text = tr("SLOT_CONFIRM_SUB")
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sub.custom_minimum_size = Vector2(260, 0)
	dialog.add_child(sub)
	var no := MenuKit.button(tr("SLOT_NO"), _close_dialog)
	dialog.add_child(no)
	dialog.add_child(MenuKit.button(tr("SLOT_YES"), func():
		Save.delete_slot(n)
		if Save.slot == 0:
			back = Callable()
		_close_dialog()))
	add_child(dialog)
	_focus(no)

func _close_dialog() -> void:
	dialog.queue_free()
	dialog = null
	row.visible = true
	_build()

func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel"):
		return
	if dialog != null:
		get_viewport().set_input_as_handled()
		_close_dialog()
	elif back.is_valid():
		get_viewport().set_input_as_handled()
		back.call()
