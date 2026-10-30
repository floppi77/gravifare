class_name Run
extends RefCounted
## Auftragslogik, Credits und Levelabschluss um eine TaxiSim herum. Rein datenbasiert und testbar.
## Fahrgäste sind PassengerActor-Objekte; Ein-/Aussteigen dauert so lange, wie sie laufen.
## Der letzte Auftrag eines Levels ist der Ausgangs-Fahrgast ("to": "exit"): Das Tor öffnet, sobald er an
## Bord ist; er wird durch das Tor ins nächste Level gebracht.

enum Phase { WAITING, BOARDING, CARRYING, DROPOFF }
enum Result { RUNNING, COMPLETE, FAILED }

const STEP_OUT_TIME := 0.5
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
var damage_taken := 0.0       # Hüllenschaden im Level (für die Medaille „Sauber“)
var respawns := 0             # verlorene Leben im Level
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
enum ES { WAIT, BOARD, CARRY, DROP }
var extras: Array = []             # Zusatzfahrgäste: {job, actor, state, clock, patience, patience_max, pen_pick, timer}
var extras_enabled := true         # Bot-/Teststeuerung
var extra_timer := 0.0
var extra_count := 0
var extras_delivered := 0
var extras_missed := 0
var extra_earned := 0.0
var flow_rng := RandomNumberGenerator.new()
var main_wait := 0.0               # Wartezeit des aktuellen Auftrags-Fahrgasts
var main_patience := 60.0
var refuel_tick := false          # in diesem Tick wurde getankt: Spritpreis bleibt dann unverändert
var missed := 0                   # Pflichtfahrgäste, die nicht befördert wurden (Geduld abgelaufen)
var missed_fees := 0.0
var pen_ride := 0.0               # Abzug dieser Fahrt: falsche Plattform, Schaden mit Fahrgast an Bord
var taxi_damage := 0.0            # Hüllenschaden des aktuellen Taxis (wird am Levelende repariert, kostet Credits)
var repair_cost := 0.0            # Reparaturrechnung dieses Levels
var taxi_fees := 0.0              # Ersatztaxis in diesem Level

func start(lvl: LevelData, fuel_in := -1.0, credits_in := 0.0, seed := -1) -> void:
	level = lvl
	jobs = lvl.jobs.duplicate(true)
	var fscale := Tuning.fare_scale(lvl.number)
	for j in jobs:
		j["fare"] = snappedf(float(j.get("fare", 50)) * fscale, 1.0)      # Level-Daten bleiben unverändert
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
	damage_taken = 0.0
	respawns = 0
	leavers.clear()
	carried = {}
	spawn_timer = 0.0
	spawn_wait = false
	respawn_keep_clock = false
	squashes = 0
	extras.clear()
	extra_count = 0
	extras_delivered = 0
	extras_missed = 0
	extra_earned = 0.0
	taxi_damage = 0.0
	pen_ride = 0.0
	missed = 0
	missed_fees = 0.0
	repair_cost = 0.0
	taxi_fees = 0.0
	level_time = 0.0
	pump_touches = 0
	pump_cd = 0.0
	pump_boom_t = -1.0
	pump_broken = false
	pump_warned = false
	price_rng.seed = seed if seed >= 0 else absi(lvl.id.hash())      # reproduzierbar je Lauf/Level
	price_base = snappedf(price_rng.randf_range(lvl.fuel_price_min, lvl.fuel_price_max), 0.01)
	price_next_t = price_rng.randf_range(lvl.price_every.x, lvl.price_every.y)
	flow_rng.seed = price_rng.seed + 17 + (seed if seed >= 0 else 0)
	extra_timer = flow_rng.randf_range(Tuning.EXTRA_FIRST_MIN, Tuning.EXTRA_FIRST_MAX)
	actor = null
	_spawn_actor(true)

func _spawn_actor(instant: bool) -> void:
	var job := current_job()
	if job.is_empty():
		actor = null
		return
	actor = PassengerActor.new()
	actor.setup(job, level.pads[String(job.from)], job_index, instant)
	main_wait = 0.0
	main_patience = flow_rng.randf_range(Tuning.MAIN_PATIENCE_MIN, Tuning.MAIN_PATIENCE_MAX)
	if not respawn_keep_clock:
		job_clock = 0.0
	respawn_keep_clock = false

func current_job() -> Dictionary:
	return jobs[job_index] if job_index < jobs.size() else {}

func is_exit_job(job: Dictionary) -> bool:
	return String(job.get("to", "")) == "exit"

func target_pad() -> String:
	var ex := _extra_aboard()
	if not ex.is_empty():
		return String(ex.job.to)
	var j := current_job()
	if j.is_empty():
		return ""
	if phase == Phase.CARRYING or phase == Phase.DROPOFF:
		return "" if is_exit_job(j) else String(j.to)
	return String(j.from)

## Fahrgast, der gerade im Taxi sitzt (Auftrags- oder Zusatzfahrgast), sonst null.
func aboard_actor() -> PassengerActor:
	var ex := _extra_aboard()
	if not ex.is_empty() and int(ex.state) == ES.CARRY:
		return ex.actor
	if actor != null and phase == Phase.CARRYING:
		return actor
	return null

func _aboard_dest() -> String:
	var ex := _extra_aboard()
	if not ex.is_empty():
		return String(ex.job.to)
	var j := current_job()
	return "" if j.is_empty() else String(j.to)       # "exit" für den Ausgangs-Fahrgast: jede Landung ist falsch

## Landung an einer falschen Plattform mit Fahrgast an Bord: Fahrgast meckert, Fahrpreis sinkt eine Stufe.
func _check_wrong_pad(pad_id: String) -> void:
	var a := aboard_actor()
	var dest := _aboard_dest()
	if a == null or dest == "" or pad_id == dest or level.pads[pad_id].fuel or pad_id == String(a.pad.id):
		return              # Zielpad, Tankpad und das Abholpad (Nachsetzen nach dem Abheben) sind nie „falsch“
	pen_ride = minf(Tuning.RIDE_PEN_MAX, pen_ride + Tuning.WRONG_PAD_PEN)
	log.append({"type": "wrong_pad", "voice": a.voice_key(), "name": a.pname, "pct": int(round(Tuning.WRONG_PAD_PEN * 100.0))})

func _ride_hit(e: Dictionary) -> void:
	var a := aboard_actor()
	if a == null or e.get("fatal", false):
		return
	pen_ride = minf(Tuning.RIDE_PEN_MAX, pen_ride + Tuning.RIDE_HIT_PEN)
	log.append({"type": "ride_damage", "voice": a.voice_key(), "name": a.pname, "pct": int(round(Tuning.RIDE_HIT_PEN * 100.0))})

## Zielplattform eines wartenden Fahrgasts ("1".."9" oder "exit"), "" wenn unbekannt.
func dest_of(a: PassengerActor) -> String:
	var ex := extra_of(a)
	if not ex.is_empty():
		return String(ex.job.to)
	if a == actor and not current_job().is_empty():
		return String(current_job().to)
	return ""

## Pad, auf das Pfeil und Leuchtfeuer zeigen: erst, wenn der Fahrgast tatsächlich erscheint (nicht schon nach dem Absetzen).
func marker_pad() -> String:
	if _extra_aboard().is_empty() and phase == Phase.WAITING and actor == null:
		return ""
	return target_pad()

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
			_check_wrong_pad(String(e.pad))
		elif e.type == "bad_landing":
			_break_streak()
		elif e.type == "damage":
			damage_taken += float(e.amount)
			taxi_damage += float(e.amount)
			_ride_hit(e)
	if sim.state == TaxiSim.State.DESTROYED:
		result = Result.FAILED
		return
	if actor != null or respawn_keep_clock:
		job_clock += dt
	_step_actors(dt)
	_step_extras(dt)
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

## Pflichtfahrgast hat zu lange gewartet: Er geht ohne Ersatz, der Auftrag gilt als verpasst (Abzug); nach dem letzten
## Pflichtfahrgast – befördert oder nicht – öffnet das Tor.
func _miss_job() -> void:
	var old := actor
	log.append({"type": "extra_left", "voice": old.voice_key(), "name": old.pname})
	old.squash()
	leavers.append(old)
	actor = null
	var fee := minf(snappedf(float(level.jobs[job_index].get("fare", 50)) * Tuning.MISSED_FEE_FACTOR, 1.0), money)
	money -= fee
	missed += 1
	missed_fees += fee
	log.append({"type": "job_missed", "name": old.pname, "fee": fee})
	job_index += 1
	job_clock = 0.0
	respawn_keep_clock = false
	pen_pick = 0.0
	pen_drop = 0.0
	pen_ride = 0.0
	phase = Phase.WAITING
	phase_timer = 0.0
	if job_index >= jobs.size():
		exit_open = true
		level.exit_open = true
		log.append({"type": "exit_open"})
	else:
		spawn_timer = flow_rng.randf_range(Tuning.NEXT_SPAWN_MIN, Tuning.NEXT_SPAWN_MAX)
		spawn_wait = false

func _squash_actor() -> void:
	var job: Dictionary = jobs[job_index]
	var old := actor
	log.append({"type": "squashed", "voice": old.voice_key(), "name": old.pname})
	squashes += 1
	old.squash()
	leavers.append(old)
	actor = null
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
	repair_cost = minf(snappedf(minf(taxi_damage, Tuning.HULL_MAX) * Tuning.REPAIR_COST, 1.0), money)
	if repair_cost > 0.0:
		money -= repair_cost
		log.append({"type": "cost", "what": "repair", "amount": repair_cost})
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
		var blocked: bool = (sim.state == TaxiSim.State.LANDED and not nj.is_empty() and sim.landed_pad.id == String(nj.from)) \
			or (not nj.is_empty() and _extra_at(String(nj.from)) != null)
		if not blocked:
			spawn_wait = false
			_spawn_actor(false)
	if actor != null:
		actor.step(dt)
		if actor.state == PassengerActor.S.WAITING and phase == Phase.WAITING:
			main_wait += dt
			if main_wait >= main_patience and actor.can_be_hit():
				_miss_job()
				return
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
	refuel_tick = false
	_service_extras()
	if sim.state != TaxiSim.State.LANDED:
		pump_warned = false
		if phase == Phase.BOARDING:
			phase = Phase.WAITING
			phase_timer = 0.0
			if actor != null:
				actor.abort_board()
		elif phase == Phase.DROPOFF:
			if actor != null:
				_deliver(current_job())          # Fahrgast ist schon ausgestiegen: er geht auch bei sofortigem Abflug zum Häuschen
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
			refuel_tick = true
		elif money >= cost:
			money -= cost
			sim.refuel(want)
			refuel_tick = true
	var job := current_job()
	if job.is_empty():
		return
	match phase:
		Phase.WAITING:
			if pad.id == String(job.from) and actor != null and actor.state == PassengerActor.S.WAITING and not extra_busy():
				actor.board(sim.pos.x)
				phase = Phase.BOARDING
				phase_timer = 0.0
				pen_pick = Tuning.landing_penalty(last_vy)
				pen_ride = 0.0
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
		"penalty": 1.0 - (1.0 - pen_pickup) * (1.0 - pen_dropoff) * (1.0 - pen_ride), "combo": streak, "job": job_index, "name": String(job.get("passenger", ""))}

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
	var is_extra: bool = l.pay_info.get("extra", false)
	if is_extra:
		extra_earned += pay
		extras_delivered += 1
	else:
		delivered += 1
		job_times.append(total_time)
	log.append({"type": "delivered", "extra": is_extra, "job": int(l.pay_info.job), "fare": l.pay_info.fare, "factor": factor, "penalty": pen, "combo": int(l.pay_info.get("combo", 0)), "pay": pay, "voice": l.voice_key(), "name": l.pname})
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
	pen_ride = 0.0
	phase = Phase.WAITING
	phase_timer = 0.0
	if job_index >= jobs.size():
		exit_open = true
		level.exit_open = true
		log.append({"type": "exit_open"})
	else:
		spawn_timer = flow_rng.randf_range(Tuning.NEXT_SPAWN_MIN, Tuning.NEXT_SPAWN_MAX)

## Taxi zerstört (Leben verloren): Das Level läuft weiter, nichts wird neu gestartet. Der Fahrgast an Bord ist verloren
## (kein Geld) und wartet – derselbe Fahrgast – erneut an seinem Abholpad. Erledigtes bleibt erledigt. Neues Taxi
## am Startpad mit Mindest-Sprit (35 %) bzw. dem Rest-Sprit, falls mehr.
func respawn_after_crash() -> void:
	var fuel_keep := clampf(maxf(sim.fuel, Tuning.MIN_START_FUEL), 0.0, Tuning.FUEL_MAX)
	if actor != null and phase == Phase.DROPOFF:
		_deliver(current_job())             # schon ausgestiegen: bleibt abgeliefert, läuft zum Häuschen
	for ex in extras.duplicate():
		if int(ex.state) == ES.CARRY or int(ex.state) == ES.BOARD:
			log.append({"type": "passenger_lost", "name": ex.actor.pname, "pad": String(ex.job.from)})
			extras.erase(ex)
		elif int(ex.state) == ES.DROP:
			_finish_extra_drop(ex)
	var lost: bool = actor != null and phase == Phase.CARRYING
	respawns += 1
	var fee := minf(Tuning.replacement_fee(level.number), money)
	if fee > 0.0:
		money -= fee
		taxi_fees += fee
		log.append({"type": "cost", "what": "taxi", "amount": fee})
	taxi_damage = 0.0
	sim.setup(level)
	sim.fuel = fuel_keep
	result = Result.RUNNING
	last_vy = 0.0
	streak = 0
	if lost:
		pen_ride = 0.0
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
			return p
	var up := old + Tuning.PRICE_MIN_STEP
	return snappedf(up if up <= level.fuel_price_max else old - Tuning.PRICE_MIN_STEP, 0.01)

func _update_prices(dt: float) -> void:
	level_time += dt
	if refuel_tick:                       # während des Tankens ändert sich der Preis nie: Wechsel wird verschoben
		price_next_t += dt
		return
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

# ---------------------------------------------------------------- Medaillen (je Level, dauerhaft gespeichert)
## Zielwerte: Zeit = 1,2 × Summe der Richtzeiten + 10 s; Einkommen = Summe der Fahrpreise (mit Streckenzuschlag) der
## normalen Aufträge (ohne Ausgangs-Fahrgast, der erst im nächsten Level bezahlt wird).
func time_target() -> float:
	var sum_par := 0.0
	for j in jobs:
		sum_par += par_of(j)
	return sum_par * 1.2 + 10.0

func money_target() -> float:
	var sum := 0.0
	for j in jobs:
		if not is_exit_job(j):
			sum += float(j.get("fare", 50)) * job_mult(j)
	return sum

## ⏱ Zeit: im Zeitziel · ♥ Sauber: kein Leben verloren, nie Fahrgast/Zapfsäule getroffen, ≤ 10 % Hüllenschaden ·
## ★ Meister: ≥ 110 % des Einkommensziels und mindestens Serie 2.
func medals() -> Dictionary:
	return {
		"time": level_time <= time_target(),
		"clean": respawns == 0 and squashes == 0 and pump_touches == 0 and damage_taken <= 10.0,
		"pro": earned >= money_target() * 1.1 and best_streak >= 2,
	}

# ---------------------------------------------------------------- Zusatzfahrgäste (ab Level 5)
func extras_active() -> bool:
	return extras_enabled and Tuning.extra_slots(level.number) > 0

func extra_busy() -> bool:
	return not _extra_aboard().is_empty() or extras.any(func(e): return int(e.state) == ES.BOARD)

func _extra_aboard() -> Dictionary:
	for e in extras:
		if int(e.state) == ES.CARRY or int(e.state) == ES.DROP:
			return e
	return {}

func _extra_at(pad_id: String) -> Variant:
	for e in extras:
		if String(e.job.from) == pad_id and int(e.state) == ES.WAIT:
			return e
	return null

func extra_of(a: PassengerActor) -> Dictionary:
	for e in extras:
		if e.actor == a:
			return e
	return {}

## Voraussichtlicher Fahrpreis eines wartenden/aufgenommenen Zusatzfahrgasts (tickt mit der Zeit herunter).
func extra_prospect(e: Dictionary) -> float:
	return float(e.job.fare) * job_mult(e.job) * Tuning.time_factor(float(e.clock), par_of(e.job)) * combo_mult(streak)

func extra_factor(e: Dictionary) -> float:
	return Tuning.time_factor(float(e.clock), par_of(e.job))

func _spawn_extra() -> void:
	var cands: Array = []
	for id in level.pads:
		if level.pads[id].fuel:
			continue
		if actor != null and String(actor.pad.id) == id:
			continue
		var nj := current_job()
		if not nj.is_empty() and String(nj.from) == id and phase == Phase.WAITING:
			continue
		if _extra_at(id) != null:
			continue
		if sim.state == TaxiSim.State.LANDED and String(sim.landed_pad.id) == id:
			continue
		cands.append(id)
	cands.sort()
	if cands.is_empty():
		return
	var from_id: String = cands[flow_rng.randi() % cands.size()]
	var dests: Array = []
	for id in level.pads:
		if not level.pads[id].fuel and id != from_id:
			dests.append(id)
	dests.sort()
	if dests.is_empty():
		return
	var to_id: String = dests[flow_rng.randi() % dests.size()]
	extra_count += 1
	var used: Array = []
	for j in jobs:
		used.append(String(j.get("passenger", "")))
	for e in extras:
		used.append(String(e.actor.pname))
	var ident := PassengerActor.pick_identity(level.id, 100 + extra_count, extra_count, "")
	for k in range(1, 12):
		if not used.has(String(ident.name)):
			break
		ident = PassengerActor.pick_identity(level.id, 100 + extra_count + k * 31, extra_count + k, "")
	var fare_sum := 0.0
	var fare_n := 0
	for j in level.jobs:
		if not is_exit_job(j):
			fare_sum += float(j.get("fare", 50))
			fare_n += 1
	var base_fare := maxf(35.0, snappedf(fare_sum / maxf(float(fare_n), 1.0) * 0.7 * Tuning.EXTRA_FARE_FACTOR, 5.0))
	var dist: float = absf(float(level.pads[from_id].center) - float(level.pads[to_id].center)) + absf(float(level.pads[from_id].row) - float(level.pads[to_id].row)) * Tuning.TILE
	var job := {"from": from_id, "to": to_id, "fare": base_fare, "par": snappedf(14.0 + dist / 38.0, 1.0),
		"passenger": ident.name, "gender": ident.gender, "look": ident.look}
	var a := PassengerActor.new()
	a.setup(job, level.pads[from_id], 100 + extra_count, false)
	var pat := flow_rng.randf_range(Tuning.EXTRA_PATIENCE_MIN, Tuning.EXTRA_PATIENCE_MAX)
	extras.append({"job": job, "actor": a, "state": ES.WAIT, "clock": 0.0, "patience": pat, "patience_max": pat, "pen_pick": 0.0, "timer": 0.0})
	log.append({"type": "extra_appeared", "name": ident.name, "pad": from_id, "to": to_id})

func _step_extras(dt: float) -> void:
	if not extras_active():
		return
	var main_done := job_index >= jobs.size() or exit_open or (not current_job().is_empty() and is_exit_job(current_job()) and phase != Phase.WAITING)
	if not main_done:
		extra_timer -= dt
		var waiting := extras.filter(func(e): return int(e.state) == ES.WAIT).size()
		if extra_timer <= 0.0:
			extra_timer = flow_rng.randf_range(Tuning.EXTRA_EVERY_MIN, Tuning.EXTRA_EVERY_MAX)
			if waiting < Tuning.extra_slots(level.number):
				_spawn_extra()
	for e in extras.duplicate():
		var a: PassengerActor = e.actor
		a.step(dt)
		for ev in a.events:
			if ev.type == "arrived_wait":
				a.wave()
				a.call_cd = CALL_COOLDOWN
				log.append({"type": "call", "voice": a.voice_key(), "name": a.pname})
		match int(e.state):
			ES.WAIT:
				e.clock += dt
				e.patience -= dt
				if a.state == PassengerActor.S.WAITING and a.call_cd <= 0.0 and sim.state == TaxiSim.State.FLYING and sim.pos.distance_to(a.world_pos()) < CALL_RANGE:
					a.wave()
					a.call_cd = CALL_COOLDOWN
					log.append({"type": "call", "voice": a.voice_key(), "name": a.pname})
				if e.patience <= 0.0 and a.can_be_hit():
					a.squash()
					extras_missed += 1
					leavers.append(a)
					extras.erase(e)
					log.append({"type": "extra_left", "voice": a.voice_key(), "name": a.pname})
			ES.BOARD:
				e.clock += dt
				if a.state == PassengerActor.S.ABOARD:
					e.state = ES.CARRY
					log.append({"type": "boarded", "job": -1, "voice": a.voice_key(), "name": a.pname, "dest": String(e.job.to), "extra": true})
			ES.CARRY:
				e.clock += dt
			ES.DROP:
				e.timer += dt
				if e.timer >= STEP_OUT_TIME:
					_finish_extra_drop(e)

func _finish_extra_drop(e: Dictionary) -> void:
	log.append({"type": "dropped", "job": -1, "name": e.actor.pname, "extra": true})
	leavers.append(e.actor)
	extras.erase(e)

func _service_extras() -> void:
	if not extras_active():
		return
	var landed := sim.state == TaxiSim.State.LANDED
	for e in extras.duplicate():
		match int(e.state):
			ES.BOARD:
				if not landed:
					e.state = ES.WAIT
					e.actor.abort_board()
			ES.DROP:
				if not landed:
					_finish_extra_drop(e)
	if not landed:
		return
	var pad: Dictionary = sim.landed_pad
	var aboard := _extra_aboard()
	if not aboard.is_empty():
		if int(aboard.state) == ES.CARRY and String(aboard.job.to) == String(pad.id):
			aboard.state = ES.DROP
			aboard.timer = 0.0
			var pen_drop_x := Tuning.landing_penalty(last_vy)
			var info := _make_pay_info(aboard.job, float(aboard.clock), float(aboard.pen_pick), pen_drop_x)
			info["extra"] = true
			info["job"] = -1
			aboard.actor.pay_info = info
			aboard.actor.step_out(sim.pos.x, level.pads[String(aboard.job.to)])
		return
	if phase != Phase.WAITING or exit_open:
		return
	var main_here: bool = actor != null and String(actor.pad.id) == String(pad.id) and actor.state != PassengerActor.S.GONE
	if main_here:
		return
	var w: Variant = _extra_at(String(pad.id))
	if w != null and w.actor.state == PassengerActor.S.WAITING:
		w.actor.board(sim.pos.x)
		w.state = ES.BOARD
		w.pen_pick = Tuning.landing_penalty(last_vy)
		pen_ride = 0.0
