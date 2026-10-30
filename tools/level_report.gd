extends SceneTree
## Aufruf: godot --headless -s tools/level_report.gd
## Gibt Schwierigkeitsmetrik und Bot-Ergebnis (ab Mindest-Sprit) je Level aus.
func _initialize() -> void:
	var dir := DirAccess.open("res://data/levels")
	var files: Array = []
	for f in dir.get_files():
		if f.ends_with(".json"):
			files.append(f)
	files.sort()
	for f in files:
		var lvl := LevelData.load_file("res://data/levels/" + f)
		var m := LevelMetrics.analyze(lvl)
		var r := Bot.fly_level(lvl, 600.0, Tuning.MIN_START_FUEL)
		print("%s  Score %5.1f  Korridor %2.0f px  Strecke %4.0f px  Aufträge %d  schmalstes Pad %3.0f px  Bot: %s %.0f s Tank %.0f%% Jobzeiten %s" % [
			lvl.id, m.score, m.clearance, m.route_len, m.jobs, m.min_pad_w, "OK" if r.complete else "FAIL(" + r.reason + ")", r.time, r.fuel_left,
			str(r.job_times.map(func(t): return snappedf(t, 0.1)))])
	quit()
