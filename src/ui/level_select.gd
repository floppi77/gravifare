class_name LevelSelect
extends Control
## Levelauswahl: je Sektor eine Seite mit elf Levelkarten und einer Vorschau (Grundriss, Name, Medaillen, Bestwerte).
## Sektorwechsel über die Reiter oder LB/RB bzw. Bild auf/ab; B/Esc geht zurück. Mit laufender Karriere ist ein Start ein Übungsflug.
## Die Reiter (SectorTab) füllen sich von links in der Sektorfarbe, je mehr Level des Sektors geschafft sind; der gewählte ist gelb umrandet.

var back: Callable
var ids: Array = []
var sector := 1
var tabs: Array = []
var grid: GridContainer
var head: Label
var preview: LevelPreview
var info_name: Label
var info_stats: Label
var prog_sector: Label
var prog_total: Label
var frame: Panel                 # Rahmen der Vorschau in der Sektorfarbe
var watch_btn: Button            # „Bestflug ansehen“ (Y / V), nur bei geschafften Leveln mit passender Aufzeichnung
var watch_id := ""
var watch_data := {}

const TAB_W := 64.0
const TAB_GAP := 4.0

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(MenuKit.dim_rect(0.62))
	ids = Flow.level_ids()
	sector = _start_sector()
	add_child(_at(MenuKit.screen_title(tr("MENU_LEVELS"), 21), Vector2(0, 2), Vector2(640, 24)))     # kleiner als sonst: darunter liegen gleich die Sektor-Reiter (sonst überdecken sie den Titel)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", int(TAB_GAP))
	for n in range(1, 10):
		var p := Progress.sector(ids, Save.data.completed, n)
		var b := SectorTab.new()
		b.number = n
		b.done = int(p.done)
		b.total = int(p.total)
		b.gold = Progress.gold(p)
		b.accent = sector_color(n)
		b.custom_minimum_size = Vector2(TAB_W, 26)
		b.pressed.connect(func():
			Sfx.play("ui_ok")
			_open(n))
		b.focus_entered.connect(func():
			Sfx.play("ui_move", -6.0)
			_open(n))
		row.add_child(b)
		tabs.append(b)
	add_child(_at(row, Vector2(0, 30), Vector2(640, 26)))
	head = MenuKit.title("", 12)
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	add_child(_at(head, Vector2(16, 59), Vector2(200, 16)))
	prog_sector = Label.new()                                   # Fortschritt des gewählten Sektors, rechts neben dem Namen
	prog_sector.add_theme_font_size_override("font_size", 9)
	prog_sector.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(_at(prog_sector, Vector2(156, 62), Vector2(150, 12)))
	grid = GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 4)
	add_child(_at(grid, Vector2(16, 79), Vector2(290, 200)))
	frame = Panel.new()
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_at(frame, Vector2(320, 59), Vector2(306, 174)))
	preview = LevelPreview.new()
	add_child(_at(preview, Vector2(322, 61), Vector2(302, 170)))
	info_name = _at(MenuKit.title("", 12), Vector2(322, 236), Vector2(302, 16))
	add_child(info_name)
	info_stats = Label.new()
	info_stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_at(info_stats, Vector2(322, 253), Vector2(302, 30)))
	watch_btn = Button.new()
	watch_btn.flat = true
	watch_btn.focus_mode = Control.FOCUS_NONE                   # per Y/V oder Maus; der Fokus bleibt auf den Levelkarten
	watch_btn.add_theme_font_size_override("font_size", 8)
	watch_btn.add_theme_color_override("font_color", Color("#9fe6ff"))
	watch_btn.add_theme_color_override("font_hover_color", Color("#ffffff"))
	watch_btn.pressed.connect(_watch)
	watch_btn.visible = false
	add_child(_at(watch_btn, Vector2(372, 282), Vector2(202, 14)))
	prog_total = Label.new()                                    # Gesamtfortschritt unter den Levelkarten
	prog_total.add_theme_font_size_override("font_size", 8)
	prog_total.add_theme_color_override("font_color", Color("#a9b8ff"))
	add_child(_at(prog_total, Vector2(16, 258), Vector2(290, 12)))
	var all := Progress.of(ids, Save.data.completed)
	prog_total.text = tr("LVL_PROGRESS_ALL") % [all.done, all.total, all.stars, all.stars_max]
	var hint := Label.new()
	hint.text = tr("LVL_SWITCH") + "   ·   " + tr("LVL_PRACTICE")         # eine Zeile: zwei Zeilen reichten in den Zurück-Knopf hinein
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hint.clip_text = true                                          # Mindestbreite 0: sonst wächst das Feld über 640 hinaus und der Text sitzt rechts der Mitte
	hint.add_theme_font_size_override("font_size", 8)
	add_child(_at(hint, Vector2(0, 306), Vector2(640, 16)))
	var bb := MenuKit.button(tr("MENU_BACK"), func(): back.call())
	add_child(_at(bb, Vector2(256, 327), Vector2(128, 19)))
	_open(sector)
	_focus_first_level()

## Farbe eines Sektors in der Levelauswahl: die Kantenfarbe seines Felsens, etwas kräftiger (Reiter, Kartenstreifen, Vorschaurahmen).
static func sector_color(n: int) -> Color:
	var c: Color = SectorLook.of(n).edge
	return Color.from_hsv(c.h, minf(c.s * 1.25, 1.0), minf(c.v * 1.08, 1.0))

func _at(c: Control, pos: Vector2, sz: Vector2) -> Control:
	c.position = pos
	c.size = sz
	c.custom_minimum_size = sz if c is LevelPreview else c.custom_minimum_size
	return c

## Laufende Karriere: deren Sektor; sonst der Sektor des nächsten offenen Levels.
func _start_sector() -> int:
	var id: String = String(Save.campaign().get("level", ""))
	if Flow.watch_level != "" and ids.has(Flow.watch_level):
		id = Flow.watch_level                                 # zurück vom angesehenen Bestflug: dessen Sektor
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
		(tabs[i] as SectorTab).selected = i + 1 == n
	var col := sector_color(n)
	head.text = tr("LVL_SECTOR") % [n, tr("SECTOR_%d" % n)]
	head.add_theme_color_override("font_color", col.lightened(0.35))
	var p := Progress.sector(ids, Save.data.completed, n)
	prog_sector.text = tr("LVL_PROGRESS") % [p.done, p.total, p.stars, p.stars_max]
	var sb := MenuKit.panel_style(0.0, 4)
	sb.border_color = col
	sb.set_border_width_all(2)
	frame.add_theme_stylebox_override("panel", sb)
	var campaign_id := String(Save.campaign().get("level", ""))
	for c in grid.get_children():
		grid.remove_child(c)
		c.queue_free()
	var first := true
	for i in range((n - 1) * 11, mini(n * 11, ids.size())):
		var id: String = ids[i]
		var lvl := LevelData.load_file(Flow.level_path(id))
		var b := LevelCard.new()
		b.number = lvl.number if lvl != null else i + 1
		b.accent = col
		b.current = id == campaign_id
		b.medals = Save.medals_of(id) if Save.is_completed(id) else {}
		b.state = LevelCard.State.DONE if Save.is_completed(id) else (LevelCard.State.OPEN if Save.is_unlocked(ids, i) else LevelCard.State.LOCKED)
		b.pressed.connect(func():
			Sfx.play("ui_ok")
			Flow.start_selected(id))
		b.focus_entered.connect(func(): Sfx.play("ui_move", -6.0))
		b.disabled = not Save.is_unlocked(ids, i)                  # gesperrte Level bleiben ansteuerbar, damit die Vorschau sie zeigt
		b.focus_entered.connect(_show.bind(lvl, id, i))
		b.mouse_entered.connect(_show.bind(lvl, id, i))
		grid.add_child(b)
		if first:
			first = false
			_show(lvl, id, i)

func _show(lvl: LevelData, id: String, i: int) -> void:
	if lvl == null:
		return
	preview.show_level(id, Save.is_completed(id) or Save.debug)      # Debug: alle Vorschaubilder scharf
	var lang := TranslationServer.get_locale().substr(0, 2)
	info_name.text = "%d · %s" % [lvl.number, lvl.display_name(lang)]
	var line := tr("LVL_JOBS") % lvl.jobs.size()
	if not Save.is_unlocked(ids, i):
		line = tr("LVL_LOCKED")
	elif Save.is_completed(id):
		line += "\n" + tr("LVL_BEST") % [int(Save.best_time(id)), Save.best_score(id)]
	else:
		line += "\n" + tr("LVL_NEW")
	info_stats.text = line
	watch_data = Replay.watchable(lvl, Save.slot) if Save.is_completed(id) else {}
	watch_id = id if not watch_data.is_empty() else ""
	watch_btn.visible = watch_id != ""
	if watch_btn.visible:
		var key := Controls.pad_name("Y") if Controls.last_device == "gamepad" else "V"
		watch_btn.text = tr("LVL_WATCH") % [key, int(float(watch_data.get("result", {}).get("time", 0.0)))]

## Bestflug des gewählten Levels ansehen.
func _watch() -> void:
	if watch_id == "" or watch_data.is_empty():
		return
	Sfx.play("ui_ok")
	Flow.start_watch(watch_id, watch_data)

func _focus_first_level() -> void:
	await get_tree().process_frame
	if grid.get_child_count() > 0:
		var k := 0
		if Flow.watch_level != "":                           # zurück vom angesehenen Bestflug: Fokus auf dessen Karte
			k = clampi(ids.find(Flow.watch_level) - (sector - 1) * 11, 0, grid.get_child_count() - 1)
			Flow.watch_level = ""
		grid.get_child(k).grab_focus()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		back.call()
		return
	if (event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_Y) or (event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_V):
		if watch_id != "":
			get_viewport().set_input_as_handled()
			_watch()
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
