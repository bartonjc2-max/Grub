"""Item facts the game reads (room_items.json schema), MEASURED from the meshes with modifiers applied.

  /Applications/Blender.app/Contents/MacOS/Blender -b --factory-startup --python measure_items.py
  ONLY=plant_bamboo,rug_daisy ...   just these variants        NO_CANON=1 ...   skip the canon room

Writes
  * every <category>/<id>/meta.json: adds / replaces the key "game" (nothing else in it is touched)
  * catalog.json: the same "game" on each variant entry (make_catalog.py keeps it when it rebuilds the catalog)
  * canon room, from ../room.blend (opened, never saved):
      GrubUnity/Assets/Grub/Room/room_items.json   the file the game loads
      canon_items.json                             the same, kept beside the store assets
Run it after build_store_assets*.py (they rewrite meta.json) and before make_rug_layer.py. A new variant needs
nothing but its <id>.blend and meta.json: about 10 s for all of them.

Unity world coordinates, metres: Unity (x, y, z) = (-blender_x, blender_z, -blender_y). A variant's "game" holds
only its own block(s); the canon file holds all of them:
  rug    {"id", "shape": "ellipse"|"rect", "centre": [x, z], "radii": [rx, rz]}    half-extents along world x, z
  plant  {"id", "height", "leafY", "bendable", "bendFrom", "potRadius", "potTop", "base": [x, z]}  (+ "leafTop")
  couch  {"id", "seatTop", "backTop", "width"}
  picL / picR  {"id"}                                 a picture fits either slot, so its "game" has both
  obstacles    [{"id", "centre": [x, z], "radius"}]   floor extras only

How each number is measured (objects are told apart by the name conventions in README.md > Naming):
  rug     bounding box of every Rug* object. shape: the convex hull of their floor outline fills an ellipse's
          bounding box to pi/4 = 0.785 and a rectangle's to 1; "rect" above 0.89, else "ellipse".
  plant   height    highest vertex of anything in the plant.
          potRadius / potTop / base   Pot_Rim: half its widest extent, its top, its centre.
          leafY     "leaves" = Leaf* objects that are not structure (names with Stem, Cane, Trunk, Branch,
                    Nodes, Moss, Pebbles, Core). The top cluster = the leaves whose tops are within 0.10 m of the
                    highest leaf top; leafY = the lowest vertex of that cluster, but never more than 0.60 m below
                    its top (a snake-plant blade runs from the soil up: only its tip counts). leafTop = its top.
          bendable  true when there is a slender stalk (an object named Stem, or with Stem / Cane in its name,
                    at least 0.35 m long and under 0.2 m thick; trunks, branches and stand legs don't count)
                    and leaves above it. Rigid or squat plants (cactus, snake plant, bonsai, succulent bowl, a pot
                    of vines on a stand) have none and come out false.
          bendFrom  the middle of the bare stalk as a fraction of the height: halfway between the pot top and
                    the lowest canopy leaf (a leaf that does not start within 0.15 m of the pot top).
  couch   seatTop   top of Sofa_Seat* (not *Base*); backTop  top of Sofa_Back* cushions (frames, rails and slats
                    only if there are no cushions); width  x extent of every Sofa_* object.
  extras  centre of the bounding box of every Extra_* object; radius = half its wider floor extent.
A variant can overrule a measurement: put {"game_overrides": {"plant": {"bendable": false}}} in its meta.json.
"""
import bpy, json, math, os
from mathutils import Vector
from mathutils.geometry import convex_hull_2d

HERE = os.path.dirname(os.path.abspath(__file__))
D3 = os.path.dirname(HERE)
GAME_ITEMS = os.path.normpath(os.path.join(D3, "..", "..", "..", "GrubUnity", "Assets", "Grub", "Room", "room_items.json"))
CATS = ["rugs", "pictures", "plants", "couches", "extras"]
ONLY = [s for s in os.environ.get("ONLY", "").split(",") if s]
CANON_IDS = {"rug": "rug_terracotta", "plant": "plant_canon", "couch": "couch_canon", "picL": "pic_canon_l", "picR": "pic_canon_r"}
STRUCTURE = ("Stem", "Cane", "Trunk", "Branch", "Nodes", "Moss", "Pebbles", "Core")
R = lambda x: round(float(x), 3)

IS = {
    "rug":   lambda n: n == "Rug" or n.startswith("Rug_"),
    "plant": lambda n: n.startswith(("Leaf", "Pot")) or n in ("Stem", "Soil"),
    "couch": lambda n: n.startswith("Sofa_"),
    "extra": lambda n: n.startswith("Extra_"),
}


def verts(obs):
    """World-space vertices of the evaluated (modifier-applied) meshes."""
    dg = bpy.context.evaluated_depsgraph_get(); out = []
    for o in obs:
        e = o.evaluated_get(dg); me = e.to_mesh()
        out += [e.matrix_world @ v.co for v in me.vertices]
        e.to_mesh_clear()
    return out

def ext(vs, i): return min(v[i] for v in vs), max(v[i] for v in vs)
def unity_xz(bx, by): return [R(-bx), R(-by)]


def rug_block(obs, vid):
    vs = verts(obs); (x0, x1), (y0, y1) = ext(vs, 0), ext(vs, 1)
    pts = [Vector((v.x, v.y)) for v in vs]; hull = [pts[i] for i in convex_hull_2d(pts)]
    area = abs(sum(hull[i].x * hull[(i + 1) % len(hull)].y - hull[(i + 1) % len(hull)].x * hull[i].y for i in range(len(hull)))) / 2
    fill = area / ((x1 - x0) * (y1 - y0))
    return {"id": vid, "shape": "rect" if fill > 0.89 else "ellipse", "centre": unity_xz((x0 + x1) / 2, (y0 + y1) / 2),
            "radii": [R((x1 - x0) / 2), R((y1 - y0) / 2)]}, {"hull_fill": R(fill)}


def plant_block(obs, vid):
    allv = verts(obs); height = ext(allv, 2)[1]
    rim = [o for o in obs if o.name == "Pot_Rim"] or [o for o in obs if o.name == "Pot"] or [o for o in obs if o.name.startswith("Pot")]
    rv = verts(rim); (x0, x1), (y0, y1) = ext(rv, 0), ext(rv, 1); pot_top = ext(rv, 2)[1]
    leaves = [o for o in obs if o.name.startswith("Leaf") and not any(s in o.name for s in STRUCTURE)]
    lz = {o.name: ext(verts([o]), 2) for o in leaves}
    top = max(z1 for _, z1 in lz.values())
    cluster = [n for n, (_, z1) in lz.items() if z1 >= top - 0.10]
    leaf_y = max(min(lz[n][0] for n in cluster), top - 0.60)
    stalks = []
    for o in obs:
        n = o.name
        if not (n == "Stem" or "Stem" in n or "Cane" in n) or "Stand" in n: continue
        sv = verts([o]); (sx0, sx1), (sy0, sy1), (sz0, sz1) = ext(sv, 0), ext(sv, 1), ext(sv, 2)
        # thickness: a stalk can arch, so judge it by its cross-section near the middle of its length
        mid = [v for v in sv if abs(v.z - (sz0 + sz1) / 2) < 0.06] or sv
        thick = max(ext(mid, 0)[1] - ext(mid, 0)[0], ext(mid, 1)[1] - ext(mid, 1)[0])
        if sz1 - sz0 >= 0.35 and thick < 0.2: stalks.append((n, sz0, sz1, thick))
    bendable = bool(stalks) and top > min(s[1] for s in stalks) + 0.35
    canopy = [z0 for z0, _ in lz.values() if z0 > pot_top + 0.15]
    bend_from = min(0.8, max(0.2, ((pot_top + min(canopy)) / 2) / height)) if canopy else 0.5
    return ({"id": vid, "height": R(height), "leafY": R(leaf_y), "leafTop": R(top), "bendable": bendable, "bendFrom": round(bend_from, 2),
             "potRadius": R(max(x1 - x0, y1 - y0) / 2), "potTop": R(pot_top), "base": unity_xz((x0 + x1) / 2, (y0 + y1) / 2)},
            {"top_cluster": sorted(cluster), "stalks": [s[0] for s in stalks], "canopy_from": R(min(canopy)) if canopy else None})


def couch_block(obs, vid):
    top = lambda sel: ext(verts(sel), 2)[1] if sel else None
    seats = [o for o in obs if o.name.startswith("Sofa_Seat") and "Base" not in o.name] or [o for o in obs if o.name.startswith("Sofa_Body")]
    backs = [o for o in obs if o.name.startswith("Sofa_Back") and not any(s in o.name for s in ("Frame", "Rail", "Slat"))] \
        or [o for o in obs if o.name.startswith("Sofa_Back")]
    x0, x1 = ext(verts(obs), 0)
    return ({"id": vid, "seatTop": R(top(seats)), "backTop": R(top(backs) if backs else top(obs)), "width": R(x1 - x0)},
            {"seat_objects": sorted(o.name for o in seats), "back_objects": sorted(o.name for o in backs), "top": R(top(obs))})


def obstacle_block(obs, vid):
    vs = verts(obs); (x0, x1), (y0, y1) = ext(vs, 0), ext(vs, 1)
    return {"id": vid, "centre": unity_xz((x0 + x1) / 2, (y0 + y1) / 2), "radius": R(max(x1 - x0, y1 - y0) / 2)}, {"height": R(ext(vs, 2)[1])}


def merge(block, over):
    if over: block.update(over)
    return block


def measure_variant(cat, vid, meta):
    """Load the variant's objects from its .blend into an empty scene and measure them."""
    for o in list(bpy.data.objects): bpy.data.objects.remove(o, do_unlink=True)
    with bpy.data.libraries.load(os.path.join(HERE, cat, vid, vid + ".blend")) as (src, dst): dst.objects = list(src.objects)
    obs = [o for o in dst.objects if o is not None and o.type == 'MESH']
    for o in obs: bpy.context.scene.collection.objects.link(o)
    bpy.context.view_layer.update()
    over = meta.get("game_overrides", {})
    if cat == "rugs":
        b, dbg = rug_block([o for o in obs if IS["rug"](o.name)], vid); game = {"rug": merge(b, over.get("rug"))}
    elif cat == "plants":
        b, dbg = plant_block([o for o in obs if IS["plant"](o.name)], vid); game = {"plant": merge(b, over.get("plant"))}
    elif cat == "couches":
        b, dbg = couch_block([o for o in obs if IS["couch"](o.name)], vid); game = {"couch": merge(b, over.get("couch"))}
    elif cat == "pictures":
        game, dbg = {"picL": {"id": vid}, "picR": {"id": vid}}, {}
    else:
        b, dbg = obstacle_block(obs, vid); game = {"obstacles": [merge(b, over.get("obstacle"))]}
    return game, dbg


def dump(obj, path):
    """One block per line, like the hand-written draft, so the file diffs cleanly."""
    lines = ["{"] + [f' {json.dumps(k)}: {json.dumps(v)}{"," if i < len(obj) - 1 else ""}' for i, (k, v) in enumerate(obj.items())] + ["}"]
    open(path, "w").write("\n".join(lines) + "\n")


# ------------------------------------------------------------------ the 37 (or however many) variants
measured = {}
for cat in CATS:
    d = os.path.join(HERE, cat)
    if not os.path.isdir(d): continue
    for vid in sorted(os.listdir(d)):
        mp = os.path.join(d, vid, "meta.json")
        if not os.path.exists(mp) or (ONLY and vid not in ONLY): continue
        meta = json.load(open(mp))
        game, dbg = measure_variant(cat, vid, meta)
        meta["game"] = game
        json.dump(meta, open(mp, "w"), indent=1)
        measured[vid] = game
        print("ITEM", vid, json.dumps(game), json.dumps(dbg))
cp = os.path.join(HERE, "catalog.json")
if os.path.exists(cp) and measured:
    cat_j = json.load(open(cp))
    for e in cat_j["variants"]:
        if e["id"] in measured: e["game"] = measured[e["id"]]
    json.dump(cat_j, open(cp, "w"), indent=1)

# ------------------------------------------------------------------ the canon room
if not os.environ.get("NO_CANON") and not ONLY:
    bpy.ops.wm.open_mainfile(filepath=os.path.join(D3, "room.blend"))          # read only: never saved
    meshes = [o for o in bpy.data.objects if o.type == 'MESH']
    pick = lambda k: [o for o in meshes if IS[k](o.name)]
    rug, d1 = rug_block(pick("rug"), CANON_IDS["rug"])
    plant, d2 = plant_block(pick("plant"), CANON_IDS["plant"])
    couch, d3 = couch_block(pick("couch"), CANON_IDS["couch"])
    obst = [obstacle_block([o], o.name)[0] for o in pick("extra")]             # none in the canon room
    canon = {"rug": rug, "plant": plant, "couch": couch, "picL": {"id": CANON_IDS["picL"]}, "picR": {"id": CANON_IDS["picR"]},
             "obstacles": obst}
    print("CANON", json.dumps(canon), json.dumps([d1, d2, d3]))
    dump(canon, os.path.join(HERE, "canon_items.json"))
    if os.path.isdir(os.path.dirname(GAME_ITEMS)): dump(canon, GAME_ITEMS); print("wrote", GAME_ITEMS)
print("MEASURE ITEMS done:", len(measured), "variants")
