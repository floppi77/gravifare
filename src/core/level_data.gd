class_name LevelData
extends RefCounted
## Rastergestützte Leveldaten, geladen aus data/levels/*.json.
## Zeichen: '#' Fels, '1'-'9' Landepad, 'F' Tankpad, 'S' Start, 'E' Ausgang, '^' Dornen.

const SOLID := "#"

var id := ""
var sector := 1
var index := 1
var number := 1                # Kampagnennummer 1..99
var names := {}
var rows: Array = []
var width := 0
var height := 0
var gravity := Tuning.GRAVITY
var jobs: Array = []
var pads := {}               # id -> {id, x0, x1, row, center, fuel}
var spawn := Vector2.ZERO
var exit_cells: Array = []
var pumps: Array = []            # Zapfsäulen (Zeichen "P", 1×2 Tiles, fest): {rect: Rect2, pad: id, side: -1/0/1}
var fuel_price_min := Tuning.FUEL_PRICE_MIN
var fuel_price_max := Tuning.FUEL_PRICE_MAX
var price_every := Vector2(Tuning.PRICE_EVERY_MIN, Tuning.PRICE_EVERY_MAX)
var exit_open := false      # Laufzeitzustand; geschlossenes Tor ist fest
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
	l.number = (l.sector - 1) * 11 + l.index
	l.names = d.get("name", {})
	l.rows = d.get("map", [])
	l.height = l.rows.size()
	for r in l.rows:
		l.width = maxi(l.width, String(r).length())
	l.gravity = float(d.get("gravity", Tuning.GRAVITY))
	l.jobs = d.get("jobs", [])
	l.par_time = float(d.get("par_time", 90.0))
	l.start_fuel = float(d.get("start_fuel", Tuning.FUEL_MAX))
	var fc: Dictionary = d.get("fuel", {})
	l.fuel_price_min = float(fc.get("min", Tuning.FUEL_PRICE_MIN))
	l.fuel_price_max = float(fc.get("max", Tuning.FUEL_PRICE_MAX))
	var ev: Array = fc.get("every", [Tuning.PRICE_EVERY_MIN, Tuning.PRICE_EVERY_MAX])
	l.price_every = Vector2(float(ev[0]), float(ev[1]))
	l._scan()
	l._plan_shelters()
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

const SHELTER_W := 20.4
const SHELTER_H := 17.0

func _collect_pumps() -> void:
	## Zusammenhängende "P"-Zellen je Spalte = eine Zapfsäule; sie steht auf dem Tankpad (Pad-Ende).
	for x in width:
		var y := 0
		while y < height:
			if cell(x, y) == "P":
				var y1 := y
				while y1 + 1 < height and cell(x, y1 + 1) == "P":
					y1 += 1
				pumps.append({"rect": Rect2(x * Tuning.TILE, y * Tuning.TILE, Tuning.TILE, (y1 - y + 1) * Tuning.TILE), "pad": "", "side": 0})
				y = y1 + 1
			else:
				y += 1
	for pm in pumps:
		var r: Rect2 = pm.rect
		for id in pads:
			var pd: Dictionary = pads[id]
			if pd.fuel and absf(pd.row * Tuning.TILE - r.end.y) < 0.5 and r.position.x >= pd.x0 - 0.5 and r.end.x <= pd.x1 + 0.5:
				pm["pad"] = id
				pm["side"] = -1 if absf(r.position.x - pd.x0) < 0.5 else (1 if absf(r.end.x - pd.x1) < 0.5 else 0)

func _plan_shelters() -> void:
	_collect_pumps()
	## Jedes Passagierpad bekommt einen Wartebereich: Unterstand an einem Ende (links bevorzugt),
	## davor der Wartepunkt. Nur wenn darüber 2 Tiles frei sind; sonst side = 0 (Validator meldet das).
	## Zusätzlich das freie Landefenster: Bereich, in dem das Taxi (Füße auf dem Pad, Abstand zum
	## wartenden Fahrgast) landen kann – daran bemisst sich die Padgröße/Schwierigkeit.
	var half := Tuning.HULL_HALF.x + Tuning.PASS_HALF_W + Tuning.PASS_CLEAR
	for id in pads:
		var p: Dictionary = pads[id]
		var lo: float = p.x0 + Tuning.FOOT_X
		var hi: float = p.x1 - Tuning.FOOT_X
		if p.fuel:
			for pm in pumps:
				if pm.pad == id:
					if pm.side < 0:
						lo = maxf(lo, pm.rect.end.x + Tuning.HULL_HALF.x + 2.0)
					elif pm.side > 0:
						hi = minf(hi, pm.rect.position.x - Tuning.HULL_HALF.x - 2.0)
			p["land_lo"] = lo
			p["land_hi"] = hi
			p["land_window"] = hi - lo
			p["land_mid"] = (lo + hi) * 0.5
			continue
		var side := 0
		for cand in [-1, 1]:
			var xs: float = p.x0 if cand < 0 else p.x1 - SHELTER_W
			var free := true
			for cx in range(floori(xs / Tuning.TILE), floori((xs + SHELTER_W - 0.01) / Tuning.TILE) + 1):
				for cy in [p.row - 1, p.row - 2]:
					if is_solid_cell(cx, cy):
						free = false
			if free:
				side = cand
				break
		p["side"] = side
		var surf: float = p.row * Tuning.TILE
		if side == 0:
			p["door_x"] = p.center
			p["wait_x"] = p.center
			p["shelter"] = Rect2()
			var left_w: float = (p.center - half) - lo
			var right_w: float = hi - (p.center + half)
			if left_w >= right_w:
				hi = p.center - half
			else:
				lo = p.center + half
		else:
			var xs: float = p.x0 if side < 0 else p.x1 - SHELTER_W
			p["shelter"] = Rect2(xs, surf - SHELTER_H, SHELTER_W, SHELTER_H)
			p["door_x"] = xs + SHELTER_W * 0.5
			p["wait_x"] = p.door_x + (SHELTER_W * 0.5 + 6.0) * (1.0 if side < 0 else -1.0)
			if side < 0:
				lo = maxf(lo, p.wait_x + half)
			else:
				hi = minf(hi, p.wait_x - half)
		p["land_lo"] = lo
		p["land_hi"] = hi
		p["land_window"] = maxf(hi - lo, 0.0)
		p["land_mid"] = (lo + hi) * 0.5

func cell(cx: int, cy: int) -> String:
	if cy < 0 or cx < 0 or cx >= width or cy >= height:
		return SOLID
	var row: String = rows[cy]
	return row[cx] if cx < row.length() else SOLID

func is_solid_cell(cx: int, cy: int) -> bool:
	var c := cell(cx, cy)
	return c == SOLID or c == "^" or c == "P" or (c >= "1" and c <= "9") or c == "F" or (c == "E" and not exit_open)

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

func exit_rect() -> Rect2:
	## Tor als Rechteck in Pixeln (leer, wenn das Level keins hat).
	if exit_cells.is_empty():
		return Rect2()
	var x0 := 1 << 30
	var y0 := 1 << 30
	var x1 := -1
	var y1 := -1
	for c in exit_cells:
		x0 = mini(x0, c.x); y0 = mini(y0, c.y); x1 = maxi(x1, c.x); y1 = maxi(y1, c.y)
	return Rect2(x0 * Tuning.TILE, y0 * Tuning.TILE, (x1 - x0 + 1) * Tuning.TILE, (y1 - y0 + 1) * Tuning.TILE)

func pixel_size() -> Vector2:
	return Vector2(width * Tuning.TILE, height * Tuning.TILE)
