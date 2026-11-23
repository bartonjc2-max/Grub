"""Store asset library: alternate rugs, wall pictures, plants and couches for the Grub room.

Opens ../room.blend (NEVER saves it), and for every variant:
  1. builds the variant procedurally where the canon item sits,
  2. hides the canon item it replaces (render only),
  3. renders the room from the canon camera at the plate resolution  -> <category>/<id>/render.png
  4. renders a coverage mask of just the variant (everything else held out, transparent film, the same
     approach as render_room_layers.py)                               -> <category>/<id>/mask.png
  5. writes only the variant's objects                               -> <category>/<id>/<id>.blend
  6. writes <category>/<id>/meta.json, then removes the variant again.
Then run make_catalog.py (plain python3 + PIL) for catalog.json and contact_sheet.png.

Object names use the canon prefixes (Rug*, PicL_*, Sofa_*, Pot*/Leaf*/Stem/Soil) so that, once a variant is
appended into a copy of room.blend in place of the canon objects, render_room_layers.py groups it unchanged.

  /Applications/Blender.app/Contents/MacOS/Blender -b --python build_store_assets.py
  ONLY=rug_checker,pic_moon ...   build just these ids        CATEGORY=rugs ...   just one category
  PLATE_W / PLATE_H              override the 1284 x 2778 plate (e.g. 321 x 694 for a quick look)

Batch 2 lives in build_store_assets_b2.py, which imports this file for its helpers and its run() loop. Run as
a script this file builds batch 1 only, exactly as before.
"""
import bpy, bmesh, json, math, os, time
from mathutils import Quaternion, Vector

HERE = os.path.dirname(os.path.abspath(__file__))
D3 = os.path.dirname(HERE)
W, H = int(os.environ.get("PLATE_W", "1284")), int(os.environ.get("PLATE_H", "2778"))
ONLY = [s for s in os.environ.get("ONLY", "").split(",") if s]
CATEGORY = os.environ.get("CATEGORY", "")

bpy.ops.wm.open_mainfile(filepath=os.path.join(D3, "room.blend"))
sc = bpy.context.scene
COL = sc.collection
cam = sc.camera
old_aspect = 768 / 1344                       # same camera fit as render_room_layers.py / export_unity.py
h_sensor = cam.data.sensor_height * old_aspect if cam.data.sensor_fit == 'VERTICAL' else cam.data.sensor_width
cam.data.sensor_fit = 'HORIZONTAL'; cam.data.sensor_width = h_sensor
sc.render.resolution_x, sc.render.resolution_y, sc.render.resolution_percentage = W, H, 100
for o in bpy.data.objects:
    if o.name in ("Grub", "GrubShadow", "BeachBall"): o.hide_render = True

# canon items a variant can replace (the same name tests as render_room_layers.py, plus the rug)
CANON_TEST = {
    "rug":   lambda n: n in ("Rug", "Rug_Border"),
    "picL":  lambda n: n.startswith("PicL_"),
    "picR":  lambda n: n.startswith("PicR_"),            # only hidden for the batch 2 render_picR.png pass
    "couch": lambda n: n.startswith("Sofa_"),
    "plant": lambda n: n.startswith(("Leaf", "Pot")) or n in ("Stem", "Soil"),
}
CANON = {k: [o for o in bpy.data.objects if o.type == 'MESH' and f(o.name)] for k, f in CANON_TEST.items()}
for k, g in CANON.items():
    print("CANON", k, [o.name for o in g])
    for o in g: o.name = "CANON_" + o.name       # in memory only: frees the canon names for the variants

# ------------------------------------------------------------------ helpers
CUR, MATS, VID = [], {}, [""]

def lin(h):
    h = h.lstrip('#'); c = [int(h[i:i + 2], 16) / 255 for i in (0, 2, 4)]
    return [x / 12.92 if x <= 0.04045 else ((x + 0.055) / 1.055) ** 2.4 for x in c] + [1]

def mat(key, hexc, rough=0.9):
    if key in MATS: return MATS[key]
    m = bpy.data.materials.new(f"Store_{VID[0]}_{key}"); m.use_nodes = True
    b = next(n for n in m.node_tree.nodes if n.type == 'BSDF_PRINCIPLED')
    b.inputs['Base Color'].default_value = lin(hexc); b.inputs['Roughness'].default_value = rough
    m.diffuse_color = lin(hexc); MATS[key] = m; return m

def new_ob(name, me, m, loc=(0, 0, 0), rot=(0, 0, 0), smooth=True):
    if smooth:
        for p in me.polygons: p.use_smooth = True
    me.materials.append(m)
    ob = bpy.data.objects.new(name, me); COL.objects.link(ob)
    ob.location = loc; ob.rotation_euler = rot; CUR.append(ob); return ob

def rbox(name, size, loc, m, bevel=0.08, seg=6, rot=(0, 0, 0)):
    """Rounded box (as build_room.py): cube with a bevel modifier."""
    me = bpy.data.meshes.new(name); bm = bmesh.new(); bmesh.ops.create_cube(bm, size=1.0)
    for v in bm.verts: v.co = Vector((v.co.x * size[0], v.co.y * size[1], v.co.z * size[2]))
    bm.to_mesh(me); bm.free()
    ob = new_ob(name, me, m, loc, rot)
    md = ob.modifiers.new("Bevel", 'BEVEL'); md.width = min(bevel, min(size) / 2 - 1e-3)
    md.segments = seg; md.harden_normals = True; md.limit_method = 'NONE'; return ob

def pillow(name, size, loc, m, crease=0.6, rot=(0, 0, 0)):
    """Puffy cushion (as build_room.py): creased cube + subdivision."""
    me = bpy.data.meshes.new(name); bm = bmesh.new(); bmesh.ops.create_cube(bm, size=1.0)
    for v in bm.verts: v.co = Vector((v.co.x * size[0], v.co.y * size[1], v.co.z * size[2]))
    cl = bm.edges.layers.float.get('crease_edge') or bm.edges.layers.float.new('crease_edge')
    for e in bm.edges: e[cl] = crease
    bm.to_mesh(me); bm.free()
    ob = new_ob(name, me, m, loc, rot)
    sd = ob.modifiers.new("Subsurf", 'SUBSURF'); sd.levels = 3; sd.render_levels = 3; return ob

def sphere(name, r, loc, m, scale=(1, 1, 1), rot=(0, 0, 0), seg=32, rings=16, stretch=0.0):
    """UV sphere; stretch > 0 lifts the upper half by that much (a capsule standing on its local z)."""
    me = bpy.data.meshes.new(name); bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=seg, v_segments=rings, radius=r)
    if stretch:
        for v in bm.verts:
            if v.co.z > 1e-6: v.co.z += stretch
    bm.to_mesh(me); bm.free()
    ob = new_ob(name, me, m, loc, rot); ob.scale = scale; return ob

def cyl(name, r1, r2, depth, loc, m, seg=48, rot=(0, 0, 0), bevel=0.03):
    """Cone frustum, r1 at the bottom; soft rim bevel as build_room.py (bevel=0 for none)."""
    me = bpy.data.meshes.new(name); bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, segments=seg, radius1=r1, radius2=r2, depth=depth)
    bm.to_mesh(me); bm.free()
    ob = new_ob(name, me, m, loc, rot)
    if bevel:
        md = ob.modifiers.new("Bevel", 'BEVEL'); md.width = min(bevel, depth / 3, min(r1, r2) * 0.9); md.segments = 4
        md.harden_normals = True; md.limit_method = 'ANGLE'
    return ob

def poly(name, pts3, m, extrude=None, bevel=0.0):
    """One n-gon through pts3 (world coords), optionally extruded by a vector into a slab."""
    me = bpy.data.meshes.new(name); bm = bmesh.new()
    f = bm.faces.new([bm.verts.new(p) for p in pts3])
    if extrude:
        ret = bmesh.ops.extrude_face_region(bm, geom=[f])
        bmesh.ops.translate(bm, verts=[e for e in ret["geom"] if isinstance(e, bmesh.types.BMVert)], vec=extrude)
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    bm.to_mesh(me); bm.free()
    ob = new_ob(name, me, m, smooth=bool(bevel))
    if bevel:
        md = ob.modifiers.new("soft edge", 'BEVEL'); md.width = bevel; md.segments = 3
        md.harden_normals = True; md.limit_method = 'ANGLE'
    return ob

def faces(name, loops3, m):
    """Several flat faces in one mesh (stripes, checks, rings cut into quads)."""
    me = bpy.data.meshes.new(name); bm = bmesh.new()
    for loop in loops3: bm.faces.new([bm.verts.new(p) for p in loop])
    bm.to_mesh(me); bm.free()
    return new_ob(name, me, m, smooth=False)

# 2D outlines (counter-clockwise)
def ellipse(cx, cy, a, b, n=96, a0=0.0, a1=2 * math.pi):
    full = abs(a1 - a0 - 2 * math.pi) < 1e-6
    k = n if full else n + 1
    return [(cx + math.cos(a0 + (a1 - a0) * i / n) * a, cy + math.sin(a0 + (a1 - a0) * i / n) * b) for i in range(k)]

def roundrect(cx, cy, w, h, r, n=10, ang=0.0):
    pts = []
    for qx, qy, s in ((1, 1, 0), (-1, 1, 90), (-1, -1, 180), (1, -1, 270)):
        for i in range(n + 1):
            t = math.radians(s + 90 * i / n)
            pts.append((qx * (w / 2 - r) + math.cos(t) * r, qy * (h / 2 - r) + math.sin(t) * r))
    c, s_ = math.cos(ang), math.sin(ang)
    return [(cx + x * c - y * s_, cy + x * s_ + y * c) for x, y in pts]

def rect(cx, cy, w, h):
    return [(cx - w / 2, cy - h / 2), (cx + w / 2, cy - h / 2), (cx + w / 2, cy + h / 2), (cx - w / 2, cy + h / 2)]

# ------------------------------------------------------------------ rugs (canon: 4.4 x 3.0 oval at -2.9, -3.3)
RC = (-2.9, -3.3); RT = 0.010; RZ = RT + 0.0008        # centre, pile thickness, height of the flat inlays

def floor_pts(pts, z): return [(x, y, z) for x, y in pts]
def rug_base(pts, m): return poly("Rug", floor_pts(pts, 0.0), m, extrude=(0, 0, RT), bevel=RT * 0.45)
def rug_ring(name, outer, inner, m):
    n = len(outer)
    return faces(name, [floor_pts((outer[k], outer[(k + 1) % n], inner[(k + 1) % n], inner[k]), RZ) for k in range(n)], m)

def rug_sage_round():
    rug_base(ellipse(*RC, 1.5, 1.5, 160), mat("pile", "#A8C3A0", 1.0))
    rug_ring("Rug_Border", ellipse(*RC, 1.34, 1.34, 160), ellipse(*RC, 1.25, 1.25, 160), mat("border", "#F7E8D8", 1.0))
    rug_ring("Rug_Border2", ellipse(*RC, 0.62, 0.62, 120), ellipse(*RC, 0.57, 0.57, 120), mat("border", "#F7E8D8", 1.0))

def rug_striped_rect():
    rug_base(roundrect(*RC, 4.2, 2.8, 0.22), mat("pile", "#F7E8D8", 1.0))
    ys = [-1.05, -0.525, 0.0, 0.525, 1.05]
    faces("Rug_StripesA", [floor_pts(rect(RC[0], RC[1] + y, 3.84, 0.27), RZ) for y in ys[0::2]], mat("stripeA", "#D98A72", 1.0))
    faces("Rug_StripesB", [floor_pts(rect(RC[0], RC[1] + y, 3.84, 0.27), RZ) for y in ys[1::2]], mat("stripeB", "#E8B960", 1.0))

def rug_checker():
    rug_base(roundrect(*RC, 4.0, 2.8, 0.18), mat("pile", "#F7E8D8", 1.0))
    c = 0.6
    cells = [floor_pts(rect(RC[0] + (i - 2.5) * c, RC[1] + (j - 1.5) * c, c, c), RZ)
             for i in range(6) for j in range(4) if (i + j) % 2 == 0]
    faces("Rug_Checks", cells, mat("check", "#9DB8C7", 1.0))

def rug_scalloped():
    a, b, n, bumps = 2.1, 1.43, 432, 18
    pts = []
    for i in range(n):
        t = 2 * math.pi * i / n; s = 0.93 + 0.07 * abs(math.sin(bumps / 2 * t))
        pts.append((RC[0] + math.cos(t) * a * s, RC[1] + math.sin(t) * b * s))
    rug_base(pts, mat("pile", "#EDB5AE", 1.0))
    rug_ring("Rug_Border", ellipse(*RC, a - 0.36, b - 0.36, 200), ellipse(*RC, a - 0.43, b - 0.43, 200), mat("border", "#F7E8D8", 1.0))

# ------------------------------------------------------------------ pictures (canon PicL: 0.68 x 0.84 at x -4.0, z 2.05)
PX, PZ, PW, PH = -4.0, 2.05, 0.68, 0.84
HW, HH = (PW - 0.12) / 2, (PH - 0.12) / 2            # half canvas

def pic_frame(frame_hex, canvas_hex):
    rbox("PicL_Frame", (PW, 0.06, PH), (PX, -0.03, PZ), mat("frame", frame_hex, 0.6), 0.02, 3)
    rbox("PicL_Canvas", (PW - 0.12, 0.02, PH - 0.12), (PX, -0.065, PZ), mat("canvas", canvas_hex, 0.9), 0.003, 1)

def art(name, pts, m, layer):
    """Flat shape on the canvas; pts are (u, v) from the canvas centre, layer 1.. stacks toward the room."""
    y = -0.0755 - 0.002 * layer
    return poly("PicL_" + name, [(PX + u, y, PZ + v) for u, v in pts], m)

def hill(top, n=40):
    return [(HW, -HH)] + [(HW - 2 * HW * i / n, top(-1 + 2 * (1 - i / n))) for i in range(n + 1)] + [(-HW, -HH)]

def pic_sunset_hills():
    pic_frame("#C8956A", "#F9D2A8")
    art("Sun", ellipse(0.05, 0.03, 0.125, 0.125, 64), mat("sun", "#F0875A"), 1)
    art("HillBack", hill(lambda t: -0.07 + 0.075 * math.sin(2.2 * t + 0.6)), mat("hillback", "#D79AA5"), 2)
    art("HillFront", hill(lambda t: -0.20 + 0.06 * math.cos(2.0 * t + 0.9)), mat("hillfront", "#8FB59A"), 3)

def pic_flower():
    pic_frame("#9DB59A", "#F7ECDD")
    g = mat("green", "#7FAE7A")
    art("Stem", rect(0, -0.12, 0.026, 0.36), g, 1)
    for k, sgn in enumerate((-1, 1)):
        art(f"Leaf{k}", roundrect(sgn * 0.075, -0.15 + 0.03 * k, 0.17, 0.075, 0.036, 8, sgn * math.radians(32)), g, 1)
    for k in range(6):
        t = math.radians(60 * k + 30)
        art(f"Petal{k}", ellipse(0.088 * math.cos(t), 0.11 + 0.088 * math.sin(t), 0.066, 0.066, 40), mat("petal", "#EE9BA8"), 2)
    art("Centre", ellipse(0, 0.11, 0.056, 0.056, 40), mat("centre", "#F0C05A"), 3)

def pic_abstract():
    pic_frame("#B8794F", "#F3E7D6")
    art("Arch", ellipse(-0.05, -HH, 0.20, 0.24, 48, 0, math.pi), mat("terracotta", "#D98A72"), 1)
    art("Circle", ellipse(0.12, 0.17, 0.10, 0.10, 48), mat("sage", "#A8C3A0"), 1)
    art("Bar", roundrect(-0.08, 0.13, 0.30, 0.07, 0.034, 8, math.radians(32)), mat("mustard", "#E8B960"), 2)
    art("Dot", ellipse(0.16, -0.11, 0.05, 0.05, 32), mat("blue", "#7F9FB5"), 2)

def pic_moon():
    pic_frame("#F5E9DA", "#5B6F95")
    cream = mat("cream", "#F8EBC8")
    art("Moon", ellipse(0.0, 0.08, 0.135, 0.135, 64), cream, 1)
    art("MoonBite", ellipse(0.062, 0.118, 0.112, 0.112, 64), mat("canvas", "#5B6F95"), 2)
    for k, (u, v) in enumerate(((-0.20, 0.27), (-0.15, -0.06), (0.20, -0.09), (0.21, 0.29), (-0.04, 0.30), (-0.22, 0.11))):
        art(f"Star{k}", ellipse(u, v, 0.014, 0.014, 16), cream, 3)
    art("Cloud", hill(lambda t: -0.24 + 0.035 * math.sin(5.0 * t)), mat("cloud", "#8E9CC0"), 3)

# ------------------------------------------------------------------ plants (canon pot at -1.25, -0.80; top of leaves 2.28 m)
PPX, PPY = -1.25, -0.80

def pot(r_bot, r_top, h, hexc, z0=0.0, rim=0.045, soil_hex="#6B4A36"):
    m = mat("pot", hexc, 0.7)
    cyl("Pot", r_bot, r_top, h, (PPX, PPY, z0 + h / 2), m)
    cyl("Pot_Rim", r_top + rim, r_top + rim, 0.09, (PPX, PPY, z0 + h), m)
    cyl("Soil", r_top - 0.01, r_top - 0.01, 0.02, (PPX, PPY, z0 + h + 0.05), mat("soil", soil_hex, 0.9), bevel=0)
    return z0 + h + 0.05                                 # soil height

def aim(ob, d, axis='Z', up='Y'):
    ob.rotation_mode = 'QUATERNION'; ob.rotation_quaternion = Vector(d).to_track_quat(axis, up)

def plant_snake():
    z = pot(0.30, 0.40, 0.60, "#F1DFC9")
    blades = [  # yaw deg, lean deg, root radius, length
        (0, 5, 0.00, 1.52), (40, 12, 0.14, 1.20), (95, 9, 0.12, 1.38), (150, 14, 0.16, 1.05), (200, 8, 0.10, 1.44),
        (250, 15, 0.17, 0.95), (300, 10, 0.13, 1.30), (340, 16, 0.18, 0.88), (270, 6, 0.06, 1.12)]
    for k, (yaw, lean, rr, L) in enumerate(blades):
        yr, lr = math.radians(yaw), math.radians(lean)
        d = Vector((math.cos(yr) * math.sin(lr), math.sin(yr) * math.sin(lr), math.cos(lr)))
        root = Vector((PPX + math.cos(yr) * rr, PPY + math.sin(yr) * rr, z - 0.04))
        m = mat("leafA", "#5E9E6B", 0.6) if k % 2 == 0 else mat("leafB", "#8CBF7A", 0.6)
        ob = sphere(f"Leaf{k}", 1.0, root + d * L * 0.5, m, scale=(0.105, 0.036, L * 0.5), seg=24, rings=16)
        aim(ob, d); ob.rotation_quaternion = ob.rotation_quaternion @ Quaternion((0, 0, 1), math.radians(yaw * 0.7))

def plant_bushy():
    z = pot(0.32, 0.42, 0.50, "#9DB8C7")
    cyl("Stem", 0.05, 0.04, 0.42, (PPX, PPY, z + 0.2), mat("stem", "#8A6244", 0.7), seg=16, bevel=0)
    c = Vector((PPX, PPY, 1.22)); n = 16
    for k in range(n):
        v = 1 - 2 * (k + 0.5) / n; r = math.sqrt(1 - v * v); t = k * 2.39996
        d = Vector((math.cos(t) * r, math.sin(t) * r, v * 0.85))
        m = mat("leafA", "#6FA86A", 0.6) if k % 3 else mat("leafB", "#93C487", 0.6)
        sphere(f"Leaf{k}", 0.25 + 0.035 * (k % 3), c + d * 0.34, m, scale=(1, 1, 0.92), seg=24, rings=14)
    sphere("Leaf_Core", 0.36, c, mat("leafA", "#6FA86A", 0.6), seg=24, rings=14)

def plant_cactus():
    r0, r1, h = 0.30, 0.38, 0.50
    z = pot(r0, r1, h, "#F5E6D3", soil_hex="#D8B98F")
    for k, zc in enumerate((0.10, 0.24, 0.38)):
        ra = r0 + (r1 - r0) * (zc - 0.045) / h + 0.006; rb = r0 + (r1 - r0) * (zc + 0.045) / h + 0.006
        cyl(f"Pot_Stripe{k}", ra, rb, 0.09, (PPX, PPY, zc), mat("stripe", "#D98A72", 0.7), bevel=0)
    g = mat("cactus", "#7DB58A", 0.7)
    sphere("Leaf_Body", 0.21, (PPX, PPY, z + 0.16), g, stretch=0.56)                       # top at ~1.48
    for k, (sgn, za, up) in enumerate(((-1, 0.98, 0.24), (1, 1.14, 0.16))):
        sphere(f"Leaf_Elbow{k}", 0.085, (PPX + sgn * 0.14, PPY, za), g, rot=(0, sgn * math.radians(90), 0), stretch=0.18, seg=24, rings=12)
        sphere(f"Leaf_Arm{k}", 0.085, (PPX + sgn * 0.32, PPY, za), g, stretch=up, seg=24, rings=12)
    sphere("Leaf_Flower", 0.075, (PPX + 0.02, PPY - 0.02, 1.50), mat("flower", "#F2A0B0", 0.7), scale=(1, 1, 0.7), seg=20, rings=10)
    sphere("Leaf_Flower2", 0.05, (PPX - 0.32, PPY, 1.32), mat("flower", "#F2A0B0", 0.7), scale=(1, 1, 0.7), seg=20, rings=10)

def plant_trailing():
    wood = mat("wood", "#C8956A", 0.55)
    cyl("Pot_StandTop", 0.34, 0.34, 0.05, (PPX, PPY, 0.955), wood)
    for k in range(3):
        t = math.radians(90 + 120 * k); top = Vector((PPX + math.cos(t) * 0.20, PPY + math.sin(t) * 0.20, 0.94))
        foot = Vector((PPX + math.cos(t) * 0.32, PPY + math.sin(t) * 0.32, 0.0)); d = top - foot
        ob = cyl(f"Pot_StandLeg{k}", 0.028, 0.038, d.length, (foot + top) / 2, wood, seg=16, bevel=0); aim(ob, d)
    z = pot(0.20, 0.28, 0.36, "#E8B960", z0=0.98, rim=0.035)
    ga, gb = mat("leafA", "#6FA86A", 0.6), mat("leafB", "#93C487", 0.6)
    for k in range(6):
        t = math.radians(60 * k)
        sphere(f"Leaf_Top{k}", 0.13, (PPX + math.cos(t) * 0.13, PPY + math.sin(t) * 0.13, z + 0.07), ga if k % 2 else gb, scale=(1, 1, 0.75), seg=20, rings=10)
    sphere("Leaf_TopC", 0.15, (PPX, PPY, z + 0.13), ga, seg=20, rings=10)
    n = 0
    for yaw, count in ((-150, 6), (-95, 9), (-40, 5), (15, 7), (190, 8), (100, 4)):
        yr = math.radians(yaw); out = Vector((math.cos(yr), math.sin(yr), 0)); side = Vector((-out.y, out.x, 0))
        for i in range(count):
            rad = 0.325 + 0.035 * math.sin(i * 1.1) + 0.012 * i
            p = Vector((PPX, PPY, z + 0.02 - 0.105 * i)) + out * rad + side * (0.045 if i % 2 else -0.045)
            ob = sphere(f"Leaf_Vine{n}", 0.075, p, ga if (i + n) % 2 else gb, scale=(1, 0.95, 0.42), seg=16, rings=8)
            aim(ob, out + Vector((0, 0, 0.35))); n += 1

# ------------------------------------------------------------------ couches (canon: x -5.04..-1.86, y -1.46..-0.36, seat top 0.72)
SX, YF, YB, SW = -3.45, -1.46, -0.36, 3.18
YC = (YF + YB) / 2; SEAT_TOP = 0.72

def sofa_legs(m, h=0.14, inset=0.14):
    for i in (-1, 1):
        for j, yy in ((-1, YF + 0.12), (1, YB - 0.12)):
            cyl(f"Sofa_Leg{i}{j}", 0.065, 0.045, h + 0.02, (SX + i * (SW / 2 - inset), yy, h / 2), m, seg=24,
                rot=(math.radians(-8 * j), math.radians(8 * i), 0))

def couch_teal_two_seater():
    f = mat("fabric", "#6DB3AE", 0.92); arm = 0.36; inw = SW - 2 * arm
    pillow("Sofa_Body", (SW - 0.04, 1.08, 0.30), (SX, YC, 0.29), f, 0.6)
    for i in (-1, 1):
        pillow(f"Sofa_Arm{i}", (arm, 1.10, 0.80), (SX + i * (SW / 2 - arm / 2), YC, 0.54), f, 0.45)
        cx = SX + i * inw / 4
        pillow(f"Sofa_Seat{i}", (inw / 2 - 0.03, 0.88, 0.30), (cx, YF + 0.45, SEAT_TOP - 0.15), f, 0.5)
        pillow(f"Sofa_Back{i}", (inw / 2 - 0.04, 0.34, 0.66), (cx, YB - 0.34, 0.99), f, 0.42, rot=(math.radians(-8), 0, 0))
    pillow("Sofa_BackFrame", (inw + 0.04, 0.26, 1.04), (SX, YB - 0.13, 0.66), f, 0.6)
    sphere("Sofa_Cushion", 0.23, (SX - 0.88, YB - 0.62, SEAT_TOP + 0.21), mat("cushion", "#F0C05A", 0.92), scale=(1, 0.45, 1),
           rot=(math.radians(-14), 0, math.radians(12)))
    sofa_legs(mat("wood", "#C8956A", 0.55))

def couch_mustard_loveseat():
    f = mat("fabric", "#E6B65C", 0.92); ar = 0.27; inw = SW - 4 * ar
    pillow("Sofa_Body", (SW - 0.20, 1.06, 0.30), (SX, YC, 0.29), f, 0.6)
    for i in (-1, 1):
        ax = SX + i * (SW / 2 - ar)
        pillow(f"Sofa_ArmBase{i}", (2 * ar - 0.06, 1.04, 0.50), (ax, YC, 0.39), f, 0.5)
        cyl(f"Sofa_Arm{i}", ar, ar, 1.10, (ax, YC, 0.64), f, rot=(math.radians(90), 0, 0), bevel=0.10)
        cyl(f"Sofa_ArmButton{i}", 0.07, 0.07, 0.03, (ax, YF - 0.005, 0.64), mat("button", "#F7E8D8", 0.9), seg=24,
            rot=(math.radians(90), 0, 0), bevel=0.01)
    pillow("Sofa_Seat0", (inw - 0.02, 0.88, 0.30), (SX, YF + 0.45, SEAT_TOP - 0.15), f, 0.5)
    pillow("Sofa_BackFrame", (inw + 0.10, 0.24, 1.00), (SX, YB - 0.12, 0.64), f, 0.6)
    pillow("Sofa_Back0", (inw + 0.30, 0.36, 0.86), (SX, YB - 0.32, 0.93), f, 0.25, rot=(math.radians(-8), 0, 0))
    sofa_legs(mat("wood", "#A9744F", 0.55))

def couch_low_bench():
    wood = mat("wood", "#C8956A", 0.55); f = mat("fabric", "#9DB8C7", 0.92); cream = mat("cream", "#F5E6D3", 0.92)
    rbox("Sofa_Body", (SW, 1.10, 0.10), (SX, YC, 0.27), wood, 0.04, 5)
    rbox("Sofa_BackFrame", (SW, 0.08, 0.72), (SX, YB - 0.04, 0.66), wood, 0.035, 5)
    pillow("Sofa_Seat0", (SW - 0.08, 0.98, 0.40), (SX, YF + 0.50, 0.52), f, 0.5)
    for k in (-1, 0, 1):
        pillow(f"Sofa_Back{k}", (0.98, 0.30, 0.50), (SX + k * 1.02, YB - 0.26, 0.93), cream, 0.4, rot=(math.radians(-10), 0, 0))
    for i in (-1, 1):
        cyl(f"Sofa_Bolster{i}", 0.15, 0.15, 0.78, (SX + i * (SW / 2 - 0.22), YF + 0.48, SEAT_TOP + 0.13), mat("bolster", "#D98A72", 0.92),
            rot=(math.radians(90), 0, 0), bevel=0.07)
    sofa_legs(wood, h=0.23, inset=0.18)

# ------------------------------------------------------------------ registry
VARIANTS = [
    ("rugs", "rug_sage_round", "rug", "Sage Round Rug", "Round sage-green rug with two cream rings.", rug_sage_round),
    ("rugs", "rug_striped_rect", "rug", "Striped Rug", "Cream rounded-rectangle rug with terracotta and mustard stripes.", rug_striped_rect),
    ("rugs", "rug_checker", "rug", "Checker Rug", "Cream rug with a dusty-blue checkerboard.", rug_checker),
    ("rugs", "rug_scalloped", "rug", "Scalloped Rug", "Blush oval rug with a scalloped edge and a cream inset ring.", rug_scalloped),
    ("pictures", "pic_sunset_hills", "picL", "Sunset Hills", "Orange sun setting behind mauve and sage hills, light wood frame.", pic_sunset_hills),
    ("pictures", "pic_flower", "picL", "Little Flower", "A pink six-petal flower on cream, sage frame.", pic_flower),
    ("pictures", "pic_abstract", "picL", "Shapes", "Abstract arch, circle, bar and dot in the room's palette, dark wood frame.", pic_abstract),
    ("pictures", "pic_moon", "picL", "Crescent Moon", "Cream crescent moon and stars over soft clouds on dusk blue, cream frame.", pic_moon),
    ("plants", "plant_snake", "plant", "Snake Plant", "Tall upright two-tone blades in a cream pot.", plant_snake),
    ("plants", "plant_bushy", "plant", "Round Bush", "A round bushy ball of leaves on a short trunk, dusty-blue pot.", plant_bushy),
    ("plants", "plant_cactus", "plant", "Little Cactus", "Two-armed cactus with pink flowers in a terracotta-striped pot.", plant_cactus),
    ("plants", "plant_trailing", "plant", "Trailing Vine", "Mustard pot on a three-legged wooden stand with vines trailing down.", plant_trailing),
    ("couches", "couch_teal_two_seater", "couch", "Teal Two-Seater", "Teal two-seater with square arms and a mustard round cushion.", couch_teal_two_seater),
    ("couches", "couch_mustard_loveseat", "couch", "Mustard Loveseat", "Mustard loveseat with rolled round arms and a one-piece back.", couch_mustard_loveseat),
    ("couches", "couch_low_bench", "couch", "Low Bench Sofa", "Low wooden bench sofa with a dusty-blue seat, cream back cushions and terracotta bolsters.", couch_low_bench),
]

FMT0, MODE0 = sc.render.image_settings.file_format, sc.render.image_settings.color_mode
PICR_OFFSET, PICR_SCALE = (1.15, 0.0, -0.05), 0.9      # PicL slot -> PicR slot (see README)

def world_bbox(obs):
    dg = bpy.context.evaluated_depsgraph_get(); lo = [1e9] * 3; hi = [-1e9] * 3
    for o in obs:
        e = o.evaluated_get(dg)
        for c in e.bound_box:
            w = e.matrix_world @ Vector(c)
            for i in range(3): lo[i] = min(lo[i], w[i]); hi[i] = max(hi[i], w[i])
    return [round(x, 3) for x in lo], [round(x, 3) for x in hi]

def render_pair(out, render_name, mask_name):
    """The room with the current variant (-> render_name), then its coverage mask (-> mask_name)."""
    sc.render.film_transparent = False
    sc.render.image_settings.file_format = 'PNG'
    sc.render.image_settings.color_mode = MODE0 if MODE0 in ('RGB', 'RGBA') else 'RGB'
    sc.render.filepath = os.path.join(out, render_name)
    t0 = time.time(); bpy.ops.render.render(write_still=True); t_render = time.time() - t0
    # coverage mask: everything but the variant held out, transparent film
    sc.render.film_transparent = True; sc.render.image_settings.color_mode = 'RGBA'
    cur = set(CUR)
    for o in bpy.data.objects:
        if o.type == 'MESH': o.is_holdout = o not in cur
    sc.render.filepath = os.path.join(out, mask_name)
    t0 = time.time(); bpy.ops.render.render(write_still=True); t_mask = time.time() - t0
    for o in bpy.data.objects:
        if o.type == 'MESH': o.is_holdout = False
    sc.render.film_transparent = False
    return t_render, t_mask

def run(variants, batch=None):
    """Build, render and write every variant in the list. A variant is
    (category, id, replaces, name, description, builder[, options]); replaces is a CANON key or None (nothing
    hidden). options: "extra": fn(objects) -> dict merged into meta.json; "picR": True also renders the
    picture moved to the PicR slot (render_picR.png / mask_picR.png). batch is written to meta.json if given."""
    for v in variants:
        cat, vid, replaces, name, desc, build = v[:6]; opts = v[6] if len(v) > 6 else {}
        if ONLY and vid not in ONLY: continue
        if CATEGORY and cat != CATEGORY: continue
        out = os.path.join(HERE, cat, vid); os.makedirs(out, exist_ok=True)
        CUR.clear(); MATS.clear(); VID[0] = vid
        build(); bpy.context.view_layer.update()
        hidden = CANON[replaces] if replaces else []
        for o in hidden: o.hide_render = True
        # 1 + 2. the room with this variant in place of its canon item (other canon items present), and the mask
        t_render, t_mask = render_pair(out, "render.png", "mask.png")
        lo, hi = world_bbox(CUR)
        # 3. just this variant's objects (with their meshes and materials)
        bpy.data.libraries.write(os.path.join(out, vid + ".blend"), set(CUR), fake_user=True)
        meta = {"id": vid, "category": cat, "name": name, "description": desc, "replaces": replaces,
                "objects": sorted(o.name for o in CUR), "world_bbox_min": lo, "world_bbox_max": hi,
                "plate_size": [W, H], "render_seconds": round(t_render, 1), "mask_seconds": round(t_mask, 1)}
        if batch is not None: meta["batch"] = batch
        if opts.get("extra"): meta.update(opts["extra"](list(CUR)))
        for o in hidden: o.hide_render = False
        if opts.get("picR"):
            # the same picture at the right-hand slot: moved by PICR_OFFSET and scaled about its own centre
            from mathutils import Matrix
            c = Vector((PX, -0.03, PZ)); saved = [(o, o.matrix_world.copy()) for o in CUR]
            xf = Matrix.Translation(c + Vector(PICR_OFFSET)) @ Matrix.Diagonal((PICR_SCALE, 1.0, PICR_SCALE, 1.0)) @ Matrix.Translation(-c)
            for o, m in saved: o.matrix_world = xf @ m
            bpy.context.view_layer.update()
            for o in CANON["picR"]: o.hide_render = True
            t2, t3 = render_pair(out, "render_picR.png", "mask_picR.png")
            for o in CANON["picR"]: o.hide_render = False
            for o, m in saved: o.matrix_world = m
            meta["picR"] = {"offset": list(PICR_OFFSET), "scale_xz": PICR_SCALE, "about": [PX, -0.03, PZ],
                            "render_seconds": round(t2, 1), "mask_seconds": round(t3, 1)}
        json.dump(meta, open(os.path.join(out, "meta.json"), "w"), indent=1)
        print(f"VARIANT {vid}: {len(CUR)} objects, bbox {lo} {hi}, render {t_render:.1f}s mask {t_mask:.1f}s")
        for o in CUR: bpy.data.objects.remove(o, do_unlink=True)
    sc.render.image_settings.file_format, sc.render.image_settings.color_mode = FMT0, MODE0
    print("STORE ASSETS done (room.blend was not saved)")

if __name__ == "__main__":
    run(VARIANTS)
