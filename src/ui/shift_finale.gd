extends Control
## Finale der Nachtschicht: Das Taxi kommt durch den Sternenhimmel, fährt im Anflug das Fahrwerk aus und setzt auf dem Depot auf. Die Zentrale sagt (gesprochen und als
## Untertitel) einen Satz zur Note. Dann steigt der Fahrer aus und geht über die Brücke nach rechts; kurz vor dem Bildrand bleibt er stehen, dreht sich zur Kamera, winkt,
## lächelt, dreht sich zurück und läuft aus dem Bild. Dazu steht die Abrechnung im Bild (Note, Punkte, Karten, Taxis, Credits); die Musik („night“, rund eine Minute)
## läuft als Schleife, bis A/Enter ins Menü führt. Dev: --scene=shift_finale

const Stage := preload("res://src/core/stage.gd")
const T_VOICE := 1.2                 # Ansage der Zentrale
const T_GEAR := 5.0                  # ab hier fährt das Fahrwerk aus
const T_SINK := 6.6                  # Schlussanflug senkrecht
const T_LAND := 8.2                  # Aufsetzen
const T_DOOR := 9.0                  # die Kuppel leuchtet auf, der Fahrer macht sich bereit
const T_STAND := 9.4                 # er steht auf und steigt aus der Kuppel
const T_TOP := 9.95                  # er sitzt oben auf dem Taxi und springt
const T_GROUND := 10.45              # Landung auf dem Pad neben dem Taxi
const T_TURN := 10.65                # er dreht sich nach rechts
const T_WALK := 11.15                # und geht los
const RISE := 12.0                   # so weit steigt er aus der Kuppel (Einheiten)
const T_CARD := 9.6                  # ab hier steht die Abrechnung im Bild
const PAD := Rect2(118.0, 306.0, 144.0, 8.0)
const GROUND := 306.0                # Oberkante von Pad und Brücke
const LAND_X := 190.0
const X_OUT := LAND_X + 34.0         # hier landet er
const TAXI_S := 1.5                  # Maßstab des Taxis im Finale
const WALK_SPEED := 38.0
const DRIVER_FW := 40.0              # Bildgröße des Fahrerblatts (driver.png: 12 Bilder à 40×56)
const DRIVER_FH := 56.0
const DRIVER_S := 0.5                # Einheiten je Bildpunkt: gleiche Pixeldichte wie das Taxi im Finale (1,5 / 3)
const STOP_X := 560.0                # hier bleibt der Fahrer stehen
const OFF_X := 676.0
var bg: Texture2D = load("res://assets/art/bg_s9.png")
var taxi: Texture2D = Cosmetics.paint_texture()
var taxi_empty: Texture2D                          # dasselbe Taxi ohne Fahrer (leere Kuppel), sobald er ausgestiegen ist
var driver_tex: Texture2D = load("res://assets/art/driver.png")
var t := 0.0
var stars: Array = []
var res: Dictionary = {}
var _done := {}                      # schon ausgelöste Klänge
var radio_text := ""
var radio_until := 0.0

func _ready() -> void:
	taxi_empty = _empty_taxi()
	Music.play_theme("night")
	Music.set_layers(true, false)
	Music.duck(0.0)                                  # die Ansage senkt die Musik von selbst
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	res = Flow.shift_last_result
	if res.is_empty():                               # Dev-Aufruf ohne Schicht: Beispielwerte
		res = {"grade": "B", "score": 71.0, "maps": 9, "taxis": 4, "credits": 4200.0}
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	for i in 90:
		stars.append([rng.randf_range(0.0, 640.0), rng.randf_range(0.0, 250.0), rng.randf_range(0.0, TAU), rng.randf_range(0.6, 1.6)])

func _process(delta: float) -> void:
	t += delta
	if t >= T_VOICE and not _done.has("voice"):
		_done["voice"] = true
		_announce()
	if t >= T_GEAR and not _done.has("gear"):
		_done["gear"] = true
		Sfx.play("gear")
	if t >= T_LAND and not _done.has("land"):
		_done["land"] = true
		Sfx.play("land", -4.0)
	if t >= T_DOOR and not _done.has("door"):
		_done["door"] = true
		Sfx.play("board", -8.0)
	queue_redraw()

## Ansage der Zentrale zur Note: gesprochen (falls die Sprachdatei da ist), als Untertitel in jedem Fall.
func _announce() -> void:
	var key := "shift_" + String(res.grade)
	radio_text = "%s: %s" % [tr("SHIFT_FIN_SPK"), Sfx.line_text("d0", key)]
	var spoke := Sfx.play_voice("d0", key)
	var length := Sfx.voice_player.stream.get_length() if spoke and Sfx.voice_player.stream != null else 4.5
	radio_until = t + length + 0.5

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept") or event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		Sfx.voice_player.stop()
		Music.duck(0.0)
		Flow.to_menu()

func _draw() -> void:
	var vs := get_viewport_rect().size
	var cover := maxf(vs.x / 640.0, vs.y / 360.0)
	var w := 640.0 * cover * 1.05
	var h := 360.0 * cover * 1.05
	var drift := minf(t / 20.0, 1.0)
	draw_texture_rect(bg, Rect2(-(w - vs.x) * (0.3 + 0.4 * drift), -(h - vs.y) * 0.5, w, h), false)
	draw_rect(Rect2(Vector2.ZERO, vs), Color(0.01, 0.02, 0.08, 0.5 + 0.2 * clampf((t - T_CARD + 1.5) / 1.5, 0.0, 1.0)))
	var m := Stage.margin(self)
	draw_set_transform(m)
	for s in stars:
		var a := 0.35 + 0.65 * (0.5 + 0.5 * sin(t * s[3] + s[2]))
		draw_rect(Rect2(s[0], s[1], 1.4, 1.4), Color(0.85, 0.92, 1.0, a * 0.8))
	_draw_depot()
	_draw_taxi()
	_draw_driver()
	_draw_radio()
	if t >= T_CARD:
		_draw_card()
	var ta := clampf(t / 1.2, 0.0, 1.0)
	var ink := Color(0.02, 0.03, 0.1, 0.9 * ta)
	draw_string_outline(Fonts.title, Vector2(0, 58), tr("SHIFT_FIN_TITLE"), HORIZONTAL_ALIGNMENT_CENTER, 640, 30, 3, ink)
	draw_string(Fonts.title, Vector2(0, 58), tr("SHIFT_FIN_TITLE"), HORIZONTAL_ALIGNMENT_CENTER, 640, 30, Color(0.78, 0.88, 1.0, ta))
	var sub := tr("SHIFT_FIN_SUB") % _date_text()
	draw_string_outline(Fonts.hud, Vector2(0, 74), sub, HORIZONTAL_ALIGNMENT_CENTER, 640, 11, 3, ink)
	draw_string(Fonts.hud, Vector2(0, 74), sub, HORIZONTAL_ALIGNMENT_CENTER, 640, 11, Color(1, 1, 1, ta))

## Depot: beleuchtete Landeplattform links, von ihr aus führt eine Brücke über den Abgrund nach rechts aus dem Bild.
func _draw_depot() -> void:
	var deck := Color(0.07, 0.09, 0.22, 1.0)
	for px in [318.0, 468.0, 618.0]:                                   # Pfeiler der Brücke
		draw_rect(Rect2(px, GROUND + 5.0, 9.0, 60.0), Color(0.04, 0.05, 0.14, 0.95))
		draw_rect(Rect2(px + 3.0, GROUND + 14.0, 3.0, 2.0), Color(1.0, 0.7, 0.3, 0.5 + 0.4 * sin(t * 2.0 + px)))
	draw_rect(Rect2(PAD.end.x, GROUND, 640.0 - PAD.end.x + 40.0, 5.0), deck)                   # Fahrbahn
	draw_rect(Rect2(PAD.end.x, GROUND, 640.0 - PAD.end.x + 40.0, 1.0), Color(0.21, 0.88, 0.82, 0.55))
	var x := PAD.end.x + 10.0
	while x < 650.0:                                                  # Geländer: Pfosten, Holm und Zwischenstrebe
		draw_rect(Rect2(x, GROUND - 12.0, 1.5, 12.0), Color(0.28, 0.34, 0.6))
		x += 26.0
	draw_rect(Rect2(PAD.end.x, GROUND - 12.0, 640.0 - PAD.end.x + 40.0, 1.0), Color(0.4, 0.5, 0.85, 0.9))
	draw_rect(Rect2(PAD.end.x, GROUND - 6.0, 640.0 - PAD.end.x + 40.0, 0.7), Color(0.3, 0.38, 0.7, 0.6))
	x = PAD.end.x + 62.0
	while x < 650.0:                                                  # Laternen
		draw_rect(Rect2(x, GROUND - 22.0, 1.5, 22.0), Color(0.22, 0.27, 0.5))
		draw_circle(Vector2(x + 0.7, GROUND - 23.0), 2.2, Color(1.0, 0.9, 0.6, 0.95))
		draw_circle(Vector2(x + 0.7, GROUND - 23.0), 9.0, Color(1.0, 0.85, 0.5, 0.07))
		x += 104.0
	draw_rect(Rect2(PAD.position.x, PAD.position.y, PAD.size.x, 60.0), Color(0.04, 0.05, 0.14, 0.95))
	draw_rect(PAD, Color("#35e0d2"))
	draw_rect(Rect2(PAD.position.x, PAD.position.y, PAD.size.x, 1.5), Color(1, 1, 1, 0.5))
	for k in 2:
		var bx := PAD.position.x + (4.0 if k == 0 else PAD.size.x - 8.0)
		var blink := 0.5 + 0.5 * sin(t * 3.0 + float(k) * PI)
		draw_rect(Rect2(bx, PAD.position.y - 12.0, 3, 12), Color(0.2, 0.25, 0.45))
		draw_circle(Vector2(bx + 1.5, PAD.position.y - 14.0), 3.0, Color(1.0, 0.35, 0.4, 0.45 + 0.5 * blink))
	draw_circle(Vector2(PAD.position.x + PAD.size.x * 0.5, PAD.position.y - 2.0), 46.0, Color(0.2, 0.9, 0.85, 0.06))

func _ease(k: float) -> float:
	var c := clampf(k, 0.0, 1.0)
	return c * c * (3.0 - 2.0 * c)

## Taxi: großer Bogen von links, im Anflug fährt das Fahrwerk aus, dann senkrecht auf das Pad.
func _taxi_pos() -> Vector2:
	var land_y := GROUND - 10.0 * TAXI_S                                # Fußplatten des ausgefahrenen Fahrwerks stehen 10 Einheiten unter der Mitte
	var k := _ease(t / T_SINK)
	if t < T_SINK:
		return Vector2(lerpf(-40.0, LAND_X, k), lerpf(96.0, land_y - 34.0, k) - sin(k * PI) * 18.0)
	var d := clampf((t - T_SINK) / (T_LAND - T_SINK), 0.0, 1.0)
	return Vector2(LAND_X, lerpf(land_y - 34.0, land_y, 1.0 - (1.0 - d) * (1.0 - d)))

func _draw_taxi() -> void:
	var p := _taxi_pos()
	var kk := clampf(t / T_SINK, 0.0, 1.0)
	var s := lerpf(0.9, TAXI_S, _ease(kk))
	var tilt := 0.14 * (1.0 - _ease(kk * 1.4))
	var flying := t < T_LAND
	if t < T_SINK:
		for i in 18:                                                    # Schweif im Flug
			var f := float(i) / 18.0
			draw_rect(Rect2(p + Vector2(-20.0 * s - float(i) * 3.0, sin(t * 18.0 + float(i)) * 0.6), Vector2(3, 2.0 - f)), Color(0.5, 0.8, 1.0, (1.0 - f) * 0.6 * (1.0 - kk)))
	draw_set_transform(Stage.margin(self) + p, tilt, Vector2(s, s))
	var g := clampf((t - T_GEAR) / 1.4, 0.0, 1.0)                       # Fahrwerk ausfahren, wie im Spiel (Streben und Fußplatten)
	if g > 0.02:
		var gl := Tuning.GEAR_LEN / Tuning.TAXI_SCALE * g
		var steel := Color("#c9cfee")
		for sx in [-1.0, 1.0]:
			draw_line(Vector2(sx * 5.0, 5.5), Vector2(sx * Tuning.FOOT_X / Tuning.TAXI_SCALE, 5.0 + gl), steel, 0.7)
			draw_rect(Rect2(sx * Tuning.FOOT_X / Tuning.TAXI_SCALE - 2.0, 5.0 + gl, 4.0, 0.7), steel)
		if g >= 1.0:
			draw_rect(Rect2(-1, 7, 2, 1), Color("#5dff9a"))             # grüne Landelampe
	if t >= T_SINK and flying:                                          # Bremsflamme im Schlussanflug
		var fade := 1.0 - clampf((t - T_SINK) / (T_LAND - T_SINK), 0.0, 1.0) * 0.6
		var fl := 0.6 + 0.4 * sin(t * 60.0)
		for sx in [-1.0, 1.0]:
			draw_rect(Rect2(sx * 5.0 - 1.0, 10.0, 2.0, 4.0 * fl * fade), Color(1.0, 0.7, 0.25, 0.85 * fade))
			draw_rect(Rect2(sx * 5.0 - 0.5, 10.0, 1.0, 2.5 * fl * fade), Color(1.0, 0.97, 0.8, 0.9 * fade))
	draw_texture_rect(taxi_empty if t >= T_STAND else taxi, Tuning.TAXI_RECT, false)         # ab dem Aufstehen sitzt niemand mehr in der Kuppel
	if t >= T_DOOR and t < T_TOP:                                       # die Kuppel leuchtet kurz auf, solange er aussteigt
		var da := sin(clampf((t - T_DOOR) / (T_TOP - T_DOOR), 0.0, 1.0) * PI)
		draw_circle(Vector2(0.0, -4.0), 11.0, Color(1.0, 0.95, 0.7, 0.28 * da))
	draw_set_transform(Stage.margin(self))
	if t >= T_LAND and t < T_LAND + 0.9:                                # Staub beim Aufsetzen
		var d := (t - T_LAND) / 0.9
		for i in 7:
			var dir := -1.0 if i % 2 == 0 else 1.0
			var off := dir * (6.0 + float(i / 2) * 5.0) * (0.4 + d)
			draw_circle(Vector2(LAND_X + off, GROUND - 1.5 - d * 3.0), 2.5 * (1.0 - d) + 0.5, Color(0.7, 0.78, 0.95, 0.35 * (1.0 - d)))

## Ablauf des Fahrers: {mode, x, …} – "gone" (sitzt noch im Taxi bzw. ist aus dem Bild), "rise" (steigt aus der Kuppel, k 0..1), "hop" (springt aufs Pad, u 0..1), "land" (Landehocke),
## "turn" (Drehung, k = 0..1 zur Kamera; beim Losgehen und beim Zurückdrehen rückwärts), "walk" (Seitenansicht), "front" (zur Kamera, winkt/lächelt).
func _driver_state() -> Dictionary:
	if t < T_STAND:
		return {"mode": "gone", "x": LAND_X}
	if t < T_TOP:
		return {"mode": "rise", "x": LAND_X, "k": (t - T_STAND) / (T_TOP - T_STAND)}
	if t < T_GROUND:
		return {"mode": "hop", "x": lerpf(LAND_X, X_OUT, _ease((t - T_TOP) / (T_GROUND - T_TOP))), "u": (t - T_TOP) / (T_GROUND - T_TOP)}
	if t < T_TURN:
		return {"mode": "land", "x": X_OUT}
	if t < T_WALK:
		return {"mode": "turn", "x": X_OUT, "k": 1.0 - (t - T_TURN) / (T_WALK - T_TURN)}
	var t_stop := T_WALK + (STOP_X - X_OUT) / WALK_SPEED
	if t < t_stop:
		return {"mode": "walk", "x": X_OUT + (t - T_WALK) * WALK_SPEED, "ph": (t - T_WALK) * 9.0}
	var u := t - t_stop
	if u < 0.7:
		return {"mode": "turn", "x": STOP_X, "k": u / 0.7}
	if u < 4.4:
		return {"mode": "front", "x": STOP_X, "u": u - 0.7, "wave": u > 1.3 and u < 3.8, "smile": u > 0.9 and u < 4.2}
	if u < 5.1:
		return {"mode": "turn", "x": STOP_X, "k": 1.0 - (u - 4.4) / 0.7}
	var x := STOP_X + (u - 5.1) * WALK_SPEED
	if x > OFF_X:
		return {"mode": "gone", "x": x}
	return {"mode": "walk", "x": x, "ph": (u - 5.1) * 9.0}

## Taxi ohne Fahrer: die Lackierung des Spielers mit der leeren Kuppel (`taxi_cockpit_empty.png` enthält nur die Pixel, die der Fahrer verdeckt hat).
func _empty_taxi() -> Texture2D:
	var base: Image = taxi.get_image()
	var patch: Image = (load("res://assets/art/taxi_cockpit_empty.png") as Texture2D).get_image()
	if base == null or patch == null:
		return taxi
	base = base.duplicate()
	base.convert(Image.FORMAT_RGBA8)
	patch.convert(Image.FORMAT_RGBA8)
	base.blend_rect(patch, Rect2i(Vector2i.ZERO, patch.get_size()), Vector2i.ZERO)
	return ImageTexture.create_from_image(base)

## Bild des Fahrers im Blatt (driver.png): 0–7 Gehen, 8 Stand seitlich, 9 Drehung, 10 von vorn lächelnd, 11 von vorn ohne Lächeln, 12–14 winkend, 15 Sprung, 16 Landung.
func _driver_frame(st: Dictionary) -> int:
	match String(st.mode):
		"walk":
			return int(fposmod(float(st.ph), TAU) / TAU * 8.0) % 8
		"turn":
			var k := float(st.k)
			return 8 if k < 0.34 else (9 if k < 0.67 else 10)
		"front":
			if st.wave:
				return [12, 13, 12, 14][int(float(st.u) * 6.0) % 4]
			return 10 if st.smile else 11
		"rise":
			return 10
		"hop":
			return 15
		"land":
			return 16
	return 8

## Der Fahrer aus dem Blatt `driver.png` (gleiche Melone, Uniform und Fliege wie im Taxi). Beim Aussteigen sitzt sein Kopf zuerst genau dort, wo der Fahrer in der Kuppel saß
## (gleiche Pixeldichte); der Rest steckt unter dem Kuppelrand, bis er hochgestiegen ist. Dann springt er im Bogen aufs Pad und geht von dort los.
func _draw_driver() -> void:
	var st := _driver_state()
	if st.mode == "gone":
		return
	var w := DRIVER_FW * DRIVER_S
	var h := DRIVER_FH * DRIVER_S
	var f := _driver_frame(st)
	var tp := _taxi_pos()
	var rect_src := Rect2(float(f) * DRIVER_FW, 0.0, DRIVER_FW, DRIVER_FH)
	var pos: Vector2
	var shadow := true
	if st.mode == "rise" or st.mode == "hop":
		# Kopfmitte des Fahrers in der Kuppel (Pixel 48/15 des Taxis, 3 Pixel je Einheit): 0 / -5 Einheiten über der Taxi-Mitte
		var seat := Vector2(tp.x - w * 0.5, tp.y - 5.0 * TAXI_S - 20.5 * DRIVER_S)
		if st.mode == "rise":
			pos = seat - Vector2(0.0, RISE * _ease(float(st.k)))
			var clip_y := tp.y + (27.0 / 3.0 - 10.0) * TAXI_S              # Unterkante der Kuppel
			var rows := clampf((clip_y - pos.y) / DRIVER_S, 0.0, DRIVER_FH)
			if rows < DRIVER_FH:
				rect_src.size.y = rows
			shadow = false
			if rows > 0.0:
				draw_texture_rect_region(driver_tex, Rect2(pos, Vector2(w, rows * DRIVER_S)), rect_src)
			return
		var u := float(st.u)
		var bottom0 := seat.y - RISE + DRIVER_FH * DRIVER_S                    # Absprung: oben auf dem Taxi, Füße über dem Kuppelrand
		var bottom := bottom0 + (GROUND - bottom0) * u * u - 9.0 * sin(PI * u) * (1.0 - u)
		pos = Vector2(float(st.x) - w * 0.5, bottom - DRIVER_FH * DRIVER_S)
		shadow = u > 0.55
	else:
		pos = Vector2(float(st.x) - w * 0.5, GROUND - DRIVER_FH * DRIVER_S)
	pos = pos.round()
	if shadow:
		draw_rect(Rect2(pos.x + w * 0.5 - 7.0, GROUND - 0.5, 14.0, 1.5), Color(0, 0, 0, 0.3))
	draw_texture_rect_region(driver_tex, Rect2(pos, Vector2(w, h)), rect_src)
	if st.mode == "land":                                                    # Staub bei der Landung
		for i in 4:
			var dir := -1.0 if i % 2 == 0 else 1.0
			draw_circle(Vector2(float(st.x) + dir * (4.0 + float(i / 2) * 4.0), GROUND - 1.5), 1.6, Color(0.7, 0.78, 0.95, 0.35))

## Ansage der Zentrale als Untertitel unter der Überschrift, solange gesprochen wird.
func _draw_radio() -> void:
	if not Settings.values.subtitles or radio_text == "" or t < T_VOICE or t > radio_until:
		return
	var a := clampf((t - T_VOICE) / 0.4, 0.0, 1.0) * clampf((radio_until - t) / 0.5, 0.0, 1.0)
	draw_rect(Rect2(60, 84, 520, 30), Color(0.04, 0.05, 0.14, 0.78 * a))
	draw_rect(Rect2(60, 84, 520, 1), Color(0.55, 0.75, 1.0, 0.7 * a))
	draw_multiline_string(Fonts.ui, Vector2(70, 97), radio_text, HORIZONTAL_ALIGNMENT_CENTER, 500, 10, 2, Color(0.96, 0.97, 1.0, a))

func _draw_card() -> void:
	var a := clampf((t - T_CARD) / 1.0, 0.0, 1.0)
	var g := String(res.grade)
	var r := Rect2(180, 92, 280, 160)
	draw_style_box(_box(Color(0.05, 0.06, 0.16, 0.9 * a), Color(0.43, 0.66, 1.0, 0.8 * a)), r)
	draw_string(Fonts.ui, Vector2(r.position.x, r.position.y + 20.0), tr("SHIFT_TOTAL"), HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 10, Color(0.7, 0.76, 1.0, a))
	var gc: Color = load("res://src/game/hud.gd").grade_color(g)
	draw_string(Fonts.title, Vector2(r.position.x, r.position.y + 76.0), g, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 56, Color(gc.r, gc.g, gc.b, a))
	draw_string(Fonts.hud, Vector2(r.position.x, r.position.y + 96.0), tr("SHIFT_TOTAL_POINTS") % int(round(float(res.score))) + "  " + tr("SHIFT_OF") % 100, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 12, Color(1.0, 0.88, 0.4, a))
	var rows := [[tr("SHIFT_FIN_MAPS"), "%d / %d" % [int(res.maps), NightShift.MAPS]], [tr("SHIFT_SUM_TAXIS"), "%d / %d" % [int(res.taxis), NightShift.START_TAXIS]], [tr("SHIFT_SUM_CREDITS"), "¢ %d" % int(round(float(res.credits)))]]
	for i in rows.size():
		var y := r.position.y + 122.0 + float(i) * 12.0
		draw_string(Fonts.ui, Vector2(r.position.x + 22.0, y), rows[i][0], HORIZONTAL_ALIGNMENT_LEFT, 140, 9, Color(0.82, 0.86, 1.0, a))
		draw_string(Fonts.hud, Vector2(r.position.x + 130.0, y), rows[i][1], HORIZONTAL_ALIGNMENT_RIGHT, 128, 9, Color(1.0, 0.9, 0.5, a))
	var b := clampf((t - T_CARD - 1.5) / 1.0, 0.0, 1.0)
	draw_string_outline(Fonts.ui, Vector2(0, 340), tr("SHIFT_FIN_NEXT"), HORIZONTAL_ALIGNMENT_CENTER, 640, 10, 3, Color(0.02, 0.03, 0.1, 0.9 * b))
	draw_string(Fonts.ui, Vector2(0, 340), tr("SHIFT_FIN_NEXT"), HORIZONTAL_ALIGNMENT_CENTER, 640, 10, Color(0.9, 0.95, 1.0, b))

## Datum und Uhrzeit der Schicht im Format der Sprache (24 h deutsch, 12 h englisch).
func _date_text() -> String:
	var now := Time.get_datetime_dict_from_system()
	return NightShift.format_stamp(String(res.get("date", Daily.today())), int(res.get("hour", now.hour)), int(res.get("minute", now.minute)), TranslationServer.get_locale().substr(0, 2))

var _boxes := {}

func _box(bg: Color, border: Color) -> StyleBoxFlat:
	var key := bg.to_html(true) + border.to_html(true)
	if not _boxes.has(key):
		var sb := StyleBoxFlat.new()
		sb.bg_color = bg
		sb.border_color = border
		sb.set_border_width_all(1)
		sb.set_corner_radius_all(9)
		sb.anti_aliasing = true
		_boxes[key] = sb
	return _boxes[key]
