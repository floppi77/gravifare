class_name Daily
## Tagesflug: eine Karte pro Tag mit festem Seed. Gleiches Datum = gleiche Karte (bei gleichem Fortschritt), gleiche Aufträge,
## gleiche Spritpreise und Zusatzfahrgäste; geflogen wird mit dem Serientaxi (ohne Werkstatt-Einbauten), damit Ergebnisse
## vergleichbar bleiben. Beliebig viele Versuche, gewertet wird der beste des Tages. Reine Logik ohne Autoloads (testbar).

const JOBS_LEVEL := 2                    # Länge der Auftragskette wie die dritte Karte einer Nachtschicht: 5 Fahrten + Ausgang
const UNLOCK_LEVELS := 11                # freigeschaltet, sobald so viele Level geschafft sind (Sektor 1)

## Dev: festes Datum statt der Systemzeit (--day-date=JJJJ-MM-TT), z. B. um die Regel eines Wochentags zu sehen.
static var override_date := ""

## Heutiges Datum (Ortszeit) als "JJJJ-MM-TT".
static func today() -> String:
	return override_date if override_date != "" else Time.get_date_string_from_system()

## Seed eines Tages: JJJJMMTT als Zahl (z. B. 20261103).
static func seed_for(date: String) -> int:
	return int(date.replace("-", ""))

## Karte des Tages aus `pool` (Level-IDs; sortiert, damit die Wahl nicht von der Reihenfolge abhängt).
static func pick_level(pool: Array, date: String) -> String:
	if pool.is_empty():
		return ""
	var ids := pool.duplicate()
	ids.sort()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_for(date)
	return String(ids[rng.randi() % ids.size()])

## Auftragskette des Tages auf `lvl`.
static func jobs_for(lvl: LevelData, date: String) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_for(date) * 31 + 7
	return Run.shift_jobs(lvl, JOBS_LEVEL, rng)

## Vortag von `date` ("JJJJ-MM-TT").
static func yesterday(date: String) -> String:
	var t := Time.get_unix_time_from_datetime_string(date + "T12:00:00")
	return Time.get_date_string_from_unix_time(int(t) - 86400)

## Tageskarte festhalten: Ist für `date` schon eine gewählt, bleibt sie (auch wenn inzwischen mehr Level geschafft sind).
## `d` ist der Speicherstand-Eintrag "daily" und wird verändert. Rückgabe: Level-ID.
static func level_of_day(d: Dictionary, pool: Array, date: String) -> String:
	if String(d.get("date", "")) == date and pool.has(String(d.get("level", ""))):
		return String(d.level)
	d["date"] = date
	d["level"] = pick_level(pool, date)
	d["best"] = 0
	d["done"] = false
	d["medal"] = 0
	d["gold"] = false
	return String(d.level)

## Abgeschlossene Tagschicht werten. `d` = Eintrag "daily", `stats` = Statistik; beide werden verändert. `score` = Wertung des Tagesziels, `medal` = 0–3 (siehe DayShift).
## Tage in Folge zählen nur abgeschlossene Tagschichten; der beste Wert und die beste Medaille des Tages bleiben stehen, Gold zählt je Tag einmal.
static func record(d: Dictionary, stats: Dictionary, date: String, score: int, medal := 0) -> void:
	if String(d.get("date", "")) != date:
		d["date"] = date
		d["best"] = 0
		d["done"] = false
		d["medal"] = 0
		d["gold"] = false
	d["best"] = maxi(int(d.get("best", 0)), score)
	d["medal"] = maxi(int(d.get("medal", 0)), medal)
	if medal >= 3 and not bool(d.get("gold", false)):
		d["gold"] = true
		stats["day_golds"] = int(stats.get("day_golds", 0)) + 1
	stats["day_best_medal"] = maxi(int(stats.get("day_best_medal", 0)), medal)
	if bool(d.get("done", false)):
		return
	d["done"] = true
	var last := String(stats.get("daily_last", ""))
	stats["daily_streak"] = int(stats.get("daily_streak", 0)) + 1 if last == yesterday(date) else 1
	stats["daily_last"] = date
	stats["daily_days"] = int(stats.get("daily_days", 0)) + 1
	stats["daily_best_streak"] = maxi(int(stats.get("daily_best_streak", 0)), int(stats.daily_streak))

## Aktuelle Serie: Sie gilt, solange der letzte abgeschlossene Tagesflug heute oder gestern war.
static func current_streak(stats: Dictionary, date: String) -> int:
	var last := String(stats.get("daily_last", ""))
	return int(stats.get("daily_streak", 0)) if last == date or last == yesterday(date) else 0
