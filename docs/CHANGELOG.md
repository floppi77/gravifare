# Änderungsliste · Changelog

Die Texte stehen in den GitHub-Release-Notes („Neu in x“ / „What's new in x“), hier zur Nachlese.
The text of each section is used in the GitHub release notes ("Neu in x" / "What's new in x").

## 0.9.9

### Deutsch

**Level-Editor**
- Zahlenfelder lassen sich mit Links/Rechts ändern, Halten wiederholt, nach einer Weile in größeren Schritten
- Neue Hilfeseite mit allen Tasten und Knöpfen für Tastatur, Maus und Controller (H, Knopf „Hilfe“ oder Back halten)
- „Fehler (n)“ bzw. F springt von Fehler zu Fehler und markiert die Stelle im Level
- „Speichern“ trägt ein Schloss, solange das Level Fehler hat oder noch nicht selbst gelöst ist; das Verlassen mit ungespeicherten Änderungen fragt nach (Speichern, Verwerfen, Weiter bearbeiten)
- Neue Knöpfe für Rückgängig, Wiederholen und Hilfe; Raster-Zustand, Eingabemodus und das Feld unter dem Zeiger sind sichtbar
- Automatische Aufträge stehen als lesbarer Text da, bis zu 12 Aufträge passen auf den Bildschirm
- Mit „Bewegung reduzieren“ blinken Fehlerstellen nicht mehr, sondern bleiben ruhig markiert

### English

**Level editor**
- Number fields can be changed with Left/Right; holding repeats, and after a while it moves in bigger steps
- New help page with all keys and buttons for keyboard, mouse and controller (H, the "Help" button or hold Back)
- "Errors (n)" or F jumps from error to error and marks the spot in the level
- "Save" carries a lock while the level has errors or has not been solved by you yet; leaving with unsaved changes asks first (save, discard, keep editing)
- New buttons for undo, redo and help; grid state, input mode and the cell under the pointer are shown
- Automatic jobs are shown as readable text, and up to 12 jobs fit on screen
- With "Reduce motion" error spots no longer blink but stay calmly marked

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
- „Neues Spiel“ übernahm die Werkstatt-Einbauten des früheren Spielstands, und „Fortsetzen“ erschien schon ohne laufenden Feldzug: Ein neues Spiel beginnt jetzt ohne Einbauten, „Fortsetzen“ gibt es nur mit laufendem Feldzug (Bestzeiten und Medaillen bleiben)

**Spiel**
- Das ausgefahrene Fahrwerk bremst das Taxi nicht mehr beim Fallen nach unten (Schwerkraft und Massenträgheit); nach oben und zur Seite bleibt die Bremswirkung als Feinmanöver-Feature
- „Neues Spiel“ startet direkt Level 1; das Tutorial ist nicht mehr Pflicht und bleibt als eigener Menüpunkt erreichbar

### English

**Bug fixes**
- The explainer videos for newly introduced game elements (spikes, gates, magnets …) were hidden during the arrival flight, only the voice played: they now sit above the transition view
- "New Game" kept the workshop upgrades from the previous save, and "Continue" appeared without a running campaign: a new game now starts without upgrades, "Continue" only shows with a running campaign (best times and medals are kept)

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
