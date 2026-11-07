"""Erzeugt die Fels-Materialien der Sektoren 2–9 aus tiles_s1.png: gleiche Formen, eigene Farbwelt je Sektor (assets/art/tiles_sN.png).
Plattformen, Tankpad und Dornen (Index 4, 5, 6) bleiben unverändert: Funktionsfarben sind in allen Sektoren gleich.
Aufruf: python3 tools/art/gen_sector_tiles.py"""
import colorsys
from PIL import Image

KEEP = (5, 6)
PAD = 4
PAD_TOP = 15        # Oberkante des Pads (Pixel im Tile) bleibt in der Funktionsfarbe
# Sektor: Farbton (0..1), Sättigungsfaktor, Helligkeitsfaktor
LOOK = {2: (0.80, 0.85, 0.95), 3: (0.075, 0.90, 0.95), 4: (0.55, 0.45, 1.05), 5: (0.02, 0.60, 0.72),
        6: (0.47, 0.75, 0.85), 7: (0.10, 0.62, 0.80), 8: (0.32, 0.50, 0.70), 9: (0.70, 0.40, 0.62)}

src = Image.open("assets/art/tiles_s1.png").convert("RGBA")
for sector, (hue, sat, val) in LOOK.items():
    im = src.copy()
    px = im.load()
    for x in range(im.width):
        if x // 48 in KEEP:
            continue
        for y in range(im.height):
            if x // 48 == PAD and y < PAD_TOP:
                continue
            r, g, b, a = px[x, y]
            h, s, v = colorsys.rgb_to_hsv(r / 255, g / 255, b / 255)
            if 0.5 < h < 0.78:          # das Blau des Grundmaterials; Lichter und Gelb bleiben
                nr, ng, nb = colorsys.hsv_to_rgb(hue + 0.03 * (v - 0.4), min(1.0, s * sat), min(1.0, v * val))
                px[x, y] = (int(nr * 255), int(ng * 255), int(nb * 255), a)
    im.save("assets/art/tiles_s%d.png" % sector)
