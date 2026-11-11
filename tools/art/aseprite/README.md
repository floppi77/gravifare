# Taxi, Fahrgäste und Verkehr (Aseprite)

Diese Grafiken sind in Aseprite (über den Aseprite-MCP) gezeichnet und werden **nicht** von `tools/art/gen_art.py` erzeugt:

- `assets/art/taxi.png` (78×48 seit Runde 62, vorher 96×60). `gen_art.py` leitet daraus nur die Lackierungen `taxi_<name>.png` per Farbtausch ab.
- `assets/art/passengers.png` (240×504): 14 Figuren × 10 Frames à 24×36, **eine Figur je Fahrgaststimme**.
- `assets/art/vehicle_<farbe>.png` (96×60): Verkehrsfahrzeug „Pendlergleiter“ in Rot, Blau, Grün, Lila, Silber.
- `assets/art/shelters.png` (684×60): Haltestelle je Sektor, 72×60 im Abstand von 76 px (Sektor 1 links).
- `assets/art/life_icon.png` (32×20, HUD-Leben; Lackierungen `life_<name>.png` leitet `gen_art.taxi_skins()` ab), `stat_icons.png` (13 × 18 px), `ws_icons.png` (4 × 26 px: Düsen, Hülle, Fahrwerk, Scheinwerfer; das vierte Feld aus `gen_round2.py` → `ws_light_raw.png`, Kontur in Aseprite).

- `assets/art/driver.png` (680×56, 17 Bilder à 40×56) und `taxi_cockpit_empty.png` (96×60): Fahrer fürs Finale der Nachtschicht und die leere Kuppel. Ablauf: `python3 tools/art/gen_driver.py pre` (Grundflächen und Schattierung nach `build/aseprite-workspace/gf_driver/`), `aseprite -b --script tools/art/aseprite/build_driver.lua` (baut `driver.aseprite` mit Ebenen `body` und `outline`, Kontur in abgedunkelter Nachbarfarbe, Tags walk/stand/turn/front/wave/jump/land), `python3 tools/art/gen_driver.py export` (Blatt nach `assets/art/`), `… cockpit` (leere Kuppel aus `taxi.aseprite`). Farben und Formen wie der Fahrer in `taxi.aseprite`.

- `assets/art/movers.png` (120×36): Kachelblatt für Trümmer, Schieber und fahrende Plattformen (10 Spalten × 3 Zeilen à 12 px: Ecken, Kanten, zwei Füllungen). Ablauf: `python3 tools/art/gen_movers.py pre` (Ebenen `body`, `detail`, `outline` nach `build/aseprite-workspace/gf_movers/`), `aseprite -b --script tools/art/aseprite/build_movers.lua` (baut `movers.aseprite` und `movers_flat.png`), `python3 tools/art/gen_movers.py export` (nach `assets/art/`). Das Spiel setzt jede Hindernisgröße aus den Kacheln zusammen (`props_view._draw_mover_box`).

Eigene Arbeit, keine Fremdassets.

## Dateien

| Datei | Inhalt |
|---|---|
| `gen_parts.py` | Grundformen des Taxis (flache Materialflächen und Detail-Ebenen) nach `build/aseprite-workspace/gf_polish/` |
| `gen_figures.py` | Grundformen der 14 Figuren nach `build/aseprite-workspace/gf_polish/figures/`; die Tabelle `FIG` beschreibt jede Figur |
| `gen_vehicle.py` | Grundformen des Verkehrsfahrzeugs nach `build/aseprite-workspace/gf_polish/vehicle/` |
| `gen_round2.py` | Grundformen der Haltestellen (Wand flach, Details), Leben-Symbol, Statistik- und Werkstatt-Symbole nach `build/aseprite-workspace/gf_polish/round2/` |
| `shelters.aseprite`, `life_icon.aseprite`, `stat_icons.aseprite`, `ws_icons.aseprite` | Aseprite-Quellen dazu (Haltestellen mit Ebenen, ohne Kontur) |
| `finish.py` | Letzter Schritt: Fahrgastblatt (Kontur-Bereinigung, Zeilenreihenfolge) und die fünf Fahrzeugfarben nach `assets/art/` |
| `taxi.aseprite` | Taxi mit Ebenen `metal`, `fins`, `hull`, `glass`, `detail`, `driver` (schattiert, ohne Außenkontur) |
| `passengers_14.aseprite` | Alle 14 Figuren (240×504, Reihenfolge f0–f6, m0–m6) mit Ebenen `Layer 1` (schattiert) und `top`, ohne Außenkontur |
| `vehicle.aseprite` | Fahrzeug (rot) mit Ebenen `metal`, `hull`, `glass`, `detail`, ohne Außenkontur |

## Figur je Stimme

| Zeile | Stimme | Figur | Zeile | Stimme | Figur |
|---|---|---|---|---|---|
| 0 | f0 | jung, Kleid, Haarspange | 7 | f4 | Geschäftsfrau, Dutt, Aktentasche |
| 1 | m0 | Jacke, Koffer | 8 | f5 | ältere Dame, graue Locken, Handtasche |
| 2 | m2 | Schirmmütze, Kapuzenpulli | 9 | m1 | Schiebermütze, Weste, Schnurrbart, breit |
| 3 | f6 | Alien mit Fühlern (verträumt) | 10 | m3 | Vollbart, Karohemd, breit (Bass) |
| 4 | f1 | Bob, Blazer, Brille | 11 | m4 | dicke Brille, Fliege, schmal (nervös) |
| 5 | f2 | Pferdeschwanz, Kopfhörer, Sommersprossen | 12 | m5 | Anzug, Krawatte (Nachrichtensprecher) |
| 6 | f3 | lange Haare, Sonnenbrille, Lederjacke | 13 | m6 | Glatze, Brille, Schnurrbart, Stock |

Die Zeilenfolge steht in `PassengerActor.LOOK_VOICE`. Zeilen 0–3 sind die vier ursprünglichen Figuren, damit ein im Spielstand gespeicherter Fahrgast seine Figur behält.

## Taxi und Verkehr in 78×48 (Runde 62)

1. `python3 tools/art/aseprite/gen_taxi78.py .` (Grundformen nach `build/aseprite-workspace/gf_polish/taxi78/`, Maße von Hand gesetzt) bzw. `gen_vehicle.py .` (jetzt 78×48).
2. In Aseprite wie unten: Ebenen `metal`, `fins`, `hull`, `glass`, `detail`, `driver` stempeln und mit denselben Rampen und Lichtwinkeln schattieren (Glanzpunkt Rumpf und Glas je 3 px), flach speichern, Kontur `outline_smart` single `#0c0f24`, exportieren nach `assets/art/taxi.png`; Quelle mit Ebenen `taxi.aseprite`. Fahrzeug analog (`vehicle.aseprite`, Export als `vehicle/v2_red.png`, dann `finish.py vehicles`).
3. Lackierungen: `python3 -c "import sys; sys.path.insert(0,'tools/art'); import gen_art; gen_art.taxi_skins()"`, leere Kuppel: `python3 tools/art/gen_driver.py cockpit`, Aufkleber in Taxigröße: `gen_art.stickers(small_only=True)`.

## Ablauf (Aseprite-MCP)

1. `python3 tools/art/aseprite/gen_parts.py .`, `gen_figures.py .` bzw. `gen_vehicle.py .`
2. **Taxi:** Ebenen der Reihe nach aus `taxi_metal/fins/hull/glass/detail/driver.png` stempeln, dann schattieren:
   - `hull`: `shade_region_by_light`, Rampe `#9c4a1a #c8681c #e8901f #f7ae2a #ffcb3d #ffe066`, Licht 100°, light_z 0.55, bulge 1, ambient 0.25. Danach `specular_highlight` mit derselben Rampe plus `#fff6c8`, size 4.
   - `metal`: Rampe `#22254a #3d4166 #5a5f8a #7a80a8 #9aa1cc #b8bfe6`, Licht 110°, light_z 0.35, ambient 0.15, rim 0.25.
   - `glass`: Rampe `#1d5f78 #2a8fa8 #4fc3cf #8ae8ea #c8fffd`, Licht 120°, bulge 1.1, ambient 0.4, rim 0.35. Danach Glanzpunkt mit `#ffffff`, size 3.
   - Chromkragen der Kuppel von Hand auf `driver` (Zeilen 27/28, x 33–62).
3. **Fahrgäste:** `fig_base.png` stempeln. Je Oberteil- und Hautfarbe aus `FIG` einmal `shade_region_by_light` mit `base_color` (Toleranz 3), Licht 100°; Kleidung light_z 0.5, bulge 0.8, ambient 0.3; Haut light_z 0.6, bulge 0.9, ambient 0.4. Rampe: Schatten = Farbe × (0,62/0,62/0,74), Halbschatten × (0,80/0,80/0,88), Licht = Farbe + 22 % Richtung Weiß; Haut × (0,80/0,70/0,70), × (0,91/0,84/0,83), + 30 %. Dann `fig_top.png` als Ebene `top`. Flach als `figures/fig_pre.png` exportieren.
4. **Fahrzeug:** Ebenen `metal`, `hull`, `glass` stempeln und schattieren (`hull`: Rampe `#5a1a32 #8a2438 #b8333c #e04a4a #f2785e`, Licht 100°, light_z 0.55, ambient 0.25, Glanzpunkt `#ffd0b8`; `metal` wie beim Taxi; `glass`: `#123a52 #1d5f78 #2a8fa8 #4fc3cf #8ae8ea`, Licht 120°, bulge 0.8), dann `detail`.
5. Flach speichern (`save_sprite_as`, flatten), Außenkontur `outline_smart` mode `single` mit `#0c0f24`, als PNG exportieren (Taxi nach `assets/art/taxi.png`, Fahrgäste als `figures/passengers_14.png`, Fahrzeug als `vehicle/v2_red.png`).
6. **Haltestellen:** `shelters_base.png` stempeln, je Wandfarbe aus `SH` in `gen_round2.py` einmal `shade_region_by_light` (Toleranz 3, Licht 110°, bulge 0,5, Rampe wie bei den Fahrgästen), `shelters_top.png` als Ebene `top`, flach speichern, Kontur `#0c0f24`, nach `assets/art/shelters.png`. Symbole: Rohbild stempeln, Kontur, exportieren.
7. `python3 tools/art/aseprite/finish.py figures` und `finish.py vehicles`; für das Taxi die Lackierungen neu ableiten:
   `python3 -c "import sys; sys.path.insert(0,'tools/art'); import gen_art; gen_art.taxi_skins()"`

## Zu beachten

- Taxi und Verkehr sind seit Runde 62 in Zielgröße gezeichnet (78×48 px = 26×16 Einheiten, 1:1 bei 1080p). Fahrgäste werden bei 1080p weiter auf ≈ 0,85× verkleinert (nächster Nachbar). 1440p und 4K vergrößern nur.
- Code zeichnet auf feste Stellen der Taxi-Textur (78×48): Düsenöffnung unten y 41–44, Seitenflammen an x 0/77, Lampe über der Düse um (38, 40), Aufkleber über x 8–28 / y 14–34 (`sticker_*_s.png`, 20 px), die Spiegelung im Boden nutzt die Zeilen 22–47 (`Tuning.TAXI_REFLECT_SRC`). Umriss und diese Stellen beibehalten.
- Beim Fahrzeug (78×48) zeichnet der Code die Düsenflamme am Heck (Textur x 0, y ≈ 26) und den Scheinwerfer an der Nase (x ≈ 74, y ≈ 29). Die Trefferfläche ist 21×10 Einheiten, die Grafik 26×16; der Autopilot plant mit 26×12 Sicherheitsabstand.
- Die Taxi-Lackierungen tauschen alle Pixel mit Farbton 0,04–0,18, Sättigung > 0,4 und Helligkeit > 0,35. Neue Orange-/Gelbtöne außerhalb des Rumpfs werden mit umgefärbt (gewollt bei der Fahrermütze); die Düsenglut liegt bewusst darunter.
- Laufbilder (Frames 4–9) blicken nach rechts und werden für links gespiegelt, deshalb Licht von oben statt von der Seite.
- Ein Blatt mit allen Figuren: Die Aseprite-Kontur läuft an Framegrenzen in den Nachbarframe; `finish.py figures` entfernt genau diese Pixel.
