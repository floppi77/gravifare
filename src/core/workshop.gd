class_name Workshop
extends RefCounted
## Werkstatt: kleine Verbesserungen des Taxis je Speicherplatz, bezahlt mit den Credits des laufenden Flugs. Einkaufen lässt sich nur beim Halt
## nach jedem Sektor (src/game/workshop_bay.gd); ein Game Over nimmt alle Einbauten wieder heraus.
## Bewusst bescheiden: Das Spiel bleibt ohne Einbauten vollständig lösbar (der Autopilot prüft ohne sie).

const MAX_LEVEL := 3
const PRICES := [2000, 6000, 15000]
const ITEMS := ["jets", "hull", "gear"]
const JETS_STEP := 0.06      # Spritverbrauch je Stufe
const HULL_STEP := 0.08      # Aufprallschaden je Stufe
const GEAR_STEP := 3.0       # erlaubte Sinkrate (px/s) je Stufe

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

static func mods(data: Dictionary) -> Dictionary:
	var levels := {}
	for id in ITEMS:
		levels[id] = level_of(data, id)
	return mods_for(levels)

static func price(data: Dictionary, id: String) -> int:
	var l := level_of(data, id)
	return PRICES[l] if l < MAX_LEVEL else 0

## Kauf der nächsten Stufe mit `credits` (Kasse des laufenden Flugs). Gibt die Credits danach zurück, -1, wenn es nicht geht; der Aufrufer speichert.
static func buy(data: Dictionary, id: String, credits: float) -> float:
	var l := level_of(data, id)
	if l >= MAX_LEVEL or credits < float(PRICES[l]):
		return -1.0
	if not (data.get("workshop") is Dictionary):
		data["workshop"] = {}
	data.workshop[id] = l + 1
	return credits - float(PRICES[l])
