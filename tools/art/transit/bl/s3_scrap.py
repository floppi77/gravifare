"""Sektor 3: Schrottgürtel – Container, Träger, Fachwerk, Rohre, Tanks, Schüsseln, Wrack eines Frachters."""
import sys, os, math, random
sys.path.insert(0, os.path.dirname(__file__))
import bpy, bmesh
from mathutils import Vector, Matrix, Euler
from bl_common import *

sc = reset()
sc.cycles.samples = 192
rng = random.Random(303)

def metal_mat(name, paint, rust_amt=0.45, stripes=False):
    m = bpy.data.materials.new(name); m.use_nodes = True
    nt, ln = nodes(m); b = nt["Principled BSDF"]
    tc = nt.new("ShaderNodeTexCoord")
    nz = nt.new("ShaderNodeTexNoise"); nz.inputs["Scale"].default_value = 0.6; nz.inputs["Detail"].default_value = 10; nz.inputs["Roughness"].default_value = 0.7
    ln.new(tc.outputs["Object"], nz.inputs["Vector"])
    rr = nt.new("ShaderNodeValToRGB"); rr.color_ramp.elements[0].position = 1 - rust_amt - 0.05; rr.color_ramp.elements[1].position = 1 - rust_amt + 0.08
    ln.new(nz.outputs["Fac"], rr.inputs[0])
    paintc = hexc(paint)
    if stripes:
        wv = nt.new("ShaderNodeTexWave"); wv.wave_profile = "SAW"; wv.inputs["Scale"].default_value = 0.35
        ln.new(tc.outputs["Object"], wv.inputs["Vector"])
        st = nt.new("ShaderNodeValToRGB"); st.color_ramp.interpolation = "CONSTANT"
        st.color_ramp.elements[0].color = hexc("#c89a20"); st.color_ramp.elements[1].position = 0.5; st.color_ramp.elements[1].color = hexc("#16140f")
        ln.new(wv.outputs["Fac"], st.inputs[0]); src = st.outputs[0]
    else:
        rgb = nt.new("ShaderNodeRGB"); rgb.outputs[0].default_value = paintc; src = rgb.outputs[0]
    rust = nt.new("ShaderNodeRGB"); rust.outputs[0].default_value = hexc("#5a2a14")
    mix = nt.new("ShaderNodeMix"); mix.data_type = "RGBA"
    ln.new(rr.outputs[0], mix.inputs["Factor"]); ln.new(src, mix.inputs[6]); ln.new(rust.outputs[0], mix.inputs[7])
    ln.new(mix.outputs[2], b.inputs["Base Color"])
    b.inputs["Metallic"].default_value = 0.55; b.inputs["Roughness"].default_value = 0.42
    bump = nt.new("ShaderNodeBump"); bump.inputs["Strength"].default_value = 0.25
    ln.new(nz.outputs["Fac"], bump.inputs["Height"]); ln.new(bump.outputs[0], b.inputs["Normal"])
    return m

MATS = [metal_mat("teal", "#3f7a76"), metal_mat("ochre", "#b88230"), metal_mat("grey", "#5c6266", 0.3),
        metal_mat("red", "#7a2c1e", 0.5), metal_mat("haz", "#000000", 0.35, True), metal_mat("steel", "#8a9298", 0.2)]
WIN = principled("win", "#103030", 0.0, 0.3, "#5af0d0", 6.0)

def box(name, sx, sy, sz, loc=(0, 0, 0), mat=None, parent=None):
    bpy.ops.mesh.primitive_cube_add(size=1, location=loc)
    o = bpy.context.active_object; o.name = name; o.scale = (sx, sy, sz)
    if mat: o.data.materials.append(mat)
    if parent: o.parent = parent
    return o

def cyl(name, r, d, loc=(0, 0, 0), rot=(0, 0, 0), mat=None, parent=None, verts=16):
    bpy.ops.mesh.primitive_cylinder_add(vertices=verts, radius=r, depth=d, location=loc, rotation=rot)
    o = bpy.context.active_object; o.name = name
    if mat: o.data.materials.append(mat)
    if parent: o.parent = parent
    return o

def empty(name):
    e = bpy.data.objects.new(name, None); link(e); return e

def container(s, mat):
    root = empty("cont")
    L, w = s * 2.4, s
    box("c", L, w, w, mat=mat, parent=root)
    n = max(2, int(L / (s * 0.6)))
    for i in range(n + 1):
        x = -L / 2 + i * L / n
        box("rib", s * 0.05, w * 1.04, w * 1.04, (x, 0, 0), mat, root)
    box("door", s * 0.06, w * 0.9, w * 0.9, (L / 2 + s * 0.02, 0, 0), MATS[2], root)
    return root

def ibeam(s, mat):
    root = empty("ibeam"); L = s * 4
    box("web", L, s * 0.08, s * 0.5, mat=mat, parent=root)
    box("f1", L, s * 0.4, s * 0.07, (0, 0, s * 0.25), mat, root)
    box("f2", L, s * 0.4, s * 0.07, (0, 0, -s * 0.25), mat, root)
    if rng.random() < 0.5:   # abgerissenes Ende
        box("f3", s * 0.6, s * 0.4, s * 0.07, (L / 2 + s * 0.2, 0, s * 0.35), mat, root).rotation_euler = (0, 0.5, 0)
    return root

def truss(s, mat):
    root = empty("truss"); L = s * 5; r = s * 0.05; h = s * 0.45
    pts = [(0, -h, -h), (0, h, -h), (0, 0, h)]
    for p in pts:
        cyl("chord", r, L, (0, p[1], p[2]), (0, math.pi / 2, 0), mat, root, 8)
    n = 6
    for i in range(n):
        x0 = -L / 2 + i * L / n; x1 = x0 + L / n
        for a, b2 in ((0, 1), (1, 2), (2, 0)):
            p0 = Vector((x0, pts[a][1], pts[a][2])); p1 = Vector((x1, pts[b2][1], pts[b2][2]))
            d = p1 - p0; c = (p0 + p1) / 2
            o = cyl("brace", r * 0.7, d.length, c, (0, 0, 0), mat, root, 6)
            o.rotation_mode = "QUATERNION"; o.rotation_quaternion = Vector((0, 0, 1)).rotation_difference(d)
    return root

def pipe(s, mat):
    root = empty("pipe"); L = s * 4
    cyl("p", s * 0.25, L, (0, 0, 0), (0, math.pi / 2, 0), mat, root, 18)
    for x in (-L / 2, -L / 6, L / 6, L / 2):
        cyl("fl", s * 0.34, s * 0.12, (x, 0, 0), (0, math.pi / 2, 0), MATS[5], root, 18)
    return root

def tank(s, mat):
    root = empty("tank")
    cyl("t", s * 0.8, s * 2.0, (0, 0, 0), (0, math.pi / 2, 0), mat, root, 24)
    for x in (-s, s):
        bpy.ops.mesh.primitive_uv_sphere_add(radius=s * 0.8, location=(x, 0, 0), segments=24, ring_count=12)
        o = bpy.context.active_object; o.data.materials.append(mat); o.parent = root; o.scale = (0.5, 1, 1)
    box("band", s * 0.15, s * 1.7, s * 1.7, (0, 0, 0), MATS[4], root)
    return root

def dish(s, mat):
    root = empty("dish")
    bpy.ops.mesh.primitive_uv_sphere_add(radius=s * 1.2, location=(0, 0, 0), segments=24, ring_count=12)
    o = bpy.context.active_object; o.parent = root; o.data.materials.append(MATS[5])
    bm = bmesh.new(); bm.from_mesh(o.data)
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if v.co.z > -s * 0.75], context="VERTS"); bm.to_mesh(o.data); bm.free()
    o.modifiers.new("so", "SOLIDIFY").thickness = s * 0.05
    cyl("arm", s * 0.05, s * 1.0, (0, 0, -s * 0.6), (0, 0, 0), mat, root, 6)
    return root

def plate(s, mat):
    root = empty("plate")
    bpy.ops.mesh.primitive_grid_add(x_subdivisions=8, y_subdivisions=8, size=s * 2.2)
    o = bpy.context.active_object; o.parent = root; o.data.materials.append(mat)
    bd = o.modifiers.new("bend", "SIMPLE_DEFORM"); bd.deform_method = "BEND"; bd.angle = rng.uniform(0.4, 1.4); bd.deform_axis = "Y"
    o.modifiers.new("so", "SOLIDIFY").thickness = s * 0.08
    for i in range(3):
        box("rib", s * 2.2, s * 0.08, s * 0.12, (0, -s * 0.8 + i * s * 0.8, s * 0.06), mat, o)
    return root

def rubble(s, mat):
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=2, radius=s)
    o = bpy.context.active_object; o.data.materials.append(MATS[2])
    tx = bpy.data.textures.new("rt", "VORONOI"); tx.noise_scale = s * 0.6
    d = o.modifiers.new("d", "DISPLACE"); d.texture = tx; d.strength = s * 0.5
    return o

KINDS = [(container, 3), (ibeam, 4), (truss, 2), (pipe, 3), (tank, 1), (dish, 1), (plate, 4), (rubble, 2)]
bag = [k for k, n in KINDS for _ in range(n)]

def belt_y(x): return 70 + 0.10 * (x - 320) + 14 * math.sin(x / 90)

placed = 0
for i in range(230):
    if i < 185:
        x = rng.uniform(-110, 750); y = belt_y(x) + rng.gauss(0, 24)
    else:
        x = rng.uniform(-110, 85) if rng.random() < 0.5 else rng.uniform(555, 750); y = rng.uniform(235, 370)
    if 132 < y < 222: continue
    if 230 < y and 90 < x < 550: continue
    big = rng.random() < 0.07
    s = rng.uniform(7.0, 13.0) if big else rng.uniform(2.0, 5.5)
    k = rng.choice(bag)
    mat = rng.choice(MATS[:5] if k is not rubble else MATS[2:3])
    o = k(s, mat)
    o.location = wpos(x, y, rng.uniform(-150, 150))
    o.rotation_euler = (rng.uniform(0, 6.3), rng.uniform(0, 6.3), rng.uniform(0, 6.3))
    placed += 1

# Großteile nah an den Ecken
SOLAR = principled("solar", "#0c1a3a", 0.6, 0.25)
def solar(s):
    root = empty("solar")
    for i in range(4):
        for j in range(2):
            p = box("cell", s * 0.95, s * 0.05, s * 0.6, (i * s - 1.5 * s, 0, j * s * 0.65 - s * 0.32), SOLAR, root)
    box("spar", s * 4.2, s * 0.12, s * 0.08, (0, 0, 0), MATS[5], root)
    return root
o = container(11, MATS[1]); o.location = wpos(42, 302, -60); o.rotation_euler = (0.3, 0.5, 0.4)
o = solar(8); o.location = wpos(602, 292, -40); o.rotation_euler = (1.2, 0.3, 0.7)
o = tank(8, MATS[0]); o.location = wpos(30, 40, -40); o.rotation_euler = (0.5, 0.2, 0.9)
o = truss(9, MATS[3]); o.location = wpos(300, 20, -80); o.rotation_euler = (0.2, 0.25, 0.15)

mark("scrap")
# Wrack oben rechts: aufgerissene Rumpfsektion eines Frachters
root = empty("wreck")
R = 30.0; Lw = 110.0
hull = metal_mat("hull", "#3a4a48", 0.35)
bpy.ops.mesh.primitive_cylinder_add(vertices=48, radius=R, depth=Lw, end_fill_type="NOTHING")
o = bpy.context.active_object; o.data.materials.append(hull); o.parent = root
bm = bmesh.new(); bm.from_mesh(o.data)
cut = [v for v in bm.verts if (1.7 < math.atan2(v.co.y, v.co.x) < 2.6 and v.co.z > 0) or (-0.6 < math.atan2(v.co.y, v.co.x) < -0.1 and v.co.z > 35)]
bmesh.ops.delete(bm, geom=cut, context="VERTS"); bm.to_mesh(o.data); bm.free()
o.modifiers.new("so", "SOLIDIFY").thickness = 2.0
for i in range(13):    # Spanten
    z = -Lw / 2 + i * Lw / 12
    bpy.ops.mesh.primitive_torus_add(major_radius=R - 1.5, minor_radius=1.4, major_segments=48, minor_segments=6, location=(0, 0, z))
    t = bpy.context.active_object; t.data.materials.append(MATS[5] if i % 3 else MATS[3]); t.parent = root
    if i > 8:
        t.scale = (1, 1, 1); t.rotation_euler = (rng.uniform(-0.2, 0.2), rng.uniform(-0.2, 0.2), 0)
for i in range(80):    # Fensterreihe
    a = -2.6 + i * 0.045; z = -Lw / 2 + 6 + (i % 2) * 3
    for zz in range(6):
        zq = -Lw / 2 + 8 + zz * 16
        if rng.random() < 0.55:
            box("w", 0.5, 2.2, 1.6, (math.cos(a) * (R + 0.9), math.sin(a) * (R + 0.9), zq), WIN, root).rotation_euler = (0, 0, a)
    if i > 14: break
root.location = wpos(590, 22, 160)
root.rotation_mode = "QUATERNION"
root.rotation_quaternion = Vector((0, 0, 1)).rotation_difference(Vector((0.85, 0.45, 0.32))) @ __import__("mathutils").Quaternion((0, 0, 1), 2.2)

mark("wreck")
# Licht: Kupferfarbenes Führungslicht von rechts oben, türkises Fülllicht von links unten
sun_dir("key", (-0.6, 0.45, -0.55), 5.0, (1.0, 0.62, 0.32))
sun_dir("fill", (0.7, 0.4, 0.5), 0.7, (0.3, 0.8, 0.8))
sun_dir("rim", (0.2, -0.9, -0.2), 2.2, (0.5, 0.9, 0.9))
print("placed", placed)
render_groups(args()[0])
