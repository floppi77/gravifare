# DESIGN

## Spielprinzip
Ein Schwebetaxi holt Fahrgäste von nummerierten Pads ab und liefert sie an Zielpads. Reiz: Trägheit, Schwerkraft, saubere Landungen. Nach allen Fahrten öffnet der Ausgang.

## Technikentscheidungen
| Entscheidung | Begründung |
|---|---|
| Godot 4.7.2, GDScript, 2D | lokal vorhanden, nativer Linux-Export, schnelle Iteration |
| **Eigene Physik statt RigidBody2D** (`TaxiSim`, fester 120-Hz-Tick) | exakt reproduzierbar, headless testbar, identisch in Spiel/Bot/Validator, unabhängig von Framerate (60–240 Hz) |
| Rendering über Physik-Interpolation | flüssig bei hohen Bildraten ohne Physikänderung |
| Tile-Raster 16 px, Level als JSON mit ASCII-Karte | pro Level separat prüfbar, gut diffbar, schnell iterierbar |
| Bewegte Gefahren als Funktion der Zeit (geplant) | deterministisch, für Bot/Validator vorausberechenbar |
| Neigung folgt dem Seitenschub (keine Rotationssteuerung) | „Neigung“ bleibt Landekriterium, Steuerung bleibt einfach |
| Pixel-Art per Python/Pillow-Skript (`tools/art`) | eigenständig, reproduzierbar, keine Fremdassets; Aseprite für spätere Feinarbeit |
| Lokalisierung per JSON → `Translation` | kein Import-Schritt, robust bei fehlenden Schlüsseln |
| Logische Auflösung 640×360, Standardfenster **1920×1080** (Skalierung 3), Stretch `canvas_items` + Integer-Scaling | UI/Schrift bleiben scharf; 4K = exakt 6× |
| Grafik in 3-facher Detailauflösung (Tile 48 px = 16 Welteinheiten) | pixelgenau bei 1080p, detailreicher als 640×360-Pixel-Art |
| Ausgang: Tor **immer mittig oben** (4×2 Tiles), geschlossen fest, öffnet erst nach allen Fahrten | Regel wird per Test für jedes Level geprüft |

## Flug- und Landeparameter (`src/core/tuning.gd`)
Schwerkraft 90 px/s², Hauptschub 230, Seitenschub 125, Dämpfung 0,18/s. Landefenster: Sinkrate ≤ 48 px/s, Seitengeschwindigkeit ≤ 32 px/s, Neigung ≤ 8,6°, beide Füße auf demselben Pad, Fahrwerk ausgefahren. „Weich“ ab ≤ 22 px/s. Aufprall unter 70 px/s ohne Schaden. Tankstelle: nie Sackgasse (unter 35 % kostenlos).

## Prioritäten
**Pflicht:** Flugphysik, Fahrwerk, Pads, Aufträge, Tanken, Schaden/Neustart, HUD, Tastatur+Gamepad, Menü/Pause/Optionen/Remapping, Speicherstand, 99 Level mit Validierung, DE/EN, Audio mit getrennten Reglern, Linux-Export, Dokumentation.
**Wertvolle Erweiterung:** 3 Medaillen/Bestzeiten, Fahrgasttypen (VIP, Fracht, Gruppen), Sektorfinales, Zugänglichkeitsoptionen, Sprachansagen.
**Optional:** Upgrades, Rückspulen, Tagesherausforderung, Geisterfahrt, Endlosmodus.

## Designregeln für Level
- Pad-Anflüge: Korridore mindestens 3 Tiles breit (Bot-Sicherheitsrand 7 px um die Hülle).
- Pads mindestens 4 Tiles breit, nie kleiner als nötig.
- Ausgangstor mittig oben (`Grid.gate()` in `tools/levelkit.py`); darunter muss ein mindestens 4 Tiles breiter Flugweg frei bleiben.
- Schwierigkeit durch Routen, Timing, Kombinationen – nicht durch Treibstoffknappheit.
- Jedes Level muss den Autopiloten-Test bestehen und zusätzlich spielerisch abgenommen werden.

## Plan Vertical Slice (M2)
Erledigt: Physik, Fahrwerk, Pads, Aufträge, Tanken, HUD, Level S1-01, Autopilot-Test.
Offen: Gamepad-/Eingabetest am echten Gerät, Menü, Pause mit Optionen, Fonts, Audio (Schub, Landung, Warnung), Spielgefühl-Feintuning durch Probespielen, Level S1-02 bis 03 als Gegenprobe der Levelpipeline.
