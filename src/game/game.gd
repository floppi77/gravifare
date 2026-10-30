extends Node2D
## Spielszene: verbindet Eingabe, Run-Logik, Darstellung, Kamera und HUD.
## Aufruf mit Level: godot --path . -- --level=s1_01  (Screenshot: --shot=pfad.png --frames=N)

var level_path := "res://data/levels/s1_01.json"
var run := Run.new()
var paused := false
var gear_on := false
var restart_timer := 0.0

@onready var world: Node2D = $World
@onready var taxi: Node2D = $World/Taxi
@onready var cam: Camera2D = $Camera
@onready var hud: Control = $Hud/Root
@onready var bg: Control = $Backdrop/Bg
@onready var world_tiles: Node2D = $World/Tiles
var shot_path := ""
var shot_frames := 0
var script_inputs: Array = []

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--level="):
			level_path = "res://data/levels/%s.json" % a.substr(8)
		elif a.begins_with("--shot="):
			shot_path = a.substr(7)
		elif a.begins_with("--frames="):
			shot_frames = int(a.substr(9))
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

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") and run.result == Run.Result.RUNNING:
		paused = not paused
		hud.paused = paused
		get_tree().root.set_input_as_handled()
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
	run.step(v, gear_on)
	taxi.sync_state()
	for e in run.log:
		_on_event(e)
	cam.global_position = _cam_target()
	if run.result == Run.Result.FAILED:
		restart_timer += Tuning.TICK
		if restart_timer > 1.2:
			load_level(level_path)

func _on_event(e: Dictionary) -> void:
	match e.type:
		"boarded": hud.flash_message(tr("MSG_BOARDED"))
		"delivered": hud.flash_message(tr("MSG_DELIVERED") % int(e.fare + e.tip))
		"exit_open": hud.flash_message(tr("MSG_EXIT_OPEN"))
		"damage": taxi.flash = 1.0
		"bad_landing":
			match e.reason:
				"gear": hud.flash_message(tr("MSG_BAD_GEAR"))
				"pos": hud.flash_message(tr("MSG_BAD_POS"))
				"speed": hud.flash_message(tr("MSG_BAD_SPEED"))
				"tilt": hud.flash_message(tr("MSG_BAD_TILT"))

var _frame := 0
func _process(_delta: float) -> void:
	_frame += 1
	if shot_path != "" and _frame == shot_frames:
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(shot_path)
		get_tree().quit()
