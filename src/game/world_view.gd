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
	ct.normal_texture = SectorLook.tiles_normal(level.sector)
	tiles_tex = ct
	queue_redraw()

func _process(_delta: float) -> void:
	# Tore ändern die Kollisionsfläche nicht optisch; Tiles sind statisch und werden nur bei Bedarf neu gezeichnet
	pass

func _hash(x: int, y: int) -> int:
	return int(absi((x * 73856093) ^ (y * 19349663))) % 4

func _tile(idx: int, cx: int, cy: int, row := 0) -> void:
	draw_texture_rect_region(tiles_tex, Rect2(cx * T, cy * T, T, T), Rect2(idx * 48, row * 48, 48, 48))

## Fels nach Nachbarschaft (Runde 63, Atlas aus tools/art/gen_sector_tiles.py): Randkachel je Maske der offenen Nachbarn (1 oben, 2 rechts, 4 unten,
## 8 links, Zeile 1), Innenecken als Auflage (Zeile 2), sonst Innenfläche mit Abwandlung (tief im Fels häufiger mit Merkmalen).
func _rock_tile(cx: int, cy: int) -> void:
	var m := 0
	if not level.is_solid_cell(cx, cy - 1): m |= 1
	if not level.is_solid_cell(cx + 1, cy): m |= 2
	if not level.is_solid_cell(cx, cy + 1): m |= 4
	if not level.is_solid_cell(cx - 1, cy): m |= 8
	if m != 0:
		_tile(m, cx, cy, 1)
	elif _deep(cx, cy):
		var h := int(absi((cx * 83492791) ^ (cy * 2654435761)) >> 4)
		_tile([7, 8, 9, 7, 10, 11, 12, 13, 14, 15, 8, 9][h % 12], cx, cy)
	else:
		_tile(_hash(cx, cy), cx, cy)
	var k := 0
	for d in [Vector2i(1, -1), Vector2i(1, 1), Vector2i(-1, 1), Vector2i(-1, -1)]:
		if not level.is_solid_cell(cx + d.x, cy + d.y) and level.is_solid_cell(cx + d.x, cy) and level.is_solid_cell(cx, cy + d.y):
			_tile(k, cx, cy, 2)
		k += 1

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
	# Pass 1: Schlagschatten der Felsmasse auf den Hintergrund, nach rechts unten versetzt und in drei Stufen weich auslaufend
	var sh_far := Color(0.01, 0.015, 0.03, 0.14)
	var sh_mid := Color(0.01, 0.015, 0.03, 0.22)
	var sh := Color(0.01, 0.015, 0.03, 0.45)
	for cy in level.height:
		for cx in level.width:
			if level.is_solid_cell(cx, cy) and (not level.is_solid_cell(cx + 1, cy) or not level.is_solid_cell(cx, cy + 1) or not level.is_solid_cell(cx + 1, cy + 1)):
				draw_rect(Rect2(cx * T + 7.0, cy * T + 10.0, T, T), sh_far)
				draw_rect(Rect2(cx * T + 4.5, cy * T + 6.5, T, T), sh_mid)
				draw_rect(Rect2(cx * T + 2.0, cy * T + 3.0, T, T), sh)
	for cy in level.height:
		for cx in level.width:
			var c := level.cell(cx, cy)
			if c == "#":
				_rock_tile(cx, cy)                     # Kontur, Fasen und Ecken stecken in den Randkacheln
				var x := cx * T
				var y := cy * T
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
	_draw_soft_edge()
	WorldDecor.draw(self, level)

## Weicher Rand für Ultrawide (Runde 63): Links und rechts außerhalb des Levels (bei 21:9 und 32:9 sichtbar, bei 16:9 außerhalb des Bildes) läuft der
## Randfels über SOFT_EDGE Kacheln aus, wird dunkler und durchsichtiger und geht ins Hintergrundbild über, statt hart an der 16:9-Kante zu enden.
## Nur Darstellung: Kollision und Kamera bleiben, wie sie sind.
const SOFT_EDGE := 5
func _draw_soft_edge() -> void:
	var shade: Color = look.shade
	for side in [-1, 1]:
		for k in range(1, SOFT_EDGE + 1):
			var cx: int = -k if side < 0 else level.width - 1 + k
			var edge_x: int = 0 if side < 0 else level.width - 1
			var a := pow(1.0 - float(k - 1) / float(SOFT_EDGE), 1.6)
			var dim := lerpf(0.82, 0.45, float(k - 1) / float(SOFT_EDGE - 1))
			for cy in level.height:
				if not level.is_solid_cell(edge_x, cy):
					continue                          # Öffnungen in der Außenwand (Verkehr) bleiben offen
				var h := int(absi((cx * 83492791) ^ (cy * 2654435761)) >> 4)
				draw_texture_rect_region(tiles_tex, Rect2(cx * T, cy * T, T, T), Rect2([7, 8, 9, 10, 11][h % 5] * 48, 0, 48, 48), Color(dim, dim, dim * 1.05, a))
			draw_rect(Rect2(cx * T, 0, T, level.height * T), Color(shade.r, shade.g, shade.b, (1.0 - a) * 0.35))
