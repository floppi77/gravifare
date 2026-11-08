extends Control
## Statistik-Seite: Gesamtstand des Profils (Level, Medaillen, Auslieferungen, Landungen, Pannen, Spielzeit). Dunkle Tafel wie im
## Hauptmenü, je Zeile ein Symbol aus assets/art/stat_icons.png (Reihenfolge wie die Zeilen, 18 px je Symbol).

func _ready() -> void:
	Music.play_theme("menu")
	Music.set_layers(true, false)
	theme = MenuKit.make_theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var backdrop := Control.new()
	backdrop.set_script(load("res://src/ui/menu_backdrop.gd"))
	add_child(backdrop)
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.03, 0.1, 0.65)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	box.grow_vertical = Control.GROW_DIRECTION_BOTH
	box.add_theme_constant_override("separation", 3)
	add_child(box)
	box.add_child(MenuKit.title(tr("MENU_STATS"), 36))
	var st: Dictionary = Save.data.stats
	var medals := 0
	for id in Save.data.completed:
		var m: Dictionary = Save.medals_of(id)
		medals += int(m.time) + int(m.clean) + int(m.pro)
	var secs := int(float(st.get("play_seconds", 0.0)))
	var rows := [
		["STAT_LEVELS", "%d / %d" % [Save.data.completed.size(), Flow.level_ids().size()]],
		["STAT_MEDALS", "%d" % medals],
		["STAT_DELIVERIES", "%d" % int(st.get("deliveries", 0))],
		["STAT_PERFECT", "%d" % int(st.get("perfect_landings", 0))],
		["STAT_STREAK", "%d" % int(st.get("best_streak", 0))],
		["STAT_SCORE", "%d" % Save.total_score()],
		["STAT_CREDITS", "¢ %d" % int(st.get("credits_total", 0))],
		["STAT_CRASHES", "%d" % int(st.get("crashes", 0))],
		["STAT_PUMP", "%d / %d" % [int(st.get("pump_hits", 0)), int(st.get("pump_explosions", 0))]],
		["STAT_SQUASH", "%d" % int(st.get("squashes", 0))],
		["STAT_SHIFT", "%s · %d" % [String(st.get("shift_best_grade", "–")), int(st.get("shift_best_score", 0))] if int(st.get("shift_best_score", 0)) > 0 else "–"],
		["STAT_SHIFT_TODAY", _shift_today()],
		["STAT_DAILY", "%d · %d" % [int(st.get("day_golds", 0)), Daily.current_streak(st, Daily.today())]],
		["STAT_TIME", "%d:%02d:%02d" % [secs / 3600, (secs / 60) % 60, secs % 60]],
	]
	var panel := Panel.new()
	panel.add_theme_stylebox_override("panel", MenuKit.panel_style(0.82))
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(panel)
	move_child(panel, box.get_index())
	box.item_rect_changed.connect(func():
		var first := box.get_child(1) as Control
		panel.position = box.position + Vector2(-14, first.position.y - 8)
		panel.size = Vector2(box.size.x + 28, box.size.y - first.position.y + 12))
	var icons: Texture2D = load("res://assets/art/stat_icons.png")
	var ri := 0
	for r in rows:
		var h := HBoxContainer.new()
		h.alignment = BoxContainer.ALIGNMENT_CENTER
		var ic := TextureRect.new()
		var at := AtlasTexture.new()
		at.atlas = icons
		at.region = Rect2(ri * 18, 0, 18, 18)
		ic.texture = at
		ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ic.custom_minimum_size = Vector2(12, 12)
		ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		h.add_child(ic)
		ri += 1
		var a := Label.new()
		a.text = tr(r[0])
		a.custom_minimum_size = Vector2(150, 0)
		var b := Label.new()
		b.text = r[1]
		b.custom_minimum_size = Vector2(90, 0)
		b.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		b.add_theme_color_override("font_color", Color("#ffe14a"))
		h.add_child(a)
		h.add_child(b)
		box.add_child(h)
	var back := MenuKit.button(tr("MENU_BACK"), func(): Flow.to_menu())
	box.add_child(back)
	await get_tree().process_frame
	back.grab_focus()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()   # vor dem Szenenwechsel, danach hat der Knoten keinen Viewport mehr
		Flow.to_menu()

## Nachtschicht von heute: Note und Punkte, "–" wenn noch nicht geflogen.
func _shift_today() -> String:
	var e := Save.shift_entry()
	if String(e.get("date", "")) != Daily.today() or not bool(e.get("finished", false)):
		return "–"
	return "%s · %d" % [String(e.get("grade", "E")), int(e.get("score", 0))]
