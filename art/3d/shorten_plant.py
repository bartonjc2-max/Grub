"""Shorten the plant above its pot so a jumping Grub can just grab a leaf (Jesse 2026-11-22: "make the plant
just tall enough when he jumps he can grab a leaf"). Measured in Unity: his hands top out at ~1.87 m on the
leaf jump; the leaf cluster was centred at ~2.05 m (leaves 1.59-2.50). Everything above the pot rim is pulled
down toward the rim by SCALE (leaves keep their shape, the stem shortens), so the cluster centres on his reach.
Saves room.blend. Then: render_room_layers.py, painted/build_room_layers.py.
Blender -b --python shorten_plant.py
"""
import bpy, os
from mathutils import Vector
HERE = os.path.dirname(os.path.abspath(__file__))
SCALE = float(os.environ.get("SCALE", "0.845"))
bpy.ops.wm.open_mainfile(filepath=os.path.join(HERE, "room.blend"))
rim = bpy.data.objects["Pot_Rim"]
RIM = max((rim.matrix_world @ v.co).z for v in rim.data.vertices)          # top of the rim
for o in bpy.data.objects:
    if o.type != 'MESH': continue
    if o.name.startswith("Leaf"):
        cz = sum((o.matrix_world @ v.co).z for v in o.data.vertices) / len(o.data.vertices)
        o.location.z += (RIM + (cz - RIM) * SCALE) - cz                      # move, keep the leaf's shape
    elif o.name == "Stem":
        mw, mi = o.matrix_world, o.matrix_world.inverted()
        for v in o.data.vertices:
            w = mw @ v.co
            if w.z > RIM: w.z = RIM + (w.z - RIM) * SCALE
            v.co = mi @ w
        o.data.update()
bpy.context.view_layer.update()
top = max((o.matrix_world @ v.co).z for o in bpy.data.objects if o.name.startswith("Leaf") for v in o.data.vertices)
low = min((o.matrix_world @ v.co).z for o in bpy.data.objects if o.name.startswith("Leaf") for v in o.data.vertices)
print(f"SHORTENED: rim {RIM:.3f}, leaves now {low:.2f}-{top:.2f}")
bpy.ops.wm.save_mainfile()
