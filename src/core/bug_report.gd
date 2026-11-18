class_name BugReport
extends RefCounted
## „Bug melden“: E-Mail an die Fehleradresse mit festem Betreff-Präfix (zum Filtern) und vorausgefüllten Systemangaben.
## Reine Hilfsfunktionen; das Hauptmenü sammelt die Angaben (Autoloads) und öffnet die mailto:-Adresse.

const ADDRESS := "gravifare@jpfa.eu"
const SUBJECT_TAG := "[GraviFare-Bug]"

## Betreff: „[GraviFare-Bug] v1.6.1 · Linux“.
static func subject(version: String, os_name: String) -> String:
	return "%s v%s · %s" % [SUBJECT_TAG, version, os_name]

## Text der Mail: Fragen an den Spieler (in seiner Sprache), darunter die Systemangaben als „Schlüssel: Wert“-Zeilen.
static func body(questions: Array, info: Array) -> String:
	var lines: Array = []
	for q in questions:
		lines.append(String(q))
		lines.append("")
		lines.append("")
	lines.append("----------")
	for kv in info:
		lines.append("%s: %s" % [kv[0], kv[1]])
	return "\n".join(lines)

## mailto:-Adresse; Zeilenumbrüche als CRLF (RFC 6068), alles prozentkodiert.
static func mailto(subj: String, text: String) -> String:
	return "mailto:%s?subject=%s&body=%s" % [ADDRESS, subj.uri_encode(), text.replace("\r\n", "\n").replace("\n", "\r\n").uri_encode()]
