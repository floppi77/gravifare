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
var dropoff_clock := 0.0    # Fahrtzeit im Moment des Aussteigens; danach zählt die Gehzeit zum Häuschen
var job_times: Array = []   # Dauer je zugestelltem Auftrag
var pen_pick := 0.0         # Abzug durch harte Landung beim Abholen
var pen_drop := 0.0         # Abzug durch harte Landung am Ziel
var last_vy := 0.0
var streak := 0               # perfekte Landungen in Folge
var best_streak := 0
var perfect_count := 0
var log: Array = []         # Ereignisse des letzten Ticks: {type, ...}
var actor: PassengerActor = null       # Fahrgast des aktuellen Auftrags
var leavers: Array = []                # abgelieferte Fahrgäste auf dem Weg in den Unterstand
var carried: Dictionary = {}           # Fahrgast, der ins nächste Level mitfährt {name, look, gender}
var spawn_timer := 0.0
var spawn_wait := false
var level_time := 0.0              # Levelzeit (läuft auch nach Verlust eines Lebens weiter) – Takt der Preiswechsel
var price_rng := RandomNumberGenerator.new()
var price_base := Tuning.FUEL_PRICE
var price_next_t := 0.0
var pump_touches := 0
var pump_cd := 0.0
var pump_boom_t := -1.0
var pump_broken := false           # Station explodiert (bleibt bis zum Neustart des Levels defekt)
var pump_warned := false
var respawn_keep_clock := false   # Ersatz-Fahrgast: Zeit läuft für den Auftrag weiter (Strafe durch Verzögerung)
var squashes := 0

func start(lvl: LevelData, fuel_in := -1.0, credits_in := 0.0, seed := -1) -> void:
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
	streak = 0
	best_streak = 0
	perfect_count = 0
	leavers.clear()
	carried = {}
	spawn_timer = 0.0
	spawn_wait = false
	respawn_keep_clock = false
	squashes = 0
	level_time = 0.0
	pump_touches = 0
	pump_cd = 0.0
	pump_boom_t = -1.0
	pump_broken = false
	pump_warned = false
	price_rng.seed = seed if seed >= 0 else absi(lvl.id.hash())      # reproduzierbar je Lauf/Level
	price_base = snappedf(price_rng.randf_range(lvl.fuel_price_min, lvl.fuel_price_max), 0.01)
	price_next_t = price_rng.randf_range(lvl.price_every.x, lvl.price_every.y)
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

## Streckenzuschlag des Auftrags (länger/schwieriger = mehr Geld), aus dem Layout berechnet und zwischengespeichert.
func job_mult(job: Dictionary) -> float:
	if job.is_empty() or not level.pads.has(String(job.get("from", ""))):
		return 1.0
	var to_id := String(job.get("to", ""))
	if to_id != "exit" and not level.pads.has(to_id):
		return 1.0
	return LevelMetrics.leg_mult(level, String(job.from), to_id)

## Voraussichtlicher Fahrpreis des laufenden Auftrags jetzt (ohne Landeabzug): tickt mit der Zeit herunter.
func prospect() -> float:
	var j := current_job()
	if j.is_empty():
		return 0.0
	return float(j.get("fare", 50)) * job_mult(j) * Tuning.time_factor(job_clock, par_of(j)) * combo_mult(streak)

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
			_evaluate_landing(e)
		elif e.type == "bad_landing":
			_break_streak()
	if sim.state == TaxiSim.State.DESTROYED:
		result = Result.FAILED
		return
	if actor != null or respawn_keep_clock:
		job_clock += dt
	_step_actors(dt)
	_update_prices(dt)
	_check_pump(dt)
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

## Perfekte Landung = weich (≤ 22 px/s), kaum seitlich (≤ 12 px/s), waagerecht (≤ 4°). Serie bis +30 % Fahrpreis.
func _evaluate_landing(e: Dictionary) -> void:
	if float(e.vy) <= Tuning.LAND_SOFT_VY and float(e.vx) <= Tuning.PERFECT_VX and float(e.tilt) <= Tuning.PERFECT_TILT:
		streak += 1
		perfect_count += 1
		best_streak = maxi(best_streak, streak)
		log.append({"type": "perfect", "streak": streak})
	else:
		_break_streak()

func _break_streak() -> void:
	if streak >= 2:
		log.append({"type": "streak_lost", "streak": streak})
	streak = 0

func combo_mult(combo: int) -> float:
	return 1.0 + Tuning.COMBO_STEP * float(mini(combo, Tuning.COMBO_MAX))

func _finish_level() -> void:
	var job := current_job()
	if not job.is_empty() and is_exit_job(job) and phase == Phase.CARRYING and actor != null:
		# Einkommen erst, wenn der Fahrgast im nächsten Level sein Häuschen erreicht; die Zahlungsinfo fährt mit
		carried = {"name": actor.pname, "look": actor.look, "gender": actor.gender, "pay_info": _make_pay_info(job, job_clock, pen_pick)}
		job_index += 1
		actor = null
	_settle_pending()
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
			if e.type == "arrived_home":          # sehr kurzer Weg: schon vor Ende der Aussteige-Phase im Häuschen
				_pay_leaver(actor, 0.0)
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
		for e in l.events:
			if e.type == "arrived_home":
				_pay_leaver(l, 0.0)
	leavers = leavers.filter(func(l): return l.state != PassengerActor.S.GONE)

func _service_pad(dt: float) -> void:
	if sim.state != TaxiSim.State.LANDED:
		pump_warned = false
		if phase == Phase.BOARDING:
			phase = Phase.WAITING
			phase_timer = 0.0
			if actor != null:
				actor.abort_board()
		elif phase == Phase.DROPOFF:
			if actor != null and not actor.pay_info.is_empty():
				# Taxi hebt ab, bevor der Fahrgast im Häuschen ist: er bleibt an Bord, keine Auszahlung
				phase = Phase.CARRYING
				phase_timer = 0.0
				actor.pay_info = {}
				actor.cancel_exit()
			elif actor != null:
				_deliver(current_job())          # schon bezahlt (Ankunft im Häuschen): Auftrag abschließen
		return
	var pad: Dictionary = sim.landed_pad
	# Tanken (nicht an einer explodierten/defekten Station)
	if pad.fuel and pump_touches >= Tuning.PUMP_TOUCHES_TO_BREAK:
		if not pump_warned:
			pump_warned = true
			log.append({"type": "pump_out"})
	elif pad.fuel and sim.fuel < Tuning.FUEL_MAX:
		var want := minf(Tuning.REFUEL_RATE * dt, Tuning.FUEL_MAX - sim.fuel)
		var free := sim.fuel < Tuning.EMERGENCY_FUEL
		var cost := want * fuel_price()
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
				dropoff_clock = job_clock
				actor.pay_info = _make_pay_info(job, dropoff_clock, pen_pick, pen_drop)
				actor.step_out(sim.pos.x, level.pads[String(job.to)])
		Phase.DROPOFF:
			phase_timer += dt
			if phase_timer >= STEP_OUT_TIME:
				_deliver(job)

func _make_pay_info(job: Dictionary, base_clock: float, pen_pickup: float, pen_dropoff := 0.0) -> Dictionary:
	return {"fare": float(job.get("fare", 50)) * job_mult(job), "par": par_of(job), "base": base_clock,
		"penalty": 1.0 - (1.0 - pen_pickup) * (1.0 - pen_dropoff), "combo": streak, "job": job_index, "name": String(job.get("passenger", ""))}

## Auszahlung, wenn der Fahrgast sein Häuschen erreicht hat; extra_time = noch fehlende Gehzeit (beim Levelende).
func _pay_leaver(l: PassengerActor, extra_time: float) -> void:
	if l.pay_info.is_empty():
		return
	var pay := l.pay_for(extra_time)
	var factor := l.factor_for(extra_time)
	var pen := float(l.pay_info.penalty)
	var total_time := float(l.pay_info.base) + l.exit_time + extra_time
	money += pay
	earned += pay
	delivered += 1
	job_times.append(total_time)
	log.append({"type": "delivered", "job": int(l.pay_info.job), "fare": l.pay_info.fare, "factor": factor, "penalty": pen, "combo": int(l.pay_info.get("combo", 0)), "pay": pay, "voice": l.voice_key(), "name": l.pname})
	l.pay_info = {}

## Beim Levelende noch laufende Fahrgäste gelten als angekommen (Rest-Gehzeit wird eingerechnet).
func _settle_pending() -> void:
	for l in leavers:
		if not l.pay_info.is_empty() and not l.angry:
			_pay_leaver(l, l.remaining_walk())

func _deliver(job: Dictionary) -> void:
	## Aussteigen abgeschlossen: Auftrag ist erledigt, der Fahrgast läuft zum Häuschen. Bezahlt wird erst dort.
	log.append({"type": "dropped", "job": job_index, "name": actor.pname})
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

## Taxi zerstört (Leben verloren): Das Level läuft weiter, nichts wird neu gestartet. Der Fahrgast an Bord ist verloren
## (kein Geld) und wartet – derselbe Fahrgast – erneut an seinem Abholpad. Erledigtes bleibt erledigt. Neues Taxi
## am Startpad mit Mindest-Sprit (35 %) bzw. dem Rest-Sprit, falls mehr.
func respawn_after_crash() -> void:
	var fuel_keep := clampf(maxf(sim.fuel, Tuning.MIN_START_FUEL), 0.0, Tuning.FUEL_MAX)
	var lost: bool = actor != null and (phase == Phase.CARRYING or phase == Phase.DROPOFF)
	sim.setup(level)
	sim.fuel = fuel_keep
	result = Result.RUNNING
	last_vy = 0.0
	streak = 0
	if lost:
		log.append({"type": "passenger_lost", "name": actor.pname, "pad": String(current_job().get("from", ""))})
		actor = null
		pen_pick = 0.0
		pen_drop = 0.0
		job_clock = 0.0
		respawn_keep_clock = false
		spawn_timer = SQUASH_RESPAWN_DELAY
		spawn_wait = false
	elif actor != null and phase == Phase.BOARDING:
		actor.abort_board()
	phase = Phase.WAITING
	phase_timer = 0.0
	exit_open = job_index >= jobs.size()
	level.exit_open = exit_open

# ---------------------------------------------------------------- Spritpreis und Zapfsäule
## Aktueller Preis je Einheit: zufälliger Basispreis im Levelbereich (wechselt in zufälligen Abständen, sprunghaft),
## dazu +25 % je Berührung der Zapfsäule, gedeckelt (1,6 × Maximalpreis).
func fuel_price() -> float:
	var touches := mini(pump_touches, Tuning.PUMP_TOUCHES_TO_BREAK)
	return minf(price_base * (1.0 + Tuning.PRICE_TOUCH_SURCHARGE * float(touches)), level.fuel_price_max * Tuning.PRICE_HARD_CAP)

func station_down() -> bool:
	return pump_touches >= Tuning.PUMP_TOUCHES_TO_BREAK

func _roll_price(old: float) -> float:
	var p := old
	for i in 8:
		p = snappedf(price_rng.randf_range(level.fuel_price_min, level.fuel_price_max), 0.01)
		if absf(p - old) >= Tuning.PRICE_MIN_STEP:
			break
	return p

func _update_prices(dt: float) -> void:
	level_time += dt
	if level_time >= price_next_t:
		var old := price_base
		price_base = _roll_price(old)
		price_next_t = level_time + price_rng.randf_range(level.price_every.x, level.price_every.y)
		if level.pads.has("F"):
			log.append({"type": "price_changed", "price": fuel_price(), "up": price_base > old})

func _check_pump(dt: float) -> void:
	pump_cd = maxf(0.0, pump_cd - dt)
	if pump_boom_t >= 0.0:
		pump_boom_t -= dt
		if pump_boom_t < 0.0:
			pump_broken = true
			log.append({"type": "pump_exploded", "rect": level.pumps[0].rect if not level.pumps.is_empty() else Rect2()})
	if level.pumps.is_empty() or pump_touches >= Tuning.PUMP_TOUCHES_TO_BREAK or pump_cd > 0.0 or sim.state == TaxiSim.State.DESTROYED:
		return
	var body := Rect2(sim.pos.x - Tuning.HULL_HALF.x - 1.2, sim.pos.y - Tuning.HULL_HALF.y - 1.2, Tuning.HULL_HALF.x * 2.0 + 2.4, Tuning.HULL_HALF.y * 2.0 + Tuning.GEAR_LEN * sim.gear + 2.4)
	for pm in level.pumps:
		if body.intersects(pm.rect):
			pump_touches += 1
			pump_cd = Tuning.PUMP_TOUCH_COOLDOWN
			log.append({"type": "pump_touched", "stage": pump_touches, "price": fuel_price()})
			if pump_touches >= Tuning.PUMP_TOUCHES_TO_BREAK:
				pump_boom_t = Tuning.PUMP_BOOM_DELAY
			return
