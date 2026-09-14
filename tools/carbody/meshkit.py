"""Low-poly car body toolkit: build a surface out of shared-vertex patches,
split it into pieces, lay UVs out in projected charts, bake procedural
materials into texture atlases, and write the result as a Luau data module
that the game turns into EditableMeshes (see RIG_SPEC.md section 7).

Car space throughout: metres, +X right, +Y up, -Z forward, origin on the
ground under the wheelbase centre with the car at rest.

Nothing here knows about a particular car; see kamri.py for one.
"""
from __future__ import annotations

import base64
import math
import os
import struct
from dataclasses import dataclass, field

import numpy as np
from PIL import Image

# ---------------------------------------------------------------------------
# Curves
# ---------------------------------------------------------------------------


def curve(keys):
    """Monotone cubic (PCHIP) through (x, y) keys; flat beyond the ends."""
    xs = np.array([k[0] for k in keys], dtype=float)
    ys = np.array([k[1] for k in keys], dtype=float)
    n = len(xs)
    h = np.diff(xs)
    d = np.diff(ys) / h
    m = np.zeros(n)
    if n == 2:
        m[:] = d[0]
    else:
        for i in range(1, n - 1):
            if d[i - 1] * d[i] <= 0:
                m[i] = 0
            else:
                w1 = 2 * h[i] + h[i - 1]
                w2 = h[i] + 2 * h[i - 1]
                m[i] = (w1 + w2) / (w1 / d[i - 1] + w2 / d[i])
        m[0] = d[0]
        m[-1] = d[-1]

    def f(x):
        x = float(x)
        if x <= xs[0]:
            return float(ys[0])
        if x >= xs[-1]:
            return float(ys[-1])
        i = int(np.searchsorted(xs, x) - 1)
        i = max(0, min(n - 2, i))
        t = (x - xs[i]) / h[i]
        t2, t3 = t * t, t * t * t
        return float(
            (2 * t3 - 3 * t2 + 1) * ys[i]
            + (t3 - 2 * t2 + t) * h[i] * m[i]
            + (-2 * t3 + 3 * t2) * ys[i + 1]
            + (t3 - t2) * h[i] * m[i + 1]
        )

    return f


def lerp(a, b, t):
    return a + (b - a) * t


def smoothstep(e0, e1, x):
    t = np.clip((x - e0) / (e1 - e0), 0.0, 1.0)
    return t * t * (3 - 2 * t)


# ---------------------------------------------------------------------------
# Surface
# ---------------------------------------------------------------------------


@dataclass
class Face:
    v: tuple  # three vertex indices, counter-clockwise seen from outside
    piece: str  # which MeshPart it ends up in
    chart: str  # which UV chart (or flat patch) it is laid out in
    tag: str  # free label handed to the material function


class Surface:
    """Shared vertices so normals smooth across patch seams."""

    def __init__(self):
        self.P: list = []
        self.faces: list[Face] = []
        self.hard: set = set()  # vertex indices that keep per-face normals

    def vert(self, p) -> int:
        self.P.append(np.asarray(p, dtype=float))
        return len(self.P) - 1

    def tri(self, a, b, c, piece, chart, tag, outward=None):
        pa, pb, pc = self.P[a], self.P[b], self.P[c]
        n = np.cross(pb - pa, pc - pa)
        area = np.linalg.norm(n)
        if area < 1e-9:
            return
        if outward is not None:
            centre = (pa + pb + pc) / 3
            if np.dot(n, outward(centre)) < 0:
                b, c = c, b
        self.faces.append(Face((a, b, c), piece, chart, tag))

    def quad(self, a, b, c, d, piece, chart, tag, outward=None):
        self.tri(a, b, c, piece, chart, tag, outward)
        self.tri(a, c, d, piece, chart, tag, outward)

    def grid(self, idx, piece_of, chart_of, tag_of, outward):
        """idx[i][j] vertex indices; quads between (i,j) (i+1,j) (i+1,j+1) (i,j+1)."""
        for i in range(len(idx) - 1):
            for j in range(len(idx[i]) - 1):
                a, b, c, d = idx[i][j], idx[i + 1][j], idx[i + 1][j + 1], idx[i][j + 1]
                piece = piece_of(i, j)
                if piece is None:
                    continue
                self.quad(a, b, c, d, piece, chart_of(i, j), tag_of(i, j), outward)

    def normals(self):
        acc = np.zeros((len(self.P), 3))
        for f in self.faces:
            pa, pb, pc = (self.P[k] for k in f.v)
            n = np.cross(pb - pa, pc - pa)  # area weighted
            for k in f.v:
                acc[k] += n
        ln = np.linalg.norm(acc, axis=1, keepdims=True)
        ln[ln == 0] = 1
        return acc / ln


# ---------------------------------------------------------------------------
# Charts and atlases
# ---------------------------------------------------------------------------


@dataclass
class Chart:
    """A planar projection of some faces into a rectangle of an atlas.

    project(p) -> (a, b) in metres; the rectangle [a0,a1] x [b0,b1] lands at
    atlas pixel (x, y) with `ppm` pixels per metre. flipB puts b0 at the
    bottom of the rectangle (so up in the car is up in the image).
    """

    name: str
    project: object
    a0: float
    a1: float
    b0: float
    b1: float
    x: int
    y: int
    ppm: float
    flipB: bool = True

    def pixel(self, p):
        a, b = self.project(p)
        px = self.x + (a - self.a0) * self.ppm
        if self.flipB:
            py = self.y + (self.b1 - b) * self.ppm
        else:
            py = self.y + (b - self.b0) * self.ppm
        return px, py

    @property
    def w(self):
        return int(math.ceil((self.a1 - self.a0) * self.ppm))

    @property
    def h(self):
        return int(math.ceil((self.b1 - self.b0) * self.ppm))


@dataclass
class Flat:
    """A small solid patch: every face in it samples one colour."""

    name: str
    x: int
    y: int
    size: int = 8


@dataclass
class Atlas:
    name: str
    width: int
    height: int
    charts: dict = field(default_factory=dict)
    flats: dict = field(default_factory=dict)

    def add(self, c):
        (self.charts if isinstance(c, Chart) else self.flats)[c.name] = c

    def uv_of(self, chart_name, p):
        if chart_name in self.flats:
            fl = self.flats[chart_name]
            px, py = fl.x + fl.size / 2, fl.y + fl.size / 2
        else:
            px, py = self.charts[chart_name].pixel(p)
        return px / self.width, py / self.height


def bake(atlas: Atlas, faces_uv, material, pad=4):
    """faces_uv: list of (uv3 (3x2 in 0..1), P3 (3x3), N3 (3x3), tag, chart).
    material(P (k,3), N (k,3), tag, chart) -> dict of arrays:
      rgb (k,3) 0..1, alpha (k,) 0..1, metal (k,), rough (k,)
    Returns dict of uint8 images (RGBA colour, L metal, L rough) and the
    count of texels written by more than one chart."""
    W, H = atlas.width, atlas.height
    rgb = np.zeros((H, W, 3))
    alpha = np.zeros((H, W))
    metal = np.zeros((H, W))
    rough = np.ones((H, W))
    written = np.zeros((H, W), dtype=np.int32)  # chart id + 1
    chart_ids = {}
    overlaps = 0

    # Flats first, whole squares.
    for fl in atlas.flats.values():
        P = np.zeros((1, 3))
        N = np.array([[0, 1, 0]])
        m = material(P, N, fl.name, fl.name)
        ys, xs = slice(fl.y, fl.y + fl.size), slice(fl.x, fl.x + fl.size)
        rgb[ys, xs] = m["rgb"][0]
        alpha[ys, xs] = m["alpha"][0]
        metal[ys, xs] = m["metal"][0]
        rough[ys, xs] = m["rough"][0]
        written[ys, xs] = -1

    for uv, P3, N3, tag, chart in faces_uv:
        if chart in atlas.flats:
            continue
        cid = chart_ids.setdefault(chart, len(chart_ids) + 1)
        px = uv[:, 0] * W
        py = uv[:, 1] * H
        x0 = max(int(math.floor(px.min())) - 1, 0)
        x1 = min(int(math.ceil(px.max())) + 1, W - 1)
        y0 = max(int(math.floor(py.min())) - 1, 0)
        y1 = min(int(math.ceil(py.max())) + 1, H - 1)
        if x1 < x0 or y1 < y0:
            continue
        gx, gy = np.meshgrid(np.arange(x0, x1 + 1) + 0.5, np.arange(y0, y1 + 1) + 0.5)
        (ax, ay), (bx, by), (cx, cy) = zip(px, py)
        det = (by - cy) * (ax - cx) + (cx - bx) * (ay - cy)
        if abs(det) < 1e-12:
            continue
        l1 = ((by - cy) * (gx - cx) + (cx - bx) * (gy - cy)) / det
        l2 = ((cy - ay) * (gx - cx) + (ax - cx) * (gy - cy)) / det
        l3 = 1 - l1 - l2
        eps = -0.02  # a hair of conservative rasterisation closes seams
        inside = (l1 >= eps) & (l2 >= eps) & (l3 >= eps)
        if not inside.any():
            continue
        L = np.stack([l1[inside], l2[inside], l3[inside]], axis=1).clip(0, 1)
        L /= L.sum(axis=1, keepdims=True)
        P = L @ P3
        N = L @ N3
        N /= np.linalg.norm(N, axis=1, keepdims=True).clip(1e-9)
        m = material(P, N, tag, chart)
        yy = gy[inside].astype(int)
        xx = gx[inside].astype(int)
        prev = written[yy, xx]
        overlaps += int(np.count_nonzero((prev > 0) & (prev != cid)))
        rgb[yy, xx] = m["rgb"]
        alpha[yy, xx] = m["alpha"]
        metal[yy, xx] = m["metal"]
        rough[yy, xx] = m["rough"]
        written[yy, xx] = cid

    # Dilate into the gutters so mip levels don't pull in black.
    filled = written != 0
    for _ in range(pad):
        grown = filled.copy()
        nrgb, nal, nme, nro = rgb.copy(), alpha.copy(), metal.copy(), rough.copy()
        for dy, dx in ((0, 1), (0, -1), (1, 0), (-1, 0)):
            src = np.roll(filled, (dy, dx), axis=(0, 1))
            take = src & ~grown
            nrgb[take] = np.roll(rgb, (dy, dx), axis=(0, 1))[take]
            nal[take] = np.roll(alpha, (dy, dx), axis=(0, 1))[take]
            nme[take] = np.roll(metal, (dy, dx), axis=(0, 1))[take]
            nro[take] = np.roll(rough, (dy, dx), axis=(0, 1))[take]
            grown |= take
        rgb, alpha, metal, rough, filled = nrgb, nal, nme, nro, grown

    def u8(a):
        return (np.clip(a, 0, 1) * 255 + 0.5).astype(np.uint8)

    colour = np.dstack([u8(rgb), u8(alpha)])
    return {
        "color": Image.fromarray(colour, "RGBA"),
        "metal": Image.fromarray(u8(metal), "L"),
        "rough": Image.fromarray(u8(rough), "L"),
    }, overlaps


# ---------------------------------------------------------------------------
# Pieces: split, centre, encode
# ---------------------------------------------------------------------------


@dataclass
class Piece:
    name: str
    positions: np.ndarray  # (v,3) metres, centred on the bounding box
    normals: np.ndarray  # (n,3)
    uvs: np.ndarray  # (u,2)
    tris: np.ndarray  # (t,3,3): per corner (position, normal, uv) ids
    size: np.ndarray
    offset: np.ndarray  # bounding box centre in its mount's space

    @property
    def triangles(self):
        return len(self.tris)


def build_piece(name, P, N, faces, uv_of_face):
    """faces: list of Face; uv_of_face(face) -> 3x2 uv array."""
    pos_map, nrm_map, uv_map = {}, {}, {}
    positions, normals, uvs, tris = [], [], [], []
    for f in faces:
        uv3 = uv_of_face(f)
        corner = []
        for k, vi in enumerate(f.v):
            if vi not in pos_map:
                pos_map[vi] = len(positions)
                positions.append(P[vi])
            if vi not in nrm_map:
                nrm_map[vi] = len(normals)
                normals.append(N[vi])
            key = (round(float(uv3[k][0]), 6), round(float(uv3[k][1]), 6))
            if key not in uv_map:
                uv_map[key] = len(uvs)
                uvs.append(key)
            corner.append((pos_map[vi], nrm_map[vi], uv_map[key]))
        tris.append(corner)
    positions = np.array(positions)
    lo, hi = positions.min(axis=0), positions.max(axis=0)
    centre = (lo + hi) / 2
    return Piece(
        name,
        positions - centre,
        np.array(normals),
        np.array(uvs),
        np.array(tris, dtype=np.int64),
        hi - lo,
        centre,
    )


def _b64(fmt, values):
    return base64.b64encode(struct.pack("<" + fmt * len(values), *values)).decode("ascii")


def encode_piece(piece: Piece):
    """Quantised: positions int16 over the half size, normals int8, uvs
    uint16, indices uint16. Little endian, base64."""
    half = np.maximum(piece.size / 2, 1e-6)
    q = np.clip(np.round(piece.positions / half * 32767), -32767, 32767).astype(int)
    nq = np.clip(np.round(piece.normals * 127), -127, 127).astype(int)
    uq = np.clip(np.round(piece.uvs * 65535), 0, 65535).astype(int)
    for arr in (piece.tris[:, :, 0], piece.tris[:, :, 1], piece.tris[:, :, 2]):
        assert arr.max() < 65536
    return {
        "positions": _b64("h", q.flatten().tolist()),
        "normals": _b64("b", nq.flatten().tolist()),
        "uvs": _b64("H", uq.flatten().tolist()),
        "triangles": _b64("H", piece.tris.reshape(-1).tolist()),
    }


CHUNK = 180_000  # a Roblox script Source must stay under 200,000 characters


def write_luau(folder, car_name, header, pieces: list[Piece]):
    """Writes folder/init.luau plus one module per buffer (split into chunks
    under the Source limit). Stale modules from an earlier run are removed."""
    os.makedirs(folder, exist_ok=True)
    for old in os.listdir(folder):
        if old.endswith(".luau"):
            os.remove(os.path.join(folder, old))
    gen = "-- GENERATED by tools/carbody/" + car_name.lower() + ".py. Do not edit by hand."
    lines = ["--!strict", gen, "-- Change the generator and run it again."]
    for h in header:
        lines.append("-- " + h)
    lines += [
        "--",
        "-- Each piece is centred on its bounding box; sizeM and offsetM are what",
        "-- the catalog entry places it by (RIG_SPEC.md section 7). Buffers are",
        "-- base64 little-endian in the child modules: positions int16 of the half",
        "-- size, normals int8, uvs uint16, triangles uint16 (position, normal, uv)",
        "-- per corner. MeshData decodes them.",
        "return {",
    ]
    for p in pieces:
        e = encode_piece(p)
        lines.append(f"\t{p.name} = {{")
        lines.append(f"\t\ttriangleCount = {p.triangles},")
        lines.append(f"\t\tsizeM = {{ {p.size[0]:.4f}, {p.size[1]:.4f}, {p.size[2]:.4f} }},")
        lines.append(f"\t\toffsetM = {{ {p.offset[0]:.4f}, {p.offset[1]:.4f}, {p.offset[2]:.4f} }},")
        lines.append(f"\t\tcounts = {{ {len(p.positions)}, {len(p.normals)}, {len(p.uvs)} }},")
        for key in ("positions", "normals", "uvs", "triangles"):
            text = e[key]
            parts = [text[k:k + CHUNK] for k in range(0, len(text), CHUNK)] or [""]
            names = []
            for n, chunk in enumerate(parts):
                name = f"{p.name}_{key}" + (f"_{n + 1}" if len(parts) > 1 else "")
                names.append(name)
                with open(os.path.join(folder, name + ".luau"), "w") as fh:
                    fh.write("--!strict\n" + gen + "\n" + f'return "{chunk}"\n')
            joined = " .. ".join(f"require(script.{n}) :: string" if len(names) == 1 else f"(require(script.{n}) :: string)" for n in names)
            lines.append(f"\t\t{key} = {joined},")
        lines.append("\t},")
    lines.append("}")
    with open(os.path.join(folder, "init.luau"), "w") as fh:
        fh.write("\n".join(lines) + "\n")


def write_obj(path, pieces: list[Piece], offsets=True):
    """For import into a DCC tool or Studio's 3D importer, not used by the game."""
    with open(path, "w") as fh:
        vbase = nbase = tbase = 1
        for p in pieces:
            fh.write(f"o {p.name}\n")
            off = p.offset if offsets else np.zeros(3)
            for v in p.positions + off:
                fh.write(f"v {v[0]:.5f} {v[1]:.5f} {v[2]:.5f}\n")
            for n in p.normals:
                fh.write(f"vn {n[0]:.4f} {n[1]:.4f} {n[2]:.4f}\n")
            for u in p.uvs:
                fh.write(f"vt {u[0]:.6f} {1 - u[1]:.6f}\n")
            for t in p.tris:
                fh.write("f " + " ".join(f"{c[0] + vbase}/{c[2] + tbase}/{c[1] + nbase}" for c in t) + "\n")
            vbase += len(p.positions)
            nbase += len(p.normals)
            tbase += len(p.uvs)


# ---------------------------------------------------------------------------
# Revolved meshes for wheels (wheel space: axle along X)
# ---------------------------------------------------------------------------


def revolve(surface: Surface, profile, segments):
    """profile: list of (x, r). Returns idx[seg][k] for seg in 0..segments-1;
    index segments wraps to 0. A profile point with r == 0 is one vertex."""
    idx = []
    centre = {}
    for s in range(segments):
        th = 2 * math.pi * s / segments
        row = []
        for k, (x, r) in enumerate(profile):
            if r == 0:
                if k not in centre:
                    centre[k] = surface.vert((x, 0.0, 0.0))
                row.append(centre[k])
            else:
                row.append(surface.vert((x, r * math.cos(th), r * math.sin(th))))
        idx.append(row)
    idx.append(idx[0])
    return idx


def angle_uv(p3):
    """u in 0..1 from the angle about X for three corners, unwrapped so a face
    across the seam does not span the whole texture."""
    th = np.arctan2(p3[:, 2], p3[:, 1]) % (2 * math.pi)
    if th.max() - th.min() > math.pi:
        th = np.where(th < math.pi, th + 2 * math.pi, th)
    return th / (2 * math.pi)
