# Car bodies from the Creator Store

Every car from the store goes through the same steps and comes out split,
named and debadged the same way. Later customisation (paint, lamp colours,
plates, maybe decals and underglow) then works on every car without per-car
code.

## The body standard

**Piece names** are a role, then an optional detail after an underscore
(`Body`, `Body_Scoop`, `Trim_Grille`). Customisation finds pieces by role.

| Role | What it is | Drawn as |
|---|---|---|
| `Body` | Painted panels, and anything painted body colour (mirror caps, scoops, a spare wheel cover) | `paint = true` |
| `Glass` | Windows | the store's tint, `castShadow = false` |
| `HeadLamps` | The front lamp **lenses**: the piece a headlight colour goes on | `castShadow = false` |
| `TailLamps` | Rear lamp lenses | `castShadow = false` |
| `Indicators`, `ReverseLamps`, `FogLamps` | The other lamps | `castShadow = false` |
| `Chrome` | Bright trim | the store's colour |
| `Trim` | Black and grey plastic, grilles, lamp housings | the store's colour |
| `Underbody` | Floor, arch liners, suspension parts seen through the arches | the store's colour |
| `Interior` | The cabin, kept whole (the owner's rule) | `castShadow = false` |
| `Tyre`, `Rim`, `Rim_Face` | Wheel pieces, one left wheel mirrored to all four | tyre `Rubber` |

**Debadging.** Every maker's logo and every piece of model lettering goes:
grille, boot or tailgate, wheel centres, steering wheel, cabin. A badge that is
its own part is dropped. A badge inside a bigger mesh is cut out of that
mesh, and the mesh ships as a generated piece (`src/shared/CarMeshes/<Car>`)
or, better, is uploaded (below). Plate text goes too; the plate recess stays
blank for the game's own plates.

**Placement.** Car space as in RIG_SPEC.md: metres, front −Z, left −X,
origin on the ground under the wheelbase centre. Scale the store model so its
wheel centres sit on the real car's wheelbase.

**Triangles.** Keep the interior whole (the owner's rule). Drop what is
never seen: internals hidden inside the body (as on the Kamri), roof gear
(racks, boxes, jerry cans, roof spares, light bars), and plain parts and
unions the body builder cannot use. Keep the car's own wheels, simplified
with `simplify.py` into OBJs for upload so they still look right and fit.
Record the triangle count before and after in the catalog comment.

**The plate spot.** Every car keeps its plate mount or recess, blank. A bare
black block that reads as a hole is painted body colour (`paintParts` in
`storecar.py`) until the game's own plates go on it. Nothing may cover it:
a tailgate spare that hides a lamp or the plate is shrunk and moved
(`spare` in `storecar.py`), not left overlapping.

## Store scripts: what we keep

Store cars come with A-Chassis scripts. We never run them; we read them for
their sound ids and settings and rebuild what is worth having on our own
systems (the owner's call, 2026-09-25). Record every id you take in the
car's catalog entry, next to where it is used.

| Keep | Where it goes |
|---|---|
| Engine sound set (the loops and the rpm they were recorded at) | the car's `tuning.effects.engineAudio`: layer ids and `refRpm` |
| Ignition: start chime, starter, engine off | `effects.engineAudio` (`chimeSoundId`, `startSoundId`, `offSoundId`); the defaults are the store Camry's |
| Horn | the car's `tuning.effects.horn.soundId` (server `CarControls`, H to hold) |
| Lights | replaced, never run: our `CarLamps` lights the car's own lens pieces (below). A store light script is still the best guide to which parts are the lamps (the parts it switches) and their lit colours, so read it to assign the lamp roles |

| Leave | Why |
|---|---|
| A-Chassis itself: drive, tune, gauges, control plugins | our sim and HUD do these |
| Spotlights and beams at the lamps or exhausts | nothing lights the ground (the owner, 2026-09-25) |
| Backfire | tried on the Kruzer 80 and parked: the flame looked poor (`car-backfire`, BRANCH_STATUS.md) |
| Anything else (screens, decals, sirens) | not wanted so far; ask first |

## Lamps

`CarLamps` finds lamp pieces by name (`HeadLamps*`, `TailLamps*`,
`ReverseLamps*`) and lights the car's **own lenses**, never an overlay:

- A plain lens turns Neon in the lamp colour (`CarConfig` `effects.lamps`)
  and gets its own material, colour and transparency back when off.
- A textured lens (lamps painted into a shared texture, like the Kruzer
  80's) drops its texture while lit, since a texture hides the glow. Find
  which mesh carries the lamp photos by the faces' texture coordinates
  (`rbxcache.decode(..., with_uvs=True)` against the texture's lamp region)
  and give that part the lamp role.
- Tail lamps sit dim with the headlights on and jump to bright under
  braking. An opaque lens looks brighter than a glass one, so such a car
  takes a darker `tailColor` in its tuning (the Kruzer 80: 105, 5, 7).
- One mesh holding several lamps (the Kruzer 80's tail cluster: amber,
  reverse and red in one) glows as one until it is split into separate
  pieces, which means an upload.
- Nothing lights the ground: no headlight beams, no brake glow.

## Steps for a new car

1. Render the model in Studio (Edit, loaded with `game:GetObjects`, never
   inserted into the place) and dump every MeshPart to
   `assets/cars/<car>/parts.json`: mesh id, texture, colour, material,
   transparency, Size, CFrame, MeshSize.
2. Look for badges: colour one part at a time and take screen captures.
3. If a badge is inside a mesh, get that mesh from Studio's asset cache:
   `rbxcache.py <Size x y z>` finds it by proportions. Save it as
   `assets/cars/<car>/<piece>_source.obj`.
4. Add the car to `CARS` in `storecar.py`: the role of every part (lamp
   lenses included), what to drop (roof gear, badges, lettering, plain parts
   and unions), textures to drop or parts to make plain, the four tyres, a
   part at the front, the real wheelbase. It levels and turns the model from its wheel centres and
   writes the catalog lines with the triangle count. (`batrol.py` is the
   older one-car version, kept because its chrome is rebuilt.)
   Then look at every side in Studio for branding the part list missed:
   lettering is often a thin strip of its own, or in a shared texture.
   Heavy meshes that must stay (wheels) are simplified with `simplify.py`
   into OBJs for upload; until then the store mesh is used.
5. Read its scripts (above) and take the engine set, horn and ignition ids
   into the entry's `tuning.effects`.
6. Add the catalog entry, check `VehicleRig.validate`, spawn it, and measure
   it with the harness. Check the lamps lit, braking and reversing from
   behind and in front, and the plate spot, before calling it done.

## Generated pieces and EditableMesh

A generated piece is decoded into an EditableMesh on each client. That needs
"Allow Mesh / Image APIs" on (Studio: File > Game Settings > Security), and a
published game only gets it with the owner ID verified. Without it the piece
is a grey box. So each generated piece also gets an OBJ
(`assets/cars/<car>/<piece>.obj`). Import that with Studio's 3D Importer and
put the new mesh id on the piece (`meshId` wins over `mesh`), and no setting
is needed.

## Cars

| Car | Store asset | Script | Notes |
|---|---|---|---|
| Kamri (`kamri07`) | 876308553 | `store_body.py` (experiments) | Store meshes by id; badge parts dropped. Predates the standard: most pieces are still named `P<n>`, but its lamps have roles (`HeadLamps_P64`, `TailLamps_*`, `ReverseLamps_*`, `Indicators_P35`). Its own Camry engine set; the default ignition and horn are its own |
| Batrol (`batrol`) | 8941542327 | `batrol.py` | Store meshes by id; grille and tailgate badges cut from the chrome. Lamp pieces have roles (red glass tail lamps); its own horn |
| Kruzer 80 (`kruzer80`) | 13118106368 | `storecar.py` | Store meshes by id, interior kept; roof gear, badges and lettering dropped; own wheels; tailgate spare kept, shrunk to 0.8 to clear the right tail lamp; plate mount painted. Headlamp lens and tail clusters are textured lenses; darker tail colour. Its own engine loop and horn. 163,478 to 137,884 triangles, about 87,500 once the simplified rim and hub are uploaded |
