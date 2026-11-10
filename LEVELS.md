# LEVELS – Leveldesign-Matrix

Verbindliche Regeln: Pad-Nummern sind fortlaufend 1..N; jedes Pad hat Platz für einen Wartebereich-Unterstand (2 Tiles Luft über einem Padende); das Ausgangstor liegt mittig oben und öffnet erst, wenn der **Ausgangs-Fahrgast** (letzter Auftrag, `to: "exit"`) an Bord ist; jeder Auftrag hat einen eigenen Fahrgast; der erste Fahrgast wartet nicht auf dem Startpad, und jeder Fahrgast beginnt an einem anderen Pad, als der vorherige endete; unter dem Torblock bleiben mindestens 96 px Durchflug. Das Tankpad (`F`) braucht eine 2 Tiles hohe Zapfsäule (`P`) am Padende und ein freies Landefenster ≥ 28 px; Preisbereich je Level optional (`fuel`). Jedes Level muss der Bot **ab dem Mindest-Sprit (35 %)** lösen; seit Runde 60 (unter 35 % gratis nur ohne Geld) gilt das für die in TESTING.md geführten Level nur mit dem Regelstand 2 (Fliegbarkeit), siehe dort. **Pads sind unterschiedlich groß** (5 bis 8 Tiles; je kleiner, desto schwieriger), aber jedes Passagierpad hat ein **freies Landefenster** neben dem Wartebereich, mindestens 34 px in Level 1–3, **sinkend bis 20 px in Level 99** (`Tuning.min_land_window`, Test) – späte Level dürfen deutlich kleinere Plattformen haben. Die Grenze gilt je Pad: **Größere Pads im selben Level sind erlaubt, unterschiedlich große Pads innerhalb eines Levels dürfen gemischt auftreten.**

Status: **99 von 99 Leveln vorhanden** (alle Sektoren komplett). Erzeuger: `tools/make_level_s1_01.py`, `tools/make_s1_02_03.py`, `tools/make_s1_04_11.py` (Pars dort als Tabelle), `tools/make_s2.py`, `tools/make_s3.py`, `tools/make_s4.py` (Pars je Sektor in `tools/sN_pars.json` = Bot-Zeit × 1,3 + 8 s). Sektor 2: `tools/make_s2.py`; **Sektor 3–5 prozedural**: `python3 tools/build_sector.py 3|4|5` (Grundriss-Generator `tools/procgen.py`, Bausteine `tools/levelparts.py`, Bot-Messung `tools/batch_eval.gd`; Pars = Bot-Zeit × 1,3 + 8 s). Übersichtsbilder: `docs/levels/`.

## Obergrenzen und Plattform-Stufen (Tests: `_test_level_caps`, `_test_life_station`)
| Level | Passagierpads (max.) | Pflichtfahrgäste (max.) | Anmerkung |
|---|---|---|---|
| 1–3 | 3–4 | 3 | Einstieg |
| 4–22 (Sektor 1–2) | **4** | 6 | Sektor 2: bewegliche Tore |
| 23–33 (Sektor 3) | **5** | 6 | |
| 34–44 (Sektor 4) | **6** | 7 | |
| 45–66 (Sektor 5–6) | **7** | 7 (ab 56: 8) | |
| 67–88 (Sektor 7–8) | **8** | 8 (ab 78: 9) | |
| 89–99 (Sektor 9) | **9** | 9 | Finale |
Mehr als **9 Passagierpads** sind nicht geplant (Pads sind Ziffern 1–9; das Tankpad „F“ und die Lebens-Station „L“ zählen nicht mit). **Lebens-Station** (`L`, kleine Plattform, alle 5 Level: 5, 10, 15, 20 … 95): Landen mit ≥ ¢1000 kauft nach 1,2 s ein Leben, höchstens 5.

## Geplante Hindernisse und Neuerungen je Sektor (ursprüngliche Planung; gebaut sind alle 99 Level, Details siehe Sektortabelle unten)
| Sektor | Neue Hindernisse / Mechaniken | Passagierpads | Weitere Neuerungen (schrittweise) |
|---|---|---|---|
| 1 Sternenhafen (1–11) | Dornen, Engstellen, Schächte, Tanken | 3–4 | Zusatzfahrgäste ab 5 |
| 2 Neon-Schluchten (12–22) | **bewegliche Tore** (Wandschleusen, Falltüren) | 4 | Lebens-Station alle 5 Level |
| 3 Schrottgürtel (23–33) | driftende Trümmer (Schaden bei Berührung), **bewegliche Plattformen** (Pads auf Schienen/Pendel) | **5** (ab 23) | Zufallsereignis „Meteoritenschauer“, Fahrgasttyp **zerbrechlich** (Schaden an Bord = Auftrag verloren) |
| 4 Magnetfeld (34–44) | **anziehende/abstoßende Feldzonen** (zeitweise schaltend), magnetische Träger | **6** (ab 34) | **zweite Tankstation**, Reparaturplattform, Fahrgasttyp **VIP** (höherer Preis, kurze Geduld) |
| 5 Solarschmiede (45–55) | **Hitzezonen** (Schaden je Sekunde), **Plasmastrahlen im Takt**, Sonnenwind | **7** (ab 45) | Fahrgasttyp **Gruppe** (2–3 Personen, mehr Platz nötig), Tank-Sonderangebote |
| 6 Gezeitenorbit (56–66) | **wechselnde Schwerkraft** (Zonen/Takt, auch Umkehr), **Strömungen** (Windfelder) | 7 | Fahrgasttyp **Notfall** (knappes Zeitlimit, hoher Preis), Zufallsereignis „Funkstörung“ |
| 7 Transitknoten (67–77) | **Verkehr** (Fremdfahrzeuge auf festen Routen), Mehrfach-Schleusen, Weichen/Förderbänder | **8** (ab 67) | Zufallsereignis „Preissturz/-anstieg“ an der Tankstelle |
| 8 Schattenring (78–88) | **Sichtbehinderung** (Nebel, Dunkelzonen), Radar-/Sensoranzeige, Suchscheinwerfer-Drohnen | 8 | alle Fahrgasttypen gemischt |
| 9 Singularitätsrand (89–99) | **alle Systeme** kombiniert plus Gravitationsbrunnen (Sog wächst), Finale in Level 99 | **9** (ab 89) | Tagesherausforderung (ganz am Ende, außerhalb der 99 Level) |

## Schwierigkeitsmetrik (`src/core/level_metrics.gd`, Test erzwingt: steigender Trend von Level 1 bis 99, einzelne Level bis 14 Punkte unter dem bisherigen Höchstwert)
Score = 40·Enge + 25·Streckenlänge + 15·Aufträge + 10·Landefenster + 10·Gefahren + 5·Mechaniken (Enge und Landefenster 0..1; Streckenlänge bis 2, Aufträge bis 1,5, Gefahren bis 3, Mechaniken bis 12 – nach oben offen, damit die Rangfolge bis Level 99 nicht an eine Obergrenze stößt; „Mechaniken“ = im Level-JSON unter `mechanics` deklarierte Neuerungen wie `spikes`; kleineres Landefenster = schwerer). Enge = engster Flugkorridor der Bot-Route (Sicherheitsrand in px, kleiner = schwerer). Bericht: `godot --headless -s tools/level_report.gd`.

| Sektor | Level | Schwerpunkt | Status |
|---|---|---|---|
| 1 Sternenhafen | 01–11 | Schub, Trägheit, Landung, Tanken, Engstellen, Dornen, Meisterprüfung | 01–11 gebaut |
| 2 Neon-Schluchten | 12–22 | Schächte, Engstellen, **bewegliche Tore** (Schleusen, Falltüren) | 12–22 gebaut |
| 3 Schrottgürtel | 23–33 | **Trümmer**, **fahrende Landeplattformen**, **Meteoritenschauer** (mit Warnung), **Schieber**, **zerbrechliche Fahrgäste**; fünf Passagierpads | 23–33 gebaut |
| 4 Magnetfeld | 34–44 | **Magnetzonen** (anziehend/abstoßend, teils pulsierend), sechs Passagierpads, sieben Aufträge | 34–44 gebaut |
| 5 Solarschmiede | 45–55 | **Hitzezonen** (teils pulsierend), **Plasmastrahlen** (Takt, Warnlinie), sieben Passagierpads | 45–55 gebaut |
| 6 Gezeitenorbit | 56–66 | **Strömungen** (teils böig), **Schwerkraftzonen**; acht Aufträge | 56–66 gebaut |
| 7 Transitknoten | 67–77 | **Verkehr** (Fahrzeuge auf Lichtbahnen, Gegenverkehr), Kombination mit Strömungen und Magneten | gebaut (67–77) |
| 8 Schattenring | 78–88 | **Dunkelheit** (nur Taxi, Plattformen, Tor und leuchtende Gefahren sind beleuchtet; Radar entfällt) | gebaut (78–88) |
| 9 Singularitätsrand | 89–99 | alle Systeme gleichzeitig (Verkehr, Wind, Magnete, Hitze, Strahlen, Meteoriten, Dunkelheit), neun Aufträge | gebaut (89–99) |

## Einzelzeilen
Spalte „Einzelabnahme“: Eine förmliche Abnahme je Level gibt es nicht, „–“ heißt nur, dass keine einzeln festgehalten ist. Gespielt und zurückgemeldet wird laufend; die Rückmeldungen und ihre Umsetzung stehen in `DESIGN.md`.

| ID | Name | Aufträge (Fahrgast von→nach) | Padbreiten (Tiles) | Score | Korridor | Strecke | kleinstes Landefenster | Bot ab 35 % Sprit | Einzelabnahme |
|---|---|---|---|---|---|---|---|---|---|
| S1-01 | Erster Flug | Mika 2→3, Odo 1→Ausgang | 1: 8, 2: 8, 3: 7 | 27.0 | 36 px | 1169 px | 66 px | bestanden (38 s, Tank 67 %) | – |
| S1-02 | Tankstopp | Mika 3→2, Odo 1→3, Lena 2→Ausgang | 1: 7, 2: 5, 3: 6 | 48.9 | 28 px | 2164 px | 34 px | bestanden (63 s, Tank 48 %) | – |
| S1-03 | Der Schornstein | Ines 2→3 (Schacht), Jonas 1→2, Lena 3→Ausgang | 1: 6, 2: 5, 3: 5 | 59.7 | 20 px | 2496 px | 34 px | bestanden (66 s, Tank 47 %) | – |
| S1-04 | Terrassen (Zick-Zack, hängender Zapfen) | Mika 3→2, Odo 4→3, Ines 1→4, Jonas 2→3, Lena 4→Ausgang | 1: 7, 2–4: 5 | 72.1 | 16 px | 3187 px | 34 px | bestanden (86 s, Tank 29 %) | – |
| S1-05 | Doppelschacht (zwei 5-Tiles-Schächte) | Mika 3→2, Odo 4→3, Lena 2→4, Jonas 1→2, Ines 3→Ausgang | 1: 6, 2/3: 5, 4: 6 | 72.5 | 20 px | 3742 px | 34 px | bestanden (93 s, Tank 25 %) | – |
| S1-06 | Tankwart (Tanken wird Pflicht) | Lena 3→2, Mika 4→3, Odo 2→4, Jonas 1→2, Ines 3→Ausgang | 1: 7, 2: 6, 3: 7, 4: 6 | 73.8 | 16 px | 3763 px | 50 px | bestanden (100 s, Tank 18 %) | – |
| S1-07 | Rundkurs (Ringweg um Mittelblock) | Lena 3→2, Odo 4→1, Mika 2→3, Jonas 1→4, Ines 3→Ausgang | 1: 7, 2: 7, 3/4: 5 | 82.4 | 16 px | 4618 px | 34 px | bestanden (101 s, Tank 20 %) | – |
| S1-08 | Dornenpfad (**erste Dornen**: 65 Hülle je Berührung) | Ines 3→2, Odo 4→3, Lena 2→4, Jonas 1→3, Mika 2→Ausgang | 1: 7, 2: 6, 3: 5, 4: 7 | 89.6 | 12 px | 3445 px | 34 px | bestanden (99 s, Tank 20 %) | – |
| S1-09 | Nadelspitzen (Säulen über Dornenfeld) | Odo 3→2, Lena 4→3, Mika 2→4, Jonas 1→2, Ines 4→1, Mika 3→Ausgang | 1: 6, 2–4: 5 | 90.2 | 16 px | 3754 px | 34 px | bestanden (101 s, Tank 17 %) | – |
| S1-10 | Tanknot (Tankturm hoch oben) | Lena 3→2, Odo 4→3, Mika 2→4, Jonas 1→3, Ines 4→1, Mika 2→Ausgang | 1: 7, 2–4: 5 | 91.6 | 20 px | 4390 px | 34 px | bestanden (142 s, Tank 55 %) | – |
| S1-11 | **Meisterprüfung** (Bunker, 2-Tiles-Tunnel, Dornen, Tankturm) | Lena 3→2, Odo 4→3, Mika 2→4, Jonas 1→3, Ines 4→2, Mika 3→Ausgang | 1: 6, 2–4: 5 | 97.4 | 8 px | 4374 px | 34 px | bestanden (118 s, Tank 67 %) | – |
| S2-01 | Schluchteingang (spikes) | Mika 3→2, Odo 4→3, Lena 2→4, Jonas 1→3, Ines 4→2, Ben 3→Ausgang | 100.3 | 12 px | 5294 px | 34 px | bestanden (142 s, Tank 48 %); mit der strengen Tankregel (Runde 60) nicht verlangt, geprüft mit Regelstand 2 | – |
| S2-02 | Neonallee (spikes) | Mika 3→4, Odo 2→3, Lena 4→2, Jonas 1→3, Ines 2→4, Ben 1→Ausgang | 109.2 | 16 px | 6131 px | 34 px | bestanden (184 s, Tank 47 %) | – |
| S2-03 | Erste Schleuse (doors, spikes) | Mika 3→1, Odo 2→4, Lena 1→3, Jonas 4→2, Ines 3→4, Ben 3→Ausgang | 101.6 | 20 px | 3627 px | 34 px | bestanden (161 s, Tank 35 %) | – |
| S2-04 | Zwillingsschleuse (doors, spikes, chicane) + Lebens-Station | Mika 3→2, Odo 4→3, Lena 2→4, Jonas 1→2, Ines 3→1, Ben 2→Ausgang | 102.6 | 20 px | 3689 px | 34 px | bestanden (162 s, Tank 68 %) | – |
| S2-05 | Rushhour (doors, spikes) | Mika 3→2, Odo 4→3, Lena 2→4, Jonas 1→3, Ines 4→2, Ben 1→Ausgang | 103.6 | 20 px | 4811 px | 34 px | bestanden (212 s, Tank 46 %) | – |
| S2-06 | Neonfinale (doors, spikes) | Mika 3→2, Odo 4→3, Lena 2→4, Jonas 1→3, Ines 4→2, Ben 1→Ausgang | 112.3 | 8 px | 5687 px | 34 px | bestanden (202 s, Tank 68 %) | – |
| S2-07 | Fallgitter (doors, spikes) | Mika 2→4, Odo 3→1, Lena 4→3, Jonas 1→2, Ines 3→4, Ben 1→Ausgang | 104.0 | 8 px | 3973 px | 34 px | bestanden (172 s, Tank 47 %) | – |
| S2-08 | Neonlabyrinth (doors, spikes, **Neon-Strahlen**) | Mika 3→2, Odo 4→3, Lena 2→4, Jonas 1→2, Ines 3→1, Ben 2→Ausgang | 104.7 | 16 px | 5723 px | 34 px | bestanden (194 s, Tank 33 %) | – |
| S2-09 | Schleusenkammer (doors) + Lebens-Station | Mika 3→2, Odo 4→3, Lena 1→4, Jonas 2→3, Ines 4→1, Ben 3→Ausgang | 110.7 | 8 px | 6525 px | 34 px | bestanden (185 s, Tank 68 %) | – |
| S2-10 | Doppelschleuse (doors; Pad 2 auf dem Vorsprung links oben) | Mika 3→2, Odo 4→3, Lena 2→4, Jonas 1→2, Ines 4→1, Ben 4→Ausgang | 116.5 | 4 px | 6816 px | 34 px | bestanden (240 s, Tank 52 %) | – |
| S2-11 | Glasfassade (**Sweep-Glasschleusen**, spikes) | Mika 3→2, Odo 4→3, Lena 2→4, Jonas 1→3, Ines 4→2, Ben 1→Ausgang | 113.2 | 12 px | 5980 px | 34 px | bestanden (211 s, Tank 45 %) | – |
| S3-01 (Level 23) | Schrottplatz (chicane, spikes, debris) | Mika 3→5, Odo 1→3, Lena 1→4, Jonas 2→5, Ines 2→5, Ben 4→Ausgang | 118.5 | 8 px | 3902 px | 34 px | bestanden (244 s, Tank 53 %) | – |
| S3-02 (Level 24) | Kranbahn (chicane, spikes, debris) | Mika 2→1, Odo 5→1, Lena 4→3, Jonas 2→1, Ines 3→1, Ben 5→Ausgang | 119.8 | 20 px | 5679 px | 34 px | bestanden (160 s, Tank 33 %) | – |
| S3-03 (Level 25) | Fließband (chicane, spikes, debris, moving_pads, life_station) + Lebens-Station | Mika 2→3, Odo 1→2, Lena 1→5, Jonas 1→4, Ines 1→4, Ben 5→Ausgang | 116.8 | 20 px | 3514 px | 34 px | bestanden (114 s, Tank 27 %) | – |
| S3-04 (Level 26) | Trümmerfeld (chicane, spikes, debris) | Mika 3→1, Odo 5→3, Lena 1→3, Jonas 1→3, Ines 2→5, Ben 4→Ausgang | 117.3 | 12 px | 4175 px | 34 px | bestanden (130 s, Tank 57 %); mit der strengen Tankregel (Runde 60) nicht verlangt, geprüft mit Regelstand 2 | – |
| S3-05 (Level 27) | Notfallflug (chicane, spikes, debris, medical) + Krankentransport | Mika 4→2, Odo 4→Krankenhaus, Lena 5→4, Jonas 5→Krankenhaus, Ines 1→3, Ben 1→Ausgang | 118.5 | 16 px | 3662 px | 34 px | bestanden (134 s, Tank 53 %) | – |
| S3-06 (Level 28) | Doppelfähre (chicane, spikes, debris, moving_pads) | Mika 5→4, Odo 1→3, Lena 1→4, Jonas 2→4, Ines 2→5, Ben 2→Ausgang | 123.7 | 16 px | 4010 px | 18 px | bestanden (121 s, Tank 30 %) | – |
| S3-07 (Level 29) | Meteorregen (chicane, spikes, debris, moving_pads, meteors) | Mika 3→2, Odo 4→2, Lena 5→1, Jonas 4→3, Ines 2→3, Ben 5→Ausgang | 125.8 | 8 px | 3776 px | 18 px | bestanden (224 s, Tank 53 %); mit der strengen Tankregel (Runde 60) nicht verlangt, geprüft mit Regelstand 2 | – |
| S3-08 (Level 30) | Altmetall (chicane, spikes, debris, meteors, life_station) + Lebens-Station | Mika 4→2, Odo 1→4, Lena 2→1, Jonas 4→5, Ines 1→3, Ben 4→Ausgang | 126.8 | 16 px | 3945 px | 18 px | bestanden (146 s, Tank 49 %) | – |
| S3-09 (Level 31) | Lazarettgürtel (chicane, spikes, debris, moving_pads, medical) + Krankentransport | Mika 3→2, Odo 4→Krankenhaus, Lena 5→1, Jonas 2→Krankenhaus, Ines 1→5, Ben 3→Ausgang | 127.3 | 16 px | 4303 px | 18 px | bestanden (190 s, Tank 56 %) | – |
| S3-10 (Level 32) | Schrottpresse (chicane, spikes, debris, moving_pads, meteors, medical) + Krankentransport | Mika 4→3, Odo 5→Krankenhaus, Lena 2→5, Jonas 2→Krankenhaus, Ines 4→1, Ben 4→Ausgang | 128.6 | 12 px | 2295 px | 18 px | bestanden (146 s, Tank 25 %) | – |
| S3-11 (Level 33) | Gürtelwächter (chicane, spikes, debris, moving_pads, meteors, sliders) | Mika 5→2, Odo 3→2, Lena 5→2, Jonas 5→1, Ines 3→4, Ben 1→Ausgang | 144.9 | 12 px | 4295 px | 18 px | bestanden (184 s, Tank 59 %) | – |
| S4-01 (Level 34) | Erste Spule (chicane, spikes, debris, magnets, attract_fields) | Mika 6→1, Odo 2→5, Lena 3→1, Jonas 4→1, Ines 5→1, Ben 5→1, Nora 2→Ausgang | 134.9 | 8 px | 5280 px | 34 px | bestanden (158 s, Tank 40 %) | – |
| S4-02 (Level 35) | Abstoßung (chicane, spikes, debris, magnets, repel_fields, life_station) + Lebens-Station | Mika 6→4, Odo 1→3, Lena 1→6, Jonas 2→1, Ines 5→1, Ben 2→6, Nora 5→Ausgang | 138.4 | 16 px | 5389 px | 34 px | bestanden (164 s, Tank 31 %) | – |
| S4-03 (Level 36) | Zwillingspole (chicane, spikes, debris, magnets, repel_fields, attract_fields) | Mika 4→1, Odo 5→6, Lena 4→2, Jonas 6→4, Ines 5→2, Ben 1→3, Nora 6→Ausgang | 139.0 | 12 px | 4274 px | 34 px | bestanden (149 s, Tank 49 %) | – |
| S4-04 (Level 37) | Pulsschlag (chicane, spikes, debris, magnets, pulsing_fields, attract_fields, medical) + Krankentransport | Mika 4→3, Odo 6→Krankenhaus, Lena 5→3, Jonas 4→Krankenhaus, Ines 1→2, Ben 6→1, Nora 3→Ausgang | 141.5 | 12 px | 5453 px | 34 px | bestanden (216 s, Tank 52 %) | – |
| S4-05 (Level 38) | Magnetschacht (chicane, spikes, debris, magnets, pulsing_fields, repel_fields, attract_fields) | Mika 3→2, Odo 1→2, Lena 3→2, Jonas 6→2, Ines 5→1, Ben 4→2, Nora 5→Ausgang | 141.9 | 16 px | 4167 px | 18 px | bestanden (144 s, Tank 24 %) | – |
| S4-06 (Level 39) | Feldlinien (chicane, spikes, debris, moving_pads, magnets, pulsing_fields, repel_fields, attract_fields) | Mika 3→5, Odo 6→3, Lena 2→6, Jonas 5→4, Ines 2→3, Ben 5→6, Nora 1→Ausgang | 143.1 | 24 px | 4865 px | 18 px | bestanden (175 s, Tank 23 %) | – |
| S4-07 (Level 40) | Polwechsel (chicane, debris, moving_pads, magnets, pulsing_fields, repel_fields, attract_fields, life_station) + Lebens-Station | Mika 4→3, Odo 6→3, Lena 4→6, Jonas 5→3, Ines 5→1, Ben 4→2, Nora 6→Ausgang | 144.3 | 8 px | 4894 px | 18 px | bestanden (157 s, Tank 39 %) | – |
| S4-08 (Level 41) | Dynamo (chicane, spikes, debris, moving_pads, magnets, pulsing_fields, repel_fields, attract_fields) | Mika 6→4, Odo 5→1, Lena 2→4, Jonas 3→1, Ines 6→3, Ben 5→6, Nora 5→Ausgang | 146.8 | 16 px | 5143 px | 18 px | bestanden (196 s, Tank 47 %); mit der strengen Tankregel (Runde 60) nicht verlangt, geprüft mit Regelstand 2 | – |
| S4-09 (Level 42) | Rettungsfeld (chicane, spikes, debris, moving_pads, magnets, pulsing_fields, repel_fields, attract_fields, medical) + Krankentransport | Mika 4→6, Odo 3→Krankenhaus, Lena 5→3, Jonas 6→4, Ines 2→6, Ben 4→Krankenhaus, Nora 5→Ausgang | 151.1 | 12 px | 4876 px | 18 px | bestanden (184 s, Tank 62 %); mit der strengen Tankregel (Runde 60) nicht verlangt, geprüft mit Regelstand 2 | – |
| S4-10 (Level 43) | Magnetträger (chicane, spikes, debris, moving_pads, magnets, pulsing_fields, repel_fields, attract_fields) | Mika 3→5, Odo 6→3, Lena 5→6, Jonas 1→2, Ines 5→1, Ben 4→2, Nora 3→Ausgang | 151.2 | 8 px | 4181 px | 18 px | bestanden (165 s, Tank 29 %) | – |
| S4-11 (Level 44) | Magnetmeister (chicane, spikes, debris, moving_pads, magnets, pulsing_fields, repel_fields, attract_fields) | Mika 3→1, Odo 3→5, Lena 1→5, Jonas 3→4, Ines 6→5, Ben 1→3, Nora 2→Ausgang | 149.3 | 12 px | 3716 px | 18 px | bestanden (132 s, Tank 33 %) | – |
| S5-01 (Level 45) | Glutschacht (chicane, spikes, debris, heat) | Mika 6→7, Odo 5→3, Lena 6→7, Jonas 1→2, Ines 1→2, Ben 4→2, Nora 1→Ausgang | 152.7 | 8 px | 6072 px | 18 px | bestanden (177 s, Tank 67 %) | – |
| S5-02 (Level 46) | Plasmastrahl (chicane, spikes, debris, heat, beams, magnets, attract_fields) | Mika 4→6, Odo 3→1, Lena 2→7, Jonas 2→4, Ines 2→6, Ben 5→3, Nora 6→Ausgang | 153.1 | 12 px | 4527 px | 18 px | bestanden (173 s, Tank 31 %) | – |
| S5-03 (Level 47) | Hitzewelle (chicane, spikes, debris, heat, pulsing_heat, beams, magnets, attract_fields) | Mika 4→1, Odo 3→4, Lena 6→2, Jonas 5→6, Ines 3→7, Ben 2→3, Nora 1→Ausgang | 158.9 | 8 px | 4689 px | 18 px | bestanden (173 s, Tank 61 %); mit der strengen Tankregel (Runde 60) nicht verlangt, geprüft mit Regelstand 2 | – |
| S5-04 (Level 48) | Taktgeber (chicane, spikes, debris, heat, pulsing_heat, beams, life_station) + Lebens-Station | Mika 4→2, Odo 7→5, Lena 7→4, Jonas 3→6, Ines 3→1, Ben 7→2, Nora 6→Ausgang | 159.9 | 8 px | 7369 px | 18 px | bestanden (210 s, Tank 47 %) | – |
| S5-05 (Level 49) | Hochofen (chicane, spikes, debris, heat, pulsing_heat, magnets, attract_fields, beams) | Mika 7→6, Odo 4→5, Lena 6→3, Jonas 2→5, Ines 2→5, Ben 1→2, Nora 6→Ausgang | 161.6 | 8 px | 5003 px | 18 px | bestanden (158 s, Tank 30 %) | – |
| S5-06 (Level 50) | Sonnenschmiede (chicane, spikes, debris, heat, pulsing_heat, beams, magnets, attract_fields) | Mika 3→2, Odo 7→6, Lena 1→6, Jonas 4→6, Ines 5→2, Ben 6→2, Nora 3→Ausgang | 164.5 | 12 px | 4938 px | 18 px | bestanden (191 s, Tank 65 %) | – |
| S5-07 (Level 51) | Schmiedemeister (chicane, spikes, debris, heat, pulsing_heat, beams, magnets, attract_fields, life_station) + Lebens-Station | Mika 4→2, Odo 4→5, Lena 6→5, Jonas 1→7, Ines 3→1, Ben 4→3, Nora 5→Ausgang | 166.1 | 8 px | 4096 px | 18 px | bestanden (177 s, Tank 47 %) | – |
| S5-08 (Level 52) | Gussform (chicane, spikes, debris, meteors, heat, pulsing_heat, beams, magnets, attract_fields) | Mika 3→5, Odo 6→4, Lena 6→5, Jonas 7→1, Ines 7→4, Ben 2→4, Nora 1→Ausgang | 176.0 | 12 px | 5708 px | 18 px | bestanden (206 s, Tank 32 %) | – |
| S5-09 (Level 53) | Plasmaschmiede (chicane, spikes, debris, meteors, heat, pulsing_heat, beams, magnets, attract_fields, medical) + Krankentransport | Mika 4→1, Odo 4→5, Lena 1→Krankenhaus, Jonas 5→1, Ines 6→2, Ben 7→2, Nora 3→Ausgang | 169.3 | 8 px | 4745 px | 18 px | bestanden (205 s, Tank 62 %) | – |
| S5-10 (Level 54) | Sonnenwende (chicane, spikes, debris, meteors, heat, pulsing_heat, beams, magnets, repel_fields, attract_fields, life_station) + Lebens-Station | Mika 6→4, Odo 6→3, Lena 6→2, Jonas 1→4, Ines 2→4, Ben 1→5, Nora 7→Ausgang | 174.9 | 12 px | 4917 px | 18 px | bestanden (227 s, Tank 40 %) | – |
| S5-11 (Level 55) | Sonnenzenit (chicane, spikes, debris, meteors, heat, pulsing_heat, beams, magnets, pulsing_fields, repel_fields, attract_fields, life_station) + Lebens-Station | Mika 2→5, Odo 6→1, Lena 7→3, Jonas 1→3, Ines 1→6, Ben 4→6, Nora 3→Ausgang | 175.7 | 8 px | 4674 px | 18 px | bestanden (247 s, Tank 50 %) | – |
| S6-01 (Level 56) | Gezeitenstrom (chicane, spikes, currents) | Mika 3→5, Odo 1→7, Lena 6→2, Jonas 3→4, Ines 3→5, Ben 1→2, Nora 6→3, Tarek 2→Ausgang | 194.4 | 8 px | 8288 px | 18 px | bestanden (219 s, Tank 19 %) | – |
| S6-02 (Level 57) | Schwerelos (chicane, spikes, currents, gravity_zones) | Mika 4→2, Odo 6→1, Lena 2→4, Jonas 6→1, Ines 3→4, Ben 3→5, Nora 6→7, Tarek 4→Ausgang | 184.6 | 16 px | 8295 px | 18 px | bestanden (210 s, Tank 27 %) | – |
| S6-03 (Level 58) | Springflut (chicane, spikes, currents, gusts, gravity_zones, medical) + Krankentransport | Mika 5→7, Odo 3→Krankenhaus, Lena 4→5, Jonas 1→5, Ines 3→1, Ben 2→6, Nora 2→7, Tarek 6→Ausgang | 185.5 | 12 px | 6262 px | 18 px | bestanden (170 s, Tank 20 %) | – |
| S6-04 (Level 59) | Ebbe (chicane, spikes, debris, currents, gusts, gravity_zones) | Mika 7→4, Odo 6→1, Lena 4→7, Jonas 2→4, Ines 5→2, Ben 4→3, Nora 2→1, Tarek 2→Ausgang | 186.1 | 8 px | 4513 px | 18 px | bestanden (337 s, Tank 61 %) | – |
| S6-05 (Level 60) | Mondbahn (chicane, spikes, debris, currents, gusts, gravity_zones, magnets, attract_fields) | Mika 6→4, Odo 6→3, Lena 2→1, Jonas 6→7, Ines 1→4, Ben 5→7, Nora 5→6, Tarek 5→Ausgang | 188.4 | 12 px | 5064 px | 18 px | bestanden (162 s, Tank 42 %) | – |
| S6-06 (Level 61) | Strudel (chicane, spikes, debris, currents, gusts, magnets, attract_fields, medical) + Krankentransport | Mika 2→4, Odo 6→1, Lena 4→3, Jonas 1→Krankenhaus, Ines 2→7, Ben 5→1, Nora 4→2, Tarek 4→Ausgang | 191.2 | 12 px | 4063 px | 18 px | bestanden (167 s, Tank 46 %) | – |
| S6-07 (Level 62) | Sturmflut (chicane, debris, currents, gusts, gravity_zones, magnets, attract_fields, life_station) + Lebens-Station | Mika 4→1, Odo 2→1, Lena 5→1, Jonas 5→6, Ines 1→7, Ben 5→3, Nora 2→4, Tarek 3→Ausgang | 192.9 | 8 px | 7452 px | 18 px | bestanden (204 s, Tank 51 %) | – |
| S6-08 (Level 63) | Gezeitenmeister (chicane, spikes, debris, currents, gusts, gravity_zones, magnets, attract_fields) | Mika 3→7, Odo 3→4, Lena 2→5, Jonas 4→7, Ines 6→5, Ben 4→6, Nora 5→7, Tarek 1→Ausgang | 199.9 | 8 px | 4901 px | 18 px | bestanden (230 s, Tank 25 %) | – |
| S6-09 (Level 64) | Orbitalsog (chicane, spikes, debris, currents, gusts, gravity_zones, magnets, attract_fields, life_station) + Lebens-Station | Mika 4→1, Odo 2→7, Lena 1→4, Jonas 1→7, Ines 1→7, Ben 5→3, Nora 4→6, Tarek 3→Ausgang | 200.5 | 8 px | 5124 px | 18 px | bestanden (154 s, Tank 66 %) | – |
| S6-10 (Level 65) | Mahlstrom (chicane, spikes, debris, currents, gusts, gravity_zones, magnets, attract_fields, medical) + Krankentransport | Mika 2→4, Odo 2→Krankenhaus, Lena 7→6, Jonas 2→5, Ines 7→3, Ben 5→6, Nora 1→3, Tarek 4→Ausgang | 204.1 | 8 px | 5346 px | 18 px | bestanden (183 s, Tank 66 %) | – |
| S6-11 (Level 66) | Wasserwelt (chicane, spikes, debris, currents, gusts, gravity_zones, magnets, attract_fields) | Mika 6→4, Odo 2→1, Lena 5→6, Jonas 4→6, Ines 1→7, Ben 3→4, Nora 7→4, Tarek 1→Ausgang | 205.5 | 8 px | 5268 px | 18 px | bestanden (213 s, Tank 44 %) | – |
| S7-01 (Level 67) | Zubringer (chicane, spikes, traffic) | Mika 6→1, Odo 3→2, Lena 1→2, Jonas 6→2, Ines 4→7, Ben 6→7, Nora 4→5, Tarek 6→Ausgang | 214.3 | 8 px | 5445 px | 18 px | bestanden (186 s, Tank 58 %) | – |
| S7-02 (Level 68) | Knotenpunkt (chicane, spikes, traffic, currents, gusts, magnets, attract_fields, medical) + Krankentransport | Mika 3→5, Odo 2→Krankenhaus, Lena 3→1, Jonas 6→7, Ines 3→2, Ben 4→7, Nora 6→1, Tarek 6→Ausgang | 210.9 | 24 px | 4843 px | 18 px | bestanden (193 s, Tank 58 %) | – |
| S7-03 (Level 69) | Schichtwechsel (chicane, spikes, traffic, currents, gusts, magnets, attract_fields, life_station) + Lebens-Station | Mika 7→6, Odo 5→3, Lena 6→5, Jonas 2→5, Ines 6→4, Ben 1→3, Nora 5→6, Tarek 3→Ausgang | 214.6 | 24 px | 5084 px | 18 px | bestanden (204 s, Tank 47 %) | – |
| S7-04 (Level 70) | Leitstelle (chicane, spikes, traffic, currents, gusts, magnets, attract_fields) | Mika 6→4, Odo 7→3, Lena 5→4, Jonas 5→7, Ines 2→3, Ben 2→6, Nora 1→7, Tarek 4→Ausgang | 213.3 | 16 px | 4303 px | 18 px | bestanden (135 s, Tank 29 %) | – |
| S7-05 (Level 71) | Güterbahn (chicane, spikes, traffic, magnets, attract_fields, medical) + Krankentransport | Mika 4→1, Odo 3→1, Lena 4→2, Jonas 6→Krankenhaus, Ines 5→4, Ben 1→4, Nora 7→1, Tarek 2→Ausgang | 219.2 | 12 px | 5668 px | 18 px | bestanden (201 s, Tank 56 %) | – |
| S7-06 (Level 72) | Expresslinie (chicane, spikes, traffic, currents, gusts, magnets, attract_fields) | Mika 5→1, Odo 3→7, Lena 2→1, Jonas 5→1, Ines 4→7, Ben 5→6, Nora 2→6, Tarek 3→Ausgang | 221.6 | 16 px | 4899 px | 18 px | bestanden (185 s, Tank 53 %) | – |
| S7-07 (Level 73) | Transitring (chicane, spikes, traffic, currents, gusts, magnets, attract_fields, medical) + Krankentransport | Mika 5→2, Odo 5→7, Lena 5→Krankenhaus, Jonas 3→4, Ines 7→4, Ben 5→7, Nora 6→2, Tarek 1→Ausgang | 218.5 | 16 px | 4462 px | 18 px | bestanden (178 s, Tank 61 %) | – |
| S7-08 (Level 74) | Zentralknoten (chicane, spikes, traffic, currents, gusts, magnets, attract_fields) | Mika 7→2, Odo 1→2, Lena 3→4, Jonas 5→4, Ines 1→2, Ben 7→6, Nora 7→3, Tarek 2→Ausgang | 222.7 | 16 px | 5193 px | 18 px | bestanden (197 s, Tank 42 %) | – |
| S7-09 (Level 75) | Knotenpunkt (chicane, spikes, traffic, currents, gusts, magnets, attract_fields, medical) + Krankentransport | Mika 5→6, Odo 3→6, Lena 4→1, Jonas 6→Krankenhaus, Ines 7→1, Ben 6→4, Nora 5→2, Tarek 1→Ausgang | 220.8 | 24 px | 7422 px | 18 px | bestanden (254 s, Tank 62 %) | – |
| S7-10 (Level 76) | Umsteigebahnhof (chicane, spikes, traffic, currents, gusts, magnets, attract_fields) | Mika 2→3, Odo 5→7, Lena 4→1, Jonas 5→6, Ines 4→2, Ben 1→7, Nora 4→5, Tarek 6→Ausgang | 222.8 | 12 px | 5332 px | 18 px | bestanden (195 s, Tank 42 %) | – |
| S7-11 (Level 77) | Knotenpunkt (chicane, spikes, traffic, currents, gusts, magnets, attract_fields, medical) + Krankentransport | Mika 4→6, Odo 2→3, Lena 1→6, Jonas 3→Krankenhaus, Ines 2→4, Ben 6→5, Nora 2→7, Tarek 3→Ausgang | 213.7 | 20 px | 4308 px | 18 px | bestanden (182 s, Tank 57 %) | – |
| S8-01 (Level 78) | Dämmerung (chicane, spikes, darkness) | Mika 3→6, Odo 3→4, Lena 2→4, Jonas 7→5, Ines 6→3, Ben 4→7, Nora 4→2, Tarek 1→Ausgang | 235.1 | 12 px | 4938 px | 18 px | bestanden (149 s, Tank 21 %) | – |
| S8-02 (Level 79) | Nachtschicht (chicane, spikes, darkness) | Mika 2→7, Odo 2→4, Lena 3→5, Jonas 7→6, Ines 1→7, Ben 6→2, Nora 5→1, Tarek 7→Ausgang | 236.7 | 12 px | 5122 px | 18 px | bestanden (156 s, Tank 20 %) | – |
| S8-03 (Level 80) | Peilung (chicane, spikes, traffic, medical, darkness) + Krankentransport | Mika 4→1, Odo 3→1, Lena 4→2, Jonas 6→Krankenhaus, Ines 5→4, Ben 1→4, Nora 7→1, Tarek 2→Ausgang | 240.6 | 12 px | 4206 px | 18 px | bestanden (195 s, Tank 60 %) | – |
| S8-04 (Level 81) | Funkschatten (chicane, spikes, traffic, magnets, attract_fields, darkness) | Mika 3→1, Odo 4→3, Lena 6→5, Jonas 1→4, Ines 7→3, Ben 7→4, Nora 1→7, Tarek 2→Ausgang | 238.6 | 20 px | 4626 px | 18 px | bestanden (158 s, Tank 37 %) | – |
| S8-05 (Level 82) | Sensorfeld (chicane, traffic, currents, gusts, magnets, attract_fields, life_station, darkness) + Lebens-Station | Mika 6→3, Odo 7→3, Lena 5→6, Jonas 2→6, Ines 4→1, Ben 4→7, Nora 4→6, Tarek 4→Ausgang | 240.9 | 20 px | 4964 px | 18 px | bestanden (195 s, Tank 53 %) | – |
| S8-06 (Level 83) | Lichtlos (chicane, traffic, beams, currents, gusts, magnets, attract_fields, medical, darkness) + Krankentransport | Mika 3→6, Odo 5→4, Lena 1→Krankenhaus, Jonas 3→7, Ines 2→5, Ben 1→6, Nora 1→2, Tarek 1→Ausgang | 243.8 | 24 px | 4709 px | 18 px | bestanden (181 s, Tank 67 %) | – |
| S8-07 (Level 84) | Schattenring (chicane, spikes, traffic, beams, currents, gusts, magnets, attract_fields, darkness) | Mika 7→5, Odo 7→3, Lena 4→2, Jonas 6→2, Ines 3→2, Ben 6→2, Nora 5→1, Tarek 5→Ausgang | 248.7 | 24 px | 3619 px | 18 px | bestanden (213 s, Tank 54 %) | – |
| S8-08 (Level 85) | Finsternis (chicane, spikes, traffic, beams, currents, gusts, magnets, attract_fields, darkness) | Mika 3→6, Odo 1→7, Lena 6→7, Jonas 2→6, Ines 7→6, Ben 3→4, Nora 6→5, Tarek 7→Ausgang | 256.8 | 24 px | 4519 px | 18 px | bestanden (238 s, Tank 58 %) | – |
| S8-09 (Level 86) | Echolot (chicane, spikes, traffic, beams, currents, gusts, magnets, attract_fields, darkness) | Mika 7→1, Odo 5→2, Lena 6→2, Jonas 3→7, Ines 4→7, Ben 3→5, Nora 6→4, Tarek 5→Ausgang | 257.8 | 24 px | 5289 px | 18 px | bestanden (193 s, Tank 48 %) | – |
| S8-10 (Level 87) | Schattenring (chicane, spikes, traffic, beams, currents, gusts, magnets, attract_fields, darkness) | Mika 6→5, Odo 4→7, Lena 1→6, Jonas 7→3, Ines 4→1, Ben 7→4, Nora 2→6, Tarek 2→Ausgang | 258.0 | 24 px | 4984 px | 18 px | bestanden (198 s, Tank 29 %) | – |
| S8-11 (Level 88) | Echolot (chicane, spikes, traffic, beams, currents, gusts, magnets, attract_fields, darkness) | Mika 4→7, Odo 4→2, Lena 7→6, Jonas 5→7, Ines 1→4, Ben 2→5, Nora 2→3, Tarek 7→Ausgang | 250.8 | 20 px | 4429 px | 18 px | bestanden (246 s, Tank 26 %) | – |
| S9-01 (Level 89) | Ereignishorizont (chicane, spikes, traffic, magnets, attract_fields, darkness) | Mika 4→6, Odo 4→2, Lena 5→4, Jonas 5→1, Ines 6→2, Ben 6→5, Nora 4→3, Tarek 2→7, Mika 6→Ausgang | 260.0 | 24 px | 4365 px | 18 px | bestanden (196 s, Tank 53 %) | – |
| S9-02 (Level 90) | Akkretionsscheibe (chicane, traffic, currents, gusts, magnets, attract_fields, life_station, darkness) + Lebens-Station | Mika 6→1, Odo 5→3, Lena 6→3, Jonas 6→5, Ines 4→2, Ben 7→3, Nora 5→2, Tarek 3→7, Mika 4→Ausgang | 271.2 | 20 px | 4447 px | 18 px | bestanden (249 s, Tank 60 %) | – |
| S9-03 (Level 91) | Gravitationslinse (chicane, debris, traffic, beams, currents, gusts, magnets, attract_fields, medical, darkness) + Krankentransport | Mika 6→4, Odo 3→4, Lena 3→1, Jonas 3→Krankenhaus, Ines 7→5, Ben 6→3, Nora 2→5, Tarek 6→2, Mika 6→Ausgang | 294.7 | 20 px | 6122 px | 18 px | bestanden (225 s, Tank 23 %) | – |
| S9-04 (Level 92) | Zeitdehnung (chicane, debris, traffic, heat, beams, currents, gusts, magnets, attract_fields, darkness) | Mika 7→2, Odo 5→3, Lena 2→3, Jonas 5→1, Ines 4→5, Ben 7→4, Nora 7→6, Tarek 2→3, Mika 7→Ausgang | 296.3 | 20 px | 5858 px | 18 px | bestanden (260 s, Tank 36 %) | – |
| S9-05 (Level 93) | Singularität (chicane, debris, traffic, heat, beams, currents, gusts, magnets, pulsing_fields, repel_fields, attract_fields, darkness) | Mika 2→3, Odo 1→6, Lena 4→2, Jonas 5→7, Ines 3→6, Ben 7→4, Nora 6→2, Tarek 6→1, Mika 2→Ausgang | 294.6 | 24 px | 4377 px | 18 px | bestanden (213 s, Tank 36 %) | – |
| S9-06 (Level 94) | Photonenring (chicane, spikes, debris, traffic, beams, currents, gusts, magnets, attract_fields, medical, darkness) + Krankentransport | Mika 4→5, Odo 6→Krankenhaus, Lena 4→5, Jonas 3→2, Ines 1→2, Ben 1→7, Nora 1→2, Tarek 1→6, Mika 1→Ausgang | 298.1 | 20 px | 5412 px | 18 px | bestanden (215 s, Tank 25 %); mit der strengen Tankregel (Runde 60) nicht verlangt, geprüft mit Regelstand 2 | – |
| S9-07 (Level 95) | Gezeitenkraft (chicane, spikes, debris, traffic, heat, beams, currents, gusts, magnets, attract_fields, darkness) | Mika 5→7, Odo 6→7, Lena 1→7, Jonas 1→2, Ines 1→4, Ben 5→2, Nora 1→4, Tarek 3→6, Mika 1→Ausgang | 302.9 | 20 px | 5658 px | 18 px | bestanden (200 s, Tank 24 %) | – |
| S9-08 (Level 96) | Gravitationswelle (chicane, spikes, debris, traffic, heat, beams, currents, gusts, magnets, attract_fields, darkness) | Mika 4→3, Odo 7→6, Lena 3→7, Jonas 6→2, Ines 4→5, Ben 6→3, Nora 1→6, Tarek 2→5, Mika 1→Ausgang | 304.9 | 16 px | 5153 px | 18 px | bestanden (260 s, Tank 38 %) | – |
| S9-09 (Level 97) | Quantenschaum (chicane, debris, traffic, heat, beams, currents, gusts, magnets, attract_fields, darkness) | Mika 7→4, Odo 1→5, Lena 4→6, Jonas 1→4, Ines 3→1, Ben 5→6, Nora 2→5, Tarek 6→7, Mika 2→Ausgang | 318.4 | 8 px | 5412 px | 18 px | bestanden (212 s, Tank 30 %) | – |
| S9-10 (Level 98) | Wurmloch (chicane, debris, traffic, heat, beams, currents, gusts, magnets, attract_fields, darkness) | Mika 4→7, Odo 5→4, Lena 7→3, Jonas 2→5, Ines 7→1, Ben 5→6, Nora 5→6, Tarek 2→6, Mika 1→Ausgang | 316.0 | 8 px | 5081 px | 18 px | bestanden (244 s, Tank 55 %) | – |
| S9-11 (Level 99) | Letzter Halt (attract_fields, beams, chicane, currents, darkness, debris, gravity, gusts, heat, magnets, meteors, pulsing_fields, pulsing_heat, repel_fields, sliders, spikes, traffic) | Mika 2→1, Odo 2→7, Lena 1→4, Jonas 3→6, Ines 4→1, Ben 3→4, Nora 5→4, Tarek 1→4, Mika 6→Ausgang | 351.0 | 16 px | 7540 px | 18 px | bestanden (368 s, Tank 65 %) | – |

## Fahrgasttypen VIP und Notfall (Runde 61)
Pflichtfahrgäste mit Typ (`"kind"` am Auftrag, nur dieses Feld ergänzt; Karten, Routen, Richtzeiten und Zeitziele unverändert): ein VIP je Level ab Sektor 4, ein Notfall in jedem zweiten Level ab Sektor 6 (gerade Nummern; Level 93 statt 92, weil der Autopilot in 92 keinen Auftrag misst), nie der Ausgangs-Auftrag, kein Krankentransport. Auswahl und Messwerte: `tools/levelmarks/` (`measure_jobs.gd`, `mark_levels.py`, `marks.json`). Notfall-Frist = 1,3 × Richtzeit vom Erscheinen bis zum Absetzen; Reserve = Frist − Zeit des Autopiloten ab Mindest-Sprit. „statisch“: Der Autopilot kommt in diesem Handlevel nicht bis zu diesem Auftrag; VIP = kürzester Anflug, Notfall = längste Richtzeit (aus der Handzeit).

| Level | VIP | Notfall |
|---|---|---|
| 34 | Auftrag 3 | – |
| 35 | Auftrag 4 | – |
| 36 | Auftrag 4 | – |
| 37 | Auftrag 6 | – |
| 38 | Auftrag 2 | – |
| 39 | Auftrag 5 | – |
| 40 | Auftrag 4 | – |
| 41 | Auftrag 3 | – |
| 42 | Auftrag 5 | – |
| 43 | Auftrag 4 | – |
| 44 | Auftrag 4 | – |
| 45 | Auftrag 3 | – |
| 46 | Auftrag 6 | – |
| 47 | Auftrag 6 | – |
| 48 | Auftrag 3 | – |
| 49 | Auftrag 2 | – |
| 50 | Auftrag 4 | – |
| 51 | Auftrag 3 | – |
| 52 | Auftrag 2 | – |
| 53 | Auftrag 4 | – |
| 54 | Auftrag 3 | – |
| 55 | Auftrag 1 | – |
| 56 | Auftrag 3 | Auftrag 6: Frist 35.1 s (Richtzeit 27 s), Autopilot 15.5 s, Reserve 19.6 s |
| 57 | Auftrag 4 | – |
| 58 | Auftrag 4 | Auftrag 5: Frist 27.3 s (Richtzeit 21 s), Autopilot 22.1 s, Reserve 5.2 s |
| 59 | Auftrag 2 | – |
| 60 | Auftrag 4 | Auftrag 5: Frist 24.7 s (Richtzeit 19 s), Autopilot 20.3 s, Reserve 4.4 s |
| 61 | Auftrag 5 | – |
| 62 | Auftrag 7 | Auftrag 1: Frist 32.5 s (Richtzeit 25 s), Autopilot 26.6 s, Reserve 5.9 s |
| 63 | Auftrag 6 | – |
| 64 | Auftrag 7 | Auftrag 5: Frist 23.4 s (Richtzeit 18 s), Autopilot 14.0 s, Reserve 9.4 s |
| 65 | Auftrag 4 | – |
| 66 | Auftrag 6 | Auftrag 4: Frist 40.3 s (Richtzeit 31 s), Autopilot 13.4 s, Reserve 26.9 s |
| 67 | Auftrag 7 | – |
| 68 | Auftrag 3 | Auftrag 5: Frist 45.5 s (Richtzeit 35 s), Autopilot 23.4 s, Reserve 22.1 s |
| 69 | Auftrag 6 | – |
| 70 | Auftrag 3 | Auftrag 6: Frist 28.6 s (Richtzeit 22 s), Autopilot 12.0 s, Reserve 16.6 s |
| 71 | Auftrag 7 | – |
| 72 | Auftrag 1 | Auftrag 6: Frist 13.0 s (Richtzeit 10 s), Autopilot 6.3 s, Reserve 6.7 s |
| 73 | Auftrag 4 | – |
| 74 | Auftrag 3 | Auftrag 7: Frist 18.2 s (Richtzeit 14 s), Autopilot 11.1 s, Reserve 7.1 s |
| 75 | Auftrag 7 | – |
| 76 | Auftrag 6 | Auftrag 1: Frist 36.4 s (Richtzeit 28 s), Autopilot 27.7 s, Reserve 8.7 s |
| 77 | Auftrag 6 | – |
| 78 | Auftrag 2 | Auftrag 1: Frist 19.5 s (Richtzeit 15 s), Autopilot 18.4 s, Reserve 1.1 s |
| 79 | Auftrag 1 | – |
| 80 | Auftrag 6 | Auftrag 5: Frist 29.9 s (Richtzeit 23 s), Autopilot 13.0 s, Reserve 16.9 s |
| 81 | Auftrag 3 | – |
| 82 | Auftrag 4 | Auftrag 2: Frist 41.6 s (Richtzeit 32 s), Autopilot 27.5 s, Reserve 14.1 s |
| 83 | Auftrag 1 | – |
| 84 | Auftrag 7 | Auftrag 6: Frist 29.9 s (Richtzeit 23 s), Autopilot 18.1 s, Reserve 11.8 s |
| 85 | Auftrag 6 | – |
| 86 | Auftrag 2 | Auftrag 3: Frist 22.1 s (Richtzeit 17 s), Autopilot 8.4 s, Reserve 13.7 s |
| 87 | Auftrag 5 (statisch) | – |
| 88 | Auftrag 7 | Auftrag 6: Frist 20.8 s (Richtzeit 16 s), Autopilot 12.8 s, Reserve 8.0 s |
| 89 | Auftrag 4 (statisch) | – |
| 90 | Auftrag 6 (statisch) | Auftrag 2: Frist 31.2 s (Richtzeit 24 s), Autopilot nicht gemessen |
| 91 | Auftrag 1 | – |
| 92 | Auftrag 4 (statisch) | – |
| 93 | Auftrag 6 (statisch) | Auftrag 1: Frist 33.8 s (Richtzeit 26 s), Autopilot 16.5 s, Reserve 17.3 s |
| 94 | Auftrag 1 | Auftrag 4: Frist 42.9 s (Richtzeit 33 s), Autopilot 57.8 s, Reserve -14.9 s |
| 95 | Auftrag 1 | – |
| 96 | Auftrag 1 | – |
| 97 | Auftrag 7 | Auftrag 8: Frist 33.8 s (Richtzeit 26 s), Autopilot 9.7 s, Reserve 24.1 s |
| 98 | Auftrag 2 | Auftrag 1: Frist 29.9 s (Richtzeit 23 s), Autopilot 26.0 s, Reserve 3.9 s |
| 99 | Auftrag 4 (statisch) | – |
