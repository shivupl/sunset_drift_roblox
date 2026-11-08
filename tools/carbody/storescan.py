"""Triangle counts for store cars scanned in Studio (storescan.luau).

    /tmp/rbx/bin/python tools/carbody/storescan.py

Reads the CARSCAN lines storescan.luau printed to Studio's log
(~/Library/Logs/Roblox/*Studio*.log), matches every MeshPart's MeshSize to a
mesh in Studio's cache (rbxcache.py; the scan preloads them) and prints each
car's triangles at full detail, split into body and wheels (pieces used a
multiple of 4 times with two equal sides). Our standard swaps in simplified
wheels, so the body figure is the one to compare. Decoded cache entries are
remembered in /tmp/storescan_cache.pkl, so later runs only decode new ones.
"""
import glob
import json
import os
import pickle
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import rbxcache  # noqa: E402

IDX = os.path.join(os.environ.get("TMPDIR", "/tmp"), "storescan_cache.pkl")


def cache_meshes():
    idx = pickle.load(open(IDX, "rb")) if os.path.exists(IDX) else {}
    for path in rbxcache.entries():
        if path in idx:
            continue
        try:
            r = rbxcache.decode(path)
        except Exception:
            r = None
        if r is None or not len(r[0]):
            idx[path] = None
            continue
        ext = r[0].max(0) - r[0].min(0)
        idx[path] = (tuple(ext), len(r[1])) if np.isfinite(ext).all() else None
    pickle.dump(idx, open(IDX, "wb"))
    good = [v for v in idx.values() if v]
    return np.array([v[0] for v in good]), np.array([v[1] for v in good])


def scanned():
    chunks = {}
    for log in glob.glob(os.path.expanduser("~/Library/Logs/Roblox/*Studio*.log")):
        for line in open(log, errors="replace"):
            i = line.find("CARSCAN|")
            if i >= 0:
                _, cid, k, n, data = line[i:].rstrip("\n").split("|", 4)
                chunks.setdefault(cid, {})[int(k)] = (int(n), data)
    cars = {}
    for cid, parts in chunks.items():
        n = next(iter(parts.values()))[0]
        if len(parts) == n:
            cars[cid] = json.loads("".join(parts[k][1] for k in range(1, n + 1)))
    return cars


def main():
    exts, tris = cache_meshes()
    rows = []
    for cid, c in scanned().items():
        body = wheel = missing = 0
        for item in filter(None, c["sizes"].split(";")):
            k, cnt = item.rsplit("x", 1)
            cnt = int(cnt)
            s = np.array([float(v) for v in k.split(",")])
            if (s <= 1e-4).any():
                missing += cnt
                continue
            err = np.abs(exts - s).max(1) / s.max()
            j = int(err.argmin())
            if err[j] >= 0.01:
                missing += cnt
                continue
            a = sorted(s)
            wheelish = cnt % 4 == 0 and abs(a[1] - a[2]) / a[2] < 0.03 and a[0] < a[2] * 0.8
            if wheelish:
                wheel += int(tris[j]) * cnt
            else:
                body += int(tris[j]) * cnt
        rows.append((body, wheel, missing, cid, c))
    for body, wheel, missing, cid, c in sorted(rows):
        note = f"  ({missing} meshes not in cache)" if missing else ""
        sw = "wheel part" if c["sw"] else "no wheel part"
        print(f"{cid:>16}  body {body:>9,}  wheels {wheel:>8,}  seats {c['seats']}  {sw:<13}  {c['name'][:40]}{note}")


if __name__ == "__main__":
    main()
