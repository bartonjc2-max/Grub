"""Add an in-place 'Walk' cycle to grub_clean.blend (keeps 'Waddle'), then re-export grub_clean.fbx.

24 frames @ 24 fps = one cycle (two steps). Rigid parts only: the body never deforms.
  legs   alternate: the stance leg sweeps back on the floor, the swing leg lifts and comes forward
  arms   counter-swing against the legs
  body   rolls onto the stance leg (waddle), slight twist and forward lean
  root   height solved per frame so the lowest point of Grub sits exactly on z = 0 (natural bob)
Character faces -Y, his left is +X. Blender -b --python animate_walk.py
"""
import bpy, math, os
from mathutils import Vector, Quaternion

HERE = os.path.dirname(os.path.abspath(__file__))
E = lambda k, d: float(os.environ.get(k, d))
bpy.ops.wm.open_mainfile(filepath=os.path.join(HERE, "grub_clean.blend"))
sc = bpy.context.scene
rig, grub = bpy.data.objects["GrubRig"], bpy.data.objects["Grub"]
pbs = rig.pose.bones

FRAMES = 24
A_LEG, LIFT = E("A_LEG", "28"), E("LIFT", "0.035")      # leg swing (deg), swing-foot lift (Grub units)
A_ARM = E("A_ARM", "24")
ROLL, YAW, LEAN = E("ROLL", "4.5"), E("YAW", "4"), E("LEAN", "3")

def world_q(axis, deg):
    return Quaternion(Vector(axis), math.radians(deg))

def set_world(pb, qw):
    """Apply a world-space rotation to a pose bone, expressed in its rest frame."""
    m3 = pb.bone.matrix_local.to_3x3()
    pb.rotation_mode = 'QUATERNION'
    pb.rotation_quaternion = (m3.inverted() @ qw.to_matrix() @ m3).to_quaternion()

def pose_at(t):
    c, s = math.cos(2 * math.pi * t), math.sin(2 * math.pi * t)
    thL, thR = -A_LEG * c, A_LEG * c                      # forward = negative about X
    liftL, liftR = LIFT * max(0.0, -s), LIFT * max(0.0, s)
    # body: roll onto the stance leg (+Y roll lowers his left/+X side), twist, lean forward
    q_body = world_q((0, 0, 1), YAW * c) @ world_q((0, 1, 0), ROLL * s) @ world_q((1, 0, 0), -LEAN)
    set_world(pbs["body"], q_body)
    set_world(pbs["leg.L"], world_q((1, 0, 0), thL)); pbs["leg.L"].location = (0, -liftL, 0)
    set_world(pbs["leg.R"], world_q((1, 0, 0), thR)); pbs["leg.R"].location = (0, -liftR, 0)
    set_world(pbs["arm.L"], world_q((1, 0, 0), A_ARM * c))      # opposite to the left leg
    set_world(pbs["arm.R"], world_q((1, 0, 0), -A_ARM * c))

def lowest_z():
    dg = bpy.context.evaluated_depsgraph_get()
    ev = grub.evaluated_get(dg); me = ev.to_mesh()
    mw = ev.matrix_world
    z = min((mw @ v.co).z for v in me.vertices)
    ev.to_mesh_clear(); return z

# fresh action; keep Waddle untouched
act = bpy.data.actions.get("Walk")
if act: bpy.data.actions.remove(act)
rig.animation_data_create()
act = bpy.data.actions.new("Walk"); act.use_fake_user = True
if "Waddle" in bpy.data.actions: bpy.data.actions["Waddle"].use_fake_user = True
rig.animation_data.action = act

offsets = []
for f in range(1, FRAMES + 2):                 # frame 25 == frame 1 so the loop is seamless
    t = ((f - 1) % FRAMES) / FRAMES
    for pb in pbs:
        pb.location = (0, 0, 0); pb.rotation_mode = 'QUATERNION'; pb.rotation_quaternion = (1, 0, 0, 0)
    pose_at(t)
    bpy.context.view_layer.update()
    dz = -lowest_z()
    pbs["root"].location = (0, dz, 0)          # root points +Z, so its local Y is world up
    offsets.append(dz)
    for pb in pbs:
        pb.keyframe_insert("rotation_quaternion", frame=f)
        pb.keyframe_insert("location", frame=f)
act.frame_range = (1, FRAMES + 1)
act.use_frame_range = True; act.use_cyclic = True
print("WALK root bob (Grub units): min %.4f max %.4f" % (min(offsets), max(offsets)))

# verify contact: lowest point must sit on the floor every frame
bad = []
for f in range(1, FRAMES + 1):
    sc.frame_set(f)
    z = lowest_z()
    if abs(z) > 1e-3: bad.append((f, round(z, 4)))
print("WALK contact errors:", bad or "none")

sc.frame_start, sc.frame_end, sc.render.fps = 1, FRAMES, 24
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
