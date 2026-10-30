extends Node
## Autoload "Save": Kampagnenfortschritt in user://save.json. Atomar geschrieben (tmp + rename),
## bei defekter Datei wird sie als .bad gesichert und ein leerer Stand verwendet.

var path := "user://save.json"
## Dev-/Testläufe (Autopilot, Debug-Flags) dürfen den echten Speicherstand nie verändern.
var dev_session := false
var data := {"version": 1, "completed": {}, "stats": {"flights": 0, "crashes": 0, "deliveries": 0, "perfect_landings": 0, "best_streak": 0, "pump_hits": 0, "pump_explosions": 0, "squashes": 0, "credits_total": 0}, "unlocked": [], "cosmetics": {"paint": "std", "sticker": "none", "challenge": false}, "campaign": {}}

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a in ["--autopilot", "--debug-complete", "--debug-input", "--debug-open-exit", "--debug-destroy", "--debug-squash", "--lives"] or a.begins_with("--debug-input=") or a.begins_with("--lives=") or a.begins_with("--debug-pump=") or a.begins_with("--seed="):
			dev_session = true
	load_save()

func load_save() -> void:
	if not FileAccess.file_exists(path):
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
			data["cosmetics"] = {"paint": "std", "sticker": "none", "challenge": false}
	else:
		DirAccess.rename_absolute(path, path + ".bad")
		push_warning("Speicherstand defekt – gesichert als save.json.bad")

func write() -> void:
	if dev_session:
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

## Rekord-Statistik (z. B. längste Serie perfekter Landungen).
func note_max(key: String, value: int) -> void:
	if value > int(data.stats.get(key, 0)):
		data.stats[key] = value

func count_event(key: String, n := 1) -> void:
	data.stats[key] = int(data.stats.get(key, 0)) + n

## Ein Level ist frei, wenn es das erste ist oder sein Vorgänger abgeschlossen wurde.
func is_unlocked(ids: Array, i: int) -> bool:
	return i == 0 or is_completed(ids[i - 1]) or is_completed(ids[i])
