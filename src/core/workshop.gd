class_name Workshop
extends RefCounted
## Werkstatt: dauerhafte, kleine Verbesserungen des Taxis je Speicherplatz, bezahlt mit den Credits des laufenden Feldzugs.
## Bewusst bescheiden: Das Spiel bleibt ohne Einbauten vollständig lösbar (der Autopilot prüft ohne sie).

const MAX_LEVEL := 3
const PRICES := [2000, 6000, 15000]
const ITEMS := ["jets", "hull", "gear"]
const JETS_STEP := 0.06      # Spritverbrauch je Stufe
const HULL_STEP := 0.08      # Aufprallschaden je Stufe
const GEAR_STEP := 3.0       # erlaubte Sinkrate (px/s) je Stufe

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

static func credits(data: Dictionary) -> float:
	var c = data.get("campaign", {})
	return float(c.get("credits", 0.0)) if c is Dictionary else 0.0

static func price(data: Dictionary, id: String) -> int:
	var l := level_of(data, id)
	return PRICES[l] if l < MAX_LEVEL else 0

## Kauf der nächsten Stufe; zieht die Credits vom gespeicherten Feldzug ab (der Aufrufer speichert). false, wenn es nicht geht.
static func buy(data: Dictionary, id: String) -> bool:
	var l := level_of(data, id)
	var c = data.get("campaign", {})
	if l >= MAX_LEVEL or not (c is Dictionary) or not c.has("level") or credits(data) < float(PRICES[l]):
		return false
	if not (data.get("workshop") is Dictionary):
		data["workshop"] = {}
	data.workshop[id] = l + 1
	c["credits"] = credits(data) - float(PRICES[l])
	return true
