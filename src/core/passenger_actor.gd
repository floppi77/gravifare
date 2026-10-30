class_name PassengerActor
extends RefCounted
## Ein Fahrgast als kleiner Zustandsautomat: tritt aus dem Unterstand, wartet, läuft zum gelandeten
## Taxi, steigt ein; beim Ankunftspad steigt er aus, läuft zum Unterstand und verschwindet dort.
## Reine Daten (kein Node) – Darstellung und Tests lesen nur Zustand und Position.

enum S { EMERGING, WAITING, TO_TAXI, ABOARD, EXITING, RETURNING, GONE, FALLING, DEAD }

const SPEED := 38.0          # Welteinheiten/s
const ENTER_PAUSE := 0.15
const FALL_G := 380.0        # Fallbeschleunigung des rausgeworfenen Fahrgasts (px/s²)

var state := S.WAITING
var x := 0.0
var surface_y := 0.0          # Höhe der Pad-Oberfläche, auf der er läuft
var look := 0
var gender := "f"
var pname := ""
var job_index := 0
var pad: Dictionary = {}      # Startpad (Warten/Einsteigen)
var dest: Dictionary = {}     # Zielpad (Aussteigen)
var target_x := 0.0
var facing := 1.0
var walked := 0.0             # zurückgelegte Strecke (für den Laufzyklus)
var age := 0.0
var wave_t := 0.0
var call_cd := 0.0
var fade := 1.0               # 0..1 beim Auftauchen/Verschwinden
var pay_info: Dictionary = {}   # offene Auszahlung: {fare, par, base, penalty}; wird bei Ankunft im Häuschen fällig
var exit_time := 0.0          # Gehzeit seit dem Aussteigen (zählt zur Fahrzeit)
var _home_reported := false
var angry := false            # vom Taxi erschreckt: flüchtet schimpfend in den Unterstand
var speed_mul := 1.0
var events: Array = []
var _pause := 0.0
var fall_y := 0.0
var fall_vy := 0.0
var fall_vx := 0.0
var ground_y := 0.0
var dead_t := 0.0

func setup(job: Dictionary, p: Dictionary, index: int, instant: bool) -> void:
	pad = p
	job_index = index
	pname = job.get("passenger", "?")
	gender = job.get("gender", "f")
	look = int(job.get("look", _default_look(gender, index)))
	surface_y = p.row * Tuning.TILE
	if instant:
		x = p.wait_x
		state = S.WAITING
	else:
		x = p.door_x
		state = S.EMERGING
		fade = 0.0
	target_x = p.wait_x

const NAMES_F := ["Mika", "Ines", "Lena", "Nora", "Pia", "Yuki"]
const NAMES_M := ["Odo", "Jonas", "Ben", "Tarek", "Finn", "Leo"]

## Deterministische neue Identität (Ersatz-Fahrgast): gleicher Level/Auftrag/Versuch ergibt immer dieselbe Person.
static func pick_identity(level_id: String, job_index: int, attempt: int, old_name: String) -> Dictionary:
	var h := absi(("%s:%d:%d" % [level_id, job_index, attempt]).hash())
	var gender := "f" if h % 2 == 0 else "m"
	var names: Array = NAMES_F if gender == "f" else NAMES_M
	var name: String = names[(h / 2) % names.size()]
	if name == old_name:
		name = names[((h / 2) + 1) % names.size()]
	var looks: Array = [0, 3] if gender == "f" else [1, 2]
	return {"name": name, "gender": gender, "look": looks[(h / 7) % 2]}

static func _default_look(g: String, index: int) -> int:
	var f := [0, 3]
	var m := [1, 2]
	return (f if g == "f" else m)[index % 2]

func voice_key() -> String:
	## Zwei Stimmen je Geschlecht (f0/f1, m0/m1), fest an die Figur gebunden.
	return {0: "f0", 3: "f1", 1: "m0", 2: "m1"}.get(look, "f0" if gender == "f" else "m0")

## Körper des Fahrgasts (für Kollision mit dem Taxi); nur ruhende/auftauchende Fahrgäste sind „treffbar“.
func hit_rect() -> Rect2:
	return Rect2(x - Tuning.PASS_HALF_W, surface_y - Tuning.PASS_H, Tuning.PASS_HALF_W * 2.0, Tuning.PASS_H)

func can_be_hit() -> bool:
	return state == S.WAITING or state == S.EMERGING

## Taxi kommt ihm auf den Kopf: schimpft und flüchtet in den Unterstand (wird dort unsichtbar).
func squash() -> void:
	angry = true
	state = S.EXITING
	target_x = pad.door_x
	speed_mul = 1.9
	fade = 1.0
	wave_t = 0.0

func is_visible() -> bool:
	return state != S.ABOARD and state != S.GONE

func is_walking() -> bool:
	return state == S.EMERGING or state == S.TO_TAXI or state == S.EXITING or state == S.RETURNING

func board(taxi_x: float) -> void:
	state = S.TO_TAXI
	target_x = taxi_x
	_pause = 0.0

func abort_board() -> void:
	if state == S.TO_TAXI:
		state = S.RETURNING
		target_x = pad.wait_x

func step_out(taxi_x: float, dest_pad: Dictionary) -> void:
	exit_time = 0.0
	_home_reported = false
	dest = dest_pad
	surface_y = dest_pad.row * Tuning.TILE
	x = taxi_x
	state = S.EXITING
	fade = 1.0
	target_x = dest_pad.door_x

func cancel_exit() -> void:
	if state == S.EXITING:
		state = S.ABOARD
		_home_reported = false

func wave() -> void:
	wave_t = 1.4

func world_pos() -> Vector2:
	if state == S.FALLING or state == S.DEAD:
		return Vector2(x, fall_y)
	return Vector2(x, surface_y)

## Aus dem fliegenden Taxi geworfen: fällt bis zum Boden und stirbt beim Aufprall (kein Geld).
func start_fall(px: float, py: float, vel: Vector2, ground: float) -> void:
	x = px
	fall_y = py
	fall_vy = maxf(vel.y, 0.0) * 0.5
	fall_vx = vel.x * 0.6
	ground_y = ground
	state = S.FALLING
	fade = 1.0
	pay_info = {}
	wave_t = 0.0
	dead_t = 0.0

## Vom stehenden Taxi (oder aus geringer Höhe) hinausgeworfen: überlebt, schimpft und läuft in den Unterstand (kein Geld).
func kicked_out(taxi_x: float, pad_d: Dictionary) -> void:
	pad = pad_d
	surface_y = pad_d.row * Tuning.TILE
	x = taxi_x
	angry = true
	state = S.EXITING
	target_x = float(pad_d.get("door_x", pad_d.center))
	speed_mul = 1.9
	fade = 1.0
	wave_t = 0.0
	pay_info = {}
	_home_reported = true

func step(dt: float) -> void:
	events.clear()
	age += dt
	wave_t = maxf(0.0, wave_t - dt)
	call_cd = maxf(0.0, call_cd - dt)
	match state:
		S.EMERGING:
			fade = minf(1.0, fade + dt * 4.0)
			if _walk(dt):
				state = S.WAITING
				events.append({"type": "arrived_wait"})
		S.TO_TAXI:
			if _walk(dt):
				_pause += dt
				if _pause >= ENTER_PAUSE:
					state = S.ABOARD
					events.append({"type": "aboard"})
		S.RETURNING:
			if _walk(dt):
				state = S.WAITING
		S.FALLING:
			fall_vy += FALL_G * dt
			fall_y += fall_vy * dt
			x += fall_vx * dt
			fall_vx *= maxf(0.0, 1.0 - 0.4 * dt)
			if fall_y >= ground_y:
				fall_y = ground_y
				state = S.DEAD
				events.append({"type": "splat", "x": x, "y": fall_y})
		S.DEAD:
			dead_t += dt
			if dead_t > 2.0:
				fade = maxf(0.0, fade - dt * 1.5)
				if fade <= 0.0:
					state = S.GONE
		S.EXITING:
			exit_time += dt
			if _walk(dt):
				if not _home_reported:
					_home_reported = true
					events.append({"type": "arrived_home"})
				fade = maxf(0.0, fade - dt * 5.0)
				if fade <= 0.0:
					state = S.GONE

func _walk(dt: float) -> bool:
	## Läuft Richtung target_x; true, sobald angekommen.
	var d := target_x - x
	if absf(d) <= 0.5:
		x = target_x
		return true
	facing = signf(d)
	var step_len := minf(absf(d), SPEED * speed_mul * dt)
	x += facing * step_len
	walked += step_len
	return absf(target_x - x) <= 0.5

## Fällige bzw. voraussichtliche Auszahlung: Fahrtzeit = Zeit bis zum Aussteigen + Gehzeit zum Häuschen.
func pay_for(extra_time := 0.0) -> float:
	if pay_info.is_empty():
		return 0.0
	var t := float(pay_info.base) + (exit_time + extra_time) * Tuning.WALK_TIME_WEIGHT
	return float(pay_info.fare) * Tuning.time_factor(t, float(pay_info.par)) * (1.0 - float(pay_info.penalty)) * (1.0 + Tuning.COMBO_STEP * float(mini(int(pay_info.get("combo", 0)), Tuning.COMBO_MAX)))

func factor_for(extra_time := 0.0) -> float:
	return Tuning.time_factor(float(pay_info.base) + (exit_time + extra_time) * Tuning.WALK_TIME_WEIGHT, float(pay_info.par)) if not pay_info.is_empty() else 1.0

## Restliche Gehzeit bis zur Haustür (Sekunden).
func remaining_walk() -> float:
	return absf(target_x - x) / (SPEED * speed_mul)
