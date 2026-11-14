#!/usr/bin/env python3
"""Azeroth Academy - make Sprocket readable on the dark Guide strip (v1.2.1).

Usage: python3 tools/sprocket_pop.py [ART_DIR] [--preview OUT.png] [--force]

Sprocket is dark bronze; on the strip's dark brown background his head crops vanished.
For each sprocket_<state>_head.tga this lifts the shadows (gamma), adds a little contrast and
saturation, and paints a thin warm rim light along the inside of his silhouette. His design,
shape and colors stay the same. It also writes sprocket_glow.tga, the soft warm backplate the
strip draws behind him (128x128, alpha gradient).

Processed files carry the TGA id "AA-pop1", so running the tool again does nothing unless
--force (convert_art.sh runs it after making fresh head crops). Needs Pillow and numpy.
--preview writes a before/after picture on the strip's real background color.
"""
import os, sys
import numpy as np
from PIL import Image, ImageFilter

TAG = b"AA-pop1"
STATES = ("curious", "squawk")
# UI/Guide.lua strip: backdrop (0.10, 0.07, 0.03) at alpha 0.92 over the dark hub frame
STRIP_BG = (26, 19, 9)
GLOW_ALPHA = 0.7  # must match GU.PARROT_GLOW_ALPHA in UI/Guide.lua

def read_tga(path):
    with open(path, "rb") as fh:
        data = fh.read()
    idlen = data[0]
    w, h = data[12] | data[13] << 8, data[14] | data[15] << 8
    ident = data[18:18 + idlen]
    px = np.frombuffer(data, np.uint8, w * h * 4, 18 + idlen).reshape(h, w, 4)
    if not (data[17] & 0x20):  # bottom-left origin: flip to top-down
        px = px[::-1]
    rgba = px[..., [2, 1, 0, 3]].copy()  # BGRA -> RGBA
    return rgba, ident

def write_tga(path, rgba, ident=TAG):
    h, w = rgba.shape[:2]
    head = bytes([len(ident), 0, 2, 0, 0, 0, 0, 0, 0, 0, 0, 0, w & 255, w >> 8, h & 255, h >> 8, 32, 8])
    body = rgba[::-1][..., [2, 1, 0, 3]].astype(np.uint8).tobytes()  # bottom-left origin, BGRA
    with open(path, "wb") as fh:
        fh.write(head + ident + body)

def pop(rgba):
    rgb = rgba[..., :3].astype(float) / 255
    a = rgba[..., 3].astype(float) / 255
    rgb = rgb ** 0.62                                   # lift the dark bronze
    rgb = np.clip((rgb - 0.5) * 1.12 + 0.52, 0, 1)      # a little contrast and brightness
    luma = rgb @ np.array([0.299, 0.587, 0.114])
    rgb = np.clip(luma[..., None] + (rgb - luma[..., None]) * 1.12, 0, 1)  # +12% saturation
    # rim light: the inner edge band of the silhouette, softened
    mask = Image.fromarray((a * 255).astype(np.uint8))
    inner = np.asarray(mask.filter(ImageFilter.MinFilter(7))).astype(float) / 255
    rim = np.clip(a - inner, 0, 1)
    rim = np.asarray(Image.fromarray((rim * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(1.6))).astype(float) / 255
    rim = rim * a
    warm = np.array([1.0, 0.86, 0.58])
    rgb = rgb + (warm - rgb) * (rim[..., None] * 0.55)
    out = np.dstack([np.clip(rgb * 255 + 0.5, 0, 255), rgba[..., 3]]).astype(np.uint8)
    return out

def glow(size=128):
    y, x = np.mgrid[0:size, 0:size]
    r = np.hypot(x - (size - 1) / 2, y - (size - 1) / 2) / (size / 2)
    t = np.clip(1 - r, 0, 1)
    alpha = (t ** 1.2) * 0.95                     # soft disc, brightest in the middle
    alpha = alpha * (1 - np.clip((r - 0.96) / 0.04, 0, 1))
    col = np.zeros((size, size, 4))
    col[..., 0], col[..., 1], col[..., 2] = 255, 214, 140  # warm candle light
    col[..., 3] = alpha * 255
    return col.astype(np.uint8)

def composite(rgba, bg, glow_rgba=None, glow_alpha=1.0, alpha=1.0):
    h, w = rgba.shape[:2]
    out = np.zeros((h, w, 3)) + np.array(bg, float)
    if glow_rgba is not None:
        g = np.asarray(Image.fromarray(glow_rgba).resize((w, h), Image.BILINEAR)).astype(float)
        ga = g[..., 3:] / 255 * glow_alpha
        out = out * (1 - ga) + g[..., :3] * ga
    fa = rgba[..., 3:].astype(float) / 255 * alpha
    out = out * (1 - fa) + rgba[..., :3] * fa
    return out.astype(np.uint8)

def main():
    args = [x for x in sys.argv[1:] if not x.startswith("--")]
    force = "--force" in sys.argv
    preview = sys.argv[sys.argv.index("--preview") + 1] if "--preview" in sys.argv else None
    if preview in args: args.remove(preview)
    art = args[0] if args else os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "Media", "Art")
    gl = glow()
    write_tga(os.path.join(art, "sprocket_glow.tga"), gl, b"AA-glow1")
    before, after = [], []
    for st in STATES:
        path = os.path.join(art, "sprocket_%s_head.tga" % st)
        if not os.path.exists(path):
            continue
        rgba, ident = read_tga(path)
        if ident == TAG and not force:
            print("already processed:", os.path.basename(path)); after.append(rgba); continue
        new = pop(rgba)
        write_tga(path, new)
        before.append(rgba); after.append(new)
        print("brightened", os.path.basename(path))
    if preview and before:
        # in-game size is 56 px on the strip; show 2x (112 px) and 1x on the strip color
        tiles = []
        for b, a in zip(before, after):
            row = [composite(b, STRIP_BG, alpha=0.45), composite(b, STRIP_BG, alpha=0.9),
                   composite(a, STRIP_BG, gl, GLOW_ALPHA, 1.0), composite(a, STRIP_BG, gl, GLOW_ALPHA * 0.8, 0.85)]
            tiles.append(np.hstack([np.asarray(Image.fromarray(t).resize((112, 112), Image.LANCZOS)) for t in row]))
        img = np.vstack(tiles)
        pad = np.zeros((img.shape[0] + 40, img.shape[1] + 20, 3), np.uint8) + np.array(STRIP_BG, np.uint8)
        pad[30:30 + img.shape[0], 10:10 + img.shape[1]] = img
        im = Image.fromarray(pad)
        from PIL import ImageDraw
        d = ImageDraw.Draw(im)
        for i, label in enumerate(["before 45%", "before 90%", "after", "after 85%"]):
            d.text((14 + i * 112, 8), label, fill=(255, 210, 0))
        big = im.resize((im.width * 2, im.height * 2), Image.NEAREST)
        # real size: the right end of the strip (parrot 56 px on a 64 px glow), before and after
        strip = Image.new("RGB", (big.width, 110), STRIP_BG)
        sd = ImageDraw.Draw(strip)
        for i, (b, a) in enumerate(zip(before, after)):
            x0 = 40 + i * 440
            sd.text((x0, 6), "actual size: " + STATES[i] + " before / after", fill=(255, 210, 0))
            pb = Image.fromarray(composite(b, STRIP_BG, alpha=0.45)).resize((56, 56), Image.LANCZOS)
            strip.paste(pb, (x0 + 40, 34))
            g = np.asarray(Image.fromarray(gl).resize((64, 64), Image.BILINEAR)).astype(float)
            bgpatch = np.zeros((64, 64, 3)) + np.array(STRIP_BG, float)
            ga = g[..., 3:] / 255 * GLOW_ALPHA
            bgpatch = (bgpatch * (1 - ga) + g[..., :3] * ga)
            fa_img = np.asarray(Image.fromarray(a).resize((56, 56), Image.LANCZOS)).astype(float)
            fa = fa_img[..., 3:] / 255
            bgpatch[4:60, 4:60] = bgpatch[4:60, 4:60] * (1 - fa) + fa_img[..., :3] * fa
            strip.paste(Image.fromarray(bgpatch.astype(np.uint8)), (x0 + 200, 30))
        canvas = Image.new("RGB", (big.width, big.height + strip.height), STRIP_BG)
        canvas.paste(big, (0, 0)); canvas.paste(strip, (0, big.height))
        canvas.save(preview)
        print("preview ->", preview)

if __name__ == "__main__":
    main()
