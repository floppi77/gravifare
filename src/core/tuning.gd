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
const IMPACT_SAFE := 40.0        # Aufprall darunter: kein Schaden
const CRASH_SPEED := 150.0       # Aufprall ab hier: Taxi sofort zerstört
const SPIKE_DAMAGE := 30.0       # Dornen: fester Zusatzschaden je Berührung, unabhängig vom Tempo
const DOOR_CRUSH_DAMAGE := 30.0   # Tor schließt auf dem Taxi: Schaden und Rauswurf zur nächsten Seite
const DOOR_EJECT_SPEED := 70.0
const EJECT_LETHAL_HEIGHT := 24.0 # Fallhöhe (px) ab der ein rausgeworfener Fahrgast stirbt
const OUT_OF_FUEL_TIME := 3.0     # Sekunden mit leerem Tank (außer an einer funktionierenden Zapfsäule), dann Taxi verloren
const SPIKE_COOLDOWN := 0.5      # Sekunden, in denen dieselbe Berührung nicht erneut zählt
const DAMAGE_EXP := 1.3          # Schaden = 100 * ((v-40)/(150-40))^1.3 (ab 40 px/s Schaden, schnell steigend)
const BOUNCE := 0.35

# Treibstoff (0..100)
const FUEL_MAX := 100.0
const BURN_UP := 1.6
const BURN_SIDE := 0.7
const BURN_DOWN := 0.8
const REFUEL_RATE := 25.0
const FUEL_PRICE := 3.0          # Credits je Einheit (Richtwert; echte Preise: siehe Spritpreis-Zufall)
# Spritpreise: je Level zufällig in festem Bereich ("nie zu billig, nie zu teuer"), Wechsel in zufälligen Abständen
const FUEL_PRICE_MIN := 2.00      # Level 1; höhere Level: × price_scale()
const FUEL_PRICE_MAX := 4.20
const PRICE_EVERY_MIN := 20.0     # Sekunden Levelzeit zwischen zwei Preiswechseln (zufällig im Bereich)
const PRICE_EVERY_MAX := 45.0
const PRICE_MIN_STEP := 0.5       # jeder Wechsel ändert den Preis merklich
const PRICE_PER_LEVEL := 0.03     # Spritpreise steigen je Level um 3 % (Level 99 ≈ 3,9-fach)
# Zapfsäule: Berührung steigert den Preis sofort; 3 Berührungen = Explosion, Station defekt
const PRICE_TOUCH_SURCHARGE := 0.25
const PRICE_HARD_CAP := 1.6       # Obergrenze (× Maximalpreis) auch bei Berührungen
const PUMP_TOUCHES_TO_BREAK := 3
const PUMP_TOUCH_COOLDOWN := 1.2
const PUMP_BOOM_DELAY := 0.7
const EMERGENCY_FUEL := 35.0     # bis hierhin tankt die Station immer kostenlos

# Belohnungen: Auftrags-Fahrpreise sinken ab Level 5 (Zusatzfahrgäste werden nötig, um im Plus zu bleiben)
const FARE_SCALE_LATE := 0.22
const FARE_SCALE_FROM := 5
const EXTRA_FARE_FACTOR := 1.0       # Zusatzfahrgäste zahlen nach dem unskalierten Durchschnitt der Auftragspreise

static func fare_scale(level_no: int) -> float:
	return 1.0 if level_no < FARE_SCALE_FROM else FARE_SCALE_LATE

# Mindest-Fahrpreis: Bei guter Flugweise bleibt jeder Fahrgast bis hinunter zu 25 % Zufriedenheit profitabel.
# Zufriedenheit = Zeitfaktor normiert zwischen PAY_MIN (0 %) und PAY_MAX (100 %); der Spritverbrauch wird aus der Strecke geschätzt.
const SAT_FLOOR := 0.25
const FUEL_PER_PX := 0.040           # Treibstoffeinheiten je px Flugstrecke inkl. Anflug-Umwege (am Autopiloten kalibriert, der eher mehr verbraucht als ein guter Pilot)
const PICKUP_FACTOR := 1.6           # Anflug zum Fahrgast zählt zur Fahrt dazu (Mehrfaches der Fahrstrecke)
const PROFIT_MARGIN := 1.25

## Obergrenzen je Levelnummer: Pflichtfahrgäste (Aufträge) und Passagierpads. Pads: Zeichen 1–9, daher höchstens 9.
static func max_jobs(level_no: int) -> int:
	if level_no <= 3: return 3
	if level_no <= 33: return 6
	if level_no <= 55: return 7
	if level_no <= 77: return 8
	return 9

static func max_pads(level_no: int) -> int:
	if level_no <= 22: return 4
	if level_no <= 33: return 5
	if level_no <= 44: return 6
	if level_no <= 66: return 7
	if level_no <= 88: return 8
	return 9

static func satisfaction_factor(sat: float) -> float:
	return PAY_MIN + sat * (PAY_MAX - PAY_MIN)

# Kosten: Reparatur der Hülle am Levelende, Ersatztaxi nach Totalschaden (Credits)
const REPAIR_COST := 2.0          # je verlorenem Hüllenpunkt des überlebenden Taxis
const REPLACE_BASE := 80.0        # Ersatztaxi nach Zerstörung
const REPLACE_PER_LEVEL := 2.0    # … plus je Levelnummer

# Zusatzfahrgäste (Funkrufe): ab Level 5 erscheinen weitere Fahrgäste, auch während das Taxi jemanden fährt.
# Das Taxi hat einen Sitz. Wer zu lange wartet, schimpft und geht.
const EXTRA_FROM_LEVEL := 5
const EXTRA_FIRST_MIN := 6.0         # Sekunden bis zum ersten Zusatzfahrgast
const EXTRA_FIRST_MAX := 11.0
const EXTRA_EVERY_MIN := 9.0         # Abstand zwischen zwei Zusatzfahrgästen
const EXTRA_EVERY_MAX := 18.0
const EXTRA_PATIENCE_MIN := 20.0     # Geduld in Sekunden
const EXTRA_PATIENCE_MAX := 34.0
const MAIN_PATIENCE_MIN := 45.0      # Auftrags-Fahrgäste warten länger, gehen aber auch (Ersatz-Fahrgast erscheint)
const MAIN_PATIENCE_MAX := 70.0
const NEXT_SPAWN_MIN := 2.5          # Pause nach dem Absetzen, bis der nächste Auftrags-Fahrgast erscheint
const NEXT_SPAWN_MAX := 6.0

## Wie viele Zusatzfahrgäste gleichzeitig warten dürfen (0 = noch keine).
static func extra_slots(level_no: int) -> int:
	if level_no < EXTRA_FROM_LEVEL:
		return 0
	return 1 if level_no < 11 else (2 if level_no < 31 else 3)

# Auftragsablauf
const BOARD_TIME := 0.9
const EXIT_COUNTDOWN := 0.0

# Kampagne: Leben, Sprit-Übernahme
const START_LIVES := 5
const MAX_LIVES := 5             # mehr als 5 Leben gibt es nie (auch nicht gekauft)
const LIFE_PRICE := 1000.0       # Lebens-Station: ein Leben für 1000 Credits
const LIFE_BUY_TIME := 1.2       # Sekunden Landezeit bis zum Kauf
const MIN_START_FUEL := 35.0     # Mindestvorrat zu Levelbeginn (nie Sackgasse durch leeren Tank)

# Bezahlung: je schneller vom Erscheinen des Fahrgasts bis zum Ziel, desto mehr Credits
const PAY_MAX := 1.6             # Faktor bei sofortiger Zustellung
const PAY_MIN := 0.35            # Untergrenze bei sehr langer Fahrt
const PAY_SLOPE := 0.6           # Faktor sinkt um 0,6 je ganzer Richtzeit (par); bei par genau 1,0
const LAND_PENALTY_MAX := 0.30
const WRONG_PAD_PEN := 0.15      # Fahrpreisabzug je Landung an falscher Plattform mit Fahrgast an Bord
const RIDE_HIT_PEN := 0.08       # Fahrpreisabzug je Hüllenschaden mit Fahrgast an Bord
const RIDE_PEN_MAX := 0.5
const MISSED_FEE_FACTOR := 0.35   # Abzug für einen verpassten Pflichtfahrgast: Anteil des (unskalierten) Fahrpreises
# Serie perfekter Landungen: weich, geradeaus, waagerecht – jede weitere in Folge erhöht den Fahrpreis
const PERFECT_VX := 12.0
const PERFECT_TILT := 0.07
const COMBO_STEP := 0.05          # +5 % je Serienstufe
const COMBO_MAX := 6              # höchstens +30 %
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

static func price_scale(level_no: int) -> float:
	return 1.0 + PRICE_PER_LEVEL * float(maxi(level_no - 1, 0))

static func replacement_fee(level_no: int) -> float:
	return REPLACE_BASE + REPLACE_PER_LEVEL * float(level_no)
