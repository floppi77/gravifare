class_name SectorLook
extends RefCounted
## Bildsprache je Sektor: Fels-Material (tiles_sN.png, tools/art/gen_sector_tiles.py), Kantenfarben und Tonwert des Hintergrunds.
## Funktionsfarben (Plattformen, Tankpad, Gefahren) bleiben in allen Sektoren gleich. Der Hintergrund tritt durch weniger Sättigung
## und Kontrast sowie Dunst in Sektorfarbe zurück, damit die Spielfläche führt.

const LOOKS := {
	1: {"edge": "#7f8fe0", "hi": "#c4d0ff", "shade": "#0c0f24", "sat": 0.85, "con": 0.82, "fog": "#101a38", "amt": 0.22},
	2: {"edge": "#b07ae0", "hi": "#e6c4ff", "shade": "#150a24", "sat": 0.75, "con": 0.72, "fog": "#1a0f30", "amt": 0.30},
	3: {"edge": "#b98a52", "hi": "#ffd9a0", "shade": "#1c1009", "sat": 0.62, "con": 0.65, "fog": "#0e2228", "amt": 0.30},
	4: {"edge": "#8fc4cf", "hi": "#dff6fa", "shade": "#0b1820", "sat": 0.70, "con": 0.72, "fog": "#0c1c26", "amt": 0.28},
	5: {"edge": "#c0705a", "hi": "#ffc09a", "shade": "#180806", "sat": 0.75, "con": 0.75, "fog": "#200a08", "amt": 0.22},
	6: {"edge": "#5ab8a4", "hi": "#bff5e4", "shade": "#061814", "sat": 0.75, "con": 0.75, "fog": "#061a22", "amt": 0.24},
	7: {"edge": "#d0b070", "hi": "#fff0c4", "shade": "#201808", "sat": 0.60, "con": 0.60, "fog": "#1a1420", "amt": 0.52},
	8: {"edge": "#6f9a62", "hi": "#c8eab8", "shade": "#07120a", "sat": 0.80, "con": 0.82, "fog": "#061410", "amt": 0.20},
	9: {"edge": "#7a78c0", "hi": "#cfceff", "shade": "#07071a", "sat": 0.85, "con": 0.85, "fog": "#08061a", "amt": 0.12},
}

## Werte eines Sektors als Farben; unbekannte Sektoren nutzen Sektor 1.
static func of(sector: int) -> Dictionary:
	var l: Dictionary = LOOKS.get(sector, LOOKS[1])
	return {"edge": Color(l.edge), "hi": Color(l.hi), "shade": Color(l.shade), "sat": l.sat, "con": l.con, "fog": Color(l.fog), "amt": l.amt}

static func tiles(sector: int) -> Texture2D:
	var p := "res://assets/art/tiles_s%d.png" % sector
	return load(p if ResourceLoader.exists(p) else "res://assets/art/tiles_s1.png")
