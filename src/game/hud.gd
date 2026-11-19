extends Control
## HUD: Treibstoff, Hülle, Geld, Auftrag, Ziel-Hinweis und Landeampel. Klar getrennt von der Spielwelt.

const PadGlyph := preload("res://src/ui/pad_glyph.gd")

var run: Run
var message := ""
var message_t := 0.0
var sub_speaker := ""
var sub_text := ""
var sub_t := 0.0
var paused := false
var game_over := false
var shift_final := {}            # Nachtschicht: Gesamtwertung, wenn die Schicht durch Game Over endet
var shot_btn := Rect2()          # Knopf „Screenshot erstellen“ der Schicht-Auswertung (für den Mausklick)
var shot_hide := false           # beim Aufnehmen ausblenden, damit der Knopf nicht im Bild steht
var shot_note := ""              # Dateiname des letzten Screenshots (Hinweis unter dem Knopf)
var shot_note_t := 0.0
var mirror_view := false          # Spiegelwelt: das Bild wird am Ende gespiegelt, Mauspositionen für Klickflächen werden mitgespiegelt
var briefing := false           # Tagschicht: Briefing (Regel und Ziel) steht vor dem Start im Bild
var brief := {}
var brief_btn := Rect2()
var over_level := 0              # Game Over in der Karriere: Level, mit dem es weitergeht
var price_flash := 0.0
var lost_t := 0.0                # Restzeit der „Patient verloren“-Anzeige
var lost_age := 99.0
var lost_name := ""
var lost_fee := 0
const LOST_TOTAL := 4.6
var hint_text := ""
var gauge_override: Array = []      # Tutorial: Landeanzeige zeigt vorgegebene Anteile (Wert / Grenze) statt der echten Werte
var hint_t := 0.0
var result := {}
var result_age := 0.0            # Sekunden seit Anzeige der Ergebnisansicht
var next_exists := true
var life_icon: Texture2D = Cosmetics.life_texture()
var font: Font = Fonts.hud
var gauges := HudGauges.new()    # Tank- und Hüllenanzeige links oben (eigene Zeichnung, Farbe nach Zustand)
const GAUGE_FUEL := Vector2(3, 2)
const GAUGE_HULL := Vector2(74, 2)

var split := {}                  # Runde 85: Zwischenzeit am Sektorende (Karriere-Uhr), steht SPLIT_SHOW Sekunden im Bild
var split_t := 0.0
const SPLIT_SHOW := 7.0
var grav_shown := -1.0           # zuletzt angezeigter Schwerkraftwert (g): ändert er sich, leuchtet die Anzeige kurz auf
var grav_flash := 0.0

func bind(r: Run) -> void:
	run = r

## Gesamte sichtbare Fläche in den Koordinaten dieses Controls (die 640×360-Fläche liegt bei Ultrawide/hohen Fenstern zentriert):
## Abdunklungen sollen bis zum Fensterrand reichen.
func _full_rect() -> Rect2:
	var vs := get_viewport_rect().size
	return Rect2(-(vs - size) * 0.5, vs)

func flash_message(text: String, seconds := 2.0) -> void:
	message = text
	message_t = seconds

## Krankenpatient verloren: roter Blitz, EKG-Monitor mit Nulllinie, Name und Strafbetrag.
func patient_lost(pname: String, fee: int) -> void:
	lost_name = pname
	lost_fee = fee
	lost_t = LOST_TOTAL
	lost_age = 0.0

func subtitle(speaker: String, text: String, seconds := 2.4) -> void:
	if not Settings.values.subtitles:
		return
	sub_speaker = speaker
	sub_text = text
	sub_t = seconds

func _process(delta: float) -> void:
	message_t = maxf(0.0, message_t - delta)
	shot_note_t = maxf(0.0, shot_note_t - delta)
	lost_t = maxf(0.0, lost_t - delta)
	lost_age += delta
	price_flash = maxf(0.0, price_flash - delta * 1.6)
	if not result.is_empty():
		result_age += delta
	hint_t = maxf(0.0, hint_t - delta)
	sub_t = maxf(0.0, sub_t - delta)
	split_t = maxf(0.0, split_t - delta)
	grav_flash = maxf(0.0, grav_flash - delta * 1.2)
	if run != null:
		gauges.update(delta, run.sim.fuel / Tuning.FUEL_MAX, run.sim.hull / Tuning.HULL_MAX)
	queue_redraw()

## Der Tankalarm hat gepiept: Die Tankanzeige blitzt im selben Takt (der Ton selbst bleibt, wie er ist).
func fuel_ping() -> void:
	gauges.ping()

## Das HUD liegt nur in den Randstreifen: oben auf der Felsreihe 0 (y 0–16), unten unter der Bodenreihe (y 336–360).
## Dazwischen liegt das reine Spielfeld – nichts überdeckt Plattformen, Hindernisse oder Fahrgäste. Frei bleibt
## x 296–344 oben (Torschild). Rechts vom Tor: Level und Name, Pflichtfahrgäste (x/y), Spritpreis; ganz rechts die Landeanzeige.
const TOP_Y := 0.0
const BOT_Y := 337.0

func _draw() -> void:
	if run == null:
		return
	var s := run.sim
	var blink := int(Time.get_ticks_msec() / 250) % 2 == 0
	if run.fuel_dead_t > 0.0 and run.result == Run.Result.RUNNING and blink:
		draw_string(font, Vector2(0, size.y * 0.30), tr("HUD_NO_FUEL") % maxf(0.0, Tuning.OUT_OF_FUEL_TIME - run.fuel_dead_t), HORIZONTAL_ALIGNMENT_CENTER, size.x, 14, Color("#ff4d6d"))
	# ---------------- oberer Streifen: dunkle Unterlage über die ganze Fensterbreite (auch Ultrawide); x 296–344 bleibt für das Torschild frei
	var fr := _full_rect()
	var band := Color(0.03, 0.04, 0.12, 0.86)
	draw_rect(Rect2(fr.position.x, 0, 296.0 - fr.position.x, 16), band)
	draw_rect(Rect2(344, 0, fr.end.x - 344.0, 16), band)
	draw_line(Vector2(fr.position.x, 16), Vector2(296, 16), Color("#3a4580"), 0.67)
	draw_line(Vector2(344, 16), Vector2(fr.end.x, 16), Color("#3a4580"), 0.67)
	gauges.draw_fuel(self, GAUGE_FUEL, s.fuel / Tuning.FUEL_MAX, s.fuel_cap / Tuning.FUEL_MAX, run.fuel_dead_t > 0.0 and run.result == Run.Result.RUNNING)
	gauges.draw_hull(self, GAUGE_HULL, s.hull / Tuning.HULL_MAX)
	_fit_text(font, Vector2(147, 12), "¢%d" % int(run.money), 56.0, Settings.fs(9), Color("#ffe14a"), HORIZONTAL_ALIGNMENT_LEFT)       # Settings.fs: Option „Große Schrift“
	var life_fr: Dictionary = Cosmetics.life_frame(PixelScale.size_for(self))                          # Runde 72: neues Taxi, 10 × 6 Einheiten in der Pixelgröße des Bildschirms
	for i in Flow.lives:
		draw_texture_rect_region(life_fr.tex, Rect2(204 + i * 11, 5, 10, 6), life_fr.src)
	if run.streak >= 1:
		var stars := mini(run.streak, Tuning.COMBO_MAX)
		_fit_text(font, Vector2(262, 12), "★%d +%d%%" % [run.streak, int(round(Tuning.COMBO_STEP * stars * 100.0))], 34.0, Settings.fs(8), Color("#ffe14a"), HORIZONTAL_ALIGNMENT_LEFT)
	if run.level.pads.has("F"):
		# Spritpreis (springt in zufälligen Abständen, steigt bei Berührung der Zapfsäule)
		var pf := run.fuel_price()
		var span := maxf(run.level.fuel_price_max - run.level.fuel_price_min, 0.01)
		var n := (pf - run.level.fuel_price_min) / span
		var pcol := SignalColors.by_level(n, 0.34, 0.67, Color("#ff6a4a"))
		var ptxt := tr("HUD_PRICE") % pf
		if run.station_down():
			ptxt = tr("HUD_PUMP_DEAD")
			pcol = SignalColors.bad()
		if price_flash > 0.0:
			pcol = pcol.lerp(Color.WHITE, price_flash)
		_fit_text(font, Vector2(494, 12), ptxt, 82.0, Settings.fs(8), pcol, HORIZONTAL_ALIGNMENT_LEFT)
	var lname: String = run.level.display_name()
	if not Flow.watch.is_empty():
		lname = tr("WATCH_TAG") + "  " + lname                  # Bestflug ansehen
	_fit_text(font, Vector2(374, 12), lname if run.level.tutorial or not Flow.watch.is_empty() else (tr("SHIFT_TAG") + "  " + lname if Flow.shift or result.has("shift") else (tr("DAILY_TAG") + "  " + lname if Flow.daily else (tr("COMMUNITY_TAG") + ("  " + tr("ED_AUTOPILOT_TAG") if Flow.editor_autopilot else "") + "  " + lname if Flow.community else "%d/99  %s" % [run.level.number, lname]))), 84.0, Settings.fs(8), Color("#c4d0ff"), HORIZONTAL_ALIGNMENT_LEFT)       # nur auf dem oberen Rand, nicht im Eck des Tores
	_fit_text(font, Vector2(460, 12), "%d/%d" % [run.delivered, run.level.jobs.size()], 28.0, Settings.fs(9), Color.WHITE, HORIZONTAL_ALIGNMENT_RIGHT)
	# Landeampel: Sinkrate, Seitengeschwindigkeit, Neigung als drei Balken mit gezeichneten Symbolen (weiße Marke = Grenze der sicheren Landung;
	# darüber gestreift, damit der Zustand auch ohne Farbsehen erkennbar ist)
	var rows := [s.vel.y / run.sim.land_vy, absf(s.vel.x) / Tuning.LAND_VX, absf(s.tilt) / Tuning.LAND_TILT]
	for i in rows.size():
		var r: float = rows[i]
		if gauge_override.size() == rows.size():
			r = float(gauge_override[i])
		var ratio: float = clampf(r, 0.0, 2.0)
		var col := SignalColors.by_level(ratio, Tuning.GAUGE_GREEN, 1.0)
		_gauge_row(i, ratio, col)
	_draw_gravity(fr)
	_draw_career_clock()
	# Countdown des letzten Pflichtfahrgasts: unter dem Tor, ab 10 s rot blinkend
	if run.exit_countdown > 0.0 and run.result == Run.Result.RUNNING:
		var cd := run.exit_countdown
		var urgent := cd <= 10.0
		var ccol := Color("#ff4d6d") if (urgent and blink) else (Color("#ffb02e") if urgent else Color("#ffe14a"))
		draw_rect(Rect2(266, 51, 108, 13), Color(0.05, 0.06, 0.15, 0.85))
		draw_rect(Rect2(266, 51, 108, 13), ccol, false, 0.8)
		_fit_text(font, Vector2(266, 61), tr("HUD_EXIT_TIMER") % int(ceilf(cd)), 108.0, mini(Settings.fs(9), 11), ccol, HORIZONTAL_ALIGNMENT_CENTER)
	# ---------------- unterer Streifen: Auftrag (oben) und Hinweise/Untertitel (unten)
	var job := run.current_job()
	var txt := ""
	var ex_aboard := run._extra_aboard()
	if not ex_aboard.is_empty():
		var xf: String = (tr("HUD_TAG_FRAGILE") + " " if ex_aboard.job.get("fragile", false) else "") + _kind_tag(ex_aboard.job, run.extra_emergency_left(ex_aboard))
		txt = tr("HUD_TAG_EXTRA") + "  " + xf + (tr("HUD_DELIVER_H") % ex_aboard.actor.pname if run.target_pad() == "H" else tr("HUD_DELIVER") % [ex_aboard.actor.pname, run.target_pad()])
	elif job.is_empty():
		txt = tr("HUD_GO_EXIT") if run.exit_open else ""
	else:
		var who: String = job.get("passenger", "?")
		var frag: String = (tr("HUD_TAG_FRAGILE") + " " if job.get("fragile", false) else "") + _kind_tag(job, run.emergency_left())
		if run.phase == Run.Phase.CARRYING and run.is_exit_job(job):
			txt = tr("HUD_TAG_MAIN") + "  " + frag + tr("HUD_TO_EXIT") % who
		elif run.phase == Run.Phase.CARRYING or run.phase == Run.Phase.DROPOFF:
			txt = tr("HUD_TAG_MAIN") + "  " + frag + (tr("HUD_DELIVER_H") % who if run.target_pad() == "H" else tr("HUD_DELIVER") % [who, run.target_pad()])
		elif run.actor != null:
			txt = tr("HUD_TAG_MAIN") + "  " + frag + tr("HUD_PICKUP") % [who, run.target_pad()]
		else:
			txt = tr("HUD_WAIT_CALL")
	if txt != "":
		draw_rect(Rect2(2, BOT_Y, 636, 13), Color(0.05, 0.06, 0.15, 0.9))
		draw_rect(Rect2(2, BOT_Y, 636, 13), Color("#3a4580"), false, 0.67)
		_fit_text(font, Vector2(8, BOT_Y + 10), txt, 440.0, mini(Settings.fs(10), 12), Color("#6fe8f0") if not ex_aboard.is_empty() else Color("#ffe14a"), HORIZONTAL_ALIGNMENT_LEFT)
		if not ex_aboard.is_empty() and run.result == Run.Result.RUNNING:
			var fe := run.extra_factor(ex_aboard)
			var fce := SignalColors.by_level(-fe, -1.05, -0.8, Color("#ff8a5a"))
			_fit_text(font, Vector2(450, BOT_Y + 10), (tr("HUD_FACTOR") % fe) + "  ¢%d" % int(round(run.extra_prospect(ex_aboard))), 182.0, mini(Settings.fs(10), 12), fce, HORIZONTAL_ALIGNMENT_RIGHT)
		elif run.actor != null and run.result == Run.Result.RUNNING:
			var f := run.live_factor()
			var fc := SignalColors.by_level(-f, -1.05, -0.8, Color("#ff8a5a"))
			_fit_text(font, Vector2(450, BOT_Y + 10), (tr("HUD_FACTOR") % f) + "  ¢%d" % int(round(run.prospect())), 182.0, mini(Settings.fs(10), 12), fc, HORIZONTAL_ALIGNMENT_RIGHT)
	var row_b := BOT_Y + 21.0
	draw_rect(Rect2(2, BOT_Y + 14.0, 636, 9.0), Color(0.05, 0.06, 0.15, 0.78))      # Unterlage: die Zeile bleibt auf jedem Hintergrund lesbar
	# Untere Zeile: links Steuerungshinweis (bzw. gesprochener Untertitel/Hinweis), rechts alle Meldungen des Spiels
	var large: bool = Settings.values.text_large
	if sub_t > 0.0 and large:
		_big_caption("%s: %s" % [sub_speaker, sub_text], Color(1, 1, 1, clampf(sub_t / 0.4, 0.0, 1.0)))
	elif hint_t > 0.0 and hint_text != "" and large:
		_big_caption(hint_text, Color(0.8, 1.0, 0.95, clampf(hint_t / 0.5, 0.0, 1.0)))
	if sub_t > 0.0 and not large:
		var line := "%s: %s" % [sub_speaker, sub_text]
		var a := clampf(sub_t / 0.4, 0.0, 1.0)
		_fit_text(Fonts.ui, Vector2(8, row_b), line, 330.0, 8, Color(1, 1, 1, a), HORIZONTAL_ALIGNMENT_LEFT)
	elif hint_t > 0.0 and hint_text != "" and not large:
		var ha := clampf(hint_t / 0.5, 0.0, 1.0)
		_fit_text(Fonts.ui, Vector2(8, row_b), hint_text, 330.0, 8, Color(0.8, 1.0, 0.95, ha), HORIZONTAL_ALIGNMENT_LEFT)
	elif not Flow.watch.is_empty():
		var wk := Controls.pad_name("B") if Controls.last_device == "gamepad" else "Esc"
		_fit_text(font, Vector2(8, row_b), tr("WATCH_HINT") % wk, 330.0, Settings.fs(8), Color("#9fe6ff"), HORIZONTAL_ALIGNMENT_LEFT)
	else:
		_fit_text(font, Vector2(8, row_b), Controls.hint_text(Controls.last_device), 330.0, Settings.fs(7), Color("#b4bcea"), HORIZONTAL_ALIGNMENT_LEFT)
	if message_t > 0.0:
		var ma := clampf(message_t / 0.4, 0.0, 1.0)
		_fit_text(font, Vector2(340, row_b), message, 296.0, mini(Settings.fs(9), 11), Color(1.0, 0.95, 0.7, ma), HORIZONTAL_ALIGNMENT_RIGHT)
	elif not ex_aboard.is_empty() and not job.is_empty():     # Erinnerung an die Pflicht, solange ein Zusatzfahrgast mitfährt
		var rem := tr("HUD_MAIN_WAITING") % [job.get("passenger", "?"), job.get("to", "") if run.phase == Run.Phase.CARRYING else job.get("from", "")]
		_fit_text(font, Vector2(340, row_b), rem, 296.0, 8, Color("#ffd24a"), HORIZONTAL_ALIGNMENT_RIGHT)
	if game_over and not shift_final.is_empty():
		_draw_shift_summary(shift_final, true)
	elif game_over:
		draw_rect(_full_rect(), Color(0, 0, 0, 0.6))
		draw_string(font, Vector2(0, size.y * 0.42), tr("HUD_GAME_OVER"), HORIZONTAL_ALIGNMENT_CENTER, size.x, 28, Color("#ff4d6d"))
		var over_line := tr("HUD_RUN_CREDITS") + ": ¢ %d" % int(run.money)
		if over_level > 0:
			over_line = tr("HUD_OVER_SECTOR") % over_level
		draw_string(font, Vector2(0, size.y * 0.42 + 20), over_line, HORIZONTAL_ALIGNMENT_CENTER, size.x, 12, Color("#ffe14a"))
		draw_string(font, Vector2(0, size.y * 0.42 + 40), tr("HUD_GAME_OVER_HINT"), HORIZONTAL_ALIGNMENT_CENTER, size.x, 10, Color.WHITE)
	elif run.result == Run.Result.FAILED:
		draw_rect(Rect2(size.x * 0.5 - 130.0, size.y * 0.45 - 21.0, 260.0, 46.0), Color(0.03, 0.04, 0.1, 0.8))      # Unterlage: Text bleibt auf jedem Hintergrund lesbar
		draw_rect(Rect2(size.x * 0.5 - 130.0, size.y * 0.45 - 21.0, 260.0, 1.0), Color("#ff4d6d"))
		draw_string(font, Vector2(0, size.y * 0.45), tr("HUD_OUT_OF_FUEL") if run.fuel_fail else tr("HUD_CRASHED"), HORIZONTAL_ALIGNMENT_CENTER, size.x, 16, Color("#ff4d6d"))
		draw_string(font, Vector2(0, size.y * 0.45 + 16), tr("HUD_LAST_LIFE") if Flow.lives <= 1 else tr("HUD_LIFE_LOST") % (Flow.lives - 1), HORIZONTAL_ALIGNMENT_CENTER, size.x, 10, Color.WHITE)
	elif run.result == Run.Result.COMPLETE and result.is_empty():
		draw_string(font, Vector2(0, size.y * 0.42), tr("HUD_COMPLETE"), HORIZONTAL_ALIGNMENT_CENTER, size.x, 16, Color("#5dff9a"))
	if lost_t > 0.0:
		_draw_patient_lost()
	if run.result == Run.Result.COMPLETE and not result.is_empty():
		_draw_result()
	if briefing:
		_draw_briefing()
	if paused:
		draw_rect(_full_rect(), Color(0, 0, 0, 0.55))

# ---------------------------------------------------------------- Runde 85: Schwerkraft und Karriere-Uhr
## Schwerkraft am Ort des Taxis in g (Grundschwerkraft des Levels samt Schwerkraftzonen, 1 g = Tuning.GRAVITY).
func gravity_now() -> float:
	if run == null or run.level == null:
		return 1.0
	return run.level.gravity_at(run.sim.pos, run.level.clock) / Tuning.GRAVITY

## Zahl mit einer Nachkommastelle, Komma in allen Sprachen außer Englisch.
static func decimal(v: float, lang: String) -> String:
	var t := "%.1f" % v
	return t if lang == "en" else t.replace(".", ",")

## Schwerkraftanzeige rechts unter dem oberen Streifen: Planetensymbol mit Pfeil und der Wert in g. Gedämpft bei 1 g,
## heller (kühl unter, warm über 1 g), sobald sie abweicht; ändert sich der Wert (Zone, Sektor), leuchtet sie kurz auf.
func _draw_gravity(fr: Rect2) -> void:
	var g := gravity_now()
	var shown := snappedf(g, 0.1)
	if grav_shown >= 0.0 and absf(shown - grav_shown) > 0.01:
		grav_flash = 0.0 if Settings.values.reduce_motion else 1.0
	grav_shown = shown
	var w := 34.0
	var x := minf(fr.end.x, 640.0) - w - 2.0
	var y := 17.5
	var col := Color("#9aa6d8")
	if shown < 0.95:
		col = Color("#7fe3ff")
	elif shown > 1.05:
		col = Color("#ffb35a")
	col = col.lerp(Color.WHITE, grav_flash * 0.8)
	draw_rect(Rect2(x, y, w, 10.0), Color(0.03, 0.04, 0.12, 0.72 + 0.2 * grav_flash))
	draw_rect(Rect2(x, y, w, 10.0), Color("#3a4580").lerp(col, 0.35 + 0.65 * grav_flash), false, 0.67)
	var c := Vector2(x + 6.0, y + 9.6)                        # Planet: Bogen am unteren Rand, Pfeil darauf zu
	draw_arc(c, 3.6, PI * 1.08, PI * 1.92, 10, col, 0.9)
	draw_line(Vector2(c.x, y + 1.6), Vector2(c.x, y + 5.0), col, 0.67)
	draw_polyline(PackedVector2Array([Vector2(c.x - 1.5, y + 3.7), Vector2(c.x, y + 5.3), Vector2(c.x + 1.5, y + 3.7)]), col, 0.67)
	_fit_text(font, Vector2(x + 11.0, y + 8.0), decimal(shown, Loc.code()) + " g", w - 12.0, mini(Settings.fs(7), 9), col, HORIZONTAL_ALIGNMENT_LEFT)

func show_split(sp: Dictionary) -> void:
	if sp.is_empty():
		return
	split = sp
	split_t = SPLIT_SHOW

## Karriere-Uhr (Option „Speedrun-Uhr“) links unter dem oberen Streifen; am Sektorende darunter die Zwischenzeit mit dem Abstand
## zur bisherigen Bestzeit dieses Sektors (grün schneller, rot langsamer).
func _draw_career_clock() -> void:
	if not Settings.values.speedrun_clock or not Flow.is_career():
		return
	var x := 3.0
	var y := 17.5
	var w := 50.0
	var col := Color("#d8e0ff")
	draw_rect(Rect2(x, y, w, 10.0), Color(0.03, 0.04, 0.12, 0.72))
	draw_rect(Rect2(x, y, w, 10.0), Color("#3a4580"), false, 0.67)
	var c := Vector2(x + 5.5, y + 5.4)                        # Stoppuhr
	draw_arc(c, 3.0, 0.0, TAU, 14, col, 0.67)
	draw_line(c, c + Vector2(0.0, -2.0), col, 0.67)
	draw_line(c, c + Vector2(1.4, 0.6), col, 0.67)
	draw_line(Vector2(c.x - 0.8, y + 1.0), Vector2(c.x + 0.8, y + 1.0), col, 0.67)
	_fit_text(font, Vector2(x + 10.5, y + 8.0), Flow.clock_text(Flow.career_clock), w - 12.0, mini(Settings.fs(7), 9), col, HORIZONTAL_ALIGNMENT_LEFT)
	if split_t <= 0.0 or split.is_empty():
		return
	var a := clampf(split_t / 0.6, 0.0, 1.0)
	var line := tr("HUD_SPLIT") % [int(split.sector), Flow.clock_text(float(split.time))]
	var dcol := Color(0.85, 0.88, 1.0, a)
	var prev := float(split.get("best", -1.0))
	if prev >= 0.0:
		var d := float(split.time) - prev
		line += "  " + ("−" if d < 0.0 else "+") + Flow.clock_text(absf(d))
		dcol = (SignalColors.good() if d < 0.0 else SignalColors.bad())
		dcol.a = a
	draw_rect(Rect2(x, y + 11.0, 104.0, 10.0), Color(0.03, 0.04, 0.12, 0.72 * a))
	_fit_text(font, Vector2(x + 3.0, y + 18.5), line, 98.0, mini(Settings.fs(7), 9), dcol, HORIZONTAL_ALIGNMENT_LEFT)

## Eine Zeile der Landeanzeige: Symbol (Pfeil nach unten = Sinken, Doppelpfeil = seitwärts, Winkel = Neigung), Balken, Grenzmarke.
func _gauge_row(i: int, ratio: float, col: Color) -> void:
	var gx := 588.0
	var gw := 49.0
	var gy := 1.0 + i * 5.0
	var h := 3.6
	var ic := Color("#d8e0ff")
	var ix := 578.0
	var my := gy + h * 0.5
	match i:
		0:
			draw_line(Vector2(ix + 3.5, gy - 0.3), Vector2(ix + 3.5, gy + h), ic, 0.67)
			draw_polyline(PackedVector2Array([Vector2(ix + 1.5, gy + h - 1.8), Vector2(ix + 3.5, gy + h + 0.2), Vector2(ix + 5.5, gy + h - 1.8)]), ic, 0.67)
		1:
			draw_line(Vector2(ix, my), Vector2(ix + 7, my), ic, 0.67)
			draw_polyline(PackedVector2Array([Vector2(ix + 1.6, my - 1.6), Vector2(ix, my), Vector2(ix + 1.6, my + 1.6)]), ic, 0.67)
			draw_polyline(PackedVector2Array([Vector2(ix + 5.4, my - 1.6), Vector2(ix + 7, my), Vector2(ix + 5.4, my + 1.6)]), ic, 0.67)
		2:
			draw_line(Vector2(ix, gy + h), Vector2(ix + 7, gy + h), ic, 0.67)
			draw_line(Vector2(ix, gy + h), Vector2(ix + 6, gy - 0.2), ic, 0.67)
	draw_rect(Rect2(gx - 0.67, gy - 0.67, gw + 1.34, h + 1.34), Color("#0c0f24"))
	draw_rect(Rect2(gx, gy, gw, h), Color("#2a3266"))
	var fill := gw * minf(ratio / 2.0, 1.0)
	var half := gw * 0.5
	draw_rect(Rect2(gx, gy, minf(fill, half), h), col)
	var x := gx + half
	var k := 0
	while x < gx + fill:
		draw_rect(Rect2(x, gy, minf(1.34, gx + fill - x), h), col if k % 2 == 0 else col.darkened(0.6))
		x += 1.34
		k += 1
	draw_rect(Rect2(gx + half - 0.67, gy - 0.67, 1.34, h + 1.34), Color.WHITE)

## Option „Große Schrift“: Untertitel und Hinweise stehen nicht in der schmalen unteren Zeile, sondern in einem Kasten mit großer Schrift
## knapp über dem unteren HUD-Streifen (bis zu drei Zeilen, mittig).
func _big_caption(text: String, col: Color) -> void:
	var f := Fonts.ui
	var sz := Settings.fs(9)
	var w := 560.0
	var lines := _wrap_lines(f, text, w - 16.0, sz)
	while lines.size() > 3 and sz > 9:
		sz -= 1
		lines = _wrap_lines(f, text, w - 16.0, sz)
	var lh := float(sz) + 3.0
	var h := 6.0 + lh * float(lines.size())
	var x := (size.x - w) * 0.5
	var y := BOT_Y - 3.0 - h
	if run.sim.pos.y > run.level.pixel_size().y * 0.55:
		y = 19.0                                   # Taxi in der unteren Hälfte: Kasten oben, damit er Plattformen unten nicht verdeckt
	draw_rect(Rect2(x, y, w, h), Color(0.04, 0.06, 0.16, 0.82 * col.a))
	draw_rect(Rect2(x, y, w, 1.0), Color(1.0, 0.88, 0.58, 0.55 * col.a))
	for i in lines.size():
		draw_string(f, Vector2(x + 8.0, y + 2.0 + lh * float(i + 1) - 2.0), lines[i], HORIZONTAL_ALIGNMENT_LEFT, w - 16.0, sz, col)

## Zeilenumbruch nach Pixelbreite.
func _wrap_lines(f: Font, text: String, width: float, sz: int) -> Array:
	var out: Array = []
	var line := ""
	for word in text.split(" "):
		var cand := word if line == "" else line + " " + word
		if f.get_string_size(cand, HORIZONTAL_ALIGNMENT_LEFT, -1, sz).x > width and line != "":
			out.append(line)
			line = word
		else:
			line = cand
	if line != "":
		out.append(line)
	return out

## Text, der in `width` passen muss: Schriftgröße schrumpft bis 6 px, damit nichts abgeschnitten wird oder überläuft.
func _fit_text(f: Font, pos: Vector2, text: String, width: float, fs: int, col: Color, align: int) -> void:
	var sz := fs
	while sz > 6 and f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, sz).x > width:
		sz -= 1
	draw_string(f, pos, text, align, width, sz, col)

## „Patient verloren“ im unteren HUD rechts (dort, wo sonst Faktor und Preis stehen): roter Streifen mit EKG, das dreimal schlägt und
## in die Nulllinie übergeht, dazu „PATIENT VERLOREN“ und die Strafe. Blinkender Rand.
func _draw_patient_lost() -> void:
	var a := lost_age
	var fade := minf(1.0, a / 0.15) * clampf((LOST_TOTAL - a) / 0.7, 0.0, 1.0)
	var x0 := 316.0
	var w := 320.0
	var y0 := BOT_Y
	var h := 13.0
	var calm: bool = Settings.values.reduce_motion
	var blink := 0.6 if calm else 0.5 + 0.5 * sin(a * 9.0)
	draw_rect(Rect2(x0 - 1, y0 - 1, w + 2, h + 2), Color(0.02, 0.0, 0.02, 0.95 * fade))
	draw_rect(Rect2(x0, y0, w, h), Color(0.3, 0.02, 0.05, 0.96 * fade))
	draw_rect(Rect2(x0, y0, w, h), Color(1.0, 0.25 + 0.25 * blink, 0.3, fade), false, 1.0)
	# EKG-Spur links im Streifen
	var tx0 := x0 + 4.0
	var tw := 78.0
	var ty := y0 + h * 0.5 + 1.0
	var amp := clampf(1.0 - (a - 0.9) / 1.0, 0.0, 1.0)
	var pts := PackedVector2Array()
	for i in 40:
		var u := float(i) / 39.0
		var ph_ := fposmod(u * 2.0 - a * 1.1, 1.0)
		var spike := exp(-pow((ph_ - 0.30) * 18.0, 2.0)) - exp(-pow((ph_ - 0.38) * 14.0, 2.0)) * 0.35 + exp(-pow((ph_ - 0.62) * 8.0, 2.0)) * 0.15
		pts.append(Vector2(tx0 + u * tw, ty - spike * 5.0 * amp))
	var col := Color(0.4, 1.0, 0.5, fade).lerp(Color(1.0, 0.3, 0.3, fade), 1.0 - amp)
	draw_polyline(pts, col, 1.0)
	var dot_a := 1.0 if amp > 0.0 else (0.4 + 0.6 * blink)
	draw_circle(Vector2(tx0 + tw, pts[39].y), 1.4, Color(col.r, col.g, col.b, dot_a * fade))
	# Text: Titel, Name und Strafe
	var label := "%s  %s  −¢%d" % [tr("HUD_PATIENT_LOST"), lost_name, lost_fee]
	_fit_text(font, Vector2(x0 + tw + 10.0, y0 + 10.0), label, w - tw - 16.0, 10, Color(1.0, 0.92, 0.92, fade), HORIZONTAL_ALIGNMENT_LEFT)

## Ergebnisansicht nach dem Level: bleibt stehen, bis der Spieler bestätigt (Enter/A).
## Aufbau (Runde 75): abgedunkeltes Bild, Tafel mit Kopfband; darunter die drei Medaillen, dann zwei Karten – links die Zeit,
## rechts die Abrechnung als Rechnung (Fahrpreise, Abzüge, Ergebnis an einer Stelle) –, unten Kontostand und Punkte, zuletzt der Weiter-Hinweis.
## Abzüge von 0 stehen gedämpft mit „–“ da, damit der Blick auf das fällt, was wirklich etwas gekostet hat.
func _draw_result() -> void:
	if result.has("shift"):
		_draw_shift_result()
		return
	if result.has("day"):
		_draw_day_result()
		return
	var m: Dictionary = result.medals
	var ui := Fonts.ui
	var counted: bool = result.get("counted", true)
	var pw := 400.0
	var ph := 246.0                                       # Runde 84: Abrechnung mit Spritzeile (vorher 238)
	var px := roundf(size.x * 0.5 - pw * 0.5)
	var py := roundf(size.y * 0.5 - ph * 0.5)
	var accent := Color("#5dff9a") if counted else Color("#ffb02e")
	draw_rect(_full_rect(), Color(0.0, 0.0, 0.03, 0.6))                        # Spielbild abdunkeln (bis zum Fensterrand, auch Ultrawide)
	_shift_panel(px, py, pw, ph, 38.0, Color(0.08, 0.2, 0.19, 1.0) if counted else Color(0.26, 0.14, 0.08, 1.0), accent)
	draw_string(font, Vector2(px, py + 20.0), tr("HUD_COMPLETE") if counted else tr("RES_NOT_COUNTED"), HORIZONTAL_ALIGNMENT_CENTER, pw, 16, accent)
	var lname: String = run.level.display_name()
	_fit_text(ui, Vector2(px + 12.0, py + 33.0), (tr("COMMUNITY_TAG") + " · " + lname if Flow.community else (tr("LVL_NUM") + " · %s") % [run.level.number, lname]), pw - 24.0, 10, Color("#c9cfee"), HORIZONTAL_ALIGNMENT_CENTER)
	var ix := px + 12.0                                                          # Innenrand
	var iw := pw - 24.0
	# ---- Medaillen: drei gleich breite Karten
	var items := [["time", tr("MEDAL_TIME"), tr("MEDAL_TIME_D")], ["clean", tr("MEDAL_CLEAN"), tr("MEDAL_CLEAN_D")], ["pro", tr("MEDAL_PRO"), tr("MEDAL_PRO_D") % int(round(Tuning.pro_share(run.level.sector) * 100.0))]]
	var my := py + 46.0
	var mgap := 6.0
	var cw := (iw - mgap * 2.0) / 3.0
	for i in items.size():
		var cx := ix + float(i) * (cw + mgap)
		var got: bool = m[items[i][0]]
		_rbox(Rect2(cx, my, cw, 32.0), Color(0.15, 0.15, 0.3, 0.98) if got else Color(0.08, 0.1, 0.22, 0.95), 6, Color("#ffd24a") if got else Color("#2e3870"), 1)
		_star(Vector2(cx + 15.0, my + 16.0), 8.0, Color("#ffd24a") if got else Color("#3e4678"), got)
		_fit_text(ui, Vector2(cx + 28.0, my + 14.0), items[i][1], cw - 32.0, 11, Color("#ffe9a0") if got else Color("#7c86bb"), HORIZONTAL_ALIGNMENT_LEFT)
		_fit_text(ui, Vector2(cx + 28.0, my + 25.0), items[i][2], cw - 32.0, 8, Color("#b4c0ff") if got else Color("#646d9e"), HORIZONTAL_ALIGNMENT_LEFT)
	# ---- zwei Karten: Zeit | Abrechnung
	var ky := my + 40.0
	var kh := 96.0
	var kw := (iw - mgap) * 0.5
	var lx := ix
	var rx := ix + kw + mgap
	var card_bg := Color(0.09, 0.12, 0.27, 0.95)
	var card_edge := Color("#2e3870")
	_rbox(Rect2(lx, ky, kw, kh), card_bg, 6, card_edge, 1)
	_rbox(Rect2(rx, ky, kw, kh), card_bg, 6, card_edge, 1)
	var head_col := Color("#7c86bb")
	# Zeit: große Zahl, Balken mit Zielmarke, darunter Ziel und Bestzeit
	var tl := lx + 10.0
	var tw := kw - 20.0
	draw_string(ui, Vector2(tl, ky + 13.0), tr("RES_H_TIME"), HORIZONTAL_ALIGNMENT_LEFT, tw, 8, head_col)
	var t_ok := Run.time_ok(float(result.time), float(result.target))      # wie die Medaille: ganze Sekunden, wie angezeigt
	var tcol := SignalColors.good() if t_ok else SignalColors.bad(Color("#ff9a7a"))
	draw_string(font, Vector2(tl, ky + 37.0), "%d s" % int(result.time), HORIZONTAL_ALIGNMENT_LEFT, tw, 20, tcol)
	draw_string(ui, Vector2(tl, ky + 36.0), tr("RES_TARGET") % int(result.target), HORIZONTAL_ALIGNMENT_RIGHT, tw, 9, Color("#a9b8ff"))      # Zeitziel neben der Zeit
	var bar_y := ky + 46.0
	var frac := clampf(float(result.time) / maxf(float(result.target) * 1.5, 1.0), 0.0, 1.0)
	_rbox(Rect2(tl, bar_y, tw, 5.0), Color("#232a52"), 2)
	if frac > 0.0:
		_rbox(Rect2(tl, bar_y, maxf(tw * frac, 4.0), 5.0), tcol, 2)
	var mark := tl + tw * (1.0 / 1.5)                              # Zeitziel-Marke bei 100 %
	draw_rect(Rect2(mark - 0.75, bar_y - 3.0, 1.5, 11.0), Color.WHITE)
	var best_line := tr("RES_NEW_BEST") if (float(result.best) <= 0.0 or float(result.time) < float(result.best)) else tr("RES_BEST") % int(result.best)
	if not counted:
		best_line = tr("MSG_NOT_COUNTED")
	if result.get("solved", false):
		best_line = tr("RES_SOLVED")
	var best_col := Color("#ffe14a") if best_line == tr("RES_NEW_BEST") else (Color("#ffb02e") if not counted else Color("#8a93c9"))
	if ui.get_string_size(best_line, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x > tw:          # langer Hinweis (nicht gewertet, selbst gelöst): zwei Zeilen
		draw_multiline_string(ui, Vector2(tl, ky + 64.0), best_line, HORIZONTAL_ALIGNMENT_LEFT, tw, 8, 2, best_col)
	else:
		draw_string(ui, Vector2(tl, ky + 70.0), best_line, HORIZONTAL_ALIGNMENT_LEFT, tw, 10, best_col)
	# Abrechnung: Fahrpreise minus Abzüge = Ergebnis
	var al := rx + 10.0
	var aw := kw - 20.0
	draw_string(ui, Vector2(al, ky + 13.0), tr("RES_H_LEDGER"), HORIZONTAL_ALIGNMENT_LEFT, aw, 8, head_col)
	var earned := float(result.earned)
	draw_string(ui, Vector2(al, ky + 26.0), tr("RES_FARES"), HORIZONTAL_ALIGNMENT_LEFT, aw, 9, Color("#d8e0ff"))
	draw_string(ui, Vector2(al, ky + 26.0), "+¢%d" % int(earned), HORIZONTAL_ALIGNMENT_RIGHT, aw, 9, Color("#ffe14a") if earned > 0.0 else Color("#5a628f"))
	_fit_text(ui, Vector2(al, ky + 35.0), tr("RES_JOBS") % [int(result.get("delivered", 0)), int(result.get("jobs", 0)), int(result.get("extras", 0))], aw, 7, Color("#7c86bb"), HORIZONTAL_ALIGNMENT_LEFT)
	var rows := [[tr("RES_FUEL"), float(result.get("fuel", 0.0))], [tr("RES_REPAIR"), float(result.get("repair", 0.0))], [tr("RES_TAXIS"), float(result.get("taxi_fees", 0.0))], [tr("RES_MISSED"), float(result.get("missed_fees", 0.0))]]
	for i in rows.size():
		var yy := ky + 47.0 + float(i) * 9.0
		var amt: float = rows[i][1]
		var paid := amt > 0.0
		draw_string(ui, Vector2(al, yy), rows[i][0], HORIZONTAL_ALIGNMENT_LEFT, aw - 40.0, 8, Color("#a9b3e8") if paid else Color("#4e5788"))
		draw_string(ui, Vector2(al, yy), "−¢%d" % int(amt) if paid else "–", HORIZONTAL_ALIGNMENT_RIGHT, aw, 8, Color("#ff9a7a") if paid else Color("#4e5788"))
	draw_rect(Rect2(al, ky + 79.0, aw, 1.0), Color("#3a4580"))
	var net := float(result.get("net", 0.0))
	draw_string(ui, Vector2(al, ky + 91.0), tr("RES_NET_ROW"), HORIZONTAL_ALIGNMENT_LEFT, aw - 70.0, 9, Color("#d8e0ff"))
	draw_string(font, Vector2(al, ky + 92.0), "%s¢%d" % ["+" if net >= 0.0 else "−", int(absf(net))], HORIZONTAL_ALIGNMENT_RIGHT, aw, 13, SignalColors.good() if net >= 0.0 else SignalColors.bad(Color("#ff6a4a")))
	# ---- Fußband: Kontostand links, Punkte rechts
	var by := ky + kh + 8.0
	var bh := 28.0
	_rbox(Rect2(ix, by, iw, bh), Color(0.12, 0.16, 0.34, 0.95), 6, Color("#3a4580"), 1)
	draw_string(ui, Vector2(ix + 10.0, by + 11.0), tr("RES_H_BALANCE"), HORIZONTAL_ALIGNMENT_LEFT, 120.0, 8, head_col)
	draw_string(font, Vector2(ix + 10.0, by + 23.0), "¢%d" % int(result.get("balance", 0.0)), HORIZONTAL_ALIGNMENT_LEFT, 150.0, 12, Color("#ffe14a"))
	var score := int(result.get("score", 0))
	var best_score := int(result.get("best_score", 0))
	var sr := ix + iw - 10.0                                                     # rechte Kante der Punkte
	draw_string(ui, Vector2(sr - 200.0, by + 11.0), tr("RES_H_SCORE"), HORIZONTAL_ALIGNMENT_RIGHT, 200.0, 8, head_col)
	draw_string(font, Vector2(sr - 120.0, by + 24.0), "%d" % score, HORIZONTAL_ALIGNMENT_RIGHT, 120.0, 16, Color("#ffffff"))
	var sw := font.get_string_size("%d" % score, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
	var best_txt := tr("RES_BEST_SCORE") % best_score
	draw_string(ui, Vector2(sr - sw - 130.0, by + 23.0), best_txt, HORIZONTAL_ALIGNMENT_RIGHT, 122.0, 8, Color("#ffe14a") if score > 0 and score >= best_score else Color("#8a93c9"))
	# ---- Weiter-Hinweis
	var blink := 0.65 + 0.35 * sin(result_age * 4.0)
	draw_string(ui, Vector2(px, py + ph - 11.0), tr("RES_CONTINUE") if next_exists else tr("RES_TO_MENU"), HORIZONTAL_ALIGNMENT_CENTER, pw, 10, Color(0.66, 0.72, 1.0, blink))

var _box_cache := {}

## Abgerundetes Feld (optional mit Rand); `top_only` rundet nur die oberen Ecken (Kopfband).
func _rbox(r: Rect2, bg: Color, radius := 6, border := Color(0, 0, 0, 0), bw := 0, top_only := false) -> void:
	var key := "%s|%s|%d|%d|%s" % [bg.to_html(true), border.to_html(true), radius, bw, top_only]
	var sb: StyleBoxFlat = _box_cache.get(key)
	if sb == null:
		sb = StyleBoxFlat.new()
		sb.bg_color = bg
		if top_only:
			sb.corner_radius_top_left = radius
			sb.corner_radius_top_right = radius
		else:
			sb.set_corner_radius_all(radius)
		if bw > 0:
			sb.border_color = border
			sb.set_border_width_all(bw)
		sb.anti_aliasing = true
		_box_cache[key] = sb
	draw_style_box(sb, r)

## Zahl groß, dahinter klein „von N“.
func _num_of(pos: Vector2, num: String, of: String, big: int, col: Color) -> void:
	draw_string(font, pos, num, HORIZONTAL_ALIGNMENT_LEFT, -1, big, col)
	var w := font.get_string_size(num, HORIZONTAL_ALIGNMENT_LEFT, -1, big).x
	draw_string(Fonts.ui, pos + Vector2(w + 3.0, 0), of, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color("#8a93c9"))

## Farbe eines Teilwerts (Anteil des Höchstwerts): voll = grün, mittel = hell, schwach = orange.
static func share_color(frac: float) -> Color:
	if frac >= 0.9:
		return Color("#7dffb0")
	if frac >= 0.6:
		return Color("#d8e0ff")
	return Color("#ffa070")

## Tafel mit Schatten, Rand und Kopfband.
func _shift_panel(px: float, py: float, pw: float, ph: float, head_h: float, head_col: Color, line_col: Color) -> void:
	_rbox(Rect2(px - 3, py - 2, pw + 6, ph + 8), Color(0.01, 0.02, 0.06, 0.55), 14)
	_rbox(Rect2(px, py, pw, ph), Color(0.06, 0.08, 0.2, 0.98), 11, Color("#3a4580"), 1)
	_rbox(Rect2(px + 1, py + 1, pw - 2, head_h), head_col, 10, Color(0, 0, 0, 0), 0, true)
	draw_rect(Rect2(px + 1, py + head_h + 1, pw - 2, 1.0), line_col)

## Auswertung der ganzen Schicht: jede geflogene Karte als Zeile (Wartezeit, Landungen, Hülle, Vorbeiflüge, Punkte, jeweils mit Höchstwert in der Kopfzeile),
## darunter Karten, übrige Taxis, übrige Credits und die Gesamtnote. Nicht geflogene Karten stehen als leere Zeile da.
func summary_visible() -> bool:
	return (game_over and not shift_final.is_empty()) or (run.result == Run.Result.COMPLETE and result.has("shift") and not (result.get("shift_final", {}) as Dictionary).is_empty())

func _draw_shift_summary(fin: Dictionary, aborted: bool) -> void:
	var ui := Fonts.ui
	var pw := 560.0
	var ph := 332.0
	var px := size.x * 0.5 - pw * 0.5
	var py := size.y * 0.5 - ph * 0.5
	draw_rect(_full_rect(), Color(0, 0, 0, 0.5))
	_shift_panel(px, py, pw, ph, 38.0, Color(0.09, 0.13, 0.32, 1.0) if not aborted else Color(0.28, 0.1, 0.13, 1.0), Color("#6fa8ff") if not aborted else Color("#ff6a5a"))
	draw_string(font, Vector2(px, py + 20.0), tr("SHIFT_ABORTED") if aborted else tr("SHIFT_DONE"), HORIZONTAL_ALIGNMENT_CENTER, pw, 16, Color("#ff8a7a") if aborted else Color("#8fc0ff"))
	var stamp := NightShift.format_stamp(String(fin.get("date", Daily.today())), int(fin.get("hour", 0)), int(fin.get("minute", 0)), TranslationServer.get_locale().substr(0, 2))
	draw_string(ui, Vector2(px, py + 33.0), tr("SHIFT_FIN_SUB") % stamp, HORIZONTAL_ALIGNMENT_CENTER, pw, 9, Color("#c9cfff"))
	var lang := TranslationServer.get_locale().substr(0, 2)
	var results: Array = Flow.shift_results
	# Kopfzeile: Name der Spalte und ihr Höchstwert
	var rx := [px + 344.0, px + 396.0, px + 448.0, px + 500.0, px + 548.0]          # rechte Kanten: Warten | Landung | Hülle | Vorbeiflug | Punkte
	var heads := [["SHIFT_COL_WAIT", NightShift.W_WAIT], ["SHIFT_COL_LAND", NightShift.W_LANDING], ["SHIFT_COL_HULL", NightShift.W_HULL], ["SHIFT_COL_NEAR", NightShift.NEAR_POINTS * NightShift.MAX_NEAR], ["SHIFT_COL_SUM", NightShift.MAP_MAX]]
	var hy := py + 54.0
	var tx := px + 292.0                                  # rechte Kante der Zeitspalte (ohne Wertung)
	draw_string(ui, Vector2(px + 18.0, hy), tr("SHIFT_COL_MAP"), HORIZONTAL_ALIGNMENT_LEFT, 200.0, 8, Color("#7c86bb"))
	draw_string(ui, Vector2(tx - 50.0, hy - 1.0), tr("SHIFT_COL_TIME"), HORIZONTAL_ALIGNMENT_RIGHT, 50.0, 8, Color("#a9b3e8"))
	draw_string(ui, Vector2(tx - 50.0, hy + 7.0), tr("SHIFT_COL_NOSCORE"), HORIZONTAL_ALIGNMENT_RIGHT, 50.0, 7, Color("#5f689a"))
	for i in heads.size():
		draw_string(ui, Vector2(rx[i] - 50.0, hy - 1.0), tr(String(heads[i][0])), HORIZONTAL_ALIGNMENT_RIGHT, 50.0, 8, Color("#a9b3e8"))
		draw_string(ui, Vector2(rx[i] - 50.0, hy + 7.0), tr("SHIFT_COL_MAX") % int(heads[i][1]), HORIZONTAL_ALIGNMENT_RIGHT, 50.0, 7, Color("#5f689a"))
	var row_h := 15.0
	for i in NightShift.MAPS:
		var yy := hy + 20.0 + float(i) * row_h
		if i % 2 == 0:
			_rbox(Rect2(px + 10.0, yy - 11.0, pw - 20.0, row_h), Color(0.12, 0.16, 0.34, 0.55), 4)
		if i >= results.size():
			draw_string(ui, Vector2(px + 18.0, yy), "%d   –" % (i + 1), HORIZONTAL_ALIGNMENT_LEFT, 230.0, 9, Color("#4a5280"))
			continue
		var r: Dictionary = results[i]
		var nm := Loc.pick(r.get("names", {}), lang, String(r.get("id", "")))
		draw_string(ui, Vector2(px + 18.0, yy), "%d" % (i + 1), HORIZONTAL_ALIGNMENT_LEFT, 14.0, 9, Color("#7c86bb"))
		draw_string(ui, Vector2(px + 34.0, yy), (tr("LVL_NUM") + " · %s") % [int(r.get("number", 0)), nm], HORIZONTAL_ALIGNMENT_LEFT, 200.0, 9, Color("#d8e0ff"))
		draw_string(ui, Vector2(tx - 50.0, yy), NightShift.format_time(float(r.get("time", 0.0))), HORIZONTAL_ALIGNMENT_RIGHT, 50.0, 9, Color("#9aa6dd"))
		var cells := [float(r.wait) * NightShift.W_WAIT, float(r.landing) * NightShift.W_LANDING, float(r.hull) * NightShift.W_HULL, float(r.bonus), float(r.score)]
		for k in cells.size():
			var mx := float(heads[k][1])
			var txt := "%d" % int(round(cells[k])) if k != 3 else "+%d" % int(round(cells[k]))
			var col := share_color(cells[k] / mx) if k != 3 else (Color("#6fe8f0") if cells[k] > 0.0 else Color("#5f689a"))
			if k == 4:
				col = share_color(cells[k] / mx).lerp(Color("#ffe14a"), 0.35)
			draw_string(font if k == 4 else ui, Vector2(rx[k] - 50.0, yy), txt, HORIZONTAL_ALIGNMENT_RIGHT, 50.0, 10 if k == 4 else 9, col)
		var rg := NightShift.map_grade(float(r.score))                  # Note der Karte links neben den Punkten
		draw_string(font, Vector2(rx[4] - 42.0, yy), rg, HORIZONTAL_ALIGNMENT_LEFT, 12.0, 10, grade_color(rg))
	var ty := hy + 20.0 + float(NightShift.MAPS) * row_h
	draw_rect(Rect2(px + 18.0, ty - 9.0, tx - px - 18.0, 1.0), Color("#2a3266"))
	draw_string(ui, Vector2(px + 34.0, ty + 3.0), tr("SHIFT_TOTAL_TIME"), HORIZONTAL_ALIGNMENT_LEFT, 150.0, 9, Color("#7c86bb"))
	draw_string(font, Vector2(tx - 70.0, ty + 3.0), NightShift.format_time(float(fin.get("total_time", 0.0))), HORIZONTAL_ALIGNMENT_RIGHT, 70.0, 10, Color("#c9cfff"))
	var fy := ty + 16.0
	# Beiträge zur Gesamtwertung, jeweils „x von Höchstwert“
	var boxes := [
		[tr("SHIFT_SUM_MAPS"), "%d" % int(round(float(fin.map_points))), tr("SHIFT_OF") % int(NightShift.MAPS_POINTS), ""],
		[tr("SHIFT_SUM_TAXIS"), "%d" % int(round(float(fin.taxi_points))), tr("SHIFT_OF") % int(NightShift.TAXI_POINTS * NightShift.START_TAXIS), tr("SHIFT_TAXIS_LEFT") % int(fin.taxis)],
		[tr("SHIFT_SUM_CREDITS"), "%d" % int(round(float(fin.credit_points))), tr("SHIFT_OF") % int(NightShift.CREDIT_POINTS), tr("SHIFT_CREDITS_D") % int(round(float(fin.credits)))],
	]
	for i in boxes.size():
		var bx := px + 16.0 + float(i) * 118.0
		_rbox(Rect2(bx, fy, 110.0, 50.0), Color(0.1, 0.14, 0.3, 0.95), 7, Color("#3a4580"), 1)
		draw_string(ui, Vector2(bx + 8.0, fy + 12.0), boxes[i][0], HORIZONTAL_ALIGNMENT_LEFT, 100.0, 8, Color("#7c86bb"))
		_num_of(Vector2(bx + 8.0, fy + 32.0), boxes[i][1], boxes[i][2], 18, Color("#ffe14a"))
		draw_string(ui, Vector2(bx + 8.0, fy + 44.0), boxes[i][3], HORIZONTAL_ALIGNMENT_LEFT, 100.0, 8, Color("#8a93c9"))
	var g := String(fin.grade)
	_rbox(Rect2(px + 372.0, fy, 172.0, 50.0), Color(0.13, 0.17, 0.36, 0.98), 7, grade_color(g).darkened(0.35), 1)
	draw_string(ui, Vector2(px + 382.0, fy + 12.0), tr("SHIFT_TOTAL"), HORIZONTAL_ALIGNMENT_LEFT, 110.0, 8, Color("#7c86bb"))
	_num_of(Vector2(px + 382.0, fy + 33.0), "%d" % int(round(float(fin.score))), tr("SHIFT_OF") % 100, 20, Color("#ffffff"))
	draw_string(font, Vector2(px + 478.0, fy + 42.0), g, HORIZONTAL_ALIGNMENT_CENTER, 60.0, 40, grade_color(g))
	_draw_shot_button(px, py, pw, ph, 0.65 + 0.35 * sin(result_age * 4.0 if not aborted else Time.get_ticks_msec() * 0.004), tr("RES_TO_MENU"))

## Ort eines Mausereignisses in den Zeichenkoordinaten des HUD (in der Spiegelwelt hat das Spiel das Ereignis schon gespiegelt).
func event_pos(event: InputEvent) -> Vector2:
	return make_input_local(event).position if event is InputEventMouse else Vector2(-1.0e6, -1.0e6)

## Mausposition zum Überfahren von Knöpfen (Hover); in der Spiegelwelt (Bild gespiegelt) auf die Zeichenkoordinaten zurückgerechnet.
func mouse_pos() -> Vector2:
	var p := get_local_mouse_position()
	return Vector2(size.x - p.x, p.y) if mirror_view else p

## Knopf „Screenshot erstellen“ (Maus oder Rauswerfen-Taste) mit Taste bzw. Controllersymbol, darunter der Hinweis zum Weitermachen; `shot_btn` ist die Klickfläche.
func _draw_shot_button(px: float, py: float, pw: float, ph: float, blink: float, continue_text: String) -> void:
	var ui := Fonts.ui
	shot_btn = Rect2(px + pw * 0.5 - 100.0, py + ph - 42.0, 200.0, 22.0)
	if shot_hide:
		return
	var over := shot_btn.has_point(mouse_pos())
	_rbox(shot_btn, Color(0.16, 0.24, 0.5, 0.98) if over else Color(0.1, 0.16, 0.38, 0.95), 8, Color("#8fc0ff") if over else Color("#4a5aa0"), 1)
	var kind := "kb" if Controls.last_device == "keyboard" else "pad"
	var key := Controls.slot_label("eject", kind, 0)
	var label := tr("SHIFT_SHOT")
	var gid := Controls.glyph_id(key)
	var glyph := kind == "pad" and gid in ["A", "B", "X", "Y"]          # Controller: das Symbol des Knopfs statt eines Textes
	var lw := ui.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x
	var kw := 12.0 if glyph else ui.get_string_size("[%s]" % key, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x
	var x0 := shot_btn.position.x + (shot_btn.size.x - (lw + 6.0 + kw)) * 0.5
	draw_string(ui, Vector2(x0, shot_btn.position.y + 15.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("#e6ebff"))
	if glyph:
		PadGlyph.draw(self, gid, Rect2(x0 + lw + 6.0, shot_btn.position.y + 5.0, 12.0, 12.0))
	else:
		draw_string(ui, Vector2(x0 + lw + 6.0, shot_btn.position.y + 15.0), "[%s]" % key, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("#ffe14a"))
	if shot_note_t > 0.0:
		draw_string(ui, Vector2(px, py + ph - 9.0), tr("SHIFT_SHOT_DONE") % shot_note, HORIZONTAL_ALIGNMENT_CENTER, pw, 9, Color("#7dffb0"))
	else:
		draw_string(ui, Vector2(px, py + ph - 9.0), continue_text, HORIZONTAL_ALIGNMENT_CENTER, pw, 10, Color(0.66, 0.72, 1.0, blink))

## Medaillenfarbe der Tagschicht (0 keine, 1 Bronze, 2 Silber, 3 Gold).
static func medal_color(m: int) -> Color:
	return [Color("#5a628f"), Color("#d9894a"), Color("#d4dcf0"), Color("#ffd24a")][clampi(m, 0, 3)]

## Ergebnis der Tagschicht: Tagesregel und Tagesziel, Wertung mit Medaille und Schwellen, Bestwert, Serie und Belohnung.
func _draw_day_result() -> void:
	var d: Dictionary = result.day
	var ui := Fonts.ui
	var pw := 420.0
	var ph := 296.0
	var px := size.x * 0.5 - pw * 0.5
	var py := size.y * 0.5 - ph * 0.5
	_shift_panel(px, py, pw, ph, 38.0, Color(0.1, 0.2, 0.3, 1.0), Color("#5dd0ff"))
	draw_string(font, Vector2(px, py + 20.0), tr("DAY_DONE"), HORIZONTAL_ALIGNMENT_CENTER, pw, 16, Color("#8fe0ff"))
	var lname: String = run.level.display_name()
	var stamp := NightShift.format_stamp(String(d.get("date", Daily.today())), 12, 0, TranslationServer.get_locale().substr(0, 2)).split(",")[0]
	draw_string(ui, Vector2(px, py + 33.0), (tr("LVL_NUM") + " · %s · %s") % [run.level.number, lname, stamp], HORIZONTAL_ALIGNMENT_CENTER, pw, 9, Color("#c9cfff"))
	var rule := String(d.rule)
	var goal := String(d.goal)
	_draw_day_cards(px, py + 48.0, pw, rule, goal)
	# Wertung: Medaille, Zahl, Balken mit Schwellen
	var score := int(d.score)
	var medal := int(d.medal)
	var mcol := medal_color(medal)
	var cy := py + 134.0
	draw_circle(Vector2(px + 40.0, cy + 6.0), 17.0, Color(0, 0, 0, 0.5))
	draw_circle(Vector2(px + 40.0, cy + 6.0), 16.0, mcol.darkened(0.25))
	draw_circle(Vector2(px + 40.0, cy + 6.0), 12.5, mcol)
	_star(Vector2(px + 40.0, cy + 6.0), 8.0, mcol.darkened(0.45) if medal > 0 else Color("#3a4170"), medal > 0)
	_num_of(Vector2(px + 70.0, cy + 14.0), "%d" % score, "", 24, Color("#ffffff"))
	draw_string(ui, Vector2(px + 70.0, cy - 6.0), tr("DAY_H_SCORE"), HORIZONTAL_ALIGNMENT_LEFT, 80.0, 8, Color("#7c86bb"))
	_fit_text(font, Vector2(px + 130.0, cy + 6.0), tr("DAY_MEDAL_%d" % medal), 116.0, 14, mcol, HORIZONTAL_ALIGNMENT_LEFT)
	var at: Array = DayShift.MEDAL_AT.get(goal, [50, 75, 95])
	draw_string(ui, Vector2(px + 130.0, cy + 18.0), tr("DAY_THRESH") % [int(at[0]), int(at[1]), int(at[2])], HORIZONTAL_ALIGNMENT_LEFT, 180.0, 8, Color("#8a93c9"))
	var bar := Rect2(px + 254.0, cy - 2.0, pw - 254.0 - 16.0, 8.0)
	var smax := float(at[2]) * 1.25
	_rbox(bar, Color("#232a52"), 4)
	_rbox(Rect2(bar.position, Vector2(maxf(8.0, bar.size.x * clampf(float(score) / smax, 0.0, 1.0)), bar.size.y)), mcol if medal > 0 else Color("#6a729f"), 4)
	for k in 3:
		var mx := bar.position.x + bar.size.x * float(at[k]) / smax
		draw_rect(Rect2(mx - 0.5, bar.position.y - 3.0, 1.5, bar.size.y + 6.0), medal_color(k + 1))
	# Kennzahl zum Ziel
	var sd: Dictionary = d.stats
	var detail := ""
	match goal:
		"express":
			detail = tr("DAY_STAT_express") % [int(round(float(sd.time))), int(round(float(sd.target)))]
		"precision":
			detail = tr("DAY_STAT_precision") % [int(sd.perfect), int(sd.landings)]
		"clean":
			detail = tr("DAY_STAT_clean") % [int(round(float(sd.damage))), int(sd.respawns)]
		"profit":
			detail = tr("DAY_STAT_profit") % [int(round(float(sd.net))), int(round(float(sd.money_target)))]
	draw_string(ui, Vector2(px + 14.0, py + 168.0), detail, HORIZONTAL_ALIGNMENT_LEFT, pw - 28.0, 9, Color("#c9cfff"))
	draw_rect(Rect2(px + 14.0, py + 175.0, pw - 28.0, 1.0), Color("#2a3266"))
	# Bestwert, Serie
	var best_txt := tr("DAY_BEST") % int(d.best)
	draw_string(ui, Vector2(px + 14.0, py + 190.0), best_txt, HORIZONTAL_ALIGNMENT_LEFT, 180.0, 9, Color("#ffe14a") if bool(d.get("new_best", false)) else Color("#8a93c9"))
	var streak := int(d.get("streak", 0))
	draw_string(ui, Vector2(px + pw - 194.0, py + 190.0), (tr("DAY_STREAK") % streak) if streak != 1 else tr("DAY_STREAK_1"), HORIZONTAL_ALIGNMENT_RIGHT, 180.0, 9, Color("#7dffb0") if streak >= 3 else Color("#c9cfff"))
	if Settings.values.ghost:
		draw_string(ui, Vector2(px + 14.0, py + 202.0), tr("DAY_GHOST"), HORIZONTAL_ALIGNMENT_LEFT, pw - 28.0, 8, Color("#6a729f"))
	# Belohnung: frisch freigeschaltet oder die nächste
	var fresh: Array = d.get("fresh", [])
	var rw: Dictionary = d.get("reward", {})
	var rtxt := ""
	var rcol := Color("#9aa6dd")
	if not fresh.is_empty():
		rtxt = tr("MSG_UNLOCK") % ", ".join(fresh)
		rcol = Color("#7dffb0")
	elif rw.is_empty():
		rtxt = tr("DAY_ALL_REWARDS")
	else:
		var it: Dictionary = Cosmetics.item(String(rw.item))
		var nm: String = it.get("name", {}).get(TranslationServer.get_locale().substr(0, 2), String(rw.item))
		var cond := (tr("DAY_REWARD_STREAK") if String(rw.stat) == "daily_best_streak" else tr("DAY_REWARD_GOLD")) % [int(rw.min), int(rw.have)]
		rtxt = tr("DAY_NEXT_REWARD") % (nm + " – " + cond)
	_rbox(Rect2(px + 12.0, py + 212.0, pw - 24.0, 22.0), Color(0.1, 0.16, 0.3, 0.95) if fresh.is_empty() else Color(0.1, 0.26, 0.22, 0.95), 6, Color("#3a4580") if fresh.is_empty() else Color("#5dff9a"), 1)
	_fit_text(ui, Vector2(px + 20.0, py + 226.0), rtxt, pw - 40.0, 9, rcol, HORIZONTAL_ALIGNMENT_LEFT)
	_draw_shot_button(px, py, pw, ph, 0.65 + 0.35 * sin(result_age * 4.0), tr("RES_CONTINUE") if next_exists else tr("RES_TO_MENU"))

## Tagesregel und Tagesziel als zwei Karten (Auswertung und Briefing).
func _draw_day_cards(px: float, y: float, pw: float, rule: String, goal: String) -> void:
	var ui := Fonts.ui
	var cards := [[tr("DAY_H_RULE"), tr("DAY_RULE_" + rule), tr("DAY_RULE_" + rule + "_D")], [tr("DAY_H_GOAL"), tr("DAY_GOAL_" + goal), tr("DAY_GOAL_" + goal + "_D")]]
	for i in 2:
		var bx := px + 14.0 + float(i) * (pw * 0.5 - 7.0)
		_rbox(Rect2(bx, y, pw * 0.5 - 21.0, 60.0), Color(0.1, 0.14, 0.3, 0.95), 7, Color("#3a4580"), 1)
		draw_string(ui, Vector2(bx + 8.0, y + 12.0), cards[i][0], HORIZONTAL_ALIGNMENT_LEFT, 150.0, 8, Color("#7c86bb"))
		draw_string(font, Vector2(bx + 8.0, y + 28.0), cards[i][1], HORIZONTAL_ALIGNMENT_LEFT, pw * 0.5 - 38.0, 12, Color("#ffe14a") if i == 1 else Color("#9be8ff"))
		draw_multiline_string(ui, Vector2(bx + 8.0, y + 39.0), cards[i][2], HORIZONTAL_ALIGNMENT_LEFT, pw * 0.5 - 38.0, 7, 2, Color("#9aa6dd"))

## Briefing vor dem Start der Tagschicht: Regel und Ziel des Tages, so wird gewertet, Medaillen, Serie und Belohnung; Start mit A/Enter oder Klick.
func _draw_briefing() -> void:
	var d: Dictionary = brief
	var ui := Fonts.ui
	var pw := 420.0
	var ph := 286.0
	var px := size.x * 0.5 - pw * 0.5
	var py := size.y * 0.5 - ph * 0.5
	draw_rect(_full_rect(), Color(0, 0, 0, 0.55))
	_shift_panel(px, py, pw, ph, 38.0, Color(0.1, 0.2, 0.3, 1.0), Color("#5dd0ff"))
	draw_string(font, Vector2(px, py + 20.0), tr("DAY_BRIEF_TITLE"), HORIZONTAL_ALIGNMENT_CENTER, pw, 16, Color("#8fe0ff"))
	draw_string(ui, Vector2(px, py + 33.0), String(d.get("sub", "")), HORIZONTAL_ALIGNMENT_CENTER, pw, 9, Color("#c9cfff"))
	var goal := String(d.goal)
	_draw_day_cards(px, py + 48.0, pw, String(d.rule), goal)
	# so wird gewertet
	draw_string(ui, Vector2(px + 14.0, py + 124.0), tr("DAY_H_HOW"), HORIZONTAL_ALIGNMENT_LEFT, pw - 28.0, 8, Color("#7c86bb"))
	var how := tr("DAY_HOW_" + goal)
	if goal == "express":
		how = how % int(round(float(d.get("target", 0.0)) * DayShift.EXPRESS_REF))
	draw_multiline_string(ui, Vector2(px + 14.0, py + 136.0), how, HORIZONTAL_ALIGNMENT_LEFT, pw - 28.0, 9, 2, Color("#d8e0ff"))
	var at: Array = DayShift.MEDAL_AT.get(goal, [50, 75, 95])
	for k in 3:
		var mx := px + 14.0 + float(k) * 132.0
		draw_circle(Vector2(mx + 5.0, py + 166.0), 5.0, medal_color(k + 1))
		draw_string(ui, Vector2(mx + 14.0, py + 169.0), "%s %d" % [tr("DAY_MEDAL_%d" % (k + 1)), int(at[k])], HORIZONTAL_ALIGNMENT_LEFT, 110.0, 9, Color("#c9cfee"))
	draw_rect(Rect2(px + 14.0, py + 180.0, pw - 28.0, 1.0), Color("#2a3266"))
	var streak := int(d.get("streak", 0))
	draw_string(ui, Vector2(px + 14.0, py + 195.0), (tr("DAY_STREAK") % streak) if streak != 1 else tr("DAY_STREAK_1"), HORIZONTAL_ALIGNMENT_LEFT, 150.0, 9, Color("#7dffb0") if streak >= 3 else Color("#c9cfff"))
	if bool(d.get("ghost", false)):
		draw_string(ui, Vector2(px + 14.0, py + 195.0), tr("DAY_GHOST"), HORIZONTAL_ALIGNMENT_RIGHT, pw - 28.0, 9, Color("#8a93c9"))
	var rw: Dictionary = d.get("reward", {})
	var rtxt := tr("DAY_ALL_REWARDS")
	if not rw.is_empty():
		var it: Dictionary = Cosmetics.item(String(rw.item))
		var nm: String = it.get("name", {}).get(TranslationServer.get_locale().substr(0, 2), String(rw.item))
		var cond := (tr("DAY_REWARD_STREAK") if String(rw.stat) == "daily_best_streak" else tr("DAY_REWARD_GOLD")) % [int(rw.min), int(rw.have)]
		rtxt = tr("DAY_NEXT_REWARD") % (nm + " – " + cond)
	_rbox(Rect2(px + 12.0, py + 204.0, pw - 24.0, 22.0), Color(0.1, 0.16, 0.3, 0.95), 6, Color("#3a4580"), 1)
	_fit_text(ui, Vector2(px + 20.0, py + 218.0), rtxt, pw - 40.0, 9, Color("#9aa6dd"), HORIZONTAL_ALIGNMENT_LEFT)
	# Startknopf
	brief_btn = Rect2(px + pw * 0.5 - 100.0, py + ph - 42.0, 200.0, 24.0)
	var over := brief_btn.has_point(mouse_pos())
	_rbox(brief_btn, Color(0.16, 0.36, 0.3, 0.98) if over else Color(0.1, 0.26, 0.24, 0.96), 8, Color("#5dff9a") if over else Color("#3aa070"), 1)
	var kind := "kb" if Controls.last_device == "keyboard" else "pad"
	var label := tr("DAY_BRIEF_START")
	var lw := ui.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
	var kw := 12.0 if kind == "pad" else ui.get_string_size("[Enter]", HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
	var x0 := brief_btn.position.x + (brief_btn.size.x - (lw + 6.0 + kw)) * 0.5
	draw_string(ui, Vector2(x0, brief_btn.position.y + 16.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("#eafff3"))
	if kind == "pad":
		PadGlyph.draw(self, "A", Rect2(x0 + lw + 6.0, brief_btn.position.y + 6.0, 12.0, 12.0))
	else:
		draw_string(ui, Vector2(x0 + lw + 6.0, brief_btn.position.y + 16.0), "[Enter]", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("#ffe14a"))
	draw_string(ui, Vector2(px, py + ph - 9.0), tr("DAY_BRIEF_ESC"), HORIZONTAL_ALIGNMENT_CENTER, pw, 8, Color("#6a729f"))

## Steht gerade das Ergebnis der Tagschicht im Bild? (Dort gibt es den Screenshot-Knopf.)
func day_result_visible() -> bool:
	return run != null and run.result == Run.Result.COMPLETE and result.has("day")

func shot_available() -> bool:
	return summary_visible() or day_result_visible()

## Farbe einer Schichtnote.
static func grade_color(g: String) -> Color:
	match g:
		"S": return Color("#ffd24a")
		"A": return Color("#5dff9a")
		"B": return Color("#9ae86a")
		"C": return Color("#f0e060")
		"D": return Color("#ffa04a")
	return Color("#ff6a5a")

## Nachtschicht: Wertung der Karte (Wartezeit, Landungen, Hülle, Vorbeiflüge); nach der letzten Karte folgt stattdessen die Auswertung der ganzen Schicht.
func _draw_shift_result() -> void:
	var m: Dictionary = result.shift
	var fin: Dictionary = result.get("shift_final", {})
	if not fin.is_empty():
		_draw_shift_summary(fin, false)
		return
	var ui := Fonts.ui
	var pw := 400.0
	var ph := 280.0                       # Runde 83: mit Abrechnung (Fahrpreise, Reparatur, Ersatztaxi, Verpasst, Saldo)
	var px := size.x * 0.5 - pw * 0.5
	var py := size.y * 0.5 - ph * 0.5
	_shift_panel(px, py, pw, ph, 40.0, Color(0.09, 0.13, 0.32, 1.0), Color("#6fa8ff"))
	draw_string(font, Vector2(px, py + 20.0), tr("SHIFT_MAP_DONE") % [int(result.get("shift_index", 1)), NightShift.MAPS], HORIZONTAL_ALIGNMENT_CENTER, pw, 16, Color("#8fc0ff"))
	var lname: String = run.level.display_name()
	draw_string(ui, Vector2(px, py + 34.0), (tr("LVL_NUM") + " · %s") % [run.level.number, lname], HORIZONTAL_ALIGNMENT_CENTER, pw, 10, Color("#c9cfff"))
	var rows := [
		[tr("SHIFT_R_WAIT"), float(m.wait), int(round(float(m.wait) * NightShift.W_WAIT)), int(NightShift.W_WAIT), tr("SHIFT_D_WAIT") % int(round(float(m.avg_wait)))],
		[tr("SHIFT_R_LANDING"), float(m.landing), int(round(float(m.landing) * NightShift.W_LANDING)), int(NightShift.W_LANDING), tr("SHIFT_D_LANDING") % [int(m.soft), int(m.medium), int(m.hard)]],
		[tr("SHIFT_R_HULL"), float(m.hull), int(round(float(m.hull) * NightShift.W_HULL)), int(NightShift.W_HULL), tr("SHIFT_D_HULL") % int(round(float(m.damage)))],
		[tr("SHIFT_R_NEAR"), float(m.bonus) / (NightShift.NEAR_POINTS * NightShift.MAX_NEAR), int(m.bonus), int(NightShift.NEAR_POINTS * NightShift.MAX_NEAR), tr("SHIFT_D_NEAR") % int(m.near)],
	]
	for i in rows.size():
		var yy := py + 54.0 + float(i) * 28.0
		draw_string(ui, Vector2(px + 18.0, yy + 8.0), rows[i][0], HORIZONTAL_ALIGNMENT_LEFT, 150.0, 10, Color("#d8e0ff"))
		draw_string(ui, Vector2(px + 18.0, yy + 20.0), rows[i][4], HORIZONTAL_ALIGNMENT_LEFT, 150.0, 8, Color("#8a93c9"))
		var bx := px + 178.0
		var bw := 150.0
		var frac := clampf(float(rows[i][1]), 0.0, 1.0)
		_rbox(Rect2(bx, yy + 5.0, bw, 8.0), Color("#232a52"), 4)
		if frac > 0.01:
			_rbox(Rect2(bx, yy + 5.0, maxf(bw * frac, 8.0), 8.0), Color("#6fe8f0") if i == 3 else share_color(frac).darkened(0.1), 4)
		draw_string(ui, Vector2(bx + bw + 8.0, yy + 13.0), "%d" % int(rows[i][2]) if i != 3 else "+%d" % int(rows[i][2]), HORIZONTAL_ALIGNMENT_LEFT, 20.0, 10, Color("#ffe14a"))
		draw_string(ui, Vector2(bx + bw + 24.0, yy + 13.0), tr("SHIFT_OF") % int(rows[i][3]), HORIZONTAL_ALIGNMENT_LEFT, 40.0, 8, Color("#8a93c9"))
	var by := py + 172.0
	_rbox(Rect2(px + 14.0, by, pw - 28.0, 52.0), Color(0.1, 0.14, 0.3, 0.95), 8, Color("#3a4580"), 1)
	draw_string(ui, Vector2(px + 26.0, by + 13.0), tr("SHIFT_MAP_SCORE"), HORIZONTAL_ALIGNMENT_LEFT, 120.0, 8, Color("#7c86bb"))
	_num_of(Vector2(px + 26.0, by + 36.0), "%d" % int(round(float(m.score))), tr("SHIFT_OF") % int(NightShift.MAP_MAX), 22, share_color(float(m.score) / NightShift.MAP_MAX).lerp(Color("#ffe14a"), 0.35))
	draw_string(ui, Vector2(px + 26.0, by + 47.0), tr("SHIFT_TAXIS_LEFT") % Flow.lives, HORIZONTAL_ALIGNMENT_LEFT, 150.0, 8, Color("#8a93c9"))
	var mg := NightShift.map_grade(float(m.score))                      # Note der Karte, farbig wie die Schichtnote
	draw_string(ui, Vector2(px + 140.0, by + 13.0), tr("SHIFT_MAP_GRADE"), HORIZONTAL_ALIGNMENT_CENTER, 50.0, 8, Color("#7c86bb"))
	draw_string(font, Vector2(px + 140.0, by + 44.0), mg, HORIZONTAL_ALIGNMENT_CENTER, 50.0, 30, grade_color(mg))
	draw_string(ui, Vector2(px + 200.0, by + 22.0), tr("SHIFT_MAP_TIME") % NightShift.format_time(float(m.get("time", 0.0))), HORIZONTAL_ALIGNMENT_LEFT, 180.0, 9, Color("#9aa6dd"))
	draw_string(ui, Vector2(px + 200.0, by + 38.0), tr("SHIFT_NEXT") % [int(result.get("shift_index", 1)) + 1, NightShift.MAPS], HORIZONTAL_ALIGNMENT_LEFT, 180.0, 9, Color("#a9b8ff"))
	_draw_shift_ledger(px + 14.0, by + 58.0, pw - 28.0)
	var blink := 0.65 + 0.35 * sin(result_age * 4.0)
	draw_string(ui, Vector2(px, py + ph - 9.0), tr("RES_CONTINUE") if next_exists else tr("RES_TO_MENU"), HORIZONTAL_ALIGNMENT_CENTER, pw, 10, Color(0.66, 0.72, 1.0, blink))

## Nachtschicht: kurze Abrechnung der Karte in einer Leiste – Fahrpreise, Sprit, Reparatur, Ersatztaxi, verpasste Fahrgäste und Saldo (wie in der Karriere).
func _draw_shift_ledger(x: float, y: float, w: float) -> void:
	var ui := Fonts.ui
	_rbox(Rect2(x, y, w, 30.0), Color(0.08, 0.11, 0.26, 0.95), 6, Color("#3a4580"), 1)
	var earned := float(result.get("earned", 0.0))
	var net := float(result.get("net", 0.0))
	var cells := [
		[tr("RES_FARES"), "+¢%d" % int(earned), Color("#ffe14a") if earned > 0.0 else Color("#5a628f")],
		[tr("RES_FUEL"), float(result.get("fuel", 0.0))],
		[tr("RES_REPAIR"), float(result.get("repair", 0.0))],
		[tr("RES_TAXIS"), float(result.get("taxi_fees", 0.0))],
		[tr("RES_MISSED"), float(result.get("missed_fees", 0.0))],
		[tr("RES_NET_ROW"), "%s¢%d" % ["+" if net >= 0.0 else "−", int(absf(net))], SignalColors.good() if net >= 0.0 else SignalColors.bad(Color("#ff6a4a"))],
	]
	var cw := (w - 12.0) / float(cells.size())
	for i in cells.size():
		var cx := x + 6.0 + float(i) * cw
		var c: Array = cells[i]
		var txt: String
		var col: Color
		if c.size() == 2:
			var amt: float = c[1]
			txt = "−¢%d" % int(amt) if amt > 0.0 else "–"
			col = Color("#ff9a7a") if amt > 0.0 else Color("#4e5788")
		else:
			txt = c[1]
			col = c[2]
		_fit_text(ui, Vector2(cx, y + 11.0), String(c[0]), cw - 4.0, 7, Color("#8a93c9"), HORIZONTAL_ALIGNMENT_CENTER)
		_fit_text(font, Vector2(cx, y + 24.0), txt, cw - 4.0, 10, col, HORIZONTAL_ALIGNMENT_CENTER)

## Fünfzackiger Stern (Level-Abschluss-Medaille): gefüllt in Gold, wenn erreicht, sonst nur als dunkle Silhouette.
func _star(c: Vector2, r: float, col: Color, filled: bool) -> void:
	var pts := PackedVector2Array()
	for i in 10:
		var rad := r if i % 2 == 0 else r * 0.42
		var a := -PI * 0.5 + i * PI / 5.0
		pts.append(c + Vector2(cos(a), sin(a)) * rad)
	if filled:
		draw_colored_polygon(pts, col)
		draw_polyline(pts + PackedVector2Array([pts[0]]), Color("#fff3b0"), 0.7)
	else:
		draw_colored_polygon(pts, Color(col.r, col.g, col.b, 0.35))
		draw_polyline(pts + PackedVector2Array([pts[0]]), col, 0.7)

## Kennzeichen des Fahrgasttyps in der Auftragszeile: „VIP“ bzw. „NOTFALL 23 s“ (Text, damit auch ohne Farbsehen eindeutig).
func _kind_tag(job: Dictionary, left: float) -> String:
	match run.kind_of(job):
		"vip": return tr("HUD_TAG_VIP") + " "
		"emergency": return (tr("HUD_TAG_EMERGENCY_T") % int(ceilf(left)) if left >= 0.0 else tr("HUD_TAG_EMERGENCY")) + " "
	return ""
