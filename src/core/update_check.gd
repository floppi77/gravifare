extends Node
## Runde 85: Hinweis auf neue Versionen. Nur mit Zustimmung (Option „Nach Updates suchen“, beim ersten Start einmal erfragt):
## höchstens einmal am Tag eine Anfrage an die öffentliche GitHub-Schnittstelle (neueste Veröffentlichung), ohne persönliche Daten –
## übertragen werden nur die üblichen Angaben jeder Webanfrage und die Kennung „GraviFare/<Version>“. Ist dort eine neuere Version
## als die laufende, merkt sich das Spiel sie (`update_seen`) und zeigt im Hauptmenü einen Knopf zur Projektseite auf itch.io.
## Fehler (offline, Zeitüberschreitung, Antwort unbrauchbar) bleiben still.

const API_URL := "https://api.github.com/repos/floppi77/gravifare/releases/latest"
const PAGE_URL := "https://floppi77.itch.io/gravifare"
const TIMEOUT := 8.0

signal found(version: String)

var _http: HTTPRequest

## Versionsnummer aus einem Tag („v1.6.7“ → [1, 6, 7]); leer, wenn es keine ist.
static func parse(tag: String) -> Array:
	var t := tag.strip_edges()
	if t.begins_with("v") or t.begins_with("V"):
		t = t.substr(1)
	var parts := t.split(".")
	if parts.size() < 2 or parts.size() > 4:
		return []
	var out: Array = []
	for p in parts:
		if not p.is_valid_int():
			return []
		out.append(int(p))
	return out

## Ist `latest` neuer als `current`? Unbrauchbare Angaben: nein.
static func is_newer(latest: String, current: String) -> bool:
	var a := parse(latest)
	var b := parse(current)
	if a.is_empty() or b.is_empty():
		return false
	for i in maxi(a.size(), b.size()):
		var x: int = a[i] if i < a.size() else 0
		var y: int = b[i] if i < b.size() else 0
		if x != y:
			return x > y
	return false

## Tag der neuesten Veröffentlichung aus der Antwort der Schnittstelle ("" bei Entwürfen, Vorabversionen oder unbrauchbarer Antwort).
static func tag_from(body: String) -> String:
	var js := JSON.new()
	if js.parse(body) != OK:                       # still: keine Fehlermeldung im Protokoll bei kaputten Antworten
		return ""
	var d = js.data
	if not (d is Dictionary) or bool(d.get("draft", false)) or bool(d.get("prerelease", false)):
		return ""
	var tag := String(d.get("tag_name", ""))
	return tag if not parse(tag).is_empty() else ""

## Version ohne führendes „v“ für die Anzeige.
static func plain(tag: String) -> String:
	return tag.substr(1) if tag.begins_with("v") or tag.begins_with("V") else tag

## Neuere Version, die schon einmal gefunden wurde ("" sonst oder wenn sie inzwischen installiert ist).
static func pending(seen: String, current: String) -> String:
	return seen if seen != "" and is_newer(seen, current) else ""

## Nachfragen, falls erlaubt und heute noch nicht geschehen. `today` im Format JJJJ-MM-TT.
func check(today: String) -> void:
	if Settings.values.update_check != "on" or String(Settings.values.update_last) == today or _http != null:
		return
	if DisplayServer.get_name() == "headless" or Save.dev_session:
		return
	_http = HTTPRequest.new()
	_http.timeout = TIMEOUT
	add_child(_http)
	_http.request_completed.connect(_done.bind(today))
	var err := _http.request(API_URL, PackedStringArray(["User-Agent: GraviFare/" + Flow.VERSION, "Accept: application/vnd.github+json"]))
	if err != OK:
		_http.queue_free()
		_http = null

func _done(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray, today: String) -> void:
	_http.queue_free()
	_http = null
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		return
	Settings.values.update_last = today
	var tag := tag_from(body.get_string_from_utf8())
	if tag != "" and is_newer(tag, Flow.VERSION):
		Settings.values.update_seen = tag
	Settings.save_settings()
	var p := pending(String(Settings.values.update_seen), Flow.VERSION)
	if p != "":
		found.emit(p)
