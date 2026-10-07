#!/usr/bin/env python3
"""KRUZER's art (hud-variants, 2026-10-07): the ARCADE layout the owner
picked, with a real instrument cluster. After Tokyo Xtreme Racer 2025's
orange-lit tacho with small gauges round it, and the 100-series Land
Cruiser's cluster at night (amber numerals lit through a black face, a red
needle that glows).

  tacho_*      0..8000 r/min over FROM..TO degrees; an LCD for the speed and
               the odometer at the bottom, the gear in a window over the
               cap, a strip of telltales under it.
  roll_*       an inclinometer: the car tilts with the roll; red marks at
               the tip angle (the HUD turns them).
  angle_*      the drift angle, -90..90 over the top half.
  lcd          seven-segment characters for the LCDs (LCD_CHARS order).
  dots         the dot-matrix characters for the drift display (parts.DOT_ORDER).
  mid, mini    the drift display's glass and the cash display's.
  lamp_*       the telltales lit (they sit over the face's dim print).
  pedal_*, pad_*, lever_*, natl_*, pill, lean_*   the controls.

Run from anywhere: python3 art/hud/kruzer/make.py (PYTHONPATH to resvg-py).
Coordinates the HUD needs are printed at the end and kept in
src/client/HudLab/Variants/Kruzer.luau.
"""
import math
import pathlib
import sys

HERE = pathlib.Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent))

import numpy as np  # noqa: E402

import kit as K  # noqa: E402
import parts as P  # noqa: E402

AMBER = "#ffad42"
AMBER_GLOW = "#ff7a12"
AMBER_DIM = "#0d0702"
RED = "#ff3a24"
GREEN = "#5cff7a"
FROM, TO, MAX, RED_FROM = -125, 125, 8000, 6800

# The tacho's layout, in its 768 px (the HUD uses these as fractions).
T = 768
TC = T / 2
GEAR_WIN = (TC, 262, 78, 96)  # centre x, y, w, h
TELLS = ((276, 262), (318, 262), (450, 262), (492, 262))  # shift, brake, slip, natl
TELL_SIZE = 38
LCD = (TC, 572, 300, 168)
SPEED_BOX = (262, 500, 192, 104)  # x, y, w, h of the three speed digits
ODO_BOX = (300, 614, 168, 40)  # six odometer digits

LCD_CHARS = "0123456789 -rnP#"


def name(n):
    return f"kruzer_{n}"


def save(c, n):
    p = K.save(c, name(n))
    print(p.name, c.w, "x", c.h)


# --------------------------------------------------------------------------
# Icons (SVG, drawn in a 100x100 box)
# --------------------------------------------------------------------------

def suv_rear(stroke, sw=5.0, fill="none"):
    """A boxy SUV from behind: body, glasshouse, wheels, lamps."""
    return (
        f'<g fill="{fill}" stroke="{stroke}" stroke-width="{sw}" stroke-linejoin="round" stroke-linecap="round">'
        '<path d="M14 46 L20 40 L80 40 L86 46 L86 70 L14 70 Z"/>'
        '<path d="M24 40 L29 17 L71 17 L76 40"/>'
        '<path d="M31 37 L34 22 L66 22 L69 37 Z" stroke-width="3"/>'
        '<rect x="17" y="70" width="14" height="13" rx="3"/>'
        '<rect x="69" y="70" width="14" height="13" rx="3"/>'
        '<line x1="20" y1="52" x2="30" y2="52"/><line x1="70" y1="52" x2="80" y2="52"/>'
        '</g>'
    )


def icon_brake(col):
    return (
        f'<g fill="none" stroke="{col}" stroke-width="7" stroke-linecap="round">'
        '<circle cx="50" cy="50" r="27"/>'
        '<path d="M16 26 A40 40 0 0 0 16 74"/><path d="M84 26 A40 40 0 0 1 84 74"/></g>'
        + K.text_svg(50, 64, "P", 40, "Barlow Condensed", fill=col, weight="bold")
    )


def icon_slip(col):
    return (
        f'<g fill="none" stroke="{col}" stroke-width="6" stroke-linejoin="round" stroke-linecap="round">'
        '<path d="M30 20 L70 20 L76 44 L76 56 L24 56 L24 44 Z"/>'
        '<line x1="30" y1="38" x2="70" y2="38"/>'
        '<path d="M30 64 C 22 72, 38 78, 28 90"/><path d="M70 64 C 62 72, 78 78, 68 90"/></g>'
    )


def icon_natl(col):
    return f'<g transform="rotate(-22 50 76)">{suv_rear(col, 6)}</g>' + f'<line x1="10" y1="90" x2="90" y2="90" stroke="{col}" stroke-width="5" stroke-linecap="round"/>'


def icon_shift(col):
    return (
        f'<path d="M50 14 L82 50 L62 50 L62 82 L38 82 L38 50 L18 50 Z" fill="none" stroke="{col}" stroke-width="7" stroke-linejoin="round"/>'
    )


def icon_at(svg, x, y, size):
    k = size / 100
    return f'<g transform="translate({x - size / 2:.2f} {y - size / 2:.2f}) scale({k:.4f})">{svg}</g>'


# --------------------------------------------------------------------------
# The tacho
# --------------------------------------------------------------------------

def tacho():
    c = K.Canvas(T, T)
    s = K.Surface(c)
    fr = P.bezel(c, s, TC, TC, 378, chrome_w=10, hood_w=24, seed=11)
    P.face(c, s, TC, TC, fr, base="#040405", centre="#0e0f10", seed=12)
    # Recessed windows: the LCD and the gear's.
    for (x, y, w, h), r in ((LCD, 20), (GEAR_WIN, 14)):
        d = K.rrect(c, x, y, w + 16, h + 16, r + 6)
        s.paint(K.cover(d), albedo="#1a1b1d", metal=1, rough=0.3, h=K.bevel(d, 5, 3))
        d2 = K.rrect(c, x, y, w, h, r)
        s.paint(K.cover(d2), albedo="#0c0703", metal=0, rough=0.2, clear=0.8, h=-4 + K.bevel(d2, 3, -2.0, "round") * 0)
    K.draw(c, s, shadow=(0, 12, 14, 0.6), ao_radius=10)

    # The print: ticks and numerals lit amber through the face.
    num = lambda v: str(int(v // 1000))  # noqa: E731
    ticks = P.scale_svg(TC, TC, d0=FROM, d1=TO, vmax=MAX, major=1000, minor=250, mid_len=24, r_out=338,
                        major_len=36, minor_len=13, major_w=7, minor_w=3.2, colour=AMBER, red_from=RED_FROM, red=RED,
                        numerals=num, num_r=268, num_size=72, family="Barlow Condensed", weight="bold",
                        red_band=(344, 7))
    label = K.text_svg(TC, 196, "x1000r/min", 22, "Barlow Condensed", fill=AMBER, weight="bold", spacing=1)
    P.printed(c, ticks + label, lit=AMBER_GLOW, bloom_r=6, bloom_k=0.85)
    # In the LCD: the units, dim when unlit print, lit here (the LCD's lamp
    # is always on); the ghost digits come from the atlas in the HUD.
    lx, ly, lw, lh = LCD
    sx, sy, sw, sh = SPEED_BOX
    ox, oy, ow, oh = ODO_BOX
    lcd_print = (
        K.text_svg(sx + sw + 8, sy + sh - 6, "km/h", 28, "Barlow Condensed", fill=AMBER, weight="bold", anchor="start")
        + K.text_svg(ox - 8, oy + oh - 6, "ODO", 22, "Barlow Condensed", fill=AMBER, weight="bold", anchor="end")
        + K.text_svg(ox + ow + 8, oy + oh - 6, "km", 22, "Barlow Condensed", fill=AMBER, weight="bold", anchor="start")
    )
    gx, gy, gw, gh = GEAR_WIN
    P.printed(c, lcd_print, lit=AMBER_GLOW, bloom_r=3, bloom_k=0.5)
    # The telltales, printed dim: dead front until one lights.
    dim = "#1d1a17"
    tells = [icon_shift(dim), icon_brake(dim), icon_slip(dim), icon_natl(dim)]
    P.printed(c, "".join(icon_at(t, x, y, TELL_SIZE) for t, (x, y) in zip(tells, TELLS)))
    # The LCD glass: a faint sheen across its top.
    win = K.cover(K.rrect(c, lx, ly, lw, lh, 20))
    sheen = K.smooth(ly - lh / 2 + 40, ly - lh / 2, c.Y) * win * 0.10
    c.over(np.broadcast_to(K.lin("#ffe2b8"), (T, T, 3)), sheen)
    save(c, "tacho_face")

    c = K.Canvas(T, T)
    P.needle(c, TC, TC, 330, 62, 15, 4, "#ff3a1a", core="#ffd2a0", glow="#ff3a10", glow_r=7, glow_k=0.9, body_rough=0.3)
    save(c, "tacho_needle")

    c = K.Canvas(T, T)
    P.dial_glass(c, TC, TC, fr + 2, strength=1.0)
    P.cap(c, TC, TC, 50, ring_w=8)
    save(c, "tacho_glass")


# --------------------------------------------------------------------------
# The small gauges
# --------------------------------------------------------------------------

S = 320
SC = S / 2


def pod(c, s, seed):
    fr = P.bezel(c, s, SC, SC, 156, chrome_w=7, hood_w=12, seed=seed)
    P.face(c, s, SC, SC, fr, base="#040405", centre="#0e0f10", seed=seed + 1)
    K.draw(c, s, shadow=(0, 10, 10, 0.65), ao_radius=6)
    return fr


def roll_gauge():
    c = K.Canvas(S, S)
    s = K.Surface(c)
    fr = pod(c, s, 21)
    ticks = P.scale_svg(SC, SC, d0=-60, d1=60, vmax=120, major=30, minor=10, r_out=fr - 8, major_len=18,
                        minor_len=9, major_w=4.5, minor_w=2.4, colour=AMBER,
                        numerals=lambda v: str(int(abs(v - 60))), num_r=fr - 44, num_size=30)
    horizon = f'<line x1="{SC - 92}" y1="{SC + 58}" x2="{SC + 92}" y2="{SC + 58}" stroke="{AMBER}" stroke-width="3" stroke-opacity="0.6"/>'
    label = K.text_svg(SC, SC + 102, "ROLL", 26, "Barlow Condensed", fill=AMBER, weight="bold", spacing=2)
    P.printed(c, ticks + horizon + label, lit=AMBER_GLOW, bloom_r=4, bloom_k=0.8)
    save(c, "roll_face")

    # The car that tilts (its pivot the gauge's centre), lit amber.
    c = K.Canvas(S, S)
    P.printed(c, icon_at(suv_rear(AMBER, 5.5), SC, SC + 8, 150), lit=AMBER_GLOW, bloom_r=4, bloom_k=0.9)
    # A pointer on the roof's centre line, up to the scale.
    P.printed(c, f'<path d="M{SC} {SC - 116} L{SC - 8} {SC - 98} L{SC + 8} {SC - 98} Z" fill="{AMBER}"/>', lit=AMBER_GLOW, bloom_r=3, bloom_k=0.8)
    save(c, "roll_car")

    # The tip mark: a red wedge at the top, turned to where the car tips.
    c = K.Canvas(S, S)
    P.printed(c, f'<path d="M{SC} {SC - fr + 34} L{SC - 9} {SC - fr + 8} L{SC + 9} {SC - fr + 8} Z" fill="{RED}"/>', lit=RED, bloom_r=4, bloom_k=0.8)
    save(c, "roll_tip")


def angle_gauge():
    c = K.Canvas(S, S)
    s = K.Surface(c)
    fr = pod(c, s, 31)
    ticks = P.scale_svg(SC, SC, d0=-90, d1=90, vmax=180, major=30, minor=10, r_out=fr - 8, major_len=18,
                        minor_len=9, major_w=4.5, minor_w=2.4, colour=AMBER, red_from=150, red=RED,
                        numerals=lambda v: str(int(abs(v - 90))), num_r=fr - 44, num_size=28)
    # The sweet spot, 30..60 either way, as a band outside the ticks.
    band = "".join(f'<path d="{P.arc_path(SC, SC, fr - 4, a0, a1)}" fill="none" stroke="{AMBER}" stroke-width="5" stroke-opacity="0.9"/>' for a0, a1 in ((-60, -30), (30, 60)))
    label = K.text_svg(SC, SC + 82, "ANGLE", 26, "Barlow Condensed", fill=AMBER, weight="bold", spacing=2)
    P.printed(c, ticks + band + label, lit=AMBER_GLOW, bloom_r=4, bloom_k=0.8)
    save(c, "angle_face")


def pod_needle_glass():
    c = K.Canvas(S, S)
    P.needle(c, SC, SC, 126, 26, 9, 3, "#ff3a1a", core="#ffd2a0", glow="#ff3a10", glow_r=4, glow_k=0.9)
    save(c, "pod_needle")
    c = K.Canvas(S, S)
    P.dial_glass(c, SC, SC, 138, strength=1.1, seed=4)
    P.cap(c, SC, SC, 21, ring_w=4)
    save(c, "pod_glass")


# --------------------------------------------------------------------------
# Readouts
# --------------------------------------------------------------------------

def atlases():
    c = P.seg_atlas(LCD_CHARS, 60, 96, 70, lit=AMBER, ghost=AMBER_DIM, glow=AMBER_GLOW, glow_r=3, glow_k=0.6)
    save(c, "lcd")
    c, (cw, ch, cols) = P.dot_atlas(16, AMBER, AMBER_DIM, cols=10, glow=AMBER_GLOW)
    save(c, "dots")
    print("dots cell", cw, ch, "cols", cols)


def display(w, h, n, r=30):
    """A display's glass in its chrome frame: smoked, a sheen at the top."""
    c = K.Canvas(w, h)
    s = K.Surface(c)
    outer = K.rrect(c, w / 2, h / 2 - 4, w - 16, h - 20, r)
    s.shape(K.cover(outer))
    s.paint(K.cover(outer), albedo="#e9ebee", metal=1, rough=0.08, h=K.bevel(outer, 7, 6))
    inner = K.rrect(c, w / 2, h / 2 - 4, w - 32, h - 36, r - 8)
    s.paint(K.cover(inner), albedo="#030303", metal=0, rough=0.25, spec=0.15, clear=0.5, h=1 + K.bevel(inner, 2, 0.5))
    K.draw(c, s, shadow=(0, 8, 10, 0.5), ao=0)
    # The glass lets the world through a little.
    c.a = c.a * (1 - 0.12 * K.cover(inner))
    sheen = K.smooth(h * 0.42, 14, c.Y) * K.cover(inner) * 0.07
    c.over(np.broadcast_to(K.lin("#fff1dc"), (h, w, 3)), sheen)
    save(c, n)


def lamps():
    for n, svg, col in (("shift", icon_shift, GREEN), ("brake", icon_brake, RED), ("slip", icon_slip, AMBER),
                        ("natl", icon_natl, GREEN)):
        c = K.Canvas(96, 96)
        P.printed(c, icon_at(svg(col), 48, 48, 66), lit=col, bloom_r=5, bloom_k=0.9)
        save(c, f"lamp_{n}")


# --------------------------------------------------------------------------
# Controls: OEM parts, at night
# --------------------------------------------------------------------------

def pedals():
    c = P.rubber_pedal(400, 1000, plate=(0.82, 0.93), pad_inset=24, radius=64, rib_pitch=36, seed=41)
    save(c, "pedal_gas")
    c = P.rubber_pedal(560, 520, plate=(0.9, 0.86), pad_inset=26, radius=70, rib_pitch=32, seed=43)
    save(c, "pedal_brake")


def leather(c, cx, cy, r, seed, colour="#1a1614", seam_r=None):
    s = K.Surface(c)
    disc = K.circle(c, cx, cy, r)
    s.shape(K.cover(disc))
    _, edge = K.cells(c, 8, seed)
    h = K.bevel(disc, r * 0.16, r * 0.08, "smooth") + np.clip(edge / 4, 0, 1) * 0.8
    if seam_r:
        h -= K.cover(K.ring(c, cx, cy, seam_r, 9)) * 3
    s.paint(K.cover(disc), albedo=colour, metal=0, rough=0.55, h=h)
    if seam_r:
        ang = np.arctan2(c.Y - cy, c.X - cx)
        st = K.cover(K.ring(c, cx, cy, seam_r, 4.5)) * (np.sin(ang * seam_r / 4.2) > 0.25)
        s.paint(st, albedo="#7d7468", rough=0.7, add_h=1.4)
    return s


def pad():
    c = K.Canvas(640, 640)
    s = leather(c, 320, 320, 300, 51, seam_r=262)
    ring = K.ring(c, 320, 320, 296, 10)
    s.paint(K.cover(ring), albedo="#e8eaee", metal=1, rough=0.08, add_h=K.bevel(ring, 5, 6))
    K.draw(c, s, shadow=(0, 14, 16, 0.6))
    # Chrome arrows set into the leather, lit at their tips.
    arr = "".join(
        f'<path d="M{320 + sx * 232} 320 L{320 + sx * 196} 290 L{320 + sx * 196} 350 Z" fill="#fff"/>' for sx in (-1, 1)
    )
    a = K.svg_alpha(c, arr)
    s2 = K.Surface(c)
    s2.shape(a)
    s2.paint(a, albedo="#d9dce1", metal=1, rough=0.12, h=K.bevel(K.from_alpha(a), 6, 4))
    K.draw(c, s2, shadow=(0, 2, 2, 0.6), ao=0)
    save(c, "pad_base")

    c = K.Canvas(300, 300)
    s = leather(c, 150, 150, 132, 53, colour="#221c18", seam_r=96)
    ring = K.ring(c, 150, 150, 128, 9)
    s.paint(K.cover(ring), albedo="#eceef1", metal=1, rough=0.06, add_h=K.bevel(ring, 4, 7))
    s.h += K.bevel(K.circle(c, 150, 150, 132), 90, 30, "dome")
    K.draw(c, s, shadow=(0, 16, 14, 0.65))
    save(c, "pad_knob")


def lever():
    # The slot: a chrome-trimmed opening, a pleated leather boot down it.
    c = K.Canvas(220, 640)
    s = K.Surface(c)
    plate = K.rrect(c, 110, 316, 168, 600, 50)
    s.shape(K.cover(plate))
    s.paint(K.cover(plate), albedo="#0d0e10", metal=0, rough=0.5, h=K.bevel(plate, 10, 8) + K.grain(c, 61, 0.8) * 0.05)
    trim = K.cut(K.rrect(c, 110, 316, 120, 540, 36), K.rrect(c, 110, 316, 104, 524, 30))
    s.paint(K.cover(trim), albedo="#eceef1", metal=1, rough=0.07, add_h=6 + K.bevel(trim, 4, 4))
    boot = K.rrect(c, 110, 316, 104, 524, 30)
    pleat = K.ribs(c.Y, 30, 0.9) * 6
    _, edge = K.cells(c, 7, 62)
    s.paint(K.cover(boot), albedo="#15110f", metal=0, rough=0.6, h=2 + pleat + np.clip(edge / 4, 0, 1) * 0.5)
    K.draw(c, s, shadow=(0, 10, 12, 0.55))
    save(c, "lever_track")

    # The grip: stitched leather, a chrome release button at its end.
    c = K.Canvas(360, 260)
    s = K.Surface(c)
    grip = K.rrect(c, 160, 130, 270, 150, 72)
    s.shape(K.cover(grip))
    _, edge = K.cells(c, 7, 63)
    s.paint(K.cover(grip), albedo="#1b1613", metal=0, rough=0.52, h=K.bevel(grip, 60, 34, "round") + np.clip(edge / 4, 0, 1) * 0.6)
    seam = K.cover(np.abs(c.Y - 130) - 2.5) * K.cover(K.rrect(c, 150, 130, 230, 200, 10))
    s.paint(seam, albedo="#7d7468", rough=0.7, add_h=1.0 * (np.sin(c.X / 4.6) > 0.2))
    btn = K.circle(c, 296, 130, 46)
    s.shape(K.cover(btn))
    s.paint(K.cover(btn), albedo="#eef0f3", metal=1, rough=0.06, h=26 + K.bevel(btn, 30, 22, "dome"))
    K.draw(c, s, shadow=(0, 16, 14, 0.6))
    P.printed(c, K.text_svg(296, 146, "P", 44, "Barlow Condensed", fill="#3a3c40", weight="bold"))
    save(c, "lever_handle")


def natl_switch(lit):
    c, s, d = P.switch_square(320, body="#121316")
    K.draw(c, s, shadow=(0, 12, 12, 0.6))
    col = AMBER if lit else "#c9c4bb"
    # The indicator window across the top: amber when on.
    bar = K.rrect(c, 160, 70, 120, 14, 7)
    bar_m = K.cover(bar)
    c.over(np.broadcast_to(K.lin("#ffb347" if lit else "#2a2116"), (320, 320, 3)), bar_m)
    if lit:
        K.bloom(c, bar_m, AMBER_GLOW, 8, 1.2)
    art = icon_at(icon_natl(col), 160, 158, 120) + K.text_svg(160, 262, "NATL", 44, "Barlow Condensed", fill=col, weight="bold", spacing=3)
    P.printed(c, art, lit=AMBER_GLOW if lit else None, bloom_r=5, bloom_k=0.7)
    save(c, f"natl_{'on' if lit else 'off'}")


def pill():
    c = K.Canvas(300, 120)
    s = K.Surface(c)
    d = K.rrect(c, 150, 56, 284, 96, 30)
    s.shape(K.cover(d))
    rim = K.cut(d, K.rrect(c, 150, 56, 272, 84, 25))
    s.paint(K.cover(d), albedo="#121316", metal=0, rough=0.45, h=K.bevel(d, 10, 8) + K.grain(c, 71, 0.7) * 0.05)
    s.paint(K.cover(rim), albedo="#e8eaee", metal=1, rough=0.08, add_h=2)
    K.draw(c, s, shadow=(0, 6, 6, 0.5))
    save(c, "pill")


def lean():
    c = K.Canvas(900, 200)
    s = K.Surface(c)
    d = K.rrect(c, 450, 96, 860, 150, 75)
    s.shape(K.cover(d))
    s.paint(K.cover(d), albedo="#0d0e10", metal=0, rough=0.5, h=K.bevel(d, 12, 10))
    slot = K.rrect(c, 450, 96, 760, 34, 17)
    s.paint(K.cover(slot + 6), albedo="#eceef1", metal=1, rough=0.08, add_h=4)
    s.paint(K.cover(slot), albedo="#030303", metal=0, rough=0.4, h=-6)
    K.draw(c, s, shadow=(0, 10, 10, 0.55))
    for sx in (-1, 1):
        P.printed(c, f'<path d="M{450 + sx * 400} 96 L{450 + sx * 372} 74 L{450 + sx * 372} 118 Z" fill="{AMBER}"/>', lit=AMBER_GLOW, bloom_r=4, bloom_k=0.7)
    save(c, "lean_track")
    c = K.Canvas(200, 200)
    s = leather(c, 100, 100, 84, 81, colour="#221c18", seam_r=60)
    ring = K.ring(c, 100, 100, 80, 7)
    s.paint(K.cover(ring), albedo="#eceef1", metal=1, rough=0.06, add_h=K.bevel(ring, 3, 5))
    s.h += K.bevel(K.circle(c, 100, 100, 84), 60, 20, "dome")
    K.draw(c, s, shadow=(0, 12, 10, 0.65))
    save(c, "lean_knob")


if __name__ == "__main__":
    tacho()
    roll_gauge()
    angle_gauge()
    pod_needle_glass()
    atlases()
    display(960, 300, "mid")
    display(600, 200, "mini", r=24)
    lamps()
    pedals()
    pad()
    lever()
    natl_switch(False)
    natl_switch(True)
    pill()
    lean()
    print("tacho layout (px of 768):", dict(gear=GEAR_WIN, tells=TELLS, tell_size=TELL_SIZE, lcd=LCD, speed=SPEED_BOX, odo=ODO_BOX))
