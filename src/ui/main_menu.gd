extends Control
## Hauptmenü: Weiter/Spielen, Levelauswahl, Musik, Optionen, Beenden. Vollständig per Tastatur und Gamepad bedienbar.

const Stage := preload("res://src/core/stage.gd")
const CommunitySelect := preload("res://src/ui/community_select.gd")
const LevelEditor := preload("res://src/ui/level_editor.gd")
const UpdateCheck := preload("res://src/core/update_check.gd")
const Calendar := preload("res://src/core/calendar.gd")
const TaxiView := preload("res://src/game/taxi_view.gd")
static var update_asked := false          # Runde 85: Frage nach der Update-Suche höchstens einmal je Programmstart
var update_btn: Button
var update_node: Node

var box: VBoxContainer
var stage: Control
var version: Label
var screen: Control = null
var code := CodeEntry.new("marvin")
var notice: Label
var help: Label                    # Hilfetext zum gewählten oder überfahrenen Menüpunkt (unten unter dem Menü)
var flags_col: Control = null      # Sprachflaggen, untereinander links neben dem Menü
var bug_btn: Button = null          # „Bug melden“ unten rechts (nur im Hauptmenü)
var kofi_btn: Button = null         # „Ko-fi“ links neben „Bug melden“ (seit Runde 87: im Raster steht die Sonderschicht)
var _return_focus := ""            # Menüpunkt, der zuletzt geöffnet wurde: dorthin springt der Fokus nach „Zurück“
## Hilfetexte der Menüpunkte (data/i18n); ein Test prüft, dass alle in beiden Sprachen vorhanden sind.
const HELP_KEYS := ["HELP_CONTINUE", "HELP_PLAY", "HELP_LEVELS", "HELP_TUTORIAL", "HELP_DAILY", "HELP_DAILY_LOCKED", "HELP_SHIFT", "HELP_SHIFT_LOCKED", "HELP_SHIFT_DONE", "HELP_OVERTIME", "HELP_OVERTIME_LOCKED", "HELP_COMMUNITY",
	"HELP_GARAGE", "HELP_STATS", "HELP_MUSIC", "HELP_OPTIONS", "HELP_CREDITS", "HELP_SLOT", "HELP_KOFI", "HELP_BUG", "HELP_DEBUG3D", "HELP_DEBUGEGGS", "HELP_QUIT", "HELP_DEBUG", "HELP_LANG_DE", "HELP_LANG_EN", "HELP_LANG_FR", "HELP_LANG_ES", "HELP_LANG_IT", "HELP_LANG_PT", "HELP_LANG_PL", "HELP_UPDATE"]

func _ready() -> void:
	preload("res://src/ui/ach_toast.gd").flush(get_tree())          # anstehende Erfolge (z. B. rückwirkend beim ersten Start)
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
	box.offset_top = -28.0                     # nach oben: unten bleibt eine Zeile für den Hilfetext frei
	box.offset_bottom = -28.0
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 2)
	box.grow_horizontal = Control.GROW_DIRECTION_END
	box.grow_vertical = Control.GROW_DIRECTION_BOTH
	box.custom_minimum_size = Vector2(150, 0)
	_add_button_panel()
	stage.add_child(box)
	version = MenuKit.version_label()
	stage.add_child(version)
	notice = MenuKit.title("", 12)
	notice.position = Vector2(0, 4)
	notice.size = Vector2(640, 16)
	notice.modulate.a = 0.0
	stage.add_child(notice)
	help = Label.new()
	help.position = Vector2(6, 344)                      # unten links, einzeilig bis zum Copyright (rechts), ohne das Menü zu überdecken
	help.size = Vector2(462, 14)
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	help.autowrap_mode = TextServer.AUTOWRAP_OFF
	help.clip_text = true
	help.add_theme_font_size_override("font_size", 8)
	help.add_theme_color_override("font_color", Color("#ffe9a0"))
	help.add_theme_color_override("font_outline_color", Color(0.02, 0.03, 0.1, 0.9))
	help.add_theme_constant_override("outline_size", 2)
	help.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(help)
	if Save.slot == 0 or OS.get_cmdline_user_args().has("--slots"):      # Dev: --slots zeigt die Platzwahl
		show_slots()                                    # Spielstand wählen (beim Start)
	elif Flow.menu_screen.begins_with("editor:"):       # zurück aus dem Testflug: wieder in den Editor
		var eid := Flow.menu_screen.substr(7)
		Flow.menu_screen = ""
		show_editor(eid, Flow.editor_session)
	elif Flow.menu_screen == "levels":                  # zurück vom angesehenen Bestflug: wieder die Levelauswahl
		Flow.menu_screen = ""
		show_levels()
	elif Flow.menu_screen == "community":               # zurück aus einem Community-Level: wieder die Liste zeigen
		Flow.menu_screen = ""
		show_community()
	elif OS.get_cmdline_user_args().has("--levels"):    # Dev: direkt die Levelauswahl zeigen
		show_levels()
	elif OS.get_cmdline_user_args().has("--community"): # Dev: direkt die Community-Liste zeigen
		show_community()
	elif OS.get_cmdline_user_args().has("--music"):     # Dev: direkt den Musikplayer zeigen
		show_music()
	elif OS.get_cmdline_user_args().has("--options") or _options_page() != "":   # Dev: direkt die Optionen zeigen (--options=audio|controls|display|game)
		show_options()
		var pg := _options_page()
		if pg != "":
			options.call_deferred("show_" + pg)
	elif OS.get_cmdline_user_args().has("--bug"):       # Dev: die Seite „Bug melden“ zeigen
		show_bug()
	elif OS.get_cmdline_user_args().has("--confirm"):   # Dev: die Nachfrage „Neues Spiel“ zeigen
		show_new_confirm(func(): pass)
	elif OS.get_cmdline_user_args().has("--update-ask"):   # Dev: die Frage nach der Update-Suche zeigen (Runde 85)
		show_update_ask()
	else:
		show_main()

func _options_page() -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--options="):
			return a.substr(10)
	return ""

func _clear() -> void:
	for c in box.get_children():
		box.remove_child(c)
		c.queue_free()
	if flags_col != null and is_instance_valid(flags_col):
		flags_col.queue_free()
	flags_col = null
	if bug_btn != null and is_instance_valid(bug_btn):
		bug_btn.queue_free()
	bug_btn = null
	if kofi_btn != null and is_instance_valid(kofi_btn):
		kofi_btn.queue_free()
	kofi_btn = null
	if update_btn != null and is_instance_valid(update_btn):
		update_btn.queue_free()
	update_btn = null
	help.text = ""

## Fokus setzen: auf die Flagge der gewählten Sprache (nach einem Sprachwechsel), auf den zuletzt geöffneten Menüpunkt (`restore`, nach „Zurück“),
## sonst auf den ersten Knopf.
func _focus_first(lang := "", restore := false) -> void:
	await get_tree().process_frame
	if lang != "" and flags_col != null and is_instance_valid(flags_col):
		for c in flags_col.get_children():
			if c.get_meta("lang", "") == lang:
				c.grab_focus()
				return
	var buttons := box.find_children("*", "Button", true, false)
	if bug_btn != null and is_instance_valid(bug_btn):
		buttons.append(bug_btn)                     # „Bug melden“ liegt außerhalb der Spalte (Rückkehr von seiner Seite)
	if kofi_btn != null and is_instance_valid(kofi_btn):
		buttons.append(kofi_btn)
	if restore and _return_focus != "":
		for c in buttons:
			if c.get_meta("key", "") == _return_focus and not (c as Button).disabled:
				_return_focus = ""
				c.grab_focus()
				return
	if restore:
		_return_focus = ""
	for c in buttons:
		c.grab_focus()
		return

## Menüknopf mit Hilfetext: der Text erscheint beim Fokussieren (Tastatur, Gamepad) und beim Überfahren mit der Maus; `key` merkt den Eintrag für den Rückweg.
func _menu_button(text: String, key: String, cb: Callable, small := false) -> Button:
	var wrapped := func():
		_return_focus = key
		cb.call()
	var b: Button = _small_button(text, wrapped) if small else MenuKit.button(text, wrapped)
	b.set_meta("key", key)
	b.set_meta("help", "HELP_" + key.to_upper())
	_bind_help(b)
	return b

func _bind_help(c: Control) -> void:
	c.focus_entered.connect(func(): help.text = _help_text(String(c.get_meta("help", ""))))
	c.mouse_entered.connect(func(): help.text = _help_text(String(c.get_meta("help", ""))))
	c.mouse_exited.connect(_help_for_focus)

## Hilfetext eines Eintrags; bei der Tagschicht mit der heutigen Regel und dem Ziel.
func _help_text(key: String) -> String:
	if key == "HELP_DAILY":
		var date := Daily.today()
		return tr(key) % (tr("DAY_RULE_" + DayShift.rule_of(date)) + " · " + tr("DAY_GOAL_" + DayShift.goal_of(date)))
	return tr(key)

## Nach dem Verlassen mit der Maus: wieder der Hilfetext des fokussierten Eintrags (oder keiner).
func _help_for_focus() -> void:
	var f := get_viewport().gui_get_focus_owner()
	help.text = _help_text(String(f.get_meta("help", ""))) if f != null and f.has_meta("help") else ""

## Gesperrter Eintrag: der Hilfetext nennt den Grund (auch bei Maus-Überfahren eines ausgegrauten Knopfs).
func _lock(b: Button, locked: bool) -> void:
	b.disabled = locked
	if locked:
		b.set_meta("help", String(b.get_meta("help")) + "_LOCKED")

func _next_open_level() -> String:
	var ids := Flow.level_ids()
	for id in ids:
		if not Save.is_completed(id):
			return id
	return ids[0] if not ids.is_empty() else ""

## Optionen und Nachfragen: Das Logo bleibt auf jeder Seite an derselben Stelle (die Spalte hat feste Höhe, der Inhalt beginnt oben); im Hauptmenü wird sie mittig angeordnet.
func _pin_top(on: bool) -> void:
	box.custom_minimum_size = Vector2(150, 330 if on else 0)
	box.alignment = BoxContainer.ALIGNMENT_BEGIN if on else BoxContainer.ALIGNMENT_CENTER

## Kopf aller Spaltenbildschirme: Logo, Untertitel und ein kleiner Abstand (Kinder 0–2; die Tafel dahinter beginnt erst bei Kind 3).
func _header() -> void:
	var mt := Control.new()
	mt.set_script(load("res://src/ui/menu_title.gd"))
	box.add_child(mt)
	box.add_child(MenuKit.title(tr("TITLE_SUB"), 10))
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 2)
	box.add_child(spacer)

func show_main(focus_lang := "") -> void:
	_hide_screen()
	_clear()
	_pin_top(false)
	_header()
	var id := _next_open_level()
	var ids := Flow.level_ids()
	if not Save.campaign().is_empty():              # „Fortsetzen“ nur mit laufender Karriere; erledigte Level allein genügen nicht (neues Spiel, Tutorial)
		box.add_child(_menu_button(tr("MENU_CONTINUE"), "continue", func():
			if not Flow.resume_campaign():
				Flow.start_campaign(id)))
	var start_new := func():
		Save.clear_campaign()
		Save.reset_workshop()
		var first: String = ids[0] if not ids.is_empty() else id
		Flow.start_campaign(first)                     # Neues Spiel beginnt direkt mit Level 1; die Flugschule ist der eigene Menüpunkt „Tutorial“
	box.add_child(_menu_button(tr("MENU_PLAY"), "play", func():
		if Save.campaign().is_empty():
			start_new.call()
		else:
			show_new_confirm(start_new)))
	box.add_child(_menu_button(tr("MENU_LEVELS"), "levels", show_levels))
	box.add_child(_menu_button(tr("MENU_TUTORIAL"), "tutorial", func(): Flow.start_tutorial("")))
	# Nebenmenüs kompakt in zwei Spalten, damit Menü und Flaggen auf den Bildschirm passen
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 2)
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	for entry in [
			[tr("MENU_DAILY"), "daily", func(): Flow.start_daily()],
			[tr("MENU_SHIFT"), "shift", func(): Flow.start_shift()],
			[tr("MENU_OVERTIME"), "overtime", func(): get_tree().change_scene_to_file(Flow.OT_MENU)],
			[tr("MENU_COMMUNITY"), "community", show_community],
			[tr("MENU_GARAGE"), "garage", func(): get_tree().change_scene_to_file("res://src/ui/garage.tscn")],
			[tr("MENU_STATS"), "stats", func(): get_tree().change_scene_to_file("res://src/ui/stats.tscn")],
			[tr("MENU_MUSIC"), "music", show_music],
			[tr("MENU_OPTIONS"), "options", show_options],
			[tr("MENU_CREDITS"), "credits", func(): get_tree().change_scene_to_file("res://src/ui/credits.tscn")],
			[Save.slot_label(), "slot", show_slots]]:
		grid.add_child(_menu_button(entry[0], entry[1], entry[2], true))
	_lock(grid.get_child(0), not Save.daily_unlocked(ids))     # Tagschicht: ab Sektor 1
	_lock(grid.get_child(1), not Save.shift_unlocked(ids))     # Nachtschicht: erst nach allen Leveln der Sektoren 1–4
	_lock(grid.get_child(2), not Flow.ot_unlocked())           # Sonderschicht: erst nach allen Leveln der Sektoren 1–6
	if Save.shift_unlocked(ids) and Save.shift_used_today(Daily.today()):      # … und nur ein Versuch pro Tag
		var sb := grid.get_child(1) as Button
		sb.disabled = true
		sb.set_meta("help", "HELP_SHIFT_DONE")
	box.add_child(grid)
	_link_grid(grid)
	# „Beenden“ allein in der letzten Zeile, mittig unter beiden Spalten (elf Einträge hätten es links allein stehen lassen)
	var quit_btn := _menu_button(tr("MENU_QUIT"), "quit", func(): get_tree().quit(), true)
	quit_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(quit_btn)
	_equalize_grid.call_deferred(grid, [quit_btn])
	# „Bug melden“ (mit Käfer) unten rechts über der Versionsangabe: In der Spalte ist kein Platz mehr (das Logo würde oben abgeschnitten).
	# Erreichbar mit Rechts von „Beenden“ bzw. „Ko-fi“, zurück mit Links/Hoch.
	bug_btn = _menu_button(tr("MENU_BUG"), "bug", show_bug, true)
	bug_btn.icon = BugIcon.texture()
	bug_btn.add_theme_constant_override("icon_max_width", 11)
	bug_btn.add_theme_constant_override("h_separation", 4)
	stage.add_child(bug_btn)
	kofi_btn = _menu_button(tr("MENU_KOFI"), "kofi", func(): OS.shell_open(Flow.KOFI_URL), true)      # per Gamepad wie jeder Eintrag anwählbar
	stage.add_child(kofi_btn)
	_place_bug_button.call_deferred(grid, quit_btn)
	if Save.debug:
		var drow := HBoxContainer.new()                  # Debug: verlassen und Taxi-Grafik 2D/Mischform (Vergleich) in einer Zeile
		drow.alignment = BoxContainer.ALIGNMENT_CENTER
		drow.add_theme_constant_override("separation", 4)
		var leave := func():
			Cosmetics.taxi_3d = true                    # Vergleich beendet: wieder die Mischform (Standard)
			Flow.set_debug(false)
			show_main()
		var flip := func():
			Cosmetics.taxi_3d = not Cosmetics.taxi_3d
			show_main()
		var lb := _menu_button(tr("DEBUG_LEAVE"), "debug", leave, true)
		var fb := _menu_button(tr("DEBUG_TAXI3D") % ("3D" if Cosmetics.taxi_3d else "2D"), "debug3d", flip, true)
		var eb := _menu_button(tr("DEBUG_EGGS"), "debugeggs", show_debug_eggs, true)
		drow.add_child(lb)
		drow.add_child(fb)
		drow.add_child(eb)
		_link_debug_row.call_deferred(quit_btn, lb, fb, eb)
		box.add_child(drow)
	# Sprachwahl: zwei Flaggen ohne Text untereinander links neben dem Menü (Auf/Ab wechselt, Rechts führt ins Menü, Links aus dem Menü zu den Flaggen)
	flags_col = MenuKit.flag_column(func(code): show_main(code))
	flags_col.position = Vector2(14, 74)                 # sieben Flaggen, senkrecht mittig neben dem Menü
	stage.add_child(flags_col)
	for fb in flags_col.get_children():
		_bind_help(fb)
	_focus_first(focus_lang, true)
	_slide_in()
	_update_flow.call_deferred()

## Links/Rechts innerhalb einer Zeile fest verdrahten: Die automatische Suche überspringt ausgegraute Knöpfe, Tagesflug und Nachtschicht (beide gesperrt) waren so nur von
## oben oder unten erreichbar.
func _link_grid(grid: GridContainer) -> void:
	var n := grid.get_child_count()
	for i in n:
		var b := grid.get_child(i) as Control
		if i % 2 == 0 and i + 1 < n:
			b.focus_neighbor_right = b.get_path_to(grid.get_child(i + 1))
		elif i % 2 == 1:
			b.focus_neighbor_left = b.get_path_to(grid.get_child(i - 1))

## Gitter fest in allen vier Richtungen verdrahten (Gamepad/Pfeiltasten): Links/Rechts in der Zeile, Hoch/Runter in der Spalte, aus der letzten Zeile
## nach unten auf `below` (z. B. „Zurück“) und von dort wieder hoch in die linke Spalte. Ränder bleiben stehen statt quer zu springen.
func _link_grid_full(grid: GridContainer, below: Control = null) -> void:
	var n := grid.get_child_count()
	var cols := maxi(grid.columns, 1)
	for i in n:
		var b := grid.get_child(i) as Control
		var col := i % cols
		b.focus_neighbor_left = b.get_path_to(grid.get_child(i - 1) if col > 0 else b)
		b.focus_neighbor_right = b.get_path_to(grid.get_child(i + 1) if col < cols - 1 and i + 1 < n else b)
		b.focus_neighbor_top = b.get_path_to(grid.get_child(i - cols) if i - cols >= 0 else b)
		var down: Control = grid.get_child(i + cols) if i + cols < n else (below if below != null else b)
		b.focus_neighbor_bottom = b.get_path_to(down)
		b.focus_next = b.get_path_to(grid.get_child(i + 1) if i + 1 < n else (below if below != null else b))
		b.focus_previous = b.get_path_to(grid.get_child(i - 1) if i > 0 else b)
	if below != null and n > 0:
		var last_left := grid.get_child(((n - 1) / cols) * cols) as Control
		below.focus_neighbor_top = below.get_path_to(last_left)
		below.focus_neighbor_bottom = below.get_path_to(below)
		below.focus_neighbor_left = below.get_path_to(below)
		below.focus_neighbor_right = below.get_path_to(below)
		below.focus_previous = below.get_path_to(grid.get_child(n - 1))

## Alle Knöpfe des Nebenmenüs so breit wie der breiteste (z. B. „Ko-fi: Unterstützen“), damit beide Spalten gleich aussehen.
## Erst im Baum gemessen, weil die Schrift aus dem Theme kommt.
func _equalize_grid(grid: GridContainer, extras: Array = []) -> void:
	if not is_instance_valid(grid):
		return
	var w := 0.0
	for c in grid.get_children():
		w = maxf(w, (c as Control).get_combined_minimum_size().x)
	for c in grid.get_children():
		(c as Control).custom_minimum_size.x = w
	for extra in extras:
		if is_instance_valid(extra):
			(extra as Control).custom_minimum_size.x = w            # so breit wie eine Spalte, mittig unter dem Gitter

## Debug-Zeile unter „Beenden“ fest verdrahten: Die automatische Suche fand sie mit Controller/Pfeiltasten nicht (Runde 82).
func _link_debug_row(quit_btn: Control, lb: Control, fb: Control, eb: Control) -> void:
	if not (is_instance_valid(quit_btn) and is_instance_valid(lb) and is_instance_valid(fb) and is_instance_valid(eb)):
		return
	quit_btn.focus_neighbor_bottom = quit_btn.get_path_to(lb)
	for b in [lb, fb, eb]:
		b.focus_neighbor_top = b.get_path_to(quit_btn)
		b.focus_neighbor_bottom = b.get_path_to(b)
	lb.focus_neighbor_right = lb.get_path_to(fb)
	fb.focus_neighbor_left = fb.get_path_to(lb)
	fb.focus_neighbor_right = fb.get_path_to(eb)
	eb.focus_neighbor_left = eb.get_path_to(fb)
	lb.focus_neighbor_left = lb.get_path_to(lb)
	if bug_btn != null and is_instance_valid(bug_btn):
		eb.focus_neighbor_right = eb.get_path_to(bug_btn)

## Runde 86 (nur Debug): Eastereggs zum Ansehen – Hut, Feuerwerk, Spätnacht-Leuchtreklame, Schnee, Ostereier, Valentinstag, seltener Gast, schnelles Nickerchen
## erzwingen (gilt bis zum Spielende) und passende Level direkt starten (Übungsflug, wenn eine Karriere läuft).
func show_debug_eggs() -> void:
	_clear()
	_pin_top(true)
	box.add_child(MenuKit.screen_title(tr("DEBUG_EGGS"), 20))
	var grid := GridContainer.new()                          # zwei Spalten, damit alles auf einen Bildschirm passt
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 4)
	box.add_child(grid)
	var hats := ["auto", "none", "party", "xmas"]
	var hat_names := {"auto": "DEBUG_EGG_AUTO", "none": "OFF", "party": "DEBUG_EGG_PARTY", "xmas": "DEBUG_EGG_XMAS"}
	var hb := MenuKit.button("", func(): pass)
	var hr := func(): hb.text = tr("DEBUG_EGG_HAT") + ": " + tr(hat_names[Calendar.force_hat])
	hr.call()
	hb.pressed.connect(func():
		Calendar.force_hat = hats[(hats.find(Calendar.force_hat) + 1) % hats.size()]
		hr.call())
	grid.add_child(hb)
	var tri := func(key: String, getter: Callable, setter: Callable) -> Button:
		var b := MenuKit.button("", func(): pass)
		var r := func():
			var v: int = getter.call()
			b.text = tr(key) + ": " + (tr("DEBUG_EGG_AUTO") if v < 0 else tr("ON" if v == 1 else "OFF"))
		r.call()
		b.pressed.connect(func():
			var v: int = getter.call()
			setter.call(0 if v < 0 else (1 if v == 0 else -1))
			r.call())
		return b
	grid.add_child(tri.call("DEBUG_EGG_FIREWORKS", func(): return Calendar.force_fireworks, func(v): Calendar.force_fireworks = v))
	grid.add_child(tri.call("DEBUG_EGG_LATE", func(): return Calendar.force_late, func(v): Calendar.force_late = v))
	grid.add_child(tri.call("DEBUG_EGG_SNOW", func(): return Calendar.force_snow, func(v): Calendar.force_snow = v))
	grid.add_child(tri.call("DEBUG_EGG_EASTER", func(): return Calendar.force_easter, func(v): Calendar.force_easter = v))
	grid.add_child(tri.call("DEBUG_EGG_VALENTINE", func(): return Calendar.force_valentine, func(v): Calendar.force_valentine = v))
	var fl := MenuKit.button("", func(): pass)
	var flr := func(): fl.text = tr("DEBUG_EGG_FLOPPI") + ": " + tr("ON" if Run.debug_floppi else "OFF")
	flr.call()
	fl.pressed.connect(func():
		Run.debug_floppi = not Run.debug_floppi
		flr.call())
	grid.add_child(fl)
	var nb := MenuKit.button("", func(): pass)
	var nr := func(): nb.text = tr("DEBUG_EGG_NAP") + ": " + tr("ON" if TaxiView.nap_after < 5.0 else "OFF")
	nr.call()
	nb.pressed.connect(func():
		TaxiView.nap_after = 9.0 if TaxiView.nap_after < 5.0 else 2.0
		nr.call())
	grid.add_child(nb)
	for entry in [["DEBUG_EGG_L42", "s4_09"], ["DEBUG_EGG_S5", "s5_01"], ["DEBUG_EGG_S8", "s8_01"], ["DEBUG_EGG_NEON", "s2_11"]]:
		var id: String = entry[1]
		grid.add_child(MenuKit.button(tr(entry[0]), func(): Flow.start_selected(id)))
	grid.add_child(MenuKit.button(tr("DEBUG_EGG_DAILY"), func(): Flow.start_daily()))
	var back := MenuKit.button(tr("MENU_BACK"), show_main)
	box.add_child(back)
	_equalize_grid.call_deferred(grid)
	_link_grid_full(grid, back)
	_focus_first()

## „Bug melden“ rechtsbündig über der Versionsangabe, „Ko-fi“ links daneben; Fokuswege: Rechts von „Beenden“ zu „Ko-fi“, weiter zu „Bug melden“,
## zurück mit Links; Hoch führt in die letzte Zeile des Rasters.
func _place_bug_button(grid: GridContainer, quit_btn: Control) -> void:
	if bug_btn == null or not is_instance_valid(bug_btn) or not is_instance_valid(quit_btn) or kofi_btn == null or not is_instance_valid(kofi_btn):
		return
	var sz := bug_btn.get_combined_minimum_size()
	bug_btn.size = sz
	bug_btn.position = Vector2(640.0 - 6.0 - sz.x, 340.0 - sz.y)
	var ksz := kofi_btn.get_combined_minimum_size()
	kofi_btn.size = Vector2(ksz.x, sz.y)
	kofi_btn.position = Vector2(bug_btn.position.x - 6.0 - ksz.x, bug_btn.position.y)
	var last := grid.get_child(grid.get_child_count() - 1) as Control
	quit_btn.focus_neighbor_right = quit_btn.get_path_to(kofi_btn)
	last.focus_neighbor_right = last.get_path_to(kofi_btn)
	kofi_btn.focus_neighbor_left = kofi_btn.get_path_to(quit_btn)
	kofi_btn.focus_neighbor_right = kofi_btn.get_path_to(bug_btn)
	kofi_btn.focus_neighbor_top = kofi_btn.get_path_to(last)
	kofi_btn.focus_neighbor_bottom = kofi_btn.get_path_to(kofi_btn)
	bug_btn.focus_neighbor_left = bug_btn.get_path_to(kofi_btn)
	bug_btn.focus_neighbor_top = bug_btn.get_path_to(last)
	bug_btn.focus_neighbor_bottom = bug_btn.get_path_to(bug_btn)
	bug_btn.focus_neighbor_right = bug_btn.get_path_to(bug_btn)

## Dunkle Tafel hinter den Menüknöpfen (nicht hinter Logo und Untertitel): die Knöpfe liegen sonst direkt auf dem detailreichen Stadtbild.
func _add_button_panel() -> void:
	var panel := Panel.new()
	panel.add_theme_stylebox_override("panel", MenuKit.panel_style())
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(panel)
	var fit := func():
		var r := Rect2()
		var first := true
		for i in range(3, box.get_child_count()):          # Kind 0–2: Logo, Untertitel, Abstand
			var c := box.get_child(i) as Control
			var cr := Rect2(box.position + c.position, c.size)
			r = cr if first else r.merge(cr)
			first = false
		panel.visible = box.visible and not first             # Levelauswahl/Spielstände blenden die Spalte aus, die Tafel mit
		panel.position = r.position - Vector2(8, 6)
		panel.size = r.size + Vector2(16, 12)
	box.item_rect_changed.connect(fit)
	box.sort_children.connect(func(): fit.call_deferred())
	box.visibility_changed.connect(fit)

func _small_button(text: String, cb: Callable) -> Button:
	var sb := MenuKit.button(text, cb)
	sb.custom_minimum_size = Vector2(66, 20)
	sb.add_theme_font_size_override("font_size", 8)
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
	if screen_panel != null:
		screen_panel.queue_free()
		screen_panel = null
	if not (c is SlotSelect or c is LevelEditor):          # der Editor braucht die ganze Fläche, die Spielstandwahl hat ihre eigene Gestaltung
		screen_panel = MenuKit.screen_panel()
		stage.add_child(screen_panel)
	screen = c
	stage.add_child(c)

var screen_panel: Panel = null

func _hide_screen() -> void:
	if screen != null:
		screen.queue_free()
		screen = null
	if screen_panel != null:
		screen_panel.queue_free()
		screen_panel = null
	box.visible = true
	version.visible = true

func show_levels() -> void:
	var ls := LevelSelect.new()
	ls.back = show_main
	_show_screen(ls)

## `pick_original`: Id eines Originals, mit dessen Auswahl (Debug) die Liste sofort wieder die Originalauswahl zeigt (Rückweg aus dem Editor eines Originals).
func show_community(pick_original := "") -> void:
	Flow.editor_session = ""
	Flow.editor_original = ""                  # eine neue Editorsitzung beginnt immer hier (nur die Rückkehr aus dem Testflug geht direkt in den Editor)
	var cs := CommunitySelect.new()
	cs.back = show_main
	cs.edit = show_editor
	cs.edit_original = show_original_editor
	cs.reopen_originals = pick_original
	_show_screen(cs)

## Debug: ein mitgeliefertes Level im Editor öffnen (Änderungen landen in data/levels).
func show_original_editor(id: String) -> void:
	var ed := LevelEditor.new()
	if not ed.open_original(id):
		ed.free()
		show_community()
		return
	ed.back = show_community.bind(id)               # zurück zur Auswahl der Originale, nicht zur Liste
	_show_screen(ed)

## Editor für ein neues Level (id == "") oder zum Bearbeiten einer Kopie von `id`; `session` = bereits gespeicherte Fassung dieser Sitzung.
func show_editor(id := "", session := "") -> void:
	var ed := LevelEditor.new()
	if not ed.open(id, session):
		ed.free()
		show_community()
		return
	ed.back = show_community.bind(ed.orig_id) if ed.orig_id != "" else show_community       # Original: zurück zur Auswahl der Originale
	_show_screen(ed)

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
		preload("res://src/ui/ach_toast.gd").flush(get_tree())
	ss.back = show_main if Save.slot != 0 else Callable()
	_show_screen(ss)

# ------------------------------------------------------------------ Runde 85: neue Versionen
## Einmal fragen (nur echte Starts, keine Entwicklungsaufrufe), sonst bei Zustimmung nachsehen und einen gefundenen Hinweis zeigen.
func _update_flow() -> void:
	if not is_inside_tree() or not box.visible:
		return
	if Settings.values.update_check == "ask":
		if not update_asked and not Save.dev_session and OS.get_cmdline_user_args().is_empty() and DisplayServer.get_name() != "headless":
			update_asked = true
			show_update_ask()
		return
	_show_update_button(UpdateCheck.pending(String(Settings.values.update_seen), Flow.VERSION))
	if update_node == null:
		update_node = UpdateCheck.new()
		add_child(update_node)
		update_node.found.connect(_show_update_button)
	update_node.check(Daily.today())

## Knopf „Version x verfügbar“ oben rechts; öffnet die Projektseite. Per Gamepad über „Bug melden“ (Hoch) erreichbar.
func _show_update_button(ver: String) -> void:
	if ver == "" or not is_instance_valid(bug_btn) or not box.visible:
		return
	if update_btn != null and is_instance_valid(update_btn):
		update_btn.queue_free()
	update_btn = _menu_button(tr("UPDATE_AVAILABLE") % UpdateCheck.plain(ver), "update", func(): OS.shell_open(UpdateCheck.PAGE_URL), true)
	update_btn.add_theme_color_override("font_color", Color("#5dff9a"))
	stage.add_child(update_btn)
	var sz := update_btn.get_combined_minimum_size()
	update_btn.size = sz
	update_btn.position = Vector2(640.0 - 6.0 - sz.x, 6.0)
	bug_btn.focus_neighbor_top = bug_btn.get_path_to(update_btn)
	update_btn.focus_neighbor_bottom = update_btn.get_path_to(bug_btn)
	update_btn.focus_neighbor_left = update_btn.get_path_to(bug_btn)
	update_btn.focus_neighbor_top = update_btn.get_path_to(update_btn)
	update_btn.focus_neighbor_right = update_btn.get_path_to(update_btn)

## Beim ersten Start: Darf das Spiel nach neuen Versionen sehen? (Antwort jederzeit in Optionen › Spiel änderbar.)
func show_update_ask() -> void:
	_clear()
	_pin_top(true)
	_header()
	box.add_child(MenuKit.title(tr("UPDATE_ASK")))
	var sub := Label.new()
	sub.text = tr("UPDATE_ASK_SUB")
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sub.custom_minimum_size = Vector2(240, 0)
	sub.add_theme_font_size_override("font_size", 8)
	box.add_child(sub)
	box.add_child(MenuKit.button(tr("UPDATE_YES"), func():
		Settings.set_value("update_check", "on")
		show_main()))
	box.add_child(MenuKit.button(tr("UPDATE_NO"), func():
		Settings.set_value("update_check", "off")
		show_main()))
	_focus_first()

## Neues Spiel bei laufender Karriere: erst nachfragen, der Fortschritt des Laufs geht sonst verloren.
func show_new_confirm(start: Callable) -> void:
	_clear()
	_pin_top(true)
	_header()
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

## „Bug melden“: Erklärung, E-Mail mit vorausgefülltem Betreff und Systemangaben, Protokollordner, Adresse kopieren.
func show_bug() -> void:
	_clear()
	_pin_top(true)
	_header()
	box.add_child(MenuKit.title(tr("BUG_TITLE")))
	var sub := Label.new()
	sub.text = tr("BUG_TEXT") % BugReport.ADDRESS
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sub.custom_minimum_size = Vector2(250, 0)
	sub.add_theme_font_size_override("font_size", 8)
	box.add_child(sub)
	var note := Label.new()
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.custom_minimum_size = Vector2(250, 11)
	note.add_theme_font_size_override("font_size", 8)
	note.add_theme_color_override("font_color", Color("#ffe14a"))
	var mail := MenuKit.button(tr("BUG_MAIL"), func():
		var err := OS.shell_open(bug_mailto())
		note.text = tr("BUG_MAIL_OPENED") if err == OK else tr("BUG_MAIL_FAILED") % BugReport.ADDRESS)
	mail.icon = BugIcon.texture()
	mail.add_theme_constant_override("icon_max_width", 11)
	box.add_child(mail)
	box.add_child(MenuKit.button(tr("BUG_LOGS"), func():
		var dir := ProjectSettings.globalize_path("user://logs")
		DirAccess.make_dir_recursive_absolute(dir)
		var logf := dir.path_join("godot.log")
		var err := OS.shell_show_in_file_manager(logf if FileAccess.file_exists(logf) else dir)
		note.text = tr("BUG_LOGS_OPENED") if err == OK else dir))
	box.add_child(MenuKit.button(tr("BUG_COPY"), func():
		DisplayServer.clipboard_set(BugReport.ADDRESS)
		note.text = tr("BUG_COPIED") % BugReport.ADDRESS))
	box.add_child(MenuKit.button(tr("MENU_BACK"), show_main))
	box.add_child(note)
	_focus_first()

## mailto:-Adresse mit Betreff „[GraviFare-Bug] v<Version> · <System>“ und den Systemangaben (Version, System, Grafik, Fenster, Sprache, Eingabe, Protokoll).
func bug_mailto() -> String:
	var win := DisplayServer.window_get_size()
	var mode := DisplayServer.window_get_mode()
	var fs := mode == DisplayServer.WINDOW_MODE_FULLSCREEN or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN
	var pads := Input.get_connected_joypads()
	var pad_names: Array = pads.map(func(d): return Input.get_joy_name(d))
	var info := [
		["Version", Flow.VERSION],
		["System", "%s %s (%s)" % [OS.get_name(), OS.get_version(), Engine.get_architecture_name()]],
		["Grafik", RenderingServer.get_video_adapter_name()],
		["Fenster", "%d×%d%s" % [win.x, win.y, " Vollbild" if fs else ""]],
		["Sprache", TranslationServer.get_locale().substr(0, 2)],
		["Eingabe", (", ".join(pad_names) if not pad_names.is_empty() else "-") + " / zuletzt " + Controls.last_device],
		["Spielstand", "Platz %d" % Save.slot],
		["Protokoll", ProjectSettings.globalize_path("user://logs/godot.log")],
	]
	return BugReport.mailto(BugReport.subject(Flow.VERSION, OS.get_name()), BugReport.body([tr("BUG_MAIL_Q1"), tr("BUG_MAIL_Q2")], info))

func show_options() -> void:
	_clear()
	_pin_top(true)
	_header()
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
