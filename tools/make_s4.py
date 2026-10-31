"""Sektor 4 'Magnetfeld', Level 34–44 (S4-01 … S4-11). Aufruf aus der Projektwurzel.
Neue Mechanik: Magnetzonen (anziehend/abstoßend, teils pulsierend; JSON "zones"). Sechs Passagierpads, sieben Aufträge.
Lebens-Stationen in Level 35 und 40. Pars aus tools/s4_pars.json (Bot-Zeit × 1,3 + 8 s)."""
import sys, json, os, random
sys.path.insert(0, "tools")
from levelkit import Grid, write

PARS = json.load(open("tools/s4_pars.json")) if os.path.exists("tools/s4_pars.json") else {}
FINAL = {"S4-04": "S4-01", "S4-02": "S4-02", "S4-01": "S4-03", "S4-10": "S4-04", "S4-03": "S4-05", "S4-09": "S4-06", "S4-07": "S4-07", "S4-06": "S4-08", "S4-08": "S4-09", "S4-05": "S4-10", "S4-11": "S4-11"}      # Entwurfsschlüssel -> endgültige ID (nach gemessener Schwierigkeit)
BOOST = {"S4-%02d" % i: 26 for i in range(1, 12)}                 # zusätzliche Dornenbänder an der Decke je Entwurfsschlüssel
NAMES = [("Mika", "f"), ("Odo", "m"), ("Lena", "f"), ("Jonas", "m"), ("Ines", "f"), ("Ben", "m"), ("Nora", "f"), ("Tarek", "m")]
UNDER = {}      # zusätzliche Dornen unter den Ablagen je Entwurfsschlüssel (Standard 26)
LSET = ("S4-02", "S4-07")      # (nach endgültiger ID)      # Lebens-Stationen in Level 35 und 40


def seq(seed, n=7, pads=6, start=1):
    """Auftragsfolge: erster Fahrgast nicht am Startpad, keine Kettenüberschneidung, letzter zum Ausgang."""
    rnd = random.Random(seed)
    while True:
        out = []
        prev_to = start
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


def jobs_of(sq, base=130):
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


def under_spikes(g, n):
    """Dornen unter den Ablagen (Pad 2, 4, 6) und auf dem Boden zwischen Pfeiler und Pad 5: mehr Gefahr bei gleichem Grundriss."""
    cells = [(x, 11) for x in range(1, 9)] + [(x, 9) for x in range(32, 39)] + [(x, 15) for x in range(25, 31)] + [(x, 19) for x in range(28, 22, -1)]
    placed = 0
    for x, y in cells:
        if placed >= n:
            break
        if g.g[y][x] == ".":
            g.g[y][x] = "^"
            placed += 1


def MAG(cx, cy, k, r=4.5, period=0.0, on=0.0, phase=0.0):
    """Magnetzone: k > 0 zieht zur Mitte, k < 0 stößt ab; period > 0: nur die ersten `on` Sekunden jeder Periode aktiv."""
    z = {"kind": "magnet", "cx": cx, "cy": cy, "r": r, "k": k}
    if period > 0.0:
        z.update({"period": period, "on": on, "phase": phase})
    return z


def V1(g): g.rect("#", 12, 1, 15, 8)          # hängender Zapfen links der Torzone
def V3(g): g.rect("#", 27, 1, 28, 4)          # kleiner hängender Zapfen rechts
def V4(g): g.rect("#", 8, 15, 10, 19)         # Sockel zwischen Startpad und Tankpad (Pad 1 bleibt frei)


def base(g, narrow=()):
    """Gerüst mit sechs Passagierpads: Start unten links (1), Ablage links oben (2), Pfeiler mitte (3), Ablage rechts oben (4),
    unten rechts (5), schwebende Ablage rechts mitte (6), Tankpad unten links-mitte."""
    g.rect("#", 1, 20, 38, 20)
    g.pad("1", 2, 8, 19)
    g.rect("#", 1, 9, 8, 10); g.pad("2", 2, 5 if 2 in narrow else 6, 8)
    g.rect("#", 17, 14, 22, 19); g.pad("3", 17, 21, 13)
    g.rect("#", 32, 7, 38, 8); g.pad("4", 34 if 4 in narrow else 33, 37, 6)
    g.pad("5", 31 if 5 in narrow else 30, 34 if 5 in narrow else 36, 19)
    g.rect("#", 25, 13, 30, 14); g.rect("6", 27 if 6 in narrow else 26, 12, 30, 12)
    g.rect("P", 11, 17, 11, 18); g.pad("F", 11, 16, 19)
    g.gate()
    g.put("S", 5, 18)


# Magnetorte (Tile-Koordinaten): A links-mittig, B über dem Pfeiler (Torzone), C rechts-mittig, D unten zwischen Pfeiler und Pad 5
A = (12.5, 12.0); B = (22.5, 8.0); C = (28.5, 9.0); D = (26.5, 17.0); E = (13.5, 5.5)

SPECS = [
    # key, Name DE, Name EN, Varianten, Zonen, narrow
    ("S4-01", "Erste Spule", "First Coil", [], [MAG(*A, 45)], ()),
    ("S4-02", "Abstoßung", "Repulsion", [V3], [MAG(*C, -38)], (2,)),
    ("S4-03", "Zwillingspole", "Twin Poles", [V1], [MAG(*A, 50), MAG(*C, -50)], ()),
    ("S4-04", "Pulsschlag", "Heartbeat", [], [MAG(*B, 60, period=8.0, on=4.0)], ()),
    ("S4-05", "Magnetschacht", "Magnet Shaft", [V1], [MAG(*A, -55), MAG(*D, 50, period=9.0, on=5.0)], (5,)),
    ("S4-06", "Feldlinien", "Field Lines", [V3], [MAG(*A, 45), MAG(*C, 50), MAG(*B, -50)], (2,)),
    ("S4-07", "Polwechsel", "Pole Swap", [V1], [MAG(*C, 60, period=7.0, on=3.5), MAG(*A, -60, period=7.0, on=3.5, phase=3.5)], (2, 5)),
    ("S4-08", "Schleusenfeld", "Lock Field", [V1, V3], [MAG(*A, 50), MAG(*B, -55), MAG(*D, 45, period=8.0, on=4.0)], (2, 5)),
    ("S4-09", "Dynamo", "Dynamo", [V1], [MAG(*A, 55, period=6.0, on=3.0), MAG(*C, -55, period=9.0, on=4.5), MAG(*B, 50, period=7.0, on=3.5, phase=2.0)], (2, 4, 5)),
    ("S4-10", "Gegenpol", "Counter Pole", [V1, V3], [MAG(*A, -60), MAG(*C, 60), MAG(*B, -50, period=8.0, on=4.0), MAG(*D, 50)], (2, 4, 5)),
    ("S4-11", "Magnetmeister", "Magnet Master", [V1, V3], [MAG(*A, 55, period=7.0, on=3.5), MAG(*C, -55, period=7.0, on=3.5, phase=3.5), MAG(*B, 55), MAG(*D, -50, period=9.0, on=4.5), MAG(*E, 45)], (2, 4, 5, 6)),
]

for i, (key, de, en, variants, zones, narrow) in enumerate(SPECS):
    fid = FINAL[key]
    g = Grid()
    base(g, narrow)
    for v in variants:
        v(g)
    boost_spikes(g, BOOST.get(key, 0))
    if fid in LSET:
        g.rect("L", 24, 19, 27, 19)
    under_spikes(g, UNDER.get(key, 26))
    jobs = jobs_of(seq(100 + int(key[-2:])))
    for j, p in zip(jobs, PARS.get(fid, [])):
        j["par"] = p
    mech = ["spikes", "chicane", "magnets"]
    if fid in LSET:
        mech.append("life_station")
    if any("period" in z for z in zones):
        mech.append("pulsing_fields")
    if any(z["k"] < 0 for z in zones):
        mech.append("repel_fields")
    if any(z["k"] > 0 for z in zones):
        mech.append("attract_fields")
    write(fid, 4, int(fid[-2:]), de, en, g, jobs, zones=zones, mechanics=mech)
    print("== %s %s" % (fid, de))
    g.show()
