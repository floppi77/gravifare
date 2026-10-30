extends SceneTree
## Aufruf: godot --headless -s tools/replay_check.gd
## Rechnet alle gespeicherten Bestzeit-Replays (user://replays/*.json) nach und vergleicht Zeit/Credits mit dem Eintrag.
func _initialize() -> void:
	var dir := DirAccess.open(Replay.DIR)
	if dir == null:
		print("Keine Replays gespeichert.")
		quit()
		return
	var bad := 0
	for f in dir.get_files():
		if not f.ends_with(".json"):
			continue
		var d := Replay.load_best(f.get_basename())
		if d.is_empty():
			print("UNGÜLTIG ", f)
			bad += 1
			continue
		var lvl := LevelData.load_file(Flow_path(String(d.level)))
		var res := Replay.play(lvl, d)
		var ok: bool = res.complete and absf(res.time - float(d.result.time)) < 0.001 and absf(res.money - float(d.result.money)) < 0.01
		print("%s %s  %.2f s  ¢%d  (%d Ticks)" % ["OK  " if ok else "FAIL", d.level, res.time, int(res.money), res.ticks])
		if not ok:
			bad += 1
	quit(1 if bad > 0 else 0)

func Flow_path(id: String) -> String:
	return "res://data/levels/%s.json" % id
