"""Living-room rug (Jesse 2026-11-22: Gemini's terracotta oval, "make it larger and closer to the camera").
A low-pile oval in front of the couch, terracotta #D98A72 with a cream #F7E8D8 inset border, 1 cm thick with
a soft rounded edge. Static: part of the bare room, so the couch and plant shadows fall on it.
Blender -b room.blend --python add_rug.py   (saves room.blend; replaces an existing Rug)
"""
import bpy, os
SIZE = (4.4, 3.0)                 # metres across (along the couch, front to back)
CENTRE = (-2.9, -3.3)             # Blender floor x, y (Unity x = -x, z = -y): front edge ~1/4 up the screen
THICK, INSET, BORDER = 0.010, 0.16, 0.07

def lin(h):
    h = h.lstrip('#'); c = [int(h[i:i + 2], 16) / 255 for i in (0, 2, 4)]
    return [x / 12.92 if x <= 0.04045 else ((x + 0.055) / 1.055) ** 2.4 for x in c] + [1]

old = bpy.data.objects.get("Rug")
if old: bpy.data.objects.remove(old, do_unlink=True)
bpy.ops.mesh.primitive_cylinder_add(vertices=160, radius=1, depth=THICK, location=(CENTRE[0], CENTRE[1], THICK / 2))
rug = bpy.context.object; rug.name = "Rug"
rug.scale = (SIZE[0] / 2, SIZE[1] / 2, 1)
bpy.ops.object.transform_apply(scale=True)
bev = rug.modifiers.new("soft edge", 'BEVEL'); bev.width = THICK * 0.45; bev.segments = 3
bpy.ops.object.shade_smooth()

m = bpy.data.materials.get("Rug") or bpy.data.materials.new("Rug")
m.use_nodes = True; nt = m.node_tree; nt.nodes.clear()
out = nt.nodes.new("ShaderNodeOutputMaterial"); bsdf = nt.nodes.new("ShaderNodeBsdfPrincipled")
bsdf.inputs["Roughness"].default_value = 1.0
bsdf.inputs["Base Color"].default_value = lin("#D98A72")
nt.links.new(bsdf.outputs[0], out.inputs[0])
rug.data.materials.clear(); rug.data.materials.append(m)
# the cream inset border: a flat elliptical ring lying on the pile
import bmesh, math as m_
old = bpy.data.objects.get("Rug_Border")
if old: bpy.data.objects.remove(old, do_unlink=True)
me = bpy.data.meshes.new("Rug_Border"); bm = bmesh.new(); N = 200
a, b = SIZE[0] / 2 - INSET, SIZE[1] / 2 - INSET
outer = [bm.verts.new((CENTRE[0] + m_.cos(2 * m_.pi * k / N) * a, CENTRE[1] + m_.sin(2 * m_.pi * k / N) * b, THICK + 0.0008)) for k in range(N)]
inner = [bm.verts.new((CENTRE[0] + m_.cos(2 * m_.pi * k / N) * (a - BORDER), CENTRE[1] + m_.sin(2 * m_.pi * k / N) * (b - BORDER), THICK + 0.0008)) for k in range(N)]
for k in range(N): bm.faces.new((outer[k], outer[(k + 1) % N], inner[(k + 1) % N], inner[k]))
bm.to_mesh(me); bm.free()
border = bpy.data.objects.new("Rug_Border", me); rug.users_collection[0].objects.link(border)
mb = bpy.data.materials.get("Rug_Border") or bpy.data.materials.new("Rug_Border"); mb.use_nodes = True
pb = next(n for n in mb.node_tree.nodes if n.type == 'BSDF_PRINCIPLED')
pb.inputs["Base Color"].default_value = lin("#F7E8D8"); pb.inputs["Roughness"].default_value = 1.0
me.materials.append(mb)
bpy.ops.wm.save_mainfile()
print("RUG", rug.name, [round(x, 2) for x in rug.dimensions])
