"""Sample Grub's colours region by region in the canon screen and in our render.
Grub is found as the teal blob in a search box; regions are fractions of its body bbox."""
import os
import sys, numpy as np
from PIL import Image
CANON = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "docs", "canon", "2026-11-19-livingroom-screen.png")
OURS = sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.path.dirname(os.path.abspath(__file__)), "renders", "room_render.png")
BOX = (270, 640, 540, 900)   # search window (x0,y0,x1,y1) in the 768x1344 frame

def grub_mask(a):
    r, g, b = [a[..., i].astype(int) for i in range(3)]
    return (g - r > 25) & (b - r > 12) & (g > 90)

def regions(path):
    im = np.asarray(Image.open(path).convert("RGB"))
    x0, y0, x1, y1 = BOX
    sub = im[y0:y1, x0:x1]; m = grub_mask(sub)
    ys, xs = np.nonzero(m)
    # body = rows where the blob is widest-ish; use full bbox
    # robust bbox: keep rows/cols that hold a real share of the blob (drops stray teal pixels)
    cols = m.sum(0); rows = m.sum(1)
    cx = np.nonzero(cols > 3)[0]; ry = np.nonzero(rows > 6)[0]
    bx0, bx1, by0, by1 = cx.min(), cx.max(), ry.min(), ry.max()
    W, H = bx1 - bx0, by1 - by0
    def reg(fx0, fx1, fy0, fy1):
        X0, X1 = int(bx0 + fx0 * W), max(int(bx0 + fx1 * W), int(bx0 + fx0 * W) + 1)
        Y0, Y1 = int(by0 + fy0 * H), max(int(by0 + fy1 * H), int(by0 + fy0 * H) + 1)
        blk = sub[Y0:Y1, X0:X1]; mm = m[Y0:Y1, X0:X1]
        return blk[mm].mean(0) if mm.any() else np.array([np.nan] * 3)
    R = {
        "top dome":      reg(0.40, 0.60, 0.00, 0.06),
        "upper centre":  reg(0.42, 0.58, 0.12, 0.22),
        "cheek L":       reg(0.22, 0.30, 0.35, 0.45),
        "cheek R":       reg(0.70, 0.78, 0.35, 0.45),
        "belly":         reg(0.42, 0.58, 0.55, 0.65),
        "body edge L":   reg(0.14, 0.19, 0.20, 0.55),
        "body edge R":   reg(0.81, 0.86, 0.20, 0.55),
        "arm L":         reg(0.00, 0.08, 0.50, 0.65),
        "arm R":         reg(0.92, 1.00, 0.50, 0.65),
        "lower body":    reg(0.35, 0.65, 0.72, 0.80),
        "leg L":         reg(0.22, 0.35, 0.88, 0.97),
        "leg R":         reg(0.65, 0.78, 0.88, 0.97),
    }
    return R, (bx0 + x0, by0 + y0, W, H)

a, ba = regions(CANON); b, bb = regions(OURS)
print(f"bbox canon {ba}   ours {bb}")
print(f"{'region':14s} {'canon':>16s} {'ours':>16s}   diff(rgb)")
tot = 0
for k in a:
    d = b[k] - a[k]; tot += np.abs(d).mean()
    print(f"{k:14s} {str(a[k].round().astype(int)):>16s} {str(b[k].round().astype(int)):>16s}   {d.round().astype(int)}")
print("mean abs diff", round(tot / len(a), 1))
