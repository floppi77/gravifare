extends Node
## Nur Aufnahmekopie: baut im Level-Editor Strich für Strich ein Level auf (für Trailer und Screenshot). GF_ED_STOP=<frame> hält an.
const LevelEdit := preload("res://src/core/level_edit.gd")
var ed: Control
var steps: Array = []
var frame := 0
var cur := {}
func _rect(pal: int, a: Vector2i, b: Vector2i, frames := 14) -> void:
	steps.append({"kind": "rect", "pal": pal, "a": a, "b": b, "n": frames})
func _obj(kind: String, x: int, y: int, params: Dictionary, wait := 16) -> void:
	steps.append({"kind": "obj", "obj": kind, "x": x, "y": y, "p": params, "n": wait})
func _ready() -> void:
	ed = load("res://src/ui/level_editor.gd").new()
	ed.back = func(): pass
	ed.open("")
	add_child(ed)
	Input.warp_mouse(Vector2(2, 2))
	ed.model.names = {"de": "Magnetsaal", "en": "Magnet Hall"}
	ed.model.author = "floppi77"
	ed._sync_fields()
	steps.append({"kind": "wait", "n": 30})
	_rect(0, Vector2i(1, 8), Vector2i(13, 10), 22)
	_rect(0, Vector2i(22, 6), Vector2i(34, 8), 22)
	_rect(0, Vector2i(14, 15), Vector2i(17, 20), 16)
	_rect(0, Vector2i(26, 13), Vector2i(26, 20), 12)
	_rect(5, Vector2i(3, 7), Vector2i(6, 7), 10)
	_rect(6, Vector2i(27, 5), Vector2i(30, 5), 10)
	_rect(14, Vector2i(23, 9), Vector2i(32, 9), 16)
	steps.append({"kind": "page", "n": 18})
	_obj("magnet", 17, 9, {"r": 4.5, "k": 120.0}, 22)
	_obj("beam", 12, 11, {"h": 5.0}, 22)
	_obj("debris", 28, 14, {"dx": 6.0}, 22)
	_obj("wind", 3, 12, {}, 22)
	steps.append({"kind": "select", "n": 400})
func _process(_d: float) -> void:
	frame += 1
	if cur.is_empty():
		if steps.is_empty():
			return
		cur = steps.pop_front()
		cur["i"] = 0
		match String(cur.kind):
			"rect":
				ed._select_tool(1)
				ed._select_pal(int(cur.pal))
				ed.cursor = cur.a
				ed._begin(false, cur.a)
			"page":
				ed._set_page(1)
			"obj":
				var o: Dictionary = ed.model.add_object(String(cur.obj), int(cur.x), int(cur.y))
				for k in cur.p:
					ed.model.set_param(o, k, cur.p[k])
				ed.cursor = Vector2i(int(cur.x), int(cur.y))
				ed._select_kind(LevelEdit.KINDS.find(String(cur.obj)))
				ed._select_obj(o)
				ed._changed()
				cur["o"] = o
			"select":
				pass
	cur.i = int(cur.i) + 1
	if String(cur.kind) == "rect":
		var a: Vector2i = cur.a
		var b: Vector2i = cur.b
		var u := minf(float(cur.i) / float(cur.n), 1.0)
		var at := Vector2i(roundi(lerpf(a.x, b.x, u)), roundi(lerpf(a.y, b.y, u)))
		ed.cursor = at
		ed._move_stroke(at)
		if int(cur.i) >= int(cur.n):
			ed._end_stroke()
			ed._changed()
			cur = {}
	elif int(cur.i) >= int(cur.n):
		cur = {}
