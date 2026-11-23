"""Front orthographic render of Grub with the face geometry removed, plus the canon face layout in
pixels (face_layout.json), for designing procedural Vector-style faces. Blender -b --python face/render_faceless.py"""
import bpy, json, math, os
from mathutils import Vector
HERE = os.path.dirname(os.path.abspath(__file__)); ROOT = os.path.dirname(HERE)
bpy.ops.wm.open_mainfile(filepath=os.path.join(ROOT, "grub_clean.blend"))
sc = bpy.context.scene
rig = bpy.data.objects["GrubRig"]; grub = bpy.data.objects["Grub"]
if rig.animation_data: rig.animation_data.action = None
for pb in rig.pose.bones: pb.location = (0, 0, 0); pb.rotation_quaternion = (1, 0, 0, 0)

# --- canon face layout, same maths as build_grub.py
m = json.load(open(os.path.join(ROOT, "grub_measure.json")))
eL, eR, mo, hL, hR = m["eyeL"], m["eyeR"], m["mouth"], m["hiL"], m["hiR"]
ex = ((eL["x0"] + eL["x1"]) / 2 - (eR["x0"] + eR["x1"]) / 2) / 2
ew = ((eL["x1"] - eL["x0"]) + (eR["x1"] - eR["x0"])) / 2
eh = ((eL["z1"] - eL["z0"]) + (eR["z1"] - eR["z0"])) / 2
ez = (eL["z0"] + eL["z1"] + eR["z0"] + eR["z1"]) / 4
hs = ((hL["x1"] - hL["x0"]) + (hR["x1"] - hR["x0"]) + (hL["z1"] - hL["z0"]) + (hR["z1"] - hR["z0"])) / 4
hz = (hL["z0"] + hL["z1"] + hR["z0"] + hR["z1"]) / 4
mw, mh, mz = mo["x1"] - mo["x0"], mo["z1"] - mo["z0"], (mo["z0"] + mo["z1"]) / 2

# --- strip face parts (Eye + Shine materials)
me = grub.data
kill = {i for i, s in enumerate(grub.material_slots) if s.material and s.material.name in ("Grub_Eye", "Grub_Shine")}
import bmesh
bm = bmesh.new(); bm.from_mesh(me)
bmesh.ops.delete(bm, geom=[f for f in bm.faces if f.material_index in kill], context='FACES')
bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context='VERTS')
bm.to_mesh(me); bm.free()

# --- look: the matte pastel skin from the room
def srgb_to_lin(h):
    c = [int(h[i:i + 2], 16) / 255 for i in (1, 3, 5)]
    return tuple(((x + 0.055) / 1.055) ** 2.4 if x > 0.04045 else x / 12.92 for x in c) + (1,)
skin = bpy.data.materials["Grub_Skin"]; b = next(n for n in skin.node_tree.nodes if n.type == 'BSDF_PRINCIPLED')
b.inputs['Base Color'].default_value = srgb_to_lin("#669B8D"); b.inputs['Roughness'].default_value = 0.9
b.inputs['Specular IOR Level'].default_value = 0.15; b.inputs['Sheen Weight'].default_value = 0.5

for o in list(sc.objects):
    if o.type in ('CAMERA', 'LIGHT'): bpy.data.objects.remove(o)
W = 1024; OS = 1.25; CZ = 0.55
cd = bpy.data.cameras.new("Cam"); cd.type = 'ORTHO'; cd.ortho_scale = OS
cam = bpy.data.objects.new("Cam", cd); sc.collection.objects.link(cam); sc.camera = cam
cam.location = (0, -4, CZ); cam.rotation_euler = (math.radians(90), 0, 0)
def area(n, loc, e, s):
    d = bpy.data.lights.new(n, 'AREA'); d.energy = e; d.size = s
    o = bpy.data.objects.new(n, d); sc.collection.objects.link(o); o.location = loc
    o.rotation_euler = (Vector((0, 0, 0.5)) - Vector(loc)).to_track_quat('-Z', 'Y').to_euler()
area("Key", (-1.2, -3, 2.2), 120, 3); area("Fill", (1.6, -2.6, 0.8), 55, 3); area("Top", (0, -0.5, 3), 45, 2)
w = bpy.data.worlds.new("W"); sc.world = w; w.use_nodes = True
bg = next(n for n in w.node_tree.nodes if n.type == 'BACKGROUND'); bg.inputs[0].default_value = srgb_to_lin("#F6EBDD"); bg.inputs[1].default_value = 0.4
sc.render.engine = 'BLENDER_EEVEE'; sc.view_settings.view_transform = 'Standard'
sc.render.resolution_x = sc.render.resolution_y = W; sc.render.film_transparent = False
sc.render.filepath = os.path.join(HERE, "grub_faceless.png")
bpy.ops.render.render(write_still=True)

px = lambda x: W / 2 + x / OS * W
py = lambda z: W / 2 - (z - CZ) / OS * W
s = W / OS
layout = {"size": W, "px_per_unit": s,
          "eye": {"cx_left_px": px(-ex), "cx_right_px": px(ex), "cy_px": py(ez), "w_px": ew * s, "h_px": eh * s,
                  "corner_px": 0.035 * s},
          "pupil": {"size_px": hs * s, "cy_px": py(hz)},
          "mouth": {"cx_px": px(0), "cy_px": py(mz), "w_px": mw * s, "h_px": mh * s}}
json.dump(layout, open(os.path.join(HERE, "face_layout.json"), "w"), indent=1)
print("FACE layout", json.dumps(layout))
