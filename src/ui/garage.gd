extends Control
## Garage: Lackierung und Aufkleber wählen (nur Optik). Gesperrte Einträge zeigen ihre Freischaltbedingung.
## Fokus auf einem Eintrag zeigt eine Vorschau, bei gesperrten Teilen abgedunkelt mit Schloss; A/Enter legt ihn an. Neben jedem Eintrag
## steht ein Farbfeld bzw. der Aufkleber. „Nur Standardtaxi“ erzwingt den Challenge-Look.

class Preview extends Control:
	var paint := "std"
	var sticker := "none"
	var locked := false
	var t := 0.0
	func _process(d: float) -> void:
		t += d
		queue_redraw()
	func _draw() -> void:
		# Das Taxi füllt die leere Mitte: Größe aus der Textur (nie fest eingetragen), Vergrößerung in Schritten von 1/3 (ein Texturpunkt = ganze Bildschirmpunkte bei 1080p)
		var tex := Cosmetics.paint_texture(paint)
		var tsz: Vector2 = tex.get_size() if tex != null else Vector2(96.0, 60.0)
		var s := floorf(minf(size.x * 0.9 / tsz.x, size.y * 0.55 / tsz.y) * 3.0) / 3.0
		var hs := tsz * s * 0.5                                   # halbe Taxigröße in Einheiten
		var c := PixelDraw.snap2(Vector2(size.x * 0.5, size.y * 0.42 + sin(t * 1.8) * 2.5))
		var fy := size.y * 0.42 + hs.y - 1.0                    # Landefeld unter dem Taxi (bleibt stehen, nur das Taxi schwebt)
		PixelDraw.rect(self, Rect2(size.x * 0.5 - hs.x * 1.25, fy, hs.x * 2.5, 3.0), Color(0.2, 0.9, 0.85, 0.5))
		PixelDraw.rect(self, Rect2(size.x * 0.5 - hs.x, fy + 3.0, hs.x * 2.0, 2.0), Color(0.2, 0.9, 0.85, 0.2))
		var fl := 0.7 + 0.3 * sin(t * 40.0)
		var nz := c + Vector2(0.0, tsz.y * 0.28 * s)              # Düse: 28 % der Bildhöhe unter der Mitte (78×48: 13,4 Texel)
		PixelDraw.jet(self, nz, Vector2.DOWN, 12.0 * s * fl, 6.0 * s, Color("#ff8a2e"))
		PixelDraw.jet(self, nz, Vector2.DOWN, 12.0 * s * fl * 0.55, 3.0 * s, Color("#ffe14a"))
		var mod := Color(0.62, 0.64, 0.78) if locked else Color.WHITE
		if tex != null:
			draw_texture_rect(tex, Rect2(c - hs, hs * 2.0), false, mod)
		var st := Cosmetics.sticker_texture(sticker)
		if st != null:
			draw_texture_rect(st, Rect2(c + Vector2(-31.0, -10.0) * s, Vector2(20.0, 20.0) * s), false, mod)      # Aufkleberfeld des Taxis 78×48: Texel x 8, y 14, 20 groß
		if locked:          # Schloss: Vorschau eines noch gesperrten Teils
			var k := s / 0.8333
			var lc := c + Vector2(0.85 * hs.x, -0.8 * hs.y)
			draw_arc(lc + Vector2(0, -2) * k, 3.2 * k, PI, TAU, 10, Color("#c9cfee"), 1.6 * k)
			draw_rect(Rect2(lc.x - 5.0 * k, lc.y - 1.0 * k, 10.0 * k, 8.0 * k), Color("#ffcb3d"))
			draw_rect(Rect2(lc.x - 1.0 * k, lc.y + 1.5 * k, 2.0 * k, 3.0 * k), Color("#0c0f24"))

const Stage := preload("res://src/core/stage.gd")
var stage: Control                # zentrierte 640×360-Fläche (Ultrawide: Ränder zeigen nur den Hintergrund)
var preview: Preview
var info: Label
var buttons: Array = []
var lang := "de"

func _ready() -> void:
	Music.play_theme("menu")
	Music.set_layers(true, false)
	Music.duck(0.0)
	theme = MenuKit.make_theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	lang = TranslationServer.get_locale().substr(0, 2)
	var backdrop := Control.new()
	backdrop.set_script(load("res://src/ui/menu_backdrop.gd"))
	add_child(backdrop)
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.03, 0.1, 0.62)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	stage = Stage.make(self)
	stage.add_child(MenuKit.screen_panel())                  # Tafel wie hinter dem Hauptmenü
	var title := MenuKit.screen_title(tr("MENU_GARAGE"))
	title.set_anchors_preset(Control.PRESET_TOP_WIDE)
	title.offset_top = 4
	stage.add_child(title)
	preview = Preview.new()
	preview.position = Vector2(195, 40)                       # die leere Mitte zwischen den Spalten
	preview.size = Vector2(250, 235)
	preview.paint = Cosmetics.selected("paint")
	preview.sticker = Cosmetics.selected("sticker")
	stage.add_child(preview)
	_column("paint", 20.0, tr("GARAGE_PAINT"))
	_column("sticker", 450.0, tr("GARAGE_STICKER"))
	info = Label.new()
	info.position = Vector2(0, 280)
	info.size = Vector2(640, 14)
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info.add_theme_color_override("font_color", Color("#ffe14a"))
	stage.add_child(info)
	var back := MenuKit.button(tr("MENU_BACK"), func(): Flow.to_menu())
	back.position = Vector2(270, 324)
	back.custom_minimum_size = Vector2(100, 18)
	stage.add_child(back)
	await get_tree().process_frame
	for b in buttons:
		if b.get_meta("id") == Cosmetics.selected("paint"):
			b.grab_focus()

func _column(kind: String, x: float, head: String) -> void:
	var col := VBoxContainer.new()
	col.position = Vector2(x, 36)
	col.add_theme_constant_override("separation", 2)
	var h := Label.new()
	h.text = head
	h.add_theme_color_override("font_color", Color("#a9b8ff"))
	col.add_child(h)
	for it in Cosmetics.items:
		if it.kind != kind:
			continue
		var unlocked := Cosmetics.is_unlocked(it.id)
		var nm: String = it.name.get(lang, it.id)
		var b := Button.new()
		b.focus_mode = Control.FOCUS_ALL
		b.custom_minimum_size = Vector2(170, 18)
		b.set_meta("id", it.id)
		b.set_meta("label", nm if unlocked else "🔒 " + nm)
		b.set_meta("kind", kind)
		b.add_theme_font_size_override("font_size", 9)
		if not unlocked:
			b.add_theme_color_override("font_color", Color("#6a729c"))
		b.pressed.connect(func():
			if unlocked:
				Cosmetics.select(kind, it.id)
				Sfx.play("ui_ok")
				_mark()
				info.text = nm + "  ✔"
			else:
				Sfx.play("warn", -6.0))
		b.focus_entered.connect(func():
			Sfx.play("ui_move", -6.0)
			info.text = (Cosmetics.requirement_text(it) if not unlocked else (nm + "  ✔" if Cosmetics.selected(kind) == it.id else nm))
			# Vorschau zeigt das fokussierte Teil (gesperrte abgedunkelt mit Schloss), die andere Spalte bleibt wie gewählt
			preview.locked = not unlocked
			preview.paint = it.id if kind == "paint" else Cosmetics.selected("paint")
			preview.sticker = it.id if kind == "sticker" else Cosmetics.selected("sticker"))
		# Farbfeld der Lackierung bzw. Aufkleber am rechten Rand (gesperrt etwas gedämpft)
		if kind == "paint":
			var sw := ColorRect.new()
			sw.color = Cosmetics.paint_texture(it.id).get_image().get_pixel(16, 20) * (Color(0.75, 0.75, 0.8) if not unlocked else Color.WHITE)
			sw.position = Vector2(150, 4)
			sw.size = Vector2(14, 10)
			sw.mouse_filter = Control.MOUSE_FILTER_IGNORE
			b.add_child(sw)
		elif it.id != "none":
			var ic := TextureRect.new()
			ic.texture = Cosmetics.sticker_texture(it.id)
			ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			ic.position = Vector2(151, 2)
			ic.size = Vector2(14, 14)
			ic.modulate = Color(0.7, 0.72, 0.85) if not unlocked else Color.WHITE
			ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
			b.add_child(ic)
		col.add_child(b)
		buttons.append(b)
	stage.add_child(col)
	_mark()

## Gewählte Teile mit ◆ kennzeichnen.
func _mark() -> void:
	for b in buttons:
		b.text = ("◆ " if Cosmetics.selected(b.get_meta("kind")) == b.get_meta("id") else "") + b.get_meta("label")

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()   # vor dem Szenenwechsel, danach hat der Knoten keinen Viewport mehr
		Flow.to_menu()
