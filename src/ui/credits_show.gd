extends Control
## Credits als Szene (Runde 84): Ein Taxi schleppt ein Werbebanner mit der Kategorie über den Himmel, unten auf der Haltestellen-Plattform
## kommen Fahrgäste aus den Häuschen und halten die Einträge hoch: ein kurzer Eintrag auf einem Schild an der Stange, ein langer als Spruchband
## zwischen zwei Fahrgästen. Jeder Durchflug kommt aus einer anderen Richtung und hat eine andere Lackierung. Zum Schluss winken alle.
## A/Enter beschleunigt, B/Esc beendet (credits.gd). Gezeichnet im Bühnenmaß (640 × 360 Einheiten, breiter bei Ultrawide), auf ganzen Bildpunkten.

const PASS_TEX := preload("res://assets/art/passengers_sizes.png")       # Fahrgastblatt je Pixelgröße 2–6 (wie props_view)
const SHELTER_TEX := preload("res://assets/art/shelters_sizes.png")
const PASS_UNITS := Vector2(70, 140)
const PASS_IMG := Vector2(7, 10)
const SHELTER_UNITS := Vector2(180, 17)
const SHELTER_IMG := Vector2(20, 17)
const LOOKS := 14
const LOGO_W := 210.0

const SIGN_FS := 10                  # Schrift der Schilder und Spruchbänder (Fonts.hud, mal Faktor der großen Schrift)
const CAT_FS := 11                   # Schrift des Werbebanners
const HAND_X := 2.75                 # Faust der erhobenen Hand (Bild 3 des Blatts) neben der Figurenmitte, ungespiegelt rechts
const HAND_Y := 8.0                  # … über den Füßen
const WALK_V := 38.0                 # Gehtempo (Einheiten/s), beim Hinlaufen notfalls schneller, damit alle rechtzeitig stehen
const DECK_H := 30.0                 # Plattform am unteren Rand: Oberkante so weit über dem Bildrand
const PLACARD_MAX := 66.0            # bis zu dieser Textbreite ein Schild an einer Stange (ein Fahrgast), sonst ein Spruchband (zwei)
const ROW_UP := 21.0                 # hintere Reihe: Spruchband so viel höher (längere Stangen)
const ROPE := 18.0                   # Schleppseil zwischen Taxi und Banner
const T_WALK := 2.2                  # je Durchflug: Hinlaufen …
const T_RAISE := 0.4                 # … Hochhalten …
const T_LOWER := 0.35                # … Absenken
const FIRST := 3.4                   # erster Durchflug (davor Logo)

const INK := Color("#0c0f24")
const CLOTH := Color("#f6f2df")
const CLOTH_DARK := Color("#d8d0b2")
const TEXT_COL := Color("#1a1f4a")
const BANNER_EDGE := Color("#e5202e")
const POLE := Color("#8a6a48")
const FIRE := [Color("#e8452c"), Color("#ff8a2e"), Color("#ffd04a"), Color("#fff6c8")]
const ICE := [Color("#2a6ab8"), Color("#4fb8e8"), Color("#e8fbff")]

var lines: Array = []
var lang := "de"
var owner_scene: Node
var logo: Texture2D = load("res://assets/art/logo.png") if ResourceLoader.exists("res://assets/art/logo.png") else null
var tt := 0.0                        # Szenenzeit (beschleunigt mit A/Enter)
var plan := {}
var still := false                   # „Weniger Bewegung“: kein Flattern, kein Wippen
var _built_for := Vector2.ZERO
var _trail_pass := -1
var _trail := PackedVector2Array()   # bisherige Taxipositionen des laufenden Durchflugs (älteste zuerst)
var _puffs: Array = []               # Abgaswölkchen [Position, Alter]
var _puff_t := -1.0
var _left := false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	still = Settings.values.reduce_motion
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--credits-t="):           # Dev: an diese Stelle springen (Bilder einzelner Durchflüge)
			tt = float(a.substr(12))

# ---------------------------------------------------------------- Plan (rein rechnerisch, für die Tests ohne Bild)

static func text_of(v, lg: String) -> String:
	return v if typeof(v) == TYPE_STRING else String(v.get(lg, v.get("en", "")))

## Zeilen aus credits.json in Titel, Untertitel, Kategorien (mit Einträgen) und Schlusszeile ordnen.
static func sections(src: Array, lg: String) -> Dictionary:
	var out := {"title": "", "sub": "", "outro": "", "cats": []}
	for l in src:
		var kind := String(l[0])
		var txt := text_of(l[1], lg)
		match kind:
			"title":
				out.title = txt
			"sub":
				if out.cats.is_empty():
					out.sub = txt
				else:
					out.outro = txt
			"head":
				out.cats.append({"cat": txt, "items": []})
			_:
				if not out.cats.is_empty():
					out.cats[-1].items.append(txt)
	return out

## Zu breiten Text an dem Leerzeichen umbrechen, das der Mitte am nächsten liegt.
static func wrap2(txt: String, font: Font, fs: int, max_w: float) -> Array:
	if font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x <= max_w:
		return [txt]
	var best := -1
	for i in txt.length():
		if txt[i] == " " and (best < 0 or absi(i - txt.length() / 2) < absi(best - txt.length() / 2)):
			best = i
	if best < 0:
		return [txt]
	return [txt.substr(0, best).strip_edges(), txt.substr(best + 1).strip_edges()]

## Schild bzw. Spruchband eines Eintrags: Zeilen, Textbreite, Art, Breite der Fläche und Platzbedarf am Boden (mit den Haltern).
static func make_sign(txt: String, font: Font, fs: int, max_w: float) -> Dictionary:
	var rows := wrap2(txt, font, fs, max_w)
	var w := 0.0
	for r in rows:
		w = maxf(w, font.get_string_size(r, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x)
	var placard := rows.size() == 1 and w <= PLACARD_MAX
	var sw := ceilf(w) + (8.0 if placard else 12.0)
	var foot := maxf(sw, PASS_IMG.x) if placard else sw + 2.0 * HAND_X + PASS_IMG.x
	return {"text": txt, "rows": rows, "w": w, "kind": "placard" if placard else "banner", "sw": sw, "foot": foot, "h": float(fs) * float(rows.size()) + 4.0}

## Ganzer Ablauf für eine Bühne der Breite `width` und Höhe `height`: Durchflüge mit Schildern (Reihe, Mitte), Route, Lackierung, Zeiten.
static func build(src: Array, lg: String, width: float, height: float, font: Font, sign_fs: int, cat_fs: int, paints: Array) -> Dictionary:
	var sec := sections(src, lg)
	var avail := width - 40.0
	var max_w := minf(avail - 30.0, 380.0)
	var passes: Array = []
	for c in sec.cats:
		var page: Array = [[], []]               # vordere und hintere Reihe
		var used := [0.0, 0.0]
		for it in c.items:
			var sg := make_sign(String(it), font, sign_fs, max_w)
			var placed := false
			for row in 2:
				var need: float = sg.foot + (16.0 if not page[row].is_empty() else 0.0)
				if used[row] + need <= avail:
					page[row].append(sg)
					used[row] += need
					placed = true
					break
			if not placed:
				passes.append(_pass(c.cat, page, used, width))
				page = [[sg], []]
				used = [sg.foot, 0.0]
		passes.append(_pass(c.cat, page, used, width))
	passes.append({"cat": sec.outro, "signs": [], "outro": true, "chars": 0})
	# Zeiten, Lackierung, Route
	var rng := RandomNumberGenerator.new()
	rng.seed = 8484
	var pool := paints.duplicate()
	var last_paint := ""
	var start := FIRST
	var from_left := true
	var kinds := ["level", "dive", "climb", "level", "wave", "dive", "climb"]
	for i in passes.size():
		var p: Dictionary = passes[i]
		var read := clampf(2.2 + 0.05 * float(p.chars), 3.4, 8.0)
		if p.get("outro", false):
			read = 6.0
		p["read"] = read
		p["start"] = start
		p["dur"] = read + T_WALK + T_RAISE + T_LOWER + 0.9
		p["taxi_in"] = start + 1.0
		p["taxi_t"] = read + 3.2
		if pool.is_empty():
			pool = paints.duplicate()
		var pick := rng.randi() % pool.size()
		if String(pool[pick]) == last_paint and pool.size() > 1:
			pick = (pick + 1) % pool.size()
		p["paint"] = String(pool[pick])
		last_paint = p.paint
		pool.remove_at(pick)
		p["dir"] = 1.0 if from_left else -1.0
		p["route"] = route(String(kinds[i % kinds.size()]) if not p.get("outro", false) else "level", from_left, width, height, rng)
		p["kind"] = String(kinds[i % kinds.size()]) if not p.get("outro", false) else "level"
		from_left = not from_left
		start += p.dur
	return {"title": sec.title, "sub": sec.sub, "passes": passes, "end": start + 2.5}

static func _pass(cat: String, page: Array, used: Array, width: float) -> Dictionary:
	var signs: Array = []
	var chars := 0
	for row in 2:
		var x := (width - float(used[row])) * 0.5
		for sg in page[row]:
			var s: Dictionary = sg.duplicate()
			s["row"] = row
			s["cx"] = x + float(sg.foot) * 0.5
			x += float(sg.foot) + 16.0
			signs.append(s)
			chars += String(sg.text).length()
	return {"cat": cat, "signs": signs, "chars": chars}

## Flugbahn als kubische Bézierkurve von außerhalb des Bilds nach außerhalb; die Mitte bleibt flach (das Banner ist dort zu lesen).
## Arten: geradeaus, von oben herabstoßen, hinaus steigen, leichte Welle. Steigung höchstens etwa 30°, x läuft immer in Flugrichtung.
static func route(kind: String, from_left: bool, width: float, height: float, rng: RandomNumberGenerator) -> Array:
	var top := 46.0
	var low := height - DECK_H - 120.0
	var y := rng.randf_range(top, maxf(top, low))
	var pts: Array
	match kind:
		"dive":
			pts = [Vector2(-80.0, y - 70.0), Vector2(width * 0.22, y + 8.0), Vector2(width * 0.62, y), Vector2(width + 80.0, y - 18.0)]
		"climb":
			pts = [Vector2(-80.0, y + 24.0), Vector2(width * 0.38, y), Vector2(width * 0.72, y - 4.0), Vector2(width + 80.0, y - 80.0)]
		"wave":
			pts = [Vector2(-80.0, y + 20.0), Vector2(width * 0.3, y - 34.0), Vector2(width * 0.7, y + 34.0), Vector2(width + 80.0, y - 20.0)]
		_:
			pts = [Vector2(-80.0, y), Vector2(width * 0.33, y + 6.0), Vector2(width * 0.66, y - 6.0), Vector2(width + 80.0, y)]
	if not from_left:
		for i in pts.size():
			pts[i] = Vector2(width - pts[i].x, pts[i].y)
	return pts

static func bezier(p: Array, u: float) -> Vector2:
	var v := 1.0 - u
	return p[0] * v * v * v + p[1] * 3.0 * v * v * u + p[2] * 3.0 * v * u * u + p[3] * u * u * u

# ---------------------------------------------------------------- Ablauf

func _process(delta: float) -> void:
	var fast := Input.is_action_pressed("ui_accept") or Input.is_action_pressed("gear")
	var dt := delta * (3.0 if fast else 1.0)
	if size.x > 0.0 and size != _built_for:
		_built_for = size
		plan = build(lines, lang, size.x, size.y, Fonts.hud, Settings.fs(SIGN_FS), Settings.fs(CAT_FS), Cosmetics.LIFE_SKINS)
	tt += dt
	_step_puffs(dt)
	queue_redraw()
	if not plan.is_empty() and tt > float(plan.end) + 1.0 and not _left:
		_left = true
		Flow.to_menu()

func _deck_y() -> float:
	return size.y - DECK_H

func _shelters() -> Array:
	var k := clampi(int(size.x / 150.0), 3, 7)
	var out: Array = []
	for i in k:
		out.append(snappedf((float(i) + 0.5) * size.x / float(k), 1.0))
	return out

# ---------------------------------------------------------------- Zeichnen

func _draw() -> void:
	if plan.is_empty():
		return
	var passes: Array = plan.passes
	for i in passes.size():                  # Taxi und Banner hinter der Plattform am Himmel
		_draw_flight(i, passes[i])
	_draw_deck()
	for row in [1, 0]:                       # hintere Reihe zuerst (wird vom vorderen Spruchband überdeckt)
		for i in passes.size():
			_draw_signs(passes[i], row, i)
	for i in passes.size():
		if passes[i].get("outro", false):
			_draw_wavers(passes[i])
	_draw_intro()
	var fade := clampf((tt - float(plan.end)) / 1.0, 0.0, 1.0)
	if fade > 0.0:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.01, 0.015, 0.05, fade))

func _draw_intro() -> void:
	var a := clampf(minf(tt / 0.9, (FIRST + 1.2 - tt) / 1.0), 0.0, 1.0)
	if a <= 0.0:
		return
	var y := 30.0 + (0.0 if still else sin(tt * 1.3) * 1.5)
	if logo != null:
		var lh := LOGO_W * float(logo.get_height()) / float(logo.get_width())
		var r := Rect2(PixelDraw.snap2_to(self, Vector2((size.x - LOGO_W) * 0.5, y)), Vector2(LOGO_W, lh))
		draw_texture_rect(logo, Rect2(r.position + Vector2(2, 3), r.size), false, Color(0, 0, 0, 0.45 * a))
		draw_texture_rect(logo, r, false, Color(1, 1, 1, a))
		y += lh + 6.0
	elif String(plan.title) != "":
		draw_string(Fonts.title, Vector2(0, y + 44.0), String(plan.title), HORIZONTAL_ALIGNMENT_CENTER, size.x, 56, Color(1.0, 0.88, 0.29, a))
		y += 56.0
	var col := Color("#a9b8ff")
	col.a = a
	draw_string_outline(Fonts.ui, Vector2(0, y + 12.0), String(plan.sub), HORIZONTAL_ALIGNMENT_CENTER, size.x, Settings.fs(12), 4, Color(0.02, 0.03, 0.1, 0.8 * a))
	draw_string(Fonts.ui, Vector2(0, y + 12.0), String(plan.sub), HORIZONTAL_ALIGNMENT_CENTER, size.x, Settings.fs(12), col)

## Plattform am unteren Rand: Deckplatte mit Leuchtkante wie die Landeplattformen, Front mit Paneelen und Lampen, Haltestellenhäuschen.
func _draw_deck() -> void:
	var y := PixelDraw.snap_to(self, _deck_y())
	var col := Color("#35e0d2")
	for i in 10:                                                   # Lichtschein über der Plattform (wie _pad_glow)
		var k := float(i) / 10.0
		draw_rect(Rect2(0, y - float(i + 1) * 3.0, size.x, 3.0), Color(col.r, col.g, col.b, 0.13 * (1.0 - k) * (1.0 - k)))
	draw_rect(Rect2(0, y, size.x, size.y - y), Color("#161b44"))
	draw_rect(Rect2(0, y, size.x, 1.0), col.lightened(0.55))
	draw_rect(Rect2(0, y, size.x, PixelDraw.px_of(self)), Color.WHITE)
	draw_rect(Rect2(0, y + 1.0, size.x, 2.0), Color("#2a3170"))
	var seam := 0.0
	while seam < size.x:                                           # Paneele und Lampenreihe
		draw_rect(Rect2(seam, y + 3.0, 1.0, size.y - y - 3.0), INK)
		var on := 0.55 + (0.0 if still else 0.45 * sin(tt * 2.0 + seam * 0.07))
		draw_rect(Rect2(seam + 11.0, y + 9.0, 2.0, 1.0), Color(col.r, col.g, col.b, 0.35 + 0.5 * on))
		seam += 24.0
	draw_rect(Rect2(0, y + 15.0, size.x, 1.0), Color("#232a62"))
	var sn := PixelScale.size_for(self)
	var ss := PixelScale.sheet_rect(sn, SHELTER_UNITS)
	for sx in _shelters():
		var pos := PixelDraw.snap2_to(self, Vector2(float(sx) - SHELTER_IMG.x * 0.5, y - SHELTER_IMG.y))
		draw_texture_rect_region(SHELTER_TEX, Rect2(pos, SHELTER_IMG), Rect2(ss.position, SHELTER_IMG * float(sn)))

# ---------------------------------------------------------------- Fahrgäste mit Schildern

func _pass_src(frame: int, look: int) -> Rect2:
	var n := PixelScale.size_for(self)
	var r := PixelScale.sheet_rect(n, PASS_UNITS)
	return Rect2(r.position + Vector2(frame, look) * PASS_IMG * float(n), PASS_IMG * float(n))

## Figur mit den Füßen bei `feet` (Mitte unten), gespiegelt bei `mirror`, Bild `frame` (0–1 Stehen, 2–3 Winken, 4–9 Laufen).
func _figure(feet: Vector2, look: int, frame: int, mirror: bool, alpha: float, shade := 1.0) -> void:
	var fx := PixelDraw.snap_to(self, feet.x - PASS_IMG.x * 0.5) + PASS_IMG.x * 0.5
	var fy := PixelDraw.snap_to(self, feet.y - PASS_IMG.y)
	draw_set_transform(Vector2(fx, feet.y), 0.0, Vector2(1.0, 0.32))          # flacher Bodenschatten wie im Spiel
	draw_circle(Vector2.ZERO, 3.6, Color(0.0, 0.0, 0.05, 0.38 * alpha))
	draw_set_transform(Vector2(fx, 0), 0.0, Vector2(-1.0 if mirror else 1.0, 1.0))
	draw_texture_rect_region(PASS_TEX, Rect2(-PASS_IMG.x * 0.5, fy, PASS_IMG.x, PASS_IMG.y), _pass_src(frame, look % LOOKS), Color(shade, shade, shade, alpha))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

## Weg eines Halters: aus dem nächsten Häuschen zur Stelle, halten, zurück. Rückgabe {pos, frame, mirror, alpha, k (0 = unten … 1 = hochgehalten)}.
func _holder_state(p: Dictionary, spot: Vector2, mirror_hold: bool, seed: int) -> Dictionary:
	var door := 0.0
	var best := INF
	for sx in _shelters():
		if absf(float(sx) - spot.x) < best:
			best = absf(float(sx) - spot.x)
			door = float(sx)
	var s0: float = float(p.start) + 0.12 * float(seed % 4)
	var t_raise: float = float(p.start) + T_WALK
	var t_hold_end: float = t_raise + T_RAISE + float(p.read)
	var dist := absf(spot.x - door)
	var v := maxf(WALK_V, dist / maxf(t_raise - s0 - 0.3, 0.3))
	var tin := s0 + 0.3 + dist / v                              # angekommen
	var t_back := t_hold_end + T_LOWER
	var tout := t_back + dist / WALK_V
	var out := {"pos": spot, "frame": 0, "mirror": false, "alpha": 1.0, "k": 0.0, "visible": true}
	if tt < s0 or tt > tout + 0.3:
		out.visible = false
		return out
	if tt < s0 + 0.3:                                           # aus der Tür treten
		out.pos = Vector2(door, spot.y)
		out.alpha = (tt - s0) / 0.3
		out.frame = 0
		return out
	if tt < tin:
		var f := (tt - s0 - 0.3) * v
		out.pos = Vector2(door + signf(spot.x - door) * f, spot.y)
		out.frame = 4 + int(f / 2.2) % 6
		out.mirror = spot.x < door
		return out
	if tt < t_back:
		out.pos = spot
		out.mirror = mirror_hold
		var k := clampf((tt - t_raise) / T_RAISE, 0.0, 1.0) if tt < t_hold_end else 1.0 - clampf((tt - t_hold_end) / T_LOWER, 0.0, 1.0)
		out.k = k * k * (3.0 - 2.0 * k)
		var bob := int((tt + float(seed) * 0.37) / 0.55) % 2 == 0 and not still
		out.frame = (3 if bob else 2) if k > 0.0 else 0
		return out
	if tt < tout:                                               # zurück zur Tür
		var f2 := (tt - t_back) * WALK_V
		out.pos = Vector2(spot.x + signf(door - spot.x) * f2, spot.y)
		out.frame = 4 + int(f2 / 2.2) % 6
		out.mirror = door < spot.x
		return out
	out.pos = Vector2(door, spot.y)
	out.alpha = 1.0 - (tt - tout) / 0.3
	return out

func _draw_signs(p: Dictionary, row: int, idx: int) -> void:
	if p.signs.is_empty() or tt < float(p.start) - 0.1 or tt > float(p.start) + float(p.dur) + 4.0:
		return
	var feet_y := _deck_y() - (3.0 if row == 1 else 0.0)
	var shade := 0.78 if row == 1 else 1.0
	var si := 0
	for sg in p.signs:
		si += 1
		if int(sg.row) != row:
			continue
		var seed := idx * 7 + si * 3
		var look := (idx * 5 + si * 3) % LOOKS
		if String(sg.kind) == "placard":
			var st := _holder_state(p, Vector2(float(sg.cx) - HAND_X, feet_y), false, seed)
			if not st.visible:
				continue
			if float(st.k) > 0.0:
				_draw_placard(sg, st, row)
			_figure(st.pos, look, int(st.frame), bool(st.mirror), float(st.alpha), shade)
		else:
			var half: float = float(sg.sw) * 0.5
			var a := _holder_state(p, Vector2(float(sg.cx) - half - HAND_X, feet_y), false, seed)
			var b := _holder_state(p, Vector2(float(sg.cx) + half + HAND_X, feet_y), true, seed)
			if float(a.k) > 0.0 and float(b.k) > 0.0:
				_draw_band(sg, a, b, row)
			if a.visible:
				_figure(a.pos, look, int(a.frame), bool(a.mirror), float(a.alpha), shade)
			if b.visible:
				_figure(b.pos, (look + 6) % LOOKS, int(b.frame), bool(b.mirror), float(b.alpha), shade)

## Höhe der Faust über den Füßen im aktuellen Bild (Bild 2 liegt einen Drittelpunkt tiefer als Bild 3).
func _hand_y(st: Dictionary) -> float:
	return float(st.pos.y) - HAND_Y + (0.33 if int(st.frame) == 2 else 0.0)

func _sign_text(rows: Array, rect: Rect2, fs: int, alpha: float) -> void:
	var col := TEXT_COL
	col.a = alpha
	var y := rect.position.y + 2.0
	for r in rows:
		draw_string(Fonts.hud, PixelDraw.snap2_to(self, Vector2(rect.position.x, y + float(fs) * 0.82)), String(r), HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, fs, col)
		y += float(fs)

## Schild an der Stange: Stange aus der Faust nach oben, Tafel darüber, hebt sich beim Hochhalten aus der Hand.
func _draw_placard(sg: Dictionary, st: Dictionary, row: int) -> void:
	var k: float = st.k
	var px := PixelDraw.snap_to(self, float(st.pos.x) + HAND_X)
	var hy := _hand_y(st)
	var lift := 5.0 + (ROW_UP if row == 1 else 0.0)
	var h: float = sg.h
	var bottom := PixelDraw.snap_to(self, hy - lift * k - 1.0)
	var r := Rect2(px - float(sg.sw) * 0.5, bottom - h * k, float(sg.sw), h * k)
	draw_rect(Rect2(px - 0.5, r.position.y, 1.0, hy + 1.5 - r.position.y), POLE)
	draw_rect(r.grow(1.0), INK)
	draw_rect(r, CLOTH)
	draw_rect(Rect2(r.position.x, r.end.y - 1.0, r.size.x, 1.0), CLOTH_DARK)
	if k > 0.85:
		_sign_text(sg.rows, r, Settings.fs(SIGN_FS), (k - 0.85) / 0.15)

## Spruchband zwischen zwei Haltern: zwei Stangen, das Tuch rollt sich beim Hochhalten von unten nach oben auf, hängt leicht durch.
func _draw_band(sg: Dictionary, a: Dictionary, b: Dictionary, row: int) -> void:
	var k := minf(float(a.k), float(b.k))
	var xl := PixelDraw.snap_to(self, float(a.pos.x) + HAND_X)
	var xr := PixelDraw.snap_to(self, float(b.pos.x) - HAND_X)
	var hy := minf(_hand_y(a), _hand_y(b))
	var lift := 4.0 + (ROW_UP if row == 1 else 0.0)
	var h: float = sg.h
	var bottom := PixelDraw.snap_to(self, hy - lift * k - 1.0)
	var top := PixelDraw.snap_to(self, bottom - h * k)
	for x in [xl, xr]:
		draw_rect(Rect2(x - 0.5, top - 1.0, 1.0, hy + 1.5 - top + 1.0), POLE)
		draw_rect(Rect2(x - 1.0, top - 2.0, 2.0, 1.0), Color("#ffe14a"))
	var w := xr - xl - 1.0
	var r := Rect2(xl + 0.5, top, w, bottom - top)
	if r.size.y < 0.5:
		return
	var sag := 0.0 if still else 0.5 + 0.5 * sin(tt * 1.7 + xl * 0.1)
	draw_rect(r.grow(1.0), INK)
	draw_rect(r, CLOTH)
	draw_rect(Rect2(r.position.x, r.position.y, r.size.x, 1.0), BANNER_EDGE)
	draw_rect(Rect2(r.position.x, r.end.y - 1.0, r.size.x, 1.0), BANNER_EDGE)
	if sag > 0.5:                                                 # Falten im Tuch
		draw_rect(Rect2(r.position.x + r.size.x * 0.33, r.position.y + 1.0, 1.0, r.size.y - 2.0), Color(CLOTH_DARK, 0.5))
		draw_rect(Rect2(r.position.x + r.size.x * 0.68, r.position.y + 1.0, 1.0, r.size.y - 2.0), Color(CLOTH_DARK, 0.5))
	draw_rect(Rect2(r.position.x, r.end.y, r.size.x, 1.0), INK)    # Stab am unteren Rand
	if k > 0.85:
		_sign_text(sg.rows, Rect2(r.position.x, r.position.y + 1.0, r.size.x, r.size.y), Settings.fs(SIGN_FS), (k - 0.85) / 0.15)

## Schluss: aus jedem Häuschen kommen zwei Fahrgäste und winken.
func _draw_wavers(p: Dictionary) -> void:
	var s0: float = float(p.start)
	if tt < s0:
		return
	var i := 0
	for sx in _shelters():
		for side in [-1.0, 1.0]:
			i += 1
			var go := clampf((tt - s0 - 0.15 * float(i % 5)) / 1.0, 0.0, 1.0)
			if tt < s0 + 0.15 * float(i % 5):
				continue
			var pos := Vector2(float(sx) + side * (6.0 + 14.0 * go), _deck_y())
			var alpha := clampf((tt - s0 - 0.15 * float(i % 5)) / 0.3, 0.0, 1.0)
			var frame := 4 + int(go * 14.0 / 2.2) % 6 if go < 1.0 else (2 + int(tt * 5.0 + float(i)) % 2)
			_figure(pos, (i * 5) % LOOKS, frame, side < 0.0 and go < 1.0, alpha)

# ---------------------------------------------------------------- Taxi mit Banner

func _route_len(p: Dictionary) -> PackedFloat32Array:
	if p.has("_lut"):
		return p._lut
	var lut := PackedFloat32Array([0.0])
	var prev := bezier(p.route, 0.0)
	var acc := 0.0
	for i in range(1, 129):
		var q := bezier(p.route, float(i) / 128.0)
		acc += prev.distance_to(q)
		lut.append(acc)
		prev = q
	p["_lut"] = lut
	return lut

## Ort auf der Bahn nach Flugzeit (gleichmäßiges Tempo über die Bogenlänge).
func _route_at(p: Dictionary, f: float) -> Vector2:
	var lut := _route_len(p)
	var target := clampf(f, 0.0, 1.0) * lut[lut.size() - 1]
	var i := lut.bsearch(target)
	i = clampi(i, 1, lut.size() - 1)
	var seg := (target - lut[i - 1]) / maxf(lut[i] - lut[i - 1], 0.0001)
	return bezier(p.route, (float(i - 1) + seg) / 128.0)

func _draw_flight(idx: int, p: Dictionary) -> void:
	var f := (tt - float(p.taxi_in)) / float(p.taxi_t)
	if f < 0.0 or f > 1.0:
		return
	var pos := _route_at(p, f)
	var dir: float = p.dir
	if _trail_pass != idx or _trail.is_empty():
		_trail_pass = idx
		_trail = PackedVector2Array()
		var back := (bezier(p.route, 0.0) - bezier(p.route, 0.02)).normalized()
		for s in range(120, 0, -1):                               # vor dem Einflug: gerade Spur rückwärts, das Banner hängt schon dran
			_trail.append(bezier(p.route, 0.0) + back * float(s) * 4.0)
	_trail.append(pos)
	if _trail.size() > 1400:
		_trail = _trail.slice(_trail.size() - 1000)
	var ahead := _route_at(p, f + 0.01)
	var vx := (ahead.x - pos.x) / (0.01 * float(p.taxi_t))
	var cat := String(p.cat)
	_draw_towed_banner(pos, dir, cat)
	_draw_taxi(pos, dir, vx, String(p.paint))

## Höhe der Schleppspur in `d` Einheiten (waagerecht) hinter dem Taxi, für d = 0 … n−1.
func _trail_heights(pos: Vector2, n: int) -> PackedFloat32Array:
	var ys := PackedFloat32Array()
	ys.resize(n)
	var j := _trail.size() - 1
	for d in n:
		while j > 0 and absf(_trail[j].x - pos.x) < float(d):
			j -= 1
		var a := _trail[mini(j + 1, _trail.size() - 1)]
		var b := _trail[j]
		var da := absf(a.x - pos.x)
		var db := absf(b.x - pos.x)
		var u := clampf((float(d) - da) / maxf(db - da, 0.001), 0.0, 1.0)
		ys[d] = lerpf(a.y, b.y, u)
	return ys

func _draw_towed_banner(pos: Vector2, dir: float, cat: String) -> void:
	var fs := Settings.fs(CAT_FS)
	var font: Font = Fonts.hud
	var tw := font.get_string_size(cat, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var blen := ceilf(tw) + 16.0
	var bh := float(fs) + 5.0
	var n := int(ROPE + blen) + 2
	var ys := _trail_heights(pos, n)
	var px := PixelDraw.px_of(self)
	var col_y := PackedFloat32Array()
	col_y.resize(n)
	for d in n:                                                   # Flattern nimmt zum Ende hin zu
		var k := clampf((float(d) - ROPE) / blen, 0.0, 1.0)
		var fl := 0.0 if still else (0.4 + 1.6 * k) * sin(tt * 9.0 - float(d) * 0.21)
		col_y[d] = PixelDraw.snap_to(self, ys[d] + fl)
	var hook := pos + Vector2(-dir * 12.0, 3.0)
	var lead_y := col_y[int(ROPE)]
	var lead_x := pos.x - dir * ROPE
	PixelDraw.line(self, hook, Vector2(lead_x, lead_y - bh * 0.5), Color(0.8, 0.82, 0.95, 0.85), 1)
	PixelDraw.line(self, hook, Vector2(lead_x, lead_y + bh * 0.5), Color(0.8, 0.82, 0.95, 0.85), 1)
	for d in range(int(ROPE), int(ROPE + blen)):                  # Tuch spaltenweise (je 1 Einheit), folgt der Spur und flattert
		var x := pos.x - dir * float(d) - (1.0 if dir > 0.0 else 0.0)
		var y := col_y[d] - bh * 0.5
		var tail := float(d) > ROPE + blen - 3.0
		draw_rect(Rect2(x, y - px, 1.0, bh + px * 2.0), INK)
		draw_rect(Rect2(x, y, 1.0, bh), CLOTH_DARK if tail else CLOTH)
		draw_rect(Rect2(x, y, 1.0, 1.0), BANNER_EDGE)
		draw_rect(Rect2(x, y + bh - 1.0, 1.0, 1.0), BANNER_EDGE)
	draw_rect(Rect2(lead_x - 0.5, lead_y - bh * 0.5 - 1.0, 1.0, bh + 2.0), INK)        # Stab an der Vorderkante
	var left := pos.x - dir * ROPE - blen if dir > 0.0 else pos.x + ROPE
	var gx := left + 8.0
	var col := TEXT_COL
	for i in cat.length():                                        # Schrift Zeichen für Zeichen auf der Höhe ihrer Spalte, nie gespiegelt
		var ch := cat.unicode_at(i)
		var adv := font.get_char_size(ch, fs).x
		var d := clampi(int(absf(gx + adv * 0.5 - pos.x)), 0, n - 1)
		var y := col_y[d] - bh * 0.5 + 2.0 + float(fs) * 0.82
		draw_char(font, PixelDraw.snap2_to(self, Vector2(gx, y)), cat.substr(i, 1), fs, col)
		gx += adv

func _draw_taxi(pos: Vector2, dir: float, vx: float, paint: String) -> void:
	var n := PixelScale.size_for(self)
	var yaw := clampf(vx / 60.0, -1.0, 1.0)
	var c := PixelDraw.snap2_to(self, pos)
	var flick := 0.0 if still else sin(tt * 47.0) * 0.5 + 0.5
	var fl := 3.0 + 2.0 * flick                                  # Hauptdüse: leichter Schub nach unten (hält die Höhe)
	for i in FIRE.size():
		var k := 1.0 - float(i) / float(FIRE.size())
		PixelDraw.jet(self, c + Vector2(0, 8.0), Vector2(0, 1), fl * k + 1.0, 2.2 * k + 0.4, FIRE[i])
	var sl := 4.0 + 3.0 * flick                                  # Lenkdüse hinten (gegen die Flugrichtung)
	for i in ICE.size():
		var k2 := 1.0 - float(i) / float(ICE.size())
		PixelDraw.jet(self, c + Vector2(-dir * 13.0, 0.0), Vector2(-dir, 0), sl * k2 + 1.0, 1.4 * k2 + 0.3, ICE[i])
	for pf in _puffs:
		var age: float = pf[1]
		PixelDraw.disc(self, pf[0], 0.8 + age * 2.2, Color(0.75, 0.78, 0.95, 0.35 * (1.0 - age)))
	if tt - _puff_t > 0.035 and not still:                     # Abgaswölkchen hinter der Lenkdüse, zeitlich gleichmäßig
		_puff_t = tt
		_puffs.append([pos + Vector2(-dir * 18.0, 0.5), 0.0])
	var fr := Cosmetics.taxi3d_frame(n, roundi((yaw + 1.0) * 0.5 * float(Cosmetics.TAXI3D_FRAMES - 1)), paint)
	if fr.is_empty():
		fr = Cosmetics.taxi_frame(n, paint)
	var r := Rect2(c - Tuning.TAXI_UNITS * 0.5, Tuning.TAXI_UNITS)
	draw_texture_rect_region(fr.tex, r, fr.src)

func _step_puffs(dt: float) -> void:
	for pf in _puffs:
		pf[1] = float(pf[1]) + dt * 1.6
		pf[0] = pf[0] + Vector2(0, -3.0 * dt)
	_puffs = _puffs.filter(func(pf): return float(pf[1]) < 1.0)
