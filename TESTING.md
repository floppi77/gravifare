# TESTING
| Befehl | Zweck |
|---|---|
| `godot --headless -s tests/test_runner.gd` | Physik, Landung, Schaden, Auftragsfluss, Autopilot je Level (Exit-Code ≠ 0 bei Fehlern) |
| `godot --headless -s tools/run_bot.gd [-- s1_01]` | Autopilot fliegt Level mit echter Physik und meldet Zeit, Tank, Hülle |
| `HF_HOME=<cache> <venv>/bin/python tools/audio/verify_voice.py --model medium` | prüft Sprachclips per lokaler Spracherkennung (Ziffernnormalisierung, Ähnlichkeit ≥ 0,88) |
| `godot --headless --path . -- --dump-input` | zeigt die zur Laufzeit registrierten Eingabeaktionen |
| `godot --path . --rendering-driver opengl3 -- --shot=out.png --frames=40` | Screenshot für visuelle Kontrolle |

**Stand (Meilenstein M3/M4, laufend):** 416 Prüfungen bestanden (neu: verpasste Pflichtfahrgäste, Falsche-Plattform-Regeln, Feldzug-Speicher; Zusatzfahrgäste, Abflug nach dem Aussteigen, Einflug-Pfad, Dornen-Halt, Tankpad-Größen, Musikwechsel alle 5 Level, neue Schadenskurve; zuvor: Dornen mit festem Schaden, Sektor 1 komplett mit 11 Leveln inkl. Regel-, Schwierigkeits- und Bot-Prüfung je Level; zuvor: freie Belegung inkl. Tausch/Speichern/defekte Dateien, Medaillen, Speicherstand- und Einstellungs-Robustheit; zuvor: Serien-Bonus, Musik-Assets 10×3 Schichten synchron, Kosmetik-Daten, 64+ Sondersprachzeilen mit Clip; zuvor: Spritpreise im Bereich/Intervalle/reproduzierbar, Zapfsäule mit 3 Stufen und Explosion, Streckenzuschlag, tickender Betrag; neu: Auszahlung erst im Häuschen und näheres Landen lohnt, Absturz setzt das Level nicht zurück, Landefenster-Rampe, Fahrgast-Kollision, Taxi-Skalierung) – u. a. Absturz-Balance (monotoner Schaden, Sofortzerstörung ab 170 px/s), Bezahlung nach Zeit und Landestrafe, Ausgangs-Fahrgast, Spawn nicht auf dem Taxi-Pad, Levelregeln (Job-Reihenfolge, fortlaufende Pads, Ausgang mittig oben), **Schwierigkeit steigt über die Level**, Bot löst jedes Level **ab dem Mindest-Sprit 35 %**.

Screenshots/Menü: `godot --path . --rendering-driver opengl3 -- --level=s1_01 --press=pause@20 --shot=out.png --frames=40`.
**Grenzen:** Der Bot beweist Fliegbarkeit mit Sicherheitsrand, ersetzt aber keine spielerische Abnahme. Gamepad, Menüs und Spielgefühl sind noch nicht an echter Hardware abgenommen. Beim Autopiloten gilt „nicht bestanden“ immer als nicht bestanden.

Dev-Flags (nach `--`): `--level=<id>`, `--shot=<png> --frames=<n>`, `--press=<aktion>@<frame>`, `--debug-open-exit`, `--dump-input`.
Weitere Dev-Flags: `--scene=garage|credits|menu`, `--seed=N`, `--debug-pump=N` (Schadensstufe 0–3), `--lives=N`, `--debug-destroy` (Taxi sofort zerstören), `--debug-squash` (Taxi auf wartenden Fahrgast senken), `--debug-input=x,y` (konstanter Schub), `--autopilot` (Bot fliegt im echten Spiel), `--debug-complete` (Level sofort abschließen), `--trans-t=<s>` (Levelwechsel-Zeitachse an Stelle s starten), `--lang=de|en` (Sprache nur für diesen Lauf). Läufe mit Autopilot/Debug-Flags schreiben **nie** den Speicherstand (`Save.dev_session`).

Hinweis: `godot --minimized` öffnet das Fenster auf KDE/Wayland nicht minimiert; Fensterläufe erscheinen kurz im Vordergrund.

Sprachclips: `tools/audio/gen_voice.py --validate` erzeugt Clips mit automatischer Spracherkennungs-Prüfung (Wiederholung mit neuem Seed bei Fehlern, Zusatzwörter wie Lacher werden verworfen). Stand: 88/88 Clips verständlich erkannt, Akzent-Indikator DE 0/36. **Subjektive Klangqualität und Akzent sind nur indirekt gemessen – bitte anhören.**

`godot --headless -s tools/level_report.gd` gibt Schwierigkeitsmetrik und Bot-Ergebnis je Level aus (Grundlage für LEVELS.md).

**Parallelbetrieb:** Ein zweiter Agent kann gleichzeitig Godot nutzen. Deshalb nie Prozesse per Name beenden (kein `pkill godot`/`pgrep -f`), nur eigene PIDs; jedes Projekt hat einen eigenen Ordner und Namen (`user://` getrennt).

Musik: `python3 tools/audio/gen_music.py [thema]` (10 Themen × 3 Schichten). Sprachclips: Texte in `data/voice_lines.json`, Erzeugung `tools/audio/gen_voice.py --validate`; Stand: 167/168 + 1 Wiederholung bestätigt.
**Nicht automatisch prüfbar:** Klang der Musik/Stimmen, Vibrationsgefühl, Zeitlupe/Kamera-Gefühl – bitte spielen und anhören.

## Werkzeuge (M3)
| Aufruf | Zweck |
|---|---|
| `godot --headless -s tests/test_runner.gd` | alle Prüfungen (Physik, Aufträge, Regeln, Level, Daten, Audio-Assets, Speicherstand, Replay) |
| `godot --headless -s tools/run_bot.gd [id …]` | Autopilot fliegt jedes Level komplett (Lösbarkeit ab Standard-Sprit) |
| `godot --headless -s tools/level_report.gd` | Schwierigkeitsmetrik und Bot-Ergebnis je Level **ab Mindest-Sprit 35 %** |
| `godot --headless -s tools/replay_check.gd` | gespeicherte Bestzeit-Replays nachrechnen und mit dem Ergebnis vergleichen |
| `python3 tools/make_*.py` | Level-Erzeuger (ASCII-Raster → `data/levels/*.json`), `tools/levelkit.py` als Hilfsmodul |
| `python3 tools/audio/gen_music_sid.py [thema]` | Musik (SID-Klang) neu erzeugen |
| `.venv/tts/bin/python tools/audio/gen_voice.py [--clip de/f0_call] [--validate]` | Sprachclips erzeugen (Validierung braucht ein lokales Whisper-Modell) |

**Replay-Fundament:** Jeder Lauf besteht aus Start-Parametern (Level, Seed, Sprit, Credits, mitfahrender Fahrgast) und den Eingaben je 120-Hz-Tick (auf 1/127 gerundet, lauflängenkodiert). `Replay.play()` rechnet ihn headless exakt nach (Test: Bot-Läufe S1-01/04/08 reproduzieren Zeit, Credits und Zustellungen). Im Spiel wird die Bestzeit je Level als `user://replays/<id>.json` gespeichert (nie bei Dev-/Autopilot-Läufen). Der Geist (Anzeige im Spiel) ist damit vorbereitet, aber noch nicht gebaut.
**Punkte:** `Run.level_score()` = Netto-Einnahmen + 150 je Stern + 2 je Sekunde unter dem Zeitziel + 10 je perfekter Landung; Bestwert je Level im Speicherstand, Gesamtpunkte auf der Statistikseite.
