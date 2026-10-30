class_name TaxiSim
extends RefCounted
## Deterministische Taxi-Simulation mit festem Tick. Kein Node, kein Rendering:
## dieselbe Klasse läuft im Spiel, in Tests und in Validierungsbots.

enum State { FLYING, LANDED, DESTROYED }

var level: LevelData
var pos := Vector2.ZERO
var vel := Vector2.ZERO
var tilt := 0.0
var gear := 0.0              # 0 = eingefahren, 1 = ausgefahren
var gear_cmd := false
var fuel := Tuning.FUEL_MAX
var hull := Tuning.HULL_MAX
var state := State.FLYING
var landed_pad := {}
var thrust_in := Vector2.ZERO  # zuletzt angewandte Eingabe (für Effekte)
var time := 0.0
var events: Array = []

func setup(lvl: LevelData) -> void:
	level = lvl
	pos = lvl.spawn
	vel = Vector2.ZERO
	tilt = 0.0
	gear = 0.0
	gear_cmd = false
	fuel = lvl.start_fuel
	hull = Tuning.HULL_MAX
	state = State.FLYING
	landed_pad = {}
	time = 0.0
	events.clear()
	# Steht unter dem Startpunkt ein Pad, beginnt das Taxi sicher gelandet.
	for dy in range(0, 3):
		var probe := Vector2(pos.x, pos.y + dy * Tuning.TILE)
		var pad := level.pad_at_foot(probe)
		if not pad.is_empty():
			gear = 1.0
			gear_cmd = true
			pos.y = pad.row * Tuning.TILE - Tuning.GEAR_LEN - Tuning.HULL_HALF.y
			state = State.LANDED
			landed_pad = pad
			break

## Wirksame Düsenstärken und Dämpfung: gleiten vom Reisemodus (Fahrwerk drin) zum Feinmodus (draußen).
func up_power() -> float: return lerpf(Tuning.THRUST_UP, Tuning.GEAR_THRUST_UP, gear)
func down_power() -> float: return lerpf(Tuning.THRUST_DOWN, Tuning.GEAR_THRUST_DOWN, gear)
func side_power() -> float: return lerpf(Tuning.THRUST_SIDE, Tuning.GEAR_THRUST_SIDE, gear)
func drag() -> float: return lerpf(Tuning.DRAG, Tuning.GEAR_DRAG, gear)
func max_speed() -> float: return lerpf(Tuning.MAX_SPEED, Tuning.GEAR_MAX_SPEED, gear)

func gear_extended() -> bool:
	return gear >= 0.99

func foot_points() -> Array[Vector2]:
	var y := pos.y + Tuning.HULL_HALF.y + Tuning.GEAR_LEN * gear
	return [Vector2(pos.x - Tuning.FOOT_X, y), Vector2(pos.x + Tuning.FOOT_X, y)]

## Landesicherheit 0..1 für das HUD (1 = sicher). Nur aussagekräftig mit Fahrwerk.
func landing_margin() -> float:
	var m_vy := 1.0 - clampf(vel.y / Tuning.LAND_VY, 0.0, 2.0)
	var m_vx := 1.0 - clampf(absf(vel.x) / Tuning.LAND_VX, 0.0, 2.0)
	var m_t := 1.0 - clampf(absf(tilt) / Tuning.LAND_TILT, 0.0, 2.0)
	return clampf(minf(m_vy, minf(m_vx, m_t)), -1.0, 1.0)

func step(input: Vector2, gear_request: bool, dt: float = Tuning.TICK) -> void:
	## input: x = -1..1 (links/rechts), y = -1..1 (hoch = -1 wie Bildschirmachse)
	events.clear()
	if state == State.DESTROYED:
		return
	time += dt
	gear_cmd = gear_request
	gear = move_toward(gear, 1.0 if gear_cmd else 0.0, dt / Tuning.GEAR_TIME)

	var up := clampf(-input.y, 0.0, 1.0)
	var down := clampf(input.y, 0.0, 1.0)
	var side := clampf(input.x, -1.0, 1.0)
	if fuel <= 0.0:
		up = 0.0; down = 0.0; side = 0.0
	thrust_in = Vector2(side, -up + down)

	if state == State.LANDED:
		# Abheben nur mit Schub nach oben; sonst bleibt das Taxi sicher stehen.
		if up > 0.0:
			state = State.FLYING
			landed_pad = {}
			events.append({"type": "liftoff"})
		else:
			vel = Vector2.ZERO
			tilt = move_toward(tilt, 0.0, dt * 2.0)
			return

	var acc := Vector2(0.0, level.gravity)
	acc.y -= up_power() * up
	acc.y += down_power() * down
	acc.x += side_power() * side
	fuel = maxf(0.0, fuel - dt * (Tuning.BURN_UP * up + Tuning.BURN_DOWN * down + Tuning.BURN_SIDE * absf(side)))

	vel += acc * dt
	vel *= maxf(0.0, 1.0 - drag() * dt)
	if vel.length() > max_speed():
		vel = vel.normalized() * max_speed()

	var target_tilt := side * Tuning.TILT_MAX
	tilt = lerpf(tilt, target_tilt, minf(1.0, Tuning.TILT_RATE * dt))

	_move_axis_x(dt)
	_move_axis_y(dt)

func _move_axis_x(dt: float) -> void:
	var nx := pos.x + vel.x * dt
	if level.box_hits_solid(Vector2(nx, pos.y), Tuning.HULL_HALF):
		_impact(absf(vel.x))
		vel.x = -vel.x * Tuning.BOUNCE
		# an Kante heranschieben
		var dir := signf(vel.x) * -1.0
		var step_px := 0.25
		while not level.box_hits_solid(Vector2(pos.x + dir * step_px, pos.y), Tuning.HULL_HALF) and step_px < 8.0:
			pos.x += dir * step_px
	else:
		pos.x = nx

func _move_axis_y(dt: float) -> void:
	var ny := pos.y + vel.y * dt
	# Hülle
	if level.box_hits_solid(Vector2(pos.x, ny), Tuning.HULL_HALF):
		_impact(absf(vel.y))
		var dir := -signf(vel.y)
		var moved := 0.0
		while not level.box_hits_solid(Vector2(pos.x, pos.y - dir * 0.25), Tuning.HULL_HALF) and moved < 8.0:
			pos.y -= dir * 0.25
			moved += 0.25
		vel.y = -vel.y * Tuning.BOUNCE
		return
	# Landefüße (nur beim Sinken)
	if vel.y > 0.0 and gear > 0.35:
		var glen := Tuning.GEAR_LEN * gear
		var fy := ny + Tuning.HULL_HALF.y + glen
		var hit_l := level.is_solid_at(Vector2(pos.x - Tuning.FOOT_X, fy))
		var hit_r := level.is_solid_at(Vector2(pos.x + Tuning.FOOT_X, fy))
		if hit_l or hit_r:
			_touch_down(hit_l, hit_r, fy, glen)
			return
	pos.y = ny

func _touch_down(hit_l: bool, hit_r: bool, fy: float, glen: float) -> void:
	var pad_l := level.pad_at_foot(Vector2(pos.x - Tuning.FOOT_X, fy))
	var pad_r := level.pad_at_foot(Vector2(pos.x + Tuning.FOOT_X, fy))
	var speed_y := vel.y
	var on_pad: bool = hit_l and hit_r and not pad_l.is_empty() and not pad_r.is_empty() and pad_l.id == pad_r.id
	var ok := gear_extended() and on_pad and speed_y <= Tuning.LAND_VY \
		and absf(vel.x) <= Tuning.LAND_VX and absf(tilt) <= Tuning.LAND_TILT
	if ok:
		var surf_y: float = pad_l.row * Tuning.TILE
		pos.y = surf_y - glen - Tuning.HULL_HALF.y
		vel = Vector2.ZERO
		tilt = 0.0
		state = State.LANDED
		landed_pad = pad_l
		events.append({"type": "landed", "pad": pad_l.id, "soft": speed_y <= Tuning.LAND_SOFT_VY, "vy": speed_y})
	else:
		var reason := "pos" if not on_pad else ("gear" if not gear_extended() else ("tilt" if absf(tilt) > Tuning.LAND_TILT else "speed"))
		events.append({"type": "bad_landing", "reason": reason})
		_impact(maxf(speed_y, absf(vel.x)) * 1.2)
		# aus der Wand/Plattform herausheben und zurückfedern
		while level.is_solid_at(Vector2(pos.x - Tuning.FOOT_X, fy)) or level.is_solid_at(Vector2(pos.x + Tuning.FOOT_X, fy)):
			fy -= 0.25
			pos.y -= 0.25
			if pos.y < 0.0:
				break
		vel.y = -speed_y * Tuning.BOUNCE
		vel.x *= 0.6

func _impact(speed: float) -> void:
	## Balance: bis 70 px/s harmlos; danach Hüllenschaden, der mit der Geschwindigkeit überproportional
	## steigt; ab 170 px/s ist das Taxi sofort zerstört.
	if speed <= Tuning.IMPACT_SAFE:
		return
	if speed >= Tuning.CRASH_SPEED:
		events.append({"type": "damage", "amount": hull, "speed": speed, "fatal": true})
		hull = 0.0
		state = State.DESTROYED
		events.append({"type": "destroyed", "instant": true})
		return
	var k := (speed - Tuning.IMPACT_SAFE) / (Tuning.CRASH_SPEED - Tuning.IMPACT_SAFE)
	var dmg := Tuning.HULL_MAX * pow(k, Tuning.DAMAGE_EXP)
	hull -= dmg
	events.append({"type": "damage", "amount": dmg, "speed": speed})
	if hull <= 0.0:
		hull = 0.0
		state = State.DESTROYED
		events.append({"type": "destroyed"})

func refuel(amount: float) -> void:
	fuel = minf(Tuning.FUEL_MAX, fuel + amount)

func in_exit(exit_rect_cells: Array) -> bool:
	var c := Vector2i(floori(pos.x / Tuning.TILE), floori(pos.y / Tuning.TILE))
	return exit_rect_cells.has(c)
