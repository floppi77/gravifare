"""Sektor 6: Gezeitenorbit – Ozeanplanet (Meer mit Sonnenglitzern, Inseln, Wolkenhülle, Atmosphäre), Kratermond,
Gezeitenstrom aus Wasser-/Eisbrocken zwischen beiden."""
import sys, os, math, random
sys.path.insert(0, os.path.dirname(__file__))
import bpy
from mathutils import Vector
from bl_common import *

sc = reset()
sc.cycles.samples = 256
sc.cycles.volume_bounces = 1
rng = random.Random(606)
SUN = Vector((1.0, 0.05, -0.32)).normalized()
R = 120.0
P0 = wpos(585, 30, 0)

bpy.ops.mesh.primitive_uv_sphere_add(radius=R, segments=256, ring_count=128, location=P0)
pl = bpy.context.active_object
for p in pl.data.polygons: p.use_smooth = True
m = bpy.data.materials.new("ocean"); m.use_nodes = True
nt, ln = nodes(m); b = nt["Principled BSDF"]
tc = nt.new("ShaderNodeTexCoord")
land = nt.new("ShaderNodeTexNoise"); land.inputs["Scale"].default_value = 0.025; land.inputs["Detail"].default_value = 12
ln.new(tc.outputs["Object"], land.inputs["Vector"])
lc = nt.new("ShaderNodeValToRGB"); e = lc.color_ramp.elements
e[0].position = 0.40; e[0].color = hexc("#031a48"); e[1].position = 0.63; e[1].color = hexc("#0a4a9a")
x = lc.color_ramp.elements.new(0.66); x.color = hexc("#3ad0d0")      # Flachwasser/Riffe
x = lc.color_ramp.elements.new(0.68); x.color = hexc("#c8b878")      # Inseln
x = lc.color_ramp.elements.new(0.72); x.color = hexc("#3a8a3a")
ln.new(land.outputs["Fac"], lc.inputs[0]); ln.new(lc.outputs[0], b.inputs["Base Color"])
isl = nt.new("ShaderNodeMath"); isl.operation = "GREATER_THAN"; isl.inputs[1].default_value = 0.665; ln.new(land.outputs["Fac"], isl.inputs[0])
rough = nt.new("ShaderNodeMapRange"); rough.inputs["To Min"].default_value = 0.08; rough.inputs["To Max"].default_value = 0.8
ln.new(isl.outputs[0], rough.inputs["Value"]); ln.new(rough.outputs["Result"], b.inputs["Roughness"])
b.inputs["Specular IOR Level"].default_value = 0.8
pl.data.materials.append(m)
pl.rotation_euler = (0.3, 0.6, 0.2)
# Wolkenhülle
bpy.ops.mesh.primitive_uv_sphere_add(radius=R * 1.012, segments=256, ring_count=128, location=P0)
cl = bpy.context.active_object
for p in cl.data.polygons: p.use_smooth = True
mc = bpy.data.materials.new("clouds"); mc.use_nodes = True
nt, ln = nodes(mc); b = nt["Principled BSDF"]
tc = nt.new("ShaderNodeTexCoord")
w1 = nt.new("ShaderNodeTexNoise"); w1.inputs["Scale"].default_value = 0.045; w1.inputs["Detail"].default_value = 14; w1.inputs["Distortion"].default_value = 0.6
ln.new(tc.outputs["Object"], w1.inputs["Vector"])
cr = nt.new("ShaderNodeValToRGB"); cr.color_ramp.elements[0].position = 0.55; cr.color_ramp.elements[0].color = (0, 0, 0, 1)
cr.color_ramp.elements[1].position = 0.68; cr.color_ramp.elements[1].color = (1, 1, 1, 1)
ln.new(w1.outputs["Fac"], cr.inputs[0])
b.inputs["Base Color"].default_value = (1, 1, 1, 1); b.inputs["Roughness"].default_value = 0.9
ln.new(cr.outputs[0], b.inputs["Alpha"])
cl.data.materials.append(mc); cl.rotation_euler = (0.5, 0.2, 1.0)
# Atmosphäre
bpy.ops.mesh.primitive_uv_sphere_add(radius=R * 1.05, segments=192, ring_count=96, location=P0)
at = bpy.context.active_object
for p in at.data.polygons: p.use_smooth = True
ma = bpy.data.materials.new("atmo"); ma.use_nodes = True
nt, ln = nodes(ma)
for n in list(nt):
    if n.type != "OUTPUT_MATERIAL": nt.remove(n)
out = [n for n in nt if n.type == "OUTPUT_MATERIAL"][0]
tc = nt.new("ShaderNodeTexCoord"); vl = nt.new("ShaderNodeVectorMath"); vl.operation = "LENGTH"; ln.new(tc.outputs["Object"], vl.inputs[0])
mp = nt.new("ShaderNodeMapRange"); mp.inputs["From Min"].default_value = R; mp.inputs["From Max"].default_value = R * 1.05
mp.inputs["To Min"].default_value = 1.0; mp.inputs["To Max"].default_value = 0.0; ln.new(vl.outputs["Value"], mp.inputs["Value"])
pw = nt.new("ShaderNodeMath"); pw.operation = "POWER"; pw.inputs[1].default_value = 2.5; ln.new(mp.outputs["Result"], pw.inputs[0])
dk = nt.new("ShaderNodeMath"); dk.operation = "MULTIPLY"; dk.inputs[1].default_value = 0.06; ln.new(pw.outputs[0], dk.inputs[0])
vs = nt.new("ShaderNodeVolumeScatter"); vs.inputs["Color"].default_value = (0.45, 0.75, 1.0, 1); vs.inputs["Anisotropy"].default_value = 0.3
ln.new(dk.outputs[0], vs.inputs["Density"]); ln.new(vs.outputs[0], out.inputs["Volume"])
at.data.materials.append(ma)

mark("planet")
# Kratermond
M0 = wpos(105, 82, 0)
bpy.ops.mesh.primitive_uv_sphere_add(radius=22, segments=128, ring_count=64, location=M0)
mo = bpy.context.active_object
for p in mo.data.polygons: p.use_smooth = True
mm = bpy.data.materials.new("moon"); mm.use_nodes = True
nt, ln = nodes(mm); b = nt["Principled BSDF"]
tc = nt.new("ShaderNodeTexCoord")
vo = nt.new("ShaderNodeTexVoronoi"); vo.inputs["Scale"].default_value = 0.25; vo.feature = "F1"
ln.new(tc.outputs["Object"], vo.inputs["Vector"])
crt = nt.new("ShaderNodeValToRGB"); ce = crt.color_ramp.elements
ce[0].position = 0.0; ce[0].color = (0, 0, 0, 1); ce[1].position = 0.32; ce[1].color = (1, 1, 1, 1)
q = crt.color_ramp.elements.new(0.36); q.color = (1.3, 1.3, 1.3, 1)
q = crt.color_ramp.elements.new(0.42); q.color = (1, 1, 1, 1)
ln.new(vo.outputs["Distance"], crt.inputs[0])
vo2 = nt.new("ShaderNodeTexVoronoi"); vo2.inputs["Scale"].default_value = 0.8; ln.new(tc.outputs["Object"], vo2.inputs["Vector"])
cr2 = nt.new("ShaderNodeValToRGB"); cr2.color_ramp.elements[0].color = (0, 0, 0, 1); cr2.color_ramp.elements[1].position = 0.3
ln.new(vo2.outputs["Distance"], cr2.inputs[0])
hm = nt.new("ShaderNodeMath"); hm.operation = "ADD"; ln.new(crt.outputs[0], hm.inputs[0])
hm2 = nt.new("ShaderNodeMath"); hm2.operation = "MULTIPLY"; hm2.inputs[1].default_value = 0.4; ln.new(cr2.outputs[0], hm2.inputs[0]); ln.new(hm2.outputs[0], hm.inputs[1])
bump = nt.new("ShaderNodeBump"); bump.inputs["Strength"].default_value = 0.9; bump.inputs["Distance"].default_value = 0.6
ln.new(hm.outputs[0], bump.inputs["Height"]); ln.new(bump.outputs[0], b.inputs["Normal"])
mar = nt.new("ShaderNodeTexNoise"); mar.inputs["Scale"].default_value = 0.06; ln.new(tc.outputs["Object"], mar.inputs["Vector"])
mc2 = nt.new("ShaderNodeValToRGB"); mc2.color_ramp.elements[0].position = 0.45; mc2.color_ramp.elements[0].color = hexc("#5a6070")
mc2.color_ramp.elements[1].position = 0.6; mc2.color_ramp.elements[1].color = hexc("#b8c0cc")
ln.new(mar.outputs["Fac"], mc2.inputs[0]); ln.new(mc2.outputs[0], b.inputs["Base Color"])
b.inputs["Roughness"].default_value = 0.95
mo.data.materials.append(mm)

# Gezeitenstrom: Bogen aus Eis-/Wasserbrocken vom Mond Richtung Planet
ice = principled("ice", "#c8f0ff", 0.0, 0.08, None, 0.0, 0.6, 0.5)
glint = principled("glint", "#ffffff", 0.0, 0.05, "#a0e8ff", 2.0)
for i in range(90):
    t = rng.random() ** 0.8
    ux = 105 + (470 - 105) * t + rng.gauss(0, 5 + 10 * t)
    uy = 82 - 40 * math.sin(t * math.pi) + 10 * t + rng.gauss(0, 4 + 8 * math.sin(t * math.pi))
    if uy > 128: continue
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1, radius=rng.uniform(0.8, 2.6) * (1.2 - 0.6 * t), location=wpos(ux, uy, rng.uniform(-30, 30)))
    o = bpy.context.active_object; o.data.materials.append(glint if rng.random() < 0.15 else ice)
    o.rotation_euler = (rng.uniform(0, 6), rng.uniform(0, 6), rng.uniform(0, 6))

mark("moon")
sun_dir("sun", tuple(SUN), 4.2, (1.0, 0.96, 0.9), angle=0.01)
sun_dir("fill", (-0.6, 0.5, 0.4), 0.12, (0.3, 0.6, 1.0))
render_groups(args()[0])
