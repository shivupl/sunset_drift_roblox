#!/usr/bin/env python3
"""The cash's price tag (the owner, 2026-10-14, of the canvas's J7 "Price
tag: a sodium plate with the cut corner, dark ink": "uniformly implement
this one throughout the ui"): a white 9-slice plate, 300x120, its three
corners rounded (30) and its bottom-right corner cut (34), for the HUD to
tint sodium with a gradient. Pillow only (no kit, no resvg). Run:

    python3 tag.py

Writes ../out/hud_tag.png.
"""
from pathlib import Path

from PIL import Image, ImageDraw

OUT = Path(__file__).parent.parent / "out"
W, H, R, CUT, SS = 300, 120, 30, 34, 4


def main():
    w, h, r, cut = W * SS, H * SS, R * SS, CUT * SS
    im = Image.new("L", (w, h), 0)
    d = ImageDraw.Draw(im)
    # The rounded body, then the bottom-right corner cut off.
    d.rounded_rectangle((0, 0, w - 1, h - 1), radius=r, fill=255)
    d.polygon([(w, h - cut), (w, h), (w - cut, h)], fill=0)
    # The cut square's corner: the rounded corner there is replaced by the cut, so square it first.
    d.rectangle((w - r, h - r, w, h), fill=255)
    d.polygon([(w, h - cut), (w, h), (w - cut, h)], fill=0)
    a = im.resize((W, H), Image.LANCZOS)
    rgba = Image.new("RGBA", (W, H), (255, 255, 255, 0))
    rgba.putalpha(a)
    OUT.mkdir(exist_ok=True)
    rgba.save(OUT / "hud_tag.png", optimize=True)
    print("hud_tag", rgba.size)


if __name__ == "__main__":
    main()
