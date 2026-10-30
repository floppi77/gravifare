# TESTING
| Befehl | Zweck |
|---|---|
| `godot --headless -s tests/test_runner.gd` | Physik, Landung, Schaden, Auftragsfluss, Autopilot je Level (Exit-Code ≠ 0 bei Fehlern) |
| `godot --headless -s tools/run_bot.gd [-- s1_01]` | Autopilot fliegt Level mit echter Physik und meldet Zeit, Tank, Hülle |
| `godot --path . --rendering-driver opengl3 -- --shot=out.png --frames=40` | Screenshot für visuelle Kontrolle |

**Stand (Meilenstein M2, laufend):** 16 Prüfungen bestanden. Autopilot-Lösbarkeit: S1-01 ✔, S1-02 ✔ (inkl. Tankstopp), S1-03 ✔.

Screenshots/Menü: `godot --path . --rendering-driver opengl3 -- --level=s1_01 --press=pause@20 --shot=out.png --frames=40`.
**Grenzen:** Der Bot beweist Fliegbarkeit mit Sicherheitsrand, ersetzt aber keine spielerische Abnahme. Gamepad, Menüs und Spielgefühl sind noch nicht an echter Hardware abgenommen. Beim Autopiloten gilt „nicht bestanden“ immer als nicht bestanden.
