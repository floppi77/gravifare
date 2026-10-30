class_name LevelData
extends RefCounted
## Rastergestützte Leveldaten, geladen aus data/levels/*.json.
## Zeichen: '#' Fels, '1'-'9' Landepad, 'F' Tankpad, 'S' Start, 'E' Ausgang, '^' Dornen.

const SOLID := "#"

var id := ""
var sector := 1
var index := 1
var names := {}
var rows: Array = []
var width := 0
var height := 0
var gravity := Tuning.GRAVITY
var jobs: Array = []
var pads := {}               # id -> {id, x0, x1, row, center, fuel}
var spawn := Vector2.ZERO
var exit_cells: Array = []
var par_time := 90.0
var start_fuel := Tuning.FUEL_MAX
var raw := {}

static func load_file(path: String) -> LevelData:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("Level nicht lesbar: " + path)
		return null
	var parsed = JSON.parse_string(f.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("Level defekt: " + path)
		return null
	return from_dict(parsed)

static func from_dict(d: Dictionary) -> LevelData:
	var l := LevelData.new()
	l.raw = d
	l.id = d.get("id", "")
	l.sector = int(d.get("sector", 1))
	l.index = int(d.get("index", 1))
	l.names = d.get("name", {})
	l.rows = d.get("map", [])
	l.height = l.rows.size()
	for r in l.rows:
		l.width = maxi(l.width, String(r).length())
	l.gravity = float(d.get("gravity", Tuning.GRAVITY))
	l.jobs = d.get("jobs", [])
	l.par_time = float(d.get("par_time", 90.0))
	l.start_fuel = float(d.get("start_fuel", Tuning.FUEL_MAX))
	l._scan()
	return l

func _scan() -> void:
	for y in height:
		var row: String = rows[y]
		var x := 0
		while x < row.length():
			var c := row[x]
			if c == "S":
				spawn = Vector2(x * Tuning.TILE + Tuning.TILE * 0.5, y * Tuning.TILE + Tuning.TILE * 0.5)
			elif c == "E":
				exit_cells.append(Vector2i(x, y))
			elif (c >= "1" and c <= "9") or c == "F":
				var x1 := x
				while x1 + 1 < row.length() and row[x1 + 1] == c:
					x1 += 1
				pads[c] = {"id": c, "x0": x * Tuning.TILE, "x1": (x1 + 1) * Tuning.TILE, "row": y,
					"center": (x * Tuning.TILE + (x1 + 1) * Tuning.TILE) * 0.5, "fuel": c == "F"}
				x = x1
			x += 1

func cell(cx: int, cy: int) -> String:
	if cy < 0 or cx < 0 or cx >= width or cy >= height:
		return SOLID
	var row: String = rows[cy]
	return row[cx] if cx < row.length() else SOLID

func is_solid_cell(cx: int, cy: int) -> bool:
	var c := cell(cx, cy)
	return c == SOLID or c == "^" or (c >= "1" and c <= "9") or c == "F"

func is_solid_at(p: Vector2) -> bool:
	return is_solid_cell(floori(p.x / Tuning.TILE), floori(p.y / Tuning.TILE))

func box_hits_solid(center: Vector2, half: Vector2) -> bool:
	var x0 := floori((center.x - half.x) / Tuning.TILE)
	var x1 := floori((center.x + half.x - 0.001) / Tuning.TILE)
	var y0 := floori((center.y - half.y) / Tuning.TILE)
	var y1 := floori((center.y + half.y - 0.001) / Tuning.TILE)
	for cy in range(y0, y1 + 1):
		for cx in range(x0, x1 + 1):
			if is_solid_cell(cx, cy):
				return true
	return false

func pad_at_foot(p: Vector2) -> Dictionary:
	## Pad, dessen Oberfläche den Punkt enthält (nur oberste Pad-Zeile).
	var cx := floori(p.x / Tuning.TILE)
	var cy := floori(p.y / Tuning.TILE)
	var c := cell(cx, cy)
	if (c >= "1" and c <= "9") or c == "F":
		var pad: Dictionary = pads.get(c, {})
		if not pad.is_empty() and pad.row == cy:
			return pad
	return {}

func pixel_size() -> Vector2:
	return Vector2(width * Tuning.TILE, height * Tuning.TILE)
