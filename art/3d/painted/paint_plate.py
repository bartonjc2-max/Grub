"""Painted room plate (painted-look D, board grub-mechanics #658): the Unity room plate through
Blender's compositor Kuwahara (anisotropic, size 6, uniformity 4, sharpness 0.5), then the darks
nudged toward #6E7FA0 at 15%. Writes room_plate_painted.png next to room_plate.png (the original
stays, so the two can be switched).
Blender -b --python paint_plate.py
"""
import bpy, os

HERE = os.path.dirname(os.path.abspath(__file__))
ROOM = os.path.normpath(os.path.join(HERE, "..", "..", "..", "..", "GrubUnity", "Assets", "Grub", "Room"))
SRC = os.environ.get("PLATE_SRC", os.path.join(ROOM, "room_plate.png"))
DST = os.environ.get("PLATE_DST", os.path.join(ROOM, "room_plate_painted.png"))
KSIZE = int(os.environ.get("KSIZE", "6"))

sc = bpy.context.scene
img = bpy.data.images.load(SRC)
W, H = img.size
sc.render.resolution_x, sc.render.resolution_y, sc.render.resolution_percentage = W, H, 100
sc.render.image_settings.file_format = 'PNG'
sc.render.image_settings.color_mode = 'RGB'
sc.view_settings.view_transform = 'Standard'

tree = bpy.data.node_groups.new("PaintPlate", 'CompositorNodeTree')
sc.compositing_node_group = tree
N = tree.nodes
src = N.new('CompositorNodeImage'); src.image = img
kw = N.new('CompositorNodeKuwahara')


def set_in(node, names, val):
    for n in names:
        if n in node.inputs: node.inputs[n].default_value = val; return True
        if hasattr(node, n.lower()): setattr(node, n.lower(), val); return True
    return False


for prop, val in (("variation", 'ANISOTROPIC'),):
    try: setattr(kw, prop, val)
    except Exception: pass
if "Type" in kw.inputs:
    try: kw.inputs["Type"].default_value = 'Anisotropic'
    except Exception: pass
set_in(kw, ["Size"], KSIZE); set_in(kw, ["Uniformity"], 4); set_in(kw, ["Sharpness"], 0.5)
print("KUWAHARA inputs:", [(i.name, getattr(i, "default_value", None)) for i in kw.inputs])

# darks toward #6E7FA0 at 15%: mix(colour, tint, 0.15 * (1 - luminance))
sep = N.new('CompositorNodeRGBToBW')
inv = N.new('ShaderNodeMath'); inv.operation = 'SUBTRACT'; inv.inputs[0].default_value = 1.0
mul = N.new('ShaderNodeMath'); mul.operation = 'MULTIPLY'; mul.inputs[1].default_value = 0.15
mix = N.new('ShaderNodeMix'); mix.data_type = 'RGBA'; mix.blend_type = 'MIX'
tint = (0x6E / 255, 0x7F / 255, 0xA0 / 255)
lin = lambda c: c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4
mix.inputs[7].default_value = (*[lin(c) for c in tint], 1.0)
out = N.new('NodeGroupOutput')
tree.interface.new_socket("Image", in_out='OUTPUT', socket_type='NodeSocketColor')

L = tree.links
L.new(src.outputs[0], kw.inputs[0])
L.new(kw.outputs[0], sep.inputs[0])
L.new(sep.outputs[0], inv.inputs[1])
L.new(inv.outputs[0], mul.inputs[0])
L.new(mul.outputs[0], mix.inputs[0])
L.new(kw.outputs[0], mix.inputs[6])
L.new(mix.outputs[2], out.inputs[0])

# nothing to render but the compositor: an empty scene, cheap engine
sc.render.engine = 'BLENDER_WORKBENCH'
cam = bpy.data.objects.get("Camera")
if cam is None:
    cd = bpy.data.cameras.new("C"); cam = bpy.data.objects.new("C", cd); sc.collection.objects.link(cam)
sc.camera = cam
sc.render.use_compositing = True
sc.render.filepath = DST
bpy.ops.render.render(write_still=True)
print("PAINTED PLATE ->", DST)
