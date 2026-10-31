"""Bausteine für die Level-Erzeuger: Aufträge, Trümmer, Meteoriten, Schieber, fahrende Pads, Magnete."""
import random

NAMES = [("Mika", "f"), ("Odo", "m"), ("Lena", "f"), ("Jonas", "m"), ("Ines", "f"), ("Ben", "m"), ("Nora", "f"), ("Tarek", "m")]


def seq(seed, n, pads, start=1, hospital_at=None):
    """Auftragsfolge: erster Fahrgast nicht am Startpad, keine Kettenüberschneidung, letzter zum Ausgang.
    hospital_at = Index eines Krankentransports (Ziel "H")."""
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
            if hospital_at is not None and i == hospital_at:
                out.append((str(frm), "H"))
                prev_to = 0
                continue
            out.append((str(frm), str(to)))
            prev_to = to
        used = {a for a, _ in out} | {b for _, b in out if b not in ("exit", "H")}
        if len(used) >= pads:
            return out


def jobs_of(sq, base=120, fragile=()):
    res = []
    for i, (a, b) in enumerate(sq):
        n, gnd = NAMES[i % len(NAMES)]
        j = {"from": a, "to": b, "fare": base + 10 * i, "par": 50, "passenger": n, "gender": gnd}
        if i in fragile or b == "H":
            j["fragile"] = True
            j["fare"] = int(j["fare"] * 1.25)
        res.append(j)
    return res


def D(x, y, dx=0, dy=0, period=8.0, phase=0.0, w=2, h=1):
    period = round(period * 0.82 * (0.85 + 0.3 * random.Random(x * 31 + y * 17 + int(period * 10)).random()), 1)
    return {"kind": "debris", "x": x, "y": y, "w": w, "h": h, "dx": dx, "dy": dy, "period": period, "phase": phase, "shape": "line"}


def SL(x, y, w=3, h=2, dx=4, dy=0, period=12.0, phase=0.0):
    return {"kind": "slider", "x": x, "y": y, "w": w, "h": h, "dx": dx, "dy": dy, "period": period, "phase": phase, "shape": "line"}


def MP(pad, x, y, w=5, dx=2, period=16.0, phase=0.0):
    return {"kind": "pad", "pad": str(pad), "x": x, "y": y, "w": w, "dx": dx, "period": period, "phase": phase}


def METS(lanes, period=22.0, t0=10.0, gap=0.9, fall=1.6):
    out = []
    for i, (x, dx, dy) in enumerate(lanes):
        out.append({"kind": "meteor", "x": x, "y": 1, "w": 1, "h": 1, "dx": dx, "dy": dy, "fall": fall, "warn": 2.0,
                    "period": period, "phase": round((period - t0 - i * gap) % period, 2)})
    return out


KS = 2.0


def MAG(cx, cy, k, r=4.5, period=0.0, on=0.0, phase=0.0):
    z = {"kind": "magnet", "cx": cx, "cy": cy, "r": r, "k": round(k * KS)}
    if period > 0.0:
        z.update({"period": period, "on": on, "phase": phase})
    return z


def BEAM(x, y, w, h, period=9.0, on=3.0, phase=0.0, warn=2.0):
    """Plasmastrahl: Rechteck in Tiles, nur in den ersten `on` Sekunden jeder Periode aktiv."""
    return {"kind": "beam", "x": x, "y": y, "w": w, "h": h, "period": period, "on": on, "phase": phase, "warn": warn}


def HEAT(x0, x1, y0, y1, period=0.0, on=0.0, phase=0.0):
    z = {"kind": "heat", "x": x0, "y": y0, "w": x1 - x0 + 1, "h": y1 - y0 + 1}
    if period > 0.0:
        z.update({"period": period, "on": on, "phase": phase})
    return z
