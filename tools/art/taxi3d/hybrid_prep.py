"""Mischform (Runde 82): das gezeichnete 2D-Taxi (gen_taxi.py) als Bild und als Höhenrelief für Blender.
Form, Gesicht, Band und Kontur bleiben die des 2D-Taxis; das Relief (je Teil aufgewölbt) liefert in Blender Licht und Drehung.
Höhen in Einheiten zum Betrachter: Rumpf als gerundeter Wulst, Kuppel als Kugel davor, Kapseln und Flossen dahinter, Düse als Wulst.
Aufruf (Projektwurzel): python3 tools/art/taxi3d/hybrid_prep.py <ordner> [punkte_je_einheit=24]
Ausgabe: <ordner>/taxi2d_<lack>.png (RGBA, alle Lackierungen aus gen_taxi.skins), <ordner>/height.npy (float32, gleiche Größe), <ordner>/info.json"""
import json, os, sys
import numpy as np
from PIL import Image

sys.path.insert(0, "tools/art")
import gen_taxi as G

def dist_inside(mask, n):
    """Abstand jedes Pixels der Maske zum Rand (in Einheiten), schnelle Näherung über wiederholtes Abtragen."""
    d = np.zeros(mask.shape, float)
    cur = mask.copy()
    step = 0
    while cur.any() and step < 40 * n:
        step += 1
        d[cur] += 1.0
        k = cur.copy()
        k[1:, :] &= cur[:-1, :]; k[:-1, :] &= cur[1:, :]; k[:, 1:] &= cur[:, :-1]; k[:, :-1] &= cur[:, 1:]
        cur = k
    return d / n

def bulge(d, radius, height):
    u = np.clip(d / radius, 0.0, 1.0)
    return height * np.sqrt(1.0 - (1.0 - u) ** 2)

def main():
    out = sys.argv[1]
    n = int(sys.argv[2]) if len(sys.argv) > 2 else 24
    os.makedirs(out, exist_ok=True)
    col, alpha, paint = G.render(n)
    part = G.LAST_PART
    h, w = alpha.shape
    ys, xs = np.mgrid[0:h, 0:w]
    X = (xs + 0.5) / n; Y = (ys + 0.5) / n
    height = np.zeros((h, w), float)
    # Grundkörper: alles Sichtbare leicht gewölbt (Kontur, Kleinteile)
    height = np.maximum(height, bulge(dist_inside(alpha, n), 1.0, 0.6) * alpha)
    # Rumpf: Ellipsoid (rund in beide Richtungen), am Rand mindestens leicht gewölbt
    hull = part == 1
    U = X - G.W / 2.0
    ell = 2.6 * np.sqrt(np.clip(1.0 - (U / 11.4) ** 2 - ((Y - 8.3) / 4.9) ** 2, 0.0, None))
    height = np.where(hull, np.maximum(ell, bulge(dist_inside(hull | (part == 2), n), 0.8, 0.5)), height)
    spec = {3: (1.1, 1.5, -0.8), 4: (1.2, 2.0, 0.0), 5: (0.6, 0.5, -1.0)}
    for pid, (rad, hh, base) in spec.items():
        m = part == pid
        if m.any():
            hp = base + bulge(dist_inside(m, n), rad, hh)
            height = np.where(m, np.maximum(height, hp) if base >= 0 else hp, height)
    # Kuppel: Kugelkappe vor dem Rumpf
    dome = part == 2
    r = G.DOME_R
    dd = np.sqrt((X - G.W / 2.0) ** 2 + (Y - G.DOME_Y) ** 2)
    cap = np.sqrt(np.clip(r * r - dd * dd, 0.0, None)) * 0.7 + 1.0
    height = np.where(dome, np.maximum(cap, 1.2), height)
    # zum Umriss hin auslaufen lassen: keine Stufe an der Silhouette, sonst stellt sich die Kontur beim Drehen als dunkle Wand auf
    edge = np.clip(dist_inside(alpha, n) / 1.4, 0.0, 1.0)
    height = height * (edge * edge * (3.0 - 2.0 * edge))
    height[~alpha] = 0.0
    # Kontur am Außenrand flach halten (Rand des Reliefs = Silhouette des 2D-Taxis)
    for name, im in G.skins(n).items():                 # dasselbe Relief für alle Lackierungen, nur die Vorlage wechselt
        im.save(os.path.join(out, "taxi2d_%s.png" % name))
    np.save(os.path.join(out, "height.npy"), height.astype(np.float32))
    json.dump({"n": n, "w": G.W, "h": G.H, "max_height": float(height.max()), "skins": list(G.skins(n).keys())}, open(os.path.join(out, "info.json"), "w"))
    print("Bild und Relief", w, "×", h, "max. Höhe %.2f" % height.max())

if __name__ == "__main__":
    main()
