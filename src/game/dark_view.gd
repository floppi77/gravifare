extends Control
## Dunkelheit (Sektor 8): ein Vollbild-Shader dunkelt das Spielfeld ab und lässt Lichtkegel frei – um das Taxi, an Plattformen, am Tor
## und an leuchtenden Gefahren (Fahrzeuge, Meteoriten, Strahlen, Lavablasen).

const MAX_LIGHTS := 32

var run: Run
var cam: Camera2D
var rect: ColorRect
var mat: ShaderMaterial

const SHADER := """
shader_type canvas_item;
uniform vec2 size = vec2(640.0, 360.0);
uniform float dark = 0.8;
uniform vec3 lights[32];
uniform int n = 0;
void fragment() {
	vec2 p = UV * size;
	float lit = 0.0;
	for (int i = 0; i < 32; i++) {
		if (i >= n) { break; }
		vec3 l = lights[i];
		float d = length(p - l.xy);
		lit = max(lit, 1.0 - smoothstep(l.z * 0.3, l.z, d));
	}
	float a = dark * (1.0 - lit);
	COLOR = vec4(vec3(0.01, 0.0, 0.06), a);
}
"""

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rect = ColorRect.new()
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var sh := Shader.new()
	sh.code = SHADER
	mat = ShaderMaterial.new()
	mat.shader = sh
	rect.material = mat
	add_child(rect)
	visible = false

func setup(r: Run, c: Camera2D) -> void:
	run = r
	cam = c
	visible = r.level.dark > 0.0
	if visible:
		mat.set_shader_parameter("dark", r.level.dark)

func _screen(world: Vector2) -> Vector2:
	var half := get_viewport_rect().size * 0.5
	var center := cam.get_screen_center_position() if cam != null else half
	return world - center + half

func _process(_d: float) -> void:
	if run == null or not visible:
		return
	var lv := run.level
	mat.set_shader_parameter("size", get_viewport_rect().size)
	var lights := PackedVector3Array()
	var tp := _screen(run.sim.pos)
	lights.append(Vector3(tp.x, tp.y, 72.0 + 3.0 * sin(Time.get_ticks_msec() * 0.011)))
	for id in lv.pads:
		var p: Dictionary = lv.pads[id]
		var c := _screen(Vector2(float(p.center), float(p.row) * Tuning.TILE - 8.0))
		lights.append(Vector3(c.x, c.y, 38.0))
		var shl: Rect2 = p.get("shelter", Rect2())
		if shl.size.x > 0.0:                                        # Ampellampe auf dem Dach bleibt auch im Dunkeln sichtbar
			var lc := _screen(Vector2(shl.get_center().x, shl.position.y - 5.5))
			lights.append(Vector3(lc.x, lc.y, 16.0))
	var ex := _screen(lv.exit_rect().get_center())
	lights.append(Vector3(ex.x, ex.y, 54.0 if run.exit_open else 30.0))
	for m in lv.movers:
		if lights.size() >= MAX_LIGHTS - 2:
			break
		var r: Rect2 = m.rect
		if r.position.x < -500.0 or m.kind == "pad":
			continue
		if m.kind == "vehicle":
			var c := _screen(r.get_center())
			lights.append(Vector3(c.x, c.y, 24.0))
		elif m.kind == "meteor" or m.kind == "debris":
			var c := _screen(r.get_center())
			lights.append(Vector3(c.x, c.y, 24.0 if m.kind == "meteor" else 16.0))
		elif m.kind == "beam":
			var c := _screen(r.get_center())
			lights.append(Vector3(c.x, c.y, maxf(r.size.x, r.size.y) * 0.55 + 12.0))
	for z in lv.zones:
		if lights.size() >= MAX_LIGHTS - 1:
			break
		if z.kind == "heat" and lv.zone_active(z, run.sim.time):
			var c := _screen((z.rect as Rect2).get_center())
			lights.append(Vector3(c.x, c.y, 46.0))
	var padded := PackedVector3Array(lights)
	var n := padded.size()
	while padded.size() < MAX_LIGHTS:
		padded.append(Vector3.ZERO)
	mat.set_shader_parameter("lights", padded)
	mat.set_shader_parameter("n", n)
