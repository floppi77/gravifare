extends Node2D
## Spielszene: verbindet Eingabe, Run-Logik, Darstellung, Kamera und HUD.
## Aufruf mit Level: godot --path . -- --level=s1_01  (Screenshot: --shot=pfad.png --frames=N)

var level_path := ""
var run := Run.new()
var paused := false
var gear_on := false
var restart_timer := 0.0
var assist: Node2D
const RESTART_CONFIRM_MS := 2000
var restart_armed_until := 0           # Zeitpunkt (ms), bis zu dem ein zweiter Neustart-Druck gilt
var cam_off := Vector2.ZERO
var shake := 0.0
var near_cd := 0.0
var slowmo_left := 0.0
var completion_saved := false
const TV := preload("res://src/game/transition_view.gd")
const Stage := preload("res://src/core/stage.gd")
var replay: Replay = null              # Aufzeichnung des laufenden Levels (Replay-Fundament)
var arrive_path := PackedVector2Array()   # hindernisfreier Einflug-Pfad (Pathing.arrival_path)
var trans_t := -1.0              # Zeitachse des Levelwechsels (siehe transition_view.gd), < 0 = inaktiv
var next_id := ""
var arriving := false
var arrive_done := false
var arrive_start := Vector2.ZERO
var arrive_end := Vector2.ZERO
var arrive_prev := Vector2.ZERO

@onready var world: Node2D = $World
@onready var taxi: Node2D = $World/Taxi
@onready var cam: Camera2D = $Camera
@onready var hud: Control = $Hud/Root
@onready var bg: Control = $Backdrop/Bg
@onready var world_tiles: Node2D = $World/Tiles
@onready var props: Node2D = $World/Props
var tags: Node2D                                    # Kennzeichen VIP/Notfall (passenger_tags.gd)
@onready var fx: Node2D = $World/Fx
@onready var trans: Control = $Trans/Root
var dark: Control
var tutorial: Tutorial = null          # Tutorial-Regie (nur im Tutorial-Level)
var spot: Control = null
var clip: IntroClip = null              # laufender Einspieler (Erklärvideo zu neuen Spielelementen)
var clip_pending := ""                 # Einspieler, der nach Funkspruch/Ankunft startet
var clip_delay := 0.0
var script_inputs: Array = []
var ghost: Node2D = null
var ambient: Node2D = null
var level_style: Node2D = null         # Optik einzelner Level (Neon, Glas), siehe level_style.gd
var entry_carry := {}                  # Ausgangs-Fahrgast, der in diesem Level ausgestiegen ist (für den Neustart)
var autopilot: Bot = null
var debug_input := Vector2.INF   # --debug-input=x,y erzwingt konstanten Schub (Screenshots)

func _ready() -> void:
	if Flow.current_level == "":
		Flow.current_level = "s1_01"
	level_path = Flow.level_path(Flow.current_level)
	var unlit := CanvasItemMaterial.new()
	unlit.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	props.material = unlit
	taxi.material = unlit
	assist = Node2D.new()                      # Landeassistent am Taxi (siehe landing_assist.gd)
	assist.set_script(load("res://src/game/landing_assist.gd"))
	assist.material = unlit
	world.add_child(assist)
	_setup_look()
	_fit_layers()
	get_viewport().size_changed.connect(_fit_layers)
	Input.joy_connection_changed.connect(_on_joy_connection)
	load_level(level_path)
	for hold in OS.get_cmdline_user_args():
		if hold.begins_with("--hold-action="):          # Dev: eine Eingabeaktion dauerhaft gedrückt halten (z. B. thrust_right), um die Steuerung ohne Hand zu prüfen
			Input.action_press(hold.substr(14))
	if Flow.daily and DayShift.mirrors_screen(Flow.daily_rule):
		_enable_mirror_view()                  # Tagschicht-Regel Spiegelwelt: das ganze Bild wird gespiegelt
	_release_carried()                         # Fortsetzen: Der gespeicherte Ausgangs-Fahrgast steigt aus und zahlt (sonst ginge sein Fahrpreis verloren)
	if Flow.daily and autopilot == null and not OS.get_cmdline_user_args().has("--autopilot") and not OS.get_cmdline_user_args().has("--no-brief"):
		_open_briefing()                       # Tagschicht: Regel und Ziel stehen vor dem Start im Bild, erst A/Enter startet
	elif Flow.daily:
		hud.flash_message(tr("MSG_DAILY") % [Flow.daily_date, tr("DAY_RULE_" + Flow.daily_rule), tr("DAY_GOAL_" + Flow.daily_goal)], 8.0)
	elif Flow.community:
		hud.flash_message(tr("MSG_COMMUNITY"), 4.0)
	elif Flow.practice:
		hud.flash_message(tr("MSG_PRACTICE"), 4.0)
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--debug-input="):
			var xy := a.substr(14).split(",")
			debug_input = Vector2(float(xy[0]), float(xy[1]))
			gear_on = false
			run.sim.state = TaxiSim.State.FLYING
			run.sim.landed_pad = {}
	if OS.get_cmdline_user_args().has("--debug-squash") and run.actor != null:    # Dev: Taxi senkt sich auf den wartenden Fahrgast
		var sp: Dictionary = run.actor.pad
		run.sim.state = TaxiSim.State.FLYING
		run.sim.landed_pad = {}
		run.sim.gear = 1.0
		run.sim.pos = Vector2(run.actor.x, sp.row * Tuning.TILE - 46.0)
		run.sim.vel = Vector2(0, 30)
		gear_on = true
		debug_input = Vector2(0, 0)
		taxi.sync_state()
		taxi.reset_physics_interpolation()
		assist.sync_state()
		assist.reset_physics_interpolation()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--debug-pump="):          # Dev: Zapfsäule auf Schadensstufe N setzen (3 = Explosion)
			run.pump_touches = int(a.substr(13))
			if run.pump_touches >= 3:
				run.pump_boom_t = 0.05
	if OS.get_cmdline_user_args().has("--debug-destroy"):     # Dev: Taxi sofort zerstören (Leben-/Game-Over-Anzeige)
		run.sim.hull = 0.0
		run.sim.state = TaxiSim.State.DESTROYED
	if OS.get_cmdline_user_args().has("--autopilot") or (Flow.community and Flow.editor_autopilot):
		run.extras_enabled = false      # Autopilot (Dev bzw. Testflug im Level-Editor) fährt nur die Auftragskette
		autopilot = Bot.new(run, Flow.community and Flow.editor_autopilot)
	for ua in OS.get_cmdline_user_args():
		if ua.begins_with("--skip-time="):          # Dev: Spielzeit vorspulen (Taxi bleibt stehen), z. B. für Screenshots von Meteoriten
			for i in int(float(ua.substr(12)) / Tuning.TICK):
				run.step(Vector2.ZERO, false)
	if OS.get_cmdline_user_args().has("--debug-patient-lost"):      # Dev: „Patient verloren“-Effekt ansehen
		_patient_lost({"name": "Mika", "fee": 123.0})
	if OS.get_cmdline_user_args().has("--debug-medical") and run.actor != null:      # Dev: wartenden Fahrgast als Patient auf der Trage zeigen
		run.actor.medical = true
	for ua2 in OS.get_cmdline_user_args():
		if ua2.begins_with("--dark="):               # Dev: Dunkelheit in jedem Level ansehen
			run.level.dark = float(ua2.substr(7))
			dark.setup(run, cam)
	dark.light_k = headlight_k()
	if OS.get_cmdline_user_args().has("--debug-extra"):      # Dev: Zusatzfahrgast sofort
		run.extra_timer = 0.3
	if OS.get_cmdline_user_args().has("--no-hud"):      # Dev: Bild ohne HUD (Vorschaubilder der Levelauswahl)
		$Hud.visible = false
	if OS.get_cmdline_user_args().has("--debug-complete"):
		run.exit_open = true
		run.level.exit_open = true
		run.sim.state = TaxiSim.State.FLYING
		run.sim.landed_pad = {}
		run.sim.pos = run.level.exit_rect().get_center()
	_queue_clip(0.9)                           # Szenenstart (Menü): Einspieler nach kurzer Pause; bei Übergangsflügen in _end_transition
	for ua3 in OS.get_cmdline_user_args():
		if ua3.begins_with("--clip="):           # Dev: Einspieler sofort zeigen
			clip_pending = ua3.substr(7)
			clip_delay = 0.3
	if OS.get_cmdline_user_args().has("--debug-bay"):        # Dev: Werkstatt nach dem Sektor sofort zeigen
		_open_bay.call_deferred()
	if OS.get_cmdline_user_args().has("--debug-open-exit"):
		run.exit_open = true
		run.level.exit_open = true
		props.door = 1.0

## HUD und Überblendung liegen auf der zentrierten 640×360-Fläche; breitere/höhere Fenster zeigen links/rechts bzw. oben/unten nur den Hintergrund.
func _fit_layers() -> void:
	var m := Stage.margin(self)
	$Hud.offset = m
	$Trans.offset = m

## Bildcharakter: HDR-Bloom auf Lichter/Abgase/Neon, leichte Farbkorrektur und Vignette für Tiefe.
func _setup_look() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_CANVAS
	env.glow_enabled = true
	env.glow_hdr_threshold = 0.92
	env.glow_intensity = 0.55
	env.glow_strength = 1.0
	env.glow_bloom = 0.0
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var layer := CanvasLayer.new()
	layer.layer = 5
	var rect := ColorRect.new()
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := Shader.new()
	sh.code = "shader_type canvas_item;\nvoid fragment() {\n\tvec2 u = (UV - 0.5) * vec2(1.0, 1.1);\n\tfloat d = dot(u, u);\n\tCOLOR = vec4(0.0, 0.0, 0.04, smoothstep(0.2, 0.62, d) * 0.42);\n}\n"
	var mat := ShaderMaterial.new()
	mat.shader = sh
	rect.material = mat
	layer.add_child(rect)
	add_child(layer)

## Scheinwerfer der Werkstatt: nur in der Karriere. Nachtschicht, Tagschicht und Community-Level fliegen ohne ihn, damit Wertungen vergleichbar bleiben.
## Dev: `--ws-light=N` setzt die Stufe für Vergleichsbilder, ohne den Spielstand zu ändern.
func headlight_k() -> float:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--ws-light="):
			return Workshop.light_k_for(int(a.get_slice("=", 1)))
	if Flow.shift or Flow.daily or Flow.community:
		return 1.0
	return Workshop.light_k(Save.data)

## Level neu starten: Der Ausgangs-Fahrgast des Vorlevels steigt erneut aus, sein Fahrpreis geht durch den Neustart nicht verloren.
func restart_level() -> void:
	load_level(level_path)
	Flow.carry_passenger = entry_carry
	_release_carried()

func load_level(path: String) -> void:
	var lvl: LevelData = Flow.community_store().load_runtime(Flow.current_level) if Flow.community else LevelData.load_file(path)
	if lvl == null:
		push_error("Level konnte nicht geladen werden: " + path)
		return
	run.shift_mode = Flow.shift
	run.types_enabled = not (Flow.shift or Flow.daily)              # VIP und Notfall nur in Karriere und Community-Leveln
	if Flow.shift:
		NightShift.apply(lvl, Flow.shift_index(), Flow.shift_date)          # Schwerkraft, Dunkelheit und Aufträge der Schicht
		run.extras_enabled = false                                                       # nur Pflichtfahrgäste
	elif Flow.daily:
		lvl = DayShift.apply(lvl, Flow.daily_rule, Flow.daily_date)          # Tagschicht: immer hell, dazu die Tagesregel (bei „Spiegelwelt“ ein gespiegeltes Level)
		lvl.jobs = Daily.jobs_for(lvl, Flow.daily_date)
		run.patience_k = DayShift.patience_k(Flow.daily_rule)
		run.fuel_cap = DayShift.fuel_cap(Flow.daily_rule)
	run.start(lvl, Flow.entry_fuel, Flow.entry_credits, Flow.run_seed + lvl.number * 7919)
	run.lives = Flow.lives
	var mods := Workshop.mods_for({}) if Flow.daily or Flow.community else Workshop.mods(Save.data)      # Tagschicht und Community-Level: Serientaxi, damit Ergebnisse vergleichbar sind
	if Flow.daily:
		mods = DayShift.mods(Flow.daily_rule, mods)
	run.sim.apply_mods(mods)
	replay = Replay.new()
	replay.begin(lvl.id, Flow.run_seed + lvl.number * 7919, Flow.entry_fuel, Flow.entry_credits, Flow.carry_passenger, run.extras_enabled)
	replay.mods = mods
	replay.sig = Replay.sig_of(lvl)
	Music.play_theme(Music.theme_for_level(lvl.number))
	Music.duck(0.0)
	Sfx.play_ambient(lvl.sector)
	gear_on = run.sim.gear_cmd
	if dark == null:
		var dl := CanvasLayer.new()
		dl.layer = 4                                       # über der Spielwelt, unter dem HUD
		add_child(dl)
		dark = Control.new()
		dark.set_script(load("res://src/game/dark_view.gd"))
		dl.add_child(dark)
	dark.setup(run, cam)
	world_tiles.setup(run)
	props.setup(run)
	if tags == null:
		tags = Node2D.new()
		tags.set_script(load("res://src/game/passenger_tags.gd"))
		tags.material = props.material                                  # wie Figur und Betrag (unbeleuchtet)
		props.get_parent().add_child(tags)
		props.get_parent().move_child(tags, props.get_index() + 1)     # über Figur und Betrag
	tags.setup(run)
	if level_style == null:
		level_style = Node2D.new()
		level_style.set_script(load("res://src/game/level_style.gd"))
		world.add_child(level_style)
		world.move_child(level_style, world_tiles.get_index() + 1)      # über dem Fels, unter Requisiten, Taxi und Gefahren
	level_style.setup(lvl)
	if ambient == null:
		ambient = Node2D.new()
		ambient.set_script(load("res://src/game/ambient_view.gd"))
		world.add_child(ambient)
	ambient.setup(lvl)
	fx.setup(run)
	taxi.bind(run.sim)
	assist.bind(run)
	taxi.sync_state()
	taxi.reset_physics_interpolation()
	assist.sync_state()
	assist.reset_physics_interpolation()
	hud.bind(run)
	_setup_ghost(lvl)
	if autopilot != null:
		run.extras_enabled = false      # Dev-Autopilot fährt nur die Auftragskette
		autopilot = Bot.new(run, Flow.community and Flow.editor_autopilot)
	hud.paused = false
	paused = false
	near_z = 0.0
	restart_timer = 0.0
	completion_saved = false
	_setup_camera()
	bg.setup(lvl)
	_setup_tutorial(lvl)

## Geisterfahrt: Taxi der eigenen Bestzeit mitfliegen lassen (abschaltbar; nicht im Tutorial, in der Nachtschicht oder im Dev-Autopilot).
func _setup_ghost(lvl: LevelData) -> void:
	if ghost == null:
		ghost = Node2D.new()
		ghost.set_script(load("res://src/game/ghost_view.gd"))
		world.add_child(ghost)
		world.move_child(ghost, taxi.get_index())
	var best := {} if lvl.tutorial or Flow.shift or Flow.daily or Flow.community or autopilot != null or not Settings.values.ghost or not Save.is_completed(lvl.id) else Replay.load_best(lvl.id, Save.slot)       # nur Geister aus diesem Speicherplatz und nur für schon geschaffte Level
	if best.has("sig") and String(best.sig) != Replay.sig_of(lvl):
		best = {}                        # das Level wurde nach diesem Lauf geändert
	var trace: Array = best.get("trace", [])
	if Flow.daily and Settings.values.ghost and autopilot == null:
		trace = Replay.load_day(Save.slot, Flow.daily_date)          # Tagschicht: der beste Flug von heute fliegt als Geist mit
	ghost.bind(run, trace)

## Tutorial-Sprecher: Clip der Zentrale abspielen (Fahrgast-Zurufe schweigen währenddessen); gibt Länge und Text zurück.
func tutorial_speak(key: String) -> Dictionary:
	var text := Sfx.line_text("i0", key)
	var spoke := Sfx.play_voice("i0", key)
	var length := Sfx.voice_player.stream.get_length() if spoke and Sfx.voice_player.stream != null else maxf(2.5, float(text.length()) * 0.07)
	Sfx.narration_until = Time.get_ticks_msec() + int((length + 0.4) * 1000.0)
	return {"len": length, "text": text}

func tutorial_line(key: String) -> String:
	return Sfx.line_text("i0", key)

func tutorial_voice_stop() -> void:
	Sfx.voice_player.stop()
	Sfx.narration_until = 0

func tutorial_ping() -> void:
	Sfx.play("perfect", -6.0)

func tutorial_voice_pause(p: bool) -> void:
	Sfx.voice_player.stream_paused = p

func tutorial_narrating() -> bool:
	return Time.get_ticks_msec() < Sfx.narration_until

func tutorial_mark_done() -> void:
	Save.data["tutorial_done"] = true
	Save.write()

func tutorial_set_lives(n: int) -> void:
	Flow.lives = n

## Tutorial beendet: weiter ins erste Level (neuer Spielstand) oder zurück ins Menü.
func tutorial_finish() -> void:
	Sfx.set_thrust(0.0, 0.0)
	if Flow.tutorial_next != "":
		var nxt: String = Flow.tutorial_next
		Flow.tutorial_next = ""
		Flow.start_campaign(nxt)
	else:
		Flow.to_menu()

# ---------------------------------------------------------------- Einspieler (Erklärvideos zu neuen Spielelementen)
## Name des Einspielers dieses Levels (data/intros/index.json: Levelnummer → Name), "" wenn es keinen gibt.
func level_clip_key() -> String:
	if run.level.tutorial:
		return ""
	var f := FileAccess.open("res://data/intros/index.json", FileAccess.READ)
	var idx = JSON.parse_string(f.get_as_text()) if f != null else null
	if typeof(idx) != TYPE_DICTIONARY:
		return ""
	return String(idx.get(str(run.level.number), ""))

## Einspieler dieses Levels vormerken, falls noch nicht gesehen.
func _queue_clip(delay: float, now := false) -> void:
	if not Settings.values.hints or Flow.shift or Flow.daily or Flow.community:
		return
	var k := level_clip_key()
	var seen: Array = Save.data.get("seen_clips", [])
	if k == "" or seen.has(k):
		return
	if now:
		start_clip(k)
		return
	clip_pending = k
	clip_delay = delay

## Einspieler abspielen (pausiert das Spiel); `force` ignoriert „schon gesehen“ (Wiederholung, Dev-Flag).
func start_clip(k: String) -> void:
	if clip != null:
		return
	var seen: Array = Save.data.get("seen_clips", [])
	if not seen.has(k) and not (Flow.shift or Flow.daily or Flow.community):      # nur die Karriere merkt „gesehen“: in den Schichten offen sind auch noch unbekannte Sektoren
		seen.append(k)
		Save.data["seen_clips"] = seen
		Save.write()
	var layer := CanvasLayer.new()
	layer.layer = 45                                       # über der Übergangsebene (40): der Einspieler startet beim Einflug
	layer.offset = Stage.margin(self)
	add_child(layer)
	var c := IntroClip.new()
	layer.add_child(c)
	if not c.start(self, k):
		layer.queue_free()
		return
	clip = c
	paused = true
	Sfx.set_thrust(0.0, 0.0)
	Haptics.stop()
	Music.duck(-8.0)
	c.finished.connect(func():
		clip = null
		layer.queue_free()
		paused = false
		Music.duck(0.0))

## Einspieler zu VIP und Notfall: nicht an ein Level gebunden, sondern beim ersten wartenden Fahrgast dieses Typs (Pflicht- oder Zusatzfahrgast).
const KIND_CLIPS := ["vip", "emergency"]
func _kind_clip_tick() -> void:
	if clip_pending != "" or clip != null or not Settings.values.hints or Flow.shift or Flow.daily or Flow.community or run.level.tutorial:
		return
	var seen: Array = Save.data.get("seen_clips", [])
	var waiting: Array = []
	if run.actor != null and run.phase == Run.Phase.WAITING:
		waiting.append(run.kind_of(run.current_job()))
	for e in run.extras:
		if int(e.state) == Run.ES.WAIT:
			waiting.append(run.kind_of(e.job))
	for k in KIND_CLIPS:
		if waiting.has(k) and not seen.has(k):
			clip_pending = k
			clip_delay = 0.8
			return

func _clip_tick(delta: float) -> void:
	_kind_clip_tick()
	if clip_pending == "" or clip != null or paused or trans_t >= 0.0 or run.result != Run.Result.RUNNING:
		return
	if Sfx.voice_player.playing:
		return                      # erst den Funkspruch zu Ende hören
	clip_delay -= delta
	if clip_delay <= 0.0:
		var k := clip_pending
		clip_pending = ""
		start_clip(k)

## Beleuchtungs-Ebene (Spotlight) bei Bedarf anlegen: Tutorial und Respawn-Hinweis.
func _ensure_spot() -> void:
	if spot != null:
		return
	var sl := CanvasLayer.new()
	sl.layer = 11                                          # über dem HUD, unter Pausemenü-Ebene
	add_child(sl)
	spot = Control.new()
	spot.set_script(load("res://src/game/spot_view.gd"))
	sl.add_child(spot)

var focus_on := false              # Respawn-Spot: Bildschirm dunkel bis auf das neue Taxi, bis das Taxi wieder etwas tut
var focus_gear := false

## Nach einem verlorenen Taxi: alles abdunkeln bis auf das neue Taxi, damit der Blick es findet. Das Licht bleibt, bis das Taxi
## wieder etwas tut (Schub, Fahrwerk oder Abheben), nicht für eine feste Zeit.
func _respawn_focus() -> void:
	if run.level.tutorial:
		return
	_ensure_spot()
	focus_on = true
	focus_gear = run.sim.gear_cmd

func _focus_tick(_delta: float) -> void:
	if spot == null or tutorial != null:
		return
	if focus_on:
		var acted := run.sim.state != TaxiSim.State.LANDED or run.sim.gear_cmd != focus_gear or Controls.thrust_vector().length() > 0.1 \
			or debug_input != Vector2.INF or autopilot != null or run.result != Run.Result.RUNNING or trans_t >= 0.0
		if acted:
			focus_on = false
			spot.set_spots([])
		else:
			var center := cam.get_screen_center_position()
			spot.fade_speed = 7.0
			spot.set_spots([Rect2(run.sim.pos - center + Stage.view(self) * 0.5 - Vector2(30, 26), Vector2(60, 52))])
	elif spot.amount <= 0.01:
		spot.fade_speed = 2.6

## Tutorial-Level: Beleuchtungs-Ebene und Regie anlegen (bei Neustart frisch).
func _setup_tutorial(lvl: LevelData) -> void:
	if tutorial != null:
		tutorial.game = null                  # beim Neustart nicht die Stimme der neuen Regie abschneiden
		tutorial.queue_free()
		tutorial = null
	if not lvl.tutorial:
		return
	_ensure_spot()
	spot.set_spots([])
	spot.say("", "")
	tutorial = Tutorial.new()
	add_child(tutorial)
	tutorial.setup(self, run, hud, spot, cam)

func _setup_camera() -> void:
	var sz := run.level.pixel_size()
	cam.limit_left = -100000
	cam.limit_top = -100000
	cam.limit_right = 100000
	cam.limit_bottom = 100000     # Begrenzung übernimmt _cam_target(); Offset (Vorausblick/Wackeln) darf kurz darüber
	cam.position_smoothing_enabled = false
	cam.process_callback = Camera2D.CAMERA2D_PROCESS_PHYSICS      # passt zur Physik-Interpolation (keine Warnung)
	cam.global_position = _cam_target()
	cam.reset_physics_interpolation()

func _cam_target() -> Vector2:
	var view := Stage.view(self)
	var sz := run.level.pixel_size()
	var p := run.sim.pos
	return Vector2(
		sz.x * 0.5 if sz.x <= view.x else clampf(p.x, view.x * 0.5, sz.x - view.x * 0.5),
		sz.y * 0.5 if sz.y <= view.y else clampf(p.y, view.y * 0.5, sz.y - view.y * 0.5))

var pause_menu: Control

func _set_paused(on: bool) -> void:
	paused = on
	hud.paused = on
	Music.duck(-8.0 if on else 0.0)
	Sfx.set_thrust(0.0, 0.0)
	Haptics.stop()
	_end_slowmo()
	if on:
		pause_menu = PauseMenu.new()
		pause_menu.game = self
		hud.add_child(pause_menu)
	elif pause_menu != null:
		pause_menu.queue_free()
		pause_menu = null

## Automatische Pause, wenn das Fenster den Fokus verliert (Alt-Tab, Overlay) oder der gerade benutzte Controller getrennt wird:
## Sprit, Geduld und Countdown sollen nicht weiterlaufen. Fortgesetzt wird nur von Hand (Pausenmenü).
func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		auto_pause()

func _on_joy_connection(_device: int, connected: bool) -> void:
	if not connected and Controls.last_device == "gamepad":
		auto_pause()

func auto_pause() -> bool:
	if paused or bay != null or clip != null or trans_t >= 0.0 or run == null or run.result != Run.Result.RUNNING:
		return false
	if autopilot != null or Save.dev_session or OS.get_cmdline_args().has("--write-movie"):
		return false                              # Testläufe und Trailer-Aufnahmen laufen ungestört weiter
	_set_paused(true)
	return true

var shot_busy := false
var day_ghost_score := -1          # Tagschicht: Wertung dieses Flugs, wenn er der beste des Tages ist (Geist wird nach dem Ende des Replays gesichert)

## Auswertung der Nachtschicht als Bild speichern: „JJMMTT_nachtschicht_name.png“ neben dem Spiel (sonst im Datenordner).
## Der Knopf wird dabei kurz ausgeblendet.
func _take_shift_shot() -> void:
	if shot_busy:
		return
	shot_busy = true
	hud.shot_hide = true
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	hud.shot_hide = false
	var fname := Shots.day_file_name(Daily.today(), Save.slot_name(), Save.slot) if Flow.daily else Shots.shift_file_name(Daily.today(), Save.slot_name(), Save.slot)
	var path := Shots.unique_path(Shots.target_dir(), fname)
	if img != null and img.save_png(path) == OK:
		Sfx.play("coin", -4.0)
		hud.shot_note = path.get_file()
		hud.shot_note_t = 6.0
		hud.flash_message(tr("MSG_SHOT_SAVED") % path, 6.0)
	else:
		hud.flash_message(tr("MSG_SHOT_FAIL"), 4.0)
	shot_busy = false

## Spiegelwelt: Ein Vollbild-Shader über allem (HUD, Einspieler, Pausemenü) spiegelt das fertige Bild horizontal. Mausereignisse werden entsprechend gespiegelt weitergegeben,
## damit Knöpfe dort reagieren, wo man sie sieht; der HUD rechnet seine Klickflächen mit `mouse_pos()` um.
var mirror_view := false

const MIRROR_SHADER := """
shader_type canvas_item;
uniform sampler2D screen : hint_screen_texture, filter_nearest;
void fragment() {
	COLOR = vec4(texture(screen, vec2(1.0 - SCREEN_UV.x, SCREEN_UV.y)).rgb, 1.0);
}
"""

func _enable_mirror_view() -> void:
	mirror_view = true
	hud.mirror_view = true
	var ml := CanvasLayer.new()
	ml.layer = 100
	add_child(ml)
	var rect := ColorRect.new()
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var sh := Shader.new()
	sh.code = MIRROR_SHADER
	var mat := ShaderMaterial.new()
	mat.shader = sh
	rect.material = mat
	ml.add_child(rect)

func _input(event: InputEvent) -> void:
	if mirror_view and event is InputEventMouse and not event.has_meta("gf_mirrored"):
		var m := event.duplicate() as InputEventMouse
		var w := get_viewport().get_visible_rect().size.x
		m.position = Vector2(w - m.position.x, m.position.y)
		m.global_position = Vector2(w - m.global_position.x, m.global_position.y)
		m.set_meta("gf_mirrored", true)
		get_viewport().set_input_as_handled()
		get_viewport().push_input(m, true)

## Briefing der Tagschicht (Regel, Ziel, Wertung, Serie, Belohnung); das Level steht, bis es bestätigt ist. Innerhalb einer Sitzung nur einmal je Start aus dem Menü (ein Neustart zeigt es nicht erneut).
var briefing := false

func _open_briefing() -> void:
	if Flow.daily_briefed:
		hud.flash_message(tr("MSG_DAILY") % [Flow.daily_date, tr("DAY_RULE_" + Flow.daily_rule), tr("DAY_GOAL_" + Flow.daily_goal)], 6.0)
		return
	var lang := TranslationServer.get_locale().substr(0, 2)
	var lname: String = run.level.names.get(lang, run.level.id)
	var stats: Dictionary = Save.data.stats
	hud.brief = {"rule": Flow.daily_rule, "goal": Flow.daily_goal, "sub": "Level %d · %s · %s" % [run.level.number, lname, NightShift.format_stamp(Flow.daily_date, 12, 0, lang).split(",")[0]],
		"target": run.time_target(), "streak": Daily.current_streak(stats, Flow.daily_date), "reward": DayShift.next_reward(stats, Save.data.get("unlocked", [])),
		"ghost": not Replay.load_day(Save.slot, Flow.daily_date).is_empty() and Settings.values.ghost}
	hud.briefing = true
	briefing = true

func _start_after_briefing() -> void:
	briefing = false
	hud.briefing = false
	Flow.daily_briefed = true
	Sfx.play("ui_ok", -4.0)
	hud.flash_message(tr("MSG_DAILY") % [Flow.daily_date, tr("DAY_RULE_" + Flow.daily_rule), tr("DAY_GOAL_" + Flow.daily_goal)], 6.0)

func _unhandled_input(event: InputEvent) -> void:
	if bay != null:
		return
	if briefing:
		if event.is_action_pressed("ui_accept") or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and hud.brief_btn.has_point(hud.event_pos(event))):
			get_viewport().set_input_as_handled()
			_start_after_briefing()
		elif event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause"):
			get_viewport().set_input_as_handled()
			Flow.to_menu()
		return
	if trans_t >= 0.0:
		# Levelwechsel: A/Enter/B/Esc überspringen die Sequenz bis zum Einblenden; sonst keine Eingabe
		if (event.is_action_pressed("ui_accept") or event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause")) and trans_t < TV.T_IN - 0.01:
			trans_t = TV.T_IN - 0.001
			radio_played = true
			radio_age = 1.0e6                  # die Warte-Bedingung in _process darf nicht greifen
			Sfx.voice_player.stop()
			Sfx.stop_long()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()     # vor einem möglichen Szenenwechsel
		if run.result == Run.Result.RUNNING:
			_set_paused(not paused)
		elif run.result == Run.Result.FAILED and not hud.game_over:
			pass        # Absturz-Sequenz läuft: nicht ins Menü springen (sonst ließe sich das verlorene Leben über „Fortsetzen“ zurückholen)
		else:
			Flow.to_menu()
	elif paused:
		return
	elif hud.shot_available() and (event.is_action_pressed("eject") or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and hud.shot_btn.has_point(hud.event_pos(event)))):
		get_viewport().set_input_as_handled()
		_take_shift_shot()
	elif event.is_action_pressed("ui_accept") and run.result == Run.Result.COMPLETE and completion_saved and hud.result_age >= 0.7:
		get_viewport().set_input_as_handled()     # vor einem Szenenwechsel: danach hat der Knoten keinen Viewport mehr
		if Flow.next_level_id() != "":
			if Workshop.due(run.level.number) and not Flow.shift:
				_open_bay()         # Sektor geschafft: erst in die Werkstatt
			else:
				_begin_transition()     # Ergebnisansicht bestätigt: Levelwechsel-Sequenz starten
		elif Flow.shift:
			Flow.to_shift_finale()  # Schicht geflogen: eigenes Finale der Nachtschicht, nicht das der Karriere
		elif hud.result.get("counted", false) and not Flow.daily and not Flow.community:
			Flow.to_finale()        # letztes Level geschafft: Finale und Abspann
		else:
			Flow.to_menu()
	elif hud.game_over:
		if event.is_action_pressed("ui_accept"):
			Flow.to_menu()
	elif event.is_action_pressed("eject"):
		if run.result == Run.Result.RUNNING and trans_t < 0.0:
			replay.mark_eject()
			if not run.eject():
				replay.events.pop_back()          # nichts passiert: auch nicht aufzeichnen
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("restart"):
		if run.level.tutorial and run.result != Run.Result.FAILED:
			pass                                  # Tutorial: R startet nicht die ganze Flugschule neu (bewusst geht das über das Pausenmenü)
		elif run.result == Run.Result.FAILED:
			_lose_life()
		elif Flow.shift:
			pass                                  # Nachtschicht: ein Versuch, kein Neustart einer Karte
		elif run.result == Run.Result.RUNNING and not run.level.tutorial and Time.get_ticks_msec() > restart_armed_until:
			# freiwilliger Neustart mitten im Level: erst nach zweitem Druck (R liegt direkt neben E = Rauswerfen)
			restart_armed_until = Time.get_ticks_msec() + RESTART_CONFIRM_MS
			var rk := "kb" if Controls.last_device == "keyboard" else "pad"
			hud.flash_message(tr("MSG_RESTART_CONFIRM") % Controls.slot_label("restart", rk, 0), RESTART_CONFIRM_MS / 1000.0)
		else:
			restart_armed_until = 0
			restart_level()
	elif event.is_action_pressed("gear") and not paused and Controls.gear_toggle:
		if tutorial == null or not tutorial.locked:
			gear_on = not gear_on

## Stärke 0..1 des Schubbrummens: nur im Flug und nur für Schub über dem, was das Taxi zum Schweben braucht.
## Schweben, kleine Korrekturen und ein Stick, der im Stand leicht ausschlägt, brummen nicht.
func _thrust_rumble() -> float:
	var s := run.sim
	if s.state != TaxiSim.State.FLYING or s.fuel <= 0.0:
		return 0.0
	var hover := clampf(run.level.gravity / maxf(s.up_power(), 1.0), 0.0, 0.95)
	var main := clampf((taxi.flame_main - hover - 0.15) / maxf(1.0 - hover - 0.15, 0.05), 0.0, 1.0)
	var side := clampf((absf(taxi.flame_side) - 0.6) / 0.4, 0.0, 1.0) * 0.5
	return maxf(main, side)

func _physics_process(_delta: float) -> void:
	if paused or briefing:
		return
	if trans_t >= 0.0:
		_arrival_tick()
		return
	var v := Controls.thrust_vector()
	if debug_input != Vector2.INF:
		v = debug_input
	if autopilot != null:
		var cmd := autopilot.decide()
		v = cmd[0]
		gear_on = cmd[1]
	if not Controls.gear_toggle:
		gear_on = Input.is_action_pressed("gear")
	if tutorial != null and tutorial.locked:
		v = Vector2.ZERO                       # Tutorial: erst erklären, dann fliegen
		gear_on = run.sim.gear_cmd             # … und das Fahrwerk bleibt, wie es ist
	if not script_inputs.is_empty():
		var cmd: Dictionary = script_inputs.pop_front()
		v = cmd.v
		gear_on = cmd.g
	var gear_before := run.sim.gear_cmd
	v = Replay.quantize(v)
	if run.result == Run.Result.RUNNING:
		replay.add(v, gear_on)
	run.step(v, gear_on)
	replay.sample(run.sim.pos, run.sim.tilt)
	if run.sim.gear_cmd != gear_before:
		Sfx.play("gear")
	if bay == null:                          # in der Werkstatt steuert sie den Triebwerksklang selbst
		var flying := run.result == Run.Result.RUNNING
		Sfx.set_thrust(taxi.flame_main if flying else 0.0, absf(taxi.flame_side) if flying else 0.0)
	var summary: bool = hud.summary_visible()        # Schicht-Auswertung im Bild: kein Triebwerk, kein Tankalarm, keine tickende Uhr mehr (Musik und Raumklang laufen weiter)
	if summary:
		Sfx.set_thrust(0.0, 0.0)
	if run.sim.fuel < 25.0 and run.sim.fuel > 0.0 and run.result == Run.Result.RUNNING and not summary:
		warn_cd -= Tuning.TICK
		if warn_cd <= 0.0:
			Sfx.play("warn", -6.0)
			warn_cd = lerpf(0.12, 1.0, clampf(run.sim.fuel / 25.0, 0.0, 1.0))        # je leerer der Tank, desto schneller piept es
	else:
		warn_cd = 0.0
	_exit_clock_tick()
	taxi.sync_state()
	assist.sync_state()
	if run.result == Run.Result.RUNNING:
		Haptics.thrust(_thrust_rumble())
		_check_near_miss()
		_music_tick()
		_hint_tick()
		_field_feedback()
	for e in run.log:
		_on_event(e)
	if not pending_call.is_empty() and Time.get_ticks_msec() >= Sfx.narration_until:
		var pc := pending_call
		pending_call = {}
		_on_event(pc)
	cam.global_position = _cam_target()
	_cam_feel()
	if run.result == Run.Result.COMPLETE and not completion_saved and run.level.tutorial:
		completion_saved = true
		Sfx.set_thrust(0.0, 0.0)
		tutorial.complete()
	if run.result == Run.Result.COMPLETE and not completion_saved:
		completion_saved = true
		Save.note_max("best_streak", run.best_streak)
		var prev_best := Save.community_best_time(Flow.current_level) if Flow.community else Save.best_time(Flow.current_level)
		# Ohne eine einzige Beförderung (z. B. Leerlauf bis zum Countdown) zählt das Level nicht als geschafft.
		var counted := run.delivered > 0 or run.extras_delivered > 0
		var med := run.medals() if counted else {"time": false, "clean": false, "pro": false}
		hud.result = {"counted": counted, "time": run.level_time, "target": run.time_target(), "best": prev_best, "medals": med, "money_target": run.money_target(), "earned": run.earned, "repair": run.repair_cost, "taxi_fees": run.taxi_fees, "missed_fees": run.missed_fees, "net": run.earned - run.repair_cost - run.taxi_fees - run.missed_fees, "delivered": run.delivered, "jobs": run.level.jobs.size(), "extras": run.extras_delivered, "balance": run.money}
		hud.result_age = 0.0
		hud.next_exists = Flow.next_level_id() != ""
		var score := run.level_score() if counted else 0
		hud.result["score"] = score
		hud.result["best_score"] = maxi(score, Save.community_best_score(Flow.current_level) if Flow.community else Save.best_score(Flow.current_level))
		if Flow.shift:
			counted = false                  # Nachtschicht: eigene Aufträge, zählt nur für die Schichtnote
			var mr := NightShift.map_result(run.shift_stats() if Flow.dev_shift_quality < 0.0 else Flow.dev_fake_map_stats(RandomNumberGenerator.new(), Flow.dev_shift_quality))      # Dev: --shift-quality ersetzt auch die letzte Karte durch Beispielwerte
			mr["id"] = Flow.current_level
			mr["time"] = run.level_time if Flow.dev_shift_quality < 0.0 else 150.0
			mr["number"] = run.level.number
			mr["names"] = run.level.names
			Flow.shift_results.append(mr)
			Flow.shift_credits = run.money if Flow.dev_shift_quality < 0.0 else 4200.0 + Flow.dev_shift_quality * 9000.0
			hud.result["shift"] = mr
			hud.result["shift_index"] = Flow.shift_index() + 1
			hud.result["shift_final"] = Flow.finish_shift() if Flow.next_level_id() == "" else {}
		elif Flow.community:
			if counted and not Flow.editor_autopilot and Flow.community_store().exists(Flow.current_level):      # Community-Level: nur eigene Bestzeit und Bestwert, keine Karriere, keine Medaillen, kein Geist (Autopilot-Testflug zählt nicht)
				Save.complete_community(Flow.current_level, run.level_time, score)
			elif counted and _solved_by_hand():
				Flow.note_editor_run(Flow.current_level, run.level_time, score)      # Entwurf: erst beim Speichern in den Spielstand (sonst sammelten verworfene Entwürfe Einträge)
			if _solved_by_hand():                                           # Testflug aus dem Editor, selbst und vollständig geflogen: erst damit lässt sich das Level speichern
				Flow.community_store().mark_solved(Flow.current_level)
				hud.result["solved"] = true
			counted = false
		elif Flow.daily:
			# Tagschicht: zählt nur für Tagesziel, Medaille, Serie und Geist, nicht für Level und Medaillen der Karriere
			var ds := run.day_stats()
			var gscore := DayShift.goal_score(Flow.daily_goal, ds) if counted else 0
			var gmedal := DayShift.medal_of(Flow.daily_goal, gscore) if counted else 0
			var entry := Save.daily_entry()
			var day_prev := int(entry.get("best", 0)) if String(entry.get("date", "")) == Flow.daily_date else 0
			if counted:
				Daily.record(entry, Save.data.stats, Flow.daily_date, gscore, gmedal)
				Save.write()
				if gscore > day_prev:
					day_ghost_score = gscore                    # nach replay.finish() sichern
			hud.result["day"] = {"rule": Flow.daily_rule, "goal": Flow.daily_goal, "score": gscore, "medal": gmedal, "best": int(entry.get("best", gscore)), "new_best": counted and gscore > day_prev,
				"best_medal": int(entry.get("medal", gmedal)), "streak": Daily.current_streak(Save.data.stats, Flow.daily_date), "date": Flow.daily_date, "stats": ds}
			hud.result["best_score"] = int(entry.get("best", gscore))
			counted = false
		if counted:
			Save.complete_level(Flow.current_level, run.level_time, run.money, run.earned, med, score)
		replay.finish({"complete": true, "time": run.level_time, "money": run.money, "earned": run.earned, "delivered": run.delivered})
		if Flow.daily and day_ghost_score >= 0 and not Save.dev_session:
			Replay.save_day(replay.to_dict(), Save.slot, Flow.daily_date, day_ghost_score)
		if counted and not Save.dev_session:
			Replay.save_if_best(replay.to_dict(), Save.slot)
		var fresh := _check_unlocks()
		if hud.result.has("day"):
			var dd: Dictionary = hud.result["day"]
			dd["fresh"] = fresh.map(func(it): return String(it.name.get(TranslationServer.get_locale().substr(0, 2), it.id)))
			dd["reward"] = DayShift.next_reward(Save.data.stats, Save.data.get("unlocked", []))
		Sfx.set_thrust(0.0, 0.0)
		if Flow.next_level_id() == "":
			if not Flow.practice:
				Save.clear_campaign()
		elif autopilot != null:
			_begin_transition()                  # Autopilot-Läufe (Dev) laufen ohne Bestätigung weiter
	if run.result == Run.Result.FAILED and not hud.game_over:
		restart_timer += Tuning.TICK
		if restart_timer > 1.2:
			_lose_life()

var field_cd := 0.0
var warn_cd := 0.0
const EXIT_TICK_SLOW := 15.0        # Restsekunden, ab denen die Uhr langsam tickt
const EXIT_TICK_FAST := 7.0         # Restsekunden, ab denen sie schnell tickt
var exit_tick_cd := 0.0             # Zeitdruck am Ausgang: tickende Uhr
var exit_cd_last := -1.0

## Tickende Uhr für die letzten 15 Sekunden des Ausgangs-Countdowns, ab 7 Sekunden schneller und lauter. Sie tickt nur, solange die Zeit
## des letzten Fahrgasts wirklich läuft (nicht beim Mitfahren eines Zusatzfahrgasts, nicht in der Flugschule). Der Tankalarm („warn“) bleibt dem Tank vorbehalten.
func _exit_clock_tick() -> void:
	var cd: float = run.exit_countdown
	if run.result == Run.Result.RUNNING and cd > 0.0 and cd <= EXIT_TICK_SLOW and not run.level.tutorial and exit_cd_last >= 0.0 and cd < exit_cd_last:
		exit_tick_cd -= Tuning.TICK
		if exit_tick_cd <= 0.0:
			Sfx.play("exit_tick_fast" if cd <= EXIT_TICK_FAST else "exit_tick", -5.0 if cd <= EXIT_TICK_FAST else -10.0)
			exit_tick_cd = 1.0
	else:
		exit_tick_cd = 0.0
	exit_cd_last = cd
var heat_msg_t := -99.0
var field_msg_t := -99.0

## Im Magnetfeld: Rütteln, Funken und Rumble, damit man die Kraft spürt; beim Einflug eine Meldung (Anziehung oder Abstoßung).
func _field_feedback() -> void:
	if not run.level.has_zones() or run.sim.state != TaxiSim.State.FLYING:
		return
	if run.level.heat_at(run.sim.pos, run.sim.time, Tuning.HULL_HALF if run.rules >= 4 else Vector2.ZERO) and run.sim.time - heat_msg_t > 5.0:
		heat_msg_t = run.sim.time
		hud.flash_message(tr("MSG_HEAT"), 1.8)
	var za := run.level.zone_accel(run.sim.pos, run.sim.time)
	var mag := za.length()
	if mag < 12.0:
		return
	var s := clampf(mag / 120.0, 0.0, 1.0)
	_add_shake(0.25 + 0.9 * s)
	Haptics.pulse(0.04, 0.2 + 0.6 * s, 0.06)
	field_cd -= Tuning.TICK
	if field_cd <= 0.0:
		field_cd = 0.3
		taxi.burst_sparks()
	if run.sim.time - field_msg_t > 6.0:
		field_msg_t = run.sim.time
		var key := "MSG_FIELD_PUSH"
		for z in run.level.zones:
			if not (z.rect as Rect2).has_point(run.sim.pos) or not run.level.zone_active(z, run.sim.time):
				continue
			if z.kind == "magnet":
				key = "MSG_FIELD_PULL" if run.level.zone_k(z, run.sim.time) > 0.0 else "MSG_FIELD_PUSH"
			elif z.kind == "wind":
				key = "MSG_FIELD_WIND"
			elif z.kind == "gravity":
				key = "MSG_FIELD_HEAVY" if float(z.g) > 1.0 else "MSG_FIELD_LIGHT"
		hud.flash_message(tr(key), 1.6)

func _lose_life() -> void:
	## Taxi zerstört: ein Leben weniger; keins mehr = Game Over. Sonst läuft das Level weiter (nichts wird neu gestartet):
	## Der Fahrgast an Bord ist verloren, neues Taxi am Startpad.
	if run.level.tutorial:                      # Flugschule: ein Leben weniger (nie unter 1), damit die Lebensstation später etwas zu tun hat
		Flow.lives = maxi(1, Flow.lives - 1)
		run.respawn_after_crash()
		run.lives = Flow.lives
		gear_on = run.sim.gear_cmd
		restart_timer = 0.0
		taxi.sync_state()
		taxi.reset_physics_interpolation()
		assist.sync_state()
		assist.reset_physics_interpolation()
		cam.global_position = _cam_target()
		cam.reset_physics_interpolation()
		return
	Flow.lives -= 1
	if Flow.lives <= 0:
		Flow.lives = 0
		hud.game_over = true
		if Flow.shift:
			Flow.shift_credits = run.money
			hud.shift_final = Flow.finish_shift()
		elif not Flow.practice:
			hud.over_level = Flow.lose_sector(run.level.sector).number
		return
	if not Flow.practice:
		Save.note_campaign_lives(Flow.lives)
	replay.mark_respawn()
	run.respawn_after_crash()
	run.lives = Flow.lives
	gear_on = run.sim.gear_cmd
	restart_timer = 0.0
	taxi.sync_state()
	taxi.reset_physics_interpolation()
	assist.sync_state()
	assist.reset_physics_interpolation()
	cam.global_position = _cam_target()
	cam.reset_physics_interpolation()
	_respawn_focus()

## Kamera-Gefühl: leichter Vorausblick in Flugrichtung, Wackeln bei Treffern. Bei „Weniger Bewegung“ aus.
func _cam_feel() -> void:
	if Settings.values.reduce_motion or trans_t >= 0.0:
		cam.offset = Vector2.ZERO
		cam.zoom = Vector2.ONE
		return
	cam_off = cam_off.lerp((run.sim.vel * 0.03).limit_length(4.0), 0.06)
	shake = maxf(0.0, shake - 0.05)
	near_z = move_toward(near_z, 1.0 if slowmo_left > 0.0 else 0.0, 0.03)
	var z := 1.0 + NEAR_ZOOM * TV.smooth(near_z)
	cam.zoom = Vector2(z, z)
	var to_taxi := (run.sim.pos - cam.global_position) * (1.0 - 1.0 / z)      # Zoom auf das Taxi zu, nicht auf die Bildmitte
	cam.offset = cam_off + to_taxi + Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * shake

## Musik-Schichten: B (Bewegung) mit Fahrgast an Bord/offenem Tor/Tempo, C (Spannung) bei wenig Sprit, Schaden, Beinahe-Treffer.
var _music_ticks := 0
func _music_tick() -> void:
	_music_ticks += 1
	if _music_ticks % 30 != 0:
		return
	var s := run.sim
	var drive := run.phase == Run.Phase.CARRYING or run.phase == Run.Phase.DROPOFF or run.exit_open or s.vel.length() > 70.0
	var danger := s.fuel < 25.0 or s.hull < 45.0 or near_cd > 3.0 or run.pump_boom_t >= 0.0 or (run.exit_countdown > 0.0 and run.exit_countdown <= 15.0)
	Music.set_layers(drive, danger)

## Tutorial-Hinweise (einmalig je Profil, abschaltbar, laufen nach 7 s von selbst aus).
var _hint_ticks := 0
func _hint_tick() -> void:
	_hint_ticks += 1
	if _hint_ticks % 30 != 0 or not Settings.values.hints or paused or trans_t >= 0.0 or run.level.tutorial:
		return
	var s := run.sim
	var dev := Controls.last_device
	var kind := "kb" if dev == "keyboard" else "pad"
	if run.level.number <= 3 and run.level_time > 0.6 and Flow.current_level == "s1_01":
		_hint("start", tr("HINT_START") % Controls.thrust_label(dev))
	var near_pad := false
	for id in run.level.pads:
		var p: Dictionary = run.level.pads[id]
		if s.pos.x > p.x0 and s.pos.x < p.x1 and s.pos.y < p.row * Tuning.TILE and p.row * Tuning.TILE - s.pos.y < 60.0 and s.state == TaxiSim.State.FLYING:
			near_pad = true
	if near_pad and not s.gear_cmd:
		_hint("gear", tr("HINT_GEAR") % Controls.slot_label("gear", kind, 0))
	if near_pad and s.gear_extended():
		_hint("landing", tr("HINT_LANDING"))
	if run.phase == Run.Phase.CARRYING:
		_hint("passenger", tr("HINT_PASSENGER"))
	if run.level.pads.has("F") and s.fuel < 30.0:
		_hint("fuel", tr("HINT_FUEL"))
	if run.exit_open:
		_hint("exit", tr("HINT_EXIT"))

func _hint(key: String, text: String) -> void:
	var seen: Array = Save.data.get("seen_hints", [])
	if seen.has(key) or hud.hint_t > 0.0:
		return
	seen.append(key)
	Save.data["seen_hints"] = seen
	hud.hint_text = text
	hud.hint_t = 7.0

func _add_shake(amp: float) -> void:
	if not Settings.values.reduce_motion:
		shake = maxf(shake, amp)

## Beinahe-Treffer: zügig an einem Hindernis vorbei (kein Kontakt) löst einen kurzen Kamerazoom mit leichter Zeitlupe aus.
## Außerhalb der Nachtschicht erkennt ihn die Auftragslogik (Run._check_near_tip, mit Trinkgeld) und meldet ihn als Ereignis „near_miss“;
## in der Nachtschicht zählt er wie bisher hier für die Wertung (unverändert: engerer Abstand, auch ohne Fahrgast, kein Trinkgeld).
const NEAR_SPEED := Tuning.NEAR_SPEED
const NEAR_GAP := Tuning.NEAR_GAP
const NEAR_GAP_SHIFT := 2.0         # Nachtschicht: enger, damit sich der Bonus nicht durch Hängen an Wänden einsammeln lässt
const NEAR_ZOOM := 0.12
var near_z := 0.0

func _check_near_miss() -> void:
	near_cd = maxf(0.0, near_cd - Tuning.TICK)
	if not Flow.shift:
		return                          # Erkennung und Trinkgeld in Run (Ereignis „near_miss“, siehe _on_event)
	var s := run.sim
	if near_cd > 0.0 or s.state != TaxiSim.State.FLYING or s.vel.length() < NEAR_SPEED or trans_t >= 0.0 or (Settings.values.reduce_motion and not Flow.shift):
		return
	var lv := run.level
	var gap := NEAR_GAP_SHIFT if Flow.shift else NEAR_GAP
	if lv.box_hits_solid(s.pos, Tuning.HULL_HALF + Vector2(gap, gap)) and not lv.box_hits_solid(s.pos, Tuning.HULL_HALF + Vector2(0.5, 0.5)):
		if Flow.shift:
			run.note_near_miss()            # zählt für die Wertung, unabhängig von „Weniger Bewegung“
			near_cd = 4.0
		if not Settings.values.reduce_motion:
			_near_miss_fx()

func _near_miss_fx(show_text := true) -> void:
	near_cd = 4.0
	slowmo_left = 0.4
	Engine.time_scale = 0.6
	AudioServer.playback_speed_scale = 0.92
	Sfx.play("near_miss", -2.0)
	Haptics.pulse(0.2, 0.2, 0.1)
	if show_text:
		hud.flash_message(tr("MSG_NEAR_MISS"), 1.0)

## Neu freigeschaltete Lackierungen/Aufkleber melden (Toast + Ton).
## Zählt dieser Flug als Handlösung für den Editor? Nur ein Testflug aus dem Editor, ohne Autopilot und ohne Entwicklerschalter, bei dem alle Aufträge befördert wurden.
func _solved_by_hand() -> bool:
	return Flow.community and Flow.return_to_editor != "" and not Flow.editor_autopilot and autopilot == null and not Save.dev_session \
		and run.result == Run.Result.COMPLETE and run.delivered >= run.level.jobs.size()

func _check_unlocks() -> Array:
	var lang := TranslationServer.get_locale().substr(0, 2)
	var fresh: Array = Cosmetics.check_unlocks()
	for it in fresh:
		hud.flash_message(tr("MSG_UNLOCK") % it.name.get(lang, it.id), 4.0)
		Sfx.play("exit", -4.0)
	return fresh

var voice_cd := 0.0
var attendant_cd := 0.0
var pending_call := {}
## Fahrgast an Bord kommentiert die Landung: weich = „Wow, sanft!“, hart = „Aua!“ (höchstens alle 8 s).
func _passenger_reaction(e: Dictionary) -> void:
	if run.actor == null or run.phase != Run.Phase.CARRYING or Time.get_ticks_msec() / 1000.0 < voice_cd:
		return
	var key := ""
	if float(e.vy) <= Tuning.LAND_SOFT_VY and float(e.vx) <= Tuning.PERFECT_VX:
		key = "soft"
	elif float(e.vy) > 38.0:
		key = "hard"
	if key == "":
		return
	voice_cd = Time.get_ticks_msec() / 1000.0 + 8.0
	Sfx.play_voice(run.actor.voice_key(), key)
	hud.subtitle(run.actor.pname, Sfx.line_text("passenger_extra", key))

## Tankwart: schimpft bei Berührungen der Säule, kommentiert Preiswechsel (höchstens alle 14 s).
func _attendant(key: String, cooldown := 0.0) -> void:
	if run.level.tutorial:
		return                                  # im Tutorial spricht nur der Fluglehrer
	var now := Time.get_ticks_msec() / 1000.0
	if cooldown > 0.0:
		if now < attendant_cd:
			return
		attendant_cd = now + cooldown
	Sfx.play_voice("t0", key)
	hud.subtitle(tr("SPK_ATTENDANT"), Sfx.line_text("t0", key), 2.4)

## Patient verloren – deutlich in Bild und Ton: roter Blitz, EKG mit Nulllinie, Dauerton, Meldung der Zentrale, Wackeln, Rumble.
func _patient_lost(e: Dictionary) -> void:
	hud.patient_lost(e.name, int(e.fee))
	_add_shake(4.0)
	Haptics.pulse(0.8, 0.9, 0.5)
	Sfx.play("shatter", -4.0)
	get_tree().create_timer(0.45, true, false, true).timeout.connect(func(): Sfx.play("flatline", -3.0))
	get_tree().create_timer(2.0, true, false, true).timeout.connect(func():
		Sfx.play_voice("d0", "patient_lost")
		hud.subtitle(tr("SPK_DISPATCH"), Sfx.line_text("d0", "patient_lost"), 2.8))

func _end_slowmo() -> void:
	slowmo_left = 0.0
	Engine.time_scale = 1.0
	AudioServer.playback_speed_scale = 1.0

func _exit_tree() -> void:
	_end_slowmo()
	Haptics.stop()

func _on_event(e: Dictionary) -> void:
	if tutorial != null:
		tutorial.on_event(e)
	match e.type:
		"near_miss":
			if float(e.get("tip", 0.0)) > 0.0:
				hud.flash_message(tr("MSG_NEAR_TIP") % int(e.tip), 1.2)
			if not Settings.values.reduce_motion:
				_near_miss_fx(float(e.get("tip", 0.0)) <= 0.0)
			else:
				near_cd = Tuning.NEAR_COOLDOWN
		"perfect":
			hud.flash_message(tr("MSG_PERFECT") % e.streak, 1.4)
			Sfx.play("perfect", -4.0, 1.0 + 0.06 * float(mini(int(e.streak), Tuning.COMBO_MAX) - 1))      # jede weitere perfekte Landung klingt höher
			Haptics.pulse(0.1, 0.25, 0.1)
			Save.count_event("perfect_landings")
			Save.note_max("best_streak", int(e.streak))
			_check_unlocks()
		"streak_lost":
			hud.flash_message(tr("MSG_STREAK_LOST"), 1.2)
		"landed":
			_passenger_reaction(e)
			if run.perfect_landing(e):
				Sfx.play("land_perfect", -3.0)           # perfekte Landung: gedämpftes Aufsetzen, Zischen, Einrasten (nicht nach einem Hüpfer)
			else:
				Sfx.play("land", -4.0)
			taxi.burst_puff(0.6)
			Haptics.pulse(0.15, clampf(float(e.vy) / 48.0, 0.0, 1.0) * 0.8, 0.12)
			if float(e.vy) > 35.0:
				_add_shake(1.2)
		"liftoff": taxi.burst_puff(1.0)
		"call":
			if not run.level.tutorial and Time.get_ticks_msec() < Sfx.narration_until:
				pending_call = e                  # spricht gerade die Zentrale: Ruf danach nachholen
				return
			Sfx.play_voice(e.voice, "call")
			hud.subtitle(e.name, tr("VOICE_CALL"))
		"boarded":
			Sfx.play("board", -6.0)
			Sfx.play_voice(e.voice, "dest_" + e.dest)
			hud.subtitle(e.name, tr("VOICE_EXIT") if e.dest == "exit" else (tr("VOICE_DEST_H") if e.dest == "H" else tr("VOICE_DEST") % e.dest), 2.8)
			if int(e.job) >= 0 and bool(run.jobs[e.job].get("fragile", false)):
				hud.flash_message(tr("MSG_MEDICAL"), 3.2)
		"delivered":
			var msg := tr("MSG_DELIVERED2") % [int(e.pay), e.factor]
			if int(e.get("combo", 0)) > 0:
				msg += "  ★%d" % int(e.combo)
			Save.count_event("deliveries")
			_check_unlocks()
			# Abzüge nach Grund: Landung (beim Absetzen), Treffer mit Fahrgast an Bord, Landung an falscher Plattform
			var pl := float(e.get("pen_land", e.penalty))
			var ph := float(e.get("pen_hit", 0.0))
			var pw := float(e.get("pen_wrong", 0.0))
			if pl > 0.005:
				msg += "  " + tr("MSG_HARD") % int(round(pl * 100.0))
			if ph > 0.005:
				msg += "  " + tr("MSG_PEN_HIT") % int(round(ph * 100.0))
			if pw > 0.005:
				msg += "  " + tr("MSG_PEN_WRONG") % int(round(pw * 100.0))
			hud.flash_message(msg, 3.0)
			Sfx.play("coin")
			Sfx.play_voice(e.voice, "thanks")
			hud.subtitle(e.name, tr("VOICE_THANKS"), 1.8)
		"squashed":
			Haptics.pulse(0.3, 0.1, 0.15)
			Save.count_event("squashes")
			Sfx.play_voice(e.voice, "angry")
			hud.subtitle(e.name, tr("VOICE_ANGRY"), 2.0)
			Sfx.play("hit", -8.0)
		"wrong_pad":
			hud.flash_message(tr("MSG_WRONG_PAD") % e.pct, 2.4)
			Sfx.play_voice(e.voice, "wrong_pad")
			hud.subtitle(e.name, tr("VOICE_WRONG_PAD"), 2.2)
		"ride_damage":
			hud.flash_message(tr("MSG_RIDE_DAMAGE") % e.pct, 2.2)
			if Time.get_ticks_msec() / 1000.0 >= voice_cd:
				voice_cd = Time.get_ticks_msec() / 1000.0 + 2.5
				Sfx.play_voice(e.voice, "bumpy")
				hud.subtitle(e.name, tr("VOICE_BUMPY"), 2.0)
		"beam_warn":
			hud.flash_message(tr("MSG_BEAM_WARN"), 2.0)
			Sfx.play("plasma_warn", -4.0)            # eigener Ton (Plasmabrenner), nicht der Tankalarm
			Haptics.pulse(0.15, 0.2, 0.2)
		"meteor_warn":
			hud.flash_message(tr("MSG_METEOR_WARN"), 2.4)
			Sfx.play("meteor_warn", -4.0)
			Haptics.pulse(0.15, 0.2, 0.2)
		"fragile_broke":
			Sfx.play_voice(e.voice, "hard")
			Sfx.play("shatter", -2.0)
			Haptics.pulse(0.3, 0.3, 0.15)
		"patient_lost":
			_patient_lost(e)
		"job_missed":
			hud.flash_message(tr("MSG_JOB_MISSED") % [e.name, int(e.fee)], 3.0)
		"emergency_expired":
			Sfx.play_voice(e.voice, "angry")
			hud.subtitle(e.name, tr("VOICE_ANGRY"), 1.8)
			if bool(e.get("extra", false)):
				hud.flash_message(tr("MSG_EMERGENCY_LOST") % e.name, 3.0)      # Pflichtfahrgast: die Meldung „verpasst“ mit Strafe folgt
			Haptics.pulse(0.2, 0.3, 0.15)
		"ejected":
			hud.flash_message(tr("MSG_EJECTED") % e.name, 2.4)
			if e.lethal:
				Sfx.play("scream_f" if String(e.voice).begins_with("f") else "scream_m")
				hud.subtitle(e.name, tr("VOICE_SCREAM"), 1.6)
			else:
				Sfx.play_voice(e.voice, "angry")
				hud.subtitle(e.name, tr("VOICE_ANGRY"), 1.8)
			Save.count_event("ejected")
			Haptics.pulse(0.2, 0.3, 0.15)
		"splat":
			Sfx.play("splat")
			_add_shake(2.0)
			Haptics.pulse(0.5, 0.7, 0.25)
		"life_bought":
			Flow.lives = int(e.lives)
			hud.flash_message(tr("MSG_LIFE_BOUGHT") % [int(e.lives), int(e.price)], 3.0)
			Sfx.play("coin")
			Haptics.pulse(0.3, 0.4, 0.2)
		"life_denied":
			hud.flash_message(tr("MSG_LIFE_OFF") if e.get("off", false) else (tr("MSG_LIFE_FULL") if e.full else tr("MSG_LIFE_POOR") % int(e.price)), 2.6)
		"out_of_fuel":
			hud.flash_message(tr("MSG_OUT_OF_FUEL"), 2.5)
			Haptics.pulse(0.5, 0.5, 0.3)
		"extra_appeared":
			hud.flash_message(tr("MSG_EXTRA_NEW") % [e.name, e.pad], 2.6)
			Sfx.play("board", -10.0)
		"extra_left":
			hud.flash_message(tr("MSG_EXTRA_LEFT") % e.name, 2.6)
			if not Sfx.play_voice(e.voice, "bored"):
				Sfx.play_voice(e.voice, "angry")
			hud.subtitle(e.name, tr("VOICE_BORED"), 2.2)
		"cost":
			if e.what == "taxi":
				hud.flash_message(tr("MSG_TAXI_FEE") % int(e.amount), 2.5)
		"price_changed":
			if run.sim.fuel < 70.0:
				_attendant("price_up" if e.up else "price_down", 14.0)
			Sfx.play("price_tick", -6.0)
			props.pump_flash = 1.0
			hud.price_flash = 1.0
			hud.flash_message(tr("MSG_PRICE") % e.price, 2.0)
		"pump_touched":
			_attendant("pump_hit_%d" % clampi(int(e.stage), 1, 3))
			Haptics.pulse(0.6, 0.6, 0.25)
			_add_shake(1.5)
			Save.count_event("pump_hits")
			Sfx.play("pump_hit")
			taxi.burst_sparks()
			hud.flash_message(tr("MSG_PUMP_HIT") % [e.stage, e.price], 2.8)
		"pump_exploded":
			Haptics.pulse(1.0, 1.0, 0.7)
			_add_shake(5.0)
			Save.count_event("pump_explosions")
			_check_unlocks()
			Sfx.play("pump_boom")
			fx.pump_explode(e.rect)
			hud.flash_message(tr("MSG_PUMP_BOOM"), 3.5)
		"pump_out":
			hud.flash_message(tr("MSG_PUMP_OUT"), 2.5)
		"passenger_lost":
			hud.flash_message(tr("MSG_LOST") % [e.name, e.pad], 3.5)
		"replacement":
			hud.flash_message(tr("MSG_SQUASH") % e.pad, 3.0)
		"carried_thanks":
			Sfx.play_voice(e.voice, "thanks")
			hud.subtitle(e.name, tr("VOICE_THANKS"), 1.8)
		"exit_countdown":
			hud.flash_message(tr("MSG_EXIT_COUNTDOWN"), 3.0)
			if not run.level.tutorial and Sfx.play_voice("d0", "exit_start"):
				var ms := int((Sfx.voice_player.stream.get_length() + 0.3) * 1000.0)
				Sfx.narration_until = Time.get_ticks_msec() + ms            # Fahrgast-Zurufe warten, bis die Zentrale fertig ist
				hud.subtitle(tr("SPK_DISPATCH"), Sfx.line_text("d0", "exit_start"), float(ms) / 1000.0)
		"exit_hurry":
			Haptics.pulse(0.15, 0.1, 0.12)
			if e.voice != "":
				Sfx.play_voice(e.voice, "hurry_%d" % e.n)
				hud.subtitle(e.name, Sfx.line_text("passenger_extra", "hurry_%d" % e.n), 1.8)
			else:
				Sfx.play_voice("d0", "exit_hurry")
				hud.subtitle(tr("SPK_DISPATCH"), Sfx.line_text("d0", "exit_hurry"), 1.8)
		"spawn_blocked":
			hud.flash_message(tr("MSG_MAKE_ROOM"), 3.0)
		"exit_timeout":
			hud.flash_message(tr("MSG_EXIT_TIMEOUT") % int(e.fee), 4.0)
			Sfx.play("hit", -4.0)
			_add_shake(2.0)
		"exit_open":
			hud.flash_message(tr("MSG_EXIT_OPEN"))
			Sfx.play("exit")
		"damage":
			Haptics.pulse(0.6, 0.9, 0.2)
			_add_shake(clampf(float(e.amount) / 25.0, 0.6, 4.0))
			taxi.flash = 1.0
			taxi.burst_sparks()
			Sfx.play("hit")
		"destroyed":
			Sfx.play("crash")
			Save.count_event("crashes")
			Haptics.pulse(1.0, 1.0, 0.6)
			_add_shake(5.0)
		"bad_landing":
			match e.reason:
				"gear": hud.flash_message(tr("MSG_BAD_GEAR"))
				"pos": hud.flash_message(tr("MSG_BAD_POS"))
				"plate": hud.flash_message(tr("MSG_BAD_PLATE"))
				"speed": hud.flash_message(tr("MSG_BAD_SPEED"))
				"tilt": hud.flash_message(tr("MSG_BAD_TILT"))

# ---------------------------------------------------------------- Levelwechsel
func _process(delta: float) -> void:
	_clip_tick(delta)
	_focus_tick(delta)
	if run.result == Run.Result.RUNNING and not paused and not briefing and trans_t < 0.0:
		Save.add_playtime(delta / maxf(Engine.time_scale, 0.05))
	if slowmo_left > 0.0:
		slowmo_left -= delta / maxf(Engine.time_scale, 0.05)
		if slowmo_left <= 0.0:
			_end_slowmo()
	if trans_t < 0.0:
		return
	if radio_played:
		radio_age += delta
		trans.radio_age = radio_age
	# Läuft der Funkspruch noch, wartet der Flug kurz vor der Ankunft, bis Text und Sprache zu Ende sind (nichts wird abgeschnitten)
	var hold: bool = radio_played and radio_age < trans.radio_len + 0.6 and trans_t > TV.T_IN - 0.4 and trans_t < TV.T_IN
	if not hold and clip == null:           # läuft ein Einspieler, steht auch der automatische Einflug
		trans_t += delta
	trans.t = trans_t
	if not radio_played and trans_t >= 2.15 and trans_t < TV.T_IN:
		radio_played = true
		_play_radio()
	if not arriving and trans_t >= TV.T_IN:
		_begin_arrival()
	if trans_t >= TV.T_END:
		trans_t = TV.T_END
		_arrival_tick()          # Aufsetzen abschließen (Staub, Geräusch, Ruf, Aussteigen), bevor die Sequenz endet
		_end_transition()

var radio_played := false
var radio_age := 0.0              # Sekunden seit Beginn des Funkspruchs (läuft auch, wenn der Flug darauf wartet)

## Funkspruch der Zentrale während der Weltraumfahrt: ein eigener Spruch je Level; wird dort etwas Neues eingeführt,
## bezieht er sich darauf, sonst ist es Plauderei.
func _play_radio() -> void:
	var nl := LevelData.load_file(Flow.level_path(next_id))
	var key := "r%d" % nl.number          # jedes Level hat einen eigenen Funkspruch (data/voice_lines.json, Stimme d0)
	var txt := Sfx.line_text("d0", key)
	if txt == "":
		return
	Sfx.play_voice("d0", key)
	var length := Sfx.voice_player.stream.get_length() if Sfx.voice_player.stream != null else 3.0
	trans.radio_speaker = tr("SPK_DISPATCH")
	trans.radio_text = txt
	trans.radio_t0 = trans_t
	trans.radio_len = length
	hud.subtitle(tr("SPK_DISPATCH"), txt, length + 0.6)        # läuft unter dem Overlay weiter und erscheint beim Einblenden

## Stand für das nächste Level festhalten: Sprit, Credits und Ausgangs-Fahrgast laufen mit.
func _store_progress() -> void:
	next_id = Flow.next_level_id()
	Flow.entry_fuel = maxf(Tuning.MIN_START_FUEL, run.sim.fuel)
	Flow.entry_credits = run.money
	Flow.carry_passenger = run.carried
	entry_carry = {}
	if not Flow.practice:
		Save.set_campaign({"level": next_id, "lives": Flow.lives, "fuel": Flow.entry_fuel, "credits": Flow.entry_credits, "seed": Flow.run_seed, "carry": run.carried})

## Werkstatt nach dem Sektor: liegt über allem; verlässt das Taxi sie, beginnt der Levelwechsel direkt im Weltraum.
func _open_bay() -> void:
	_store_progress()
	Music.duck(-8.0)
	var layer := CanvasLayer.new()
	layer.layer = 13
	bay = WorkshopBay.new()
	bay.sector = run.level.sector
	bay.wallet = run.money
	bay.leave = func():
		run.money = bay.wallet
		bay = null
		_begin_transition()
		trans_t = TV.T_OUT
		trans.t = trans_t
	layer.add_child(bay)
	add_child(layer)

var bay: WorkshopBay = null

func _begin_transition() -> void:
	_store_progress()
	if OS.get_cmdline_user_args().has("--debug-carry") and Flow.carry_passenger.is_empty():     # Dev: Ausgangs-Fahrgast simulieren
		Flow.carry_passenger = {"name": "Odo", "look": 2, "gender": "m"}
	var nl := LevelData.load_file(Flow.level_path(next_id))
	var lang := TranslationServer.get_locale().substr(0, 2)
	trans.title_sector = tr("TRANS_SECTOR") % [nl.sector, tr("SECTOR_%d" % nl.sector)]
	trans.title_level = tr("TRANS_LEVEL") % [(nl.sector - 1) * 11 + nl.index, nl.names.get(lang, nl.id)]
	trans.info = tr("TRANS_FARES") % int(run.money)
	if nl.gravity != Tuning.GRAVITY:
		trans.info += "  ·  " + tr("TRANS_GRAVITY") % (nl.gravity / Tuning.GRAVITY)
	if Flow.shift:
		trans.info = tr("TRANS_SHIFT") % [Flow.shift_results.size() + 1, NightShift.MAPS]
		var sidx: int = Flow.shift_plan.find(next_id)
		trans.info += "  ·  " + tr("TRANS_GRAVITY") % (NightShift.gravity_for(nl, sidx, Flow.shift_date) / Tuning.GRAVITY)
		trans.info += "  ·  " + tr("TRANS_DARK") % int(round(maxf(nl.dark, NightShift.dark_for(sidx)) * 100.0))
	trans.skip_hint = tr("TRANS_SKIP")
	arriving = false
	trans_t = 0.0
	radio_played = false
	radio_age = 0.0
	trans.radio_age = 0.0
	Music.duck(-13.0)
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--trans-t="):      # Dev: Zeitachse an beliebiger Stelle starten (Screenshots)
			trans_t = float(a.substr(10))
	trans.t = trans_t
	Sfx.set_thrust(0.0, 0.0)
	Sfx.play_long("transit")

func _begin_arrival() -> void:
	## Neues Level laden; das Taxi tritt durch das (kurz öffnende) Tor in der Decke aus, fliegt eine
	## S-Kurve und landet auf der Startplattform.
	arriving = true
	arrive_done = false
	Flow.current_level = next_id
	level_path = Flow.level_path(next_id)
	load_level(level_path)
	run.level.doors_forced_open = true      # beim Einflug stehen bewegliche Tore offen
	run.level.movers_ignore = true          # … und Trümmer sind ausgeblendet (sie erscheinen mit dem Spielstart)
	arrive_end = run.sim.pos
	arrive_path = Pathing.arrival_path(run.level, arrive_end)
	arrive_start = arrive_path[0]
	arrive_prev = arrive_start
	_arrival_tick()
	taxi.reset_physics_interpolation()
	assist.sync_state()
	assist.reset_physics_interpolation()
	_queue_clip(0.0, true)                  # Neues Spielelement gleich beim Einflug vorstellen; der Einflug steht währenddessen (siehe _process) und läuft danach weiter

func _arrival_tick() -> void:
	if not arriving or arrive_done:
		return
	var s := run.sim
	var u := clampf((trans_t - TV.T_IN) / (TV.T_END - TV.T_IN), 0.0, 1.0)
	if u >= 1.0:
		s.pos = arrive_end
		s.gear = 1.0
		s.tilt = 0.0
		s.thrust_in = Vector2.ZERO
		props.door_override = -1.0
		props.door = 1.0 if run.exit_open else 0.0
		taxi.sync_state()
		taxi.burst_puff(1.0)
		Sfx.play("land", -4.0)
		Sfx.set_thrust(0.0, 0.0)
		arrive_done = true
		_release_carried()
		if run.actor != null and run.actor.state == PassengerActor.S.WAITING:
			run.actor.wave()
			_on_event({"type": "call", "voice": run.actor.voice_key(), "name": run.actor.pname})
		return
	var e := TV.smooth(u * 1.04)
	var pos := Pathing.sample_path(arrive_path, e)
	var vel := (pos - arrive_prev) / Tuning.TICK
	arrive_prev = pos
	s.pos = pos
	s.gear = TV.smooth((u - 0.5) / 0.3)
	s.tilt = clampf(vel.x / 170.0, -0.24, 0.24) * (1.0 - TV.smooth((u - 0.8) / 0.2))
	s.thrust_in = Vector2(clampf(vel.x / 90.0, -1.0, 1.0) * 0.8 * (1.0 - TV.smooth((u - 0.55) / 0.3)), -(0.3 + 0.5 * (1.0 - TV.smooth((u - 0.75) / 0.25))))
	# Tor öffnet sich zum Austritt und schließt sich danach wieder
	props.door_override = TV.smooth(u / 0.25) * (1.0 - TV.smooth((u - 0.5) / 0.3))
	taxi.sync_state()
	Sfx.set_thrust(taxi.flame_main * 0.7, absf(taxi.flame_side))

func _release_carried() -> void:
	var c: Dictionary = Flow.carry_passenger
	Flow.carry_passenger = {}
	entry_carry = c
	run.release_carried(c)

func _end_transition() -> void:
	_queue_clip(0.5)
	run.level.doors_forced_open = false
	run.level.movers_ignore = false
	Music.duck(0.0)
	props.door_override = -1.0
	trans_t = -1.0
	trans.t = -1.0
	arriving = false
	Sfx.set_thrust(0.0, 0.0)
	taxi.reset_physics_interpolation()
	assist.sync_state()
	assist.reset_physics_interpolation()
