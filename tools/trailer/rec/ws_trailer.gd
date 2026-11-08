extends Control
## Nur Aufnahmekopie: Werkstatt nach Sektor 3, Taxi fliegt ein, dann wandert der Fokus über die Einbauten und kauft zwei davon.
## Zeitplan in Frames (60 fps): Ereignisse werden auf stdout protokolliert (für die Tonspur des Trailers).
var bay
var frame := 0
var plan := {}
func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	Save.data["workshop"] = {"jets": 1, "hull": 0, "gear": 1}
	bay = WorkshopBay.new()
	bay.sector = int(OS.get_environment("GF_SECTOR")) if OS.get_environment("GF_SECTOR") != "" else 3
	bay.wallet = 16000.0
	bay.leave = func(): pass
	add_child(bay)
	Input.warp_mouse(Vector2(2, 2))
	var t0 := int(OS.get_environment("GF_WS_T0")) if OS.get_environment("GF_WS_T0") != "" else 0
	plan = {t0 + 60: ["focus", "jets"], t0 + 110: ["buy", "jets"], t0 + 170: ["focus", "hull"], t0 + 220: ["buy", "hull"], t0 + 290: ["focus", "gear"], t0 + 360: ["focus", "jets"]}
func _process(_d: float) -> void:
	frame += 1
	if bay.state != WorkshopBay.S.SHOP:
		return
	if not has_meta("shop_at"):
		set_meta("shop_at", frame)
		print("SHOP ", frame)
	var rel: int = frame - int(get_meta("shop_at"))
	if plan.has(rel):
		var a: Array = plan[rel]
		var b := bay.box.find_child(a[1], true, false) as Button
		if b == null:
			return
		if a[0] == "focus":
			b.grab_focus()
		else:
			b.grab_focus()
			b.pressed.emit()
			print("BUY ", a[1], " ", frame)
