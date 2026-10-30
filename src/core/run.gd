class_name Run
extends RefCounted
## Auftragslogik, Credits und Levelabschluss um eine TaxiSim herum. Rein datenbasiert und testbar.
## Fahrgäste sind PassengerActor-Objekte; Ein-/Aussteigen dauert so lange, wie sie laufen.
## Der letzte Auftrag eines Levels ist der Ausgangs-Fahrgast ("to": "exit"): Das Tor öffnet, sobald er an
## Bord ist; er wird durch das Tor ins nächste Level gebracht.

enum Phase { WAITING, BOARDING, CARRYING, DROPOFF }
enum Result { RUNNING, COMPLETE, FAILED }

const STEP_OUT_TIME := 0.5
const NEXT_SPAWN_DELAY := 1.2
const CALL_RANGE := 150.0
const CALL_COOLDOWN := 12.0
const SQUASH_RESPAWN_DELAY := 2.4

var level: LevelData
var jobs: Array = []        # Arbeitskopie der Aufträge (Ersatz-Fahrgäste ändern Pad/Person, nie die Leveldaten)
var sim := TaxiSim.new()
var job_index := 0
var phase := Phase.WAITING
var phase_timer := 0.0
var money := 0.0            # Credits des Laufs (werden von Level zu Level übernommen)
var earned := 0.0           # in diesem Level verdient
var delivered := 0
var result := Result.RUNNING
var exit_open := false
var job_clock := 0.0        # Sekunden seit Erscheinen des aktuellen Fahrgasts (bestimmt den Fahrpreis)
var job_times: Array = []   # Dauer je zugestelltem Auftrag
var pen_pick := 0.0         # Abzug durch harte Landung beim Abholen
var pen_drop := 0.0         # Abzug durch harte Landung am Ziel
var last_vy := 0.0
var log: Array = []         # Ereignisse des letzten Ticks: {type, ...}
var actor: PassengerActor = null       # Fahrgast des aktuellen Auftrags
var leavers: Array = []                # abgelieferte Fahrgäste auf dem Weg in den Unterstand
var carried: Dictionary = {}           # Fahrgast, der ins nächste Level mitfährt {name, look, gender}
var spawn_timer := 0.0
var spawn_wait := false
var respawn_keep_clock := false   # Ersatz-Fahrgast: Zeit läuft für den Auftrag weiter (Strafe durch Verzögerung)
var squashes := 0

func start(lvl: LevelData, fuel_in := -1.0, credits_in := 0.0) -> void:
	level = lvl
	jobs = lvl.jobs.duplicate(true)
	sim.setup(lvl)
	if fuel_in >= 0.0:
		sim.fuel = clampf(maxf(fuel_in, Tuning.MIN_START_FUEL), 0.0, Tuning.FUEL_MAX)
	else:
		sim.fuel = Tuning.FUEL_MAX
	job_index = 0
	phase = Phase.WAITING
	phase_timer = 0.0
	money = credits_in
	earned = 0.0
	delivered = 0
	result = Result.RUNNING
	exit_open = jobs.is_empty()
	lvl.exit_open = exit_open
	job_clock = 0.0
	job_times.clear()
	pen_pick = 0.0
	pen_drop = 0.0
	last_vy = 0.0
	leavers.clear()
	carried = {}
	spawn_timer = 0.0
	spawn_wait = false
	respawn_keep_clock = false
	squashes = 0
	actor = null
	_spawn_actor(true)

func _spawn_actor(instant: bool) -> void:
	var job := current_job()
	if job.is_empty():
		actor = null
		return
	actor = PassengerActor.new()
	actor.setup(job, level.pads[String(job.from)], job_index, instant)
	if not respawn_keep_clock:
		job_clock = 0.0
	respawn_keep_clock = false

func current_job() -> Dictionary:
	return jobs[job_index] if job_index < jobs.size() else {}

func is_exit_job(job: Dictionary) -> bool:
	return String(job.get("to", "")) == "exit"

func target_pad() -> String:
	var j := current_job()
	if j.is_empty():
		return ""
	if phase == Phase.CARRYING or phase == Phase.DROPOFF:
		return "" if is_exit_job(j) else String(j.to)
	return String(j.from)

func par_of(job: Dictionary) -> float:
	return float(job.get("par", job.get("time_limit", 60)))

## Aktueller Zeitfaktor des laufenden Auftrags (für die HUD-Anzeige).
func live_factor() -> float:
	var j := current_job()
	return Tuning.time_factor(job_clock, par_of(j)) if not j.is_empty() and actor != null else 1.0

func step(input: Vector2, gear_request: bool, dt: float = Tuning.TICK) -> void:
	log.clear()
	if result != Result.RUNNING:
		if result == Result.COMPLETE:
			_step_actors(dt)    # letzte Fahrgäste laufen beim Levelabschluss noch zu Ende
		return
	sim.step(input, gear_request, dt)
	for e in sim.events:
		log.append(e)
		if e.type == "landed":
			last_vy = e.vy
	if sim.state == TaxiSim.State.DESTROYED:
		result = Result.FAILED
		return
	if actor != null or respawn_keep_clock:
		job_clock += dt
	_step_actors(dt)
	_check_squash()
	_service_pad(dt)
	if exit_open and sim.in_exit(level.exit_cells):
		_finish_level()

## Taxi trifft einen wartenden Fahrgast (Kopf/Seite): Fahrgast schimpft und flieht, an seiner Stelle erscheint –
## nach kurzer Pause und an einem anderen Pad – ein neuer Fahrgast für denselben Auftrag. Die Zeit läuft weiter,
## der Umweg kostet Sprit. Steigendes Taxi (Abheben) zählt nicht.
func _check_squash() -> void:
	if actor == null or sim.state != TaxiSim.State.FLYING or not actor.can_be_hit():
		return
	if sim.vel.y < -12.0:
		return
	var body := Rect2(sim.pos.x - Tuning.HULL_HALF.x, sim.pos.y - Tuning.HULL_HALF.y, Tuning.HULL_HALF.x * 2.0, Tuning.HULL_HALF.y * 2.0 + Tuning.GEAR_LEN * sim.gear)
	if body.intersects(actor.hit_rect()):
		_squash_actor()

func _squash_actor() -> void:
	var job: Dictionary = jobs[job_index]
	var old := actor
	log.append({"type": "squashed", "voice": old.voice_key(), "name": old.pname})
	old.squash()
	leavers.append(old)
	actor = null
	squashes += 1
	var n := int(job.get("squashed", 0)) + 1
	job["squashed"] = n
	var new_pad := _pick_new_pad(job, String(old.pad.id), n)
	var ident := PassengerActor.pick_identity(level.id, job_index, n, String(job.get("passenger", "")))
	job["from"] = new_pad
	job["passenger"] = ident.name
	job["gender"] = ident.gender
	job["look"] = ident.look
	spawn_timer = SQUASH_RESPAWN_DELAY
	spawn_wait = false
	respawn_keep_clock = true
	phase = Phase.WAITING
	log.append({"type": "replacement", "pad": new_pad, "name": ident.name})

## Anderes Passagierpad als das des Vorfalls und das Zielpad; deterministisch je Level/Auftrag/Versuch.
func _pick_new_pad(job: Dictionary, current_id: String, attempt: int) -> String:
	var cands: Array = []
	for id in level.pads:
		if level.pads[id].fuel or id == current_id or id == String(job.get("to", "")):
			continue
		cands.append(id)
	cands.sort()
	if cands.is_empty():
		return current_id
	var h := absi(("%s:%d:%d" % [level.id, job_index, attempt]).hash())
	return cands[h % cands.size()]

func _finish_level() -> void:
	var job := current_job()
	if not job.is_empty() and is_exit_job(job) and phase == Phase.CARRYING and actor != null:
		var p := _payout(job)
		money += p.pay
		earned += p.pay
		delivered += 1
		job_times.append(job_clock)
		carried = {"name": actor.pname, "look": actor.look, "gender": actor.gender}
		log.append({"type": "delivered", "exit": true, "job": job_index, "fare": p.fare, "factor": p.factor, "penalty": p.penalty, "pay": p.pay, "voice": actor.voice_key(), "name": actor.pname})
		job_index += 1
		actor = null
	result = Result.COMPLETE
	log.append({"type": "level_complete"})

func _step_actors(dt: float) -> void:
	if spawn_timer > 0.0:
		spawn_timer -= dt
		if spawn_timer <= 0.0:
			spawn_wait = true
	if spawn_wait:
		# Neue Fahrgäste erscheinen nie auf dem Pad, auf dem das Taxi gerade steht
		var nj := current_job()
		var blocked: bool = sim.state == TaxiSim.State.LANDED and not nj.is_empty() and sim.landed_pad.id == String(nj.from)
		if not blocked:
			spawn_wait = false
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
				pen_pick = Tuning.landing_penalty(last_vy)
		Phase.BOARDING:
			if actor != null and actor.state == PassengerActor.S.ABOARD:
				phase = Phase.CARRYING
				var dest := "exit" if is_exit_job(job) else String(job.to)
				log.append({"type": "boarded", "job": job_index, "voice": actor.voice_key(), "name": actor.pname, "dest": dest})
				if is_exit_job(job):
					exit_open = true
					level.exit_open = true
					log.append({"type": "exit_open"})
		Phase.CARRYING:
			if not is_exit_job(job) and pad.id == String(job.to):
				phase = Phase.DROPOFF
				phase_timer = 0.0
				pen_drop = Tuning.landing_penalty(last_vy)
				actor.step_out(sim.pos.x, level.pads[String(job.to)])
		Phase.DROPOFF:
			phase_timer += dt
			if phase_timer >= STEP_OUT_TIME:
				_deliver(job)

func _payout(job: Dictionary) -> Dictionary:
	var fare := float(job.get("fare", 50))
	var factor := Tuning.time_factor(job_clock, par_of(job))
	var penalty := 1.0 - (1.0 - pen_pick) * (1.0 - pen_drop)
	return {"fare": fare, "factor": factor, "penalty": penalty, "pay": fare * factor * (1.0 - penalty), "time": job_clock}

func _deliver(job: Dictionary) -> void:
	var p := _payout(job)
	money += p.pay
	earned += p.pay
	delivered += 1
	job_times.append(job_clock)
	log.append({"type": "delivered", "job": job_index, "fare": p.fare, "factor": p.factor, "penalty": p.penalty, "pay": p.pay, "voice": actor.voice_key(), "name": actor.pname})
	leavers.append(actor)
	actor = null
	job_index += 1
	pen_pick = 0.0
	pen_drop = 0.0
	phase = Phase.WAITING
	phase_timer = 0.0
	if job_index >= jobs.size():
		exit_open = true
		level.exit_open = true
		log.append({"type": "exit_open"})
	else:
		spawn_timer = NEXT_SPAWN_DELAY
