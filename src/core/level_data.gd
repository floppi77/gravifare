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
var tutorial := false            # Tutorial-Level (data/tutorial/tutorial.json): Geduld unbegrenzt, Zusatzfahrgäste nur auf Befehl des Skripts
## Schiebetore (Zeichen "a".."e" im Raster, Parameter im JSON unter "doors"): Zwei Flügel fahren im festen Takt von beiden Seiten zu, bleiben kurz
## geschlossen und fahren wieder auf: senkrecht in Wänden, waagerecht in Böden. Die Flügel sind fest wie Fels. Treffen sie das Taxi im Tor, nimmt es Schaden
## und wird zur nächsten Seite hinausgeschleudert (TaxiSim).
const DOOR_CHARS := "abcde"
const DOOR_CLOSE := 1.7          # Sekunden, die ein Tor zum Schließen braucht
const DOOR_OPEN := 1.2           # … und zum Öffnen
var doors := {}                  # Zeichen -> {cells: Array[Vector2i], gates: [{rect: Rect2 (px), vertical: bool}], period, open, phase}; open = Dauer ganz offen
var clock := 0.0                 # Simulationszeit (setzt TaxiSim), bestimmt den Torzustand
var doors_ignore := false        # Planung/Zeichnen: Tore gelten als offen
var doors_forced_open := false   # Levelwechsel-Einflug: Tore stehen offen
## Bewegliche Hindernisse und Plattformen (Sektor 3): JSON "movers": kind "debris" (Trümmer, Schaden), "slider" (großer
## Block, quetscht wie ein Tor), "pad" (Landeplattform auf waagerechter Schiene) oder "meteor" (Meteoritenschauer: fällt
## je Periode einmal von (x, y) um (dx, dy) Felder in "fall" Sekunden und ist sonst unsichtbar; "warn" Sekunden vorher
## blinkt seine Bahn). Bewegung nach der Simulationszeit.
var movers: Array = []
var meteor_seed := 0             # Meteoriten fallen je Fall auf einer anderen Bahn (zufällig je Lauf, reproduzierbar im Replay); setzt Run.start
var dark := 0.0                  # Sektor 8: Dunkelheit (0 = hell … 1 = fast schwarz); nur Taxi, Plattformen, Tor und leuchtende Gefahren sind beleuchtet
var movers_ignore := false       # Planung/Zeichnen: Mover gelten als nicht vorhanden
var pump_aware := false          # Planung (Zuschauer-Autopilot): Zapfsäulen samt Kopf sind Hindernisse (sonst zählt jede Berührung zum Zerstören der Station)
var sweep_core := false          # Planung: fahrende Pads sperren nur den Bereich, den die Platte in jeder Stellung belegt (statt ihres ganzen Fahrwegs)

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
	l.tutorial = bool(d.get("tutorial", false))
	l.sector = int(d.get("sector", 1))
	l.index = int(d.get("index", 1))
	l.number = (l.sector - 1) * 11 + l.index
	l.names = d.get("name", {})
	l.rows = d.get("map", [])
	l.height = l.rows.size()
	for r in l.rows:
		l.width = maxi(l.width, String(r).length())
	l.gravity = float(d.get("gravity", Tuning.sector_gravity(l.sector)))
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
	l._scan_zones(d.get("zones", []))
	l.dark = clampf(float(d.get("dark", 0.0)), 0.0, 1.0)
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
			elif (c >= "1" and c <= "9") or c == "F" or c == "L" or c == "H":
				var x1 := x
				while x1 + 1 < row.length() and row[x1 + 1] == c:
					x1 += 1
				pads[c] = {"id": c, "x0": x * Tuning.TILE, "x1": (x1 + 1) * Tuning.TILE, "row": y,
					"center": (x * Tuning.TILE + (x1 + 1) * Tuning.TILE) * 0.5, "fuel": c == "F", "life": c == "L", "hospital": c == "H"}
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
					# "sweep": Schleuse mit fester Öffnung („gap“ Felder hoch), die dauerhaft über die Torhöhe auf und ab wandert; Wert = Sekunden pro Weg
					# (oben nach unten). Ohne Haltephasen, Flügel oberhalb und unterhalb der Öffnung sind fest. "glass" ist nur Optik.
					doors[c] = {"cells": [], "period": float(p.get("period", 8.0)), "open": float(p.get("open", 5.0)), "phase": float(p.get("phase", 0.0)),
						"sweep": float(p.get("sweep", 0.0)), "gap_cells": float(p.get("gap", 3.0)), "glass": bool(p.get("glass", false)), "orient": int(p.get("orient", 0))}
				doors[c].cells.append(Vector2i(x, y))
	for c in doors:
		doors[c]["gates"] = _door_gates(c)

## Zusammenhängende Torzellen als Rechteck; Flügel fahren senkrecht, wenn über und unter dem Tor Wand steht (Durchflug waagerecht). Mit "orient" (1 senkrecht,
## 2 waagerecht) lässt sich die Richtung festlegen, wenn die Umgebung nicht eindeutig ist.
func _door_gates(ch: String) -> Array:
	var out: Array = []
	var left: Array = doors[ch].cells.duplicate()
	while not left.is_empty():
		var todo: Array = [left.pop_back()]
		var r := Rect2i(todo[0], Vector2i.ONE)
		while not todo.is_empty():
			var p: Vector2i = todo.pop_back()
			r = r.merge(Rect2i(p, Vector2i.ONE))
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				if left.has(p + d):
					left.erase(p + d)
					todo.append(p + d)
		var orient: int = int(doors[ch].get("orient", 0))
		var above := cell(r.position.x, r.position.y - 1) != "."
		var below := cell(r.position.x, r.end.y) != "."
		out.append({"rect": Rect2(Vector2(r.position) * Tuning.TILE, Vector2(r.size) * Tuning.TILE), "vertical": (orient == 1) or (orient == 0 and above and below)})
	return out

## Passagierpad (weder Tank-, Lebens-Station noch Krankenhaus; das Krankenhaus „H“ ist nur Ziel von Krankentransporten).
func is_passenger_pad(id: String) -> bool:
	return pads.has(id) and not pads[id].fuel and not pads[id].get("life", false) and not pads[id].get("hospital", false)

## Zonen (Sektor 4–6): JSON "zones". Kinds: "wind" (Strömung: konstante Beschleunigung ax/ay in einem Rechteck x/y/w/h, Felder),
## "magnet" (Kreis um cx/cy mit Radius r Feldern: k > 0 zieht zur Mitte, k < 0 stößt ab; Stärke fällt zum Rand quadratisch ab)
## und "gravity" (Rechteck mit Schwerkraftfaktor g). Optional "period"/"on"/"phase": nur während der ersten `on` Sekunden
## jeder Periode aktiv (Böen, pulsierende Magnete).
var zones: Array = []

func _scan_zones(list: Array) -> void:
	for d in list:
		var z := {"kind": String(d.get("kind", "wind")), "period": float(d.get("period", 0.0)), "on": float(d.get("on", 0.0)), "phase": float(d.get("phase", 0.0)),
			"rect": Rect2(float(d.get("x", 0)) * Tuning.TILE, float(d.get("y", 0)) * Tuning.TILE, float(d.get("w", 1)) * Tuning.TILE, float(d.get("h", 1)) * Tuning.TILE),
			"a": Vector2(float(d.get("ax", 0.0)), float(d.get("ay", 0.0))), "g": float(d.get("g", 1.0)), "k": float(d.get("k", 0.0)),
			"center": Vector2(float(d.get("cx", 0.0)), float(d.get("cy", 0.0))) * Tuning.TILE, "r": float(d.get("r", 4.0)) * Tuning.TILE,
			"cycle": bool(d.get("cycle", false))}
		if z.cycle:
			z["period"] = maxf(float(d.get("period", 16.0)), 4.0)       # Polwechsel: anziehend – aus – abstoßend – aus (je ein Viertel der Periode)
		if z.kind == "magnet":
			z["rect"] = Rect2(z.center - Vector2(z.r, z.r), Vector2(z.r, z.r) * 2.0)
		zones.append(z)

## Hitzezone (Sektor 5): Rechteck, in dem die Hülle verbrennt; optional pulsierend (Dampfauslass).
func heat_at(p: Vector2, t: float) -> bool:
	for z in zones:
		if z.kind == "heat" and (z.rect as Rect2).has_point(p) and zone_active(z, t):
			return true
	return false

## Planung: Hitzezonen gelten unabhängig vom Takt als feste Fläche.
func heat_hit_box(center: Vector2, half: Vector2) -> bool:
	if zones.is_empty():
		return false
	var box := Rect2(center - half, half * 2.0)
	for z in zones:
		if z.kind == "heat" and (z.rect as Rect2).intersects(box):
			return true
	return false

## Wimpel der Plattformen (Zahl bzw. T/L auf dem Dreieck). Benachbarte Plattformen würden sich verdecken (z. B. die 3 unter dem Tankstellenwimpel):
## dann entfällt der Wimpel der Service-Plattform an der zugewandten Seite (sie hat noch den anderen), sonst weht er nach innen, zuletzt entfällt er.
## Rückgabe: [{id, x (Mast), dir (-1 links / 1 rechts), rect}]
const FLAG_LEN := 19.0
const FLAG_H := 13.0

static func _flag_rect(x: float, dir: float, y: float) -> Rect2:
	var x2 := x + 0.5 + dir * FLAG_LEN
	return Rect2(minf(x + 0.5, x2), y - 19.0, FLAG_LEN, FLAG_H)

func pad_flags() -> Array:
	var out: Array = []
	for id in pads:
		var p: Dictionary = pads[id]
		var y: float = float(p.row) * float(Tuning.TILE)
		var shelter: Rect2 = p.get("shelter", Rect2())
		var poles: Array = [float(p.x0) + 2.0, float(p.x1) - 3.0]
		if shelter.size.x > 0.0:
			poles = [float(p.x1) - 3.0] if int(p.side) < 0 else [float(p.x0) + 2.0]
		for x in poles:
			var dir := -1.0 if x < float(p.center) else 1.0
			out.append({"id": id, "x": x, "dir": dir, "y": y, "service": bool(p.fuel) or bool(p.life), "rect": _flag_rect(x, dir, y)})
	for _round in 8:
		var hit := -1
		for i in out.size():
			for j in range(i + 1, out.size()):
				if out[i].id != out[j].id and out[i].rect.intersects(out[j].rect):
					# Opfer: Service-Plattform vor Fahrgastplattform, sonst der Wimpel mit weiter entferntem Mast
					hit = i if (out[i].service and not out[j].service) or (out[i].service == out[j].service and absf(float(out[i].x) - float(pads[out[i].id].center)) > absf(float(out[j].x) - float(pads[out[j].id].center))) else j
					break
			if hit >= 0:
				break
		if hit < 0:
			break
		var v: Dictionary = out[hit]
		var mates := 0
		for f in out:
			if f.id == v.id:
				mates += 1
		if mates > 1:
			out.remove_at(hit)
			continue
		var flipped := _flag_rect(float(v.x), -float(v.dir), float(v.y))
		var free := true
		for f in out:
			if f.id != v.id and f.rect.intersects(flipped):
				free = false
		if free and float(v.dir) == (-1.0 if float(v.x) < float(pads[v.id].center) else 1.0):
			v["dir"] = -float(v.dir)
			v["rect"] = flipped
		else:
			out.remove_at(hit)
	return out

func has_zones() -> bool:
	return not zones.is_empty()

func zone_active(z: Dictionary, t: float) -> bool:
	if z.get("cycle", false):
		return int(fposmod(t + float(z.phase), float(z.period)) / float(z.period) * 4.0) % 2 == 0
	return float(z.period) <= 0.0 or fposmod(t + float(z.phase), float(z.period)) < float(z.on)

## Viertel (0–3) und Fortschritt darin (0–1) eines Polwechsel-Magneten: 0 anziehend, 1 aus, 2 abstoßend, 3 aus.
func zone_cycle(z: Dictionary, t: float) -> Vector2:
	var q := fposmod(t + float(z.phase), float(z.period)) / float(z.period) * 4.0
	var idx := floorf(q)
	return Vector2(idx, q - idx)

## Vorzeichen der Kraft des Magneten: +1 anziehend, -1 abstoßend; im ausgeschalteten Zustand die Polarität, die als Nächstes kommt.
func zone_polarity(z: Dictionary, t: float) -> float:
	if not z.get("cycle", false):
		return 1.0 if float(z.k) > 0.0 else -1.0
	var q := int(zone_cycle(z, t).x)
	return 1.0 if q == 0 or q == 3 else -1.0

## Aktuelle Stärke (mit Vorzeichen) der Magnetkraft: bei Polwechsel mit weichem Ein- und Ausblenden an den Viertelgrenzen.
func zone_k(z: Dictionary, t: float) -> float:
	if not z.get("cycle", false):
		return float(z.k)
	var c := zone_cycle(z, t)
	if int(c.x) % 2 == 1:
		return 0.0
	var amp := smoothstep(0.0, 0.12, c.y) * (1.0 - smoothstep(0.88, 1.0, c.y))
	return float(z.k) * (1.0 if int(c.x) == 0 else -1.0) * amp

## Zusätzliche Beschleunigung (px/s²) durch Zonen am Ort p zur Zeit t.
func zone_accel(p: Vector2, t: float) -> Vector2:
	var a := Vector2.ZERO
	for z in zones:
		if not (z.rect as Rect2).has_point(p) or not zone_active(z, t):
			continue
		match String(z.kind):
			"wind":
				a += z.a as Vector2
			"gravity":
				a.y += (float(z.g) - 1.0) * gravity
			"magnet":
				var d: Vector2 = (z.center as Vector2) - p
				var dist := d.length()
				if dist < float(z.r) and dist > 2.0:
					a += d / dist * zone_k(z, t) * (1.0 - pow(dist / float(z.r), 2.0))
	return a

## Verkehr: Bahnabschnitt eines Fahrzeugpfads, in dem die Box liegt ({} sonst); "horizontal" sagt, wie der Abschnitt verläuft.
func vehicle_lane_at(center: Vector2, half: Vector2) -> Dictionary:
	var box := Rect2(center - half, half * 2.0)
	for m in movers:
		if m.kind != "vehicle":
			continue
		for ln in m.lanes:
			if (ln.rect as Rect2).intersects(box):
				return ln
	return {}

func has_traffic() -> bool:
	for m in movers:
		if m.kind == "vehicle":
			return true
	return false

func has_meteors() -> bool:
	for m in movers:
		if m.kind == "meteor" or m.kind == "beam":
			return true
	return false

func has_movers() -> bool:
	return not movers.is_empty()

func _scan_movers(list: Array) -> void:
	for d in list:
		var kind := String(d.get("kind", "debris"))
		var m := {"kind": kind, "w": float(d.get("w", 2)) * Tuning.TILE, "h": float(d.get("h", 1)) * Tuning.TILE,
			"x": float(d.get("x", 0)) * Tuning.TILE, "y": float(d.get("y", 0)) * Tuning.TILE, "ax": float(d.get("dx", 0)) * Tuning.TILE,
			"ay": float(d.get("dy", 0)) * Tuning.TILE, "period": maxf(float(d.get("period", 8.0)), 0.5), "phase": float(d.get("phase", 0.0)),
			"shape": String(d.get("shape", "line")), "pad": String(d.get("pad", "")),
			"fall": maxf(float(d.get("fall", 1.6)), 0.3), "warn": float(d.get("warn", 2.0)), "on": float(d.get("on", 3.0)),
			"speed": float(d.get("speed", 50.0)), "tint": int(d.get("tint", 0)), "paint": int(d.get("paint", d.get("tint", 0))), "spikes": bool(d.get("spikes", false))}
		if kind == "vehicle":
			m["w"] = 21.0                         # Trefferfläche passend zum Rumpf des Fahrzeugs in Taxigröße (25,6 × 16), etwas kleiner als die Grafik
			m["h"] = 10.0
			m["pw"] = 26.0                        # Autopilot plant mit dem früheren, größeren Sicherheitsabstand (Bot-Lösungen bleiben gültig)
			m["ph"] = 12.0
			_setup_vehicle_path(m, d)
		if kind == "beam":
			m["period"] = maxf(float(d.get("period", 9.0)), m.on + 1.0)
		if kind == "meteor":
			m["y0"] = m.y                         # Original-Einsatzreihe und Fallstrecke: je Fall wird der Einsatz in die erste freie Reihe gelegt
			m["ay0"] = m.ay
			m["x0"] = m.x                         # feste Bahn aus der Leveldatei, falls keine Spalte erlaubt ist
			m["w"] = float(d.get("w", 1)) * Tuning.TILE
			m["h"] = float(d.get("h", 1)) * Tuning.TILE
			m["period"] = maxf(float(d.get("period", 20.0)), m.fall + 1.0)
		if kind == "pad":
			var id: String = m.pad
			m["h"] = 2.0 * Tuning.TILE
			m["ay"] = 0.0
			pads[id] = {"id": id, "x0": m.x, "x1": m.x + m.w, "row": int(d.get("y", 0)), "center": m.x + m.w * 0.5, "fuel": false, "life": false, "moving": true, "dx": 0.0, "dx_step": 0.0}
		m["rect"] = _mover_rect(m, 0.0)
		m["vel"] = Vector2.ZERO
		movers.append(m)

func _mover_offset(m: Dictionary, t: float) -> Vector2:
	var ph := TAU * (t + float(m.phase)) / float(m.period)
	if m.shape == "circle":
		return Vector2(float(m.ax) * cos(ph), float(m.ay) * sin(ph))
	var s := sin(ph)
	return Vector2(float(m.ax) * s, float(m.ay) * s)

const OFFSCREEN := -1000.0

## Spalten (Felder), in denen ein Meteorit fallen darf: oben frei, mit freier Fallstrecke und nie über einem Pad, das gerade im Spiel ist
## (`meteor_avoid`: Abhol-/Zielpad des laufenden Auftrags und das Pad unter dem Taxi, setzt Run) oder über Tank-/Lebens-Station.
## Alle anderen Pads sind keine Sperre (sonst blieben bei Plattformen über die ganze Breite nur die Randspalten übrig); fahrende Plattformen
## sperren nur, solange sie im Spiel sind, dann samt Fahrweg. Gibt es keine Spalte, bleibt die Bahn aus dem Level (x).
var meteor_avoid: Array = []

func meteor_columns(m: Dictionary) -> Array:
	var key := ",".join(PackedStringArray(meteor_avoid))
	if m.has("cols") and String(m.get("cols_key", "")) == key:
		return m.cols
	var blocked := {}
	for pid in pads:
		var p: Dictionary = pads[pid]
		if not (meteor_avoid.has(String(pid)) or bool(p.get("fuel", false)) or bool(p.get("life", false))):
			continue
		var x0 := float(p.x0)
		var x1 := float(p.x1)
		var b: Dictionary = p.get("base", {})
		if not b.is_empty():
			x0 = float(b.x0)
			x1 = float(b.x1)
		for mv in movers:                                  # fahrende Plattform: samt Fahrweg, aber nur solange sie im Spiel ist
			if mv.kind == "pad" and String(mv.pad) == String(pid):
				x0 -= absf(float(mv.ax))
				x1 += absf(float(mv.ax))
		for c in range(int(floorf(x0 / Tuning.TILE)), int(ceilf(x1 / Tuning.TILE))):
			blocked[c] = true
	var cols: Array = []
	var starts := {}                                     # Spalte -> erste Reihe, ab der der Meteorit sichtbar fällt (bis zu 3 Reihen Fels darüber: er bricht aus der Decke)
	var w_tiles := int(round(float(m.w) / Tuning.TILE))
	var top := int(float(m.get("y0", m.y)) / Tuning.TILE)
	var bottom := top + int(float(m.get("ay0", m.ay)) / Tuning.TILE)
	for c in range(1, 39):
		var blocked_col := false
		for k in w_tiles:
			if blocked.has(c + k):
				blocked_col = true
		if blocked_col:
			continue
		var r0 := -1
		for r in range(top, top + 4):
			var open := true
			for k in w_tiles:
				if cell(c + k, r) != ".":
					open = false
			if open:
				r0 = r
				break
			var rock := true
			for k in w_tiles:
				if cell(c + k, r) != "#":
					rock = false
			if not rock:
				break                                    # Dornen, Ausgang o. Ä. oben: dort kein Einsatz
		if r0 < 0:
			continue
		var free := 0
		for r in range(r0, mini(bottom, 21)):
			if cell(c, r) == ".":
				free += 1
		if free >= 6:
			cols.append(c)
			starts[c] = r0
	m["starts"] = starts
	m["cols"] = cols
	m["cols_key"] = key
	return cols

## Bahn (linke x-Koordinate) des Falls mit der laufenden Nummer n.
func meteor_x_for(m: Dictionary, idx: int, n: int) -> float:
	var cols := meteor_columns(m)
	if cols.is_empty():
		return float(m.x0)
	var h := absi(("%s:%d:%d:%d" % [id, meteor_seed, idx, n]).hash())
	return float(cols[h % cols.size()]) * Tuning.TILE

## Meteor: Fortschritt 0..1 des laufenden Falls, -1 zwischen den Fällen.
func meteor_progress(m: Dictionary, t: float) -> float:
	var c := fposmod(t + float(m.phase), float(m.period))
	return c / float(m.fall) if c < float(m.fall) else -1.0

## Meteor: Sekunden bis zum nächsten Fall (0, solange er fällt).
func meteor_eta(m: Dictionary, t: float) -> float:
	var c := fposmod(t + float(m.phase), float(m.period))
	if m.kind == "beam":
		return 0.0 if c < float(m.on) else float(m.period) - c
	return 0.0 if c < float(m.fall) else float(m.period) - c

## Bot: Liegt die Box in der Bahn eines Meteors, der gerade fällt oder innerhalb von `horizon` Sekunden fällt? Gibt ihn zurück (sonst {}).
func meteor_threat(box: Rect2, t0: float, horizon: float) -> Dictionary:
	for m in movers:
		if (m.kind != "meteor" and m.kind != "beam") or meteor_eta(m, t0) > horizon:
			continue
		if lane_rect(m).intersects(box):
			return m
	return {}

## Bahn eines Meteors bzw. Fläche eines Plasmastrahls (für Warnung und Ausweichen).
func lane_rect(m: Dictionary) -> Rect2:
	if m.kind == "beam":
		return Rect2(float(m.x), float(m.y), float(m.w), float(m.h))
	var x0 := minf(float(m.x), float(m.x) + float(m.ax))
	var x1 := maxf(float(m.x), float(m.x) + float(m.ax)) + float(m.w)
	return Rect2(x0, float(m.y), x1 - x0, float(m.ay) + float(m.h))

## Fahrzeug (Sektor 7+, Verkehr): fährt auf einem Pfad ("path": Mittelpunkte in Feldern, meist von einer Wandöffnung zu einer anderen, auch mit
## Knicken) mit `speed` px/s. Ankunft in der Zielöffnung = unsichtbar bis zum erneuten Eintritt; mehrere Fahrzeuge je Pfad unterscheiden sich in
## der Phase. (Alt: "x", "y", "dx" = gerade Bahn von Wand zu Wand.)
func _setup_vehicle_path(m: Dictionary, d: Dictionary) -> void:
	var pts := PackedVector2Array()
	if d.has("path"):
		for p in d.path:
			pts.append(Vector2(float(p[0]), float(p[1])) * Tuning.TILE)
	else:
		var y := float(d.get("y", 0)) + 0.5
		var x0 := float(d.get("x", 1)) - 0.5
		var lane := float(d.get("dx", 38))
		if float(d.get("speed", 50.0)) >= 0.0:
			pts.append(Vector2(x0, y) * Tuning.TILE)
			pts.append(Vector2(x0 + lane + 1.0, y) * Tuning.TILE)
		else:
			pts.append(Vector2(x0 + lane + 1.0, y) * Tuning.TILE)
			pts.append(Vector2(x0, y) * Tuning.TILE)
	m["pts"] = pts
	var total := 0.0
	var lanes: Array = []
	for i in range(pts.size() - 1):
		total += pts[i].distance_to(pts[i + 1])
		var r := Rect2(pts[i], Vector2.ZERO).expand(pts[i + 1])
		var horiz := absf(pts[i + 1].x - pts[i].x) >= absf(pts[i + 1].y - pts[i].y)
		lanes.append({"rect": r.grow_individual(16.0 if horiz else 8.0, 8.0 if horiz else 16.0, 16.0 if horiz else 8.0, 8.0 if horiz else 16.0), "horizontal": horiz})
	m["total"] = total
	m["lanes"] = lanes

## Position und Ausrichtung des Fahrzeugs entlang des Pfads.
func vehicle_state(m: Dictionary, t: float) -> Dictionary:
	var sp := absf(float(m.speed))
	var period := float(m.total) + 64.0
	var s := fposmod((t + float(m.phase)) * sp, period)
	if s > float(m.total):
		return {"visible": false}
	var pts: PackedVector2Array = m.pts
	var acc := 0.0
	for i in range(pts.size() - 1):
		var seg := pts[i].distance_to(pts[i + 1])
		if s <= acc + seg or i == pts.size() - 2:
			var dir := (pts[i + 1] - pts[i]).normalized()
			return {"visible": true, "pos": pts[i] + dir * (s - acc), "dir": dir}
		acc += seg
	return {"visible": false}

func _vehicle_rect(m: Dictionary, t: float, plan := false) -> Rect2:
	var st := vehicle_state(m, t)
	if not st.visible:
		return Rect2(OFFSCREEN, OFFSCREEN, float(m.w), float(m.h))
	var dir: Vector2 = st.dir
	var w := float(m.pw) if plan else float(m.w)
	var h := float(m.ph) if plan else float(m.h)
	var c: Vector2 = st.pos
	if absf(dir.x) >= absf(dir.y):
		return Rect2(c.x - w * 0.5, c.y - h * 0.5, w, h)
	return Rect2(c.x - h * 0.5, c.y - w * 0.5, h, w)

## Plasmastrahl: nur in den ersten `on` Sekunden jeder Periode sichtbar und gefährlich (Rechteck x/y/w/h fest).
## `plan`: Rechteck für die Vorausplanung des Autopiloten (Fahrzeuge mit Sicherheitsabstand), sonst die echte Trefferfläche.
func _mover_rect(m: Dictionary, t: float, plan := false) -> Rect2:
	if m.kind == "vehicle":
		return _vehicle_rect(m, t, plan)
	if m.kind == "beam":
		if fposmod(t + float(m.phase), float(m.period)) >= float(m.on):
			return Rect2(OFFSCREEN, OFFSCREEN, float(m.w), float(m.h))
		return Rect2(float(m.x), float(m.y), float(m.w), float(m.h))
	if m.kind == "meteor":
		var k := meteor_progress(m, t)
		if k < 0.0:
			return Rect2(OFFSCREEN, OFFSCREEN, float(m.w), float(m.h))
		return Rect2(float(m.x) + float(m.ax) * k, float(m.y) + float(m.ay) * k, float(m.w), float(m.h))
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
	for mi in movers.size():
		var m: Dictionary = movers[mi]
		if m.kind == "meteor":
			var cyc := floorf((t + float(m.phase)) / float(m.period))
			var falling := fposmod(t + float(m.phase), float(m.period)) < float(m.fall)
			var nfall := int(cyc) + (0 if falling else 1)
			var warn_at := float(m.warn) + 0.5                                   # Bahn erst kurz vor dem Fall festlegen: dann gelten die aktuellen Pads im Spiel
			if int(m.get("lane_n", -1)) != nfall and (falling or meteor_eta(m, t) <= warn_at or reset):
				m["lane_n"] = nfall
				m["x"] = meteor_x_for(m, mi, nfall)                              # laufender bzw. nächster Fall
				var col := int(round(float(m.x) / Tuning.TILE))
				var r0 := int(m.get("starts", {}).get(col, int(float(m.y0) / Tuning.TILE)))
				m["y"] = float(r0) * Tuning.TILE
				m["ay"] = maxf(float(m.y0) + float(m.ay0) - m.y, Tuning.TILE)
		var old: Rect2 = m.rect
		var r := _mover_rect(m, t)
		m.vel = Vector2.ZERO if reset else (r.position - old.position) / Tuning.TICK
		if m.kind == "meteor":
			m.vel = Vector2(float(m.ax), float(m.ay)) / float(m.fall) if (not reset and r.position.x > OFFSCREEN) else Vector2.ZERO
		elif m.kind == "vehicle":
			var vs := vehicle_state(m, t)
			m.vel = (vs.dir * absf(float(m.speed))) if (vs.visible and not reset) else Vector2.ZERO
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
		if m.kind != "beam" and (m.rect.intersects(box) or (m.spikes and pad_spike_rect(m).intersects(box))):          # Plasmastrahlen sind nicht fest: man fliegt hindurch (und verbrennt)
			return true
	return false

## Planung: fahrende Pads belegen ihren gesamten Fahrweg (Platte + Schiene) als feste Fläche.
## Mit `sweep_core` (Lösbarkeitsprüfung, Autopilot-Rückfall) nur der Kern: Bereich, den die Platte in jeder Stellung ihrer Fahrt belegt.
## Sonst wäre eine Öffnung, an der die Platte nur zeitweise vorbeifährt, dauerhaft gesperrt, obwohl man dort durchkommt, wenn sie weg ist.
func pad_sweeps_hit(center: Vector2, half: Vector2) -> bool:
	var box := Rect2(center - half, half * 2.0)
	for m in movers:
		if m.kind != "pad":
			continue
		if sweep_core:
			var cw := float(m.w) - 2.0 * float(m.ax)
			if cw > 0.0 and Rect2(float(m.x) + float(m.ax), float(m.y), cw, float(m.h)).intersects(box):
				return true
		elif Rect2(float(m.x) - float(m.ax), float(m.y), float(m.w) + 2.0 * float(m.ax), float(m.h)).intersects(box):
			return true
	return false

## Bot: Trifft das Taxi auf seiner voraussichtlichen Bahn (Anfahrt von v0 auf v_des, Zeitkonstante 0,3 s) innerhalb des
## Horizonts ein Hindernis (Trümmer/Schieber; Pads zählen nicht)? Prüft die Mover-Positionen zu jedem Zeitpunkt mit.
## `pads_too`: auch fahrende Plattformen (außer `skip_pad`, dem Zielpad) zählen als Hindernis.
func movers_collide_traj(p0: Vector2, v0: Vector2, v_des: Vector2, half: Vector2, t0: float, horizon: float, pads_too := false, skip_pad := "") -> bool:
	var t := 0.1
	while t <= horizon:
		var k := 1.0 - exp(-t / 0.3)
		var p := p0 + v_des * t + (v0 - v_des) * 0.3 * k
		var box := Rect2(p - half, half * 2.0)
		for m in movers:
			if (m.kind != "pad" or (pads_too and String(m.pad) != skip_pad)) and _mover_rect(m, t0 + t, true).intersects(box):
				return true
		t += 0.1
	return false

## Trifft eine Box, die sich zur Zeit `t0 + t` an `p` befindet, ein Hindernis (Pads nur mit `pads_too`, außer dem Zielpad)?
func movers_hit_at(p: Vector2, half: Vector2, t: float, pads_too := false, skip_pad := "") -> bool:
	var box := Rect2(p - half, half * 2.0)
	for m in movers:
		if (m.kind != "pad" or (pads_too and String(m.pad) != skip_pad)) and _mover_rect(m, t, true).intersects(box):
			return true
	return false

## Zapfsäulen (Säule und breiterer Kopf mit der Preisanzeige, wie in `Run._check_pump`) gegen eine Box.
func pumps_hit_box(center: Vector2, half: Vector2) -> bool:
	var box := Rect2(center - half, half * 2.0)
	for pm in pumps:
		var pr: Rect2 = pm.rect
		if box.intersects(pr) or box.intersects(Rect2(pr.position.x + pr.size.x * 0.5 - 11.0, pr.end.y - 35.2, 22.0, 16.0)):
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
			if m.kind != "pad" and _mover_rect(m, t, true).intersects(box):
				return true
		t += 0.15
	return false

func has_doors() -> bool:
	return not doors.is_empty()

func door_is_open(ch: String, t: float) -> bool:
	var d: Dictionary = doors.get(ch, {})
	return doors_forced_open or d.is_empty() or fposmod(t + float(d.phase), float(d.period)) < float(d.open)

## Öffnung des Tors: 1 = ganz offen, 0 = geschlossen. Im Takt: offen, schließen, kurz geschlossen, öffnen.
func door_gap(ch: String, t: float) -> float:
	var d: Dictionary = doors.get(ch, {})
	if doors_forced_open or d.is_empty():
		return 1.0
	var m := fposmod(t + float(d.phase), float(d.period))
	var shut := float(d.open) + DOOR_CLOSE
	var shut_end := maxf(float(d.period) - DOOR_OPEN, shut)
	if m < float(d.open):
		return 1.0
	if m < shut:
		return 1.0 - (m - float(d.open)) / DOOR_CLOSE
	return 0.0 if m < shut_end else (m - shut_end) / (float(d.period) - shut_end)

## Die beiden Flügel eines Tors bei Öffnung `gap`.
static func door_leaves(gate: Dictionary, gap: float) -> Array:
	var r: Rect2 = gate.rect
	var f := (1.0 - gap) * 0.5
	if gate.vertical:
		var h := r.size.y * f
		return [Rect2(r.position, Vector2(r.size.x, h)), Rect2(r.position.x, r.end.y - h, r.size.x, h)]
	var w := r.size.x * f
	return [Rect2(r.position, Vector2(w, r.size.y)), Rect2(r.end.x - w, r.position.y, w, r.size.y)]

## Sweep-Schleuse: Lage der Mitte der Öffnung zur Zeit t (Pixel), gleichmäßig hin und her ohne Halt: bei senkrechten Toren die Höhe (y), bei waagerechten
## (Flügel fahren seitlich, Durchflug von oben/unten) die Breite (x).
func sweep_center(ch: String, gate: Dictionary, t: float) -> float:
	var d: Dictionary = doors[ch]
	var r: Rect2 = gate.rect
	var half := float(d.gap_cells) * Tuning.TILE * 0.5
	var u := fposmod(t + float(d.phase), 2.0 * float(d.sweep)) / float(d.sweep)
	if u > 1.0:
		u = 2.0 - u
	if not gate.vertical:
		return lerpf(r.position.x + half, r.end.x - half, u)
	return lerpf(r.position.y + half, r.end.y - half, u)

## Ist der Durchflug auf Höhe `y` (Box mit halber Höhe `half_h`) im Zeitfenster [t0, t0 + length] frei von Flügeln?
func door_clear_window(ch: String, t0: float, length: float, y: float, half_h: float) -> bool:
	var d: Dictionary = doors.get(ch, {})
	if doors_forced_open or d.is_empty():
		return true
	var t := t0
	while t <= t0 + length + 0.001:
		for gate in d.gates:
			for leaf in door_leaf_rects(ch, gate, t):
				if leaf.size.y > 0.0 and y + half_h > leaf.position.y and y - half_h < leaf.end.y:
					return false
		t += 0.05
	return true

func is_sweep(ch: String) -> bool:
	return float(doors.get(ch, {}).get("sweep", 0.0)) > 0.0

## Sweep-Schleuse mit senkrecht fahrenden Flügeln (die Öffnung wandert in der Höhe)? Der Autopilot kennt nur diese Form.
func is_sweep_vertical(ch: String) -> bool:
	if not is_sweep(ch):
		return false
	for gate in doors[ch].gates:
		if not gate.vertical:
			return false
	return true

## Feste Flügel eines Tors zur Zeit t: oberhalb und unterhalb der Öffnung (Sweep) bzw. die beiden Schiebeflügel.
func door_leaf_rects(ch: String, gate: Dictionary, t: float) -> Array:
	if not is_sweep(ch) or doors_forced_open:
		return door_leaves(gate, door_gap(ch, t))
	var r: Rect2 = gate.rect
	var c := sweep_center(ch, gate, t)
	var half := float(doors[ch].gap_cells) * Tuning.TILE * 0.5
	if not gate.vertical:
		return [Rect2(r.position.x, r.position.y, c - half - r.position.x, r.size.y), Rect2(c + half, r.position.y, r.end.x - c - half, r.size.y)]
	return [Rect2(r.position.x, r.position.y, r.size.x, c - half - r.position.y), Rect2(r.position.x, c + half, r.size.x, r.end.y - c - half)]

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

func _door_cell_closed(c: String, cx := -1, cy := -1) -> bool:
	if doors_ignore:
		return false
	if is_sweep(c):                                       # Sweep: keine Zellen-Sperre, die exakten Flügel prüft hits_closed_door (Öffnung bleibt voll 3 Felder hoch)
		return false
	return door_gap(c, clock) <= 0.0

## Berührt die Box einen Torflügel?
func hits_closed_door(center: Vector2, half: Vector2) -> bool:
	if doors.is_empty() or doors_ignore:
		return false
	var box := Rect2(center - half, half * 2.0)
	for ch in doors:
		var sweep := is_sweep(ch)
		if not sweep and door_gap(ch, clock) >= 1.0:
			continue
		for gate in doors[ch].gates:
			for leaf in door_leaf_rects(ch, gate, clock):
				if leaf.size.x > 0.0 and leaf.size.y > 0.0 and box.intersects(leaf):
					return true
	return false

## Weg aus dem Tor für eine Box, die die Flügel treffen: quer zu ihrer Fahrrichtung zur näheren freien Seite, ganz aus dem Tor heraus. Null, wenn beide Seiten belegt sind.
func door_escape(center: Vector2, half: Vector2) -> Vector2:
	var box := Rect2(center - half, half * 2.0)
	for ch in doors:
		for gate in doors[ch].gates:
			var r: Rect2 = gate.rect
			if not box.intersects(r):
				continue
			var a := Vector2(r.position.x - half.x - 1.0 - center.x, 0.0) if gate.vertical else Vector2(0.0, r.position.y - half.y - 1.0 - center.y)
			var b := Vector2(r.end.x + half.x + 1.0 - center.x, 0.0) if gate.vertical else Vector2(0.0, r.end.y + half.y + 1.0 - center.y)
			for out in ([a, b] if a.length() <= b.length() else [b, a]):
				if not box_hits_solid(center + out, half):
					return out
	return Vector2.ZERO

func is_solid_cell(cx: int, cy: int) -> bool:
	var c := cell(cx, cy)
	if c != "" and DOOR_CHARS.contains(c):
		return _door_cell_closed(c, cx, cy)
	return c == SOLID or c == "^" or c == "P" or (c >= "1" and c <= "9") or c == "F" or c == "L" or c == "H" or (c == "E" and not exit_open)

func is_solid_at(p: Vector2) -> bool:
	if not movers.is_empty() and not movers_ignore:
		for m in movers:
			if m.kind != "beam" and m.rect.has_point(p):
				return true
	if hits_closed_door(p, Vector2(0.01, 0.01)):
		return true
	return is_solid_cell(floori(p.x / Tuning.TILE), floori(p.y / Tuning.TILE))

func box_hits_solid(center: Vector2, half: Vector2) -> bool:
	if movers_hit_box(center, half) or hits_closed_door(center, half):
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

## Wie box_hits_solid, aber nur das feste Raster (ohne Mover).
func box_hits_cells(center: Vector2, half: Vector2) -> bool:
	if hits_closed_door(center, half):
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

## Dornen an der Unterseite fahrender Plattformen (Mover "pad" mit "spikes": true).
const PAD_SPIKE_H := 7.0

func pad_spike_rect(m: Dictionary) -> Rect2:
	var r: Rect2 = m.rect
	return Rect2(r.position.x, r.end.y, r.size.x, PAD_SPIKE_H)

func box_hits_pad_spikes(center: Vector2, half: Vector2) -> bool:
	var box := Rect2(center - half, half * 2.0)
	for m in movers:
		if m.spikes and not movers_ignore and box.intersects(pad_spike_rect(m)):
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
	if (c >= "1" and c <= "9") or c == "F" or c == "L" or c == "H":
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
