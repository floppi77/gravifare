"""Sektor 7: Transitknoten – Ringstation (Wohnring mit Modulen, Speichen, Nabe mit Andockspindel, Solarflügel, Positionslichter)."""
import sys, os, math, random
sys.path.insert(0, os.path.dirname(__file__))
import bpy
from mathutils import Vector, Matrix, Euler, Quaternion
from bl_common import *

sc = reset()
sc.cycles.samples = 256
rng = random.Random(707)

def empty(name):
    e = bpy.data.objects.new(name, None); link(e); return e

def hull_mat(name, col, panel=True):
    m = bpy.data.materials.new(name); m.use_nodes = True
    nt, ln = nodes(m); b = nt["Principled BSDF"]
    tc = nt.new("ShaderNodeTexCoord")
    br = nt.new("ShaderNodeTexBrick"); br.inputs["Scale"].default_value = 0.35; br.inputs["Mortar Size"].default_value = 0.012
    br.inputs["Color1"].default_value = hexc(col); br.inputs["Color2"].default_value = tuple(c * 0.8 for c in hexc(col)[:3]) + (1,)
    br.inputs["Mortar"].default_value = tuple(c * 0.35 for c in hexc(col)[:3]) + (1,)
    ln.new(tc.outputs["Object"], br.inputs["Vector"])
    ln.new(br.outputs["Color"], b.inputs["Base Color"])
    b.inputs["Metallic"].default_value = 0.75; b.inputs["Roughness"].default_value = 0.32
    bump = nt.new("ShaderNodeBump"); bump.inputs["Strength"].default_value = 0.35; bump.inputs["Distance"].default_value = 0.3
    ln.new(br.outputs["Fac"], bump.inputs["Height"]); ln.new(bump.outputs[0], b.inputs["Normal"])
    return m

GOLD = hull_mat("gold", "#d8b070")
WHITE = hull_mat("white", "#e8dcc4")
DARK = principled("dark", "#3a3028", 0.6, 0.45)
SOLAR = principled("solar", "#1a1e3a", 0.5, 0.2)
GLASS = principled("glass", "#201810", 0.0, 0.2, "#ffd890", 3.5)
RED = principled("red", "#ff2020", 0.0, 0.5, "#ff3020", 40.0)
WLT = principled("wl", "#ffffff", 0.0, 0.5, "#fff0d0", 40.0)

root = empty("station")
R = 112.0; r = 9.0
# Wohnring aus Segmenten mit Fensterbändern
bpy.ops.mesh.primitive_torus_add(major_radius=R, minor_radius=r, major_segments=96, minor_segments=16)
ring = bpy.context.active_object; ring.data.materials.append(WHITE); ring.parent = root
for p in ring.data.polygons: p.use_smooth = True
N = 24
for i in range(N):
    a = i * 2 * math.pi / N
    # Ringklammer (Segmentgrenze)
    bpy.ops.mesh.primitive_torus_add(major_radius=r + 0.8, minor_radius=1.6, major_segments=24, minor_segments=6,
                                     location=(math.cos(a) * R, math.sin(a) * R, 0), rotation=(math.pi / 2, 0, a + math.pi / 2))
    t = bpy.context.active_object; t.data.materials.append(GOLD); t.parent = root
    # Fensterband außen
    for k in range(5):
        aa = a + (k + 0.8) * 2 * math.pi / N / 6
        if rng.random() < 0.85:
            bpy.ops.mesh.primitive_cube_add(size=1, location=(math.cos(aa) * (R + r * 0.93), math.sin(aa) * (R + r * 0.93), rng.choice((-2.5, 0, 2.5))))
            w = bpy.context.active_object; w.scale = (0.6, 3.0, 1.3); w.rotation_euler = (0, 0, aa); w.data.materials.append(GLASS); w.parent = root
    # Module auf dem Ring (oben)
    if i % 2 == 0:
        bpy.ops.mesh.primitive_cube_add(size=1, location=(math.cos(a + 0.12) * R, math.sin(a + 0.12) * R, r + 3))
        mo = bpy.context.active_object; mo.scale = (8, 14, 5); mo.rotation_euler = (0, 0, a + 0.12); mo.data.materials.append(GOLD); mo.parent = root
        bpy.ops.mesh.primitive_cylinder_add(vertices=12, radius=2.0, depth=10, location=(math.cos(a + 0.12) * R, math.sin(a + 0.12) * R, r + 9))
        an = bpy.context.active_object; an.data.materials.append(WHITE); an.parent = root
# Speichen
for i in range(6):
    a = i * math.pi / 3 + 0.26
    bpy.ops.mesh.primitive_cylinder_add(vertices=12, radius=2.6, depth=R - 18, location=(math.cos(a) * (R / 2 + 8), math.sin(a) * (R / 2 + 8), 0), rotation=(0, math.pi / 2, a))
    sp = bpy.context.active_object; sp.data.materials.append(WHITE); sp.parent = root
    for k in range(4):   # Aufzugskabinen/Rippen
        d = 24 + k * 20
        bpy.ops.mesh.primitive_cylinder_add(vertices=12, radius=3.6, depth=2.2, location=(math.cos(a) * d, math.sin(a) * d, 0), rotation=(0, math.pi / 2, a))
        rb = bpy.context.active_object; rb.data.materials.append(GOLD); rb.parent = root
# Nabe + Andockspindel
bpy.ops.mesh.primitive_cylinder_add(vertices=32, radius=16, depth=14); h = bpy.context.active_object; h.data.materials.append(GOLD); h.parent = root
bpy.ops.mesh.primitive_uv_sphere_add(radius=13, segments=32, ring_count=16, location=(0, 0, 7)); h2 = bpy.context.active_object; h2.data.materials.append(WHITE); h2.parent = root
for p in h2.data.polygons: p.use_smooth = True
bpy.ops.mesh.primitive_cylinder_add(vertices=16, radius=4.5, depth=70, location=(0, 0, 0)); sp = bpy.context.active_object; sp.data.materials.append(WHITE); sp.parent = root
for z in (-30, -20, 22, 32):
    bpy.ops.mesh.primitive_cylinder_add(vertices=16, radius=7.5, depth=3, location=(0, 0, z)); c = bpy.context.active_object; c.data.materials.append(GOLD); c.parent = root
# Solarflügel an der Spindel
for sgn in (-1, 1):
    for z in (-26, 27):
        for k in range(3):
            bpy.ops.mesh.primitive_cube_add(size=1, location=(sgn * (18 + k * 13), 0, z))
            pnl = bpy.context.active_object; pnl.scale = (12, 0.6, 9); pnl.data.materials.append(SOLAR); pnl.parent = root
        bpy.ops.mesh.primitive_cylinder_add(vertices=8, radius=0.8, depth=44, location=(sgn * 30, 0, z), rotation=(0, math.pi / 2, 0))
        bar = bpy.context.active_object; bar.data.materials.append(DARK); bar.parent = root
# Positionslichter
for i in range(12):
    a = i * math.pi / 6
    bpy.ops.mesh.primitive_uv_sphere_add(radius=1.0, location=(math.cos(a) * (R + r + 1), math.sin(a) * (R + r + 1), 0))
    l = bpy.context.active_object; l.data.materials.append(RED if i % 2 else WLT); l.parent = root
for z in (-36, 36):
    bpy.ops.mesh.primitive_uv_sphere_add(radius=1.2, location=(0, 0, z)); l = bpy.context.active_object; l.data.materials.append(RED); l.parent = root

root.location = wpos(430, 78, 0)
# Ringachse zur Kamera geneigt (Ellipse), leicht gedreht
root.rotation_euler = (math.radians(19), math.radians(-9), math.radians(25))

# kleine Fähren im Anflug (auf den Schneisen)
SHIP = hull_mat("ship", "#c8b8a0")
for (ux, uy, ang) in ((300, 40, -0.2), (250, 96, 0.1), (560, 112, 3.0), (610, 36, 2.8), (180, 22, -0.05)):
    bpy.ops.mesh.primitive_cube_add(size=1); s = bpy.context.active_object; s.scale = (5, 2.4, 1.6); s.data.materials.append(SHIP)
    s.location = wpos(ux, uy, -50); s.rotation_euler = (0, -ang, 0)
    bpy.ops.mesh.primitive_uv_sphere_add(radius=0.9); e = bpy.context.active_object; e.data.materials.append(principled("eng", "#ffffff", 0, 0.5, "#ffb050", 50.0))
    e.location = s.location + Vector((-math.cos(ang) * 5.6, -1, math.sin(ang) * 5.6))

mark("station")
sun_dir("key", (0.75, 0.45, -0.45), 4.0, (1.0, 0.82, 0.58))
sun_dir("fill", (-0.6, 0.5, 0.4), 0.8, (0.7, 0.55, 0.8))
sun_dir("rim", (-0.3, -0.85, -0.3), 1.5, (1.0, 0.75, 0.45))
render_groups(args()[0])
