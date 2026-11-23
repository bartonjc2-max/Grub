#!/usr/bin/env python3
"""iOS app icon candidates for Grub from a live gameplay capture + the 3D canon (Gemini 2.5 flash image).
Usage: gen_icons.py <gameplay.png>   -> icon_v1..v5.png beside this script, prompts in prompts_icon.txt"""
import base64, json, os, sys, time, urllib.request
from pathlib import Path
from concurrent.futures import ThreadPoolExecutor
HERE = Path(__file__).resolve().parent
env = {}
for ln in open(os.path.expanduser("~/Documents/Code/art-judge/.env")):
    ln = ln.strip()
    if ln and not ln.startswith("#") and "=" in ln:
        k, v = ln.split("=", 1); env[k] = v.strip()
URL = ("https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash-image"
       f":generateContent?key={env['GEMINI_API_KEY']}")
shot = Path(sys.argv[1]); canon = HERE.parent.parent / "docs/canon/2026-11-19-grub-3d.png"

BASE = ("Design an iOS app icon for this virtual pet game. Image 1 is a real gameplay screenshot; image 2 is the "
        "character canon. Keep the character's design EXACTLY as in the canon: same body shape, colours, face and "
        "proportions. Match the game's soft 3D clay render look, warm palette and lighting from the screenshot. "
        "Square, full bleed to all four edges, NO rounded corners, NO border, NO text or letters, NO UI, no phone frame. "
        "One bold, simple, centred composition that still reads at 60x60 pixels: big character, clean silhouette, "
        "uncluttered background. Scene: ")
SCENES = [
    "a close-up of his face and upper body filling most of the icon, big happy eyes looking straight at the viewer, "
    "softly blurred cosy living-room colours behind him.",
    "him sitting contentedly on the cushion of the game's couch, small and cute, the couch shape simple and readable.",
    "him mid-hop, delighted, with the game's small ball bouncing beside him, a warm plain background.",
    "him holding a clay food bowl, cheeks puffed and happy, the bowl matching the game's clay icon style.",
    "him asleep, curled up and peaceful, a small soft 'z' shape floating above (a shape, not a letter), cosy "
    "evening tones.",
]
imgs = [base64.b64encode(p.read_bytes()).decode() for p in (shot, canon)]

def run(i):
    body = json.dumps({"contents": [{"parts": [{"text": BASE + SCENES[i - 1]}] +
                       [{"inline_data": {"mime_type": "image/png", "data": d}} for d in imgs]}],
                       "generationConfig": {"responseModalities": ["IMAGE"], "imageConfig": {"aspectRatio": "1:1"}}}).encode()
    for a in range(3):
        try:
            req = urllib.request.Request(URL, data=body, headers={"Content-Type": "application/json"})
            with urllib.request.urlopen(req, timeout=180) as r:
                resp = json.loads(r.read())
            for p in resp["candidates"][0]["content"]["parts"]:
                if "inlineData" in p:
                    out = HERE / f"icon_v{i}.png"
                    out.write_bytes(base64.b64decode(p["inlineData"]["data"]))
                    return f"v{i} ok {out.stat().st_size}"
            raise RuntimeError("no image")
        except Exception as e:
            print(f"v{i} attempt {a+1}: {e}", file=sys.stderr); time.sleep(5)
    return f"v{i} FAILED"

with ThreadPoolExecutor(5) as ex:
    for r in ex.map(run, range(1, 6)): print(r)
(HERE / "prompts_icon.txt").write_text("\n\n".join(f"v{i+1}: {BASE}{s}" for i, s in enumerate(SCENES)) + "\n")
