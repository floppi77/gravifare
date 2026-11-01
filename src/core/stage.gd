extends RefCounted
## Bildschirm-Anpassung (Stretch-Aspekt „expand“): Die logische Spielfläche ist immer 640×360 und liegt zentriert im Fenster.
## Bei breiteren (Ultrawide) oder höheren Fenstern entstehen links/rechts bzw. oben/unten Ränder, die Hintergründe und
## Überblendungen ausfüllen; HUD, Menüs und Overlays bleiben auf der 640×360-Fläche.
## Einbinden mit: const Stage := preload("res://src/core/stage.gd")

const SIZE := Vector2(640, 360)

## Sichtbare Größe des Viewports in logischen Pixeln (mindestens 640×360).
static func view(n: Node) -> Vector2:
	var v := n.get_viewport().get_visible_rect().size
	return Vector2(maxf(v.x, SIZE.x), maxf(v.y, SIZE.y))

## Abstand der 640×360-Fläche zum Fensterrand (links/oben; rechts/unten gleich groß), nicht gerundet:
## Mit ganzzahligem Skalieren ergibt das ganze Bildschirmpixel und passt exakt zur zentrierten Kamera.
static func margin(n: Node) -> Vector2:
	return (view(n) - SIZE) * 0.5

## Legt einen zentrierten Container mit fester Größe 640×360 an (für Menüs mit festen Koordinaten).
static func make(parent: Control) -> Control:
	var c := Control.new()
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.set_anchors_preset(Control.PRESET_CENTER)
	c.custom_minimum_size = SIZE
	c.size = SIZE
	c.offset_left = -SIZE.x * 0.5
	c.offset_right = SIZE.x * 0.5
	c.offset_top = -SIZE.y * 0.5
	c.offset_bottom = SIZE.y * 0.5
	c.grow_horizontal = Control.GROW_DIRECTION_BOTH
	c.grow_vertical = Control.GROW_DIRECTION_BOTH
	parent.add_child(c)
	return c
