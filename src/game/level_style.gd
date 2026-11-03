extends Node2D
## Optische Sonderbehandlung einzelner Level nach ihrem Namen (rein Optik, Physik und Kollision bleiben unberührt).
## "neon": Leuchtröhren entlang der Felskanten, Leuchtschilder in der Felsmasse, flackernde Röhren (Neonallee, Neonfinale, Neonlabyrinth).
## "glass": Glasfassade mit Scheibenfeldern, Rahmen, Spiegelungen und wanderndem Lichtreflex.
## Gezeichnet wird additiv und unbeleuchtet, zwischen Fels und Requisiten: Plattformen, Taxi und Gefahren bleiben darüber gut lesbar.

const T := 16.0
const PX := 1.0 / 3.0

## Stil je Level-ID. "pal" = Farbfamilie der Röhren, "signs" = Anteil Schilder (je mehr, desto dichter), "flick" = Anteil flackernder Röhren.
const STYLES := {
	"S2-02": {"kind": "neon", "pal": ["#ff4fd8", "#4fd8ff", "#b46bff"], "signs": 26, "flick": 0.10},                                # Neonallee: ruhige Reklameallee
	"S2-06": {"kind": "neon", "pal": ["#ff4fd8", "#ffb347", "#4fd8ff", "#ff6bb5"], "signs": 14, "flick": 0.22},                      # Neonfinale: dichter, heller, nervöser
	"S2-08": {"kind": "neon", "pal": ["#4fd8ff", "#7b6bff", "#42ffc8"], "signs": 20, "flick": 0.16},                                 # Neonlabyrinth: kühles Blau-Grün mit Richtungspfeilen
	"S2-11": {"kind": "glass"},
}

var kind := ""
var style: Dictionary = {}
var lv: LevelData
var anim: Node2D
var tubes_anim: Array = []         # [a, b, Color, Phase] flackernde Röhren
var panes: Array = []              # [Rect2, Phase] Scheibenfelder für den wandernden Reflex
var t := 0.0

static func applies_to(id: String) -> bool:
	return STYLES.has(id)

func _ready() -> void:
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	m.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	material = m

func setup(level: LevelData) -> void:
	lv = level
	style = STYLES.get(level.id, {})
	kind = String(style.get("kind", ""))
	tubes_anim.clear()
	panes.clear()
	visible = kind != ""
	if anim == null:
		anim = Anim.new()
		anim.owner_style = self
		anim.material = material if material != null else null
		add_child(anim)
	if material != null:
		anim.material = material
	set_process(kind != "")
	queue_redraw()
	anim.queue_redraw()

func _process(delta: float) -> void:
	if Settings.values.reduce_motion:
		return
	t += delta
	anim.queue_redraw()

func _h(x: int, y: int, k: int) -> int:
	return absi((x * 73856093) ^ (y * 19349663) ^ (k * 83492791)) >> 3

func _open(x: int, y: int) -> bool:
	return lv.cell(x, y) == "."       # nur freier Luftraum: Plattformen, Tore und Gefahren bleiben unverziert

func _rock(x: int, y: int) -> bool:
	return lv.cell(x, y) == "#"

func _draw() -> void:
	if lv == null:
		return
	match kind:
		"neon":
			_draw_neon()
		"glass":
			_draw_glass()

# ---------------------------------------------------------------- Neon

func _pal(h: int) -> Color:
	var p: Array = style.pal
	return Color(String(p[h % p.size()]))

## Eine Leuchtröhre von a nach b: weiter Schein, enger Schein, heller Kern (additiv).
func _tube(c: CanvasItem, a: Vector2, b: Vector2, col: Color, k: float) -> void:
	c.draw_line(a, b, Color(col.r, col.g, col.b, 0.16 * k), 9.0)
	c.draw_line(a, b, Color(col.r, col.g, col.b, 0.34 * k), 4.5)
	c.draw_line(a, b, Color(col.r, col.g, col.b, 1.0 * k), 2.0)
	c.draw_line(a, b, Color(1, 1, 1, 0.8 * k), 0.8)

## Lichtschein, der von der Röhre in den Raum fällt.
func _spill(c: CanvasItem, from: Vector2, to: Vector2, depth: Vector2, col: Color, k: float) -> void:
	var a := Color(col.r, col.g, col.b, 0.3 * k)
	var z := Color(col.r, col.g, col.b, 0.0)
	c.draw_polygon(PackedVector2Array([from, to, to + depth, from + depth]), PackedColorArray([a, a, z, z]))

func _draw_neon() -> void:
	var flick: float = style.flick
	# Röhren: zusammenhängende Kantenstücke aus mindestens drei Zellen, mit Lücken nach Hash
	var dirs := [[0, -1], [0, 1], [-1, 0], [1, 0]]       # offene Seite des Felsens: oben, unten, links, rechts
	for d in dirs:
		var horizontal: bool = d[1] != 0
		var outer: int = lv.height if horizontal else lv.width
		var inner: int = lv.width if horizontal else lv.height
		for o in outer:
			var run := 0
			for i in inner + 1:
				var cx: int = i if horizontal else o
				var cy: int = o if horizontal else i
				var edge := i < inner and _rock(cx, cy) and _open(cx + d[0], cy + d[1])
				if edge:
					run += 1
					continue
				if run >= 3:
					var s := i - run
					var h := _h(s, o, 7 + d[0] * 3 + d[1] * 5)
					if h % 6 != 0:
						_add_tube(horizontal, o, s, i, d, h, flick)
				run = 0
	_draw_signs()
	_draw_plates()

func _add_tube(horizontal: bool, o: int, s: int, e: int, d: Array, h: int, flick: float) -> void:
	var col := _pal(h >> 4)
	var gap := 0.5 + float(h % 3) * 0.25       # Enden kürzen, damit die Röhren nicht an Ecken zusammenlaufen
	var n := Vector2(d[0], d[1])
	var a: Vector2
	var b: Vector2
	if horizontal:
		var yy: float = (o + (1.0 if d[1] < 0 else 0.0)) * T + n.y * 1.5
		a = Vector2((s + gap) * T, yy)
		b = Vector2((e - gap) * T, yy)
	else:
		var xx: float = (o + (1.0 if d[0] < 0 else 0.0)) * T + n.x * 1.5
		a = Vector2(xx, (s + gap) * T)
		b = Vector2(xx, (e - gap) * T)
	if float(h % 100) / 100.0 < flick:
		tubes_anim.append([a, b, col, float(h % 997) * 0.013])
		return
	_tube(self, a, b, col, 1.0)
	_spill(self, a, b, n * 14.0, col, 1.0)

## Leuchtschilder in der Felsmasse: Rahmen mit Zeichen (Pfeil, Balken, Ring, Streifen).
func _draw_signs() -> void:
	var taken := {}
	var step: int = int(style.signs)
	for y in range(1, lv.height - 2):
		for x in range(1, lv.width - 3):
			var h := _h(x, y, 11)
			if h % step != 0:
				continue
			var ok := true
			for yy in range(y - 1, y + 3):                # 3x2 Zellen Fels plus ein Feld Rand ringsum
				for xx in range(x - 1, x + 4):
					if not _rock(xx, yy) or taken.has(Vector2i(xx, yy)):
						ok = false
			if not ok:
				continue
			for yy in range(y - 1, y + 3):
				for xx in range(x - 1, x + 4):
					taken[Vector2i(xx, yy)] = true
			_sign(Rect2(x * T + 2.0, y * T + 2.0, 3.0 * T - 4.0, 2.0 * T - 4.0), h)

## Kleine Schilder (2x1 Zellen) für schmale Felswände, in denen kein großes Schild Platz hat.
func _draw_plates() -> void:
	var step: int = maxi(int(style.signs) / 2, 4)
	for y in range(1, lv.height - 1):
		var x := 1
		while x < lv.width - 2:
			var h := _h(x, y, 17)
			if h % step == 0 and _rock(x, y) and _rock(x + 1, y) and _rock(x, y - 1) and _rock(x + 1, y - 1):
				var r := Rect2(x * T + 2.5, y * T + 3.5, 2.0 * T - 5.0, T - 7.0)
				var col := _pal(h >> 3)
				var pts := PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y), r.position])
				for i in 4:
					_tube(self, pts[i], pts[i + 1], col, 0.75)
				var col2 := _pal((h >> 3) + 1)
				var m := r.get_center()
				if (h >> 5) % 2 == 0:
					_tube(self, Vector2(r.position.x + 5, m.y), Vector2(r.end.x - 5, m.y), col2, 0.8)
				else:
					_tube(self, Vector2(m.x - 3, m.y - 2.5), Vector2(m.x + 3, m.y), col2, 0.8)
					_tube(self, Vector2(m.x - 3, m.y + 2.5), Vector2(m.x + 3, m.y), col2, 0.8)
				x += 3
			else:
				x += 1

func _sign(r: Rect2, h: int) -> void:
	var col := _pal(h >> 3)
	var pts := PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y), r.position])
	for i in 4:
		_tube(self, pts[i], pts[i + 1], col, 0.8)
	var mid := r.get_center()
	var col2 := _pal((h >> 3) + 1)
	match (h >> 6) % 4:
		0:                                                 # Pfeil
			_tube(self, Vector2(r.position.x + 8, mid.y), Vector2(r.end.x - 8, mid.y), col2, 0.9)
			_tube(self, Vector2(r.end.x - 16, mid.y - 7), Vector2(r.end.x - 8, mid.y), col2, 0.9)
			_tube(self, Vector2(r.end.x - 16, mid.y + 7), Vector2(r.end.x - 8, mid.y), col2, 0.9)
		1:                                                 # Balkenreihe
			for i in 4:
				var yy := r.position.y + 7.0 + i * (r.size.y - 14.0) / 3.0
				_tube(self, Vector2(r.position.x + 8, yy), Vector2(r.end.x - 8 - float((h >> (i + 8)) % 3) * 9.0, yy), col2, 0.8)
		2:                                                 # Ring
			var pc := PackedVector2Array()
			for i in 17:
				pc.append(mid + Vector2(cos(TAU * i / 16.0), sin(TAU * i / 16.0)) * (r.size.y * 0.32))
			for i in 16:
				_tube(self, pc[i], pc[i + 1], col2, 0.85)
		_:                                                 # Schrägstreifen
			for i in 4:
				var xx := r.position.x + 9.0 + i * 8.0
				_tube(self, Vector2(xx, r.end.y - 6), Vector2(xx + 8, r.position.y + 6), col2, 0.8)

# ---------------------------------------------------------------- Glas

func _draw_glass() -> void:
	var ph := 3
	var cyan := Color("#9fe8ff")
	var white := Color("#ffffff")
	# Scheibenfelder (4x3, danach 2x3 Zellen), die vollständig im Fels liegen; flexible Suche, damit auch schmale Pfeiler Glas bekommen
	var taken := {}
	var cand: Array = []
	for pw in [4, 2]:
		for py in range(0, lv.height - ph + 1):
			for px in range(0, lv.width - pw + 1):
				var ok := true
				for yy in ph:
					for xx in pw:
						if not _rock(px + xx, py + yy) or taken.has(Vector2i(px + xx, py + yy)):
							ok = false
				if not ok:
					continue
				for yy in ph:
					for xx in pw:
						taken[Vector2i(px + xx, py + yy)] = true
				cand.append([px, py, pw])
	for cp in cand:
		var px: int = cp[0]
		var py: int = cp[1]
		var pw: int = cp[2]
		if true:
			var r := Rect2(px * T, py * T, pw * T, ph * T)
			panes.append([r, float(px) * 0.11 + float(py) * 0.07])
			var top := Color(cyan.r, cyan.g, cyan.b, 0.30)
			var bot := Color(cyan.r, cyan.g, cyan.b, 0.0)
			draw_polygon(PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]), PackedColorArray([top, top, bot, bot]))
			draw_rect(r, Color(0.7, 0.88, 1.0, 0.55), false, 1.34)       # Rahmen
			var h := _h(px, py, 5)
			var o := float(h % 20)                                            # zwei Spiegelstreifen schräg über der Scheibe
			for k in 2:
				var x0 := r.position.x + 8.0 + o + k * 17.0
				var seg := PackedVector2Array([Vector2(x0, r.end.y - 3.0), Vector2(x0 + 10.0, r.end.y - 3.0), Vector2(x0 + 24.0, r.position.y + 3.0), Vector2(x0 + 14.0, r.position.y + 3.0)])
				var sx := PackedVector2Array()
				for p in seg:
					sx.append(Vector2(clampf(p.x, r.position.x + 2.0, r.end.x - 2.0), p.y))
				draw_colored_polygon(sx, Color(white.r, white.g, white.b, 0.14 + 0.06 * k))
	# Glaskanten an der Fassade: heller Doppelstrich zum offenen Raum hin
	for y in lv.height:
		for x in lv.width:
			if not _rock(x, y):
				continue
			var gx := x * T
			var gy := y * T
			if _open(x, y - 1):
				draw_line(Vector2(gx, gy - PX), Vector2(gx + T, gy - PX), Color(cyan.r, cyan.g, cyan.b, 0.75), 1.34)
				draw_line(Vector2(gx, gy + 2.0), Vector2(gx + T, gy + 2.0), Color(white.r, white.g, white.b, 0.18), PX)
			if _open(x, y + 1):
				draw_line(Vector2(gx, gy + T + PX), Vector2(gx + T, gy + T + PX), Color(cyan.r, cyan.g, cyan.b, 0.4), 1.34)
			if _open(x - 1, y):
				draw_line(Vector2(gx - PX, gy), Vector2(gx - PX, gy + T), Color(cyan.r, cyan.g, cyan.b, 0.6), 1.34)
			if _open(x + 1, y):
				draw_line(Vector2(gx + T + PX, gy), Vector2(gx + T + PX, gy + T), Color(cyan.r, cyan.g, cyan.b, 0.3), 1.34)

# ---------------------------------------------------------------- Animation

class Anim extends Node2D:
	var owner_style: Node2D

	func _draw() -> void:
		var s := owner_style
		if s == null or s.lv == null:
			return
		if s.kind == "neon":
			for e in s.tubes_anim:
				var ph: float = e[3]
				var f := 1.0
				if not Settings.values.reduce_motion:
					var w := sin(s.t * 9.0 + ph * 40.0) * sin(s.t * 2.3 + ph * 17.0)
					f = 0.25 if w < -0.55 else 1.0 - 0.12 * absf(sin(s.t * 31.0 + ph))   # kurzer Aussetzer, sonst leichtes Surren
				var a: Vector2 = e[0]
				var b: Vector2 = e[1]
				var col: Color = e[2]
				s._tube(self, a, b, col, f)
				var n := Vector2(0, 0)
				if absf(a.y - b.y) < 0.01:
					n = Vector2(0, 1.0 if fmod(a.y, 16.0) < 8.0 else -1.0)
				else:
					n = Vector2(1.0 if fmod(a.x, 16.0) < 8.0 else -1.0, 0)
				s._spill(self, a, b, n * 14.0, col, f)
		elif s.kind == "glass":
			var sweep: float = s.t * 140.0 if not Settings.values.reduce_motion else 0.0
			var span: float = s.lv.pixel_size().x + 400.0
			for p in s.panes:
				var r: Rect2 = p[0]
				var d := absf(fposmod(r.get_center().x + r.get_center().y * 0.6 - sweep, span) - 200.0)    # Reflexband wandert diagonal über die Fassade
				if d < 120.0:
					var a := (1.0 - d / 120.0) * 0.16
					draw_rect(r.grow(-1.0), Color(0.85, 0.97, 1.0, a))
