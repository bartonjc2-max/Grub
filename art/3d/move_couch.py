"""Pull the couch a little off wall A so Grub can stand on its backrest (Jesse 2026-11-22: "Move the couch off
the wall far enough so he can stand on the back of the couch. Make it subtle tho"). Moves every Sofa_* object
by GAP along wall A's inward normal (-Y here). Saves room.blend.  Blender -b --python move_couch.py
"""
import bpy, os
HERE = os.path.dirname(os.path.abspath(__file__))
GAP = float(os.environ.get("GAP", "0.25"))
bpy.ops.wm.open_mainfile(filepath=os.path.join(HERE, "room.blend"))
sofa = [o for o in bpy.data.objects if o.name.startswith("Sofa_") and o.parent is None]
for o in sofa: o.location.y -= GAP
bpy.context.view_layer.update()
bk = [o for o in bpy.data.objects if o.name.startswith("Sofa_Back")]
vs = [o.matrix_world @ v.co for o in bk for v in o.data.vertices]
print("MOVED", [o.name for o in sofa], "back top z %.3f, back y %.3f..%.3f, x %.3f..%.3f" % (max(v.z for v in vs), min(v.y for v in vs), max(v.y for v in vs), min(v.x for v in vs), max(v.x for v in vs)))
bpy.ops.wm.save_mainfile()
