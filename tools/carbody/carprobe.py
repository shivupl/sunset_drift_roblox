"""Measure a store car's body in car space with rays (README "Finding store
cars"; the cosmetic spots in CarCosmeticMounts).

    python3 tools/carbody/carprobe.py <car> rear <x> <y>       # bumper face: last z hit by a ray going forward from behind
    python3 tools/carbody/carprobe.py <car> up <x> <z> <y0>    # underside: first y hit by a ray going up from y0
    python3 tools/carbody/carprobe.py <car> back <x> <y> <z0>  # first z hit by a ray going back from z0
    python3 tools/carbody/carprobe.py <car> near <x> <y> <z> <r>  # body pieces with a vertex within r

Car space as storecar.py and the catalog: metres before the car's scale, +X
right, +Y up, forward -Z, origin on the ground under the wheelbase centre.
Every part storecar.py keeps is placed from its store mesh in Studio's cache
(rbxcache.py; render the model first, storedump.luau does) with the role
storecar.py gives it. Cut pieces are probed whole, before their cut.
"""
import json
import os
import pickle
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import rbxcache  # noqa: E402
import storecar  # noqa: E402
import storescan  # noqa: E402


def soup(key):
    car = storecar.CARS[key]
    folder = os.path.join(storecar.ROOT, "assets", "cars", key)
    parts = json.load(open(os.path.join(folder, "parts.json")))
    by = {p["i"]: p for p in parts}
    B, origin, mps, *_ = storecar.car_frame(car, by)
    idx = pickle.load(open(storescan.IDX, "rb"))
    paths = [(np.array(v[0]), path) for path, v in idx.items() if v]
    exts = np.array([e for e, _ in paths])
    tris, labels = [], []
    names = {}
    for p in parts:
        if p["p"] in car["dropGroups"] or p["i"] in car["dropParts"] or p["c"] != "MeshPart":
            continue
        role, _ = car["role"](p)
        names[role] = names.get(role, 0) + 1
        name = role if names[role] == 1 else f"{role}_{names[role]}"
        s = np.array(p["ms"], dtype=float)
        if (s <= 1e-4).any():
            continue
        err = np.abs(exts - s).max(1) / s.max()
        j = int(err.argmin())
        if err[j] >= 0.01:
            continue
        P, F = rbxcache.decode(paths[j][1])
        scale = np.array(p["s"], dtype=float) / s
        Rw = np.array(p["cf"][3:], dtype=float).reshape(3, 3)
        world = (P * scale) @ Rw.T + np.array(p["cf"][:3], dtype=float)
        cs = (world - origin) @ B * mps
        tris.append(cs[F])
        labels += [f"{name} (part {p['i']})"] * len(F)
    return np.concatenate(tris), np.array(labels)


def cast(T, o, d):
    """Distances along d from o to every triangle hit (Möller-Trumbore)."""
    e1, e2 = T[:, 1] - T[:, 0], T[:, 2] - T[:, 0]
    h = np.cross(d, e2)
    a = (e1 * h).sum(1)
    ok = np.abs(a) > 1e-12
    f = np.where(ok, 1 / np.where(ok, a, 1), 0)
    s = o - T[:, 0]
    u = f * (s * h).sum(1)
    q = np.cross(s, e1)
    v = f * (q @ d)
    t = f * (e2 * q).sum(1)
    hit = ok & (u >= 0) & (v >= 0) & (u + v <= 1) & (t > 1e-6)
    return t, hit


def main():
    key, cmd, *a = sys.argv[1:]
    T, L = soup(key)
    a = [float(x) for x in a]
    if cmd == "near":
        x, y, z, r = a
        c = np.array([x, y, z])
        m = (np.linalg.norm(T - c, axis=2) < r).any(1)
        for name in sorted(set(L[m])):
            print(name)
        return
    if cmd == "rear":
        o, d = np.array([a[0], a[1], 10.0]), np.array([0, 0, -1.0])
    elif cmd == "back":
        o, d = np.array([a[0], a[1], a[2]]), np.array([0, 0, 1.0])
    elif cmd == "up":
        o, d = np.array([a[0], a[2], a[1]]), np.array([0, 1.0, 0])
    else:
        sys.exit("rear | back | up | near")
    t, hit = cast(T, o, d)
    order = np.argsort(np.where(hit, t, np.inf))[: min(4, int(hit.sum()))]
    if not len(order):
        print("no hit")
    for k in order:
        p = o + d * t[k]
        print(f"hit at ({p[0]:.3f}, {p[1]:.3f}, {p[2]:.3f}) on {L[k]}")


if __name__ == "__main__":
    main()
