"""Export the living room for Unity, 1:1 with Blender.

The room is shown in Unity as its real geometry with this Blender render (Grub hidden) projected
onto it from the game camera, so every room pixel the camera sees matches Blender exactly. Grub
stays a live 3D character, lit by his own lights.

Writes into the Unity project (UNITY env, default ../../../GrubUnity):
  Assets/Grub/Room/room_plate.png    Eevee render of the empty room at iPhone Pro Max portrait res
  Assets/Grub/Room/room.fbx          room meshes (modifiers applied) + the camera + marker empties
  Assets/Grub/Room/room_scene.json   camera FOV/plate size, Grub's lights (energy, size, colour),
                                     Grub placement, blob-shadow numbers, skin settings
  Assets/Grub/Room/ball.fbx          the beach ball alone (live and kickable in Unity, not in the plate)
  Assets/Grub/Grub/grub_clean.fbx    Grub with all his moves (copied), plus grub_moves.json
and art/3d/renders/unity_ref.png     the same frame WITH Grub, for matching him in Unity.
Blender -b --python export_unity.py
"""
import bpy, json, math, os, shutil
from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__))
UNITY = os.environ.get("UNITY", os.path.normpath(os.path.join(HERE, "..", "..", "..", "GrubUnity")))
ROOM_DIR = os.path.join(UNITY, "Assets", "Grub", "Room"); os.makedirs(ROOM_DIR, exist_ok=True)
GRUB_DIR = os.path.join(UNITY, "Assets", "Grub", "Grub"); os.makedirs(GRUB_DIR, exist_ok=True)
W, H = int(os.environ.get("PLATE_W", "1284")), int(os.environ.get("PLATE_H", "2778"))   # iPhone 12/13 Pro Max

bpy.ops.wm.open_mainfile(filepath=os.path.join(HERE, "room.blend"))
sc = bpy.context.scene
cam = sc.camera
rig = bpy.data.objects["GrubRig"]

# same horizontal field of view as the canon frame (768x1344, vertical fit 36 mm @ 27 mm)
old_aspect = 768 / 1344
h_sensor = cam.data.sensor_height * old_aspect if cam.data.sensor_fit == 'VERTICAL' else cam.data.sensor_width
cam.data.sensor_fit = 'HORIZONTAL'; cam.data.sensor_width = h_sensor
hfov = 2 * math.degrees(math.atan(h_sensor / 2 / cam.data.lens))
sc.render.resolution_x, sc.render.resolution_y = W, H
vfov = 2 * math.degrees(math.atan(math.tan(math.radians(hfov) / 2) * H / W))
print(f"EXPORT camera hfov {hfov:.3f} vfov(plate) {vfov:.3f}")

grub_objs = [o for o in bpy.data.objects if o.name in ("Grub", "GrubShadow")]
ball = bpy.data.objects.get("BeachBall")     # a live, kickable object in Unity: not baked into the plate

def render(path, show_grub):
    for o in grub_objs: o.hide_render = not show_grub
    if ball: ball.hide_render = not show_grub
    sc.render.filepath = path; bpy.ops.render.render(write_still=True)

render(os.path.join(HERE, "renders", "unity_ref.png"), True)
render(os.path.join(ROOM_DIR, "room_plate.png"), False)
for o in grub_objs: o.hide_render = False

# --- markers (positions only; Unity builds rotations from them, so no axis guesswork) ---
markers = []
def marker(name, loc):
    e = bpy.data.objects.new(name, None); sc.collection.objects.link(e); e.location = loc; markers.append(e)
cm = cam.matrix_world
marker("M_Cam", cm.translation)
marker("M_Cam_aim", cm @ Vector((0, 0, -1)))
marker("M_Cam_up", cm @ Vector((0, 1, 0)))
fwd = Vector((0, -1, 0)); fwd.rotate(rig.rotation_euler); fwd.z = 0; fwd.normalize()
marker("M_Grub", rig.location.copy())
marker("M_Grub_fwd", rig.location + fwd)
shm = bpy.data.objects["GrubShadow"].matrix_world
marker("M_Shadow", shm @ Vector((0, 0, 0)))
marker("M_Shadow_x", shm @ Vector((1, 0, 0)))      # one ellipse radius along its local x
marker("M_Shadow_y", shm @ Vector((0, 1, 0)))      # one ellipse radius along its local y
# couch seats: front-edge centre of each seat cushion's top (Grub sits on the edge, legs over it)
dg = bpy.context.evaluated_depsgraph_get()
def wverts(o):
    ev = o.evaluated_get(dg); me = ev.to_mesh(); vs = [ev.matrix_world @ v.co for v in me.vertices]; ev.to_mesh_clear()
    return vs
seats = []
for nm in ("Sofa_Seat1", "Sofa_Seat-1"):
    o = bpy.data.objects.get(nm)
    if not o: continue
    vs = wverts(o)
    lo = Vector((min(v.x for v in vs), min(v.y for v in vs), min(v.z for v in vs)))
    hi = Vector((max(v.x for v in vs), max(v.y for v in vs), max(v.z for v in vs)))
    cx = (lo.x + hi.x) / 2
    mid = [v for v in vs if abs(v.x - cx) < 0.15]
    top = max(v.z for v in mid)
    tag = "R" if nm.endswith("1") and not nm.endswith("-1") else "L"
    marker(f"M_Seat{tag}", Vector((cx, lo.y, top)))
    marker(f"M_Seat{tag}_out", Vector((cx, lo.y - 1, top)))
    seats.append({"name": tag, "edge": [cx, lo.y, top], "width": hi.x - lo.x, "depth": hi.y - lo.y})
    # where he stands on the couch back above this seat: the top of the back frame (the couch sits off the wall
    # so he fits; move_couch.py)
    bf = bpy.data.objects.get("Sofa_BackFrame")
    if bf:
        bvs = [v for v in wverts(bf) if lo.x <= v.x <= hi.x] or wverts(bf)
        btop = max(v.z for v in bvs)
        ridge = [v for v in bvs if v.z > btop - 0.03]
        marker(f"M_Back{tag}", Vector((cx, sum(v.y for v in ridge) / len(ridge), btop)))
# floor obstacles for the rolling ball (positions only, Unity rebuilds directions from them)
marker("M_Corner", Vector((0, 0, 0))); marker("M_WallA_in", Vector((0, -1, 0))); marker("M_WallB_in", Vector((-1, 0, 0)))
sb = bpy.data.objects.get("Sofa_Body")
if sb:
    vs = wverts(sb)
    marker("M_CouchFL", Vector((min(v.x for v in vs), min(v.y for v in vs), 0)))
    marker("M_CouchFR", Vector((max(v.x for v in vs), min(v.y for v in vs), 0)))
plant_r = 0.0
pot = bpy.data.objects.get("Pot_Rim") or bpy.data.objects.get("Pot")
if pot:
    marker("M_Plant", Vector((pot.matrix_world.translation.x, pot.matrix_world.translation.y, 0)))
    plant_r = max(pot.dimensions.x, pot.dimensions.y) / 2
ball_info = None
if ball:
    marker("M_Ball", ball.matrix_world.translation)
    r = max(ball.dimensions) / 2
    def mhex(m):
        b_ = next(n for n in m.node_tree.nodes if n.type == 'BSDF_PRINCIPLED'); c = b_.inputs["Base Color"].default_value
        to_s = lambda x: 12.92 * x if x <= 0.0031308 else 1.055 * x ** (1 / 2.4) - 0.055
        return "#%02X%02X%02X" % tuple(round(255 * max(0, min(1, to_s(c[i])))) for i in range(3))
    ball_info = {"radius": r, "materials": {m.name: mhex(m) for m in ball.data.materials}}
lights = {}
for nm in ("GrubKey", "GrubTop", "GrubRimL", "GrubRimR"):
    L = bpy.data.objects.get(nm)
    if not L: continue
    d = L.matrix_world.to_3x3() @ Vector((0, 0, -1))
    marker(f"M_{nm}", L.matrix_world.translation)
    marker(f"M_{nm}_aim", L.matrix_world.translation + d)
    lights[nm] = {"energy_w": L.data.energy, "size": L.data.size,
                  "spread_deg": math.degrees(getattr(L.data, "spread", math.pi)),
                  "color": list(L.data.color)}

# --- room FBX: static meshes (modifiers applied) + markers ---------------------------------
skip = {"Grub", "GrubShadow", "GrubRig", "BeachBall"}
bpy.ops.object.select_all(action='DESELECT')
room_meshes = [o for o in bpy.data.objects if o.type == 'MESH' and o.name not in skip and o.visible_get()]
for o in room_meshes + markers: o.select_set(True)
bpy.context.view_layer.objects.active = room_meshes[0]
bpy.ops.export_scene.fbx(
    filepath=os.path.join(ROOM_DIR, "room.fbx"), use_selection=True, object_types={'MESH', 'EMPTY'},
    use_mesh_modifiers=True, apply_unit_scale=True, apply_scale_options='FBX_SCALE_ALL',
    bake_space_transform=False, axis_forward='-Z', axis_up='Y', mesh_smooth_type='FACE',
    use_custom_props=False, bake_anim=False, path_mode='STRIP')
shutil.copy2(os.path.join(HERE, "grub_clean.fbx"), os.path.join(GRUB_DIR, "grub_clean.fbx"))
if os.path.exists(os.path.join(HERE, "grub_moves.json")):
    shutil.copy2(os.path.join(HERE, "grub_moves.json"), os.path.join(GRUB_DIR, "grub_moves.json"))
if ball:   # the ball alone, centred on its own origin, unrotated (Unity spins it as it rolls)
    keep_loc, keep_rot = ball.location.copy(), ball.rotation_euler.copy()
    ball.location = (0, 0, 0)
    bpy.ops.object.select_all(action='DESELECT'); ball.select_set(True); bpy.context.view_layer.objects.active = ball
    bpy.ops.export_scene.fbx(
        filepath=os.path.join(ROOM_DIR, "ball.fbx"), use_selection=True, object_types={'MESH'},
        use_mesh_modifiers=True, apply_unit_scale=True, apply_scale_options='FBX_SCALE_ALL',
        bake_space_transform=False, axis_forward='-Z', axis_up='Y', mesh_smooth_type='FACE',
        bake_anim=False, path_mode='STRIP')
    ball.location, ball.rotation_euler = keep_loc, keep_rot

# --- scene description ------------------------------------------------------------------------
def hexcol(m, inp="Base Color"):
    b = next(n for n in m.node_tree.nodes if n.type == 'BSDF_PRINCIPLED')
    c = b.inputs[inp].default_value
    to_s = lambda x: 12.92 * x if x <= 0.0031308 else 1.055 * x ** (1 / 2.4) - 0.055
    return "#%02X%02X%02X" % tuple(round(255 * max(0, min(1, to_s(c[i])))) for i in range(3)), b
skin_hex, skin_b = hexcol(bpy.data.materials["Grub_Skin"])
shadow_m = bpy.data.materials["GrubShadow"]
shadow_tint = next(n for n in shadow_m.node_tree.nodes if n.type == 'BSDF_TRANSPARENT' and tuple(n.inputs[0].default_value)[:3] != (1, 1, 1))
sh = bpy.data.objects["GrubShadow"]
info = {
    "plate": {"width": W, "height": H, "hfov_deg": hfov, "vfov_deg": vfov,
              "near": cam.data.clip_start, "far": cam.data.clip_end},
    "grub": {"scale": rig.scale.x},
    "lights": lights,
    "skin": {"base_hex": skin_hex, "roughness": skin_b.inputs['Roughness'].default_value,
             "specular": skin_b.inputs['Specular IOR Level'].default_value,
             "sheen": skin_b.inputs['Sheen Weight'].default_value,
             "eye_hex": hexcol(bpy.data.materials["Grub_Eye"])[0],
             "shine_hex": hexcol(bpy.data.materials["Grub_Shine"])[0]},
    "blob_shadow": {"local_x": sh.location.x, "local_y_forward_is_neg": sh.location.y,
                    "radius_x": sh.scale.x, "radius_y": sh.scale.y,
                    "soft": 0.45, "tint_linear": list(shadow_tint.inputs[0].default_value)[:3]},
    "seats": seats,
    "plant_radius": plant_r,
    "ball": ball_info,
    "world_ambient": {"hex": "#F6E7D6", "strength": sc.world.node_tree.nodes["Background"].inputs[1].default_value},
}
json.dump(info, open(os.path.join(ROOM_DIR, "room_scene.json"), "w"), indent=1)
print("EXPORT done ->", ROOM_DIR, "| meshes", len(room_meshes), "| lights", list(lights))
