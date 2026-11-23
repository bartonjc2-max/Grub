#!/usr/bin/env python3
"""Room element layers, step 2 (after render_room_layers.py in Blender).

The room plate is REBUILT from its pieces, so moving a piece can never reveal shading that doesn't match:
  bare   = the room with no elements, painted (paint_plate_d2.py k12 + warm_plate.py)
  elem_k = the bare room with only element k in it, painted the same way
  S_k    = the darkening element k casts on the room (its shadows and paint smear): lum(elem_k) / lum(bare)
  plate  = bare x every S_k, then each element's own pixels (from elem_k) on top
The shader does the same sum at runtime with each element's pixels AND its S_k moved by its transform: at rest
it's the plate exactly; moved, the element takes its shadow with it and leaves the bare wall it was painted on.
(Earlier versions cut elements out of the old all-in-one plate; the old plate's shading round them never matched
the bare room, so a shaken pot left a ghost and the wall behind it looked clean next to "dirty" wall.)

Writes into GrubUnity/Assets/Grub/Room:
  room_plate_painted_k12w.png       the rebuilt plate (the old one is kept as art/3d/renders/plate_k12w_before_layers.png)
  room_plate_painted_k12w_bare.png  the painted bare room
  room_layers_a.png   RGBA = coverage of the four furthest elements (far to near)
  room_layers_b.png   R = coverage of the nearest, B = its darkening S
  room_layers_s.png   RGBA = darkening S of the four furthest
  room_layers.json    order (far to near), per element pivot (plate px, top-left origin), size, bend flag
python3 build_room_layers.py

Environment (all optional; with none set this behaves exactly as before and OVERWRITES THE GAME TEXTURES):
  OUT_DIR=<folder>      write the game textures (and the paint pass's temporary files) there, not into GrubUnity
  RENDERS_DIR=<folder>  read the raw renders (render_room_layers.py OUT_DIR) from there and write painted*.png there
  UNBAKED_RUG=1         the rug is its own layer (needs renders made with RUG=layer, so the bare room and every
                        element render have no rug). Also writes into OUT_DIR:
                          room_rug.png       1284 x 2778 RGBA, straight alpha: RGB = the rug as painted in the bare
                                             room with the bare room's colour-fit gains, alpha = its silhouette
                          bare_fit_gains.json  those gains (store_assets/make_rug_layer.py reuses them)
                        Each element's own pixels are painted from elem_<k>_rug.png (lit by the canon rug, as
                        shipped); only its floor shadow comes from the no-rug render (ELEM_LIGHT=norug: both).
                        and room_layers.json gets "rug": {"bbox": [x0, y0, x1, y1], "file": "room_rug.png"}.
                        Unity: base = lerp(bare, rug.rgb, rug.a) x element shadows, then the elements.
  The approved plate the colours are fitted to is always art/3d/renders/plate_k12w_before_layers.png.

Staging run (nothing under GrubUnity is written; about 6 minutes):
  cd art/3d && S=$PWD/renders/unbaked
  RUG=layer OUT_DIR=$S/work /Applications/Blender.app/Contents/MacOS/Blender -b --python render_room_layers.py
  UNBAKED_RUG=1 OUT_DIR=$S RENDERS_DIR=$S/work python3 painted/build_room_layers.py
"""
import json, os, shutil, subprocess, sys
import numpy as np
from PIL import Image, ImageFilter

HERE = os.path.dirname(os.path.abspath(__file__))
D3 = os.path.normpath(os.path.join(HERE, ".."))
CANON_RENDERS = os.path.join(D3, "renders")
RENDERS = os.environ.get("RENDERS_DIR") or CANON_RENDERS
GAME_ROOM = os.path.normpath(os.path.join(HERE, "..", "..", "..", "..", "GrubUnity", "Assets", "Grub", "Room"))
ROOM = os.environ.get("OUT_DIR") or GAME_ROOM            # every file this script writes goes here or into RENDERS
STAGING = ROOM != GAME_ROOM
UNBAKED_RUG = os.environ.get("UNBAKED_RUG", "") == "1"
if UNBAKED_RUG and not STAGING: sys.exit("UNBAKED_RUG=1 needs OUT_DIR (the game does not read a rug layer from the default folder yet)")
os.makedirs(ROOM, exist_ok=True)
# stacking order = far to near from the camera (render_room_layers.py measures it): an element moved over
# another one goes behind it if it's further away (a shaken pot slides behind the couch)
_depth = json.load(open(os.path.join(RENDERS, "room_layers_depth.json")))
ORDER = sorted(_depth, key=lambda k: -_depth[k])
PIVOT = {"door": "bottom", "picL": "top", "picR": "top", "couch": "bottom", "plant": "bottom"}
BEND = {"plant": 1.5}     # >0 bends; above (value - 1) of its height (mid-stem) the stem curves, the leaves ride on
POT_TOP_PX = 1440
CONTACT = {"plant": 0.10, "couch": 0.08}   # keep a floor contact shadow under the bottom fraction of these only         # plate row just under the pot rim (the pot didn't change when the plant was shortened)


def paint(src, tag):
    """Paint a raw render exactly like the shipped plate: D2 at Kuwahara 12, then the warm grade."""
    env = dict(os.environ, PLATE_IN=src, OUT_TAG=tag)
    if STAGING: env["PLATE_OUT_DIR"] = ROOM              # paint_plate_d2.py's output and temp file: not into GrubUnity
    subprocess.run([sys.executable, os.path.join(HERE, "paint_plate_d2.py"), "12"], env=env, check=True, capture_output=True)
    raw = os.path.join(ROOM, f"room_plate_painted_k12{tag}.png")
    out = os.path.join(RENDERS, f"painted{tag}.png")
    subprocess.run([sys.executable, os.path.join(HERE, "warm_plate.py"), raw, out], check=True, capture_output=True)
    os.remove(raw)
    return np.asarray(Image.open(out).convert("RGB"), float)


plate_p = os.path.join(ROOM, "room_plate_painted_k12w.png")
backup = os.path.join(CANON_RENDERS, "plate_k12w_before_layers.png")
if not os.path.exists(backup):
    if STAGING: sys.exit("missing " + backup)
    shutil.copy2(plate_p, backup)

bare = paint(os.path.join(RENDERS, "room_plate_bare.png"), "_bare")
elems = {k: paint(os.path.join(RENDERS, f"elem_{k}.png"), f"_elem_{k}") for k in ORDER}
# Unbaked rug: the terracotta rug bounces a lot of warm light into the room (raw render: walls 13-20 levels less
# green / blue with it, the couch 6-8). The walls are colour-fitted to the approved plate below, which absorbs it,
# but the couch is not fitted, so built from the no-rug render it came out visibly paler than the shipped one.
# So each element's OWN pixels come from its render with the canon rug down (exactly the shipped look), and only
# its shadow on the room (S, against the no-rug bare) comes from the no-rug render. ELEM_LIGHT=norug turns it off.
elems_lit = None
if UNBAKED_RUG and os.environ.get("ELEM_LIGHT", "rug") == "rug" and all(os.path.exists(os.path.join(RENDERS, f"elem_{k}_rug.png")) for k in ORDER):
    elems_lit = {k: paint(os.path.join(RENDERS, f"elem_{k}_rug.png"), f"_elem_{k}_rug") for k in ORDER}
    print("  element pixels: from the renders with the canon rug (shadows from the no-rug renders)")
raws = {k: Image.open(os.path.join(RENDERS, f"mask_{k}_raw.png")).convert("RGBA").split()[3] for k in ORDER}
H, W = bare.shape[:2]

lum = lambda x: x[..., 0] * 0.299 + x[..., 1] * 0.587 + x[..., 2] * 0.114


def box(a, r, axis):
    c = np.cumsum(np.pad(a, [(r + 1, r) if i == axis else (0, 0) for i in range(a.ndim)], mode="edge"), axis=axis)
    return (np.take(c, np.arange(2 * r + 1, c.shape[axis]), axis=axis) - np.take(c, np.arange(0, c.shape[axis] - 2 * r - 1), axis=axis)) / (2 * r + 1)


def blur(a, r):
    k = max(1, int(r / 1.7))
    for _ in range(3): a = box(box(a, k, 0), k, 1)
    return a


# An element darkens the room two ways: its own shadow and paint smear right round it, and a faint room-wide
# change (bounce light) that reaches most of the plate. Only the near part may move with it, or a shaken pot
# would slide the whole wall's shading. So per element:
#   far  = the smooth room-wide part, estimated away from it and interpolated underneath it (baked into bare)
#   near = S / far, only within ~50 px of it (moves with it); 1 under the element itself
alpha, near_s = {}, {}
bare_eff = bare.copy()
for k in ORDER:
    # the silhouette itself, antialiased: a dilated mask carried a ring of the wall it was painted on wherever the
    # element moved (a pale rim round the folded plant). Outside the silhouette the room shows instead.
    a = np.asarray(raws[k].filter(ImageFilter.GaussianBlur(0.8)), float) / 255
    # Its whole shadow (contact, smear and the soft shading round it) out to ~60 px, fading to nothing; it all
    # moves with the element. The bare wall underneath stays plain everywhere. (Splitting off a static
    # "room-wide" part and interpolating it under the element left visible shapes in the wall.)
    S = np.clip(lum(elems[k]) / np.maximum(lum(bare), 1.0), 0.15, 1.0)
    S[np.abs(lum(elems[k]) - lum(bare)) < 0.6] = 1.0
    reach = blur(np.asarray(raws[k].filter(ImageFilter.MaxFilter(81)), float) / 255, 20)    # 1 near it, 0 by ~60 px
    # Right round the element S is unreliable (the paint smears its edge, and the mask is dilated ~6 px), and
    # forcing it to 1 there left a band of unshadowed wall: a pale rim round every element (Jesse 2026-11-22:
    # "weird outline"). Carry the shadow in from the wall 9-20 px out, under the element too (it moves with it).
    near_band = np.asarray(raws[k].filter(ImageFilter.MaxFilter(19)), float) > 127
    valid = (~near_band).astype(float)
    w1, w2 = blur(valid, 12), blur(valid, 40)
    S_fill = np.where(w1 > 0.15, blur(S * valid, 12) / np.maximum(w1, 1e-4),
                      np.where(w2 > 0.05, blur(S * valid, 40) / np.maximum(w2, 1e-4), 1.0))   # gaps between leaves
    S = np.where(near_band, np.clip(S_fill, 0.15, 1.0), S)
    nearS = 1 - (1 - S) * np.clip(reach, 0, 1)
    # Jesse 2026-11-22 (build 26): "the dark kinda shadowy outline the plant, couch ... should be identified and
    # removed. It really shows up poorly when he folds the plant over." It was this: each element's whole wall
    # shadow (~60 px, ~15% darker) moved with it, so a bent plant dragged a plant-shaped dark halo across the wall.
    # Keep only a tight contact shadow on the floor right under an element's base (pot, couch feet); nothing on walls.
    if k in CONTACT:
        ys, xs = np.nonzero(np.asarray(raws[k]) > 127)
        y1, hgt = ys.max(), ys.max() - ys.min()
        yy = np.arange(H)[:, None]
        base = np.clip((yy - (y1 - CONTACT[k] * hgt)) / (0.04 * hgt), 0, 1)                # only the bottom of it
        tight = blur(np.asarray(raws[k].filter(ImageFilter.MaxFilter(31)), float) / 255, 8)  # within ~20 px
        nearS = 1 - (1 - nearS) * np.clip(base * tight, 0, 1)
    else:
        nearS = np.ones_like(nearS)
    alpha[k], near_s[k] = a, nearS
    print(f"  {k}: covers {(a > 0.5).mean() * 100:.2f}%, shadow on {(nearS < 0.995).mean() * 100:.2f}% (min {nearS.min():.2f})")

if elems_lit: elems = elems_lit        # S is done (it used the no-rug renders); from here on, the elements' own pixels

# Keep the approved colours: the old plate was graded to the canon on the phone (warm_plate.py). Painted alone
# each element (and the bare room) comes out a little lighter / differently tinted, so fit a per-channel
# gain + offset from each piece to the old plate where they show the same thing, and apply it.
old = np.asarray(Image.open(backup).convert("RGB"), float)
def apply_gains(src, gains):
    out = src.copy()
    for c, (g, o) in enumerate(gains): out[..., c] = src[..., c] * g + o
    return out
BARE_GAINS = []
def fit(src, dst, m, keep=None):
    # robust: refit without pixels the old plate never showed (the rug, added since): drop big residuals
    m = m.copy()
    for it in range(3):
        res = np.zeros(src.shape[:2]); gains = []
        for c in range(3):
            x, y = src[..., c][m], dst[..., c][m]
            A = np.vstack([x, np.ones_like(x)]).T
            g, o = np.linalg.lstsq(A, y, rcond=None)[0]; gains.append((g, o))
            res = np.maximum(res, np.abs(src[..., c] * g + o - dst[..., c]))
        if it < 2: m &= res < max(3 * np.median(res[m]), 6)
    if keep is not None: keep[:] = [(float(g), float(o)) for g, o in gains]
    return apply_gains(src, gains)
any_near = np.zeros((H, W), bool)
for k in ORDER: any_near |= np.asarray(raws[k].filter(ImageFilter.MaxFilter(121)), float) > 127
fit_mask = ~any_near
if UNBAKED_RUG:
    # The approved plate has no rug. With the rug baked in, the robust refit above throws the rug out by its
    # residuals; here the floor under it is bare and would join the fit, and the gains would drift from the
    # shipped plate's. Leave the rug's area (and 30 px round it) out, so both versions fit the same pixels.
    rug_raw = Image.open(os.path.join(RENDERS, "mask_rug_raw.png")).convert("RGBA").split()[3]
    fit_mask &= ~(np.asarray(rug_raw.filter(ImageFilter.MaxFilter(61)), float) > 127)
bare_eff = fit(bare_eff, old, fit_mask, BARE_GAINS)            # walls, floor, ceiling away from the elements
print("  colour fit bare: gains", [(round(g, 4), round(o, 2)) for g, o in BARE_GAINS])
for k in ORDER:
    core = np.asarray(raws[k].filter(ImageFilter.MinFilter(9)), float) > 127   # the element itself, edge excluded
    if k == "plant": core[:POT_TOP_PX] = False       # the plant was shortened since the approved plate: match on the pot only
    ref = old
    if k == "couch":
        # the couch was pulled off the wall since the approved plate (move_couch.py), so the old plate no longer
        # shows the couch at these pixels: a fit there flattens it. It's painted the same way, so leave it be.
        print("  colour fit couch: skipped (moved since the approved plate)")
        continue
    elems[k] = fit(elems[k], ref, core)
    print(f"  colour fit {k}: |elem - old| in it {np.abs(elems[k] - ref)[core].mean():.2f}")

# Outside its own silhouette an element's render is just wall (plus its shadow), painted and colour-fitted
# separately from the bare room, so the dilated mask showed it as a halo ring round every element (Jesse
# 2026-11-22: "some weird outline that's not like grub's"). Past the silhouette use exactly what the room
# under it shows (bare x its shadows), so the mask edge blends between identical colours.
# The Kuwahara overshoots at high-contrast edges: each element's outermost ~3 px came out paler than both the
# element and the wall, a light rim Grub doesn't have. Refill that band from the element's own interior.
for k in ORDER:
    core = (np.asarray(raws[k].filter(ImageFilter.MinFilter(7)), float) > 127).astype(float)
    band = (np.asarray(raws[k], float) > 8) & (core < 0.5)
    num = np.stack([blur(elems[k][..., c] * core, 5) for c in range(3)], -1); den = blur(core, 5)[..., None]
    fill = num / np.maximum(den, 1e-4)
    ok = band & (den[..., 0] > 0.02)
    print(f"  {k}: edge rim was {(lum(elems[k]) - lum(fill))[ok].mean():+.1f} lighter than the inside")
    elems[k][ok] = fill[ok]
for k in ORDER:
    ra = np.asarray(raws[k].filter(ImageFilter.GaussianBlur(1.2)), float)[..., None] / 255
    under = bare_eff * np.prod([near_s[j] for j in ORDER], axis=0)[..., None]
    ring = (alpha[k] > 0.02) & (ra[..., 0] < 0.98)
    before = np.abs(elems[k] - under)[ring & (ra[..., 0] < 0.02)].mean()
    elems[k] = elems[k] * ra + under * (1 - ra)
    print(f"  {k}: halo ring |elem - room| was {before:.2f}, now 0")

# the plate, rebuilt from the pieces
plate = bare_eff.copy()
for k in ORDER: plate *= near_s[k][..., None]
for k in ORDER: plate = plate * (1 - alpha[k][..., None]) + elems[k] * alpha[k][..., None]
print("rebuilt plate vs the old one: mean |diff| %.2f, p99 %.1f" % (np.abs(plate - old).mean(), np.percentile(np.abs(plate - old).mean(2), 99)))
Image.fromarray(np.clip(plate + 0.5, 0, 255).astype(np.uint8)).save(plate_p)
Image.fromarray(np.clip(bare_eff + 0.5, 0, 255).astype(np.uint8)).save(os.path.join(ROOM, "room_plate_painted_k12w_bare.png"))
shade = near_s

u8 = lambda x: Image.fromarray(np.clip(x * 255 + 0.5, 0, 255).astype(np.uint8))
zero = Image.new("L", (W, H), 0)
Image.merge("RGBA", [u8(alpha[k]) for k in ORDER[:4]]).save(os.path.join(ROOM, "room_layers_a.png"))
Image.merge("RGBA", [u8(alpha[ORDER[4]]), zero, u8(shade[ORDER[4]]), Image.new("L", (W, H), 255)]).save(os.path.join(ROOM, "room_layers_b.png"))
Image.merge("RGBA", [u8(shade[k]) for k in ORDER[:4]]).save(os.path.join(ROOM, "room_layers_s.png"))

info = {"width": W, "height": H, "order": ORDER, "layers": {}}
for i, k in enumerate(ORDER):
    m = np.asarray(raws[k]) > 127
    ys, xs = np.nonzero(m)
    x0, x1, y0, y1 = int(xs.min()), int(xs.max()), int(ys.min()), int(ys.max())
    info["layers"][k] = {"index": i, "bbox": [x0, y0, x1, y1], "pivot": [(x0 + x1) / 2, y1 if PIVOT[k] == "bottom" else y0],
                         "height": y1 - y0, "width": x1 - x0, "bend": BEND.get(k, 0), "pivot_at": PIVOT[k]}

if UNBAKED_RUG:
    # The rug as its own full-plate layer: painted in the bare room exactly like the bare plate (same wobble,
    # Kuwahara, grain, warm grade) and given the bare plate's colour-fit gains, so lerp(bare, rug.rgb, rug.a)
    # is the bare room with the rug in it. Not in "order" / "layers": the shader's element arrays stay at 5.
    sys.path.insert(0, os.path.join(D3, "store_assets"))
    from make_rug_layer import write_rug_layer
    rug_p = apply_gains(paint(os.path.join(RENDERS, "room_plate_bare_rug.png"), "_bare_rug"), BARE_GAINS)
    json.dump({"gains": BARE_GAINS, "note": "per channel (gain, offset) on 0..255 painted values: painted bare -> approved plate colours"},
              open(os.path.join(ROOM, "bare_fit_gains.json"), "w"), indent=1)
    info["rug"] = {"bbox": write_rug_layer(rug_p, rug_raw, os.path.join(ROOM, "room_rug.png")), "file": "room_rug.png"}
json.dump(info, open(os.path.join(ROOM, "room_layers.json"), "w"), indent=1)
print("ORDER far -> near:", ORDER)
