# TESTING
| Befehl | Zweck |
|---|---|
| `godot --headless -s tests/test_runner.gd` | Physik, Landung, Schaden, Auftragsfluss, Autopilot je Level (Exit-Code ≠ 0 bei Fehlern) |
| `godot --headless -s tools/run_bot.gd [-- s1_01]` | Autopilot fliegt Level mit echter Physik und meldet Zeit, Tank, Hülle |
| `HF_HOME=<cache> <venv>/bin/python tools/audio/verify_voice.py --model medium` | prüft Sprachclips per lokaler Spracherkennung (Ziffernnormalisierung, Ähnlichkeit ≥ 0,88) |
| `godot --headless --path . -- --dump-input` | zeigt die zur Laufzeit registrierten Eingabeaktionen |
| `godot --path . --rendering-driver opengl3 -- --shot=out.png --frames=40` | Screenshot für visuelle Kontrolle |

**Stand (Meilenstein M2, laufend):** 121 Prüfungen bestanden (neu: Fahrgast-Kollision und Ersatz, Landefenster-Regeln, Taxi-Skalierung) – u. a. Absturz-Balance (monotoner Schaden, Sofortzerstörung ab 170 px/s), Bezahlung nach Zeit und Landestrafe, Ausgangs-Fahrgast, Spawn nicht auf dem Taxi-Pad, Levelregeln (Job-Reihenfolge, fortlaufende Pads, Ausgang mittig oben), **Schwierigkeit steigt über die Level**, Bot löst jedes Level **ab dem Mindest-Sprit 35 %**.

Screenshots/Menü: `godot --path . --rendering-driver opengl3 -- --level=s1_01 --press=pause@20 --shot=out.png --frames=40`.
**Grenzen:** Der Bot beweist Fliegbarkeit mit Sicherheitsrand, ersetzt aber keine spielerische Abnahme. Gamepad, Menüs und Spielgefühl sind noch nicht an echter Hardware abgenommen. Beim Autopiloten gilt „nicht bestanden“ immer als nicht bestanden.

Dev-Flags (nach `--`): `--level=<id>`, `--shot=<png> --frames=<n>`, `--press=<aktion>@<frame>`, `--debug-open-exit`, `--dump-input`.
Weitere Dev-Flags: `--lives=N`, `--debug-destroy` (Taxi sofort zerstören), `--debug-squash` (Taxi auf wartenden Fahrgast senken), `--debug-input=x,y` (konstanter Schub), `--autopilot` (Bot fliegt im echten Spiel), `--debug-complete` (Level sofort abschließen), `--trans-t=<s>` (Levelwechsel-Zeitachse an Stelle s starten), `--lang=de|en` (Sprache nur für diesen Lauf). Läufe mit Autopilot/Debug-Flags schreiben **nie** den Speicherstand (`Save.dev_session`).

Hinweis: `godot --minimized` öffnet das Fenster auf KDE/Wayland nicht minimiert; Fensterläufe erscheinen kurz im Vordergrund.

Sprachclips: `tools/audio/gen_voice.py --validate` erzeugt Clips mit automatischer Spracherkennungs-Prüfung (Wiederholung mit neuem Seed bei Fehlern, Zusatzwörter wie Lacher werden verworfen). Stand: 88/88 Clips verständlich erkannt, Akzent-Indikator DE 0/36. **Subjektive Klangqualität und Akzent sind nur indirekt gemessen – bitte anhören.**

`godot --headless -s tools/level_report.gd` gibt Schwierigkeitsmetrik und Bot-Ergebnis je Level aus (Grundlage für LEVELS.md).

**Parallelbetrieb:** Ein zweiter Agent kann gleichzeitig Godot nutzen. Deshalb nie Prozesse per Name beenden (kein `pkill godot`/`pgrep -f`), nur eigene PIDs; jedes Projekt hat einen eigenen Ordner und Namen (`user://` getrennt).
