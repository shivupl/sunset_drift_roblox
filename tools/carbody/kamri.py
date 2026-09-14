"""The Kamri: a large Japanese four-door saloon in the shape of a mid-2000s
family sedan. No real make, model or badge anywhere on it.

Real-world proportions (metres, at scale 1; the catalog scales the whole car):
  length 4.805, width 1.820 (no mirrors), height 1.470
  wheelbase 2.775, front overhang 0.965, rear overhang 1.065
  track 1.575, tyres 215/60 R16 (0.652 diameter), ground clearance ~0.16

Run from the repo root:
  python3 tools/carbody/kamri.py
Writes src/shared/CarMeshes/Kamri/ (data modules), assets/cars/kamri/*.png (textures to
upload) and assets/cars/kamri/kamri.obj (for looking at it elsewhere).
"""
from __future__ import annotations

import json
import math
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(__file__))
from meshkit import (  # noqa: E402
    Atlas,
    Chart,
    Flat,
    Surface,
    angle_uv,
    bake,
    build_piece,
    curve,
    revolve,
    smoothstep,
    write_luau,
    write_obj,
)

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT_ASSETS = os.path.join(ROOT, "assets", "cars", "kamri")
OUT_LUAU = os.path.join(ROOT, "src", "shared", "CarMeshes", "Kamri")

# ---------------------------------------------------------------------------
# Package: the numbers the rig entry must agree with
# ---------------------------------------------------------------------------

WHEELBASE = 2.775
TRACK = 1.575
TYRE_R = 0.326  # 215/60 R16
TYRE_W = 0.215
RIM_R = 0.2032  # 16 inch
Z_FRONT = -(WHEELBASE / 2 + 0.965)  # -2.3525
Z_REAR = WHEELBASE / 2 + 1.065  # 2.4525
AXLES = (-WHEELBASE / 2, WHEELBASE / 2)

ARCH_W = 0.43  # half the arch opening along the car
ARCH_TOP = 0.755  # arch crown above the ground; tyre top at full bump is ~0.74
ROCKER_Y = 0.20

Z_COWL = -0.86  # windscreen base
Z_WS_TOP = -0.07  # windscreen top / roof front header
Z_RW_TOP = 1.07  # rear window top / roof rear header
Z_DECK = 1.70  # rear window base / boot lid front
B_PILLAR = (0.22, 0.32)
REAR_DIVIDER = (1.02, 1.06)
DLO = (-0.80, 1.38)  # side glass runs between these

# ---------------------------------------------------------------------------
# Shape curves
# ---------------------------------------------------------------------------

# Half width at the shoulder along the car: rounded nose and tail in plan.
half_width = curve([
    (Z_FRONT, 0.60), (-2.335, 0.72), (-2.30, 0.80), (-2.20, 0.865), (-2.00, 0.895),
    (-1.70, 0.905), (-1.00, 0.910), (1.00, 0.910), (1.80, 0.905), (2.15, 0.890),
    (2.35, 0.855), (2.42, 0.800), (Z_REAR, 0.700),
])
# Section: width factor by height. Tucked rocker, full at the shoulder, then
# tumblehome into the glass.
width_by_height = curve([
    (0.15, 0.930), (0.22, 0.955), (0.35, 0.985), (0.55, 1.000), (0.78, 1.000),
    (0.90, 0.975), (1.00, 0.948), (1.07, 0.935),
])
# The shoulder line the side panel runs up to: the hood and fender edge at the
# front, the waist under the glass, the boot edge at the back.
belt = curve([
    (Z_FRONT, 0.700), (-2.30, 0.755), (-2.22, 0.790), (-2.00, 0.815), (-1.50, 0.870),
    (Z_COWL, 0.985), (0.30, 1.020), (1.00, 1.045), (Z_DECK, 1.065), (2.20, 1.055),
    (2.36, 1.040), (2.42, 0.990), (Z_REAR, 0.900),
])
# Centreline height of the hood and the boot lid (before crown).
top_centre = curve([
    (Z_FRONT, 0.705), (-2.30, 0.765), (-2.22, 0.805), (-2.00, 0.835), (-1.50, 0.895),
    (Z_COWL, 1.000), (Z_DECK, 1.075), (2.20, 1.070), (2.36, 1.055), (2.42, 1.000),
    (Z_REAR, 0.905),
])
HOOD_CROWN = 0.020
DECK_CROWN = 0.015
# Greenhouse: roof rail height and half width, and the roof centreline.
rail_y = curve([
    (Z_COWL, belt(Z_COWL)), (-0.60, 1.090), (-0.30, 1.235), (Z_WS_TOP, 1.360), (0.10, 1.385),
    (0.50, 1.392), (0.90, 1.375), (Z_RW_TOP, 1.355), (1.30, 1.240), (1.55, 1.120),
    (Z_DECK, belt(Z_DECK)),
])
roof_base = curve([
    (Z_COWL, top_centre(Z_COWL)), (Z_WS_TOP, 1.385), (0.40, 1.415), (Z_RW_TOP, 1.365),
    (Z_DECK, top_centre(Z_DECK)),
])
roof_crown = curve([(Z_COWL, HOOD_CROWN), (Z_WS_TOP, 0.050), (Z_RW_TOP, 0.050), (Z_DECK, DECK_CROWN)])


def shoulder_x(z, y):
    return half_width(z) * width_by_height(y)


def belt_x(z):
    return shoulder_x(z, belt(z))


rail_x = curve([
    (Z_COWL, belt_x(Z_COWL)), (-0.40, 0.780), (Z_WS_TOP, 0.705), (0.50, 0.690),
    (Z_RW_TOP, 0.695), (1.40, 0.765), (Z_DECK, belt_x(Z_DECK)),
])


def in_cabin(z):
    return Z_COWL < z < Z_DECK


def top_params(z):
    """(edge x, edge y, centre base y, crown) of the top surface at z."""
    if in_cabin(z):
        return rail_x(z), rail_y(z), roof_base(z), roof_crown(z)
    crown = HOOD_CROWN if z <= Z_COWL else DECK_CROWN
    return belt_x(z), belt(z), top_centre(z), crown


def arch_bottom(z):
    """Lower edge of the side panel: the rocker, or the wheel arch."""
    y = ROCKER_Y
    if z < -2.10:
        y = max(y, 0.20 + 0.10 * smoothstep(-2.10, Z_FRONT, z))
    if z > 1.95:
        y = max(y, 0.20 + 0.16 * smoothstep(1.95, Z_REAR, z))
    for zc in AXLES:
        d = abs(z - zc) / ARCH_W
        if d < 1:
            # Superellipse: square shouldered like a real opening.
            y = max(y, ROCKER_Y + (ARCH_TOP - ROCKER_Y) * (1 - d ** 2.6) ** (1 / 2.6))
    return y


# ---------------------------------------------------------------------------
# Stations along the car
# ---------------------------------------------------------------------------


def stations():
    zs = [Z_FRONT, -2.345, -2.335, -2.32, -2.30, -2.27, -2.22, -2.15, -2.05, -1.95]
    for zc in AXLES:
        for phi in np.linspace(-math.pi / 2, math.pi / 2, 13):
            zs.append(zc + ARCH_W * math.sin(phi) * 0.999)
        zs.append(zc - ARCH_W - 0.03)
        zs.append(zc + ARCH_W + 0.03)
    zs += [-0.93, Z_COWL, -0.83, DLO[0], -0.65, -0.48, -0.30, -0.15, Z_WS_TOP, 0.08,
           B_PILLAR[0], B_PILLAR[1], 0.50, 0.70, 0.88, REAR_DIVIDER[0], REAR_DIVIDER[1],
           Z_RW_TOP, DLO[1], 1.50, 1.66, Z_DECK, 1.735, 2.05, 2.18, 2.28, 2.36, 2.40, 2.43, Z_REAR]
    zs = sorted(set(round(z, 4) for z in zs))
    out = []
    for z in zs:
        if not out or z - out[-1] > 0.006:
            out.append(z)
    return out


SIDE_ROWS = [0.20, 0.26, 0.38, 0.52, 0.66, 0.78, 0.88, 0.95]
ACROSS = [0.0, 0.04, 0.10, 0.25, 0.50, 0.75, 1.0]  # edge -> centre
GLASS_ROWS = [0.0, 0.07, 0.93, 1.0]  # belt -> rail


def side_heights(z):
    yb, yt = arch_bottom(z), belt(z)
    ys = [yb]
    n = len(SIDE_ROWS)
    for r in range(1, n):
        y = max(SIDE_ROWS[r], ys[-1] + 0.002)
        y = min(y, yt - (n - r) * 0.002)
        ys.append(y)
    ys.append(yt)
    return ys


def top_point(z, a, side):
    ex, ey, cy, crown = top_params(z)
    sm = min(1.0, a / 0.10) ** 0.5
    return (side * ex * (1 - a), ey + (cy - ey) * sm + crown * (1 - (1 - a) ** 2), z)


# ---------------------------------------------------------------------------
# Body
# ---------------------------------------------------------------------------


def body_outward(p):
    return p - np.array([0.0, 0.70, min(max(p[2], -1.9), 2.0)])


def build_body(S: Surface):
    Z = stations()
    nz = len(Z)
    side = {}  # (sideSign) -> [col][row] vertex ids
    for s in (-1, 1):
        cols = []
        for z in Z:
            cols.append([S.vert((s * shoulder_x(z, y), y, z)) for y in side_heights(z)])
        side[s] = cols

    # Top surface across the whole length: left edge -> centre -> right edge.
    top = []
    for ci, z in enumerate(Z):
        row = []
        cab = in_cabin(z)
        for s in (-1,):
            for a in ACROSS:
                if a == 0 and not cab:
                    row.append(side[-1][ci][-1])
                else:
                    row.append(S.vert(top_point(z, a, -1)))
        for a in reversed(ACROSS[:-1]):
            if a == 0 and not cab:
                row.append(side[1][ci][-1])
            else:
                row.append(S.vert(top_point(z, a, 1)))
        top.append(row)
    centre_j = len(ACROSS) - 1

    def top_piece(i, j):
        z0, z1 = Z[i], Z[i + 1]
        zc = (z0 + z1) / 2
        a = ACROSS[j] if j < centre_j else ACROSS[2 * centre_j - j - 1]
        edge_band = a < 0.10
        if not edge_band and (-0.83 <= zc <= Z_WS_TOP or Z_RW_TOP <= zc <= 1.66):
            return "Glass"
        return "Body"

    def top_tag(i, j):
        zc = (Z[i] + Z[i + 1]) / 2
        return "roof" if in_cabin(zc) else "top"

    S.grid(top, top_piece, lambda i, j: "top", top_tag, body_outward)

    # Side panels.
    for s in (-1, 1):
        S.grid(side[s], lambda i, j: "Body", lambda i, j: "side", lambda i, j: "side", body_outward)

    # Side glass and window frame between belt and roof rail.
    for s in (-1, 1):
        cols, cabin_cols = [], []
        for ci, z in enumerate(Z):
            if not (Z_COWL <= z <= Z_DECK):
                continue
            b = side[s][ci][-1]
            r = top[ci][0] if s < 0 else top[ci][-1]
            pb, pr = S.P[b], S.P[r]
            col = [b]
            for w in GLASS_ROWS[1:-1]:
                p = pb + (pr - pb) * w
                p = p + np.array([s * 0.012 * math.sin(math.pi * w), 0, 0])
                col.append(S.vert(p))
            col.append(r)
            cols.append(col)
            cabin_cols.append(z)

        def glass_piece(i, j, zs=cabin_cols):
            zc = (zs[i] + zs[i + 1]) / 2
            if j == 1 and DLO[0] <= zc <= DLO[1] and not (B_PILLAR[0] <= zc <= B_PILLAR[1]) \
                    and not (REAR_DIVIDER[0] <= zc <= REAR_DIVIDER[1]):
                return "Glass"
            return "Body"

        def glass_tag(i, j, zs=cabin_cols):
            zc = (zs[i] + zs[i + 1]) / 2
            if B_PILLAR[0] <= zc <= B_PILLAR[1] or REAR_DIVIDER[0] <= zc <= REAR_DIVIDER[1]:
                return "pillar_black"
            if zc < DLO[0] or zc > DLO[1]:
                return "roof"  # A and C pillar in paint
            return "window_trim"

        S.grid(cols, glass_piece, lambda i, j: "side", glass_tag, body_outward)

    # End caps: ring round the last station, bulged outward.
    def cap(ci, zsign, chart):
        # The cap gets its own copies of the ring so its normals face along
        # the car instead of borrowing the sills' and the hood's, and the
        # straight bottom edge is split so no triangle spans the car.
        edge = list(side[-1][ci])  # bottom -> belt, left
        edge += top[ci][1:-1]  # across (edge verts are the belt verts outside the cabin)
        edge += list(reversed(side[1][ci]))  # belt -> bottom, right
        right_bottom, left_bottom = S.P[edge[-1]], S.P[edge[0]]
        pts = [S.P[k] for k in edge]
        for t in np.linspace(0, 1, 10)[1:-1]:
            pts.append(right_bottom + (left_bottom - right_bottom) * t)
        ring = [S.vert(p) for p in pts]
        c = np.mean(np.array(pts), axis=0)
        rings = [ring]
        for scale, bulge in ((0.72, 0.008), (0.40, 0.013)):
            rings.append([S.vert(c + (S.P[k] - c) * scale + np.array([0, 0, zsign * bulge])) for k in ring])
        centre = S.vert(c + np.array([0, 0, zsign * 0.016]))

        def out(p):
            return np.array([0, 0, zsign * 1.0]) + 0.2 * (p - c)

        n = len(ring)
        for r in range(len(rings) - 1):
            for k in range(n):
                a, b = rings[r][k], rings[r][(k + 1) % n]
                c2, d = rings[r + 1][(k + 1) % n], rings[r + 1][k]
                S.quad(a, b, c2, d, "Body", chart, chart, out)
        last = rings[-1]
        for k in range(n):
            S.tri(last[k], last[(k + 1) % n], centre, "Body", chart, chart, out)

    cap(0, -1, "front")
    cap(nz - 1, 1, "rear")

    # Underside: a strip between the rocker bottoms.
    under = [[side[-1][ci][0], side[1][ci][0]] for ci in range(nz)]
    S.grid(under, lambda i, j: "Body", lambda i, j: "flat_black", lambda i, j: "under",
           lambda p: np.array([0, -1.0, 0]))

    # Wheel wells: the arch outline swept inward, and an inner wall.
    for zc in AXLES:
        wz = [z for z in Z if abs(z - zc) < ARCH_W]
        for s in (-1, 1):
            inner_x = s * 0.50

            def out(p, zc=zc, s=s):
                return np.array([s * 1.0, 0.33, zc]) - np.array([0, p[1], p[2]]) + np.array([0, 0, 0]) \
                    - np.array([p[0] * 0.0, 0, 0])

            outer, inner = [], []
            for z in wz:
                ci = Z.index(z)
                outer.append(side[s][ci][0])
                inner.append(S.vert((inner_x, arch_bottom(z), z)))
            strip = [[outer[k], inner[k]] for k in range(len(wz))]
            S.grid(strip, lambda i, j: "Body", lambda i, j: "flat_black", lambda i, j: "well",
                   lambda p, zc=zc, s=s: np.array([s * 0.3, 0.33 - p[1], zc - p[2]]))
            base = S.vert((inner_x, ROCKER_Y, zc))
            for k in range(len(inner) - 1):
                S.tri(inner[k], inner[k + 1], base, "Body", "flat_black", "well",
                      lambda p, s=s: np.array([s * 1.0, 0, 0]))

    # Mirrors: a housing on a short arm at the front of the side glass.
    for s in (-1, 1):
        z0, y0 = -0.72, 1.005
        x0 = shoulder_x(z0, y0) - 0.01
        box = []
        for dz, dy, dx in [(-0.07, -0.05, 0.02), (0.05, -0.05, 0.02), (0.05, 0.06, 0.02), (-0.06, 0.06, 0.02),
                           (-0.08, -0.05, 0.20), (0.05, -0.04, 0.20), (0.05, 0.055, 0.20), (-0.07, 0.06, 0.20)]:
            box.append(S.vert((s * (x0 + dx), y0 + dy, z0 + dz)))
        c = np.array([s * (x0 + 0.11), y0, z0])

        def out(p, c=c):
            return p - c

        faces = [(0, 1, 2, 3), (4, 5, 6, 7), (0, 1, 5, 4), (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7)]
        for f in faces:
            chart = "flat_black" if f == (1, 2, 6, 5) else "flat_paint"
            S.quad(box[f[0]], box[f[1]], box[f[2]], box[f[3]], "Body", chart, "mirror", out)

    return Z


def build_interior(S: Surface):
    """Dark cabin behind the glass: an inner skin following the greenhouse
    (floor, door cards, headliner) facing inward, a dashboard and seats."""
    zs = [z for z in stations() if Z_COWL + 0.02 <= z <= Z_DECK - 0.02]
    cols = []
    for z in zs:
        ex, ey, cy, crown = top_params(z)
        half = [(-0.76, 0.32), (-(belt_x(z) - 0.06), belt(z) - 0.03), (-(ex - 0.05), ey - 0.05), (0.0, cy + crown - 0.06)]
        pts = half + [(-x, y) for x, y in reversed(half[:-1])]
        cols.append([S.vert((x, y, z)) for x, y in pts])

    def inward(p):
        return np.array([0.0, 0.8, p[2]]) - p

    S.grid(cols, lambda i, j: "Interior", lambda i, j: "none", lambda i, j: "interior", inward)
    n = len(cols[0])
    for ci, zsign in ((0, 1), (len(cols) - 1, -1)):
        c = S.vert((0.0, 0.75, zs[ci]))
        for k in range(n - 1):
            S.tri(cols[ci][k], cols[ci][k + 1], c, "Interior", "none", "interior",
                  lambda p, zsign=zsign: np.array([0, 0, zsign * 1.0]))
        S.tri(cols[ci][n - 1], cols[ci][0], c, "Interior", "none", "interior",
              lambda p, zsign=zsign: np.array([0, 0, zsign * 1.0]))

    def box(lo, hi):
        (x0, y0, z0), (x1, y1, z1) = lo, hi
        v = [S.vert(p) for p in [(x0, y0, z0), (x1, y0, z0), (x1, y1, z0), (x0, y1, z0),
                                 (x0, y0, z1), (x1, y0, z1), (x1, y1, z1), (x0, y1, z1)]]
        c = np.array([(x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2])
        for f in [(0, 1, 2, 3), (4, 5, 6, 7), (0, 1, 5, 4), (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7)]:
            S.quad(v[f[0]], v[f[1]], v[f[2]], v[f[3]], "Interior", "none", "interior", lambda p, c=c: p - c)

    box((-0.74, 0.72, -0.84), (0.74, 0.98, -0.52))  # dashboard
    for x in (-0.38, 0.38):  # front seats
        box((x - 0.25, 0.30, -0.10), (x + 0.25, 0.55, 0.40))
        box((x - 0.24, 0.55, 0.32), (x + 0.24, 1.10, 0.44))
        box((x - 0.12, 1.10, 0.34), (x + 0.12, 1.24, 0.42))
    box((-0.72, 0.30, 0.78), (0.72, 0.58, 1.28))  # rear bench
    box((-0.72, 0.58, 1.24), (0.72, 1.06, 1.40))


def lean(p):
    """The nose and tail are not vertical: the grille leans back toward the
    hood edge and the tail panel leans in under the boot lid."""
    x, y, z = p
    if z < -1.9:
        w = float(smoothstep(-1.9, Z_FRONT, z))
        z += 0.085 * w * float(smoothstep(0.42, 0.82, y)) - 0.012 * w * float(smoothstep(0.42, 0.20, y))
    elif z > 2.1:
        w = float(smoothstep(2.1, Z_REAR, z))
        z -= 0.06 * w * float(smoothstep(0.62, 1.05, y))
    return np.array([x, y, z])


# ---------------------------------------------------------------------------
# Body material
# ---------------------------------------------------------------------------

PAINT_BASE = np.array([0.93, 0.93, 0.93])
# Paint: a glossy metallic. Roblox has no clear coat, so the gloss is all in
# low roughness; metalness is kept moderate so a white car stays white.
PAINT_METAL = float(os.environ.get("KAMRI_PAINT_METAL", "0.45"))
PAINT_ROUGH = float(os.environ.get("KAMRI_PAINT_ROUGH", "0.15"))


def seg_dist(a, b, p0, p1):
    """Distance from points (a, b) to the segment p0-p1 in a plane."""
    ax, ay = p0
    bx, by = p1
    dx, dy = bx - ax, by - ay
    L2 = dx * dx + dy * dy
    t = np.clip(((a - ax) * dx + (b - ay) * dy) / max(L2, 1e-12), 0, 1)
    return np.hypot(a - (ax + t * dx), b - (ay + t * dy))


def poly_dist(a, b, pts):
    d = np.full(np.shape(a), 1e9)
    for k in range(len(pts) - 1):
        d = np.minimum(d, seg_dist(a, b, pts[k], pts[k + 1]))
    return d


BELT = np.vectorize(belt)
HALF_W = np.vectorize(half_width)
WBH = np.vectorize(width_by_height)
ARCH_B = np.vectorize(arch_bottom)


def body_material(P, N, tag, chart):
    k = len(P)
    x, y, z = P[:, 0], P[:, 1], P[:, 2]
    ax = np.abs(x)
    rgb = np.tile(PAINT_BASE, (k, 1))
    alpha = np.ones(k)
    metal = np.full(k, PAINT_METAL)
    rough = np.full(k, PAINT_ROUGH)

    def put(mask, col, a=0.0, m=0.0, r=0.5):
        rgb[mask] = col
        alpha[mask] = a
        metal[mask] = m
        rough[mask] = r

    flats = {
        "flat_paint": ((0.93, 0.93, 0.93), 1, PAINT_METAL, PAINT_ROUGH),
        "flat_black": ((0.025, 0.025, 0.028), 0, 0.0, 0.8),
        "flat_chrome": ((0.80, 0.80, 0.82), 0, 1.0, 0.12),
    }
    if chart in flats:
        c, a, m, r = flats[chart]
        return {"rgb": np.tile(c, (k, 1)), "alpha": np.full(k, a), "metal": np.full(k, m), "rough": np.full(k, r)}

    bl = BELT(z)
    # Ambient occlusion baked into the paint: darker low down and in the arches.
    ao = 0.80 + 0.20 * smoothstep(0.20, 0.50, y)
    arch_d = np.abs(y - ARCH_B(z))
    near_arch = np.zeros(k, dtype=bool)
    for zc in AXLES:
        near_arch |= np.abs(z - zc) < ARCH_W + 0.02
    ao = ao * np.where(near_arch & (arch_d < 0.035) & (tag == "side"), 0.72 + 8 * arch_d, 1.0)
    rgb *= ao[:, None]

    line = np.zeros(k, dtype=bool)
    LW = 0.0035
    if tag in ("side", "front", "rear"):
        # Doors: front leading edge, B line, rear door trailing edge, sill line.
        line |= (seg_dist(z, y, (-0.905, 0.26), (-0.875, 1.02)) < LW)
        line |= (seg_dist(z, y, (0.265, 0.24), (0.272, 1.03)) < LW)
        line |= (poly_dist(z, y, [(0.93, 0.24), (0.93, 0.60), (1.00, 0.80), (1.045, 1.06)]) < LW)
        line |= (seg_dist(z, y, (-0.905, 0.265), (0.93, 0.265)) < LW)
        # Bumper seams at the corners.
        line |= (poly_dist(z, y, [(-1.93, 0.30), (-1.95, 0.56), (-1.93, 0.62)]) < LW)
        line |= (poly_dist(z, y, [(2.02, 0.36), (2.08, 0.72), (2.46, 0.72)]) < LW) & (ax > 0.3)
        # Boot lid down the tail.
        line |= (np.abs(ax - 0.66) < LW) & (z > 2.40) & (y > 0.80)
        line |= (np.abs(y - 0.80) < LW) & (z > 2.40) & (ax < 0.66)
    if tag in ("top", "front"):
        hood = z < Z_COWL
        edge_x = np.vectorize(belt_x)(z) - 0.075
        line |= hood & (np.abs(ax - edge_x) < LW) & (z > -2.22)
        line |= (np.abs(z + 2.22) < LW) & (ax < edge_x)
    if tag == "top":
        line |= (np.abs(z - 1.735) < LW) & (ax < np.vectorize(belt_x)(z) - 0.09)
        line |= (z > 1.735) & (np.abs(ax - (np.vectorize(belt_x)(z) - 0.09)) < LW)
    rgb[line] = (0.05, 0.05, 0.055)
    alpha[line] = 0
    rough[line] = 0.9
    metal[line] = 0

    # Cowl panel and wiper well.
    if tag == "top":
        cowl = (z > -0.93) & (z < Z_COWL + 0.004)
        put(cowl, (0.03, 0.03, 0.035), r=0.65)

    if tag in ("window_trim",):
        put(np.ones(k, dtype=bool), (0.02, 0.02, 0.022), r=0.35)
    if tag == "pillar_black":
        put(np.ones(k, dtype=bool), (0.012, 0.012, 0.014), r=0.10, m=0.1)

    # Door handles.
    if tag == "side":
        for z0, z1 in ((-0.30, -0.15), (0.72, 0.87)):
            h = (z > z0) & (z < z1) & (y > 0.895) & (y < 0.927)
            put(h, (0.78, 0.78, 0.80), m=1.0, r=0.14)
            sh = (z > z0 + 0.01) & (z < z1 - 0.01) & (y > 0.883) & (y <= 0.895)
            rgb[sh] *= 0.35
            alpha[sh] = 0

    frontish = z < -1.88
    rearish = z > 2.15
    if tag in ("side", "front", "top"):
        # Headlamps: under the hood edge, wrapping back onto the wings.
        lamp_bottom = 0.575 + 0.17 * smoothstep(-2.18, -1.90, z) + 0.02 * smoothstep(0.4, 0.8, ax)
        lamp_top = bl - 0.014
        lamp = frontish & (y > lamp_bottom) & (y < lamp_top) & (ax > 0.40)
        edge = lamp & ((y < lamp_bottom + 0.008) | (y > lamp_top - 0.008) | (ax < 0.408))
        put(lamp, (0.28, 0.29, 0.30), m=0.9, r=0.08)
        for cx, cy, rr in ((0.575, 0.672, 0.046), (0.720, 0.688, 0.042)):
            d = np.hypot(ax - cx, y - cy)
            proj = lamp & (d < rr) & (z < -2.12)
            put(proj, (0.92, 0.93, 0.95), m=0.2, r=0.04)
            ring = lamp & (d >= rr) & (d < rr + 0.008) & (z < -2.12)
            put(ring, (0.55, 0.56, 0.58), m=1.0, r=0.1)
        amber = lamp & (z > -2.08)
        put(amber, (0.85, 0.42, 0.05), m=0.1, r=0.06)
        put(edge, (0.02, 0.02, 0.02), r=0.3)

    if tag in ("front", "side"):
        f = z < -2.24
        # Upper grille: dark slats, two chrome bars, chrome surround. No badge.
        gr = f & (ax < 0.40) & (y > 0.600) & (y < 0.690)
        put(gr, (0.025, 0.025, 0.03), r=0.4)
        bars = gr & ((np.abs(y - 0.628) < 0.006) | (np.abs(y - 0.660) < 0.006))
        put(bars, (0.82, 0.82, 0.84), m=1.0, r=0.1)
        frame = f & (ax < 0.412) & (y > 0.590) & (y < 0.700) & ~gr
        put(frame, (0.80, 0.80, 0.82), m=1.0, r=0.12)
        # Lower intake with a gloss bar through it.
        taper = 0.52 - 0.10 * smoothstep(0.30, 0.46, y)
        intake = f & (ax < taper) & (y > 0.265) & (y < 0.465)
        cell = ((np.floor(ax / 0.022) + np.floor(y / 0.019)) % 2) == 0
        put(intake & cell, (0.02, 0.02, 0.022), r=0.8)
        put(intake & ~cell, (0.045, 0.045, 0.05), r=0.7)
        put(intake & (np.abs(y - 0.365) < 0.011), (0.01, 0.01, 0.012), r=0.1)
        # Fog lamps.
        dfog = np.hypot(ax - 0.665, y - 0.365)
        put(f & (dfog < 0.075), (0.015, 0.015, 0.017), r=0.5)
        put(f & (dfog < 0.045), (0.90, 0.90, 0.88), m=0.2, r=0.05)
        # Front plate: white, thin border, abstract characters.
        plate = (z < -2.30) & (ax < 0.26) & (y > 0.49) & (y < 0.60)
        put(plate, (0.90, 0.90, 0.88), r=0.5)
        border = plate & ((ax > 0.25) | (y < 0.498) | (y > 0.592) | (ax < 0.003))
        put(border, (0.08, 0.08, 0.10), r=0.5)
        glyph = plate & (y > 0.51) & (y < 0.58) & (((ax > 0.03) & (ax < 0.06)) | ((ax > 0.09) & (ax < 0.12))
                                                    | ((ax > 0.15) & (ax < 0.18)) | ((ax > 0.20) & (ax < 0.23)))
        put(glyph & ((np.floor(y / 0.012) % 2) == 0), (0.1, 0.12, 0.2), r=0.5)
        lip = (z < -2.0) & (y < 0.245)
        put(lip, (0.03, 0.03, 0.032), r=0.7)

    if tag in ("side", "rear", "top"):
        # Tail lamps wrap round the corners under the boot line.
        tl = rearish & (y > 0.80) & (y < bl - 0.014) & (ax > 0.50)
        tl &= ~((z < 2.40) & (tag == "top"))
        put(tl, (0.52, 0.02, 0.03), m=0.2, r=0.08)
        put(tl & (np.abs(y - 0.875) < 0.010), (0.30, 0.01, 0.02), m=0.2, r=0.08)
        put(tl & (ax < 0.60) & (z > 2.40), (0.86, 0.86, 0.88), m=0.3, r=0.05)
        tedge = tl & ((y < 0.808) | (y > bl - 0.022) | ((ax < 0.508) & (z > 2.40)))
        put(tedge, (0.02, 0.02, 0.02), r=0.3)

    if tag in ("rear", "side"):
        r = z > 2.38
        put(r & (ax < 0.50) & (y > 0.842) & (y < 0.874), (0.82, 0.82, 0.84), m=1.0, r=0.1)
        rplate = r & (ax < 0.26) & (y > 0.56) & (y < 0.67)
        put(rplate, (0.90, 0.90, 0.88), r=0.5)
        put(rplate & ((ax > 0.25) | (y < 0.568) | (y > 0.662)), (0.08, 0.08, 0.10), r=0.5)
        put(rplate & (y > 0.58) & (y < 0.65) & (((ax > 0.04) & (ax < 0.07)) | ((ax > 0.11) & (ax < 0.14))
                                                  | ((ax > 0.18) & (ax < 0.21))), (0.1, 0.12, 0.2), r=0.5)
        put(r & (ax > 0.62) & (ax < 0.78) & (y > 0.44) & (y < 0.47), (0.35, 0.02, 0.02), r=0.2)
        put((z > 2.12) & (y < 0.40), (0.03, 0.03, 0.032), r=0.7)

    return {"rgb": rgb, "alpha": alpha, "metal": metal, "rough": rough}


# ---------------------------------------------------------------------------
# Wheels (wheel space, left wheel, outer face -X)
# ---------------------------------------------------------------------------

TYRE_PROFILE = [
    (0.092, 0.2032), (0.103, 0.235), (0.1075, 0.270), (0.104, 0.300), (0.094, 0.318), (0.075, 0.3255),
    (0.025, 0.326), (-0.025, 0.326),
    (-0.075, 0.3255), (-0.094, 0.318), (-0.104, 0.300), (-0.1075, 0.270), (-0.103, 0.235), (-0.092, 0.2032),
]
RIM_FACE = [(-0.050, 0.0), (-0.053, 0.030), (-0.058, 0.075), (-0.076, 0.170), (-0.089, 0.190),
            (-0.097, 0.2032), (-0.094, 0.2085)]
RIM_BARREL = [(-0.086, 0.196), (0.090, 0.196)]
ROTOR = [(0.012, 0.0), (0.012, 0.060), (0.034, 0.066), (0.034, 0.158)]
WHEEL_SEGMENTS = 28


def build_wheels(S: Surface):
    def tyre_out(p):
        r = math.hypot(p[1], p[2])
        return np.array([p[0] * 4, p[1] / max(r, 1e-6), p[2] / max(r, 1e-6)])

    t = revolve(S, TYRE_PROFILE, WHEEL_SEGMENTS)
    S.grid(t, lambda i, j: "Tyre", lambda i, j: "tyre", lambda i, j: "tyre", tyre_out)

    f = revolve(S, RIM_FACE, WHEEL_SEGMENTS)
    S.grid(f, lambda i, j: "Rim", lambda i, j: "rimface", lambda i, j: "rimface", lambda p: np.array([-1.0, 0, 0]))
    b = revolve(S, RIM_BARREL, WHEEL_SEGMENTS)
    S.grid(b, lambda i, j: "Rim", lambda i, j: "flat_barrel", lambda i, j: "barrel",
           lambda p: -np.array([0, p[1], p[2]]))
    ro = revolve(S, ROTOR, WHEEL_SEGMENTS)
    S.grid(ro, lambda i, j: "Rim", lambda i, j: "flat_rotor", lambda i, j: "rotor",
           lambda p: np.array([-1.0, 0, 0]))


TYRE_PROFILE_S = np.concatenate([[0], np.cumsum([math.dist(TYRE_PROFILE[i], TYRE_PROFILE[i + 1])
                                                 for i in range(len(TYRE_PROFILE) - 1)])])
TYRE_PROFILE_S /= TYRE_PROFILE_S[-1]


def tyre_v(p3):
    """v across the tyre from the profile position of each corner."""
    out = []
    for p in p3:
        r = math.hypot(p[1], p[2])
        d = [math.hypot(p[0] - x, r - rr) for x, rr in TYRE_PROFILE]
        out.append(TYRE_PROFILE_S[int(np.argmin(d))])
    return np.array(out)


def tyre_material(P, N, tag, chart):
    k = len(P)
    x = P[:, 0]
    r = np.hypot(P[:, 1], P[:, 2])
    th = np.arctan2(P[:, 2], P[:, 1])
    rgb = np.tile((0.055, 0.055, 0.06), (k, 1))
    rough = np.full(k, 0.92)
    tread = r > 0.316
    groove = tread & ((np.abs(x) < 0.005) | (np.abs(np.abs(x) - 0.042) < 0.005))
    sipe = tread & (np.abs(x) > 0.05) & (np.abs(((th / (2 * math.pi)) * 64) % 1 - 0.5) < 0.08)
    rgb[groove | sipe] = (0.02, 0.02, 0.022)
    band = (~tread) & (r > 0.262) & (r < 0.282)
    rgb[band] = (0.085, 0.085, 0.09)
    rough[band] = 0.8
    return {"rgb": rgb, "alpha": np.zeros(k), "metal": np.zeros(k), "rough": rough}


def rim_material(P, N, tag, chart):
    k = len(P)
    flats = {
        "flat_barrel": ((0.10, 0.10, 0.11), 1, 0.3, 0.6),
        "flat_rotor": ((0.30, 0.30, 0.31), 1, 0.8, 0.45),
    }
    if chart in flats:
        c, a, m, r = flats[chart]
        return {"rgb": np.tile(c, (k, 1)), "alpha": np.full(k, a), "metal": np.full(k, m), "rough": np.full(k, r)}
    y, z = P[:, 1], P[:, 2]
    r = np.hypot(y, z)
    th = np.arctan2(y, z)
    silver = np.array((0.74, 0.75, 0.77))
    rgb = np.tile(silver, (k, 1))
    alpha = np.ones(k)
    metal = np.full(k, 0.9)
    rough = np.full(k, 0.22)
    spokes = np.zeros(k, dtype=bool)
    rr = np.clip(r, 1e-4, None)
    half = 0.012 + 0.010 * np.clip((0.17 - r) / 0.10, 0, 1)
    for i in range(5):
        for off in (-0.13, 0.13):
            a = 2 * math.pi * i / 5 + off * (0.12 / np.clip(r, 0.08, 0.17))
            d = th - a
            along = np.cos(d)
            lateral = np.abs(rr * np.sin(d))
            spokes |= (along > 0) & (lateral < half)
    zone = (r > 0.075) & (r < 0.172)
    gap = zone & ~spokes
    alpha[gap] = 0
    rgb[gap] = (0.05, 0.05, 0.05)
    edge = zone & spokes
    for i in range(5):
        pass
    rgb[(r >= 0.172) & (r < 0.19)] = silver * 0.82
    rgb[r >= 0.195] = silver * 1.08
    rough[r >= 0.195] = 0.15
    for i in range(5):
        a = 2 * math.pi * (i + 0.5) / 5
        d = np.hypot(y - 0.05 * math.sin(a), z - 0.05 * math.cos(a))
        rgb[d < 0.010] = (0.35, 0.35, 0.37)
    rgb[(r < 0.030) & (r > 0.026)] = silver * 0.6
    return {"rgb": rgb, "alpha": alpha, "metal": metal, "rough": rough}


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------


def main():
    os.makedirs(OUT_ASSETS, exist_ok=True)
    os.makedirs(OUT_LUAU, exist_ok=True)

    S = Surface()
    build_body(S)
    S.P = [lean(p) for p in S.P]
    build_interior(S)
    n_body_faces = len(S.faces)
    build_wheels(S)

    # Anything mostly facing along the car goes to the end charts.
    P = S.P
    for f in S.faces:
        if f.chart in ("side", "top") and f.piece == "Body":
            pa, pb, pc = (P[k] for k in f.v)
            n = np.cross(pb - pa, pc - pa)
            n = n / (np.linalg.norm(n) + 1e-12)
            if abs(n[2]) > 0.72:
                f.chart = "front" if pa[2] < 0 else "rear"
                if f.tag in ("top", "side"):
                    f.tag = f.chart
    N = S.normals()

    # Body atlas.
    body = Atlas("body", 1024, 1024)
    body.add(Chart("side", lambda p: (p[2], p[1]), -2.37, 2.47, 0.17, 1.50, 18, 8, 205))
    body.add(Chart("top", lambda p: (p[2], abs(p[0])), -2.37, 2.47, 0.0, 0.93, 18, 296, 205, flipB=False))
    body.add(Chart("front", lambda p: (abs(p[0]), p[1]), 0.0, 0.93, 0.17, 1.05, 18, 504, 360))
    body.add(Chart("rear", lambda p: (abs(p[0]), p[1]), 0.0, 0.93, 0.17, 1.05, 370, 504, 360))
    for i, name in enumerate(("flat_paint", "flat_black", "flat_chrome")):
        body.add(Flat(name, 740 + 16 * i, 504))

    tyre_atlas_size = (1024, 256)
    rim = Atlas("rim", 512, 512)
    rim.add(Chart("rimface", lambda p: (p[2], p[1]), -0.212, 0.212, -0.212, 0.212, 16, 16, 480 / 0.424))
    rim.add(Flat("flat_barrel", 2, 2))
    rim.add(Flat("flat_rotor", 502, 2))

    def uv_body(f):
        if f.piece in ("Glass", "Interior"):
            return np.zeros((3, 2))
        return np.array([body.uv_of(f.chart, P[k]) for k in f.v])

    def uv_tyre(f):
        p3 = np.array([P[k] for k in f.v])
        u = angle_uv(p3)
        v = tyre_v(p3)
        return np.stack([u, v], axis=1)

    def uv_rim(f):
        return np.array([rim.uv_of(f.chart, P[k]) for k in f.v])

    groups = {}
    for f in S.faces:
        groups.setdefault(f.piece, []).append(f)
    uv_fn = {"Body": uv_body, "Glass": uv_body, "Interior": uv_body, "Tyre": uv_tyre, "Rim": uv_rim}
    pieces = {name: build_piece(name, P, N, fs, uv_fn[name]) for name, fs in groups.items()}

    # Bake.
    def face_list(name, uvf):
        out = []
        for f in groups[name]:
            out.append((uvf(f), np.array([P[k] for k in f.v]), np.array([N[k] for k in f.v]), f.tag, f.chart))
        return out

    maps, overlap = bake(body, face_list("Body", uv_body), body_material)
    for key, img in maps.items():
        img.save(os.path.join(OUT_ASSETS, f"kamri_body_{key}.png"))
    tyre = Atlas("tyre", *tyre_atlas_size)
    tmaps, _ = bake(tyre, face_list("Tyre", uv_tyre), tyre_material)
    tmaps["color"] = tmaps["color"].convert("RGB")
    for key, img in tmaps.items():
        img.save(os.path.join(OUT_ASSETS, f"kamri_tyre_{key}.png"))
    rmaps, _ = bake(rim, face_list("Rim", uv_rim), rim_material)
    for key, img in rmaps.items():
        img.save(os.path.join(OUT_ASSETS, f"kamri_rim_{key}.png"))

    order = ["Body", "Glass", "Interior", "Tyre", "Rim"]
    plist = [pieces[n] for n in order]
    total = sum(p.triangles for p in plist)
    per_car = sum(pieces[n].triangles for n in ("Body", "Glass", "Interior")) + 4 * (
        pieces["Tyre"].triangles + pieces["Rim"].triangles)
    header = [
        "The Kamri: a large Japanese four-door saloon, mid-2000s shape, no badge.",
        "Triangles: " + ", ".join(f"{p.name} {p.triangles}" for p in plist)
        + f"; {per_car} for the whole car with four wheels.",
    ]
    write_luau(OUT_LUAU, "Kamri", header, plist)
    write_obj(os.path.join(OUT_ASSETS, "kamri.obj"), plist)
    # One file per piece, centred on its bounding box like the data modules,
    # for Studio's 3D Importer: the imported MeshPart's mesh id can then go on
    # the catalog piece as meshId and no EditableMesh is needed.
    for p in plist:
        write_obj(os.path.join(OUT_ASSETS, f"Kamri_{p.name}.obj"), [p], offsets=False)
    summary = {p.name: {"triangles": p.triangles, "sizeM": [round(v, 4) for v in p.size],
                        "offsetM": [round(v, 4) for v in p.offset]} for p in plist}
    summary["car_triangles"] = per_car
    summary["body_texel_overlaps"] = overlap
    with open(os.path.join(OUT_ASSETS, "summary.json"), "w") as fh:
        json.dump(summary, fh, indent=2)
    print(json.dumps(summary, indent=2))


if __name__ == "__main__":
    main()
