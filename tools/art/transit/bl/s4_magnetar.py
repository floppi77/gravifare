"""Sektor 4: Magnetfeld – Magnetar mit räumlichen Dipol-Feldlinien (r = L·sin²θ), Plasmaperlen auf den Linien,
Polstrahlen und einem Eismond mit Polarlicht-Ovalen."""
import sys, os, math, random
sys.path.insert(0, os.path.dirname(__file__))
import bpy
from mathutils import Vector, Matrix, Quaternion
from bl_common import *

sc = reset()
sc.cycles.samples = 256
rng = random.Random(404)
C0 = wpos(548, 66, 0)
AX = Vector((0.38, 0.3, 1.0)).normalized()          # magnetische Achse, leicht gekippt
Q = Vector((0, 0, 1)).rotation_difference(AX)

def emis_mat(name, col, k, fade_to=None):
    m = bpy.data.materials.new(name); m.use_nodes = True
    nt, ln = nodes(m)
    for n in list(nt):
        if n.type != "OUTPUT_MATERIAL": nt.remove(n)
    out = [n for n in nt if n.type == "OUTPUT_MATERIAL"][0]
    em = nt.new("ShaderNodeEmission"); em.inputs["Color"].default_value = hexc(col); em.inputs["Strength"].default_value = k
    ln.new(em.outputs[0], out.inputs["Surface"])
    return m

# Magnetar: glühender Kern + Korona-Hülle
bpy.ops.mesh.primitive_uv_sphere_add(radius=4.5, segments=48, ring_count=24, location=C0)
st = bpy.context.active_object
for p in st.data.polygons: p.use_smooth = True
st.data.materials.append(emis_mat("core", "#e8f8ff", 18.0))

def field_line(L, phi, mat, thick, n=220):
    pts = []
    # θ von θ0 bis π-θ0, wobei r(θ0) = Sternradius
    th0 = math.asin(min(1.0, math.sqrt(4.6 / L)))
    for i in range(n + 1):
        th = th0 + (math.pi - 2 * th0) * i / n
        r = L * math.sin(th) ** 2
        p = Vector((r * math.sin(th) * math.cos(phi), r * math.sin(th) * math.sin(phi), r * math.cos(th)))
        pts.append(Q @ p + C0)
    cu = bpy.data.curves.new("fl", "CURVE"); cu.dimensions = "3D"
    sp = cu.splines.new("POLY"); sp.points.add(len(pts) - 1)
    for i, p in enumerate(pts): sp.points[i].co = (p.x, p.y, p.z, 1)
    cu.bevel_depth = thick; cu.bevel_resolution = 2
    o = link(bpy.data.objects.new("fl", cu)); o.data.materials.append(mat)
    return pts

# Farbverlauf: innen weiß-cyan, außen violett, schwächer
shells = [(12, 0.75, "#d8f8ff", 10.0), (20, 0.68, "#a8f0ff", 8.0), (32, 0.6, "#70dcff", 6.0), (50, 0.52, "#50b8ff", 4.4),
          (76, 0.46, "#5890ff", 3.2), (110, 0.42, "#7468ff", 2.3), (160, 0.38, "#9a50f0", 1.6)]
beads = []
for L, th, col, k in shells:
    mat = emis_mat("fl%d" % L, col, k)
    nphi = 10 if L < 120 else 8
    for j in range(nphi):
        phi = j * 2 * math.pi / nphi + rng.uniform(-0.12, 0.12) + L * 0.01
        pts = field_line(L * rng.uniform(0.94, 1.06), phi, mat, th * rng.uniform(0.8, 1.15))
        # Plasmaperlen entlang der Linie
        for q in range(int(L / 18) + 1):
            beads.append((pts[rng.randrange(10, len(pts) - 10)], col, k))
bm = emis_mat("bead", "#ffffff", 14.0)
for p, col, k in beads:
    bpy.ops.mesh.primitive_uv_sphere_add(radius=rng.uniform(0.6, 1.1), segments=10, ring_count=6, location=p)
    o = bpy.context.active_object; o.data.materials.append(emis_mat("b", col, k * 4.0))

# Polstrahlen: lange, nach außen verblassende Kegel
def jet(sign):
    m = bpy.data.materials.new("jet"); m.use_nodes = True
    nt, ln = nodes(m)
    for n in list(nt):
        if n.type != "OUTPUT_MATERIAL": nt.remove(n)
    out = [n for n in nt if n.type == "OUTPUT_MATERIAL"][0]
    tc = nt.new("ShaderNodeTexCoord"); sep = nt.new("ShaderNodeSeparateXYZ"); ln.new(tc.outputs["Generated"], sep.inputs[0])
    cr = nt.new("ShaderNodeValToRGB"); cr.color_ramp.elements[0].color = (0, 0, 0, 1); cr.color_ramp.elements[1].color = (1, 1, 1, 1)
    ln.new(sep.outputs["Z"], cr.inputs[0])
    nz = nt.new("ShaderNodeTexNoise"); nz.inputs["Scale"].default_value = 3.0; nz.inputs["Detail"].default_value = 6
    ln.new(tc.outputs["Object"], nz.inputs["Vector"])
    mul = nt.new("ShaderNodeMath"); mul.operation = "MULTIPLY"; ln.new(cr.outputs[0], mul.inputs[0]); ln.new(nz.outputs["Fac"], mul.inputs[1])
    em = nt.new("ShaderNodeEmission"); em.inputs["Color"].default_value = hexc("#a0e0ff")
    k = nt.new("ShaderNodeMath"); k.operation = "MULTIPLY"; k.inputs[1].default_value = 25.0; ln.new(mul.outputs[0], k.inputs[0]); ln.new(k.outputs[0], em.inputs["Strength"])
    tp = nt.new("ShaderNodeBsdfTransparent"); ad = nt.new("ShaderNodeAddShader")
    ln.new(em.outputs[0], ad.inputs[0]); ln.new(tp.outputs[0], ad.inputs[1]); ln.new(ad.outputs[0], out.inputs["Surface"])
    m.blend_method = "BLEND" if hasattr(m, "blend_method") else None
    Lj = 120.0
    bpy.ops.mesh.primitive_cone_add(vertices=32, radius1=0.4, radius2=9.0, depth=Lj)
    o = bpy.context.active_object; o.data.materials.append(m)
    # Spitze am Stern, öffnet nach außen; Generated-Z: 0 an der Basis (weit), 1 an der Spitze (eng) -> hell am Stern
    d = AX * sign
    o.rotation_mode = "QUATERNION"; o.rotation_quaternion = Vector((0, 0, -1)).rotation_difference(d)
    o.location = C0 + d * (Lj / 2 + 4)
jet(1); jet(-1)

mark("magnetar")
# Eismond rechts unten am Rand mit Polarlicht-Oval
M0 = wpos(40, 300, -100)
bpy.ops.mesh.primitive_uv_sphere_add(radius=34, segments=96, ring_count=48, location=M0)
mo = bpy.context.active_object
for p in mo.data.polygons: p.use_smooth = True
mm = bpy.data.materials.new("ice"); mm.use_nodes = True
nt, ln = nodes(mm); b = nt["Principled BSDF"]
tc = nt.new("ShaderNodeTexCoord")
vo = nt.new("ShaderNodeTexVoronoi"); vo.feature = "DISTANCE_TO_EDGE"; vo.inputs["Scale"].default_value = 0.11
wn = nt.new("ShaderNodeTexNoise"); wn.inputs["Scale"].default_value = 0.08; wn.inputs["Detail"].default_value = 6
mixv = nt.new("ShaderNodeVectorMath"); mixv.operation = "ADD"
sc2 = nt.new("ShaderNodeVectorMath"); sc2.operation = "SCALE"; sc2.inputs["Scale"].default_value = 14.0
ln.new(wn.outputs["Color"], sc2.inputs[0]); ln.new(tc.outputs["Object"], mixv.inputs[0]); ln.new(sc2.outputs[0], mixv.inputs[1])
ln.new(tc.outputs["Object"], wn.inputs["Vector"]); ln.new(mixv.outputs[0], vo.inputs["Vector"])
cr = nt.new("ShaderNodeValToRGB"); cr.color_ramp.elements[0].position = 0.0; cr.color_ramp.elements[0].color = hexc("#9a6a58")
cr.color_ramp.elements[1].position = 0.02; cr.color_ramp.elements[1].color = hexc("#c8e0f0")
ln.new(vo.outputs["Distance"], cr.inputs[0]); ln.new(cr.outputs[0], b.inputs["Base Color"])
b.inputs["Roughness"].default_value = 0.35
bump = nt.new("ShaderNodeBump"); bump.inputs["Strength"].default_value = 0.15; ln.new(vo.outputs["Distance"], bump.inputs["Height"]); ln.new(bump.outputs[0], b.inputs["Normal"])
mo.data.materials.append(mm)
mo.rotation_euler = (math.radians(-35), math.radians(-20), 0)
for z, rr in ((0.92, 0.42), (-0.92, 0.42)):
    bpy.ops.mesh.primitive_torus_add(major_radius=34 * rr, minor_radius=0.9, major_segments=64, minor_segments=8)
    t = bpy.context.active_object; t.data.materials.append(emis_mat("auro", "#50ffb0", 8.0))
    t.parent = mo; t.location = (0, 0, 34 * z)

mark("moon")
sun_dir("star", (-0.85, 0.35, -0.4), 3.0, (0.75, 0.9, 1.0))
render_groups(args()[0])
