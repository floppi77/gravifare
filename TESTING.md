# TESTING
| Befehl | Zweck |
|---|---|
| `godot --headless -s tests/test_runner.gd` | Physik, Landung, Schaden, Auftragsfluss, Autopilot je Level (Exit-Code ≠ 0 bei Fehlern) |
| `python3 tools/level_hashes.py` | schreibt `data/levels.sha256` neu (nach gewollten Änderungen an den Originalleveln; der Test `_test_originals_unchanged` prüft sie) |
| `godot --headless -s tools/run_bot.gd [-- s1_01]` | Autopilot fliegt Level mit echter Physik und meldet Zeit, Tank, Hülle |
| `HF_HOME=<cache> <venv>/bin/python tools/audio/verify_voice.py --model medium` | prüft Sprachclips per lokaler Spracherkennung (Ziffernnormalisierung, Ähnlichkeit ≥ 0,88) |
| `godot --headless --path . -- --dump-input` | zeigt die zur Laufzeit registrierten Eingabeaktionen |
| `godot --path . --rendering-driver opengl3 -- --shot=out.png --frames=40` | Screenshot für visuelle Kontrolle |

**Stand (Meilenstein M4, laufend):** über 2700 Prüfungen, alle bestanden (2825). Neu je Runde, jüngste zuerst:

- **Runde 48:** Handlevel: Autopilot-Lösbarkeit nur statisch für 20 Level (`BOT_HAND_LEVELS`), Sektor-Mittelwert der Schwierigkeit steigt, Einflug hindernisfrei in allen 99 Leveln, Metrik-Anflugpunkt unter dem Tor
- **Runde 47:** Schreibformat und Einarbeiten von Original-Änderungen (97 von 99 Dateien byteidentisch, unveränderte Bearbeitung schreibt nichts), Prüfsumme/Geister beim Speichern, Handlösung (Nachweis je Inhalt, Entwürfe, Speichersperre im Editor, Original-Modus nur im Debug-Modus)
- **Runde 43:** Editor mit einem Stift (Fahrzeugpfad: Rollen, Beenden, Abbrechen, Punkt ziehen/entfernen, Greifen nur an der Linie; Größe beim Setzen für Zone, Magnet, Meteorit, Plattform; Symbolpaletten; Doppelklick-Füllen; Controllerbelegung per Quelltextprüfung)
- **Runde 41:** Editor Stufe 3 (Objekte: alle zehn Arten hinzufügen/ändern/verschieben/entfernen/auswählen, Tore und Zonen-Pulsieren, Grenzen, Magnetstärke; Aufträge: eigene Liste, Einfügen, Ziel wechseln, Klinik, Ausgang nur im letzten; Bildschirm: Seiten, Ziehen, Löschen unter dem Zeiger, Auftragsliste; Zahlenwerte aller Originale bleiben beim Kopieren erhalten)
- **Runde 40:** Level-Editor (leeres Level gültig, festes Ausgangstor, Start versetzen, Rückgängig/Wiederholen mit Strichen, Rechteck/Füllen, Pads nummerieren, Aufträge passen sich an, Rundlauf von neun Originalen ohne Änderung, Bildschirm: Malen, Speichern, Sitzungsfassung ersetzen, Kopie beim Bearbeiten, Zurück mit Rückfrage), Hauptmenü (Hilfetexte, Flaggenspalte)
- **Runde 39:** Community-Level (Format, Prüfung, Positivliste, Zahlenbegrenzung, ID-Hash und Pfadschutz, Code-Rundlauf, Ablage in `user://`, Kopie eines Originals ohne Änderung am Original, Spielmodus ohne Statistik und Feldzug, Fehlertexte vollständig, Fuzz mit beschädigten Leveln, alle 99 Originale als Kopie gültig, Probeflug, Bildschirm), Prüfsummen der Originale
- **Runde 38:** Level-Optik (Neon/Glas) hängt nur an vorhandenen Leveln, Neonlabyrinth hat drei Neon-Strahlen, Glasfassade: Sweep-Schleusen (Öffnung immer 3 Felder, wandert über die ganze Höhe, gegenläufig), Pflichtfahrgast-Zähler ohne Abzug, Einspieler beim Einflug, Meteorbahnen streuen breit und meiden nur Pads im Spiel
- **Runde 37 (v0.9.4):** Ausgangs-Fahrgast zählt im Level als befördert, Menü-Version passt zum Export-Preset, Fenstergröße passt zum Bildschirm, Auto-Pause und Anzeige-Optionen (Quelltextprüfung), Einstellungen atomar, Tagesflug (gleicher Tag = gleiche Karte, Aufträge und Preise; Bestwert und Serie)
- **Runde 36:** 14 Fahrgaststimmen in beiden Sprachen
- **Runde 35:** Polwechsel-Magnete, Meteoritenbahnen, mitgebrachter Fahrgast zählt nicht, Preissteilheit, Verlustfahrgast-Strafe
- **Runde 34:** Plattformwimpel ohne Überdeckung, Lebenspreis je Sektor, Werkstattpreise je Werkstatt, Taxi der Zwischensequenz ohne Stillstand
- **Runde 32:** Schiebetore, Debug-Code, Game Over je Sektor, Werkstatt-Kauf, Nachtschicht-Sperre, Fahrzeugrouten meiden Haltestellen und führen quer durchs Level
- **Runde 31:** Hüpfer an falscher Plattform, Musikplayer, Hinweistexte
- **Runde 30:** Sektor-Grafik, Finale-Musik
- **Runde 29:** Tutorial nach Fehlbedienung
- **Runde 28:** Landeplatte
- **Runde 27:** Werkstatt, Geist-Spur, Nachtschicht-Aufträge, Sektor-Schwerkraft
- **Runde 26:** Autopilot muss durchs Tor fliegen, Exit-Countdown drängt und hält bei Zusatzfahrgast, Mover schiebt nie in den Fels, Medaillen verlangen alle Pflichtfahrgäste, Übungsflug schützt den Feldzug
- **Runde 25:** zweite Sicherung bei defektem Speicherstand, Platz-Übersicht mit falschem Typ, Master-/Assistent-Optionen, Landeassistent-Farbstufen, Effekt-Variation
- **Frühere Runden** (jüngste zuerst):
  - Pflichtgast-Verlust und Exit-Countdown, Tutorial mit zweitem Gast/Rauswurf, 99 Level
  - Speicherplätze, Tutorial-Skript mit Sperren, Einspieler (18 Demos), Lückenfüller-Regel, 98 Level gesamt
  - Sektor 9 (89 Level gesamt), Dunkelheit-Test für Sektor 8/9
  - Fahrzeugpfade, Dunkelheit in Sektor 8, Sektor 7 und 8 (82 Level gesamt)
  - Verkehr durch Wandöffnungen, Windbänder, Sektor 7 komplett (77 Level gesamt)
  - überlappungsfreie Kraftzonen, Verkehr (Fahrzeuge), Sektor 7 (73 Level gesamt)
  - Patientenverlust-Ereignis, Sektor 5 komplett, Sektor 6 (66 Level gesamt) inkl. Bot-Lösbarkeit, 98 Funksprüche mit Clips
  - durchfliegbarer Plasmastrahl, Strafe für verlorene Krankenpatienten, Sektor 5 bis Level 54
  - Flugpflicht für perfekte Landungen, Plasmastrahl, Hitzezone, Krankenhaus-Pad/Krankentransport, Sektor 3–5 (51 Level) inkl. Bot-Lösbarkeit, 94 Funksprüche mit Clips
  - zerbrechliche Fahrgäste und Meteoriten (Warnung, Fall, Schaden), Sektor 4 mit 11 Leveln inkl. Bot-Lösbarkeit
  - bewegliche Trümmer und fahrende Pads (Kollision, Landung relativ zur Plattform, Mitnahme), Sektor 3 mit 11 Leveln inkl. Bot-Lösbarkeit und Gewinnprüfung; Fahrgast rauswerfen (Fall, Tod, kein Geld, Zusatzfahrgast, Replay, Tasten); Tor-Quetschung, leerer Tank, Zusatzfahrgast-Kollision, Obergrenzen, Lebens-Station; bewegliche Tore, Mindest-Fahrpreis/Profit je Level, Preise bei defekter Zapfsäule, Sektor 2 mit 11 Leveln inkl. Bot-Lösbarkeit ohne verpasste Fahrgäste; verpasste Pflichtfahrgäste, Falsche-Plattform-Regeln, Feldzug-Speicher; Zusatzfahrgäste, Abflug nach dem Aussteigen, Einflug-Pfad, Dornen-Halt, Tankpad-Größen, Musikwechsel alle 5 Level, neue Schadenskurve
  - Dornen mit festem Schaden, Sektor 1 komplett mit 11 Leveln inkl. Regel-, Schwierigkeits- und Bot-Prüfung je Level
  - freie Belegung inkl. Tausch/Speichern/defekte Dateien, Medaillen, Speicherstand- und Einstellungs-Robustheit
  - Serien-Bonus, Musik-Assets 10×3 Schichten synchron, Kosmetik-Daten, 64+ Sondersprachzeilen mit Clip
  - Spritpreise im Bereich/Intervalle/reproduzierbar, Zapfsäule mit 3 Stufen und Explosion, Streckenzuschlag, tickender Betrag
  - Auszahlung erst im Häuschen und näheres Landen lohnt, Absturz setzt das Level nicht zurück, Landefenster-Rampe, Fahrgast-Kollision, Taxi-Skalierung
- **Grundlagen:** Absturz-Balance (monotoner Schaden, Sofortzerstörung ab 150 px/s), Bezahlung nach Zeit und Landestrafe, Ausgangs-Fahrgast, Spawn nicht auf dem Taxi-Pad, Levelregeln (Job-Reihenfolge, fortlaufende Pads, Ausgang mittig oben), **Schwierigkeit steigt über die Level**, Bot löst jedes Level **ab dem Mindest-Sprit 35 %**.

**Bekannt:** `tools/run_bot.gd` fliegt mit Standardwerten statt ab Mindest-Sprit und scheitert dabei an S5-03 und S9-11, auch schon vor Runde 31. Die maßgebliche Prüfung „Autopilot löst … ab Mindest-Sprit“ im Testläufer besteht für alle 99 Level.

Screenshots/Menü: `godot --path . --rendering-driver opengl3 -- --level=s1_01 --press=pause@20 --shot=out.png --frames=40`.
**Grenzen:** Der Bot beweist Fliegbarkeit mit Sicherheitsrand, ersetzt aber keine spielerische Abnahme. Die Gamepad-Steuerung (Xbox-Layout) hat der Auftraggeber an echter Hardware gespielt und als herausragend bewertet (2026-11-01); Menüs und Spielgefühl prüft er laufend beim Spielen, automatisch messen lässt sich das nicht. Beim Autopiloten gilt „nicht bestanden“ immer als nicht bestanden.

Dev-Flags (nach `--`): `--level=<id>`, `--shot=<png> --frames=<n>`, `--press=<aktion>@<frame>`, `--debug-open-exit`, `--dump-input`.
Weitere Dev-Flags: `--scene=garage|credits|finale|menu`, `--slots`, `--levels`, `--seed=N`, `--debug-pump=N` (Schadensstufe 0–3), `--lives=N`, `--debug-destroy` (Taxi sofort zerstören), `--debug-squash` (Taxi auf wartenden Fahrgast senken), `--debug-input=x,y` (konstanter Schub), `--autopilot` (Bot fliegt im echten Spiel), `--debug-complete` (Level sofort abschließen), `--trans-t=<s>` (Levelwechsel-Zeitachse an Stelle s starten), `--lang=de|en` (Sprache nur für diesen Lauf), `--no-hud` (Bild ohne HUD). Läufe mit Autopilot/Debug-Flags schreiben **nie** den Speicherstand (`Save.dev_session`).

Hinweis: `godot --minimized` öffnet das Fenster auf KDE/Wayland nicht minimiert; Fensterläufe erscheinen kurz im Vordergrund.

Sprachclips: `tools/audio/gen_voice.py --validate` erzeugt Clips mit automatischer Spracherkennungs-Prüfung (Wiederholung mit neuem Seed bei Fehlern, Zusatzwörter wie Lacher werden verworfen). Stand: 88/88 Clips verständlich erkannt, Akzent-Indikator DE 0/36. **Subjektive Klangqualität und Akzent sind nur indirekt gemessen – bitte anhören.**

`godot --headless -s tools/level_report.gd` gibt Schwierigkeitsmetrik und Bot-Ergebnis je Level aus (Grundlage für LEVELS.md).

**Parallelbetrieb:** Ein zweiter Agent kann gleichzeitig Godot nutzen. Deshalb nie Prozesse per Name beenden (kein `pkill godot`/`pgrep -f`), nur eigene PIDs; jedes Projekt hat einen eigenen Ordner und Namen (`user://` getrennt).

**Testskript und Autoloads:** `tests/test_runner.gd` wird übersetzt, bevor die Autoloads (Flow, Save, Sfx …) existieren. Dort deshalb kein `Flow`/`Save` im Quelltext und kein `preload` von Skripten, die Autoloads nennen (z. B. `community_store.gd`); stattdessen zur Laufzeit `get_root().get_node("Flow")` bzw. `load(...)`, und eigene `Save`-Instanzen (`load("res://src/core/save.gd").new()`) mit eigenem `slot_prefix`. Die Autoload-Knoten sind in `_initialize` noch nicht „im Baum“ (kein `_ready`, keine Übersetzungen, `add_child` an die Wurzel wirkt nicht): Oberflächen von Hand mit `_ready()` aufbauen, Übersetzungen wie `Loc` selbst anlegen. Skripte wie `game.gd` übersetzt der Testlauf nicht; ihre Fehler zeigt erst ein Fensterlauf (`godot -w … -- --slot=1 --community --press=ui_accept@60 --shot=…`).

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
| `.venv/tts/bin/python tools/audio/gen_passenger_refs.py` und `gen_voice_drama_passengers.py` | zusätzliche Fahrgaststimmen f2–f6, m2–m6 (Referenzen mit Qwen, Zeilen mit Drama 3 über `drama serve`, Ablauf im Kopf des Skripts) |
| `.venv/tts/bin/python tools/audio/voice_pitch.py` | mittlere Tonlage je Fahrgaststimme |

**Replay-Fundament:** Jeder Lauf besteht aus Start-Parametern (Level, Seed, Sprit, Credits, mitfahrender Fahrgast) und den Eingaben je 120-Hz-Tick (auf 1/127 gerundet, lauflängenkodiert). `Replay.play()` rechnet ihn headless exakt nach (Test: Bot-Läufe S1-01/04/08 reproduzieren Zeit, Credits und Zustellungen). Im Spiel wird die Bestzeit je Level als `user://replays/<id>.json` gespeichert (nie bei Dev-/Autopilot-Läufen). Der Geist (Anzeige im Spiel) ist damit vorbereitet, aber noch nicht gebaut.
**Punkte:** `Run.level_score()` = Netto-Einnahmen + 150 je Stern + 2 je Sekunde unter dem Zeitziel + 10 je perfekter Landung; Bestwert je Level im Speicherstand, Gesamtpunkte auf der Statistikseite.
