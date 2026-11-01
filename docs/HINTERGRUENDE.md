# Hintergrundbilder

**Stand:** Jeder Sektor hat ein ganzes Hintergrundbild `assets/art/bg_sN.png` (1920 × 1080, PNG, deckend). Die Bilder wurden mit „ChatGPT Astra 6.0“ KI-generiert (Pixel-Art-Look; Angabe des Entwicklers, 2026-11-01; Lizenz/Nutzungsrechte siehe THIRD_PARTY_LICENSES.md, Prüfung vor Veröffentlichung offen) und werden im Spiel auf 1,06-fach vergrößert, leicht mit der Kamera verschoben (Parallax 5 %) und je Sektor abgedunkelt, damit Plattformen, Fahrgäste und Hindernisse lesbar bleiben.

| Sektor | Datei | Motiv (Quelldatei) | Abdunklung |
|---|---|---|---|
| 1 Sternenhafen | `bg_s1.png` | Orbitale Metropole (01) | 30 % |
| 2 Neon-Schluchten | `bg_s2.png` | Amethysttiefen (09) | 46 % |
| 3 Schrottgürtel | `bg_s3.png` | Vergessene Maschinenwelt (08) | 30 % |
| 4 Magnetfeld | `bg_s4.png` | Polarlichtmond (03) | 30 % |
| 5 Solarschmiede | `bg_s5.png` | Vulkanmond (06) | 22 % |
| 6 Gezeitenorbit | `bg_s6.png` | Versunkene Tiefseestadt (05) | 22 % |
| 7 Transitknoten | `bg_s7.png` | Goldene Wolkenstadt (07) | 58 % |
| 8 Schattenring | `bg_s8.png` | Leuchtender Urwald (04) | 30 % |
| 9 Singularitätsrand | `bg_s9.png` | Rand der Singularität (10) | 12 % |
| (Reserve) | `bg_menu.png` | Bernsteinwüste (02), noch nicht verwendet | – |

Die Zuordnung steht (Dateinamen) in dieser Tabelle, die Abdunklung in `DIM` in `src/game/backdrop.gd`. Zum Tauschen einfach die Datei überschreiben und einmal `godot --headless --import` ausführen. Dev-Flag `--bg=N` zeigt den Hintergrund eines anderen Sektors.

Fehlt `bg_sN.png`, greift der alte Dreiebenen-Aufbau `bg_sN_far/mid/near.png` (nur Sektor 1 hat ihn noch; das Hauptmenü nutzt ihn).

Das Logo liegt als `assets/art/logo.png` (zugeschnitten, RGBA) und ersetzt im Hauptmenü die Textüberschrift.

## Hinweise für neue Bilder
- 16:9, 1920 × 1080 (oder 3840 × 2160), harte Pixelkanten, keine Weichzeichnung.
- Lesbarkeit geht vor: Plattformen/Fahrgäste werden in Cyan/Orange/Gelb/Rosa gezeichnet; sehr helle Bilder brauchen eine höhere Abdunklung.
- Oberer (16 px logisch) und unterer Rand (ca. 24 px logisch) sind HUD-Streifen.
