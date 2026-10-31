"""Ähnlichkeit der Level-Grundrisse: Jaccard über Fels-/Pad-Zellen (ohne Rand und Tor) und über die Pad-Zellen allein.
Aufruf: python3 tools/similarity.py [--min 0.5]   -> listet Paare, die einander zu ähnlich sehen."""
import json, glob, sys, itertools

def load():
    out = {}
    for f in sorted(glob.glob("data/levels/s*.json")):
        d = json.load(open(f))
        n = (d["sector"] - 1) * 11 + d["index"]
        solid, pads = set(), set()
        for y, row in enumerate(d["map"]):
            for x, c in enumerate(row):
                if x in (0, 39) or y in (0, 20, 21):
                    continue
                if c in "#^":
                    solid.add((x, y))
                elif c in "123456789FLH":
                    pads.add((x, y))
        # Mover-Pads zählen als Pad-Zellen
        for m in d.get("movers", []):
            if m["kind"] == "pad":
                for xx in range(m["x"], m["x"] + m["w"]):
                    pads.add((xx, m["y"]))
        out[n] = (d["id"], solid | pads, pads, d)
    return out

def jac(a, b):
    return len(a & b) / max(1, len(a | b))

def pairs(lv, lo=0.0):
    res = []
    for a, b in itertools.combinations(sorted(lv), 2):
        s = jac(lv[a][1], lv[b][1])
        p = jac(lv[a][2], lv[b][2])
        res.append((max(s, p), s, p, a, b))
    return sorted(res, reverse=True)

if __name__ == "__main__":
    lv = load()
    th = float(sys.argv[sys.argv.index("--min") + 1]) if "--min" in sys.argv else 0.5
    ps = pairs(lv)
    print("Verteilung: Median %.2f, Max %.2f" % (sorted(p[0] for p in ps)[len(ps) // 2], ps[0][0]))
    for m, s, p, a, b in ps:
        if m < th:
            break
        print("Level %2d / %2d: Gesamt %.2f  Pads %.2f" % (a, b, s, p))
