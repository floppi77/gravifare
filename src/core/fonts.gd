extends Node
## Autoload "Fonts": die drei Spielschriften (alle SIL OFL 1.1, siehe THIRD_PARTY_LICENSES.md).
##   title  Jersey 10   – Pixel-Schrift für Titel und große Überschriften
##   hud    Oxanium     – technische Schrift für HUD, Menüs, Schilder
##   ui     Nunito      – gut lesbare Schrift für Untertitel und Fließtext
## Dazu als Ersatzschrift für alle drei: Noto Sans Symbols 2, nur ✕ ○ □ △ (Knopfnamen im PlayStation-Layout).
## Fehlt eine Datei, fällt jede Schrift auf die Godot-Standardschrift zurück (Spiel läuft weiter).

const SYMBOLS := "res://assets/fonts/noto_symbols2/NotoSansSymbols2-PadSubset.ttf"   # Teilmenge von Noto Sans Symbols 2 (SIL OFL 1.1)

var title: Font
var hud: Font
var ui: Font

func _ready() -> void:
	title = _load("res://assets/fonts/jersey10/Jersey10-Regular.ttf", 0)
	hud = _load("res://assets/fonts/oxanium/Oxanium.ttf", 600)
	ui = _load("res://assets/fonts/nunito/Nunito.ttf", 600)
	var th := ThemeDB.get_default_theme()
	if th != null:
		th.default_font = hud

func _load(path: String, weight: int) -> Font:
	if not ResourceLoader.exists(path):
		push_warning("Schrift fehlt: " + path)
		return ThemeDB.fallback_font
	var base: Font = load(path)
	if base == null:
		return ThemeDB.fallback_font
	if ResourceLoader.exists(SYMBOLS):                  # ✕ ○ □ △ für Knopfnamen im PlayStation-Layout (fehlen in allen drei Schriften)
		var sym: Font = load(SYMBOLS)
		if sym != null and not base.fallbacks.has(sym):
			base.fallbacks = base.fallbacks + [sym]
	if weight <= 0:
		return base
	var fv := FontVariation.new()
	fv.base_font = base
	fv.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): weight}
	return fv
