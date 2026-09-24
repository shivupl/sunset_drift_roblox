"""Read store meshes out of Roblox Studio's local asset cache.

Studio will not hand a script another creator's mesh (EditableMesh from a
store asset fails with "no permission"), but every mesh it has rendered sits
in its HTTP cache. This decodes those files so a store car's mesh can be
edited (a badge cut out) without an Export Selection round trip.

    python3 -m venv /tmp/rbx && /tmp/rbx/bin/pip install DracoPy numpy
    /tmp/rbx/bin/python tools/carbody/rbxcache.py 19.648 4.612 7.802

finds the cached mesh whose proportions match a MeshPart's Size (render the
model in Studio first so its meshes are cached). Cache entries have an
"RBXH" HTTP header, then the mesh file. Mesh format 7.00 is chunked:
COREMESH holds a Draco bitstream (positions and UVs; faces are flat, three
unshared vertices each), LODS the level-of-detail table.
"""
import glob
import os
import struct
import sys

import numpy as np

CACHE = os.path.join(os.environ.get("TMPDIR", "/tmp"), "Roblox", "rbx-storage")


def mesh_body(path):
    data = open(path, "rb").read()
    i = data.find(b"version ")
    return data[i:] if i >= 0 else None


def chunks(b):
    nl = b.index(b"\n")
    p = nl + 1
    out = {}
    while p + 16 <= len(b):
        typ = b[p:p + 8].rstrip(b"\0").decode(errors="replace")
        cver, size = struct.unpack_from("<II", b, p + 8)
        out[typ] = (cver, b[p + 16:p + 16 + size])
        p += 16 + size
    return out


def decode(path):
    """(points (v,3), faces (f,3)) in mesh space, or None if not a v7 mesh."""
    import DracoPy

    b = mesh_body(path)
    if b is None or not b.startswith(b"version 7"):
        return None
    ch = chunks(b)
    if "COREMESH" not in ch:
        return None
    data = ch["COREMESH"][1]
    m = DracoPy.decode(data[data.find(b"DRACO"):])
    points = np.asarray(m.points, dtype=float).reshape(-1, 3)
    faces = np.asarray(m.faces, dtype=np.int64).reshape(-1, 3)
    return points, faces


def find(size, cache=CACHE):
    """Cached meshes ranked by how well their bounds match `size` (studs)
    up to one uniform scale: [(error, path, triangles, scale)]."""
    size = np.asarray(size, dtype=float)
    ranked = []
    for path in glob.glob(os.path.join(cache, "*", "*")):
        try:
            r = decode(path)
        except Exception:
            continue
        if r is None:
            continue
        ext = r[0].max(0) - r[0].min(0)
        if (ext <= 1e-6).any():
            continue
        k = size / ext
        ranked.append((float(np.ptp(k) / k.mean()), path, len(r[1]), float(k.mean())))
    return sorted(ranked)


def write_obj(path, points, faces, header=""):
    with open(path, "w") as fh:
        for line in header.splitlines():
            fh.write("# " + line + "\n")
        for p in points:
            fh.write(f"v {p[0]:.5f} {p[1]:.5f} {p[2]:.5f}\n")
        for a, b, c in faces:
            fh.write(f"f {a + 1} {b + 1} {c + 1}\n")


if __name__ == "__main__":
    for err, path, tris, k in find([float(v) for v in sys.argv[1:4]])[:5]:
        print(f"{err:.4f}  {tris:6d} triangles  scale {k:.4f}  {path}")
