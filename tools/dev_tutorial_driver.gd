extends Node
## Dev-Treiber (nur für Tests über den Editor/MCP): spielt das Tutorial im laufenden Spiel durch, indem er das Taxi versetzt und
## Sprache überspringt. Aufruf in der laufenden Instanz:  add_child(load("res://tools/dev_tutorial_driver.gd").new())
## Zustand lesbar über `log` (Schritte) und `done`.
var log: Array = []
var done := false
var last := ""
var g: Node
var cool := 0.0
var placed := {}

func _ready() -> void:
	g = get_tree().current_scene

func _land(id: String) -> void:
	var s = g.run.sim
	var p = g.run.level.pads[id]
	s.pos = Vector2(float(p.x1) - 14.0, float(p.row) * 16.0 - 8.0)
	s.vel = Vector2.ZERO
	s.gear = 1.0
	s.state = TaxiSim.State.LANDED
	s.landed_pad = p

func _process(delta: float) -> void:
	if done or g == null or g.tutorial == null:
		return
	cool -= delta
	var t = g.tutorial
	var s = g.run.sim
	if t.idx >= t.steps.size():
		if g.run.result == Run.Result.RUNNING and g.run.exit_open:
			s.pos = g.run.level.exit_rect().get_center()
			s.state = TaxiSim.State.FLYING
			s.landed_pad = {}
		return
	var key := String(t.steps[t.idx].key)
	t.speak_len = 0.0
	if key != last:
		var line := "%s (t=%.1f) lives=%d money=%.0f fuel=%.0f job=%d delivered=%d extras=%d" % [key, Time.get_ticks_msec() / 1000.0, Flow.lives, g.run.money, s.fuel, g.run.job_index, g.run.delivered, g.run.extras.size()]
		log.append(line)
		last = key
		var f := FileAccess.open("/tmp/claude-1000/dev_driver.log", FileAccess.READ_WRITE) if FileAccess.file_exists("/tmp/claude-1000/dev_driver.log") else FileAccess.open("/tmp/claude-1000/dev_driver.log", FileAccess.WRITE)
		f.seek_end()
		f.store_line(line)
		f.close()
	if cool > 0.0:
		return
	match key:
		"tut_gear_in":
			g.gear_on = false
		"tut_fly":
			if t.gates != null and t.gates.active and t.gates.next < t.gates.points.size():
				s.state = TaxiSim.State.FLYING
				s.landed_pad = {}
				s.pos = t.gates.points[t.gates.next]
				s.vel = Vector2.ZERO
				cool = 0.2
		"tut_gear":
			g.gear_on = true
		"tut_fuel_low", "tut_refuel", "tut_credit":
			if not (s.state == TaxiSim.State.LANDED and String(s.landed_pad.get("id", "")) == "F"):
				_land("F")
		"tut_hard":
			if s.state != TaxiSim.State.DESTROYED and g.run.result == Run.Result.RUNNING:
				s.state = TaxiSim.State.FLYING                    # echter Absturz: schneller Sturz auf den Boden (erzeugt das Ereignis „destroyed“)
				s.landed_pad = {}
				s.gear = 0.0
				s.pos = Vector2(330.0, 230.0)
				s.vel = Vector2(0.0, 230.0)
				cool = 4.0
		"tut_soft":
			if not placed.has(key):
				placed[key] = true
				s.state = TaxiSim.State.FLYING
				s.landed_pad = {}
				s.pos = Vector2(float(g.run.level.pads["3"].center), float(g.run.level.pads["3"].row) * 16.0 - 14.0)
				s.vel = Vector2(0, 6.0)
				s.gear = 1.0
				g.gear_on = true
		"tut_job", "tut_extra", "tut_extra2":
			var from_id := "2" if key != "tut_extra2" else "3"
			if key == "tut_job":
				from_id = "2"
			if not (s.state == TaxiSim.State.LANDED and String(s.landed_pad.get("id", "")) == from_id):
				_land(from_id)
		"tut_pay":
			if not (s.state == TaxiSim.State.LANDED and String(s.landed_pad.get("id", "")) == "3"):
				_land("3")
		"tut_extra_dest":
			if not (s.state == TaxiSim.State.LANDED and String(s.landed_pad.get("id", "")) == "1"):
				_land("1")
		"tut_eject":
			g.run.eject()
			cool = 1.0
		"tut_life":
			if not (s.state == TaxiSim.State.LANDED and String(s.landed_pad.get("id", "")) == "L"):
				_land("L")
		"tut_exit":
			if g.run.actor != null and not (s.state == TaxiSim.State.LANDED and String(s.landed_pad.get("id", "")) == "1"):
				_land("1")
