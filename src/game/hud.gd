extends Control
## HUD: Treibstoff, Hülle, Geld, Auftrag, Ziel-Hinweis und Landeampel. Klar getrennt von der Spielwelt.

var run: Run
var message := ""
var message_t := 0.0
var sub_speaker := ""
var sub_text := ""
var sub_t := 0.0
var paused := false
var game_over := false
var shift_total := -1            # Nachtschicht: Ergebnis der Schicht (Fahrgäste)
var over_level := 0              # Game Over im Feldzug: Level, mit dem es weitergeht
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
var taxi_icon: Texture2D = Cosmetics.paint_texture()
var font: Font = Fonts.hud

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
	lost_t = maxf(0.0, lost_t - delta)
	lost_age += delta
	price_flash = maxf(0.0, price_flash - delta * 1.6)
	if not result.is_empty():
		result_age += delta
	hint_t = maxf(0.0, hint_t - delta)
	sub_t = maxf(0.0, sub_t - delta)
	queue_redraw()

func _bar(x: float, y: float, w: float, h: float, frac: float, col: Color, label: String) -> void:
	draw_rect(Rect2(x - 1, y - 1, w + 2, h + 2), Color("#10142b"))
	draw_rect(Rect2(x, y, w, h), Color("#232a52"))
	draw_rect(Rect2(x, y, w * clampf(frac, 0.0, 1.0), h), col)
	draw_string(font, Vector2(x + 2, y + h - 1), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 7, Color.WHITE)

## Das HUD liegt nur in den Randstreifen: oben auf der Felsreihe 0 (y 0–16), unten unter der Bodenreihe (y 336–360).
## Dazwischen liegt das reine Spielfeld – nichts überdeckt Plattformen, Hindernisse oder Fahrgäste. Frei bleibt
## x 296–344 oben (Torschild). Rechts vom Tor: Level und Name, Pflichtfahrgäste (x/y), Spritpreis; ganz rechts die Landeanzeige.
const TOP_Y := 0.0
const BOT_Y := 337.0

func _draw() -> void:
	if run == null:
		return
	var s := run.sim
	var fuel_frac := s.fuel / Tuning.FUEL_MAX
	var low := fuel_frac < 0.25
	var blink := int(Time.get_ticks_msec() / 250) % 2 == 0
	if run.fuel_dead_t > 0.0 and run.result == Run.Result.RUNNING and blink:
		draw_string(font, Vector2(0, size.y * 0.30), tr("HUD_NO_FUEL") % maxf(0.0, Tuning.OUT_OF_FUEL_TIME - run.fuel_dead_t), HORIZONTAL_ALIGNMENT_CENTER, size.x, 14, Color("#ff4d6d"))
	# ---------------- oberer Streifen
	_bar(4, 4, 66, 8, fuel_frac, Color("#ff4d6d") if (low and blink) else Color("#ffb02e"), tr("HUD_FUEL"))
	_bar(75, 4, 66, 8, s.hull / Tuning.HULL_MAX, Color("#5dff9a") if s.hull > 35.0 else Color("#ff4d6d"), tr("HUD_HULL"))
	draw_string(font, Vector2(147, 12), "¢%d" % int(run.money), HORIZONTAL_ALIGNMENT_LEFT, 56, 9, Color("#ffe14a"))
	for i in Flow.lives:
		draw_texture_rect(taxi_icon, Rect2(204 + i * 11, 4.5, 10, 6.3), false)
	if run.streak >= 1:
		var stars := mini(run.streak, Tuning.COMBO_MAX)
		draw_string(font, Vector2(262, 12), "★%d +%d%%" % [run.streak, int(round(Tuning.COMBO_STEP * stars * 100.0))], HORIZONTAL_ALIGNMENT_LEFT, 34, 8, Color("#ffe14a"))
	if run.level.pads.has("F"):
		# Spritpreis (springt in zufälligen Abständen, steigt bei Berührung der Zapfsäule)
		var pf := run.fuel_price()
		var span := maxf(run.level.fuel_price_max - run.level.fuel_price_min, 0.01)
		var n := (pf - run.level.fuel_price_min) / span
		var pcol := Color("#5dff9a") if n < 0.34 else (Color("#ffe14a") if n < 0.67 else Color("#ff6a4a"))
		var ptxt := tr("HUD_PRICE") % pf
		if run.station_down():
			ptxt = tr("HUD_PUMP_DEAD")
			pcol = Color("#ff4d6d")
		if price_flash > 0.0:
			pcol = pcol.lerp(Color.WHITE, price_flash)
		draw_string(font, Vector2(494, 12), ptxt, HORIZONTAL_ALIGNMENT_LEFT, 82, 8, pcol)
	var lname: String = run.level.names.get(TranslationServer.get_locale().substr(0, 2), run.level.id)
	_fit_text(font, Vector2(374, 12), lname if run.level.tutorial else (tr("SHIFT_TAG") + "  " + lname if Flow.shift else (tr("DAILY_TAG") + "  " + lname if Flow.daily else (tr("COMMUNITY_TAG") + ("  " + tr("ED_AUTOPILOT_TAG") if Flow.editor_autopilot else "") + "  " + lname if Flow.community else "%d/99  %s" % [run.level.number, lname]))), 84.0, 8, Color("#c4d0ff"), HORIZONTAL_ALIGNMENT_LEFT)       # nur auf dem oberen Rand, nicht im Eck des Tores
	draw_string(font, Vector2(460, 12), "%d/%d" % [run.delivered, run.level.jobs.size()], HORIZONTAL_ALIGNMENT_RIGHT, 28, 9, Color.WHITE)
	# Landeampel: Sinkrate, Seitengeschwindigkeit, Neigung als drei beschriftete Balken (weiße Marke = Grenze der sicheren Landung)
	var gx := 598.0
	var gw := 39.0
	var rows := [[tr("HUD_VY"), s.vel.y, run.sim.land_vy], [tr("HUD_VX"), absf(s.vel.x), Tuning.LAND_VX], [tr("HUD_TILT"), rad_to_deg(absf(s.tilt)), rad_to_deg(Tuning.LAND_TILT)]]
	for i in rows.size():
		var v: float = rows[i][1]
		var lim: float = rows[i][2]
		if gauge_override.size() == rows.size():
			v = float(gauge_override[i]) * lim
		var ratio: float = clampf(v / lim, 0.0, 2.0)
		var col := Color("#5dff9a") if ratio <= 0.7 else (Color("#ffe14a") if ratio <= 1.0 else Color("#ff4d6d"))
		var gy := 1.6 + i * 4.8
		draw_string(font, Vector2(576, gy + 3.6), String(rows[i][0]), HORIZONTAL_ALIGNMENT_LEFT, 22, 5, Color("#aab6e8"))
		draw_rect(Rect2(gx - 0.5, gy - 0.5, gw + 1, 4.0), Color("#0c0f24"))
		draw_rect(Rect2(gx, gy, gw, 3.0), Color("#2a3266"))
		draw_rect(Rect2(gx, gy, gw * minf(ratio / 2.0, 1.0), 3.0), col)
		draw_rect(Rect2(gx + gw * 0.5 - 0.5, gy - 0.5, 1, 4.0), Color.WHITE)
	# Countdown des letzten Pflichtfahrgasts: unter dem Tor, ab 10 s rot blinkend
	if run.exit_countdown > 0.0 and run.result == Run.Result.RUNNING:
		var cd := run.exit_countdown
		var urgent := cd <= 10.0
		var ccol := Color("#ff4d6d") if (urgent and blink) else (Color("#ffb02e") if urgent else Color("#ffe14a"))
		draw_rect(Rect2(266, 51, 108, 13), Color(0.05, 0.06, 0.15, 0.85))
		draw_rect(Rect2(266, 51, 108, 13), ccol, false, 0.8)
		draw_string(font, Vector2(266, 61), tr("HUD_EXIT_TIMER") % int(ceilf(cd)), HORIZONTAL_ALIGNMENT_CENTER, 108, 9, ccol)
	# ---------------- unterer Streifen: Auftrag (oben) und Hinweise/Untertitel (unten)
	var job := run.current_job()
	var txt := ""
	var ex_aboard := run._extra_aboard()
	if not ex_aboard.is_empty():
		var xf: String = tr("HUD_TAG_FRAGILE") + " " if ex_aboard.job.get("fragile", false) else ""
		txt = tr("HUD_TAG_EXTRA") + "  " + xf + (tr("HUD_DELIVER_H") % ex_aboard.actor.pname if run.target_pad() == "H" else tr("HUD_DELIVER") % [ex_aboard.actor.pname, run.target_pad()])
	elif job.is_empty():
		txt = tr("HUD_GO_EXIT") if run.exit_open else ""
	else:
		var who: String = job.get("passenger", "?")
		var frag: String = tr("HUD_TAG_FRAGILE") + " " if job.get("fragile", false) else ""
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
		draw_string(font, Vector2(8, BOT_Y + 10), txt, HORIZONTAL_ALIGNMENT_LEFT, 440, 10, Color("#6fe8f0") if not ex_aboard.is_empty() else Color("#ffe14a"))
		if not ex_aboard.is_empty() and run.result == Run.Result.RUNNING:
			var fe := run.extra_factor(ex_aboard)
			var fce := Color("#5dff9a") if fe > 1.05 else (Color("#ffe14a") if fe > 0.8 else Color("#ff8a5a"))
			draw_string(font, Vector2(450, BOT_Y + 10), (tr("HUD_FACTOR") % fe) + "  ¢%d" % int(round(run.extra_prospect(ex_aboard))), HORIZONTAL_ALIGNMENT_RIGHT, 182, 10, fce)
		elif run.actor != null and run.result == Run.Result.RUNNING:
			var f := run.live_factor()
			var fc := Color("#5dff9a") if f > 1.05 else (Color("#ffe14a") if f > 0.8 else Color("#ff8a5a"))
			draw_string(font, Vector2(450, BOT_Y + 10), (tr("HUD_FACTOR") % f) + "  ¢%d" % int(round(run.prospect())), HORIZONTAL_ALIGNMENT_RIGHT, 182, 10, fc)
	var row_b := BOT_Y + 21.0
	draw_rect(Rect2(2, BOT_Y + 14.0, 636, 9.0), Color(0.05, 0.06, 0.15, 0.78))      # Unterlage: die Zeile bleibt auf jedem Hintergrund lesbar
	# Untere Zeile: links Steuerungshinweis (bzw. gesprochener Untertitel/Hinweis), rechts alle Meldungen des Spiels
	if sub_t > 0.0:
		var line := "%s: %s" % [sub_speaker, sub_text]
		var a := clampf(sub_t / 0.4, 0.0, 1.0)
		_fit_text(Fonts.ui, Vector2(8, row_b), line, 330.0, 8, Color(1, 1, 1, a), HORIZONTAL_ALIGNMENT_LEFT)
	elif hint_t > 0.0 and hint_text != "":
		var ha := clampf(hint_t / 0.5, 0.0, 1.0)
		_fit_text(Fonts.ui, Vector2(8, row_b), hint_text, 330.0, 8, Color(0.8, 1.0, 0.95, ha), HORIZONTAL_ALIGNMENT_LEFT)
	else:
		draw_string(font, Vector2(8, row_b), Controls.hint_text(Controls.last_device), HORIZONTAL_ALIGNMENT_LEFT, 330, 7, Color("#b4bcea"))
	if message_t > 0.0:
		var ma := clampf(message_t / 0.4, 0.0, 1.0)
		_fit_text(font, Vector2(340, row_b), message, 296.0, 9, Color(1.0, 0.95, 0.7, ma), HORIZONTAL_ALIGNMENT_RIGHT)
	elif not ex_aboard.is_empty() and not job.is_empty():     # Erinnerung an die Pflicht, solange ein Zusatzfahrgast mitfährt
		var rem := tr("HUD_MAIN_WAITING") % [job.get("passenger", "?"), job.get("to", "") if run.phase == Run.Phase.CARRYING else job.get("from", "")]
		_fit_text(font, Vector2(340, row_b), rem, 296.0, 8, Color("#ffd24a"), HORIZONTAL_ALIGNMENT_RIGHT)
	if game_over:
		draw_rect(_full_rect(), Color(0, 0, 0, 0.6))
		draw_string(font, Vector2(0, size.y * 0.42), tr("HUD_GAME_OVER"), HORIZONTAL_ALIGNMENT_CENTER, size.x, 28, Color("#ff4d6d"))
		var over_line := tr("HUD_RUN_CREDITS") + ": ¢ %d" % int(run.money)
		if shift_total >= 0:
			over_line = tr("HUD_SHIFT_RESULT") % [shift_total, int(Save.data.stats.get("shift_best", 0))]
		elif over_level > 0:
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
	if paused:
		draw_rect(_full_rect(), Color(0, 0, 0, 0.55))

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
func _draw_result() -> void:
	var m: Dictionary = result.medals
	var ui := Fonts.ui
	var pw := 384.0
	var ph := 236.0
	var px := size.x * 0.5 - pw * 0.5
	var py := size.y * 0.5 - ph * 0.5
	# Tafel mit Doppelrand und Kopfband
	draw_rect(Rect2(px - 3, py - 3, pw + 6, ph + 6), Color(0.02, 0.03, 0.09, 0.7))
	draw_rect(Rect2(px - 1, py - 1, pw + 2, ph + 2), Color("#0c0f24"))
	draw_rect(Rect2(px, py, pw, ph), Color(0.06, 0.08, 0.2, 0.96))
	draw_rect(Rect2(px, py, pw, 38.0), Color(0.1, 0.22, 0.2, 0.95))
	draw_rect(Rect2(px, py + 38.0, pw, 1.0), Color("#5dff9a"))
	draw_rect(Rect2(px, py, pw, ph), Color("#3a4580"), false, 0.8)
	var counted: bool = result.get("counted", true)
	if not counted:
		draw_rect(Rect2(px, py, pw, 38.0), Color(0.26, 0.14, 0.08, 0.95))
		draw_rect(Rect2(px, py + 38.0, pw, 1.0), Color("#ffb02e"))
	draw_string(font, Vector2(px, py + 19.0), tr("HUD_COMPLETE") if counted else tr("RES_NOT_COUNTED"), HORIZONTAL_ALIGNMENT_CENTER, pw, 16, Color("#5dff9a") if counted else Color("#ffb02e"))
	var lname: String = run.level.names.get(TranslationServer.get_locale().substr(0, 2), run.level.id)
	draw_string(ui, Vector2(px, py + 33.0), (tr("COMMUNITY_TAG") + " · " + lname if Flow.community else "Level %d · %s" % [run.level.number, lname]), HORIZONTAL_ALIGNMENT_CENTER, pw, 10, Color("#c9cfee"))
	# Medaillen als drei Karten
	var items := [["time", tr("MEDAL_TIME"), tr("MEDAL_TIME_D")], ["clean", tr("MEDAL_CLEAN"), tr("MEDAL_CLEAN_D")], ["pro", tr("MEDAL_PRO"), tr("MEDAL_PRO_D")]]
	var cw := 112.0
	var gap := (pw - 28.0 - cw * 3.0) / 2.0
	for i in items.size():
		var cx := px + 14.0 + float(i) * (cw + gap)
		var got: bool = m[items[i][0]]
		var edge := Color("#ffd24a") if got else Color("#3a4580")
		draw_rect(Rect2(cx, py + 48.0, cw, 34.0), Color(0.12, 0.14, 0.3, 0.9) if got else Color(0.07, 0.09, 0.2, 0.9))
		draw_rect(Rect2(cx, py + 48.0, cw, 34.0), edge, false, 1.0 if got else 0.7)
		_star(Vector2(cx + 20.0, py + 62.0), 9.0, Color("#ffd24a") if got else Color("#4a5280"), got)
		draw_string(ui, Vector2(cx + 36.0, py + 66.0), items[i][1], HORIZONTAL_ALIGNMENT_LEFT, cw - 40.0, 11, Color("#ffe9a0") if got else Color("#6a729f"))
		draw_string(ui, Vector2(cx + 6.0, py + 78.0), items[i][2], HORIZONTAL_ALIGNMENT_CENTER, cw - 12.0, 7, Color("#a9b8ff") if got else Color("#7c86bb"))
	# linke Spalte: Zeit mit Balken, rechte Spalte: Einnahmen und Abzüge
	var lx := px + 16.0
	var rx := px + pw * 0.5 + 8.0
	var colw := pw * 0.5 - 24.0
	draw_string(ui, Vector2(lx, py + 100.0), tr("RES_H_TIME"), HORIZONTAL_ALIGNMENT_LEFT, colw, 8, Color("#7c86bb"))
	var t_ok := float(result.time) <= float(result.target)
	draw_string(font, Vector2(lx, py + 120.0), "%d s" % int(result.time), HORIZONTAL_ALIGNMENT_LEFT, colw, 18, Color("#5dff9a") if t_ok else Color("#ff9a7a"))
	var bar_y := py + 128.0
	var frac := clampf(float(result.time) / maxf(float(result.target) * 1.5, 1.0), 0.0, 1.0)
	draw_rect(Rect2(lx, bar_y, colw, 5.0), Color("#232a52"))
	draw_rect(Rect2(lx, bar_y, colw * frac, 5.0), Color("#5dff9a") if t_ok else Color("#ff9a7a"))
	var tx := lx + colw * (1.0 / 1.5)                              # Zeitziel-Marke bei 100 %
	draw_rect(Rect2(tx - 0.5, bar_y - 3.0, 1.5, 11.0), Color.WHITE)
	draw_string(ui, Vector2(lx, py + 148.0), tr("RES_TARGET") % int(result.target), HORIZONTAL_ALIGNMENT_LEFT, colw, 9, Color("#a9b8ff"))
	var best_line := tr("RES_NEW_BEST") if (float(result.best) <= 0.0 or float(result.time) < float(result.best)) else tr("RES_BEST") % int(result.best)
	if not counted:
		best_line = tr("MSG_NOT_COUNTED")
	if result.get("solved", false):
		best_line = tr("RES_SOLVED")
	_fit_text(ui, Vector2(lx, py + 161.0), best_line, colw, 9, Color("#ffe14a") if best_line == tr("RES_NEW_BEST") else Color("#8a93c9"), HORIZONTAL_ALIGNMENT_LEFT)
	draw_rect(Rect2(px + pw * 0.5 - 0.5, py + 92.0, 1.0, 76.0), Color("#232a52"))
	draw_string(ui, Vector2(rx, py + 100.0), tr("RES_H_EARNED"), HORIZONTAL_ALIGNMENT_LEFT, colw, 8, Color("#7c86bb"))
	draw_string(font, Vector2(rx, py + 120.0), "¢ %d" % int(result.earned), HORIZONTAL_ALIGNMENT_LEFT, colw, 18, Color("#ffe14a"))
	draw_string(ui, Vector2(rx, py + 133.0), tr("RES_JOBS") % [int(result.get("delivered", 0)), int(result.get("jobs", 0)), int(result.get("extras", 0))], HORIZONTAL_ALIGNMENT_LEFT, colw, 9, Color("#a9b8ff"))
	var rows := [[tr("RES_REPAIR"), float(result.get("repair", 0.0))], [tr("RES_TAXIS"), float(result.get("taxi_fees", 0.0))], [tr("RES_MISSED"), float(result.get("missed_fees", 0.0))]]
	for i in rows.size():
		var yy := py + 146.0 + float(i) * 10.0
		var amt: float = rows[i][1]
		var rc := Color("#ff9a7a") if amt > 0.0 else Color("#5a628f")
		draw_string(ui, Vector2(rx, yy), rows[i][0], HORIZONTAL_ALIGNMENT_LEFT, colw, 8, Color("#8a93c9"))
		draw_string(ui, Vector2(rx, yy), "−¢%d" % int(amt), HORIZONTAL_ALIGNMENT_RIGHT, colw, 8, rc)
	# Ergebnisband: Netto und Kontostand, Punkte
	var net := float(result.get("net", 0.0))
	draw_rect(Rect2(px + 12.0, py + 176.0, pw - 24.0, 24.0), Color(0.1, 0.14, 0.3, 0.9))
	draw_rect(Rect2(px + 12.0, py + 176.0, pw - 24.0, 24.0), Color("#3a4580"), false, 0.7)
	draw_string(ui, Vector2(px + 20.0, py + 186.0), tr("RES_H_NET"), HORIZONTAL_ALIGNMENT_LEFT, 80.0, 8, Color("#7c86bb"))
	draw_string(font, Vector2(px + 20.0, py + 197.0), "%s¢ %d" % ["+" if net >= 0.0 else "−", int(absf(net))], HORIZONTAL_ALIGNMENT_LEFT, 120.0, 12, Color("#5dff9a") if net >= 0.0 else Color("#ff6a4a"))
	draw_string(ui, Vector2(px + 140.0, py + 186.0), tr("RES_H_BALANCE"), HORIZONTAL_ALIGNMENT_LEFT, 90.0, 8, Color("#7c86bb"))
	draw_string(font, Vector2(px + 140.0, py + 197.0), "¢ %d" % int(result.get("balance", 0.0)), HORIZONTAL_ALIGNMENT_LEFT, 110.0, 12, Color("#ffe14a"))
	draw_string(ui, Vector2(px + 260.0, py + 186.0), tr("RES_H_SCORE"), HORIZONTAL_ALIGNMENT_LEFT, 100.0, 8, Color("#7c86bb"))
	draw_string(font, Vector2(px + 260.0, py + 197.0), "%d" % int(result.get("score", 0)), HORIZONTAL_ALIGNMENT_LEFT, 70.0, 12, Color("#c4d0ff"))
	draw_string(ui, Vector2(px + 300.0, py + 197.0), tr("RES_BEST_SCORE") % int(result.get("best_score", 0)), HORIZONTAL_ALIGNMENT_LEFT, 80.0, 8, Color("#8a93c9"))
	var blink := 0.65 + 0.35 * sin(result_age * 4.0)
	draw_string(ui, Vector2(px, py + ph - 10.0), tr("RES_CONTINUE") if next_exists else tr("RES_TO_MENU"), HORIZONTAL_ALIGNMENT_CENTER, pw, 10, Color(0.66, 0.72, 1.0, blink))

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
