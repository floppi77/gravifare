class_name OvertimeKit
extends RefCounted
## Übersicht der eingebauten Ausstattung und der Pakte (Kreuzung und Pausenmenü der Sonderschicht): Tafel über allem, B/Esc schließt.

const Stage := preload("res://src/core/stage.gd")

static func make(st: Dictionary, close: Callable) -> Control:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	root.theme = MenuKit.make_theme()
	root.add_child(MenuKit.dim_rect(0.75))
	var stage := Stage.make(root)
	var pb := Panel.new()
	pb.add_theme_stylebox_override("panel", MenuKit.panel_style(0.94))
	pb.position = Vector2(60, 24)
	pb.size = Vector2(520, 312)
	pb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(pb)
	var head := MenuKit.title(TranslationServer.translate("OT_KIT_TITLE"), 14)
	head.position = Vector2(60, 30)
	head.size = Vector2(520, 18)
	stage.add_child(head)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.position = Vector2(76, 54)
	grid.size = Vector2(488, 236)
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 2)
	stage.add_child(grid)
	var ids: Array = (st.get("perks", {}) as Dictionary).keys()
	ids.sort_custom(func(a, b): return _order(String(a)) < _order(String(b)))
	if ids.is_empty():
		grid.add_child(_line("", "", TranslationServer.translate("OT_KIT_NONE"), Color("#a9b8ff")))
	for id in ids:
		var p := Overtime.perk(String(id))
		var n := int(st.perks[id])
		var name := TranslationServer.translate("OT_PERK_%s" % String(id).to_upper())
		if int(p.get("max", 1)) > 1 and int(p.get("max", 1)) < 9:
			name += "  " + TranslationServer.translate("OT_STACK") % [n, int(p.max)]
		grid.add_child(_line(String(p.get("cat", "run")), String(p.get("rar", "c")), name, OvertimeIcon.RAR_COLOR.get(String(p.get("rar", "c")), Color.WHITE)))
	for c in st.get("curses", []):
		if String(st.get("phase", "")) == "fly" and not (st.get("pacts", []) as Array).has(c):
			grid.add_child(_line("", "", TranslationServer.translate("OT_CURSE_LINE") % TranslationServer.translate("OT_CURSE_%s" % String(c).to_upper()), Color("#ffb3a8"), String(Overtime.curse(String(c)).get("kind", "sim"))))
	for c in st.get("pacts", []):
		grid.add_child(_line("", "", TranslationServer.translate("OT_PACT_LINE") % TranslationServer.translate("OT_CURSE_%s" % String(c).to_upper()), Color("#c77dff"), String(Overtime.curse(String(c)).get("kind", "sim"))))
	var lic := Label.new()
	lic.text = TranslationServer.translate("OT_LICENSE_LINE") % TranslationServer.translate("OT_LIC_%s" % String(st.get("license", "standard")).to_upper())
	lic.position = Vector2(76, 292)
	lic.add_theme_font_size_override("font_size", 8)
	lic.add_theme_color_override("font_color", Color("#c4d0ff"))
	stage.add_child(lic)
	var b := MenuKit.button(TranslationServer.translate("OT_BACK"), close)
	b.position = Vector2(270, 306)
	b.size = Vector2(100, 22)
	stage.add_child(b)
	b.grab_focus.call_deferred()
	return root

static func _order(id: String) -> String:
	var cats := ["jets", "fuel", "hull", "land", "guest", "life", "run", "legend"]
	return "%02d%s" % [cats.find(String(Overtime.perk(id).get("cat", "run"))), id]

static func _line(cat: String, rar: String, text: String, col: Color, curse_kind := "") -> HBoxContainer:
	var h := HBoxContainer.new()
	h.custom_minimum_size = Vector2(156, 13)
	h.add_theme_constant_override("separation", 4)
	if cat != "" or curse_kind != "":
		var ic := OvertimeIcon.new()
		ic.kind = "curse" if curse_kind != "" else "perk"
		ic.cat = curse_kind if curse_kind != "" else cat
		ic.rar = rar
		ic.custom_minimum_size = Vector2(12, 12)
		h.add_child(ic)
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 8)
	l.add_theme_color_override("font_color", col)
	h.add_child(l)
	return h
