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

## Fahrgäste und Wartebereiche
- Jedes Passagierpad hat einen **Wartebereich**: Unterstand an einem Padende (24×20 Einheiten, 2 Tiles Luft darüber nötig), davor der Wartepunkt (`LevelData._plan_shelters`).
- Fahrgäste sind `PassengerActor`-Zustandsautomaten: treten aus der Tür, warten und winken („Hey Taxi!“), laufen zum gelandeten Taxi, steigen ein („Plattform N, bitte!“); am Ziel steigen sie aus, laufen in den Unterstand und verschwinden dort („Danke!“). Einsteigen dauert so lange, wie sie laufen; Abheben bricht es ab.
- Jeder Auftrag hat einen eigenen Fahrgast mit Name, Geschlecht und Figur; der nächste erscheint erst, wenn sein Auftrag dran ist (Verzögerung 1,2 s). Abgelieferte Fahrgäste erscheinen nicht erneut.
- Laufzyklus mit 6 Frames (Seitenansicht), Idle (Blinzeln), Winken. Pad-Nummern sind immer fortlaufend 1..N.

## Zweisprachigkeit (Deutsch/Englisch)
Alle Texte laufen über `data/i18n/{de,en}.json` (Test: gleiche Schlüssel, nichts Leeres, alle im Code benutzten Schlüssel vorhanden); Levelnamen stehen im Level in beiden Sprachen, Sprachclips je Sprache. Die Sprache wählst du im Hauptmenü über zwei Flaggen ohne Text (Deutschland; Großbritannien/USA diagonal geteilt); die Wahl wird gespeichert, das Menü baut sich sofort neu auf. Zusätzlich gibt es den Schalter in den Optionen. Gamepad: Flaggen sind fokussierbar, A wählt.

## Sprachausgabe
Offline mit Qwen3-TTS (VoiceDesign, Apache-2.0) erzeugt (`tools/audio/gen_voice.py`), zwei Stimmen je Geschlecht (f0/f1, m0/m1), Deutsch und Englisch, 44 Clips je Sprache als OGG. Stimmbeschreibungen sind sprachspezifisch (deutsche Zeilen mit deutscher Beschreibung „Muttersprachler, akzentfreies Standarddeutsch“), Clip-Enden klingen mit relativer Schwelle und 180-ms-Ausblendung natürlich aus. Zur Laufzeit keine KI nötig; fehlen Clips, bleibt der Untertitel. Qualitätsprüfung per lokaler Spracherkennung (`tools/audio/verify_voice.py`). Untertitel und eigener Voice-Regler sind in den Optionen.

## Flugmodi
Fahrwerk **eingefahren**: schnelle Navigation (Schub 230/125, Dämpfung 0,18, Vmax 240). Fahrwerk **ausgefahren**: Feinmanöver (Schub 150/68, Dämpfung 1,1, Vmax 90). Der Übergang folgt der Fahrwerksanimation; Werte in `tuning.gd`.

## Licht und Effekte
Dunkles Ambient (`CanvasModulate`) plus Punktlichter an Pads, Unterständen, Tor und Taxi; Fels-Tiles werfen Schatten (Occluder). Schlagschatten und Ambient Occlusion an den Tiles, Partikel für Abgas, Bodenstaub, Landestaub, Funken, Rauch und Schwebestaub (bei „Weniger Bewegung“ reduziert). Spielelemente (Taxi, Pads, Fahrgäste, Tor) sind ungelit und bleiben dadurch immer lesbar.

## Levelwechsel
Nach dem Tor: altes Level blendet in 2 s in den Weltraum aus, 3,6 s Flugsequenz (Sterne in drei Ebenen, Planeten, fliegendes Taxi, Titelkarte „Sektor · Level – Name“, verdienter Betrag), dann blendet das neue Level in 2 s ein, während das Taxi durch das kurz öffnende Tor in der Decke austritt, eine S-Kurve fliegt und auf der Startplattform landet; die wartende Fahrgast ruft „Hey Taxi!“. A/Enter/B/Esc überspringen bis zum Einblenden. Ablauf: `transition_view.gd` (Zeichnen), `game.gd` (Zeitachse, Laden, Anflug). Der Klang `transit.wav` (8 s, Stereo) ist eigene Synthese: Riser beim Ausblenden, Einschlag bei 2 s, Pad-Akkorde (Am(add9) → Fmaj7 → C(add9)), Arpeggio mit Ping-Pong-Delay, Antriebsdrohne, drei Vorbeiflug-Whooshes mit Doppler-Panorama, Abwärts-Sweep zum Anflug, Raumhall; zeitgenau zur Sequenz; er ist dem Charakter nach ein Weltraumflug, übernimmt aber keinen Originalklang. Nach dem letzten Level wird die Sequenz nicht gespielt (Rückkehr ins Menü).

## Kampagnenregeln
- **5 Leben** für den Lauf über alle Level; zerstörtes Taxi = −1 Leben, das Level läuft weiter (siehe unten); kein Leben = **Game Over** → Hauptmenü. Leben als Taxi-Symbole im HUD. Sprachwahl per Flagge auch im Pausenmenü. Levelauswahl und „Spielen/Weiter“ starten einen neuen Lauf (5 Leben, voller Tank, 0 Credits).
- **Sprit wird übernommen** (Mindestvorrat 35 %, Tankstellen: unter 35 % kostenlos, sonst Credits). **Credits laufen mit.** Hülle ist je Level voll.
- **Fahrpreis** = Fare × Zeitfaktor × (1 − Landeabzug): Zeitfaktor = clamp(1 + (1 − t/par)·0,6; 0,35; 1,6) mit t = Zeit vom Erscheinen des Fahrgasts bis zur **Ankunft in seinem Häuschen** (Fahrt + Gehzeit nach dem Aussteigen); Landeabzug je Landung bis 30 % (linear zwischen „weich“ 22 px/s und Limit 48 px/s). Der laufende Faktor steht im HUD.
- **Einkommen erst im Häuschen**: Die Credits werden erst gutgeschrieben, wenn die Figur ihren Unterstand erreicht hat. Die Gehzeit zählt zur Fahrzeit, also lohnt es sich, **nah am Häuschen zu landen**; über dem Kopf des Fahrgasts steht der voraussichtliche Betrag. Noch laufende Fahrgäste gelten beim Levelende als angekommen (Rest-Gehzeit eingerechnet).
- **Ausgangs-Fahrgast**: letzter Auftrag jedes Levels; das Tor öffnet, sobald er an Bord ist; er steigt im nächsten Level auf der Startplattform aus und wird **erst dort, bei Ankunft in seinem Häuschen, bezahlt** (die Zahlungsinfo fährt mit).
- **Absturz setzt das Level nicht zurück**: Zerstörtes Taxi = −1 Leben, aber Erledigtes bleibt erledigt. Der Fahrgast an Bord ist verloren (kein Geld) und **derselbe Fahrgast** wartet erneut an seinem Abholpad; das Tor schließt sich wieder, bis er eingesammelt ist. Neues Taxi am Startpad mit Rest-Sprit, mindestens 35 %. Nur der freiwillige Neustart (R/Menü) startet das Level komplett neu.
- **Fahrgast-Spawn**: nie auf dem Pad, auf dem das Taxi steht (Levelregel + Laufzeitschutz).
- **Absturz-Balance**: Aufprall bis 40 px/s harmlos, darüber Schaden = 100·((v−40)/110)^1,3 (60 px/s ≈ 11 %, 100 px/s ≈ 46 %), ab 150 px/s sofort zerstört. Mit ausgefahrenem Fahrwerk (Feinmodus) ist die Geschwindigkeit auf 90 px/s begrenzt – Sturzflüge gehen nur mit eingefahrenem Fahrwerk.

## Fahrpreis-Anzeige und Streckenzuschlag
- Der Betrag steht **dauerhaft über dem Fahrgast**: vom Erscheinen bis zum Einsteigen (tickt mit dem Zeitfaktor herunter) und vom Aussteigen bis zum Häuschen (tickt weiter, die Gehzeit zählt **2,5-fach**). Im HUD steht Zeitfaktor und aktueller Betrag („×1,50  ¢63“).
- **Streckenzuschlag** je Fahrt (1,0 … 1,6), aus dem Layout berechnet (`LevelMetrics.leg_mult`, zwischengespeichert): +30 % Streckenlänge, +20 % enger Korridor entlang der Route, +10 % kleines Ziel-Landefenster. Längere und schwierigere Wege zahlen mehr (S1-01 2→3: ×1,15; S1-02 3→2: ×1,35; S1-03 2→3 Schacht: ×1,36).

## Spritpreise und Zapfsäule
- Jedes Level hat **zufällige Spritpreise** in einem festen Bereich (Standard 0,40–0,90 ¢/Einheit, je Level in JSON `fuel: {min, max, every:[a,b]}` änderbar). Der Preis **wechselt sprunghaft** (nicht kontinuierlich) in **zufälligen Abständen** (20–45 s Levelzeit), jeder Wechsel ist spürbar (≥ 0,12). Reproduzierbar: Seed je Lauf (`Flow.run_seed`) + Levelnummer; `--seed=N` fixiert ihn. Unter 35 % Sprit tankt die Station weiterhin kostenlos.
- Das Tankpad hat eine **Zapfsäule** (Zeichen `P`, 1×2 Tiles, fest) am Padende mit **Preisanzeige** (grün/gelb/rot nach Preisniveau, blitzt beim Wechsel). **Berührt** das Taxi sie (Hülle oder Füße, Abklingzeit 1,2 s), steigt der Preis **sofort um 25 %** (gedeckelt bei 1,6 × Maximalpreis) und der Anzeigekopf **knickt in Stufen ab** (Stufe 1, 2, 3 mit Funken und flackernder Anzeige). Bei der **dritten Berührung** ist die Station sofort außer Betrieb und **explodiert** kurz darauf (Feuerball, Funkenregen, Druckwellenlicht, danach Schwelbrand mit Rauch); sie bleibt bis zum Neustart des Levels **defekt** (kein Tanken, auch nicht kostenlos). Kein Softlock: jeder Verlust eines Lebens gibt ≥ 35 % Sprit, Fortschritt bleibt erhalten.
- Einschränkung: Pro Level gibt es derzeit **eine** Tankstelle (Pad-Zeichen `F`).

## Gefühl, Kosmetik, Ton (fünfte Testrunde)
- **Vibration**: `Haptics` (Schub-Brummen, Landung nach Sinkrate, Schaden, Zerstörung, Zapfsäule, Explosion, Beinahe-Treffer); Stärke 0–1 in den Optionen.
- **Serie perfekter Landungen**: weich (≤ 22 px/s), seitlich ≤ 12 px/s, ≤ 4° Neigung; jede weitere in Folge +5 % Fahrpreis, höchstens +30 %; HUD zeigt Sterne und Prozent; harte/misslungene Landung oder Absturz setzt zurück.
- **Kamera-Gefühl**: leichter Vorausblick (≤ 4 px), Wackeln bei Treffern/Explosionen, **Beinahe-Treffer-Zeitlupe** (schnell ≤ 4 px an einer Wand vorbei: 0,5 s bei Zeitmaßstab 0,4, Sound, Vibration). Alles aus bei „Weniger Bewegung“.
- **Reflexionen** auf den Pads: Glanzstreifen und Spiegelbild des Taxis (mit Abgasflamme).
- **Garage** (Hauptmenü): 8 Lackierungen und 7 Aufkleber, nur Optik. Freischaltung über Statistiken (Level, perfekte Landungen, Auslieferungen, Serie, Abstürze, gesprengte Tankstelle; `data/cosmetics.json`), Hinweis beim Freischalten; „Nur Standardtaxi“ erzwingt den Challenge-Look. Lackierungen entstehen per Farbtransformation (`tools/art/gen_art.py`).
- **Schriften** (alle OFL): Jersey 10 (Titel), Oxanium (HUD/Menüs), Nunito (Untertitel/Fließtext); `Fonts`-Autoload mit Rückfall auf die Standardschrift.
- **Menü-Politur**: schimmernder Titel, gleitende Menüeinträge, Credits-Abspann mit scrollendem Text.
- **Mehr Sprache**: Fahrgast an Bord kommentiert Landungen („Wow, sanft!“ / „Aua!“), **Tankwart** (eigene Stimme) schimpft bei Berührungen der Säule (3 Stufen) und kommentiert Preiswechsel, die **Zentrale** (Funkfilter) meldet sich in der Weltraumsequenz (Sektor-Intro beim ersten Level eines Sektors, sonst allgemeine Zeilen als dezente Story). Texte stehen in `data/voice_lines.json` (Quelle für Generator und Untertitel).
- **Musik** (C64-SID-Klang): 21 Themen (Menü + t00..t19, **ein Thema je 5 Level**), je 3 synchrone Schichten über `AudioStreamSynchronized`: A Basis (Bass + schnelles Akkord-Arpeggio), B Bewegung (Melodie mit PWM/Vibrato und SID-Echo + Gegenstimme; bei Fahrgast an Bord, offenem Tor oder Tempo), C Spannung (Dreieck-/Rauschen-Schlagzeug; bei wenig Sprit, Schaden, Beinahe-Treffer). Ducking in Sequenzen, Pause und während Sprache. Eigene Synthese (`tools/audio/gen_music_sid.py`: Pulswellen mit PWM, Dreieck, Säge, Rauschen), **32 Takte** (A, A-Variation, B, A mit Schluss, ~55–77 s), mono, nahtlos loopbar.

## Abschluss Vertical Slice (M2)
- **Optionen** als Kategorien: Ton (Musik/Effekte/Stimmen/Untertitel), Steuerung (Belegung, Deadzone, Vibration, Fahrwerk Umschalten/Halten), Anzeige (Vollbild, V-Sync, **FPS-Limit** 30/60/120/144/240/unbegrenzt, FPS-Anzeige, Weniger Bewegung), Spiel (Sprache, Tutorial-Hinweise).
- **Medaillen je Level** (dauerhaft, über Läufe vereint): ⏱ Zeit (≤ 1,2 × Summe der Richtzeiten + 10 s) · ♥ Sauber (kein Leben verloren, nie Fahrgast/Zapfsäule getroffen, ≤ 10 % Schaden) · ★ Meister (≥ 110 % des Einkommensziels und Serie ≥ 2). Anzeige nach dem Level (Zeit gegen Ziel/Bestzeit, drei Sterne), in der Levelauswahl (★★☆, drei Sterne je Level) und in der **Statistik** (Hauptmenü).
- **Tutorial-Hinweise** (Level 1 und bei Bedarf): Schub, Fahrwerk, Landeampel, Fahrgast/Zeit, Tankstelle, Tor – je einmal pro Profil, 7 s sichtbar, in den Optionen abschaltbar.
- Die Kamera nutzt den Physik-Takt (`CAMERA2D_PROCESS_PHYSICS`); die Simulation läuft in festen 120-Hz-Ticks mit Rendering-Interpolation (framerate-unabhängig, bis 240 Hz und darüber).

## Größen, Landefenster, Fahrgast-Kollision
- **Taxi 20 % kleiner** (`Tuning.TAXI_SCALE = 0.8`: Hülle 16×8, Füße ±6,4, Fahrwerk 4), Fahrgäste und Unterstände auf 85 %. Das Taxi-Node wird skaliert, der Zeichencode bleibt in Entwurfsmaßen; die Physik nutzt die kleineren Kollisionsmaße.
- **Pads sind unterschiedlich groß** (5–8 Tiles). Das **freie Landefenster** je Passagierpad (`land_window`) = Bereich, in dem die Füße auf dem Pad stehen und der Abstand zum wartenden Fahrgast (Hülle + Fahrgast + 2 px) gewahrt ist. Je kleiner das Fenster, desto schwerer; Die Untergrenze gilt **je Pad** (Level 1–3: 34 px, bis Level 99 sinkend auf 20 px); **größere Pads im selben Level sind jederzeit erlaubt, und innerhalb eines Levels dürfen unterschiedlich große Pads gemischt auftreten** (z. B. 5, 6 und 8 Tiles) – vorgeschrieben ist nur die Untergrenze. Autopilot und Bot-Hover nutzen die Fenstermitte (`land_mid`).
- **Fahrgast-Kollision**: Berührt das Taxi (Hülle oder ausgefahrene Füße) einen wartenden/auftauchenden Fahrgast (nicht beim Aufsteigen, nicht beim Einsteigen), schimpft er („Hey, Idiot!“, Untertitel, Ärger-Blase) und flieht schnell in den Unterstand. Für denselben Auftrag erscheint nach 2,4 s ein **anderer Fahrgast an einem anderen Passagierpad** (deterministisch je Level/Auftrag/Versuch; nicht Zielpad, nicht der Vorfall-Pad). Anzahl der Fahrgäste je Level bleibt gleich; die Auftragszeit läuft weiter (Zeitfaktor sinkt), der Umweg kostet Sprit.

## Optik (Finesse und Räumlichkeit)
Normal-Maps auf den Tiles (aus der Helligkeit der Platten abgeleitet, Stärke 3) lassen Nieten, Paneele und Lüftungen auf Taxi- und Pad-Licht reagieren; Lichthöhe ~55 % des Radius. Kontaktschatten des Taxis, Schlagschatten/AO an den Tiles, Vignette (Shader), Bloom (WorldEnvironment-Glow, Schwelle 0,92), Dunstbänder zwischen den Skyline-Ebenen. **Kein HDR-2D** (verfälscht die Farbwiedergabe und macht das Bild zu dunkel) und keine globale Farbkorrektur. Umgebungslicht `CanvasModulate` (0,86 / 0,90 / 1,0).

## Hauptmenü
Animierter Hintergrund (`src/ui/menu_backdrop.gd`): ziehender Nebel, funkelnde Sterne, Sternschnuppen, ferner Raumverkehr mit Positionslichtern und Abgasspur, ein großes Taxi im Vordergrund alle ~11 s, driftende Skyline-Ebenen (jede zweite Kachel gespiegelt = nahtlos), Dunst. Bei „Weniger Bewegung“ statisch. Sprachflaggen zentriert im Auswahlrahmen.

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


## Dornen
Dornenzellen (`^`) sind fest wie Fels, verursachen aber bei jeder Berührung festen Zusatzschaden (`Tuning.SPIKE_DAMAGE` = 30 Hülle, unabhängig vom Tempo; 0,5 s Sperre gegen Mehrfachzählung). Sie zählen in der Schwierigkeitsmetrik als Gefahr. Erstes Auftreten: S1-08.

## Zusatzfahrgäste und Ökonomie (siebte Runde)
- **Zusatzfahrgäste** (`Run.extras`, ab Level 5, Anzahl je Level in `Tuning.extra_slots`): erscheinen in zufälligen Abständen (9–18 s) an einem freien Passagierpad mit zufälligem Ziel, auch während das Taxi jemanden fährt. Das Taxi hat einen Sitz: Solange ein Zusatzfahrgast an Bord ist, steigt der Auftrags-Fahrgast nicht ein (und umgekehrt). Geduld 42–70 s; danach schimpft der Fahrgast („bored“-Sprachzeile) und geht. Bezahlung wie beim Auftrags-Fahrgast (Zeitfaktor, Streckenzuschlag, Serie), aber nicht Teil des Levelziels; zählt für die Einkommens-Medaille.
- **Pause nach dem Absetzen**: Der nächste Auftrags-Fahrgast erscheint nach zufälligen 2,5–6 s (nicht sofort, nicht ewig).
- **Kosten**: Sprit 2,0–4,2 ¢/Einheit × (1 + 0,03·(Level−1)); Reparatur 2 ¢ je verlorenem Hüllenpunkt am Levelende; Ersatztaxi 80 ¢ + 2 ¢·Level je Totalschaden. Credits fallen nie unter 0; unter 35 % Tank bleibt das Tanken kostenlos (keine Sackgasse).
- **Backlog**: eigenes Taskleistensymbol (M6).

## Rückmeldungen Runde 8: Abzüge, Geduld, Belohnungen
- **Pfeil/Leuchtfeuer und Auftragszeile** erscheinen erst, wenn der Fahrgast tatsächlich da ist (`Run.marker_pad`); bis dahin „Warte auf den nächsten Fahrgast …“.
- **Falsche Plattform** (Landung mit Fahrgast an Bord an einem anderen Passagierpad als dem Ziel): der Fahrgast meckert (Sprachzeile, Untertitel), Fahrpreis −15 % je Landung. **Schaden mit Fahrgast an Bord**: −8 % je Treffer, er meckert. Beide Abzüge (`Run.pen_ride`, höchstens −50 %) wirken wie die Landeabzüge auf die Auszahlung; Tanken am Tankpad zählt nicht als falsche Plattform.
- **Spritpreis ist beim Tanken eingefroren**: Während Sprit fließt, wird ein fälliger Preiswechsel verschoben.
- **Tankpads** haben unterschiedliche Größen (5–8 Tiles, Test: mindestens vier verschiedene Breiten); in späteren Leveln liegen sie schwerer zugänglich (Zapfen darüber in S1-11; weitere Ausbaustufen mit den Sektoren). Untergrenze des freien Landefensters bleibt 28 px.
- **Geduld**: Zusatzfahrgäste 20–34 s, Auftrags-Fahrgäste 45–70 s; danach schimpfen sie und gehen (Auftrags-Fahrgast wird durch Ersatz an anderem Pad ersetzt, zählt nicht als „Fahrgast getroffen“).
- **Belohnungen**: Auftrags-Fahrpreise werden ab Level 5 auf 22 % gesenkt (`Tuning.fare_scale`, Level-Daten unverändert), Zusatzfahrgäste zahlen nach dem unskalierten Durchschnitt – ohne Zusatzfahrten bleibt man ab Level 5 etwa auf null, mit ihnen im Plus. Spritpreise unverändert.

## Rückmeldungen Runde 9
- **Verpasste Pflichtfahrgäste**: Wartet ein Auftrags-Fahrgast zu lange, geht er **ohne Ersatz**; der Auftrag gilt als verpasst (Abzug: 35 % des unskalierten Fahrpreises, nie unter 0 Credits) und das Level hat entsprechend weniger Beförderungen. Nach dem letzten Pflichtfahrgast – befördert oder nicht – öffnet das Tor. (Ersatzfahrgast gibt es weiterhin nur nach Kollision und nach Absturz.)
- **Falsche Plattform**: Das Abholpad und das Tankpad zählen nie als falsch (Nachsetzen nach dem Abheben); der Ausgangs-Fahrgast meckert bei jeder Landung auf einem Passagierpad.
- **Fortsetzen / Neues Spiel**: Nach jedem Level wird der Feldzug gespeichert (nächstes Level, Leben, Credits, Sprit, Seed, mitfahrender Fahrgast). „Fortsetzen“ lädt ihn, „Neues Spiel“ startet bei Level 1 mit vollen Leben und löscht ihn; Game Over löscht ihn ebenfalls. Medaillen, Bestzeiten und Statistik bleiben immer erhalten.
- **Plattform-Wimpel**: Statt der blinkenden Laterne trägt jede Plattform einen dreieckigen, leicht wehenden Wimpel mit ihrer Nummer (Tankpad: „T“); beim Ziel-Pad leuchtet er gelb. **Sprechblase**: Nach dem „!“ zeigt jeder wartende Fahrgast in einer Blase die Zielplattform (Pfeil nach oben = Ausgang).

## Bewegliche Tore und Preisregeln (Sektor 2, Runde 10)
- **Bewegliche Tore** (Raster-Zeichen `a`–`e`, Takt im JSON unter `doors`: `period`, `open`, `phase`): geschlossen fest wie Fels, offen passierbar; sie schließen nie auf dem Taxi (Hüllen-/Fahrwerksbereich) und blinken 1,3 s vor dem Schließen gelb. Der Torzustand folgt der Simulationszeit (deterministisch, Replay-tauglich). Die Wegplanung behandelt Tore als offen; der Bot wartet davor und fliegt nur hinein, wenn das Tor bei frühester Ankunft offen ist und bis zur spätesten Ankunft plus Durchflugzeit offen bleibt. Beim Levelwechsel-Einflug stehen alle Tore offen. Tore bis zur Decke erzwingen die Passage (Tor-Wände dürfen nicht in den Torblock-Korridor reichen); Zwischendecken mit Falltür trennen Ebenen.
- **Mindest-Fahrpreis** (`Run.min_fare`): Jeder Auftrag zahlt mindestens so viel, dass er bei **25 % Zufriedenheit** (Zeitfaktor 0,66) noch Gewinn nach geschätztem Spritverbrauch (Strecke × 1,6 Anflug × `FUEL_PER_PX`, mittlerer Spritpreis des Levels, +15 %) abwirft. Test: Autopilot-Sprit ≤ Einnahmen bei 25 % je Level.
- **Preise ruhen**, solange getankt wird und **sobald die Zapfsäule defekt ist**. **Neues Taxi** (nach Totalschaden) startet immer mit **vollem Tank**.
- **Betrag über dem Fahrgast** wird nie abgeschnitten (Breite folgt dem Text); der mitfahrende Zusatzfahrgast zeigt Faktor und Preis in der unteren Leiste.
