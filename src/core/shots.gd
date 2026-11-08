class_name Shots
extends RefCounted
## Screenshots zum Teilen (Auswertung der Nachtschicht): Dateiname aus Datum, Modus und Name des Spielstands, Zielordner neben dem Spiel.
## Reine Logik für Namen und Pfade (testbar); das Aufnehmen selbst macht das Spiel.

const NAME_MAX := 16          # längster Name eines Spielstands

## Name für Dateinamen: klein, Leerzeichen als „_“, Umlaute umgeschrieben, nur a–z, 0–9, „-“ und „_“.
static func safe_name(s: String) -> String:
	var out := ""
	for ch in s.strip_edges().to_lower():
		match ch:
			"ä": out += "ae"
			"ö": out += "oe"
			"ü": out += "ue"
			"ß": out += "ss"
			" ", "_": out += "_"
			_:
				if (ch >= "a" and ch <= "z") or (ch >= "0" and ch <= "9") or ch == "-":
					out += ch
	while out.contains("__"):
		out = out.replace("__", "_")
	return out.trim_prefix("_").trim_suffix("_")

## Dateiname eines Screenshots zum Teilen: „JJMMTT_<modus>_name.png“, z. B. 261108_nachtschicht_floppi.png oder 261109_tagschicht_floppi.png.
## Ohne Namen steht „slotN“ (N = Nummer des Spielstands).
static func file_name(mode: String, date: String, slot_name: String, slot: int) -> String:
	var ymd := date.replace("-", "")
	var yymmdd := ymd.substr(2) if ymd.length() >= 8 else ymd
	var nm := safe_name(slot_name)
	if nm == "":
		nm = "slot%d" % slot
	return "%s_%s_%s.png" % [yymmdd, mode, nm]

static func shift_file_name(date: String, slot_name: String, slot: int) -> String:
	return file_name("nachtschicht", date, slot_name, slot)

static func day_file_name(date: String, slot_name: String, slot: int) -> String:
	return file_name("tagschicht", date, slot_name, slot)

## Ordner für Screenshots: neben dem Spiel (bei macOS neben dem App-Paket); ist er nicht beschreibbar oder läuft das Spiel aus dem Editor,
## der Datenordner des Spiels.
static func target_dir() -> String:
	var base := OS.get_executable_path().get_base_dir()
	if OS.get_name() == "macOS":
		var d := base
		while d != "" and not d.ends_with(".app") and d.get_base_dir() != d:
			d = d.get_base_dir()
		if d.ends_with(".app"):
			base = d.get_base_dir()
	if OS.has_feature("editor") or not _writable(base):
		return ProjectSettings.globalize_path("user://")
	return base

static func _writable(dir: String) -> bool:
	var p := dir.path_join(".gravifare_write_test")
	var f := FileAccess.open(p, FileAccess.WRITE)
	if f == null:
		return false
	f.close()
	DirAccess.remove_absolute(p)
	return true

## Freier Pfad: gibt es die Datei schon, wird „_2“, „_3“ … angehängt (nichts wird überschrieben).
static func unique_path(dir: String, file_name: String) -> String:
	var base := file_name.get_basename()
	var ext := file_name.get_extension()
	var p := dir.path_join(file_name)
	var i := 2
	while FileAccess.file_exists(p):
		p = dir.path_join("%s_%d.%s" % [base, i, ext])
		i += 1
	return p
