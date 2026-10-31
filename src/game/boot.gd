extends Node
## Einstiegspunkt: Hauptmenü, oder direkt ein Level mit --level=<id> (Entwicklung/Screenshots).

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--scene="):           # Dev: garage | credits | menu direkt öffnen
			get_tree().change_scene_to_file.call_deferred("res://src/ui/%s.tscn" % a.substr(8).replace("menu", "main_menu"))
			return
		if a.begins_with("--level="):
			Flow.current_level = Flow.resolve_level(a.substr(8))
			get_tree().change_scene_to_file.call_deferred(Flow.GAME)
			return
	get_tree().change_scene_to_file.call_deferred(Flow.MENU)
