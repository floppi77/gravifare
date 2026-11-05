extends RefCounted
## Bearbeitungsmodell des Level-Editors (ohne Oberfläche, testbar): Karte als Textzeilen, Zeichenwerkzeuge, Rückgängig/Wiederholen, Pad-Nummern
## und Prüfung über community_level.gd. Türen, bewegliche Hindernisse, Zonen und Dunkelheit eines geladenen Levels bleiben unverändert erhalten
## (der Editor zeigt sie, bearbeitet sie aber noch nicht). Verwendung (ohne class_name): const LevelEdit := preload("res://src/core/level_edit.gd")

const CL := preload("res://src/core/community_level.gd")
const MAX_UNDO := 100
const PAD_CHARS := "123456789"
## Paletteneinträge: Zeichen, Textschlüssel. Pads 1–9 stehen einzeln (jede Nummer nur einmal pro Level).
const PALETTE := [["#", "ED_T_ROCK"], [".", "ED_T_AIR"], ["1", "ED_T_PAD"], ["2", "ED_T_PAD"], ["3", "ED_T_PAD"], ["4", "ED_T_PAD"], ["5", "ED_T_PAD"], ["6", "ED_T_PAD"],
	["7", "ED_T_PAD"], ["8", "ED_T_PAD"], ["9", "ED_T_PAD"], ["F", "ED_T_FUEL"], ["L", "ED_T_LIFE"], ["H", "ED_T_HOSPITAL"], ["^", "ED_T_SPIKES"], ["P", "ED_T_PUMP"], ["S", "ED_T_START"]]

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
	if jobs.is_empty() and job_seed > 0:
		d["job_seed"] = job_seed
	return d

func to_wrapper() -> Dictionary:
	var doc := {"format": CL.FORMAT, "version": CL.VERSION, "author": author, "license": license, "level": to_level_dict()}
	if derived_from != "":
		doc["derived_from"] = derived_from
	return doc

## Prüfung wie beim Einlesen. Passen die Aufträge nicht mehr zur Karte, werden sie verworfen und neu erzeugt (`jobs_reset`).
func validate() -> Dictionary:
	var res := CL.clean(to_wrapper())
	jobs_reset = false
	if not res.ok and not jobs.is_empty():
		var only_jobs: bool = not res.errors.is_empty()
		for e in res.errors:
			only_jobs = only_jobs and String(e.code).begins_with("JOB_")
		if only_jobs:
			jobs = []
			jobs_reset = true
			res = CL.clean(to_wrapper())
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
	_undo.append({"rows": rows.duplicate(), "jobs": jobs.duplicate(true), "seed": job_seed})
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

func can_undo() -> bool:
	return not _undo.is_empty()

func can_redo() -> bool:
	return not _redo.is_empty()

func undo() -> bool:
	if _undo.is_empty():
		return false
	_redo.append({"rows": rows.duplicate(), "jobs": jobs.duplicate(true), "seed": job_seed})
	var s: Dictionary = _undo.pop_back()
	rows = s.rows
	jobs = s.jobs
	job_seed = int(s.seed)
	dirty = true
	return true

func redo() -> bool:
	if _redo.is_empty():
		return false
	_undo.append({"rows": rows.duplicate(), "jobs": jobs.duplicate(true), "seed": job_seed})
	var s: Dictionary = _redo.pop_back()
	rows = s.rows
	jobs = s.jobs
	job_seed = int(s.seed)
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
