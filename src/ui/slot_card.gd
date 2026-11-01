class_name SlotCard
extends Button
## Ein Spielstand als Diskette: Das Etikett trägt die Nummer, darunter stehen Fortschritt und Spielzeit. Der Fokus hebt die Diskette an.

const COLORS := [Color("#3fd0f0"), Color("#ff6fb5"), Color("#ffc23e")]
var tex: Texture2D
var slot := 1
var info := {}
var current := false
var lift := 0.0
var t := 0.0

func setup(n: int, summary: Dictionary, is_current: bool) -> void:
	slot = n
	info = summary
	current = is_current
	tex = load("res://assets/art/floppy_%d.png" % n)
	custom_minimum_size = Vector2(150, 176)
	focus_mode = Control.FOCUS_ALL
	var none := StyleBoxEmpty.new()
	for st in ["normal", "hover", "pressed", "focus", "disabled"]:
		add_theme_stylebox_override(st, none)
	mouse_entered.connect(grab_focus)

func _process(delta: float) -> void:
	t += delta
	lift = move_toward(lift, 5.0 if has_focus() else 0.0, delta * 40.0)
	queue_redraw()

func _draw() -> void:
	var col: Color = COLORS[slot - 1]
	var r := Rect2(Vector2.ZERO, size)
	var focused := has_focus()
	draw_rect(r, Color(0.04, 0.05, 0.14, 0.82 if focused else 0.62))
	draw_rect(r, Color("#ffe14a") if focused else Color(col.r, col.g, col.b, 0.45), false, 1.5 if focused else 1.0)
	var bob := sin(t * 2.4) * 1.0 if focused else 0.0
	var d := Rect2(27, 12.0 - lift + bob, 96, 96)
	var used: bool = info.exists
	draw_rect(Rect2(d.position + Vector2(3, 96.0 + lift * 0.5 - bob), Vector2(90, 3)), Color(0, 0, 0, 0.35))
	draw_texture_rect(tex, d, false, Color.WHITE if used else Color(0.62, 0.66, 0.8, 0.8))
	var label := tr("SLOT_DISK") % slot if used else tr("SLOT_FREE")
	draw_string(Fonts.hud, d.position + Vector2(14, 67), label, HORIZONTAL_ALIGNMENT_CENTER, 68, 8, Color("#1a2040"))
	var y := 122.0
	var font := Fonts.ui
	if not used:
		draw_string(Fonts.hud, Vector2(0, y + 16.0), tr("SLOT_NEW"), HORIZONTAL_ALIGNMENT_CENTER, size.x, 12, Color("#ffe14a") if focused else Color("#c9cfee"))
		return
	var levels: int = info.levels
	draw_string(Fonts.hud, Vector2(0, y), tr("SLOT_LEVELS") % levels, HORIZONTAL_ALIGNMENT_CENTER, size.x, 11, Color.WHITE)
	var bar := Rect2(20, y + 5.0, size.x - 40.0, 4.0)
	draw_rect(bar, Color("#232a52"))
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * clampf(float(levels) / 99.0, 0.0, 1.0), bar.size.y)), col)
	var secs: int = info.seconds
	draw_string(font, Vector2(0, y + 22.0), tr("SLOT_TIME") % ("%d:%02d h" % [secs / 3600, (secs % 3600) / 60]), HORIZONTAL_ALIGNMENT_CENTER, size.x, 9, Color("#c9cfee"))
	draw_string(font, Vector2(0, y + 34.0), tr("SLOT_SCORE") % info.score, HORIZONTAL_ALIGNMENT_CENTER, size.x, 9, Color("#ffe14a"))
	if current:
		draw_string(Fonts.hud, Vector2(0, size.y - 3.0), "◄ ►", HORIZONTAL_ALIGNMENT_CENTER, size.x, 7, Color(col.r, col.g, col.b, 0.9))
