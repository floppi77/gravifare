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
var hull_gauge := HudGauges.new()      # Hüllenanzeige wie im HUD (Demos, die Schaden zeigen)
var over: Control

func start(g: Node, k: String) -> bool:
	game = g
	key = k
	demo = IntroDemo.new()
	if not demo.setup(k):
		return false
	var grun = g.get("run")                            # Bildsprache des Sektors, in dem der Einspieler läuft (Physik und Regeln des Demos bleiben)
	if grun != null and grun.level != null and not grun.level.tutorial:
		demo.level.look_sector = grun.level.look()
	set_anchors_preset(Control.PRESET_TOP_LEFT)       # feste 640×360-Fläche; die CanvasLayer verschiebt sie in die Mitte (siehe game.gd)
	size = VIEW
	mouse_filter = Control.MOUSE_FILTER_STOP
	var lang := TranslationServer.get_locale().substr(0, 2)
	var tt: Dictionary = demo.data.get("title", {})
	title = Loc.pick(tt, lang, k)
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
	var bgl := CanvasLayer.new()
	bgl.layer = -5
	bgl.follow_viewport_enabled = false
	sv.add_child(bgl)
	var bg := Control.new()                                     # Hintergrundbild des Sektors wie im Spiel (vorher ein leerer Farbverlauf)
	bg.set_script(load("res://src/game/backdrop.gd"))
	bg.size = VIEW
	bgl.add_child(bg)
	bg.setup(demo.level)
	var veil := ColorRect.new()                                 # leichter Schleier: Taxi und Vorführung bleiben vor hellen Bildern klar
	veil.size = VIEW
	veil.color = Color(0.02, 0.03, 0.1, 0.28)
	bgl.add_child(veil)
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
	over = Control.new()                 # liegt über dem Bild der Demo: was hier in _draw() steht, verdeckt das Bild sonst
	over.mouse_filter = Control.MOUSE_FILTER_IGNORE
	over.draw.connect(_draw_over)
	add_child(over)

func _input(event: InputEvent) -> void:
	if closing:
		return
	if event.is_action_pressed("ui_accept") or event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause") \
			or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
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
	if demo != null and demo.run != null:
		hull_gauge.update(delta, 1.0, demo.run.sim.hull / Tuning.HULL_MAX)
	queue_redraw()
	if over != null:
		over.queue_redraw()

## Über dem Bild der Demo: die Hüllenanzeige (dieselbe wie im HUD), wenn die Demo Schaden zeigt.
func _draw_over() -> void:
	if fade > 0.6 and demo != null and bool(demo.data.get("show_hull", false)):
		hull_gauge.draw_hull(over, Vector2(SCREEN.end.x - 74.0, SCREEN.position.y + 5.0), demo.run.sim.hull / Tuning.HULL_MAX)

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
	# Zeilenraster über dem Bild (leichter Videoeffekt)
	for i in int(r.size.y / 3.0):
		draw_rect(Rect2(r.position.x, r.position.y + float(i) * 3.0, r.size.x, 1.0), Color(0, 0, 0, 0.07 * f))
	# Untertitel
	if Settings.values.subtitles and text != "":
		var sfs := Settings.fs(9)                           # Option „Große Schrift“
		var lh := 11.0 * Settings.text_k()
		var lines := _wrap(Fonts.ui, text, r.size.x - 18.0, sfs)
		var h := 8.0 + float(lines.size()) * lh
		var y := minf(r.end.y + 12.0, VIEW.y - 3.0 - h)         # viele Zeilen (große Schrift): Kasten rückt ins Bild, statt unten abgeschnitten zu werden
		draw_rect(Rect2(-mg.x, y - 4.0, get_viewport_rect().size.x, VIEW.y + mg.y - y + 4.0), Color(0.01, 0.01, 0.05, f))      # Auftragszeile des HUD ganz abdecken statt halb durchscheinen
		draw_rect(Rect2(r.position.x, y, r.size.x, h), Color(0.04, 0.06, 0.16, 0.9 * f))
		draw_rect(Rect2(r.position.x, y, r.size.x, 1.0), Color(1.0, 0.88, 0.58, 0.55 * f))
		for i in lines.size():
			draw_string(Fonts.ui, Vector2(r.position.x + 9.0, y + 1.0 + lh * float(i + 1)), lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1, sfs, Color(0.95, 0.97, 1.0, f))
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
