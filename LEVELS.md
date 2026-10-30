# LEVELS – Leveldesign-Matrix

Verbindliche Regeln: Pad-Nummern sind fortlaufend 1..N; jedes Pad hat Platz für einen Wartebereich-Unterstand (2 Tiles Luft über einem Padende); das Ausgangstor liegt mittig oben und öffnet erst, wenn der **Ausgangs-Fahrgast** (letzter Auftrag, `to: "exit"`) an Bord ist; jeder Auftrag hat einen eigenen Fahrgast; der erste Fahrgast wartet nicht auf dem Startpad, und jeder Fahrgast beginnt an einem anderen Pad, als der vorherige endete; unter dem Torblock bleiben mindestens 96 px Durchflug. Jedes Level muss der Bot **ab dem Mindest-Sprit (35 %)** lösen. **Pads sind unterschiedlich groß** (5 bis 8 Tiles; je kleiner, desto schwieriger), aber jedes Passagierpad hat ein **freies Landefenster** neben dem Wartebereich, mindestens 34 px in Level 1–3, **sinkend bis 20 px in Level 99** (`Tuning.min_land_window`, Test) – späte Level dürfen deutlich kleinere Plattformen haben. Die Grenze gilt je Pad: **Größere Pads im selben Level sind erlaubt, unterschiedlich große Pads innerhalb eines Levels dürfen gemischt auftreten.**

Status: **3 von 99 Leveln vorhanden** (S1-01 bis S1-03). Übersichtsbilder: `docs/levels/`.

## Schwierigkeitsmetrik (`src/core/level_metrics.gd`, Test erzwingt: nicht fallend von Level 1 bis 99)
Score = 40·Enge + 25·Streckenlänge + 15·Aufträge + 10·Landefenster + 10·Gefahren (je 0..1 normiert; kleineres Landefenster = schwerer). Enge = engster Flugkorridor der Bot-Route (Sicherheitsrand in px, kleiner = schwerer). Bericht: `godot --headless -s tools/level_report.gd`.

| Sektor | Level | Schwerpunkt | Status |
|---|---|---|---|
| 1 Sternenhafen | 01–11 | Schub, Trägheit, Landung, Tanken, später engere Wege | 01–03 gebaut |
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
| S1-03 | Der Schornstein | Ines 2→3 (Schacht), Jonas 1→2, Lena 3→Ausgang | 1: 6, 2: 5, 3: 5 | 58.6 | 20 px | 2496 px | 34 px | bestanden (66 s, Tank 47 %) | **offen** |
