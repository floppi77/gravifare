extends Node2D
## Spielszene: verbindet Eingabe, Run-Logik, Darstellung, Kamera und HUD.
## Aufruf mit Level: godot --path . -- --level=s1_01  (Screenshot: --shot=pfad.png --frames=N)

var level_path := ""
var run := Run.new()
var paused := false
var gear_on := false
var restart_timer := 0.0
var cam_off := Vector2.ZERO
var shake := 0.0
var near_cd := 0.0
var slowmo_left := 0.0
var completion_saved := false
const TV := preload("res://src/game/transition_view.gd")
var replay: Replay = null              # Aufzeichnung des laufenden Levels (Replay-Fundament)
var arrive_path := PackedVector2Array()   # hindernisfreier Einflug-Pfad (Pathing.arrival_path)
var trans_t := -1.0              # Zeitachse des Levelwechsels (siehe transition_view.gd), < 0 = inaktiv
var next_id := ""
var arriving := false
var arrive_done := false
var arrive_start := Vector2.ZERO
var arrive_end := Vector2.ZERO
var arrive_prev := Vector2.ZERO

@onready var world: Node2D = $World
@onready var taxi: Node2D = $World/Taxi
@onready var cam: Camera2D = $Camera
@onready var hud: Control = $Hud/Root
@onready var bg: Control = $Backdrop/Bg
@onready var world_tiles: Node2D = $World/Tiles
@onready var props: Node2D = $World/Props
@onready var fx: Node2D = $World/Fx
@onready var trans: Control = $Trans/Root
var script_inputs: Array = []
var autopilot: Bot = null
var debug_input := Vector2.INF   # --debug-input=x,y erzwingt konstanten Schub (Screenshots)

func _ready() -> void:
	if Flow.current_level == "":
		Flow.current_level = "s1_01"
	level_path = Flow.level_path(Flow.current_level)
	var unlit := CanvasItemMaterial.new()
	unlit.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	props.material = unlit
	taxi.material = unlit
	_setup_look()
	load_level(level_path)
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--debug-input="):
			var xy := a.substr(14).split(",")
			debug_input = Vector2(float(xy[0]), float(xy[1]))
			gear_on = false
			run.sim.state = TaxiSim.State.FLYING
			run.sim.landed_pad = {}
	if OS.get_cmdline_user_args().has("--debug-squash") and run.actor != null:    # Dev: Taxi senkt sich auf den wartenden Fahrgast
		var sp: Dictionary = run.actor.pad
		run.sim.state = TaxiSim.State.FLYING
		run.sim.landed_pad = {}
		run.sim.gear = 1.0
		run.sim.pos = Vector2(run.actor.x, sp.row * Tuning.TILE - 46.0)
		run.sim.vel = Vector2(0, 30)
		gear_on = true
		debug_input = Vector2(0, 0)
		taxi.sync_state()
		taxi.reset_physics_interpolation()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--debug-pump="):          # Dev: Zapfsäule auf Schadensstufe N setzen (3 = Explosion)
			run.pump_touches = int(a.substr(13))
			if run.pump_touches >= 3:
				run.pump_boom_t = 0.05
	if OS.get_cmdline_user_args().has("--debug-destroy"):     # Dev: Taxi sofort zerstören (Leben-/Game-Over-Anzeige)
		run.sim.hull = 0.0
		run.sim.state = TaxiSim.State.DESTROYED
	if OS.get_cmdline_user_args().has("--autopilot"):
		run.extras_enabled = false      # Dev-Autopilot fährt nur die Auftragskette
		autopilot = Bot.new(run)
	if OS.get_cmdline_user_args().has("--debug-extra"):      # Dev: Zusatzfahrgast sofort
		run.extra_timer = 0.3
	if OS.get_cmdline_user_args().has("--debug-complete"):
		run.exit_open = true
		run.level.exit_open = true
		run.sim.state = TaxiSim.State.FLYING
		run.sim.landed_pad = {}
		run.sim.pos = run.level.exit_rect().get_center()
	if OS.get_cmdline_user_args().has("--debug-open-exit"):
		run.exit_open = true
		run.level.exit_open = true
		props.door = 1.0

## Bildcharakter: HDR-Bloom auf Lichter/Abgase/Neon, leichte Farbkorrektur und Vignette für Tiefe.
func _setup_look() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_CANVAS
	env.glow_enabled = true
	env.glow_hdr_threshold = 0.92
	env.glow_intensity = 0.55
	env.glow_strength = 1.0
	env.glow_bloom = 0.0
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var layer := CanvasLayer.new()
	layer.layer = 5
	var rect := ColorRect.new()
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := Shader.new()
	sh.code = "shader_type canvas_item;\nvoid fragment() {\n\tvec2 u = (UV - 0.5) * vec2(1.0, 1.1);\n\tfloat d = dot(u, u);\n\tCOLOR = vec4(0.0, 0.0, 0.04, smoothstep(0.2, 0.62, d) * 0.42);\n}\n"
	var mat := ShaderMaterial.new()
	mat.shader = sh
	rect.material = mat
	layer.add_child(rect)
	add_child(layer)

func load_level(path: String) -> void:
	var lvl := LevelData.load_file(path)
	if lvl == null:
		push_error("Level konnte nicht geladen werden: " + path)
		return
	run.start(lvl, Flow.entry_fuel, Flow.entry_credits, Flow.run_seed + lvl.number * 7919)
	run.lives = Flow.lives
	replay = Replay.new()
	replay.begin(lvl.id, Flow.run_seed + lvl.number * 7919, Flow.entry_fuel, Flow.entry_credits, Flow.carry_passenger, run.extras_enabled)
	Music.play_theme(Music.theme_for_level(lvl.number))
	Music.duck(0.0)
	gear_on = run.sim.gear_cmd
	world_tiles.setup(run)
	props.setup(run)
	fx.setup(run)
	taxi.bind(run.sim)
	taxi.sync_state()
	taxi.reset_physics_interpolation()
	hud.bind(run)
	if autopilot != null:
		run.extras_enabled = false      # Dev-Autopilot fährt nur die Auftragskette
		autopilot = Bot.new(run)
	hud.paused = false
	paused = false
	restart_timer = 0.0
	completion_saved = false
	_setup_camera()
	bg.setup(lvl)

func _setup_camera() -> void:
	var sz := run.level.pixel_size()
	cam.limit_left = -100000
	cam.limit_top = -100000
	cam.limit_right = 100000
	cam.limit_bottom = 100000     # Begrenzung übernimmt _cam_target(); Offset (Vorausblick/Wackeln) darf kurz darüber
	cam.position_smoothing_enabled = false
	cam.process_callback = Camera2D.CAMERA2D_PROCESS_PHYSICS      # passt zur Physik-Interpolation (keine Warnung)
	cam.global_position = _cam_target()
	cam.reset_physics_interpolation()

func _cam_target() -> Vector2:
	var view := Vector2(640, 360)
	var sz := run.level.pixel_size()
	var p := run.sim.pos
	return Vector2(
		sz.x * 0.5 if sz.x <= view.x else clampf(p.x, view.x * 0.5, sz.x - view.x * 0.5),
		sz.y * 0.5 if sz.y <= view.y else clampf(p.y, view.y * 0.5, sz.y - view.y * 0.5))

var pause_menu: Control

func _set_paused(on: bool) -> void:
	paused = on
	hud.paused = on
	Music.duck(-8.0 if on else 0.0)
	Sfx.set_thrust(0.0, 0.0)
	Haptics.stop()
	_end_slowmo()
	if on:
		pause_menu = PauseMenu.new()
		pause_menu.game = self
		hud.add_child(pause_menu)
	elif pause_menu != null:
		pause_menu.queue_free()
		pause_menu = null

func _unhandled_input(event: InputEvent) -> void:
	if trans_t >= 0.0:
		# Levelwechsel: A/Enter/B/Esc überspringen die Sequenz bis zum Einblenden; sonst keine Eingabe
		if (event.is_action_pressed("ui_accept") or event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause")) and trans_t < TV.T_IN - 0.01:
			trans_t = TV.T_IN - 0.001
			Sfx.stop_long()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("pause"):
		if run.result == Run.Result.RUNNING:
			_set_paused(not paused)
		else:
			Flow.to_menu()
		get_viewport().set_input_as_handled()
	elif paused:
		return
	elif event.is_action_pressed("ui_accept") and run.result == Run.Result.COMPLETE and completion_saved and hud.result_age >= 0.7:
		if Flow.next_level_id() != "":
			_begin_transition()     # Ergebnisansicht bestätigt: Levelwechsel-Sequenz starten
		else:
			Flow.to_menu()          # letztes Level: zurück ins Menü
		get_viewport().set_input_as_handled()
	elif hud.game_over:
		if event.is_action_pressed("ui_accept"):
			Flow.to_menu()
	elif event.is_action_pressed("restart"):
		if run.result == Run.Result.FAILED:
			_lose_life()
		else:
			load_level(level_path)
	elif event.is_action_pressed("gear") and not paused and Controls.gear_toggle:
		gear_on = not gear_on

func _physics_process(_delta: float) -> void:
	if paused:
		return
	if trans_t >= 0.0:
		_arrival_tick()
		return
	var v := Controls.thrust_vector()
	if debug_input != Vector2.INF:
		v = debug_input
	if autopilot != null:
		var cmd := autopilot.decide()
		v = cmd[0]
		gear_on = cmd[1]
	if not Controls.gear_toggle:
		gear_on = Input.is_action_pressed("gear")
	if not script_inputs.is_empty():
		var cmd: Dictionary = script_inputs.pop_front()
		v = cmd.v
		gear_on = cmd.g
	var gear_before := run.sim.gear_cmd
	v = Replay.quantize(v)
	if run.result == Run.Result.RUNNING:
		replay.add(v, gear_on)
	run.step(v, gear_on)
	if run.sim.gear_cmd != gear_before:
		Sfx.play("gear")
	Sfx.set_thrust(taxi.flame_main if run.result == Run.Result.RUNNING else 0.0, absf(taxi.flame_side))
	if run.sim.fuel < 25.0 and run.sim.fuel > 0.0 and int(run.sim.time * 120.0) % 120 == 0:
		Sfx.play("warn", -6.0)
	taxi.sync_state()
	if run.result == Run.Result.RUNNING:
		Haptics.thrust(taxi.flame_main + absf(taxi.flame_side) * 0.5)
		_check_near_miss()
		_music_tick()
		_hint_tick()
	for e in run.log:
		_on_event(e)
	cam.global_position = _cam_target()
	_cam_feel()
	if run.result == Run.Result.COMPLETE and not completion_saved:
		completion_saved = true
		Save.note_max("best_streak", run.best_streak)
		var prev_best := Save.best_time(Flow.current_level)
		var med := run.medals()
		hud.result = {"time": run.level_time, "target": run.time_target(), "best": prev_best, "medals": med, "money_target": run.money_target(), "earned": run.earned, "repair": run.repair_cost, "taxi_fees": run.taxi_fees, "missed_fees": run.missed_fees, "net": run.earned - run.repair_cost - run.taxi_fees - run.missed_fees, "delivered": run.delivered, "jobs": run.level.jobs.size(), "extras": run.extras_delivered, "balance": run.money}
		hud.result_age = 0.0
		hud.next_exists = Flow.next_level_id() != ""
		var score := run.level_score()
		hud.result["score"] = score
		hud.result["best_score"] = maxi(score, Save.best_score(Flow.current_level))
		Save.complete_level(Flow.current_level, run.level_time, run.money, run.earned, med, score)
		replay.finish({"complete": true, "time": run.level_time, "money": run.money, "earned": run.earned, "delivered": run.delivered})
		if not Save.dev_session:
			Replay.save_if_best(replay.to_dict())
		_check_unlocks()
		Sfx.set_thrust(0.0, 0.0)
		if Flow.next_level_id() == "":
			Save.clear_campaign()
		elif autopilot != null:
			_begin_transition()                  # Autopilot-Läufe (Dev) laufen ohne Bestätigung weiter
	if run.result == Run.Result.FAILED and not hud.game_over:
		restart_timer += Tuning.TICK
		if restart_timer > 1.2:
			_lose_life()

func _lose_life() -> void:
	## Taxi zerstört: ein Leben weniger; keins mehr = Game Over. Sonst läuft das Level weiter (nichts wird neu gestartet):
	## Der Fahrgast an Bord ist verloren und wartet erneut an seinem Abholpad, neues Taxi am Startpad.
	Flow.lives -= 1
	if Flow.lives <= 0:
		Flow.lives = 0
		hud.game_over = true
		Save.clear_campaign()
		return
	replay.mark_respawn()
	run.respawn_after_crash()
	run.lives = Flow.lives
	gear_on = run.sim.gear_cmd
	restart_timer = 0.0
	taxi.sync_state()
	taxi.reset_physics_interpolation()
	cam.global_position = _cam_target()
	cam.reset_physics_interpolation()
	for e in run.log:
		_on_event(e)

## Kamera-Gefühl: leichter Vorausblick in Flugrichtung, Wackeln bei Treffern. Bei „Weniger Bewegung“ aus.
func _cam_feel() -> void:
	if Settings.values.reduce_motion or trans_t >= 0.0:
		cam.offset = Vector2.ZERO
		return
	cam_off = cam_off.lerp((run.sim.vel * 0.03).limit_length(4.0), 0.06)
	shake = maxf(0.0, shake - 0.05)
	cam.offset = cam_off + Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * shake

## Musik-Schichten: B (Bewegung) mit Fahrgast an Bord/offenem Tor/Tempo, C (Spannung) bei wenig Sprit, Schaden, Beinahe-Treffer.
var _music_ticks := 0
func _music_tick() -> void:
	_music_ticks += 1
	if _music_ticks % 30 != 0:
		return
	var s := run.sim
	var drive := run.phase == Run.Phase.CARRYING or run.phase == Run.Phase.DROPOFF or run.exit_open or s.vel.length() > 70.0
	var danger := s.fuel < 25.0 or s.hull < 45.0 or near_cd > 3.0 or run.pump_boom_t >= 0.0
	Music.set_layers(drive, danger)

## Tutorial-Hinweise (einmalig je Profil, abschaltbar, laufen nach 7 s von selbst aus).
var _hint_ticks := 0
func _hint_tick() -> void:
	_hint_ticks += 1
	if _hint_ticks % 30 != 0 or not Settings.values.hints or paused or trans_t >= 0.0:
		return
	var s := run.sim
	var dev := Controls.last_device
	var kind := "kb" if dev == "keyboard" else "pad"
	if run.level.number <= 3 and run.level_time > 0.6 and Flow.current_level == "s1_01":
		_hint("start", tr("HINT_START") % Controls.thrust_label(dev))
	var near_pad := false
	for id in run.level.pads:
		var p: Dictionary = run.level.pads[id]
		if s.pos.x > p.x0 and s.pos.x < p.x1 and s.pos.y < p.row * Tuning.TILE and p.row * Tuning.TILE - s.pos.y < 60.0 and s.state == TaxiSim.State.FLYING:
			near_pad = true
	if near_pad and not s.gear_cmd:
		_hint("gear", tr("HINT_GEAR") % Controls.slot_label("gear", kind, 0))
	if near_pad and s.gear_extended():
		_hint("landing", tr("HINT_LANDING"))
	if run.phase == Run.Phase.CARRYING:
		_hint("passenger", tr("HINT_PASSENGER"))
	if run.level.pads.has("F") and s.fuel < 30.0:
		_hint("fuel", tr("HINT_FUEL"))
	if run.exit_open:
		_hint("exit", tr("HINT_EXIT"))

func _hint(key: String, text: String) -> void:
	var seen: Array = Save.data.get("seen_hints", [])
	if seen.has(key) or hud.hint_t > 0.0:
		return
	seen.append(key)
	Save.data["seen_hints"] = seen
	hud.hint_text = text
	hud.hint_t = 7.0

func _add_shake(amp: float) -> void:
	if not Settings.values.reduce_motion:
		shake = maxf(shake, amp)

## Beinahe-Treffer: schnell an einer Wand vorbei (≤ 4 px Abstand, kein Kontakt) löst eine kurze Zeitlupe aus.
func _check_near_miss() -> void:
	near_cd = maxf(0.0, near_cd - Tuning.TICK)
	var s := run.sim
	if near_cd > 0.0 or s.state != TaxiSim.State.FLYING or s.vel.length() < 110.0 or Settings.values.reduce_motion or trans_t >= 0.0:
		return
	var lv := run.level
	if lv.box_hits_solid(s.pos, Tuning.HULL_HALF + Vector2(4, 4)) and not lv.box_hits_solid(s.pos, Tuning.HULL_HALF):
		near_cd = 5.0
		slowmo_left = 0.5
		Engine.time_scale = 0.4
		AudioServer.playback_speed_scale = 0.85
		Sfx.play("near_miss", -2.0)
		Haptics.pulse(0.2, 0.2, 0.1)
		hud.flash_message(tr("MSG_NEAR_MISS"), 1.0)

## Neu freigeschaltete Lackierungen/Aufkleber melden (Toast + Ton).
func _check_unlocks() -> void:
	var lang := TranslationServer.get_locale().substr(0, 2)
	for it in Cosmetics.check_unlocks():
		hud.flash_message(tr("MSG_UNLOCK") % it.name.get(lang, it.id), 4.0)
		Sfx.play("exit", -4.0)

var voice_cd := 0.0
var attendant_cd := 0.0
## Fahrgast an Bord kommentiert die Landung: weich = „Wow, sanft!“, hart = „Aua!“ (höchstens alle 8 s).
func _passenger_reaction(e: Dictionary) -> void:
	if run.actor == null or run.phase != Run.Phase.CARRYING or Time.get_ticks_msec() / 1000.0 < voice_cd:
		return
	var key := ""
	if float(e.vy) <= Tuning.LAND_SOFT_VY and float(e.vx) <= Tuning.PERFECT_VX:
		key = "soft"
	elif float(e.vy) > 38.0:
		key = "hard"
	if key == "":
		return
	voice_cd = Time.get_ticks_msec() / 1000.0 + 8.0
	Sfx.play_voice(run.actor.voice_key(), key)
	hud.subtitle(run.actor.pname, Sfx.line_text("passenger_extra", key))

## Tankwart: schimpft bei Berührungen der Säule, kommentiert Preiswechsel (höchstens alle 14 s).
func _attendant(key: String, cooldown := 0.0) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if cooldown > 0.0:
		if now < attendant_cd:
			return
		attendant_cd = now + cooldown
	Sfx.play_voice("t0", key)
	hud.subtitle(tr("SPK_ATTENDANT"), Sfx.line_text("t0", key), 2.4)

func _end_slowmo() -> void:
	slowmo_left = 0.0
	Engine.time_scale = 1.0
	AudioServer.playback_speed_scale = 1.0

func _exit_tree() -> void:
	_end_slowmo()
	Haptics.stop()

func _on_event(e: Dictionary) -> void:
	match e.type:
		"perfect":
			hud.flash_message(tr("MSG_PERFECT") % e.streak, 1.4)
			Sfx.play("perfect", -4.0)
			Haptics.pulse(0.1, 0.25, 0.1)
			Save.count_event("perfect_landings")
			Save.note_max("best_streak", int(e.streak))
			_check_unlocks()
		"streak_lost":
			hud.flash_message(tr("MSG_STREAK_LOST"), 1.2)
		"landed":
			_passenger_reaction(e)
			Sfx.play("land", -4.0)
			taxi.burst_puff(0.6)
			Haptics.pulse(0.15, clampf(float(e.vy) / 48.0, 0.0, 1.0) * 0.8, 0.12)
			if float(e.vy) > 35.0:
				_add_shake(1.2)
		"liftoff": taxi.burst_puff(1.0)
		"call":
			Sfx.play_voice(e.voice, "call")
			hud.subtitle(e.name, tr("VOICE_CALL"))
		"boarded":
			Sfx.play("board", -6.0)
			Sfx.play_voice(e.voice, "dest_" + e.dest)
			hud.subtitle(e.name, tr("VOICE_EXIT") if e.dest == "exit" else tr("VOICE_DEST") % e.dest, 2.8)
		"delivered":
			var msg := tr("MSG_DELIVERED2") % [int(e.pay), e.factor]
			if int(e.get("combo", 0)) > 0:
				msg += "  ★%d" % int(e.combo)
			Save.count_event("deliveries")
			_check_unlocks()
			if e.penalty > 0.005:
				msg += "  " + tr("MSG_HARD") % int(round(e.penalty * 100.0))
			hud.flash_message(msg, 3.0)
			Sfx.play("coin")
			Sfx.play_voice(e.voice, "thanks")
			hud.subtitle(e.name, tr("VOICE_THANKS"), 1.8)
		"squashed":
			Haptics.pulse(0.3, 0.1, 0.15)
			Save.count_event("squashes")
			Sfx.play_voice(e.voice, "angry")
			hud.subtitle(e.name, tr("VOICE_ANGRY"), 2.0)
			Sfx.play("hit", -8.0)
		"wrong_pad":
			hud.flash_message(tr("MSG_WRONG_PAD") % e.pct, 2.4)
			Sfx.play_voice(e.voice, "wrong_pad")
			hud.subtitle(e.name, tr("VOICE_WRONG_PAD"), 2.2)
		"ride_damage":
			hud.flash_message(tr("MSG_RIDE_DAMAGE") % e.pct, 2.2)
			if Time.get_ticks_msec() / 1000.0 >= voice_cd:
				voice_cd = Time.get_ticks_msec() / 1000.0 + 2.5
				Sfx.play_voice(e.voice, "bumpy")
				hud.subtitle(e.name, tr("VOICE_BUMPY"), 2.0)
		"job_missed":
			hud.flash_message(tr("MSG_JOB_MISSED") % [e.name, int(e.fee)], 3.0)
		"life_bought":
			Flow.lives = int(e.lives)
			hud.flash_message(tr("MSG_LIFE_BOUGHT") % [int(e.lives), int(e.price)], 3.0)
			Sfx.play("coin")
			Haptics.pulse(0.3, 0.4, 0.2)
		"life_denied":
			hud.flash_message(tr("MSG_LIFE_FULL") if e.full else tr("MSG_LIFE_POOR") % int(e.price), 2.6)
		"out_of_fuel":
			hud.flash_message(tr("MSG_OUT_OF_FUEL"), 2.5)
			Haptics.pulse(0.5, 0.5, 0.3)
		"extra_appeared":
			hud.flash_message(tr("MSG_EXTRA_NEW") % [e.name, e.pad], 2.6)
			Sfx.play("board", -10.0)
		"extra_left":
			hud.flash_message(tr("MSG_EXTRA_LEFT") % e.name, 2.6)
			if not Sfx.play_voice(e.voice, "bored"):
				Sfx.play_voice(e.voice, "angry")
			hud.subtitle(e.name, tr("VOICE_BORED"), 2.2)
		"cost":
			if e.what == "taxi":
				hud.flash_message(tr("MSG_TAXI_FEE") % int(e.amount), 2.5)
		"price_changed":
			if run.sim.fuel < 70.0:
				_attendant("price_up" if e.up else "price_down", 14.0)
			Sfx.play("price_tick", -6.0)
			props.pump_flash = 1.0
			hud.price_flash = 1.0
			hud.flash_message(tr("MSG_PRICE") % e.price, 2.0)
		"pump_touched":
			_attendant("pump_hit_%d" % clampi(int(e.stage), 1, 3))
			Haptics.pulse(0.6, 0.6, 0.25)
			_add_shake(1.5)
			Save.count_event("pump_hits")
			Sfx.play("pump_hit")
			taxi.burst_sparks()
			hud.flash_message(tr("MSG_PUMP_HIT") % [e.stage, e.price], 2.8)
		"pump_exploded":
			Haptics.pulse(1.0, 1.0, 0.7)
			_add_shake(5.0)
			Save.count_event("pump_explosions")
			_check_unlocks()
			Sfx.play("pump_boom")
			fx.pump_explode(e.rect)
			hud.flash_message(tr("MSG_PUMP_BOOM"), 3.5)
		"pump_out":
			hud.flash_message(tr("MSG_PUMP_OUT"), 2.5)
		"passenger_lost":
			hud.flash_message(tr("MSG_LOST") % [e.name, e.pad], 3.5)
		"replacement":
			hud.flash_message(tr("MSG_SQUASH") % e.pad, 3.0)
		"carried_thanks":
			Sfx.play_voice(e.voice, "thanks")
			hud.subtitle(e.name, tr("VOICE_THANKS"), 1.8)
		"exit_open":
			hud.flash_message(tr("MSG_EXIT_OPEN"))
			Sfx.play("exit")
		"damage":
			Haptics.pulse(0.6, 0.9, 0.2)
			_add_shake(clampf(float(e.amount) / 25.0, 0.6, 4.0))
			taxi.flash = 1.0
			taxi.burst_sparks()
			Sfx.play("hit")
		"destroyed":
			Sfx.play("crash")
			Save.count_event("crashes")
			Haptics.pulse(1.0, 1.0, 0.6)
			_add_shake(5.0)
		"bad_landing":
			match e.reason:
				"gear": hud.flash_message(tr("MSG_BAD_GEAR"))
				"pos": hud.flash_message(tr("MSG_BAD_POS"))
				"speed": hud.flash_message(tr("MSG_BAD_SPEED"))
				"tilt": hud.flash_message(tr("MSG_BAD_TILT"))

# ---------------------------------------------------------------- Levelwechsel
func _process(delta: float) -> void:
	if run.result == Run.Result.RUNNING and not paused and trans_t < 0.0:
		Save.add_playtime(delta / maxf(Engine.time_scale, 0.05))
	if slowmo_left > 0.0:
		slowmo_left -= delta / maxf(Engine.time_scale, 0.05)
		if slowmo_left <= 0.0:
			_end_slowmo()
	if trans_t < 0.0:
		return
	trans_t += delta
	trans.t = trans_t
	if not radio_played and trans_t >= 2.15 and trans_t < TV.T_IN:
		radio_played = true
		_play_radio()
	if not arriving and trans_t >= TV.T_IN:
		_begin_arrival()
	if trans_t >= TV.T_END:
		trans_t = TV.T_END
		_arrival_tick()          # Aufsetzen abschließen (Staub, Geräusch, Ruf, Aussteigen), bevor die Sequenz endet
		_end_transition()

var radio_played := false

## Funkspruch der Zentrale während der Weltraumfahrt: Sektor-Intro beim ersten Level eines Sektors, sonst eine
## allgemeine Zeile (reproduzierbar aus der Levelnummer).
func _play_radio() -> void:
	var nl := LevelData.load_file(Flow.level_path(next_id))
	var key := "intro_%d" % clampi(nl.sector, 1, 9) if nl.index == 1 else "g%d" % ((nl.number * 7) % 10 + 1)
	var txt := Sfx.line_text("d0", key)
	if txt == "":
		return
	Sfx.play_voice("d0", key)
	var length := Sfx.voice_player.stream.get_length() if Sfx.voice_player.stream != null else 3.0
	trans.radio_speaker = tr("SPK_DISPATCH")
	trans.radio_text = txt
	trans.radio_t0 = trans_t
	trans.radio_len = length
	hud.subtitle(tr("SPK_DISPATCH"), txt, length + 0.6)        # läuft unter dem Overlay weiter und erscheint beim Einblenden

func _begin_transition() -> void:
	next_id = Flow.next_level_id()
	Flow.entry_fuel = maxf(Tuning.MIN_START_FUEL, run.sim.fuel)     # Sprit und Credits laufen mit
	Flow.entry_credits = run.money
	Flow.carry_passenger = run.carried
	Save.set_campaign({"level": next_id, "lives": Flow.lives, "fuel": Flow.entry_fuel, "credits": Flow.entry_credits, "seed": Flow.run_seed, "carry": run.carried})
	if OS.get_cmdline_user_args().has("--debug-carry") and Flow.carry_passenger.is_empty():     # Dev: Ausgangs-Fahrgast simulieren
		Flow.carry_passenger = {"name": "Odo", "look": 2, "gender": "m"}
	var nl := LevelData.load_file(Flow.level_path(next_id))
	var lang := TranslationServer.get_locale().substr(0, 2)
	trans.title_sector = tr("TRANS_SECTOR") % [nl.sector, tr("SECTOR_%d" % nl.sector)]
	trans.title_level = tr("TRANS_LEVEL") % [(nl.sector - 1) * 11 + nl.index, nl.names.get(lang, nl.id)]
	trans.info = tr("TRANS_FARES") % int(run.money)
	trans.skip_hint = tr("TRANS_SKIP")
	arriving = false
	trans_t = 0.0
	radio_played = false
	Music.duck(-13.0)
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--trans-t="):      # Dev: Zeitachse an beliebiger Stelle starten (Screenshots)
			trans_t = float(a.substr(10))
	trans.t = trans_t
	Sfx.set_thrust(0.0, 0.0)
	Sfx.play_long("transit")

func _begin_arrival() -> void:
	## Neues Level laden; das Taxi tritt durch das (kurz öffnende) Tor in der Decke aus, fliegt eine
	## S-Kurve und landet auf der Startplattform.
	arriving = true
	arrive_done = false
	Flow.current_level = next_id
	level_path = Flow.level_path(next_id)
	load_level(level_path)
	run.level.doors_forced_open = true      # beim Einflug stehen bewegliche Tore offen
	arrive_end = run.sim.pos
	arrive_path = Pathing.arrival_path(run.level, arrive_end)
	arrive_start = arrive_path[0]
	arrive_prev = arrive_start
	_arrival_tick()
	taxi.reset_physics_interpolation()

func _arrival_tick() -> void:
	if not arriving or arrive_done:
		return
	var s := run.sim
	var u := clampf((trans_t - TV.T_IN) / (TV.T_END - TV.T_IN), 0.0, 1.0)
	if u >= 1.0:
		s.pos = arrive_end
		s.gear = 1.0
		s.tilt = 0.0
		s.thrust_in = Vector2.ZERO
		props.door_override = -1.0
		props.door = 1.0 if run.exit_open else 0.0
		taxi.sync_state()
		taxi.burst_puff(1.0)
		Sfx.play("land", -4.0)
		Sfx.set_thrust(0.0, 0.0)
		arrive_done = true
		_release_carried()
		if run.actor != null and run.actor.state == PassengerActor.S.WAITING:
			run.actor.wave()
			_on_event({"type": "call", "voice": run.actor.voice_key(), "name": run.actor.pname})
		return
	var e := TV.smooth(u * 1.04)
	var pos := Pathing.sample_path(arrive_path, e)
	var vel := (pos - arrive_prev) / Tuning.TICK
	arrive_prev = pos
	s.pos = pos
	s.gear = TV.smooth((u - 0.5) / 0.3)
	s.tilt = clampf(vel.x / 170.0, -0.24, 0.24) * (1.0 - TV.smooth((u - 0.8) / 0.2))
	s.thrust_in = Vector2(clampf(vel.x / 90.0, -1.0, 1.0) * 0.8 * (1.0 - TV.smooth((u - 0.55) / 0.3)), -(0.3 + 0.5 * (1.0 - TV.smooth((u - 0.75) / 0.25))))
	# Tor öffnet sich zum Austritt und schließt sich danach wieder
	props.door_override = TV.smooth(u / 0.25) * (1.0 - TV.smooth((u - 0.5) / 0.3))
	taxi.sync_state()
	Sfx.set_thrust(taxi.flame_main * 0.7, absf(taxi.flame_side))

func _release_carried() -> void:
	var c: Dictionary = Flow.carry_passenger
	Flow.carry_passenger = {}
	run.release_carried(c)

func _end_transition() -> void:
	run.level.doors_forced_open = false
	Music.duck(0.0)
	props.door_override = -1.0
	trans_t = -1.0
	trans.t = -1.0
	arriving = false
	Sfx.set_thrust(0.0, 0.0)
	taxi.reset_physics_interpolation()
