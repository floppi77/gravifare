"""Sektor 8: Schattenring – Ringplanet im Gegenlicht (Sonne knapp hinter dem Planeten).
Nachtseite mit schwach glimmenden Dschungelflächen, Atmosphäre als Volumen (Vorwärtsstreuung), durchscheinender Ring."""
import sys, os, math, random
sys.path.insert(0, os.path.dirname(__file__))
import bpy, bmesh
from mathutils import Vector
from bl_common import *

sc = reset()
sc.cycles.samples = 384
sc.cycles.volume_bounces = 2
sc.cycles.transparent_max_bounces = 16
R = 66.0
C0 = wpos(205, 78, 0)

# Planet
bpy.ops.mesh.primitive_uv_sphere_add(radius=R, segments=128, ring_count=64, location=C0)
pl = bpy.context.active_object
for p in pl.data.polygons: p.use_smooth = True
m = bpy.data.materials.new("planet"); m.use_nodes = True
nt, ln = nodes(m); b = nt["Principled BSDF"]
tc = nt.new("ShaderNodeTexCoord")
nz = nt.new("ShaderNodeTexNoise"); nz.inputs["Scale"].default_value = 0.05; nz.inputs["Detail"].default_value = 12; nz.inputs["Roughness"].default_value = 0.62
ln.new(tc.outputs["Object"], nz.inputs["Vector"])
cr = nt.new("ShaderNodeValToRGB")
cr.color_ramp.elements[0].position = 0.42; cr.color_ramp.elements[0].color = hexc("#0a2a30")     # Meer
cr.color_ramp.elements[1].position = 0.50; cr.color_ramp.elements[1].color = hexc("#1e5a26")     # Dschungel
e = cr.color_ramp.elements.new(0.62); e.color = hexc("#2c7a30")
ln.new(nz.outputs["Fac"], cr.inputs[0]); ln.new(cr.outputs[0], b.inputs["Base Color"])
b.inputs["Roughness"].default_value = 0.8
# Wolken als zweite Rauschebene (aufgehellt)
nz2 = nt.new("ShaderNodeTexNoise"); nz2.inputs["Scale"].default_value = 0.09; nz2.inputs["Detail"].default_value = 8; nz2.inputs["Distortion"].default_value = 2.5
ln.new(tc.outputs["Object"], nz2.inputs["Vector"])
cc = nt.new("ShaderNodeValToRGB"); cc.color_ramp.elements[0].position = 0.55; cc.color_ramp.elements[1].position = 0.72
ln.new(nz2.outputs["Fac"], cc.inputs[0])
mix = nt.new("ShaderNodeMix"); mix.data_type = "RGBA"
ln.new(cc.outputs[0], mix.inputs["Factor"]); ln.new(cr.outputs[0], mix.inputs[6]); mix.inputs[7].default_value = hexc("#c8e8d8")
ln.new(mix.outputs[2], b.inputs["Base Color"])
# Biolumineszenz: nur auf Dschungelflächen, fleckig, schwach
nz3 = nt.new("ShaderNodeTexNoise"); nz3.inputs["Scale"].default_value = 0.12; nz3.inputs["Detail"].default_value = 6
ln.new(tc.outputs["Object"], nz3.inputs["Vector"])
bl = nt.new("ShaderNodeValToRGB"); bl.color_ramp.elements[0].position = 0.5; bl.color_ramp.elements[0].color = (0, 0, 0, 1)
bl.color_ramp.elements[1].position = 0.75; bl.color_ramp.elements[1].color = (1, 1, 1, 1)
ln.new(nz3.outputs["Fac"], bl.inputs[0])
land = nt.new("ShaderNodeMath"); land.operation = "GREATER_THAN"; land.inputs[1].default_value = 0.5
ln.new(nz.outputs["Fac"], land.inputs[0])
mul = nt.new("ShaderNodeMath"); mul.operation = "MULTIPLY"
ln.new(bl.outputs[0], mul.inputs[0]); ln.new(land.outputs[0], mul.inputs[1])
k = nt.new("ShaderNodeMath"); k.operation = "MULTIPLY"; k.inputs[1].default_value = 0.06
ln.new(mul.outputs[0], k.inputs[0])
b.inputs["Emission Color"].default_value = hexc("#40ff90")
ln.new(k.outputs[0], b.inputs["Emission Strength"])
pl.data.materials.append(m)

# Atmosphäre: Volumen-Hülle, Dichte fällt nach außen ab
bpy.ops.mesh.primitive_uv_sphere_add(radius=R * 1.04, segments=96, ring_count=48, location=C0)
at = bpy.context.active_object
for p in at.data.polygons: p.use_smooth = True
ma = bpy.data.materials.new("atmo"); ma.use_nodes = True
nt, ln = nodes(ma)
for n in list(nt):
    if n.type != "OUTPUT_MATERIAL": nt.remove(n)
out = [n for n in nt if n.type == "OUTPUT_MATERIAL"][0]
tc = nt.new("ShaderNodeTexCoord")
vl = nt.new("ShaderNodeVectorMath"); vl.operation = "LENGTH"
ln.new(tc.outputs["Object"], vl.inputs[0])
mp = nt.new("ShaderNodeMapRange"); mp.inputs["From Min"].default_value = R; mp.inputs["From Max"].default_value = R * 1.04
mp.inputs["To Min"].default_value = 1.0; mp.inputs["To Max"].default_value = 0.0
ln.new(vl.outputs["Value"], mp.inputs["Value"])
pw = nt.new("ShaderNodeMath"); pw.operation = "POWER"; pw.inputs[1].default_value = 3.0
ln.new(mp.outputs["Result"], pw.inputs[0])
dk = nt.new("ShaderNodeMath"); dk.operation = "MULTIPLY"; dk.inputs[1].default_value = 0.22
ln.new(pw.outputs[0], dk.inputs[0])
vs = nt.new("ShaderNodeVolumeScatter"); vs.inputs["Color"].default_value = (1, 1, 1, 1); vs.inputs["Anisotropy"].default_value = 0.82
ln.new(dk.outputs[0], vs.inputs["Density"])
ln.new(vs.outputs[0], out.inputs["Volume"])
at.data.materials.append(ma)

# Ring: Kreisring-Netz, Bänder per radialem Verlauf, durchscheinend
bm = bmesh.new()
Ri, Ro, seg = R * 1.45, R * 3.2, 256
for i in range(seg):
    a = i * 2 * math.pi / seg
    bm.verts.new((math.cos(a) * Ri, math.sin(a) * Ri, 0)); bm.verts.new((math.cos(a) * Ro, math.sin(a) * Ro, 0))
bm.verts.ensure_lookup_table()
for i in range(seg):
    j = (i + 1) % seg
    bm.faces.new((bm.verts[2 * i], bm.verts[2 * i + 1], bm.verts[2 * j + 1], bm.verts[2 * j]))
me = bpy.data.meshes.new("ring"); bm.to_mesh(me); bm.free()
rg = link(bpy.data.objects.new("ring", me))
mr = bpy.data.materials.new("ringm"); mr.use_nodes = True
nt, ln = nodes(mr)
for n in list(nt):
    if n.type != "OUTPUT_MATERIAL": nt.remove(n)
out = [n for n in nt if n.type == "OUTPUT_MATERIAL"][0]
tc = nt.new("ShaderNodeTexCoord")
vl = nt.new("ShaderNodeVectorMath"); vl.operation = "LENGTH"; ln.new(tc.outputs["Object"], vl.inputs[0])
mp = nt.new("ShaderNodeMapRange"); mp.inputs["From Min"].default_value = Ri; mp.inputs["From Max"].default_value = Ro
ln.new(vl.outputs["Value"], mp.inputs["Value"])
# Bänder: 1D-Rauschen über den Radius
cxyz = nt.new("ShaderNodeCombineXYZ"); ln.new(mp.outputs["Result"], cxyz.inputs["X"])
nb = nt.new("ShaderNodeTexNoise"); nb.noise_dimensions = "1D"; nb.inputs["Scale"].default_value = 11; nb.inputs["Detail"].default_value = 6
ln.new(mp.outputs["Result"], nb.inputs["W"])
dens = nt.new("ShaderNodeValToRGB")
els = dens.color_ramp.elements
els[0].position = 0.30; els[0].color = (0, 0, 0, 1); els[1].position = 0.62; els[1].color = (1, 1, 1, 1)
ln.new(nb.outputs["Fac"], dens.inputs[0])
# Lücke (Teilung) und weiche Ränder
gap = nt.new("ShaderNodeValToRGB"); ge = gap.color_ramp.elements
ge[0].position = 0.0; ge[0].color = (0, 0, 0, 1); ge[1].position = 0.06; ge[1].color = (1, 1, 1, 1)
e1 = gap.color_ramp.elements.new(0.52); e1.color = (1, 1, 1, 1)
e2 = gap.color_ramp.elements.new(0.55); e2.color = (0, 0, 0, 1)
e3 = gap.color_ramp.elements.new(0.58); e3.color = (0.8, 0.8, 0.8, 1)
e4 = gap.color_ramp.elements.new(0.9); e4.color = (0.5, 0.5, 0.5, 1)
e5 = gap.color_ramp.elements.new(1.0); e5.color = (0, 0, 0, 1)
ln.new(mp.outputs["Result"], gap.inputs[0])
am = nt.new("ShaderNodeMath"); am.operation = "MULTIPLY"
ln.new(dens.outputs[0], am.inputs[0]); ln.new(gap.outputs[0], am.inputs[1])
a2 = nt.new("ShaderNodeMath"); a2.operation = "MULTIPLY"; a2.inputs[1].default_value = 0.85
ln.new(am.outputs[0], a2.inputs[0])
tr = nt.new("ShaderNodeBsdfTranslucent"); tr.inputs["Color"].default_value = hexc("#a0f0c0")
df = nt.new("ShaderNodeBsdfDiffuse"); df.inputs["Color"].default_value = hexc("#4a7a5a")
mx = nt.new("ShaderNodeMixShader"); mx.inputs[0].default_value = 0.7
ln.new(df.outputs[0], mx.inputs[1]); ln.new(tr.outputs[0], mx.inputs[2])
tp = nt.new("ShaderNodeBsdfTransparent")
mx2 = nt.new("ShaderNodeMixShader")
ln.new(a2.outputs[0], mx2.inputs[0]); ln.new(tp.outputs[0], mx2.inputs[1]); ln.new(mx.outputs[0], mx2.inputs[2])
ln.new(mx2.outputs[0], out.inputs["Surface"])
rg.data.materials.append(mr)
rg.location = C0
rg.rotation_euler = (math.radians(8.5), math.radians(16), 0)

# Sonne knapp hinter dem Planeten, oben rechts
mark("planet")
sun_dir("sun", (-0.42, -0.86, -0.29), 12.0, (1.0, 0.95, 0.85), angle=0.01)
sun_dir("ringshine", (0.25, 0.7, 0.65), 0.11, (0.35, 0.9, 0.7))
render_groups(args()[0])
