class_name Progress
extends RefCounted
## Fortschritt je Sektor für die Levelauswahl: geschaffte Level und Sterne. Reine Logik ohne Autoloads (testbar);
## `completed` ist `Save.data.completed` ({id: {medals: {time, clean, pro}, …}}).

const PER_SECTOR := 11
const STARS_PER_LEVEL := 3

## Level `ids` des Sektors `n` (1–9) in Reihenfolge.
static func sector_ids(ids: Array, n: int) -> Array:
	return ids.slice((n - 1) * PER_SECTOR, mini(n * PER_SECTOR, ids.size()))

## {done, total, stars, stars_max} für eine Liste von Leveln.
static func of(list: Array, completed: Dictionary) -> Dictionary:
	var done := 0
	var stars := 0
	for id in list:
		if not completed.has(id):
			continue
		done += 1
		var e = completed[id]
		var m = e.get("medals", {}) if e is Dictionary else {}
		if m is Dictionary:
			for k in ["time", "clean", "pro"]:
				stars += 1 if bool(m.get(k, false)) else 0
	return {"done": done, "total": list.size(), "stars": stars, "stars_max": list.size() * STARS_PER_LEVEL}

static func sector(ids: Array, completed: Dictionary, n: int) -> Dictionary:
	return of(sector_ids(ids, n), completed)

## Anteil 0–1 der geschafften Level; `gold`: alle Sterne des Sektors.
static func share(p: Dictionary) -> float:
	return float(p.done) / float(maxi(int(p.total), 1))

static func gold(p: Dictionary) -> bool:
	return int(p.total) > 0 and int(p.stars) >= int(p.stars_max)
