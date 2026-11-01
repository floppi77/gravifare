class_name Tutorial
extends Node
## Tutorial-Regie: Das Skript läuft ab, während der Spieler fliegt. Jeder Schritt spricht eine Zeile (Stimme "i0", Schlüssel tut_*,
## Deutsch und Englisch), beleuchtet den erklärten Bereich (SpotView, kein Rahmen) und wartet danach – falls nötig – auf eine Handlung.
## Das Tutorial greift nur über Run-Felder ein (Tankstand, Credits, Zusatzfahrgast, Sperren) und schreibt keinen Spielstand außer „fertig“.
## Reihenfolge: Anzeigen erklären (Taxi gesperrt) → Fahrwerk einfahren → Parcours durch Tore → Fahrwerk, Tanken (Sprit, Preis) →
## Landung (hart bis zur Zerstörung, dann sanft) → Pflichtfahrgast → optionaler Fahrgast → Lebensstation → Ausgangsfahrgast und Tor.

var game: Node
var run: Run
var hud: Control
var spot: Control
var cam: Camera2D
var gates: GateField = null
var steps: Array = []
var idx := -1
var t := 0.0                    # Zeit im aktuellen Schritt
var speak_len := 0.0            # Länge der Sprachzeile des Schritts
var waiting := false
var wait_t := 0.0
var gap_t := 0.0
var flags := {}
var finished := false
var _spoke_crash := false
var locked := true              # Steuerung und Fahrwerk gesperrt, bis das Starten erklärt wird (das Taxi bleibt auf dem Startpad)

# HUD-Bereiche (logische Pixel)
const R_FUEL := Rect2(2, 2, 70, 12)
const R_HULL := Rect2(73, 2, 70, 12)
const R_MONEY := Rect2(145, 1, 56, 14)
const R_LIVES := Rect2(202, 1, 60, 14)
const R_LEVEL := Rect2(348, 1, 112, 14)
const R_COUNT := Rect2(458, 1, 34, 14)
const R_PRICE := Rect2(492, 1, 84, 14)
const R_GAUGE := Rect2(576, 1, 62, 14)
const R_TASK := Rect2(2, 335, 440, 16)
const R_FARE := Rect2(446, 335, 192, 16)
const HUD_RECTS := [R_FUEL, R_HULL, R_MONEY, R_LIVES, R_LEVEL, R_COUNT, R_PRICE, R_GAUGE, R_TASK, R_FARE]

## Parcours (Mittelpunkte in Weltpixeln): links an der Lebensplattform hoch, oben nach rechts, runter zur Zwei, zurück zur Eins.
const COURSE := [Vector2(44, 214), Vector2(44, 118), Vector2(150, 46), Vector2(400, 64), Vector2(548, 118), Vector2(528, 232), Vector2(330, 236), Vector2(150, 236)]

func setup(g: Node, r: Run, h: Control, sp: Control, c: Camera2D) -> void:
	game = g
	run = r
	hud = h
	spot = sp
	cam = c
	run.extra_timer = 1.0e9             # Zusatzfahrgäste erscheinen nur auf Befehl des Skripts
	run.pickup_locked = true            # kein Fahrgast, bis das Skript erklärt, wie man ihn abholt
	run.prices_frozen = true            # der Spritpreis ändert sich nur auf Befehl des Skripts
	run.actor = null                    # Mika erscheint erst im Schritt tut_job
	if g.has_node("World"):
		gates = GateField.new()
		gates.points = COURSE
		g.get_node("World").add_child(gates)
	_build()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--tut-step="):          # Dev: Skript bei Schritt N beginnen (Screenshots)
			idx = int(a.substr(11)) - 1
			locked = false
	_next()

func _exit_tree() -> void:
	if gates != null and is_instance_valid(gates):
		gates.queue_free()
	if hud != null and is_instance_valid(hud):
		hud.set("gauge_override", [])

# ---------------------------------------------------------------- Skript
func _build() -> void:
	steps = [
		{"key": "tut_welcome", "spots": func(): return [_taxi_rect()]},
		{"key": "tut_hud_fuel", "spots": func(): return [R_FUEL]},
		{"key": "tut_hud_hull", "spots": func(): return [R_HULL]},
		{"key": "tut_hud_money", "spots": func(): return [R_MONEY, R_LIVES]},
		{"key": "tut_hud_level", "spots": func(): return [R_LEVEL, R_COUNT]},
		{"key": "tut_hud_price", "spots": func(): return [R_PRICE]},
		{"key": "tut_hud_gauge", "spots": func(): return [R_GAUGE], "gauge": true},
		{"key": "tut_gear_in", "enter": _enter_unlock,
			"wait": func(): return not run.sim.gear_cmd, "timeout": 60.0},
		{"key": "tut_fly", "enter": _enter_course,
			"wait": func(): return flags.get("course_done", false), "timeout": 240.0},
		{"key": "tut_fly_ok"},
		{"key": "tut_gear", "wait": func(): return run.sim.gear_cmd, "timeout": 40.0},
		{"key": "tut_fuel_low", "enter": func(): run.sim.fuel = minf(run.sim.fuel, 22.0),
			"spots": func(): return [_fuel_rect()],
			"wait": func(): return _landed_on("F"), "timeout": 120.0},
		{"key": "tut_refuel", "spots": func(): return [_fuel_rect(), R_FUEL],
			"wait": func(): return run.sim.fuel >= 35.0 or not _landed_on("F"), "timeout": 12.0},
		{"key": "tut_credit", "enter": _enter_credit, "spots": func(): return [R_MONEY, R_FUEL],
			"wait": func(): return run.sim.fuel >= 92.0 or not _landed_on("F"), "timeout": 30.0},
		{"key": "tut_price", "enter": _enter_price, "spots": func(): return [R_PRICE]},
		{"key": "tut_landing", "spots": func(): return [R_GAUGE, R_HULL], "gauge": true},
		{"key": "tut_hard", "enter": func(): flags["crashed"] = false,
			"wait": func(): return flags.get("crashed", false), "timeout": 240.0},
		{"key": "tut_crash_ok", "spots": func(): return [R_LIVES, _taxi_rect()]},
		{"key": "tut_soft", "enter": func(): flags["land3"] = false,
			"spots": func(): return [_pad_rect("3"), R_GAUGE],
			"wait": func(): return flags.get("land3", false), "timeout": 240.0},
		{"key": "tut_soft_react"},
		{"key": "tut_job", "enter": _enter_job, "spots": func(): return [_pad_rect("2"), R_TASK],
			"wait": func(): return flags.get("boarded_main", false), "timeout": 180.0},
		{"key": "tut_pay", "spots": func(): return [R_FARE, _pad_rect("3")],
			"wait": func(): return flags.get("delivered_main", false), "timeout": 180.0},
		{"key": "tut_delivered", "enter": _enter_delivered},
		{"key": "tut_extra", "enter": _enter_extra, "spots": func(): return [_extra_rect()],
			"after_speech": func(): run.extra_locked = false,
			"wait": func(): return flags.get("boarded_extra", false) or flags.get("extra_done", false), "timeout": 150.0},
		{"key": "tut_extra_dest", "spots": func(): return [_extra_dest_rect()],
			"wait": func(): return flags.get("extra_done", false), "timeout": 150.0, "after": _drop_waiting_extras},
		{"key": "tut_life", "enter": _give_life_money, "spots": func(): return [_pad_rect("L"), R_LIVES],
			"wait": func(): return flags.get("life_bought", false), "timeout": 90.0},
		{"key": "tut_exit", "enter": func(): run.pickup_locked = false, "spots": func(): return [_pad_rect("1"), _gate_rect()],
			"wait": func(): return run.exit_open, "timeout": 180.0},
		{"key": "tut_gate", "spots": func(): return [_gate_rect()]},
	]

func _enter_unlock() -> void:
	locked = false

func _enter_course() -> void:
	flags["course_done"] = false
	if gates != null:
		gates.start()

func _enter_credit() -> void:
	run.money += 50.0                         # ab 35 % kostet Sprit Geld: kleines Startguthaben für die Übung

func _enter_price() -> void:
	run.force_price_change()                  # ein einziger, sichtbarer Preiswechsel; danach bleibt der Preis fest (prices_frozen)

## Mika erscheint erst jetzt: Sie tritt aus ihrem Häuschen, die Fahrgastsperre fällt.
func _enter_job() -> void:
	run.pickup_locked = false
	if run.actor == null:
		run._spawn_actor(false)

func _enter_delivered() -> void:
	flags["extra_done"] = false
	flags["boarded_extra"] = false
	run.pickup_locked = true                  # Odo erscheint erst am Ende

## Optionaler Fahrgast an Plattform 2 mit Ziel 1; er steigt erst ein, wenn die Erklärung zu Ende gesprochen ist.
func _enter_extra() -> void:
	run.extras_enabled = true
	run.extra_locked = true
	run._spawn_extra("2", "1")

func _give_life_money() -> void:
	run.lives = 4
	game.call("tutorial_set_lives", 4)
	run.money = maxf(run.money, Tuning.LIFE_PRICE)

## Zusatzfahrgast, der nach der Übung noch wartet, geht ohne Folgen (nichts bleibt für später liegen).
func _drop_waiting_extras() -> void:
	for e in run.extras.duplicate():
		if int(e.state) == Run.ES.WAIT:
			run.extras.erase(e)

# ---------------------------------------------------------------- Ablauf
func _next() -> void:
	idx += 1
	if idx >= steps.size():
		spot.set_spots([])
		spot.say("", "")
		_gauge(false)
		return
	t = 0.0
	waiting = false
	wait_t = 0.0
	gap_t = 0.0
	var st: Dictionary = steps[idx]
	var key := String(st.key)
	if key == "tut_soft_react":
		key = "tut_soft_ok" if flags.get("soft_ok", false) else "tut_soft_meh"
		st["key"] = key
	if st.has("enter"):
		(st.enter as Callable).call()
	_speak(key)

func _speak(key: String) -> void:
	var info: Dictionary = game.call("tutorial_speak", key)        # spielt den Clip, liefert Länge und Text (Untertitel)
	speak_len = float(info.len)
	spot.say(tr("SPK_INSTRUCTOR"), String(info.text))

func _process(delta: float) -> void:
	if game == null or finished or idx < 0 or idx >= steps.size():
		return
	var paused: bool = game.paused
	game.call("tutorial_voice_pause", paused)
	if paused:
		return
	var st: Dictionary = steps[idx]
	t += delta
	_tick_gates()
	if OS.get_cmdline_user_args().has("--tut-debug") and Engine.get_process_frames() % 120 == 0:
		print("tut idx=%d key=%s t=%.1f speak=%.1f waiting=%s" % [idx, st.key, t, speak_len, waiting])
	if st.has("spots"):
		spot.set_spots(_to_screen((st.spots as Callable).call()))
	else:
		spot.set_spots([])
	_gauge(bool(st.get("gauge", false)))
	if t < speak_len + 0.15:
		return
	if st.has("after_speech") and not st.get("_speech_done", false):
		st["_speech_done"] = true
		(st.after_speech as Callable).call()
	if st.has("wait") and not waiting:
		waiting = true
	if waiting:
		wait_t += delta
		var done: bool = (st.wait as Callable).call()
		if not done and wait_t < float(st.get("timeout", 60.0)):
			return
		if done:
			waiting = false
	gap_t += delta
	if gap_t >= float(st.get("gap", 0.7)):
		spot.say("", "")
		if st.has("after"):
			(st.after as Callable).call()
		_next()

## Landeanzeige im Tutorial: erst Ausschläge in allen drei Balken, dann alle sicher unter der weißen Marke.
func _gauge(on: bool) -> void:
	if hud == null or not is_instance_valid(hud):
		return
	if not on:
		var cur = hud.get("gauge_override")
		if cur != null and not (cur as Array).is_empty():
			hud.set("gauge_override", [])
		return
	var span := maxf(speak_len, 4.0)
	var u := clampf(t / span, 0.0, 1.0)
	var vals: Array
	if u < 0.5:
		var w := t * 3.2
		vals = [0.55 + 0.75 * absf(sin(w)), 0.35 + 0.85 * absf(sin(w * 0.8 + 1.0)), 0.5 + 0.7 * absf(sin(w * 0.6 + 2.0))]
	else:
		vals = [0.28 + 0.06 * sin(t * 3.0), 0.2 + 0.05 * sin(t * 2.3), 0.25 + 0.05 * sin(t * 2.7)]
	hud.set("gauge_override", vals)

## Welt-Rechtecke werden in Bildschirmkoordinaten umgerechnet (HUD-Rechtecke liegen schon dort).
func _to_screen(list: Array) -> Array:
	var out: Array = []
	var center := cam.get_screen_center_position() if cam != null else Vector2(320, 180)
	for r in list:
		var rr: Rect2 = r
		if rr.size.x <= 0.0:
			continue
		if rr in HUD_RECTS:
			out.append(rr)
		else:
			out.append(Rect2(rr.position - center + Vector2(320.0, 180.0), rr.size))
	return out

## Parcours: durchflogene Tore wechseln auf Rot, das nächste wird grün; nach dem letzten ist der Parcours geschafft.
func _tick_gates() -> void:
	if gates == null or not gates.active:
		return
	if run.sim.state == TaxiSim.State.DESTROYED:
		return
	if run.sim.pos.distance_to(gates.points[gates.next]) <= GateField.RADIUS + 2.0:
		gates.next += 1
		game.call("tutorial_ping")
		if gates.next >= gates.points.size():
			gates.finish()
			flags["course_done"] = true

# ---------------------------------------------------------------- Ereignisse
func _key() -> String:
	return String(steps[mini(idx, steps.size() - 1)].key) if idx >= 0 else ""

func on_event(e: Dictionary) -> void:
	match String(e.type):
		"landed":
			flags["last_pad"] = String(e.pad)
			if String(e.pad) == "3" and _key() == "tut_soft":
				flags["land3"] = true
				flags["soft_ok"] = float(e.vy) <= Tuning.LAND_SOFT_VY
		"boarded":
			if bool(e.get("extra", false)):
				flags["boarded_extra"] = true
			else:
				flags["boarded_main"] = true
		"delivered":
			if bool(e.get("extra", false)):
				flags["extra_done"] = true
			else:
				flags["delivered_main"] = true
		"extra_appeared":
			run.extra_timer = 1.0e9
			for ex in run.extras:
				ex["patience"] = 120.0
				ex["patience_max"] = 120.0
		"extra_left":
			if _key() in ["tut_extra", "tut_extra_dest"]:
				flags["extra_done"] = true
		"life_bought":
			flags["life_bought"] = true
		"destroyed":
			if _key() == "tut_hard":
				flags["crashed"] = true
			elif not _spoke_crash and not bool(game.call("tutorial_narrating")):
				_spoke_crash = true
				var info: Dictionary = game.call("tutorial_speak", "tut_crash")
				spot.say(tr("SPK_INSTRUCTOR"), String(info.text))

## Level geschafft: Schlusswort, dann Übergang (nächstes Level oder Menü).
func complete() -> void:
	finished = true
	spot.set_spots([])
	_gauge(false)
	var info: Dictionary = game.call("tutorial_speak", "tut_done")
	spot.say(tr("SPK_INSTRUCTOR"), String(info.text))
	game.call("tutorial_mark_done")
	get_tree().create_timer(float(info.len) + 1.4, true, false, true).timeout.connect(func():
		game.call("tutorial_finish"))

# ---------------------------------------------------------------- Hilfen
func _landed_on(id: String) -> bool:
	return run.sim.state == TaxiSim.State.LANDED and String(run.sim.landed_pad.get("id", "")) == id

func _taxi_rect() -> Rect2:
	return Rect2(run.sim.pos - Vector2(26, 22), Vector2(52, 44))

func _pad_rect(id: String) -> Rect2:
	if not run.level.pads.has(id):
		return Rect2()
	var p: Dictionary = run.level.pads[id]
	return Rect2(float(p.x0) - 6.0, float(p.row) * Tuning.TILE - 50.0, float(p.x1) - float(p.x0) + 12.0, 58.0)          # inkl. Stern/Preisschild über dem Fahrgast

## Tankpad samt Zapfsäule als ein beleuchteter Bereich.
func _fuel_rect() -> Rect2:
	var r := _pad_rect("F")
	if not run.level.pumps.is_empty() and r.size.x > 0.0:
		r = r.merge((run.level.pumps[0].rect as Rect2).grow(6.0))
	return r

func _gate_rect() -> Rect2:
	return run.level.exit_rect().grow(8.0)

func _extra_rect() -> Rect2:
	for ex in run.extras:
		return _pad_rect(String(ex.job.from))
	return Rect2()

func _extra_dest_rect() -> Rect2:
	for ex in run.extras:
		return _pad_rect(String(ex.job.to))
	return Rect2()
