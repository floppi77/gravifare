extends Node
## Einstiegspunkt: Startbildschirm und Hauptmenü, oder direkt ein Level mit --level=<id> (Entwicklung/Screenshots).
## Mit Entwicklerschaltern geht es ohne Startbildschirm direkt ins Menü (außer mit --splash).

const SPLASH := "res://src/ui/splash.tscn"
const Splash := preload("res://src/ui/splash.gd")

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
		elif a.begins_with("--shift-quality="):    # Dev: Güte der Beispielkarten von --shift-demo (0–1)
			Flow.dev_shift_quality = float(a.substr(16))
		elif a == "--shift":
			shift_run = true
	if shift_run:
		Flow.start_shift.call_deferred()
		return
	if Array(OS.get_cmdline_user_args()).any(func(a): return String(a).begins_with("--ot=")):      # Dev: Sonderschicht (siehe Flow.dev_overtime)
		Flow.dev_overtime.call_deferred(OS.get_cmdline_user_args())
		return
	if day_run:
		Flow.start_daily.call_deferred()
		return
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--watch-file="):      # Dev: gespeicherten Lauf (Replay-JSON) als „Bestflug ansehen“ abspielen
			var wd = JSON.parse_string(FileAccess.get_file_as_string(a.substr(13)))
			if typeof(wd) == TYPE_DICTIONARY:
				Flow.start_watch.call_deferred(Flow.resolve_level(String(wd.get("level", ""))), wd)     # Läufe tragen die Anzeige-Id (S1-04)
				return
		if a.begins_with("--scene="):           # Dev: garage | credits | finale | menu direkt öffnen
			get_tree().change_scene_to_file.call_deferred("res://src/ui/%s.tscn" % a.substr(8).replace("menu", "main_menu"))
			return
		if a.begins_with("--level="):
			Flow.current_level = Flow.resolve_level(a.substr(8))
			get_tree().change_scene_to_file.call_deferred(Flow.GAME)
			return
	# Normaler Start: erst der Startbildschirm (Studio, Spiellogo, Godot), der danach ins Hauptmenü wechselt
	get_tree().change_scene_to_file.call_deferred(SPLASH if Splash.wanted(OS.get_cmdline_user_args()) else Flow.MENU)
