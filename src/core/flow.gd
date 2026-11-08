extends Node
## Autoload "Flow": Szenenwechsel und aktuelles Level. Levelreihenfolge = sortierte Dateinamen.

const VERSION := "0.9.12"                # Spielversion (Anzeige in Speicherplatz-Bildschirm und Hauptmenü)
const MENU := "res://src/ui/main_menu.tscn"
const GAME := "res://src/game/game.tscn"
var current_level := ""
# Kampagnenzustand eines Laufs (5 Leben für alle Level; Sprit und Credits laufen von Level zu Level mit)
var lives := Tuning.START_LIVES
var entry_fuel := Tuning.FUEL_MAX       # Sprit bei Levelbeginn (auch Wiederholung nach Verlust)
var entry_credits := 0.0
var carry_passenger := {}               # Fahrgast, der ins nächste Level mitfährt
var run_seed := 0                       # Zufalls-Seed des Laufs (Spritpreise): je Lauf neu, je Level/Neustart reproduzierbar
var shift := false                      # Nachtschicht (Endlosmodus): zählt nur die eigene Bestleistung, kein Feldzug, keine Medaillen
var shift_fares := 0                    # bisher beförderte Fahrgäste dieser Schicht
var shift_maps := 0                     # abgeschlossene Karten dieser Schicht
var shift_next := ""
var practice := false                   # Übungsflug aus der Levelauswahl: schreibt und löscht keinen Feldzug (Medaillen und Bestzeiten zählen)
var daily := false                      # Tagesflug (siehe daily.gd): eine Karte, Seed aus dem Datum, Serientaxi, zählt nur für den Tagesbestwert
var daily_date := ""
var community := false:                 # Community-Level (user://community/, siehe community_store.gd): ein Level, zählt nur für die eigenen Bestwerte
	set(v):
		community = v
		Save.community_mode = v
var editor_autopilot := false            # Testflug aus dem Level-Editor: der Autopilot fliegt, man sieht ihm zu (zählt nichts)
var return_to_editor := ""              # Level-ID, in deren Editor es nach einem Testflug zurückgeht (setzt der Editor)
var editor_skip_solve := false          # Debug: Speichern im Editor ohne Handlösung (nur wirksam bei Save.debug; bleibt über Testflüge erhalten)
var editor_session := ""                # Die in dieser Editorsitzung gespeicherte Fassung bleibt über den Testflug hinweg die, die das nächste Speichern ersetzt
var editor_original := ""               # Debug: Id des mitgelieferten Levels, das der Editor gerade bearbeitet (bleibt über den Testflug erhalten)
var editor_runs := {}                   # Geschaffte Testflüge noch nicht gespeicherter Fassungen (Entwürfe): Level-ID → {time, score, plays}; der Editor übernimmt sie beim Speichern in den Spielstand
var menu_screen := ""                   # Bildschirm, mit dem das Hauptmenü startet ("community": zurück zur Community-Liste)

## Geschafften Testflug eines Entwurfs merken (Bestzeit, Bestwert, Zahl der Flüge), bis die Fassung gespeichert wird.
func note_editor_run(id: String, time: float, score: int) -> void:
	var prev: Dictionary = editor_runs.get(id, {})
	editor_runs[id] = {"time": minf(float(prev.get("time", 1e9)), time), "score": maxi(int(prev.get("score", 0)), score), "plays": int(prev.get("plays", 0)) + 1}

func level_ids() -> Array:
	var ids: Array = []
	var dir := DirAccess.open("res://data/levels")
	if dir == null:
		return ids
	for f in dir.get_files():
		if f.ends_with(".json"):
			ids.append(f.get_basename())
	ids.sort()
	return ids

## Dev: Level aus Kommandozeile/Eingabe auflösen – Levelnummer (34), Dateiname (s4_01) oder Anzeigename (S4-01, s4-01).
func resolve_level(arg: String) -> String:
	var ids := level_ids()
	var a := arg.strip_edges().to_lower().replace("-", "_")
	if a.is_valid_int():
		var n := int(a)
		var id := "s%d_%02d" % [(n - 1) / 11 + 1, (n - 1) % 11 + 1]       # Levelnummer = (Sektor-1)*11 + Index (auch mit Lücken)
		return id if ids.has(id) else a
	return a

const KOFI_URL := "https://ko-fi.com/floppi77"
const TUTORIAL_ID := "tutorial"
var tutorial_next := ""                 # nach dem Tutorial: Level, in das es übergeht ("" = zurück ins Menü)

## Community-Skripte erst bei Gebrauch laden: Autoloads dürfen beim Start keine Skripte vorladen, die selbst Autoloads kennen.
func community_level_script() -> GDScript:
	return load("res://src/core/community_level.gd")

func community_store() -> GDScript:
	return load("res://src/core/community_store.gd")

func level_path(id: String) -> String:
	if id == TUTORIAL_ID:
		return "res://data/tutorial/tutorial.json"
	if community_level_script().is_valid_id(id):
		return community_store().path_for(id)
	return "res://data/levels/%s.json" % id

func in_tutorial() -> bool:
	return current_level == TUTORIAL_ID

## Tutorial starten (eigener Mini-Lauf mit vollen Leben/Tank, ohne Speicherstand-Eingriff). `next_id`: Level danach, "" = Menü.
func start_tutorial(next_id := "") -> void:
	lives = Tuning.START_LIVES
	entry_fuel = Tuning.FUEL_MAX
	entry_credits = 0.0
	carry_passenger = {}
	run_seed = randi() % 1000000
	practice = false
	shift = false
	daily = false
	tutorial_next = next_id
	start_level(TUTORIAL_ID)

## Neuer Lauf: volle Leben, voller Tank, keine Credits – ab dem gewählten Level.
func start_campaign(id: String) -> void:
	lives = Tuning.START_LIVES
	entry_fuel = Tuning.FUEL_MAX
	entry_credits = 0.0
	carry_passenger = {}
	run_seed = randi() % 1000000
	practice = false
	shift = false
	daily = false
	Save.reset_workshop()                  # neuer Feldzug beginnt ohne Einbauten
	Save.set_campaign({"level": id, "lives": lives, "fuel": entry_fuel, "credits": entry_credits, "seed": run_seed, "carry": {}})
	start_level(id)

## Start aus der Levelauswahl: Läuft ein Feldzug, wird es ein Übungsflug (der Feldzug bleibt unberührt), sonst beginnt ab hier ein neuer Feldzug.
func start_selected(id: String) -> void:
	if Save.campaign().is_empty():
		start_campaign(id)
		return
	lives = Tuning.START_LIVES
	entry_fuel = Tuning.FUEL_MAX
	entry_credits = 0.0
	carry_passenger = {}
	run_seed = randi() % 1000000
	practice = true
	shift = false
	daily = false
	start_level(id)

## Nachtschicht: zufällige Aufträge auf bereits geflogenen Karten, bis alle Leben weg sind. Ziel: möglichst viele Fahrgäste.
func start_shift() -> void:
	lives = Tuning.START_LIVES
	entry_fuel = Tuning.FUEL_MAX
	entry_credits = 0.0
	carry_passenger = {}
	run_seed = randi() % 1000000
	practice = true
	shift = true
	daily = false
	shift_fares = 0
	shift_maps = 0
	var first := _pick_shift_map("")
	shift_next = _pick_shift_map(first)
	start_level(first)

## Tagesflug: Karte, Aufträge und Preise hängen nur vom Datum ab (siehe daily.gd). Volle Leben, voller Tank, keine Credits.
func start_daily() -> void:
	daily_date = Daily.today()
	var pool := Save.daily_pool(level_ids())
	if pool.is_empty():
		pool = level_ids()                 # nur im Debug-Modus erreichbar (sonst erst ab Sektor 1 frei)
	var id := Daily.level_of_day(Save.daily_entry(), pool, daily_date)
	if id == "":
		return
	lives = Tuning.START_LIVES
	entry_fuel = Tuning.FUEL_MAX
	entry_credits = 0.0
	carry_passenger = {}
	run_seed = Daily.seed_for(daily_date)
	practice = true
	shift = false
	daily = true
	Save.count_event("daily_flights")
	Save.write()
	start_level(id)

## Debug-Modus ein- oder ausschalten (bleibt über einen Neustart erhalten).
func set_debug(on: bool) -> void:
	Save.debug = on
	if not on:
		editor_skip_solve = false
	Settings.set_value("debug", on)

## Game Over im Feldzug: zurück an den Anfang des Sektors. Gibt das Level zurück, mit dem es weitergeht.
func lose_sector(sector: int) -> LevelData:
	var first := "s%d_01" % sector
	Save.lose_sector(sector, first, randi() % 1000000)
	return LevelData.load_file(level_path(first))

## Nächste Karte: nur Level, die schon geschafft sind (mindestens Sektor 1).
func _pick_shift_map(avoid: String) -> String:
	var pool: Array = Save.data.completed.keys().filter(func(id): return level_ids().has(id) and id != avoid)
	if pool.is_empty():
		pool = level_ids().slice(0, 11).filter(func(id): return id != avoid)
	return pool[randi() % pool.size()]

## Ende der Schicht (Game Over oder Hauptmenü): Bestwert sichern.
func finish_shift(extra_fares: int) -> void:
	if not shift:
		return
	shift_fares += extra_fares
	Save.note_max("shift_best", shift_fares)
	Save.write()
	shift = false

## Gespeicherten Feldzug fortsetzen (Leben, Credits, Sprit, Seed, Fahrgast); false, wenn keiner vorhanden ist.
func resume_campaign() -> bool:
	var c := Save.campaign()
	if c.is_empty() or not level_ids().has(String(c.level)):
		return false
	lives = clampi(int(c.get("lives", Tuning.START_LIVES)), 1, Tuning.START_LIVES)
	entry_fuel = clampf(float(c.get("fuel", Tuning.FUEL_MAX)), Tuning.MIN_START_FUEL, Tuning.FUEL_MAX)
	entry_credits = maxf(0.0, float(c.get("credits", 0.0)))
	carry_passenger = c.get("carry", {}) if c.get("carry", {}) is Dictionary else {}
	run_seed = int(c.get("seed", 0))
	practice = false
	shift = false
	daily = false
	start_level(String(c.level))
	return true

## Community-Level: ein Level, volle Leben, voller Tank, keine Credits, Serientaxi; der Feldzug bleibt unberührt (wie der Übungsflug).
func start_community(id: String, autopilot := false) -> void:
	if not community_store().playable(id):         # gespeichert oder Entwurf eines Testflugs
		return
	editor_autopilot = autopilot and return_to_editor != ""        # nur aus dem Editor heraus
	lives = Tuning.START_LIVES
	entry_fuel = Tuning.FUEL_MAX
	entry_credits = 0.0
	carry_passenger = {}
	run_seed = randi() % 1000000
	practice = true
	shift = false
	daily = false
	start_level(id)

func start_level(id: String) -> void:
	current_level = id
	community = community_level_script().is_valid_id(id)       # nur hier gesetzt: kein anderer Spielmodus kann es „vergessen“
	if not community:
		return_to_editor = ""
		editor_autopilot = false
	get_tree().paused = false
	get_tree().change_scene_to_file(GAME)

func next_level_id() -> String:
	if community:
		return ""                          # Community-Level: ein Level, danach zurück zur Liste
	if shift:
		return shift_next
	if daily:
		return ""                          # Tagesflug: eine Karte, danach zurück ins Menü
	var ids := level_ids()
	var i := ids.find(current_level)
	return ids[i + 1] if i >= 0 and i + 1 < ids.size() else ""

func to_menu() -> void:
	menu_screen = ("editor:" + return_to_editor if return_to_editor != "" else "community") if community else ""
	return_to_editor = ""
	editor_autopilot = false
	var g := get_tree().current_scene
	if shift and g != null and "run" in g:
		finish_shift(g.run.delivered + g.run.extras_delivered)      # Schicht abgebrochen: Bestwert trotzdem sichern
	Save.write()                       # Statistiken (Serien, Auslieferungen …) sichern
	community = false
	get_tree().paused = false
	Sfx.set_thrust(0.0, 0.0)
	Sfx.stop_ambient()
	get_tree().change_scene_to_file(MENU)

## Nach Level 99: Finale, danach Abspann.
func to_finale() -> void:
	Save.write()
	Sfx.set_thrust(0.0, 0.0)
	Sfx.stop_ambient()
	get_tree().change_scene_to_file("res://src/ui/finale.tscn")

## Entwicklungshilfe: --shot=<png> --frames=<n> macht nach n Frames einen Screenshot und beendet;
## --press=<aktion>@<frame> löst eine Eingabeaktion aus (z. B. pause@20).
var _shot := ""
var _shot_frame := 0
var _presses: Array = []
var _frame := 0

func _ready() -> void:
	community_store().game_version = VERSION
	Save.debug = Settings.values.debug
	for a in OS.get_cmdline_user_args():
		if a == "--dump-input":
			for act in ["ui_accept", "ui_cancel", "ui_up", "ui_down", "gear", "pause"]:
				print(act, " -> ", InputMap.action_get_events(act).map(func(e): return e.as_text()))
			get_tree().quit.call_deferred()
		if a.begins_with("--seed="):          # Dev: Zufalls-Seed fest vorgeben
			run_seed = int(a.substr(7))
		if a.begins_with("--lives="):         # Dev: Anzahl Leben für diesen Lauf
			lives = int(a.substr(8))
		if a.begins_with("--lang="):          # Dev: Sprache für diesen Lauf setzen (nicht gespeichert)
			Loc.set_language(a.substr(7))
		if a.begins_with("--shot="):
			_shot = a.substr(7)
		elif a.begins_with("--frames="):
			_shot_frame = int(a.substr(9))
		elif a.begins_with("--press="):
			var parts := a.substr(8).split("@")
			_presses.append([parts[0], int(parts[1])])

func _process(_d: float) -> void:
	if _shot == "" and _presses.is_empty():
		return
	_frame += 1
	for p in _presses:
		if p[1] == _frame:
			var ev := InputEventAction.new()
			ev.action = p[0]
			ev.pressed = true
			Input.parse_input_event(ev)
			var up := InputEventAction.new()
			up.action = p[0]
			up.pressed = false
			Input.parse_input_event(up)
	if _shot != "" and _frame == _shot_frame:
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(_shot)
		get_tree().quit()
