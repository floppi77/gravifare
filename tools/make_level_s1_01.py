"""S1-01 'Erster Flug': große offene Halle, drei große Pads (8/8/7 Tiles). Aufruf aus der Projektwurzel."""
import sys; sys.path.insert(0, "tools")
from levelkit import Grid, write
g = Grid()
g.rect("#", 1, 20, 38, 20)                                  # Boden
g.rect("#", 2, 19, 11, 19); g.rect("1", 3, 18, 10, 18)      # Startpad 1 (8 Tiles) mit Sockel
g.rect("#", 2, 18, 2, 18); g.rect("#", 11, 18, 11, 18)
g.rect("#", 28, 19, 37, 19); g.rect("2", 29, 18, 36, 18)    # Pad 2 rechts unten (8 Tiles)
g.rect("#", 28, 18, 28, 18); g.rect("#", 37, 18, 37, 18)
g.rect("#", 23, 11, 31, 12); g.rect("3", 24, 10, 30, 10)    # Pad 3 auf schwebender Insel (7 Tiles)
g.rect("#", 23, 10, 23, 10); g.rect("#", 31, 10, 31, 10)
g.rect("#", 13, 19, 20, 19); g.rect("F", 14, 18, 19, 18)    # Tankpad (6 Tiles)
g.rect("P", 14, 16, 14, 17)                                  # Zapfsäule am linken Padende
g.gate()
g.put("S", 7, 17)
write("S1-01", 1, 1, "Erster Flug", "First Flight", g,
      [{"from": "2", "to": "3", "fare": 40, "par": 22, "passenger": "Mika", "gender": "f"},
       {"from": "1", "to": "exit", "fare": 60, "par": 24, "passenger": "Odo", "gender": "m"}])
g.show()
