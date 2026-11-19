"""Shadow under Grub: floor darkening (vs. a clean floor reference) around his feet."""
import os
import sys, numpy as np
from PIL import Image
def lum(p): a=np.asarray(Image.open(p).convert("RGB")).astype(float); return a@[0.2126,0.7152,0.0722], a
def prof(path, feet_y, cx):
    L, a = lum(path)
    out=[]
    for dy in (-6, 0, 6, 12, 20, 30, 45):
        y = feet_y + dy
        row = L[y-2:y+3].mean(0)
        ref = np.median(np.r_[row[40:120], row[650:730]])
        xs = list(range(cx-140, cx+161, 20))
        out.append((dy, [int(row[x-3:x+4].mean()-ref) for x in xs], int(ref)))
    return out, xs
for name, path, fy, cx in (("canon",os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "docs", "canon", "2026-11-19-livingroom-screen.png"),866,392),
                           ("ours",sys.argv[1] if len(sys.argv)>1 else os.path.join(os.path.dirname(os.path.abspath(__file__)), "renders", "room_render.png"),886,388)):
    o, xs = prof(path, fy, cx)
    print(name, "x offsets", [x-cx for x in xs])
    for dy, v, ref in o: print(f"  dy={dy:+3d} ref={ref}", v)
