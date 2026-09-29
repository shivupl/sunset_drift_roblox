# Garage cosmetics made in the repo

Meshes for the garage's looks, built by scripts and shipped as data like the
generated car pieces (`tools/carbody`, "Generated pieces and EditableMesh"):
quantised buffers in `src/shared/CosmeticMeshes`, decoded once per client by
`src/shared/MeshData.luau` into an EditableMesh and one template MeshPart per
piece, cloned per car. No uploads.

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
(`CarCosmeticMounts.tipMouths`) plus `offsetM` and the `ExhaustOutlet`
attachments stay exactly at the mouths. `inletM` / `inletRadiusM` say where
the pipe goes in; `radiusM` is the outer half size across. `QuadY` is in pair
space: the pair's centre on its mouth plane, tips at x = ±`pairGapM`/2.

**Pieces.** Each style is a shell (outside, band clamp, reducer, rolled lip;
the item's colour and material) and a bore (inner wall and flat floor, 1.6 cm
deep; its own matte part, because Metal and Foil mirror the world through a
dark vertex colour).

| Piece | What it is | Triangles |
|---|---|---|
| Rolled + RolledBore | single and twin chrome: round, rolled lip, 2.2 cm band clamp, S-curve reducer onto a 4.6 cm collar | 1,120 + 288 |
| Quad (+ RolledBore) | one tip of a quad pair, no reducer; its closed front sits on QuadY | 544 + 288 |
| QuadY | the pair's Y inlet: round collar 33 cm in, flaring into a housing that joins the two tips and hides inside them | 512 |
| Slash + SlashBore | titanium: 3 cm longer, mouth cut 26° (bottom shorter), heat colours straw, bronze, rose, blue, violet from the lip back, baked in | 1,204 + 252 |
| Oval + OvalBore | Big Oval: 25 x 16 cm barrel on the round collar | 1,190 + 306 |

Every tip (shell and bore) is at most 1,500 triangles (`CosmeticsConfig.spec`
checks it, and that every exhaust item names a style whose pieces exist).

**Budget.** A client can hold only 8 EditableMeshes (BEHAVIOURS.md). All five
exhaust items on screen at once take 8 (Quad shares the round bore); a style
that cannot be made falls back to cylinder tips in `CarCosmetics`.

**Changing a tip.** The shapes are the constants at the top of the script
(`TIP_R`, `WALL`, `BORE`, `SLASH_DEG`, lengths in `styles()`), each with why it
is that number. `TIP_R` and `QUAD_GAP` must match `CosmeticsConfig.render`
`tipRadiusM` and `quadPairGapM` (spec-checked). Winding is counter-clockwise
from outside (Roblox's front face); the script asserts each closed tip's
signed volume is positive, because Blender's previews draw both sides.
