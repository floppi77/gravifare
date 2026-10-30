class_name Bot
extends RefCounted
## Autopilot für Lösbarkeits- und Spieltests: plant per BFS über ein Freiraumraster
## (Hülle + Sicherheitsrand), glättet per Sichtlinie und fliegt mit der echten TaxiSim-Physik.
## Ziel ist keine perfekte Bestzeit, sondern der Nachweis, dass eine Auftragsfolge fliegbar ist.

const MARGIN := 7.0                # zusätzlicher Sicherheitsabstand um die Hülle (px)
const V_MAX := 85.0
const LOOKAHEAD_V := 55.0
const REFUEL_BELOW := 14.0
const REFUEL_GOAL := 70.0

var run: Run
var level: LevelData
var path: Array[Vector2] = []
var goal_key := ""
var landing := false
var stuck_timer := 0.0
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
	var refuel_trip := level.pads.has("F") and not run.station_down() and sim.fuel < REFUEL_BELOW and run.phase != Run.Phase.BOARDING and run.phase != Run.Phase.DROPOFF
	if refuel_trip:
		tgt_pad_id = "F"
	var heading_exit := tgt_pad_id == "" and run.exit_open
	var key := "exit" if heading_exit else ("pad" + tgt_pad_id + ":" + str(run.phase) + ":" + str(run.job_index))
	if sim.state == TaxiSim.State.LANDED:
		var pad_id: String = sim.landed_pad.id
		var boarding := run.phase == Run.Phase.BOARDING or run.phase == Run.Phase.DROPOFF
		var can_refuel: bool = not run.station_down() and (sim.fuel < Tuning.EMERGENCY_FUEL or run.money > 5.0)
		var refuelling: bool = pad_id == "F" and sim.fuel < REFUEL_GOAL and can_refuel
		var serving: bool = pad_id == run.target_pad() and (run.phase == Run.Phase.WAITING or run.phase == Run.Phase.CARRYING)
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
		return [Vector2(0, -0.2), false]
	var gear := false
	# nächsten Wegpunkt per Sichtlinie wählen
	while path.size() > 1 and (sim.pos.distance_to(path[0]) < 10.0 or Pathing.line_free(level, sim.pos, path[1], MARGIN)):
		path.pop_front()
	var wp: Vector2 = path[0] if not path.is_empty() else sim.pos
	var last := path.size() <= 1
	var d := wp - sim.pos
	var v_des := Vector2.ZERO
	if not heading_exit and (landing or (last and d.length() < 14.0 and absf(sim.vel.x) < 12.0)):
		landing = true
		var pad: Dictionary = level.pads[tgt_pad_id]
		var foot_y := sim.pos.y + Tuning.HULL_HALF.y + Tuning.GEAR_LEN
		var dist_down: float = pad.row * Tuning.TILE - foot_y
		gear = true
		var ex: float = float(pad.get("land_mid", pad.center)) - sim.pos.x
		v_des.x = clampf(ex * 3.0, -14.0, 14.0)
		var vy := 22.0
		if dist_down < 14.0:
			vy = 15.0
		v_des.y = vy if absf(ex) < 5.0 else 0.0
		if absf(ex) > 12.0:
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
	var a_des := (v_des - sim.vel) / 0.30 + sim.vel * sim.drag()
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
	for i in ticks:
		var cmd := bot.decide()
		var inp: Vector2 = Replay.quantize(cmd[0])
		if rep != null:
			rep.add(inp, cmd[1])
		r.step(inp, cmd[1])
		if r.result != Run.Result.RUNNING:
			break
		if r.sim.state == TaxiSim.State.FLYING:
			if r.sim.pos.distance_to(stuck_pos) < 1.5:
				stuck_ticks += 1
			else:
				stuck_pos = r.sim.pos
				stuck_ticks = 0
			if stuck_ticks > 600:
				reason = "festgefahren bei " + str(r.sim.pos)
				break
		if r.sim.fuel <= 0.0 and r.sim.state == TaxiSim.State.FLYING:
			reason = "Treibstoff leer"
			break
	var out := {
		"complete": r.result == Run.Result.COMPLETE,
		"failed": r.result == Run.Result.FAILED,
		"time": r.sim.time, "fuel_left": r.sim.fuel, "hull": r.sim.hull,
		"delivered": r.delivered, "jobs": lvl.jobs.size(), "money": r.money, "job_times": r.job_times,
		"reason": reason if reason != "" else bot.fail_reason,
	}
	if rep != null:
		rep.finish({"complete": out.complete, "time": r.level_time, "money": r.money, "earned": r.earned, "delivered": r.delivered})
		out["replay"] = rep.to_dict()
	if not out.complete and out.reason == "":
		out.reason = "Zeitlimit" if not out.failed else "Taxi zerstört"
	return out
