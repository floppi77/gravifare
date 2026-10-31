"""Prozedurale Level-Grundrisse für Sektor 3+ (jedes Level bekommt einen eigenen Grundriss aus dem Seed).
Liefert Raster (levelkit.Grid) plus Metadaten (Pads, freie Bahnen für Trümmer/Meteoriten, freie Orte für Magnete).
Prüfung hier nur geometrisch (Erreichbarkeit mit 2×2-Tile-Fenster); die Lösbarkeit prüft der Bot (tools/batch_eval.gd)."""
import random
from levelkit import Grid

W, H = 40, 22
FLOOR = 20                      # erste Felszeile am Boden
GATE_ZONE = (13, 26, 1, 8)      # x0, x1, y0, y1: darunter bleibt der Einflug frei


def _rect_hit(a, b):
    return not (a[1] < b[0] or b[1] < a[0] or a[3] < b[2] or b[3] < a[2])


def _free(g, x, y):
    return 0 <= x < W and 0 <= y < H and g.g[y][x] in ".S"


STRICT = 0      # 0: 2x2-Fenster (zwei Tiles Gasse); 1: 3x3-Fenster um die Zelle (drei Tiles Gasse, Bot-Rand 7 px)


def _block_free(g, x, y):
    if STRICT:
        return all(_free(g, x + dx, y + dy) for dx in (-1, 0, 1) for dy in (-1, 0, 1))
    return all(_free(g, x + dx, y + dy) for dx in (0, 1) for dy in (0, 1))


def reachable(g, start, goals):
    """2x2-Fenster-BFS: erreichen alle Ziele (Blockkoordinaten oben links) den Start?"""
    seen = {start}
    todo = [start]
    while todo:
        x, y = todo.pop()
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            n = (x + dx, y + dy)
            if n not in seen and _block_free(g, *n):
                seen.add(n)
                todo.append(n)
    return all(t in seen for t in goals)


class Island:
    def __init__(self, kind, rx0, rx1, top, bot, px0, px1, ext=0):
        self.kind, self.rx0, self.rx1, self.top, self.bot, self.px0, self.px1, self.ext = kind, rx0, rx1, top, bot, px0, px1, ext

    ABOVE = 5

    def excl(self):
        """Sperrbereich: 2 Tiles seitlich, 5 darüber (Unterstand + Anflug), 1 darunter."""
        return (self.rx0 - 1 - self.ext, self.rx1 + 1 + self.ext, self.top - Island.ABOVE, self.bot + 1)

    def rock(self):
        return (self.rx0, self.rx1, self.top, self.bot)


def build(seed, npads=5, special=None, moving=0, narrow=0, stalac=2, stalag=1, tries=400, dense=False, lanes=0):
    """Erzeugt einen Grundriss. npads = nummerierte Passagierpads inkl. Startpad 1; special = None | "L" | "H";
    moving = Anzahl fahrender Pads (ersetzen Inseln); narrow = Anzahl schmaler Pads (4 statt 5–8 Tiles)."""
    Island.ABOVE = 4 if dense else 5
    for attempt in range(tries):
        rnd = random.Random(seed * 1000 + attempt)
        r = _try(rnd, npads, special, moving, narrow, stalac, stalag, dense, lanes)
        if r is not None:
            r["attempt"] = attempt
            return r
    raise RuntimeError("kein Grundriss für Seed %d" % seed)


def _try(rnd, npads, special, moving, narrow, stalac, stalag, dense=False, lanes=0):
    g = Grid()
    g.rect("#", 1, FLOOR, W - 2, FLOOR)
    g.gate()
    islands = []
    # --- Bodenpads: Start (1) und Tank (F)
    side = rnd.choice([0, 1])
    w1 = rnd.randint(6, 8)
    wf = 6
    if side == 0:
        p1x = rnd.randint(2, 6)
        fx = rnd.randint(p1x + w1 + 2, p1x + w1 + 9)
    else:
        p1x = rnd.randint(W - 2 - w1 - 5, W - 2 - w1)
        fx = rnd.randint(p1x - 9 - wf, p1x - 2 - wf)
    if fx + wf > W - 2 or fx < 2:
        return None
    g.rect("1", p1x, FLOOR - 1, p1x + w1 - 1, FLOOR - 1)
    g.rect("F", fx, FLOOR - 1, fx + wf - 1, FLOOR - 1)
    pump_x = fx if rnd.random() < 0.5 else fx + wf - 1
    g.rect("P", pump_x, FLOOR - 3, pump_x, FLOOR - 2)
    g.put("S", p1x + w1 // 2, FLOOR - 2)
    for (a, b) in ((p1x, p1x + w1 - 1), (fx, fx + wf - 1)):
        islands.append(Island("floor", a, b, FLOOR - 1, FLOOR - 1, a, b))
    # --- reservierte Fallbahnen (Meteoriten): freie Säulen von der Decke bis zum Boden
    reserved = []
    for _ in range(lanes):
        for _t in range(40):
            x = rnd.randint(3, W - 4)
            if GATE_ZONE[0] - 1 <= x <= GATE_ZONE[1] + 1:
                continue
            if any(a - 2 <= x <= b + 2 for (a, b) in ((p1x, p1x + w1 - 1), (fx, fx + wf - 1))):
                continue
            if any(abs(x - o) < 5 for o in reserved):
                continue
            reserved.append(x)
            break
    res_rects = [(x, x, 1, FLOOR - 1) for x in reserved]
    # --- Inseln für die übrigen Pads (und Sonderpad)
    want = [str(i) for i in range(2, npads + 1)]
    if special:
        want.append(special)
    rnd.shuffle(want)
    pads = {"1": (p1x, p1x + w1 - 1, FLOOR - 1), "F": (fx, fx + wf - 1, FLOOR - 1)}
    mov = []
    nar_left = narrow
    mov_left = moving
    for ident in want:
        done = False
        for _ in range(400):
            is_moving = mov_left > 0 and ident not in ("L", "H") and ident != "2"
            if ident == "L":
                w = 4
            elif ident == "H":
                w = 5
            elif nar_left > 0 and rnd.random() < 0.6:
                w = 4
            else:
                w = rnd.randint(4, 6) if dense else rnd.randint(5, 7)
            kind = rnd.choice(["pillar", "float", "float", "shelf"])
            top = rnd.randint(7, 16)
            thick = rnd.randint(2, 4)
            pad_x0 = rnd.randint(2, W - 2 - w)
            if kind == "shelf":
                if pad_x0 < W // 2:
                    rx0, rx1 = 1, pad_x0 + w - 1 + rnd.randint(0, 2)
                else:
                    rx0, rx1 = pad_x0 - rnd.randint(0, 2), W - 2
                pad_x0 = max(pad_x0, 2 if rx0 == 1 else pad_x0)
                if rx1 - rx0 + 1 < w + 1:
                    continue
            else:
                rx0, rx1 = pad_x0 - rnd.randint(0, 2), pad_x0 + w - 1 + rnd.randint(0, 2)
                rx0, rx1 = max(rx0, 1), min(rx1, W - 2)
            px0, px1 = pad_x0, pad_x0 + w - 1
            if kind == "pillar" or FLOOR - (top + thick) < 5:
                bot = FLOOR - 1
                kind = "pillar"
            else:
                bot = top + thick - 1
            ext = 0
            if is_moving:
                dx = rnd.choice([2, 3, 4])
                ext = dx + 1
                kind = "slab"
                bot = top + 1
                rx0, rx1 = px0, px1
                if px0 - dx < 1 or px1 + dx > W - 2:
                    continue
            isl = Island(kind, rx0, rx1, top, bot, px0, px1, ext)
            ex = isl.excl()
            rock = (isl.rx0 - isl.ext, isl.rx1 + isl.ext, isl.top, isl.bot)
            if _rect_hit(rock, (GATE_ZONE[0], GATE_ZONE[1], GATE_ZONE[2], GATE_ZONE[3])):
                continue
            if any(_rect_hit(rock, rr) for rr in res_rects):
                continue
            if any(_rect_hit(ex, o.rock()) or _rect_hit(o.excl(), rock) for o in islands):
                continue
            if top - Island.ABOVE < 3:
                continue
            islands.append(isl)
            if is_moving:
                mov.append({"pad": ident, "x": px0, "y": top, "w": w, "dx": dx})
                mov_left -= 1
            else:
                if kind != "slab":
                    g.rect("#", isl.rx0, top, isl.rx1, bot)
                    g.rect(ident, px0, top, px1, top)
            pads[ident] = (px0, px1, top)
            if w == 4 and ident not in ("L", "H"):
                nar_left -= 1
            done = True
            break
        if not done:
            return None
    # --- Stalaktiten (hängen von der Decke) und Stalagmiten (stehen auf dem Boden)
    deco = []
    for _ in range(stalac):
        for _t in range(60):
            w = rnd.randint(2, 4)
            x0 = rnd.randint(2, W - 2 - w)
            d = rnd.randint(3, 6)
            rc = (x0, x0 + w - 1, 1, d)
            if _rect_hit(rc, (GATE_ZONE[0] - 1, GATE_ZONE[1] + 1, 1, 9)):
                continue
            if any(_rect_hit(rc, o.excl()) for o in islands):
                continue
            if any(_rect_hit(rc, o) for o in deco) or any(_rect_hit(rc, rr) for rr in res_rects):
                continue
            deco.append(rc)
            g.rect("#", x0, 1, x0 + w - 1, d)
            break
    for _ in range(stalag):
        for _t in range(60):
            w = rnd.randint(2, 3)
            x0 = rnd.randint(2, W - 2 - w)
            h = rnd.randint(2, 4)
            rc = (x0, x0 + w - 1, FLOOR - h, FLOOR - 1)
            if any(_rect_hit(rc, o.excl()) for o in islands):
                continue
            if any(_rect_hit(rc, o) for o in deco) or any(_rect_hit(rc, rr) for rr in res_rects):
                continue
            deco.append(rc)
            g.rect("#", x0, FLOOR - h, x0 + w - 1, FLOOR - 1)
            break
    # --- Erreichbarkeit
    start = (p1x + w1 // 2 - 0, FLOOR - 4)
    goals = [(18, 4)]
    for ident, (a, b, top) in pads.items():
        goals.append(((a + b) // 2, top - 4))
    for m in mov:
        goals.append((m["x"] + m["w"] // 2, m["y"] - 4))
    if not _block_free(g, *start):
        return None
    if not reachable(g, start, [t for t in goals if _block_free(g, *t)]) or any(not _block_free(g, *t) for t in goals):
        return None
    return {"grid": g, "pads": pads, "islands": islands, "moving": mov, "deco": deco, "start": start, "lanes": reserved}


# ---------- freie Bahnen und Orte für Hindernisse ----------
def _pad_cols(res, pad=1):
    cols = set()
    for ident, (a, b, top) in res["pads"].items():
        for x in range(a - pad, b + pad + 1):
            cols.add(x)
    for m in res["moving"]:
        for x in range(m["x"] - m["dx"] - 2, m["x"] + m["w"] + m["dx"] + 3):
            cols.add(x)
    return cols


def meteor_lanes(res, rnd, n):
    """Senkrechte Fallbahnen: die bei build(lanes=...) reservierten freien Säulen (Decke bis Boden)."""
    g = res["grid"]
    out = []
    for x in res.get("lanes", [])[:n]:
        if all(g.g[y][x] == "." for y in range(1, FLOOR)):
            out.append((x, 0, FLOOR - 2))
    return out


def debris_lanes(res, rnd, n):
    """Trümmerbahnen in freier Luft: waagerecht (freier 3-Zeilen-Streifen ab 7 Tiles) oder senkrecht (freie 3-Spalten-Säule ab 7
    Tiles), nicht in Pad-Anflugzonen (über dem Pad ± 1 Tile) und nicht im Torbereich. Rückgabe [(x, y, amp, "h"|"v")]:
    x/y = Mitte der Bahn (Tile), amp = Schwingweite in Tiles."""
    if n <= 0:
        return []
    g = res["grid"]
    cands = []
    for y in range(5, 17):
        x = 2
        while x < W - 2:
            if all(g.g[yy][x] == "." for yy in (y - 1, y, y + 1)):
                x1 = x
                while x1 + 1 < W - 2 and all(g.g[yy][x1 + 1] == "." for yy in (y - 1, y, y + 1)):
                    x1 += 1
                if x1 - x >= 6:
                    cands.append((x, x1, y, "h"))
                x = x1 + 1
            else:
                x += 1
    for x in range(3, W - 3):
        y = 3
        while y < FLOOR - 1:
            if all(g.g[y][xx] == "." for xx in (x - 1, x, x + 1)):
                y1 = y
                while y1 + 1 < FLOOR - 1 and all(g.g[y1 + 1][xx] == "." for xx in (x - 1, x, x + 1)):
                    y1 += 1
                if y1 - y >= 6:
                    cands.append((y, y1, x, "v"))
                y = y1 + 1
            else:
                y += 1
    ok = []
    for a0, a1, c, kind in cands:
        rc = (a0, a1, c, c) if kind == "h" else (c, c, a0, a1)
        bad = False
        for ident, (pa, pb, top) in res["pads"].items():
            if _rect_hit(rc, (pa - 1, pb + 1, top - 4, top + 1)):
                bad = True
        for m in res["moving"]:
            if _rect_hit(rc, (m["x"] - m["dx"] - 1, m["x"] + m["w"] + m["dx"] + 1, m["y"] - 4, m["y"] + 2)):
                bad = True
        if _rect_hit(rc, (GATE_ZONE[0], GATE_ZONE[1], GATE_ZONE[2], GATE_ZONE[3] + 2)):
            bad = True
        if not bad:
            ok.append((a0, a1, c, kind))
    rnd.shuffle(ok)
    out = []
    for a0, a1, c, kind in ok:
        pos = (c, 0) if kind == "h" else (0, c)
        if all(abs(c - o[1 if o[3] == "h" else 0]) >= 3 or o[3] != kind for o in out):
            a = min(5, (a1 - a0 - 1) // 2 - 1)
            if a >= 1:
                mid = a0 + a + 1
                out.append((mid, c, a, kind) if kind == "h" else (c, mid, a, kind))
        if len(out) >= n:
            break
    return out


def magnet_sites(res, rnd, n, r=4.5):
    """Orte für Magnetkerne in freier Luft: mindestens r Tiles von allen Pads und vom Tor entfernt (bzw. am weitesten weg)."""
    g = res["grid"]
    pts = []
    for y in range(4, 18):
        for x in range(3, W - 3):
            if g.g[y][x] != ".":
                continue
            dmin = 99.0
            for ident, (a, b, top) in res["pads"].items():
                dx = max(a - x, 0, x - b)
                dy = top - y
                dmin = min(dmin, (dx * dx + dy * dy) ** 0.5)
            for m in res["moving"]:
                dx = max(m["x"] - m["dx"] - x, 0, x - (m["x"] + m["w"] + m["dx"]))
                dmin = min(dmin, (dx * dx + (m["y"] - y) ** 2) ** 0.5)
            dgate = max(GATE_ZONE[0] - x, 0, x - GATE_ZONE[1])
            if dgate == 0 and y <= 9:
                continue
            # freier Raum um den Kern (kein Fels im 2-Tile-Umkreis)
            if any(g.g[yy][xx] not in ".S" for yy in range(y - 2, y + 3) for xx in range(x - 2, x + 3) if 0 <= xx < W and 0 <= yy < H):
                continue
            pts.append((dmin, x + 0.5, y + 0.5))
    pts.sort(reverse=True)
    out = []
    for d, x, y in pts:
        if all(((x - o[0]) ** 2 + (y - o[1]) ** 2) ** 0.5 >= 6.0 for o in out):
            out.append((x, y, d))
        if len(out) >= n:
            break
    return out


def slider_site(res, rnd):
    g = res["grid"]
    cands = []
    for y in range(5, 15):
        for x in range(3, W - 10):
            if all(g.g[yy][xx] == "." for yy in range(y - 1, y + 3) for xx in range(x - 3, x + 10)):
                ok = True
                for ident, (a, b, top) in res["pads"].items():
                    if top - 6 <= y <= top + 2 and not (x + 9 < a or x - 3 > b):
                        ok = False
                if x - 3 <= GATE_ZONE[1] and x + 9 >= GATE_ZONE[0] and y <= GATE_ZONE[3] + 2:
                    ok = False
                if ok:
                    cands.append((x, y))
    return rnd.choice(cands) if cands else None


def spike_cells(res, n):
    """Dornen (feste Reihenfolge): Decke (Zeile 1 links/rechts vom Tor), Unterseiten schwebender Inseln, Spitzen der Stalaktiten,
    Spitzen der Stalagmiten. Reicht für bis zu etwa 60 Gefahreneinheiten."""
    g = res["grid"]
    cells = []
    for x in list(range(2, 15)) + list(range(37, 24, -1)):
        if g.g[1][x] == "." and g.g[2][x] == ".":
            cells.append((x, 1))
    for isl in res["islands"]:
        if isl.kind == "float":
            for x in range(isl.rx0, isl.rx1 + 1):
                y = isl.bot + 1
                if g.g[y][x] == "." and g.g[y + 1][x] == ".":
                    cells.append((x, y))
    for (x0, x1, y0, y1) in res["deco"]:
        if y0 == 1:                                   # Stalaktit: Spitze zeigt nach unten
            for x in range(x0, x1 + 1):
                if g.g[y1 + 1][x] == "." and g.g[y1 + 2][x] == ".":
                    cells.append((x, y1 + 1))
        elif y1 == FLOOR - 1:                         # Stalagmit: Spitze zeigt nach oben
            for x in range(x0, x1 + 1):
                if g.g[y0 - 1][x] == "." and g.g[y0 - 2][x] == ".":
                    cells.append((x, y0 - 1))
    return cells[:n]


def _rect_blocks_path(res, rects):
    """Bleibt der Grundriss mit den (Tile-)Rechtecken als Hindernis erreichbar? rects = [(x0, x1, y0, y1)] inklusive."""
    g = res["grid"]
    saved = []
    for (x0, x1, y0, y1) in rects:
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1):
                if g.g[y][x] == ".":
                    saved.append((x, y))
                    g.g[y][x] = "~"
    start = res["start"]
    goals = [(18, 4)]
    for ident, (a, b, top) in res["pads"].items():
        goals.append(((a + b) // 2, top - 4))
    for m in res["moving"]:
        goals.append((m["x"] + m["w"] // 2, m["y"] - 4))
    ok = _block_free(g, *start) and all(_block_free(g, *t) for t in goals) and reachable(g, start, goals)
    for x, y in saved:
        g.g[y][x] = "."
    return ok


def heat_sites(res, rnd, n):
    """Hitzezonen: Rechtecke (2–4 Tiles) in freier Luft, nicht in Pad-Anflugzonen und nicht am Tor; der Grundriss bleibt erreichbar."""
    g = res["grid"]
    out = []
    for _ in range(800):
        w = rnd.randint(2, 4)
        h = rnd.randint(2, 4)
        x0 = rnd.randint(3, W - 3 - w)
        y0 = rnd.randint(4, 17 - h)
        rc = (x0, x0 + w - 1, y0, y0 + h - 1)
        if any(g.g[y][x] != "." for y in range(y0, y0 + h) for x in range(x0, x0 + w)):
            continue
        if _rect_hit(rc, (GATE_ZONE[0] - 1, GATE_ZONE[1] + 1, 1, 10)):
            continue
        if any(_rect_hit(rc, (o.rx0 - 1 - o.ext, o.rx1 + 1 + o.ext, o.top - 3, o.bot + 1)) for o in res["islands"]):
            continue
        if any(_rect_hit((rc[0] - 2, rc[1] + 2, rc[2] - 2, rc[3] + 2), o) for o in out):
            continue
        if not _rect_blocks_path(res, [rc] + [o for o in out]):
            continue
        out.append(rc)
        if len(out) >= n:
            break
    return out


def beam_sites(res, rnd, n):
    """Plasmastrahlen: freie Strecken, die an beiden Enden an Fels grenzen (Emitter sitzen im Fels). Waagerecht (1 Tile hoch)
    oder senkrecht (1 Tile breit), nicht in Pad-Anflugzonen und nicht im Torbereich. Rückgabe: [(x, y, w, h)] in Tiles."""
    g = res["grid"]
    cands = []
    for y in range(4, 18):
        x = 2
        while x < W - 2:
            if g.g[y][x] == ".":
                x1 = x
                while x1 + 1 < W - 1 and g.g[y][x1 + 1] == ".":
                    x1 += 1
                if g.g[y][x - 1] == "#" and g.g[y][x1 + 1] == "#" and 5 <= x1 - x + 1 <= 24:
                    cands.append((x, y, x1 - x + 1, 1))
                x = x1 + 1
            else:
                x += 1
    for x in range(2, W - 2):
        y = 2
        while y < FLOOR:
            if g.g[y][x] == ".":
                y1 = y
                while y1 + 1 < FLOOR and g.g[y1 + 1][x] == ".":
                    y1 += 1
                if g.g[y - 1][x] == "#" and g.g[y1 + 1][x] == "#" and 5 <= y1 - y + 1 <= 18:
                    cands.append((x, y, 1, y1 - y + 1))
                y = y1 + 1
            else:
                y += 1
    ok = []
    for (x, y, w, h) in cands:
        rc = (x, x + w - 1, y, y + h - 1)
        if any(_rect_hit(rc, (a - 1, b + 1, top - 6, top + 1)) for (a, b, top) in res["pads"].values()):
            continue
        if any(_rect_hit(rc, (m["x"] - m["dx"] - 1, m["x"] + m["w"] + m["dx"] + 1, m["y"] - 6, m["y"] + 2)) for m in res["moving"]):
            continue
        if _rect_hit(rc, (GATE_ZONE[0] - 1, GATE_ZONE[1] + 1, 1, 10)):
            continue
        ok.append((x, y, w, h))
    rnd.shuffle(ok)
    out = []
    for c in ok:
        if all(not _rect_hit((c[0] - 2, c[0] + c[2] + 1, c[1] - 2, c[1] + c[3] + 1), (o[0], o[0] + o[2] - 1, o[1], o[1] + o[3] - 1)) for o in out):
            out.append(c)
        if len(out) >= n:
            break
    return out
