class_name Bot
extends RefCounted
## Autopilot für Lösbarkeits- und Spieltests: plant per BFS über ein Freiraumraster
## (Hülle + Sicherheitsrand), glättet per Sichtlinie und fliegt mit der echten TaxiSim-Physik.
## Ziel ist keine perfekte Bestzeit, sondern der Nachweis, dass eine Auftragsfolge fliegbar ist.

const MARGIN := 7.0                # zusätzlicher Sicherheitsabstand um die Hülle (px)
const V_MAX := 85.0
const LOOKAHEAD_V := 55.0

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

func _half() -> Vector2:
	return Tuning.HULL_HALF + Vector2(MARGIN, MARGIN)

func _free(p: Vector2) -> bool:
	return not level.box_hits_solid(p, _half())

func _line_free(a: Vector2, b: Vector2) -> bool:
	var n := int(ceil(a.distance_to(b) / 3.0))
	for i in range(0, n + 1):
		if not _free(a.lerp(b, float(i) / maxf(n, 1))):
			return false
	return true

func _cell_center(c: Vector2i) -> Vector2:
	return Vector2(c.x * Tuning.TILE + 8.0, c.y * Tuning.TILE + 8.0)

func plan(from: Vector2, to: Vector2) -> Array[Vector2]:
	var res: Array[Vector2] = []
	if _line_free(from, to):
		res.append(to)
		return res
	# BFS auf Halb-Tile-Raster (8 px) für feinere Engstellen
	var step := 8.0
	var cols := int(level.width * Tuning.TILE / step)
	var rows := int(level.height * Tuning.TILE / step)
	var s := Vector2i(int(from.x / step), int(from.y / step))
	var g := Vector2i(int(to.x / step), int(to.y / step))
	var prev := {}
	var q: Array[Vector2i] = [s]
	prev[s] = s
	var found := false
	var qi := 0
	while qi < q.size():
		var c := q[qi]
		qi += 1
		if c == g:
			found = true
			break
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = c + d
			if n.x < 0 or n.y < 0 or n.x >= cols or n.y >= rows or prev.has(n):
				continue
			var wp := Vector2(n.x * step + step * 0.5, n.y * step + step * 0.5)
			if n != g and not _free(wp):
				continue
			prev[n] = c
			q.append(n)
	if not found:
		return res
	var cells: Array[Vector2] = []
	var cur := g
	while cur != s:
		cells.push_front(Vector2(cur.x * step + step * 0.5, cur.y * step + step * 0.5))
		cur = prev[cur]
	# Sichtlinien-Glättung
	var anchor := from
	var i := 0
	while i < cells.size():
		var far := i
		for j in range(cells.size() - 1, i - 1, -1):
			if _line_free(anchor, cells[j]):
				far = j
				break
		res.append(cells[far])
		anchor = cells[far]
		i = far + 1
	res[res.size() - 1] = to
	return res

func _hover_point(pad: Dictionary) -> Vector2:
	for h in [56.0, 48.0, 40.0, 32.0]:
		var p := Vector2(pad.center, pad.row * Tuning.TILE - h)
		if _free(p):
			return p
	return Vector2(pad.center, pad.row * Tuning.TILE - 32.0)

func _accel_to_input(a_des: Vector2) -> Vector2:
	# a_des: gewünschte Beschleunigung (px/s²). Rückgabe: Eingabevektor.
	var x := clampf(a_des.x / Tuning.THRUST_SIDE, -1.0, 1.0)
	var net_y := a_des.y - level.gravity   # benötigte Schubbeschleunigung (negativ = hoch)
	var y := 0.0
	if net_y < 0.0:
		y = clampf(net_y / Tuning.THRUST_UP, -1.0, 0.0)
	else:
		y = clampf(net_y / Tuning.THRUST_DOWN, 0.0, 1.0)
	return Vector2(x, y)

## Liefert [input, gear] für diesen Tick.
func decide() -> Array:
	var sim := run.sim
	var tgt_pad_id := run.target_pad()
	var heading_exit := tgt_pad_id == "" and run.exit_open
	var key := "exit" if heading_exit else ("pad" + tgt_pad_id + ":" + str(run.phase) + ":" + str(run.job_index))
	if sim.state == TaxiSim.State.LANDED:
		# Stehen bleiben, solange Ein-/Aussteigen läuft oder noch getankt werden soll
		var on_target: bool = sim.landed_pad.id == tgt_pad_id
		var boarding := run.phase == Run.Phase.BOARDING or run.phase == Run.Phase.DROPOFF
		if boarding or (on_target and (run.phase == Run.Phase.WAITING or run.phase == Run.Phase.CARRYING)):
			return [Vector2.ZERO, true]
		var want_fuel: bool = sim.landed_pad.fuel and sim.fuel < 60.0 and run.money > 5.0
		if want_fuel:
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
			path = plan(sim.pos, goal)
		else:
			var pad: Dictionary = level.pads[tgt_pad_id]
			path = plan(sim.pos, _hover_point(pad))
		if path.is_empty():
			fail_reason = "kein Pfad zu " + key
	return _fly(tgt_pad_id, heading_exit)

func _fly(tgt_pad_id: String, heading_exit: bool) -> Array:
	var sim := run.sim
	if path.is_empty() and not landing:
		return [Vector2(0, -0.2), false]
	var gear := false
	# nächsten Wegpunkt per Sichtlinie wählen
	while path.size() > 1 and (sim.pos.distance_to(path[0]) < 10.0 or _line_free(sim.pos, path[1])):
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
		var ex: float = float(pad.center) - sim.pos.x
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
	var a_des := (v_des - sim.vel) / 0.30 - sim.vel * Tuning.DRAG * -1.0
	return [_accel_to_input(a_des), gear]

## Fliegt eine komplette Level-Fahrt. Rückgabe: Ergebnis-Dictionary.
static func fly_level(lvl: LevelData, max_seconds := 600.0) -> Dictionary:
	var r := Run.new()
	r.start(lvl)
	var bot := Bot.new(r)
	var ticks := int(max_seconds / Tuning.TICK)
	var stuck_pos := r.sim.pos
	var stuck_ticks := 0
	var reason := ""
	var min_fuel := r.sim.fuel
	for i in ticks:
		var cmd := bot.decide()
		r.step(cmd[0], cmd[1])
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
		"delivered": r.delivered, "jobs": lvl.jobs.size(), "money": r.money,
		"reason": reason if reason != "" else bot.fail_reason,
	}
	if not out.complete and out.reason == "":
		out.reason = "Zeitlimit" if not out.failed else "Taxi zerstört"
	return out
