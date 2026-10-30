extends Node
## Einstiegspunkt: Hauptmenü, oder direkt ein Level mit --level=<id> (Entwicklung/Screenshots).

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--level="):
			Flow.current_level = a.substr(8)
			get_tree().change_scene_to_file.call_deferred(Flow.GAME)
			return
	get_tree().change_scene_to_file.call_deferred(Flow.MENU)
