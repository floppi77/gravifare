extends Node2D
## Kennzeichen der Fahrgasttypen über den Figuren (Runde 61): VIP = goldene Krone, Notfall = weißes Kreuz auf Rot mit Frist als Zahl.
## Die Formen unterscheiden sich auch ohne Farbsehen (Krone gegen Kreuz, dazu die Zahl beim Notfall). Sitzt ein Notfall im Taxi, steht die Frist
## über dem Taxi. Eigener Knoten über den Requisiten (props_view.gd zeichnet Figur, Betrag und Zielblase); Lage links neben dem Betrag.

const PX := 1.0 / 3.0
const INK := Color("#0c0f24")
const GOLD := Color("#ffd23a")
const RED := Color("#e8243a")

var run: Run
var t := 0.0

func setup(r: Run) -> void:
	run = r
	queue_redraw()

func _process(delta: float) -> void:
	t += delta
	queue_redraw()

func _draw() -> void:
	if run == null:
		return
	if run.actor != null:
		_tag(run.actor, run.current_job(), run.emergency_left())
	for e in run.extras:
		_tag(e.actor, e.job, run.extra_emergency_left(e))
	# Notfall an Bord: Frist über dem Taxi
	var left := -1.0
	if run.phase == Run.Phase.CARRYING:
		left = run.emergency_left()
	var ex := run._extra_aboard()
	if left < 0.0 and not ex.is_empty() and int(ex.state) == Run.ES.CARRY:
		left = run.extra_emergency_left(ex)
	if left >= 0.0 and run.result == Run.Result.RUNNING:
		var c := run.sim.pos + Vector2(0.0, -Tuning.HULL_HALF.y - 12.0)
		_cross(c + Vector2(-9.0, 0.0), 1.0)
		_clock(c + Vector2(4.0, 0.0), left, 1.0)

func _tag(a: PassengerActor, job: Dictionary, left: float) -> void:
	var kind := run.kind_of(job)
	if kind == "" or a == null or not a.is_visible() or a.state == PassengerActor.S.ABOARD or a.state == PassengerActor.S.FALLING or a.state == PassengerActor.S.DEAD:
		return
	var pos := a.world_pos()
	var x := pos.x - _amount_width(a) * 0.5 - 5.6          # links neben dem Betrag (gleiche Breite wie props_view._draw_amount)
	var c := Vector2(x, pos.y - 17.4)
	if kind == "vip":
		_crown(c, a.fade)
	else:
		_cross(c, a.fade)
		if left >= 0.0:
			_clock(Vector2(x, pos.y - 26.6), left, a.fade)

## Breite des Betragsschilds über der Figur (wie props_view._draw_amount; ohne Betrag die Mindestbreite).
func _amount_width(a: PassengerActor) -> float:
	var value := -1.0
	var ex := run.extra_of(a)
	if not ex.is_empty():
		value = run.extra_prospect(ex)
	elif a == run.actor:
		value = run.prospect()
	if value < 0.0:
		return 16.0
	return maxf(16.0, Fonts.hud.get_string_size("¢%d" % int(round(value)), HORIZONTAL_ALIGNMENT_LEFT, -1, 7).x + 4.0)

## Krone: dunkler Rand, goldene Fläche mit drei Zacken und Steinchen.
func _crown(c: Vector2, fade: float) -> void:
	var out := PackedVector2Array([c + Vector2(-4.6, 3.4), c + Vector2(-4.6, -3.0), c + Vector2(-2.3, -0.6), c + Vector2(0.0, -4.0),
		c + Vector2(2.3, -0.6), c + Vector2(4.6, -3.0), c + Vector2(4.6, 3.4)])
	draw_colored_polygon(out, Color(INK, fade))
	var inn := PackedVector2Array([c + Vector2(-3.6, 2.5), c + Vector2(-3.6, -1.2), c + Vector2(-2.2, 0.6), c + Vector2(0.0, -2.6),
		c + Vector2(2.2, 0.6), c + Vector2(3.6, -1.2), c + Vector2(3.6, 2.5)])
	draw_colored_polygon(inn, Color(GOLD, fade))
	draw_rect(Rect2(c.x - 3.6, c.y + 1.4, 7.2, 1.1), Color(GOLD.darkened(0.3), fade))
	draw_rect(Rect2(c.x - 0.5, c.y - 0.4, 1.0, 1.0), Color(RED, fade))

## Notfall: rotes Feld mit weißem Kreuz, pulsiert.
func _cross(c: Vector2, fade: float) -> void:
	var p := 0.5 + 0.5 * sin(t * 7.0)
	draw_rect(Rect2(c.x - 4.2, c.y - 4.2, 8.4, 8.4), Color(INK, fade))
	draw_rect(Rect2(c.x - 3.5, c.y - 3.5, 7.0, 7.0), Color(RED.lightened(0.15 * p), fade))
	draw_rect(Rect2(c.x - 1.0, c.y - 2.8, 2.0, 5.6), Color(1, 1, 1, fade))
	draw_rect(Rect2(c.x - 2.8, c.y - 1.0, 5.6, 2.0), Color(1, 1, 1, fade))

## Frist in ganzen Sekunden; unter 10 s heller Rand und Blinken.
func _clock(c: Vector2, left: float, fade: float) -> void:
	var txt := "%d" % int(ceilf(left))
	var font := Fonts.hud
	var w := maxf(9.0, font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 7).x + 3.0)
	var urgent := left <= 10.0
	var on := not urgent or fmod(t, 0.5) < 0.32
	var r := Rect2(c.x - w * 0.5, c.y - 3.8, w, 7.4)
	draw_rect(r, Color(0.04, 0.05, 0.14, 0.92 * fade))
	draw_rect(r, Color(Color.WHITE if urgent else RED, fade), false, 0.7)
	if on:
		draw_string_outline(font, Vector2(r.position.x, c.y + 2.2), txt, HORIZONTAL_ALIGNMENT_CENTER, w, 7, 3, Color(0.02, 0.03, 0.1, fade))
		draw_string(font, Vector2(r.position.x, c.y + 2.2), txt, HORIZONTAL_ALIGNMENT_CENTER, w, 7, Color(1.0, 0.9, 0.9, fade))
