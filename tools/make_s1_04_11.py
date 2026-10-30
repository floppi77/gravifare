"""Sektor 1 'Sternenhafen', Level 4–11 (S1-04 Terrassen … S1-11 Meisterprüfung). Aufruf aus der Projektwurzel.
Jedes Level führt genau einen neuen Gedanken ein; Pars stehen am Ende je Level (aus Bot-Zeiten abgeleitet)."""
import sys; sys.path.insert(0, "tools")
from levelkit import Grid, write

PAR = {}   # wird unten je Level gesetzt


def job(frm, to, fare, par, name, gender):
    return {"from": frm, "to": to, "fare": fare, "par": par, "passenger": name, "gender": gender}


# Pars = Bot-Fahrzeit je Auftrag × 1,3 + 8 s (Bot ab 35 % Sprit, level_report.gd)
PARS = {"S1-04": [32, 40, 31, 26, 32], "S1-05": [31, 40, 32, 33, 34], "S1-06": [32, 54, 30, 33, 37],
        "S1-07": [34, 43, 37, 33, 37], "S1-08": [34, 51, 29, 35, 37], "S1-09": [28, 38, 28, 31, 34, 32],
        "S1-10": [38, 54, 29, 33, 59, 43], "S1-11": [34, 40, 29, 37, 30, 34]}


def make(ident, idx, de, en, g, jobs, **extra):
    for j, p in zip(jobs, PARS[ident]):
        j["par"] = p
    fn = write(ident, 1, idx, de, en, g, jobs, **extra)
    print("== %s %s" % (ident, de))
    g.show()
    return fn


# ---- S1-04 Terrassen: Treppe aus Absätzen, hängender Zapfen vor Pad 3 (erste feste Engstelle, Zick-Zack-Route)
g = Grid()
g.rect("#", 1, 20, 38, 20)
g.pad("1", 2, 8, 19)                                         # Startpad unten links
g.rect("#", 12, 16, 19, 19); g.pad("2", 13, 17, 15)          # Absatz 1 (5 Tiles)
g.rect("P", 20, 17, 20, 18); g.pad("F", 20, 27, 19)          # Tankpad am Boden, 8 Tiles (Zapfsäule am linken Ende)
g.rect("#", 28, 12, 33, 19); g.pad("3", 28, 32, 11)          # Absatz 2 (5 Tiles)
g.rect("#", 1, 9, 9, 10); g.pad("4", 2, 6, 8)                # Ablage oben links (5 Tiles)
g.rect("#", 25, 1, 28, 7)                                    # hängender Zapfen: Engstelle über Pad 3
g.gate()
g.put("S", 5, 18)
make("S1-04", 4, "Terrassen", "Terraces", g, [
    job("3", "2", 60, 30, "Mika", "f"),
    job("4", "3", 70, 40, "Odo", "m"),
    job("1", "4", 75, 36, "Ines", "f"),
    job("2", "3", 80, 30, "Jonas", "m"),
    job("4", "exit", 100, 24, "Lena", "f"),
])

# ---- S1-05 Doppelschacht: zwei 5 Tiles breite Schächte mit Pads am Grund, Tankpad auf dem Mittelblock
g = Grid()
g.rect("#", 1, 20, 38, 20)
g.rect("#", 1, 10, 8, 19); g.pad("1", 2, 7, 9)               # Block links, Startpad oben
g.rect("#", 14, 12, 25, 19); g.pad("F", 15, 21, 11); g.rect("P", 15, 9, 15, 10)      # Tankpad 7 Tiles
g.rect("3", 9, 19, 13, 19)                                   # Pad 3 am Grund Schacht 1
g.rect("2", 26, 19, 30, 19)                                  # Pad 2 am Grund Schacht 2
g.rect("#", 31, 9, 38, 19); g.pad("4", 32, 37, 8)            # Block rechts, Pad 4 oben
g.rect("L", 22, 11, 25, 11)                                  # Lebens-Station (kleine Plattform neben dem Tankpad, alle 5 Level)
g.gate()
g.put("S", 4, 8)
make("S1-05", 5, "Doppelschacht", "Twin Shafts", g, [
    job("3", "2", 80, 36, "Mika", "f"),
    job("4", "3", 90, 44, "Odo", "m"),
    job("2", "4", 90, 40, "Lena", "f"),
    job("1", "2", 80, 40, "Jonas", "m"),
    job("3", "exit", 120, 36, "Ines", "f"),
])

# ---- S1-06 Tankwart: Tankpad auf Mittelsäule; Querfahrten fressen Sprit, Tanken wird Pflicht
g = Grid()
g.rect("#", 1, 20, 38, 20)
g.rect("#", 16, 12, 23, 19); g.pad("F", 16, 23, 11)          # Mittelsäule mit Tankpad, 8 Tiles
g.rect("P", 16, 9, 16, 10)
g.rect("#", 28, 9, 38, 10); g.pad("4", 32, 37, 8)            # Überhang rechts oben mit Pad 4
g.pad("1", 30, 36, 19)                                       # Startpad unten rechts, unter dem Überhang
g.rect("#", 1, 12, 8, 19); g.pad("2", 2, 7, 11)              # Block links mit Pad 2
g.rect("#", 1, 6, 10, 7); g.pad("3", 3, 9, 5)                # Ablage links oben, Pad 3
g.gate()
g.put("S", 33, 18)
make("S1-06", 6, "Tankwart", "Fuel Master", g, [
    job("3", "2", 70, 28, "Lena", "f"),
    job("4", "3", 90, 44, "Mika", "f"),
    job("2", "4", 90, 44, "Odo", "m"),
    job("1", "2", 80, 40, "Jonas", "m"),
    job("3", "exit", 110, 26, "Ines", "f"),
])

# ---- S1-08 Dornenpfad: Dornen sind echte Gefahr (fester Schaden); Pfeiler mit Dornenkopf, Dornenband an der Decke
g = Grid()
g.rect("#", 1, 20, 38, 20)
g.pad("1", 2, 8, 19)
g.rect("#", 1, 12, 9, 13); g.pad("F", 3, 7, 11); g.rect("P", 3, 9, 3, 10)   # Tankablage links, 5 Tiles
g.rect("#", 1, 6, 9, 7); g.pad("4", 2, 8, 5)                # Ablage oben links
g.rect("#", 13, 14, 16, 19); g.rect("^", 13, 13, 16, 13)    # Dornenpfeiler
g.rect("#", 19, 17, 26, 19); g.pad("2", 20, 25, 16)
g.rect("#", 29, 12, 31, 19); g.rect("^", 29, 11, 31, 11)    # zweiter Dornenpfeiler
g.rect("#", 34, 15, 38, 19); g.pad("3", 34, 38, 14)
g.rect("#", 32, 4, 38, 5); g.rect("^", 32, 6, 38, 6)        # Decke rechts mit Dornenband
g.gate()
g.put("S", 5, 18)
make("S1-08", 8, "Dornenpfad", "Thorn Path", g, [
    job("3", "2", 70, 28, "Ines", "f"),
    job("4", "3", 90, 44, "Odo", "m"),
    job("2", "4", 85, 40, "Lena", "f"),
    job("1", "3", 80, 40, "Jonas", "m"),
    job("2", "exit", 110, 26, "Mika", "f"),
], mechanics=["spikes"])

# ---- S1-07 Rundkurs: Mittelblock mit Ringweg; weit auseinander liegende Pads, lange Strecken
g = Grid()
g.rect("#", 1, 20, 38, 20)
g.rect("#", 12, 9, 27, 14)                                   # Mittelblock (Oberkante Zeile 9: 96 px unter dem Tor)
g.pad("1", 2, 8, 19)
g.pad("2", 31, 37, 19)
g.rect("#", 1, 6, 5, 7); g.pad("3", 1, 5, 5)                 # Wandablage links oben
g.rect("#", 34, 6, 38, 7); g.pad("4", 34, 38, 5)             # Wandablage rechts oben
g.rect("P", 17, 17, 17, 18); g.pad("F", 17, 22, 19)          # Tankpad unter dem Block
g.gate()
g.put("S", 5, 18)
make("S1-07", 7, "Rundkurs", "Ring Road", g, [
    job("3", "2", 80, 40, "Lena", "f"),
    job("4", "1", 90, 44, "Odo", "m"),
    job("2", "3", 90, 44, "Mika", "f"),
    job("1", "4", 90, 44, "Jonas", "m"),
    job("3", "exit", 120, 40, "Ines", "f"),
])

# ---- S1-09 Nadelspitzen: Pads auf Säulen über einem Dornenfeld, Zapfen über Pad 3
g = Grid()
g.rect("#", 1, 20, 38, 20)
g.rect("^", 1, 19, 38, 19)                                   # Dornenboden
g.rect("#", 1, 15, 8, 19); g.pad("1", 2, 7, 14)
g.rect("#", 12, 11, 17, 19); g.pad("2", 12, 16, 10)
g.rect("#", 21, 14, 31, 19); g.pad("3", 21, 25, 13); g.pad("F", 27, 31, 13); g.rect("P", 31, 11, 31, 12)
g.rect("#", 33, 10, 38, 19); g.pad("4", 33, 37, 9)
g.rect("#", 24, 1, 26, 9)                                    # Zapfen über Pad 3
g.rect("^", 10, 1, 12, 1); g.rect("^", 27, 1, 29, 1)         # Dornenbänder an der Decke
g.gate()
g.put("S", 4, 13)
make("S1-09", 9, "Nadelspitzen", "Needle Points", g, [
    job("3", "2", 90, 40, "Odo", "m"),
    job("4", "3", 100, 44, "Lena", "f"),
    job("2", "4", 100, 44, "Mika", "f"),
    job("1", "2", 100, 44, "Jonas", "m"),
    job("4", "1", 100, 44, "Ines", "f"),
    job("3", "exit", 130, 40, "Mika", "f"),
], mechanics=["spikes"])

# ---- S1-10 Tanknot: Tankpad hoch oben auf dem Turm, lange Steigflüge; Dornen unter der Ablage
g = Grid()
g.rect("#", 1, 20, 38, 20)
g.pad("1", 2, 8, 19)
g.rect("#", 1, 7, 7, 8); g.pad("4", 2, 6, 6); g.rect("^", 1, 9, 7, 9)     # Ablage oben links, Dornen darunter
g.rect("#", 12, 10, 16, 19); g.pad("2", 12, 16, 9)           # Turm mit Pad 2
g.rect("#", 28, 8, 32, 19); g.pad("F", 28, 32, 7); g.rect("P", 28, 5, 28, 6)   # Tankturm
g.rect("#", 34, 14, 38, 19); g.pad("3", 34, 38, 13)
g.rect("^", 17, 19, 20, 19); g.rect("^", 25, 19, 27, 19)     # Dornenfelder zwischen den Türmen
g.rect("#", 21, 14, 24, 19); g.rect("L", 21, 13, 24, 13)      # Lebens-Station auf einem Sockel zwischen den Türmen
g.gate()
g.put("S", 5, 18)
make("S1-10", 10, "Tanknot", "Running Dry", g, [
    job("3", "2", 100, 40, "Lena", "f"),
    job("4", "3", 110, 50, "Odo", "m"),
    job("2", "4", 100, 44, "Mika", "f"),
    job("1", "3", 110, 50, "Jonas", "m"),
    job("4", "1", 110, 50, "Ines", "f"),
    job("2", "exit", 130, 36, "Mika", "f"),
], mechanics=["spikes"])

# ---- S1-11 Meisterprüfung: Bunker mit 2-Tiles-Tunnel, Dornenfeld, Tankturm, sechs Aufträge
g = Grid()
g.rect("#", 1, 20, 38, 20)
g.rect("#", 1, 9, 13, 11)                                    # Decke des Bunkers (Startkammer links)
g.rect("#", 9, 14, 13, 19)                                   # Tunnelboden: Tunnel Zeilen 12–13 (32 px)
g.pad("1", 2, 7, 19)
g.rect("#", 14, 15, 19, 19); g.pad("2", 14, 18, 14)          # Pad 2 bündig am Tunnelausgang
g.rect("#", 22, 15, 27, 19); g.pad("F", 22, 26, 14); g.rect("P", 22, 12, 22, 13)
g.rect("#", 23, 1, 25, 8)                                    # Zapfen über dem Tankpad: schwer zugänglich
g.rect("#", 30, 8, 38, 9); g.pad("3", 31, 36, 7)             # Ablage rechts oben
g.pad("4", 31, 37, 19)                                       # Pad 4 unten rechts unter der Ablage
g.rect("^", 28, 19, 29, 19)                                  # Dornen vor Pad 4
g.rect("^", 20, 19, 21, 19)
g.gate()
g.put("S", 5, 18)
make("S1-11", 11, "Meisterprüfung", "Master Exam", g, [
    job("3", "2", 100, 40, "Lena", "f"),
    job("4", "3", 120, 44, "Odo", "m"),
    job("2", "4", 120, 44, "Mika", "f"),
    job("1", "3", 130, 50, "Jonas", "m"),
    job("4", "2", 120, 44, "Ines", "f"),
    job("3", "exit", 150, 40, "Mika", "f"),
], mechanics=["spikes"])
