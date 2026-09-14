# Branch status: INACTIVE (parked 2026-09-13)

`phase3-cars` is shelved, not merged. Active work continues on `phase2-rig-body`.

What is here, for when it is picked back up:
- The Kamri: a car body generated in the repo (`tools/carbody/kamri.py`), 10,108 triangles,
  baked textures on SurfaceAppearance looks, and RIG_SPEC.md §7b describing the pipeline.
- Bodies mounted per client (`src/client/CarBodies.luau`, `src/shared/BodyBuilder.luau`).
- Wheel travel from the suspension compression, including cars the client is not driving
  (`src/client/WheelVisuals.luau`).

Why it was parked: generated meshes need the experience's "Allow Mesh / Image APIs" setting
(ID-verified owner) or a manual 3D Importer upload of the OBJ files before they show in play.
