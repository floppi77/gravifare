class_name SteamBridge
extends RefCounted
## Vorbereitung für Steam-Erfolge, ohne Abhängigkeit: Ist GodotSteam (GDExtension, Engine-Singleton „Steam“) eingebunden und läuft
## Steam, meldet diese Brücke jeden im Spiel erreichten Erfolg zusätzlich an Steam. Ohne GodotSteam (wie jetzt) tut sie nichts –
## die Erfolge im Spiel (achievements.gd, Spielstand) bleiben die Quelle und funktionieren unverändert.
## Steam-Namen: „ACH_“ + Id in Großbuchstaben (z. B. ACH_FIRST_FARE); Liste, Texte und Symbole für Steamworks: docs/steam_achievements.md.
## Da die Erfolge aus dem Spielstand stammen, werden bei jedem Abgleich alle schon erreichten gemeldet: Auch Erfolge von vor der
## Steam-Fassung (oder offline erreichte) kommen so nach Steam. Jede Id geht je Sitzung höchstens einmal hinaus.

static var _state := 0          # 0 ungeprüft, 1 aktiv, -1 nicht verfügbar
static var _sent: Dictionary = {}

static func api_name(id: String) -> String:
	return "ACH_" + id.to_upper()

static func _steam() -> Object:
	return Engine.get_singleton("Steam") if Engine.has_singleton("Steam") else null

## Steam erreichbar? Beim ersten Aufruf wird GodotSteam initialisiert (App-Id aus steam_appid.txt bzw. vom Steam-Client).
static func available() -> bool:
	if _state == 0:
		_state = -1
		var st := _steam()
		if st != null and st.has_method("steamInitEx"):
			var r = st.call("steamInitEx")
			if typeof(r) == TYPE_DICTIONARY and int(r.get("status", -1)) == 0:
				_state = 1
	return _state == 1

## Erreichte Erfolge an Steam melden (noch nicht gemeldete dieser Sitzung). Rückgabe: Zahl der gemeldeten.
static func push(ids: Array) -> int:
	var todo: Array = ids.filter(func(i): return not _sent.has(String(i)))
	if todo.is_empty() or not available():
		return 0
	var st := _steam()
	for id in todo:
		st.call("setAchievement", api_name(String(id)))
		_sent[String(id)] = true
	st.call("storeStats")
	return todo.size()
