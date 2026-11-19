"""Floor + wall brightness, canon vs our render, at fixed patches of the 768x1344 frame."""
import os
import sys, numpy as np
from PIL import Image
CANON = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "docs", "canon", "2026-11-19-livingroom-screen.png")
OURS = sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.path.dirname(os.path.abspath(__file__)), "renders", "room_render.png")
P = {"floor near L": (60, 1020), "floor near C": (384, 1000), "floor near R": (680, 1020),
     "floor mid L": (120, 920), "floor mid R": (620, 900), "floor front": (384, 1250),
     "floor by grub": (470, 880), "wall upper": (384, 420), "wall left": (60, 600),
     "ceiling": (384, 100)}
a = np.asarray(Image.open(CANON).convert("RGB")).astype(float)
b = np.asarray(Image.open(OURS).convert("RGB")).astype(float)
tot = 0
for k, (x, y) in P.items():
    ca = a[y-12:y+12, x-12:x+12].reshape(-1, 3).mean(0); cb = b[y-12:y+12, x-12:x+12].reshape(-1, 3).mean(0)
    tot += np.abs(cb - ca).mean()
    print(f"{k:14s} {ca.round().astype(int)} {cb.round().astype(int)} {(cb-ca).round().astype(int)}")
print("mean abs diff", round(tot / len(P), 1))
