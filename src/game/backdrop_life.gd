class_name BackdropLife
extends RefCounted
## Leben im Level-Hintergrund: Eine dezente Ebene über dem Hintergrundbild und hinter dem Spielfeld (`backdrop.gd` ruft sie auf). Fern fliegender Verkehr mit
## Positionslichtern, einzelne Blinklichter und je Sektor treibende Teilchen (Funken, Glut, Blasen, Sporen …). Vorlage: `src/ui/menu_backdrop.gd`.
## Alles besteht aus Bildpunkten von 1/3 Einheit (wie der Rest der Welt) und ist höchstens zu 15 % deckend, damit nichts wie ein Hindernis wirkt.
## Bei „Weniger Bewegung“ steht alles still (Verkehr und Teilchen an festen Stellen, die Blinklichter leuchten dauerhaft schwach).

const MAX_ALPHA := 0.15
const PX := 1.0 / 3.0

## Je Sektor: Verkehr {n, v (Einheiten/s), hull (Farbton des Rumpfs), front, rear}, Blinklichter {n, cols}, Teilchen {kind, n, col}.
## Teilchenarten: spark (steigt auf, flackert), ember (steigt langsam, schwankt), bubble (steigt, schwankt), spore (schwebt, pulsiert), mote (treibt seitlich), fall (sinkt).
const LOOK := {
	1: {"cars": 6, "v": 16.0, "hull": Color(0.55, 0.6, 0.95), "front": Color(1, 1, 1), "rear": Color(1.0, 0.3, 0.35), "blink": 4, "bcols": [Color(1.0, 0.3, 0.35), Color(1, 1, 1)], "drift": "", "dn": 0, "dcol": Color(1, 1, 1)},
	2: {"cars": 7, "v": 22.0, "hull": Color(0.8, 0.4, 0.9), "front": Color(0.6, 1.0, 1.0), "rear": Color(1.0, 0.35, 0.85), "blink": 5, "bcols": [Color(1.0, 0.35, 0.85), Color(0.4, 1.0, 1.0)], "drift": "", "dn": 0, "dcol": Color(1, 1, 1)},
	3: {"cars": 3, "v": 9.0, "hull": Color(0.8, 0.6, 0.35), "front": Color(1.0, 0.85, 0.5), "rear": Color(1.0, 0.45, 0.2), "blink": 6, "bcols": [Color(1.0, 0.6, 0.2)], "drift": "spark", "dn": 8, "dcol": Color(1.0, 0.65, 0.25)},
	4: {"cars": 3, "v": 12.0, "hull": Color(0.5, 0.8, 1.0), "front": Color(0.8, 1.0, 1.0), "rear": Color(0.5, 0.8, 1.0), "blink": 3, "bcols": [Color(0.5, 0.85, 1.0)], "drift": "mote", "dn": 10, "dcol": Color(0.7, 0.95, 1.0)},
	5: {"cars": 4, "v": 14.0, "hull": Color(1.0, 0.75, 0.4), "front": Color(1.0, 0.95, 0.6), "rear": Color(1.0, 0.5, 0.2), "blink": 4, "bcols": [Color(1.0, 0.8, 0.3)], "drift": "ember", "dn": 14, "dcol": Color(1.0, 0.55, 0.2)},
	6: {"cars": 3, "v": 10.0, "hull": Color(0.4, 0.85, 0.85), "front": Color(0.8, 1.0, 1.0), "rear": Color(0.3, 0.9, 0.8), "blink": 3, "bcols": [Color(0.4, 1.0, 0.9)], "drift": "bubble", "dn": 12, "dcol": Color(0.85, 0.97, 1.0)},
	7: {"cars": 12, "v": 26.0, "hull": Color(0.7, 0.75, 0.95), "front": Color(1, 1, 1), "rear": Color(1.0, 0.3, 0.3), "blink": 6, "bcols": [Color(0.4, 1.0, 0.55), Color(1.0, 0.3, 0.3)], "drift": "", "dn": 0, "dcol": Color(1, 1, 1)},
	8: {"cars": 2, "v": 8.0, "hull": Color(0.5, 0.7, 0.6), "front": Color(0.7, 1.0, 0.8), "rear": Color(0.5, 0.9, 0.7), "blink": 5, "bcols": [Color(0.5, 1.0, 0.7)], "drift": "spore", "dn": 10, "dcol": Color(0.55, 1.0, 0.7)},
	9: {"cars": 2, "v": 8.0, "hull": Color(0.7, 0.55, 0.95), "front": Color(0.9, 0.85, 1.0), "rear": Color(0.8, 0.5, 1.0), "blink": 3, "bcols": [Color(0.8, 0.6, 1.0), Color(1, 1, 1)], "drift": "fall", "dn": 10, "dcol": Color(0.85, 0.7, 1.0)},
}

## Die Dinge einer Karte: Liste von Wörterbüchern (feste Zufallsfolge je Sektor, bei jedem Aufruf gleich).
static func make(sector: int) -> Array:
	var n := clampi(sector, 1, 9)
	var look: Dictionary = LOOK[n]
	var rng := RandomNumberGenerator.new()
	rng.seed = 5701 * n + 11
	var out: Array = []
	for i in int(look.cars):
		var dir := 1.0 if rng.randf() < 0.5 else -1.0
		out.append({"k": "car", "x": rng.randf(), "y": rng.randf_range(0.10, 0.70), "v": dir * float(look.v) * rng.randf_range(0.6, 1.3),
				"len": rng.randi_range(3, 5), "a": rng.randf_range(0.55, 1.0)})
	for i in int(look.blink):
		var bc: Array = look.bcols
		out.append({"k": "blink", "x": rng.randf(), "y": rng.randf_range(0.12, 0.85), "per": rng.randf_range(1.2, 3.2), "ph": rng.randf() * 3.0,
				"col": bc[i % bc.size()], "a": rng.randf_range(0.7, 1.0)})
	for i in int(look.dn):
		out.append({"k": String(look.drift), "x": rng.randf(), "y": rng.randf(), "v": rng.randf_range(2.5, 7.0), "ph": rng.randf() * TAU, "a": rng.randf_range(0.5, 1.0),
				"col": look.dcol})
	return out

## Größte Deckkraft, die diese Ebene je ergibt (Prüfung für „höchstens etwa 15 %“).
static func max_alpha(things: Array) -> float:
	var m := 0.0
	for it in things:
		m = maxf(m, MAX_ALPHA * float(it.a))
	return m

## Lage eines Dings (Einheiten in der Fläche `vs`, ohne Parallax) zur Zeit `t`; bei `still` immer wie zur Zeit 0 (Weniger Bewegung). Auch für die Prüfung gedacht.
static func pos_at(it: Dictionary, vs: Vector2, t: float, still: bool) -> Vector2:
	var tt := 0.0 if still else t
	match String(it.k):
		"car":
			var span := vs.x + 40.0
			return Vector2(fposmod(float(it.x) * span + float(it.v) * tt, span) - 20.0, float(it.y) * vs.y)
		"blink":
			return Vector2(float(it.x) * vs.x, float(it.y) * vs.y)
	var u := float(it.v) * tt / maxf(vs.y, 1.0)                  # zurückgelegter Bruchteil der Höhe
	var x := float(it.x) * vs.x
	var y := float(it.y)
	match String(it.k):
		"spark", "ember", "bubble":
			y = 1.0 - fposmod((1.0 - y) + u * (0.6 if String(it.k) == "ember" else 1.0), 1.0)         # steigt auf
			x += sin(tt * 0.7 + float(it.ph)) * (2.0 if String(it.k) == "spark" else 6.0)
		"spore":
			y = fposmod(y + u * 0.15, 1.0)
			x += sin(tt * 0.5 + float(it.ph)) * 5.0
		"mote":
			x = fposmod(x + float(it.v) * tt * 0.7, vs.x)
			y = y + sin(tt * 0.6 + float(it.ph)) * 0.03
		"fall":
			y = fposmod(y + u * 0.5, 1.0)
			x += sin(tt * 0.4 + float(it.ph)) * 3.0
	return Vector2(x, y * vs.y)

## Zeichnet die Ebene auf `ci` in der Fläche `vs`; `off` = Kameraversatz (leichter Parallax wie beim Bild), `t` = Zeit, `still` = nichts bewegt sich.
static func draw(ci: CanvasItem, things: Array, sector: int, vs: Vector2, off: Vector2, t: float, still: bool) -> void:
	var look: Dictionary = LOOK[clampi(sector, 1, 9)]
	var tt := 0.0 if still else t
	var ox := -roundf(off.x * 0.04 * 3.0) * PX
	var oy := -roundf(off.y * 0.04 * 3.0) * PX
	for it in things:
		var a := MAX_ALPHA * float(it.a)
		var p := pos_at(it, vs, t, still) + Vector2(ox, oy)
		match String(it.k):
			"car":
				var dir := 1.0 if float(it.v) > 0.0 else -1.0
				var ln := float(int(it.len))
				var hull: Color = look.hull
				_px(ci, p.x - ln * 0.5, p.y, ln, 1.0, Color(hull.r, hull.g, hull.b, a * 0.6))          # Rumpf: schwacher Streifen
				_px(ci, p.x + dir * (ln * 0.5 - PX * 2.0), p.y + PX, PX * 2.0, PX * 2.0, Color(look.front.r, look.front.g, look.front.b, a))
				_px(ci, p.x - dir * (ln * 0.5) - (PX * 2.0 if dir > 0.0 else 0.0), p.y + PX, PX * 2.0, PX * 2.0, Color(look.rear.r, look.rear.g, look.rear.b, a))
			"blink":
				var on := true
				if not still:
					on = fposmod(tt + float(it.ph), float(it.per)) < float(it.per) * 0.22
				if on:
					var c: Color = it.col
					_px(ci, p.x, p.y, PX * 2.0, PX * 2.0, Color(c.r, c.g, c.b, a))
					_px(ci, p.x - PX, p.y, PX, PX * 2.0, Color(c.r, c.g, c.b, a * 0.5))        # kleines Kreuz um den Punkt
					_px(ci, p.x + PX * 2.0, p.y, PX, PX * 2.0, Color(c.r, c.g, c.b, a * 0.5))
					_px(ci, p.x, p.y - PX, PX * 2.0, PX, Color(c.r, c.g, c.b, a * 0.5))
					_px(ci, p.x, p.y + PX * 2.0, PX * 2.0, PX, Color(c.r, c.g, c.b, a * 0.5))
			_:
				var c2: Color = it.col
				var k := String(it.k)
				var al := a
				var sz := PX * 2.0
				if k == "spark":
					al *= 0.5 + 0.5 * sin(tt * 18.0 + float(it.ph))
				elif k == "spore":
					al *= 0.55 + 0.45 * sin(tt * 1.3 + float(it.ph))
				elif k == "bubble":
					sz = PX * 3.0
				_px(ci, p.x, p.y, sz, sz, Color(c2.r, c2.g, c2.b, clampf(al, 0.0, MAX_ALPHA)))

static func _px(ci: CanvasItem, x: float, y: float, w: float, h: float, col: Color) -> void:
	ci.draw_rect(Rect2(roundf(x * 3.0) * PX, roundf(y * 3.0) * PX, w, h), col)
