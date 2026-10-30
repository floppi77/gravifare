class_name Run
extends RefCounted
## Auftragslogik, Geld und Levelabschluss um eine TaxiSim herum. Rein datenbasiert und testbar.
## Fahrgäste sind PassengerActor-Objekte; Ein-/Aussteigen dauert so lange, wie sie laufen.

enum Phase { WAITING, BOARDING, CARRYING, DROPOFF }
enum Result { RUNNING, COMPLETE, FAILED }

const STEP_OUT_TIME := 0.5
const NEXT_SPAWN_DELAY := 1.2
const CALL_RANGE := 150.0
const CALL_COOLDOWN := 12.0

var level: LevelData
var sim := TaxiSim.new()
var job_index := 0
var phase := Phase.WAITING
var phase_timer := 0.0
var money := 0.0
var delivered := 0
var soft_landings := 0
var result := Result.RUNNING
var exit_open := false
var job_time := 0.0        # Zeit seit Annahme der Fahrt (für Trinkgeld)
var last_message := ""
var log: Array = []         # Ereignisse des letzten Ticks: {type, ...}
var actor: PassengerActor = null       # Fahrgast des aktuellen Auftrags
var leavers: Array = []                # abgelieferte Fahrgäste auf dem Weg in den Unterstand
var spawn_timer := 0.0

func start(lvl: LevelData) -> void:
	level = lvl
	sim.setup(lvl)
	job_index = 0
	phase = Phase.WAITING
	phase_timer = 0.0
	money = 0.0
	delivered = 0
	soft_landings = 0
	result = Result.RUNNING
	exit_open = lvl.jobs.is_empty()
	lvl.exit_open = exit_open
	job_time = 0.0
	leavers.clear()
	spawn_timer = 0.0
	actor = null
	_spawn_actor(true)

func _spawn_actor(instant: bool) -> void:
	var job := current_job()
	if job.is_empty():
		actor = null
		return
	actor = PassengerActor.new()
	actor.setup(job, level.pads[String(job.from)], job_index, instant)
	if instant:
		actor.call_cd = 0.0

func current_job() -> Dictionary:
	return level.jobs[job_index] if job_index < level.jobs.size() else {}

func target_pad() -> String:
	var j := current_job()
	if j.is_empty():
		return ""
	return String(j.to) if phase == Phase.CARRYING or phase == Phase.DROPOFF else String(j.from)

func step(input: Vector2, gear_request: bool, dt: float = Tuning.TICK) -> void:
	log.clear()
	if result != Result.RUNNING:
		if result == Result.COMPLETE:
			_step_actors(dt)    # letzte Fahrgäste laufen beim Levelabschluss noch zu Ende
		return
	sim.step(input, gear_request, dt)
	for e in sim.events:
		log.append(e)
	if sim.state == TaxiSim.State.DESTROYED:
		result = Result.FAILED
		return
	if phase == Phase.CARRYING:
		job_time += dt
	_step_actors(dt)
	_service_pad(dt)
	if exit_open and sim.in_exit(level.exit_cells):
		result = Result.COMPLETE
		log.append({"type": "level_complete"})

func _step_actors(dt: float) -> void:
	if spawn_timer > 0.0:
		spawn_timer -= dt
		if spawn_timer <= 0.0:
			_spawn_actor(false)
	if actor != null:
		actor.step(dt)
		for e in actor.events:
			if e.type == "arrived_wait":
				actor.wave()
				actor.call_cd = CALL_COOLDOWN
				log.append({"type": "call", "voice": actor.voice_key(), "name": actor.pname})
		# Passagier ruft, wenn das Taxi in die Nähe kommt
		if actor.state == PassengerActor.S.WAITING and phase == Phase.WAITING and actor.call_cd <= 0.0 \
				and sim.state == TaxiSim.State.FLYING and sim.pos.distance_to(actor.world_pos()) < CALL_RANGE:
			actor.wave()
			actor.call_cd = CALL_COOLDOWN
			log.append({"type": "call", "voice": actor.voice_key(), "name": actor.pname})
	for l in leavers:
		l.step(dt)
	leavers = leavers.filter(func(l): return l.state != PassengerActor.S.GONE)

func _service_pad(dt: float) -> void:
	if sim.state != TaxiSim.State.LANDED:
		if phase == Phase.BOARDING:
			phase = Phase.WAITING
			phase_timer = 0.0
			if actor != null:
				actor.abort_board()
		elif phase == Phase.DROPOFF:
			phase = Phase.CARRYING
			phase_timer = 0.0
			if actor != null:
				actor.cancel_exit()
		return
	var pad: Dictionary = sim.landed_pad
	# Tanken
	if pad.fuel and sim.fuel < Tuning.FUEL_MAX:
		var want := minf(Tuning.REFUEL_RATE * dt, Tuning.FUEL_MAX - sim.fuel)
		var free := sim.fuel < Tuning.EMERGENCY_FUEL
		var cost := want * Tuning.FUEL_PRICE
		if free:
			sim.refuel(want)
		elif money >= cost:
			money -= cost
			sim.refuel(want)
	var job := current_job()
	if job.is_empty():
		return
	match phase:
		Phase.WAITING:
			if pad.id == String(job.from) and actor != null and actor.state == PassengerActor.S.WAITING:
				actor.board(sim.pos.x)
				phase = Phase.BOARDING
				phase_timer = 0.0
		Phase.BOARDING:
			if actor != null and actor.state == PassengerActor.S.ABOARD:
				phase = Phase.CARRYING
				job_time = 0.0
				log.append({"type": "boarded", "job": job_index, "voice": actor.voice_key(), "name": actor.pname, "dest": String(job.to)})
		Phase.CARRYING:
			if pad.id == String(job.to):
				phase = Phase.DROPOFF
				phase_timer = 0.0
				actor.step_out(sim.pos.x, level.pads[String(job.to)])
		Phase.DROPOFF:
			phase_timer += dt
			if phase_timer >= STEP_OUT_TIME:
				_deliver(job)

func _deliver(job: Dictionary) -> void:
	var fare := float(job.get("fare", 50))
	var limit := float(job.get("time_limit", 60))
	var tip := fare * 0.5 * clampf(1.0 - job_time / limit, 0.0, 1.0)
	money += fare + tip
	delivered += 1
	log.append({"type": "delivered", "job": job_index, "fare": fare, "tip": tip, "voice": actor.voice_key(), "name": actor.pname})
	leavers.append(actor)
	actor = null
	job_index += 1
	phase = Phase.WAITING
	phase_timer = 0.0
	if job_index >= level.jobs.size():
		exit_open = true
		level.exit_open = true
		log.append({"type": "exit_open"})
	else:
		spawn_timer = NEXT_SPAWN_DELAY
