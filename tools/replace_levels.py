"""Ersetzt einzelne Level durch neue Grundrisse mit gleichem Rezept (gleiche Mechaniken, anderes Layout) – etwa, wenn zwei Level sich zu ähnlich sehen.
Aufruf (Projektwurzel):  python3 tools/replace_levels.py 75 77 ...   (Levelnummern)
Der neue Grundriss muss dem Autopiloten genügen, anderen Leveln unähnlich sein (pad_dist >= MIN_DIST) und sich mit seinem Score zwischen
Vorgänger und Nachfolger einordnen (monotone Schwierigkeit)."""
import sys, os, json, glob
sys.path.insert(0, "tools")
import build_sector as bs


def level_file(n):
    sector, idx = (n - 1) // 11 + 1, (n - 1) % 11 + 1
    return sector, idx, "data/levels/s%d_%02d.json" % (sector, idx)


def cfg_from_level(d):
    mv = d.get("movers", [])
    zs = d.get("zones", [])
    kinds = [m["kind"] for m in mv]
    pads = {c for row in d["map"] for c in row if c in "123456789"}
    ids = [int(p) for p in pads] + [int(m["pad"]) for m in mv if m["kind"] == "pad"]
    widths = []
    for row in d["map"]:
        for c in set(row):
            if c in "123456789":
                widths.append(row.count(c))
    paths = {json.dumps(m["path"]) for m in mv if m["kind"] == "vehicle"}
    special = "H" if any("H" in r for r in d["map"]) else ("L" if any("L" in r for r in d["map"]) else None)
    mags = [z for z in zs if z["kind"] == "magnet"]
    winds = [z for z in zs if z["kind"] == "wind"]
    c = {"npads": max(ids), "jobs": len(d["jobs"]), "special": special, "moving": kinds.count("pad"),
         "narrow": sum(1 for w in widths if w <= 4), "debris": kinds.count("debris"), "meteors": kinds.count("meteor") if kinds.count("meteor") >= 2 else 0,
         "slider": "slider" in kinds, "traffic": min(len(paths), 2), "mags": len(mags), "pulsing": sum(1 for z in mags if "period" in z), "mixed": False,
         "heat": sum(1 for z in zs if z["kind"] == "heat"), "beams": kinds.count("beam"), "wind": len(winds), "grav": sum(1 for z in zs if z["kind"] == "gravity"),
         "gust": sum(1 for z in winds if "period" in z), "heat_pulsing": sum(1 for z in zs if z["kind"] == "heat" and "period" in z),
         "stalac": 1 if max(ids) >= 7 else 2, "stalag": 0 if max(ids) >= 7 else 1, "base": d["jobs"][0]["fare"], "target": 0.0}
    if d.get("dark"):
        c["dark"] = d["dark"]
    return c


def score_of(path):
    r = bs.run_eval([path], nobot=True, workers=1)
    return r[path]["score"]


TOL = 0.0            # --tol=<x>: Fenster um x Punkte weiten (Lückenfüller auf gleicher Schwierigkeitsstufe)
FROM = 0             # --from=<Level>: rezeptgebend ist dieses Level (Konfiguration, Score), der neue Grundriss kommt an die Stelle des Zielslots


def replace(n, K=40):
    sector, idx, fn = level_file(n)
    src_fn = level_file(FROM)[2] if FROM else fn
    old = json.load(open(src_fn))
    if FROM and os.path.exists(fn):
        old["name"] = json.load(open(fn))["name"]                 # der Zielslot behält seinen Namen
    s0 = score_of(src_fn)
    prev = next((level_file(m)[2] for m in range(n - 1, 0, -1) if os.path.exists(level_file(m)[2])), None)
    lo = score_of(prev) if prev else 0.0
    nxt = None if FROM else next((level_file(m)[2] for m in range(n + 1, 100) if os.path.exists(level_file(m)[2])), None)
    hi = score_of(nxt) if nxt else 1e9
    c = cfg_from_level(old)
    others = bs.existing_layouts(skip_sector=None, skip_levels=(n,))
    print("Level %d: Score %.1f, Fenster (%.1f, %.1f)" % (n, s0, lo, hi), flush=True)
    cands, paths = {}, []
    for v in range(40, 40 + K):
        try:
            d, nsp = bs.make_level(sector, idx, v, 0, None, idx, cfgo=c)
        except RuntimeError:
            continue
        pc = bs.pad_centers(d)
        if bs.too_similar(n, pc, others):
            continue
        d["name"] = old["name"]
        p = bs.write_cand(d, "rep%d_v%d" % (n, v))
        cands[p] = (v, d, nsp)
        paths.append(p)
    pre = bs.run_eval(paths, nobot=True)
    paths = [p for p in paths if pre.get(p) and pre[p]["clear"] >= 8.0]
    res = bs.run_eval(paths)
    pts = []
    for p in paths:
        v, d, nsp = cands[p]
        if bs.valid(d, res.get(p)):
            pts.append((res[p]["score"], v, 0, nsp))
    print("  gültige Kandidaten:", len(pts), flush=True)
    meta, paths2 = {}, []
    for (sc, v, n0, nsp) in list(pts):
        for f in (0.25, 0.5, 0.75, 1.0):
            k = int(round(f * min(nsp, 60)))
            if k <= 0:
                continue
            d, _ = bs.make_level(sector, idx, v, k, None, idx, cfgo=c)
            d["name"] = old["name"]
            p = bs.write_cand(d, "rep%d_v%d_n%d" % (n, v, k))
            meta[p] = (v, k, d)
            paths2.append(p)
    res2 = bs.run_eval(paths2)
    for p, (v, k, d) in meta.items():
        if bs.valid(d, res2.get(p)):
            pts.append((res2[p]["score"], v, k, 0))
    inside = [q for q in pts if lo - TOL + 0.05 < q[0] < hi + TOL - 0.05]
    if not inside:
        print("  kein Punkt im Fenster (Bereich %.1f–%.1f)" % (min((q[0] for q in pts), default=0), max((q[0] for q in pts), default=0)))
        return False
    best = min(inside, key=lambda q: abs(q[0] - s0))
    sc, v, k, _ = best
    d, _ = bs.make_level(sector, idx, v, k, None, idx, cfgo=c)
    d["name"] = old["name"]
    p = bs.write_cand(d, "rep%d_final_pre" % n)
    r = bs.run_eval([p])[p]
    times = r["times"] + [22.0]
    pars = [max(10, int(round(0.85 * t))) for t in times][: len(d["jobs"])]
    d2, _ = bs.make_level(sector, idx, v, k, pars, idx, cfgo=c)
    d2["name"] = old["name"]
    d2["index"] = idx
    d2["id"] = "S%d-%02d" % (sector, idx)
    json.dump(d2, open(fn, "w"), indent=1, ensure_ascii=False)
    r2 = bs.run_eval([fn])[fn]
    ok = bs.valid(d2, r2)
    print("  ersetzt: Score %.1f (vorher %.1f), gültig=%s" % (r2["score"], s0, ok), flush=True)
    if not ok and not FROM:
        json.dump(old, open(fn, "w"), indent=1, ensure_ascii=False)
    return ok


if __name__ == "__main__":
    for a in sys.argv[1:]:
        if a.startswith("--tol="):
            TOL = float(a[6:])
        if a.startswith("--from="):
            FROM = int(a[7:])
    for a in sys.argv[1:]:
        if not a.startswith("--"):
            replace(int(a))
