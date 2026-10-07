#!/usr/bin/env python3
"""Parts the instrument-cluster variants share (hud-variants, 2026-10-07):
dial faces, needles, glass and caps, LCD and dot-matrix character atlases,
odometer drums, pedals, knobs and switches. Each takes its look as
arguments; art/hud/<variant>/make.py says which and writes the PNGs.

Dial angles: 0 is straight up, positive clockwise, as Roblox turns a GUI
object, so a needle image drawn pointing up turns to the same angle the face
was printed at.
"""
from __future__ import annotations

import math

import numpy as np
from scipy import ndimage

import kit as K

F = np.float32


def at(cx, cy, deg, r):
    a = math.radians(deg)
    return cx + r * math.sin(a), cy - r * math.cos(a)


def arc_path(cx, cy, r, d0, d1):
    x0, y0 = at(cx, cy, d0, r)
    x1, y1 = at(cx, cy, d1, r)
    large = 1 if abs(d1 - d0) > 180 else 0
    return f"M{x0:.2f} {y0:.2f} A{r} {r} 0 {large} 1 {x1:.2f} {y1:.2f}"


# --------------------------------------------------------------------------
# Dials
# --------------------------------------------------------------------------

def bezel(c: K.Canvas, s: K.Surface, cx, cy, r_out, chrome_w, hood_w, hood="#0b0c0d", chrome="#eef0f3", seed=1):
    """A dial's housing: a satin black hood ring and a polished chrome ring
    inside it. Returns the face's radius."""
    hood_d = K.circle(c, cx, cy, r_out)
    s.shape(K.cover(hood_d))
    r_chrome = r_out - hood_w
    hood_h = K.bevel(hood_d, hood_w * 0.8, hood_w * 0.45, "round") + K.grain(c, seed, 0.8) * 0.06
    s.paint(K.cover(hood_d), albedo=hood, metal=0, rough=0.5, h=hood_h)
    ring = K.ring(c, cx, cy, r_chrome - chrome_w / 2, chrome_w)
    s.paint(K.cover(ring), albedo=chrome, metal=1, rough=0.07, h=hood_w * 0.45 + K.bevel(ring, chrome_w * 0.5, chrome_w * 0.55, "round"))
    return r_chrome - chrome_w


def face(c: K.Canvas, s: K.Surface, cx, cy, r, base="#060607", centre="#121314", rough=0.62, seed=2, texture=0.05, spec=0.15):
    """The dial's card: dark, a touch lighter at the middle, fine grain."""
    d = K.circle(c, cx, cy, r)
    m = K.cover(d)
    rad = np.hypot(c.X - cx, c.Y - cy) / r
    col = K.lin(base)[None, None, :] * rad[..., None] + K.lin(centre)[None, None, :] * (1 - rad[..., None])
    s.paint(m, albedo=np.clip(col, 0, 1), metal=0, rough=rough, spec=spec, h=K.grain(c, seed, 0.6) * texture)
    return m


def scale_svg(cx, cy, *, d0, d1, vmax, major, minor, r_out, major_len, minor_len, mid_len=None, major_w=6.0,
              minor_w=2.5, colour="#ffffff", red_from=None, red="#ff3b2a", numerals=None, num_r=0.0, num_size=60,
              family="Barlow Condensed", weight="bold", style="normal", num_colour=None, red_band=None, skip=()):
    """Ticks and numerals round an arc as SVG: majors every `major`, minors
    every `minor`, a half-way tick if mid_len, red at and above red_from,
    a red band (r, width) over the red part. numerals(v) -> label or None."""
    parts = []
    n = int(round(vmax / minor))
    for i in range(n + 1):
        v = i * minor
        if any(abs(v - k) < 1e-6 for k in skip):
            continue
        deg = d0 + (d1 - d0) * v / vmax
        is_major = abs(v / major - round(v / major)) < 1e-6
        is_mid = mid_len is not None and not is_major and abs((v / major) % 1 - 0.5) < 1e-6
        ln = major_len if is_major else mid_len if is_mid else minor_len
        w = major_w if is_major else (major_w + minor_w) / 2 if is_mid else minor_w
        col = red if red_from is not None and v >= red_from - 1e-6 else colour
        x0, y0 = at(cx, cy, deg, r_out)
        x1, y1 = at(cx, cy, deg, r_out - ln)
        parts.append(f'<line x1="{x0:.2f}" y1="{y0:.2f}" x2="{x1:.2f}" y2="{y1:.2f}" stroke="{col}" stroke-width="{w}" stroke-linecap="butt"/>')
        if is_major and numerals:
            lab = numerals(v)
            if lab is not None:
                x, y = at(cx, cy, deg, num_r)
                ncol = red if red_from is not None and v >= red_from - 1e-6 else (num_colour or colour)
                parts.append(K.text_svg(x, y + num_size * 0.36, lab, num_size, family, fill=ncol, weight=weight, style=style))
    if red_band and red_from is not None:
        rb, wb = red_band
        a0 = d0 + (d1 - d0) * red_from / vmax
        parts.append(f'<path d="{arc_path(cx, cy, rb, a0, d1)}" fill="none" stroke="{red}" stroke-width="{wb}"/>')
    return "".join(parts)


def printed(c: K.Canvas, inner: str, lit: str | None = None, bloom_r=5.0, bloom_k=0.9, defs=""):
    """Puts SVG print on the canvas; if lit, it glows (backlit through the
    face) in that colour."""
    rgb, a = K.svg_rgba(c, inner, defs)
    if lit:
        K.bloom(c, a, lit, bloom_r, bloom_k)
    c.over(rgb, a)
    return a


def needle(c: K.Canvas, cx, cy, length, tail, base_w, tip_w, colour, core=None, glow=None, glow_r=6.0, glow_k=0.8,
           shadow=True, body_rough=0.35):
    """A needle pointing straight up from (cx, cy): tapered, its tail a
    counterweight. Lit needles (core) glow; painted ones are shaded."""
    s = K.Surface(c)
    pts = [(cx - base_w / 2, cy + tail), (cx - tip_w / 2, cy - length), (cx + tip_w / 2, cy - length), (cx + base_w / 2, cy + tail)]
    poly = " ".join(f"{x:.2f},{y:.2f}" for x, y in pts)
    a = K.svg_alpha(c, f'<polygon points="{poly}" fill="#fff"/>')
    d = K.from_alpha(a)
    s.shape(a)
    s.paint(a, albedo=colour, metal=0, rough=body_rough, clear=0.6, h=K.bevel(d, base_w * 0.45, base_w * 0.35, "round"))
    if shadow:
        c.shadow(a, 5, 9, 5, 0.5)
    c.over(K.shade(s, ao=0), a)
    if core:
        ca = K.svg_alpha(c, f'<line x1="{cx}" y1="{cy - length + 6}" x2="{cx}" y2="{cy + tail * 0.2}" stroke="#fff" stroke-width="{max(tip_w * 0.6, 1.5)}" stroke-linecap="round"/>')
        c.over(np.broadcast_to(K.lin(core), (c.h, c.w, 3)), ca * 0.85)
    if glow:
        K.bloom(c, a, glow, glow_r, glow_k)
    return a


def cap(c: K.Canvas, cx, cy, r, ring_w=6, body="#0d0e10", chrome="#eef0f3"):
    """The needle's centre cap: a glossy dome in a chrome ring."""
    s = K.Surface(c)
    d = K.circle(c, cx, cy, r)
    s.shape(K.cover(d))
    rd = K.ring(c, cx, cy, r - ring_w / 2, ring_w)
    s.paint(K.cover(d), albedo=body, metal=0, rough=0.18, clear=1, h=K.bevel(d, r * 0.9, r * 0.5, "dome"))
    s.paint(K.cover(rd), albedo=chrome, metal=1, rough=0.06, h=r * 0.3 + K.bevel(rd, ring_w / 2, ring_w * 0.4))
    K.draw(c, s, shadow=(3, 7, 5, 0.55), ao=0)


def dial_glass(c: K.Canvas, cx, cy, r, strength=1.0, seed=7):
    """The cover glass: the overhead soft box's reflection as a crescent at
    the top, a rim catch at the lower right, faint dust."""
    inside = K.cover(K.circle(c, cx, cy, r))
    dx, dy = (c.X - cx) / r, (c.Y - cy) / r
    # Crescent: inside the dial, outside a circle shifted down.
    cres = K.cover((np.hypot(dx, dy + 0.45) - 1.25) * -r * 0.5) * K.smooth(0.15, -0.55, dy)
    cres = cres * (0.5 + 0.5 * K.smooth(0.6, -0.4, dx))
    rim = np.clip(1 - np.abs(np.hypot(dx, dy) - 0.965) / 0.03, 0, 1) * K.smooth(0.2, 0.75, dx + dy)
    dust = np.clip(K.noise(c, 2.5, seed, 2) - 0.74, 0, 1) * 0.6
    a = np.clip((cres * 0.13 + rim * 0.22 + dust * 0.07) * strength, 0, 1) * inside
    c.over(np.broadcast_to(K.lin("#f4f8ff"), (c.h, c.w, 3)), a)


# --------------------------------------------------------------------------
# Character atlases (a row of cells the HUD picks from with ImageRectOffset)
# --------------------------------------------------------------------------

def seg_atlas(chars: str, cell_w: int, cell_h: int, size: float, lit: str, ghost: str, *, family="DSEG7 Classic",
              weight="bold", style="normal", glow: str | None = None, glow_r=3.0, glow_k=0.6, cols=None,
              ghost_glyph="8"):
    """Segment characters (DSEG7, or DSEG14 for letters), one per cell. '#'
    is the ghost (every segment, unlit: "8" in DSEG7, "~" in DSEG14), ' '
    blank. Cells run left to right, then down."""
    cols = cols or len(chars)
    rows = math.ceil(len(chars) / cols)
    c = K.Canvas(cell_w * cols, cell_h * rows)
    parts_lit, parts_ghost = [], []
    for i, ch in enumerate(chars):
        x = (i % cols) * cell_w + cell_w / 2
        y = (i // cols) * cell_h + cell_h / 2 + size * 0.5
        if ch == "#":
            parts_ghost.append(K.text_svg(x, y, ghost_glyph, size, family, fill=ghost, weight=weight, style=style))
        elif ch != " ":
            parts_lit.append(K.text_svg(x, y, ch, size, family, fill=lit, weight=weight, style=style))
    rgb, a = K.svg_rgba(c, "".join(parts_ghost))
    c.over(rgb, a)
    rgb, a = K.svg_rgba(c, "".join(parts_lit))
    if glow:
        K.bloom(c, a, glow, glow_r, glow_k)
    c.over(rgb, a)
    return c


# A 5x7 dot font (the HD44780 shapes) for the dot-matrix displays.
DOTS = {
    "0": ["01110", "10001", "10011", "10101", "11001", "10001", "01110"],
    "1": ["00100", "01100", "00100", "00100", "00100", "00100", "01110"],
    "2": ["01110", "10001", "00001", "00010", "00100", "01000", "11111"],
    "3": ["11111", "00010", "00100", "00010", "00001", "10001", "01110"],
    "4": ["00010", "00110", "01010", "10010", "11111", "00010", "00010"],
    "5": ["11111", "10000", "11110", "00001", "00001", "10001", "01110"],
    "6": ["00110", "01000", "10000", "11110", "10001", "10001", "01110"],
    "7": ["11111", "00001", "00010", "00100", "01000", "01000", "01000"],
    "8": ["01110", "10001", "10001", "01110", "10001", "10001", "01110"],
    "9": ["01110", "10001", "10001", "01111", "00001", "00010", "01100"],
    "A": ["01110", "10001", "10001", "10001", "11111", "10001", "10001"],
    "B": ["11110", "10001", "10001", "11110", "10001", "10001", "11110"],
    "C": ["01110", "10001", "10000", "10000", "10000", "10001", "01110"],
    "D": ["11100", "10010", "10001", "10001", "10001", "10010", "11100"],
    "E": ["11111", "10000", "10000", "11110", "10000", "10000", "11111"],
    "F": ["11111", "10000", "10000", "11110", "10000", "10000", "10000"],
    "G": ["01110", "10001", "10000", "10111", "10001", "10001", "01111"],
    "H": ["10001", "10001", "10001", "11111", "10001", "10001", "10001"],
    "I": ["01110", "00100", "00100", "00100", "00100", "00100", "01110"],
    "J": ["00111", "00010", "00010", "00010", "00010", "10010", "01100"],
    "K": ["10001", "10010", "10100", "11000", "10100", "10010", "10001"],
    "L": ["10000", "10000", "10000", "10000", "10000", "10000", "11111"],
    "M": ["10001", "11011", "10101", "10101", "10001", "10001", "10001"],
    "N": ["10001", "10001", "11001", "10101", "10011", "10001", "10001"],
    "O": ["01110", "10001", "10001", "10001", "10001", "10001", "01110"],
    "P": ["11110", "10001", "10001", "11110", "10000", "10000", "10000"],
    "Q": ["01110", "10001", "10001", "10001", "10101", "10010", "01101"],
    "R": ["11110", "10001", "10001", "11110", "10100", "10010", "10001"],
    "S": ["01111", "10000", "10000", "01110", "00001", "00001", "11110"],
    "T": ["11111", "00100", "00100", "00100", "00100", "00100", "00100"],
    "U": ["10001", "10001", "10001", "10001", "10001", "10001", "01110"],
    "V": ["10001", "10001", "10001", "10001", "10001", "01010", "00100"],
    "W": ["10001", "10001", "10001", "10101", "10101", "10101", "01010"],
    "X": ["10001", "10001", "01010", "00100", "01010", "10001", "10001"],
    "Y": ["10001", "10001", "10001", "01010", "00100", "00100", "00100"],
    "Z": ["11111", "00001", "00010", "00100", "01000", "10000", "11111"],
    "x": ["00000", "00000", "10001", "01010", "00100", "01010", "10001"],
    ".": ["00000", "00000", "00000", "00000", "00000", "01100", "01100"],
    ",": ["00000", "00000", "00000", "00000", "01100", "00100", "01000"],
    "+": ["00000", "00100", "00100", "11111", "00100", "00100", "00000"],
    "-": ["00000", "00000", "00000", "11111", "00000", "00000", "00000"],
    "!": ["00100", "00100", "00100", "00100", "00100", "00000", "00100"],
    ":": ["00000", "01100", "01100", "00000", "01100", "01100", "00000"],
    "/": ["00000", "00001", "00010", "00100", "01000", "10000", "00000"],
    "°": ["01100", "10010", "10010", "01100", "00000", "00000", "00000"],
    " ": ["00000"] * 7,
    "#": ["11111"] * 7,  # the ghost: every dot, unlit
}
DOT_ORDER = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZx.,+-!:/° #"


def dot_atlas(pitch: float, lit: str, ghost: str, *, cols=16, glow: str | None = None, glow_k=0.7, square=False):
    """The dot-matrix characters in DOT_ORDER, cells of 6x8 dots (one dot of
    spacing right and below) at `pitch` px."""
    cw, ch = int(pitch * 6), int(pitch * 8)
    rows = math.ceil(len(DOT_ORDER) / cols)
    c = K.Canvas(cw * cols, ch * rows)
    lit_m = np.zeros((c.h, c.w), F)
    ghost_m = np.zeros((c.h, c.w), F)
    rad = pitch * (0.40 if not square else 0.42)
    for i, chname in enumerate(DOT_ORDER):
        ox, oy = (i % cols) * cw + pitch * 0.5, (i // cols) * ch + pitch * 0.5
        rows_ = DOTS[chname]
        for ry, row in enumerate(rows_):
            for rx, bit in enumerate(row):
                x, y = ox + rx * pitch + pitch / 2, oy + ry * pitch + pitch / 2
                x0, x1 = int(x - pitch), int(x + pitch + 1)
                y0, y1 = int(y - pitch), int(y + pitch + 1)
                sub = (slice(max(y0, 0), min(y1, c.h)), slice(max(x0, 0), min(x1, c.w)))
                if square:
                    d = np.maximum(np.abs(c.X[sub] - x), np.abs(c.Y[sub] - y)) - rad
                else:
                    d = np.hypot(c.X[sub] - x, c.Y[sub] - y) - rad
                cov = K.cover(d)
                if chname == "#":
                    # Unlit dots are smaller: they show the grid, not a block.
                    gcov = K.cover(d + pitch * 0.08)
                    ghost_m[sub] = np.maximum(ghost_m[sub], gcov)
                elif bit == "1":
                    lit_m[sub] = np.maximum(lit_m[sub], cov)
    c.over(np.broadcast_to(K.lin(ghost), (c.h, c.w, 3)), ghost_m)
    if glow:
        K.bloom(c, lit_m, glow, pitch * 0.35, glow_k)
    c.over(np.broadcast_to(K.lin(lit), (c.h, c.w, 3)), lit_m)
    # A hot centre on each lit dot.
    core = ndimage.gaussian_filter(lit_m, pitch * 0.12) * lit_m
    c.glow(K.lin("#fff3d8") * 0.35, core * 0.6)
    return c, (cw, ch, cols)


# --------------------------------------------------------------------------
# Odometer drums: a strip of digits 0..9,0 down a drum and the drum's shade
# --------------------------------------------------------------------------

def drum_strip(cell_w: int, cell_h: int, size: float, ink="#f2f0ea", paper="#0f0f10", family="Barlow Condensed",
               weight="bold", seed=3):
    c = K.Canvas(cell_w, cell_h * 11)
    s = K.Surface(c)
    full = np.ones((c.h, c.w), F)
    s.shape(full)
    s.paint(full, albedo=paper, metal=0, rough=0.6, h=K.grain(c, seed, 0.6) * 0.05)
    c.over(K.shade(s, ao=0, env_gain=0.6), full)
    txt = "".join(K.text_svg(cell_w / 2, cell_h * i + cell_h / 2 + size * 0.36, str(i % 10), size, family, fill=ink, weight=weight) for i in range(11))
    rgb, a = K.svg_rgba(c, txt)
    c.over(rgb, a)
    return c


def drum_shade(w: int, h: int):
    """Over a drum window: the drum's curve (dark top and bottom), a soft
    highlight above the middle."""
    c = K.Canvas(w, h)
    y = (c.Y / h) * 2 - 1  # -1 top .. 1 bottom
    dark = np.clip(np.abs(y) ** 2.2, 0, 1) * 0.92
    c.over(np.zeros((h, w, 3), F), dark)
    hi = np.exp(-((y + 0.28) ** 2) / 0.02) * 0.16
    c.over(np.broadcast_to(K.lin("#ffffff"), (h, w, 3)), hi)
    return c


# --------------------------------------------------------------------------
# Controls
# --------------------------------------------------------------------------

def rubber_pedal(w, h, *, plate=(0.8, 0.92), pad_inset=26, radius=60, rib_pitch=34, rib_dir="h", steel="#3b3e43",
                 rubber="#131415", wear=0.25, seed=5, plate_r=None, extra=None):
    """An OEM pedal: a steel backing plate and a ribbed rubber pad on it, the
    rib tops worn a little lighter where the foot rubs."""
    c = K.Canvas(w, h)
    s = K.Surface(c)
    pw, ph = w * plate[0], h * plate[1]
    pr = plate_r if plate_r is not None else radius
    cx, cy = w / 2, h / 2 - h * 0.015
    pl = K.rrect(c, cx, cy, pw, ph, pr)
    s.shape(K.cover(pl))
    s.paint(K.cover(pl), albedo=steel, metal=1, rough=0.45, h=K.bevel(pl, 12, 10, "round") + K.streaks(c, seed, 50, 90) * 0.06)
    pad = K.rrect(c, cx, cy, pw - pad_inset * 2, ph - pad_inset * 2, max(pr - pad_inset * 0.7, 8))
    pm = K.cover(pad)
    coord = c.Y if rib_dir == "h" else c.X
    rib = K.ribs(coord, rib_pitch, 0.62)
    inner = K.cover(pad + 14)
    pad_h = 10 + K.bevel(pad, 8, 6, "round") + rib * 5 * inner + K.grain(c, seed + 1, 0.7) * 0.14
    worn = K.noise(c, 90, seed + 2, 3)
    shade_mix = np.clip(rib * inner * (worn - 0.35) * 1.6 * wear, 0, 1)
    alb = K.lin(rubber)[None, None, :] * (1 - shade_mix[..., None]) + K.lin("#3a3b3d")[None, None, :] * shade_mix[..., None]
    s.paint(pm, albedo=alb, metal=0, rough=0.78, h=pad_h)
    if extra:
        extra(c, s)
    K.draw(c, s, shadow=(0, 14, 12, 0.6))
    return c


def switch_square(size, *, body="#141518", rough=0.45, radius=None, top_concave=4.0, seed=9):
    """A dashboard push switch: a rounded square cap with a dished top."""
    c = K.Canvas(size, size)
    s = K.Surface(c)
    r = radius if radius is not None else size * 0.16
    d = K.rrect(c, size / 2, size / 2 - size * 0.02, size * 0.84, size * 0.84, r)
    s.shape(K.cover(d))
    dish = -top_concave * (1 - ((c.X - size / 2) ** 2 + (c.Y - size / 2) ** 2) / (size * 0.42) ** 2).clip(0, 1)
    s.paint(K.cover(d), albedo=body, metal=0, rough=rough, h=K.bevel(d, size * 0.07, size * 0.06, "round") + dish * K.cover(d + size * 0.06) + K.grain(c, seed, 0.7) * 0.05)
    return c, s, d


# --------------------------------------------------------------------------
# Machined parts (STREET)
# --------------------------------------------------------------------------

def knurl_bezel(c: K.Canvas, s: K.Surface, cx, cy, r_out, width, chrome_w=7, colour="#16171a", pitch=7.0, seed=13):
    """An aftermarket gauge's bezel: black anodised, knurled round its outer
    half, a polished ring at the face. Returns the face's radius."""
    d = K.circle(c, cx, cy, r_out)
    s.shape(K.cover(d))
    rad = np.hypot(c.X - cx, c.Y - cy)
    ang = np.arctan2(c.Y - cy, c.X - cx)
    # Straight knurl across the rim: ridges along the radius.
    ridges = np.abs(np.sin(ang * (2 * np.pi * r_out / pitch) / 2)) ** 0.7
    outer = K.smooth(r_out - width * 0.55, r_out - width * 0.45, rad)
    h = K.bevel(d, width * 0.5, width * 0.5, "round") + ridges * 2.2 * outer * K.cover(d + 3)
    s.paint(K.cover(d), albedo=colour, metal=1, rough=0.38, h=h + K.grain(c, seed, 0.7) * 0.05)
    r_ring = r_out - width
    ring = K.ring(c, cx, cy, r_ring + chrome_w / 2, chrome_w)
    s.paint(K.cover(ring), albedo="#eceef1", metal=1, rough=0.06, h=width * 0.35 + K.bevel(ring, chrome_w / 2, chrome_w * 0.5))
    return r_ring


def hex_screw(s: K.Surface, c: K.Canvas, cx, cy, r, colour="#c9ccd1"):
    """A button-head hex screw: a dome with a hex socket."""
    d = K.circle(c, cx, cy, r)
    s.shape(K.cover(d))
    ang = np.arctan2(c.Y - cy, c.X - cx)
    rad = np.hypot(c.X - cx, c.Y - cy)
    hexr = r * 0.42 / np.cos(((ang + np.pi / 6) % (np.pi / 3)) - np.pi / 6)
    sock = K.cover(rad - hexr)
    base = s.h + 0
    s.paint(K.cover(d), albedo=colour, metal=1, rough=0.25, h=base + K.bevel(d, r * 0.8, r * 0.5, "dome") - sock * r * 0.4)


def drilled_pedal(w, h, *, plate_w, plate_h, radius, slots, strips, alum="#c3c7cc", rubber="#111213", seed=7,
                  brush_angle=90):
    """A race pedal: brushed aluminium with slots cut through it (they show
    what is behind) and black rubber anti-slip strips with studs. slots and
    strips are lists of (cx, cy, w, h) rounded boxes."""
    c = K.Canvas(w, h)
    s = K.Surface(c)
    plate = K.rrect(c, w / 2, h / 2 - h * 0.012, plate_w, plate_h, radius)
    holes = K.union(*[K.rrect(c, x, y, sw, sh, min(sw, sh) / 2) for x, y, sw, sh in slots])
    body = K.cut(plate, holes)
    s.shape(K.cover(body))
    alum_h = K.bevel(body, 9, 9, "round") + K.streaks(c, seed, 70, brush_angle) * 0.1
    s.paint(K.cover(body), albedo=alum, metal=1, rough=0.26, h=alum_h)
    for x, y, sw, sh in strips:
        st = K.rrect(c, x, y, sw, sh, min(sw, sh) / 2)
        studs = K.cover(np.maximum(np.abs((c.X - x) % 18 - 9), np.abs((c.Y - y) % 18 - 9)) - 5.5)
        s.paint(K.cover(st), albedo=rubber, metal=0, rough=0.75, spec=0.4, h=9 + K.bevel(st, 4, 3) + studs * 2.5 * K.cover(st + 4))
    K.draw(c, s, shadow=(0, 14, 12, 0.6), ao_radius=6)
    return c


# --------------------------------------------------------------------------
# Brougham trim (KABRIS)
# --------------------------------------------------------------------------

def woodgrain(c: K.Canvas, seed: int, light="#7a4322", dark="#4a2412", period=26.0, angle_deg=0.0):
    """Walnut: growth rings warped by noise, soft between light and dark,
    with fine pores along the grain. Returns linear albedo (h, w, 3) and a
    small height for the grain."""
    a = np.radians(angle_deg)
    u = c.X * np.cos(a) + c.Y * np.sin(a)
    v = -c.X * np.sin(a) + c.Y * np.cos(a)
    warp = (K.noise(c, 220, seed, 4) - 0.5) * 160 + (K.noise(c, 40, seed + 1, 3) - 0.5) * 18
    t = np.sin((v + warp) / period * 2 * np.pi + u / 700.0)
    # Rings are thin dark lines in lighter wood, not even stripes.
    ring = np.clip(1 - np.abs(t) * 1.0, 0, 1) ** 3
    fine = K.streaks(c, seed + 2, 50, angle_deg) * 0.12
    tone = K.noise(c, 180, seed + 3, 3)
    mix = np.clip(0.75 - 0.55 * ring + fine + (tone - 0.5) * 0.5, 0, 1)
    col = K.lin(dark)[None, None, :] * (1 - mix[..., None]) + K.lin(light)[None, None, :] * mix[..., None]
    return col.astype(np.float32), (mix * 0.3).astype(np.float32)


def pebble(c: K.Canvas, seed: int, size=5.0, depth=0.6):
    """Pebble-grain moulded plastic: a height to add."""
    f1, edge = K.cells(c, size, seed)
    return (np.clip(edge / 3, 0, 1) * depth).astype(np.float32)
