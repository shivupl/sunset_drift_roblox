"""Sun strips moulded to each car's windscreen (garage round 3 §3).

    python3 tools/cosmetics/strip_shapes.py

Needs numpy and DracoPy (tools/carbody/rbxcache.py). Render every car in
Studio first (Edit, BodyBuilder.mount, or any MeshPart with the piece's mesh
id in view) so its glass mesh sits in Studio's local cache.

For each car in CarCosmeticMounts with a windscreen spot it:

  1. reads the spot's glass piece (`piece`) from CarCatalog.luau: a store
     mesh found in Studio's cache by its proportions (rbxcache.py), or a
     generated mesh from its MeshData module (src/shared/CarMeshes), and
     places it in car space as BodyBuilder does (the mesh's bounds scaled to
     sizeM, turned by rotationDeg YXZ, moved to offsetM): metres before the
     car's scale, +X right, +Y up, forward -Z;
  2. keeps the faces that look forward and up (the windscreen) inside the
     spot's x range, and slices them with planes of constant x: each slice is
     the screen's profile there, top edge first;
  3. walks down each profile from its top edge by topGapM plus half the
     strip height: that point is the strip's centre line there, and the
     profile's direction there is the strip's up;
  4. splits the centre line between the ends into CosmeticsConfig.render
     .stripSlats slats; each slat spans the chord between its two end points
     (so neighbours share their ends and the chain follows the screen's curve
     across) and takes its normal from the surface (orthogonal to the chord).
     Each join is widened until even the slats' corners overlap by 2 x
     stripOverlapM (more where the strip bends in the glass's plane); the
     strip's two outer ends are not widened. Canvas slices count from the
     car's right (+X) end, where a Front-face SurfaceGui's canvas starts;
  5. moves each slat off the glass along its normal (outside, on opaque
     glass) or behind it (inside, behind see-through glass), and writes
     src/shared/CarStripShapes.luau.

The ends: where the spot says `ends = "mesh"`, the centre line runs to where
the glass ends at the pillars (the outline, less endInsetM where the glass
runs on under the pillar trim). Shell cars (pickup, cruiser) have their
glass painted into a textured shell, so the mesh has no outline there:
`ends = "spot"` takes the ends from the spot's by-eye widthM, and only the
curve and normals come from the mesh. The hatch is a pack car too, but its
glass is a black glass piece of its own, so it takes its ends from the mesh.

Store meshes are found by mesh id: glass_meshes.json records each id's
MeshSize and face count, and exactly one cached mesh must match them.
"""

from __future__ import annotations

import argparse
import base64
import math
import os
import re
import sys

import numpy as np

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
sys.path.insert(0, os.path.join(ROOT, "tools", "carbody"))

CATALOG = os.path.join(ROOT, "src", "shared", "CarCatalog.luau")
MOUNTS = os.path.join(ROOT, "src", "shared", "CarCosmeticMounts.luau")
MESHES = os.path.join(ROOT, "src", "shared", "CarMeshes")
OUT = os.path.join(ROOT, "src", "shared", "CarStripShapes.luau")

COSMETICS = os.path.join(ROOT, "src", "shared", "CosmeticsConfig.luau")


def render_number(key):
    """A number from CosmeticsConfig.render: the slat count, overlap, glass
    gap and thickness live there (tunables in config), and the game reads
    the same ones."""
    text = open(COSMETICS).read()
    m = re.search(r"\n\t" + key + r"\s*=\s*([\d.]+)", text)
    if not m:
        raise ValueError(f"CosmeticsConfig.render.{key} missing")
    return float(m.group(1))


# The polynomial degree the strip's centre line is smoothed with, across x:
# enough to follow a crowned screen into its corners (the fit's error is
# printed per car; a few millimetres at most).
SMOOTH_DEG = 6
# Mesh corners this close to a slat's plane (either side) and under it count
# when clearing the glass; further ones are other panels (the roof, the dash).
NEAR_M = 0.05
# How far the fitted header may run above a slice's own top edge before the
# band counts as off the glass there, metres of arc: the fit's own error on a
# faceted top edge (a few millimetres), with room to spare. Past it the top
# edge is turning down the pillar.
TOP_TOL_M = 0.012
# Profile slices across the screen when finding the ends and the curve.
SLICES = 240
# Which faces are windscreen: outward normal looking forward (z below
# SCREEN_FWD_MAX, so the roof's crown, up to ~81° from vertical, still counts,
# and the top edge is where the glass turns into the roof), up (y above
# SCREEN_UP_MIN, not the bumper or a straight-ahead roof lip) and not sideways
# (|x| below SCREEN_SIDE_MAX, not the side windows; a curved screen's corners
# look out up to ~58° to the side).
SCREEN_FWD_MAX = -0.15
SCREEN_UP_MIN = 0.1
SCREEN_SIDE_MAX = 0.85


# --------------------------------------------------------------------------
# Reading the catalog and the mounts


def lua_block(text, key, start=0):
    """The text of `key = { ... }` (balanced braces) from start."""
    m = re.compile(r"\b" + re.escape(key) + r"\s*=\s*\{").search(text, start)
    if not m:
        return None
    i = m.end() - 1
    depth = 0
    for j in range(i, len(text)):
        c = text[j]
        if c == "{":
            depth += 1
        elif c == "}":
            depth -= 1
            if depth == 0:
                return text[i:j + 1]
    raise ValueError(f"unbalanced block {key}")


def lua_vec(s, key):
    m = re.search(r"\b" + key + r"\s*=\s*\{([^}]*)\}", s)
    return None if not m else [float(x) for x in m.group(1).split(",")]


def catalog_piece(car, name):
    text = open(CATALOG).read()
    m = re.search(r"\n\t" + re.escape(car) + r" = \{", text)
    if not m:
        raise ValueError(f"no catalog entry {car}")
    entry = lua_block(text, car, m.start())
    scale = float(re.search(r"\bscale\s*=\s*([\d.]+)", entry).group(1))
    for line in entry.splitlines():
        if re.search(r'name\s*=\s*"' + re.escape(name) + '"', line):
            if lua_vec(line, "sizeM") is None or lua_vec(line, "offsetM") is None:
                raise ValueError(f"{car} {name}: sizeM and offsetM must be on the piece's one line in CarCatalog.luau")
            mesh_id = re.search(r"\bmeshId\s*=\s*(\d+)", line)
            mesh = re.search(r'\bmesh\s*=\s*"([^"]+)"', line)
            return {
                "meshId": int(mesh_id.group(1)) if mesh_id else None,
                "mesh": mesh.group(1) if mesh else None,
                "sizeM": np.array(lua_vec(line, "sizeM")),
                "offsetM": np.array(lua_vec(line, "offsetM")),
                "rotationDeg": np.array(lua_vec(line, "rotationDeg") or [0, 0, 0]),
                "scale": scale,
            }
    raise KeyError(f"{car}: no body piece {name}")


def mount_spots():
    """{car: windscreen spot} from CarCosmeticMounts.luau."""
    text = open(MOUNTS).read()
    cars = lua_block(text, "CarCosmeticMounts.cars")
    out = {}
    for m in re.finditer(r"\n\t(\w+) = \{", cars):
        car = m.group(1)
        block = lua_block(cars, car, m.start())
        ws = lua_block(block, "windscreen")
        if not ws:
            continue
        pos = lua_vec(ws, "posM")
        width = re.search(r"widthM\s*=\s*([\d.]+)", ws)
        for key in ("piece", "side", "ends", "heightM"):
            if not re.search(r"\b" + key + r"\s*=", ws):
                raise ValueError(f"{car}: CarCosmeticMounts windscreen has no {key}")
        spot = {
            "posM": np.array(pos) if pos else None,
            "widthM": float(width.group(1)) if width else None,
            "heightM": float(re.search(r"heightM\s*=\s*([\d.]+)", ws).group(1)),
            "piece": re.search(r'piece\s*=\s*"([^"]+)"', ws).group(1),
            "side": re.search(r'side\s*=\s*"(\w+)"', ws).group(1),
            "ends": re.search(r'ends\s*=\s*"(\w+)"', ws).group(1),
        }
        for key in ("topGapM", "endInsetM"):
            v = re.search(key + r"\s*=\s*(-?[\d.]+)", ws)
            spot[key] = float(v.group(1)) if v else 0.0
        out[car] = spot
    return out


# --------------------------------------------------------------------------
# Meshes


def meshdata(name):
    """A generated piece's (points, faces), in its own space (MeshData)."""
    folder, piece = name.split("/")
    base = os.path.join(MESHES, folder)
    init = open(os.path.join(base, "init.luau")).read()
    block = lua_block(init, piece)
    size = np.array(lua_vec(block, "sizeM"))
    counts = lua_vec(block, "counts")
    tri_n = int(re.search(r"triangleCount\s*=\s*(\d+)", block).group(1))

    def buf(kind):
        s = open(os.path.join(base, f"{piece}_{kind}.luau")).read()
        return base64.b64decode(re.search(r'return "([^"]*)"', s).group(1))

    pos = np.frombuffer(buf("positions"), dtype="<i2")[: int(counts[0]) * 3].reshape(-1, 3) / 32767 * size / 2
    tri = np.frombuffer(buf("triangles"), dtype="<u2")[: tri_n * 9].reshape(-1, 3, 3)[:, :, 0].astype(np.int64)
    return pos.astype(float), tri


_cache_index = None
GLASS = os.path.join(ROOT, "tools", "cosmetics", "glass_meshes.json")


def store_mesh(mesh_id):
    """A store mesh's (points, faces) from Studio's cache, by mesh id: the
    cached mesh whose own bounds match the id's recorded MeshSize and whose
    face count matches (glass_meshes.json). Exactly one distinct mesh must
    match (the cache often holds the same mesh twice); anything else fails
    loudly, so a wrong mesh is never fitted (fix round 1, M2)."""
    import json

    import rbxcache

    known = json.load(open(GLASS)).get(str(mesh_id))
    if known is None:
        raise LookupError(f"mesh {mesh_id} is not in {os.path.relpath(GLASS, ROOT)}: add its MeshSize and face count")
    want = np.array(known["meshSize"], dtype=float)
    global _cache_index
    if _cache_index is None:
        _cache_index = []
        # storescan.py's index of the cache (bounds and face counts, kept
        # between runs): only the meshes with these bounds are decoded.
        import pickle

        import storescan

        if os.path.exists(storescan.IDX):
            storescan.cache_meshes()
            idx = pickle.load(open(storescan.IDX, "rb"))
            wanted = [np.array(v["meshSize"], dtype=float) for k, v in json.load(open(GLASS)).items() if k != "_about"]
            paths = [path for path, v in idx.items()
                     if v and any(np.max(np.abs(np.array(v[0]) - w) / w) < 0.001 for w in wanted)]
        else:
            paths = list(rbxcache.entries())
        for path in paths:
            try:
                r = rbxcache.decode(path)
            except Exception:
                continue
            if r is None:
                continue
            ext = rbxcache.extents(r[0])
            if ext is not None:
                _cache_index.append((path, ext, r))
    hits = {}
    near = []
    for path, ext, r in _cache_index:
        err = float(np.max(np.abs(ext - want) / want))
        if err < 0.001 and len(r[1]) == known["faces"]:
            # The same mesh cached twice decodes the same: one entry per shape.
            hits.setdefault((len(r[1]), tuple(np.round(ext, 4))), (path, r))
        elif err < 0.001:
            near.append(f"{os.path.basename(path)} ({len(r[1])} faces)")
    if not hits:
        extra = f"; same bounds but {', '.join(near)} (expected {known['faces']} faces)" if near else ""
        raise LookupError(f"mesh {mesh_id} ({known['car']} {known['piece']}) is not in Studio's cache: render the car in Studio first{extra}")
    if len(hits) > 1:
        raise LookupError(f"mesh {mesh_id}: {len(hits)} different cached meshes match its bounds and face count")
    path, r = next(iter(hits.values()))
    return r, path


def rot_yxz(deg):
    rx, ry, rz = np.radians(deg)
    cx, sx, cy, sy, cz, sz = math.cos(rx), math.sin(rx), math.cos(ry), math.sin(ry), math.cos(rz), math.sin(rz)
    Ry = np.array([[cy, 0, sy], [0, 1, 0], [-sy, 0, cy]])
    Rx = np.array([[1, 0, 0], [0, cx, -sx], [0, sx, cx]])
    Rz = np.array([[cz, -sz, 0], [sz, cz, 0], [0, 0, 1]])
    return Ry @ Rx @ Rz


def piece_in_car(p):
    """(points, faces, where) of a catalog piece in car space."""
    if p["mesh"]:
        pts, faces = meshdata(p["mesh"])
        where = f"MeshData {p['mesh']}"
    else:
        (pts, faces), path = store_mesh(p["meshId"])
        where = f"store mesh {p['meshId']} (cache {os.path.basename(path)})"
    lo, hi = pts.min(0), pts.max(0)
    local = (pts - (lo + hi) / 2) / (hi - lo) * p["sizeM"]
    world = local @ rot_yxz(p["rotationDeg"]).T + p["offsetM"]
    return world, faces, where


# --------------------------------------------------------------------------
# The windscreen surface


def outward_normals(V, F):
    """Unit face normals turned to point out of the car (away from a point
    low in the cabin under the piece), whatever the mesh's winding: store
    meshes mix windings, and some are double-sided."""
    A, B, C = V[F[:, 0]], V[F[:, 1]], V[F[:, 2]]
    n = np.cross(B - A, C - A)
    area = np.linalg.norm(n, axis=1) / 2
    n = n / np.maximum(2 * area, 1e-12)[:, None]
    cen = (A + B + C) / 3
    inside = np.array([0.0, V[:, 1].min(), (V[:, 2].min() + V[:, 2].max()) / 2])
    n *= np.where(((cen - inside) * n).sum(1) >= 0, 1.0, -1.0)[:, None]
    return n, area, cen


def screen_faces(V, F, spot):
    """Indices of the windscreen's faces: those facing forward and up, in
    the connected patch that is the screen (the largest, or for a shell the
    one at the spot's by-eye centre)."""
    n, area, cen = outward_normals(V, F)
    facing = (n[:, 2] < SCREEN_FWD_MAX) & (n[:, 1] > SCREEN_UP_MIN) & (np.abs(n[:, 0]) < SCREEN_SIDE_MAX)
    # Weld corners 1 mm apart: store meshes split vertices at UV seams.
    key = np.round(V / 0.001).astype(np.int64)
    _, weld = np.unique(key, axis=0, return_inverse=True)
    weld = weld.reshape(-1)
    parent = list(range(weld.max() + 1))

    def find(a):
        while parent[a] != a:
            parent[a] = parent[parent[a]]
            a = parent[a]
        return a

    idx = np.nonzero(facing)[0]
    for i in idx:
        a, b, c = (find(int(weld[v])) for v in F[i])
        parent[b] = a
        parent[find(c)] = a
    comp = np.array([find(int(weld[F[i, 0]])) for i in idx])
    if spot["ends"] == "spot":
        seed = spot["posM"]
        pick = comp[np.argmin(np.linalg.norm(cen[idx] - seed, axis=1))]
    else:
        sums = {}
        for c, i in zip(comp, idx):
            sums[c] = sums.get(c, 0.0) + area[i]
        pick = max(sums, key=sums.get)
    return idx[comp == pick], n


def profile(V, F, faces, n, x):
    """The screen's profile in the plane at x, from its top edge down: points
    (k, 3), arc lengths (k,), and outward normals (k, 3); or None."""
    segs = []
    for i in faces:
        P = V[F[i]]
        d = P[:, 0] - x
        pts = []
        for a, b in ((0, 1), (1, 2), (2, 0)):
            if (d[a] < 0) != (d[b] < 0):
                t = d[a] / (d[a] - d[b])
                pts.append(P[a] + (P[b] - P[a]) * t)
        if len(pts) == 2:
            segs.append((pts[0], pts[1], n[i]))
    if not segs:
        return None
    # Chain the segments from the topmost free end, always stepping down to
    # the next segment that starts where this one ended; repeat until every
    # segment is in a chain, and keep the longest (a shell's roof lip, cut
    # from the glass by a face that looks straight ahead, is a short chain of
    # its own above the screen's).
    q = lambda p: (round(p[1] / 2e-5), round(p[2] / 2e-5))
    ends = {}
    for s in segs:
        for p in s[:2]:
            ends.setdefault(q(p), []).append(s)
    used = set()
    best = None
    while len(used) < len(segs):
        free = [p for s in segs if id(s) not in used for p in s[:2]]
        top = max(free, key=lambda p: p[1])
        pts, nrm = [top], []
        cur = top
        while True:
            nxt = None
            for s in ends.get(q(cur), []):
                if id(s) in used:
                    continue
                other = s[1] if q(s[0]) == q(cur) else s[0]
                if q(other) == q(cur):
                    used.add(id(s))
                    continue
                if nxt is None or other[1] < nxt[0][1]:
                    nxt = (other, s)
            if nxt is None:
                break
            other, s = nxt
            # Take this step and every duplicate of it (double-sided meshes).
            for t in ends.get(q(cur), []):
                if {q(t[0]), q(t[1])} == {q(cur), q(other)}:
                    used.add(id(t))
            pts.append(other)
            nrm.append(s[2])
            cur = other
        for s in ends.get(q(top), []):
            if len(pts) == 1:
                used.add(id(s))  # a lone point: nothing chains from it
        if len(pts) < 2:
            continue
        P = np.array(pts)
        S = np.concatenate([[0.0], np.cumsum(np.linalg.norm(np.diff(P, axis=0), axis=1))])
        if best is None or S[-1] > best[1][-1]:
            best = (P, S, np.array(nrm))
    return best


def surface_points(V, F, box, step=0.004):
    """Points over every face of the mesh that reaches into box (lo, hi),
    about `step` apart: what a slat must clear. Big faces (a shell's whole
    side) are split into quarters until small, dropping the quarters that
    miss the box, so only the part near the strip is sampled."""
    lo, hi = box
    out = [V[((V >= lo) & (V <= hi)).all(1)]]
    todo = [t for t in V[F]]
    while todo:
        tri = todo.pop()
        if (tri.max(0) < lo).any() or (tri.min(0) > hi).any():
            continue
        edge = max(np.linalg.norm(tri[1] - tri[0]), np.linalg.norm(tri[2] - tri[1]), np.linalg.norm(tri[0] - tri[2]))
        if edge > 16 * step:
            m01, m12, m20 = (tri[0] + tri[1]) / 2, (tri[1] + tri[2]) / 2, (tri[2] + tri[0]) / 2
            todo += [np.array([tri[0], m01, m20]), np.array([m01, tri[1], m12]),
                     np.array([m20, m12, tri[2]]), np.array([m01, m12, m20])]
            continue
        n = max(2, int(math.ceil(edge / step)))
        i, j = np.meshgrid(np.arange(n + 1), np.arange(n + 1))
        keep = i + j <= n
        pts = tri[0] + np.outer(i[keep] / n, tri[1] - tri[0]) + np.outer(j[keep] / n, tri[2] - tri[0])
        out.append(pts[((pts >= lo) & (pts <= hi)).all(1)])
    return np.concatenate(out)


def along(prof, s):
    """The point, the up-slope tangent and the outward normal at arc s."""
    P, S, N = prof
    s = min(max(s, 0.0), S[-1])
    k = int(np.clip(np.searchsorted(S, s, side="right") - 1, 0, len(N) - 1))
    span = S[k + 1] - S[k]
    t = 0.0 if span <= 0 else (s - S[k]) / span
    p = P[k] + (P[k + 1] - P[k]) * t
    up = P[k] - P[k + 1]
    up = up / max(np.linalg.norm(up), 1e-12)
    return p, up, N[k]


def arc_at_height(prof, y):
    """The arc length where the profile comes down to height y."""
    P, S, _ = prof
    for k in range(len(P) - 1):
        if P[k][1] >= y >= P[k + 1][1]:
            dy = P[k][1] - P[k + 1][1]
            t = 0.0 if dy <= 0 else (P[k][1] - y) / dy
            return S[k] + (S[k + 1] - S[k]) * t
    return None


# --------------------------------------------------------------------------
# Fitting the slats


def fit(car, spot, report=None):
    slats = int(render_number("stripSlats"))
    overlap = render_number("stripOverlapM")
    glass_gap = render_number("stripGlassGapM")
    T = render_number("stripThicknessM")
    piece = catalog_piece(car, spot["piece"])
    V, F, where = piece_in_car(piece)
    faces, n = screen_faces(V, F, spot)
    fv = V[F[faces]].reshape(-1, 3)
    x0, x1 = fv[:, 0].min(), fv[:, 0].max()
    xc = float(spot["posM"][0]) if spot["ends"] == "spot" else (x0 + x1) / 2
    H = spot["heightM"]
    gap = spot["topGapM"]

    cache = {}

    def prof(x):
        key = round(x, 6)
        if key not in cache:
            cache[key] = profile(V, F, faces, n, x)
        return cache[key]

    # The header: the screen's top edge where it runs across (the middle
    # half), fitted in 3D (y and z each a quadratic in x) and carried out to
    # the pillars, where the glass's own top edge turns down the pillar.
    # Fitting in 3D matters on a nearly level screen: a header fitted in
    # height alone and found on each slice by height turned a few mm of
    # misfit into ~4x that along the glass (1 / sin 15° on the hatch), and
    # the strip waved 1.6 cm up and down it (fix round 1, M3).
    xs = np.linspace(x0, x1, SLICES + 2)[1:-1]
    mid = [x for x in xs if abs(x - (x0 + x1) / 2) < 0.25 * (x1 - x0)]
    tops = [(x, prof(x)[0][0]) for x in mid if prof(x) is not None]
    tx = [t[0] for t in tops]
    cy = np.polyfit(tx, [t[1][1] for t in tops], 2)
    cz = np.polyfit(tx, [t[1][2] for t in tops], 2)

    def header_arc(x, p):
        """Arc from this profile's own top to the point nearest the header
        (negative where the header runs above the top edge, at a rounded
        corner). A shell's ends are by eye, inside its screen: there the
        band just follows the slice's own top edge, rounded corners and all."""
        if spot["ends"] == "spot":
            return 0.0
        head = np.array([np.polyval(cy, x), np.polyval(cz, x)])
        P, S, _ = p
        _, up, _ = along(p, 0.0)
        above = (head - P[0][1:]) @ up[1:]
        if above > 0:
            return -above
        best, best_s = math.inf, 0.0
        for k in range(len(P) - 1):
            a, b = P[k][1:], P[k + 1][1:]
            seg = b - a
            L2 = seg @ seg
            t = 0.0 if L2 <= 0 else min(max((head - a) @ seg / L2, 0.0), 1.0)
            dist = np.linalg.norm(a + seg * t - head)
            if dist < best:
                best, best_s = dist, S[k] + (S[k + 1] - S[k]) * t
        return best_s

    def band(x):
        """The band's centre arc on this slice's profile, or None where the
        whole band (topGapM, then heightM) is not on the glass."""
        p = prof(x)
        if p is None:
            return None
        start = header_arc(x, p) + gap
        if start < -TOP_TOL_M or start + H > p[1][-1] + 1e-4:
            return None
        if spot["side"] == "outside":
            # A sticker on opaque glass never starts above the glass's own top
            # edge, where it would sit over roof or pillar trim this script
            # does not clear (fix round 1, L1). Inside, the roof hides it.
            start = max(start, 0.0)
        return p, start + H / 2

    def on(x):
        b = band(x)
        if b is None:
            raise ValueError(f"{car}: the band leaves the glass at x {x:.3f} (topGapM, heightM or the spot's ends)")
        return b

    if spot["ends"] == "spot":
        xl, xr = xc - spot["widthM"] / 2, xc + spot["widthM"] / 2
        for x in (xl, xr):
            if band(x) is None:
                raise ValueError(f"{car}: the spot's ends are off the screen (x {x:.3f})")
    else:
        # Out from the middle, slice by slice, to the last slice the whole
        # band fits on; then halve the step down to a millimetre.
        def edge(direction):
            step = (x1 - x0) / SLICES
            x = xc
            if band(x) is None:
                raise ValueError(f"{car}: the band does not fit the screen's middle")
            while step > 0.001:
                while x0 < x + direction * step < x1 and band(x + direction * step) is not None:
                    x += direction * step
                step /= 2
            return x

        xl = edge(-1) + spot["endInsetM"]
        xr = edge(1) - spot["endInsetM"]

    if report is not None:
        report.update({"where": where, "faces": len(faces), "x": (x0, x1), "ends": (xl, xr)})
        if spot["posM"] is not None:
            # Where the by-eye spot sits on the profile at its x: its gap under
            # the top edge (how topGapM was set for a shell).
            p0 = prof(xc)
            ss = np.linspace(0, p0[1][-1], 400)
            dist = [np.linalg.norm(along(p0, t)[0][1:] - spot["posM"][1:]) for t in ss]
            report["spotGapM"] = ss[int(np.argmin(dist))] - header_arc(xc, p0) - H / 2
    # The centre line and its up-slope direction, sampled finely across and
    # smoothed with a polynomial in x: faceted glass (a zig-zag top edge, a
    # crease between two rows of faces) would otherwise kink the slats a
    # degree or two either way.
    xs = np.linspace(xl, xr, 8 * slats + 1)
    raw_p, raw_u = [], []
    for x in xs:
        p, s = on(x)
        q, up, _ = along(p, s)
        raw_p.append(q)
        raw_u.append(up)
    raw_p, raw_u = np.array(raw_p), np.array(raw_u)
    deg = min(SMOOTH_DEG, len(xs) - 1)
    fp = [np.polyfit(xs, raw_p[:, i], deg) for i in range(3)]
    fu = [np.polyfit(xs, raw_u[:, i], deg) for i in range(3)]

    def P(x):
        return np.array([np.polyval(f, x) for f in fp])

    def U(x):
        u = np.array([np.polyval(f, x) for f in fu])
        return u / np.linalg.norm(u)

    if report is not None:
        report["fitErrM"] = float(np.max(np.linalg.norm(np.array([P(x) for x in xs]) - raw_p, axis=1)))

    def frame(a, b, xm):
        right = (b - a) / np.linalg.norm(b - a)
        up = U(xm)
        up = up - right * (up @ right)
        up /= np.linalg.norm(up)
        return right, up, np.cross(up, right)  # right x up is the part's back (+Z)

    xk = np.linspace(xl, xr, slats + 1)
    E = [P(x) for x in xk]
    # The strip's box, and a margin: the mesh only matters near it.
    ends_ = np.array(E)
    dense = surface_points(V, F, (ends_.min(0) - H - NEAR_M, ends_.max(0) + H + NEAR_M))
    # How far each slat must stand off the glass along its normal: sample the
    # surface under it (across its span, at its top, middle and bottom) and
    # clear the highest point (outside) or the lowest (inside) by the gap.
    need = []
    for k in range(slats):
        right, up, normal = frame(E[k], E[k + 1], (xk[k] + xk[k + 1]) / 2)
        c = (E[k] + E[k + 1]) / 2
        d = []
        for x in np.linspace(xk[k], xk[k + 1], 7):
            pp, ss = on(x)
            for ds in (-H / 2, -H / 4, 0.0, H / 4, H / 2):
                d.append((along(pp, ss + ds)[0] - c) @ normal)
        # And the whole piece's mesh under the slat and near it, sampled every
        # few millimetres (a pillar's face or a sharp corner between the
        # profile samples would otherwise poke through at a slat's end).
        rel = dense - c
        u, w, h = rel @ right, rel @ up, rel @ normal
        under = (np.abs(u) <= (xk[k + 1] - xk[k]) / 2 + overlap) & (np.abs(w) <= H / 2) & (np.abs(h) < NEAR_M)
        d.extend(h[under].tolist())
        need.append((max(d) if spot["side"] == "outside" else -min(d)) + glass_gap + T / 2)
    # Move the shared slat ends off the glass by the larger need of the two
    # slats that meet there, so the chain stays joined and every slat clears.
    sign = 1.0 if spot["side"] == "outside" else -1.0
    moved = []
    for k, x in enumerate(xk):
        o = max(need[max(k - 1, 0)], need[min(k, slats - 1)])
        tangent = P(x + 1e-4) - P(x - 1e-4)
        tangent /= np.linalg.norm(tangent)
        normal = np.cross(U(x), tangent)
        normal /= np.linalg.norm(normal)
        moved.append(E[k] + sign * normal * o)
    out = []
    run = 0.0
    for k in range(slats):
        a, b = moved[k], moved[k + 1]
        right, up, normal = frame(a, b, (xk[k] + xk[k + 1]) / 2)
        chord = float(np.linalg.norm(b - a))
        out.append({"a": a, "b": b, "normal": normal, "right": right, "up": up, "startM": run, "chordM": chord})
        run += chord
    # How far each slat runs past its chord at a join. The strip bends in
    # the glass's plane where it follows a curving top edge, so neighbours
    # turn against each other (up to ~15° at a rounded corner) and a wedge
    # opens at the outer edge; each join gets enough extra that even there
    # the two overlap by 2 x stripOverlapM. The strip's two ends run
    # stripOverlapM past their chords.
    ext = [overlap] * (slats + 1)
    # The strip's two outer ends have no neighbour to cover: no extension
    # (4 mm of plain part colour past the canvas otherwise; fix round 1, N1).
    ext[0] = ext[slats] = 0.0
    for j in range(1, slats):
        s1, s2 = out[j - 1], out[j]
        for _ in range(4):
            worst = math.inf
            for sgn in (-1.0, 1.0):
                p1 = s1["b"] + s1["right"] * ext[j] + s1["up"] * sgn * H / 2  # left slat's right corner
                p2 = s2["a"] - s2["right"] * ext[j] + s2["up"] * sgn * H / 2  # right slat's left corner
                worst = min(worst, (p1 - s2["a"]) @ s2["right"] + ext[j], (s1["b"] - p2) @ s1["right"] + ext[j])
            if worst >= 2 * overlap - 1e-5:
                break
            ext[j] += (2 * overlap - worst) / 2 + 1e-4
    for k, sl in enumerate(out):
        a, b, right = sl.pop("a"), sl.pop("b"), sl["right"]
        left_ext, right_ext = ext[k], ext[k + 1]
        sl.pop("up")
        chord = sl.pop("chordM")
        sl["centreM"] = (a + b) / 2 + right * (right_ext - left_ext) / 2
        sl["widthM"] = chord + left_ext + right_ext
        sl["heightM"] = H
        # The canvas reads left to right as seen from in front of the car,
        # which is from the car's right (+X): a SurfaceGui on a part's Front
        # face puts its canvas's left edge at the part's +X side. So each
        # slat's slice is counted from the strip's +X end.
        sl["fromM"] = run - sl.pop("startM") - chord - right_ext
    if report is not None:
        report["joinExtM"] = max(ext)
    return out, run


# --------------------------------------------------------------------------
# Writing the module


def num(x, n=4):
    v = f"{x:.{n}f}".rstrip("0").rstrip(".")
    return "0" if v in ("-0", "") else v


def vec(v, n=4):
    return "{ " + ", ".join(num(float(x), n) for x in v) + " }"


def write(shapes, text_only=False):
    lines = [
        "--!strict",
        "-- GENERATED by tools/cosmetics/strip_shapes.py. Do not edit by hand: change",
        "-- the car's windscreen spot (CarCosmeticMounts) or CosmeticsConfig.render's",
        "-- strip knobs and run the script again (tools/cosmetics/README.md).",
        "--",
        "-- Each car's sun strip as slats moulded to its windscreen (garage round 3",
        "-- §3), in car metres before the car's scale, the same frame as",
        "-- CarCosmeticMounts. A slat is a flat card centred at centreM; normal is",
        "-- its outward face (forward and up, the way the SurfaceGui reads), right",
        "-- the part's +X (toward the car's right). Slats run from the car's left",
        "-- (-X) to its right. widthM x heightM is a slat's size (overlap included).",
        "-- fromM is where its slice starts along the whole strip canvas (lengthM",
        "-- long), which reads from the car's right end, the reader's left seen",
        "-- from in front: a SurfaceGui on a part's Front face puts its canvas's",
        "-- left edge at the part's +X side. Each slat's SurfaceGui shows that",
        "-- slice, so text and gradient run on across slats.",
        "export type Slat = { centreM: { number }, normal: { number }, right: { number }, widthM: number, heightM: number, fromM: number }",
        "-- side is the windscreen spot's side the slats were fitted for (CarCosmeticMounts):",
        "-- the spec checks it still matches, so a changed spot without a rerun fails.",
        "export type Shape = { lengthM: number, heightM: number, side: \"inside\" | \"outside\", slats: { Slat } }",
        "",
        "local shapes: { [string]: Shape } = {",
    ]
    for car, (slats, length, note, side) in shapes.items():
        lines.append(f"\t-- {note}")
        lines.append(f"\t{car} = {{")
        lines.append(f"\t\tlengthM = {num(length)},")
        lines.append(f"\t\theightM = {num(slats[0]['heightM'])},")
        lines.append(f'\t\tside = "{side}",')
        lines.append("\t\tslats = {")
        for sl in slats:
            lines.append(
                "\t\t\t{ "
                + f"centreM = {vec(sl['centreM'])}, normal = {vec(sl['normal'])}, right = {vec(sl['right'])}, "
                + f"widthM = {num(sl['widthM'])}, heightM = {num(sl['heightM'])}, fromM = {num(sl['fromM'])}"
                + " },"
            )
        lines.append("\t\t},")
        lines.append("\t},")
    lines += ["}", "", "return shapes", ""]
    if text_only:
        return "\n".join(lines)
    with open(OUT, "w") as fh:
        fh.write("\n".join(lines))


def splice(shapes):
    """Replace or add only these cars' blocks in the existing file (--only),
    so cars whose glass is not in Studio's cache keep theirs."""
    full = write(shapes, text_only=True)
    old = open(OUT).read()
    for car in shapes:
        start = full.index(f"\t-- {car}:")
        block = full[start:full.index("\n\t},\n", start) + len("\n\t},\n")]
        if f"\n\t{car} = {{" in old:
            a = old.rindex("\n\t-- ", 0, old.index(f"\n\t{car} = {{")) + 1
            b = old.index("\n\t},\n", a) + len("\n\t},\n")
            old = old[:a] + block + old[b:]
        else:
            end = old.rindex("\n}")
            old = old[:end + 1] + block + old[end + 1:]
    open(OUT, "w").write(old)


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--only", nargs="+", help="fit only these cars and keep the others' shapes as they are")
    only = ap.parse_args().only
    spots = mount_spots()
    if only:
        spots = {car: spot for car, spot in spots.items() if car in only}
    shapes = {}
    for car, spot in spots.items():
        rep = {}
        slats, length = fit(car, spot, report=rep)
        ends = "ends at the glass's outline" if spot["ends"] == "mesh" else f"ends by eye ({num(spot['widthM'])} m wide)"
        note = f"{car}: {rep['where']}, {spot['side']} the glass, {ends}"
        if "MeshData" in rep["where"]:
            # A generated piece is placed by the working copy's catalog sizeM,
            # which may carry someone's uncommitted change (fix round 1, N4).
            note += "; placed by the working copy's CarCatalog.luau"
        shapes[car] = (slats, length, note, spot["side"])
        extra = f", spot gap {rep['spotGapM']:.3f}" if "spotGapM" in rep else ""
        print(f"{car:14s} {rep['where']}: {rep['faces']} screen faces, glass x {rep['x'][0]:.3f}..{rep['x'][1]:.3f}, "
              f"strip x {rep['ends'][0]:.3f}..{rep['ends'][1]:.3f}, {length:.3f} m long, smoothing {rep['fitErrM'] * 1000:.1f} mm, widest join overlap {2 * rep['joinExtM'] * 1000:.0f} mm{extra}")
    if only:
        splice(shapes)
    else:
        write(shapes)
    print(f"wrote {os.path.relpath(OUT, ROOT)}")


if __name__ == "__main__":
    main()
