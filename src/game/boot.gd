extends Node
## Einstiegspunkt: wechselt in die Spielszene (später: Hauptmenü).

func _ready() -> void:
	get_tree().change_scene_to_file.call_deferred("res://src/game/game.tscn")
