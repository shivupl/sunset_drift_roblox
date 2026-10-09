#!/usr/bin/env python3
"""Layout D's art (hud-variants, 2026-10-08): the mobile layout the owner
put together from the mockups (round steer buttons bottom left, NATL over
the right one; EXIT / RESET / STYLE as round icon buttons by the cash, top
right; a small see-through tacho bottom middle; the pedals bottom right, a
round HAND button over the brake), in STREET's style, in two finishes:

  streetd_*   machined: black anodised buttons with a knurled rim, a smoked
              tacho in a black bezel (the pedals are STREET's aluminium ones)
  ghost_*     smoked glass: see-through buttons with a thin white rim, a
              glass tacho, black anodised pedals

Each finish: btn_left, btn_right, natl_off/on, hand_off/on, exit, reset,
style, tacho_face, tacho_needle, tacho_glass, pill (cash, 9-slice), board
(the drift score), and for ghost pedal_gas, pedal_brake. Shared: num (white
italic digits for the readouts, NUM_CHARS order in 80x150 cells, 8 across;
the HUD tints them).
"""
import pathlib
import sys

HERE = pathlib.Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent))

import numpy as np  # noqa: E402
from scipy import ndimage  # noqa: E402

import kit as K  # noqa: E402
import parts as P  # noqa: E402

RED = "#e3221a"
WHITE = "#f4f2ec"
NUM_CHARS = "0123456789,.x+-°"
FROM, TO, MAX, RED_FROM = -135, 135, 9000, 7000

ICONS = {
    "left": '<path d="M30 12 L12 24 L30 36 Z" fill="{c}"/>',
    "right": '<path d="M18 12 L36 24 L18 36 Z" fill="{c}"/>',
    "hand": '<g stroke="{c}" stroke-width="3.4" stroke-linecap="round"><circle cx="24" cy="24" r="11"/>'
            '<path d="M8 13 A17 17 0 0 0 8 35"/><path d="M40 13 A17 17 0 0 1 40 35"/></g>'
            '<text x="24" y="30.5" text-anchor="middle" font-family="Barlow Condensed" font-weight="bold" font-size="17" fill="{c}">P</text>',
    "natl": '<g transform="rotate(-20 24 34)" stroke="{c}" stroke-width="2.8" stroke-linejoin="round" fill="none">'
            '<path d="M9 24 L12 21 L36 21 L39 24 L39 34 L9 34 Z"/><path d="M14 21 L17 11 L31 11 L34 21"/>'
            '<rect x="11" y="34" width="6" height="5" rx="1.5"/><rect x="31" y="34" width="6" height="5" rx="1.5"/></g>'
            '<line x1="6" y1="41" x2="42" y2="41" stroke="{c}" stroke-width="2.6" stroke-linecap="round"/>',
    "exit": '<g stroke="{c}" stroke-width="3.2" stroke-linecap="round" stroke-linejoin="round" fill="none">'
            '<path d="M20 10 H11 V38 H20"/><path d="M22 24 H39"/><path d="M33 17 L40 24 L33 31"/></g>',
    "reset": '<g stroke="{c}" stroke-width="3.2" stroke-linecap="round" stroke-linejoin="round" fill="none">'
             '<path d="M36 22 A12 12 0 1 0 33 33"/><path d="M37 12 V22 H27"/></g>',
    "style": '<g stroke="{c}" stroke-width="3.2" stroke-linejoin="round" fill="none"><rect x="9" y="9" width="20" height="20" rx="3"/>'
             '<rect x="19" y="19" width="20" height="20" rx="3" fill="#e3221a"/></g>',
}


def save(c, n):
    p = K.save(c, n)
    print(p.name, c.w, "x", c.h)


def icon_svg(name, cx, cy, size, colour):
    k = size / 48
    return f'<g transform="translate({cx - size / 2:.2f} {cy - size / 2:.2f}) scale({k:.4f})">{ICONS[name].replace("{c}", colour)}</g>'


# --------------------------------------------------------------------------
# Round buttons
# --------------------------------------------------------------------------

def round_machined(size, icon, lit=None, icon_scale=0.42):
    """Black anodised, a knurled rim, a gently domed face, the icon printed
    white; lit: the icon and a ring round the face glow."""
    c = K.Canvas(size, size)
    s = K.Surface(c)
    cx = cy = size / 2
    r = size * 0.44
    fr = P.knurl_bezel(c, s, cx, cy, r, size * 0.07, chrome_w=size * 0.012, colour="#18191c", pitch=size / 60)
    face = K.circle(c, cx, cy, fr)
    s.paint(K.cover(face), albedo="#141518", metal=1, rough=0.4, h=size * 0.035 + K.bevel(face, fr * 0.6, size * 0.03, "dome") + K.radial_streaks(c, cx, cy, 5) * 0.06)
    K.draw(c, s, shadow=(0, size * 0.035, size * 0.03, 0.6))
    if lit:
        ring = K.cover(K.ring(c, cx, cy, fr - size * 0.025, size * 0.018))
        c.over(np.broadcast_to(K.lin(lit), (size, size, 3)), ring)
        K.bloom(c, ring, lit, size * 0.03, 1.2)
    col = lit or WHITE
    P.printed(c, icon_svg(icon, cx, cy, size * icon_scale, col), lit=lit, bloom_r=size * 0.02, bloom_k=0.8)
    return c


def round_ghost(size, icon, lit=None, icon_scale=0.42):
    """Smoked glass: see-through dark, a thin white rim, a sheen at the top,
    the icon white; lit: the rim and icon in the light's colour."""
    c = K.Canvas(size, size)
    cx = cy = size / 2
    r = size * 0.44
    disc = K.cover(K.circle(c, cx, cy, r))
    c.shadow(disc, 0, size * 0.02, size * 0.03, 0.35)
    c.over(np.broadcast_to(K.lin("#0c0d10"), (size, size, 3)), disc * 0.62)
    sheen = K.smooth(cy - r * 0.1, cy - r, c.Y) * K.cover(K.circle(c, cx, cy, r - size * 0.03)) * 0.12
    c.over(np.broadcast_to(K.lin("#ffffff"), (size, size, 3)), sheen)
    rim_col = lit or "#ffffff"
    rim = K.cover(K.ring(c, cx, cy, r - 1, size * 0.014))
    c.over(np.broadcast_to(K.lin(rim_col), (size, size, 3)), rim * (1.0 if lit else 0.5))
    if lit:
        K.bloom(c, rim, lit, size * 0.03, 1.2)
    P.printed(c, icon_svg(icon, cx, cy, size * icon_scale, lit or WHITE), lit=lit, bloom_r=size * 0.02, bloom_k=0.8)
    return c


# --------------------------------------------------------------------------
# The tacho: small, see-through
# --------------------------------------------------------------------------

T = 512
TC = T / 2


def tacho(prefix, machined):
    c = K.Canvas(T, T)
    if machined:
        s = K.Surface(c)
        fr = P.knurl_bezel(c, s, TC, TC, 250, 22, chrome_w=5, colour="#18191c", pitch=6)
        K.draw(c, s, shadow=(0, 8, 10, 0.55))
        # Cut the face out of the bezel's disc: smoked, the world shows through.
        face = K.cover(K.circle(c, TC, TC, fr))
        c.rgb = c.rgb * (1 - face[..., None])
        c.a = c.a * (1 - face)
        c.over(np.broadcast_to(K.lin("#08090b"), (T, T, 3)), face * 0.58)
    else:
        fr = 246
        face = K.cover(K.circle(c, TC, TC, fr))
        c.over(np.broadcast_to(K.lin("#08090b"), (T, T, 3)), face * 0.5)
        rim = K.cover(K.ring(c, TC, TC, fr, 3))
        c.over(np.broadcast_to(K.lin("#ffffff"), (T, T, 3)), rim * 0.55)
    num = lambda v: str(int(v // 1000))  # noqa: E731
    ticks = P.scale_svg(TC, TC, d0=FROM, d1=TO, vmax=MAX, major=1000, minor=250, mid_len=None, r_out=fr - 10,
                        major_len=26, minor_len=11, major_w=5.5, minor_w=2.4, colour=WHITE, red_from=RED_FROM, red=RED,
                        numerals=num, num_r=fr - 56, num_size=46, family="Barlow Condensed", weight="bold", style="italic",
                        red_band=(fr - 5, 7))
    P.printed(c, ticks, lit="#ffffff", bloom_r=2, bloom_k=0.25)
    save(c, f"{prefix}_tacho_face")

    c = K.Canvas(T, T)
    P.needle(c, TC, TC, fr - 24, 36, 11, 3.5, RED, shadow=False, body_rough=0.3)
    save(c, f"{prefix}_tacho_needle")

    c = K.Canvas(T, T)
    P.dial_glass(c, TC, TC, fr, strength=0.9 if machined else 1.1)
    P.cap(c, TC, TC, 16, ring_w=4, body="#141518")
    save(c, f"{prefix}_tacho_glass")


# --------------------------------------------------------------------------
# Panels: the cash pill (9-slice) and the drift board
# --------------------------------------------------------------------------

def panel(w, h, r, machined, alpha):
    c = K.Canvas(w, h)
    d = K.rrect(c, w / 2, h / 2 - 3, w - 12, h - 16, r)
    if machined:
        s = K.Surface(c)
        s.shape(K.cover(d))
        s.paint(K.cover(d), albedo="#17181b", metal=1, rough=0.38, h=K.bevel(d, 6, 5) + K.streaks(c, 7, 70, 0) * 0.08)
        rim = K.cut(d, K.rrect(c, w / 2, h / 2 - 3, w - 22, h - 26, r - 5))
        s.paint(K.cover(rim), albedo="#e9ebee", metal=1, rough=0.08, add_h=2)
        K.draw(c, s, shadow=(0, 5, 6, 0.5))
        inner = K.cover(K.rrect(c, w / 2, h / 2 - 3, w - 22, h - 26, r - 5))
        c.a = c.a * (1 - (1 - alpha) * inner)
    else:
        m = K.cover(d)
        c.shadow(m, 0, 4, 6, 0.3)
        c.over(np.broadcast_to(K.lin("#0b0c0f"), (h, w, 3)), m * alpha)
        rim = K.cover(np.abs(d + 1) - 1.2)
        c.over(np.broadcast_to(K.lin("#ffffff"), (h, w, 3)), rim * 0.45)
    return c


def numbers():
    cell_w, cell_h, cols = 80, 150, 8
    c = K.Canvas(cell_w * cols, cell_h * 2)
    parts = []
    for i, ch in enumerate(NUM_CHARS):
        x = (i % cols) * cell_w + cell_w / 2 - 4
        y = (i // cols) * cell_h + cell_h / 2 + 52
        t = ch.replace("&", "&amp;")
        parts.append(K.text_svg(x, y, t, 150, "Barlow Condensed", fill="#ffffff", weight="bold", style="italic",
                                extra='stroke="#0b0b0c" stroke-width="10" stroke-linejoin="round" paint-order="stroke"'))
    rgb, a = K.svg_rgba(c, "".join(parts))
    c.shadow(a, 3, 5, 3, 0.5)
    c.over(rgb, a)
    save(c, "num")


def finish(prefix, machined):
    btn = round_machined if machined else round_ghost
    save(btn(256, "left", icon_scale=0.4), f"{prefix}_btn_left")
    save(btn(256, "right", icon_scale=0.4), f"{prefix}_btn_right")
    save(btn(256, "natl", icon_scale=0.46), f"{prefix}_natl_off")
    save(btn(256, "natl", "#2fe36a", icon_scale=0.46), f"{prefix}_natl_on")
    save(btn(256, "hand", icon_scale=0.46), f"{prefix}_hand_off")
    save(btn(256, "hand", "#ff3a24", icon_scale=0.46), f"{prefix}_hand_on")
    for n in ("exit", "reset", "style"):
        save(btn(160, n, icon_scale=0.42), f"{prefix}_{n}")
    tacho(prefix, machined)
    save(panel(300, 120, 26, machined, 0.75), f"{prefix}_pill")
    save(panel(660, 170, 26, machined, 0.72), f"{prefix}_board")


def ghost_pedals():
    slots = [(200, 170 + i * 150, 64, 112) for i in range(5)]
    strips = [(112, 470, 52, 760), (288, 470, 52, 760)]
    save(P.drilled_pedal(400, 1000, plate_w=320, plate_h=920, radius=44, slots=slots, strips=strips, alum="#2c2e33", seed=151), "ghost_pedal_gas")
    slots = [(120 + i * 80, 250, 52, 150) for i in range(5)]
    strips = [(280, 104, 430, 46), (280, 396, 430, 46)]
    save(P.drilled_pedal(560, 520, plate_w=500, plate_h=440, radius=44, slots=slots, strips=strips, alum="#2c2e33", seed=153, brush_angle=0), "ghost_pedal_brake")


if __name__ == "__main__":
    finish("streetd", True)
    finish("ghost", False)
    ghost_pedals()
    numbers()
