"""Sektor 9: Schwarzes Loch per Strahlverfolgung (Schwarzschild, M = 1).
Lichtwege: d²x/dλ² = -3 M h² x / r⁵ (h = |x × v|). Dünne Akkretionsscheibe in der Ebene z = 0, Kepler-Umlauf,
Doppler- und Gravitationsverschiebung. Ausgabe: RGBA-Ebene (Scheibe + Schatten) und Ablenkungskarte für den Hintergrund.
Aufruf: python3 blackhole.py out_dir  (rendert im 3200×1080-Raster nur die Box um das Loch; Ergebnis liest gen_transit.s9)"""
import sys, math
import numpy as np
from PIL import Image

OUT = sys.argv[1]
W, H, FX, U = 3200, 1080, 640, 3
CX, CY = 470.0, 100.0              # Bildmitte des Lochs (Einheiten)
UPM = 5.4                          # Spiel-Einheiten je M (Schattenradius ≈ 5.2 M ≈ 28 Einheiten)
X0, X1, Y0, Y1 = 285.0, 660.0, 18.0, 185.0
D = 70.0                           # Kameraabstand (M)
INC = math.radians(7.5)            # Blickhöhe über der Scheibenebene
ROLL = -0.17                       # Bilddrehung (rad)
R_IN, R_OUT = 6.0, 26.0

px0, px1 = int(FX + X0 * U), int(FX + X1 * U)
py0, py1 = int(Y0 * U), int(Y1 * U)
w, h = px1 - px0, py1 - py0
yy, xx = np.mgrid[0:h, 0:w].astype(np.float64)
ux = (xx + px0 + 0.5 - FX) / U; uy = (yy + py0 + 0.5) / U
sx = (ux - CX) / UPM; sy = -(uy - CY) / UPM            # Bildebene in M, y nach oben
c, s = math.cos(ROLL), math.sin(ROLL)
sx, sy = sx * c - sy * s, sx * s + sy * c

cam = np.array([0.0, -D * math.cos(INC), D * math.sin(INC)])
fwd = -cam / np.linalg.norm(cam)
right = np.array([1.0, 0.0, 0.0])
up = np.cross(right, fwd); up /= np.linalg.norm(up)
dirs = fwd[None, None, :] + (sx[..., None] * right + sy[..., None] * up) / D
dirs /= np.linalg.norm(dirs, axis=-1, keepdims=True)

N = w * h
pos = np.repeat(cam[None, :], N, 0)
vel = dirs.reshape(N, 3).copy()
col = np.zeros((N, 3)); acc = np.zeros(N)
esc_dir = np.zeros((N, 3)); state = np.zeros(N, np.int8)      # 0 läuft, 1 entkommen, 2 eingefangen
h2 = np.sum(np.cross(pos, vel) ** 2, axis=1)

rng = np.random.default_rng(9)
def noise2(a, b, seed):
    """glattes periodisches Rauschen über (Winkel, log r) aus Sinus-Summen"""
    r = np.random.default_rng(seed); out = np.zeros_like(a)
    for k in range(7):
        fa = r.integers(1, 9) * (1 + k); fb = r.uniform(2, 9) * (1 + k * 0.7); ph = r.uniform(0, 6.3)
        out += np.sin(fa * a + fb * b + ph) / (1 + k * 0.8)
    return out

def disk_emit(p, k):
    """p: Treffpunkte (n,3), k: Richtung zur Kamera (n,3). -> Farbe (n,3), Deckung (n,)"""
    r = np.linalg.norm(p[:, :2], axis=1); phi = np.arctan2(p[:, 1], p[:, 0])
    beta = np.sqrt(1.0 / np.maximum(r - 2.0, 0.5)); beta = np.minimum(beta, 0.7)
    vdir = np.stack([-np.sin(phi), np.cos(phi), np.zeros_like(phi)], 1)
    cos_t = np.sum(vdir * k, 1)
    gamma = 1 / np.sqrt(1 - beta ** 2)
    g = np.sqrt(np.maximum(1 - 3.0 / r, 0.05)) / (gamma * (1 - beta * cos_t))
    prof = (r / R_IN) ** -2.2 * np.clip(1 - np.sqrt(R_IN / r), 0, 1) ** 0.6 * 6.0
    lr = np.log(r)
    turb = noise2(phi - 2.2 * lr * 3, lr * 6, 3) * 0.16 + noise2(phi * 2 - lr * 9, lr * 14, 5) * 0.08
    lanes = 0.8 + 0.2 * np.sin(lr * 34 + noise2(phi, lr * 3, 7) * 1.5)
    I = prof * lanes * (1 + turb) * g ** 3.2
    T = np.clip(0.55 + 0.45 * (r / R_IN) ** -0.75 * g, 0, 2)          # "Farbtemperatur"
    edge = np.clip((R_OUT - r) / 6.0, 0, 1) * np.clip((r - R_IN) / 0.6, 0, 1)
    # Farbrampe: tiefrot -> orange -> gold -> weiß
    stops = np.array([[0.30, 60, 8, 18], [0.55, 170, 40, 10], [0.80, 255, 120, 30], [1.05, 255, 200, 110], [1.4, 255, 245, 225]])
    rgb = np.stack([np.interp(T, stops[:, 0], stops[:, i]) for i in (1, 2, 3)], 1) / 255.0
    alpha = np.clip(edge * (0.55 + 0.45 * np.clip(I, 0, 1)), 0, 1)
    return rgb * I[:, None] * edge[:, None], alpha

act = np.arange(N)
for step in range(3000):
    if act.size == 0: break
    p = pos[act]; v = vel[act]; hh = h2[act]
    r = np.linalg.norm(p, axis=1)
    dt = np.clip(0.035 * r, 0.02, 3.0)
    def a(x):
        rr = np.linalg.norm(x, axis=1)
        return -3.0 * hh[:, None] * x / rr[:, None] ** 5
    # RK4
    k1v = a(p); k1x = v
    k2v = a(p + 0.5 * dt[:, None] * k1x); k2x = v + 0.5 * dt[:, None] * k1v
    k3v = a(p + 0.5 * dt[:, None] * k2x); k3x = v + 0.5 * dt[:, None] * k2v
    k4v = a(p + dt[:, None] * k3x); k4x = v + dt[:, None] * k3v
    pn = p + dt[:, None] / 6 * (k1x + 2 * k2x + 2 * k3x + k4x)
    vn = v + dt[:, None] / 6 * (k1v + 2 * k2v + 2 * k3v + k4v)
    # Durchgang durch die Scheibenebene
    cross = (p[:, 2] * pn[:, 2] < 0)
    if cross.any():
        t = p[cross, 2] / (p[cross, 2] - pn[cross, 2])
        hit = p[cross] + (pn[cross] - p[cross]) * t[:, None]
        rh = np.linalg.norm(hit[:, :2], axis=1)
        ok = (rh > R_IN * 0.9) & (rh < R_OUT)
        if ok.any():
            idx = act[cross][ok]
            cc, al = disk_emit(hit[ok], -vn[cross][ok] / np.linalg.norm(vn[cross][ok], axis=1, keepdims=True))
            rem = 1 - acc[idx]
            col[idx] += rem[:, None] * cc * al[:, None]
            acc[idx] += rem * al
    pos[act] = pn; vel[act] = vn
    rn = np.linalg.norm(pn, axis=1)
    cap = rn < 2.02
    esc = (rn > D * 1.3) & (np.sum(pn * vn, 1) > 0)
    full = acc[act] > 0.995
    state[act[cap]] = 2
    state[act[esc]] = 1
    esc_dir[act[esc]] = vn[esc]
    done = cap | esc | full
    state[act[full & ~cap & ~esc]] = 3
    act = act[~done]
print("steps", step, "left", act.size)

# Ebene schreiben: Farbe (vormultipliziert) + Deckung; Schatten schwarz und deckend
capm = state == 2
acc[capm] = 1.0
rgb = np.clip(col, 0, None)
# sanfter Tonwert (Glanzlichter nicht hart abschneiden)
rgb = 1 - np.exp(-rgb * 3.4)
outa = np.clip(acc, 0, 1)
straight = np.where(outa[:, None] > 1e-4, rgb / np.maximum(outa[:, None], 1e-4), 0)
lay = np.zeros((H, W, 4), np.float32)
lay[py0:py1, px0:px1, :3] = np.clip(straight, 0, 1).reshape(h, w, 3)
lay[py0:py1, px0:px1, 3] = outa.reshape(h, w)
np.save(OUT + "/bh_layer.npy", lay)
# Ablenkung: wohin blickt ein entkommener Strahl auf dem Bildschirm (für die Hintergrund-Linsung)
ed = esc_dir.reshape(h, w, 3)
fs = np.sum(ed * fwd, -1); fs = np.where(fs > 1e-3, fs, 1e-3)
ex = np.sum(ed * right, -1) / fs * D; ey = np.sum(ed * up, -1) / fs * D
ex, ey = ex * c + ey * s, -ex * s + ey * c              # Bilddrehung zurück
mapx = CX + ex * UPM; mapy = CY - ey * UPM
esc_m = (state == 1).reshape(h, w)
np.save(OUT + "/bh_map.npy", np.stack([mapx, mapy, esc_m.astype(np.float64)], 0))
np.save(OUT + "/bh_box.npy", np.array([px0, py0, px1, py1]))
Image.fromarray((np.clip(lay[py0:py1, px0:px1, :3] * lay[py0:py1, px0:px1, 3:4], 0, 1) * 255).astype(np.uint8)).save(OUT + "/bh_preview.png")
