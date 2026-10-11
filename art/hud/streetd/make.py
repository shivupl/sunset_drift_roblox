#!/usr/bin/env python3
"""Layout D's art (hud-variants, 2026-10-08): the mobile layout the owner
put together from the mockups (round steer buttons bottom left, NATL over
the right one; EXIT / RESET as round icon buttons by the cash, top right; a
small see-through tacho bottom middle; the pedals bottom right, a round HAND
button over the brake), in STREET's style with the machined finish (STREET
D): black anodised buttons with a knurled rim, a smoked tacho in a black
bezel. The pedals, the lean slider and the gear digits are STREET's
(art/hud/street/make.py). The smoked-glass finish (GHOST) went on
2026-10-10 with the other HUD styles.

streetd_*: btn_left, btn_right, natl_off/on, hand_off/on, exit, reset,
tacho_face, tacho_needle, tacho_glass, pill (cash, 9-slice), board (the
drift score). num: white italic digits for the readouts, NUM_CHARS order in
80x150 cells, 8 across; the HUD tints them.
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


# --------------------------------------------------------------------------
# The tacho: small, see-through
# --------------------------------------------------------------------------

T = 512
TC = T / 2


def tacho(prefix):
    c = K.Canvas(T, T)
    s = K.Surface(c)
    fr = P.knurl_bezel(c, s, TC, TC, 250, 22, chrome_w=5, colour="#18191c", pitch=6)
    K.draw(c, s, shadow=(0, 8, 10, 0.55))
    # Cut the face out of the bezel's disc: smoked, the world shows through.
    face = K.cover(K.circle(c, TC, TC, fr))
    c.rgb = c.rgb * (1 - face[..., None])
    c.a = c.a * (1 - face)
    c.over(np.broadcast_to(K.lin("#08090b"), (T, T, 3)), face * 0.58)
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
    P.dial_glass(c, TC, TC, fr, strength=0.9)
    P.cap(c, TC, TC, 16, ring_w=4, body="#141518")
    save(c, f"{prefix}_tacho_glass")


# --------------------------------------------------------------------------
# Panels: the cash pill (9-slice) and the drift board
# --------------------------------------------------------------------------

def panel(w, h, r, alpha):
    c = K.Canvas(w, h)
    d = K.rrect(c, w / 2, h / 2 - 3, w - 12, h - 16, r)
    s = K.Surface(c)
    s.shape(K.cover(d))
    s.paint(K.cover(d), albedo="#17181b", metal=1, rough=0.38, h=K.bevel(d, 6, 5) + K.streaks(c, 7, 70, 0) * 0.08)
    rim = K.cut(d, K.rrect(c, w / 2, h / 2 - 3, w - 22, h - 26, r - 5))
    s.paint(K.cover(rim), albedo="#e9ebee", metal=1, rough=0.08, add_h=2)
    K.draw(c, s, shadow=(0, 5, 6, 0.5))
    inner = K.cover(K.rrect(c, w / 2, h / 2 - 3, w - 22, h - 26, r - 5))
    c.a = c.a * (1 - (1 - alpha) * inner)
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


def buttons(prefix):
    btn = round_machined
    save(btn(256, "left", icon_scale=0.4), f"{prefix}_btn_left")
    save(btn(256, "right", icon_scale=0.4), f"{prefix}_btn_right")
    save(btn(256, "natl", icon_scale=0.46), f"{prefix}_natl_off")
    save(btn(256, "natl", "#2fe36a", icon_scale=0.46), f"{prefix}_natl_on")
    save(btn(256, "hand", icon_scale=0.46), f"{prefix}_hand_off")
    save(btn(256, "hand", "#ff3a24", icon_scale=0.46), f"{prefix}_hand_on")
    for n in ("exit", "reset"):
        save(btn(160, n, icon_scale=0.42), f"{prefix}_{n}")


if __name__ == "__main__":
    buttons("streetd")
    tacho("streetd")
    save(panel(300, 120, 26, 0.75), "streetd_pill")
    save(panel(660, 170, 26, 0.72), "streetd_board")
    numbers()
