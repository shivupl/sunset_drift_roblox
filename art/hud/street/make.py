#!/usr/bin/env python3
"""STREET's art (hud-variants, 2026-10-07): ARCADE's layout as a street
drift car. After Initial D Arcade Stage (a white-face tacho with a red
needle, the speed and gear in big italic digits beside it) and CarX Street
(a real tacho with a rolling odometer): an aftermarket white-face tacho in
a knurled black bezel, a peak-hold needle, a shift light on the bezel, a
mechanical odometer, a small tyre-temperature gauge, a red LED drift board.
Controls are drift-car hardware: drilled aluminium pedals with rubber
strips, a machined thumb pad, a hydraulic handbrake grip, a missile switch
for the natl.

  tacho_*        0..9000 r/min over FROM..TO degrees; drums in the window
  needle_shadow  the needle's soft shadow (the HUD offsets it, so the
                 shadow stays down-right whichever way the needle points)
  shift_*        the shift light, off and lit
  drum_*         odometer drum strips (0..9,0), the tenths drum, the shade
  speed, gear    big italic digits (SPEED_CHARS in 80x150 cells, GEAR_CHARS in 112x160)
  tyre_*         the small gauge: 40..140 C over -120..120 degrees
  dots, board, mini   red LED characters and the boards they light on
  pedal_*, pad_*, lever_*, natl_*, pill, lean_*   the controls
"""
import pathlib
import sys

HERE = pathlib.Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent))

import numpy as np  # noqa: E402
from scipy import ndimage  # noqa: E402

import kit as K  # noqa: E402
import parts as P  # noqa: E402

INK = "#121212"
RED = "#e3221a"
PAPER = "#f1efe7"
LED = "#ff3220"
LED_GLOW = "#ff1608"
LED_DIM = "#1d0805"
FROM, TO, MAX, RED_FROM = -135, 135, 9000, 7000

T = 768
TC = T / 2
DRUMS = (264, 520, 240, 54)  # x, y, w, h: seven drums, the last tenths
SHIFT = (600, 128, 150)  # the shift light's centre x, y and size over the tacho, px of 768

SPEED_CHARS = "0123456789"
GEAR_CHARS = "123456RN"


def save(c, n):
    p = K.save(c, f"street_{n}")
    print(p.name, c.w, "x", c.h)


def needle_pair(size, cx, cy, length, tail, base_w, tip_w, colour, name, hub=None):
    """The needle, painted (no glow, a daylight face), and its shadow."""
    c = K.Canvas(size, size)
    a = P.needle(c, cx, cy, length, tail, base_w, tip_w, colour, shadow=False, body_rough=0.3)
    save(c, name)
    sh = K.Canvas(size, size)
    blur = ndimage.gaussian_filter(a, size / 150)
    sh.over(np.zeros((size, size, 3), np.float32), blur * 0.5)
    save(sh, name + "_shadow")


# --------------------------------------------------------------------------
# The tacho
# --------------------------------------------------------------------------

def tacho():
    c = K.Canvas(T, T)
    s = K.Surface(c)
    fr = P.knurl_bezel(c, s, TC, TC, 376, 34, chrome_w=8)
    P.face(c, s, TC, TC, fr, base="#d8d5cb", centre=PAPER, rough=0.7, spec=0.3, seed=21, texture=0.08)
    # The odometer's window: a black slot with a chrome lip.
    x, y, w, h = DRUMS
    lip = K.rrect(c, x + w / 2, y + h / 2, w + 18, h + 18, 10)
    s.paint(K.cover(lip), albedo="#e9ebee", metal=1, rough=0.1, h=1.5 + K.bevel(lip, 4, 2))
    win = K.rrect(c, x + w / 2, y + h / 2, w + 4, h + 4, 5)
    s.paint(K.cover(win), albedo="#050505", metal=0, rough=0.5, h=-3)
    K.draw(c, s, shadow=(0, 12, 14, 0.6), ao_radius=12)

    num = lambda v: str(int(v // 1000))  # noqa: E731
    ticks = P.scale_svg(TC, TC, d0=FROM, d1=TO, vmax=MAX, major=1000, minor=250, mid_len=27, r_out=322,
                        major_len=40, minor_len=15, major_w=8, minor_w=3.2, colour=INK, red_from=RED_FROM, red=RED,
                        numerals=num, num_r=246, num_size=88, family="Barlow Condensed", weight="bold",
                        style="italic", red_band=(330, 12))
    labels = (
        K.text_svg(TC, 236, "x1000", 30, "Barlow Condensed", fill=INK, weight="bold", style="italic")
        + K.text_svg(TC, 264, "r/min", 24, "Barlow Condensed", fill=INK, weight="bold", style="italic")
        + K.text_svg(x + w + 14, y + h - 12, "km", 24, "Barlow Condensed", fill=INK, weight="bold", anchor="start")
        + K.text_svg(TC, y + h + 52, "SHIFT", 22, "Barlow Condensed", fill=RED, weight="bold", spacing=4)
    )
    P.printed(c, ticks + labels)
    save(c, "tacho_face")

    needle_pair(T, TC, TC, 318, 70, 16, 5, RED, "needle")
    # The peak needle: thin, translucent orange, it stays at the top reading.
    c = K.Canvas(T, T)
    pk = K.svg_alpha(c, f'<polygon points="{TC - 3},{TC} {TC - 1.5},{TC - 300} {TC + 1.5},{TC - 300} {TC + 3},{TC}" fill="#fff"/>')
    c.over(np.broadcast_to(K.lin("#ff8a1a"), (T, T, 3)), pk * 0.75)
    save(c, "peak")

    c = K.Canvas(T, T)
    P.dial_glass(c, TC, TC, fr + 2, strength=1.25)
    P.cap(c, TC, TC, 44, ring_w=7, body="#141518")
    save(c, "tacho_glass")


def shift_light():
    for lit in (False, True):
        c = K.Canvas(160, 160)
        s = K.Surface(c)
        body = K.circle(c, 80, 80, 66)
        s.shape(K.cover(body))
        s.paint(K.cover(body), albedo="#16171a", metal=1, rough=0.35, h=K.bevel(body, 14, 12))
        ring = K.ring(c, 80, 80, 50, 8)
        s.paint(K.cover(ring), albedo="#eceef1", metal=1, rough=0.06, add_h=4 + K.bevel(ring, 4, 3))
        lens = K.circle(c, 80, 80, 44)
        lens_col = "#ff2a12" if lit else "#3a0805"
        s.paint(K.cover(lens), albedo=lens_col, metal=0, rough=0.08, clear=1, h=14 + K.bevel(lens, 30, 16, "dome"),
                emit=(K.lin("#ff3a1a") * 1.4 if lit else None))
        # Faceted lens: a grid of small domes.
        facets = (np.abs(np.sin(c.X / 5.2)) * np.abs(np.sin(c.Y / 5.2))) * 1.4
        s.paint(K.cover(lens + 4), add_h=facets)
        K.draw(c, s, shadow=(0, 6, 6, 0.6), ao=0.5)
        if lit:
            K.bloom(c, K.cover(lens), "#ff2008", 14, 1.4)
        save(c, f"shift_{'on' if lit else 'off'}")


def drums():
    c = P.drum_strip(48, 72, 54, ink="#f4f2ec", paper="#0d0d0e")
    save(c, "drum")
    c = P.drum_strip(48, 72, 54, ink="#f4f2ec", paper="#b3150e", seed=4)
    save(c, "drum_tenths")
    c = P.drum_shade(48, 72)
    save(c, "drum_shade")


def italic_atlas(chars, cell_w, cell_h, size, name, fill, defs=""):
    c = K.Canvas(cell_w * len(chars), cell_h)
    parts = []
    for i, ch in enumerate(chars):
        x = i * cell_w + cell_w / 2 - size * 0.03
        y = cell_h / 2 + size * 0.36
        t = K.text_svg(x, y, ch, size, "Barlow Condensed", fill=fill, weight="bold", style="italic",
                       extra='stroke="#0b0b0c" stroke-width="12" stroke-linejoin="round" paint-order="stroke"')
        parts.append(t)
    rgb, a = K.svg_rgba(c, "".join(parts), defs)
    c.shadow(a, 4, 7, 4, 0.55)
    c.over(rgb, a)
    save(c, name)


def readouts():
    italic_atlas(SPEED_CHARS, 80, 150, 150, "speed", "#fbfaf6")
    grad = ('<linearGradient id="g" x1="0" y1="0" x2="0" y2="1">'
            '<stop offset="0" stop-color="#ffe066"/><stop offset="0.55" stop-color="#ff9a1a"/>'
            '<stop offset="1" stop-color="#e3221a"/></linearGradient>')
    italic_atlas(GEAR_CHARS, 112, 160, 160, "gear", "url(#g)", grad)
    c = K.Canvas(220, 80)
    t = K.text_svg(110, 58, "km/h", 56, "Barlow Condensed", fill="#fbfaf6", weight="bold", style="italic",
                   extra='stroke="#0b0b0c" stroke-width="9" stroke-linejoin="round" paint-order="stroke"')
    rgb, a = K.svg_rgba(c, t)
    c.shadow(a, 3, 5, 3, 0.55)
    c.over(rgb, a)
    save(c, "kmh")


# --------------------------------------------------------------------------
# The tyre gauge
# --------------------------------------------------------------------------

S = 320
SC = S / 2


def tyre_gauge():
    c = K.Canvas(S, S)
    s = K.Surface(c)
    fr = P.knurl_bezel(c, s, SC, SC, 154, 18, chrome_w=5, pitch=6)
    P.face(c, s, SC, SC, fr, base="#d8d5cb", centre=PAPER, rough=0.7, spec=0.3, seed=31, texture=0.08)
    K.draw(c, s, shadow=(0, 10, 10, 0.65), ao_radius=8)
    ticks = P.scale_svg(SC, SC, d0=-120, d1=120, vmax=100, major=20, minor=5, mid_len=None, r_out=fr - 10,
                        major_len=20, minor_len=9, major_w=5, minor_w=2.2, colour=INK, red_from=80, red=RED,
                        numerals=lambda v: str(int(v + 40)) if int(v) % 40 == 0 else None, num_r=fr - 48,
                        num_size=34, style="italic", red_band=(fr - 6, 6))
    labels = (K.text_svg(SC, SC + 62, "TYRE", 26, "Barlow Condensed", fill=INK, weight="bold", style="italic", spacing=2)
              + K.text_svg(SC, SC + 88, "°C", 22, "Barlow Condensed", fill=INK, weight="bold"))
    P.printed(c, ticks + labels)
    save(c, "tyre_face")
    needle_pair(S, SC, SC, 118, 26, 9, 3, RED, "pod_needle")
    c = K.Canvas(S, S)
    P.dial_glass(c, SC, SC, fr + 1, strength=1.3, seed=5)
    P.cap(c, SC, SC, 20, ring_w=4, body="#141518")
    save(c, "pod_glass")


# --------------------------------------------------------------------------
# The LED boards
# --------------------------------------------------------------------------

def leds():
    c, (cw, ch, cols) = P.dot_atlas(16, LED, LED_DIM, cols=10, glow=LED_GLOW, glow_k=0.8)
    save(c, "dots")


def board(w, h, name, r=22):
    """Black anodised aluminium round a matte panel, a hex screw in each
    corner, an acrylic sheen."""
    c = K.Canvas(w, h)
    s = K.Surface(c)
    outer = K.rrect(c, w / 2, h / 2 - 4, w - 14, h - 20, r)
    s.shape(K.cover(outer))
    s.paint(K.cover(outer), albedo="#1a1b1e", metal=1, rough=0.34, h=K.bevel(outer, 8, 7) + K.streaks(c, 41, 80, 0) * 0.08)
    inner = K.rrect(c, w / 2, h / 2 - 4, w - 50, h - 52, r - 10)
    s.paint(K.cover(inner), albedo="#040404", metal=0, rough=0.6, spec=0.2, h=2)
    for sx in (-1, 1):
        for sy in (-1, 1):
            P.hex_screw(s, c, w / 2 + sx * (w / 2 - 22), h / 2 - 4 + sy * (h / 2 - 22), 7)
    K.draw(c, s, shadow=(0, 8, 10, 0.5))
    c.a = c.a * (1 - 0.1 * K.cover(inner))
    sheen = K.smooth(h * 0.5, 20, c.Y) * K.cover(inner) * 0.06
    c.over(np.broadcast_to(K.lin("#ffffff"), (h, w, 3)), sheen)
    save(c, name)


# --------------------------------------------------------------------------
# Controls
# --------------------------------------------------------------------------

def pedals():
    slots = [(200, 170 + i * 150, 64, 112) for i in range(5)]
    strips = [(112, 470, 52, 760), (288, 470, 52, 760)]
    c = P.drilled_pedal(400, 1000, plate_w=320, plate_h=920, radius=44, slots=slots, strips=strips, seed=51)
    save(c, "pedal_gas")
    slots = [(120 + i * 80, 250, 52, 150) for i in range(5)]
    strips = [(280, 104, 430, 46), (280, 396, 430, 46)]
    c = P.drilled_pedal(560, 520, plate_w=500, plate_h=440, radius=44, slots=slots, strips=strips, seed=53, brush_angle=0)
    save(c, "pedal_brake")


def pad():
    c = K.Canvas(640, 640)
    s = K.Surface(c)
    d = K.circle(c, 320, 320, 300)
    s.shape(K.cover(d))
    rad = np.hypot(c.X - 320, c.Y - 320)
    ang = np.arctan2(c.Y - 320, c.X - 320)
    knurl = np.abs(np.sin(ang * 120)) ** 0.7 * K.smooth(272, 280, rad)
    turned = K.radial_streaks(c, 320, 320, 61) * 0.12
    grooves = K.ribs(rad, 26, 0.85) * 0.8 * K.smooth(240, 230, rad)
    h = K.bevel(d, 30, 26, "round") + knurl * 2.4 + turned + grooves
    s.paint(K.cover(d), albedo="#c6cacf", metal=1, rough=0.22, h=h)
    # Engraved arrows, filled black.
    arr = "".join(f'<path d="M{320 + sx * 236} 320 L{320 + sx * 196} 286 L{320 + sx * 196} 354 Z" fill="#fff"/>' for sx in (-1, 1))
    a = K.svg_alpha(c, arr)
    s.paint(a, albedo="#0c0c0d", metal=0, rough=0.6, add_h=-2)
    K.draw(c, s, shadow=(0, 14, 16, 0.6))
    save(c, "pad_base")

    c = K.Canvas(300, 300)
    s = K.Surface(c)
    d = K.circle(c, 150, 150, 132)
    s.shape(K.cover(d))
    s.paint(K.cover(d), albedo="#141416", metal=0, rough=0.42, h=K.bevel(d, 100, 34, "dome") + K.grain(c, 63, 0.8) * 0.06)
    ring = K.ring(c, 150, 150, 70, 22)
    s.paint(K.cover(ring), albedo="#c41a12", metal=1, rough=0.3, add_h=3 + K.bevel(ring, 6, 4))
    s.paint(K.cover(K.circle(c, 150, 150, 48)), albedo="#18181a", metal=0, rough=0.35, add_h=-3)
    K.draw(c, s, shadow=(0, 16, 14, 0.65))
    save(c, "pad_knob")


def lever():
    c = K.Canvas(220, 640)
    s = K.Surface(c)
    plate = K.rrect(c, 110, 316, 170, 600, 30)
    s.shape(K.cover(plate))
    s.paint(K.cover(plate), albedo="#1a1b1e", metal=1, rough=0.36, h=K.bevel(plate, 8, 7) + K.streaks(c, 71, 80, 90) * 0.08)
    slot = K.rrect(c, 110, 316, 46, 500, 23)
    s.paint(K.cover(slot), albedo="#030303", metal=0, rough=0.5, h=-8 + K.bevel(slot, 4, 3))
    for y in (46, 586):
        for x in (60, 160):
            P.hex_screw(s, c, x, y, 11)
    K.draw(c, s, shadow=(0, 10, 12, 0.55))
    save(c, "lever_track")

    c = K.Canvas(360, 260)
    s = K.Surface(c)
    bar = K.rrect(c, 180, 130, 300, 96, 48)
    s.shape(K.cover(bar))
    kn = K.knurl(c, 7)
    s.paint(K.cover(bar), albedo="#c6cacf", metal=1, rough=0.24, h=K.bevel(bar, 48, 30, "round") + kn * 1.6 * K.cover(K.rrect(c, 180, 130, 170, 120, 4)))
    for sx in (-1, 1):
        cap_d = K.rrect(c, 180 + sx * 126, 130, 50, 100, 22)
        s.paint(K.cover(cap_d), albedo="#c01a12", metal=1, rough=0.28, h=4 + K.bevel(cap_d, 24, 30, "round"))
    K.draw(c, s, shadow=(0, 16, 14, 0.6))
    save(c, "lever_handle")


def natl_switch(lit):
    c = K.Canvas(320, 320)
    s = K.Surface(c)
    plate = K.rrect(c, 160, 158, 290, 290, 26)
    s.shape(K.cover(plate))
    s.paint(K.cover(plate), albedo="#18191c", metal=1, rough=0.36, h=K.bevel(plate, 8, 7) + K.streaks(c, 81, 70, 0) * 0.08)
    for x in (34, 286):
        for y in (32, 284):
            P.hex_screw(s, c, x, y, 9)
    # The toggle's nut and (when on) its bat handle; the LED.
    nut = K.circle(c, 160, 150, 36)
    s.paint(K.cover(nut), albedo="#d2d5da", metal=1, rough=0.2, h=6 + K.bevel(nut, 12, 7))
    led = K.circle(c, 160, 254, 12)
    s.paint(K.cover(led), albedo="#ff2a12" if lit else "#3a0a06", metal=0, rough=0.1, clear=1,
            h=4 + K.bevel(led, 10, 6, "dome"), emit=(K.lin("#ff3a1a") * 1.3 if lit else None))
    if lit:
        bat = K.capsule(c, 160, 150, 160, 80, 14)
        s.paint(K.cover(bat), albedo="#e9ebee", metal=1, rough=0.08, h=18 + K.bevel(bat, 14, 12, "round"))
        # The cover, flipped up over its hinge: seen end-on, short.
        cov = K.rrect(c, 160, 34, 176, 38, 12)
        s.paint(K.cover(cov), albedo="#c8160c", metal=0, rough=0.18, clear=1, h=22 + K.bevel(cov, 14, 10))
    else:
        cov = K.rrect(c, 160, 142, 176, 184, 26)
        ridge = K.ribs(c.Y, 13, 0.6) * K.cover(K.rrect(c, 160, 204, 140, 40, 8))
        s.paint(K.cover(cov), albedo="#d01a0e", metal=0, rough=0.18, clear=1, h=16 + K.bevel(cov, 30, 16, "round") + ridge * 2)
    hinge = K.rrect(c, 160, 54, 190, 24, 12)
    s.paint(K.cover(hinge), albedo="#d2d5da", metal=1, rough=0.15, h=18 + K.bevel(hinge, 12, 9, "round"))
    K.draw(c, s, shadow=(0, 12, 12, 0.6))
    if lit:
        K.bloom(c, K.cover(led), "#ff2008", 10, 1.3)
    P.printed(c, K.text_svg(160, 294, "NATL", 30, "Barlow Condensed", fill="#e9e6df", weight="bold", spacing=5))
    save(c, f"natl_{'on' if lit else 'off'}")


def pill():
    c = K.Canvas(300, 120)
    s = K.Surface(c)
    d = K.rrect(c, 150, 56, 284, 96, 14)
    s.shape(K.cover(d))
    s.paint(K.cover(d), albedo="#1a1b1e", metal=1, rough=0.36, h=K.bevel(d, 7, 6) + K.streaks(c, 91, 60, 0) * 0.08)
    for x in (22, 278):
        P.hex_screw(s, c, x, 56, 7)
    K.draw(c, s, shadow=(0, 6, 6, 0.5))
    save(c, "pill")


def lean():
    c = K.Canvas(900, 200)
    s = K.Surface(c)
    d = K.rrect(c, 450, 96, 860, 140, 22)
    s.shape(K.cover(d))
    s.paint(K.cover(d), albedo="#c3c7cc", metal=1, rough=0.26, h=K.bevel(d, 9, 9) + K.streaks(c, 95, 90, 0) * 0.1)
    slot = K.rrect(c, 450, 96, 740, 34, 17)
    s.paint(K.cover(slot), albedo="#050505", metal=0, rough=0.5, h=-8 + K.bevel(slot, 3, 3))
    for x in (40, 860):
        P.hex_screw(s, c, x, 96, 12)
    K.draw(c, s, shadow=(0, 10, 10, 0.55))
    save(c, "lean_track")
    c = K.Canvas(200, 200)
    s = K.Surface(c)
    d = K.circle(c, 100, 100, 84)
    s.shape(K.cover(d))
    s.paint(K.cover(d), albedo="#c41a12", metal=1, rough=0.28, h=K.bevel(d, 60, 24, "dome") + K.radial_streaks(c, 100, 100, 97) * 0.08)
    K.draw(c, s, shadow=(0, 12, 10, 0.65))
    save(c, "lean_knob")


if __name__ == "__main__":
    tacho()
    shift_light()
    drums()
    readouts()
    tyre_gauge()
    leds()
    board(960, 300, "board")
    board(600, 200, "mini", r=18)
    pedals()
    pad()
    lever()
    natl_switch(False)
    natl_switch(True)
    pill()
    lean()
    print("layout (px of 768):", dict(drums=DRUMS, shift=SHIFT))
