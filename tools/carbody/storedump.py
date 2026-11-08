"""PARTDUMP lines from Studio's log into assets/cars/<car>/parts.json.

    /tmp/rbx/bin/python tools/carbody/storedump.py <car>

storedump.luau prints them; this takes that car's latest run, adds each
mesh's full-detail triangle count from Studio's cache (rbxcache.py, matched
by MeshSize; storescan.py's cache index), and writes parts.json for
storecar.py.
"""
import glob
import json
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import storescan  # noqa: E402

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))


def main(key):
    runs = {}
    for log in glob.glob(os.path.expanduser("~/Library/Logs/Roblox/*Studio*.log")):
        for line in open(log, errors="replace"):
            i = line.find("PARTDUMP|")
            if i < 0:
                continue
            _, k, run, idx, n, data = line[i:].rstrip("\n").split("|", 5)
            if k == key:
                runs.setdefault(run, {})[int(idx)] = (int(n), data)
    run = max((r for r, p in runs.items() if len(p) == next(iter(p.values()))[0]), default=None)
    if run is None:
        sys.exit(f"no complete PARTDUMP run for {key} in Studio's log")
    parts = json.loads("".join(runs[run][k][1] for k in sorted(runs[run])))
    exts, tris = storescan.cache_meshes()
    missing = 0
    for p in parts:
        if "ms" not in p:
            continue
        s = np.array(p["ms"], dtype=float)
        if (s <= 1e-4).any():
            continue
        err = np.abs(exts - s).max(1) / s.max()
        j = int(err.argmin())
        if err[j] < 0.01:
            p["tris"] = int(tris[j])
        else:
            missing += 1
    folder = os.path.join(ROOT, "assets", "cars", key)
    os.makedirs(folder, exist_ok=True)
    json.dump(parts, open(os.path.join(folder, "parts.json"), "w"))
    total = sum(p.get("tris", 0) for p in parts)
    print(f"{key}: {len(parts)} parts, {total:,} triangles, {missing} meshes not found in the cache -> assets/cars/{key}/parts.json")


if __name__ == "__main__":
    main(sys.argv[1])
