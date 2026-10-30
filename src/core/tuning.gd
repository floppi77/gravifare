class_name Tuning
## Zentrale, dokumentierte Flug- und Landeparameter (Einheiten: Pixel, Sekunden).
## Änderungen hier wirken auf Spiel, Validatoren und Tests gleichermaßen.

const TILE := 16
const TICK := 1.0 / 120.0

# Flugphysik
const GRAVITY := 90.0            # px/s², Standard (Level darf überschreiben)
const THRUST_UP := 230.0         # Hauptdüse, px/s²
const THRUST_DOWN := 110.0       # Bremsdüse nach unten
const THRUST_SIDE := 125.0       # Seitendüsen
const DRAG := 0.18               # lineare Dämpfung pro Sekunde (Trägheit bleibt spürbar)
const MAX_SPEED := 240.0
const TILT_MAX := 0.24           # rad bei vollem Seitenschub (~14°)
const TILT_RATE := 9.0           # Glättung der Neigung pro Sekunde

# Fahrwerk ausgefahren = Feinmanöver: schwächere Düsen, starke Dämpfung, niedrigere Höchstgeschwindigkeit.
# Eingefahren = schnelle Navigation (Werte oben). Der Übergang folgt der Fahrwerksanimation.
const GEAR_THRUST_UP := 150.0
const GEAR_THRUST_DOWN := 80.0
const GEAR_THRUST_SIDE := 68.0
const GEAR_DRAG := 1.1
const GEAR_MAX_SPEED := 90.0

# Hülle
const TAXI_SCALE := 0.8           # Taxi 20 % kleiner als im ersten Entwurf (mehr Platz auf den Pads)
const HULL_HALF := Vector2(8, 4)
const FOOT_X := 6.4
const GEAR_LEN := 4.0

# Fahrgäste (85 % der ursprünglichen Größe, passend zum kleineren Taxi)
const PASS_SCALE := 0.85
const PASS_W := 6.8
const PASS_H := 10.2
const PASS_HALF_W := 3.0
const PASS_CLEAR := 2.0           # Sicherheitsabstand Taxi–Fahrgast bei der Landefenster-Berechnung
const LAND_WINDOW_EARLY := 34.0   # Mindestbreite (px) des freien Landebereichs je Passagierpad in Level 1–3
const LAND_WINDOW_FLOOR := 20.0   # …sinkt bis Level 99 auf diesen Wert (kleine Pads sind in späten Leveln gewollt)
const GEAR_TIME := 0.22

# Landefenster (fair, im HUD sichtbar)
const LAND_VY := 48.0
const LAND_VX := 32.0
const LAND_TILT := 0.15          # rad (~8,5°)
const LAND_SOFT_VY := 22.0       # unter diesem Wert gilt die Landung als "weich" (Bonus)

# Schaden
const HULL_MAX := 100.0
const IMPACT_SAFE := 70.0        # Aufprall darunter: kein Schaden
const CRASH_SPEED := 170.0       # Aufprall ab hier: Taxi sofort zerstört
const DAMAGE_EXP := 1.6          # Schaden = 100 * ((v-70)/(170-70))^1.6 (leichte Stöße harmlos, schwere teuer)
const BOUNCE := 0.35

# Treibstoff (0..100)
const FUEL_MAX := 100.0
const BURN_UP := 1.6
const BURN_SIDE := 0.7
const BURN_DOWN := 0.8
const REFUEL_RATE := 25.0
const FUEL_PRICE := 0.6          # Credits je Einheit (Richtwert; echte Preise: siehe Spritpreis-Zufall)
# Spritpreise: je Level zufällig in festem Bereich ("nie zu billig, nie zu teuer"), Wechsel in zufälligen Abständen
const FUEL_PRICE_MIN := 0.40
const FUEL_PRICE_MAX := 0.90
const PRICE_EVERY_MIN := 20.0     # Sekunden Levelzeit zwischen zwei Preiswechseln (zufällig im Bereich)
const PRICE_EVERY_MAX := 45.0
const PRICE_MIN_STEP := 0.12      # jeder Wechsel ändert den Preis merklich
# Zapfsäule: Berührung steigert den Preis sofort; 3 Berührungen = Explosion, Station defekt
const PRICE_TOUCH_SURCHARGE := 0.25
const PRICE_HARD_CAP := 1.6       # Obergrenze (× Maximalpreis) auch bei Berührungen
const PUMP_TOUCHES_TO_BREAK := 3
const PUMP_TOUCH_COOLDOWN := 1.2
const PUMP_BOOM_DELAY := 0.7
const EMERGENCY_FUEL := 35.0     # bis hierhin tankt die Station immer kostenlos

# Auftragsablauf
const BOARD_TIME := 0.9
const EXIT_COUNTDOWN := 0.0

# Kampagne: Leben, Sprit-Übernahme
const START_LIVES := 5
const MIN_START_FUEL := 35.0     # Mindestvorrat zu Levelbeginn (nie Sackgasse durch leeren Tank)

# Bezahlung: je schneller vom Erscheinen des Fahrgasts bis zum Ziel, desto mehr Credits
const PAY_MAX := 1.6             # Faktor bei sofortiger Zustellung
const PAY_MIN := 0.35            # Untergrenze bei sehr langer Fahrt
const PAY_SLOPE := 0.6           # Faktor sinkt um 0,6 je ganzer Richtzeit (par); bei par genau 1,0
const LAND_PENALTY_MAX := 0.30
const WALK_TIME_WEIGHT := 2.5    # Gehzeit zum Häuschen zählt 2,5-fach (nahes Landen lohnt spürbar)
# Streckenzuschlag: lange/schwierige Fahrten zahlen bis zu +60 % (Länge, enger Korridor, kleines Ziel-Landefenster)
const DIST_BONUS_LEN := 0.30
const DIST_BONUS_NARROW := 0.20
const DIST_BONUS_WINDOW := 0.10   # max. Abzug je harter Landung (Sinkrate = Limit)

static func time_factor(t: float, par: float) -> float:
	var ratio := t / maxf(par, 1.0)
	return clampf(1.0 + (1.0 - ratio) * PAY_SLOPE, PAY_MIN, PAY_MAX)

static func landing_penalty(vy: float) -> float:
	return clampf((vy - LAND_SOFT_VY) / (LAND_VY - LAND_SOFT_VY), 0.0, 1.0) * LAND_PENALTY_MAX

## Kleinstes erlaubtes Landefenster für ein Level: konstant für Level 1–3, danach linear fallend bis Level 99.
static func min_land_window(level_no: int) -> float:
	if level_no <= 3:
		return LAND_WINDOW_EARLY
	return lerpf(LAND_WINDOW_EARLY, LAND_WINDOW_FLOOR, clampf(float(level_no - 3) / 96.0, 0.0, 1.0))
