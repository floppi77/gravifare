extends Node
## Autoload "Cosmetics": Lackierungen und Aufkleber (nur Optik, kein Einfluss auf das Spiel), Freischaltungen
## über Spielstatistiken (data/cosmetics.json). „Standardtaxi erzwingen“ = Challenge-Look.

const STAT_NAMES := ["levels_done", "perfect_landings", "deliveries", "best_streak", "crashes", "pump_explosions", "stars_time", "stars_clean", "stars_pro", "stars_all", "daily_best_streak", "day_golds"]
## Stern-Freischaltungen: „bei allen Leveln“ den 1. (Zeit), 2. (Sauber), 3. (Meister) oder alle drei Sterne (Mindestwert 0 = alle Level)
const STAR_STATS := {"stars_time": "time", "stars_clean": "clean", "stars_pro": "pro"}
var items: Array = []
var _tex_cache := {}

# Mischform (Runde 83, Standard): das gezeichnete 2D-Taxi auf einem Relief in Blender mit Licht und Drehstufen (tools/art/taxi3d/make_hybrid.py),
# je Lackierung ein Blatt. Gilt für das Taxi im Level; Garage, Menüs und Leben-Symbole zeigen weiter das 2D-Bild (feste Vorderansicht).
# Zum Vergleich im Debug-Modus: Debug-Menü oder F6 im Level zeigen das bisherige 2D-Taxi; Dev: --taxi2d.
const TAXI3D_SHEET := "res://assets/art/taxi_hybrid/%s.png"
const TAXI3D_FRAMES := 7               # Drehstufen −12° … +12° um die Hochachse
var taxi_3d := true

func _ready() -> void:
	taxi_3d = not OS.get_cmdline_user_args().has("--taxi2d")
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

func select(kind: String, id: String) -> void:
	var c: Dictionary = Save.data.get("cosmetics", {})
	c[kind] = id
	Save.data["cosmetics"] = c
	Save.write()

func paint_texture(id := "") -> Texture2D:
	if id == "":
		id = selected("paint")
	return _tex("res://assets/art/taxi_%s.png" % id)

## Leben-Symbol im HUD in der Farbe der Lackierung (life_<id>.png, abgeleitet in tools/art/gen_art.py).
func life_texture(id := "") -> Texture2D:
	if id == "":
		id = selected("paint")
	var t := _tex("res://assets/art/life_%s.png" % id)
	return t if t != null else _tex("res://assets/art/life_icon.png")

## Leben-Symbol je Pixelgröße (Runde 72): das neue Taxi auf 10 × 6 Einheiten, 10 Lackierungen nebeneinander, die Größen 2–6 untereinander
## (life_sizes.png, tools/art/gen_life_icons_sizes.py). Ausschnitt in Bildpunkten: {tex, src}; fehlt das Blatt, das alte 32 × 20-Symbol.
const LIFE_SKINS := ["std", "neon", "mint", "night", "sunset", "candy", "gold", "sky", "platinum", "wasp"]
const LIFE_UNITS := Vector2(100, 6)
const LIFE_ICON := Vector2(10, 6)

func life_frame(n: int, id := "") -> Dictionary:
	if id == "":
		id = selected("paint")
	var sheet := _tex("res://assets/art/life_sizes.png")
	var idx := LIFE_SKINS.find(id)
	if sheet == null:
		var t := life_texture(id)
		return {"tex": t, "src": Rect2(Vector2.ZERO, t.get_size())}
	var r := PixelScale.sheet_rect(clampi(n, 2, 6), LIFE_UNITS)
	var nn := clampi(n, 2, 6)
	return {"tex": sheet, "src": Rect2(r.position + Vector2(float(maxi(idx, 0)) * LIFE_ICON.x * float(nn), 0.0), LIFE_ICON * float(nn))}

func sticker_texture(id := "") -> Texture2D:
	if id == "":
		id = selected("sticker")
	if id == "none":
		return null
	return _tex("res://assets/art/sticker_%s.png" % id)

## Aufkleber in Taxigröße (20 px, 1:1 am Taxi im Spiel und in der Werkstatt; sticker_<id>_s.png aus tools/art/gen_art.py).
func sticker_small_texture(id := "") -> Texture2D:
	if id == "":
		id = selected("sticker")
	if id == "none":
		return null
	var p := "res://assets/art/sticker_%s_s.png" % id
	return _tex(p) if ResourceLoader.exists(p) else _tex("res://assets/art/sticker_%s.png" % id)

# ------------------------------------------------------------------ Taxi in der Pixelgröße des Bildschirms (Runde 71)
## Die Größenwahl liegt in PixelScale (src/core/pixel_scale.gd); hier nur die Blätter des Taxis und der Aufkleber: Das Taxi und sein Aufkleber
## liegen für jede Größe eigens gerastert vor (taxi_sizes/<lack>.png, sticker_<id>_sizes.png; tools/art/gen_taxi.py, gen_art.py),
## damit sie im Level immer 1:1 erscheinen statt ungleichmäßig gestreckt.
const TAXI_SIZES := PixelScale.SIZES
const TAXI_UNITS := Vector2(26, 16)
const STICKER_BASE := 20            # Aufkleber bei 3 Punkten je Einheit

## Bildschirmpunkte je Welteinheit, mit denen `node` gerade gezeichnet wird (Fensterskalierung × Kamerazoom).
func pixel_scale(node: CanvasItem) -> float:
	return PixelScale.of(node)

static func pick_size(scale: float) -> int:
	return PixelScale.pick(scale)

static func _sheet_y(n: int, unit: Callable) -> int:
	return PixelScale.sheet_y(n, unit)

## Ausschnitt des Taxis in der Größe `n`: {tex, src (Bildpunkte im Blatt), n}. Fehlt das Blatt, das 78×48-Bild.
func taxi_frame(n: int, id := "") -> Dictionary:
	if id == "":
		id = selected("paint")
	if not TAXI_SIZES.has(n):
		n = 3
	var sheet := _tex("res://assets/art/taxi_sizes/%s.png" % id)
	if sheet == null:
		var t := paint_texture(id)
		return {"tex": t, "src": Rect2(Vector2.ZERO, t.get_size()), "n": 3}
	return {"tex": sheet, "src": PixelScale.sheet_rect(n, TAXI_UNITS), "n": n}

## Mischform: Ausschnitt der Drehstufe `k` (0 … TAXI3D_FRAMES−1, Mitte = geradeaus) in der Größe `n` für die Lackierung `id`; {} ohne Blatt.
func taxi3d_frame(n: int, k: int, id := "") -> Dictionary:
	if id == "":
		id = selected("paint")
	if not TAXI_SIZES.has(n):
		n = 3
	var p := TAXI3D_SHEET % id
	if not ResourceLoader.exists(p):
		return {}
	var sheet := _tex(p)
	if sheet == null:
		return {}
	var r := PixelScale.sheet_rect(n, TAXI_UNITS)
	return {"tex": sheet, "src": Rect2(r.position + Vector2(float(clampi(k, 0, TAXI3D_FRAMES - 1)) * TAXI_UNITS.x * 6.0, 0.0), r.size), "n": n}

static func sticker_px(n: int) -> int:
	return roundi(STICKER_BASE * n / 3.0)

## Ausschnitt des Aufklebers in der Größe `n` ({} ohne Aufkleber): {tex, src, n}.
func sticker_frame(n: int, id := "") -> Dictionary:
	if id == "":
		id = selected("sticker")
	if id == "none":
		return {}
	if not TAXI_SIZES.has(n):
		n = 3
	var sheet := _tex("res://assets/art/sticker_%s_sizes.png" % id)
	if sheet == null:
		var t := sticker_small_texture(id)
		return {} if t == null else {"tex": t, "src": Rect2(Vector2.ZERO, t.get_size()), "n": 3}
	var px := sticker_px(n)
	return {"tex": sheet, "src": Rect2(0, _sheet_y(n, func(k): return sticker_px(k)), px, px), "n": n}

func _tex(path: String) -> Texture2D:
	if not _tex_cache.has(path):
		_tex_cache[path] = load(path) if ResourceLoader.exists(path) else null
	return _tex_cache[path]
