class_name LevelPreview
extends Control
## Vorschaubild eines Levels (assets/art/levels/<id>.jpg, erzeugt mit tools/make_level_shots.sh).
## Noch nicht geschaffte Level bleiben unscharf.

const BLUR_CODE := "shader_type canvas_item;\nuniform float amount = 0.0;\nvoid fragment() {\n\tvec4 c = vec4(0.0);\n\tfloat n = 0.0;\n\tfor (int x = -3; x <= 3; x++) {\n\t\tfor (int y = -3; y <= 3; y++) {\n\t\t\tc += texture(TEXTURE, UV + vec2(float(x), float(y)) * amount);\n\t\t\tn += 1.0;\n\t\t}\n\t}\n\tCOLOR = c / n;\n}\n"
var view: TextureRect
var unknown: Label

func _ready() -> void:
	view = TextureRect.new()
	view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	view.stretch_mode = TextureRect.STRETCH_SCALE
	view.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var sh := Shader.new()
	sh.code = BLUR_CODE
	view.material = ShaderMaterial.new()
	view.material.shader = sh
	add_child(view)
	unknown = MenuKit.title(tr("LVL_UNKNOWN"), 14)
	unknown.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	unknown.grow_horizontal = Control.GROW_DIRECTION_BOTH
	unknown.grow_vertical = Control.GROW_DIRECTION_BOTH
	add_child(unknown)

func show_level(id: String, known: bool) -> void:
	var p := "res://assets/art/levels/%s.jpg" % id
	view.texture = load(p) if ResourceLoader.exists(p) else null
	view.material.set_shader_parameter("amount", 0.0 if known else 0.012)
	view.modulate = Color.WHITE if known else Color(0.7, 0.72, 0.85)
	unknown.visible = not known

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.03, 0.04, 0.1, 0.88))
	draw_rect(Rect2(Vector2.ZERO, size).grow(1.0), Color("#3a4580"), false, 1.0)
