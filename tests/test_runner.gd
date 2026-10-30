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
	for t in ["_test_level_parse", "_test_gravity_fall", "_test_hover", "_test_good_landing", "_test_crash", "_test_full_run", "_test_level_rules", "_test_gear_flight_mode", "_test_passenger_walk_and_board", "_test_passenger_abort", "_test_no_respawn_after_delivery", "_test_transition_timeline", "_test_i18n_complete", "_test_gate_blocks_until_open", "_test_bot_solves_levels"]:
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
	check(s.hull < 100.0, "Aufprall verursacht Schaden (%.1f)" % s.hull)

func _test_full_run() -> void:
	var r := Run.new()
	r.start(_lvl())
	check(r.sim.state == TaxiSim.State.LANDED, "Start gelandet auf Startpad")
	check(r.target_pad() == "1", "Erster Fahrgast wartet auf Pad 1")
	for i in 240:
		r.step(Vector2.ZERO, true)
	check(r.phase == Run.Phase.CARRYING, "Fahrgast an Bord nach Einsteigezeit")

func _test_bot_solves_levels() -> void:
	var dir := DirAccess.open("res://data/levels")
	for f in dir.get_files():
		if not f.ends_with(".json"):
			continue
		var lvl := LevelData.load_file("res://data/levels/" + f)
		var r := Bot.fly_level(lvl)
		check(r.complete and r.hull > 90.0, "Autopilot löst %s (%.0f s, Hülle %.0f%%, %s)" % [lvl.id, r.time, r.hull, r.reason])

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

func _test_passenger_walk_and_board() -> void:
	var r := Run.new()
	r.start(_lvl())
	var a: PassengerActor = r.actor
	check(a != null and a.state == PassengerActor.S.WAITING, "Fahrgast wartet beim Start im Wartebereich")
	var pad: Dictionary = _lvl().pads["1"]
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
	r.step(Vector2.ZERO, true)                     # Fahrgast beginnt zu laufen
	check(r.phase == Run.Phase.BOARDING, "Boarding beginnt nach Landung")
	for i in 12:
		r.step(Vector2(0, -1), true)               # Taxi hebt sofort ab
	check(r.phase == Run.Phase.WAITING, "Abheben bricht das Einsteigen ab")
	for i in 300:
		r.step(Vector2(0, -0.39), false)
	check(r.actor.state == PassengerActor.S.WAITING and absf(r.actor.x - _lvl().pads["1"].wait_x) < 1.0, "Fahrgast kehrt in den Wartebereich zurück")

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
