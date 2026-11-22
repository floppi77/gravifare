extends Node
## Autoload "Flow": Szenenwechsel und aktuelles Level. Levelreihenfolge = sortierte Dateinamen.

const VERSION := "1.8.0"                # Spielversion (Anzeige in Speicherplatz-Bildschirm und Hauptmenü)
const MENU := "res://src/ui/main_menu.tscn"
const GAME := "res://src/game/game.tscn"
var current_level := ""
# Karrierezustand eines Laufs (5 Leben für alle Level; Sprit und Credits laufen von Level zu Level mit)
var lives := Tuning.START_LIVES
var entry_fuel := Tuning.FUEL_MAX       # Sprit bei Levelbeginn (auch Wiederholung nach Verlust)
var entry_credits := 0.0
var carry_passenger := {}               # Fahrgast, der ins nächste Level mitfährt
var run_seed := 0                       # Zufalls-Seed des Laufs (Spritpreise): je Lauf neu, je Level/Neustart reproduzierbar
var shift := false                      # Nachtschicht (9 Karten): zählt nur für die Schichtnote, keine Karriere, keine Medaillen
var shift_date := ""                    # Datum der laufenden Schicht (Seed für Karten, Aufträge und Schwerkraft)
var shift_plan: Array = []              # die 9 Karten der Schicht (je Sektor eine)
var shift_results: Array = []           # Wertung der bisher geflogenen Karten
var shift_credits := 0.0                # Guthaben am Ende der letzten Karte (fließt in die Schichtwertung ein)
var shift_last_result := {}              # Gesamtwertung der zuletzt beendeten Schicht (für das Finale der Nachtschicht)
var shift_last_date := ""
var shift_done := false                 # Wertung ist gebildet; die Schicht bleibt bis zum Verlassen "aktiv", damit nach der Auswertung kein weiteres Level folgt
var dev_shift_quality := -1.0           # Dev: --shift-quality=0..1 macht die Beispielkarten von --shift-demo besser (0 = schlecht, 1 = makellos)
var dev_shift_fake := false             # Entwicklung (--shift-demo): die Karten vor der Startkarte als geflogen mit Beispielwerten füllen (Vorschau der Auswertung)
var dev_shift_start := 0                # Entwicklung (--shift-map=N): Schicht ab dieser Karte starten
var practice := false                   # Übungsflug aus der Levelauswahl: schreibt und löscht keine Karriere (Medaillen und Bestzeiten zählen)
var daily := false                      # Tagesflug (siehe daily.gd): eine Karte, Seed aus dem Datum, Serientaxi, zählt nur für den Tagesbestwert
var daily_date := ""
var daily_rule := ""                 # Tagschicht: Regel des Tages (DayShift.RULES)
var daily_goal := ""                 # … und Tagesziel (DayShift.GOALS)
var daily_briefed := false            # Briefing dieser Tagschicht-Sitzung schon gezeigt (ein Neustart des Levels zeigt es nicht erneut)
var dev_day_rule := ""                # Dev: Regel/Ziel erzwingen (--day-rule=, --day-goal=)
var dev_day_goal := ""
var community := false:                 # Community-Level (user://community/, siehe community_store.gd): ein Level, zählt nur für die eigenen Bestwerte
	set(v):
		community = v
		Save.community_mode = v or overtime
var overtime := false:                  # Sonderschicht (overtime.gd): eigener Lauf, zählt nur für ihre Wertung; Statistik, Erfolge und Karriere bleiben unberührt
	set(v):
		overtime = v
		Save.community_mode = v or community
var ot: Dictionary = {}                 # Zustand des laufenden Sonderschicht-Laufs (gesichert in Save.data.overtime.run: zu Etappenbeginn und nach jeder Etappe)
var ot_last: Dictionary = {}            # zuletzt beendeter Lauf {state, rec} für das Finale der Sonderschicht
const OT_STOP := "res://src/ui/overtime_stop.tscn"
const OT_MENU := "res://src/ui/overtime_menu.tscn"
const OT_FINALE := "res://src/ui/overtime_finale.tscn"
var editor_autopilot := false            # Testflug aus dem Level-Editor: der Autopilot fliegt, man sieht ihm zu (zählt nichts)
var return_to_editor := ""              # Level-ID, in deren Editor es nach einem Testflug zurückgeht (setzt der Editor)
var watch := {}                         # Bestflug ansehen: gespeicherter Lauf (Replay), den das Spiel nachfliegt; zählt nichts
var watch_level := ""                   # zuletzt angesehenes Level: die Levelauswahl kehrt dorthin zurück
var came_from_achievements := false     # Statistik: nach der Erfolgsübersicht steht der Fokus wieder auf ihrem Knopf
var editor_skip_solve := false          # Debug: Speichern im Editor ohne Handlösung (nur wirksam bei Save.debug; bleibt über Testflüge erhalten)
var editor_session := ""                # Die in dieser Editorsitzung gespeicherte Fassung bleibt über den Testflug hinweg die, die das nächste Speichern ersetzt
var editor_original := ""               # Debug: Id des mitgelieferten Levels, das der Editor gerade bearbeitet (bleibt über den Testflug erhalten)
var editor_runs := {}                   # Geschaffte Testflüge noch nicht gespeicherter Fassungen (Entwürfe): Level-ID → {time, score, plays}; der Editor übernimmt sie beim Speichern in den Spielstand
var career_clock := 0.0                 # Runde 85: Karriere-Uhr (Flugzeit der laufenden Karriere in Sekunden, inkl. verlorener Versuche)
var career_splits: Array = []           # Zwischenzeiten je geschafftem Sektor: [{"sector": n, "time": s}]
var career_full := false                # Karriere ab Level 1 begonnen: nur dann zählen Bestzeiten der Uhr
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
	watch = {}
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
	watch = {}
	lives = Tuning.START_LIVES
	entry_fuel = Tuning.FUEL_MAX
	entry_credits = 0.0
	carry_passenger = {}
	run_seed = randi() % 1000000
	practice = false
	shift = false
	daily = false
	Save.reset_workshop()                  # neue Karriere beginnt ohne Einbauten
	career_clock = 0.0
	career_splits = []
	career_full = level_ids().find(id) == 0
	Save.set_campaign(career_fields({"level": id, "lives": lives, "fuel": entry_fuel, "credits": entry_credits, "seed": run_seed, "carry": {}}))
	start_level(id)

## Start aus der Levelauswahl: Läuft eine Karriere, wird es ein Übungsflug (die Karriere bleibt unberührt), sonst beginnt ab hier eine neue Karriere.
func start_selected(id: String) -> void:
	watch = {}
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

## Dev (--shift-demo): Zählwerte einer Beispielkarte; `q` 0–1 = Güte (negativ: zufällig wie bisher).
func dev_fake_map_stats(drng: RandomNumberGenerator, q: float) -> Dictionary:
	var ds := {"jobs": 4, "waits": [], "landings": [], "damage": drng.randf_range(0.0, 60.0), "near": drng.randi() % 6}
	if q >= 0.0:
		ds["damage"] = drng.randf_range(0.0, lerpf(60.0, 6.0, q))
		ds["near"] = clampi(int(round(q * 5.0 - drng.randf_range(0.0, 2.0))), 0, 5)
	for j in 4:
		var wmax := lerpf(40.0, 12.0, q) if q >= 0.0 else 40.0
		ds.waits.append({"job": j, "wait": drng.randf_range(4.0, wmax), "leg": 300.0})
		if j < 3:
			ds.landings.append({"job": j, "vy": drng.randf_range(8.0, lerpf(44.0, 24.0, q) if q >= 0.0 else 44.0)})
	return ds

## Nachtschicht: 9 Karten, je eine pro Sektor (1 → 9), mit festem Tages-Seed. Ein Versuch pro Tag (im Debug-Modus unbegrenzt), 5 Taxis, volle Tanks.
func start_shift() -> void:
	watch = {}
	var date := Daily.today()
	if Save.shift_used_today(date):
		return
	shift_date = date
	shift_plan = NightShift.plan(date, level_ids())
	if shift_plan.is_empty():
		return
	lives = NightShift.START_TAXIS
	entry_fuel = Tuning.FUEL_MAX
	entry_credits = 0.0
	carry_passenger = {}
	run_seed = Daily.seed_for(date)
	practice = true
	shift = true
	daily = false
	shift_results = []
	shift_credits = 0.0
	shift_done = false
	if dev_shift_fake:
		var drng := RandomNumberGenerator.new()
		drng.seed = 4
		for i in clampi(dev_shift_start, 0, shift_plan.size() - 1):
			var dl := LevelData.load_file(level_path(String(shift_plan[i])))
			var ds := dev_fake_map_stats(drng, dev_shift_quality)
			var dr := NightShift.map_result(ds)
			dr["id"] = String(shift_plan[i])
			dr["time"] = drng.randf_range(60.0, 260.0)
			dr["number"] = dl.number
			dr["names"] = dl.names
			shift_results.append(dr)
		shift_credits = 4200.0 if dev_shift_quality < 0.0 else 4200.0 + dev_shift_quality * 9000.0
	Save.shift_begin(date)
	start_level(shift_plan[clampi(dev_shift_start, 0, shift_plan.size() - 1)])

## Tagschicht: Karte, Regel, Ziel, Aufträge und Preise hängen nur vom Datum ab (siehe daily.gd, day_shift.gd). Volle Leben, keine Credits, Tank je nach Regel.
func start_daily() -> void:
	watch = {}
	daily_date = Daily.today()
	daily_rule = dev_day_rule if dev_day_rule != "" else DayShift.rule_of(daily_date)
	daily_goal = dev_day_goal if dev_day_goal != "" else DayShift.goal_of(daily_date)
	daily_briefed = false
	var pool := level_ids()                    # alle 99 Level: für alle Spieler dasselbe Level am selben Tag, auch wenn es noch nicht geschafft ist
	var id := Daily.level_of_day(Save.daily_entry(), pool, daily_date)
	if id == "":
		return
	lives = Tuning.START_LIVES
	entry_fuel = DayShift.entry_fuel(daily_rule)
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

## Game Over in der Karriere: zurück an den Anfang des Sektors. Gibt das Level zurück, mit dem es weitergeht.
func lose_sector(sector: int) -> LevelData:
	var first := "s%d_01" % sector
	Save.lose_sector(sector, first, randi() % 1000000)
	Save.data.campaign = career_fields(Save.data.campaign)      # die Karriere-Uhr läuft über das Game Over hinweg weiter
	Save.write()
	return LevelData.load_file(level_path(first))

## Index der laufenden Karte in der Schicht (0 = Sektor 1), -1 außerhalb einer Schicht.
func shift_index() -> int:
	return shift_plan.find(current_level) if shift else -1

## Ende der Schicht (letzte Karte, Game Over oder Hauptmenü): Gesamtwertung bilden und festhalten. Nicht geflogene Karten zählen 0.
func finish_shift() -> Dictionary:
	if not shift or shift_done:
		return {}
	shift_done = true                  # `shift` bleibt gesetzt: sonst fände next_level_id() nach der Auswertung das nächste Karriere-Level
	var res := NightShift.final_result(shift_results, lives, shift_credits)
	var now := Time.get_datetime_dict_from_system()
	res["date"] = shift_date
	res["hour"] = int(now.hour)
	res["minute"] = int(now.minute)
	shift_last_result = res
	shift_last_date = shift_date
	Save.shift_record(shift_date, res, shift_results)
	return res

## Gespeicherte Karriere fortsetzen (Leben, Credits, Sprit, Seed, Fahrgast); false, wenn keine vorhanden ist.
func resume_campaign() -> bool:
	watch = {}
	var c := Save.campaign()
	if c.is_empty() or not level_ids().has(String(c.level)):
		return false
	lives = clampi(int(c.get("lives", Tuning.START_LIVES)), 1, Tuning.START_LIVES)
	entry_fuel = clampf(float(c.get("fuel", Tuning.FUEL_MAX)), Tuning.MIN_START_FUEL, Tuning.FUEL_MAX)
	entry_credits = maxf(0.0, float(c.get("credits", 0.0)))
	carry_passenger = c.get("carry", {}) if c.get("carry", {}) is Dictionary else {}
	run_seed = int(c.get("seed", 0))
	career_clock = maxf(0.0, float(c.get("clock", 0.0)))
	career_splits = c.get("splits", []) if c.get("splits", []) is Array else []
	career_full = bool(c.get("full", false))
	practice = false
	shift = false
	daily = false
	start_level(String(c.level))
	return true

## Karriere-Uhr in den gespeicherten Karriere-Eintrag übernehmen (ohne zu schreiben): Abbruch ins Menü, verlorenes Leben oder
## Schließen des Fensters dürfen die Zeit des laufenden Versuchs nicht zurückgeben.
func store_clock() -> void:
	if is_career() and not Save.campaign().is_empty():
		Save.data.campaign["clock"] = career_clock

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and get_tree().current_scene != null and get_tree().current_scene.scene_file_path == GAME:
		store_clock()
		Save.write()

## Felder der Karriere-Uhr an einen Karriere-Eintrag des Spielstands anhängen.
func career_fields(c: Dictionary) -> Dictionary:
	c["clock"] = career_clock
	c["splits"] = career_splits.duplicate(true)
	c["full"] = career_full
	return c

## Läuft gerade die Karriere selbst (kein Übungsflug, keine Schicht, Community, Flugschule oder Bestflug)?
func is_career() -> bool:
	return not (practice or shift or daily or community or overtime or in_tutorial() or not watch.is_empty() or editor_autopilot)

## Zwischenzeit am Ende eines Sektors festhalten. Gibt {sector, time, best (vorherige Bestzeit, -1 ohne), total_best} zurück.
## Bestzeiten (je Sektor die schnellste Zwischenzeit, dazu die schnellste ganze Karriere) zählen nur für Karrieren ab Level 1.
func note_career_split(sector: int, last_sector: bool) -> Dictionary:
	for sp in career_splits:
		if int(sp.get("sector", 0)) == sector:
			return {}
	career_splits.append({"sector": sector, "time": career_clock})
	var st: Dictionary = Save.data.stats
	var bests: Dictionary = st.get("speed_splits", {}) if st.get("speed_splits", {}) is Dictionary else {}
	var key := str(sector)
	var prev := float(bests.get(key, -1.0))
	var out := {"sector": sector, "time": career_clock, "best": prev, "total_best": -1.0}
	if career_full and not Save.dev_session:
		if prev < 0.0 or career_clock < prev:
			bests[key] = career_clock
		st["speed_splits"] = bests
		if last_sector:
			var tb := float(st.get("speed_total", -1.0))
			out.total_best = tb
			if tb < 0.0 or career_clock < tb:
				st["speed_total"] = career_clock
		Save.write()
	return out

## Zeit als h:mm:ss.z bzw. m:ss.z (Karriere-Uhr).
static func clock_text(t: float) -> String:
	var ds := int(floor(maxf(t, 0.0) * 10.0))
	var s := ds / 10
	if s >= 3600:
		return "%d:%02d:%02d.%d" % [s / 3600, (s / 60) % 60, s % 60, ds % 10]
	return "%d:%02d.%d" % [s / 60, s % 60, ds % 10]

## Community-Level: ein Level, volle Leben, voller Tank, keine Credits, Serientaxi; die Karriere bleibt unberührt (wie der Übungsflug).
func start_community(id: String, autopilot := false) -> void:
	watch = {}
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

## Bestflug eines Levels ansehen (Levelauswahl): Startwerte aus der Aufzeichnung, kein Eintrag in Karriere oder Statistik.
func start_watch(id: String, d: Dictionary) -> void:
	watch = d
	watch_level = id
	lives = int(d.get("lives", Tuning.START_LIVES))
	entry_fuel = float(d.get("fuel", -1.0))
	entry_credits = float(d.get("credits", 0.0))
	carry_passenger = (d.get("carry", {}) as Dictionary).duplicate(true)
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
	if overtime:
		return String(ot.get("level", "")) if String(ot.get("phase", "")) == "fly" else ""      # Sonderschicht: das an der Kreuzung gewählte Level
	if shift:
		var i := shift_index()
		return String(shift_plan[i + 1]) if i >= 0 and i + 1 < shift_plan.size() else ""
	if daily:
		return ""                          # Tagesflug: eine Karte, danach zurück ins Menü
	var ids := level_ids()
	var i := ids.find(current_level)
	return ids[i + 1] if i >= 0 and i + 1 < ids.size() else ""

func to_menu() -> void:
	var g := get_tree().current_scene
	if g != null and g.scene_file_path == GAME:
		store_clock()                  # Karriere-Uhr: abgebrochener Versuch zählt mit (vor dem Zurücksetzen der Modus-Schalter)
	menu_screen = ("editor:" + return_to_editor if return_to_editor != "" else "community") if community else ("levels" if not watch.is_empty() else "")
	watch = {}
	return_to_editor = ""
	editor_autopilot = false
	if shift:
		finish_shift()                 # Schicht abgebrochen: Wertung trotzdem sichern (nicht geflogene Karten zählen 0)
		shift = false
		shift_done = false
	var to_ot := overtime                # Sonderschicht unterbrochen: Der Lauf bleibt gesichert (Etappenbeginn bzw. Kreuzung), weiter im Menü der Sonderschicht
	overtime = false
	Save.write()                       # Statistiken (Serien, Auslieferungen …) sichern
	community = false
	if to_ot:
		get_tree().paused = false
		Sfx.set_thrust(0.0, 0.0)
		Sfx.stop_ambient()
		get_tree().change_scene_to_file(OT_MENU)
		return
	get_tree().paused = false
	Sfx.set_thrust(0.0, 0.0)
	Sfx.stop_ambient()
	get_tree().change_scene_to_file(MENU)

# --------------------------------------------------------------------------- Sonderschicht

## Fortschritt der Sonderschicht im Spielstand (Dienstgrad, Stufen, Bestenliste); legt ihn bei Bedarf an.
func ot_meta() -> Dictionary:
	if not (Save.data.get("overtime") is Dictionary):
		Save.data["overtime"] = {}
	var o: Dictionary = Save.data.overtime
	if not (o.get("meta") is Dictionary):
		o["meta"] = Overtime.default_meta()
	return o.meta

## Gesicherter Lauf ({} ohne).
func ot_saved() -> Dictionary:
	var o = Save.data.get("overtime", {})
	if not (o is Dictionary) or not (o.get("run", {}) is Dictionary):
		return {}
	var r: Dictionary = o.get("run", {})
	return r if int(r.get("version", 0)) == 1 and String(r.get("phase", "")) in ["cross", "halt", "fly"] else {}

func ot_save() -> void:
	ot_meta()
	Save.data.overtime["run"] = ot.duplicate(true)
	Save.write()

func ot_unlocked() -> bool:
	return Save.debug or Save.ot_early() or Save.sectors_done(level_ids(), Overtime.UNLOCK_SECTORS)

func _ot_enter() -> void:
	watch = {}
	shift = false
	daily = false
	practice = true                    # schützt die Karriere (kein Fortsetzen-Eintrag, kein Game-Over-Rücksetzen)
	community = false
	overtime = true

## Neuen Lauf beginnen (Code ungültig: zufälliger Seed) und zur ersten Kreuzung.
func start_overtime(code: String, length: String, license_id: String, stage: int) -> void:
	var seed := Overtime.seed_of(code)
	if seed < 0:
		var rng := RandomNumberGenerator.new()
		rng.randomize()
		seed = Overtime.seed_of(Overtime.random_code(rng))
	_ot_enter()
	ot = Overtime.new_run(seed, length, license_id, stage, ot_meta())
	ot_save()
	get_tree().change_scene_to_file(OT_STOP)

## Gesicherten Lauf fortsetzen: an der Kreuzung bzw. im Halt, oder die unterbrochene Etappe von vorn (Stand zu ihrem Beginn).
func resume_overtime() -> bool:
	var s := ot_saved()
	if s.is_empty():
		return false
	_ot_enter()
	ot = s.duplicate(true)
	if String(ot.phase) == "fly" and level_ids().has(String(ot.level)):
		ot_begin_etappe()
	else:
		if String(ot.phase) == "fly":
			ot.phase = "cross"
		get_tree().change_scene_to_file(OT_STOP)
	return true

## Einstiegswerte der Etappe aus dem Zustand (Taxis, Sprit, Guthaben, mitfahrender Fahrgast, Seed der Etappe).
func ot_prepare() -> void:
	lives = clampi(int(ot.get("lives", Overtime.START_TAXIS)), 1, Overtime.MAX_TAXIS)
	entry_fuel = maxf(Tuning.MIN_START_FUEL, float(ot.get("fuel", Tuning.FUEL_MAX)))
	entry_credits = maxf(0.0, float(ot.get("credits", 0.0)))
	carry_passenger = ot.get("carry", {}) if ot.get("carry", {}) is Dictionary else {}
	run_seed = absi(("%d:run:%d" % [int(ot.get("seed", 0)), int(ot.get("etappe", 0))]).hash()) % 1000000007

func ot_begin_etappe() -> void:
	ot_prepare()
	start_level(String(ot.level))

## Neustart der Etappe (R, Pausenmenü): zurück auf den Stand zu Etappenbeginn – auch die Taxis, kostenlos.
func ot_restart() -> void:
	var s := ot_saved()
	if s.is_empty() or String(s.get("phase", "")) != "fly":
		return
	ot = s.duplicate(true)
	ot_begin_etappe()

## Lauf beendet (geschafft oder kein Taxi mehr): sofort werten und den gesicherten Lauf löschen; das Finale zeigt `ot_last`.
func ot_close() -> void:
	if ot.is_empty() or bool(ot.get("closed", false)):
		return
	var rec := Overtime.record(ot_meta(), ot, Daily.today(), Save.slot_name())
	ot["closed"] = true
	ot_last = {"state": ot.duplicate(true), "rec": rec}
	Save.data.overtime["run"] = {}
	Save.write()

## Lauf aufgeben (Menü der Sonderschicht): zählt wie verloren, mit den bis dahin geflogenen Etappen.
func ot_abandon() -> void:
	var s := ot_saved()
	if s.is_empty():
		return
	ot = s.duplicate(true)
	ot.phase = "done"
	Overtime.fail(ot, float(ot.get("credits", 0.0)))
	ot_close()

func to_overtime_finale() -> void:
	ot_close()
	overtime = false
	community = false
	get_tree().paused = false
	Sfx.set_thrust(0.0, 0.0)
	Sfx.stop_ambient()
	get_tree().change_scene_to_file(OT_FINALE)

## Entwicklung: Sonderschicht direkt öffnen (--ot=cross|halt|fly|finale|menu, dazu --ot-len=, --ot-seed=, --ot-etappe=, --ot-perks=a,b, --ot-curses=a,b,
## --ot-credits=, --ot-xp=, --ot-level=, --ot-lic=). Schreibt nichts in den Spielstand (Save.dev_session).
func dev_overtime(args: PackedStringArray) -> void:
	var what := "cross"
	var length := "short"
	var code := "GRAVF7"
	var etappe := 0
	var perks_s := ""
	var curses_s := ""
	var credits := -1.0
	var level := ""
	var lic := "standard"
	for a in args:
		if a.begins_with("--ot="):
			what = a.substr(5)
		elif a.begins_with("--ot-len="):
			length = a.substr(9)
		elif a.begins_with("--ot-seed="):
			code = a.substr(10)
		elif a.begins_with("--ot-etappe="):
			etappe = maxi(0, int(a.substr(12)) - 1)
		elif a.begins_with("--ot-perks="):
			perks_s = a.substr(11)
		elif a.begins_with("--ot-curses="):
			curses_s = a.substr(12)
		elif a.begins_with("--ot-credits="):
			credits = float(a.substr(13))
		elif a.begins_with("--ot-xp="):
			ot_meta()["xp"] = int(a.substr(8))
		elif a.begins_with("--ot-lic="):
			lic = a.substr(9)
		elif a.begins_with("--ot-level="):
			level = resolve_level(a.substr(11))
	if what == "menu":
		if args.has("--ot-board"):                    # Beispiel-Bestenliste (nur Ansicht)
			var m := ot_meta()
			var b: Array = []
			for i in 7:
				b.append({"score": 98000 - i * 9100, "code": Overtime.code_of(1000 + i * 777), "date": "2026-11-21", "name": ["floppi", "Spielstand 2", "Nachtflug", "Testpilot mit sehr langem Namen", "floppi", "Alex", "Kim"][i],
					"license": ["standard", "racer", "tank", "saver", "charmer", "gambler", "standard"][i], "stage": [0, 2, 0, 1, 0, 3, 0][i], "flown": 9 - (i % 3), "of": 9, "won": i % 3 == 0})
			m["best"] = {"short": b, "medium": [], "long": []}
		get_tree().change_scene_to_file(OT_MENU)
		return
	_ot_enter()
	ot = Overtime.new_run(maxi(0, Overtime.seed_of(code)), length, lic, 0, ot_meta())
	var ids := level_ids()
	for e in mini(etappe, Overtime.total(ot) - (0 if what == "finale" else 1)):
		var os := Overtime.offers(ot, ids)
		Overtime.choose(ot, os[0])
		Overtime.etappe_done(ot, {"points": 400 + 60 * e, "bonus": 150, "credits": float(ot.credits) + 600.0, "lives": ot.lives, "stars": 1})
		if String(ot.phase) == "halt" and what != "halt":
			Overtime.leave_halt(ot)
	for p in perks_s.split(",", false):
		Overtime._add_perk(ot, p)
	if credits >= 0.0:
		ot.credits = credits
	if what == "halt" and String(ot.phase) != "halt":
		ot.phase = "halt"
		ot.halts = maxi(1, int(ot.halts))
	if what == "finale":
		ot.done = int(ot.etappe) >= Overtime.total(ot)
		ot.phase = "done"
		if not ot.done:
			Overtime.fail(ot, float(ot.credits))
		to_overtime_finale()
		return
	if what == "fly":
		var os2 := Overtime.offers(ot, ids)
		var o: Dictionary = os2[0].duplicate(true)
		if level != "":
			o.level = level
		if curses_s != "":
			o.curses = Array(curses_s.split(",", false))
		Overtime.choose(ot, o)
		ot_begin_etappe()
		return
	get_tree().change_scene_to_file(OT_STOP)

## Nach der Nachtschicht: eigenes Finale (Feierabend im Depot) mit der Abrechnung, danach zurück ins Menü.
func to_shift_finale() -> void:
	shift = false
	shift_done = false
	community = false
	Save.write()
	get_tree().paused = false
	Sfx.set_thrust(0.0, 0.0)
	Sfx.stop_ambient()
	get_tree().change_scene_to_file("res://src/ui/shift_finale.tscn")

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
var _clicks: Array = []             # Dev: --click=x,y@frame (Viewport-Koordinaten, Bewegung + Linksklick), --hover=x,y@frame (nur Bewegung)
var _frame := 0

func _ready() -> void:
	community_store().game_version = VERSION
	Save.debug = Settings.values.debug
	if DisplayServer.get_name() != "headless":          # Runde 86: Schnee-Ebene über allen Szenen (sichtbar nur an den Schneetagen)
		var layer := CanvasLayer.new()
		layer.layer = 110
		var snow := Control.new()
		snow.set_script(load("res://src/ui/snow_view.gd"))
		layer.add_child(snow)
		add_child(layer)
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
			Settings.lang_override = a.substr(7)
			Loc.set_language(a.substr(7))
		if a.begins_with("--shot="):
			_shot = a.substr(7)
		elif a.begins_with("--frames="):
			_shot_frame = int(a.substr(9))
		elif a.begins_with("--click=") or a.begins_with("--hover="):
			var cp := a.substr(8).split("@")
			var xy := cp[0].split(",")
			_clicks.append([Vector2(float(xy[0]), float(xy[1])), int(cp[1]), a.begins_with("--click=")])
		elif a.begins_with("--press="):
			var parts := a.substr(8).split("@")
			_presses.append([parts[0], int(parts[1])])

func _process(_d: float) -> void:
	if _shot == "" and _presses.is_empty() and _clicks.is_empty():
		return
	_frame += 1
	for c in _clicks:
		if c[1] == _frame:
			var mm := InputEventMouseMotion.new()
			mm.position = c[0]
			mm.global_position = c[0]
			Input.parse_input_event(mm)
			if not c[2]:
				continue                     # --hover: nur den Zeiger bewegen (Bilder ohne Tooltip unter dem Zeiger)
			var mb := InputEventMouseButton.new()
			mb.button_index = MOUSE_BUTTON_LEFT
			mb.position = c[0]
			mb.global_position = c[0]
			mb.pressed = true
			Input.parse_input_event(mb)
			var mu := mb.duplicate() as InputEventMouseButton
			mu.pressed = false
			Input.parse_input_event(mu)
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
