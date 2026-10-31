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
	for t in ["_test_level_parse", "_test_gravity_fall", "_test_hover", "_test_good_landing", "_test_crash", "_test_full_run", "_test_level_rules", "_test_gear_flight_mode", "_test_passenger_walk_and_board", "_test_passenger_abort", "_test_no_respawn_after_delivery", "_test_transition_timeline", "_test_i18n_complete", "_test_crash_balance", "_test_spikes", "_test_spikes_attached", "_test_arrival_path", "_test_dropoff_liftoff", "_test_extras", "_test_missed_job", "_test_replay", "_test_doors", "_test_movers", "_test_broken_pump_prices", "_test_out_of_fuel", "_test_extra_squash", "_test_level_caps", "_test_life_station", "_test_eject", "_test_fragile_and_meteors", "_test_perfect_needs_flight", "_test_beam_heat_hospital", "_test_wrong_pad_rules", "_test_campaign_save", "_test_payout_and_penalty", "_test_exit_passenger", "_test_spawn_not_on_taxi_pad", "_test_job_rules_and_difficulty", "_test_squash_passenger", "_test_pay_at_shelter_rewards_close_landing", "_test_crash_continues_level", "_test_min_window_ramp", "_test_distance_bonus", "_test_amount_ticks_down", "_test_medals", "_test_save_robust", "_test_settings_robust", "_test_controls_remap", "_test_music_assets", "_test_cosmetics_data", "_test_voice_lines_complete", "_test_streak_bonus", "_test_fuel_prices", "_test_pump_touch_and_explosion", "_test_pump_level_rules", "_test_fuel_pad_variety", "_test_landing_window_rules", "_test_taxi_scale", "_test_gate_blocks_until_open", "_test_bot_solves_levels"]:
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
		var rr := Run.new()
		rr.start(lvl)
		var inc := 0.0
		for j in rr.jobs:
			inc += float(j.fare) * rr.job_mult(j) * Tuning.satisfaction_factor(Tuning.SAT_FLOOR)
		var cost: float = float(r.fuel_burned) * (lvl.fuel_price_min + lvl.fuel_price_max) * 0.5
		check(inc >= cost, "%s: Fahrpreise bei 25 %% Zufriedenheit (¢%d) decken den Sprit des Autopiloten (¢%d)" % [lvl.id, int(inc), int(cost)])
		check(r.complete and r.hull > 90.0 and r.delivered >= r.jobs - 1, "Autopilot löst %s ab Mindest-Sprit %d%% (%.0f s, Hülle %.0f%%, %d/%d befördert, %s)" % [lvl.id, int(Tuning.MIN_START_FUEL), r.time, r.hull, r.delivered, r.jobs, r.reason])

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
			if lvl.is_passenger_pad(id):
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
		if r.job_index == 1 and not checked:
			checked = true
			check(r.leavers.size() == 1 and r.leavers[0].pname == first_name, "Abgesetzter Fahrgast läuft zum Häuschen (leavers)")
			check(r.actor == null or r.actor.pname != first_name, "Abgelieferter Fahrgast spawnt nicht erneut")
			check(r.money == 0.0 and r.delivered == 0, "Noch kein Einkommen, solange er unterwegs zum Häuschen ist")
		if r.result != Run.Result.RUNNING:
			break
	check(r.result == Run.Result.COMPLETE, "Level mit Fahrgast-Akteuren abgeschlossen")
	check(r.delivered >= 1 and r.money > 0.0, "Einkommen wurde bei Ankunft im Häuschen gutgeschrieben (%.0f)" % r.money)

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
				if not m.get_string(1).ends_with("_"):          # dynamisch zusammengesetzte Schlüssel (Präfix) überspringen
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

func _test_spikes() -> void:
	var l := _lvl()
	var rows: Array = []
	for y in l.rows.size():
		rows.append(String(l.rows[y]))
	# Dornenreihe im offenen Bereich (links oben im freien Raum von S1-01 prüfen wir die Mechanik direkt)
	var d := {"id": "T-SP", "sector": 1, "index": 1, "name": {"de": "t", "en": "t"}, "map": rows, "jobs": []}
	var spike_row: String = rows[10]
	var sp_x := -1
	for x in range(2, spike_row.length() - 2):
		if rows[8][x] == "." and rows[9][x] == "." and rows[10][x] == "." and rows[11][x] == ".":
			sp_x = x
			break
	check(sp_x > 0, "Testfläche für Dornen gefunden")
	var r2: Array = rows.duplicate()
	r2[10] = String(rows[10]).substr(0, sp_x - 1) + "^^^" + String(rows[10]).substr(sp_x + 2)
	d["map"] = r2
	var lv := LevelData.from_dict(d)
	var s := TaxiSim.new()
	s.setup(lv)
	s.pos = Vector2(sp_x * Tuning.TILE + 8.0, 8.0 * Tuning.TILE)
	s.vel = Vector2(0, 30)
	s.state = TaxiSim.State.FLYING
	var hits := 0
	for i in 240:
		s.step(Vector2.ZERO, false)
		for e in s.events:
			if e.type == "damage" and e.get("spike", false):
				hits += 1
	check(hits >= 1, "Dornen: Berührung löst Dornenschaden aus (%d Treffer)" % hits)
	check(s.hull <= 100.0 - Tuning.SPIKE_DAMAGE + 0.01, "Dornen: fester Schaden auch bei langsamer Berührung (%.0f Hülle)" % s.hull)
	check(s.hull > 0.0 or s.state == TaxiSim.State.DESTROYED, "Dornen: Hülle fällt nicht unter 0, ohne zerstört zu sein")

func _test_spikes_attached() -> void:
	var dir := DirAccess.open("res://data/levels")
	for f in dir.get_files():
		if not f.ends_with(".json"):
			continue
		var lvl := LevelData.load_file("res://data/levels/" + f)
		var loose := 0
		for cy in lvl.height:
			for cx in lvl.width:
				if lvl.cell(cx, cy) != "^":
					continue
				var held := false
				for d in [Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0)]:
					var c := lvl.cell(cx + d.x, cy + d.y)
					if c != "^" and lvl.is_solid_cell(cx + d.x, cy + d.y):
						held = true
				if not held:
					loose += 1
		check(loose == 0, "%s: Dornen sitzen alle an einer Fläche (%d frei schwebend)" % [lvl.id, loose])

func _test_arrival_path() -> void:
	var dir := DirAccess.open("res://data/levels")
	for f in dir.get_files():
		if not f.ends_with(".json"):
			continue
		var lvl := LevelData.load_file("res://data/levels/" + f)
		var s := TaxiSim.new()
		s.setup(lvl)
		var path := Pathing.arrival_path(lvl, s.pos)
		lvl.exit_open = true
		lvl.doors_forced_open = true          # Einflug: Tore stehen offen
		lvl.movers_ignore = true              # … und Trümmer sind ausgeblendet (Pads: Fahrweg wird umflogen)
		var hits := 0
		for i in range(3, 201):
			var p := Pathing.sample_path(path, float(i) / 200.0)
			if p.y > lvl.exit_rect().end.y and lvl.box_hits_solid(p, Tuning.HULL_HALF):
				hits += 1
		lvl.exit_open = false
		check(hits == 0, "%s: Einflug aus dem Tor zur Startplattform ist hindernisfrei (%d Treffer)" % [lvl.id, hits])
		check(path[path.size() - 1].distance_to(s.pos) < 1.0, "%s: Einflug endet auf der Startposition" % lvl.id)

func _test_dropoff_liftoff() -> void:
	var lvl := _lvl()
	var r := Run.new()
	r.extras_enabled = false
	r.start(lvl)
	var job: Dictionary = r.current_job()
	_land_on(r, String(job.from))
	for i in 240:
		r.step(Vector2.ZERO, true)
	check(r.phase == Run.Phase.CARRYING, "Fahrgast ist an Bord (Phase CARRYING)")
	_land_on(r, String(job.to))
	for i in 6:
		r.step(Vector2.ZERO, true)
	check(r.phase == Run.Phase.DROPOFF, "Aussteigen beginnt")
	r.sim.state = TaxiSim.State.FLYING        # sofort wieder abheben
	r.sim.landed_pad = {}
	for i in 4:
		r.step(Vector2(0, -1), true)
	check(r.phase == Run.Phase.WAITING and r.job_index == 1, "Nach sofortigem Abflug ist der Auftrag abgeschlossen (nicht mehr an Bord)")
	check(r.leavers.size() == 1 and r.leavers[0].state != PassengerActor.S.ABOARD, "Fahrgast läuft zum Häuschen statt zurück ins Taxi")
	for i in int(20.0 / Tuning.TICK):
		r.step(Vector2(0, -0.39), true)
	check(r.delivered == 1 and r.money > 0.0, "Auszahlung folgt, sobald er sein Häuschen erreicht (¢%d)" % int(r.money))

func _test_extras() -> void:
	var lvl := LevelData.load_file("res://data/levels/s1_05.json")
	var r := Run.new()
	r.start(lvl)
	check(r.extras_active() and Tuning.extra_slots(5) == 1 and Tuning.extra_slots(4) == 0, "Zusatzfahrgäste ab Level 5")
	var l4 := LevelData.load_file("res://data/levels/s1_04.json")
	var r4 := Run.new()
	r4.start(l4)
	r4.extra_timer = 0.0
	r4.step(Vector2.ZERO, false)
	check(r4.extras.is_empty(), "Vor Level 5 erscheinen keine Zusatzfahrgäste")
	r.extra_timer = 0.0
	r.step(Vector2.ZERO, false)
	check(r.extras.size() == 1, "Zusatzfahrgast erscheint, auch während ein Auftrags-Fahrgast wartet")
	var ex: Dictionary = r.extras[0]
	check(String(ex.job.from) != String(r.actor.pad.id) and String(ex.job.to) != String(ex.job.from), "Anderes Pad als der Auftrags-Fahrgast, anderes Ziel als Start")
	r.extra_timer = 0.0
	r.step(Vector2.ZERO, false)
	check(r.extras.size() == 1, "Höchstens %d gleichzeitig wartende Zusatzfahrgäste" % Tuning.extra_slots(5))
	# Aufnehmen und Ausliefern
	for i in int(2.0 / Tuning.TICK):
		r.step(Vector2.ZERO, false)
	_land_on(r, String(ex.job.from))
	for i in int(3.0 / Tuning.TICK):
		r.step(Vector2.ZERO, true)
	check(int(ex.state) == Run.ES.CARRY and r.extra_busy(), "Zusatzfahrgast steigt ein, das Taxi hat nur einen Sitz")
	check(r.target_pad() == String(ex.job.to), "Zielpad zeigt auf das Ziel des Zusatzfahrgasts")
	var before_phase := r.phase
	check(before_phase == Run.Phase.WAITING, "Auftragskette unberührt")
	r.sim.state = TaxiSim.State.FLYING
	r.sim.landed_pad = {}
	r.step(Vector2(0, -1), true)
	_land_on(r, String(ex.job.to))
	for i in int(1.0 / Tuning.TICK):
		r.step(Vector2.ZERO, true)
	check(r.extras.is_empty() and r.leavers.size() >= 1, "Ausgestiegen: läuft zum Häuschen")
	var m0 := r.money
	r.sim.state = TaxiSim.State.FLYING
	r.sim.landed_pad = {}
	for i in int(20.0 / Tuning.TICK):
		r.step(Vector2(0, -0.39), true)
	check(r.extras_delivered == 1 and r.money > m0 and r.delivered == 0, "Bezahlt im Häuschen, zählt nicht als Auftrag des Levels (¢%d)" % int(r.money - m0))
	# Geduld
	var r2 := Run.new()
	r2.start(lvl)
	r2.extra_timer = 0.0
	r2.step(Vector2.ZERO, false)
	r2.extras[0].patience = 0.02
	var left := false
	for i in 20:
		r2.step(Vector2.ZERO, false)
		for e in r2.log:
			if e.type == "extra_left":
				left = true
	check(left and r2.extras.is_empty() and r2.extras_missed == 1, "Zu lange gewartet: Fahrgast schimpft und geht")
	# Absturz verliert Fahrgast an Bord
	var r3 := Run.new()
	r3.start(lvl)
	r3.extra_timer = 0.0
	r3.step(Vector2.ZERO, false)
	var e3: Dictionary = r3.extras[0]
	for i in int(2.0 / Tuning.TICK):
		r3.step(Vector2.ZERO, false)
	_land_on(r3, String(e3.job.from))
	for i in int(3.0 / Tuning.TICK):
		r3.step(Vector2.ZERO, true)
	r3.respawn_after_crash()
	check(r3.extras.is_empty(), "Absturz: Zusatzfahrgast an Bord ist verloren")

func _test_missed_job() -> void:
	var lvl := _lvl()
	var r := Run.new()
	r.extras_enabled = false
	r.start(lvl)
	r.money = 100.0
	var left := false
	for i in 90:
		r.step(Vector2(0, -1), true)                      # abheben: auf dem Startpad erscheint sonst kein Fahrgast
	for i in int(30.0 / Tuning.TICK):
		if r.actor != null and r.actor.state == PassengerActor.S.WAITING:
			r.main_patience = 0.0
		r.step(Vector2(0, -0.39), false)
		for e in r.log:
			if e.type == "extra_left":
				left = true
		if r.exit_open:
			break
	check(left and r.missed == lvl.jobs.size(), "Wartet ein Pflichtfahrgast zu lange, geht er (verpasst: %d/%d)" % [r.missed, lvl.jobs.size()])
	check(r.delivered == 0 and r.actor == null, "Kein Ersatzfahrgast erscheint")
	check(r.exit_open and lvl.exit_open, "Nach dem letzten Pflichtfahrgast ist der Ausgang frei, auch wenn niemand befördert wurde")
	check(r.missed_fees > 0.0 and r.money < 100.0, "Jeder verpasste Fahrgast kostet Credits (−¢%d)" % int(r.missed_fees))

func _test_wrong_pad_rules() -> void:
	var lvl := _lvl()
	var r := Run.new()
	r.extras_enabled = false
	r.start(lvl)
	var job: Dictionary = r.current_job()
	_land_on(r, String(job.from))
	for i in 240:
		r.step(Vector2.ZERO, true)
	check(r.phase == Run.Phase.CARRYING, "Fahrgast an Bord")
	r._check_wrong_pad(String(job.from))
	check(r.pen_ride == 0.0, "Nachsetzen auf dem Abholpad ist keine falsche Plattform")
	var other := "1" if String(job.from) != "1" and String(job.to) != "1" else "2"
	for id in ["1", "2", "3"]:
		if id != String(job.from) and id != String(job.to):
			other = id
	r.log.clear()
	r._check_wrong_pad(other)
	check(absf(r.pen_ride - Tuning.WRONG_PAD_PEN) < 0.001 and r.log.any(func(e): return e.type == "wrong_pad"), "Landung an falscher Plattform: Fahrgast meckert, Fahrpreis sinkt")
	# Ausgangs-Fahrgast
	var r2 := Run.new()
	r2.extras_enabled = false
	r2.start(lvl)
	r2.job_index = lvl.jobs.size() - 1
	r2._spawn_actor(true)
	var ej: Dictionary = r2.current_job()
	_land_on(r2, String(ej.from))
	for i in 240:
		r2.step(Vector2.ZERO, true)
	check(r2.phase == Run.Phase.CARRYING and r2.is_exit_job(ej), "Ausgangs-Fahrgast an Bord")
	var other2 := "2" if String(ej.from) != "2" else "3"
	r2.log.clear()
	r2._check_wrong_pad(other2)
	check(r2.log.any(func(e): return e.type == "wrong_pad"), "Ausgangs-Fahrgast meckert, wenn er woanders abgesetzt wird")

func _test_campaign_save() -> void:
	var sv: Node = load("res://src/core/save.gd").new()
	sv.path = "user://test_save_campaign.json"
	_rm(sv.path)
	sv.set_campaign({"level": "s1_05", "lives": 3, "fuel": 60.0, "credits": 420.0, "seed": 123, "carry": {}})
	var sv2: Node = load("res://src/core/save.gd").new()
	sv2.path = sv.path
	sv2.load_save()
	var c: Dictionary = sv2.campaign()
	check(c.get("level", "") == "s1_05" and int(c.get("lives", 0)) == 3 and float(c.get("credits", 0)) == 420.0, "Feldzug (Level, Leben, Credits) wird gespeichert und geladen")
	sv2.clear_campaign()
	var sv3: Node = load("res://src/core/save.gd").new()
	sv3.path = sv.path
	sv3.load_save()
	check(sv3.campaign().is_empty(), "Neues Spiel / Game Over löscht den gespeicherten Feldzug")
	_rm(sv.path)

func _test_replay() -> void:
	var q := Replay.quantize(Vector2(0.3333, -1.7))
	check(absf(q.x - roundi(0.3333 * 127.0) / 127.0) < 1e-6 and q.y == -1.0, "Eingaben werden auf 1/127 gerundet und begrenzt")
	for id in ["s1_01", "s1_04", "s1_08"]:
		var lvl := LevelData.load_file("res://data/levels/%s.json" % id)
		var res := Bot.fly_level(lvl, 600.0, Tuning.MIN_START_FUEL, true)
		check(res.complete, "%s: aufgezeichneter Bot-Lauf ist abgeschlossen" % id)
		var d: Dictionary = JSON.parse_string(JSON.stringify(res.replay))      # wie nach Speichern und Laden
		var lvl2 := LevelData.load_file("res://data/levels/%s.json" % id)
		var pl := Replay.play(lvl2, d)
		check(pl.complete and absf(pl.time - float(d.result.time)) < 0.001 and absf(pl.money - float(d.result.money)) < 0.01 and pl.delivered == int(d.result.delivered),
			"%s: Wiedergabe reproduziert den Lauf exakt (%.2f s, ¢%d, %d Ticks, %d Läufe RLE)" % [id, pl.time, int(pl.money), pl.ticks, d.runs.size()])
	# Absturz-Ereignis wird wiedergegeben
	var lv := _lvl()
	var r := Run.new()
	r.extras_enabled = false
	r.start(lv)
	var rep := Replay.new()
	rep.begin(lv.id, -1, -1.0, 0.0, {}, false)
	for i in 30:
		rep.add(Vector2(0, -1), true)
		r.step(Vector2(0, -1), true)
	rep.mark_respawn()
	r.respawn_after_crash()
	for i in 30:
		rep.add(Vector2.ZERO, true)
		r.step(Vector2.ZERO, true)
	var d2 := rep.to_dict()
	check(d2.events.size() == 1 and d2.ticks == 60, "Respawn wird als Ereignis aufgezeichnet")

func _door_level() -> LevelData:
	var rows: Array = []
	for y in 12:
		var row := ""
		for x in 20:
			row += "#" if (y == 0 or y == 11 or x == 0 or x == 19) else ("a" if x == 10 else ".")
		rows.append(row)
	return LevelData.from_dict({"id": "T-DOOR", "sector": 2, "index": 1, "name": {"de": "t", "en": "t"}, "map": rows, "jobs": [],
		"doors": {"a": {"period": 6.0, "open": 3.0, "phase": 3.0}}})

func _test_doors() -> void:
	var lv := _door_level()
	check(lv.has_doors() and lv.doors["a"].cells.size() == 10, "Torzellen werden erkannt (%d)" % lv.doors["a"].cells.size())
	check(not lv.door_is_open("a", 0.0) and lv.door_is_open("a", 3.5) and not lv.door_is_open("a", 6.5) and lv.door_is_open("a", 9.5), "Tor öffnet und schließt im festen Takt")
	var s := TaxiSim.new()
	s.setup(lv)
	s.state = TaxiSim.State.FLYING
	s.pos = Vector2(120.0, 80.0)
	s.vel = Vector2.ZERO
	for i in int(2.5 / Tuning.TICK):
		s.step(Vector2(1, -0.39), false)
	check(s.pos.x < 10.0 * Tuning.TILE and s.time < 3.0, "Geschlossenes Tor ist fest (x=%.0f)" % s.pos.x)
	var crossed := false
	for i in int(2.4 / Tuning.TICK):
		s.step(Vector2(1, -0.39), false)
		if s.pos.x > 11.0 * Tuning.TILE:
			crossed = true
	check(crossed, "Offenes Tor ist passierbar")
	# Tor schließt auf dem Taxi: Schaden und Rauswurf zur nächsten Seite
	var s2 := TaxiSim.new()
	s2.setup(lv)
	s2.state = TaxiSim.State.FLYING
	s2.pos = Vector2(10.0 * Tuning.TILE + 8.0, 80.0)
	s2.vel = Vector2.ZERO
	s2.time = 5.95                     # Tor ist offen und schließt bei t = 6
	var crushed := false
	for i in 20:
		s2.step(Vector2(0, -0.39), false)
		for e in s2.events:
			if e.type == "damage" and e.get("crush", false):
				crushed = true
	check(crushed and s2.hull <= 100.0 - Tuning.DOOR_CRUSH_DAMAGE + 0.01, "Tor schließt auf dem Taxi: Schaden (%.0f Hülle)" % s2.hull)
	check(absf(s2.pos.x - (10.0 * Tuning.TILE + 8.0)) >= 14.0 and s2.state != TaxiSim.State.DESTROYED and not lv.box_hits_solid(s2.pos, Tuning.HULL_HALF), "…und wird zur nächsten Seite hinausgeschleudert (x=%.0f)" % s2.pos.x)
	# Planung ignoriert Tore (Bot wartet davor)
	var p := Pathing.plan(lv, Vector2(60, 80), Vector2(260, 80), 4.0)
	check(not p.is_empty(), "Wegplanung behandelt bewegliche Tore als passierbar")

func _test_broken_pump_prices() -> void:
	var r := Run.new()
	r.extras_enabled = false
	r.start(_lvl())
	r.pump_touches = Tuning.PUMP_TOUCHES_TO_BREAK
	r.pump_broken = true
	var p0 := r.price_base
	r.price_next_t = 0.0
	var changed := false
	for i in int(5.0 / Tuning.TICK):
		r.step(Vector2.ZERO, false)
		for e in r.log:
			if e.type == "price_changed":
				changed = true
	check(not changed and r.price_base == p0, "Bei defekter Zapfsäule ändert sich der Spritpreis nicht mehr")

func _test_out_of_fuel() -> void:
	var lvl := _lvl()
	var r := Run.new()
	r.extras_enabled = false
	r.start(lvl)
	for i in 90:
		r.step(Vector2(0, -1), true)
	r.sim.fuel = 0.0
	var warned := false
	for i in int((Tuning.OUT_OF_FUEL_TIME + 1.0) / Tuning.TICK):
		r.step(Vector2.ZERO, true)
		for e in r.log:
			if e.type == "out_of_fuel":
				warned = true
		if r.result == Run.Result.FAILED:
			break
	check(warned and r.result == Run.Result.FAILED and r.fuel_fail, "Leerer Tank: Warnung, nach %.0f s ist das Taxi verloren" % Tuning.OUT_OF_FUEL_TIME)
	r.respawn_after_crash()
	check(r.sim.fuel >= Tuning.FUEL_MAX - 0.01 and r.result == Run.Result.RUNNING, "Neues Taxi mit vollem Tank, Level läuft weiter")
	# an der Zapfsäule: kein Verlust (tankt notfalls kostenlos)
	var r2 := Run.new()
	r2.extras_enabled = false
	r2.start(lvl)
	_land_on(r2, "F")
	r2.sim.fuel = 0.0
	for i in int(4.0 / Tuning.TICK):
		r2.step(Vector2.ZERO, true)
	check(r2.result == Run.Result.RUNNING and r2.sim.fuel > 0.0, "Leer an der Zapfsäule: wird kostenlos aufgetankt, kein Verlust")

func _test_extra_squash() -> void:
	var lvl := LevelData.load_file("res://data/levels/s1_05.json")
	var r := Run.new()
	r.start(lvl)
	r.extra_timer = 0.0
	for i in 90:
		r.step(Vector2(0, -1), true)
	for i in int(2.0 / Tuning.TICK):
		r.step(Vector2(0, -0.39), false)
	check(r.extras.size() == 1, "Zusatzfahrgast wartet")
	var ex: Dictionary = r.extras[0]
	var a: PassengerActor = ex.actor
	r.sim.state = TaxiSim.State.FLYING
	r.sim.landed_pad = {}
	r.sim.vel = Vector2(0, 20)
	r.sim.pos = Vector2(a.x, a.surface_y - 8.0)
	var squashed := false
	for i in 6:
		r.step(Vector2(0, -0.39), false)
		for e in r.log:
			if e.type == "squashed":
				squashed = true
	check(squashed and r.extras.is_empty() and a.angry, "Auch Zusatzfahrgäste werden vom Taxi getroffen: schimpfen und verschwinden")

func _test_level_caps() -> void:
	var dir := DirAccess.open("res://data/levels")
	for f in dir.get_files():
		if not f.ends_with(".json"):
			continue
		var lvl := LevelData.load_file("res://data/levels/" + f)
		var n_pads := 0
		for id in lvl.pads:
			if lvl.is_passenger_pad(id):
				n_pads += 1
		check(lvl.jobs.size() <= Tuning.max_jobs(lvl.number), "%s: %d Pflichtfahrgäste (Obergrenze %d)" % [lvl.id, lvl.jobs.size(), Tuning.max_jobs(lvl.number)])
		check(n_pads <= Tuning.max_pads(lvl.number), "%s: %d Passagierpads (Obergrenze %d)" % [lvl.id, n_pads, Tuning.max_pads(lvl.number)])

func _test_life_station() -> void:
	var dir := DirAccess.open("res://data/levels")
	for f in dir.get_files():
		if not f.ends_with(".json"):
			continue
		var lv := LevelData.load_file("res://data/levels/" + f)
		if lv.number % 5 == 0 and lv.sector <= 4:          # Sektor 5 ist noch ein Teilsektor (Lebensstationen dort in Level 48 und 51)
			check(lv.pads.has("L") and lv.pads["L"].land_window >= 28.0, "%s (Level %d): Lebens-Station vorhanden (alle 5 Level)" % [lv.id, lv.number])
	var lvl := LevelData.load_file("res://data/levels/s1_05.json")
	var r := Run.new()
	r.extras_enabled = false
	r.start(lvl)
	r.lives = 3
	r.money = 1500.0
	_land_on(r, "L")
	var bought := false
	for i in int(2.0 / Tuning.TICK):
		r.step(Vector2.ZERO, true)
		for e in r.log:
			if e.type == "life_bought":
				bought = true
	check(bought and r.lives == 4 and absf(r.money - 500.0) < 0.01, "Lebens-Station: ein Leben für ¢%d (jetzt %d Leben, ¢%d)" % [int(Tuning.LIFE_PRICE), r.lives, int(r.money)])
	r.money = 5000.0
	r.lives = Tuning.MAX_LIVES
	r.sim.state = TaxiSim.State.FLYING
	r.sim.landed_pad = {}
	r.step(Vector2(0, -1), true)
	_land_on(r, "L")
	var denied := false
	for i in int(2.0 / Tuning.TICK):
		r.step(Vector2.ZERO, true)
		for e in r.log:
			if e.type == "life_denied":
				denied = true
	check(denied and r.lives == Tuning.MAX_LIVES and r.money == 5000.0, "Mehr als 5 Leben gibt es nicht (nichts abgebucht)")
	check(not lvl.is_passenger_pad("L") and lvl.is_passenger_pad("1") and not lvl.is_passenger_pad("F"), "Lebens-Station zählt nicht als Passagierpad")

func _board_main(r: Run, lvl: LevelData) -> Dictionary:
	var job: Dictionary = r.current_job()
	_land_on(r, String(job.from))
	for i in 240:
		r.step(Vector2.ZERO, true)
	return job

func _test_fragile_and_meteors() -> void:
	# Zerbrechlicher Fahrgast: jede Beschädigung an Bord beendet die Fahrt, der Auftrag gilt als verpasst
	var lvl := _lvl()
	var r := Run.new()
	r.extras_enabled = false
	r.start(lvl)
	r.jobs[0]["fragile"] = true
	_board_main(r, lvl)
	check(r.phase == Run.Phase.CARRYING and r.actor != null, "Zerbrechlicher Fahrgast sitzt im Taxi")
	r._ride_hit({"amount": 5.0})
	check(r.actor == null and r.missed == 1 and r.pen_ride == 0.0, "Beschädigung an Bord: zerbrechlicher Fahrgast weg, Auftrag verpasst")
	check(r.log.any(func(e): return e.type == "fragile_broke") and r.log.any(func(e): return e.type == "job_missed"), "Ereignisse fragile_broke und job_missed werden gemeldet")
	var r2 := Run.new()
	r2.extras_enabled = false
	r2.start(lvl)
	_board_main(r2, lvl)
	r2._ride_hit({"amount": 5.0})
	check(r2.actor != null and r2.pen_ride > 0.0 and r2.missed == 0, "Normaler Fahrgast: Beschädigung kostet nur Fahrpreis")
	# Meteoritenschauer: nur während des Falls sichtbar und gefährlich, Warnung vorher
	var rows: Array = []
	for y in 22:
		var row := ""
		for x in 30:
			row += "#" if (y == 0 or y == 21 or x == 0 or x == 29) else "."
		rows.append(row)
	var lv := LevelData.from_dict({"id": "T-MET", "sector": 3, "index": 1, "name": {"de": "t", "en": "t"}, "map": rows, "jobs": [],
		"movers": [{"kind": "meteor", "x": 10, "y": 1, "w": 1, "h": 1, "dx": 0, "dy": 12, "fall": 2.0, "warn": 2.0, "period": 10.0, "phase": 0.0}]})
	check(lv.has_meteors() and lv.movers.size() == 1, "Meteor wird erkannt")
	var m: Dictionary = lv.movers[0]
	lv.update_movers(1.0)
	check(absf(m.rect.position.y - (1.0 * Tuning.TILE + 6.0 * Tuning.TILE)) < 0.5, "Meteor fällt linear (Halbzeit = halbe Strecke)")
	lv.update_movers(5.0)
	check(m.rect.position.x < -500.0 and lv.meteor_eta(m, 5.0) == 5.0, "Zwischen den Fällen ist der Meteor unsichtbar (eta 5 s)")
	var lane := Rect2(10.0 * Tuning.TILE, 8.0 * Tuning.TILE, 16.0, 16.0)
	check(lv.meteor_threat(lane, 8.5, 2.2).is_empty() == false and lv.meteor_threat(lane, 5.0, 2.2).is_empty(), "Bahn gilt erst kurz vor dem Fall als bedroht")
	var s := TaxiSim.new()
	s.setup(lv)
	s.state = TaxiSim.State.FLYING
	s.pos = Vector2(10.5 * Tuning.TILE, 6.0 * Tuning.TILE)
	var warned := false
	var hit := false
	for i in int(12.0 / Tuning.TICK):
		s.step(Vector2(0, -0.39), false)
		for e in s.events:
			if e.type == "meteor_warn":
				warned = true
			if e.type == "damage" and e.get("mover", "") == "meteor":
				hit = true
		if s.state == TaxiSim.State.DESTROYED:
			break
	check(warned, "Meteoritenschauer meldet vorher eine Warnung")
	check(hit and s.hull < 100.0, "Meteoriten-Treffer: Schaden (%.0f Hülle)" % s.hull)

func _test_perfect_needs_flight() -> void:
	# Eine „perfekte Landung“ zählt nur nach echtem Flug (Zeit und Strecke seit dem Abheben), nicht nach Hüpfern auf der Stelle
	var r := Run.new()
	r.start(_lvl())
	r.log.clear()
	r._evaluate_landing({"vy": 10.0, "vx": 3.0, "tilt": 0.02, "air_t": 0.1, "air_path": 3.0})
	check(r.streak == 0 and r.perfect_count == 0, "Hüpfer direkt nach dem Abheben (0,1 s) zählt nicht als perfekt")
	r._evaluate_landing({"vy": 10.0, "vx": 3.0, "tilt": 0.02, "air_t": 3.0, "air_path": 10.0})
	check(r.perfect_count == 0, "Zu kurze Strecke (10 px) zählt nicht als perfekt")
	r._evaluate_landing({"vy": 10.0, "vx": 3.0, "tilt": 0.02, "air_t": 3.0, "air_path": 120.0})
	check(r.perfect_count == 1 and r.streak == 1, "Echter Flug (3 s, 120 px) und sanfte Landung = perfekt")
	r._evaluate_landing({"vy": 10.0, "vx": 3.0, "tilt": 0.02, "air_t": 0.2, "air_path": 4.0})
	check(r.streak == 1, "Ein Hüpfer unterbricht die Serie nicht und verlängert sie nicht")
	# Im Sim: Abheben setzt die Zähler zurück, jeder Flugtick zählt hoch
	var s := TaxiSim.new()
	s.setup(_lvl())
	s.state = TaxiSim.State.FLYING
	s.pos = Vector2(300.0, 100.0)
	s.air_t = 0.0
	s.air_path = 0.0
	for i in 120:
		s.step(Vector2(0.3, -0.39), false)
	check(s.air_t > 0.9 and s.air_path > 10.0, "Flugzeit und Flugstrecke wachsen im Flug (%.1f s, %.0f px)" % [s.air_t, s.air_path])

func _test_beam_heat_hospital() -> void:
	var rows: Array = []
	for y in 22:
		var row := ""
		for x in 40:
			row += "#" if (y == 0 or y >= 20 or x == 0 or x == 39) else "."
		rows.append(row)
	rows[1] = "#" + ".".repeat(14) + "##EEEE##" + ".".repeat(15) + "#"
	rows[19] = "#" + ".".repeat(3) + "11111" + ".".repeat(5) + "HHHHH" + ".".repeat(21) + "#"
	rows[18] = rows[18].substr(0, 4) + "S" + rows[18].substr(5)
	var lv := LevelData.from_dict({"id": "T-BH", "sector": 5, "index": 1, "name": {"de": "t", "en": "t"}, "map": rows, "jobs": [{"from": "1", "to": "H", "fare": 100, "par": 50, "passenger": "Mika", "gender": "f", "fragile": true}],
		"movers": [{"kind": "beam", "x": 10, "y": 5, "w": 8, "h": 1, "period": 10.0, "on": 3.0, "phase": 0.0, "warn": 2.0}],
		"zones": [{"kind": "heat", "x": 24, "y": 5, "w": 3, "h": 3}]})
	check(lv.pads.has("H") and lv.pads["H"].hospital and not lv.is_passenger_pad("H") and lv.is_passenger_pad("1"), "Krankenhaus-Pad H wird erkannt, ist aber kein nummeriertes Passagierpad")
	check(lv.pads["H"].shelter.size.x > 0.0, "Krankenhaus hat einen Unterstand (Fahrgast läuft hinein)")
	var m: Dictionary = lv.movers[0]
	lv.update_movers(1.0)
	check(m.rect.position.x == 160.0 and lv.meteor_eta(m, 1.0) == 0.0, "Plasmastrahl ist im Takt aktiv")
	lv.update_movers(5.0)
	check(m.rect.position.x < -500.0 and absf(lv.meteor_eta(m, 5.0) - 5.0) < 0.001, "Plasmastrahl ist zwischen den Pulsen aus (nächster in 5 s)")
	check(not lv.meteor_threat(Rect2(160, 80, 16, 16), 5.0, 2.2).is_empty() == false and not lv.meteor_threat(Rect2(160, 80, 16, 16), 8.5, 2.2).is_empty(), "Strahl-Bahn gilt erst kurz vor dem Puls als bedroht")
	var s := TaxiSim.new()
	s.setup(lv)
	s.state = TaxiSim.State.FLYING
	s.pos = Vector2(14.0 * Tuning.TILE, 5.5 * Tuning.TILE)
	var beam_hit := false
	for i in int(3.0 / Tuning.TICK):
		s.step(Vector2(0, -0.39), false)
		for e in s.events:
			if e.type == "damage" and e.get("mover", "") == "beam":
				beam_hit = true
	check(beam_hit, "Plasmastrahl verbrennt das Taxi")
	var s2 := TaxiSim.new()
	s2.setup(lv)
	s2.state = TaxiSim.State.FLYING
	s2.pos = Vector2(25.5 * Tuning.TILE, 6.5 * Tuning.TILE)
	var heat := 0
	for i in int(2.0 / Tuning.TICK):
		s2.step(Vector2(0, -0.39), false)
		for e in s2.events:
			if e.type == "damage" and e.get("heat", false):
				heat += 1
	check(heat >= 6 and s2.hull < 85.0, "Hitzezone: Hüllenschaden alle 0,25 s (%d Treffer, Hülle %.0f)" % [heat, s2.hull])
	check(not Pathing.free_at(lv, Vector2(25.5 * Tuning.TILE, 6.5 * Tuning.TILE), 0.0) and Pathing.free_at(lv, Vector2(30.0 * Tuning.TILE, 12.0 * Tuning.TILE), 0.0), "Planung meidet Hitzezonen")
	# Krankentransport: Zielpad ist H
	var r := Run.new()
	r.start(lv)
	_land_on(r, "1")
	for i in 240:
		r.step(Vector2.ZERO, true)
	check(r.phase == Run.Phase.CARRYING and r.target_pad() == "H", "Krankentransport: nach dem Einsteigen ist das Krankenhaus das Ziel")

func _test_eject() -> void:
	var lvl := _lvl()
	var r := Run.new()
	r.extras_enabled = false
	r.start(lvl)
	check(not r.eject(), "Ohne Fahrgast an Bord passiert beim Rauswerfen nichts")
	r.money = 200.0
	var job := _board_main(r, lvl)
	check(r.phase == Run.Phase.CARRYING, "Fahrgast an Bord")
	r.sim.state = TaxiSim.State.FLYING
	r.sim.landed_pad = {}
	r.sim.pos = Vector2(300.0, 80.0)
	r.sim.vel = Vector2(20, 0)
	var lethal := false
	check(r.eject(), "Rauswerfen im Flug funktioniert")
	for e in r.log:
		if e.type == "ejected":
			lethal = e.lethal
	check(lethal and r.actor == null and r.job_index == 1 and r.missed == 1 and r.ejected == 1, "Pflichtauftrag gilt als verpasst, Fahrgast fällt")
	r.step(Vector2(0, -0.39), false)
	check(r.log.any(func(e): return e.type == "ejected") and r.log.any(func(e): return e.type == "job_missed"), "Rauswurf-Ereignisse erreichen das Spiel (Schrei, Meldung) – gehen nicht zwischen den Ticks verloren")
	var splat := false
	var fell: PassengerActor = r.leavers[r.leavers.size() - 1]
	var money_before := r.money
	for i in int(6.0 / Tuning.TICK):
		r.step(Vector2(0, -0.39), false)
		for e in r.log:
			if e.type == "splat":
				splat = true
	check(splat and fell.state != PassengerActor.S.FALLING and r.delivered == 0 and r.money <= money_before + 0.001, "Er stirbt beim Aufprall und bringt kein Geld (¢%d)" % int(r.money))
	check(not r.medals().clean, "Rausgeworfen: keine Sauber-Medaille")
	# aus dem Stand: überlebt, schimpft, läuft weg
	var r2 := Run.new()
	r2.extras_enabled = false
	r2.start(lvl)
	_board_main(r2, lvl)
	check(r2.eject(), "Rauswerfen am Boden")
	var surv: PassengerActor = r2.leavers[r2.leavers.size() - 1]
	check(surv.state == PassengerActor.S.EXITING and surv.angry and surv.pay_info.is_empty(), "Am Boden überlebt er, schimpft und läuft weg – ohne Geld")
	# Zusatzfahrgast
	var l5 := LevelData.load_file("res://data/levels/s1_05.json")
	var r3 := Run.new()
	r3.start(l5)
	r3.extra_timer = 0.0
	for i in 90:
		r3.step(Vector2(0, -1), true)
	for i in int(2.0 / Tuning.TICK):
		r3.step(Vector2(0, -0.39), false)
	var ex: Dictionary = r3.extras[0]
	_land_on(r3, String(ex.job.from))
	for i in int(3.0 / Tuning.TICK):
		r3.step(Vector2.ZERO, true)
	check(int(ex.state) == Run.ES.CARRY, "Zusatzfahrgast an Bord")
	var fee_before := r3.missed_fees
	r3.sim.state = TaxiSim.State.FLYING
	r3.sim.landed_pad = {}
	r3.sim.pos = Vector2(300.0, 80.0)
	check(r3.eject() and r3.extras.is_empty() and r3.missed == 0 and r3.missed_fees == fee_before, "Zusatzfahrgast rauswerfen: weg, keine Verpasst-Gebühr")
	# Standard-Tasten
	var ctl := load("res://src/core/controls.gd")
	var cfg: Dictionary = ctl.ACTIONS
	check(cfg.eject.keys.has(KEY_E) and cfg.eject.btn.has(JOY_BUTTON_Y) and cfg.restart.btn.has(JOY_BUTTON_BACK) and not cfg.restart.btn.has(JOY_BUTTON_Y), "Rauswerfen: E / Y; Neustart: R / Back")
	# Replay mit Rauswurf
	var rr := Run.new()
	rr.extras_enabled = false
	rr.start(lvl)
	var rep := Replay.new()
	rep.begin(lvl.id, -1, -1.0, 0.0, {}, false)
	var jb: Dictionary = rr.current_job()
	_land_on(rr, String(jb.from))
	for i in 240:
		rep.add(Vector2.ZERO, true)
		rr.step(Vector2.ZERO, true)
	rr.sim.state = TaxiSim.State.FLYING
	rr.sim.landed_pad = {}
	rr.sim.pos = Vector2(300.0, 80.0)
	rep.mark_eject()
	rr.eject()
	for i in 600:
		rep.add(Vector2(0, -0.39), false)
		rr.step(Vector2(0, -0.39), false)
	check(rr.ejected == 1 and rep.events.size() == 1 and String(rep.events[0][1]) == "eject", "Rauswurf wird im Replay als Ereignis aufgezeichnet")

func _mover_level() -> LevelData:
	var rows: Array = []
	for y in 16:
		var row := ""
		for x in 30:
			row += "#" if (y == 0 or y == 15 or x == 0 or x == 29) else "."
		rows.append(row)
	return LevelData.from_dict({"id": "T-MV", "sector": 3, "index": 1, "name": {"de": "t", "en": "t"}, "map": rows, "jobs": [],
		"movers": [{"kind": "debris", "x": 10, "y": 6, "w": 2, "h": 1, "dx": 4, "dy": 0, "period": 8.0},
			{"kind": "pad", "pad": "1", "x": 18, "y": 12, "w": 6, "dx": 2, "period": 8.0}]})

func _test_movers() -> void:
	var lv := _mover_level()
	check(lv.movers.size() == 2 and lv.pads.has("1") and lv.pads["1"].moving, "Mover werden erkannt (Trümmer + fahrendes Pad)")
	lv.update_movers(0.0, true)
	var r0: Rect2 = lv.movers[0].rect
	lv.update_movers(2.0)
	var r1: Rect2 = lv.movers[0].rect
	check(absf(r1.position.x - (r0.position.x + 4.0 * Tuning.TILE)) < 0.5, "Trümmer bewegen sich nach der Simulationszeit (Amplitude 4 Tiles bei t = Viertelperiode)")
	# Pad fährt mit seinen Daten (Landefenster, Wartepunkt)
	var p: Dictionary = lv.pads["1"]
	check(absf(float(p.x0) - (18.0 * Tuning.TILE + 2.0 * Tuning.TILE)) < 0.5 and absf(float(p.land_mid) - (float(p.base.land_mid) + 2.0 * Tuning.TILE)) < 0.5, "Fahrendes Pad verschiebt Fläche, Landefenster und Unterstand")
	# Trümmer-Treffer: Schaden und Rückstoß
	var s := TaxiSim.new()
	s.setup(lv)
	s.state = TaxiSim.State.FLYING
	s.pos = Vector2(10.0 * Tuning.TILE - 14.0, 6.0 * Tuning.TILE + 8.0)
	s.vel = Vector2(40, 0)
	var dmg := false
	for i in int(2.0 / Tuning.TICK):
		s.step(Vector2(0.5, -0.39), false)
		for e in s.events:
			if e.type == "damage" and e.get("mover", "") == "debris":
				dmg = true
	check(dmg and s.hull < 100.0, "Berührung mit Trümmern: Schaden (%.0f Hülle)" % s.hull)
	# Landen auf der fahrenden Plattform: das Taxi fährt mit
	var s2 := TaxiSim.new()
	s2.setup(lv)
	s2.state = TaxiSim.State.FLYING
	var pad: Dictionary = lv.pads["1"]
	s2.pos = Vector2(float(pad.land_mid), pad.row * Tuning.TILE - 30.0)
	s2.vel = Vector2.ZERO
	s2.gear = 1.0
	s2.gear_cmd = true
	var landed := false
	for i in int(6.0 / Tuning.TICK):
		s2.step(Vector2(0, 0.25), true)
		if s2.state == TaxiSim.State.LANDED:
			landed = true
			break
	check(landed and s2.landed_pad.id == "1", "Landung auf der fahrenden Plattform gelingt (relative Geschwindigkeit zählt)")
	var x0 := s2.pos.x
	var d0 := float(pad.dx)
	for i in int(3.0 / Tuning.TICK):
		s2.step(Vector2.ZERO, true)
	check(s2.state == TaxiSim.State.LANDED and absf((s2.pos.x - x0) - (float(pad.dx) - d0)) < 0.6 and absf(float(pad.dx) - d0) > 4.0, "Das gelandete Taxi fährt mit der Plattform (%.0f px)" % (s2.pos.x - x0))
	# Fahrgast wartet auf der fahrenden Plattform und fährt mit
	var a := PassengerActor.new()
	a.setup({"passenger": "T", "gender": "f"}, pad, 0, true)
	var r := Run.new()
	r.start(lv)

func _test_crash_balance() -> void:
	var results := {}
	for v in [35.0, 60.0, 80.0, 100.0, 130.0, 149.0, 151.0, 240.0]:
		var s := TaxiSim.new()
		s.setup(_lvl())
		s._impact(v)
		results[v] = s
	check(results[35.0].hull == 100.0, "Aufprall 35 px/s: kein Schaden")
	check(results[60.0].hull > 80.0 and results[60.0].hull < 100.0, "Aufprall 60 px/s: bereits spürbarer Schaden (%.1f Hülle)" % results[60.0].hull)
	var prev := 101.0
	var mono := true
	for v in [60.0, 80.0, 100.0, 130.0, 149.0]:
		if results[v].hull >= prev:
			mono = false
		prev = results[v].hull
	check(mono, "Schaden steigt mit der Geschwindigkeit streng an")
	check(results[100.0].hull < 60.0 and results[130.0].hull < 40.0 and results[130.0].state != TaxiSim.State.DESTROYED, "100 px/s: über 40 %% Schaden, 130 px/s: schwer, nicht zerstört (%.0f / %.0f)" % [results[100.0].hull, results[130.0].hull])
	check(results[149.0].hull > 0.0 or results[149.0].state == TaxiSim.State.DESTROYED, "149 px/s: knapp unter der Sofortgrenze")
	check(results[151.0].state == TaxiSim.State.DESTROYED and results[151.0].events.any(func(e): return e.type == "destroyed" and e.get("instant", false)), "151 px/s: sofort zerstört")
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
	check(r.money == money0 and not r.carried.is_empty() and not r.carried.pay_info.is_empty(), "Am Tor noch kein Geld: Fahrgast (%s) fährt mit Zahlungsinfo ins nächste Level" % str(r.carried.get("name", "")))
	# Im nächsten Level: er steigt aus, läuft zum Häuschen, erst dort wird bezahlt
	var nxt := Run.new()
	nxt.start(lvl)
	var a := PassengerActor.new()
	a.setup({"passenger": r.carried.name, "gender": r.carried.gender, "look": r.carried.look}, nxt.sim.landed_pad, 0, true)
	a.pay_info = r.carried.pay_info
	a.step_out(nxt.sim.pos.x, nxt.sim.landed_pad)
	nxt.leavers.append(a)
	var paid_at := -1.0
	for i in 800:
		nxt.step(Vector2.ZERO, true)
		if nxt.money > 0.0 and paid_at < 0.0:
			paid_at = nxt.sim.time
	check(paid_at > 0.2 and nxt.delivered == 1, "Ausgangs-Fahrgast wird erst bei Ankunft im Häuschen bezahlt (nach %.1f s, ¢%d)" % [paid_at, int(nxt.money)])

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
	## Die Untergrenze gilt je Pad (Level 1–3: 34 px, bis Level 99 sinkend auf 20 px). Größere Pads im selben Level sind
	## jederzeit erlaubt; verschieden große Pads innerhalb eines Levels sind ausdrücklich zulässig, aber nicht vorgeschrieben.
	var dir := DirAccess.open("res://data/levels")
	var all_widths := {}
	for f in dir.get_files():
		if not f.ends_with(".json"):
			continue
		var lvl := LevelData.load_file("res://data/levels/" + f)
		var min_w := 1e9
		var widths: Array = []
		for id in lvl.pads:
			var p: Dictionary = lvl.pads[id]
			if not lvl.is_passenger_pad(id):
				continue
			min_w = minf(min_w, p.land_window)
			widths.append(int((p.x1 - p.x0) / Tuning.TILE))
			all_widths[widths[widths.size() - 1]] = true
		check(min_w >= Tuning.min_land_window(lvl.number) - 0.01, "%s (Level %d): jedes Passagierpad hat ein freies Landefenster ≥ %.0f px (kleinstes %.0f px, Padbreiten %s Tiles)" % [lvl.id, lvl.number, Tuning.min_land_window(lvl.number), min_w, str(widths)])
	check(all_widths.size() >= 3, "In der Kampagne kommen verschiedene Padgrößen vor (%s Tiles)" % str(all_widths.keys()))

func _test_taxi_scale() -> void:
	check(absf(Tuning.HULL_HALF.x - 10.0 * Tuning.TAXI_SCALE) < 0.01 and absf(Tuning.FOOT_X - 8.0 * Tuning.TAXI_SCALE) < 0.01, "Taxi-Kollisionsmaße sind auf %.0f %% skaliert" % (Tuning.TAXI_SCALE * 100.0))
	# Taxi passt mit Landetoleranz bequem auf das kleinste Pad: Fußabstand + Toleranz < Landefenster
	var lvl := _lvl()
	var s := TaxiSim.new()
	s.setup(lvl)
	check(s.state == TaxiSim.State.LANDED, "Start nach Skalierung sicher gelandet")

## Gleicher Auftrag, gleiche Fahrtzeit: nah am Häuschen gelandet bringt mehr als weit weg (kürzere Gehzeit).
func _dropoff_pay(land_dx: float) -> float:
	var lvl := _lvl()
	var r := Run.new()
	r.start(lvl)
	var job: Dictionary = r.current_job()
	var to_pad: Dictionary = lvl.pads[String(job.to)]
	# Fahrgast sitzt bereits im Taxi, Fahrtzeit steht fest
	_land_on(r, String(job.from))
	for i in 400:
		r.step(Vector2.ZERO, true)
		if r.phase == Run.Phase.CARRYING:
			break
	r.job_clock = 20.0
	_land_on(r, String(job.to))
	r.sim.pos.x = float(to_pad.door_x) + land_dx
	r.sim.vel = Vector2.ZERO
	r.last_vy = 0.0
	var money0 := r.money
	for i in 900:
		r.step(Vector2.ZERO, true)
	return r.money - money0

func _test_pay_at_shelter_rewards_close_landing() -> void:
	var near := _dropoff_pay(14.0)
	var far := _dropoff_pay(64.0)
	check(near > 0.0 and far > 0.0, "Beide Zustellungen werden bezahlt (nah ¢%.1f, weit ¢%.1f)" % [near, far])
	check(near > far, "Näher am Häuschen landen bringt mehr Einkommen (%.1f > %.1f)" % [near, far])

func _test_crash_continues_level() -> void:
	var lvl := _lvl()
	var r := Run.new()
	r.start(lvl)
	# Erster Auftrag erledigt, zweiter (Ausgangs-Fahrgast) an Bord
	r.job_index = lvl.jobs.size() - 1
	r.money = 55.0
	r.delivered = lvl.jobs.size() - 1
	r._spawn_actor(true)
	var last: Dictionary = lvl.jobs[lvl.jobs.size() - 1]
	var lost_name := String(last.passenger)
	_land_on(r, String(last.from))
	for i in 600:
		r.step(Vector2.ZERO, true)
	check(r.phase == Run.Phase.CARRYING and r.exit_open, "Ausgangs-Fahrgast an Bord, Tor offen")
	var fuel_before := r.sim.fuel
	# Absturz
	r.sim.hull = 0.0
	r.sim.state = TaxiSim.State.DESTROYED
	r.step(Vector2.ZERO, true)
	check(r.result == Run.Result.FAILED, "Absturz = Taxi verloren")
	r.respawn_after_crash()
	check(r.result == Run.Result.RUNNING and r.sim.state == TaxiSim.State.LANDED and r.sim.hull == Tuning.HULL_MAX, "Neues Taxi, Level läuft weiter")
	check(r.job_index == lvl.jobs.size() - 1 and r.delivered == lvl.jobs.size() - 1 and absf(r.money - maxf(0.0, 55.0 - Tuning.replacement_fee(lvl.number))) < 0.01, "Erledigtes bleibt erledigt, kein Geld für den verlorenen Fahrgast (Ersatztaxi kostet)")
	check(not r.exit_open and not lvl.exit_open, "Tor schließt sich wieder, bis der Fahrgast erneut an Bord ist")
	check(r.sim.fuel >= Tuning.FUEL_MAX - 0.01, "Neues Taxi startet mit vollem Tank (%.0f)" % r.sim.fuel)
	check(r.actor == null and String(r.current_job().passenger) == lost_name and String(r.current_job().from) == String(last.from), "Derselbe Fahrgast (%s) wartet wieder an seinem Abholpad %s" % [lost_name, String(last.from)])
	for i in 60:
		r.step(Vector2(0, -1), true)                      # abheben (Startpad = Abholpad: Spawn ist bis dahin blockiert)
	for i in int(4.0 / Tuning.TICK):
		r.step(Vector2(0, -0.39), false)
	check(r.actor != null and r.actor.pname == lost_name, "Er tritt wieder aus dem Unterstand (verschwunden nur im Spiel, nicht im Auftrag)")

func _test_min_window_ramp() -> void:
	check(Tuning.min_land_window(1) == Tuning.LAND_WINDOW_EARLY and Tuning.min_land_window(3) == Tuning.LAND_WINDOW_EARLY, "Level 1–3: Mindest-Landefenster %.0f px" % Tuning.LAND_WINDOW_EARLY)
	check(Tuning.min_land_window(50) < Tuning.min_land_window(10) and Tuning.min_land_window(99) == Tuning.LAND_WINDOW_FLOOR, "Mindest-Landefenster sinkt bis Level 99 auf %.0f px" % Tuning.LAND_WINDOW_FLOOR)
	var mono := true
	for n in range(2, 100):
		if Tuning.min_land_window(n) > Tuning.min_land_window(n - 1) + 0.0001:
			mono = false
	check(mono, "Mindest-Landefenster steigt nie von Level zu Level")

func _test_distance_bonus() -> void:
	var l1 := LevelData.load_file("res://data/levels/s1_01.json")
	var l2 := LevelData.load_file("res://data/levels/s1_02.json")
	var l3 := LevelData.load_file("res://data/levels/s1_03.json")
	var short_easy := LevelMetrics.leg_mult(l1, "2", "3")          # kurze, offene Strecke, großes Ziel
	var long_hard := LevelMetrics.leg_mult(l2, "3", "2")           # quer durchs Level, kleineres Ziel
	var shaft := LevelMetrics.leg_mult(l3, "2", "3")               # Schacht, kleines Landefenster
	check(short_easy >= 1.0 and long_hard <= 1.6 and shaft <= 1.6, "Streckenzuschlag liegt in 1,0…1,6 (%.2f / %.2f / %.2f)" % [short_easy, long_hard, shaft])
	check(long_hard > short_easy, "Längere Strecke zahlt mehr (%.2f > %.2f)" % [long_hard, short_easy])
	check(shaft > short_easy, "Schwierigerer Weg (Schacht, kleines Ziel) zahlt mehr (%.2f > %.2f)" % [shaft, short_easy])
	var r := Run.new()
	r.start(l2)
	var j: Dictionary = r.current_job()
	var info := r._make_pay_info(j, 0.0, 0.0)
	check(absf(float(info.fare) - float(j.fare) * r.job_mult(j)) < 0.001, "Fahrpreis = Fare × Streckenzuschlag")

func _test_amount_ticks_down() -> void:
	var r := Run.new()
	r.start(_lvl())
	var v0 := r.prospect()
	for i in 240:
		r.step(Vector2.ZERO, true)
	var v1 := r.prospect()
	for i in 240:
		r.step(Vector2.ZERO, true)
	var v2 := r.prospect()
	check(v0 > v1 and v1 > v2, "Angezeigter Betrag tickt über dem wartenden Fahrgast herunter (%.1f > %.1f > %.1f)" % [v0, v1, v2])
	# Nach dem Aussteigen läuft er bis zum Häuschen weiter herunter
	var a := PassengerActor.new()
	a.setup({"passenger": "X", "gender": "f"}, r.level.pads["3"], 0, true)
	a.pay_info = {"fare": 60.0, "par": 20.0, "base": 10.0, "penalty": 0.0}
	a.step_out(a.pad.wait_x + 40.0, r.level.pads["3"])
	var p0 := a.pay_for(0.0)
	for i in 60:
		a.step(Tuning.TICK)
	var p1 := a.pay_for(0.0)
	for i in 60:
		a.step(Tuning.TICK)
	check(p0 > p1 and p1 > a.pay_for(0.0), "Auf dem Weg zum Häuschen tickt der Betrag weiter herunter (%.2f > %.2f)" % [p0, p1])

func _price_series(seed: int, seconds: float) -> Array:
	var r := Run.new()
	r.start(_lvl(), -1.0, 0.0, seed)
	var changes: Array = [[0.0, r.price_base]]
	var prev := r.price_base
	for i in int(seconds / Tuning.TICK):
		r._update_prices(Tuning.TICK)
		if r.price_base != prev:
			changes.append([r.level_time, r.price_base])
			prev = r.price_base
	return changes

func _test_fuel_prices() -> void:
	var lvl := _lvl()
	var all_in_range := true
	var interval_ok := true
	var step_ok := true
	var min_changes := 1000
	for seed in [1, 2, 3, 42]:
		var ser := _price_series(seed, 1500.0)
		min_changes = mini(min_changes, ser.size())
		for i in ser.size():
			var price: float = ser[i][1]
			if price < lvl.fuel_price_min - 0.001 or price > lvl.fuel_price_max + 0.001:
				all_in_range = false
			if i >= 2:
				var dt: float = ser[i][0] - ser[i - 1][0]
				if dt < lvl.price_every.x - 0.05 or dt > lvl.price_every.y + 0.05:
					interval_ok = false
			if i >= 1 and absf(float(ser[i][1]) - float(ser[i - 1][1])) < Tuning.PRICE_MIN_STEP - 0.001:
				step_ok = false
	check(all_in_range, "Spritpreis bleibt immer im Bereich %.2f–%.2f (nie zu billig, nie zu teuer)" % [lvl.fuel_price_min, lvl.fuel_price_max])
	check(interval_ok, "Preiswechsel in zufälligen Abständen zwischen %.0f und %.0f s" % [lvl.price_every.x, lvl.price_every.y])
	check(step_ok, "Jeder Preiswechsel ist deutlich spürbar (≥ %.2f)" % Tuning.PRICE_MIN_STEP)
	check(min_changes >= 20, "Der Preis wechselt im Level mehrfach (mind. %d Wechsel in 1500 s)" % min_changes)
	var a := _price_series(7, 400.0)
	var b := _price_series(7, 400.0)
	var c := _price_series(8, 400.0)
	check(str(a) == str(b), "Preisverlauf ist reproduzierbar (gleicher Seed = gleiche Preise)")
	check(str(a) != str(c), "Anderer Seed = anderer Preisverlauf")
	var r := Run.new()
	r.start(lvl, -1.0, 0.0, 5)
	var p0 := r.fuel_price()
	r.pump_touches = 3
	check(r.fuel_price() <= lvl.fuel_price_max * Tuning.PRICE_HARD_CAP + 0.001 and r.fuel_price() > p0, "Berührungen erhöhen den Preis, gedeckelt bei %.2f" % (lvl.fuel_price_max * Tuning.PRICE_HARD_CAP))

func _test_pump_touch_and_explosion() -> void:
	var lvl := _lvl()
	var r := Run.new()
	r.start(lvl, 80.0, 100.0, 11)
	check(lvl.pumps.size() == 1 and lvl.pumps[0].pad == "F", "Level hat eine Zapfsäule am Tankpad")
	var rect: Rect2 = lvl.pumps[0].rect
	var base0 := r.price_base
	var price0 := r.fuel_price()
	# Taxi berührt die Säule (fliegend, direkt daneben)
	r.sim.state = TaxiSim.State.FLYING
	r.sim.landed_pad = {}
	r.sim.vel = Vector2.ZERO
	r.sim.pos = Vector2(rect.end.x + Tuning.HULL_HALF.x + 0.5, rect.get_center().y)
	r.log.clear()
	r._check_pump(Tuning.TICK)
	check(r.pump_touches == 1 and r.log.any(func(e): return e.type == "pump_touched" and e.stage == 1), "Berührung zählt (Stufe 1)")
	check(r.fuel_price() >= price0 * 1.2, "Berührung steigert den Spritpreis sofort (%.2f → %.2f)" % [price0, r.fuel_price()])
	r.log.clear()
	r._check_pump(Tuning.TICK)
	check(r.pump_touches == 1, "Dauerkontakt zählt nicht mehrfach (Abklingzeit %.1f s)" % Tuning.PUMP_TOUCH_COOLDOWN)
	for i in int(1.3 / Tuning.TICK):
		r._check_pump(Tuning.TICK)
	check(r.pump_touches == 2 and not r.station_down(), "Nach der Abklingzeit zählt die zweite Berührung (Stufe 2), Station noch in Betrieb")
	for i in int(1.3 / Tuning.TICK):
		r._check_pump(Tuning.TICK)
	check(r.pump_touches == 3 and r.station_down() and not r.pump_broken, "Dritte Berührung: Station sofort außer Betrieb, Explosion folgt")
	var exploded := false
	for i in int(1.0 / Tuning.TICK):
		r.log.clear()
		r._check_pump(Tuning.TICK)
		if r.log.any(func(e): return e.type == "pump_exploded"):
			exploded = true
	check(exploded and r.pump_broken, "Nach kurzer Verzögerung explodiert die Tankstelle und ist defekt")
	# Defekte Station gibt keinen Sprit mehr
	_land_on(r, "F")
	r.sim.fuel = 20.0
	r.money = 100.0
	var warned := false
	for i in 240:
		r.log.clear()
		r._service_pad(Tuning.TICK)
		if r.log.any(func(e): return e.type == "pump_out"):
			warned = true
	check(r.sim.fuel == 20.0 and r.money == 100.0 and warned, "Defekte Station tankt nicht mehr (auch nicht kostenlos) und meldet „außer Betrieb“")
	# Intakte Station tankt gegen Credits zum aktuellen Preis
	var r2 := Run.new()
	r2.start(lvl, 80.0, 100.0, 11)
	_land_on(r2, "F")
	r2.sim.fuel = 60.0
	var money_before := r2.money
	for i in 240:
		r2._service_pad(Tuning.TICK)
	var gained := r2.sim.fuel - 60.0
	check(gained > 5.0 and absf((money_before - r2.money) - gained * r2.fuel_price()) < 0.05, "Tanken kostet Menge × aktueller Preis (%.1f Einheiten für ¢%.2f)" % [gained, money_before - r2.money])

func _test_fuel_pad_variety() -> void:
	var widths := {}
	var dir := DirAccess.open("res://data/levels")
	for f in dir.get_files():
		if not f.ends_with(".json"):
			continue
		var lvl := LevelData.load_file("res://data/levels/" + f)
		if lvl.pads.has("F"):
			widths[int((lvl.pads["F"].x1 - lvl.pads["F"].x0) / Tuning.TILE)] = true
	check(widths.size() >= 4, "Tankpads sind unterschiedlich groß (%s Tiles)" % str(widths.keys()))

func _test_pump_level_rules() -> void:
	var dir := DirAccess.open("res://data/levels")
	for f in dir.get_files():
		if not f.ends_with(".json"):
			continue
		var lvl := LevelData.load_file("res://data/levels/" + f)
		if not lvl.pads.has("F"):
			continue
		var pad: Dictionary = lvl.pads["F"]
		var ok_pump := false
		for pm in lvl.pumps:
			if pm.pad == "F" and pm.side != 0 and pm.rect.size.y >= Tuning.TILE * 2.0 - 0.1:
				ok_pump = true
		check(ok_pump, "%s: Tankpad hat eine 2 Tiles hohe Zapfsäule am Padende" % lvl.id)
		check(pad.land_window >= 28.0, "%s: freies Landefenster am Tankpad ≥ 28 px (%.0f px)" % [lvl.id, pad.land_window])
		check(lvl.fuel_price_min >= 1.0 and lvl.fuel_price_max <= 14.0 and lvl.fuel_price_min < lvl.fuel_price_max - 0.8, "%s: Preisbereich ist sinnvoll (%.2f–%.2f)" % [lvl.id, lvl.fuel_price_min, lvl.fuel_price_max])

func _test_streak_bonus() -> void:
	var r := Run.new()
	r.start(_lvl())
	r.log.clear()
	for i in 3:
		r._evaluate_landing({"vy": 12.0, "vx": 4.0, "tilt": 0.02})
	check(r.streak == 3 and r.best_streak == 3 and r.perfect_count == 3, "Drei perfekte Landungen in Folge = Serie 3")
	r._evaluate_landing({"vy": 30.0, "vx": 4.0, "tilt": 0.02})
	check(r.streak == 0 and r.best_streak == 3 and r.log.any(func(e): return e.type == "streak_lost"), "Harte Landung (30 px/s) unterbricht die Serie")
	r._evaluate_landing({"vy": 10.0, "vx": 20.0, "tilt": 0.02})
	check(r.streak == 0, "Zu seitlich (20 px/s) ist nicht perfekt")
	r._evaluate_landing({"vy": 10.0, "vx": 3.0, "tilt": 0.12})
	check(r.streak == 0, "Zu schräg (7°) ist nicht perfekt")
	# Bonus: +5 % je Stufe, gedeckelt bei +30 %
	var info := {"fare": 100.0, "par": 20.0, "base": 0.0, "penalty": 0.0, "combo": 0}
	var a := PassengerActor.new()
	a.pay_info = info.duplicate()
	var p0 := a.pay_for(0.0)
	a.pay_info["combo"] = 4
	var p4 := a.pay_for(0.0)
	a.pay_info["combo"] = 50
	var pmax := a.pay_for(0.0)
	check(absf(p4 / p0 - 1.20) < 0.001 and absf(pmax / p0 - 1.30) < 0.001, "Serie 4 = +20 %%, Obergrenze +30 %% (%.2f / %.2f)" % [p4 / p0, pmax / p0])
	# Bad-Landing/Absturz setzen zurück
	r.streak = 4
	r.log.clear()
	r.sim.events = [{"type": "bad_landing", "reason": "speed"}]
	r._break_streak()
	check(r.streak == 0, "Misslungene Landung beendet die Serie")
	r.streak = 5
	r.sim.hull = 0.0
	r.sim.state = TaxiSim.State.DESTROYED
	r.respawn_after_crash()
	check(r.streak == 0, "Absturz beendet die Serie")
	# Sim liefert Geschwindigkeit/Neigung im Landeereignis
	var s2 := TaxiSim.new()
	var lvl := _lvl()
	s2.setup(lvl)
	s2.state = TaxiSim.State.FLYING
	s2.landed_pad = {}
	var pad: Dictionary = lvl.pads["2"]
	s2.pos = Vector2(pad.land_mid, pad.row * Tuning.TILE - 30.0)
	s2.vel = Vector2(3.0, 12.0)
	s2.gear = 1.0
	var ev: Dictionary = {}
	for i in 900:
		s2.step(Vector2(0, -0.58), true)
		for e in s2.events:
			if e.type == "landed":
				ev = e
		if not ev.is_empty():
			break
	check(not ev.is_empty() and ev.has("vx") and ev.has("tilt"), "Landeereignis enthält Seitengeschwindigkeit und Neigung")

func _test_music_assets() -> void:
	var themes := ["menu"]
	for i in 20:
		themes.append("t%02d" % i)
	var ok_all := true
	var lens_ok := true
	for th in themes:
		var lens: Array = []
		for st in ["A", "B", "C"]:
			var path := "res://assets/audio/music/%s_%s.ogg" % [th, st]
			if not ResourceLoader.exists(path):
				ok_all = false
				continue
			var stream: AudioStream = load(path)
			lens.append(stream.get_length())
		if lens.size() == 3:
			if absf(lens[0] - lens[1]) > 0.06 or absf(lens[0] - lens[2]) > 0.06 or lens[0] < 45.0:
				lens_ok = false
	check(ok_all, "Alle 21 Musikthemen (Menü + 20 Level-Themen) haben drei Schichten (A/B/C)")
	var mus = load("res://src/core/music.gd")
	check(mus.theme_for_level(1) == "t00" and mus.theme_for_level(5) == "t00" and mus.theme_for_level(6) == "t01" and mus.theme_for_level(99) == "t19", "Thema wechselt alle 5 Level")
	check(lens_ok, "Schichten eines Themas sind gleich lang (synchron loopbar, ≥ 45 s)")

func _test_cosmetics_data() -> void:
	var f := FileAccess.open("res://data/cosmetics.json", FileAccess.READ)
	var d = JSON.parse_string(f.get_as_text())
	var items: Array = d.items
	var tex_ok := true
	var names_ok := true
	var unlock_ok := true
	var de := _read_json("res://data/i18n/de.json")
	var en := _read_json("res://data/i18n/en.json")
	var ids := {}
	var free_paint := false
	for it in items:
		ids[it.id] = true
		if not ResourceLoader.exists("res://assets/art/%s_%s.png" % ["taxi" if it.kind == "paint" else "sticker", it.id]) and it.id != "none":
			tex_ok = false
		if String(it.name.get("de", "")) == "" or String(it.name.get("en", "")) == "":
			names_ok = false
		if it.unlock == null:
			if it.kind == "paint":
				free_paint = true
		else:
			var key := "COSM_REQ_" + String(it.unlock.stat).to_upper()
			if not de.has(key) or not en.has(key) or not Cosmetics_STATS.has(it.unlock.stat) or int(it.unlock.min) < 1:
				unlock_ok = false
	check(ids.size() == items.size(), "Kosmetik-IDs sind eindeutig (%d Einträge)" % items.size())
	check(tex_ok, "Zu jeder Lackierung/jedem Aufkleber gibt es eine Grafik")
	check(names_ok, "Alle Kosmetik-Namen sind zweisprachig")
	check(unlock_ok and free_paint, "Freischaltbedingungen haben gültige Statistik und Übersetzung; ein Standardtaxi ist frei")

const Cosmetics_STATS := ["levels_done", "perfect_landings", "deliveries", "best_streak", "crashes", "pump_explosions"]

func _test_voice_lines_complete() -> void:
	var f := FileAccess.open("res://data/voice_lines.json", FileAccess.READ)
	var d = JSON.parse_string(f.get_as_text())
	var missing: Array = []
	var total := 0
	for group in d:
		for lang in d[group]:
			for key in d[group][lang]:
				if String(d[group][lang][key]).strip_edges() == "":
					missing.append("%s/%s/%s (Text leer)" % [group, lang, key])
				var voices: Array = ["f0", "f1", "m0", "m1"] if group == "passenger_extra" else [group]
				for v in voices:
					total += 1
					if not ResourceLoader.exists("res://assets/audio/voice/%s/%s_%s.ogg" % [lang, v, key]):
						missing.append("%s/%s_%s" % [lang, v, key])
	check(missing.is_empty() and total > 50, "Alle %d Sondersprachzeilen (Tankwart, Zentrale, Passagier-Reaktionen) haben Text und Clip %s" % [total, str(missing.slice(0, 4))])

func _key(code: int) -> InputEventKey:
	var e := InputEventKey.new()
	e.physical_keycode = code
	return e

func _test_controls_remap() -> void:
	var c: Node = load("res://src/core/controls.gd").new()
	c.path = "user://test_controls.cfg"
	if FileAccess.file_exists(c.path):
		DirAccess.remove_absolute(c.path)
	c._ready()
	var all_ok := true
	for a in c.REMAPPABLE:
		if c.events_of(a, "kb").is_empty() or c.events_of(a, "pad").is_empty():
			all_ok = false
	check(all_ok, "Alle belegbaren Aktionen haben Standard-Tasten und Gamepad-Belegung")
	check(InputMap.event_is_action(_key(KEY_W), "thrust_up") and InputMap.event_is_action(_key(KEY_SPACE), "gear") and InputMap.event_is_action(_key(KEY_ESCAPE), "pause"), "Standard: W = Schub hoch, Leertaste = Fahrwerk, Esc = Pause")
	# Umbelegen
	var swapped: String = c.set_slot("thrust_up", "kb", 0, _key(KEY_I))
	check(swapped == "" and InputMap.event_is_action(_key(KEY_I), "thrust_up") and not InputMap.event_is_action(_key(KEY_W), "thrust_up"), "Umbelegen: I ersetzt W für Schub hoch")
	check(InputMap.event_is_action(_key(KEY_UP), "thrust_up"), "Zweite Belegung (Pfeil hoch) bleibt erhalten")
	# Konflikt: R gehört dem Neustart -> Tausch
	swapped = c.set_slot("gear", "kb", 0, _key(KEY_R))
	check(swapped == "restart" and InputMap.event_is_action(_key(KEY_R), "gear") and InputMap.event_is_action(_key(KEY_SPACE), "restart") and not InputMap.event_is_action(_key(KEY_R), "restart"), "Konflikt: Doppelte Belegung wird getauscht (Fahrwerk=R, Neustart=Leertaste)")
	# Gamepad: Stickachse und Knopf
	var ax := InputEventJoypadMotion.new()
	ax.axis = JOY_AXIS_RIGHT_X
	ax.axis_value = -1.0
	c.set_slot("thrust_left", "pad", 0, ax)
	var probe := InputEventJoypadMotion.new()
	probe.axis = JOY_AXIS_RIGHT_X
	probe.axis_value = -0.9
	check(InputMap.event_is_action(probe, "thrust_left"), "Gamepad: rechte Stick-Richtung für Schub links belegbar")
	var btn := InputEventJoypadButton.new()
	btn.button_index = JOY_BUTTON_X
	c.set_slot("gear", "pad", 0, btn)
	var probe_b := InputEventJoypadButton.new()
	probe_b.button_index = JOY_BUTTON_X
	check(InputMap.event_is_action(probe_b, "gear"), "Gamepad: X für Fahrwerk belegbar")
	# Pause und Menüs bleiben fest
	check(InputMap.event_is_action(_key(KEY_ESCAPE), "pause") and c.REMAPPABLE.find("pause") == -1, "Pause (Esc/Start) ist nicht belegbar und bleibt erreichbar")
	# Speichern und Laden
	c.apply_defaults()
	c.set_slot("thrust_down", "kb", 0, _key(KEY_K))
	check(FileAccess.file_exists(c.path), "Belegung wird gespeichert")
	c.apply_defaults()
	check(InputMap.event_is_action(_key(KEY_S), "thrust_down"), "Zwischenzustand: Standard wiederhergestellt")
	c.load_bindings()
	check(InputMap.event_is_action(_key(KEY_K), "thrust_down") and not InputMap.event_is_action(_key(KEY_S), "thrust_down"), "Gespeicherte Belegung wird geladen")
	check(c.hint_text("keyboard").contains("K") and c.hint_text("gamepad") != "", "HUD-Hinweis folgt der aktuellen Belegung")
	# Defekte/unvollständige Dateien
	var f := FileAccess.open(c.path, FileAccess.WRITE)
	f.store_string("das ist keine gültige cfg [[[")
	f.close()
	c.apply_defaults()
	c.load_bindings()
	check(InputMap.event_is_action(_key(KEY_W), "thrust_up"), "Defekte Belegungsdatei: Standard bleibt aktiv, kein Absturz")
	var cf := ConfigFile.new()
	cf.set_value("bindings", "gear", [{"t": "key", "c": KEY_G}])          # nur Tastatur, kein Gamepad -> unvollständig
	cf.save(c.path)
	c.apply_defaults()
	c.load_bindings()
	check(InputMap.event_is_action(_key(KEY_SPACE), "gear") and not InputMap.event_is_action(_key(KEY_G), "gear"), "Unvollständige Belegung wird verworfen (Standard bleibt)")
	c.reset_defaults()
	check(not FileAccess.file_exists(c.path), "Zurücksetzen löscht die gespeicherte Belegung")
	c.free()

func _test_medals() -> void:
	var lvl := LevelData.load_file("res://data/levels/s1_02.json")
	var r := Run.new()
	r.start(lvl)
	var sum_par := 0.0
	var money_t := 0.0
	for j in r.jobs:                         # Arbeitskopie: Fahrpreise wie im Spiel (Skalierung und Mindestpreis)
		sum_par += float(j.par)
		if String(j.to) != "exit":
			money_t += float(j.fare) * r.job_mult(j)
	check(absf(r.time_target() - (sum_par * 1.2 + 10.0)) < 0.01 and absf(r.money_target() - money_t) < 0.01, "Medaillen-Ziele: Zeit %.0f s, Einkommen ¢%.0f aus den Auftragsdaten" % [r.time_target(), r.money_target()])
	r.level_time = r.time_target() - 1.0
	r.earned = r.money_target() * 1.2
	r.best_streak = 3
	var m := r.medals()
	check(m.time and m.clean and m.pro, "Alle drei Medaillen bei guter Leistung")
	r.level_time = r.time_target() + 1.0
	check(not r.medals().time, "Zu langsam: keine Zeit-Medaille")
	r.damage_taken = 25.0
	check(not r.medals().clean, "Zu viel Schaden: keine Sauber-Medaille")
	r.damage_taken = 0.0
	r.squashes = 1
	check(not r.medals().clean, "Fahrgast erschreckt: keine Sauber-Medaille")
	r.squashes = 0
	r.pump_touches = 1
	check(not r.medals().clean, "Zapfsäule berührt: keine Sauber-Medaille")
	r.pump_touches = 0
	r.respawns = 1
	check(not r.medals().clean, "Leben verloren: keine Sauber-Medaille")
	r.earned = 1.0
	check(not r.medals().pro, "Zu wenig verdient: keine Meister-Medaille")

func _rm(path: String) -> void:
	for suffix in ["", ".bad", ".tmp"]:
		if FileAccess.file_exists(path + suffix):
			DirAccess.remove_absolute(path + suffix)

func _test_save_robust() -> void:
	var sv: Node = load("res://src/core/save.gd").new()
	sv.path = "user://test_save.json"
	_rm(sv.path)
	var f := FileAccess.open(sv.path, FileAccess.WRITE)
	f.store_string("{ defekt [[[")
	f.close()
	sv.load_save()
	check(sv.data.completed.is_empty() and FileAccess.file_exists(sv.path + ".bad"), "Defekter Speicherstand: Standard geladen, Original als .bad gesichert")
	_rm(sv.path)
	f = FileAccess.open(sv.path, FileAccess.WRITE)
	f.store_string(JSON.stringify({"completed": "kaputt"}))
	f.close()
	sv.load_save()
	check(sv.data.completed is Dictionary and sv.data.completed.is_empty(), "Falsche Struktur wird abgefangen")
	_rm(sv.path)
	sv.complete_level("s1_01", 60.0, 100.0, 50.0, {"time": true, "clean": false, "pro": false})
	sv.complete_level("s1_01", 70.0, 120.0, 60.0, {"time": false, "clean": true, "pro": false})
	var mm: Dictionary = sv.medals_of("s1_01")
	check(sv.best_time("s1_01") == 60.0 and mm.time and mm.clean and not mm.pro, "Bestzeit bleibt, Medaillen werden über Läufe vereint")
	check(int(sv.data.stats.credits_total) == 110, "Verdiente Credits summieren sich (%d)" % int(sv.data.stats.credits_total))
	var sv2: Node = load("res://src/core/save.gd").new()
	sv2.path = sv.path
	sv2.load_save()
	check(sv2.is_completed("s1_01") and sv2.best_time("s1_01") == 60.0, "Speichern und Neuladen (Fortschritt bleibt nach Neustart)")
	check(sv2.is_unlocked(["s1_01", "s1_02"], 1) and (Save.DEBUG_UNLOCK_ALL or not sv2.is_unlocked(["s1_01", "s1_02", "s1_03"], 2)), "Freischaltung: Nachfolger erst nach Abschluss des Vorgängers (Debug: alles frei)")
	_rm(sv.path)
	sv.free()
	sv2.free()

func _test_settings_robust() -> void:
	var st: Node = load("res://src/core/settings.gd").new()
	st.path = "user://test_settings.cfg"
	_rm(st.path)
	var defaults_music: float = st.values.music
	var f := FileAccess.open(st.path, FileAccess.WRITE)
	f.store_string("keine [gültige cfg")
	f.close()
	st.load_settings()
	check(st.values.music == defaults_music, "Defekte Einstellungsdatei: Standardwerte")
	var cf := ConfigFile.new()
	cf.set_value("settings", "music", 7.5)
	cf.set_value("settings", "sfx", "laut")
	cf.set_value("settings", "vibration", -3.0)
	cf.set_value("settings", "fps_cap", 144)
	cf.set_value("settings", "unbekannt", 1)
	cf.save(st.path)
	st.load_settings()
	check(st.values.music == 1.0 and st.values.vibration == 0.0, "Werte außerhalb 0..1 werden begrenzt")
	check(typeof(st.values.sfx) == TYPE_FLOAT and st.values.sfx == 0.9, "Falscher Typ wird ignoriert (Standard bleibt)")
	check(int(st.values.fps_cap) == 144 and not st.values.has("unbekannt"), "Gültige Werte werden übernommen, unbekannte Schlüssel ignoriert")
	_rm(st.path)
	st.free()
