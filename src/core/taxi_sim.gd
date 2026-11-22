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
var fuel_cap := Tuning.FUEL_MAX       # Fassungsvermögen des Tanks (Tagschicht, Regel Dünner Tank: die Hälfte)
var hull := Tuning.HULL_MAX
var state := State.FLYING
var landed_pad := {}
var thrust_in := Vector2.ZERO  # zuletzt angewandte Eingabe (für Effekte)
var time := 0.0
var events: Array = []
var spike_cd := 0.0
var mover_cd := 0.0
var meteor_cd := 0.0
var heat_cd := 0.0
var beam_cd := 0.0
var air_t := 0.0             # Flugzeit seit dem letzten Abheben (für „perfekte Landung“)
var air_path := 0.0          # zurückgelegte Strecke seit dem letzten Abheben (px)
var burn_k := 1.0            # Werkstatt: Verbrauchsfaktor, Aufprallschaden-Faktor, erlaubte Sinkrate
var damage_k := 1.0
var land_vy := Tuning.LAND_VY
var rules := 4               # Regelstand (Run.rules): ab 4 trifft Lava schon am Rumpf und mit Tuning.HEAT_DAMAGE
# Sonderschicht (Overtime.sim_mods): Ausstattung und Zwischenfälle. Alle Grundwerte lassen die Rechnung bitgleich (Faktor 1, Grenzen wie in Tuning).
var thrust_k := 1.0          # Hauptdüse
var side_k := 1.0            # Seitendüsen
var side_l := 1.0            # Schwache Seitendüse: eine Seite schwächer
var side_r := 1.0
var down_k := 1.0            # Bremsdüse
var drag_k := 1.0            # Dämpfung (Schmierfilm: weniger)
var gear_time_k := 1.0       # Fahrwerkszeit
var land_tilt := Tuning.LAND_TILT
var land_vx := Tuning.LAND_VX
var impact_safe := Tuning.IMPACT_SAFE
var heat_k := 1.0            # Hitze und Plasmastrahl
var mover_k := 1.0           # Trümmer, Verkehr, Meteoriten
var spike_shield := 0        # Dornenschutz: so viele Berührungen ohne Schaden (je Level)
var overheat := false        # Heiße Düse: Dauerschub überhitzt die Hauptdüse
var jet_heat := 0.0          # Sekunden Dauerschub (kühlt ab, wenn man vom Gas geht)
var jet_hot := false
var leak := 0.0              # Leck: Sprit je Sekunde, auch im Stand
var heavy_k := 1.0           # Schwere Fracht: Schubfaktor mit Fahrgast an Bord
var loaded := false          # Fahrgast an Bord (setzt Run vor jedem Schritt)
var angel := 0               # Schutzengel: so oft bleibt bei Zerstörung 1 Hüllenpunkt
var jet_lag := false         # Träge Düsen: Schub folgt der Eingabe verzögert und brennt nach dem Loslassen kurz nach
var gear_snap := false       # Klemmendes Fahrwerk: Feinmodus, sobald das Fahrwerk sich bewegt; Schnellflug erst, wenn es ganz eingefahren ist
var jet_eff := Vector2.ZERO  # wirksamer Schub (x seitlich, y = hoch − runter) bei trägen Düsen

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
	spike_cd = 0.0
	mover_cd = 0.0
	meteor_cd = 0.0
	heat_cd = 0.0
	beam_cd = 0.0
	air_t = 0.0
	air_path = 0.0
	lvl.clock = 0.0
	lvl.update_movers(0.0, true)
	for m in lvl.movers:
		m.erase("hit_until")               # Treffersperre der Meteoriten gilt in Simulationszeit, die hier neu beginnt
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

## Werkstatt-Einbauten anwenden ({burn, damage, land_vy}, siehe Workshop.mods_for), in der Sonderschicht auch Ausstattung und Zwischenfälle
## (Overtime.sim_mods). Fehlende Schlüssel setzen den Serienwert: Das Taxi lebt über mehrere Level, nichts darf von einer Etappe in die nächste mitlaufen.
func apply_mods(m: Dictionary) -> void:
	burn_k = float(m.get("burn", 1.0))
	damage_k = float(m.get("damage", 1.0))
	land_vy = float(m.get("land_vy", Tuning.LAND_VY))
	thrust_k = float(m.get("thrust_k", 1.0))
	side_k = float(m.get("side_k", 1.0))
	side_l = float(m.get("side_l", 1.0))
	side_r = float(m.get("side_r", 1.0))
	down_k = float(m.get("down_k", 1.0))
	drag_k = float(m.get("drag_k", 1.0))
	gear_time_k = float(m.get("gear_time_k", 1.0))
	land_tilt = float(m.get("land_tilt", Tuning.LAND_TILT))
	land_vx = float(m.get("land_vx", Tuning.LAND_VX))
	impact_safe = float(m.get("impact_safe", Tuning.IMPACT_SAFE))
	heat_k = float(m.get("heat_k", 1.0))
	mover_k = float(m.get("mover_k", 1.0))
	spike_shield = int(m.get("spike_shield", 0))
	overheat = bool(m.get("overheat", false))
	leak = float(m.get("leak", 0.0))
	heavy_k = float(m.get("heavy_k", 1.0))
	angel = int(m.get("angel", 0))
	jet_lag = bool(m.get("jet_lag", false))
	gear_snap = bool(m.get("gear_snap", false))
	jet_eff = Vector2.ZERO
	jet_heat = 0.0
	jet_hot = false
	loaded = false

## Hülle aufgebraucht? Dann ist das Taxi zerstört – außer ein Schutzengel (Sonderschicht) lässt einen Hüllenpunkt übrig.
func _hull_check() -> void:
	if hull > 0.0:
		return
	if angel > 0:
		angel -= 1
		hull = 1.0
		events.append({"type": "angel"})
		return
	hull = 0.0
	state = State.DESTROYED
	events.append({"type": "destroyed"})

## Wirksame Düsenstärken und Dämpfung: gleiten vom Reisemodus (Fahrwerk drin) zum Feinmodus (draußen).
## Tor schließt auf dem Taxi: Schaden, und das Taxi wird zur nächstgelegenen freien Seite hinausgeschleudert.
func _door_crush() -> void:
	if not level.has_doors() or state == State.DESTROYED:
		return
	var half := Vector2(Tuning.HULL_HALF.x, Tuning.HULL_HALF.y + Tuning.GEAR_LEN * gear * 0.5)
	var off := Vector2(0, Tuning.GEAR_LEN * gear * 0.5)
	if not level.hits_closed_door(pos + off, half):
		return
	if rules >= 5:                           # Regelstand 5: Eine wandernde Schleuse (senkrecht) nimmt das Taxi mit, statt es hinauszuschleudern
		var push := level.sweep_carry(pos + off, half)
		if push != Vector2.ZERO and not level.box_hits_cells(pos + off + push, half):
			pos += push
			vel.y = clampf(push.y / Tuning.TICK, -Tuning.MAX_SPEED, Tuning.MAX_SPEED)
			if state == State.LANDED:
				state = State.FLYING
				landed_pad = {}
				air_t = 0.0
				air_path = 0.0
			events.append({"type": "scrape"})
			return
	var out := level.door_escape(pos + off, half)
	if out == Vector2.ZERO:
		_crush_out(off, half)
		return
	pos += out
	_crush_hit(out.normalized())

## Gequetscht (Tor, oder Mover drückt gegen Fels): Schaden, und das Taxi wird zur nächstgelegenen freien Seite hinausgeschleudert.
func _crush_out(off: Vector2, half: Vector2) -> void:
	var best_d := 999
	var best_dir := Vector2.ZERO
	for dir in [Vector2(1, 0), Vector2(-1, 0), Vector2(0, -1), Vector2(0, 1)]:
		for d in range(1, 65):
			var p: Vector2 = pos + dir * float(d)
			if not level.box_hits_solid(p + off, half):
				if d < best_d:
					best_d = d
					best_dir = dir
				break
	if best_dir == Vector2.ZERO:
		best_dir = Vector2(0, -1)
		best_d = 12
	pos += best_dir * float(best_d + 1)
	_crush_hit(best_dir)

func _crush_hit(dir: Vector2) -> void:
	vel = dir * Tuning.DOOR_EJECT_SPEED
	tilt = 0.0
	if state == State.LANDED:
		state = State.FLYING
		landed_pad = {}
	hull -= Tuning.DOOR_CRUSH_DAMAGE
	events.append({"type": "damage", "amount": Tuning.DOOR_CRUSH_DAMAGE, "speed": 0.0, "crush": true})
	_hull_check()

## Schaden durch bewegliche Hindernisse (mit kurzer Sperre gegen Mehrfachzählung).
func _mover_damage(kind: String) -> void:
	if mover_cd > 0.0 or state == State.DESTROYED:
		return
	var dmg := Tuning.DEBRIS_DAMAGE if kind == "debris" else (Tuning.SLIDER_DAMAGE if kind == "slider" else (Tuning.METEOR_DAMAGE if kind == "meteor" else (Tuning.BEAM_DAMAGE if kind == "beam" else (Tuning.VEHICLE_DAMAGE if kind == "vehicle" else Tuning.PADSLAB_DAMAGE))))
	if kind == "debris" or kind == "vehicle" or kind == "meteor":
		dmg *= mover_k                       # Rammbügel
	elif kind == "beam":
		dmg *= heat_k                        # Hitzeschild
	mover_cd = Tuning.MOVER_COOLDOWN
	hull -= dmg
	events.append({"type": "damage", "amount": dmg, "speed": 0.0, "mover": kind})
	_hull_check()

## Plasmastrahl: Hüllenschaden alle 0,3 s, solange das Taxi im Strahl ist; man kann ungehindert weiterfliegen.
func _beam_burn() -> void:
	if beam_cd > 0.0 or state == State.DESTROYED:
		return
	beam_cd = 0.3
	var bdmg := Tuning.BEAM_DAMAGE * heat_k
	hull -= bdmg
	events.append({"type": "damage", "amount": bdmg, "speed": 0.0, "mover": "beam"})
	_hull_check()

## Hitzezone (Lava): solange das Taxi sie berührt, alle 0,25 s Hüllenschaden. Regelstand 4: Rumpf berührt die Zone, 9 Schaden;
## bis Regelstand 3: Mittelpunkt in der Zone, 3 Schaden.
func _heat(dt: float) -> void:
	heat_cd = maxf(0.0, heat_cd - dt)
	if heat_cd > 0.0 or state == State.DESTROYED or level.zones.is_empty():
		return
	var hot := level.heat_at(pos, time, Tuning.HULL_HALF) if rules >= 4 else level.heat_at(pos, time)
	if not hot:
		return
	var dmg := (Tuning.HEAT_DAMAGE if rules >= 4 else Tuning.HEAT_DAMAGE_V3) * heat_k
	heat_cd = 0.25
	hull -= dmg
	events.append({"type": "damage", "amount": dmg, "speed": 0.0, "heat": true})
	_hull_check()

## Meteoritenschauer: kurz bevor ein Meteorit fällt, einmal Alarm melden (danach mindestens 6 s Ruhe).
func _meteor_alert(dt: float) -> void:
	meteor_cd = maxf(0.0, meteor_cd - dt)
	if meteor_cd > 0.0:
		return
	for m in level.movers:
		if m.kind == "meteor" or m.kind == "beam":
			var eta := level.meteor_eta(m, time)
			if eta > 0.0 and eta <= float(m.warn):
				meteor_cd = 6.0
				events.append({"type": "meteor_warn" if m.kind == "meteor" else "beam_warn"})
				return

## Taxi stößt (durch eigene Bewegung) an einen Mover.
func _movers_touch(center: Vector2) -> void:
	for m in level.movers_at_box(center, Tuning.HULL_HALF + Vector2(0.6, 0.6)):
		if m.kind != "pad":
			_mover_damage(m.kind)
		else:
			_mover_damage("pad")
		break

## Ein Mover fährt in das Taxi: es wird zur Seite mit der kleinsten Überlappung hinausgeschoben (Schaden).
func _mover_push() -> void:
	if level.movers.is_empty() or state == State.DESTROYED:
		return
	var box := Rect2(pos - Tuning.HULL_HALF, Tuning.HULL_HALF * 2.0)
	for m in level.movers:
		var r: Rect2 = m.rect
		if not level.mover_touches(m, box):
			continue
		if m.kind == "beam":                 # Strahl schiebt nicht, er verbrennt nur (solange man darin ist)
			_beam_burn()
			continue
		if m.kind == "meteor":
			# Meteoriten schlagen ein und prallen ab: kurzer Stoß nach unten, Schaden, danach fällt der Brocken ohne das Taxi weiter
			if float(m.get("hit_until", -1.0)) > time:
				continue
			m["hit_until"] = time + float(m.fall) + 0.3
			vel.y = maxf(vel.y, 95.0)
			if state == State.LANDED:
				state = State.FLYING
				landed_pad = {}
				air_t = 0.0
				air_path = 0.0
			mover_cd = 0.0
			_mover_damage("meteor")
			return
		var opts := [[box.end.x - r.position.x, Vector2(-1, 0)], [r.end.x - box.position.x, Vector2(1, 0)],
			[box.end.y - r.position.y, Vector2(0, -1)], [r.end.y - box.position.y, Vector2(0, 1)]]
		var best: Array = []
		for o in opts:
			if level.box_hits_cells(pos + (o[1] as Vector2) * (float(o[0]) + 0.6), Tuning.HULL_HALF):
				continue                     # dorthin steht Fels im Weg: nie ins Gestein schieben
			if best.is_empty() or o[0] < best[0] - 0.001:
				best = o
		if best.is_empty():                  # zwischen Mover und Fels eingeklemmt: Quetschung wie beim Tor
			mover_cd = Tuning.MOVER_COOLDOWN
			_crush_out(Vector2.ZERO, Tuning.HULL_HALF)
			return
		pos += (best[1] as Vector2) * (float(best[0]) + 0.6)
		vel = (m.vel as Vector2) * (0.3 if m.kind == "meteor" else 1.0) + (best[1] as Vector2) * 30.0      # Meteoriten streifen nur
		if state == State.LANDED:
			state = State.FLYING
			landed_pad = {}
			air_t = 0.0
			air_path = 0.0
		_mover_damage(m.kind)
		return

## Anteil des Feinmodus 0…1: sonst der Fahrwerksstand (stufenloser Übergang); mit klemmendem Fahrwerk (Sonderschicht) voll, sobald es nicht ganz eingefahren ist.
func mode() -> float: return (1.0 if gear > 0.0 else 0.0) if gear_snap else gear
func up_power() -> float: return lerpf(Tuning.THRUST_UP, Tuning.GEAR_THRUST_UP, mode()) * (thrust_k * (heavy_k if loaded else 1.0) * (OVERHEAT_K if jet_hot else 1.0))
func down_power() -> float: return lerpf(Tuning.THRUST_DOWN, Tuning.GEAR_THRUST_DOWN, mode()) * down_k
func side_power() -> float: return lerpf(Tuning.THRUST_SIDE, Tuning.GEAR_THRUST_SIDE, mode()) * side_k
func drag() -> float: return lerpf(Tuning.DRAG, Tuning.GEAR_DRAG, mode()) * drag_k
## Dämpfung je Achse: Das ausgefahrene Fahrwerk bremst seitlich und nach oben voll (Feinmanöver-Feature), nach unten nur mit
## GEAR_FALL_FACTOR der Wirkung – dort tragen Schwerkraft und Massenträgheit das Taxi weiter.
func drag_v() -> Vector2: return Vector2(drag(), lerpf(Tuning.DRAG, drag(), Tuning.GEAR_FALL_FACTOR) if vel.y > 0.0 else drag())
func max_speed() -> float: return lerpf(Tuning.MAX_SPEED, Tuning.GEAR_MAX_SPEED, mode())
func max_fall_speed() -> float: return lerpf(Tuning.MAX_SPEED, max_speed(), Tuning.GEAR_FALL_FACTOR)

func gear_extended() -> bool:
	return gear >= 0.99

func foot_points() -> Array[Vector2]:
	var y := pos.y + Tuning.HULL_HALF.y + Tuning.GEAR_LEN * gear
	return [Vector2(pos.x - Tuning.FOOT_X, y), Vector2(pos.x + Tuning.FOOT_X, y)]

## Landesicherheit 0..1 für das HUD (1 = sicher). Nur aussagekräftig mit Fahrwerk.
func landing_margin() -> float:
	var m_vy := 1.0 - clampf(vel.y / land_vy, 0.0, 2.0)
	var m_vx := 1.0 - clampf(absf(vel.x) / land_vx, 0.0, 2.0)
	var m_t := 1.0 - clampf(absf(tilt) / land_tilt, 0.0, 2.0)
	return clampf(minf(m_vy, minf(m_vx, m_t)), -1.0, 1.0)

func step(input: Vector2, gear_request: bool, dt: float = Tuning.TICK) -> void:
	## input: x = -1..1 (links/rechts), y = -1..1 (hoch = -1 wie Bildschirmachse)
	events.clear()
	if state == State.DESTROYED:
		return
	time += dt
	spike_cd = maxf(0.0, spike_cd - dt)
	level.clock = time
	mover_cd = maxf(0.0, mover_cd - dt)
	beam_cd = maxf(0.0, beam_cd - dt)
	level.update_movers(time)
	_meteor_alert(dt)
	_heat(dt)
	_door_crush()
	_mover_push()
	gear_cmd = gear_request
	gear = move_toward(gear, 1.0 if gear_cmd else 0.0, dt / (Tuning.GEAR_TIME * gear_time_k))
	if leak > 0.0:
		fuel = maxf(0.0, fuel - leak * dt)        # Leck: läuft auch im Stand aus

	var up := clampf(-input.y, 0.0, 1.0)
	var down := clampf(input.y, 0.0, 1.0)
	var side := clampf(input.x, -1.0, 1.0)
	if fuel <= 0.0:
		up = 0.0; down = 0.0; side = 0.0
	var lift_cmd := up                       # Abheben nur mit echtem Schub nach oben (nicht mit Nachbrennen)
	if jet_lag:                              # Träge Düsen (Sonderschicht): Schub läuft der Eingabe nach (Zeitkonstante JET_LAG) und brennt kurz nach
		if state == State.LANDED and lift_cmd <= 0.0:
			jet_eff = Vector2.ZERO               # gelandet ohne Schub: nichts brennt nach (sonst hüpfte das Taxi im Takt)
		var want := Vector2(side, up - down)
		jet_eff = jet_eff.lerp(want, minf(1.0, dt / JET_LAG))
		if absf(want.x - jet_eff.x) < JET_LAG_EPS:
			jet_eff.x = want.x                   # Rest ausklingen lassen (sonst brennte sie ewig ein bisschen nach)
		if absf(want.y - jet_eff.y) < JET_LAG_EPS:
			jet_eff.y = want.y
		side = jet_eff.x
		up = maxf(0.0, jet_eff.y)
		down = maxf(0.0, -jet_eff.y)
		if fuel <= 0.0:
			up = 0.0; down = 0.0; side = 0.0
	thrust_in = Vector2(side, -up + down)
	if overheat:
		_jet_heat(up, dt)

	if state == State.LANDED:
		# Abheben nur mit Schub nach oben; sonst bleibt das Taxi sicher stehen.
		if up > 0.0 and lift_cmd > 0.0:
			vel.x = float(landed_pad.get("dx_step", 0.0)) / dt        # fährt die Plattform, startet das Taxi mit ihrem Tempo
			state = State.FLYING
			landed_pad = {}
			air_t = 0.0
			air_path = 0.0
			events.append({"type": "liftoff"})
		else:
			vel = Vector2.ZERO
			var carry := float(landed_pad.get("dx_step", 0.0))
			pos.x += carry                                               # fahrende Plattform nimmt das Taxi mit
			tilt = move_toward(tilt, 0.0, dt * 2.0)
			if carry != 0.0 and level.box_hits_cells(pos, Tuning.HULL_HALF):
				_crush_out(Vector2.ZERO, Tuning.HULL_HALF)               # die Plattform schiebt das Taxi in den Fels: Quetschung wie beim Tor
			return

	air_t += dt
	air_path += vel.length() * dt
	var acc := Vector2(0.0, level.gravity)
	if not level.zones.is_empty():
		acc += level.zone_accel(pos, time)
	acc.y -= up_power() * up
	acc.y += down_power() * down
	acc.x += side_power() * side * (side_l if side < 0.0 else side_r)
	fuel = maxf(0.0, fuel - dt * burn_k * (Tuning.BURN_UP * up + Tuning.BURN_DOWN * down + Tuning.BURN_SIDE * absf(side)))

	vel += acc * dt
	var dv := drag_v()
	vel = Vector2(vel.x * maxf(0.0, 1.0 - dv.x * dt), vel.y * maxf(0.0, 1.0 - dv.y * dt))
	if vel.y > 0.0 and max_speed() < Tuning.MAX_SPEED:
		vel.x = clampf(vel.x, -max_speed(), max_speed())          # Fahrwerk: seitlich voll gedeckelt, nach unten nur teilweise
		if vel.length() > max_fall_speed():
			vel = vel.normalized() * max_fall_speed()
	elif vel.length() > max_speed():
		vel = vel.normalized() * max_speed()

	var target_tilt := side * Tuning.TILT_MAX
	tilt = lerpf(tilt, target_tilt, minf(1.0, Tuning.TILT_RATE * dt))

	_move_axis_x(dt)
	_move_axis_y(dt)

func _move_axis_x(dt: float) -> void:
	var nx := pos.x + vel.x * dt
	if level.box_hits_solid(Vector2(nx, pos.y), Tuning.HULL_HALF):
		_impact(absf(vel.x))
		_spikes(Vector2(nx, pos.y))
		_movers_touch(Vector2(nx, pos.y))
		vel.x = -vel.x * Tuning.BOUNCE
		# an Kante heranschieben
		var dir := signf(vel.x) * -1.0
		var step_px := 0.25
		var moved := 0.0
		while not level.box_hits_solid(Vector2(pos.x + dir * step_px, pos.y), Tuning.HULL_HALF) and moved < 8.0:
			pos.x += dir * step_px
			moved += step_px
	else:
		pos.x = nx

func _move_axis_y(dt: float) -> void:
	var ny := pos.y + vel.y * dt
	# Hülle
	if level.box_hits_solid(Vector2(pos.x, ny), Tuning.HULL_HALF):
		_impact(absf(vel.y))
		_spikes(Vector2(pos.x, ny))
		_movers_touch(Vector2(pos.x, ny))
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
	var pad_vx := float(pad_l.get("dx_step", 0.0)) / Tuning.TICK if not pad_l.is_empty() else 0.0
	var speed_x := absf(vel.x - pad_vx)
	var tilt_in := absf(tilt)
	var on_pad: bool = hit_l and hit_r and not pad_l.is_empty() and not pad_r.is_empty() and pad_l.id == pad_r.id
	# Gültig ist nur die Landeplatte: Beide Füße stehen darauf, wenn die Rumpfmitte im Landefenster liegt.
	var on_plate: bool = on_pad and pos.x >= float(pad_l.get("land_lo", pad_l.x0)) - 0.5 and pos.x <= float(pad_l.get("land_hi", pad_l.x1)) + 0.5
	var ok := gear_extended() and on_plate and speed_y <= land_vy \
		and speed_x <= land_vx and absf(tilt) <= land_tilt
	if ok:
		var surf_y: float = pad_l.row * Tuning.TILE
		pos.y = surf_y - glen - Tuning.HULL_HALF.y
		vel = Vector2.ZERO
		tilt = 0.0
		state = State.LANDED
		landed_pad = pad_l
		events.append({"type": "landed", "pad": pad_l.id, "soft": speed_y <= Tuning.LAND_SOFT_VY, "vy": speed_y, "vx": speed_x, "tilt": tilt_in, "air_t": air_t, "air_path": air_path})
	else:
		var reason := "pos" if not on_pad else ("plate" if not on_plate else ("gear" if not gear_extended() else ("tilt" if absf(tilt) > land_tilt else "speed")))
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
	## Balance: bis IMPACT_SAFE harmlos; danach Hüllenschaden, der mit der Geschwindigkeit überproportional
	## steigt; ab CRASH_SPEED ist das Taxi sofort zerstört.
	if speed <= impact_safe:
		return
	if speed >= Tuning.CRASH_SPEED:
		events.append({"type": "damage", "amount": hull, "speed": speed, "fatal": true})
		if angel > 0:                        # Schutzengel (Sonderschicht): auch der Totalschaden lässt einen Hüllenpunkt
			angel -= 1
			hull = 1.0
			events.append({"type": "angel"})
			return
		hull = 0.0
		state = State.DESTROYED
		events.append({"type": "destroyed", "instant": true})
		return
	var k := (speed - impact_safe) / (Tuning.CRASH_SPEED - impact_safe)
	var dmg := Tuning.HULL_MAX * pow(k, Tuning.DAMAGE_EXP) * damage_k
	hull -= dmg
	events.append({"type": "damage", "amount": dmg, "speed": speed})
	_hull_check()

## Dornen: fester Zusatzschaden je Berührung (nicht tempoabhängig), mit kurzer Sperre gegen Mehrfachzählung.
func _spikes(box_center: Vector2) -> void:
	if state != State.DESTROYED and (level.box_hits_char(box_center, Tuning.HULL_HALF, "^") or level.box_hits_pad_spikes(box_center, Tuning.HULL_HALF)):
		_spike_hit()

func _spike_hit() -> void:
	if spike_cd > 0.0 or state == State.DESTROYED:
		return
	spike_cd = Tuning.SPIKE_COOLDOWN
	if spike_shield > 0:                     # Dornenschutz (Sonderschicht): diese Berührung kostet nichts
		spike_shield -= 1
		events.append({"type": "shield"})
		return
	hull -= Tuning.SPIKE_DAMAGE
	events.append({"type": "damage", "amount": Tuning.SPIKE_DAMAGE, "speed": 0.0, "spike": true})
	_hull_check()

## Heiße Düse (Sonderschicht): Nach OVERHEAT_AT Sekunden Vollgas überhitzt die Hauptdüse und bringt nur noch OVERHEAT_K, bis sie unter
## OVERHEAT_COOL abgekühlt ist. Abkühlen geht langsamer als Aufheizen; leichtes Schweben (unter 60 % Schub) heizt nicht.
const JET_LAG := 0.22                    # Träge Düsen: Zeitkonstante in Sekunden
const JET_LAG_EPS := 0.04                # darunter ist der Nachbrand aus (sonst klänge er nie ganz ab)
const OVERHEAT_AT := 1.5
const OVERHEAT_COOL := 1.0
const OVERHEAT_K := 0.6
const OVERHEAT_RATE := 0.6
func _jet_heat(up: float, dt: float) -> void:
	if up > 0.6 and state == State.FLYING:
		jet_heat = minf(OVERHEAT_AT + 1.0, jet_heat + dt)
	else:
		jet_heat = maxf(0.0, jet_heat - dt * OVERHEAT_RATE)
	if not jet_hot and jet_heat >= OVERHEAT_AT:
		jet_hot = true
		events.append({"type": "overheat"})
	elif jet_hot and jet_heat <= OVERHEAT_COOL:
		jet_hot = false
		events.append({"type": "cooled"})

func refuel(amount: float) -> void:
	fuel = minf(fuel_cap, fuel + amount)

func in_exit(exit_rect_cells: Array) -> bool:
	var c := Vector2i(floori(pos.x / Tuning.TILE), floori(pos.y / Tuning.TILE))
	return exit_rect_cells.has(c)
