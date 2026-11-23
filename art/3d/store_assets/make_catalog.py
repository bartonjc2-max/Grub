#!/usr/bin/env python3
"""catalog.json + contact_sheet.png + contact_sheet_batch2.png from what the build scripts wrote (run after them).
For every <category>/<id>/ it reads meta.json and mask.png, measures the mask's bounding box in plate pixels
(top-left origin, alpha > 8/255) and its coverage, and crops render.png to that box (+ margin) for the sheets.
Batch 1 entries keep their original keys (plus "game", the PicR-slot files once render_picr.py has made them, and
the game rug layer once make_rug_layer.py has); batch 2 entries (meta.json has "batch": 2) also carry "batch",
"plate_margin_px" (smallest gap between the mask bbox and a plate edge), the per-category extras from
meta.json, and for pictures the PicR-slot files and bbox.
  contact_sheet.png         every variant, grouped by category, batch 2 marked NEW
  contact_sheet_batch2.png  batch 2 only, larger crops, plus a row of the pictures at the PicR slot
python3 make_catalog.py
"""
import json, os
import numpy as np
from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
CATS = ["rugs", "pictures", "plants", "couches", "extras"]
PAD, LABEL, HEAD = 24, 58, 64
BG, INK, SUB = (247, 238, 221), (92, 66, 52), (150, 120, 100)
NEW_FILL, NEW_LINE = (226, 122, 96), (226, 122, 96)
BASE_KEYS = {"id", "category", "name", "description", "replaces", "objects", "world_bbox_min", "world_bbox_max",
             "plate_size", "render_seconds", "mask_seconds"}

def font(size, bold=False):
    for p, idx in (("/System/Library/Fonts/Helvetica.ttc", 1 if bold else 0), ("/System/Library/Fonts/Supplemental/Arial.ttf", 0)):
        try: return ImageFont.truetype(p, size, index=idx)
        except Exception: pass
    return ImageFont.load_default()

def mask_box(path):
    a = np.asarray(Image.open(path).convert("RGBA"))[..., 3]
    ys, xs = np.nonzero(a > 8)
    if not len(xs): return None, a
    return (int(xs.min()), int(ys.min()), int(xs.max()) + 1, int(ys.max()) + 1), a

def crop_of(render_path, box, cell):
    x0, y0, x1, y1 = box
    im = Image.open(render_path).convert("RGB")
    m = int(0.08 * max(x1 - x0, y1 - y0)) + 6
    crop = im.crop((max(0, x0 - m), max(0, y0 - m), min(im.width, x1 + m), min(im.height, y1 + m)))
    k = min((cell - 2 * PAD) / crop.width, (cell - 2 * PAD) / crop.height, 2.0 * cell / 400)   # fit the cell
    return crop.resize((max(1, round(crop.width * k)), max(1, round(crop.height * k))), Image.LANCZOS)

catalog, items = [], {c: [] for c in CATS}
for cat in CATS:
    d = os.path.join(HERE, cat)
    if not os.path.isdir(d): continue
    found = []
    for vid in sorted(os.listdir(d)):
        mp = os.path.join(d, vid, "meta.json")
        if os.path.exists(mp): found.append((json.load(open(mp)).get("batch", 1), vid))
    for batch, vid in sorted(found):                                   # batch 1 first, then batch 2, each by id
        meta = json.load(open(os.path.join(d, vid, "meta.json")))
        box, a = mask_box(os.path.join(d, vid, "mask.png"))
        if box is None: print("EMPTY MASK", vid); continue
        x0, y0, x1, y1 = box
        entry = {"id": vid, "category": cat, "name": meta["name"], "description": meta["description"],
                 "replaces": meta["replaces"],
                 "files": {k: f"{cat}/{vid}/{f}" for k, f in (("render", "render.png"), ("mask", "mask.png"), ("blend", vid + ".blend"))},
                 "bbox": {"x": x0, "y": y0, "w": x1 - x0, "h": y1 - y0},
                 "plate_size": list(a.shape[::-1]), "mask_coverage_px": int((a > 127).sum()),
                 "objects": meta["objects"], "world_bbox_min": meta["world_bbox_min"], "world_bbox_max": meta["world_bbox_max"]}
        boxR = None
        if batch != 1:
            entry["batch"] = batch
            entry["plate_margin_px"] = int(min(x0, y0, a.shape[1] - x1, a.shape[0] - y1))
            for k, v in meta.items():
                if k not in BASE_KEYS and k != "batch": entry[k] = v
        if "game" in meta: entry["game"] = meta["game"]              # measure_items.py: the facts the game reads
        if os.path.exists(os.path.join(d, vid, "mask_picR.png")):     # batch 2 pictures, and batch 1 via render_picr.py
            boxR, aR = mask_box(os.path.join(d, vid, "mask_picR.png"))
            entry["files"]["render_picR"] = f"{cat}/{vid}/render_picR.png"; entry["files"]["mask_picR"] = f"{cat}/{vid}/mask_picR.png"
            entry["bbox_picR"] = {"x": boxR[0], "y": boxR[1], "w": boxR[2] - boxR[0], "h": boxR[3] - boxR[1]}
            entry["mask_coverage_px_picR"] = int((aR > 127).sum())
            if batch == 1 and "picR" in meta: entry["picR"] = meta["picR"]
        if os.path.exists(os.path.join(d, vid, "game", "room_rug.png")):      # make_rug_layer.py
            entry["files"]["game_rug"] = f"{cat}/{vid}/game/room_rug.png"; entry["files"]["game_item"] = f"{cat}/{vid}/game/item.json"
        catalog.append(entry)
        items[cat].append((entry, box, boxR))
        print(f"{vid:26s} b{batch} bbox {x0},{y0} {x1 - x0}x{y1 - y0}  coverage {entry['mask_coverage_px']} px")

json.dump({"plate_size": catalog[0]["plate_size"] if catalog else None,
           "bbox_note": "plate pixels, origin top-left, from mask.png alpha > 8/255",
           "variants": catalog}, open(os.path.join(HERE, "catalog.json"), "w"), indent=1)

def sheet(path, rows, cell, cols, title):
    """rows: [(heading, [(entry, crop, is_new), ...]), ...]; long rows wrap at cols."""
    lines = sum((len(c) + cols - 1) // cols for _, c in rows)
    Wd = cols * cell + 2 * PAD; Ht = PAD + 70 + len(rows) * HEAD + lines * (cell + LABEL) + PAD
    im = Image.new("RGB", (Wd, Ht), BG); dr = ImageDraw.Draw(im)
    dr.text((PAD + 8, PAD), title, fill=INK, font=font(34, True))
    y = PAD + 70
    for head, cells in rows:
        dr.text((PAD + 8, y + 14), head, fill=INK, font=font(30, True)); y += HEAD
        for k, (e, crop, new) in enumerate(cells):
            x = PAD + (k % cols) * cell
            dr.rounded_rectangle((x + 8, y + 8, x + cell - 8, y + cell - 8), 18, fill=(255, 250, 240),
                                 outline=NEW_LINE if new else (226, 210, 188), width=4 if new else 2)
            im.paste(crop, (x + (cell - crop.width) // 2, y + (cell - crop.height) // 2))
            if new:
                dr.rounded_rectangle((x + cell - 96, y + 18, x + cell - 18, y + 52), 12, fill=NEW_FILL)
                dr.text((x + cell - 86, y + 22), "NEW", fill=(255, 255, 255), font=font(24, True))
            dr.text((x + 14, y + cell + 2), e["name"], fill=INK, font=font(24, True))
            dr.text((x + 14, y + cell + 30), e["id"] + ("   (batch 2)" if new else ""), fill=SUB, font=font(18))
            if k % cols == cols - 1 and k != len(cells) - 1: y += cell + LABEL
        y += cell + LABEL
    im.save(path)
    print(os.path.basename(path), im.size, os.path.getsize(path), "bytes")

def head(cat):
    r = items[cat][0][0]["replaces"]
    return f"{cat.upper()}   ({'replaces: ' + r if r else 'new category: stands on free floor, replaces nothing'})"

def rpath(e, key="render"): return os.path.join(HERE, e["files"][key])

# every variant
rows = [(head(c), [(e, crop_of(rpath(e), box, 400), e.get("batch", 1) != 1) for e, box, _ in items[c]]) for c in CATS if items[c]]
sheet(os.path.join(HERE, "contact_sheet.png"), rows, 400, 5, f"Grub store assets: all {len(catalog)} variants (orange outline + NEW = batch 2)")

# batch 2 only, larger
rows2 = []
for c in CATS:
    new = [(e, box, boxR) for e, box, boxR in items[c] if e.get("batch", 1) != 1]
    if not new: continue
    rows2.append((head(c), [(e, crop_of(rpath(e), box, 600), True) for e, box, _ in new]))
    if any(bR for _, _, bR in new):
        rows2.append((f"{c.upper()}   (the same pictures at the picR slot: render_picR.png)",
                      [(e, crop_of(rpath(e, "render_picR"), bR, 600), True) for e, _, bR in new if bR]))
if rows2:
    sheet(os.path.join(HERE, "contact_sheet_batch2.png"), rows2, 600, 5, f"Grub store assets: batch 2 ({sum(len(c) for h, c in rows2 if 'picR slot' not in h)} new variants)")
print("catalog.json:", len(catalog), "variants")
