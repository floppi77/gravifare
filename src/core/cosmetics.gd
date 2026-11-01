extends Node
## Autoload "Cosmetics": Lackierungen und Aufkleber (nur Optik, kein Einfluss auf das Spiel), Freischaltungen
## über Spielstatistiken (data/cosmetics.json). „Standardtaxi erzwingen“ = Challenge-Look.

const STAT_NAMES := ["levels_done", "perfect_landings", "deliveries", "best_streak", "crashes", "pump_explosions", "stars_time", "stars_clean", "stars_pro", "stars_all"]
## Stern-Freischaltungen: „bei allen Leveln“ den 1. (Zeit), 2. (Sauber), 3. (Meister) oder alle drei Sterne (Mindestwert 0 = alle Level)
const STAR_STATS := {"stars_time": "time", "stars_clean": "clean", "stars_pro": "pro"}
var items: Array = []
var _tex_cache := {}

func _ready() -> void:
	var f := FileAccess.open("res://data/cosmetics.json", FileAccess.READ)
	var d = JSON.parse_string(f.get_as_text()) if f != null else null
	if typeof(d) == TYPE_DICTIONARY:
		items = d.get("items", [])

func item(id: String) -> Dictionary:
	for it in items:
		if it.id == id:
			return it
	return {}

func total_levels() -> int:
	var n := 0
	var dir := DirAccess.open("res://data/levels")
	if dir != null:
		for f in dir.get_files():
			if f.ends_with(".json"):
				n += 1
	return n

func stat_value(stat: String) -> int:
	if stat == "levels_done":
		return Save.data.completed.size()
	if stat == "stars_all" or STAR_STATS.has(stat):
		var n := 0
		for id in Save.data.completed:
			var m: Dictionary = Save.data.completed[id].get("medals", {})
			if stat == "stars_all":
				n += 1 if (m.get("time", false) and m.get("clean", false) and m.get("pro", false)) else 0
			else:
				n += 1 if m.get(STAR_STATS[stat], false) else 0
		return n
	return int(Save.data.stats.get(stat, 0))

## Benötigter Wert: bei Stern-Freischaltungen alle Level des Spiels, sonst der Wert aus den Daten.
func required(it: Dictionary) -> int:
	var st := String(it.unlock.stat)
	return total_levels() if (st == "stars_all" or STAR_STATS.has(st)) else int(it.unlock.min)

func is_unlocked(id: String) -> bool:
	var it := item(id)
	if it.is_empty():
		return false
	if it.unlock == null:
		return true
	return Save.data.get("unlocked", []).has(id)

func requirement_text(it: Dictionary) -> String:
	if it.unlock == null:
		return ""
	var need := required(it)
	return tr("COSM_REQ_" + String(it.unlock.stat).to_upper()) % need + "  (%d / %d)" % [mini(stat_value(it.unlock.stat), need), need]

## Prüft alle Bedingungen und schaltet neue Items frei; Rückgabe: Liste der neu freigeschalteten Items.
func check_unlocks() -> Array:
	var fresh: Array = []
	var unlocked: Array = Save.data.get("unlocked", [])
	for it in items:
		if it.unlock != null and not unlocked.has(it.id) and stat_value(it.unlock.stat) >= required(it):
			unlocked.append(it.id)
			fresh.append(it)
	if not fresh.is_empty():
		Save.data["unlocked"] = unlocked
		Save.write()
	return fresh

func selected(kind: String) -> String:
	var c: Dictionary = Save.data.get("cosmetics", {})
	var id: String = c.get(kind, "std" if kind == "paint" else "none")
	return id if is_unlocked(id) else ("std" if kind == "paint" else "none")

func challenge() -> bool:
	return bool(Save.data.get("cosmetics", {}).get("challenge", false))

func select(kind: String, id: String) -> void:
	var c: Dictionary = Save.data.get("cosmetics", {})
	c[kind] = id
	Save.data["cosmetics"] = c
	Save.write()

func set_challenge(on: bool) -> void:
	var c: Dictionary = Save.data.get("cosmetics", {})
	c["challenge"] = on
	Save.data["cosmetics"] = c
	Save.write()

func paint_texture(id := "") -> Texture2D:
	if id == "":
		id = "std" if challenge() else selected("paint")
	return _tex("res://assets/art/taxi_%s.png" % id)

func sticker_texture(id := "") -> Texture2D:
	if id == "":
		id = "none" if challenge() else selected("sticker")
	if id == "none":
		return null
	return _tex("res://assets/art/sticker_%s.png" % id)

func _tex(path: String) -> Texture2D:
	if not _tex_cache.has(path):
		_tex_cache[path] = load(path) if ResourceLoader.exists(path) else null
	return _tex_cache[path]
