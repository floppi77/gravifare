class_name Workshop
extends RefCounted
## Werkstatt: kleine Verbesserungen des Taxis je Speicherplatz, bezahlt mit den Credits des laufenden Flugs. Einkaufen lässt sich nur beim Halt
## nach jedem Sektor (src/game/workshop_bay.gd); ein Game Over kostet jeden Einbau eine Stufe, eine neue Karriere beginnt ohne Einbauten.
## Bewusst bescheiden: Das Spiel bleibt ohne Einbauten vollständig lösbar (der Autopilot prüft ohne sie).

const MAX_LEVEL := 3
const PRICES := [2700, 6500, 15000]       # Grundpreise der drei Stufen (erste Werkstatt)
const STEP_FRACTION := 0.10               # jede weitere Werkstatt: jede Stufe um 10 % ihres Grundpreises teurer (linear)
const ITEMS := ["jets", "hull", "gear", "light"]
const JETS_STEP := 0.06      # Spritverbrauch je Stufe
const HULL_STEP := 0.08      # Aufprallschaden je Stufe
const GEAR_STEP := 3.0       # erlaubte Sinkrate (px/s) je Stufe
const LIGHT_STEP := 0.15     # Scheinwerfer: Radius des Lichtkreises um das Taxi in dunklen Leveln je Stufe (nur Darstellung, nur Karriere)

## Halt in der Werkstatt nach dem letzten Level eines Sektors, außer nach Level 99.
static func due(level_number: int) -> bool:
	return level_number % 11 == 0 and level_number < 99

## `data` ist der Speicherstand (Save.data): reine Daten, damit die Klasse auch in Tests ohne Autoloads läuft.
static func level_of(data: Dictionary, id: String) -> int:
	var w = data.get("workshop", {})
	return clampi(int(w.get(id, 0)), 0, MAX_LEVEL) if w is Dictionary else 0

## Wirkung als Zahlen, für TaxiSim und Replay. `levels`: {id: Stufe}.
static func mods_for(levels: Dictionary) -> Dictionary:
	return {"burn": 1.0 - JETS_STEP * float(levels.get("jets", 0)), "damage": 1.0 - HULL_STEP * float(levels.get("hull", 0)),
		"land_vy": Tuning.LAND_VY + GEAR_STEP * float(levels.get("gear", 0))}

## Scheinwerfer: Faktor auf den Radius des Lichtkreises um das Taxi (dark_view.gd). Wirkt nur auf die Darstellung, nicht auf TaxiSim oder Replays.
static func light_k_for(level: int) -> float:
	return 1.0 + LIGHT_STEP * float(clampi(level, 0, MAX_LEVEL))

static func light_k(data: Dictionary) -> float:
	return light_k_for(level_of(data, "light"))

## Einbauten nach einem Game Over: jede Stufe eins weniger, nie unter 0 (Einträge mit Stufe 0 entfallen).
static func downgraded(data: Dictionary) -> Dictionary:
	var out := {}
	for id in ITEMS:
		var l := level_of(data, id) - 1
		if l > 0:
			out[id] = l
	return out

static func mods(data: Dictionary) -> Dictionary:
	var levels := {}
	for id in ITEMS:
		levels[id] = level_of(data, id)
	return mods_for(levels)

## Preisfaktor der Werkstatt nach `sector` (1 = erste Werkstatt): je weiterer Werkstatt +10 % des Grundpreises der jeweiligen Stufe (linear).
static func price_factor(sector: int) -> float:
	return 1.0 + STEP_FRACTION * float(maxi(sector - 1, 0))

static func price(data: Dictionary, id: String, sector := 1) -> int:
	var l := level_of(data, id)
	return int(round(float(PRICES[l]) * price_factor(sector))) if l < MAX_LEVEL else 0

## Kauf der nächsten Stufe mit `credits` (Kasse des laufenden Flugs). Gibt die Credits danach zurück, -1, wenn es nicht geht; der Aufrufer speichert.
static func buy(data: Dictionary, id: String, credits: float, sector := 1) -> float:
	var l := level_of(data, id)
	var cost := price(data, id, sector)
	if l >= MAX_LEVEL or credits < float(cost):
		return -1.0
	if not (data.get("workshop") is Dictionary):
		data["workshop"] = {}
	data.workshop[id] = l + 1
	return credits - float(cost)
