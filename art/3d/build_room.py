"""Living room from the canon screen (GrubIOS/docs/canon/2026-11-19-livingroom-screen.png),
modelled from primitives in the same soft clay style as grub_clean, with Grub placed in it.
Headless: Blender -b --python build_room.py  ->  room.blend, renders/room_render.png
World: x right, y away from camera (back wall at +y), z up. Grub is 1.0 tall."""
import bpy, bmesh, math, os
from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__))
bpy.ops.wm.read_factory_settings(use_empty=True)
sc = bpy.context.scene
COL = sc.collection

# ---------- helpers ----------
def srgb(h):
    h = h.lstrip('#'); c = [int(h[i:i + 2], 16) / 255 for i in (0, 2, 4)]
    return tuple(((x + 0.055) / 1.055) ** 2.4 if x > 0.04045 else x / 12.92 for x in c) + (1,)

MATS = {}
def mat(name, hexc, rough=0.65, emit=0.0):
    if name in MATS: return MATS[name]
    m = bpy.data.materials.new(name); m.use_nodes = True
    b = next(n for n in m.node_tree.nodes if n.type == 'BSDF_PRINCIPLED')
    b.inputs['Base Color'].default_value = srgb(hexc)
    b.inputs['Roughness'].default_value = rough
    if emit:
        b.inputs['Emission Color'].default_value = srgb(hexc)
        b.inputs['Emission Strength'].default_value = emit
    m.diffuse_color = srgb(hexc)
    MATS[name] = m; return m

def link(ob):
    COL.objects.link(ob); return ob

def rbox(name, size, loc, m, bevel=0.08, seg=6, rot=(0, 0, 0)):
    """Rounded box: cube with a bevel modifier (harden normals keeps flat faces flat)."""
    me = bpy.data.meshes.new(name); bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0); bm.to_mesh(me); bm.free()
    ob = link(bpy.data.objects.new(name, me))
    ob.scale = size; ob.location = loc; ob.rotation_euler = rot
    bpy.context.view_layer.objects.active = ob; ob.select_set(True)
    bpy.ops.object.transform_apply(scale=True); ob.select_set(False)
    md = ob.modifiers.new("Bevel", 'BEVEL'); md.width = min(bevel, min(size) / 2 - 1e-3)
    md.segments = seg; md.harden_normals = True; md.limit_method = 'NONE'
    for p in me.polygons: p.use_smooth = True
    me.materials.append(m); return ob

def sphere(name, r, loc, m, scale=(1, 1, 1), rot=(0, 0, 0), seg=48, rings=24):
    me = bpy.data.meshes.new(name); bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=seg, v_segments=rings, radius=r); bm.to_mesh(me); bm.free()
    for p in me.polygons: p.use_smooth = True
    ob = link(bpy.data.objects.new(name, me)); ob.location = loc; ob.scale = scale; ob.rotation_euler = rot
    me.materials.append(m); return ob

def cyl(name, r1, r2, depth, loc, m, seg=48, rot=(0, 0, 0)):
    me = bpy.data.meshes.new(name); bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, segments=seg, radius1=r1, radius2=r2, depth=depth)
    bm.to_mesh(me); bm.free()
    ob = link(bpy.data.objects.new(name, me)); ob.location = loc; ob.rotation_euler = rot
    md = ob.modifiers.new("Bevel", 'BEVEL'); md.width = min(0.03, depth / 3); md.segments = 4
    md.harden_normals = True; md.limit_method = 'ANGLE'
    for p in me.polygons: p.use_smooth = True
    me.materials.append(m); return ob

# ---------- palette (sampled by eye from the canon screen) ----------
WALL = mat("Wall", os.environ.get("WALLC", "#ECE3D9"), 0.9)
FLOOR = mat("Floor", os.environ.get("FLOORC", "#EDE4D9"), 0.85)
CEIL = mat("Ceiling", "#F0E8DE", 0.9)
def camera_only_glow(m, hexc, strength):
    """Brighten a surface for the camera only: the glow is not a light source for the room."""
    if strength <= 0: return
    nt = m.node_tree; out = next(n for n in nt.nodes if n.type == 'OUTPUT_MATERIAL')
    bsdf = next(n for n in nt.nodes if n.type == 'BSDF_PRINCIPLED')
    em = nt.nodes.new('ShaderNodeEmission'); em.inputs[0].default_value = srgb(hexc); em.inputs[1].default_value = strength
    add = nt.nodes.new('ShaderNodeAddShader'); mix = nt.nodes.new('ShaderNodeMixShader')
    lp = nt.nodes.new('ShaderNodeLightPath')
    nt.links.new(bsdf.outputs[0], add.inputs[0]); nt.links.new(em.outputs[0], add.inputs[1])
    nt.links.new(lp.outputs['Is Camera Ray'], mix.inputs[0])
    nt.links.new(bsdf.outputs[0], mix.inputs[1]); nt.links.new(add.outputs[0], mix.inputs[2])
    nt.links.new(mix.outputs[0], out.inputs['Surface'])
camera_only_glow(CEIL, "#F0E8DE", float(os.environ.get("CEILE", "0.45")))
SOFA = mat("Sofa", "#F4A3AE", 0.92)
_sb = next(n for n in SOFA.node_tree.nodes if n.type == 'BSDF_PRINCIPLED')
_sb.inputs['Specular IOR Level'].default_value = 0.2
_sb.inputs['Sheen Weight'].default_value = 0.5; _sb.inputs['Sheen Tint'].default_value = srgb("#FFE3E8")
SOFA_LEG = mat("SofaLeg", "#9A6A4F", 0.6)
DOOR = mat("Door", "#EFA3A3", 0.6)
TRIM = mat("Trim", "#F6E6D2", 0.7)
KNOB = mat("Knob", "#FAF6F0", 0.3)
FRAME = mat("Frame", "#D9B48C", 0.6)
ART_BG = mat("ArtPink", "#F2B3B8", 0.9)
ART_HILL = mat("ArtHill", "#BFC6CE", 0.9)
ART_GRASS = mat("ArtGrass", "#B9D98F", 0.9)
BALL_TEAL = mat("SofaBall", "#7FC3C3", 0.5)
POT = mat("Pot", "#D9774F", 0.7)
SOIL = mat("Soil", "#6B4A35", 0.9)
STEM = mat("Stem", "#7A5A3A", 0.7)
LEAF = mat("Leaf", "#5E9E4B", 0.55)
LAMP = mat("Lamp", "#FFFFFF", 0.3, emit=6.0)
LAMP_RIM = mat("LampRim", "#E9E2DA", 0.5)
BB = [mat("BB_Red", "#E8574E", 0.45), mat("BB_Yellow", "#F4C64A", 0.45), mat("BB_Blue", "#4F9BDB", 0.45),
      mat("BB_White", "#F7F3EC", 0.45), mat("BB_Teal", "#58B7A8", 0.45)]

# ---------- room shell: the camera looks into a corner ----------
# Wall A (pictures, sofa) is the plane y=0 for x<0, facing -y.
# Wall B (door) is the plane x=0 for y<0, facing -x. Corner at the origin.
H, EXT = 4.4, 10.0
BACK = 0.0
rbox("Floor", (2 * EXT, 2 * EXT, 0.2), (0, -EXT / 2, -0.1), FLOOR, 0.01, 1)
rbox("Ceiling", (2 * EXT, 2 * EXT, 0.2), (0, -EXT / 2, H + 0.1), CEIL, 0.01, 1)
rbox("WallA", (EXT + 0.2, 0.2, H), (-EXT / 2, 0.1, H / 2), WALL, 0.01, 1)
rbox("WallB", (0.2, EXT + 0.2, H), (0.1, -EXT / 2, H / 2), WALL, 0.01, 1)

# ceiling light: flush disc
LX, LY = -2.3, -2.6
# dropped 2026-11-19 (no ceiling light): cyl("LampRim", 0.62, 0.62, 0.10, (LX, LY, H - 0.05), LAMP_RIM)
# dropped 2026-11-19 (no ceiling light): cyl("LampDiffuser", 0.56, 0.50, 0.06, (LX, LY, H - 0.12), LAMP)

# ---------- sofa (against wall A), matched to the canon couch ----------
# Puffy two-seater: pillow back cushions taller than the rolled arms, two thick seat cushions on a
# solid base, short light-wood legs. Pillow shapes = creased cube + subdivision (soft, bulging faces).
def pillow(name, size, loc, m, crease=0.75, rot=(0, 0, 0)):
    me = bpy.data.meshes.new(name); bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    for v in bm.verts:
        v.co = Vector((v.co.x * size[0], v.co.y * size[1], v.co.z * size[2]))
    cl = bm.edges.layers.float.get('crease_edge') or bm.edges.layers.float.new('crease_edge')
    for e in bm.edges: e[cl] = crease
    bm.to_mesh(me); bm.free()
    ob = link(bpy.data.objects.new(name, me)); ob.location = loc; ob.rotation_euler = rot
    sd_ = ob.modifiers.new("Subsurf", 'SUBSURF'); sd_.levels = 3; sd_.render_levels = 3
    for p_ in me.polygons: p_.use_smooth = True
    me.materials.append(m); return ob

SOFA_LEG = mat("SofaLegWood", "#C8956A", 0.55)
sx, sy = -3.45, -0.66            # centre of the sofa footprint (back against wall A at y=0)
ARM_W, IN_W, DEP = 0.44, 2.30, 1.10
TOT_W = IN_W + 2 * ARM_W
LEG_H = 0.14
BASE_TOP = 0.42
SEAT_H = 0.30
SEAT_TOP = BASE_TOP + SEAT_H      # 0.72
ARM_TOP = SEAT_TOP + 0.24
BACK_TOP = 1.32
yf, yb = sy - DEP / 2, sy + DEP / 2
# base plinth between the arms
def sofa_body(name, m, crease=0.42):
    """Base and both arms as one mesh: a full-width block cut into arm|seat|arm, with the arm
    sections extruded up. Subdivision then rounds it as one piece, so the arms grow out of the base."""
    me = bpy.data.meshes.new(name); bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    h = BASE_TOP - LEG_H
    for v in bm.verts:
        v.co = Vector((v.co.x * TOT_W, v.co.y * DEP, v.co.z * h + LEG_H + h / 2))
    for sgn in (-1, 1):
        bmesh.ops.bisect_plane(bm, geom=bm.verts[:] + bm.edges[:] + bm.faces[:],
                               plane_co=(sgn * IN_W / 2, 0, 0), plane_no=(1, 0, 0))
    bm.faces.ensure_lookup_table()
    tops = [f for f in bm.faces if f.normal.z > 0.9 and abs(f.calc_center_median().x) > IN_W / 2]
    for f in tops:
        ret = bmesh.ops.extrude_face_region(bm, geom=[f])
        vs = [e for e in ret["geom"] if isinstance(e, bmesh.types.BMVert)]
        bmesh.ops.translate(bm, verts=vs, vec=(0, 0, ARM_TOP - BASE_TOP))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    cl = bm.edges.layers.float.get('crease_edge') or bm.edges.layers.float.new('crease_edge')
    for e in bm.edges: e[cl] = crease
    bm.to_mesh(me); bm.free()
    ob = link(bpy.data.objects.new(name, me)); ob.location = (sx, sy, 0)
    sd_ = ob.modifiers.new("Subsurf", 'SUBSURF'); sd_.levels = 3; sd_.render_levels = 3
    for p_ in me.polygons: p_.use_smooth = True
    me.materials.append(m); return ob
sofa_body("Sofa_Body", SOFA)
# back frame (mostly hidden behind the cushions)
pillow("Sofa_BackFrame", (IN_W + 0.02, 0.26, 1.18 - LEG_H), (sx, yb - 0.13, (LEG_H + 1.18) / 2), SOFA, 0.6)
for i in (-1, 1):
    cx = sx + i * (IN_W / 4)
    # rolled arms: full height from the legs, rounded top
    # thick seat cushions, front edge a touch proud of the base
    pillow(f"Sofa_Seat{i}", (IN_W / 2 - 0.03, DEP - 0.22, SEAT_H), (cx, sy - 0.07, BASE_TOP + SEAT_H / 2), SOFA, 0.5)
    # tall pillow back cushions, leaning back a little
    bh = BACK_TOP - (SEAT_TOP - 0.06)
    pillow(f"Sofa_Back{i}", (IN_W / 2 - 0.04, 0.36, bh), (cx, yb - 0.33, SEAT_TOP - 0.06 + bh / 2), SOFA, 0.42,
           rot=(math.radians(-8), 0, 0))
    for j, yy in ((-1, yf + 0.12), (1, yb - 0.12)):
        leg = cyl(f"Sofa_Leg{i}{j}", 0.065, 0.045, LEG_H + 0.02, (sx + i * (TOT_W / 2 - 0.14), yy, LEG_H / 2), SOFA_LEG, seg=24,
                  rot=(math.radians(-8 * j), math.radians(8 * i), 0))
sphere("Sofa_Ball", 0.30, (sx - IN_W / 4 - 0.05, yb - 0.62, SEAT_TOP + 0.27), BALL_TEAL)

# ---------- picture frames (wall A, above the sofa) ----------
def picture(name, x, z, w=0.62, h=0.78):
    y = BACK - 0.03
    rbox(name + "_Frame", (w, 0.06, h), (x, y, z), FRAME, 0.02, 3)
    iw, ih = w - 0.12, h - 0.12
    rbox(name + "_Canvas", (iw, 0.02, ih), (x, y - 0.035, z), ART_BG, 0.003, 1)
    rbox(name + "_Grass", (iw, 0.025, ih * 0.22), (x, y - 0.04, z - ih / 2 + ih * 0.11), ART_GRASS, 0.003, 1)
    for k, (dx, r) in enumerate(((-0.08, 0.16), (0.12, 0.12))):
        sphere(f"{name}_Hill{k}", r, (x + dx, y - 0.038, z - ih / 2 + ih * 0.22), ART_HILL, scale=(1, 0.05, 1.3))
picture("PicL", -4.0, 2.05, 0.68, 0.84)
picture("PicR", -2.85, 2.00, 0.60, 0.76)

# ---------- door (wall B) ----------
dy, dw, dh = -1.10, 1.30, 3.05
R90 = (0, 0, math.radians(90))   # local x (width) runs along world y, local y (thickness) along world x
rbox("Door_Frame", (dw + 0.22, 0.10, dh + 0.11), (-0.02, dy, (dh + 0.11) / 2), TRIM, 0.02, 2, rot=R90)
rbox("Door", (dw, 0.10, dh), (-0.06, dy, dh / 2), DOOR, 0.02, 2, rot=R90)
for k, (pz, ph) in enumerate(((dh * 0.70, dh * 0.38), (dh * 0.25, dh * 0.30))):
    rbox(f"Door_Panel{k}", (dw * 0.72, 0.03, ph), (-0.12, dy, pz), DOOR, 0.025, 3, rot=R90)
sphere("Door_Knob", 0.06, (-0.16, dy - dw / 2 + 0.14, dh * 0.47), KNOB)

OPEN = math.radians(float(os.environ.get("OPEN", "58")))
piv = link(bpy.data.objects.new("WallB_Pivot", None))
for o in bpy.data.objects:
    if o.name.startswith(("WallB", "Door")) and o is not piv:
        o.parent = piv
piv.rotation_euler = (0, 0, OPEN)

# ---------- potted plant (near the corner) ----------
px, py = -1.25, -0.80
PS = 1.25
plant_start = len(bpy.data.objects)
cyl("Pot", 0.30, 0.38, 0.55, (px, py, 0.275), POT)
cyl("Pot_Rim", 0.42, 0.42, 0.10, (px, py, 0.56), POT)
cyl("Soil", 0.36, 0.36, 0.02, (px, py, 0.61), SOIL)
cyl("Stem", 0.035, 0.025, 1.0, (px - 0.02, py, 1.05), STEM, seg=16, rot=(0, math.radians(-4), 0))
leaves = [  # (yaw deg, tilt deg, height, length)
    (0, 72, 1.55, 0.62), (60, 76, 1.52, 0.58), (125, 70, 1.55, 0.62), (185, 75, 1.50, 0.58),
    (245, 70, 1.55, 0.62), (300, 78, 1.50, 0.58), (30, 25, 1.62, 0.42), (150, 30, 1.62, 0.40),
    (270, 28, 1.62, 0.40), (90, 75, 1.30, 0.45), (210, 78, 1.28, 0.45), (330, 72, 1.30, 0.42)]
for k, (yaw, tilt, z, L) in enumerate(leaves):
    yr, tr = math.radians(yaw), math.radians(tilt)
    d = Vector((math.cos(yr) * math.sin(tr), math.sin(yr) * math.sin(tr), math.cos(tr)))
    ob = sphere(f"Leaf{k}", 1.0, Vector((px, py, z)) + d * L * 0.5, LEAF, scale=(L * 0.5, 0.17, 0.025), seg=24, rings=12)
    ob.rotation_mode = 'QUATERNION'; ob.rotation_quaternion = d.to_track_quat('X', 'Z')

for ob in list(bpy.data.objects)[plant_start:]:
    pass
PLANT = [o for o in bpy.data.objects if o.name.startswith(("Pot", "Soil", "Stem", "Leaf"))]
for o in PLANT:
    o.location = Vector((px, py, 0)) + (o.location - Vector((px, py, 0))) * PS
    o.scale = o.scale * PS

# ---------- beach ball (front-left floor) ----------
def beach_ball(loc, r=0.30):
    ob = sphere("BeachBall", r, loc, BB[0], seg=48, rings=24)
    me = ob.data
    for m in BB[1:]: me.materials.append(m)
    order = [0, 1, 2, 0, 1, 4]
    for p in me.polygons:
        c = p.center
        if abs(c.z) > r * 0.95: p.material_index = 3; continue
        a = (math.atan2(c.y, c.x) + math.pi) / (2 * math.pi)
        p.material_index = order[int(a * 6) % 6]
    ob.rotation_euler = (math.radians(25), math.radians(-20), math.radians(10))
    return ob

# ---------- camera ----------
CAM = Vector((-4.6, -9.0, 2.55))
cd = bpy.data.cameras.new("Cam"); cd.lens = 27; cd.sensor_fit = 'VERTICAL'; cd.sensor_height = 36
cam = link(bpy.data.objects.new("Cam", cd)); sc.camera = cam
cam.location = CAM
target = Vector((-2.3, -1.5, 1.4))
cam.rotation_euler = (target - cam.location).to_track_quat('-Z', 'Y').to_euler()

GX, GY = -2.55, -2.45
beach_ball((-4.15, -2.35, 0.27), 0.27)

# ---------- Grub (faces the camera) ----------
with bpy.data.libraries.load(os.path.join(HERE, "grub_clean.blend")) as (src, dst):
    dst.objects = [n for n in src.objects if n in ("Grub", "GrubRig")]
for ob in dst.objects:
    COL.objects.link(ob)
rig = bpy.data.objects["GrubRig"]
if rig.animation_data: rig.animation_data.action = None
for pb in rig.pose.bones:
    pb.location = (0, 0, 0); pb.rotation_quaternion = (1, 0, 0, 0); pb.rotation_euler = (0, 0, 0)
skin = bpy.data.materials.get("Grub_Skin")
if skin and skin.node_tree:
    bs = next(n for n in skin.node_tree.nodes if n.type == 'BSDF_PRINCIPLED')
    bs.inputs['Base Color'].default_value = srgb(os.environ.get("SKIN", "#669B8D"))
    bs.inputs['Roughness'].default_value = float(os.environ.get('ROUGH', '0.9'))
    bs.inputs['Specular IOR Level'].default_value = float(os.environ.get('SPEC', '0.15'))
    bs.inputs['Sheen Weight'].default_value = float(os.environ.get("SHEEN", "0.5"))
    bs.inputs['Sheen Roughness'].default_value = float(os.environ.get('SHR', '0.35'))
    bs.inputs['Sheen Tint'].default_value = srgb("#DFFFF6")
shine = bpy.data.materials.get("Grub_Shine")
if shine and shine.node_tree:
    sb = next(n for n in shine.node_tree.nodes if n.type == 'BSDF_PRINCIPLED')
    sb.inputs['Base Color'].default_value = srgb(os.environ.get("SHINE", "#E6E1D3"))
    sb.inputs['Emission Strength'].default_value = 0.0
    sb.inputs['Roughness'].default_value = 0.7
GRUB_SCALE = 1.35
rig.scale = (GRUB_SCALE,) * 3
rig.location = (GX, GY, 0)
to_cam = CAM - Vector((GX, GY, 0))
rig.rotation_euler = (0, 0, math.atan2(to_cam.x, -to_cam.y))

# ---------- Grub's contact shadow (blob decal, as games do it) ----------
def blob_shadow():
    E = lambda k, d: float(os.environ.get(k, d))
    me = bpy.data.meshes.new("GrubShadow"); bm = bmesh.new()
    bmesh.ops.create_grid(bm, x_segments=1, y_segments=1, size=1.0); bm.to_mesh(me); bm.free()
    ob = link(bpy.data.objects.new("GrubShadow", me))
    ob.parent = rig; ob.matrix_parent_inverse = rig.matrix_world.inverted() if False else ob.matrix_parent_inverse
    # rig is scaled by GRUB_SCALE; give the decal its size in Grub's (unscaled) local units
    ob.location = (E("SHX", "-0.035"), E("SHY", "0.08"), 0.004 / GRUB_SCALE)
    ob.scale = (E("SHRX", "0.56"), E("SHRY", "0.24"), 1)
    ob.visible_shadow = False
    m = bpy.data.materials.new("GrubShadow"); m.use_nodes = True
    try: m.surface_render_method = 'BLENDED'
    except Exception: m.blend_method = 'BLEND'
    nt = m.node_tree; nt.nodes.clear()
    out = nt.nodes.new('ShaderNodeOutputMaterial')
    clear = nt.nodes.new('ShaderNodeBsdfTransparent'); clear.inputs[0].default_value = (1, 1, 1, 1)
    dark = nt.nodes.new('ShaderNodeBsdfTransparent'); dark.inputs[0].default_value = srgb(os.environ.get("SHC", "#B0AAA3"))
    mix = nt.nodes.new('ShaderNodeMixShader')
    tc = nt.nodes.new('ShaderNodeTexCoord')
    ln = nt.nodes.new('ShaderNodeVectorMath'); ln.operation = 'LENGTH'
    mr = nt.nodes.new('ShaderNodeMapRange')       # 1 inside the core, 0 past the rim
    mr.interpolation_type = 'SMOOTHSTEP'
    mr.inputs['From Min'].default_value = 1.0 - E("SHSOFT", "0.45"); mr.inputs['From Max'].default_value = 1.0
    mr.inputs['To Min'].default_value = 1.0; mr.inputs['To Max'].default_value = 0.0
    nt.links.new(tc.outputs['Object'], ln.inputs[0])
    nt.links.new(ln.outputs['Value'], mr.inputs['Value'])
    nt.links.new(mr.outputs['Result'], mix.inputs[0])
    nt.links.new(clear.outputs[0], mix.inputs[1]); nt.links.new(dark.outputs[0], mix.inputs[2])
    nt.links.new(mix.outputs[0], out.inputs['Surface'])
    me.materials.append(m)
    return ob
if os.environ.get("BLOB", "1") == "1":
    blob_shadow()

# ---------- lighting: soft, warm, low contrast ----------
w = bpy.data.worlds.new("W"); sc.world = w; w.use_nodes = True
bg = next(n for n in w.node_tree.nodes if n.type == 'BACKGROUND')
bg.inputs[0].default_value = srgb("#F6E7D6"); bg.inputs[1].default_value = float(os.environ.get("WORLD", "0.15"))
def area(name, loc, energy, size, col="#FFFBF6", tgt=(-2, -2, 0.8)):
    d = bpy.data.lights.new(name, 'AREA'); d.energy = energy; d.size = size; d.color = srgb(col)[:3]
    o = link(bpy.data.objects.new(name, d)); o.location = loc
    o.rotation_euler = (Vector(tgt) - Vector(loc)).to_track_quat('-Z', 'Y').to_euler(); return o
K = float(os.environ.get("LIGHT", "1.0"))
KEYL = area("Key", (-6.5, -5.0, 3.9), 160 * K, 7.0)
FILLL = area("Fill", (-2.5, -7.5, float(os.environ.get("FILLZ", "4.2"))), float(os.environ.get("FILL", "0")) * K, 6.0, "#FFFFFF",
             tgt=(-2.3, -1.5, 0.0))
ROOMTOP = area("RoomTop", (-2.3, float(os.environ.get("RTY", "-2.6")), H - 0.05), float(os.environ.get("ROOMTOP", "95")) * K, 5.0, "#FFF9F2",
               tgt=(-2.3, float(os.environ.get("RTY", "-2.6")), 0.0))
ROOMTOP.data.size = float(os.environ.get("RTS", "3"))
ROOMTOP.data.spread = math.radians(float(os.environ.get("RTSP", "60")))
# close the room behind the camera so outside light can't flood the near floor
if os.environ.get("FRONTWALL", "1") == "1":
    rbox("FrontWall", (2 * EXT, 0.2, H + 0.4), (0, CAM.y - 0.6, H / 2), WALL, 0.01, 1)
# dropped 2026-11-19: area("CeilingBounce", (LX, LY, H - 0.25), 45 * K, 1.1, "#FFFDF8", tgt=(LX, LY, 0))
area("GrubKey", tuple(Vector((GX, GY, 0)) + (CAM - Vector((GX, GY, 0))).normalized() * 3.0 + Vector((float(os.environ.get("GKX", "0")), 0, float(os.environ.get("GKZ", "0.3"))))),
     float(os.environ.get("GK", "95")) * K, float(os.environ.get("GKS", "4")), "#FFFFFF", tgt=(GX, GY, 0.7))
area("GrubTop", (GX, GY - 0.2, 3.2), float(os.environ.get("TOP", "62")) * K, 2.2, "#FFFFFF",
     tgt=(GX, GY, 1.3)).data.spread = math.radians(40)
# rims in Grub's own frame: behind him and to each side as the viewer sees it
_fwd = Vector((CAM.x - GX, CAM.y - GY, 0)).normalized()
_back, _vright = -_fwd, Vector((_fwd.y * -1, _fwd.x, 0)) * -1
_rz = float(os.environ.get("RIMZ", "1.0"))
for nm, side, env in (("GrubRimL", -1, "RIML"), ("GrubRimR", 1, "RIMR")):
    off = _vright * (side * 1.2) + _back * 0.5 + Vector((0, 0, _rz))
    area(nm, tuple(Vector((GX, GY, 0)) + off), float(os.environ.get(env, {"RIML": "14", "RIMR": "12"}[env])) * K, 0.6, "#FFFFFF",
         tgt=(GX, GY, 0.7)).data.spread = math.radians(35)
# Grub's own lights (front fill, top, rims) light only Grub, never the floor or room
if os.environ.get("GRUBONLY", "1") == "1":
    gc = bpy.data.collections.new("GrubOnly"); gc.objects.link(bpy.data.objects["Grub"])
    for nm in ("GrubKey", "GrubTop", "GrubRimL", "GrubRimR"):
        bpy.data.objects[nm].light_linking.receiver_collection = gc
if os.environ.get("KEYX", "1") == "1":
    rc = bpy.data.collections.new("KeyReceivers")
    rc.objects.link(bpy.data.objects["Grub"])
    for L_ in (KEYL, FILLL, ROOMTOP):
        L_.light_linking.receiver_collection = rc
        if os.environ.get("NOGRUBSHADOW", "1") == "1":
            L_.light_linking.blocker_collection = rc
    rc.collection_objects[0].light_linking.link_state = 'EXCLUDE'
MATS["Lamp"].node_tree.nodes["Principled BSDF"].inputs['Emission Strength'].default_value = 2.5

# ---------- render ----------
sc.render.engine = 'BLENDER_EEVEE'
sc.view_settings.view_transform = os.environ.get('VT', 'Standard')
sc.view_settings.exposure = float(os.environ.get('EXPO', '0'))
sc.view_settings.look = 'None'
sc.render.resolution_x, sc.render.resolution_y = 768, 1344
try:
    sc.eevee.use_shadows = True; sc.eevee.use_raytracing = True
    sc.eevee.ray_tracing_options.resolution_scale = '1'
except Exception as e:
    print("eevee opts:", e)
sc.eevee.taa_render_samples = 64
os.makedirs(os.path.join(HERE, "renders"), exist_ok=True)
sc.render.filepath = os.path.join(HERE, "renders", os.environ.get("OUT", "room_render.png"))
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(HERE, "room.blend"))
bpy.ops.render.render(write_still=True)
print("WROTE room.blend + renders/room_render.png")
