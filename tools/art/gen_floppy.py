"""Pixel-Disketten für die Speicherplatz-Auswahl (assets/art/floppy_1..3.png, 96×96). Aufruf: python3 tools/art/gen_floppy.py"""
from PIL import Image, ImageDraw

BODY = {1: ("#1d7fa8", "#3fd0f0", "#124f6c"), 2: ("#a83a78", "#ff6fb5", "#6c1f4c"), 3: ("#b07a1c", "#ffc23e", "#6f4b0e")}
for n, (base, hi, lo) in BODY.items():
    im = Image.new("RGBA", (96, 96), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    d.polygon([(6, 4), (82, 4), (92, 14), (92, 92), (4, 92), (4, 6)], fill=lo)                 # Kontur mit abgeschrägter Ecke
    d.polygon([(8, 7), (80, 7), (89, 16), (89, 89), (7, 89), (7, 8)], fill=base)
    d.line([(8, 7), (80, 7)], fill=hi, width=2)
    d.line([(8, 7), (8, 88)], fill=hi, width=2)
    d.rectangle((26, 7, 70, 34), fill="#c7ced9")                                                # Metallschieber
    d.rectangle((26, 7, 70, 9), fill="#eef2f8")
    d.rectangle((52, 12, 63, 30), fill=lo)
    d.rectangle((54, 14, 61, 28), fill="#10142b")
    d.rectangle((16, 44, 80, 89), fill="#f2efe2")                                               # Etikett
    d.rectangle((16, 44, 80, 49), fill=hi)
    for y in (76, 82):
        d.line([(22, y), (74, y)], fill="#c4c9d6", width=1)
    d.rectangle((10, 80, 13, 85), fill="#10142b")                                               # Schreibschutz
    im.save("assets/art/floppy_%d.png" % n)
