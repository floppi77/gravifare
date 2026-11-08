extends Node
## Nur Projektkopie für Screenshots: Gamepad-Eingaben ignorieren (Godot liest Controller systemweit, auch in unsichtbaren Instanzen).
func _ready() -> void:
	for a in InputMap.get_actions():
		for ev in InputMap.action_get_events(a):
			if ev is InputEventJoypadButton or ev is InputEventJoypadMotion:
				InputMap.action_erase_event(a, ev)
