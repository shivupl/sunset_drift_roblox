# Kamri '07

A mid-2000s Japanese saloon from the Creator Store (asset 876308553, an
A-Chassis car), debadged and cut down for the game. Catalog id `kamri07`.

## How it was made

1. **Studio:** inserted into ServerStorage (scripts sandboxed), then stripped
   of everything but geometry: 34 scripts, GUIs, sounds, lights, remotes,
   seats, 18 invisible parts and the front badge. Placed facing world -Z with
   its left on -X (car space), every part renamed `P<index>`, its colour,
   material and transparency saved to `parts.csv`, and exported with Export
   Selection to `camry_exp/camry_edit.obj` (30 MB, not in git).
2. **Blender:** `tools/carbody/store_body.py -- kamri07`.

| Step | Result |
|---|---|
| Parts no ray reaches, plus the engine bay | 34 parts, 15,119 triangles deleted |
| Faces no ray reaches on outside parts (inner skins of panels) | 37,448 deleted |
| Badge oval and script lettering on the boot strip | cut |
| Small cabin pieces below the window line | deleted |
| Front cabin / rear cabin | decimated separately, the rear far harder |
| Paint | planar decimation only (5 degrees), area-weighted normals |

Visibility is 400 directions x 150 x 150 rays through the car, glass letting
them through. Inner skins had to go: decimating a panel with its inner skin
welded to it folds the two together and creases the paint.

| Piece | Triangles |
|---|---|
| Body (paint) | 10,477 |
| Glass | 622 |
| Lenses | 1,324 |
| TailLamps | 80 |
| Chrome | 1,291 |
| Trim | 2,963 |
| Grey | 770 |
| InteriorDark | 3,387 |
| InteriorLight | 1,890 |
| Tyre x4 | 898 each |
| Rim x4 | 514 each |
| **Whole car** | **28,452** (from 158,140) |

Scale: 0.2505 m a stud, so the wheel centres sit on the real 2.775 m
wheelbase. 4.83 m long, 1.52 m track, 0.66 m tyres.

3. `python3 tools/carbody/fbx_pieces.py kamri07 Kamri07` writes
   `src/shared/CarMeshes/Kamri07`; `fbx_preview.py -- kamri07` renders
   `preview_*.png`.

## Live

The meshes are generated data, which Studio play and live servers refuse
without the Mesh API setting. Import `kamri07_all.obj` with Studio's 3D
Importer (one import, one MeshPart per piece) and put each MeshPart's mesh id
on its catalog piece as `meshId`.
