extends Node
## Autoload "Controls": legt alle Eingabeaktionen mit Standardbelegung an (Tastatur + Gamepad).
## Spielaktionen und Menüaktionen sind getrennt, damit eine Taste nie beides auslöst.

const ACTIONS := {
	"thrust_left":  {"keys": [KEY_A, KEY_LEFT],  "axis": [JOY_AXIS_LEFT_X, -1.0], "btn": [JOY_BUTTON_DPAD_LEFT]},
	"thrust_right": {"keys": [KEY_D, KEY_RIGHT], "axis": [JOY_AXIS_LEFT_X, 1.0],  "btn": [JOY_BUTTON_DPAD_RIGHT]},
	"thrust_up":    {"keys": [KEY_W, KEY_UP],    "axis": [JOY_AXIS_LEFT_Y, -1.0], "btn": [JOY_BUTTON_DPAD_UP]},
	"thrust_down":  {"keys": [KEY_S, KEY_DOWN],  "axis": [JOY_AXIS_LEFT_Y, 1.0],  "btn": [JOY_BUTTON_DPAD_DOWN]},
	"gear":         {"keys": [KEY_SPACE],        "btn": [JOY_BUTTON_A]},
	"restart":      {"keys": [KEY_R],            "btn": [JOY_BUTTON_Y]},
	"pause":        {"keys": [KEY_ESCAPE],       "btn": [JOY_BUTTON_START]},
}

var deadzone := 0.2
var gear_toggle := true
var last_device := "keyboard"   # "keyboard" | "gamepad" – steuert die Hinweisanzeige

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for a in ACTIONS:
		if not InputMap.has_action(a):
			InputMap.add_action(a, 0.2)
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

	# Godot 4.7 liefert für ui_accept/ui_cancel keine Gamepad-Standardtasten: A bestätigt, B bricht ab.
	for pair in [["ui_accept", JOY_BUTTON_A], ["ui_cancel", JOY_BUTTON_B]]:
		var jb := InputEventJoypadButton.new()
		jb.button_index = pair[1]
		InputMap.action_add_event(pair[0], jb)

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
