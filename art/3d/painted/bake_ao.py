"""Bake ambient occlusion into Grub's vertex colours (color attribute "AO"), then re-export grub_clean.fbx.
Painted-look B2 (board grub-mechanics #658): darkening under the body, between the legs and where
the limbs meet the body. Cycles, 64 samples, AO distance 0.3 x Grub's height, rest pose.
GrubPainted reads it from the vertex colour (white = open, dark = occluded).
Blender -b --python bake_ao.py
"""
import bpy, os

HERE = os.path.dirname(os.path.abspath(__file__))
D3 = os.path.normpath(os.path.join(HERE, ".."))
bpy.ops.wm.open_mainfile(filepath=os.path.join(D3, "grub_clean.blend"))
sc = bpy.context.scene
rig, grub = bpy.data.objects["GrubRig"], bpy.data.objects["Grub"]

# rest pose for the bake
keep_action = rig.animation_data.action if rig.animation_data else None
if rig.animation_data: rig.animation_data.action = None
for pb in rig.pose.bones:
    pb.location = (0, 0, 0); pb.rotation_mode = 'QUATERNION'; pb.rotation_quaternion = (1, 0, 0, 0); pb.scale = (1, 1, 1)
bpy.context.view_layer.update()

me = grub.data
for a in list(me.color_attributes):
    if a.name == "AO": me.color_attributes.remove(a)
ca = me.color_attributes.new("AO", 'BYTE_COLOR', 'POINT')
me.color_attributes.active_color = ca

# the bake needs a material on every slot; AO ignores the shader, so the existing ones are fine
sc.render.engine = 'CYCLES'
sc.cycles.samples = 64
sc.cycles.device = 'CPU'
height = grub.dimensions.z if grub.dimensions.z > 0 else 1.0
if sc.world is None: sc.world = bpy.data.worlds.new("W")
sc.world.light_settings.distance = 0.3 * height
bake = sc.render.bake
bake.target = 'VERTEX_COLORS'
bpy.ops.object.select_all(action='DESELECT')
grub.select_set(True); bpy.context.view_layer.objects.active = grub
bpy.ops.object.bake(type='AO', target='VERTEX_COLORS')

vals = [d.color[0] for d in ca.data]
print("AO baked: %d verts, min %.3f mean %.3f" % (len(vals), min(vals), sum(vals) / len(vals)))

if keep_action: rig.animation_data.action = keep_action
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(D3, "grub_clean.blend"))
bpy.ops.object.select_all(action='DESELECT')
grub.select_set(True); rig.select_set(True); bpy.context.view_layer.objects.active = rig
bpy.ops.export_scene.fbx(
    filepath=os.path.join(D3, "grub_clean.fbx"), use_selection=True,
    object_types={'ARMATURE', 'MESH'}, apply_unit_scale=True, apply_scale_options='FBX_SCALE_ALL',
    bake_space_transform=False, axis_forward='-Z', axis_up='Y', mesh_smooth_type='FACE',
    add_leaf_bones=False, bake_anim=True, bake_anim_use_all_actions=True,
    bake_anim_use_nla_strips=False, path_mode='AUTO', colors_type='LINEAR')
print("EXPORTED with AO colours")
