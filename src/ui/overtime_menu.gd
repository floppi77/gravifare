extends Control
## Menü der Sonderschicht: Lauf fortsetzen oder aufgeben, neuen Lauf einstellen (Länge, Seed, Lizenz, Überstunden-Stufe), Dienstgrad und Bestenliste.
## Auswahlzeilen wechseln mit Links/Rechts (Steuerkreuz, Stick, Pfeiltasten) oder per Klick; der Seed lässt sich würfeln oder eintippen
## (Bildschirmtastatur für den Controller). Freigeschaltet nach Sektor 6 (Flow.ot_unlocked).

const Stage := preload("res://src/core/stage.gd")
const Osk := preload("res://src/ui/osk.gd")

var stage: Control
var col: VBoxContainer
var side: VBoxContainer
var desc: Label
var board_box: VBoxContainer
var osk: Control = null
var length_i := 0
var code := ""
var license_i := 0
var stage_n := 0
var confirm := ""                 # "abandon" oder "start": zweiter Druck bestätigt
var focus_name := ""

func _ready() -> void:
	Music.play_theme("menu")
	Music.set_layers(true, false)
	Music.duck(0.0)
	Flow.overtime = false
	theme = MenuKit.make_theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var backdrop := Control.new()
	backdrop.set_script(load("res://src/ui/menu_backdrop.gd"))
	add_child(backdrop)
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.03, 0.1, 0.66)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	stage = Stage.make(self)
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	code = Overtime.random_code(rng)            # jede Anwahl schlägt einen neuen Zufallsseed vor
	var meta := Flow.ot_meta()
	stage_n = int(meta.get("stage_max", 0))
	var last: Dictionary = meta.get("last", {}) if meta.get("last", {}) is Dictionary else {}
	length_i = maxi(0, Overtime.LENGTH_ORDER.find(String(last.get("length", "short"))))
	var lics := Overtime.licenses_for(Overtime.rank_of(int(meta.get("xp", 0))))
	license_i = maxi(0, lics.find(String(last.get("license", "standard"))))
	_build()

func _lics() -> Array:
	return Overtime.licenses_for(Overtime.rank_of(int(Flow.ot_meta().get("xp", 0))))

func _length() -> String:
	return String(Overtime.LENGTH_ORDER[length_i])

func _build() -> void:
	for c in stage.get_children():
		stage.remove_child(c)
		c.queue_free()
	var meta := Flow.ot_meta()
	var xp := int(meta.get("xp", 0))
	var rank := Overtime.rank_of(xp)
	var title := MenuKit.screen_title(tr("OT_TITLE"), 22)
	title.position = Vector2(0, 6)
	title.size = Vector2(640, 28)
	stage.add_child(title)
	var xb = preload("res://src/ui/overtime_finale.gd").XpBar.new()       # Dienstgrad mit Namen und Fortschritt im Dienstgrad
	xb.xp_from = xp
	xb.xp_to = xp
	xb.position = Vector2(220, 26)
	xb.size = Vector2(200, 30)
	stage.add_child(xb)
	var panel := Panel.new()
	panel.add_theme_stylebox_override("panel", MenuKit.panel_style(0.8))
	panel.position = Vector2(16, 52)
	panel.size = Vector2(300, 296)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(panel)
	col = VBoxContainer.new()
	col.position = Vector2(26, 60)
	col.size = Vector2(280, 280)
	col.add_theme_constant_override("separation", 4)
	stage.add_child(col)
	var saved := Flow.ot_saved()
	if not saved.is_empty():
		var info := tr("OT_RESUME") % [mini(int(saved.etappe) + 1, Overtime.total(saved)), Overtime.total(saved), tr("OT_LEN_" + String(saved.length).to_upper()), String(saved.code)]
		_add(MenuKit.button(info, func(): Flow.resume_overtime()), "resume", "OT_RESUME_D")
		_add(MenuKit.button(tr("OT_ABANDON_SURE") if confirm == "abandon" else tr("OT_ABANDON"), func():
			if confirm == "abandon":
				confirm = ""
				Flow.ot_abandon()
				get_tree().change_scene_to_file(Flow.OT_FINALE)
			else:
				confirm = "abandon"
				focus_name = "abandon"
				_build()), "abandon", "OT_ABANDON_D")
		var gap := Control.new()
		gap.custom_minimum_size = Vector2(0, 4)
		col.add_child(gap)
	_add(_selector(tr("OT_LENGTH") % [tr("OT_LEN_" + _length().to_upper()), 9 * Overtime.per_sector(_length())], func(d: int):
		length_i = (length_i + d + Overtime.LENGTH_ORDER.size()) % Overtime.LENGTH_ORDER.size()), "length", "OT_LENGTH_D")
	_add(MenuKit.button(tr("OT_SEED") % code, _open_osk), "seed", "OT_SEED_D")
	_add(MenuKit.button(tr("OT_SEED_NEW"), func():
		var rng := RandomNumberGenerator.new()
		rng.randomize()
		code = Overtime.random_code(rng)
		focus_name = "seed_new"
		_build()), "seed_new", "OT_SEED_D")
	var lics := _lics()
	license_i = clampi(license_i, 0, lics.size() - 1)
	var lic := String(lics[license_i])
	_add(_selector(tr("OT_LICENSE") % tr("OT_LIC_" + lic.to_upper()), func(d: int):
		license_i = (license_i + d + lics.size()) % lics.size()), "license", "OT_LIC_%s_D" % lic.to_upper())
	var smax := int(meta.get("stage_max", 0))
	if smax > 0:
		stage_n = clampi(stage_n, 0, smax)
		_add(_selector(tr("OT_STAGE") % stage_n if stage_n > 0 else tr("OT_STAGE_0"), func(d: int):
			stage_n = (stage_n + d + smax + 1) % (smax + 1)), "stage", "")
	var start_txt := tr("OT_START_SURE") if confirm == "start" else tr("OT_START")
	_add(MenuKit.button(start_txt, func():
		if not Flow.ot_saved().is_empty() and confirm != "start":
			confirm = "start"
			focus_name = "start"
			_build()
			return
		if not Flow.ot_saved().is_empty():
			Flow.ot_abandon()                  # neuer Lauf ersetzt den alten: der alte zählt wie aufgegeben
		meta["last"] = {"length": _length(), "license": lic}
		Flow.start_overtime(code, _length(), lic, stage_n)), "start", "OT_START_D")
	_add(MenuKit.button(tr("OT_BACK"), func(): get_tree().change_scene_to_file(Flow.MENU)), "back", "")
	# rechts: Beschreibung und Bestenliste
	var rp := Panel.new()
	rp.add_theme_stylebox_override("panel", MenuKit.panel_style(0.8))
	rp.position = Vector2(324, 52)
	rp.size = Vector2(300, 296)
	rp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(rp)
	side = VBoxContainer.new()
	side.position = Vector2(334, 58)
	side.size = Vector2(280, 284)
	side.add_theme_constant_override("separation", 3)
	stage.add_child(side)
	var lic_id := String(_lics()[license_i])
	var pv_row := HBoxContainer.new()                  # Taxi mit Lizenz-Streifen, Emblem und Start-Ausstattung der Lizenz
	pv_row.add_theme_constant_override("separation", 8)
	var pv := OvertimeLook.Preview.new()
	pv.license = lic_id
	pv.perks = (Overtime.license(lic_id).get("perks", {}) as Dictionary).duplicate()
	pv.custom_minimum_size = Vector2(120, 62)
	pv_row.add_child(pv)
	var lic_box := VBoxContainer.new()
	lic_box.add_child(_small(tr("OT_LICENSE") % tr("OT_LIC_" + lic_id.to_upper()), Color("#ffe14a")))
	var ld := _small(tr("OT_LIC_%s_D" % lic_id.to_upper()), Color("#c4d0ff"))
	ld.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ld.custom_minimum_size = Vector2(150, 0)
	lic_box.add_child(ld)
	pv_row.add_child(lic_box)
	side.add_child(pv_row)
	desc = Label.new()
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.custom_minimum_size = Vector2(280, 64)
	desc.add_theme_font_size_override("font_size", 8)
	desc.add_theme_color_override("font_color", Color("#c4d0ff"))
	side.add_child(desc)
	var bt := MenuKit.title(tr("OT_BOARD") % tr("OT_LEN_" + _length().to_upper()), 11)
	side.add_child(bt)
	board_box = VBoxContainer.new()
	board_box.add_theme_constant_override("separation", 1)
	side.add_child(board_box)
	_fill_board()
	var first := focus_name if focus_name != "" else ("resume" if not saved.is_empty() else "start")
	_focus.call_deferred(first)

func _fill_board() -> void:
	var meta := Flow.ot_meta()
	var board: Array = (meta.get("best", {}) as Dictionary).get(_length(), []) if meta.get("best") is Dictionary else []
	if board.is_empty():
		board_box.add_child(_small(tr("OT_BOARD_EMPTY"), Color("#7d89c4")))
	for i in board.size():
		var e: Dictionary = board[i]
		var mark := "✓" if bool(e.get("won", false)) else "%d/%d" % [int(e.get("flown", 0)), int(e.get("of", 0))]
		var extra := tr("OT_LIC_" + String(e.get("license", "standard")).to_upper())
		if int(e.get("stage", 0)) > 0:
			extra += " · " + tr("OT_STAGE_SHORT") % int(e.stage)
		var who := String(e.get("name", ""))
		board_box.add_child(_small("%2d.  %s  %s  %s  %s%s" % [i + 1, _pts(int(e.score)), who if who != "" else "–", String(e.get("code", "")), mark, "  " + extra], Color("#ffe14a") if i == 0 else Color("#e6ecff")))

static func _pts(n: int) -> String:
	var s := str(n)
	var out := ""
	while s.length() > 3:
		out = Overtime.thousands_sep() + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return (s + out).lpad(7)

func _small(text: String, c: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 8)
	l.add_theme_color_override("font_color", c)
	return l

func _add(b: Button, n: String, desc_key: String) -> void:
	b.name = n
	b.add_theme_font_size_override("font_size", 9)
	b.custom_minimum_size = Vector2(280, 22)
	b.focus_entered.connect(func():
		focus_name = n
		if desc != null:
			desc.text = _describe(n, desc_key))
	col.add_child(b)

func _describe(n: String, key: String) -> String:
	if n == "start":
		var r := Overtime.rank_of(int(Flow.ot_meta().get("xp", 0)))
		var probe := Overtime.new_run(0, _length(), String(_lics()[license_i]), stage_n, Flow.ot_meta())
		return tr("OT_START_D") % [int(probe.lives), Overtime.start_capital(r)]
	if n == "stage":
		if stage_n == 0:
			return tr("OT_STAGE_0_D")
		var lines: Array = [tr("OT_STAGE_D") % int(round(Overtime.STAGE_STEP * 100.0 * stage_n))]
		for i in stage_n:
			lines.append("· " + tr("OT_STAGE_%d" % (i + 1)))
		return "\n".join(lines)
	if n == "license":
		var lic := String(_lics()[license_i])
		var t := tr("OT_LIC_%s_D" % lic.to_upper())
		var locked: Array = Overtime.licenses().filter(func(l): return int(l.get("rank", 0)) > Overtime.rank_of(int(Flow.ot_meta().get("xp", 0))))
		if not locked.is_empty():
			t += "\n" + tr("OT_LIC_LOCKED") % int(locked[0].rank)
		return t
	return tr(key) if key != "" else ""

## Auswahlzeile: Links/Rechts wechselt, A/Klick geht einen Schritt weiter.
func _selector(text: String, change: Callable) -> Button:
	var b := MenuKit.button("‹  " + text + "  ›", func():
		change.call(1)
		_build())
	b.gui_input.connect(func(ev: InputEvent):
		if ev.is_action_pressed("ui_left") or ev.is_action_pressed("ui_right"):
			b.accept_event()
			change.call(-1 if ev.is_action_pressed("ui_left") else 1)
			_build())
	return b

func _focus(n: String) -> void:
	var b := col.find_child(n, true, false) as Button
	if b == null and col.get_child_count() > 0:
		b = col.get_child(0) as Button
	if b != null:
		b.grab_focus()

func _open_osk() -> void:
	if osk != null:
		return
	osk = Osk.new()
	osk.text = code
	osk.max_len = Overtime.CODE_LEN
	osk.title_text = tr("OT_SEED_PROMPT")
	osk.finished.connect(func(t: String, accepted: bool):
		if osk != null:
			osk.queue_free()
			osk = null
		if accepted:
			if Overtime.seed_of(t) >= 0:
				code = Overtime.code_of(Overtime.seed_of(t))
			else:
				Sfx.play("warn", -6.0)
		focus_name = "seed"
		_build())
	add_child(osk)

func _unhandled_input(event: InputEvent) -> void:
	if osk != null:
		return
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		if confirm != "":
			confirm = ""
			_build()
		else:
			get_tree().change_scene_to_file(Flow.MENU)
