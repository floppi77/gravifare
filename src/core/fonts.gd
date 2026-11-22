extends Node
## Autoload "Fonts": die drei Spielschriften (alle SIL OFL 1.1, siehe THIRD_PARTY_LICENSES.md).
##   title  Jersey 10   – Pixel-Schrift für Titel und große Überschriften
##   hud    Oxanium     – technische Schrift für HUD, Menüs, Schilder
##   ui     Nunito      – gut lesbare Schrift für Untertitel und Fließtext
## Dazu als Ersatzschriften für alle drei (Teilmengen, SIL OFL 1.1): Noto Sans Symbols 2 für ✕ ○ □ △ (Knopfnamen im PlayStation-Layout)
## und ★ ◆ ✎ ✓ ✔ ⌨ 🔒, Noto Sans Symbols für die Pfeile ← ↑ → ↓. Die Titelschrift greift zusätzlich auf Oxanium zurück (∞ ≈ ≤).
## Ohne diese Ersatzschriften hängt die Darstellung von den Systemschriften ab; im Browser gibt es keine, dort stünden Kästchen.
## Fehlt eine Datei, fällt jede Schrift auf die Godot-Standardschrift zurück (Spiel läuft weiter).

const SYMBOLS := ["res://assets/fonts/noto_symbols2/NotoSansSymbols2-Subset.ttf",      # Teilmengen (SIL OFL 1.1), erzeugt mit pyftsubset
	"res://assets/fonts/noto_symbols/NotoSansSymbols-Subset.ttf"]
const OXANIUM := "res://assets/fonts/oxanium/Oxanium.ttf"

var title: Font
var hud: Font
var ui: Font

func _ready() -> void:
	title = _load("res://assets/fonts/jersey10/Jersey10-Regular.ttf", 0, [OXANIUM])
	hud = _load(OXANIUM, 600)
	ui = _load("res://assets/fonts/nunito/Nunito.ttf", 600)
	var th := ThemeDB.get_default_theme()
	if th != null:
		th.default_font = hud

func _load(path: String, weight: int, extra: Array = []) -> Font:
	if not ResourceLoader.exists(path):
		push_warning("Schrift fehlt: " + path)
		return ThemeDB.fallback_font
	var base: Font = load(path)
	if base == null:
		return ThemeDB.fallback_font
	for fp in extra + SYMBOLS:                           # Zeichen, die in der Schrift fehlen (Symbole, Pfeile; Titel: ∞ ≈ ≤ aus Oxanium)
		if not ResourceLoader.exists(fp):
			continue
		var sym: Font = load(fp)
		if sym != null and sym != base and not base.fallbacks.has(sym):
			base.fallbacks = base.fallbacks + [sym]
	if weight <= 0:
		return base
	var fv := FontVariation.new()
	fv.base_font = base
	fv.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): weight}
	return fv
