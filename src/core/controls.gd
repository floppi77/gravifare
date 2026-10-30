extends Node
## Autoload "Controls": Eingabeaktionen mit Standardbelegung (Tastatur + Gamepad), frei belegbar und persistent
## (user://controls.cfg). Belegbar: Schub (4 Richtungen), Fahrwerk, Fahrgast rauswerfen (E / Y), Neustart (R / Back). Pause bleibt fest auf Esc/Start, Menüs
## (ui_*) fest auf Pfeile/Stick/A/B/Enter – so kann man sich nie aussperren. Doppelte Belegungen werden getauscht.

const ACTIONS := {
	"thrust_left":  {"keys": [KEY_A, KEY_LEFT],  "axis": [JOY_AXIS_LEFT_X, -1.0], "btn": [JOY_BUTTON_DPAD_LEFT]},
	"thrust_right": {"keys": [KEY_D, KEY_RIGHT], "axis": [JOY_AXIS_LEFT_X, 1.0],  "btn": [JOY_BUTTON_DPAD_RIGHT]},
	"thrust_up":    {"keys": [KEY_W, KEY_UP],    "axis": [JOY_AXIS_LEFT_Y, -1.0], "btn": [JOY_BUTTON_DPAD_UP]},
	"thrust_down":  {"keys": [KEY_S, KEY_DOWN],  "axis": [JOY_AXIS_LEFT_Y, 1.0],  "btn": [JOY_BUTTON_DPAD_DOWN]},
	"gear":         {"keys": [KEY_SPACE],        "btn": [JOY_BUTTON_A]},
	"eject":        {"keys": [KEY_E],            "btn": [JOY_BUTTON_Y]},
	"restart":      {"keys": [KEY_R],            "btn": [JOY_BUTTON_BACK]},
	"pause":        {"keys": [KEY_ESCAPE],       "btn": [JOY_BUTTON_START]},
}
const REMAPPABLE := ["thrust_up", "thrust_left", "thrust_down", "thrust_right", "gear", "eject", "restart"]
const PAD_NAMES := ["A", "B", "X", "Y", "Back", "Guide", "Start", "L3", "R3", "LB", "RB", "D↑", "D↓", "D←", "D→", "Misc"]

var path := "user://controls.cfg"
var deadzone := 0.2
var gear_toggle := true
var last_device := "keyboard"   # "keyboard" | "gamepad" – steuert die Hinweisanzeige

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	apply_defaults()
	# Godot 4.7 liefert für ui_accept/ui_cancel keine Gamepad-Standardtasten: A bestätigt, B bricht ab.
	for pair in [["ui_accept", JOY_BUTTON_A], ["ui_cancel", JOY_BUTTON_B]]:
		var jb := InputEventJoypadButton.new()
		jb.button_index = pair[1]
		InputMap.action_add_event(pair[0], jb)
	load_bindings()

## Standardbelegung setzen (alle Spielaktionen, überschreibt vorhandene Ereignisse).
func apply_defaults() -> void:
	for a in ACTIONS:
		if not InputMap.has_action(a):
			InputMap.add_action(a, 0.2)
		InputMap.action_erase_events(a)
		var cfg: Dictionary = ACTIONS[a]
		for k in cfg.get("keys", []):
			var ev := InputEventKey.new()
			ev.physical_keycode = k
			InputMap.action_add_event(a, ev)
		if cfg.has("axis"):
			var jm := InputEventJoypadMotion.new()
			jm.axis = cfg.axis[0]
			jm.axis_value = cfg.axis[1]
			InputMap.action_add_event(a, jm)
		for b in cfg.get("btn", []):
			var jb := InputEventJoypadButton.new()
			jb.button_index = b
			InputMap.action_add_event(a, jb)

func _input(event: InputEvent) -> void:
	if event is InputEventJoypadButton or (event is InputEventJoypadMotion and event.axis <= JOY_AXIS_RIGHT_Y and absf(event.axis_value) > 0.5):
		last_device = "gamepad"
	elif event is InputEventKey and event.pressed:
		last_device = "keyboard"

## Schubvektor: x rechts positiv, y nach unten positiv (hoch = negativ). Analog dosierbar.
func thrust_vector() -> Vector2:
	var x := Input.get_axis("thrust_left", "thrust_right")
	var y := Input.get_axis("thrust_up", "thrust_down")
	return Vector2(x, y)

# ------------------------------------------------------------------ Belegung lesen/ändern
func events_of(action: String, kind: String) -> Array:
	## kind "kb" = Tastatur, "pad" = Gamepad (Knopf oder Stickrichtung)
	var out: Array = []
	for e in InputMap.action_get_events(action):
		if (kind == "kb" and e is InputEventKey) or (kind == "pad" and (e is InputEventJoypadButton or e is InputEventJoypadMotion)):
			out.append(e)
	return out

func same_event(a: InputEvent, b: InputEvent) -> bool:
	if a is InputEventKey and b is InputEventKey:
		return a.physical_keycode == b.physical_keycode
	if a is InputEventJoypadButton and b is InputEventJoypadButton:
		return a.button_index == b.button_index
	if a is InputEventJoypadMotion and b is InputEventJoypadMotion:
		return a.axis == b.axis and signf(a.axis_value) == signf(b.axis_value)
	return false

func event_label(ev: InputEvent) -> String:
	if ev == null:
		return "–"
	if ev is InputEventKey:
		var t := (ev as InputEventKey).as_text_physical_keycode()
		if t == "":
			return "?"
		var k := "KEY_" + t.to_upper().replace(" ", "_")
		var loc := tr(k)
		return loc if loc != k else t           # Tastennamen lokalisiert, falls übersetzt (Leertaste, Pfeile …)
	if ev is InputEventJoypadButton:
		var i: int = ev.button_index
		return PAD_NAMES[i] if i >= 0 and i < PAD_NAMES.size() else "B%d" % i
	if ev is InputEventJoypadMotion:
		var m := ev as InputEventJoypadMotion
		match m.axis:
			JOY_AXIS_LEFT_X: return "Stick " + ("→" if m.axis_value > 0 else "←")
			JOY_AXIS_LEFT_Y: return "Stick " + ("↓" if m.axis_value > 0 else "↑")
			JOY_AXIS_RIGHT_X: return "R-Stick " + ("→" if m.axis_value > 0 else "←")
			JOY_AXIS_RIGHT_Y: return "R-Stick " + ("↓" if m.axis_value > 0 else "↑")
			JOY_AXIS_TRIGGER_LEFT: return "LT"
			JOY_AXIS_TRIGGER_RIGHT: return "RT"
		return "Achse %d" % m.axis
	return "?"

func slot_label(action: String, kind: String, slot: int) -> String:
	var l := events_of(action, kind)
	return event_label(l[slot]) if slot < l.size() else "–"

## Belegt Slot `slot` von (action, kind) neu. Ist das Ereignis bei einer anderen Aktion belegt, wird getauscht
## (die andere bekommt die alte Belegung dieses Slots oder verliert sie, falls der Slot leer war).
## Rückgabe: Name der getauschten Aktion ("" wenn keine).
func set_slot(action: String, kind: String, slot: int, ev: InputEvent) -> String:
	var swapped := ""
	var cur := events_of(action, kind)
	var old: InputEvent = cur[slot] if slot < cur.size() else null
	for other in REMAPPABLE:
		if other == action:
			continue
		var ol := events_of(other, kind)
		for i in ol.size():
			if same_event(ol[i], ev):
				swapped = other
				var repl := ol.duplicate()
				if old != null:
					repl[i] = old
				else:
					repl.remove_at(i)
				_write(other, kind, repl)
				break
	# gleiches Ereignis schon an anderem Slot derselben Aktion: dort entfernen
	var mine := cur.duplicate()
	for i in range(mine.size() - 1, -1, -1):
		if i != slot and same_event(mine[i], ev):
			mine.remove_at(i)
			if i < slot:
				slot -= 1
	if slot < mine.size():
		mine[slot] = ev
	else:
		mine.append(ev)
	_write(action, kind, mine)
	save_bindings()
	return swapped

func _write(action: String, kind: String, list: Array) -> void:
	var others: Array = []
	for e in InputMap.action_get_events(action):
		var is_kind: bool = (kind == "kb" and e is InputEventKey) or (kind == "pad" and (e is InputEventJoypadButton or e is InputEventJoypadMotion))
		if not is_kind:
			others.append(e)
	InputMap.action_erase_events(action)
	for e in list:
		InputMap.action_add_event(action, e)
	for e in others:
		InputMap.action_add_event(action, e)

func reset_defaults() -> void:
	apply_defaults()
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)

# ------------------------------------------------------------------ Speichern/Laden (robust)
func save_bindings() -> void:
	var cf := ConfigFile.new()
	for a in REMAPPABLE:
		var arr: Array = []
		for e in InputMap.action_get_events(a):
			if e is InputEventKey:
				arr.append({"t": "key", "c": e.physical_keycode})
			elif e is InputEventJoypadButton:
				arr.append({"t": "btn", "i": e.button_index})
			elif e is InputEventJoypadMotion:
				arr.append({"t": "axis", "a": e.axis, "v": signf(e.axis_value)})
		cf.set_value("bindings", a, arr)
	cf.save(path)

func load_bindings() -> void:
	var cf := ConfigFile.new()
	if cf.load(path) != OK:
		return
	for a in REMAPPABLE:
		if not cf.has_section_key("bindings", a):
			continue
		var arr = cf.get_value("bindings", a)
		if typeof(arr) != TYPE_ARRAY:
			continue
		var evs: Array = []
		var has_kb := false
		var has_pad := false
		for d in arr:
			if typeof(d) != TYPE_DICTIONARY or not d.has("t"):
				continue
			var e: InputEvent = null
			if d.t == "key" and int(d.get("c", 0)) > 0:
				e = InputEventKey.new()
				e.physical_keycode = int(d.c)
				has_kb = true
			elif d.t == "btn" and int(d.get("i", -1)) >= 0 and int(d.i) < 32:
				e = InputEventJoypadButton.new()
				e.button_index = int(d.i)
				has_pad = true
			elif d.t == "axis" and int(d.get("a", -1)) >= 0 and int(d.a) < 8:
				e = InputEventJoypadMotion.new()
				e.axis = int(d.a)
				e.axis_value = float(d.get("v", 1.0))
				has_pad = true
			if e != null:
				evs.append(e)
		if has_kb and has_pad:                  # nur vollständige Belegungen übernehmen, sonst Standard behalten
			InputMap.action_erase_events(a)
			for e in evs:
				InputMap.action_add_event(a, e)
	# Migration: Y gehörte früher dem Neustart. Fehlt „eject“ in der Datei, bekommt der Neustart statt Y die Back-Taste.
	if not cf.has_section_key("bindings", "eject"):
		var fixed: Array = []
		var changed := false
		for e in InputMap.action_get_events("restart"):
			if e is InputEventJoypadButton and e.button_index == JOY_BUTTON_Y:
				var jb := InputEventJoypadButton.new()
				jb.button_index = JOY_BUTTON_BACK
				fixed.append(jb)
				changed = true
			else:
				fixed.append(e)
		if changed:
			InputMap.action_erase_events("restart")
			for e in fixed:
				InputMap.action_add_event("restart", e)

# ------------------------------------------------------------------ Hinweistext für das HUD
func thrust_label(device: String) -> String:
	var kind := "kb" if device == "keyboard" else "pad"
	var thrust: Array = []
	for a in ["thrust_up", "thrust_left", "thrust_down", "thrust_right"]:
		thrust.append(slot_label(a, kind, 0))
	if kind == "pad" and thrust[0].begins_with("Stick") and thrust[1].begins_with("Stick"):
		return "Stick"
	return "/".join(thrust)

func hint_text(device: String) -> String:
	var kind := "kb" if device == "keyboard" else "pad"
	var thrust: Array = []
	for a in ["thrust_up", "thrust_left", "thrust_down", "thrust_right"]:
		thrust.append(slot_label(a, kind, 0))
	var th := "/".join(thrust)
	if kind == "pad" and thrust[0].begins_with("Stick") and thrust[1].begins_with("Stick"):
		th = "Stick"
	var key := "HUD_HINT_KB" if kind == "kb" else "HUD_HINT_PAD_DYN"
	return tr(key) % [th, slot_label("gear", kind, 0), slot_label("eject", kind, 0), slot_label("restart", kind, 0)]
