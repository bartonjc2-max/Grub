#!/usr/bin/env python3
"""Export Grub's face rig data for Unity (GrubUnity/Assets/Grub/Face/):
  grub_face_layout.json   canon eye / pupil / mouth layout in Grub units (Blender metres, height 1)
  grub_face_states.json   every expression's parameters, with the pupil decision applied
  grub_face_tired.json    the Vector tired port as a baked 24 fps parameter loop
Usage: python3 export_face_unity.py vector_anim.json
"""
import json, os, sys
import numpy as np
import face_rig as fr
import vector_to_grub as vg

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
OUT = os.path.normpath(os.path.join(ROOT, "..", "..", "..", "GrubUnity", "Assets", "Grub", "Face"))
os.makedirs(OUT, exist_ok=True)

# ---- layout in Grub units, same maths as build_grub.py
m = json.load(open(os.path.join(ROOT, "grub_measure.json")))
eL, eR, mo, hL, hR = m["eyeL"], m["eyeR"], m["mouth"], m["hiL"], m["hiR"]
ex = ((eL["x0"] + eL["x1"]) / 2 - (eR["x0"] + eR["x1"]) / 2) / 2
ew = ((eL["x1"] - eL["x0"]) + (eR["x1"] - eR["x0"])) / 2
eh = ((eL["z1"] - eL["z0"]) + (eR["z1"] - eR["z0"])) / 2
ez = (eL["z0"] + eL["z1"] + eR["z0"] + eR["z1"]) / 4
hs = ((hL["x1"] - hL["x0"]) + (hR["x1"] - hR["x0"]) + (hL["z1"] - hL["z0"]) + (hR["z1"] - hR["z0"])) / 4
mw, mh, mz = mo["x1"] - mo["x0"], mo["z1"] - mo["z0"], (mo["z0"] + mo["z1"]) / 2
layout = {
    "eyeX": ex, "eyeW": ew, "eyeH": eh, "eyeZ": ez, "corner": 0.035,
    "pupil": hs, "mouthW": mw, "mouthH": mh, "mouthZ": mz,
    # the feature box the geometry eyes + mouth occupy (used to place the decal on the model)
    "boxXMin": -(ex + ew / 2), "boxXMax": ex + ew / 2, "boxZMin": mz - mh / 2, "boxZMax": ez + eh / 2,
}
json.dump(layout, open(os.path.join(OUT, "grub_face_layout.json"), "w"), indent=1)

# ---- states: Jesse's pick (2026-11-19) = the Vector eye poses ported onto Grub (port_poses.py),
# hand-made mouths, pupil picks; Happy gets a pupil too. Hand-made only where Vector has no pose.
keys = list(fr.NEUTRAL.keys())
VECTOR_PICK = {"Content": "default", "Happy": "happy", "Eating": "bliss", "Sad": "sad", "Grumpy": "angry",
               "Surprised": "shocked", "Asleep": "asleep", "Refusing": "suspicious", "Dirty": "squint",
               "Hungry": "concerned", "Sick (S2)": "hurt"}
PUPIL_OVERRIDE = {"Happy": True}
import port_poses as pp
pp.SRC = os.path.join(os.path.dirname(sys.argv[1]), "poses")
v0 = pp.pose("default")
states = []
for name, kw in fr.STATES.items():
    if name in VECTOR_PICK:
        p = pp.ported(name, VECTOR_PICK[name], v0)
        if PUPIL_OVERRIDE.get(name): p["ps"] = 1.0
    else:
        p = fr.params(**kw)
        if not fr.PUPIL_PICK[name]: p["ps"] = 0.0
        elif p["ps"] == 0: p["ps"] = 1.0
    states.append({"name": name.split(" ")[0], "values": [float(p[k]) for k in keys]})
json.dump({"keys": keys, "states": states}, open(os.path.join(OUT, "grub_face_states.json"), "w"), indent=1)

# ---- tired loop (the vector_to_grub port, baked)
ks = vg.vector_keys(sys.argv[1]); v0 = vg.sample(ks, 0); end = ks[-1]["triggerTime_ms"]
step = 1000 / vg.FPS / vg.STRETCH
seq = [vg.to_grub(vg.sample(ks, t), v0) for t in np.arange(0, end + step, step)]
arr = np.array([[p[k] for k in keys] for p in seq])
n_re = int(vg.REOPEN_MS / 1000 * vg.FPS); n_hold = int(vg.HOLD_MS / 1000 * vg.FPS)
last, first = arr[-1], arr[0]
reopen = np.array([last + (first - last) * fr.ease((i + 1) / n_re) for i in range(n_re)])
arr = np.vstack([arr, np.repeat(arr[-1:], n_hold, 0), reopen, np.repeat(first[None], n_hold, 0)])
w = max(1, int(vg.SMOOTH_MS / 1000 * vg.FPS)); kern = np.ones(w) / w
pad = np.vstack([arr[-w:], arr, arr[:w]])
sm = np.stack([np.convolve(pad[:, j], kern, mode="same") for j in range(arr.shape[1])], 1)[w:-w]
json.dump({"keys": keys, "fps": vg.FPS, "frames": [[round(float(x), 4) for x in row] for row in sm]},
          open(os.path.join(OUT, "grub_face_tired.json"), "w"))
print("exported to", OUT, "| states", len(states), "| tired frames", len(sm), "| keys", keys)
