"""Fahrer fürs Finale der Nachtschicht: Grundflächen und Schattierung der Einzelbilder, danach baut Aseprite die Datei (Kontur, Tags, Export).
Der Fahrer entspricht dem im Taxi (orange Melone mit Plakette, dunkelblaue Uniform, rote Fliege): gleiche Farben, gleiche Pixeldichte
(tools/art/aseprite/gen_parts.py). 17 Bilder à 40×56 (Seitenansicht schaut nach rechts, Füße auf Zeile 54):
   0–7   Gehen (acht Phasen mit Kniegelenk: Kontakt, Abdruck, Durchschwung …)
   8     Stand seitlich      9  Drehung (Dreiviertel)
   10    von vorn lächelnd   11 von vorn ohne Lächeln
   12–14 von vorn winkend (drei Armstellungen)
   15    Sprung (Arme hoch, Beine angezogen)   16 Landung (Hocke)
Schritte (aus der Projektwurzel):
   python3 tools/art/gen_driver.py pre        -> build/aseprite-workspace/gf_driver/frame_00.png … frame_16.png (ohne Kontur)
   (Aseprite: driver.aseprite aus den Bildern bauen, Kontur mit outline_smart, Tags setzen – siehe tools/art/aseprite/README.md)
   python3 tools/art/gen_driver.py export     -> assets/art/driver.png aus build/aseprite-workspace/gf_driver/driver.aseprite (Blatt, ein Bild je 40 px)
   python3 tools/art/gen_driver.py cockpit    -> assets/art/taxi_cockpit_empty.png (leere Kuppel des Taxis, aus taxi.aseprite)
   python3 tools/art/gen_driver.py flat       -> Notlösung ohne Aseprite: driver.png mit einfacher Kontur direkt aus Python"""
import math, os, subprocess, sys, tempfile
import numpy as np
from PIL import Image, ImageDraw

def hexc(h, a=255):
    h = h.lstrip("#"); return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), a)

OL = hexc("#0c0f24")
SKH, SK, SKD, SKDD = hexc("#ffe0c4"), hexc("#f2c29b"), hexc("#d9a585"), hexc("#b98468")
UNIH, UNI, UNID, UNIDD = hexc("#4a5bb0"), hexc("#2d3a7a"), hexc("#1f2856"), hexc("#161c40")
TRH, TRO, TROD = hexc("#5a6088"), hexc("#434a70"), hexc("#2c3050")
SHIRT, SHIRTD, TIE, TIED = hexc("#f0f3ff"), hexc("#b4bce0"), hexc("#ff4d6d"), hexc("#c9304f")
CAPH, CAP, CAPD, BRIM, BRIMD = hexc("#ffa868"), hexc("#ff7a2e"), hexc("#e05a1c"), hexc("#c9561a"), hexc("#8a3410")
BADGE, BADGED = hexc("#fff3b0"), hexc("#e8b84a")
CHEEK, MOUTH, MOUTHD, WHITE = hexc("#f59a9a"), hexc("#8a3a3a"), hexc("#5a1f2a"), hexc("#ffffff")
SHOE, SHOEH, SOLE = hexc("#2a1a24"), hexc("#6a4a56"), hexc("#10080e")
GOLD = hexc("#e8b84a")
FW, FH, GROUND, N = 40, 56, 54, 17
CX = 20

def new():
    im = Image.new("RGBA", (FW, FH)); return im, ImageDraw.Draw(im)

def ik(hip, foot, l1, l2, bend=1.0):
    """Knie (oder Ellbogen) eines Zwei-Knochen-Glieds; bend = +1 knickt nach vorn (rechts), -1 nach hinten."""
    hx, hy = hip; fx, fy = foot
    dx, dy = fx - hx, fy - hy
    dist = max(0.01, min(math.hypot(dx, dy), l1 + l2 - 0.05))
    a = math.atan2(dy, dx)
    c = (l1 * l1 + dist * dist - l2 * l2) / (2 * l1 * dist)
    b = math.acos(max(-1.0, min(1.0, c)))
    return (hx + math.cos(a - bend * b) * l1, hy + math.sin(a - bend * b) * l1)

def thick(d, pts, w, col):
    for p, q in zip(pts, pts[1:]):
        d.line([p, q], fill=col, width=w)
    r = (w - 1) / 2.0
    for p in pts:
        d.ellipse([p[0] - r, p[1] - r, p[0] + r, p[1] + r], fill=col)

def R(d, x0, y0, x1, y1, col):
    d.rectangle([int(round(x0)), int(round(y0)), int(round(x1)), int(round(y1))], fill=col)

def P(d, x, y, col):
    d.point((int(round(x)), int(round(y))), fill=col)

# --------------------------------------------------------------------------- Teile
def hat_front(d, dx=0):
    """Melone: runde orange Kuppel (Licht links oben, Schatten rechts), ringsum schmale Krempe, Plakette vorn."""
    cx = CX + dx
    d.rounded_rectangle([cx - 7, 7, cx + 6, 17], radius=5, fill=CAP)
    d.rounded_rectangle([cx + 2, 9, cx + 6, 17], radius=3, fill=CAPD)                 # Schattenseite
    d.rounded_rectangle([cx - 7, 7, cx + 3, 16], radius=5, fill=CAP)
    R(d, cx - 4, 8, cx, 8, CAPH); P(d, cx - 6, 10, CAPH); R(d, cx - 5, 9, cx - 5, 10, CAPH)
    R(d, cx - 9, 17, cx + 8, 18, BRIM); R(d, cx - 9, 18, cx + 8, 18, BRIMD); R(d, cx - 8, 17, cx - 4, 17, CAPH)
    R(d, cx - 2, 11, cx + 1, 13, BADGE); R(d, cx - 2, 13, cx + 1, 13, BADGED); P(d, cx - 1, 12, OL)

def hat_side(d, hy=0):
    d.rounded_rectangle([CX - 7, 7 + hy, CX + 6, 17 + hy], radius=5, fill=CAP)
    d.rounded_rectangle([CX - 7, 9 + hy, CX - 3, 17 + hy], radius=3, fill=CAPD)       # Schatten hinten (Licht kommt von vorn rechts oben)
    d.rounded_rectangle([CX - 4, 7 + hy, CX + 6, 16 + hy], radius=5, fill=CAP)
    R(d, CX - 1, 8 + hy, CX + 4, 8 + hy, CAPH); P(d, CX + 5, 10 + hy, CAPH)
    R(d, CX - 8, 17 + hy, CX + 10, 18 + hy, BRIM); R(d, CX - 8, 18 + hy, CX + 10, 18 + hy, BRIMD); R(d, CX + 4, 17 + hy, CX + 9, 17 + hy, CAPH)
    R(d, CX + 2, 11 + hy, CX + 5, 13 + hy, BADGE); R(d, CX + 2, 13 + hy, CX + 5, 13 + hy, BADGED); P(d, CX + 4, 12 + hy, OL)

def head_front(d, smile, blink=False, dx=0):
    cx = CX + dx
    d.ellipse([cx - 7, 14, cx + 6, 27], fill=SK)
    R(d, cx - 5, 14, cx + 4, 17, SK)
    d.arc([cx - 7, 14, cx + 6, 27], 20, 160, fill=SKD)                                     # Kinn leicht im Schatten
    R(d, cx - 4, 26, cx + 3, 26, SKD)
    R(d, cx - 8, 20, cx - 8, 22, SKD); R(d, cx + 7, 20, cx + 7, 22, SKD)                    # Ohren
    P(d, cx - 8, 21, SKDD); P(d, cx + 7, 21, SKDD)
    for ex in (cx - 4, cx + 2):
        if blink:
            R(d, ex, 21, ex + 1, 21, OL)
        else:
            R(d, ex, 20, ex + 1, 22, OL); P(d, ex, 20, WHITE); P(d, ex + 1, 22, hexc("#2a3a8a"))
    P(d, cx, 23, SKD)                                                                       # Nasenspitze
    for ch in (cx - 6, cx - 5, cx + 4, cx + 5):
        P(d, ch, 24, CHEEK)
    if smile:
        R(d, cx - 2, 25, cx + 1, 25, MOUTH); P(d, cx - 3, 24, MOUTH); P(d, cx + 2, 24, MOUTH); R(d, cx - 1, 25, cx, 25, MOUTHD)
    else:
        R(d, cx - 1, 25, cx, 25, MOUTH)
    hat_front(d, dx)

def head_side(d, hy=0):
    d.ellipse([CX - 6, 14 + hy, CX + 6, 27 + hy], fill=SK)
    R(d, CX - 4, 14 + hy, CX + 4, 17 + hy, SK)
    d.arc([CX - 6, 14 + hy, CX + 6, 27 + hy], 20, 150, fill=SKD)
    R(d, CX - 3, 26 + hy, CX + 3, 26 + hy, SKD)
    P(d, CX + 7, 22 + hy, SK); P(d, CX + 7, 21 + hy, SK); P(d, CX + 7, 22 + hy, SKH); P(d, CX + 6, 23 + hy, SKD)   # Nase
    R(d, CX - 4, 21 + hy, CX - 3, 23 + hy, SKD); P(d, CX - 4, 22 + hy, SKDD)                    # Ohr
    R(d, CX + 2, 20 + hy, CX + 4, 22 + hy, OL); P(d, CX + 2, 20 + hy, WHITE)
    P(d, CX + 3, 24 + hy, CHEEK); R(d, CX + 3, 25 + hy, CX + 5, 25 + hy, MOUTH); P(d, CX + 6, 24 + hy, MOUTH)
    hat_side(d, hy)

def neck(d, y=27, h=3):
    R(d, CX - 2, y, CX + 2, y + h, SKD)

def torso_front(d, top=29, bottom=43, w=8):
    d.rounded_rectangle([CX - w, top, CX + w - 1, bottom], radius=3, fill=UNI)
    R(d, CX + 3, top + 2, CX + w - 1, bottom - 1, UNID)                                    # Schattenseite rechts
    R(d, CX - w + 1, top + 2, CX - w + 1, bottom - 3, UNIH)                                # Licht links
    d.polygon([(CX - 4, top), (CX, top + 6), (CX + 3, top)], fill=SHIRT)                    # Hemd
    d.polygon([(CX - 4, top), (CX - 1, top + 6), (CX - 5, top + 3)], fill=UNIH)             # Revers links
    d.polygon([(CX + 3, top), (CX + 1, top + 6), (CX + 5, top + 3)], fill=UNID)             # Revers rechts
    R(d, CX - 1, top + 2, CX, top + 4, TIE); P(d, CX, top + 5, TIED); R(d, CX, top + 2, CX, top + 4, TIED)   # Fliege/Krawatte
    P(d, CX - 3, top + 9, GOLD); P(d, CX - 3, top + 12, GOLD)                              # Knöpfe
    R(d, CX - w, bottom - 2, CX + w - 1, bottom - 2, UNID)                                 # Saum
    R(d, CX - 1, bottom - 2, CX, bottom - 1, GOLD)                                         # Gürtelschnalle

def legs_front(d, top=42, stance=0, crouch=0):
    """Beine von vorn: stance = Abstand der Füße nach außen, crouch = Kniebeuge (Knie nach außen)."""
    for sgn in (-1, 1):
        hip = (CX + sgn * 3, top)
        foot = (CX + sgn * (3 + stance), 52)
        if crouch:
            knee = (CX + sgn * (6 + crouch), (top + 52) / 2.0)
            thick(d, [hip, knee, foot], 4, TRO)
        else:
            thick(d, [hip, foot], 5 if not stance else 4, TRO)
        sx, sy = int(round(foot[0])), int(round(foot[1]))
        R(d, sx - 3 if sgn < 0 else sx - 2, sy, sx + 2 if sgn < 0 else sx + 3, sy + 2, SHOE)
        R(d, sx - 3 if sgn < 0 else sx - 2, sy + 2, sx + 2 if sgn < 0 else sx + 3, sy + 2, SOLE)
        P(d, sx - 1 if sgn < 0 else sx, sy, SHOEH)
    R(d, CX - 1, top, CX, top + 9, TROD)
    R(d, CX - 5, top + 1, CX - 5, top + 8, TRH)

def hand(d, x, y, col=SK):
    R(d, x, y, x + 3, y + 3, col); P(d, x, y, SKH if col == SK else col); R(d, x + 3, y + 1, x + 3, y + 2, SKD)

def arm_down(d, side, y=41):
    """Hängender Arm von vorn (side = -1 links im Bild, +1 rechts)."""
    x = CX + side * 11
    d.rounded_rectangle([x - 1, 30, x + 2, y + 1], radius=1, fill=UNI if side < 0 else UNID)
    R(d, x - 1 + (0 if side < 0 else 3), 31, x - 1 + (0 if side < 0 else 3), y, UNIH if side < 0 else UNIDD)
    R(d, x - 1, y, x + 2, y + 1, SHIRT)
    hand(d, x - 1, y + 2, SK if side < 0 else SKD)

def arm_up(d, hx, hy, side=1, elbow_out=5):
    """Arm von der Schulter zur Hand (hx, hy), Ellbogen nach außen."""
    sh = (CX + side * 8, 32)
    el = ik(sh, (hx, hy), 7.0, 7.0, bend=-side)
    thick(d, [sh, el], 4, UNID)
    thick(d, [el, (hx, hy + 3)], 4, UNI)
    R(d, hx - 2, hy + 3, hx + 1, hy + 4, SHIRT)
    hand(d, hx - 2, hy - 1, SK)

# --------------------------------------------------------------------------- Bilder
def front_frame(smile=True, blink=False, wave=None, pose="stand"):
    im, d = new()
    if pose == "crouch":
        legs_front(d, top=45, stance=3, crouch=3)
        torso_front(d, top=32, bottom=46)
        neck(d, 30, 2)
        arm_down(d, -1, 43); arm_down(d, 1, 43)
        for k in (-1, 1):
            pass
        shift = 3
        sub = Image.new("RGBA", (FW, FH)); sd = ImageDraw.Draw(sub)
        head_front(sd, smile)
        im.alpha_composite(sub, (0, shift - 0))
        return im
    if pose == "jump":
        legs_front(d, top=41, stance=3, crouch=2)
        torso_front(d, top=29, bottom=42)
        neck(d)
        arm_up(d, CX - 14, 19, -1); arm_up(d, CX + 14, 19, 1)
        head_front(d, True)
        return im
    legs_front(d)
    torso_front(d)
    neck(d)
    arm_down(d, -1)
    if wave is None:
        arm_down(d, 1)
    else:
        arm_up(d, CX + 11 + wave[0], 20 + wave[1], 1)
    head_front(d, smile, blink)
    return im

def three_quarter():
    im, d = new()
    legs_front(d)
    R(d, CX - 2, 42, CX + 3, 44, UNID)
    torso_front(d, w=7)
    neck(d)
    arm_down(d, -1)
    R(d, CX + 6, 31, CX + 8, 41, UNID); R(d, CX + 6, 41, CX + 8, 42, SHIRT); hand(d, CX + 5, 43, SKD)
    head_front(d, True, dx=1)
    R(d, CX + 7, 22, CX + 8, 22, SK)                                                     # Nase tritt aus der Wange
    return im

def side_frame(phase, standing=False):
    im, d = new()
    s = 0.0 if standing else math.sin(phase)
    c = 0.0 if standing else math.cos(phase)
    bob = 0 if standing else (1 if abs(s) < 0.5 else 0)
    hip = (CX, 43 - bob)
    sh = (CX, 31 - bob)

    def leg(sw, lift, far):
        foot = (CX + sw * 5.4, 52 - lift)
        knee = ik(hip, (foot[0] - 1.0, foot[1] - 1.0), 5.2, 5.2, bend=1.0)
        col, colh = (TROD, TROD) if far else (TRO, TRH)
        thick(d, [hip, knee], 5, col)
        thick(d, [knee, (foot[0] - 1.0, foot[1] - 1.0)], 4, col)
        if not far:
            d.line([hip[0] - 1, hip[1] + 1, knee[0] - 1, knee[1]], fill=TRH)
        fx, fy = int(round(foot[0])), int(round(foot[1]))
        R(d, fx - 3, fy - 1, fx + 4, fy + 1, SHOE); R(d, fx - 3, fy + 1, fx + 4, fy + 1, SOLE); R(d, fx - 2, fy - 1, fx + 2, fy - 1, SHOEH)
        R(d, fx - 3, fy - 2, fx, fy - 2, SHOE)

    def arm(sw, far):
        hand_pos = (CX + sw * 5.0, 41 - bob + abs(sw) * 0.5)
        el = ik(sh, hand_pos, 6.0, 5.5, bend=1.0)
        col = UNID if far else UNI
        thick(d, [sh, el], 4, col)
        thick(d, [el, hand_pos], 3, col if far else UNI)
        R(d, hand_pos[0] - 1, hand_pos[1] - 1, hand_pos[0] + 1, hand_pos[1] + 1, SHIRT)
        hand_c = (SKD if far else SK)
        R(d, hand_pos[0] - 1, hand_pos[1] + 1, hand_pos[0] + 1, hand_pos[1] + 3, hand_c)

    leg(-s, max(0.0, -c) * 3.0, True)
    arm(s, True)
    d.rounded_rectangle([CX - 6, 29 - bob, CX + 6, 44 - bob], radius=3, fill=UNI)
    R(d, CX - 6, 31 - bob, CX - 4, 43 - bob, UNID)                                      # Rücken im Schatten
    R(d, CX + 5, 31 - bob, CX + 5, 40 - bob, UNIH)                                       # Licht vorn
    R(d, CX + 4, 30 - bob, CX + 5, 36 - bob, SHIRT); R(d, CX + 6, 31 - bob, CX + 6, 36 - bob, TIE); P(d, CX + 6, 33 - bob, TIED)
    R(d, CX - 6, 42 - bob, CX + 6, 42 - bob, UNID); R(d, CX - 1, 42 - bob, CX + 1, 42 - bob, GOLD)
    leg(s, max(0.0, c) * 3.0, False)
    R(d, CX - 6, 41 - bob, CX + 6, 43 - bob, UNI); R(d, CX - 6, 43 - bob, CX + 6, 43 - bob, UNID)
    arm(-s, False)
    neck(d, 27 - bob, 3)
    head_side(d, -bob)
    return im

def frames():
    out = [side_frame(i / 8.0 * 2.0 * math.pi) for i in range(8)]
    out += [side_frame(0.0, standing=True), three_quarter(), front_frame(True), front_frame(False),
            front_frame(True, wave=(0, -2)), front_frame(True, wave=(2, -4)), front_frame(True, wave=(-1, -3)),
            front_frame(True, pose="jump"), front_frame(True, pose="crouch")]
    return out

# --------------------------------------------------------------------------- Ausgabe
def outline_flat(im):
    a = np.array(im); op = a[..., 3] > 0
    out = a.copy()
    for y in range(FH):
        for x in range(FW):
            if op[y, x]: continue
            if any(0 <= x + dx < FW and 0 <= y + dy < FH and op[y + dy, x + dx] for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))):
                out[y, x] = OL
    return Image.fromarray(out)

def cockpit_patch():
    """Pixel, die der Fahrer im Taxi verdeckt: Ebene `driver` ohne Spiegelungen und Instrumentenlinie, ersetzt durch das Glas darunter."""
    src = "tools/art/aseprite/taxi.aseprite"
    with tempfile.TemporaryDirectory() as tmp:
        bare, drv = os.path.join(tmp, "bare.png"), os.path.join(tmp, "drv.png")
        subprocess.run(["aseprite", "-b", "--ignore-layer", "driver", src, "--save-as", bare], check=True)
        subprocess.run(["aseprite", "-b", "--layer", "driver", src, "--save-as", drv], check=True)
        bare_a, drv_a = np.array(Image.open(bare).convert("RGBA")), np.array(Image.open(drv).convert("RGBA"))
    mask = drv_a[..., 3] > 0
    reflection = (drv_a[..., 0] > 250) & (drv_a[..., 1] > 250) & (drv_a[..., 2] > 250)
    teal = (drv_a[..., 0] == 0x1f) & (drv_a[..., 1] == 0x7f) & (drv_a[..., 2] == 0x92)
    figure = mask & ~reflection & ~teal
    eyes = ((37, 11), (41, 11)) if figure.shape[1] == 78 else ((45, 14), (50, 14))      # Taxi 78×48 (Runde 62) bzw. früher 96×60
    for px in eyes:                                                     # weiße Glanzpunkte der Augen gehören zur Figur
        figure[px[1], px[0]] = True
    patch = np.zeros_like(bare_a)
    patch[figure] = bare_a[figure]
    taxi = np.array(Image.open("assets/art/taxi.png").convert("RGBA"))
    h, w = figure.shape
    grow = figure.copy()
    for y in range(h):                                                   # Kontur der Figur im fertigen Taxi ebenfalls ersetzen
        for x in range(w):
            if figure[y, x]: continue
            near = any(0 <= x + dx < w and 0 <= y + dy < h and figure[y + dy, x + dx] for dx in (-1, 0, 1) for dy in (-1, 0, 1))
            if near and tuple(taxi[y, x][:3]) == OL[:3] and bare_a[y, x, 3] > 0 and patch[y, x, 3] == 0:
                grow[y, x] = True
                patch[y, x] = bare_a[y, x]
    return Image.fromarray(patch)

if __name__ == "__main__":
    what = sys.argv[1] if len(sys.argv) > 1 else ""
    ws = "build/aseprite-workspace/gf_driver/"
    if what == "pre":
        os.makedirs(ws, exist_ok=True)
        for i, f in enumerate(frames()):
            f.save(ws + "frame_%02d.png" % i)
        print("pre: %d Bilder nach %s" % (N, ws))
    elif what == "export":
        subprocess.run(["aseprite", "-b", ws + "driver.aseprite", "--sheet", "assets/art/driver.png", "--sheet-type", "horizontal"], check=True, stdout=subprocess.DEVNULL)
        print("driver.png aus Aseprite exportiert")
    elif what == "cockpit":
        cockpit_patch().save("assets/art/taxi_cockpit_empty.png")
        print("taxi_cockpit_empty.png ok")
    elif what == "flat":
        sheet = Image.new("RGBA", (FW * N, FH))
        for i, f in enumerate(frames()):
            sheet.alpha_composite(outline_flat(f), (i * FW, 0))
        sheet.save("assets/art/driver.png")
        print("flat: driver.png ok")
    else:
        sys.exit(__doc__)
