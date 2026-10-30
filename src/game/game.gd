extends Node2D
## Spielszene: verbindet Eingabe, Run-Logik, Darstellung, Kamera und HUD.
## Aufruf mit Level: godot --path . -- --level=s1_01  (Screenshot: --shot=pfad.png --frames=N)

var level_path := ""
var run := Run.new()
var paused := false
var gear_on := false
var restart_timer := 0.0
var completion_saved := false

@onready var world: Node2D = $World
@onready var taxi: Node2D = $World/Taxi
@onready var cam: Camera2D = $Camera
@onready var hud: Control = $Hud/Root
@onready var bg: Control = $Backdrop/Bg
@onready var world_tiles: Node2D = $World/Tiles
var script_inputs: Array = []

func _ready() -> void:
	if Flow.current_level == "":
		Flow.current_level = "s1_01"
	level_path = Flow.level_path(Flow.current_level)
	load_level(level_path)

func load_level(path: String) -> void:
	var lvl := LevelData.load_file(path)
	if lvl == null:
		push_error("Level konnte nicht geladen werden: " + path)
		return
	run.start(lvl)
	gear_on = run.sim.gear_cmd
	world_tiles.setup(run)
	taxi.bind(run.sim)
	taxi.sync_state()
	taxi.reset_physics_interpolation()
	hud.bind(run)
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
	if event.is_action_pressed("pause"):
		if run.result == Run.Result.RUNNING:
			_set_paused(not paused)
		else:
			Flow.to_menu()
		get_viewport().set_input_as_handled()
	elif paused:
		return
	elif event.is_action_pressed("ui_accept") and run.result == Run.Result.COMPLETE:
		var nxt := Flow.next_level_id()
		if nxt != "":
			Flow.start_level(nxt)
		else:
			Flow.to_menu()
	elif event.is_action_pressed("restart"):
		load_level(level_path)
	elif event.is_action_pressed("gear") and not paused and Controls.gear_toggle:
		gear_on = not gear_on

func _physics_process(_delta: float) -> void:
	if paused:
		return
	var v := Controls.thrust_vector()
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
	if run.result == Run.Result.FAILED:
		restart_timer += Tuning.TICK
		if restart_timer > 1.2:
			load_level(level_path)

func _on_event(e: Dictionary) -> void:
	match e.type:
		"landed": Sfx.play("land", -4.0)
		"boarded":
			hud.flash_message(tr("MSG_BOARDED"))
			Sfx.play("board")
		"delivered":
			hud.flash_message(tr("MSG_DELIVERED") % int(e.fare + e.tip))
			Sfx.play("coin")
		"exit_open":
			hud.flash_message(tr("MSG_EXIT_OPEN"))
			Sfx.play("exit")
		"damage":
			taxi.flash = 1.0
			Sfx.play("hit")
		"destroyed": Sfx.play("crash")
		"bad_landing":
			match e.reason:
				"gear": hud.flash_message(tr("MSG_BAD_GEAR"))
				"pos": hud.flash_message(tr("MSG_BAD_POS"))
				"speed": hud.flash_message(tr("MSG_BAD_SPEED"))
				"tilt": hud.flash_message(tr("MSG_BAD_TILT"))
