extends SceneTree
## Aufruf: godot --headless -s tools/batch_eval.gd -- [--nobot] pfad1.json pfad2.json ...
## Bewertet Level-Dateien (auch außerhalb von data/levels): Metrik und Bot-Lauf ab Mindest-Sprit. Ausgabe je Datei eine Zeile
## "EVAL|pfad|score|korridor|strecke|fenster|ok|huelle|befoerdert|auftraege|zeit|tank|jobzeiten".
func _initialize() -> void:
	var nobot := false
	for a in OS.get_cmdline_user_args():
		if a == "--nobot":
			nobot = true
			continue
		var lvl := LevelData.load_file(a)
		if lvl == null:
			print("EVAL|%s|ERR" % a)
			continue
		var m := LevelMetrics.analyze(lvl)
		if nobot:
			print("EVAL|%s|%.2f|%.0f|%.0f|%.0f|-|-|-|%d|-|-|[]" % [a, m.score, m.clearance, m.route_len, m.min_window, lvl.jobs.size()])
			continue
		var r := Bot.fly_level(lvl, 360.0, Tuning.MIN_START_FUEL)
		print("EVAL|%s|%.2f|%.0f|%.0f|%.0f|%s|%.0f|%d|%d|%.1f|%.0f|%s" % [a, m.score, m.clearance, m.route_len, m.min_window, "1" if r.complete else "0", r.hull, r.delivered, r.jobs, r.time, r.fuel_left, str(r.job_times.map(func(t): return snappedf(t, 0.1))).replace(" ", "")])
	quit()
