extends RefCounted
## Ablage der Community-Level: user://community/<id>.gflevel (ID = Hash des Inhalts, siehe community_level.gd). Geschrieben wird ausschließlich
## in diesen Ordner, und nur unter gültigen IDs; die mitgelieferten Level unter res://data/levels werden nie verändert (nur gelesen).
## Verwendung (ohne class_name): const CommunityStore := preload("res://src/core/community_store.gd")

const CommunityLevel := preload("res://src/core/community_level.gd")
const DIR := "user://community/"
const MAX_LEVELS := 200
static var dir := DIR                 # Tests weichen auf einen eigenen Ordner aus

## Ordner der Level. Nach dem Neuladen von Skripten im laufenden Editor-Spiel werden statische Variablen auf ihren Typ-Standard ("") zurückgesetzt;
## dann landeten Level ohne diese Absicherung relativ im Projektordner und die Liste zeigte nur sie (die gespeicherten Level kamen erst nach einem Neustart zurück).
static func _d() -> String:
	return dir if dir != "" else DIR
static var game_version := ""         # setzt Flow beim Start; steht in den gespeicherten Dateien

static func path_for(id: String) -> String:
	return _d() + id + ".gflevel" if CommunityLevel.is_valid_id(id) else ""

static func exists(id: String) -> bool:
	var p := path_for(id)
	return p != "" and FileAccess.file_exists(p)

## Entwürfe: Fassungen, die für einen Testflug bereitliegen, aber noch nicht gespeichert sind (Speichern setzt eine Handlösung voraus). Sie erscheinen weder in der
## Liste noch zählen sie zum Limit; es bleiben nur die neuesten.
const MAX_DRAFTS := 8

static func draft_dir() -> String:
	return _d() + "drafts/"

static func draft_path(id: String) -> String:
	return draft_dir() + id + ".gflevel" if CommunityLevel.is_valid_id(id) else ""

static func draft_exists(id: String) -> bool:
	var p := draft_path(id)
	return p != "" and FileAccess.file_exists(p)

## Spielbar (gespeichert oder als Entwurf)?
static func playable(id: String) -> bool:
	return exists(id) or draft_exists(id)

## Entwurf ablegen (nur gültige Ergebnisse). Gibt "" oder einen Fehlercode zurück.
static func save_draft(res: Dictionary, author := "") -> String:
	if not res.get("ok", false) or not CommunityLevel.is_valid_id(res.get("id", "")):
		return "INVALID"
	DirAccess.make_dir_recursive_absolute(draft_dir())
	var p := draft_path(res.id)
	var f := FileAccess.open(p, FileAccess.WRITE)
	if f == null:
		return "WRITE"
	f.store_string(CommunityLevel.to_file_text(res, author, game_version))
	f.close()
	_cache[res.id] = {"sha": FileAccess.get_sha256(p), "res": res}
	_prune_drafts()
	return ""

static func _prune_drafts() -> void:
	var d := DirAccess.open(draft_dir())
	if d == null:
		return
	var files: Array = []
	for f in d.get_files():
		if f.ends_with(".gflevel"):
			files.append([FileAccess.get_modified_time(draft_dir() + f), f])
	files.sort_custom(func(a, b): return a[0] > b[0])
	for i in range(MAX_DRAFTS, files.size()):
		DirAccess.remove_absolute(draft_dir() + String(files[i][1]))

static func drop_draft(id: String) -> void:
	var p := draft_path(id)
	if p != "" and FileAccess.file_exists(p):
		DirAccess.remove_absolute(p)

## Handlösung: Nur wer sein Level (genau diesen Inhalt, die ID ist der Hash) einmal selbst bis zum Ende geflogen ist, darf es speichern. Der Nachweis liegt in
## solved.json neben den Leveln und gilt nur für unveränderten Inhalt; jede Änderung ergibt eine neue ID und verlangt einen neuen Flug.
const MAX_SOLVED := 400
static var _solved := {}              # id -> Unix-Zeit
static var _solved_dir := "?"

static func _load_solved() -> void:
	if _solved_dir == _d():
		return
	_solved_dir = _d()
	_solved = {}
	var f := FileAccess.open(_d() + "solved.json", FileAccess.READ)
	var d = JSON.parse_string(f.get_as_text()) if f != null else null
	if d is Dictionary:
		for id in d:
			if CommunityLevel.is_valid_id(id) and (d[id] is float or d[id] is int):
				_solved[id] = d[id]

static func is_solved(id: String) -> bool:
	_load_solved()
	return _solved.has(id)

static func mark_solved(id: String) -> void:
	if not CommunityLevel.is_valid_id(id):
		return
	_load_solved()
	_solved[id] = Time.get_unix_time_from_system()
	if _solved.size() > MAX_SOLVED:
		var ids: Array = _solved.keys()
		ids.sort_custom(func(a, b): return _solved[a] < _solved[b])
		for i in _solved.size() - MAX_SOLVED:
			_solved.erase(ids[i])
	DirAccess.make_dir_recursive_absolute(_d())
	var f := FileAccess.open(_d() + "solved.json", FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(_solved))
		f.close()

## Darf diese Fassung aus dem Editor gespeichert werden? Schon gespeicherte Level ja, sonst nur nach einer Handlösung.
static func may_save(id: String) -> bool:
	return exists(id) or is_solved(id)

static func _ids() -> Array:
	var out: Array = []
	var d := DirAccess.open(_d())
	if d == null:
		return out
	for f in d.get_files():
		if f.ends_with(".gflevel") and CommunityLevel.is_valid_id(f.get_basename()):
			out.append(f.get_basename())
	out.sort()
	return out

static var _cache := {}               # id -> {sha: Prüfsumme der Datei, res}; die Prüfung (Planung) dauert einen Moment, ein Neustart nach Absturz soll nicht warten
static var _index := {}               # id -> {sha, ok, Kurzangaben, map}: Auszug für die Liste, damit sie nicht jedes Level neu prüfen muss
static var _index_dir := ""

## Gespeichertes Level lesen und neu prüfen (die Datei kann von Hand verändert worden sein). Ergebnis mit ok = false bei Fehlern.
static func load_level(id: String) -> Dictionary:
	var p := path_for(id)
	var f := FileAccess.open(p, FileAccess.READ) if p != "" else null
	if f == null:
		p = draft_path(id)                 # noch nicht gespeicherter Entwurf eines Testflugs
		f = FileAccess.open(p, FileAccess.READ) if p != "" else null
	if f == null:
		return {"ok": false, "errors": [{"code": "NOT_FOUND", "args": []}], "warnings": [], "id": "", "meta": {}, "level": {}}
	var sha := FileAccess.get_sha256(p)
	var hit = _cache.get(id)
	if hit is Dictionary and hit.sha == sha:
		return hit.res
	var res := CommunityLevel.parse_text(f.get_as_text())
	if res.ok and res.id != id:
		res["stale_id"] = id               # Inhalt passt nicht mehr zum Dateinamen (von Hand bearbeitet): gilt als neues Level
	_cache[id] = {"sha": sha, "res": res}
	return res

## Spielbares LevelData (null, wenn die Datei fehlt, ungültig oder nicht mehr zum Namen passt).
static func load_runtime(id: String) -> LevelData:
	var res := load_level(id)
	return CommunityLevel.to_level(res) if res.ok and not res.has("stale_id") else null

## Alle gültigen gespeicherten Level: [{id, name {de,en}, author, sector, jobs, license, derived_from, map}], nach Titel sortiert.
## Die Prüfung eines Levels dauert je nach Größe bis zu einigen hundert Millisekunden; der Auszug in `index.json` (je Datei mit ihrer SHA-256 geführt) erspart sie,
## solange die Datei unverändert ist. Eine von Hand veränderte oder beschädigte Datei wird neu geprüft; der Index ist nur ein Zwischenspeicher.
static func list() -> Array:
	_load_index()
	var out: Array = []
	var seen := {}
	var changed := false
	for id in _ids():
		seen[id] = true
		var sha := FileAccess.get_sha256(path_for(id))
		var e = _index.get(id)
		if not (e is Dictionary and e.get("sha") == sha):
			var res := load_level(id)
			e = {"sha": sha, "ok": res.ok and not res.has("stale_id")}
			if e.ok:
				e["name"] = res.level.name
				e["author"] = res.meta.author
				e["sector"] = res.level.sector
				e["jobs"] = res.level.jobs.size()
				e["license"] = res.meta.license
				e["derived_from"] = res.meta.derived_from
				e["map"] = res.level.map
			_index[id] = e
			changed = true
		if e.get("ok", false) == true and e.get("name") is Dictionary and e.get("map") is Array:
			out.append({"id": id, "name": e.name, "author": String(e.get("author", "")), "sector": int(e.get("sector", 1)), "jobs": int(e.get("jobs", 0)),
				"license": String(e.get("license", "")), "derived_from": String(e.get("derived_from", "")), "map": e.map})
	for id in _index.keys():
		if not seen.has(id):
			_index.erase(id)
			changed = true
	if changed:
		_save_index()
	out.sort_custom(func(a, b): return String(a.name.get("de", "")).naturalnocasecmp_to(String(b.name.get("de", ""))) < 0)
	return out

static func _load_index() -> void:
	if _index_dir == _d():
		return
	_index_dir = _d()
	_index = {}
	var f := FileAccess.open(_d() + "index.json", FileAccess.READ)
	var d = JSON.parse_string(f.get_as_text()) if f != null else null
	if d is Dictionary:
		for id in d:
			if CommunityLevel.is_valid_id(id) and d[id] is Dictionary:
				_index[id] = d[id]

static func _save_index() -> void:
	DirAccess.make_dir_recursive_absolute(_d())
	var tmp := _d() + "index.json.tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify(_index))
	f.close()
	DirAccess.rename_absolute(tmp, _d() + "index.json")

## Geprüftes Ergebnis speichern (atomar). Gibt "" zurück oder einen Fehlercode.
static func save(res: Dictionary, author := "") -> String:
	if not res.get("ok", false) or not CommunityLevel.is_valid_id(res.get("id", "")):
		return "INVALID"
	var id: String = res.id
	if not exists(id) and _ids().size() >= MAX_LEVELS:
		return "STORE_FULL"
	DirAccess.make_dir_recursive_absolute(_d())
	var p := path_for(id)
	var tmp := p + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		return "WRITE"
	f.store_string(CommunityLevel.to_file_text(res, author, game_version))
	f.close()
	if DirAccess.rename_absolute(tmp, p) != OK:
		DirAccess.remove_absolute(tmp)
		return "WRITE"
	_cache[id] = {"sha": FileAccess.get_sha256(p), "res": res}      # gerade geprüft: Liste und Spielstart brauchen es nicht noch einmal zu prüfen
	drop_draft(id)
	return ""

static func delete(id: String) -> bool:
	var p := path_for(id)
	return p != "" and FileAccess.file_exists(p) and DirAccess.remove_absolute(p) == OK

## Text (Datei oder Zwischenablage) einlesen, prüfen und speichern. Ergebnis wie `CommunityLevel.clean` plus `saved` und `existed`.
static func import_text(text: String) -> Dictionary:
	var t := text.strip_edges()
	if t.begins_with(CommunityLevel.CODE_PREFIX):
		t = CommunityLevel.from_code(t)
		if t == "":
			var bad := {"ok": false, "errors": [{"code": "BAD_CODE", "args": []}], "warnings": [], "id": "", "meta": {}, "level": {}}
			bad["saved"] = false
			bad["existed"] = false
			return bad
	var res := CommunityLevel.parse_text(t)
	res["saved"] = false
	res["existed"] = false
	if not res.ok:
		return res
	res["existed"] = exists(res.id)
	var err := save(res)
	if err != "":
		res.ok = false
		res.errors.append({"code": err, "args": []})
		return res
	res["saved"] = true
	return res

## Eine Fassung des Levels als Dateitext bzw. Teilen-Code.
static func export_text(id: String) -> String:
	var res := load_level(id)
	return CommunityLevel.to_file_text(res, "", game_version) if res.ok else ""

static func export_code(id: String) -> String:
	var t := export_text(id)
	return CommunityLevel.to_code(t) if t != "" else ""

## Kopie eines mitgelieferten Levels als neues Community-Level (Vermerk „derived_from“); das Original bleibt unverändert.
static func copy_original(orig_id: String) -> Dictionary:
	var f := FileAccess.open("res://data/levels/%s.json" % orig_id, FileAccess.READ) if orig_id.is_valid_filename() else null
	if f == null:
		return {"ok": false, "errors": [{"code": "NOT_FOUND", "args": []}], "warnings": [], "id": "", "meta": {}, "level": {}, "saved": false, "existed": false}
	var d = JSON.parse_string(f.get_as_text())
	if not (d is Dictionary):
		return {"ok": false, "errors": [{"code": "NOT_A_LEVEL", "args": []}], "warnings": [], "id": "", "meta": {}, "level": {}, "saved": false, "existed": false}
	var res := CommunityLevel.clean({"format": CommunityLevel.FORMAT, "version": CommunityLevel.VERSION, "derived_from": orig_id, "level": d})
	res["saved"] = false
	res["existed"] = false
	if res.ok:
		res["existed"] = exists(res.id)
		var err := save(res)
		res["saved"] = err == ""
		if err != "":
			res.ok = false
			res.errors.append({"code": err, "args": []})
	return res
