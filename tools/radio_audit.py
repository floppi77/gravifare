"""Prüft, ob die Funksprüche (data/voice_lines.json, Stimme d0, r<Level>) zum Inhalt des Levels passen und ob die Sprachclips zum Text
passen (assets/audio/voice/manifest.json). Aufruf (Projektwurzel): python3 tools/radio_audit.py"""
import json, glob, re

vl = json.load(open("data/voice_lines.json"))["d0"]
man = json.load(open("assets/audio/voice/manifest.json"))["clips"]


def feats(d):
    f = set()
    maps = "".join(d["map"])
    if any(c in maps for c in "abcde"): f.add("tor")
    if "^" in maps: f.add("dornen")
    if "H" in maps or any(j.get("fragile") for j in d["jobs"]): f.add("patient")
    if "L" in maps: f.add("leben")
    for m in d.get("movers", []):
        f.add({"vehicle": "verkehr", "meteor": "meteor", "beam": "strahl", "slider": "schieber", "debris": "truemmer", "pad": "fahrpad"}.get(m["kind"], m["kind"]))
    for z in d.get("zones", []):
        f.add({"wind": "stroemung", "gravity": "schwerkraft", "magnet": "magnet", "heat": "hitze"}[z["kind"]])
    if d.get("dark"): f.add("dunkel")
    return f


CLAIMS = [("patient", r"Patient|Krankentransport|Krankenhaus"), ("leben", r"Lebensstation|Lebens-Station"), ("stroemung", r"Strömung|Böen|Gezeiten schieben"),
          ("schwerkraft", r"Schwerkraft"), ("magnet", r"Magnet"), ("hitze", r"Hitze|Lava"), ("strahl", r"Plasmastrahl|Strahl"), ("meteor", r"Meteor"),
          ("verkehr", r"Verkehr|Fahrzeug"), ("dunkel", r"Dunkel|dunkel|Finsternis|Lichtlos"), ("schieber", r"Schieber"), ("dornen", r"Dornen")]
bad = 0
for f in sorted(glob.glob("data/levels/*.json")):
    d = json.load(open(f))
    n = (d["sector"] - 1) * 11 + d["index"]
    k = "r%d" % n
    txt = vl["de"].get(k, "")
    have = feats(d)
    for ft, rx in CLAIMS:
        if re.search(rx, txt) and ft not in have:
            print("Level %d (%s): Text erwähnt %s, Level hat es nicht: %s" % (n, d["id"], ft, txt)); bad += 1
    for lang in ("de", "en"):
        m = man.get("%s/d0_%s" % (lang, k))
        if m is None or m["text"].strip() != vl[lang].get(k, "").strip():
            print("Level %d: Clip %s passt nicht zum Text" % (n, lang)); bad += 1
print("Auffälligkeiten:", bad)
