extends CanvasLayer
## Banner „Erfolg erreicht“ oben in der Mitte (gleitet herein, bleibt kurz, gleitet hinaus; mehrere nacheinander). Gezeigt nur an Ruhepunkten:
## Ergebnisansicht nach dem Level, Ende der Nachtschicht, Hauptmenü (AchToast.flush). Beim ersten Abgleich eines älteren Spielstands ein
## Sammelbanner („12 Erfolge schon erreicht“). Dazu das gemeinsame Abzeichen je Kategorie (draw_badge, auch in der Erfolgsübersicht).
## Einbinden mit: const AchToast := preload("res://src/ui/ach_toast.gd")

const Stage := preload("res://src/core/stage.gd")
const Achievements := preload("res://src/core/achievements.gd")

const CAT_COLORS := {"fare": Color("#35e0d2"), "sector": Color("#8c9cff"), "medal": Color("#ffd24a"), "landing": Color("#5dff9a"),
	"money": Color("#b6f06a"), "shift": Color("#b07cff"), "day": Color("#ffa04a"), "garage": Color("#ff7ac8"), "fun": Color("#ff6464"),
	"time": Color("#7fd3ff"), "egg": Color("#ff9ae6"), "holiday": Color("#ff5a7a"), "crown": Color("#ffe680"), "overtime": Color("#ffb347")}
const T_IN := 0.3
const T_STAY := 2.8
const T_OUT := 0.3
const W := 236.0
const H := 34.0

var queue: Array = []                 # Einträge: ["id", <Erfolg>] oder ["retro", <Anzahl>]
var t := 0.0
var canvas: Control

## Anstehende Erfolge aus Save zeigen (an Ruhepunkten aufrufen). Tut nichts, wenn nichts ansteht.
static func flush(tree: SceneTree) -> void:
	if tree == null or (Save.ach_pending.is_empty() and Save.ach_retro <= 0):
		return
	var items: Array = []
	if Save.ach_retro > 0:
		items.append(["retro", Save.ach_retro])
	for id in Save.ach_pending:
		items.append(["id", id])
	Save.ach_pending = []
	Save.ach_retro = 0
	var existing := tree.root.get_node_or_null("AchToast")
	if existing != null:
		existing.queue.append_array(items)
		return
	var layer: CanvasLayer = load("res://src/ui/ach_toast.gd").new()
	layer.name = "AchToast"
	layer.queue = items
	tree.root.add_child.call_deferred(layer)

func _ready() -> void:
	layer = 95
	process_mode = Node.PROCESS_MODE_ALWAYS
	var holder := Control.new()
	holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(holder)
	canvas = Stage.make(holder)
	canvas.draw.connect(_draw_toast)
	if not queue.is_empty():
		Sfx.play("perfect", -4.0)

func _process(delta: float) -> void:
	t += delta
	if t >= T_IN + T_STAY + T_OUT:
		queue.pop_front()
		t = 0.0
		if queue.is_empty():
			queue_free()
			return
		Sfx.play("perfect", -4.0)
	canvas.queue_redraw()

func _draw_toast() -> void:
	if queue.is_empty():
		return
	var still: bool = Settings.values.reduce_motion
	var k := 1.0
	if t < T_IN:
		k = t / T_IN
	elif t > T_IN + T_STAY:
		k = 1.0 - (t - T_IN - T_STAY) / T_OUT
	k = clampf(k, 0.0, 1.0)
	var e: Array = queue[0]
	var y := 6.0 if still else lerpf(-H - 4.0, 6.0, 1.0 - pow(1.0 - k, 3.0))
	var a := k if still else 1.0
	var r := Rect2(320.0 - W * 0.5, y, W, H)
	var id := String(e[1]) if e[0] == "id" else ""
	var col: Color = CAT_COLORS.get(Achievements.category(id), Color("#ffd24a")) if id != "" else Color("#ffd24a")
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.06, 0.16, 0.95 * a)
	sb.border_color = Color(col, 0.9 * a)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(7)
	sb.shadow_color = Color(0, 0, 0, 0.45 * a)
	sb.shadow_size = 4
	canvas.draw_style_box(sb, r)
	draw_badge(canvas, id if id != "" else "medals_50", r.position + Vector2(18, H * 0.5), 12.0, true, a)
	var f: Font = Fonts.hud
	var head := tr("ACH_TOAST") if id != "" else tr("ACH_TOAST_RETRO_HEAD")
	var line := tr("ACH_" + id.to_upper()) if id != "" else tr("ACH_TOAST_RETRO") % int(e[1])
	var tx := r.position.x + 36.0
	var tw := W - 42.0
	canvas.draw_string(f, Vector2(tx, r.position.y + 13.0), head.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, tw, 7, Color(col, a))
	canvas.draw_string(Fonts.ui, Vector2(tx, r.position.y + 26.0), line, HORIZONTAL_ALIGNMENT_LEFT, tw, 10, Color(0.94, 0.96, 1.0, a))

# ---------- Abzeichen ----------

## Achteckiges Abzeichen mit dem Zeichen der Kategorie; gesperrt grau.
static func draw_badge(ci: CanvasItem, id: String, c: Vector2, r: float, unlocked: bool, a := 1.0) -> void:
	var cat := Achievements.category(id)
	var col: Color = CAT_COLORS.get(cat, Color.WHITE)
	if not unlocked:
		col = Color(0.42, 0.45, 0.6)
	var pts := PackedVector2Array()
	for i in 8:
		var ang := PI / 8.0 + TAU * float(i) / 8.0
		pts.append(c + Vector2(cos(ang), sin(ang)) * r)
	ci.draw_colored_polygon(pts, Color(0.07, 0.08, 0.2, a) if unlocked else Color(0.08, 0.09, 0.16, a))
	pts.append(pts[0])
	ci.draw_polyline(pts, Color(col, (0.95 if unlocked else 0.5) * a), maxf(r * 0.09, 0.8), true)
	var s := Color(col, (1.0 if unlocked else 0.45) * a)
	var w := maxf(r * 0.12, 0.8)
	var u := r * 0.5
	if not unlocked and Achievements.is_hidden(id):            # verdeckter Erfolg: nur ein Fragezeichen
		ci.draw_arc(c + Vector2(0, -u * 0.35), u * 0.42, PI * 1.05, PI * 2.45, 12, s, w * 1.2, true)
		ci.draw_line(c + Vector2(u * 0.05, u * 0.05), c + Vector2(0, u * 0.4), s, w * 1.2, true)
		ci.draw_circle(c + Vector2(0, u * 0.78), w * 0.75, s, true, -1.0, true)
		return
	match cat:
		"fare":
			ci.draw_circle(c + Vector2(0, -u * 0.55), u * 0.38, s, true, -1.0, true)
			ci.draw_arc(c + Vector2(0, u * 0.75), u * 0.75, PI, TAU, 16, s, w * 1.4, true)
		"sector":
			ci.draw_circle(c, u * 0.55, s, true, -1.0, true)
			var ring := PackedVector2Array()
			for i in 25:
				var ang := TAU * float(i) / 24.0
				ring.append(c + Vector2(cos(ang) * u * 1.15, sin(ang) * u * 0.38).rotated(-0.35))
			ci.draw_polyline(ring, s, w * 0.8, true)
		"medal":
			var star := PackedVector2Array()
			for i in 10:
				var ang := -PI * 0.5 + PI * float(i) / 5.0
				star.append(c + Vector2(cos(ang), sin(ang)) * (u * 1.05 if i % 2 == 0 else u * 0.45))
			ci.draw_colored_polygon(star, s)
		"landing":
			ci.draw_polyline(PackedVector2Array([c + Vector2(-u * 0.6, -u * 0.6), c + Vector2(0, 0), c + Vector2(u * 0.6, -u * 0.6)]), s, w, true)
			ci.draw_line(c + Vector2(-u * 0.9, u * 0.6), c + Vector2(u * 0.9, u * 0.6), s, w * 1.3, true)
		"money":
			ci.draw_arc(c, u * 0.7, PI * 0.25, PI * 1.75, 16, s, w, true)
			ci.draw_line(c + Vector2(0, -u * 1.0), c + Vector2(0, u * 1.0), s, w * 0.8, true)
		"shift":
			ci.draw_arc(c, u * 0.85, PI * 0.35, PI * 1.65, 20, s, w * 1.6, true)
			ci.draw_circle(c + Vector2(u * 0.75, -u * 0.6), u * 0.15, s, true, -1.0, true)
		"day":
			ci.draw_circle(c, u * 0.45, s, true, -1.0, true)
			for i in 8:
				var d := Vector2.from_angle(TAU * float(i) / 8.0)
				ci.draw_line(c + d * u * 0.7, c + d * u * 1.0, s, w * 0.8, true)
		"garage":
			ci.draw_arc(c, u * 0.6, 0.0, TAU, 20, s, w * 1.2, true)
			for i in 6:
				var d := Vector2.from_angle(TAU * float(i) / 6.0)
				ci.draw_line(c + d * u * 0.65, c + d * u * 0.98, s, w * 1.4, true)
		"fun":
			ci.draw_polyline(PackedVector2Array([c + Vector2(u * 0.3, -u), c + Vector2(-u * 0.35, u * 0.1), c + Vector2(u * 0.25, u * 0.1), c + Vector2(-u * 0.3, u)]), s, w, true)
		"time":
			ci.draw_arc(c, u * 0.85, 0.0, TAU, 24, s, w, true)
			ci.draw_line(c, c + Vector2(0, -u * 0.6), s, w, true)
			ci.draw_line(c, c + Vector2(u * 0.45, 0), s, w, true)
		"egg":
			var egg := PackedVector2Array()
			for i in 20:
				var ang := TAU * float(i) / 20.0
				var up := cos(ang)
				egg.append(c + Vector2(sin(ang) * u * 0.7 * (1.0 - 0.18 * maxf(0.0, up)), -up * u * (1.05 if up > 0.0 else 0.8)))
			ci.draw_colored_polygon(egg, s)
			var bg := Color(0.07, 0.08, 0.2, a)
			ci.draw_polyline(PackedVector2Array([c + Vector2(-u * 0.6, 0), c + Vector2(-u * 0.3, -u * 0.25), c + Vector2(0, 0), c + Vector2(u * 0.3, -u * 0.25), c + Vector2(u * 0.6, 0)]), bg, w * 0.8, true)
		"holiday":
			_holiday_symbol(ci, id, c, u, s, w)
		"overtime":                                  # Sonderschicht: Uhr mit Pfeil im Kreis (Überstunden)
			ci.draw_arc(c, u * 0.85, -PI * 0.35, PI * 1.45, 20, s, w * 1.3, true)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(u * 0.55, -u * 0.95), c + Vector2(u * 1.05, -u * 0.55), c + Vector2(u * 0.45, -u * 0.35)]), s)
			ci.draw_line(c, c + Vector2(0, -u * 0.5), s, w, true)
			ci.draw_line(c, c + Vector2(u * 0.4, u * 0.15), s, w, true)
		"crown":
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-u * 0.9, u * 0.55), c + Vector2(-u * 0.9, -u * 0.45), c + Vector2(-u * 0.45, 0),
				c + Vector2(0, -u * 0.75), c + Vector2(u * 0.45, 0), c + Vector2(u * 0.9, -u * 0.45), c + Vector2(u * 0.9, u * 0.55)]), s)
			for x in [-0.9, 0.0, 0.9]:
				ci.draw_circle(c + Vector2(u * x, -u * (0.75 if x == 0.0 else 0.45) - u * 0.15), u * 0.14, s, true, -1.0, true)

## Zeichen der Feiertags-Erfolge: Stiefel (Nikolaus), Tannenbaum (Weihnachten), Feuerwerk (Silvester), Herz (Valentinstag).
static func _holiday_symbol(ci: CanvasItem, id: String, c: Vector2, u: float, s: Color, w: float) -> void:
	match id:
		"day_nikolaus":
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-u * 0.35, -u * 0.85), c + Vector2(u * 0.25, -u * 0.85), c + Vector2(u * 0.25, u * 0.2),
				c + Vector2(u * 0.85, u * 0.35), c + Vector2(u * 0.85, u * 0.8), c + Vector2(-u * 0.35, u * 0.8)]), s)
			ci.draw_rect(Rect2(c + Vector2(-u * 0.5, -u * 1.0), Vector2(u * 0.9, u * 0.3)), Color(1, 1, 1, s.a))
		"day_xmas":
			for k in 3:
				var y := -u * 0.95 + u * 0.5 * k
				var hw := u * (0.45 + 0.25 * k)
				ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0, y), c + Vector2(hw, y + u * 0.75), c + Vector2(-hw, y + u * 0.75)]), s)
			ci.draw_rect(Rect2(c + Vector2(-u * 0.15, u * 0.8), Vector2(u * 0.3, u * 0.3)), s)
		"day_silvester":
			for i in 8:
				var d := Vector2.from_angle(TAU * float(i) / 8.0 + 0.2)
				ci.draw_line(c + d * u * 0.3, c + d * u * 0.95, s, w * 0.8, true)
				ci.draw_circle(c + d * u * 1.0, u * 0.1, s, true, -1.0, true)
			ci.draw_circle(c, u * 0.18, s, true, -1.0, true)
		_:
			ci.draw_circle(c + Vector2(-u * 0.42, -u * 0.25), u * 0.47, s, true, -1.0, true)
			ci.draw_circle(c + Vector2(u * 0.42, -u * 0.25), u * 0.47, s, true, -1.0, true)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-u * 0.86, -u * 0.08), c + Vector2(u * 0.86, -u * 0.08), c + Vector2(0, u * 0.9)]), s)
