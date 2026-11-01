extends Control
## Hintergrund je Sektor. Bevorzugt ein ganzes Bild bg_sN.png (1920×1080, leicht vergrößert mit schwachem Parallax und
## abgedunkelt, damit Plattformen und Fahrgäste lesbar bleiben); fehlt es, greift der Dreiebenen-Aufbau bg_sN_far/mid/near.png.

## Abdunklung je Sektor (0 = Originalbild, 1 = schwarz): helle Bilder brauchen mehr, damit Cyan/Orange/Gelb lesbar bleibt.
const DIM := {1: 0.30, 2: 0.46, 3: 0.30, 4: 0.30, 5: 0.22, 6: 0.22, 7: 0.58, 8: 0.30, 9: 0.12}
const TONE_CODE := "shader_type canvas_item;\nuniform float sat = 1.0;\nuniform float con = 1.0;\nuniform vec3 fog = vec3(0.0);\nuniform float amt = 0.0;\nvoid fragment() {\n\tvec4 t = texture(TEXTURE, UV) * COLOR;\n\tvec3 c = t.rgb;\n\tfloat g = dot(c, vec3(0.3, 0.59, 0.11));\n\tc = mix(vec3(g), c, sat);\n\tc = mix(vec3(0.5), c, con);\n\tCOLOR = vec4(mix(c, fog, amt), t.a);\n}\n"
const ZOOM := 1.06             # Bild etwas größer als der Schirm, damit der Parallax keine Ränder zeigt
const PARALLAX := 0.05

var far: Texture2D = preload("res://assets/art/bg_s1_far.png")
var mid: Texture2D = preload("res://assets/art/bg_s1_mid.png")
var near: Texture2D = preload("res://assets/art/bg_s1_near.png")
var cam_ref: Camera2D
var lvl: LevelData
var full_img: Texture2D
var dim := 0.3

func setup(l: LevelData) -> void:
	lvl = l
	var n := l.sector
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--bg="):         # Dev: Hintergrund eines anderen Sektors ansehen
			n = int(a.substr(5))
	var fp := "res://assets/art/bg_s%d.png" % n
	full_img = load(fp) if ResourceLoader.exists(fp) else null
	var lk := SectorLook.of(n)
	dim = float(DIM.get(n, 0.3)) * 0.55                 # der Tonwert (Shader unten) übernimmt einen Teil der Abdunklung
	if material == null:
		var sh := Shader.new()
		sh.code = TONE_CODE
		material = ShaderMaterial.new()
		material.shader = sh
		texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR     # das Bild wird nicht ganzzahlig skaliert: weich statt ungleichmäßiger Pixel, tritt zugleich zurück
	var fog: Color = lk.fog
	material.set_shader_parameter("sat", lk.sat)
	material.set_shader_parameter("con", lk.con)
	material.set_shader_parameter("fog", Vector3(fog.r, fog.g, fog.b))
	material.set_shader_parameter("amt", lk.amt)
	far = _tex(n, "far")
	mid = _tex(n, "mid")
	near = _tex(n, "near")

func _tex(n: int, layer: String) -> Texture2D:
	var p := "res://assets/art/bg_s%d_%s.png" % [n, layer]
	if not ResourceLoader.exists(p):
		p = "res://assets/art/bg_s1_%s.png" % layer
	return load(p)

func _process(_d: float) -> void:
	queue_redraw()

func _draw() -> void:
	var vs := get_viewport_rect().size
	var full := Rect2(0, 0, vs.x, vs.y)
	var cam := get_viewport().get_camera_2d()
	var off := Vector2.ZERO
	if cam != null and lvl != null:
		off = cam.get_screen_center_position() - Vector2(320, 180)
	if full_img != null:
		var cover := maxf(vs.x / 640.0, vs.y / 360.0)           # Ultrawide/hohe Fenster: Bild füllt die ganze Fläche (Zuschnitt oben/unten bzw. seitlich)
		var w := 640.0 * ZOOM * cover
		var h := 360.0 * ZOOM * cover
		var x := -(w - vs.x) * 0.5 - roundf(off.x * PARALLAX * 3.0) / 3.0
		var y := -(h - vs.y) * 0.5 - roundf(off.y * PARALLAX * 3.0) / 3.0
		draw_texture_rect(full_img, Rect2(x, y, w, h), false, Color(1.0 - dim, 1.0 - dim, 1.0 - dim))
		return
	draw_texture_rect(far, full, false)
	_layer(mid, off, 0.08, 0.86)
	_haze(off)
	_layer(near, off, 0.18, 1.0)

func _layer(tex: Texture2D, off: Vector2, k: float, alpha: float) -> void:
	var x := -roundf(off.x * k * 3.0) / 3.0
	var y := -roundf(off.y * k * 3.0) / 3.0
	for i in [-1, 0, 1]:
		draw_texture_rect(tex, Rect2(x + i * 640.0, y, 640, 360), false, Color(1, 1, 1, alpha))

var _t := 0.0
## Atmosphärischer Dunst zwischen fernen und nahen Gebäuden (zwei driftende Bänder) – gibt Tiefe.
func _haze(off: Vector2) -> void:
	_t += get_process_delta_time()
	var drift := sin(_t * 0.12) * 14.0
	for band in [[205.0, 90.0, 0.30, 0.0], [255.0, 80.0, 0.22, 1.7]]:
		var y0: float = band[0] + float(band[3]) * 0.0
		var h: float = band[1]
		var a: float = band[2]
		var ox := drift * (1.0 if int(band[3]) == 0 else -0.7)
		var c0 := Color(0.45, 0.32, 0.65, 0.0)
		var c1 := Color(0.45, 0.32, 0.65, a)
		var pts := PackedVector2Array([Vector2(-20 + ox, y0), Vector2(660 + ox, y0), Vector2(660 + ox, y0 + h * 0.5), Vector2(-20 + ox, y0 + h * 0.5)])
		draw_polygon(pts, PackedColorArray([c0, c0, c1, c1]))
		var pts2 := PackedVector2Array([Vector2(-20 + ox, y0 + h * 0.5), Vector2(660 + ox, y0 + h * 0.5), Vector2(660 + ox, y0 + h), Vector2(-20 + ox, y0 + h)])
		draw_polygon(pts2, PackedColorArray([c1, c1, c0, c0]))
