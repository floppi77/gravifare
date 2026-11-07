extends Control
## Level-Editor für Community-Level: Karte malen (Fels, Luft, Pads, Tank, Leben, Klinik, Dornen, Pumpe, Start) mit Stift, Rechteck und Füllen, live geprüft und mit
## der echten Spielansicht als Vorschau. Bedienung: Maus (links malen, rechts löschen, Rad = Auswahl), Tastatur (Pfeile/WASD bewegen, Leertaste malen, X löschen)
## und Controller (Stick/Steuerkreuz bewegen, A malen, B löschen, LB/RB Auswahl). Esc bzw. X (Controller) öffnet und schließt die Bedienfelder (Menü), alles dort ist per
## Fokus erreichbar. Das geöffnete Level bleibt unverändert: gespeichert wird eine eigene Fassung (die der letzten Speicherung dieser Sitzung ersetzt wird).

const CommunityLevel := preload("res://src/core/community_level.gd")
const CommunityStore := preload("res://src/core/community_store.gd")
const LevelEdit := preload("res://src/core/level_edit.gd")
const EditorCanvas := preload("res://src/ui/editor_canvas.gd")
const IconButton := preload("res://src/ui/icon_button.gd")
const Osk := preload("res://src/ui/osk.gd")
const LevelFiles := preload("res://src/core/level_files.gd")

const TILE := 16.0
const ZOOM := 0.75
const VIEW_POS := Vector2(6, 18)
const TOOL_PEN := 0
const TOOL_RECT := 1
const TOOL_FILL := 2
const MOVE_DELAY := 0.28
const MOVE_REPEAT := 0.055
const COLORS := {"#": Color("#6a78c8"), ".": Color(1, 1, 1, 0.10), "^": Color("#ff4d6d"), "S": Color("#5dd6ff"), "F": Color("#5dff9a"), "L": Color("#ff8ad8"),
	"H": Color("#ffffff"), "P": Color("#2f8f5a")}
const COL_OK := Color("#5dff9a")
const COL_WARN := Color("#ffb35a")                 # gültig, aber Speichern gesperrt (erst selbst lösen)
const COL_ERR := Color("#ff8a7a")
const COL_HINT := Color("#c3cdf5")                 # Hinweiszeile (vorher #9aa6dd, zu blass)
const MIN_FONT := 6                                # kleinste Schrift beim Einpassen (640×360-Fläche: 18 px bei 1080p)
const HOLD_DELAY := 0.38                           # Halten von „<“/„>“ bzw. Links/Rechts auf einem Wert: erste Wiederholung
const HOLD_REPEAT := 0.07
const HOLD_FAST_AFTER := 8                         # ab der achten Wiederholung große Schritte
const BIG_STEP := 10
const BACK_HOLD := 0.5                             # Controller: Back halten öffnet die Hilfe (kurz drücken = Vorschau)

var back: Callable
var model                                   # LevelEdit
var origin_id := ""                         # geöffnetes Level (bleibt unverändert)
var session_id := ""                        # in dieser Sitzung gespeicherte Fassung (wird beim nächsten Speichern ersetzt)
var res: Dictionary = {}
var last_jobs: Array = []
var tool := TOOL_PEN
var pal := 0
var cursor := Vector2i(4, 4)
var mouse_mode := false
var grid_on := true
var preview_mode := false
var gamepad_hint := false
var leave_dlg: Control = null               # Rückfrage beim Verlassen mit ungespeicherten Änderungen
var help: Control = null                    # Hilfeseite (H, Hilfe-Knopf, Controller: Back halten)
var cursor_info: Label                      # Titelzeile links: Feld unter dem Zeiger
var mode_badge: Label                       # Titelzeile rechts: Zeichnen oder Bedienfelder
var _badge_state := -1
var btn_undo: Button
var btn_redo: Button
var btn_help: Button
var btn_err: Button                         # neben der Statuszeile: nächsten Fehler zeigen (F)
var btn_grid: Button
var save_lock: Control                      # Schloss auf „Speichern“, solange nicht gespeichert werden kann
var _err_list: Array = []                   # Fehler der letzten Prüfung: {text, cells, movers}
var _err_idx := -1
var _hold_cb := Callable()                  # gehaltener „<“/„>“-Knopf bzw. Links/Rechts auf einem Wert
var _hold_t := 0.0
var _hold_dir := 0
var _hold_n := 0
var _val_dir := 0                           # Links/Rechts auf einem fokussierten Wert (-1/+1)
var _back_t := -1.0                         # Controller: Back gedrückt seit … (-1 = nicht gedrückt)
var _back_used := false
var view: Control
var canvas                                  # EditorCanvas
var overlay: Control
var panel: Control
var bottom: Control
var title: Label
var status: Label
var hint: Label
var page := 0                               # 0 Karte, 1 Objekte, 2 Level
var pages: Array = []
var page_btns: Array = []
var obj_ref: Dictionary = {}                # gewähltes Objekt (Verweis des Modells)
var kind_idx := 0
var kind_label: Label
var obj_label: Label
var param_box: Control
var param_vals: Dictionary = {}
var job_box: Control
var job_mode_btn: Button
var drag_last := Vector2i(-1, -1)
var _regrab := ""                           # Meta-Schlüssel des Knopfs, der nach dem Neuaufbau einer Liste wieder den Fokus bekommt
var name_edit: LineEdit
var author_edit: LineEdit
var mode_btn: Button
var mode_label: Label
var sel_label: Label
var kind_btns: Array = []
var drag_mode := ""                         # "move" | "size" | "point"
var drag_origin := Vector2i.ZERO
var drag_point := -1
var veh_pts: Array = []                     # Fahrzeugpfad im Bau: Eingang, Zwischenpunkte (Feldmittelpunkte)
var stroke_mode := 0                        # Zeichenmodus des laufenden Strichs (Linie, Rechteck, Füllen)
var pal_btns: Array = []
var look_label: Button                      # Level-Seite: Werte Optik und Dunkelheit (fokussierbar, Links/Rechts ändern)
var dark_label: Button
var btn_back: Button
var bar_btns: Array = []                    # untere Leiste: Speichern, Testflug, Autopilot, Vorschau, Raster, Zurück
var osk: Control = null                     # Bildschirmtastatur (Controller) für Name und Autor
var param_rows: Array = []                  # Objekte-Seite: Knopfpaare „<“, „>“ der Eigenschaften des gewählten Objekts
var obj_nav: Array = []                     # Objekte-Seite: Knöpfe „<“, „>“, „×“ der Objektauswahl
var level_rows: Array = []                  # Knopfreihen der Level-Seite (feste Fokusnachbarn; Auftragszeilen kommen beim Neuaufbau dazu)
var page_first: Array = [null, null, null]  # erster fokussierbarer Knopf je Seite (Einstieg mit dem Controller)
var btn_save: Button
var orig_id := ""                           # Original-Level-Modus (Debug): Id der mitgelieferten Datei, die beim Speichern geändert wird (sonst eigene Level)
var orig_raw: Dictionary = {}               # Inhalt dieser Datei
var orig_base: Dictionary = {}              # ihre bereinigte Fassung (Vergleichsbasis)
var base_id := ""                           # ID der bereinigten Dateifassung; eine gleiche Fassung braucht keinen Nachweis und wird nicht geschrieben
var look_btns: Array = []
var skip_btn: Button = null                 # nur im Debug-Modus: Handlösung überspringen
# Strich
var active := false
var stroke_erase := false
var stroke_last := Vector2i(-1, -1)
var rect_start := Vector2i(-1, -1)
var rect_cur := Vector2i(-1, -1)
# Wiederholung beim Halten
var move_dir := Vector2i.ZERO
var move_t := 0.0
var key_paint := false
var key_erase := false
var preview_t := -1.0
var validate_t := -1.0
var _thread: Thread = null                  # Prüfung läuft im Arbeitsfaden (kostet je nach Level bis zu einigen hundert Millisekunden)
var _model_rev := 0                         # zählt Änderungen; ein Ergebnis zu älterem Stand wird verworfen
var _thread_rev := 0
var _jobs_sig := ""
static var _warmed := false                 # Einmal je Programmlauf: die erste Zeichnung von Fels im Inneren und jeder Hindernisart baut Grafikzustände auf (bis 170 ms Ruckler)
var _tiles_sig := ""                        # Karte und Optik der gezeigten Felsschicht; nur bei Änderung wird sie neu gezeichnet
var _shown_rows: Array = []                 # Karte der gezeigten Vorschau: Unterschiede zeichnet die Zeichenfläche während eines Strichs selbst
var _slim_styles := {}
var _blink := 0.0                           # Restzeit des Blinkens fehlerhafter Objekte (nach gescheitertem Speichern oder Testflug)
var _bad_cells: Array = []                  # betroffene Kartenfelder (Vector2i)
var _bad_movers: Array = []                 # betroffene bewegliche Hindernisse (Index im Modell)
var input_ready := false
var trig_l := false
var trig_r := false

## Neues Level (id == "") oder Kopie des Levels `id` zum Bearbeiten. `session` = bereits in dieser Sitzung gespeicherte Fassung.
func open(id: String, session := "") -> bool:
	origin_id = id
	session_id = session if session != "" and CommunityStore.exists(session) else ""      # nur eine wirklich gespeicherte Fassung wird beim nächsten Speichern ersetzt
	if id == "":
		model = LevelEdit.blank()
	else:
		var r := CommunityStore.load_level(id)
		if not r.ok or r.has("stale_id"):
			return false
		model = LevelEdit.from_result(r)
		last_jobs = r.level.jobs
		model.dirty = not CommunityStore.exists(id)                  # Entwurf aus einem Testflug: noch nicht gespeichert
		if Flow.editor_original != "":                               # Rückkehr aus dem Testflug eines Originals
			if not _attach_original(Flow.editor_original):
				Flow.editor_original = ""
			else:
				model.dirty = r.id != base_id
	if model.author == "":
		model.author = Save.community_author()
	return true

## Original-Level (Debug-Modus) zum Bearbeiten öffnen: Gespeichert wird in die Datei des Levels, nicht als eigene Kopie.
func open_original(id: String) -> bool:
	if not _attach_original(id):
		return false
	var r := LevelFiles.clean_of(orig_raw)
	model = LevelEdit.from_result(r)
	last_jobs = r.level.jobs
	Flow.editor_original = id
	origin_id = ""
	session_id = ""
	model.author = Save.community_author()
	return true

func _attach_original(id: String) -> bool:
	if not (Save.debug and LevelFiles.can_write()):
		return false
	var raw := LevelFiles.read(id)
	var base := LevelFiles.clean_of(raw) if not raw.is_empty() else {}
	if base.is_empty() or not base.ok:
		return false
	orig_id = id
	orig_raw = raw
	orig_base = base
	base_id = base.id
	return true

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(MenuKit.dim_rect(0.86))
	if model == null:
		model = LevelEdit.blank()
	title = MenuKit.title("", 10)
	add_child(_at(title, Vector2(0, 2), Vector2(640, 14)))
	_build_top()
	_build_view()
	_build_panel()
	_build_bottom()
	_select_pal(0)
	_select_tool(TOOL_PEN)
	_set_page(0)
	_sync_fields()
	status.text = tr("CM_CHECKING")
	_start_async()                         # die erste Prüfung (bei großen Leveln mehrere hundert Millisekunden) blockiert das Öffnen nicht
	_refresh_preview()
	_warm_up()
	_update_hint()

## Zeichnet beim ersten Öffnen einmal (fast durchsichtig, zwei Bilder lang) ein Level mit Fels im Inneren und allen Hindernisarten, damit der erste Strich und das erste
## Objekt nicht ruckeln.
func _warm_up() -> void:
	if _warmed or not is_inside_tree():
		return
	_warmed = true
	var w = LevelEdit.blank()
	w.rect(Vector2i(14, 8), Vector2i(20, 12), "#")
	for k in LevelEdit.KINDS:
		w.add_object(k, 22 + LevelEdit.KINDS.find(k), 6)
	var d: Dictionary = w.to_level_dict()
	d["jobs"] = []
	d["id"] = "warm"
	canvas.modulate = Color(1, 1, 1, 0.02)
	canvas.show_level(LevelData.from_dict(d), true)
	await get_tree().process_frame
	await get_tree().process_frame
	if is_inside_tree():
		canvas.modulate = Color.WHITE
		_tiles_sig = ""
		_refresh_preview()

func _at(c: Control, pos: Vector2, sz: Vector2) -> Control:
	c.position = pos
	c.size = sz
	return c

# ---------------------------------------------------------------------------------------------------------------- Aufbau

## Titelzeile: links das Feld unter dem Zeiger (Koordinaten, Inhalt), rechts der Eingabemodus (Zeichnen oder Bedienfelder).
func _build_top() -> void:
	cursor_info = _label("", Vector2(6, 1), Vector2(230, 14), self)
	cursor_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	cursor_info.add_theme_font_size_override("font_size", 7)
	cursor_info.add_theme_color_override("font_color", COL_HINT)
	mode_badge = _label("", Vector2(492, 2), Vector2(144, 13), self)
	mode_badge.add_theme_font_size_override("font_size", 7)
	mode_badge.size = Vector2(144, 14)                 # nicht die Mindesthöhe der Felder: darunter beginnen die Seitenknöpfe
	_update_badge(true)

func _update_badge(force := false) -> void:
	var drawing := not _panels_have_focus()
	var state := (1 if drawing else 0) + (2 if page == 2 else 0)
	if state == _badge_state and not force:
		return
	_badge_state = state
	mode_badge.visible = not (drawing and page == 2) and not preview_mode     # auf der Level-Seite gibt es nichts zu zeichnen
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("#1d5c3a") if drawing else Color("#3a3f8c")
	sb.border_color = Color("#5dff9a") if drawing else Color("#ffe14a")
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(3)
	mode_badge.add_theme_stylebox_override("normal", sb)
	mode_badge.text = tr("ED_BADGE_DRAW") if drawing else tr("ED_BADGE_PANEL")
	if hint != null:
		_update_hint()
	if overlay != null:
		overlay.queue_redraw()

func _panels_have_focus() -> bool:
	return is_inside_tree() and get_viewport().gui_get_focus_owner() != null

func _build_view() -> void:
	view = Control.new()
	view.clip_contents = true
	view.mouse_filter = Control.MOUSE_FILTER_STOP
	view.focus_mode = Control.FOCUS_NONE
	view.gui_input.connect(_view_input)
	view.mouse_exited.connect(_view_exited)
	add_child(view)
	var bgc := ColorRect.new()
	bgc.color = Color(0.03, 0.04, 0.1)
	bgc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bgc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	view.add_child(bgc)
	canvas = EditorCanvas.new()
	view.add_child(canvas)
	overlay = Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.draw.connect(_draw_overlay)
	view.add_child(overlay)
	_layout_view()

func _layout_view() -> void:
	var z := 1.0 if preview_mode else ZOOM
	view.position = Vector2(0, 4) if preview_mode else VIEW_POS
	view.size = Vector2(model.w, model.h) * TILE * z
	canvas.scale = Vector2(z, z)
	overlay.queue_redraw()

func _cellsize() -> float:
	return TILE * (1.0 if preview_mode else ZOOM)

func _button(text: String, cb: Callable, pos: Vector2, sz: Vector2, parent: Control, fs := 8) -> Button:
	var b := MenuKit.button(text, cb)
	b.custom_minimum_size = sz            # vor der Größe: MenuKit.button setzt 128×19, und `size` wird auf das Minimum angehoben
	b.position = pos
	b.size = sz
	b.add_theme_font_size_override("font_size", fs)
	b.clip_text = true
	parent.add_child(b)
	_slim(b)
	b.size = sz                           # nach dem Eintragen im Baum hat die Größe sich dem (damals noch breiten) Rand angepasst: zurücksetzen
	return b

## Schmale Ränder, damit kleine Knöpfe ihre Größe behalten (der Menü-Stil lässt je 8 px Rand, das sprengt 33–45 px breite Knöpfe).
func _slim(b: Button) -> void:
	if _slim_styles.is_empty():
		for st in ["normal", "hover", "pressed", "focus", "disabled"]:
			var sb := b.get_theme_stylebox(st)
			if sb is StyleBoxTexture:
				var c := sb.duplicate() as StyleBoxTexture
				c.content_margin_left = 3.0
				c.content_margin_right = 3.0
				_slim_styles[st] = c                  # einmal angelegt und von allen kleinen Knöpfen geteilt (spart beim Neuaufbau der Listen viel Zeit)
	for st in _slim_styles:
		b.add_theme_stylebox_override(st, _slim_styles[st])

func _build_panel() -> void:
	panel = Control.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(panel)
	var x0 := 492.0
	var page_names := [tr("ED_PAGE_MAP"), tr("ED_PAGE_OBJ"), tr("ED_PAGE_LVL")]
	for i in 3:
		page_btns.append(_button(page_names[i], _set_page.bind(i), Vector2(x0 + i * 48.0, 18), Vector2(45, 17), panel, 7))
		var pg := Control.new()
		pg.position = Vector2(x0, 40)
		pg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(pg)
		pages.append(pg)
	_build_page_map(pages[0])
	_build_page_objects(pages[1])
	_build_page_level(pages[2])

## Knopf mit gezeichnetem Symbol (die Auswahl steht als Grafik zur Verfügung, der Name zusätzlich als Hinweistext und Beschriftung).
func _icon_button(icon: String, cb: Callable, pos: Vector2, sz: Vector2, parent: Control, tip := "") -> Button:
	var b: Button = IconButton.new()
	b.icon_id = icon
	b.custom_minimum_size = sz
	b.position = pos
	b.size = sz
	b.focus_mode = Control.FOCUS_ALL
	b.tooltip_text = tip
	b.clip_text = true
	b.pressed.connect(_icon_pressed.bind(cb))
	b.focus_entered.connect(_icon_focused.bind(b))
	b.focus_exited.connect(_icon_unfocused)
	parent.add_child(b)
	_slim(b)
	b.size = sz
	return b

func _icon_pressed(cb: Callable) -> void:
	Sfx.play("ui_ok")
	cb.call()

## Mit Controller oder Tastatur gibt es keinen Hinweistext beim Darüberfahren: das Feld unter der Palette nennt das fokussierte Symbol (danach wieder die Auswahl).
func _icon_focused(b: Button) -> void:
	Sfx.play("ui_move", -6.0)
	var i := pal_btns.find(b)
	if i >= 0:
		sel_label.text = _tile_name(i) + ("" if i == pal else " · " + tr("ED_PICK_A"))
		return
	i = kind_btns.find(b)
	if i >= 0:
		var kn: String = LevelEdit.KINDS[i]
		kind_label.text = "%s – %s" % [tr("ED_K_" + kn), tr("ED_KH_" + kn)]

func _icon_unfocused() -> void:
	if sel_label != null:
		sel_label.text = _tile_name(pal)
	if kind_label != null and not kind_btns.is_empty():
		var kn: String = LevelEdit.KINDS[kind_idx]
		kind_label.text = "%s – %s" % [tr("ED_K_" + kn), tr("ED_KH_" + kn)]

func _tile_name(i: int) -> String:
	var e: Array = LevelEdit.PALETTE[i]
	var ch: String = e[0]
	if LevelEdit.PAD_CHARS.contains(ch):
		return "%s %s" % [tr(e[1]), ch]
	if LevelEdit.DOOR_CHARS.contains(ch):
		return "%s %s" % [tr(e[1]), ch]
	return tr(e[1])

func _build_page_map(pg: Control) -> void:
	for i in LevelEdit.PALETTE.size():
		pal_btns.append(_icon_button(String(LevelEdit.PALETTE[i][0]), _select_pal.bind(i), Vector2((i % 5) * 29.0, (i / 5) * 27.0), Vector2(27, 25), pg, _tile_name(i)))
	sel_label = _label("", Vector2(0, 138), Vector2(144, 14), pg)
	mode_btn = _icon_button("mode_line", _primary_next, Vector2(0, 158), Vector2(30, 22), pg, tr("ED_MODE_TIP"))
	mode_label = _label("", Vector2(34, 156), Vector2(110, 26), pg)
	mode_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	mode_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	mode_label.add_theme_font_size_override("font_size", 7)
	_button(tr("ED_RENUMBER"), _renumber, Vector2(0, 186), Vector2(144, 17), pg, 7)

func _build_page_objects(pg: Control) -> void:
	for i in LevelEdit.KINDS.size():
		kind_btns.append(_icon_button(String(LevelEdit.KINDS[i]), _select_kind.bind(i), Vector2((i % 5) * 29.0, (i / 5) * 27.0), Vector2(27, 25), pg, tr("ED_K_" + String(LevelEdit.KINDS[i]))))
	kind_label = _label("", Vector2(0, 56), Vector2(144, 20), pg)
	kind_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	kind_label.add_theme_font_size_override("font_size", 7)
	var o_prev := _button("<", _obj_step.bind(-1), Vector2(0, 80), Vector2(18, 16), pg, 7)
	obj_label = _label("", Vector2(20, 81), Vector2(78, 14), pg)
	obj_label.add_theme_font_size_override("font_size", 7)
	var o_next := _button(">", _obj_step.bind(1), Vector2(100, 80), Vector2(18, 16), pg, 7)
	var o_del := _button("×", _obj_remove, Vector2(120, 80), Vector2(24, 16), pg, 8)
	obj_nav = [o_prev, o_next, o_del]
	param_box = Control.new()
	param_box.position = Vector2(0, 100)
	param_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pg.add_child(param_box)
	_select_kind(0)

func _build_page_level(pg: Control) -> void:
	var xs := [0.0, 20.0, 22.0, 100.0, 124.0, 20.0]
	var look := _stepper(pg, 0.0, xs, 17.0, func(d: int): _change_look(d), func(): _change_look(1), "l:look", 8)
	look_label = look[1]
	page_first[2] = look_label
	look_btns = [look[0], look[2]]
	if orig_id != "":
		for b in look:
			b.disabled = true                     # Sektor und Index bestimmen bei den Originalen die Levelnummer und den Preisrahmen
	var dark := _stepper(pg, 20.0, xs, 17.0, func(d: int): _change_dark(d), func(): _change_dark(1), "l:dark", 8)
	dark_label = dark[1]
	var reroll := _button(tr("ED_REROLL"), _reroll, Vector2(0, 40), Vector2(70, 17), pg, 7)
	job_mode_btn = _button("", _job_mode, Vector2(74, 40), Vector2(70, 17), pg, 7)
	level_rows = [[look_label], [dark_label], [reroll, job_mode_btn]]
	var job_y := 62.0
	if Save.debug:
		skip_btn = _button("", _toggle_skip_solve, Vector2(0, 60), Vector2(144, 17), pg, 7)       # Debug: Speichern ohne eigene Lösung
		level_rows.append([skip_btn])
		_update_skip_btn()
		job_y = 82.0
	job_box = Control.new()
	job_box.position = Vector2(0, job_y)
	job_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pg.add_child(job_box)

func _label(text: String, pos: Vector2, sz: Vector2, parent: Control) -> Label:
	var l := Label.new()
	l.text = text
	l.position = pos
	l.size = sz
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", 8)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.clip_text = true                      # ein zu langer Text vergrößert das Feld nicht mehr nach rechts (dann säße er nicht mehr mittig und läge unter dem Nachbarknopf)
	parent.add_child(l)
	l.size = Vector2(sz.x, maxf(sz.y, 17.0))        # Mindesthöhe wie bisher (Zeilen und Knöpfe sind darauf abgestimmt), aber nie breiter als angegeben
	return l

## Text in ein Feld setzen und die Schrift bei Bedarf verkleinern, bis er ganz hineinpasst (nie abgeschnitten, nie unter einem Knopf).
func _fit_text(l: Label, text: String, base_size := 7) -> void:
	l.text = text
	var fs := base_size
	var f: Font = l.get_theme_font("font")
	while fs > MIN_FONT and f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > l.size.x - 1.0:
		fs -= 1
	l.add_theme_font_size_override("font_size", fs)

## Wie `_fit_text`, für Wertknöpfe (Text in einem Knopf mit schmalen Rändern).
func _fit_button(b: Button, text: String, base_size := 7) -> void:
	b.text = text
	var fs := base_size
	var f: Font = b.get_theme_font("font")
	while fs > MIN_FONT and f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > b.size.x - 6.0:
		fs -= 1
	b.add_theme_font_size_override("font_size", fs)

## Zahlenwert als „<“ Wert „>“. `xs` = [x, Breite] von „<“, Wert und „>“. „<“/„>“ sind für die Maus (Halten wiederholt, nach einer Weile in großen Schritten); der Wert
## selbst ist der Fokuspunkt für Controller und Tastatur: Links/Rechts ändern ihn (Halten wiederholt), Umschalt+Links/Rechts, Bild auf/ab bzw. LB/RB machen große Schritte,
## A/Enter schaltet weiter (bei Schaltern: um). `step(d)` ändert um d Schritte, `accept()` schaltet weiter. Gibt [„<“, Wert, „>“] zurück.
func _stepper(parent: Control, y: float, xs: Array, h: float, step: Callable, accept: Callable, key: String, fs := 7) -> Array:
	var bm := _button("<", func(): step.call(-1), Vector2(xs[0], y), Vector2(xs[1], h), parent, 7)
	var bv := _button("", accept, Vector2(xs[2], y), Vector2(xs[3], h), parent, fs)
	var bp := _button(">", func(): step.call(1), Vector2(xs[4], y), Vector2(xs[5], h), parent, 7)
	for b in [bm, bp]:
		b.focus_mode = Control.FOCUS_NONE
		b.action_mode = BaseButton.ACTION_MODE_BUTTON_PRESS
		b.button_down.connect(_hold_begin.bind(step, -1 if b == bm else 1, 0))
		b.button_up.connect(_hold_end)
	bv.set_meta("step", step)
	bv.set_meta("key", key)
	bv.focus_entered.connect(_update_hint)
	bv.focus_exited.connect(_update_hint)
	return [bm, bv, bp]

## Halten beginnt (Maus auf „<“/„>“ bzw. Links/Rechts auf einem Wert, `val_dir` ≠ 0): erste Wiederholung nach HOLD_DELAY, danach alle HOLD_REPEAT Sekunden.
func _hold_begin(step: Callable, dir: int, val_dir: int) -> void:
	_hold_cb = step
	_hold_dir = dir
	_val_dir = val_dir
	_hold_t = HOLD_DELAY
	_hold_n = 0

func _hold_end() -> void:
	_hold_cb = Callable()
	_val_dir = 0

func _hold_tick(delta: float) -> void:
	if not _hold_cb.is_valid():
		return
	var held: bool = Input.is_action_pressed("ui_right" if _val_dir > 0 else "ui_left") if _val_dir != 0 else Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	if not held:
		_hold_end()
		return
	_hold_t -= delta
	if _hold_t <= 0.0:
		_hold_n += 1
		_hold_t = HOLD_REPEAT
		_hold_cb.call(_hold_dir * (BIG_STEP if _hold_n >= HOLD_FAST_AFTER else 1))

## Controller und Tastatur auf einem fokussierten Wert: Links/Rechts ändern ihn, statt den Fokus zu verschieben. Gibt true zurück, wenn das Ereignis verbraucht ist.
func _value_input(fo: Control, event: InputEvent) -> bool:
	if not (fo is Button and fo.has_meta("step")):
		return false
	var step: Callable = fo.get_meta("step")
	var big := 0
	if event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_PAGEUP, KEY_PAGEDOWN]:
		big = -1 if event.keycode == KEY_PAGEDOWN else 1
	elif event is InputEventJoypadButton and event.pressed and event.button_index in [JOY_BUTTON_LEFT_SHOULDER, JOY_BUTTON_RIGHT_SHOULDER]:
		big = -1 if event.button_index == JOY_BUTTON_LEFT_SHOULDER else 1
	if big != 0:
		get_viewport().set_input_as_handled()
		if not (fo as Button).disabled:
			step.call(big * BIG_STEP)
		return true
	for d in [-1, 1]:
		var act := "ui_left" if d < 0 else "ui_right"
		if not event.is_action(act):
			continue
		get_viewport().set_input_as_handled()                 # auch Wiederholungen und Loslassen: der Fokus bleibt auf dem Wert, die Wiederholung macht _hold_tick
		if event.is_action_pressed(act) and not (fo as Button).disabled and not (_hold_cb.is_valid() and _val_dir == d):      # Stick: jedes Bewegungsereignis gilt als „gedrückt“, die Wiederholung macht _hold_tick
			var shift: bool = event is InputEventKey and event.shift_pressed
			step.call(d * (BIG_STEP if shift else 1))
			Sfx.play("ui_move", -8.0)
			_hold_begin(step, d, d)
		return true
	return false

func _build_bottom() -> void:
	bottom = Control.new()
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bottom)
	status = _label("", Vector2(6, 283), Vector2(630, 21), bottom)
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.add_theme_color_override("font_color", Color("#ffe14a"))
	hint = _label("", Vector2(6, 305), Vector2(630, 11), bottom)
	hint.add_theme_font_size_override("font_size", 7)
	hint.add_theme_color_override("font_color", COL_HINT)
	btn_err = _button("", _next_error, Vector2(566, 285), Vector2(70, 17), bottom, 7)
	btn_err.visible = false
	_label(tr("ED_NAME"), Vector2(6, 318), Vector2(34, 16), bottom)
	name_edit = _line_edit(Vector2(42, 318), Vector2(220, 16), CommunityLevel.MAX_TEXT)
	name_edit.text_changed.connect(_name_changed)
	_label(tr("ED_AUTHOR"), Vector2(270, 318), Vector2(38, 16), bottom)
	author_edit = _line_edit(Vector2(310, 318), Vector2(130, 16), CommunityLevel.MAX_AUTHOR)
	author_edit.text_changed.connect(_author_changed)
	btn_undo = _button(tr("ED_UNDO"), func(): _undo_redo(true), Vector2(444, 318), Vector2(62, 16), bottom, 7)
	btn_redo = _button(tr("ED_REDO"), func(): _undo_redo(false), Vector2(510, 318), Vector2(62, 16), bottom, 7)
	btn_help = _button(tr("ED_HELP"), _open_help, Vector2(576, 318), Vector2(60, 16), bottom, 7)
	btn_undo.tooltip_text = tr("ED_UNDO_TIP")
	btn_redo.tooltip_text = tr("ED_REDO_TIP")
	btn_help.tooltip_text = tr("ED_HELP_TIP")
	var specs := [[tr("ED_SAVE"), func(): _save(true), 98.0], [tr("ED_TEST"), func(): _test_flight(false), 98.0], [tr("ED_AUTOPILOT"), func(): _test_flight(true), 98.0],
		[tr("ED_PREVIEW"), func(): _set_preview(true), 98.0], [tr("ED_GRID_ON"), _toggle_grid, 98.0], [tr("ED_BACK"), _request_back, 120.0]]
	var x := 6.0
	for sp in specs:
		var bb := _button(sp[0], sp[1], Vector2(x, 338), Vector2(sp[2], 18), bottom)
		bar_btns.append(bb)
		x += float(sp[2]) + 4.0
	btn_save = bar_btns[0]
	btn_grid = bar_btns[4]
	btn_back = bar_btns[5]
	save_lock = Control.new()
	save_lock.mouse_filter = Control.MOUSE_FILTER_IGNORE
	save_lock.position = Vector2(8, 3)
	save_lock.size = Vector2(9, 12)
	save_lock.draw.connect(_draw_lock)
	save_lock.visible = false
	btn_save.add_child(save_lock)
	_update_grid_btn()
	_update_undo_btns()
	_wire_bar()
	_wire_object_page()

## Fokusnachbarn der unteren Leiste: links/rechts innerhalb der Reihe, hoch zu Name bzw. Autor, runter zur Leiste. Die automatische Suche übersprang Knöpfe (Testflug)
## und blieb in den Textfeldern hängen, weil die ihre Pfeiltasten selbst verbrauchen.
func _wire_bar() -> void:
	for i in bar_btns.size():
		var b: Control = bar_btns[i]
		b.focus_neighbor_left = b.get_path_to(bar_btns[maxi(i - 1, 0)])
		b.focus_neighbor_right = b.get_path_to(bar_btns[mini(i + 1, bar_btns.size() - 1)])
		b.focus_neighbor_bottom = b.get_path_to(b)
		b.focus_neighbor_top = b.get_path_to([name_edit, name_edit, name_edit, author_edit, btn_undo, btn_help][i])
	var row: Array = [name_edit, author_edit, btn_undo, btn_redo, btn_help]
	var below: Array = [bar_btns[0], bar_btns[3], bar_btns[4], bar_btns[4], bar_btns[5]]
	for i in row.size():
		var c: Control = row[i]
		c.focus_neighbor_left = c.get_path_to(row[maxi(i - 1, 0)])
		c.focus_neighbor_right = c.get_path_to(row[mini(i + 1, row.size() - 1)])
		c.focus_neighbor_bottom = c.get_path_to(below[i])
	_wire_err_btn()

## „Fehler zeigen“ steht über der Name-Zeile, nur solange es Fehler gibt; nach oben führt die Zeile dann dorthin, sonst bleibt sie stehen.
func _wire_err_btn() -> void:
	if name_edit == null or btn_help == null:
		return
	for c in [name_edit, author_edit, btn_undo, btn_redo, btn_help]:
		c.focus_neighbor_top = c.get_path_to(btn_err if btn_err.visible else c)
	btn_err.focus_neighbor_bottom = btn_err.get_path_to(btn_help)
	btn_err.focus_neighbor_top = btn_err.get_path_to(btn_err)
	btn_err.focus_neighbor_left = btn_err.get_path_to(btn_err)
	btn_err.focus_neighbor_right = btn_err.get_path_to(btn_err)

## Schloss auf „Speichern“ (gesperrt: Fehler im Level oder noch nicht selbst gelöst).
func _draw_lock() -> void:
	save_lock.draw_arc(Vector2(4.5, 5.0), 3.0, PI, TAU, 10, COL_WARN, 1.6)
	save_lock.draw_line(Vector2(1.5, 5.0), Vector2(1.5, 6.0), COL_WARN, 1.6)
	save_lock.draw_line(Vector2(7.5, 5.0), Vector2(7.5, 6.0), COL_WARN, 1.6)
	save_lock.draw_rect(Rect2(0.5, 5.5, 8.0, 6.0), COL_WARN)
	save_lock.draw_rect(Rect2(3.75, 7.5, 1.5, 2.5), Color(0.1, 0.1, 0.2))

func _update_save_btn() -> void:
	if btn_save == null or save_lock == null:
		return
	var blocked := _save_blocked()
	var locked: bool = blocked or not res.get("ok", false)
	save_lock.visible = locked
	btn_save.modulate = Color(0.8, 0.8, 0.88) if locked else Color.WHITE
	btn_save.tooltip_text = tr("ED_SAVE_TIP_SOLVE") if blocked else (tr("ED_SAVE_TIP_ERR") if locked else "")

func _update_grid_btn() -> void:
	if btn_grid != null:
		btn_grid.text = tr("ED_GRID_ON") if grid_on else tr("ED_GRID_OFF")

func _update_undo_btns() -> void:
	if btn_undo != null:
		btn_undo.disabled = not model.can_undo()
		btn_redo.disabled = not model.can_redo()

## Feste Fokusnachbarn der Seiten (Controller, Tastatur): links/rechts in der Reihe, hoch/runter zur Reihe darüber/darunter (gleiche Spalte bzw. letzte Taste). Oben geht es zu
## `up` (Seitenknopf), unten zu `down` (Leiste). Die automatische Suche sprang von „<“ zu den Seitenknöpfen statt zu „>“ und übersprang Knöpfe.
func _wire_rows(rows: Array, up: Control, down: Control) -> void:
	for r in rows.size():
		var row: Array = rows[r]
		for c in row.size():
			var b: Control = row[c]
			b.focus_neighbor_left = b.get_path_to(row[maxi(c - 1, 0)])
			b.focus_neighbor_right = b.get_path_to(row[mini(c + 1, row.size() - 1)])
			var u: Control = up if r == 0 else rows[r - 1][mini(c, rows[r - 1].size() - 1)]
			var d: Control = down if r == rows.size() - 1 else rows[r + 1][mini(c, rows[r + 1].size() - 1)]
			b.focus_neighbor_top = b.get_path_to(u)
			b.focus_neighbor_bottom = b.get_path_to(d)

## Level-Seite: Optik, Dunkelheit, Würfeln, Auftragszeilen.
func _wire_level_page(job_rows: Array) -> void:
	var rows: Array = level_rows.duplicate()
	rows.append_array(job_rows)
	_wire_rows(rows, page_btns[2], btn_save)

## Objekte-Seite: Artenpalette, Objektauswahl und die Eigenschaften des gewählten Objekts (je eine Reihe „<“, „>“).
func _wire_object_page() -> void:
	if btn_save == null or kind_btns.is_empty() or obj_nav.is_empty():
		return                                                    # beim Aufbau existiert die untere Leiste noch nicht (sie ruft das hier selbst auf)
	var rows: Array = []
	for i in range(0, kind_btns.size(), 5):
		rows.append(kind_btns.slice(i, mini(i + 5, kind_btns.size())))
	rows.append(obj_nav)
	rows.append_array(param_rows)
	_wire_rows(rows, page_btns[1], btn_save)

## Controller: A auf einem Textfeld öffnet die Bildschirmtastatur (Tastatur und Maus tippen direkt ins Feld).
func _open_osk(edit: LineEdit) -> void:
	if osk != null:
		return
	osk = Osk.new()
	osk.text = edit.text
	osk.max_len = edit.max_length if edit.max_length > 0 else 40
	osk.title_text = tr("ED_OSK_NAME") if edit == name_edit else tr("ED_OSK_AUTHOR")
	osk.finished.connect(_osk_done.bind(edit))
	add_child(osk)

func _osk_done(t: String, accepted: bool, edit: LineEdit) -> void:
	if osk != null:
		osk.queue_free()
		osk = null
	if accepted:
		edit.text = t
		edit.text_changed.emit(t)
	edit.grab_focus.call_deferred()

func _line_edit(pos: Vector2, sz: Vector2, max_len: int) -> LineEdit:
	var e := LineEdit.new()
	e.custom_minimum_size = sz
	e.position = pos
	e.size = sz
	e.max_length = max_len
	e.add_theme_font_size_override("font_size", 8)
	e.focus_mode = Control.FOCUS_ALL
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("#10142b")
	sb.border_color = Color("#3a4580")
	sb.set_border_width_all(1)
	sb.content_margin_left = 4.0
	sb.content_margin_right = 4.0
	sb.content_margin_top = 1.0
	sb.content_margin_bottom = 1.0
	var sbf := sb.duplicate() as StyleBoxFlat
	sbf.border_color = Color("#ffe14a")
	e.add_theme_stylebox_override("normal", sb)
	e.add_theme_stylebox_override("focus", sbf)
	bottom.add_child(e)
	return e

func _view_exited() -> void:
	mouse_mode = false
	overlay.queue_redraw()

func _author_changed(t: String) -> void:
	model.author = t
	model.dirty = true
	_update_title()

func _toggle_grid() -> void:
	grid_on = not grid_on
	_update_grid_btn()
	overlay.queue_redraw()

func _sync_fields() -> void:
	var lang := TranslationServer.get_locale().substr(0, 2)
	name_edit.text = String(model.names.get(lang, model.names.get("de", "")))
	author_edit.text = model.author
	look_label.text = tr("ED_LOOK") % model.sector
	dark_label.text = tr("ED_DARK") % int(round(model.dark * 100.0))
	_update_title()

func _update_title() -> void:
	var head := tr("ED_TITLE_ORIG") % orig_id.to_upper().replace("_", "-") if orig_id != "" else tr("ED_TITLE")
	title.text = "%s%s" % [head, " *" if model.dirty else ""]
	_update_undo_btns()

# ---------------------------------------------------------------------------------------------------------------- Auswahl und Eigenschaften

## Zeichenmodus des Stifts: 0 Linie, 1 Rechteck, 2 Füllen (Umschalt = Rechteck, Doppelklick = Füllen gelten nur für einen Strich).
func _select_tool(i: int) -> void:
	tool = posmod(i, 3)
	mode_btn.icon_id = ["mode_line", "mode_rect", "mode_fill"][tool]
	mode_btn.queue_redraw()
	mode_label.text = tr(["ED_MODE_LINE", "ED_MODE_RECT", "ED_MODE_FILL"][tool])
	_update_hint()

func _select_pal(i: int) -> void:
	pal = posmod(i, LevelEdit.PALETTE.size())
	for k in pal_btns.size():
		pal_btns[k].selected = k == pal
	sel_label.text = _tile_name(pal)
	overlay.queue_redraw()

func _select_kind(i: int) -> void:
	kind_idx = posmod(i, LevelEdit.KINDS.size())
	_veh_cancel()
	for k in kind_btns.size():
		kind_btns[k].selected = k == kind_idx
	var kn: String = LevelEdit.KINDS[kind_idx]
	kind_label.text = "%s – %s" % [tr("ED_K_" + kn), tr("ED_KH_" + kn)]
	if hint != null:
		_update_hint()

func _kind_step(step: int) -> void:
	_select_kind(kind_idx + step)

## Auswahl weiterschalten: Kartenseite = Feld, Objektseite = Art (die Zeichenfläche wählt Objekte selbst per Klick).
func _cycle_pal(step: int) -> void:
	if page == 1:
		_kind_step(step)
	elif page == 0:
		_select_pal(pal + step)

func _change_look(step: int) -> void:
	if orig_id != "":
		return
	model.sector = wrapi(model.sector - 1 + signi(step), 0, 9) + 1
	_after_property()

func _change_dark(step: int) -> void:
	var steps := [0.0, 0.6, 0.78, 0.9]
	var i := 0
	for k in steps.size():
		if absf(float(steps[k]) - model.dark) < absf(float(steps[i]) - model.dark):
			i = k
	model.dark = float(steps[wrapi(i + signi(step), 0, steps.size())])
	_after_property()

func _after_property() -> void:
	model.dirty = true
	_sync_fields()
	_changed()

func _renumber() -> void:
	if model.renumber_pads():
		_say(tr("ED_RENUMBERED"))
	else:
		_say(tr("ED_RENUMBER_NONE"))
	_changed()

func _reroll() -> void:
	model.reroll_jobs()
	_say(tr("ED_REROLLED"))
	_changed()

func _name_changed(t: String) -> void:
	var s := CommunityLevel.clean_text(t, CommunityLevel.MAX_TEXT)
	if orig_id != "":
		var lang := TranslationServer.get_locale().substr(0, 2)       # Originale haben zwei verschiedene Namen: nur den der gezeigten Sprache ändern
		model.names[lang if model.names.has(lang) else "de"] = s if s != "" else String(model.names.get("de", ""))
	else:
		model.names = {"de": s, "en": s} if s != "" else {"de": "Mein Level", "en": "My level"}
	model.dirty = true
	_update_title()
	_request_validation(0.45)

func _say(t: String) -> void:
	status.text = t
	status.add_theme_color_override("font_color", Color("#ffe14a"))

func _update_hint() -> void:
	if hint == null:
		return
	var fo: Control = get_viewport().gui_get_focus_owner() if is_inside_tree() else null
	if fo != null and fo.has_meta("step"):
		hint.text = tr("ED_HINT_VALUE_PAD") if gamepad_hint else tr("ED_HINT_VALUE_KEYS")
		return
	if page == 1:
		if not veh_pts.is_empty():
			hint.text = tr("ED_VEH_ACTIVE")
		else:
			hint.text = tr("ED_HINT_OBJ_PAD") if gamepad_hint else tr("ED_HINT_OBJ_KEYS")
	elif page == 2:
		hint.text = tr("ED_HINT_LVL_PAD") if gamepad_hint else tr("ED_HINT_LVL")
	else:
		hint.text = tr("ED_HINT_PAD") if gamepad_hint else tr("ED_HINT_KEYS")

# ---------------------------------------------------------------------------------------------------------------- Seiten, Objekte, Aufträge

## `focus`: Controller und F-Tasten – auf der Level-Seite gibt es nichts zu zeichnen, der Fokus geht gleich in ihre Knöpfe.
func _set_page(i: int, focus := false) -> void:
	if active:
		return
	_veh_cancel()
	page = clampi(i, 0, 2)
	for k in pages.size():
		pages[k].visible = k == page
		page_btns[k].modulate = Color(1.3, 1.25, 0.8) if k == page else Color.WHITE
	if page == 1:
		if not model.valid_ref(obj_ref):
			var objs: Array = model.objects()
			obj_ref = objs[0] if not objs.is_empty() else {}
		_rebuild_params()
	elif page == 2:
		_rebuild_jobs(true)
	_update_hint()
	if mode_badge != null:
		_update_badge(true)
	overlay.queue_redraw()
	if page == 2 and focus and page_first[2] != null and is_inside_tree():
		(page_first[2] as Button).grab_focus()
	elif focus and page != 2 and get_viewport().gui_get_focus_owner() != null and not _bottom_has_focus():
		get_viewport().gui_release_focus()                 # Seitenwechsel im Bedienfeld: zurück zum Zeichnen

func _bottom_has_focus() -> bool:
	var f := get_viewport().gui_get_focus_owner()
	return f != null and bottom.is_ancestor_of(f)

## Objekt der gewählten Art am Zeiger setzen (Taste N, Tests); mit der Maus genügt ein Klick auf eine freie Stelle.
func _obj_add() -> void:
	var kn: String = LevelEdit.KINDS[kind_idx]
	if kn == "vehicle":
		_veh_click(cursor)
		return
	var ref: Dictionary = model.add_object(kn, cursor.x, cursor.y)
	if ref.is_empty():
		_say(tr("ED_O_LIMIT"))
		return
	_select_obj(ref)
	_changed()

func _obj_remove_at(ref: Dictionary) -> void:
	if not model.valid_ref(ref):
		return
	model.remove_object(ref)
	if model.same_ref(ref, obj_ref) or not model.valid_ref(obj_ref):
		var objs: Array = model.objects()
		_select_obj(objs[mini(maxi(int(ref.get("i", 0)) - 1, 0), objs.size() - 1)] if not objs.is_empty() and ref.get("t") != "door" else ({} if objs.is_empty() else objs[0]))
	_changed()

func _obj_remove() -> void:
	_obj_remove_at(obj_ref)

func _obj_step(step: int) -> void:
	var objs: Array = model.objects()
	if objs.is_empty():
		_select_obj({})
		return
	var cur := -1
	for i in objs.size():
		if model.same_ref(objs[i], obj_ref):
			cur = i
	_select_obj(objs[wrapi(cur + step, 0, objs.size())])

func _select_obj(ref: Dictionary) -> void:
	obj_ref = ref
	_rebuild_params()
	overlay.queue_redraw()

func _param_text(key: String) -> String:
	var v: float = model.get_param(obj_ref, key)
	var spec: Array = model.param_spec(obj_ref, key)
	if key in ["shape", "spikes", "cycle", "glass"]:
		return tr("ED_ON") if v >= 0.5 else tr("ED_OFF")
	if key == "pole":
		return tr("ED_POLE_1") if v >= 0.5 else tr("ED_POLE_0")
	if key == "period" and obj_ref.get("t") == "zone" and v <= 0.0:
		return tr("ED_STEADY")
	if key == "sweep" and v <= 0.0:
		return tr("ED_OFF")
	if key == "orient":
		return tr("ED_ORIENT_%d" % clampi(int(round(v)), 0, 2))
	if not spec.is_empty() and float(spec[3]) < 1.0:
		return "%.2f" % v if float(spec[3]) < 0.1 else "%.1f" % v
	return "%d" % int(round(v))

func _rebuild_params() -> void:
	for c in param_box.get_children():
		param_box.remove_child(c)
		c.queue_free()
	param_vals.clear()
	if not model.valid_ref(obj_ref):
		obj_label.text = tr("ED_O_NONE")
		param_rows = []
		_wire_object_page()
		return
	var objs: Array = model.objects()
	var idx := 0
	for i in objs.size():
		if model.same_ref(objs[i], obj_ref):
			idx = i + 1
	var kind: String = model.obj_kind(obj_ref)
	obj_label.text = tr("ED_O_SEL") % [idx, objs.size(), tr("ED_K_" + kind) + (" " + String(obj_ref.k) if obj_ref.t == "door" else "")]
	var row := 0
	param_rows = []
	for p in model.obj_params(obj_ref):
		var y := row * 15.0
		var l := _label("", Vector2(0, y), Vector2(62, 14), param_box)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		_fit_text(l, tr(String(p[4])))
		var key: String = p[0]
		var st := _stepper(param_box, y, [64.0, 16.0, 82.0, 44.0, 128.0, 16.0], 14.0, func(d: int): _param_step(key, d), func(): _param_accept(key), "p:%s" % key)
		var val: Button = st[1]
		_fit_button(val, _param_text(key))
		param_vals[key] = val
		param_rows.append([val])
		row += 1
	_wire_object_page()
	_focus_regrab()

func _param_step(key: String, direction: int) -> void:
	if not model.valid_ref(obj_ref):
		return
	model.nudge_param(obj_ref, key, direction)
	_refresh_param_vals()
	_changed()

## A/Enter auf einem Wert: einen Schritt weiter, am Ende wieder von vorn (Schalter wechseln so hin und her).
func _param_accept(key: String) -> void:
	if not model.valid_ref(obj_ref):
		return
	var before: float = model.get_param(obj_ref, key)
	model.nudge_param(obj_ref, key, 1)
	if is_equal_approx(before, model.get_param(obj_ref, key)):
		var spec: Array = model.param_spec(obj_ref, key)
		if not spec.is_empty():
			model.set_param(obj_ref, key, float(spec[1]))
	_refresh_param_vals()
	_changed()

func _refresh_param_vals() -> void:
	for k in param_vals:
		_fit_button(param_vals[k], _param_text(k))

## Nach dem Neuaufbau einer Liste (Parameter, Aufträge) bekommt der zuletzt bediente Knopf den Fokus zurück, damit Controller und Tastatur nicht aus den Bedienfeldern fallen.
func _focus_regrab_key(key: String) -> void:
	_regrab = key
	_focus_regrab()

func _focus_regrab() -> void:
	if _regrab == "" or not is_inside_tree():
		return
	var key := _regrab
	_regrab = ""
	for root in [param_box, job_box]:
		for c in root.find_children("*", "Button", true, false):
			if String(c.get_meta("key", "")) == key and not (c as Button).disabled:
				c.grab_focus.call_deferred()
				return

func _job_mode() -> void:
	if model.jobs.is_empty():
		model.jobs_make_explicit(last_jobs)
	else:
		model.jobs_make_auto()
	_changed()
	_rebuild_jobs(true)

func _job_cycle(i: int, key: String) -> void:
	model.job_cycle(i, key, 1)
	_job_changed("j:%d:%s" % [i, key])

func _job_fragile(i: int) -> void:
	model.job_toggle_fragile(i)
	_job_changed("j:%d:f" % i)

func _job_insert(i: int) -> void:
	if not model.job_insert(i):
		_say(tr("ED_J_LIMIT"))
		return
	_job_changed("j:%d:i" % i)

func _job_remove(i: int) -> void:
	model.job_remove(i)
	_job_changed("j:%d:d" % maxi(i - 1, 0))

func _job_changed(key: String) -> void:
	_regrab = key
	_changed()
	_rebuild_jobs(true)

func _rebuild_jobs(force := false) -> void:
	var own_now: bool = not model.jobs.is_empty()
	var sig := JSON.stringify([own_now, model.jobs if own_now else last_jobs])
	if not force and sig == _jobs_sig:
		_focus_regrab()
		return
	_jobs_sig = sig
	for c in job_box.get_children():
		job_box.remove_child(c)
		c.queue_free()
	var own: bool = not model.jobs.is_empty()
	job_mode_btn.text = tr("ED_J_AUTO") if own else tr("ED_J_CUSTOM")
	var list: Array = model.jobs if own else last_jobs
	var job_rows: Array = []
	# Kopfzeile: was die Spalten bedeuten (im Automatikmodus: woher die Liste kommt)
	if own:
		for hd in [["ED_J_H_FROM", 11.0, 24.0], ["ED_J_H_TO", 47.0, 32.0], ["ED_J_H_FRAGILE", 80.0, 64.0]]:
			var hl := _label("", Vector2(hd[1], 0), Vector2(hd[2], 11), job_box)
			hl.size.y = 11.0
			hl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if hd[0] == "ED_J_H_FRAGILE" else HORIZONTAL_ALIGNMENT_CENTER
			hl.add_theme_color_override("font_color", COL_HINT)
			_fit_text(hl, tr(hd[0]), 6)
	else:
		var al := _label("", Vector2(0, 0), Vector2(144, 11), job_box)
		al.size.y = 11.0
		al.add_theme_color_override("font_color", COL_HINT)
		_fit_text(al, tr("ED_J_AUTO_HEAD"), 6)
	var pitch := clampf((283.0 - 40.0 - job_box.position.y - 12.0) / float(maxi(list.size(), 1)), 12.0, 15.0)     # bis zu 12 Aufträge passen über die Statuszeile
	var bh := minf(14.0, pitch - 0.5)
	for i in list.size():
		var j: Dictionary = list[i]
		var y := 12.0 + i * pitch
		var n := _label(str(i + 1), Vector2(0, y), Vector2(10, 14), job_box)
		n.add_theme_font_size_override("font_size", 7)
		var to_text: String = tr("ED_EXIT_SHORT") if String(j.to) == "exit" else String(j.to)
		var fragile: bool = j.get("fragile", false) == true
		if not own:
			# Automatische Aufträge: nur zur Ansicht, als gut lesbarer Text statt ausgegrauter Knöpfe
			var line := _label("", Vector2(11, y), Vector2(133, 14), job_box)
			line.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
			line.add_theme_color_override("font_color", Color("#dfe4ff"))
			_fit_text(line, tr("ED_J_LINE") % [String(j.from), to_text] + (" · " + tr("ED_J_FRAGILE_WORD") if fragile else ""), 7)
			continue
		var bf := _button(String(j.from), _job_cycle.bind(i, "from"), Vector2(11, y), Vector2(24, bh), job_box, 7)
		var arrow := _label("→", Vector2(36, y), Vector2(10, 14), job_box)
		arrow.add_theme_font_size_override("font_size", 7)
		var bt := _button(to_text, _job_cycle.bind(i, "to"), Vector2(47, y), Vector2(32, bh), job_box, 7)
		_fit_button(bt, to_text)
		var bz := _button("Z" if fragile else "–", _job_fragile.bind(i), Vector2(80, y), Vector2(18, bh), job_box, 7)
		var bi := _button("+", _job_insert.bind(i), Vector2(100, y), Vector2(18, bh), job_box, 7)
		var bd := _button("×", _job_remove.bind(i), Vector2(120, y), Vector2(18, bh), job_box, 7)
		bf.tooltip_text = tr("ED_J_TIP_FROM")
		bt.tooltip_text = tr("ED_J_TIP_TO")
		bz.tooltip_text = tr("ED_J_TIP_FRAGILE")
		bi.tooltip_text = tr("ED_J_TIP_INSERT")
		bd.tooltip_text = tr("ED_J_TIP_DELETE")
		bf.set_meta("key", "j:%d:from" % i)
		bt.set_meta("key", "j:%d:to" % i)
		bz.set_meta("key", "j:%d:f" % i)
		bi.set_meta("key", "j:%d:i" % i)
		bd.set_meta("key", "j:%d:d" % i)
		job_rows.append([bf, bt, bz, bi, bd])
	_wire_level_page(job_rows)
	_focus_regrab()

# ---------------------------------------------------------------------------------------------------------------- Zeichnen

func _tile_char(erase: bool) -> String:
	return "." if erase else String(LevelEdit.PALETTE[pal][0])

func _begin(erase: bool, at: Vector2i, force_fill := false) -> void:
	if active:
		return
	if page == 2:
		return
	if page == 1:
		_begin_object(erase, at)
		return
	stroke_mode = TOOL_FILL if force_fill else (TOOL_RECT if tool == TOOL_PEN and Input.is_key_pressed(KEY_SHIFT) else tool)
	active = true
	stroke_erase = erase
	var ch := _tile_char(erase)
	if stroke_mode == TOOL_PEN:
		model.begin_stroke()
		model.line(at, at, ch)
		stroke_last = at
	elif stroke_mode == TOOL_RECT:
		rect_start = at
		rect_cur = at
	else:
		model.begin_stroke()
		model.flood(at.x, at.y, ch)
		model.end_stroke()
		active = false
		_changed()
	_changed_soft()

## Objektseite, ein Stift für alles: ein Klick auf ein vorhandenes Objekt wählt es (Ziehen verschiebt es, bei Fahrzeugpfaden auch einzelne Pfadpunkte), ein Klick auf eine
## freie Stelle setzt ein Objekt der gewählten Art (Ziehen bestimmt Größe bzw. Richtung); Fahrzeuge werden als Pfad gesetzt (Eingang, Zwischenpunkte, Ausgang).
## Löschen entfernt das Objekt unter dem Zeiger bzw. bricht einen Fahrzeugpfad ab.
func _begin_object(erase: bool, at: Vector2i) -> void:
	var center := Vector2(at) + Vector2(0.5, 0.5)
	if erase:
		if not veh_pts.is_empty():
			_veh_cancel()
			return
		if model.valid_ref(obj_ref):
			var pi: int = model.path_point_near(obj_ref, center, 0.8)
			if pi >= 0 and model.path_points(obj_ref).size() > 2:
				model.remove_path_point(obj_ref, pi)
				_changed()
				return
		_obj_remove_at(model.pick_object(at.x, at.y))
		return
	if not veh_pts.is_empty():
		_veh_click(at)
		return
	if model.valid_ref(obj_ref) and not model.path_points(obj_ref).is_empty():
		var pj: int = model.path_point_near(obj_ref, center, 0.8)
		if pj >= 0:
			active = true
			drag_mode = "point"
			drag_point = pj
			model.begin_stroke()
			return
	var ref: Dictionary = model.pick_object(at.x, at.y)
	if not ref.is_empty():
		if not model.same_ref(ref, obj_ref):
			_select_obj(ref)
		if ref.t != "door":                                           # Tore sind Kartenfelder und lassen sich nur auf der Karte verschieben
			active = true
			drag_mode = "move"
			drag_last = at
			model.begin_stroke()
		return
	var kn: String = LevelEdit.KINDS[kind_idx]
	if kn == "vehicle":
		_veh_click(at)
		return
	model.begin_stroke()
	var nref: Dictionary = model.add_object(kn, at.x, at.y)
	if nref.is_empty():
		model.end_stroke()
		_say(tr("ED_O_LIMIT"))
		return
	_select_obj(nref)
	active = true
	drag_mode = "size"
	drag_origin = at
	_changed_soft()

func _move_stroke(at: Vector2i) -> void:
	if not active:
		return
	if page == 1:
		var moved := false
		match drag_mode:
			"move":
				var delta := at - drag_last
				if delta != Vector2i.ZERO and model.move_object(obj_ref, delta.x, delta.y):
					drag_last = at
					moved = true
			"size":
				model.size_object(obj_ref, drag_origin, at)
				moved = true
			"point":
				model.set_path_point(obj_ref, drag_point, Vector2(at) + Vector2(0.5, 0.5))
				moved = true
		if moved:
			_refresh_param_vals()
			_changed_soft()
		return
	if stroke_mode == TOOL_PEN:
		if at != stroke_last:
			model.line(stroke_last, at, _tile_char(stroke_erase))
			stroke_last = at
			_changed_soft()
	elif stroke_mode == TOOL_RECT:
		rect_cur = at
	overlay.queue_redraw()

func _end_stroke() -> void:
	if not active:
		return
	active = false
	if page == 1:
		model.end_stroke()
		drag_mode = ""
		_rebuild_params()
		_changed()
		return
	if stroke_mode == TOOL_PEN:
		model.end_stroke()
	elif stroke_mode == TOOL_RECT:
		model.begin_stroke()
		model.rect(rect_start, rect_cur, _tile_char(stroke_erase))
		model.end_stroke()
		rect_start = Vector2i(-1, -1)
	_changed()

# ---------------------------------------------------------------------------------------------------------------- Fremdfahrzeug: Pfad setzen

## Wand, Rand oder Fels: dort tauchen Fahrzeuge auf und verschwinden (Wandöffnung); alles andere ist freier Raum.
func _veh_solid(at: Vector2i) -> bool:
	return at.x <= 0 or at.y <= 0 or at.x >= model.w - 1 or at.y >= model.h - 1 or model.cell(at.x, at.y) == "#"

## Rolle des nächsten Klicks: 0 Eingang, 1 Zwischenpunkt, 2 Ausgang (Klick auf Wand/Rand, sobald ein Eingang gesetzt ist).
func _veh_role_at(at: Vector2i) -> int:
	if veh_pts.is_empty():
		return 0
	return 2 if _veh_solid(at) else 1

func _veh_click(at: Vector2i) -> void:
	var p := Vector2(at) + Vector2(0.5, 0.5)
	if veh_pts.is_empty():
		veh_pts = [p]
		_update_hint()
		overlay.queue_redraw()
		return
	if p == veh_pts[veh_pts.size() - 1]:
		return
	veh_pts.append(p)
	if _veh_solid(at):
		_veh_finish()                                             # Wand oder Rand erreicht: das ist der Ausgang
	else:
		overlay.queue_redraw()

func _veh_finish() -> void:
	if veh_pts.size() >= 2:
		model.begin_stroke()
		var ref: Dictionary = model.add_vehicle_path(veh_pts)
		model.end_stroke()
		if ref.is_empty():
			_say(tr("ED_O_LIMIT"))
		else:
			_select_obj(ref)
			_changed()
	_veh_cancel()

func _veh_cancel() -> void:
	if veh_pts.is_empty():
		return
	veh_pts = []
	_update_hint()
	overlay.queue_redraw()

## Während eines Strichs: keine Neuberechnung der Vorschau (die Felsschicht neu zu zeichnen kostet je nach Fels einige Millisekunden und ruckelte). Die Zeichenfläche
## zeigt die gemalten Felder selbst; die Vorschau folgt am Ende des Strichs. Beim Ziehen von Objekten (Felsschicht bleibt) aktualisiert sie sich laufend.
func _changed_soft() -> void:
	if page == 1:
		preview_t = 0.06
	_request_validation(0.45)
	_update_title()
	overlay.queue_redraw()

func _changed() -> void:
	_refresh_preview()
	_request_validation(0.35)
	_update_title()
	overlay.queue_redraw()

func _eyedrop(at: Vector2i) -> void:
	var ch: String = model.cell(at.x, at.y)
	for i in LevelEdit.PALETTE.size():
		if LevelEdit.PALETTE[i][0] == ch:
			_select_pal(i)
			return

func _tile_at_mouse() -> Vector2i:
	var p := view.get_local_mouse_position() / _cellsize()
	return Vector2i(clampi(int(floorf(p.x)), 0, model.w - 1), clampi(int(floorf(p.y)), 0, model.h - 1))

func _view_input(ev: InputEvent) -> void:
	if preview_mode:
		if ev is InputEventMouseButton and ev.pressed:
			_set_preview(false)
			accept_event()
		return
	if ev is InputEventMouseMotion:
		mouse_mode = true
		gamepad_hint = false
		cursor = _tile_at_mouse()
		if active:
			_move_stroke(cursor)
		overlay.queue_redraw()
	elif ev is InputEventMouseButton:
		if get_viewport().gui_get_focus_owner() != null and ev.pressed:
			get_viewport().gui_release_focus()
		mouse_mode = true
		cursor = _tile_at_mouse()
		if ev.pressed and ev.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
			_begin(ev.button_index == MOUSE_BUTTON_RIGHT, cursor, bool(ev.double_click) and page == 0)
		elif not ev.pressed and ev.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
			_end_stroke()
		elif ev.pressed and ev.button_index == MOUSE_BUTTON_MIDDLE and page == 0:
			_eyedrop(cursor)
		elif ev.pressed and ev.button_index == MOUSE_BUTTON_WHEEL_UP:
			_cycle_pal(-1)
		elif ev.pressed and ev.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_cycle_pal(1)
		accept_event()

func _draw_overlay() -> void:
	var cs := _cellsize()
	if grid_on and not preview_mode:
		var gc := Color(1, 1, 1, 0.07)
		for x in range(1, model.w):
			overlay.draw_line(Vector2(x * cs, 0), Vector2(x * cs, model.h * cs), gc, 1.0)
		for y in range(1, model.h):
			overlay.draw_line(Vector2(0, y * cs), Vector2(model.w * cs, y * cs), gc, 1.0)
	_draw_blink(cs)
	if preview_mode:
		return
	if _shown_rows != model.rows and _shown_rows.size() == model.rows.size():
		for y in model.h:                                              # noch nicht in der Vorschau: gemalte Felder direkt zeigen
			var a: String = _shown_rows[y]
			var b: String = model.rows[y]
			if a == b:
				continue
			for x in model.w:
				if a[x] != b[x]:
					var ch := b[x]
					var rc := Rect2(Vector2(x, y) * cs, Vector2(cs, cs))
					if ch == ".":
						overlay.draw_rect(rc, Color(0.03, 0.04, 0.1, 0.95))
					else:
						var cc: Color = COLORS.get(ch, Color("#ffd24a") if LevelEdit.PAD_CHARS.contains(ch) else Color("#b07bff"))
						overlay.draw_rect(rc, Color(cc.r, cc.g, cc.b, 0.85))
	if page == 1:
		for ref in model.objects():
			var bnd: Rect2 = model.obj_bounds(ref)
			if bnd.size == Vector2.ZERO:
				continue
			var sel: bool = model.same_ref(ref, obj_ref)
			if not model.path_points(ref).is_empty():
				continue                                                  # Pfadfahrzeuge zeigen ihre Linie statt eines Rahmens
			var rr := Rect2(bnd.position * cs, bnd.size * cs)
			overlay.draw_rect(rr, Color(1, 0.9, 0.3, 0.16) if sel else Color(1, 1, 1, 0.05))
			overlay.draw_rect(rr, Color("#ffe14a") if sel else Color(1, 1, 1, 0.35), false, 2.0 if sel else 1.0)
			if ref.t != "door":
				var d: Dictionary = model.movers[ref.i] if ref.t == "mover" else model.zones[ref.i]
				if d.get("kind") == "vehicle" and d.has("path"):
					for k in range(d.path.size() - 1):
						overlay.draw_line(Vector2(d.path[k][0], d.path[k][1]) * cs, Vector2(d.path[k + 1][0], d.path[k + 1][1]) * cs, Color(0.5, 0.9, 1, 0.7), 1.0)
	if active and page == 0 and stroke_mode == TOOL_RECT and rect_start.x >= 0:
		var a := Vector2i(mini(rect_start.x, rect_cur.x), mini(rect_start.y, rect_cur.y))
		var b := Vector2i(maxi(rect_start.x, rect_cur.x), maxi(rect_start.y, rect_cur.y))
		overlay.draw_rect(Rect2(Vector2(a) * cs, Vector2(b - a + Vector2i.ONE) * cs), Color(1, 0.9, 0.3, 0.25))
		overlay.draw_rect(Rect2(Vector2(a) * cs, Vector2(b - a + Vector2i.ONE) * cs), Color("#ffe14a"), false, 1.0)
	_draw_vehicle_paths(cs)
	var show_cursor: bool = page != 2 and (get_viewport().gui_get_focus_owner() == null or mouse_mode)      # Level-Seite: kein Zeichnen, kein Zeiger
	if show_cursor:
		var ch := String(LevelEdit.PALETTE[pal][0])
		var col: Color = COLORS.get(ch, Color("#ffd24a") if LevelEdit.PAD_CHARS.contains(ch) else Color.WHITE)
		var r := Rect2(Vector2(cursor) * cs, Vector2(cs, cs))
		if page == 0:
			overlay.draw_rect(r, Color(col.r, col.g, col.b, 0.35))
		overlay.draw_rect(r.grow(1.5), Color(0.02, 0.03, 0.1, 0.9), false, 1.0)       # dunkler Außenrand: der Zeiger bleibt auf hellem Fels und Pads sichtbar
		overlay.draw_rect(r.grow(0.5), Color("#ffe14a"), false, 2.0)
	_update_cursor_info(show_cursor)

## Titelzeile links: Koordinaten und Inhalt des Felds unter dem Zeiger (Objekte-Seite: das Objekt darunter).
func _update_cursor_info(show: bool) -> void:
	if cursor_info == null:
		return
	if not show or page == 2:
		cursor_info.text = ""
		return
	var what := ""
	if page == 1:
		var ref: Dictionary = model.pick_object(cursor.x, cursor.y)
		if not ref.is_empty():
			what = tr("ED_K_" + model.obj_kind(ref)) + (" " + String(ref.k) if ref.t == "door" else "")
	if what == "":
		what = _cell_name(model.cell(cursor.x, cursor.y))
	cursor_info.text = tr("ED_CURSOR") % [cursor.x, cursor.y, what]

func _cell_name(ch: String) -> String:
	for i in LevelEdit.PALETTE.size():
		if LevelEdit.PALETTE[i][0] == ch:
			return _tile_name(i)
	if ch == "E":
		return tr("ED_CELL_EXIT")
	return ""

## Fahrzeugpfade: der Pfad im Bau mit erkannten Rollen (Eingang, Zwischenpunkte, Ausgang) und der Pfad des gewählten Fahrzeugs mit seinen Punkten.
func _pt(p: Variant) -> Vector2:
	return p if p is Vector2 else Vector2(float(p[0]), float(p[1]))

func _draw_path(pts: Array, cs: float, col: Color, final: bool, cursor_p := Vector2.INF) -> void:
	var f: Font = Fonts.ui
	for i in range(pts.size() - 1):
		overlay.draw_line(_pt(pts[i]) * cs, _pt(pts[i + 1]) * cs, col, 2.0)
	if cursor_p != Vector2.INF and not pts.is_empty():
		overlay.draw_dashed_line(_pt(pts[pts.size() - 1]) * cs, cursor_p * cs, Color(col.r, col.g, col.b, 0.6), 1.0, 3.0)
	for i in pts.size():
		var p := _pt(pts[i]) * cs
		var last := final and i == pts.size() - 1
		var role := tr("ED_ROLE_ENTRY") if i == 0 else (tr("ED_ROLE_EXIT") if last else str(i))
		var dot := Color("#5dff9a") if i == 0 else (Color("#ff6a4a") if last else Color("#ffe14a"))
		overlay.draw_circle(p, 3.5, dot)
		overlay.draw_circle(p, 3.5, Color(0, 0, 0, 0.6), false, 1.0)
		var pos := p + Vector2(5, -4)
		overlay.draw_string_outline(f, pos, role, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, 2, Color(0.02, 0.03, 0.1, 0.95))
		overlay.draw_string(f, pos, role, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, dot)

func _draw_vehicle_paths(cs: float) -> void:
	if page != 1:
		return
	if not veh_pts.is_empty():
		var cp := Vector2(cursor) + Vector2(0.5, 0.5)
		_draw_path(veh_pts, cs, Color("#5dd6ff"), false, cp)
		var role := _veh_role_at(cursor)
		var rname := tr(["ED_ROLE_ENTRY", "ED_ROLE_WAY", "ED_ROLE_EXIT"][role])
		var fnt: Font = Fonts.ui
		overlay.draw_string_outline(fnt, cp * cs + Vector2(7, 10), rname, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, 2, Color(0.02, 0.03, 0.1, 0.95))
		overlay.draw_string(fnt, cp * cs + Vector2(7, 10), rname, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color("#ff6a4a") if role == 2 else Color.WHITE)
	elif model.valid_ref(obj_ref) and not model.path_points(obj_ref).is_empty():
		_draw_path(model.path_points(obj_ref), cs, Color(0.5, 0.9, 1, 0.8), true)

# ---------------------------------------------------------------------------------------------------------------- Vorschau, Prüfung, Speichern

func _refresh_preview() -> void:
	preview_t = -1.0
	var sig := "%d:%d" % [model.rows.hash(), model.sector]
	var rebuild := sig != _tiles_sig
	_tiles_sig = sig
	if rebuild:
		_shown_rows = model.rows.duplicate()
	var d: Dictionary = model.to_level_dict()
	var jobs: Array = model.jobs if not model.jobs.is_empty() else last_jobs
	var valid := true
	for j in jobs:
		valid = valid and model.pad_digits().has(String(j.get("from", ""))) and (String(j.get("to", "")) == "exit" or String(j.get("to", "")) == "H" or model.pad_digits().has(String(j.get("to", ""))))
	d["jobs"] = jobs if valid else []
	d["id"] = "editor"
	canvas.show_level(LevelData.from_dict(d), rebuild)

## Neue Prüfung anfordern: sie startet nach `delay` Sekunden Ruhe (während des Malens nicht ständig).
func _request_validation(delay: float) -> void:
	_model_rev += 1
	_blink = 0.0
	validate_t = delay

## Prüfung sofort und gleichzeitig (beim Öffnen und vor dem Speichern, wo das Ergebnis gebraucht wird).
func _validate_now() -> void:
	_join_validation()
	validate_t = -1.0
	_apply_validation(model.validate())

func _start_async() -> void:
	validate_t = -1.0
	if _thread != null:
		return                                   # läuft schon; bei Rückkehr wird wegen der neueren Änderung neu gestartet
	_thread_rev = _model_rev
	_thread = Thread.new()
	_thread.start(LevelEdit.validate_wrapper.bind(model.to_wrapper()))

func _join_validation() -> void:
	if _thread != null:
		_thread.wait_to_finish()
		_thread = null

func _exit_tree() -> void:
	_join_validation()

func _poll_validation() -> void:
	if _thread == null or _thread.is_alive():
		return
	var r: Dictionary = _thread.wait_to_finish()
	_thread = null
	if _thread_rev == _model_rev:
		model.jobs_reset = bool(r.get("jobs_reset", false))
		if model.jobs_reset:
			model.jobs = []
		_apply_validation(r)
	else:
		_start_async()

func _apply_validation(r: Dictionary) -> void:
	res = r
	if res.ok:
		last_jobs = res.level.jobs
		var pads: int = model.pad_runs().size()
		var txt := tr("ED_VALID") % [pads, res.level.jobs.size()]
		if model.jobs_reset:
			txt += " · " + tr("ED_JOBS_RESET")
		if _save_blocked():
			txt += "\n" + _need_solve_text()
		elif _skip_solve() and not _is_saved_version() and not CommunityStore.is_solved(res.id):
			txt += "\n" + tr("ED_SKIP_ACTIVE")
		else:
			if CommunityStore.is_solved(res.id) and not _is_saved_version():
				txt += " · " + tr("ED_SOLVED")
			for w in res.warnings.slice(0, 1):
				txt += "\n" + CommunityLevel.describe(w, true)
		status.text = txt
		status.add_theme_color_override("font_color", COL_WARN if _save_blocked() else COL_OK)      # gesperrtes Speichern nicht im Grün des Erfolgs
	else:
		var lines: Array = []
		for e in res.errors.slice(0, 2):
			lines.append(CommunityLevel.describe(e))
		if res.errors.size() > 2:
			lines[1] = String(lines[1]) + " " + tr("ED_ERR_MORE") % (res.errors.size() - 2)
		status.text = "\n".join(lines)
		status.add_theme_color_override("font_color", COL_ERR)
	_collect_errors()
	_update_save_btn()
	if model.jobs_reset:
		_refresh_preview()
	if page == 2:
		_rebuild_jobs()

## Fehler der letzten Prüfung mit ihren Fundstellen (für „Fehler zeigen“ und die dauerhafte dünne Markierung auf der Karte).
func _collect_errors() -> void:
	_err_list = []
	_err_idx = -1
	for e in res.get("errors", []):
		var at: Dictionary = e.get("at", {})
		var cells: Array = []
		for c in at.get("cells", []):
			cells.append(Vector2i(int(c[0]), int(c[1])))
		var movers: Array = []
		for i in at.get("movers", []):
			movers.append(int(i))
		_err_list.append({"text": CommunityLevel.describe(e), "cells": cells, "movers": movers})
	if btn_err != null:
		btn_err.visible = not _err_list.is_empty()
		btn_err.text = tr("ED_ERR_SHOW") % _err_list.size()
		status.size.x = 556.0 if btn_err.visible else 630.0
		_wire_err_btn()
	overlay.queue_redraw()

## Nächsten Fehler zeigen (F, Knopf neben der Statuszeile): Text in der Statuszeile, Zeiger auf die Fundstelle, die Stelle wird hervorgehoben.
func _next_error() -> void:
	if _err_list.is_empty():
		_say(tr("ED_ERR_NONE") if res.get("ok", false) else tr("CM_CHECKING"))
		return
	_err_idx = (_err_idx + 1) % _err_list.size()
	var e: Dictionary = _err_list[_err_idx]
	status.text = tr("ED_ERR_N") % [_err_idx + 1, _err_list.size(), e.text]
	status.add_theme_color_override("font_color", COL_ERR)
	_bad_cells = (e.cells as Array).duplicate()
	_bad_movers = (e.movers as Array).duplicate()
	var target := Vector2i(-1, -1)
	if not _bad_cells.is_empty():
		target = _bad_cells[0]
	elif not _bad_movers.is_empty():
		var bnd: Rect2 = model.obj_bounds({"t": "mover", "i": _bad_movers[0]})
		if bnd.size != Vector2.ZERO:
			target = Vector2i(bnd.get_center().floor())
	if target.x >= 0:
		cursor = Vector2i(clampi(target.x, 0, model.w - 1), clampi(target.y, 0, model.h - 1))
		mouse_mode = false
	_blink = _blink_time() if (not _bad_cells.is_empty() or not _bad_movers.is_empty()) else 0.0
	overlay.queue_redraw()

func _blink_time() -> float:
	return 12.0 if Settings.values.reduce_motion else 5.0                # ohne Blinken bleibt die ruhige Markierung länger stehen

## Lässt die Objekte blinken, an denen die Prüfung scheitert (Fundstellen `at` der Fehler: Felder und bewegliche Hindernisse).
func _flag_errors() -> void:
	_bad_cells = []
	_bad_movers = []
	for e in res.get("errors", []):
		var at: Dictionary = e.get("at", {})
		for c in at.get("cells", []):
			var v := Vector2i(int(c[0]), int(c[1]))
			if not _bad_cells.has(v):
				_bad_cells.append(v)
		for i in at.get("movers", []):
			_bad_movers.append(int(i))
	_blink = _blink_time() if (not _bad_cells.is_empty() or not _bad_movers.is_empty()) else 0.0
	overlay.queue_redraw()

func _draw_blink(cs: float) -> void:
	if not res.get("ok", true):                                         # alle Fundstellen der aktuellen Fehler dauerhaft dünn umrandet
		for e in _err_list:
			for v in e.cells:
				overlay.draw_rect(Rect2(Vector2(v) * cs, Vector2(cs, cs)).grow(-0.5), Color(1, 0.35, 0.35, 0.85), false, 1.0)
	if _blink <= 0.0:
		return
	var on: bool = bool(Settings.values.reduce_motion) or fmod(_blink, 0.5) > 0.25   # 2 Hz hart an/aus (auch bei Farbenschwäche gut zu sehen); mit „Bewegung reduzieren“ ruhig
	if not on:
		return
	for v in _bad_cells:
		var rc := Rect2(Vector2(v) * cs, Vector2(cs, cs))
		overlay.draw_rect(rc, Color(1, 0.15, 0.2, 0.55))
		overlay.draw_rect(rc.grow(1.0), Color(1, 1, 1, 0.95), false, 2.0)
	for i in _bad_movers:
		var bnd: Rect2 = model.obj_bounds({"t": "mover", "i": i})
		if bnd.size != Vector2.ZERO:
			var rr := Rect2(bnd.position * cs, bnd.size * cs)
			overlay.draw_rect(rr, Color(1, 0.15, 0.2, 0.45))
			overlay.draw_rect(rr, Color(1, 1, 1, 0.95), false, 2.0)

## Ist diese Fassung schon gespeichert (Community) bzw. gleich der Datei (Original)? Dann braucht sie keine Handlösung.
func _is_saved_version() -> bool:
	return res.id == base_id if orig_id != "" else CommunityStore.exists(res.id)

## Fehlt für die geprüfte Fassung noch die Handlösung? Speichern geht nur, wenn der Ersteller genau dieses Level einmal selbst geflogen ist.
func _save_blocked() -> bool:
	return res.get("ok", false) and not _is_saved_version() and not CommunityStore.is_solved(res.id) and not _skip_solve()

## Hinweis „erst selbst lösen“; im Debug-Modus mit dem Verweis auf den Schalter.
func _need_solve_text() -> String:
	return tr("ED_NEED_SOLVE") + (" " + tr("ED_SKIP_HINT") if Save.debug else "")

## Debug-Override: Im Debug-Modus lässt sich die Handlösung abschalten (für kleine Änderungen, die keinen neuen Testflug brauchen).
func _skip_solve() -> bool:
	return Save.debug and Flow.editor_skip_solve

func _toggle_skip_solve() -> void:
	Flow.editor_skip_solve = not Flow.editor_skip_solve
	_update_skip_btn()
	_request_validation(0.05)

func _update_skip_btn() -> void:
	if skip_btn != null:
		skip_btn.text = tr("ED_SKIP_ON") if Flow.editor_skip_solve else tr("ED_SKIP_OFF")
		skip_btn.modulate = Color(1.35, 1.2, 0.7) if Flow.editor_skip_solve else Color.WHITE

## Speichert eine eigene Fassung (im Original-Modus: die Datei des Originals). Gibt die ID zurück oder "" bei einem Fehler (der Grund steht in der Statuszeile).
func _save(announce: bool) -> String:
	_validate_now()
	if not res.ok:
		_flag_errors()
		return ""
	if _save_blocked():
		_say(_need_solve_text())
		return ""
	if orig_id != "":
		return _save_original(announce)
	var err := CommunityStore.save(res, model.author)
	if err != "":
		_say(CommunityLevel.describe({"code": err, "args": []}))
		return ""
	if session_id != "" and session_id != res.id:
		CommunityStore.delete(session_id)                 # die frühere Fassung dieser Sitzung wird ersetzt
		Save.community_forget(session_id)
	session_id = res.id
	model.dirty = false
	if model.author != "":
		Save.set_community_author(model.author)
	_update_title()
	if announce:
		status.text = tr("ED_SAVED") % String(model.names.get(TranslationServer.get_locale().substr(0, 2), model.names.get("de", "")))
		status.add_theme_color_override("font_color", Color("#5dff9a"))
	return res.id

## Original-Datei schreiben (nur Geändertes; Prüfsumme und Geisterläufe werden nachgeführt).
func _save_original(announce: bool) -> String:
	var out := LevelFiles.save(orig_id, orig_raw, orig_base, res)
	if out.error != "":
		_say(CommunityLevel.describe({"code": out.error, "args": []}))
		return ""
	orig_raw = out.raw
	orig_base = LevelFiles.clean_of(orig_raw)
	base_id = orig_base.id if orig_base.ok else res.id
	model.dirty = false
	_update_title()
	if announce:
		var nm := String(model.names.get(TranslationServer.get_locale().substr(0, 2), model.names.get("de", "")))
		status.text = (tr("ED_ORIG_SAVED") if out.changed else tr("ED_ORIG_UNCHANGED")) % nm
		status.add_theme_color_override("font_color", Color("#5dff9a"))
	return res.id

## Testflug: selbst fliegen, oder (`autopilot`) dem Autopiloten beim Lösen zusehen. Die Fassung liegt dafür nur als Entwurf bereit (gespeichert wird erst nach einer
## eigenen, vollständigen Lösung). Bei Fehlern blinken die betroffenen Objekte.
func _test_flight(autopilot := false) -> void:
	_validate_now()
	if not res.ok:
		_flag_errors()
		_say(tr("ED_NEED_VALID") + " " + status.text.replace("\n", " "))
		return
	var id: String = res.id
	if not CommunityStore.exists(id):
		var err := CommunityStore.save_draft(res, model.author)
		if err != "":
			_say(CommunityLevel.describe({"code": err, "args": []}))
			return
	Flow.return_to_editor = id
	Flow.editor_session = session_id
	Flow.start_community(id, autopilot)

func _request_back() -> void:
	if model.dirty:
		_open_leave_dialog()
		return
	back.call()

# ---------------------------------------------------------------------------------------------------------------- Rückfrage beim Verlassen, Hilfeseite

## Fenster mit Rahmen in der Mitte der 640×360-Fläche; der Rest wird abgedunkelt und nimmt keine Klicks an die Zeichenfläche durch.
func _modal(sz: Vector2) -> Array:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(MenuKit.dim_rect(0.7))
	var box := Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("#10142b")
	sb.border_color = Color("#ffe14a")
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(3)
	box.add_theme_stylebox_override("panel", sb)
	box.position = (Vector2(640, 360) - sz) * 0.5
	box.size = sz
	box.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(box)
	add_child(root)
	return [root, box]

## Ungespeicherte Änderungen: Speichern und zurück, Verwerfen oder weiter bearbeiten (Fokus zuerst auf dem harmlosen „Weiter bearbeiten“).
func _open_leave_dialog() -> void:
	if leave_dlg != null:
		return
	_hold_end()
	var m := _modal(Vector2(300, 96))
	leave_dlg = m[0]
	var box: Control = m[1]
	var head := _label(tr("ED_LEAVE_TITLE"), Vector2(8, 4), Vector2(284, 16), box)
	head.add_theme_color_override("font_color", Color("#ffe14a"))
	head.add_theme_font_size_override("font_size", 9)
	var blocked: bool = not res.get("ok", false) or _save_blocked()
	var body := _label(tr("ED_LEAVE_TEXT") + ("\n" + tr("ED_LEAVE_NOSAVE") if blocked else ""), Vector2(8, 22), Vector2(284, 40), box)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_theme_font_size_override("font_size", 7)
	var b_save := _button(tr("ED_LEAVE_SAVE"), _leave_save, Vector2(8, 70), Vector2(92, 18), box, 7)
	var b_drop := _button(tr("ED_LEAVE_DISCARD"), _leave_discard, Vector2(104, 70), Vector2(92, 18), box, 7)
	var b_stay := _button(tr("ED_LEAVE_STAY"), _leave_close, Vector2(200, 70), Vector2(92, 18), box, 7)
	b_save.disabled = blocked
	var row: Array = [b_save, b_drop, b_stay]
	for i in row.size():
		var c: Control = row[i]
		c.focus_neighbor_left = c.get_path_to(row[maxi(i - 1, 0)])
		c.focus_neighbor_right = c.get_path_to(row[mini(i + 1, row.size() - 1)])
		c.focus_neighbor_top = c.get_path_to(c)
		c.focus_neighbor_bottom = c.get_path_to(c)
	if is_inside_tree():
		b_stay.grab_focus.call_deferred()

func _leave_close() -> void:
	if leave_dlg != null:
		leave_dlg.queue_free()
		leave_dlg = null
	input_ready = false
	if is_inside_tree():
		get_viewport().gui_release_focus()
	_update_badge(true)

func _leave_save() -> void:
	_leave_close()
	if _save(true) != "":
		back.call()

func _leave_discard() -> void:
	_leave_close()
	back.call()

## Hilfeseite: alle Belegungen der aktuellen Seite und die allgemeinen, links Tastatur und Maus, rechts Controller. Jede Taste oder ein Klick schließt sie.
func _open_help() -> void:
	if help != null:
		return
	_hold_end()
	_end_key_stroke()
	var m := _modal(Vector2(620, 336))
	help = m[0]
	var box: Control = m[1]
	var page_key: String = ["MAP", "OBJ", "LVL"][page]
	var head := _label(tr("ED_HELP_TITLE") % tr(["ED_PAGE_MAP", "ED_PAGE_OBJ", "ED_PAGE_LVL"][page]), Vector2(8, 3), Vector2(604, 16), box)
	head.add_theme_color_override("font_color", Color("#ffe14a"))
	head.add_theme_font_size_override("font_size", 10)
	var cols := [["ED_HELP_KEYS", "ED_HELP_%s_KEYS" % page_key, "ED_HELP_ALL_KEYS"], ["ED_HELP_PAD", "ED_HELP_%s_PAD" % page_key, "ED_HELP_ALL_PAD"]]
	for ci in cols.size():
		var x := 10.0 + ci * 304.0
		var y := 22.0
		var ch := _label(tr(cols[ci][0]), Vector2(x, y), Vector2(296, 13), box)
		ch.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		ch.add_theme_color_override("font_color", COL_OK)
		y += 15.0
		for part in [cols[ci][1], cols[ci][2]]:
			for line in tr(part).split("\n"):
				var kv := String(line).split("|")
				if kv.size() < 2:
					continue
				var kl := _label("", Vector2(x, y), Vector2(104, 11), box)
				kl.size.y = 11.0
				kl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
				kl.add_theme_color_override("font_color", Color("#ffe14a"))
				_fit_text(kl, kv[0], 7)
				var vl := _label("", Vector2(x + 108, y), Vector2(188, 11), box)
				vl.size.y = 11.0
				vl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
				_fit_text(vl, kv[1], 7)
				y += 11.0
			y += 5.0
	var foot := _label(tr("ED_HELP_CLOSE"), Vector2(8, 318), Vector2(604, 14), box)
	foot.add_theme_font_size_override("font_size", 7)
	foot.add_theme_color_override("font_color", COL_HINT)
	help.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed:
			_close_help())
	box.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed:
			_close_help())

func _close_help() -> void:
	if help != null:
		help.queue_free()
		help = null
	input_ready = false                   # die Taste, die die Hilfe schließt, malt bzw. löscht nicht (erst nach dem Loslassen wieder)

func _set_preview(on: bool) -> void:
	preview_mode = on
	panel.visible = not on
	bottom.visible = not on
	title.visible = not on
	cursor_info.visible = not on
	_update_badge(true)
	if on:
		get_viewport().gui_release_focus()
		canvas.lvl.exit_open = false
	_layout_view()

# ---------------------------------------------------------------------------------------------------------------- Eingabe (Tastatur, Controller)

func _toggle_menu() -> void:
	if get_viewport().gui_get_focus_owner() != null:
		get_viewport().gui_release_focus()
		overlay.queue_redraw()
	else:
		_enter_menu()

func _enter_menu() -> void:
	if page == 2 and page_first[2] != null:
		(page_first[2] as Button).grab_focus()           # die Level-Seite hat nichts zu zeichnen: ihre Knöpfe zuerst
	elif page == 1 and not kind_btns.is_empty():
		(kind_btns[clampi(kind_idx, 0, kind_btns.size() - 1)] as Button).grab_focus()      # Objekte: Art, Objektauswahl und Eigenschaften
	else:
		btn_save.grab_focus()
	overlay.queue_redraw()

## Tab bzw. Y: auf der Kartenseite den nächsten Zeichenmodus (Linie, Rechteck, Füllen), auf der Objektseite das nächste Objekt bzw. das Ende eines Fahrzeugpfads.
func _primary_next() -> void:
	if page == 0:
		_select_tool((tool + 1) % 3)
	elif page == 1:
		if not veh_pts.is_empty():
			_veh_finish()                      # Fahrzeugpfad beenden (letzter Punkt = Ausgang)
		else:
			_obj_step(1)                       # nächstes vorhandenes Objekt wählen (auch unsichtbare wie Meteoriten finden)

## Nach einem Mausklick auf einen Knopf behält er sonst den Fokus und die Tastatur/der Controller malen nicht mehr: Fokus gleich wieder abgeben.
func _input(event: InputEvent) -> void:
	if osk != null:
		return                                                 # die Bildschirmtastatur gehört sich selbst
	if help != null:
		if (event is InputEventKey or event is InputEventJoypadButton) and event.is_pressed() and not event.is_echo():
			get_viewport().set_input_as_handled()              # jede Taste schließt die Hilfe (Mausklick: über die Fläche selbst)
			_close_help()
		elif event is InputEventKey or event is InputEventJoypadButton or event is InputEventJoypadMotion:
			get_viewport().set_input_as_handled()
		return
	if leave_dlg != null:
		if event.is_action_pressed("ui_cancel"):
			get_viewport().set_input_as_handled()
			_leave_close()
		return                                                 # sonst bedient der normale Fokus die drei Knöpfe
	var fo := get_viewport().gui_get_focus_owner()
	if fo != null and (event is InputEventJoypadButton or event is InputEventKey) and event.is_pressed():
		gamepad_hint = event is InputEventJoypadButton              # Hinweiszeile folgt dem Gerät auch dort, wo ein Wert das Ereignis verbraucht
	if fo != null and _value_input(fo, event):
		_update_hint()
		return
	if fo is LineEdit and (event is InputEventJoypadButton or event is InputEventJoypadMotion) and not event.is_echo():
		# Controller im Textfeld: A öffnet die Bildschirmtastatur, die Richtungen verlassen das Feld (es würde sie sonst für den Cursor verbrauchen)
		if event.is_action_pressed("ui_accept"):
			get_viewport().set_input_as_handled()
			_open_osk(fo)
			return
		for side in [[SIDE_LEFT, "ui_left"], [SIDE_RIGHT, "ui_right"], [SIDE_TOP, "ui_up"], [SIDE_BOTTOM, "ui_down"]]:
			if event.is_action_pressed(side[1]):
				get_viewport().set_input_as_handled()
				var nb: Control = fo.find_valid_focus_neighbor(side[0])
				if nb != null:
					nb.grab_focus()
				return
	if event is InputEventMouseButton and not event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_release_button_focus.call_deferred()
	# Im Zeichenmodus (kein Knopf fokussiert) gehören Pfeile, A/Enter und Tab dem Editor: sonst würde die Oberfläche den Fokus an sich ziehen.
	if not preview_mode and page != 2 and get_viewport().gui_get_focus_owner() == null:
		for a in ["ui_left", "ui_right", "ui_up", "ui_down", "ui_accept", "ui_focus_next", "ui_focus_prev"]:
			if event.is_action(a):
				get_viewport().set_input_as_handled()
				if event.is_action_pressed("ui_focus_next") and not event.is_echo():
					_primary_next()
				return

func _release_button_focus() -> void:
	var f := get_viewport().gui_get_focus_owner()
	if f is Button:
		f.release_focus()
		overlay.queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if osk != null or help != null or leave_dlg != null:
		return
	if event is InputEventJoypadButton or event is InputEventJoypadMotion:
		gamepad_hint = true
		_update_hint()
	elif event is InputEventKey:
		gamepad_hint = false
		_update_hint()
	if preview_mode:
		if (event is InputEventKey or event is InputEventJoypadButton or event is InputEventMouseButton) and event.pressed:
			get_viewport().set_input_as_handled()
			_set_preview(false)
		return
	var focus := get_viewport().gui_get_focus_owner()
	if event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_X:
		get_viewport().set_input_as_handled()                  # Controller: X öffnet und schließt die Bedienfelder (B löscht beim Zeichnen)
		_toggle_menu()
		return
	if event is InputEventJoypadMotion and (event.axis == JOY_AXIS_TRIGGER_LEFT or event.axis == JOY_AXIS_TRIGGER_RIGHT):
		get_viewport().set_input_as_handled()                  # Controller: LT/RT schalten die Seiten (Karte, Objekte, Level) zurück/vor
		var down: bool = event.axis_value > 0.6
		if event.axis == JOY_AXIS_TRIGGER_LEFT:
			if down and not trig_l:
				_set_page(wrapi(page - 1, 0, 3), true)
			trig_l = down
		else:
			if down and not trig_r:
				_set_page(wrapi(page + 1, 0, 3), true)
			trig_r = down
		return
	if event is InputEventJoypadButton and event.button_index == JOY_BUTTON_BACK:
		get_viewport().set_input_as_handled()                  # Back: kurz = Vorschau (beim Loslassen), gehalten = Hilfe (in _process), auch aus den Bedienfeldern
		if event.pressed:
			_back_t = 0.0
			_back_used = false
		elif _back_t >= 0.0:
			if not _back_used:
				_set_preview(true)
			_back_t = -1.0
		return
	if event is InputEventJoypadButton and event.pressed and (event.button_index == JOY_BUTTON_LEFT_STICK or event.button_index == JOY_BUTTON_RIGHT_STICK):
		get_viewport().set_input_as_handled()                  # Stickklick: L3 rückgängig, R3 wiederholen
		_undo_redo(event.button_index == JOY_BUTTON_LEFT_STICK)
		return
	if event.is_action_pressed("ui_cancel"):
		if focus != null:
			get_viewport().set_input_as_handled()
			if page == 2:
				_set_page(0)                                   # Level-Seite: B geht zurück zur Karte (dort wird gezeichnet)
				input_ready = false
			else:
				get_viewport().gui_release_focus()             # in den Bedienfeldern geht B (wie Esc) zurück zur Zeichenfläche
				input_ready = false                            # B löscht erst nach dem Loslassen wieder
			overlay.queue_redraw()
		elif event is InputEventKey:
			get_viewport().set_input_as_handled()
			_enter_menu()
		else:
			get_viewport().set_input_as_handled()              # B auf der Zeichenfläche löscht (siehe _process), es öffnet kein Menü
		return
	if focus != null:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var handled := true
		if event.is_command_or_control_pressed():
			match event.keycode:
				KEY_Z:
					_undo_redo(not event.shift_pressed)
				KEY_Y:
					_undo_redo(false)
				KEY_S:
					_save(true)
				_:
					handled = false
		else:
			match event.keycode:
				KEY_Q, KEY_PAGEUP, KEY_BRACKETLEFT:
					_cycle_pal(-1)
				KEY_E, KEY_PAGEDOWN, KEY_BRACKETRIGHT:
					_cycle_pal(1)
				KEY_TAB:
					_primary_next()
				KEY_N:
					if page == 1:
						_obj_add()
				KEY_F1:
					_set_page(0)
				KEY_F2:
					_set_page(1)
				KEY_F3:
					_set_page(2, true)
				KEY_G:
					_toggle_grid()
				KEY_F:
					_next_error()
				KEY_H:
					_open_help()
				KEY_V:
					_set_preview(true)
				KEY_T, KEY_F5:
					_test_flight(false)
				KEY_F6:
					_test_flight(true)
				KEY_P:
					_eyedrop(cursor)
				KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_7, KEY_8, KEY_9:
					if page == 0:
						_select_pal(2 + (event.keycode - KEY_1))
				_:
					handled = false
		if handled:
			get_viewport().set_input_as_handled()
	elif event is InputEventJoypadButton and event.pressed:
		var handled2 := true
		match event.button_index:
			JOY_BUTTON_LEFT_SHOULDER:
				_cycle_pal(-1)
			JOY_BUTTON_RIGHT_SHOULDER:
				_cycle_pal(1)
			JOY_BUTTON_Y:
				_primary_next()
			JOY_BUTTON_START:
				_test_flight(false)
			_:
				handled2 = false
		if handled2:
			get_viewport().set_input_as_handled()

func _undo_redo(is_undo: bool) -> void:
	if active:
		return
	if (model.undo() if is_undo else model.redo()):
		model.dirty = true
		if not model.valid_ref(obj_ref):
			obj_ref = {}
		if page == 1:
			_rebuild_params()
		_changed()
		_sync_fields()
		if page == 2:
			_rebuild_jobs()

func _pad_pressed(button: int) -> bool:
	for dev in Input.get_connected_joypads():
		if Input.is_joy_button_pressed(dev, button):
			return true
	return false

func _end_key_stroke() -> void:
	if key_paint or key_erase:
		key_paint = false
		key_erase = false
		_end_stroke()

func _process(delta: float) -> void:
	_hold_tick(delta)
	if _back_t >= 0.0:
		_back_t += delta
		if _back_t >= BACK_HOLD and not _back_used:
			_back_used = true
			_open_help()
	if leave_dlg == null and help == null:
		_update_badge()
	if _blink > 0.0:
		_blink = maxf(0.0, _blink - delta)
		overlay.queue_redraw()
	if preview_t >= 0.0:
		preview_t -= delta
		if preview_t < 0.0:
			_refresh_preview()
	if validate_t >= 0.0:
		validate_t -= delta
		if validate_t < 0.0:
			_start_async()
	_poll_validation()
	if preview_mode or help != null or leave_dlg != null:
		_end_key_stroke()
		return
	if get_viewport().gui_get_focus_owner() != null:
		_end_key_stroke()
		return
	# Cursor mit Tastatur und Controller: sofort ein Schritt, nach kurzer Pause wiederholt
	var dir := Vector2i(
		int(Input.is_action_pressed("ui_right") or Input.is_physical_key_pressed(KEY_D)) - int(Input.is_action_pressed("ui_left") or Input.is_physical_key_pressed(KEY_A)),
		int(Input.is_action_pressed("ui_down") or Input.is_physical_key_pressed(KEY_S)) - int(Input.is_action_pressed("ui_up") or Input.is_physical_key_pressed(KEY_W)))
	if Input.is_key_pressed(KEY_CTRL) or Input.is_key_pressed(KEY_META):
		dir = Vector2i.ZERO                                         # Strg+S, Strg+Z usw.: nicht gleichzeitig den Cursor bewegen
	if dir == Vector2i.ZERO:
		move_dir = Vector2i.ZERO
	else:
		move_t -= delta
		if dir != move_dir or move_t <= 0.0:
			move_t = MOVE_REPEAT if dir == move_dir else MOVE_DELAY
			move_dir = dir
			mouse_mode = false
			cursor = Vector2i(clampi(cursor.x + dir.x, 0, model.w - 1), clampi(cursor.y + dir.y, 0, model.h - 1))
			if active:
				_move_stroke(cursor)
			overlay.queue_redraw()
	# Malen (Leertaste/Enter/A) und Löschen (X, Rücktaste, Entf)
	var paint := (Input.is_action_pressed("ui_accept") and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)) and not Input.is_key_pressed(KEY_CTRL)
	var erase := Input.is_key_pressed(KEY_X) or Input.is_key_pressed(KEY_BACKSPACE) or Input.is_key_pressed(KEY_DELETE) or _pad_pressed(JOY_BUTTON_B)
	if not paint and not erase:
		input_ready = true                                          # erst nach dem Loslassen: die Taste, die den Editor geöffnet hat, malt nichts
	if paint and input_ready and not key_paint and not key_erase:
		key_paint = true
		_begin(false, cursor)
	elif erase and input_ready and not key_erase and not key_paint:
		key_erase = true
		_begin(true, cursor)
	if key_paint and not paint:
		key_paint = false
		_end_stroke()
	if key_erase and not erase:
		key_erase = false
		_end_stroke()
