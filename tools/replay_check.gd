extends SceneTree
## Aufruf: godot --headless -s tools/replay_check.gd
## Rechnet alle gespeicherten Bestzeit-Replays nach (user://replays/*.json und je Speicherplatz user://replays/s<Platz>/*.json) und vergleicht
## Zeit/Credits mit dem Eintrag. Läufe ohne Feld „rules“ stammen aus Version ≤ 1.0.1 und werden mit deren Regeln nachgerechnet (Replay.LEGACY_RULES).
func _initialize() -> void:
	var bad := 0
	var n := 0
	for slot in [0, 1, 2, 3]:
		var dir := DirAccess.open(Replay.dir_for(slot))
		if dir == null:
			continue
		for f in dir.get_files():
			if not f.ends_with(".json") or f.begins_with("_"):
				continue                      # _day.json: Geist der Tagschicht (nur Spur, kein Bestzeitlauf)
			n += 1
			var d := Replay.load_best(f.get_basename(), slot) if slot > 0 else Replay.load_best(f.get_basename())
			if d.is_empty():
				print("UNGÜLTIG ", Replay.dir_for(slot), f)
				bad += 1
				continue
			var lvl := LevelData.load_file(Flow_path(String(d.level)))
			if lvl == null:
				print("UNGÜLTIG (Level fehlt) ", f)
				bad += 1
				continue
			var res := Replay.play(lvl, d)
			var ok: bool = res.complete and absf(res.time - float(d.result.time)) < 0.001 and absf(res.money - float(d.result.money)) < 0.01
			print("%s %s%s  %.2f s  ¢%d  (%d Ticks, Regelstand %d)" % ["OK  " if ok else "FAIL", "s%d/" % slot if slot > 0 else "", d.level, res.time, int(res.money), res.ticks, int(d.get("rules", Replay.LEGACY_RULES))])
			if not ok:
				bad += 1
	if n == 0:
		print("Keine Replays gespeichert.")
	quit(1 if bad > 0 else 0)

func Flow_path(id: String) -> String:
	return "res://data/levels/%s.json" % String(id).to_lower().replace("-", "_")
