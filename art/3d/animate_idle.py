"""Add an 'Idle' loop to grub_clean.blend (keeps Walk + Waddle), then re-export grub_clean.fbx.

72 frames @ 24 fps = 3 s loop. Rigid parts only; nothing deforms:
  breathe  body rises 0.012 on the in-breath; the legs counter-move so the feet stay planted
  sway     a slow side-to-side lean of the body (±1.5°), half the breath rate
  arms     a lazy swing (±6°), slightly out of phase with each other
Character faces -Y, his left is +X. Blender -b --python animate_idle.py
"""
import bpy, math, os
from mathutils import Vector, Quaternion

HERE = os.path.dirname(os.path.abspath(__file__))
E = lambda k, d: float(os.environ.get(k, d))
bpy.ops.wm.open_mainfile(filepath=os.path.join(HERE, "grub_clean.blend"))
sc = bpy.context.scene
rig, grub = bpy.data.objects["GrubRig"], bpy.data.objects["Grub"]
pbs = rig.pose.bones

FRAMES = 72
BREATH, SWAY, ARM = E("BREATH", "0.012"), E("SWAY", "1.5"), E("ARM", "6")


def set_world(pb, qw):
    m3 = pb.bone.matrix_local.to_3x3()
    pb.rotation_mode = 'QUATERNION'
    pb.rotation_quaternion = (m3.inverted() @ qw.to_matrix() @ m3).to_quaternion()


def q(axis, deg):
    return Quaternion(Vector(axis), math.radians(deg))


act = bpy.data.actions.get("Idle")
if act: bpy.data.actions.remove(act)
rig.animation_data_create()
act = bpy.data.actions.new("Idle"); act.use_fake_user = True
for n in ("Walk", "Waddle"):
    if n in bpy.data.actions: bpy.data.actions[n].use_fake_user = True
rig.animation_data.action = act

for f in range(1, FRAMES + 2):
    t = ((f - 1) % FRAMES) / FRAMES
    breath = 0.5 - 0.5 * math.cos(2 * math.pi * 2 * t)        # two breaths per loop
    sway = math.sin(2 * math.pi * t)
    for pb in pbs:
        pb.location = (0, 0, 0); pb.rotation_mode = 'QUATERNION'; pb.rotation_quaternion = (1, 0, 0, 0)
    # body bone points +Z: its local Y is world up
    pbs["body"].location = (0, BREATH * breath, 0)
    set_world(pbs["body"], q((0, 1, 0), SWAY * sway))
    # legs point down (local Y = world down): move them down by the same amount so the feet stay put
    for leg in ("leg.L", "leg.R"):
        pbs[leg].location = (0, BREATH * breath, 0)
        set_world(pbs[leg], q((0, 1, 0), -SWAY * sway))     # cancel the body lean on the legs
    set_world(pbs["arm.L"], q((1, 0, 0), ARM * math.sin(2 * math.pi * t + 0.6)))
    set_world(pbs["arm.R"], q((1, 0, 0), ARM * math.sin(2 * math.pi * t)))
    for pb in pbs:
        pb.keyframe_insert("rotation_quaternion", frame=f)
        pb.keyframe_insert("location", frame=f)
act.frame_range = (1, FRAMES + 1); act.use_frame_range = True; act.use_cyclic = True

# check: the feet must not leave the floor
def lowest_z():
    dg = bpy.context.evaluated_depsgraph_get(); ev = grub.evaluated_get(dg); me = ev.to_mesh()
    z = min((ev.matrix_world @ v.co).z for v in me.vertices); ev.to_mesh_clear(); return z
zs = []
for f in range(1, FRAMES + 1, 6):
    sc.frame_set(f); zs.append(lowest_z())
print("IDLE lowest z range: %.4f .. %.4f" % (min(zs), max(zs)))

sc.frame_set(1)
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(HERE, "grub_clean.blend"))
bpy.ops.object.select_all(action='DESELECT')
grub.select_set(True); rig.select_set(True); bpy.context.view_layer.objects.active = rig
bpy.ops.export_scene.fbx(
    filepath=os.path.join(HERE, "grub_clean.fbx"), use_selection=True,
    object_types={'ARMATURE', 'MESH'}, apply_unit_scale=True, apply_scale_options='FBX_SCALE_ALL',
    bake_space_transform=False, axis_forward='-Z', axis_up='Y', mesh_smooth_type='FACE',
    add_leaf_bones=False, bake_anim=True, bake_anim_use_all_actions=True,
    bake_anim_use_nla_strips=False, path_mode='AUTO')
print("ACTIONS", [a.name for a in bpy.data.actions])
