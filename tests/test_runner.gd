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
	for t in ["_test_level_parse", "_test_gravity_fall", "_test_hover", "_test_good_landing", "_test_crash", "_test_full_run", "_test_level_rules", "_test_gate_blocks_until_open", "_test_bot_solves_levels"]:
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
