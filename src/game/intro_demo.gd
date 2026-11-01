class_name IntroDemo
extends RefCounted
## Simulation eines Einspielers (siehe intro_clip.gd): ein kleines Demo-Level (data/intros/<name>.json) mit echter Spielphysik,
## das Taxi wird nach einem Drehbuch gesteuert. Keine Autoloads und keine Darstellung, damit es auch in Tests läuft.
##
## Drehbuch ("demo"."script"): Liste von {t, mode, p, y, speed, gear}; der letzte Eintrag mit t <= Zeit gilt.
##   hover p   – Position halten             go p [speed]  – zu p fliegen (Zonenkräfte werden nicht ausgeglichen)
##   level y   – nur Höhe halten, seitlich Schubfrei (Strömung/Magnet wirken sichtbar)
##   coast     – nur Schwebeschub gegen die Schwerkraft, sonst nichts (Zonen wirken ungehindert)
##   bot       – der Autopilot fliegt die Aufträge des Demo-Levels

var key := ""
var data: Dictionary = {}          # kompletter "demo"-Block
var level: LevelData
var run: Run
var bot: Bot = null
var t := 0.0
var length := 8.0
var actions: Array = []
var _acc := 0.0

static func path_of(k: String) -> String:
	return "res://data/intros/%s.json" % k

func setup(k: String) -> bool:
	key = k
	var f := FileAccess.open(path_of(k), FileAccess.READ)
	if f == null:
		return false
	var d = JSON.parse_string(f.get_as_text())
	if typeof(d) != TYPE_DICTIONARY:
		return false
	data = d.get("demo", {})
	level = LevelData.from_dict(d)
	run = Run.new()
	run.extras_enabled = false
	run.start(level, 100.0, 0.0, 1)
	length = float(data.get("length", 8.0))
	actions = data.get("script", [])
	if data.has("start"):
		var s: Array = data.start
		run.sim.pos = Vector2(float(s[0]), float(s[1]))
		run.sim.state = TaxiSim.State.FLYING
		run.sim.landed_pad = {}
		run.sim.vel = Vector2.ZERO
		run.sim.gear = 0.0
		run.sim.gear_cmd = false
	if _uses_bot():
		bot = Bot.new(run)
	return true

func _uses_bot() -> bool:
	for st in actions:
		if String(st.get("mode", "")) == "bot":
			return true
	return false

func step(dt: float) -> void:
	_acc += dt
	while _acc >= Tuning.TICK:
		_acc -= Tuning.TICK
		var cmd := _pilot()
		run.step(cmd[0], cmd[1])
		t += Tuning.TICK

func _current() -> Dictionary:
	var cur := {"mode": "coast"}
	for st in actions:
		if float(st.get("t", 0.0)) <= t:
			cur = st
	return cur

func _pilot() -> Array:
	var s := run.sim
	var st := _current()
	var gear: bool = bool(st.get("gear", false))
	var mode := String(st.get("mode", "coast"))
	if mode == "bot" and bot != null:
		return bot.decide()
	var p := Vector2.ZERO
	if st.has("p"):
		p = Vector2(float(st.p[0]), float(st.p[1]))
	var a_des := Vector2.ZERO
	match mode:
		"hover":
			a_des = (((p - s.pos) * 2.0).limit_length(70.0) - s.vel) / 0.30 + s.vel * s.drag()
		"go":
			a_des = (((p - s.pos) * 1.8).limit_length(float(st.get("speed", 70.0))) - s.vel) / 0.30 + s.vel * s.drag()
		"level":
			var vy := clampf((float(st.get("y", s.pos.y)) - s.pos.y) * 2.0, -60.0, 60.0)
			a_des = Vector2(0.0, (vy - s.vel.y) / 0.30 + s.vel.y * s.drag())
		"land":
			var pad: Dictionary = level.pads[String(st.get("pad", "1"))]
			var pv := float(pad.get("dx_step", 0.0)) / Tuning.TICK          # Tempo der (fahrenden) Plattform
			var dx := float(pad.center) - s.pos.x
			var foot := float(pad.row) * float(Tuning.TILE)
			var v_des := Vector2(clampf(dx * 3.0, -60.0, 60.0) + pv, 0.0)
			if s.state == TaxiSim.State.LANDED:
				v_des = Vector2(pv, 0.0)
			elif absf(dx) < 9.0 and s.pos.y < foot - 6.0:
				v_des.y = clampf((foot - 9.0 - s.pos.y) * 1.5, 12.0, 26.0)
			else:
				v_des.y = clampf((foot - 55.0 - s.pos.y) * 2.0, -50.0, 40.0)
			a_des = (v_des - s.vel) / 0.30 + s.vel * s.drag()
		_:
			a_des = Vector2.ZERO
	var x := clampf(a_des.x / s.side_power(), -1.0, 1.0)
	var net_y := a_des.y - level.gravity
	var y := 0.0
	if net_y < 0.0:
		y = clampf(net_y / s.up_power(), -1.0, 0.0)
	else:
		y = clampf(net_y / s.down_power(), 0.0, 1.0)
	return [Vector2(x, y), gear]
