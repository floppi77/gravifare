class_name WorkshopBay
extends Control
## Werkstatt zwischen zwei Sektoren, im Farbschema des gerade beendeten Sektors: Das Taxi fliegt durch die Dachluke ein, setzt auf der Hebebühne auf und
## wird angehoben. Rechts stehen die verfügbaren Credits und die Einbauten. „Verlassen“ lässt es durch die Luke ausfliegen; danach folgt der Levelwechsel.

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

func _ready() -> void:
	theme = MenuKit.make_theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	look = SectorLook.of(sector)
	tiles = SectorLook.tiles(sector)
	taxi_tex = Cosmetics.paint_texture()
	sticker_tex = Cosmetics.sticker_texture()
	var stage := Stage.make(self)
	panel = Control.new()
	panel.position = Vector2(340, 0)
	panel.size = Vector2(640, 360)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(panel)
	var back := ColorRect.new()
	back.color = Color(look.shade, 0.9)
	back.position = Vector2(336, 22)
	back.size = Vector2(290, 316)
	panel.add_child(back)
	var rim := ColorRect.new()
	rim.color = look.edge
	rim.position = Vector2(336, 22)
	rim.size = Vector2(290, 1)
	panel.add_child(rim)
	box = VBoxContainer.new()
	box.position = Vector2(346, 30)
	box.size = Vector2(270, 300)
	box.add_theme_constant_override("separation", 6)
	panel.add_child(box)
	_build("")
	Sfx.set_thrust(0.6, 0.0)

func _build(focus_id: String) -> void:
	for c in box.get_children():
		box.remove_child(c)
		c.queue_free()
	box.add_child(MenuKit.title(tr("MENU_WORKSHOP"), 16))
	var cash := Label.new()
	cash.text = tr("WS_CREDITS") % int(wallet)
	cash.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cash.add_theme_color_override("font_color", Color("#ffe14a"))
	cash.add_theme_font_size_override("font_size", 12)
	box.add_child(cash)
	for id in Workshop.ITEMS:
		box.add_child(_item_row(id))
	var gap := Control.new()
	gap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(gap)
	var out := MenuKit.button(tr("WS_LEAVE"), _go)
	out.name = "leave"
	box.add_child(out)
	if state == S.SHOP:
		_focus(focus_id)

func _item_row(id: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 1)
	col.custom_minimum_size = Vector2(170, 52)
	var l := Workshop.level_of(Save.data, id)
	var title := Label.new()
	title.text = "%s  %s" % [tr("WS_%s" % id.to_upper()), "■".repeat(l) + "□".repeat(Workshop.MAX_LEVEL - l)]
	title.add_theme_color_override("font_color", Color.WHITE)
	col.add_child(title)
	var desc := Label.new()
	desc.text = tr("WS_%s_DESC" % id.to_upper())
	desc.add_theme_font_size_override("font_size", 8)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.custom_minimum_size = Vector2(170, 0)
	col.add_child(desc)
	row.add_child(col)
	var b := MenuKit.button(tr("WS_MAX") if l >= Workshop.MAX_LEVEL else "¢ %d" % Workshop.price(Save.data, id), func():
		var rest := Workshop.buy(Save.data, id, wallet)
		if rest >= 0.0:
			wallet = rest
			Save.write()
			Sfx.play("coin")
			_build(id)
		else:
			Sfx.play("warn", -6.0))
	b.name = id
	b.custom_minimum_size = Vector2(94, 22)
	b.add_theme_font_size_override("font_size", 8)
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(b)
	return row

func _focus(id: String) -> void:
	await get_tree().process_frame
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
			if v > 0.0 and flame == 0.0:
				Sfx.set_thrust(0.8, 0.0)
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
	draw_rect(Rect2(58, 120, 56, 64), Color(look.shade, 0.85))
	draw_rect(Rect2(58, 120, 56, 64), look.edge, false, 1.0)
	for i in 4:
		var bx := 66.0 + float(i) * 12.0
		draw_rect(Rect2(bx, 126, 3, 22 + (i * 5) % 12), look.hi)
		draw_rect(Rect2(bx - 2.0, 126, 7, 3), look.hi)
	for i in 3:
		var ry := 240.0 + float(i) * 25.0
		draw_rect(Rect2(250, ry, 44, 3), look.edge)
	draw_rect(Rect2(256, 250, 12, 15), look.rim)
	draw_rect(Rect2(274, 275, 14, 15), look.hi)
	# Boden
	for col in cols:
		var x := x0 + float(col) * TILE
		for row in int((360.0 + m.y - FLOOR_Y) / TILE) + 1:
			_tile(x, FLOOR_Y + float(row) * TILE, (col + row) % 4, Color.WHITE)
	draw_rect(Rect2(-m.x, FLOOR_Y - 1.0, 640.0 + 2.0 * m.x, 2.0), look.rim)

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
		draw_colored_polygon(PackedVector2Array([Vector2(c.x - 7, c.y + 16), Vector2(c.x + 7, c.y + 16), Vector2(c.x, c.y + 16 + 26.0 * fl)]), Color(1.0, 0.55, 0.2, 0.9))
		draw_colored_polygon(PackedVector2Array([Vector2(c.x - 3, c.y + 16), Vector2(c.x + 3, c.y + 16), Vector2(c.x, c.y + 16 + 14.0 * fl)]), Color(1.0, 0.94, 0.65))
	else:
		for s in [-1.0, 1.0]:                      # Fahrwerk steht auf der Bühne
			draw_rect(Rect2(c.x + 24.0 * s - 1.5, c.y + 16.0, 3.0, TAXI_H - 16.0), Color("#3a4580"))
			draw_rect(Rect2(c.x + 24.0 * s - 5.0, c.y + TAXI_H - 2.0, 10.0, 2.0), Color("#c9cfee"))
	if taxi_tex != null:
		draw_texture_rect(taxi_tex, Rect2(c.x - 48.0, c.y - 30.0, 96.0, 60.0), false)
	if sticker_tex != null:
		draw_texture_rect(sticker_tex, Rect2(c.x - 39.0, c.y - 12.6, 24.0, 24.0), false)

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
