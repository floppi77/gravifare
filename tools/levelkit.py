"""Kleines Hilfsmodul zum Zeichnen von Level-Rastern (40x22 Standard) und Schreiben der JSON-Datei.
Zeichen: # Fels, 1-9 Pads, F Tankpad, S Start, E Ausgang, ^ Dornen."""
import json, os

class Grid:
    def __init__(self, w=40, h=22):
        self.w, self.h = w, h
        self.g = [["."] * w for _ in range(h)]
        self.rect("#", 0, 0, w - 1, 0); self.rect("#", 0, h - 1, w - 1, h - 1)
        self.rect("#", 0, 0, 0, h - 1); self.rect("#", w - 1, 0, w - 1, h - 1)
    def rect(self, c, x0, y0, x1, y1):
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1):
                self.g[y][x] = c
        return self
    def pad(self, ident, x0, x1, row, support=True):
        """Pad auf Zeile row, darunter Fels bis zum Boden/Unterkante, falls support."""
        self.rect(str(ident), x0, row, x1, row)
        if support:
            y = row + 1
            while y < self.h - 1 and self.g[y][x0] == ".":
                self.rect("#", x0, y, x1, y); y += 1
        return self
    def put(self, c, x, y): self.g[y][x] = c; return self
    def rows(self): return ["".join(r) for r in self.g]
    def show(self): print("\n".join(self.rows()))

def write(ident, sector, index, name_de, name_en, grid, jobs, **extra):
    d = {"id": ident, "sector": sector, "index": index, "name": {"de": name_de, "en": name_en},
         "map": grid.rows(), "jobs": jobs}
    d.update(extra)
    fn = "data/levels/%s.json" % ident.lower().replace("-", "_")
    json.dump(d, open(fn, "w"), indent=1, ensure_ascii=False)
    return fn
