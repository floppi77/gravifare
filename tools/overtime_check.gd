extends SceneTree
## Fliegbarkeit der Zwischenfälle (Sonderschicht): Der Autopilot fliegt jedes Level zuerst wie in der Karriere (Regelstand 3, voller Tank), dann
## mit jedem Zwischenfall, der Physik oder Level verändert. Schafft er es ohne, aber nicht mit, wird der Zwischenfall für dieses Level gesperrt.
## Level, die er schon ohne Zwischenfall nicht schafft (von Hand gebaut), bekommen nur die milden Physik-Zwischenfälle nicht gesperrt.
## Ergebnis: data/overtime_block.json (wird von Overtime.blocked gelesen).
##
## Aufruf: godot --headless -s tools/overtime_check.gd [-- s1_01,s1_02] [--out=<pfad>]
## Dauer: rund eine Sekunde je Flug, alle 99 Level etwa 15–25 Minuten.

const CHECK := ["hotjet", "stickygear", "crooked_l", "crooked_r", "leak", "heavy", "slick", "newroute", "pumpcycle"]
const MILD := ["stickygear", "crooked_l", "crooked_r", "leak", "pumpcycle"]     # dürfen auch auf Leveln bleiben, die der Autopilot nicht ohne Weiteres schafft
const NEWROUTE_SEEDS := [11, 22, 33]
const SECONDS := 600.0

func _initialize() -> void:
	var only: Array = []
	var out_path := "res://data/overtime_block.json"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out_path = a.substr(6)
		else:
			only = Array(a.split(",", false))
	var ids: Array = []
	for f in DirAccess.get_files_at("res://data/levels"):
		if f.ends_with(".json") and (only.is_empty() or only.has(f.get_basename())):
			ids.append(f.get_basename())
	ids.sort()
	var block := {}
	var report: Array = []
	var t0 := Time.get_ticks_msec()
	for id in ids:
		var base := _fly(id, "", 0)
		var base_ok := _solved(base)
		var line := "%s base=%s" % [id, "ok" if base_ok else "x"]
		for c in CHECK:
			var cid := String(c).get_slice("_", 0)
			if cid == "pumpcycle" and not Overtime.level_info(id).fuel:
				continue
			if cid == "newroute" and int(Overtime.level_info(id).pads) < 3:
				continue
			var ok := true
			if not base_ok and not MILD.has(c):
				ok = false                                         # ohne Nachweis: harte Zwischenfälle nicht auf diesem Level
			elif base_ok:
				var seeds: Array = NEWROUTE_SEEDS if cid == "newroute" else [0]
				for sd in seeds:
					if not _solved(_fly(id, String(c), int(sd))):
						ok = false
						break
			line += " %s=%s" % [c, "ok" if ok else "x"]
			if not ok:
				var lst: Array = block.get(cid, [])
				if not lst.has(id):
					lst.append(id)
				block[cid] = lst
		print(line)
		report.append(line)
	for k in block:
		(block[k] as Array).sort()
	var data := {"_doc": "Erzeugt von tools/overtime_check.gd: Zwischenfälle, mit denen der Autopilot das Level nicht mehr schafft (Sonderschicht bietet sie dort nicht an).",
		"block": block}
	if only.is_empty():
		var f := FileAccess.open(out_path, FileAccess.WRITE)
		f.store_string(JSON.stringify(data, "\t", true) + "\n")
		f.close()
		print("geschrieben: %s" % out_path)
	print("fertig in %.0f s" % ((Time.get_ticks_msec() - t0) / 1000.0))
	quit()

func _solved(r: Dictionary) -> bool:
	return bool(r.complete) and not bool(r.timed_out) and float(r.hull) > 10.0 and int(r.delivered) + int(r.squashes) >= int(r.jobs) - 1

func _fly(id: String, c: String, seed: int) -> Dictionary:
	var lvl := LevelData.load_file("res://data/levels/%s.json" % id)
	var st := {"seed": 1, "etappe": 0, "perks": {}, "license": "standard", "stage": 0, "curses": [], "pacts": [], "offer": {}}
	var cid := c.get_slice("_", 0)
	if cid != "":
		st.curses = [cid]
	var fx := Overtime.effects(st)
	if c == "crooked_l":
		fx.side_l = 0.75
		fx.side_r = 1.0
	elif c == "crooked_r":
		fx.side_l = 1.0
		fx.side_r = 0.75
	if cid == "newroute":
		var jr := RandomNumberGenerator.new()
		jr.seed = seed
		lvl.jobs = Run.chain_jobs(lvl, maxi(2, lvl.jobs.size() - 1), jr)
	return Bot.fly_level(lvl, SECONDS, Tuning.FUEL_MAX, false, false, 3, 0.0, Overtime.sim_mods(fx), Overtime.run_mods(fx) if cid != "" else {})
