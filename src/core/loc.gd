extends Node
## Autoload "Loc": lädt data/i18n/<locale>.json als Translation-Objekte. Fehlende Schlüssel
## fallen auf den Schlüssel selbst zurück (sichtbar, aber nie ein Absturz).

const LOCALES := ["de", "en"]

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
		var t := Translation.new()
		t.locale = loc
		for k in d:
			t.add_message(k, d[k])
		TranslationServer.add_translation(t)
	set_language("de" if OS.get_locale_language() == "de" else "en")

func set_language(code: String) -> void:
	TranslationServer.set_locale(code)
