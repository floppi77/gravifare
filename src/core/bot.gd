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

func _init(r: Run) -> void:
	run = r
	level = r.level

func _cell_center(c: Vector2i) -> Vector2:
	return Vector2(c.x * Tuning.TILE + 8.0, c.y * Tuning.TILE + 8.0)

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
	var tgt_pad_id := run.target_pad()
	var refuel_trip := level.pads.has("F") and not run.station_down() and sim.fuel < (REFUEL_BELOW_DOORS if (level.has_doors() or level.has_movers()) else REFUEL_BELOW) and run.phase != Run.Phase.BOARDING and run.phase != Run.Phase.DROPOFF
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
			path = Pathing.plan(level, sim.pos, goal, MARGIN)
		else:
			var pad: Dictionary = level.pads[tgt_pad_id]
			path = Pathing.plan(level, sim.pos, Pathing.hover_point(level, pad, MARGIN), MARGIN)
		if path.is_empty():
			fail_reason = "kein Pfad zu " + key
	return _fly(tgt_pad_id, heading_exit)

func _fly(tgt_pad_id: String, heading_exit: bool) -> Array:
	var sim := run.sim
	if path.is_empty() and not landing:
		goal_key = ""                       # beim nächsten Tick neu planen; bis dahin schweben statt abstürzen
		return [_accel_to_input(-sim.vel / 0.3 + sim.vel * sim.drag()), false]
	var gear := false
	# nächsten Wegpunkt per Sichtlinie wählen
	while path.size() > 1 and (sim.pos.distance_to(path[0]) < 10.0 or Pathing.line_free(level, sim.pos, path[1], MARGIN)):
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
		var spd := V_MAX
		if last:
			spd = minf(V_MAX, sqrt(2.0 * 45.0 * maxf(dist - 2.0, 0.0)) + 4.0)
		elif dist < 50.0:
			spd = LOOKAHEAD_V
		v_des = d.normalized() * spd if dist > 0.5 else Vector2.ZERO
		if heading_exit and last and dist < 6.0:
			v_des = Vector2.ZERO
	var v_des_before := v_des
	if level.has_doors() and v_des != Vector2.ZERO:
		# Tore voraus: nur hineinfliegen, wenn sie bei Ankunft offen sind und lange genug offen bleiben (sonst schweben).
		var dir := v_des.normalized()
		var spd := maxf(sim.vel.length(), 25.0)
		var inside: Array = level.door_chars_in_box(sim.pos, Tuning.HULL_HALF)     # im Tor: Tor bleibt offen
		for dist: float in [14.0, 14.0 + spd * 0.5, 14.0 + spd * 1.0]:
			var probe: Vector2 = sim.pos + dir * dist
			for ch in level.door_chars_in_box(probe, Tuning.HULL_HALF + Vector2(5, 5)):
				if inside.has(ch):
					continue
				# Frühestmögliche Ankunft (Höchsttempo) bis späteste Ankunft (aktuelles Tempo) + Durchflugzeit muss offen sein
				if not level.door_open_window(ch, level.clock + dist / V_MAX - 0.05, maxf(dist / spd - dist / V_MAX, 0.0) + 2.0):
					v_des = Vector2.ZERO
	if level.has_movers():
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
		var mhalf := Tuning.HULL_HALF + Vector2(6, 6)
		if v_des != Vector2.ZERO and level.movers_collide_traj(sim.pos, sim.vel, v_des, mhalf, level.clock, 1.0):
			v_des = Vector2.ZERO
		# Trifft die Bahn auch beim Schweben/Bremsen noch ein Hindernis: in eine freie Richtung ausweichen
		var ehalf := Tuning.HULL_HALF + Vector2(2, 2)
		if sim.state == TaxiSim.State.FLYING and level.movers_collide_traj(sim.pos, sim.vel, v_des, ehalf, level.clock, 0.5):
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
				if wall:
					continue
				if not level.movers_collide_traj(sim.pos, sim.vel, cand * 55.0, ehalf, level.clock, 0.8):
					v_des = cand * 55.0
					break
	var blocked_now := v_des_before != Vector2.ZERO and v_des == Vector2.ZERO
	if was_blocked and not blocked_now and v_des != Vector2.ZERO:
		goal_key = ""                       # nach dem Warten (Absinken, Drift) neu planen
	was_blocked = blocked_now or (was_blocked and v_des == Vector2.ZERO)
	var a_des := (v_des - sim.vel) / 0.30 + sim.vel * sim.drag()
	if level.has_zones():
		a_des -= level.zone_accel(sim.pos, level.clock)      # Strömung/Magnet/Schwerkraftzone ausgleichen
	return [_accel_to_input(a_des), gear]

## Fliegt eine komplette Level-Fahrt. Rückgabe: Ergebnis-Dictionary.
static func fly_level(lvl: LevelData, max_seconds := 600.0, fuel_in := -1.0, record := false) -> Dictionary:
	var r := Run.new()
	r.extras_enabled = false         # Der Bot löst die Auftragskette; Zusatzfahrgäste sind optional
	r.start(lvl, fuel_in)
	var bot := Bot.new(r)
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
		"delivered": r.delivered, "jobs": lvl.jobs.size(), "money": r.money, "job_times": r.job_times,
		"reason": reason if reason != "" else bot.fail_reason,
	}
	if rep != null:
		rep.finish({"complete": out.complete, "time": r.level_time, "money": r.money, "earned": r.earned, "delivered": r.delivered})
		out["replay"] = rep.to_dict()
	if not out.complete and out.reason == "":
		out.reason = "Zeitlimit" if not out.failed else "Taxi zerstört"
	return out
