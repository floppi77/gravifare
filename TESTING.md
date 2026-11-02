# TESTING
| Befehl | Zweck |
|---|---|
| `godot --headless -s tests/test_runner.gd` | Physik, Landung, Schaden, Auftragsfluss, Autopilot je Level (Exit-Code ≠ 0 bei Fehlern) |
| `godot --headless -s tools/run_bot.gd [-- s1_01]` | Autopilot fliegt Level mit echter Physik und meldet Zeit, Tank, Hülle |
| `HF_HOME=<cache> <venv>/bin/python tools/audio/verify_voice.py --model medium` | prüft Sprachclips per lokaler Spracherkennung (Ziffernnormalisierung, Ähnlichkeit ≥ 0,88) |
| `godot --headless --path . -- --dump-input` | zeigt die zur Laufzeit registrierten Eingabeaktionen |
| `godot --path . --rendering-driver opengl3 -- --shot=out.png --frames=40` | Screenshot für visuelle Kontrolle |

**Stand (Meilenstein M4, laufend):** 2762 Prüfungen bestanden (neu in Runde 34: Plattformwimpel ohne Überdeckung, Lebenspreis je Sektor, Werkstattpreise je Werkstatt, Taxi der Zwischensequenz ohne Stillstand; Runde 32: Schiebetore, Debug-Code, Game Over je Sektor, Werkstatt-Kauf, Nachtschicht-Sperre, Fahrzeugrouten meiden Haltestellen und führen quer durchs Level; Runde 31: Hüpfer an falscher Plattform, Musikplayer, Hinweistexte; Runde 30: Sektor-Grafik, Finale-Musik; Runde 29: Tutorial nach Fehlbedienung; Runde 28: Landeplatte; Runde 27: Werkstatt, Geist-Spur, Nachtschicht-Aufträge, Sektor-Schwerkraft; zuvor Runde 26: Autopilot muss durchs Tor fliegen, Exit-Countdown drängt und hält bei Zusatzfahrgast, Mover schiebt nie in den Fels, Medaillen verlangen alle Pflichtfahrgäste, Übungsflug schützt den Feldzug; zuvor Runde 25: zweite Sicherung bei defektem Speicherstand, Platz-Übersicht mit falschem Typ, Master-/Assistent-Optionen, Landeassistent-Farbstufen, Effekt-Variation; zuvor: Pflichtgast-Verlust und Exit-Countdown, Tutorial mit zweitem Gast/Rauswurf, 99 Level; zuvor: Speicherplätze, Tutorial-Skript mit Sperren, Einspieler (18 Demos), Lückenfüller-Regel, 98 Level gesamt; zuvor: Sektor 9 (89 Level gesamt), Dunkelheit-Test für Sektor 8/9; zuvor: Fahrzeugpfade, Dunkelheit in Sektor 8, Sektor 7 und 8 (82 Level gesamt); zuvor: Verkehr durch Wandöffnungen, Windbänder, Sektor 7 komplett (77 Level gesamt); zuvor: überlappungsfreie Kraftzonen, Verkehr (Fahrzeuge), Sektor 7 (73 Level gesamt); zuvor: Patientenverlust-Ereignis, Sektor 5 komplett, Sektor 6 (66 Level gesamt) inkl. Bot-Lösbarkeit, 98 Funksprüche mit Clips; zuvor: durchfliegbarer Plasmastrahl, Strafe für verlorene Krankenpatienten, Sektor 5 bis Level 54; zuvor: Flugpflicht für perfekte Landungen, Plasmastrahl, Hitzezone, Krankenhaus-Pad/Krankentransport, Sektor 3–5 (51 Level) inkl. Bot-Lösbarkeit, 94 Funksprüche mit Clips; zuvor: zerbrechliche Fahrgäste und Meteoriten (Warnung, Fall, Schaden), Sektor 4 mit 11 Leveln inkl. Bot-Lösbarkeit; zuvor: bewegliche Trümmer und fahrende Pads (Kollision, Landung relativ zur Plattform, Mitnahme), Sektor 3 mit 11 Leveln inkl. Bot-Lösbarkeit und Gewinnprüfung; Fahrgast rauswerfen (Fall, Tod, kein Geld, Zusatzfahrgast, Replay, Tasten); Tor-Quetschung, leerer Tank, Zusatzfahrgast-Kollision, Obergrenzen, Lebens-Station; bewegliche Tore, Mindest-Fahrpreis/Profit je Level, Preise bei defekter Zapfsäule, Sektor 2 mit 11 Leveln inkl. Bot-Lösbarkeit ohne verpasste Fahrgäste; verpasste Pflichtfahrgäste, Falsche-Plattform-Regeln, Feldzug-Speicher; Zusatzfahrgäste, Abflug nach dem Aussteigen, Einflug-Pfad, Dornen-Halt, Tankpad-Größen, Musikwechsel alle 5 Level, neue Schadenskurve; zuvor: Dornen mit festem Schaden, Sektor 1 komplett mit 11 Leveln inkl. Regel-, Schwierigkeits- und Bot-Prüfung je Level; zuvor: freie Belegung inkl. Tausch/Speichern/defekte Dateien, Medaillen, Speicherstand- und Einstellungs-Robustheit; zuvor: Serien-Bonus, Musik-Assets 10×3 Schichten synchron, Kosmetik-Daten, 64+ Sondersprachzeilen mit Clip; zuvor: Spritpreise im Bereich/Intervalle/reproduzierbar, Zapfsäule mit 3 Stufen und Explosion, Streckenzuschlag, tickender Betrag; neu: Auszahlung erst im Häuschen und näheres Landen lohnt, Absturz setzt das Level nicht zurück, Landefenster-Rampe, Fahrgast-Kollision, Taxi-Skalierung) – u. a. Absturz-Balance (monotoner Schaden, Sofortzerstörung ab 150 px/s), Bezahlung nach Zeit und Landestrafe, Ausgangs-Fahrgast, Spawn nicht auf dem Taxi-Pad, Levelregeln (Job-Reihenfolge, fortlaufende Pads, Ausgang mittig oben), **Schwierigkeit steigt über die Level**, Bot löst jedes Level **ab dem Mindest-Sprit 35 %**.

**Bekannt:** `tools/run_bot.gd` fliegt mit Standardwerten statt ab Mindest-Sprit und scheitert dabei an S5-03 und S9-11, auch schon vor Runde 31. Die maßgebliche Prüfung „Autopilot löst … ab Mindest-Sprit“ im Testläufer besteht für alle 99 Level.

Screenshots/Menü: `godot --path . --rendering-driver opengl3 -- --level=s1_01 --press=pause@20 --shot=out.png --frames=40`.
**Grenzen:** Der Bot beweist Fliegbarkeit mit Sicherheitsrand, ersetzt aber keine spielerische Abnahme. Gamepad, Menüs und Spielgefühl sind noch nicht an echter Hardware abgenommen. Beim Autopiloten gilt „nicht bestanden“ immer als nicht bestanden.

Dev-Flags (nach `--`): `--level=<id>`, `--shot=<png> --frames=<n>`, `--press=<aktion>@<frame>`, `--debug-open-exit`, `--dump-input`.
Weitere Dev-Flags: `--scene=garage|credits|finale|menu`, `--slots`, `--levels`, `--seed=N`, `--debug-pump=N` (Schadensstufe 0–3), `--lives=N`, `--debug-destroy` (Taxi sofort zerstören), `--debug-squash` (Taxi auf wartenden Fahrgast senken), `--debug-input=x,y` (konstanter Schub), `--autopilot` (Bot fliegt im echten Spiel), `--debug-complete` (Level sofort abschließen), `--trans-t=<s>` (Levelwechsel-Zeitachse an Stelle s starten), `--lang=de|en` (Sprache nur für diesen Lauf), `--no-hud` (Bild ohne HUD). Läufe mit Autopilot/Debug-Flags schreiben **nie** den Speicherstand (`Save.dev_session`).

Hinweis: `godot --minimized` öffnet das Fenster auf KDE/Wayland nicht minimiert; Fensterläufe erscheinen kurz im Vordergrund.

Sprachclips: `tools/audio/gen_voice.py --validate` erzeugt Clips mit automatischer Spracherkennungs-Prüfung (Wiederholung mit neuem Seed bei Fehlern, Zusatzwörter wie Lacher werden verworfen). Stand: 88/88 Clips verständlich erkannt, Akzent-Indikator DE 0/36. **Subjektive Klangqualität und Akzent sind nur indirekt gemessen – bitte anhören.**

`godot --headless -s tools/level_report.gd` gibt Schwierigkeitsmetrik und Bot-Ergebnis je Level aus (Grundlage für LEVELS.md).

**Parallelbetrieb:** Ein zweiter Agent kann gleichzeitig Godot nutzen. Deshalb nie Prozesse per Name beenden (kein `pkill godot`/`pgrep -f`), nur eigene PIDs; jedes Projekt hat einen eigenen Ordner und Namen (`user://` getrennt).

Musik: `python3 tools/audio/gen_music.py [thema]` (22 Themen × 3 Schichten, Noten in `tools/audio/music_score.py`). Sprachclips: Texte in `data/voice_lines.json`, Erzeugung `tools/audio/gen_voice.py --validate`; Stand: 167/168 + 1 Wiederholung bestätigt.
**Nicht automatisch prüfbar:** Klang der Musik/Stimmen, Vibrationsgefühl, Zeitlupe/Kamera-Gefühl – bitte spielen und anhören.

## Werkzeuge (M3)
| Aufruf | Zweck |
|---|---|
| `godot --headless -s tests/test_runner.gd` | alle Prüfungen (Physik, Aufträge, Regeln, Level, Daten, Audio-Assets, Speicherstand, Replay) |
| `godot --headless -s tools/run_bot.gd [id …]` | Autopilot fliegt jedes Level komplett (Lösbarkeit ab Standard-Sprit) |
| `godot --headless -s tools/level_report.gd` | Schwierigkeitsmetrik und Bot-Ergebnis je Level **ab Mindest-Sprit 35 %** |
| `godot --headless -s tools/replay_check.gd` | gespeicherte Bestzeit-Replays nachrechnen und mit dem Ergebnis vergleichen |
| `python3 tools/make_*.py` | Level-Erzeuger (ASCII-Raster → `data/levels/*.json`), `tools/levelkit.py` als Hilfsmodul |
| `python3 tools/audio/gen_music.py [thema]` | Musik neu erzeugen (SID und Paula), Noten in `tools/audio/music_score.py` |
| `.venv/tts/bin/python tools/audio/gen_voice.py [--clip de/f0_call] [--validate]` | Sprachclips erzeugen (Validierung braucht ein lokales Whisper-Modell) |

**Replay-Fundament:** Jeder Lauf besteht aus Start-Parametern (Level, Seed, Sprit, Credits, mitfahrender Fahrgast) und den Eingaben je 120-Hz-Tick (auf 1/127 gerundet, lauflängenkodiert). `Replay.play()` rechnet ihn headless exakt nach (Test: Bot-Läufe S1-01/04/08 reproduzieren Zeit, Credits und Zustellungen). Im Spiel wird die Bestzeit je Level als `user://replays/<id>.json` gespeichert (nie bei Dev-/Autopilot-Läufen). Der Geist (Anzeige im Spiel) ist damit vorbereitet, aber noch nicht gebaut.
**Punkte:** `Run.level_score()` = Netto-Einnahmen + 150 je Stern + 2 je Sekunde unter dem Zeitziel + 10 je perfekter Landung; Bestwert je Level im Speicherstand, Gesamtpunkte auf der Statistikseite.
