extends Control
## Hauptmenü: Weiter/Spielen, Levelauswahl, Musik, Optionen, Beenden. Vollständig per Tastatur und Gamepad bedienbar.

const Stage := preload("res://src/core/stage.gd")
const CommunitySelect := preload("res://src/ui/community_select.gd")
const LevelEditor := preload("res://src/ui/level_editor.gd")

var box: VBoxContainer
var stage: Control
var version: Label
var screen: Control = null
var code := CodeEntry.new("marvin")
var notice: Label
var help: Label                    # Hilfetext zum gewählten oder überfahrenen Menüpunkt (unten unter dem Menü)
var flags_col: Control = null      # Sprachflaggen, untereinander links neben dem Menü
var _return_focus := ""            # Menüpunkt, der zuletzt geöffnet wurde: dorthin springt der Fokus nach „Zurück“
## Hilfetexte der Menüpunkte (data/i18n); ein Test prüft, dass alle in beiden Sprachen vorhanden sind.
const HELP_KEYS := ["HELP_CONTINUE", "HELP_PLAY", "HELP_LEVELS", "HELP_TUTORIAL", "HELP_DAILY", "HELP_DAILY_LOCKED", "HELP_SHIFT", "HELP_SHIFT_LOCKED", "HELP_SHIFT_DONE", "HELP_COMMUNITY",
	"HELP_GARAGE", "HELP_STATS", "HELP_MUSIC", "HELP_OPTIONS", "HELP_CREDITS", "HELP_SLOT", "HELP_KOFI", "HELP_QUIT", "HELP_DEBUG", "HELP_LANG_DE", "HELP_LANG_EN"]

func _ready() -> void:
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
	elif OS.get_cmdline_user_args().has("--confirm"):   # Dev: die Nachfrage „Neues Spiel“ zeigen
		show_new_confirm(func(): pass)
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
			[tr("MENU_COMMUNITY"), "community", show_community],
			[tr("MENU_GARAGE"), "garage", func(): get_tree().change_scene_to_file("res://src/ui/garage.tscn")],
			[tr("MENU_STATS"), "stats", func(): get_tree().change_scene_to_file("res://src/ui/stats.tscn")],
			[tr("MENU_MUSIC"), "music", show_music],
			[tr("MENU_OPTIONS"), "options", show_options],
			[tr("MENU_CREDITS"), "credits", func(): get_tree().change_scene_to_file("res://src/ui/credits.tscn")],
			[Save.slot_label(), "slot", show_slots],
			[tr("MENU_KOFI"), "kofi", func(): OS.shell_open(Flow.KOFI_URL)],      # per Gamepad wie jeder Eintrag anwählbar
			[tr("MENU_QUIT"), "quit", func(): get_tree().quit()]]:
		grid.add_child(_menu_button(entry[0], entry[1], entry[2], true))
	_lock(grid.get_child(0), not Save.daily_unlocked(ids))     # Tagschicht: ab Sektor 1
	_lock(grid.get_child(1), not Save.shift_unlocked(ids))     # Nachtschicht: erst nach allen Leveln
	if Save.shift_unlocked(ids) and Save.shift_used_today(Daily.today()):      # … und nur ein Versuch pro Tag
		var sb := grid.get_child(1) as Button
		sb.disabled = true
		sb.set_meta("help", "HELP_SHIFT_DONE")
	box.add_child(grid)
	_link_grid(grid)
	_equalize_grid.call_deferred(grid)
	if Save.debug:
		box.add_child(_menu_button(tr("DEBUG_LEAVE"), "debug", func():
			Flow.set_debug(false)
			show_main()))
	# Sprachwahl: zwei Flaggen ohne Text untereinander links neben dem Menü (Auf/Ab wechselt, Rechts führt ins Menü, Links aus dem Menü zu den Flaggen)
	flags_col = MenuKit.flag_column(func(code): show_main(code))
	flags_col.position = Vector2(14, 138)
	stage.add_child(flags_col)
	for fb in flags_col.get_children():
		_bind_help(fb)
	_focus_first(focus_lang, true)
	_slide_in()

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

## Alle Knöpfe des Nebenmenüs so breit wie der breiteste (z. B. „Ko-fi: Unterstützen“), damit beide Spalten gleich aussehen.
## Erst im Baum gemessen, weil die Schrift aus dem Theme kommt.
func _equalize_grid(grid: GridContainer) -> void:
	if not is_instance_valid(grid):
		return
	var w := 0.0
	for c in grid.get_children():
		w = maxf(w, (c as Control).get_combined_minimum_size().x)
	for c in grid.get_children():
		(c as Control).custom_minimum_size.x = w

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
	ss.back = show_main if Save.slot != 0 else Callable()
	_show_screen(ss)

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
