extends Node2D
## Optische Sonderbehandlung einzelner Level nach ihrem Namen (rein Optik, Physik und Kollision bleiben unberührt).
## "neon": Leuchtröhren entlang der Felskanten, Leuchtreklame in der Felsmasse (Schrift und Bildzeichen aus Röhren auf dunklen Tafeln, siehe
## neon_signs.gd), farbiges Licht der Schilder auf Fels und Taxi, flackernde Röhren (Neonallee, Neonfinale, Neonlabyrinth).
## "glass": Glasfassade mit Scheibenfeldern, Rahmen, Spiegelungen und wanderndem Lichtreflex.
## Gezeichnet wird additiv und unbeleuchtet (Tafeln normal), zwischen Fels und Requisiten: Plattformen, Taxi und Gefahren bleiben darüber gut lesbar.
## Alle Röhren liegen im Pixelraster (1/3 Einheit, wie Runde 57).

const T := 16.0
const PX := 1.0 / 3.0

## Stil je Level-ID. "pal" = Farbfamilie der Röhren, "max" = höchstens so viele Schilder, "flick" = Anteil flackernder Kantenröhren.
const STYLES := {
	"S2-02": {"kind": "neon", "pal": ["#ff4fd8", "#4fd8ff", "#b46bff"], "max": 8, "flick": 0.10},                                    # Neonallee: ruhige Reklameallee
	"S2-06": {"kind": "neon", "pal": ["#ff4fd8", "#ffb347", "#4fd8ff", "#ff6bb5"], "max": 11, "flick": 0.22},                        # Neonfinale: dichter, heller, nervöser
	"S2-08": {"kind": "neon", "pal": ["#4fd8ff", "#7b6bff", "#42ffc8"], "max": 9, "flick": 0.16},                                    # Neonlabyrinth: kühles Blau-Grün, ruhig an den Strahlen
	"S2-11": {"kind": "glass"},
}

var kind := ""
var style: Dictionary = {}
var lv: LevelData
var anim: Node2D
var tubes_anim: Array = []         # [a, b, Color, Phase] flackernde Röhren
var panes: Array = []              # [Rect2, Phase] Scheibenfelder für den wandernden Reflex
var signs: Array = []              # Leuchtreklame (NeonSigns.plan), je Element zusätzlich "tex" und "at"
var boards: Node2D                 # dunkle Tafeln (normal gemischt, unter den Röhren)
var lights: Array = []             # [PointLight2D, Schild, Grundenergie]
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
	signs.clear()
	for l in lights:
		(l[0] as Node).queue_free()
	lights.clear()
	visible = kind != ""
	if boards == null:
		boards = Boards.new()
		boards.owner_style = self
		add_child(boards)
	if kind == "neon":
		_build_signs()
	if anim == null:
		anim = Anim.new()
		anim.owner_style = self
		anim.material = material if material != null else null
		add_child(anim)
	if material != null:
		anim.material = material
	set_process(kind != "")
	queue_redraw()
	boards.queue_redraw()
	anim.queue_redraw()

func _build_signs() -> void:
	signs = NeonSigns.plan(lv, style)
	var Fx := load("res://src/game/fx.gd")
	for s in signs:
		for it in s.items:
			var b: Array = NeonSigns.bake(it)
			if not b.is_empty():
				it["tex"] = b[0]
				it["at"] = b[1]
		var r: Rect2 = s.board
		var big: bool = s.kind == "main"
		var l: PointLight2D = Fx.make_light(s.col, maxf(r.size.x, r.size.y) * 0.9 + 26.0, 0.0)
		l.position = r.get_center()
		add_child(l)
		lights.append([l, s, 1.1 if big else 0.75])

## Helligkeit eines Elements (Zeichen `g`) eines Schilds zur Zeit t: ruhig mit leisem Surren, ein sterbender Buchstabe, oder Aus-und-Einschalten
## Zeichen für Zeichen (alle 13–18 s). Bei „Weniger Bewegung“ immer voll.
func sign_level(s: Dictionary, g: int) -> float:
	if Settings.values.reduce_motion:
		return 1.0
	var ph: float = s.phase
	var hum := 1.0 - 0.05 * absf(sin(t * 23.0 + ph * 7.0))
	match String(s.mode):
		"dying":
			var dead := int(ph * 100.0) % maxi(s.items.size() - 1, 1)
			if g == dead:
				var w := sin(t * 7.0 + ph * 40.0) * sin(t * 1.9 + ph * 17.0)
				return 0.12 if w < -0.5 else hum * (0.75 + 0.25 * absf(sin(t * 3.1 + ph)))
		"cycle":
			var period := 13.0 + fmod(ph * 10.0, 5.0)
			var u := fmod(t + ph * 50.0, period)
			if u < 0.6:
				return 0.1
			if g >= 0 and u < 0.6 + 0.16 * float(g + 1):
				return 0.1
	return hum

func _process_lights() -> void:
	for e in lights:
		var l: PointLight2D = e[0]
		var s: Dictionary = e[1]
		var sum := 0.0
		for it in s.items:
			sum += sign_level(s, int(it.glyph))
		l.energy = float(e[2]) * sum / float(maxi(s.items.size(), 1))

func _process(delta: float) -> void:
	if Settings.values.reduce_motion:
		return
	t += delta
	_process_lights()
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

## Eine Leuchtröhre von a nach b im Pixelraster (additiv): Schein in zwei Stufen (9 und 5 Bildpunkte), Röhre 3 Bildpunkte, heller Kern 1 Bildpunkt.
func _tube(c: CanvasItem, a: Vector2, b: Vector2, col: Color, k: float) -> void:
	PixelDraw.line(c, a, b, Color(col.r, col.g, col.b, 0.10 * k), 9)
	PixelDraw.line(c, a, b, Color(col.r, col.g, col.b, 0.22 * k), 5)
	PixelDraw.line(c, a, b, Color(col.r, col.g, col.b, 0.9 * k), 3)
	PixelDraw.line(c, a, b, Color(1, 1, 1, 0.75 * k), 1)

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
			for sg in s.signs:
				for it in sg.items:
					if not it.has("tex"):
						continue
					var f: float = s.sign_level(sg, int(it.glyph)) * float(it.get("dim", 1.0))
					var tx: Texture2D = it.tex
					draw_texture_rect(tx, Rect2(it.at, tx.get_size() / float(NeonSigns.PPU)), false, Color(1, 1, 1, f))
				if sg.mode == "chase":
					_chase(sg, s)
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

	## Lauflicht im Rahmen des Hauptschilds: Lämpchen alle 4 Einheiten, jedes dritte leuchtet, die Reihe wandert (bei „Weniger Bewegung“ steht sie).
	func _chase(sg: Dictionary, s: Node2D) -> void:
		var r: Rect2 = (sg.board as Rect2).grow(-2.0)
		var per := 2.0 * (r.size.x + r.size.y)
		var n := int(per / 4.0)
		var shift := 0 if Settings.values.reduce_motion else int(s.t * 7.0)
		var col: Color = sg.col2
		for i in n:
			var d := float(i) * per / float(n)
			var p: Vector2
			if d < r.size.x:
				p = r.position + Vector2(d, 0)
			elif d < r.size.x + r.size.y:
				p = Vector2(r.end.x, r.position.y + d - r.size.x)
			elif d < 2.0 * r.size.x + r.size.y:
				p = Vector2(r.end.x - (d - r.size.x - r.size.y), r.end.y)
			else:
				p = Vector2(r.position.x, r.end.y - (d - 2.0 * r.size.x - r.size.y))
			p = PixelDraw.snap2(p)
			var on := (i + shift) % 3 == 0
			var a := 1.0 if on else 0.22
			PixelDraw.rect(self, Rect2(p - Vector2(1, 1), Vector2(2, 2)), Color(col.r, col.g, col.b, 0.25 * a))
			PixelDraw.rect(self, Rect2(p - Vector2(1, 1) / 3.0, Vector2(2, 2) / 3.0), Color(1, 1, 1, 0.9 * a) if on else Color(col.r, col.g, col.b, 0.5))

## Dunkle Tafeln der Leuchtreklame (normal gemischt, vom Licht der Welt beleuchtet): Schatten, Platte, Kanten, Schrauben, Halter.
class Boards extends Node2D:
	var owner_style: Node2D

	func _draw() -> void:
		var s := owner_style
		if s == null or s.kind != "neon":
			return
		for sg in s.signs:
			var r: Rect2 = sg.board
			PixelDraw.rect(self, Rect2(r.position + Vector2(1, 1), r.size), Color(0, 0, 0, 0.45))
			if sg.kind == "kana":                                                   # Halter oben und unten
				for x in [r.position.x + 3.0, r.end.x - 5.0]:
					PixelDraw.rect(self, Rect2(x, r.position.y - 3.0, 2.0, 3.0), Color(0.2, 0.19, 0.27))
					PixelDraw.rect(self, Rect2(x, r.end.y, 2.0, 3.0), Color(0.2, 0.19, 0.27))
			PixelDraw.rect(self, r, Color(0.05, 0.04, 0.085))
			PixelDraw.rect(self, Rect2(r.position, Vector2(r.size.x, 1.0 / 3.0)), Color(0.2, 0.18, 0.3))
			PixelDraw.rect(self, Rect2(r.position, Vector2(1.0 / 3.0, r.size.y)), Color(0.14, 0.12, 0.22))
			PixelDraw.rect(self, Rect2(Vector2(r.position.x, r.end.y - 1.0 / 3.0), Vector2(r.size.x, 1.0 / 3.0)), Color(0.015, 0.01, 0.03))
			PixelDraw.rect(self, Rect2(Vector2(r.end.x - 1.0 / 3.0, r.position.y), Vector2(1.0 / 3.0, r.size.y)), Color(0.02, 0.015, 0.04))
			if sg.kind == "main":
				PixelDraw.rect(self, r.grow(-4.0), Color(0.07, 0.05, 0.12))
			for c in [r.position + Vector2(1.34, 1.34), Vector2(r.end.x - 2.0, r.position.y + 1.34), Vector2(r.position.x + 1.34, r.end.y - 2.0), r.end - Vector2(2.0, 2.0)]:
				PixelDraw.rect(self, Rect2(PixelDraw.snap2(c), Vector2(2.0, 2.0) / 3.0), Color(0.36, 0.34, 0.46))
