# Taxi und Fahrgäste (Aseprite)

`assets/art/taxi.png` (96×60) und `assets/art/passengers.png` (240×144, 4 Figuren × 10 Frames à 24×36) sind seit November 2026 in Aseprite überarbeitet und werden **nicht mehr** von `tools/art/gen_art.py` erzeugt. Der Generator leitet nur noch die Lackierungen (`taxi_<name>.png`) per Farbtausch aus `taxi.png` ab.

Eigene Arbeit, keine Fremdassets.

## Dateien

| Datei | Inhalt |
|---|---|
| `gen_parts.py` | Erzeugt die Grundformen als flache Materialflächen und Detail-Ebenen nach `build/aseprite-workspace/gf_polish/` |
| `taxi.aseprite` | Taxi mit Ebenen `metal`, `fins`, `hull`, `glass`, `detail`, `driver` (schattiert, ohne Außenkontur) |
| `passenger_<0-3>.aseprite` | Je Figur ein Streifen 240×36 mit Ebenen `Layer 1` (schattiert) und `top` (Haare, Gesicht, Accessoires), ohne Außenkontur |

## Ablauf (Aseprite-MCP)

1. `python3 tools/art/aseprite/gen_parts.py .`
2. **Taxi:** Ebenen der Reihe nach aus `taxi_metal/fins/hull/glass/detail/driver.png` stempeln, dann schattieren:
   - `hull`: `shade_region_by_light`, Rampe `#9c4a1a #c8681c #e8901f #f7ae2a #ffcb3d #ffe066`, Licht 100°, light_z 0.55, bulge 1, ambient 0.25. Danach `specular_highlight` mit derselben Rampe plus `#fff6c8`, size 4.
   - `metal`: Rampe `#22254a #3d4166 #5a5f8a #7a80a8 #9aa1cc #b8bfe6`, Licht 110°, light_z 0.35, ambient 0.15, rim 0.25.
   - `glass`: Rampe `#1d5f78 #2a8fa8 #4fc3cf #8ae8ea #c8fffd`, Licht 120°, bulge 1.1, ambient 0.4, rim 0.35. Danach Glanzpunkt mit `#ffffff`, size 3.
   - Chromkragen der Kuppel von Hand auf `driver` (Zeilen 27/28, x 33–62).
3. **Fahrgäste:** je Figur `pass<i>_base.png` stempeln, Kleidung und Haut getrennt per `base_color` (Toleranz 6) schattieren, Licht von oben (100°), dann `pass<i>_top.png` als Ebene `top`.
4. Flach speichern (`save_sprite_as`, flatten), Außenkontur `outline_smart` mode `single` mit `#0c0f24`, als PNG exportieren.
5. Nach `assets/art/` kopieren, Lackierungen neu ableiten:
   `python3 -c "import sys; sys.path.insert(0,'tools/art'); import gen_art; gen_art.taxi_skins()"`

## Zu beachten

- Im Spiel wird bei 1080p verkleinert (Taxi 0,8×, Fahrgäste ≈ 0,85×, nächster Nachbar). Einzelne Pixelzeilen fallen dabei weg; feine 1-px-Schrift zerfällt. 1440p und 4K vergrößern nur.
- Code zeichnet auf feste Stellen der Taxi-Textur: Hauptdüse unten bei y ≈ 55, Seitenflammen an x 0/95, Fahrwerk und Lampe um (45, 51), Aufkleber über x 9–33 / y 17–41, die Spiegelung im Boden nutzt nur die Zeilen 27–60. Umriss und diese Stellen beibehalten.
- Die Lackierungen tauschen alle Pixel mit Farbton 0,04–0,18, Sättigung > 0,4 und Helligkeit > 0,35. Neue Orange-/Gelbtöne außerhalb des Rumpfs werden mit umgefärbt (gewollt bei der Fahrermütze); die Düsenglut liegt bewusst darunter.
- Laufbilder (Frames 4–9) blicken nach rechts und werden für links gespiegelt, deshalb Licht von oben statt von der Seite.
