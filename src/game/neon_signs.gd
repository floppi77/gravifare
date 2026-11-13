class_name NeonSigns
extends RefCounted
## Leuchtreklame der Neon-Level (Runde 64): Schilder mit Schrift aus Röhren (Latein, Katakana), Bildzeichen und Hauptschild mit Lauflicht.
## Reine Planung und Rasterung, ohne Autoloads (testbar): `plan` legt die Schilder nach der Form der Felswände fest (nur in Fels, nie in
## Luftraum, Plattformen, Toren oder Gefahren), `bake` rastert jede Röhre als Pixelbild mit hartem Kern und gestuftem Schein.
## Gezeichnet wird in level_style.gd: dunkle Tafeln normal, die Röhren additiv darüber.

const T := 16.0
const PPU := 3                         # Bildpunkte je Einheit (1080p)

# ---------------------------------------------------------------- Zeichen (Striche im Raster)

## Lateinische Buchstaben auf einem 4 × 6-Raster; jede Liste ist ein durchgehender Röhrenzug.
const LATIN := {
	"A": [[[0, 6], [0, 2], [2, 0], [4, 2], [4, 6]], [[0, 3.5], [4, 3.5]]],
	"B": [[[0, 0], [0, 6], [3, 6], [4, 5], [4, 4], [3, 3], [0, 3]], [[0, 0], [3, 0], [4, 1], [4, 2], [3, 3]]],
	"C": [[[4, 1], [3, 0], [1, 0], [0, 1], [0, 5], [1, 6], [3, 6], [4, 5]]],
	"D": [[[0, 0], [0, 6], [2.5, 6], [4, 4.5], [4, 1.5], [2.5, 0], [0, 0]]],
	"E": [[[4, 0], [0, 0], [0, 6], [4, 6]], [[0, 3], [3, 3]]],
	"F": [[[4, 0], [0, 0], [0, 6]], [[0, 3], [3, 3]]],
	"G": [[[4, 1], [3, 0], [1, 0], [0, 1], [0, 5], [1, 6], [3, 6], [4, 5], [4, 3.5], [2.5, 3.5]]],
	"H": [[[0, 0], [0, 6]], [[4, 0], [4, 6]], [[0, 3], [4, 3]]],
	"I": [[[1, 0], [3, 0]], [[2, 0], [2, 6]], [[1, 6], [3, 6]]],
	"K": [[[0, 0], [0, 6]], [[4, 0], [0, 3.5]], [[1.4, 2.7], [4, 6]]],
	"L": [[[0, 0], [0, 6], [4, 6]]],
	"M": [[[0, 6], [0, 0], [2, 3], [4, 0], [4, 6]]],
	"N": [[[0, 6], [0, 0], [4, 6], [4, 0]]],
	"O": [[[1, 0], [3, 0], [4, 1], [4, 5], [3, 6], [1, 6], [0, 5], [0, 1], [1, 0]]],
	"P": [[[0, 6], [0, 0], [3, 0], [4, 1], [4, 2], [3, 3], [0, 3]]],
	"R": [[[0, 6], [0, 0], [3, 0], [4, 1], [4, 2], [3, 3], [0, 3]], [[2, 3], [4, 6]]],
	"S": [[[4, 1], [3, 0], [1, 0], [0, 1], [0, 2], [1, 3], [3, 3], [4, 4], [4, 5], [3, 6], [1, 6], [0, 5]]],
	"T": [[[0, 0], [4, 0]], [[2, 0], [2, 6]]],
	"U": [[[0, 0], [0, 5], [1, 6], [3, 6], [4, 5], [4, 0]]],
	"V": [[[0, 0], [2, 6], [4, 0]]],
	"W": [[[0, 0], [1, 6], [2, 3], [3, 6], [4, 0]]],
	"X": [[[0, 0], [4, 6]], [[4, 0], [0, 6]]],
	"Y": [[[0, 0], [2, 3], [4, 0]], [[2, 3], [2, 6]]],
	"Z": [[[0, 0], [4, 0], [0, 6], [4, 6]]],
	"2": [[[0, 1], [1, 0], [3, 0], [4, 1], [4, 2], [0, 6], [4, 6]]],
	"4": [[[3, 6], [3, 0], [0, 4], [4, 4]]],
	"7": [[[0, 0], [4, 0], [1.5, 6]]],
}

## Katakana auf einem 6 × 6-Raster (senkrecht geschrieben: der Langstrich „ー“ steht senkrecht).
const KANA := {
	"タ": [[[2.4, 0], [0.4, 2.6]], [[1.6, 1], [5.2, 1], [4, 3.6], [1.2, 6]], [[1.8, 2.6], [3.8, 3.8]]],
	"ク": [[[2.4, 0], [0.4, 2.6]], [[1.6, 1], [5.2, 1], [4, 3.6], [1.2, 6]]],
	"シ": [[[0.6, 0.4], [1.8, 1.2]], [[0.3, 2.3], [1.5, 3.1]], [[0.6, 5.8], [5.6, 1.4]]],
	"ー": [[[3, 0.4], [3, 5.6]]],
	"ネ": [[[3, 0], [3, 1]], [[0.6, 1.6], [5, 1.6], [0.8, 5]], [[3, 3.2], [3, 6]], [[3.6, 3.6], [5.4, 4.8]]],
	"オ": [[[0.2, 2], [5.8, 2]], [[4, 0], [4, 6], [3, 5.4]], [[4, 2.2], [0.4, 5.6]]],
	"ン": [[[0.6, 1], [1.8, 2]], [[0.6, 5.8], [5.6, 1.4]]],
	"ホ": [[[0.4, 2], [5.6, 2]], [[3, 0], [3, 6], [2.2, 5.4]], [[1.6, 3.4], [0.3, 5.4]], [[4.4, 3.4], [5.7, 5.4]]],
	"テ": [[[1, 0.4], [5, 0.4]], [[0, 2.3], [6, 2.3]], [[3, 2.3], [3, 4], [1.6, 6]]],
	"ル": [[[2, 0.4], [2, 3.6], [0.3, 6]], [[4, 0], [4, 5.8], [6, 4.2]]],
	"ラ": [[[1, 0.3], [5, 0.3]], [[0.8, 2], [5, 2], [4, 4.3], [1.4, 6]]],
	"メ": [[[4.8, 0.3], [1, 6]], [[1, 2], [5, 5.5]]],
	"バ": [[[2, 1.6], [0.2, 5.6]], [[3.6, 1.6], [5.6, 5.6]], [[4.4, 0], [4.8, 0.8]], [[5.4, -0.2], [5.8, 0.6]]],
	"ス": [[[1, 0.6], [5, 0.6], [3.4, 3.4], [0.6, 6]], [[3.4, 3.4], [5.6, 6]]],
}

## Bildzeichen auf einem 8 × 8-Raster.
const PICTOS := {
	"cocktail": [[[1, 1], [7, 1], [4, 4.6], [1, 1]], [[4, 4.6], [4, 7.4]], [[2.4, 7.4], [5.6, 7.4]], [[5, 2.4], [6.6, 0]]],
	"ramen": [[[0.4, 3.6], [7.6, 3.6], [6.6, 6], [5, 7], [3, 7], [1.4, 6], [0.4, 3.6]], [[3.2, 3], [6.4, 0.2]], [[4.4, 3], [7.6, 0.8]], [[1.8, 2.8], [1.3, 1.6], [1.9, 0.4]]],
	"heart": [[[4, 7.4], [0.7, 3.6], [0.5, 2], [1.5, 0.8], [3, 0.8], [4, 2.1], [5, 0.8], [6.5, 0.8], [7.5, 2], [7.3, 3.6], [4, 7.4]]],
	"bolt": [[[5, 0.2], [1.8, 4.3], [4.2, 4.3], [3, 7.8], [6.3, 3.4], [3.8, 3.4], [5, 0.2]]],
	"cat": [[[1, 7.4], [1, 2.6], [2, 0.4], [3.3, 2.3], [4.7, 2.3], [6, 0.4], [7, 2.6], [7, 7.4], [1, 7.4]], [[2.6, 4.4], [3.3, 4.4]], [[4.7, 4.4], [5.4, 4.4]], [[3.6, 5.8], [4, 6.2], [4.4, 5.8]]],
	"ufo": [[[2.4, 4], [2.7, 2.4], [4, 1.4], [5.3, 2.4], [5.6, 4]], [[0.2, 4], [7.8, 4], [6.8, 5.8], [1.2, 5.8], [0.2, 4]], [[2, 7.6], [2.6, 5.8]], [[6, 7.6], [5.4, 5.8]]],
	"planet": [],          # Kreis mit Ring, wird in `_picto_strokes` berechnet
	"eye": [],
}

## Inhalte je Stil: Wörter (waagerecht), Katakana (senkrecht), kurze Wörter für kleine Tafeln, Bildzeichen, Hauptschild (Bild + Wort).
const CONTENT := {
	"S2-01": {"words": ["WELCOME", "TAXI", "NEON"], "kana": ["ネオン", "タクシー"], "small": ["OPEN", "24H", "TAXI"],
			  "pictos": ["ufo", "heart", "cocktail"], "main": ["ufo", "TAXI"]},
	"S2-02": {"words": ["HOTEL", "RAMEN", "NOODLES", "BAR", "OPEN"], "kana": ["ホテル", "ラーメン", "バー"], "small": ["OPEN", "24H", "BAR"],
			  "pictos": ["cocktail", "ramen", "heart"], "main": ["cocktail", "HOTEL"]},
	"S2-11": {"words": ["CLUB", "LIVE", "TAXI", "NEON", "24H"], "kana": ["ネオン", "タクシー", "クラス"], "small": ["LIVE", "24H", "CLUB"],
			  "pictos": ["bolt", "eye", "ufo"], "main": ["bolt", "CLUB"]},
	"S2-08": {"words": ["SUSHI", "ORBIT", "VOID", "TAXI"], "kana": ["ネオン", "スシ", "タクシー"], "small": ["VOID", "24H", "OPEN"],
			  "pictos": ["planet", "cat", "eye"], "main": ["planet", "ORBIT"]},
}

# ---------------------------------------------------------------- Planung

## Legt die Schilder fest. Ergebnis: Liste von Schildern {kind, cells: Rect2i, board: Rect2 (Einheiten), col, col2, mode, phase, items}.
## items: [{strokes (Einheiten, absolut), w_px, col, glyph: Index für Flackern}] – die Röhren eines Zeichens bilden ein Element.
static func plan(lv: LevelData, style: Dictionary) -> Array:
	var content: Dictionary = CONTENT.get(lv.id, CONTENT["S2-02"])
	var pal: Array = style.get("pal", ["#ff4fd8", "#4fd8ff"])
	var max_signs: int = int(style.get("max", 9))
	var taken := {}
	var out: Array = []
	var used := {}
	var hazards := _hazard_zones(lv)
	# Reihenfolge: großes Hauptschild, senkrechte Katakana, waagerechte Banner, Bildzeichen, kleine Tafeln
	var main_spot := _find_block(lv, taken, 5, 5)
	if main_spot.size.x > 0:
		var cells := Rect2i(main_spot.position, Vector2i(mini(main_spot.size.x, 6), mini(main_spot.size.y, 6)))
		out.append(_make_main(cells, content.main, pal, hazards, 0))
		used[content.main[0]] = true                                  # Bild und Wort des Hauptschilds nicht noch einmal
		used[content.main[1]] = true
		_take(taken, cells, 1)
	for pass_kind in ["kana", "banner", "picto", "small"]:
		var spots := _spots(lv, taken, pass_kind)
		spots.sort_custom(func(a, b): return a[1] > b[1])          # längste Läufe zuerst
		for sp in spots:
			if out.size() >= max_signs:
				break
			var r: Rect2i = sp[0]
			if not _free(lv, taken, r):
				continue
			var sign := _make(pass_kind, r, content, pal, used, hazards, out.size())
			if sign.is_empty():
				continue
			out.append(sign)
			_take(taken, sign.cells, 1)
	return out

## Gefahren in der Nähe (Einheiten): Dornen (rosa) und Neon-Strahlen. Dort keine Magenta-Röhren, an Strahlen kein Flackern.
static func _hazard_zones(lv: LevelData) -> Dictionary:
	var spikes: Array = []
	for y in lv.height:
		for x in lv.width:
			if lv.cell(x, y) == "^":
				spikes.append(Rect2(x * T, y * T, T, T).grow(T * 1.5))
	var beams: Array = []
	for m in lv.movers:
		if m.kind == "beam":
			var r := Rect2(m.x, m.y, maxf(m.w, 1.0), maxf(m.h, 1.0)).expand(Vector2(m.x + m.ax, m.y + m.ay))
			beams.append(r.grow(T * 3.0))
	return {"spikes": spikes, "beams": beams}

static func _hits(zones: Array, r: Rect2) -> bool:
	for z in zones:
		if (z as Rect2).intersects(r):
			return true
	return false

## Nutzbare Fläche: Fels in den sichtbaren Reihen (oberste und unterste Reihe liegen unter der Anzeige).
static func _usable(lv: LevelData, x: int, y: int) -> bool:
	return y >= 1 and y <= lv.height - 2 and x >= 0 and x < lv.width and lv.cell(x, y) == "#"

static func _free(lv: LevelData, taken: Dictionary, r: Rect2i) -> bool:
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			if not _usable(lv, x, y) or taken.has(Vector2i(x, y)):
				return false
	return true

static func _take(taken: Dictionary, r: Rect2i, margin: int) -> void:
	for y in range(r.position.y - margin, r.end.y + margin):
		for x in range(r.position.x - margin, r.end.x + margin):
			taken[Vector2i(x, y)] = true

## Größter freier Felsblock ab Mindestgröße (für das Hauptschild).
static func _find_block(lv: LevelData, taken: Dictionary, mw: int, mh: int) -> Rect2i:
	var best := Rect2i()
	for y in range(1, lv.height - 1):
		for x in lv.width:
			if not _free(lv, taken, Rect2i(x, y, mw, mh)):
				continue
			var w := mw
			while w < 6 and _free(lv, taken, Rect2i(x, y, w + 1, mh)):
				w += 1
			var h := mh
			while h < 6 and _free(lv, taken, Rect2i(x, y, w, h + 1)):
				h += 1
			if w * h > best.size.x * best.size.y:
				best = Rect2i(x, y, w, h)
	return best

## Mögliche Plätze je Schildart als [Rect2i, Länge]. Ein Platz ist ein Lauf freier Felsfelder mit fester Dicke (Katakana: 1–2 Spalten
## breit und senkrecht; Banner: 2 Reihen hoch; Bildzeichen 2 × 2; kleine Tafeln: 1 Reihe hoch).
static func _spots(lv: LevelData, taken: Dictionary, kind: String) -> Array:
	var out: Array = []
	match kind:
		"kana":
			for th in [2, 1]:
				for x in lv.width - th + 1:
					var y := 1
					while y < lv.height - 1:
						var n := 0
						while _free(lv, taken, Rect2i(x, y + n, th, 1)):
							n += 1
						if n >= 4 and (th == 1 or not _free(lv, taken, Rect2i(x - 1, y, 1, n)) or not _free(lv, taken, Rect2i(x + th, y, 1, n))):
							out.append([Rect2i(x, y, th, n), n * 2 + th])
						y += maxi(n, 1)
		"banner", "small":
			var th := 2 if kind == "banner" else 1
			for y in range(1, lv.height - th):
				var x := 0
				while x < lv.width:
					var n := 0
					while _free(lv, taken, Rect2i(x + n, y, 1, th)):
						n += 1
					if n >= (4 if kind == "banner" else 3):
						out.append([Rect2i(x, y, n, th), n])
					x += maxi(n, 1)
		"picto":
			for y in range(1, lv.height - 2):
				for x in lv.width - 1:
					if _free(lv, taken, Rect2i(x, y, 2, 2)):
						out.append([Rect2i(x, y, 2, 2), 4 - ((x * 7 + y * 3) % 3)])
	return out

static func _h(a: int, b: int, k: int) -> int:
	return absi((a * 73856093) ^ (b * 19349663) ^ (k * 83492791)) >> 3

## Farbe wählen: an Dornen keine Rosa-/Magentatöne, an Neon-Strahlen weder Magenta noch Cyan (die Strahlen warnen in diesen Farben).
static func _color(pal: Array, h: int, board: Rect2, hazards: Dictionary, avoid := "") -> Color:
	var near_spikes := _hits(hazards.spikes, board)
	var near_beams := _hits(hazards.beams, board)
	for k in pal.size():
		var c := Color(String(pal[(h + k) % pal.size()]))
		if String(pal[(h + k) % pal.size()]) == avoid and pal.size() > 1:
			continue
		var pinkish := c.r > 0.8 and c.b > 0.5 and c.g < 0.5
		var cyanish := c.b > 0.8 and c.g > 0.7 and c.r < 0.5
		if near_spikes and pinkish:
			continue
		if near_beams and (pinkish or cyanish):
			continue
		return c
	return Color("#ffb347") if not near_beams else Color("#b46bff")

static func _mode(h: int, board: Rect2, hazards: Dictionary, flick: float) -> String:
	if _hits(hazards.beams, board):
		return "steady"                                      # neben den Strahlen ruhig: deren Blinken bleibt die einzige Warnung
	var u := float(h % 100) / 100.0
	if u < flick:
		return "dying"
	if u < flick * 2.0:
		return "cycle"
	return "steady"

static func _cells_rect(r: Rect2i) -> Rect2:
	return Rect2(Vector2(r.position) * T, Vector2(r.size) * T)

static func _pick(list: Array, used: Dictionary, h: int, fits: Callable, reuse := true) -> String:
	for k in list.size():
		var s: String = list[(h + k) % list.size()]
		if not used.has(s) and fits.call(s):
			return s
	if not reuse:
		return ""                          # Katakana und Banner: jedes Wort nur einmal je Level (Abwechslung, Runde 67)
	for k in list.size():
		var s: String = list[(h + k) % list.size()]
		if fits.call(s):
			return s
	return ""

static func _make(kind: String, r: Rect2i, content: Dictionary, pal: Array, used: Dictionary, hazards: Dictionary, idx: int) -> Dictionary:
	var h := _h(r.position.x, r.position.y, 31 + idx)
	match kind:
		"kana":
			var gs := 12.0 if r.size.x >= 2 else 8.0                          # Zeichengröße (Einheiten); schmale Tafel passt in eine Spalte
			var pitch := gs + 3.0
			var cap := float(mini(r.size.y, 7)) * T - 8.0
			var word := _pick(content.kana, used, h, func(s): return float(s.length()) * pitch + 8.0 <= cap, false)
			if word == "":
				return {}
			used[word] = true
			var bh := float(word.length()) * pitch + 9.0
			var bw := gs + (9.0 if r.size.x >= 2 else 6.0)
			var cells_h := int(ceil(bh / T))
			var y0 := r.position.y + (r.size.y - cells_h) / 2
			var cells := Rect2i(r.position.x, y0, r.size.x, cells_h)
			var area := _cells_rect(cells)
			var board := Rect2(PixelDraw.snap2(Vector2(area.get_center().x - bw * 0.5, area.get_center().y - bh * 0.5)), Vector2(bw, bh))
			var col := _color(pal, h >> 4, board, hazards)
			var items: Array = []
			for i in word.length():
				var o := board.position + Vector2((bw - gs) * 0.5, 5.0 + float(i) * pitch)
				items.append({"strokes": _place(KANA.get(word[i], []), o, gs / 6.0), "w_px": 3, "col": col, "glyph": i})
			items.append({"strokes": _frame(board.grow(-1.5)), "w_px": 2, "col": _color(pal, (h >> 4) + 1, board, hazards, _hex(col)), "glyph": -1, "dim": 0.55})
			return {"kind": "kana", "cells": cells, "board": board, "col": col, "mode": _mode(h, board, hazards, 0.18), "phase": float(h % 997) * 0.013, "items": items}
		"banner", "small":
			var big := kind == "banner"
			var s := 7.0 / 3.0 if big else 4.0 / 3.0                            # Rasterschritt: Buchstaben 14 bzw. 8 Einheiten hoch
			var pitch := 4.0 * s + (3.0 if big else 2.0)
			var cap := float(mini(r.size.x, 9)) * T - 8.0
			var list: Array = content.words if big else content.small
			var word := _pick(list, used, h, func(w): return float(w.length()) * pitch + (10.0 if big else 6.0) <= cap, not big)
			if word == "":
				return {}
			used[word] = true
			var bw := float(word.length()) * pitch - (3.0 if big else 2.0) + (14.0 if big else 8.0)
			var bh := 6.0 * s + (12.0 if big else 6.0)
			var cells_w := int(ceil(bw / T))
			var x0 := r.position.x + (r.size.x - cells_w) / 2
			var cells := Rect2i(x0, r.position.y, cells_w, r.size.y)
			var area := _cells_rect(cells)
			var board := Rect2(PixelDraw.snap2(area.get_center() - Vector2(bw, bh) * 0.5), Vector2(bw, bh))
			var col := _color(pal, h >> 4, board, hazards)
			var items: Array = []
			var pad := 7.0 if big else 4.0
			for i in word.length():
				var ch := word[i]
				if ch == " ":
					continue
				var o := board.position + Vector2(pad + float(i) * pitch, (bh - 6.0 * s) * 0.5)
				items.append({"strokes": _place(LATIN.get(ch, []), o, s), "w_px": 3 if big else 2, "col": col, "glyph": i})
			if big:
				items.append({"strokes": _frame(board.grow(-1.5)), "w_px": 2, "col": _color(pal, (h >> 4) + 1, board, hazards, _hex(col)), "glyph": -1, "dim": 0.55})
			return {"kind": kind, "cells": cells, "board": board, "col": col, "mode": _mode(h, board, hazards, 0.2), "phase": float(h % 997) * 0.013, "items": items}
		"picto":
			var name := _pick(content.pictos, used, h, func(p): return not used.has(p))      # jedes Bildzeichen nur einmal je Level
			if name == "":
				return {}
			used[name] = true
			var area := _cells_rect(r)
			var board := Rect2(PixelDraw.snap2(area.position + Vector2(2, 2)), area.size - Vector2(4, 4))
			var col := _color(pal, h >> 4, board, hazards)
			var items: Array = [{"strokes": _place(_picto_strokes(name), board.position + Vector2(4, 4), (board.size.x - 8.0) / 8.0), "w_px": 3, "col": col, "glyph": 0}]
			items.append({"strokes": _frame(board.grow(-1.5)), "w_px": 2, "col": _color(pal, (h >> 4) + 1, board, hazards, _hex(col)), "glyph": -1, "dim": 0.5})
			return {"kind": "picto", "cells": r, "board": board, "col": col, "mode": _mode(h, board, hazards, 0.15), "phase": float(h % 997) * 0.013, "items": items}
	return {}

## Hauptschild: großes Bildzeichen über einem Wort, Rahmen mit Lauflicht.
static func _make_main(cells: Rect2i, main: Array, pal: Array, hazards: Dictionary, idx: int) -> Dictionary:
	var h := _h(cells.position.x, cells.position.y, 53 + idx)
	var area := _cells_rect(cells)
	var board := Rect2(PixelDraw.snap2(area.position + Vector2(3, 3)), area.size - Vector2(6, 6))
	var col := _color(pal, h >> 4, board, hazards)
	var col2 := _color(pal, (h >> 4) + 1, board, hazards, _hex(col))
	var word: String = main[1]
	var s := 7.0 / 3.0
	var pitch := 4.0 * s + 3.0
	while float(word.length()) * pitch > board.size.x - 10.0 and s > 1.4:
		s -= 1.0 / 3.0
		pitch = 4.0 * s + 2.0
	var ww := float(word.length()) * pitch - (pitch - 4.0 * s)
	var items: Array = []
	var pic := minf(board.size.x - 16.0, board.size.y - 6.0 * s - 22.0)
	var pc := Vector2(board.get_center().x - pic * 0.5, board.position.y + 7.0)
	items.append({"strokes": _place(_picto_strokes(main[0]), PixelDraw.snap2(pc), pic / 8.0), "w_px": 3, "col": col2, "glyph": 0})
	var ty := board.end.y - 6.0 * s - 8.0
	for i in word.length():
		var o := PixelDraw.snap2(Vector2(board.get_center().x - ww * 0.5 + float(i) * pitch, ty))
		items.append({"strokes": _place(LATIN.get(word[i], []), o, s), "w_px": 3, "col": col, "glyph": i + 1})
	return {"kind": "main", "cells": cells, "board": board, "col": col, "col2": col2, "mode": "chase", "phase": float(h % 997) * 0.013, "items": items}

static func _hex(c: Color) -> String:
	return "#" + c.to_html(false)

## Rasterpunkte (Zeichenraster) auf Einheiten setzen.
static func _place(strokes: Array, origin: Vector2, scale: float) -> Array:
	var out: Array = []
	for st in strokes:
		var pts := PackedVector2Array()
		for p in st:
			pts.append(PixelDraw.snap2(origin + Vector2(float(p[0]), float(p[1])) * scale))
		out.append(pts)
	return out

static func _frame(r: Rect2) -> Array:
	var c := 2.0                                                            # abgerundete Ecken der Röhre
	return [PackedVector2Array([PixelDraw.snap2(r.position + Vector2(c, 0)), PixelDraw.snap2(Vector2(r.end.x - c, r.position.y)), PixelDraw.snap2(Vector2(r.end.x, r.position.y + c)),
		PixelDraw.snap2(Vector2(r.end.x, r.end.y - c)), PixelDraw.snap2(Vector2(r.end.x - c, r.end.y)), PixelDraw.snap2(Vector2(r.position.x + c, r.end.y)),
		PixelDraw.snap2(Vector2(r.position.x, r.end.y - c)), PixelDraw.snap2(Vector2(r.position.x, r.position.y + c)), PixelDraw.snap2(r.position + Vector2(c, 0))])]

static func _picto_strokes(name: String) -> Array:
	match name:
		"planet":
			var c: Array = []
			for i in 17:
				var a := TAU * float(i) / 16.0
				c.append([4.0 + cos(a) * 2.4, 4.0 + sin(a) * 2.4])
			var ring: Array = []
			for i in 21:
				var a := TAU * float(i) / 20.0
				var p := Vector2(cos(a) * 3.9, sin(a) * 1.1).rotated(-0.38)
				ring.append([4.0 + p.x, 4.0 + p.y])
			return [c, ring]
		"eye":
			var up: Array = []
			var lo: Array = []
			for i in 9:
				var x := float(i) * 7.6 / 8.0 + 0.2
				var k := sin(PI * float(i) / 8.0)
				up.append([x, 4.0 - 2.6 * k])
				lo.append([x, 4.0 + 2.6 * k])
			var iris: Array = []
			for i in 13:
				var a := TAU * float(i) / 12.0
				iris.append([4.0 + cos(a) * 1.3, 4.0 + sin(a) * 1.3])
			return [up, lo, iris]
	return PICTOS.get(name, [])

# ---------------------------------------------------------------- Rastern

## Rastert die Röhren eines Elements als Pixelbild: Kern `w_px` Bildpunkte in der Röhrenfarbe, heller Mittelstrich (über der Glüh-Schwelle,
## daher mit Bloom), Schein in drei Stufen. Ergebnis: [ImageTexture, Ursprung in Einheiten].
static func bake(item: Dictionary) -> Array:
	var strokes: Array = item.strokes
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for st in strokes:
		for p in st:
			lo = lo.min(p)
			hi = hi.max(p)
	if lo.x == INF:
		return []
	var glow := 6                                                           # Scheinbreite in Bildpunkten
	var ox := roundi(lo.x * PPU) - glow - 2
	var oy := roundi(lo.y * PPU) - glow - 2
	var w := roundi(hi.x * PPU) - ox + glow + 3
	var h := roundi(hi.y * PPU) - oy + glow + 3
	var core := PackedByteArray()
	core.resize(w * h)
	var wpx: int = int(item.w_px)
	for st in strokes:
		var pts: PackedVector2Array = st
		for i in pts.size() - 1:
			_raster_line(core, w, h, roundi(pts[i].x * PPU) - ox, roundi(pts[i].y * PPU) - oy, roundi(pts[i + 1].x * PPU) - ox, roundi(pts[i + 1].y * PPU) - oy, wpx)
	# Abstand zum nächsten Röhrenpunkt (Chebyshev-artig, zwei Durchläufe), daraus der gestufte Schein
	var dist := PackedInt32Array()
	dist.resize(w * h)
	var far := 99
	for i in w * h:
		dist[i] = 0 if core[i] > 0 else far
	for y in h:
		for x in w:
			var i := y * w + x
			var d := dist[i]
			if x > 0: d = mini(d, dist[i - 1] + 2)
			if y > 0: d = mini(d, dist[i - w] + 2)
			if x > 0 and y > 0: d = mini(d, dist[i - w - 1] + 3)
			if x < w - 1 and y > 0: d = mini(d, dist[i - w + 1] + 3)
			dist[i] = d
	for y in range(h - 1, -1, -1):
		for x in range(w - 1, -1, -1):
			var i := y * w + x
			var d := dist[i]
			if x < w - 1: d = mini(d, dist[i + 1] + 2)
			if y < h - 1: d = mini(d, dist[i + w] + 2)
			if x < w - 1 and y < h - 1: d = mini(d, dist[i + w + 1] + 3)
			if x > 0 and y < h - 1: d = mini(d, dist[i + w - 1] + 3)
			dist[i] = d
	var col: Color = item.col
	var hot := col.lerp(Color.WHITE, 0.72)
	var img := Image.create_empty(w, h, false, Image.FORMAT_RGBA8)
	for y in h:
		for x in w:
			var i := y * w + x
			if core[i] == 2:
				img.set_pixel(x, y, Color(hot.r, hot.g, hot.b, 1.0))
			elif core[i] == 1:
				img.set_pixel(x, y, Color(col.r, col.g, col.b, 0.95))
			else:
				var d := float(dist[i]) * 0.5                                # Bildpunkte
				if d <= float(glow):
					var a := 0.42 if d <= 1.5 else (0.24 if d <= 3.0 else (0.12 if d <= 4.5 else 0.05))
					img.set_pixel(x, y, Color(col.r, col.g, col.b, a))
	return [ImageTexture.create_from_image(img), Vector2(ox, oy) / float(PPU)]

## Linie mit Dicke `wpx` ins Raster: Außenpunkte 1 (Farbe), die mittlere Spur 2 (heller Kern).
static func _raster_line(buf: PackedByteArray, w: int, h: int, x0: int, y0: int, x1: int, y1: int, wpx: int) -> void:
	var dx := absi(x1 - x0)
	var dy := -absi(y1 - y0)
	var sx := 1 if x0 < x1 else -1
	var sy := 1 if y0 < y1 else -1
	var err := dx + dy
	var lo := -(wpx / 2)
	var x := x0
	var y := y0
	while true:
		for oy in range(lo, lo + wpx):
			for ox in range(lo, lo + wpx):
				var px := x + ox
				var py := y + oy
				if px >= 0 and py >= 0 and px < w and py < h:
					var v := 2 if (ox == 0 and oy == 0) else 1
					buf[py * w + px] = maxi(buf[py * w + px], v)
		if x == x1 and y == y1:
			break
		var e2 := 2 * err
		if e2 >= dy:
			err += dy
			x += sx
		if e2 <= dx:
			err += dx
			y += sy
