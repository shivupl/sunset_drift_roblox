# Garage cosmetics made in the repo

Meshes for the garage's looks, built by scripts and shipped as data like the
generated car pieces (`tools/carbody`, "Generated pieces and EditableMesh"):
quantised buffers in `src/shared/CosmeticMeshes`, decoded once per client by
`src/shared/MeshData.luau` into an EditableMesh and one template MeshPart per
piece, cloned per car; or, per style, uploaded as a mesh asset (below).

## Exhaust tips (`exhaust_tips.py`)

Garage round 3 §1. Run from the repo root:

    /opt/homebrew/bin/blender -b -P tools/cosmetics/exhaust_tips.py -- [--preview DIR]

Blender builds every style (smooth normals, hard only past `SHARP_DEG`),
renders `tip_<Style>.png` and `tip_<Style>_behind.png` into DIR when asked,
and hands the meshes to the system `python3` (Blender's own numpy does not
load on this Mac), which writes `src/shared/CosmeticMeshes/ExhaustTips`
through `tools/carbody/meshkit.py`'s encoder (the same buffers as
`src/shared/CarMeshes`) plus a `colors` buffer: uint8 RGB per position, which
`MeshData` multiplies into the part colour.

**Tip space.** Metres before the car's scale; the mouth centre (the middle of
the lip's crest) at the origin, +Z out of the mouth, +Y up. `offsetM` is each
piece's bounding-box centre there, so `CarCosmetics` puts a tip at its mouth
frame (`CarCosmeticMounts.tipFrames`) times `offsetM`, and the
`ExhaustOutlet` attachments stay exactly at the mouths. `inletM` /
`inletRadiusM` say where the pipe goes in; `radiusM` is a tip's outer half
size across; `tips` how many tips the mesh holds; `bores` each tip's open bore
(centre, radii, tilt about X). `QuadPair` is in pair space: the pair's centre
on its mouth plane, tips at x = ±`pairGapM`/2 (`CarCosmeticMounts.quadPairFrames`).

**One mesh per style** (garage round 3 fix 1). A client can hold only 8
EditableMeshes and a MeshPart made from one goes blank when it is destroyed
(BEHAVIOURS.md), so each style is a single mesh: the tip's outside, band
clamp, reducer, rolled lip and the first centimetre of inner wall, open at
the back of the bore. The game closes each bore with a flat dark disc Part
(matte, because Metal mirrors the world through a dark vertex colour).

| Piece | What it is | Triangles |
|---|---|---|
| Rolled | single and twin chrome: round, rolled lip, 2.2 cm band clamp, S-curve reducer onto a 4.6 cm collar | 1,312 |
| QuadPair | a pair of black tips (no reducer) on their Y inlet: a round collar 33 cm in flaring into a housing that joins the tips and hides inside them | 1,984 (two tips) |
| Slash | titanium: 3 cm longer, mouth cut 26° (bottom shorter), heat colours straw, bronze, rose, blue, violet from the lip back, baked in; its bore disc turns with the cut | 1,372 |
| Oval | Big Oval: 25 x 16 cm barrel on the round collar | 1,394 |

Every tip is at most 1,500 triangles (`CosmeticsConfig.spec` checks it per
tip, that every exhaust item names a style whose piece exists, and that the
styles use at most 4 meshes).

**Budget.** `CarCosmetics` counts the cars wearing each style, frees a
style's EditableMesh when none does, and takes one only if
`CosmeticsConfig.render.tipMeshReserve` (4) slots stay free for car bodies;
otherwise that car gets cylinder tips.

**Uploading (no EditableMesh at all).** The generator also writes
`tools/cosmetics/out/<Style>.obj` (tip space, metres, per-vertex colour on
each `v` line). To ship a style as an asset:

1. In Studio, Avatar or Home tab, Import 3D, pick `tools/cosmetics/out/<Style>.obj`.
   Keep the scale (the file is in metres; the game sets the part's size
   itself), turn off anchoring and rig options, and import. Studio centres the
   mesh on its bounding box, as the generated one is.
2. Publish the MeshPart's mesh (right-click, Save to Roblox or the Asset
   Manager's upload) and copy its asset id (`rbxassetid://<id>`).
3. Put the number in `CosmeticsConfig.render.tipStyles.<style>.meshAssetId`.
   The game then builds that style with `AssetService:CreateMeshPartAsync(Content.fromUri(...))`,
   cached once per client.
4. Check the Slash in the garage: its heat colours are vertex colours. If
   the importer dropped them, leave the Slash on its generated mesh (it
   costs one slot) or bake them into a texture.

Re-upload whenever the generator changes a shape; `offsetM` and the bores in
the generated module must match the uploaded mesh.

**Changing a tip.** The shapes are the constants at the top of the script
(`TIP_R`, `WALL`, `BORE`, `SLASH_DEG`, lengths in `styles()`), each with why it
is that number. `TIP_R` and `QUAD_GAP` must match `CosmeticsConfig.render`
`tipRadiusM` and `quadPairGapM` (spec-checked). Winding is counter-clockwise
from outside (Roblox's front face); the script builds each tip closed and
asserts its signed volume is positive before cutting the bore open, because
Blender's previews draw both sides.
