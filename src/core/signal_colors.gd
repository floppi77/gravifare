class_name SignalColors
extends RefCounted
## Signalfarben für Zustände (gut / Achtung / schlecht): Tank, Hülle, Landeampel und Landeassistent, Spritpreis, Fahrpreisfaktor,
## Geduld, Lampen an Wartehäuschen, Türen und Ausgang.
## Normal: die gewohnten Farben grün / gelb / rot. Mit der Option „Farbsehschwäche“ (Settings „color_safe“): blau / gelb / purpurrot.
## Diese Tafel ist so gewählt, dass die Stufen bei Rot-Grün-Schwäche (Deuteranopie, Protanopie) und bei Blau-Gelb-Schwäche (Tritanopie)
## deutlich verschieden bleiben (Simulation Machado 2009, volle Stärke, kleinster Abstand ΔE): Ampel ≥ 51 statt 23, Tank ≥ 38 statt 6,
## Hülle ≥ 51 statt 14 (Rechnung: tools/art/cvd_check.py).
## Klassen mit class_name dürfen Autoloads nicht kennen: Settings setzt `safe` in apply().

static var safe := false

const SAFE_GOOD := Color("#4fb0ff")
const SAFE_MID := Color("#ffe14a")
const SAFE_BAD := Color("#d83c64")
# Tank in vier Stufen (voll, halb, knapp, kritisch)
const SAFE_FUEL := [Color("#4fb0ff"), Color("#f4f4ff"), Color("#ffc23a"), Color("#d83c64")]

## „Gut“ (normal: `normal`, meist das Grün #5dff9a).
static func good(normal := Color("#5dff9a")) -> Color:
	return SAFE_GOOD if safe else normal

## „Achtung“.
static func mid(normal := Color("#ffe14a")) -> Color:
	return SAFE_MID if safe else normal

## „Schlecht“ (normal: das jeweilige Rot/Orange der Stelle).
static func bad(normal := Color("#ff4d6d")) -> Color:
	return SAFE_BAD if safe else normal

## Dreistufig nach Schwellen: v <= a gut, v <= b Achtung, sonst schlecht.
static func by_level(v: float, a: float, b: float, bad_normal := Color("#ff4d6d")) -> Color:
	return good() if v <= a else (mid() if v <= b else bad(bad_normal))
