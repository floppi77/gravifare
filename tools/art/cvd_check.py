"""Prüft die Signalfarben (src/core/signal_colors.gd, hud_gauges.gd) für Farbsehschwäche.
Simulation nach Machado, Oliveira, Fernandes (2009), volle Stärke, in linearem RGB; Abstand ΔE76 in CIELAB.
Ausgabe: kleinster Abstand je Farbgruppe und Simulation – normale Tafel gegen Tafel der Option „Farbsehschwäche“.
Aufruf: python3 tools/art/cvd_check.py"""
import itertools
import numpy as np

MACHADO = {
    "deutan": np.array([[0.367322, 0.860646, -0.227968], [0.280085, 0.672501, 0.047413], [-0.011820, 0.042940, 0.968881]]),
    "protan": np.array([[0.152286, 1.052583, -0.204868], [0.114503, 0.786281, 0.099216], [-0.003882, -0.048116, 1.051998]]),
    "tritan": np.array([[1.255528, -0.076749, -0.178779], [-0.078411, 0.930809, 0.147602], [0.004733, 0.691367, 0.303900]]),
}

def hx(h):
    h = h.lstrip("#")
    return np.array([int(h[i:i + 2], 16) / 255 for i in (0, 2, 4)])

def lin(c):
    return np.where(c <= 0.04045, c / 12.92, ((c + 0.055) / 1.055) ** 2.4)

def srgb(c):
    c = np.clip(c, 0, 1)
    return np.where(c <= 0.0031308, c * 12.92, 1.055 * c ** (1 / 2.4) - 0.055)

def lab(c):
    m = np.array([[0.4124, 0.3576, 0.1805], [0.2126, 0.7152, 0.0722], [0.0193, 0.1192, 0.9505]])
    x = m @ lin(c) / np.array([0.95047, 1, 1.08883])
    f = np.where(x > 0.008856, np.cbrt(x), 7.787 * x + 16 / 116)
    return np.array([116 * f[1] - 16, 500 * (f[0] - f[1]), 200 * (f[1] - f[2])])

def sim(c, mode):
    return c if mode == "normal" else srgb(MACHADO[mode] @ lin(c))

def worst(cols, mode):
    cs = [hx(c) for c in cols]
    return min(np.linalg.norm(lab(sim(a, mode)) - lab(sim(b, mode))) for a, b in itertools.combinations(cs, 2))

GROUPS = {
    "Ampel/Preis/Lampen (gut, Achtung, schlecht)": (["#5dff9a", "#ffe14a", "#ff4d6d"], ["#4fb0ff", "#ffe14a", "#d83c64"]),
    "Tank (voll, halb, knapp, kritisch)": (["#8dff4a", "#ffe14a", "#ff9a1f", "#ff3b3b"], ["#4fb0ff", "#f4f4ff", "#ffc23a", "#d83c64"]),
    "Hülle (heil, angeschlagen, kritisch)": (["#4fc3ff", "#a98bff", "#ff4fc8"], ["#4fb0ff", "#ffe14a", "#d83c64"]),
}

if __name__ == "__main__":
    for name, (normal, safe) in GROUPS.items():
        print(name)
        for mode in ["normal", "deutan", "protan", "tritan"]:
            print(f"  {mode:7s}  normal ΔE {worst(normal, mode):5.1f}   Option ΔE {worst(safe, mode):5.1f}")
