"""Gemeinsame Blender-Helfer für die Zwischenflug-Ebenen (Blender 5.x, Cycles). Aufruf je Szene:
  blender -b --factory-startup --python sN_name.py -- "<ordner>/sN_{}.png"   ({} = Ebenenname)
Orthografische Kamera: 1 Blender-Einheit = 1 Spiel-Einheit; Bild 3200×1080 = Einheiten x -213.33..853.33 (Reserve fürs Mitziehen), y 0..360.
Weltposition: X = ux - 320, Z = 180 - uy (Kamera blickt entlang -Y)."""
import bpy, math, sys, random
from mathutils import Vector, Matrix, Euler

W, H = 3200, 1080
FXP = 640                      # Pixel-Lage der Einheit x = 0
UW = W / 3.0

def args():
    a = sys.argv
    return a[a.index("--") + 1:] if "--" in a else []

def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    sc = bpy.context.scene
    sc.render.engine = "CYCLES"
    p = bpy.context.preferences.addons["cycles"].preferences
    sc.cycles.device = "CPU"
    for kind in ("OPTIX", "CUDA", "HIP", "METAL", "ONEAPI"):      # erste verfügbare GPU, sonst CPU
        try:
            p.compute_device_type = kind; p.get_devices()
        except Exception:
            continue
        if any(d.type == kind for d in p.devices):
            for d in p.devices: d.use = d.type == kind
            sc.cycles.device = "GPU"; break
    sc.cycles.samples = 128
    sc.cycles.use_denoising = True
    sc.render.resolution_x, sc.render.resolution_y = W, H
    sc.render.resolution_percentage = 100
    sc.render.film_transparent = True
    sc.render.image_settings.file_format = "PNG"
    sc.render.image_settings.color_mode = "RGBA"
    sc.render.image_settings.color_depth = "16"
    sc.view_settings.view_transform = "Standard"
    sc.view_settings.look = "None"
    sc.render.filter_size = 1.0
    w = bpy.data.worlds.new("w"); sc.world = w
    w.use_nodes = True
    w.node_tree.nodes["Background"].inputs[0].default_value = (0, 0, 0, 1)
    w.node_tree.nodes["Background"].inputs[1].default_value = 0.0
    cam = bpy.data.cameras.new("cam"); cam.type = "ORTHO"; cam.ortho_scale = UW
    cam.clip_start = 0.1; cam.clip_end = 5000
    co = bpy.data.objects.new("cam", cam); sc.collection.objects.link(co)
    co.location = (UW / 2 - FXP / 3.0 - 320.0, -2000, 0)
    co.rotation_euler = (math.radians(90), 0, 0)
    sc.camera = co
    return sc

def wpos(ux, uy, depth=0.0):
    return Vector((ux - 320.0, depth, 180.0 - uy))

def link(ob):
    bpy.context.scene.collection.objects.link(ob); return ob

def mesh_obj(name, verts, faces, smooth=False):
    me = bpy.data.meshes.new(name); me.from_pydata(verts, [], faces); me.update()
    for p in me.polygons: p.use_smooth = smooth
    return link(bpy.data.objects.new(name, me))

def sun(name, rot, strength, color=(1, 1, 1), angle=0.02):
    l = bpy.data.lights.new(name, "SUN"); l.energy = strength; l.color = color; l.angle = angle
    o = link(bpy.data.objects.new(name, l)); o.rotation_euler = rot; return o

def sun_dir(name, d, strength, color=(1, 1, 1), angle=0.02):
    """d = Laufrichtung des Lichts (Blender-Welt: x rechts, y weg von der Kamera, z oben)."""
    l = bpy.data.lights.new(name, "SUN"); l.energy = strength; l.color = color; l.angle = angle
    o = link(bpy.data.objects.new(name, l))
    o.rotation_euler = Vector(d).normalized().to_track_quat("-Z", "Y").to_euler(); return o

def area(name, loc, target, power, color=(1, 1, 1), size=50.0):
    l = bpy.data.lights.new(name, "AREA"); l.energy = power; l.color = color; l.size = size
    o = link(bpy.data.objects.new(name, l)); o.location = loc
    d = (Vector(target) - Vector(loc)); o.rotation_euler = d.to_track_quat("-Z", "Y").to_euler(); return o

def point(name, loc, power, color=(1, 1, 1), radius=1.0):
    l = bpy.data.lights.new(name, "POINT"); l.energy = power; l.color = color; l.shadow_soft_size = radius
    o = link(bpy.data.objects.new(name, l)); o.location = loc; return o

def hexc(h):
    h = h.lstrip("#"); c = [int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4)]
    return tuple(x ** 2.2 for x in c) + (1.0,)

def principled(name, color, metallic=0.0, rough=0.5, emit=None, emit_k=0.0, transmission=0.0, coat=0.0):
    m = bpy.data.materials.new(name); m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = hexc(color) if isinstance(color, str) else color
    b.inputs["Metallic"].default_value = metallic
    b.inputs["Roughness"].default_value = rough
    b.inputs["Transmission Weight"].default_value = transmission
    b.inputs["Coat Weight"].default_value = coat
    if emit is not None:
        b.inputs["Emission Color"].default_value = hexc(emit) if isinstance(emit, str) else emit
        b.inputs["Emission Strength"].default_value = emit_k
    return m

def nodes(m):
    return m.node_tree.nodes, m.node_tree.links

def render(path):
    sc = bpy.context.scene
    sc.render.filepath = path
    bpy.ops.render.render(write_still=True)

GROUPS = {}
_assigned = set()

def mark(name):
    """Alle seit dem letzten mark() erzeugten Objekte bilden die Tiefenebene name."""
    objs = {o.name for o in bpy.context.scene.objects if o.type not in ("LIGHT", "CAMERA")}
    new = objs - _assigned
    GROUPS[name] = new; _assigned.update(new)

def render_groups(pattern):
    """Jede Ebene einzeln rendern (andere ausgeblendet). pattern enthält {}."""
    sc = bpy.context.scene
    for g, names in GROUPS.items():
        for o in sc.objects:
            if o.type in ("LIGHT", "CAMERA"): continue
            o.hide_render = o.name not in names
        render(pattern.format(g))
