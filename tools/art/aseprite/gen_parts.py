"""Grundformen für Taxi und Fahrgäste als Vorlage für die Aseprite-Überarbeitung (siehe README.md hier im Ordner).
Schreibt flache Materialflächen und Detail-Ebenen nach build/aseprite-workspace/gf_polish/ (nie nach assets/).
Aufruf aus der Projektwurzel: python3 tools/art/aseprite/gen_parts.py ."""
import os, sys, math
from PIL import Image, ImageDraw

ROOT = sys.argv[1] if len(sys.argv) > 1 else "."
OUT = os.path.join(ROOT, "build/aseprite-workspace/gf_polish/")
os.makedirs(OUT, exist_ok=True)

def hexc(h, a=255):
    h = h.lstrip("#"); return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), a)

OL = hexc("#0c0f24")

# ================================================================ TAXI (96x60)
W, H = 96, 60
BODY, METAL, GLASS = hexc("#ffcb3d"), hexc("#7a80a8"), hexc("#6fe8ea")

# --- Ebene "hull": Rumpf (flach), wird in Aseprite schattiert
hull = Image.new("RGBA", (W, H)); d = ImageDraw.Draw(hull)
d.rounded_rectangle([8, 14, 87, 46], radius=15, fill=BODY)
hull.save(OUT + "taxi_hull.png")

# --- Ebene "metal": Seitenpods + Düse (flach)
metal = Image.new("RGBA", (W, H)); d = ImageDraw.Draw(metal)
for ox in (1, 83):
    d.rounded_rectangle([ox, 20, ox + 11, 40], radius=4, fill=METAL)
d.rounded_rectangle([32, 43, 63, 55], radius=4, fill=METAL)
metal.save(OUT + "taxi_metal.png")

# --- Ebene "glass": Kuppelglas (flach)
glass = Image.new("RGBA", (W, H)); d = ImageDraw.Draw(glass)
d.rounded_rectangle([31, 4, 64, 27], radius=11, fill=GLASS)
glass.save(OUT + "taxi_glass.png")

# --- Ebene "fins": Heckflossen, von Hand zweitonig (zu schmal zum Schattieren)
fins = Image.new("RGBA", (W, H)); d = ImageDraw.Draw(fins)
fin_l, fin_d, fin_h = hexc("#e8901f"), hexc("#b8631a"), hexc("#ffcb3d")
d.polygon([(8, 22), (2, 15), (2, 26), (8, 30)], fill=fin_l)
d.polygon([(87, 22), (93, 15), (93, 26), (87, 30)], fill=fin_l)
d.polygon([(8, 26), (2, 22), (2, 26), (8, 30)], fill=fin_d)
d.polygon([(87, 26), (93, 22), (93, 26), (87, 30)], fill=fin_d)
d.line([2, 15, 7, 21], fill=fin_h); d.line([93, 15, 88, 21], fill=fin_h)
fins.save(OUT + "taxi_fins.png")

# --- Ebene "detail": alles, was über der Schattierung liegt
det = Image.new("RGBA", (W, H)); d = ImageDraw.Draw(det)
WHITE, GREY = hexc("#ffffff"), hexc("#c9cfee")
# Zierleiste + Schachbrettband (vertieft: Licht oben, Schatten unten)
d.line([12, 30, 83, 30], fill=hexc("#9c4a1a"))
d.line([12, 37, 83, 37], fill=hexc("#ffe066"))
for i, x in enumerate(range(13, 82, 4)):
    edge = x < 18 or x > 76
    w = GREY if edge else WHITE
    k = hexc("#1b1f3d")
    d.rectangle([x, 31, x + 3, 33], fill=k if i % 2 else w)
    d.rectangle([x, 34, x + 3, 36], fill=w if i % 2 else k)
# Positionslampen mit Glanzpunkt
for (x, c, cl, hi) in ((11, "#ff4d6d", "#b82a48", "#ffd0da"), (81, "#5dff9a", "#22b862", "#e0ffe9")):
    d.rectangle([x, 20, x + 3, 23], fill=hexc(c)); d.line([x, 23, x + 3, 23], fill=hexc(cl))
    d.point((x + 1, 21), fill=hexc(hi))
# Pods: Rillen, Nieten, Abgasöffnung mit Kühlglühen
for ox, port in ((1, 0), (83, 93)):
    for k in range(3):
        d.line([ox + 2, 25 + k * 4, ox + 9, 25 + k * 4], fill=hexc("#3d4166"))
        d.line([ox + 2, 26 + k * 4, ox + 9, 26 + k * 4], fill=hexc("#9aa1cc"))
    d.rectangle([port, 26, port + 2, 34], fill=OL)
    gx = port + (0 if port == 0 else 2)
    d.line([gx, 28, gx, 32], fill=hexc("#4fb8e8")); d.point((gx, 30), fill=hexc("#c8f0ff"))
# Düse: Ring, dunkle Öffnung, rote Restglut (Farbton < 0.04, bleibt bei Lackierungen gleich)
d.line([33, 48, 62, 48], fill=hexc("#3d4166"))
d.line([33, 47, 62, 47], fill=hexc("#b8bfe6"))
d.rectangle([40, 52, 55, 56], fill=OL); d.rectangle([42, 52, 53, 54], fill=hexc("#22254a"))
d.line([43, 54, 52, 54], fill=hexc("#8a2a2a")); d.line([45, 54, 50, 54], fill=hexc("#e8452c"))
for x in (36, 59):
    d.point((x, 51), fill=hexc("#e6eaff")); d.point((x, 52), fill=hexc("#3d4166"))
# Kuppelrahmen (Chromring) + Kontur
d.rounded_rectangle([29, 2, 66, 28], radius=13, outline=OL)
d.rounded_rectangle([30, 3, 65, 28], radius=12, outline=hexc("#1f2a50"))
det.save(OUT + "taxi_detail.png")

# --- Ebene "driver": Fahrer + Spiegelungen (über dem Glas)
drv = Image.new("RGBA", (W, H)); d = ImageDraw.Draw(drv)
SK, SKD, SKH = hexc("#f2c29b"), hexc("#d9a585"), hexc("#ffe0c4")
UNI, UNID = hexc("#2d3a7a"), hexc("#1f2856")
# Schultern / Uniform mit Kragen
d.rounded_rectangle([39, 20, 57, 27], radius=4, fill=UNI)
d.line([39, 26, 57, 26], fill=UNID)
d.polygon([(45, 20), (48, 24), (51, 20)], fill=hexc("#e6eaff"))
d.point((48, 22), fill=hexc("#ff4d6d")); d.point((48, 23), fill=hexc("#ff4d6d"))  # Fliege
# Kopf
d.ellipse([43, 10, 53, 20], fill=SK)
d.line([44, 19, 52, 19], fill=SKD); d.point((43, 15), fill=SKD); d.point((53, 15), fill=SKD)
d.point((45, 12), fill=SKH)
d.rectangle([45, 14, 46, 15], fill=OL); d.rectangle([50, 14, 51, 15], fill=OL)
d.point((45, 14), fill=hexc("#ffffff")); d.point((50, 14), fill=hexc("#ffffff"))
d.point((44, 17), fill=hexc("#f59a9a")); d.point((52, 17), fill=hexc("#f59a9a"))
d.line([47, 17, 49, 17], fill=hexc("#8a3a3a")); d.point((46, 16), fill=hexc("#8a3a3a")); d.point((50, 16), fill=hexc("#8a3a3a"))
# Mütze mit Schirm und Plakette
d.rounded_rectangle([42, 6, 54, 11], radius=2, fill=hexc("#ff7a2e"))
d.line([43, 7, 53, 7], fill=hexc("#ffa060"))
d.rectangle([41, 11, 55, 12], fill=hexc("#c9561a")); d.line([41, 12, 55, 12], fill=hexc("#8a3410"))
d.rectangle([47, 8, 49, 9], fill=hexc("#fff3b0")); d.point((48, 9), fill=hexc("#1b1f3d"))
# Spiegelungen
for (x0, y0, x1, y1) in ((35, 12, 41, 6), (36, 13, 42, 7), (38, 14, 39, 13)):
    d.line([x0, y0, x1, y1], fill=(255, 255, 255, 220))
d.line([44, 5, 50, 5], fill=(255, 255, 255, 140))
d.point((60, 9), fill=(255, 255, 255, 200)); d.point((61, 10), fill=(255, 255, 255, 200))
d.line([33, 25, 62, 25], fill=hexc("#1f7f92"))
drv.save(OUT + "taxi_driver.png")
print("taxi parts ok")

# ================================================================ FAHRGÄSTE (Streifen 240x36 je Look)
# Look: Haut, Kleidung, Haar, weiblich?, Extra
LOOKS = [
    dict(skin="#f2c29b", cloth="#d9467f", hair="#3a2a52", hair_hi="#6a4a8c", fem=True, extra="clip"),
    dict(skin="#a8714f", cloth="#3fb68b", hair="#1c1c30", hair_hi="#3a3a5c", fem=False, extra="case"),
    dict(skin="#e9b58c", cloth="#e8a33a", hair="#552a1c", hair_hi="#8a4a2c", fem=False, extra="cap"),
    dict(skin="#8fd0c8", cloth="#7a6bd8", hair="#22223d", hair_hi="#40406a", fem=True, extra="antenna"),
]
PANTS, PANTS_D, SHOE, SHOE_H = hexc("#43529c"), hexc("#2f3a75"), hexc("#10142b"), hexc("#3a4170")

def sh(c, f):
    return tuple(max(0, min(255, int(v * f))) for v in c[:3]) + (255,)

def ik(hip, foot, l1, l2, bend=1):
    """Knie für zweiteiliges Bein, Knie zeigt nach vorn (rechts)."""
    hx, hy = hip; fx, fy = foot
    dx, dy = fx - hx, fy - hy; dist = min(math.hypot(dx, dy), l1 + l2 - 0.01)
    a = math.atan2(dy, dx)
    c = (l1 * l1 + dist * dist - l2 * l2) / (2 * l1 * dist)
    b = math.acos(max(-1, min(1, c)))
    ang = a - b * bend
    return (hx + math.cos(ang) * l1, hy + math.sin(ang) * l1)

def thick(d, pts, col, w):
    for p, q in zip(pts, pts[1:]):
        d.line([p, q], fill=col, width=w)
    for p in pts:
        r = (w - 1) / 2
        d.ellipse([p[0] - r, p[1] - r, p[0] + r, p[1] + r], fill=col)

def person_front(L, pose, k):
    """Basisfarben flach (Kleidung, Haut) für Aseprite-Schattierung + feste Details."""
    sk, cl, hr, hh = hexc(L["skin"]), hexc(L["cloth"]), hexc(L["hair"]), hexc(L["hair_hi"])
    f = Image.new("RGBA", (24, 36)); d = ImageDraw.Draw(f)
    y = 1 if (pose == "idle" and k == 1) else 0
    # Beine + Schuhe
    if L["fem"]:
        d.rectangle([8, 29, 10, 33], fill=sh(sk, 0.9)); d.rectangle([13, 29, 15, 33], fill=sh(sk, 0.9))
    else:
        d.rectangle([8, 28, 11, 33], fill=PANTS); d.rectangle([12, 28, 15, 33], fill=PANTS)
        d.line([11, 28, 11, 33], fill=PANTS_D); d.line([15, 29, 15, 33], fill=PANTS_D)
    d.rectangle([7, 33, 11, 35], fill=SHOE); d.rectangle([12, 33, 16, 35], fill=SHOE)
    d.line([8, 33, 10, 33], fill=SHOE_H); d.line([13, 33, 15, 33], fill=SHOE_H)
    # Rumpf (flach, wird schattiert)
    d.rounded_rectangle([6, 14 + y, 17, 28], radius=3, fill=cl)
    if L["fem"]:
        d.polygon([(6, 24), (17, 24), (19, 30), (4, 30)], fill=cl)
    # Arme
    sleeve = sh(cl, 0.8)
    if pose == "wave":
        up = 0 if k == 0 else 1
        d.rectangle([3, 15 + y, 5, 25], fill=sleeve); d.rectangle([3, 25, 5, 27], fill=sk)
        thick(d, [(18.5, 16.5), (20 + up, 9)], sleeve, 3)
        d.rectangle([19 + up, 4, 22, 7], fill=sk); d.point((19 + up, 4), fill=(0, 0, 0, 0))
    else:
        d.rectangle([3, 15 + y, 5, 25], fill=sleeve); d.rectangle([18, 15 + y, 20, 25], fill=sleeve)
        d.rectangle([3, 25, 5, 27], fill=sk); d.rectangle([18, 25, 20, 27], fill=sk)
    # Kopf (flach)
    d.ellipse([6, 2 + y, 17, 14 + y], fill=sk)
    return f

def person_front_top(L, pose, k):
    """Details über der Schattierung: Haare, Gesicht, Accessoires."""
    sk, cl, hr, hh = hexc(L["skin"]), hexc(L["cloth"]), hexc(L["hair"]), hexc(L["hair_hi"])
    f = Image.new("RGBA", (24, 36)); d = ImageDraw.Draw(f)
    y = 1 if (pose == "idle" and k == 1) else 0
    # Kragen
    d.line([9, 14 + y, 14, 14 + y], fill=sh(cl, 1.25) if L["extra"] != "case" else hexc("#e6eaff"))
    if L["extra"] == "case":
        d.line([11, 15 + y, 11, 26], fill=hexc("#e6eaff")); d.line([12, 15 + y, 12, 26], fill=hexc("#c9cfee"))
        d.line([10, 15 + y, 10, 24], fill=sh(cl, 0.75)); d.line([13, 15 + y, 13, 24], fill=sh(cl, 0.75))
    if L["extra"] == "cap":   # Hoodie-Tasche + Kordeln
        d.line([8, 23, 15, 23], fill=sh(cl, 0.7)); d.point((10, 16 + y), fill=hexc("#fff0b0")); d.point((13, 16 + y), fill=hexc("#fff0b0"))
    if L["fem"]:
        d.line([5, 29, 18, 29], fill=sh(cl, 0.7))
    # Haare
    if L["extra"] == "cap":
        d.pieslice([5, 0 + y, 18, 12 + y], 180, 360, fill=hexc("#3fa0d8"))
        d.line([7, 1 + y, 13, 1 + y], fill=hexc("#8fd8ff"))
        d.rectangle([5, 5 + y, 19, 6 + y], fill=hexc("#2a6fa0"))
        d.rectangle([5, 7 + y, 6, 9 + y], fill=hr); d.rectangle([17, 7 + y, 18, 8 + y], fill=hr)
    else:
        d.pieslice([5, 0 + y, 18, 12 + y], 180, 360, fill=hr)
        d.rectangle([5, 5 + y, 7, (14 if L["fem"] else 9) + y], fill=hr)
        if L["fem"]:
            d.rectangle([16, 5 + y, 18, 14 + y], fill=hr)
            d.polygon([(7, 5 + y), (12, 5 + y), (8, 8 + y)], fill=hr)   # Pony
        else:
            d.polygon([(10, 5 + y), (16, 5 + y), (16, 7 + y)], fill=hr)
        d.line([8, 1 + y, 12, 1 + y], fill=hh); d.point((7, 2 + y), fill=hh)
    if L["extra"] == "clip":
        d.rectangle([15, 3 + y, 16, 4 + y], fill=hexc("#ffe14a"))
    if L["extra"] == "antenna":
        for ax, tx in ((9, 7), (14, 16)):
            d.line([ax, 2 + y, tx, 1 + y], fill=hexc("#22223d"))
        d.rectangle([6, 0 + y, 7, 1 + y], fill=hexc("#b6ff6a")); d.rectangle([16, 0 + y, 17, 1 + y], fill=hexc("#b6ff6a"))
        d.point((6, 0 + y), fill=hexc("#f0ffd0")); d.point((16, 0 + y), fill=hexc("#f0ffd0"))
    # Gesicht
    blink = pose == "idle" and k == 1
    if blink:
        d.line([9, 9 + y, 10, 9 + y], fill=OL); d.line([13, 9 + y, 14, 9 + y], fill=OL)
    else:
        d.rectangle([9, 8 + y, 10, 9 + y], fill=OL); d.rectangle([13, 8 + y, 14, 9 + y], fill=OL)
        d.point((9, 8 + y), fill=hexc("#ffffff")); d.point((13, 8 + y), fill=hexc("#ffffff"))
    blush = sh(hexc("#f07a8a"), 1.0) if L["extra"] != "antenna" else hexc("#5fb0c8")
    d.point((8, 11 + y), fill=blush); d.point((15, 11 + y), fill=blush)
    mouth = sh(sk, 0.55)
    if pose == "wave":
        d.rectangle([11, 11 + y, 12, 12 + y], fill=hexc("#7a2a3a"))
    else:
        d.line([11, 12 + y, 12, 12 + y], fill=mouth); d.point((10, 11 + y), fill=mouth); d.point((13, 11 + y), fill=mouth)
    if L["extra"] == "case" and pose != "wave":
        d.rectangle([18, 26, 23, 33], fill=hexc("#7a4a2a")); d.line([18, 26, 23, 26], fill=hexc("#a8703c"))
        d.line([18, 30, 23, 30], fill=hexc("#c9a060")); d.line([18, 33, 23, 33], fill=hexc("#4a2a18"))
        d.rectangle([20, 24, 21, 25], fill=hexc("#3a2a18"))
    return f

def person_walk(L, k, top_layer):
    sk, cl, hr, hh = hexc(L["skin"]), hexc(L["cloth"]), hexc(L["hair"]), hexc(L["hair_hi"])
    f = Image.new("RGBA", (24, 36)); d = ImageDraw.Draw(f)
    ph = k / 6.0 * 2 * math.pi
    bob = 1 if k in (1, 4) else 0           # Passierphase höher
    hip = (11.5, 25 + bob)
    def foot(p):
        x = 11.5 + math.cos(p) * 4.5
        lift = max(0.0, math.sin(p)) * 2.6
        return (x, 34.5 - lift)
    legs = [(foot(ph + math.pi), PANTS_D if not L["fem"] else sh(sk, 0.75), SHOE),
            (foot(ph), PANTS if not L["fem"] else sh(sk, 0.9), SHOE)]
    arm_sw = math.cos(ph) * 3.0
    sleeve, sleeve_d = sh(cl, 0.8), sh(cl, 0.62)
    shoulder = (11.5, 16.5 + bob)
    def arm(sw, col, hand):
        el = (shoulder[0] - sw * 0.5, shoulder[1] + 4.5)
        hd = (shoulder[0] - sw, shoulder[1] + 8.5)
        thick(d, [shoulder, el, hd], col, 3)
        if col == sleeve:
            d.line([(shoulder[0] + 1.5, shoulder[1] + 1), (el[0] + 1.5, el[1]), (hd[0] + 1.5, hd[1] - 1)], fill=sleeve_d)
        d.rectangle([round(hd[0]) - 1, round(hd[1]), round(hd[0]) + 1, round(hd[1]) + 1], fill=hand)
        return hd
    if not top_layer:
        # hinterer Arm, hinteres Bein
        if L["extra"] == "case":
            hd = arm(4.2 + math.cos(ph) * 0.6, sleeve_d, sh(sk, 0.8))
            hx, hy = round(hd[0]), round(hd[1])
            d.rectangle([hx - 4, hy + 2, hx + 1, hy + 8], fill=hexc("#6a3e22")); d.line([hx - 4, hy + 2, hx + 1, hy + 2], fill=hexc("#94602f"))
            d.line([hx - 4, hy + 5, hx + 1, hy + 5], fill=hexc("#b08a50")); d.line([hx - 4, hy + 8, hx + 1, hy + 8], fill=hexc("#40241a"))
            d.rectangle([hx - 1, hy + 1, hx, hy + 1], fill=hexc("#3a2a18"))
        else:
            arm(-arm_sw, sleeve_d, sh(sk, 0.8))
        for i, (ft, col, shoe) in enumerate(legs):
            kn = ik(hip, ft, 5.0, 5.2)
            thick(d, [hip, kn, ft], col, 3)
            fx, fy = round(ft[0]), round(ft[1])
            d.rectangle([fx - 1, fy - 1, fx + 2, fy], fill=shoe)
            if i == 1: d.point((fx, fy - 1), fill=SHOE_H)
        # Rumpf seitlich (flach -> wird schattiert)
        d.rounded_rectangle([8, 14 + bob, 15, 28 + bob], radius=3, fill=cl)
        if L["fem"]:
            d.polygon([(8, 24 + bob), (15, 24 + bob), (17, 30 + bob), (6, 30 + bob)], fill=cl)
        # Kopf im Profil
        d.ellipse([7, 2 + bob, 17, 14 + bob], fill=sk)
        d.rectangle([16, 7 + bob, 17, 9 + bob], fill=sk)       # Nase
        return f
    # ---- obere Ebene: Haare, Auge, vorderer Arm, Gepäck
    if L["extra"] == "cap":
        d.pieslice([6, 0 + bob, 17, 12 + bob], 180, 360, fill=hexc("#3fa0d8"))
        d.line([8, 1 + bob, 13, 1 + bob], fill=hexc("#8fd8ff"))
        d.rectangle([7, 5 + bob, 20, 6 + bob], fill=hexc("#2a6fa0"))
        d.rectangle([6, 7 + bob, 8, 10 + bob], fill=hr)
    else:
        d.pieslice([6, 0 + bob, 17, 12 + bob], 180, 360, fill=hr)
        d.rectangle([6, 4 + bob, 9, (14 if L["fem"] else 10) + bob], fill=hr)
        if L["fem"]:
            d.polygon([(6, 6 + bob), (9, 6 + bob), (7, 16 + bob), (5, 15 + bob)], fill=hr)
        d.polygon([(12, 5 + bob), (17, 5 + bob), (17, 6 + bob)], fill=hr)
        d.line([9, 1 + bob, 13, 1 + bob], fill=hh)
    if L["extra"] == "clip":
        d.rectangle([9, 3 + bob, 10, 4 + bob], fill=hexc("#ffe14a"))
    if L["extra"] == "antenna":
        d.line([11, 2 + bob, 9, 0 + bob], fill=hexc("#22223d")); d.line([13, 2 + bob, 15, 0 + bob], fill=hexc("#22223d"))
        d.rectangle([8, 0 + bob, 9, 1 + bob], fill=hexc("#b6ff6a")); d.rectangle([15, 0 + bob, 16, 1 + bob], fill=hexc("#b6ff6a"))
    # Auge, Wange, Mund
    d.rectangle([14, 8 + bob, 15, 9 + bob], fill=OL); d.point((15, 8 + bob), fill=hexc("#ffffff"))
    blush = hexc("#f07a8a") if L["extra"] != "antenna" else hexc("#5fb0c8")
    d.point((13, 11 + bob), fill=blush)
    d.point((16, 12 + bob), fill=sh(sk, 0.55))
    d.line([9, 14 + bob, 14, 14 + bob], fill=sh(cl, 1.25))
    if L["fem"]:
        d.line([7, 29 + bob, 16, 29 + bob], fill=sh(cl, 0.7))
    # vorderer Arm
    hd = arm(arm_sw, sleeve, sk)
    return f

FRAMES = [("idle", 0), ("idle", 1), ("wave", 0), ("wave", 1)] + [("walk", k) for k in range(6)]
for i, L in enumerate(LOOKS):
    base = Image.new("RGBA", (240, 36)); top = Image.new("RGBA", (240, 36))
    for j, (pose, k) in enumerate(FRAMES):
        if pose == "walk":
            b, t = person_walk(L, k, False), person_walk(L, k, True)
        else:
            b, t = person_front(L, pose, k), person_front_top(L, pose, k)
        base.alpha_composite(b, (j * 24, 0)); top.alpha_composite(t, (j * 24, 0))
    base.save(OUT + "pass%d_base.png" % i); top.save(OUT + "pass%d_top.png" % i)
print("passenger parts ok")
