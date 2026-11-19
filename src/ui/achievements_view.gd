extends Control
## Erfolgsübersicht (aus der Statistik erreichbar): Karten in zwei Spalten, je Seite sieben Zeilen. Erreichte Erfolge farbig mit Datum,
## offene grau mit Fortschritt („312 / 500“ und Balken). Blättern: Links/Rechts, LB/RB, Bild auf/ab, Mausrad oder die Pfeile;
## zurück zur Statistik mit B, Esc oder dem Knopf. Inhalt auf der 640×360-Fläche, Hintergrund über das ganze Fenster.

const Stage := preload("res://src/core/stage.gd")
const Achievements := preload("res://src/core/achievements.gd")
const AchToast := preload("res://src/ui/ach_toast.gd")

const COLS := 2
const ROWS := 7
const CARD := Vector2(292, 34)
const GAP := Vector2(8, 4)
const TOP := 52.0
const STATS := "res://src/ui/stats.tscn"

var page := 0
var canvas: Control
var data: Dictionary = {}
var arrow_l := Rect2()
var arrow_r := Rect2()
var back_r := Rect2()

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if is_inside_tree():
		Music.play_theme("menu")
	data = Save.data
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--export-ach-icons="):     # Dev: Symbole für Steamworks (64×64, erreicht und gesperrt) speichern und beenden
			_export_icons.call_deferred(arg.substr(19))
			return
		if arg == "--ach-demo":                     # Dev: Beispielstand für Screenshots (nichts wird gespeichert)
			data = demo_data()
		elif arg.begins_with("--ach-toast="):       # Dev: Banner zeigen (Erfolgs-ID oder „retro“)
			var v := arg.substr(12)
			if v == "retro":
				Save.ach_retro = 12
			else:
				Save.ach_pending.append(v)
			AchToast.flush(get_tree())
	var backdrop := Control.new()
	backdrop.set_script(load("res://src/ui/menu_backdrop.gd"))
	add_child(backdrop)
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.03, 0.1, 0.72)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	canvas = Stage.make(self)
	canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.draw.connect(_draw_page)

## Beispielstand: einige Erfolge erreicht, andere mit Fortschritt.
static func demo_data() -> Dictionary:
	var comp := {}
	for i in range(1, 12):
		comp["s1_%02d" % i] = {"medals": {"time": true, "clean": i % 3 != 0, "pro": i % 2 == 0}}
	for i in range(1, 8):
		comp["s2_%02d" % i] = {"medals": {"time": true, "clean": false, "pro": false}}
	var d := {"completed": comp, "stats": {"deliveries": 312, "perfect_landings": 61, "best_streak": 7, "credits_total": 48210, "crashes": 23,
		"pump_explosions": 1, "shift_runs": 2, "shift_best_grade": "B", "day_golds": 1, "daily_best_streak": 3, "play_seconds": 21000.0},
		"cosmetics": {"paint": "neon", "sticker": "none"}}
	Achievements.update(d, "2026-11-12")
	return d

func pages() -> int:
	return ceili(float(Achievements.LIST.size()) / float(COLS * ROWS))

func turn(d: int) -> void:
	var np := clampi(page + d, 0, pages() - 1)
	if np != page:
		page = np
		Sfx.play("ui_move")
		canvas.queue_redraw()

func _back() -> void:
	Sfx.play("ui_ok")
	Flow.came_from_achievements = true
	get_tree().change_scene_to_file(STATS)

func _unhandled_input(e: InputEvent) -> void:
	var used := true
	if e.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_back()
		return
	elif e.is_action_pressed("ui_left") or (e is InputEventJoypadButton and e.pressed and e.button_index == JOY_BUTTON_LEFT_SHOULDER) \
			or (e is InputEventKey and e.pressed and e.keycode == KEY_PAGEUP):
		turn(-1)
	elif e.is_action_pressed("ui_right") or (e is InputEventJoypadButton and e.pressed and e.button_index == JOY_BUTTON_RIGHT_SHOULDER) \
			or (e is InputEventKey and e.pressed and e.keycode == KEY_PAGEDOWN):
		turn(1)
	elif e.is_action_pressed("ui_accept") and not (e is InputEventMouseButton):
		_back()
	elif e is InputEventMouseButton and e.pressed:
		var p := canvas.get_local_mouse_position()
		match e.button_index:
			MOUSE_BUTTON_WHEEL_UP: turn(-1)
			MOUSE_BUTTON_WHEEL_DOWN: turn(1)
			MOUSE_BUTTON_LEFT:
				if arrow_l.has_point(p):
					turn(-1)
				elif arrow_r.has_point(p):
					turn(1)
				elif back_r.has_point(p):
					_back()
				else:
					used = false
			_: used = false
	else:
		used = false
	if used and is_inside_tree():
		get_viewport().set_input_as_handled()

func _draw_page() -> void:
	var have := Achievements.stored(data)
	var f: Font = Fonts.title
	var title := tr("ACH_TITLE")
	var cnt := "%d / %d" % [have.size(), Achievements.LIST.size()]
	var tw := f.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, 24).x
	var cw := Fonts.hud.get_string_size(cnt, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
	var x0 := 320.0 - (tw + 10.0 + cw) * 0.5
	canvas.draw_string(f, Vector2(x0, 34.0), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color("#ffe14a"))
	canvas.draw_string(Fonts.hud, Vector2(x0 + tw + 10.0, 33.0), cnt, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("#8c9cff"))
	var gx := 320.0 - (CARD.x * COLS + GAP.x * (COLS - 1)) * 0.5
	var per := COLS * ROWS
	for i in per:
		var idx := page * per + i
		if idx >= Achievements.LIST.size():
			break
		var id := String(Achievements.LIST[idx][0])
		var r := Rect2(gx + float(i % COLS) * (CARD.x + GAP.x), TOP + float(i / COLS) * (CARD.y + GAP.y), CARD.x, CARD.y)
		_card(r, id, have)
	# Fußzeile: Seiten, Pfeile, Zurück
	var fy := 340.0
	var pg := "%d / %d" % [page + 1, pages()]
	var hf: Font = Fonts.hud
	var pw := hf.get_string_size(pg, HORIZONTAL_ALIGNMENT_LEFT, -1, 9).x
	canvas.draw_string(hf, Vector2(320.0 - pw * 0.5, fy + 3.0), pg, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color("#c9d3ff"))
	arrow_l = Rect2(320.0 - pw * 0.5 - 26.0, fy - 9.0, 18.0, 16.0)
	arrow_r = Rect2(320.0 + pw * 0.5 + 8.0, fy - 9.0, 18.0, 16.0)
	for ar in [[arrow_l, -1.0, page > 0], [arrow_r, 1.0, page < pages() - 1]]:
		var rr: Rect2 = ar[0]
		var c := rr.get_center()
		var dx: float = ar[1] * 4.0
		var col := Color("#ffe14a") if ar[2] else Color(0.35, 0.38, 0.55)
		canvas.draw_colored_polygon(PackedVector2Array([c + Vector2(dx, 0), c + Vector2(-dx, -5), c + Vector2(-dx, 5)]), col)
	var hint := "%s / %s  ·  %s" % [Controls.pad_name("LB"), Controls.pad_name("RB"), tr("ACH_PAGE")]
	canvas.draw_string(hf, Vector2(24.0, fy + 3.0), hint, HORIZONTAL_ALIGNMENT_LEFT, 200, 7, Color(0.55, 0.6, 0.8))
	var bt := tr("MENU_BACK")
	var bw := hf.get_string_size(bt, HORIZONTAL_ALIGNMENT_LEFT, -1, 9).x + 18.0
	back_r = Rect2(616.0 - bw, fy - 9.0, bw, 16.0)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.1, 0.13, 0.32, 0.95)
	sb.border_color = Color("#4a5aa0")
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(5)
	canvas.draw_style_box(sb, back_r)
	canvas.draw_string(hf, Vector2(back_r.position.x + 9.0, fy + 3.0), bt, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color("#e6ebff"))

func _card(r: Rect2, id: String, have: Dictionary) -> void:
	var done := have.has(id)
	var cat := Achievements.category(id)
	var col: Color = AchToast.CAT_COLORS.get(cat, Color.WHITE)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.07, 0.09, 0.22, 0.92) if done else Color(0.05, 0.06, 0.13, 0.85)
	sb.border_color = Color(col, 0.75) if done else Color(0.25, 0.28, 0.45, 0.8)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(6)
	canvas.draw_style_box(sb, r)
	AchToast.draw_badge(canvas, id, r.position + Vector2(18.0, r.size.y * 0.5), 12.0, done)
	var tx := r.position.x + 36.0
	var name_col := Color(0.95, 0.97, 1.0) if done else Color(0.62, 0.66, 0.8)
	var right_w := 64.0
	var g := Achievements.goal(id)
	var veiled := not done and Achievements.is_hidden(id)             # verdeckt, bis erreicht
	var desc := tr("ACH_HIDDEN_D") if veiled else tr("ACH_%s_D" % id.to_upper())
	if desc.contains("%d"):
		desc = desc % g
	canvas.draw_string(Fonts.ui, Vector2(tx, r.position.y + 14.0), tr("ACH_HIDDEN") if veiled else tr("ACH_" + id.to_upper()), HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 36.0 - right_w, 10, name_col)
	canvas.draw_string(Fonts.ui, Vector2(tx, r.position.y + 26.0), desc, HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 40.0, 7, Color(0.6, 0.65, 0.82) if done else Color(0.48, 0.52, 0.66))
	var rx := r.end.x - 8.0
	if done:
		var d := _date(String(have[id]))
		var dw := Fonts.hud.get_string_size(d, HORIZONTAL_ALIGNMENT_LEFT, -1, 7).x
		canvas.draw_string(Fonts.hud, Vector2(rx - dw, r.position.y + 13.0), d, HORIZONTAL_ALIGNMENT_LEFT, -1, 7, Color(col, 0.9))
	elif g > 1 and not veiled:
		var p := Achievements.progress(data, id)
		var txt := "%d / %d" % [p[0], p[1]]
		var pw := Fonts.hud.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 7).x
		canvas.draw_string(Fonts.hud, Vector2(rx - pw, r.position.y + 12.0), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 7, Color(0.7, 0.74, 0.9))
		var bar := Rect2(rx - 52.0, r.position.y + 15.5, 52.0, 3.0)
		canvas.draw_rect(bar, Color(0.16, 0.18, 0.32))
		canvas.draw_rect(Rect2(bar.position, Vector2(bar.size.x * clampf(float(p[0]) / float(p[1]), 0.0, 1.0), bar.size.y)), Color(col, 0.7))

## Datum JJJJ-MM-TT in der Schreibweise der Sprache (de/pl: TT.MM.JJJJ, fr/es/it/pt: TT/MM/JJJJ, en: JJJJ-MM-TT).
static func _date(iso: String) -> String:
	var p := iso.split("-")
	if p.size() != 3:
		return iso
	match TranslationServer.get_locale().substr(0, 2):
		"de", "pl": return "%s.%s.%s" % [p[2], p[1], p[0]]
		"fr", "es", "it", "pt": return "%s/%s/%s" % [p[2], p[1], p[0]]
	return iso

## Dev (--export-ach-icons=<Ordner>): je Erfolg ACH_<ID>.png und ACH_<ID>_locked.png in 64×64 (in 256×256 gezeichnet, dann verkleinert).
func _export_icons(dir: String) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	var vp := SubViewport.new()
	vp.size = Vector2i(256, 256)
	vp.transparent_bg = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var ctl := Control.new()
	ctl.size = Vector2(256, 256)
	vp.add_child(ctl)
	add_child(vp)
	var cur := [Achievements.ids()[0], true]
	ctl.draw.connect(func(): AchToast.draw_badge(ctl, String(cur[0]), Vector2(128, 128), 118.0, bool(cur[1])))
	var n := 0
	for id in Achievements.ids():
		for unlocked in [true, false]:
			cur[0] = id
			cur[1] = unlocked
			ctl.queue_redraw()
			await RenderingServer.frame_post_draw
			await RenderingServer.frame_post_draw
			var img := vp.get_texture().get_image()
			img.resize(64, 64, Image.INTERPOLATE_LANCZOS)
			img.save_png(dir.path_join(SteamBridge.api_name(id) + ("" if unlocked else "_locked") + ".png"))
			n += 1
	print("Erfolgssymbole gespeichert: %d in %s" % [n, dir])
	get_tree().quit()
