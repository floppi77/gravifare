"""Sektor 2: schwebende Felsbrocken mit leuchtenden Amethyst-/Neonkristallen (Druse)."""
import sys, os, math, random
sys.path.insert(0, os.path.dirname(__file__))
import bpy
from mathutils import Vector, Matrix, Euler, Quaternion
from bl_common import *

sc = reset()
sc.cycles.samples = 256
rng = random.Random(202)

def crystal_mesh(name, L, r, taper=0.85, tip=0.32, sides=6):
    v = []; f = []
    rot0 = rng.uniform(0, math.pi)
    for i in range(sides):
        a = rot0 + i * 2 * math.pi / sides
        rr = r * rng.uniform(0.85, 1.12)
        v.append((math.cos(a) * rr, math.sin(a) * rr, -L * 0.15))
    for i in range(sides):
        a = rot0 + i * 2 * math.pi / sides
        rr = r * taper * rng.uniform(0.9, 1.08)
        v.append((math.cos(a) * rr, math.sin(a) * rr, L * (1 - tip)))
    ax = rng.uniform(-0.12, 0.12) * r; ay = rng.uniform(-0.12, 0.12) * r
    v.append((ax, ay, L))
    for i in range(sides):
        j = (i + 1) % sides
        f.append((i, j, sides + j, sides + i))
        f.append((sides + i, sides + j, 2 * sides))
    f.append(tuple(reversed(range(sides))))
    o = mesh_obj(name, v, f)
    bv = o.modifiers.new("bv", "BEVEL"); bv.width = r * 0.12; bv.segments = 1; bv.limit_method = "ANGLE"
    return o

def crystal_mat(name, col, glow):
    m = bpy.data.materials.new(name); m.use_nodes = True
    nt, ln = nodes(m)
    b = nt["Principled BSDF"]
    b.inputs["Base Color"].default_value = hexc(col)
    b.inputs["Roughness"].default_value = 0.08
    b.inputs["Transmission Weight"].default_value = 0.35
    b.inputs["IOR"].default_value = 1.6
    b.inputs["Coat Weight"].default_value = 0.6
    b.inputs["Specular IOR Level"].default_value = 0.8
    b.inputs["Emission Color"].default_value = hexc(glow)
    # innen leuchtend: zur Spitze hin heller, Adern per Rauschen
    tc = nt.new("ShaderNodeTexCoord"); sep = nt.new("ShaderNodeSeparateXYZ")
    ln.new(tc.outputs["Generated"], sep.inputs[0])
    nz = nt.new("ShaderNodeTexNoise"); nz.inputs["Scale"].default_value = 6.0; nz.inputs["Detail"].default_value = 6
    ln.new(tc.outputs["Object"], nz.inputs["Vector"])
    mul = nt.new("ShaderNodeMath"); mul.operation = "MULTIPLY"
    ramp = nt.new("ShaderNodeValToRGB")
    ramp.color_ramp.elements[0].position = 0.0; ramp.color_ramp.elements[0].color = (0.25, 0.25, 0.25, 1)
    ramp.color_ramp.elements[1].position = 1.0; ramp.color_ramp.elements[1].color = (1.6, 1.6, 1.6, 1)
    ln.new(sep.outputs["Z"], ramp.inputs[0])
    ln.new(ramp.outputs[0], mul.inputs[0]); ln.new(nz.outputs["Fac"], mul.inputs[1])
    k = nt.new("ShaderNodeMath"); k.operation = "MULTIPLY"; k.inputs[1].default_value = 1.3
    ln.new(mul.outputs[0], k.inputs[0]); ln.new(k.outputs[0], b.inputs["Emission Strength"])
    return m

MATS = [crystal_mat("amethyst", "#9a40ff", "#b050ff"), crystal_mat("cyan", "#40d8ff", "#30c8ff"), crystal_mat("pink", "#ff40c0", "#ff3aa8")]

rock_mat = principled("rock", "#2a1c38", 0.0, 0.85)
nt, ln = nodes(rock_mat)
b = nt["Principled BSDF"]
nz = nt.new("ShaderNodeTexNoise"); nz.inputs["Scale"].default_value = 0.35; nz.inputs["Detail"].default_value = 8
cr = nt.new("ShaderNodeValToRGB")
cr.color_ramp.elements[0].color = hexc("#140c1e"); cr.color_ramp.elements[1].color = hexc("#4a3460")
ln.new(nz.outputs["Fac"], cr.inputs[0]); ln.new(cr.outputs[0], b.inputs["Base Color"])
bump = nt.new("ShaderNodeBump"); bump.inputs["Strength"].default_value = 0.6
nz2 = nt.new("ShaderNodeTexVoronoi"); nz2.inputs["Scale"].default_value = 0.6
ln.new(nz2.outputs["Distance"], bump.inputs["Height"]); ln.new(bump.outputs[0], b.inputs["Normal"])

def rock(name, loc, size, seed):
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=5, radius=size * 0.72, location=loc)
    o = bpy.context.active_object; o.name = name
    o.scale = (rng.uniform(1.0, 1.5), rng.uniform(0.8, 1.1), rng.uniform(0.7, 1.0))
    tex = bpy.data.textures.new(name + "t", "VORONOI"); tex.noise_scale = size * 0.55
    d = o.modifiers.new("d", "DISPLACE"); d.texture = tex; d.strength = size * 0.35
    tex2 = bpy.data.textures.new(name + "c", "CLOUDS"); tex2.noise_scale = size * 0.3; tex2.noise_depth = 4
    d2 = o.modifiers.new("d2", "DISPLACE"); d2.texture = tex2; d2.strength = size * 0.25
    o.data.materials.append(rock_mat)
    for p in o.data.polygons: p.use_smooth = False
    o.rotation_euler = (rng.uniform(0, 6.3), rng.uniform(0, 6.3), rng.uniform(0, 6.3))
    return o

def cluster(ux, uy, size, main_dir, palette, n=11, seed=0):
    n = int(n * 1.6)
    """Fels mit einem Fächer von Kristallen, Hauptrichtung main_dir (Bildwinkel, 0 = nach rechts, positiv = nach oben)."""
    c = wpos(ux, uy, rng.uniform(-40, 40))
    rock("rock%d" % seed, c, size, seed)
    base_dir = Vector((math.cos(main_dir), rng.uniform(-0.5, 0.2), math.sin(main_dir))).normalized()
    for i in range(n):
        big = i == 0
        d = (base_dir + Vector((rng.gauss(0, 0.45), rng.gauss(0, 0.5), rng.gauss(0, 0.45)))).normalized() if not big else base_dir
        L = size * (rng.uniform(2.5, 3.1) if big else rng.uniform(0.8, 2.0))
        r = L * rng.uniform(0.13, 0.19)
        o = crystal_mesh("cr", L, r)
        o.data.materials.append(MATS[palette if (big or rng.random() < 0.7) else rng.randrange(3)])
        o.location = c + d * size * 0.35 + Vector((rng.gauss(0, size * 0.12), 0, rng.gauss(0, size * 0.12)))
        o.rotation_mode = "QUATERNION"
        o.rotation_quaternion = Vector((0, 0, 1)).rotation_difference(d)

def shard(ux, uy, L, palette):
    o = crystal_mesh("sh", L, L * rng.uniform(0.12, 0.2), tip=0.3)
    # Doppelspitze für frei schwebende Splitter
    o2 = crystal_mesh("sh2", L * 0.6, L * 0.15, tip=0.4)
    for ob in (o, o2):
        ob.data.materials.append(MATS[palette])
    o.location = wpos(ux, uy, rng.uniform(-60, 60))
    o2.parent = o; o2.rotation_euler = (math.pi, 0, 0)
    o.rotation_euler = (rng.uniform(0, 6.3), rng.uniform(0, 6.3), rng.uniform(0, 6.3))

cluster(30, 35, 34, math.radians(-28), 0, 12, 1)
cluster(118, 18, 14, math.radians(-60), 2, 7, 2)
cluster(612, 30, 36, math.radians(208), 1, 13, 3)
cluster(660, 128, 16, math.radians(185), 0, 7, 4)
cluster(625, 340, 30, math.radians(150), 2, 10, 5)
cluster(18, 338, 26, math.radians(32), 1, 9, 6)
cluster(520, 345, 10, math.radians(110), 0, 5, 9)
# Ultrawide-Ränder
cluster(-75, 215, 24, math.radians(15), 2, 8, 7)
cluster(720, 236, 22, math.radians(165), 0, 8, 8)
for i in range(40):
    while True:
        x = rng.uniform(-100, 740); y = rng.uniform(0, 360)
        if not (125 < y < 228) and not (90 < x < 550 and y > 222): break
    shard(x, y, rng.uniform(5, 15), rng.randrange(3))

# Licht: kühles Führungslicht von links oben vorn, magenta/cyan Gegenlicht von hinten
mark("crystals")
sun_dir("key", (0.55, 0.55, -0.62), 1.6, (0.85, 0.8, 1.0))
sun_dir("rimL", (0.7, -0.6, -0.4), 2.2, (1.0, 0.25, 0.75))
sun_dir("rimR", (-0.7, -0.6, 0.2), 2.2, (0.25, 0.8, 1.0))
sun_dir("fill", (-0.3, 0.8, 0.5), 0.6, (0.5, 0.4, 0.9))
render_groups(args()[0])
