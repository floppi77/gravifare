"""Schreibt data/levels.sha256: Prüfsummen (SHA-256, Zeilenenden auf LF vereinheitlicht) aller mitgelieferten Level und des Tutorials.
Der Test `_test_originals_unchanged` vergleicht sie mit den Dateien: Eine Änderung an den Originalen fällt so sofort auf.
Nach einer gewollten Leveländerung (z. B. build_sector.py) einmal ausführen:  python3 tools/level_hashes.py
"""
import hashlib
import pathlib

ROOT = pathlib.Path(__file__).resolve().parent.parent
FILES = sorted((ROOT / "data" / "levels").glob("*.json")) + [ROOT / "data" / "tutorial" / "tutorial.json"]


def digest(path):
    text = path.read_text(encoding="utf-8").replace("\r\n", "\n")
    return hashlib.sha256(text.encode("utf-8")).hexdigest()


def main():
    lines = ["%s  %s" % (digest(p), p.relative_to(ROOT / "data").as_posix()) for p in FILES]
    (ROOT / "data" / "levels.sha256").write_text("\n".join(lines) + "\n", encoding="utf-8")
    print("%d Prüfsummen geschrieben" % len(lines))


if __name__ == "__main__":
    main()
