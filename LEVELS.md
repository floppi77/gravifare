# LEVELS – Leveldesign-Matrix

Verbindliche Regeln: Pad-Nummern sind fortlaufend 1..N; jedes Pad hat Platz für einen Wartebereich-Unterstand (2 Tiles Luft über einem Padende); das Ausgangstor liegt mittig oben und öffnet erst, wenn der **Ausgangs-Fahrgast** (letzter Auftrag, `to: "exit"`) an Bord ist; jeder Auftrag hat einen eigenen Fahrgast; der erste Fahrgast wartet nicht auf dem Startpad, und jeder Fahrgast beginnt an einem anderen Pad, als der vorherige endete; unter dem Torblock bleiben mindestens 96 px Durchflug. Das Tankpad (`F`) braucht eine 2 Tiles hohe Zapfsäule (`P`) am Padende und ein freies Landefenster ≥ 28 px; Preisbereich je Level optional (`fuel`). Jedes Level muss der Bot **ab dem Mindest-Sprit (35 %)** lösen. **Pads sind unterschiedlich groß** (5 bis 8 Tiles; je kleiner, desto schwieriger), aber jedes Passagierpad hat ein **freies Landefenster** neben dem Wartebereich, mindestens 34 px in Level 1–3, **sinkend bis 20 px in Level 99** (`Tuning.min_land_window`, Test) – späte Level dürfen deutlich kleinere Plattformen haben. Die Grenze gilt je Pad: **Größere Pads im selben Level sind erlaubt, unterschiedlich große Pads innerhalb eines Levels dürfen gemischt auftreten.**

Status: **11 von 99 Leveln vorhanden** (Sektor 1 komplett, S1-01 bis S1-11). Erzeuger: `tools/make_level_s1_01.py`, `tools/make_s1_02_03.py`, `tools/make_s1_04_11.py` (Pars dort als Tabelle). Übersichtsbilder: `docs/levels/`.

## Schwierigkeitsmetrik (`src/core/level_metrics.gd`, Test erzwingt: nicht fallend von Level 1 bis 99)
Score = 40·Enge + 25·Streckenlänge + 15·Aufträge + 10·Landefenster + 10·Gefahren + 5·Mechaniken (Enge und Landefenster 0..1; Streckenlänge bis 2, Aufträge bis 1,5, Gefahren bis 3, Mechaniken bis 12 – nach oben offen, damit die Rangfolge bis Level 99 nicht an eine Obergrenze stößt; „Mechaniken“ = im Level-JSON unter `mechanics` deklarierte Neuerungen wie `spikes`; kleineres Landefenster = schwerer). Enge = engster Flugkorridor der Bot-Route (Sicherheitsrand in px, kleiner = schwerer). Bericht: `godot --headless -s tools/level_report.gd`.

| Sektor | Level | Schwerpunkt | Status |
|---|---|---|---|
| 1 Sternenhafen | 01–11 | Schub, Trägheit, Landung, Tanken, Engstellen, Dornen, Meisterprüfung | 01–11 gebaut |
| 2 Neon-Schluchten | 12–22 | Schächte, Engstellen, bewegliche Tore | offen |
| 3 Schrottgürtel | 23–33 | Trümmer, bewegliche Plattformen | offen |
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
