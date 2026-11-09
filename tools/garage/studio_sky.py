"""The garage's studio sky: six skybox faces the customisation view swaps in,
so car paint and the glossy floor reflect softboxes instead of the sunset.

Roblox's Reflectance shows the Sky's skybox, not the room, so indoors a
shiny car showed sunset clouds (2026-11-09: gloss at 0.3 on the turntable was
a pink car). A dark box with white softbox panels gives the streaks a
photo studio puts on a car. Nothing branded, no photos: drawn here.

Pure Python (no PIL on this machine): python3 tools/garage/studio_sky.py
writes tools/garage/out/studio_<look>_<face>.png. Upload with the Studio MCP's
upload_image from an http://localhost URL and put the ids in
GarageThemes.skies.
"""
import math
import os
import struct
import sys
import zlib

SIZE = 512
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "out")


def write_png(path, rows):
    def chunk(kind, data):
        return struct.pack(">I", len(data)) + kind + data + struct.pack(">I", zlib.crc32(kind + data) & 0xFFFFFFFF)

    h = len(rows)
    w = len(rows[0]) // 3
    raw = b"".join(b"\x00" + bytes(r) for r in rows)
    with open(path, "wb") as fh:
        fh.write(b"\x89PNG\r\n\x1a\n")
        fh.write(chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 2, 0, 0, 0)))
        fh.write(chunk(b"IDAT", zlib.compress(raw, 9)))
        fh.write(chunk(b"IEND", b""))


def smooth(edge0, edge1, x):
    t = min(1.0, max(0.0, (x - edge0) / (edge1 - edge0)))
    return t * t * (3 - 2 * t)


def box(u, v, cu, cv, hw, hh, soft):
    """1 inside a rectangle centred (cu, cv), half size (hw, hh), soft edge."""
    du = abs(u - cu) - hw
    dv = abs(v - cv) - hh
    d = max(du, dv)
    return 1 - smooth(-soft, soft, d)


# Each look: background (bottom, top) luminance 0..1, the panels per face,
# and a tint. A panel is (cu, cv, half width, half height, soft, level).
LOOKS = {
    # Dark studio: graphite box, two tall strip boxes on every wall, a big
    # softbox overhead. For dark rooms (the Studio and Workshop themes).
    "dark": {
        "bg": (0.035, 0.085),
        "tint": (0.97, 0.99, 1.0),
        # The two strip boxes, and a dim horizon band: the line a studio's
        # floor edge draws along a car's doors.
        "side": [(-0.52, 0.32, 0.09, 0.5, 0.035, 0.95), (0.52, 0.32, 0.09, 0.5, 0.035, 0.95), (0, -0.04, 1.2, 0.012, 0.02, 0.32)],
        "up": [(0, 0, 0.55, 0.34, 0.05, 1.0), (-0.84, 0, 0.05, 0.75, 0.03, 0.7), (0.84, 0, 0.05, 0.75, 0.03, 0.7)],
        "dn": [(0, 0, 0.6, 0.6, 0.4, 0.04)],
    },
    # White cyclorama: pale grey box, wide soft panels; for the Gallery.
    "light": {
        "bg": (0.42, 0.62),
        "tint": (1.0, 1.0, 1.0),
        "side": [(-0.5, 0.3, 0.2, 0.55, 0.12, 0.95), (0.5, 0.3, 0.2, 0.55, 0.12, 0.95)],
        "up": [(0, 0, 0.7, 0.5, 0.2, 1.0)],
        "dn": [(0, 0, 0.6, 0.6, 0.4, 0.5)],
    },
}


def face(look, kind):
    lo, hi = look["bg"]
    tr, tg, tb = look["tint"]
    panels = look[kind]
    rows = []
    for y in range(SIZE):
        v = 1 - 2 * (y + 0.5) / SIZE
        row = bytearray()
        for x in range(SIZE):
            u = 2 * (x + 0.5) / SIZE - 1
            if kind == "side":
                base = lo + (hi - lo) * smooth(-1, 1, v)
            elif kind == "up":
                base = hi
            else:
                base = lo
            level = base
            for cu, cv, hw, hh, soft, lv in panels:
                level = max(level, base + (lv - base) * box(u, v, cu, cv, hw, hh, soft))
            level = min(1.0, level)
            row += bytes((int(255 * level * tr), int(255 * level * tg), int(255 * level * tb)))
        rows.append(row)
    return rows


def main():
    os.makedirs(OUT, exist_ok=True)
    looks = sys.argv[1:] or list(LOOKS)
    for name in looks:
        look = LOOKS[name]
        side = face(look, "side")
        for f in ("Bk", "Ft", "Lf", "Rt"):
            write_png(os.path.join(OUT, f"studio_{name}_{f}.png"), side)
        write_png(os.path.join(OUT, f"studio_{name}_Up.png"), face(look, "up"))
        write_png(os.path.join(OUT, f"studio_{name}_Dn.png"), face(look, "dn"))
        print("wrote", name)


if __name__ == "__main__":
    main()
