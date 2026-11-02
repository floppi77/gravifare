class_name CodeEntry
extends RefCounted
## Unsichtbare Code-Eingabe: Das Wort muss ohne Tippfehler innerhalb des Zeitfensters vollständig eingegeben werden; Groß- und Kleinschreibung zählt nicht.

var word := ""
var window_ms := 3000
var _i := 0
var _t0 := 0

func _init(w: String, ms := 3000) -> void:
	word = w.to_lower()
	window_ms = ms

## Ein getipptes Zeichen; true, wenn das Wort damit vollständig ist.
func feed(ch: String, now_ms: int) -> bool:
	var c := ch.to_lower()
	if _i > 0 and (c != word[_i] or now_ms - _t0 > window_ms):
		_i = 0
	if c != word[_i]:
		return false
	if _i == 0:
		_t0 = now_ms
	_i += 1
	if _i < word.length():
		return false
	_i = 0
	return true
