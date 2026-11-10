class_name IntroClip
extends Control
## Einspieler („kleines Video“) für ein neu eingeführtes Spielelement: Das Spiel pausiert, in einem Bildschirm in der Mitte läuft eine
## kurze Demonstration mit der echten Spielphysik (IntroDemo), dazu Sprache (Fluglehrer, i0) und Untertitel. Enter/B/Esc überspringt.
## Liegt in einer CanvasLayer über dem HUD; `game` liefert Sprache und Pause (game.gd).

signal finished

const VIEW := Vector2(640, 360)            # interne Auflösung der Demo (wie das Spiel)
const SCREEN := Rect2(80, 40, 480, 270)    # Bildschirmfenster im Overlay

var game: Node
var demo: IntroDemo
var key := ""
var sv: SubViewport
var tex: TextureRect
var cam: Camera2D
var taxi_node: Node2D
var props_node: Node2D
var dark_node: Control
var t := 0.0
var speak_len := 0.0
var total := 8.0
var fade := 0.0
var closing := false
var title := ""
var text := ""

func start(g: Node, k: String) -> bool:
	game = g
	key = k
	demo = IntroDemo.new()
	if not demo.setup(k):
		return false
	set_anchors_preset(Control.PRESET_TOP_LEFT)       # feste 640×360-Fläche; die CanvasLayer verschiebt sie in die Mitte (siehe game.gd)
	size = VIEW
	mouse_filter = Control.MOUSE_FILTER_STOP
	var lang := TranslationServer.get_locale().substr(0, 2)
	var tt: Dictionary = demo.data.get("title", {})
	title = String(tt.get(lang, tt.get("de", k)))
	_build_view()
	var info: Dictionary = game.call("tutorial_speak", "vid_" + k)
	speak_len = float(info.len)
	text = String(info.text)
	total = maxf(demo.length, speak_len + 0.8)
	return true

func _build_view() -> void:
	sv = SubViewport.new()
	sv.size = Vector2i(int(VIEW.x), int(VIEW.y))
	sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	sv.transparent_bg = false
	add_child(sv)
	var bg := ColorRect.new()
	bg.size = VIEW
	var sh := Shader.new()
	sh.code = "shader_type canvas_item;\nvoid fragment() {\n\tCOLOR = vec4(mix(vec3(0.03, 0.04, 0.13), vec3(0.14, 0.1, 0.28), UV.y), 1.0);\n}\n"
	var mat := ShaderMaterial.new()
	mat.shader = sh
	bg.material = mat
	var bgl := CanvasLayer.new()
	bgl.layer = -5
	bgl.follow_viewport_enabled = false
	bgl.add_child(bg)
	sv.add_child(bgl)
	var amb := CanvasModulate.new()
	amb.color = Color(0.86, 0.9, 1.0)
	sv.add_child(amb)
	var world := Node2D.new()
	sv.add_child(world)
	var unlit := CanvasItemMaterial.new()
	unlit.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	var tiles := Node2D.new()
	tiles.set_script(load("res://src/game/world_view.gd"))
	world.add_child(tiles)
	props_node = Node2D.new()
	props_node.set_script(load("res://src/game/props_view.gd"))
	props_node.material = unlit
	world.add_child(props_node)
	var tags := Node2D.new()                                    # Kennzeichen VIP/Notfall wie im Spiel
	tags.set_script(load("res://src/game/passenger_tags.gd"))
	tags.material = unlit
	world.add_child(tags)
	taxi_node = Node2D.new()
	taxi_node.set_script(load("res://src/game/taxi_view.gd"))
	taxi_node.material = unlit
	world.add_child(taxi_node)
	cam = Camera2D.new()
	cam.process_callback = Camera2D.CAMERA2D_PROCESS_PHYSICS      # sonst Warnung wegen Physik-Interpolation
	var focus: Array = demo.data.get("focus", [320, 180])
	cam.position = Vector2(float(focus[0]), float(focus[1]))
	var z := float(demo.data.get("zoom", 1.5))
	cam.zoom = Vector2(z, z)
	sv.add_child(cam)
	cam.make_current()
	tiles.setup(demo.run)
	props_node.setup(demo.run)
	tags.setup(demo.run)
	taxi_node.bind(demo.run.sim)
	taxi_node.sync_state()
	taxi_node.reset_physics_interpolation()
	if demo.level.dark > 0.0:
		var dl := CanvasLayer.new()
		dl.layer = 4
		sv.add_child(dl)
		dark_node = Control.new()
		dark_node.set_script(load("res://src/game/dark_view.gd"))
		dl.add_child(dark_node)
		dark_node.setup(demo.run, cam)
	tex = TextureRect.new()
	tex.texture = sv.get_texture()
	tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex.stretch_mode = TextureRect.STRETCH_SCALE
	tex.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tex.custom_minimum_size = SCREEN.size
	add_child(tex)
	tex.set_anchors_preset(Control.PRESET_TOP_LEFT)
	tex.position = SCREEN.position
	tex.size = SCREEN.size

func _input(event: InputEvent) -> void:
	if closing:
		return
	if event.is_action_pressed("ui_accept") or event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause"):
		_close()
		get_viewport().set_input_as_handled()

func _close() -> void:
	closing = true
	game.call("tutorial_voice_stop")

func _physics_process(delta: float) -> void:
	if closing:
		return
	demo.step(delta)
	taxi_node.sync_state()
	if demo.run.sim.state == TaxiSim.State.DESTROYED:
		demo.run.respawn_after_crash()

func _process(delta: float) -> void:
	if closing:
		fade = move_toward(fade, 0.0, delta * 3.5)
		if fade <= 0.0:
			finished.emit()
			queue_free()
			return
	else:
		t += delta
		fade = move_toward(fade, 1.0, delta * 3.5)
		if t >= total + 0.4:
			_close()
	queue_redraw()

func _draw() -> void:
	if fade <= 0.01:
		return
	var f := fade
	var hud := Fonts.hud
	var mg := (get_viewport_rect().size - VIEW) * 0.5
	draw_rect(Rect2(-mg, get_viewport_rect().size), Color(0.0, 0.0, 0.03, 0.62 * f))
	# Rahmen des Bildschirms
	var r := SCREEN
	draw_rect(r.grow(7.0), Color(0.02, 0.03, 0.09, 0.95 * f))
	draw_rect(r.grow(5.0), Color(0.22, 0.26, 0.5, f), false, 1.0)
	draw_rect(r.grow(2.0), Color(0.07, 0.09, 0.2, f), false, 2.0)
	# Titel
	draw_string(hud, Vector2(r.position.x, r.position.y - 13.0), "%s: %s" % [tr("CLIP_NEW"), title], HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 70.0, 11, Color(1.0, 0.88, 0.45, f))
	# Aufnahme-Kennung (blinkender Punkt)
	var blink := 0.5 + 0.5 * sin(t * 5.0)
	draw_circle(r.position + Vector2(9.0, 9.0), 2.6, Color(1.0, 0.25, 0.25, (0.5 + 0.5 * blink) * f))
	draw_string(hud, r.position + Vector2(15.0, 12.0), tr("CLIP_TAG"), HORIZONTAL_ALIGNMENT_LEFT, -1, 7, Color(1, 1, 1, 0.8 * f))
	# Rücklicht-Anzeige: Hülle, wenn das Demo Schaden zeigt
	if bool(demo.data.get("show_hull", false)):
		var hx := r.end.x - 86.0
		var hy := r.position.y + 6.0
		draw_rect(Rect2(hx - 1.0, hy - 1.0, 72.0, 10.0), Color("#10142b"))
		draw_rect(Rect2(hx, hy, 70.0, 8.0), Color("#232a52"))
		var hf := clampf(demo.run.sim.hull / Tuning.HULL_MAX, 0.0, 1.0)
		draw_rect(Rect2(hx, hy, 70.0 * hf, 8.0), Color("#5dff9a") if hf > 0.35 else Color("#ff4d6d"))
		draw_string(hud, Vector2(hx + 2.0, hy + 7.0), tr("HUD_HULL"), HORIZONTAL_ALIGNMENT_LEFT, -1, 7, Color.WHITE)
	# Zeilenraster über dem Bild (leichter Videoeffekt)
	for i in int(r.size.y / 3.0):
		draw_rect(Rect2(r.position.x, r.position.y + float(i) * 3.0, r.size.x, 1.0), Color(0, 0, 0, 0.07 * f))
	# Untertitel
	if Settings.values.subtitles and text != "":
		var lines := _wrap(Fonts.ui, text, r.size.x - 18.0, 9)
		var h := 8.0 + float(lines.size()) * 11.0
		var y := r.end.y + 12.0
		draw_rect(Rect2(r.position.x, y, r.size.x, h), Color(0.04, 0.06, 0.16, 0.9 * f))
		draw_rect(Rect2(r.position.x, y, r.size.x, 1.0), Color(1.0, 0.88, 0.58, 0.55 * f))
		for i in lines.size():
			draw_string(Fonts.ui, Vector2(r.position.x + 9.0, y + 12.0 + float(i) * 11.0), lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(0.95, 0.97, 1.0, f))
	draw_string(hud, Vector2(r.end.x - 120.0, r.position.y - 13.0), tr("CLIP_SKIP"), HORIZONTAL_ALIGNMENT_RIGHT, 120.0, 7, Color(0.7, 0.75, 1.0, 0.8 * f))

func _wrap(f: Font, txt: String, width: float, fs: int) -> Array:
	var out: Array = []
	var line := ""
	for word in txt.split(" "):
		var cand := word if line == "" else line + " " + word
		if f.get_string_size(cand, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > width and line != "":
			out.append(line)
			line = word
		else:
			line = cand
	if line != "":
		out.append(line)
	return out
