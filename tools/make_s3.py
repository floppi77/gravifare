"""Sektor 3 'Schrottgürtel', Level 23–33 (S3-01 … S3-11). Aufruf aus der Projektwurzel.
Neue Mechaniken: Trümmer (bewegliche Brocken), Schieber (große bewegliche Blöcke), Pads auf Schienen.
Ab Level 23 gibt es fünf Passagierpads. Lebens-Stationen in Level 25 und 30. Pars aus tools/s3_pars.json."""
import sys, json, os, random
sys.path.insert(0, "tools")
from levelkit import Grid, write

PARS = json.load(open("tools/s3_pars.json")) if os.path.exists("tools/s3_pars.json") else {}
FINAL = {"S3-10": "S3-01", "S3-04": "S3-02", "S3-03": "S3-03", "S3-01": "S3-04", "S3-02": "S3-05", "S3-06": "S3-06", "S3-08": "S3-07",
         "S3-05": "S3-08", "S3-11": "S3-09", "S3-07": "S3-10", "S3-09": "S3-11"}      # Entwurfsschlüssel -> endgültige ID (nach gemessener Schwierigkeit)
BOOST = {"S3-%02d" % i: 26 for i in range(1, 12)}      # zusätzliche Dornenbänder an der Decke je Entwurfsschlüssel
NAMES = [("Mika", "f"), ("Odo", "m"), ("Lena", "f"), ("Jonas", "m"), ("Ines", "f"), ("Ben", "m"), ("Nora", "f"), ("Tarek", "m")]


def seq(seed, n=6, pads=5, start=1):
    """Auftragsfolge: erster Fahrgast nicht am Startpad, keine Kettenüberschneidung, letzter zum Ausgang."""
    rnd = random.Random(seed)
    while True:
        out = []
        prev_to = start
        ok = True
        for i in range(n):
            frm = rnd.choice([p for p in range(1, pads + 1) if p != prev_to and not (i == 0 and p == start)])
            if i == n - 1:
                out.append((str(frm), "exit"))
                break
            to = rnd.choice([p for p in range(1, pads + 1) if p != frm])
            out.append((str(frm), str(to)))
            prev_to = to
        if len({a for a, _ in out} | {b for _, b in out if b != "exit"}) >= pads:
            return out


def jobs_of(sq, base=120):
    res = []
    for i, (a, b) in enumerate(sq):
        n, gnd = NAMES[i % len(NAMES)]
        res.append({"from": a, "to": b, "fare": base + 10 * i, "par": 50, "passenger": n, "gender": gnd})
    return res


def boost_spikes(g, n):
    placed = 0
    for x in list(range(2, 15)) + list(range(37, 24, -1)):
        if placed >= n:
            break
        if g.g[1][x] == "." and g.g[2][x] == ".":
            g.g[1][x] = "^"
            placed += 1


LSET = ("S3-03", "S3-08")     # Lebens-Stationen in Level 25 und 30


def V1(g): g.rect("#", 12, 1, 15, 8)          # hängender Zapfen links der Torzone (Engstelle)
def V2(g): g.rect("#", 24, 16, 27, 19)        # niedriger Block zwischen Pfeiler und Pad 5
def V3(g): g.rect("#", 27, 1, 28, 4)          # kleiner hängender Zapfen rechts


def make(key, de, en, g, sq, movers, mech, fragile=(), **extra):
    fid = FINAL.get(key, key)
    n = BOOST.get(key, 0)
    boost_spikes(g, n)
    mech = list(mech) + (["spikes"] if n > 0 and "spikes" not in mech else [])
    if fid in LSET:
        if g.g[16][24] == "#":                      # niedriger Block V2 (Zeilen 16–19): Lebens-Station obenauf
            g.rect("L", 24, 15, 27, 15)
        else:
            g.rect("L", 24, 19, 27, 19)
    jobs = jobs_of(sq)
    for j, p in zip(jobs, PARS.get(fid, [])):
        j["par"] = p
    for i in fragile:                     # zerbrechlicher Fahrgast: jede Beschädigung an Bord beendet die Fahrt; dafür mehr Fahrgeld
        jobs[i]["fragile"] = True
        jobs[i]["fare"] = int(jobs[i]["fare"] * 1.25)
    if fragile and "fragile" not in mech:
        mech = list(mech) + ["fragile"]
    if any(m["kind"] == "meteor" for m in movers) and "meteors" not in mech:
        mech = list(mech) + ["meteors"]
    if any(m["kind"] == "slider" for m in movers) and "sliders" not in mech:
        mech = list(mech) + ["sliders"]
    write(fid, 3, int(fid[-2:]), de, en, g, jobs, movers=movers, mechanics=mech, **extra)
    print("== %s (%s) %s" % (fid, key, de))
    g.show()


def D(x, y, dx=0, dy=0, period=8.0, phase=0.0, w=2, h=1, kind="debris", shape="line"):
    period = round(period * 0.82 * (0.85 + 0.3 * random.Random(x * 31 + y * 17 + int(period * 10)).random()), 1)     # schneller und je Brocken anders
    return {"kind": kind, "x": x, "y": y, "w": w, "h": h, "dx": dx, "dy": dy, "period": period, "phase": phase, "shape": shape}


def SL(x, y, w=3, h=2, dx=4, dy=0, period=12.0, phase=0.0):
    """Schieber: großer Block, der hin und her fährt; Berührung quetscht (Schaden und Hinausschieben)."""
    return {"kind": "slider", "x": x, "y": y, "w": w, "h": h, "dx": dx, "dy": dy, "period": period, "phase": phase, "shape": "line"}


def METS(lanes, period=22.0, t0=10.0, gap=0.9, fall=1.6):
    """Meteoritenschauer: lanes = [(x, dx, dy)] fallen nacheinander (Abstand gap) ab Zeit t0, dann alle `period` Sekunden."""
    out = []
    for i, (x, dx, dy) in enumerate(lanes):
        out.append({"kind": "meteor", "x": x, "y": 1, "w": 1, "h": 1, "dx": dx, "dy": dy, "fall": fall, "warn": 2.0,
                    "period": period, "phase": round((period - t0 - i * gap) % period, 2)})
    return out


def MP(pad, x, y, w=5, dx=2, period=16.0, phase=0.0):
    return {"kind": "pad", "pad": str(pad), "x": x, "y": y, "w": w, "dx": dx, "period": period, "phase": phase}


def base(g, f_cols=(11, 16), pad3=True, pad4=True, narrow=()):
    """Gemeinsames Gerüst: Start unten links (Pad 1), Ablage links oben (2), Pfeiler mitte (3), Ablage rechts oben (4),
    unten rechts (5), Tankpad links unten."""
    g.rect("#", 1, 20, 38, 20)
    g.pad("1", 2, 8, 19)
    g.rect("#", 1, 9, 8, 10); g.pad("2", 2, 5 if 2 in narrow else 6, 8)
    if pad3:
        g.rect("#", 17, 14, 22, 19); g.pad("3", 17, 21, 13)
    if pad4:
        g.rect("#", 32, 7, 38, 8); g.pad("4", 34 if 4 in narrow else 33, 37, 6)
    g.pad("5", 31 if 5 in narrow else 30, 34 if 5 in narrow else 36, 19)
    g.rect("P", f_cols[0], 17, f_cols[0], 18); g.pad("F", f_cols[0], f_cols[1], 19)
    g.gate()
    g.put("S", 5, 18)


# ---- S3-01 Schrottplatz: zwei Trümmerbahnen
g = Grid(); base(g); V1(g)
make("S3-01", "Schrottlawine", "Scrap Avalanche", g, seq(1),
     [D(10, 11, dx=5, period=10.0), D(27, 10, dy=3, period=7.0, w=1, h=1)], ["debris", "chicane"])

# ---- S3-02 Trümmerfeld: Zapfen links, drei Bahnen
g = Grid(); base(g); V1(g)
make("S3-02", "Trümmerfeld", "Debris Field", g, seq(2),
     [D(9, 12, dx=4, period=9.0), D(27, 10, dy=3, period=7.0, w=1, h=1, phase=2.0), D(27, 4, dx=3, period=11.0, w=3, phase=3.0)], ["debris", "chicane"], fragile=(2,))

# ---- S3-03 Fließband: Pad 3 fährt auf einer Schiene
g = Grid(); base(g, pad3=False); V3(g)
make("S3-03", "Fließband", "Conveyor", g, seq(3),
     [MP(3, 16, 13, w=5, dx=3, period=16.0), D(27, 10, dy=3, period=8.0, w=1, h=1)], ["debris", "moving_pads", "chicane"])

# ---- S3-04 Kranbahn: Zapfen, zwei Bahnen
g = Grid(); base(g); V1(g)
make("S3-04", "Kranbahn", "Crane Track", g, seq(4),
     [D(25, 12, dy=3, period=9.0, w=2, h=1), D(10, 12, dx=3, period=8.0, phase=2.0), D(27, 4, dx=3, period=11.0, w=3, phase=3.0)], ["debris", "chicane"])

# ---- S3-05 Pendelhalle: kreisende Trümmer, niedriger Block
g = Grid(); base(g); V1(g); V2(g)
make("S3-05", "Pendelhalle", "Pendulum Hall", g, seq(5),
     [D(11, 12, dx=3, dy=3, period=9.0, shape="circle"), D(27, 11, dx=3, dy=3, period=9.0, phase=4.5, shape="circle")]
     + METS([(9, 0, 18), (23, 0, 18), (29, 0, 18)], period=22.0, t0=12.0), ["debris", "chicane"], fragile=(3,))

# ---- S3-06 Doppelfähre: zwei fahrende Pads
g = Grid(); base(g, pad3=False, pad4=False, narrow=(4,)); V1(g)
make("S3-06", "Doppelfähre", "Twin Ferry", g, seq(6),
     [MP(3, 15, 13, w=5, dx=3, period=12.0), MP(4, 31, 7, w=4, dx=2, period=18.0, phase=3.0), D(24, 5, dx=3, period=9.0, w=2, h=1, phase=1.0)], ["debris", "moving_pads", "chicane"])

# ---- S3-07 Schrottpresse: Trümmerpaar unten, Blöcke
g = Grid(); base(g, narrow=(2,)); V2(g); V3(g)
make("S3-07", "Schrottpresse", "Scrap Press", g, seq(7),
     [D(9, 11, dx=4, period=9.0), D(25, 9, dy=3, period=8.0, w=1, h=1), D(27, 4, dx=3, period=11.0, w=3, phase=3.0)]
     + METS([(9, 0, 18), (23, 0, 18), (29, 0, 18)], period=20.0, t0=11.0), ["debris", "chicane"], fragile=(2,))

# ---- S3-08 Altmetall: fahrendes Pad plus Trümmer, Zapfen
g = Grid(); base(g, pad3=False, narrow=(2, 5)); V1(g)
make("S3-08", "Altmetall", "Scrap Metal", g, seq(8),
     [MP(3, 17, 13, w=5, dx=3, period=13.0), D(9, 12, dx=4, period=9.0), D(27, 5, dx=3, period=9.0, w=2, h=1, phase=2.0), D(30, 12, dx=2, period=8.0, w=2, h=1, phase=1.0)]
     + METS([(9, 0, 18), (23, 0, 18), (28, 0, 18)], period=24.0, t0=8.0), ["debris", "moving_pads", "chicane"])

# ---- S3-09 Wrackgasse: enge Gasse, drei Bahnen
g = Grid(); base(g, narrow=(2, 4, 5)); V1(g); V3(g)
make("S3-09", "Wrackgasse", "Wreck Alley", g, seq(9),
     [D(8, 12, dx=3, period=8.0), D(26, 9, dy=3, period=7.0, w=1, h=1), D(26, 4, dx=3, period=9.0, w=2, phase=3.0), SL(24, 10, w=3, h=2, dx=4, period=13.0)]
     + METS([(23, 0, 18), (29, 0, 18)], period=20.0, t0=15.0, gap=1.2), ["debris", "chicane"])

# ---- S3-10 Schrottlawine: Bahnen, Blöcke
g = Grid(); base(g); V1(g); V3(g)
make("S3-10", "Schrottplatz", "Scrap Yard", g, seq(10),
     [D(9, 11, dx=4, period=9.0), D(25, 9, dy=3, period=8.0, w=1, h=1), D(27, 4, dx=3, period=11.0, w=3, phase=3.0)], ["debris", "chicane"])

# ---- S3-11 Gürtelwächter: alles zusammen
g = Grid(); base(g, pad3=False, pad4=False, narrow=(2, 5)); V1(g); V2(g)
make("S3-11", "Gürtelwächter", "Belt Guardian", g, seq(11),
     [MP(3, 15, 13, w=5, dx=3, period=12.0), MP(4, 31, 7, w=5, dx=2, period=17.0, phase=2.0),
      D(11, 6, dx=3, period=9.0)]
     + METS([(23, 0, 18), (26, 0, 14)], period=18.0, t0=6.0, gap=1.2), ["debris", "moving_pads", "chicane"])
