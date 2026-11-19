"""Render Grub's Walk cycle in the living room: he walks toward the camera at his stride speed
(so the planted foot doesn't slide). His own lights and blob shadow travel with him.
Blender -b --python render_walk.py  ->  renders/walk/####.png  (then ffmpeg → walk.mp4 / walk.gif)
Env: CYCLES (default 3), MODE=inplace to keep him on the spot."""
import bpy, math, os
from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__))
bpy.ops.wm.open_mainfile(filepath=os.path.join(HERE, "room.blend"))
sc = bpy.context.scene
rig = bpy.data.objects["GrubRig"]
walk = bpy.data.actions.get("Walk")
if walk is None:   # room.blend only carries Grub's objects; pull the action from the Grub file
    with bpy.data.libraries.load(os.path.join(HERE, "grub_clean.blend")) as (src, dst):
        dst.actions = ["Walk"]
    walk = dst.actions[0]
CYC = int(os.environ.get("CYCLES", "3"))
N = 24 * CYC

# loop the cycle with an NLA strip
ad = rig.animation_data or rig.animation_data_create()
ad.action = None
for tr in list(ad.nla_tracks): ad.nla_tracks.remove(tr)
strip = ad.nla_tracks.new().strips.new("Walk", 1, walk)
strip.action_frame_start, strip.action_frame_end = 1, 25
strip.repeat = CYC

# mover: carries the rig and Grub's own lights
mover = bpy.data.objects.new("GrubMover", None); sc.collection.objects.link(mover)
mover.location = rig.location.copy()
bpy.context.view_layer.update()
for ob in [rig] + [o for o in bpy.data.objects if o.name in ("GrubKey", "GrubTop", "GrubRimL", "GrubRimR")]:
    mw = ob.matrix_world.copy(); ob.parent = mover; ob.matrix_world = mw
if os.environ.get("MODE", "walk") == "walk":
    scale = rig.scale.x
    stride = 2 * 2 * 0.17 * math.sin(math.radians(28)) * scale      # two steps per cycle
    fwd = Vector((0, -1, 0)); fwd.rotate(rig.rotation_euler); fwd.z = 0; fwd.normalize()
    mover.keyframe_insert("location", frame=1)
    mover.location = mover.location + fwd * stride * CYC
    mover.keyframe_insert("location", frame=N + 1)
    for fc in getattr(mover.animation_data.action, "fcurves", []):
        for k in fc.keyframe_points: k.interpolation = 'LINEAR'
    try:  # Blender 5 slotted actions
        for lay in mover.animation_data.action.layers:
            for st in lay.strips:
                for cb in st.channelbags:
                    for fc in cb.fcurves:
                        for k in fc.keyframe_points: k.interpolation = 'LINEAR'
    except AttributeError:
        pass

sc.frame_start, sc.frame_end, sc.render.fps = 1, N, 24
out = os.path.join(HERE, "renders", "walk"); os.makedirs(out, exist_ok=True)
sc.render.filepath = os.path.join(out, "")
sc.render.image_settings.file_format = 'PNG'
bpy.ops.render.render(animation=True)
print("WALK FRAMES", N, "->", out)
