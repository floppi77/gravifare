extends RefCounted
## Erfolge: reine Auswertung des Spielstands (Save.data), ohne eigene Zähler. Dadurch zählt auch Fortschritt von vor Runde 78 rückwirkend.
## Einmal erreichte Erfolge stehen mit Datum in data.achievements und gehen nie verloren (auch nicht nach einem Game Over, das
## data.completed eines Sektors leert). Sektor-Erfolge lesen ever_completed (bleibt nach Game Over), Medaillen-Erfolge nur, was noch da ist.
## Nicht gewertet: Debug-Modus, Entwicklerschalter (dev_session), Community-Level (community_mode) – das prüft Save.write.
## Einbinden mit: const Achievements := preload("res://src/core/achievements.gd")

const SECTORS := 9
const LEVELS_PER_SECTOR := 11

## id: [Kategorie (Symbol und Farbe), Ziel]. Name/Beschreibung: ACH_<ID> und ACH_<ID>_D (Beschreibung mit %d für das Ziel, falls vorhanden).
const LIST := [
	["first_fare", "fare", 1], ["fares_100", "fare", 100], ["fares_500", "fare", 500],
	["sector_1", "sector", 1], ["sector_5", "sector", 5], ["all_levels", "sector", 99], ["career_done", "sector", 1],
	["triple", "medal", 1], ["medals_50", "medal", 50], ["sector_gold", "medal", 1], ["medals_all", "medal", 297],
	["perfect_25", "landing", 25], ["perfect_250", "landing", 250], ["streak_10", "landing", 10],
	["credits_10k", "money", 10000], ["credits_100k", "money", 100000],
	["shift_done", "shift", 1], ["shift_s", "shift", 1],
	["day_gold", "day", 1], ["day_streak_7", "day", 7],
	["workshop_max", "garage", 1], ["new_look", "garage", 1],
	["pump_boom", "fun", 1], ["crashes_50", "fun", 50], ["community", "fun", 1], ["hours_10", "time", 10],
	["eggs_20", "egg", 20],
	["ot_first", "overtime", 1], ["ot_short", "overtime", 1], ["ot_medium", "overtime", 1], ["ot_long", "overtime", 1],
	["ot_stage5", "overtime", 1], ["ot_rank10", "overtime", 10], ["ot_pacts3", "overtime", 3], ["ot_score", "overtime", 100000], ["ot_licenses", "overtime", 6],
	["day_nikolaus", "holiday", 1], ["day_xmas", "holiday", 1], ["day_silvester", "holiday", 1], ["day_valentine", "holiday", 1],
	["all_done", "crown", 40],
]

## Runde 86: verdeckt, bis sie erreicht sind (Name und Beschreibung „???“ in der Übersicht; Steam: „Hidden“). Nichts verraten.
const HIDDEN := ["eggs_20", "day_nikolaus", "day_xmas", "day_silvester", "day_valentine"]

static func is_hidden(id: String) -> bool:
	return id in HIDDEN

static func ids() -> Array:
	return LIST.map(func(e): return String(e[0]))

static func entry(id: String) -> Array:
	for e in LIST:
		if e[0] == id:
			return e
	return []

static func goal(id: String) -> int:
	var e := entry(id)
	return int(e[2]) if not e.is_empty() else 1

static func category(id: String) -> String:
	var e := entry(id)
	return String(e[1]) if not e.is_empty() else "fun"

## Alle jemals geschafften Karriere-Level (wie Save.ever_completed, aber auf den reinen Daten).
static func _ever(data: Dictionary) -> Dictionary:
	var out: Dictionary = (data.get("ever", {}) as Dictionary).duplicate() if data.get("ever", {}) is Dictionary else {}
	if data.get("completed", {}) is Dictionary:
		out.merge(data.completed)
	return out

static func _sector_done(ever: Dictionary, s: int) -> bool:
	for i in range(1, LEVELS_PER_SECTOR + 1):
		if not ever.has("s%d_%02d" % [s, i]):
			return false
	return true

static func _medal_count(m) -> int:
	if not (m is Dictionary):
		return 0
	return int(bool(m.get("time", false))) + int(bool(m.get("clean", false))) + int(bool(m.get("pro", false)))

## Fortschritt [aktuell, Ziel] eines Erfolgs aus dem Spielstand (aktuell ≥ Ziel = erreicht).
static func progress(data: Dictionary, id: String) -> Array:
	var st: Dictionary = data.get("stats", {}) if data.get("stats", {}) is Dictionary else {}
	var g := goal(id)
	var ever := _ever(data)
	var comp: Dictionary = data.get("completed", {}) if data.get("completed", {}) is Dictionary else {}
	var cur := 0
	match id:
		"first_fare", "fares_100", "fares_500":
			cur = int(st.get("deliveries", 0))
		"sector_1":
			cur = 1 if _sector_done(ever, 1) else 0
		"sector_5":
			for s in range(1, 6):
				cur += 1 if _sector_done(ever, s) else 0
		"all_levels":
			for s in range(1, SECTORS + 1):
				for i in range(1, LEVELS_PER_SECTOR + 1):
					cur += 1 if ever.has("s%d_%02d" % [s, i]) else 0
		"career_done":
			cur = 1 if int(st.get("finale_seen", 0)) > 0 else 0
		"triple":
			for k in comp:
				if _medal_count(comp[k].get("medals", {}) if comp[k] is Dictionary else {}) == 3:
					cur = 1
					break
		"medals_50", "medals_all":
			for k in comp:
				if String(k).begins_with("s") and comp[k] is Dictionary:
					cur += _medal_count(comp[k].get("medals", {}))
		"sector_gold":
			for s in range(1, SECTORS + 1):
				var all := true
				for i in range(1, LEVELS_PER_SECTOR + 1):
					var e = comp.get("s%d_%02d" % [s, i])
					if not (e is Dictionary) or _medal_count(e.get("medals", {})) < 3:
						all = false
						break
				if all:
					cur = 1
					break
		"perfect_25", "perfect_250":
			cur = int(st.get("perfect_landings", 0))
		"streak_10":
			cur = int(st.get("best_streak", 0))
		"credits_10k", "credits_100k":
			cur = int(st.get("credits_total", 0))
		"shift_done":
			cur = int(st.get("shift_runs", 0))
		"shift_s":
			cur = 1 if String(st.get("shift_best_grade", "")) == "S" else 0
		"day_gold":
			cur = int(st.get("day_golds", 0))
		"day_streak_7":
			cur = int(st.get("daily_best_streak", 0))
		"workshop_max":
			var w = data.get("workshop", {})
			if w is Dictionary:
				for k in w:
					if int(w[k]) >= 3:
						cur = 1
		"new_look":
			var c = data.get("cosmetics", {})
			if c is Dictionary and (String(c.get("paint", "std")) != "std" or String(c.get("sticker", "none")) != "none"):
				cur = 1
		"pump_boom":
			cur = int(st.get("pump_explosions", 0))
		"crashes_50":
			cur = int(st.get("crashes", 0))
		"community":
			var cm = data.get("community", {})
			if cm is Dictionary:
				for k in cm:
					if cm[k] is Dictionary and int(cm[k].get("plays", 0)) > 0:
						cur = 1
						break
		"hours_10":
			cur = int(float(st.get("play_seconds", 0.0)) / 3600.0)
		"eggs_20":
			cur = (st.eggs as Dictionary).size() if st.get("eggs") is Dictionary else 0
		"day_nikolaus", "day_xmas", "day_silvester", "day_valentine":
			cur = 1 if st.get("holidays") is Dictionary and (st.holidays as Dictionary).has(id.substr(4)) else 0
		"ot_first", "ot_short", "ot_medium", "ot_long", "ot_stage5", "ot_rank10", "ot_pacts3", "ot_score", "ot_licenses":
			cur = _overtime(data, id)
		"all_done":                                   # alle anderen Erfolge (gespeichert oder gerade erreicht)
			var have := stored(data)
			for e in LIST:
				var o := String(e[0])
				if o == "all_done":
					continue
				if have.has(o):
					cur += 1
				else:
					var p := progress(data, o)
					cur += 1 if p[0] >= p[1] else 0
	return [mini(cur, g), g]

## Sonderschicht (Save.data.overtime.meta, siehe Overtime.record).
static func _overtime(data: Dictionary, id: String) -> int:
	var o = data.get("overtime", {})
	var m = o.get("meta", {}) if o is Dictionary else {}
	if not (m is Dictionary):
		return 0
	var wl: Dictionary = m.get("wins_len", {}) if m.get("wins_len") is Dictionary else {}
	match id:
		"ot_first":
			return int(m.get("runs", 0))
		"ot_short", "ot_medium", "ot_long":
			return 1 if int(wl.get(id.substr(3), 0)) > 0 else 0
		"ot_stage5":
			return 1 if int(m.get("stage_won", -1)) >= 5 else 0
		"ot_rank10":
			return Overtime.rank_of(int(m.get("xp", 0)))
		"ot_pacts3":
			return int(m.get("pacts_won", 0))
		"ot_score":
			return int(m.get("best_score", 0))
		"ot_licenses":
			return (m.get("licenses_won", []) as Array).size() if m.get("licenses_won") is Array else 0
	return 0

## Erfolge, deren Bedingung der Spielstand gerade erfüllt (ohne Blick auf die gespeicherten).
static func reached(data: Dictionary) -> Array:
	return ids().filter(func(id):
		var p := progress(data, id)
		return p[0] >= p[1])

## Gespeicherte Erfolge {id: Datum}.
static func stored(data: Dictionary) -> Dictionary:
	var a = data.get("achievements")
	return a if a is Dictionary else {}

static func is_unlocked(data: Dictionary, id: String) -> bool:
	return stored(data).has(id)

## Neu erreichte Erfolge mit Datum eintragen. Rückgabe {"new": [ids], "retro": bool}: retro = erster Abgleich eines älteren Spielstands
## (dann kein Einzelbanner je Erfolg, sondern ein Sammelhinweis).
static func update(data: Dictionary, date: String) -> Dictionary:
	var first := not (data.get("achievements") is Dictionary)
	var have := stored(data)
	var fresh: Array = []
	for id in reached(data):
		if not have.has(id):
			have[id] = date
			fresh.append(id)
	data["achievements"] = have
	return {"new": fresh, "retro": first and not fresh.is_empty()}
