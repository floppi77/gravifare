class_name SlotCard
extends Button
## Ein Spielstand als Diskette auf einer abgerundeten Karte: Das Etikett trägt den Namen (sonst die Nummer), darunter stehen Fortschritt,
## Spielzeit und Punkte. Der Fokus hebt die Diskette an und legt einen goldenen Rahmen um die Karte.

const COLORS := [Color("#3fd0f0"), Color("#ff6fb5"), Color("#ffc23e")]
const SIZE := Vector2(150, 176)
var tex: Texture2D
var slot := 1
var info := {}
var current := false
var lift := 0.0
var t := 0.0
var _boxes := {}

func setup(n: int, summary: Dictionary, is_current: bool) -> void:
	slot = n
	info = summary
	current = is_current
	tex = load("res://assets/art/floppy_%d.png" % n)
	custom_minimum_size = SIZE
	focus_mode = Control.FOCUS_ALL
	var none := StyleBoxEmpty.new()
	for st in ["normal", "hover", "pressed", "focus", "disabled"]:
		add_theme_stylebox_override(st, none)
	mouse_entered.connect(grab_focus)

func _process(delta: float) -> void:
	t += delta
	lift = move_toward(lift, 5.0 if has_focus() else 0.0, delta * 40.0)
	queue_redraw()

## Abgerundetes Feld, die Stile werden zwischengespeichert.
func _rbox(r: Rect2, bg: Color, radius: int, border := Color(0, 0, 0, 0), bw := 0) -> void:
	var key := "%s|%s|%d|%d" % [bg.to_html(true), border.to_html(true), radius, bw]
	var sb: StyleBoxFlat = _boxes.get(key)
	if sb == null:
		sb = StyleBoxFlat.new()
		sb.bg_color = bg
		sb.set_corner_radius_all(radius)
		if bw > 0:
			sb.border_color = border
			sb.set_border_width_all(bw)
		sb.anti_aliasing = true
		_boxes[key] = sb
	draw_style_box(sb, r)

## Text in `width` Pixeln: die Schrift schrumpft bis 6 px, damit lange Namen passen.
func _fit(f: Font, pos: Vector2, text: String, width: float, fs: int, col: Color) -> void:
	var sz := fs
	while sz > 7 and f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, sz).x > width:
		sz -= 1
	while text.length() > 3 and f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, sz).x > width:
		text = text.left(text.length() - 2) + "…" if not text.ends_with("…") else text.left(text.length() - 2) + "…"
	draw_string(f, pos, text, HORIZONTAL_ALIGNMENT_CENTER, width, sz, col)

func _draw() -> void:
	var col: Color = COLORS[slot - 1]
	var r := Rect2(Vector2.ZERO, size)
	var focused := has_focus()
	var used: bool = info.exists
	if focused:
		_rbox(r.grow(3.0), Color(1.0, 0.88, 0.29, 0.16), 14)
	_rbox(r, Color(0.05, 0.07, 0.18, 0.9 if focused else 0.7), 11, Color("#ffe14a") if focused else Color(col.r, col.g, col.b, 0.5), 2 if focused else 1)
	_rbox(Rect2(1, 1, size.x - 2, 5), Color(col.r, col.g, col.b, 0.9 if used else 0.35), 4)            # Farbband oben
	var bob := sin(t * 2.4) * 1.0 if focused else 0.0
	var d := Rect2(31, 14.0 - lift + bob, 88, 88)
	draw_rect(Rect2(d.position + Vector2(5, 88.0 + lift * 0.5 - bob), Vector2(78, 3)), Color(0, 0, 0, 0.3))
	draw_texture_rect(tex, d, false, Color.WHITE if used else Color(0.62, 0.66, 0.8, 0.8))
	var nm := String(info.get("name", ""))
	var label := nm if nm != "" else (tr("SLOT_DISK") % slot if used else tr("SLOT_FREE"))
	_fit(Fonts.hud, d.position + Vector2(10, 61), label, 68.0, 9, Color("#1a2040"))
	var y := 120.0
	var font := Fonts.ui
	if not used:
		_rbox(Rect2(25, y + 4.0, size.x - 50.0, 24), Color(1.0, 0.88, 0.29, 0.18 if focused else 0.08), 8, Color(1.0, 0.88, 0.29, 0.55 if focused else 0.25), 1)
		draw_string(Fonts.hud, Vector2(0, y + 20.0), "+ " + tr("SLOT_NEW"), HORIZONTAL_ALIGNMENT_CENTER, size.x, 11, Color("#ffe14a") if focused else Color("#c9cfee"))
		return
	_fit(Fonts.hud, Vector2(5, y), nm if nm != "" else tr("SLOT_DISK") % slot, size.x - 10.0, 12, Color.WHITE)
	var levels: int = info.levels
	var bar := Rect2(18, y + 7.0, size.x - 36.0, 6)
	_rbox(bar, Color("#232a52"), 3)
	if levels > 0:
		_rbox(Rect2(bar.position, Vector2(maxf(bar.size.x * clampf(float(levels) / 99.0, 0.0, 1.0), 6.0), bar.size.y)), col, 3)
	draw_string(font, Vector2(0, y + 24.0), tr("SLOT_LEVELS") % levels, HORIZONTAL_ALIGNMENT_CENTER, size.x, 10, Color("#e6ebff"))
	var secs: int = info.seconds
	draw_string(font, Vector2(0, y + 36.0), tr("SLOT_TIME") % ("%d:%02d h" % [secs / 3600, (secs % 3600) / 60]), HORIZONTAL_ALIGNMENT_CENTER, size.x, 9, Color("#a9b3e8"))
	draw_string(font, Vector2(0, y + 47.0), tr("SLOT_SCORE") % info.score, HORIZONTAL_ALIGNMENT_CENTER, size.x, 9, Color("#ffe14a"))
	if current:
		_rbox(Rect2(size.x - 44.0, 9.0, 38, 12), Color(col.r, col.g, col.b, 0.95), 6)
		draw_string(Fonts.hud, Vector2(size.x - 44.0, 18.0), tr("SLOT_ACTIVE"), HORIZONTAL_ALIGNMENT_CENTER, 38, 7, Color("#10142b"))
