#!/usr/bin/env python3
"""Port a Vector face animation onto Grub's canon eyes (not 1:1).

Takes Vector's keyframes (DDL vector-animations-build JSON) and maps them onto face_rig's
Grub parameters:
  lids      Vector upper/lower lid y, angle and bend -> Grub lids (the part that carries the mood)
  eye size  Vector eye scale relative to its first keyframe -> Grub sx/sy (softened)
  tilt      Vector eye angle -> Grub rot (softened)
  position  Vector face/eye centre -> small Grub eye offsets (softened: Grub's eyes live on a body)
  pupil     visible while the eye is open enough to read gaze; it sinks as the lids drop and
            shrinks away as they close, so it never pops
Grub-feel changes: time stretched (STRETCH), every channel low-passed (no Vector darts), eased
segments, and the loop ends by slowly reopening into frame 0 instead of snapping.
Usage: python3 vector_to_grub.py vector_anim.json out.gif
"""
import json, math, sys
import numpy as np
from PIL import Image
import face_rig as fr

STRETCH = 1.7          # Grub is slower than Vector
SMOOTH_MS = 320        # low-pass window: removes the quick darts
REOPEN_MS = 2200       # slow reopen back to the first pose for a seamless loop
HOLD_MS = 500
FPS = 24
MOTION = 0.45          # how much of Vector's eye/face travel Grub keeps
SIZE = 0.6             # how much of Vector's eye-size change Grub keeps
LID_ANGLE = float(__import__("os").environ.get("LID_ANGLE", "2.0"))   # Vector lid angles carry over (same sign: - lifts the inner corner)


def vector_keys(path):
    data = json.load(open(path)); frames = next(iter(data.values()))
    ks = sorted([k for k in frames if k.get("Name") == "ProceduralFaceKeyFrame"], key=lambda k: k["triggerTime_ms"])
    return ks


def sample(ks, t):
    """Vector params at time t (ms), eased between keyframes."""
    prev = ks[0]; nxt = ks[-1]
    for k in ks:
        if k["triggerTime_ms"] <= t: prev = k
    later = [k for k in ks if k["triggerTime_ms"] > t]
    if not later: return prev
    nxt = later[0]
    span = nxt["triggerTime_ms"] - prev["triggerTime_ms"]
    u = fr.ease((t - prev["triggerTime_ms"]) / span) if span > 0 else 1
    out = {}
    for key in ("faceCenterX", "faceCenterY", "faceScaleX", "faceScaleY", "faceAngle"):
        out[key] = prev.get(key, 0) + (nxt.get(key, 0) - prev.get(key, 0)) * u
    for key in ("leftEye", "rightEye"):
        out[key] = [a + (b - a) * u for a, b in zip(prev[key], nxt[key])]
    return out


def to_grub(v, v0):
    """Map one Vector frame onto Grub face params (both eyes averaged: Grub's face is symmetric)."""
    L, R, L0, R0 = v["leftEye"], v["rightEye"], v0["leftEye"], v0["rightEye"]
    avg = lambda i: (L[i] + R[i]) / 2
    avg0 = lambda i: (L0[i] + R0[i]) / 2
    sx = 1 + SIZE * (avg(2) / avg0(2) * v["faceScaleX"] / v0["faceScaleX"] - 1)
    sy = 1 + SIZE * (avg(3) / avg0(3) * v["faceScaleY"] / v0["faceScaleY"] - 1)
    uy, ly = avg(13), avg(16)
    openness = max(0.0, 1 - uy - ly) * sy
    p = fr.params(
        sx=sx, sy=sy,
        rot=MOTION * (L[4] - R[4]) / 2 * 0.5,
        dx=MOTION * ((v["faceCenterX"] - v0["faceCenterX"]) * 0.79 / fr.L["eye"]["w_px"] * 4),
        dy=MOTION * ((v["faceCenterY"] - v0["faceCenterY"]) * 0.75 / fr.L["eye"]["h_px"] * 4) * 0.5,
        uy=uy, ua=avg(14) * LID_ANGLE, ub=avg(15),
        ly=ly, la=avg(17) * LID_ANGLE, lb=avg(18),
        # pupil: rides under the upper lid, fades as the eye closes
        py=-0.45 + 1.6 * uy, ps=float(np.clip((openness - 0.28) / 0.35, 0, 1)),
        mw=0.9, mdy=0.02 + 0.06 * uy,
    )
    return p


def main(src, out):
    ks = vector_keys(src)
    v0 = sample(ks, 0)
    end = ks[-1]["triggerTime_ms"]
    # dense Vector-timed samples (ms), mapped to Grub, then stretched + smoothed
    step = 1000 / FPS / STRETCH
    seq = [to_grub(sample(ks, t), v0) for t in np.arange(0, end + step, step)]
    keys = list(seq[0].keys())
    arr = np.array([[p[k] for k in keys] for p in seq])
    # reopen: ease back to the first pose, then hold — seamless loop, no snap
    n_re = int(REOPEN_MS / 1000 * FPS); n_hold = int(HOLD_MS / 1000 * FPS)
    last, first = arr[-1], arr[0]
    reopen = np.array([last + (first - last) * fr.ease((i + 1) / n_re) for i in range(n_re)])
    arr = np.vstack([arr, np.repeat(arr[-1:], n_hold, 0), reopen, np.repeat(first[None], n_hold, 0)])
    # low-pass every channel (circular, so the loop seam stays smooth)
    w = max(1, int(SMOOTH_MS / 1000 * FPS))
    kern = np.ones(w) / w
    pad = np.vstack([arr[-w:], arr, arr[:w]])
    sm = np.stack([np.convolve(pad[:, j], kern, mode="same") for j in range(arr.shape[1])], 1)[w:-w]
    frames = []
    for row in sm:
        p = dict(zip(keys, row))
        frames.append(fr.render(p).crop((262, 200, 762, 640)).resize((375, 330), Image.LANCZOS))
    frames[0].save(out, save_all=True, append_images=frames[1:], duration=int(1000 / FPS), loop=0, optimize=True)
    print("wrote", out, len(frames), "frames,", round(len(frames) / FPS, 1), "s")


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
