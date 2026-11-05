extends Node
## Autoload "Save": Kampagnenfortschritt in drei unabhängigen Speicherplätzen (user://save_1.json … save_3.json).
## Atomar geschrieben (tmp + rename), bei defekter Datei wird sie als .bad gesichert und ein leerer Stand verwendet.
## Bis ein Platz gewählt ist (slot == 0), wird nichts geladen oder geschrieben.

const SLOTS := 3
var legacy_path := "user://save.json"      # Speicherstand vor den Plätzen: wird einmalig nach Platz 1 übernommen
var slot := 0
var path := ""
## Dev-/Testläufe (Autopilot, Debug-Flags) dürfen den echten Speicherstand nie verändern.
var dev_session := false
var data := _default_data()

static func _default_data() -> Dictionary:
	return {"version": 1, "completed": {}, "stats": {"flights": 0, "crashes": 0, "deliveries": 0, "perfect_landings": 0, "best_streak": 0, "pump_hits": 0, "pump_explosions": 0, "squashes": 0, "credits_total": 0}, "unlocked": [], "cosmetics": {"paint": "std", "sticker": "none"}, "campaign": {}}

## Gesetzt von Flow.community: Während eines Community-Levels werden Statistik und Freischaltungen nicht verändert.
var community_mode := false
var slot_prefix := "user://save_"      # Tests weichen auf eigene Dateien aus

func slot_path(n: int) -> String:
	return "%s%d.json" % [slot_prefix, n]

func _ready() -> void:
	var want := 0
	for a in OS.get_cmdline_user_args():
		if a in ["--autopilot", "--debug-complete", "--debug-input", "--debug-open-exit", "--debug-destroy", "--debug-squash", "--lives"] or a.begins_with("--debug-input=") or a.begins_with("--lives=") or a.begins_with("--debug-pump=") or a.begins_with("--seed=") or a.begins_with("--clip=") or a.begins_with("--tut-step=") or a.begins_with("--shot=") or a.begins_with("--skip-time=") or a.begins_with("--dark="):
			dev_session = true
		if a.begins_with("--level=") or a.begins_with("--scene=") or a == "--levels" or a.begins_with("--shot="):
			want = maxi(want, 1)                 # Dev-Aufrufe überspringen die Platzwahl (Platz 1)
		if a.begins_with("--slot="):
			want = clampi(int(a.substr(7)), 1, SLOTS)
	if dev_session:
		want = maxi(want, 1)
	if want > 0:
		select_slot(want)

## Wählt einen Speicherplatz (1–3) und lädt ihn; ein neuer Platz beginnt leer. Beim ersten Mal wird ein alter Einzel-Speicherstand in Platz 1 übernommen.
func select_slot(n: int) -> void:
	n = clampi(n, 1, SLOTS)
	if n == 1 and not FileAccess.file_exists(slot_path(1)) and FileAccess.file_exists(legacy_path) and not dev_session:
		DirAccess.copy_absolute(legacy_path, slot_path(1))
	slot = n
	path = slot_path(n)
	data = _default_data()
	load_save()

## Zurück zur Platzwahl (Menü „Spielstand wechseln“); der laufende Stand ist bereits gespeichert.
func leave_slot() -> void:
	slot = 0
	path = ""
	data = _default_data()

func slot_exists(n: int) -> bool:
	return FileAccess.file_exists(slot_path(n))

## Kurzinfo eines Platzes für die Auswahl: {"exists", "levels", "score", "seconds", "credits", "lives"} (Datei wird nur gelesen).
func slot_summary(n: int) -> Dictionary:
	var info := {"exists": false, "levels": 0, "score": 0, "seconds": 0, "credits": 0, "lives": 0}
	if not slot_exists(n):
		return info
	var f := FileAccess.open(slot_path(n), FileAccess.READ)
	var d = JSON.parse_string(f.get_as_text()) if f != null else null
	if typeof(d) != TYPE_DICTIONARY or not (d.get("completed") is Dictionary):
		return info
	info["exists"] = true
	info["levels"] = d.completed.size()
	var sc := 0
	for id in d.completed:
		var entry = d.completed[id]
		if entry is Dictionary:                       # handeditierte/defekte Einträge dürfen die Platzwahl nicht abstürzen lassen
			sc += int(entry.get("score", 0))
	info["score"] = sc
	var st = d.get("stats", {})
	info["seconds"] = int(float(st.get("play_seconds", 0.0))) if st is Dictionary else 0
	var c = d.get("campaign", {})
	if c is Dictionary and c.has("level"):
		info["credits"] = int(c.get("credits", 0.0))
		info["lives"] = int(c.get("lives", 0))
	return info

## Löscht einen Speicherplatz; er ist danach frei für einen neuen Spielstand.
func delete_slot(n: int) -> void:
	for suffix in ["", ".tmp", ".bad"]:
		if FileAccess.file_exists(slot_path(n) + suffix):
			DirAccess.remove_absolute(slot_path(n) + suffix)
	var rd := Replay.dir_for(n)                     # Bestzeit-Geister dieses Platzes gehen mit
	if DirAccess.dir_exists_absolute(rd) and not dev_session and slot_prefix == "user://save_":
		for f in DirAccess.get_files_at(rd):
			DirAccess.remove_absolute(rd + f)
		DirAccess.remove_absolute(rd)
	if slot == n:
		leave_slot()

func load_save() -> void:
	if path == "" or not FileAccess.file_exists(path):
		return
	var f := FileAccess.open(path, FileAccess.READ)
	var parsed = JSON.parse_string(f.get_as_text()) if f != null else null
	if typeof(parsed) == TYPE_DICTIONARY and parsed.get("completed") is Dictionary:
		data = parsed
		if not data.has("stats") or not (data.stats is Dictionary):
			data["stats"] = {}
		if not data.has("unlocked"):
			data["unlocked"] = []
		if not (data.get("campaign") is Dictionary):
			data["campaign"] = {}
		if not data.has("cosmetics"):
			data["cosmetics"] = {"paint": "std", "sticker": "none"}
	else:
		var bad := path + ".bad"
		if FileAccess.file_exists(bad):               # frühere Sicherung nicht überschreiben
			bad = "%s.bad%d" % [path, int(Time.get_unix_time_from_system())]
		DirAccess.rename_absolute(path, bad)
		push_warning("Speicherstand defekt – gesichert als " + bad.get_file())

func write() -> void:
	if dev_session or slot == 0:
		return
	var tmp := path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		push_warning("Speicherstand nicht schreibbar")
		return
	f.store_string(JSON.stringify(data, "\t"))
	f.close()
	DirAccess.rename_absolute(tmp, path)

## Laufender Feldzug (für „Fortsetzen“): nächstes Level, Leben, Credits, Sprit, Seed, mitfahrender Fahrgast.
func campaign() -> Dictionary:
	var c = data.get("campaign", {})
	return c if c is Dictionary and c.has("level") else {}

func set_campaign(c: Dictionary) -> void:
	data["campaign"] = c
	write()

## Leben sofort sichern, damit „Fortsetzen“ ein verlorenes Leben nicht zurückholt.
func note_campaign_lives(n: int) -> void:
	if not campaign().is_empty():
		data.campaign["lives"] = n
		write()

func clear_campaign() -> void:
	if not data.get("campaign", {}).is_empty():
		data["campaign"] = {}
		write()

func is_completed(id: String) -> bool:
	return data.completed.has(id)

func best_time(id: String) -> float:
	return float(data.completed.get(id, {}).get("time", -1.0)) if data.completed.has(id) else -1.0

func medals_of(id: String) -> Dictionary:
	return data.completed.get(id, {}).get("medals", {"time": false, "clean": false, "pro": false})

func best_score(id: String) -> int:
	return int(data.completed.get(id, {}).get("score", 0)) if data.completed.has(id) else 0

func total_score() -> int:
	var t := 0
	for id in data.completed:
		t += int(data.completed[id].get("score", 0))
	return t

func add_playtime(seconds: float) -> void:
	data.stats["play_seconds"] = float(data.stats.get("play_seconds", 0.0)) + seconds

func complete_level(id: String, time: float, money: float, earned := 0.0, medals := {}, score := 0) -> void:
	var prev: Dictionary = data.completed.get(id, {})
	var best_time: float = minf(prev.get("time", 1e9), time)
	var old_m: Dictionary = prev.get("medals", {})
	var merged := {"time": bool(old_m.get("time", false)) or bool(medals.get("time", false)),
		"clean": bool(old_m.get("clean", false)) or bool(medals.get("clean", false)),
		"pro": bool(old_m.get("pro", false)) or bool(medals.get("pro", false))}
	data.completed[id] = {"time": best_time, "money": maxf(prev.get("money", 0.0), money), "medals": merged, "score": maxi(int(prev.get("score", 0)), score)}
	data.stats["credits_total"] = int(data.stats.get("credits_total", 0)) + int(earned)
	write()

## Community-Level: eigene Bestwerte je Level-ID (Inhalts-Hash), getrennt vom Feldzug; fehlt in älteren Spielständen.
func community_entry() -> Dictionary:
	if not (data.get("community") is Dictionary):
		data["community"] = {}
	return data.community

func community_best_time(id: String) -> float:
	var e = community_entry().get(id)
	return float(e.get("time", -1.0)) if e is Dictionary else -1.0

func community_best_score(id: String) -> int:
	var e = community_entry().get(id)
	return int(e.get("score", 0)) if e is Dictionary else 0

func community_plays(id: String) -> int:
	var e = community_entry().get(id)
	return int(e.get("plays", 0)) if e is Dictionary else 0

## Name, unter dem eigene Community-Level gespeichert werden (Vorbelegung im Editor), je Speicherplatz.
func community_author() -> String:
	return String(data.get("community_author", ""))

func set_community_author(name: String) -> void:
	if name != community_author():
		data["community_author"] = name.substr(0, 24)
		write()

func community_forget(id: String) -> void:
	if community_entry().erase(id):
		write()

## Geschafften Community-Flug werten (nur Bestzeit, Bestwert, Zähler). Die Einträge sind auf 200 Level begrenzt.
func complete_community(id: String, time: float, score: int) -> void:
	var c := community_entry()
	if not c.has(id) and c.size() >= 200:
		return
	var prev = c.get(id, {})
	var best_t: float = minf(float(prev.get("time", 1e9)), time) if prev is Dictionary else time
	c[id] = {"time": best_t, "score": maxi(int(prev.get("score", 0)) if prev is Dictionary else 0, score), "plays": (int(prev.get("plays", 0)) if prev is Dictionary else 0) + 1}
	write()

## Rekord-Statistik (z. B. längste Serie perfekter Landungen).
func note_max(key: String, value: int) -> void:
	if community_mode:
		return                                       # Community-Level zählen nicht für Statistiken und Freischaltungen
	if value > int(data.stats.get(key, 0)):
		data.stats[key] = value

func count_event(key: String, n := 1) -> void:
	if community_mode:
		return
	data.stats[key] = int(data.stats.get(key, 0)) + n

## Debug-Modus (im Hauptmenü per Code ein- und abschaltbar, Settings.values.debug): alles frei.
var debug := false

## Ein Level ist frei, wenn es das erste ist oder sein Vorgänger abgeschlossen wurde.
func is_unlocked(ids: Array, i: int) -> bool:
	return debug or i == 0 or is_completed(ids[i - 1]) or is_completed(ids[i])

## Jemals geschaffte Level: bleiben auch nach einem Game Over gültig (Musik, Nachtschicht).
func ever_completed() -> Dictionary:
	var out: Dictionary = data.get("ever", {}).duplicate()
	out.merge(data.completed)
	return out

## Tagesflug: Eintrag im Spielstand (Datum, Karte, Bestwert des Tages), fehlt in älteren Spielständen.
func daily_entry() -> Dictionary:
	if not (data.get("daily") is Dictionary):
		data["daily"] = {}
	return data.daily

## Kartenvorrat des Tagesflugs: alle jemals geschafften Level (ohne Flugschule), die es noch gibt.
func daily_pool(ids: Array) -> Array:
	return ever_completed().keys().filter(func(id): return ids.has(id))

## Tagesflug: frei ab Sektor 1 (11 geschaffte Level) oder im Debug-Modus.
func daily_unlocked(ids: Array) -> bool:
	return debug or daily_pool(ids).size() >= Daily.UNLOCK_LEVELS

## Nachtschicht: erst, wenn alle Level einmal geschafft wurden.
func shift_unlocked(ids: Array) -> bool:
	var done := ever_completed()
	return debug or ids.all(func(id): return done.has(id))

## Game Over im Feldzug: Der Fortschritt des Sektors geht verloren, die Einbauten der Werkstatt und alle Credits auch.
## Weiter geht es mit `first_level`, dem ersten Level des Sektors.
func lose_sector(sector: int, first_level: String, run_seed: int) -> void:
	var ever: Dictionary = data.get("ever", {})
	var prefix := "s%d_" % sector
	for id in data.completed.keys():
		ever[id] = true
		if String(id).begins_with(prefix):
			data.completed.erase(id)
	data["ever"] = ever
	data["workshop"] = {}
	data["campaign"] = {"level": first_level, "lives": Tuning.START_LIVES, "fuel": Tuning.FUEL_MAX, "credits": 0.0, "seed": run_seed, "carry": {}}
	write()
