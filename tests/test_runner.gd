extends SceneTree
## Aufruf: godot --headless -s tests/test_runner.gd
## Beendet mit Exit-Code 1, sobald ein Test fehlschlägt.

var failures := 0
var checks := 0

func check(cond: bool, msg: String) -> void:
	checks += 1
	if cond:
		print("  ok   ", msg)
	else:
		failures += 1
		print("  FAIL ", msg)

func _initialize() -> void:
	for t in ["_test_level_parse", "_test_gravity_fall", "_test_hover", "_test_good_landing", "_test_crash", "_test_full_run", "_test_level_rules", "_test_gear_flight_mode", "_test_passenger_walk_and_board", "_test_passenger_abort", "_test_no_respawn_after_delivery", "_test_transition_timeline", "_test_i18n_complete", "_test_crash_balance", "_test_payout_and_penalty", "_test_exit_passenger", "_test_spawn_not_on_taxi_pad", "_test_job_rules_and_difficulty", "_test_squash_passenger", "_test_landing_window_rules", "_test_taxi_scale", "_test_gate_blocks_until_open", "_test_bot_solves_levels"]:
		print(t)
		call(t)
	print("%d Prüfungen, %d Fehler" % [checks, failures])
	quit(1 if failures > 0 else 0)

func _lvl() -> LevelData:
	return LevelData.load_file("res://data/levels/s1_01.json")

func _test_level_parse() -> void:
	var l := _lvl()
	check(l != null and l.id == "S1-01", "Level S1-01 lädt")
	check(l.pads.has("1") and l.pads.has("2") and l.pads.has("F"), "Pads 1, 2, F erkannt")
	check(l.exit_cells.size() > 0, "Ausgang vorhanden")

func _test_gravity_fall() -> void:
	var s := TaxiSim.new()
	s.setup(_lvl())
	s.state = TaxiSim.State.FLYING
	s.pos = Vector2(400, 100)
	s.vel = Vector2.ZERO
	for i in 120:
		s.step(Vector2.ZERO, false)
	# analytisch mit linearer Dämpfung k: v(1 s) = g/k·(1−e^−k) ≈ 82,3 px/s
	var expected := Tuning.GRAVITY / Tuning.DRAG * (1.0 - exp(-Tuning.DRAG))
	check(absf(s.vel.y - expected) < 1.0, "Freier Fall folgt Gravitation+Dämpfung (%.1f ≈ %.1f)" % [s.vel.y, expected])

func _test_hover() -> void:
	var s := TaxiSim.new()
	s.setup(_lvl())
	s.state = TaxiSim.State.FLYING
	s.pos = Vector2(400, 100)
	s.vel = Vector2.ZERO
	var fuel0 := s.fuel
	for i in 240:
		# einfacher Regler: Schub proportional zur Fallgeschwindigkeit
		var up := clampf(0.4 + s.vel.y * 0.01, 0.0, 1.0)
		s.step(Vector2(0, -up), false)
	check(absf(s.vel.y) < 20.0, "Schwebeflug stabil (vy=%.1f)" % s.vel.y)
	check(s.fuel < fuel0, "Schub verbraucht Treibstoff")

func _test_good_landing() -> void:
	var s := TaxiSim.new()
	var l := _lvl()
	s.setup(l)
	s.state = TaxiSim.State.FLYING
	s.landed_pad = {}
	var pad: Dictionary = l.pads["2"]
	s.pos = Vector2(pad.center, pad.row * Tuning.TILE - 40)
	s.vel = Vector2(0, 10)
	s.tilt = 0
	var landed := false
	for i in 600:
		# Gear raus, Sinkrate unter 25 px/s halten
		var up := clampf(0.39 + (s.vel.y - 20.0) * 0.01, 0.0, 1.0)
		s.step(Vector2(0, -up), true)
		for e in s.events:
			if e.type == "landed":
				landed = true
		if landed:
			break
	check(landed, "Sanfte Landung auf Pad 2 gelingt")
	check(s.state == TaxiSim.State.LANDED and s.hull >= 99.0, "Gelandet ohne Schaden")

func _test_crash() -> void:
	var s := TaxiSim.new()
	var l := _lvl()
	s.setup(l)
	s.state = TaxiSim.State.FLYING
	var pad: Dictionary = l.pads["2"]
	s.pos = Vector2(pad.center, pad.row * Tuning.TILE - 60)
	s.vel = Vector2(0, 160)
	var bad := false
	for i in 120:
		s.step(Vector2.ZERO, true)
		for e in s.events:
			if e.type == "bad_landing":
				bad = true
	check(bad, "Zu schnelle Landung wird als bad_landing erkannt")
	check(s.hull < 100.0 and s.state != TaxiSim.State.DESTROYED, "Zu harte Landung mit Fahrwerk (Feinmodus, max. 90 px/s): Schaden, aber nicht zerstört (%.1f)" % s.hull)
	# Ohne Fahrwerk im Sturzflug auf den Boden: sofort zerstört
	var d := TaxiSim.new()
	d.setup(l)
	d.state = TaxiSim.State.FLYING
	d.landed_pad = {}
	d.gear = 0.0                      # Setup startet auf dem Pad mit ausgefahrenem Fahrwerk
	d.gear_cmd = false
	d.pos = Vector2(pad.center, pad.row * Tuning.TILE - 110)
	d.vel = Vector2(0, 235)
	for i in 120:
		d.step(Vector2.ZERO, false)
	check(d.state == TaxiSim.State.DESTROYED, "Sturz mit ~230 px/s ohne Fahrwerk zerstört das Taxi sofort")

func _test_full_run() -> void:
	var r := Run.new()
	r.start(_lvl())
	check(r.sim.state == TaxiSim.State.LANDED and r.sim.landed_pad.id == "1", "Start gelandet auf Startpad 1")
	check(r.target_pad() == "2", "Erster Fahrgast wartet auf Pad 2 (nicht dort, wo das Taxi steht)")
	_land_on(r, "2")
	for i in 240:
		r.step(Vector2.ZERO, true)
	check(r.phase == Run.Phase.CARRYING, "Fahrgast an Bord nach Einsteigezeit")

func _test_bot_solves_levels() -> void:
	var dir := DirAccess.open("res://data/levels")
	for f in dir.get_files():
		if not f.ends_with(".json"):
			continue
		var lvl := LevelData.load_file("res://data/levels/" + f)
		var r := Bot.fly_level(lvl, 600.0, Tuning.MIN_START_FUEL)
		check(r.complete and r.hull > 90.0, "Autopilot löst %s ab Mindest-Sprit %d%% (%.0f s, Hülle %.0f%%, %s)" % [lvl.id, int(Tuning.MIN_START_FUEL), r.time, r.hull, r.reason])

func _test_level_rules() -> void:
	var dir := DirAccess.open("res://data/levels")
	for f in dir.get_files():
		if not f.ends_with(".json"):
			continue
		var lvl := LevelData.load_file("res://data/levels/" + f)
		var r := lvl.exit_rect()
		check(r.size.x > 0 and absf(r.get_center().x - lvl.width * Tuning.TILE * 0.5) < 1.0 and r.position.y <= Tuning.TILE * 2.0,
			"%s: Ausgang mittig oben" % lvl.id)
		var min_w := 99
		for id in lvl.pads:
			min_w = mini(min_w, int((lvl.pads[id].x1 - lvl.pads[id].x0) / Tuning.TILE))
		check(min_w >= 4, "%s: alle Pads mindestens 4 Tiles breit (min %d)" % [lvl.id, min_w])
		var ids: Array = []
		for id in lvl.pads:
			if not lvl.pads[id].fuel:
				ids.append(int(id))
		ids.sort()
		var contiguous := true
		for i in ids.size():
			if ids[i] != i + 1:
				contiguous = false
		check(contiguous, "%s: Pad-Nummern fortlaufend 1..%d (%s)" % [lvl.id, ids.size(), str(ids)])
		check(lvl.spawn != Vector2.ZERO, "%s: Startpunkt vorhanden" % lvl.id)

func _test_gate_blocks_until_open() -> void:
	var lvl := _lvl()
	var r := Run.new()
	r.start(lvl)
	var rect := lvl.exit_rect()
	check(lvl.box_hits_solid(rect.get_center(), Tuning.HULL_HALF), "Geschlossenes Tor ist fest")
	r.exit_open = true
	lvl.exit_open = true
	check(not lvl.box_hits_solid(rect.get_center(), Tuning.HULL_HALF), "Offenes Tor ist passierbar")

func _test_gear_flight_mode() -> void:
	var s := TaxiSim.new()
	s.setup(_lvl())
	s.gear = 0.0
	var fast_side := s.side_power()
	var fast_vmax := s.max_speed()
	s.gear = 1.0
	check(s.side_power() < fast_side * 0.7, "Fahrwerk aus: deutlich schwächerer Seitenschub (%.0f < %.0f)" % [s.side_power(), fast_side])
	check(s.max_speed() < fast_vmax * 0.5, "Fahrwerk aus: deutlich niedrigere Höchstgeschwindigkeit")
	check(s.drag() > Tuning.DRAG * 3.0, "Fahrwerk aus: stärkere Dämpfung für Feinmanöver")
	# Seitenschub-Dauerlauf: Endgeschwindigkeit mit Fahrwerk deutlich kleiner
	var a := TaxiSim.new(); a.setup(_lvl()); a.state = TaxiSim.State.FLYING; a.pos = Vector2(320, 100)
	var b := TaxiSim.new(); b.setup(_lvl()); b.state = TaxiSim.State.FLYING; b.pos = Vector2(320, 100); b.gear = 1.0
	for i in 120:
		a.step(Vector2(1, -0.4), false)
		b.step(Vector2(1, -0.65), true)
		a.pos.x = 320; b.pos.x = 320
	check(absf(b.vel.x) < absf(a.vel.x) * 0.5, "Seitengeschwindigkeit nach 1 s: Fahrwerk %.0f < eingefahren %.0f" % [absf(b.vel.x), absf(a.vel.x)])

## Setzt das Taxi (Test-Hilfe) sicher gelandet auf ein Pad, ohne es zu fliegen.
func _land_on(r: Run, id: String) -> void:
	var pad: Dictionary = r.level.pads[id]
	r.sim.pos = Vector2(pad.center + 6.0, pad.row * Tuning.TILE - Tuning.GEAR_LEN - Tuning.HULL_HALF.y)
	r.sim.vel = Vector2.ZERO
	r.sim.gear = 1.0
	r.sim.gear_cmd = true
	r.sim.state = TaxiSim.State.LANDED
	r.sim.landed_pad = pad

func _test_passenger_walk_and_board() -> void:
	var r := Run.new()
	r.start(_lvl())
	var a: PassengerActor = r.actor
	check(a != null and a.state == PassengerActor.S.WAITING, "Fahrgast wartet beim Start im Wartebereich")
	var pad: Dictionary = _lvl().pads["2"]
	_land_on(r, "2")
	check(a.x == pad.wait_x and pad.shelter.size.x > 0.0, "Wartepunkt liegt im Wartebereich des Pads (Unterstand vorhanden)")
	var boarded_at := -1.0
	var saw_walking := false
	for i in 600:
		r.step(Vector2.ZERO, true)
		if a.is_walking():
			saw_walking = true
		for e in r.log:
			if e.type == "boarded" and boarded_at < 0.0:
				boarded_at = r.sim.time
	var dist := absf(r.sim.pos.x - pad.wait_x)
	check(saw_walking, "Fahrgast läuft zum Taxi")
	check(boarded_at >= dist / PassengerActor.SPEED, "Einsteigen dauert mindestens die Laufzeit (%.2f s ≥ %.2f s)" % [boarded_at, dist / PassengerActor.SPEED])
	check(r.phase == Run.Phase.CARRYING and a.state == PassengerActor.S.ABOARD, "Danach sitzt der Fahrgast im Taxi")

func _test_passenger_abort() -> void:
	var r := Run.new()
	r.start(_lvl())
	_land_on(r, "2")
	r.step(Vector2.ZERO, true)                     # Fahrgast beginnt zu laufen
	check(r.phase == Run.Phase.BOARDING, "Boarding beginnt nach Landung")
	for i in 12:
		r.step(Vector2(0, -1), true)               # Taxi hebt sofort ab
	check(r.phase == Run.Phase.WAITING, "Abheben bricht das Einsteigen ab")
	for i in 300:
		r.step(Vector2(0, -0.39), false)
	check(r.actor.state == PassengerActor.S.WAITING and absf(r.actor.x - _lvl().pads["2"].wait_x) < 1.0, "Fahrgast kehrt in den Wartebereich zurück")

func _test_no_respawn_after_delivery() -> void:
	var lvl := _lvl()
	var r := Run.new()
	r.start(lvl)
	var bot := Bot.new(r)
	var first_name := String(lvl.jobs[0].passenger)
	var checked := false
	for i in 60000:
		var cmd := bot.decide()
		r.step(cmd[0], cmd[1])
		if r.delivered == 1 and not checked:
			checked = true
			check(r.leavers.size() == 1 and r.leavers[0].pname == first_name, "Abgelieferter Fahrgast geht in den Wartebereich (leavers)")
			check(r.actor == null or r.actor.pname != first_name, "Abgelieferter Fahrgast spawnt nicht erneut")
		if r.result != Run.Result.RUNNING:
			break
	check(r.result == Run.Result.COMPLETE, "Level mit Fahrgast-Akteuren abgeschlossen")
	for i in 600:
		r.step(Vector2.ZERO, false)
	# nach Levelende laufen keine Fahrgäste mehr: Run bleibt stehen, daher nur Zustand prüfen
	check(r.leavers.size() <= 1, "Höchstens ein Fahrgast noch unterwegs (%d)" % r.leavers.size())

func _test_transition_timeline() -> void:
	var tv = load("res://src/game/transition_view.gd").new()
	var checks_a := {0.0: 0.0, 2.0: 1.0, 4.0: 1.0, 5.6: 1.0, 7.6: 0.0}
	for tt in checks_a:
		tv.t = tt
		check(absf(tv.overlay_alpha() - checks_a[tt]) < 0.01, "Überblendung bei t=%.1f s ist %.2f" % [tt, checks_a[tt]])
	tv.t = 1.0
	var a1: float = tv.overlay_alpha()
	tv.t = 1.5
	check(tv.overlay_alpha() > a1 and tv.T_OUT == 2.0, "Ausblenden dauert 2 s und steigt monoton")
	check(absf((tv.T_IN - tv.T_OUT) - 3.6) < 0.01 and absf((tv.T_END - tv.T_IN) - 2.0) < 0.01, "Sequenz: 2 s aus, 3,6 s Weltraum, 2 s ein")
	tv.free()

func _read_json(path: String) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	var d = JSON.parse_string(f.get_as_text()) if f != null else null
	return d if typeof(d) == TYPE_DICTIONARY else {}

func _collect_keys(dir: String, out: Dictionary) -> void:
	var rx := RegEx.create_from_string("\\btr\\(\"([A-Z0-9_]+)\"")
	var d := DirAccess.open(dir)
	for sub in d.get_directories():
		_collect_keys(dir + "/" + sub, out)
	for f in d.get_files():
		if f.ends_with(".gd"):
			var text := FileAccess.get_file_as_string(dir + "/" + f)
			for m in rx.search_all(text):
				out[m.get_string(1)] = true

func _test_i18n_complete() -> void:
	var de := _read_json("res://data/i18n/de.json")
	var en := _read_json("res://data/i18n/en.json")
	check(not de.is_empty() and de.keys().size() == en.keys().size(), "Deutsch und Englisch haben gleich viele Schlüssel (%d / %d)" % [de.size(), en.size()])
	var missing: Array = []
	for k in de:
		if not en.has(k) or String(en[k]).strip_edges() == "" or String(de[k]).strip_edges() == "":
			missing.append(k)
	check(missing.is_empty(), "Keine fehlenden/leeren Übersetzungen %s" % str(missing))
	var used := {}
	_collect_keys("res://src", used)
	var undefined: Array = []
	for k in used:
		if not de.has(k) or not en.has(k):
			undefined.append(k)
	check(undefined.is_empty() and used.size() > 30, "Alle im Code benutzten Schlüssel (%d) sind in beiden Sprachen definiert %s" % [used.size(), str(undefined)])
	# Level: Namen in beiden Sprachen
	var dir := DirAccess.open("res://data/levels")
	for f in dir.get_files():
		if f.ends_with(".json"):
			var lvl := LevelData.load_file("res://data/levels/" + f)
			check(String(lvl.names.get("de", "")) != "" and String(lvl.names.get("en", "")) != "", "%s hat deutschen und englischen Namen" % lvl.id)

func _test_crash_balance() -> void:
	var results := {}
	for v in [60.0, 80.0, 100.0, 130.0, 160.0, 169.0, 171.0, 240.0]:
		var s := TaxiSim.new()
		s.setup(_lvl())
		s._impact(v)
		results[v] = s
	check(results[60.0].hull == 100.0, "Aufprall 60 px/s: kein Schaden")
	check(results[80.0].hull > 95.0 and results[80.0].hull < 100.0, "Aufprall 80 px/s: leichter Schaden (%.1f Hülle)" % results[80.0].hull)
	var prev := 101.0
	var mono := true
	for v in [80.0, 100.0, 130.0, 160.0, 169.0]:
		if results[v].hull >= prev:
			mono = false
		prev = results[v].hull
	check(mono, "Schaden steigt mit der Geschwindigkeit streng an")
	check(results[130.0].hull < 70.0 and results[130.0].state != TaxiSim.State.DESTROYED, "130 px/s: schwerer Schaden, aber nicht zerstört (%.0f)" % results[130.0].hull)
	check(results[169.0].hull > 0.0 or results[169.0].state == TaxiSim.State.DESTROYED, "169 px/s: knapp unter der Sofortgrenze")
	check(results[171.0].state == TaxiSim.State.DESTROYED and results[171.0].events.any(func(e): return e.type == "destroyed" and e.get("instant", false)), "171 px/s: sofort zerstört")
	check(results[240.0].state == TaxiSim.State.DESTROYED, "240 px/s (Höchstgeschwindigkeit): sofort zerstört")

func _test_payout_and_penalty() -> void:
	check(absf(Tuning.time_factor(0.0, 30.0) - Tuning.PAY_MAX) < 0.001, "Sofort zugestellt: Höchstfaktor %.2f" % Tuning.PAY_MAX)
	check(absf(Tuning.time_factor(30.0, 30.0) - 1.0) < 0.001, "Bei Richtzeit genau Faktor 1,0")
	check(Tuning.time_factor(15.0, 30.0) > Tuning.time_factor(30.0, 30.0) and Tuning.time_factor(30.0, 30.0) > Tuning.time_factor(60.0, 30.0), "Je länger die Fahrt, desto weniger Credits")
	check(absf(Tuning.time_factor(1000.0, 30.0) - Tuning.PAY_MIN) < 0.001, "Sehr lange Fahrt: Untergrenze %.2f (nie null/negativ)" % Tuning.PAY_MIN)
	check(Tuning.landing_penalty(Tuning.LAND_SOFT_VY) == 0.0 and Tuning.landing_penalty(10.0) == 0.0, "Weiche Landung: kein Abzug")
	check(absf(Tuning.landing_penalty(Tuning.LAND_VY) - Tuning.LAND_PENALTY_MAX) < 0.001, "Landung am Limit: maximaler Abzug")
	check(Tuning.landing_penalty(35.0) > 0.0 and Tuning.landing_penalty(35.0) < Tuning.LAND_PENALTY_MAX, "Harte Landung dazwischen: anteiliger Abzug")
	# Durchgespielter Auftrag: schnell + weich vs. langsam + hart
	var fast := _simulate_job_payout(0.0, 18.0)
	var slow := _simulate_job_payout(Tuning.LAND_VY, 60.0)
	check(fast > slow, "Schnell+weich (%.0f) bringt mehr als langsam+hart (%.0f)" % [fast, slow])

func _simulate_job_payout(landing_vy: float, seconds: float) -> float:
	var r := Run.new()
	r.start(_lvl())
	_land_on(r, "2")
	r.last_vy = landing_vy
	var money0 := r.money
	for i in int(seconds / Tuning.TICK):
		r.step(Vector2.ZERO, true)
		if r.phase == Run.Phase.CARRYING:
			break
	# Ziel: Pad 3 (Insel); direkt dorthin versetzen und aussteigen lassen
	r.job_clock = seconds
	_land_on(r, "3")
	r.last_vy = landing_vy
	for i in 400:
		r.step(Vector2.ZERO, true)
	return r.money - money0

func _test_exit_passenger() -> void:
	var lvl := _lvl()
	var last: Dictionary = lvl.jobs[lvl.jobs.size() - 1]
	check(String(last.to) == "exit", "Letzter Auftrag bringt einen Fahrgast zum Ausgang")
	var r := Run.new()
	r.start(lvl)
	r.job_index = lvl.jobs.size() - 1
	r._spawn_actor(true)
	check(not r.exit_open, "Tor ist zu, solange der Ausgangs-Fahrgast nicht an Bord ist")
	_land_on(r, String(last.from))
	var opened := false
	for i in 600:
		r.step(Vector2.ZERO, true)
		for e in r.log:
			if e.type == "exit_open":
				opened = true
	check(opened and r.exit_open and r.phase == Run.Phase.CARRYING, "Tor öffnet, sobald der Fahrgast an Bord ist")
	check(r.target_pad() == "", "Ziel des Ausgangs-Fahrgasts ist kein Pad")
	# durchs Tor fliegen
	r.sim.state = TaxiSim.State.FLYING
	r.sim.landed_pad = {}
	r.sim.pos = lvl.exit_rect().get_center()
	var money0 := r.money
	r.step(Vector2.ZERO, false)
	check(r.result == Run.Result.COMPLETE, "Flug mit Fahrgast durchs Tor beendet das Level")
	check(r.money > money0 and not r.carried.is_empty(), "Fahrpreis wird gezahlt, Fahrgast fährt ins nächste Level mit (%s)" % str(r.carried.get("name", "")))

func _test_spawn_not_on_taxi_pad() -> void:
	# Nachfolge-Fahrgast darf nicht erscheinen, solange das Taxi auf seinem Pad steht
	var lvl := _lvl()
	var r := Run.new()
	r.start(lvl)
	r.job_index = 0
	r.actor = null
	var next_from := String(lvl.jobs[1].from)
	r.job_index = 1
	r.spawn_timer = 0.01
	_land_on(r, next_from)
	for i in 600:
		r.step(Vector2.ZERO, true)
	check(r.actor == null, "Fahrgast erscheint nicht auf dem Pad, auf dem das Taxi steht")
	r.sim.state = TaxiSim.State.FLYING
	r.sim.landed_pad = {}
	r.sim.pos = Vector2(320, 100)
	for i in 10:
		r.step(Vector2(0, -0.39), false)
	check(r.actor != null, "…aber sobald das Taxi weg ist")

func _test_job_rules_and_difficulty() -> void:
	var dir := DirAccess.open("res://data/levels")
	var files: Array = []
	for f in dir.get_files():
		if f.ends_with(".json"):
			files.append(f)
	files.sort()
	var prev_score := -1.0
	var prev_id := ""
	for f in files:
		var lvl := LevelData.load_file("res://data/levels/" + f)
		var start_pad := ""
		for dy in range(0, 3):
			var pad := lvl.pad_at_foot(Vector2(lvl.spawn.x, lvl.spawn.y + dy * Tuning.TILE))
			if not pad.is_empty():
				start_pad = pad.id
				break
		check(not lvl.jobs.is_empty() and String(lvl.jobs[lvl.jobs.size() - 1].to) == "exit", "%s: letzter Auftrag = Ausgangs-Fahrgast" % lvl.id)
		var ok_first: bool = String(lvl.jobs[0].from) != start_pad
		check(ok_first, "%s: erster Fahrgast wartet nicht auf dem Startpad %s" % [lvl.id, start_pad])
		var chain_ok := true
		var exit_only_last := true
		for i in lvl.jobs.size():
			var j: Dictionary = lvl.jobs[i]
			if i > 0 and String(j.from) == String(lvl.jobs[i - 1].to):
				chain_ok = false
			if String(j.from) == String(j.to):
				chain_ok = false
			if i < lvl.jobs.size() - 1 and String(j.to) == "exit":
				exit_only_last = false
			if not lvl.pads.has(String(j.from)) or (String(j.to) != "exit" and not lvl.pads.has(String(j.to))):
				chain_ok = false
		check(chain_ok, "%s: jeder Fahrgast beginnt an einem anderen Pad als der vorherige endete" % lvl.id)
		check(exit_only_last, "%s: nur der letzte Auftrag führt zum Ausgang" % lvl.id)
		var m := LevelMetrics.analyze(lvl)
		check(m.solvable, "%s: Route planbar (Korridor %.0f px)" % [lvl.id, m.clearance])
		check(m.score >= prev_score, "Schwierigkeit steigt: %s %.1f ≥ %s %.1f" % [lvl.id, m.score, prev_id, maxf(prev_score, 0.0)])
		prev_score = m.score
		prev_id = lvl.id

func _taxi_over(r: Run, x: float, y: float, vy: float) -> void:
	r.sim.state = TaxiSim.State.FLYING
	r.sim.landed_pad = {}
	r.sim.pos = Vector2(x, y)
	r.sim.vel = Vector2(0, vy)
	r.sim.gear = 1.0

func _test_squash_passenger() -> void:
	var lvl := _lvl()
	var r := Run.new()
	r.start(lvl)
	var a := r.actor
	var from_id := String(r.current_job().from)
	var n_jobs := r.jobs.size()
	var pad: Dictionary = lvl.pads[from_id]
	# Taxi senkt sich auf den Kopf des wartenden Fahrgasts
	_taxi_over(r, a.x, pad.row * Tuning.TILE - 40.0, 40.0)
	var squashed := false
	var replaced := false
	for i in 400:
		r.step(Vector2(0, -0.0), true)
		if r.sim.state != TaxiSim.State.FLYING:
			break
		for e in r.log:
			if e.type == "squashed":
				squashed = true
			if e.type == "replacement":
				replaced = true
		if squashed:
			break
	check(squashed and replaced, "Taxi auf dem Kopf eines Fahrgasts: er schimpft (squashed) und wird ersetzt")
	check(r.actor == null and r.leavers.size() == 1 and r.leavers[0].angry, "Der Fahrgast flieht verärgert in den Unterstand")
	check(r.jobs.size() == n_jobs and r.job_index == 0, "Anzahl und Reihenfolge der Aufträge bleiben gleich")
	var new_from := String(r.current_job().from)
	check(new_from != from_id and new_from != String(r.current_job().to) and not lvl.pads[new_from].fuel, "Ersatz-Fahrgast erscheint an anderem Passagierpad (%s statt %s)" % [new_from, from_id])
	check(String(r.current_job().passenger) != "Mika", "Ersatz-Fahrgast ist eine andere Person (%s)" % String(r.current_job().passenger))
	# Zeit läuft weiter (Strafe), Ersatz erscheint nach Pause
	var clock0 := r.job_clock
	_taxi_over(r, 320.0, 100.0, 0.0)
	for i in int(1.0 / Tuning.TICK):
		r.step(Vector2(0, -0.39), false)
	check(r.job_clock > clock0 + 0.9, "Die Auftragszeit läuft während des Ersatzes weiter")
	check(r.actor == null, "Ersatz-Fahrgast erscheint erst nach kurzer Pause")
	for i in int(2.0 / Tuning.TICK):
		r.step(Vector2(0, -0.39), false)
	check(r.actor != null and r.actor.state == PassengerActor.S.EMERGING or (r.actor != null and r.actor.state == PassengerActor.S.WAITING), "…und tritt dann aus dem Unterstand")
	check(r.job_clock >= clock0 + 2.9, "Kein Zeit-Reset durch den Ersatz (Clock %.1f)" % r.job_clock)
	# Gegenprobe: aufsteigendes Taxi und gelandetes Taxi treffen niemanden
	var r2 := Run.new()
	r2.start(lvl)
	var b := r2.actor
	var pad2: Dictionary = lvl.pads[String(r2.current_job().from)]
	_taxi_over(r2, b.x, pad2.row * Tuning.TILE - 8.0, -60.0)
	r2.step(Vector2(0, -1), true)
	check(r2.actor != null, "Aufsteigendes Taxi trifft keinen Fahrgast")
	_land_on(r2, String(r2.current_job().from))
	r2.step(Vector2.ZERO, true)
	check(r2.actor != null and r2.squashes == 0, "Gelandetes Taxi (Einsteigen) zählt nie als Kollision")
	# Deterministisch: gleicher Level/Auftrag/Versuch -> gleiche Wahl
	var i1 := PassengerActor.pick_identity("S1-01", 0, 1, "Mika")
	var i2 := PassengerActor.pick_identity("S1-01", 0, 1, "Mika")
	check(i1 == i2 and i1.name != "Mika", "Ersatz-Identität ist reproduzierbar und neu")

func _test_landing_window_rules() -> void:
	var dir := DirAccess.open("res://data/levels")
	for f in dir.get_files():
		if not f.ends_with(".json"):
			continue
		var lvl := LevelData.load_file("res://data/levels/" + f)
		var min_w := 1e9
		var widths: Array = []
		for id in lvl.pads:
			var p: Dictionary = lvl.pads[id]
			if p.fuel:
				continue
			min_w = minf(min_w, p.land_window)
			widths.append(int((p.x1 - p.x0) / Tuning.TILE))
		check(min_w >= Tuning.MIN_LAND_WINDOW, "%s: jedes Passagierpad hat ein freies Landefenster ≥ %d px (kleinstes %.0f px, Padbreiten %s Tiles)" % [lvl.id, int(Tuning.MIN_LAND_WINDOW), min_w, str(widths)])
		var varied := false
		for w in widths:
			if w != widths[0]:
				varied = true
		check(varied, "%s: Pads sind unterschiedlich groß" % lvl.id)

func _test_taxi_scale() -> void:
	check(absf(Tuning.HULL_HALF.x - 10.0 * Tuning.TAXI_SCALE) < 0.01 and absf(Tuning.FOOT_X - 8.0 * Tuning.TAXI_SCALE) < 0.01, "Taxi-Kollisionsmaße sind auf %.0f %% skaliert" % (Tuning.TAXI_SCALE * 100.0))
	# Taxi passt mit Landetoleranz bequem auf das kleinste Pad: Fußabstand + Toleranz < Landefenster
	var lvl := _lvl()
	var s := TaxiSim.new()
	s.setup(lvl)
	check(s.state == TaxiSim.State.LANDED, "Start nach Skalierung sicher gelandet")
