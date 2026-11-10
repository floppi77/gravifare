"""Erzeugt die Pixel-Art-Assets (Sektor 1 Sternenhafen, Taxi-Lackierungen, Ausgangstor, Hintergründe).
Taxi und Fahrgäste selbst sind in Aseprite gezeichnet: tools/art/aseprite/.
Aufruf: python3 tools/art/gen_art.py   -> schreibt nach assets/art/
Alle Grafiken entstehen in 3-facher Detailauflösung (Tile = 48 px, im Spiel 16 Welteinheiten),
damit sie bei 1080p (Skalierung 3) pixelgenau und bei 4K (6x) sauber vergrößert erscheinen.
Eigenständig per Code gezeichnet, keine Fremdassets."""
import os, random
import numpy as np
from PIL import Image, ImageDraw

OUT = "assets/art/"
T = 48  # Tile-Kantenlänge in Pixeln

def hexc(h, a=255):
    h = h.lstrip("#"); return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), a)

def shade(c, f):
    return tuple(max(0, min(255, int(v * f))) for v in c[:3]) + (c[3],)

OUTLINE = hexc("#0c0f24")

def add_outline(img, col=OUTLINE, thick=1):
    """Dunkle Kontur um alle undurchsichtigen Pixel (außen)."""
    a = np.array(img)
    opaque = a[:, :, 3] > 0
    grow = opaque.copy()
    for _ in range(thick):
        g = grow.copy()
        g[1:, :] |= grow[:-1, :]; g[:-1, :] |= grow[1:, :]
        g[:, 1:] |= grow[:, :-1]; g[:, :-1] |= grow[:, 1:]
        grow = g
    ring = grow & ~opaque
    a[ring] = col
    return Image.fromarray(a)

def vgrad(d, box, top, bot, mask_fn=None):
    x0, y0, x1, y1 = box
    for y in range(y0, y1 + 1):
        t = (y - y0) / max(1, y1 - y0)
        c = tuple(int(top[i] + (bot[i] - top[i]) * t) for i in range(3)) + (255,)
        d.line([x0, y, x1, y], fill=c)

# ------------------------------------------------------------------ Tiles
P = dict(
    base=hexc("#2a3060"), lite=hexc("#3d4a8c"), lite2=hexc("#5967b4"), dark=hexc("#171b3d"), deep=hexc("#12152f"),
    rivet=hexc("#8d9be8"), rivet_s=hexc("#0e1128"),
    pad=hexc("#183652"), pad_l=hexc("#35e0d2"), pad_d=hexc("#168a86"), steel=hexc("#6f7fa8"),
    fuel=hexc("#3b1d10"), fuel_l=hexc("#ffa530"), fuel_hi=hexc("#ffdc8a"),
    spike=hexc("#f0587a"), spike_d=hexc("#8f2a45"), spike_h=hexc("#ffc1d0"),
)

def plate(d, rnd, ox, variant, deep=False):
    base = shade(P["base"], 0.72) if deep else P["base"]
    d.rectangle([ox, 0, ox + T - 1, T - 1], fill=base)
    # Rauschen in drei diskreten Stufen
    for _ in range(110):
        x, y = rnd.randrange(T), rnd.randrange(T)
        d.point((ox + x, y), fill=rnd.choice([P["dark"], P["lite"], P["dark"], base]))
    if deep:
        for i in (0, 24):
            d.line([ox, i, ox + T - 1, i], fill=P["deep"]); d.line([ox + i, 0, ox + i, T - 1], fill=P["deep"])
        return
    # Fase: oben/links hell, unten/rechts dunkel
    d.line([ox, 0, ox + T - 1, 0], fill=P["lite2"]); d.line([ox, 1, ox + T - 1, 1], fill=P["lite"])
    d.line([ox, 0, ox, T - 1], fill=P["lite"])
    d.line([ox, T - 1, ox + T - 1, T - 1], fill=P["deep"]); d.line([ox + T - 1, 0, ox + T - 1, T - 1], fill=P["dark"])
    d.line([ox + 1, T - 2, ox + T - 2, T - 2], fill=P["dark"])
    def rivet(x, y):
        d.rectangle([ox + x, y, ox + x + 2, y + 2], fill=P["rivet"]); d.point((ox + x + 2, y + 2), fill=P["rivet_s"])
    for (x, y) in ((4, 4), (40, 4), (4, 40), (40, 40)): rivet(x, y)
    if variant == 1:    # zwei Paneele
        d.line([ox + 3, 24, ox + T - 4, 24], fill=P["deep"]); d.line([ox + 3, 25, ox + T - 4, 25], fill=P["lite"])
    elif variant == 2:  # Lüftungsschlitze
        for k in range(5):
            y = 12 + k * 5
            d.rectangle([ox + 12, y, ox + 35, y + 2], fill=P["deep"]); d.line([ox + 12, y + 3, ox + 35, y + 3], fill=P["lite"])
    elif variant == 3:  # Statusleuchte + Leitung
        d.rectangle([ox + 10, 22, ox + 37, 25], fill=P["dark"])
        col = rnd.choice([hexc("#35e0d2"), hexc("#ffb02e"), hexc("#ff5a7a")])
        d.rectangle([ox + 20, 18, ox + 27, 29], fill=P["deep"]); d.rectangle([ox + 21, 19, ox + 26, 28], fill=shade(col, 0.55))
        d.rectangle([ox + 22, 21, ox + 25, 26], fill=col)
    # Kratzer
    for _ in range(3):
        x, y = rnd.randrange(8, 36), rnd.randrange(8, 38)
        d.line([ox + x, y, ox + x + rnd.randrange(3, 8), y + rnd.randrange(-1, 2)], fill=P["dark"])

def tiles():
    img = Image.new("RGBA", (T * 10, T), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    rnd = random.Random(11)
    for v in range(4): plate(d, rnd, v * T, v)
    # Pad (4)
    ox = 4 * T
    d.rectangle([ox, 0, ox + T - 1, T - 1], fill=P["pad"])
    vgrad(d, (ox, 0, ox + T - 1, 5), P["pad_l"][:3], P["pad_d"][:3])
    d.line([ox, 6, ox + T - 1, 6], fill=OUTLINE)
    for k in range(0, T, 12):
        d.rectangle([ox + k + 2, 1, ox + k + 5, 3], fill=hexc("#d9fffb"))
    for y in (14, 15): d.line([ox, y, ox + T - 1, y], fill=shade(P["pad"], 1.35))
    d.rectangle([ox + 5, 22, ox + 17, 34], fill=P["dark"]); d.rectangle([ox + 30, 22, ox + 42, 34], fill=P["dark"])
    for k in range(3):
        d.line([ox + 6, 24 + k * 4, ox + 16, 24 + k * 4], fill=P["steel"]); d.line([ox + 31, 24 + k * 4, ox + 41, 24 + k * 4], fill=P["steel"])
    d.line([ox, T - 1, ox + T - 1, T - 1], fill=P["deep"])
    # Tankpad (5) – in eigener Ebene gezeichnet, damit nichts in Nachbar-Tiles läuft
    ft = Image.new("RGBA", (T, T), P["fuel"]); fd = ImageDraw.Draw(ft)
    vgrad(fd, (0, 0, T - 1, 5), P["fuel_hi"][:3], P["fuel_l"][:3])
    fd.line([0, 6, T - 1, 6], fill=OUTLINE)
    for k in range(-T, T, 16):
        fd.polygon([(k, T - 1), (k + 8, T - 1), (k + 24, 16), (k + 16, 16)], fill=P["fuel_l"])
    fd.rectangle([0, 16, T - 1, 17], fill=OUTLINE)
    img.paste(ft, (5 * T, 0))
    # Dornen (6)
    ox = 6 * T
    d.rectangle([ox, 36, ox + T - 1, T - 1], fill=P["spike_d"])
    for x in range(0, T, 12):
        d.polygon([(ox + x, 36), (ox + x + 6, 4), (ox + x + 12, 36)], fill=P["spike"])
        d.polygon([(ox + x + 2, 36), (ox + x + 6, 8), (ox + x + 6, 36)], fill=P["spike_h"])
        d.line([ox + x, 36, ox + x + 6, 4], fill=OUTLINE); d.line([ox + x + 12, 36, ox + x + 6, 4], fill=OUTLINE)
    # Tiefe Paneele (7-9)
    for k in range(3): plate(d, rnd, (7 + k) * T, 0, deep=True)
    img.save(OUT + "tiles_s1.png")

def tiles_normal():
    """Normal-Map zum Tile-Atlas (OpenGL-Konvention, Grün = oben), aus der Helligkeit des Diffuse-Tiles abgeleitet:
    Fasen, Nieten, Schlitze und Rillen bekommen so echtes Relief unter den 2D-Lichtern."""
    from scipy.ndimage import gaussian_filter, sobel
    im = Image.open(OUT + "tiles_s1.png").convert("RGBA")
    a = np.array(im).astype(float)
    out = np.zeros_like(a); out[:, :, 0] = 128; out[:, :, 1] = 128; out[:, :, 2] = 255; out[:, :, 3] = 255
    for i in range(im.size[0] // T):
        tile = a[:, i * T:(i + 1) * T, :]
        lum = (0.3 * tile[:, :, 0] + 0.59 * tile[:, :, 1] + 0.11 * tile[:, :, 2]) / 255.0
        h = gaussian_filter(lum, 0.8, mode="nearest")
        dx = sobel(h, axis=1, mode="nearest") / 8.0
        dy = sobel(h, axis=0, mode="nearest") / 8.0
        k = 3.0
        nx, ny, nz = -dx * k, dy * k, np.ones_like(h)
        ln = np.sqrt(nx * nx + ny * ny + nz * nz)
        n = np.stack([nx / ln, ny / ln, nz / ln], axis=2)
        blk = (n * 0.5 + 0.5) * 255.0
        flat = tile[:, :, 3] < 10
        blk[flat] = (128, 128, 255)
        out[:, i * T:(i + 1) * T, :3] = blk
    Image.fromarray(np.clip(out, 0, 255).astype(np.uint8)).save(OUT + "tiles_s1_n.png")

# ------------------------------------------------------------------ Taxi und Fahrgäste
# taxi.png und passengers.png entstehen in Aseprite (tools/art/aseprite/, siehe README dort) und werden hier
# nicht mehr erzeugt. taxi_skins() leitet die Lackierungen weiterhin aus assets/art/taxi.png ab.

# ------------------------------------------------------------------ Wartebereich-Unterstand (24x20 Einheiten = 72x60 px)
def shelter():
    W, H = 72, 60
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0)); d = ImageDraw.Draw(img)
    wall, wall_d, glass = hexc("#2a3466"), hexc("#1a2048"), hexc("#7ef0ee", 70)
    d.rectangle([3, 12, W - 4, H - 1], fill=wall)                                 # Rückwand
    vgrad(d, (3, 12, W - 4, H - 1), hexc("#34407e")[:3], hexc("#1b2250")[:3])
    for x in range(8, W - 6, 9): d.line([x, 14, x, H - 2], fill=wall_d)           # Paneelfugen
    # beleuchtete Tür in der Mitte
    d.rectangle([27, 22, 44, H - 1], fill=OUTLINE)
    d.rectangle([29, 24, 42, H - 1], fill=hexc("#ffe9a8")); vgrad(d, (29, 24, 42, H - 1), hexc("#fff6d0")[:3], hexc("#ffb85a")[:3])
    d.rectangle([29, 24, 42, 27], fill=hexc("#7a5a2a"))
    # Bank links und rechts der Tür
    for bx in (6, 48):
        d.rectangle([bx, 44, bx + 17, 47], fill=hexc("#c9871f")); d.rectangle([bx, 47, bx + 17, 48], fill=hexc("#7a4a12"))
        d.rectangle([bx + 2, 48, bx + 3, 56], fill=OUTLINE); d.rectangle([bx + 14, 48, bx + 15, 56], fill=OUTLINE)
    # Dach mit Leuchtkante
    d.polygon([(0, 14), (6, 4), (W - 7, 4), (W - 1, 14)], fill=hexc("#4a5596"))
    d.polygon([(2, 14), (7, 6), (W - 8, 6), (W - 3, 14)], fill=hexc("#6a78c4"))
    d.rectangle([0, 14, W - 1, 17], fill=hexc("#232a5a")); d.rectangle([2, 17, W - 3, 18], fill=hexc("#35e0d2"))
    # Piktogramm-Schild
    d.rectangle([30, 9, 41, 13], fill=OUTLINE); d.rectangle([31, 10, 40, 12], fill=hexc("#ffcb3d"))
    # Glasscheibe (leicht durchsichtig)
    for gx in (5, 49): d.rectangle([gx, 20, gx + 17, 42], fill=glass)
    img = add_outline(img)
    img.save(OUT + "shelter.png")

# ------------------------------------------------------------------ Ausgangstor
GW, GH = 192, 96          # 4x2 Tiles
INNER = (10, 10, 181, 85)  # Öffnung im Rahmen (x0, y0, x1, y1)
LEAF_W = 86

def gate():
    fr = Image.new("RGBA", (GW, GH), (0, 0, 0, 0)); d = ImageDraw.Draw(fr)
    d.rectangle([0, 0, GW - 1, GH - 1], fill=hexc("#6f7fa8"))
    vgrad(d, (0, 0, GW - 1, GH - 1), hexc("#8d9be8")[:3], hexc("#2c3262")[:3])
    x0, y0, x1, y1 = INNER
    d.rectangle([x0 - 2, y0 - 2, x1 + 2, y1 + 2], fill=OUTLINE)
    # Warnstreifen oben/unten und Seitenpylone
    for k in range(0, GW, 12):
        d.polygon([(k, 0), (k + 6, 0), (k + 2, 6), (k - 4, 6)], fill=hexc("#ffcb3d"))
        d.polygon([(k, GH - 1), (k + 6, GH - 1), (k + 2, GH - 7), (k - 4, GH - 7)], fill=hexc("#ffcb3d"))
    d.rectangle([0, 6, 3, GH - 7], fill=hexc("#232a5a")); d.rectangle([GW - 4, 6, GW - 1, GH - 7], fill=hexc("#232a5a"))
    for (x, y) in ((5, 7), (GW - 8, 7), (5, GH - 10), (GW - 8, GH - 10)):
        d.rectangle([x, y, x + 2, y + 2], fill=hexc("#d9e0ff"))
    # Öffnung freistanzen
    a = np.array(fr); a[y0:y1 + 1, x0:x1 + 1, :] = 0
    fr = Image.fromarray(a)
    fr = add_outline(fr)
    fr.save(OUT + "gate_frame.png")
    # Torflügel (links); rechter Flügel gespiegelt
    lf = Image.new("RGBA", (LEAF_W, INNER[3] - INNER[1] + 1), (0, 0, 0, 0)); d = ImageDraw.Draw(lf)
    h = lf.size[1]
    d.rectangle([0, 0, LEAF_W - 1, h - 1], fill=hexc("#4a5596"))
    vgrad(d, (0, 0, LEAF_W - 1, h - 1), hexc("#6a78c4")[:3], hexc("#2f3868")[:3])
    for y in range(8, h, 16): d.line([0, y, LEAF_W - 1, y], fill=hexc("#232a5a")); d.line([0, y + 1, LEAF_W - 1, y + 1], fill=hexc("#8d9be8"))
    for x in range(10, LEAF_W - 12, 20): d.line([x, 0, x, h - 1], fill=hexc("#232a5a"))
    for k in range(-h, 14, 12):
        d.polygon([(LEAF_W - 14 + k, h), (LEAF_W - 9 + k, h), (LEAF_W - 9 + k + h, 0), (LEAF_W - 14 + k + h, 0)], fill=hexc("#ffcb3d")) if False else None
    d.rectangle([LEAF_W - 12, 0, LEAF_W - 1, h - 1], fill=hexc("#ffcb3d"))
    for y in range(0, h, 12):
        d.polygon([(LEAF_W - 12, y), (LEAF_W - 1, y - 11), (LEAF_W - 1, y - 5), (LEAF_W - 12, y + 6)], fill=OUTLINE)
    d.line([LEAF_W - 13, 0, LEAF_W - 13, h - 1], fill=OUTLINE)
    lf = add_outline(lf)
    lf.save(OUT + "gate_leaf_l.png")
    lf.transpose(Image.FLIP_LEFT_RIGHT).save(OUT + "gate_leaf_r.png")

# ------------------------------------------------------------------ Hintergründe (1920x1080)
BAYER = np.array([[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]) / 16.0

def fbm(w, h, seed, octaves=5):
    rng = np.random.default_rng(seed)
    out = np.zeros((h, w)); amp, tot = 1.0, 0.0
    for o in range(octaves):
        n = 2 ** (o + 2)
        g = rng.random((n + 1, int(n * w / h) + 2))
        im = Image.fromarray((g * 255).astype(np.uint8)).resize((w, h), Image.BICUBIC)
        out += np.array(im) / 255.0 * amp; tot += amp; amp *= 0.5
    return out / tot

def background():
    W, H = 1920, 1080
    rnd = random.Random(21)
    yy = np.linspace(0, 1, H)[:, None] ** 1.3
    top, bot = np.array([8, 10, 30]), np.array([54, 34, 96])
    base = top[None, None, :] + (bot - top)[None, None, :] * yy[:, :, None]
    base = np.repeat(base, W, axis=1)
    n1 = fbm(W, H, 3); n2 = fbm(W, H, 9)
    neb = np.clip((n1 - 0.45) * 2.2, 0, 1) * np.clip(1.2 - yy, 0, 1)
    base += neb[:, :, None] * np.array([70, 25, 95])[None, None, :] * 0.8
    base += np.clip((n2 - 0.52) * 2.5, 0, 1)[:, :, None] * np.array([10, 70, 80])[None, None, :] * 0.5
    # Dithering: Quantisierung auf 24 Stufen je Kanal mit Bayer-Matrix
    thr = np.tile(BAYER, (H // 4 + 1, W // 4 + 1))[:H, :W]
    step = 255 / 24.0
    q = np.floor(base / step + thr[:, :, None]) * step
    img = Image.fromarray(np.clip(q, 0, 255).astype(np.uint8)).convert("RGBA")
    d = ImageDraw.Draw(img)
    for _ in range(520):
        x, y = rnd.randrange(W), rnd.randrange(int(H * 0.8))
        c = rnd.choice([hexc("#ffffff"), hexc("#a9b8ff"), hexc("#ffd9a0"), hexc("#7f8fe0")])
        s = rnd.choice([1, 1, 1, 2, 2, 3])
        d.rectangle([x, y, x + s - 1, y + s - 1], fill=c)
        if s == 3:
            d.line([x - 3, y + 1, x + 5, y + 1], fill=shade(c, 0.5)); d.line([x + 1, y - 3, x + 1, y + 5], fill=shade(c, 0.5))
    # Ringplanet
    cx, cy, r = 1380, 300, 150
    back_ring = Image.new("RGBA", (W, H), (0, 0, 0, 0)); bd = ImageDraw.Draw(back_ring)
    for k, col in enumerate((hexc("#ffd9a0", 170), hexc("#d89a6a", 140), hexc("#ffe9c4", 120))):
        bd.ellipse([cx - r - 80 - k * 14, cy - 26 - k * 5, cx + r + 80 + k * 14, cy + 26 + k * 5], outline=col, width=5)
    img.alpha_composite(back_ring)
    yy2, xx2 = np.mgrid[0:H, 0:W]
    dist = np.sqrt((xx2 - cx) ** 2 + (yy2 - cy) ** 2)
    inside = dist <= r
    light = np.clip(((xx2 - cx) * -0.6 + (yy2 - cy) * -0.5) / r * 0.5 + 0.55, 0, 1)
    band = (np.sin((yy2 - cy) / 11.0 + fbm(W, H, 5)[:, :] * 4) * 0.5 + 0.5)
    pal_a, pal_b = np.array([243, 150, 86]), np.array([196, 98, 52])
    col = pal_a[None, None, :] * (1 - band[:, :, None] * 0.45) + pal_b[None, None, :] * band[:, :, None] * 0.45
    col = col * (0.35 + 0.75 * light[:, :, None])
    col = np.floor(col / 18.0 + thr[:, :, None]) * 18.0
    arr = np.array(img); arr[inside, :3] = np.clip(col, 0, 255).astype(np.uint8)[inside]
    img = Image.fromarray(arr)
    front = Image.new("RGBA", (W, H), (0, 0, 0, 0)); fd = ImageDraw.Draw(front)
    for k, col in enumerate((hexc("#ffd9a0", 210), hexc("#d89a6a", 180), hexc("#ffe9c4", 150))):
        fd.arc([cx - r - 80 - k * 14, cy - 26 - k * 5, cx + r + 80 + k * 14, cy + 26 + k * 5], 0, 180, fill=col, width=5)
    img.alpha_composite(front)
    # Horizont-Glut
    gl = np.zeros((H, W, 4), dtype=np.uint8)
    for y in range(640, 1000):
        t = (y - 640) / 360.0
        gl[y, :, :3] = (110, 60, 130); gl[y, :, 3] = int(70 * (1 - abs(t - 0.5) * 2))
    img.alpha_composite(Image.fromarray(gl))
    img.save(OUT + "bg_s1_far.png")

    def skyline(seed, colr, hmin, hmax, wmin, wmax, base_y, lit, tall=False):
        r2 = random.Random(seed)
        im = Image.new("RGBA", (W, H), (0, 0, 0, 0)); dd = ImageDraw.Draw(im)
        x = -10
        while x < W:
            w = r2.randrange(wmin, wmax); h = r2.randrange(hmin, hmax)
            top = base_y - h
            dd.rectangle([x, top, x + w, H], fill=colr)
            dd.line([x, top, x + w, top], fill=shade(colr, 1.5))
            kind = r2.random()
            if kind < 0.3:  # Antenne
                ax = x + w // 2; dd.line([ax, top, ax, top - r2.randrange(30, 80)], fill=shade(colr, 1.3), width=2)
                dd.rectangle([ax - 2, top - 84, ax + 2, top - 80], fill=hexc("#ff4d6d"))
            elif kind < 0.5:  # Kuppel
                dd.pieslice([x + 4, top - w // 2, x + w - 4, top + w // 2], 180, 360, fill=shade(colr, 1.25))
            for wy in range(top + 14, base_y + 30, 18):
                for wx in range(x + 8, x + w - 8, 14):
                    if r2.random() < lit:
                        c = hexc("#ffcf6a") if r2.random() < 0.7 else hexc("#59e0d6")
                        dd.rectangle([wx, wy, wx + 4, wy + 7], fill=c)
            x += w + r2.randrange(0, 16)
        return im
    skyline(8, hexc("#1c2250"), 120, 360, 50, 120, 880, 0.12).save(OUT + "bg_s1_mid.png")
    near = skyline(15, hexc("#12163a"), 60, 220, 70, 170, 1000, 0.2)
    nd = ImageDraw.Draw(near)
    for y in (760, 830):  # Gerüste/Rohre
        nd.rectangle([0, y, W, y + 8], fill=hexc("#0e1230"))
        for x in range(0, W, 120): nd.rectangle([x, y - 40, x + 6, y + 8], fill=hexc("#0e1230"))
    near.save(OUT + "bg_s1_near.png")

# ------------------------------------------------------------------ Lackierungen und Aufkleber (Kosmetik, Garage)
def _rgb2hsv(a):
    r, g, b = a[..., 0], a[..., 1], a[..., 2]
    mx, mn = a.max(-1), a.min(-1); d = mx - mn
    h = np.zeros_like(mx)
    m = d > 1e-6
    rc = (mx == r) & m; gc = (mx == g) & m & ~rc; bc = (mx == b) & m & ~rc & ~gc
    h[rc] = ((g - b)[rc] / d[rc]) % 6; h[gc] = (b - r)[gc] / d[gc] + 2; h[bc] = (r - g)[bc] / d[bc] + 4
    s_ = np.where(mx > 1e-6, d / np.maximum(mx, 1e-6), 0)
    return h / 6.0, s_, mx
def _hsv2rgb(h, s_, v):
    i = np.floor(h * 6).astype(int) % 6; f = h * 6 - np.floor(h * 6)
    p_, q, t_ = v * (1 - s_), v * (1 - f * s_), v * (1 - (1 - f) * s_)
    out = np.zeros(h.shape + (3,))
    for k, (r, g, b) in enumerate([(v, t_, p_), (q, v, p_), (p_, v, t_), (p_, q, v), (t_, p_, v), (v, p_, q)]):
        mk = i == k; out[mk, 0], out[mk, 1], out[mk, 2] = r[mk], g[mk], b[mk]
    return out

def taxi_skins():
    """Lackierungen per Farbtausch der gelb-orangen Karosserie: taxi_<name>.png aus taxi.png und das Leben-Symbol life_<name>.png
    aus life_icon.png (beide in Aseprite gezeichnet, tools/art/aseprite)."""
    for src, dst, stripe in (("taxi.png", "taxi_%s.png", 6), ("life_icon.png", "life_%s.png", 3)):
        base = np.array(Image.open(OUT + src).convert("RGBA")).astype(float)
        rgb = base[..., :3] / 255.0
        h, s_, v = _rgb2hsv(rgb)
        body = (base[..., 3] > 0) & (h > 0.04) & (h < 0.18) & (s_ > 0.4) & (v > 0.35)   # gelb/orange Karosserie
        def make(name, hue, smul=1.0, vmul=1.0):
            hh = np.where(body, (hue / 360.0 + (h - 0.12) * 0.5) % 1.0, h)
            ss = np.where(body, np.clip(s_ * smul, 0, 1), s_); vv = np.where(body, np.clip(v * vmul, 0, 1), v)
            out = base.copy(); out[..., :3] = _hsv2rgb(hh, ss, vv) * 255.0
            Image.fromarray(np.clip(out, 0, 255).astype(np.uint8)).save(OUT + dst % name)
            return out
        for name, hue, sm, vm in (("neon", 318, 1.0, 1.0), ("mint", 150, 0.9, 1.0), ("night", 225, 0.9, 0.78),
                                  ("sunset", 8, 1.0, 1.0), ("candy", 178, 0.85, 1.05), ("gold", 46, 0.7, 1.12),
                                  ("sky", 198, 0.55, 1.1), ("platinum", 215, 0.12, 1.18)):          # sky: Serie 7 Tage, platinum: Serie 14 Tage (Tagschicht)
            make(name, hue, sm, vm)
        # Wespe: dunkle Karosserie mit gelben Streifen
        out = make("wasp", 235, 0.35, 0.28)
        yy, xx = np.mgrid[0:base.shape[0], 0:base.shape[1]]
        stripes = body & ((xx // stripe) % 2 == 0)
        out[stripes, :3] = base[stripes, :3]
        Image.fromarray(np.clip(out, 0, 255).astype(np.uint8)).save(OUT + dst % "wasp")
        Image.open(OUT + src).save(OUT + dst % "std")

class _Scaled:
    """Zeichenfläche, die alle Koordinaten mit k multipliziert: dieselben Formen, neu gerastert in kleinerer Pixelgröße (kein Verkleinern des Bilds)."""
    def __init__(self, d, k):
        self.d, self.k = d, k
    def polygon(self, pts, fill=None):
        self.d.polygon([(x * self.k, y * self.k) for x, y in pts], fill=fill)
    def ellipse(self, box, fill=None):
        self.d.ellipse([round(v * self.k) for v in box], fill=fill)
    def rectangle(self, box, fill=None):
        self.d.rectangle([round(v * self.k) for v in box], fill=fill)

STICKER_SMALL = 20      # Aufkleber am Taxi im Spiel: 20 px = 6,67 Einheiten, 1:1 bei 1080p (Runde 62; das große Bild bleibt für Garage, Menü, Werkstatt)

def stickers(small_only=False):
    def icon(draw_fn, name):
        if not small_only:
            im = Image.new("RGBA", (36, 36), (0, 0, 0, 0)); d = ImageDraw.Draw(im); draw_fn(d)
            add_outline(im, thick=1).save(OUT + "sticker_%s.png" % name)
        sm = Image.new("RGBA", (STICKER_SMALL, STICKER_SMALL), (0, 0, 0, 0))
        draw_fn(_Scaled(ImageDraw.Draw(sm), (STICKER_SMALL - 2) / 36.0))
        sm2 = Image.new("RGBA", (STICKER_SMALL, STICKER_SMALL), (0, 0, 0, 0)); sm2.alpha_composite(sm, (1, 1))
        add_outline(sm2, thick=1).save(OUT + "sticker_%s_s.png" % name)
    import math
    def star(d):
        pts = []
        for i in range(10):
            r = 15 if i % 2 == 0 else 6.5; a = -math.pi / 2 + i * math.pi / 5
            pts.append((18 + r * math.cos(a), 19 + r * math.sin(a)))
        d.polygon(pts, fill=hexc("#ffe14a")); d.polygon([(18, 8), (21, 15), (16, 15)], fill=hexc("#fff6b0"))
    def bolt(d):
        d.polygon([(21, 3), (9, 20), (17, 20), (13, 33), (27, 14), (19, 14)], fill=hexc("#35e0d2")); d.polygon([(21, 3), (16, 11), (20, 11)], fill=hexc("#bffcf6"))
    def heart(d):
        d.ellipse([4, 8, 19, 23], fill=hexc("#ff4d6d")); d.ellipse([17, 8, 32, 23], fill=hexc("#ff4d6d"))
        d.polygon([(5, 19), (31, 19), (18, 33)], fill=hexc("#ff4d6d")); d.ellipse([8, 11, 13, 15], fill=hexc("#ffb0c0"))
    def flame(d):
        d.polygon([(18, 3), (28, 16), (27, 28), (18, 34), (9, 28), (8, 16), (14, 20)], fill=hexc("#ff8a2e"))
        d.polygon([(18, 14), (23, 24), (22, 30), (18, 32), (14, 30), (13, 24)], fill=hexc("#ffe14a"))
    def boom(d):
        pts = []
        for i in range(16):
            r = 16 if i % 2 == 0 else 8; a = i * math.pi / 8
            pts.append((18 + r * math.cos(a), 18 + r * math.sin(a)))
        d.polygon(pts, fill=hexc("#ff7a30")); d.ellipse([10, 10, 26, 26], fill=hexc("#ffd37a")); d.ellipse([14, 14, 22, 22], fill=hexc("#fff6d0"))
    def crown(d):
        d.polygon([(4, 28), (4, 10), (12, 18), (18, 6), (24, 18), (32, 10), (32, 28)], fill=hexc("#ffcb3d"))
        d.rectangle([4, 27, 32, 31], fill=hexc("#e08a1e")); d.ellipse([16, 18, 20, 22], fill=hexc("#ff4d6d"))
    def sun(d):                                                                           # Serie 3 Tage (Tagschicht)
        for i in range(12):
            a = i * math.pi / 6
            d.polygon([(18 + 9 * math.cos(a - 0.2), 18 + 9 * math.sin(a - 0.2)), (18 + 16 * math.cos(a), 18 + 16 * math.sin(a)), (18 + 9 * math.cos(a + 0.2), 18 + 9 * math.sin(a + 0.2))], fill=hexc("#ffb02e"))
        d.ellipse([8, 8, 28, 28], fill=hexc("#ffd24a")); d.ellipse([11, 11, 19, 19], fill=hexc("#fff3b0"))
    def medal(d):                                                                         # 5 Mal Gold in der Tagschicht
        d.polygon([(9, 3), (17, 3), (21, 16), (13, 16)], fill=hexc("#4a7bff")); d.polygon([(27, 3), (19, 3), (15, 16), (23, 16)], fill=hexc("#ff4d6d"))
        d.ellipse([6, 13, 30, 35], fill=hexc("#ffcb3d")); d.ellipse([10, 17, 26, 31], fill=hexc("#ffe27a")); d.polygon([(18, 19), (20, 23), (24, 23), (21, 26), (22, 30), (18, 27), (14, 30), (15, 26), (12, 23), (16, 23)], fill=hexc("#e08a1e"))
    for fn, nm in ((star, "star"), (bolt, "bolt"), (heart, "heart"), (flame, "flame"), (boom, "boom"), (crown, "crown"), (sun, "sun"), (medal, "medal")):
        icon(fn, nm)

# ------------------------------------------------------------------ Zapfsäule (16x32 Einheiten = 48x96 px; Kopf getrennt: 16x12 = 48x36 px)
def pump():
    steel, steel_d, steel_h = hexc("#6f7fa8"), hexc("#3a4575"), hexc("#b8c4f0")
    amber, amber_d = hexc("#ffa530"), hexc("#b8631a")
    # Säulenkörper
    base = Image.new("RGBA", (48, 96), (0, 0, 0, 0)); d = ImageDraw.Draw(base)
    d.rectangle([12, 30, 35, 90], fill=steel)
    vgrad(d, (12, 30, 35, 90), steel_h[:3], steel_d[:3])
    d.rectangle([12, 30, 14, 90], fill=steel_h)                  # Glanzkante links
    d.rectangle([33, 30, 35, 90], fill=steel_d)
    for k in range(-24, 24, 12):                                  # Warnband oben
        d.polygon([(12 + k, 34), (18 + k, 34), (30 + k, 46), (24 + k, 46)], fill=amber)
    d.rectangle([12, 34, 35, 34], fill=OUTLINE); d.rectangle([12, 46, 35, 46], fill=OUTLINE)
    # Tropfen-Emblem
    d.polygon([(23, 54), (28, 64), (28, 68), (23, 72), (18, 68), (18, 64)], fill=amber)
    d.polygon([(23, 54), (28, 64), (23, 66)], fill=hexc("#ffdc8a"))
    d.rectangle([20, 62, 22, 66], fill=hexc("#fff0c0"))
    # Schlauch und Halterung rechts
    d.rectangle([35, 52, 44, 74], fill=steel_d)
    d.rectangle([37, 54, 42, 72], fill=OUTLINE)
    d.arc([36, 62, 52, 90], 270, 90, fill=hexc("#232a5a"), width=3)
    d.rectangle([38, 74, 43, 84], fill=hexc("#2a2e57")); d.rectangle([39, 82, 42, 88], fill=amber_d)
    # Sockel
    d.rectangle([5, 88, 42, 95], fill=hexc("#4a5596")); d.rectangle([5, 88, 42, 89], fill=steel_h)
    for x in (8, 22, 36):
        d.rectangle([x, 91, x + 2, 93], fill=hexc("#8d9be8"))
    for y in (38, 76):
        d.rectangle([14, y, 16, y + 2], fill=hexc("#8d9be8")); d.rectangle([31, y, 33, y + 2], fill=hexc("#8d9be8"))
    add_outline(base).save(OUT + "pump_base.png")
    # Kopf mit Preisanzeige (Pivot unten Mitte)
    head = Image.new("RGBA", (48, 36), (0, 0, 0, 0)); d = ImageDraw.Draw(head)
    d.rounded_rectangle([2, 6, 45, 33], radius=5, fill=steel)
    vgrad(d, (4, 8, 43, 31), steel_h[:3], steel_d[:3])
    d.rounded_rectangle([7, 11, 40, 27], radius=3, fill=hexc("#06140f"))
    d.rounded_rectangle([7, 11, 40, 27], radius=3, outline=hexc("#35e0d2"), width=1)
    d.rectangle([20, 1, 27, 6], fill=hexc("#ff4d6d")); d.rectangle([21, 2, 26, 4], fill=hexc("#ffb0c0"))
    d.rectangle([4, 28, 6, 30], fill=hexc("#8d9be8")); d.rectangle([41, 28, 43, 30], fill=hexc("#8d9be8"))
    d.rectangle([17, 32, 30, 35], fill=steel_d)
    add_outline(head).save(OUT + "pump_head.png")

# ------------------------------------------------------------------ Flaggen (120x80 = 40x26,7 Einheiten, Sprachwahl im Hauptmenü)
def flags():
    W, H = 120, 80
    def finish(im, name):
        # leichte Wellenschattierung + Rand mit abgerundeten Ecken
        a = np.array(im).astype(float)
        for x in range(W):
            k = 1.0 + 0.07 * np.sin(x / W * 2 * np.pi * 1.5)
            a[:, x, :3] *= k
        im = Image.fromarray(np.clip(a, 0, 255).astype(np.uint8))
        mask = Image.new("L", (W, H), 0); ImageDraw.Draw(mask).rounded_rectangle([0, 0, W - 1, H - 1], radius=6, fill=255)
        out = Image.new("RGBA", (W, H), (0, 0, 0, 0)); out.paste(im, (0, 0), mask)
        d = ImageDraw.Draw(out); d.rounded_rectangle([0, 0, W - 1, H - 1], radius=6, outline=hexc("#0c0f24"), width=2)
        d.line([6, 2, W - 7, 2], fill=(255, 255, 255, 90))
        out.save(OUT + name)
    # Deutschland
    de = Image.new("RGBA", (W, H)); d = ImageDraw.Draw(de)
    d.rectangle([0, 0, W, 27], fill=hexc("#111111")); d.rectangle([0, 27, W, 53], fill=hexc("#dd0000")); d.rectangle([0, 54, W, H], fill=hexc("#ffce00"))
    finish(de, "flag_de.png")
    # Union Jack (volle Fläche)
    def union_jack():
        im = Image.new("RGBA", (W, H), hexc("#012169")); d = ImageDraw.Draw(im)
        d.line([0, 0, W, H], fill=hexc("#ffffff"), width=13); d.line([0, H, W, 0], fill=hexc("#ffffff"), width=13)
        d.line([0, 0, W, H], fill=hexc("#c8102e"), width=5); d.line([0, H, W, 0], fill=hexc("#c8102e"), width=5)
        d.rectangle([0, H // 2 - 9, W, H // 2 + 9], fill=hexc("#ffffff")); d.rectangle([W // 2 - 9, 0, W // 2 + 9, H], fill=hexc("#ffffff"))
        d.rectangle([0, H // 2 - 5, W, H // 2 + 5], fill=hexc("#c8102e")); d.rectangle([W // 2 - 5, 0, W // 2 + 5, H], fill=hexc("#c8102e"))
        return im
    def stars_and_stripes():
        im = Image.new("RGBA", (W, H), hexc("#ffffff")); d = ImageDraw.Draw(im)
        for i in range(13):
            if i % 2 == 0:
                d.rectangle([0, int(i * H / 13), W, int((i + 1) * H / 13) - 1], fill=hexc("#b22234"))
        # Sternenfeld (vereinfacht) oben links (aufrecht) – diese Ecke liegt in der sichtbaren Hälfte
        d.rectangle([0, 0, 54, 40], fill=hexc("#3c3b6e"))
        for r in range(4):
            for c in range(5):
                cx, cy = 5 + c * 10 + (5 if r % 2 and c < 4 else 0), 5 + r * 9
                if r % 2 and c == 4:
                    continue
                d.rectangle([cx, cy, cx + 2, cy + 2], fill=hexc("#ffffff"))
        return im
    uk, us = union_jack(), stars_and_stripes()
    yy, xx = np.mgrid[0:H, 0:W]
    upper_left = (xx / W + yy / H) < 1.0
    en = Image.fromarray(np.where(upper_left[:, :, None], np.array(us), np.array(uk)).astype(np.uint8))          # USA oben links (aufrecht), Union Jack unten rechts
    d = ImageDraw.Draw(en); d.line([W, 0, 0, H], fill=hexc("#0c0f24"), width=2)
    finish(en, "flag_en.png")

# ------------------------------------------------------------------ Weltraum-Zwischensequenz
def space():
    W, H = 1920, 1080
    yy = np.linspace(0, 1, H)[:, None]
    top, bot = np.array([5, 6, 22]), np.array([30, 18, 70])
    base = top[None, None, :] + (bot - top)[None, None, :] * (yy ** 1.2)[:, :, None]
    base = np.repeat(base, W, axis=1)
    n1 = fbm(W, H, 31); n2 = fbm(W, H, 37)
    base += (np.clip((n1 - 0.42) * 2.4, 0, 1))[:, :, None] * np.array([85, 30, 110])[None, None, :] * 0.8
    base += (np.clip((n2 - 0.5) * 2.6, 0, 1))[:, :, None] * np.array([10, 85, 95])[None, None, :] * 0.55
    thr = np.tile(BAYER, (H // 4 + 1, W // 4 + 1))[:H, :W]
    q = np.floor(base / (255 / 24.0) + thr[:, :, None]) * (255 / 24.0)
    Image.fromarray(np.clip(q, 0, 255).astype(np.uint8)).convert("RGBA").save(OUT + "space_bg.png")
    def planet(name, light_dir, pal_a, pal_b, bands, ring, seed):
        S = 192; r = 78
        yy2, xx2 = np.mgrid[0:S, 0:S]
        cx = cy = S / 2
        dist = np.sqrt((xx2 - cx) ** 2 + (yy2 - cy) ** 2)
        inside = dist <= r
        light = np.clip(((xx2 - cx) * light_dir[0] + (yy2 - cy) * light_dir[1]) / r * 0.5 + 0.55, 0, 1)
        band = np.sin((yy2 - cy) / bands + fbm(S, S, seed, 4) * 5) * 0.5 + 0.5
        col = np.array(pal_a)[None, None, :] * (1 - band[:, :, None] * 0.5) + np.array(pal_b)[None, None, :] * band[:, :, None] * 0.5
        col = col * (0.22 + 0.9 * light[:, :, None])
        th = np.tile(BAYER, (S // 4 + 1, S // 4 + 1))[:S, :S]
        col = np.floor(col / 16.0 + th[:, :, None]) * 16.0
        im = Image.new("RGBA", (S, S), (0, 0, 0, 0)); ar = np.array(im)
        ar[inside, :3] = np.clip(col, 0, 255).astype(np.uint8)[inside]; ar[inside, 3] = 255
        im = Image.fromarray(ar); d = ImageDraw.Draw(im)
        # Kantenaufhellung (Atmosphäre)
        rim = Image.new("RGBA", (S, S), (0, 0, 0, 0)); rd = ImageDraw.Draw(rim)
        rd.ellipse([cx - r - 1, cy - r - 1, cx + r + 1, cy + r + 1], outline=hexc("#bfe8ff", 90), width=2)
        im.alpha_composite(rim)
        if ring:
            rg = Image.new("RGBA", (S, S), (0, 0, 0, 0)); gd = ImageDraw.Draw(rg)
            for k, c in enumerate((hexc("#e8d9b0", 200), hexc("#b89a70", 170))):
                gd.ellipse([8 - k * 3, cy - 14 - k * 2, S - 8 + k * 3, cy + 14 + k * 2], outline=c, width=3)
            im.alpha_composite(rg)
        im.save(OUT + name)
    planet("planet_1.png", (-0.6, -0.5), (90, 180, 210), (40, 90, 150), 9.0, True, 41)
    planet("planet_2.png", (0.6, -0.4), (120, 170, 90), (150, 110, 70), 7.0, False, 43)
    planet("planet_3.png", (-0.5, 0.5), (230, 120, 110), (140, 50, 90), 12.0, False, 47)

if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    for f in ("tiles", "tiles_normal", "shelter", "gate", "taxi_skins", "stickers", "background", "space", "flags", "pump"):
        globals()[f]()
    print("Assets geschrieben nach", OUT)
