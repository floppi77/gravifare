"""S1-01 'Erster Flug': große offene Halle, drei Pads, großzügig. Aufruf aus der Projektwurzel."""
import sys; sys.path.insert(0, "tools")
from levelkit import Grid, write
g = Grid()
g.rect("#", 1, 20, 38, 20)                                  # Boden
g.rect("#", 2, 19, 9, 19); g.rect("1", 3, 18, 8, 18)        # Startpad 1 (6 Tiles) mit Sockel
g.rect("#", 2, 18, 2, 18); g.rect("#", 9, 18, 9, 18)
g.rect("#", 29, 19, 37, 19); g.rect("2", 30, 18, 36, 18)    # Pad 2 rechts unten (7 Tiles)
g.rect("#", 29, 18, 29, 18); g.rect("#", 37, 18, 37, 18)
g.rect("#", 23, 11, 30, 12); g.rect("3", 24, 10, 29, 10)    # Pad 3 auf schwebender Insel (6 Tiles)
g.rect("#", 23, 10, 23, 10); g.rect("#", 30, 10, 30, 10)
g.rect("#", 13, 19, 18, 19); g.rect("F", 13, 18, 18, 18)    # Tankpad
g.gate()
g.put("S", 6, 17)
write("S1-01", 1, 1, "Erster Flug", "First Flight", g,
      [{"from": "2", "to": "3", "fare": 40, "par": 22, "passenger": "Mika", "gender": "f"},
       {"from": "1", "to": "exit", "fare": 60, "par": 24, "passenger": "Odo", "gender": "m"}])
g.show()
