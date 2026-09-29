"""Read store meshes out of Roblox Studio's local asset cache.

Studio will not hand a script another creator's mesh (EditableMesh from a
store asset fails with "no permission"), but every mesh it has rendered sits
in its HTTP cache. This decodes those files so a store car's mesh can be
edited (a badge cut out) without an Export Selection round trip.

    python3 -m venv /tmp/rbx && /tmp/rbx/bin/pip install DracoPy numpy
    /tmp/rbx/bin/python tools/carbody/rbxcache.py 19.648 4.612 7.802

finds the cached mesh whose proportions match a MeshPart's Size (render the
model in Studio first so its meshes are cached). Cache entries have an
"RBXH" HTTP header, then the mesh file. Formats 2.00 to 4.01 are a header,
vertices and faces (and from 3.00 level-of-detail ranges); 7.00 is chunked:
COREMESH holds a Draco bitstream, LODS the level-of-detail table.
"""
import glob
import os
import struct
import sys

import numpy as np

CACHE = os.path.join(os.environ.get("TMPDIR", "/tmp"), "Roblox", "rbx-storage")
# Small entries live inline in this SQLite file instead of the folder.
CACHE_DB = os.path.expanduser("~/Library/Roblox/rbx-storage.db")


def entries(cache=CACHE, db=CACHE_DB):
    """Every cached entry: file paths, then "db:<hex id>" for inline ones."""
    for path in glob.glob(os.path.join(cache, "*", "*")):
        yield path
    if os.path.exists(db):
        import sqlite3

        con = sqlite3.connect(f"file:{db}?mode=ro", uri=True)
        for (key,) in con.execute("SELECT hex(id) FROM files WHERE content IS NOT NULL"):
            yield "db:" + key
        con.close()


def read(path, db=CACHE_DB):
    if path.startswith("db:"):
        import sqlite3

        con = sqlite3.connect(f"file:{db}?mode=ro", uri=True)
        row = con.execute("SELECT content FROM files WHERE hex(id) = ?", (path[3:],)).fetchone()
        con.close()
        return bytes(row[0]) if row else b""
    return open(path, "rb").read()


def mesh_body(path):
    data = read(path)
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


def decode_v7(b):
    import DracoPy

    ch = chunks(b)
    if "COREMESH" not in ch:
        return None
    data = ch["COREMESH"][1]
    m = DracoPy.decode(data[data.find(b"DRACO"):])
    points = np.asarray(m.points, dtype=float).reshape(-1, 3)
    faces = np.asarray(m.faces, dtype=np.int64).reshape(-1, 3)
    uvs = None if m.tex_coord is None else np.asarray(m.tex_coord, dtype=float).reshape(-1, 2)
    # LODS: u16 type, u8 high-quality count, u32 n, then n face offsets. The
    # faces hold every level of detail back to back; the first is full detail.
    if "LODS" in ch:
        lods = ch["LODS"][1]
        _, _, n = struct.unpack_from("<HBI", lods, 0)
        offs = struct.unpack_from(f"<{n}I", lods, 7)
        if n >= 2 and 0 < offs[1] <= len(faces):
            faces = faces[offs[0]:offs[1]]
    return points, faces, uvs


def decode_v2_v4(b):
    """Formats 2.00, 3.00 and 4.0x: a header, vertices, faces, and (from 3.00)
    a table of level-of-detail face ranges; the first range is full detail."""
    ver = b[8:12]
    p = b.index(b"\n") + 1
    if ver == b"2.00":
        _, vsize, _, nv, nf = struct.unpack_from("<HBBII", b, p)
        p += 12
        lods = None
    elif ver == b"3.00":
        hsize, vsize, _, _, nlods, nv, nf = struct.unpack_from("<HBBHHII", b, p)
        p += hsize
        lods = nlods
    elif ver.startswith(b"4.0"):
        hsize, _, nv, nf, nlods, nbones = struct.unpack_from("<HHIIHH", b, p)
        p += hsize
        vsize = 40
        lods = nlods
    else:
        return None
    raw = np.frombuffer(b, dtype=np.uint8, count=nv * vsize, offset=p).reshape(nv, vsize)
    points = raw[:, :12].copy().view("<f4").reshape(nv, 3).astype(float)
    uvs = raw[:, 24:32].copy().view("<f4").reshape(nv, 2).astype(float)
    p += nv * vsize
    if ver.startswith(b"4.0") and nbones:
        p += nv * 8
    faces = np.frombuffer(b, dtype="<u4", count=nf * 3, offset=p).reshape(nf, 3).astype(np.int64)
    p += nf * 12
    if lods:
        offs = np.frombuffer(b, dtype="<u4", count=lods, offset=p)
        if lods >= 2 and 0 < offs[1] <= nf:
            faces = faces[offs[0]:offs[1]]
    return points, faces, uvs


def decode(path, with_uvs=False):
    """(points (v,3), faces (f,3)) in mesh space, or None if not a mesh.
    with_uvs: (points, faces, uvs (v,2)); uvs as stored, v down."""
    b = mesh_body(path)
    if b is None:
        return None
    if b.startswith(b"version 7"):
        r = decode_v7(b)
    elif b[:12] in (b"version 2.00", b"version 3.00", b"version 4.00", b"version 4.01"):
        r = decode_v2_v4(b)
    else:
        return None
    if r is None:
        return None
    return r if with_uvs else r[:2]


def extents(points):
    """A decoded mesh's bounding-box size, or None where it is unusable: some
    cached meshes decode with NaN bounds (one NaN error scrambles a whole
    ranking, so a mesh that matched exactly ranked below misses), and flat
    ones have a zero side."""
    ext = points.max(0) - points.min(0)
    if not np.isfinite(ext).all() or (ext <= 1e-6).any():
        return None
    return ext


def find(size, cache=CACHE):
    """Cached meshes ranked by how well their bounds match `size` (studs)
    up to one uniform scale: [(error, path, triangles, scale)]."""
    size = np.asarray(size, dtype=float)
    ranked = []
    for path in entries(cache):
        try:
            r = decode(path)
        except Exception:
            continue
        if r is None:
            continue
        ext = extents(r[0])
        if ext is None:
            continue
        k = size / ext
        ranked.append((float(np.ptp(k) / k.mean()), path, len(r[1]), float(k.mean())))
    return sorted(ranked)


def write_obj(path, points, faces, header="", uvs=None):
    """uvs as decode stores them (v down); OBJ's vt has v up."""
    with open(path, "w") as fh:
        for line in header.splitlines():
            fh.write("# " + line + "\n")
        for p in points:
            fh.write(f"v {p[0]:.5f} {p[1]:.5f} {p[2]:.5f}\n")
        if uvs is not None:
            for u in uvs:
                fh.write(f"vt {u[0]:.6f} {1 - u[1]:.6f}\n")
            for a, b, c in faces:
                fh.write(f"f {a + 1}/{a + 1} {b + 1}/{b + 1} {c + 1}/{c + 1}\n")
        else:
            for a, b, c in faces:
                fh.write(f"f {a + 1} {b + 1} {c + 1}\n")


if __name__ == "__main__":
    for err, path, tris, k in find([float(v) for v in sys.argv[1:4]])[:5]:
        print(f"{err:.4f}  {tris:6d} triangles  scale {k:.4f}  {path}")
