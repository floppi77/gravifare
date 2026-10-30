class_name LevelData
extends RefCounted
## Rastergestützte Leveldaten, geladen aus data/levels/*.json.
## Zeichen: '#' Fels, '1'-'9' Landepad, 'F' Tankpad, 'L' Lebens-Station, 'S' Start, 'E' Ausgang, '^' Dornen.

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
## Bewegliche Tore (Zeichen "a".."e" im Raster, Parameter im JSON unter "doors"): öffnen und schließen im festen Takt.
## Geschlossen sind sie fest wie Fels. Schließt ein Tor, während das Taxi darin ist, nimmt es Schaden und wird zur nächsten Seite hinausgeschleudert (TaxiSim).
const DOOR_CHARS := "abcde"
var doors := {}                  # Zeichen -> {cells: Array[Vector2i], period, open, phase}
var clock := 0.0                 # Simulationszeit (setzt TaxiSim), bestimmt den Torzustand
var doors_ignore := false        # Planung/Zeichnen: Tore gelten als offen
var doors_forced_open := false   # Levelwechsel-Einflug: Tore stehen offen
## Bewegliche Hindernisse und Plattformen (Sektor 3): JSON "movers": kind "debris" (Trümmer, Schaden), "slider" (großer
## Block, quetscht wie ein Tor) oder "pad" (Landeplattform auf waagerechter Schiene). Bewegung nach der Simulationszeit.
var movers: Array = []
var movers_ignore := false       # Planung/Zeichnen: Mover gelten als nicht vorhanden

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
	var pscale := Tuning.price_scale(l.number)
	l.fuel_price_min = float(fc.get("min", Tuning.FUEL_PRICE_MIN * pscale))
	l.fuel_price_max = float(fc.get("max", Tuning.FUEL_PRICE_MAX * pscale))
	var ev: Array = fc.get("every", [Tuning.PRICE_EVERY_MIN, Tuning.PRICE_EVERY_MAX])
	l.price_every = Vector2(float(ev[0]), float(ev[1]))
	l._scan()
	l._scan_doors(d.get("doors", {}))
	l._scan_movers(d.get("movers", []))
	l._plan_shelters()
	l._finish_moving_pads()
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
			elif (c >= "1" and c <= "9") or c == "F" or c == "L":
				var x1 := x
				while x1 + 1 < row.length() and row[x1 + 1] == c:
					x1 += 1
				pads[c] = {"id": c, "x0": x * Tuning.TILE, "x1": (x1 + 1) * Tuning.TILE, "row": y,
					"center": (x * Tuning.TILE + (x1 + 1) * Tuning.TILE) * 0.5, "fuel": c == "F", "life": c == "L"}
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
		if p.life:                       # Lebens-Station: kleine Plattform ohne Wartebereich
			p["side"] = 0
			p["shelter"] = Rect2()
			p["door_x"] = p.center
			p["wait_x"] = p.center
			p["land_lo"] = lo
			p["land_hi"] = hi
			p["land_window"] = maxf(hi - lo, 0.0)
			p["land_mid"] = (lo + hi) * 0.5
			continue
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

func _scan_doors(params: Dictionary) -> void:
	for y in height:
		var row: String = rows[y]
		for x in row.length():
			var c := row[x]
			if DOOR_CHARS.contains(c):
				if not doors.has(c):
					var p: Dictionary = params.get(c, {})
					doors[c] = {"cells": [], "period": float(p.get("period", 8.0)), "open": float(p.get("open", 5.0)), "phase": float(p.get("phase", 0.0))}
				doors[c].cells.append(Vector2i(x, y))

## Passagierpad (weder Tank- noch Lebens-Station).
func is_passenger_pad(id: String) -> bool:
	return pads.has(id) and not pads[id].fuel and not pads[id].get("life", false)

func has_movers() -> bool:
	return not movers.is_empty()

func _scan_movers(list: Array) -> void:
	for d in list:
		var kind := String(d.get("kind", "debris"))
		var m := {"kind": kind, "w": float(d.get("w", 2)) * Tuning.TILE, "h": float(d.get("h", 1)) * Tuning.TILE,
			"x": float(d.x) * Tuning.TILE, "y": float(d.y) * Tuning.TILE, "ax": float(d.get("dx", 0)) * Tuning.TILE,
			"ay": float(d.get("dy", 0)) * Tuning.TILE, "period": maxf(float(d.get("period", 8.0)), 0.5), "phase": float(d.get("phase", 0.0)),
			"shape": String(d.get("shape", "line")), "pad": String(d.get("pad", ""))}
		if kind == "pad":
			var id: String = m.pad
			m["h"] = 2.0 * Tuning.TILE
			m["ay"] = 0.0
			pads[id] = {"id": id, "x0": m.x, "x1": m.x + m.w, "row": int(d.y), "center": m.x + m.w * 0.5, "fuel": false, "life": false, "moving": true, "dx": 0.0, "dx_step": 0.0}
		m["rect"] = _mover_rect(m, 0.0)
		m["vel"] = Vector2.ZERO
		movers.append(m)

func _mover_offset(m: Dictionary, t: float) -> Vector2:
	var ph := TAU * (t + float(m.phase)) / float(m.period)
	if m.shape == "circle":
		return Vector2(float(m.ax) * cos(ph), float(m.ay) * sin(ph))
	var s := sin(ph)
	return Vector2(float(m.ax) * s, float(m.ay) * s)

func _mover_rect(m: Dictionary, t: float) -> Rect2:
	var off := _mover_offset(m, t)
	return Rect2(float(m.x) + off.x, float(m.y) + off.y, float(m.w), float(m.h))

## Merkt die Grundgeometrie der fahrenden Pads (nach Planung der Unterstände).
func _finish_moving_pads() -> void:
	for m in movers:
		if m.kind == "pad":
			var p: Dictionary = pads[m.pad]
			p["base"] = {"x0": p.x0, "x1": p.x1, "center": p.center, "land_lo": p.get("land_lo", p.x0), "land_hi": p.get("land_hi", p.x1),
				"land_mid": p.get("land_mid", p.center), "shelter": p.get("shelter", Rect2()), "door_x": p.get("door_x", p.center), "wait_x": p.get("wait_x", p.center)}

## Setzt alle Mover auf die Zeit t (Simulationszeit); `reset` verwirft die Geschwindigkeit (Neustart).
func update_movers(t: float, reset := false) -> void:
	for m in movers:
		var old: Rect2 = m.rect
		var r := _mover_rect(m, t)
		m.vel = Vector2.ZERO if reset else (r.position - old.position) / Tuning.TICK
		m.rect = r
		if m.kind == "pad":
			var p: Dictionary = pads[m.pad]
			var b: Dictionary = p.base
			var dx := r.position.x - float(m.x)
			p["dx_step"] = 0.0 if reset else dx - float(p.dx)
			p["dx"] = dx
			p["x0"] = b.x0 + dx
			p["x1"] = b.x1 + dx
			p["center"] = b.center + dx
			p["land_lo"] = b.land_lo + dx
			p["land_hi"] = b.land_hi + dx
			p["land_mid"] = b.land_mid + dx
			p["door_x"] = b.door_x + dx
			p["wait_x"] = b.wait_x + dx
			var sh: Rect2 = b.shelter
			p["shelter"] = Rect2(sh.position.x + dx, sh.position.y, sh.size.x, sh.size.y) if sh.size.x > 0.0 else sh

func movers_hit_box(center: Vector2, half: Vector2) -> bool:
	if movers.is_empty() or movers_ignore:
		return false
	var box := Rect2(center - half, half * 2.0)
	for m in movers:
		if m.rect.intersects(box):
			return true
	return false

## Planung: fahrende Pads belegen ihren gesamten Fahrweg (Platte + Schiene) als feste Fläche.
func pad_sweeps_hit(center: Vector2, half: Vector2) -> bool:
	var box := Rect2(center - half, half * 2.0)
	for m in movers:
		if m.kind == "pad" and Rect2(float(m.x) - float(m.ax), float(m.y), float(m.w) + 2.0 * float(m.ax), float(m.h)).intersects(box):
			return true
	return false

func movers_at_box(center: Vector2, half: Vector2) -> Array:
	var out: Array = []
	if movers_ignore:
		return out
	var box := Rect2(center - half, half * 2.0)
	for m in movers:
		if m.rect.intersects(box):
			out.append(m)
	return out

## Bot: Berührt ein Hindernis (Trümmer/Schieber, keine Pads) die Box irgendwann im Zeitfenster [t0, t0 + length]?
func movers_block(center: Vector2, half: Vector2, t0: float, length: float) -> bool:
	var box := Rect2(center - half, half * 2.0)
	var t := t0
	while t <= t0 + length:
		for m in movers:
			if m.kind != "pad" and _mover_rect(m, t).intersects(box):
				return true
		t += 0.15
	return false

func has_doors() -> bool:
	return not doors.is_empty()

func door_is_open(ch: String, t: float) -> bool:
	var d: Dictionary = doors.get(ch, {})
	return doors_forced_open or d.is_empty() or fposmod(t + float(d.phase), float(d.period)) < float(d.open)

## Ist das Tor im gesamten Zeitfenster [t0, t0 + length] offen? (Bot: erst losfliegen, wenn die Passage reicht.)
func door_open_window(ch: String, t0: float, length: float) -> bool:
	var t := t0
	while t <= t0 + length:
		if not door_is_open(ch, t):
			return false
		t += 0.1
	return door_is_open(ch, t0 + length)

## Torzeichen aller Torzellen, die die Box berührt (ohne Rücksicht auf den aktuellen Zustand).
func door_chars_in_box(center: Vector2, half: Vector2) -> Array:
	var out: Array = []
	if doors.is_empty():
		return out
	var x0 := floori((center.x - half.x) / Tuning.TILE)
	var x1 := floori((center.x + half.x - 0.001) / Tuning.TILE)
	var y0 := floori((center.y - half.y) / Tuning.TILE)
	var y1 := floori((center.y + half.y - 0.001) / Tuning.TILE)
	for cy in range(y0, y1 + 1):
		for cx in range(x0, x1 + 1):
			var c := cell(cx, cy)
			if c != "" and DOOR_CHARS.contains(c) and not out.has(c):
				out.append(c)
	return out

## Sekunden bis zum Schließen (0, wenn geschlossen) bzw. -1, wenn das Tor dauerhaft offen ist.
func door_time_to_close(ch: String, t: float) -> float:
	var d: Dictionary = doors.get(ch, {})
	if d.is_empty():
		return -1.0
	var m := fposmod(t + float(d.phase), float(d.period))
	return maxf(0.0, float(d.open) - m) if m < float(d.open) else 0.0

func _door_cell_closed(cx: int, cy: int, c: String) -> bool:
	return not (doors_ignore or door_is_open(c, clock))

func hits_closed_door(center: Vector2, half: Vector2) -> bool:
	if doors.is_empty():
		return false
	var x0 := floori((center.x - half.x) / Tuning.TILE)
	var x1 := floori((center.x + half.x - 0.001) / Tuning.TILE)
	var y0 := floori((center.y - half.y) / Tuning.TILE)
	var y1 := floori((center.y + half.y - 0.001) / Tuning.TILE)
	for cy in range(y0, y1 + 1):
		for cx in range(x0, x1 + 1):
			var c := cell(cx, cy)
			if DOOR_CHARS.contains(c) and c != "" and not door_is_open(c, clock):
				return true
	return false

func is_solid_cell(cx: int, cy: int) -> bool:
	var c := cell(cx, cy)
	if c != "" and DOOR_CHARS.contains(c):
		return _door_cell_closed(cx, cy, c)
	return c == SOLID or c == "^" or c == "P" or (c >= "1" and c <= "9") or c == "F" or c == "L" or (c == "E" and not exit_open)

func is_solid_at(p: Vector2) -> bool:
	if not movers.is_empty() and not movers_ignore:
		for m in movers:
			if m.rect.has_point(p):
				return true
	return is_solid_cell(floori(p.x / Tuning.TILE), floori(p.y / Tuning.TILE))

func box_hits_solid(center: Vector2, half: Vector2) -> bool:
	if movers_hit_box(center, half):
		return true
	var x0 := floori((center.x - half.x) / Tuning.TILE)
	var x1 := floori((center.x + half.x - 0.001) / Tuning.TILE)
	var y0 := floori((center.y - half.y) / Tuning.TILE)
	var y1 := floori((center.y + half.y - 0.001) / Tuning.TILE)
	for cy in range(y0, y1 + 1):
		for cx in range(x0, x1 + 1):
			if is_solid_cell(cx, cy):
				return true
	return false

func box_hits_char(center: Vector2, half: Vector2, ch: String) -> bool:
	var x0 := floori((center.x - half.x) / Tuning.TILE)
	var x1 := floori((center.x + half.x - 0.001) / Tuning.TILE)
	var y0 := floori((center.y - half.y) / Tuning.TILE)
	var y1 := floori((center.y + half.y - 0.001) / Tuning.TILE)
	for cy in range(y0, y1 + 1):
		for cx in range(x0, x1 + 1):
			if cell(cx, cy) == ch:
				return true
	return false

func pad_at_foot(p: Vector2) -> Dictionary:
	## Pad, dessen Oberfläche den Punkt enthält (nur oberste Pad-Zeile).
	for m in movers:
		if m.kind == "pad":
			var r: Rect2 = m.rect
			if p.x >= r.position.x and p.x <= r.end.x and p.y >= r.position.y - 0.5 and p.y <= r.position.y + 10.0:
				return pads[m.pad]
	var cx := floori(p.x / Tuning.TILE)
	var cy := floori(p.y / Tuning.TILE)
	var c := cell(cx, cy)
	if (c >= "1" and c <= "9") or c == "F" or c == "L":
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
