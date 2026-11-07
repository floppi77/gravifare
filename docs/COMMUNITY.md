# Level-Editor und eigene Level

*Deutsch zuerst · [English below](#level-editor-and-your-own-levels-english)*

Im Hauptmenü unter **Level-Editor** liegen eigene und geteilte Level. Sie sind getrennt vom Feldzug: Sie ändern weder Fortschritt noch Medaillen, Statistik oder Freischaltungen, und die 99 mitgelieferten Level werden nie verändert. Geflogen wird mit dem Serientaxi (ohne Garagen-Einbauten), mit vollem Tank und fünf Leben. Gespeichert werden nur eigene Bestzeit, Bestwert und die Zahl der Flüge je Level.

## Level bauen (Editor)

*Level-Editor → Neues Level* (oder *Bearbeiten* für eine Kopie eines vorhandenen Levels). Die Karte zeigt sofort die echte Spielansicht; die Statuszeile meldet live, ob das Level gültig ist. Das Ausgangstor liegt fest mittig oben. *Testflug* startet das Level (als Entwurf, noch nicht gespeichert), danach geht es zurück in den Editor; *Autopilot* lässt den Autopiloten das Level lösen, während du zusehen kannst (zählt keine Bestzeit; er fliegt zügig und umfliegt Zapfsäulen, schafft aber nicht jedes lösbare Level). Hat das Level Fehler, blinken die betroffenen Objekte. Zwei freie Felder unter dem Ausgangstor genügen; dahinter dürfen Fels und Dornen stehen. Am Controller springen LT/RT auf die Level-Seite und gleich in ihre Knöpfe; A auf *Name* oder *Autor* öffnet eine Bildschirmtastatur. Eine fahrende Plattform sperrt nur den Bereich, den sie immer belegt, nicht ihren ganzen Fahrweg. Das geöffnete Level bleibt unverändert; *Speichern* legt eine eigene Fassung an (weitere Speicherungen derselben Sitzung ersetzen sie). **Gespeichert wird nur, was du selbst gelöst hast:** Fliege das Level im Testflug von Hand und schaffe alle Fahrten bis zum Ausgang (der Autopilot zählt nicht), erst dann gibt der Editor das Speichern frei. Der Nachweis gilt für genau diesen Inhalt; jede Änderung verlangt einen neuen Flug. Beim Speichern übernimmt das Level Bestzeit und Bestwert deiner Testflüge. Eingelesene Level (Zwischenablage, Datei) und Kopien von Originalen sind davon nicht betroffen. **Tore:** Die Flügel fahren senkrecht, wenn über und unter dem Tor Wand steht, sonst waagerecht; mit dem Tor-Parameter *Flügel* (auto / senkrecht / waagerecht) legst du es fest. *Wandern* funktioniert in beiden Richtungen, auch für den Autopiloten. Im Debug-Modus gibt es auf der Level-Seite den Schalter *Handlösung: nötig / übersprungen*: Ist er auf „übersprungen“, lässt sich ohne neuen Testflug speichern (für kleine Änderungen; gilt für Originale wie für eigene Level, bleibt über Testflüge erhalten und fällt mit dem Debug-Modus weg).

Es gibt einen Stift für alles; was er zeichnet, wählst du in einer Symbolpalette (der Name steht zusätzlich als Hinweistext). Das rechte Bedienfeld hat drei Seiten (F1–F3, am Controller LT/RT):

- **Karte:** Fels, Luft, Pads 1–9, Tank, Leben, Klinik, Dornen, Pumpe, Start und die Tore a–e. Der Stift zieht Linien; **Umschalt+Ziehen** zeichnet ein Rechteck, **Doppelklick** füllt ein Gebiet. Am Controller und per Tab wechselt der Modusknopf (Linie, Rechteck, Füllen). *Pads nummerieren* ordnet die Pad-Nummern lückenlos.
- **Objekte:** Art als Symbol wählen (Trümmer, Schieber, Plattform, Meteorit, Strahl, Fahrzeug, Strömung, Magnet, Schwerkraft, Hitze). Ein Klick auf eine freie Stelle setzt sie, **Ziehen bestimmt Größe oder Richtung** (Fläche, Radius, Fallweg, Breite, Bewegungsweg). Ein Klick auf ein vorhandenes Objekt wählt es, Ziehen verschiebt es; Rechtsklick (X, B) entfernt das Objekt unter dem Zeiger. Alle Zahlen (Position, Größe, Weg, Takt, Versatz, Stärke …) stehen als Zeilen mit **<** Wert **>**; Gedrückthalten wiederholt und wird schneller. Mit Controller oder Tastatur wählst du den Wert selbst an und änderst ihn mit Links/Rechts (halten wiederholt), LB/RB bzw. Umschalt oder Bild auf/ab machen große Schritte, A/Enter schaltet Schalter um. Bei Zonen bedeutet Pulstakt 0 „dauerhaft“. Die Vorschau zeigt die Hindernisse live in Bewegung. Tore malst du auf der Karte, ihre Zeiten stellst du hier ein.
- **Fremdfahrzeuge:** *Fahrzeug* wählen, dann nacheinander klicken: **Eingang** (am besten in der Wand), beliebig viele **Zwischenpunkte** in freiem Raum, und ein Klick auf **Wand oder Rand** setzt den **Ausgang** (wird automatisch erkannt; Y bzw. Tab beendet den Pfad am letzten Punkt, Rechtsklick bzw. B bricht ab). Die Rollen stehen an den Punkten. Einzelne Pfadpunkte lassen sich später ziehen, Rechtsklick auf einen Punkt entfernt ihn (mindestens zwei bleiben).
- **Level:** Optik (Sektor), Dunkelheit und die **Aufträge**. Automatisch erzeugte Aufträge stehen als Text da („Pad 2 nach 3“); sie lassen sich würfeln oder mit *Eigene Aufträge* in eine Liste übernehmen: je Zeile Start und Ziel wechseln (ein Klick), *Z* = zerbrechlich (darf zur Klinik, „–“ = normal), *+* fügt einen Auftrag ein, *×* löscht ihn. Der letzte Auftrag führt zum Ausgang. Verstöße gegen die Regeln meldet die Statuszeile.

| | Maus | Tastatur | Controller |
|---|---|---|---|
| Bewegen | Mauszeiger | Pfeile / WASD | Stick, Steuerkreuz |
| Zeichnen / Löschen | links / rechts | Leertaste / X, Rücktaste | A / B |
| Auswahl (Karte: Feld, Objekte: Art) | Rad, Symbole | Q/E, 1–9 (Pads) | LB / RB |
| Zeichenmodus bzw. nächstes Objekt | Modusknopf, Umschalt, Doppelklick | Tab | Y |
| Seite wechseln | Reiter | F1 / F2 / F3 | LT / RT |
| Rückgängig / Wiederholen | Knöpfe *Rückgängig* / *Wiederholen* | Strg+Z / Strg+Y | L3 / R3 (Stickklick) |
| Testflug / Vorschau | Knöpfe | T / V | Start / Back |
| Autopilot sieht zu | Knopf *Autopilot* | F6 | X → Leiste unten → *Autopilot* |
| Bedienfelder an/aus | Klick | Esc | X (in den Feldern auch B) |
| Nächsten Fehler zeigen | Knopf *Fehler (n)* | F | X → *Fehler (n)* |
| Hilfe mit allen Tasten | Knopf *Hilfe* | H | Back halten |

Oben links steht, welches Feld bzw. Objekt unter dem Zeiger liegt (mit Koordinaten), oben rechts, ob du gerade zeichnest oder in den Bedienfeldern bist. Mit Controller oder Tastatur nennt das Feld unter der Palette das angewählte Symbol. Solange nicht gespeichert werden kann, trägt *Speichern* ein Schloss (Fehler im Level oder noch nicht selbst gelöst). *Zurück* mit ungespeicherten Änderungen fragt nach: *Speichern*, *Verwerfen* oder *Weiter bearbeiten*. Ist in den Optionen *Bewegung reduzieren* an, blinken Fehlerstellen nicht, sondern bleiben ruhig markiert.

## Level weitergeben und einlesen

- **Code:** *Code kopieren* legt einen Text der Form `GFL1:…` in die Zwischenablage (etwa 1 KB). Der Empfänger wählt *Aus Zwischenablage*. Das funktioniert auch mit dem Controller.
- **Datei:** Level liegen als `<ID>.gflevel` im Ordner `user://community/` (Knopf *Ordner öffnen*). Eine Datei dorthin kopieren genügt; mit *Aus Zwischenablage* lässt sich auch der Dateiinhalt einfügen.
- **Original kopieren:** Jedes mitgelieferte Level lässt sich als eigene Kopie anlegen und per Hand verändern. Die Kopie trägt den Vermerk `derived_from`.
- **Original ändern (Debug-Modus, nur beim Start aus dem Projektordner):** Mit dem Knopf *Original ändern* öffnet der Editor eines der 99 mitgelieferten Level. *Speichern* schreibt die Änderung in `data/levels/<id>.json` (sofort im Spiel gültig), trägt die Prüfsumme in `data/levels.sha256` nach und verwirft die gespeicherten Geisterläufe dieses Levels. Es gilt dieselbe Regel: erst selbst lösen, dann speichern. Unverändert Gebliebenes (Richtzeiten der Aufträge, Mechanik-Liste, Zahlenformate) bleibt Zeichen für Zeichen erhalten. Sektor und Index sind gesperrt (Levelnummer). Ein erneutes Ausführen der Level-Erzeuger (`tools/build_sector.py`) überschreibt solche Handänderungen; zurück zur ausgelieferten Fassung geht es mit `git checkout data/levels/<id>.json` und `python3 tools/level_hashes.py`.
- Beim Einlesen wird alles geprüft (siehe unten). Ungültiges wird mit einer Begründung abgelehnt. Die Lösbarkeit prüft die Regelprüfung (Flugwege für alle Fahrten); der Autopilot ist dafür kein Maßstab – ein Mensch fliegt vieles besser.

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

# Level editor and your own levels (English)

Under **Level editor** in the main menu you find your own and shared levels. They are separate from the campaign: they change neither progress nor medals, statistics or unlocks, and the 99 bundled levels are never modified. You fly the standard taxi (no garage upgrades) with a full tank and five lives. Only your best time, best score and the number of flights per level are saved.

## Building levels (editor)

*Level editor → New level* (or *Edit* for a copy of an existing level). The map shows the real game view; the status line reports live whether the level is valid. The exit gate sits fixed in the middle at the top, jobs are generated automatically (*Re-roll jobs* for others). Doors, moving obstacles, zones and darkness of an edited level are preserved. *Test flight* starts the level (as a draft, not yet saved), then returns to the editor; *Autopilot* lets the autopilot solve it while you watch (no best time is recorded; it flies briskly and avoids fuel pumps but does not manage every solvable level). If the level has errors, the affected objects blink. Two free cells below the exit gate are enough; rock and spikes may follow behind them. On a controller LT/RT jump to the Level page and straight into its buttons; A on *Name* or *Author* opens an on-screen keyboard. A moving platform only blocks the area it always covers, not its whole travel range. The opened level stays unchanged; *Save* creates your own version (further saves in the same session replace it). There is one pen for everything; what it draws is picked from a palette of symbols (the name is shown as a tooltip and label). The right panel has three pages (F1–F3, controller LT/RT): *Map* (tiles incl. gates a–e; the pen draws lines, **Shift+drag** a rectangle, **double-click** fills; on the controller and with Tab the mode button cycles line/rectangle/fill), *Objects* (pick a kind as a symbol; click an empty spot to place it, **drag to set size or direction**; click an object to select/move it; right-click, X or B removes the object under the pointer; all numbers as rows with < value >; holding repeats and speeds up; with a controller or keyboard select the value and change it with Left/Right, LB/RB or Shift/Page up/down for big steps, A/Enter toggles switches) and *Level* (look, darkness and a job table: start, destination, Z = fragile, – = normal, + insert, × delete; automatic jobs are listed as text). **Foreign vehicles:** pick *Vehicle*, then click the **entry** (best inside the wall), any number of **waypoints** in free space, and a **wall or edge** sets the **exit** (detected automatically; Y/Tab ends the path at the last point, right-click/B cancels). Controls: mouse (left draws, right erases, wheel selects, *Undo*/*Redo*/*Help* buttons), keyboard (arrows/WASD move, Space draws, X erases, Q/E select, Tab mode or next object, N new object, Ctrl+Z/Y, T test flight, V preview, F1–F3 pages, F next error, H help, Esc toggles the panels) and controller (stick/D-pad move, A draw, B erase, LB/RB select, Y mode or next object, LT/RT page, L3/R3 undo/redo, Start test flight, Back preview, hold Back for help, X toggles the panels; B leaves the panels again). The top left shows the tile or object under the pointer with its coordinates, the top right whether you are drawing or in the panels; with a controller or keyboard the field below the palette names the highlighted symbol. While saving is not possible, *Save* shows a lock; *Errors (n)* next to the status line jumps to each problem. *Back* with unsaved changes asks: *Save*, *Discard* or *Keep editing*. With *Reduce motion* in the options, error spots are marked steadily instead of blinking. A test flight runs the level as an unsaved draft. **Only levels you have solved yourself can be saved:** fly the level by hand in a test flight and finish every trip through the exit (the autopilot does not count); only then does the editor unlock *Save*. The proof applies to exactly that content, so any change needs a new flight. When saved, the level keeps the best time and score of your test flights. Imported levels (clipboard, file) and copies of originals are not affected. **Gates:** The leaves move vertically when there is wall above and below the gate, otherwise horizontally; the gate parameter *Leaves* (auto / vertical / horizontal) sets it explicitly. *Sweep* works in both directions, also for the autopilot. In debug mode the level page has a *Solve by hand: required / skipped* switch: when skipped, you can save without a new test flight (for small changes; applies to originals and your own levels, survives test flights and is reset when debug mode is turned off).

## Sharing and importing

- **Code:** *Copy code* puts a `GFL1:…` text on the clipboard (about 1 KB). The recipient picks *From clipboard*. This works with a controller as well.
- **File:** Levels are stored as `<ID>.gflevel` in `user://community/` (button *Open folder*). Copying a file there is enough; *From clipboard* also accepts the file's content.
- **Copy an original:** Any bundled level can be saved as your own copy and edited by hand. The copy carries a `derived_from` note.
- **Edit an original (debug mode, only when started from the project folder):** The button *Edit an original* opens one of the 99 bundled levels in the editor. *Save* writes the change to `data/levels/<id>.json` (effective in the game right away), updates the checksum in `data/levels.sha256` and discards the stored ghost runs of that level. The same rule applies: solve it yourself first, then save. Whatever stays unchanged (job target times, mechanics list, number formats) is kept character for character. Sector and index are locked (level number). Re-running the level generators (`tools/build_sector.py`) overwrites such hand edits; to get back to the shipped version use `git checkout data/levels/<id>.json` and `python3 tools/level_hashes.py`.
- Everything is validated on import (see below) and rejected with a reason if invalid. Solvability is judged by the rules check (flight routes for every leg); the autopilot is not a yardstick – a human flies much better.

## File format (`.gflevel`, JSON)

See the German example above. `sector` (1–9) chooses the look (background, music, ambience, price level), `index` (1–11) the price level within the sector. `map` has 10 to 22 rows of 16 to 40 equal-length characters: `#` rock, `.` air, `1`–`9` passenger pads, `F` fuel pad, `L` life station, `H` hospital, `S` start, `E` exit gate, `^` spikes, `P` pump, `a`–`e` sliding gates. `jobs` list trips in order (`to: "exit"` only in the last one); missing jobs are generated and target times (`par`) are always computed from the flight path. `doors`, `movers` (at most 24 of `debris`, `slider`, `pad`, `meteor`, `beam`, `vehicle`) and `zones` (at most 16 of `wind`, `magnet`, `gravity`, `heat`) work as in the bundled levels (`data/levels/*.json`); numbers are clamped to sensible ranges. Anything else in the file is discarded. The level ID (`c_` plus ten hex characters) is a hash of the validated content: changing a level creates a new level with its own best times.

A small example to try and learn from: [`community/zwergenhafen.gflevel`](community/zwergenhafen.gflevel) (copy the content to the clipboard and pick *From clipboard*, or put the file into the folder).

## Validation rules

Exactly one start `S`, one exit gate `E` centred at the top, 2 to 9 passenger pads numbered from 1 without gaps and at least 4 tiles wide, jobs between existing pads (fragile passengers may go to the hospital `H`), the first passenger does not wait on the start pad and none on the previous destination pad, and every trip needs a flight path. A pad without room for its shelter is only a warning.

## Licence

Your own levels belong to you. Copies of bundled levels are adaptations of this project's content and fall under **CC BY-NC-SA 4.0** (the default in the file). When sharing a level, name the author in `author`. The game does not distribute or host community levels.
