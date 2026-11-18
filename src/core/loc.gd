extends Node
## Autoload "Loc": lädt data/i18n/<locale>.json als Translation-Objekte. Fehlende Schlüssel
## fallen auf den Schlüssel selbst zurück (sichtbar, aber nie ein Absturz).

const LOCALES := ["de", "en", "fr", "es"]
const NAMES := {"de": "Deutsch", "en": "English", "fr": "Français", "es": "Español"}

var tables := {}                    # Sprache → Schlüssel → Text (für Anzeigen in beiden Sprachen gleichzeitig)
var translations := {}              # Sprache → Translation (für den Austausch der Knopfnamen)
var pad_style := "xbox"

## Texte mit Controllerknöpfen im Xbox-Layout: bei einem PlayStation-Controller werden die Knopfnamen darin ersetzt (set_pad_style).
## Nur diese Schlüssel, damit Tastaturkürzel wie „Strg+Y“ oder Achsen wie „Wind X“ unberührt bleiben.
const PAD_KEYS := ["HUD_HINT_PAD_PAD", "HUD_HINT_PAD_DYN", "HUD_RESTART", "TRANS_SKIP", "HUD_GAME_OVER_HINT", "CREDITS_KOFI", "MUSIC_HINT",
	"BIND_PRESS", "RES_CONTINUE", "RES_TO_MENU", "LVL_SWITCH", "FINALE_NEXT", "SHIFT_FIN_NEXT", "ED_HINT_LVL_PAD", "ED_HINT_PAD",
	"ED_HINT_OBJ_PAD", "ED_HINT_VALUE_PAD", "ED_MODE_TIP", "ED_VEH_ACTIVE", "ED_PICK_A", "ED_HELP_TIP", "ED_HELP_MAP_PAD", "ED_HELP_OBJ_PAD",
	"ED_HELP_LVL_PAD", "ED_HELP_ALL_PAD"]
const PS_TEXT := {"A": "✕", "B": "○", "X": "□", "Y": "△", "LB": "L1", "RB": "R1", "LT": "L2", "RT": "R2", "Back": "Share", "Start": "Options"}
var _ps_rx: RegEx

func _ready() -> void:
	for loc in LOCALES:
		var f := FileAccess.open("res://data/i18n/%s.json" % loc, FileAccess.READ)
		if f == null:
			push_warning("Sprachdatei fehlt: " + loc)
			continue
		var d = JSON.parse_string(f.get_as_text())
		if typeof(d) != TYPE_DICTIONARY:
			push_warning("Sprachdatei defekt: " + loc)
			continue
		tables[loc] = d
		if translations.has(loc):                      # erneuter Aufruf (Tests): alte Übersetzung ersetzen statt doppelt anmelden
			TranslationServer.remove_translation(translations[loc])
		var t := Translation.new()
		t.locale = loc
		for k in d:
			t.add_message(k, d[k])
		TranslationServer.add_translation(t)
		translations[loc] = t
	if pad_style == "ps":                              # Knopfnamen schon umgestellt (Controls war zuerst bereit): neu anwenden
		pad_style = "xbox"
		set_pad_style("ps")
	set_language(system_language())

## Knopfnamen eines Hinweistexts ins PlayStation-Layout übertragen („A / Enter“ → „✕ / Enter“, „LB/RB“ → „L1/R1“).
## „Back“ vor „ to“ ist das englische Wort, kein Knopf.
func ps_text(s: String) -> String:
	if _ps_rx == null:
		_ps_rx = RegEx.create_from_string("(?<![\\w+])(LB|RB|LT|RT|Back(?! to)|Start|A|B|X|Y)(?!\\w)")
	var out := ""
	var last := 0
	for m in _ps_rx.search_all(s):
		out += s.substr(last, m.get_start() - last) + String(PS_TEXT[m.get_string(1)])
		last = m.get_end()
	return out + s.substr(last)

## Knopfnamen in allen Sprachen auf den Symbolsatz „xbox“ oder „ps“ umstellen.
func set_pad_style(style: String) -> void:
	if style == pad_style:
		return
	pad_style = style
	for loc in translations:
		var t: Translation = translations[loc]
		var d: Dictionary = tables.get(loc, {})
		for k in PAD_KEYS:
			if d.has(k):
				t.add_message(k, ps_text(d[k]) if style == "ps" else String(d[k]))

## Text in einer bestimmten Sprache, unabhängig von der eingestellten (fehlt er, der Schlüssel selbst).
func text_in(code: String, key: String) -> String:
	return String(tables.get(code, {}).get(key, key))

## Sprache des Systems, falls das Spiel sie hat, sonst Englisch.
static func system_language() -> String:
	var l := OS.get_locale_language()
	return l if l in LOCALES else "en"

## Text aus einem Wörterbuch je Sprache {de, en, …}: gewünschte Sprache, sonst Englisch, sonst Deutsch.
static func pick(d, lang: String, fallback := "") -> String:
	if not (d is Dictionary):
		return String(d) if d != null else fallback
	return String(d.get(lang, d.get("en", d.get("de", fallback))))

## Aktuelle Sprache als zweibuchstabiger Code.
static func code() -> String:
	return TranslationServer.get_locale().substr(0, 2)

func set_language(code: String) -> void:
	TranslationServer.set_locale(code)
