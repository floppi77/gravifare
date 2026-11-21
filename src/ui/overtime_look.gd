class_name OvertimeLook
extends RefCounted
## Sonderschicht, sichtbar am Taxi: Lizenz als Zierstreifen und Emblem, jedes eingebaute Teil als Anbau (Düsen, Platten, Stoßfänger, Kanister,
## Antenne …) oder – wenn es nichts Mechanisches ist (Kundschaft, Geld, Glück) – als Plakette in der Farbe seines Bereichs am unteren Rumpf.
## Gezeichnet in Taxi-Einheiten (26 × 16, wie das Taxi-Blatt); `rect` ist die Fläche des Taxi-Bilds im Zeichenraum.

const UNITS := Vector2(26.0, 16.0)
const STEEL := Color("#9aa3c7")
const STEEL_D := Color("#4e5573")
const INK := Color("#0c0f24")
const GOLD := Color("#ffd23a")
## Lizenzen: Farbe des Zierstreifens und Emblem
const LIC := {"standard": Color(0, 0, 0, 0), "saver": Color("#5dff9a"), "racer": Color("#ff4d4d"), "tank": Color("#9aa3c7"), "charmer": Color("#ff7ad9"), "gambler": Color("#b07cff")}
## Teile mit eigenem Anbau; alle anderen werden Plaketten.
const PARTS := ["turbo", "finesse", "brake", "quickgear", "greedy", "canister", "fastpump", "reserve", "armor", "bumper", "spikeguard", "heatshield", "ram",
	"selfrepair", "softgear", "skids", "velvet", "tiltguard", "seat", "angel", "scanner", "meter", "golden", "charm"]

static func _p(rect: Rect2, u: float, v: float) -> Vector2:
	return rect.position + Vector2(u, v) * rect.size / UNITS

static func _b(ci: CanvasItem, rect: Rect2, u: float, v: float, w: float, h: float, c: Color) -> void:
	var a := _p(rect, u, v)
	ci.draw_rect(Rect2(a, _p(rect, u + w, v + h) - a), c)

## Alles zeichnen. `gear` 0…1 (Fahrwerk), `t` Zeit für kleine Bewegungen, `motion` false bei „Weniger Bewegung“.
static func draw_on_taxi(ci: CanvasItem, rect: Rect2, perks: Dictionary, license: String, gear := 0.0, t := 0.0, motion := true) -> void:
	var lc: Color = LIC.get(license, Color(0, 0, 0, 0))
	if lc.a > 0.0:                                                   # Lizenz: Zierstreifen über dem Schachbrettband und Emblem am linken Flügel
		_b(ci, rect, 3.4, 7.55, 19.2, 0.45, lc)
		draw_emblem(ci, _p(rect, 5.3, 5.1), rect.size.x / UNITS.x * 1.05, license)
	var n := func(id: String) -> int: return int(perks.get(id, 0))
	# Antrieb
	for i in mini(n.call("turbo"), 3):
		var ux: float = [9.0, 15.8, 12.4][i]
		_b(ci, rect, ux, 15.0, 1.2, 1.1, STEEL_D)
		_b(ci, rect, ux + 0.2, 15.8, 0.8, 0.4, Color("#ff9a3a"))
	for i in mini(n.call("finesse"), 3):
		var h := 2.0 + i
		_b(ci, rect, -0.7, 7.5 - h * 0.5, 0.6, h, Color("#35c8e0"))
		_b(ci, rect, 26.1, 7.5 - h * 0.5, 0.6, h, Color("#35c8e0"))
	if n.call("brake") > 0:
		_b(ci, rect, 5.6, 2.5, 1.0, 0.7, STEEL_D)
		_b(ci, rect, 19.4, 2.5, 1.0, 0.7, STEEL_D)
		_b(ci, rect, 5.8, 2.3, 0.6, 0.25, Color("#6aa0ff"))
		_b(ci, rect, 19.6, 2.3, 0.6, 0.25, Color("#6aa0ff"))
	if n.call("quickgear") > 0:
		for ux in [8.7, 17.0]:
			for k in 3:
				_b(ci, rect, ux, 12.8 + k * 0.9, 0.35, 0.45, Color("#ffcb3d"))
	if n.call("greedy") > 0:
		_b(ci, rect, 11.8, 15.9, 2.4, 1.2, INK)
		_b(ci, rect, 12.1, 16.6, 1.8, 0.5, Color("#ff5a3a"))
	# Sprit
	for i in mini(n.call("canister"), 2):
		var ux: float = [3.8, 19.0][i]
		_b(ci, rect, ux, 11.7, 3.2, 1.2, Color("#6b7a2a"))
		_b(ci, rect, ux, 11.7, 3.2, 0.3, Color("#9bb03c"))
		_b(ci, rect, ux + 2.6, 11.5, 0.5, 0.3, STEEL)
	if n.call("fastpump") > 0:
		_b(ci, rect, 20.2, 3.2, 1.2, 0.7, STEEL)
		_b(ci, rect, 20.5, 3.35, 0.6, 0.4, Color("#ffa530"))
	if n.call("reserve") > 0:
		_b(ci, rect, 16.6, 12.3, 1.6, 0.9, Color("#c8323c"))
		_b(ci, rect, 16.9, 12.45, 1.0, 0.25, Color("#ff9aa8"))
	# Hülle
	for i in mini(n.call("armor"), 3):
		_b(ci, rect, 3.4 + i * 1.95, 3.3, 1.7, 0.75, STEEL)
		_b(ci, rect, 20.9 - i * 1.95, 3.3, 1.7, 0.75, STEEL)
		_b(ci, rect, 3.4 + i * 1.95, 3.3, 1.7, 0.2, Color.WHITE.darkened(0.1))
		_b(ci, rect, 20.9 - i * 1.95, 3.3, 1.7, 0.2, Color.WHITE.darkened(0.1))
	if n.call("bumper") > 0:
		var bw := 0.6 + 0.35 * float(n.call("bumper"))
		_b(ci, rect, -bw + 0.1, 8.9, bw, 2.3, Color("#2a2d3e"))
		_b(ci, rect, 25.9, 8.9, bw, 2.3, Color("#2a2d3e"))
	if n.call("ram") > 0:
		_b(ci, rect, -1.5, 7.3, 0.5, 4.4, STEEL)
		_b(ci, rect, 27.0, 7.3, 0.5, 4.4, STEEL)
		_b(ci, rect, -1.2, 8.2, 0.4, 0.4, INK)
		_b(ci, rect, 26.8, 8.2, 0.4, 0.4, INK)
	if n.call("spikeguard") > 0:
		for k in 4:
			_b(ci, rect, 0.2 + k * 0.55, 11.3 + (k % 2) * 0.3, 0.4, 0.5, STEEL)
			_b(ci, rect, 23.8 + k * 0.55, 11.3 + (k % 2) * 0.3, 0.4, 0.5, STEEL)
	if n.call("heatshield") > 0:
		for k in 5:
			_b(ci, rect, 3.6 + k * 0.95, 11.75, 0.8, 0.45, Color("#ff7a3a") if k % 2 == 0 else Color("#b83a1e"))
			_b(ci, rect, 18.2 + k * 0.95, 11.75, 0.8, 0.45, Color("#ff7a3a") if k % 2 == 1 else Color("#b83a1e"))
	if n.call("selfrepair") > 0:
		var on := not motion or int(t * 2.0) % 2 == 0
		_b(ci, rect, 17.4, 5.7, 0.8, 0.8, Color("#5dff9a") if on else Color("#2a7a4a"))
	# Landung (am Fahrwerk, nur wenn es draußen ist)
	if n.call("tiltguard") > 0:
		_b(ci, rect, 0.5, 2.6, 1.3, 1.5, Color("#7dff9a").darkened(0.3))
		_b(ci, rect, 24.2, 2.6, 1.3, 1.5, Color("#7dff9a").darkened(0.3))
	if gear > 0.3:
		var fy := 16.0 + 0.8 * gear
		var pad := Color("#c9cfee")
		var pw := 1.6 + 0.6 * float(n.call("softgear"))
		if n.call("velvet") > 0:
			pad = Color("#c77dff")
		if n.call("softgear") > 0 or n.call("velvet") > 0:
			_b(ci, rect, 6.4 - pw * 0.5, fy, pw, 0.5, pad)
			_b(ci, rect, 19.6 - pw * 0.5, fy, pw, 0.5, pad)
		if n.call("skids") > 0:
			_b(ci, rect, 4.8, fy + 0.45, 16.4, 0.35, STEEL)
	# Fahrgäste und Lauf
	if n.call("seat") > 0:
		_b(ci, rect, 9.4, 0.9, 0.9, 0.9, INK)
		_b(ci, rect, 9.55, 1.05, 0.6, 0.6, Color("#ffcb3d"))
	if n.call("meter") > 0:
		_b(ci, rect, 11.2, -1.3, 3.6, 1.2, INK)
		_b(ci, rect, 11.4, -1.15, 3.2, 0.9, Color("#ffe14a"))
		_b(ci, rect, 12.0, -0.85, 2.0, 0.3, INK)
	if n.call("angel") > 0:
		var bob := sin(t * 2.2) * 0.25 if motion else 0.0
		var c := _p(rect, 13.0, -2.6 + bob)
		var r := rect.size.x / UNITS.x * 2.1
		ci.draw_arc(c, r, 0.0, TAU, 20, Color(GOLD, 0.95), maxf(0.6, r * 0.22))
	if n.call("scanner") > 0:
		var base := _p(rect, 21.5, 3.2)
		var top := _p(rect, 21.5, 0.4)
		ci.draw_line(base, top, STEEL, maxf(0.5, rect.size.x / UNITS.x * 0.3))
		_b(ci, rect, 20.7, -0.2, 1.6, 0.6, STEEL)
		if not motion or int(t * 3.0) % 2 == 0:
			_b(ci, rect, 21.3, -0.6, 0.4, 0.4, Color("#ff4d6d"))
	if n.call("charm") > 0:
		_b(ci, rect, 10.7, 1.6, 0.25, 1.2, Color("#c9cfee"))
		_b(ci, rect, 10.4, 2.7, 0.9, 0.9, Color("#5dff9a"))
	if n.call("golden") > 0:
		_b(ci, rect, 3.2, 10.05, 19.6, 0.35, GOLD)
	# Plaketten für alles ohne eigenen Anbau
	var chips: Array = []
	for id in perks:
		if not PARTS.has(String(id)) and int(perks[id]) > 0 and String(id) != "spare":
			chips.append(String(id))
	chips.sort_custom(func(a, b): return _order(a) < _order(b))
	for i in mini(chips.size(), 13):
		var p := Overtime.perk(String(chips[i]))
		var cc: Color = OvertimeIcon.CAT_COLOR.get(String(p.get("cat", "run")), Color.WHITE)
		var rc: Color = OvertimeIcon.RAR_COLOR.get(String(p.get("rar", "c")), Color.WHITE)
		var ux := 4.0 + float(i) * 1.42
		_b(ci, rect, ux, 10.55, 1.15, 1.0, rc)
		_b(ci, rect, ux + 0.15, 10.7, 0.85, 0.7, cc)

static func _order(id: String) -> String:
	var cats := ["jets", "fuel", "hull", "land", "guest", "life", "run", "legend"]
	return "%02d%s" % [cats.find(String(Overtime.perk(id).get("cat", "run"))), id]

## Emblem einer Lizenz (Schild mit Zeichen), `c` Mitte, `u` Größe einer Einheit.
static func draw_emblem(ci: CanvasItem, c: Vector2, u: float, license: String) -> void:
	var col: Color = LIC.get(license, Color("#7f8fe0"))
	if col.a <= 0.0:
		col = Color("#7f8fe0")
	var w := u * 1.0
	var pts := PackedVector2Array([c + Vector2(-w, -w), c + Vector2(w, -w), c + Vector2(w, w * 0.3), c + Vector2(0, w * 1.15), c + Vector2(-w, w * 0.3)])
	ci.draw_colored_polygon(pts, INK)
	var inner := PackedVector2Array()
	for p in pts:
		inner.append(c + (p - c) * 0.78)
	ci.draw_colored_polygon(inner, col.darkened(0.25))
	var s := u * 0.35
	var g := Color.WHITE
	match license:
		"saver":                                  # Blatt
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -s * 1.3), c + Vector2(s, 0), c + Vector2(0, s * 1.3), c + Vector2(-s, 0)]), g)
		"racer":                                  # Blitz
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(s * 0.4, -s * 1.4), c + Vector2(-s * 0.7, s * 0.2), c + Vector2(0, s * 0.2), c + Vector2(-s * 0.4, s * 1.4), c + Vector2(s * 0.7, -s * 0.2), c + Vector2(0, -s * 0.2)]), g)
		"tank":                                   # Platte mit Nieten
			ci.draw_rect(Rect2(c - Vector2(s, s), Vector2(s, s) * 2.0), g)
			for d in [Vector2(-0.6, -0.6), Vector2(0.6, -0.6), Vector2(-0.6, 0.6), Vector2(0.6, 0.6)]:
				ci.draw_rect(Rect2(c + d * s - Vector2(0.15, 0.15) * s, Vector2(0.3, 0.3) * s), col.darkened(0.5))
		"charmer":                                # Herz
			ci.draw_circle(c + Vector2(-s * 0.5, -s * 0.3), s * 0.55, g)
			ci.draw_circle(c + Vector2(s * 0.5, -s * 0.3), s * 0.55, g)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-s * 1.0, -s * 0.15), c + Vector2(s * 1.0, -s * 0.15), c + Vector2(0, s * 1.2)]), g)
		"gambler":                                # Würfel
			ci.draw_rect(Rect2(c - Vector2(s, s), Vector2(s, s) * 2.0), g)
			for d in [Vector2(-0.5, -0.5), Vector2(0, 0), Vector2(0.5, 0.5)]:
				ci.draw_rect(Rect2(c + d * s - Vector2(0.18, 0.18) * s, Vector2(0.36, 0.36) * s), INK)
		_:                                        # Standard: Taxi-Stern
			var star := PackedVector2Array()
			for i in 10:
				var ang := -PI * 0.5 + PI * float(i) / 5.0
				star.append(c + Vector2(cos(ang), sin(ang)) * (s * 1.2 if i % 2 == 0 else s * 0.5))
			ci.draw_colored_polygon(star, g)

## Taxi mit Lizenz und Ausstattung für Menüs (Lackierung des Spielstands).
class Preview extends Control:
	var perks: Dictionary = {}
	var license := "standard"
	var tex: Texture2D = Cosmetics.paint_texture()
	var t := 0.0
	func _process(d: float) -> void:
		t += d
		queue_redraw()
	func _draw() -> void:
		if tex == null:
			return
		var k := floorf(minf(size.x / 78.0, size.y / 48.0) * 3.0) / 3.0
		k = maxf(k, 1.0 / 3.0)
		var sz := Vector2(78, 48) * k
		var r := Rect2(((size - sz) * 0.5).floor(), sz)
		draw_texture_rect(tex, r, false)
		OvertimeLook.draw_on_taxi(self, r, perks, license, 0.0, t, not Settings.values.reduce_motion)
