"""Erzeugt die Demo-Level der Einspieler (data/intros/*.json) und data/intros/index.json (Levelnummer -> Einspieler).
Aufruf (Projektwurzel): python3 tools/make_intro_demos.py [name ...]
Jedes Demo ist ein Level mit echter Physik plus ein Block "demo" (Fokus, Zoom, Dauer, Drehbuch, Titel; siehe src/game/intro_demo.gd)."""
import json, os, sys

T = 16


def blank(gate=False):
    rows = [["."] * 40 for _ in range(22)]
    for x in range(40):
        rows[0][x] = "#"
        rows[20][x] = "#"
        rows[21][x] = "#"
    for y in range(22):
        rows[y][0] = "#"
        rows[y][39] = "#"
    if gate:                                           # Tor oben (nur wo es zur Sache gehört, z. B. im Dunkelheits-Einspieler)
        for y in (1, 2):
            for x in range(16, 24):
                rows[y][x] = "#"
            for x in range(18, 22):
                rows[y][x] = "E"
    return rows


def put(rows, x0, y0, x1, y1, ch):
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            rows[y][x] = ch


def level(name, rows, title, demo, movers=None, zones=None, doors=None, jobs=None, dark=0.0):
    d = {"id": "DEMO-" + name, "sector": 1, "index": 1, "name": {"de": title[0], "en": title[1]},
         "map": ["".join(r) for r in rows], "jobs": jobs or []}
    if movers: d["movers"] = movers
    if zones: d["zones"] = zones
    if doors: d["doors"] = doors
    if dark: d["dark"] = dark
    demo = dict(demo)
    demo["title"] = {"de": title[0], "en": title[1]}
    d["demo"] = demo
    return d


DEMOS = {}


def demo(fn):
    DEMOS[fn.__name__] = fn
    return fn


# ------------------------------------------------------------------ Einspieler
@demo
def spikes():
    r = blank()
    put(r, 14, 13, 25, 19, "#")
    put(r, 14, 12, 25, 12, "^")
    return level("spikes", r, ("Dornen", "Spikes"), {
        "focus": [320, 190], "zoom": 1.6, "length": 9.0, "show_hull": True, "start": [320, 120],
        "script": [{"t": 0, "mode": "hover", "p": [320, 120]}, {"t": 2.0, "mode": "go", "p": [320, 200], "speed": 50},
                   {"t": 3.9, "mode": "go", "p": [320, 110], "speed": 70}]})


@demo
def magnet_pull():
    r = blank()
    return level("magnet_pull", r, ("Anziehende Magnete", "Attracting magnets"), {
        "focus": [320, 184], "zoom": 1.5, "length": 10.0, "start": [200, 184],
        "script": [{"t": 0, "mode": "hover", "p": [200, 184]}, {"t": 1.0, "mode": "go", "p": [262, 184], "speed": 40},
                   {"t": 2.6, "mode": "level", "y": 184}, {"t": 6.0, "mode": "go", "p": [200, 184], "speed": 70}]},
        zones=[{"kind": "magnet", "cx": 20.5, "cy": 11.5, "r": 5.0, "k": 110}])


@demo
def magnet_push():
    r = blank()
    return level("magnet_push", r, ("Abstoßende Magnete", "Repelling magnets"), {
        "focus": [320, 184], "zoom": 1.5, "length": 10.0, "start": [190, 184],
        "script": [{"t": 0, "mode": "hover", "p": [190, 184]}, {"t": 1.5, "mode": "go", "p": [328, 184], "speed": 60},
                   {"t": 5.0, "mode": "level", "y": 184}, {"t": 7.2, "mode": "hover", "p": [170, 184]}]},
        zones=[{"kind": "magnet", "cx": 20.5, "cy": 11.5, "r": 5.0, "k": -90}])


@demo
def magnet_pulse():
    r = blank()
    return level("magnet_pulse", r, ("Magnete im Takt", "Pulsing magnets"), {
        "focus": [320, 184], "zoom": 1.5, "length": 12.0, "start": [250, 184],
        "script": [{"t": 0, "mode": "level", "y": 184}]},
        zones=[{"kind": "magnet", "cx": 20.5, "cy": 11.5, "r": 5.0, "k": 100, "period": 6.0, "on": 3.0, "phase": 0.0}])


@demo
def heat():
    r = blank()
    return level("heat", r, ("Hitzezonen", "Heat zones"), {
        "focus": [320, 176], "zoom": 1.5, "length": 8.5, "show_hull": True, "start": [190, 176],
        "script": [{"t": 0, "mode": "hover", "p": [190, 176]}, {"t": 1.2, "mode": "go", "p": [450, 176], "speed": 45}]},
        zones=[{"kind": "heat", "x": 19, "y": 9, "w": 3, "h": 4}])


@demo
def heat_pulse():
    r = blank()
    return level("heat_pulse", r, ("Lavablasen im Takt", "Pulsing lava"), {
        "focus": [320, 176], "zoom": 1.5, "length": 10.0, "show_hull": True, "start": [190, 176],
        "script": [{"t": 0, "mode": "hover", "p": [190, 176]}, {"t": 4.0, "mode": "go", "p": [450, 176], "speed": 70}]},
        zones=[{"kind": "heat", "x": 19, "y": 9, "w": 3, "h": 4, "period": 7.0, "on": 3.5, "phase": 0.0}])


@demo
def wind():
    r = blank()
    return level("wind", r, ("Strömungen", "Currents"), {
        "focus": [320, 184], "zoom": 1.5, "length": 10.0, "start": [150, 184],
        "script": [{"t": 0, "mode": "hover", "p": [150, 184]}, {"t": 1.0, "mode": "level", "y": 184},
                   {"t": 4.0, "mode": "go", "p": [150, 184], "speed": 60}, {"t": 7.5, "mode": "level", "y": 184}]},
        zones=[{"kind": "wind", "x": 1, "y": 9, "w": 38, "h": 5, "ax": 30, "ay": 0}])


@demo
def wind_gust():
    r = blank()
    return level("wind_gust", r, ("Böen", "Gusts"), {
        "focus": [320, 184], "zoom": 1.5, "length": 10.5, "start": [170, 184],
        "script": [{"t": 0, "mode": "level", "y": 184}, {"t": 5.0, "mode": "go", "p": [170, 184], "speed": 60},
                   {"t": 7.4, "mode": "level", "y": 184}]},
        zones=[{"kind": "wind", "x": 1, "y": 9, "w": 38, "h": 5, "ax": 30, "ay": 0, "period": 6.0, "on": 2.5, "phase": 4.5}])


@demo
def gravity():
    r = blank()
    return level("gravity", r, ("Schwerkraftzonen", "Gravity zones"), {
        "focus": [320, 184], "zoom": 1.5, "length": 11.0, "start": [232, 190],
        "script": [{"t": 0, "mode": "hover", "p": [232, 190]}, {"t": 1.0, "mode": "coast"},
                   {"t": 2.4, "mode": "hover", "p": [232, 150]}, {"t": 3.8, "mode": "go", "p": [424, 150], "speed": 70},
                   {"t": 5.8, "mode": "coast"}, {"t": 7.4, "mode": "hover", "p": [424, 200]}]},
        zones=[{"kind": "gravity", "x": 13, "y": 7, "w": 4, "h": 7, "g": 0.5}, {"kind": "gravity", "x": 24, "y": 7, "w": 4, "h": 7, "g": 1.8}])


@demo
def doors():
    r = blank()
    put(r, 20, 3, 20, 8, "#")
    put(r, 20, 9, 20, 12, "a")
    put(r, 20, 13, 20, 19, "#")
    return level("doors", r, ("Schiebetore", "Sliding gates"), {
        "focus": [320, 184], "zoom": 1.5, "length": 9.5, "start": [200, 176],
        "script": [{"t": 0, "mode": "hover", "p": [200, 176]}, {"t": 3.1, "mode": "go", "p": [450, 176], "speed": 80}]},
        doors={"a": {"period": 6.0, "open": 3.0, "phase": 3.0}})


@demo
def beam():
    r = blank()
    return level("beam", r, ("Plasmastrahlen", "Plasma beams"), {
        "focus": [320, 184], "zoom": 1.5, "length": 9.5, "show_hull": True, "start": [200, 184],
        "script": [{"t": 0, "mode": "hover", "p": [200, 184]}, {"t": 5.8, "mode": "go", "p": [450, 184], "speed": 90}]},
        movers=[{"kind": "beam", "x": 20, "y": 5, "w": 1, "h": 11, "period": 8.0, "on": 3.0, "phase": 5.5, "warn": 2.0}])


@demo
def meteors():
    r = blank()
    return level("meteors", r, ("Meteoriten", "Meteors"), {
        "focus": [320, 184], "zoom": 1.5, "length": 9.0, "start": [250, 200],
        "script": [{"t": 0, "mode": "hover", "p": [250, 200]}, {"t": 4.7, "mode": "go", "p": [400, 200], "speed": 90}]},
        movers=[{"kind": "meteor", "x": 20, "y": 1, "w": 1, "h": 1, "dx": 0, "dy": 18, "fall": 1.6, "warn": 2.0, "period": 10.0, "phase": 7.5}])


@demo
def debris():
    r = blank()
    return level("debris", r, ("Trümmer", "Debris"), {
        "focus": [320, 184], "zoom": 1.5, "length": 12.0, "show_hull": True, "start": [200, 176],
        "script": [{"t": 0, "mode": "hover", "p": [200, 176]}, {"t": 4.0, "mode": "go", "p": [450, 176], "speed": 90}]},
        movers=[{"kind": "debris", "x": 20, "y": 8, "w": 1, "h": 2, "dx": 0, "dy": 5, "period": 6.0, "phase": 0.0, "shape": "line"}])


@demo
def slider():
    r = blank()
    return level("slider", r, ("Schieber", "Sliders"), {
        "focus": [320, 184], "zoom": 1.5, "length": 11.0, "show_hull": True, "start": [200, 232],
        "script": [{"t": 0, "mode": "hover", "p": [200, 232]}, {"t": 5.0, "mode": "go", "p": [450, 232], "speed": 90}]},
        movers=[{"kind": "slider", "x": 20, "y": 10, "w": 2, "h": 4, "dx": 0, "dy": 5, "period": 8.0, "phase": 0.0, "shape": "line"}])


@demo
def traffic():
    r = blank()
    return level("traffic", r, ("Verkehr", "Traffic"), {
        "focus": [320, 184], "zoom": 1.5, "length": 9.5, "start": [320, 120],
        "script": [{"t": 0, "mode": "hover", "p": [320, 120]}, {"t": 4.6, "mode": "go", "p": [320, 250], "speed": 90}]},
        movers=[{"kind": "vehicle", "path": [[39.5, 11.5], [0.5, 11.5]], "w": 2, "h": 1, "speed": 48.0, "phase": 3.0, "paint": 0},
                {"kind": "vehicle", "path": [[39.5, 11.5], [0.5, 11.5]], "w": 2, "h": 1, "speed": 48.0, "phase": 12.0, "paint": 2}])


@demo
def dark():
    r = blank(True)
    put(r, 2, 17, 9, 17, "1")
    put(r, 2, 18, 9, 19, "#")
    put(r, 30, 17, 37, 17, "2")
    put(r, 30, 18, 37, 19, "#")
    return level("dark", r, ("Dunkelheit", "Darkness"), {
        "focus": [320, 180], "zoom": 1.0, "length": 11.0, "start": [96, 240],
        "script": [{"t": 0, "mode": "hover", "p": [96, 240]}, {"t": 1.0, "mode": "go", "p": [300, 110], "speed": 70},
                   {"t": 4.5, "mode": "go", "p": [500, 240], "speed": 70}, {"t": 8.0, "mode": "go", "p": [300, 150], "speed": 70}]},
        dark=0.8)


@demo
def moving_pad():
    r = blank()
    put(r, 8, 17, 13, 17, "1")
    put(r, 8, 18, 13, 19, "#")
    put(r, 19, 15, 24, 15, "2")
    put(r, 19, 16, 24, 19, "#")
    return level("moving_pad", r, ("Fahrende Plattformen", "Moving pads"), {
        "focus": [320, 200], "zoom": 1.5, "length": 10.0, "start": [300, 170],
        "script": [{"t": 0, "mode": "hover", "p": [300, 170]}, {"t": 1.0, "mode": "land", "pad": "2", "gear": True}]},
        movers=[{"kind": "pad", "pad": "2", "x": 19, "y": 15, "w": 6, "dx": 3, "period": 12.0, "phase": 0.0}])


@demo
def hospital():
    r = blank()
    put(r, 6, 17, 12, 17, "1")
    put(r, 6, 18, 12, 19, "#")
    r[16][8] = "S"
    put(r, 27, 17, 33, 17, "H")
    put(r, 27, 18, 33, 19, "#")
    return level("hospital", r, ("Krankentransport", "Medical transport"), {
        "focus": [320, 210], "zoom": 1.4, "length": 12.0, "show_hull": True,
        "script": [{"t": 0, "mode": "bot"}]},
        jobs=[{"from": "1", "to": "H", "fare": 100, "par": 30, "passenger": "Mika", "gender": "f", "fragile": True}])


@demo
def vip():
    r = blank()
    put(r, 6, 17, 12, 17, "1")
    put(r, 6, 18, 12, 19, "#")
    r[16][8] = "S"
    put(r, 27, 15, 33, 15, "2")
    put(r, 27, 16, 33, 19, "#")
    return level("vip", r, ("VIP-Fahrgast", "VIP passenger"), {
        "focus": [320, 200], "zoom": 1.4, "length": 12.0,
        "script": [{"t": 0, "mode": "bot"}]},
        jobs=[{"from": "1", "to": "2", "fare": 100, "par": 30, "passenger": "Mika", "gender": "f", "kind": "vip"}])


@demo
def emergency():
    r = blank()
    put(r, 6, 17, 12, 17, "1")
    put(r, 6, 18, 12, 19, "#")
    r[16][8] = "S"
    put(r, 16, 8, 23, 19, "#")
    put(r, 27, 17, 33, 17, "2")
    put(r, 27, 18, 33, 19, "#")
    return level("emergency", r, ("Notfall", "Emergency"), {
        "focus": [320, 200], "zoom": 1.3, "length": 13.0,
        "script": [{"t": 0, "mode": "bot"}]},
        jobs=[{"from": "1", "to": "2", "fare": 100, "par": 14, "passenger": "Odo", "gender": "m", "kind": "emergency"}])


def main():
    names = sys.argv[1:] or list(DEMOS)
    os.makedirs("data/intros", exist_ok=True)
    for n in names:
        json.dump(DEMOS[n](), open("data/intros/%s.json" % n, "w"), indent=1, ensure_ascii=False)
        print("geschrieben:", n)
    idx = {"8": "spikes", "14": "doors", "19": "beam", "23": "debris", "25": "moving_pad", "27": "hospital", "29": "meteors", "33": "slider",
           "34": "magnet_pull", "35": "magnet_push", "37": "magnet_pulse", "45": "heat", "47": "heat_pulse", "56": "wind", "57": "gravity",
           "58": "wind_gust", "67": "traffic", "78": "dark"}      # „beam“ seit Runde 38 bei Level 19 (Neonlabyrinth)
    json.dump(idx, open("data/intros/index.json", "w"), indent=1)      # VIP und Notfall laufen nicht je Level, sondern beim ersten Fahrgast dieses Typs (Game._kind_clip_tick)


if __name__ == "__main__":
    main()
