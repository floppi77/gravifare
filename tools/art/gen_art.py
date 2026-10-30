"""Erzeugt die Pixel-Art-Assets (Sektor 1 Sternenhafen, Taxi, Fahrgäste, Ausgangstor, Hintergründe).
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

# ------------------------------------------------------------------ Taxi
def taxi():
    W, H = 96, 60
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    yl, yd, ydd, yh = hexc("#ffcb3d"), hexc("#e8901f"), hexc("#b8631a"), hexc("#fff3b0")
    mt, md, mh = hexc("#7a80a8"), hexc("#3d4166"), hexc("#b8bfe6")
    # Seitenpods
    for ox, flip in ((1, 1), (83, -1)):
        d.rounded_rectangle([ox, 20, ox + 11, 40], radius=4, fill=md)
        vgrad(d, (ox + 1, 22, ox + 10, 38), mh[:3], md[:3])
        for k in range(3): d.line([ox + 2, 25 + k * 4, ox + 9, 25 + k * 4], fill=md)
    d.rectangle([0, 26, 2, 34], fill=OUTLINE); d.rectangle([93, 26, 95, 34], fill=OUTLINE)
    # Düse unten
    d.rounded_rectangle([32, 44, 63, 55], radius=3, fill=md)
    vgrad(d, (34, 45, 61, 52), mh[:3], md[:3])
    d.rectangle([40, 52, 55, 56], fill=OUTLINE); d.rectangle([42, 52, 53, 54], fill=hexc("#22254a"))
    # Rumpf
    d.rounded_rectangle([8, 14, 87, 46], radius=15, fill=yl)
    body_mask = Image.new("L", (W, H), 0); ImageDraw.Draw(body_mask).rounded_rectangle([8, 14, 87, 46], radius=15, fill=255)
    shade_layer = Image.new("RGBA", (W, H), (0, 0, 0, 0)); sd = ImageDraw.Draw(shade_layer)
    sd.rectangle([0, 33, W, 40], fill=yd); sd.rectangle([0, 41, W, H], fill=ydd)
    sd.rectangle([0, 14, W, 16], fill=yh)
    img.paste(shade_layer, (0, 0), Image.composite(shade_layer.split()[3], Image.new("L", (W, H), 0), body_mask))
    d = ImageDraw.Draw(img)
    d.arc([8, 14, 87, 46], 195, 345, fill=hexc("#ffe27a"), width=1)
    # Schachbrettband
    for i, x in enumerate(range(14, 82, 4)):
        d.rectangle([x, 31, x + 3, 33], fill=OUTLINE if i % 2 else hexc("#ffffff"))
        d.rectangle([x, 34, x + 3, 36], fill=hexc("#ffffff") if i % 2 else OUTLINE)
    # Heckflossen / Lampen
    d.polygon([(8, 22), (2, 16), (2, 26), (8, 30)], fill=yd); d.polygon([(87, 22), (93, 16), (93, 26), (87, 30)], fill=yd)
    d.rectangle([11, 20, 14, 23], fill=hexc("#ff4d6d")); d.rectangle([81, 20, 84, 23], fill=hexc("#5dff9a"))
    # Kuppel
    dome = Image.new("RGBA", (W, H), (0, 0, 0, 0)); dd = ImageDraw.Draw(dome)
    dd.rounded_rectangle([29, 2, 66, 28], radius=13, fill=OUTLINE)
    dd.rounded_rectangle([31, 4, 64, 27], radius=11, fill=hexc("#6fe8ea"))
    vgrad(dd, (33, 6, 62, 26), hexc("#c8fffd")[:3], hexc("#2a9fb0")[:3])
    m = Image.new("L", (W, H), 0); ImageDraw.Draw(m).rounded_rectangle([31, 4, 64, 27], radius=11, fill=255)
    glass = Image.new("RGBA", (W, H), (0, 0, 0, 0)); gd = ImageDraw.Draw(glass)
    vgrad(gd, (31, 4, 64, 27), hexc("#bdfcfb")[:3], hexc("#2a8fa8")[:3])
    dome.paste(glass, (0, 0), m)
    dd = ImageDraw.Draw(dome)
    # Fahrer: Kopf, Mütze
    dd.ellipse([44, 12, 53, 21], fill=hexc("#f2c29b")); dd.rectangle([46, 15, 47, 16], fill=OUTLINE); dd.rectangle([50, 15, 51, 16], fill=OUTLINE)
    dd.rectangle([43, 10, 54, 13], fill=hexc("#ff7a2e")); dd.rectangle([43, 13, 56, 14], fill=hexc("#c9561a"))
    dd.polygon([(38, 8), (46, 5), (44, 12), (36, 14)], fill=hexc("#ffffff"))  # Spiegelung
    dd.line([36, 8, 42, 6], fill=hexc("#ffffff"))
    dd.line([33, 25, 62, 25], fill=hexc("#1f7f92"))
    img.alpha_composite(dome)
    img = add_outline(img)
    # Zusatzkontur Rumpfunterkante
    d = ImageDraw.Draw(img)
    d.arc([8, 14, 87, 46], 20, 160, fill=shade(ydd, 0.75), width=1)
    img.save(OUT + "taxi.png")

# ------------------------------------------------------------------ Fahrgäste (24x36 je Frame)
# Sheet: 4 Figuren (Zeilen) x 10 Frames: 0-1 Idle, 2-3 Winken, 4-9 Laufzyklus (blickt nach rechts)
LOOKS = [  # Haut, Kleidung, Haar, Highlight, weiblich?
    ("#f2c29b", "#d9467f", "#3a2a52", "#ffd0e8", True),
    ("#a8714f", "#3fb68b", "#1c1c30", "#b9ffe0", False),
    ("#e9b58c", "#e8a33a", "#552a1c", "#fff0b0", False),
    ("#8fd0c8", "#7a6bd8", "#22223d", "#d9d2ff", True),
]
PANTS, SHOE = hexc("#43529c"), hexc("#10142b")

def person(i, pose, k=0):
    """pose: 'idle' (k=0/1), 'wave' (k=0/1), 'walk' (k=0..5)."""
    skin, cloth, hair, hi, fem = LOOKS[i]
    sk, cl, hr = hexc(skin), hexc(cloth), hexc(hair)
    f = Image.new("RGBA", (24, 36), (0, 0, 0, 0)); d = ImageDraw.Draw(f)
    if pose == "walk":
        ph = k / 6.0 * 2 * np.pi
        bob = int(round(abs(np.sin(ph)) * 1.2))
        sw = np.sin(ph)
        hx = 12
        top = 14 + bob
        # hintere Gliedmaßen zuerst (dunkler)
        def limb(x0, y0, ang, ln, col, w):
            x1, y1 = x0 + np.sin(ang) * ln, y0 + np.cos(ang) * ln
            d.line([x0, y0, x1, y1], fill=col, width=w)
            return int(x1), int(y1)
        back_leg = limb(hx, 27 + bob, -sw * 0.65, 9, shade(PANTS, 0.75), 4)
        back_arm = limb(hx, top + 2, sw * 0.6, 9, shade(cl, 0.75), 3)
        d.rectangle([back_leg[0] - 1, back_leg[1] - 1, back_leg[0] + 3, back_leg[1] + 1], fill=SHOE)
        # Torso (Seitenansicht)
        d.rounded_rectangle([hx - 4, top, hx + 4, 28 + bob], radius=3, fill=cl)
        d.rectangle([hx - 4, 23 + bob, hx + 4, 28 + bob], fill=shade(cl, 0.82))
        if fem: d.polygon([(hx - 5, 27 + bob), (hx + 5, 27 + bob), (hx + 6, 30 + bob), (hx - 6, 30 + bob)], fill=shade(cl, 0.9))
        front_leg = limb(hx, 27 + bob, sw * 0.65, 9, PANTS, 4)
        d.rectangle([front_leg[0] - 1, front_leg[1] - 1, front_leg[0] + 4, front_leg[1] + 1], fill=SHOE)
        # Kopf im Profil, Blick nach rechts
        d.ellipse([hx - 4, 2 + bob, hx + 5, 13 + bob], fill=sk)
        d.rectangle([hx + 3, 7 + bob, hx + 5, 8 + bob], fill=shade(sk, 0.85))      # Nase
        d.point((hx + 3, 6 + bob), fill=SHOE)
        d.pieslice([hx - 5, 0 + bob, hx + 5, 11 + bob], 180, 360, fill=hr)
        d.rectangle([hx - 5, 4 + bob, hx - 3, (14 if fem else 9) + bob], fill=hr)
        if i == 3: d.ellipse([hx - 7, 0 + bob, hx - 3, 4 + bob], fill=hr)
        front_arm = limb(hx, top + 2, -sw * 0.6, 9, cl, 3)
        d.rectangle([front_arm[0] - 1, front_arm[1] - 1, front_arm[0] + 1, front_arm[1] + 1], fill=sk)
        if i == 1: d.rectangle([front_arm[0] - 2, front_arm[1] + 1, front_arm[0] + 3, front_arm[1] + 7], fill=hexc("#6a4a2a"))
    else:
        yoff = 1 if (pose == "idle" and k == 1) else 0
        d.rounded_rectangle([6, 14 + yoff, 17, 28], radius=3, fill=cl)
        d.rectangle([6, 22, 17, 28], fill=shade(cl, 0.82)); d.line([7, 15 + yoff, 16, 15 + yoff], fill=hexc(hi))
        if fem: d.polygon([(5, 27), (18, 27), (20, 31), (3, 31)], fill=shade(cl, 0.9))
        d.rectangle([8, 28, 11, 35], fill=PANTS); d.rectangle([12, 28, 15, 35], fill=PANTS)
        d.rectangle([7, 34, 11, 35], fill=SHOE); d.rectangle([12, 34, 16, 35], fill=SHOE)
        if pose == "wave":
            up = 0 if k == 0 else 2
            d.rectangle([3, 15, 5, 25], fill=cl); d.rectangle([3, 25, 5, 27], fill=sk)          # linker Arm unten
            d.polygon([(18, 16), (21 + up, 6), (24 if up else 23, 6), (20, 17)], fill=cl)       # rechter Arm hoch
            d.rectangle([20 + up, 3, 23 + up, 6], fill=sk)
        else:
            d.rectangle([3, 15, 5, 25], fill=cl); d.rectangle([18, 15, 20, 25], fill=cl)
            d.rectangle([3, 25, 5, 27], fill=sk); d.rectangle([18, 25, 20, 27], fill=sk)
        d.ellipse([6, 2 + yoff, 17, 14 + yoff], fill=sk)
        d.pieslice([5, 0 + yoff, 18, 12 + yoff], 180, 360, fill=hr); d.rectangle([5, 5 + yoff, 7, (13 if fem else 9) + yoff], fill=hr)
        if fem: d.rectangle([16, 5 + yoff, 18, 13 + yoff], fill=hr)
        if i == 3: d.ellipse([9, -1 + yoff, 14, 3 + yoff], fill=hr)
        blink = pose == "idle" and k == 1
        if blink:
            d.line([9, 8 + yoff, 10, 8 + yoff], fill=OUTLINE); d.line([13, 8 + yoff, 14, 8 + yoff], fill=OUTLINE)
        else:
            d.rectangle([9, 8 + yoff, 10, 9 + yoff], fill=OUTLINE); d.rectangle([13, 8 + yoff, 14, 9 + yoff], fill=OUTLINE)
        d.line([10, 12 + yoff, 13, 12 + yoff], fill=shade(sk, 0.7))
        if pose == "wave": d.rectangle([11, 11 + yoff, 12, 11 + yoff], fill=hexc("#7a2a3a"))
        if i == 1 and pose != "wave": d.rectangle([19, 25, 23, 32], fill=hexc("#6a4a2a")); d.rectangle([19, 25, 23, 26], fill=hexc("#a07a3a"))
    return add_outline(f)

def passengers():
    frames = [("idle", 0), ("idle", 1), ("wave", 0), ("wave", 1)] + [("walk", k) for k in range(6)]
    img = Image.new("RGBA", (24 * len(frames), 36 * len(LOOKS)), (0, 0, 0, 0))
    for i in range(len(LOOKS)):
        for j, (pose, k) in enumerate(frames):
            img.alpha_composite(person(i, pose, k), (j * 24, i * 36))
    img.save(OUT + "passengers.png")

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
        # Sternenfeld (vereinfacht) unten rechts, damit es in der sichtbaren Hälfte liegt
        d.rectangle([W - 54, H - 40, W, H], fill=hexc("#3c3b6e"))
        for r in range(4):
            for c in range(5):
                cx, cy = W - 48 + c * 10 + (5 if r % 2 else 0), H - 34 + r * 9
                d.rectangle([cx, cy, cx + 2, cy + 2], fill=hexc("#ffffff"))
        return im
    uk, us = union_jack(), stars_and_stripes()
    yy, xx = np.mgrid[0:H, 0:W]
    upper_left = (xx / W + yy / H) < 1.0
    en = Image.fromarray(np.where(upper_left[:, :, None], np.array(uk), np.array(us)).astype(np.uint8))
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
    for f in ("tiles", "taxi", "passengers", "shelter", "gate", "background", "space", "flags"):
        globals()[f]()
    print("Assets geschrieben nach", OUT)
