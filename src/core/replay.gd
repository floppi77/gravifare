class_name Replay
extends RefCounted
## Replay-Fundament: Ein Lauf ist durch Start-Parameter (Level, Seed, Sprit, Credits, mitfahrender Fahrgast) und die
## Eingaben je Tick vollständig bestimmt, weil Run/TaxiSim deterministisch sind. Gespeichert wird lauflängenkodiert
## (RLE) als JSON; `play()` rechnet einen Lauf headless nach und liefert das Ergebnis (Verifikation, später Geist).

const VERSION := 2            # 2: mit Geist-Spur und Werkstatt-Werten (Regelstand des Laufs im Feld „rules“, siehe Run.RULES)
const LEGACY_RULES := 2       # Läufe ohne „rules“ stammen aus Version ≤ 1.0.1 und werden mit den damaligen Regeln nachgerechnet
const TRACE_HZ := 10.0        # Positionen je Sekunde für die Geisterfahrt
const TRACE_FIELDS := 3       # x, y, Neigung
const DIR := "user://replays/"

var level_id := ""
var seed := -1
var fuel := -1.0
var credits := 0.0
var carry: Dictionary = {}
var extras := true
var runs: Array = []          # [Anzahl Ticks, qx, qy, gear(0/1)]
var events: Array = []        # [Tick, "respawn"]
var ticks := 0
var result: Dictionary = {}
var trace: Array = []         # flach: x, y, Neigung je Abtastung
var mods: Dictionary = {}     # Werkstatt-Einbauten des Laufs
var rules := Run.RULES       # Regelstand, mit dem der Lauf geflogen wurde
var sig := ""                 # Kennung des Leveldateiinhalts: Wurde das Level danach geändert, wird der Geist nicht mehr gezeigt (er flöge durch die alte Karte)

## Kennung des Levelinhalts (für `sig`).
## Der Fahrgasttyp eines Auftrags („kind“, VIP/Notfall seit Runde 61) zählt nicht: Karte und Wege bleiben gleich, der Geist bleibt gültig.
static func sig_of(lvl: LevelData) -> String:
	var raw: Dictionary = lvl.raw
	if raw.get("jobs") is Array and (raw.jobs as Array).any(func(j): return j is Dictionary and j.has("kind")):
		raw = raw.duplicate(true)
		for j in raw.jobs:
			if j is Dictionary:
				j.erase("kind")
	return JSON.stringify(raw, "", true).sha256_text().substr(0, 12)

## Eingaben werden auf 1/127 gerundet, damit Aufzeichnung und Wiedergabe exakt dieselben Werte rechnen.
static func quantize(v: Vector2) -> Vector2:
	return Vector2(roundi(clampf(v.x, -1.0, 1.0) * 127.0) / 127.0, roundi(clampf(v.y, -1.0, 1.0) * 127.0) / 127.0)

func begin(id: String, run_seed: int, fuel_in: float, credits_in: float, carry_in: Dictionary, extras_on: bool) -> void:
	level_id = id
	seed = run_seed
	fuel = fuel_in
	credits = credits_in
	carry = carry_in.duplicate(true)
	extras = extras_on
	runs.clear()
	events.clear()
	ticks = 0
	result = {}
	trace = []
	mods = {}
	rules = Run.RULES

## Position für den Geist merken; das Spiel ruft es je Tick.
func sample(p: Vector2, tilt: float) -> void:
	if ticks % int(120.0 / TRACE_HZ) == 1:
		trace.append_array([snappedf(p.x, 0.1), snappedf(p.y, 0.1), snappedf(tilt, 0.01)])

func add(v: Vector2, gear: bool) -> void:
	var qx := roundi(clampf(v.x, -1.0, 1.0) * 127.0)
	var qy := roundi(clampf(v.y, -1.0, 1.0) * 127.0)
	var g := 1 if gear else 0
	if not runs.is_empty() and runs[-1][1] == qx and runs[-1][2] == qy and runs[-1][3] == g:
		runs[-1][0] += 1
	else:
		runs.append([1, qx, qy, g])
	ticks += 1

func mark_respawn() -> void:
	events.append([ticks, "respawn"])

func mark_eject() -> void:
	events.append([ticks, "eject"])

func finish(res: Dictionary) -> void:
	result = res

func to_dict() -> Dictionary:
	return {"v": VERSION, "level": level_id, "seed": seed, "fuel": fuel, "credits": credits, "carry": carry, "extras": extras,
		"ticks": ticks, "runs": runs, "events": events, "result": result, "trace": trace, "mods": mods, "sig": sig, "rules": rules}

## Rechnet einen Lauf nach. Rückgabe: {complete, time, money, earned, delivered, ticks}.
static func play(lvl: LevelData, d: Dictionary) -> Dictionary:
	var r := Run.new()
	r.rules = int(d.get("rules", LEGACY_RULES))
	r.extras_enabled = bool(d.get("extras", true))
	r.start(lvl, float(d.get("fuel", -1.0)), float(d.get("credits", 0.0)), int(d.get("seed", -1)))
	r.sim.apply_mods(d.get("mods", {}))
	var carry_d: Dictionary = d.get("carry", {})
	if not carry_d.is_empty():
		r.release_carried(carry_d)
	var evs: Array = d.get("events", [])
	var ei := 0
	var tick := 0
	for run_entry in d.get("runs", []):
		var v := Vector2(float(run_entry[1]) / 127.0, float(run_entry[2]) / 127.0)
		for k in int(run_entry[0]):
			while ei < evs.size() and int(evs[ei][0]) == tick:
				if String(evs[ei][1]) == "eject":
					r.eject()
				else:
					r.respawn_after_crash()
				ei += 1
			r.step(v, int(run_entry[3]) == 1)
			tick += 1
			if r.result == Run.Result.COMPLETE:
				break
		if r.result == Run.Result.COMPLETE:
			break
	return {"complete": r.result == Run.Result.COMPLETE, "time": r.level_time, "money": r.money, "earned": r.earned,
		"delivered": r.delivered, "ticks": tick}

## Bestzeit-Läufe liegen je Speicherplatz (user://replays/s<Platz>/); ohne Platz (Tests, Altbestand) direkt in user://replays/.
static func dir_for(slot := 0) -> String:
	return DIR if slot <= 0 else DIR + "s%d/" % slot

static func path_for(id: String, slot := 0) -> String:
	return dir_for(slot) + id + ".json"

## Speichert den Lauf, wenn er schneller ist als der bisher gespeicherte (nur abgeschlossene Läufe).
static func save_if_best(d: Dictionary, slot := 0) -> bool:
	if not bool(d.get("result", {}).get("complete", false)):
		return false
	DirAccess.make_dir_recursive_absolute(dir_for(slot))
	var p := path_for(String(d.level), slot)
	if FileAccess.file_exists(p):
		var old = JSON.parse_string(FileAccess.get_file_as_string(p))
		if typeof(old) == TYPE_DICTIONARY and int(old.get("v", 0)) == VERSION and float(old.get("result", {}).get("time", 1e9)) <= float(d.result.time):
			return false
	var f := FileAccess.open(p + ".tmp", FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(d))
	f.close()
	DirAccess.rename_absolute(p + ".tmp", p)
	return true

static func load_best(id: String, slot := 0) -> Dictionary:
	var p := path_for(id, slot)
	if not FileAccess.file_exists(p) and slot == 1:
		p = path_for(id)                 # Läufe von vor den Speicherplätzen gehören zu Platz 1
	if not FileAccess.file_exists(p):
		return {}
	var d = JSON.parse_string(FileAccess.get_file_as_string(p))
	return d if typeof(d) == TYPE_DICTIONARY and int(d.get("v", 0)) == VERSION else {}

## Geist der Tagschicht: der beste Flug des heutigen Tages (eine Datei je Speicherplatz, am nächsten Tag ungültig). `score` = Wertung des Tagesziels.
static func day_path(slot := 0) -> String:
	return dir_for(slot) + "_day.json"

static func save_day(d: Dictionary, slot: int, date: String, score: int) -> bool:
	if not bool(d.get("result", {}).get("complete", false)):
		return false
	var old := load_day_file(slot)
	if String(old.get("date", "")) == date and int(old.get("score", -1)) >= score:
		return false
	DirAccess.make_dir_recursive_absolute(dir_for(slot))
	var f := FileAccess.open(day_path(slot) + ".tmp", FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify({"date": date, "score": score, "replay": {"v": VERSION, "trace": d.get("trace", []), "level": d.get("level", "")}}))
	f.close()
	DirAccess.rename_absolute(day_path(slot) + ".tmp", day_path(slot))
	return true

static func load_day_file(slot := 0) -> Dictionary:
	var p := day_path(slot)
	if not FileAccess.file_exists(p):
		return {}
	var d = JSON.parse_string(FileAccess.get_file_as_string(p))
	return d if typeof(d) == TYPE_DICTIONARY else {}

## Flugspur des besten Flugs von `date` ([] wenn es keinen gibt).
static func load_day(slot: int, date: String) -> Array:
	var d := load_day_file(slot)
	if String(d.get("date", "")) != date or typeof(d.get("replay")) != TYPE_DICTIONARY:
		return []
	return d.replay.get("trace", [])
