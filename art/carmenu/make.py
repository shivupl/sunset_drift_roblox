"""The car picker's UI art (src/client/CarPicker), drawn at 2x and
antialiased by supersampling. White shapes the game tints with ImageColor3
and UIGradient; the stat-bar stripes are coloured. Run:

    python3 make.py

Writes out/cm_*.png. The car photos (out/car_*.png) come from key.py.
"""
import math
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

OUT = Path(__file__).parent / "out"
SS = 4  # supersampling


def save(img, name):
    img.save(OUT / f"{name}.png", optimize=True)
    print(name, img.size)


def down(big, w, h):
    return big.resize((w, h), Image.LANCZOS)


def rounded(w, h, r):
    """A white rounded rectangle mask, supersampled."""
    m = Image.new("L", (w * SS, h * SS), 0)
    ImageDraw.Draw(m).rounded_rectangle([0, 0, w * SS - 1, h * SS - 1], radius=r * SS, fill=255)
    return m


def shear(mask, deg):
    """Slants a mask to the right (top moves right), widening the canvas."""
    w, h = mask.size
    k = math.tan(math.radians(deg))
    extra = int(math.ceil(h * k))
    out = mask.transform((w + extra, h), Image.AFFINE, (1, k, -extra, 0, 1, 0), resample=Image.BICUBIC)
    return out


def white(mask, shade=None):
    """A white RGBA image with the mask as alpha; shade (h,) greys rows."""
    w, h = mask.size
    rgb = np.full((h, w, 3), 255, np.float32)
    if shade is not None:
        rgb *= shade[:, None, None]
    a = np.asarray(mask, np.float32)[..., None]
    return Image.fromarray(np.dstack([rgb, a]).clip(0, 255).astype(np.uint8), "RGBA")


def slant(name, w, h, r, deg, shaded):
    m = shear(rounded(w, h, r), deg)
    big_h = m.size[1]
    shade = None
    if shaded:
        y = np.linspace(0, 1, big_h)
        shade = np.interp(y, [0, 0.03, 0.06, 0.55, 0.9, 0.92, 1], [1.0, 1.0, 0.94, 0.84, 0.70, 0.60, 0.60])
    img = white(m, shade)
    save(down(img, m.size[0] // SS, h), name)


def chamfer(w, h, r, c):
    """Rounded rectangle with the bottom-right corner cut off, supersampled."""
    m = rounded(w, h, r)
    d = ImageDraw.Draw(m)
    W, H = w * SS, h * SS
    d.polygon([(W - c * SS, H), (W, H - c * SS), (W, H), ], fill=0)
    # Square off the cut so the rounded corner does not leave a nub.
    d.polygon([(W - c * SS - 1, H + 1), (W + 1, H - c * SS - 1), (W + 1, H + 1)], fill=0)
    return m


def ring_of(mask, t):
    """The outline of a mask, t px (at 1x of the output) thick."""
    a = np.asarray(mask) > 127
    from scipy import ndimage
    inner = ndimage.binary_erosion(a, iterations=int(t * SS))
    edge = (a & ~inner).astype(np.uint8) * 255
    return Image.fromarray(edge, "L")


def tile_art():
    w = h = 100  # 1x of the 2x art below
    for name, t in (("cm_tile", None), ("cm_tile_edge", 1.5), ("cm_tile_edge2", 2.5)):
        m = chamfer(w * 2, h * 2, 20, 30)
        if t:
            m = ring_of(m, t * 2)
        save(down(white(m), w * 2, h * 2), name)


def spot():
    n = 256
    y, x = np.mgrid[0:n, 0:n] / (n - 1) * 2 - 1
    r = np.sqrt(x * x + y * y)
    a = np.clip(1 - r, 0, 1) ** 1.6 * 255
    save(Image.fromarray(np.dstack([np.full((n, n, 3), 255), a]).astype(np.uint8), "RGBA"), "cm_spot")


def ring():
    n = 256
    m = Image.new("L", (n * SS, n * SS), 0)
    d = ImageDraw.Draw(m)
    d.ellipse([0, 0, n * SS - 1, n * SS - 1], fill=255)
    t = 28 * SS
    d.ellipse([t, t, n * SS - 1 - t, n * SS - 1 - t], fill=0)
    save(down(white(m), n, n), "cm_ring")


def dots():
    n = 18
    m = Image.new("L", (n * SS, n * SS), 0)
    c, r = n * SS / 2, 1.6 * SS
    ImageDraw.Draw(m).ellipse([c - r, c - r, c + r, c + r], fill=255)
    save(down(white(m), n, n), "cm_dots")


def star_points(n, cx, cy, ro, ri):
    pts = []
    for i in range(10):
        a = -math.pi / 2 + i * math.pi / 5
        rr = ro if i % 2 == 0 else ri
        pts.append((cx + rr * math.cos(a), cy + rr * math.sin(a)))
    return pts


def stars():
    n = 64
    S = n * SS
    pts = star_points(n, S / 2, S / 2 + 2 * SS, S * 0.46, S * 0.19)
    fill = Image.new("L", (S, S), 0)
    ImageDraw.Draw(fill).polygon(pts, fill=255)
    save(down(white(fill), n, n), "cm_star")
    line = Image.new("L", (S, S), 0)
    ImageDraw.Draw(line).line(pts + [pts[0]], fill=255, width=int(3.6 * SS), joint="curve")
    save(down(white(line), n, n), "cm_star_line")


def stripes():
    n = 16
    y, x = np.mgrid[0:n, 0:n]
    band = ((x + y) % 16) < 10
    a = np.where(band[..., None], [47, 211, 192], [26, 174, 156]).astype(np.uint8)
    save(Image.fromarray(np.dstack([a, np.full((n, n), 255, np.uint8)]), "RGBA"), "cm_stripes")


def search():
    n = 48
    S = n * SS
    m = Image.new("L", (S, S), 0)
    d = ImageDraw.Draw(m)
    w = int(5 * SS)
    d.ellipse([7 * SS, 7 * SS, 33 * SS, 33 * SS], outline=255, width=w)
    d.line([(29 * SS, 29 * SS), (42 * SS, 42 * SS)], fill=255, width=w)
    save(down(white(m), n, n), "cm_search")


def icon(name, draw):
    n = 48
    S = n * SS
    m = Image.new("L", (S, S), 0)
    draw(ImageDraw.Draw(m), SS)
    save(down(white(m), n, n), name)


def layout_icon(d, k):
    # Three panels: the three layouts the button cycles.
    w = int(3.4 * k)
    d.rounded_rectangle([6 * k, 9 * k, 21 * k, 39 * k], radius=3 * k, outline=255, width=w)
    d.rounded_rectangle([26 * k, 9 * k, 42 * k, 22 * k], radius=3 * k, outline=255, width=w)
    d.rounded_rectangle([26 * k, 27 * k, 42 * k, 39 * k], radius=3 * k, outline=255, width=w)


def plate_icon(d, k):
    # A number plate: frame, the Arabic line over the Latin one.
    w = int(3.4 * k)
    d.rounded_rectangle([4 * k, 12 * k, 44 * k, 36 * k], radius=4 * k, outline=255, width=w)
    d.line([(11 * k, 20 * k), (37 * k, 20 * k)], fill=255, width=int(3 * k))
    d.line([(11 * k, 28 * k), (30 * k, 28 * k)], fill=255, width=int(3 * k))


def gear_icon(d, k):
    c = 24 * k
    for i in range(8):
        a = i * math.pi / 4
        x, y = c + math.cos(a) * 16 * k, c + math.sin(a) * 16 * k
        d.line([(c, c), (x, y)], fill=255, width=int(7 * k))
    d.ellipse([c - 12.5 * k, c - 12.5 * k, c + 12.5 * k, c + 12.5 * k], fill=255)
    d.ellipse([c - 5 * k, c - 5 * k, c + 5 * k, c + 5 * k], fill=0)


if __name__ == "__main__":
    OUT.mkdir(exist_ok=True)
    slant("cm_tab", 120, 64, 10, 16, False)
    slant("cm_btn", 240, 104, 16, 12, True)
    tile_art()
    spot()
    ring()
    dots()
    stars()
    stripes()
    search()
    icon("cm_layout", layout_icon)
    icon("cm_plate", plate_icon)
    icon("cm_gear", gear_icon)
