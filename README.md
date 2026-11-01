# GraviFare (Arbeitstitel)

2D-Arcade-Schwebetaxi in Godot 4.7: Trägheit, Schwerkraft, präzise Landungen, 99 Level in 9 Sektoren (Sektor 3–5 prozedural erzeugt und per Bot geprüft, Rest per Skript/ASCII-Raster).
Geistiger Nachfolger des Genres „Flugtaxi“ – eigene Welt, eigene Level, eigene Grafik und Klänge.

**Stand:** Meilenstein M4: alle 99 Level in 9 Sektoren (Level 1–99), Tutorial („Flugschule“), 3 Speicherplätze, Medaillen und Punkte, Garage, DE/EN mit Sprachausgabe, 21 Musikthemen mit 3 Schichten, Licht/Normal-Maps/Partikel, Gamepad und freie Tastenbelegung. Siehe [DESIGN.md](DESIGN.md), [LEVELS.md](LEVELS.md) und [TESTING.md](TESTING.md). QA-Prüfungen (2026-11-01) und ihre Maßnahmen stehen in DESIGN.md („Runde 25“ und „Runde 26“).
Der Titel ist vorläufig; vor einer Veröffentlichung ist eine Markenprüfung (DE/EU) nötig. Eine Lizenz für das eigene Spiel ist **nicht** festgelegt.

## Starten
```bash
godot --path .                                  # Spiel (Godot 4.7.x)
godot --path . -- --level=s1_01                 # bestimmtes Level (data/levels/<id>.json)
godot --headless -s tests/test_runner.gd        # Tests
godot --headless -s tools/run_bot.gd            # Autopilot fliegt alle Level
python3 tools/art/gen_art.py                    # Pixel-Art neu erzeugen
```
Nach frischem Checkout einmal `godot --headless --import` ausführen (baut den Klassen-Cache).

## Aufbau
| Pfad | Inhalt |
|---|---|
| `src/core/` | Physik (`taxi_sim`), Auftragslogik (`run`), Leveldaten, Autopilot (`bot`), Parameter (`tuning`), Eingabe, Lokalisierung |
| `src/game/` | Szenen und Darstellung (Welt, Taxi, HUD, Hintergrund) |
| `data/levels/` | ein JSON pro Level |
| `data/i18n/` | Texte `de.json`, `en.json` |
| `tests/`, `tools/` | Testläufer, Bot-Harness, Asset-Generatoren |
