"""Gemeinsame Hilfen der Bilderzeuger für die fünf Pixelgrößen (Runde 72).

Das Spiel skaliert ganzzahlig, 720p = 2 … 2160p = 6 Bildschirmpunkte je Welteinheit (src/core/pixel_scale.gd). Jede Grafik, die im Level 1:1
erscheint, wird für jede dieser Größen n eigens gerastert statt aus einem Bild skaliert.

Entwurfsraster: Die Formen sind in „Entwurfspunkten“ beschrieben (3 je Einheit, wie die bisherigen Bilder; Koordinaten wie in Aseprite, ein Punkt
= ein Pixelindex, Rechtecke einschließlich der Endpunkte). `Sc` setzt sie für n um: Kanten fallen auf ganze Bildpunkte, Kleinteile und Striche
haben mindestens einen Bildpunkt (bis Größe 4 einen, darüber zwei). Bei n = 3 entsteht genau das bisherige Bild.

Blattformat: die Größen 2, 3, 4, 5, 6 untereinander, links bündig (siehe `stack`)."""
import math
from PIL import Image, ImageDraw

SIZES = (2, 3, 4, 5, 6)


def rnd(v):
    return int(math.floor(v + 0.5))


def stroke(n):
    """Strichstärke in Bildpunkten für einen Entwurfspunkt: 1 bis 1440p, darüber 2."""
    return max(1, rnd(n / 3.0))


def stack(images, n_list=SIZES):
    """Bilder je Größe (dict n → Bild gleicher Einheitengröße) untereinander in ein Blatt legen."""
    w = max(images[n].width for n in n_list)
    h = sum(images[n].height for n in n_list)
    sheet = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    y = 0
    for n in n_list:
        sheet.paste(images[n], (0, y))
        y += images[n].height
    return sheet


class Sc:
    """Zeichenfläche, die Entwurfskoordinaten (3 Punkte je Einheit) auf n Bildpunkte je Einheit umsetzt."""

    def __init__(self, img, n, kx=None, ky=None):
        """kx, ky: Bildpunkte je Entwurfspunkt waagerecht/senkrecht (Vorgabe n/3); anders nur, wenn eine Form ungleich gedehnt entworfen wird."""
        self.img, self.n = img, n
        self.k = n / 3.0
        self.kx = self.k if kx is None else kx
        self.ky = self.k if ky is None else ky
        self.d = ImageDraw.Draw(img)
        self.t = stroke(n)

    # Kanten: Entwurfspunkt i überdeckt [i, i+1) in Entwurfseinheiten
    def _lo(self, v, y=False):
        return rnd(v * (self.ky if y else self.kx))

    def _hi(self, v, y=False):             # letzter Bildpunkt eines Bereichs, der bei Entwurfspunkt v (einschließlich) endet
        return rnd((v + 1) * (self.ky if y else self.kx)) - 1

    def S(self, v):
        """Länge in Entwurfspunkten → Bildpunkte (mindestens 1)."""
        return max(1, rnd(v * self.k))

    def rectangle(self, box, fill=None):
        x0, y0, x1, y1 = box
        a, b, c, e = self._lo(x0), self._lo(y0, True), self._hi(x1), self._hi(y1, True)
        self.d.rectangle([a, b, max(c, a), max(e, b)], fill=fill)

    def line(self, pts, fill=None, width=1):
        """Achsenparallele Linie (Entwurfspunkte, Endpunkte eingeschlossen), `width` Entwurfspunkte dick (mindestens ein Bildpunkt)."""
        if not isinstance(pts[0], (tuple, list)):
            pts = [(pts[0], pts[1]), (pts[2], pts[3])]
        if len(pts) > 2:                                           # Linienzug: Stück für Stück
            for a, b in zip(pts[:-1], pts[1:]):
                self.line([a, b], fill, width)
            return
        (x0, y0), (x1, y1) = pts[0], pts[-1]
        if y0 == y1:
            self.rectangle([min(x0, x1), y0, max(x0, x1), y0 + width - 1], fill)
        elif x0 == x1:
            self.rectangle([x0, min(y0, y1), x0 + width - 1, max(y0, y1)], fill)
        else:
            self.d.line([((x0 + .5) * self.kx - .5, (y0 + .5) * self.ky - .5), ((x1 + .5) * self.kx - .5, (y1 + .5) * self.ky - .5)], fill=fill,
                        width=max(1, rnd(width * self.k)))

    def point(self, xy, fill=None):
        """Ein Entwurfspunkt: ein Quadrat von 1 Bildpunkt (bis Größe 4) bzw. 2 Bildpunkten."""
        x, y = rnd(xy[0] * self.kx), rnd(xy[1] * self.ky)
        self.d.rectangle([x, y, x + self.t - 1, y + self.t - 1], fill=fill)

    def polygon(self, pts, fill=None, outline=None):
        self.d.polygon([((x + .5) * self.kx - .5, (y + .5) * self.ky - .5) for x, y in pts], fill=fill, outline=outline)

    def ellipse(self, box, fill=None, outline=None):
        x0, y0, x1, y1 = box
        self.d.ellipse([self._lo(x0), self._lo(y0, True), max(self._hi(x1), self._lo(x0)), max(self._hi(y1, True), self._lo(y0, True))], fill=fill, outline=outline)

    def vgrad(self, box, top, bot):
        x0, y0, x1, y1 = box
        a, c = self._lo(x0), max(self._hi(x1), self._lo(x0))
        r0, r1 = self._lo(y0, True), max(self._hi(y1, True), self._lo(y0, True))
        for y in range(r0, r1 + 1):
            u = (y - r0) / max(1, r1 - r0)
            col = tuple(int(top[i] + (bot[i] - top[i]) * u) for i in range(3)) + (255,)
            self.d.rectangle([a, y, c, y], fill=col)

    def rounded_rectangle(self, box, radius=0, fill=None, outline=None, width=1):
        x0, y0, x1, y1 = box
        self.d.rounded_rectangle([self._lo(x0), self._lo(y0, True), max(self._hi(x1), self._lo(x0)), max(self._hi(y1, True), self._lo(y0, True))],
                                 radius=rnd(radius * self.k), fill=fill, outline=outline, width=max(1, rnd(width * self.k)))

    def arc(self, box, start, end, fill=None, width=1):
        x0, y0, x1, y1 = box
        self.d.arc([self._lo(x0), self._lo(y0, True), max(self._hi(x1), self._lo(x0)), max(self._hi(y1, True), self._lo(y0, True))], start, end, fill=fill,
                   width=max(1, rnd(width * self.k)))
