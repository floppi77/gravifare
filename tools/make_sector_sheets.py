"""Setzt die Levelbilder zu Sektor-Übersichten zusammen (docs/levels/sektor_<n>.jpg). Nummer und Name stehen in einer Leiste über dem Bild,
damit nichts vom Level verdeckt wird. Aufruf über tools/make_sector_sheets.sh."""
import glob, json, os, sys
from PIL import Image, ImageDraw, ImageFont

COLS, ROWS = 4, 3
TILE_W, TILE_H = 1280, 720
BAR = 100
GAP = 12
INK = (10, 12, 34)
GOLD = (255, 225, 74)
WHITE = (236, 240, 255)
FONT = glob.glob("assets/fonts/jersey10/*.ttf")[0]
TITLE = ImageFont.truetype(FONT, 150)
NAME = ImageFont.truetype(FONT, 64)
NUMBER = ImageFont.truetype(FONT, 130)


def label(sheet, x, y, no, name):
    """Levelnummer groß, Name daneben, goldene Linie zum Bild."""
    d = ImageDraw.Draw(sheet)
    d.text((x + 16, y - 26), str(no), font=NUMBER, fill=GOLD)
    d.text((x + 28 + d.textlength(str(no), font=NUMBER), y + 16), name, font=NAME, fill=WHITE)
    d.rectangle((x, y + BAR - 4, x + TILE_W, y + BAR), fill=GOLD)


def main(src):
    os.makedirs("docs/levels", exist_ok=True)
    de = json.load(open("data/i18n/de.json", encoding="utf8"))
    for s in range(1, 10):
        cell_h = BAR + TILE_H + GAP
        sheet = Image.new("RGB", (COLS * TILE_W + (COLS + 1) * GAP, ROWS * cell_h + GAP), INK)
        for i in range(11):
            lid = "s%d_%02d" % (s, i + 1)
            lv = json.load(open("data/levels/%s.json" % lid, encoding="utf8"))
            im = Image.open(os.path.join(src, lid + ".png")).convert("RGB").resize((TILE_W, TILE_H), Image.NEAREST)
            x, y = GAP + (i % COLS) * (TILE_W + GAP), GAP + (i // COLS) * cell_h
            label(sheet, x, y, (s - 1) * 11 + i + 1, lv["name"]["de"])
            sheet.paste(im, (x, y + BAR))
        d = ImageDraw.Draw(sheet)
        x, y = GAP + 3 * (TILE_W + GAP), GAP + 2 * cell_h
        d.text((x + 80, y + 170), "Sektor %d" % s, font=TITLE, fill=GOLD)
        d.text((x + 80, y + 340), de["SECTOR_%d" % s], font=TITLE, fill=WHITE)
        d.text((x + 80, y + 510), "Level %d–%d" % ((s - 1) * 11 + 1, s * 11), font=NAME, fill=WHITE)
        sheet.save("docs/levels/sektor_%d.jpg" % s, quality=92)
        print("sektor_%d.jpg" % s, sheet.size)


main(sys.argv[1])
