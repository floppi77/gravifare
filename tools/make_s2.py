"""Sektor 2 'Neon-Schluchten', Level 12–22 (S2-01 … S2-11). Aufruf aus der Projektwurzel.
Neue Mechanik: bewegliche Tore (Zeichen a–e im Raster, Takt im JSON unter "doors"). Pars siehe PARS."""
import sys; sys.path.insert(0, "tools")
from levelkit import Grid, write

import json, os
# Pars je endgültiger ID = Bot-Zeit × 1,3 + 8 s (aus tools/level_report.gd); Datei wird nach jedem Messlauf neu geschrieben
PARS = json.load(open("tools/s2_pars.json")) if os.path.exists("tools/s2_pars.json") else {}


def job(frm, to, fare, name, gender):
    return {"from": frm, "to": to, "fare": fare, "par": 40, "passenger": name, "gender": gender}


# Zusätzliche Dornenbänder an der Decke (Zeile 1) je Entwurfsschlüssel: echte Gefahr nahe der Decke, hebt die gemessene Schwierigkeit
BOOST = {"S2-02": 7, "S2-06": 28, "S2-11": 17, "S2-10": 14, "S2-07": 9}


def boost_spikes(g, n):
    placed = 0
    for x in list(range(2, 15)) + list(range(37, 24, -1)):
        if placed >= n:
            break
        if g.g[1][x] == "." and g.g[2][x] == ".":
            g.g[1][x] = "^"
            placed += 1


FINAL = {"S2-01": "S2-01", "S2-02": "S2-02", "S2-06": "S2-03", "S2-11": "S2-04", "S2-10": "S2-05", "S2-04": "S2-06",
         "S2-05": "S2-07", "S2-07": "S2-08", "S2-03": "S2-09", "S2-08": "S2-10", "S2-09": "S2-11"}   # Entwurfsschlüssel -> endgültige ID (nach gemessener Schwierigkeit)


def make(ident, idx, de, en, g, jobs, **extra):
    fid = FINAL.get(ident, ident)
    boost_spikes(g, BOOST.get(ident, 0))
    for j, p in zip(jobs, PARS.get(fid, [])):
        j["par"] = p
    fn = write(fid, 2, int(fid[-2:]), de, en, g, jobs, **extra)
    print("== %s %s" % (ident, de))
    g.show()
    return fn


NAMES = [("Mika", "f"), ("Odo", "m"), ("Lena", "f"), ("Jonas", "m"), ("Ines", "f"), ("Ben", "m"), ("Nora", "f"), ("Tarek", "m")]


def jobs_of(seq, base=120):
    """seq: Liste (von, nach); Namen reihum, Fahrpreis steigt mit der Zahl der Aufträge."""
    out = []
    if len(seq) > 6:                       # Obergrenze Pflichtfahrgäste (Tuning.max_jobs): 5 normale + Ausgangs-Fahrgast
        last = seq[-1]
        seq = list(seq[:5])
        pads = sorted({p for pair in seq for p in pair if p != "exit"})
        prev_to = seq[-1][1]
        frm = last[0] if last[0] != prev_to else next(p for p in pads if p != prev_to)
        seq.append((frm, "exit"))
    for i, (a, b) in enumerate(seq):
        n, gnd = NAMES[i % len(NAMES)]
        out.append(job(a, b, base + 10 * i, n, gnd))
    return out


# ---- S2-01 Schluchteingang: hängender Block mit Dornenkante, schmale Gasse zur oberen Ablage
g = Grid()
g.rect("#", 1, 20, 38, 20)
g.pad("1", 2, 8, 19)
g.rect("#", 1, 8, 8, 9); g.pad("2", 2, 6, 7)
g.rect("#", 22, 13, 27, 19); g.pad("3", 22, 26, 12)
g.rect("#", 32, 6, 38, 7); g.pad("4", 33, 37, 5)
g.rect("P", 29, 17, 29, 18); g.pad("F", 29, 35, 19)
g.rect("#", 12, 1, 15, 11); g.rect("^", 12, 12, 15, 12)
g.gate()
g.put("S", 5, 18)
make("S2-01", 1, "Schluchteingang", "Canyon Mouth", g,
     jobs_of([("3", "2"), ("4", "3"), ("2", "4"), ("1", "3"), ("4", "2"), ("3", "exit")]), mechanics=["spikes"])

# ---- S2-02 Neonallee: zwei schwebende Platten, Dornen unter der Platte, Tankpad auf der Platte
g = Grid()
g.rect("#", 1, 20, 38, 20)
g.pad("1", 2, 8, 19)
g.pad("4", 31, 37, 19)
g.rect("#", 9, 13, 22, 14); g.pad("2", 10, 14, 12); g.pad("F", 17, 22, 12); g.rect("P", 22, 10, 22, 11)
g.rect("#", 25, 8, 36, 9); g.pad("3", 27, 31, 7)
g.rect("^", 12, 19, 18, 19)
g.rect("#", 33, 1, 35, 5); g.rect("^", 33, 6, 35, 6)
g.gate()
g.put("S", 5, 18)
make("S2-02", 2, "Neonallee", "Neon Avenue", g,
     jobs_of([("3", "4"), ("2", "3"), ("4", "2"), ("1", "3"), ("2", "4"), ("3", "1"), ("4", "exit")]), mechanics=["spikes"])

# ---- S2-03 Erste Schleuse: Wand bis zur Decke, bewegliches Tor am Boden (Takt 9 s, 5 s offen)
g = Grid()
g.rect("#", 1, 20, 38, 20)
g.pad("1", 2, 8, 19)
g.rect("#", 1, 9, 8, 10); g.pad("2", 2, 6, 8)
g.rect("#", 12, 15, 19, 19); g.pad("F", 13, 18, 14); g.rect("P", 13, 12, 13, 13)
g.rect("#", 12, 1, 15, 9)
g.rect("#", 28, 1, 29, 19); g.rect("a", 28, 15, 29, 18)
g.pad("3", 31, 37, 19)
g.rect("#", 33, 10, 38, 11); g.pad("4", 33, 37, 9)
g.rect("#", 24, 6, 27, 7); g.rect("L", 24, 5, 27, 5)             # Lebens-Station
g.gate()
g.put("S", 5, 18)
make("S2-03", 3, "Schleusenkammer", "Lock Chamber", g,
     jobs_of([("3", "2"), ("4", "3"), ("1", "4"), ("2", "3"), ("4", "1"), ("3", "exit")]),
     doors={"a": {"period": 9.0, "open": 5.0, "phase": 0.0}}, mechanics=["doors"])

# ---- S2-04 Doppelschleuse: zwei Wandtore im Gegentakt
g = Grid()
g.rect("#", 1, 20, 38, 20)
g.rect("#", 8, 1, 9, 19); g.rect("b", 8, 17, 9, 18)
g.rect("#", 30, 1, 31, 19); g.rect("a", 30, 17, 31, 18)
g.pad("2", 2, 6, 19)
g.pad("4", 32, 37, 19)
g.pad("1", 12, 18, 19)
g.rect("#", 20, 13, 25, 19); g.pad("3", 20, 24, 12)
g.rect("#", 10, 10, 15, 11); g.pad("F", 10, 15, 9); g.rect("P", 10, 7, 10, 8)
g.rect("#", 1, 6, 5, 7)
g.gate()
g.put("S", 15, 18)
make("S2-04", 4, "Doppelschleuse", "Twin Locks", g,
     jobs_of([("3", "2"), ("4", "3"), ("2", "4"), ("1", "2"), ("4", "1"), ("3", "4"), ("2", "3"), ("4", "exit")]),
     doors={"a": {"period": 8.0, "open": 5.0, "phase": 0.0}, "b": {"period": 8.0, "open": 5.0, "phase": 4.0}}, mechanics=["doors"])

# ---- S2-05 Fallgitter: Zwischendecke mit Falltür, oben zwei Pads, unten zwei Pads
g = Grid()
g.rect("#", 1, 20, 38, 20)
g.rect("#", 1, 12, 38, 13); g.rect("a", 18, 12, 21, 13)
g.pad("2", 3, 7, 11)
g.pad("3", 31, 36, 11)
g.pad("1", 2, 8, 19)
g.pad("4", 30, 36, 19)
g.rect("P", 11, 17, 11, 18); g.pad("F", 11, 16, 19)
g.rect("^", 24, 14, 27, 14)
g.gate()
g.put("S", 5, 18)
make("S2-05", 5, "Fallgitter", "Portcullis", g,
     jobs_of([("2", "4"), ("3", "1"), ("4", "3"), ("1", "2"), ("3", "4"), ("2", "1"), ("4", "exit")]),
     doors={"a": {"period": 8.0, "open": 5.0, "phase": 0.0}}, mechanics=["doors", "spikes"])

# ---- S2-06 Doppelfalltür: zwei Falltüren im Wechseltakt
g = Grid()
g.rect("#", 1, 20, 38, 20)
g.rect("#", 1, 12, 38, 13); g.rect("a", 8, 12, 11, 13); g.rect("b", 28, 12, 31, 13)
g.pad("2", 14, 18, 11)
g.pad("3", 22, 26, 11)
g.pad("1", 2, 6, 19)
g.pad("4", 33, 37, 19)
g.rect("P", 13, 17, 13, 18); g.pad("F", 13, 19, 19)
g.rect("^", 24, 14, 27, 14); g.rect("^", 14, 14, 18, 14)
g.gate()
g.put("S", 4, 18)
make("S2-06", 6, "Erste Schleuse", "First Lock", g,
     jobs_of([("3", "1"), ("2", "4"), ("1", "3"), ("4", "2"), ("3", "4"), ("2", "1"), ("4", "3"), ("1", "2"), ("3", "exit")]),
     doors={"a": {"period": 8.0, "open": 4.5, "phase": 0.0}, "b": {"period": 8.0, "open": 4.5, "phase": 4.0}}, mechanics=["doors", "spikes"])

# ---- S2-07 Neonlabyrinth: Zwischendecke mit Falltür links, Wandtor rechts
g = Grid()
g.rect("#", 1, 20, 38, 20)
g.rect("#", 1, 12, 27, 13); g.rect("a", 8, 12, 11, 13)
g.rect("#", 28, 1, 29, 19); g.rect("b", 28, 17, 29, 18)
g.pad("2", 2, 6, 11)
g.pad("3", 14, 18, 11)
g.pad("F", 21, 27, 11); g.rect("P", 27, 9, 27, 10)
g.pad("1", 14, 20, 19)
g.pad("4", 31, 37, 19)
g.rect("^", 3, 14, 6, 14)
g.rect("#", 33, 1, 36, 8)
g.gate()
g.put("S", 17, 18)
make("S2-07", 7, "Neonlabyrinth", "Neon Maze", g,
     jobs_of([("3", "2"), ("4", "3"), ("2", "4"), ("1", "2"), ("3", "1"), ("4", "3"), ("1", "4"), ("2", "exit")]),
     doors={"a": {"period": 7.0, "open": 4.0, "phase": 0.0}, "b": {"period": 9.0, "open": 5.0, "phase": 2.0}}, mechanics=["doors", "spikes"])

# ---- S2-08 Taktgeber: Wandtore mit verschiedenen Takten (2 Tiles hoch), Pad 4 hinter dem rechten Tor
g = Grid()
g.rect("#", 1, 20, 38, 20)
g.rect("#", 8, 1, 9, 19); g.rect("a", 8, 17, 9, 18)
g.rect("#", 28, 1, 29, 19); g.rect("b", 28, 17, 29, 18)
g.rect("#", 10, 12, 27, 13); g.rect("c", 17, 12, 20, 13)
g.pad("2", 2, 6, 19)
g.pad("1", 12, 18, 19)
g.pad("3", 22, 26, 11)
g.pad("F", 11, 16, 11); g.rect("P", 11, 9, 11, 10)
g.rect("#", 34, 9, 38, 10); g.pad("4", 34, 38, 8)
g.rect("^", 22, 19, 26, 19)
g.gate()
g.put("S", 15, 18)
make("S2-08", 8, "Neonfinale", "Neon Finale", g,
     jobs_of([("3", "2"), ("4", "3"), ("2", "4"), ("1", "3"), ("4", "2"), ("3", "1"), ("2", "4"), ("1", "exit")]),
     doors={"a": {"period": 6.0, "open": 3.5, "phase": 0.0}, "b": {"period": 7.0, "open": 4.0, "phase": 3.0}, "c": {"period": 8.0, "open": 4.5, "phase": 5.0}},
     mechanics=["doors", "spikes"])

# ---- S2-09 Glasfassade: hohes Wandtor, schmale Gasse, Dornenkante
g = Grid()
g.rect("#", 1, 20, 38, 20)
g.rect("#", 10, 1, 11, 19); g.rect("a", 10, 3, 11, 7)
g.rect("#", 28, 1, 29, 19); g.rect("b", 28, 15, 29, 18)
g.pad("2", 2, 6, 19)
g.rect("#", 1, 11, 6, 12); g.pad("3", 2, 6, 10)
g.pad("1", 13, 19, 19)
g.rect("#", 20, 14, 24, 19); g.pad("F", 20, 24, 13); g.rect("P", 20, 11, 20, 12)
g.rect("#", 33, 11, 38, 12); g.pad("4", 33, 37, 10)
g.rect("^", 31, 19, 38, 19)
g.rect("^", 14, 1, 15, 1)
g.gate()
g.put("S", 16, 18)
make("S2-09", 9, "Glasfassade", "Glass Facade", g,
     jobs_of([("3", "2"), ("4", "3"), ("2", "4"), ("1", "3"), ("4", "2"), ("3", "4"), ("2", "exit")]),
     doors={"a": {"period": 7.0, "open": 4.0, "phase": 0.0}, "b": {"period": 8.0, "open": 4.5, "phase": 3.0}}, mechanics=["doors", "spikes"])

# ---- S2-10 Rushhour: Falltür und Wandtor im schnellen Takt, acht Aufträge
g = Grid()
g.rect("#", 1, 20, 38, 20)
g.rect("#", 1, 12, 27, 13); g.rect("a", 12, 12, 15, 13)
g.rect("#", 28, 1, 29, 19); g.rect("b", 28, 15, 29, 18)
g.pad("2", 2, 6, 11)
g.pad("3", 16, 20, 11)
g.pad("F", 22, 27, 11); g.rect("P", 27, 9, 27, 10)
g.pad("1", 2, 8, 19)
g.pad("4", 31, 37, 19)
g.rect("#", 33, 1, 36, 8); g.rect("^", 33, 9, 36, 9)
g.rect("^", 7, 14, 10, 14)
g.gate()
g.put("S", 5, 18)
make("S2-10", 10, "Rushhour", "Rush Hour", g,
     jobs_of([("3", "2"), ("4", "3"), ("2", "4"), ("1", "3"), ("4", "2"), ("3", "1"), ("2", "4"), ("1", "exit")]),
     doors={"a": {"period": 6.0, "open": 3.5, "phase": 0.0}, "b": {"period": 7.0, "open": 4.0, "phase": 2.0}}, mechanics=["doors", "spikes"])

# ---- S2-11 Neonfinale: zwei Falltüren, Wandtor, Dornen, schmale Gassen, acht Aufträge
g = Grid()
g.rect("#", 1, 20, 38, 20)
g.rect("#", 1, 12, 27, 13); g.rect("a", 8, 12, 11, 13); g.rect("c", 24, 12, 27, 13)
g.rect("#", 28, 1, 29, 19); g.rect("b", 28, 15, 29, 18)
g.rect("#", 25, 1, 27, 7)
g.pad("2", 2, 6, 11)
g.pad("3", 12, 16, 11)
g.pad("F", 18, 23, 11); g.rect("P", 18, 9, 18, 10)
g.pad("1", 14, 20, 19)
g.pad("4", 31, 37, 19)
g.rect("#", 33, 1, 38, 6); g.rect("^", 33, 7, 38, 7)
g.rect("^", 3, 14, 6, 14)
g.rect("L", 3, 19, 6, 19)                                    # Lebens-Station am Boden links
g.gate()
g.put("S", 17, 18)
make("S2-11", 11, "Zwillingsschleuse", "Twin Gates", g,
     jobs_of([("3", "2"), ("4", "3"), ("2", "4"), ("1", "2"), ("3", "1"), ("4", "3"), ("2", "4"), ("1", "exit")]),
     doors={"a": {"period": 6.0, "open": 3.5, "phase": 0.0}, "b": {"period": 7.0, "open": 4.0, "phase": 3.0}, "c": {"period": 6.0, "open": 3.5, "phase": 3.0}},
     mechanics=["doors", "spikes", "chicane"])
