#!/usr/bin/env python3
"""The render kit for the HUD art (hud-variants, 2026-10-07; the owner, on
the flat ARCADE art: "feels really ai, need deep UI").

An object is drawn as a Surface: a height map (px), and per pixel its albedo,
metalness, roughness and light it gives off. shade() lights it the way a
product shot is lit: a soft box overhead, a strip light at the left, a rim at
the right, a dark studio around, so chrome shows the room, rubber a dull
sheen, brushed aluminium a streak. Ambient occlusion darkens the creases, a
drop shadow sits it on the screen. Lighting is done in linear light and
written as sRGB.

Shapes are signed distance fields (negative inside), so edges are smooth at
any size and a bevel is a profile of the distance. Text and anything drawn
in SVG comes in through resvg (svg_alpha / svg_rgba) with the TTFs in
fonts/ttf, and can be printed, engraved or embossed like any other shape.

Every function works on numpy arrays the size of the image; nothing here
knows about pedals or gauges (art/hud/<variant>/make.py does).
"""
from __future__ import annotations

import pathlib
import re

import numpy as np
from PIL import Image
from scipy import ndimage

ROOT = pathlib.Path(__file__).resolve().parent
FONTS = ROOT / "fonts" / "ttf"
OUT = ROOT / "out"

F = np.float32


# --------------------------------------------------------------------------
# Colour
# --------------------------------------------------------------------------

def lin(hexcol: str) -> np.ndarray:
    """sRGB hex to linear RGB."""
    h = hexcol.lstrip("#")
    c = np.array([int(h[i : i + 2], 16) / 255 for i in (0, 2, 4)], F)
    return np.where(c <= 0.04045, c / 12.92, ((c + 0.055) / 1.055) ** 2.4).astype(F)


def to_srgb(c: np.ndarray) -> np.ndarray:
    c = np.clip(c, 0, 1)
    return np.where(c <= 0.0031308, c * 12.92, 1.055 * np.power(c, 1 / 2.4) - 0.055)


def smooth(e0: float, e1: float, x):
    t = np.clip((x - e0) / (e1 - e0), 0, 1)
    return t * t * (3 - 2 * t)


# --------------------------------------------------------------------------
# Canvas: the image, composited back to front (premultiplied, linear).
# --------------------------------------------------------------------------

class Canvas:
    def __init__(self, w: int, h: int):
        if w > 1024 or h > 1024:
            raise ValueError(f"{w}x{h} is over Roblox's 1024 px")
        self.w, self.h = w, h
        self.X, self.Y = np.meshgrid(np.arange(w, dtype=F) + 0.5, np.arange(h, dtype=F) + 0.5)
        self.rgb = np.zeros((h, w, 3), F)
        self.a = np.zeros((h, w), F)

    def over(self, rgb: np.ndarray, a: np.ndarray):
        """Straight rgb with coverage a, over what is there."""
        a = np.clip(a, 0, 1).astype(F)
        self.rgb = rgb * a[..., None] + self.rgb * (1 - a[..., None])
        self.a = a + self.a * (1 - a)

    def glow(self, rgb, a: np.ndarray):
        """Light added on top (a lamp's bloom): brightens what is there and,
        where nothing is, becomes a soft coloured haze."""
        a = np.clip(a, 0, 1).astype(F)
        col = np.broadcast_to(np.asarray(rgb, F), self.rgb.shape)
        self.rgb = self.rgb + col * a[..., None]
        self.a = np.clip(self.a + a * (1 - self.a), 0, 1)

    def shadow(self, a: np.ndarray, dx: float, dy: float, blur: float, opacity: float):
        """A drop shadow of coverage a, cast down and right."""
        s = ndimage.shift(a, (dy, dx), order=1, mode="constant")
        s = ndimage.gaussian_filter(s, blur) * opacity
        self.over(np.zeros((self.h, self.w, 3), F), s)

    def save(self, path: pathlib.Path | str):
        a = np.clip(self.a, 0, 1)
        rgb = np.where(a[..., None] > 1e-5, self.rgb / np.maximum(a[..., None], 1e-5), 0)
        out = np.dstack([to_srgb(rgb), a])
        Image.fromarray((out * 255 + 0.5).astype(np.uint8), "RGBA").save(path)


# --------------------------------------------------------------------------
# Shapes (signed distance, px; negative inside)
# --------------------------------------------------------------------------

def circle(c: Canvas, cx, cy, r):
    return np.hypot(c.X - cx, c.Y - cy) - r


def rrect(c: Canvas, cx, cy, w, h, r):
    r = min(r, w / 2, h / 2)
    qx = np.abs(c.X - cx) - (w / 2 - r)
    qy = np.abs(c.Y - cy) - (h / 2 - r)
    return np.hypot(np.maximum(qx, 0), np.maximum(qy, 0)) + np.minimum(np.maximum(qx, qy), 0) - r


def capsule(c: Canvas, x0, y0, x1, y1, r):
    px, py = c.X - x0, c.Y - y0
    bx, by = x1 - x0, y1 - y0
    t = np.clip((px * bx + py * by) / max(bx * bx + by * by, 1e-6), 0, 1)
    return np.hypot(px - bx * t, py - by * t) - r


def ring(c: Canvas, cx, cy, r, width):
    return np.abs(np.hypot(c.X - cx, c.Y - cy) - r) - width / 2


def union(*d):
    return np.minimum.reduce(d)


def cut(a, b):
    """a with b taken out."""
    return np.maximum(a, -b)


def inter(*d):
    return np.maximum.reduce(d)


def cover(d):
    """Anti-aliased coverage of a distance field."""
    return np.clip(0.5 - d, 0, 1).astype(F)


def from_alpha(a: np.ndarray):
    """A distance field from a coverage image (text, an SVG path)."""
    inside = a >= 0.5
    d_out = ndimage.distance_transform_edt(~inside)
    d_in = ndimage.distance_transform_edt(inside)
    return np.where(inside, 0.5 - d_in, d_out - 0.5).astype(F)


# --------------------------------------------------------------------------
# Height profiles and textures
# --------------------------------------------------------------------------

def bevel(d, width: float, height: float, profile: str = "round"):
    """Height from a distance field: rises over `width` px inside the edge to
    `height`. round: a quarter circle (a moulded edge); smooth: an S (a
    pillow); chamfer: a straight cut; cove: dips first (a lip)."""
    t = np.clip(-d / max(width, 1e-3), 0, 1)
    if profile == "round":
        p = np.sqrt(1 - (1 - t) ** 2)
    elif profile == "smooth":
        p = t * t * (3 - 2 * t)
    elif profile == "chamfer":
        p = t
    elif profile == "dome":
        p = np.sqrt(np.clip(1 - (1 - t) ** 2, 0, 1)) ** 0.6
    else:
        raise ValueError(profile)
    return (p * height).astype(F)


def rng(seed: int):
    return np.random.default_rng(seed)


def noise(c: Canvas, cell: float, seed: int, octaves: int = 4, persist: float = 0.5):
    """Smooth value noise in 0..1, features about `cell` px."""
    r = rng(seed)
    out = np.zeros((c.h, c.w), F)
    amp, total, size = 1.0, 0.0, float(cell)
    for _ in range(octaves):
        gw, gh = int(c.w / size) + 3, int(c.h / size) + 3
        g = r.random((gh, gw)).astype(F)
        img = Image.fromarray(g, "F").resize((max(1, int(gw * size)), max(1, int(gh * size))), Image.BICUBIC)
        arr = np.asarray(img, F)
        ox, oy = int(r.integers(0, max(1, arr.shape[1] - c.w))), int(r.integers(0, max(1, arr.shape[0] - c.h)))
        out += arr[oy : oy + c.h, ox : ox + c.w] * amp
        total += amp
        amp *= persist
        size = max(size / 2, 1.0)
    return (out / total).astype(F)


def grain(c: Canvas, seed: int, sigma: float = 0.6):
    """Fine per-pixel grain, mean 0, about unit spread."""
    g = rng(seed).standard_normal((c.h, c.w)).astype(F)
    if sigma > 0:
        g = ndimage.gaussian_filter(g, sigma)
        g /= max(float(g.std()), 1e-6)
    return g


def streaks(c: Canvas, seed: int, length: float = 40, angle_deg: float = 0):
    """Brushed-metal streaks along a direction, mean 0, unit spread."""
    g = rng(seed).standard_normal((c.h * 2, c.w * 2)).astype(F)
    g = ndimage.gaussian_filter(g, (0.5, length))
    if angle_deg:
        g = ndimage.rotate(g, angle_deg, reshape=False, order=1, mode="reflect")
    y0, x0 = c.h // 2, c.w // 2
    g = g[y0 : y0 + c.h, x0 : x0 + c.w]
    return (g / max(float(g.std()), 1e-6)).astype(F)


def radial_streaks(c: Canvas, cx, cy, seed: int):
    """Brushed in circles round a centre (a turned face), unit spread."""
    r = rng(seed)
    rad = np.hypot(c.X - cx, c.Y - cy)
    ang = np.arctan2(c.Y - cy, c.X - cx)
    n = int(rad.max() * 3) + 8
    line = ndimage.gaussian_filter(r.standard_normal(n).astype(F), 0.8)
    wob = noise(c, 60, seed + 1, 3) - 0.5
    idx = np.clip((rad + wob * 2.5) * 3, 0, n - 1)
    v = np.interp(idx.ravel(), np.arange(n), line).reshape(rad.shape)
    v = v + 0.25 * np.sin(ang * 3 + r.random() * 6)
    return (v / max(float(v.std()), 1e-6)).astype(F)


def ribs(coord, pitch: float, duty: float = 0.55, phase: float = 0.0):
    """Rounded ribs across an axis: 1 on a rib's crown, 0 in the groove."""
    t = ((coord / pitch + phase) % 1.0)
    d = np.abs(t - 0.5) * 2  # 0 at the rib's centre, 1 at the groove
    return np.sqrt(np.clip(1 - (d / duty) ** 2, 0, 1)).astype(F)


def knurl(c: Canvas, pitch: float, angle_deg: float = 45):
    """Diamond knurling (crossed grooves): 1 on the diamonds' tops."""
    a = np.radians(angle_deg)
    u = c.X * np.cos(a) + c.Y * np.sin(a)
    v = -c.X * np.sin(a) + c.Y * np.cos(a)
    k = np.minimum(np.abs(np.sin(np.pi * u / pitch)), np.abs(np.sin(np.pi * v / pitch)))
    return np.sqrt(k).astype(F)


def cells(c: Canvas, size: float, seed: int):
    """Worley cells (leather grain, pebbled plastic): returns F1 and F2-F1
    distances in px."""
    from scipy.spatial import cKDTree

    r = rng(seed)
    n = int(c.w * c.h / (size * size)) + 8
    pts = np.column_stack([r.random(n) * (c.w + 2 * size) - size, r.random(n) * (c.h + 2 * size) - size])
    tree = cKDTree(pts)
    q = np.column_stack([c.X.ravel(), c.Y.ravel()])
    d, _ = tree.query(q, k=2)
    f1 = d[:, 0].reshape(c.h, c.w).astype(F)
    f2 = d[:, 1].reshape(c.h, c.w).astype(F)
    return f1, f2 - f1


def carbon(c: Canvas, tow: float = 14.0):
    """2x2 twill carbon weave: a height for the tows and which way each runs
    (0 across, 1 down), for the shimmer as the light catches one set."""
    i = np.floor(c.X / tow).astype(int)
    j = np.floor(c.Y / tow).astype(int)
    over = (((i - j) % 4) < 2).astype(F)
    fx = (c.X % tow) / tow
    fy = (c.Y % tow) / tow
    h_across = np.sin(np.pi * fy)
    h_down = np.sin(np.pi * fx)
    h = np.where(over > 0.5, h_down, h_across).astype(F)
    return h, over


# --------------------------------------------------------------------------
# SVG in (text, ticks, anything easier drawn as vectors)
# --------------------------------------------------------------------------

def svg_rgba(c: Canvas, inner: str, defs: str = ""):
    """Renders SVG markup at the canvas size; straight linear rgb and alpha."""
    import resvg_py

    text = (
        f'<svg xmlns="http://www.w3.org/2000/svg" width="{c.w}" height="{c.h}" '
        f'viewBox="0 0 {c.w} {c.h}"><defs>{defs}</defs>{inner}</svg>'
    )
    data = resvg_py.svg_to_bytes(svg_string=text, font_dirs=[str(FONTS)], skip_system_fonts=True)
    import io

    im = Image.open(io.BytesIO(bytes(data))).convert("RGBA")
    arr = np.asarray(im, F) / 255
    a = arr[..., 3]
    rgb = arr[..., :3]
    rgb = np.where(rgb <= 0.04045, rgb / 12.92, ((rgb + 0.055) / 1.055) ** 2.4).astype(F)
    return rgb, a.astype(F)


def svg_alpha(c: Canvas, inner: str, defs: str = ""):
    return svg_rgba(c, inner, defs)[1]


# --------------------------------------------------------------------------
# The studio and the shading
# --------------------------------------------------------------------------

# Key light from the upper left, toward the viewer (screen y points down).
LIGHT = np.array([-0.42, -0.62, 0.66], F)
LIGHT /= np.linalg.norm(LIGHT)


def env(d: np.ndarray) -> np.ndarray:
    """Radiance of the studio seen along unit directions d (..., 3): a big
    soft box overhead, a strip light at the left, a thin rim at the right, a
    dim front fill, a dark floor. Grey (returns ...,)."""
    x, y, z = d[..., 0], d[..., 1], d[..., 2]
    up = -y
    key = smooth(0.18, 0.62, up) * np.exp(-(x + 0.15) ** 2 / 0.45) * 2.2
    strip = np.exp(-((x + 0.78) ** 2) / 0.012) * smooth(-0.55, 0.25, up) * 1.4
    rim = np.exp(-((x - 0.82) ** 2) / 0.006) * smooth(-0.2, 0.5, up) * 0.7
    front = np.clip(z, 0, 1) ** 3 * 0.16
    floor = 0.03 + 0.07 * smooth(-0.7, 0.2, up)
    return (key + strip + rim + front + floor).astype(F)


class Surface:
    """What an object is, per pixel: its shape's coverage, height, albedo
    (linear), metalness, roughness, emission (linear, added after light)."""

    def __init__(self, c: Canvas):
        self.c = c
        self.a = np.zeros((c.h, c.w), F)
        self.h = np.zeros((c.h, c.w), F)
        self.alb = np.zeros((c.h, c.w, 3), F)
        self.metal = np.zeros((c.h, c.w), F)
        self.rough = np.full((c.h, c.w), 0.5, F)
        self.emit = np.zeros((c.h, c.w, 3), F)
        self.clear = np.zeros((c.h, c.w), F)  # clear coat over paint
        self.spec = np.full((c.h, c.w), 0.5, F)  # dielectric specular level (0.5 = 4%)

    def paint(self, m, albedo=None, metal=None, rough=None, clear=None, h=None, add_h=None, emit=None, spec=None):
        """Paints a material where coverage m is (0..1): any of its albedo
        (hex or array), metalness, roughness, a height to set (h) or add
        (add_h), emission."""
        m = np.clip(np.asarray(m, F), 0, 1)
        m3 = m[..., None]
        if albedo is not None:
            col = lin(albedo) if isinstance(albedo, str) else np.asarray(albedo, F)
            self.alb = self.alb * (1 - m3) + col * m3
        if metal is not None:
            self.metal = self.metal * (1 - m) + np.asarray(metal, F) * m
        if rough is not None:
            self.rough = self.rough * (1 - m) + np.asarray(rough, F) * m
        if clear is not None:
            self.clear = self.clear * (1 - m) + np.asarray(clear, F) * m
        if spec is not None:
            self.spec = self.spec * (1 - m) + np.asarray(spec, F) * m
        if h is not None:
            self.h = self.h * (1 - m) + np.asarray(h, F) * m
        if add_h is not None:
            self.h = self.h + np.asarray(add_h, F) * m
        if emit is not None:
            col = lin(emit) if isinstance(emit, str) else np.asarray(emit, F)
            self.emit = self.emit * (1 - m3) + col * m3

    def shape(self, m):
        self.a = np.maximum(self.a, np.clip(np.asarray(m, F), 0, 1))


def normals(h: np.ndarray, scale: float = 1.0):
    gy, gx = np.gradient(h)
    n = np.dstack([-gx * scale, -gy * scale, np.ones_like(h)])
    return (n / np.linalg.norm(n, axis=2, keepdims=True)).astype(F)


def shade(s: Surface, ao: float = 1.0, ao_radius: float = 8.0, light: float = 1.0, env_gain: float = 1.0):
    """Lights a surface: returns linear rgb (straight) for its pixels."""
    n = normals(s.h)
    nz = n[..., 2]
    # Mirror direction toward the viewer (0, 0, 1).
    R = np.dstack([2 * nz * n[..., 0], 2 * nz * n[..., 1], 2 * nz * nz - 1])
    spec_env = env(R) * env_gain
    # Rough surfaces see a blurred room: blur by the mean roughness, then mix
    # in a diffuse look by each pixel's own.
    rbar = float(np.average(s.rough, weights=s.a + 1e-6))
    blurred = ndimage.gaussian_filter(spec_env, 1 + rbar * 7)
    diffuse_env = env(np.dstack([n[..., 0] * 0.5, n[..., 1] * 0.5 - 0.35, np.maximum(nz, 0.2)])) * 0.35 * env_gain
    r = s.rough
    refl = spec_env * (1 - r) ** 2 + blurred * (1 - (1 - r) ** 2) * (1 - r * 0.55) + diffuse_env * r * 0.4

    ndl = np.clip(np.einsum("ijk,k->ij", n, LIGHT), 0, 1)
    H = LIGHT + np.array([0, 0, 1], F)
    H /= np.linalg.norm(H)
    ndh = np.clip(np.einsum("ijk,k->ij", n, H), 0, 1)
    power = 2 / np.maximum(r * r, 0.002) + 2
    # Normalised Blinn-Phong: a rough surface's highlight spreads and dims.
    hi = ndh ** power * (power + 8) / (8 * np.pi) * ndl

    # Dielectrics reflect ~4% head on (s.spec 0.5), more at grazing angles.
    f0 = 0.08 * s.spec
    fres = f0 + (1 - f0) * (1 - np.clip(nz, 0, 1)) ** 5
    ambient = 0.10 + 0.08 * (-n[..., 1])
    diel = s.alb * (ambient + 0.95 * ndl * light)[..., None] + ((fres * refl * 0.9 + f0 * hi * light * 2))[..., None]
    met = s.alb * (refl + hi * light * (1 - r) + 0.05)[..., None]
    m = s.metal[..., None]
    col = diel * (1 - m) + met * m
    # Clear coat: a dielectric mirror on top of the paint.
    cc = s.clear[..., None]
    col = col + cc * (fres * spec_env * 0.9 + (ndh ** 400) * 2 * light)[..., None]

    if ao > 0:
        cav = np.clip(ndimage.gaussian_filter(s.h, ao_radius) - s.h, 0, None)
        occl = np.exp(-cav * 0.09 * ao)
        col = col * occl[..., None]
    return (col + s.emit).astype(F)


def draw(c: Canvas, s: Surface, shadow=(0, 10, 10, 0.55), **kw):
    """Shades s and puts it on the canvas over a drop shadow
    (dx, dy, blur, opacity), or none."""
    if shadow:
        c.shadow(s.a, *shadow)
    c.over(shade(s, **kw), s.a)


def bloom(c: Canvas, a: np.ndarray, colour: str, radius: float, strength: float):
    """A lamp's glow round coverage a."""
    g = ndimage.gaussian_filter(a, radius) * strength
    c.glow(lin(colour), np.clip(g, 0, 1))


def glass(c: Canvas, inside, strength: float = 1.0, seed: int = 7):
    """Glass over a dial: the soft box's reflection as a curved band across
    the top, a thin bright edge at the upper left, faint dust. inside is the
    glass's coverage."""
    y = (c.Y - c.Y.min()) / c.h
    x = (c.X - c.X.min()) / c.w
    band = smooth(0.0, 0.08, y - 0.08 - 0.12 * (x - 0.5) ** 2 * 4) * (1 - smooth(0.22, 0.42, y - 0.06 * np.sin(x * 3)))
    band = band * (0.55 + 0.45 * smooth(0.0, 0.5, 1 - x))
    dust = np.clip(noise(c, 3, seed, 2) - 0.72, 0, 1) * 0.5
    a = np.clip((band * 0.16 + dust * 0.08) * strength, 0, 1) * inside
    c.over(np.ones((c.h, c.w, 3), F) * lin("#eaf2ff"), a)


def save(c: Canvas, name: str):
    OUT.mkdir(exist_ok=True)
    p = OUT / f"{name}.png"
    c.save(p)
    return p


def text_svg(x, y, s, size, family, fill="#fff", anchor="middle", weight="normal", style="normal", spacing=0, extra=""):
    s = s.replace("&", "&amp;").replace("<", "&lt;")
    return (
        f'<text x="{x:.2f}" y="{y:.2f}" text-anchor="{anchor}" font-family="{family}" font-size="{size}" '
        f'font-weight="{weight}" font-style="{style}" letter-spacing="{spacing}" fill="{fill}" {extra}>{s}</text>'
    )
