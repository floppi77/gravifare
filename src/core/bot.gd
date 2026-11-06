class_name Bot
extends RefCounted
## Autopilot für Lösbarkeits- und Spieltests: plant per BFS über ein Freiraumraster
## (Hülle + Sicherheitsrand), glättet per Sichtlinie und fliegt mit der echten TaxiSim-Physik.
## Ziel ist keine perfekte Bestzeit, sondern der Nachweis, dass eine Auftragsfolge fliegbar ist.

const MARGIN := 7.0                # zusätzlicher Sicherheitsabstand um die Hülle (px)
const V_MAX := 85.0
const LOOKAHEAD_V := 55.0
const REFUEL_BELOW := 14.0
const REFUEL_BELOW_DOORS := 22.0        # Warten vor Toren kostet Sprit: früher tanken
const REFUEL_GOAL := 70.0
## Zuschauer-Autopilot des Level-Editors (`pro`): fliegt zügiger, umfliegt Zapfsäulen, hält Bahnen unter beweglichen Hindernissen nur bei vorhergesagter freier Durchfahrt
## und gibt Gas, statt vor Toren und Schiebern umzukehren. Der Standard-Autopilot (Tests, Metrik) bleibt unverändert.
static var V_PRO := 100.0               # Reisetempo auf langen Geraden (Standard 85); ab 150 px/s zerstört ein Aufprall das Taxi, ab 40 kostet er Hülle; 125 ließ Original-Level scheitern
static var CORNER_V := 50.0             # Tempo an Wegpunkten, an denen die Bahn abbiegt
const BRAKE_A := 45.0              # Bremsverzögerung für die Tempoberechnung (px/s², die Seitendüsen schaffen 125)
const DASH_V := 125.0              # Durchflugtempo unter Hindernissen
const CROSS_V := 80.0              # Tempo beim Queren einer Sweep-Schleuse (dahinter biegt die Bahn meist ab)
const PATH_HORIZON := 4.0          # so weit (Sekunden) wird die Bahn gegen bewegliche Hindernisse vorausberechnet

var run: Run
var level: LevelData
var path: Array[Vector2] = []
var goal_key := ""
var landing := false
var stuck_timer := 0.0
var waiting_spawn := false
var was_blocked := false        # zuletzt wegen Tor/Hindernis geschwebt: danach vom aktuellen Ort neu planen
var last_pos := Vector2.ZERO
var fail_reason := ""
var fly_margin := MARGIN
var sweep_commit := -1.0        # bis zu dieser Torzeit ist der Durchflug durch eine Sweep-Schleuse beschlossen
## Einzelne Verbesserungen des pro-Modus (zum Einzelprüfen in der Entwicklung abschaltbar): pump, speed, reach, route, dash, escape, track (Mitfliegen mit schnellen Sweep-Öffnungen), doordash (Gas an Schiebetoren), crossfast (Sweep-Tor im Durchflugtempo queren), core
static var features := {"pump": true, "speed": true, "reach": false, "route": true, "dash": false, "escape": true, "track": false, "doordash": false, "crossfast": true, "core": true}
var pro := false
var escape_until := -1.0        # pro: bis zu dieser Zeit gilt das gewählte Ausweichen (kein Hin und Her)
var escape_v := Vector2.ZERO
var wait_t := 0.0               # pro: Sekunden, die der Bot wegen eines Hindernisses oder Tors schwebt
var cross_dir := 0.0           # pro: Richtung (±1) des beschlossenen Tordurchflugs
var route_until := -1.0         # pro: bis zu dieser Zeit entscheidet die Bahnvorhersage (nach längerem Stillstand vor einem Hindernis)
var pump_off_until := -1.0      # pro: bis zu dieser Zeit bleibt die Zapfsäulen-Planung aus (nach langem Stillstand: der Umweg um die Säule ist die Falle)
var track_until := -1.0         # pro: bis zu dieser Zeit fliegt der Bot mit der Öffnung einer schnellen Sweep-Schleuse mit

func _init(r: Run, pro_mode := false) -> void:
	run = r
	level = r.level
	pro = pro_mode
	if pro and features.pump:
		level.pump_aware = true

func _cell_center(c: Vector2i) -> Vector2:
	return Vector2(c.x * Tuning.TILE + 8.0, c.y * Tuning.TILE + 8.0)

func _near_spikes(p: Vector2) -> bool:
	return level.box_hits_char(p, Tuning.HULL_HALF + Vector2(5, 5), "^")

func _unsafe_wait(p: Vector2) -> bool:
	return _near_spikes(p) or level.heat_at(p, level.clock)

func _accel_to_input(a_des: Vector2) -> Vector2:
	# a_des: gewünschte Beschleunigung (px/s²). Rückgabe: Eingabevektor.
	var sim := run.sim
	var x := clampf(a_des.x / sim.side_power(), -1.0, 1.0)
	var net_y := a_des.y - level.gravity   # benötigte Schubbeschleunigung (negativ = hoch)
	var y := 0.0
	if net_y < 0.0:
		y = clampf(net_y / sim.up_power(), -1.0, 0.0)
	else:
		y = clampf(net_y / sim.down_power(), 0.0, 1.0)
	return Vector2(x, y)

## Liefert [input, gear] für diesen Tick.
func decide() -> Array:
	var sim := run.sim
	if pro and wait_t > 15.0 and level.pump_aware and not level.pumps.is_empty():
		pump_off_until = level.clock + 40.0          # lange festgefahren: ohne Zapfsäulen-Umweg wie der Standard neu planen
		goal_key = ""
		wait_t = 0.0
	var tgt_pad_id := run.target_pad()
	var refuel_trip := level.pads.has("F") and not run.station_down() and sim.fuel < (REFUEL_BELOW_DOORS if (level.has_doors() or level.has_movers()) else REFUEL_BELOW) and run.phase != Run.Phase.BOARDING and run.phase != Run.Phase.DROPOFF
	if refuel_trip and level.has_doors() and sim.fuel > 13.0 and level.pads.has(tgt_pad_id):       # kurz vor dem Ziel erst abliefern
		var p: Dictionary = level.pads[tgt_pad_id]
		refuel_trip = sim.pos.distance_to(Vector2(float(p.center), float(p.row) * Tuning.TILE)) > 160.0
	if refuel_trip:
		tgt_pad_id = "F"
	var heading_exit := tgt_pad_id == "" and run.exit_open
	# Der nächste Fahrgast erscheint nie auf dem Pad, auf dem das Taxi steht: bis er da ist, nur anfliegen und schweben.
	waiting_spawn = run.phase == Run.Phase.WAITING and run.actor == null and not run.current_job().is_empty() and not refuel_trip
	var key := "exit" if heading_exit else ("pad" + tgt_pad_id + ":" + str(run.phase) + ":" + str(run.job_index))
	if not heading_exit and not landing and level.pads.has(tgt_pad_id) and level.pads[tgt_pad_id].get("moving", false):
		key += ":" + str(int(level.clock / 1.5))          # fahrende Plattform: Anflug regelmäßig neu planen (nicht im Landeanflug)
	elif landing and goal_key.begins_with("pad") and level.pads.has(tgt_pad_id) and level.pads[tgt_pad_id].get("moving", false):
		key = goal_key                                     # im Landeanflug den Schlüssel beibehalten
	if sim.state == TaxiSim.State.LANDED:
		var pad_id: String = sim.landed_pad.id
		var boarding := run.phase == Run.Phase.BOARDING or run.phase == Run.Phase.DROPOFF
		var can_refuel: bool = not run.station_down() and (sim.fuel < Tuning.EMERGENCY_FUEL or run.money > 5.0)
		var refuelling: bool = pad_id == "F" and sim.fuel < REFUEL_GOAL and can_refuel
		var serving: bool = pad_id == run.target_pad() and (run.phase == Run.Phase.WAITING or run.phase == Run.Phase.CARRYING)
		if waiting_spawn and pad_id == tgt_pad_id:
			return [Vector2(0, -1), true]           # abheben, damit der Fahrgast erscheinen kann
		if boarding or refuelling or (serving and not refuel_trip):
			return [Vector2.ZERO, true]
		landing = false
		goal_key = ""   # neu planen
		return [Vector2(0, -1), true]
	if key != goal_key:
		goal_key = key
		landing = false
		if heading_exit:
			var sum := Vector2.ZERO
			for c in level.exit_cells:
				sum += _cell_center(c)
			var goal: Vector2 = sum / level.exit_cells.size()
			path = _plan(goal)
		else:
			var pad: Dictionary = level.pads[tgt_pad_id]
			path = _plan(Pathing.hover_point(level, pad, MARGIN))
		if path.is_empty():
			fail_reason = "kein Pfad zu " + key
	return _fly(tgt_pad_id, heading_exit)

## Route mit Sicherheitsabstand; an Engstellen (z. B. neben Hitzezonen vor dem Tor) notfalls mit weniger Rand.
func _plan(goal: Vector2) -> Array[Vector2]:
	if pro:
		level.sweep_core = false
		level.pump_aware = features.pump and level.clock >= pump_off_until
	for m in [MARGIN, 5.5, 4.0, 3.0]:
		var p := Pathing.plan(level, run.sim.pos, goal, m)
		if not p.is_empty():
			fly_margin = m
			return p
	if pro and level.pump_aware:
		level.pump_aware = false                           # kein Weg um die Zapfsäule herum (z. B. Ziel direkt daneben): dann wie der Standard-Autopilot
		for m in [MARGIN, 5.5, 4.0, 3.0]:
			var pp := Pathing.plan(level, run.sim.pos, goal, m)
			if not pp.is_empty():
				fly_margin = m
				return pp
	if pro and features.core:
		# Eine fahrende Plattform, die die einzige Öffnung nur zeitweise belegt: nur ihren Kern sperren und im Flug auf die Platte achten
		level.sweep_core = true
		for m in [MARGIN, 5.5, 4.0, 3.0]:
			var p2 := Pathing.plan(level, run.sim.pos, goal, m)
			if not p2.is_empty():
				fly_margin = m
				return p2
		level.sweep_core = false
	return []

func _fly(tgt_pad_id: String, heading_exit: bool) -> Array:
	var sim := run.sim
	if path.is_empty() and not landing:
		goal_key = ""                       # beim nächsten Tick neu planen; bis dahin schweben statt abstürzen
		return [_accel_to_input(-sim.vel / 0.3 + sim.vel * sim.drag()), false]
	var gear := false
	# nächsten Wegpunkt per Sichtlinie wählen
	var reached := 4.0 if (pro and features.reach) else 10.0                 # pro: ein Wegpunkt gilt erst nahe als erreicht, sonst schneidet der Bot Ecken (Dornen, Wände) und fliegt zu schnell dagegen
	while path.size() > 1 and (sim.pos.distance_to(path[0]) < reached or Pathing.line_free(level, sim.pos, path[1], fly_margin)):
		path.pop_front()
	var wp: Vector2 = path[0] if not path.is_empty() else sim.pos
	var last := path.size() <= 1
	var d := wp - sim.pos
	var v_des := Vector2.ZERO
	var near_moving := false
	if not heading_exit and not waiting_spawn and level.pads.has(tgt_pad_id) and level.pads[tgt_pad_id].get("moving", false):
		var mp: Dictionary = level.pads[tgt_pad_id]      # fahrendes Pad: Landeanflug, sobald das Taxi über der Plattform schwebt
		var mvx := float(mp.get("dx_step", 0.0)) / Tuning.TICK
		var above: float = mp.row * Tuning.TILE - (sim.pos.y + Tuning.HULL_HALF.y + Tuning.GEAR_LEN)
		near_moving = absf(float(mp.land_mid) - sim.pos.x) < 18.0 and above > 0.0 and above < 80.0 and absf(sim.vel.x - mvx) < 14.0
	if not heading_exit and not waiting_spawn and (landing or near_moving or (last and d.length() < 14.0 and absf(sim.vel.x) < 12.0)):
		landing = true
		var pad: Dictionary = level.pads[tgt_pad_id]
		var foot_y := sim.pos.y + Tuning.HULL_HALF.y + Tuning.GEAR_LEN
		var dist_down: float = pad.row * Tuning.TILE - foot_y
		gear = true
		var ex: float = float(pad.get("land_mid", pad.center)) - sim.pos.x
		var pad_vx := float(pad.get("dx_step", 0.0)) / Tuning.TICK          # fahrende Plattform: Tempo als Vorsteuerung
		v_des.x = pad_vx + clampf(ex * 3.0, -14.0, 14.0)
		var vy := 22.0
		if dist_down < 14.0:
			vy = 15.0
		v_des.y = vy if absf(ex) < 5.0 else 0.0
		if absf(ex) > 12.0 + absf(pad_vx):
			landing = false
			goal_key = ""
	else:
		var dist := d.length()
		var fast: bool = pro and features.speed and not level.has_doors() and not level.has_movers() and not level.has_zones()        # Tore, Hindernisse und Zonen sind auf das Standardtempo abgestimmt: dort bleibt es dabei
		var spd := V_PRO if fast else V_MAX
		if last:
			spd = minf(spd, sqrt(2.0 * 45.0 * maxf(dist - 2.0, 0.0)) + 4.0)
		elif dist < 50.0:
			spd = LOOKAHEAD_V                                                 # nahe am Wegpunkt wie der Standard: dort biegt die Bahn ab
		elif fast:
			spd = minf(spd, sqrt(LOOKAHEAD_V * LOOKAHEAD_V + 2.0 * BRAKE_A * (dist - 50.0)))          # auf langen Geraden schneller, so weit sich bis zum Abbiegen noch bremsen lässt
		v_des = d.normalized() * spd if dist > 0.5 else Vector2.ZERO
		if heading_exit and last and dist < 6.0:
			v_des = Vector2.ZERO
	var v_des_before := v_des
	var committed: bool = pro and features.crossfast and level.clock < sweep_commit          # beschlossener Tordurchflug: nicht mittendrin wegen Hindernissen bremsen
	if level.has_doors() and v_des != Vector2.ZERO:
		# Tore voraus: nur hineinfliegen, wenn sie bei Ankunft offen sind und lange genug offen bleiben (sonst schweben).
		var dir := v_des.normalized()
		var spd := maxf(sim.vel.length(), 25.0)
		var inside: Array = level.door_chars_in_box(sim.pos, Tuning.HULL_HALF)     # im Tor: Tor bleibt offen
		for ch in inside.duplicate():                         # Sweep-Schleuse: erst „im Tor“, wenn die Taxi-Mitte zwischen den Schienen ist (vorher gilt noch die Synchronisierung)
			if level.is_sweep_vertical(ch):
				var centered := false
				for gate in level.doors[ch].gates:
					if (gate.rect as Rect2).has_point(sim.pos):
						centered = true
				if not centered:
					inside.erase(ch)
		for dist: float in [14.0, 14.0 + spd * 0.5, 14.0 + spd * 1.0]:
			var probe: Vector2 = sim.pos + dir * dist
			for ch in level.door_chars_in_box(probe, Tuning.HULL_HALF + Vector2(5, 5)):
				if inside.has(ch):
					continue
				if level.is_sweep_vertical(ch):                               # Sweep-Schleuse: mit Abstand vor dem Tor bremsen, auf Höhe schweben, nur starten, wenn die Öffnung den ganzen Durchflug lang frei ist
					var entry := 999.0
					var entry_gate: Dictionary = {}
					for gate in level.doors[ch].gates:
						var gr: Rect2 = gate.rect
						var e := maxf((gr.position.x - sim.pos.x - Tuning.HULL_HALF.x) if dir.x > 0.0 else (sim.pos.x - Tuning.HULL_HALF.x - gr.end.x), 0.0)
						if e < 120.0 and gr.grow(Tuning.HULL_HALF.x + 8.0).has_point(probe):
							entry = e
							entry_gate = gate
					if entry < 999.0:
						var go := false
						if pro and features.crossfast and not entry_gate.is_empty() and (wait_t > 10.0 or level.clock < sweep_commit):
							# Anlauf: nur der Zeitraum zählt, in dem das Taxi im Tor ist (aus der Beschleunigung berechnet), nicht der ganze Anflug; vor dem Tor in Ruhe warten
							if entry < 60.0:
								v_des.y = 0.0
								var gw: float = (entry_gate.rect as Rect2).size.x
								var v0 := maxf(sim.vel.x * signf(dir.x), 0.0)
								var t_mid := _travel_time(entry + gw * 0.5, v0, 100.0, CROSS_V)               # Ankunft in der Torachse
								var t_out := _travel_time(entry + gw + Tuning.HULL_HALF.x * 2.0, v0, 60.0, CROSS_V)    # spätester Austritt (vorsichtig: langsame Beschleunigung)
								# Die Öffnung wandert zu schnell, um sie am festen Ort durchzufliegen: losfliegen, wenn sie bei der Ankunft auf Höhe des Taxis ist;
								# im Tor hält _sweep_track das Taxi dann mit der Öffnung mit
								var c_pred := level.sweep_center(ch, entry_gate, level.clock + t_mid)
								go = level.clock < sweep_commit or (absf(sim.vel.y) < 12.0 and absf(c_pred - sim.pos.y) < 14.0)
								if go and level.clock >= sweep_commit:
									sweep_commit = level.clock + t_out + 0.2                  # festlegen: den Durchflug nicht mittendrin abbrechen
									cross_dir = signf(dir.x)
								v_des.x = signf(dir.x) * (CROSS_V if go else clampf((entry - 30.0) * 1.2, 0.0, 85.0))          # quer zum Tor, auch wenn die Bahn dahinter nach oben/unten abbiegt
						else:
							if entry < 26.0:
								v_des.y = 0.0                                    # Höhe halten; die Öffnung wandert vorbei
								var cross := (entry + 32.0 + Tuning.HULL_HALF.x * 2.0) / 62.0 + 0.1        # pro: im Durchflugtempo statt im Schleichtempo
								go = level.clock < sweep_commit or (absf(sim.vel.y) < 12.0 and level.door_clear_window(ch, level.clock, cross, sim.pos.y, Tuning.HULL_HALF.y + 4.0))
								if pro and features.track and wait_t > 12.0 and level.clock >= track_until and not go:
									track_until = level.clock + 6.0                      # kein Fenster in zwölf Sekunden: sechs Sekunden lang mit der Öffnung mitfliegen
								if pro and features.track and not go and level.clock < track_until and not entry_gate.is_empty():
									# Die Öffnung wandert zu schnell für einen festen Wartepunkt: mit ihr mitfliegen und bei Deckung durchstarten
									var c := level.sweep_center(ch, entry_gate, level.clock)
									var vg := (level.sweep_center(ch, entry_gate, level.clock + 0.1) - c) / 0.1
									v_des.y = clampf(vg + (c - sim.pos.y) * 5.0, -140.0, 140.0)
									go = absf(c - sim.pos.y) + absf(sim.vel.y - vg) * cross < 11.0                 # deckungsgleich und gleich schnell: die Öffnung bleibt den ganzen Durchflug um das Taxi
								if go and level.clock >= sweep_commit:
									sweep_commit = level.clock + cross                  # festlegen: den Durchflug nicht mittendrin abbrechen
							if not go:
								v_des.x = dir.x * clampf((entry - 12.0) * 1.2, 0.0, 85.0)      # Bremsweg: weit vor dem Tor verlangsamen
					continue
				# Frühestmögliche Ankunft (Höchsttempo) bis späteste Ankunft (aktuelles Tempo) + Durchflugzeit muss offen sein
				if not level.door_open_window(ch, level.clock + dist / V_MAX - 0.05, maxf(dist / spd - dist / V_MAX, 0.0) + 2.0):
					v_des = Vector2.ZERO
		for ch in inside:                                    # Tor schließt gleich: aus den Flügeln heraus, zur näheren Seite
			if level.is_sweep_vertical(ch):                               # in der Sweep-Schleuse: mit der Öffnung mitfliegen
				for gate in level.doors[ch].gates:
					if (gate.rect as Rect2).grow(Tuning.HULL_HALF.x).has_point(sim.pos):
						v_des.y = _sweep_track(ch, gate)
						if committed and cross_dir != 0.0:
							v_des.x = cross_dir * CROSS_V                    # im Tor weiter quer hindurch, nicht der Bahn dahinter nach oben/unten folgen
				continue
			if level.door_time_to_close(ch, level.clock) < 1.0:
				if pro and features.doordash and _door_dash_ok(ch, v_des_before):
					v_des = v_des_before.normalized() * DASH_V               # Gas geben: schafft er es nach vorn noch, wird nicht zurückgeflogen
					continue
				var out := level.door_escape(sim.pos, Tuning.HULL_HALF)
				if out != Vector2.ZERO:
					v_des = out.normalized() * 60.0
	if level.has_movers() and not committed:
		# Trümmer/Schieber: Bahn des Taxis (Anfahrt auf die Wunschgeschwindigkeit) gegen die vorhergesagten Hindernisse prüfen
		# und bei drohendem Treffer schweben und warten
		# Meteoritenschauer: aus der Fallbahn herausfliegen, solange sie warnt oder fällt; nicht hineinfliegen
		if sim.state == TaxiSim.State.FLYING and level.has_meteors():
			var mh := Tuning.HULL_HALF + Vector2(10, 10)
			var th := level.meteor_threat(Rect2(sim.pos - mh, mh * 2.0), level.clock, 2.2)
			if not th.is_empty():
				var lr := level.lane_rect(th)
				if lr.size.x > lr.size.y * 1.5:            # waagerechter Strahl: nach oben/unten ausweichen
					var dv := 1.0 if sim.pos.y >= lr.get_center().y else -1.0
					if level.box_hits_solid(sim.pos + Vector2(0.0, dv * 28.0), Tuning.HULL_HALF + Vector2(2, 2)):
						dv = -dv
					v_des = Vector2(0.0, dv * 70.0)
				else:
					var dir := 1.0 if sim.pos.x >= lr.get_center().x else -1.0
					if level.box_hits_solid(sim.pos + Vector2(dir * 28.0, 0.0), Tuning.HULL_HALF + Vector2(2, 2)):
						dir = -dir
					v_des = Vector2(dir * 70.0, 0.0)
			elif v_des != Vector2.ZERO:
				var ahead := sim.pos + v_des.normalized() * 26.0
				if not level.meteor_threat(Rect2(ahead - mh, mh * 2.0), level.clock, 2.2).is_empty():
					v_des = Vector2.ZERO
		if pro and features.route and (wait_t > 15.0 or level.clock < route_until):
			# Stillstand vor einem beweglichen Hindernis (der Standard wartet hier ewig, wenn es die Bahn immer wieder kreuzt): die ganze Bahn gegen den Takt der
			# Hindernisse vorausberechnen und erst losfliegen, wenn sie frei bleibt; sonst Gas geben oder ausweichen
			v_des = _pro_movers(v_des, tgt_pad_id)
			if v_des != Vector2.ZERO:
				route_until = level.clock + 1.5
		else:
			var mhalf := Tuning.HULL_HALF + Vector2(6, 6)
			if v_des != Vector2.ZERO and level.movers_collide_traj(sim.pos, sim.vel, v_des, mhalf, level.clock, 1.0):
				var dashed := false
				if pro and features.dash and not level.has_meteors() and sim.state == TaxiSim.State.FLYING and v_des.length() < DASH_V - 5.0:
					# Gas geben: mit mehr Tempo kommt er vor dem Hindernis durch, statt abzuwarten und getroffen zu werden
					var ddir := v_des.normalized()
					if _dash_safe(ddir) and not level.movers_collide_traj(sim.pos, sim.vel, ddir * DASH_V, mhalf, level.clock, 1.0, level.sweep_core, tgt_pad_id):
						v_des = ddir * DASH_V
						dashed = true
				if not dashed:
					v_des = Vector2.ZERO
				# Wartet er mitten in einer Verkehrsbahn, steigt er senkrecht aus der Bahn aus (zur näheren Seite) statt darin zu schweben
				var lane := level.vehicle_lane_at(sim.pos, Tuning.HULL_HALF + Vector2(4, 4)) if sim.state == TaxiSim.State.FLYING else {}
				if not lane.is_empty():
					var lc: Vector2 = (lane.rect as Rect2).get_center()
					if bool(lane.horizontal):               # waagerechter Abschnitt: nach oben/unten aussteigen, sonst seitlich
						var dv := -1.0 if sim.pos.y < lc.y else 1.0
						if level.box_hits_solid(sim.pos + Vector2(0.0, dv * 26.0), Tuning.HULL_HALF + Vector2(2, 2)):
							dv = -dv
						v_des = Vector2(0.0, dv * 60.0)
					else:
						var dh := -1.0 if sim.pos.x < lc.x else 1.0
						if level.box_hits_solid(sim.pos + Vector2(dh * 26.0, 0.0), Tuning.HULL_HALF + Vector2(2, 2)):
							dh = -dh
						v_des = Vector2(dh * 60.0, 0.0)
			# Trifft die Bahn auch beim Schweben/Bremsen noch ein Hindernis: in eine freie Richtung ausweichen
			var ehalf := Tuning.HULL_HALF + Vector2(2, 2)
			var esc_held := false
			if pro and features.escape and sim.state == TaxiSim.State.FLYING and escape_until > level.clock and not level.movers_collide_traj(sim.pos, sim.vel, escape_v, ehalf, level.clock, 0.4, level.sweep_core, tgt_pad_id):
				v_des = escape_v                                             # gewähltes Ausweichen zu Ende fliegen, kein Hin und Her
				esc_held = true
			if not esc_held and sim.state == TaxiSim.State.FLYING and level.movers_collide_traj(sim.pos, sim.vel, v_des, ehalf, level.clock, 0.5):
				var found := false
				var near_c := Vector2.ZERO
				var near_d := 1e9
				for m in level.movers:
					if m.kind == "pad" or (m.rect as Rect2).position.x < LevelData.OFFSCREEN * 0.5:
						continue
					var dd: float = ((m.rect as Rect2).get_center() - sim.pos).length()
					if dd < near_d:
						near_d = dd
						near_c = (m.rect as Rect2).get_center()
				var away: Vector2 = (sim.pos - near_c).normalized()
				var cands: Array = []
				for k in 8:
					cands.append(Vector2.RIGHT.rotated(float(k) * PI / 4.0))
				cands.sort_custom(func(p: Vector2, q: Vector2) -> bool: return p.dot(away) > q.dot(away))
				var prev_ig := level.movers_ignore
				for cand: Vector2 in cands:
					level.movers_ignore = true
					var wall := level.box_hits_solid(sim.pos + cand * 24.0, Tuning.HULL_HALF + Vector2(4, 4))
					level.movers_ignore = prev_ig
					if wall or _near_spikes(sim.pos + cand * 24.0):
						continue
					if not level.movers_collide_traj(sim.pos, sim.vel, cand * 55.0, ehalf, level.clock, 0.8):
						v_des = cand * 55.0
						found = true
						break
				if not found and pro and features.escape:
					# Kein Ausweichen weg vom nächsten Hindernis (breiter Schieber über dem Taxi): in jede freie Richtung, auch seitlich, in der die nächste Sekunde frei bleibt
					var ev := _pro_escape(v_des, ehalf + Vector2(2, 2), level.sweep_core, tgt_pad_id)
					if ev != Vector2.ZERO:
						v_des = ev
	if v_des == Vector2.ZERO and sim.state == TaxiSim.State.FLYING and _unsafe_wait(sim.pos):      # beim Warten nicht an Dornen oder in Hitze schweben
		for k in 16:
			var cand := Vector2.RIGHT.rotated(float(k) * PI / 8.0)
			var reach := 14.0 + 10.0 * float(k % 3)
			if not _unsafe_wait(sim.pos + cand * reach) and not level.box_hits_solid(sim.pos + cand * reach, Tuning.HULL_HALF + Vector2(2, 2)):
				v_des = cand * 45.0
				break
	var blocked_now := v_des_before != Vector2.ZERO and v_des == Vector2.ZERO
	wait_t = wait_t + Tuning.TICK if (sim.vel.length() < 10.0 and v_des.length() < 40.0 and sim.state == TaxiSim.State.FLYING) else 0.0      # pro: Sekunden fast im Stillstand (vor Tor, Schieber)
	if was_blocked and not blocked_now and v_des != Vector2.ZERO:
		goal_key = ""                       # nach dem Warten (Absinken, Drift) neu planen
	was_blocked = blocked_now or (was_blocked and v_des == Vector2.ZERO)
	var a_des := (v_des - sim.vel) / 0.30 + sim.vel * sim.drag()
	if level.has_zones():
		a_des -= level.zone_accel(sim.pos, level.clock)      # Strömung/Magnet/Schwerkraftzone ausgleichen
	return [_accel_to_input(a_des), gear]

## pro: Schafft das Taxi die Durchfahrt durch ein sich schließendes Schiebetor noch nach vorn (Tempo `DASH_V`, bis die Flügel zu weit zugefahren sind)?
func _door_dash_ok(ch: String, dir_v: Vector2) -> bool:
	if dir_v == Vector2.ZERO:
		return false
	var dir := dir_v.normalized()
	var sim := run.sim
	for gate in level.doors[ch].gates:
		var gr: Rect2 = gate.rect
		if not gr.grow(Tuning.HULL_HALF.x).has_point(sim.pos):
			continue
		var along := dir.x if gate.vertical else dir.y                       # Durchflugrichtung (Flügel eines senkrechten Tors fahren oben/unten zu)
		if absf(along) < 0.5:
			return false
		var sgn := 1.0 if along > 0.0 else -1.0
		var dist := 0.0
		if gate.vertical:
			dist = (gr.end.x + Tuning.HULL_HALF.x + 1.0 - sim.pos.x) if sgn > 0.0 else (sim.pos.x - (gr.position.x - Tuning.HULL_HALF.x - 1.0))
		else:
			dist = (gr.end.y + Tuning.HULL_HALF.y + 1.0 - sim.pos.y) if sgn > 0.0 else (sim.pos.y - (gr.position.y - Tuning.HULL_HALF.y - 1.0))
		var budget := level.door_time_to_close(ch, level.clock) + LevelData.DOOR_CLOSE * 0.5 - 0.1
		return maxf(dist, 0.0) / DASH_V < budget
	return false

## pro: Bleibt die geplante Bahn (Wegpunkte ab der Taxi-Position) bei dem Tempo `spd` für die nächsten Sekunden frei von beweglichen Hindernissen?
## Die ganze Bahn wird vorausberechnet, nicht nur ein gerader Strich: unter einem breiten Schieber hindurch braucht es die Zeit des gesamten Weges.
func _route_clear(spd: float, half: Vector2, pads_too: bool, skip: String) -> bool:
	var sim := run.sim
	var pts: Array[Vector2] = [sim.pos]
	pts.append_array(path)
	var v0 := sim.vel.length()
	var s := 0.0
	var t := 0.0
	while t < PATH_HORIZON:
		t += 0.1
		var v := lerpf(v0, spd, 1.0 - exp(-t / 0.3))
		s += v * 0.1
		var p := _point_along(pts, s)
		if level.movers_hit_at(p, half, level.clock + t, pads_too, skip):
			return false
	return true

static func _point_along(pts: Array[Vector2], s: float) -> Vector2:
	var left := s
	for i in range(pts.size() - 1):
		var seg := pts[i].distance_to(pts[i + 1])
		if left <= seg:
			return pts[i].lerp(pts[i + 1], left / maxf(seg, 0.0001))
		left -= seg
	return pts[pts.size() - 1]

## pro: Sekunden, um die Strecke `d` (px) in Fahrtrichtung zu fliegen, aus der Geschwindigkeit `v0`, mit der Seitenbeschleunigung `a` bis zum Durchflugtempo.
func _travel_time(d: float, v0: float, a := 100.0, vmax := DASH_V) -> float:
	if v0 >= vmax:
		return d / vmax
	var t_acc := (vmax - v0) / a
	var d_acc := (v0 + vmax) * 0.5 * t_acc
	if d_acc >= d:
		return (-v0 + sqrt(v0 * v0 + 2.0 * a * d)) / a
	return t_acc + (d - d_acc) / vmax

## pro: Sicherheit für das Durchstarten: vor dem Taxi muss bis zum Stillstand aus `DASH_V` Platz sein.
func _dash_safe(dir: Vector2) -> bool:
	var stop := DASH_V * DASH_V / (2.0 * 80.0) + 14.0
	return Pathing.line_free(level, run.sim.pos, run.sim.pos + dir * stop, 3.0)

## pro: Bewegliche Hindernisse (Schieber, Trümmer, Fahrzeuge, bei Bedarf Plattformen). Durchfahren, wenn die Bahn frei bleibt; sonst Gas geben, wenn es so reicht,
## sonst langsamer; sonst schweben, solange es dort sicher ist, und andernfalls in eine Richtung ausweichen, in der die nächste Sekunde frei bleibt.
func _pro_movers(v_des: Vector2, tgt: String) -> Vector2:
	var sim := run.sim
	if sim.state != TaxiSim.State.FLYING:
		return v_des
	var half := Tuning.HULL_HALF + Vector2(6, 6)
	var pads_too := level.sweep_core
	var skip := tgt
	if escape_until > level.clock and not level.movers_collide_traj(sim.pos, sim.vel, escape_v, half, level.clock, 0.4, pads_too, skip):
		return escape_v                                                        # laufendes Ausweichen zu Ende führen
	if v_des != Vector2.ZERO:
		var spd := v_des.length()
		if _route_clear(spd, half, pads_too, skip):
			return v_des
		var dir := v_des.normalized()
		if spd < DASH_V - 5.0 and _dash_safe(dir) and _route_clear(DASH_V, half, pads_too, skip):
			return dir * DASH_V
		for f in [0.6, 0.35]:
			if _route_clear(spd * f, half, pads_too, skip):
				return v_des * f
	if not level.movers_collide_traj(sim.pos, sim.vel, Vector2.ZERO, half, level.clock, 1.5, pads_too, skip):
		return Vector2.ZERO                                                    # warten: hier trifft ihn nichts
	return _pro_escape(v_des, half, pads_too, skip)

func _pro_escape(v_des: Vector2, half: Vector2, pads_too: bool, skip: String) -> Vector2:
	var sim := run.sim
	var want := v_des.normalized() if v_des != Vector2.ZERO else Vector2.ZERO
	var best := Vector2.ZERO
	var best_score := -1e9
	var prev_ig := level.movers_ignore
	for k in 16:
		var cand := Vector2.RIGHT.rotated(float(k) * PI / 8.0)
		for sp in [60.0, 100.0]:
			var vd: Vector2 = cand * sp
			var look: Vector2 = sim.pos + cand * (sp * 0.45)
			level.movers_ignore = true
			var wall := level.box_hits_solid(look, Tuning.HULL_HALF + Vector2(4, 4))
			level.movers_ignore = prev_ig
			if wall or _near_spikes(look) or level.heat_at(look, level.clock):
				continue
			if level.movers_collide_traj(sim.pos, sim.vel, vd, half, level.clock, 1.2, pads_too, skip):
				continue
			var score: float = cand.dot(want) * 0.4 + sp / 100.0 * 0.3
			if score > best_score:
				best_score = score
				best = vd
	if best != Vector2.ZERO:
		escape_v = best
		escape_until = level.clock + 0.5
	return best

## Fliegt eine komplette Level-Fahrt. Rückgabe: Ergebnis-Dictionary.
## Vertikale Sollgeschwindigkeit, um mit der Mitte der wandernden Öffnung mitzufliegen (Vorhalt = Geschwindigkeit der Öffnung).
func _sweep_track(ch: String, gate: Dictionary) -> float:
	var sim := run.sim
	var c := level.sweep_center(ch, gate, level.clock)
	var vg := (level.sweep_center(ch, gate, level.clock + 0.1) - c) / 0.1
	var lim := 140.0 if (pro and (features.track or features.crossfast)) else 80.0
	return clampf(vg + (c - sim.pos.y) * 4.0, -lim, lim)

static func fly_level(lvl: LevelData, max_seconds := 600.0, fuel_in := -1.0, record := false, pro_mode := false) -> Dictionary:
	var r := Run.new()
	r.extras_enabled = false         # Der Bot löst die Auftragskette; Zusatzfahrgäste sind optional
	r.start(lvl, fuel_in)
	var bot := Bot.new(r, pro_mode)
	var rep: Replay = null
	if record:
		rep = Replay.new()
		rep.begin(lvl.id, -1, fuel_in, 0.0, {}, false)
	var ticks := int(max_seconds / Tuning.TICK)
	var stuck_pos := r.sim.pos
	var stuck_ticks := 0
	var reason := ""
	var min_fuel := r.sim.fuel
	var burned := 0.0
	var fuel_prev := r.sim.fuel
	for i in ticks:
		var cmd := bot.decide()
		var inp: Vector2 = Replay.quantize(cmd[0])
		if rep != null:
			rep.add(inp, cmd[1])
		r.step(inp, cmd[1])
		burned += maxf(0.0, fuel_prev - r.sim.fuel)
		fuel_prev = r.sim.fuel
		if r.result != Run.Result.RUNNING:
			break
		if r.sim.state == TaxiSim.State.FLYING:
			if r.sim.pos.distance_to(stuck_pos) < 1.5:
				stuck_ticks += 1
			else:
				stuck_pos = r.sim.pos
				stuck_ticks = 0
			if stuck_ticks > (2400 if (lvl.has_doors() or lvl.has_movers()) else 600):     # vor Toren darf er bis zu 20 s warten
				reason = "festgefahren bei " + str(r.sim.pos)
				break
		if r.sim.fuel <= 0.0 and r.sim.state == TaxiSim.State.FLYING:
			reason = "Treibstoff leer"
			break
	var out := {
		"complete": r.result == Run.Result.COMPLETE,
		"failed": r.result == Run.Result.FAILED,
		"time": r.sim.time, "fuel_left": r.sim.fuel, "fuel_burned": burned, "hull": r.sim.hull,
		"delivered": r.delivered, "squashes": r.squashes, "jobs": lvl.jobs.size(), "money": r.money, "job_times": r.job_times,
		"reason": reason if reason != "" else bot.fail_reason,
		"timed_out": r.exit_timed_out,
	}
	if rep != null:
		rep.finish({"complete": out.complete, "time": r.level_time, "money": r.money, "earned": r.earned, "delivered": r.delivered})
		out["replay"] = rep.to_dict()
	if not out.complete and out.reason == "":
		out.reason = "Zeitlimit" if not out.failed else "Taxi zerstört"
	return out
