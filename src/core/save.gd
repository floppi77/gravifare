extends Node
## Autoload "Save": Kampagnenfortschritt in user://save.json. Atomar geschrieben (tmp + rename),
## bei defekter Datei wird sie als .bad gesichert und ein leerer Stand verwendet.

const PATH := "user://save.json"
## Dev-/Testläufe (Autopilot, Debug-Flags) dürfen den echten Speicherstand nie verändern.
var dev_session := false
var data := {"version": 1, "completed": {}, "stats": {"flights": 0, "crashes": 0, "delivered": 0}}

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a in ["--autopilot", "--debug-complete", "--debug-input", "--debug-open-exit", "--debug-destroy", "--debug-squash", "--lives"] or a.begins_with("--debug-input=") or a.begins_with("--lives="):
			dev_session = true
	load_save()

func load_save() -> void:
	if not FileAccess.file_exists(PATH):
		return
	var f := FileAccess.open(PATH, FileAccess.READ)
	var parsed = JSON.parse_string(f.get_as_text()) if f != null else null
	if typeof(parsed) == TYPE_DICTIONARY and parsed.get("completed") is Dictionary:
		data = parsed
	else:
		DirAccess.rename_absolute(PATH, PATH + ".bad")
		push_warning("Speicherstand defekt – gesichert als save.json.bad")

func write() -> void:
	if dev_session:
		return
	var tmp := PATH + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		push_warning("Speicherstand nicht schreibbar")
		return
	f.store_string(JSON.stringify(data, "\t"))
	f.close()
	DirAccess.rename_absolute(tmp, PATH)

func is_completed(id: String) -> bool:
	return data.completed.has(id)

func complete_level(id: String, time: float, money: float) -> void:
	var prev: Dictionary = data.completed.get(id, {})
	var best_time: float = minf(prev.get("time", 1e9), time)
	data.completed[id] = {"time": best_time, "money": maxf(prev.get("money", 0.0), money)}
	write()

func count_event(key: String, n := 1) -> void:
	data.stats[key] = int(data.stats.get(key, 0)) + n

## Ein Level ist frei, wenn es das erste ist oder sein Vorgänger abgeschlossen wurde.
func is_unlocked(ids: Array, i: int) -> bool:
	return i == 0 or is_completed(ids[i - 1]) or is_completed(ids[i])
