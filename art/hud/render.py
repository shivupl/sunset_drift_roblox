#!/usr/bin/env python3
"""Renders the HUD art (art/hud/<variant>/*.svg) to transparent PNGs in
art/hud/out/<variant>_<name>.png with resvg, which draws SVG filters
(brushed metal, bevels, grain, glows) and fonts the same everywhere.

Setup, once: python3 -m pip install --target <dir> --only-binary=:all: resvg-py
then run with PYTHONPATH=<dir>. Fonts are TTFs in art/hud/fonts/ttf (Google
Fonts, OFL), so a render never reaches for the network.

Usage: PYTHONPATH=<dir> python3 art/hud/render.py [name-filter]

Headless Chrome was the first renderer: on this Mac it took 24 s a page and
hung when memory was short (2026-10-07), so resvg replaced it.

The PNGs are uploaded to Roblox from Studio (the MCP upload tool) and their
asset ids recorded in src/client/HudLab/Art.luau. Roblox caps an image at
1024 px a side, so every SVG is drawn at its final pixel size, at most 1024.
"""
import pathlib
import re
import sys

import resvg_py

ROOT = pathlib.Path(__file__).resolve().parent
OUT = ROOT / "out"
FONTS = ROOT / "fonts" / "ttf"


def render(svg: pathlib.Path) -> pathlib.Path:
    text = svg.read_text()
    m = re.search(r'<svg[^>]*\bwidth="(\d+)"[^>]*\bheight="(\d+)"', text)
    if not m:
        raise SystemExit(f"{svg}: no width/height on the svg tag")
    w, h = int(m.group(1)), int(m.group(2))
    if w > 1024 or h > 1024:
        raise SystemExit(f"{svg}: {w}x{h} is over Roblox's 1024 px")
    data = resvg_py.svg_to_bytes(
        svg_string=text,
        font_dirs=[str(FONTS)],
        skip_system_fonts=True,
        resources_dir=str(svg.parent),
    )
    png = OUT / f"{svg.parent.name}_{svg.stem}.png"
    png.write_bytes(bytes(data))
    return png


def main() -> None:
    OUT.mkdir(exist_ok=True)
    want = sys.argv[1] if len(sys.argv) > 1 else ""
    for svg in sorted(ROOT.glob("*/*.svg")):
        if svg.parent.name in ("out", "fonts") or want not in f"{svg.parent.name}_{svg.stem}":
            continue
        print(render(svg).relative_to(ROOT))


if __name__ == "__main__":
    main()
