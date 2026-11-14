"""Sektor 1: Sternenhafen – Heimatplanet (Horizont, Nachtseite mit Städten, Wolken, Atmosphäre im Sonnenaufgang),
Ringriese mit Ringschatten, kleine Hafenstation mit Andockarmen."""
import sys, os, math, random
sys.path.insert(0, os.path.dirname(__file__))
import bpy
from mathutils import Vector
from bl_common import *

sc = reset()
sc.cycles.samples = 256
sc.cycles.volume_bounces = 1
rng = random.Random(101)
SUN = Vector((0.55, -0.82, 0.12)).normalized()        # Sonne hinter dem Planeten, links knapp unter dem Horizont        # Laufrichtung des Sonnenlichts (Sonne links am Horizont)

def emis(name, col, k):
    return principled(name, "#000000", 0, 0.5, col, k)

# Heimatplanet
R = 1100.0
P0 = wpos(320, 236 + R, 0)
bpy.ops.mesh.primitive_uv_sphere_add(radius=R, segments=512, ring_count=256, location=P0)
pl = bpy.context.active_object
for p in pl.data.polygons: p.use_smooth = True
pl.rotation_euler = (math.radians(70), 0, 0)
m = bpy.data.materials.new("home"); m.use_nodes = True
nt, ln = nodes(m); b = nt["Principled BSDF"]
tc = nt.new("ShaderNodeTexCoord")
land = nt.new("ShaderNodeTexNoise"); land.inputs["Scale"].default_value = 0.004; land.inputs["Detail"].default_value = 14; land.inputs["Roughness"].default_value = 0.6
ln.new(tc.outputs["Object"], land.inputs["Vector"])
lc = nt.new("ShaderNodeValToRGB"); e = lc.color_ramp.elements
e[0].position = 0.5; e[0].color = hexc("#0c1a3a"); e[1].position = 0.52; e[1].color = hexc("#3a3a30")
x = lc.color_ramp.elements.new(0.65); x.color = hexc("#5a4a3a")
ln.new(land.outputs["Fac"], lc.inputs[0])
# Wolken
cl = nt.new("ShaderNodeTexNoise"); cl.inputs["Scale"].default_value = 0.01; cl.inputs["Detail"].default_value = 10; cl.inputs["Distortion"].default_value = 1.5
ln.new(tc.outputs["Object"], cl.inputs["Vector"])
cc = nt.new("ShaderNodeValToRGB"); cc.color_ramp.elements[0].position = 0.55; cc.color_ramp.elements[1].position = 0.7
ln.new(cl.outputs["Fac"], cc.inputs[0])
mx = nt.new("ShaderNodeMix"); mx.data_type = "RGBA"
ln.new(cc.outputs[0], mx.inputs["Factor"]); ln.new(lc.outputs[0], mx.inputs[6]); mx.inputs[7].default_value = hexc("#d8d8e8")
ln.new(mx.outputs[2], b.inputs["Base Color"])
b.inputs["Roughness"].default_value = 0.6
# Stadtlichter: nur an Land, in Clustern, auf der Nachtseite, unter Wolken gedämpft
vo = nt.new("ShaderNodeTexVoronoi"); vo.inputs["Scale"].default_value = 0.35; vo.feature = "F1"
ln.new(tc.outputs["Object"], vo.inputs["Vector"])
vr = nt.new("ShaderNodeValToRGB"); vr.color_ramp.elements[0].position = 0.0; vr.color_ramp.elements[0].color = (1, 1, 1, 1)
vr.color_ramp.elements[1].position = 0.18; vr.color_ramp.elements[1].color = (0, 0, 0, 1)
ln.new(vo.outputs["Distance"], vr.inputs[0])
big = nt.new("ShaderNodeTexNoise"); big.inputs["Scale"].default_value = 0.03; big.inputs["Detail"].default_value = 4
ln.new(tc.outputs["Object"], big.inputs["Vector"])
bg = nt.new("ShaderNodeValToRGB"); bg.color_ramp.elements[0].position = 0.45; bg.color_ramp.elements[1].position = 0.65
ln.new(big.outputs["Fac"], bg.inputs[0])
lm = nt.new("ShaderNodeMath"); lm.operation = "GREATER_THAN"; lm.inputs[1].default_value = 0.51; ln.new(land.outputs["Fac"], lm.inputs[0])
m1 = nt.new("ShaderNodeMath"); m1.operation = "MULTIPLY"; ln.new(vr.outputs[0], m1.inputs[0]); ln.new(bg.outputs[0], m1.inputs[1])
m2 = nt.new("ShaderNodeMath"); m2.operation = "MULTIPLY"; ln.new(m1.outputs[0], m2.inputs[0]); ln.new(lm.outputs[0], m2.inputs[1])
cinv = nt.new("ShaderNodeMath"); cinv.operation = "SUBTRACT"; cinv.inputs[0].default_value = 1.0; ln.new(cc.outputs[0], cinv.inputs[1])
m3 = nt.new("ShaderNodeMath"); m3.operation = "MULTIPLY"; ln.new(m2.outputs[0], m3.inputs[0]); ln.new(cinv.outputs[0], m3.inputs[1])
geo = nt.new("ShaderNodeNewGeometry")
dp = nt.new("ShaderNodeVectorMath"); dp.operation = "DOT_PRODUCT"; dp.inputs[1].default_value = tuple(-SUN)
ln.new(geo.outputs["Normal"], dp.inputs[0])
night = nt.new("ShaderNodeMapRange"); night.inputs["From Min"].default_value = 0.05; night.inputs["From Max"].default_value = -0.15
ln.new(dp.outputs["Value"], night.inputs["Value"])
m4 = nt.new("ShaderNodeMath"); m4.operation = "MULTIPLY"; ln.new(m3.outputs[0], m4.inputs[0]); ln.new(night.outputs["Result"], m4.inputs[1])
k = nt.new("ShaderNodeMath"); k.operation = "MULTIPLY"; k.inputs[1].default_value = 3.0; ln.new(m4.outputs[0], k.inputs[0])
b.inputs["Emission Color"].default_value = hexc("#ffb050"); ln.new(k.outputs[0], b.inputs["Emission Strength"])
pl.data.materials.append(m)
# Atmosphäre
bpy.ops.mesh.primitive_uv_sphere_add(radius=R + 9, segments=512, ring_count=256, location=P0)
at = bpy.context.active_object
for p in at.data.polygons: p.use_smooth = True
ma = bpy.data.materials.new("atmo"); ma.use_nodes = True
nt, ln = nodes(ma)
for n in list(nt):
    if n.type != "OUTPUT_MATERIAL": nt.remove(n)
out = [n for n in nt if n.type == "OUTPUT_MATERIAL"][0]
tc = nt.new("ShaderNodeTexCoord"); vl = nt.new("ShaderNodeVectorMath"); vl.operation = "LENGTH"; ln.new(tc.outputs["Object"], vl.inputs[0])
mp = nt.new("ShaderNodeMapRange"); mp.inputs["From Min"].default_value = R; mp.inputs["From Max"].default_value = R + 9
mp.inputs["To Min"].default_value = 1.0; mp.inputs["To Max"].default_value = 0.0; ln.new(vl.outputs["Value"], mp.inputs["Value"])
pw = nt.new("ShaderNodeMath"); pw.operation = "POWER"; pw.inputs[1].default_value = 2.5; ln.new(mp.outputs["Result"], pw.inputs[0])
dk = nt.new("ShaderNodeMath"); dk.operation = "MULTIPLY"; dk.inputs[1].default_value = 0.08; ln.new(pw.outputs[0], dk.inputs[0])
vs = nt.new("ShaderNodeVolumeScatter"); vs.inputs["Color"].default_value = (0.55, 0.7, 1.0, 1); vs.inputs["Anisotropy"].default_value = 0.6
ln.new(dk.outputs[0], vs.inputs["Density"]); ln.new(vs.outputs[0], out.inputs["Volume"])
at.data.materials.append(ma)

mark("home")
# Ringriese oben rechts
G0 = wpos(525, 78, 300)
bpy.ops.mesh.primitive_uv_sphere_add(radius=40, segments=128, ring_count=64, location=G0)
gp = bpy.context.active_object
for p in gp.data.polygons: p.use_smooth = True
mg = bpy.data.materials.new("giant"); mg.use_nodes = True
nt, ln = nodes(mg); b = nt["Principled BSDF"]
tc = nt.new("ShaderNodeTexCoord")
wv = nt.new("ShaderNodeTexWave"); wv.wave_type = "BANDS"; wv.bands_direction = "Z"; wv.inputs["Scale"].default_value = 0.06
wv.inputs["Distortion"].default_value = 3.2; wv.inputs["Detail"].default_value = 6; wv.inputs["Detail Scale"].default_value = 2.0
ln.new(tc.outputs["Object"], wv.inputs["Vector"])
gr = nt.new("ShaderNodeValToRGB"); el = gr.color_ramp.elements
el[0].position = 0.0; el[0].color = hexc("#6a4058"); el[1].position = 1.0; el[1].color = hexc("#f4d0b0")
for pos, col in ((0.3, "#c08870"), (0.55, "#e8b898"), (0.75, "#a87088")):
    q = gr.color_ramp.elements.new(pos); q.color = hexc(col)
ln.new(wv.outputs["Fac"], gr.inputs[0]); ln.new(gr.outputs[0], b.inputs["Base Color"])
b.inputs["Roughness"].default_value = 0.7
gp.data.materials.append(mg)
gp.rotation_euler = (math.radians(14), math.radians(-18), 0)
import bmesh
bm = bmesh.new(); Ri, Ro, seg = 52.0, 88.0, 256
for i in range(seg):
    a = i * 2 * math.pi / seg
    bm.verts.new((math.cos(a) * Ri, math.sin(a) * Ri, 0)); bm.verts.new((math.cos(a) * Ro, math.sin(a) * Ro, 0))
bm.verts.ensure_lookup_table()
for i in range(seg):
    j = (i + 1) % seg; bm.faces.new((bm.verts[2 * i], bm.verts[2 * i + 1], bm.verts[2 * j + 1], bm.verts[2 * j]))
me = bpy.data.meshes.new("ring"); bm.to_mesh(me); bm.free()
rg = link(bpy.data.objects.new("ring", me)); rg.location = G0
rg.rotation_euler = (math.radians(14), math.radians(-18), 0)
mr = bpy.data.materials.new("ringm"); mr.use_nodes = True
nt, ln = nodes(mr); b = nt["Principled BSDF"]
tc = nt.new("ShaderNodeTexCoord"); vl = nt.new("ShaderNodeVectorMath"); vl.operation = "LENGTH"; ln.new(tc.outputs["Object"], vl.inputs[0])
mp = nt.new("ShaderNodeMapRange"); mp.inputs["From Min"].default_value = Ri; mp.inputs["From Max"].default_value = Ro; ln.new(vl.outputs["Value"], mp.inputs["Value"])
nb = nt.new("ShaderNodeTexNoise"); nb.noise_dimensions = "1D"; nb.inputs["Scale"].default_value = 14; nb.inputs["Detail"].default_value = 6; ln.new(mp.outputs["Result"], nb.inputs["W"])
rc = nt.new("ShaderNodeValToRGB"); rc.color_ramp.elements[0].color = hexc("#806070"); rc.color_ramp.elements[1].color = hexc("#f0d8c0")
ln.new(nb.outputs["Fac"], rc.inputs[0]); ln.new(rc.outputs[0], b.inputs["Base Color"])
al = nt.new("ShaderNodeValToRGB"); ae = al.color_ramp.elements
ae[0].position = 0.35; ae[0].color = (0.1, 0.1, 0.1, 1); ae[1].position = 0.6; ae[1].color = (1, 1, 1, 1)
ln.new(nb.outputs["Fac"], al.inputs[0])
gap = nt.new("ShaderNodeValToRGB"); ge = gap.color_ramp.elements
ge[0].position = 0.0; ge[0].color = (0.3, 0.3, 0.3, 1); ge[1].position = 0.1; ge[1].color = (1, 1, 1, 1)
for pos, v in ((0.6, 1), (0.63, 0), (0.67, 0.9), (0.95, 0.6), (1.0, 0)):
    q = gap.color_ramp.elements.new(pos); q.color = (v, v, v, 1)
ln.new(mp.outputs["Result"], gap.inputs[0])
am = nt.new("ShaderNodeMath"); am.operation = "MULTIPLY"; ln.new(al.outputs[0], am.inputs[0]); ln.new(gap.outputs[0], am.inputs[1])
ln.new(am.outputs[0], b.inputs["Alpha"])
rg.data.materials.append(mr)

mark("giant")
# Hafenstation über dem Horizont: Mittelturm, Andockarme mit Lichtern, angedockte Fähren
H = bpy.data.objects.new("harbor", None); link(H)
hull = principled("hull", "#8a90a8", 0.7, 0.35); acc = principled("acc", "#c87840", 0.6, 0.4)
glass = emis("glass", "#ffd890", 4.0); red = emis("red", "#ff3030", 30.0); grn = emis("grn", "#40ff80", 30.0); wht = emis("wht", "#ffffff", 30.0)
def add_cyl(r, d, loc, rot=(0, 0, 0), mat=hull, v=24):
    bpy.ops.mesh.primitive_cylinder_add(vertices=v, radius=r, depth=d, location=loc, rotation=rot)
    o = bpy.context.active_object; o.data.materials.append(mat); o.parent = H; return o
def add_box(sx, sy, sz, loc, mat=hull):
    bpy.ops.mesh.primitive_cube_add(size=1, location=loc); o = bpy.context.active_object; o.scale = (sx, sy, sz); o.data.materials.append(mat); o.parent = H; return o
add_cyl(5, 34, (0, 0, 0)); add_cyl(8, 6, (0, 0, 6), mat=acc); add_cyl(6.5, 4, (0, 0, -10), mat=acc)
for z in (-6, 0, 6, 12):
    for a in range(12):
        aa = a * math.pi / 6
        if rng.random() < 0.7:
            add_box(0.6, 1.2, 0.8, (math.cos(aa) * 5.1, math.sin(aa) * 5.1, z), glass).rotation_euler = (0, 0, aa)
for a in range(4):
    aa = a * math.pi / 2 + 0.4
    d = Vector((math.cos(aa), math.sin(aa), 0))
    add_cyl(0.9, 26, d * 18 + Vector((0, 0, 2)), (math.pi / 2, 0, aa + math.pi / 2), hull, 10)
    add_box(5, 3.5, 2.6, d * 32 + Vector((0, 0, 2)), acc).rotation_euler = (0, 0, aa)
    bpy.ops.mesh.primitive_uv_sphere_add(radius=0.7, location=d * 35 + Vector((0, 0, 3.6))); l = bpy.context.active_object; l.parent = H
    l.data.materials.append([red, grn, wht, red][a])
    if a % 2 == 0:  # angedockte Fähre
        add_box(6, 3, 2, d * 38 + Vector((0, 0, -1)), principled("ferry", "#e8c040", 0.4, 0.4)).rotation_euler = (0, 0, aa)
add_cyl(0.4, 14, (0, 0, 24), mat=hull, v=8)
bpy.ops.mesh.primitive_uv_sphere_add(radius=0.9, location=(0, 0, 31)); l = bpy.context.active_object; l.parent = H; l.data.materials.append(red)
H.location = wpos(300, 64, 100)
H.rotation_euler = (math.radians(18), math.radians(10), math.radians(25))
H.scale = (0.9, 0.9, 0.9)

mark("harbor")
home = bpy.data.collections.new("home"); bpy.context.scene.collection.children.link(home)
for o in (pl, at): home.objects.link(o)
rest = bpy.data.collections.new("rest"); bpy.context.scene.collection.children.link(rest)
for o in bpy.context.scene.objects:
    if o.type in ("MESH", "EMPTY") and o not in (pl, at): rest.objects.link(o)
s1 = sun_dir("sun", tuple(SUN), 6.0, (1.0, 0.8, 0.6), angle=0.02)
s1.light_linking.receiver_collection = home
s2 = sun_dir("key", (0.85, 0.35, -0.4), 3.2, (1.0, 0.86, 0.72))
s2.light_linking.receiver_collection = rest
s3 = sun_dir("sky", (-0.2, 0.6, -0.7), 0.25, (0.5, 0.55, 1.0))
s3.light_linking.receiver_collection = rest
render_groups(args()[0])
