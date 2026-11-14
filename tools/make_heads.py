#!/usr/bin/env python3
"""Azeroth Academy - make 256x256 head-and-chest crops from full-figure pose PNGs.

Usage: python3 tools/make_heads.py SOURCE_PNG_DIR [OUT_DIR] [--png]
  SOURCE_PNG_DIR  folder with fizzwick_<pose>.png / sprocket_<state>.png (512x512, transparent)
  OUT_DIR         default Media/Art; writes <name>_head.tga (32-bit, uncompressed, alpha)
  --png           also write <name>_head.png previews

Fizzwick: finds the face as the widest olive-green skin blob in the top half of the figure
(the ears make the head wider than a raised hand), then crops a 250px square from just above
the hair/goggles down to the chest, centered on the face. Sprocket: the top of the figure.
Out-of-image areas stay transparent. Needs Pillow and numpy.
"""
import os, sys
from collections import deque
import numpy as np
from PIL import Image

SIDE = 250  # source pixels per crop (about 1:1 with the 256 output)

def components(mask):
    h, w = mask.shape
    lab = np.zeros((h, w), dtype=np.int32)
    comps, n = [], 0
    for y, x in zip(*np.nonzero(mask)):
        if lab[y, x]:
            continue
        n += 1
        q = deque([(y, x)]); lab[y, x] = n; pts = []
        while q:
            cy, cx = q.popleft(); pts.append((cy, cx))
            for ny, nx in ((cy + 1, cx), (cy - 1, cx), (cy, cx + 1), (cy, cx - 1)):
                if 0 <= ny < h and 0 <= nx < w and mask[ny, nx] and not lab[ny, nx]:
                    lab[ny, nx] = n; q.append((ny, nx))
        comps.append(np.array(pts))
    return comps

def head_box(im, name):
    a = np.asarray(im).astype(int)
    al = a[..., 3]
    ys, xs = np.nonzero(al > 40)
    top, bot = ys.min(), ys.max()
    size = im.size[0]
    if name.startswith("fizzwick"):
        hsv = np.asarray(im.convert("RGB").convert("HSV")).astype(int)
        hue = hsv[..., 0] * 360 / 255
        skin = (al > 200) & (hue >= 52) & (hue <= 110) & (hsv[..., 1] > 70) & (hsv[..., 2] > 50)
        skin[int(top + (bot - top) * 0.45):, :] = False
        comps = [c for c in components(skin) if len(c) > 150]
        if comps:
            head = max(comps, key=lambda c: c[:, 1].max() - c[:, 1].min())
            cx, htop = head[:, 1].mean(), head[:, 0].min()
            y0 = int(min(htop - 0.16 * SIDE, size - SIDE))
            x0 = int(max(0, min(cx - SIDE / 2, size - SIDE)))
            # keep hair tips: if the figure reaches above the box near the face, lift it (max 25px)
            cols = al[:, max(0, int(cx - 45)):int(cx + 45)] > 40
            rows = np.nonzero(cols.any(axis=1))[0]
            if len(rows) and rows[0] < y0 + 4:
                y0 = int(max(y0 - 25, rows[0] - 6))
            return (x0, y0, x0 + SIDE, y0 + SIDE)
    band = np.nonzero(al[top:top + 120, :] > 40)[1]
    cx = band.mean() if len(band) else size / 2
    y0 = int(max(0, top - 10))
    x0 = int(max(0, min(cx - SIDE / 2, size - SIDE)))
    return (x0, y0, x0 + SIDE, y0 + SIDE)

def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    if not args:
        print(__doc__); sys.exit(1)
    src = args[0]
    out = args[1] if len(args) > 1 else "Media/Art"
    os.makedirs(out, exist_ok=True)
    for f in sorted(os.listdir(src)):
        if not f.endswith(".png") or not (f.startswith("fizzwick_") or f.startswith("sprocket_")) or f.endswith("_head.png"):
            continue
        name = f[:-4]
        im = Image.open(os.path.join(src, f)).convert("RGBA")
        box = head_box(im, name)
        crop = im.crop(box).resize((256, 256), Image.LANCZOS)
        crop.save(os.path.join(out, name + "_head.tga"), compression=None)
        if "--png" in sys.argv:
            crop.save(os.path.join(out, name + "_head.png"))
        print(name + "_head", box)

if __name__ == "__main__":
    main()
