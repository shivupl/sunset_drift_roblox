#!/usr/bin/env python3
"""The phone top bar's icons (src/client/TopBar.luau): GARAGE, RESET, VIEW,
STYLE and SETTINGS, white strokes on transparent for the game to tint, in
one sheet of 128 px cells, 5 across, in that order. Drawn from the
"Hajwala Menus" canvas's Driving board (2026-10-11); VIEW keeps the HUD's
own camera (art/hud/streetd/make.py "view"), as the owner asked ("keep
'view' icon as a regular camera"). Run:

    python3 make.py

Writes out/topbar_icons.png.
"""
import io
from pathlib import Path

import resvg_py
from PIL import Image

OUT = Path(__file__).parent / "out"
CELL = 128
ICON = 76  # the drawing's size inside its cell

# 24-unit drawings, stroke 2 (the canvas's), except VIEW (48 units).
STROKE = 'fill="none" stroke="#fff" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"'
ICONS = {
    # A car side on: the car menu.
    "garage": (24, f'<g {STROKE}><path d="M3.5 15.5v-3.2l2.1-4.1A2 2 0 0 1 7.4 7h9.2a2 2 0 0 1 1.8 1.2l2.1 4.1v3.2"/>'
                   '<path d="M3.5 15.5h17M4.5 12h15"/><circle cx="7" cy="16.5" r="1.9"/><circle cx="17" cy="16.5" r="1.9"/></g>'),
    "reset": (24, f'<g {STROKE}><path d="M4.5 12a7.5 7.5 0 1 0 2.2-5.3"/><path d="M4.5 4.5v3.5H8"/></g>'),
    # The HUD's camera, its lines thickened to the others' weight.
    "view": (48, '<g stroke="#fff" stroke-width="4" stroke-linejoin="round" fill="none">'
                 '<path d="M6 16 H15 L18.5 11 H29.5 L33 16 H42 V37 H6 Z"/><circle cx="24" cy="26" r="6.5"/></g>'
                 '<circle cx="36.5" cy="21" r="2.2" fill="#fff"/>'),
    # Two layers: the HUD's finish.
    "style": (24, f'<g {STROKE}><path d="M12 3.5l9 4.5-9 4.5-9-4.5z"/><path d="M3 12.5l9 4.5 9-4.5"/></g>'),
    # A cog: eight teeth round a ring.
    "settings": (24, '<g fill="none" stroke="#fff" stroke-width="2"><circle cx="12" cy="12" r="6.2"/><circle cx="12" cy="12" r="2.4"/></g>'
                     '<g stroke="#fff" stroke-width="3" stroke-linecap="butt">'
                     + "".join(f'<line x1="12" y1="5.6" x2="12" y2="2.6" transform="rotate({a} 12 12)"/>' for a in range(0, 360, 45))
                     + "</g>"),
}
ORDER = ["garage", "reset", "view", "style", "settings"]


def main():
    OUT.mkdir(exist_ok=True)
    parts = []
    for i, name in enumerate(ORDER):
        units, body = ICONS[name]
        k = ICON / units
        x0 = i * CELL + (CELL - ICON) / 2
        y0 = (CELL - ICON) / 2
        parts.append(f'<g transform="translate({x0:.2f} {y0:.2f}) scale({k:.4f})">{body}</g>')
    w, h = CELL * len(ORDER), CELL
    svg = f'<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{h}" viewBox="0 0 {w} {h}">{"".join(parts)}</svg>'
    png = bytes(resvg_py.svg_to_bytes(svg_string=svg))
    img = Image.open(io.BytesIO(png)).convert("RGBA")
    img.save(OUT / "topbar_icons.png", optimize=True)
    print("topbar_icons", img.size)


if __name__ == "__main__":
    main()
