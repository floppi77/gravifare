class_name WorldDecor
extends RefCounted
## Sektor-Details auf dem Fels (statisch, wird einmal mit dem Level gezeichnet): Tiefe im Inneren der Felsmassen und je Sektor eigene
## Oberflächen. Alles bleibt flach und gedämpft, damit nichts wie ein Hindernis aussieht; Gefahren behalten ihre Warnfarben.

const T := 16.0
const PX := 1.0 / 3.0

static func _h(x: int, y: int, k: int) -> int:
	return absi((x * 73856093) ^ (y * 19349663) ^ (k * 83492791)) >> 3

static func _rock(lv: LevelData, x: int, y: int) -> bool:
	return lv.cell(x, y) == "#"

## Abstand jeder Felszelle zur nächsten offenen Zelle (Felder).
static func _depths(lv: LevelData) -> Dictionary:
	var d := {}
	var open: Array = []
	for y in lv.height:
		for x in lv.width:
			if not _rock(lv, x, y):
				open.append(Vector2i(x, y))
				d[Vector2i(x, y)] = 0
	var i := 0
	while i < open.size():
		var c: Vector2i = open[i]
		i += 1
		for n in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var q: Vector2i = c + n
			if q.x >= 0 and q.y >= 0 and q.x < lv.width and q.y < lv.height and not d.has(q):
				d[q] = int(d[c]) + 1
				open.append(q)
	return d

static func draw(c: CanvasItem, lv: LevelData) -> void:
	var look := SectorLook.of(lv.sector)
	var dep := _depths(lv)
	var shade: Color = look.shade
	for y in lv.height:
		for x in lv.width:
			if not _rock(lv, x, y):
				continue
			var cols := PackedColorArray()            # Masse wird nach innen weich dunkler: Tiefe statt sichtbarem Raster
			for k in [[0, 0], [1, 0], [1, 1], [0, 1]]:
				var sum := 0.0
				for o in [[-1, -1], [0, -1], [-1, 0], [0, 0]]:
					sum += float(dep.get(Vector2i(x + k[0] + o[0], y + k[1] + o[1]), 7))
				var a := clampf((sum / 4.0 - 1.1) * 0.2, 0.0, 0.74)
				cols.append(Color(shade.r, shade.g, shade.b, a))
			c.draw_polygon(PackedVector2Array([Vector2(x, y) * T, Vector2(x + 1, y) * T, Vector2(x + 1, y + 1) * T, Vector2(x, y + 1) * T]), cols)
	var rim: Color = look.rim
	for y in lv.height:
		for x in lv.width:
			if not lv.is_solid_cell(x, y) or lv.cell(x, y) == "^":
				continue
			if y > 0 and not lv.is_solid_cell(x, y - 1):        # Umgebungslicht fällt auf die Oberkanten …
				_fade(c, x * T, y * T, T, 9.0, Color(rim.r, rim.g, rim.b, 0.34), Color(rim.r, rim.g, rim.b, 0.0))
			if y + 1 < lv.height and not lv.is_solid_cell(x, y + 1):   # … die Unterseiten liegen im Schatten
				_fade(c, x * T, (y + 1) * T - 8.0, T, 8.0, Color(shade.r, shade.g, shade.b, 0.0), Color(shade.r, shade.g, shade.b, 0.6))
	for y in lv.height:
		for x in lv.width:
			if not _rock(lv, x, y):
				continue
			var d := int(dep.get(Vector2i(x, y), 1))
			var px := x * T
			var py := y * T
			if d >= 2:
				_inner(c, lv.sector, x, y, px, py)
			if y > 0 and lv.cell(x, y - 1) == ".":
				_top(c, lv.sector, x, y, px, py)
			if y + 1 < lv.height and lv.cell(x, y + 1) == ".":
				_under(c, lv.sector, x, y, px, py + T)

static func _fade(c: CanvasItem, x: float, y: float, w: float, h: float, top: Color, bot: Color) -> void:
	c.draw_polygon(PackedVector2Array([Vector2(x, y), Vector2(x + w, y), Vector2(x + w, y + h), Vector2(x, y + h)]), PackedColorArray([top, top, bot, bot]))

static func _r(c: CanvasItem, x: float, y: float, w: float, h: float, col: Color) -> void:
	c.draw_rect(Rect2(x, y, w, h), col)

## Innenflächen: Fensterlichter, Risse, Glut.
static func _inner(c: CanvasItem, s: int, x: int, y: int, px: float, py: float) -> void:
	var h := _h(x, y, 1)
	match s:
		1, 7:
			if h % 2 == 0:                            # Fensterreihen einer Station
				var col := Color("#ffd98a") if s == 7 else Color("#8fd0ff")
				for i in 3:
					if (h >> (i + 3)) % 3 != 0:
						_r(c, px + 3.0 + i * 3.6, py + 5.0 + float(h % 2) * 4.0, 1.34, 1.67, Color(col.r, col.g, col.b, 0.5))
		3:
			if h % 2 == 0:                            # Roststreifen
				_r(c, px + float(h % 12) + 2.0, py, 1.34, T * (0.5 + float(h % 3) * 0.25), Color(0.55, 0.24, 0.07, 0.4))
		5:
			if h % 2 == 0:                            # Glutrisse
				var a := Vector2(px + 2.0 + float(h % 6), py + 2.0)
				var b := a + Vector2(float(h % 5) - 2.0, 6.0)
				var e := b + Vector2(float((h >> 3) % 5) - 2.0, 6.0)
				c.draw_polyline(PackedVector2Array([a, b, e]), Color(1.0, 0.45, 0.12, 0.85), 0.67)
		9:
			if h % 3 == 0:                            # Risse ins Nichts
				var a := Vector2(px + 3.0 + float(h % 8), py + 1.0)
				c.draw_polyline(PackedVector2Array([a, a + Vector2(3, 5), a + Vector2(1, 9), a + Vector2(4, 13)]), Color(0.66, 0.46, 1.0, 0.75), 0.67)

## Oberkante freier Felsen.
static func _top(c: CanvasItem, s: int, x: int, y: int, px: float, py: float) -> void:
	var h := _h(x, y, 2)
	match s:
		1:
			if h % 4 == 0:                            # Antenne mit Lampe
				_r(c, px + 7.0, py - 7.0, PX * 2.0, 7.0, Color("#39436f"))
				_r(c, px + 6.7, py - 8.0, 1.34, 1.34, Color("#ff6a6a"))
			elif h % 5 == 0:
				_r(c, px + 3.0, py - 2.0, 7.0, 2.0, Color("#2a3360"))
				_r(c, px + 4.0, py - 1.34, 1.0, PX, Color("#8fd0ff"))
		2:
			for i in 1 + h % 3:                       # Kristalle: stumpf und dunkel, damit sie nicht wie Dornen wirken
				var bx := px + 2.0 + float((h >> (i * 2)) % 12)
				var ht := 2.0 + float((h >> (i + 2)) % 3)
				c.draw_colored_polygon(PackedVector2Array([Vector2(bx - 2.2, py), Vector2(bx - 0.7, py - ht), Vector2(bx + 0.7, py - ht), Vector2(bx + 2.2, py)]), Color(0.36, 0.2, 0.56, 0.95))
				c.draw_line(Vector2(bx - 0.7, py - ht), Vector2(bx + 0.7, py - ht), Color(0.62, 0.42, 0.84, 0.8), PX)
		3:
			if h % 2 == 0:                            # Schrott
				_r(c, px + 2.0, py - 2.34, 6.0, 2.34, Color("#4b3a2a"))
				_r(c, px + 2.0, py - 2.34, 6.0, PX, Color("#8a6a44"))
			elif h % 4 == 1:
				_r(c, px, py - 1.34, T, 1.34, Color("#3a3028"))
				_r(c, px + 5.0, py - 2.0, 2.0, 2.0, Color("#5a4a38"))
		4:
			var hh := 1.34 + float(h % 3) * 0.67      # Schneekappe
			_r(c, px, py - hh, T, hh + 1.0, Color(0.9, 0.95, 1.0, 0.96))
			_r(c, px + 2.0, py - hh - 0.67, 9.0, 0.67, Color(1, 1, 1, 0.9))
			_r(c, px, py + 1.0, T, PX * 2.0, Color(0.6, 0.78, 0.92, 0.7))
		5:
			if h % 2 == 0:                            # Schlacke mit Glut
				_r(c, px + 1.0, py - 2.0, 9.0, 2.0, Color("#2a1410"))
				_r(c, px + 3.0, py - 1.0, 3.0, PX * 2.0, Color(1.0, 0.5, 0.12, 0.85))
		6:
			if h % 2 == 0:                            # Korallen und Tang
				for i in 3:
					var bx := px + 2.0 + float((h >> (i * 2)) % 12)
					var ht := 3.0 + float((h >> i) % 6)
					_r(c, bx, py - ht, 1.0, ht, Color(0.2, 0.72, 0.58, 0.85))
			else:
				_r(c, px + 2.0, py - 1.34, 8.0, 1.34, Color("#c2607a"))
				_r(c, px + 3.0, py - 2.0, 2.0, 0.67, Color("#e088a0"))
		7:
			_r(c, px, py - 0.67, T, 0.67, Color("#d8b870"))
			if x % 3 == 0:
				_r(c, px + 7.0, py - 1.34, 2.0, 0.67, Color("#fff0c0"))
		8:
			var hh := 1.34 + float(h % 3) * 0.67      # Moos, ab und zu Leuchtpilze
			_r(c, px, py - hh, T, hh + 0.67, Color("#2f6a3a"))
			_r(c, px + 3.0, py - hh - 0.67, 7.0, 0.67, Color("#3f8a4a"))
			if h % 3 == 0:
				_r(c, px + 8.0, py - hh - 2.0, 0.67, 2.0, Color("#b8e8d0"))
				_r(c, px + 7.0, py - hh - 3.0, 2.67, 1.0, Color("#6ff0e0"))
		9:
			if h % 3 == 0:                            # schwebende Splitter
				_r(c, px + 4.0, py - 4.0 - float(h % 5), 3.0, 1.34, Color("#3a2f70"))
				_r(c, px + 4.0, py - 4.0 - float(h % 5), 3.0, PX, Color("#a78cff"))

## Unterkante: Kabel, Eiszapfen, Ranken; kurz und blass, damit sie nicht wie Dornen wirken.
static func _under(c: CanvasItem, s: int, x: int, y: int, px: float, py: float) -> void:
	var h := _h(x, y, 3)
	match s:
		1, 3:
			if h % 3 == 0:
				var l := 4.0 + float(h % 8)
				_r(c, px + 6.0, py, PX * 2.0, l, Color("#20264a") if s == 1 else Color("#2a2018"))
				_r(c, px + 5.34, py + l, 2.0, 1.34, Color("#ffd98a") if s == 1 else Color("#c98a3a"))
		4:
			if h % 3 == 0:
				_r(c, px + 3.0 + float(h % 8), py, 1.34, 2.0 + float(h % 3), Color(0.82, 0.92, 1.0, 0.55))
		5:
			if h % 6 == 0:
				_r(c, px + 7.0, py, 1.34, 2.0, Color(1.0, 0.45, 0.1, 0.7))
		6:
			if h % 3 == 0:
				var l := 3.0 + float(h % 7)
				_r(c, px + 4.0 + float(h % 8), py, 1.0, l, Color(0.14, 0.5, 0.42, 0.75))
		7:
			if h % 4 == 0:
				_r(c, px + 3.0, py, 10.0, 0.67, Color("#fff0c0"))
		8:
			if h % 2 == 0:
				var l := 5.0 + float(h % 14)
				var vx := px + 3.0 + float(h % 10)
				_r(c, vx, py, 0.67, l, Color("#1f4a2a"))
				if h % 3 == 0:
					_r(c, vx - 0.34, py + l, 1.34, 1.34, Color("#6ff0e0"))
