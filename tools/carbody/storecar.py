"""Store cars into game bodies, the same way for every car (README.md).

    python3 tools/carbody/storecar.py kruzer80

Input, assets/cars/<car>/parts.json: every visible part of the store model as
Studio has it (dumped in Edit with game:GetObjects, never inserted): index,
name, parent, class, CFrame components, Size, colour, material,
transparency, and for MeshParts the mesh id, texture id, MeshSize and the
triangle count at full detail (from Studio's cache, rbxcache.py).

For each car, CARS below says what goes (roof gear, badges, plain parts
and unions, which the body builder cannot use), which texture ids to drop
(stickers, plates), the role of every part (body standard), which four
parts are the tyres, and the real wheelbase. The script then:

  1. finds the four wheel centres; the car's forward, up and right axes
     come from them, so a model built pitched or turned is levelled and
     turned to face -Z;
  2. scales the model so the wheel centres sit on the real wheelbase, with
     the origin on the ground under the wheelbase centre (RIG_SPEC.md);
  3. writes every kept part as a body piece referencing its store mesh id,
     and the Batrol's wheel (the store wheels are far heavier), scaled to
     this car's tyre;
  4. cuts badges out of meshes that must stay (CARS "cuts"): the store mesh
     is saved as assets/cars/<car>/<piece>_source.obj (rbxcache.py), the
     connected islands inside a badge box are removed, and the rest ships as
     a generated piece (src/shared/CarMeshes/<Car>) plus <piece>.obj for
     Studio's 3D Importer (README.md);
  5. writes assets/cars/<car>/catalog.luau with the pieces and the rig
     numbers, and prints the triangle count before and after.
"""
import json
import math
import os
import sys

import numpy as np

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))

# The Batrol's wheel (tools/carbody/batrol.py), in its wheel space, sized for
# a 0.428 m tyre radius: 382 + 4,414 + 1,510 triangles.
BATROL_RADIUS = 0.428
BATROL_WHEEL = [
    {"name": "Rim_Face", "meshId": 8941522368, "color": (248, 248, 248), "material": "SmoothPlastic", "sizeM": (0.5341, 0.508, 0.0382), "offsetM": (-0.1366, 0.022, -0.0005), "triangles": 382},
    {"name": "Rim", "meshId": 8941509678, "color": (202, 203, 209), "material": "SmoothPlastic", "sizeM": (0.5656, 0.5675, 0.3144), "offsetM": (-0.0011, 0.0038, -0.0005), "triangles": 4414},
    {"name": "Tyre", "meshId": 8941514489, "color": (25, 25, 25), "material": "Rubber", "sizeM": (0.8555, 0.856, 0.2888), "offsetM": (0, 0, 0), "triangles": 1510},
]


def role_kruzer80(p):
    col, tr, tex = tuple(p["col"]), p["tr"], p.get("tex")
    if p["p"] == "Shut":
        return "Spare", {}
    # The real lamp lenses, textured with photos of the lamps: all of part 74
    # is the two headlamps, all of part 97 the two tail clusters (CarLamps
    # lights them by clearing the texture).
    if p["i"] == 74:
        return "HeadLamps", {"castShadow": False}
    if p["i"] == 97:
        return "TailLamps", {"castShadow": False}
    if 0 < tr < 1:
        return "Glass", {"castShadow": False}
    if tex in (7179126327, 2972069630) or col == (139, 131, 112) or p["p"] == "SW":
        return "Interior", {"castShadow": False}
    if col == (248, 248, 248):
        return "Body", {"paint": True}
    if col == (17, 17, 17):
        return "Trim", {}
    return "Chrome", {}


def role_kruzer100(p):
    n, tr = p["n"].lower(), p["tr"]
    if n == "primary":
        return "Body", {"paint": True}
    if n == "krasnoesteklo":
        return "TailLamps", {"castShadow": False}
    if 0 < tr < 1 or n.startswith("vehicle_generic_glass") or n == "gredazadstdlt":
        return "Glass", {"castShadow": False}
    if "front light" in n:
        return "HeadLamps", {"castShadow": False}
    if "rear light" in n:
        return "TailLamps", {"castShadow": False}
    if n.startswith("foglight"):
        return "FogLamps", {"castShadow": False}
    if n == "vehiclelights":
        return "Indicators", {"castShadow": False}
    if n.startswith("lcx100") or n == "lcx100dolmattxt" or p["p"] in ("movsteer_0.5", "brake", "throttle", "handbrake", "shifter", "chassis"):
        return "Interior", {"castShadow": False}
    if n == "silver2":
        return "Chrome", {}
    return "Trim", {}


def role_lekzas(p):
    n, tr = p["n"].replace("Meshes/", ""), p["tr"]
    if n.startswith("Paint"):
        return "Body", {"paint": True}
    lamp = {"F Glass (1)": "HeadLamps", "Light(s) CDCBCB": "ReverseLamps"}
    if n in lamp:
        return lamp[n], {"castShadow": False}
    if n.startswith("Light(s) C44747"):  # the tail lamps and the high brake light
        return "TailLamps", {"castShadow": False}
    if n.startswith("Light(s) C8AA6E") or n.startswith("L C8AA6E"):  # indicators and side markers
        return "Indicators", {"castShadow": False}
    if n in ("Light(s) 6A6A6A", "Light(s) 6A6A6A.007"):  # the two low in the bumper
        return "FogLamps", {"castShadow": False}
    if n.startswith("Light(s) 6A6A6A"):  # headlamp reflectors behind the lens
        return "Trim", {}
    if 0 < tr < 1:
        return "Glass", {"castShadow": False}
    if n.startswith("Interieur") or n.startswith("C4BEB9"):
        return "Interior", {"castShadow": False}
    if n.startswith("Dessous"):
        return "Underbody", {}
    if "Chrome" in n or n == "A6A6A6":
        return "Chrome", {}
    return "Trim", {}


KROWNVIK_INTERIOR = {9, 33, 36, 49, 54, 57, 65, 66, 77, 100, 101, 102, 103, 104, 106, 107, 108, 109, 111, 112, 113, 114, 115, 116}


def role_krownvik(p):
    n, tr, col, mat = p["n"], p["tr"], tuple(p["col"]), p["mat"]
    # The lamps are the textured lamp faces (the tail-light mesh, 91, and the
    # headlamp and corner-lamp faces split out of the grille, "cuts"). The
    # kit's own lamp parts (F, FLI, FRI, R, RLI, RRI) are plain boxes it hid
    # inside them to carry its lights: trim here. RV, beside the plate, is
    # the reverse lamp's own shape.
    # The clear covers over the headlamps (124) and the reverse lamps (37)
    # are the whole lamp face: they light with them.
    if p["i"] == 91:
        return "TailLamps", {"castShadow": False}
    if p["i"] == 124:
        return "HeadLamps", {"castShadow": False}
    if n == "RV" or p["i"] == 37:
        return "ReverseLamps", {"castShadow": False}
    if n == "Color":
        return "Body", {"paint": True}
    if 0 < tr < 1:  # windows, and the clear covers over the lamps
        return "Glass", {"castShadow": False}
    if p["i"] in KROWNVIK_INTERIOR:
        return "Interior", {"castShadow": False}
    if n == "Chrome" or col == (202, 203, 209):
        return "Chrome", {}
    if mat == "Fabric" and p["i"] == 97:  # the floor pan and arches, one mesh
        return "Underbody", {}
    return "Trim", {}


CARS = {
    "kruzer80": {
        "title": "The early-90s Japanese full-size 4x4 (store 13118106368), with its interior",
        "wheelbaseM": 2.85,
        # Roof: rack, storage box, jerry cans, spare, light bar and LEDs. "h":
        # a cluster of plain parts and unions on the dash, which the builder
        # cannot use. The tailgate spare wheel ("Shut", 15,521 triangles)
        # stays: the owner wants it.
        "dropGroups": {"Offroader Roof Rack", "Jerry Cans", "Spare Tire", "Light Bar", "LED Lights", "h"},
        # The wheels (body pieces no more: one of them becomes wheelPieces),
        # the grille badge (95), the tailgate emblem (45), the lettering strip
        # over the plate (37), the 4WD and grade badges beside it (39), and
        # the lettering on the rear mudflaps (94).
        "dropParts": {46, 47, 48, 49, 50, 51, 52, 53, 54, 55, 56, 57, 95, 45, 37, 39, 94},
        # The flame stripes.
        "dropTextures": {7183908487},
        # The door mouldings carry the side lettering in the body texture:
        # plain black instead.
        "plain": {6: (17, 17, 17), 13: (17, 17, 17), 22: (17, 17, 17), 30: (17, 17, 17)},
        "tyres": [46, 49, 52, 55],
        # The front-left wheel (tyre, rim, hub), mirrored to all four.
        "wheelParts": {46: "Tyre", 47: "Rim", 48: "Rim_Hub"},
        "frontPart": 90,  # the front bumper
        # The tailgate spare is a full road tyre (0.93 m) and hid most of the
        # right tail lamp. Shrunk to 0.8 about its centre, drawn in towards
        # the door (pivotZ, the door face) and moved 6.3 cm inboard, it fits
        # between the plate mount and the lamp (owner, 2026-09-25).
        "spare": {"parts": {112, 113, 114, 115}, "tyre": 114, "scale": 0.8, "pivotZ": 2.40, "shiftM": (-0.063, 0, 0)},
        # The plate mount, a bare black block that read as a hole: body
        # colour until the game's own plates go on it.
        "paintParts": {36},
        "role": role_kruzer80,
        "paint": (236, 236, 232),
    },
    "lekzas": {
        "title": "The early-2000s Japanese luxury saloon (store 5405292580), with its interior",
        "wheelbaseM": 2.925,
        "dropGroups": set(),
        # The wheels (one becomes wheelPieces) and the brake calipers, which
        # are fixed to the hub and would spin as wheel pieces.
        "dropParts": {3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 17, 18, 19, 20, 21, 23, 24, 25, 26, 27, 2, 14, 16, 28},
        "dropTextures": set(),
        "tyres": [6, 12, 20, 26],
        # The front-left wheel: tyre, rim, centre cap (plain), nuts, disc.
        "wheelParts": {6: "Tyre", 7: "Rim", 3: "Rim_Cap", 4: "Rim_Nuts", 5: "Rim_Disc"},
        "frontPart": 63,  # the amber strip across the front bumper
        # The chrome (part 40: grille slats, window trim, door handles, bumper
        # strips) carries the maker's grille emblem, boot emblem and the two
        # boot scripts as islands of their own. Boxes in the mesh's space.
        "cuts": {
            40: {
                "source": "chrome_source.obj",
                "badges": [
                    ((-0.25, -0.80, -7.95), (0.25, -0.45, -7.65)),  # grille emblem, 652 triangles
                    ((-2.05, -0.10, 7.60), (-1.30, 0.06, 7.85)),  # maker's name, left of the boot
                    ((1.40, -0.10, 7.60), (2.02, 0.06, 7.85)),  # model name, right of the boot
                    ((-0.15, -0.05, 7.75), (0.15, 0.20, 7.90)),  # boot emblem
                ],
            },
        },
        "role": role_lekzas,
        "paint": (211, 190, 150),
    },
    "krownvik": {
        "title": "The mid-2000s American full-size V8 saloon (store 2930898738), with its interior",
        "wheelbaseM": 2.913,
        "dropGroups": set(),
        # The wheels (the front-left becomes wheelPieces), their centre caps
        # (the maker's oval, all of each cap), the tiny badge in the middle
        # of the steering wheel (38), and parts that are invisible in the
        # store model (plate lamps and a plate backing, fully transparent),
        # and the model name in raised letters on the boot panel (35: 672
        # triangles in a part 15 cm wide).
        "dropParts": {130, 131, 132, 133, 135, 136, 137, 138, 140, 141, 142, 143, 145, 146, 147, 148, 38, 31, 88, 123, 35},
        "dropTextures": set(),
        "tyres": [133, 136, 140, 147],
        "wheelParts": {133: "Tyre", 132: "Rim", 131: "Rim_Disc"},
        "frontPart": 83,  # the headlamps
        # The maker's oval is painted into the shared texture 1079416334
        # (u 0.147-0.426, v 0.626-0.742 from the top left): on the grille
        # (part 12, 52 of 200 faces) and the boot badge (part 30, 14 of 50).
        "cuts": {
            # The headlamps and the corner lamps are photos in the same
            # texture and in the same mesh as the grille: their faces become
            # the HeadLamps and Indicators pieces (the real lamp shapes).
            12: {
                "source": "grille_source.obj",
                "uvBoxes": [(0.147, 0.626, 0.426, 0.742)],
                "split": [
                    {"role": "HeadLamps", "uvBoxes": [(0.40, 0.60, 0.73, 0.76)]},
                    {"role": "Indicators", "uvBoxes": [(0.0, 0.49, 0.345, 0.625)]},
                ],
            },
            30: {"source": "bootbadge_source.obj", "uvBoxes": [(0.147, 0.626, 0.426, 0.742)]},
        },
        "role": role_krownvik,
        "paint": (240, 240, 236),
    },
    "kruzer100": {
        "title": "The late-90s Japanese full-size 4x4 (store 12753900235), leather interior",
        "wheelbaseM": 2.85,
        "dropGroups": set(),
        # The plate (99); the wheels (one becomes wheelPieces); the fixed
        # brake parts behind them, which would spin as wheel pieces (64, 67,
        # 69, 70).
        "dropParts": {99, 65, 66, 68, 71, 64, 67, 69, 70},
        "dropTextures": set(),
        "tyres": [65, 66, 68, 71],
        "frontPart": 104,  # the front bumper
        "wheelParts": {65: "Tyre"},
        "role": role_kruzer100,
        "paint": (40, 52, 60),
    },
}


def euler_yxz(R):
    """Roblox CFrame:ToEulerAnglesYXZ for a rotation matrix (R = Ry Rx Rz)."""
    rx = math.asin(max(-1.0, min(1.0, -R[1, 2])))
    ry = math.atan2(R[0, 2], R[2, 2])
    rz = math.atan2(R[1, 0], R[1, 1])
    return np.degrees([rx, ry, rz])


def num(x, n=4):
    s = f"{x:.{n}f}".rstrip("0").rstrip(".")
    return "0" if s in ("-0", "") else s


def vec(v, n=4):
    return "{ " + ", ".join(num(float(x), n) for x in v) + " }"


def colour(rgb):
    return f"Color3.fromRGB({rgb[0]}, {rgb[1]}, {rgb[2]})"


def read_obj(path):
    """(points, faces, uvs or None). uvs per point, v down like the cache
    (rbxcache.write_obj writes one texture coordinate per point)."""
    P, F, T = [], [], []
    for line in open(path):
        if line.startswith("v "):
            P.append([float(v) for v in line.split()[1:4]])
        elif line.startswith("vt "):
            u, v = (float(x) for x in line.split()[1:3])
            T.append([u, 1 - v])
        elif line.startswith("f "):
            F.append([int(v.split("/")[0]) - 1 for v in line.split()[1:4]])
    return np.array(P), np.array(F, dtype=np.int64), (np.array(T) if len(T) == len(P) else None)


def cut_faces(folder, cut):
    """The source mesh of a CARS "cuts" entry, split: (points, texture
    coordinates or None, faces to keep, [(role, faces)] for each "split",
    faces before). Badge islands inside a "badges" box and faces textured
    from a "uvBoxes" box of the texture (u, v from the top left) are cut;
    faces textured from a "split" entry's boxes become pieces of their own
    (lamps painted into the same mesh as the grille, the Krown Vik)."""
    P, F, T = read_obj(os.path.join(folder, cut["source"]))
    before_n = len(F)
    # Islands: faces joined through shared positions (store meshes split
    # vertices at seams, so weld by position first).
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
    island = np.array([find(a) for a in weld[F[:, 0]]])
    gone = np.zeros(len(F), dtype=bool)
    for isl in np.unique(island):
        pts = P[F[island == isl].ravel()]
        lo, hi = pts.min(0), pts.max(0)
        for blo, bhi in cut.get("badges", []):
            if np.all(lo >= np.array(blo)) and np.all(hi <= np.array(bhi)):
                gone |= island == isl

    def in_boxes(boxes):
        m = np.zeros(len(F), dtype=bool)
        if T is not None:
            c = T[F].mean(axis=1)
            for u0, v0, u1, v1 in boxes:
                m |= (c[:, 0] >= u0) & (c[:, 0] <= u1) & (c[:, 1] >= v0) & (c[:, 1] <= v1)
        return m

    gone |= in_boxes(cut.get("uvBoxes", []))
    taken = gone.copy()
    splits = []
    for sp in cut.get("split", []):
        m = in_boxes(sp["uvBoxes"]) & ~taken
        taken |= m
        splits.append((sp["role"], F[m]))
    return P, T, F[~taken], splits, before_n


def make_piece(name, P, T, F, p, B, origin, mps):
    """A generated piece from store mesh faces, in car space."""
    import meshkit

    # Mesh space to world (the part's CFrame, mesh scaled to its Size) to car space.
    scale = np.array(p["s"], dtype=float) / np.array(p["ms"], dtype=float)
    Rw = np.array(p["cf"][3:], dtype=float).reshape(3, 3)
    world = (P * scale) @ Rw.T + np.array(p["cf"][:3], dtype=float)
    car = (world - origin) @ B * mps
    used = np.unique(F)
    remap = -np.ones(len(car), dtype=np.int64)
    remap[used] = np.arange(len(used))
    car, F = car[used], remap[F]
    uvs = T[used] if T is not None else np.zeros((1, 2))
    # Smooth normals, area weighted, shared across split seams.
    fn = np.cross(car[F[:, 1]] - car[F[:, 0]], car[F[:, 2]] - car[F[:, 0]])
    _, w2 = np.unique(np.round(car, 5), axis=0, return_inverse=True)
    w2 = w2.ravel()
    acc = np.zeros((w2.max() + 1, 3))
    for k in range(3):
        np.add.at(acc, w2[F[:, k]], fn)
    N = acc[w2]
    N /= np.maximum(np.linalg.norm(N, axis=1, keepdims=True), 1e-12)
    lo, hi = car.min(0), car.max(0)
    centre = (lo + hi) / 2
    uv_index = (lambda k: F[:, k]) if T is not None else (lambda k: np.zeros(len(F), dtype=np.int64))
    tris = np.stack([np.stack([F[:, k], F[:, k], uv_index(k)], axis=1) for k in range(3)], axis=1)
    return meshkit.Piece(name, car - centre, N, uvs, tris, hi - lo, centre)


def build(key):
    car = CARS[key]
    folder = os.path.join(ROOT, "assets", "cars", key)
    parts = json.load(open(os.path.join(folder, "parts.json")))
    by = {p["i"]: p for p in parts}

    # Wheel centres, and the car's axes from them.
    C = np.array([by[i]["cf"][:3] for i in car["tyres"]], dtype=float)
    radius_st = float(np.mean([max(by[i]["s"]) / 2 for i in car["tyres"]]))
    centre = C.mean(axis=0)
    # Pair the tyres into axles along their longest horizontal spread; the
    # axle nearer CARS[...]["frontPart"] is the front.
    d = (C - centre)[:, [0, 2]]
    along = d @ np.linalg.svd(d)[2][0]
    groups = [C[along > 0], C[along <= 0]]
    nose = np.array(by[car["frontPart"]]["cf"][:3], dtype=float)
    groups.sort(key=lambda g: np.linalg.norm(g.mean(axis=0) - nose))
    front, rear = groups
    fwd = front.mean(axis=0) - rear.mean(axis=0)
    wheelbase_st = float(np.linalg.norm(fwd))
    fwd /= wheelbase_st
    side = front[0] - front[1]
    up = np.cross(side, fwd)
    up /= np.linalg.norm(up)
    if up[1] < 0:
        up = -up
    right = np.cross(fwd, up)
    right /= np.linalg.norm(right)
    fwd = np.cross(up, right)
    # Car space: +X right, +Y up, +Z back (forward is -Z).
    B = np.stack([right, up, -fwd], axis=1)
    mps = car["wheelbaseM"] / wheelbase_st
    origin = centre - up * radius_st
    track_m = float(np.mean([abs((g[0] - g[1]) @ right) for g in (front, rear)])) * mps

    def place(p):
        R = B.T @ np.array(p["cf"][3:], dtype=float).reshape(3, 3)
        pos = B.T @ (np.array(p["cf"][:3], dtype=float) - origin) * mps
        return R, pos

    spare = car.get("spare")
    if spare:
        pivot = place(by[spare["tyre"]])[1].copy()
        pivot[2] = spare["pivotZ"]

    kept, dropped = [], []
    before = sum(p.get("tris", 0) for p in parts)
    for p in parts:
        gone = p["p"] in car["dropGroups"] or p["i"] in car["dropParts"] or p["c"] != "MeshPart"
        (dropped if gone else kept).append(p)

    lines = []
    names = {}
    tris_after = 0
    lo = np.full(3, np.inf)
    hi = np.full(3, -np.inf)
    generated = []
    for p in kept:
        role, opts = car["role"](p)
        names[role] = names.get(role, 0) + 1
        name = role if names[role] == 1 else f"{role}_{names[role]}"
        R, pos = place(p)
        if p["i"] in car.get("cuts", {}):
            P, T, keep, splits, before_n = cut_faces(folder, car["cuts"][p["i"]])
            parts_out = [(name, keep, opts)]
            for srole, sfaces in splits:
                names[srole] = names.get(srole, 0) + 1
                sname = srole if names[srole] == 1 else f"{srole}_{names[srole]}"
                parts_out.append((sname, sfaces, {"castShadow": False}))
            for pname, pfaces, popts in parts_out:
                piece = make_piece(pname, P, T, pfaces, p, B, origin, mps)
                generated.append(piece)
                lo, hi = np.minimum(lo, piece.offset - piece.size / 2), np.maximum(hi, piece.offset + piece.size / 2)
                tex = f"textureId = {p['tex']}, " if p.get("tex") and p["tex"] not in car["dropTextures"] else ""
                shadow = "castShadow = false, " if popts.get("castShadow") is False else ""
                lines.append(
                    "{ " + f'name = "{pname}", mesh = "{key.capitalize()}/{pname}", {tex}color = {colour(p["col"])}, '
                    f"material = Enum.Material.{p['mat']}, {shadow}sizeM = {vec(piece.size)}, offsetM = {vec(piece.offset)}" + " },"
                )
                tris_after += piece.triangles
            print(f"{name}: {before_n:,} faces -> " + ", ".join(f"{n} {len(f):,}" for n, f, _ in parts_out))
            continue
        size = np.array(p["s"], dtype=float) * mps
        if spare and p["i"] in spare["parts"]:
            pos = pivot + (pos - pivot) * spare["scale"] + np.array(spare["shiftM"])
            size = size * spare["scale"]
        if p["i"] in car.get("paintParts", ()):
            opts = {"paint": True}
        corners = np.array([[sx, sy, sz] for sx in (-1, 1) for sy in (-1, 1) for sz in (-1, 1)]) * size / 2
        w = corners @ R.T + pos
        lo, hi = np.minimum(lo, w.min(0)), np.maximum(hi, w.max(0))
        f = [f'name = "{name}"', f"meshId = {p['mesh']}"]
        tex = p.get("tex")
        if p["i"] in car.get("plain", {}):
            p = dict(p, col=car["plain"][p["i"]])
            tex = None
            opts = {}
        if tex and tex not in car["dropTextures"]:
            f.append(f"textureId = {tex}")
        if opts.get("paint"):
            f.append("paint = true")
        else:
            f.append(f"color = {colour(p['col'])}")
            f.append(f"material = Enum.Material.{p['mat']}")
        if p["tr"] > 0:
            f.append(f"transparency = {num(p['tr'], 2)}")
        if opts.get("castShadow") is False:
            f.append("castShadow = false")
        f.append(f"sizeM = {vec(size)}")
        f.append(f"offsetM = {vec(pos)}")
        rot = euler_yxz(R)
        if np.abs(rot).max() > 1e-3:
            f.append(f"rotationDeg = {vec(rot, 3)}")
        lines.append("{ " + ", ".join(f) + " },")
        tris_after += p.get("tris", 0)

    if generated:
        import meshkit

        meshkit.write_luau(
            os.path.join(ROOT, "src", "shared", "CarMeshes", key.capitalize()),
            "storecar",
            [f"{car['title']}: store meshes with the badges cut out.", "Car space, metres."],
            generated,
        )
        # The same pieces for Studio's 3D Importer: an uploaded mesh id needs no
        # EditableMesh (which a live game only gets with the owner ID verified).
        for piece in generated:
            meshkit.write_obj(os.path.join(folder, piece.name + ".obj"), [piece], offsets=False)

    k = radius_st * mps / BATROL_RADIUS
    wlines = []
    if car.get("wheelParts"):
        # Wheel space: origin at the wheel centre, axle along X, authored as
        # a left wheel (outer face -X), which car space already is for a
        # left wheel.
        hub = np.array(by[car["tyres"][0]]["cf"][:3], dtype=float)
        for i, wname in car["wheelParts"].items():
            p = by[i]
            R = B.T @ np.array(p["cf"][3:], dtype=float).reshape(3, 3)
            pos = B.T @ (np.array(p["cf"][:3], dtype=float) - hub) * mps
            f = [f'name = "{wname}"', f"meshId = {p['mesh']}"]
            if p.get("tex") and p["tex"] not in car["dropTextures"]:
                f.append(f"textureId = {p['tex']}")
            f.append(f"color = {colour(p['col'])}")
            f.append(f"material = Enum.Material.{p['mat']}")
            f.append(f"sizeM = {vec(np.array(p['s'], dtype=float) * mps)}")
            f.append(f"offsetM = {vec(pos)}")
            f.append(f"rotationDeg = {vec(euler_yxz(R), 3)}")
            wlines.append("{ " + ", ".join(f) + " },")
            tris_after += 4 * p.get("tris", 0)
        wheel_width = float(min(by[car["tyres"][0]]["s"])) * mps
    else:
        for w in BATROL_WHEEL:
            wlines.append(
                "{ " + f'name = "{w["name"]}", meshId = {w["meshId"]}, color = {colour(w["color"])}, '
                f'material = Enum.Material.{w["material"]}, sizeM = {vec(np.array(w["sizeM"]) * k)}, '
                f'offsetM = {vec(np.array(w["offsetM"]) * k)}, rotationDeg = {{ 0, 90, 0 }}' + " },"
            )
            tris_after += 4 * w["triangles"]
        wheel_width = BATROL_WHEEL[2]["sizeM"][2] * k

    rig = {
        "wheelbaseM": car["wheelbaseM"],
        "trackWidthM": round(track_m, 4),
        "wheelRadiusM": round(radius_st * mps, 4),
        "wheelWidthM": round(wheel_width, 4),
    }
    out = [
        f"-- GENERATED by tools/carbody/storecar.py {key}: paste into CarCatalog.{key}.",
        f"-- rig: {rig}",
        f"-- body: x {lo[0]:.3f}..{hi[0]:.3f}, y {lo[1]:.3f}..{hi[1]:.3f}, z {lo[2]:.3f}..{hi[2]:.3f} m; {mps:.5f} m per model stud",
        f"-- triangles: {before:,} in the store model, {tris_after:,} here ({len(kept)} parts kept, {len(dropped)} dropped)",
        "pieces = {",
    ]
    out += ["\t" + l for l in lines] + ["},", "wheelPieces = {"] + ["\t" + l for l in wlines] + ["},"]
    with open(os.path.join(folder, "catalog.luau"), "w") as fh:
        fh.write("\n".join(out) + "\n")
    print("\n".join(out[:4]))


if __name__ == "__main__":
    for key in sys.argv[1:] or list(CARS):
        build(key)
