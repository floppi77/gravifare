"""Mischform (Runde 82) komplett: je Pixelgröße n (2–6) Vorlage und Relief aus gen_taxi.render(n) (hybrid_prep.py), Blender-Render der
Drehstufen mit 10 Renderpunkten je Bildpunkt (build_hybrid.py), dann zurück auf ganze Bildpunkte: Deckung nach Mehrheit, Farben auf die
Farbtafel des 2D-Taxis derselben Größe (taxi_sizes/std.png) – so bleibt der Stil der Pixelgrafik. Die Kontur kommt aus der Vorlage.
Aufruf (Projektwurzel): python3 tools/art/taxi3d/make_hybrid.py <arbeitsordner> assets/art/taxi_hybrid [gieren=-12,-8,-4,0,4,8,12]
Ziel: je Lackierung ein Blatt <lack>.png wie taxi_sizes (Größen untereinander), Drehstufen nebeneinander (je 156 Bildpunkte breit).
Vorher gen_taxi.py laufen lassen (die Farbtafeln kommen aus assets/art/taxi_sizes/<lack>.png)."""
import glob, os, subprocess, sys
import numpy as np
from PIL import Image

W, H, K = 26, 16, 10
SIZES = (2, 3, 4, 5, 6)
OL = np.array([12, 15, 36], float)

def palette(n, skin):
    sheet = np.array(Image.open("assets/art/taxi_sizes/%s.png" % skin).convert("RGBA"))
    y = sum(H * m for m in SIZES if m < n)
    blk = sheet[y:y + H * n, :W * n].reshape(-1, 4)
    return np.unique(blk[blk[:, 3] > 0][:, :3], axis=0).astype(float)

def reduce(a, pal, t, flat=None):
    h, w = H * a.shape[0] // (H * K) * 1, 0
    rows, cols = a.shape[0] // K, a.shape[1] // K
    out = np.zeros((rows, cols, 4))
    blk = a[:rows * K, :cols * K].reshape(rows, K, cols, K, 4).transpose(0, 2, 1, 3, 4).reshape(rows, cols, K * K, 4)
    al = blk[..., 3] / 255.0
    cov = al.mean(-1)
    on = cov >= 0.5
    col = (blk[..., :3] * al[..., None]).sum(-2) / np.maximum(al.sum(-1)[..., None], 1e-6)
    if flat is not None:
        fb = flat[:rows * K, :cols * K].reshape(rows, K, cols, K, 4).transpose(0, 2, 1, 3, 4).reshape(rows, cols, K * K, 4)
        fc = np.median(fb[..., :3], axis=-2)
        lum = fc @ np.array([0.3, 0.59, 0.11])
        keep = lum < 70.0                         # Kontur, Augen, Mund, Fugen: gezeichnete Farbe, nicht vom Licht aufgehellt
        col[keep] = fc[keep]
    d = ((col[on][:, None, :] - pal[None, :, :]) ** 2).sum(-1)
    out[on, :3] = pal[d.argmin(1)]
    out[on, 3] = 255
    return out                                    # die Kontur steckt schon in der Vorlage (gen_taxi.py)

def main():
    work, dst = sys.argv[1], sys.argv[2]               # dst: Ordner, je Lackierung <lack>.png
    yaws = sys.argv[3] if len(sys.argv) > 3 else "-12,-8,-4,0,4,8,12"
    cols = len(yaws.split(","))
    os.makedirs(dst, exist_ok=True)
    sheets = {}
    y = 0
    for n in SIZES:
        src = os.path.join(work, "prep_%d" % n)
        ren = os.path.join(work, "render_%d" % n)
        subprocess.run([sys.executable, "tools/art/taxi3d/hybrid_prep.py", src, str(n)], check=True)
        for old in glob.glob(os.path.join(ren, "*", "*_*.png")):
            os.remove(old)                        # alte Drehstufen eines früheren Laufs
        subprocess.run(["blender", "-b", "-P", "tools/art/taxi3d/build_hybrid.py", "--", src, ren, str(n * K), yaws],
                       check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        t = max(1, int(n / 3.0 + 0.5))
        for skin in sorted(os.listdir(ren)):
            pal = palette(n, skin)
            if skin not in sheets:
                sheets[skin] = np.zeros((sum(H * m for m in SIZES), W * 6 * cols, 4), np.uint8)
            files = sorted(glob.glob(os.path.join(ren, skin, "yaw_*.png")), key=lambda p: int(os.path.basename(p)[4:-4]))
            for i, f in enumerate(files):
                a = np.array(Image.open(f).convert("RGBA")).astype(float)
                fl = np.array(Image.open(f.replace("yaw_", "flat_")).convert("RGBA")).astype(float)
                sheets[skin][y:y + H * n, i * W * 6:i * W * 6 + W * n] = reduce(a, pal, t, fl).astype(np.uint8)
        print("Größe", n, "fertig:", len(sheets), "Lackierungen")
        y += H * n
    for skin, sh in sheets.items():
        Image.fromarray(sh).save(os.path.join(dst, "%s.png" % skin))
    print("Blätter in", dst, ":", ", ".join(sorted(sheets)))

if __name__ == "__main__":
    main()
