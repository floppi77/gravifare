extends Control
## Schlusswertung der Sonderschicht: alle Posten der Punktzahl (Etappen, übrige Taxis, Abschlussbonus, Überstunden-Stufe), die Etappen als Balken
## (Farbe nach Zahl der Zwischenfälle), Erfahrung und Dienstgrad, neu freigeschaltete Teile, Lizenzen und Stufen sowie der Platz in der Bestenliste.
## A/Enter/B: zurück ins Menü der Sonderschicht.

const Stage := preload("res://src/core/stage.gd")

var st: Dictionary = {}
var rec: Dictionary = {}
var f: Dictionary = {}
var t := 0.0
var bg: Texture2D

func _ready() -> void:
	Music.play_theme("menu")
	Music.duck(0.0)
	theme = MenuKit.make_theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	st = Flow.ot_last.get("state", {})
	rec = Flow.ot_last.get("rec", {})
	f = rec.get("final", Overtime.final(st) if not st.is_empty() else {})
	bg = load("res://assets/art/bg_s%d.png" % clampi(Overtime.sector_of(st, maxi(0, int(st.get("etappe", 1)) - 1)) if not st.is_empty() else 9, 1, 9))
	var stage := Stage.make(self)
	if st.is_empty():
		var l := MenuKit.title(tr("OT_TITLE"), 16)
		l.position = Vector2(0, 160)
		l.size = Vector2(640, 20)
		stage.add_child(l)
		return
	var won := bool(f.get("won", false))
	var head := MenuKit.screen_title(tr("OT_FIN_WON") if won else tr("OT_FIN_OVER"), 22)
	head.position = Vector2(0, 8)
	head.size = Vector2(640, 28)
	stage.add_child(head)
	var sub := Label.new()
	sub.text = tr("OT_FIN_SUB") % [tr("OT_LEN_" + String(st.length).to_upper()), String(st.code), tr("OT_LIC_" + String(st.license).to_upper())] + (("  ·  " + tr("OT_STAGE_SHORT") % int(st.stage)) if int(st.stage) > 0 else "")
	sub.position = Vector2(0, 36)
	sub.size = Vector2(640, 12)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 8)
	sub.add_theme_color_override("font_color", Color("#c4d0ff"))
	stage.add_child(sub)
	# links: Abrechnung
	var lp := Panel.new()
	lp.add_theme_stylebox_override("panel", MenuKit.panel_style(0.85))
	lp.position = Vector2(16, 54)
	lp.size = Vector2(300, 260)
	lp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(lp)
	var g := GridContainer.new()
	g.columns = 2
	g.position = Vector2(28, 62)
	g.size = Vector2(276, 120)
	g.add_theme_constant_override("h_separation", 10)
	g.add_theme_constant_override("v_separation", 3)
	stage.add_child(g)
	_row(g, tr("OT_FIN_ETAPPEN") % [int(f.flown), int(f.of)], _pts(int(f.etappen)))
	_row(g, tr("OT_FIN_TAXIS") % [int(f.taxis), Overtime.TAXI_POINTS], "+ " + _pts(int(f.taxi_points)))
	_row(g, tr("OT_FIN_FINISH") % int(round(Overtime.FINISH_BONUS * 100.0)), "+ " + _pts(int(f.finish)))
	if int(f.stage) > 0:
		_row(g, tr("OT_FIN_STAGE") % int(f.stage), "× " + ("%.1f" % float(f.stage_k)).replace(".", ","))
	_row(g, tr("OT_FIN_TOTAL"), _pts(int(f.total)), Color("#ffe14a"), 12)
	var chart := Chart.new()
	chart.results = st.get("results", [])
	chart.of = int(f.of)
	chart.position = Vector2(28, 188)
	chart.size = Vector2(276, 92)
	stage.add_child(chart)
	var leg := Label.new()
	leg.text = tr("OT_FIN_CHART")
	leg.position = Vector2(28, 284)
	leg.size = Vector2(276, 24)
	leg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	leg.add_theme_font_size_override("font_size", 7)
	leg.add_theme_color_override("font_color", Color("#7d89c4"))
	stage.add_child(leg)
	# rechts: Dienstgrad, Freischaltungen, Bestenliste
	var rp := Panel.new()
	rp.add_theme_stylebox_override("panel", MenuKit.panel_style(0.85))
	rp.position = Vector2(324, 54)
	rp.size = Vector2(300, 260)
	rp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(rp)
	var v := VBoxContainer.new()
	v.position = Vector2(336, 62)
	v.size = Vector2(276, 244)
	v.add_theme_constant_override("separation", 4)
	stage.add_child(v)
	v.add_child(_lbl(tr("OT_FIN_XP") % int(f.xp), 10, Color("#ffe14a")))
	var r0 := int(rec.get("rank_before", 0))
	var r1 := int(rec.get("rank", r0))
	v.add_child(_lbl(tr("OT_FIN_RANK_UP") % r1 if r1 > r0 else tr("OT_RANK") % r1, 10, Color("#7dff9a") if r1 > r0 else Color("#e6ecff")))
	var news: Array = []
	for r in range(r0 + 1, r1 + 1):
		for u in Overtime.unlocks_at(r):
			var parts := String(u).split(":")
			news.append(tr("OT_PERK_%s" % parts[1].to_upper()) if parts[0] == "perk" else tr("OT_LIC_%s" % parts[1].to_upper()) + " (" + tr("OT_LICENSE_WORD") + ")")
	if int(rec.get("stage_unlocked", -1)) > 0:
		news.append(tr("OT_FIN_STAGE_NEW") % int(rec.stage_unlocked))
	if not news.is_empty():
		v.add_child(_lbl(tr("OT_FIN_NEW"), 9, Color("#5ab8ff")))
		var nl := _lbl(", ".join(news), 8, Color("#c4d0ff"))
		nl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		nl.custom_minimum_size = Vector2(276, 0)
		v.add_child(nl)
	var place := int(rec.get("place", 0))
	v.add_child(_lbl(tr("OT_FIN_PLACE") % [place, tr("OT_LEN_" + String(st.length).to_upper())] if place > 0 else tr("OT_FIN_NOPLACE"), 9, Color("#ffe14a") if place == 1 else Color("#e6ecff")))
	var b := MenuKit.button(tr("OT_FIN_CONTINUE"), _leave)
	b.position = Vector2(250, 322)
	b.size = Vector2(140, 24)
	stage.add_child(b)
	b.grab_focus.call_deferred()

class Chart extends Control:
	var results: Array = []
	var of := 9
	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.03, 0.04, 0.12, 0.8))
		var top := 1
		for r in results:
			top = maxi(top, int(r.get("score", 0)))
		var n := maxi(of, 1)
		var w := floorf((size.x - 4.0) / float(n))
		for i in n:
			var x := 2.0 + float(i) * w
			if i >= results.size():
				draw_rect(Rect2(x + 1.0, size.y - 4.0, w - 2.0, 2.0), Color("#232a52"))
				continue
			var r: Dictionary = results[i]
			var h := maxf(2.0, (size.y - 8.0) * float(r.get("score", 0)) / float(top))
			var nc := (r.get("curses", []) as Array).size()
			var c: Color = [Color("#7dff9a"), Color("#ffcb3d"), Color("#ff6a5a"), Color("#c77dff")][mini(nc, 3)]
			draw_rect(Rect2(x + 1.0, size.y - 2.0 - h, w - 2.0, h), c)
			draw_rect(Rect2(x + 1.0, size.y - 2.0 - h, w - 2.0, 1.0), c.lightened(0.4))

func _row(g: GridContainer, a: String, b: String, c := Color("#e6ecff"), fs := 9) -> void:
	var l := _lbl(a, fs, c)
	l.custom_minimum_size = Vector2(190, 0)
	g.add_child(l)
	var r := _lbl(b, fs, c)
	r.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	r.custom_minimum_size = Vector2(76, 0)
	g.add_child(r)

func _lbl(text: String, fs: int, c: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", c)
	return l

static func _pts(n: int) -> String:
	var s := str(absi(n))
	var out := ""
	while s.length() > 3:
		out = Overtime.thousands_sep() + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return ("-" if n < 0 else "") + s + out

func _leave() -> void:
	get_tree().change_scene_to_file(Flow.OT_MENU)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		_leave()

func _process(d: float) -> void:
	t += d
	queue_redraw()

func _draw() -> void:
	var v := size
	if bg != null:
		var ts := bg.get_size()
		var k := maxf(v.x / ts.x, v.y / ts.y)
		draw_texture_rect(bg, Rect2((v - ts * k) * 0.5, ts * k), false, Color(0.55, 0.58, 0.75))
	draw_rect(Rect2(Vector2.ZERO, v), Color(0.02, 0.03, 0.1, 0.55))
