#!/usr/bin/env python3
"""Grub's procedural face, Anki-Vector style, built on the canon eyes.

The canon eye is a rounded dark square with a lighter outline and a cream square pupil
(GrubIOS/docs/canon). Expressions never redraw the eye: like Cozmo/Vector's ProceduralFace,
each eye is the same rounded square with parameters, and skin-coloured lids cut into it:

  eye    dx, dy   offset (in eye widths/heights)      sx, sy  scale       rot  tilt (deg, mirrored)
  upper  y        how far the upper lid comes down (0..1 of the eye height)
         angle    lid tilt in degrees; + drops the inner (nose) corner = cross/determined
         bend     curve; + sags in the middle (heavy/sleepy), − arches (surprised)
  lower  y, angle, bend   same from the bottom; + bend pushes the middle up = happy crescent
  pupil  px, py   position inside the eye (−1..1)     ps  size scale    (0 hides it)
  mouth  w scale, bend (+smile/−frown), open (0 line … 1 round 'o'), wave (icky wobble), dy
  extras blush, tear, sweat, zzz

Expressions blend by interpolating every number (Vector's animation system does the same), and
blinks are a fast squash of sy. Usage: python3 face_rig.py  -> faces_sheet.png, faces_demo.gif
"""
import json, math, os
import numpy as np
from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
L = json.load(open(os.path.join(HERE, "face_layout.json")))
BASE = Image.open(os.path.join(HERE, "grub_faceless.png")).convert("RGB")
FONT = "/Users/jessedev/Documents/Code/grub/GrubUnity/Assets/Grub/UI/Fonts/Fredoka-Bold.ttf"

EYE_FILL = np.array([42, 54, 69]) / 255        # canon eye navy #2A3645
EYE_EDGE = np.array([96, 108, 124]) / 255      # lighter outline ring
PUPIL = np.array([239, 233, 214]) / 255        # cream square pupil
MOUTH = np.array([42, 54, 69]) / 255
SS = 3                                         # supersampling

NEUTRAL = dict(dx=0, dy=0, sx=1, sy=1, rot=0, uy=0, ua=0, ub=0, ly=0, la=0, lb=0,
               px=0, py=-0.45, ps=1, mw=1, mb=0, mo=0, mwave=0, mdy=0,
               blush=0, tear=0, sweat=0, zzz=0)

STATES = {
    "Content":   {},
    "Happy":     dict(ly=0.22, lb=0.42, py=-0.6, ps=0.85, mw=1.05, mb=0.55, blush=0.45, dy=-0.03),
    "Hungry":    dict(ua=-14, uy=0.06, py=-0.9, ps=1.1, sy=1.06, mw=0.45, mo=0.55, dy=-0.04),
    "Tired":     dict(uy=0.46, ub=0.12, sy=0.92, py=0.25, mw=0.8, mdy=0.05, dy=0.03),
    "Asleep":    dict(sy=0.11, ub=0.0, py=0.0, ps=0, mw=0.55, mdy=0.04, dy=0.08, zzz=1),
    "Dirty":     dict(uy=0.24, ly=0.24, sx=1.04, sy=0.94, py=0.0, mw=0.9, mwave=1, sweat=1),
    "Sad":       dict(ua=-20, uy=0.18, py=0.55, sy=0.96, dy=0.05, mw=0.75, mb=-0.5, tear=1),
    "Eating":    dict(ly=0.18, lb=0.38, py=-0.5, mw=0.55, mo=0.85, blush=0.35),
    "Refusing":  dict(uy=0.34, ly=0.18, ub=-0.05, px=0.75, py=0.1, mw=0.7, mb=-0.12),
    "Grumpy":    dict(ua=24, uy=0.30, ly=0.12, sy=0.94, py=0.1, mw=0.8, mb=-0.3),
    "Surprised": dict(sx=1.12, sy=1.2, ub=-0.08, py=-0.1, ps=0.75, mw=0.4, mo=0.95, dy=-0.04),
    "Sick (S2)": dict(uy=0.40, ua=-6, sy=0.88, py=0.35, ps=0.9, mw=0.7, mwave=0.6, mb=-0.15, blush=0.25),
}


def params(**kw):
    p = dict(NEUTRAL); p.update(kw); return p


def lerp(a, b, t):
    return {k: a[k] + (b[k] - a[k]) * t for k in a}


def ease(t):
    return t * t * (3 - 2 * t)


# --------------------------------------------------------------------------- SDF helpers
def sd_round_box(x, y, hw, hh, r):
    qx, qy = np.abs(x) - hw + r, np.abs(y) - hh + r
    return np.hypot(np.maximum(qx, 0), np.maximum(qy, 0)) + np.minimum(np.maximum(qx, qy), 0) - r


def cov(d, aa=1.0):
    """Signed distance -> coverage (0..1), anti-aliased over ~1 px."""
    return np.clip(0.5 - d / aa, 0, 1)


def draw_eye(canvas, X, Y, cx, cy, p, side):
    e = L["eye"]
    W, H = e["w_px"] * p["sx"] * SS, e["h_px"] * p["sy"] * SS
    cx = (cx + p["dx"] * e["w_px"]) * SS; cy = (cy + p["dy"] * e["h_px"]) * SS
    th = math.radians(p["rot"] * side)
    x = (X - cx) * math.cos(th) + (Y - cy) * math.sin(th)
    y = -(X - cx) * math.sin(th) + (Y - cy) * math.cos(th)
    hw, hh = W / 2, H / 2
    r = min(e["corner_px"] * SS, hw, hh)
    d = sd_round_box(x, y, hw, hh, r)
    inside = cov(d, SS)
    if hh < 2 * SS:                                 # closed: draw as a soft bar
        inside = cov(sd_round_box(x, y, hw, max(hh, 2.5 * SS), 2.5 * SS), SS)
    # lids: x_in runs toward the nose, so + angle lowers the inner corner on both eyes
    xn = x / max(hw, 1)
    x_in = -xn * side
    upper = -hh + p["uy"] * 2 * hh + math.tan(math.radians(p["ua"])) * x_in * hw + p["ub"] * (1 - xn ** 2) * 2 * hh
    lower = hh - p["ly"] * 2 * hh - math.tan(math.radians(p["la"])) * x_in * hw - p["lb"] * (1 - xn ** 2) * 2 * hh
    lids = cov(upper - y, SS) * cov(y - lower, SS)
    a = inside * lids
    # the canon outline follows the visible shape, lid cuts included (Grub's eye edge is a feature)
    shape_d = np.maximum(d, np.maximum(upper - y, y - lower))
    edge = cov(shape_d + 4.5 * SS, SS)              # 1 inside the inner region (fill); the band outside it is the outline
    col = EYE_EDGE[None, None, :] * (1 - edge[..., None]) + EYE_FILL[None, None, :] * edge[..., None]
    # pupil: cream rounded square, moves inside the eye
    ps = L["pupil"]["size_px"] * p["ps"] * SS
    if ps > 0:
        free_x, free_y = max(hw - ps * 0.5 - 8 * SS, 0), max(hh - ps * 0.5 - 8 * SS, 0)
        pcx, pcy = p["px"] * free_x * (1 if side > 0 else 1), p["py"] * free_y
        pd = sd_round_box(x - pcx, y - pcy, ps / 2, ps / 2, ps * 0.18)
        pa = cov(pd, SS) * cov(shape_d + 6 * SS, SS)
        col = col * (1 - pa[..., None]) + PUPIL[None, None, :] * pa[..., None]
    canvas[:] = canvas * (1 - a[..., None]) + col * a[..., None]


def draw_mouth(canvas, X, Y, p):
    m = L["mouth"]
    cx, cy = m["cx_px"] * SS, (m["cy_px"] + p["mdy"] * L["eye"]["h_px"] + p["dy"] * 20) * SS
    hw = m["w_px"] * p["mw"] * SS / 2
    th = m["h_px"] * 0.55 * SS
    if p["mo"] > 0.02:                              # open mouth: dark rounded 'o'
        rx = max(hw * 0.75, th * 0.9) * (0.6 + 0.4 * p["mo"]); ry = th * (0.8 + 1.6 * p["mo"])
        d = (np.hypot((X - cx) / rx, (Y - cy) / ry) - 1) * min(rx, ry)
        a = cov(d, SS)
    else:
        u = np.clip((X - cx) / max(hw, 1), -1, 1)
        curve = cy + p["mb"] * hw * 0.45 * (1 - u ** 2) + p["mwave"] * th * 0.9 * np.sin(u * math.pi * 2.5)
        dist = np.abs(Y - curve) - th / 2
        ends = np.abs(X - cx) - hw
        d = np.maximum(dist, ends)
        a = cov(d, SS) * (np.abs(X - cx) <= hw + th)
    canvas[:] = canvas * (1 - a[..., None]) + MOUTH[None, None, :] * a[..., None]


def overlay_ellipse(canvas, X, Y, cx, cy, rx, ry, color, alpha):
    d = (np.hypot((X - cx) / rx, (Y - cy) / ry) - 1) * min(rx, ry)
    a = cov(d, 6 * SS) * alpha
    canvas[:] = canvas * (1 - a[..., None]) + np.array(color)[None, None, :] * a[..., None]


def render(p, base=BASE, label=None):
    e = L["eye"]
    x0, y0, x1, y1 = 300, 260, 724, 600              # face crop (base px)
    crop = np.asarray(base.crop((x0, y0, x1, y1)).resize(((x1 - x0) * SS, (y1 - y0) * SS), Image.BICUBIC)).astype(np.float32) / 255
    H, W, _ = crop.shape
    Y, X = np.mgrid[0:H, 0:W].astype(np.float32)
    X += x0 * SS; Y += y0 * SS
    if p["blush"] > 0:
        for s in (-1, 1):
            cxp = (e["cx_left_px"] if s < 0 else e["cx_right_px"]) + s * 0.25 * e["w_px"]
            overlay_ellipse(crop, X, Y, cxp * SS, (e["cy_px"] + 0.78 * e["h_px"]) * SS, 34 * SS, 16 * SS, (0.93, 0.55, 0.55), 0.55 * p["blush"])
    for side, cx in ((-1, e["cx_left_px"]), (1, e["cx_right_px"])):
        draw_eye(crop, X, Y, cx, e["cy_px"], p, side)
    draw_mouth(crop, X, Y, p)
    if p["tear"] > 0:
        overlay_ellipse(crop, X, Y, (e["cx_right_px"] + 0.2 * e["w_px"]) * SS, (e["cy_px"] + 0.75 * e["h_px"]) * SS, 9 * SS, 14 * SS, (0.45, 0.72, 0.92), p["tear"])
    out = Image.fromarray((np.clip(crop, 0, 1) * 255).astype(np.uint8)).resize((x1 - x0, y1 - y0), Image.LANCZOS)
    img = base.copy(); img.paste(out, (x0, y0))
    d = ImageDraw.Draw(img)
    if p["sweat"] > 0:
        sx, sy = e["cx_right_px"] + 0.95 * e["w_px"], e["cy_px"] - 0.55 * e["h_px"]
        d.ellipse([sx - 11, sy - 4, sx + 11, sy + 22], fill=(120, 190, 230)); d.polygon([(sx - 9, sy + 4), (sx + 9, sy + 4), (sx, sy - 16)], fill=(120, 190, 230))
    if p["zzz"] > 0:
        f = ImageFont.truetype(FONT, 46)
        for i, (dx, dy, s) in enumerate([(0, 0, 1), (42, -48, 0.8), (76, -90, 0.6)]):
            ff = ImageFont.truetype(FONT, int(46 * s))
            d.text((e["cx_right_px"] + 120 + dx, e["cy_px"] - 150 + dy), "z", fill=(70, 84, 104), font=ff)
    return img


def sheet():
    names = list(STATES)
    cw, ch = 400, 360
    out = Image.new("RGB", (4 * cw, 3 * (ch + 56)), (250, 242, 230)); d = ImageDraw.Draw(out)
    f = ImageFont.truetype(FONT, 34)
    for i, n in enumerate(names):
        img = render(params(**STATES[n])).crop((212, 150, 812, 690)).resize((cw, ch), Image.LANCZOS)
        r, c = divmod(i, 4)
        out.paste(img, (c * cw, r * (ch + 56)))
        d.text((c * cw + cw // 2, r * (ch + 56) + ch + 10), n, fill=(129, 79, 50), font=f, anchor="ma")
    out.save(os.path.join(HERE, "faces_sheet.png")); print("faces_sheet.png", out.size)


def demo_gif():
    """Vector-style life: idle blinks + glances, then blends through every state with a blink at each change."""
    fps = 30; frames = []
    def shot(p): frames.append(render(p).crop((262, 200, 762, 640)).resize((375, 330), Image.LANCZOS))
    cur = params()
    # idle: glance left, blink, glance right, double blink
    def hold(p, n):
        for _ in range(n): shot(p)
    def go(a, b, n):
        for i in range(n): shot(lerp(a, b, ease((i + 1) / n)))
        return b
    def blink(p):
        closed = dict(p); closed["sy"] = p["sy"] * 0.08
        go(p, closed, 3); go(closed, p, 4)
    hold(cur, 12)
    look_l = dict(cur, dx=-0.12, px=-0.8, sx=1.04); cur = go(cur, look_l, 6); hold(cur, 14)
    blink(cur); hold(cur, 6)
    look_r = dict(cur, dx=0.12, px=0.8, sx=1.04); cur = go(cur, look_r, 8); hold(cur, 14)
    cur = go(cur, params(), 6); blink(cur); hold(cur, 4); blink(cur); hold(cur, 10)
    for n in ["Happy", "Hungry", "Eating", "Tired", "Asleep", "Surprised", "Grumpy", "Sad", "Dirty", "Refusing", "Content"]:
        tgt = params(**STATES[n])
        squash = lerp(cur, tgt, 0.5); squash["sy"] *= 0.82; squash["sx"] *= 1.06   # Vector-style squash on the change
        go(cur, squash, 4); cur = go(squash, tgt, 6)
        hold(cur, 26 if n != "Asleep" else 34)
        if n not in ("Asleep",): blink(cur)
    frames[0].save(os.path.join(HERE, "faces_demo.gif"), save_all=True, append_images=frames[1:],
                   duration=int(1000 / fps), loop=0, optimize=True)
    print("faces_demo.gif", len(frames), "frames")


if __name__ == "__main__":
    sheet(); demo_gif()


# --------------------------------------------------------------------------- pupil decider
# Vector's eyes have no pupil: the eye SHAPE is the whole expression. Grub's cream pupil is his
# gaze, so it carries over only where where-he's-looking is part of the feeling. Where the shape
# says it all (crescents, bars, squeezes) the pupil is dropped and the dark eye reads like
# Vector's solid shape. Pick = the recommendation; the sheet shows both so Jesse can decide.
PUPIL_PICK = {
    "Content": True,      # his default look; the pupil is his "alive" spark
    "Happy": False,       # crescent ^^ is the expression (Vector's happy)
    "Hungry": True,       # looking up, pleading: gaze is the point
    "Tired": True,        # pupil sinks under the heavy lids
    "Asleep": False,      # closed bars
    "Dirty": False,       # squeezed "ugh" squint, shape-only
    "Sad": True,          # looking down
    "Eating": False,      # blissful crescent while chewing
    "Refusing": True,     # side-eye needs a pupil
    "Grumpy": True,       # glare at you
    "Surprised": True,    # small focused pupil = startled
    "Sick (S2)": False,   # dazed, unfocused
}


def decider_sheet():
    names = list(STATES)
    cw, ch, lab = 300, 270, 64
    cols = 3
    rows = math.ceil(len(names) / cols)
    out = Image.new("RGB", (cols * (2 * cw + 30) + 30, rows * (ch + lab + 24) + 20), (250, 242, 230))
    d = ImageDraw.Draw(out)
    f = ImageFont.truetype(FONT, 30); f2 = ImageFont.truetype(FONT, 20)
    for i, n in enumerate(names):
        r, c = divmod(i, cols)
        x0 = 30 + c * (2 * cw + 30); y0 = 20 + r * (ch + lab + 24)
        base = dict(STATES[n])
        for k, with_pupil in enumerate((True, False)):
            p = params(**base)
            if with_pupil and p["ps"] == 0: p["ps"] = 1.0
            if not with_pupil: p["ps"] = 0
            img = render(p).crop((262, 230, 762, 680)).resize((cw, ch), Image.LANCZOS)
            x = x0 + k * cw
            out.paste(img, (x, y0))
            pick = PUPIL_PICK[n] == with_pupil
            if pick: d.rectangle([x + 2, y0 + 2, x + cw - 3, y0 + ch - 3], outline=(94, 192, 181), width=6)
            d.text((x + cw // 2, y0 + ch - 34), "pupil" if with_pupil else "no pupil", fill=(255, 255, 255) if pick else (235, 235, 235), font=f2, anchor="ma",
                   stroke_width=2, stroke_fill=(60, 60, 60))
        d.text((x0 + cw, y0 + ch + 12), n, fill=(129, 79, 50), font=f, anchor="ma")
    out.save(os.path.join(HERE, "faces_pupil_decider.png")); print("faces_pupil_decider.png", out.size)
