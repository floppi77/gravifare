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

func _process(delta: float) -> void:
	t += delta
	queue_redraw()

static func tone(ratio: float) -> Color:
	return GREEN if ratio <= 0.7 else (YELLOW if ratio <= 1.0 else RED)

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
	if run == null or run.result != Run.Result.RUNNING:
		return
	var s := run.sim
	if s.state == TaxiSim.State.DESTROYED:
		return
	if run.level.has_traffic():
		_draw_marker()
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
	var rs := [maxf(s.vel.y, 0.0) / Tuning.LAND_VY, absf(s.vel.x) / Tuning.LAND_VX, absf(s.tilt) / Tuning.LAND_TILT]
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

## Eigenes Taxi in Leveln mit Fremdverkehr: goldene Marke über dem Rumpf, die sanft pulsiert.
func _draw_marker() -> void:
	var by := -14.0 + sin(t * 4.0) * 1.0
	var pts := PackedVector2Array([Vector2(-3.5, by - 4.0), Vector2(3.5, by - 4.0), Vector2(0.0, by + 1.0)])
	draw_colored_polygon(PackedVector2Array([Vector2(-4.5, by - 5.0), Vector2(4.5, by - 5.0), Vector2(0.0, by + 2.4)]), Color(0.03, 0.04, 0.1, 0.85))
	draw_colored_polygon(pts, Color("#ffe14a"))
