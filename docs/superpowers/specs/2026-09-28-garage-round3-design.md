# Garage round 3: modelled exhaust tips, routed pipes, moulded sun strips

Asked by the owner on 2026-09-28 after round 2: "work purely on the
customizations, use the blender mcp/tool or whatever you need to really make
the exhaust tip options better and connect/mesh slightly better into the
cars with the pipes. additionally the window strip decals, make them
actually mold around the window ... rename it from decals to like
headstrips or whatever they are actually called". Design approved in chat
the same day ("yes go").

Builds on `2026-09-28-garage-round2-design.md` (the exhaust standard, the
`ExhaustOutlet` contract, flames). Branch `garage-r3`, off `garage`.

## 1. Modelled tips (Blender)

- Tip meshes are authored by a repo script run in headless Blender
  (`blender -b -P tools/cosmetics/exhaust_tips.py`), exported through the
  existing generated-mesh path: quantised MeshData modules
  (`src/shared/CosmeticMeshes/`, same format as `src/shared/CarMeshes`,
  decoded by `MeshData` into an EditableMesh once per client, one template
  MeshPart per mesh, cloned per car). No uploads.
- Styles (one per shipping item, plus one new item):
  - **Rolled** (Single / Twin Chrome): round tip, rolled lip, double wall
    with a dark inner face, a band clamp at the inlet, a short flared
    reducer onto the pipe.
  - **Quad** (Quad Tips): a joined pair of black tips on one Y inlet; one
    pair per side, so a quad car has two pipes, not four.
  - **Slash** (Burnt Titanium Twin): slash-cut tip with the heat colours
    (straw → blue → violet from the lip back), as vertex colours if
    EditableMesh renders them, else a SurfaceAppearance-free fallback
    (bands of separate parts) — the implementer verifies in Studio and
    records which.
  - **Oval** (new item `exhaust_oval`, "Big Oval Tip", single): a large oval
    rolled tip.
- Each mesh has its mouth centre at a known local point and its axis along
  local +Z so `CarCosmeticMounts.tipMouths`/`outletFrames` stay the
  contract: outlets stay exactly at the mouths (flames unchanged).
- The dark bore reads from any angle (inner wall faces dark), so no
  separate bore cylinder.
  - **As built (controller ruling, fix round 2):** each tip does have a
    separate bore part, a flat dark SmoothPlastic disc 1.6 cm in (not a
    cylinder), because Metal and Foil mirror the world through dark vertex
    colours (measured in Studio: a Foil bore showed the bumper and the car's
    pipes), and a bore mesh would cost an EditableMesh (a client holds 8).
    The mesh keeps the first centimetre of dark inner wall. Parts per look are
    no more than round 2's.
- Budget: each tip ≤ 1,500 triangles; report counts.

## 2. Pipes routed into the car

- The pipe behind every tip (and every factory pipe) is a swept tube built
  at runtime (EditableMesh, cached by shape): straight forward from the
  tip's inlet, then a bend up into the underbody, ending hidden inside it,
  with a small rubber hanger on the straight run.
- Per car the exhaust gains `riseM` (how far above the pipe's centre the
  underbody sits at the end of the run), measured on the car (below and side
  captures, as the round-2 spots were). `pipeLengthM` stays the straight run.
- Spec: every car has `riseM` > 0; the pipe's end is at or above the
  pipe's start plus `riseM`.
- **As built (controller ruling, task 2):** the pipe is plain Parts, not an
  EditableMesh, because a client holds 8 EditableMeshes and the generated
  car bodies and the tips already share them. A cylinder for the straight,
  one per chord of the bend (`pipeBendSegments`, 3 per 90°), a Ball part the
  pipe's size at every joint so the bend reads smooth, and a riser where
  the bend's 90° is not enough (kruzer80). The route is a pure function,
  `CarCosmeticMounts.pipeRoute`, which the spec walks for every car, style
  and factory pipe. A turned quad pair's pipe leaves along the tip's axis
  (`pipeAxisRunM`) before it turns forward. Factory pipes and the cylinder
  fallback route the same way. Where the run already ends inside the body
  or the car's own muffler, `riseM` is a nominal 0.04; each car's entry
  says which. 8 Parts per pipe (10 with a riser, 12 on a turned pair).

## 3. Sun strips moulded to the windscreen

- The strip is built from N narrow slats (config, ~14) across the
  windscreen, each placed and angled to the glass at its spot, so the strip
  follows the screen's curve across and its top edge; the two ends are cut
  to the glass outline at the pillars. One SurfaceGui per slat shows its
  slice of the whole strip canvas (text and gradient continuous across
  slats). Slats overlap a hair so no seam shows.
- Per car shape data, in car metres: a list of slat frames (centre, normal,
  width, height), generated offline from each car's real windscreen mesh
  (the store glass read from Studio's local cache with
  `tools/carbody/rbxcache.py`, the generated glass from its MeshData
  module) by a repo script, into a generated module
  (`src/shared/CarStripShapes.luau`). Shell cars whose glass is painted into
  a textured shell (hatch, pickup, cruiser) get their slats from their
  shell mesh the same way, or by eye where the mesh gives no usable screen.
- Inside or outside the glass as today (inside behind see-through glass,
  outside on opaque glass), a fixed offset along the normal.

## 4. Rename: sun strips

- The category is shown as **SUN STRIPS** (panel chip), title
  `SUN STRIPS` / `شريط`; the real name for the banner across the top of a
  windscreen. Internal ids and the `decal` slot key stay (they are stored on
  profiles). Docs and UI_SYSTEM follow.

## Constraints (unchanged)

Cosmetic only; config-driven; no new Lights; report parts and triangles;
never touch VehicleSim or scoring; the owner's uncommitted rig files
untouched; every visual change checked in Studio screenshots on every car.
