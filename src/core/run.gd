class_name Run
extends RefCounted
## Auftragslogik, Geld und Levelabschluss um eine TaxiSim herum. Rein datenbasiert und testbar.

enum Phase { WAITING, BOARDING, CARRYING, DROPOFF }
enum Result { RUNNING, COMPLETE, FAILED }

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
	job_time = 0.0

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
		return
	sim.step(input, gear_request, dt)
	for e in sim.events:
		log.append(e)
	if sim.state == TaxiSim.State.DESTROYED:
		result = Result.FAILED
		return
	if phase == Phase.CARRYING:
		job_time += dt
	_service_pad(dt)
	if exit_open and sim.in_exit(level.exit_cells):
		result = Result.COMPLETE
		log.append({"type": "level_complete"})

func _service_pad(dt: float) -> void:
	if sim.state != TaxiSim.State.LANDED:
		if phase == Phase.BOARDING:
			phase = Phase.WAITING
			phase_timer = 0.0
		elif phase == Phase.DROPOFF:
			phase = Phase.CARRYING
			phase_timer = 0.0
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
			if pad.id == String(job.from):
				phase = Phase.BOARDING
				phase_timer = 0.0
		Phase.BOARDING:
			phase_timer += dt
			if phase_timer >= Tuning.BOARD_TIME:
				phase = Phase.CARRYING
				job_time = 0.0
				log.append({"type": "boarded", "job": job_index})
		Phase.CARRYING:
			if pad.id == String(job.to):
				phase = Phase.DROPOFF
				phase_timer = 0.0
		Phase.DROPOFF:
			phase_timer += dt
			if phase_timer >= Tuning.BOARD_TIME:
				_deliver(job)

func _deliver(job: Dictionary) -> void:
	var fare := float(job.get("fare", 50))
	var limit := float(job.get("time_limit", 60))
	var tip := fare * 0.5 * clampf(1.0 - job_time / limit, 0.0, 1.0)
	var soft_bonus := 0.0
	money += fare + tip + soft_bonus
	delivered += 1
	log.append({"type": "delivered", "job": job_index, "fare": fare, "tip": tip})
	job_index += 1
	phase = Phase.WAITING
	phase_timer = 0.0
	if job_index >= level.jobs.size():
		exit_open = true
		log.append({"type": "exit_open"})
