"""Erzeugt data/levels/s1_01.json (handgesetztes Layout, per Raster-Zeichnung)."""
import json, sys
W, H = 40, 22
g = [["."] * W for _ in range(H)]
def rect(c, x0, y0, x1, y1):
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            g[y][x] = c
rect("#", 0, 0, W - 1, 0); rect("#", 0, H - 1, W - 1, H - 1)
rect("#", 0, 0, 0, H - 1); rect("#", W - 1, 0, W - 1, H - 1)
rect("#", 1, 20, W - 2, 20)           # Boden
rect("#", 2, 19, 8, 19)               # Sockel Startpad
rect("1", 3, 18, 7, 18); rect("#", 2, 18, 2, 18); rect("#", 8, 18, 8, 18)
rect("#", 27, 15, 37, 19)             # Plattform rechts
rect("2", 29, 14, 34, 14)
rect("F", 13, 19, 17, 19)             # Tankpad am Boden
rect("#", 19, 1, 21, 8)               # hängender Pfeiler
rect("#", 33, 1, 38, 4)               # Ausgangsnische
rect("E", 34, 5, 37, 6)
rect("#", 1, 1, 4, 3)
g[17][4] = "S"
rows = ["".join(r) for r in g]
level = {
  "id": "S1-01", "sector": 1, "index": 1,
  "name": {"de": "Erster Flug", "en": "First Flight"},
  "map": rows,
  "jobs": [
    {"from": "1", "to": "2", "fare": 40, "time_limit": 45, "passenger": "Mika"},
    {"from": "2", "to": "1", "fare": 40, "time_limit": 45, "passenger": "Mika"}
  ],
  "par_time": 80
}
json.dump(level, open("data/levels/s1_01.json", "w"), indent=1, ensure_ascii=False)
print("\n".join(rows))
