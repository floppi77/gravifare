# Community-Level

*Deutsch zuerst · [English below](#community-levels-english)*

Im Hauptmenü unter **Community** liegen eigene und geteilte Level. Sie sind getrennt vom Feldzug: Sie ändern weder Fortschritt noch Medaillen, Statistik oder Freischaltungen, und die 99 mitgelieferten Level werden nie verändert. Geflogen wird mit dem Serientaxi (ohne Garagen-Einbauten), mit vollem Tank und fünf Leben. Gespeichert werden nur eigene Bestzeit, Bestwert und die Zahl der Flüge je Level.

## Level weitergeben und einlesen

- **Code:** *Code kopieren* legt einen Text der Form `GFL1:…` in die Zwischenablage (etwa 1 KB). Der Empfänger wählt *Aus Zwischenablage*. Das funktioniert auch mit dem Controller.
- **Datei:** Level liegen als `<ID>.gflevel` im Ordner `user://community/` (Knopf *Ordner öffnen*). Eine Datei dorthin kopieren genügt; mit *Aus Zwischenablage* lässt sich auch der Dateiinhalt einfügen.
- **Original kopieren:** Jedes mitgelieferte Level lässt sich als eigene Kopie anlegen und per Hand verändern. Die Kopie trägt den Vermerk `derived_from`.
- Beim Einlesen wird alles geprüft (siehe unten). Ungültiges wird mit einer Begründung abgelehnt. Der Autopilot fliegt das Level danach einmal Probe; schafft er es nicht, gibt es nur eine Warnung.

## Dateiformat (`.gflevel`, JSON)

```json
{
 "format": "gravifare-level", "version": 1,
 "author": "Name", "license": "CC BY-NC-SA 4.0", "created": "2026-11-05", "derived_from": "s1_01",
 "level": {
  "name": {"de": "Zwergenhafen", "en": "Dwarf Harbor"},
  "sector": 1, "index": 6, "dark": 0.0,
  "map": ["####…", "…"],
  "jobs": [{"from": "1", "to": "2", "passenger": "Mika", "gender": "f"}, {"from": "2", "to": "exit"}],
  "doors": {}, "movers": [], "zones": []
 }
}
```

- **`sector` (1–9)** wählt die Optik: Hintergrund, Musik, Umgebungsgeräusch und Preisniveau. `index` (1–11) stuft das Preisniveau innerhalb des Sektors.
- **`map`:** 10 bis 22 Zeilen mit je 16 bis 40 Zeichen, alle gleich lang. Zeichen: `#` Fels, `.` Luft, `1`–`9` Passagierpads, `F` Tankpad, `L` Lebens-Station, `H` Krankenhaus, `S` Start, `E` Ausgangstor, `^` Dornen, `P` Zapfsäule, `a`–`e` Schiebetore.
- **`jobs`:** Fahrten in Reihenfolge, `from`/`to` sind Pad-Ziffern, `to: "exit"` nur im letzten Auftrag. Fehlen die Aufträge, werden sie erzeugt. Richtzeiten (`par`) werden immer aus dem Flugweg berechnet.
- **`doors`, `movers`, `zones`:** wie in den mitgelieferten Leveln (`data/levels/*.json`). Erlaubt sind Hindernisarten `debris`, `slider`, `pad`, `meteor`, `beam`, `vehicle` (höchstens 24) und Zonen `wind`, `magnet`, `gravity`, `heat` (höchstens 16). Zahlen werden auf sinnvolle Bereiche begrenzt.
- Alles andere in der Datei wird verworfen. Die Level-ID (`c_` plus zehn Hexzeichen) ist ein Hash des geprüften Inhalts: Wer ein Level ändert, erzeugt ein neues Level mit eigenen Bestzeiten.

Ein kleines Beispiel zum Ausprobieren und Abschauen: [`community/zwergenhafen.gflevel`](community/zwergenhafen.gflevel) (Inhalt in die Zwischenablage kopieren und *Aus Zwischenablage* wählen, oder die Datei in den Ordner legen).

## Regeln der Prüfung

Genau ein Start `S`, ein Ausgangstor `E` mittig oben, 2 bis 9 Passagierpads mit fortlaufenden Nummern ab 1 und mindestens 4 Feldern Breite, Aufträge zwischen vorhandenen Pads (zerbrechliche Fahrgäste dürfen zum Krankenhaus `H`), der erste Fahrgast wartet nicht auf dem Start-Pad und keiner auf dem letzten Ziel-Pad, und jede Fahrt braucht einen Flugweg. Ein fehlender Platz für den Unterstand eines Pads ist nur eine Warnung.

## Lizenz

Eigene Level gehören den Autorinnen und Autoren. Kopien mitgelieferter Level sind Bearbeitungen von Inhalten dieses Projekts und stehen unter **CC BY-NC-SA 4.0** (Voreinstellung in der Datei). Wer ein Level weitergibt, nennt den Autor in `author`. Das Spiel verteilt oder hostet keine Community-Level.

---

# Community levels (English)

Under **Community** in the main menu you find your own and shared levels. They are separate from the campaign: they change neither progress nor medals, statistics or unlocks, and the 99 bundled levels are never modified. You fly the standard taxi (no garage upgrades) with a full tank and five lives. Only your best time, best score and the number of flights per level are saved.

## Sharing and importing

- **Code:** *Copy code* puts a `GFL1:…` text on the clipboard (about 1 KB). The recipient picks *From clipboard*. This works with a controller as well.
- **File:** Levels are stored as `<ID>.gflevel` in `user://community/` (button *Open folder*). Copying a file there is enough; *From clipboard* also accepts the file's content.
- **Copy an original:** Any bundled level can be saved as your own copy and edited by hand. The copy carries a `derived_from` note.
- Everything is validated on import (see below) and rejected with a reason if invalid. The autopilot then makes one trial flight; if it fails you only get a warning.

## File format (`.gflevel`, JSON)

See the German example above. `sector` (1–9) chooses the look (background, music, ambience, price level), `index` (1–11) the price level within the sector. `map` has 10 to 22 rows of 16 to 40 equal-length characters: `#` rock, `.` air, `1`–`9` passenger pads, `F` fuel pad, `L` life station, `H` hospital, `S` start, `E` exit gate, `^` spikes, `P` pump, `a`–`e` sliding gates. `jobs` list trips in order (`to: "exit"` only in the last one); missing jobs are generated and target times (`par`) are always computed from the flight path. `doors`, `movers` (at most 24 of `debris`, `slider`, `pad`, `meteor`, `beam`, `vehicle`) and `zones` (at most 16 of `wind`, `magnet`, `gravity`, `heat`) work as in the bundled levels (`data/levels/*.json`); numbers are clamped to sensible ranges. Anything else in the file is discarded. The level ID (`c_` plus ten hex characters) is a hash of the validated content: changing a level creates a new level with its own best times.

A small example to try and learn from: [`community/zwergenhafen.gflevel`](community/zwergenhafen.gflevel) (copy the content to the clipboard and pick *From clipboard*, or put the file into the folder).

## Validation rules

Exactly one start `S`, one exit gate `E` centred at the top, 2 to 9 passenger pads numbered from 1 without gaps and at least 4 tiles wide, jobs between existing pads (fragile passengers may go to the hospital `H`), the first passenger does not wait on the start pad and none on the previous destination pad, and every trip needs a flight path. A pad without room for its shelter is only a warning.

## Licence

Your own levels belong to you. Copies of bundled levels are adaptations of this project's content and fall under **CC BY-NC-SA 4.0** (the default in the file). When sharing a level, name the author in `author`. The game does not distribute or host community levels.
