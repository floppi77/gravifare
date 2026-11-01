extends Control
## Finale nach Level 99: Das Taxi fliegt in den Sonnenuntergang und setzt zum Feierabend auf. Die Zentrale meldet sich ein letztes Mal,
## dann folgt die Bilanz der gesamten Fahrt und die Widmung. A/Enter führt zum Abspann. Dev: --scene=finale

const Stage := preload("res://src/core/stage.gd")
const T_STATS := 11.0                # ab hier steht die Bilanz im Bild
var bg: Texture2D = load("res://assets/art/bg_menu.png")
var taxi: Texture2D = Cosmetics.paint_texture()
var t := 0.0
var spoken := 0
var rows: Array = []

func _ready() -> void:
	Music.play_theme("menu")
	Music.set_layers(true, false)
	Music.duck(-6.0)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var st: Dictionary = Save.data.stats
	var secs := int(float(st.get("play_seconds", 0.0)))
	rows = [[tr("FINALE_LEVELS"), "%d / 99" % Save.data.completed.size()], [tr("FINALE_SCORE"), str(Save.total_score())],
		[tr("FINALE_TIME"), "%d:%02d h" % [secs / 3600, (secs % 3600) / 60]], [tr("FINALE_FARES"), str(int(st.get("deliveries", 0)))],
		[tr("FINALE_PERFECT"), str(int(st.get("perfect_landings", 0)))], [tr("FINALE_CRASHES"), str(int(st.get("crashes", 0)))]]
	Save.note_max("finale_seen", 1)
	Save.write()

func _process(delta: float) -> void:
	t += delta
	if spoken == 0 and t > 1.5:
		spoken = 1
		_say("finale_1")
	elif spoken == 1 and t > 7.5 and not Sfx.voice_player.playing:
		spoken = 2
		_say("finale_2")
	queue_redraw()

func _say(key: String) -> void:
	Sfx.play_voice("d0", key)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept") or event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		Sfx.voice_player.stop()
		Music.duck(0.0)
		get_tree().change_scene_to_file("res://src/ui/credits.tscn")

func _draw() -> void:
	var vs := get_viewport_rect().size
	var cover := maxf(vs.x / 640.0, vs.y / 360.0)
	var w := 640.0 * cover * 1.05
	var h := 360.0 * cover * 1.05
	var drift := minf(t / 20.0, 1.0)
	draw_texture_rect(bg, Rect2(-(w - vs.x) * (0.3 + 0.4 * drift), -(h - vs.y) * 0.5, w, h), false)
	draw_rect(Rect2(Vector2.ZERO, vs), Color(0.10, 0.04, 0.10, 0.10 + 0.34 * clampf((t - T_STATS + 1.5) / 1.5, 0.0, 1.0)))
	var m := Stage.margin(self)
	draw_set_transform(m)
	_draw_taxi()
	_draw_radio()
	if t >= T_STATS:
		_draw_stats()
	var ta := clampf(t / 1.2, 0.0, 1.0)
	var ink := Color(0.16, 0.05, 0.08, 0.9 * ta)
	draw_string_outline(Fonts.title, Vector2(0, 58), tr("FINALE_TITLE"), HORIZONTAL_ALIGNMENT_CENTER, 640, 30, 3, ink)
	draw_string(Fonts.title, Vector2(0, 58), tr("FINALE_TITLE"), HORIZONTAL_ALIGNMENT_CENTER, 640, 30, Color(1.0, 0.95, 0.72, ta))
	draw_string_outline(Fonts.hud, Vector2(0, 74), tr("FINALE_SUB"), HORIZONTAL_ALIGNMENT_CENTER, 640, 11, 3, ink)
	draw_string(Fonts.hud, Vector2(0, 74), tr("FINALE_SUB"), HORIZONTAL_ALIGNMENT_CENTER, 640, 11, Color(1, 1, 1, ta))

## Flug von links in großem Bogen, setzt rechts unten sanft auf den Dünen auf.
func _draw_taxi() -> void:
	var k := clampf(t / 9.0, 0.0, 1.0)
	var e := k * k * (3.0 - 2.0 * k)
	var p := Vector2(lerpf(-40.0, 470.0, e), lerpf(130.0, 292.0, e) - sin(e * PI) * 46.0)
	var s := lerpf(0.7, 1.5, e)
	var tilt := 0.16 * (1.0 - e)
	if k < 1.0:
		for i in 18:
			var f := float(i) / 18.0
			draw_rect(Rect2(p + Vector2(-20.0 * s - float(i) * 3.0, sin(t * 18.0 + float(i)) * 0.6), Vector2(3, 2.0 - f)), Color(1.0, 0.7, 0.3, (1.0 - f) * 0.6 * (1.0 - k)))
	else:
		draw_rect(Rect2(p + Vector2(-18.0, 13.0 * s), Vector2(36, 2)), Color(0.2, 0.08, 0.05, 0.35))
	draw_set_transform(Stage.margin(self) + p, tilt, Vector2(s, s))
	draw_texture_rect(taxi, Rect2(-16, -10, 32, 20), false)
	draw_set_transform(Stage.margin(self))

## Funkspruch als Untertitel (Stimme d0).
func _draw_radio() -> void:
	if not Settings.values.subtitles or t >= T_STATS or spoken == 0:
		return
	var text := Sfx.line_text("d0", "finale_%d" % spoken)
	draw_rect(Rect2(60, 318, 520, 30), Color(0.04, 0.05, 0.14, 0.78))
	draw_rect(Rect2(60, 318, 520, 1), Color(1.0, 0.88, 0.58, 0.7))
	draw_multiline_string(Fonts.ui, Vector2(70, 331), text, HORIZONTAL_ALIGNMENT_CENTER, 500, 10, 2, Color(0.96, 0.97, 1.0))

func _draw_stats() -> void:
	var a := clampf((t - T_STATS) / 1.0, 0.0, 1.0)
	var r := Rect2(190, 92, 260, 150)
	draw_rect(r, Color(0.05, 0.05, 0.14, 0.86 * a))
	draw_rect(r, Color(1.0, 0.82, 0.45, 0.8 * a), false, 1.0)
	for i in rows.size():
		var y := r.position.y + 22.0 + float(i) * 22.0
		draw_string(Fonts.ui, Vector2(r.position.x + 16.0, y), rows[i][0], HORIZONTAL_ALIGNMENT_LEFT, 150, 11, Color(0.82, 0.86, 1.0, a))
		draw_string(Fonts.hud, Vector2(r.position.x + 110.0, y), rows[i][1], HORIZONTAL_ALIGNMENT_RIGHT, 134, 12, Color(1.0, 0.88, 0.4, a))
	var b := clampf((t - T_STATS - 1.5) / 1.0, 0.0, 1.0)
	draw_string_outline(Fonts.title, Vector2(0, 272), tr("FINALE_IDEA"), HORIZONTAL_ALIGNMENT_CENTER, 640, 24, 3, Color(0.16, 0.05, 0.08, 0.9 * b))
	draw_string(Fonts.title, Vector2(0, 272), tr("FINALE_IDEA"), HORIZONTAL_ALIGNMENT_CENTER, 640, 24, Color(1, 1, 1, b))
	draw_string_outline(Fonts.ui, Vector2(0, 340), tr("FINALE_NEXT"), HORIZONTAL_ALIGNMENT_CENTER, 640, 10, 3, Color(0.16, 0.05, 0.08, 0.9 * b))
	draw_string(Fonts.ui, Vector2(0, 340), tr("FINALE_NEXT"), HORIZONTAL_ALIGNMENT_CENTER, 640, 10, Color(1.0, 0.97, 0.9, b))
