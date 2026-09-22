"""Turn cleaned body OBJs into the Luau mesh data the game loads.

    python3 tools/carbody/fbx_pieces.py kamri_s KamriS

Reads assets/cars/<car>/<Piece>.obj (written by fbx_body.py: car space,
metres, per-corner normals and UVs) and writes src/shared/CarMeshes/<Module>,
the same format kamri.py writes (meshkit.write_luau), so BodyBuilder can
build EditableMeshes from it. Also prints each piece's sizeM and offsetM for
the catalog entry; the wheel pieces are already in wheel space.
"""
from __future__ import annotations

import json
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(__file__))
import meshkit  # noqa: E402

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
ORDER = ["Body", "Glass", "HeadLamps", "TailLamps", "Trim", "Interior", "Tyre", "Rim"]


def read_obj(path: str, name: str) -> meshkit.Piece:
    P, N, T, tris = [], [], [], []
    with open(path) as fh:
        for line in fh:
            parts = line.split()
            if not parts:
                continue
            if parts[0] == "v":
                P.append([float(x) for x in parts[1:4]])
            elif parts[0] == "vn":
                N.append([float(x) for x in parts[1:4]])
            elif parts[0] == "vt":
                # meshkit.write_obj flips v on the way out; flip it back.
                T.append([float(parts[1]), 1 - float(parts[2])])
            elif parts[0] == "f":
                corners = []
                for c in parts[1:]:
                    p, t, n = (c.split("/") + ["", ""])[:3]
                    corners.append((int(p) - 1, int(n) - 1 if n else 0, int(t) - 1 if t else 0))
                for k in range(1, len(corners) - 1):
                    tris.append([corners[0], corners[k], corners[k + 1]])
    P = np.array(P)
    N = np.array(N) if N else np.zeros((1, 3))
    T = np.clip(np.array(T), 0, 1) if T else np.zeros((1, 2))
    lo, hi = P.min(axis=0), P.max(axis=0)
    centre = (lo + hi) / 2
    return meshkit.Piece(name, P - centre, N, T, np.array(tris, dtype=np.int64), hi - lo, centre)


def main(car_id: str, module: str):
    folder = os.path.join(ROOT, "assets", "cars", car_id)
    summary = json.load(open(os.path.join(folder, "summary.json")))
    # The pieces the summary lists (store_body.py), or the fixed set.
    names = list(summary["pieces"]) if "pieces" in summary else ORDER
    pieces = [read_obj(os.path.join(folder, f"{n}.obj"), n) for n in names if os.path.exists(os.path.join(folder, f"{n}.obj"))]
    counts = ", ".join(f"{p.name} {p.triangles}" for p in pieces)
    whole = sum(p.triangles for p in pieces if p.name not in ("Tyre", "Rim")) + 4 * sum(p.triangles for p in pieces if p.name in ("Tyre", "Rim"))
    header = [
        summary.get("title", module),
        f"Source: {summary['source']['file']} ({summary['source']['triangles']} triangles), cleaned by tools/carbody/{'store_body' if 'removed' in summary else 'fbx_body'}.py.",
        f"Triangles: {counts}; {whole} for the whole car with four wheels.",
    ]
    meshkit.write_luau(os.path.join(ROOT, "src", "shared", "CarMeshes", module), "fbx_pieces", header, pieces)
    for p in pieces:
        print(f"{p.name:10} tris={p.triangles:5}  sizeM = {{ {p.size[0]:.4f}, {p.size[1]:.4f}, {p.size[2]:.4f} }}, offsetM = {{ {p.offset[0]:.4f}, {p.offset[1]:.4f}, {p.offset[2]:.4f} }}")
    print("whole car", whole)


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else "kamri_s", sys.argv[2] if len(sys.argv) > 2 else "KamriS")
