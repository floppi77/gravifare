extends Node2D
## Spielszene: verbindet Eingabe, Run-Logik, Darstellung, Kamera und HUD.
## Aufruf mit Level: godot --path . -- --level=s1_01  (Screenshot: --shot=pfad.png --frames=N)

var level_path := ""
var run := Run.new()
var paused := false
var gear_on := false
var restart_timer := 0.0
var completion_saved := false
const TV := preload("res://src/game/transition_view.gd")
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
	load_level(level_path)
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--debug-input="):
			var xy := a.substr(14).split(",")
			debug_input = Vector2(float(xy[0]), float(xy[1]))
			gear_on = false
			run.sim.state = TaxiSim.State.FLYING
			run.sim.landed_pad = {}
	if OS.get_cmdline_user_args().has("--autopilot"):
		autopilot = Bot.new(run)
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

func load_level(path: String) -> void:
	var lvl := LevelData.load_file(path)
	if lvl == null:
		push_error("Level konnte nicht geladen werden: " + path)
		return
	run.start(lvl, Flow.entry_fuel, Flow.entry_credits)
	gear_on = run.sim.gear_cmd
	world_tiles.setup(run)
	props.setup(run)
	fx.setup(run)
	taxi.bind(run.sim)
	taxi.sync_state()
	taxi.reset_physics_interpolation()
	hud.bind(run)
	if autopilot != null:
		autopilot = Bot.new(run)
	hud.paused = false
	paused = false
	restart_timer = 0.0
	completion_saved = false
	_setup_camera()
	bg.setup(lvl)

func _setup_camera() -> void:
	var sz := run.level.pixel_size()
	cam.limit_left = 0
	cam.limit_top = 0
	cam.limit_right = int(sz.x)
	cam.limit_bottom = int(sz.y)
	cam.position_smoothing_enabled = false
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
	Sfx.set_thrust(0.0, 0.0)
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
	elif event.is_action_pressed("ui_accept") and run.result == Run.Result.COMPLETE:
		Flow.to_menu()          # nur das letzte Level erreicht diesen Pfad; sonst übernimmt die Levelwechsel-Sequenz
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
	run.step(v, gear_on)
	if run.sim.gear_cmd != gear_before:
		Sfx.play("gear")
	Sfx.set_thrust(taxi.flame_main if run.result == Run.Result.RUNNING else 0.0, absf(taxi.flame_side))
	if run.sim.fuel < 25.0 and run.sim.fuel > 0.0 and int(run.sim.time * 120.0) % 120 == 0:
		Sfx.play("warn", -6.0)
	taxi.sync_state()
	for e in run.log:
		_on_event(e)
	cam.global_position = _cam_target()
	if run.result == Run.Result.COMPLETE and not completion_saved:
		completion_saved = true
		Save.complete_level(Flow.current_level, run.sim.time, run.money)
		Sfx.set_thrust(0.0, 0.0)
		if Flow.next_level_id() != "":
			_begin_transition()
	if run.result == Run.Result.FAILED and not hud.game_over:
		restart_timer += Tuning.TICK
		if restart_timer > 1.2:
			_lose_life()

func _lose_life() -> void:
	## Taxi zerstört: ein Leben weniger; keins mehr = Game Over, sonst Level neu mit dem Sprit/den Credits von Levelbeginn.
	Flow.lives -= 1
	if Flow.lives <= 0:
		Flow.lives = 0
		hud.game_over = true
		return
	load_level(level_path)

func _on_event(e: Dictionary) -> void:
	match e.type:
		"landed":
			Sfx.play("land", -4.0)
			taxi.burst_puff(0.6)
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
			if e.penalty > 0.005:
				msg += "  " + tr("MSG_HARD") % int(round(e.penalty * 100.0))
			hud.flash_message(msg, 3.0)
			Sfx.play("coin")
			Sfx.play_voice(e.voice, "thanks")
			hud.subtitle(e.name, tr("VOICE_THANKS"), 1.8)
		"carried_thanks":
			Sfx.play_voice(e.voice, "thanks")
			hud.subtitle(e.name, tr("VOICE_THANKS"), 1.8)
		"exit_open":
			hud.flash_message(tr("MSG_EXIT_OPEN"))
			Sfx.play("exit")
		"damage":
			taxi.flash = 1.0
			taxi.burst_sparks()
			Sfx.play("hit")
		"destroyed": Sfx.play("crash")
		"bad_landing":
			match e.reason:
				"gear": hud.flash_message(tr("MSG_BAD_GEAR"))
				"pos": hud.flash_message(tr("MSG_BAD_POS"))
				"speed": hud.flash_message(tr("MSG_BAD_SPEED"))
				"tilt": hud.flash_message(tr("MSG_BAD_TILT"))

# ---------------------------------------------------------------- Levelwechsel
func _process(delta: float) -> void:
	if trans_t < 0.0:
		return
	trans_t += delta
	trans.t = trans_t
	if not arriving and trans_t >= TV.T_IN:
		_begin_arrival()
	if trans_t >= TV.T_END:
		_end_transition()

func _begin_transition() -> void:
	next_id = Flow.next_level_id()
	Flow.entry_fuel = maxf(Tuning.MIN_START_FUEL, run.sim.fuel)     # Sprit und Credits laufen mit
	Flow.entry_credits = run.money
	Flow.carry_passenger = run.carried
	var nl := LevelData.load_file(Flow.level_path(next_id))
	var lang := TranslationServer.get_locale().substr(0, 2)
	trans.title_sector = tr("TRANS_SECTOR") % [nl.sector, tr("SECTOR_%d" % nl.sector)]
	trans.title_level = tr("TRANS_LEVEL") % [(nl.sector - 1) * 11 + nl.index, nl.names.get(lang, nl.id)]
	trans.info = tr("TRANS_FARES") % int(run.money)
	trans.skip_hint = tr("TRANS_SKIP")
	arriving = false
	trans_t = 0.0
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
	arrive_end = run.sim.pos
	arrive_start = run.level.exit_rect().get_center() + Vector2(0, 4)
	arrive_prev = arrive_start
	_arrival_tick()
	taxi.reset_physics_interpolation()

static func _bezier(p0: Vector2, c1: Vector2, c2: Vector2, p3: Vector2, e: float) -> Vector2:
	var q := 1.0 - e
	return p0 * (q * q * q) + c1 * (3.0 * q * q * e) + c2 * (3.0 * q * e * e) + p3 * (e * e * e)

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
	var c1 := arrive_start + Vector2(0, 95)
	var c2 := arrive_end + Vector2(0, -75)
	var pos := _bezier(arrive_start, c1, c2, arrive_end, e)
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
	## Der Ausgangs-Fahrgast des letzten Levels steigt auf der Startplattform aus und geht in den Unterstand.
	var c: Dictionary = Flow.carry_passenger
	Flow.carry_passenger = {}
	if c.is_empty() or run.sim.landed_pad.is_empty():
		return
	var a := PassengerActor.new()
	a.setup({"passenger": c.name, "gender": c.gender, "look": c.look}, run.sim.landed_pad, 0, true)
	a.step_out(run.sim.pos.x, run.sim.landed_pad)
	run.leavers.append(a)
	_on_event({"type": "carried_thanks", "voice": a.voice_key(), "name": a.pname})

func _end_transition() -> void:
	props.door_override = -1.0
	trans_t = -1.0
	trans.t = -1.0
	arriving = false
	Sfx.set_thrust(0.0, 0.0)
	taxi.reset_physics_interpolation()
