extends RefCounted
## Ablage der Community-Level: user://community/<id>.gflevel (ID = Hash des Inhalts, siehe community_level.gd). Geschrieben wird ausschließlich
## in diesen Ordner, und nur unter gültigen IDs; die mitgelieferten Level unter res://data/levels werden nie verändert (nur gelesen).
## Verwendung (ohne class_name): const CommunityStore := preload("res://src/core/community_store.gd")

const CommunityLevel := preload("res://src/core/community_level.gd")
const DIR := "user://community/"
const MAX_LEVELS := 200
static var dir := DIR                 # Tests weichen auf einen eigenen Ordner aus
static var game_version := ""         # setzt Flow beim Start; steht in den gespeicherten Dateien

static func path_for(id: String) -> String:
	return dir + id + ".gflevel" if CommunityLevel.is_valid_id(id) else ""

static func exists(id: String) -> bool:
	var p := path_for(id)
	return p != "" and FileAccess.file_exists(p)

static func _ids() -> Array:
	var out: Array = []
	var d := DirAccess.open(dir)
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
	if _index_dir == dir:
		return
	_index_dir = dir
	_index = {}
	var f := FileAccess.open(dir + "index.json", FileAccess.READ)
	var d = JSON.parse_string(f.get_as_text()) if f != null else null
	if d is Dictionary:
		for id in d:
			if CommunityLevel.is_valid_id(id) and d[id] is Dictionary:
				_index[id] = d[id]

static func _save_index() -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	var tmp := dir + "index.json.tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify(_index))
	f.close()
	DirAccess.rename_absolute(tmp, dir + "index.json")

## Geprüftes Ergebnis speichern (atomar). Gibt "" zurück oder einen Fehlercode.
static func save(res: Dictionary, author := "") -> String:
	if not res.get("ok", false) or not CommunityLevel.is_valid_id(res.get("id", "")):
		return "INVALID"
	var id: String = res.id
	if not exists(id) and _ids().size() >= MAX_LEVELS:
		return "STORE_FULL"
	DirAccess.make_dir_recursive_absolute(dir)
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
