extends RefCounted
## Die 99 mitgelieferten Level (data/levels/<id>.json) bearbeiten und zurückschreiben (Debug-Modus, nur beim Start aus dem Projektordner; ein exportiertes
## Spiel kann seine eigenen Dateien nicht ändern). Der Editor arbeitet mit der bereinigten Community-Fassung (community_level.gd); beim Speichern wird sie in die
## ursprüngliche Datei eingearbeitet: Alles, was unverändert blieb, bleibt Zeichen für Zeichen erhalten (Richtzeiten, Mechanik-Liste, Zahlenformate), nur Geändertes
## wird neu geschrieben. Das Dateiformat entspricht dem der Python-Erzeuger (`json.dump(indent=1, ensure_ascii=False)`, ohne Zeilenende am Schluss).
## Verwendung (ohne class_name): const LevelFiles := preload("res://src/core/level_files.gd")

const CL := preload("res://src/core/community_level.gd")
const DIR := "res://data/levels/"
const HASH_FILE := "res://data/levels.sha256"
static var dir := DIR                     # Tests weichen auf einen eigenen Ordner aus
static var hash_file := HASH_FILE
static var replay_dir := "user://replays/"

## Zahlen mit diesen Schlüsseln stehen in den Originalen als Kommazahl (6.0), alle anderen als ganze Zahl (6), solange sie ganz sind.
const FLOAT_KEYS := ["cx", "cy", "dark", "fall", "g", "on", "open", "path", "period", "phase", "r", "speed", "sweep", "warn"]
## Schlüsselfolge neu geschriebener Einträge (wie in den Originalen); unbekannte Schlüssel folgen hinten.
const ORDER := {
	"beam": ["kind", "x", "y", "w", "h", "period", "on", "phase", "warn", "tint"],
	"debris": ["kind", "x", "y", "w", "h", "dx", "dy", "period", "phase", "shape"],
	"slider": ["kind", "x", "y", "w", "h", "dx", "dy", "period", "phase", "shape"],
	"meteor": ["kind", "x", "y", "w", "h", "dx", "dy", "fall", "warn", "period", "phase"],
	"pad": ["kind", "pad", "x", "y", "w", "dx", "period", "phase", "spikes"],
	"vehicle": ["kind", "path", "w", "h", "speed", "phase", "paint"],
	"wind": ["kind", "x", "y", "w", "h", "ax", "ay", "period", "on", "phase"],
	"heat": ["kind", "x", "y", "w", "h", "period", "on", "phase"],
	"gravity": ["kind", "x", "y", "w", "h", "g", "period", "on", "phase"],
	"magnet": ["kind", "cx", "cy", "r", "k", "period", "on", "phase", "cycle"],
	"door": ["period", "open", "sweep", "gap", "phase", "glass"],
	"job": ["from", "to", "fare", "par", "passenger", "gender", "fragile"]}

# ---------------------------------------------------------------------------------------------------------------- Zugriff

## Darf das Spiel seine mitgelieferten Level überschreiben? Nur ohne Exportvorlage (Start aus dem Projektordner) und wenn der Ordner beschreibbar ist.
static func can_write() -> bool:
	if OS.has_feature("template") and dir == DIR:
		return false
	var probe := dir + ".schreibprobe"
	var f := FileAccess.open(probe, FileAccess.WRITE)
	if f == null:
		return false
	f.close()
	DirAccess.remove_absolute(probe)
	return true

static func path_for(id: String) -> String:
	return dir + id + ".json" if id.is_valid_filename() and not id.contains(".") else ""

static func exists(id: String) -> bool:
	var p := path_for(id)
	return p != "" and FileAccess.file_exists(p)

## Inhalt der Datei (leer, wenn sie fehlt oder kein Level ist).
static func read(id: String) -> Dictionary:
	var p := path_for(id)
	if p == "" or not FileAccess.file_exists(p):
		return {}
	var d = JSON.parse_string(FileAccess.get_file_as_string(p))
	return d if d is Dictionary else {}

## Bereinigte Fassung eines Originals (so sieht der Editor es); `ok` ist bei allen mitgelieferten Leveln wahr.
static func clean_of(raw: Dictionary) -> Dictionary:
	return CL.clean({"format": CL.FORMAT, "version": CL.VERSION, "level": raw})

# ---------------------------------------------------------------------------------------------------------------- Einarbeiten

static func _same(a: Variant, b: Variant) -> bool:
	return JSON.stringify(a, "", true) == JSON.stringify(b, "", true)

## Einträge einer Liste (Hindernisse, Zonen): Ein Eintrag, der einem bereinigten Eintrag der alten Datei entspricht, bleibt in seiner alten Schreibweise;
## alles andere kommt aus dem Editor. `old_clean[i]` gehört zu `old_raw[i]`.
static func _keep_list(old_raw: Array, old_clean: Array, now: Array, key_of: Callable = Callable()) -> Array:
	var used := {}
	var out: Array = []
	for item in now:
		var hit := -1
		for i in old_clean.size():
			if not used.has(i) and i < old_raw.size() and _same(_cmp(old_clean[i], key_of), _cmp(item, key_of)):
				hit = i
				break
		if hit >= 0:
			used[hit] = true
			out.append(old_raw[hit])
		else:
			out.append(item)
	return out

static func _cmp(item: Variant, key_of: Callable) -> Variant:
	return key_of.call(item) if key_of.is_valid() else item

static func _job_key(j: Dictionary) -> Dictionary:
	return {"from": j.get("from"), "to": j.get("to"), "fare": j.get("fare"), "passenger": j.get("passenger"), "gender": j.get("gender"), "fragile": bool(j.get("fragile", false))}

## Neue Fassung der Datei: `raw` = bisheriger Inhalt, `base` = bereinigte Fassung davon (clean_of), `res` = geprüftes Ergebnis des Editors.
## Sektor und Index bleiben, wie sie sind (sie bestimmen die Levelnummer); die Mechanik-Liste bleibt unverändert.
static func merged(raw: Dictionary, base: Dictionary, res: Dictionary) -> Dictionary:
	var out: Dictionary = raw.duplicate(true)
	var bl: Dictionary = base.level
	var nl: Dictionary = res.level
	if not _same(bl.name, nl.name):
		out["name"] = nl.name.duplicate()
	if not _same(bl.map, nl.map):
		out["map"] = nl.map.duplicate()
	if not is_equal_approx(float(bl.dark), float(nl.dark)):
		if float(nl.dark) > 0.0:
			out["dark"] = float(nl.dark)
		else:
			out.erase("dark")
	var doors_raw: Dictionary = raw.get("doors", {})
	var doors: Dictionary = {}
	for ch in nl.doors:
		doors[ch] = doors_raw[ch] if doors_raw.has(ch) and bl.doors.has(ch) and _same(bl.doors[ch], nl.doors[ch]) else nl.doors[ch]
	if doors.is_empty():
		out.erase("doors")
	elif not _same(doors, doors_raw):
		out["doors"] = doors
	for key in ["movers", "zones"]:
		var list := _keep_list(raw.get(key, []), bl[key], nl[key])
		if list.is_empty():
			out.erase(key)
		elif not _same(list, raw.get(key, [])):
			out[key] = list
	# Aufträge: Ein unveränderter Auftrag behält seine von Hand abgestimmte Richtzeit; neue und geänderte bekommen die berechnete.
	var jobs := _keep_list(raw.get("jobs", []), bl.jobs, nl.jobs, _job_key)
	if not _same(jobs, raw.get("jobs", [])):
		out["jobs"] = jobs
	return out

# ---------------------------------------------------------------------------------------------------------------- Dateitext

## Text im Format der Python-Erzeuger.
static func to_text(d: Dictionary) -> String:
	return _fmt(d, 0, "", "")

static func _fmt(v: Variant, depth: int, key: String, tag: String) -> String:
	var pad := " ".repeat(depth + 1)
	match typeof(v):
		TYPE_DICTIONARY:
			if v.is_empty():
				return "{}"
			var d: Dictionary = v
			var parts: Array = []
			for k in _order_of(d, tag):
				var child := "door" if tag == "doors" else ("doors" if (tag == "" and k == "doors") else ("job" if (tag == "" and k == "jobs") else ""))
				parts.append("%s%s: %s" % [pad, JSON.stringify(String(k)), _fmt(d[k], depth + 1, String(k) if tag != "doors" else "", child)])
			return "{\n" + ",\n".join(parts) + "\n" + " ".repeat(depth) + "}"
		TYPE_ARRAY:
			if v.is_empty():
				return "[]"
			var parts2: Array = []
			for item in v:
				parts2.append(pad + _fmt(item, depth + 1, key, tag))
			return "[\n" + ",\n".join(parts2) + "\n" + " ".repeat(depth) + "]"
		TYPE_STRING:
			return JSON.stringify(v)
		TYPE_BOOL:
			return "true" if v else "false"
		TYPE_NIL:
			return "null"
		TYPE_INT:
			return str(v)
		TYPE_FLOAT:
			return _num(float(v), FLOAT_KEYS.has(key))
	return JSON.stringify(v)

static func _order_of(d: Dictionary, tag: String) -> Array:
	var keys: Array = d.keys()
	var pref: Array = []
	if tag == "door" or tag == "job":
		pref = ORDER[tag]
	elif d.has("kind") and ORDER.has(String(d.kind)):
		pref = ORDER[String(d.kind)]
	if pref.is_empty():
		return keys                       # oberste Ebene, Namen, Türensammlung: Reihenfolge des Wörterbuchs
	var out: Array = []
	for k in pref:
		if d.has(k):
			out.append(k)
	for k in keys:
		if not out.has(k):
			out.append(k)
	return out

## Kürzeste Schreibweise, die wieder dieselbe Zahl ergibt (wie Pythons repr); ganze Zahlen als „6.0“ (Kommazahl-Schlüssel) oder „6“.
static func _num(f: float, as_float: bool) -> String:
	if f == roundf(f) and absf(f) < 1.0e15:
		return "%d.0" % int(f) if as_float else str(int(f))
	for digits in range(1, 18):
		var s := String.num(f, digits)
		if s.to_float() == f:
			return s
	return str(f)

# ---------------------------------------------------------------------------------------------------------------- Schreiben

## Neue Fassung in die Datei schreiben (atomar), Prüfsumme in data/levels.sha256 nachführen und gespeicherte Geisterläufe dieses Levels verwerfen
## (sie zeigen sonst einen Flug durch die alte Karte). Ergebnis {error: "" oder Code, raw: neuer Inhalt, changed: wurde etwas geschrieben}.
static func save(id: String, raw: Dictionary, base: Dictionary, res: Dictionary) -> Dictionary:
	var p := path_for(id)
	if p == "" or not FileAccess.file_exists(p):
		return {"error": "NOT_FOUND", "raw": raw, "changed": false}
	var now := merged(raw, base, res)
	var text := to_text(now)
	if text == FileAccess.get_file_as_string(p):
		return {"error": "", "raw": now, "changed": false}
	var tmp := p + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		return {"error": "WRITE", "raw": raw, "changed": false}
	f.store_string(text)
	f.close()
	if DirAccess.rename_absolute(tmp, p) != OK:
		DirAccess.remove_absolute(tmp)
		return {"error": "WRITE", "raw": raw, "changed": false}
	_update_hash(id, text)
	drop_replays(id)
	return {"error": "", "raw": JSON.parse_string(text), "changed": true}

## Zeile des Levels in levels.sha256 ersetzen (Zeilenenden vereinheitlicht, wie tools/level_hashes.py); ohne Zeile nichts tun.
static func _update_hash(id: String, text: String) -> void:
	if not FileAccess.file_exists(hash_file):
		return
	var lines := FileAccess.get_file_as_string(hash_file).split("\n")
	var tail := "  levels/%s.json" % id
	var digest := text.replace("\r\n", "\n").sha256_text()
	var changed := false
	for i in lines.size():
		if lines[i].ends_with(tail):
			lines[i] = digest + tail
			changed = true
	if not changed:
		return
	var f := FileAccess.open(hash_file, FileAccess.WRITE)
	if f != null:
		f.store_string("\n".join(lines))
		f.close()

## Gespeicherte Bestzeit-Läufe (Geister) dieses Levels in allen Speicherplätzen löschen.
static func drop_replays(id: String) -> void:
	var d := DirAccess.open(replay_dir)
	if d == null:
		return
	var folders: Array = [replay_dir]
	for sub in d.get_directories():
		folders.append(replay_dir.path_join(sub) + "/")
	for fo in folders:
		var p: String = String(fo).path_join(id + ".json")
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(p)
