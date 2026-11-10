extends SceneTree
## Aufruf: LV=s4_01,s4_02 godot --headless -s tools/levelmarks/measure_jobs.gd
## Misst je Auftrag, wie lange der Autopilot (ab Mindest-Sprit wie im Testläufer) braucht: Wartezeit bis zum Einsteigen und Zeit vom Erscheinen
## bis zum Absetzen, dazu die Richtzeit. Grundlage für die Auswahl der VIP- und Notfall-Aufträge (tools/levelmarks/mark_levels.py).
const OVR := {"s4_05": 38.0, "s8_08": 38.0, "s9_05": 40.0, "s5_11": 45.0, "s5_08": 50.0, "s9_06": 42.0, "s3_08": 38.0, "s7_01": 38.0, "s3_04": 50.0}
func _initialize() -> void:
	for id in OS.get_environment("LV").split(","):
		var lvl := LevelData.load_file("res://data/levels/%s.json" % id)
		var r := Run.new()
		r.extras_enabled = false
		r.start(lvl, float(OVR.get(id, Tuning.MIN_START_FUEL)))
		var bot := Bot.new(r, false)
		var rec := {}
		var last_phase := r.phase
		for i in int(600.0 / Tuning.TICK):
			var cmd := bot.decide()
			var ji := r.job_index
			var clock := r.job_clock
			var wait := r.main_wait
			r.step(Replay.quantize(cmd[0]), cmd[1])
			if r.phase != last_phase and r.job_index == ji:
				var e: Dictionary = rec.get(ji, {})
				if r.phase == Run.Phase.BOARDING and not e.has("wait"):
					e["wait"] = snappedf(wait, 0.1)
				if r.phase == Run.Phase.DROPOFF and not e.has("drop"):
					e["drop"] = snappedf(r.job_clock, 0.1)
				rec[ji] = e
			for ev in r.log:
				if ev.type == "job_missed":
					var e2: Dictionary = rec.get(ji, {})
					e2["missed"] = true
					rec[ji] = e2
			last_phase = r.phase
			if r.result != Run.Result.RUNNING:
				break
		var jobs: Array = []
		for k in r.jobs.size():
			var j: Dictionary = r.jobs[k]
			var e3: Dictionary = rec.get(k, {})
			jobs.append({"i": k, "from": j.from, "to": j.to, "par": r.par_of(j), "fragile": bool(j.get("fragile", false)), "exit": r.is_exit_job(j),
				"wait": e3.get("wait", -1.0), "drop": e3.get("drop", -1.0), "missed": e3.get("missed", false)})
		print("JOBS ", JSON.stringify({"id": id, "number": lvl.number, "complete": r.result == Run.Result.COMPLETE, "jobs": jobs}))
	quit()
