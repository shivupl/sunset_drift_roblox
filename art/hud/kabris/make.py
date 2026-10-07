#!/usr/bin/env python3
"""KABRIS's art (hud-variants, 2026-10-07): ARCADE's layout as the box
Caprice ("kabris"), the hajwala classic. After the 1977-90 cluster: a wide
chrome-trimmed housing, a sweep speedometer whose orange needle runs
sideways along a km/h scale with the MPH scale under it in blue, a gauge pod
on the left (here the tyres' temperature, C to H like the fuel gauge), text
lamps in the right pod, a PRND strip under it all with a pointer that slides
(here R N 1..6), a walnut band across the top; the drift score on a
vacuum-fluorescent display, as the dash's clock and radio were. Controls are
Brougham: chrome-trimmed pedals, a walnut and chrome pad with a spinner
knob, a PARK T-handle, a chrome pull knob for the natl.

  housing          1000x320: the whole cluster, printed (the needles, the
                   pointer, the drums and the lamps go over it)
  sweep            the speed needle (the HUD slides it along SPEED_X)
  pod_needle       the tyre needle, its pivot at the canvas's centre
  pointer          the gear pointer (slides along GEAR_X at POINTER_Y)
  lamp_*           the lamps lit
  glass            over the whole housing
  vfd, vfd_mini, vfd_over, vfd_mini_over   the display, its mesh and glass
  seg              14-segment characters (parts.DOT_ORDER, '#' the ghost)
"""
import pathlib
import sys

HERE = pathlib.Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent))

import numpy as np  # noqa: E402

import kit as K  # noqa: E402
import parts as P  # noqa: E402

HW, HH = 1000, 320
WHITE = "#f4f2ea"
BLUE = "#7cc8ff"
ORANGE = "#ff6a14"
VFD = "#5dffd2"
VFD_GLOW = "#18ffbc"
VFD_DIM = "#0a2620"

# The housing's windows and what is in them (px of 1000x320).
LEFT = (140, 150, 200, 190)  # centre x, y, w, h
CENTRE = (500, 140, 440, 170)
RIGHT = (860, 150, 200, 190)
SPEED_X = (310, 690)  # 0 and 220 km/h
SPEED_MAX = 220
NEEDLE_Y = (62, 142)  # the sweep needle's top and bottom
DRUMS = (420, 180, 160, 34)  # x, y, w, h
POD_PIVOT = (140, 236)  # the tyre needle's pivot (under the window's edge)
POD_FROM, POD_TO = -52, 52
GEAR_X = (330, 670)  # R .. 6, eight even steps
GEAR_Y = 272
POINTER_Y = 242
LAMPS = (("brake", 812, 112, "BRAKE", "#ff3a24"), ("natl", 908, 112, "NATL", "#5cff7a"),
         ("temp", 812, 190, "TEMP", "#ff3a24"), ("shift", 908, 190, "SHIFT", "#ffb020"))
LAMP_W, LAMP_H = 88, 46


def save(c, n):
    p = K.save(c, f"kabris_{n}")
    print(p.name, c.w, "x", c.h)


def window(c, s, box, r=14):
    x, y, w, h = box
    trim = K.rrect(c, x, y, w + 16, h + 16, r + 6)
    s.paint(K.cover(trim), albedo="#eceef1", metal=1, rough=0.07, h=8 + K.bevel(trim, 6, 5))
    face = K.rrect(c, x, y, w, h, r)
    s.paint(K.cover(face), albedo="#030303", metal=0, rough=0.6, spec=0.15, h=-6 + K.grain(c, 3, 0.6) * 0.04)


def housing():
    c = K.Canvas(HW, HH)
    s = K.Surface(c)
    panel = K.rrect(c, HW / 2, HH / 2 - 4, HW - 20, HH - 22, 30)
    s.shape(K.cover(panel))
    s.paint(K.cover(panel), albedo="#121214", metal=0, rough=0.62, spec=0.35, h=K.bevel(panel, 16, 12) + P.pebble(c, 11, 5, 0.5))
    bead = K.cut(panel, K.rrect(c, HW / 2, HH / 2 - 4, HW - 34, HH - 36, 24))
    s.paint(K.cover(bead), albedo="#eceef1", metal=1, rough=0.07, add_h=3)
    # The walnut band across the top.
    band = K.rrect(c, HW / 2, 30, HW - 80, 22, 6)
    wood, grain = P.woodgrain(c, 12, period=22, angle_deg=4)
    s.paint(K.cover(band), albedo=wood, metal=0, rough=0.15, clear=1, h=12 + K.bevel(band, 4, 3) + grain)
    for box in (LEFT, CENTRE, RIGHT):
        window(c, s, box)
    # The drums' window, set into the speedometer's face.
    dx, dy, dw, dh = DRUMS
    lip = K.rrect(c, dx + dw / 2, dy + dh / 2, dw + 12, dh + 12, 6)
    s.paint(K.cover(lip), albedo="#c9ccd1", metal=1, rough=0.12, add_h=2)
    s.paint(K.cover(K.rrect(c, dx + dw / 2, dy + dh / 2, dw + 2, dh + 2, 3)), albedo="#000000", rough=0.5, add_h=-3)
    # The PRND strip's chrome surround.
    strip = K.rrect(c, 500, GEAR_Y - 6, 410, 40, 12)
    s.paint(K.cover(K.cut(strip, K.rrect(c, 500, GEAR_Y - 6, 398, 30, 9))), albedo="#eceef1", metal=1, rough=0.08, add_h=4)
    K.draw(c, s, shadow=(0, 12, 14, 0.6), ao_radius=10)

    # The print.
    x0, x1 = SPEED_X
    k = (x1 - x0) / SPEED_MAX
    svg = []
    for v in range(0, SPEED_MAX + 1, 10):
        x = x0 + v * k
        major = v % 20 == 0
        svg.append(f'<line x1="{x:.1f}" y1="66" x2="{x:.1f}" y2="{92 if major else 82}" stroke="{WHITE}" stroke-width="{4 if major else 2.4}"/>')
        if major:
            svg.append(K.text_svg(x, 116, str(v), 23, "Barlow Condensed", fill=WHITE, weight="bold"))
    mph = (x1 - x0) / (SPEED_MAX / 1.609344)
    for m in range(0, 140, 10):
        x = x0 + m * mph
        if x > x1 + 0.5:
            break
        svg.append(f'<line x1="{x:.1f}" y1="126" x2="{x:.1f}" y2="134" stroke="{BLUE}" stroke-width="2.2"/>')
        if m % 20 == 0:
            svg.append(K.text_svg(x, 152, str(m), 15, "Barlow Condensed", fill=BLUE, weight="bold"))
    svg.append(K.text_svg(x0 - 6, 140, "km/h", 15, "Barlow Condensed", fill=WHITE, weight="bold", anchor="end"))
    svg.append(K.text_svg(x0 - 6, 154, "MPH", 13, "Barlow Condensed", fill=BLUE, weight="bold", anchor="end"))
    svg.append(K.text_svg(dx + dw + 8, dy + dh - 8, "km", 15, "Barlow Condensed", fill=WHITE, weight="bold", anchor="start"))
    # The tyre pod: a fuel-gauge arc, C to H.
    px, py = POD_PIVOT
    for i in range(11):
        deg = POD_FROM + (POD_TO - POD_FROM) * i / 10
        a0 = P.at(px, py, deg, 150)
        a1 = P.at(px, py, deg, 132 if i % 5 == 0 else 140)
        col = "#ff3a24" if i >= 8 else WHITE
        svg.append(f'<line x1="{a0[0]:.1f}" y1="{a0[1]:.1f}" x2="{a1[0]:.1f}" y2="{a1[1]:.1f}" stroke="{col}" stroke-width="{4.5 if i % 5 == 0 else 2.5}"/>')
    for lab, deg in (("C", POD_FROM + 6), ("H", POD_TO - 6)):
        x, y = P.at(px, py, deg, 108)
        svg.append(K.text_svg(x, y + 8, lab, 24, "Michroma", fill="#ff3a24" if lab == "H" else WHITE))
    svg.append(K.text_svg(px, 168, "TYRE", 16, "Michroma", fill=WHITE, spacing=2))
    # Gear letters.
    for i, ch in enumerate("RN123456"):
        x = GEAR_X[0] + (GEAR_X[1] - GEAR_X[0]) * i / 7
        svg.append(K.text_svg(x, GEAR_Y + 8, ch, 19, "Michroma", fill=WHITE))
    # The lamps' dim print.
    for _, x, y, text, _col in LAMPS:
        svg.append(f'<rect x="{x - LAMP_W / 2}" y="{y - LAMP_H / 2}" width="{LAMP_W}" height="{LAMP_H}" rx="5" fill="#0d0d0e" stroke="#26272a" stroke-width="2"/>')
        svg.append(K.text_svg(x, y + 7, text, 17, "Michroma", fill="#24252a"))
    P.printed(c, "".join(svg))
    save(c, "housing")

    # The sweep needle: a fluorescent orange bar.
    c = K.Canvas(40, 120)
    bar = K.cover(K.rrect(c, 20, 60, 7, 100, 3))
    c.over(np.broadcast_to(K.lin(ORANGE), (120, 40, 3)), bar)
    K.bloom(c, bar, "#ff4a00", 4, 1.0)
    core = K.cover(K.rrect(c, 20, 60, 2.5, 96, 1))
    c.over(np.broadcast_to(K.lin("#ffd2a8"), (120, 40, 3)), core * 0.8)
    save(c, "sweep")

    # The tyre needle (white, pivot at the canvas centre).
    c = K.Canvas(320, 320)
    P.needle(c, 160, 160, 146, 0, 8, 3, "#f4f2ea", shadow=True, body_rough=0.4)
    save(c, "pod_needle")

    # The gear pointer: an orange triangle pointing down at the letter.
    c = K.Canvas(40, 32)
    a = K.svg_alpha(c, '<path d="M8 7 L32 7 L20 25 Z" fill="#fff"/>')
    c.over(np.broadcast_to(K.lin(ORANGE), (32, 40, 3)), a)
    K.bloom(c, a, "#ff4a00", 3, 0.8)
    save(c, "pointer")

    for n, x, y, text, col in LAMPS:
        c = K.Canvas(LAMP_W + 24, LAMP_H + 24)
        cx, cy = c.w / 2, c.h / 2
        rect = K.cover(K.rrect(c, cx, cy, LAMP_W, LAMP_H, 5))
        c.over(np.broadcast_to(K.lin(col) * 0.35, (c.h, c.w, 3)), rect)
        K.bloom(c, rect, col, 6, 0.6)
        P.printed(c, K.text_svg(cx, cy + 7, text, 17, "Michroma", fill="#fff6e8"), lit=col, bloom_r=3, bloom_k=0.8)
        save(c, f"lamp_{n}")

    # The glass over it all: a soft band across each window.
    c = K.Canvas(HW, HH)
    inside = np.zeros((HH, HW), np.float32)
    for box in (LEFT, CENTRE, RIGHT):
        inside = np.maximum(inside, K.cover(K.rrect(c, box[0], box[1], box[2], box[3], 14)))
    band = K.smooth(0.0, 40, c.Y - 40 - (c.X - 200) * 0.18) * (1 - K.smooth(60, 130, c.Y - 40 - (c.X - 200) * 0.18))
    c.over(np.broadcast_to(K.lin("#eef6ff"), (HH, HW, 3)), band * inside * 0.16)
    save(c, "glass")


# --------------------------------------------------------------------------
# The vacuum-fluorescent display
# --------------------------------------------------------------------------

def vfd_atlas():
    c = P.seg_atlas(P.DOT_ORDER, 96, 128, 100, cols=10, lit=VFD, ghost=VFD_DIM, glow=VFD_GLOW, glow_r=4, glow_k=0.8,
                    family="DSEG14 Classic", ghost_glyph="~")
    save(c, "seg")


def vfd(w, h, name, r=26):
    c = K.Canvas(w, h)
    s = K.Surface(c)
    outer = K.rrect(c, w / 2, h / 2 - 4, w - 16, h - 20, r)
    s.shape(K.cover(outer))
    s.paint(K.cover(outer), albedo="#eceef1", metal=1, rough=0.07, h=K.bevel(outer, 7, 6))
    inner = K.rrect(c, w / 2, h / 2 - 4, w - 34, h - 38, r - 9)
    s.paint(K.cover(inner), albedo="#020605", metal=0, rough=0.3, spec=0.2, h=1)
    K.draw(c, s, shadow=(0, 8, 10, 0.5), ao=0)
    save(c, name)
    # Over the characters: the VFD's grid mesh and the smoked glass's sheen.
    o = K.Canvas(w, h)
    m = K.cover(inner + 4)
    mesh = ((np.abs((c.X % 7) - 3.5) < 0.6) | (np.abs((c.Y % 7) - 3.5) < 0.6)).astype(np.float32)
    o.over(np.broadcast_to(K.lin("#000000"), (h, w, 3)), mesh * m * 0.28)
    sheen = K.smooth(h * 0.45, 14, o.Y) * m * 0.1
    o.over(np.broadcast_to(K.lin("#e8fff8"), (h, w, 3)), sheen)
    save(o, name + "_over")


# --------------------------------------------------------------------------
# Controls
# --------------------------------------------------------------------------

def chrome_pedal(w, h, plate, rib_pitch, seed):
    c = K.Canvas(w, h)
    s = K.Surface(c)
    pw, ph = plate
    d = K.rrect(c, w / 2, h / 2 - 8, pw, ph, 36)
    s.shape(K.cover(d))
    s.paint(K.cover(d), albedo="#eceef1", metal=1, rough=0.07, h=K.bevel(d, 14, 14, "round"))
    pad = K.rrect(c, w / 2, h / 2 - 8, pw - 40, ph - 40, 22)
    rib = K.ribs(c.Y, rib_pitch, 0.6)
    s.paint(K.cover(pad), albedo="#141415", metal=0, rough=0.72, spec=0.45, h=8 + K.bevel(pad, 6, 4) + rib * 4 * K.cover(pad + 10) + K.grain(c, seed, 0.7) * 0.12)
    K.draw(c, s, shadow=(0, 14, 12, 0.6))
    return c


def pedals():
    save(chrome_pedal(400, 1000, (320, 920), 30, 61), "pedal_gas")
    save(chrome_pedal(560, 520, (500, 440), 28, 62), "pedal_brake")


def pad():
    c = K.Canvas(640, 640)
    s = K.Surface(c)
    d = K.circle(c, 320, 320, 300)
    s.shape(K.cover(d))
    wood, grain = P.woodgrain(c, 71, period=30, angle_deg=-20)
    ringw = K.cut(d, K.circle(c, 320, 320, 226))
    s.paint(K.cover(d), albedo=wood, metal=0, rough=0.14, clear=1, h=K.bevel(d, 40, 30, "round") + grain)
    chrome = K.ring(c, 320, 320, 222, 14)
    s.paint(K.cover(chrome), albedo="#eceef1", metal=1, rough=0.06, h=26 + K.bevel(chrome, 7, 6))
    centre = K.circle(c, 320, 320, 214)
    s.paint(K.cover(centre), albedo="#141416", metal=0, rough=0.6, spec=0.35, h=20 + P.pebble(c, 72, 5, 0.5))
    K.draw(c, s, shadow=(0, 14, 16, 0.6))
    arr = "".join(f'<path d="M{320 + sx * 196} 320 L{320 + sx * 160} 290 L{320 + sx * 160} 350 Z" fill="#fff"/>' for sx in (-1, 1))
    a = K.svg_alpha(c, arr)
    s2 = K.Surface(c)
    s2.shape(a)
    s2.paint(a, albedo="#e3e6ea", metal=1, rough=0.1, h=K.bevel(K.from_alpha(a), 6, 4))
    K.draw(c, s2, shadow=(0, 2, 2, 0.6), ao=0)
    del ringw
    save(c, "pad_base")

    # The spinner knob: a chrome cup, a red pearl dome with flake.
    c = K.Canvas(300, 300)
    s = K.Surface(c)
    cup = K.circle(c, 150, 150, 132)
    s.shape(K.cover(cup))
    s.paint(K.cover(cup), albedo="#eceef1", metal=1, rough=0.06, h=K.bevel(cup, 30, 26, "round"))
    dome = K.circle(c, 150, 150, 104)
    flake = np.clip(K.grain(c, 73, 0.0) - 2.2, 0, 1)
    pearl = K.lin("#b0101a")[None, None, :] * (0.8 + 0.4 * K.noise(c, 40, 74, 3)[..., None]) + flake[..., None] * K.lin("#ffd8a0")
    s.paint(K.cover(dome), albedo=np.clip(pearl, 0, 1), metal=0, rough=0.08, clear=1, h=26 + K.bevel(dome, 90, 40, "dome"))
    K.draw(c, s, shadow=(0, 16, 14, 0.65))
    save(c, "pad_knob")


def lever():
    c = K.Canvas(220, 640)
    s = K.Surface(c)
    plate = K.rrect(c, 110, 316, 160, 600, 40)
    s.shape(K.cover(plate))
    s.paint(K.cover(plate), albedo="#121214", metal=0, rough=0.62, spec=0.35, h=K.bevel(plate, 10, 8) + P.pebble(c, 81, 5, 0.5))
    trim = K.cut(K.rrect(c, 110, 316, 70, 520, 35), K.rrect(c, 110, 316, 50, 500, 25))
    s.paint(K.cover(trim), albedo="#eceef1", metal=1, rough=0.07, add_h=5 + K.bevel(trim, 4, 3))
    s.paint(K.cover(K.rrect(c, 110, 316, 50, 500, 25)), albedo="#030303", metal=0, rough=0.5, h=-6)
    K.draw(c, s, shadow=(0, 10, 12, 0.55))
    save(c, "lever_track")

    # The T-handle: black, a chrome face with PARK on it.
    c = K.Canvas(360, 260)
    s = K.Surface(c)
    t = K.union(K.rrect(c, 180, 112, 300, 84, 30), K.rrect(c, 180, 190, 70, 110, 18))
    s.shape(K.cover(t))
    s.paint(K.cover(t), albedo="#111113", metal=0, rough=0.4, spec=0.5, h=K.bevel(t, 30, 22, "round"))
    face = K.rrect(c, 180, 108, 250, 46, 20)
    s.paint(K.cover(face), albedo="#eceef1", metal=1, rough=0.07, add_h=3 + K.bevel(face, 6, 3))
    K.draw(c, s, shadow=(0, 16, 14, 0.6))
    P.printed(c, K.text_svg(180, 120, "PARK", 30, "Michroma", fill="#c4160c"))
    save(c, "lever_handle")


def natl_knob(lit):
    c = K.Canvas(320, 320)
    s = K.Surface(c)
    r = 132 if lit else 120
    if lit:
        # Pulled out: bigger (nearer), a green ring lights round its base.
        ring = K.ring(c, 160, 160, 142, 10)
        c.over(np.broadcast_to(K.lin("#5cff7a"), (320, 320, 3)), K.cover(ring) * 0.9)
        K.bloom(c, K.cover(ring), "#2aff5a", 10, 1.2)
    d = K.circle(c, 160, 156, r)
    s.shape(K.cover(d))
    rad = np.hypot(c.X - 160, c.Y - 156)
    ang = np.arctan2(c.Y - 156, c.X - 160)
    knurl = np.abs(np.sin(ang * 60)) ** 0.7 * K.smooth(r - 22, r - 14, rad)
    s.paint(K.cover(d), albedo="#eceef1", metal=1, rough=0.08, h=K.bevel(d, 30, 30, "round") + knurl * 2.5)
    insert = K.circle(c, 160, 156, r - 30)
    s.paint(K.cover(insert), albedo="#0e0e10", metal=0, rough=0.35, clear=0.6, h=24 + K.bevel(insert, 20, 6, "dome"))
    K.draw(c, s, shadow=(0, 24 if lit else 10, 18 if lit else 10, 0.65))
    col = "#bfffd0" if lit else "#e9e6df"
    P.printed(c, K.text_svg(160, 170, "NATL", 38 if lit else 36, "Michroma", fill=col), lit="#2aff5a" if lit else None, bloom_r=4, bloom_k=0.6)
    save(c, f"natl_{'on' if lit else 'off'}")


def pill():
    c = K.Canvas(300, 120)
    s = K.Surface(c)
    d = K.rrect(c, 150, 56, 284, 96, 26)
    s.shape(K.cover(d))
    s.paint(K.cover(d), albedo="#121214", metal=0, rough=0.62, spec=0.35, h=K.bevel(d, 10, 8) + P.pebble(c, 91, 4, 0.4))
    rim = K.cut(d, K.rrect(c, 150, 56, 274, 86, 21))
    s.paint(K.cover(rim), albedo="#eceef1", metal=1, rough=0.07, add_h=2)
    K.draw(c, s, shadow=(0, 6, 6, 0.5))
    save(c, "pill")


def lean():
    c = K.Canvas(900, 200)
    s = K.Surface(c)
    d = K.rrect(c, 450, 96, 860, 130, 65)
    s.shape(K.cover(d))
    s.paint(K.cover(d), albedo="#121214", metal=0, rough=0.62, spec=0.35, h=K.bevel(d, 12, 10) + P.pebble(c, 95, 5, 0.5))
    rod = K.rrect(c, 450, 96, 760, 22, 11)
    s.paint(K.cover(rod), albedo="#eceef1", metal=1, rough=0.06, h=12 + K.bevel(rod, 11, 9, "round"))
    K.draw(c, s, shadow=(0, 10, 10, 0.55))
    save(c, "lean_track")
    c = K.Canvas(200, 200)
    s = K.Surface(c)
    d = K.circle(c, 100, 100, 80)
    s.shape(K.cover(d))
    s.paint(K.cover(d), albedo="#eceef1", metal=1, rough=0.05, h=K.bevel(d, 80, 60, "dome"))
    K.draw(c, s, shadow=(0, 14, 10, 0.65))
    save(c, "lean_knob")


if __name__ == "__main__":
    housing()
    vfd_atlas()
    vfd(960, 300, "vfd")
    vfd(600, 200, "vfd_mini", r=20)
    pedals()
    pad()
    lever()
    natl_knob(False)
    natl_knob(True)
    pill()
    lean()
