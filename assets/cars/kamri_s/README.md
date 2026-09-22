# Kamri S

The owner's sculpt of the XV40-shape saloon (`white toyota car 3d model.fbx` in
the repo root: one fused AI mesh, 50,367 triangles, no UVs), cleaned into game
pieces. Catalog id `kamriS`.

## Rebuild

```
BLENDER_NUMPY_PATH=<numpy for macOS 11+> blender -b --factory-startup --python tools/carbody/fbx_body.py -- kamri_s
python3 tools/carbody/fbx_pieces.py kamri_s KamriS
blender -b --factory-startup --python tools/carbody/fbx_preview.py -- kamri_s
```

`fbx_body.py` writes the OBJs and `summary.json` here; `fbx_pieces.py` writes
`src/shared/CarMeshes/KamriS` and prints each piece's sizeM and offsetM for the
catalog; `fbx_preview.py` renders `preview_*.png`.

## What the cleanup does

| Step | Why |
|---|---|
| Weld, split long edges where outlines cut | The sculpt is long thin triangles; outlines need short edges to cut clean. |
| Badges and the fused interior mirror pressed flat | No real brands; the mirror was sculpted into the windscreen. |
| Glass, lamps, grille, intakes cut by traced outlines | Everything was one surface. |
| Side windows glazed with panes on the frame | The openings run into the door cards: no hole to fill. |
| Small stray patches take the class around them | Flecks of paint on the glass and so on. |
| Paint lightly smoothed (Laplacian, borders pinned) | AI surfaces are lumpy. |
| Per-piece decimation to a budget, small parts protected | Wipers and handles fall apart under a global collapse. |
| Smooth by angle, UVs projected, into car space | RIG_SPEC.md sections 1 and 7. |

| Piece | Triangles |
|---|---|
| Body (paint, mirrors, handles) | 4,561 |
| Glass | 482 |
| HeadLamps | 303 |
| TailLamps | 286 |
| Trim (grille, intakes, wipers, exhausts, underbody) | 898 |
| Interior | 599 |
| Tyre ×4 | 693 each |
| Rim ×4 | 540 each |
| **Whole car** | **12,061** (from 50,367) |

Scaled so the wheel centres sit on the Kamri's real 2.775 m wheelbase and
1.575 m track (Y and Z share one scale so the wheels stay round): 4.54 m long,
1.82 m wide without mirrors, roof at 1.52 m.

## Getting it into a live game

The meshes are generated data (EditableMesh). Studio's Edit mode shows them;
Studio play and live servers refuse EditableMesh unless the experience allows
Mesh APIs, and show grey boxes instead. The route that needs no switch: import
each `*.obj` here with Studio's 3D Importer, then put each MeshPart's mesh id on
the catalog piece as `meshId` (keep `mesh`, `sizeM` and `offsetM`).
