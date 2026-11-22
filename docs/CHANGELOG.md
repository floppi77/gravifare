# Änderungsliste · Changelog

Die Texte stehen in den GitHub-Release-Notes („Neu in x“ / „What's new in x“), hier zur Nachlese.
The text of each section is used in the GitHub release notes ("Neu in x" / "What's new in x").

## 1.8.1

### Deutsch

**Neu**
- GraviFare läuft jetzt auch im Browser: das vollständige Spiel mit allen 99 Leveln und allen Spielmodi, direkt auf itch.io spielbar (nur Englisch, Spielstände bleiben im Browser gespeichert). Die Download-Fassung für Windows, Linux und macOS bleibt mit sieben Sprachen erhalten

**Fehlerbehebungen**
- Sonderzeichen wie ★, ✓ und die Pfeiltasten werden jetzt mit eigenen Ersatzschriften dargestellt statt mit den Schriften des Systems; vorher konnten dort Kästchen stehen
- Spielstandwahl: Die Überschrift wird nicht mehr von den Rahmen der Disketten überdeckt

### English

**New**
- GraviFare now runs in the browser too: the complete game with all 99 levels and every mode, playable right on itch.io (English only, saves are kept in the browser). The download version for Windows, Linux and macOS stays, with seven languages

**Bug fixes**
- Special characters such as ★, ✓ and the arrow keys now use bundled fallback fonts instead of the system's fonts; boxes could show up before
- Save slot selection: the heading is no longer covered by the frames of the floppy disks

## 1.8.0

### Deutsch

**Neu: Sonderschicht – der Roguelike-Modus**
- Neuer Spielmodus neben Tag- und Nachtschicht: 9, 18 oder 27 Etappen durch alle neun Sektoren. An jeder Kreuzung wählst du einen Auftrag – ruhig, mittel, riskant oder als Pakt –, jeweils mit Zwischenfällen, Gefahrenzulage, Wertungsfaktor und Prämie; die Karten zeigen das Level als Vorschaubild
- 18 Zwischenfälle, die es nur hier gibt, darunter heiße Düse, Leck im Tank, klemmendes Fahrwerk, träge Düsen, schwache Seitendüse, Schmierfilm, Funkloch, wackelige Instrumente, Säule im Takt, Barzahler und Steuerprüfung. Angeboten werden sie nur auf Leveln, die damit lösbar bleiben
- Werkstatt-Halt nach jedem Sektor: 46 Ausstattungsteile (gewöhnlich, selten, legendär) für Düsen, Tank, Hülle, Landung, Fahrgäste und den Lauf selbst; neu würfeln oder einen Zwischenfall streichen
- Sechs Lizenzen, Dienstgrade 0 bis 20 mit Namen, Überstunden-Stufen, Bestenliste je Spielstand mit nachvollziehbarer Punktzahl und neun eigene Erfolge
- Seed als Code frei wählbar, Abbrechen jederzeit, Fortsetzen am Beginn der Etappe
- Lizenz und Ausstattung sind am Taxi zu sehen; das Pausenmenü zeigt alle Wirkungen in Zahlen
- Frei nach Abschluss von Sektor 6 – oder beim Anlegen eines neuen Spielstands sofort, für alle, die nur den Roguelike-Modus spielen möchten
- Getrennt von der Karriere: Credits, Werkstatt, Medaillen und Statistik bleiben unberührt

**Spiel**
- Neuer Spielstand: Übersicht aller Spielmodi mit kurzer Erklärung und wann sie frei werden
- Hauptmenü dreispaltig; Spielstand, Ko-fi und „Bug melden“ als Symbole unten rechts (mit Hilfetext, auch per Controller)
- Anzeige oben: der Spielmodus als Symbol statt als Schriftzug, lange Levelnamen werden gekürzt
- Wandernde Schleusen (z. B. Level 52 „Gussform“) schieben das Taxi jetzt mit, statt es hinauszuschleudern; bisherige Bestflüge und Geister laufen unverändert
- Level 72 „Expresslinie“ umgebaut: deutlich mehr Verkehr auf zwei Routen

**Level-Editor**
- Fahrzeugrouten: Zwischenpunkte lassen sich über einen „+“-Griff in der Streckenmitte einfügen, mehrere Routen können denselben Eingang nutzen

### English

**New: Overtime – the roguelike mode**
- A new mode next to Day and Night shift: 9, 18 or 27 stages through all nine sectors. At every crossing you pick a job – calm, medium, risky or a pact – each with incidents, hazard pay, a score multiplier and a reward; the cards show a preview image of the level
- 18 incidents found only here, among them hot jet, leaky tank, sticky gear, sluggish jets, weak side jet, slick hull, radio blackout, shaky gauges, timed pump, cash only and tax audit. They are only offered on levels that stay solvable with them
- Pit stop after every sector: 46 parts of gear (common, rare, legendary) for jets, tank, hull, landing, passengers and the run itself; reroll or strike an incident
- Six licenses, ranks 0 to 20 with names, overtime levels, a leaderboard per save with a transparent score, and nine achievements of its own
- Seed as a code of your choice, quit any time, continue at the start of the stage
- License and gear are visible on the taxi; the pause menu shows every effect in numbers
- Unlocked after completing sector 6 – or right away when creating a new save, for everyone who only wants to play the roguelike mode
- Separate from the career: credits, workshop, medals and statistics stay untouched

**Game**
- New save: an overview of all modes with a short explanation and when they unlock
- Main menu in three columns; save slot, Ko-fi and "Report a bug" as icons in the bottom right (with help text, controller included)
- Top bar: the game mode as an icon instead of a label, long level names are shortened
- Wandering locks (e.g. level 52 "Casting Mold") now push the taxi along instead of throwing it out; existing best flights and ghosts play back as before
- Level 72 "Express Line" rebuilt: a lot more traffic on two routes

**Level editor**
- Vehicle routes: waypoints can be inserted with a "+" handle in the middle of each segment, and several routes can share one entry

## 1.7.1

### Deutsch

**Fehlerbehebungen**
- Rausgeworfene Fahrgäste liefen manchmal durch die Luft zu ihrer Herkunftsplattform. Jetzt gilt: Steht oder schwebt das Taxi dicht über einer Plattform, läuft der Fahrgast nur zum Häuschen dieser Plattform; ist darunter keine Plattform, stürzt er ab – auch aus geringer Höhe
- Fahrgäste, die nach einer perfekten Landung am Häuschen winken, fahren auf einer beweglichen Plattform jetzt mit, statt in der Luft zu hängen
- Erfolge: Mit der Maus lässt sich wieder blättern (Pfeile und Mausrad) und zurückgehen
- Maus: Ein Klick führt jetzt auch in der Levelauswertung, bei Game Over, beim Levelwechsel, im Finale, in Einspielern und beim Einflug in die Werkstatt weiter; die Credits haben einen „Zurück“-Knopf
- Controller und Pfeiltasten: Menüs mit zwei Spalten springen beim Wechsel zwischen links/rechts und oben/unten nicht mehr quer

### English

**Bug fixes**
- Ejected passengers sometimes walked through the air back to the platform they came from. Now: if the taxi stands on or hovers close above a platform, the passenger only walks to that platform's shelter; with no platform below, they fall – even from a low height
- Passengers waving at the shelter after a perfect landing now ride along on a moving platform instead of hanging in mid-air
- Achievements: paging (arrows and mouse wheel) and going back work with the mouse again
- Mouse: a click now also continues on the level results, game over, level transitions, the finale, intro clips and the workshop fly-in; the credits have a "Back" button
- Controller and arrow keys: two-column menus no longer jump diagonally when moving left/right and up/down

## 1.7.0

### Deutsch

**Neu**
- Drei neue Sprachen: Italienisch, Portugiesisch (Brasilien) und Polnisch – alle Texte, Untertitel und eine eigene Sprachausgabe für jede Figur. Damit spricht GraviFare sieben Sprachen
- Hupe (Tastatur H, Controller X, frei belegbar)
- Schwerkraftanzeige im Level: unauffällig mit Symbol, zeigt die Schwerkraft am Ort des Taxis (auch in Schwerkraftzonen)
- Speedrun-Uhr für die Karriere (Optionen › Spiel, Standard aus): Flugzeit samt verlorener Versuche, Zwischenzeit am Ende jedes Sektors mit Abstand zur Bestzeit
- Hinweis auf neue Versionen: Das Spiel fragt einmal, ob es nachsehen darf; mit Zustimmung höchstens einmal am Tag, ohne persönliche Daten
- Statistik: geflogene Strecke
- Neuer Erfolg „Taxi-Ikone“ für alle anderen Erfolge, dazu verborgene Erfolge, die sich erst beim Erreichen zeigen
- Eastereggs hinzugefügt
- Neuer Trailer, aufgenommen in 4K

**Optionen und Bedienhilfen**
- Strom sparen: eigene Bildrate im Hintergrund und in Menüs (15 / 30 / 60 / wie im Spiel, Standard 30); das Spiel selbst läuft unverändert
- Tonausgabe Mono (Bedienhilfen, Standard Stereo)

### English

**New**
- Three new languages: Italian, Portuguese (Brazil) and Polish – all texts, subtitles and a voice of their own for every character. GraviFare now speaks seven languages
- Horn (keyboard H, controller X, rebindable)
- Gravity indicator in levels: unobtrusive with an icon, shows the gravity where the taxi is (gravity zones included)
- Speedrun clock for the career (Options › Game, off by default): flight time including lost attempts, split at the end of every sector with the gap to your best
- New version notice: the game asks once whether it may check; with your consent at most once a day, without personal data
- Statistics: distance flown
- New achievement "Taxi icon" for all other achievements, plus hidden achievements that only reveal themselves once unlocked
- Easter eggs added
- New trailer, recorded in 4K

**Options and accessibility**
- Power saving: separate frame rate in the background and in menus (15 / 30 / 60 / same as in game, default 30); the game itself runs as before
- Mono audio output (Accessibility, default stereo)

## 1.6.6

### Deutsch

**Neu**
- Neue Credits: Ein Taxi zieht ein Werbebanner mit der Kategorie über den Himmel, unten halten Fahrgäste die Einträge auf Schildern und Spruchbändern hoch – jedes Mal mit anderer Lackierung und aus einer anderen Richtung, zum Schluss winken alle
- Blender ist in den Credits mit eigener Kategorie „3D-Grafik“ genannt
- Levelauswertung: Die Abrechnung zeigt jetzt auch die im Level bezahlten Spritkosten (auch in der Nachtschicht)

**Level-Editor**
- Eigene Aufträge springen beim Durchschalten einer Plattformzahl nicht mehr auf die automatischen Ziele zurück
- Rechtsklick auf Start oder Ziel eines Auftrags schaltet eine Zahl zurück, Linksklick weiter
- Das Krankenhaus lässt sich bei jedem Auftrag als Ziel wählen; der Fahrgast wird dabei zum Patienten

**Leistung**
- Level mit Magnetfeldern und anderen schrägen Linien zeichnen schneller (in 4K bis zu ein Drittel weniger Rechenzeit je Bild), bei gleichem Bild
- Testflug mit Autopilot im Editor ruckelt vor Toren nicht mehr

**Level**
- Level 94 überarbeitet (Karte und Aufträge), neue Vorschau in der Levelauswahl

### English

**New**
- New credits: a taxi tows an advertising banner with the category across the sky while passengers below hold up the entries on signs and banners – every pass with a different paint job and from a different direction, and everyone waves at the end
- Blender is credited with its own "3D graphics" category
- Level results: the ledger now also shows the fuel you paid for in the level (night shift too)

**Level editor**
- Custom jobs no longer jump back to automatic destinations while you cycle a platform number
- Right-click on a job's start or destination steps one number back, left-click steps forward
- The hospital can be picked as a destination for any job; the passenger becomes a patient

**Performance**
- Levels with magnetic fields and other diagonal lines draw faster (up to a third less time per frame in 4K), with an identical picture
- Autopilot test flights in the editor no longer stutter in front of gates

**Levels**
- Level 94 reworked (map and jobs), new preview in level select

## 1.6.5

### Deutsch

**Neu**
- Französisch und Spanisch: alle Texte und die komplette Sprachausgabe (Fahrgäste, Tankwart, Zentrale, Fluglehrer, Einspieler); Sprache über die Flaggen im Hauptmenü oder in den Optionen
- 26 Erfolge mit eigener Übersicht in der Statistik; Fortschritt von früher zählt rückwirkend
- Bestflug ansehen: In der Levelauswahl spielt Y bzw. V die eigene Bestzeit als Wiedergabe im Spiel ab
- Bedienhilfen (Optionen): Farbsehschwäche (Ampel, Tank, Spritpreis und Lampen in Blau, Gelb und Purpurrot) und große Schrift für HUD, Untertitel, Flugschule und Einspieler
- Bug melden im Hauptmenü: öffnet eine E-Mail mit Betreff und Systemangaben, dazu der Protokollordner
- Beim Spielstart ein Hinweis, dass ein Controller empfohlen wird (Deutsch und Englisch zugleich)
- PlayStation-Controller werden erkannt und zeigen ✕ ○ □ △ statt A B X Y (einstellbar)

**Grafik**
- Neues Taxi: Das gezeichnete Taxi bekommt in Blender Licht, Glanz und Rundung und dreht sich beim Seitenflug leicht ein – in allen Lackierungen und Pixelgrößen
- Ampel am Wartehäuschen mit Haken (grün) und X (rot)
- Levelauswahl: Titel und Hinweise werden nicht mehr von Knöpfen überdeckt

**Flugschule**
- Wer eine Aufgabe schon während der Erklärung erledigt, wird mit einem von drei Sprüchen gelobt, und es geht gleich weiter – auch beim Tanken (nach dem Abheben) und bei einem Absturz schon während der Erklärung zur Landung
- Ein an der Taxistation gekauftes Taxi bleibt jetzt erhalten

**Nachtschicht**
- Das Ergebnis jeder Karte zeigt jetzt auch die Abrechnung: Fahrpreise, Reparatur, Ersatztaxis, verpasste Fahrgäste und das Ergebnis

**Korrekturen**
- Dunkle Level: Die nächste Abholplattform leuchtet erst, wenn der Fahrgast dort erscheint, nicht schon nach dem Absetzen des vorigen (Karriere und Nachtschicht)
- Level 49 überarbeitet
- Level mit Magnetfeldern (z. B. Level 41) laufen deutlich flüssiger: Die Felder kosten nur noch ein Viertel der Zeichenzeit

### English

**New**
- French and Spanish: all texts and full voice-over (passengers, attendant, dispatch, flight instructor, clips); pick the language with the flags in the main menu or in the options
- 26 achievements with their own overview in the statistics; earlier progress counts retroactively
- Watch best run: in level select, Y or V replays your best time inside the game
- Accessibility (options): colour-blind mode (lights, fuel, fuel price and lamps in blue, yellow and crimson) and large text for HUD, subtitles, flight school and clips
- Report a bug from the main menu: opens an e-mail with subject and system details, plus the log folder
- At startup a note recommends a controller (German and English at once)
- PlayStation controllers are detected and show ✕ ○ □ △ instead of A B X Y (configurable)

**Graphics**
- New taxi: the hand-drawn taxi gets lighting, gloss and roundness from Blender and turns slightly when flying sideways – in all paints and pixel sizes
- Shelter lamps with a check mark (green) and an X (red)
- Level select: title and hints are no longer covered by buttons

**Flight school**
- Finish a task while the instructor is still explaining and he praises you with one of three lines and moves on – also when refuelling (after taking off again) and when crashing during the landing explanation
- A taxi bought at the taxi station is now kept

**Night shift**
- Each map result now also shows the ledger: fares, repair, replacement taxis, missed passengers and the balance

**Fixes**
- Dark levels: the next pickup platform only lights up once the passenger appears there, not right after dropping off the previous one (career and night shift)
- Level 49 reworked
- Levels with magnet fields (e.g. level 41) run much smoother: the fields take only a quarter of the drawing time

## 1.6.1

### Deutsch

**Spiel**
- Keine wiederholten Aufträge mehr: In Nachtschicht, Tagschicht und Tagesflug kommt dieselbe Fahrt (z. B. 5 → 7) nie zweimal hintereinander, und solange es freie Fahrten gibt, auch nicht zweimal in einem Level
- Auch in der Karriere: In 23 Levels wurden doppelte Fahrten durch andere ersetzt, Strecken und Richtzeiten bleiben ähnlich. Bestzeit-Geister dieser Level beginnen neu

**Grafik**
- Dunkle Level (Sektor 8, Nachtschicht, Nebel): Plattformen leuchten nicht mehr, nur noch die Zielplattform und die Ampellampen der Häuschen
- Neue Bilder der Projektseite (HUD mit den neuen Anzeigen, neues Taxi)

### English

**Game**
- No more repeated jobs: in Night Shift, Day Shift and the daily flight the same ride (e.g. 5 → 7) never comes twice in a row, and as long as free rides remain, not twice in a level either
- Career too: in 23 levels duplicate rides were replaced by other ones, distances and par times stay similar. Best-time ghosts for these levels start over

**Graphics**
- Dark levels (sector 8, night shift, fog): platforms no longer glow, only the target platform and the shelter lamps do
- New project page images (HUD with the new gauges, new taxi)

## 1.6.0

### Deutsch

**Grafik**
- Alles im Level wird in der Pixelgröße des Bildschirms eigens gezeichnet (720p bis 2160p, 2 bis 6 Bildschirmpunkte je Einheit) und nicht mehr gestreckt: Taxi, Fels und Plattformen aller Sektoren, Zapfsäulen, Tore, Schieber, Wrackteile, Fahrgäste, Haltestellen, fremde Fahrzeuge, Leuchtreklame und die Taxi-Symbole der Leben. Linien und Schatten liegen auf ganzen Bildpunkten, bei 1440p und 1800p gibt es keine ungleichmäßigen Pixel mehr
- Fahrgäste, Haltestellen und fremde Fahrzeuge sind neu gezeichnet (Front- und Seitenansichten mit durchgehenden Details wie der Haarspange); Trefferflächen und Spielverhalten bleiben gleich
- Neue Tank- und Hüllenanzeige: Der Tank ist hellgrün, wird orange, wenn er knapp wird (Schwelle des Tankalarms), und rot in den letzten 10 %. Die Hülle hat eine eigene Form und eigene Farben (blau, violett, magenta). Beim Piepen des Tankalarms blitzt die Anzeige im selben Takt auf, ein Treffer zeigt kurz, wie viel Hülle er gekostet hat. Auch in den Einspielern sichtbar
- Neues Taxi in jeder Pixelgröße, auch in der Garage und im HUD
- Dunkle Level (Sektor 8, Nachtschicht, Nebel) sind weniger hell: Nur noch die Zielplattform leuchtet kräftig, alle übrigen Plattformen nur schwach
- Levelauswahl: Die Sektor-Reiter füllen sich von links in der Sektorfarbe, der gewählte Sektor ist klar zu erkennen; gezeichnete Levelkarten mit Sternen und Schloss
- Ergebnisansicht nach dem Level neu geordnet: abgedunkelter Hintergrund bis zum Fensterrand, Kopfband, drei Medaillenkarten, eine Karte für die Zeit und eine Abrechnung als Rechnung (Fahrpreise, Reparatur, Ersatztaxi, Verpasst, Ergebnis), Abzüge von 0 gedämpft

**Spiel**
- Verlorene Pflichtfahrgäste (verpasst, gerammt, rausgeworfen) kosten in allen Sektoren den doppelten Fahrpreis, vorher das 4- bis 12-fache. Dazu nehmen alle Strafen eines Levels höchstens 40 % des Guthabens, das Konto fällt dadurch nicht mehr auf 0. Gilt für Karriere, Nachtschicht und Tagschicht, auch für laufende Spielstände; Reparatur und Ersatztaxi bleiben wie bisher
- Die Meldungen zur Strafe nennen den Betrag, der tatsächlich abgezogen wird
- Bestzeit-Läufe bleiben gültig, ihre Strafen werden mit den neuen Regeln nachgerechnet

### English

**Graphics**
- Everything in the level is now drawn in the pixel size of your screen (720p to 2160p, 2 to 6 screen pixels per unit) instead of being stretched: taxi, rock and platforms of every sector, fuel pumps, gates, sliders, wreckage, passengers, shelters, other vehicles, neon signs and the taxi icons for lives. Lines and shadows sit on whole pixels, so 1440p and 1800p no longer show uneven pixels
- Passengers, shelters and other vehicles are redrawn (front and side views with consistent details such as the hair clip); hitboxes and gameplay are unchanged
- New fuel and hull gauges: the tank is bright green, turns orange as it runs low (the same threshold as the low-fuel alarm) and red in the last 10 %. The hull has its own shape and colours (blue, violet, magenta). The gauge flashes in time with the alarm beeps, and a hit briefly shows how much hull it cost. Also shown in the intro clips
- New taxi in every pixel size, in the garage and the HUD as well
- Dark levels (sector 8, night shift, fog) are less bright: only the target platform glows strongly, all other platforms only faintly
- Level select: the sector tabs fill from the left in the sector colour, the selected sector is easy to spot; drawn level cards with stars and a lock
- The result screen after a level is reorganised: darkened background out to the window edge, header band, three medal cards, one card for the time and a payout card laid out as a sum (fares, repairs, replacement taxi, lost, net result), zero deductions shown muted

**Game**
- Lost mandatory passengers (missed, rammed, ejected) now cost twice the fare in every sector, instead of 4 to 12 times. In addition, all penalties of a level take at most 40 % of your credits, so the balance no longer drops to 0. Applies to Career, Night Shift and Day Shift, including saves in progress; repairs and the replacement taxi are unchanged
- The penalty messages show the amount that is actually deducted
- Best-time runs stay valid; their penalties are recalculated with the new rules

## 1.5.0

### Deutsch

**Spiel**
- Sektor 2 (Neon-Schluchten) ist kürzer: In zehn der elf Level gibt es einen Pflichtfahrgast weniger (fünf statt sechs), die Zeitziele sinken entsprechend. Karten und Routen sind unverändert; Bestzeit-Geister dieser Level beginnen neu
- Levelauswahl zeigt den Fortschritt: ein Balken unter jedem Sektor (Gold, wenn alle Sterne geholt sind), dazu geschaffte Level und Sterne des Sektors und insgesamt
- Der Landeassistent am Taxi weicht Wimpeln und Preisschildern aus, statt sie zu verdecken

**Grafik**
- Trümmer sind jetzt Wrackteile: Frachtcontainer, Rumpfplatte mit geborstenem Bullauge und Solarpaneel statt flacher Platten; Schieber sind Panzerplatten mit Bolzen und Lüftungsschlitzen. Trefferflächen unverändert
- Die Einspieler zu neuen Spielelementen laufen vor Hintergrund und Fels des jeweiligen Sektors statt vor einer leeren Fläche
- Das Pausemenü liegt auf einer dunklen Tafel wie die übrigen Menüs
- Ultrawide (21:9, 32:9): Der Rand des Spielfelds läuft stufenlos aus, ohne sichtbare Streifen
- Vorschaubilder der Levelauswahl für alle Level mit Trümmern und Schiebern neu

**Behoben**
- Die Winke-Blase eines wartenden Fahrgasts verdeckte sein Preisschild und das Ziel
- Der Untertitel der Einspieler ließ die Auftragszeile halb durchscheinen
- Die Meldung beim Taxiverlust nannte „Taxi verloren“ doppelt

### English

**Game**
- Sector 2 (Neon Canyons) is shorter: ten of its eleven levels need one mandatory passenger fewer (five instead of six), and the time targets drop accordingly. Maps and routes are unchanged; best-time ghosts for these levels start over
- The level select shows your progress: a bar under each sector (gold once every star is earned), plus cleared levels and stars for the sector and in total
- The landing assist next to the taxi moves out of the way of pennants and fare tags instead of covering them

**Graphics**
- Debris is now wreckage: a cargo container, a hull plate with a shattered porthole and a solar panel instead of flat slabs; sliders are armour plates with bolts and vents. Hitboxes are unchanged
- The intro clips for new game elements play in front of the backdrop and rock of their sector instead of an empty screen
- The pause menu sits on a dark panel like the other menus
- Ultrawide (21:9, 32:9): the edge of the playfield fades out smoothly, without visible bands
- New level-select previews for every level with debris or sliders

**Fixed**
- A waiting passenger's waving bubble covered the fare tag and destination
- The intro clip subtitle let the job line show through
- The message after losing a taxi said "Taxi lost" twice

## 1.4.0

### Deutsch

**Startbildschirm**
- Neuer Startbildschirm vor dem Hauptmenü: das GraviFare-Logo mit wanderndem Glanzstreifen, darunter das Studio „Quantum Abacus Games“ mit animiertem Neon-Abakus und „Made with Godot“
- Jede Taste, jeder Controllerknopf und jeder Mausklick überspringt ihn; mit „Weniger Bewegung“ gibt es nur sanfte Überblendungen
- Das Godot-Logo ist in den Credits mit Urheber und Lizenz genannt

### English

**Splash screen**
- New splash screen before the main menu: the GraviFare logo with a travelling shine, below it the studio "Quantum Abacus Games" with an animated neon abacus and "Made with Godot"
- Any key, controller button or mouse click skips it; with "Reduce motion" it only fades
- The Godot logo is credited with its author and licence in the credits

## 1.3.0

### Deutsch

**Grafik**
- Jeder Sektor hat jetzt einen eigenen Hintergrund für den Flug zwischen den Leveln, passend zum Ziel: Heimatplanet mit Hafenstation, Neon-Kristalle, Schrottgürtel mit Frachterwrack, Magnetar mit Feldlinien und Polarlicht, Sonne mit orbitaler Schmiede, Ozeanplanet mit Gezeitenstrom, Ringstation über goldenen Wolken, Ringplanet in der Finsternis und ein Schwarzes Loch mit echter Lichtablenkung
- Die Motive liegen in Tiefenebenen und ziehen je nach Entfernung mit (Parallaxe); ferne Sterne liegen hinter den Planeten
- Die alten, immer gleichen Planeten im Zwischenflug entfallen

### English

**Graphics**
- Every sector now has its own background for the flight between levels, matching the destination: home planet with a harbour station, neon crystals, a scrap belt with a freighter wreck, a magnetar with field lines and aurora, a sun with an orbital forge, an ocean planet with a tidal stream, a ring station above golden clouds, a ringed planet in eclipse and a black hole with real light bending
- The scenery sits in depth layers and drifts at its own speed (parallax); distant stars stay behind the planets
- The old, always identical planets of the transit flight are gone

## 1.2.2

### Deutsch

**Level**
- Balanceanpassungen in Sektor 7 (Level 69, 70, 71, 74, 75 und 76), neue Vorschaubilder in der Levelauswahl

### English

**Levels**
- Balance changes in sector 7 (levels 69, 70, 71, 74, 75 and 76), new previews in level select

## 1.2.1

### Deutsch

**Credits**
- Die Credits nennen jetzt richtig, wer die Level gemacht hat: floppi hat alle 99 Level von Hand gebaut und selbst durchgeflogen. Unter „Entwicklung“ standen sie fälschlich bei der KI-unterstützten Programmierung

### English

**Credits**
- The credits now correctly name who made the levels: floppi built and flew all 99 levels by hand. They were wrongly listed under the AI-assisted development

## 1.2.0

### Deutsch

**Regeln**
- Harte Landung: Es zählt nur noch die Landung beim Absetzen, mit Fahrgast an Bord – das Abholen kostet nichts mehr. Der Abzug beginnt erst, wenn die Landeampel gelb wird (mit Weichem Fahrwerk entsprechend später), bis 30 % an der Grenze
- Beim Bezahlen steht der Abzug getrennt nach Grund: „Harte Landung“, „Treffer“ und „Falsche Plattform“ (vorher hieß alles „Harte Landung“)
- Lava trifft deutlich härter: 9 Schaden alle 0,25 s, schon wenn der Rumpf die Zone berührt
- Der letzte Fahrgast lässt nur noch halb so viel Zeit bis zum Verlassen des Levels (mindestens 22,5 s)
- Notfälle: Die Frist steigt je Sektor von 0,65 × Richtzeit (Sektor 1) bis 1,15 × (Sektor 9), vorher überall 1,3 ×
- Zeitstern: Es zählen ganze Sekunden, so wie die Ergebnistafel sie zeigt (94 s bei „Ziel ≤ 94 s“ bekam vorher manchmal keinen Stern)
- Meisterstern in Sektor 1 schon bei 100 % des Einkommensziels (ab Sektor 2 weiter 110 %)
- Bestzeiten und Geister aus älteren Versionen rechnen weiter mit ihren damaligen Regeln

**Level**
- Neonfinale ist jetzt das letzte Level der Neon-Schluchten (Level 22), die Glasfassade Level 17
- Schluchteingang (Level 12) bekommt Leuchtreklame, und auf allen Neon-Schildern wiederholen sich Wörter nicht mehr
- Level 52, 85, 93 und 96 überarbeitet, neue Vorschaubilder in der Levelauswahl

**Nachtschicht**
- Jede Karte bekommt eine Note von S bis E, in der Auswertung und in der Schlusstabelle; die Noten sind farbig (S Gold, A Grün … E Rot)

**Klang und Musik**
- Level 99 hat ein eigenes Stück: „Endloser Aufstieg“ – eine Steigerung, die nie aufgelöst wird und trotzdem nahtlos weiterläuft; auch im Musikplayer
- Eine perfekte Landung klingt beim Aufsetzen anders: gedämpft, mit Zischen der Federbeine und Einrasten (nicht nach kurzem Hüpfen)

**Bedienung**
- Spielstandsauswahl mit Gamepad: Name und Löschen sind jetzt für alle drei Spielstände erreichbar (Name ↔ Löschen über alle Plätze, hoch zur Diskette, runter zu „Zurück“)

### English

**Rules**
- Hard landing: only the landing at drop-off, with a passenger on board, counts – picking up no longer costs anything. The deduction only starts when the landing gauge turns yellow (later with Soft landing gear), up to 30 % at the limit
- At payment the deduction is listed by reason: "Hard landing", "Hits" and "Wrong platform" (previously everything was called "Hard landing")
- Lava hits much harder: 9 damage every 0.25 s, as soon as the hull touches it
- The last passenger only gives half the time before the level is left (at least 22.5 s)
- Emergencies: the deadline rises per sector from 0.65 × par time (sector 1) to 1.15 × (sector 9), previously 1.3 × everywhere
- Time star: whole seconds count, exactly as shown on the result screen (94 s at "target ≤ 94 s" sometimes did not earn a star)
- Master star in sector 1 already at 100 % of the income target (110 % from sector 2 on)
- Best times and ghosts from older versions are still replayed with their original rules

**Levels**
- Neon Finale is now the last level of the Neon Canyons (level 22), Glass Facade is level 17
- Canyon Mouth (level 12) gets neon signs, and words no longer repeat on the neon signs
- Levels 52, 85, 93 and 96 reworked, new previews in level select

**Night shift**
- Every map gets a grade from S to E, on its result and in the final table; grades are coloured (S gold, A green … E red)

**Sound and music**
- Level 99 has its own track: "Endless Ascent" – a rise that never resolves and still loops seamlessly; also in the music player
- A perfect landing sounds different on touchdown: cushioned, with a hiss of the landing gear and a click into place (not after a short hop)

**Controls**
- Save slot screen with a gamepad: Name and Delete can now be reached for all three slots (Name ↔ Delete across all slots, up to the disk, down to "Back")

## 1.1.1

### Deutsch

**Grafik**
- Neon-Schluchten mit echter Leuchtreklame: Neonallee (13), Neonfinale (17) und Neonlabyrinth (19) tragen Schilder mit Schrift aus Leuchtröhren – waagerechte Banner (HOTEL, NOODLES, BAR, LIVE, TAXI …), senkrechte Katakana-Tafeln (ラーメン, タクシー, ネオン …), Bildzeichen (Cocktail, Ramen, Blitz, Auge, Planet …) und ein großes Hauptschild mit Lauflicht
- Röhren pixelgenau mit hellem Kern, Bloom und gestuftem Schein auf dunklen Tafeln mit Schrauben und Haltern; die Schilder werfen farbiges Licht auf Fels und Taxi
- Einzelne Buchstaben flackern oder sterben kurz weg, manche Schilder schalten sich Zeichen für Zeichen neu ein; bei „Weniger Bewegung“ leuchtet alles ruhig
- Neben den Neon-Strahlen im Neonlabyrinth bleiben die Schilder ruhig und meiden deren Farben, neben Dornen gibt es kein Rosa – Warnungen bleiben eindeutig
- Nur Optik: Karten, Kollision, Physik und Zeiten sind unverändert

**Sonstiges**
- Neue Screenshots auf der Projektseite (u. a. Neon-Schluchten, Notfall, Werkstatt mit Scheinwerfer)

### English

**Graphics**
- Neon Canyons with real neon signs: Neon Avenue (13), Neon Finale (17) and Neon Labyrinth (19) carry signs lettered in glowing tubes – horizontal banners (HOTEL, NOODLES, BAR, LIVE, TAXI …), vertical katakana boards (ラーメン, タクシー, ネオン …), pictograms (cocktail, ramen, lightning, eye, planet …) and a large main sign with chasing lights
- Pixel-perfect tubes with a bright core, bloom and stepped glow on dark boards with bolts and brackets; the signs cast coloured light onto rock and taxi
- Single letters flicker or briefly die, some signs switch back on letter by letter; with "Reduce motion" everything glows steadily
- Next to the neon beams in the Neon Labyrinth the signs stay steady and avoid the beam colours, next to spikes there is no pink – warnings stay clear
- Visual only: maps, collision, physics and times are unchanged

**Other**
- New screenshots on the project page (including Neon Canyons, emergency passengers, workshop with headlight)

## 1.1.0

### Deutsch

**Karriere und Werkstatt**
- Game Over kostet nicht mehr alle Einbauten: Jeder Einbau verliert eine Stufe. Sektor-Neustart, 5 Leben und 0 Credits bleiben
- Werkstatt günstiger: 2.700 / 6.500 / 15.000 Credits (je weiterer Werkstatt 10 % mehr)
- Neuer Einbau „Scheinwerfer“: größerer Lichtkreis um das Taxi in dunklen Leveln, +15 % je Stufe, nur in der Karriere
- Tanken: Unter 35 % gibt es Sprit nur noch gratis, wenn das Geld nicht reicht – wer zahlen kann, zahlt. Ohne Geld tankt die Station wie bisher bis 35 %
- Knapp vorbei mit Fahrgast an Bord bringt ein kleines Trinkgeld (2 % des Fahrpreises, höchstens drei Mal je Fahrt)

**Neue Fahrgäste**
- VIP (goldene Krone): zahlt fast das Doppelte, wartet nur halb so lange, harte Landungen und Treffer kosten doppelt
- Notfall (rotes Kreuz mit Frist in Sekunden): zahlt das Doppelte, muss vor Ablauf der Frist am Ziel sein
- Beide als seltene Zusatzfahrgäste in allen Sektoren und als Pflichtfahrgäste in den Leveln ab Sektor 4 (VIP) bzw. 6 (Notfall); je ein Einspieler beim ersten Auftreten

**Nachtschicht**
- Frei, sobald alle Level der Sektoren 1 bis 4 geschafft sind (vorher alle 99)

**Grafik**
- Das Taxi ist in seiner echten Größe neu gezeichnet und erscheint pixelgenau (vorher verkleinert, dabei fielen Pixelzeilen weg); Lackierungen, Aufkleber, Werkstatt, Garage und der Verkehr ziehen mit
- Jeder Sektor hat sein eigenes Felsmaterial – Metallplatten, Kristallfels, Rost und Flickblech, vereister Stahl, Basalt mit Glutadern, bewachsener Unterwasserstahl, Beton und Fliesen, überwucherter Stein, rissiges Gestein – mit Kanten, runden Ecken und Abwechslung im Inneren
- Ultrawide (21:9, 32:9): Das Spielfeld läuft an den Seiten weich in den Hintergrund aus statt hart zu enden
- Hindernisse in Pixelgrafik: Trümmer, Schieber und fahrende Plattformen aus eigenem Kachelblatt mit Warnfarben; Wind, Strömung, Magnetfelder, Schwerkraftpfeile und Verkehrspfade liegen sauber im Pixelraster statt als weiche Linien
- Leben im Hintergrund: ferner Verkehr, Blinklichter und Teilchen je Sektor, dezent und bei „Weniger Bewegung“ still
- Menüs: einheitliche Titel in Pixelschrift, die Garage zeigt das Taxi groß mit Landefeld, Optionsknöpfe füllen die Tafel

### English

**Career and workshop**
- Game over no longer removes all upgrades: every upgrade loses one level. Sector restart, 5 lives and 0 credits stay
- Cheaper workshop: 2,700 / 6,500 / 15,000 credits (10 % more at each further workshop)
- New upgrade "Headlight": a larger circle of light around the taxi in dark levels, +15 % per level, career only
- Refuelling: below 35 % fuel is only free when you cannot pay – whoever can pay, pays. Without money the station still fills up to 35 %
- A close call with a passenger on board earns a small tip (2 % of the fare, at most three times per trip)

**New passengers**
- VIP (golden crown): pays almost double, only waits half as long, hard landings and hits cost double
- Emergency (red cross with a deadline in seconds): pays double, must reach the destination before the deadline
- Both appear as rare extra passengers in all sectors and as required passengers in levels from sector 4 (VIP) and 6 (emergency); one intro clip each on first appearance

**Night shift**
- Unlocked once all levels of sectors 1 to 4 are completed (previously all 99)

**Graphics**
- The taxi is redrawn at its real size and shows pixel-perfect (it used to be scaled down, losing pixel rows); paint jobs, stickers, workshop, garage and traffic follow
- Every sector has its own rock material – metal plates, crystal rock, rust and patched sheet metal, icy steel, basalt with glowing veins, overgrown underwater steel, concrete and tiles, overgrown stone, cracked rock – with edges, rounded corners and variety inside
- Ultrawide (21:9, 32:9): the playfield fades softly into the background at the sides instead of ending abruptly
- Obstacles in pixel art: debris, sliders and moving platforms from their own tile sheet with warning colours; wind, currents, magnetic fields, gravity arrows and traffic paths sit cleanly on the pixel grid instead of soft lines
- Life in the background: distant traffic, blinking lights and particles per sector, subtle and still with "Reduce motion"
- Menus: consistent pixel-font titles, the garage shows the taxi large on a landing pad, option buttons fill the panel

## 1.0.1

### Deutsch

**Fehlerbehebung**
- Tagschicht: Das Level des Tages hing vom eigenen Fortschritt ab, Spieler mit anderem Stand bekamen eine andere Karte. Jetzt wählt das Datum ein Level aus allen 99, für alle am selben Tag dasselbe – auch wenn man es noch nicht geschafft hat
- Der Tagesbestwert bleibt erhalten, ein neuer Tag setzt ihn wie bisher zurück

**Entwicklung**
- Neue Dev-Schalter zum Prüfen und für Screenshots (`--shift-quality`, `--options`, `--confirm`, `--hold-action`, `--click`)

### English

**Bug fix**
- Day shift: the level of the day depended on your own progress, so players at a different stage got a different map. The date now picks one level out of all 99, the same for everyone on the same day – even if you have not completed it yet
- The best score of the day is kept, a new day resets it as before

**Development**
- New dev switches for checking and screenshots (`--shift-quality`, `--options`, `--confirm`, `--hold-action`, `--click`)

## 1.0.0

### Deutsch

**Version 1.0**
- GraviFare ist in Version 1.0 angekommen: 99 Level in 9 Sektoren, Karriere, Nachtschicht, Tagschicht, Werkstatt, Garage und Level-Editor, auf Deutsch und Englisch, mit Tastatur und Controller

**Nachtschicht neu**
- Eine Schicht aus 9 Karten, je eine pro Sektor von 1 bis 9; Karten, Aufträge und Schwerkraft stehen pro Tag fest und sind für alle gleich. Ein Versuch pro Tag, Start mit 5 Taxis
- Nur Pflichtfahrgäste (3 Fahrten auf Karte 1 bis 7 auf Karte 9), keine Ungeduld, Lebensstationen außer Betrieb, kein Neustart einer Karte
- Die Schwerkraft ändert sich von Karte zu Karte, bleibt aber immer fliegbar; es wird dunkler: 25 % auf Karte 1, 8 % mehr je Karte
- Wertung je Karte bis 80 Punkte (Wartezeit 25 – in späteren Sektoren großzügiger –, Landungen mit Fahrgast 25, Hülle 20, knappe Vorbeiflüge bis 10), dazu 2 Punkte je übrigem Taxi (bis 10) und 1 Punkt je 1500 übrige Credits (bis 10): höchstens 100 Punkte und Noten von S bis E
- Auswertung mit Tabelle aller Karten, Zeit je Karte und Gesamtzeit (ohne Wertung), Datum und Uhrzeit (24 h deutsch, 12 h englisch)
- Knopf „Screenshot erstellen“ (Maus oder Y/E) speichert die Auswertung als `JJMMTT_nachtschicht_name.png` neben dem Spiel
- Eigenes Finale der Nachtschicht: Anflug mit ausgefahrenem Fahrwerk, Ansage der Zentrale zur Note, der Fahrer steigt aus der Kuppel, springt aufs Pad, geht über die Brücke und winkt, dazu ein eigenes Musikstück als Schleife
- Während die Auswertung steht, schweigen Triebwerk und Tankalarm

**Tagschicht (früher Tagesflug)**
- Jede Karte ist hell, auch aus dem dunklen Sektor
- Je Wochentag eine Tagesregel, jede Woche neu gemischt: Windtag (Böen über die ganze Karte), Nebel (Sicht nur um das Taxi), Spiegelwelt, Dünner Tank (der Tank fasst nur die Hälfte, Sprit kostet mehr), Glasdach (die Hülle verträgt viel weniger), Eilfahrt (ungeduldige Fahrgäste), Rückenwind (60 % Schwerkraft mit leichten Böen)
- Spiegelwelt spiegelt das ganze Bild, auch Schrift und Anzeigen – und damit die Steuerung links/rechts
- Ein Tagesziel (Express, Präzision, Sauber oder Gewinn) mit Bronze, Silber und Gold
- Serie und Gold belohnen mit neuen Lackierungen und Aufklebern (Sonne, Himmelblau, Medaille, Platin)
- Vor dem Start erscheint ein Briefing mit Regel, Ziel, Wertung und Medaillen-Schwellen
- Dein bester Flug des Tages fliegt als Geist mit; „Screenshot erstellen“ speichert die Auswertung als `JJMMTT_tagschicht_name.png`

**Spielstände und Menüs**
- Optionen, Levelauswahl, Musik, Garage, Statistik und die Level-Editor-Liste im Stil des Hauptmenüs: abgerundete dunkle Tafel, die Optionen mit Logo
- Spielstände haben Namen; die Spielstandwahl ist überarbeitet (runde Karten, Name, Umbenennen)
- Bildschirmtastatur: Fokus springt nicht mehr ins Leere, die Tastenreihen laufen im Kreis
- Hauptmenü: Hilfetext unten links in einer Zeile, das Menü sitzt etwas höher

**Sonstiges**
- Der Hauptmodus heißt jetzt „Karriere“ statt „Feldzug“

### English

**Version 1.0**
- GraviFare has reached version 1.0: 99 levels in 9 sectors, career, night shift, day shift, workshop, garage and level editor, in German and English, with keyboard and controller

**Night shift reworked**
- One shift of 9 maps, one from each sector 1 to 9; maps, jobs and gravity are fixed per day and the same for everyone. One attempt per day, starting with 5 taxis
- Mandatory passengers only (3 rides on map 1 up to 7 on map 9), no impatience, life stations off, no restarting a map
- Gravity changes from map to map but always stays flyable; it gets darker: 25 % on map 1, 8 % more per map
- Score per map up to 80 points (waiting time 25 – more generous in later sectors –, landings with a passenger 25, hull 20, near misses up to 10), plus 2 points per taxi left (up to 10) and 1 point per 1500 credits left (up to 10): 100 points at most, grades from S to E
- Results table with every map, time per map and total time (not scored), date and time (24 h in German, 12 h in English)
- "Create screenshot" button (mouse or Y/E) saves the results as `YYMMDD_nachtschicht_name.png` next to the game
- Own night-shift finale: approach with the landing gear extended, dispatch announcement for the grade, the driver climbs out of the dome, jumps down onto the pad, walks over the bridge and waves, with its own looping music track
- While the results are on screen, the engine and the low-fuel alarm are silent

**Day shift (formerly daily flight)**
- Every map is brightly lit, even from the dark sector
- One daily rule per weekday, reshuffled every week: windy day (gusts across the whole map), fog (you only see near the taxi), mirror world, thin tank (the tank holds only half, fuel costs more), glass roof (the hull takes far less), rush hour (impatient passengers), tailwind (60 % gravity with light gusts)
- Mirror world flips the whole picture, text and displays too – and with it left/right on the controls
- A daily goal (express, precision, clean or profit) with bronze, silver and gold
- Streaks and gold unlock new paints and stickers (Sun, Sky Blue, Medal, Platinum)
- A briefing before the start shows the rule, the goal, how it is scored and the medal thresholds
- Your best flight of the day flies along as a ghost; "Create screenshot" saves the results as `YYMMDD_tagschicht_name.png`

**Save slots and menus**
- Options, level selection, music, garage, statistics and the level editor list in the style of the main menu: rounded dark panel, the options with the logo
- Save slots have names; the slot selection has been redesigned (rounded cards, name, rename)
- On-screen keyboard: focus no longer jumps into nothing, key rows wrap around
- Main menu: help text at the bottom left on one line, the menu sits a little higher

**Other**
- The main mode is now called "Career" instead of "campaign"

## 0.9.12

### Deutsch

**Level**
- Balancing in Sektor 9 (Level 89, 90, 91, 94, 95, 97 und 99), dazu eine Lebensstation in Level 97

### English

**Levels**
- Balancing in sector 9 (levels 89, 90, 91, 94, 95, 97 and 99), plus a life station in level 97

## 0.9.11

### Deutsch

**Grafik**
- Taxi und Fahrgäste neu gezeichnet: schattierter Rumpf mit Glanz, Kuppel mit Spiegelung, Fahrer mit Mütze; Fahrgäste mit Laufzyklus und Koffer
- 14 Fahrgastfiguren statt 4, jede Stimme hat ihre eigene, passende Figur; die Namen wechseln jetzt auch von Sektor zu Sektor
- Eigene Verkehrsfahrzeuge (Pendlergleiter) in fünf Farben statt umgefärbter Taxis, mit weißem Scheinwerferkegel vorn und rotem Rücklicht hinten – auch in der Dunkelheit leuchten sie nur noch nach vorn und hinten
- Jeder Sektor hat seine eigene Haltestelle (Kristalle, Wellblech, Eiszapfen, Solarpaneel, Bullaugen, Bahnhofsuhr, Leuchtpilze …)
- Weiche Schatten unter Felsen und Plattformen, Bodenschatten unter Fahrgästen und Fahrzeugen, Triebwerksflammen aus Pixelzeilen
- Sektor 7: Wände dunkler, sie heben sich besser vom hellen Himmel ab

**Oberfläche**
- HUD: dunkle Leiste oben über die ganze Breite, gut lesbare Tank- und Hüllenanzeige, Landeanzeige mit Symbolen und gestreiften Warnbalken
- Wimpelzahlen, Torschild und Fahrpreis besser lesbar; Hauptmenü mit Tafel hinter den Knöpfen
- Eigenes Leben-Symbol in der Farbe der Lackierung
- Werkstatt überarbeitet: Karten mit Symbol, Stufen, Wirkung jetzt › nächste Stufe und rotem Preis, wenn das Geld nicht reicht; das Taxi zeigt das gewählte Teil, die Halle ist eingerichtet
- Garage zeigt Farbfelder und Aufkleber, gesperrte Teile lassen sich in der Vorschau ansehen; Statistik mit Tafel und Symbolen

**Klang**
- Eigene Warntöne für Plasmastrahl und Meteorit; in den letzten 15 Sekunden des Ausgangs tickt eine Uhr, zum Schluss schneller

**Behoben**
- Große Meteoriten (z. B. Level 95) trafen schon in den leeren Ecken um den Brocken; getroffen wird jetzt nur noch, wer den sichtbaren Brocken berührt

### English

**Graphics**
- Taxi and passengers redrawn: shaded hull with highlight, dome with reflection, driver with a cap; passengers with a walk cycle and suitcase
- 14 passenger figures instead of 4, every voice has its own matching figure; names now also change from sector to sector
- Own traffic vehicles (commuter gliders) in five colours instead of recoloured taxis, with a white headlight cone in front and a red tail light behind – in the dark they now only light up forwards and backwards
- Every sector has its own shelter (crystals, corrugated iron, icicles, solar panel, portholes, station clock, glowing mushrooms …)
- Soft shadows below rocks and platforms, ground shadows under passengers and vehicles, pixel-row engine flames
- Sector 7: darker walls that stand out better against the bright sky

**Interface**
- HUD: dark bar across the full width at the top, readable fuel and hull gauges, landing gauge with symbols and striped warning bars
- Flag numbers, gate sign and fare easier to read; main menu with a panel behind the buttons
- Own life icon in the colour of your paint job
- Workshop reworked: cards with icon, levels, effect now › next level and a red price when you can't afford it; the taxi shows the selected part, and the hall is furnished
- Garage shows colour swatches and stickers, locked items can be previewed; statistics with a panel and icons

**Sound**
- Own warning sounds for plasma beams and meteors; in the last 15 seconds before the exit closes a clock ticks, faster at the end

**Fixed**
- Large meteors (e.g. level 95) already hit you in the empty corners around the rock; now only touching the visible rock counts as a hit

## 0.9.10

### Deutsch

**Level-Editor**
- Zahlenfelder lassen sich mit Links/Rechts ändern, Halten wiederholt, nach einer Weile in größeren Schritten
- Neue Hilfeseite mit allen Tasten und Knöpfen für Tastatur, Maus und Controller (H, Knopf „Hilfe“ oder Back halten)
- „Fehler (n)“ bzw. F springt von Fehler zu Fehler und markiert die Stelle im Level
- „Speichern“ trägt ein Schloss, solange das Level Fehler hat oder noch nicht selbst gelöst ist; das Verlassen mit ungespeicherten Änderungen fragt nach (Speichern, Verwerfen, Weiter bearbeiten)
- Neue Knöpfe für Rückgängig, Wiederholen und Hilfe; Raster-Zustand, Eingabemodus und das Feld unter dem Zeiger sind sichtbar
- Automatische Aufträge stehen als lesbarer Text da, bis zu 12 Aufträge passen auf den Bildschirm
- Mit „Bewegung reduzieren“ blinken Fehlerstellen nicht mehr, sondern bleiben ruhig markiert
- Testflug eines Entwurfs: Ist er geschafft, wird die Bestzeit beim Speichern übernommen; selbst gelöste Level heißen in der Levelliste „Von dir gelöst (Testflug) – noch keine Bestzeit“ statt „Noch nicht geschafft“

### English

**Level editor**
- Number fields can be changed with Left/Right; holding repeats, and after a while it moves in bigger steps
- New help page with all keys and buttons for keyboard, mouse and controller (H, the "Help" button or hold Back)
- "Errors (n)" or F jumps from error to error and marks the spot in the level
- "Save" carries a lock while the level has errors or has not been solved by you yet; leaving with unsaved changes asks first (save, discard, keep editing)
- New buttons for undo, redo and help; grid state, input mode and the cell under the pointer are shown
- Automatic jobs are shown as readable text, and up to 12 jobs fit on screen
- With "Reduce motion" error spots no longer blink but stay calmly marked
- Test flight of a draft: once completed, the best time is kept when you save; levels you solved yourself show "Solved by you (test flight) – no best time yet" in the level list instead of "Not completed yet"

## 0.9.8

### Deutsch

**Fehlerbehebungen**
- Der Einspieler zu den Plasmastrahlen läuft jetzt in Level 19, wo die ersten Strahlen auftauchen, nicht erst in Level 46
- Level 20: Hob das Taxi im selben Moment ab, in dem der Fahrgast einstieg, blieb dieser unsichtbar an Bord hängen. Das Pflichtziel blinkte weiter, es erschien kein neuer Fahrgast und das Level kam nicht weiter. Das ist behoben; Zustände ohne Ausweg löst das Spiel jetzt von selbst auf (Fahrgast an Bord, Fahrgast weg, fehlender Nachfolger)
- Level 33 und alle Level mit fahrenden Plattformen: Nach einem Absturz sprang die Plattform zurück, und wartende Fahrgäste blieben daneben in der Luft stehen. Sie bleiben jetzt auf ihrer Plattform
- Level-Editor: Werte wie „abstoßend“ oder „waagerecht“ saßen nicht mittig und lagen unter dem rechten Knopf; alle Werte und Beschriftungen sind jetzt mittig und voll sichtbar

**Level-Editor**
- Magnete: Die Wirkung (anziehend oder abstoßend) ist getrennt von der Stärke wählbar
- Die Bewegung der Magnete (Drehung, Feldlinien, Partikel, Ringe) wird wie beim Wind je nach Stärke schneller oder langsamer

### English

**Bug fixes**
- The intro clip for plasma beams now plays in level 19, where the first beams appear, instead of level 46
- Level 20: if the taxi lifted off in the same moment the passenger boarded, the passenger stayed stuck aboard, invisible. The objective kept flashing, no new passenger appeared and the level could not continue. Fixed; the game now resolves dead-end states by itself (passenger aboard, passenger gone, missing successor)
- Level 33 and all levels with moving pads: after a crash the pad jumped back and waiting passengers were left standing in mid-air beside it. They now stay on their pad
- Level editor: values such as "repels" or "horizontal" were off-centre and sat under the right-hand button; all values and labels are now centred and fully visible

**Level editor**
- Magnets: the effect (attracts or repels) can be chosen separately from the strength
- Magnet animation (rotation, field lines, particles, rings) now runs faster or slower with the strength, like wind

## 0.9.7

### Deutsch

**Spiel**
- Die Fahrwerks-Bremse beim Fallen aus 0.9.6 war zu krass und ist teilweise zurückgenommen: Nach unten bremst das ausgefahrene Fahrwerk jetzt mit 60 % der ursprünglichen Wirkung (Dämpfung und Höchstgeschwindigkeit), nach oben und zur Seite wie immer

### English

**Game**
- The landing-gear braking when falling, removed in 0.9.6, was too extreme and is partly restored: downwards the extended gear now brakes with 60% of its original effect (damping and top speed), upwards and sideways as always

## 0.9.6

### Deutsch

**Fehlerbehebungen**
- Erklärvideos zu neuen Spielelementen (Dornen, Tore, Magnete …) waren beim Einflug ins Level nicht zu sehen, nur die Stimme lief: Sie liegen jetzt über der Übergangsansicht
- „Neues Spiel“ übernahm die Werkstatt-Einbauten des früheren Spielstands, und „Fortsetzen“ erschien schon ohne laufende Karriere: Ein neues Spiel beginnt jetzt ohne Einbauten, „Fortsetzen“ gibt es nur mit laufender Karriere (Bestzeiten und Medaillen bleiben)

**Spiel**
- Das ausgefahrene Fahrwerk bremst das Taxi nicht mehr beim Fallen nach unten (Schwerkraft und Massenträgheit); nach oben und zur Seite bleibt die Bremswirkung als Feinmanöver-Feature
- „Neues Spiel“ startet direkt Level 1; das Tutorial ist nicht mehr Pflicht und bleibt als eigener Menüpunkt erreichbar

### English

**Bug fixes**
- The explainer videos for newly introduced game elements (spikes, gates, magnets …) were hidden during the arrival flight, only the voice played: they now sit above the transition view
- "New Game" kept the workshop upgrades from the previous save, and "Continue" appeared without a running career: a new game now starts without upgrades, "Continue" only shows with a running career (best times and medals are kept)

**Game**
- The extended landing gear no longer brakes the taxi when falling downwards (gravity and inertia); braking upwards and sideways stays as a fine-manoeuvre feature
- "New Game" starts level 1 directly; the tutorial is no longer mandatory and remains available as its own menu entry

## 0.9.5

### Deutsch

**99 handgemachte Level**
- Alle Level wurden von Hand überarbeitet und selbst durchgeflogen: neue Wege, Tore, Zonen, Fahrzeugrouten und Aufträge in fast jedem Level
- Neue Zeitziele für die Medaille „Zeit“, abgestimmt auf die Handzeiten (bei den Autopilot-kritischen Leveln aus den gemessenen Zeiten des Entwicklers)
- Neue Vorschaubilder in der Levelauswahl und neue Sektor-Übersichten
- Neuer Trailer (Deutsch und Englisch) mit den neuen Leveln

**Spiel**
- Windschlieren zeigen die Windstärke: schneller Wind, schnellere und längere Schlieren
- Eine fahrende Plattform, die das gelandete Taxi gegen Fels schiebt, quetscht es jetzt (Schaden, Auswurf) statt es in den Fels zu fahren
- Waagerechte Wandertore (Flügel fahren senkrecht, Durchflug seitlich); der Autopilot fliegt sie
- Einflug aus dem Tor zur Startplattform ist wieder in jedem Level hindernisfrei (auch bei Fels unter dem Tor oder niedriger Decke über dem Start)

**Level-Editor**
- Speichern nur nach eigener Handlösung (Testflug selbst fliegen, auch für Community-Level)
- Debug-Modus: Original-Level bearbeiten (schreibt direkt in die Leveldateien) und Schalter zum Speichern ohne Handlösung
- Fahrzeuge je Route einstellbar; Tor-Parameter „Flügel“ (auto, senkrecht, waagerecht)

**Sonstiges**
- Herkunftsangaben vereinfacht: Hintergründe und Logo sind „KI-generiert“

### English

**99 handmade levels**
- Every level was reworked by hand and flown through by the developer: new routes, gates, zones, vehicle paths and jobs in nearly every level
- New time targets for the "Time" medal, tuned to hand-flown times (for the levels the autopilot struggles with, from the developer's measured times)
- New previews in the level selection and new sector overviews
- New trailer (German and English) featuring the new levels

**Game**
- Wind streaks show the wind strength: faster wind, faster and longer streaks
- A moving platform that pushes a landed taxi into rock now crushes it (damage, ejection) instead of driving it into the rock
- Horizontal sweeping gates (leaves move vertically, passage sideways); the autopilot flies them
- The arrival flight from the gate to the start pad is obstacle-free in every level again (also with rock below the gate or a low ceiling above the start)

**Level editor**
- Saving requires solving the level yourself by hand (fly the test flight yourself, also for community levels)
- Debug mode: edit the original levels (writes straight into the level files) and a switch to save without a hand solve
- Vehicles per route are adjustable; gate parameter "leaves" (auto, vertical, horizontal)

**Misc**
- Simplified provenance notes: backgrounds and logo are "AI-generated"
