"""Mischform (Runde 82): das 2D-Taxi als Bild auf seinem Höhenrelief (hybrid_prep.py), gerendert mit Licht in mehreren Drehstufen.
Die Vorderseite trägt das gezeichnete Taxi (Form, Gesicht, Band, Kontur unverändert); Blender ergänzt Rundung im Licht, Glanz und die
Verschiebung der Teile beim Drehen (Kuppel vorn, Kapseln hinten).
Aufruf: blender -b -P tools/art/taxi3d/build_hybrid.py -- <ordner mit taxi2d_<lack>.png/height.npy> <ausgabe> [px_je_einheit=60] [gieren]
Ausgabe: <ausgabe>/<lack>/yaw_<grad>.png (mit Licht) und flat_<grad>.png (ohne Licht) für jede Lackierung."""
import json, math, os, sys
import bpy, bmesh
import numpy as np

argv = sys.argv[sys.argv.index("--") + 1:]
SRC, OUT = argv[0], argv[1]
PPU = int(argv[2]) if len(argv) > 2 else 60
YAWS = [float(v) for v in (argv[3].split(",") if len(argv) > 3 else ["-24", "-16", "-8", "0", "8", "16", "24"])]
os.makedirs(OUT, exist_ok=True)
info = json.load(open(os.path.join(SRC, "info.json")))
W, H, n = info["w"], info["h"], info["n"]
hgt = np.load(os.path.join(SRC, "height.npy"))
SKINS = info.get("skins", ["std"])
alpha = np.array(bpy.data.images.load(os.path.join(SRC, "taxi2d_std.png")).pixels[:]).reshape(int(H * n), int(W * n), 4)[::-1, :, 3]

bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
imgs = {}
for sk in SKINS:
    imgs[sk] = bpy.data.images.load(os.path.join(SRC, "taxi2d_%s.png" % sk))
    imgs[sk].alpha_mode = "STRAIGHT"
img = imgs["std"]

rows, cols = hgt.shape
# Höhe an den Pixelecken: Mittel der (bis zu vier) deckenden Nachbarpixel, damit Felder lückenlos aneinanderstoßen
pad = np.pad(hgt, 1, mode="edge")
on = np.pad(alpha > 0.5, 1)
corner = np.zeros((rows + 1, cols + 1))
cnt = np.zeros((rows + 1, cols + 1))
for dy in (0, 1):
    for dx in (0, 1):
        sub = pad[dy:dy + rows + 1, dx:dx + cols + 1]
        m = on[dy:dy + rows + 1, dx:dx + cols + 1]
        corner += np.where(m, sub, 0.0)
        cnt += m
corner = np.where(cnt > 0, corner / np.maximum(cnt, 1), 0.0)

def build(name, sign, tint):
    """Ein Feld je deckendem Pixel der Vorlage (Ecken auf den Pixelgrenzen, Farbe = dieses Pixel): geradeaus gesehen bildpunktgenau das 2D-Taxi."""
    me = bpy.data.meshes.new(name)
    bm = bmesh.new()
    uvl = bm.loops.layers.uv.new()
    verts = {}
    def v(i, j):
        if (i, j) not in verts:
            verts[(i, j)] = bm.verts.new((i / n - W / 2.0, -sign * float(corner[j, i]), H / 2.0 - j / n))
        return verts[(i, j)]
    flip = alpha[::-1, :] if False else alpha
    for y in range(rows):
        for x in range(cols):
            if alpha[rows - 1 - y, x] <= 0.5:
                continue
            f = bm.faces.new([v(x, y), v(x + 1, y), v(x + 1, y + 1), v(x, y + 1)])
            uv = ((x + 0.5) / cols, 1.0 - (y + 0.5) / rows)
            for lp in f.loops:
                lp[uvl].uv = uv
    bm.to_mesh(me)
    bm.free()
    for poly in me.polygons:
        poly.use_smooth = True
    o = bpy.data.objects.new(name, me)
    scene.collection.objects.link(o)
    m = bpy.data.materials.new(name + "Mat")
    m.use_nodes = True
    nt = m.node_tree
    b = nt.nodes["Principled BSDF"]
    tex = nt.nodes.new("ShaderNodeTexImage")
    tex.image = img
    tex.interpolation = "Closest"
    nt.links.new(tex.outputs["Color"], b.inputs["Base Color"])
    b.inputs["Roughness"].default_value = 0.38
    b.inputs["Specular IOR Level"].default_value = 0.55
    # gezeichnete Farben sollen tragen: ein Teil der Farbe leuchtet selbst (Licht formt nur nach)
    nt.links.new(tex.outputs["Color"], b.inputs["Emission Color"])
    b.inputs["Emission Strength"].default_value = 0.42
    o.data.materials.append(m)
    return o

root = bpy.data.objects.new("Taxi", None); scene.collection.objects.link(root)
for o in (build("Vorn", 1, None),):              # nur die Vorderseite: bei höchstens ±12° bleibt die Rückseite verdeckt (eine gespiegelte Rückseite flimmerte am Rand)
    o.parent = root

def sun(name, rot, energy, color=(1, 1, 1)):
    l = bpy.data.lights.new(name, "SUN"); l.energy = energy; l.color = color; l.angle = math.radians(10)
    o = bpy.data.objects.new(name, l); o.rotation_euler = rot; scene.collection.objects.link(o)
sun("Hauptlicht", (math.radians(55), math.radians(-25), math.radians(-20)), 2.6, (1.0, 0.97, 0.9))
sun("Kante", (math.radians(-125), 0, math.radians(18)), 1.6, (0.8, 0.88, 1.0))
w = bpy.data.worlds.new("Welt"); scene.world = w; w.use_nodes = True
w.node_tree.nodes["Background"].inputs[0].default_value = (0.5, 0.52, 0.65, 1); w.node_tree.nodes["Background"].inputs[1].default_value = 0.35

cam_d = bpy.data.cameras.new("Kamera"); cam_d.type = "ORTHO"; cam_d.ortho_scale = W
cam = bpy.data.objects.new("Kamera", cam_d); scene.collection.objects.link(cam); scene.camera = cam
cam.location = (0, -60, 0); cam.rotation_euler = (math.radians(90), 0, 0)
r = scene.render
r.resolution_x = int(W * PPU); r.resolution_y = int(H * PPU); r.film_transparent = True
r.engine = "CYCLES"; scene.cycles.samples = 48; scene.cycles.use_denoising = True
try:
    prefs = bpy.context.preferences.addons["cycles"].preferences
    prefs.compute_device_type = "OPTIX"; prefs.get_devices()
    for d in prefs.devices:
        d.use = True
    scene.cycles.device = "GPU"
except Exception as e:
    print("GPU nicht verfügbar:", e)
scene.view_settings.view_transform = "Standard"
r.image_settings.file_format = "PNG"; r.image_settings.color_mode = "RGBA"
# Zweiter Durchgang ohne Licht: nur die gezeichneten Farben (für Kontur und dunkle Kleinteile, die das Licht nicht aufhellen soll)
flat = bpy.data.materials.new("Flach")
flat.use_nodes = True
fnt = flat.node_tree
for nd in list(fnt.nodes):
    if nd.type != "OUTPUT_MATERIAL":
        fnt.nodes.remove(nd)
ftex = fnt.nodes.new("ShaderNodeTexImage"); ftex.image = img; ftex.interpolation = "Closest"
em = fnt.nodes.new("ShaderNodeEmission")
fnt.links.new(ftex.outputs["Color"], em.inputs["Color"])
fnt.links.new(em.outputs[0], fnt.nodes["Material Output"].inputs["Surface"])
front = [o for o in scene.objects if o.type == "MESH"]
lit_mats = [o.data.materials[0] for o in front]
texnodes = [n_ for m_ in lit_mats + [flat] for n_ in m_.node_tree.nodes if n_.type == "TEX_IMAGE"]
for sk in SKINS:
  for tn in texnodes:
    tn.image = imgs[sk]
  os.makedirs(os.path.join(OUT, sk), exist_ok=True)
  for yaw in YAWS:
    root.rotation_euler = (0, 0, math.radians(yaw))
    for o, m in zip(front, lit_mats):
        o.data.materials[0] = m
    scene.cycles.samples = 48
    r.filepath = os.path.join(OUT, sk, "yaw_%+03d.png" % int(yaw))
    bpy.ops.render.render(write_still=True)
    for o in front:
        o.data.materials[0] = flat
    scene.cycles.samples = 4
    r.filepath = os.path.join(OUT, sk, "flat_%+03d.png" % int(yaw))
    bpy.ops.render.render(write_still=True)
    print("gerendert", sk, yaw)
