class_name PixelScale
extends RefCounted
## Pixelgröße des Bildschirms (Runde 72): Das Spiel rechnet in Welteinheiten (640 × 360) und skaliert ganzzahlig, 720p = 2, 1080p = 3, 1440p = 4,
## 1800p = 5, 2160p = 6 Bildschirmpunkte je Einheit. Jede Ansicht, die Grafik 1:1 zeigen will, fragt hier nach der Größe `n` und
##   - legt ihr Zeichenraster auf 1/n Einheit (PixelDraw, `px()`),
##   - nimmt aus einem Blatt die Fassung, die für genau diese Größe gerastert wurde (`sheet_rect()`).
##
## Blattformat (Erzeuger in tools/art, z. B. gen_taxi.py): Die Größen 2, 3, 4, 5, 6 liegen untereinander, die Einheit eines Bildes ist
## `units` (Breite × Höhe in Welteinheiten). Das Blatt ist so 6·units.x breit und 20·units.y hoch; die Fassung für n beginnt links, bei
## y = units.y · (Summe der kleineren Größen) und ist units · n Bildpunkte groß. Bei Bildern, deren Kantenlänge nicht ein Vielfaches von n ist
## (Aufkleber), gibt der Aufrufer die Höhe je Größe selbst an (`sheet_y`).

const SIZES: Array[int] = [2, 3, 4, 5, 6]
const DEFAULT := 3

static var _cache := {}            # Knoten-ID → [Bild, Größe]: höchstens eine Abfrage je Knoten und Bild

## Bildschirmpunkte je Welteinheit, mit denen `node` gerade gezeichnet wird (Fensterskalierung × Kamerazoom).
static func of(node: CanvasItem) -> float:
	if node == null or not node.is_inside_tree():
		return float(DEFAULT)
	var vp := node.get_viewport()
	return absf(vp.get_final_transform().get_scale().x * node.get_canvas_transform().get_scale().x)     # Canvas des Knotens: Kamera im Spielfeld, eigene Ebene für Hintergrund und Menüs

## Vorhandene Größe für eine Skalierung: genau passend, sonst ein Teiler (8 → 4, 9 → 3, 10 → 5, 12 → 6: ganze Vielfache), sonst die größte.
static func pick(scale: float) -> int:
	var n := maxi(2, roundi(scale))
	if n <= 6:
		return n
	for k in [6, 5, 4, 3, 2]:
		if n % k == 0:
			return k
	return 6

## Größe für `node` (2 … 6), je Knoten und Bild nur einmal berechnet.
static func size_for(node: CanvasItem) -> int:
	if node == null or not node.is_inside_tree():
		return DEFAULT
	var id := node.get_instance_id()
	var fr := Engine.get_frames_drawn()
	var e = _cache.get(id)
	if e != null and e[0] == fr:
		return e[1]
	var n := pick(of(node))
	if _cache.size() > 512:
		_cache.clear()
	_cache[id] = [fr, n]
	return n

## Ein Bildpunkt in Welteinheiten (1/n) für `node`.
static func px(node: CanvasItem) -> float:
	return 1.0 / float(size_for(node))

## Wert auf das Raster von 1/n Einheit runden.
static func snap(v: float, n: int) -> float:
	return roundf(v * float(n)) / float(n)

## Oberkante der Fassung für Größe `n` in einem Blatt; `rows(k)` liefert die Höhe der Fassung für Größe k in Bildpunkten.
static func sheet_y(n: int, rows: Callable) -> int:
	var y := 0
	for k in SIZES:
		if k == n:
			break
		y += int(rows.call(k))
	return y

## Ausschnitt (Bildpunkte im Blatt) der Fassung für Größe `n`, wenn ein Bild `units` Welteinheiten groß ist.
static func sheet_rect(n: int, units: Vector2) -> Rect2:
	if not SIZES.has(n):
		n = DEFAULT
	return Rect2(0, sheet_y(n, func(k): return units.y * k), units.x * n, units.y * n)

## Größe des ganzen Blatts in Bildpunkten.
static func sheet_size(units: Vector2) -> Vector2i:
	var h := 0
	for k in SIZES:
		h += int(units.y * k)
	return Vector2i(int(units.x * SIZES[SIZES.size() - 1]), h)
