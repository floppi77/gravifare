"""S1-02 'Tankstopp' und S1-03 'Der Schornstein'. Aufruf aus Projektwurzel: python3 tools/make_s1_02_03.py"""
import sys; sys.path.insert(0, "tools")
from levelkit import Grid, write

# ---- S1-02: Zwei Ebenen links, Mitte Tankpad, rechts Pad 2; knapper Startvorrat (45)
g = Grid()
g.rect("#", 1, 20, 38, 20)                # Boden
g.rect("#", 1, 19, 8, 19); g.rect("1", 2, 18, 7, 18); g.rect("#", 1, 18, 1, 18); g.rect("#", 8, 18, 8, 18)  # Startpad mit Sockel
g.rect("#", 1, 9, 8, 11); g.rect("3", 2, 8, 7, 8) # hohes Regal links mit Pad 3
g.rect("#", 14, 1, 17, 7)                 # hängender Block
g.rect("#", 13, 19, 20, 19); g.rect("F", 14, 18, 19, 18)  # Tankpad
g.rect("#", 24, 11, 27, 19)               # mittlere Säule
g.rect("#", 30, 15, 37, 19); g.rect("2", 31, 14, 36, 14)  # Pad 2 rechts
g.rect("#", 29, 6, 38, 8)                 # Deckenplatte rechts
g.gate()
g.put("S", 4, 17)
w = write("S1-02", 1, 2, "Tankstopp", "Fuel Stop", g,
          [{"from": "1", "to": "2", "fare": 45, "time_limit": 50, "passenger": "Mika", "gender": "f"},
           {"from": "2", "to": "3", "fare": 55, "time_limit": 55, "passenger": "Odo", "gender": "m"},
           {"from": "3", "to": "1", "fare": 55, "time_limit": 55, "passenger": "Lena", "gender": "f"}],
          start_fuel=45, par_time=110)
print(w); g.show()

# ---- S1-03: Schornstein – 4 Tiles breiter Schacht mit Pad am Grund
g = Grid()
g.rect("#", 1, 20, 38, 20)                # Boden
g.rect("#", 14, 6, 27, 19)                # Block
g.rect(".", 18, 6, 22, 19)                # Schacht 5 Tiles breit (fairer Anflug)
g.rect(".", 18, 6, 22, 19)
g.rect("3", 18, 19, 22, 19)               # Pad 3 am Schachtgrund (Zeile 19)
g.rect("#", 17, 19, 17, 19); g.rect("#", 23, 19, 23, 19)
g.rect("#", 1, 19, 8, 19); g.rect("1", 2, 18, 7, 18)
g.rect("#", 31, 17, 38, 19); g.rect("2", 32, 16, 37, 16)
g.rect("#", 29, 19, 30, 19)
g.gate()
g.put("S", 4, 17)
w = write("S1-03", 1, 3, "Der Schornstein", "The Chimney", g,
          [{"from": "1", "to": "3", "fare": 60, "time_limit": 60, "passenger": "Ines", "gender": "f"},
           {"from": "3", "to": "2", "fare": 70, "time_limit": 60, "passenger": "Jonas", "gender": "m"}],
          par_time=100)
print(w); g.show()
