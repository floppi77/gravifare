extends RefCounted
## Runde 86: Osterei (nur Darstellung, nie Spielregeln). Von Karfreitag bis Ostermontag (Calendar.easter) liegt in jeder Karte der Tag- und
## Nachtschicht (nicht in der Karriere) ein buntes Ei versteckt auf dem Boden. Berührt das Taxi es, zerplatzt es; jede Karte zählt je Tag und
## Schicht einmal (Save.note_egg, Erfolg „eggs_20“).
## Versteck: fest je Karte, Tag und Schicht (Hash), auf festem Fels, mit Platz darüber für das Taxi, nicht auf Plattformen, an Zapfsäulen,
## in Hitzezonen, auf Wegen von Trümmern oder am Startpunkt. Bevorzugt Ecken (Fels zwei Felder daneben), damit es eher versteckt liegt.
## Einbinden mit: const EasterEgg := preload("res://src/game/easter_egg.gd")

const T := Tuning.TILE
const SIZE := Vector2(7.0, 9.0)                 # Ei in Einheiten (Breite, Höhe)
const HIT_HALF := Vector2(11.0, 9.0)            # Berührfläche des Taxis um seine Mitte (etwas größer als der Rumpf: Kufen und Kuppel zählen mit)

## Farbpaare (Grund, Muster) – je Level eines nach dem Hash.
const COLORS := [
	[Color("#ff7ac8"), Color("#fff3a6")], [Color("#6ad8ff"), Color("#ffffff")], [Color("#9cff6a"), Color("#ff6aa8")],
	[Color("#ffd24a"), Color("#7a6aff")], [Color("#b48cff"), Color("#9cffe8")], [Color("#ff8a5a"), Color("#6affc8")],
]

static func _free(level: LevelData, cx: int, cy: int) -> bool:
	return level.cell(cx, cy) == "."

## Mögliche Felder (Vector2i, Zelle in der das Ei liegt): {"nook": Ecken, "all": weitere, "loose": Notlösung} – in dieser Reihenfolge bevorzugt.
static func candidates(level: LevelData) -> Dictionary:
	var blocked: Array = []
	for z in level.zones:
		if String(z.kind) == "heat":                       # Hitze verbrennt das Taxi; Wind und Magnete (auch die Tagesregeln) stören nicht
			blocked.append((z.rect as Rect2).grow(T * 0.5))
	for m in level.movers:
		if String(m.kind) in ["debris", "pad"]:
			var ax := absf(float(m.ax))
			var ay := absf(float(m.ay))
			blocked.append(Rect2(float(m.x) - ax, float(m.y) - ay, float(m.w) + ax * 2.0, float(m.h) + ay * 2.0).grow(T * 0.5))
	for p in level.pumps:
		blocked.append((p.rect as Rect2).grow(T * 1.5))
	blocked.append(Rect2(level.spawn - Vector2(T * 3.0, T * 3.0), Vector2(T * 6.0, T * 6.0)))
	var nook: Array = []
	var all: Array = []
	var loose: Array = []                                 # Notlösung für enge Karten: Fels nur direkt darunter, ein Nachbarfeld frei
	for cy in range(2, level.height - 1):
		for cx in range(1, level.width - 1):
			if level.cell(cx, cy + 1) != LevelData.SOLID or not _free(level, cx, cy) or not _free(level, cx, cy - 1):
				continue
			var strict := _free(level, cx - 1, cy) and _free(level, cx + 1, cy) and _free(level, cx - 1, cy - 1) and _free(level, cx + 1, cy - 1) and _free(level, cx, cy - 2) \
				and level.cell(cx - 1, cy + 1) == LevelData.SOLID and level.cell(cx + 1, cy + 1) == LevelData.SOLID     # ganz auf Fels, nicht an einer Kante oder neben einer Plattform
			if not strict and not ((_free(level, cx - 1, cy) and _free(level, cx - 1, cy - 1)) or (_free(level, cx + 1, cy) and _free(level, cx + 1, cy - 1))):
				continue
			var r := Rect2(cx * T, cy * T, T, T)
			var ok := true
			for b in blocked:
				if (b as Rect2).intersects(r):
					ok = false
					break
			if not ok:
				continue
			var c := Vector2i(cx, cy)
			if not strict:
				loose.append(c)
				continue
			all.append(c)
			if level.cell(cx - 2, cy) == LevelData.SOLID or level.cell(cx + 2, cy) == LevelData.SOLID:
				nook.append(c)
	return {"nook": nook, "all": all, "loose": loose}

## Versteck des Eis im Level, fest für `seed_key` (Tag, Schicht, Karte): {"pos": Vector2 (Mitte unten, auf dem Boden), "rect": Rect2, "colors": [Grund, Muster], "pattern": 0–2}
## oder {} (kein Platz).
static func spot(level: LevelData, seed_key: String) -> Dictionary:
	var c := candidates(level)
	var list: Array = c.nook
	if list.is_empty():
		list = c.all
	if list.is_empty():
		list = c.loose
	if list.is_empty():
		return {}
	var h := absi(hash(seed_key + ":egg"))
	var cell: Vector2i = list[h % list.size()]
	var x := float(cell.x * T) + T * 0.5 + float((h / 7) % 7 - 3)
	var pos := Vector2(x, float((cell.y + 1) * T))
	return {"pos": pos, "rect": Rect2(pos.x - SIZE.x * 0.5, pos.y - SIZE.y, SIZE.x, SIZE.y), "cell": cell,
		"colors": COLORS[(h / 13) % COLORS.size()], "pattern": (h / 31) % 3}

## Berührt das Taxi (Mitte `taxi_pos`) das Ei?
static func touches(egg: Dictionary, taxi_pos: Vector2) -> bool:
	return not egg.is_empty() and Rect2(taxi_pos - HIT_HALF, HIT_HALF * 2.0).intersects((egg.rect as Rect2).grow(1.0))

## Umriss des Eis (unten breiter, oben spitzer) um die Mitte unten `base`.
static func outline(base: Vector2, size := SIZE, n := 20) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var c := base - Vector2(0, size.y * 0.45)
	for i in n:
		var a := TAU * float(i) / float(n)
		var up := cos(a)                                                # 1 = Spitze oben, −1 = Boden
		var r := size.x * 0.5 * (1.0 - 0.18 * maxf(0.0, up))           # obere Hälfte schmaler
		var ry := size.y * (0.55 if up > 0.0 else 0.45)
		pts.append(c + Vector2(sin(a) * r, -up * ry))
	return pts
