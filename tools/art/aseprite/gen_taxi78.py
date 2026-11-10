"""Grundformen des Taxis in Zielgröße 78×48 px (26 × 16 Einheiten, 3 px je Einheit wie Kacheln und Figuren; Runde 62).
Bisher wurde taxi.png (96×60) im Spiel mit 0,8 verkleinert gezeichnet, dabei fielen Pixelzeilen weg. 96 × 0,8 = 76,8 px ist keine ganze Zahl:
78 px Breite (+0,4 Einheiten) hält das Taxi symmetrisch, 48 px Höhe passen genau. Die Formen folgen dem bisherigen Taxi (gen_parts.py), Maße von Hand
gesetzt statt skaliert. Ebenen wie dort: metal, fins, hull, glass, detail, driver; Schattierung und Kontur in Aseprite (README, Abschnitt Taxi 78×48).
Feste Stellen für den Code (taxi_view.gd, Texturpixel): Düsenöffnung unten y 41–44, Seitenkapseln x 0–9 / 68–77, Lampe über der Düse um (38, 40),
Aufkleber über x 8–27 / y 14–33, Kuppel x 23–54 / y 1–23.
Aufruf aus der Projektwurzel: python3 tools/art/aseprite/gen_taxi78.py ."""
import os, sys
from PIL import Image, ImageDraw

ROOT = sys.argv[1] if len(sys.argv) > 1 else "."
OUT = os.path.join(ROOT, "build/aseprite-workspace/gf_polish/taxi78/")
os.makedirs(OUT, exist_ok=True)

def hexc(h, a=255):
    h = h.lstrip("#"); return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), a)

OL = hexc("#0c0f24")
W, H = 78, 48
BODY, METAL, GLASS = hexc("#ffcb3d"), hexc("#7a80a8"), hexc("#6fe8ea")

def layer():
    im = Image.new("RGBA", (W, H)); return im, ImageDraw.Draw(im)

# --- hull: Rumpf (flach), wird in Aseprite schattiert
hull, d = layer()
d.rounded_rectangle([6, 11, 71, 37], radius=12, fill=BODY)
hull.save(OUT + "hull.png")

# --- metal: Seitenkapseln und Düse
metal, d = layer()
for ox in (1, 67):
    d.rounded_rectangle([ox, 16, ox + 9, 32], radius=3, fill=METAL)
d.rounded_rectangle([26, 34, 51, 44], radius=3, fill=METAL)
metal.save(OUT + "metal.png")

# --- glass: Kuppel
glass, d = layer()
d.rounded_rectangle([25, 3, 52, 22], radius=9, fill=GLASS)
glass.save(OUT + "glass.png")

# --- fins: Heckflossen, zweitonig von Hand
fins, d = layer()
fin_l, fin_d, fin_h = hexc("#e8901f"), hexc("#b8631a"), hexc("#ffcb3d")
d.polygon([(6, 18), (2, 12), (2, 21), (6, 24)], fill=fin_l)
d.polygon([(71, 18), (75, 12), (75, 21), (71, 24)], fill=fin_l)
d.polygon([(6, 21), (2, 18), (2, 21), (6, 24)], fill=fin_d)
d.polygon([(71, 21), (75, 18), (75, 21), (71, 24)], fill=fin_d)
d.line([2, 12, 5, 17], fill=fin_h); d.line([75, 12, 72, 17], fill=fin_h)
fins.save(OUT + "fins.png")

# --- detail: über der Schattierung
det, d = layer()
WHITE, GREY, INK2 = hexc("#ffffff"), hexc("#c9cfee"), hexc("#1b1f3d")
d.line([9, 24, 68, 24], fill=hexc("#9c4a1a"))                  # Zierleiste (Rille: Schatten oben …)
d.line([9, 31, 68, 31], fill=hexc("#ffe066"))                  # … Licht unten
for i, x in enumerate(range(10, 67, 3)):                       # Schachbrettband, 3×3-Felder in zwei Reihen
    edge = x < 14 or x > 62
    w = GREY if edge else WHITE
    d.rectangle([x, 25, x + 2, 27], fill=INK2 if i % 2 else w)
    d.rectangle([x, 28, x + 2, 30], fill=w if i % 2 else INK2)
for (x, c, cl, hi) in ((9, "#ff4d6d", "#b82a48", "#ffd0da"), (66, "#5dff9a", "#22b862", "#e0ffe9")):      # Positionslampen
    d.rectangle([x, 16, x + 2, 18], fill=hexc(c)); d.line([x, 18, x + 2, 18], fill=hexc(cl)); d.point((x + 1, 16), fill=hexc(hi))
for ox, port in ((1, 0), (67, 77)):                             # Kapseln: Rillen, Abgasöffnung mit Kühlglühen
    for k in range(3):
        d.line([ox + 2, 20 + k * 3, ox + 7, 20 + k * 3], fill=hexc("#3d4166"))
        d.line([ox + 2, 21 + k * 3, ox + 7, 21 + k * 3], fill=hexc("#9aa1cc"))
    d.line([port, 21, port, 27], fill=OL)
    d.point((port, 24), fill=hexc("#4fb8e8"))
d.line([27, 37, 50, 37], fill=hexc("#b8bfe6"))                 # Düse: Ring
d.line([27, 38, 50, 38], fill=hexc("#3d4166"))
d.rectangle([33, 41, 44, 44], fill=OL); d.rectangle([34, 41, 43, 42], fill=hexc("#22254a"))
d.line([35, 43, 42, 43], fill=hexc("#8a2a2a")); d.line([37, 43, 40, 43], fill=hexc("#e8452c"))        # Restglut (Farbton < 0,04)
for x in (29, 48):
    d.point((x, 40), fill=hexc("#e6eaff")); d.point((x, 41), fill=hexc("#3d4166"))
d.rounded_rectangle([23, 1, 54, 23], radius=11, outline=OL)      # Kuppelrahmen
d.rounded_rectangle([24, 2, 53, 23], radius=10, outline=hexc("#1f2a50"))
det.save(OUT + "detail.png")

# --- driver: Fahrer und Spiegelungen
drv, d = layer()
SK, SKD, SKH = hexc("#f2c29b"), hexc("#d9a585"), hexc("#ffe0c4")
UNI, UNID = hexc("#2d3a7a"), hexc("#1f2856")
d.rounded_rectangle([32, 16, 46, 22], radius=3, fill=UNI)       # Schultern, Uniform
d.line([32, 21, 46, 21], fill=UNID)
d.polygon([(37, 16), (39, 19), (41, 16)], fill=hexc("#e6eaff"))   # Kragen
d.point((39, 18), fill=hexc("#ff4d6d"))                          # Fliege
d.ellipse([35, 8, 43, 16], fill=SK)                              # Kopf
d.line([36, 15, 42, 15], fill=SKD); d.point((35, 12), fill=SKD); d.point((43, 12), fill=SKD)
d.point((37, 9), fill=SKH)
d.rectangle([37, 11, 37, 12], fill=OL); d.rectangle([41, 11, 41, 12], fill=OL)       # Augen
d.point((37, 11), fill=hexc("#ffffff")); d.point((41, 11), fill=hexc("#ffffff"))
d.point((36, 13), fill=hexc("#f59a9a")); d.point((42, 13), fill=hexc("#f59a9a"))    # Wangen
d.line([38, 14, 40, 14], fill=hexc("#8a3a3a"))                   # Lächeln
d.rounded_rectangle([34, 4, 44, 8], radius=2, fill=hexc("#ff7a2e"))      # Mütze mit Schirm und Plakette
d.line([35, 5, 43, 5], fill=hexc("#ffa060"))
d.rectangle([33, 8, 45, 9], fill=hexc("#c9561a")); d.line([33, 9, 45, 9], fill=hexc("#8a3410"))
d.rectangle([38, 6, 40, 7], fill=hexc("#fff3b0")); d.point((39, 7), fill=hexc("#1b1f3d"))
for (x0, y0, x1, y1) in ((28, 10, 33, 5), (29, 11, 34, 6)):       # Spiegelungen
    d.line([x0, y0, x1, y1], fill=(255, 255, 255, 220))
d.line([36, 3, 41, 3], fill=(255, 255, 255, 140))
d.point((49, 7), fill=(255, 255, 255, 200)); d.point((50, 8), fill=(255, 255, 255, 200))
d.line([27, 21, 50, 21], fill=hexc("#1f7f92"))
drv.save(OUT + "driver.png")

flat = Image.new("RGBA", (W, H))
for im in (metal, fins, hull, glass, det, drv):
    flat.alpha_composite(im)
flat.save(OUT + "flat_preview.png")
flat.resize((W * 8, H * 8), Image.NEAREST).save(OUT + "flat_preview_x8.png")
print("taxi78 ok")
