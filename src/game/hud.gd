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
var price_flash := 0.0
var hint_text := ""
var hint_t := 0.0
var result := {}
var result_age := 0.0            # Sekunden seit Anzeige der Ergebnisansicht
var next_exists := true
var taxi_icon: Texture2D = Cosmetics.paint_texture()
var font: Font = Fonts.hud

func bind(r: Run) -> void:
	run = r

func flash_message(text: String, seconds := 2.0) -> void:
	message = text
	message_t = seconds

func subtitle(speaker: String, text: String, seconds := 2.4) -> void:
	if not Settings.values.subtitles:
		return
	sub_speaker = speaker
	sub_text = text
	sub_t = seconds

func _process(delta: float) -> void:
	message_t = maxf(0.0, message_t - delta)
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
	draw_string(font, Vector2(x + 2, y + h - 1), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color.WHITE)

func _draw() -> void:
	if run == null:
		return
	var s := run.sim
	var fuel_frac := s.fuel / Tuning.FUEL_MAX
	var low := fuel_frac < 0.25
	var blink := int(Time.get_ticks_msec() / 250) % 2 == 0
	if run.fuel_dead_t > 0.0 and run.result == Run.Result.RUNNING and blink:
		draw_string(font, Vector2(0, size.y * 0.30), tr("HUD_NO_FUEL") % maxf(0.0, Tuning.OUT_OF_FUEL_TIME - run.fuel_dead_t), HORIZONTAL_ALIGNMENT_CENTER, size.x, 14, Color("#ff4d6d"))
	_bar(8, 8, 90, 9, fuel_frac, Color("#ff4d6d") if (low and blink) else Color("#ffb02e"), tr("HUD_FUEL"))
	_bar(8, 20, 90, 9, s.hull / Tuning.HULL_MAX, Color("#5dff9a") if s.hull > 35.0 else Color("#ff4d6d"), tr("HUD_HULL"))
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
		draw_string(font, Vector2(102, 16), ptxt, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, pcol)
	draw_string(font, Vector2(8, 42), "¢ %d" % int(run.money), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("#ffe14a"))
	# Leben als kleine Taxi-Symbole
	for i in Flow.lives:
		draw_texture_rect(taxi_icon, Rect2(8 + i * 17, 47, 15, 9.4), false)
	var lname: String = run.level.names.get(TranslationServer.get_locale().substr(0, 2), run.level.id)
	draw_string(font, Vector2(size.x * 0.5 + 44, 13), "%d/99  %s" % [run.level.number, lname], HORIZONTAL_ALIGNMENT_LEFT, 200, 9, Color("#c4d0ff"))
	if run.streak >= 1:
		var stars := mini(run.streak, Tuning.COMBO_MAX)
		draw_string(font, Vector2(8, 66), "★".repeat(stars) + "  " + tr("HUD_STREAK") % [run.streak, int(round(Tuning.COMBO_STEP * stars * 100.0))], HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color("#ffe14a"))
	# Auftrag
	var job := run.current_job()
	var txt := ""
	var ex_aboard := run._extra_aboard()
	if not ex_aboard.is_empty():
		txt = tr("HUD_TAG_EXTRA") + "  " + tr("HUD_DELIVER") % [ex_aboard.actor.pname, run.target_pad()]
	elif job.is_empty():
		txt = tr("HUD_GO_EXIT") if run.exit_open else ""
	else:
		var who: String = job.get("passenger", "?")
		if run.phase == Run.Phase.CARRYING and run.is_exit_job(job):
			txt = tr("HUD_TAG_MAIN") + "  " + tr("HUD_TO_EXIT") % who
		elif run.phase == Run.Phase.CARRYING or run.phase == Run.Phase.DROPOFF:
			txt = tr("HUD_TAG_MAIN") + "  " + tr("HUD_DELIVER") % [who, run.target_pad()]
		elif run.actor != null:
			txt = tr("HUD_TAG_MAIN") + "  " + tr("HUD_PICKUP") % [who, run.target_pad()]
		else:
			txt = tr("HUD_WAIT_CALL")
	if not ex_aboard.is_empty() and not job.is_empty():     # Erinnerung an die Pflicht, solange ein Zusatzfahrgast mitfährt
		var rem := tr("HUD_MAIN_WAITING") % [job.get("passenger", "?"), job.get("to", "") if run.phase == Run.Phase.CARRYING else job.get("from", "")]
		draw_rect(Rect2(size.x * 0.5 - 130, size.y - 64, 260, 12), Color(0.05, 0.06, 0.15, 0.8))
		draw_rect(Rect2(size.x * 0.5 - 130, size.y - 64, 260, 12), Color("#c9a227"), false, 0.67)
		draw_string(font, Vector2(size.x * 0.5 - 130, size.y - 55), rem, HORIZONTAL_ALIGNMENT_CENTER, 260, 8, Color("#ffd24a"))
	if txt != "":
		draw_rect(Rect2(size.x * 0.5 - 170, size.y - 30, 340, 15), Color(0.05, 0.06, 0.15, 0.8))
		draw_rect(Rect2(size.x * 0.5 - 170, size.y - 30, 340, 15), Color("#3a4580"), false, 0.67)
		draw_string(font, Vector2(size.x * 0.5 - 170, size.y - 19), txt, HORIZONTAL_ALIGNMENT_CENTER, 340, 10, Color("#6fe8f0") if not ex_aboard.is_empty() else Color("#ffe14a"))
		if not ex_aboard.is_empty() and run.result == Run.Result.RUNNING:
			var fe := run.extra_factor(ex_aboard)
			var fce := Color("#5dff9a") if fe > 1.05 else (Color("#ffe14a") if fe > 0.8 else Color("#ff8a5a"))
			draw_string(font, Vector2(size.x * 0.5 + 40, size.y - 19), (tr("HUD_FACTOR") % fe) + "  ¢%d" % int(round(run.extra_prospect(ex_aboard))), HORIZONTAL_ALIGNMENT_RIGHT, 126, 10, fce)
		elif run.actor != null and run.result == Run.Result.RUNNING:
			var f := run.live_factor()
			var fc := Color("#5dff9a") if f > 1.05 else (Color("#ffe14a") if f > 0.8 else Color("#ff8a5a"))
			draw_string(font, Vector2(size.x * 0.5 + 40, size.y - 19), (tr("HUD_FACTOR") % f) + "  ¢%d" % int(round(run.prospect())), HORIZONTAL_ALIGNMENT_RIGHT, 126, 10, fc)
	var ey := 25.0
	for ex in run.extras:
		if int(ex.state) == Run.ES.WAIT:
			var ec := Color("#c9cfee") if float(ex.patience) > 12.0 else Color("#ff8a5a")
			draw_string(font, Vector2(size.x * 0.5 + 44, ey), tr("HUD_EXTRA") % [ex.actor.pname, ex.job.from, ex.job.to, int(round(run.extra_prospect(ex))), int(ceil(ex.patience))], HORIZONTAL_ALIGNMENT_LEFT, 220, 8, ec)
			ey += 10.0
	var done := "%d/%d" % [run.delivered, run.level.jobs.size()]
	draw_string(font, Vector2(size.x - 70, 14), done, HORIZONTAL_ALIGNMENT_RIGHT, 62, 10, Color.WHITE)
	# Landeampel: Sinkrate, Seitengeschwindigkeit, Neigung
	var gx := size.x - 74.0
	var gy := 24.0
	var rows := [
		[tr("HUD_VY"), s.vel.y, Tuning.LAND_VY, true],
		[tr("HUD_VX"), absf(s.vel.x), Tuning.LAND_VX, false],
		[tr("HUD_TILT"), rad_to_deg(absf(s.tilt)), rad_to_deg(Tuning.LAND_TILT), false],
	]
	for i in rows.size():
		var v: float = rows[i][1]
		var lim: float = rows[i][2]
		var ratio: float = clampf(v / lim, 0.0, 2.0)
		var col := Color("#5dff9a") if ratio <= 0.7 else (Color("#ffe14a") if ratio <= 1.0 else Color("#ff4d6d"))
		draw_rect(Rect2(gx - 0.67, gy + i * 8 - 0.67, 67.3, 7.3), Color("#0c0f24"))
		draw_rect(Rect2(gx, gy + i * 8, 66, 6), Color("#2a3266"))
		draw_rect(Rect2(gx + 1, gy + i * 8 + 1, 64.0 * minf(ratio / 2.0, 1.0), 4), col)
		draw_rect(Rect2(gx + 32, gy + i * 8 - 1, 1, 8), Color.WHITE)
		draw_string(font, Vector2(gx - 14, gy + i * 8 + 6), rows[i][0], HORIZONTAL_ALIGNMENT_LEFT, -1, 7, Color("#a9b8ff"))
	if sub_t > 0.0:
		var line := "%s: %s" % [sub_speaker, sub_text]
		var w := Fonts.ui.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x + 14.0
		var a := clampf(sub_t / 0.4, 0.0, 1.0)
		draw_rect(Rect2(size.x * 0.5 - w * 0.5, size.y - 52, w, 16), Color(0.05, 0.06, 0.15, 0.85 * a))
		draw_string(Fonts.ui, Vector2(size.x * 0.5 - w * 0.5 + 7, size.y - 40.5), line, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(1, 1, 1, a))
	var hint := Controls.hint_text(Controls.last_device)
	draw_string(font, Vector2(8, size.y - 5), hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color("#8a93c9"))
	if message_t > 0.0:
		draw_string(font, Vector2(0, size.y * 0.35), message, HORIZONTAL_ALIGNMENT_CENTER, size.x, 14, Color.WHITE)
	if game_over:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.6))
		draw_string(font, Vector2(0, size.y * 0.42), tr("HUD_GAME_OVER"), HORIZONTAL_ALIGNMENT_CENTER, size.x, 28, Color("#ff4d6d"))
		draw_string(font, Vector2(0, size.y * 0.42 + 20), tr("HUD_RUN_CREDITS") + ": ¢ %d" % int(run.money), HORIZONTAL_ALIGNMENT_CENTER, size.x, 12, Color("#ffe14a"))
		draw_string(font, Vector2(0, size.y * 0.42 + 40), tr("HUD_GAME_OVER_HINT"), HORIZONTAL_ALIGNMENT_CENTER, size.x, 10, Color.WHITE)
	elif run.result == Run.Result.FAILED:
		draw_string(font, Vector2(0, size.y * 0.45), tr("HUD_OUT_OF_FUEL") if run.fuel_fail else tr("HUD_CRASHED"), HORIZONTAL_ALIGNMENT_CENTER, size.x, 16, Color("#ff4d6d"))
		draw_string(font, Vector2(0, size.y * 0.45 + 16), tr("HUD_LAST_LIFE") if Flow.lives <= 1 else tr("HUD_LIFE_LOST") % (Flow.lives - 1), HORIZONTAL_ALIGNMENT_CENTER, size.x, 10, Color.WHITE)
	elif run.result == Run.Result.COMPLETE and result.is_empty():
		draw_string(font, Vector2(0, size.y * 0.42), tr("HUD_COMPLETE"), HORIZONTAL_ALIGNMENT_CENTER, size.x, 16, Color("#5dff9a"))
	if hint_t > 0.0 and hint_text != "":
		var hw := minf(Fonts.ui.get_string_size(hint_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 9).x + 16.0, size.x - 40.0)
		var ha := clampf(hint_t / 0.5, 0.0, 1.0)
		draw_rect(Rect2(size.x * 0.5 - hw * 0.5, 22, hw, 16), Color(0.04, 0.05, 0.14, 0.82 * ha))
		draw_rect(Rect2(size.x * 0.5 - hw * 0.5, 22, hw, 16), Color(0.35, 0.88, 0.82, 0.5 * ha), false, 0.67)
		draw_string(Fonts.ui, Vector2(size.x * 0.5 - hw * 0.5 + 8, 33.5), hint_text, HORIZONTAL_ALIGNMENT_LEFT, hw - 12, 9, Color(0.8, 1.0, 0.95, ha))
	if run.result == Run.Result.COMPLETE and not result.is_empty():
		_draw_result()
	if paused:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.55))

## Ergebnisansicht nach dem Level: bleibt stehen, bis der Spieler bestätigt (Enter/A).
func _draw_result() -> void:
	var m: Dictionary = result.medals
	var pw := 420.0
	var ph := 166.0
	var px := size.x * 0.5 - pw * 0.5
	var py := 62.0
	draw_rect(Rect2(px - 1, py - 1, pw + 2, ph + 2), Color("#0c0f24"))
	draw_rect(Rect2(px, py, pw, ph), Color(0.06, 0.08, 0.2, 0.93))
	draw_rect(Rect2(px, py, pw, ph), Color("#3a4580"), false, 0.8)
	var ui := Fonts.ui
	draw_string(font, Vector2(px, py + 17), tr("HUD_COMPLETE"), HORIZONTAL_ALIGNMENT_CENTER, pw, 14, Color("#5dff9a"))
	var t_line := tr("RES_TIME") % [int(result.time), int(result.target)]
	if float(result.best) > 0.0:
		t_line += "   " + (tr("RES_NEW_BEST") if float(result.time) < float(result.best) else tr("RES_BEST") % int(result.best))
	draw_string(ui, Vector2(px + 14, py + 36), t_line, HORIZONTAL_ALIGNMENT_LEFT, pw - 28, 10, Color("#c9cfee"))
	draw_string(ui, Vector2(px + 14, py + 51), tr("RES_EARNED") % [int(result.earned), int(result.get("delivered", 0)), int(result.get("jobs", 0)), int(result.get("extras", 0))], HORIZONTAL_ALIGNMENT_LEFT, pw - 28, 10, Color("#ffe14a"))
	draw_string(ui, Vector2(px + 14, py + 66), tr("RES_DEDUCT") % [int(result.get("repair", 0.0)), int(result.get("taxi_fees", 0.0)), int(result.get("missed_fees", 0.0))], HORIZONTAL_ALIGNMENT_LEFT, pw - 28, 10, Color("#ff9a7a"))
	var net := float(result.get("net", 0.0))
	draw_string(ui, Vector2(px + 14, py + 84), tr("RES_NET") % [int(net), int(result.get("balance", 0.0))], HORIZONTAL_ALIGNMENT_LEFT, pw - 28, 11, Color("#5dff9a") if net >= 0.0 else Color("#ff6a4a"))
	draw_string(ui, Vector2(px + 14, py + 99), tr("RES_SCORE") % [int(result.get("score", 0)), int(result.get("best_score", 0))], HORIZONTAL_ALIGNMENT_LEFT, pw - 28, 10, Color("#c4d0ff"))
	var items := [["time", tr("MEDAL_TIME")], ["clean", tr("MEDAL_CLEAN")], ["pro", tr("MEDAL_PRO")]]
	for i in items.size():
		var x := px + 14.0 + i * 130.0
		var got: bool = m[items[i][0]]
		var col := Color("#ffd24a") if got else Color("#5a628f")
		_star(Vector2(x + 7, py + 120), 7.0, col, got)
		draw_string(ui, Vector2(x + 19, py + 124), items[i][1], HORIZONTAL_ALIGNMENT_LEFT, -1, 10, col)
	draw_string(ui, Vector2(px, py + ph - 12), tr("RES_CONTINUE") if next_exists else tr("RES_TO_MENU"), HORIZONTAL_ALIGNMENT_CENTER, pw, 10, Color("#a9b8ff"))

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
