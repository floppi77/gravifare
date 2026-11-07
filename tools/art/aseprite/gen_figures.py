"""Eine eigene Figur je Fahrgaststimme (f0–f6, m0–m6), passend zur Stimmbeschreibung in tools/audio/.
Flache Grundflächen (Kleidung/Haut werden in Aseprite schattiert) + Detail-Ebene, je Figur ein Streifen 240×36
(10 Frames à 24×36: 2× Warten, 2× Winken, 6× Laufen nach rechts). Schreibt nach build/aseprite-workspace/gf_polish/figures/ (nie nach assets/). Aufruf: python3 tools/art/aseprite/gen_figures.py ."""
import os, sys, math
from PIL import Image, ImageDraw

ROOT = sys.argv[1] if len(sys.argv) > 1 else "."
OUT = os.path.join(ROOT, "build/aseprite-workspace/gf_polish/figures/")
os.makedirs(OUT, exist_ok=True)

def hexc(h, a=255):
    h = h.lstrip("#"); return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), a)
def sh(c, f):
    return tuple(max(0, min(255, int(v * f))) for v in c[:3]) + (255,)

OL = hexc("#0c0f24")
SHOE, SHOE_H = hexc("#10142b"), hexc("#3a4170")
T = (0, 0, 0, 0)

# Stimme -> Figur. top = Hauptfarbe Oberteil (wird schattiert), inner = Hemd/Bluse, legs = Hose/Rock, skirt = Rock statt Hose
FIG = {
 "f0": dict(skin="#f2c29b", hair="#3a2a52", hair_hi="#6a4a8c", hair_style="long", top="#d9467f", dress=True, acc=["clip"], note="jung, fröhlich, verspielt"),
 "f1": dict(skin="#c68a62", hair="#2a1a14", hair_hi="#5a3a2a", hair_style="bob", top="#2f8f9d", inner="#f2f0e6", legs="#2a2f4a", acc=["glasses"], note="Mitte 30, ruhig, trocken-humorvoll"),
 "f2": dict(skin="#f7d0b0", hair="#c8502a", hair_hi="#f08a4a", hair_style="ponytail", top="#9ad94a", legs="#4a6ad0", acc=["headphones", "freckles"], height=-1, note="17, aufgekratzt, kichernd"),
 "f3": dict(skin="#d9a57e", hair="#141420", hair_hi="#3a3a50", hair_style="long_side", top="#30303f", inner="#c8324a", legs="#1c1c28", acc=["sunglasses"], note="Ende 20, rauchig, cool"),
 "f4": dict(skin="#8a5a3c", hair="#1a1010", hair_hi="#3a2a20", hair_style="bun", top="#2c3e8a", inner="#f2f0e6", skirt="#2c3e8a", acc=["briefcase"], note="Geschäftsfrau, in Eile"),
 "f5": dict(skin="#f0c8b0", hair="#d8d8e4", hair_hi="#ffffff", hair_style="bun_curly", top="#b48ad8", skirt="#5e5288", acc=["handbag"], height=-1, note="Anfang 70, gütig, zittrig"),
 "f6": dict(skin="#8fd0c8", hair="#22223d", hair_hi="#40406a", hair_style="long", top="#7a6bd8", dress=True, acc=["antenna"], note="um 30, hauchig, verträumt"),
 "m0": dict(skin="#a8714f", hair="#1c1c30", hair_hi="#3a3a5c", hair_style="short", top="#3fb68b", inner="#e6eaff", legs="#43529c", acc=["suitcase"], note="Mitte 30, warmer Bariton"),
 "m1": dict(skin="#e8a888", hair="#7a6a5a", hair_hi="#a89888", hair_style="flatcap", cap="#6a4a2a", top="#8a5a2a", inner="#efe2c0", legs="#4a4a5a", acc=["mustache"], width=1, note="älter, rau, gutmütig"),
 "m2": dict(skin="#e9b58c", hair="#552a1c", hair_hi="#8a4a2c", hair_style="cap", cap="#3fa0d8", top="#e8a33a", legs="#43529c", acc=["hoodie"], note="19, aufgeregt, lässig"),
 "m3": dict(skin="#7a4e36", hair="#1e1a1a", hair_hi="#3a3030", hair_style="buzz", top="#b83a2a", legs="#3a4a6a", acc=["beard", "flannel"], width=1, note="Anfang 40, dröhnender Bass"),
 "m4": dict(skin="#f4d2b8", hair="#e0c060", hair_hi="#fff0a0", hair_style="messy", top="#7a8a3a", inner="#f2f0e6", legs="#5a4a3a", acc=["glasses_big", "bowtie"], width=-1, note="Ende 20, nervös, witzig"),
 "m5": dict(skin="#c08a64", hair="#2a2018", hair_hi="#8a8a90", hair_style="side", top="#3a3f55", inner="#f2f0e6", legs="#2a2e40", acc=["tie"], note="Mitte 40, Nachrichtensprecher"),
 "m6": dict(skin="#f0ccb4", hair="#e8e8f0", hair_hi="#ffffff", hair_style="bald", top="#c8b48a", legs="#5a5a6a", acc=["glasses", "mustache_white", "cane"], height=-1, note="um 80, dünn, schwerhörig laut"),
}
ORDER = ["f0", "f1", "f2", "f3", "f4", "f5", "f6", "m0", "m1", "m2", "m3", "m4", "m5", "m6"]

def ik(hip, foot, l1, l2):
    hx, hy = hip; fx, fy = foot
    dx, dy = fx - hx, fy - hy; dist = min(math.hypot(dx, dy), l1 + l2 - 0.01)
    a = math.atan2(dy, dx)
    c = (l1 * l1 + dist * dist - l2 * l2) / (2 * l1 * dist)
    b = math.acos(max(-1, min(1, c)))
    ang = a - b
    return (hx + math.cos(ang) * l1, hy + math.sin(ang) * l1)

def thick(d, pts, col, w):
    for p, q in zip(pts, pts[1:]):
        d.line([p, q], fill=col, width=w)
    for p in pts:
        r = (w - 1) / 2
        d.ellipse([p[0] - r, p[1] - r, p[0] + r, p[1] + r], fill=col)

# ------------------------------------------------------------------ Vorderansicht
def front(F, pose, k, top_layer):
    sk, cl, hr, hh = hexc(F["skin"]), hexc(F["top"]), hexc(F["hair"]), hexc(F["hair_hi"])
    acc = F.get("acc", [])
    w = F.get("width", 0)
    hy = -F.get("height", 0)              # kleinere/gebeugte Figuren: Kopf und Rumpf 1 px tiefer
    f = Image.new("RGBA", (24, 36)); d = ImageDraw.Draw(f)
    y = (1 if (pose == "idle" and k == 1) else 0) + hy
    tx0, tx1 = 6 - w, 17 + w
    if not top_layer:
        # Beine/Rock
        if F.get("dress"):
            d.rectangle([8, 29, 10, 33], fill=sh(sk, 0.9)); d.rectangle([13, 29, 15, 33], fill=sh(sk, 0.9))
        elif F.get("skirt"):
            d.rectangle([8, 29, 10, 33], fill=sh(sk, 0.9)); d.rectangle([13, 29, 15, 33], fill=sh(sk, 0.9))
        else:
            lg = hexc(F["legs"])
            d.rectangle([8, 28, 11, 33], fill=lg); d.rectangle([12, 28, 15, 33], fill=lg)
            d.line([11, 28, 11, 33], fill=sh(lg, 0.72)); d.line([15, 29, 15, 33], fill=sh(lg, 0.72))
        d.rectangle([7, 33, 11, 35], fill=SHOE); d.rectangle([12, 33, 16, 35], fill=SHOE)
        d.line([8, 33, 10, 33], fill=SHOE_H); d.line([13, 33, 15, 33], fill=SHOE_H)
        # Rumpf (flach -> Aseprite)
        d.rounded_rectangle([tx0, 14 + y, tx1, 28], radius=3, fill=cl)
        if F.get("dress"):
            d.polygon([(6, 24), (17, 24), (19, 30), (4, 30)], fill=cl)
        if F.get("skirt"):
            sc = hexc(F["skirt"])
            long = F.get("height", 0) < 0
            d.polygon([(6, 25), (17, 25), (18, 32 if long else 30), (5, 32 if long else 30)], fill=sc if sc != cl else cl)
        # Arme
        sleeve = sh(cl, 0.8)
        al0, al1, ar0, ar1 = 3 - w, 5 - w, 18 + w, 20 + w
        if pose == "wave":
            up = 0 if k == 0 else 1
            d.rectangle([al0, 15 + y, al1, 25], fill=sleeve); d.rectangle([al0, 25, al1, 27], fill=sk)
            thick(d, [(18.5 + w, 16.5 + y), (20 + up, 9)], sleeve, 3)
            d.rectangle([19 + up, 4, 22, 7], fill=sk); d.point((19 + up, 4), fill=T)
        else:
            d.rectangle([al0, 15 + y, al1, 25], fill=sleeve); d.rectangle([ar0, 15 + y, ar1, 25], fill=sleeve)
            d.rectangle([al0, 25, al1, 27], fill=sk); d.rectangle([ar0, 25, ar1, 27], fill=sk)
        # Kopf (flach -> Aseprite)
        d.ellipse([6, 2 + y, 17, 14 + y], fill=sk)
        return f
    # ---- obere Ebene
    inner = hexc(F["inner"]) if F.get("inner") else None
    if inner:
        d.rectangle([10, 14 + y, 13, 26], fill=inner); d.line([10, 14 + y, 10, 26], fill=sh(inner, 0.85))
        d.line([9, 15 + y, 9, 25], fill=sh(cl, 0.7)); d.line([14, 15 + y, 14, 25], fill=sh(cl, 0.7))     # Revers/Jackenkante
    else:
        d.line([9, 14 + y, 14, 14 + y], fill=sh(cl, 1.25))
    if "flannel" in acc:
        for xx in (8, 11, 14):
            d.line([xx + w * (1 if xx > 11 else (-1 if xx < 11 else 0)), 15 + y, xx, 27], fill=sh(cl, 0.7))
        d.line([tx0 + 1, 20 + y, tx1 - 1, 20 + y], fill=sh(cl, 0.7))
    if "hoodie" in acc:
        d.line([8, 23, 15, 23], fill=sh(cl, 0.7)); d.point((10, 16 + y), fill=hexc("#fff0b0")); d.point((13, 16 + y), fill=hexc("#fff0b0"))
    if "tie" in acc:
        d.line([11, 15 + y, 11, 23], fill=hexc("#c8283a")); d.line([12, 15 + y, 12, 23], fill=hexc("#e84a5a")); d.point((11, 24), fill=hexc("#c8283a"))
    if "bowtie" in acc:
        d.rectangle([10, 15 + y, 13, 16 + y], fill=hexc("#c8283a")); d.point((11, 15 + y), fill=hexc("#ff7a8a"))
    if F.get("dress"):
        d.line([5, 29, 18, 29], fill=sh(cl, 0.7))
    if F.get("skirt"):
        d.line([6, 25, 17, 25], fill=sh(hexc(F["skirt"]), 0.7))
    _hair_front(d, F, y)
    _face_front(d, F, pose, k, y)
    _acc_front(d, F, pose, y)
    return f

def _hair_front(d, F, y):
    hr, hh, st = hexc(F["hair"]), hexc(F["hair_hi"]), F["hair_style"]
    if st in ("cap", "flatcap"):
        c = hexc(F["cap"])
        if st == "cap":
            d.pieslice([5, 0 + y, 18, 12 + y], 180, 360, fill=c); d.line([7, 1 + y, 13, 1 + y], fill=sh(c, 1.5))
            d.rectangle([5, 5 + y, 19, 6 + y], fill=sh(c, 0.7))
            d.rectangle([5, 7 + y, 6, 9 + y], fill=hr); d.rectangle([17, 7 + y, 18, 8 + y], fill=hr)
        else:
            d.rectangle([6, 1 + y, 17, 4 + y], fill=c); d.line([7, 1 + y, 15, 1 + y], fill=sh(c, 1.4))
            d.rectangle([5, 5 + y, 18, 5 + y], fill=sh(c, 0.7))
            d.rectangle([5, 6 + y, 6, 9 + y], fill=hr); d.rectangle([17, 6 + y, 18, 9 + y], fill=hr)
        return
    if st == "bald":
        d.rectangle([5, 6 + y, 6, 9 + y], fill=hr); d.rectangle([17, 6 + y, 18, 9 + y], fill=hr)
        d.point((9, 3 + y), fill=hexc("#ffffff"))         # Glanz auf der Glatze
        return
    if st == "buzz":
        d.pieslice([6, 1 + y, 17, 10 + y], 180, 360, fill=hr); d.rectangle([6, 5 + y, 6, 7 + y], fill=hr); d.rectangle([17, 5 + y, 17, 7 + y], fill=hr)
        return
    d.pieslice([5, 0 + y, 18, 12 + y], 180, 360, fill=hr)
    if st in ("long", "long_side"):
        d.rectangle([5, 5 + y, 7, 14 + y], fill=hr); d.rectangle([16, 5 + y, 18, 14 + y], fill=hr)
        if st == "long":
            d.polygon([(7, 5 + y), (12, 5 + y), (8, 8 + y)], fill=hr)
        else:
            d.polygon([(7, 5 + y), (16, 5 + y), (16, 8 + y), (14, 7 + y)], fill=hr)     # Seitenscheitel, Strähne über ein Auge
            d.rectangle([16, 5 + y, 18, 16 + y], fill=hr)
    elif st == "bob":
        d.rectangle([5, 5 + y, 7, 11 + y], fill=hr); d.rectangle([16, 5 + y, 18, 11 + y], fill=hr)
        d.line([7, 5 + y, 16, 5 + y], fill=hr)
    elif st == "ponytail":
        d.rectangle([5, 5 + y, 6, 8 + y], fill=hr); d.rectangle([17, 5 + y, 18, 8 + y], fill=hr)
        d.ellipse([16, 0 + y, 21, 5 + y], fill=hr); d.rectangle([18, 4 + y, 20, 10 + y], fill=hr)
        d.point((17, 2 + y), fill=hexc("#ff6aa0"))                                    # Haargummi
    elif st in ("bun", "bun_curly"):
        d.rectangle([5, 5 + y, 6, 9 + y], fill=hr); d.rectangle([17, 5 + y, 18, 9 + y], fill=hr)
        d.ellipse([9, 0 + y, 14, 3 + y], fill=hr)
        if st == "bun_curly":
            for px in (6, 9, 12, 15):
                d.point((px, 2 + y), fill=hh)
            d.rectangle([5, 9 + y, 6, 10 + y], fill=hr); d.rectangle([17, 9 + y, 18, 10 + y], fill=hr)
    elif st == "short":
        d.rectangle([5, 5 + y, 7, 9 + y], fill=hr); d.polygon([(10, 5 + y), (16, 5 + y), (16, 7 + y)], fill=hr)
    elif st == "messy":
        d.rectangle([5, 5 + y, 6, 9 + y], fill=hr); d.rectangle([17, 5 + y, 18, 8 + y], fill=hr)
        for px, py in ((7, 0), (10, -1), (13, 0), (16, 1)):
            d.point((px, py + 1 + y), fill=hr); d.point((px, py + 2 + y), fill=hr)
        d.polygon([(7, 5 + y), (11, 5 + y), (8, 7 + y)], fill=hr)
    elif st == "side":
        d.rectangle([5, 4 + y, 6, 6 + y], fill=hr); d.rectangle([17, 4 + y, 18, 6 + y], fill=hr)
        d.point((6, 7 + y), fill=hh); d.point((17, 7 + y), fill=hh)                                 # graue Schläfen
        d.line([8, 2 + y, 8, 4 + y], fill=sh(hr, 0.6))                                                 # Scheitel
        d.polygon([(9, 4 + y), (17, 4 + y), (17, 6 + y)], fill=hr)
    if st not in ("side",):
        d.line([8, 1 + y, 12, 1 + y], fill=hh); d.point((7, 2 + y), fill=hh)

def _face_front(d, F, pose, k, y):
    sk = hexc(F["skin"]); acc = F.get("acc", [])
    blink = pose == "idle" and k == 1
    if "sunglasses" in acc:
        d.rectangle([8, 8 + y, 15, 9 + y], fill=hexc("#1a1a2a")); d.point((9, 8 + y), fill=hexc("#8a8ab0")); d.point((14, 8 + y), fill=hexc("#8a8ab0"))
    elif blink:
        d.line([9, 9 + y, 10, 9 + y], fill=OL); d.line([13, 9 + y, 14, 9 + y], fill=OL)
    else:
        d.rectangle([9, 8 + y, 10, 9 + y], fill=OL); d.rectangle([13, 8 + y, 14, 9 + y], fill=OL)
        d.point((9, 8 + y), fill=hexc("#ffffff")); d.point((13, 8 + y), fill=hexc("#ffffff"))
    if "glasses" in acc or "glasses_big" in acc:
        big = "glasses_big" in acc
        g = hexc("#2a2a3a") if big else hexc("#dfe4ff")       # Hornbrille dunkel, sonst helles Metallgestell
        lens = hexc("#bfe6ff")
        for x0 in (8, 12):
            d.rectangle([x0, 7 + y, x0 + 3, 10 + y], fill=lens if big else None, outline=g)
            if big and not blink:
                d.point((x0 + 1 + (0 if x0 == 8 else 1), 8 + y), fill=OL); d.point((x0 + 1 + (0 if x0 == 8 else 1), 9 + y), fill=OL)
        d.point((11, 8 + y), fill=g); d.point((12, 8 + y), fill=g)
    alien = "antenna" in acc
    blush = hexc("#5fb0c8") if alien else (hexc("#d46a5a") if F["skin"] in ("#7a4e36", "#8a5a3c") else hexc("#f07a8a"))
    d.point((8, 11 + y), fill=blush); d.point((15, 11 + y), fill=blush)
    if "freckles" in acc:
        for p in ((8, 10), (9, 11), (14, 10), (15, 10)):
            d.point((p[0], p[1] + y), fill=hexc("#d08860"))
    if "beard" in acc:
        b = hexc(F["hair"])
        d.polygon([(6, 9 + y), (17, 9 + y), (16, 13 + y), (13, 15 + y), (10, 15 + y), (7, 13 + y)], fill=b)
        d.rectangle([9, 9 + y, 14, 10 + y], fill=sk)
        d.line([8, 13 + y, 9, 14 + y], fill=hexc("#4a4040")); d.line([15, 13 + y, 14, 14 + y], fill=hexc("#4a4040"))     # Glanzkante im Bart
        d.line([10, 12 + y, 13, 12 + y], fill=hexc("#c86a5a") if pose != "wave" else hexc("#7a2a3a"))
        if pose == "wave": d.line([10, 13 + y, 13, 13 + y], fill=hexc("#7a2a3a"))
        return
    if "mustache" in acc or "mustache_white" in acc:
        m = hexc("#e8e8f0") if "mustache_white" in acc else sh(hexc(F["hair"]), 0.8)
        d.rectangle([9, 11 + y, 14, 11 + y], fill=m); d.point((9, 12 + y), fill=m); d.point((14, 12 + y), fill=m)
        if pose == "wave": d.rectangle([11, 12 + y, 12, 13 + y], fill=hexc("#7a2a3a"))
        return
    mouth = sh(sk, 0.55)
    if pose == "wave":
        d.rectangle([11, 11 + y, 12, 12 + y], fill=hexc("#7a2a3a"))
    else:
        d.line([11, 12 + y, 12, 12 + y], fill=mouth); d.point((10, 11 + y), fill=mouth); d.point((13, 11 + y), fill=mouth)

def _acc_front(d, F, pose, y):
    acc = F.get("acc", [])
    if "clip" in acc:
        d.rectangle([15, 3 + y, 16, 4 + y], fill=hexc("#ffe14a"))
    if "antenna" in acc:
        for ax, tx in ((9, 7), (14, 16)):
            d.line([ax, 2 + y, tx, 1 + y], fill=hexc("#22223d"))
        d.rectangle([6, 0 + y, 7, 1 + y], fill=hexc("#b6ff6a")); d.rectangle([16, 0 + y, 17, 1 + y], fill=hexc("#b6ff6a"))
        d.point((6, 0 + y), fill=hexc("#f0ffd0")); d.point((16, 0 + y), fill=hexc("#f0ffd0"))
    if "headphones" in acc:
        d.arc([5, 0 + y, 18, 10 + y], 180, 360, fill=hexc("#1a1a2a"))
        d.rectangle([4, 7 + y, 6, 10 + y], fill=hexc("#2ad0e0")); d.rectangle([17, 7 + y, 19, 10 + y], fill=hexc("#2ad0e0"))
    wave = pose == "wave"
    if "suitcase" in acc and not wave:
        d.rectangle([18, 26, 23, 33], fill=hexc("#7a4a2a")); d.line([18, 26, 23, 26], fill=hexc("#a8703c"))
        d.line([18, 30, 23, 30], fill=hexc("#c9a060")); d.line([18, 33, 23, 33], fill=hexc("#4a2a18")); d.rectangle([20, 24, 21, 25], fill=hexc("#3a2a18"))
    if "briefcase" in acc and not wave:
        d.rectangle([18, 27, 23, 31], fill=hexc("#1e1e2a")); d.line([18, 27, 23, 27], fill=hexc("#4a4a60")); d.point((20, 29), fill=hexc("#d8b860"))
        d.rectangle([20, 26, 21, 26], fill=hexc("#1e1e2a"))
    if "handbag" in acc:
        d.line([2, 18 + y, 4, 23], fill=hexc("#8a3a5a"))
        d.rectangle([1, 23, 5, 27], fill=hexc("#c84a7a")); d.line([1, 23, 5, 23], fill=hexc("#ff8ab0")); d.point((3, 25), fill=hexc("#ffe14a"))
    if "cane" in acc and not wave:
        d.line([21, 26, 21, 35], fill=hexc("#6a4a2a")); d.line([19, 26, 21, 26], fill=hexc("#8a6a3a"))

# ------------------------------------------------------------------ Seitenansicht (Laufen, Blick nach rechts)
def walk(F, k, top_layer):
    sk, cl, hr, hh = hexc(F["skin"]), hexc(F["top"]), hexc(F["hair"]), hexc(F["hair_hi"])
    acc = F.get("acc", []); w = F.get("width", 0); hy = -F.get("height", 0)
    f = Image.new("RGBA", (24, 36)); d = ImageDraw.Draw(f)
    ph = k / 6.0 * 2 * math.pi
    bob = (1 if k in (1, 4) else 0) + hy
    lean = 1 if F.get("height", 0) < 0 else 0          # ältere/kleine Figuren: Kopf leicht vor
    old = "cane" in acc or F["hair_style"] == "bun_curly"
    stride = 3.2 if old else 4.5
    hip = (11.5, 25 + bob - hy)
    def foot(p):
        return (11.5 + math.cos(p) * stride, 34.5 - max(0.0, math.sin(p)) * (1.6 if old else 2.6))
    skirt = F.get("dress") or F.get("skirt")
    legc = sh(sk, 0.9) if skirt else hexc(F["legs"])
    legs = [(foot(ph + math.pi), sh(legc, 0.75)), (foot(ph), legc)]
    arm_sw = math.cos(ph) * (1.8 if old else 3.0)
    sleeve, sleeve_d = sh(cl, 0.8), sh(cl, 0.62)
    shoulder = (11.5 + lean, 16.5 + bob)
    def arm(sw, col, hand):
        el = (shoulder[0] - sw * 0.5, shoulder[1] + 4.5)
        hd = (shoulder[0] - sw, shoulder[1] + 8.5)
        thick(d, [shoulder, el, hd], col, 3)
        if col == sleeve:
            d.line([(shoulder[0] + 1.5, shoulder[1] + 1), (el[0] + 1.5, el[1]), (hd[0] + 1.5, hd[1] - 1)], fill=sleeve_d)
        d.rectangle([round(hd[0]) - 1, round(hd[1]), round(hd[0]) + 1, round(hd[1]) + 1], fill=hand)
        return hd
    hx0, hx1 = 7 + lean, 17 + lean
    if not top_layer:
        if "suitcase" in acc or "briefcase" in acc:
            hd = arm(4.2 + math.cos(ph) * 0.6, sleeve_d, sh(sk, 0.8))
            hx, hyy = round(hd[0]), round(hd[1])
            if "suitcase" in acc:
                d.rectangle([hx - 4, hyy + 2, hx + 1, hyy + 8], fill=hexc("#6a3e22")); d.line([hx - 4, hyy + 2, hx + 1, hyy + 2], fill=hexc("#94602f"))
                d.line([hx - 4, hyy + 5, hx + 1, hyy + 5], fill=hexc("#b08a50")); d.line([hx - 4, hyy + 8, hx + 1, hyy + 8], fill=hexc("#40241a"))
            else:
                d.rectangle([hx - 4, hyy + 2, hx + 1, hyy + 6], fill=hexc("#1e1e2a")); d.line([hx - 4, hyy + 2, hx + 1, hyy + 2], fill=hexc("#4a4a60"))
            d.rectangle([hx - 1, hyy + 1, hx, hyy + 1], fill=hexc("#3a2a18"))
        else:
            arm(-arm_sw, sleeve_d, sh(sk, 0.8))
        for i, (ft, col) in enumerate(legs):
            kn = ik(hip, ft, 5.0, 5.2)
            thick(d, [hip, kn, ft], col, 3)
            fx, fy = round(ft[0]), round(ft[1])
            d.rectangle([fx - 1, fy - 1, fx + 2, fy], fill=SHOE)
            if i == 1: d.point((fx, fy - 1), fill=SHOE_H)
        d.rounded_rectangle([8 - max(w, 0), 14 + bob, 15 + w, 28 + bob - hy], radius=3, fill=cl)
        if F.get("dress"):
            d.polygon([(8, 24 + bob), (15, 24 + bob), (17, 30 + bob), (6, 30 + bob)], fill=cl)
        if F.get("skirt"):
            long = F.get("height", 0) < 0
            d.polygon([(8, 25 + bob - hy), (15, 25 + bob - hy), (16, (32 if long else 30) + bob - hy), (7, (32 if long else 30) + bob - hy)], fill=hexc(F["skirt"]))
        if "belly" in acc or w > 0:
            d.ellipse([12, 18 + bob, 17, 26 + bob], fill=cl)
        d.ellipse([hx0, 2 + bob, hx1, 14 + bob], fill=sk)
        d.rectangle([hx1 - 1, 7 + bob, hx1, 9 + bob], fill=sk)
        return f
    # ---- obere Ebene
    st = F["hair_style"]
    if st == "cap":
        c = hexc(F["cap"])
        d.pieslice([hx0 - 1, 0 + bob, hx1, 12 + bob], 180, 360, fill=c); d.line([hx0 + 1, 1 + bob, hx0 + 6, 1 + bob], fill=sh(c, 1.5))
        d.rectangle([hx0, 5 + bob, hx1 + 3, 6 + bob], fill=sh(c, 0.7)); d.rectangle([hx0 - 1, 7 + bob, hx0 + 1, 10 + bob], fill=hr)
    elif st == "flatcap":
        c = hexc(F["cap"])
        d.rectangle([hx0 - 1, 1 + bob, hx1 - 1, 4 + bob], fill=c); d.rectangle([hx0 + 2, 5 + bob, hx1 + 2, 5 + bob], fill=sh(c, 0.7))
        d.rectangle([hx0 - 1, 5 + bob, hx0 + 1, 9 + bob], fill=hr)
    elif st == "bald":
        d.rectangle([hx0, 6 + bob, hx0 + 2, 9 + bob], fill=hr); d.point((hx0 + 4, 3 + bob), fill=hexc("#ffffff"))
    elif st == "buzz":
        d.pieslice([hx0, 1 + bob, hx1 - 1, 10 + bob], 180, 360, fill=hr); d.rectangle([hx0, 5 + bob, hx0 + 2, 8 + bob], fill=hr)
    else:
        d.pieslice([hx0 - 1, 0 + bob, hx1, 12 + bob], 180, 360, fill=hr)
        if st in ("long", "long_side"):
            d.rectangle([hx0 - 1, 4 + bob, hx0 + 2, 14 + bob], fill=hr)
            d.polygon([(hx0 - 1, 6 + bob), (hx0 + 2, 6 + bob), (hx0, 16 + bob), (hx0 - 2, 15 + bob)], fill=hr)
        elif st == "bob":
            d.rectangle([hx0 - 1, 4 + bob, hx0 + 3, 11 + bob], fill=hr)
        elif st == "ponytail":
            d.rectangle([hx0 - 1, 4 + bob, hx0 + 1, 8 + bob], fill=hr)
            sw = round(math.sin(ph) * 1.0)
            d.polygon([(hx0, 2 + bob), (hx0 - 4, 4 + bob + sw), (hx0 - 4, 9 + bob + sw), (hx0 - 1, 6 + bob)], fill=hr)
            d.point((hx0, 3 + bob), fill=hexc("#ff6aa0"))
        elif st in ("bun", "bun_curly"):
            d.rectangle([hx0 - 1, 4 + bob, hx0 + 1, 9 + bob], fill=hr); d.ellipse([hx0 - 3, 1 + bob, hx0 + 1, 5 + bob], fill=hr)
            if st == "bun_curly":
                for px in (hx0 + 2, hx0 + 5, hx0 + 8): d.point((px, 1 + bob), fill=hh)
        elif st == "short":
            d.rectangle([hx0 - 1, 4 + bob, hx0 + 2, 10 + bob], fill=hr)
        elif st == "messy":
            d.rectangle([hx0 - 1, 4 + bob, hx0 + 1, 9 + bob], fill=hr)
            for px in (hx0 + 1, hx0 + 4, hx0 + 7): d.point((px, 0 + bob), fill=hr)
        elif st == "side":
            d.rectangle([hx0 - 1, 4 + bob, hx0 + 1, 7 + bob], fill=hr); d.point((hx0 + 1, 8 + bob), fill=hh)
        if st != "side":
            d.polygon([(hx0 + 5, 5 + bob), (hx1, 5 + bob), (hx1, 6 + bob)], fill=hr)
            d.line([hx0 + 2, 1 + bob, hx0 + 6, 1 + bob], fill=hh)
        else:
            d.polygon([(hx0 + 3, 4 + bob), (hx1, 4 + bob), (hx1, 6 + bob)], fill=hr)
    ex, ey = hx1 - 3, 8 + bob
    if "sunglasses" in acc:
        d.rectangle([ex - 1, ey, ex + 2, ey + 1], fill=hexc("#1a1a2a")); d.line([hx0 + 3, ey, ex - 1, ey], fill=hexc("#1a1a2a"))
    else:
        d.rectangle([ex, ey, ex + 1, ey + 1], fill=OL); d.point((ex + 1, ey), fill=hexc("#ffffff"))
    if "glasses" in acc or "glasses_big" in acc:
        big = "glasses_big" in acc
        g = hexc("#2a2a3a") if big else hexc("#dfe4ff")
        if big:
            d.rectangle([ex - 1, ey - 1, ex + 2, ey + 2], fill=hexc("#bfe6ff"), outline=g); d.rectangle([ex + 1, ey, ex + 1, ey + 1], fill=OL)
        else:
            d.rectangle([ex - 1, ey - 1, ex + 2, ey + 2], outline=g)
        d.line([hx0 + 3, ey, ex - 1, ey], fill=g)
    alien = "antenna" in acc
    blush = hexc("#5fb0c8") if alien else (hexc("#d46a5a") if F["skin"] in ("#7a4e36", "#8a5a3c") else hexc("#f07a8a"))
    d.point((ex - 1, ey + 3), fill=blush)
    if "freckles" in acc:
        d.point((ex - 2, ey + 2), fill=hexc("#d08860")); d.point((ex, ey + 3), fill=hexc("#d08860"))
    if "beard" in acc:
        d.polygon([(hx0 + 4, 10 + bob), (hx1, 10 + bob), (hx1 - 1, 13 + bob), (hx0 + 6, 15 + bob)], fill=hr)
    elif "mustache" in acc or "mustache_white" in acc:
        m = hexc("#e8e8f0") if "mustache_white" in acc else sh(hr, 0.8)
        d.rectangle([hx1 - 3, 11 + bob, hx1, 11 + bob], fill=m)
    else:
        d.point((hx1 - 1, 12 + bob), fill=sh(sk, 0.55))
    if "headphones" in acc:
        d.rectangle([hx0 + 3, 6 + bob, hx0 + 5, 9 + bob], fill=hexc("#2ad0e0")); d.line([hx0 + 4, 0 + bob, hx0 + 4, 5 + bob], fill=hexc("#1a1a2a"))
    if "clip" in acc:
        d.rectangle([hx0 + 2, 3 + bob, hx0 + 3, 4 + bob], fill=hexc("#ffe14a"))
    if "antenna" in acc:
        d.line([hx0 + 4, 2 + bob, hx0 + 2, 0 + bob], fill=hexc("#22223d")); d.line([hx0 + 6, 2 + bob, hx0 + 8, 0 + bob], fill=hexc("#22223d"))
        d.rectangle([hx0 + 1, 0 + bob, hx0 + 2, 1 + bob], fill=hexc("#b6ff6a")); d.rectangle([hx0 + 8, 0 + bob, hx0 + 9, 1 + bob], fill=hexc("#b6ff6a"))
    inner = hexc(F["inner"]) if F.get("inner") else None
    if inner:
        d.line([14 + w, 15 + bob, 14 + w, 24 + bob], fill=inner)
    else:
        d.line([9, 14 + bob, 14, 14 + bob], fill=sh(cl, 1.25))
    if "tie" in acc:
        d.line([15, 15 + bob, 15, 22 + bob], fill=hexc("#c8283a"))
    if "bowtie" in acc:
        d.rectangle([14, 15 + bob, 16, 16 + bob], fill=hexc("#c8283a"))
    if "flannel" in acc:
        d.line([9, 20 + bob, 16, 20 + bob], fill=sh(cl, 0.7)); d.line([12, 15 + bob, 12, 27 + bob], fill=sh(cl, 0.7))
    if F.get("dress"):
        d.line([7, 29 + bob, 16, 29 + bob], fill=sh(cl, 0.7))
    if "handbag" in acc:
        d.rectangle([13, 21 + bob, 17, 25 + bob], fill=hexc("#c84a7a")); d.line([13, 21 + bob, 17, 21 + bob], fill=hexc("#ff8ab0"))
        d.line([14, 18 + bob, 13, 21 + bob], fill=hexc("#8a3a5a"))
    hd = arm(arm_sw, sleeve, sk)
    if "cane" in acc:
        hx, hyy = round(hd[0]), round(hd[1])
        d.line([hx + 1, hyy, hx + 3, 35], fill=hexc("#6a4a2a")); d.line([hx - 1, hyy, hx + 1, hyy], fill=hexc("#8a6a3a"))
    return f

FRAMES = [("idle", 0), ("idle", 1), ("wave", 0), ("wave", 1)] + [("walk", k) for k in range(6)]
if __name__ == "__main__":
    base_all = Image.new("RGBA", (240, 36 * len(ORDER))); top_all = Image.new("RGBA", (240, 36 * len(ORDER)))
    for r, v in enumerate(ORDER):
        F = FIG[v]
        for j, (pose, k) in enumerate(FRAMES):
            b = walk(F, k, False) if pose == "walk" else front(F, pose, k, False)
            t = walk(F, k, True) if pose == "walk" else front(F, pose, k, True)
            base_all.alpha_composite(b, (j * 24, r * 36)); top_all.alpha_composite(t, (j * 24, r * 36))
    base_all.save(OUT + "fig_base.png"); top_all.save(OUT + "fig_top.png")
    prev = base_all.copy(); prev.alpha_composite(top_all)
    prev.resize((240 * 4, 36 * 4 * len(ORDER)), Image.NEAREST).save(OUT + "fig_preview_raw.png")
    print("ok", len(ORDER), "Figuren")
