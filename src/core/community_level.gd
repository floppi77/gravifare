extends RefCounted
## Community-Level: Format, Prüfung und Bereinigung (ohne Autoloads, testbar). Eingelesen wird nur, was auf einer Positivliste steht;
## alles andere wird verworfen. Aus dem Ergebnis entsteht erst danach ein LevelData. Verwendung (ohne class_name):
##   const CommunityLevel := preload("res://src/core/community_level.gd")
##   var res := CommunityLevel.parse_text(text)       # {ok, errors, warnings, id, meta, level}
## Fehler und Warnungen sind {code, args}; die Oberfläche übersetzt sie über "CL_ERR_<code>" und "CL_WARN_<code>".
## Dateiformat (.gflevel, JSON): {format, version, id, author, license, created, derived_from, game, level: {...}}; "level" hat dieselben Felder wie
## data/levels/*.json (name, sector = Optik, index, map, jobs, doors, movers, zones, dark). Pars, Mechanik-Liste und ID werden berechnet.

const FORMAT := "gravifare-level"
const VERSION := 1
const MIN_W := 16
const MAX_W := 40
const MIN_H := 10
const MAX_H := 22
const MAX_TEXT := 40
const MAX_AUTHOR := 24
const MAX_MOVERS := 24
const MAX_ZONES := 16
const MAX_JOBS := 12
const MAX_PATH_POINTS := 16
const MAX_FILE_BYTES := 65536
const MAP_CHARS := "#.123456789FHLSEP^abcde"
const DOOR_CHARS := "abcde"
const KINDS_MOVER := ["debris", "slider", "pad", "meteor", "beam", "vehicle"]
const KINDS_ZONE := ["wind", "magnet", "gravity", "heat"]
const DEFAULT_LICENSE := "CC BY-NC-SA 4.0"
const DEFAULT_INDEX := 6
const CODE_PREFIX := "GFL1:"
const BOT_SECONDS := 300.0

## Alle Fehler- und Warncodes mit der Zahl ihrer Argumente (Texte: data/i18n "CL_ERR_<code>" / "CL_WARN_<code>"; ein Test hält beides zusammen).
const ERROR_CODES := {"NOT_A_LEVEL": 0, "NEWER_VERSION": 0, "MAP_MISSING": 0, "MAP_SIZE": 3, "MAP_SIZE_W": 3, "MAP_ROW_TYPE": 0, "MAP_ROW_LEN": 0, "MAP_CHAR": 1,
	"TOO_MANY_MOVERS": 1, "BAD_MOVER": 0, "TOO_MANY_ZONES": 1, "BAD_ZONE": 0, "TOO_MANY_JOBS": 1, "BAD_JOB": 0, "SPAWN_COUNT": 1, "NO_EXIT": 0, "EXIT_PLACE": 0,
	"PAD_NARROW": 1, "PAD_COUNT": 1, "PAD_NUMBERS": 0, "JOB_PADS": 1, "JOB_EXIT": 0, "JOB_CHAIN": 1, "PAD_SPLIT": 1, "NO_JOBS": 0, "UNSOLVABLE": 0, "TOO_BIG": 0, "BAD_CODE": 0, "STORE_FULL": 0,
	"WRITE": 0, "INVALID": 0, "NOT_FOUND": 0}
const WARNING_CODES := {"NO_SHELTER": 1, "BOT_FAIL": 0}

## Lesbarer Text zu einem Fehler oder einer Warnung (in der aktuellen Sprache).
static func describe(item: Dictionary, warning := false) -> String:
	var key := ("CL_WARN_" if warning else "CL_ERR_") + String(item.get("code", ""))
	var t := TranslationServer.translate(key)
	var args: Array = item.get("args", [])
	if String(t) == key:
		return String(item.get("code", ""))
	return String(t) % args if not args.is_empty() else String(t)

static func is_valid_id(id: Variant) -> bool:
	if typeof(id) != TYPE_STRING:
		return false
	var s: String = id
	if s.length() != 12 or not s.begins_with("c_"):
		return false
	for i in range(2, 12):
		if not "0123456789abcdef".contains(s[i]):
			return false
	return true

# ---------------------------------------------------------------------------------------------------------------- Hilfsfunktionen

## `at` (optional): Fundstelle für den Editor, damit er die betroffenen Objekte blinken lassen kann: {"cells": [[x, y], …], "movers": [Index, …]}.
static func _err(res: Dictionary, code: String, args: Array = [], at: Dictionary = {}) -> void:
	var e := {"code": code, "args": args}
	if not at.is_empty():
		e["at"] = at
	res.errors.append(e)

## Kartenfelder mit einem der Zeichen `chars` als [[x, y], …].
static func _cells_of(map: Array, chars: String) -> Array:
	var out: Array = []
	for y in map.size():
		var row := String(map[y])
		for x in row.length():
			if chars.contains(row[x]):
				out.append([x, y])
	return out

static func _warn(res: Dictionary, code: String, args: Array = []) -> void:
	res.warnings.append({"code": code, "args": args})

## Text aus einem beliebigen eingelesenen Wert: alles außer einem String ergibt "" (String(x) würde bei Feldern/Wörterbüchern abstürzen).
static func _str(v: Variant) -> String:
	return v if typeof(v) == TYPE_STRING else ""

static func _bool(v: Variant) -> bool:
	return typeof(v) == TYPE_BOOL and bool(v)

static func _num(v: Variant, lo: float, hi: float, def: float) -> float:
	if typeof(v) != TYPE_INT and typeof(v) != TYPE_FLOAT:
		return def
	var f := float(v)
	if is_nan(f) or is_inf(f):
		return def
	return snappedf(clampf(f, lo, hi), 0.01)

static func _int(v: Variant, lo: int, hi: int, def: int) -> int:
	return int(_num(v, float(lo), float(hi), float(def)))

## Text ohne Steuerzeichen, getrimmt und gekürzt.
static func clean_text(v: Variant, max_len: int) -> String:
	if typeof(v) != TYPE_STRING:
		return ""
	var out := ""
	for ch in String(v):
		if ch.unicode_at(0) >= 32 and ch.unicode_at(0) != 127:
			out += ch
	return out.strip_edges().substr(0, max_len)

static func _date(v: Variant) -> String:
	var s := clean_text(v, 10)
	var re := RegEx.new()
	re.compile("^\\d{4}-\\d{2}-\\d{2}$")
	return s if re.search(s) != null else ""

static func _slug(v: Variant) -> String:
	var s := clean_text(v, 24)
	for ch in s:
		if not "abcdefghijklmnopqrstuvwxyz0123456789_".contains(ch):
			return ""
	return s

# ---------------------------------------------------------------------------------------------------------------- Bereiche des Levels

static func _clean_map(v: Variant, res: Dictionary) -> Array:
	if not (v is Array):
		_err(res, "MAP_MISSING")
		return []
	var rows: Array = []
	var width := -1
	if v.size() < MIN_H or v.size() > MAX_H:
		_err(res, "MAP_SIZE", [v.size(), MIN_H, MAX_H])
		return []
	for r in v:
		if typeof(r) != TYPE_STRING:
			_err(res, "MAP_ROW_TYPE")
			return []
		var row: String = r
		if row.length() < MIN_W or row.length() > MAX_W:
			_err(res, "MAP_SIZE_W", [row.length(), MIN_W, MAX_W])
			return []
		if width >= 0 and row.length() != width:
			_err(res, "MAP_ROW_LEN")
			return []
		width = row.length()
		for ch in row:
			if not MAP_CHARS.contains(ch):
				_err(res, "MAP_CHAR", [ch if ch.unicode_at(0) >= 32 else "?"])
				return []
		rows.append(row)
	return rows

static func _clean_doors(v: Variant, rows: Array) -> Dictionary:
	var out := {}
	if not (v is Dictionary):
		return out
	for ch in DOOR_CHARS:
		var used := false
		for r in rows:
			if String(r).contains(ch):
				used = true
		if not used or not (v.get(ch) is Dictionary):
			continue
		var p: Dictionary = v[ch]
		var d := {"period": _num(p.get("period"), 2.0, 60.0, 8.0), "phase": _num(p.get("phase"), 0.0, 240.0, 0.0)}
		d["open"] = _num(p.get("open"), 0.0, d.period, minf(5.0, d.period))
		if p.has("sweep"):
			d["sweep"] = _num(p.get("sweep"), 0.0, 60.0, 0.0)
			d["gap"] = _num(p.get("gap"), 1.0, 8.0, 3.0)
		if _bool(p.get("glass")):
			d["glass"] = true
		var orient := _int(p.get("orient"), 0, 2, 0)
		if orient > 0:
			d["orient"] = orient                         # 1 Flügel fahren senkrecht, 2 waagerecht (sonst aus der Umgebung)
		out[ch] = d
	return out

## Gemeinsame Felder eines beweglichen Hindernisses bzw. einer Zone; unbekannte Schlüssel fallen weg.
static func _clean_mover(d: Dictionary) -> Dictionary:
	var kind := _str(d.get("kind"))
	var m := {"kind": kind}
	for k in ["x", "y"]:
		m[k] = _num(d.get(k), -8.0, 64.0, 0.0)
	for k in ["w", "h"]:
		m[k] = _num(d.get(k), 0.0, 64.0, 1.0 if kind != "debris" else 2.0)
	for k in ["dx", "dy"]:
		m[k] = _num(d.get(k), -64.0, 64.0, 0.0)
	m["period"] = _num(d.get("period"), 0.5, 120.0, 8.0)
	m["phase"] = _num(d.get("phase"), -240.0, 240.0, 0.0)
	if kind == "meteor":
		m["fall"] = _num(d.get("fall"), 0.3, 30.0, 1.6)
		m["warn"] = _num(d.get("warn"), 0.0, 30.0, 2.0)
	elif kind == "beam":
		m["on"] = _num(d.get("on"), 0.0, 60.0, 3.0)
		m["warn"] = _num(d.get("warn"), 0.0, 30.0, 2.0)
		m["tint"] = _int(d.get("tint"), 0, 1, 0)
	elif kind == "pad":
		var pid := clean_text(d.get("pad"), 1)
		m["pad"] = pid if pid != "" and "123456789".contains(pid) else ""
		if _bool(d.get("spikes")):
			m["spikes"] = true
	elif kind == "vehicle":
		m["speed"] = _num(d.get("speed"), -400.0, 400.0, 50.0)
		m["paint"] = _int(d.get("paint"), 0, 7, 0)
		if d.get("path") is Array:
			var pts: Array = []
			for p in d.path:
				if p is Array and p.size() >= 2 and pts.size() < MAX_PATH_POINTS:
					pts.append([_num(p[0], -8.0, 64.0, 0.0), _num(p[1], -8.0, 64.0, 0.0)])
			m["path"] = pts
	if kind == "debris" or kind == "slider":
		m["shape"] = "circle" if _str(d.get("shape")) == "circle" else "line"
	return m

static func _clean_movers(v: Variant, res: Dictionary) -> Array:
	var out: Array = []
	if not (v is Array):
		return out
	if v.size() > MAX_MOVERS:
		_err(res, "TOO_MANY_MOVERS", [MAX_MOVERS])
		return out
	for i in v.size():
		var d: Variant = v[i]
		if not (d is Dictionary) or not KINDS_MOVER.has(_str(d.get("kind"))):
			_err(res, "BAD_MOVER", [], {"movers": [i]})
			return []
		var m := _clean_mover(d)
		if m.kind == "pad" and m.pad == "":
			_err(res, "BAD_MOVER", [], {"movers": [i]})
			return []
		if m.kind == "vehicle" and m.has("path") and m.path.size() < 2:
			_err(res, "BAD_MOVER", [], {"movers": [i]})
			return []
		out.append(m)
	return out

static func _clean_zones(v: Variant, res: Dictionary) -> Array:
	var out: Array = []
	if not (v is Array):
		return out
	if v.size() > MAX_ZONES:
		_err(res, "TOO_MANY_ZONES", [MAX_ZONES])
		return out
	for d in v:
		if not (d is Dictionary) or not KINDS_ZONE.has(_str(d.get("kind"))):
			_err(res, "BAD_ZONE")
			return []
		var z := {"kind": String(d.kind)}
		if z.kind == "magnet":
			z["cx"] = _num(d.get("cx"), -8.0, 64.0, 0.0)
			z["cy"] = _num(d.get("cy"), -8.0, 64.0, 0.0)
			z["r"] = _num(d.get("r"), 0.5, 20.0, 4.0)
			z["k"] = _num(d.get("k"), -400.0, 400.0, 0.0)
			if _bool(d.get("cycle")):
				z["cycle"] = true
		else:
			for k in ["x", "y"]:
				z[k] = _num(d.get(k), -8.0, 64.0, 0.0)
			for k in ["w", "h"]:
				z[k] = _num(d.get(k), 0.0, 64.0, 1.0)
			if z.kind == "wind":
				z["ax"] = _num(d.get("ax"), -400.0, 400.0, 0.0)
				z["ay"] = _num(d.get("ay"), -400.0, 400.0, 0.0)
			elif z.kind == "gravity":
				z["g"] = _num(d.get("g"), -3.0, 3.0, 1.0)
		if d.has("period"):
			z["period"] = _num(d.get("period"), 0.5, 120.0, 8.0)
			z["on"] = _num(d.get("on"), 0.0, 120.0, 4.0)
			z["phase"] = _num(d.get("phase"), -240.0, 240.0, 0.0)
		out.append(z)
	return out

static func _clean_jobs(v: Variant, res: Dictionary) -> Array:
	var out: Array = []
	if not (v is Array) or v.is_empty():
		return out
	if v.size() > MAX_JOBS:
		_err(res, "TOO_MANY_JOBS", [MAX_JOBS])
		return out
	for d in v:
		if not (d is Dictionary):
			_err(res, "BAD_JOB")
			return []
		var j := {"from": clean_text(d.get("from"), 1), "to": clean_text(d.get("to"), 4),
			"fare": _num(d.get("fare"), 30.0, 300.0, 60.0), "passenger": clean_text(d.get("passenger"), 16),
			"gender": "m" if _str(d.get("gender")) == "m" else "f"}
		if _bool(d.get("fragile")):
			j["fragile"] = true
		if Tuning.PASSENGER_KINDS.has(_str(d.get("kind"))):
			j["kind"] = _str(d.get("kind"))      # Fahrgasttyp (VIP, Notfall); unbekannte Werte entfallen, ältere Level haben das Feld nicht
		out.append(j)
	return out

# ---------------------------------------------------------------------------------------------------------------- Hauptfunktion

## Prüft und bereinigt ein eingelesenes Objekt (Dateirahmen oder nacktes Level). Ergebnis: {ok, errors, warnings, id, meta, level}.
static func clean(raw: Variant) -> Dictionary:
	var res := {"ok": false, "errors": [], "warnings": [], "id": "", "meta": {}, "level": {}}
	if not (raw is Dictionary):
		_err(res, "NOT_A_LEVEL")
		return res
	var src: Dictionary = raw
	var meta_in: Dictionary = {}
	if src.has("format"):
		if _str(src.get("format")) != FORMAT:
			_err(res, "NOT_A_LEVEL")
			return res
		if _int(src.get("version"), 0, 1000000, 0) > VERSION:
			_err(res, "NEWER_VERSION")
			return res
		meta_in = src
		if not (src.get("level") is Dictionary):
			_err(res, "NOT_A_LEVEL")
			return res
		src = src.level
	var names_in = src.get("name", {})
	var names := {}
	for lang in ["de", "en"]:
		var t := clean_text(names_in.get(lang) if names_in is Dictionary else names_in, MAX_TEXT)
		if t != "":
			names[lang] = t
	if names.is_empty():
		names = {"de": "Community-Level", "en": "Community level"}
	elif not names.has("de"):
		names["de"] = names.en
	elif not names.has("en"):
		names["en"] = names.de
	var rows := _clean_map(src.get("map"), res)
	if not res.errors.is_empty():
		return res
	var lvl := {"name": names, "sector": _int(src.get("sector"), 1, 9, 1), "index": _int(src.get("index"), 1, 11, DEFAULT_INDEX), "map": rows,
		"dark": _num(src.get("dark"), 0.0, 1.0, 0.0)}
	lvl["doors"] = _clean_doors(src.get("doors"), rows)
	lvl["movers"] = _clean_movers(src.get("movers"), res)
	lvl["zones"] = _clean_zones(src.get("zones"), res)
	var jobs := _clean_jobs(src.get("jobs"), res)
	if not res.errors.is_empty():
		return res
	var job_seed := _int(src.get("job_seed"), 0, 99999, 0)
	if jobs.is_empty() and job_seed > 0:
		lvl["job_seed"] = job_seed                  # Würfelzahl der automatischen Aufträge (nur ohne eigene Aufträge)
	res["meta"] = {"author": clean_text(meta_in.get("author"), MAX_AUTHOR), "license": clean_text(meta_in.get("license"), 40),
		"created": _date(meta_in.get("created")), "derived_from": _slug(meta_in.get("derived_from")), "game": clean_text(meta_in.get("game"), 12)}
	if res.meta.license == "":
		res.meta.license = DEFAULT_LICENSE
	_check_structure(lvl, jobs, res)
	if not res.errors.is_empty():
		return res
	lvl.erase("id")                      # die ID ist der Hash des bereinigten Inhalts (ohne sie selbst)
	res.level = lvl
	res.id = "c_" + JSON.stringify(lvl, "", true).sha256_text().substr(0, 10)
	lvl["id"] = res.id
	res.ok = true
	return res

## Fundstelle eines Auftrags: die Felder seiner Pads (Abholung, Ziel; "exit" = Tor).
static func _job_at(map: Array, j: Dictionary) -> Dictionary:
	var chars := ""
	for k in ["from", "to"]:
		var id := String(j.get(k, ""))
		chars += "E" if id == "exit" else (id if id.length() == 1 else "")
	return {"cells": _cells_of(map, chars)}

## Baut ein LevelData, prüft die Spielregeln und setzt Aufträge samt Richtzeiten (bei fehlenden Aufträgen werden sie erzeugt).
static func _check_structure(lvl: Dictionary, jobs_in: Array, res: Dictionary) -> void:
	var spawns := 0
	var exits := 0
	for r in lvl.map:
		spawns += String(r).count("S")
		exits += String(r).count("E")
	if spawns != 1:
		_err(res, "SPAWN_COUNT", [spawns], {"cells": _cells_of(lvl.map, "S")})
	if exits == 0:
		_err(res, "NO_EXIT")
	if not res.errors.is_empty():
		return
	var geom := {"name": lvl.name, "sector": lvl.sector, "index": lvl.index, "map": lvl.map, "dark": lvl.dark, "doors": lvl.doors, "movers": lvl.movers, "zones": lvl.zones}
	lvl["id"] = "c_" + JSON.stringify(geom, "", true).sha256_text().substr(0, 10)
	lvl["jobs"] = []
	var base := LevelData.from_dict(lvl)
	var er := base.exit_rect()
	if not (er.size.x > 0 and absf(er.get_center().x - base.width * Tuning.TILE * 0.5) < 1.0 and er.position.y <= Tuning.TILE * 2.0):
		_err(res, "EXIT_PLACE", [], {"cells": _cells_of(lvl.map, "E")})
	var runs := {}                                # dieselbe Pad-Ziffer an zwei getrennten Stellen ergäbe nur ein Pad: abweisen
	for r in lvl.map:
		var row: String = r
		for x in row.length():
			var c := row[x]
			if "123456789".contains(c) and (x == 0 or row[x - 1] != c):
				runs[c] = int(runs.get(c, 0)) + 1
	for c in runs:
		if int(runs[c]) > 1:
			_err(res, "PAD_SPLIT", [c], {"cells": _cells_of(lvl.map, c)})
	var ids: Array = []
	for id in base.pads:
		var p: Dictionary = base.pads[id]
		if base.is_passenger_pad(id):
			ids.append(int(id))
			if int((p.x1 - p.x0) / Tuning.TILE) < 4:
				_err(res, "PAD_NARROW", [id], {"cells": _cells_of(lvl.map, String(id))})
			if int(p.get("side", 0)) == 0:
				_warn(res, "NO_SHELTER", [id])
	ids.sort()
	if ids.size() < 2 or ids.size() > 9:
		_err(res, "PAD_COUNT", [ids.size()], {"cells": _cells_of(lvl.map, "123456789")})
	else:
		for i in ids.size():
			if ids[i] != i + 1:
				_err(res, "PAD_NUMBERS", [], {"cells": _cells_of(lvl.map, "123456789")})
				break
	if not res.errors.is_empty():
		return
	var jobs := jobs_in
	if jobs.is_empty():
		var rng := RandomNumberGenerator.new()
		rng.seed = String(lvl.id).hash() + int(lvl.get("job_seed", 0)) * 7919
		jobs = Run.shift_jobs(base, 3, rng)
	else:
		var start_pad := ""                       # Pad unter dem Start: dort darf kein Fahrgast auf das Taxi warten (wie bei den Originalen)
		for dy in range(0, 3):
			var sp := base.pad_at_foot(base.spawn + Vector2(0, dy * Tuning.TILE))
			if not sp.is_empty():
				start_pad = String(sp.id)
				break
		var prev_to := start_pad
		for i in jobs.size():
			var j: Dictionary = jobs[i]
			var to := String(j.to)
			var to_ok: bool = to == "exit" or base.is_passenger_pad(to) or (to == "H" and base.pads.has("H") and bool(j.get("fragile", false)))      # „H“: Krankenhaus, Ziel zerbrechlicher Fahrgäste
			if not base.is_passenger_pad(String(j.from)) or not to_ok or String(j.from) == to:
				_err(res, "JOB_PADS", [i + 1], _job_at(lvl.map, j))
				return
			if (to == "exit") != (i == jobs.size() - 1):
				_err(res, "JOB_EXIT", [], _job_at(lvl.map, j))
				return
			if String(j.from) == prev_to:
				_err(res, "JOB_CHAIN", [i + 1], _job_at(lvl.map, j))
				return
			prev_to = to
	if jobs.is_empty():
		_err(res, "NO_JOBS")
		return
	var out: Array = []
	for j in jobs:
		var o := {"from": String(j.from), "to": String(j.to), "fare": float(j.get("fare", 60.0)),
			"par": snappedf(14.0 + LevelMetrics.leg_length(base, String(j.from), String(j.to)) / 38.0, 1.0),
			"passenger": String(j.get("passenger", "")) if String(j.get("passenger", "")) != "" else "?", "gender": String(j.get("gender", "f"))}
		if bool(j.get("fragile", false)):
			o["fragile"] = true
		if j.has("kind") and String(j.to) != "exit":
			o["kind"] = String(j.kind)
		out.append(o)
	lvl["jobs"] = out
	lvl.erase("job_seed")                         # die Aufträge stehen jetzt fest in der Datei
	var final := LevelData.from_dict(lvl)
	var bad := LevelMetrics.blocked_leg(final)
	if not bad.is_empty():
		var chars := ""
		for k in ["from", "to"]:
			var id := String(bad[k])
			chars += "E" if id == "exit" else id
		_err(res, "UNSOLVABLE", [], {"cells": _cells_of(lvl.map, chars)})

# ---------------------------------------------------------------------------------------------------------------- Ein- und Ausgabe

## Datei- oder Zwischenablagetext (JSON) prüfen.
static func parse_text(text: String) -> Dictionary:
	if text.to_utf8_buffer().size() > MAX_FILE_BYTES:
		var r := {"ok": false, "errors": [], "warnings": [], "id": "", "meta": {}, "level": {}}
		_err(r, "TOO_BIG")
		return r
	return clean(JSON.parse_string(text))

## Dateitext eines geprüften Levels (nur gültige Ergebnisse).
static func to_file_text(res: Dictionary, author := "", game := "") -> String:
	var meta: Dictionary = res.meta
	var lvl: Dictionary = res.level.duplicate(true)
	lvl.erase("id")
	var doc := {"format": FORMAT, "version": VERSION, "id": res.id, "game": game, "author": author if author != "" else meta.get("author", ""),
		"license": meta.get("license", DEFAULT_LICENSE), "created": meta.get("created", ""), "level": lvl}
	if String(meta.get("derived_from", "")) != "":
		doc["derived_from"] = meta.derived_from
	return JSON.stringify(doc, "\t", true)

## Teilen als Text: "GFL1:<Größe>:<Base64 des deflate-komprimierten Dateitexts>".
static func to_code(file_text: String) -> String:
	var raw := file_text.to_utf8_buffer()
	return "%s%d:%s" % [CODE_PREFIX, raw.size(), Marshalls.raw_to_base64(raw.compress(FileAccess.COMPRESSION_DEFLATE))]

## Gegenstück zu to_code; leerer Text bei ungültigem oder zu großem Code (die angegebene Größe begrenzt den Speicher).
static func from_code(code: String) -> String:
	var s := code.strip_edges()
	if not s.begins_with(CODE_PREFIX):
		return ""
	var parts := s.substr(CODE_PREFIX.length()).split(":", false, 1)
	if parts.size() != 2 or not parts[0].is_valid_int():
		return ""
	var size := int(parts[0])
	if size <= 0 or size > MAX_FILE_BYTES:
		return ""
	var packed := Marshalls.base64_to_raw(parts[1])
	if packed.is_empty() or packed.size() > MAX_FILE_BYTES:
		return ""
	var raw := packed.decompress(size, FileAccess.COMPRESSION_DEFLATE)
	return raw.get_string_from_utf8() if raw.size() == size else ""

## LevelData aus einem geprüften Ergebnis.
static func to_level(res: Dictionary) -> LevelData:
	return LevelData.from_dict(res.level.duplicate(true)) if res.ok else null

## Probeflug des Autopiloten (dauert einige Sekunden): {complete, hull, ...}. Ein Fehlschlag ist nur eine Warnung, kein Beweis der Unlösbarkeit.
static func bot_check(res: Dictionary) -> Dictionary:
	var lvl := to_level(res)
	if lvl == null:
		return {"complete": false}
	return Bot.fly_level(lvl, BOT_SECONDS, Tuning.FUEL_MAX)
