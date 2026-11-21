class_name OvertimeKit
extends RefCounted
## Übersicht der Sonderschicht: Lizenz, eingebaute Ausstattung (mit Stufen), Zwischenfälle der laufenden Etappe und Pakte (mit Beschreibung)
## und die Wirkung insgesamt in Zahlen (Schub, Verbrauch, Landegrenzen, Fahrpreis …) – damit nichts verborgen wirkt.
## `panel()` liefert den Inhalt (Pausenmenü: rechte Hälfte), `make()` dieselbe Tafel als eigenes Fenster mit „Zurück“ (Kreuzung).

const Stage := preload("res://src/core/stage.gd")

## Wirkungen in der Übersicht: Schlüssel, Art der Anzeige (pct = Faktor als ±%, add = Zuschlag mit Einheit, deg = Grad, x = Faktor ×n)
const SUMMARY := [["thrust_k", "pct"], ["side_k", "pct"], ["down_k", "pct"], ["drag_k", "pct"], ["gear_time_k", "x"], ["jet_lag", "on"], ["overheat", "on"],
	["burn", "pct"], ["leak", "add"], ["fuel_cap", "pct"], ["fuel_price_k", "pct"], ["refuel_k", "pct"],
	["damage", "pct"], ["impact_safe", "add"], ["heat_k", "pct"], ["mover_k", "pct"], ["heavy_k", "pct"],
	["land_vy", "add"], ["land_vx", "add"], ["land_tilt", "deg"], ["soft_add", "add"], ["pen_k", "pct"],
	["fare_k", "pct"], ["tip_k", "pct"], ["tip_add", "add"], ["patience_k", "pct"], ["deadline_k", "pct"], ["walk_k", "pct"], ["missed_k", "pct"], ["combo_k", "x"], ["tmax", "addf"],
	["repair_k", "pct"], ["taxi_fee_k", "pct"]]

static func _t(k: String) -> String:
	return TranslationServer.translate(k)

static func _num(x: float, dec := 0) -> String:
	var s := ("%." + str(dec) + "f") % x
	return s.replace(".", ",") if TranslationServer.get_locale().substr(0, 2) != "en" else s

## Zeilen „Bezeichnung: Wert“ für alle Wirkungen, die vom Serientaxi abweichen.
static func summary_lines(fx: Dictionary) -> Array:
	var out: Array = []
	for e in SUMMARY:
		var k := String(e[0])
		if not fx.has(k) or not Overtime.FX.has(k):
			continue
		var v := float(fx[k])
		var base := float(Overtime.FX[k][0])
		if is_equal_approx(v, base):
			continue
		var txt := ""
		match String(e[1]):
			"pct":
				txt = ("+" if v > base else "−") + _num(absf(v - base) * 100.0) + " %"
			"x":
				txt = "×" + _num(v, 1)
			"add":
				txt = ("+" if v > 0.0 else "−") + _num(absf(v), 2 if absf(v) < 1.0 else 0)
			"addf":
				txt = "+" + _num(v, 1)
			"deg":
				txt = "+" + _num(rad_to_deg(v), 1) + "°"
			"on":
				txt = _t("OT_FX_ON")
		out.append([_t("OT_FX_" + k.to_upper()), txt, v > base if String(e[1]) != "on" else false, k])
	return out

## Inhalt der Übersicht in `box` (Breite `w`).
static func fill(box: VBoxContainer, st: Dictionary, w: float) -> void:
	var lic := String(st.get("license", "standard"))
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 6)
	var pv := OvertimeLook.Preview.new()
	pv.license = lic
	pv.perks = (st.get("perks", {}) as Dictionary).duplicate()
	pv.custom_minimum_size = Vector2(78, 48)
	head.add_child(pv)
	var hv := VBoxContainer.new()
	hv.add_theme_constant_override("separation", 1)
	hv.add_child(_lbl(_t("OT_LICENSE_LINE") % _t("OT_LIC_%s" % lic.to_upper()), 9, Color("#ffe14a")))
	var ld := _lbl(_t("OT_LIC_%s_D" % lic.to_upper()), 7, Color("#a9b8ff"))
	ld.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ld.custom_minimum_size = Vector2(w - 90.0, 0)
	hv.add_child(ld)
	head.add_child(hv)
	box.add_child(head)
	# Zwischenfälle der Etappe und Pakte, mit Beschreibung
	var cs: Array = []
	if String(st.get("phase", "")) == "fly":
		for c in st.get("curses", []):
			if not (st.get("pacts", []) as Array).has(c):
				cs.append([String(c), false])
	for c in st.get("pacts", []):
		cs.append([String(c), true])
	box.add_child(_lbl(_t("OT_KIT_CURSES"), 9, Color("#ff9a7a")))
	if cs.is_empty():
		box.add_child(_lbl("  " + _t("OT_NO_CURSE"), 8, Color("#7dff9a")))
	for e in cs:
		var cid := String(e[0])
		var l := _lbl(("∞ " if e[1] else "• ") + _t("OT_CURSE_%s" % cid.to_upper()) + ": " + _t("OT_CURSE_%s_D" % cid.to_upper()), 7, Color("#c77dff") if e[1] else Color("#ffb3a8"))
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(w, 0)
		box.add_child(l)
	# Ausstattung (Name und Stufe)
	box.add_child(_lbl(_t("OT_KIT_TITLE"), 9, Color("#5ab8ff")))
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 1)
	var ids: Array = (st.get("perks", {}) as Dictionary).keys()
	ids.sort_custom(func(a, b): return OvertimeLook._order(String(a)) < OvertimeLook._order(String(b)))
	if ids.is_empty():
		box.add_child(_lbl("  " + _t("OT_KIT_NONE"), 8, Color("#a9b8ff")))
	for id in ids:
		var p := Overtime.perk(String(id))
		var name := _t("OT_PERK_%s" % String(id).to_upper())
		if int(p.get("max", 1)) > 1 and int(p.get("max", 1)) < 9:
			name += " %d/%d" % [int(st.perks[id]), int(p.max)]
		grid.add_child(_line(String(p.get("cat", "run")), String(p.get("rar", "c")), name, OvertimeIcon.RAR_COLOR.get(String(p.get("rar", "c")), Color.WHITE), (w - 8.0) / 3.0))
	box.add_child(grid)
	# Wirkung insgesamt
	var lines := summary_lines(Overtime.effects(st))
	box.add_child(_lbl(_t("OT_KIT_TOTAL"), 9, Color("#ffe14a")))
	if lines.is_empty():
		box.add_child(_lbl("  " + _t("OT_KIT_STOCK"), 8, Color("#a9b8ff")))
	var sg := GridContainer.new()
	sg.columns = 2
	sg.add_theme_constant_override("h_separation", 10)
	sg.add_theme_constant_override("v_separation", 0)
	for ln in lines:
		var row := HBoxContainer.new()
		row.custom_minimum_size = Vector2((w - 10.0) / 2.0, 0)
		var a := _lbl(String(ln[0]), 7, Color("#c4d0ff"))
		a.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		a.clip_text = true
		row.add_child(a)
		row.add_child(_lbl(String(ln[1]), 7, Color("#e6ecff")))
		sg.add_child(row)
	box.add_child(sg)

static func _lbl(text: String, fs: int, col: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", col)
	return l

## Tafel für das Pausenmenü (rechte Hälfte).
static func panel(st: Dictionary, sz: Vector2) -> PanelContainer:
	var pc := PanelContainer.new()
	var sb := MenuKit.panel_style(0.9)
	sb.set_content_margin_all(8)
	pc.add_theme_stylebox_override("panel", sb)
	pc.custom_minimum_size = sz
	pc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	pc.add_child(v)
	v.add_child(_lbl(_t("OT_TAG") % [mini(int(st.get("etappe", 0)) + 1, Overtime.total(st)), Overtime.total(st)] + "  ·  " + _t("OT_TAXIS") % int(st.get("lives", 0)) + "  ·  " + _t("OT_TOKENS") % int(st.get("tokens", 0)), 9, Color("#e6ecff")))
	fill(v, st, sz.x - 16.0)
	return pc

static func make(st: Dictionary, close: Callable) -> Control:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	root.theme = MenuKit.make_theme()
	root.add_child(MenuKit.dim_rect(0.8))
	var stage := Stage.make(root)
	var p := panel(st, Vector2(560, 300))
	p.position = Vector2(40, 14)
	stage.add_child(p)
	var b := MenuKit.button(_t("OT_BACK"), close)
	b.position = Vector2(270, 322)
	b.size = Vector2(100, 22)
	stage.add_child(b)
	b.grab_focus.call_deferred()
	return root

static func _line(cat: String, rar: String, text: String, col: Color, w: float) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.custom_minimum_size = Vector2(w, 11)
	h.add_theme_constant_override("separation", 3)
	var ic := OvertimeIcon.new()
	ic.kind = "perk"
	ic.cat = cat
	ic.rar = rar
	ic.custom_minimum_size = Vector2(10, 10)
	h.add_child(ic)
	var l := _lbl(text, 7, col)
	l.clip_text = true
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(l)
	return h
