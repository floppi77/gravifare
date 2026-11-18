extends SceneTree
## Bildzeit je Level messen (Runde 84). Startet das Spiel normal (boot.tscn) und misst nach 2 s Aufwärmen die CPU-Zeit je Bild,
## VSync per Mailbox umgangen. Aufruf aus der Projektwurzel, z. B. in 4K ohne Fenster:
##   gamescope --backend headless -W 3840 -H 2160 -- godot --path . --resolution 3840x2160 -s tools/perf/frame_bench.gd -- \
##       --level=44 --seed=1 --autopilot --perf-secs=15 [--profile-draw] [--hide=props_view,hud]
## Ausgabe: "PERF frames=… avg=… p50=… p99=… max=… worst200=…" (ms; worst200 = langsamstes Fenster aus 200 Bildern) und "SPIKES …" (Bilder über 9 ms).
## --hide= blendet Knoten nach Skriptname oder Knotenname aus (Verursacher eingrenzen), --perf-tree gibt den Knotenbaum aus. Mit Autopilot misst man auch dessen Planung mit.
var n := 0
var secs := 15.0
var t_start := 0
var dts: Array = []
var last := 0
func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--perf-secs="):
			secs = float(a.substr(12))
	change_scene_to_file("res://src/game/boot.tscn")
	last = Time.get_ticks_usec()
func _process(_d: float) -> bool:
	n += 1
	if n == 5 or n == 60:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_MAILBOX)
	Engine.max_fps = 0
	if n == 90:
		_apply_hide(root)
		if OS.get_cmdline_user_args().has("--perf-tree"):
			_tree(root, 0)
	var now := Time.get_ticks_usec()
	if t_start == 0 and n > 60 and now > 2000000 + _boot():
		t_start = now
	if t_start != 0:
		dts.append(float(now - last) / 1000.0)
	last = now
	if t_start != 0 and now - t_start > int(secs * 1000000.0):
		var b := dts.duplicate(); b.sort()
		var s := 0.0
		for v in b: s += v
		var worst := 0.0
		var win := 200
		for i in range(0, maxi(dts.size() - win, 1), 50):
			var m := 0.0
			for j in range(i, mini(i + win, dts.size())): m += dts[j]
			worst = maxf(worst, m / float(mini(win, dts.size() - i)))
		var calls := Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
		print("PERF frames=%d avg=%.2f p50=%.2f p99=%.2f max=%.2f worst200=%.2f calls=%d" % [b.size(), s / b.size(), b[int(b.size() * 0.5)], b[int(b.size() * 0.99)], b[-1], worst, int(calls)])
		var spikes := []
		var acc := 0.0
		for i in dts.size():
			acc += dts[i]
			if dts[i] > 9.0: spikes.append("%.1fs:%.0fms" % [acc / 1000.0, dts[i]])
		print("SPIKES ", spikes.size(), " ", spikes.slice(0, 40))
		quit()
	return false
var _b := 0
func _boot() -> int:
	if _b == 0:
		_b = Time.get_ticks_usec()
	return _b

func _tree(nd: Node, d: int) -> void:
	var sc: Script = nd.get_script()
	if d < 6:
		print("TREE ", "  ".repeat(d), nd.name, " ", nd.get_class(), " ", sc.resource_path.get_file() if sc else "", " vis=", nd.visible if nd is CanvasItem else "")
	for c in nd.get_children():
		_tree(c, d + 1)
func _apply_hide(nd: Node) -> void:
	var hide := []
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--hide="):
			hide = a.substr(7).split(",")
	var sc: Script = nd.get_script()
	var key := sc.resource_path.get_file().get_basename() if sc else String(nd.name)
	if key in hide or String(nd.name) in hide:
		if nd is CanvasItem: nd.visible = false
		nd.process_mode = Node.PROCESS_MODE_DISABLED
		print("HIDDEN ", nd.name, " ", key)
	for c in nd.get_children():
		_apply_hide(c)
