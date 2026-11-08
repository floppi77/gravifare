extends Node
## Einstiegspunkt: Hauptmenü, oder direkt ein Level mit --level=<id> (Entwicklung/Screenshots).

func _ready() -> void:
	var shift_run := false
	var day_run := false
	for a in OS.get_cmdline_user_args():
		if a == "--daily":                     # Dev: Tagschicht direkt starten (--day-rule=wind|fog|mirror|fuel|glass|rush|tailwind, --day-goal=express|precision|clean|profit, --day-date=JJJJ-MM-TT)
			day_run = true
		elif a.begins_with("--day-rule="):
			Flow.dev_day_rule = a.substr(11)
			day_run = true
		elif a.begins_with("--day-goal="):
			Flow.dev_day_goal = a.substr(11)
			day_run = true
		elif a.begins_with("--day-date="):
			Daily.override_date = a.substr(11)
			day_run = true
		if a.begins_with("--shift-map="):       # Dev: Nachtschicht ab Karte N (1–9) starten
			Flow.dev_shift_start = clampi(int(a.substr(12)) - 1, 0, NightShift.MAPS - 1)
			shift_run = true
		elif a == "--shift-demo":               # Dev: die Karten davor mit Beispielwerten füllen (Vorschau der Auswertung)
			Flow.dev_shift_fake = true
			shift_run = true
		elif a == "--shift":
			shift_run = true
	if shift_run:
		Flow.start_shift.call_deferred()
		return
	if day_run:
		Flow.start_daily.call_deferred()
		return
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--scene="):           # Dev: garage | credits | finale | menu direkt öffnen
			get_tree().change_scene_to_file.call_deferred("res://src/ui/%s.tscn" % a.substr(8).replace("menu", "main_menu"))
			return
		if a.begins_with("--level="):
			Flow.current_level = Flow.resolve_level(a.substr(8))
			get_tree().change_scene_to_file.call_deferred(Flow.GAME)
			return
	get_tree().change_scene_to_file.call_deferred(Flow.MENU)
