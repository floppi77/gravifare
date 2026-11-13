class_name TrackList
extends RefCounted
## Alle Musikstücke des Spiels für den Musikplayer und ihre Freischaltung: Sektorthemen mit einem geschafften Level des Sektors,
## das Thema von Level 99 und das Finale mit Level 99; das Hauptmenü-Thema ist immer frei.

const SECTOR_THEMES := {1: ["t00", "t01"], 2: ["t02", "t03"], 3: ["t04", "t05", "t06"], 4: ["t07", "t08"], 5: ["t09", "t10"],
		6: ["t11", "t12"], 7: ["t13", "t14"], 8: ["t15", "t16", "t17"], 9: ["t18", "t19"]}
const LAST_LEVEL := "s9_11"

static func all() -> Array:
	var out: Array = [{"theme": "menu", "sector": 0}]
	for s in range(1, 10):
		for th in SECTOR_THEMES[s]:
			out.append({"theme": th, "sector": s})
	out.append({"theme": "t99", "sector": 0})
	out.append({"theme": "finale", "sector": 0})
	return out

## `completed`: geschaffte Level des Spielstands (Schlüssel = Level-ID wie s2_06).
static func unlocked(track: Dictionary, completed: Dictionary, debug: bool) -> bool:
	if debug or String(track.theme) == "menu":
		return true
	if String(track.theme) == "finale" or String(track.theme) == "t99":
		return completed.has(LAST_LEVEL)
	var prefix := "s%d_" % int(track.sector)
	for id in completed:
		if String(id).begins_with(prefix):
			return true
	return false
