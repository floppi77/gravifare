extends Control
## Level-Editor für Community-Level: Karte malen (Fels, Luft, Pads, Tank, Leben, Klinik, Dornen, Pumpe, Start) mit Stift, Rechteck und Füllen, live geprüft und mit
## der echten Spielansicht als Vorschau. Bedienung: Maus (links malen, rechts löschen, Rad = Auswahl), Tastatur (Pfeile/WASD bewegen, Leertaste malen, X löschen)
## und Controller (Stick/Steuerkreuz bewegen, A malen, B löschen, LB/RB Auswahl). Esc bzw. X (Controller) öffnet und schließt die Bedienfelder (Menü), alles dort ist per
## Fokus erreichbar. Das geöffnete Level bleibt unverändert: gespeichert wird eine eigene Fassung (die der letzten Speicherung dieser Sitzung ersetzt wird).

const CommunityLevel := preload("res://src/core/community_level.gd")
const CommunityStore := preload("res://src/core/community_store.gd")
const LevelEdit := preload("res://src/core/level_edit.gd")
const EditorCanvas := preload("res://src/ui/editor_canvas.gd")

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
var leave_armed := false
var gamepad_hint := false
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
var tool_btns: Array = []
var pal_btns: Array = []
var look_label: Label
var dark_label: Label
var btn_back: Button
var btn_save: Button
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
var _slim_styles := {}
var input_ready := false
var trig_l := false
var trig_r := false

## Neues Level (id == "") oder Kopie des Levels `id` zum Bearbeiten. `session` = bereits in dieser Sitzung gespeicherte Fassung.
func open(id: String, session := "") -> bool:
	origin_id = id
	session_id = session
	if id == "":
		model = LevelEdit.blank()
	else:
		var r := CommunityStore.load_level(id)
		if not r.ok or r.has("stale_id"):
			return false
		model = LevelEdit.from_result(r)
		last_jobs = r.level.jobs
	if model.author == "":
		model.author = Save.community_author()
	return true

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(MenuKit.dim_rect(0.86))
	if model == null:
		model = LevelEdit.blank()
	title = MenuKit.title("", 10)
	add_child(_at(title, Vector2(0, 2), Vector2(640, 14)))
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
	_update_hint()

func _at(c: Control, pos: Vector2, sz: Vector2) -> Control:
	c.position = pos
	c.size = sz
	return c

# ---------------------------------------------------------------------------------------------------------------- Aufbau

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

func _build_page_map(pg: Control) -> void:
	var names := [tr("ED_TOOL_PEN"), tr("ED_TOOL_RECT"), tr("ED_TOOL_FILL")]
	for i in 3:
		tool_btns.append(_button(names[i], _select_tool.bind(i), Vector2(i * 48.0, 0), Vector2(45, 17), pg, 6))
	for i in LevelEdit.PALETTE.size():
		var e: Array = LevelEdit.PALETTE[i]
		var label: String = e[0] if LevelEdit.PAD_CHARS.contains(e[0]) else tr(e[1]) + (" " + String(e[0]) if LevelEdit.DOOR_CHARS.contains(e[0]) else "")
		pal_btns.append(_button(label, _select_pal.bind(i), Vector2((i % 3) * 48.0, 22.0 + (i / 3) * 20.0), Vector2(45, 17), pg, 7))
	_button(tr("ED_RENUMBER"), _renumber, Vector2(0, 186), Vector2(144, 17), pg, 7)

func _build_page_objects(pg: Control) -> void:
	_button("<", _kind_step.bind(-1), Vector2(0, 0), Vector2(20, 17), pg)
	kind_label = _label("", Vector2(22, 2), Vector2(100, 14), pg)
	_button(">", _kind_step.bind(1), Vector2(124, 0), Vector2(20, 17), pg)
	_button(tr("ED_O_ADD"), _obj_add, Vector2(0, 20), Vector2(70, 17), pg, 7)
	_button(tr("ED_O_DEL"), _obj_remove, Vector2(74, 20), Vector2(70, 17), pg, 7)
	_button("<", _obj_step.bind(-1), Vector2(0, 42), Vector2(20, 17), pg)
	obj_label = _label("", Vector2(22, 44), Vector2(100, 14), pg)
	_button(">", _obj_step.bind(1), Vector2(124, 42), Vector2(20, 17), pg)
	param_box = Control.new()
	param_box.position = Vector2(0, 64)
	param_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pg.add_child(param_box)
	var h := _label(tr("ED_O_HINT"), Vector2(0, 218), Vector2(144, 24), pg)
	h.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	h.add_theme_font_size_override("font_size", 7)
	h.add_theme_color_override("font_color", Color("#9aa6dd"))
	_kind_step(0)

func _build_page_level(pg: Control) -> void:
	look_label = _label("", Vector2(22, 2), Vector2(100, 14), pg)
	_button("<", _change_look.bind(-1), Vector2(0, 0), Vector2(20, 17), pg)
	_button(">", _change_look.bind(1), Vector2(124, 0), Vector2(20, 17), pg)
	dark_label = _label("", Vector2(22, 22), Vector2(100, 14), pg)
	_button("<", _change_dark.bind(-1), Vector2(0, 20), Vector2(20, 17), pg)
	_button(">", _change_dark.bind(1), Vector2(124, 20), Vector2(20, 17), pg)
	_button(tr("ED_REROLL"), _reroll, Vector2(0, 40), Vector2(70, 17), pg, 7)
	job_mode_btn = _button("", _job_mode, Vector2(74, 40), Vector2(70, 17), pg, 7)
	job_box = Control.new()
	job_box.position = Vector2(0, 62)
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
	parent.add_child(l)
	return l

func _build_bottom() -> void:
	bottom = Control.new()
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bottom)
	status = _label("", Vector2(6, 284), Vector2(480, 20), bottom)
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.add_theme_color_override("font_color", Color("#ffe14a"))
	hint = _label("", Vector2(6, 305), Vector2(630, 11), bottom)
	hint.add_theme_font_size_override("font_size", 7)
	hint.add_theme_color_override("font_color", Color("#9aa6dd"))
	_label(tr("ED_NAME"), Vector2(6, 318), Vector2(34, 16), bottom)
	name_edit = _line_edit(Vector2(42, 318), Vector2(220, 16), CommunityLevel.MAX_TEXT)
	name_edit.text_changed.connect(_name_changed)
	_label(tr("ED_AUTHOR"), Vector2(270, 318), Vector2(38, 16), bottom)
	author_edit = _line_edit(Vector2(310, 318), Vector2(130, 16), CommunityLevel.MAX_AUTHOR)
	author_edit.text_changed.connect(_author_changed)
	btn_save = _button(tr("ED_SAVE"), func(): _save(true), Vector2(6, 338), Vector2(118, 18), bottom)
	_button(tr("ED_TEST"), _test_flight, Vector2(128, 338), Vector2(118, 18), bottom)
	_button(tr("ED_PREVIEW"), func(): _set_preview(true), Vector2(250, 338), Vector2(118, 18), bottom)
	_button(tr("ED_GRID"), _toggle_grid, Vector2(372, 338), Vector2(118, 18), bottom)
	btn_back = _button(tr("ED_BACK"), _request_back, Vector2(494, 338), Vector2(142, 18), bottom)

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
	overlay.queue_redraw()

func _sync_fields() -> void:
	var lang := TranslationServer.get_locale().substr(0, 2)
	name_edit.text = String(model.names.get(lang, model.names.get("de", "")))
	author_edit.text = model.author
	look_label.text = tr("ED_LOOK") % model.sector
	dark_label.text = tr("ED_DARK") % int(round(model.dark * 100.0))
	_update_title()

func _update_title() -> void:
	title.text = "%s%s" % [tr("ED_TITLE"), " *" if model.dirty else ""]

# ---------------------------------------------------------------------------------------------------------------- Auswahl und Eigenschaften

func _select_tool(i: int) -> void:
	tool = i
	for k in tool_btns.size():
		tool_btns[k].modulate = Color(1.3, 1.25, 0.8) if k == i else Color.WHITE
	_update_hint()

func _select_pal(i: int) -> void:
	pal = posmod(i, LevelEdit.PALETTE.size())
	for k in pal_btns.size():
		pal_btns[k].modulate = Color(1.3, 1.25, 0.8) if k == pal else Color.WHITE
	overlay.queue_redraw()

func _cycle_pal(step: int) -> void:
	if page == 1:
		_obj_step(step)                      # auf der Objektseite wählen LB/RB, Q/E und das Mausrad das Objekt
	elif page == 0:
		_select_pal(pal + step)

func _change_look(step: int) -> void:
	model.sector = wrapi(model.sector - 1 + step, 0, 9) + 1
	_after_property()

func _change_dark(step: int) -> void:
	var steps := [0.0, 0.6, 0.78, 0.9]
	var i := 0
	for k in steps.size():
		if absf(float(steps[k]) - model.dark) < absf(float(steps[i]) - model.dark):
			i = k
	model.dark = float(steps[wrapi(i + step, 0, steps.size())])
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
	model.names = {"de": s, "en": s} if s != "" else {"de": "Mein Level", "en": "My level"}
	model.dirty = true
	_update_title()
	_request_validation(0.45)

func _say(t: String) -> void:
	status.text = t
	status.add_theme_color_override("font_color", Color("#ffe14a"))

func _update_hint() -> void:
	if page == 1:
		hint.text = tr("ED_HINT_OBJ_PAD") if gamepad_hint else tr("ED_HINT_OBJ_KEYS")
	elif page == 2:
		hint.text = tr("ED_HINT_LVL")
	else:
		hint.text = tr("ED_HINT_PAD") if gamepad_hint else tr("ED_HINT_KEYS")

# ---------------------------------------------------------------------------------------------------------------- Seiten, Objekte, Aufträge

func _set_page(i: int) -> void:
	if active:
		return
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
	overlay.queue_redraw()

func _kind_step(step: int) -> void:
	kind_idx = wrapi(kind_idx + step, 0, LevelEdit.KINDS.size())
	kind_label.text = tr("ED_O_KIND") % tr("ED_K_" + String(LevelEdit.KINDS[kind_idx]))

func _obj_add() -> void:
	var ref: Dictionary = model.add_object(LevelEdit.KINDS[kind_idx], cursor.x, cursor.y)
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
	if key == "period" and obj_ref.get("t") == "zone" and v <= 0.0:
		return tr("ED_STEADY")
	if key == "sweep" and v <= 0.0:
		return tr("ED_OFF")
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
		return
	var objs: Array = model.objects()
	var idx := 0
	for i in objs.size():
		if model.same_ref(objs[i], obj_ref):
			idx = i + 1
	var kind: String = model.obj_kind(obj_ref)
	obj_label.text = tr("ED_O_SEL") % [idx, objs.size(), tr("ED_K_" + kind) + (" " + String(obj_ref.k) if obj_ref.t == "door" else "")]
	var row := 0
	for p in model.obj_params(obj_ref):
		var y := row * 15.0
		var l := _label(tr(String(p[4])), Vector2(0, y), Vector2(62, 14), param_box)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		l.add_theme_font_size_override("font_size", 7)
		var key: String = p[0]
		var b1 := _button("<", _param_step.bind(key, -1), Vector2(64, y), Vector2(16, 14), param_box, 7)
		b1.set_meta("key", "p:%s:-" % key)
		var val := _label(_param_text(key), Vector2(82, y), Vector2(44, 14), param_box)
		val.add_theme_font_size_override("font_size", 7)
		var b2 := _button(">", _param_step.bind(key, 1), Vector2(128, y), Vector2(16, 14), param_box, 7)
		b2.set_meta("key", "p:%s:+" % key)
		param_vals[key] = val
		row += 1
	_focus_regrab()

func _param_step(key: String, direction: int) -> void:
	if not model.valid_ref(obj_ref):
		return
	model.nudge_param(obj_ref, key, direction)
	for k in param_vals:
		param_vals[k].text = _param_text(k)
	_changed()

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
	for i in list.size():
		var j: Dictionary = list[i]
		var y := i * 15.0
		var n := _label(str(i + 1), Vector2(0, y), Vector2(10, 14), job_box)
		n.add_theme_font_size_override("font_size", 7)
		var to_text: String = tr("ED_EXIT_SHORT") if String(j.to) == "exit" else String(j.to)
		var bf := _button(String(j.from), _job_cycle.bind(i, "from"), Vector2(11, y), Vector2(24, 14), job_box, 7)
		var arrow := _label("→", Vector2(36, y), Vector2(10, 14), job_box)
		arrow.add_theme_font_size_override("font_size", 7)
		var bt := _button(to_text, _job_cycle.bind(i, "to"), Vector2(47, y), Vector2(32, 14), job_box, 7)
		var bz := _button("Z" if j.get("fragile", false) == true else "·", _job_fragile.bind(i), Vector2(80, y), Vector2(18, 14), job_box, 7)
		var bi := _button("+", _job_insert.bind(i), Vector2(100, y), Vector2(18, 14), job_box, 7)
		var bd := _button("×", _job_remove.bind(i), Vector2(120, y), Vector2(18, 14), job_box, 7)
		bf.set_meta("key", "j:%d:from" % i)
		bt.set_meta("key", "j:%d:to" % i)
		bz.set_meta("key", "j:%d:f" % i)
		bi.set_meta("key", "j:%d:i" % i)
		bd.set_meta("key", "j:%d:d" % i)
		if not own:
			for b in [bf, bt, bz, bi, bd]:
				b.disabled = true
	_focus_regrab()

# ---------------------------------------------------------------------------------------------------------------- Zeichnen

func _tile_char(erase: bool) -> String:
	return "." if erase else String(LevelEdit.PALETTE[pal][0])

func _begin(erase: bool, at: Vector2i) -> void:
	if active:
		return
	leave_armed = false
	if page == 2:
		return
	if page == 1:
		_begin_object(erase, at)
		return
	active = true
	stroke_erase = erase
	var ch := _tile_char(erase)
	if tool == TOOL_PEN:
		model.begin_stroke()
		model.line(at, at, ch)
		stroke_last = at
	elif tool == TOOL_RECT:
		rect_start = at
		rect_cur = at
	else:
		model.begin_stroke()
		model.flood(at.x, at.y, ch)
		model.end_stroke()
		active = false
		_changed()
	_changed_soft()

func _begin_object(erase: bool, at: Vector2i) -> void:
	if erase:
		_obj_remove_at(model.pick_object(at.x, at.y))                   # Löschen entfernt das Objekt unter dem Zeiger
		return
	var ref: Dictionary = model.pick_object(at.x, at.y)
	if not ref.is_empty() and not model.same_ref(ref, obj_ref):
		_select_obj(ref)
	if not ref.is_empty() and model.same_ref(ref, obj_ref) and obj_ref.t != "door":
		active = true                                                  # Ziehen verschiebt das Objekt unter dem Zeiger (Tore sind Kartenfelder)
		drag_last = at
		model.begin_stroke()

func _move_stroke(at: Vector2i) -> void:
	if not active:
		return
	if page == 1:
		var delta := at - drag_last
		if delta != Vector2i.ZERO and model.move_object(obj_ref, delta.x, delta.y):
			drag_last = at
			for k in param_vals:
				param_vals[k].text = _param_text(k)
			_changed_soft()
		return
	if tool == TOOL_PEN:
		if at != stroke_last:
			model.line(stroke_last, at, _tile_char(stroke_erase))
			stroke_last = at
			_changed_soft()
	elif tool == TOOL_RECT:
		rect_cur = at
	overlay.queue_redraw()

func _end_stroke() -> void:
	if not active:
		return
	active = false
	if page == 1:
		model.end_stroke()
		_changed()
		return
	if tool == TOOL_PEN:
		model.end_stroke()
	elif tool == TOOL_RECT:
		model.begin_stroke()
		model.rect(rect_start, rect_cur, _tile_char(stroke_erase))
		model.end_stroke()
		rect_start = Vector2i(-1, -1)
	_changed()

func _changed_soft() -> void:
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
			_begin(ev.button_index == MOUSE_BUTTON_RIGHT, cursor)
		elif not ev.pressed and ev.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
			_end_stroke()
		elif ev.pressed and ev.button_index == MOUSE_BUTTON_MIDDLE:
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
	if preview_mode:
		return
	if page == 1:
		for ref in model.objects():
			var bnd: Rect2 = model.obj_bounds(ref)
			if bnd.size == Vector2.ZERO:
				continue
			var sel: bool = model.same_ref(ref, obj_ref)
			var rr := Rect2(bnd.position * cs, bnd.size * cs)
			overlay.draw_rect(rr, Color(1, 0.9, 0.3, 0.16) if sel else Color(1, 1, 1, 0.05))
			overlay.draw_rect(rr, Color("#ffe14a") if sel else Color(1, 1, 1, 0.35), false, 2.0 if sel else 1.0)
			if ref.t != "door":
				var d: Dictionary = model.movers[ref.i] if ref.t == "mover" else model.zones[ref.i]
				if d.get("kind") == "vehicle" and d.has("path"):
					for k in range(d.path.size() - 1):
						overlay.draw_line(Vector2(d.path[k][0], d.path[k][1]) * cs, Vector2(d.path[k + 1][0], d.path[k + 1][1]) * cs, Color(0.5, 0.9, 1, 0.7), 1.0)
	if active and page == 0 and tool == TOOL_RECT and rect_start.x >= 0:
		var a := Vector2i(mini(rect_start.x, rect_cur.x), mini(rect_start.y, rect_cur.y))
		var b := Vector2i(maxi(rect_start.x, rect_cur.x), maxi(rect_start.y, rect_cur.y))
		overlay.draw_rect(Rect2(Vector2(a) * cs, Vector2(b - a + Vector2i.ONE) * cs), Color(1, 0.9, 0.3, 0.25))
		overlay.draw_rect(Rect2(Vector2(a) * cs, Vector2(b - a + Vector2i.ONE) * cs), Color("#ffe14a"), false, 1.0)
	if get_viewport().gui_get_focus_owner() == null or mouse_mode:
		var ch := String(LevelEdit.PALETTE[pal][0])
		var col: Color = COLORS.get(ch, Color("#ffd24a") if LevelEdit.PAD_CHARS.contains(ch) else Color.WHITE)
		var r := Rect2(Vector2(cursor) * cs, Vector2(cs, cs))
		overlay.draw_rect(r, Color(col.r, col.g, col.b, 0.35))
		overlay.draw_rect(r, Color("#ffe14a"), false, 1.0)

# ---------------------------------------------------------------------------------------------------------------- Vorschau, Prüfung, Speichern

func _refresh_preview() -> void:
	preview_t = -1.0
	var d: Dictionary = model.to_level_dict()
	var jobs: Array = model.jobs if not model.jobs.is_empty() else last_jobs
	var valid := true
	for j in jobs:
		valid = valid and model.pad_digits().has(String(j.get("from", ""))) and (String(j.get("to", "")) == "exit" or String(j.get("to", "")) == "H" or model.pad_digits().has(String(j.get("to", ""))))
	d["jobs"] = jobs if valid else []
	d["id"] = "editor"
	canvas.show_level(LevelData.from_dict(d))

## Neue Prüfung anfordern: sie startet nach `delay` Sekunden Ruhe (während des Malens nicht ständig).
func _request_validation(delay: float) -> void:
	_model_rev += 1
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
		for w in res.warnings.slice(0, 1):
			txt += "\n" + CommunityLevel.describe(w, true)
		status.text = txt
		status.add_theme_color_override("font_color", Color("#5dff9a"))
	else:
		var lines: Array = []
		for e in res.errors.slice(0, 2):
			lines.append(CommunityLevel.describe(e))
		status.text = "\n".join(lines)
		status.add_theme_color_override("font_color", Color("#ff8a7a"))
	if model.jobs_reset:
		_refresh_preview()
	if page == 2:
		_rebuild_jobs()

## Speichert eine eigene Fassung. Gibt die ID zurück oder "" bei einem Fehler (der Grund steht in der Statuszeile).
func _save(announce: bool) -> String:
	_validate_now()
	if not res.ok:
		return ""
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

func _test_flight() -> void:
	var id := _save(false)
	if id == "":
		if res.ok == false:
			_say(tr("ED_NEED_VALID") + "\n" + status.text)
		return
	Flow.return_to_editor = id
	Flow.start_community(id)

func _request_back() -> void:
	if model.dirty and not leave_armed:
		leave_armed = true
		btn_back.text = tr("ED_DISCARD")
		_say(tr("ED_UNSAVED"))
		return
	back.call()

func _set_preview(on: bool) -> void:
	preview_mode = on
	panel.visible = not on
	bottom.visible = not on
	title.visible = not on
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
	btn_save.grab_focus()
	overlay.queue_redraw()

## Tab bzw. Y: auf der Kartenseite das nächste Werkzeug, auf der Objektseite ein neues Objekt der gewählten Art.
func _primary_next() -> void:
	if page == 0:
		_select_tool((tool + 1) % 3)
	elif page == 1:
		_obj_add()

## Nach einem Mausklick auf einen Knopf behält er sonst den Fokus und die Tastatur/der Controller malen nicht mehr: Fokus gleich wieder abgeben.
func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and not event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_release_button_focus.call_deferred()
	# Im Zeichenmodus (kein Knopf fokussiert) gehören Pfeile, A/Enter und Tab dem Editor: sonst würde die Oberfläche den Fokus an sich ziehen.
	if not preview_mode and get_viewport().gui_get_focus_owner() == null:
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
	if event.is_action_pressed("ui_cancel"):
		if focus != null:
			get_viewport().set_input_as_handled()
			get_viewport().gui_release_focus()                 # in den Bedienfeldern geht B (wie Esc) zurück zur Zeichenfläche
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
					_set_page(2)
				KEY_G:
					grid_on = not grid_on
					overlay.queue_redraw()
				KEY_V:
					_set_preview(true)
				KEY_T, KEY_F5:
					_test_flight()
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
				_test_flight()
			JOY_BUTTON_BACK:
				_set_preview(true)
			_:
				handled2 = false
		if handled2:
			get_viewport().set_input_as_handled()
	elif event is InputEventJoypadMotion:
		var lt: bool = event.axis == JOY_AXIS_TRIGGER_LEFT and event.axis_value > 0.6
		var rt: bool = event.axis == JOY_AXIS_TRIGGER_RIGHT and event.axis_value > 0.6
		if event.axis == JOY_AXIS_TRIGGER_LEFT:
			if lt and not trig_l:
				_undo_redo(true)
			trig_l = lt
		elif event.axis == JOY_AXIS_TRIGGER_RIGHT:
			if rt and not trig_r:
				_undo_redo(false)
			trig_r = rt

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

func _process(delta: float) -> void:
	if preview_t >= 0.0:
		preview_t -= delta
		if preview_t < 0.0:
			_refresh_preview()
	if validate_t >= 0.0:
		validate_t -= delta
		if validate_t < 0.0:
			_start_async()
	_poll_validation()
	if preview_mode:
		return
	if get_viewport().gui_get_focus_owner() != null:
		if key_paint or key_erase:
			key_paint = false
			key_erase = false
			_end_stroke()
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
