#!/usr/bin/env python3
"""Painted room plate D2 (board grub-mechanics #661). For each Kuwahara size (default 12 and 16):
  1. edge wobble: warp the plate by smooth noise, 1.5px amplitude (straight edges waver)
  2. Kuwahara (Blender compositor, anisotropic) + the cool-darks grade, via paint_plate.py
  3. big value patches: noise at ~3-4 patches across the frame, +-4%, multiplied in
  4. paper grain baked in at 12%, in the same screen mapping GrubPainted uses for Grub
Writes GrubUnity/Assets/Grub/Room/room_plate_painted_k{size}.png.
python3 paint_plate_d2.py [12 16]
PLATE_OUT_DIR=<folder> writes the output (and the temporary wobble file) there instead of into GrubUnity.
"""
import os, subprocess, sys
import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
ROOM = os.path.normpath(os.path.join(HERE, "..", "..", "..", "..", "GrubUnity", "Assets", "Grub", "Room"))
PAINT = os.path.normpath(os.path.join(ROOM, "..", "Painted"))        # paper.png is only read from here
OUTD = os.environ.get("PLATE_OUT_DIR") or ROOM
BLENDER = "/Applications/Blender.app/Contents/MacOS/Blender"
sizes = [int(a) for a in sys.argv[1:]] or [12, 16]
rng = np.random.default_rng(661)


def smooth_noise(h, w, cells):
    """Smooth value noise with ~cells blobs across the width (bicubic upsampled grid)."""
    gw = max(2, cells + 2); gh = max(2, int(round(gw * h / w)) + 1)
    g = Image.fromarray(((rng.random((gh, gw)) * 255)).astype(np.uint8), "L")
    return np.asarray(g.resize((w, h), Image.BICUBIC), float) / 255 * 2 - 1


SRC_IN = os.environ.get("PLATE_IN", os.path.join(ROOM, "room_plate.png"))      # e.g. the no-plant render
TAG = os.environ.get("OUT_TAG", "")                                         # appended to the output name
src = np.asarray(Image.open(SRC_IN).convert("RGB"), float)
H, W, _ = src.shape

# 1. edge wobble
dx, dy = smooth_noise(H, W, 90) * 1.5, smooth_noise(H, W, 90) * 1.5
yy, xx = np.mgrid[0:H, 0:W]
sx, sy = np.clip(xx + dx, 0, W - 1), np.clip(yy + dy, 0, H - 1)
x0, y0 = sx.astype(int), sy.astype(int); x1, y1 = np.minimum(x0 + 1, W - 1), np.minimum(y0 + 1, H - 1)
fx, fy = (sx - x0)[..., None], (sy - y0)[..., None]
warped = (src[y0, x0] * (1 - fx) * (1 - fy) + src[y0, x1] * fx * (1 - fy) + src[y1, x0] * (1 - fx) * fy + src[y1, x1] * fx * fy)
tmp = os.path.join(OUTD, f"_plate_wobble{TAG}.png")
Image.fromarray(np.clip(warped, 0, 255).astype(np.uint8)).save(tmp)

patches = 1 + 0.04 * smooth_noise(H, W, 3)
paper = np.asarray(Image.open(os.path.join(PAINT, "paper.png")).convert("L"), float) / 255
P = paper.shape[0]
# GrubPainted: g = (x / W, y / W) * 1.25 in screen pixels (top-left origin), tiling the 1024 paper
gu = ((xx / W * 1.25) * P).astype(int) % P
gv = ((yy / W * 1.25) * P).astype(int) % P
grain = 1 - 0.12 * (1 - paper[gv, gu])

for k in sizes:
    out = os.path.join(OUTD, f"room_plate_painted_k{k}{TAG}.png")
    env = dict(os.environ, PLATE_SRC=tmp, PLATE_DST=out, KSIZE=str(k))
    r = subprocess.run([BLENDER, "-b", "--factory-startup", "--python", os.path.join(HERE, "paint_plate.py")],
                       env=env, capture_output=True, text=True)
    if "PAINTED PLATE" not in r.stdout: print(r.stdout[-2000:], r.stderr[-2000:]); sys.exit(1)
    img = np.asarray(Image.open(out).convert("RGB"), float)
    img = img * patches[..., None] * grain[..., None]
    Image.fromarray(np.clip(img, 0, 255).astype(np.uint8)).save(out)
    print("D2 plate ->", out)
os.remove(tmp)
