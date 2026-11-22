class_name OvertimeCross
extends Control
## Kreuzung der Sonderschicht: Die Zentrale bietet drei Aufträge an (mit Funkscanner vier). Jede Karte zeigt Level, Zwischenfälle, Lohn,
## Wertungsfaktor und Prämie bzw. Pakt; darunter die Beschreibung des fokussierten Auftrags. Wahl mit A/Enter oder Klick, Neu würfeln mit einer
## Marke, Schmiergeld streicht (mit der passenden Ausstattung) einen Zwischenfall. Esc/Start: zurück ins Menü – der Lauf bleibt gespeichert.

const Stage := preload("res://src/core/stage.gd")

var st: Dictionary = {}
var on_pick: Callable                   # func(offer: Dictionary)
var on_change: Callable                 # Zustand sichern (Neu würfeln, Schmiergeld)
var on_pause: Callable                  # Esc/Start
var offers: Array = []
var stage_c: Control
var cards: Array = []                   # Buttons
var desc: Label
var info: Label
var picked := false
var show_kit := false
var kit_panel: Control
var _stars: Array = []
var t := 0.0
var last_focus := 0

const COL_CALM := Color("#7dff9a")
const COL_MID := Color("#ffcb3d")
const COL_RISK := Color("#ff6a5a")
const COL_PACT := Color("#c77dff")

func _ready() -> void:
	theme = MenuKit.make_theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var rng := RandomNumberGenerator.new()
	rng.seed = 87
	for i in 140:
		_stars.append([Vector2(rng.randf(), rng.randf()), rng.randf_range(0.3, 1.0), rng.randf_range(4.0, 22.0)])
	stage_c = Stage.make(self)
	_build()

func _ids() -> Array:
	var ids: Array = []
	for f in DirAccess.get_files_at("res://data/levels"):
		if f.ends_with(".json"):
			ids.append(f.get_basename())
	ids.sort()
	return ids

func _build(focus := 0) -> void:
	for c in stage_c.get_children():
		stage_c.remove_child(c)
		c.queue_free()
	cards.clear()
	offers = Overtime.offers(st, _ids())
	var e := int(st.etappe)
	var sector := Overtime.sector_of(st, e)
	var look: Dictionary = SectorLook.of(sector)
	var head := Label.new()
	head.text = tr("OT_CROSS_TITLE") % [e + 1, Overtime.total(st)]
	head.position = Vector2(0, 8)
	head.size = Vector2(640, 20)
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	head.add_theme_font_size_override("font_size", 16)
	head.add_theme_color_override("font_outline_color", Color("#0c0f24"))
	head.add_theme_constant_override("outline_size", 4)
	stage_c.add_child(head)
	var sub := Label.new()
	sub.text = tr("TRANS_SECTOR") % [sector, tr("SECTOR_%d" % sector)]
	sub.position = Vector2(0, 28)
	sub.size = Vector2(640, 12)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 9)
	sub.add_theme_color_override("font_color", (look.edge as Color).lightened(0.3))
	stage_c.add_child(sub)
	info = Label.new()
	info.position = Vector2(20, 42)
	info.size = Vector2(600, 12)
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info.add_theme_font_size_override("font_size", 8)
	info.add_theme_color_override("font_color", Color("#c4d0ff"))
	info.text = _status_text()
	stage_c.add_child(info)
	var n := offers.size()
	var gap := 8.0
	var w := (600.0 - gap * float(n - 1)) / float(maxi(n, 1))
	for i in n:
		var b := _card(i, offers[i], Rect2(20.0 + float(i) * (w + gap), 58, w, 190))
		cards.append(b)
		stage_c.add_child(b)
	for i in n:
		var b: Button = cards[i]
		b.focus_neighbor_left = cards[(i - 1 + n) % n].get_path()
		b.focus_neighbor_right = cards[(i + 1) % n].get_path()
	desc = Label.new()
	desc.position = Vector2(24, 252)
	desc.size = Vector2(592, 66)
	desc.clip_text = true
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.add_theme_font_size_override("font_size", 8)
	desc.add_theme_color_override("font_color", Color("#a9b8ff"))
	stage_c.add_child(desc)
	var row := HBoxContainer.new()
	row.position = Vector2(20, 322)
	row.size = Vector2(600, 24)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 8)
	stage_c.add_child(row)
	var rr := MenuKit.button(tr("OT_CROSS_REROLL") % int(st.tokens), func():
		if Overtime.reroll_cross(st):
			Sfx.play("coin")
			_changed()
			_build(_focused())
		else:
			Sfx.play("warn", -6.0))
	rr.name = "reroll"
	rr.disabled = int(st.tokens) <= 0
	rr.add_theme_font_size_override("font_size", 8)
	row.add_child(rr)
	if float(Overtime.effects(st).bribe) > 0.0:
		var bb := MenuKit.button(tr("OT_CROSS_BRIBE") % Overtime.bribe_price(st), func():
			var i := _focused()
			if i < 0:
				i = last_focus
			if Overtime.bribe(st, _ids(), i, 0):
				Sfx.play("coin")
				_changed()
				_build(i)
			else:
				Sfx.play("warn", -6.0))
		bb.name = "bribe"
		bb.disabled = int(st.bribed) == int(st.etappe)
		bb.add_theme_font_size_override("font_size", 8)
		row.add_child(bb)
	var kit := MenuKit.button(tr("OT_CROSS_KIT"), _toggle_kit)
	kit.name = "kit"
	kit.add_theme_font_size_override("font_size", 8)
	row.add_child(kit)
	var hint := Label.new()
	hint.text = tr("OT_CROSS_HINT")
	hint.position = Vector2(0, 347)
	hint.size = Vector2(640, 10)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 6)
	hint.add_theme_color_override("font_color", Color("#6f7bb5"))
	stage_c.add_child(hint)
	for c in row.get_children():
		(c as Control).focus_neighbor_top = cards[0].get_path() if not cards.is_empty() else NodePath()
	for b in cards:
		(b as Control).focus_neighbor_bottom = row.get_child(0).get_path()
	_focus_card.call_deferred(clampi(focus, 0, maxi(0, n - 1)))

func _status_text() -> String:
	var parts: Array = ["¢ %d" % int(st.credits), tr("OT_TAXIS") % int(st.lives)]
	if int(st.tokens) > 0:
		parts.append(tr("OT_TOKENS") % int(st.tokens))
	var kit_n := 0
	for k in st.perks:
		kit_n += int(st.perks[k])
	parts.append(tr("OT_KIT_N") % kit_n)
	if not (st.pacts as Array).is_empty():
		parts.append(tr("OT_PACTS") % ", ".join((st.pacts as Array).map(func(p): return tr("OT_CURSE_%s" % String(p).to_upper()))))
	var e := int(st.etappe)
	for n in st.get("log", []):                       # was seit der letzten Kreuzung geschah: Gehalt, Steuer, Zinsen, Prämie
		if int(n.get("etappe", -9)) < e - 1 or String(n.get("what", "")) == "buy":
			continue
		match String(n.what):
			"salary":
				parts.append(tr("OT_NOTE_SALARY") % int(n.amount))
			"audit":
				parts.append(tr("OT_NOTE_AUDIT") % int(n.amount))
			"interest":
				parts.append(tr("OT_NOTE_INTEREST") % int(n.amount))
			"reward":
				parts.append(tr("OT_NOTE_REWARD") % tr("OT_PERK_%s" % String(n.item).to_upper()))
			"zulage":
				parts.append(tr("OT_NOTE_ZULAGE") % int(n.amount))
			"reward_cash":
				parts.append(tr("OT_NOTE_REWARD_CASH") % int(n.amount))
	return "  ·  ".join(parts)

func _tier(i: int, o: Dictionary) -> Array:
	if String(o.get("pact", "")) != "":
		return [tr("OT_TIER_PACT"), COL_PACT]
	var n: int = (o.curses as Array).size()
	if n == 0:
		return [tr("OT_TIER_CALM"), COL_CALM]
	if n == 1 and i <= 1:
		return [tr("OT_TIER_MID"), COL_MID]
	return [tr("OT_TIER_RISK"), COL_RISK]

func _card(i: int, o: Dictionary, r: Rect2) -> Button:
	var lang := TranslationServer.get_locale().substr(0, 2)
	var lvl := LevelData.load_file("res://data/levels/%s.json" % String(o.level))
	var tier := _tier(i, o)
	var col: Color = tier[1]
	var b := Button.new()
	b.position = r.position
	b.size = r.size
	b.focus_mode = Control.FOCUS_ALL
	b.clip_contents = true
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.06, 0.16, 0.93)
	sb.border_color = Color(col, 0.5)
	sb.set_border_width_all(1)
	sb.border_width_top = 3
	sb.set_corner_radius_all(4)
	var sf := sb.duplicate() as StyleBoxFlat
	sf.border_color = col
	sf.set_border_width_all(2)
	sf.border_width_top = 4
	sf.bg_color = Color(0.09, 0.1, 0.24, 0.97)
	b.add_theme_stylebox_override("normal", sb)
	b.add_theme_stylebox_override("hover", sb)          # nur der Fokus leuchtet: ein ruhender Mauszeiger ließe sonst eine zweite Karte hell stehen
	b.add_theme_stylebox_override("focus", sf)
	b.add_theme_stylebox_override("pressed", sf)
	var v := VBoxContainer.new()
	v.position = Vector2(8, 6)
	v.size = r.size - Vector2(16, 12)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_theme_constant_override("separation", 2)
	b.add_child(v)
	var tg := _lbl(tier[0], 8, col)
	v.add_child(tg)
	var nm := _lbl(tr("TRANS_LEVEL") % [lvl.number if lvl != null else 0, lvl.display_name(lang) if lvl != null else String(o.level)], 10, Color.WHITE)
	nm.clip_text = true                                    # einzeilig, lange Namen mit „…“ (sonst rutscht unten die Prämie aus der Karte)
	nm.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	nm.custom_minimum_size = Vector2(r.size.x - 16.0, 0)
	v.add_child(nm)
	var shot := "res://assets/art/levels/%s.jpg" % String(o.level)
	var pic := Control.new()                                 # Vorschaubild in fester Größe (alle Karten gleich), sonst der gezeichnete Grundriss
	var cs: Array = (o.curses as Array).duplicate()
	if String(o.get("pact", "")) != "":
		cs.append(String(o.pact))
	var n := Overtime.offer_curse_count(st, o)
	var rows := maxi(1, cs.size()) + (1 if n > 0 else 0) + 1 + (1 if String(o.get("reward", "")) != "" else 0)
	pic.custom_minimum_size = Vector2(0, clampf(174.0 - 17.0 * float(1 + rows) - 24.0, 26.0, 50.0))   # bei drei Zwischenfällen wird das Bild flacher, damit die Prämie in der Karte bleibt
	pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(pic)
	if ResourceLoader.exists(shot):
		var tr_img := TextureRect.new()
		tr_img.texture = load(shot)
		tr_img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr_img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr_img.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		tr_img.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tr_img.set_anchors_preset(Control.PRESET_FULL_RECT)
		pic.add_child(tr_img)
	elif lvl != null:
		var mm := MiniMap.new()
		mm.lvl = lvl
		mm.edge = (SectorLook.of(lvl.sector).edge as Color)
		mm.mouse_filter = Control.MOUSE_FILTER_IGNORE
		mm.set_anchors_preset(Control.PRESET_FULL_RECT)
		pic.add_child(mm)
	if cs.is_empty():
		v.add_child(_lbl(tr("OT_NO_CURSE"), 8, COL_CALM))
	for c in cs:
		var h := HBoxContainer.new()
		h.mouse_filter = Control.MOUSE_FILTER_IGNORE
		h.add_theme_constant_override("separation", 4)
		var ic := OvertimeIcon.new()
		ic.kind = "curse"
		ic.cat = String(Overtime.curse(String(c)).get("kind", "sim"))
		ic.custom_minimum_size = Vector2(12, 12)
		ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		h.add_child(ic)
		var cl := _lbl(tr("OT_CURSE_%s" % String(c).to_upper()) + ("  ∞" if c == String(o.get("pact", "")) else ""), 8, COL_PACT if c == String(o.get("pact", "")) else Color("#ffb3a8"))
		h.add_child(cl)
		v.add_child(h)
	var fill := Control.new()
	fill.size_flags_vertical = Control.SIZE_EXPAND_FILL
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(fill)
	if n > 0:
		v.add_child(_lbl(tr("OT_PAY_UP") % int(o.get("zulage", Overtime.zulage(st, n))), 8, Color("#ffe14a")))
	v.add_child(_lbl(tr("OT_SCORE_K") % _num(1.0 + Overtime.RISK_PER_CURSE * n), 8, Color("#c4d0ff")))
	if String(o.get("reward", "")) != "":
		var rk := "OT_REWARD_NOW" if String(o.get("pact", "")) != "" else "OT_REWARD"
		var rl := _lbl(tr(rk) % tr("OT_PERK_%s" % String(o.reward).to_upper()), 8, OvertimeIcon.RAR_COLOR.get(String(Overtime.perk(String(o.reward)).get("rar", "c")), Color.WHITE))
		rl.clip_text = true
		rl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		rl.custom_minimum_size = Vector2(r.size.x - 16.0, 0)
		v.add_child(rl)
	b.pressed.connect(func(): _pick(i))
	b.focus_entered.connect(func():
		last_focus = i
		_describe(i))
	b.mouse_entered.connect(func(): b.grab_focus())
	return b

func _num(x: float) -> String:
	var s := "%.2f" % x
	return s.replace(".", ",") if TranslationServer.get_locale().substr(0, 2) != "en" else s

func _lbl(text: String, fs: int, col: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", col)
	return l

func _describe(i: int) -> void:
	if desc == null or i < 0 or i >= offers.size():
		return
	var o: Dictionary = offers[i]
	var lines: Array = []
	for c in o.curses:
		lines.append(tr("OT_CURSE_%s" % String(c).to_upper()) + ": " + tr("OT_CURSE_%s_D" % String(c).to_upper()))
	if String(o.get("pact", "")) != "":
		lines.append(tr("OT_PACT_D") % tr("OT_CURSE_%s" % String(o.pact).to_upper()) + " " + tr("OT_CURSE_%s_D" % String(o.pact).to_upper()))
	if String(o.get("reward", "")) != "":
		lines.append(tr("OT_PERK_%s" % String(o.reward).to_upper()) + ": " + tr("OT_PERK_%s_D" % String(o.reward).to_upper()))
	if lines.is_empty():
		lines.append(tr("OT_CALM_D"))
	desc.text = "\n".join(lines)
	desc.add_theme_font_size_override("font_size", 8 if lines.size() <= 4 else 7)      # viele Zeilen: eine Stufe kleiner, damit nichts unter die Knöpfe rutscht
	desc.add_theme_constant_override("line_spacing", 0 if lines.size() > 4 else 1)

func _focused() -> int:
	var f := get_viewport().gui_get_focus_owner()
	return cards.find(f)

func _focus_card(i: int) -> void:
	if i >= 0 and i < cards.size() and is_instance_valid(cards[i]):
		(cards[i] as Button).grab_focus()
		_describe(i)

func _pick(i: int) -> void:
	if picked or show_kit:
		return
	picked = true
	Sfx.play("coin")
	if on_pick.is_valid():
		on_pick.call(offers[i])

func _changed() -> void:
	if on_change.is_valid():
		on_change.call()
	if info != null:
		info.text = _status_text()

func _toggle_kit() -> void:
	show_kit = not show_kit
	if kit_panel != null:
		kit_panel.queue_free()
		kit_panel = null
	if not show_kit:
		_focus_card.call_deferred(0)
		return
	kit_panel = OvertimeKit.make(st, func(): _toggle_kit())
	add_child(kit_panel)

func _unhandled_input(event: InputEvent) -> void:
	if picked:
		return
	if show_kit and (event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause")):
		get_viewport().set_input_as_handled()
		_toggle_kit()
	elif event.is_action_pressed("pause") or (event.is_action_pressed("ui_cancel") and not show_kit):
		get_viewport().set_input_as_handled()
		if on_pause.is_valid():
			on_pause.call()

func _process(d: float) -> void:
	t += d
	queue_redraw()

func _draw() -> void:
	var v := size
	draw_rect(Rect2(Vector2.ZERO, v), Color("#05060f"))
	for s in _stars:
		var p: Vector2 = s[0]
		var x := fmod(p.x * v.x - t * float(s[2]), v.x)
		if x < 0.0:
			x += v.x
		draw_rect(Rect2(x, p.y * v.y, 1.5, 1.5), Color(0.75, 0.82, 1.0, float(s[1]) * 0.7))

## Grundriss eines Levels im Pixelraster (eine Zelle = ganze Pixel): Fels in der Sektorfarbe, Plattformen hell, Tankstelle orange, Ausgang gelb, Dornen rot.
class MiniMap extends Control:
	var lvl: LevelData
	var edge := Color("#7f8fe0")
	func _draw() -> void:
		if lvl == null or lvl.width <= 0 or lvl.height <= 0:
			return
		var c := floorf(minf(size.x / float(lvl.width), size.y / float(lvl.height)) * 4.0) / 4.0
		c = maxf(c, 0.5)
		var off := ((size - Vector2(lvl.width, lvl.height) * c) * 0.5).floor()
		draw_rect(Rect2(off - Vector2(1, 1), Vector2(lvl.width, lvl.height) * c + Vector2(2, 2)), Color(0.02, 0.03, 0.08, 0.9))
		var rock := edge.darkened(0.35)
		for y in lvl.rows.size():
			var row := String(lvl.rows[y])
			var x0 := -1
			for x in row.length() + 1:
				var solid := x < row.length() and row[x] == "#"
				if solid and x0 < 0:
					x0 = x
				elif not solid and x0 >= 0:
					draw_rect(Rect2(off + Vector2(x0, y) * c, Vector2(x - x0, 1) * c), rock)
					x0 = -1
				if x < row.length() and row[x] == "^":
					draw_rect(Rect2(off + Vector2(x, y) * c, Vector2(c, c)), Color("#ff4d6d"))
		for id in lvl.pads:
			var p: Dictionary = lvl.pads[id]
			var col := Color("#ffa530") if bool(p.get("fuel", false)) else (Color("#ff6aa0") if bool(p.get("life", false)) else Color("#9ff7ee"))
			var x0p := float(p.x0) / float(Tuning.TILE)
			var x1p := float(p.x1) / float(Tuning.TILE)
			draw_rect(Rect2(off + Vector2(x0p, float(p.row) - 0.6) * c, Vector2(x1p - x0p, 0.6) * c), col)
		var er := lvl.exit_rect()
		draw_rect(Rect2(off + er.position / float(Tuning.TILE) * c, er.size / float(Tuning.TILE) * c), Color("#ffe14a"))
