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
style's EditableMesh when none does (a build is single-flight: cars asking
for a style while it is being made wait for the same one), and takes one
only if
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
4. Check each uploaded style in the garage against the generated one before
   shipping it: the mouth must face out of the car (+Z) with its flame
   leaving the mouth (REV), the bore disc must sit inside the mouth, and the
   Slash's cut must be shorter at the bottom with its disc tilted the same
   way. A mirrored or axis-swapped import puts the cut and the disc on the
   wrong side. The Slash's heat colours are vertex colours: if the importer
   dropped them, leave the Slash on its generated mesh (it costs one slot) or
   bake them into a texture.

Re-upload whenever the generator changes a shape; `offsetM` and the bores in
the generated module must match the uploaded mesh.

**Changing a tip.** The shapes are the constants at the top of the script
(`TIP_R`, `WALL`, `BORE`, `SLASH_DEG`, lengths in `styles()`), each with why it
is that number. `TIP_R` and `QUAD_GAP` must match `CosmeticsConfig.render`
`tipRadiusM` and `quadPairGapM` (spec-checked). Winding is counter-clockwise
from outside (Roblox's front face); the script builds each tip closed and
asserts its signed volume is positive before cutting the bore open, because
Blender's previews draw both sides.

## Sun strips (`strip_shapes.py`)

Garage round 3 §3. The windscreen strip is `CosmeticsConfig.render.stripSlats`
(14) flat slats, each placed and angled on the glass at its spot, so the
strip follows the screen's curve across and its top edge and stops at the
pillars. No EditableMesh: each slat is a Part with a SurfaceGui showing its
own slice of the one strip canvas (a clipping frame holding the whole canvas
shifted to the slat's `fromM`), so text and gradient run on across slats.

Run from the repo root, with numpy and DracoPy (see `tools/carbody/rbxcache.py`):

    python3 tools/cosmetics/strip_shapes.py

It needs every car's windscreen mesh in Studio's local cache: render the
cars in Studio first (Edit; a MeshPart with the piece's mesh id in view is
enough). Store meshes are found by the catalog's mesh id:
`glass_meshes.json` records each id's MeshSize (its own bounds) and face
count, and exactly one distinct cached mesh must match both, or the script
stops and says which (it never fits a look-alike). A new car's glass needs a
line there. The Kamri's generated glass is read from its MeshData module.
The hatch is a pack car, but its glass is a black glass piece of its own, so
its ends come from the mesh like the store cars'. Each piece is placed in car space as
BodyBuilder places it (bounds scaled to `sizeM`, `rotationDeg` YXZ,
`offsetM`), from the working copy of `CarCatalog.luau`.

Per car (the inputs are `CarCosmeticMounts` `windscreen`, TUNING.md):

1. The screen: the piece's faces whose outward normal looks forward and up
   (normals turned outward geometrically: store meshes mix windings, and the
   Krown Vik's glass is double-sided), the largest connected patch, or on a
   shell the patch at the spot.
2. Profiles: the screen cut at constant x, top edge first (the longest chain
   in the slice, which skips a shell's roof lip).
3. The header: the top edge across the middle half, fitted in 3D (y and z
   each a quadratic in x) and carried to the pillars; each slice places the
   band from the point nearest it. (Fitted in height alone, a few mm of
   misfit became ~4x that along a nearly level screen, and the hatch's strip
   waved.) The band (topGapM, then heightM, down the glass from the header)
   must lie on the glass; the ends are where it stops fitting (the glass
   turning down the pillar), or the spot's width on a shell. An outside strip
   never starts above a slice's own top edge (it would sit over trim the
   script does not clear).
4. The centre line, sampled 8 times per slat and smoothed (a degree-6
   polynomial in x; the fit's error is printed, a few mm), split into slats
   whose ends are shared, so the chain stays joined. Each slat's normal comes
   from the surface.
5. Clearance: each slat is stood off the glass by `stripGlassGapM` from the
   highest (outside) or lowest (inside) point of the piece's whole mesh under
   it, sampled every 4 mm; the shared ends move by the larger of their two
   slats' needs.
6. Joins: each join is widened until even the slats' top and bottom corners
   overlap by 2 x `stripOverlapM` (where the strip bends in the glass's
   plane a wedge opens at one edge); the strip's outer ends are not widened.
7. Canvas order: a Front-face SurfaceGui's canvas starts at the part's +X
   side, so each slat's slice (`fromM`) counts from the strip's +X end. The
   runtime places and sizes the slice in scale, so neighbours agree to the
   sub-pixel.

The output, `src/shared/CarStripShapes.luau`, says per car which mesh and
cache entry it came from. `CarStripShapes.spec` checks every catalog car has
14 slats, left to right, overlapping their neighbour (corners included) with no
gap and no step along the normal,
unit normals facing forward and up, and canvas slices that tile the strip.

Rerun it when a car's glass, its catalog placement, its windscreen spot, or
the three strip knobs change (the Kamri's glass is still the committed
MeshData stretched to the owner's working-copy catalog `sizeM`; rerun it once
the Kamri's new pieces land).
