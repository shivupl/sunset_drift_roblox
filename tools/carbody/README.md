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

**No store scripts, sounds or lights** ever enter the game: only mesh ids,
colours and materials are kept.

## Steps for a new car

1. Render the model in Studio (Edit, loaded with `game:GetObjects`, never
   inserted into the place) and dump every MeshPart to
   `assets/cars/<car>/parts.json`: mesh id, texture, colour, material,
   transparency, Size, CFrame, MeshSize.
2. Look for badges: colour one part at a time and take screen captures.
3. If a badge is inside a mesh, get that mesh from Studio's asset cache:
   `rbxcache.py <Size x y z>` finds it by proportions. Save it as
   `assets/cars/<car>/<piece>_source.obj`.
4. Add the car to `CARS` in `storecar.py`: the role of every part, what to
   drop (roof gear, badges, lettering, plain parts and unions), textures to
   drop or parts to make plain, the four tyres, a part at the front, the
   real wheelbase. It levels and turns the model from its wheel centres and
   writes the catalog lines with the triangle count. (`batrol.py` is the
   older one-car version, kept because its chrome is rebuilt.)
   Then look at every side in Studio for branding the part list missed:
   lettering is often a thin strip of its own, or in a shared texture.
   Heavy meshes that must stay (wheels) are simplified with `simplify.py`
   into OBJs for upload; until then the store mesh is used.
5. Add the catalog entry, check `VehicleRig.validate`, spawn it, and measure
   it with the harness.

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
| Kamri (`kamri07`) | 876308553 | `store_body.py` (experiments) | Store meshes by id; badge parts dropped. Predates the standard: its pieces are still named `P<n>` |
| Batrol (`batrol`) | 8941542327 | `batrol.py` | Store meshes by id; grille and tailgate badges cut from the chrome |
| Kruzer 80 (`kruzer80`) | 13118106368 | `storecar.py` | Store meshes by id, interior kept; roof gear, tailgate spare, badges and lettering dropped; 163,478 to 122,363 triangles, about 82,000 once the simplified rim and hub are uploaded |
