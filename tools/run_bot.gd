extends SceneTree
## Aufruf: godot --headless -s tools/run_bot.gd [-- level_id ...]
## Fliegt jedes Level (oder die angegebenen) mit dem Autopiloten und meldet das Ergebnis.

func _initialize() -> void:
	var wanted := OS.get_cmdline_user_args()
	var dir := DirAccess.open("res://data/levels")
	var files: Array = []
	for f in dir.get_files():
		if f.ends_with(".json"):
			files.append(f)
	files.sort()
	var bad := 0
	for f in files:
		if not wanted.is_empty() and not wanted.has(f.get_basename()):
			continue
		var lvl := LevelData.load_file("res://data/levels/" + f)
		var r := Bot.fly_level(lvl)
		var status := "OK  " if r.complete else "FAIL"
		if not r.complete:
			bad += 1
		print("%s %s  Zeit %.1fs  Tank %.0f%%  Hülle %.0f%%  Fahrten %d/%d  ¢%d  %s" % [status, lvl.id, r.time, r.fuel_left, r.hull, r.delivered, r.jobs, int(r.money), r.reason])
	quit(1 if bad > 0 else 0)
