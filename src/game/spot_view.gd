extends Control
## Tutorial-Beleuchtung: Das Bild wird abgedunkelt, bis zu drei Bereiche bleiben hell und bekommen einen weichen, warmen Lichtschein
## (kein Rahmen). Darunter der gesprochene Text als Untertitel-Tafel. Rechtecke liegen in logischen Pixeln (640×360).

var rect: ColorRect
var mat: ShaderMaterial
var amount := 0.0                 # aktuelle Abdunklung (0..1), folgt `want`
var want := 0.0
var fade_speed := 2.6             # Ein-/Ausblendtempo der Abdunklung (pro Sekunde)
var spots: Array = []             # aktuelle Bereiche (Rect2), höchstens 3
var clock := 0.0
var sub_text := ""
var sub_speaker := ""
var sub_a := 0.0                  # Einblendung der Tafel
var sub_want := 0.0
var hint := false                 # Hinweis rechts in der Tafel (Überspringen)

const SHADER := """
shader_type canvas_item;
uniform vec4 s0 = vec4(0.0);
uniform vec4 s1 = vec4(0.0);
uniform vec4 s2 = vec4(0.0);
uniform vec2 size = vec2(640.0, 360.0);
uniform float amount = 0.0;
uniform float t = 0.0;
float sd(vec2 p, vec4 r) {
	if (r.z <= 0.0) { return 1e5; }
	vec2 h = r.zw * 0.5;
	vec2 c = r.xy + h;
	float rad = min(7.0, min(h.x, h.y));
	vec2 q = abs(p - c) - h + rad;
	return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - rad;
}
void fragment() {
	vec2 p = UV * size;
	float d = min(sd(p, s0), min(sd(p, s1), sd(p, s2)));
	float lit = 1.0 - smoothstep(-1.0, 15.0, d);
	float a1 = 0.64 * (1.0 - lit) * amount;
	float pulse = 0.75 + 0.25 * sin(t * 2.6);
	float a2 = (0.07 * (1.0 - smoothstep(-6.0, 3.0, d)) + 0.16 * exp(-max(d, 0.0) / 7.0) * smoothstep(-8.0, 0.0, d + 6.0)) * pulse * amount;
	vec3 dark = vec3(0.01, 0.015, 0.07);
	vec3 warm = vec3(1.0, 0.88, 0.58);
	float a = a1 + a2 * (1.0 - a1);
	vec3 col = (dark * a1 + warm * a2 * (1.0 - a1)) / max(a, 0.0001);
	COLOR = vec4(col, a);
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

## Beleuchtete Bereiche setzen (leer = alles normal hell).
func set_spots(list: Array) -> void:
	spots = list.slice(0, 3)
	want = 1.0 if not spots.is_empty() else 0.0

func say(speaker: String, text: String) -> void:
	sub_speaker = speaker
	sub_text = text
	sub_want = 1.0 if text != "" and Settings.values.subtitles else 0.0

func _process(delta: float) -> void:
	clock += delta
	amount = move_toward(amount, want, delta * fade_speed)
	sub_a = move_toward(sub_a, sub_want, delta * 4.0)
	for i in 3:
		var r: Rect2 = spots[i] if i < spots.size() else Rect2()
		mat.set_shader_parameter("s%d" % i, Vector4(r.position.x, r.position.y, r.size.x, r.size.y))
	mat.set_shader_parameter("size", size)
	mat.set_shader_parameter("amount", amount)
	mat.set_shader_parameter("t", clock)
	queue_redraw()

func _draw() -> void:
	if sub_a <= 0.01 or sub_text == "":
		return
	var f := Fonts.ui
	var w := 540.0
	var fs := 9
	var lines := _wrap(f, sub_text, w - 16.0, fs)
	var h := 6.0 + float(lines.size()) * 11.0 + 8.0
	var x := size.x * 0.5 - w * 0.5
	var y := size.y * 0.5 + 154.0 - h          # 334 px auf der zentrierten 640×360-Fläche
	draw_rect(Rect2(x - 1.0, y - 1.0, w + 2.0, h + 2.0), Color(0.02, 0.03, 0.09, 0.55 * sub_a))
	draw_rect(Rect2(x, y, w, h), Color(0.04, 0.06, 0.16, 0.88 * sub_a))
	draw_rect(Rect2(x, y, w, 1.0), Color(1.0, 0.88, 0.58, 0.55 * sub_a))
	draw_string(Fonts.hud, Vector2(x + 8.0, y + 7.5), sub_speaker.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, 6, Color(1.0, 0.88, 0.58, sub_a))
	if hint:
		var key := "U" if Controls.last_device == "keyboard" else "B"
		draw_string(Fonts.hud, Vector2(x + w - 148.0, y + 7.5), tr("TUT_SKIP") % key, HORIZONTAL_ALIGNMENT_RIGHT, 140, 6, Color(0.75, 0.8, 1.0, 0.85 * sub_a))
	for i in lines.size():
		draw_string(f, Vector2(x + 8.0, y + 17.0 + float(i) * 11.0), lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0.95, 0.97, 1.0, sub_a))

## Einfacher Zeilenumbruch nach Pixelbreite.
func _wrap(f: Font, text: String, width: float, fs: int) -> Array:
	var out: Array = []
	var line := ""
	for word in text.split(" "):
		var cand := word if line == "" else line + " " + word
		if f.get_string_size(cand, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > width and line != "":
			out.append(line)
			line = word
		else:
			line = cand
	if line != "":
		out.append(line)
	return out
