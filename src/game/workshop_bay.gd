class_name WorkshopBay
extends Control
## Werkstatt zwischen zwei Sektoren, im Farbschema des gerade beendeten Sektors: Das Taxi fliegt durch die Dachluke ein, setzt auf der Hebebühne auf und
## wird angehoben. Rechts stehen die verfügbaren Credits und die Einbauten als Karten (Symbol, Stufen, Wirkung jetzt › nächste Stufe, Preis rot, wenn zu
## teuer); das Taxi zeigt das fokussierte Teil. Die Halle hat Lochwand, Diagnosemonitor mit Ausbaustand und Ersatzteilregal.
## „Verlassen“ lässt es durch die Luke ausfliegen; danach folgt der Levelwechsel.

const Stage := preload("res://src/core/stage.gd")
enum S {IN, SHOP, OUT, FADE}
const FLY_IN := 1.5
const LIFT_UP := 0.7
const PANEL_T := 0.3
const FLY_OUT := 1.2
const FADE_T := 0.5
const TILE := 32.0
const FLOOR_Y := 316.0
const ROOF_Y := 32.0
const LIFT_X := 170.0
const LIFT_LOW := 298.0
const LIFT_HIGH := 232.0
const TAXI_H := 26.0                  # Abstand Rumpfmitte zur Bühne
const TW := 39.0                      # halbe Taxibreite: Bild 78×48 Hallen-Einheiten (3-fach wie im Spiel, Runde 62)
const TH := 24.0
const HATCH_W := 72.0

var sector := 1
var leave: Callable                   # wird aufgerufen, wenn das Taxi draußen ist
var wallet := 0.0                     # Credits des laufenden Flugs; Käufe ziehen hier ab
var state := S.IN
var t := 0.0
var taxi_pos := Vector2(LIFT_X, -40.0)
var lift_y := LIFT_LOW
var hatch := 1.0                      # 1 = Luke offen
var flame := 1.0
var panel: Control
var box: VBoxContainer
var look: Dictionary
var tiles: Texture2D
var taxi_tex: Texture2D
var sticker_tex: Texture2D
var ws_icons: Texture2D = preload("res://assets/art/ws_icons.png")     # Düsen, Panzerhülle, Fahrwerk, Scheinwerfer (26 px je Symbol, tools/art/aseprite)
var focus_item := ""                  # fokussierter Einbau: das Taxi zeigt das passende Teil
var desc_label: Label

func _ready() -> void:
	theme = MenuKit.make_theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	look = SectorLook.of(sector)
	tiles = SectorLook.tiles(sector)
	taxi_tex = Cosmetics.paint_texture()
	sticker_tex = Cosmetics.sticker_small_texture()       # 20 px wie am Taxi im Spiel
	var stage := Stage.make(self)
	panel = Control.new()
	panel.position = Vector2(340, 0)
	panel.size = Vector2(640, 360)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(panel)
	var pb := Panel.new()       # Tafel mit Sektorrand, oben kräftiger
	var sbf := StyleBoxFlat.new()
	sbf.bg_color = Color(look.shade.lerp(Color("#05060f"), 0.4), 0.94)
	sbf.border_color = look.edge
	sbf.set_border_width_all(1)
	sbf.border_width_top = 3
	sbf.set_corner_radius_all(5)
	pb.add_theme_stylebox_override("panel", sbf)
	pb.position = Vector2(336, 22)
	pb.size = Vector2(290, 316)
	pb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(pb)
	box = VBoxContainer.new()
	box.position = Vector2(346, 30)
	box.size = Vector2(270, 300)
	box.add_theme_constant_override("separation", 6)
	panel.add_child(box)
	_build("")

func _build(focus_id: String) -> void:
	for c in box.get_children():
		box.remove_child(c)
		c.queue_free()
	box.add_child(MenuKit.title(tr("MENU_WORKSHOP"), 16))
	var cash := Label.new()
	cash.text = "¢ %d" % int(wallet)
	cash.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cash.add_theme_color_override("font_color", Color("#ffe14a"))
	cash.add_theme_font_size_override("font_size", 16)
	cash.add_theme_color_override("font_outline_color", Color("#0c0f24"))
	cash.add_theme_constant_override("outline_size", 3)
	box.add_child(cash)
	var sub := Label.new()
	sub.text = tr("WS_AVAILABLE")
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 7)
	sub.add_theme_color_override("font_color", Color("#a9b8ff"))
	box.add_child(sub)
	for id in Workshop.ITEMS:
		box.add_child(_item_card(id))
	# ausführliche Beschreibung des fokussierten Einbaus
	desc_label = Label.new()
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_label.custom_minimum_size = Vector2(260, 30)
	desc_label.add_theme_font_size_override("font_size", 8)
	desc_label.add_theme_color_override("font_color", Color("#a9b8ff"))
	desc_label.text = tr("WS_%s_DESC" % (focus_item if focus_item != "" else Workshop.ITEMS[0]).to_upper())
	box.add_child(desc_label)
	var gap := Control.new()
	gap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(gap)
	var out := MenuKit.button(tr("WS_LEAVE"), _go)
	out.name = "leave"
	box.add_child(out)
	if state == S.SHOP:
		_focus(focus_id)

## Einbau als Karte mit Symbol, drei Stufenfeldern, Wirkung jetzt → nächste Stufe und farbigem Preis.
const WS_IDX := {"jets": 0, "hull": 1, "gear": 2, "light": 3}
const WS_ACCENT := [Color("#ff9a3a"), Color("#35c8e0"), Color("#ffcb3d"), Color("#fff1a8")]
func _effect(id: String, l: int) -> String:
	match id:
		"jets": return tr("WS_EFF_JETS") % int(round(Workshop.JETS_STEP * 100.0 * l))
		"hull": return tr("WS_EFF_HULL") % int(round(Workshop.HULL_STEP * 100.0 * l))
		"light": return tr("WS_EFF_LIGHT") % int(round(Workshop.LIGHT_STEP * 100.0 * l))
		_: return tr("WS_EFF_GEAR") % int(round(Workshop.GEAR_STEP * l))

class Pips extends Control:
	var level := 0
	var col := Color.WHITE
	var next_ok := false
	func _process(_d: float) -> void:
		queue_redraw()
	func _draw() -> void:
		var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 160.0)
		for i in Workshop.MAX_LEVEL:
			var r := Rect2(i * 21.0, 0, 19.0, 5.0)
			draw_rect(r.grow(0.67), Color("#0c0f24"))
			if i < level:
				draw_rect(r, col)
				draw_rect(Rect2(r.position, Vector2(r.size.x, 1.34)), col.lightened(0.45))
			elif i == level and next_ok:
				draw_rect(r, Color(col, 0.25 + 0.25 * pulse))
			else:
				draw_rect(r, Color("#232a52"))

func _item_card(id: String) -> PanelContainer:
	var l := Workshop.level_of(Save.data, id)
	var price := Workshop.price(Save.data, id, sector)
	var can := l < Workshop.MAX_LEVEL and wallet >= float(price)
	var accent: Color = WS_ACCENT[WS_IDX[id]]
	var card := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.06, 0.16, 0.92)
	sb.border_color = Color(accent, 0.45)
	sb.set_border_width_all(1)
	sb.border_width_left = 3
	sb.set_corner_radius_all(3)
	sb.content_margin_left = 6; sb.content_margin_right = 4; sb.content_margin_top = 3; sb.content_margin_bottom = 3
	card.add_theme_stylebox_override("panel", sb)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	card.add_child(row)
	var ic := TextureRect.new()
	var at := AtlasTexture.new()
	at.atlas = ws_icons
	at.region = Rect2(WS_IDX[id] * 26, 0, 26, 26)
	ic.texture = at
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ic.custom_minimum_size = Vector2(26, 26) * (2.0 / 3.0)
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(ic)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 2)
	col.custom_minimum_size = Vector2(150, 0)
	var title := Label.new()
	title.text = tr("WS_%s" % id.to_upper())
	title.add_theme_font_size_override("font_size", 10)
	col.add_child(title)
	var pips := Pips.new()
	pips.level = l
	pips.col = accent
	pips.next_ok = can
	pips.custom_minimum_size = Vector2(62, 6)
	col.add_child(pips)
	var eff := Label.new()
	eff.text = (tr("WS_NOW") % _effect(id, l) if l > 0 else tr("WS_STOCK")) + ("   ›  " + _effect(id, l + 1) if l < Workshop.MAX_LEVEL else "")
	eff.add_theme_font_size_override("font_size", 7)
	eff.add_theme_color_override("font_color", Color("#c4d0ff"))
	col.add_child(eff)
	row.add_child(col)
	var b := MenuKit.button(("✔ " + tr("WS_MAX")) if l >= Workshop.MAX_LEVEL else "¢ %d" % price, func():
		var rest := Workshop.buy(Save.data, id, wallet, sector)
		if rest >= 0.0:
			wallet = rest
			Save.write()
			Sfx.play("coin")
			_build(id)
		else:
			Sfx.play("warn", -6.0))
	b.name = id
	b.custom_minimum_size = Vector2(80, 22)
	b.add_theme_font_size_override("font_size", 8 if l >= Workshop.MAX_LEVEL else 9)
	if l < Workshop.MAX_LEVEL and not can:
		b.add_theme_color_override("font_color", Color("#ff7a8e"))
		b.add_theme_color_override("font_focus_color", Color("#ff7a8e"))
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b.focus_entered.connect(func():
		focus_item = id
		if desc_label != null and is_instance_valid(desc_label):
			desc_label.text = tr("WS_%s_DESC" % id.to_upper())
		sb.border_color = accent)
	b.focus_exited.connect(func():
		sb.border_color = Color(accent, 0.45))
	row.add_child(b)
	return card

func _focus(id: String) -> void:
	await get_tree().process_frame
	focus_item = id if id != "" else Workshop.ITEMS[0]
	var b := box.find_child(id if id != "" else Workshop.ITEMS[0], true, false) as Button
	if b != null:
		b.grab_focus()

func _go() -> void:
	if state != S.SHOP:
		return
	state = S.OUT
	t = 0.0
	Sfx.play("gear", -6.0)
	create_tween().tween_property(panel, "position:x", 340.0, PANEL_T)
	get_viewport().gui_release_focus()

func _open_shop() -> void:
	state = S.SHOP
	t = 0.0
	taxi_pos = Vector2(LIFT_X, LIFT_HIGH - TAXI_H)
	lift_y = LIFT_HIGH
	hatch = 0.0
	flame = 0.0
	Sfx.set_thrust(0.0, 0.0)
	create_tween().tween_property(panel, "position:x", 0.0, PANEL_T)
	_focus("")

func _process(delta: float) -> void:
	t += delta
	match state:
		S.IN:
			var u := _smooth(t / FLY_IN)
			taxi_pos.y = lerpf(-40.0, LIFT_LOW - TAXI_H, u)
			flame = 0.3 + 0.7 * (1.0 - u)
			if t < FLY_IN:
				Sfx.set_thrust(0.15 + 0.45 * (1.0 - u), 0.0)       # Bremsschub beim Einflug: klingt mit dem Landen ab (kein Dauerton)
			hatch = 1.0 - _smooth((t - FLY_IN * 0.6) / 0.5)
			if t >= FLY_IN and flame > 0.0:
				flame = 0.0
			if t >= FLY_IN:
				if not touched:
					touched = true
					Sfx.set_thrust(0.0, 0.0)
					Sfx.play("land", -4.0)
				lift_y = lerpf(LIFT_LOW, LIFT_HIGH, _smooth((t - FLY_IN) / LIFT_UP))
				taxi_pos.y = lift_y - TAXI_H
			if t >= FLY_IN + LIFT_UP:
				_open_shop()
		S.OUT:
			hatch = _smooth(t / 0.4)
			var v := clampf((t - PANEL_T) / FLY_OUT, 0.0, 1.0)
			if v > 0.0:
				Sfx.set_thrust(0.3 + 0.6 * v, 0.0)                  # Ausflug: Schub steigt mit der Fahrt
			flame = 1.0 if v > 0.0 else 0.0
			taxi_pos.y = lerpf(LIFT_HIGH - TAXI_H, -60.0, v * v)
			if v >= 1.0:
				state = S.FADE
				t = 0.0
				Sfx.set_thrust(0.0, 0.0)
				leave.call()
		S.FADE:
			modulate.a = 1.0 - clampf(t / FADE_T, 0.0, 1.0)
			if t >= FADE_T:
				get_parent().queue_free()
	queue_redraw()

var touched := false

static func _smooth(x: float) -> float:
	x = clampf(x, 0.0, 1.0)
	return x * x * (3.0 - 2.0 * x)

func _unhandled_input(event: InputEvent) -> void:
	if state == S.IN and event.is_action_pressed("ui_accept"):
		t = FLY_IN + LIFT_UP
		get_viewport().set_input_as_handled()
	elif state == S.SHOP and (event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause")):
		get_viewport().set_input_as_handled()
		_go()

func _draw() -> void:
	var m := Stage.margin(self)
	draw_rect(Rect2(Vector2.ZERO, size), look.shade)
	draw_set_transform(m)
	_draw_hall(m)
	_draw_lift()
	_draw_taxi()
	_draw_roof(m)

func _tile(x: float, y: float, idx: int, tint: Color) -> void:
	draw_texture_rect_region(tiles, Rect2(x, y, TILE, TILE), Rect2(idx * 48, 0, 48, 48), tint)

func _draw_hall(m: Vector2) -> void:
	var x0 := -ceilf(m.x / TILE) * TILE
	var cols := int((640.0 + 2.0 * m.x) / TILE) + 2
	var rows := int((FLOOR_Y + m.y) / TILE) + 2
	for row in rows:
		for col in cols:
			var x := x0 + float(col) * TILE
			var y := ROOF_Y + float(row - int(m.y / TILE)) * TILE
			_tile(x, y, 7 + (col * 7 + row * 13) % 3, Color(0.8, 0.8, 0.85))
	# Pfeiler, Lampen, Werkzeugwand, Regal
	for px in [20.0, 300.0]:
		for row in 9:
			_tile(px, ROOF_Y + float(row) * TILE, 0 if row % 3 else 1, Color(0.85, 0.85, 0.9))
	for lx in [96.0, 244.0]:
		draw_rect(Rect2(lx - 1.0, ROOF_Y, 2.0, 18.0), look.shade)
		draw_rect(Rect2(lx - 12.0, ROOF_Y + 18.0, 24.0, 4.0), look.edge)
		draw_colored_polygon(PackedVector2Array([Vector2(lx - 11.0, ROOF_Y + 22.0), Vector2(lx + 11.0, ROOF_Y + 22.0), Vector2(lx + 62.0, FLOOR_Y), Vector2(lx - 62.0, FLOOR_Y)]), Color(look.rim, 0.1))
	_draw_hall_details()
	# Boden
	for col in cols:
		var x := x0 + float(col) * TILE
		for row in int((360.0 + m.y - FLOOR_Y) / TILE) + 1:
			_tile(x, FLOOR_Y + float(row) * TILE, (col + row) % 4, Color.WHITE)
	draw_rect(Rect2(-m.x, FLOOR_Y - 1.0, 640.0 + 2.0 * m.x, 2.0), look.rim)
	var k := 0
	while k * 10 < 160:          # gelb-schwarze Sicherheitsmarkierung um die Bühne
		draw_rect(Rect2(LIFT_X - 80.0 + k * 10, FLOOR_Y + 1.0, 10.0, 3.0), Color("#ffc23a") if k % 2 == 0 else Color("#0c0f24"))
		k += 1

## Ausgestattete Halle – Lochwand mit Werkzeug-Silhouetten, Diagnosemonitor mit Ausbaustand, Regal mit Ersatzteilen, Ölfleck.
func _draw_hall_details() -> void:
	var ink := Color(look.shade, 1.0)
	# Lochwand mit Werkzeugen
	var pw := Rect2(44, 104, 84, 84)
	draw_rect(pw, Color(look.shade.lerp(look.edge, 0.25), 0.95))
	draw_rect(pw, look.edge, false, 1.0)
	for yy in range(int(pw.position.y) + 6, int(pw.end.y) - 2, 8):
		for xx in range(int(pw.position.x) + 6, int(pw.end.x) - 2, 8):
			draw_rect(Rect2(xx, yy, 1.34, 1.34), Color(ink, 0.7))
	var tool: Color = look.hi
	# Schraubenschlüssel
	draw_line(Vector2(56, 116), Vector2(56, 150), tool, 3.0)
	draw_arc(Vector2(56, 114), 4.0, PI * 0.15, PI * 0.85 + PI, 8, tool, 2.4)
	draw_circle(Vector2(56, 152), 3.2, tool); draw_circle(Vector2(56, 152), 1.4, ink)
	# Hammer
	draw_line(Vector2(72, 120), Vector2(72, 152), Color("#c9871f"), 3.0)
	draw_rect(Rect2(65, 115, 14, 6), tool)
	# Schraubendreher
	draw_rect(Rect2(86, 114, 5, 14), look.rim); draw_line(Vector2(88.5, 128), Vector2(88.5, 150), tool, 1.6)
	# Zange
	draw_line(Vector2(102, 116), Vector2(110, 150), tool, 2.0); draw_line(Vector2(110, 116), Vector2(102, 150), tool, 2.0)
	draw_circle(Vector2(106, 132), 2.0, tool)
	# Kabelrolle
	draw_arc(Vector2(108, 168), 9.0, 0, TAU, 20, look.rim, 2.5); draw_arc(Vector2(108, 168), 5.0, 0, TAU, 14, look.rim, 2.0)
	draw_line(Vector2(56, 162), Vector2(88, 162), tool, 2.0); draw_rect(Rect2(52, 158, 8, 8), Color("#ff4d6d"))
	# Diagnosemonitor mit Ausbaustand
	var mon := Rect2(236, 112, 58, 44)
	draw_rect(Rect2(mon.position.x + 26, mon.end.y, 6, 10), ink)
	draw_rect(mon.grow(2.0), ink)
	draw_rect(mon, Color("#06221e"))
	for yy in range(int(mon.position.y), int(mon.end.y), 3):
		draw_rect(Rect2(mon.position.x, yy, mon.size.x, 1), Color(0.2, 1.0, 0.7, 0.05))
	var g := Color("#5dff9a")
	var tc := mon.position + Vector2(29, 16)
	draw_arc(tc + Vector2(0, -3), 6.0, PI, TAU, 10, g, 1.0)
	draw_rect(Rect2(tc.x - 16, tc.y - 3, 32, 8), Color(g, 0.0)); draw_rect(Rect2(tc.x - 16, tc.y - 3, 32, 8), g, false, 1.0)
	draw_line(Vector2(tc.x - 6, tc.y + 5), Vector2(tc.x - 8, tc.y + 9), g, 1.0); draw_line(Vector2(tc.x + 6, tc.y + 5), Vector2(tc.x + 8, tc.y + 9), g, 1.0)
	var i := 0
	for id in Workshop.ITEMS:
		var l := Workshop.level_of(Save.data, id)
		for k in Workshop.MAX_LEVEL:
			draw_rect(Rect2(mon.position.x + 6 + k * 6, mon.position.y + 29 + i * 3.4, 5, 2.4), g if k < l else Color(g, 0.18))
		i += 1
	if int(t * 2.0) % 2 == 0:
		draw_rect(Rect2(mon.end.x - 8, mon.position.y + 4, 3, 3), g)
	# Regal mit Ersatzteilen
	for k in 3:
		var ry := 222.0 + float(k) * 28.0
		draw_rect(Rect2(242, ry, 54, 3), look.edge); draw_rect(Rect2(242, ry + 3, 54, 1), ink)
	draw_rect(Rect2(246, 206, 14, 16), Color("#c9871f")); draw_rect(Rect2(246, 206, 14, 3), Color("#e8a83a")); draw_rect(Rect2(251, 212, 4, 3), ink)
	draw_rect(Rect2(264, 210, 12, 12), Color("#3a7ae0")); draw_rect(Rect2(264, 210, 12, 2), Color("#6aa0ff"))
	draw_colored_polygon(PackedVector2Array([Vector2(280, 222), Vector2(284, 210), Vector2(290, 210), Vector2(294, 222)]), Color("#7a80a8"))
	draw_circle(Vector2(256, 242), 7.0, Color("#2a2a36")); draw_circle(Vector2(256, 242), 3.0, Color("#7a80a8"))
	draw_rect(Rect2(268, 236, 22, 14), Color("#5a6a5a")); draw_rect(Rect2(268, 236, 22, 2), Color("#8a9a8a"))
	draw_rect(Rect2(248, 262, 8, 16), Color("#ff4d6d")); draw_rect(Rect2(248, 262, 8, 3), Color("#ff9aa8"))
	draw_rect(Rect2(262, 266, 30, 12), Color("#c9cfee")); draw_rect(Rect2(264, 268, 26, 2), look.edge)
	# Ölfleck und Bodenmarkierung vor der Bühne
	draw_set_transform(Vector2(Stage.margin(self).x + 92.0, Stage.margin(self).y + FLOOR_Y + 4.0), 0.0, Vector2(1.0, 0.25))
	draw_circle(Vector2.ZERO, 12.0, Color(0.0, 0.0, 0.0, 0.25))
	draw_set_transform(Stage.margin(self))

func _draw_lift() -> void:
	var base := Rect2(LIFT_X - 62.0, FLOOR_Y - 8.0, 124.0, 8.0)
	draw_rect(base, look.shade)
	draw_rect(base, look.edge, false, 1.0)
	var top := lift_y + 8.0
	var bottom := FLOOR_Y - 8.0
	var mid := (top + bottom) * 0.5
	for s in [-1.0, 1.0]:                          # Scherenarme
		draw_line(Vector2(LIFT_X - 44.0 * s, bottom), Vector2(LIFT_X + 44.0 * s, top), look.shade, 7.0)
		draw_line(Vector2(LIFT_X - 44.0 * s, bottom), Vector2(LIFT_X + 44.0 * s, top), look.edge, 5.0)
		draw_line(Vector2(LIFT_X - 44.0 * s, bottom - 1.0), Vector2(LIFT_X + 44.0 * s, top - 1.0), look.hi, 1.0)
	draw_circle(Vector2(LIFT_X, mid), 4.0, look.hi)
	draw_circle(Vector2(LIFT_X, mid), 2.0, look.shade)
	draw_rect(Rect2(LIFT_X - 58.0, lift_y, 116.0, 8.0), Color("#2a3048"))
	var i := 0
	while i * 8 < 116:                             # Warnstreifen an der Bühnenkante
		draw_rect(Rect2(LIFT_X - 58.0 + i * 8, lift_y + 1.0, 8.0, 4.0), Color("#ffc23a") if i % 2 == 0 else Color("#0c0f24"))
		i += 1
	draw_rect(Rect2(LIFT_X - 58.0, lift_y, 116.0, 1.0), look.hi)

func _draw_taxi() -> void:
	var c := taxi_pos
	if flame > 0.0:
		var fl := (0.7 + 0.3 * sin(t * 40.0)) * flame
		draw_colored_polygon(PackedVector2Array([Vector2(c.x - 6, c.y + 20), Vector2(c.x + 6, c.y + 20), Vector2(c.x, c.y + 20 + 22.0 * fl)]), Color(1.0, 0.55, 0.2, 0.9))
		draw_colored_polygon(PackedVector2Array([Vector2(c.x - 3, c.y + 20), Vector2(c.x + 3, c.y + 20), Vector2(c.x, c.y + 20 + 12.0 * fl)]), Color(1.0, 0.94, 0.65))
	else:
		for s in [-1.0, 1.0]:                      # Fahrwerk steht auf der Bühne
			draw_rect(Rect2(c.x + 20.0 * s - 1.5, c.y + 14.0, 3.0, TAXI_H - 14.0), Color("#3a4580"))
			draw_rect(Rect2(c.x + 20.0 * s - 5.0, c.y + TAXI_H - 2.0, 10.0, 2.0), Color("#c9cfee"))
	var pulse := 0.5 + 0.5 * sin(t * 5.0)
	if state == S.SHOP and focus_item == "gear":       # Fahrwerk: Federbeine leuchten
		for s in [-1.0, 1.0]:
			draw_rect(Rect2(c.x + 20.0 * s - 3.0, c.y + 12.0, 6.0, TAXI_H - 12.0), Color(1.0, 0.8, 0.25, 0.35 + 0.35 * pulse))
	if taxi_tex != null:
		draw_texture_rect(taxi_tex, Rect2(c.x - TW, c.y - TH, TW * 2.0, TH * 2.0), false)
	if state == S.SHOP and focus_item == "jets":       # Düsen: Glühen an der Hauptdüse und an den Seitenkapseln
		for q in [Vector2(c.x, c.y + 19.0), Vector2(c.x - 38.0, c.y), Vector2(c.x + 38.0, c.y)]:
			draw_circle(q, 9.0, Color(1.0, 0.6, 0.2, 0.16 + 0.14 * pulse))
			draw_arc(q, 6.0 + 2.0 * pulse, 0, TAU, 20, Color(1.0, 0.75, 0.3, 0.55 + 0.35 * pulse), 1.4)
	if state == S.SHOP and focus_item == "hull":       # Panzerhülle: Schildschimmer um den Rumpf
		draw_arc(Vector2(c.x, c.y + 2.0), 38.0, PI * 1.08, PI * 1.92, 32, Color(0.35, 0.85, 1.0, 0.35 + 0.4 * pulse), 2.0)
		draw_arc(Vector2(c.x, c.y + 2.0), 42.0, PI * 1.12, PI * 1.88, 32, Color(0.35, 0.85, 1.0, 0.15 + 0.2 * pulse), 1.4)
		draw_arc(Vector2(c.x, c.y - 4.0), 38.0, PI * 0.12, PI * 0.88, 32, Color(0.35, 0.85, 1.0, 0.25 + 0.3 * pulse), 2.0)
	if state == S.SHOP and focus_item == "light":      # Scheinwerfer: Lichtkreis um das Taxi wächst je Stufe
		var lk := Workshop.light_k(Save.data)
		for k in 3:
			draw_circle(Vector2(c.x, c.y + 4.0), 40.0 * lk * (1.0 - 0.22 * k), Color(1.0, 0.95, 0.7, 0.05 + 0.03 * pulse))
		draw_arc(Vector2(c.x, c.y + 4.0), 40.0 * Workshop.light_k_for(mini(Workshop.level_of(Save.data, "light") + 1, Workshop.MAX_LEVEL)), 0, TAU, 40, Color(1.0, 0.92, 0.55, 0.35 + 0.35 * pulse), 1.4)
		draw_circle(Vector2(c.x, c.y + 16.0), 2.6, Color(1.0, 0.97, 0.8, 0.7 + 0.3 * pulse))
	if sticker_tex != null:
		draw_texture_rect(sticker_tex, Rect2(c.x - TW + 8.0, c.y - TH + 14.0, 20.0, 20.0), false)      # Texturpixel x 8, y 14 wie am Taxi

func _draw_roof(m: Vector2) -> void:
	var x0 := -ceilf(m.x / TILE) * TILE
	var cols := int((640.0 + 2.0 * m.x) / TILE) + 2
	var rows := int((ROOF_Y + m.y) / TILE) + 1
	for row in rows:
		for col in cols:
			_tile(x0 + float(col) * TILE, ROOF_Y - float(row + 1) * TILE, (col + row) % 4, Color.WHITE)
	# Dachluke: Schacht, zwei Flügel fahren von beiden Seiten zu
	var r := Rect2(LIFT_X - HATCH_W, -m.y, HATCH_W * 2.0, ROOF_Y + m.y)
	draw_rect(r, Color("#05060f"))
	var w := HATCH_W * (1.0 - hatch)
	for leaf in [Rect2(r.position.x, r.position.y, w, r.size.y), Rect2(r.end.x - w, r.position.y, w, r.size.y)]:
		draw_rect(leaf, Color("#161c45"))
		draw_rect(Rect2(leaf.position.x, ROOF_Y - 5.0, leaf.size.x, 5.0), Color("#ffc23a"))
		draw_rect(leaf, look.edge, false, 1.0)
	draw_rect(Rect2(-m.x, ROOF_Y, 640.0 + 2.0 * m.x, 1.0), look.edge)
