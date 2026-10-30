"""Erzeugt data/levels/s1_01.json. Aufruf aus der Projektwurzel: python3 tools/make_level_s1_01.py"""
import sys; sys.path.insert(0, "tools")
from levelkit import Grid, write
g = Grid()
g.rect("#", 1, 20, 38, 20)                 # Boden
g.rect("#", 2, 19, 8, 19); g.rect("1", 3, 18, 7, 18)
g.rect("#", 2, 18, 2, 18); g.rect("#", 8, 18, 8, 18)   # Startpad mit Sockel
g.rect("#", 27, 15, 37, 19); g.rect("2", 29, 14, 34, 14)  # Plattform rechts mit Pad 2
g.rect("#", 13, 19, 17, 19); g.rect("F", 13, 18, 17, 18)  # Tankpad am Boden
g.rect("#", 9, 1, 11, 7)                   # hängender Pfeiler links der Mitte
g.gate()
g.put("S", 5, 17)
write("S1-01", 1, 1, "Erster Flug", "First Flight", g,
      [{"from": "1", "to": "2", "fare": 40, "time_limit": 45, "passenger": "Mika", "gender": "f"},
       {"from": "2", "to": "1", "fare": 40, "time_limit": 45, "passenger": "Odo", "gender": "m"}], par_time=80)
g.show()
