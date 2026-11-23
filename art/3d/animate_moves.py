"""Add Grub's gaits and room moves to grub_clean.blend (keeps Idle; replaces Walk), then re-export grub_clean.fbx.

Rigid parts only, like Walk: the body never deforms. Character faces -Y, his left is +X.
  Waddle   (loop) happy penguin gait: short quick steps, big side-to-side roll. Replaces the old
           build_grub.py Waddle, which swung the legs without planting a foot (it slid).
  Trudge   (loop) sad / tired gait: slow, small steps, slumped forward, arms barely swing
  Hop      (loop) excited bunny hops, feet together; the hop height is baked in
  Cheer    (loop) in-place bounce with arms up, for reactions (feed, clean, pet)
  Kick     (once) wind up, kick with the right foot, recover; contact at KICK_CONTACT
  Jump     (once) crouch, spring, air pose, land; Unity flies the arc between JUMP_AIR
  Sit      (loop) sitting on the cushion, legs straight out along the seat with the feet tipped up
           (he has no knees: hanging legs read as standing), leaning back a little, breathing
  SitKick  (loop) sitting, feet fluttering up and down alternately
  PotShake (loop) mischief: hugs the plant pot's rim and rocks it side to side, feet planted
  Wobble   (loop) losing his balance: big side-to-side rocking, arms flailing, feet planted
  FallDown (once) tips over onto his back (feet up) and bounces; holds the last frame lying down
  GetUp    (once) from lying on his back: rocks, heaves forward past upright, settles
  PicSwat  (once) standing on the couch back: reaches up and swipes a picture sideways; contact at PICSWAT_HIT
  PicFix   (once) both hands up on a picture, nudges it straight, a proud little nod; contact at PICFIX_HIT
  LeafJump (once) curious: crouch, hop straight up with one arm reaching high, grab at the top,
           tug on the way down, land; Unity flies the hop between LEAF_AIR and shakes the leaves at LEAF_GRAB
Every gait is measured here: per frame, how far the planted foot sweeps back. That goes to
grub_moves.json so Unity moves him exactly as far as his feet push (no sliding).
Blender -b --python animate_moves.py
"""
import bpy, json, math, os
from mathutils import Vector, Quaternion

HERE = os.path.dirname(os.path.abspath(__file__))
UNITY = os.environ.get("UNITY", os.path.normpath(os.path.join(HERE, "..", "..", "..", "GrubUnity")))
bpy.ops.wm.open_mainfile(filepath=os.path.join(HERE, "grub_clean.blend"))
sc = bpy.context.scene
rig, grub = bpy.data.objects["GrubRig"], bpy.data.objects["Grub"]
pbs = rig.pose.bones
X, Y, Z = (1, 0, 0), (0, 1, 0), (0, 0, 1)
tau = 2 * math.pi


def q(axis, deg):
    return Quaternion(Vector(axis), math.radians(deg))


def set_world(pb, qw):
    m3 = pb.bone.matrix_local.to_3x3()
    pb.rotation_mode = 'QUATERNION'
    pb.rotation_quaternion = (m3.inverted() @ qw.to_matrix() @ m3).to_quaternion()


def reset():
    for pb in pbs:
        pb.location = (0, 0, 0); pb.rotation_mode = 'QUATERNION'; pb.rotation_quaternion = (1, 0, 0, 0)


def verts_world():
    dg = bpy.context.evaluated_depsgraph_get(); ev = grub.evaluated_get(dg); me = ev.to_mesh()
    mw = ev.matrix_world; out = [mw @ v.co for v in me.vertices]; ev.to_mesh_clear(); return out


# body lean: +deg tips the top forward (-Y). Legs / arms: +fwd swings them forward, +out raises them sideways.
def body(lean=0.0, roll=0.0, yaw=0.0, lift=0.0):
    set_world(pbs["body"], q(Z, yaw) @ q(Y, roll) @ q(X, lean))
    if lift: pbs["body"].location = (0, lift, 0)        # body bone points +Z: local Y is up


def leg(side, fwd, lift=0.0):
    set_world(pbs["leg." + side], q(X, -fwd)); pbs["leg." + side].location = (0, -lift, 0)


def arm(side, fwd=0.0, out=0.0):
    s = 1 if side == "L" else -1
    set_world(pbs["arm." + side], q(Y, -s * out) @ q(X, -fwd))


def reach(side, fwd=0.0, up=0.0):
    """Arms rest pointing out and ~30 deg down: raise by `up` degrees (30 = horizontal out, ~115 = straight up), then
    swing round to the front by `fwd` degrees (90 = straight ahead)."""
    s = 1 if side == "L" else -1
    set_world(pbs["arm." + side], q(Z, -s * fwd) @ q(Y, -s * up))


def make(name, frames, pose, loop=True, ground=True):
    """Key pose(t) on frames 1..frames(+1 for loops); ground=True solves root height so the lowest
    point sits on z=0 every frame. pose may return a root lift added after grounding."""
    a = bpy.data.actions.get(name)
    if a: bpy.data.actions.remove(a)
    a = bpy.data.actions.new(name); a.use_fake_user = True
    rig.animation_data_create(); rig.animation_data.action = a
    last = frames + 1 if loop else frames
    for f in range(1, last + 1):
        t = ((f - 1) % frames) / frames if loop else (f - 1) / max(1, frames - 1)
        reset()
        extra = pose(t) or 0.0
        bpy.context.view_layer.update()
        dz = -min(v.z for v in verts_world()) if ground else 0.0
        pbs["root"].location = (0, dz + extra, 0)
        for pb in pbs:
            pb.keyframe_insert("rotation_quaternion", frame=f); pb.keyframe_insert("location", frame=f)
    a.frame_range = (1, last); a.use_frame_range = True; a.use_cyclic = loop
    return a


def measure_travel(action, frames, air_stride=0.0):
    """Per-frame forward travel (Grub units) that keeps the planted foot still: the mean +Y motion
    of the contact vertices from frame f to f+1. Frames with no contact share air_stride evenly."""
    rig.animation_data.action = action
    steps, air = [], []
    for f in range(1, frames + 1):
        sc.frame_set(f); v0 = verts_world()
        zmin = min(v.z for v in v0)
        sc.frame_set(f + 1); v1 = verts_world()
        if zmin < 2e-3:
            idx = [i for i, v in enumerate(v0) if v.z < zmin + 2e-3]
            steps.append(max(0.0, sum(v1[i].y - v0[i].y for i in idx) / len(idx)))
        else:
            steps.append(None); air.append(f)
    if air:
        share = air_stride / len(air)
        steps = [share if s is None else s for s in steps]
    cum = [0.0]
    for s in steps: cum.append(cum[-1] + s)
    return cum


def gait(n_leg, lift, n_arm, roll, yaw, lean, bob=0.0):
    def pose(t):
        c, s = math.cos(tau * t), math.sin(tau * t)
        qb = q(Z, yaw * c) @ q(Y, roll * s) @ q(X, lean)
        body(lean=lean, roll=roll * s, yaw=yaw * c)
        # legs undo the body's roll / twist / lean, so a planted foot stays flat and still while the
        # body waddles over it (otherwise the roll swings the stance foot sideways across the floor)
        inv = qb.inverted()
        for side, fwd, lf in (("L", n_leg * c, lift * max(0.0, -s)), ("R", -n_leg * c, lift * max(0.0, s))):
            set_world(pbs["leg." + side], inv @ q(X, -fwd)); pbs["leg." + side].location = (0, -lf, 0)
        arm("L", -n_arm * c); arm("R", n_arm * c)
        return 0.0
    return pose


moves = {}

# --- gaits --------------------------------------------------------------------------------------
GAITS = {
    #          frames  leg  lift   arm  roll yaw lean
    "Walk":   (24, 28, 0.035, 24, 4.5, 4, 2),     # replaces animate_walk.py's Walk (same numbers, legs now counter the roll)
    "Waddle": (16, 24, 0.034, 18, 9.0, 7, 2),
    "Trudge": (32, 14, 0.014, 5, 2.5, 2, 9),
}
for name, (fr, a_leg, lift, a_arm, roll, yaw, lean) in GAITS.items():
    act = make(name, fr, gait(a_leg, lift, a_arm, roll, yaw, lean))
    moves[name] = {"frames": fr, "loop": True, "travel": measure_travel(act, fr)}

HOP_F, HOP_H, HOP_STRIDE, HOP_GROUND = 18, 0.16, 0.30, 0.28   # ground share of the cycle


def hop(t):
    if t < HOP_GROUND:                           # squash: lean in, arms down/back
        k = math.sin(math.pi * t / HOP_GROUND)
        body(lean=8 * k); arm("L", -25 * k, 10); arm("R", -25 * k, 10)
        leg("L", 0); leg("R", 0)
        return 0.0
    u = (t - HOP_GROUND) / (1 - HOP_GROUND)      # airborne 0..1
    body(lean=-4 * math.sin(math.pi * u))
    arm("L", 60 * math.sin(math.pi * u), 35 * math.sin(math.pi * u))
    arm("R", 60 * math.sin(math.pi * u), 35 * math.sin(math.pi * u))
    leg("L", 14 * math.sin(math.pi * u)); leg("R", 14 * math.sin(math.pi * u))    # feet trail back
    return HOP_H * math.sin(math.pi * u)


act = make("Hop", HOP_F, hop)
moves["Hop"] = {"frames": HOP_F, "loop": True, "travel": measure_travel(act, HOP_F, HOP_STRIDE)}


# --- in-place moves ------------------------------------------------------------------------------
def cheer(t):
    b = abs(math.sin(math.pi * 2 * t))           # two little bounces per loop
    wave = math.sin(tau * 2 * t)
    body(roll=4 * math.sin(tau * t))
    arm("L", 20, 110 + 18 * wave); arm("R", 20, 110 - 18 * wave)
    leg("L", -6 * b); leg("R", -6 * b)
    return 0.06 * b


make("Cheer", 24, cheer)
moves["Cheer"] = {"frames": 24, "loop": True}

KICK_F, KICK_CONTACT = 28, 12


def smooth(x): x = max(0.0, min(1.0, x)); return x * x * (3 - 2 * x)


def kick(t):
    f = t * (KICK_F - 1) + 1
    wind = smooth((f - 1) / 7) * (1 - smooth((f - 9) / 3))           # 1..8 wind up, gone by 12
    swing = smooth((f - 8) / 4) * (1 - smooth((f - 15) / 12))         # 8..12 kick, recover by 27
    body(lean=6 * wind - 14 * swing, roll=-6 * (wind + swing))        # roll onto the left leg
    leg("R", -38 * wind + 88 * swing, 0.02 * swing)
    leg("L", 4 * swing)
    arm("L", -25 * wind + 40 * swing, 25 * swing); arm("R", 30 * wind - 35 * swing, 25 * swing)
    return 0.0


make("Kick", KICK_F, kick, loop=False)
moves["Kick"] = {"frames": KICK_F, "loop": False, "contact": (KICK_CONTACT - 1) / KICK_F}

JUMP_F, JUMP_UP, JUMP_LAND = 24, 7, 18      # crouch 1..6, air 7..17, land 18..24


def jump(t):
    f = t * (JUMP_F - 1) + 1
    crouch = smooth((f - 1) / 5) * (1 - smooth((f - 6) / 2))
    air = smooth((f - 6) / 3) * (1 - smooth((f - 16) / 3))
    land = smooth((f - 17) / 2) * (1 - smooth((f - 20) / 4))
    body(lean=14 * crouch - 6 * air + 8 * land)
    arm("L", -45 * crouch + 150 * air + 25 * land, 20 * air); arm("R", -45 * crouch + 150 * air + 25 * land, 20 * air)
    leg("L", 20 * air); leg("R", 20 * air)
    return 0.0


make("Jump", JUMP_F, jump, loop=False)
moves["Jump"] = {"frames": JUMP_F, "loop": False,
                 "air": [(JUMP_UP - 1) / JUMP_F, (JUMP_LAND - 1) / JUMP_F]}

# --- plant mischief (Jesse 2026-11-21: "mess with the plant") ---------------------------------------
SHAKE_F = 20


def pot_shake(t):
    """Arms forward round the rim, rocking hard side to side twice a loop; legs counter the body so the
    feet stay planted, and lift a touch on the side he rocks away from."""
    c = math.sin(tau * 2 * t)
    qb = q(Z, 4 * c) @ q(Y, 9 * c) @ q(X, 12)
    body(lean=12, roll=9 * c, yaw=4 * c)
    inv = qb.inverted()
    for side, lf in (("L", 0.018 * max(0.0, -c)), ("R", 0.018 * max(0.0, c))):
        set_world(pbs["leg." + side], inv @ q(X, 0)); pbs["leg." + side].location = (0, -lf, 0)
    reach("L", 75 + 5 * c, 25); reach("R", 75 - 5 * c, 25)        # forward round the rim, a little below shoulder
    return 0.0


make("PotShake", SHAKE_F, pot_shake)
moves["PotShake"] = {"frames": SHAKE_F, "loop": True}

LEAF_F, LEAF_UP, LEAF_GRAB, LEAF_LAND = 32, 9, 15, 23   # crouch 1..8, air 9..22 (grab at the top), land 23..32


def leaf_jump(t):
    f = t * (LEAF_F - 1) + 1
    crouch = smooth((f - 1) / 7) * (1 - smooth((f - 8) / 2))
    air = smooth((f - 8) / 3) * (1 - smooth((f - 21) / 3))
    grab = smooth((f - LEAF_GRAB + 1) / 3)                       # after the grab the arm tugs down
    land = smooth((f - 22) / 2) * (1 - smooth((f - 26) / 6))
    body(lean=14 * crouch - 8 * air + 10 * land, roll=-6 * air)
    reach("R", 5 * air, 10 - 25 * crouch + 122 * air - 18 * grab * air)   # the reaching arm goes straight up, tugs after the grab
    reach("L", 5 * air, 10 - 25 * crouch + 110 * air - 15 * grab * air)    # both hands up: a two-handed grab reads from either side
    leg("L", 18 * air - 6 * land); leg("R", 10 * air - 6 * land)
    return 0.0


make("LeafJump", LEAF_F, leaf_jump, loop=False)
moves["LeafJump"] = {"frames": LEAF_F, "loop": False,
                     "air": [(LEAF_UP - 1) / LEAF_F, (LEAF_LAND - 1) / LEAF_F], "contact": (LEAF_GRAB - 1) / LEAF_F}

# --- wobble, fall, get up; picture mischief and fixing (Jesse 2026-11-22) -------------------------------
def wobble(t):
    c = math.sin(tau * t)
    qb = q(Z, 6 * math.sin(tau * 2 * t)) @ q(Y, 14 * c) @ q(X, 0)
    body(roll=14 * c, yaw=6 * math.sin(tau * 2 * t))
    inv = qb.inverted()
    for side in ("L", "R"):
        set_world(pbs["leg." + side], inv @ q(X, 0))
    reach("L", 10, 55 + 30 * math.sin(tau * 2 * t + 0.5)); reach("R", 10, 55 - 30 * math.sin(tau * 2 * t))
    return 0.0


make("Wobble", 24, wobble)
moves["Wobble"] = {"frames": 24, "loop": True}

FALL_F = 20


def fall_down(t):
    f = t * (FALL_F - 1) + 1
    tip = smooth((f - 1) / 11)                                  # 0 upright -> 1 on his back by frame 12
    bounce = math.sin(math.pi * min(1.0, max(0.0, (f - 12) / 8))) * (1 - smooth((f - 12) / 8))
    body(lean=-92 * tip + 7 * bounce, roll=6 * math.sin(math.pi * tip))
    reach("L", 20 * tip, 40 + 70 * math.sin(math.pi * min(1, tip * 1.2)))   # arms fly up on the way down
    reach("R", 20 * tip, 40 + 70 * math.sin(math.pi * min(1, tip * 1.2)))
    leg("L", 10 * tip); leg("R", 10 * tip)
    return 0.0


make("FallDown", FALL_F, fall_down, loop=False)
moves["FallDown"] = {"frames": FALL_F, "loop": False}

GETUP_F = 30


def get_up(t):
    f = t * (GETUP_F - 1) + 1
    rock = math.sin(tau * min(1.0, (f - 1) / 10)) * (1 - smooth((f - 8) / 4))    # two little rocks to build up
    heave = smooth((f - 10) / 9)                                                 # up past upright...
    settle = smooth((f - 19) / 10)                                               # ...and back to standing
    lean = -92 + 8 * rock + (92 + 14) * heave - 14 * settle
    body(lean=lean)
    reach("L", 60 * heave * (1 - settle), 20 + 30 * (1 - heave)); reach("R", 60 * heave * (1 - settle), 20 + 30 * (1 - heave))
    leg("L", 10 * (1 - heave)); leg("R", 10 * (1 - heave))
    return 0.04 * math.sin(math.pi * heave) * (1 - settle)


make("GetUp", GETUP_F, get_up, loop=False)
moves["GetUp"] = {"frames": GETUP_F, "loop": False}

PICSWAT_F, PICSWAT_HIT = 24, 11


def pic_swat(t):
    f = t * (PICSWAT_F - 1) + 1
    up = smooth((f - 1) / 6) * (1 - smooth((f - 17) / 6))
    sweep = smooth((f - 7) / 6)                                   # the swipe crosses the picture by frame 13
    body(lean=-6 * up, roll=-8 * (sweep - 0.5) * up, yaw=10 * (sweep - 0.5) * up)
    reach("R", -25 + 55 * sweep, 20 + 100 * up)                   # straight-arm swipe, high
    reach("L", 0, 30 + 20 * up)
    return 0.0


make("PicSwat", PICSWAT_F, pic_swat, loop=False)
moves["PicSwat"] = {"frames": PICSWAT_F, "loop": False, "contact": (PICSWAT_HIT - 1) / PICSWAT_F}

PICFIX_F, PICFIX_HIT = 36, 14


def pic_fix(t):
    f = t * (PICFIX_F - 1) + 1
    up = smooth((f - 1) / 8) * (1 - smooth((f - 26) / 6))
    nudge = math.sin(tau * min(1.0, max(0.0, (f - 10) / 14))) * up   # a careful back-and-forth while it settles
    nod = math.sin(math.pi * min(1.0, max(0.0, (f - 29) / 7)))
    body(lean=-5 * up + 8 * nod, roll=3 * nudge)
    reach("L", 10 + 6 * nudge, 25 + 95 * up); reach("R", 10 - 6 * nudge, 25 + 95 * up)
    return 0.0


make("PicFix", PICFIX_F, pic_fix, loop=False)
moves["PicFix"] = {"frames": PICFIX_F, "loop": False, "contact": (PICFIX_HIT - 1) / PICFIX_F}

SIT_LEG = 110        # legs out along the seat, feet ~20 deg above horizontal (Jesse 2026-11-21)
SIT_LEAN = -10


def sit(t):
    br = 0.5 - 0.5 * math.cos(tau * 2 * t)
    body(lean=SIT_LEAN, lift=0.008 * br)
    leg("L", -SIT_LEG); leg("R", -SIT_LEG)
    arm("L", -18 + 3 * math.sin(tau * t + 0.6), 12); arm("R", -18 + 3 * math.sin(tau * t), 12)
    return 0.0


def sit_kick(t):
    s = math.sin(tau * t)
    body(lean=SIT_LEAN + 1.5 * abs(s), roll=2 * s)
    leg("L", -SIT_LEG + 14 * s); leg("R", -SIT_LEG - 14 * s)
    arm("L", -18 - 6 * s, 14); arm("R", -18 + 6 * s, 14)
    return 0.0


make("Sit", 48, sit, ground=False)
make("SitKick", 16, sit_kick, ground=False)
moves["Sit"] = {"frames": 48, "loop": True}
moves["SitKick"] = {"frames": 16, "loop": True}

# where his seat is in the Sit pose (lowest point of the body part, Grub units), so Unity can put it on a cushion
rig.animation_data.action = bpy.data.actions["Sit"]; sc.frame_set(1)
dg = bpy.context.evaluated_depsgraph_get(); ev = grub.evaluated_get(dg); me = ev.to_mesh()
vg = {g.index: g.name for g in grub.vertex_groups}
def part(name, axis):
    return [(ev.matrix_world @ v.co)[axis] for v in me.vertices if any(vg.get(g.group) == name and g.weight > 0.5 for g in v.groups)]
body_z, body_y = part("body", 2), part("body", 1)
legs_z = part("leg.L", 2) + part("leg.R", 2); legs_y = part("leg.L", 1) + part("leg.R", 1)
ev.to_mesh_clear()
# the seat is whatever rests lowest: with the legs out along the cushion that may be the backs of the legs
sit_info = {"seat_z": min(body_z + legs_z), "body_seat_z": min(body_z), "legs_seat_z": min(legs_z),
            "body_front_y": min(body_y), "body_back_y": max(body_y), "feet_front_y": min(legs_y)}

for n in ("Walk", "Idle"):
    if n in bpy.data.actions: bpy.data.actions[n].use_fake_user = True
rig.animation_data.action = bpy.data.actions["Idle"]
sc.frame_set(1)

out = {"fps": 24, "moves": moves, "sit": sit_info}
for nm, m in moves.items():
    if "travel" in m:
        print(f"MOVE {nm}: {m['frames']}f stride {m['travel'][-1]:.4f} Grub units/cycle "
              f"= {m['travel'][-1] / (m['frames'] / 24):.3f} u/s")
print("SIT", sit_info)
json.dump(out, open(os.path.join(HERE, "grub_moves.json"), "w"), indent=1)
os.makedirs(os.path.join(UNITY, "Assets", "Grub", "Grub"), exist_ok=True)
json.dump(out, open(os.path.join(UNITY, "Assets", "Grub", "Grub", "grub_moves.json"), "w"), indent=1)

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
