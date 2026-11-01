extends Node2D
## Zeichnet das statische Level aus dem Tile-Atlas (Texturen in 3-facher Detailauflösung),
## Pads mit Signalbaken, das Ausgangstor, Fahrgäste und Zielmarker.

const T := Tuning.TILE
const PX := 1.0 / 3.0                 # ein Bildschirmpixel bei 1080p in Welteinheiten

var level: LevelData
var run: Run
var tiles_tex: Texture2D
var look := SectorLook.of(1)

func _ready() -> void:
	pass

func setup(r: Run) -> void:
	run = r
	level = r.level
	look = SectorLook.of(level.sector)
	var ct := CanvasTexture.new()
	ct.diffuse_texture = SectorLook.tiles(level.sector)
	ct.normal_texture = load("res://assets/art/tiles_s1_n.png")
	tiles_tex = ct
	queue_redraw()

func _process(_delta: float) -> void:
	# Tore ändern die Kollisionsfläche nicht optisch; Tiles sind statisch und werden nur bei Bedarf neu gezeichnet
	pass

func _hash(x: int, y: int) -> int:
	return int(absi((x * 73856093) ^ (y * 19349663))) % 4

func _tile(idx: int, cx: int, cy: int) -> void:
	draw_texture_rect_region(tiles_tex, Rect2(cx * T, cy * T, T, T), Rect2(idx * 48, 0, 48, 48))

## Dornen zeigen von der tragenden Fläche weg: Fels darunter = nach oben, darüber = nach unten, seitlich = zur Seite.
func _spike_tile(cx: int, cy: int) -> void:
	var rot := 0.0
	if _base(cx, cy + 1):
		rot = 0.0
	elif _base(cx, cy - 1):
		rot = PI
	elif _base(cx - 1, cy):
		rot = PI * 0.5
	elif _base(cx + 1, cy):
		rot = -PI * 0.5
	draw_set_transform(Vector2((cx + 0.5) * T, (cy + 0.5) * T), rot)
	draw_texture_rect_region(tiles_tex, Rect2(-T * 0.5, -T * 0.5, T, T), Rect2(6 * 48, 0, 48, 48))
	draw_set_transform(Vector2.ZERO, 0.0)

func _base(cx: int, cy: int) -> bool:
	return level.is_solid_cell(cx, cy) and level.cell(cx, cy) != "^"

func _deep(cx: int, cy: int) -> bool:
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			if not level.is_solid_cell(cx + dx, cy + dy):
				return false
	return true

func _draw() -> void:
	if level == null:
		return
	level.doors_ignore = true        # Tore werden dynamisch in props_view gezeichnet; hier gelten sie als offen
	_draw_world()
	level.doors_ignore = false

func _draw_world() -> void:
	var edge: Color = look.edge
	var edge_hi: Color = look.hi
	var shadow: Color = look.shade
	# Pass 1: weicher Schlagschatten der Felsmasse auf den Hintergrund (versetzt nach rechts unten)
	var sh := Color(0.01, 0.015, 0.03, 0.6)
	for cy in level.height:
		for cx in level.width:
			if level.is_solid_cell(cx, cy) and (not level.is_solid_cell(cx + 1, cy) or not level.is_solid_cell(cx, cy + 1) or not level.is_solid_cell(cx + 1, cy + 1)):
				draw_rect(Rect2(cx * T + 2.0, cy * T + 3.0, T, T), sh)
	for cy in level.height:
		for cx in level.width:
			var c := level.cell(cx, cy)
			if c == "#":
				_tile(7 + _hash(cx, cy) % 3 if _deep(cx, cy) else _hash(cx, cy), cx, cy)
				var x := cx * T
				var y := cy * T
				if not level.is_solid_cell(cx, cy - 1):
					draw_rect(Rect2(x, y, T, PX * 2), edge_hi)
					draw_rect(Rect2(x, y + PX * 2, T, PX), edge)
				if not level.is_solid_cell(cx - 1, cy):
					draw_rect(Rect2(x, y, PX * 2, T), edge)
				if not level.is_solid_cell(cx + 1, cy):
					draw_rect(Rect2(x + T - PX * 2, y, PX * 2, T), shadow)
				if not level.is_solid_cell(cx, cy + 1):
					draw_rect(Rect2(x, y + T - PX * 2, T, PX * 2), shadow)
				# Ambient Occlusion: abgestufte Abdunklung an Kanten zu offenen Nachbarn (innen)
				for k in 3:
					var ao := Color(0.02, 0.02, 0.1, 0.22 - k * 0.07)
					var d := PX * (3 + k * 2) + PX * 2
					if not level.is_solid_cell(cx + 1, cy):
						draw_rect(Rect2(x + T - d - PX * 2, y, PX * 2, T), ao)
					if not level.is_solid_cell(cx, cy + 1):
						draw_rect(Rect2(x, y + T - d - PX * 2, T, PX * 2), ao)
			elif c == "^":
				_spike_tile(cx, cy)
			elif c == "F" or c == "L":
				_tile(5, cx, cy)
			elif (c >= "1" and c <= "9") or c == "H":
				_tile(4, cx, cy)
