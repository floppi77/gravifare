"""S1-02 'Tankstopp' und S1-03 'Der Schornstein'. Aufruf aus der Projektwurzel."""
import sys; sys.path.insert(0, "tools")
from levelkit import Grid, write

# ---- S1-02: drei Ebenen, Säule in der Mitte, Tankpad; großzügige Anflüge
g = Grid()
g.rect("#", 1, 20, 38, 20)                                   # Boden
g.rect("#", 2, 19, 9, 19); g.rect("1", 3, 18, 8, 18)         # Startpad 1
g.rect("#", 2, 18, 2, 18); g.rect("#", 9, 18, 9, 18)
g.rect("#", 1, 9, 8, 11); g.rect("3", 2, 8, 7, 8)            # hohes Regal links mit Pad 3
g.rect("#", 14, 1, 17, 5)                                    # hängender Block (Lücke zum Regal 80 px)
g.rect("#", 13, 19, 20, 19); g.rect("F", 14, 18, 19, 18)     # Tankpad
g.rect("#", 23, 9, 25, 19)                                   # Säule aus dem Boden
g.rect("#", 30, 13, 38, 19); g.rect("2", 31, 12, 37, 12)     # Pad 2 rechts erhöht (7 Tiles)
g.gate()
g.put("S", 6, 17)
write("S1-02", 1, 2, "Tankstopp", "Fuel Stop", g,
      [{"from": "3", "to": "2", "fare": 50, "par": 22, "passenger": "Mika", "gender": "f"},
       {"from": "1", "to": "3", "fare": 55, "par": 37, "passenger": "Odo", "gender": "m"},
       {"from": "2", "to": "exit", "fare": 80, "par": 16, "passenger": "Lena", "gender": "f"}])
g.show()

# ---- S1-03: 5 Tiles breiter Schacht mit Pad 3 am Grund; Tankpad auf dem Block; breite Flugwege (7 Tiles links)
g = Grid()
g.rect("#", 1, 20, 38, 20)                                   # Boden
g.rect("#", 15, 9, 28, 19)                                   # Block (Oberkante Zeile 9: 96 px Durchflug unter dem Torblock)
g.rect("F", 15, 9, 18, 9)                                    # Tankpad auf dem Block (links vom Schacht)
g.rect(".", 19, 9, 23, 19)                                   # Schacht, 5 Tiles breit
g.rect("3", 19, 19, 23, 19)                                  # Pad 3 am Schachtgrund (Zeile 19)
g.rect("#", 18, 19, 18, 19); g.rect("#", 24, 19, 24, 19)
g.rect("#", 1, 19, 9, 19); g.rect("1", 2, 18, 8, 18)         # Startpad 1
g.rect("#", 9, 18, 9, 18)
g.rect("#", 32, 17, 38, 19); g.rect("2", 33, 16, 37, 16)     # Pad 2 rechts (5 Tiles)
g.gate()
g.put("S", 5, 17)
write("S1-03", 1, 3, "Der Schornstein", "The Chimney", g,
      [{"from": "2", "to": "3", "fare": 70, "par": 24, "passenger": "Ines", "gender": "f"},
       {"from": "1", "to": "2", "fare": 60, "par": 40, "passenger": "Jonas", "gender": "m"},
       {"from": "3", "to": "exit", "fare": 100, "par": 14, "passenger": "Lena", "gender": "f"}])
g.show()
