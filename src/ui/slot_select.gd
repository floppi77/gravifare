class_name SlotSelect
extends Control
## Startbildschirm: drei Spielstände als Disketten nebeneinander, mittig. Links/Rechts wählt, A/Enter legt die Diskette ein;
## darunter vergibt „✎“ einen Namen und „✕“ löscht nach Rückfrage. Ein freier Platz fragt beim ersten Mal nach einem Namen.
## `back` ist leer, solange noch kein Spielstand gewählt wurde.
const Osk := preload("res://src/ui/osk.gd")

var chosen: Callable
var back: Callable = Callable()
var row: HBoxContainer
var dialog: Control = null
var osk: Control = null

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(MenuKit.dim_rect(0.42))
	var logo := Control.new()
	logo.set_script(load("res://src/ui/menu_title.gd"))
	add_child(logo)
	logo.position = Vector2(170, 10)
	logo.size = Vector2(300, 90)
	var head := MenuKit.screen_title(tr("SLOT_TITLE"))
	head.position = Vector2(0, 98)
	head.size = Vector2(640, 26)
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
	var cards: Array = []           # je Platz die Diskette
	var slot_btns: Array = []       # je Platz [Name, Löschen] (leer bei freiem Platz)
	for n in range(1, Save.SLOTS + 1):
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 3)
		var card := SlotCard.new()
		card.setup(n, Save.slot_summary(n), n == Save.slot)
		var used: bool = Save.slot_summary(n).exists
		card.pressed.connect(func():
			Sfx.play("ui_ok")
			if used:
				chosen.call(n)
			else:
				_ask_name(n, true))
		card.focus_entered.connect(func(): Sfx.play("ui_move", -6.0))
		col.add_child(card)
		cards.append(card)
		var pair: Array = []
		var btns := HBoxContainer.new()
		btns.add_theme_constant_override("separation", 4)
		for spec in [["✎ " + tr("SLOT_RENAME"), _ask_name.bind(n, false)], ["✕ " + tr("SLOT_DELETE"), _ask_delete.bind(n)]]:
			var d := MenuKit.button(spec[0], spec[1])
			d.custom_minimum_size = Vector2(73, 16)
			d.add_theme_font_size_override("font_size", 8)
			d.modulate.a = 1.0 if used else 0.0
			d.disabled = not used
			d.focus_mode = Control.FOCUS_ALL if used else Control.FOCUS_NONE
			btns.add_child(d)
			if used:
				pair.append(d)
		slot_btns.append(pair)
		col.add_child(btns)
		row.add_child(col)
		if first == null or n == Save.slot:
			first = card
	var bb: Control = null
	if back.is_valid():
		bb = MenuKit.button(tr("MENU_BACK"), func(): back.call())
		bb.position = Vector2(256, 334)
		add_child(bb)
	_link_focus(cards, slot_btns, bb, cards.find(first))
	_focus(first)

## Steuerkreuz/Pfeiltasten (Runde 66): Disketten links/rechts untereinander, runter zum „Name“ des Platzes; in der Knopfreihe
## links/rechts über alle Plätze hinweg (Name ↔ Löschen ↔ Name ↔ Löschen …, freie Plätze werden übersprungen), hoch zur Diskette,
## runter zu „Zurück“. Die automatische Suche nach Nachbarn fand die kleinen Knöpfe nicht.
func _link_focus(cards: Array, slot_btns: Array, bb: Control, cur: int) -> void:
	var chain: Array = []           # alle Knöpfe der Reihe in Leserichtung
	var owner_card := {}
	for i in cards.size():
		for b in slot_btns[i]:
			chain.append(b)
			owner_card[b] = cards[i]
	for i in cards.size():
		var c: Control = cards[i]
		c.focus_neighbor_left = c.get_path_to(cards[i - 1]) if i > 0 else NodePath(".")
		c.focus_neighbor_right = c.get_path_to(cards[i + 1]) if i < cards.size() - 1 else NodePath(".")
		c.focus_neighbor_top = NodePath(".")
		var down: Control = null
		if not slot_btns[i].is_empty():
			down = slot_btns[i][0]
		else:                       # freier Platz: zum nächstgelegenen Knopf (rechts zuerst), sonst „Zurück“
			for k in range(1, cards.size()):
				for j in [i + k, i - k]:
					if down == null and j >= 0 and j < cards.size() and not slot_btns[j].is_empty():
						down = slot_btns[j][0]
			if down == null:
				down = bb
		c.focus_neighbor_bottom = c.get_path_to(down) if down != null else NodePath(".")
	for i in chain.size():
		var b: Control = chain[i]
		b.focus_neighbor_left = b.get_path_to(chain[i - 1]) if i > 0 else NodePath(".")
		b.focus_neighbor_right = b.get_path_to(chain[i + 1]) if i < chain.size() - 1 else NodePath(".")
		b.focus_neighbor_top = b.get_path_to(owner_card[b])
		b.focus_neighbor_bottom = b.get_path_to(bb) if bb != null else NodePath(".")
		b.focus_previous = b.focus_neighbor_left
		b.focus_next = b.focus_neighbor_right
	if bb != null:
		var up: Control = cards[maxi(cur, 0)]                 # hoch: „Name“ des aktuellen Platzes, sonst seine Diskette
		if cur >= 0 and not slot_btns[cur].is_empty():
			up = slot_btns[cur][0]
		bb.focus_neighbor_top = bb.get_path_to(up)
		bb.focus_neighbor_left = NodePath(".")
		bb.focus_neighbor_right = NodePath(".")

func _focus(c: Control) -> void:
	if not is_inside_tree():
		return                      # Test: Aufbau außerhalb des Baums
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

## Name eines Spielstands eingeben. `create`: freier Platz, danach wird er gewählt (auch „Ohne Namen“).
func _ask_name(n: int, create: bool) -> void:
	row.visible = false
	dialog = VBoxContainer.new()
	dialog.alignment = BoxContainer.ALIGNMENT_CENTER
	dialog.add_theme_constant_override("separation", 6)
	dialog.position = Vector2(170, 130)
	dialog.size = Vector2(300, 140)
	dialog.add_child(MenuKit.title(tr("SLOT_NAME_TITLE") % n))
	var edit := LineEdit.new()
	edit.custom_minimum_size = Vector2(220, 22)
	edit.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	edit.max_length = Shots.NAME_MAX
	edit.text = Save.slot_summary(n).name
	edit.placeholder_text = tr("SLOT_NAME_HINT")
	edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
	edit.add_theme_font_size_override("font_size", 11)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("#10142b")
	sb.border_color = Color("#6fa8ff")
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(5)
	sb.content_margin_left = 6.0
	sb.content_margin_right = 6.0
	edit.add_theme_stylebox_override("normal", sb)
	edit.add_theme_stylebox_override("focus", sb)
	dialog.add_child(edit)
	var finish := func(name_text: String, proceed: bool):
		Save.rename_slot(n, name_text)
		if proceed:
			chosen.call(n)
		else:
			_close_dialog()
	edit.text_submitted.connect(func(t): finish.call(t, create))
	var ok := MenuKit.button(tr("SLOT_OK"), func(): finish.call(edit.text, create))
	dialog.add_child(ok)
	dialog.add_child(MenuKit.button("⌨ " + tr("SLOT_KEYBOARD"), func(): _open_osk(edit)))
	if create:
		dialog.add_child(MenuKit.button(tr("SLOT_NO_NAME"), func(): chosen.call(n)))
	dialog.add_child(MenuKit.button(tr("SLOT_NO"), _close_dialog))
	add_child(dialog)
	_focus(edit if Controls.last_device == "keyboard" else ok)

## Controller: Bildschirmtastatur für den Namen.
func _open_osk(edit: LineEdit) -> void:
	if osk != null:
		return
	osk = Osk.new()
	osk.text = edit.text
	osk.max_len = Shots.NAME_MAX
	osk.title_text = tr("SLOT_NAME_PROMPT")
	osk.finished.connect(func(t: String, accepted: bool):
		if osk != null:
			osk.queue_free()
			osk = null
		if accepted:
			edit.text = t
		edit.grab_focus.call_deferred())
	add_child(osk)

func _close_dialog() -> void:
	dialog.queue_free()
	dialog = null
	row.visible = true
	_build()

func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel"):
		return
	if osk != null:
		return
	if dialog != null:
		get_viewport().set_input_as_handled()
		_close_dialog()
	elif back.is_valid():
		get_viewport().set_input_as_handled()
		back.call()
