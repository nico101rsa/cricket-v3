#!/usr/bin/env python3
"""Derive the 16 runtime portraits (bucket x form band) from the design drop.

Source tiles: docs/design-drop/portraits/clean/face-<expr>.png (light skin).
WHITE = source untouched. Other buckets: skin pixels (warm hue mask) are
scaled per-channel toward the bucket's target mean tone (the appearance
picker's placeholder tints), preserving the cartoon shading.
Stopgap per spec DP4 -- replaced when design answers the tones brief.
Run from the repo root:  python3 tools/gen_portraits.py
"""
import colorsys
import pathlib

from PIL import Image

SRC = pathlib.Path("docs/design-drop/portraits/clean")
OUT = pathlib.Path("assets/portraits")
GRID = pathlib.Path("docs/mockups/portraits-grid-v1.png")

# DP2 -- form band -> design expression. steady = confident (not neutral): the
# neutral tile is framed tighter than the rest (source-art quirk, flagged in the
# design brief) and would make the portrait "jump" on every form change.
BAND_EXPR = {"hot": "happy", "steady": "confident", "tired": "disappointed", "cold": "angry"}
# DP4 -- target mean skin tone per bucket (appearance_picker.placeholder_tint)
WHITE_MEAN = (0.95, 0.86, 0.76)  # design's light skin ~= the WHITE tint
BUCKET_MEAN = {
    "white": None,  # untouched
    "mixed": (0.78, 0.62, 0.48),
    "indian": (0.62, 0.45, 0.33),
    "black": (0.36, 0.24, 0.18),
}

def is_skin(r, g, b):
    h, s, v = colorsys.rgb_to_hsv(r / 255, g / 255, b / 255)
    deg = h * 360
    # warm skin hues; excludes green cap, white shirt (low sat), navy bg, gold roundel (>=42deg)
    return 8 <= deg <= 42 and s >= 0.22 and v >= 0.25

def remap(im, mean):
    ratio = tuple(mean[i] / WHITE_MEAN[i] for i in range(3))
    px = im.load()
    for y in range(im.height):
        for x in range(im.width):
            r, g, b, a = px[x, y]
            if is_skin(r, g, b):
                px[x, y] = (
                    min(255, round(r * ratio[0])),
                    min(255, round(g * ratio[1])),
                    min(255, round(b * ratio[2])),
                    a,
                )
    return im

def main():
    OUT.mkdir(parents=True, exist_ok=True)
    tiles = {}
    for bucket, mean in BUCKET_MEAN.items():
        for band, expr in BAND_EXPR.items():
            im = Image.open(SRC / f"face-{expr}.png").convert("RGBA")
            if mean is not None:
                im = remap(im, mean)
            dest = OUT / f"{bucket}-{band}.png"
            im.save(dest)
            tiles[(bucket, band)] = im
            print("wrote", dest)
    # contact sheet: rows = buckets, cols = bands
    w, h = tiles[("white", "hot")].size
    sheet = Image.new("RGBA", (w * 4, h * 4))
    for r, bucket in enumerate(BUCKET_MEAN):
        for c, band in enumerate(BAND_EXPR):
            sheet.paste(tiles[(bucket, band)], (c * w, r * h))
    GRID.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(GRID)
    print("wrote", GRID)

if __name__ == "__main__":
    main()
