"""Hintergründe der Sektoren 2–9 (Sektor 1 stammt aus gen_art.py): je Sektor drei Ebenen
bg_sN_far.png (Himmel/Fernobjekt), bg_sN_mid.png (mittlere Silhouetten), bg_sN_near.png (nahe Silhouetten), 1920x1080.
Eigene Synthese (NumPy/Pillow), Dithering wie in Sektor 1. Aufruf: python3 tools/art/gen_backgrounds.py [sektor ...]"""
import sys, random
sys.path.insert(0, "tools/art")
import numpy as np
from PIL import Image, ImageDraw
from gen_art import fbm, hexc, shade, BAYER, OUT

W, H = 1920, 1080


def dither(base, levels=24):
    thr = np.tile(BAYER, (H // 4 + 1, W // 4 + 1))[:H, :W]
    step = 255 / float(levels)
    return np.clip(np.floor(base / step + thr[:, :, None]) * step, 0, 255).astype(np.uint8)


def sky(top, bot, seed, neb_col, neb_amt=0.8, gamma=1.3):
    yy = np.linspace(0, 1, H)[:, None] ** gamma
    base = np.array(top)[None, None, :] + (np.array(bot) - np.array(top))[None, None, :] * yy[:, :, None]
    base = np.repeat(base, W, axis=1)
    n1 = fbm(W, H, seed)
    neb = np.clip((n1 - 0.45) * 2.2, 0, 1) * np.clip(1.2 - yy, 0, 1)
    base = base + neb[:, :, None] * np.array(neb_col)[None, None, :] * neb_amt
    return Image.fromarray(dither(base)).convert("RGBA")


def stars(img, seed, n=480, cols=("#ffffff", "#a9b8ff", "#ffd9a0")):
    d = ImageDraw.Draw(img)
    rnd = random.Random(seed)
    for _ in range(n):
        x, y = rnd.randrange(W), rnd.randrange(int(H * 0.8))
        c = hexc(rnd.choice(cols))
        s = rnd.choice([1, 1, 1, 2, 2, 3])
        d.rectangle([x, y, x + s - 1, y + s - 1], fill=c)


def disc(img, cx, cy, r, pal_a, pal_b, light=(-0.6, -0.5), bands=11.0, seed=5, glow=None):
    """Kugel mit Bändern und Dithering."""
    yy, xx = np.mgrid[0:H, 0:W]
    dist = np.sqrt((xx - cx) ** 2 + (yy - cy) ** 2)
    inside = dist <= r
    lt = np.clip(((xx - cx) * light[0] + (yy - cy) * light[1]) / r * 0.5 + 0.55, 0, 1)
    band = np.sin((yy - cy) / bands + fbm(W, H, seed) * 4) * 0.5 + 0.5
    col = np.array(pal_a)[None, None, :] * (1 - band[:, :, None] * 0.45) + np.array(pal_b)[None, None, :] * band[:, :, None] * 0.45
    col = col * (0.35 + 0.75 * lt[:, :, None])
    thr = np.tile(BAYER, (H // 4 + 1, W // 4 + 1))[:H, :W]
    col = np.floor(col / 18.0 + thr[:, :, None]) * 18.0
    arr = np.array(img)
    arr[inside, :3] = np.clip(col, 0, 255).astype(np.uint8)[inside]
    out = Image.fromarray(arr)
    if glow:
        g = np.zeros((H, W, 4), dtype=np.uint8)
        gd = np.clip(1.0 - (dist - r) / (r * 0.45), 0, 1) * (~inside)
        g[..., :3] = glow
        g[..., 3] = (gd * 120).astype(np.uint8)
        out.alpha_composite(Image.fromarray(g))
    return out


def silhouettes(seed, colr, hmin, hmax, wmin, wmax, base_y, deco, lit=0.1, litcols=("#ffcf6a", "#59e0d6")):
    rnd = random.Random(seed)
    im = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    x = -10
    while x < W:
        w = rnd.randrange(wmin, wmax)
        h = rnd.randrange(hmin, hmax)
        top = base_y - h
        d.rectangle([x, top, x + w, H], fill=colr)
        d.line([x, top, x + w, top], fill=shade(colr, 1.5))
        deco(d, rnd, x, top, w, h, colr)
        for wy in range(top + 14, base_y + 30, 18):
            for wx in range(x + 8, x + w - 8, 14):
                if rnd.random() < lit:
                    d.rectangle([wx, wy, wx + 4, wy + 7], fill=hexc(rnd.choice(litcols)))
        x += w + rnd.randrange(0, 18)
    return im


def no_deco(d, rnd, x, top, w, h, colr):
    pass


def antenna(d, rnd, x, top, w, h, colr):
    if rnd.random() < 0.3:
        ax = x + w // 2
        d.line([ax, top, ax, top - rnd.randrange(30, 80)], fill=shade(colr, 1.3), width=2)
        d.rectangle([ax - 2, top - 84, ax + 2, top - 80], fill=hexc("#ff4d6d"))


def neon_strips(d, rnd, x, top, w, h, colr):
    c = rnd.choice(["#ff3fa4", "#35e0d2", "#9a6bff", "#ffd24a"])
    sx = x + rnd.randrange(6, max(7, w - 8))
    d.rectangle([sx, top + 10, sx + 3, top + h * 0.6], fill=hexc(c))
    if rnd.random() < 0.4:
        d.rectangle([x + 6, top + 24, x + w - 6, top + 30], fill=hexc(c, 200))


def chimney(d, rnd, x, top, w, h, colr):
    if rnd.random() < 0.5:
        cx = x + w // 2
        d.rectangle([cx - 8, top - 70, cx + 8, top], fill=shade(colr, 1.15))
        d.rectangle([cx - 10, top - 76, cx + 10, top - 68], fill=hexc("#ff7a2e"))


def junk(d, rnd, x, top, w, h, colr):
    k = rnd.random()
    if k < 0.35:
        d.polygon([(x, top), (x + w // 3, top - 24), (x + w * 2 // 3, top - 6), (x + w, top - 30), (x + w, top)], fill=shade(colr, 1.2))
    elif k < 0.6:
        d.ellipse([x + 6, top - 20, x + 6 + 40, top + 20], outline=shade(colr, 1.6), width=4)


def coil(d, rnd, x, top, w, h, colr):
    if rnd.random() < 0.5:
        cx = x + w // 2
        for k in range(4):
            d.arc([cx - 30 - k * 8, top - 50 - k * 12, cx + 30 + k * 8, top + 10 + k * 12], 200, 340, fill=hexc("#7af0ff", 150), width=3)


def dish(d, rnd, x, top, w, h, colr):
    if rnd.random() < 0.4:
        cx = x + w // 2
        d.pieslice([cx - 30, top - 30, cx + 30, top + 30], 180, 360, fill=shade(colr, 1.3))
        d.line([cx, top, cx, top + 12], fill=shade(colr, 1.4), width=3)


def gantry(d, rnd, x, top, w, h, colr):
    if rnd.random() < 0.5:
        d.rectangle([x - 30, top + 40, x + w + 30, top + 48], fill=shade(colr, 1.25))
        for gx in range(x - 30, x + w + 30, 40):
            d.line([gx, top + 40, gx + 20, top + 80], fill=shade(colr, 1.25), width=3)
        d.rectangle([x + w // 2 - 3, top + 52, x + w // 2 + 3, top + 58], fill=hexc(rnd.choice(["#5dff9a", "#ff4d6d"])))


def sensor(d, rnd, x, top, w, h, colr):
    if rnd.random() < 0.45:
        cx = x + w // 2
        d.line([cx, top, cx, top - 90], fill=shade(colr, 1.3), width=3)
        d.polygon([(cx, top - 88), (cx - 90, top + 140), (cx + 90, top + 140)], fill=hexc("#7f8fe0", 26))
        d.ellipse([cx - 6, top - 96, cx + 6, top - 84], fill=hexc("#ff4d6d"))


def twisted(d, rnd, x, top, w, h, colr):
    if rnd.random() < 0.5:
        d.polygon([(x, top), (x + w // 2, top - rnd.randrange(30, 90)), (x + w, top)], fill=shade(colr, 1.15))


def planet_moon(img, cx, cy, r, col):
    d = ImageDraw.Draw(img)
    d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=hexc(col))


THEMES = {
    2: dict(sky=((6, 6, 26), (60, 20, 90), (110, 30, 120)), far="neon", mid=("#1a1346", 200, 520, 60, 150, 900, neon_strips, 0.16, ("#ff3fa4", "#35e0d2")), near=("#0f0a30", 80, 260, 80, 190, 1010, antenna, 0.22)),
    3: dict(sky=((14, 10, 20), (70, 44, 40), (90, 55, 40)), far="gasgiant", mid=("#2a2030", 40, 160, 60, 150, 760, junk, 0.0, ("#ffcf6a",)), near=("#16101c", 60, 200, 80, 190, 1020, junk, 0.0, ("#ffcf6a",))),
    4: dict(sky=((4, 8, 34), (20, 40, 110), (30, 120, 130)), far="aurora", mid=("#101a4a", 150, 420, 50, 110, 900, coil, 0.1, ("#7af0ff",)), near=("#0a1030", 70, 220, 70, 150, 1010, coil, 0.15, ("#7af0ff",))),
    5: dict(sky=((30, 8, 6), (110, 36, 14), (160, 60, 20)), far="sun", mid=("#3a1410", 140, 420, 60, 150, 900, chimney, 0.14, ("#ff9a3a", "#ffd24a")), near=("#240a08", 60, 220, 80, 180, 1015, chimney, 0.2, ("#ff9a3a",))),
    6: dict(sky=((4, 12, 36), (16, 64, 120), (40, 110, 160)), far="waterworld", mid=("#0e2a52", 100, 320, 70, 170, 880, dish, 0.1, ("#9ae8ff",)), near=("#081a38", 60, 210, 90, 190, 1010, dish, 0.16, ("#9ae8ff",))),
    7: dict(sky=((8, 12, 24), (40, 56, 80), (60, 90, 100)), far="hub", mid=("#1a2438", 140, 380, 60, 150, 900, gantry, 0.18, ("#5dff9a", "#ff4d6d", "#ffd24a")), near=("#0e1424", 70, 220, 80, 180, 1015, gantry, 0.22, ("#5dff9a", "#ffd24a"))),
    8: dict(sky=((2, 2, 8), (18, 14, 40), (30, 20, 60)), far="shadowring", mid=("#121028", 120, 360, 60, 140, 900, sensor, 0.06, ("#7f8fe0",)), near=("#080818", 60, 200, 80, 180, 1015, sensor, 0.08, ("#7f8fe0",))),
    9: dict(sky=((0, 0, 4), (24, 6, 30), (60, 20, 50)), far="blackhole", mid=("#12081a", 140, 380, 60, 150, 900, twisted, 0.04, ("#ff7a2e",)), near=("#08040c", 70, 220, 90, 190, 1015, twisted, 0.06, ("#ff7a2e",))),
}


def far_layer(n, th):
    top, bot, neb = th["sky"]
    kind = th["far"]
    img = sky(top, bot, 30 + n, neb, 0.8 if kind not in ("blackhole", "shadowring") else 0.45)
    stars(img, 100 + n, 520 if kind != "sun" else 200)
    d = ImageDraw.Draw(img)
    rnd = random.Random(n)
    if kind == "neon":
        for k in range(10):   # Neon-Gitterhorizont
            y = 700 + k * k * 4
            d.line([0, y, W, y], fill=hexc("#ff3fa4", 40), width=2)
        for k in range(-12, 13):
            d.line([W // 2 + k * 40, 700, W // 2 + k * 260, H], fill=hexc("#35e0d2", 38), width=2)
        img = disc(img, 1450, 300, 130, (255, 90, 170), (120, 40, 160), seed=3, glow=(255, 60, 160))
    elif kind == "gasgiant":
        img = disc(img, 1330, 300, 190, (150, 110, 80), (80, 50, 40), seed=6)
        for _ in range(90):   # ferne Asteroiden
            x, y, s = rnd.randrange(W), rnd.randrange(int(H * 0.75)), rnd.randrange(3, 11)
            d.polygon([(x, y), (x + s, y - s // 2), (x + s * 2, y), (x + s, y + s)], fill=hexc("#5a4a44"))
    elif kind == "aurora":
        for band in range(6):
            pts_top, pts_bot = [], []
            ph = rnd.random() * 6
            for x in range(0, W + 40, 40):
                y = 260 + band * 36 + np.sin(x / 210.0 + ph) * 70
                pts_top.append((x, y)); pts_bot.append((x, y + 90 + band * 6))
            col = rnd.choice([(60, 255, 180), (80, 200, 255), (160, 120, 255)])
            ov = Image.new("RGBA", (W, H), (0, 0, 0, 0)); od = ImageDraw.Draw(ov)
            od.polygon(pts_top + pts_bot[::-1], fill=col + (46,))
            img.alpha_composite(ov)
        for k in range(7):   # Feldlinien
            cx = 960
            d.arc([cx - 520 + k * 60, 480 - k * 40, cx + 520 - k * 60, 1400 + k * 40], 200, 340, fill=hexc("#7af0ff", 70), width=2)
    elif kind == "sun":
        img = disc(img, 1380, 330, 230, (255, 190, 80), (220, 90, 30), seed=8, glow=(255, 130, 40))
        for _ in range(120):   # Funken
            x, y = rnd.randrange(W), rnd.randrange(H // 2, H)
            d.rectangle([x, y, x + 2, y + 2], fill=hexc("#ffb040"))
    elif kind == "waterworld":
        img = disc(img, 1350, 340, 220, (90, 180, 255), (30, 90, 190), seed=9, glow=(100, 200, 255))
        d.ellipse([360, 180, 440, 260], fill=hexc("#cfe9ff"))
        for k in range(3):
            d.arc([1050 - k * 30, 300 - k * 12, 1650 + k * 30, 380 + k * 12], 0, 360, fill=hexc("#9ae8ff", 70), width=2)
    elif kind == "hub":
        for k in range(26):   # Verkehrsbahnen
            y = 120 + k * 34 + rnd.randrange(-6, 6)
            x0 = rnd.randrange(-200, W)
            ln = rnd.randrange(120, 420)
            d.line([x0, y, x0 + ln, y], fill=hexc(rnd.choice(["#5dff9a", "#ffd24a", "#ff4d6d"]), 110), width=3)
        d.ellipse([1200, 200, 1600, 380], outline=hexc("#9ab4d8", 150), width=6)
        d.ellipse([1290, 250, 1510, 330], fill=hexc("#2a3a58"))
        for a in range(0, 360, 45):
            x = 1400 + 200 * np.cos(np.radians(a)); y = 290 + 90 * np.sin(np.radians(a))
            d.line([1400, 290, x, y], fill=hexc("#9ab4d8", 150), width=4)
    elif kind == "shadowring":
        img = disc(img, 1300, 320, 210, (60, 50, 90), (20, 16, 40), light=(0.6, -0.2), seed=10)
        ov = Image.new("RGBA", (W, H), (0, 0, 0, 0)); od = ImageDraw.Draw(ov)
        for k in range(5):
            od.ellipse([860 - k * 12, 270 - k * 4, 1740 + k * 12, 370 + k * 4], outline=hexc("#0a0814", 220), width=6)
        img.alpha_composite(ov)
        d.ellipse([240, 120, 300, 180], fill=hexc("#fff3d0"))
    elif kind == "blackhole":
        cx, cy = 1350, 330
        for k in range(26):
            r = 300 - k * 9
            c = (255, 150 - k * 3, 40 + k * 4)
            ov = Image.new("RGBA", (W, H), (0, 0, 0, 0)); od = ImageDraw.Draw(ov)
            od.ellipse([cx - r * 1.5, cy - r * 0.38, cx + r * 1.5, cy + r * 0.38], outline=c + (56,), width=5)
            img.alpha_composite(ov)
        d = ImageDraw.Draw(img)
        d.ellipse([cx - 110, cy - 110, cx + 110, cy + 110], fill=(0, 0, 0, 255))
        d.arc([cx - 135, cy - 135, cx + 135, cy + 135], 0, 360, fill=hexc("#ffd9a0", 200), width=4)
    return img


def make(n):
    th = THEMES[n]
    far_layer(n, th).save(OUT + "bg_s%d_far.png" % n)
    for key, name in (("mid", "mid"), ("near", "near")):
        t = th[key]
        if key == "mid":
            colr, hmin, hmax, wmin, wmax, by, deco, lit, litc = t
        else:
            colr, hmin, hmax, wmin, wmax, by, deco, lit = t[:8]
            litc = ("#ffcf6a",)
        silhouettes(40 + n + (0 if key == "mid" else 7), hexc(colr), hmin, hmax, wmin, wmax, by, deco, lit, litc).save(OUT + "bg_s%d_%s.png" % (n, name))
    print("Sektor", n, "fertig")


if __name__ == "__main__":
    for n in ([int(a) for a in sys.argv[1:]] or sorted(THEMES)):
        make(n)
