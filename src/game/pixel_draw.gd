class_name PixelDraw
extends RefCounted
## Zeichenhilfen im Pixelraster: Alles liegt auf einem Raster von 1/n Einheit (= ein Bildschirmpunkt), ohne Kantenglättung. `n` ist die Pixelgröße
## des Bildschirms (PixelScale: 720p = 2 … 2160p = 6), je Zeichenfläche aus ihrer Skalierung bestimmt, damit Linien, Ringe, Dornen, Wimpel und
## Flammen in jeder Auflösung auf ganzen Bildpunkten liegen. Maße und Formen in Einheiten bleiben gleich.
## Linien, Ringe und Bögen werden aus lauter solchen Rechtecken gesetzt (waagerechte und senkrechte Läufe zusammengefasst, damit es wenige
## Zeichenaufrufe bleiben). Die Taxi- und Hintergrundgrafik nutzt dasselbe Raster.

const PX := 1.0 / 3.0                       # Raster der Größe 3 (Vorgabe, wo keine Zeichenfläche bekannt ist)

static var _ring_cache := {}
static var _seg_cache := {}              # Ringe/Scheiben als fertige Liniensegmente je (Radien, Pixelgröße): ein Zeichenaufruf statt eines je Zeile

## Läufe einer Zeile als Liniensegmente sammeln und in einem einzigen Aufruf zeichnen (Runde 83: Magnetfelder in Level 41 kosteten
## sonst bis zu 9 ms je Bild, weil jede Zeile eines Rings ein eigenes Rechteck war). Breite = Dicke des Laufs in Einheiten.
static func _flush(ci: CanvasItem, pts: PackedVector2Array, col: Color, width: float) -> void:
	if pts.size() >= 2:
		ci.draw_multiline(pts, col, width)

## Auf das Raster von 1/3 Einheit runden.
static func snap(v: float, n := 3) -> float:
	return roundf(v * float(n)) / float(n)

static func snap2(v: Vector2, n := 3) -> Vector2:
	return Vector2(snap(v.x, n), snap(v.y, n))

## Pixelgröße der Zeichenfläche `ci` (2 … 6) und ihr Bildpunkt in Einheiten.
static func n_of(ci: CanvasItem) -> int:
	return PixelScale.size_for(ci)

static func px_of(ci: CanvasItem) -> float:
	return 1.0 / float(PixelScale.size_for(ci))

## Auf das Raster der Zeichenfläche runden.
static func snap_to(ci: CanvasItem, v: float) -> float:
	return snap(v, PixelScale.size_for(ci))

static func snap2_to(ci: CanvasItem, v: Vector2) -> Vector2:
	return snap2(v, PixelScale.size_for(ci))

## Linienbreite (Einheiten) auf ganze Bildpunkte der Zeichenfläche runden, mindestens ein Bildpunkt.
static func wsnap(ci: CanvasItem, w: float) -> float:
	var nf := float(n_of(ci))
	return maxf(roundf(w * nf), 1.0) / nf

## Strichstärke: Aufrufer geben sie in Bildpunkten der Größe 3 an (1/3 Einheit); gerechnet wird in Bildpunkten der Größe n, mindestens 1
## (1 Punkt bleibt 1 Punkt bis 1440p, darüber 2, wie beim Taxi; 3 Punkte = 1 Einheit bleiben 1 Einheit).
static func scaled_w(w3: int, n: int) -> int:
	return maxi(1, roundi(float(w3) * float(n) / 3.0))

## Ein Bildpunkt-Rechteck (Zellen x, y, Breite, Höhe in Bildpunkten) zeichnen.
static func _cells(ci: CanvasItem, x: int, y: int, w: int, h: int, col: Color) -> void:
	var p := px_of(ci)
	ci.draw_rect(Rect2(float(x) * p, float(y) * p, float(w) * p, float(h) * p), col)

## Gerade Linie von a nach b, `w_px` Bildpunkte dick (Vielfache von 1/3 Einheit). Waagerechte und senkrechte Linien sind ein einziges Rechteck,
## schräge werden Lauf für Lauf gesetzt.
static func line(ci: CanvasItem, a: Vector2, b: Vector2, col: Color, w_px := 1) -> void:
	var nf := float(n_of(ci))
	var x0 := roundi(a.x * nf)
	var y0 := roundi(a.y * nf)
	var x1 := roundi(b.x * nf)
	var y1 := roundi(b.y * nf)
	w_px = scaled_w(w_px, int(nf))
	var lo := -(w_px / 2)                           # die Dicke wächst nach beiden Seiten um die Mitte
	var p := 1.0 / nf
	var pts := PackedVector2Array()
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
				_seg_h(pts, run_start, x, cy, lo, w_px, p)
				break
			err -= dy
			x += sx
			if err < 0:
				_seg_h(pts, run_start, x - sx, cy, lo, w_px, p)
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
				_seg_v(pts, cx, run_start2, y, lo, w_px, p)
				break
			err2 -= dx
			y += sy
			if err2 < 0:
				_seg_v(pts, cx, run_start2, y - sy, lo, w_px, p)
				cx += sx
				err2 += dy
				run_start2 = y
	_flush(ci, pts, col, float(w_px) * p)

## Waagerechter Lauf (Bildpunkte xa…xb in Zeile y, Dicke w) als Segment längs der Mitte der Dicke.
static func _seg_h(pts: PackedVector2Array, xa: int, xb: int, y: int, lo: int, w: int, p: float) -> void:
	var yc := (float(y + lo) + float(w) * 0.5) * p
	pts.append(Vector2(float(mini(xa, xb)) * p, yc))
	pts.append(Vector2(float(maxi(xa, xb) + 1) * p, yc))

## Senkrechter Lauf (Bildpunkte ya…yb in Spalte x, Dicke w).
static func _seg_v(pts: PackedVector2Array, x: int, ya: int, yb: int, lo: int, w: int, p: float) -> void:
	var xc := (float(x + lo) + float(w) * 0.5) * p
	pts.append(Vector2(xc, float(mini(ya, yb)) * p))
	pts.append(Vector2(xc, float(maxi(ya, yb) + 1) * p))

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
	var nf := float(n_of(ci))
	var x0 := roundi(r.position.x * nf)
	var y0 := roundi(r.position.y * nf)
	var x1 := maxi(roundi(r.end.x * nf), x0 + 1)
	var y1 := maxi(roundi(r.end.y * nf), y0 + 1)
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
	var nf := float(n_of(ci))
	var cx := roundi(c.x * nf)
	var cy := roundi(c.y * nf)
	for run in runs:
		_cells(ci, cx + int(run[0]), cy + int(run[1]), int(run[2]), int(run[3]), col)

## Kreisring mit Radius `r` (Einheiten) um `c`, `w_px` Bildpunkte dick, gestuft.
static func ring(ci: CanvasItem, c: Vector2, r: float, col: Color, w_px := 1) -> void:
	var nf := float(n_of(ci))
	var r_px := maxf(r * nf, 1.0)
	var half := float(scaled_w(w_px, int(nf))) * 0.5
	_ring_draw(ci, c, maxf(r_px - half, 0.0), r_px + half, col)

## Ring/Scheibe aus dem Zwischenspeicher: Zeilenläufe als Segmente relativ zur Mitte, verschoben in einem Aufruf gezeichnet.
static func _ring_draw(ci: CanvasItem, c: Vector2, r_in: float, r_out: float, col: Color) -> void:
	var n := n_of(ci)
	var nf := float(n)
	var key := Vector3i(roundi(r_in * 2.0), roundi(r_out * 2.0), n)
	var pts: PackedVector2Array
	if _seg_cache.has(key):
		pts = _seg_cache[key]
	else:
		var p := 1.0 / nf
		for run in ring_runs(r_in, r_out):
			var yc := (float(run[1]) + 0.5) * p
			pts.append(Vector2(float(run[0]) * p, yc))
			pts.append(Vector2(float(int(run[0]) + int(run[2])) * p, yc))
		if _seg_cache.size() > 4000:
			_seg_cache.clear()
		_seg_cache[key] = pts
	var off := Vector2(float(roundi(c.x * nf)), float(roundi(c.y * nf))) / nf
	_flush(ci, Transform2D(0.0, off) * pts, col, 1.0 / nf)

## Gefüllte Scheibe, gestuft.
static func disc(ci: CanvasItem, c: Vector2, r: float, col: Color) -> void:
	_ring_draw(ci, c, 0.0, maxf(r * float(n_of(ci)), 1.0), col)

## Kreisbogen (Winkel im Bogenmaß wie `draw_arc`, 0 = rechts, im Uhrzeigersinn positiv), `w_px` Bildpunkte dick. Für kleine Radien (Takt-Anzeige).
static func arc(ci: CanvasItem, c: Vector2, r: float, a0: float, a1: float, col: Color, w_px := 1) -> void:
	var nf := float(n_of(ci))
	var r_px := maxf(r * nf, 1.0)
	var cx := roundi(c.x * nf)
	var cy := roundi(c.y * nf)
	w_px = scaled_w(w_px, int(nf))
	var n := maxi(int(ceilf(absf(a1 - a0) * r_px * 1.5)), 2)          # ein Schritt kürzer als ein Bildpunkt
	var lo := -(w_px / 2)
	var pp := 1.0 / nf
	var pts := PackedVector2Array()
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
			_seg_h(pts, run_x, run_x + run_w - 1, run_y, lo, w_px, pp)
		run_x = p.x
		run_y = p.y
		run_w = 1
	if run_w > 0:
		_seg_h(pts, run_x, run_x + run_w - 1, run_y, lo, w_px, pp)
	_flush(ci, pts, col, float(w_px) * pp)

## Strahl aus Pixelzeilen (Triebwerksflamme): Spitze in Richtung `dir` (achsenparallel), vom Ansatz `base` aus `length` lang und `half_w` halb breit;
## die Breite nimmt gestuft ab, jede Zeile ist ein Rechteck.
static func jet(ci: CanvasItem, base: Vector2, dir: Vector2, length: float, half_w: float, col: Color) -> void:
	var nf := float(n_of(ci))
	var len_px := maxi(roundi(length * nf), 1)
	var hw_px := maxi(roundi(half_w * nf), 1)
	var bx := roundi(base.x * nf)
	var by := roundi(base.y * nf)
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
	var nf := float(n_of(ci))
	var cx := roundi(c.x * nf)
	var cy := roundi(c.y * nf)
	var r_px := r * nf
	for i in n:
		var a := a0 + TAU * float(i) / float(n)
		_cells(ci, cx + roundi(cos(a) * r_px), cy + roundi(sin(a) * r_px), 1, 1, col)
