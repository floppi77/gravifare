class_name PixelDraw
extends RefCounted
## Zeichenhilfen im Pixelraster: Alles liegt auf einem Raster von 1/3 Einheit (= ein Bildschirmpunkt bei 1080p), ohne Kantenglättung.
## Linien, Ringe und Bögen werden aus lauter solchen Rechtecken gesetzt (waagerechte und senkrechte Läufe zusammengefasst, damit es wenige
## Zeichenaufrufe bleiben). Die Taxi- und Hintergrundgrafik nutzt dasselbe Raster.

const PX := 1.0 / 3.0

static var _ring_cache := {}

## Auf das Raster von 1/3 Einheit runden.
static func snap(v: float) -> float:
	return roundf(v * 3.0) / 3.0

static func snap2(v: Vector2) -> Vector2:
	return Vector2(snap(v.x), snap(v.y))

## Ein Bildpunkt-Rechteck (Zellen x, y, Breite, Höhe in Bildpunkten) zeichnen.
static func _cells(ci: CanvasItem, x: int, y: int, w: int, h: int, col: Color) -> void:
	ci.draw_rect(Rect2(float(x) * PX, float(y) * PX, float(w) * PX, float(h) * PX), col)

## Gerade Linie von a nach b, `w_px` Bildpunkte dick (Vielfache von 1/3 Einheit). Waagerechte und senkrechte Linien sind ein einziges Rechteck,
## schräge werden Lauf für Lauf gesetzt.
static func line(ci: CanvasItem, a: Vector2, b: Vector2, col: Color, w_px := 1) -> void:
	var x0 := roundi(a.x * 3.0)
	var y0 := roundi(a.y * 3.0)
	var x1 := roundi(b.x * 3.0)
	var y1 := roundi(b.y * 3.0)
	var lo := -(w_px / 2)                           # die Dicke wächst nach beiden Seiten um die Mitte
	if y0 == y1:
		_cells(ci, mini(x0, x1), y0 + lo, absi(x1 - x0) + 1, w_px, col)
		return
	if x0 == x1:
		_cells(ci, x0 + lo, mini(y0, y1), w_px, absi(y1 - y0) + 1, col)
		return
	var dx := absi(x1 - x0)
	var dy := absi(y1 - y0)
	var sx := 1 if x1 > x0 else -1
	var sy := 1 if y1 > y0 else -1
	if dx >= dy:                                    # flacher: Läufe in x je Zeile
		var run_start := x0
		var cy := y0
		var err := dx / 2
		var x := x0
		while true:
			if x == x1:
				_run_h(ci, run_start, x, cy, lo, w_px, col)
				break
			err -= dy
			x += sx
			if err < 0:
				_run_h(ci, run_start, x - sx, cy, lo, w_px, col)
				cy += sy
				err += dx
				run_start = x
	else:                                           # steiler: Läufe in y je Spalte
		var run_start2 := y0
		var cx := x0
		var err2 := dy / 2
		var y := y0
		while true:
			if y == y1:
				_run_v(ci, cx, run_start2, y, lo, w_px, col)
				break
			err2 -= dx
			y += sy
			if err2 < 0:
				_run_v(ci, cx, run_start2, y - sy, lo, w_px, col)
				cx += sx
				err2 += dy
				run_start2 = y

static func _run_h(ci: CanvasItem, xa: int, xb: int, y: int, lo: int, w: int, col: Color) -> void:
	_cells(ci, mini(xa, xb), y + lo, absi(xb - xa) + 1, w, col)

static func _run_v(ci: CanvasItem, x: int, ya: int, yb: int, lo: int, w: int, col: Color) -> void:
	_cells(ci, x + lo, mini(ya, yb), w, absi(yb - ya) + 1, col)

## Linienzug.
static func polyline(ci: CanvasItem, pts: PackedVector2Array, col: Color, w_px := 1) -> void:
	for i in range(pts.size() - 1):
		line(ci, pts[i], pts[i + 1], col, w_px)

## Gefülltes Rechteck, an das Raster angelegt (Kanten auf Vielfachen von 1/3 Einheit, mindestens ein Bildpunkt).
static func rect(ci: CanvasItem, r: Rect2, col: Color) -> void:
	var x0 := roundi(r.position.x * 3.0)
	var y0 := roundi(r.position.y * 3.0)
	var x1 := maxi(roundi(r.end.x * 3.0), x0 + 1)
	var y1 := maxi(roundi(r.end.y * 3.0), y0 + 1)
	_cells(ci, x0, y0, x1 - x0, y1 - y0, col)

## Bildpunkte eines Rings (Innen- und Außenradius in Bildpunkten, `r_in` = 0 ergibt eine Scheibe) als Läufe [x, y, w, h] relativ zur Mitte, in Bildpunkten:
## je Zeile ein oder zwei Rechtecke, Bildpunkte nach ihrem Mittelpunkt. Gleiche Radien teilen sich die Liste.
static func ring_runs(r_in: float, r_out: float) -> Array:
	var key := Vector2i(roundi(r_in * 2.0), roundi(r_out * 2.0))
	if _ring_cache.has(key):
		return _ring_cache[key]
	var runs: Array = []
	var ro2 := r_out * r_out
	var ri2 := r_in * r_in
	var ymax := ceili(r_out)
	for y in range(-ymax, ymax):
		var yy := float(y) + 0.5
		if yy * yy > ro2:
			continue
		var b := sqrt(ro2 - yy * yy)
		var a := sqrt(ri2 - yy * yy) if ri2 - yy * yy > 0.0 else 0.0
		var xa := ceili(a - 0.5)
		var xb := floori(b - 0.5)
		if xb < xa:
			continue
		if xa <= 0:
			runs.append([-1 - xb, y, 2 * xb + 2, 1])                  # Zeile über die Mitte (oben und unten am Ring)
		else:
			runs.append([xa, y, xb - xa + 1, 1])
			runs.append([-1 - xb, y, xb - xa + 1, 1])
	_ring_cache[key] = runs
	return runs

static func _runs(ci: CanvasItem, c: Vector2, runs: Array, col: Color) -> void:
	var cx := roundi(c.x * 3.0)
	var cy := roundi(c.y * 3.0)
	for run in runs:
		_cells(ci, cx + int(run[0]), cy + int(run[1]), int(run[2]), int(run[3]), col)

## Kreisring mit Radius `r` (Einheiten) um `c`, `w_px` Bildpunkte dick, gestuft.
static func ring(ci: CanvasItem, c: Vector2, r: float, col: Color, w_px := 1) -> void:
	var r_px := maxf(r * 3.0, 1.0)
	var half := float(w_px) * 0.5
	_runs(ci, c, ring_runs(maxf(r_px - half, 0.0), r_px + half), col)

## Gefüllte Scheibe, gestuft.
static func disc(ci: CanvasItem, c: Vector2, r: float, col: Color) -> void:
	_runs(ci, c, ring_runs(0.0, maxf(r * 3.0, 1.0)), col)

## Kreisbogen (Winkel im Bogenmaß wie `draw_arc`, 0 = rechts, im Uhrzeigersinn positiv), `w_px` Bildpunkte dick. Für kleine Radien (Takt-Anzeige).
static func arc(ci: CanvasItem, c: Vector2, r: float, a0: float, a1: float, col: Color, w_px := 1) -> void:
	var r_px := maxf(r * 3.0, 1.0)
	var cx := roundi(c.x * 3.0)
	var cy := roundi(c.y * 3.0)
	var n := maxi(int(ceilf(absf(a1 - a0) * r_px * 1.5)), 2)          # ein Schritt kürzer als ein Bildpunkt
	var lo := -(w_px / 2)
	var last := Vector2i(1 << 30, 1 << 30)
	var run_x := 0
	var run_w := 0
	var run_y := 0
	for i in n + 1:
		var a := lerpf(a0, a1, float(i) / float(n))
		var p := Vector2i(cx + roundi(cos(a) * r_px), cy + roundi(sin(a) * r_px))
		if p == last:
			continue
		last = p
		if run_w > 0 and p.y == run_y and p.x == run_x + run_w:      # waagerecht anschließend: Lauf verlängern
			run_w += 1
			continue
		if run_w > 0:
			_cells(ci, run_x, run_y + lo, run_w, w_px, col)
		run_x = p.x
		run_y = p.y
		run_w = 1
	if run_w > 0:
		_cells(ci, run_x, run_y + lo, run_w, w_px, col)

## Strahl aus Pixelzeilen (Triebwerksflamme): Spitze in Richtung `dir` (achsenparallel), vom Ansatz `base` aus `length` lang und `half_w` halb breit;
## die Breite nimmt gestuft ab, jede Zeile ist ein Rechteck.
static func jet(ci: CanvasItem, base: Vector2, dir: Vector2, length: float, half_w: float, col: Color) -> void:
	var len_px := maxi(roundi(length * 3.0), 1)
	var hw_px := maxi(roundi(half_w * 3.0), 1)
	var bx := roundi(base.x * 3.0)
	var by := roundi(base.y * 3.0)
	for k in range(-hw_px, hw_px):                    # Zeile k (quer zur Richtung)
		var f := 1.0 - (absf(float(k) + 0.5) / float(hw_px))
		var ln := maxi(roundi(float(len_px) * f), 1)
		if absf(dir.x) > absf(dir.y):
			var sx := signi(roundi(dir.x))
			_cells(ci, bx if sx > 0 else bx - ln, by + k, ln, 1, col)
		else:
			var sy := signi(roundi(dir.y))
			_cells(ci, bx + k, by if sy > 0 else by - ln, 1, ln, col)

## Punktreihe auf einem Kreis (`n` Punkte, je ein Bildpunkt), beginnend bei Winkel `a0`.
static func dots(ci: CanvasItem, c: Vector2, r: float, n: int, a0: float, col: Color) -> void:
	var cx := roundi(c.x * 3.0)
	var cy := roundi(c.y * 3.0)
	var r_px := r * 3.0
	for i in n:
		var a := a0 + TAU * float(i) / float(n)
		_cells(ci, cx + roundi(cos(a) * r_px), cy + roundi(sin(a) * r_px), 1, 1, col)
