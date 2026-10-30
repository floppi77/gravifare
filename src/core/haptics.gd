extends Node
## Autoload "Haptics": Gamepad-Vibration (Schub, Landung, Kollision, Explosion). Stärke 0..1 in den Optionen
## (0 = aus). Ohne Gamepad passiert nichts.

var _thrust_cd := 0.0

func pulse(weak: float, strong: float, seconds: float) -> void:
	var k: float = Settings.values.get("vibration", 1.0)
	if k <= 0.01:
		return
	for d in Input.get_connected_joypads():
		Input.start_joy_vibration(d, clampf(weak * k, 0.0, 1.0), clampf(strong * k, 0.0, 1.0), seconds)

## Dauerhaftes leises Brummen beim Schub; wird jeden Tick aufgerufen und gedrosselt.
func thrust(level: float) -> void:
	_thrust_cd -= Tuning.TICK
	if level > 0.05 and _thrust_cd <= 0.0:
		_thrust_cd = 0.07
		pulse(0.06 + 0.22 * clampf(level, 0.0, 1.0), 0.0, 0.1)

func stop() -> void:
	for d in Input.get_connected_joypads():
		Input.stop_joy_vibration(d)
