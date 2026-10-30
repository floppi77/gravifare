# LEVELS – Leveldesign-Matrix

Verbindliche Regeln: Pad-Nummern sind fortlaufend 1..N; jedes Pad hat Platz für einen Wartebereich-Unterstand (2 Tiles Luft über einem Padende); das Ausgangstor liegt mittig oben und öffnet erst, wenn der **Ausgangs-Fahrgast** (letzter Auftrag, `to: "exit"`) an Bord ist; jeder Auftrag hat einen eigenen Fahrgast; der erste Fahrgast wartet nicht auf dem Startpad, und jeder Fahrgast beginnt an einem anderen Pad, als der vorherige endete; unter dem Torblock bleiben mindestens 96 px Durchflug. Das Tankpad (`F`) braucht eine 2 Tiles hohe Zapfsäule (`P`) am Padende und ein freies Landefenster ≥ 28 px; Preisbereich je Level optional (`fuel`). Jedes Level muss der Bot **ab dem Mindest-Sprit (35 %)** lösen. **Pads sind unterschiedlich groß** (5 bis 8 Tiles; je kleiner, desto schwieriger), aber jedes Passagierpad hat ein **freies Landefenster** neben dem Wartebereich, mindestens 34 px in Level 1–3, **sinkend bis 20 px in Level 99** (`Tuning.min_land_window`, Test) – späte Level dürfen deutlich kleinere Plattformen haben. Die Grenze gilt je Pad: **Größere Pads im selben Level sind erlaubt, unterschiedlich große Pads innerhalb eines Levels dürfen gemischt auftreten.**

Status: **33 von 99 Leveln vorhanden** (Sektor 1–3 komplett, S1-01 bis S3-11). Erzeuger: `tools/make_level_s1_01.py`, `tools/make_s1_02_03.py`, `tools/make_s1_04_11.py` (Pars dort als Tabelle). Übersichtsbilder: `docs/levels/`.

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

## Geplante Hindernisse und Neuerungen je Sektor (Stand: Planung, nur Sektor 1–2 gebaut)
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

## Schwierigkeitsmetrik (`src/core/level_metrics.gd`, Test erzwingt: nicht fallend von Level 1 bis 99)
Score = 40·Enge + 25·Streckenlänge + 15·Aufträge + 10·Landefenster + 10·Gefahren + 5·Mechaniken (Enge und Landefenster 0..1; Streckenlänge bis 2, Aufträge bis 1,5, Gefahren bis 3, Mechaniken bis 12 – nach oben offen, damit die Rangfolge bis Level 99 nicht an eine Obergrenze stößt; „Mechaniken“ = im Level-JSON unter `mechanics` deklarierte Neuerungen wie `spikes`; kleineres Landefenster = schwerer). Enge = engster Flugkorridor der Bot-Route (Sicherheitsrand in px, kleiner = schwerer). Bericht: `godot --headless -s tools/level_report.gd`.

| Sektor | Level | Schwerpunkt | Status |
|---|---|---|---|
| 1 Sternenhafen | 01–11 | Schub, Trägheit, Landung, Tanken, Engstellen, Dornen, Meisterprüfung | 01–11 gebaut |
| 2 Neon-Schluchten | 12–22 | Schächte, Engstellen, **bewegliche Tore** (Schleusen, Falltüren) | 12–22 gebaut |
| 3 Schrottgürtel | 23–33 | **Trümmer** (bewegliche Brocken), **fahrende Landeplattformen** auf Schienen; fünf Passagierpads | 23–33 gebaut |
| 4 Magnetfeld | 34–44 | anziehende/abstoßende Zonen | offen |
| 5 Solarschmiede | 45–55 | Hitzezonen, Strahlen, Takt | offen |
| 6 Gezeitenorbit | 56–66 | wechselnde Schwerkraft, Strömungen | offen |
| 7 Transitknoten | 67–77 | Verkehr, Schleusen, Routen | offen |
| 8 Schattenring | 78–88 | Sicht, Radar, Sensoren | offen |
| 9 Singularitätsrand | 89–99 | alle Systeme, Finale in 99 | offen |

## Einzelzeilen
| ID | Name | Aufträge (Fahrgast von→nach) | Padbreiten (Tiles) | Score | Korridor | Strecke | kleinstes Landefenster | Bot ab 35 % Sprit | Spielerische Abnahme |
|---|---|---|---|---|---|---|---|---|---|
| S1-01 | Erster Flug | Mika 2→3, Odo 1→Ausgang | 1: 8, 2: 8, 3: 7 | 27.0 | 36 px | 1169 px | 66 px | bestanden (38 s, Tank 67 %) | **offen** |
| S1-02 | Tankstopp | Mika 3→2, Odo 1→3, Lena 2→Ausgang | 1: 7, 2: 5, 3: 6 | 48.9 | 28 px | 2164 px | 34 px | bestanden (63 s, Tank 48 %) | **offen** |
| S1-03 | Der Schornstein | Ines 2→3 (Schacht), Jonas 1→2, Lena 3→Ausgang | 1: 6, 2: 5, 3: 5 | 59.7 | 20 px | 2496 px | 34 px | bestanden (66 s, Tank 47 %) | **offen** |
| S1-04 | Terrassen (Zick-Zack, hängender Zapfen) | Mika 3→2, Odo 4→3, Ines 1→4, Jonas 2→3, Lena 4→Ausgang | 1: 7, 2–4: 5 | 72.1 | 16 px | 3187 px | 34 px | bestanden (86 s, Tank 29 %) | **offen** |
| S1-05 | Doppelschacht (zwei 5-Tiles-Schächte) | Mika 3→2, Odo 4→3, Lena 2→4, Jonas 1→2, Ines 3→Ausgang | 1: 6, 2/3: 5, 4: 6 | 72.5 | 20 px | 3742 px | 34 px | bestanden (93 s, Tank 25 %) | **offen** |
| S1-06 | Tankwart (Tanken wird Pflicht) | Lena 3→2, Mika 4→3, Odo 2→4, Jonas 1→2, Ines 3→Ausgang | 1: 7, 2: 6, 3: 7, 4: 6 | 73.8 | 16 px | 3763 px | 50 px | bestanden (100 s, Tank 18 %) | **offen** |
| S1-07 | Rundkurs (Ringweg um Mittelblock) | Lena 3→2, Odo 4→1, Mika 2→3, Jonas 1→4, Ines 3→Ausgang | 1: 7, 2: 7, 3/4: 5 | 82.4 | 16 px | 4618 px | 34 px | bestanden (101 s, Tank 20 %) | **offen** |
| S1-08 | Dornenpfad (**erste Dornen**: 30 Hülle je Berührung) | Ines 3→2, Odo 4→3, Lena 2→4, Jonas 1→3, Mika 2→Ausgang | 1: 7, 2: 6, 3: 5, 4: 7 | 89.6 | 12 px | 3445 px | 34 px | bestanden (99 s, Tank 20 %) | **offen** |
| S1-09 | Nadelspitzen (Säulen über Dornenfeld) | Odo 3→2, Lena 4→3, Mika 2→4, Jonas 1→2, Ines 4→1, Mika 3→Ausgang | 1: 6, 2–4: 5 | 90.2 | 16 px | 3754 px | 34 px | bestanden (101 s, Tank 17 %) | **offen** |
| S1-10 | Tanknot (Tankturm hoch oben) | Lena 3→2, Odo 4→3, Mika 2→4, Jonas 1→3, Ines 4→1, Mika 2→Ausgang | 1: 7, 2–4: 5 | 91.6 | 20 px | 4390 px | 34 px | bestanden (142 s, Tank 55 %) | **offen** |
| S1-11 | **Meisterprüfung** (Bunker, 2-Tiles-Tunnel, Dornen, Tankturm) | Lena 3→2, Odo 4→3, Mika 2→4, Jonas 1→3, Ines 4→2, Mika 3→Ausgang | 1: 6, 2–4: 5 | 97.4 | 8 px | 4374 px | 34 px | bestanden (118 s, Tank 67 %) | **offen** |
| S2-01 | Schluchteingang (spikes) | Mika 3→2, Odo 4→3, Lena 2→4, Jonas 1→3, Ines 4→2, Ben 3→Ausgang | 100.3 | 12 px | 5294 px | 34 px | bestanden (142 s, Tank 48 %) | **offen** |
| S2-02 | Neonallee (spikes) | Mika 3→4, Odo 2→3, Lena 4→2, Jonas 1→3, Ines 2→4, Ben 1→Ausgang | 101.0 | 24 px | 6005 px | 34 px | bestanden (189 s, Tank 47 %) | **offen** |
| S2-03 | Erste Schleuse (doors, spikes) | Mika 3→1, Odo 2→4, Lena 1→3, Jonas 4→2, Ines 3→4, Ben 3→Ausgang | 101.6 | 20 px | 3627 px | 34 px | bestanden (141 s, Tank 57 %) | **offen** |
| S2-04 | Zwillingsschleuse (doors, spikes, chicane) + Lebens-Station | Mika 3→2, Odo 4→3, Lena 2→4, Jonas 1→2, Ines 3→1, Ben 2→Ausgang | 102.6 | 20 px | 3689 px | 34 px | bestanden (185 s, Tank 68 %) | **offen** |
| S2-05 | Rushhour (doors, spikes) | Mika 3→2, Odo 4→3, Lena 2→4, Jonas 1→3, Ines 4→2, Ben 1→Ausgang | 103.6 | 20 px | 4811 px | 34 px | bestanden (195 s, Tank 26 %) | **offen** |
| S2-06 | Doppelschleuse (doors) | Mika 3→2, Odo 4→3, Lena 2→4, Jonas 1→2, Ines 4→1, Ben 4→Ausgang | 103.9 | 8 px | 5564 px | 34 px | bestanden (173 s, Tank 68 %) | **offen** |
| S2-07 | Fallgitter (doors, spikes) | Mika 2→4, Odo 3→1, Lena 4→3, Jonas 1→2, Ines 3→4, Ben 1→Ausgang | 105.1 | 16 px | 5767 px | 34 px | bestanden (179 s, Tank 30 %) | **offen** |
| S2-08 | Neonlabyrinth (doors, spikes) | Mika 3→2, Odo 4→3, Lena 2→4, Jonas 1→2, Ines 3→1, Ben 2→Ausgang | 105.1 | 8 px | 4122 px | 34 px | bestanden (201 s, Tank 24 %) | **offen** |
| S2-09 | Schleusenkammer (doors) + Lebens-Station | Mika 3→2, Odo 4→3, Lena 1→4, Jonas 2→3, Ines 4→1, Ben 3→Ausgang | 110.7 | 8 px | 6525 px | 34 px | bestanden (191 s, Tank 68 %) | **offen** |
| S2-10 | Neonfinale (doors, spikes) | Mika 3→2, Odo 4→3, Lena 2→4, Jonas 1→3, Ines 4→2, Ben 1→Ausgang | 112.3 | 8 px | 5687 px | 34 px | bestanden (238 s, Tank 48 %) | **offen** |
| S2-11 | Glasfassade (doors, spikes) | Mika 3→2, Odo 4→3, Lena 2→4, Jonas 1→3, Ines 4→2, Ben 1→Ausgang | 113.2 | 12 px | 5980 px | 34 px | bestanden (234 s, Tank 47 %) | **offen** |
| S3-01 | Schrottplatz (debris, chicane, spikes) | Mika 2→5, Odo 4→1, Lena 3→5, Jonas 4→3, Ines 2→1, Ben 5→Ausgang | 113.4 | 12 px | 3908 px | 34 px | bestanden (155 s, Tank 41 %) | **offen** |
| S3-02 | Kranbahn (debris, chicane, spikes) | Mika 3→4, Odo 1→5, Lena 4→2, Jonas 1→2, Ines 1→5, Ben 3→Ausgang | 114.3 | 12 px | 3897 px | 34 px | bestanden (193 s, Tank 32 %) | **offen** |
| S3-03 | Trümmerfeld (debris, chicane, spikes) + Lebens-Station | Mika 2→1, Odo 2→4, Lena 2→4, Jonas 3→2, Ines 1→3, Ben 5→Ausgang | 115.4 | 12 px | 4041 px | 34 px | bestanden (138 s, Tank 32 %) | **offen** |
| S3-04 | Fließband (debris, moving_pads, chicane, spikes) | Mika 3→2, Odo 4→5, Lena 1→2, Jonas 5→3, Ines 2→3, Ben 5→Ausgang | 116.4 | 12 px | 3702 px | 34 px | bestanden (127 s, Tank 41 %) | **offen** |
| S3-05 | Pendelhalle (debris, chicane, spikes) | Mika 4→3, Odo 1→5, Lena 2→1, Jonas 3→1, Ines 4→5, Ben 2→Ausgang | 116.7 | 12 px | 4437 px | 34 px | bestanden (158 s, Tank 37 %) | **offen** |
| S3-06 | Schrottlawine (debris, chicane, spikes) | Mika 3→1, Odo 4→1, Lena 5→4, Jonas 5→4, Ines 2→1, Ben 5→Ausgang | 116.7 | 12 px | 4443 px | 34 px | bestanden (161 s, Tank 33 %) | **offen** |
| S3-07 | Altmetall (debris, moving_pads, chicane, spikes) | Mika 3→4, Odo 5→2, Lena 3→1, Jonas 2→3, Ines 2→3, Ben 5→Ausgang | 117.7 | 12 px | 3524 px | 34 px | bestanden (156 s, Tank 39 %) | **offen** |
| S3-08 | Doppelfähre (debris, moving_pads, chicane, spikes) + Lebens-Station | Mika 2→5, Odo 3→1, Lena 2→3, Jonas 5→3, Ines 4→1, Ben 4→Ausgang | 118.5 | 12 px | 3918 px | 34 px | bestanden (169 s, Tank 24 %) | **offen** |
| S3-09 | Schrottpresse (debris, chicane, spikes) | Mika 4→2, Odo 5→1, Lena 2→1, Jonas 4→1, Ines 3→1, Ben 2→Ausgang | 119.3 | 12 px | 4515 px | 34 px | bestanden (207 s, Tank 60 %) | **offen** |
| S3-10 | Wrackgasse (debris, chicane, spikes) | Mika 5→3, Odo 4→2, Lena 3→1, Jonas 4→5, Ines 1→4, Ben 1→Ausgang | 119.3 | 12 px | 4729 px | 34 px | bestanden (153 s, Tank 39 %) | **offen** |
| S3-11 | Gürtelwächter (debris, moving_pads, chicane, spikes) | Mika 5→4, Odo 5→2, Lena 3→5, Jonas 2→1, Ines 5→3, Ben 2→Ausgang | 122.8 | 12 px | 4317 px | 34 px | bestanden (172 s, Tank 26 %) | **offen** |
