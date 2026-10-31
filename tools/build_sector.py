"""Erzeugt einen ganzen Sektor aus prozeduralen Grundrissen und misst/justiert ihn mit dem Bot.
Aufruf (Projektwurzel):  python3 tools/build_sector.py 3|4|5 [--dry]
Ablauf: je Slot K Kandidaten (andere Seeds) -> Bot-Lauf + Metrik (tools/batch_eval.gd) -> bester Kandidat -> Dornenzahl so
justieren, dass die Metrik dem Ziel des Slots entspricht (monotone Schwierigkeit) -> Pars aus den Bot-Zeiten -> data/levels."""
import sys, os, json, random, subprocess, copy, concurrent.futures as cf
sys.path.insert(0, "tools")
import procgen
from levelparts import *

CAND = "/tmp/claude-1000/cand"
os.makedirs(CAND, exist_ok=True)

NAMES = {
    3: [("Schrottplatz", "Scrap Yard"), ("Kranbahn", "Crane Track"), ("Fließband", "Conveyor"), ("Trümmerfeld", "Debris Field"), ("Notfallflug", "Emergency Run"),
        ("Doppelfähre", "Twin Ferry"), ("Meteorregen", "Meteor Rain"), ("Altmetall", "Scrap Metal"), ("Lazarettgürtel", "Medic Belt"), ("Schrottpresse", "Scrap Press"),
        ("Gürtelwächter", "Belt Guardian")],
    4: [("Erste Spule", "First Coil"), ("Abstoßung", "Repulsion"), ("Zwillingspole", "Twin Poles"), ("Pulsschlag", "Heartbeat"), ("Magnetschacht", "Magnet Shaft"),
        ("Feldlinien", "Field Lines"), ("Polwechsel", "Pole Swap"), ("Dynamo", "Dynamo"), ("Rettungsfeld", "Rescue Field"), ("Magnetträger", "Magnet Carriers"),
        ("Magnetmeister", "Magnet Master")],
    5: [("Erster Funke", "First Spark"), ("Glutschacht", "Ember Shaft"), ("Plasmastrahl", "Plasma Beam"), ("Schmelzofen", "Smelter"), ("Hitzewelle", "Heat Wave"),
        ("Taktgeber", "Pacemaker"), ("Hochofen", "Blast Furnace"), ("Koronaring", "Corona Ring"), ("Gussform", "Casting Mold"), ("Sonnenschmiede", "Solar Forge"),
        ("Schmiedemeister", "Forge Master")],
}


def cfg(sector, i):
    """Merkmale eines Slots (i = 1..11)."""
    if sector == 3:
        return {"npads": 5, "jobs": 6, "special": {3: "L", 8: "L", 5: "H", 9: "H", 10: "H"}.get(i), "moving": [0, 0, 1, 0, 0, 1, 1, 0, 1, 1, 1][i - 1],
                "narrow": 0 if i < 6 else (1 if i < 9 else 2), "debris": [1, 1, 2, 2, 2, 2, 2, 2, 2, 2, 2][i - 1], "meteors": {7: 3, 8: 3, 10: 3, 11: 2}.get(i, 0),
                "slider": i == 11, "mags": [], "stalac": 2 + (i > 5), "stalag": 1 + (i > 8), "base": 120, "target": 114.0 + 2.0 * (i - 1)}
    if sector == 4:
        mags = [1, 1, 2, 2, 2, 3, 3, 3, 4, 4, 5][i - 1]
        pulsing = [0, 0, 0, 1, 1, 1, 2, 2, 2, 2, 3][i - 1]
        return {"npads": 6, "jobs": 7, "special": {2: "L", 7: "L", 4: "H", 9: "H"}.get(i), "moving": 0 if i < 6 else 1,
                "narrow": 0 if i < 5 else (1 if i < 8 else 2), "debris": 0 if i < 8 else (1 if i < 10 else 2), "meteors": 0, "slider": False,
                "mags": mags, "pulsing": pulsing, "repel_first": i == 2, "stalac": 2, "stalag": 1, "base": 130, "target": 136.0 + 2.5 * (i - 1)}
    if sector == 5:
        heat = [1, 1, 1, 1, 2, 1, 2, 2, 2, 2, 2][i - 1]
        beams = [0, 0, 1, 1, 1, 1, 2, 2, 2, 2, 2][i - 1]
        mags = [0, 0, 1, 0, 1, 0, 1, 1, 1, 1, 1][i - 1]
        return {"npads": 7, "jobs": 7, "special": {1: "L", 6: "L", 11: "L", 4: "H", 8: "H"}.get(i), "moving": 0,
                "narrow": 0 if i < 4 else (1 if i < 8 else 2), "debris": 1, "meteors": 0, "slider": False,
                "mags": mags, "pulsing": 0, "heat": heat, "beams": beams, "heat_pulsing": 0 if i < 4 else (1 if i < 8 else 2),
                "stalac": 2, "stalag": 1, "base": 140, "target": 0.0}
    raise ValueError(sector)


def make_level(sector, i, variant, spikes=0, pars=None, idx=None):
    c = cfg(sector, i)
    seed = sector * 1000 + i * 17 + variant * 101
    res = procgen.build(seed, c["npads"], c["special"], c["moving"], c["narrow"], c["stalac"], c["stalag"], dense=c["npads"] >= 7, lanes=c["meteors"])
    rnd = random.Random(seed + 7)
    g = copy.deepcopy(res["grid"])
    cells = procgen.spike_cells(res, 60)
    for x, y in cells[:spikes]:
        g.g[y][x] = "^"
    movers = []
    for m in res["moving"]:
        movers.append(MP(m["pad"], m["x"], m["y"], w=m["w"], dx=m["dx"], period=rnd.choice([12.0, 14.0, 16.0, 18.0]), phase=rnd.choice([0.0, 2.0, 3.0])))
    for (x, y, a, kind) in procgen.debris_lanes(res, rnd, c["debris"]):
        if kind == "h":
            movers.append(D(x, y, dx=a, period=rnd.choice([8.0, 9.0, 10.0, 11.0]), phase=rnd.choice([0.0, 2.0, 3.0])))
        else:
            movers.append(D(x, y, dy=a, w=1, h=2, period=rnd.choice([8.0, 9.0, 10.0]), phase=rnd.choice([0.0, 2.0, 3.0])))
    if c["meteors"]:
        lanes = procgen.meteor_lanes(res, rnd, c["meteors"])
        if len(lanes) >= 2:
            movers += METS(lanes, period=22.0, t0=8.0 + 2.0 * (variant % 3), gap=1.0)
    if c["slider"]:
        site = procgen.slider_site(res, rnd)
        if site:
            movers.append(SL(site[0], site[1], w=3, h=2, dx=3, period=13.0))
    zones = []
    if c["mags"]:
        sites = procgen.magnet_sites(res, rnd, c["mags"])
        for n, (x, y, d) in enumerate(sites):
            r = max(3.0, min(5.0, d - 0.7))
            k = rnd.choice([45, 50, 55, 60]) * (1 if rnd.random() < 0.5 else -1)
            if n == 0:
                k = abs(k)
            if c.get("repel_first") and n == 0:
                k = -abs(k)
            if n >= c["mags"] - c.get("pulsing", 0):
                per = rnd.choice([7.0, 8.0, 9.0])
                zones.append(MAG(x, y, k, r=r, period=per, on=round(per / 2, 1), phase=rnd.choice([0.0, 2.0, 3.5])))
            else:
                zones.append(MAG(x, y, k, r=r))
    for (x0, x1, y0, y1) in (procgen.heat_sites(res, rnd, c["heat"]) if c.get("heat") else []):
        n_ = len([z for z in zones if z["kind"] == "heat"])
        if n_ >= c["heat"] - c.get("heat_pulsing", 0):
            per = rnd.choice([7.0, 8.0, 9.0])
            zones.append(HEAT(x0, x1, y0, y1, period=per, on=round(per / 2, 1), phase=rnd.choice([0.0, 2.0, 3.5])))
        else:
            zones.append(HEAT(x0, x1, y0, y1))
    for (x, y, w, h) in (procgen.beam_sites(res, rnd, c["beams"]) if c.get("beams") else []):
        movers.append(BEAM(x, y, w, h, period=rnd.choice([8.0, 9.0, 10.0]), on=rnd.choice([2.5, 3.0]), phase=rnd.choice([0.0, 2.0, 4.0])))
    # Pflichtmerkmale des Slots: fehlen sie, ist der Grundriss ungeeignet (neue Variante)
    kinds_ = [m["kind"] for m in movers]
    if c["meteors"] and kinds_.count("meteor") < 2:
        raise RuntimeError("zu wenige Meteoritenbahnen")
    if c["slider"] and "slider" not in kinds_:
        raise RuntimeError("kein Platz für den Schieber")
    if c["debris"] and kinds_.count("debris") < max(1, c["debris"] - 1):
        raise RuntimeError("zu wenige Trümmerbahnen")
    if c.get("beams") and kinds_.count("beam") < max(1, c["beams"] - 1):
        raise RuntimeError("zu wenige Strahlen")
    if c.get("heat") and len([z for z in zones if z["kind"] == "heat"]) < max(1, c["heat"] - 1):
        raise RuntimeError("zu wenige Hitzezonen")
    if c["mags"] and len([z for z in zones if z["kind"] == "magnet"]) < c["mags"]:
        raise RuntimeError("zu wenige Magnete")
    hosp = c["special"] == "H"
    jobs = jobs_of(seq(sector * 100 + i * 13 + variant, c["jobs"], c["npads"], hospital_at=(rnd.choice([1, 2, 3]) if hosp else None), ), base=c["base"])
    if pars:
        for j, p in zip(jobs, pars):
            j["par"] = p
    mech = ["chicane"]
    if any("^" in "".join(r) for r in g.rows()):
        mech.append("spikes")
    kinds = {m["kind"] for m in movers}
    for k_, tag in (("debris", "debris"), ("pad", "moving_pads"), ("meteor", "meteors"), ("slider", "sliders")):
        if k_ in kinds:
            mech.append(tag)
    if any(z["kind"] == "heat" for z in zones):
        mech.append("heat")
        if any("period" in z for z in zones if z["kind"] == "heat"):
            mech.append("pulsing_heat")
    if "beam" in kinds:
        mech.append("beams")
    zones_mag = [z for z in zones if z["kind"] == "magnet"]
    if zones_mag:
        mech.append("magnets")
        if any("period" in z for z in zones_mag):
            mech.append("pulsing_fields")
        if any(z["k"] < 0 for z in zones_mag):
            mech.append("repel_fields")
        if any(z["k"] > 0 for z in zones_mag):
            mech.append("attract_fields")
    if hosp:
        mech.append("medical")
    if c["special"] == "L":
        mech.append("life_station")
    idx = idx or i
    ident = "S%d-%02d" % (sector, idx)
    if c["special"]:
        # Sonderpad: Zeichen bleibt im Raster (L bzw. H)
        pass
    d = {"id": ident, "sector": sector, "index": idx, "name": {"de": NAMES[sector][i - 1][0], "en": NAMES[sector][i - 1][1]},
         "map": g.rows(), "jobs": jobs, "mechanics": mech}
    if movers:
        d["movers"] = movers
    if zones:
        d["zones"] = zones
    return d, len(cells)


def write_cand(d, tag):
    path = "%s/%s.json" % (CAND, tag)
    json.dump(d, open(path, "w"), indent=1, ensure_ascii=False)
    return path


def run_eval(paths, nobot=False, workers=4):
    chunks = [paths[k::workers] for k in range(workers)]
    out = {}

    def job(ch):
        if not ch:
            return ""
        cmd = ["godot", "--headless", "--path", ".", "-s", "tools/batch_eval.gd", "--"] + (["--nobot"] if nobot else []) + ch
        return subprocess.run(cmd, capture_output=True, text=True).stdout

    with cf.ThreadPoolExecutor(workers) as ex:
        for txt in ex.map(job, chunks):
            for ln in txt.splitlines():
                if ln.startswith("EVAL|"):
                    p = ln.split("|")
                    if p[2] == "ERR":
                        out[p[1]] = None
                        continue
                    out[p[1]] = {"score": float(p[2]), "clear": float(p[3]), "route": float(p[4]), "window": float(p[5]),
                                 "ok": p[6] == "1", "hull": float(p[7]) if p[7] != "-" else 100.0, "delivered": int(p[8]) if p[8] != "-" else 0, "jobs": int(p[9]),
                                 "time": float(p[10]) if p[10] != "-" else 0.0, "fuel": float(p[11]) if p[11] != "-" else 0.0, "times": json.loads(p[12])}
    return out


def valid(d, r):
    if r is None or not r["ok"]:
        return False
    fragile = any(j.get("fragile") for j in d["jobs"])
    return r["hull"] >= (99.5 if fragile else 95.0) and r["delivered"] >= r["jobs"] - 1


FLOOR_PREV = {3: 113.2}        # Höchster Score des Vorgängersektors (S2-11); für Sektor 4+ aus tools/sector_scores.json


def floor_of(sector):
    f = FLOOR_PREV.get(sector)
    if f is None:
        sc = json.load(open("tools/sector_scores.json"))
        f = max(sc[str(sector - 1)])
    return f + 0.3


def dp_points(slots, pts, ramp):
    """pts[i] = [(score, key)]; wählt je Slot einen Punkt, Scores streng steigend (≥ 0,25) ab ramp["floor"], minimale quadratische
    Abweichung von der Rampe. Rückgabe {slot: key} oder None."""
    prev = {None: (0.0, ramp["floor"] - 0.25, None)}
    back = []
    for i in slots:
        cur = {}
        for sc, key in pts.get(i, []):
            best = None
            for pk, (cost, ps, _) in prev.items():
                if ps + 0.25 <= sc + 1e-9:
                    c2 = cost + (sc - ramp[i]) ** 2
                    if best is None or c2 < best[0]:
                        best = (c2, pk)
            if best is not None:
                cur[(i, key)] = (best[0], sc, best[1])
        if not cur:
            continue                      # Slot ohne passenden Punkt entfällt (Sektor wird kürzer)
        back.append(cur)
        prev = cur
    state = min(prev, key=lambda k: prev[k][0])
    res = {}
    for cur in reversed(back):
        res[state[0]] = state[1]
        state = cur[state][2]
    return res


def main():
    sector = int(sys.argv[1])
    K = 8 if sector == 5 else 5
    slots = list(range(1, 12))
    cands = {}
    paths = []
    for i in slots:
        for v in range(K):
            try:
                d, nsp = make_level(sector, i, v)
            except RuntimeError as e:
                print("Slot", i, "Variante", v, e)
                continue
            p = write_cand(d, "s%d_%02d_v%d_n0" % (sector, i, v))
            cands[p] = (i, v, d, nsp)
            paths.append(p)
    print("Kandidaten:", len(paths), flush=True)
    # Vorfilter (schnell, ohne Bot): Wegplanung mit dem Bot-Rand von 7 px muss die ganze Route finden (Korridor ≥ 8)
    pre = run_eval(paths, nobot=True)
    keep = [p for p in paths if pre.get(p) is not None and pre[p]["clear"] >= 8.0]
    print("Wegplanung ok:", len(keep), "von", len(paths), flush=True)
    paths = keep
    res = run_eval(paths)
    pts = {i: [] for i in slots}
    nsp_of = {}
    info = {}
    for p, (i, v, d, nsp) in cands.items():
        r = res.get(p)
        nsp_of[(i, v)] = min(nsp, 60)
        if p in keep and valid(d, r):
            pts[i].append((r["score"], (v, 0)))
            info[(i, (v, 0))] = r
    fl = floor_of(sector)
    ramp = {"floor": fl}
    for i in slots:
        ramp[i] = fl + {3: 20.0, 4: 7.0, 5: 14.0}.get(sector, 18.0) * (i - 1) / 10.0
    print("gültig je Slot:", {i: len(pts[i]) for i in slots}, flush=True)
    plan = None
    for rnd_ in range(4):
        # Stichproben mit Dornen: je Slot die Kandidaten mit gültiger Basis, mehrere Dornenzahlen
        paths = []
        meta = {}
        fr = [0.2, 0.35, 0.5, 0.65, 0.8, 1.0] if rnd_ == 0 else [0.1 + 0.07 * rnd_ + 0.13 * k for k in range(6)]
        for i in slots:
            vs = sorted({k[1][0] for k in info if k[0] == i})
            for v in vs:
                for f in fr:
                    n = int(round(f * nsp_of[(i, v)]))
                    if n <= 0 or (i, (v, n)) in info or any(m == (i, v, n) for m in meta.values()):
                        continue
                    d, _ = make_level(sector, i, v, n)
                    p = write_cand(d, "s%d_%02d_v%d_n%d" % (sector, i, v, n))
                    meta[p] = (i, v, n)
                    paths.append(p)
        res = run_eval(paths)
        dmap = {}
        for p, (i, v, n) in meta.items():
            r = res.get(p)
            d, _ = make_level(sector, i, v, n)
            if valid(d, r):
                pts[i].append((r["score"], (v, n)))
                info[(i, (v, n))] = r
        print("Runde %d: Punkte je Slot:" % rnd_, {i: len(pts[i]) for i in slots}, flush=True)
        plan = dp_points(slots, pts, ramp)
        if plan is not None and len(plan) == len(slots):
            break
    if plan is None:
        print("keine monotone Zuordnung (Floor %.1f)" % fl)
        for i in slots:
            print(i, sorted(round(sc, 1) for sc, _ in pts[i]))
        return
    keep_slots = sorted(plan)
    scores = {i: info[(i, plan[i])]["score"] for i in keep_slots}
    print("Plan (Slot: Variante, Dornen, Score):", {i: (plan[i][0], plan[i][1], round(scores[i], 1)) for i in keep_slots}, flush=True)
    if len(keep_slots) < len(slots):
        print("Sektor wird kürzer:", len(keep_slots), "Level (ohne Slots", [i for i in slots if i not in keep_slots], ")", flush=True)
    if "--dry" in sys.argv:
        return
    sc_all = json.load(open("tools/sector_scores.json")) if os.path.exists("tools/sector_scores.json") else {}
    for old in [f for f in os.listdir("data/levels") if f.startswith("s%d_" % sector)]:
        os.remove("data/levels/" + old)
    final_paths = {}
    for n, i in enumerate(keep_slots, 1):
        v, nn = plan[i]
        r = info[(i, plan[i])]
        times = r["times"] + [30.0]
        pars = [int(round(1.3 * t + 8)) for t in times]
        d2, _ = make_level(sector, i, v, nn, pars[: 7], idx=n)
        fn = "data/levels/s%d_%02d.json" % (sector, n)
        json.dump(d2, open(fn, "w"), indent=1, ensure_ascii=False)
        final_paths[fn] = i
    res = run_eval(list(final_paths))
    bad = []
    for fn, i in final_paths.items():
        r = res.get(fn)
        d = json.load(open(fn))
        if not valid(d, r):
            bad.append(i)
        if r is not None:
            scores[i] = r["score"]
    print("Endscores:", {i: round(scores[i], 1) for i in keep_slots}, "ungültig:", bad)
    sc_all[str(sector)] = [scores[i] for i in keep_slots]
    json.dump(sc_all, open("tools/sector_scores.json", "w"))
    print("geschrieben:", len(final_paths), "Level")


if __name__ == "__main__":
    main()
