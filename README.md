# GraviFare (Arbeitstitel)

2D-Arcade-Schwebetaxi in Godot 4.7: Trägheit, Schwerkraft, präzise Landungen, 99 handgestaltete Level in 9 Sektoren.
Geistiger Nachfolger des Genres „Flugtaxi“ – eigene Welt, eigene Level, eigene Grafik und Klänge.

**Stand:** Meilenstein M1 abgeschlossen, M2 (Vertical Slice) in Arbeit: 3 Level, Fahrgäste mit Wartebereichen und Sprachausgabe (DE/EN), Levelwechsel-Sequenz, Licht/Partikel, Sprachwahl per Flagge. Siehe [DESIGN.md](DESIGN.md) und [TESTING.md](TESTING.md).
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
