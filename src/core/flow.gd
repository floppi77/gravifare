extends Node
## Autoload "Flow": Szenenwechsel und aktuelles Level. Levelreihenfolge = sortierte Dateinamen.

const MENU := "res://src/ui/main_menu.tscn"
const GAME := "res://src/game/game.tscn"
var current_level := ""

func level_ids() -> Array:
	var ids: Array = []
	var dir := DirAccess.open("res://data/levels")
	if dir == null:
		return ids
	for f in dir.get_files():
		if f.ends_with(".json"):
			ids.append(f.get_basename())
	ids.sort()
	return ids

func level_path(id: String) -> String:
	return "res://data/levels/%s.json" % id

func start_level(id: String) -> void:
	current_level = id
	get_tree().paused = false
	get_tree().change_scene_to_file(GAME)

func next_level_id() -> String:
	var ids := level_ids()
	var i := ids.find(current_level)
	return ids[i + 1] if i >= 0 and i + 1 < ids.size() else ""

func to_menu() -> void:
	get_tree().paused = false
	Sfx.set_thrust(0.0, 0.0)
	get_tree().change_scene_to_file(MENU)

## Entwicklungshilfe: --shot=<png> --frames=<n> macht nach n Frames einen Screenshot und beendet;
## --press=<aktion>@<frame> löst eine Eingabeaktion aus (z. B. pause@20).
var _shot := ""
var _shot_frame := 0
var _presses: Array = []
var _frame := 0

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shot="):
			_shot = a.substr(7)
		elif a.begins_with("--frames="):
			_shot_frame = int(a.substr(9))
		elif a.begins_with("--press="):
			var parts := a.substr(8).split("@")
			_presses.append([parts[0], int(parts[1])])

func _process(_d: float) -> void:
	if _shot == "" and _presses.is_empty():
		return
	_frame += 1
	for p in _presses:
		if p[1] == _frame:
			var ev := InputEventAction.new()
			ev.action = p[0]
			ev.pressed = true
			Input.parse_input_event(ev)
			var up := InputEventAction.new()
			up.action = p[0]
			up.pressed = false
			Input.parse_input_event(up)
	if _shot != "" and _frame == _shot_frame:
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(_shot)
		get_tree().quit()
