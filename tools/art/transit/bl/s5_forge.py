"""Sektor 5: Sonnenschmiede – orbitale Schmiede vor dem Sonnenrand: Kollektorspiegel, Fachwerk-Rückgrat,
Schmelzmodule mit glühenden Schlitzen, Tiegel mit Schmelzstrahl, Kräne, glühende Barren im All."""
import sys, os, math, random
sys.path.insert(0, os.path.dirname(__file__))
import bpy, bmesh
from mathutils import Vector
from bl_common import *

sc = reset()
sc.cycles.samples = 256
rng = random.Random(505)
F = bpy.data.objects.new("forge", None); link(F)

dark = principled("dark", "#3a302c", 0.8, 0.45)
steel = principled("steel", "#6a625c", 0.9, 0.3)
mirror = principled("mirror", "#ffc890", 0.4, 0.3, "#ff8a30", 2.2)
hot = principled("hot", "#200800", 0.0, 0.5, "#ff7a20", 18.0)
white_hot = principled("whot", "#200800", 0.0, 0.5, "#ffd890", 30.0)
amber = principled("amber", "#000000", 0.0, 0.5, "#ffb040", 6.0)

def cyl(r, d, loc, rot=(0, 0, 0), mat=dark, v=24):
    bpy.ops.mesh.primitive_cylinder_add(vertices=v, radius=r, depth=d, location=loc, rotation=rot)
    o = bpy.context.active_object; o.data.materials.append(mat); o.parent = F; return o
def box(sx, sy, sz, loc, mat=dark, rot=(0, 0, 0)):
    bpy.ops.mesh.primitive_cube_add(size=1, location=loc, rotation=rot); o = bpy.context.active_object; o.scale = (sx, sy, sz); o.data.materials.append(mat); o.parent = F; return o
def strut(p0, p1, r=0.5, mat=steel):
    p0 = Vector(p0); p1 = Vector(p1); d = p1 - p0
    o = cyl(r, d.length, (p0 + p1) / 2, mat=mat, v=8)
    o.rotation_mode = "QUATERNION"; o.rotation_quaternion = Vector((0, 0, 1)).rotation_difference(d); return o

# Rückgrat: Dreiecks-Fachwerk entlang X (-70..70)
L = 150.0; h = 5.0
rails = [(0, -h, -h), (0, h, -h), (0, 0, h)]
for _, y, z in rails:
    cyl(0.9, L, (0, y, z), (0, math.pi / 2, 0), steel, 10)
n = 20
for i in range(n):
    x0 = -L / 2 + i * L / n; x1 = x0 + L / n
    for a, b in ((0, 1), (1, 2), (2, 0)):
        strut((x0, rails[a][1], rails[a][2]), (x1, rails[b][1], rails[b][2]), 0.45)
# Kollektorspiegel am sonnenseitigen Ende (-X): Hohlspiegel aus Segmenten
bpy.ops.mesh.primitive_uv_sphere_add(radius=46, segments=48, ring_count=24, location=(0, 0, 0))
dish = bpy.context.active_object
bm = bmesh.new(); bm.from_mesh(dish.data)
bmesh.ops.delete(bm, geom=[v for v in bm.verts if v.co.x > -36], context="VERTS"); bm.to_mesh(dish.data); bm.free()
dish.modifiers.new("so", "SOLIDIFY").thickness = 1.2
dish.data.materials.append(mirror); dish.parent = F
dish.location = (-L / 2 - 2 + 46, 0, 0)
for p in dish.data.polygons: p.use_smooth = False
# Speichen hinter dem Spiegel
for k in range(8):
    a = k * math.pi / 4
    strut((-L / 2 + 6, 0, 0), (-L / 2 - 4, math.cos(a) * 26, math.sin(a) * 26), 0.6, dark)
# Brennpunkt -> Schmelzstrahl in den Tiegel
strut((-L / 2 + 18, 0, 0), (-L / 2 + 40, 0, 0), 1.1, white_hot)
strut((-L / 2 + 18, 0, 0), (-L / 2 + 40, 0, 0), 2.2, amber)
# Tiegel
cyl(7, 10, (-L / 2 + 46, 0, 0), (0, math.pi / 2, 0), dark, 24)
cyl(5.5, 10.4, (-L / 2 + 46, 0, 0), (0, math.pi / 2, 0), hot, 24)
# Schmelzmodule mit glühenden Schlitzen
for i, x in enumerate((-12, 8, 28, 48)):
    r = 7.5 if i % 2 == 0 else 6.0
    cyl(r, 14, (x, 0, -h - r + 1), (0, math.pi / 2, 0), dark, 24)
    for k in range(6):
        a = -math.pi / 2 + (k - 2.5) * 0.35
        box(1.0, 10, 0.6, (x, math.cos(a) * (r + 0.05) * 0 + math.sin(a) * 0, 0), hot).location = (x + (k - 2.5) * 2.1, -r * 0.98, -h - r + 1)
    cyl(1.6, 9, (x, 0, -h - 2 * r - 3), (0, 0, 0), steel, 12)   # Abstich
    box(2.4, 2.4, 1.2, (x, 0, -h - 2 * r - 8), hot)            # glühender Barren am Abstich
# Kräne
for x in (-30, 40):
    strut((x, 0, h), (x + 8, 0, h + 22), 0.7)
    strut((x + 8, 0, h + 22), (x + 30, 0, h + 18), 0.6)
    strut((x + 30, 0, h + 18), (x + 30, 0, h + 6), 0.2, steel)
    box(4, 3, 2.5, (x + 30, 0, h + 4.5), hot)
# Kühlrippen/Radiatoren am Ende (+X), dunkelrot glimmend
for k in range(5):
    box(1.0, 26, 9, (L / 2 - 8 - k * 4, 0, h + 7), principled("rad", "#2a1810", 0.5, 0.5, "#ff3a10", 0.8 + k * 0.25))
# Tanks
for x in (-40, 60):
    bpy.ops.mesh.primitive_uv_sphere_add(radius=6, segments=24, ring_count=12, location=(x, 0, h + 7)); t = bpy.context.active_object; t.data.materials.append(steel); t.parent = F
# Positionslichter
for x in (-L / 2 + 8, 0, L / 2):
    bpy.ops.mesh.primitive_uv_sphere_add(radius=0.8, location=(x, 0, h + 1.5)); l = bpy.context.active_object; l.parent = F
    l.data.materials.append(principled("pl", "#000000", 0, 0.5, "#ff2020", 40.0))

F.location = wpos(225, 82, 100)
F.rotation_euler = (math.radians(12), math.radians(24), math.radians(-28))
F.scale = (0.95, 0.95, 0.95)

# glühende Barren und Schlacke im All
bar = principled("bar", "#200800", 0.0, 0.5, "#ff6a18", 5.0)
for i in range(12):
    ux = rng.uniform(150, 420); uy = rng.uniform(15, 125)
    if 110 < uy and ux > 300: continue
    bpy.ops.mesh.primitive_cube_add(size=1, location=wpos(ux, uy, rng.uniform(-50, 50)))
    o = bpy.context.active_object; s = rng.uniform(1.0, 2.6); o.scale = (s * 2, s, s * 0.7)
    o.rotation_euler = (rng.uniform(0, 6), rng.uniform(0, 6), rng.uniform(0, 6))
    o.data.materials.append(bar if rng.random() < 0.6 else dark)

mark("forge")
sun_dir("sun", (0.85, 0.15, -0.5), 7.0, (1.0, 0.55, 0.25), angle=0.15)
sun_dir("fill", (-0.5, 0.6, 0.6), 0.6, (0.7, 0.3, 0.2))
sun_dir("rim", (0.6, -0.7, -0.3), 3.0, (1.0, 0.6, 0.3))
render_groups(args()[0])
