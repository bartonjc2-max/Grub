#!/usr/bin/env python3
"""Render a Vector (Anki/DDL) face animation from its open-source JSON keyframes to a GIF.

Data: github.com/digital-dream-labs/vector-animations-build  assets/animations/**.json
Geometry: the ProceduralFace / ProceduralEye / ProceduralLid maths from pycozmo (MIT,
github.com/zayfod/pycozmo, pycozmo/procedural_face.py), ported to grayscale masks at 4x
resolution so edges are smooth, then tinted with Vector's teal glow on a black screen.

Each ProceduralFaceKeyFrame has faceCenterX/Y, faceScaleX/Y, faceAngle and 25 floats per eye;
the first 19 are pycozmo's order:
  0 centerX 1 centerY 2 scaleX 3 scaleY 4 angle
  5 lowerInnerRadX 6 lowerInnerRadY 7 lowerOuterRadX 8 lowerOuterRadY
  9 upperInnerRadX 10 upperInnerRadY 11 upperOuterRadX 12 upperOuterRadY
  13 upperLidY 14 upperLidAngle 15 upperLidBend 16 lowerLidY 17 lowerLidAngle 18 lowerLidBend
  (19.. saturation, lightness, glow, hotspot — colour only)
Parameters are interpolated linearly between keyframes by trigger time, as Vector's animation
system does. Usage: python3 vector_face_render.py anim.json out.gif [--fps 30] [--scale 4]
"""
import argparse, json, math
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

W0, H0 = 184, 96                  # Vector's screen
EYE_W0, EYE_H0 = 28 * W0 / 128 * 0.82, 40 * H0 / 64 * 0.82   # pycozmo nominal eye, scaled to Vector screen (trimmed to match Vector photos)
X_FACTOR, Y_FACTOR = 0.55 * W0 / 128, 0.25 * H0 / 64 * 2.0
EYE_COLOR = np.array([62, 224, 196]) / 255     # Vector's default teal-green


def render_face(face, S):
    """face: dict with faceCenterX/Y, faceScaleX/Y, faceAngle, leftEye[], rightEye[] -> L image."""
    W, H = W0 * S, H0 * S
    eye_w, eye_h = EYE_W0 * S, EYE_H0 * S
    corner = (W / 20 + H / 10) * 0.55
    canvas = Image.new("L", (W, H), 0)
    for side, key in ((-1, "leftEye"), (1, "rightEye")):
        p = face[key]
        eye = Image.new("L", (W, H), 0); d = ImageDraw.Draw(eye)
        x1, y1, x2, y2 = W / 2 - eye_w / 2, H / 2 - eye_h / 2, W / 2 + eye_w / 2, H / 2 + eye_h / 2
        # rounded rectangle with independent corner radii (pycozmo: inner = toward nose, drawn on the right)
        lir = (corner * p[5], corner * p[6]); lor = (corner * p[7], corner * p[8])
        uir = (corner * p[9], corner * p[10]); uor = (corner * p[11], corner * p[12])
        poly = []
        def arc(cx, cy, rx, ry, a0, a1, n=16):
            for i in range(n + 1):
                a = math.radians(a0 + (a1 - a0) * i / n)
                poly.append((cx + rx * math.cos(a), cy + ry * math.sin(a)))
        arc(x1 + uor[0], y1 + uor[1], uor[0], uor[1], 180, 270)       # upper outer
        arc(x2 - uir[0], y1 + uir[1], uir[0], uir[1], 270, 360)       # upper inner
        arc(x2 - lir[0], y2 - lir[1], lir[0], lir[1], 0, 90)          # lower inner
        arc(x1 + lor[0], y2 - lor[1], lor[0], lor[1], 90, 180)        # lower outer
        d.polygon(poly, fill=255)
        # lids (pycozmo ProceduralLid): rect + chord, rotated about the eye centre, painted black
        for li, (y_off, ang_off) in enumerate(((-eye_h / 2, 0.0), (eye_h / 2 + S, 180.0))):
            ly, la, lb = p[13 + li * 3], p[14 + li * 3], p[15 + li * 3]
            lid = Image.new("L", (W * 2, H * 2), 0); ld = ImageDraw.Draw(lid)
            lid_h = eye_h * ly
            sh, sb = 1.2 * eye_w, 1.2 * eye_w / 2
            ld.rectangle([W - sh, H - eye_h / 2, W + sh, H + lid_h], fill=255)
            bend_h = eye_h * (1 - ly) * lb
            if abs(bend_h) > 0.5:
                ld.chord([W - sb, H + lid_h - abs(bend_h), W + sb, H + lid_h + abs(bend_h)], 0 if bend_h > 0 else 180,
                         180 if bend_h > 0 else 360, fill=255 if bend_h > 0 else 0)
            lid = lid.rotate(la + ang_off, resample=Image.BICUBIC, expand=False)
            lid = lid.crop((W // 2, H // 2 - int(y_off), W // 2 + W, H // 2 - int(y_off) + H))
            eye.paste(0, (0, 0), lid)
        # eye transform: mirror the right eye so "inner" faces the nose, then rotate, scale, place
        if side < 0: eye = eye.transpose(Image.FLIP_LEFT_RIGHT)
        eye = eye.rotate(p[4], resample=Image.BICUBIC, center=(W / 2, H / 2))
        sx, sy = max(p[2], 0.01), max(p[3], 0.01)
        ew, eh = max(1, int(W * sx)), max(1, int(H * sy))
        eye = eye.resize((ew, eh), Image.BICUBIC)
        ox = side * W / 3.7 + p[0] * X_FACTOR * S
        oy = p[1] * Y_FACTOR * S
        layer = Image.new("L", (W, H), 0)
        layer.paste(eye, (int(W / 2 - ew / 2 + ox), int(H / 2 - eh / 2 + oy)))
        canvas = Image.fromarray(np.maximum(np.asarray(canvas), np.asarray(layer)))
    # face transform
    canvas = canvas.rotate(face.get("faceAngle", 0), resample=Image.BICUBIC)
    fsx, fsy = max(face.get("faceScaleX", 1), 0.01), max(face.get("faceScaleY", 1), 0.01)
    fw, fh = max(1, int(W * fsx)), max(1, int(H * fsy))
    scaled = canvas.resize((fw, fh), Image.BICUBIC)
    out = Image.new("L", (W, H), 0)
    out.paste(scaled, (int(W / 2 - fw / 2 + face.get("faceCenterX", 0) * X_FACTOR * S),
                       int(H / 2 - fh / 2 + face.get("faceCenterY", 0) * Y_FACTOR * S)))
    return out


def colorize(mask, S):
    m = np.asarray(mask).astype(np.float32) / 255
    glow = np.asarray(mask.filter(ImageFilter.GaussianBlur(3 * S))).astype(np.float32) / 255
    rgb = EYE_COLOR[None, None, :] * np.clip(m + 0.55 * glow, 0, 1)[..., None]
    rgb = rgb + 0.25 * (m ** 2)[..., None]                    # hot core
    rows = (np.arange(rgb.shape[0]) // S) % 2 == 1            # Vector's faint scanlines
    rgb[rows] *= 0.86
    img = Image.fromarray((np.clip(rgb, 0, 1) * 255).astype(np.uint8))
    # bezel
    W, H = img.size
    frame = Image.new("RGB", (W + 16 * S, H + 16 * S), (18, 18, 20)); frame.paste(img, (8 * S, 8 * S))
    return frame


def lerp_face(a, b, t):
    out = {}
    for k in ("faceCenterX", "faceCenterY", "faceScaleX", "faceScaleY", "faceAngle"):
        out[k] = a.get(k, 0) + (b.get(k, 0) - a.get(k, 0)) * t
    for k in ("leftEye", "rightEye"):
        out[k] = [x + (y - x) * t for x, y in zip(a[k], b[k])]
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("anim"); ap.add_argument("out")
    ap.add_argument("--fps", type=int, default=30); ap.add_argument("--scale", type=int, default=4)
    ap.add_argument("--hold_ms", type=int, default=600)
    a = ap.parse_args()
    data = json.load(open(a.anim))
    name, frames = next(iter(data.items()))
    keys = sorted([k for k in frames if k.get("Name") == "ProceduralFaceKeyFrame"], key=lambda k: k["triggerTime_ms"])
    end = max(k["triggerTime_ms"] + k.get("durationTime_ms", 0) for k in keys) + a.hold_ms
    print(name, "face keyframes:", len(keys), "duration ms:", end)
    images = []
    for i in range(int(end / 1000 * a.fps) + 1):
        t = i * 1000 / a.fps
        prev = keys[0]; nxt = keys[0]
        for k in keys:
            if k["triggerTime_ms"] <= t: prev = k
        later = [k for k in keys if k["triggerTime_ms"] > t]
        if later:
            nxt = later[0]
            span = nxt["triggerTime_ms"] - prev["triggerTime_ms"]
            f = lerp_face(prev, nxt, (t - prev["triggerTime_ms"]) / span if span > 0 else 1)
        else:
            f = prev
        images.append(colorize(render_face(f, a.scale), a.scale))
    small = [im.resize((im.width // 2, im.height // 2), Image.LANCZOS) for im in images]
    small[0].save(a.out, save_all=True, append_images=small[1:], duration=int(1000 / a.fps), loop=0, optimize=True)
    small[len(small) // 2].save(a.out.replace(".gif", "_mid.png"))
    print("wrote", a.out, len(small), "frames", small[0].size)


if __name__ == "__main__":
    main()
