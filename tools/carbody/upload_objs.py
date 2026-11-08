#!/usr/bin/env python3
"""One OBJ per car of its generated pieces, for Studio's 3D Importer.

A generated piece (a badge cut out, a lamp split off, a painted grille)
ships as data in src/shared/CarMeshes/<Car> and is decoded into an
EditableMesh on each client, and a client holds only 8 of those
(BEHAVIOURS.md). An uploaded mesh takes none. This writes
assets/cars/upload/<Car>.obj, one object per piece named <Car>_<Piece>,
decoded from the same buffers the game reads, so the upload matches what
the game draws:

- each piece centred on its own bounding box at the origin (the importer
  centres every mesh anyway; BodyBuilder places it by sizeM and offsetM);
- turned half round about Y beforehand, because the importer turns an OBJ
  half round about Y on the way in (tools/cosmetics/README.md, 2026-09-29),
  so it lands the right way round;
- v flipped as meshkit.write_obj does (OBJ counts v from the bottom).

It also writes AllCars.obj, all of them in one file.

Import once (File > Import 3D, Studio Default, so each object
stays its own MeshPart), then wire the ids with upload_ids.luau
(tools/carbody/README.md, "Uploading generated pieces").

Usage: python3 tools/carbody/upload_objs.py [Car ...]   (default: every car
whose catalog pieces still use a generated mesh without a meshId, except the
owner's generated Kamri).
"""
import base64
import re
import struct
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
MESHES = ROOT / "src/shared/CarMeshes"
OUT = ROOT / "assets/cars/upload"
# The owner's generated Kamri: its catalog lines are the owner's, not ours.
SKIP = {"Kamri"}


def pieces_of(car: str):
    init = (MESHES / car / "init.luau").read_text()
    for m in re.finditer(r"\n\t(\w+) = \{\n(.*?)\n\t\},", init, re.S):
        name, body = m.group(1), m.group(2)
        tri = int(re.search(r"triangleCount = (\d+)", body).group(1))
        size = [float(x) for x in re.search(r"sizeM = \{ ([^}]*) \}", body).group(1).split(",")]
        counts = [int(x) for x in re.search(r"counts = \{ ([^}]*) \}", body).group(1).split(",")]

        def buf(kind):
            src = (MESHES / car / f"{name}_{kind}.luau").read_text()
            return base64.b64decode(re.search(r'return "([^"]*)"', src).group(1))

        yield name, tri, size, counts, buf("positions"), buf("normals"), buf("uvs"), buf("triangles")


def wanted_from_catalog():
    cat = (ROOT / "src/shared/CarCatalog.luau").read_text()
    cars = set()
    # One piece per line in the catalog.
    for line in cat.splitlines():
        m = re.search(r'mesh = "(\w+)/(\w+)"', line)
        if m and "meshId" not in line:
            cars.add(m.group(1))
    return sorted(cars - SKIP)


def write(car: str) -> list[str]:
    lines = [f"# {car}: generated pieces for Studio's 3D Importer (tools/carbody/upload_objs.py)"]
    vb = nb = tb = 1
    report = []
    for name, tri, size, counts, pos, nrm, uv, tris in pieces_of(car):
        hx, hy, hz = size[0] / 2, size[1] / 2, size[2] / 2
        lines.append(f"o {car}_{name}")
        for i in range(counts[0]):
            x, y, z = struct.unpack_from("<hhh", pos, i * 6)
            # Half turn about Y: (x, z) -> (-x, -z).
            lines.append(f"v {-x / 32767 * hx:.5f} {y / 32767 * hy:.5f} {-z / 32767 * hz:.5f}")
        for i in range(counts[1]):
            x, y, z = struct.unpack_from("<bbb", nrm, i * 3)
            ln = (x * x + y * y + z * z) ** 0.5 or 1
            lines.append(f"vn {-x / ln:.4f} {y / ln:.4f} {-z / ln:.4f}")
        for i in range(counts[2]):
            u, v = struct.unpack_from("<HH", uv, i * 4)
            lines.append(f"vt {u / 65535:.6f} {1 - v / 65535:.6f}")
        for t in range(tri):
            c = struct.unpack_from("<9H", tris, t * 18)
            lines.append("f " + " ".join(f"{c[k * 3] + vb}/{c[k * 3 + 2] + tb}/{c[k * 3 + 1] + nb}" for k in range(3)))
        vb += counts[0]
        nb += counts[1]
        tb += counts[2]
        report.append(f"{car}_{name} {tri} tris, {size[0]:.4f} x {size[1]:.4f} x {size[2]:.4f} m")
    OUT.mkdir(parents=True, exist_ok=True)
    (OUT / f"{car}.obj").write_text("\n".join(lines) + "\n")
    return report


def write_all(cars: list[str]):
    """AllCars.obj: every car's file in one, so the owner imports once
    (2026-11-07: "do i have to upload 1 by 1"). Object names carry the car,
    so they stay unique."""
    out = ["# Every car's generated pieces in one file (tools/carbody/upload_objs.py)"]
    vb = nb = tb = 0
    for car in cars:
        nv = nn = nt = 0
        for line in (OUT / f"{car}.obj").read_text().splitlines():
            if line.startswith("v "):
                nv += 1
            elif line.startswith("vn "):
                nn += 1
            elif line.startswith("vt "):
                nt += 1
            elif line.startswith("f "):
                corners = []
                for c in line[2:].split():
                    v, t, n = (int(x) for x in c.split("/"))
                    corners.append(f"{v + vb}/{t + tb}/{n + nb}")
                line = "f " + " ".join(corners)
            elif not line.startswith("o "):
                continue
            out.append(line)
        vb, nb, tb = vb + nv, nb + nn, tb + nt
    (OUT / "AllCars.obj").write_text("\n".join(out) + "\n")


if __name__ == "__main__":
    cars = sys.argv[1:] or wanted_from_catalog()
    for car in cars:
        for line in write(car):
            print(line)
    write_all(cars)
