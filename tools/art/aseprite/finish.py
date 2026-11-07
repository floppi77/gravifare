"""Letzter Schritt nach Aseprite: aus den exportierten PNGs in build/aseprite-workspace/gf_polish/ die Spielgrafiken bauen.
  figures   figures/fig_pre.png (ohne Kontur) + figures/passengers_14.png (mit Kontur) -> assets/art/passengers.png
            Kontur, die über Framegrenzen in Nachbarframes gelaufen ist, wird entfernt; Zeilen in Spielreihenfolge (LOOK_VOICE).
  vehicles  vehicle/v2_red.png + Ebenen veh_*.png -> assets/art/vehicle_{red,blue,green,purple,silver}.png (Farbtausch nur am Rumpf)
Aufruf aus der Projektwurzel: python3 tools/art/aseprite/finish.py figures|vehicles [--check]
--check schreibt nichts und meldet, ob das Ergebnis den Dateien in assets/art gleicht."""
import sys, colorsys
import numpy as np
from PIL import Image

P = "build/aseprite-workspace/gf_polish/"
ORDER = ["f0", "f1", "f2", "f3", "f4", "f5", "f6", "m0", "m1", "m2", "m3", "m4", "m5", "m6"]      # Reihenfolge in gen_figures.py
SHEET = ["f0", "m0", "m2", "f6", "f1", "f2", "f3", "f4", "f5", "m1", "m3", "m4", "m5", "m6"]      # = PassengerActor.LOOK_VOICE
PAINTS = {"blue": (218, 0.95, 1.0), "green": (150, 0.85, 0.95), "purple": (278, 0.85, 1.0), "silver": (220, 0.18, 1.12)}

def figures():
    pre = np.array(Image.open(P + "figures/fig_pre.png").convert("RGBA"))
    out = np.array(Image.open(P + "figures/passengers_14.png").convert("RGBA"))
    h, w = pre.shape[:2]
    op = pre[..., 3] > 0
    for y in range(h):
        for x in range(w):
            if op[y, x] or out[y, x, 3] == 0:
                continue
            own = any(0 <= x + dx < w and 0 <= y + dy < h and op[y + dy, x + dx] and (y + dy) // 36 == y // 36 and (x + dx) // 24 == x // 24
                      for dx in (-1, 0, 1) for dy in (-1, 0, 1))
            if not own:
                out[y, x] = 0
    src = Image.fromarray(out)
    sheet = Image.new("RGBA", (240, 36 * len(SHEET)))
    for r, v in enumerate(SHEET):
        i = ORDER.index(v)
        sheet.alpha_composite(src.crop((0, i * 36, 240, i * 36 + 36)), (0, r * 36))
    return {"assets/art/passengers.png": sheet}

def vehicles():
    base = np.array(Image.open(P + "vehicle/v2_red.png").convert("RGBA")).astype(float)
    hull = np.array(Image.open(P + "vehicle/veh_hull.png"))[..., 3] > 0
    det = np.array(Image.open(P + "vehicle/veh_detail.png"))
    over = (det[..., 3] > 0) | (np.array(Image.open(P + "vehicle/veh_glass.png"))[..., 3] > 0)
    seam = (det[..., 0] == 0x7a) & (det[..., 1] == 0x1a) & (det[..., 2] == 0x2a) & (det[..., 3] > 0)
    mask = (hull & ~over & (base[..., 3] > 0)) | seam
    res = {"assets/art/vehicle_red.png": Image.fromarray(base.astype(np.uint8))}
    for name, (hue, sat, val) in PAINTS.items():
        out = base.copy()
        for y, x in zip(*np.nonzero(mask)):
            hh, ss, vv = colorsys.rgb_to_hsv(*(base[y, x, :3] / 255))
            dh = ((hh + 0.5) % 1) - 0.5          # Abstand zum Rot der Vorlage: die Farbverschiebung der Rampe bleibt erhalten
            r, g, b = colorsys.hsv_to_rgb((hue / 360 + dh) % 1, min(1, ss * sat), min(1, vv * val))
            out[y, x, :3] = [r * 255, g * 255, b * 255]
        res["assets/art/vehicle_%s.png" % name] = Image.fromarray(out.clip(0, 255).astype(np.uint8))
    return res

if __name__ == "__main__":
    what = sys.argv[1] if len(sys.argv) > 1 else ""
    files = figures() if what == "figures" else (vehicles() if what == "vehicles" else None)
    if files is None:
        sys.exit("Aufruf: finish.py figures|vehicles [--check]")
    for path, img in files.items():
        if "--check" in sys.argv:
            same = np.array_equal(np.array(Image.open(path).convert("RGBA")), np.array(img))
            print(("gleich  " if same else "ANDERS  ") + path)
        else:
            img.save(path)
            print("geschrieben", path)
