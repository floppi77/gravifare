class_name HudGauges
extends RefCounted
## Instrumente links oben im HUD (Runde 73): Tankanzeige und Hüllenanzeige.
##
## Beide sind 68 × 12 Einheiten groß und bestehen aus einem Gehäuse mit Symbolkappe (Blatt assets/art/hud_gauges_sizes.png, je Pixelgröße 2–6
## eigens gerastert, tools/art/gen_hud.py) und der Füllung im Sichtfenster, die hier Bildpunktzeile für Bildpunktzeile gezeichnet wird –
## ihre Farbe hängt vom Zustand ab:
##
##   Tank   hellgrün (voll) → ab 50 % über Gelb nach Orange → ab 25 % orange (dort setzt auch der Tankalarm ein) → letzte 10 % rot.
##          Durchgehende „Flüssigkeit“ mit heller Kante am Füllstand. Jeder Piepton des Alarms lässt die Anzeige aufblitzen (`ping()`),
##          die Blinkfolge im Bild ist damit dieselbe wie im Ton. Beim Tanken läuft ein heller Streifen durch die Füllung.
##   Hülle  eisblau (heil) → ab 70 % nach Violett → ab 35 % magenta (kritisch, pulsiert). Zehn schräge Panzerplatten statt einer Flüssigkeit:
##          die beiden Anzeigen unterscheiden sich in Farbe, Form und Symbol, also auch ohne Farbsehen. Ein Treffer lässt das verlorene
##          Stück kurz weiß stehen und dann abschmelzen, damit man sieht, wie viel er gekostet hat.
##
## Die Schwellen der Farben stehen als Konstanten hier und sind dieselben, die unter dem Fenster als Marke eingezeichnet sind.

const TEX: Texture2D = preload("res://assets/art/hud_gauges_sizes.png")
const SIZE := Vector2(68, 12)             # eine Anzeige in Einheiten
const BLOCK := Vector2(68, 60)            # ein Block des Blatts: Tank hinten, Tank vorn, Hülle hinten, Hülle vorn, Symbole
const WINDOW := Rect2(15, 3, 50, 6)       # Sichtfenster innerhalb der Anzeige (wie in gen_hud.py)
const PLATES := 10
const SLANT := 2.0                        # Schräge der Panzerplatten in Einheiten über die Fensterhöhe

const FUEL_FADE := 0.50                   # darüber hellgrün
const FUEL_LOW := 0.25                    # ab hier orange – dieselbe Schwelle wie der Tankalarm (25 von 100)
const FUEL_RESERVE := 0.10                # letzte 10 %: rot
const HULL_OK := 0.70                     # darüber eisblau
const HULL_WORN := 0.50                   # ab hier violett
const HULL_CRIT := 0.35                   # ab hier magenta (kritisch)

const FUEL_FULL_C := Color("#8dff4a")
const FUEL_MID_C := Color("#ffe14a")
const FUEL_LOW_C := Color("#ff9a1f")
const FUEL_CRIT_C := Color("#ff3b3b")
const HULL_OK_C := Color("#4fc3ff")
const HULL_WORN_C := Color("#a98bff")
const HULL_CRIT_C := Color("#ff4fc8")
const GLASS_C := Color("#0a0d20")
const BLOCKED_C := Color("#1b2149")
const TRAIL_C := Color("#fff4dc")

var age := 0.0
var fuel_prev := -1.0
var refuel_t := 0.0                       # > 0, solange der Tank gerade gefüllt wird
var ping_t := 0.0                         # 1 beim Piepton des Tankalarms, klingt ab
var hull_prev := -1.0
var hull_trail := 0.0                     # nachlaufender Wert: Stück zwischen Hülle und Nachlauf = eben verlorener Schaden
var trail_hold := 0.0
var hit_t := 0.0                          # 1 beim Treffer, klingt ab

## Farbe der Tankfüllung für den Anteil `frac` (0–1) des vollen Tanks.
## Option „Farbsehschwäche“: dieselben Stufen in der Tafel von SignalColors (blau, weiß, gelb-orange, purpurrot).
static func fuel_color(frac: float) -> Color:
	var cs: Array = SignalColors.SAFE_FUEL if SignalColors.safe else [FUEL_FULL_C, FUEL_MID_C, FUEL_LOW_C, FUEL_CRIT_C]
	if frac <= FUEL_RESERVE:
		return cs[3]
	if frac <= FUEL_LOW:
		return cs[2]
	if frac >= FUEL_FADE:
		return cs[0]
	var t := (FUEL_FADE - frac) / (FUEL_FADE - FUEL_LOW)
	return (cs[0] as Color).lerp(cs[1], t * 2.0) if t < 0.5 else (cs[1] as Color).lerp(cs[2], t * 2.0 - 1.0)

## Zustand des Tanks: 0 gut, 1 wird knapp (orange), 2 Reserve (rot).
static func fuel_state(frac: float) -> int:
	return 2 if frac <= FUEL_RESERVE else (1 if frac <= FUEL_LOW else 0)

## Farbe der Hüllenfüllung für den Anteil `frac` (0–1) der vollen Hülle.
## Option „Farbsehschwäche“: blau / gelb / purpurrot (die normale Tafel blau/violett/magenta ist bei Rot-Grün-Schwäche zu ähnlich).
static func hull_color(frac: float) -> Color:
	var ok_c := SignalColors.SAFE_GOOD if SignalColors.safe else HULL_OK_C
	var worn_c := SignalColors.SAFE_MID if SignalColors.safe else HULL_WORN_C
	if frac <= HULL_CRIT:
		return SignalColors.SAFE_BAD if SignalColors.safe else HULL_CRIT_C
	if frac >= HULL_OK:
		return ok_c
	if frac <= HULL_WORN:
		return worn_c
	return ok_c.lerp(worn_c, (HULL_OK - frac) / (HULL_OK - HULL_WORN))

## Zustand der Hülle: 0 heil, 1 angeschlagen (violett), 2 kritisch (magenta).
static func hull_state(frac: float) -> int:
	return 2 if frac <= HULL_CRIT else (1 if frac <= HULL_WORN else 0)

## Helligkeitsstufe einer Bildpunktzeile der Füllung (v = Lage von oben 0 bis unten 1): fünf harte Bänder, oben Glanz, unten Schatten.
static func band(v: float) -> float:
	if v < 1.0 / 6.0:
		return 0.55
	if v < 0.42:
		return 0.2
	if v < 0.72:
		return 0.0
	if v < 5.0 / 6.0:
		return -0.2
	return -0.4

static func tone(c: Color, k: float) -> Color:
	return c.lightened(k) if k >= 0.0 else c.darkened(-k)

## Rechte Kante der Füllung in Bildpunkten ab dem linken Fensterrand, für die Bildpunktzeile `row` von `rows`; `lean` = Schräge in Einheiten.
## Voll und leer sind genau: bei 0 steht nichts, bei 1 ist das Fenster ganz gefüllt.
static func fill_px(frac: float, n: int, row: int, rows: int, lean: float) -> int:
	var w := int(WINDOW.size.x) * n
	if frac <= 0.0:
		return 0
	if frac >= 1.0:
		return w
	var off := lean * (0.5 - (float(row) + 0.5) / float(rows))
	return clampi(int(floor((WINDOW.size.x * frac + off) * float(n) + 0.5)), 0, w)

## Der Tankalarm hat gerade gepiept (game.gd): Die Anzeige blitzt im selben Takt.
func ping() -> void:
	ping_t = 1.0

func update(delta: float, fuel_frac: float, hull_frac: float) -> void:
	age += delta
	ping_t = maxf(0.0, ping_t - delta * 4.5)
	hit_t = maxf(0.0, hit_t - delta * 2.8)
	refuel_t = 0.3 if (fuel_prev >= 0.0 and fuel_frac > fuel_prev + 0.00001) else maxf(0.0, refuel_t - delta)
	fuel_prev = fuel_frac
	if hull_prev < 0.0 or hull_frac >= hull_trail:
		hull_trail = hull_frac                       # Beginn, Reparatur, neues Taxi: kein Nachlauf
	elif hull_frac < hull_prev - 0.0005:
		hit_t = 1.0
		trail_hold = 0.45
	elif trail_hold > 0.0:
		trail_hold -= delta
	else:
		hull_trail = move_toward(hull_trail, hull_frac, delta * 0.55)
	hull_prev = hull_frac

## Ausschnitt der Reihe `row` (0 Tank hinten … 4 Symbole) im Blatt für die Pixelgröße n; `part` = Teilbereich in Einheiten.
static func src(n: int, row: int, part := Rect2(0, 0, 68, 12)) -> Rect2:
	var b := PixelScale.sheet_rect(n, BLOCK)
	return Rect2(b.position + Vector2(part.position.x, float(row) * SIZE.y + part.position.y) * float(n), part.size * float(n))

## Tankanzeige an `pos` (linke obere Ecke, ganze Einheiten). `frac` = Füllung, `cap` = Fassungsvermögen, beide als Anteil des großen Tanks;
## `dead` = Tank leer und die Frist läuft (Symbol blinkt).
func draw_fuel(ci: CanvasItem, pos: Vector2, frac: float, cap := 1.0, dead := false) -> void:
	var n := PixelScale.size_for(ci)
	var calm: bool = Settings.values.reduce_motion
	frac = clampf(frac, 0.0, 1.0)
	var col := fuel_color(frac)
	var flash := ping_t * (0.25 if calm else 0.6) if frac <= FUEL_LOW else 0.0
	var lit := col.lerp(Color.WHITE, flash)
	ci.draw_texture_rect_region(TEX, Rect2(pos, SIZE), src(n, 0))
	_fill(ci, pos, n, frac, lit, col, 0.0)
	if refuel_t > 0.0 and not calm and frac > 0.0:
		_sweep(ci, pos, n, frac, lit)
	if frac > 0.0 and frac < 1.0:                    # helle Kante am Füllstand
		var t := maxi(1, roundi(float(n) / 3.0))
		var ex := fill_px(frac, n, 0, 1, 0.0)
		ci.draw_rect(Rect2(pos + WINDOW.position + Vector2(float(maxi(0, ex - t)) / n, 0.0), Vector2(float(mini(t, ex)) / n, WINDOW.size.y)), tone(lit, 0.7))
	if cap < 0.999:                                  # kleiner Tank (Tagschicht): der Rest des Fensters ist zugebaut
		var cx := float(fill_px(cap, n, 0, 1, 0.0)) / n
		ci.draw_rect(Rect2(pos + WINDOW.position + Vector2(cx, 0.0), Vector2(WINDOW.size.x - cx, WINDOW.size.y)), BLOCKED_C)
		ci.draw_rect(Rect2(pos + WINDOW.position + Vector2(cx, 0.0), Vector2(1.0 / n, WINDOW.size.y)), Color("#060817"))
	ci.draw_texture_rect_region(TEX, Rect2(pos, SIZE), src(n, 1))
	if frac <= FUEL_LOW and ping_t > 0.0:            # Reservemarke unter dem Fenster leuchtet im Takt des Alarms mit
		ci.draw_rect(Rect2(pos + Vector2(WINDOW.position.x, WINDOW.end.y + 0.5), Vector2(WINDOW.size.x * FUEL_RESERVE, 1.0)), Color(1.0, 0.45, 0.4, ping_t))
	var icon := lit
	if dead and int(age * 8.0) % 2 == 0:
		icon = Color(1, 1, 1)
	ci.draw_texture_rect_region(TEX, Rect2(pos, Vector2(12, 12)), src(n, 4, Rect2(0, 0, 12, 12)), icon)

## Hüllenanzeige an `pos`. `frac` = Hülle als Anteil der vollen Hülle.
func draw_hull(ci: CanvasItem, pos: Vector2, frac: float) -> void:
	var n := PixelScale.size_for(ci)
	var calm: bool = Settings.values.reduce_motion
	frac = clampf(frac, 0.0, 1.0)
	var col := hull_color(frac)
	var glow := 0.0
	if frac <= HULL_CRIT and frac > 0.0 and not calm:
		glow = 0.22 * (0.5 + 0.5 * sin(age * 9.0))
	var lit := col.lerp(Color.WHITE, clampf(glow + hit_t * 0.45, 0.0, 0.8))
	ci.draw_texture_rect_region(TEX, Rect2(pos, SIZE), src(n, 2))
	_fill(ci, pos, n, frac, lit, col, SLANT, hull_trail if hull_trail > frac + 0.001 else -1.0)
	ci.draw_texture_rect_region(TEX, Rect2(pos, SIZE), src(n, 3))
	ci.draw_texture_rect_region(TEX, Rect2(pos, Vector2(12, 12)), src(n, 4, Rect2(12, 0, 12, 12)), lit.lerp(Color.WHITE, hit_t * 0.5))

## Füllung des Fensters zeilenweise: gefüllter Teil in fünf Helligkeitsbändern, leerer Teil als dunkles Glas mit einem Hauch der Zustandsfarbe,
## dazwischen (nur Hülle) das eben verlorene Stück.
func _fill(ci: CanvasItem, pos: Vector2, n: int, frac: float, lit: Color, col: Color, lean: float, trail := -1.0) -> void:
	var rows := int(WINDOW.size.y) * n
	var p := 1.0 / float(n)
	var w := int(WINDOW.size.x) * n
	var o := pos + WINDOW.position
	var empty := GLASS_C.lerp(col, 0.12)
	for r in rows:
		var end := fill_px(frac, n, r, rows, lean)
		var y := o.y + float(r) * p
		if end > 0:
			ci.draw_rect(Rect2(o.x, y, float(end) * p, p), tone(lit, band((float(r) + 0.5) / float(rows))))
		var from := end
		if trail >= 0.0:
			var tend := fill_px(trail, n, r, rows, lean)
			if tend > end:
				ci.draw_rect(Rect2(o.x + float(end) * p, y, float(tend - end) * p, p), TRAIL_C.lerp(col, 0.25 if trail_hold > 0.0 else 0.5))
				from = tend
		if from < w:
			ci.draw_rect(Rect2(o.x + float(from) * p, y, float(w - from) * p, p), empty)

## Tanken: ein heller Streifen wandert durch die Füllung nach rechts.
func _sweep(ci: CanvasItem, pos: Vector2, n: int, frac: float, lit: Color) -> void:
	var fw := float(fill_px(frac, n, 0, 1, 0.0)) / n
	var bw := 4.0
	var x := PixelScale.snap(fposmod(age * 46.0, fw + bw * 2.0) - bw, n)
	var a := maxf(x, 0.0)
	var b := minf(x + bw, fw)
	if b > a:
		ci.draw_rect(Rect2(pos + WINDOW.position + Vector2(a, 0.0), Vector2(b - a, WINDOW.size.y)), Color(1, 1, 1, 0.32))
