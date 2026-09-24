"""The Batrol (the Gulf's own name for it): a late-90s Japanese
full-size 4x4 from the Creator Store (asset 8941542327, by IamNobody7, no
scripts), debadged and laid out in car space for its catalog entry.

    python3 tools/carbody/batrol.py

The store model is one MeshPart per material (Body, Glass, Chrome...), so
the pieces keep the store meshes, referenced by id, with one exception: the
maker's badges are geometry inside the chrome mesh (grille and tailgate), so
that mesh is rebuilt without them as a generated piece (src/shared/CarMeshes/
Batrol, decoded by MeshData). Its source, assets/cars/batrol/chrome_source.obj,
came out of Studio's asset cache (tools/carbody/rbxcache.py).

Inputs, both in assets/cars/batrol:
  parts.json         every MeshPart as the store model has it (Studio dump):
                     mesh id, texture, colour, material, transparency, Size,
                     position, rotation, MeshSize, and the rear-left wheel.
  chrome_source.obj  the chrome mesh in mesh space.

Outputs:
  src/shared/CarMeshes/Batrol   the debadged chrome.
  assets/cars/batrol/Chrome.obj   the same, for Studio's 3D Importer.
  assets/cars/batrol/catalog.luau   the body and rig numbers for CarCatalog.

Piece names follow the body standard (tools/carbody/README.md): a role, then
an optional detail after an underscore, so later customisation (paint, lamp
colours, plates) finds its pieces the same way on every car.
"""
import json
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(__file__))
import meshkit  # noqa: E402

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
ASSETS = os.path.join(ROOT, "assets", "cars", "batrol")

# The real car's wheelbase (the long five-door). The store model's wheel centres are 12.163 studs
# apart, so this sets metres per model stud (0.2442): 5.06 m long, 1.87 m
# tall, like the real car.
WHEELBASE_M = 2.97

# Store part -> (piece name, how it is drawn). None: removed.
#   paint: takes the car's paint. Others keep the store colour and material.
ROLES = {
    "Body (14)": ("Body", {"paint": True}),
    "Panel (8)": ("Body_Scoop", {"paint": True}),  # the bonnet scoop
    "Tire1 (1)": ("Body_Caps", {"paint": True}),  # mirror caps and the spare wheel cover
    "Glass (11)": ("Glass", {"castShadow": False}),
    "Headlight (14)": ("HeadLamps", {"castShadow": False}),  # the lenses; the housing behind is Trim_Housings
    "Headlight (15)": ("Indicators", {"castShadow": False}),
    "Light (11)": ("FogLamps", {"castShadow": False}),
    "Tail (15)": ("TailLamps", {"castShadow": False}),
    "Tail1 (3)": ("ReverseLamps", {"castShadow": False}),
    "Chrome (11)": ("Chrome", {"generated": True}),  # grille surround, handles, trim: badges cut
    "Chrome1 (6)": ("Chrome_Upper", {}),
    "Grill (10)": ("Trim_Grille", {}),
    "Grill1 (4)": ("Trim_LowerGrille", {}),
    "Black (14)": ("Trim_Windows", {}),
    "Black1 (14)": ("Trim", {}),
    "Body1 (8)": ("Trim_Housings", {}),
    "Underbody (9)": ("Underbody", {}),
    "Underbody1 (4)": ("Underbody_Floor", {}),
    "Shocks": ("Underbody_Shocks", {}),
    "Interior (15)": ("Interior", {"castShadow": False}),
    "Dash (3)": ("Interior_Dash", {"castShadow": False}),
    "Wood (1)": ("Interior_Wood", {"castShadow": False}),
    "Red (7)": ("Interior_Red", {"castShadow": False}),
    "Logo (7)": None,  # lettering inside the cabin: gone
}
WHEEL_ROLES = {
    "Tire (21)": ("Tyre", {"color": [25, 25, 25], "material": "Rubber"}),
    "Rim (28)": ("Rim", {}),
    "RR (13)": ("Rim_Face", {}),
}

# Badge faces in the chrome mesh, mesh space (+X is the nose, +Y up, Z
# across; the part is turned 90 degrees so +X becomes car -Z). A face goes
# when its centroid is inside the box and it is small: the grille frame's
# long bars around the front badge stay.
BADGES = [
    # The grille badge: ring and bar, 0.52 x 0.66 in the centre opening.
    {"lo": (7.8, 0.07, -0.37), "hi": (9.0, 0.60, 0.20), "maxExtent": 0.6},
    # The tailgate badge, left of centre: a flat ring 0.27 x 0.31.
    {"lo": (-9.0, 0.95, -1.65), "hi": (-8.0, 1.30, -1.25), "maxExtent": 0.6},
]


def rot_y(deg):
    t = np.radians(deg)
    c, s = np.cos(t), np.sin(t)
    # Roblox CFrame.Angles(0, t, 0): x' = x c + z s, z' = -x s + z c
    return np.array([[c, 0, s], [0, 1, 0], [-s, 0, c]])


def read_obj(path):
    P, F = [], []
    for line in open(path):
        if line.startswith("v "):
            P.append([float(v) for v in line.split()[1:4]])
        elif line.startswith("f "):
            F.append([int(v.split("/")[0]) - 1 for v in line.split()[1:4]])
    return np.array(P), np.array(F, dtype=np.int64)


def num(x, n=4):
    s = f"{x:.{n}f}".rstrip("0").rstrip(".")
    return "0" if s in ("-0", "") else s


def vec(v, n=4):
    return "{ " + ", ".join(num(x, n) for x in v) + " }"


def main():
    parts = json.load(open(os.path.join(ASSETS, "parts.json")))
    body = [p for p in parts if "wheel" not in p]
    wheel = [p for p in parts if p.get("wheel") == "RL"]
    tyre = next(p for p in wheel if p["name"].endswith("Tire (21)"))

    # Car-space origin: the body's centreline (x), the wheelbase centre (z),
    # the ground (y). Wheel centres from the store model's tyres: rear axle
    # z -5.4698, front -17.633 (the fronts are steered, so their x is off).
    axle_rear, axle_front = -5.4698, -17.633
    mps = WHEELBASE_M / (axle_rear - axle_front)
    tyre_c = np.array(tyre["pos"])
    tyre_r = tyre["size"][1] / 2
    centre_x = next(p for p in body if p["name"].endswith("Body (14)"))["pos"][0]
    origin = np.array([centre_x, tyre_c[1] - tyre_r, (axle_rear + axle_front) / 2])
    track = 2 * (centre_x - tyre_c[0]) * mps

    def colour(rgb):
        return f"Color3.fromRGB({rgb[0]}, {rgb[1]}, {rgb[2]})"

    def piece_line(name, p, opts, offset):
        f = [f'name = "{name}"', f"meshId = {p['mesh']}"]
        if p.get("tex"):
            f.append(f"textureId = {p['tex']}")
        if opts.get("paint"):
            f.append("paint = true")
        else:
            f.append(f"color = {colour(opts.get('color', p['color']))}")
            f.append(f"material = Enum.Material.{opts.get('material', p['material'])}")
        if p["transparency"] > 0:
            f.append(f"transparency = {num(p['transparency'], 2)}")
        if opts.get("castShadow") is False:
            f.append("castShadow = false")
        f.append(f"sizeM = {vec(np.array(p['size']) * mps)}")
        f.append(f"offsetM = {vec(offset)}")
        f.append(f"rotationDeg = {vec(np.round(p['rot'], 3), 3)}")
        return "{ " + ", ".join(f) + " },"

    lines, generated = [], []
    triangles = {}
    for p in body:
        key = p["name"].replace("Meshes/", "")
        role = ROLES[key]
        if role is None:
            continue
        name, opts = role
        if opts.get("generated"):
            generated.append((name, p))
            continue
        offset = (np.array(p["pos"]) - origin) * mps
        lines.append(piece_line(name, p, opts, offset))

    # The chrome, debadged, in car space.
    pieces = []
    for name, p in generated:
        P, F = read_obj(os.path.join(ASSETS, "chrome_source.obj"))
        C = P[F].mean(axis=1)
        ext = (P[F].max(axis=1) - P[F].min(axis=1)).max(axis=1)
        cut = np.zeros(len(F), dtype=bool)
        for b in BADGES:
            inside = np.all((C > b["lo"]) & (C < b["hi"]), axis=1) & (ext < b["maxExtent"])
            print(f"badge at {b['lo'][0]:+.1f}: {inside.sum()} triangles")
            cut |= inside
        F = F[~cut]
        scale = np.array(p["size"]) / np.array(p["meshSize"])
        world = (P * scale) @ rot_y(p["rot"][1]).T + np.array(p["pos"])
        car = (world - origin) * mps
        used = np.unique(F)
        remap = -np.ones(len(car), dtype=np.int64)
        remap[used] = np.arange(len(used))
        car, F = car[used], remap[F]
        a, b_, c = car[F[:, 0]], car[F[:, 1]], car[F[:, 2]]
        n = np.cross(b_ - a, c - a)
        n /= np.maximum(np.linalg.norm(n, axis=1, keepdims=True), 1e-12)
        lo, hi = car.min(axis=0), car.max(axis=0)
        centre = (lo + hi) / 2
        tris = np.stack([np.stack([F[:, k], np.arange(len(F)), np.zeros(len(F), dtype=np.int64)], axis=1) for k in range(3)], axis=1)
        piece = meshkit.Piece(name, car - centre, n, np.zeros((1, 2)), tris, hi - lo, centre)
        pieces.append(piece)
        triangles[name] = (len(C), len(F))
        lines.append(
            "{ " + f'name = "{name}", mesh = "Batrol/{name}", color = {colour(p["color"])}, '
            f"material = Enum.Material.Metal, sizeM = {vec(hi - lo)}, offsetM = {vec(centre)}" + " },"
        )
    meshkit.write_luau(
        os.path.join(ROOT, "src", "shared", "CarMeshes", "Batrol"),
        "batrol",
        ["The Batrol's chrome (store mesh 8941408893) with the maker's grille and", "tailgate badges cut out. Car space, metres."],
        pieces,
    )
    # The same pieces for Studio's 3D Importer: an uploaded mesh id needs no
    # EditableMesh (which a live game only gets with the owner ID verified).
    for piece in pieces:
        meshkit.write_obj(os.path.join(ASSETS, piece.name + ".obj"), [piece], offsets=False)

    wlines = []
    for p in wheel:
        name, opts = WHEEL_ROLES[p["name"].replace("Meshes/", "")]
        offset = (np.array(p["pos"]) - tyre_c) * mps
        wlines.append(piece_line(name, p, opts, offset))

    rig = {
        "wheelbaseM": WHEELBASE_M,
        "trackWidthM": round(track, 4),
        "wheelRadiusM": round(tyre_r * mps, 4),
        "wheelWidthM": round(tyre["size"][2] * mps, 4),
    }
    ext_lo = min((np.array(p["pos"])[2] - p["size"][0] / 2 - origin[2]) * mps for p in body)
    ext_hi = max((np.array(p["pos"])[2] + p["size"][0] / 2 - origin[2]) * mps for p in body)
    top = max((p["pos"][1] + p["size"][1] / 2 - origin[1]) * mps for p in body)
    out = ["-- GENERATED by tools/carbody/batrol.py: paste into CarCatalog.batrol.", f"-- rig: {rig}",
           f"-- body: nose {ext_lo:.3f} m, tail {ext_hi:.3f} m, roof {top:.3f} m; {mps:.5f} m per model stud"]
    out += ["pieces = {"] + ["\t" + l for l in lines] + ["},", "wheelPieces = {"] + ["\t" + l for l in wlines] + ["},"]
    with open(os.path.join(ASSETS, "catalog.luau"), "w") as fh:
        fh.write("\n".join(out) + "\n")
    print("\n".join(out[:3]))
    for k, (a, b) in triangles.items():
        print(f"{k}: {a} -> {b} triangles")


if __name__ == "__main__":
    main()
