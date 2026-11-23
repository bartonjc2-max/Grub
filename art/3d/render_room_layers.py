"""Room elements as their own layers (Jesse 2026-11-22: "I need all the room elements as their own elements.
Including the pictures."). The room is a painted plate; to move a piece of it (shake the pot, knock a picture
crooked, open the door, squash the couch) Unity needs the room WITHOUT that piece behind it, plus a mask of
where the piece is. With the export_unity.py camera and resolution this renders:
  renders/room_plate_bare.png        the room with every element removed (clean wall and floor behind them)
  renders/elem_<element>.png         the bare room with only that element in it (its shadows included)
  renders/mask_<element>_raw.png     alpha = where that element is visible (everything else held out)
Then: paint_plate_d2.py + warm_plate.py on the bare plate, and build_room_layers.py (masks + seam fit).
Blender -b --python render_room_layers.py

Environment (all optional; with none set this behaves exactly as before and writes into renders/):
  OUT_DIR=<folder>     write every output there instead of renders/
  ROOM_BLEND=<file>    open this instead of room.blend (never saved either way)
  RUG=layer            UNBAKED RUG: the rug (objects Rug*) is hidden in the bare render, in every element render
                       and in the masks, and these are written as well:
                         room_plate_bare_rug.png   the bare room WITH the rug (source of the rug's painted pixels)
                         elem_<element>_rug.png    each element alone WITH the rug: its own pixels are taken from
                                                   this (the canon rug throws a lot of warm light on the couch),
                                                   its floor shadow from the no-rug elem_<element>.png
                         mask_rug_raw.png          alpha = the rug's silhouette (elements hidden, room held out)
                         room_full.png             every element and the canon rug (what a store rug's render.png
                                                   is for its rug: make_rug_layer.py rebuilds the canon layer from it)
                         room_full_norug.png       every element, no rug (store_assets/make_rug_layer.py divides
                                                   the elements' floor shadows out of a store rug render with it)
"""
import bpy, os

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.environ.get("OUT_DIR") or os.path.join(HERE, "renders")
os.makedirs(OUT, exist_ok=True)
RUG_LAYER = os.environ.get("RUG", "") == "layer"
IS_RUG = lambda n: n == "Rug" or n.startswith("Rug_")
W, H = int(os.environ.get("PLATE_W", "1284")), int(os.environ.get("PLATE_H", "2778"))

# element -> object-name test (order = back to front; the shader composites them in this order)
ELEMENTS = {
    "door":  lambda n: n in ("Door", "Door_Panel0", "Door_Panel1", "Door_Knob"),   # the frame stays on the wall
    "picL":  lambda n: n.startswith("PicL_"),
    "picR":  lambda n: n.startswith("PicR_"),
    "couch": lambda n: n.startswith("Sofa_"),
    "plant": lambda n: n.startswith(("Leaf", "Pot")) or n in ("Stem", "Soil"),
}

bpy.ops.wm.open_mainfile(filepath=os.environ.get("ROOM_BLEND") or os.path.join(HERE, "room.blend"))
sc = bpy.context.scene
cam = sc.camera
old_aspect = 768 / 1344                       # same camera fit as export_unity.py
h_sensor = cam.data.sensor_height * old_aspect if cam.data.sensor_fit == 'VERTICAL' else cam.data.sensor_width
cam.data.sensor_fit = 'HORIZONTAL'; cam.data.sensor_width = h_sensor
sc.render.resolution_x, sc.render.resolution_y, sc.render.resolution_percentage = W, H, 100
for o in bpy.data.objects:
    if o.name in ("Grub", "GrubShadow", "BeachBall"): o.hide_render = True
rug = [o for o in bpy.data.objects if o.type == 'MESH' and IS_RUG(o.name)]
if RUG_LAYER:
    print("RUG (own layer, hidden from the room renders)", [o.name for o in rug])
    for o in rug: o.hide_render = True

meshes = [o for o in bpy.data.objects if o.type == 'MESH' and not o.hide_render]
groups = {k: [o for o in meshes if f(o.name)] for k, f in ELEMENTS.items()}
for k, g in groups.items(): print("ELEMENT", k, [o.name for o in g])
in_any = {o for g in groups.values() for o in g}

# camera distance of each element (mean over its vertices): the shader stacks the layers far to near, so a
# shaken pot slides BEHIND the nearer couch instead of over it
import json
cpos = cam.matrix_world.translation
depth = {}
for k, g in groups.items():
    vs = [o.matrix_world @ v.co for o in g for v in o.data.vertices]
    depth[k] = sum((v - cpos).length for v in vs) / max(1, len(vs))
json.dump(depth, open(os.path.join(OUT, "room_layers_depth.json"), "w"), indent=1)
print("DEPTH", {k: round(v, 2) for k, v in depth.items()})
if os.environ.get("DEPTH_ONLY"): raise SystemExit

# 0. unbaked rug only: the room with every element and no rug, and the bare room with the rug
if RUG_LAYER:
    sc.render.filepath = os.path.join(OUT, "room_full_norug.png")
    bpy.ops.render.render(write_still=True)
    for o in rug: o.hide_render = False
    sc.render.filepath = os.path.join(OUT, "room_full.png")
    bpy.ops.render.render(write_still=True)
    for o in rug: o.hide_render = True
    for o in in_any: o.hide_render = True
    for o in rug: o.hide_render = False
    sc.render.filepath = os.path.join(OUT, "room_plate_bare_rug.png")
    bpy.ops.render.render(write_still=True)
    for o in rug: o.hide_render = True
    for o in in_any: o.hide_render = False

# 1. bare room: every element removed entirely (no shadow, no occlusion). Keeping their shadows left dark
#    picture / couch / door shaped patches on the wall that showed as dirt when an element moved. Unity uses
#    this only in a band round each element; everywhere else it keeps the full plate and its real shadows.
for o in in_any: o.hide_render = True
sc.render.filepath = os.path.join(OUT, "room_plate_bare.png")
bpy.ops.render.render(write_still=True)
for o in in_any: o.hide_render = False

# 1b. each element alone in the bare room (the other elements removed), with its own shadows: painted
#     separately, these rebuild the room plate as bare + elements, so a moved element reveals exactly the wall
#     that the plate is made of (no ghost of its old shading)
if not os.environ.get("NO_ELEMENTS"):
    for k, g in groups.items():
        for o in in_any: o.hide_render = o not in g
        sc.render.filepath = os.path.join(OUT, f"elem_{k}.png")
        bpy.ops.render.render(write_still=True)
        if RUG_LAYER:        # the same with the canon rug down: the element's OWN pixels keep the approved look
            for o in rug: o.hide_render = False
            sc.render.filepath = os.path.join(OUT, f"elem_{k}_rug.png")
            bpy.ops.render.render(write_still=True)
            for o in rug: o.hide_render = True
    for o in in_any: o.hide_render = False

# 2. one coverage mask per element: everything else held out, transparent film
sc.render.film_transparent = True
sc.render.image_settings.file_format = 'PNG'; sc.render.image_settings.color_mode = 'RGBA'
for k, g in groups.items():
    for o in meshes: o.is_holdout = o not in g
    sc.render.filepath = os.path.join(OUT, f"mask_{k}_raw.png")
    bpy.ops.render.render(write_still=True)
for o in meshes: o.is_holdout = False
# 2b. unbaked rug only: the rug's own silhouette. The elements are hidden, not held out: they are drawn over
#     the rug at runtime and can move, so the rug layer must be whole underneath them.
if RUG_LAYER:
    for o in in_any: o.hide_render = True
    for o in rug: o.hide_render = False
    for o in meshes: o.is_holdout = True
    sc.render.filepath = os.path.join(OUT, "mask_rug_raw.png")
    bpy.ops.render.render(write_still=True)
    for o in meshes: o.is_holdout = False
    for o in in_any: o.hide_render = False
    for o in rug: o.hide_render = True
print("ROOM LAYERS done")
