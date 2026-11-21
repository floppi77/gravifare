class_name OvertimeBay
extends WorkshopBay
## Werkstatt-Halt der Sonderschicht: dieselbe Halle wie in der Karriere (Einflug, Hebebühne, Ausflug), rechts aber das Angebot des Halts:
## vier zufällige Teile der Ausstattung mit Preis, „Neu würfeln“ (Marke oder Credits) und „Weiter“. Gekauft wird mit dem Guthaben des Laufs;
## der Spielstand der Karriere (Werkstatt-Einbauten) bleibt unberührt.

var st: Dictionary = {}                 # Zustand der Sonderschicht (Flow.ot); Käufe schreiben direkt hinein
var on_change: Callable                 # nach jedem Kauf: Zustand sichern

const CAT_ACCENT := {"jets": Color("#ff9a3a"), "fuel": Color("#ffcb3d"), "hull": Color("#35c8e0"), "land": Color("#7dff9a"), "guest": Color("#ff7ad9"),
	"life": Color("#ff5a6e"), "run": Color("#a9b8ff"), "legend": Color("#ffe14a")}
const CAT_FOCUS := {"jets": "jets", "fuel": "jets", "hull": "hull", "land": "gear"}      # was das Taxi auf der Bühne zeigt

func _monitor_level(_id: String) -> int:
	return 0

func _build(focus_id: String) -> void:
	for c in box.get_children():
		box.remove_child(c)
		c.queue_free()
	box.add_theme_constant_override("separation", 3)
	box.add_child(MenuKit.title(tr("OT_HALT") % [int(st.get("halts", 1)), maxi(1, Overtime.total(st) / Overtime.HALT_EVERY - 1)], 14))
	var cash := Label.new()
	cash.text = "¢ %d" % int(st.get("credits", 0.0))
	cash.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cash.add_theme_color_override("font_color", Color("#ffe14a"))
	cash.add_theme_font_size_override("font_size", 14)
	cash.add_theme_color_override("font_outline_color", Color("#0c0f24"))
	cash.add_theme_constant_override("outline_size", 3)
	box.add_child(cash)
	var sub := Label.new()
	sub.text = tr("OT_HALT_SUB") % [int(st.get("lives", 0)), int(st.get("tokens", 0))]
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 7)
	sub.add_theme_color_override("font_color", Color("#a9b8ff"))
	box.add_child(sub)
	var items: Array = Overtime.shop(st)
	for i in items.size():
		box.add_child(_ot_card(i, items[i]))
	if items.is_empty():
		var none := Label.new()
		none.text = tr("OT_HALT_EMPTY")
		none.add_theme_font_size_override("font_size", 8)
		box.add_child(none)
	desc_label = Label.new()
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_label.custom_minimum_size = Vector2(260, 22)
	desc_label.add_theme_font_size_override("font_size", 8)
	desc_label.add_theme_color_override("font_color", Color("#a9b8ff"))
	desc_label.text = tr("OT_PERK_%s_D" % String(items[0].id).to_upper()) if not items.is_empty() else ""
	box.add_child(desc_label)
	var gap := Control.new()
	gap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(gap)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	var rr_text := tr("OT_REROLL_TOKEN") if int(st.get("tokens", 0)) > 0 else tr("OT_REROLL_PAY") % Overtime.shop_reroll_price(st)
	var rr := MenuKit.button(rr_text, func():
		if Overtime.reroll_shop(st):
			Sfx.play("coin")
			_changed()
			_build("slot0")
		else:
			Sfx.play("warn", -6.0))
	rr.name = "reroll"
	rr.add_theme_font_size_override("font_size", 8)
	row.add_child(rr)
	var out := MenuKit.button(tr("OT_HALT_LEAVE"), _go)
	out.name = "leave"
	row.add_child(out)
	box.add_child(row)
	if state == S.SHOP:
		_focus(focus_id if focus_id != "" else ("slot0" if not items.is_empty() else "leave"))

func _ot_card(i: int, it: Dictionary) -> PanelContainer:
	var id := String(it.id)
	var p := Overtime.perk(id)
	var cat := String(p.get("cat", "run"))
	var accent: Color = CAT_ACCENT.get(cat, Color.WHITE)
	var sold := bool(it.sold)
	var price := Overtime.price(st, id)
	var have := Overtime.stack(st, id)
	var can := not sold and float(st.get("credits", 0.0)) >= float(price)
	var card := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.06, 0.16, 0.92)
	sb.border_color = Color(accent, 0.45)
	sb.set_border_width_all(1)
	sb.border_width_left = 3
	sb.set_corner_radius_all(3)
	sb.content_margin_left = 6; sb.content_margin_right = 4; sb.content_margin_top = 3; sb.content_margin_bottom = 3
	card.add_theme_stylebox_override("panel", sb)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	card.add_child(row)
	var ic := OvertimeIcon.new()
	ic.kind = "perk"
	ic.cat = cat
	ic.rar = String(p.get("rar", "c"))
	ic.custom_minimum_size = Vector2(18, 18)
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(ic)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 1)
	col.custom_minimum_size = Vector2(150, 0)
	var title := Label.new()
	title.text = tr("OT_PERK_%s" % id.to_upper())
	title.add_theme_font_size_override("font_size", 10)
	title.add_theme_color_override("font_color", OvertimeIcon.RAR_COLOR.get(String(p.get("rar", "c")), Color.WHITE))
	col.add_child(title)
	var eff := Label.new()
	var maxn := int(p.get("max", 1))
	eff.text = tr("OT_RAR_" + String(p.get("rar", "c")).to_upper()) + ("   " + tr("OT_STACK") % [have, maxn] if maxn > 1 and maxn < 9 else "")
	eff.add_theme_font_size_override("font_size", 7)
	eff.add_theme_color_override("font_color", Color("#c4d0ff"))
	col.add_child(eff)
	row.add_child(col)
	var b := MenuKit.button(("✔ " + tr("OT_SOLD")) if sold else "¢ %d" % price, func():
		if Overtime.buy(st, i):
			Sfx.play("coin")
			_changed()
			_build("slot%d" % i)
		else:
			Sfx.play("warn", -6.0))
	b.name = "slot%d" % i
	b.custom_minimum_size = Vector2(80, 22)
	b.add_theme_font_size_override("font_size", 8 if sold else 9)
	if not sold and not can:
		b.add_theme_color_override("font_color", Color("#ff7a8e"))
		b.add_theme_color_override("font_focus_color", Color("#ff7a8e"))
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b.focus_entered.connect(func():
		focus_item = String(CAT_FOCUS.get(cat, ""))
		if desc_label != null and is_instance_valid(desc_label):
			desc_label.text = tr("OT_PERK_%s_D" % id.to_upper())
		sb.border_color = accent)
	b.focus_exited.connect(func():
		sb.border_color = Color(accent, 0.45))
	row.add_child(b)
	return card

func _changed() -> void:
	wallet = float(st.get("credits", 0.0))
	if on_change.is_valid():
		on_change.call()

func _focus(id: String) -> void:
	await get_tree().process_frame
	if id == "":
		id = "slot0"
	var b := box.find_child(id, true, false) as Button
	if b == null:
		b = box.find_child("leave", true, false) as Button
	if b != null:
		b.grab_focus()
