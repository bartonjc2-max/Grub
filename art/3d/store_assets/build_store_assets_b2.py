"""Store asset library, batch 2: more rugs, pictures, plants and couches, plus the new "extras" category.

Imports build_store_assets.py for its helpers and its run() loop (importing it opens ../room.blend in memory;
nothing is ever saved over it). Only batch 2 ids are built here, so batch 1 folders are never touched.

  /Applications/Blender.app/Contents/MacOS/Blender -b --python build_store_assets_b2.py
  ONLY=rug_daisy,pic_house ...   CATEGORY=plants ...   PLATE_W=428 PLATE_H=926 ...   (as batch 1)

New in batch 2
  * every picture is also rendered at the PicR slot (render_picR.png / mask_picR.png);
  * meta.json carries "batch": 2 and per-category extras (plant height + grabbable leaves, couch seat and
    back-top heights, the floor position of an extra);
  * category "extras" replaces nothing: objects are named Extra_* and stand in free floor space.
"""
import os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import build_store_assets as B
from build_store_assets import *          # helpers, constants, bpy / bmesh / math / Vector / Quaternion
from mathutils import Matrix

# ------------------------------------------------------------------ small helpers
def ccw(pts):
    a = sum(pts[i][0] * pts[(i + 1) % len(pts)][1] - pts[(i + 1) % len(pts)][0] * pts[i][1] for i in range(len(pts)))
    return list(pts) if a >= 0 else list(reversed(pts))

def rot_ellipse(cx, cy, a, b, ang, n=48):
    c, s = math.cos(ang), math.sin(ang)
    return [(cx + math.cos(t) * a * c - math.sin(t) * b * s, cy + math.cos(t) * a * s + math.sin(t) * b * c)
            for t in (2 * math.pi * i / n for i in range(n))]

def blobs(name, items, m, seg=16, rings=10):
    """Several spheres in one mesh; items are (centre, radius) or (centre, radius, (sx, sy, sz))."""
    me = bpy.data.meshes.new(name); bm = bmesh.new()
    for it in items:
        c, r = Vector(it[0]), it[1]; s = it[2] if len(it) > 2 else (1, 1, 1)
        bmesh.ops.create_uvsphere(bm, u_segments=seg, v_segments=rings, radius=r,
                                  matrix=Matrix.Translation(c) @ Matrix.Diagonal((s[0], s[1], s[2], 1.0)))
    bm.to_mesh(me); bm.free()
    return new_ob(name, me, m)

def tube(name, pts, r0, r1, m, sub=None):
    """A soft tapering limb: spheres strung along a polyline (r0 at the start, r1 at the end), packed closely
    enough (half a radius apart) to read as one smooth tube."""
    pts = [Vector(p) for p in pts]; items = []
    total = sum((pts[i + 1] - pts[i]).length for i in range(len(pts) - 1)); run = 0.0
    for i in range(len(pts) - 1):
        seg = (pts[i + 1] - pts[i]).length; n = max(2, math.ceil(seg / (0.5 * min(r0, r1))))
        for j in range(n + (1 if i == len(pts) - 2 else 0)):
            k = (run + seg * j / n) / total
            items.append((pts[i].lerp(pts[i + 1], j / n), r0 + (r1 - r0) * k))
        run += seg
    return blobs(name, items, m, seg=12, rings=6)

def stick(name, a, b, r0, r1, m, seg=14):
    a, b = Vector(a), Vector(b); d = b - a
    ob = cyl(name, r0, r1, d.length, (a + b) / 2, m, seg=seg, bevel=0); aim(ob, d); return ob

# ------------------------------------------------------------------ rugs
# Batch 2 rugs stay inside x -4.6..-1.45, y -4.75..-1.85 so the mask keeps 40 px clear of the plate edges and
# the rug never reaches the couch (front of the couch is y -1.46).
R2 = (-3.0, -3.3)
CREAM = "#F7E8D8"

def rug_inlay(name, pts, m, layer=0):
    return poly(name, floor_pts(ccw(pts), RZ + 0.0008 * layer), m)

def rug_rainbow_arch():
    cx, cy, R = -3.0, -4.25, 1.55
    rug_base(ellipse(cx, cy, R, R, 96, 0, math.pi), mat("pile", CREAM, 1.0))
    bands = ((1.46, 1.21, "#D98A72"), (1.14, 0.89, "#E8B960"), (0.82, 0.57, "#8FB59A"), (0.50, 0.25, "#9DB8C7"))
    for k, (ro, ri, hexc) in enumerate(bands):
        outer = ellipse(cx, cy + 0.07, ro, ro, 80, 0, math.pi); inner = ellipse(cx, cy + 0.07, ri, ri, 80, 0, math.pi)
        rug_inlay(f"Rug_Band{k}", outer + inner[::-1], mat(f"band{k}", hexc, 1.0))

def rug_daisy():
    cx, cy = R2
    rug_base(ellipse(cx, cy, 1.45, 1.45, 160), mat("pile", "#9DB8C7", 1.0))
    petal = mat("petal", "#FBF1E2", 1.0)
    for k in range(8):
        t = math.radians(45 * k + 22.5)
        rug_inlay(f"Rug_Petal{k}", rot_ellipse(cx + math.cos(t) * 0.72, cy + math.sin(t) * 0.72, 0.46, 0.235, t), petal)
    rug_inlay("Rug_Centre", ellipse(cx, cy, 0.36, 0.36, 64), mat("centre", "#E8B960", 1.0), 1)

def rug_zigzag_runner():
    cx, cy = -3.0, -3.2
    rug_base(roundrect(cx, cy, 3.1, 1.46, 0.16), mat("pile", CREAM, 1.0))
    def zig(name, yc, hexc, phase):
        n, x0, x1, amp, th = 12, cx - 1.14, cx + 1.14, 0.10, 0.12
        p = [(x0 + (x1 - x0) * i / n, yc + (amp if (i + phase) % 2 else -amp)) for i in range(n + 1)]
        faces(name, [floor_pts(((p[i][0], p[i][1] - th / 2), (p[i + 1][0], p[i + 1][1] - th / 2),
                                (p[i + 1][0], p[i + 1][1] + th / 2), (p[i][0], p[i][1] + th / 2)), RZ) for i in range(n)],
              mat(name, hexc, 1.0))
    zig("Rug_ZigA", cy + 0.40, "#D98A72", 0); zig("Rug_ZigB", cy, "#8FB59A", 0); zig("Rug_ZigC", cy - 0.40, "#E8B960", 0)
    faces("Rug_Ends", [floor_pts(rect(cx + s * 1.36, cy, 0.11, 1.22), RZ) for s in (-1, 1)], mat("ends", "#9DB8C7", 1.0))

def cloud_outline(cx, cy, s, n=420):
    circles = [(-1.0, -0.10, 0.62), (1.02, -0.12, 0.60), (-0.48, 0.38, 0.74), (0.42, 0.50, 0.84), (0.0, -0.2, 0.85)]
    ymin, ystretch = -0.70, 1.25
    pts = []
    for i in range(n):
        t = 2 * math.pi * i / n; dx, dy = math.cos(t), math.sin(t); best = 0.0
        for ox, oy, r in circles:
            b = dx * ox + dy * oy; disc = b * b - (ox * ox + oy * oy - r * r)
            if disc >= 0: best = max(best, b + math.sqrt(disc))
        if dy < 0 and best * dy < ymin: best = ymin / dy
        pts.append((cx + dx * best * s, cy + dy * best * s * ystretch))
    return pts

def rug_cloud():
    cx, cy = -3.0, -3.58
    rug_base(cloud_outline(cx, cy, 0.95), mat("pile", "#BFD6E0", 1.0))
    rug_ring("Rug_Border", cloud_outline(cx, cy, 0.95 * 0.89), cloud_outline(cx, cy, 0.95 * 0.845), mat("border", "#FBF1E2", 1.0))

def union_outline(polys):
    key = lambda p: (round(p[0], 4), round(p[1], 4)); E = {}
    for P in polys:
        for i in range(len(P)): E[(key(P[i]), key(P[(i + 1) % len(P)]))] = P[i]
    nxt = {a: (b, pa) for (a, b), pa in E.items() if (b, a) not in E}
    start = next(iter(nxt)); out = []; k = start
    while True:
        b, pa = nxt[k]; out.append(pa); k = b
        if k == start: break
    return out

def rug_hex_patchwork():
    cx, cy = R2; R = 0.56; d = math.sqrt(3) * R
    def hexa(c, r): return [(c[0] + r * math.cos(math.pi / 6 + math.pi / 3 * k), c[1] + r * math.sin(math.pi / 6 + math.pi / 3 * k)) for k in range(6)]
    centres = [(cx, cy)] + [(cx + d * math.cos(math.pi / 3 * k), cy + d * math.sin(math.pi / 3 * k)) for k in range(6)]
    rug_base(union_outline([hexa(c, R) for c in centres]), mat("pile", CREAM, 1.0))
    cols = ["#E8B960", "#EDB5AE", "#A8C3A0", "#9DB8C7", "#D98A72", "#C9B6DC", "#8FC1B5"]
    for k, c in enumerate(centres):
        rug_inlay(f"Rug_Hex{k}", hexa(c, R * 0.86), mat(f"hex{k}", cols[k], 1.0))

# ------------------------------------------------------------------ pictures
def frame_rect(w, h, frame_hex, canvas_hex):
    rbox("PicL_Frame", (w, 0.06, h), (PX, -0.03, PZ), mat("frame", frame_hex, 0.6), 0.02, 3)
    rbox("PicL_Canvas", (w - 0.12, 0.02, h - 0.12), (PX, -0.065, PZ), mat("canvas", canvas_hex, 0.9), 0.003, 1)
    return (w - 0.12) / 2, (h - 0.12) / 2

def frame_round(d, frame_hex, canvas_hex):
    q = (math.radians(90), 0, 0)
    cyl("PicL_Frame", d / 2, d / 2, 0.06, (PX, -0.03, PZ), mat("frame", frame_hex, 0.6), seg=72, rot=q, bevel=0.02)
    cv = cyl("PicL_Canvas", d / 2 - 0.06, d / 2 - 0.06, 0.02, (PX, -0.065, PZ), mat("canvas", canvas_hex, 0.9), seg=72, rot=q, bevel=0)
    for f in cv.data.polygons: f.use_smooth = False           # flat disc: no shading gradient across the canvas
    return d / 2 - 0.06

def art2(name, pts, m, layer): return art(name, ccw(pts), m, layer)

def ground(hw, hh, top, n=40):
    return [(hw, -hh)] + [(hw - 2 * hw * i / n, top(1 - 2 * i / n)) for i in range(n + 1)] + [(-hw, -hh)]

def pic_rainbow():
    hw, hh = frame_rect(PW, PH, "#E8B960", "#FBF1E2")
    v0 = -0.08
    for k, (r, hexc) in enumerate(((0.25, "#D98A72"), (0.20, "#EFC56A"), (0.15, "#8FB59A"), (0.10, "#8FAEC4"), (0.05, "#FBF1E2"))):
        art2(f"Arc{k}", ellipse(0, v0, r, r, 56, 0, math.pi), mat(f"arc{k}", hexc), k + 1)
    white = mat("cloud", "#FFFFFF")
    for s in (-1, 1):
        for j, (u, v, r) in enumerate(((0.175, -0.005, 0.058), (0.225, -0.02, 0.040), (0.118, -0.02, 0.044))):
            art2(f"Cloud{s}{j}", ellipse(s * u, v0 + v, r, r, 32), white, 6)

def pic_house():
    hw, hh = frame_rect(PW, PH, "#C8956A", "#CFE3EA")
    art2("Sun", ellipse(-0.16, 0.24, 0.055, 0.055, 40), mat("sun", "#F0C05A"), 1)
    for j, (u, v, r) in enumerate(((0.12, 0.25, 0.04), (0.17, 0.245, 0.05), (0.215, 0.24, 0.035))):
        art2(f"Cloud{j}", ellipse(u, v, r, r, 28), mat("cloud", "#FFFFFF"), 1)
    art2("Grass", ground(hw, hh, lambda t: -0.215 + 0.02 * math.sin(2.4 * t + 0.5)), mat("grass", "#9CC48F"), 2)
    art2("Chimney", rect(0.095, 0.10, 0.05, 0.12), mat("chimney", "#B8794F"), 3)
    art2("Wall", rect(0, -0.12, 0.27, 0.22), mat("wall", "#FFF3E0"), 3)
    art2("Roof", [(-0.18, -0.015), (0.18, -0.015), (0.0, 0.15)], mat("roof", "#D9806A"), 4)
    art2("Door", roundrect(-0.055, -0.175, 0.075, 0.115, 0.03, 6), mat("door", "#B8794F"), 4)
    art2("Window", rect(0.065, -0.10, 0.075, 0.075), mat("window", "#7F9FB5"), 4)

def pic_cactus():
    hw, hh = frame_rect(PW, PH, "#9DB8C7", "#FBEFD9")
    g = mat("cactus", "#7DB58A")
    art2("Halo", ellipse(0, 0.04, 0.215, 0.215, 64), mat("halo", "#F6D7B4"), 1)
    art2("Body", roundrect(0, 0.04, 0.13, 0.36, 0.064, 10), g, 2)
    art2("ArmL0", roundrect(-0.10, 0.0, 0.14, 0.052, 0.025, 6), g, 2); art2("ArmL1", roundrect(-0.148, 0.05, 0.052, 0.15, 0.025, 6), g, 2)
    art2("ArmR0", roundrect(0.10, 0.07, 0.14, 0.052, 0.025, 6), g, 2); art2("ArmR1", roundrect(0.148, 0.115, 0.052, 0.14, 0.025, 6), g, 2)
    art2("Flower", ellipse(0, 0.235, 0.042, 0.042, 28), mat("flower", "#F2A0B0"), 3)
    art2("Pot", [(-0.10, -0.28), (0.10, -0.28), (0.135, -0.13), (-0.135, -0.13)], mat("pot", "#D98A72"), 3)
    art2("PotRim", roundrect(0, -0.12, 0.31, 0.05, 0.02, 5), mat("potrim", "#C97A62"), 4)

def pic_mountain_sun():
    hw, hh = frame_rect(0.84, 0.62, "#B8794F", "#FBE3C4")
    art2("Sun", ellipse(0.17, 0.10, 0.075, 0.075, 48), mat("sun", "#F0875A"), 1)
    art2("PeakBack", [(-0.02, -hh), (hw, -hh), (hw, -0.10), (0.19, 0.07)], mat("peakback", "#C9A0B4"), 2)
    art2("PeakFront", [(-hw, -hh), (0.14, -hh), (-0.11, 0.15)], mat("peakfront", "#7F9FB5"), 3)
    art2("Snow", [(-0.11, 0.15), (-0.185, 0.03), (-0.14, 0.055), (-0.11, 0.02), (-0.08, 0.055), (-0.036, 0.03)], mat("snow", "#FBF1E2"), 4)
    art2("Meadow", ground(hw, hh, lambda t: -0.185 + 0.022 * math.sin(3.0 * t + 1.0)), mat("meadow", "#8FB59A"), 5)

def pic_fruit_bowl():
    r = frame_round(0.76, "#E8A9A0", "#FBF1DF")
    th = math.asin(0.13 / (r - 0.002))
    art2("Table", ellipse(0, 0, r - 0.002, r - 0.002, 60, math.pi + th, 2 * math.pi - th), mat("table", "#EBC9A8"), 1)
    art2("Pear", ellipse(0.0, 0.065, 0.066, 0.075, 40), mat("pear", "#A9CC7F"), 2)
    art2("Leaf", rot_ellipse(0.045, 0.155, 0.045, 0.02, math.radians(35), 24), mat("leaf", "#6FA86A"), 2)
    art2("Orange", ellipse(-0.075, 0.0, 0.078, 0.078, 40), mat("orange", "#F0A35A"), 3)
    art2("Apple", ellipse(0.075, -0.005, 0.072, 0.072, 40), mat("apple", "#E57F7F"), 4)
    art2("Bowl", ellipse(0, -0.055, 0.20, 0.15, 48, math.pi, 2 * math.pi), mat("bowl", "#8FAEC4"), 5)
    art2("BowlFoot", roundrect(0, -0.205, 0.11, 0.03, 0.012, 4), mat("bowl", "#8FAEC4"), 5)

# ------------------------------------------------------------------ plants
SOIL = Vector((PPX, PPY, 0.0))
def pp(dx, dy, z): return Vector((PPX + dx, PPY + dy, z))

def monstera_leaf(name, R, m, loc, normal, roll):
    n, pts = 150, []
    for i in range(n):
        t = 2 * math.pi * i / n; d = abs(((math.degrees(t) + 180) % 360) - 180)       # degrees from the tip
        r = R * (0.80 + 0.20 * math.cos(math.radians(d)))
        r *= 1 - 0.50 * math.exp(-((180 - d) / 15) ** 2)                               # the heart dent at the stalk
        for dn in (48, 86, 124): r *= 1 - 0.46 * math.exp(-((d - dn) / 5.0) ** 2)      # the splits
        pts.append((math.sin(t) * r * 0.98, -math.cos(t) * r, 0.0))
    ob = poly(name, pts, m, extrude=(0, 0, 0.028), bevel=0.011)
    ob.location = loc; aim(ob, normal); ob.rotation_quaternion = ob.rotation_quaternion @ Quaternion((0, 0, 1), roll)
    return Vector(loc) + ob.rotation_quaternion @ Vector((0, 0.30 * R, 0.0))             # where the stalk meets the leaf

def plant_monstera():
    z = pot(0.36, 0.46, 0.62, "#E3A587")
    ga, gb, st = mat("leafA", "#5FA06E", 0.6), mat("leafB", "#7DB884", 0.6), mat("stem", "#5E9468", 0.7)
    leaves = [  # offset from the pot, normal, roll (0 = tip down), size
        ((0.04, -0.06, 1.905), (-0.25, -0.85, 0.40), 2.75, 0.40),
        ((-0.47, -0.16, 1.47), (-0.55, -0.70, 0.45), 1.10, 0.38),
        ((0.44, -0.14, 1.58), (0.35, -0.80, 0.45), -1.15, 0.37),
        ((-0.04, -0.44, 1.14), (-0.10, -0.62, 0.78), 0.10, 0.33),
        ((-0.26, 0.16, 1.74), (-0.35, -0.80, 0.42), -2.5, 0.31),
    ]
    for k, (off, nrm, roll, R) in enumerate(leaves):
        tip = monstera_leaf(f"Leaf{k}", R, ga if k % 2 == 0 else gb, pp(*off), nrm, roll)
        base = pp(off[0] * 0.18, off[1] * 0.18, z - 0.03)
        tube(f"Leaf_Stem{k}", [base, base.lerp(tip, 0.55) + Vector((0, 0.04, 0.10)), tip + Vector((0, 0.012, 0))], 0.026, 0.02, st)

def plant_bonsai():
    wood = mat("wood", "#C8956A", 0.55); bark = mat("bark", "#8A6244", 0.8)
    rbox("Pot_Stand", (0.96, 0.62, 0.07), (PPX, PPY, 0.405), wood, 0.025, 4)
    for i in (-1, 1):
        for j in (-1, 1):
            cyl(f"Pot_StandLeg{i}{j}", 0.035, 0.048, 0.38, (PPX + i * 0.38, PPY + j * 0.22, 0.19), wood, seg=16, bevel=0)
    p = mat("pot", "#7FB3A8", 0.7)
    rbox("Pot", (0.70, 0.44, 0.20), (PPX, PPY, 0.54), p, 0.06, 5)
    rbox("Pot_Rim", (0.76, 0.50, 0.055), (PPX, PPY, 0.645), p, 0.022, 4)
    rbox("Soil", (0.66, 0.40, 0.02), (PPX, PPY, 0.668), mat("soil", "#6B4A36", 0.9), 0.004, 1)
    blobs("Leaf_Moss", [(pp(-0.12, 0.0, 0.675), 0.14, (1, 0.9, 0.35)), (pp(0.16, -0.05, 0.672), 0.09, (1, 1, 0.35))], mat("moss", "#93C487", 0.8))
    trunk = [pp(-0.12, 0, 0.68), pp(-0.11, 0, 0.82), pp(-0.03, 0, 0.93), pp(0.08, 0, 1.01), pp(0.10, 0, 1.11), pp(0.03, 0, 1.21), pp(-0.06, 0, 1.30), pp(-0.08, 0, 1.40)]
    tube("Leaf_Trunk", trunk, 0.085, 0.045, bark)
    tube("Leaf_BranchR", [pp(0.08, 0, 1.01), pp(0.24, -0.02, 1.06), pp(0.38, -0.03, 1.15)], 0.045, 0.03, bark)
    tube("Leaf_BranchL", [pp(0.03, 0, 1.21), pp(-0.18, -0.02, 1.22), pp(-0.36, -0.03, 1.27)], 0.04, 0.028, bark)
    ga, gb = mat("leafA", "#6FA86A", 0.6), mat("leafB", "#93C487", 0.6)
    def pad(name, c, r):
        c = Vector(c)
        blobs(name + "A", [(c, r, (1, 0.9, 0.5)), (c + Vector((-r * 0.55, -0.02, -0.03)), r * 0.62, (1, 0.9, 0.55))], ga, seg=24, rings=12)
        blobs(name + "B", [(c + Vector((r * 0.5, -0.04, 0.03)), r * 0.66, (1, 0.9, 0.55)), (c + Vector((-0.02, -0.06, r * 0.3)), r * 0.6, (1, 0.9, 0.55))], gb, seg=24, rings=12)
    pad("Leaf_PadTop", pp(-0.08, 0, 1.50), 0.30); pad("Leaf_PadR", pp(0.42, -0.03, 1.21), 0.21); pad("Leaf_PadL", pp(-0.42, -0.03, 1.33), 0.20)

def plant_tulips():
    z = pot(0.30, 0.40, 0.52, "#9DB8C7")
    g = mat("stem", "#6FA86A", 0.6); gl = mat("leaf", "#8CBF7A", 0.6)
    flowers = (((-0.21, -0.03, 1.36), "#F08F8F"), ((0.02, 0.02, 1.62), "#F0C05A"), ((0.23, -0.05, 1.27), "#C7A5DC"))
    for k, (top, hexc) in enumerate(flowers):
        base = pp(top[0] * 0.35, top[1] * 0.35, z - 0.03); head = pp(*top)
        tube(f"Leaf_Stem{k}", [base, base.lerp(head, 0.5) + Vector((top[0] * 0.08, 0, 0)), head], 0.024, 0.02, g)
        m = mat(f"flower{k}", hexc, 0.7)
        items = [(head + Vector((0, 0, 0.10)), 0.125, (1, 1, 1.25))]
        for j in range(3):
            t = math.radians(120 * j + 90 + 40 * k)
            items.append((head + Vector((math.cos(t) * 0.07, math.sin(t) * 0.07, 0.19)), 0.085, (0.95, 0.95, 1.55)))
        blobs(f"Leaf_Tulip{k}", items, m, seg=24, rings=14)
        for j, sgn in enumerate((-1, 1)):
            yaw = math.radians(200 * k + 70 + (0 if sgn < 0 else 170)); lean = math.radians(20 + 5 * j); L = 0.74 - 0.08 * j + 0.06 * (k == 1)
            d = Vector((math.cos(yaw) * math.sin(lean), math.sin(yaw) * math.sin(lean), math.cos(lean)))
            ob = sphere(f"Leaf{k}{j}", 1.0, base + d * L * 0.5, gl, scale=(0.095, 0.03, L * 0.5), seg=20, rings=14)
            aim(ob, d); ob.rotation_quaternion = ob.rotation_quaternion @ Quaternion((0, 0, 1), yaw)

def plant_bamboo():
    z = pot(0.38, 0.43, 0.42, "#F1DFC9", soil_hex="#CFC4B4")
    cane, node, leaf = mat("cane", "#A9CC7F", 0.6), mat("node", "#6FA86A", 0.6), mat("leafA", "#5FA06E", 0.6)
    leaf2 = mat("leafB", "#8CBF7A", 0.6)
    canes = ((-0.13, 0.05, 1.93, 0.050, -2), (0.07, 0.09, 1.74, 0.046, 2), (0.17, -0.08, 1.47, 0.042, 3), (-0.03, -0.13, 1.17, 0.040, -1), (-0.21, -0.09, 0.90, 0.036, -3))
    n = 0
    for k, (dx, dy, Ht, r, lean) in enumerate(canes):
        a = pp(dx, dy, z - 0.03); b = pp(dx + math.tan(math.radians(lean)) * (Ht - z), dy, Ht)
        stick(f"Leaf_Cane{k}", a, b, r, r * 0.9, cane, seg=20)
        rings = []
        zz = z + 0.22
        while zz < Ht - 0.08:
            rings.append((a.lerp(b, (zz - a.z) / (b.z - a.z)), r + 0.012, (1, 1, 0.38))); zz += 0.29
        rings.append((b, r * 0.95, (1, 1, 0.5)))
        blobs(f"Leaf_Nodes{k}", rings, node, seg=20, rings=8)
        tuft = [(b, yaw + 37 * k, 38) for yaw in (0, 120, 240)] + [(b, 60 + 37 * k, 12)]
        tuft += [(a.lerp(b, f), yaw, 55) for f, yaw in ((0.62, 200 + 80 * k), (0.80, 20 + 80 * k))] if Ht > 1.3 else []
        for (p0, yaw, tilt) in tuft:
            yr, tr = math.radians(yaw), math.radians(tilt); L = 0.34 if tilt < 50 else 0.30
            d = Vector((math.cos(yr) * math.sin(tr), math.sin(yr) * math.sin(tr), math.cos(tr)))
            ob = sphere(f"Leaf{n}", 1.0, p0 + d * (L * 0.5 + 0.02), leaf if n % 2 else leaf2, scale=(0.062, 0.016, L * 0.5), seg=16, rings=10)
            aim(ob, d); n += 1

def plant_succulent_bowl():
    wood = mat("wood", "#C8956A", 0.55)
    cyl("Pot_StandTop", 0.37, 0.37, 0.05, (PPX, PPY, 0.435), wood)
    for k in range(3):
        t = math.radians(90 + 120 * k)
        stick(f"Pot_StandLeg{k}", pp(math.cos(t) * 0.33, math.sin(t) * 0.33, 0.0), pp(math.cos(t) * 0.22, math.sin(t) * 0.22, 0.42), 0.028, 0.038, wood, seg=16)
    p = mat("pot", "#EDB5AE", 0.7); zb = 0.46
    cyl("Pot", 0.27, 0.47, 0.25, (PPX, PPY, zb + 0.125), p)
    cyl("Pot_Rim", 0.495, 0.495, 0.055, (PPX, PPY, zb + 0.25), p, bevel=0.02)
    cyl("Soil", 0.455, 0.455, 0.02, (PPX, PPY, zb + 0.275), mat("soil", "#E2CDA8", 0.9), bevel=0)
    zs = zb + 0.285
    mint, mint2 = mat("mint", "#9CCBB0", 0.6), mat("mint2", "#7DB58A", 0.6)
    c = pp(-0.10, -0.06, zs); n = 0
    for ring, (count, tilt, L, rad) in enumerate(((9, 68, 0.27, 0.05), (7, 42, 0.25, 0.035), (4, 16, 0.22, 0.02))):
        for j in range(count):
            yr, tr = math.radians(360 * j / count + 20 * ring), math.radians(tilt)
            d = Vector((math.cos(yr) * math.sin(tr), math.sin(yr) * math.sin(tr), math.cos(tr)))
            ob = sphere(f"Leaf_Rosette{n}", 1.0, c + Vector((math.cos(yr) * rad, math.sin(yr) * rad, 0.02)) + d * L * 0.5,
                        mint if ring != 1 else mint2, scale=(0.078, 0.034, L * 0.5), seg=16, rings=10)
            aim(ob, d); n += 1
    blobs("Leaf_Ball", [(pp(0.26, -0.12, zs + 0.085), 0.115, (1, 1, 0.9)), (pp(0.30, 0.10, zs + 0.06), 0.08)], mat("ball", "#6FA86A", 0.7), seg=24, rings=14)
    blobs("Leaf_BallFlower", [(pp(0.26, -0.12, zs + 0.195), 0.04, (1, 1, 0.7))], mat("flower", "#F2A0B0", 0.7))
    fingers = [(pp(0.05 + 0.06 * i, 0.24, zs + 0.11 + 0.03 * (i % 2)), 0.05, (1, 1, 2.6 + 0.6 * (i % 2))) for i in range(-1, 2)]
    blobs("Leaf_Fingers", fingers, mat("finger", "#B7D69A", 0.6), seg=18, rings=12)
    blobs("Leaf_Pebbles", [(pp(-0.02, -0.36, zs), 0.04, (1, 1, 0.6)), (pp(0.10, -0.33, zs), 0.03, (1, 1, 0.6)), (pp(-0.36, 0.14, zs), 0.035, (1, 1, 0.6))],
          mat("pebble", "#FBF1E2", 0.8))

# ------------------------------------------------------------------ couches
def couch_lilac_blanket():
    f = mat("fabric", "#C4B2DC", 0.92); arm = 0.40; inw = SW - 2 * arm
    pillow("Sofa_Body", (SW - 0.04, 1.08, 0.30), (SX, YC, 0.29), f, 0.6)
    for i in (-1, 1):
        pillow(f"Sofa_Arm{i}", (arm, 1.10, 0.76), (SX + i * (SW / 2 - arm / 2), YC, 0.52), f, 0.30)
    pillow("Sofa_Seat0", (inw - 0.02, 0.88, 0.30), (SX, YF + 0.45, SEAT_TOP - 0.15), f, 0.5)
    pillow("Sofa_BackFrame", (inw + 0.04, 0.26, 1.04), (SX, YB - 0.13, 0.66), f, 0.6)
    for k in (-1, 0, 1):
        pillow(f"Sofa_Back{k}", (inw / 3 - 0.01, 0.36, 0.74), (SX + k * inw / 3, YB - 0.33, 1.01), f, 0.22, rot=(math.radians(-8), 0, 0))
    ax = SX + (SW / 2 - arm / 2)                              # the blanket hangs over the right-hand arm
    pillow("Sofa_Blanket", (arm + 0.06, 0.66, 0.60), (ax, YC - 0.14, 0.615), mat("blanket", "#FBF1E2", 0.95), 0.55)
    for j, dy in enumerate((-0.19, 0.19)):
        pillow(f"Sofa_BlanketStripe{j}", (arm + 0.075, 0.085, 0.615), (ax, YC - 0.14 + dy, 0.615), mat("stripe", "#D98A72", 0.95), 0.55)
    sofa_legs(mat("wood", "#C8956A", 0.55))

def couch_green_corduroy():
    f = mat("fabric", "#8DB58C", 0.95); arm = 0.34; inw = SW - 2 * arm; N = 8; w = inw / N
    pillow("Sofa_Body", (SW - 0.04, 1.08, 0.30), (SX, YC, 0.29), f, 0.6)
    pillow("Sofa_BackFrame", (inw + 0.04, 0.26, 1.04), (SX, YB - 0.13, 0.66), f, 0.6)
    pillow("Sofa_SeatBase", (inw, 0.84, 0.22), (SX, YF + 0.47, SEAT_TOP - 0.17), f, 0.6)
    for i in (-1, 1):
        ax = SX + i * (SW / 2 - arm / 2)
        pillow(f"Sofa_Arm{i}", (arm, 1.10, 0.74), (ax, YC, 0.51), f, 0.45)
        for j in range(4):                                    # ribs run over the arm tops too
            cyl(f"Sofa_ArmRib{i}{j}", 0.052, 0.052, 1.04, (ax + (j - 1.5) * 0.078, YC, 0.865), f, seg=16, rot=(math.radians(90), 0, 0), bevel=0.03)
    for k in range(N):
        x = SX - inw / 2 + (k + 0.5) * w
        pillow(f"Sofa_Seat{k}", (w + 0.012, 0.88, 0.30), (x, YF + 0.45, SEAT_TOP - 0.15), f, 0.32)
        pillow(f"Sofa_Back{k}", (w + 0.012, 0.34, 0.72), (x, YB - 0.34, 1.00), f, 0.32, rot=(math.radians(-8), 0, 0))
    sofa_legs(mat("wood", "#A9744F", 0.55))

def couch_cream_cushions():
    f = mat("fabric", "#F6EAD8", 0.92); base = mat("base", "#E4CBAA", 0.92); arm = 0.27; inw = SW - 2 * arm
    pillow("Sofa_Body", (SW - 0.04, 1.08, 0.30), (SX, YC, 0.29), base, 0.6)
    for i in (-1, 1):
        pillow(f"Sofa_Arm{i}", (arm, 1.10, 0.86), (SX + i * (SW / 2 - arm / 2), YC, 0.57), f, 0.55)
    pillow("Sofa_BackFrame", (inw + 0.04, 0.26, 1.04), (SX, YB - 0.13, 0.66), f, 0.6)
    for k in (-1, 0, 1):
        cx = SX + k * inw / 3
        pillow(f"Sofa_Seat{k}", (inw / 3 - 0.02, 0.88, 0.30), (cx, YF + 0.45, SEAT_TOP - 0.15), f, 0.5)
        pillow(f"Sofa_Back{k}", (inw / 3 - 0.03, 0.32, 0.62), (cx, YB - 0.34, 0.97), f, 0.42, rot=(math.radians(-8), 0, 0))
    pillow("Sofa_CushionA", (0.50, 0.17, 0.50), (SX - 0.86, YB - 0.64, SEAT_TOP + 0.235), mat("cushionA", "#D98A72", 0.92), 0.25,
           rot=(math.radians(-16), 0, math.radians(10)))
    sphere("Sofa_CushionB", 0.24, (SX + 0.84, YB - 0.64, SEAT_TOP + 0.215), mat("cushionB", "#8FAEC4", 0.92), scale=(1, 0.45, 1),
           rot=(math.radians(-14), 0, math.radians(-10)))
    sofa_legs(mat("wood", "#A9744F", 0.55))

def couch_futon():
    wood = mat("wood", "#C8956A", 0.55); f = mat("fabric", "#DF9478", 0.92); btn = mat("button", "#FBF1E2", 0.9)
    tilt = math.radians(-12)
    rbox("Sofa_Body", (SW, 1.10, 0.08), (SX, YC, 0.38), wood, 0.03, 5)
    for k in range(5):                                        # slatted back
        rbox(f"Sofa_BackSlat{k}", (0.16, 0.06, 0.86), (SX + (k - 2) * (SW - 0.16) / 4, YB - 0.085, 0.80), wood, 0.025, 4, rot=(tilt, 0, 0))
    rbox("Sofa_BackRail", (SW, 0.07, 0.09), (SX, YB - 0.085 + math.sin(-tilt) * 0.40, 0.80 + math.cos(tilt) * 0.40), wood, 0.03, 4, rot=(tilt, 0, 0))
    pillow("Sofa_Seat0", (SW - 0.06, 1.00, 0.30), (SX, YF + 0.52, SEAT_TOP - 0.15), f, 0.45)
    bc = Vector((SX, YB - 0.27, 1.00)); R = Matrix.Rotation(tilt, 4, 'X')
    pillow("Sofa_Back0", (SW - 0.06, 0.26, 0.78), bc, f, 0.45, rot=(tilt, 0, 0))
    items = []
    for i in range(-2, 3):
        for j in (-1, 1):
            items.append(((SX + i * 0.60, YF + 0.50 + j * 0.22, SEAT_TOP - 0.012), 0.042, (1, 1, 0.45)))
            items.append((bc + R @ Vector((i * 0.60, -0.122, j * 0.18)), 0.042, (1, 0.45, 1)))
    blobs("Sofa_Buttons", items, btn, seg=14, rings=8)
    pillow("Sofa_Cushion", (0.56, 0.18, 0.40), (SX - 1.08, YB - 0.56, SEAT_TOP + 0.185), mat("cushion", "#F0C05A", 0.92), 0.3,
           rot=(math.radians(-20), 0, math.radians(8)))
    sofa_legs(wood, h=0.34, inset=0.18)

# ------------------------------------------------------------------ extras (new category; replace nothing)
# Free floor near the right-hand wall. SLOT_CORNER is the gap between the plant and the door, against the back
# wall; SLOT_FLOOR is open floor right of the rug, about 2 m out from the door (low items only).
SLOT_CORNER = (-0.22, -0.50)
SLOT_FLOOR = (-0.42, -2.55)

def extra_side_table():
    x, y = SLOT_CORNER; wood = mat("wood", "#C8956A", 0.55)
    cyl("Extra_TableTop", 0.25, 0.25, 0.05, (x, y, 0.60), wood, bevel=0.02)
    cyl("Extra_TableShelf", 0.17, 0.17, 0.035, (x, y, 0.26), wood, bevel=0.012)
    for k in range(3):
        t = math.radians(90 + 120 * k)
        stick(f"Extra_TableLeg{k}", (x + math.cos(t) * 0.22, y + math.sin(t) * 0.22, 0.0), (x + math.cos(t) * 0.17, y + math.sin(t) * 0.17, 0.585), 0.022, 0.03, wood)
    cyl("Extra_Cup", 0.05, 0.062, 0.10, (x - 0.07, y - 0.05, 0.675), mat("cup", "#9CCBB0", 0.6), seg=32, bevel=0.012)
    rbox("Extra_BookA", (0.20, 0.15, 0.035), (x + 0.07, y + 0.03, 0.643), mat("bookA", "#D98A72", 0.8), 0.008, 2, rot=(0, 0, math.radians(18)))
    rbox("Extra_BookB", (0.17, 0.13, 0.03), (x + 0.07, y + 0.03, 0.676), mat("bookB", "#E8B960", 0.8), 0.008, 2, rot=(0, 0, math.radians(-8)))

def extra_toy_box():
    x, y = SLOT_FLOOR; yaw = math.radians(-12); R = Matrix.Rotation(yaw, 4, 'Z')
    def at(dx, dy, z): return Vector((x, y, 0)) + R @ Vector((dx, dy, z))
    box = mat("box", "#9DB8C7", 0.8); trim = mat("trim", "#FBF1E2", 0.8)
    w, d, h, t = 0.66, 0.46, 0.34, 0.045
    rbox("Extra_BoxFloor", (w, d, t), at(0, 0, t / 2 + 0.005), box, 0.015, 3, rot=(0, 0, yaw))
    for s in (-1, 1):
        rbox(f"Extra_BoxSide{s}", (t, d, h), at(s * (w - t) / 2, 0, h / 2 + 0.005), box, 0.018, 3, rot=(0, 0, yaw))
        rbox(f"Extra_BoxFace{s}", (w, t, h), at(0, s * (d - t) / 2, h / 2 + 0.005), box, 0.018, 3, rot=(0, 0, yaw))
    rbox("Extra_BoxBand", (w + 0.012, d + 0.012, 0.05), at(0, 0, h - 0.03), trim, 0.015, 3, rot=(0, 0, yaw))
    blobs("Extra_ToyStar", [(at(0, -d / 2 - 0.004, 0.16), 0.055, (1, 0.25, 1))], mat("star", "#F0C05A", 0.8))
    sphere("Extra_ToyBall", 0.135, at(-0.15, 0.02, h + 0.04), mat("ball", "#F08F8F", 0.7), seg=28, rings=14)
    rbox("Extra_ToyBlockA", (0.15, 0.15, 0.15), at(0.14, -0.05, h + 0.03), mat("blockA", "#E8B960", 0.8), 0.02, 3, rot=(math.radians(14), math.radians(10), yaw + 0.5))
    rbox("Extra_ToyBlockB", (0.13, 0.13, 0.13), at(0.07, 0.10, h + 0.02), mat("blockB", "#8FB59A", 0.8), 0.02, 3, rot=(math.radians(-12), 0, yaw - 0.3))
    for k, (r, hexc) in enumerate(((0.085, "#D98A72"), (0.07, "#E8B960"), (0.055, "#8FB59A"))):   # ring stacker beside the box
        sphere(f"Extra_ToyRing{k}", r, at(-0.22, -0.42, 0.045 + 0.075 * k), mat(f"ring{k}", hexc, 0.7), scale=(1, 1, 0.5), seg=24, rings=10)
    sphere("Extra_ToyRingTop", 0.035, at(-0.22, -0.42, 0.255), mat("ringtop", "#FBF1E2", 0.7), seg=16, rings=8)

def extra_floor_cushion():
    x, y = SLOT_FLOOR
    sphere("Extra_CushionBase", 0.46, (x, y, 0.135), mat("base", "#8FB59A", 0.95), scale=(1, 1, 0.30), seg=40, rings=16)
    sphere("Extra_CushionTop", 0.39, (x + 0.03, y - 0.02, 0.345), mat("top", "#EDB5AE", 0.95), scale=(1, 1, 0.30), seg=40, rings=16)
    blobs("Extra_CushionButton", [((x + 0.03, y - 0.02, 0.455), 0.045, (1, 1, 0.45))], mat("button", "#FBF1E2", 0.9))
    faces_n = 10
    piping = [((x + math.cos(2 * math.pi * k / faces_n) * 0.455, y + math.sin(2 * math.pi * k / faces_n) * 0.455, 0.135), 0.028) for k in range(faces_n)]
    blobs("Extra_CushionKnots", piping, mat("knot", "#FBF1E2", 0.9), seg=12, rings=8)

# ------------------------------------------------------------------ meta extras
def vz(obs):
    """True lowest / highest z over the evaluated (modifier-applied) vertices; bound boxes of tilted parts overshoot."""
    dg = bpy.context.evaluated_depsgraph_get(); lo, hi = 1e9, -1e9
    for o in obs:
        e = o.evaluated_get(dg); me = e.to_mesh()
        for v in me.vertices:
            z = (e.matrix_world @ v.co).z; lo = min(lo, z); hi = max(hi, z)
        e.to_mesh_clear()
    return round(lo, 3), round(hi, 3)

def _z(obs, test):
    sel = [o for o in obs if test(o.name)]
    return vz(sel)[1] if sel else None

def plant_meta(obs):
    grab = []
    for o in obs:
        if o.name.startswith("Leaf") and not any(s in o.name for s in ("Stem", "Cane", "Trunk", "Branch", "Nodes", "Moss")):
            l, h = vz([o])
            if h >= 2.0: grab.append({"object": o.name, "z_min": l, "z_max": h})
    return {"height_m": vz(obs)[1], "canon_height_m": 2.28, "grabbable_leaf": bool(grab),
            "grab_note": ("leaf objects reaching 2.0 m or more (canon grab leaves span 1.78-2.28 m)" if grab else
                          "no leaf near the canon grab height; the jump-and-grab would need a new target height"),
            "grab_leaves": grab}

def couch_meta(obs):
    lo, hi = world_bbox(obs)
    return {"seat_top_m": _z(obs, lambda n: n.startswith("Sofa_Seat") and "Base" not in n),
            "back_top_m": _z(obs, lambda n: n.startswith("Sofa_Back")), "top_m": vz(obs)[1],
            "width_m": round(hi[0] - lo[0], 3), "canon": {"seat_top_m": 0.72, "back_top_m": 1.34, "width_m": 3.18}}

def extra_meta(slot, note):
    def f(obs):
        lo, hi = world_bbox(obs)
        return {"position_xy": list(slot), "height_m": vz(obs)[1], "footprint_m": [round(hi[0] - lo[0], 3), round(hi[1] - lo[1], 3)], "placement_note": note}
    return f

P = {"picR": True}; PL = {"extra": plant_meta}; C = {"extra": couch_meta}
VARIANTS_B2 = [
    ("rugs", "rug_rainbow_arch", "rug", "Rainbow Arch Rug", "Half-round cream rug with four rainbow bands, flat edge toward the camera.", rug_rainbow_arch),
    ("rugs", "rug_daisy", "rug", "Daisy Rug", "Round dusty-blue rug with a big cream daisy and a mustard centre.", rug_daisy),
    ("rugs", "rug_zigzag_runner", "rug", "Zigzag Runner", "Long cream runner with terracotta, sage and mustard zigzags and blue end bands.", rug_zigzag_runner),
    ("rugs", "rug_cloud", "rug", "Cloud Rug", "Cloud-shaped pale-blue rug with a cream inset line.", rug_cloud),
    ("rugs", "rug_hex_patchwork", "rug", "Hexagon Patchwork Rug", "Seven pastel hexagons on a cream honeycomb base.", rug_hex_patchwork),
    ("pictures", "pic_rainbow", "picL", "Rainbow", "A four-band rainbow with a cloud at each foot, mustard frame.", pic_rainbow, P),
    ("pictures", "pic_house", "picL", "Little House", "A cream house with a terracotta roof under a sun and cloud, light wood frame.", pic_house, P),
    ("pictures", "pic_cactus", "picL", "Potted Cactus", "A drawn two-armed cactus in a terracotta pot, dusty-blue frame.", pic_cactus, P),
    ("pictures", "pic_mountain_sun", "picL", "Mountain Sun", "Landscape frame: snow-capped blue peak, mauve ridge and an orange sun, dark wood frame.", pic_mountain_sun, P),
    ("pictures", "pic_fruit_bowl", "picL", "Fruit Bowl", "Round frame: a blue bowl with an orange, an apple and a pear, blush frame.", pic_fruit_bowl, P),
    ("plants", "plant_monstera", "plant", "Monstera", "Five big split leaves on arching stalks in a soft terracotta pot; as tall as the canon plant.", plant_monstera, PL),
    ("plants", "plant_bonsai", "plant", "Bonsai", "A small S-curved bonsai with three leaf pads in a teal tray on a low wooden stand.", plant_bonsai, PL),
    ("plants", "plant_tulips", "plant", "Tulip Pot", "Three tulips (coral, yellow, lilac) in a dusty-blue pot.", plant_tulips, PL),
    ("plants", "plant_bamboo", "plant", "Bamboo", "A cluster of five bamboo canes with leaf tufts in a cream planter; as tall as the canon plant.", plant_bamboo, PL),
    ("plants", "plant_succulent_bowl", "plant", "Succulent Bowl", "A blush bowl of succulents on a low three-legged stand.", plant_succulent_bowl, PL),
    ("couches", "couch_lilac_blanket", "couch", "Lilac Sofa", "Rounded lilac sofa with a striped cream blanket over the right arm.", couch_lilac_blanket, C),
    ("couches", "couch_green_corduroy", "couch", "Corduroy Sofa", "Sage-green sofa with ribbed seat, back and arm tops (ribs are geometry).", couch_green_corduroy, C),
    ("couches", "couch_cream_cushions", "couch", "Cream Sofa", "Cream three-seater with a terracotta square cushion and a blue round one.", couch_cream_cushions, C),
    ("couches", "couch_futon", "couch", "Futon", "Coral buttoned futon mattress on a slatted wooden frame, no arms.", couch_futon, C),
    ("extras", "extra_side_table", None, "Side Table", "Small round three-legged table with a cup and two books.", extra_side_table,
     {"extra": extra_meta(SLOT_CORNER, "corner gap between the plant and the door frame, 0.5 m from the back wall")}),
    ("extras", "extra_toy_box", None, "Toy Box", "Open dusty-blue toy box with a ball and blocks, and a ring stacker beside it.", extra_toy_box,
     {"extra": extra_meta(SLOT_FLOOR, "open floor right of the rug, about 2 m out from the door; shares its slot with the floor cushion")}),
    ("extras", "extra_floor_cushion", None, "Floor Cushions", "Two stacked round floor cushions, sage and blush.", extra_floor_cushion,
     {"extra": extra_meta(SLOT_FLOOR, "open floor right of the rug, about 2 m out from the door; shares its slot with the toy box")}),
]

if __name__ == "__main__":
    run(VARIANTS_B2, batch=2)
