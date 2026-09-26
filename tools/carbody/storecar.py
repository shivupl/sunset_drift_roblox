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
  4. writes assets/cars/<car>/catalog.luau with the pieces and the rig
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
    for p in kept:
        role, opts = car["role"](p)
        names[role] = names.get(role, 0) + 1
        name = role if names[role] == 1 else f"{role}_{names[role]}"
        R, pos = place(p)
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
