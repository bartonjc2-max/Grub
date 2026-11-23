#!/usr/bin/env python3
"""Textures for Grub's "Painted Ramp v1" look (reasoner spec, board grub-mechanics #656).

Writes into GrubUnity/Assets/Grub/Painted/:
  grub_ramp.png      256x1   three painted stops: shadow #4A8A93 | mid #6CBCAF | light #8EDDC9,
                             0.05-wide soft transitions at 0.33 and 0.62
  brush.png          512^2   tileable grayscale brush strokes (stretched, domain-warped noise at a
                             few angles), used to break up the ramp's band edges
  paper.png          1024^2  tileable paper grain, near white, for a 10% full-screen multiply
  painted_shadow.png 256^2   a ragged-edged oval (alpha), for the painted contact shadow
Everything tiles because the noise is built in the frequency domain (periodic by construction).
python3 make_painted_textures.py
"""
import os
import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.normpath(os.path.join(HERE, "..", "..", "..", "..", "GrubUnity", "Assets", "Grub", "Painted"))
os.makedirs(OUT, exist_ok=True)
rng = np.random.default_rng(1121)


def hexrgb(h): return np.array([int(h[i:i + 2], 16) for i in (1, 3, 5)], float)


def periodic_noise(n, sx, sy, angle=0.0):
    """Tileable noise: white noise filtered by an anisotropic Gaussian in frequency space."""
    w = rng.standard_normal((n, n))
    fy, fx = np.meshgrid(np.fft.fftfreq(n), np.fft.fftfreq(n), indexing="ij")
    c, s = np.cos(angle), np.sin(angle)
    u, v = c * fx + s * fy, -s * fx + c * fy
    filt = np.exp(-(u * sx) ** 2 - (v * sy) ** 2)
    out = np.real(np.fft.ifft2(np.fft.fft2(w) * filt))
    out -= out.mean(); out /= out.std() + 1e-9
    return out


def norm01(a): a = a - a.min(); return a / (a.max() + 1e-9)


# ---- ramp ----------------------------------------------------------------------------------------
stops = [hexrgb("#4A8A93"), hexrgb("#6CBCAF"), hexrgb("#8EDDC9")]
ramp = np.zeros((1, 256, 3))
for i in range(256):
    t = i / 255
    def step(x, e, w=0.05): return np.clip((x - (e - w / 2)) / w, 0, 1)
    a, b = step(t, 0.33, 0.08), step(t, 0.62, 0.12)          # soft painted edges (reasoner B2, #658)
    col = stops[0] * (1 - a) + stops[1] * a
    col = col * (1 - b) + stops[2] * b
    ramp[0, i] = col
Image.fromarray(ramp.astype(np.uint8)).save(os.path.join(OUT, "grub_ramp.png"))

# ---- brush strokes ------------------------------------------------------------------------------
N = 512
# B2: long soft horizontal strokes (~6:1), low contrast, so marks wrap round the body like brushwork
strokes = periodic_noise(N, 3.0, 18.0, 0.0)                  # long in x, short in y
strokes += 0.35 * periodic_noise(N, 1.6, 9.0, 0.12)
ox2 = (periodic_noise(N, 8, 8) * 6).astype(int)
yy2, xx2 = np.mgrid[0:N, 0:N]
strokes = strokes[(yy2 + ox2) % N, xx2]
strokes = np.tanh(strokes * 1.2)
strokes = (strokes - strokes.mean()) / (strokes.std() + 1e-9) * 0.15 + 0.5
Image.fromarray((np.clip(strokes, 0, 1) * 255).astype(np.uint8), "L").convert("RGB").save(os.path.join(OUT, "brush_b2.png"))
acc = np.zeros((N, N))
for k, ang in enumerate((0.35, 1.2, 2.4)):
    strokes = periodic_noise(N, 40.0, 4.0, ang)          # long along one axis: streaky
    acc += np.tanh(strokes * 1.6) * (1.0 if k == 0 else 0.6)
warp = periodic_noise(N, 10.0, 10.0)
# domain warp: resample along a smooth offset field (wraps, so still tileable)
yy, xx = np.mgrid[0:N, 0:N]
ox = (periodic_noise(N, 12, 12) * 9).astype(int); oy = (periodic_noise(N, 12, 12) * 9).astype(int)
acc = acc[(yy + oy) % N, (xx + ox) % N] + 0.25 * warp
brush = norm01(acc)
Image.fromarray((brush * 255).astype(np.uint8), "L").convert("RGB").save(os.path.join(OUT, "brush.png"))

# ---- paper grain --------------------------------------------------------------------------------
P = 1024
fine = periodic_noise(P, 900.0, 900.0)
fibre = periodic_noise(P, 300.0, 30.0, 0.7) * 0.5
blot = periodic_noise(P, 60.0, 60.0) * 0.6
paper = norm01(fine * 0.6 + fibre + blot)
paper = 0.80 + 0.20 * paper                                  # near white: it is multiplied in
Image.fromarray((paper * 255).astype(np.uint8), "L").convert("RGB").save(os.path.join(OUT, "paper.png"))

# ---- painted contact shadow ---------------------------------------------------------------------
S = 256
y, x = (np.mgrid[0:S, 0:S] + 0.5) / S * 2 - 1
r = np.sqrt(x * x + y * y)
ang = np.arctan2(y, x)
edge = 0.82 + 0.06 * np.sin(ang * 3 + 0.7) + 0.035 * np.sin(ang * 7 + 2.1) + 0.02 * np.sin(ang * 13)
grain = periodic_noise(S, 30.0, 30.0) * 0.05
core = np.clip((edge + grain - r) / 0.22, 0, 1)               # soft but ragged edge
core = core ** 0.8 * (0.85 + 0.15 * norm01(periodic_noise(S, 20.0, 6.0, 0.3)))
a = (np.clip(core, 0, 1) * 255).astype(np.uint8)
rgba = np.dstack([np.full((S, S), 255, np.uint8)] * 3 + [a])
Image.fromarray(rgba, "RGBA").save(os.path.join(OUT, "painted_shadow.png"))
print("painted textures ->", OUT)

# ---- B3: soft gouache dabs (no direction), ~3-5 across the body at _BrushScale ~0.6 ---------------
D = 512
dab = np.zeros((D, D)); ys, xs = np.mgrid[0:D, 0:D]
for _ in range(70):
    cx, cy = rng.uniform(0, D, 2); r = rng.uniform(40, 95); ex = rng.uniform(0.7, 1.3); th = rng.uniform(0, np.pi)
    dx = (xs - cx + D / 2) % D - D / 2; dy = (ys - cy + D / 2) % D - D / 2          # wrap: tileable
    u = (dx * np.cos(th) + dy * np.sin(th)) / ex; v = (-dx * np.sin(th) + dy * np.cos(th)) * ex
    edge = r * (1 + 0.12 * periodic_noise(D, 25, 25)[int(cy) % D, int(cx) % D])
    m = np.clip((edge - np.sqrt(u * u + v * v)) / 6.0, 0, 1)                       # ~6px soft edge (2-3px at use size)
    dab = dab * (1 - m) + m * rng.uniform(-1, 1)                                     # paint over: each dab its own value
dab += 0.15 * periodic_noise(D, 40, 40)
dab = (dab - dab.mean()) / (dab.std() + 1e-9) * 0.18 + 0.5
Image.fromarray((np.clip(dab, 0, 1) * 255).astype(np.uint8), "L").convert("RGB").save(os.path.join(OUT, "brush_dab.png"))
print("brush_dab done")
