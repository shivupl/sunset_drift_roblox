"""Steering wheels for the first-person view (README "First person
(CarCockpits)"): cut a store car's wheel out of the meshes it is built
into, so it can turn, and fit the column it turns about.

    python3 tools/carbody/wheelcut.py lekzas
    python3 tools/carbody/wheelcut.py kamri07 --fit   # fit only, no cut

Each source below is a catalog body piece drawn from a store mesh by id,
placed the way BodyBuilder places it: the mesh's bounding box stretched to
sizeM, turned by rotationDeg (CFrame.fromEulerAnglesYXZ) and centred on
offsetM, all in car space. Its wheel faces are taken either as whole
islands inside mesh-space boxes (the Lekzas: the wheel is islands of its
own in the cabin mesh) or as every face whose centre lies in a slab across
the wheel's plane (the Batrol: the rim is welded to the dash in its mesh,
so islands cannot part them). A source with "take": "all" is a wheel
already (the Kamri's three parts) and is only fitted.

What is left of a cut source ships as a generated piece under the source's
own name, and the wheel's faces as generated pieces named by "into" (one
per look: a wood rim and a black one cannot share a colour), all in
src/shared/CarMeshes/<Car>Cabin. Their catalog lines change from meshId to
mesh = "<Car>Cabin/<Piece>" with the sizeM and offsetM printed here, until
they are uploaded (README "Uploading generated pieces"). Normals are
computed per source vertex, area weighted, so the edges the store mesh
splits stay hard.

The fit printed at the end is the CarCockpits entry's wheel: the axis is
the direction the wheel's triangles spread least along (its face normal,
pointing back at the driver), the pivot the centre of their extent across
the face, the diameter that extent.

Each store mesh is kept as assets/cars/<car>/<piece>_source.obj, taken
once from Studio's mesh cache by its MeshSize (rbxcache.py; load the car's
meshes in Studio first), so a rerun needs no cache.
"""
import math
import os
import pickle
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import meshkit  # noqa: E402
import rbxcache  # noqa: E402
import storecar  # noqa: E402
import storescan  # noqa: E402

ROOT = storecar.ROOT

CARS = {
    # The black cabin mesh (Interieur Noir) carries the dash, the console and
    # the wheel. The wheel is four islands of its own there: the rim (576
    # faces), the hub (254) and two buttons (48 each), 926 of the mesh's
    # 1,826 faces; the column behind it stays.
    "lekzas": {
        "folder": "LekzasCabin",
        "title": "The Lekzas's cabin with its steering wheel cut out",
        "sources": [
            {
                "piece": "Interior_4", "meshId": 4719875427,
                "meshSize": (5.326062, 1.929722, 8.001907),
                "sizeM": (1.615, 0.5852, 2.4264), "offsetM": (0, 0.8255, 0.1528), "rotationDeg": (0, 0, 0),
                "take": {"islands": [((-1.80, -0.08, -2.13), (-0.57, 0.99, -1.55))]},
                "into": "SteeringWheel",
            },
        ],
    },
    # The wheel is in four meshes: the black rim, spokes and boss in the
    # cabin (Interior, welded to the dash), the two wood segments of the rim
    # (Interior_Wood), a plate on the hub and three small inlays on the rim
    # in the exterior trim (Trim, 12 faces; grey, so a piece of its own), and
    # four more inlays in the tinted glass (Glass, 5 faces; drawn with the
    # black rim). The plane is fitted to the wood segments: the
    # rim lies from 3 cm in front of it to 3 cm behind, the boss to 6 cm in
    # front, nothing else of the cabin within 6.5 cm of it inside the rim.
    "batrol": {
        "folder": "BatrolCabin",
        "title": "The Batrol's cabin, wood trim, trim and glass with its steering wheel cut out",
        "plane": {"centre": (-0.505, 1.174, -0.318), "normal": (0, 0.248, 0.969), "front": -0.065, "back": 0.04, "radiusM": 0.275},
        "sources": [
            {
                "piece": "Interior", "meshId": 8941480817,
                "meshSize": (11.659250, 4.579022, 5.986338),
                "sizeM": (3.4388, 1.3505, 1.7656), "offsetM": (0, 1.1363, 0.6884), "rotationDeg": (0, 90, 0),
                "take": "plane", "into": "SteeringWheel",
            },
            {
                "piece": "Interior_Wood", "meshId": 8941497189,
                "meshSize": (1.133438, 1.529349, 3.089493),
                "sizeM": (0.3343, 0.4511, 0.9112), "offsetM": (-0.2354, 1.1356, -0.4157), "rotationDeg": (0, 90, 0),
                "take": "plane", "into": "SteeringWheel_Wood",
            },
            {
                "piece": "Trim", "meshId": 8941396835,
                "meshSize": (16.575718, 5.151611, 6.975161),
                "sizeM": (4.8889, 1.5194, 2.0573), "offsetM": (-0.051, 1.0687, 0.0554), "rotationDeg": (0, 90, 0),
                "take": "plane", "into": "SteeringWheel_Trim",
            },
            {
                "piece": "Glass", "meshId": 8941426631,
                "meshSize": (15.881194, 3.972329, 6.068004),
                "sizeM": (4.684, 1.1716, 1.7897), "offsetM": (0.012, 1.2426, 0.0927), "rotationDeg": (0, 90, 0),
                "take": "plane", "into": "SteeringWheel",
            },
        ],
    },
    # The Kamri's wheel is parts of its own: the rim (P85) and the spoke bar
    # with its pad (P69). Nothing to cut. The maker's emblem on the pad
    # (P184) is dropped from the catalog like its other badges.
    "kamri07": {
        "sources": [
            {"piece": "P85", "meshId": 1578582244, "meshSize": (34.615501, 32.538002, 16.498699),
             "sizeM": (0.3417, 0.3212, 0.1629), "offsetM": (-0.3838, 0.8907, -0.4086), "rotationDeg": (0, -180, 0), "take": "all"},
            {"piece": "P69", "meshId": 1578584236, "meshSize": (28.150801, 11.729601, 7.253197),
             "sizeM": (0.2779, 0.1158, 0.0716), "offsetM": (-0.3838, 0.8581, -0.3959), "rotationDeg": (0, -180, 0), "take": "all"},
        ],
    },
}


def rotation_yxz(deg):
    rx, ry, rz = np.radians(deg)
    cx, sx, cy, sy, cz, sz = math.cos(rx), math.sin(rx), math.cos(ry), math.sin(ry), math.cos(rz), math.sin(rz)
    Ry = np.array([[cy, 0, sy], [0, 1, 0], [-sy, 0, cy]])
    Rx = np.array([[1, 0, 0], [0, cx, -sx], [0, sx, cx]])
    Rz = np.array([[cz, -sz, 0], [sz, cz, 0], [0, 0, 1]])
    return Ry @ Rx @ Rz


def source_mesh(car, src):
    """(points, faces, uvs or None) in mesh space, from the kept OBJ or,
    the first time, from Studio's cache by MeshSize."""
    path = os.path.join(ROOT, "assets", "cars", car, f"{src['piece']}_source.obj")
    if not os.path.exists(path):
        ms = np.array(src["meshSize"])
        idx = pickle.load(open(storescan.IDX, "rb")) if os.path.exists(storescan.IDX) else {}
        if not idx:
            storescan.cache_meshes()
            idx = pickle.load(open(storescan.IDX, "rb"))
        live = [(np.abs(np.array(v[0]) - ms).max() / ms.max(), p) for p, v in idx.items() if v and os.path.exists(p)]
        err, cache = min(live) if live else (1, None)
        if err >= 0.01:
            storescan.cache_meshes()
            idx = pickle.load(open(storescan.IDX, "rb"))
            live = [(np.abs(np.array(v[0]) - ms).max() / ms.max(), p) for p, v in idx.items() if v and os.path.exists(p)]
            err, cache = min(live)
        if err >= 0.01:
            sys.exit(f"{src['piece']} ({src['meshId']}) is not in Studio's cache: load the car's meshes in Studio first")
        P, F, T = rbxcache.decode(cache, with_uvs=True)
        rbxcache.write_obj(path, P, F, header=f"{car} {src['piece']}: store mesh {src['meshId']}, mesh space", uvs=T)
    return storecar.read_obj(path)


def car_space(P, src):
    """BodyBuilder's placement: bounding box to sizeM, turned, at offsetM."""
    lo, hi = P.min(0), P.max(0)
    unit = (P - (lo + hi) / 2) / np.maximum(hi - lo, 1e-9)
    return (unit * np.array(src["sizeM"])) @ rotation_yxz(src["rotationDeg"]).T + np.array(src["offsetM"])


def islands(P, F):
    """Island id per face: faces joined through shared positions (store
    meshes split vertices at seams, so weld by position first)."""
    _, weld = np.unique(np.round(P, 4), axis=0, return_inverse=True)
    weld = weld.ravel()
    parent = np.arange(weld.max() + 1)

    def find(a):
        while parent[a] != a:
            parent[a] = parent[parent[a]]
            a = parent[a]
        return a

    for a, b, c in weld[F]:
        for x, y in ((a, b), (b, c)):
            rx, ry = find(x), find(y)
            if rx != ry:
                parent[rx] = ry
    return np.array([find(a) for a in weld[F[:, 0]]])


def wheel_faces(P, F, C, src, plane):
    take = src["take"]
    if take == "all":
        return np.ones(len(F), dtype=bool)
    if take == "plane":
        c0, n = np.array(plane["centre"]), np.array(plane["normal"], dtype=float)
        n /= np.linalg.norm(n)
        mid = C[F].mean(axis=1) - c0
        d = mid @ n
        r = np.linalg.norm(mid - np.outer(d, n), axis=1)
        return (d >= plane["front"]) & (d <= plane["back"]) & (r <= plane["radiusM"])
    isl = islands(P, F)
    m = np.zeros(len(F), dtype=bool)
    for k in np.unique(isl):
        pts = P[F[isl == k].ravel()]
        for blo, bhi in take["islands"]:
            if np.all(pts.min(0) >= np.array(blo)) and np.all(pts.max(0) <= np.array(bhi)):
                m |= isl == k
    return m


def piece(name, parts):
    """A generated piece from (car-space points, uvs or None, faces) of one
    or more sources."""
    positions, normals, uvs, tris = [], [], [], []
    base = 0
    for C, T, F in parts:
        used = np.unique(F)
        remap = -np.ones(len(C), dtype=np.int64)
        remap[used] = np.arange(len(used)) + base
        fn = np.cross(C[F[:, 1]] - C[F[:, 0]], C[F[:, 2]] - C[F[:, 0]])
        acc = np.zeros((len(C), 3))
        for k in range(3):
            np.add.at(acc, F[:, k], fn)
        N = acc[used]
        N /= np.maximum(np.linalg.norm(N, axis=1, keepdims=True), 1e-12)
        positions.append(C[used])
        normals.append(N)
        uvs.append(T[used] if T is not None else np.zeros((len(used), 2)))
        tris.append(remap[F])
        base += len(used)
    pos = np.concatenate(positions)
    lo, hi = pos.min(0), pos.max(0)
    centre = (lo + hi) / 2
    t = np.concatenate(tris)
    corner = np.stack([np.stack([t[:, k]] * 3, axis=1) for k in range(3)], axis=1)
    return meshkit.Piece(name, pos - centre, np.concatenate(normals), np.concatenate(uvs), corner, hi - lo, centre)


def fit(tri):
    """(pivot, axis, diameter) of a wheel from its car-space triangles."""
    c = tri.mean(1)
    a = np.linalg.norm(np.cross(tri[:, 1] - tri[:, 0], tri[:, 2] - tri[:, 0]), axis=1) / 2
    mu = (c * a[:, None]).sum(0) / a.sum()
    X = c - mu
    _, v = np.linalg.eigh((X * a[:, None]).T @ X / a.sum())
    axis = v[:, 0] if v[2, 0] > 0 else -v[:, 0]
    u1, u2 = v[:, 2], v[:, 1]
    V = tri.reshape(-1, 3) - mu
    p1, p2 = V @ u1, V @ u2
    pivot = mu + u1 * (p1.min() + p1.max()) / 2 + u2 * (p2.min() + p2.max()) / 2
    return pivot, axis, max(p1.max() - p1.min(), p2.max() - p2.min())


def vec(v, n=4):
    return "{ " + ", ".join(storecar.num(x, n) for x in v) + " }"


def main():
    key = sys.argv[1]
    only_fit = "--fit" in sys.argv
    car = CARS[key]
    rest, wheel, wheel_tris = [], {}, []
    for src in car["sources"]:
        P, F, T = source_mesh(key, src)
        C = car_space(P, src)
        m = wheel_faces(P, F, C, src, car.get("plane"))
        wheel_tris.append(C[F[m]])
        print(f"{src['piece']}: {int(m.sum())} of {len(F)} faces are the wheel")
        if src["take"] != "all":
            rest.append(piece(src["piece"], [(C, T, F[~m])]))
            wheel.setdefault(src["into"], []).append((C, T, F[m]))
    pivot, axis, diameter = fit(np.concatenate(wheel_tris))
    tilt = math.degrees(math.asin(axis[1]))
    print(f"fit: pivotM = {vec(pivot)}, axis = {vec(axis)}, diameter {diameter:.3f} m, {tilt:.1f} degrees back")
    if only_fit or not rest:
        return
    generated = rest + [piece(name, parts) for name, parts in wheel.items()]
    folder = os.path.join(ROOT, "src", "shared", "CarMeshes", car["folder"])
    meshkit.write_luau(folder, "wheelcut", [car["title"] + ".", "Car space, metres."], generated)
    for g in generated:
        print(f'{{ name = "{g.name}", mesh = "{car["folder"]}/{g.name}", sizeM = {vec(g.size)}, offsetM = {vec(g.offset)} }}  -- {g.triangles} triangles')


if __name__ == "__main__":
    main()
