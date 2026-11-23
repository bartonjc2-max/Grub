#!/usr/bin/env python3
"""A rug as a game layer: store_assets/rugs/<id>/game/room_rug.png + game/item.json.

The room's rug is not baked into the bare plate any more (art/3d/renders/unbaked, built by
render_room_layers.py RUG=layer + painted/build_room_layers.py UNBAKED_RUG=1). The game draws
    base = lerp(bare_no_rug, rug.rgb, rug.a) x element contact shadows, then the elements,
so a new rug is ONE texture and nothing else is rebuilt. This makes that texture from a variant's raw
render.png (the room with the rug and every canon element) and mask.png (alpha = the rug):
  1. the elements' shadows on the rug are divided out, because the game's bare room has none either. The
     divisor is measured from the staging renders: on the canon rug's footprint, the canon rug with and
     without the elements (room_plate_bare_rug / room_full); outside it, the bare floor with and without them
     (room_plate_bare / room_full_norug);
  2. the rug is pasted into the raw no-rug bare room, and that is painted exactly like the bare plate
     (paint_plate_d2.py Kuwahara 12, same wobble / patches / grain, then warm_plate.py);
  3. the bare plate's colour-fit gains (bare_fit_gains.json) are applied, so it matches the bare plate;
  4. room_rug.png: 1284 x 2778 RGBA, straight alpha. alpha = the mask's antialiased silhouette (0.8 px blur, no
     dilation); RGB outside the silhouette is the nearest rug colour (edge-extended), so filtering never pulls
     in black.
  game/item.json = {"rug": {...}} (the footprint the game reads; from meta.json "game", see measure_items.py).

  python3 make_rug_layer.py rug_daisy [rug_cloud ...]     about 55 s per rug (one paint pass)
  python3 make_rug_layer.py rug_terracotta                the canon rug, from the staging renders (a check: it
                                                          must reproduce renders/unbaked/room_rug.png)
  UNBAKED_DIR=<folder>   the staging folder (default ../renders/unbaked); needs work/room_plate_bare.png,
                         work/room_full_norug.png and bare_fit_gains.json in it.
Never writes outside store_assets/rugs/<id>/game/. Needs python3 with PIL and numpy, and Blender for the paint.
"""
import json, os, shutil, subprocess, sys, tempfile, time
import numpy as np
from PIL import Image, ImageFilter

HERE = os.path.dirname(os.path.abspath(__file__))
D3 = os.path.dirname(HERE)
PAINTED = os.path.join(D3, "painted")
STAGE = os.environ.get("UNBAKED_DIR") or os.path.join(D3, "renders", "unbaked")
CANON_RUG = "rug_terracotta"


def write_rug_layer(rgb, mask_l, out_path, extend=16):
    """rgb: float HxWx3 painted + colour-fitted room with the rug; mask_l: PIL 'L' raw coverage of the rug.
    Writes the RGBA layer and returns the rug's bbox [x0, y0, x1, y1] in plate px (mask > 127, inclusive)."""
    raw = np.asarray(mask_l, float)
    alpha = np.asarray(mask_l.filter(ImageFilter.GaussianBlur(0.8)), float)
    solid = raw > 127
    ys, xs = np.nonzero(solid)
    out = np.where(solid[..., None], rgb, 0.0)
    known = solid.copy()
    H, W = known.shape
    for _ in range(extend):                       # grow the rug's own colour outward one pixel at a time
        k = np.pad(known.astype(float), 1); v = np.pad(out * known[..., None], ((1, 1), (1, 1), (0, 0)))
        acc = np.zeros_like(out); cnt = np.zeros((H, W))
        for dy in (0, 1, 2):
            for dx in (0, 1, 2):
                acc += v[dy:dy + H, dx:dx + W]; cnt += k[dy:dy + H, dx:dx + W]
        new = (~known) & (cnt > 0)
        out[new] = acc[new] / cnt[new][:, None]
        known |= new
    out[~known] = rgb[solid].mean(0)              # far from the rug (alpha 0): its mean colour, for mipmaps
    rgba = np.dstack([np.clip(out + 0.5, 0, 255), alpha]).astype(np.uint8)
    os.makedirs(os.path.dirname(out_path), exist_ok=True)
    Image.fromarray(rgba, "RGBA").save(out_path)
    return [int(xs.min()), int(ys.min()), int(xs.max()), int(ys.max())]


def paint(src, tmp):
    """Same paint pass as build_room_layers.py paint(), every file kept inside tmp."""
    env = dict(os.environ, PLATE_IN=src, OUT_TAG="_rug", PLATE_OUT_DIR=tmp)
    subprocess.run([sys.executable, os.path.join(PAINTED, "paint_plate_d2.py"), "12"], env=env, check=True, capture_output=True)
    out = os.path.join(tmp, "painted_rug.png")
    subprocess.run([sys.executable, os.path.join(PAINTED, "warm_plate.py"), os.path.join(tmp, "room_plate_painted_k12_rug.png"), out],
                   check=True, capture_output=True)
    return np.asarray(Image.open(out).convert("RGB"), float)


def make(vid):
    t0 = time.time()
    work = os.path.join(STAGE, "work")
    out_dir = os.path.join(HERE, "rugs", vid, "game")
    if vid == CANON_RUG:
        render_p, mask_p = os.path.join(work, "room_full.png"), os.path.join(work, "mask_rug_raw.png")
        game = json.load(open(os.path.join(HERE, "canon_items.json")))
    else:
        d = os.path.join(HERE, "rugs", vid)
        render_p, mask_p = os.path.join(d, "render.png"), os.path.join(d, "mask.png")
        game = json.load(open(os.path.join(d, "meta.json"))).get("game")
    if not game or "rug" not in game: sys.exit(f"{vid}: no measured rug footprint; run measure_items.py first")
    gains = json.load(open(os.path.join(STAGE, "bare_fit_gains.json")))["gains"]
    render = np.asarray(Image.open(render_p).convert("RGB"), float)
    mask_l = Image.open(mask_p).convert("RGBA").split()[3]
    bare = np.asarray(Image.open(os.path.join(work, "room_plate_bare.png")).convert("RGB"), float)
    full = np.asarray(Image.open(os.path.join(work, "room_full_norug.png")).convert("RGB"), float)
    if render.shape != bare.shape: sys.exit(f"{vid}: render.png is {render.shape[1]}x{render.shape[0]}, the plate is {bare.shape[1]}x{bare.shape[0]}")
    # 1. the elements' shadows off the rug: what they do to the bare floor at the same pixel ...
    unshadow = np.clip((bare + 1.0) / (full + 1.0), 0.8, 3.0)
    # ... and, where the canon rug lies, what they do to the canon rug there. That is the better measure for a
    # rug: the cream floor is nearly clipped in red, so its ratio misses the red the elements take (the canon
    # rug rebuilt from the floor ratio alone came out 3 levels short in red, 6-8 next to the couch).
    cr, cf, cm = (os.path.join(work, n) for n in ("room_plate_bare_rug.png", "room_full.png", "mask_rug_raw.png"))
    if all(os.path.exists(p) for p in (cr, cf, cm)) and not os.environ.get("FLOOR_RATIO_ONLY"):
        on_rug = np.clip((np.asarray(Image.open(cr).convert("RGB"), float) + 1.0) / (np.asarray(Image.open(cf).convert("RGB"), float) + 1.0), 0.8, 3.0)
        w = Image.open(cm).convert("RGBA").split()[3].filter(ImageFilter.MinFilter(13)).filter(ImageFilter.GaussianBlur(4))
        w = (np.asarray(w, float) / 255)[..., None]
        unshadow = unshadow * (1 - w) + on_rug * w
    rug_raw = np.clip(render * unshadow, 0, 255)
    # 2. into the raw bare room, 2 px past the silhouette (there render x unshadow IS the bare floor), then paint
    m = (np.asarray(mask_l.filter(ImageFilter.MaxFilter(5)), float) > 8)[..., None]
    tmp = tempfile.mkdtemp(prefix="rug_layer_")
    try:
        src = os.path.join(tmp, "raw_bare_with_rug.png")
        Image.fromarray((np.where(m, rug_raw, bare) + 0.5).astype(np.uint8)).save(src)
        painted = paint(src, tmp)
    finally:
        shutil.rmtree(tmp, ignore_errors=True)
    # 3 + 4
    for c, (g, o) in enumerate(gains): painted[..., c] = painted[..., c] * g + o
    bbox = write_rug_layer(painted, mask_l, os.path.join(out_dir, "room_rug.png"))
    json.dump({"rug": game["rug"], "file": "room_rug.png", "bbox": bbox}, open(os.path.join(out_dir, "item.json"), "w"), indent=1)
    print(f"{vid}: {os.path.join(out_dir, 'room_rug.png')} bbox {bbox}, {time.time() - t0:.0f} s")


if __name__ == "__main__":
    if len(sys.argv) < 2: sys.exit(__doc__)
    for v in sys.argv[1:]: make(v)
