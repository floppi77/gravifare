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
const HULL_HALF := Vector2(10, 5)
const FOOT_X := 8.0
const GEAR_LEN := 5.0
const GEAR_TIME := 0.22

# Landefenster (fair, im HUD sichtbar)
const LAND_VY := 48.0
const LAND_VX := 32.0
const LAND_TILT := 0.15          # rad (~8,5°)
const LAND_SOFT_VY := 22.0       # unter diesem Wert gilt die Landung als "weich" (Bonus)

# Schaden
const HULL_MAX := 100.0
const IMPACT_SAFE := 70.0        # Aufprall darunter: kein Schaden
const IMPACT_DAMAGE := 0.45      # Schaden je px/s darüber
const BOUNCE := 0.35

# Treibstoff (0..100)
const FUEL_MAX := 100.0
const BURN_UP := 1.6
const BURN_SIDE := 0.7
const BURN_DOWN := 0.8
const REFUEL_RATE := 25.0
const FUEL_PRICE := 0.6          # Credits je Einheit
const EMERGENCY_FUEL := 35.0     # bis hierhin tankt die Station immer kostenlos

# Auftragsablauf
const BOARD_TIME := 0.9
const EXIT_COUNTDOWN := 0.0
