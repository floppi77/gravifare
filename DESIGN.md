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

## Runde 11: Verluste, Obergrenzen, Lebens-Station, Pflicht gegen Zusatz
- **Tor schließt auf dem Taxi**: 30 Hülle Schaden, das Taxi wird zur nächsten freien Seite hinausgeschleudert (70 px/s). Der Bot rechnet früheste/späteste Ankunft und Durchflugzeit ein und kommt unbeschadet durch.
- **Leerer Tank** (außer auf einer funktionierenden Zapfsäule): Warnung „TANK LEER! 3 s“, danach ist das Taxi verloren – Leben −1, neues Taxi mit vollem Tank, das Level läuft weiter.
- **Zusatzfahrgäste** werden bei Berührung durch das Taxi wie Pflichtfahrgäste getroffen: sie schimpfen und verschwinden (zählt als „Fahrgast getroffen“, kein Ersatz).
- **Obergrenzen** `Tuning.max_jobs` / `Tuning.max_pads` (siehe LEVELS.md); Sektor 2 hat höchstens 6 Pflichtfahrgäste.
- **Lebens-Station** „L“: ¢1000 pro Leben, höchstens 5 Leben, alle 5 Level eine kleine Plattform (rosa Wimpel mit Herz und Preis; grau, wenn voll oder zu wenig Credits).
- **Pflicht gegen Zusatz**: Pflichtfahrgäste tragen einen goldenen Stern, goldenen Betragsrahmen und gelbe Zielblase; die Zeile unten beginnt mit „★ PFLICHT“. Zusatzfahrgäste sind bläulich-blass mit cyanfarbenem Rahmen und weißer Zielblase (Zeile „ZUSATZ“). Fährt ein Zusatzfahrgast mit, erinnert eine goldene Zeile an den offenen Pflichtfahrgast.
- **Schwierigkeits-Feinabstimmung Sektor 2**: Dornenbänder an der Decke (Zeile 1) heben die gemessene Schwierigkeit; die Metrik zählt sie als Gefahren.

## Fahrgast rauswerfen (Runde 12)
Taste **E** / Gamepad **Y** (frei belegbar; Neustart wanderte auf **Back**, alte Belegungsdateien werden migriert): Der Fahrgast an Bord (Pflicht- oder Zusatzfahrgast) wird aus dem Taxi geworfen. Aus ≥ 24 px Höhe fällt er (Gravitation 380 px/s², dreht sich, „AAAH!“, Schrei-Sound je Stimme), stirbt beim Aufprall (Splat-Sound, kleines Rütteln) und bringt **kein Geld**. Aus dem Stand oder geringer Höhe überlebt er, schimpft und läuft in den Unterstand – ebenfalls ohne Geld. Ein Pflichtauftrag gilt danach als verpasst (Abzug wie bei zu langer Wartezeit, nach dem letzten Pflichtauftrag öffnet das Tor), ein Zusatzfahrgast ist einfach weg. Die Sauber-Medaille entfällt. Der Wurf wird als Ereignis im Replay aufgezeichnet.

## Bewegliche Hindernisse und Plattformen (Sektor 3, Runde 13)
- **Mover** (JSON `movers`): `debris` (Trümmerbrocken, Schaden 15 je Berührung, Sperre 0,6 s), `slider` (großer Block, Quetschung 30; bisher in keinem Level genutzt) und `pad` (Landeplattform auf waagerechter Schiene). Bewegung nach der Simulationszeit: Linie (`dx`,`dy` Amplitude in Tiles, `period`, `phase`) oder Kreis (`shape: circle`). Mover sind fest (Kollision, Landefüße); ein Mover, der in das Taxi fährt, schiebt es zur Seite mit der kleinsten Überlappung hinaus und verursacht Schaden.
- **Fahrende Pads**: Fläche, Landefenster, Wartepunkt und Unterstand fahren mit; gelandete Taxis und wartende/aussteigende Fahrgäste fahren mit (Position und Laufziel werden je Tick verschoben). Die Landegeschwindigkeit zählt **relativ zur Plattform**; beim Abheben übernimmt das Taxi ihr Tempo. Höchsttempo der Plattformen bewusst klein (≈ 13 px/s: 2 Tiles Hub, 16 s Takt).
- **Planung und Bot**: Die statische Wegplanung ignoriert Trümmer; fahrende Pads belegen ihren ganzen Fahrweg als feste Fläche. Der Bot sagt Trümmer im Ankunftszeitfenster voraus (schwebt, wartet), weicht Hindernissen aus, die auf ihn zukommen, und folgt beim Landeanflug dem Pad (Mitnahme-Geschwindigkeit als Vorsteuerung).
- **Obergrenzen** ab Level 23: fünf Passagierpads (siehe LEVELS.md). Lebens-Stationen in Level 25 und 30.
- Fahrgasttyp „zerbrechlich“, Meteoritenschauer und Schieber kamen in Runde 15 hinzu (siehe unten).

## Runde 14: HUD-Streifen, Sektor-Hintergründe, schmalere Pads
- **HUD nur in den Randstreifen**: oben auf der Felsreihe 0 (y 0–16: Tank, Hülle, Credits, Leben, Serie, Spritpreis, „Nr/99 Name“, Fortschritt, Landeampel als drei dünne Balken; x 296–344 bleibt für das Torschild frei), unten unter der Bodenreihe (y 337–360: Auftragszeile mit Preis, darunter Steuerungs-/Tutorialhinweis links und Untertitel/Pflicht-Erinnerung rechts). Das Spielfeld dazwischen bleibt frei von UI-Überlappung; nur kurze Meldungen („Funkruf …“) erscheinen vorübergehend mittig.
- **Eigener Hintergrund je Sektor** (`bg_sN_far/mid/near.png`, Sektor 2–9 aus `tools/art/gen_backgrounds.py`, ersetzbar durch externe Grafiken, Vorgaben in `docs/HINTERGRUENDE.md`). Dev-Flag `--bg=N` zeigt einen anderen Sektor.
- **Mindest-Landefenster**: bis Level 27 mindestens 34 px (Pads ab 5 Tiles), ab Level 28 darf es auf 18 px sinken (Pads mit 4 Tiles). Sektor 3 nutzt ab Level 28 schmale Pads.
- **Trümmer** bewegen sich je Brocken unterschiedlich schnell und etwas schneller als zuvor (Perioden ≈ 5–9 s); fahrende Pads haben je Plattform eigenes Tempo (bis ≈ 20 px/s).
- **Bot (Mover)**: prüft seine Bahn (Anfahrt auf die Wunschgeschwindigkeit) gegen die vorhergesagten Hindernisse und weicht in freie Richtungen aus; plant nach dem Warten neu.

## Runde 15: Bilder, zerbrechlich, Meteoriten, Schieber, Zonen, Sektor 4
- **Hintergründe**: je Sektor ein extern erstelltes Bild `assets/art/bg_sN.png` (1920×1080), gezeichnet 1,06-fach mit 5 % Parallax und je Sektor abgedunkelt (`Backdrop.DIM`); Zuordnung und Abdunklung in `docs/HINTERGRUENDE.md`. Das Logo (`assets/art/logo.png`) ersetzt die Textüberschrift im Hauptmenü.
- **Zerbrechlicher Fahrgast** (Job-Flag `fragile`, +25 % Fahrpreis): jede Beschädigung an Bord (Aufprall, Trümmer, Dornen …) beendet die Fahrt – Fahrgast zerspringt (Scherben), Auftrag gilt als verpasst (`Run._fragile_break`). HUD-Marke „◇ ZERBRECHLICH“. In S3-05, S3-08 und S3-10.
- **Meteoritenschauer** (Mover `meteor`: Startpunkt, Fallstrecke dx/dy, `fall`, `period`, `phase`, `warn`): fällt je Periode einmal, sonst unsichtbar; 2 s vorher blinkt die Bahn und es gibt Warnton/Meldung (`meteor_warn`). Schaden 20, der Aufprall überträgt nur 30 % der Fallgeschwindigkeit (streift). Der Bot weicht aus (`LevelData.meteor_threat`): bedrohte Bahn seitlich verlassen, nicht hineinfliegen. In S3-05, S3-07, S3-09, S3-10, S3-11.
- **Schieber** (großer Block, Quetschung 30) in S3-11 (Kreuzung über Pad 3).
- **Zonen-Engine** (JSON `zones`, `LevelData.zone_accel`): `wind` (Strömung), `gravity` (Schwerkraftfaktor), `magnet` (Kreis, `k` > 0 zieht, < 0 stößt ab, linear abfallend); optional `period`/`on`/`phase` (Pulsieren). `TaxiSim` addiert die Beschleunigung, der Bot gleicht sie aus (Vorsteuerung). Zonen zählen als Gefahr (je 2) in der Metrik. Wind und Schwerkraft sind implementiert und gezeichnet, aber noch in keinem Level genutzt (Sektor 6).
- **Sektor 4 „Magnetfeld“** (Level 34–44): sechs Passagierpads, sieben Aufträge, Magnetzonen (zeitweise schaltend), Dornen unter den Ablagen; Lebens-Stationen in 35 und 40.

## Runde 16: Flugpflicht für „perfekt“, Magnete, Krankentransport, prozedurale Level, Funksprüche, Sektor 5
- **Perfekte Landung** zählt nur nach echtem Flug: mindestens 1,5 s Flugzeit und 40 px Strecke seit dem Abheben (`TaxiSim.air_t/air_path`, `Tuning.PERFECT_MIN_*`). Ein Hüpfer direkt nach dem Abheben ist weder perfekt noch ein Serienbruch.
- **Magnete** spürbar: Stärke ×2 (90–120 px/s² am Kern, Abfall quadratisch zum Rand), Rütteln/Funken/Rumble und Meldung im Feld (`Game._field_feedback`). Darstellung: Spule mit Hufeisen, Feldlinien, einströmende (Anziehung) bzw. ausströmende (Abstoßung) Partikel, Energieringe; pulsierende Felder flackern vor dem Einschalten.
- **Krankentransport** (ersetzt „zerbrechlich“ in der Anzeige): Job-Flag `fragile` + Ziel `H` (Krankenhaus-Pad mit rotem Kreuz, nur Ziel, kein nummeriertes Passagierpad). Jede Beschädigung an Bord beendet die Fahrt (Auftrag verloren). HUD-Marke „+ KRANKENTRANSPORT“, Meldung beim Einsteigen, Ziel-Sprechblase mit rotem Kreuz, Ansage „Zum Krankenhaus, bitte!“. Erstmals in Level 27; ebenso in den übrigen Leveln mit Krankenhaus-Pad (siehe LEVELS.md, Spalte Krankentransport).
- **Meteoriten** als unregelmäßige Felsbrocken (Krater, Feuerschweif); Dev-Flag `--skip-time=<s>` spult die Spielzeit vor (für Screenshots).
- **Plasmastrahl** (Mover `beam`: Rechteck, `period`, `on`, `phase`, `warn`; 25 Schaden, kein Hinausschieben) und **Hitzezone** (Zone `heat`: 3 Hülle alle 0,25 s; Bot plant darum herum). Der Bot weicht Strahlen wie Meteoriten aus (waagerechte Strahlen nach oben/unten).
- **Menü**: Knöpfe mit Verlauf, dünner heller Kante, abgerundeten Ecken und dunkler Unterkante (Textur zur Laufzeit erzeugt); Hauptmenü kleiner und links; Logo statt Textüberschrift.
- **Dev**: `--level=<Nummer | s4_01 | S4-01>`; Levelauswahl komplett frei (`Save.DEBUG_UNLOCK_ALL`, vor der Veröffentlichung zurücknehmen).
- **Prozedurale Level (Sektor 3–5)**: `tools/procgen.py` baut je Seed einen eigenen Grundriss (Inseln, Pfeiler, Wandsimse, Stalaktiten/Stalagmiten, reservierte Meteoritenbahnen), `tools/build_sector.py` misst Kandidaten mit dem Bot (`tools/batch_eval.gd`, Vorfilter Wegplanung mit Bot-Rand 7 px), stellt per Dornenzahl die Metrik ein und wählt per DP eine über alle Level monoton steigende Folge. Sektor 5 ist ein Teilsektor (7 Level), weil nur so viele Kandidaten Bot-lösbar und über dem Metrik-Boden von Sektor 4 lagen.
- **Funksprüche**: je Level ein eigener Spruch der Zentrale (`data/voice_lines.json`, Gruppe `d0`, Schlüssel `r<Level>`), erzeugt mit `tools/radio_lines.py` und `tools/audio/gen_voice.py`; Sprüche zu neuen Elementen nennen diese. Level 52–55 haben noch keinen Spruch (gibt es noch nicht).

## Runde 17: Krankenhaus, Strahl, Lava, Sektor 5
- **Krankenhaus-Pad** wird jetzt mit Boden gezeichnet (`H` fehlte in der Tile-Zeichnung).
- **Krankenpatienten**: Geht ein Patient verloren (Beschädigung an Bord, Rauswurf), entfällt nicht nur die Bezahlung – es wird zusätzlich der *aktuelle Preis* als Strafe abgezogen (`Run._lose_job(extra_fee)`, auch für Zusatz-Patienten). In Levels mit Krankenhaus gibt es einen zweiten Pflicht-Krankentransport (Level 27, 31, 32, 37, 42) und 35 % der Zusatzfahrgäste sind Patienten (Ziel Krankenhaus).
- **Plasmastrahl** ist nicht mehr fest: man fliegt hindurch und verliert 12 Hülle alle 0,3 s, solange man darin ist (vorher blieb das Taxi darin hängen).
- **Hitzezone als Lavablase**: wabernder Magma-Klumpen mit Kruste, Rissen, Blasen, Tropfen, Funken und Hitzeflimmern; pulsierende Auslässe sind erkaltet und glühen vor dem Einschalten auf.
- **Sektor 5** hat Level 45–54 (10 Level); Level 55 (Lebensstation, Abschluss) fehlt noch, weil kein Kandidat über dem Metrik-Boden (≈ 175) bot-lösbar war. `build_sector.py 5 --extend --slots=<n>` ergänzt einzelne Slots.

## Runde 18: Patientenverlust, Meldungen im HUD, Sektor 5–6
- **Patient verloren** (Ereignis `patient_lost` mit Strafbetrag, auch bei Rauswurf und Zusatz-Patienten): Glasklirren, nach 0,45 s der EKG-Dauerton (`flatline`), nach 2 s die Zentrale („Patient verloren. Das wird teuer.“), Wackeln und Rumble. Im HUD erscheint **unten rechts** (anstelle von Faktor/Preis) ein roter Streifen mit EKG, das in die Nulllinie übergeht, plus „PATIENT VERLOREN – Name – −¢Betrag“. Kein Vollbild-Effekt mehr.
- **Alle Meldungen** (`flash_message`) stehen jetzt in der unteren Zeile **rechts**; gesprochene Untertitel ersetzen links kurz den Steuerungshinweis. Texte schrumpfen bis 6 px, damit nichts abgeschnitten wird.
- **Tank-Piepen** wird mit sinkendem Tank schneller (1 s bei 25 % bis 0,12 s bei fast leerem Tank).
- **„Neu:“-Ansagen** nur beim tatsächlich ersten Auftreten (per Skript gegen die Level-Daten geprüft); Ansagen zu Takt-Elementen (Level 37, 47, 58) wurden verständlicher formuliert. Pulsierende Magnete, Lavablasen und Böen zeigen einen Taktring (grün = noch aktiv, gelb = kommt gleich wieder).
- **Metrik**: ab Sektor 6 Sektorzuschlag +25 je Sektor (`LevelMetrics.SECTOR_BONUS`), weil Gefahren (3,0) und Mechaniken (12) in Sektor 3–5 ihre Obergrenzen erreicht hatten; innerhalb jedes Sektors steigt die Folge weiter an.
- **Sektor 5** ist mit Level 55 komplett (Level 45–55). **Sektor 6 „Gezeitenorbit“** (Level 56–66): Strömungen (`wind`), böige Strömungen, Schwerkraftzonen (`gravity`), acht Aufträge, Krankentransporte in 58, 61 und 65; Lebensstationen in 62 und 64.

## Runde 19: Wind, Trage, Sektor 7
- **Kraftzonen überlappen nicht**: Strömung, Schwerkraft und Magnete heben sich in keinem Level mehr auf (Test `_test_force_zones_apart`; Generator verwirft Überlappungen, bestehende Level 42–44, 54 und 57–66 wurden mit `tools/zonefix.py` bereinigt: Zonen zugeschnitten, Magnetradien verkleinert, überzählige Zonen entfernt).
- **Wind**: Strömungen werden als wehende Schlieren mit kleinen Wirbeln und Pfeilspitzen an der Austrittskante gezeichnet (schneller bei stärkerem Wind); Böen sind ausgeschaltet nur ein schwaches Flimmern.
- **Krankenpatienten** liegen auf einer Rolltrage (blasses Gesicht, Decke mit rotem Kreuz, Infusionsständer mit tropfendem Beutel) und gleiten statt zu gehen (`PassengerActor.medical`); Dev-Flag `--debug-medical`.
- **Sektor 7 „Transitknoten“** (Level 67–73): Mover `vehicle` (Verkehr) – Fahrzeuge fahren mit `speed` px/s auf einer Bahn der Länge `dx` Felder und treten am Ende ohne Pause wieder ein, Gegenverkehr durch negatives Tempo; Schaden 18. Lichtbahn mit Richtungspfeilen, Schweber mit Kuppel, Scheinwerfer und Triebwerksglühen. Sieben Passagierpads, acht Aufträge, Krankentransporte in 68 und 73, Lebensstationen in 69 und 72. Teilsektor: nur 7 der 11 Level waren Bot-lösbar und über dem Metrik-Boden.

## Runde 20: Verkehr durch Wandöffnungen, Windbänder von Wand zu Wand
- **Verkehr (Sektor 7)** fährt Wand zu Wand: Fahrzeuge treten durch Tunnelöffnungen in der linken bzw. rechten Außenwand ein und durch die Gegenseite wieder aus (Portale mit Rahmen, Pfeilen und Ein-/Ausgangslicht, `_draw_vehicle_portals`); das Taxi kann die Öffnungen nicht betreten. Die Bahnen liegen im freien Band zwischen den Plattformen, die der Generator reserviert (`procgen.build(bands=…)`); Kandidaten, bei denen weniger als drei Flugstrecken der Aufträge das Band kreuzen, werden verworfen („Verkehr liegt abseits der Flugrouten“). Der Autopilot steigt aus einer Verkehrsbahn senkrecht aus, wenn er darin warten müsste.
- **Windbereiche** reichen immer von Wand zu Wand: waagerechte Bänder (linke bis rechte Wand) oder senkrechte Schächte (Decke bis Boden), gezeichnet nur durch Luft. Die Windzonen in Level 56–66 wurden entsprechend verlängert (in 60, 62 und 64 mit geringerer Stärke, damit der Autopilot sie löst).
- **Sektor 7 „Transitknoten“** ist mit Level 67–77 komplett (zwei Verkehrsbänder je Level, ab 70 Windbänder mit Böen und ein Magnet); Krankentransporte in 68, 70, 71, 75 und 77, Lebensstationen in 67 und 74.

## Runde 21: Ergebnisansicht, Hüttenlicht, Fahrzeugrouten, Dunkelheit, Grundriss-Vielfalt, Sektor 7/8
- **Ergebnisansicht** neu: zentrierte Tafel mit Kopfband (Level-Nummer und Name), drei Medaillenkarten, linke Spalte Zeit mit Balken und Zielmarke, rechte Spalte Einnahmen und Abzüge, unten ein Ergebnisband (Netto, Kontostand, Punkte). Medaillen: ⏱ Zeit = Levelzeit ≤ Σ Pars × 1,2 + 10 s; ♥ Sauber = kein Leben verloren, kein Fahrgast zerquetscht oder rausgeworfen, Zapfsäule nie berührt, ≤ 10 Hülle Schaden insgesamt; ★ Meister = Einnahmen ≥ 110 % des Einkommensziels (Σ Fahrpreise × Entfernungsfaktor ohne Ausgangs-Fahrgast) und beste Serie ≥ 2 perfekte Landungen.
- **Wartehütten leuchten**: warmes Fensterlicht, Halo und Lichtfleck auf der Plattform; mit wartendem Fahrgast heller und leicht flackernd.
- **Fahrzeuge** sind kleine Taxis (gleiche Grafik in anderen Lackierungen, Triebwerksflamme, Scheinwerferkegel). Sie fahren **Pfade** (`"path"` in Feldern): gerade, Z-förmig (links rein, rechts raus auf anderer Höhe) oder U-förmig (links rein, links wieder raus), jeweils durch Wandöffnungen; auf senkrechten Abschnitten stehen sie hochkant. Der Generator reserviert die Pfade (`procgen.make_routes`) und hält verschiedene Pfade überschneidungsfrei; der Autopilot steigt aus einem Pfadabschnitt senkrecht zu ihm aus.
- **Sektor 8: Dunkelheit und Radar** (`"dark"`, `"radar"` im Level): Vollbild-Shader (`dark_view.gd`) dunkelt ab; beleuchtet sind Taxi, Plattformen, Tor und leuchtende Gefahren (Fahrzeuge, Meteoriten, Trümmer, aktive Strahlen, Lavablasen). Der Radar schickt alle `radar` Sekunden einen Ring vom Taxi aus, der das Gelände kurz sichtbar macht (Ton `radar`). Dev: `--dark=0.8 --radar=6`.
- **Grundriss-Vielfalt**: `tools/similarity.py` misst Ähnlichkeit; `pad_dist` (mittlerer Abstand der Pad-Mittelpunkte) muss für Level innerhalb von 8 Leveln ≥ 2,4 sein, sonst ≥ 1,5. Der Bauablauf verwirft ähnliche Kandidaten; `tools/replace_levels.py <Level…>` ersetzt bestehende Level durch neue Grundrisse mit gleichem Rezept (Level 30, 58, 61, 85 ersetzt; 69 und 74 fanden keinen passenden Ersatz im Score-Fenster).
- **Sektor 7** (Level 67–74) und **Sektor 8** (Level 78–85) sind Teilsektoren; die Nummern 75–77 und 86–88 fehlen. Metrik: Sektorzuschlag +25 je Sektor ab 6.
