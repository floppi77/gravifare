extends Node2D
## Geisterfahrt: Das Taxi der eigenen Bestzeit fliegt halbtransparent mit. Es folgt den 10 Positionen je Sekunde aus dem Replay
## und stört weder Kollision noch Fahrgäste.

var run: Run
var trace: Array = []
var tex: Texture2D = Cosmetics.paint_texture("std")

func bind(r: Run, samples: Array) -> void:
	run = r
	trace = samples
	visible = trace.size() >= Replay.TRACE_FIELDS * 2
	queue_redraw()

func _process(_d: float) -> void:
	if visible:
		queue_redraw()

func _draw() -> void:
	if run == null or trace.is_empty():
		return
	var n := trace.size() / Replay.TRACE_FIELDS
	var u := run.level_time * Replay.TRACE_HZ
	var i := int(u)
	if i >= n - 1:
		return                     # der Geist ist schon im Ziel
	var f := u - float(i)
	var a := Vector2(trace[i * 3], trace[i * 3 + 1])
	var b := Vector2(trace[(i + 1) * 3], trace[(i + 1) * 3 + 1])
	draw_set_transform(a.lerp(b, f), lerpf(trace[i * 3 + 2], trace[(i + 1) * 3 + 2], f), Vector2.ONE)
	draw_texture_rect(tex, Rect2(-12.8, -8, 25.6, 16), false, Color(0.6, 0.97, 1.0, 0.27))
