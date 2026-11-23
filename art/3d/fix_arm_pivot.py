"""Centre each arm's buried inner end on its shoulder pivot (Jesse 2026-11-22: "the roundness of his arm in the
armpit when his arms are up is still showing and reading poorly").

The arm capsules were built with their inner hemisphere sunk ~0.1 past the pivot, inside the body. The bone turns
about the pivot, so when a hand swings up that buried end swings down and OUT, and pokes from under the arm as a
rounded lobe in every arms-up clip. With the inner hemisphere centred on the pivot it is the same sphere at any
rotation: nothing ever swings out. The hand end and the arm's length outside the body are unchanged.

Edits grub_clean.blend in place (backup: renders/grub_clean_before_armfix.blend), re-exports grub_clean.fbx with
animate_moves.py's settings and copies it into Unity.
Blender -b --python fix_arm_pivot.py
"""
import bpy, os, shutil
from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__))
UNITY = os.environ.get("UNITY", os.path.normpath(os.path.join(HERE, "..", "..", "..", "GrubUnity")))
bpy.ops.wm.open_mainfile(filepath=os.path.join(HERE, "grub_clean.blend"))
grub, rig = bpy.data.objects["Grub"], bpy.data.objects["GrubRig"]

# build_grub.py's arm, left side (right is mirrored in x)
shoulder = Vector((0.30, -0.015, 0.47)); arm_tip = Vector((0.411, -0.046, 0.235)); r_arm = 0.085
d = (shoulder - arm_tip).normalized()
bottom = arm_tip + d * r_arm
top = shoulder + d * 0.03 + Vector((-0.07, 0, 0))
new_top = shoulder.copy()

me = grub.data
moved = 0
for gname, sx in (("arm.L", 1), ("arm.R", -1)):
    gi = grub.vertex_groups[gname].index
    mx = lambda v: Vector((v.x * sx, v.y, v.z))
    B, T, T2 = mx(bottom), mx(top), mx(new_top)
    A, A2 = T - B, T2 - B
    L = A.length; Ah = A.normalized()
    rot = Ah.rotation_difference(A2.normalized()).to_matrix()
    for v in me.vertices:
        if not any(g.group == gi and g.weight > 0.5 for g in v.groups): continue
        p = v.co.copy(); s = (p - B).dot(Ah) / L
        if s <= 0: q = B + rot @ (p - B)                          # hand hemisphere: just follows the axis turn
        elif s < 1: c = B + A * s; q = B + A2 * s + rot @ (p - c)   # the tube
        else: q = T2 + rot @ (p - T)                                # inner hemisphere: centred on the pivot
        v.co = q; moved += 1
me.update()
print("ARMFIX moved", moved, "verts; inner end", (top - new_top).length, "closer to the pivot")

# the bone heads must be the pivot (they are: build_grub.py makes arm.* from shoulder to arm_tip)
for b in rig.data.bones:
    if b.name.startswith("arm."): print("ARMFIX bone", b.name, tuple(round(x, 3) for x in b.head_local))

bpy.ops.wm.save_as_mainfile(filepath=os.path.join(HERE, "grub_clean.blend"))
bpy.ops.object.select_all(action='DESELECT')
grub.select_set(True); rig.select_set(True); bpy.context.view_layer.objects.active = rig
bpy.ops.export_scene.fbx(
    filepath=os.path.join(HERE, "grub_clean.fbx"), use_selection=True,
    object_types={'ARMATURE', 'MESH'}, apply_unit_scale=True, apply_scale_options='FBX_SCALE_ALL',
    bake_space_transform=False, axis_forward='-Z', axis_up='Y', mesh_smooth_type='FACE',
    add_leaf_bones=False, bake_anim=True, bake_anim_use_all_actions=True,
    bake_anim_use_nla_strips=False, path_mode='AUTO')
shutil.copy2(os.path.join(HERE, "grub_clean.fbx"), os.path.join(UNITY, "Assets", "Grub", "Grub", "grub_clean.fbx"))
print("ARMFIX exported")
