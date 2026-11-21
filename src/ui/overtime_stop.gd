extends Control
## Halt und Kreuzung der Sonderschicht ohne laufendes Level: beim Start eines Laufs und beim Fortsetzen an einer Kreuzung bzw. in einem Halt.
## Die Wahl startet die Etappe direkt (ohne Zwischenflug); zwischen zwei Etappen laufen Halt und Kreuzung dagegen im Spiel (game.gd).

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	Music.play_theme("menu")
	Music.duck(0.0)
	if Flow.ot.is_empty():
		Flow.to_menu.call_deferred()
		return
	Flow.overtime = true
	if String(Flow.ot.phase) == "halt":
		var b := OvertimeBay.new()
		b.st = Flow.ot
		b.sector = Overtime.sector_of(Flow.ot, maxi(0, int(Flow.ot.etappe) - 1))
		b.wallet = float(Flow.ot.credits)
		b.on_change = Flow.ot_save
		b.leave = func():
			Overtime.leave_halt(Flow.ot)
			Flow.ot_save()
			_cross()
		var layer := CanvasLayer.new()                  # die Halle räumt beim Ausblenden ihre Elternebene ab, nicht diese Szene
		layer.layer = 13
		add_child(layer)
		layer.add_child(b)
	else:
		_cross()

func _cross() -> void:
	var c := OvertimeCross.new()
	c.st = Flow.ot
	c.on_change = Flow.ot_save
	c.on_pause = Flow.to_menu
	c.on_pick = func(o: Dictionary):
		Overtime.choose(Flow.ot, o)
		Flow.ot_save()
		Flow.ot_begin_etappe()
	var layer := CanvasLayer.new()
	layer.layer = 14
	add_child(layer)
	layer.add_child(c)
