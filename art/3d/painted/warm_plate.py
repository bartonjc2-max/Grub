#!/usr/bin/env python3
"""Grade the painted room plate to the canon screen (board grub-mechanics, planted E3).
Defaults were fitted ON DEVICE (iPhone 13, Tools/devcap.sh, daytime pinned): mean dE 13.5 -> 3.7 over 11 regions.
The first E2 pass was fitted to night-tinted editor renders and came out far too bright and warm.
Sampled canon vs our render per region (walls, floor, ceiling, sofa, door, pictures, pot): the canon
room is lighter, its neutrals sit at about b +14 (warm cream, ours were near b +3), its pinks are
softer (a about 18, ours about 28) and the pot is more orange. Done in Lab so the greens are kept:
  L' = L + LIFT * (100 - L)                        lighter, more on the darks
  b' = b + WARM * (1 - green) * (1 - cut * pink)  warm everything but foliage and the pinks
  a' = a * (1 - PINK_DESAT * pinkness)             soften the pinks
  b' += POT_B * orangeness                         a more orange pot
python3 warm_plate.py [src] [dst]   (defaults: room_plate_painted_k12.png -> room_plate_painted_k12w.png)
"""
import os, sys
import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
ROOM = os.path.normpath(os.path.join(HERE, "..", "..", "..", "..", "GrubUnity", "Assets", "Grub", "Room"))
SRC = sys.argv[1] if len(sys.argv) > 1 else os.path.join(ROOM, "room_plate_painted_k12.png")
DST = sys.argv[2] if len(sys.argv) > 2 else os.path.join(ROOM, "room_plate_painted_k12w.png")
LIFT = float(os.environ.get("LIFT", "0"))
WARM = float(os.environ.get("WARM", "2"))
WARM_A = float(os.environ.get("WARM_A", "0"))
PINK_DESAT = float(os.environ.get("PINK_DESAT", "0.42"))
PINK_LIFT = float(os.environ.get("PINK_LIFT", "0"))
POT_B = float(os.environ.get("POT_B", "7"))
PINK_WARM_CUT = float(os.environ.get("PINK_WARM_CUT", "1"))
COMPRESS = float(os.environ.get("COMPRESS", "0.33"))        # pull the brights down: L -= COMPRESS * max(0, L - 70)
PINK_L = float(os.environ.get("PINK_L", "4"))            # absolute L lift on pinks
YELLOW_B = float(os.environ.get("YELLOW_B", "0.3"))
ORANGE_L = float(os.environ.get("ORANGE_L", "5"))
PINK_B = float(os.environ.get("PINK_B", "-6"))            # b shift on pinks (negative = cooler, rosier)        # absolute L lift on the pot        # b -= YELLOW_B * max(0, b - 15)  (frames)

M = np.array([[0.4124, 0.3576, 0.1805], [0.2126, 0.7152, 0.0722], [0.0193, 0.1192, 0.9505]])
WP = np.array([0.95047, 1.0, 1.08883])


def to_lab(s):
    l = np.where(s <= 0.04045, s / 12.92, ((s + 0.055) / 1.055) ** 2.4)
    xyz = l @ M.T / WP
    f = np.where(xyz > 0.008856, np.cbrt(xyz), 7.787 * xyz + 16 / 116)
    return np.stack([116 * f[..., 1] - 16, 500 * (f[..., 0] - f[..., 1]), 200 * (f[..., 1] - f[..., 2])], -1)


def to_srgb(lab):
    fy = (lab[..., 0] + 16) / 116; fx = fy + lab[..., 1] / 500; fz = fy - lab[..., 2] / 200
    f = np.stack([fx, fy, fz], -1)
    xyz = np.where(f ** 3 > 0.008856, f ** 3, (f - 16 / 116) / 7.787) * WP
    l = np.clip(xyz @ np.linalg.inv(M).T, 0, 1)
    return np.where(l <= 0.0031308, 12.92 * l, 1.055 * l ** (1 / 2.4) - 0.055)


s = np.asarray(Image.open(SRC).convert("RGB"), float) / 255
L = to_lab(s); l, a, b = L[..., 0], L[..., 1], L[..., 2]
green = np.clip((-a - 4) / 8, 0, 1) * np.clip((np.hypot(a, b) - 14) / 10, 0, 1)      # saturated foliage only; the greenish wall glow gets warmed
pink = np.clip((a - 10) / 10, 0, 1) * np.clip((28 - b) / 12, 0, 1)
orange = np.clip((a - 15) / 10, 0, 1) * np.clip((b - 12) / 8, 0, 1)
l2 = l + (LIFT + PINK_LIFT * pink) * (100 - l) - COMPRESS * np.maximum(0, l - 70) + PINK_L * pink + ORANGE_L * orange
a2 = a * (1 - PINK_DESAT * pink) + WARM_A * (1 - green)
b2 = b + WARM * (1 - green) * (1 - PINK_WARM_CUT * pink) + POT_B * orange - YELLOW_B * np.maximum(0, b - 15) * (1 - orange) + PINK_B * pink
out = to_srgb(np.stack([l2, a2, b2], -1))
Image.fromarray((np.clip(out, 0, 1) * 255 + 0.5).astype(np.uint8)).save(DST)
print("warm plate ->", DST)
