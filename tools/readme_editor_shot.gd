extends SceneTree
## Bild des Level-Editors für die README (von tools/make_readme_shots.sh aufgerufen): öffnet ein Original im Editor (nur Ansicht, es wird nichts gespeichert),
## wartet einige Bilder und speichert das Fenster.
## Aufruf: godot --path . -w --resolution 1920x1080 -s tools/readme_editor_shot.gd -- --level-id=s6_05 --out=<pfad.png> [--lang=en]

var n := 0
var menu: Node
var level_id := "s6_05"
var out := ""

func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--level-id="):
			level_id = a.substr(11)
		elif a.begins_with("--out="):
			out = a.substr(6)
	change_scene_to_file("res://src/ui/main_menu.tscn")

func _process(_d: float) -> bool:
	n += 1
	if n == 30:
		menu = current_scene
		var ed: Control = load("res://src/ui/level_editor.gd").new()
		ed.back = func(): pass
		var files = load("res://src/core/level_files.gd")
		ed.model = load("res://src/core/level_edit.gd").from_result(files.clean_of(files.read(level_id)))
		menu._show_screen(ed)
	if n == 70:
		get_root().get_texture().get_image().save_png(out)
		quit()
	return false
