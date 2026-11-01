class_name LevelSelect
extends Control
## Levelauswahl: je Sektor eine Seite mit elf Levelkarten und einer Vorschau (Grundriss, Name, Medaillen, Bestwerte).
## Sektorwechsel über die Reiter oder LB/RB bzw. Bild auf/ab; B/Esc geht zurück. Mit laufendem Feldzug ist ein Start ein Übungsflug.

var back: Callable
var ids: Array = []
var sector := 1
var tabs: Array = []
var grid: GridContainer
var head: Label
var preview: LevelPreview
var info_name: Label
var info_stats: Label

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(MenuKit.dim_rect(0.62))
	ids = Flow.level_ids()
	sector = _start_sector()
	add_child(_at(MenuKit.title(tr("MENU_LEVELS"), 16), Vector2(0, 8), Vector2(640, 20)))
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 4)
	for n in range(1, 10):
		var b := MenuKit.button(str(n), _open.bind(n))
		b.custom_minimum_size = Vector2(30, 19)
		b.focus_entered.connect(_open.bind(n))
		row.add_child(b)
		tabs.append(b)
	add_child(_at(row, Vector2(0, 32), Vector2(640, 20)))
	head = _at(MenuKit.title("", 12), Vector2(16, 56), Vector2(290, 16))
	add_child(head)
	grid = GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 4)
	add_child(_at(grid, Vector2(16, 76), Vector2(290, 200)))
	preview = LevelPreview.new()
	add_child(_at(preview, Vector2(322, 58), Vector2(302, 168)))
	info_name = _at(MenuKit.title("", 12), Vector2(322, 230), Vector2(302, 16))
	add_child(info_name)
	info_stats = Label.new()
	info_stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_at(info_stats, Vector2(322, 247), Vector2(302, 40)))
	var hint := Label.new()
	hint.text = tr("LVL_SWITCH") + "\n" + tr("LVL_PRACTICE")
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 8)
	add_child(_at(hint, Vector2(0, 300), Vector2(640, 22)))
	var bb := MenuKit.button(tr("MENU_BACK"), func(): back.call())
	add_child(_at(bb, Vector2(256, 327), Vector2(128, 19)))
	_open(sector)
	_focus_first_level()

func _at(c: Control, pos: Vector2, sz: Vector2) -> Control:
	c.position = pos
	c.size = sz
	c.custom_minimum_size = sz if c is LevelPreview else c.custom_minimum_size
	return c

## Laufender Feldzug: dessen Sektor; sonst der Sektor des nächsten offenen Levels.
func _start_sector() -> int:
	var id: String = String(Save.campaign().get("level", ""))
	if id == "":
		for x in ids:
			if not Save.is_completed(x):
				id = x
				break
	var i := ids.find(id)
	return clampi(i / 11 + 1, 1, 9) if i >= 0 else 1

func _open(n: int) -> void:
	if n == sector and grid.get_child_count() > 0:
		return
	sector = n
	for i in tabs.size():
		tabs[i].modulate = Color(1.25, 1.2, 0.8) if i + 1 == n else Color.WHITE
	head.text = tr("LVL_SECTOR") % [n, tr("SECTOR_%d" % n)]
	for c in grid.get_children():
		grid.remove_child(c)
		c.queue_free()
	var first := true
	for i in range((n - 1) * 11, mini(n * 11, ids.size())):
		var id: String = ids[i]
		var lvl := LevelData.load_file(Flow.level_path(id))
		var text := "%02d" % (lvl.number if lvl != null else i + 1)
		if Save.is_completed(id):
			var mm := Save.medals_of(id)
			text += " " + ("★" if mm.time else "☆") + ("★" if mm.clean else "☆") + ("★" if mm.pro else "☆")
		var b := MenuKit.button(text, func(): Flow.start_selected(id))
		b.custom_minimum_size = Vector2(92, 40)
		b.disabled = not Save.is_unlocked(ids, i)
		b.focus_mode = Control.FOCUS_ALL                   # gesperrte Level bleiben ansteuerbar, damit die Vorschau sie zeigt
		b.focus_entered.connect(_show.bind(lvl, id, i))
		b.mouse_entered.connect(_show.bind(lvl, id, i))
		grid.add_child(b)
		if first:
			first = false
			_show(lvl, id, i)

func _show(lvl: LevelData, id: String, i: int) -> void:
	if lvl == null:
		return
	preview.show_level(id, Save.is_completed(id) or Save.DEBUG_UNLOCK_ALL)      # Debug: alle Vorschaubilder scharf
	var lang := TranslationServer.get_locale().substr(0, 2)
	info_name.text = "%d · %s" % [lvl.number, lvl.names.get(lang, lvl.id)]
	var line := tr("LVL_JOBS") % lvl.jobs.size()
	if not Save.is_unlocked(ids, i):
		line = tr("LVL_LOCKED")
	elif Save.is_completed(id):
		line += "\n" + tr("LVL_BEST") % [int(Save.best_time(id)), Save.best_score(id)]
	else:
		line += "\n" + tr("LVL_NEW")
	info_stats.text = line

func _focus_first_level() -> void:
	await get_tree().process_frame
	if grid.get_child_count() > 0:
		grid.get_child(0).grab_focus()

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
		_open(wrapi(sector + step, 1, 10))
		_focus_first_level()
