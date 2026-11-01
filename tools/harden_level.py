"""Macht ein Level gezielt schwerer („Finale“): fügt nacheinander bekannte Mechaniken, Engstellen und kleinste Landeplattformen hinzu –
jede Änderung nur, wenn der Autopilot das Level danach noch löst (Hülle ≥ 95 %, alle Fahrgäste) und das Landefenster ≥ 18 px bleibt.
Aufruf (Projektwurzel):  python3 tools/harden_level.py <Levelnummer> [--rounds=30] [--batch=16]
Gierig: je Runde werden --batch zufällige Änderungen bewertet, die mit dem höchsten Schwierigkeits-Score (LevelMetrics) wird übernommen."""
import sys, os, json, random, copy
sys.path.insert(0, "tools")
import build_sector as bs

W, H = 40, 22


def level_file(n):
    s, i = (n - 1) // 11 + 1, (n - 1) % 11 + 1
    return "data/levels/s%d_%02d.json" % (s, i)


class Lv:
    def __init__(self, d):
        self.d = d
        self.g = [list(r) for r in d["map"]]

    def commit(self):
        self.d["map"] = ["".join(r) for r in self.g]
        return self.d

    def cell(self, x, y):
        return self.g[y][x] if 0 <= y < H and 0 <= x < W else "#"

    def pads(self):
        out = {}
        for y, row in enumerate(self.g):
            x = 0
            while x < W:
                c = row[x]
                if c in "123456789FLH":
                    x1 = x
                    while x1 + 1 < W and row[x1 + 1] == c:
                        x1 += 1
                    out[c] = (x, x1, y)
                    x = x1
                x += 1
        return out

    def reserved(self):
        """Zellen, die nicht angefasst werden: um Pads, Start, Tor, Pumpe, Zonen und Mover-Bahnen."""
        res = set()
        for c, (x0, x1, y) in self.pads().items():
            for xx in range(x0 - 1, x1 + 2):
                for yy in range(y - 4, y + 1):
                    res.add((xx, yy))
        for y, row in enumerate(self.g):
            for x, c in enumerate(row):
                if c in "SEP" or c in "abcde":
                    for xx in range(x - 1, x + 2):
                        for yy in range(y - 1, y + 2):
                            res.add((xx, yy))
        for z in self.d.get("zones", []):
            if z["kind"] == "magnet":
                r = z["r"]
                for xx in range(int(z["cx"] - r), int(z["cx"] + r) + 1):
                    for yy in range(int(z["cy"] - r), int(z["cy"] + r) + 1):
                        res.add((xx, yy))
            else:
                for xx in range(z["x"], z["x"] + z["w"]):
                    for yy in range(z["y"], z["y"] + z["h"]):
                        res.add((xx, yy))
        for m in self.d.get("movers", []):
            if m["kind"] == "vehicle":
                for a, b in zip(m["path"], m["path"][1:]):
                    for t in range(0, 41):
                        xx = int(a[0] + (b[0] - a[0]) * t / 40.0); yy = int(a[1] + (b[1] - a[1]) * t / 40.0)
                        for dy in (-1, 0, 1):
                            res.add((xx, yy + dy))
            elif m["kind"] in ("meteor", "beam", "debris", "slider", "pad"):
                x0 = m["x"] - int(abs(m.get("dx", 0)))
                x1 = m["x"] + m.get("w", 1) + int(abs(m.get("dx", 0)))
                y0 = m["y"] - int(abs(m.get("dy", 0)))
                y1 = m["y"] + m.get("h", 1) + int(abs(m.get("dy", 0))) + (18 if m["kind"] == "meteor" else 0)
                for xx in range(x0, x1 + 1):
                    for yy in range(y0, y1 + 1):
                        res.add((xx, yy))
        return res

    def light(self, zones=True):
        """Nur Pads, Start/Tor/Pumpe, Kraftzonen (dürfen sich nicht überlappen) und Fahrzeugbahnen sind tabu; Gefahren dürfen sich überlagern."""
        res = set()
        for c, (x0, x1, y) in self.pads().items():
            for xx in range(x0 - 1, x1 + 2):
                for yy in range(y - 4, y + 1):
                    res.add((xx, yy))
        for y, row in enumerate(self.g):
            for x, c in enumerate(row):
                if c in "SEP":
                    for xx in range(x - 1, x + 2):
                        for yy in range(y - 1, y + 2):
                            res.add((xx, yy))
        for z in (self.d.get("zones", []) if zones else []):
            if z["kind"] == "magnet":
                r = z["r"]
                for xx in range(int(z["cx"] - r), int(z["cx"] + r) + 1):
                    for yy in range(int(z["cy"] - r), int(z["cy"] + r) + 1):
                        res.add((xx, yy))
            elif z["kind"] in ("wind", "gravity"):
                for xx in range(z["x"], z["x"] + z["w"]):
                    for yy in range(z["y"], z["y"] + z["h"]):
                        res.add((xx, yy))
        for m in self.d.get("movers", []):
            if m["kind"] == "vehicle":
                for a, b in zip(m["path"], m["path"][1:]):
                    for t in range(0, 41):
                        xx = int(a[0] + (b[0] - a[0]) * t / 40.0); yy = int(a[1] + (b[1] - a[1]) * t / 40.0)
                        for dy in (-1, 0, 1):
                            res.add((xx, yy + dy))
        return res

    def free_rect(self, x, y, w, h, res):
        for yy in range(y, y + h):
            for xx in range(x, x + w):
                if self.cell(xx, yy) != "." or (xx, yy) in res:
                    return False
        return True


def op_meteor(L, rnd):
    res = set()                                              # Meteoritenbahnen dürfen Fahrzeugbahnen kreuzen
    for _ in range(80):
        x = rnd.randint(3, 36)
        if any(abs(m["x"] - x) < 3 for m in L.d["movers"] if m["kind"] == "meteor"):
            continue
        y = 1
        while L.cell(x, y + 1) == "." and (x, y + 1) not in res and y < 19:
            y += 1
        if y >= 9:                                           # Bahn von oben bis zum ersten Hindernis, mindestens 8 Felder
            L.d["movers"].append({"kind": "meteor", "x": x, "y": 1, "w": 1, "h": 1, "dx": 0, "dy": y - 1, "fall": 1.6, "warn": 2.0, "period": 22.0, "phase": round(rnd.uniform(0, 22), 1)})
            return "meteor"
    return None


def op_gravity(L, rnd):
    res = L.light()
    for _ in range(120):
        w, h = rnd.randint(3, 4), rnd.randint(3, 5)
        x, y = rnd.randint(2, 35), rnd.randint(3, 15)
        if L.free_rect(x, y, w, h, res):
            L.d["zones"].append({"kind": "gravity", "x": x, "y": y, "w": w, "h": h, "g": rnd.choice([0.45, 1.8])})
            return "gravity"
    return None


def op_block(L, rnd, kind):
    res = L.light(False)
    for _ in range(120):
        x, y = rnd.randint(2, 36), rnd.randint(4, 14)
        w, h = (2, 3) if kind == "slider" else (1, 2)
        dy = 2
        if L.free_rect(x, y - dy, w, h + 2 * dy, res):
            L.d["movers"].append({"kind": kind, "x": x, "y": y, "w": w, "h": h, "dx": 0, "dy": dy, "period": round(rnd.uniform(6, 9), 1), "phase": round(rnd.uniform(0, 8), 1), "shape": "line"})
            return kind
    return None


def op_heat(L, rnd):
    res = L.reserved()
    for _ in range(60):
        w, h = rnd.randint(2, 3), rnd.randint(2, 4)
        x, y = rnd.randint(2, 35), rnd.randint(3, 16)
        if L.free_rect(x, y, w, h, res):
            z = {"kind": "heat", "x": x, "y": y, "w": w, "h": h}
            if rnd.random() < 0.5:
                z.update({"period": 7.0, "on": 3.5, "phase": round(rnd.uniform(0, 7), 1)})
            L.d["zones"].append(z)
            return "heat"
    return None


def op_beam(L, rnd):
    res = L.reserved()
    for _ in range(60):
        h = rnd.randint(5, 9)
        x, y = rnd.randint(2, 37), rnd.randint(3, 12)
        if L.free_rect(x, y, 1, h, res):
            L.d["movers"].append({"kind": "beam", "x": x, "y": y, "w": 1, "h": h, "period": 9.0, "on": 3.0, "phase": round(rnd.uniform(0, 9), 1), "warn": 2.0})
            return "beam"
    return None


def op_wall(L, rnd):
    """Engstelle: Wandblock von Decke oder Boden in den freien Raum, Lücke bleibt ≥ 3 Felder."""
    res = L.reserved()
    for _ in range(80):
        from_top = rnd.random() < 0.5
        w, h = rnd.randint(1, 3), rnd.randint(4, 9)
        x = rnd.randint(2, 36)
        y = 3 if from_top else 19 - h
        if not from_top and any(L.cell(xx, 19) not in ".#" for xx in range(x, x + w)):
            continue
        if L.free_rect(x, y, w, h, res):
            for yy in range(y, y + h):
                for xx in range(x, x + w):
                    L.g[yy][xx] = "#"
            return "wall"
    return None


def op_spikes(L, rnd):
    res = L.light(False)
    for _ in range(200):
        x, y = rnd.randint(2, 36), rnd.randint(4, 18)
        n = rnd.randint(3, 6)
        if all(L.cell(x + i, y) == "." and (x + i, y) not in res and L.cell(x + i, y + 1) == "#" for i in range(n)):
            for i in range(n):
                L.g[y][x + i] = "^"
            return "spikes"
    return None


def op_doorwall(L, rnd):
    """Schleuse in einem von der Decke hängenden Pfeiler: drei Torzellen im Pfeiler, daneben bleibt (meist) Platz."""
    used = set(L.d.get("doors", {}))
    ch = next((c for c in "abcde" if c not in used), None)
    if ch is None:
        return None
    res = L.light(False)
    for _ in range(200):
        x, y0, h = rnd.randint(3, 36), 3, rnd.randint(8, 11)
        if L.free_rect(x, y0, 1, h, res) and all(L.cell(x - 1, y) == "." and L.cell(x + 1, y) == "." for y in range(y0, y0 + h)):
            for y in range(y0, y0 + h):
                L.g[y][x] = "#"
            for y in range(y0 + h - 4, y0 + h - 1):
                L.g[y][x] = ch
            L.d.setdefault("doors", {})[ch] = {"period": 8.0, "open": 4.5, "phase": round(rnd.uniform(0, 8), 1)}
            return "door"
    return None


def op_door(L, rnd):
    used = set(L.d.get("doors", {}))
    ch = next((c for c in "abcde" if c not in used), None)
    if ch is None:
        return None
    res = L.light()
    for _ in range(300):
        x, y = rnd.randint(3, 35), rnd.randint(4, 14)
        if all(L.cell(x, y + i) == "#" for i in range(3)) and all(L.cell(x - 1, y + i) == "." and L.cell(x + 1, y + i) == "." for i in range(3)) \
                and all((x, y + i) not in res for i in range(3)) and L.cell(x, y - 1) == "#" and L.cell(x, y + 3) == "#":
            for i in range(3):
                L.g[y + i][x] = ch
            L.d.setdefault("doors", {})[ch] = {"period": 8.0, "open": 4.5, "phase": round(rnd.uniform(0, 8), 1)}
            return "door"
    return None


def op_shrink(L, rnd):
    pads = L.pads()
    cands = [c for c, (x0, x1, y) in pads.items() if c in "123456789H" and x1 - x0 + 1 > 4]
    if not cands:
        return None
    c = rnd.choice(cands)
    x0, x1, y = pads[c]
    keep0 = x0 + (x1 - x0 + 1 - 4) // 2
    for x in range(x0, x1 + 1):
        if not (keep0 <= x < keep0 + 4):
            L.g[y][x] = "#"
    return "pad%s" % c


def op_mag(L, rnd):
    res = L.light()
    for _ in range(200):
        x, y = rnd.randint(6, 33), rnd.randint(5, 14)
        if L.free_rect(x - 2, y - 2, 5, 5, res):
            z = {"kind": "magnet", "cx": x + 0.5, "cy": y + 0.5, "r": 3.0, "k": rnd.choice([-180, 180])}
            if rnd.random() < 0.5:
                z.update({"period": 9.0, "on": 4.5, "phase": round(rnd.uniform(0, 9), 1)})
            L.d["zones"].append(z)
            return "magnet"
    return None


OPS = {"meteor": op_meteor, "gravity": op_gravity, "slider": lambda L, r: op_block(L, r, "slider"), "debris": lambda L, r: op_block(L, r, "debris"),
       "heat": op_heat, "beam": op_beam, "wall": op_wall, "spikes": op_spikes, "door": op_doorwall, "shrink": op_shrink, "magnet": op_mag}


def main():
    n = int(sys.argv[1])
    rounds, batch = 30, 16
    for a in sys.argv:
        if a.startswith("--rounds="): rounds = int(a[9:])
        if a.startswith("--batch="): batch = int(a[8:])
    fn = level_file(n)
    cur = json.load(open(fn))
    base = bs.run_eval([fn])[fn]
    print("Start: Score %.1f, gültig=%s" % (base["score"], bs.valid(cur, base)), flush=True)
    best_score = base["score"]
    rnd = random.Random(99)
    weights = ["meteor", "gravity", "slider", "debris", "heat", "beam", "wall", "wall", "wall", "spikes", "door", "shrink", "shrink", "magnet"]
    musts = []
    for a in sys.argv:
        if a.startswith("--musts="):
            musts = a[8:].split(",")
    for must in musts:                                     # Pflicht-Mechaniken: je Typ mehrere Anläufe, die erste gültige Variante bleibt
        for attempt in range(8):
            cands, paths = {}, []
            for k in range(batch):
                d = copy.deepcopy(cur)
                L = Lv(d)
                tag = OPS[must](L, rnd)
                if not tag:
                    continue
                d2 = L.commit()
                p = bs.write_cand(d2, "m%d_%s_%d_%d" % (n, must, attempt, k))
                cands[p] = (tag, d2)
                paths.append(p)
            res = bs.run_eval(paths)
            okc = [(res[p]["score"], p) for p in paths if res.get(p) and bs.valid(cands[p][1], res[p]) and res[p]["window"] >= 18.0 and res[p]["clear"] >= 8.0]
            print("Pflicht %s Versuch %d: %d von %d gültig" % (must, attempt, len(okc), len(paths)), flush=True)
            if okc:
                sc, p = max(okc)
                cur = cands[p][1]
                best_score = max(best_score, sc)
                json.dump(cur, open(fn, "w"), indent=1, ensure_ascii=False)
                print("  übernommen: %s -> Score %.1f" % (must, sc), flush=True)
                break
    fails = 0
    for rd in range(rounds):
        cands = {}
        paths = []
        for k in range(batch):
            d = copy.deepcopy(cur)
            L = Lv(d)
            tag = None
            for _ in range(5):
                tag = OPS[rnd.choice(weights)](L, rnd)
                if tag:
                    break
            if not tag:
                continue
            d2 = L.commit()
            d2["mechanics"] = sorted(set(d2.get("mechanics", [])))
            p = bs.write_cand(d2, "h%d_r%d_%d" % (n, rd, k))
            cands[p] = (tag, d2)
            paths.append(p)
        res = bs.run_eval(paths)
        okc = [(res[p]["score"], p) for p in paths if res.get(p) and bs.valid(cands[p][1], res[p]) and res[p]["window"] >= 18.0 and res[p]["clear"] >= 8.0]
        # Der Score der Metrik sättigt (Obergrenzen); jede gültige Verschärfung wird übernommen, solange der Score nicht merklich fällt
        good = [q for q in okc if q[0] >= best_score - 1.5]
        print("Runde %d: %d gültig, %d übernehmbar von %d" % (rd, len(okc), len(good), len(paths)), flush=True)
        if not good:
            fails += 1
            if fails >= 4:
                break
            continue
        fails = 0
        sc, p = max(good)
        sc = max(sc, best_score)
        cur = cands[p][1]
        best_score = sc
        json.dump(cur, open(fn, "w"), indent=1, ensure_ascii=False)
        print("  übernommen: %s -> Score %.1f (Fenster %.0f, Korridor %.0f, Zeit %.0f s)" % (cands[p][0], sc, res[p]["window"], res[p]["clear"], res[p]["time"]), flush=True)
    # Richtzeiten aus den Autopilot-Zeiten
    r = bs.run_eval([fn])[fn]
    times = r["times"] + [22.0]
    pars = [max(10, int(round(0.85 * t))) for t in times][: len(cur["jobs"])]
    for j, p_ in zip(cur["jobs"], pars):
        j["par"] = p_
    json.dump(cur, open(fn, "w"), indent=1, ensure_ascii=False)
    r = bs.run_eval([fn])[fn]
    print("Ende: Score %.1f gültig=%s Fenster %.0f Korridor %.0f" % (r["score"], bs.valid(cur, r), r["window"], r["clear"]), flush=True)


if __name__ == "__main__":
    main()
