extends SceneTree
## Aufruf: godot --headless -s tools/make_replay_fixtures.gd [-- <Zielordner>]
## Zeichnet Autopilot-Läufe mit Zusatzfahrgästen, Startkapital und Mindest-Sprit als Replays auf (Format wie im Spiel, `Replay.to_dict`).
## Einmal mit dem Regelstand 1.0.1 erzeugt liegen sie in tests/fixtures/replays_v2/: Der Test `_test_old_replays_valid` prüft, dass solche
## alten Läufe (Bestzeiten, Geister) nach Regeländerungen weiter exakt nachgerechnet werden.

const LEVELS := ["s1_06", "s2_04", "s3_05", "s4_03", "s5_02", "s6_02", "s7_04", "s8_05"]

func _initialize() -> void:
	var out := "res://tests/fixtures/replays_v2/"
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		out = args[0]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out))
	for id in LEVELS:
		var lvl := LevelData.load_file("res://data/levels/%s.json" % id)
		var seed := 4242 + lvl.number * 7919
		var credits := 2500.0
		var r := Run.new()
		r.extras_enabled = true
		r.start(lvl, Tuning.MIN_START_FUEL, credits, seed)
		var bot := Bot.new(r, false)
		var rep := Replay.new()
		rep.begin(lvl.id, seed, Tuning.MIN_START_FUEL, credits, {}, true)
		for i in int(400.0 / Tuning.TICK):
			var cmd := bot.decide()
			var inp: Vector2 = Replay.quantize(cmd[0])
			rep.add(inp, cmd[1])
			r.step(inp, cmd[1])
			if r.result != Run.Result.RUNNING:
				break
		rep.finish({"complete": r.result == Run.Result.COMPLETE, "time": r.level_time, "money": r.money, "earned": r.earned, "delivered": r.delivered})
		var d := rep.to_dict()
		var f := FileAccess.open(out + id + ".json", FileAccess.WRITE)
		f.store_string(JSON.stringify(d))
		f.close()
		print("%s  fertig=%s  %.2f s  ¢%.2f  verdient %.2f  befördert %d" % [id, d.result.complete, r.level_time, r.money, r.earned, r.delivered])
	quit()
