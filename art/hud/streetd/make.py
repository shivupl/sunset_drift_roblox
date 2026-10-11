#!/usr/bin/env python3
"""Layout D's art (hud-variants): the mobile layout the owner put together
from the mockups (round steer buttons bottom left with a NATL button over
each; EXIT / RESET / STYLE as small round buttons by the cash, top right; a
small see-through tacho bottom middle; the pedals bottom right, a round HAND
button over the brake), in STREET's machined style, in three finishes the
owner cycles with STYLE (2026-10-10: "make a couple variants of the same
design i can cycle through"):

  streetd   black anodised, a polished ring, brushed aluminium pedals, red
  sodium    the game's own palette (UI_SYSTEM.md): warm asphalt anodised, a
            sand-gold ring, champagne pedals, lane-paint print, the sodium
            lamp's amber as the needle
  carbon    clear-coated carbon fibre, red anodised knurls, carbon pedals

Per finish (<finish>_*): base (a round button without its icon; every round
button is this, the icon goes over it in the HUD, so a finish is one image
however many buttons there are), tacho_face, tacho_needle, pill (cash,
9-slice), board (the drift score), pedal_gas, pedal_brake.

Shared: icons (white, tinted by the HUD: left, right, natl_l, natl_r, hand,
exit, reset, style in 192 px cells, 4 across), halo (the lit ring, white,
tinted), num (white italic digits, NUM_CHARS order in 80x150 cells, 8
across). The tacho's glass and cap are streetd_tacho_glass for every finish;
the gear digits are STREET's (art/hud/street/make.py).

Opacity (the owner: "button / overlay opacity find a way to reduce it
subtly"): a button's face is FACE_ALPHA see-through while its rim stays
solid, the pedals' slots are cut through, the panels' insides are
PANEL_ALPHA, the tacho's face SMOKE; the HUD adds a little more at rest.
"""
import pathlib
import sys

HERE = pathlib.Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent))

import numpy as np  # noqa: E402
from scipy import ndimage  # noqa: E402

import kit as K  # noqa: E402
import parts as P  # noqa: E402

WHITE = "#f4f2ec"
NUM_CHARS = "0123456789,.x+-°"
FROM, TO, MAX, RED_FROM = -135, 135, 9000, 7000
FACE_ALPHA = 0.8
PANEL_ALPHA = 0.62
SMOKE = 0.5

FINISHES = {
    "streetd": dict(knurl="#18191c", ring="#eceef1", face="#141518", carbon=False,
                    tick=WHITE, red="#e3221a", needle="#e3221a", smoke="#08090b",
                    panel="#17181b", rim="#e9ebee", pedal="#c3c7cc", rubber="#111213"),
    # UI_SYSTEM.md: asphalt 800/900, paint #E8E2CD, sand #C6AC84, sodium
    # #FFBA5C, beacon #F0533F. The ring and pedals are sand as metal.
    "sodium": dict(knurl="#2b2722", ring="#d9c49b", face="#1f1c18", carbon=False,
                   tick="#e8e2cd", red="#f0533f", needle="#ffba5c", smoke="#0d0c0b",
                   panel="#1f1c18", rim="#d9c49b", pedal="#bea77f", rubber="#15130f"),
    "carbon": dict(knurl="#9c1219", ring="#eceef1", face="#141518", carbon=True,
                   tick=WHITE, red="#ff2a1f", needle="#ff2a1f", smoke="#08090b",
                   panel="#141518", rim="#c8161e", pedal=None, rubber="#7a1016"),
}

ICONS = {
    "left": '<path d="M30 12 L12 24 L30 36 Z" fill="#fff"/>',
    "right": '<path d="M18 12 L36 24 L18 36 Z" fill="#fff"/>',
    "hand": '<g stroke="#fff" stroke-width="3.4" stroke-linecap="round" fill="none"><circle cx="24" cy="24" r="11"/>'
            '<path d="M8 13 A17 17 0 0 0 8 35"/><path d="M40 13 A17 17 0 0 1 40 35"/></g>'
            '<text x="24" y="30.5" text-anchor="middle" font-family="Barlow Condensed" font-weight="bold" font-size="17" fill="#fff">P</text>',
    # The car leaning onto its left (natl_l) or right wheels, as Q and E do.
    "natl_l": '<g transform="rotate(-20 24 34)" stroke="#fff" stroke-width="2.8" stroke-linejoin="round" fill="none">'
              '<path d="M9 24 L12 21 L36 21 L39 24 L39 34 L9 34 Z"/><path d="M14 21 L17 11 L31 11 L34 21"/>'
              '<rect x="11" y="34" width="6" height="5" rx="1.5"/><rect x="31" y="34" width="6" height="5" rx="1.5"/></g>'
              '<line x1="6" y1="41" x2="42" y2="41" stroke="#fff" stroke-width="2.6" stroke-linecap="round"/>',
    "natl_r": '<g transform="rotate(20 24 34)" stroke="#fff" stroke-width="2.8" stroke-linejoin="round" fill="none">'
              '<path d="M9 24 L12 21 L36 21 L39 24 L39 34 L9 34 Z"/><path d="M14 21 L17 11 L31 11 L34 21"/>'
              '<rect x="11" y="34" width="6" height="5" rx="1.5"/><rect x="31" y="34" width="6" height="5" rx="1.5"/></g>'
              '<line x1="6" y1="41" x2="42" y2="41" stroke="#fff" stroke-width="2.6" stroke-linecap="round"/>',
    "exit": '<g stroke="#fff" stroke-width="3.2" stroke-linecap="round" stroke-linejoin="round" fill="none">'
            '<path d="M20 10 H11 V38 H20"/><path d="M22 24 H39"/><path d="M33 17 L40 24 L33 31"/></g>',
    "reset": '<g stroke="#fff" stroke-width="3.2" stroke-linecap="round" stroke-linejoin="round" fill="none">'
             '<path d="M36 22 A12 12 0 1 0 33 33"/><path d="M37 12 V22 H27"/></g>',
    "style": '<g stroke="#fff" stroke-width="3.2" stroke-linejoin="round" fill="none"><rect x="9" y="9" width="20" height="20" rx="3"/>'
             '<rect x="19" y="19" width="20" height="20" rx="3" fill="#fff" fill-opacity="0.45"/></g>',
}
ICON_ORDER = ["left", "right", "natl_l", "natl_r", "hand", "exit", "reset", "style"]
# A label under the icon, as board D had it.
ICON_LABEL = {"natl_l": "NATL", "natl_r": "NATL", "hand": "HAND"}
CELL = 192


def save(c, n):
    p = K.save(c, n)
    print(p.name, c.w, "x", c.h)


def icon_svg(name, cx, cy, size):
    k = size / 48
    return f'<g transform="translate({cx - size / 2:.2f} {cy - size / 2:.2f}) scale({k:.4f})">{ICONS[name]}</g>'


def full(c, colour):
    return np.broadcast_to(K.lin(colour), (c.h, c.w, 3))


# --------------------------------------------------------------------------
# Round buttons: the base per finish, the icons and the halo shared
# --------------------------------------------------------------------------

def base(f, size=256):
    """A knurled rim and a gently domed face, no icon. The face is
    FACE_ALPHA see-through; the rim stays solid."""
    c = K.Canvas(size, size)
    s = K.Surface(c)
    cx = cy = size / 2
    r = size * 0.44
    fr = P.knurl_bezel(c, s, cx, cy, r, size * 0.07, chrome_w=size * 0.012, colour=f["knurl"], pitch=size / 60,
                       chrome=f["ring"])
    face = K.circle(c, cx, cy, fr)
    dome = size * 0.035 + K.bevel(face, fr * 0.6, size * 0.03, "dome")
    if f["carbon"]:
        weave_h, over = P.carbon_weave(c, 9.0)
        s.paint(K.cover(face), albedo=P.weave_albedo(over), metal=0, rough=0.18, clear=1, spec=0.5, h=dome + weave_h * 0.4)
    else:
        s.paint(K.cover(face), albedo=f["face"], metal=1, rough=0.4, h=dome + K.radial_streaks(c, cx, cy, 5) * 0.06)
    K.draw(c, s, shadow=(0, size * 0.035, size * 0.03, 0.6))
    inner = K.cover(K.circle(c, cx, cy, fr - size * 0.01))
    c.a = c.a * (1 - (1 - FACE_ALPHA) * inner)
    return c


def icons():
    cols = 4
    c = K.Canvas(CELL * cols, CELL * 2)
    parts = []
    for i, name in enumerate(ICON_ORDER):
        x0, y0 = (i % cols) * CELL, (i // cols) * CELL
        label = ICON_LABEL.get(name)
        if label:
            parts.append(icon_svg(name, x0 + CELL / 2, y0 + 80, 112))
            parts.append(K.text_svg(x0 + CELL / 2, y0 + 172, label, 34, "Barlow Condensed", fill="#fff", weight="bold",
                                    spacing=3))
        else:
            parts.append(icon_svg(name, x0 + CELL / 2, y0 + CELL / 2, 120))
    rgb, a = K.svg_rgba(c, "".join(parts))
    # A soft dark shadow so the print reads on any face (the tint leaves it dark).
    c.shadow(a, 0, 3, 4, 0.55)
    c.over(rgb, a)
    save(c, "hud_icons")


def halo(size=256):
    """The lit ring at the face's edge and its glow, white for the HUD to tint."""
    c = K.Canvas(size, size)
    cx = cy = size / 2
    fr = size * 0.44 - size * 0.07
    ring = K.cover(K.ring(c, cx, cy, fr - size * 0.025, size * 0.018))
    glow = np.clip(ndimage.gaussian_filter(ring, size * 0.03) * 1.6, 0, 1)
    a = np.maximum(ring, glow * 0.85)
    c.over(full(c, "#ffffff"), a)
    save(c, "hud_halo")


# --------------------------------------------------------------------------
# The tacho: small, see-through
# --------------------------------------------------------------------------

T = 512
TC = T / 2


def tacho(fid, f):
    c = K.Canvas(T, T)
    s = K.Surface(c)
    fr = P.knurl_bezel(c, s, TC, TC, 250, 22, chrome_w=5, colour=f["knurl"], pitch=6, chrome=f["ring"])
    K.draw(c, s, shadow=(0, 8, 10, 0.55))
    # Cut the face out of the bezel's disc: smoked, the world shows through.
    face = K.cover(K.circle(c, TC, TC, fr))
    c.rgb = c.rgb * (1 - face[..., None])
    c.a = c.a * (1 - face)
    c.over(full(c, f["smoke"]), face * SMOKE)
    num = lambda v: str(int(v // 1000))  # noqa: E731
    ticks = P.scale_svg(TC, TC, d0=FROM, d1=TO, vmax=MAX, major=1000, minor=250, mid_len=None, r_out=fr - 10,
                        major_len=26, minor_len=11, major_w=5.5, minor_w=2.4, colour=f["tick"], red_from=RED_FROM,
                        red=f["red"], numerals=num, num_r=fr - 56, num_size=46, family="Barlow Condensed",
                        weight="bold", style="italic", red_band=(fr - 5, 7))
    P.printed(c, ticks, lit="#ffffff", bloom_r=2, bloom_k=0.25)
    save(c, f"{fid}_tacho_face")

    c = K.Canvas(T, T)
    P.needle(c, TC, TC, fr - 24, 36, 11, 3.5, f["needle"], shadow=False, body_rough=0.3)
    save(c, f"{fid}_tacho_needle")


def glass():
    c = K.Canvas(T, T)
    fr = 250 - 22
    P.dial_glass(c, TC, TC, fr, strength=0.9)
    P.cap(c, TC, TC, 16, ring_w=4, body="#141518")
    save(c, "streetd_tacho_glass")


# --------------------------------------------------------------------------
# Panels: the cash pill (9-slice) and the drift board
# --------------------------------------------------------------------------

def panel(f, w, h, r):
    c = K.Canvas(w, h)
    d = K.rrect(c, w / 2, h / 2 - 3, w - 12, h - 16, r)
    s = K.Surface(c)
    s.shape(K.cover(d))
    if f["carbon"]:
        weave_h, over = P.carbon_weave(c, 9.0)
        s.paint(K.cover(d), albedo=P.weave_albedo(over), metal=0, rough=0.2, clear=1, spec=0.5,
                h=K.bevel(d, 6, 5) + weave_h * 0.4)
    else:
        s.paint(K.cover(d), albedo=f["panel"], metal=1, rough=0.38, h=K.bevel(d, 6, 5) + K.streaks(c, 7, 70, 0) * 0.08)
    rim = K.cut(d, K.rrect(c, w / 2, h / 2 - 3, w - 22, h - 26, r - 5))
    s.paint(K.cover(rim), albedo=f["rim"], metal=1, rough=0.08 if not f["carbon"] else 0.3, add_h=2)
    K.draw(c, s, shadow=(0, 5, 6, 0.5))
    inner = K.cover(K.rrect(c, w / 2, h / 2 - 3, w - 22, h - 26, r - 5))
    c.a = c.a * (1 - (1 - PANEL_ALPHA) * inner)
    return c


# --------------------------------------------------------------------------
# Pedals, drawn at the shape the HUD lays them out at (the gas 2:5, the
# brake 1.58:1) so what you see is what you press
# --------------------------------------------------------------------------

def pedals(fid, f):
    kw = dict(alum=f["pedal"] or "#c3c7cc", rubber=f["rubber"], carbon=f["carbon"])
    slots = [(200, 170 + i * 150, 64, 112) for i in range(5)]
    strips = [(112, 470, 52, 760), (288, 470, 52, 760)]
    save(P.drilled_pedal(400, 1000, plate_w=320, plate_h=920, radius=44, slots=slots, strips=strips, seed=51, **kw),
         f"{fid}_pedal_gas")
    slots = [(320 + (i - 2) * 92, 196, 54, 132) for i in range(5)]
    strips = [(320, 66, 470, 40), (320, 326, 470, 40)]
    save(P.drilled_pedal(640, 404, plate_w=588, plate_h=344, radius=44, slots=slots, strips=strips, seed=53,
                         brush_angle=0, **kw), f"{fid}_pedal_brake")


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


if __name__ == "__main__":
    only = sys.argv[1:] or list(FINISHES)
    for fid in only:
        f = FINISHES[fid]
        save(base(f), f"{fid}_base")
        tacho(fid, f)
        save(panel(f, 300, 120, 26), f"{fid}_pill")
        save(panel(f, 660, 170, 26), f"{fid}_board")
        pedals(fid, f)
    if not sys.argv[1:]:
        icons()
        glass()
        halo()
        numbers()
