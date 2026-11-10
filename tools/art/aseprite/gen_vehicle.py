"""Eigenes Verkehrsfahrzeug („Pendlergleiter“) statt umgefärbter Taxis. Gleiche Leinwand wie das Taxi (78×48 seit Runde 62),
Nase nach rechts, im Spiel in Taxigröße 1:1 (26×16 Welteinheiten). Flache Ebenen für die Aseprite-Schattierung.
Schreibt nach build/aseprite-workspace/gf_polish/vehicle/ (nie nach assets/). Aufruf: python3 tools/art/aseprite/gen_vehicle.py ."""
import os, sys
from PIL import Image, ImageDraw

ROOT = sys.argv[1] if len(sys.argv) > 1 else "."
OUT = os.path.join(ROOT, "build/aseprite-workspace/gf_polish/vehicle/")
os.makedirs(OUT, exist_ok=True)
W, H = 78, 48                 # Runde 62: Zielgröße wie das Taxi (26 × 16 Einheiten, 1:1 bei 1080p); vorher 96×60, im Spiel verkleinert
def hexc(h, a=255):
    h = h.lstrip("#"); return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), a)
OL = hexc("#0c0f24")
BODY, METAL, GLASS = hexc("#e04a4a"), hexc("#7a80a8"), hexc("#3aa8c8")

HULL = [(2, 18), (23, 12), (47, 12), (63, 16), (74, 23), (76, 28), (73, 34), (60, 38), (11, 38), (4, 34), (2, 26)]
FIN = [(6, 16), (11, 2), (18, 2), (24, 13)]

hull = Image.new("RGBA", (W, H)); d = ImageDraw.Draw(hull)
d.polygon(HULL, fill=BODY); d.polygon(FIN, fill=BODY)
hull.save(OUT + "veh_hull.png")

metal = Image.new("RGBA", (W, H)); d = ImageDraw.Draw(metal)
d.rounded_rectangle([0, 19, 9, 33], radius=2, fill=METAL)                          # Heckantrieb
d.polygon([(13, 36), (62, 36), (57, 42), (18, 42)], fill=METAL)                  # Kufe / Unterboden
metal.save(OUT + "veh_metal.png")

glass = Image.new("RGBA", (W, H)); d = ImageDraw.Draw(glass)
d.polygon([(43, 14), (55, 14), (67, 19), (71, 24), (49, 24), (43, 20)], fill=GLASS)   # Frontscheibe
glass.save(OUT + "veh_glass.png")

det = Image.new("RGBA", (W, H)); d = ImageDraw.Draw(det)
for x in (18, 24, 30, 36):                                                         # Fensterreihe der Fahrgastkabine
    d.rectangle([x, 18, x + 4, 22], fill=hexc("#1d3a5a")); d.line([x, 18, x + 4, 18], fill=hexc("#8ad8f0")); d.point((x + 1, 19), fill=hexc("#c8f4ff"))
d.line([6, 27, 73, 27], fill=hexc("#f4f6ff")); d.line([6, 28, 71, 28], fill=hexc("#b8c0e0"))      # Zierstreifen (weiß bei allen Lackierungen)
d.line([12, 3, 17, 3], fill=hexc("#f4f6ff")); d.polygon([(12, 6), (17, 6), (14, 10)], fill=hexc("#f4f6ff"))      # Flossenkante, Emblem
d.line([43, 14, 55, 14], fill=OL); d.line([55, 14, 67, 19], fill=OL); d.line([43, 14, 43, 20], fill=OL)      # Scheibenrahmen
d.line([49, 14, 50, 24], fill=hexc("#1d3a5a"))
d.rectangle([73, 29, 75, 30], fill=hexc("#fff6c8")); d.point((74, 29), fill=hexc("#ffffff"))       # Bug weiß (Scheinwerfer bei x ≈ 74, y ≈ 29)
d.rectangle([4, 20, 5, 23], fill=hexc("#ff4d6d"))                                                    # Heck rot
for y in (23, 26, 29):                                                                               # Antrieb: Rillen, Düse mit Glut (x 0, y ≈ 26)
    d.line([2, y, 8, y], fill=hexc("#3d4166"))
d.rectangle([0, 22, 1, 30], fill=OL); d.line([0, 25, 0, 27], fill=hexc("#e8452c"))
for x in (23, 32, 42, 51):                                                                           # Kufe: Rillen
    d.line([x, 38, x + 2, 38], fill=hexc("#3d4166"))
d.line([42, 30, 42, 35], fill=hexc("#7a1a2a")); d.line([16, 30, 16, 35], fill=hexc("#7a1a2a"))      # Fugen
det.save(OUT + "veh_detail.png")
flat = Image.new("RGBA", (W, H))
for im in (metal, hull, glass, det):
    flat.alpha_composite(im)
flat.resize((W * 8, H * 8), Image.NEAREST).save(OUT + "veh_flat_x8.png")
print("ok")
