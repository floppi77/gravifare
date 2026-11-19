extends Node2D
## Aufnahmekopie (an die Wurzel kopieren, wie ws_trailer): Taxi mit Mütze, Sonnenbrille und Kaffeetasse fliegt hin und her durch alle Drehstufen.
## --showcase=valentine: Herz-Duftbaum und Erröten statt Mütze.

const Calendar := preload("res://src/core/calendar.gd")
var run: Run
var taxi: Node2D
var cam: Camera2D
var t := 0.0
var mode := "xmas"

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--showcase="):
			mode = a.substr(11)
	Calendar.force_hat = "xmas" if mode == "xmas" else "none"
	Calendar.force_valentine = 1 if mode == "valentine" else 0
	run = Run.new()
	run.start(LevelData.load_file("res://data/levels/s5_01.json"), -1.0, 0.0, 1)       # Sektor 5: Sonnenbrille
	run.sim.state = TaxiSim.State.FLYING
	run.sim.pos = Vector2.ZERO
	var bg := ColorRect.new()
	bg.color = Color("#0d1030")
	bg.position = Vector2(-2000, -2000)
	bg.size = Vector2(4000, 4000)
	add_child(bg)
	taxi = Node2D.new()
	taxi.set_script(load("res://src/game/taxi_view.gd"))
	add_child(taxi)
	taxi.bind(run.sim)
	taxi.light.enabled = false                     # ohne die Spielbeleuchtung würde das Licht alles überstrahlen
	for c in taxi.get_children():
		if c is CPUParticles2D:
			c.visible = false
	cam = Camera2D.new()
	cam.zoom = Vector2(5, 5)
	add_child(cam)
	cam.make_current()

func _physics_process(delta: float) -> void:
	t += delta
	var w := 1.7
	var amp := 44.0
	var s := run.sim
	s.pos = Vector2(amp * sin(w * t), 3.0 * sin(t * 2.3))
	s.vel = Vector2(amp * w * cos(w * t), 0.0)
	s.tilt = clampf(-amp * w * w * sin(w * t) / 900.0, -0.35, 0.35)              # neigt sich in die Beschleunigung
	s.thrust_in = Vector2(clampf(-sin(w * t) * 1.2, -1.0, 1.0), -0.55)
	taxi.sync_state()
	if mode == "valentine" and (fmod(t, 3.0) < delta or t < delta * 1.5):
		taxi.blush()

func _draw() -> void:
	pass
