"""Markiert einzelne bestehende Aufträge der Originallevel als VIP bzw. Notfall (Runde 61). Ändert nur das Feld "kind" am gewählten Auftrag;
Karte, Routen, Richtzeiten, Zeitziele und die übrige Schreibweise der Datei bleiben byteweise gleich (Prüfung nach dem Schreiben).

Auswahl aus den Messwerten des Autopiloten (tools/levelmarks/measure_jobs.gd, eine JSON-Zeile je Level mit "JOBS "-Präfix):
- VIP: ein Auftrag je Level ab Sektor 4 (in Notfall-Leveln aus den übrigen Aufträgen) – nie der Ausgangs-Auftrag, kein Krankentransport; der Autopilot hat den Fahrgast abgeholt, und zwar am schnellsten
  (halbe Geduld: so kommt er auch dann noch rechtzeitig, wenn er langsamer ist).
- Notfall: in jedem zweiten Level ab Sektor 6 (Levelnummer gerade: 56, 58 … 98) ein anderer Auftrag als der VIP, mit der größten Reserve
  1,3 × Richtzeit − Autopilot-Zeit (Erscheinen bis Absetzen). Reicht die Frist dort für den Autopiloten nicht, das ungerade Nachbarlevel (erst n+1, dann n−1).
- Ohne Messung (Handlevel, in denen der Autopilot nicht so weit kommt) wird statisch gewählt: VIP = kürzester Anflug vom vorigen Ziel, Notfall =
  längste Richtzeit (die Richtzeiten dieser Level stammen aus den Handzeiten des Entwicklers).
Aufruf: python3 tools/levelmarks/mark_levels.py <jobs.jsonl> [--write]   (ohne --write nur Bericht)
Ergebnis: tools/levelmarks/marks.json (gewählte Aufträge und Messwerte, Grundlage für LEVELS.md und den Bericht)."""
import json, sys

DEADLINE = 1.3
VIP_MAX_WAIT = 30.0            # Sekunden bis zum Einsteigen; die VIP-Geduld liegt bei mindestens 45 s (halbe Mindestgeduld 90 s)

def load(path):
    out = {}
    for line in open(path, encoding="utf-8"):
        line = line.strip()
        if line.startswith("JOBS "):
            d = json.loads(line[5:])
            out[d["id"]] = d
    return out

def pads_of(level):
    """Pad-Mittelpunkte (Felder) aus der Karte: Ziffern = Passagierpads, S = Start."""
    cells = {}
    for y, row in enumerate(level["map"]):
        for x, ch in enumerate(row):
            if ch.isdigit() or ch == "S":
                cells.setdefault(ch, []).append((x, y))
    return {k: (sum(c[0] for c in v) / len(v), sum(c[1] for c in v) / len(v)) for k, v in cells.items()}

def approach(level, jobs, i):
    """Statische Anflugstrecke (Felder, Manhattan) vom vorigen Ziel (bzw. Start) zum Abholpad von Auftrag i."""
    pads = pads_of(level)
    prev = "S" if i == 0 else str(jobs[i - 1]["to"])
    a, b = pads.get(prev), pads.get(str(jobs[i]["from"]))
    return 999.0 if a is None or b is None else abs(a[0] - b[0]) + abs(a[1] - b[1])

def reserve(j):
    return j["par"] * DEADLINE - j["drop"]

def choose_vip(d, level, skip=-1):
    jobs = [j for j in d["jobs"] if not j["exit"] and not j["fragile"] and not j.get("missed") and j["i"] != skip]
    cands = [j for j in jobs if j["wait"] >= 0.0 and j["drop"] >= 0.0 and j["wait"] <= VIP_MAX_WAIT]
    if cands:
        return min(cands, key=lambda j: (j["wait"], j["i"])), "Autopilot"
    allj = [j for j in d["jobs"] if not j["exit"] and not j["fragile"] and j["i"] != skip]
    return (min(allj, key=lambda j: (approach(level, level["jobs"], j["i"]), j["i"])), "statisch") if allj else (None, "")

def choose_emergency(d, vip):
    jobs = [j for j in d["jobs"] if not j["exit"] and not j["fragile"] and (vip is None or j["i"] != vip["i"])]
    measured = [j for j in jobs if j["drop"] >= 0.0 and not j.get("missed")]
    if measured:
        return max(measured, key=lambda j: (reserve(j), -j["i"])), "Autopilot"
    return (max(jobs, key=lambda j: (j["par"], -j["i"])), "statisch") if jobs else (None, "")

def best_reserve(d, vip):
    e, how = choose_emergency(d, vip)
    return reserve(e) if e is not None and how == "Autopilot" else None

def insert_kind(text, job_index, kind):
    """Fügt am Ende des job_index-ten Auftrags `"kind": "<kind>"` ein, in der Einrückung der Datei."""
    start = text.index('"jobs": [')
    pos = start
    for k in range(job_index + 1):
        pos = text.index("{", pos + 1)
    end = text.index("}", pos)
    body = text[pos:end]
    lines = body.rstrip().split("\n")
    key_line = lines[-1]
    ind = key_line[:len(key_line) - len(key_line.lstrip())]
    new_body = body.rstrip() + ",\n" + ind + '"kind": "%s"' % kind + body[len(body.rstrip()):]
    return text[:pos] + new_body + text[end:]

def main():
    data = load(sys.argv[1])
    write = "--write" in sys.argv
    levels = {lid: json.load(open("data/levels/%s.json" % lid, encoding="utf-8")) for lid in data}
    by_num = {d["number"]: lid for lid, d in data.items()}
    # Notfall: jedes zweite Level ab 56 (gerade Nummer); ist es für den Autopiloten zu knapp, das ungerade Nachbarlevel
    emer_levels, used = [], set()
    for n in range(56, 100, 2):
        pick = n
        r = best_reserve(data[by_num[n]], None)
        if r is None or r < 0.0:
            for alt in (n + 1, n - 1):
                if alt in by_num and alt not in used and alt >= 56:
                    ra = best_reserve(data[by_num[alt]], None)
                    if ra is not None and ra >= 0.0:
                        pick = alt
                        break
        used.add(pick)
        emer_levels.append(pick)
    marks = {}
    for lid in sorted(data):
        d = data[lid]
        if d["number"] < 34:
            continue
        emer, ehow = choose_emergency(d, None) if d["number"] in emer_levels else (None, "")      # zuerst der Notfall (engere Bedingung), dann der VIP aus den übrigen
        vip, vhow = choose_vip(d, levels[lid], emer["i"] if emer is not None else -1)
        marks[lid] = {"number": d["number"], "bot_complete": d["complete"],
                      "vip": None if vip is None else {"job": vip["i"], "wait": vip["wait"], "drop": vip["drop"], "par": vip["par"], "chosen": vhow},
                      "emergency": None if emer is None else {"job": emer["i"], "drop": emer["drop"], "par": emer["par"], "chosen": ehow,
                                                               "deadline": round(emer["par"] * DEADLINE, 1), "margin": round(reserve(emer), 1) if emer["drop"] >= 0 else None}}
        if vip is None:
            print("ohne VIP:", lid)
        if write:
            p = "data/levels/%s.json" % lid
            text = open(p, encoding="utf-8").read()
            old = json.loads(text)
            new_text = text
            for j, kind in ((vip, "vip"), (emer, "emergency")):
                if j is not None and "kind" not in old["jobs"][j["i"]]:
                    new_text = insert_kind(new_text, j["i"], kind)
            new = json.loads(new_text)
            for i, job in enumerate(new["jobs"]):                    # Prüfung: nur "kind" ist dazugekommen
                o = dict(job); o.pop("kind", None)
                assert o == old["jobs"][i], (lid, i)
            assert {k: v for k, v in new.items() if k != "jobs"} == {k: v for k, v in old.items() if k != "jobs"}, lid
            open(p, "w", encoding="utf-8").write(new_text)
    json.dump(marks, open("tools/levelmarks/marks.json", "w", encoding="utf-8"), indent=1, ensure_ascii=False)
    em = [(m["emergency"]["margin"], lid, m) for lid, m in marks.items() if m["emergency"]]
    print("VIP: %d Level (%d statisch), Notfall: %d Level: %s" % (sum(1 for m in marks.values() if m["vip"]), sum(1 for m in marks.values() if m["vip"] and m["vip"]["chosen"] == "statisch"),
          len(em), " ".join(str(m["number"]) for _, _, m in sorted(em, key=lambda x: x[2]["number"]))))
    print("Notfall-Fristen (Reserve = 1,3 × Richtzeit − Autopilot), knappste zuerst:")
    for mg, lid, m in sorted(em, key=lambda x: (x[0] is None, x[0] if x[0] is not None else 0)):
        e = m["emergency"]
        print("  Level %d (%s) Auftrag %d: Richtzeit %.0f s, Frist %.1f s, Autopilot %s, Reserve %s [%s]" % (m["number"], lid, e["job"] + 1, e["par"], e["deadline"],
              "%.1f s" % e["drop"] if e["drop"] >= 0 else "–", "%.1f s" % mg if mg is not None else "–", e["chosen"]))

if __name__ == "__main__":
    main()
