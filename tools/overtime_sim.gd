extends SceneTree
## Wirtschaft der Sonderschicht grob prüfen: Der Autopilot fliegt ganze Läufe (ohne Zusatzfahrgäste, also vorsichtig gerechnet), wählt an jeder
## Kreuzung nach einer Strategie und kauft im Halt die günstigsten Teile, die er sich leisten kann. Ausgabe je Lauf: Guthaben an jedem Halt,
## gekaufte Teile, Etappenpunkte und Endwertung.
##
## Aufruf: godot --headless -s tools/overtime_sim.gd -- [short|medium|long] [calm|risky|mixed] [Anzahl Seeds]

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var length := String(args[0]) if args.size() > 0 else "short"
	var policy := String(args[1]) if args.size() > 1 else "mixed"
	var n := int(args[2]) if args.size() > 2 else 3
	var ids: Array = []
	for f in DirAccess.get_files_at("res://data/levels"):
		if f.ends_with(".json"):
			ids.append(f.get_basename())
	ids.sort()
	for k in n:
		_run(1000 + k * 7919, length, policy, ids)
	quit()

func _run(seed: int, length: String, policy: String, ids: Array) -> void:
	var st := Overtime.new_run(seed, length, "standard", 0, {"xp": 3000})
	var lives := int(st.lives)
	var halts: Array = []
	var bought: Array = []
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	while not Overtime.is_last(st) and lives > 0:
		var os := Overtime.offers(st, ids)
		var pick := 0
		match policy:
			"risky":
				pick = os.size() - 1
			"mixed":
				pick = rng.randi() % os.size()
		Overtime.choose(st, os[pick])
		var lvl := LevelData.load_file("res://data/levels/%s.json" % String(st.level))
		var fx := Overtime.effects(st)
		if float(fx.newroute) > 0.0:
			var jr := RandomNumberGenerator.new()
			jr.seed = seed
			lvl.jobs = Run.chain_jobs(lvl, maxi(2, lvl.jobs.size() - 1), jr)
		var r := Run.new()
		r.rules = Run.RULES
		r.ot = Overtime.run_mods(fx)
		r.patience_k = float(fx.patience_k)
		r.fuel_cap = Tuning.FUEL_MAX * float(fx.fuel_cap)
		r.extras_enabled = false
		r.start(lvl, float(st.fuel), float(st.credits), seed + int(st.etappe))
		r.sim.apply_mods(Overtime.sim_mods(fx, int(st.angel)))
		var bot := Bot.new(r)
		for i in int(600.0 / Tuning.TICK):
			var cmd := bot.decide()
			r.step(Replay.quantize(cmd[0]), cmd[1])
			if r.result != Run.Result.RUNNING:
				break
		if r.result != Run.Result.COMPLETE:
			lives -= 1                                          # grob: Etappe verloren, ein Taxi weniger, weiter mit der nächsten Kreuzung
			st.lives = lives
			st.credits = r.money
			st.etappe = int(st.etappe) + 1
			st.phase = "halt" if int(st.etappe) % Overtime.HALT_EVERY == 0 and not Overtime.is_last(st) else "cross"
			st.curses = []
			st.offer = {}
			if st.phase == "halt":
				st.halts = int(st.halts) + 1
			print("  Etappe %d %s: verloren (%s)" % [int(st.etappe), lvl.id, r.result])
		else:
			var score := r.level_score()
			var med := r.medals()
			var stars := int(med.time) + int(med.clean) + int(med.pro)
			Overtime.etappe_done(st, {"points": score, "bonus": 150 * stars, "credits": r.money, "fuel": maxf(Tuning.MIN_START_FUEL, r.sim.fuel), "lives": lives, "streak": r.streak, "angel": r.sim.angel})
		if String(st.phase) == "halt":
			var before := float(st.credits)
			var got: Array = []
			var tries := 0
			while tries < 8:
				tries += 1
				var items: Array = Overtime.shop(st)
				var best := -1
				for i in items.size():
					if not bool(items[i].sold) and Overtime.price(st, String(items[i].id)) <= float(st.credits) and (best < 0 or Overtime.price(st, String(items[i].id)) < Overtime.price(st, String(items[best].id))):
						best = i
				if best < 0 or not Overtime.buy(st, best):
					break
				got.append(String(items[best].id))
			halts.append("Halt %d (Sektor %d): ¢%d → %s" % [int(st.halts), Overtime.shop_sector(st), int(before), ", ".join(got) if not got.is_empty() else "nichts"])
			bought.append_array(got)
			Overtime.leave_halt(st)
	if lives <= 0:
		Overtime.fail(st, float(st.credits))
	else:
		st.done = true
	var f := Overtime.final(st)
	print("Seed %s %s/%s: %d/%d Etappen, Taxis %d, ¢%d, Punkte %d (Etappen %d), Teile %d" % [Overtime.code_of(seed), length, policy, int(f.flown), int(f.of), lives, int(st.credits), int(f.total), int(f.etappen), bought.size()])
	for h in halts:
		print("  " + h)
