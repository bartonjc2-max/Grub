"""Clean Grub, built from shapes to the Tripo model's measurements (grub_measure.json),
rigged as rigid parts and exported for Unity.

  /Applications/Blender.app/Contents/MacOS/Blender -b --python build_grub.py

Why rebuild: the Tripo mesh has the arms and legs fused into the body (any cut leaves a
flange of body on the limb) and a noisy baked texture. Here the limbs are separate shapes
whose inner ends sit hidden inside the body, and every colour is a flat material.
Front is -Y, character's left is +X. Outputs: grub_clean.blend/.fbx, renders/clean_*.png
"""
import bpy, bmesh, json, math, os
from mathutils import Vector, Matrix, Quaternion

HERE = os.path.dirname(os.path.abspath(__file__))
m = json.load(open(os.path.join(HERE, "grub_measure.json")))
os.makedirs(os.path.join(HERE, "renders"), exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene

def lin(c):  # sRGB-encoded sample -> linear for the material
    return tuple(((x + 0.055) / 1.055) ** 2.4 if x > 0.04045 else x / 12.92 for x in c)

def material(name, srgb, rough):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = next(n for n in mat.node_tree.nodes if n.type == 'BSDF_PRINCIPLED')
    bsdf.inputs["Base Color"].default_value = (*lin(srgb), 1)
    bsdf.inputs["Roughness"].default_value = rough
    mat.diffuse_color = (*lin(srgb), 1)          # viewport / workbench colour
    return mat

SKIN = material("Grub_Skin", m["skin_rgb_linear"], 0.55)
EYE = material("Grub_Eye", m["eye_rgb_linear"], 0.25)
SHINE = material("Grub_Shine", (0.91, 0.96, 0.95), 0.3)

def new_obj(name, bm, mat, group):
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me); bm.free()
    ob = bpy.data.objects.new(name, me)
    scene.collection.objects.link(ob)
    ob.data.materials.append(mat)
    vg = ob.vertex_groups.new(name=group)
    vg.add([v.index for v in me.vertices], 1.0, 'REPLACE')
    return ob

def rounded_box(name, size, center, bevel, segs, mat, group):
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    bmesh.ops.scale(bm, vec=Vector(size), verts=bm.verts)
    bmesh.ops.bevel(bm, geom=bm.verts[:] + bm.edges[:], offset=bevel, segments=segs,
                    profile=0.5, affect='EDGES', clamp_overlap=True)
    bmesh.ops.translate(bm, vec=Vector(center), verts=bm.verts)
    return new_obj(name, bm, mat, group)

def capsule(name, a, b, r, mat, group, flat_bottom=1.0):
    """Capsule from end a (bottom) to end b (top), both ends rounded with radius r.
    flat_bottom < 1 squashes the a-end hemisphere into a foot."""
    axis = b - a
    L = axis.length
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=32, v_segments=20, radius=r)
    for v in bm.verts:
        if v.co.z > 0:
            v.co.z += L
        else:
            v.co.z *= flat_bottom
    rot = Vector((0, 0, 1)).rotation_difference(axis.normalized()).to_matrix().to_4x4()
    bmesh.ops.transform(bm, matrix=Matrix.Translation(a) @ rot, verts=bm.verts)
    return new_obj(name, bm, mat, group)

# --- body ------------------------------------------------------------------------------------
B = m["body"]
hw, y0, y1 = B["half_w"], B["y_min"], B["y_max"]
zb, zt = B["z_bottom"], B["z_top"]
front_y = (y0 - y1) / 2                       # symmetric depth, front face at -depth/2
depth = y1 - y0
body = rounded_box("Body", (2 * hw, depth, zt - zb), (0, 0, (zt + zb) / 2), 0.30, 16, SKIN, "body")

# --- face: symmetric average of the measured left/right features ------------------------
eL, eR, mo = m["eyeL"], m["eyeR"], m["mouth"]
ex = ((eL["x0"] + eL["x1"]) / 2 - (eR["x0"] + eR["x1"]) / 2) / 2
ew = ((eL["x1"] - eL["x0"]) + (eR["x1"] - eR["x0"])) / 2
eh = ((eL["z1"] - eL["z0"]) + (eR["z1"] - eR["z0"])) / 2
ez = (eL["z0"] + eL["z1"] + eR["z0"] + eR["z1"]) / 4
hL, hR = m["hiL"], m["hiR"]
hs = ((hL["x1"] - hL["x0"]) + (hR["x1"] - hR["x0"]) + (hL["z1"] - hL["z0"]) + (hR["z1"] - hR["z0"])) / 4
hz = (hL["z0"] + hL["z1"] + hR["z0"] + hR["z1"]) / 4
eye_t = 0.03                                   # half sunk into the face, ~1.5 cm proud
face_parts = []
for side in (1, -1):
    face_parts.append(rounded_box(f"Eye{side}", (ew, eye_t, eh), (side * ex, front_y, ez), 0.035, 6, EYE, "body"))
    face_parts.append(rounded_box(f"Shine{side}", (hs, 0.012, hs), (side * ex, front_y - eye_t / 2 - 0.002, hz),
                                  0.008, 3, SHINE, "body"))
mw, mh, mz = mo["x1"] - mo["x0"], mo["z1"] - mo["z0"], (mo["z0"] + mo["z1"]) / 2
face_parts.append(rounded_box("Mouth", (mw, 0.02, mh), (0, front_y, mz), 0.012, 4, EYE, "body"))

# --- limbs: inner ends buried inside the body so the joint never shows ------------------
shoulder = Vector((0.30, -0.015, 0.47))      # pivot where the arm leaves the flank
arm_tip = Vector((0.411, -0.046, 0.235))     # bottom of the arm (Tripo landmark)
r_arm = 0.085
arm_dir = (shoulder - arm_tip).normalized()
arm_bottom = arm_tip + arm_dir * r_arm        # centre of the tip hemisphere
arm_top = shoulder + arm_dir * 0.03 + Vector((-0.07, 0, 0))   # sunk into the body
hip = Vector((0.182, 0.0, 0.17))
r_leg = 0.095
leg_bottom = Vector((hip.x, hip.y, r_leg * 0.55))   # flattened foot touching z = 0
leg_top = Vector((hip.x, hip.y, zb + 0.10))         # well inside the body
def mx(v): return Vector((-v.x, v.y, v.z))
limbs = [
    capsule("ArmL", arm_bottom, arm_top, r_arm, SKIN, "arm.L"),
    capsule("ArmR", mx(arm_bottom), mx(arm_top), r_arm, SKIN, "arm.R"),
    capsule("LegL", leg_bottom, leg_top, r_leg, SKIN, "leg.L", flat_bottom=0.55),
    capsule("LegR", mx(leg_bottom), mx(leg_top), r_leg, SKIN, "leg.R", flat_bottom=0.55),
]

# --- one mesh, smooth shading where curved, flat where flat ------------------------------
for ob in [body] + face_parts + limbs:
    ob.select_set(True)
bpy.context.view_layer.objects.active = body
bpy.ops.object.join()
grub = bpy.context.active_object
grub.name = "Grub"
bpy.ops.object.shade_smooth_by_angle(angle=math.radians(50))
tris = sum(len(p.vertices) - 2 for p in grub.data.polygons)
print("GRUB tris", tris, "groups", [g.name for g in grub.vertex_groups],
      "mats", [s.name for s in grub.data.materials])

# --- armature -------------------------------------------------------------------------------
arm_data = bpy.data.armatures.new("GrubRig")
rig = bpy.data.objects.new("GrubRig", arm_data)
scene.collection.objects.link(rig)
bpy.context.view_layer.objects.active = rig
bpy.ops.object.mode_set(mode='EDIT')
eb = arm_data.edit_bones
def bone(name, head, tail, parent=None, deform=True):
    b = eb.new(name); b.head, b.tail = head, tail; b.parent = parent; b.use_deform = deform
    return b
root = bone("root", Vector((0, 0, 0)), Vector((0, 0, 0.1)), deform=False)
bbody = bone("body", Vector((0, 0, 0.14)), Vector((0, 0, zt * 0.95)), root)
bone("arm.L", shoulder, arm_tip, bbody)
bone("arm.R", mx(shoulder), mx(arm_tip), bbody)
bone("leg.L", hip, Vector((hip.x, hip.y, 0.02)), bbody)
bone("leg.R", mx(hip), mx(Vector((hip.x, hip.y, 0.02))), bbody)
bpy.ops.object.mode_set(mode='OBJECT')
mod = grub.modifiers.new("Armature", 'ARMATURE'); mod.object = rig
grub.parent = rig
bad = [v.index for v in grub.data.vertices if sum(1 for g in v.groups if g.weight > 0) != 1]
print("VERTS not in exactly one part:", len(bad))

# --- posing helpers, render setup -------------------------------------------------------------
pbs = rig.pose.bones
X, Y = (1, 0, 0), (0, 1, 0)
def set_world_rot(pb, axis, deg):
    m3 = pb.bone.matrix_local.to_3x3()
    q = Quaternion(Vector(axis), math.radians(deg)).to_matrix()
    pb.rotation_mode = 'QUATERNION'
    pb.rotation_quaternion = (m3.inverted() @ q @ m3).to_quaternion()
def clear_pose():
    for pb in pbs:
        pb.rotation_mode = 'QUATERNION'; pb.rotation_quaternion = (1, 0, 0, 0); pb.location = (0, 0, 0)

scene.render.engine = 'BLENDER_WORKBENCH'
scene.view_settings.view_transform = 'Standard'   # AgX mutes the flat colours in previews
scene.display.shading.light = 'STUDIO'
scene.display.shading.color_type = 'MATERIAL'
scene.display.shading.show_specular_highlight = True
scene.render.resolution_x = scene.render.resolution_y = 640
scene.world = bpy.data.worlds.new("W")
cam_data = bpy.data.cameras.new("Cam"); cam_data.type = 'ORTHO'; cam_data.ortho_scale = 1.5
cam = bpy.data.objects.new("Cam", cam_data); scene.collection.objects.link(cam); scene.camera = cam
def shoot(name, az):
    a = math.radians(az)
    cam.location = Vector((3 * math.sin(a), -3 * math.cos(a), 0.55))
    cam.rotation_euler = (math.radians(90), 0, a)
    scene.render.filepath = os.path.join(HERE, "renders", f"clean_{name}.png")
    bpy.ops.render.render(write_still=True)

clear_pose(); shoot("rest_front", 0); shoot("rest_34", 35)
set_world_rot(pbs["arm.L"], Y, -45)    # wave up and out
set_world_rot(pbs["arm.R"], X, -40)    # swing forward
set_world_rot(pbs["leg.L"], X, -30)    # step forward
set_world_rot(pbs["leg.R"], X, 20)     # step back
bpy.context.view_layer.update()
shoot("pose_front", 0); shoot("pose_34", 35); shoot("pose_side", 90)
clear_pose()

# --- waddle: only the limbs move ----------------------------------------------------------------
rig.animation_data_create()
rig.animation_data.action = bpy.data.actions.new("Waddle")
scene.frame_start, scene.frame_end, scene.render.fps = 1, 24, 24
for f in range(1, 26):
    s = math.sin(2 * math.pi * (f - 1) / 24)
    set_world_rot(pbs["leg.L"], X, 25 * s); set_world_rot(pbs["leg.R"], X, -25 * s)
    set_world_rot(pbs["arm.L"], X, -20 * s); set_world_rot(pbs["arm.R"], X, 20 * s)
    for pb in pbs:
        pb.keyframe_insert("rotation_quaternion", frame=f)
scene.frame_set(1)

bpy.ops.wm.save_as_mainfile(filepath=os.path.join(HERE, "grub_clean.blend"))
bpy.ops.object.select_all(action='DESELECT')
grub.select_set(True); rig.select_set(True)
bpy.ops.export_scene.fbx(
    filepath=os.path.join(HERE, "grub_clean.fbx"), use_selection=True,
    object_types={'ARMATURE', 'MESH'}, apply_unit_scale=True, apply_scale_options='FBX_SCALE_ALL',
    bake_space_transform=False, axis_forward='-Z', axis_up='Y', mesh_smooth_type='FACE',
    add_leaf_bones=False, bake_anim=True, bake_anim_use_all_actions=True,
    bake_anim_use_nla_strips=False, path_mode='AUTO')
print("DONE")
