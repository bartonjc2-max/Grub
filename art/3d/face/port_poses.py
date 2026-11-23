#!/usr/bin/env python3
"""Port Vector's eye poses onto Grub's canon eyes and compare with the hand-made expressions.

For each Grub state: the hand-made face (face_rig.STATES) next to one or two Vector eyeposes
(DDL vector-animations-build, anim_eyeposes_01) mapped through vector_to_grub.to_grub:
Vector's lids, eye size and tilt drive the eyes; the pupil follows Jesse's pupil picks; the mouth
and extras (blush, tear, sweat) stay hand-made because Vector has no mouth.
Usage: python3 port_poses.py <dir with anim_eyepose_*.json renamed to <pose>.json> -> poses_compare.png, vector_poses.json
"""
import json, os, sys
from PIL import Image, ImageDraw, ImageFont
import face_rig as fr
import vector_to_grub as vg

HERE = os.path.dirname(os.path.abspath(__file__))
SRC = sys.argv[1] if __name__ == "__main__" and len(sys.argv) > 1 else ""
MAP = {
    "Content": ["default"], "Happy": ["happy", "joy"], "Eating": ["bliss"], "Sad": ["sad", "sad_down"],
    "Grumpy": ["angry", "frustrated"], "Surprised": ["shocked", "startled"], "Asleep": ["asleep"],
    "Refusing": ["suspicious", "bothered"], "Dirty": ["squint"], "Hungry": ["concerned", "curious"],
    "Sick (S2)": ["hurt"],
}
EXTRAS = ("mw", "mb", "mo", "mwave", "mdy", "blush", "tear", "sweat", "zzz")


def pose(name):
    d = json.load(open(os.path.join(SRC, name + ".json"))); frames = next(iter(d.values()))
    k = [x for x in frames if x.get("Name") == "ProceduralFaceKeyFrame"][-1]
    return {key: k.get(key, 0) for key in ("faceCenterX", "faceCenterY", "faceScaleX", "faceScaleY", "faceAngle")} | \
           {"leftEye": k["leftEye"], "rightEye": k["rightEye"]}


def ported(state, vec_name, v0):
    p = vg.to_grub(pose(vec_name), v0)
    hand = fr.params(**fr.STATES[state])
    for k in EXTRAS: p[k] = hand[k]
    if not fr.PUPIL_PICK[state]: p["ps"] = 0.0
    return p


def main():
    v0 = pose("default")
    F = fr.FONT
    f1, f2 = ImageFont.truetype(F, 30), ImageFont.truetype(F, 22)
    cw, ch, lab = 300, 250, 44
    rows = list(MAP.items())
    out = Image.new("RGB", (40 + 3 * (cw + 16), 20 + len(rows) * (ch + lab + 30)), (250, 242, 230))
    d = ImageDraw.Draw(out)
    export = {}
    for r, (state, vec) in enumerate(rows):
        y0 = 20 + r * (ch + lab + 30)
        d.text((20, y0 - 2), state.replace(" (S2)", " (Sprint 2)"), fill=(129, 79, 50), font=f1)
        cells = [("hand-made", fr.params(**fr.STATES[state]))] + [(f"Vector: {v}", ported(state, v, v0)) for v in vec]
        for c, (title, p) in enumerate(cells):
            x = 20 + c * (cw + 16)
            if c > 0: export[f"{state}|{vec[c - 1]}"] = {k: float(v) for k, v in p.items()}
            img = fr.render(p).crop((262, 230, 762, 650)).resize((cw, ch), Image.LANCZOS)
            out.paste(img, (x, y0 + 36))
            d.text((x + cw // 2, y0 + 36 + ch + 6), title, fill=(150, 110, 85), font=f2, anchor="ma")
    out.save(os.path.join(HERE, "poses_compare.png"))
    json.dump(export, open(os.path.join(HERE, "vector_poses.json"), "w"), indent=1)
    print("poses_compare.png", out.size, "|", len(export), "ported poses")


if __name__ == "__main__":
    main()
