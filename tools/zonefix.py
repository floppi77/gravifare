"""Prüft/behebt überlappende Kraftzonen (Strömung, Schwerkraft, Magnet), damit sie sich nicht gegenseitig aufheben.
Aufruf: python3 tools/zonefix.py [--fix]   (ohne --fix nur Bericht)."""
import json, glob, sys, math, random

FORCE = ("wind", "gravity", "magnet")


def shape(z):
    if z["kind"] == "magnet":
        return ("c", z["cx"], z["cy"], z["r"])
    return ("r", z["x"], z["y"], z["x"] + z["w"], z["y"] + z["h"])


def overlap(a, b, pad=0.0):
    sa, sb = shape(a), shape(b)
    if sa[0] == "c" and sb[0] == "c":
        return math.hypot(sa[1] - sb[1], sa[2] - sb[2]) < sa[3] + sb[3] + pad
    if sa[0] == "r" and sb[0] == "r":
        return not (sa[3] + pad <= sb[1] or sb[3] + pad <= sa[1] or sa[4] + pad <= sb[2] or sb[4] + pad <= sa[2])
    c, r = (sa, sb) if sa[0] == "c" else (sb, sa)
    dx = max(r[1] - c[1], 0, c[1] - r[3])
    dy = max(r[2] - c[2], 0, c[2] - r[4])
    return math.hypot(dx, dy) < c[3] + pad


def conflicts(zs):
    out = []
    for i in range(len(zs)):
        for j in range(i + 1, len(zs)):
            if zs[i]["kind"] in FORCE and zs[j]["kind"] in FORCE and overlap(zs[i], zs[j]):
                out.append((i, j))
    return out


def free_rect(d, w, h, others, rnd):
    rows = d["map"]
    H, W = len(rows), len(rows[0])
    cands = []
    for y in range(4, 18 - h):
        for x in range(3, W - 3 - w):
            if any(rows[yy][xx] != "." for yy in range(y - 1, y + h + 1) for xx in range(x - 1, x + w + 1)):
                continue
            # Abstand zu Pads, Start, Pumpe, Tor
            near = False
            for yy in range(y - 4, y + h + 3):
                for xx in range(x - 3, x + w + 3):
                    if 0 <= yy < H and 0 <= xx < W and rows[yy][xx] in "123456789FLHSEP":
                        near = True
            if near or (13 <= x + w and x <= 26 and y <= 9):
                continue
            z = {"kind": "wind", "x": x, "y": y, "w": w, "h": h}
            if any(overlap(z, o, 0.5) for o in others):
                continue
            cands.append((x, y))
    return rnd.choice(cands) if cands else None


def main():
    fix = "--fix" in sys.argv
    for f in sorted(glob.glob("data/levels/s*.json")):
        d = json.load(open(f))
        zs = d.get("zones", [])
        cf = conflicts(zs)
        if not cf:
            continue
        n = (d["sector"] - 1) * 11 + d["index"]
        print("Level", n, [(zs[i]["kind"], zs[j]["kind"]) for i, j in cf])
        if not fix:
            continue
        rnd = random.Random(n)
        for _ in range(10):
            cf = conflicts(zs)
            if not cf:
                break
            i, j = cf[0]
            if zs[i]["kind"] == "magnet" and zs[j]["kind"] == "magnet":     # zwei Magnete: den zweiten Radius verkleinern
                dist = math.hypot(zs[i]["cx"] - zs[j]["cx"], zs[i]["cy"] - zs[j]["cy"])
                zs[j]["r"] = round(max(2.6, dist - zs[i]["r"] - 0.2), 2)
                if overlap(zs[i], zs[j]):
                    zs[i]["r"] = round(max(2.6, dist - zs[j]["r"] - 0.2), 2)
                if overlap(zs[i], zs[j]):
                    break
                continue
            # Magnet gegen Rechteck: Magnetradius bis an die Kante verkleinern, wenn noch ≥ 2,6 Tiles bleiben
            mk = i if zs[i]["kind"] == "magnet" else (j if zs[j]["kind"] == "magnet" else None)
            if mk is not None:
                other = zs[j if mk == i else i]
                m = zs[mk]
                if other["kind"] != "magnet":
                    dx = max(other["x"] - m["cx"], 0, m["cx"] - (other["x"] + other["w"]))
                    dy = max(other["y"] - m["cy"], 0, m["cy"] - (other["y"] + other["h"]))
                    dist = math.hypot(dx, dy)
                    if dist - 0.2 >= 2.6:
                        m["r"] = round(dist - 0.2, 2)
                        continue
            # Rechteck-Zone gegen Hindernis (anderes Rechteck oder Kreis-Hüllquadrat): größtes Reststück behalten
            cand = [(i, j), (j, i)]
            done = False
            for (ka, kb) in cand:
                if zs[ka]["kind"] == "magnet":
                    continue
                R = zs[ka]
                ob = shape(zs[kb])
                if ob[0] == "c":
                    ob = ("r", ob[1] - ob[3], ob[2] - ob[3], ob[1] + ob[3], ob[2] + ob[3])
                x0, y0, x1, y1 = R["x"], R["y"], R["x"] + R["w"], R["y"] + R["h"]
                parts = [(x0, y0, min(x1, ob[1]), y1), (max(x0, ob[3]), y0, x1, y1), (x0, y0, x1, min(y1, ob[2])), (x0, max(y0, ob[4]), x1, y1)]
                parts = [(a_, b_, c_, d_) for (a_, b_, c_, d_) in parts if c_ - a_ >= 3 and d_ - b_ >= 3]
                if not parts:
                    continue
                best = max(parts, key=lambda q: (q[2] - q[0]) * (q[3] - q[1]))
                R["x"], R["y"], R["w"], R["h"] = int(best[0]), int(best[1]), int(best[2] - best[0]), int(best[3] - best[1])
                done = True
                break
            if not done:
                # Kein Reststück: die Zone mit den meisten Konflikten entfällt (je Art bleibt mindestens eine erhalten)
                cnt = {}
                for (a_, b_) in cf:
                    cnt[a_] = cnt.get(a_, 0) + 1
                    cnt[b_] = cnt.get(b_, 0) + 1
                for k in sorted(cnt, key=lambda q: (-cnt[q], -q)):
                    if sum(1 for z in zs if z["kind"] == zs[k]["kind"]) > 1 or n >= 60:
                        print("   entfernt:", zs[k]["kind"])
                        del zs[k]
                        break
                else:
                    break
        print("   danach Konflikte:", len(conflicts(zs)))
        json.dump(d, open(f, "w"), indent=1, ensure_ascii=False)


if __name__ == "__main__":
    main()
