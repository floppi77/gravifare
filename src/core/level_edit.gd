extends RefCounted
## Bearbeitungsmodell des Level-Editors (ohne Oberfläche, testbar): Karte als Textzeilen, Zeichenwerkzeuge, Rückgängig/Wiederholen, Pad-Nummern
## und Prüfung über community_level.gd. Türen, bewegliche Hindernisse, Zonen und Dunkelheit eines geladenen Levels bleiben unverändert erhalten
## (der Editor zeigt sie, bearbeitet sie aber noch nicht). Verwendung (ohne class_name): const LevelEdit := preload("res://src/core/level_edit.gd")

const CL := preload("res://src/core/community_level.gd")
const MAX_UNDO := 100
const PAD_CHARS := "123456789"
## Paletteneinträge: Zeichen, Textschlüssel. Pads 1–9 stehen einzeln (jede Nummer nur einmal pro Level).
const PALETTE := [["#", "ED_T_ROCK"], [".", "ED_T_AIR"], ["1", "ED_T_PAD"], ["2", "ED_T_PAD"], ["3", "ED_T_PAD"], ["4", "ED_T_PAD"], ["5", "ED_T_PAD"], ["6", "ED_T_PAD"],
	["7", "ED_T_PAD"], ["8", "ED_T_PAD"], ["9", "ED_T_PAD"], ["F", "ED_T_FUEL"], ["L", "ED_T_LIFE"], ["H", "ED_T_HOSPITAL"], ["^", "ED_T_SPIKES"], ["P", "ED_T_PUMP"], ["S", "ED_T_START"],
	["a", "ED_T_DOOR"], ["b", "ED_T_DOOR"], ["c", "ED_T_DOOR"], ["d", "ED_T_DOOR"], ["e", "ED_T_DOOR"]]
const DOOR_CHARS := "abcde"
const KINDS := ["debris", "slider", "pad", "meteor", "beam", "vehicle", "wind", "magnet", "gravity", "heat"]
## Parameter je Art: [Schlüssel, Min, Max, Schritt, Textschlüssel]. Zahlen in Feldern bzw. Sekunden; "period" > 0 bei Zonen = pulsierend (0 = dauerhaft).
## Schalter (shape, spikes, cycle, glass, tint) sind 0/1; "pad" ist die Pad-Ziffer eines fahrenden Pads.
const PARAMS := {
	"debris": [["x", -8.0, 64.0, 1.0, "ED_P_X"], ["y", -8.0, 64.0, 1.0, "ED_P_Y"], ["w", 1.0, 64.0, 1.0, "ED_P_W"], ["h", 1.0, 64.0, 1.0, "ED_P_H"],
		["dx", -64.0, 64.0, 1.0, "ED_P_DX"], ["dy", -64.0, 64.0, 1.0, "ED_P_DY"], ["period", 0.5, 120.0, 0.5, "ED_P_PERIOD"], ["phase", -240.0, 240.0, 0.5, "ED_P_PHASE"],
		["shape", 0.0, 1.0, 1.0, "ED_P_SHAPE"]],
	"slider": [["x", -8.0, 64.0, 1.0, "ED_P_X"], ["y", -8.0, 64.0, 1.0, "ED_P_Y"], ["w", 1.0, 64.0, 1.0, "ED_P_W"], ["h", 1.0, 64.0, 1.0, "ED_P_H"],
		["dx", -64.0, 64.0, 1.0, "ED_P_DX"], ["dy", -64.0, 64.0, 1.0, "ED_P_DY"], ["period", 0.5, 120.0, 0.5, "ED_P_PERIOD"], ["phase", -240.0, 240.0, 0.5, "ED_P_PHASE"],
		["shape", 0.0, 1.0, 1.0, "ED_P_SHAPE"]],
	"pad": [["pad", 1.0, 9.0, 1.0, "ED_P_PAD"], ["x", -8.0, 64.0, 1.0, "ED_P_X"], ["y", -8.0, 64.0, 1.0, "ED_P_Y"], ["w", 4.0, 64.0, 1.0, "ED_P_W"], ["dx", -64.0, 64.0, 1.0, "ED_P_DX"],
		["period", 0.5, 120.0, 0.5, "ED_P_PERIOD"], ["phase", -240.0, 240.0, 0.5, "ED_P_PHASE"], ["spikes", 0.0, 1.0, 1.0, "ED_P_SPIKES"]],
	"meteor": [["x", -8.0, 64.0, 1.0, "ED_P_X"], ["y", -8.0, 64.0, 1.0, "ED_P_Y"], ["w", 1.0, 64.0, 1.0, "ED_P_W"], ["h", 1.0, 64.0, 1.0, "ED_P_H"],
		["dx", -64.0, 64.0, 1.0, "ED_P_FALLX"], ["dy", -64.0, 64.0, 1.0, "ED_P_FALLY"], ["period", 0.5, 120.0, 0.5, "ED_P_PERIOD"], ["fall", 0.3, 30.0, 0.1, "ED_P_FALL"],
		["warn", 0.0, 30.0, 0.2, "ED_P_WARN"], ["phase", -240.0, 240.0, 0.5, "ED_P_PHASE"]],
	"beam": [["x", -8.0, 64.0, 1.0, "ED_P_X"], ["y", -8.0, 64.0, 1.0, "ED_P_Y"], ["w", 1.0, 64.0, 1.0, "ED_P_W"], ["h", 1.0, 64.0, 1.0, "ED_P_H"],
		["period", 0.5, 120.0, 0.5, "ED_P_PERIOD"], ["on", 0.0, 60.0, 0.2, "ED_P_ON"], ["warn", 0.0, 30.0, 0.2, "ED_P_WARN"], ["phase", -240.0, 240.0, 0.5, "ED_P_PHASE"],
		["tint", 0.0, 1.0, 1.0, "ED_P_TINT"]],
	"vehicle_lane": [["x", -8.0, 64.0, 1.0, "ED_P_X"], ["y", -8.0, 64.0, 1.0, "ED_P_Y"], ["dx", -64.0, 64.0, 1.0, "ED_P_LANE"], ["speed", -400.0, 400.0, 4.0, "ED_P_SPEED"],
		["paint", 0.0, 7.0, 1.0, "ED_P_PAINT"], ["phase", -240.0, 240.0, 0.5, "ED_P_PHASE"]],
	"vehicle": [["speed", -400.0, 400.0, 4.0, "ED_P_SPEED"], ["paint", 0.0, 7.0, 1.0, "ED_P_PAINT"], ["phase", -240.0, 240.0, 0.5, "ED_P_PHASE"]],
	"wind": [["x", -8.0, 64.0, 1.0, "ED_P_X"], ["y", -8.0, 64.0, 1.0, "ED_P_Y"], ["w", 1.0, 64.0, 1.0, "ED_P_W"], ["h", 1.0, 64.0, 1.0, "ED_P_H"],
		["ax", -400.0, 400.0, 5.0, "ED_P_AX"], ["ay", -400.0, 400.0, 5.0, "ED_P_AY"], ["period", 0.0, 120.0, 0.5, "ED_P_GUST"], ["on", 0.0, 120.0, 0.5, "ED_P_ON"], ["phase", -240.0, 240.0, 0.5, "ED_P_PHASE"]],
	"magnet": [["cx", -8.0, 64.0, 1.0, "ED_P_CX"], ["cy", -8.0, 64.0, 1.0, "ED_P_CY"], ["r", 0.5, 20.0, 0.5, "ED_P_R"], ["k", -400.0, 400.0, 10.0, "ED_P_K"],
		["cycle", 0.0, 1.0, 1.0, "ED_P_CYCLE"], ["period", 0.0, 120.0, 0.5, "ED_P_GUST"], ["on", 0.0, 120.0, 0.5, "ED_P_ON"], ["phase", -240.0, 240.0, 0.5, "ED_P_PHASE"]],
	"gravity": [["x", -8.0, 64.0, 1.0, "ED_P_X"], ["y", -8.0, 64.0, 1.0, "ED_P_Y"], ["w", 1.0, 64.0, 1.0, "ED_P_W"], ["h", 1.0, 64.0, 1.0, "ED_P_H"],
		["g", -3.0, 3.0, 0.05, "ED_P_G"], ["period", 0.0, 120.0, 0.5, "ED_P_GUST"], ["on", 0.0, 120.0, 0.5, "ED_P_ON"], ["phase", -240.0, 240.0, 0.5, "ED_P_PHASE"]],
	"heat": [["x", -8.0, 64.0, 1.0, "ED_P_X"], ["y", -8.0, 64.0, 1.0, "ED_P_Y"], ["w", 1.0, 64.0, 1.0, "ED_P_W"], ["h", 1.0, 64.0, 1.0, "ED_P_H"],
		["period", 0.0, 120.0, 0.5, "ED_P_GUST"], ["on", 0.0, 120.0, 0.5, "ED_P_ON"], ["phase", -240.0, 240.0, 0.5, "ED_P_PHASE"]],
	"door": [["period", 2.0, 60.0, 0.5, "ED_P_PERIOD"], ["open", 0.0, 60.0, 0.5, "ED_P_OPEN"], ["phase", 0.0, 240.0, 0.5, "ED_P_PHASE"], ["sweep", 0.0, 60.0, 0.5, "ED_P_SWEEP"],
		["gap", 1.0, 8.0, 1.0, "ED_P_GAP"], ["glass", 0.0, 1.0, 1.0, "ED_P_GLASS"]]}
const DEFAULTS := {
	"debris": {"w": 2.0, "h": 1.0, "dx": 4.0, "dy": 0.0, "period": 8.0, "phase": 0.0, "shape": "line"},
	"slider": {"w": 2.0, "h": 3.0, "dx": 0.0, "dy": 3.0, "period": 8.0, "phase": 0.0, "shape": "line"},
	"pad": {"w": 4.0, "dx": 6.0, "period": 10.0, "phase": 0.0},
	"meteor": {"w": 1.0, "h": 1.0, "dx": 0.0, "dy": 8.0, "period": 20.0, "fall": 1.6, "warn": 2.0, "phase": 0.0},
	"beam": {"w": 1.0, "h": 6.0, "period": 9.0, "on": 3.0, "warn": 2.0, "phase": 0.0, "tint": 0},
	"vehicle": {"w": 1.0, "h": 1.0, "dx": 20.0, "speed": 50.0, "paint": 0, "phase": 0.0},
	"wind": {"w": 6.0, "h": 4.0, "ax": 30.0, "ay": 0.0},
	"magnet": {"r": 4.0, "k": 100.0},
	"gravity": {"w": 6.0, "h": 6.0, "g": 0.4},
	"heat": {"w": 4.0, "h": 3.0, "period": 8.0, "on": 4.0, "phase": 0.0}}

var rows: Array = []
var w := 0
var h := 0
var names := {}
var sector := 1
var index := CL.DEFAULT_INDEX
var dark := 0.0
var doors := {}
var movers: Array = []
var zones: Array = []
var jobs: Array = []
var job_seed := 0
var author := ""
var license := CL.DEFAULT_LICENSE
var derived_from := ""
var dirty := false
var jobs_reset := false                  # Aufträge mussten neu erzeugt werden, weil die Karte nicht mehr zu ihnen passt
var _undo: Array = []
var _redo: Array = []
var _stroke_open := false
var _stroke_changed := false

# ---------------------------------------------------------------------------------------------------------------- Anlegen und Laden

## Leeres, gültiges Level: Randfels, Ausgangstor mittig oben, drei Pads am Boden und der Start über Pad 1.
static func blank(width := 40, height := 22) -> RefCounted:
	var m := new()
	m.w = clampi(width, CL.MIN_W, CL.MAX_W)
	m.h = clampi(height, CL.MIN_H, CL.MAX_H)
	for y in m.h:
		m.rows.append("#".repeat(m.w) if y == 0 or y == m.h - 1 else "#" + ".".repeat(m.w - 2) + "#")
	var gate := m.w / 2 - 2
	for y in [1, 2]:
		m.rows[y] = String(m.rows[y]).substr(0, gate) + "EEEE" + String(m.rows[y]).substr(gate + 4)
	var py: int = m.h - 2
	for pad in [["1", 3], ["2", m.w / 2 - 2], ["3", m.w - 7]]:
		var x0: int = pad[1]
		m.rows[py] = String(m.rows[py]).substr(0, x0) + String(pad[0]).repeat(4) + String(m.rows[py]).substr(x0 + 4)
	m.rows[py - 1] = String(m.rows[py - 1]).substr(0, 4) + "S" + String(m.rows[py - 1]).substr(5)
	m.names = {"de": "Neues Level", "en": "New level"}
	return m

## Aus einem geprüften Ergebnis von `CommunityLevel.clean` (ok = true).
static func from_result(res: Dictionary) -> RefCounted:
	var m := new()
	var lv: Dictionary = res.level
	m.rows = lv.map.duplicate()
	m.h = m.rows.size()
	m.w = String(m.rows[0]).length()
	m.names = lv.name.duplicate()
	m.sector = int(lv.sector)
	m.index = int(lv.index)
	m.dark = float(lv.dark)
	m.doors = lv.doors.duplicate(true)
	m.movers = lv.movers.duplicate(true)
	m.zones = lv.zones.duplicate(true)
	m.jobs = lv.jobs.duplicate(true)
	m.author = String(res.meta.get("author", ""))
	m.license = String(res.meta.get("license", CL.DEFAULT_LICENSE))
	m.derived_from = String(res.meta.get("derived_from", ""))
	return m

func to_level_dict() -> Dictionary:
	var d := {"name": names.duplicate(), "sector": sector, "index": index, "dark": dark, "map": rows.duplicate(), "doors": doors.duplicate(true),
		"movers": movers.duplicate(true), "zones": zones.duplicate(true), "jobs": jobs.duplicate(true)}
	if job_seed > 0:
		d["job_seed"] = job_seed                 # gilt nur, solange keine eigenen Aufträge da sind (die Prüfung wertet es dann aus)
	return d

func to_wrapper() -> Dictionary:
	var doc := {"format": CL.FORMAT, "version": CL.VERSION, "author": author, "license": license, "level": to_level_dict()}
	if derived_from != "":
		doc["derived_from"] = derived_from
	return doc

## Prüfung wie beim Einlesen, ohne Zugriff auf das Modell (darf in einem Arbeitsfaden laufen). Passen die Aufträge nicht mehr zur Karte (nur `JOB_*`-Fehler),
## werden sie verworfen und neu erzeugt: Ergebnis mit `jobs_reset = true`.
static func validate_wrapper(doc: Dictionary) -> Dictionary:
	var res := CL.clean(doc)
	if not res.ok and not (doc.level.get("jobs", []) as Array).is_empty():
		var only_jobs: bool = not res.errors.is_empty()
		for e in res.errors:
			only_jobs = only_jobs and String(e.code).begins_with("JOB_")
		if only_jobs:
			var d2: Dictionary = doc.duplicate(true)
			d2.level["jobs"] = []
			res = CL.clean(d2)
			res["jobs_reset"] = true
	return res

## Prüfung des Modells (gleichzeitig): verworfene Aufträge werden auch im Modell gelöscht.
func validate() -> Dictionary:
	var res := validate_wrapper(to_wrapper())
	jobs_reset = bool(res.get("jobs_reset", false))
	if jobs_reset:
		jobs = []
	return res

# ---------------------------------------------------------------------------------------------------------------- Karte

func cell(x: int, y: int) -> String:
	if x < 0 or y < 0 or y >= h or x >= w:
		return "#"
	return String(rows[y])[x]

func in_bounds(x: int, y: int) -> bool:
	return x >= 0 and y >= 0 and x < w and y < h

func is_locked(x: int, y: int) -> bool:
	return cell(x, y) == "E"                # das Ausgangstor liegt fest mittig oben

func start_cell() -> Vector2i:
	for y in h:
		var x := String(rows[y]).find("S")
		if x >= 0:
			return Vector2i(x, y)
	return Vector2i(-1, -1)

func _put(x: int, y: int, ch: String) -> void:
	var row: String = rows[y]
	rows[y] = row.substr(0, x) + ch + row.substr(x + 1)

## Zeichnet ein Feld. Das Ausgangstor ist fest; der Start lässt sich nur verschieben (Zeichen "S" setzt ihn um), nicht überschreiben.
func set_cell(x: int, y: int, ch: String) -> bool:
	if not in_bounds(x, y) or cell(x, y) == ch or ch == "E" or is_locked(x, y):
		return false
	if cell(x, y) == "S":
		return false
	if ch == "S":
		if cell(x, y) != ".":
			return false                  # der Start gehört in die Luft (über ein Pad), nicht in Fels
		var old := start_cell()
		if old.x >= 0:
			_put(old.x, old.y, ".")
	_put(x, y, ch)
	_mark_changed()
	return true

func _mark_changed() -> void:
	dirty = true
	_stroke_changed = true

## Ein Strich (Maus gedrückt, Taste gehalten) ist ein einziger Rückgängig-Schritt.
func begin_stroke() -> void:
	if _stroke_open:
		return
	_stroke_open = true
	_stroke_changed = false
	_undo.append(_snap())
	if _undo.size() > MAX_UNDO:
		_undo.pop_front()
	_redo.clear()

func end_stroke() -> void:
	if not _stroke_open:
		return
	_stroke_open = false
	if not _stroke_changed and not _undo.is_empty():
		_undo.pop_back()

func line(a: Vector2i, b: Vector2i, ch: String) -> int:
	var n := 0
	var dx := absi(b.x - a.x)
	var dy := -absi(b.y - a.y)
	var sx := 1 if a.x < b.x else -1
	var sy := 1 if a.y < b.y else -1
	var err := dx + dy
	var p := a
	for i in 4096:
		if set_cell(p.x, p.y, ch):
			n += 1
		if p == b:
			break
		var e2 := 2 * err
		if e2 >= dy:
			err += dy
			p.x += sx
		if e2 <= dx:
			err += dx
			p.y += sy
	return n

func rect(a: Vector2i, b: Vector2i, ch: String) -> int:
	var n := 0
	for y in range(mini(a.y, b.y), maxi(a.y, b.y) + 1):
		for x in range(mini(a.x, b.x), maxi(a.x, b.x) + 1):
			if set_cell(x, y, ch):
				n += 1
	return n

## Füllt das zusammenhängende Gebiet gleicher Felder (4er-Nachbarschaft); feste Felder (Tor, Start) bleiben.
func flood(x: int, y: int, ch: String) -> int:
	if not in_bounds(x, y):
		return 0
	var old := cell(x, y)
	if old == ch or old == "E" or old == "S":
		return 0
	var n := 0
	var todo: Array[Vector2i] = [Vector2i(x, y)]
	var seen := {Vector2i(x, y): true}
	while not todo.is_empty():
		var p: Vector2i = todo.pop_back()
		if set_cell(p.x, p.y, ch):
			n += 1
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var q: Vector2i = p + d
			if in_bounds(q.x, q.y) and not seen.has(q) and cell(q.x, q.y) == old:
				seen[q] = true
				todo.append(q)
	return n

## Rückgängig-Schritt: alles Bearbeitbare (Karte, Aufträge, Hindernisse, Zonen, Tore, Optik).
func _snap() -> Dictionary:
	return {"rows": rows.duplicate(), "jobs": jobs.duplicate(true), "seed": job_seed, "movers": movers.duplicate(true), "zones": zones.duplicate(true),
		"doors": doors.duplicate(true), "dark": dark, "sector": sector}

func _restore(st: Dictionary) -> void:
	rows = st.rows
	jobs = st.jobs
	job_seed = int(st.seed)
	movers = st.movers
	zones = st.zones
	doors = st.doors
	dark = float(st.dark)
	sector = int(st.sector)

func can_undo() -> bool:
	return not _undo.is_empty()

func can_redo() -> bool:
	return not _redo.is_empty()

func undo() -> bool:
	if _undo.is_empty():
		return false
	_redo.append(_snap())
	_restore(_undo.pop_back())
	dirty = true
	return true

func redo() -> bool:
	if _redo.is_empty():
		return false
	_undo.append(_snap())
	_restore(_redo.pop_back())
	dirty = true
	return true

# ---------------------------------------------------------------------------------------------------------------- Pads und Aufträge

## Zusammenhängende Passagierpad-Stücke: [{ch, x0, x1, row}] (x1 inklusive).
func pad_runs() -> Array:
	var out: Array = []
	for y in h:
		var row: String = rows[y]
		var x := 0
		while x < row.length():
			var c := row[x]
			if PAD_CHARS.contains(c):
				var x1 := x
				while x1 + 1 < row.length() and row[x1 + 1] == c:
					x1 += 1
				out.append({"ch": c, "x0": x, "x1": x1, "row": y})
				x = x1
			x += 1
	return out

## Kleinste noch unbenutzte Pad-Ziffer ("" wenn alle neun vergeben sind).
func next_free_pad() -> String:
	var used := {}
	for r in pad_runs():
		used[r.ch] = true
	for c in PAD_CHARS:
		if not used.has(c):
			return c
	return ""

func pad_used(ch: String) -> bool:
	for r in pad_runs():
		if r.ch == ch:
			return true
	return false

## Nummeriert die Passagierpads lückenlos neu (von oben nach unten, links nach rechts) und überträgt die Aufträge.
func renumber_pads() -> bool:
	var runs := pad_runs()
	runs.sort_custom(func(a, b): return a.row < b.row or (a.row == b.row and a.x0 < b.x0))
	var changed := false
	begin_stroke()
	var jmap := {}
	for i in runs.size():
		var r: Dictionary = runs[i]
		var nc := str(i + 1)
		if nc != r.ch:
			changed = true
		jmap[r.ch] = nc
	for i in runs.size():
		var r2: Dictionary = runs[i]
		for x in range(r2.x0, r2.x1 + 1):
			_put(x, r2.row, str(i + 1))
	if changed:
		_mark_changed()
		for j in jobs:
			j["from"] = jmap.get(String(j.from), String(j.from))
			if String(j.to) != "exit" and String(j.to) != "H":
				j["to"] = jmap.get(String(j.to), String(j.to))
	end_stroke()
	return changed

func reroll_jobs() -> void:
	begin_stroke()
	jobs = []
	job_seed = job_seed % 99999 + 1
	_mark_changed()
	end_stroke()

# ---------------------------------------------------------------------------------------------------------------- Objekte (Tore, Hindernisse, Zonen)

func _edit(f: Callable) -> void:
	var own := not _stroke_open
	if own:
		begin_stroke()
	f.call()
	if own:
		end_stroke()

## Buchstaben der Tore, die auf der Karte vorkommen.
func door_letters() -> Array:
	var out: Array = []
	for ch in DOOR_CHARS:
		for r in rows:
			if String(r).contains(ch):
				out.append(ch)
				break
	return out

## Alle bearbeitbaren Objekte: Tore (je Buchstabe), Hindernisse, Zonen. Verweise: {"t": "door", "k": "a"} / {"t": "mover"|"zone", "i": Index}.
func objects() -> Array:
	var out: Array = []
	for ch in door_letters():
		out.append({"t": "door", "k": ch})
	for i in movers.size():
		out.append({"t": "mover", "i": i})
	for i in zones.size():
		out.append({"t": "zone", "i": i})
	return out

func same_ref(a: Dictionary, b: Dictionary) -> bool:
	return not a.is_empty() and a.get("t") == b.get("t") and a.get("i", -1) == b.get("i", -1) and a.get("k", "") == b.get("k", "")

func _dict(ref: Dictionary, create: bool) -> Dictionary:
	match String(ref.get("t", "")):
		"door":
			if not doors.has(ref.k):
				if not create:
					return {"period": 8.0, "open": 5.0, "phase": 0.0}
				doors[ref.k] = {"period": 8.0, "open": 5.0, "phase": 0.0}
			return doors[ref.k]
		"mover":
			return movers[ref.i] if int(ref.i) < movers.size() else {}
		"zone":
			return zones[ref.i] if int(ref.i) < zones.size() else {}
	return {}

func valid_ref(ref: Dictionary) -> bool:
	return not ref.is_empty() and not _dict(ref, false).is_empty()

func obj_kind(ref: Dictionary) -> String:
	return "door" if ref.get("t") == "door" else String(_dict(ref, false).get("kind", ""))

func obj_params(ref: Dictionary) -> Array:
	var k := obj_kind(ref)
	if k == "vehicle":
		return PARAMS["vehicle"] if _dict(ref, false).has("path") else PARAMS["vehicle_lane"]
	return PARAMS.get(k, [])

func param_spec(ref: Dictionary, key: String) -> Array:
	for p in obj_params(ref):
		if p[0] == key:
			return p
	return []

func get_param(ref: Dictionary, key: String) -> float:
	var d := _dict(ref, false)
	match key:
		"shape":
			return 1.0 if String(d.get("shape", "line")) == "circle" else 0.0
		"pad":
			return float(int(String(d.get("pad", "1"))))
		"spikes", "cycle", "glass":
			return 1.0 if d.get(key, false) == true else 0.0
		"sweep":
			return float(d.get("sweep", 0.0))
		"gap":
			return float(d.get("gap", 3.0))
		"on":
			return float(d.get("on", 4.0 if d.has("period") else 0.0))
		"period":
			return float(d.get("period", 0.0 if ref.get("t") == "zone" else 8.0))
	return float(d.get(key, 0.0))

## Setzt einen Parameter (begrenzt auf den Bereich der Beschreibung); Schalter und Sonderfälle werden ins Dateiformat übersetzt.
func set_param(ref: Dictionary, key: String, value: float) -> void:
	var spec := param_spec(ref, key)
	if spec.is_empty() or not valid_ref(ref) and ref.get("t") != "door":
		return
	var step: float = spec[3]
	var v := clampf(value, spec[1], spec[2])
	v = snappedf(v, step) if step >= 1.0 else snappedf(v, 0.01)
	_edit(func():
		var d := _dict(ref, true)
		match key:
			"shape":
				d["shape"] = "circle" if v >= 0.5 else "line"
			"pad":
				d["pad"] = str(int(round(v)))
			"spikes", "cycle", "glass":
				if v >= 0.5:
					d[key] = true
				else:
					d.erase(key)
			"sweep":
				if v <= 0.0:
					d.erase("sweep")
					d.erase("gap")
				else:
					d["sweep"] = v
					d["gap"] = float(d.get("gap", 3.0))
			"period":
				if ref.get("t") == "zone" and v <= 0.0:
					d.erase("period")
					d.erase("on")
					d.erase("phase")
				else:
					d["period"] = v
					if ref.get("t") == "zone":
						d["on"] = float(d.get("on", 4.0))
						d["phase"] = float(d.get("phase", 0.0))
					if ref.get("t") == "door":
						d["open"] = minf(float(d.get("open", 5.0)), v)
			"open":
				d["open"] = minf(v, float(d.get("period", 8.0)))
			"tint", "paint":
				d[key] = int(round(v))
			_:
				d[key] = v
		_mark_changed())

func nudge_param(ref: Dictionary, key: String, direction: int) -> void:
	var spec := param_spec(ref, key)
	if spec.is_empty():
		return
	var cur := get_param(ref, key)
	if key == "period" and ref.get("t") == "zone" and cur <= 0.0 and direction > 0:
		set_param(ref, key, 8.0)                   # Zone pulsierend machen: sinnvoller Startwert statt 0,5
		return
	set_param(ref, key, cur + float(spec[3]) * float(direction))

## Neues Hindernis bzw. neue Zone mit sinnvollen Vorgaben an Feld (tx, ty). Gibt den Verweis zurück ({} wenn nicht möglich).
func add_object(kind: String, tx: int, ty: int) -> Dictionary:
	if not KINDS.has(kind):
		return {}
	var is_zone := kind in ["wind", "magnet", "gravity", "heat"]
	if (is_zone and zones.size() >= CL.MAX_ZONES) or (not is_zone and movers.size() >= CL.MAX_MOVERS):
		return {}
	var d: Dictionary = DEFAULTS[kind].duplicate(true)
	d["kind"] = kind
	if kind == "magnet":
		d["cx"] = float(tx)
		d["cy"] = float(ty)
	else:
		d["x"] = float(tx)
		d["y"] = float(ty)
	if kind == "pad":
		var free := next_free_pad()
		if free == "":
			return {}
		d["pad"] = free
	var out: Array = [{}]                    # Lambdas sehen äußere Variablen nur als Kopie: Ergebnis über ein Feld zurückgeben
	_edit(func():
		if is_zone:
			zones.append(d)
			out[0] = {"t": "zone", "i": zones.size() - 1}
		else:
			movers.append(d)
			out[0] = {"t": "mover", "i": movers.size() - 1}
		_mark_changed())
	return out[0]

func remove_object(ref: Dictionary) -> void:
	if not valid_ref(ref):
		return
	_edit(func():
		match String(ref.t):
			"mover":
				movers.remove_at(ref.i)
			"zone":
				zones.remove_at(ref.i)
			"door":
				for y in h:
					rows[y] = String(rows[y]).replace(String(ref.k), ".")
				doors.erase(ref.k)
		_mark_changed())

## Verschiebt ein Objekt um ganze Felder (Tore sind Kartenfelder und lassen sich nicht schieben).
func move_object(ref: Dictionary, dx: int, dy: int) -> bool:
	var d := _dict(ref, false)
	if d.is_empty() or ref.get("t") == "door" or (dx == 0 and dy == 0):
		return false
	_edit(func():
		for pair in [["x", dx], ["y", dy], ["cx", dx], ["cy", dy]]:
			if d.has(pair[0]):
				d[pair[0]] = clampf(float(d[pair[0]]) + float(pair[1]), -8.0, 64.0)
		if d.has("path"):
			for p in d.path:
				p[0] = clampf(float(p[0]) + dx, -8.0, 64.0)
				p[1] = clampf(float(p[1]) + dy, -8.0, 64.0)
		_mark_changed())
	return true

## Umfang des Objekts in Feldern (für Auswahl und Anzeige); Bewegungsbereich eingeschlossen.
func obj_bounds(ref: Dictionary) -> Rect2:
	var d := _dict(ref, false)
	if d.is_empty():
		return Rect2()
	if ref.get("t") == "door":
		var r := Rect2(-1, -1, 0, 0)
		var found := false
		for y in h:
			for x in w:
				if cell(x, y) == String(ref.k):
					r = Rect2(x, y, 1, 1) if not found else r.merge(Rect2(x, y, 1, 1))
					found = true
		return r
	var kind := String(d.get("kind", ""))
	var x := float(d.get("x", 0.0))
	var y := float(d.get("y", 0.0))
	var bw := float(d.get("w", 1.0))
	var bh := float(d.get("h", 1.0))
	var dx := float(d.get("dx", 0.0))
	var dy := float(d.get("dy", 0.0))
	match kind:
		"debris", "slider":
			return Rect2(x - absf(dx), y - absf(dy), bw + 2.0 * absf(dx), bh + 2.0 * absf(dy))
		"pad":
			return Rect2(x - absf(dx), y, bw + 2.0 * absf(dx), 2.0)
		"meteor":
			return Rect2(x, y, bw, bh).merge(Rect2(x + dx, y + dy, bw, bh))
		"vehicle":
			if d.has("path") and not d.path.is_empty():
				var r2 := Rect2(Vector2(d.path[0][0], d.path[0][1]), Vector2.ZERO)
				for p in d.path:
					r2 = r2.expand(Vector2(p[0], p[1]))
				return r2.grow(0.6)
			return Rect2(x - 0.5, y, absf(dx) + 1.0, 1.0)
		"magnet":
			var r := float(d.get("r", 4.0))
			return Rect2(float(d.get("cx", 0.0)) - r, float(d.get("cy", 0.0)) - r, 2.0 * r, 2.0 * r)
	return Rect2(x, y, bw, bh)

## Oberstes Objekt, dessen Umfang das Feld enthält (bei Überlappung das kleinste); {} wenn keins.
func pick_object(tx: int, ty: int) -> Dictionary:
	var best := {}
	var best_area := 1e18
	var pt := Vector2(tx + 0.5, ty + 0.5)
	for ref in objects():
		var b := obj_bounds(ref)
		if b.size == Vector2.ZERO and ref.t != "door":
			continue
		if ref.t == "door":
			if cell(tx, ty) != String(ref.k):
				continue
		elif not path_points(ref).is_empty():
			var pp := path_points(ref)                    # Fahrzeug mit Pfad: nur in der Nähe der Linie, nicht im ganzen Umfangsrechteck
			var near := false
			for k in range(pp.size() - 1):
				near = near or Geometry2D.get_closest_point_to_segment(pt, Vector2(pp[k][0], pp[k][1]), Vector2(pp[k + 1][0], pp[k + 1][1])).distance_to(pt) <= 0.9
			if not near:
				continue
		elif not b.has_point(pt):
			continue
		var area := maxf(b.get_area(), 0.01)
		if area <= best_area:
			best = ref
			best_area = area
	return best

# ---------------------------------------------------------------------------------------------------------------- Aufträge

func pad_digits() -> Array:
	var out: Array = []
	for r in pad_runs():
		if not out.has(r.ch):
			out.append(r.ch)
	for m in movers:
		if m.get("kind") == "pad" and not out.has(String(m.get("pad", ""))) and String(m.get("pad", "")) != "":
			out.append(String(m.pad))
	out.sort()
	return out

## Pad-Ziffer unter dem Start ("" wenn keine).
func start_pad() -> String:
	var sc := start_cell()
	for dy in range(1, 4):
		var c := cell(sc.x, sc.y + dy)
		if PAD_CHARS.contains(c):
			return c
	return ""

func jobs_make_explicit(from_jobs: Array) -> void:
	_edit(func():
		jobs = from_jobs.duplicate(true)
		_mark_changed())

func jobs_make_auto() -> void:
	_edit(func():
		jobs = []
		_mark_changed())

## Wahlmöglichkeiten für Start ("from") bzw. Ziel ("to") des Auftrags i.
func job_options(i: int, key: String) -> Array:
	var opts: Array = pad_digits()
	if key == "to":
		if i < jobs.size() and jobs[i].get("fragile", false) == true and pad_used_char("H"):
			opts.append("H")
		if i == jobs.size() - 1:
			opts.append("exit")
	return opts

func pad_used_char(ch: String) -> bool:
	for r in rows:
		if String(r).contains(ch):
			return true
	return false

func job_cycle(i: int, key: String, direction: int) -> void:
	if i < 0 or i >= jobs.size():
		return
	var opts := job_options(i, key)
	if opts.is_empty():
		return
	var cur: int = opts.find(String(jobs[i].get(key, "")))
	_edit(func():
		jobs[i][key] = opts[wrapi(cur + direction, 0, opts.size())]
		_mark_changed())

func job_toggle_fragile(i: int) -> void:
	if i < 0 or i >= jobs.size():
		return
	_edit(func():
		if jobs[i].get("fragile", false) == true:
			jobs[i].erase("fragile")
			if String(jobs[i].to) == "H":
				for dgt in pad_digits():
					if dgt != String(jobs[i].from):
						jobs[i]["to"] = dgt
						break
		else:
			jobs[i]["fragile"] = true
		_mark_changed())

## Fügt hinter Auftrag `after_i` einen Auftrag ein (nie hinter dem letzten, dem Ausgangs-Auftrag); Start und Ziel so gewählt, dass die Regeln gelten.
func job_insert(after_i: int) -> bool:
	if jobs.size() >= CL.MAX_JOBS or pad_digits().size() < 2:
		return false
	var pos := clampi(after_i + 1, 0, maxi(jobs.size() - 1, 0))
	var prev_to := start_pad() if pos == 0 else String(jobs[pos - 1].get("to", ""))
	var next_from := String(jobs[pos].get("from", "")) if pos < jobs.size() else ""
	var digits := pad_digits()
	var from_c := ""
	for dgt in digits:
		if dgt != prev_to:
			from_c = dgt
			break
	var to_c := ""
	for dgt in digits:
		if dgt != from_c and dgt != next_from:
			to_c = dgt
			break
	if to_c == "":
		for dgt in digits:
			if dgt != from_c:
				to_c = dgt
				break
	if from_c == "" or to_c == "":
		return false
	_edit(func():
		jobs.insert(pos, {"from": from_c, "to": to_c, "fare": 60.0, "par": 30.0, "passenger": "?", "gender": "m" if pos % 2 == 0 else "f"})
		_mark_changed())
	return true

func job_remove(i: int) -> void:
	if i < 0 or i >= jobs.size():
		return
	_edit(func():
		var was_last := i == jobs.size() - 1
		jobs.remove_at(i)
		if was_last and not jobs.is_empty():
			jobs[jobs.size() - 1]["to"] = "exit"
		_mark_changed())

# ---------------------------------------------------------------------------------------------------------------- Fahrzeugpfade und Größe beim Setzen

## Neues Fremdfahrzeug auf einem Pfad aus Feldmittelpunkten (Eingang, Zwischenpunkte, Ausgang; Koordinaten in Feldern). Gibt den Verweis zurück ({} bei zu wenigen Punkten oder zu vielen Hindernissen).
func add_vehicle_path(points: Array) -> Dictionary:
	if points.size() < 2 or movers.size() >= CL.MAX_MOVERS:
		return {}
	var pts: Array = []
	for p in points:
		if pts.size() < CL.MAX_PATH_POINTS:
			pts.append([snappedf(clampf(float(p.x), -8.0, 64.0), 0.01), snappedf(clampf(float(p.y), -8.0, 64.0), 0.01)])
	var out: Array = [{}]
	_edit(func():
		movers.append({"kind": "vehicle", "path": pts, "speed": 50.0, "paint": 0, "phase": 0.0, "w": 1.0, "h": 1.0, "x": 0.0, "y": 0.0, "dx": 0.0, "dy": 0.0, "period": 8.0})
		out[0] = {"t": "mover", "i": movers.size() - 1}
		_mark_changed())
	return out[0]

func path_points(ref: Dictionary) -> Array:
	var d := _dict(ref, false)
	return d.get("path", []) if d.get("kind") == "vehicle" else []

## Index des Pfadpunkts, der dem Punkt `p` (Felder) am nächsten liegt und höchstens `radius` entfernt ist; -1 wenn keiner.
func path_point_near(ref: Dictionary, p: Vector2, radius: float) -> int:
	var best := -1
	var best_d := radius
	var pts := path_points(ref)
	for i in pts.size():
		var d := Vector2(pts[i][0], pts[i][1]).distance_to(p)
		if d <= best_d:
			best = i
			best_d = d
	return best

func set_path_point(ref: Dictionary, idx: int, p: Vector2) -> void:
	var pts := path_points(ref)
	if idx < 0 or idx >= pts.size():
		return
	_edit(func():
		pts[idx][0] = snappedf(clampf(p.x, -8.0, 64.0), 0.01)
		pts[idx][1] = snappedf(clampf(p.y, -8.0, 64.0), 0.01)
		_mark_changed())

func remove_path_point(ref: Dictionary, idx: int) -> void:
	var pts := path_points(ref)
	if pts.size() <= 2 or idx < 0 or idx >= pts.size():
		return
	_edit(func():
		pts.remove_at(idx)
		_mark_changed())

## Legt Größe bzw. Richtung eines gerade gesetzten Objekts aus den beiden Feldern der Ziehbewegung (a = Druckpunkt, b = aktueller Punkt) fest:
## Flächen (Strömung, Schwerkraft, Hitze, Strahl, Schieber) werden zum Rechteck, Magnete bekommen den Radius, Meteoriten den Fallweg, Plattformen die Breite,
## Trümmer den Bewegungsweg.
func size_object(ref: Dictionary, a: Vector2i, b: Vector2i) -> void:
	var d := _dict(ref, false)
	if d.is_empty() or ref.get("t") == "door":
		return
	_edit(func():
		var lo := Vector2i(mini(a.x, b.x), mini(a.y, b.y))
		var hi := Vector2i(maxi(a.x, b.x), maxi(a.y, b.y))
		match String(d.get("kind", "")):
			"wind", "gravity", "heat", "beam", "slider":
				d["x"] = float(lo.x)
				d["y"] = float(lo.y)
				d["w"] = float(hi.x - lo.x + 1)
				d["h"] = float(hi.y - lo.y + 1)
			"magnet":
				d["r"] = clampf(snappedf(Vector2(a).distance_to(Vector2(b)), 0.5), 1.0, 20.0)
			"meteor":
				d["dx"] = float(b.x - a.x)
				d["dy"] = float(maxi(b.y - a.y, 1))
			"pad":
				d["x"] = float(lo.x)
				d["w"] = float(maxi(hi.x - lo.x + 1, 4))
			"debris":
				d["dx"] = float(b.x - a.x)
				d["dy"] = float(b.y - a.y)
		_mark_changed())

