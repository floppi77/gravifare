extends Node2D
## Vorschau des Level-Editors mit denselben Ansichten wie das Spiel (Fels, Pads, Wartebereiche, Ausgangstor, Tore, Hindernisse, Optik des Sektors):
## Was hier zu sehen ist, sieht man auch im Flug. Bewegliche Hindernisse laufen live mit. Der Start (S) ist als Taxi markiert.

const WorldView := preload("res://src/game/world_view.gd")
const PropsView := preload("res://src/game/props_view.gd")
const LevelStyle := preload("res://src/game/level_style.gd")

var tiles: Node2D
var props: Node2D
var style: Node2D
var lvl: LevelData
var run: Run
var clock := 0.0
var show_taxi := true

func _init() -> void:
	tiles = Node2D.new()
	tiles.set_script(WorldView)
	add_child(tiles)
	style = Node2D.new()
	style.set_script(LevelStyle)
	add_child(style)
	props = Node2D.new()
	props.set_script(PropsView)
	var unlit := CanvasItemMaterial.new()
	unlit.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	props.material = unlit
	add_child(props)

## Zeigt das Level (LevelData aus dem Modell, ohne Prüfung: das Modell hält Tor und Start fest).
## `rebuild_tiles` = false: nur Hindernisse, Zonen und Aufträge haben sich geändert. Die Felsschicht (die teuerste, rund 10 ms je Neuzeichnen bei vollem Level) bleibt dann stehen.
func show_level(l: LevelData, rebuild_tiles := true) -> void:
	lvl = l
	run = Run.new()
	run.start(l)
	if rebuild_tiles:
		tiles.setup(run)
		style.setup(l)
	props.setup(run)
	queue_redraw()

func _process(delta: float) -> void:
	if lvl == null:
		return
	clock += delta
	lvl.clock = clock
	lvl.update_movers(clock)          # Plattformen, Trümmer, Strahlen laufen wie im Spiel
	queue_redraw()

func _draw() -> void:
	if lvl == null or not show_taxi or lvl.spawn == Vector2.ZERO:
		return
	var tex: Texture2D = Cosmetics.paint_texture()
	var s := Tuning.TAXI_SCALE
	var tr_ := Tuning.taxi_rect(s)
	draw_texture_rect(tex, Rect2(lvl.spawn + tr_.position + Vector2(0, 2.0), tr_.size), false, Color(1, 1, 1, 0.9))
