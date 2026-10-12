#!/usr/bin/env python3
"""The garage panel's icons (src/client/Garage/Looks): the seven
categories, then the layout switch, white strokes on transparent for the
game to tint, one sheet of 128 px cells, 8 across, in this order:
MY CARS, PAINT, WHEELS, PLATES, LIGHTS, SUN STRIPS, EXHAUST, LAYOUT.
Drawn from the "Hajwala Menus" canvas (B. Garage's dock, 2026-10-11), in
the phone top bar's line weight (art/topbar). Run:

    PYTHONPATH=<resvg-py dir> python3 make.py

Writes out/garage_icons.png.
"""
import io
from pathlib import Path

import resvg_py
from PIL import Image

OUT = Path(__file__).parent / "out"
CELL = 128
ICON = 76

S = 'fill="none" stroke="#fff" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"'
ICONS = {
    # A key: your cars.
    "cars": f'<g {S}><circle cx="8" cy="12" r="3.5"/><path d="M11.5 12H21M17.5 12v3M20.5 12v2.5"/></g>',
    # A drop of paint.
    "paint": f'<g {S}><path d="M12 3.5c3.5 4.2 5.5 7.3 5.5 10a5.5 5.5 0 0 1-11 0c0-2.7 2-5.8 5.5-10z"/></g>',
    # A wheel: rim, hub, spokes.
    "rims": f'<g {S}><circle cx="12" cy="12" r="8.5"/><circle cx="12" cy="12" r="2.5"/><path d="M12 3.5v6M12 14.5v6M3.5 12h6M14.5 12h6"/></g>',
    # A number plate.
    "plates": f'<g {S}><rect x="2.5" y="6.5" width="19" height="11" rx="2"/><path d="M17 6.5v11M5.5 10.5h8M5.5 13.5h5.5"/></g>',
    # A headlight and its beam.
    "lights": f'<g {S}><path d="M10 6.5H8a5.5 5.5 0 0 0 0 11h2z"/><path d="M14 8.5l7-1.5M14 12h7M14 15.5l7 1.5"/></g>',
    # A windscreen with the strip across its top.
    "decal": f'<g {S}><path d="M4 18l2.5-11h11L20 18z"/></g><path d="M5.6 10.3h12.8" stroke="#fff" stroke-width="3.2" stroke-linecap="round"/>',
    # A tailpipe and its puffs.
    "exhaust": f'<g {S}><path d="M3 9.5h9a2 2 0 0 1 0 4H3"/><path d="M16.5 11.5h1.5M20 8.5l1.5-1M20 14.5l1.5 1"/></g>',
    # Three panels: the layouts the button cycles.
    "layout": f'<g {S}><rect x="3.5" y="4.5" width="7" height="15" rx="1.5"/><rect x="13.5" y="4.5" width="7" height="6.5" rx="1.5"/><rect x="13.5" y="13" width="7" height="6.5" rx="1.5"/></g>',
}
ORDER = ["cars", "paint", "rims", "plates", "lights", "decal", "exhaust", "layout"]


def main():
    OUT.mkdir(exist_ok=True)
    parts = []
    for i, name in enumerate(ORDER):
        k = ICON / 24
        x0 = i * CELL + (CELL - ICON) / 2
        y0 = (CELL - ICON) / 2
        parts.append(f'<g transform="translate({x0:.2f} {y0:.2f}) scale({k:.4f})">{ICONS[name]}</g>')
    w, h = CELL * len(ORDER), CELL
    svg = f'<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{h}" viewBox="0 0 {w} {h}">{"".join(parts)}</svg>'
    img = Image.open(io.BytesIO(bytes(resvg_py.svg_to_bytes(svg_string=svg)))).convert("RGBA")
    img.save(OUT / "garage_icons.png", optimize=True)
    print("garage_icons", img.size)


if __name__ == "__main__":
    main()
