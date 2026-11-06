extends Control
## Community-Level: Liste der gespeicherten Level mit Vorschau, Spielen, Import aus der Zwischenablage, Level-Code kopieren, Original kopieren und
## Löschen. Vollständig per Tastatur, Gamepad und Maus bedienbar; auf der 640×360-Fläche wie die Levelauswahl.

const CommunityLevel := preload("res://src/core/community_level.gd")
const CommunityStore := preload("res://src/core/community_store.gd")
const LevelFiles := preload("res://src/core/level_files.gd")

var back: Callable
var edit: Callable                 # Editor öffnen: edit.call(id) (id == "" = neues Level)
var edit_original: Callable        # Debug: Original im Editor öffnen: edit_original.call(id)
var reopen_originals := ""        # Id eines Originals: die Liste öffnet sofort die Originalauswahl (Debug) und wählt dieses an
var editing_originals := false     # die Originalauswahl öffnet den Editor statt eine Kopie anzulegen
var entries: Array = []
var sel := -1
var armed := ""                    # Level, dessen Löschen bestätigt werden muss
var main: Control                  # alles außer der Originalauswahl (unsichtbare Knöpfe nehmen keinen Fokus)
var overlay: Control = null
var list_box: VBoxContainer
var preview: MapPreview
var info_name: Label
var info_text: Label
var status: Label
var btn_share: Button
var btn_edit: Button
var btn_delete: Button
var btn_play: Button
var actions: GridContainer

class MapPreview extends Control:
	var rows: Array = []
	const COLORS := {"#": Color("#3a4580"), "^": Color("#ff4d6d"), "S": Color("#5dd6ff"), "E": Color("#ffe14a"), "F": Color("#5dff9a"), "L": Color("#ff8ad8"),
		"H": Color("#ffffff"), "P": Color("#2f8f5a")}
	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.03, 0.04, 0.1, 0.88))
		draw_rect(Rect2(Vector2.ZERO, size).grow(1.0), Color("#3a4580"), false, 1.0)
		if rows.is_empty():
			return
		var w := 0
		for r in rows:
			w = maxi(w, String(r).length())
		var cell := floorf(minf((size.x - 8.0) / float(w), (size.y - 8.0) / float(rows.size())))
		var origin := (size - Vector2(cell * w, cell * rows.size())) * 0.5
		for y in rows.size():
			var row: String = rows[y]
			for x in row.length():
				var ch := row[x]
				if ch == ".":
					continue
				var col: Color = COLORS.get(ch, Color("#ffd24a") if "123456789".contains(ch) else Color("#b07bff"))
				draw_rect(Rect2(origin + Vector2(x, y) * cell, Vector2(cell, cell)), col)

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(MenuKit.dim_rect(0.62))
	main = Control.new()
	main.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	main.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(main)
	main.add_child(_at(MenuKit.title(tr("CM_TITLE"), 16), Vector2(0, 8), Vector2(640, 20)))
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	main.add_child(_at(scroll, Vector2(16, 36), Vector2(290, 214)))
	list_box = VBoxContainer.new()
	list_box.add_theme_constant_override("separation", 2)
	list_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list_box)
	preview = MapPreview.new()
	main.add_child(_at(preview, Vector2(322, 36), Vector2(302, 150)))
	info_name = _at(MenuKit.title("", 12), Vector2(322, 190), Vector2(302, 16))
	main.add_child(info_name)
	info_text = Label.new()
	info_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info_text.add_theme_font_size_override("font_size", 8)
	info_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	main.add_child(_at(info_text, Vector2(322, 207), Vector2(302, 44)))
	actions = GridContainer.new()
	actions.columns = 5
	actions.add_theme_constant_override("h_separation", 4)
	actions.add_theme_constant_override("v_separation", 3)
	main.add_child(_at(actions, Vector2(16, 256), Vector2(608, 44)))
	btn_play = _action(tr("CM_PLAY"), func(): _play(_selected_id()))
	actions.add_child(btn_play)
	btn_edit = _action(tr("CM_EDIT"), func(): edit.call(_selected_id()))
	actions.add_child(btn_edit)
	actions.add_child(_action(tr("CM_NEW"), func(): edit.call("")))
	btn_delete = _action(tr("CM_DELETE"), _delete)
	actions.add_child(btn_delete)
	btn_share = _action(tr("CM_SHARE"), _share)
	actions.add_child(btn_share)
	actions.add_child(_action(tr("CM_IMPORT"), _import_clipboard))
	actions.add_child(_action(tr("CM_COPY_ORIG"), _open_originals.bind(false)))
	if Save.debug and LevelFiles.can_write() and edit_original.is_valid():
		actions.add_child(_action(tr("CM_EDIT_ORIG"), _open_originals.bind(true)))
	actions.add_child(_action(tr("CM_OPEN_DIR"), _open_folder))
	actions.add_child(_action(tr("MENU_BACK"), func(): back.call()))
	status = Label.new()
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.add_theme_font_size_override("font_size", 8)
	status.add_theme_color_override("font_color", Color("#ffe14a"))
	main.add_child(_at(status, Vector2(16, 304), Vector2(608, 20)))
	var hint := Label.new()
	hint.text = tr("CM_HINT")
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 8)
	main.add_child(_at(hint, Vector2(0, 336), Vector2(640, 12)))
	_rebuild()
	if reopen_originals != "" and Save.debug and edit_original.is_valid():
		_open_originals(true)

func _at(c: Control, pos: Vector2, sz: Vector2) -> Control:
	c.position = pos
	c.size = sz
	return c

func _action(text: String, cb: Callable) -> Button:
	var b := MenuKit.button(text, cb)
	b.custom_minimum_size = Vector2(116, 19)
	b.add_theme_font_size_override("font_size", 9)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return b

func _say(text: String) -> void:
	status.text = text

func _lang() -> String:
	return TranslationServer.get_locale().substr(0, 2)

## Liste neu aufbauen; `focus_id` (oder der bisher gewählte Eintrag) bekommt den Fokus.
func _rebuild(focus_id := "") -> void:
	var keep := focus_id if focus_id != "" else (String(entries[sel].id) if sel >= 0 and sel < entries.size() else "")
	entries = CommunityStore.list()
	for c in list_box.get_children():
		list_box.remove_child(c)
		c.queue_free()
	sel = -1
	armed = ""
	btn_delete.text = tr("CM_DELETE")
	var first: Button = null
	var want: Button = null
	for i in entries.size():
		var e: Dictionary = entries[i]
		var author := String(e.author)
		var b := MenuKit.button("%s · %s" % [String(e.name.get(_lang(), e.name.de)), author if author != "" else tr("CM_NO_AUTHOR")], _pick.bind(i))
		b.custom_minimum_size = Vector2(272, 17)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.clip_text = true
		b.focus_entered.connect(_select.bind(i))
		b.gui_input.connect(_row_input.bind(b, String(e.id)))
		list_box.add_child(b)
		if first == null:
			first = b
		if String(e.id) == keep:
			want = b
	if entries.is_empty():
		var l := Label.new()
		l.text = tr("CM_EMPTY")
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(260, 0)
		l.add_theme_font_size_override("font_size", 8)
		list_box.add_child(l)
	_select(-1 if entries.is_empty() else (entries.find_custom(func(e): return String(e.id) == keep) if want != null else 0))
	btn_share.disabled = entries.is_empty()
	btn_edit.disabled = entries.is_empty()
	btn_delete.disabled = entries.is_empty()
	btn_play.disabled = entries.is_empty()
	if not is_inside_tree():
		return
	await get_tree().process_frame
	if not is_inside_tree():
		return
	var target: Button = want if want != null else first
	if target != null:
		target.grab_focus()
	else:
		actions.get_child(2).grab_focus()               # keine Level: „Neues Level“

func _select(i: int) -> void:
	if i == sel:
		return
	sel = i
	armed = ""
	btn_delete.text = tr("CM_DELETE")
	if i < 0 or i >= entries.size():
		preview.rows = []
		preview.queue_redraw()
		info_name.text = ""
		info_text.text = ""
		return
	var e: Dictionary = entries[i]
	preview.rows = e.get("map", [])                      # aus dem Listenauszug: die Auswahl soll nicht jedes Level erneut prüfen
	preview.queue_redraw()
	info_name.text = String(e.name.get(_lang(), e.name.de))
	var lines: Array = [tr("CM_AUTHOR") % (String(e.author) if String(e.author) != "" else tr("CM_NO_AUTHOR")), tr("CM_THEME") % [int(e.sector), int(e.jobs)],
		tr("CM_LICENSE") % String(e.license)]
	if String(e.derived_from) != "":
		lines.append(tr("CM_DERIVED") % String(e.derived_from).to_upper().replace("_", "-"))
	var id := String(e.id)
	lines.append(tr("CM_BEST") % [int(Save.community_best_time(id)), Save.community_best_score(id), Save.community_plays(id)] if Save.community_plays(id) > 0 else tr("CM_NO_BEST"))
	info_text.text = "\n".join(lines)

## Maus: Einfachklick wählt nur an (so lässt sich danach löschen oder kopieren), Doppelklick spielt. Das bloße Darüberfahren ändert die Auswahl nicht
## (der Weg zum Löschknopf führte sonst über die unteren Einträge). Tastatur und Gamepad: Fokus wählt an, Bestätigen (A/Enter) springt wie der
## Einfachklick zu den Aktionen („Spielen“ zuerst), statt das Level sofort zu laden; Zurück (B) führt aus den Aktionen wieder in die Liste.
func _row_input(ev: InputEvent, b: Button, id: String) -> void:
	if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT and ev.pressed:
		b.accept_event()
		if ev.double_click:
			_play(id)
		else:
			b.grab_focus()

func _pick(i: int) -> void:
	_select(i)
	if btn_play != null and not btn_play.disabled and btn_play.is_inside_tree():
		btn_play.grab_focus()

func _play(id: String) -> void:
	Flow.start_community(id)

func _selected_id() -> String:
	return String(entries[sel].id) if sel >= 0 and sel < entries.size() else ""

func _share() -> void:
	var code := CommunityStore.export_code(_selected_id())
	if code == "":
		_say(CommunityLevel.describe({"code": "NOT_FOUND", "args": []}))
		return
	DisplayServer.clipboard_set(code)
	_say(tr("CM_COPIED"))

func _open_folder() -> void:
	DirAccess.make_dir_recursive_absolute(CommunityStore._d())
	OS.shell_show_in_file_manager(ProjectSettings.globalize_path(CommunityStore._d()))

## Zweimal drücken: Der erste Druck fragt nach, der zweite löscht (auch mit dem Gamepad ohne Dialog bedienbar).
func _delete() -> void:
	var id := _selected_id()
	if id == "":
		return
	if armed != id:
		armed = id
		btn_delete.text = tr("CM_DELETE_SURE")
		return
	CommunityStore.delete(id)
	Save.community_forget(id)
	_say(tr("CM_DELETED"))
	_rebuild()

func _report(res: Dictionary) -> void:
	var lines: Array = []
	if res.ok:
		var nm := String(res.level.name.get(_lang(), res.level.name.de))
		lines.append((tr("CM_EXISTS") if res.get("existed", false) else tr("CM_IMPORTED")) % nm)
		for w in res.warnings.slice(0, 2):
			lines.append(CommunityLevel.describe(w, true))
	else:
		for e in res.errors.slice(0, 2):
			lines.append(CommunityLevel.describe(e))
	_say("\n".join(lines))

func _import_clipboard() -> void:
	var text := DisplayServer.clipboard_get()
	if text.strip_edges() == "":
		_say(tr("CM_CLIP_EMPTY"))
		return
	_say(tr("CM_CHECKING"))
	await get_tree().process_frame
	var res := CommunityStore.import_text(text)           # die Lösbarkeit prüft die Regelprüfung; der Autopilot ist kein Maßstab (und blockierte hier die Oberfläche)
	_report(res)
	_rebuild(String(res.id) if res.ok else "")

# ---------------------------------------------------------------------------------------------------------------- Originale kopieren

func _open_originals(for_editing := false) -> void:
	editing_originals = for_editing
	main.visible = false
	overlay = Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)
	overlay.add_child(_at(MenuKit.title(tr("CM_PICK_ORIG_EDIT") if for_editing else tr("CM_PICK_ORIG"), 12), Vector2(0, 14), Vector2(640, 16)))
	var grid := GridContainer.new()
	grid.columns = 11
	grid.add_theme_constant_override("h_separation", 3)
	grid.add_theme_constant_override("v_separation", 3)
	overlay.add_child(_at(grid, Vector2(95, 44), Vector2(450, 230)))
	var first: Button = null
	for id in Flow.level_ids():
		var parts := String(id).split("_")                  # s3_05 -> Levelnummer 27, ohne die Datei zu laden
		var number := (int(parts[0].substr(1)) - 1) * 11 + int(parts[1]) if parts.size() == 2 else 0
		var b := MenuKit.button("%02d" % number, _pick_original.bind(String(id)))
		b.custom_minimum_size = Vector2(36, 18)
		b.add_theme_font_size_override("font_size", 8)
		grid.add_child(b)
		if first == null or String(id) == reopen_originals:
			first = b
	var bb := MenuKit.button(tr("MENU_BACK"), _close_originals)
	overlay.add_child(_at(bb, Vector2(256, 300), Vector2(128, 19)))
	if first != null:
		first.grab_focus.call_deferred()

func _close_originals() -> void:
	if overlay != null:
		overlay.queue_free()
		overlay = null
	main.visible = true
	_rebuild()

func _pick_original(id: String) -> void:
	if editing_originals and edit_original.is_valid():
		edit_original.call(id)
	else:
		_copy_original(id)

func _copy_original(id: String) -> void:
	var res := CommunityStore.copy_original(id)
	_close_originals()
	_report(res)
	if res.ok:
		_rebuild(String(res.id))

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		if overlay != null:
			_close_originals()
		elif _actions_have_focus() and sel >= 0 and sel < list_box.get_child_count():
			(list_box.get_child(sel) as Control).grab_focus()               # B in den Aktionen: zurück in die Liste
		else:
			back.call()

func _actions_have_focus() -> bool:
	var f := get_viewport().gui_get_focus_owner() if is_inside_tree() else null
	return f != null and actions != null and actions.is_ancestor_of(f)
