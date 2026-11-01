extends SceneTree
## Aufruf: godot --headless -s tools/intro_probe.gd -- <name> [dt=0.5]
## Spielt einen Einspieler (data/intros/<name>.json) ohne Darstellung ab und gibt Taxi-Zustand und Mover alle dt Sekunden aus.
func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var key: String = args[0] if args.size() > 0 else "magnet_pull"
	var every := float(args[1]) if args.size() > 1 else 0.5
	var d := IntroDemo.new()
	if not d.setup(key):
		print("Demo nicht gefunden: ", key)
		quit()
		return
	var next := 0.0
	while d.t <= d.length + 0.01:
		if d.t >= next:
			next += every
			var s := d.run.sim
			var mv := ""
			for m in d.level.movers:
				var r: Rect2 = m.rect
				mv += " %s[%.0f,%.0f]" % [String(m.kind).substr(0, 3), r.position.x, r.position.y]
			var dr := ""
			for ch in d.level.doors:
				dr += " door%s=%s" % [ch, "open" if d.level.door_is_open(ch, d.level.clock) else "shut"]
			print("t=%5.2f pos=(%4.0f,%4.0f) vel=(%4.0f,%4.0f) hull=%3.0f st=%d%s%s" % [d.t, s.pos.x, s.pos.y, s.vel.x, s.vel.y, s.hull, s.state, mv, dr])
		d.step(1.0 / 60.0)
	quit()
