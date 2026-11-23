"""render_picR.png / mask_picR.png for picture variants that only have the PicL-slot render (batch 1).

The same picture at the right-hand slot, made exactly as build_store_assets_b2.py does it (build_store_assets
run(): PICR_OFFSET x +1.15, z -0.05, scaled 0.9 in x and z about the picture centre, canon PicR hidden, canon
PicL back in place), but from the objects already in <id>.blend, so nothing is rebuilt and the existing
render.png / mask.png / <id>.blend are not touched. Adds "picR" to meta.json. Pictures that already have
render_picR.png are skipped (FORCE=1 redoes them); ONLY=pic_moon,... limits it. About 10 s per picture.
  /Applications/Blender.app/Contents/MacOS/Blender -b --python render_picr.py
Then python3 make_catalog.py (adds the files and bbox_picR to the catalog).
"""
import os, sys, json
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import build_store_assets as B                      # opens ../room.blend in memory (never saved), canon renamed CANON_*
import bpy
from mathutils import Matrix, Vector

d = os.path.join(B.HERE, "pictures")
for vid in sorted(os.listdir(d)):
    out = os.path.join(d, vid); mp = os.path.join(out, "meta.json")
    if not os.path.exists(mp) or (B.ONLY and vid not in B.ONLY): continue
    if os.path.exists(os.path.join(out, "render_picR.png")) and not os.environ.get("FORCE"): continue
    meta = json.load(open(mp))
    with bpy.data.libraries.load(os.path.join(out, vid + ".blend")) as (src, dst): dst.objects = list(src.objects)
    obs = [o for o in dst.objects if o is not None]
    for o in obs: B.COL.objects.link(o)
    bpy.context.view_layer.update()
    c = Vector((B.PX, -0.03, B.PZ))
    xf = Matrix.Translation(c + Vector(B.PICR_OFFSET)) @ Matrix.Diagonal((B.PICR_SCALE, 1.0, B.PICR_SCALE, 1.0)) @ Matrix.Translation(-c)
    for o in obs: o.matrix_world = xf @ o.matrix_world
    bpy.context.view_layer.update()
    B.CUR[:] = obs
    for o in B.CANON["picR"]: o.hide_render = True
    t2, t3 = B.render_pair(out, "render_picR.png", "mask_picR.png")
    for o in B.CANON["picR"]: o.hide_render = False
    meta["picR"] = {"offset": list(B.PICR_OFFSET), "scale_xz": B.PICR_SCALE, "about": [B.PX, -0.03, B.PZ],
                    "render_seconds": round(t2, 1), "mask_seconds": round(t3, 1)}
    json.dump(meta, open(mp, "w"), indent=1)
    print(f"PICR {vid}: {len(obs)} objects, render {t2:.1f}s mask {t3:.1f}s")
    for o in obs: bpy.data.objects.remove(o, do_unlink=True)
B.sc.render.image_settings.file_format, B.sc.render.image_settings.color_mode = B.FMT0, B.MODE0
print("PICR done (room.blend was not saved)")
