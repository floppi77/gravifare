"""Eigenes Verkehrsfahrzeug („Pendlergleiter“) statt umgefärbter Taxis. Gleiche Leinwand wie das Taxi (96×60),
Nase nach rechts, im Spiel in Taxigröße (25,6×16 Welteinheiten). Flache Ebenen für die Aseprite-Schattierung.
Schreibt nach build/aseprite-workspace/gf_polish/vehicle/ (nie nach assets/). Aufruf: python3 tools/art/aseprite/gen_vehicle.py ."""
import os, sys
from PIL import Image, ImageDraw

ROOT = sys.argv[1] if len(sys.argv) > 1 else "."
OUT = os.path.join(ROOT, "build/aseprite-workspace/gf_polish/vehicle/")
os.makedirs(OUT, exist_ok=True)
W, H = 96, 60
def hexc(h, a=255):
    h = h.lstrip("#"); return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), a)
OL = hexc("#0c0f24")
BODY, METAL, GLASS = hexc("#e04a4a"), hexc("#7a80a8"), hexc("#3aa8c8")

HULL = [(3, 22), (28, 15), (58, 15), (78, 20), (91, 29), (94, 35), (90, 42), (74, 47), (14, 47), (5, 43), (3, 32)]
FIN = [(7, 20), (13, 3), (22, 3), (29, 16)]

hull = Image.new("RGBA", (W, H)); d = ImageDraw.Draw(hull)
d.polygon(HULL, fill=BODY); d.polygon(FIN, fill=BODY)
hull.save(OUT + "veh_hull.png")

metal = Image.new("RGBA", (W, H)); d = ImageDraw.Draw(metal)
d.rounded_rectangle([0, 24, 12, 41], radius=3, fill=METAL)                         # Heckantrieb
d.polygon([(16, 45), (76, 45), (70, 52), (22, 52)], fill=METAL)                  # Kufe / Unterboden
metal.save(OUT + "veh_metal.png")

glass = Image.new("RGBA", (W, H)); d = ImageDraw.Draw(glass)
d.polygon([(53, 17), (68, 17), (83, 24), (88, 30), (60, 30), (53, 25)], fill=GLASS)   # Frontscheibe
glass.save(OUT + "veh_glass.png")

det = Image.new("RGBA", (W, H)); d = ImageDraw.Draw(det)
# Fensterreihe der Fahrgastkabine
for x in (22, 30, 38, 46):
    d.rectangle([x, 22, x + 5, 27], fill=hexc("#1d3a5a")); d.line([x, 22, x + 5, 22], fill=hexc("#8ad8f0")); d.point((x + 1, 23), fill=hexc("#c8f4ff"))
# Zierstreifen (bleibt bei allen Lackierungen weiß)
d.line([7, 33, 90, 33], fill=hexc("#f4f6ff")); d.line([7, 34, 88, 34], fill=hexc("#b8c0e0"))
# Flossenkante und Emblem
d.line([15, 4, 21, 4], fill=hexc("#f4f6ff")); d.polygon([(15, 8), (21, 8), (18, 13)], fill=hexc("#f4f6ff"))
# Scheibenrahmen
d.line([53, 17, 68, 17], fill=OL); d.line([68, 17, 83, 24], fill=OL); d.line([53, 17, 53, 25], fill=OL)
d.line([60, 17, 62, 30], fill=hexc("#1d3a5a"))
# Lichter: Bug weiß, Heck rot
d.rectangle([90, 36, 92, 37], fill=hexc("#fff6c8")); d.point((91, 36), fill=hexc("#ffffff"))
d.rectangle([5, 25, 6, 28], fill=hexc("#ff4d6d"))
# Antrieb: Rillen, Düse mit Glut
for y in (29, 33, 37):
    d.line([2, y, 10, y], fill=hexc("#3d4166"))
d.rectangle([0, 28, 1, 37], fill=OL); d.line([0, 31, 0, 34], fill=hexc("#e8452c"))
# Kufe: Rillen
for x in (28, 40, 52, 64):
    d.line([x, 48, x + 3, 48], fill=hexc("#3d4166"))
# Wartungsklappe / Fuge
d.line([52, 37, 52, 44], fill=hexc("#7a1a2a")); d.line([20, 37, 20, 44], fill=hexc("#7a1a2a"))
det.save(OUT + "veh_detail.png")
print("ok")
