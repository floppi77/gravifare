extends Node2D
## Landeassistent direkt am Taxi (statt nur der Landeampel in der Bildschirmecke): Mit ausgefahrenem Fahrwerk über einer Plattform zeigt
## ein kleines Feld die kritischste der drei Größen (Sinkrate, Seitentempo, Neigung) mit Grenzmarke sowie Haken (ok) oder Warnzeichen,
## dazu auf der Plattform das freie Landefenster und eine Marke unter dem Taxi. Der Zustand steht in Form UND Farbe – nicht nur Rot/Grün.
## Zusätzlich: In Leveln mit Fremdverkehr trägt das eigene Taxi eine kleine Marke über dem Rumpf.
## Reine Darstellung: liest nur TaxiSim und Leveldaten, verändert nichts.

const NEAR_PAD := 64.0           # ab dieser Höhe über der Plattform erscheint der Assistent (px)
const GREEN := Color("#5dff9a")
const YELLOW := Color("#ffe14a")
const RED := Color("#ff4d6d")
const PANEL := Color(0.05, 0.06, 0.15, 0.86)

var run: Run
var t := 0.0

func bind(r: Run) -> void:
	run = r
	sync_state()

## Einmal pro Physik-Tick (wie das Taxi), damit die Interpolation beide Knoten gleich glättet.
func sync_state() -> void:
	if run != null:
		position = run.sim.pos

var gauge_a := 0.0                # Einblendung der Tankanzeige (0 … 1)
var needle := 0.0                 # angezeigter Füllstand (0 … 1), der Zeiger federt nach
var needle_v := 0.0

func _process(delta: float) -> void:
	t += delta
	_gauge_tick(delta)
	queue_redraw()

## Tankanzeige über dem Taxi: nur am Zapfpad, blendet beim Abheben wieder aus.
func _gauge_tick(delta: float) -> void:
	var on := run != null and run.result == Run.Result.RUNNING and run.sim.state == TaxiSim.State.LANDED and bool(run.sim.landed_pad.get("fuel", false))
	gauge_a = move_toward(gauge_a, 1.0 if on else 0.0, delta / (0.18 if on else 0.12))
	if run == null:
		return
	if not on and gauge_a <= 0.0:
		needle = clampf(run.sim.fuel / Tuning.FUEL_MAX, 0.0, 1.0)
		needle_v = 0.0
		return
	var target := clampf(run.sim.fuel / Tuning.FUEL_MAX, 0.0, 1.0)
	needle_v += ((target - needle) * 90.0 - needle_v * 11.0) * delta        # Feder mit Dämpfung: der Zeiger schwingt leicht nach
	needle = clampf(needle + needle_v * delta, -0.03, 1.03)

## Analoge Tankanzeige wie im Auto: oben Halbkreis, unten gerade abgeschnitten; feine Strichskala, grüner Mittelstrich, Zapfsäule in der Mitte,
## E links, F rechts, roter Zeiger vom Drehpunkt unten.
func _draw_gauge() -> void:
	if gauge_a <= 0.01 or run == null:
		return
	var a := gauge_a
	var c := Vector2(0.0, -26.0 - (1.0 - a) * 4.0)           # Drehpunkt (Mitte der geraden Unterkante)
	var r := 10.5
	var th_e := deg_to_rad(200.0)                              # E: links, leicht über der Waagerechten
	var th_f := deg_to_rad(340.0)                              # F: rechts
	var body := PackedVector2Array()
	for i in 25:
		var ang := PI + float(i) / 24.0 * PI
		body.append(c + Vector2(cos(ang), sin(ang)) * (r + 1.0))
	draw_colored_polygon(body + PackedVector2Array([c + Vector2(r + 1.0, 2.0), c + Vector2(-r - 1.0, 2.0)]), Color(0.1, 0.1, 0.12, 0.96 * a))
	draw_polyline(body, Color(0.62, 0.66, 0.8, 0.9 * a), 0.8)
	draw_line(c + Vector2(-r - 1.0, 2.0), c + Vector2(r + 1.0, 2.0), Color(0.62, 0.66, 0.8, 0.9 * a), 0.8)
	var n := 29
	for i in n:
		var u := float(i) / float(n - 1)
		var ang := lerpf(th_e, th_f, u)
		var d := Vector2(cos(ang), sin(ang))
		var mid := i == n / 2
		var col := Color(0.55, 0.9, 0.6, a) if mid else (Color(1.0, 0.35, 0.3, a) if i < 3 else Color(0.88, 0.97, 0.82, 0.9 * a))
		draw_line(c + d * (r - (4.4 if mid else 3.4)), c + d * (r - 0.8), col, 1.1 if mid else 0.55)
	var font := Fonts.hud
	draw_string(font, c + Vector2(-r - 4.2, 3.2), "E", HORIZONTAL_ALIGNMENT_LEFT, -1, 5, Color(0.95, 0.95, 1.0, a))
	draw_string(font, c + Vector2(r + 0.6, 3.2), "F", HORIZONTAL_ALIGNMENT_LEFT, -1, 5, Color(0.95, 0.95, 1.0, a))
	# Zapfsäule mit Schlauch
	var ic := Color(0.97, 0.97, 1.0, a)
	draw_rect(Rect2(c.x - 2.6, c.y - 7.4, 3.8, 5.6), ic)
	draw_rect(Rect2(c.x - 1.9, c.y - 6.6, 2.4, 1.6), Color(0.1, 0.1, 0.12, a))
	draw_rect(Rect2(c.x - 3.2, c.y - 2.0, 5.0, 0.8), ic)
	draw_polyline(PackedVector2Array([Vector2(c.x + 1.4, c.y - 6.4), Vector2(c.x + 2.8, c.y - 6.0), Vector2(c.x + 3.0, c.y - 3.4), Vector2(c.x + 3.8, c.y - 3.0)]), ic, 0.5)
	# Zeiger (rot, kräftig), federt nach
	var ang2 := lerpf(th_e, th_f, clampf(needle, 0.0, 1.0))
	var nd := Vector2(cos(ang2), sin(ang2))
	var ncol := Color(0.93, 0.2, 0.18, a) if not (run.sim.fuel < 25.0 and int(t * 6.0) % 2 == 0) else Color(1.0, 0.55, 0.4, a)
	draw_line(c - nd * 1.2, c + nd * (r + 0.4), ncol, 1.5)
	draw_circle(c, 1.1, ncol)

static func tone(ratio: float) -> Color:
	return GREEN if ratio <= Tuning.GAUGE_GREEN else (YELLOW if ratio <= 1.0 else RED)

## Plattform unter dem Taxi (Fahrwerk-Fußpunkt), nächste zuerst; leer, wenn keine in Reichweite liegt.
func _pad_below(s: TaxiSim) -> Dictionary:
	var best := {}
	var best_gap := NEAR_PAD
	var foot_y := s.pos.y + Tuning.HULL_HALF.y + Tuning.GEAR_LEN
	for id in s.level.pads:
		var p: Dictionary = s.level.pads[id]
		if s.pos.x < float(p.x0) - 6.0 or s.pos.x > float(p.x1) + 6.0:
			continue
		var gap := float(p.row) * Tuning.TILE - foot_y
		if gap > -2.0 and gap < best_gap:
			best_gap = gap
			best = p
	return best

func _draw() -> void:
	_draw_gauge()
	if run == null or run.result != Run.Result.RUNNING:
		return
	var s := run.sim
	if s.state == TaxiSim.State.DESTROYED:
		return
	if s.state != TaxiSim.State.FLYING or s.gear < 0.5 or not Settings.values.landing_assist:
		return
	var pad := _pad_below(s)
	if pad.is_empty():
		return
	var foot_y := s.pos.y + Tuning.HULL_HALF.y + Tuning.GEAR_LEN
	var gap := float(pad.row) * Tuning.TILE - foot_y
	var a := clampf((NEAR_PAD - gap) / 12.0, 0.0, 1.0)
	_draw_window(s, pad, a)
	_draw_chip(s, a)

## Freies Landefenster (Klammer auf der Plattform) und Lotmarke unter dem Taxi.
func _draw_window(s: TaxiSim, pad: Dictionary, a: float) -> void:
	var lo := float(pad.get("land_lo", float(pad.x0) + Tuning.FOOT_X))
	var hi := float(pad.get("land_hi", float(pad.x1) - Tuning.FOOT_X))
	if hi <= lo:
		return
	var y := float(pad.row) * Tuning.TILE - s.pos.y            # lokale Koordinate der Plattformoberkante
	var inside := s.pos.x >= lo and s.pos.x <= hi
	var col := GREEN if inside else YELLOW
	col.a = a
	var x0 := lo - s.pos.x
	var x1 := hi - s.pos.x
	var x := x0
	while x < x1:                                              # gestrichelte Linie knapp über der Oberkante
		draw_rect(Rect2(x, y - 1.7, minf(2.0, x1 - x), 0.67), col)
		x += 4.0
	for ex in [x0, x1]:                                        # Endklammern
		draw_rect(Rect2(ex - 0.33, y - 5.0, 0.67, 3.7), col)
	draw_rect(Rect2(x0, y - 5.0, 2.0, 0.67), col)
	draw_rect(Rect2(x1 - 2.0, y - 5.0, 2.0, 0.67), col)
	# Lotmarke: Dreieck auf der Plattform unter dem Taxi (Spitze nach oben)
	var mcol := GREEN if inside else (YELLOW if s.pos.x >= float(pad.x0) + Tuning.FOOT_X and s.pos.x <= float(pad.x1) - Tuning.FOOT_X else RED)
	mcol.a = a
	draw_colored_polygon(PackedVector2Array([Vector2(-2.0, y + 2.0), Vector2(2.0, y + 2.0), Vector2(0.0, y - 0.7)]), mcol)

## Feld neben dem Taxi: Symbol der kritischsten Achse, Balken mit Grenzmarke, Haken/Warnzeichen.
func _draw_chip(s: TaxiSim, a: float) -> void:
	var rs := [maxf(s.vel.y, 0.0) / s.land_vy, absf(s.vel.x) / Tuning.LAND_VX, absf(s.tilt) / Tuning.LAND_TILT]
	var worst := 0
	for i in 3:
		if rs[i] > rs[worst]:
			worst = i
	var r: float = rs[worst]
	var col := tone(r)
	col.a = a
	var side := 1.0 if s.pos.x < float(s.level.pixel_size().x) - 60.0 else -1.0          # am rechten Rand nach links ausweichen
	var w := 30.0
	var h := 17.0
	var x0 := 14.0 if side > 0.0 else -14.0 - w
	var y0 := -12.0
	draw_rect(Rect2(x0, y0, w, h), Color(PANEL.r, PANEL.g, PANEL.b, PANEL.a * a))
	draw_rect(Rect2(x0, y0, w, h), col, false, 0.67)
	var ix := x0 + 7.0
	var iy := y0 + 7.0
	match worst:
		0:      # Sinkrate: Pfeil nach unten
			draw_colored_polygon(PackedVector2Array([Vector2(ix - 3.5, iy - 3.0), Vector2(ix + 3.5, iy - 3.0), Vector2(ix, iy + 2.5)]), col)
		1:      # Seitentempo: Pfeil in Driftrichtung
			var d := signf(s.vel.x) if absf(s.vel.x) > 0.5 else 1.0
			draw_colored_polygon(PackedVector2Array([Vector2(ix + d * 4.0, iy), Vector2(ix + d * 0.5, iy - 3.0), Vector2(ix + d * 0.5, iy + 3.0)]), col)
			draw_rect(Rect2(ix - 4.0 if d > 0.0 else ix + 0.5, iy - 0.5, 4.0, 1.0), col)
		2:      # Neigung: geneigte Linie über kurzer Basis
			var d2 := signf(s.tilt) if absf(s.tilt) > 0.005 else 1.0
			draw_line(Vector2(ix - 3.5, iy + 2.0 * d2), Vector2(ix + 3.5, iy - 2.0 * d2), col, 1.0)
			draw_rect(Rect2(ix - 4.0, iy + 3.0, 8.0, 0.67), Color(col.r, col.g, col.b, col.a * 0.6))
	# Zustandszeichen rechts: Haken (innerhalb der Grenze) oder Warndreieck (darüber, blinkt)
	var sx := x0 + w - 8.0
	var sy := y0 + 7.0
	if r <= 1.0:
		draw_polyline(PackedVector2Array([Vector2(sx - 3.0, sy), Vector2(sx - 1.0, sy + 2.5), Vector2(sx + 3.5, sy - 3.0)]), col, 1.2)
	elif int(t * 8.0) % 2 == 0:
		draw_colored_polygon(PackedVector2Array([Vector2(sx - 4.0, sy + 3.5), Vector2(sx + 4.0, sy + 3.5), Vector2(sx, sy - 4.0)]), col)
		draw_rect(Rect2(sx - 0.4, sy - 1.8, 0.8, 3.0), Color(PANEL.r, PANEL.g, PANEL.b, a))
		draw_rect(Rect2(sx - 0.4, sy + 1.6, 0.8, 0.8), Color(PANEL.r, PANEL.g, PANEL.b, a))
	# Balken: Grenze liegt in der Mitte (weiße Marke), Füllung wächst mit dem Wert
	var bx := x0 + 4.0
	var by := y0 + h - 5.0
	var bw := w - 8.0
	draw_rect(Rect2(bx, by, bw, 2.0), Color(0.16, 0.2, 0.4, a))
	draw_rect(Rect2(bx, by, bw * minf(r / 2.0, 1.0), 2.0), col)
	draw_rect(Rect2(bx + bw * 0.5 - 0.33, by - 1.0, 0.67, 4.0), Color(1, 1, 1, a))
