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
| `SteeringWheel` | The steering wheel, a piece of its own so the first-person view can turn it (2026-11-07). Cut out of the cabin mesh where the store model has it built in | `castShadow = false` |
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
their sound ids, settings and which parts do what, and rebuild what is worth
having on our own systems (the owner's call, 2026-09-25). Record every id you
take in the car's catalog entry, next to where it is used. Keep this file
current: when the standard changes, change it here in the same commit.

| Keep | Where it goes |
|---|---|
| Engine sound set (the loops and the rpm they were recorded at) | the car's `tuning.effects.engineAudio`: layer ids and `refRpm` |
| Ignition: start chime, starter, engine off | `effects.engineAudio` (`chimeSoundId`, `startSoundId`, `offSoundId`); the defaults are the store Camry's |
| Horn | the car's `tuning.effects.horn.soundId` (server `CarControls`, H to hold) |
| Lights | **the car's own lamp parts, our script.** The store model's built-in lamp meshes are kept and given the lamp roles; our `CarLamps` switches them (below). The store's light script is not run, but it is the best guide to which parts are the lamps (the parts it switches) and their colours, so read it to assign the roles. The Kamri and Batrol lamps are their store lamps this way |

| Leave | Why |
|---|---|
| A-Chassis itself: drive, tune, gauges, control plugins | our sim and HUD do these |
| Spotlights and beams at the lamps or exhausts | nothing lights the ground (the owner, 2026-09-25) |
| Backfire | tried on the Kruzer 80 and parked: the flame looked poor (`car-backfire`, BRANCH_STATUS.md) |
| Anything else (screens, decals, sirens) | not wanted so far; ask first |

## Lamps

The lamps are always the car's **own built-in lamp parts** from the store
model, never an overlay added on top. `CarLamps` finds them by role name
(`HeadLamps*`, `TailLamps*`, `ReverseLamps*`) and lights them:

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
- Light the part that has the lamp's visible shape. Some kits hide plain
  boxes inside the lamps to carry their lights (the Krown Vik's `F`, `R`):
  those stay trim. A lamp photo painted into a shared mesh is split out by
  texture coordinates (`split` under `cuts` in `storecar.py`), and a clear
  cover over a lamp lights with it, since it is the whole lamp face.
- Nothing lights the ground: no headlight beams, no brake glow.

## Plates

Every playable car carries a front and a rear number plate spot
(`src/shared/CarPlateMounts.luau`, keyed by car id), and every client draws
the plate from the car's `Plate` attribute (`src/client/CarPlates.luau`,
`src/shared/PlateStyles.luau`; design in
`docs/superpowers/specs/2026-09-26-number-plates-design.md`).

- **Frame:** car space in metres before the car's scale, the same as the
  catalog's `offsetM`. A front plate faces -Z, a rear plate +Z; `tiltDeg`
  leans the top in toward the car.
- **Format:** `short` (33.5 × 15.5 cm) or `long` (55 × 11 cm),
  whichever fills the recess. The plate is that size times the car's scale.
  Every plate style (Saudi; Dubai, `2026-09-27-dubai-plates-design.md`;
  Abu Dhabi and Kuwait, `2026-09-27-abu-dhabi-kuwait-plates-design.md`)
  comes in both formats, so a spot takes any style with no per-car work.
  Long plates differ a little by style (Saudi and Dubai 55 cm, Abu Dhabi and
  Kuwait 52 cm): the plate part takes the size of the plate shown, centred
  on the same spot.
- **Plate spot on the body:** keep the recess or bracket bare and
  uncovered (the body standard above). The plate goes on it.
- **Measuring, exact:** when the store model has a plate part, run
  `python3 tools/carbody/storecar.py <car> --spots <part>,<part>` for its
  centre, size and tilt. It prints `tiltDeg` with the sign CarPlateMounts
  uses (positive leans the top in toward the car), so enter it as printed.
- **Measuring, by eye:** spawn the car and call `CarPlates.place(car, mounts)`
  from the Client datamodel with trial numbers; screenshot front and
  behind; adjust.
- The contract lives here until the owner's rig rework lands in
  `RIG_SPEC.md`.

## Steps for a new car

1. Render the model in Studio (Edit, loaded with `game:GetObjects`, never
   inserted into the place) and dump every MeshPart to
   `assets/cars/<car>/parts.json`: mesh id, texture, colour, material,
   transparency, Size, CFrame, MeshSize. `storedump.luau` (a ModuleScript in
   Studio) prints them to Studio's log and leaves the model at the show spot
   with each part's index as its `DumpIndex` attribute (to colour or hide
   parts by index); `storedump.py <car>` writes parts.json with each mesh's
   triangles from the cache.
2. Look for badges: colour one part at a time and take screen captures.
3. If a badge is inside a mesh, get that mesh from Studio's asset cache:
   `rbxcache.py <Size x y z>` finds it by proportions. Save it as
   `assets/cars/<car>/<piece>_source.obj`, split it into connected islands to
   find the badge ones, and list a box around each under `cuts` in
   `storecar.py`: whole islands inside a box are removed, and the rest ships as
   a generated piece plus `<piece>.obj` for upload (the Lekzas chrome). A badge
   painted into a shared texture is cut by texture coordinates instead
   (`uvBoxes`, u and v from the top left of the texture; save the source with
   its texture coordinates), and the piece keeps its texture (the Krown Vik
   grille). A badge painted in the middle of a surface that must stay (a logo
   on an airbag pad) is painted out instead: `uvFlatten` points those faces at
   one plain spot of the texture (the Krown Vik Fleet's steering wheel).
   Raised lettering is often a tiny part with hundreds of triangles:
   drop it. Decals and `Texture` objects never reach the game (the body
   builder takes mesh and texture ids only), so plates and stickers drawn as
   decals go by themselves.
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
   A wheel piece whose texture carries a badge (a logo on the centre cap)
   is drawn plain instead: `wheelLook` gives its colour and material.
5. Read its scripts (above) and take the engine set, horn and ignition ids
   into the entry's `tuning.effects`. Work `refRpm` out from the kit's own
   pitch rule. Check each id loads in Play: store sounds can be private
   ("not authorized"), and then the car keeps the shared sound.
6. Add the catalog entry, check `VehicleRig.validate`, spawn it, and measure
   it with the harness. Look at the wheels from both sides next to the store
   model: a store model can have its wheel faces pointing into the car
   (`wheelFlip` in `storecar.py`). Check the lamps lit, braking and reversing from
   behind and in front, and add its plate spots to CarPlateMounts
   ("Plates" above) and check them front and behind, before calling it done.
7. The garage spots (CarCosmeticMounts: windows, the windscreen strip,
   the exhaust). `carprobe.py <car>` measures the body in car space with
   rays from the store meshes: `rear x y` for the bumper face over the tips,
   `up x z y0` for the underside over the pipe's end (riseM), `near` for the
   pieces round a point. Then `tools/cosmetics/strip_shapes.py --only <car>`
   (with the windscreen's MeshSize and faces in glass_meshes.json) fits the
   strip and leaves the other cars' strips alone.

## Finding store cars
Since 2026-11-07 every new car must also work in the first-person view
(the owner: "since i want a first person view also available for players i
need to redo the car search from ground up i think to make sure the interior
is there and the wheel and whatnot can move", and keep "the
triangle/vertices ... not too too much"). What a candidate needs:
- **A cabin seen from the driver's seat:** dash, dials, seats. Store cars
  often have seat parts but no cabin (the Land Cruiser 300 Sahara is a hollow
  shell), so look from the seat; the seat count proves nothing.
- **A steering wheel of its own,** so it can turn with the wheel. A-Chassis
  cars usually carry it as `Misc.SW`. A wheel built into the cabin mesh can be
  cut out by its islands the way badges are (`cuts` in `storecar.py`), at the
  cost of a generated piece until it is uploaded.
- **Left-hand drive** (Saudi roads).
- **Triangles:** body under about 100,000 at full detail, compared with the
  Kruzer 80's 137,884 (about 87,500 once its wheels are uploaded), the Lekzas'
  47,070 and the Krown Vik's 31,890. Wheels do not count against this: the
  standard simplifies them.

**Scanning.** Search the store (Studio MCP `search_asset`, free models; the
Arabic words for hajwala, هجولة, also find Saudi uploads), then:
1. Put `storescan.luau` in a ModuleScript in ServerStorage (Edit) and call it
   with about six ids at a time. Studio runs one script at a time, so calls
   go one after another.
2. Run `storescan.py` (the `rbxcache.py` venv) for each car's body and wheel
   triangles from Studio's own mesh cache. Studio will not give a script
   another creator's mesh (EditableMesh "no permission"), so the cache is the
   only way to count them.
3. Look at the survivors from outside and from the driver's seat in Studio,
   midday light (`Lighting.ClockTime`, put back after).

**Shortlist, 2026-11-07** (about 60 scanned; 16 kept their body under 160,000;
body and wheel triangles at full detail; "own part" means the steering wheel
is a separate part):

| Store model | Asset | Body | Wheels | Steering wheel | Cabin |
|---|---|---|---|---|---|
| 2012 Chevrolet Tahoe LTZ | 1370195897 | 38,752 | 5,360 | own part | full dash |
| 2006 Hyundai Sonata V6 | 9547275128 | 64,800 | (in body) | own part | photo-textured dash and dials |
| 2008 Honda Accord | 4913850907 | 67,801 | 21,996 | own part | full dash and dials |
| 2018 Lexus LX 570 V8 | 5882014754 | 70,042 | (in body) | own part | wood and leather, dials, screen |
| 2017 Nissan Patrol | 8255487895 | 71,818 | 15,816 | built in | basic, dark |
| 2012 Toyota Camry SE | 17767054086 | 73,965 | 14,460 | own part | textured dash, lit dials, screen |
| 2022 Toyota Land Cruiser 300 | 116150803764919 | 83,089 | 12,716 | own part | full dash, flat shading |
| 2013 Chevrolet Caprice | 106538814504056 | 86,978 | 3,360 | store page says it turns; not found by name | wood trim, dials; police box on the dash |
| 2019 Toyota Land Cruiser VXR | 16431614375 | 94,379 | 5,596 | built in | full dash and screen |
| 2023 Dodge Challenger SRT | 13904284505 | 133,157 | 33,060 | own part | excellent; heavy |
| Toyota Land Cruiser 200 | 14083131046 | 146,761 | 33,024 | own part | the best cabin found; heavy |

Turned down: the Land Cruiser 300 Sahara (10789549372, no cabin), the 1995
Supra (14947487233, right-hand drive), a Camry hajwala build (14322757408,
plain dash, the same Camry as the Kamri), the 2022 Hilux GR-S (15680293902,
its seat part is in the wrong place; not checked by hand), and the rest for
weight: most store Patrols, Super Safaris, LX570s, Caprices and newer Camrys
run 160,000 to 1,000,000 triangles.

## Generated pieces and EditableMesh

A generated piece is decoded into an EditableMesh on each client. That needs
"Allow Mesh / Image APIs" on (Studio: File > Game Settings > Security), and a
published game only gets it with the owner ID verified. The owner turned it
on for this experience on 2026-09-26. Without it the piece is left off the car
(it used to be a grey box, which covered the Batrol). Each generated piece also
goes into its car's upload file (below); once uploaded and given its
`meshId` (which wins over `mesh`), no setting is needed.

A client can hold only 8 EditableMeshes at once, whatever their size
(BEHAVIOURS.md, measured 2026-09-28), and a MeshPart made from one goes blank
when it is destroyed. So a generated piece's template (`MeshData.acquire`)
holds its slot while any car on that client shows it, and the last car to let
go frees it (`MeshData.release`, from `BodyBuilder.mount`). One car fits (the
most is the Kamri SE's 6), but a server with a few generated-piece cars in
view runs out, and the pieces that missed stay off those cars (one warning;
the next car tries again). Until 2026-11-07 every template was kept for the
session, and the fifth new store car spawned in a row came up without its
tail lamps and grille. The garage's modelled exhaust tips (`tools/cosmetics`,
the same buffers plus an optional per-position `colors` buffer that `MeshData`
reads) share the 8, count their users the same way, and back off below a
reserve so bodies come first. **Uploading a car's pieces is the real fix**: an
uploaded mesh takes no slot at all.

## Uploading generated pieces

`python3 tools/carbody/upload_objs.py` writes `assets/cars/upload/<Car>.obj`,
one per car still using generated pieces (not the owner's generated Kamri):
every piece an object named `<Car>_<Piece>`, decoded from the same buffers the
game reads, centred, and turned half round about Y beforehand because the
importer turns an OBJ half round on the way in.

1. Studio: File > Import 3D, pick the file, keep Studio Default (each object
   stays its own MeshPart), import. The importer uploads each mesh.
2. Run `tools/carbody/upload_ids.luau` in Edit: one line per piece with its
   new mesh id, its MeshSize and the generated sizeM to compare.
3. Put each id on its catalog piece as `meshId`, keeping `mesh`, `sizeM`,
   `offsetM` and the look (`meshId` wins). Check the car in Play from
   outside and from the seat, then delete the imported model.

## Cars

| Car | Store asset | Script | Notes |
|---|---|---|---|
| Kamri (`kamri07`) | 876308553 | `store_body.py` (experiments) | Store meshes by id; badge parts dropped. Predates the standard: most pieces are still named `P<n>`, but its lamps have roles (`HeadLamps_P64`, `TailLamps_*`, `ReverseLamps_*`, `Indicators_P35`). Its own Camry engine set; the default ignition and horn are its own. Plate spots by eye (boot-lid recess, front bumper band) |
| Batrol (`batrol`) | 8941542327 | `batrol.py` | Store meshes by id; grille and tailgate badges cut from the chrome. Lamp pieces have roles (red glass tail lamps); its own horn. Plate spots by eye (tailgate recess left of the spare, front over the intake slot) |
| Kruzer 80 (`kruzer80`) | 13118106368 | `storecar.py` | Store meshes by id, interior kept; roof gear, badges and lettering dropped; own wheels; tailgate spare kept, shrunk to 0.8 to clear the right tail lamp; plate mount painted. Headlamp lens and tail clusters are textured lenses; darker tail colour. Its own engine loop and horn. 163,478 to 137,884 triangles, about 87,500 once the simplified rim and hub are uploaded. Plate spots: rear exact (`--spots`, the store mount), front by eye |
| Lekzas (`lekzas`) | 5405292580 | `storecar.py` | Store meshes by id, interior kept; grille emblem, boot emblem and both boot scripts cut out of the chrome (a generated piece, `Chrome_3`, until its OBJ is uploaded). Its own lamps: glass headlamp lens, red glass tail lamps and high brake light, the white strip as reverse. Its own engine loop (refRpm 6260 from the plugin's pitch rule); no horn or ignition in the model, so the shared ones. 51,081 to 47,070 triangles. Plate spots by eye (boot recess, front bumper band) |
| Krown Vik (`krownvik`) | 2930898738 | `storecar.py` | Picked over 14407499990 on looks. Store meshes by id, interior kept; the maker's oval cut out of the grille and boot badge by texture coordinates (generated `Trim_2`, `Trim_4`, textured); wheel caps, steering-wheel badge and the raised boot lettering dropped. Lamps: the textured lamp faces (headlamps and corner lamps split out of the grille mesh, the tail-light mesh) plus the clear headlamp and reverse covers; the kit's `F`/`R` boxes stay trim. Darker tail colour (opaque lenses). Its own engine loop (refRpm 5000 from its kit's pitch rule), startup and horn; its door chime is private, so the shared chime. 32,976 to 31,890 triangles. Plate spots exact (`--spots`, the store plate parts) |
| Krown Vik Fleet (`krownvikfleet`) | 14407499990 | `storecar.py` | The fleet-trim Crown Vic (black grille, steel wheels); the owner asked for both. Store meshes by id, interior kept; grille and boot badges and both plates are parts of their own and dropped; the airbag's oval painted out (`uvFlatten`); the engine under the bonnet dropped. Its lamps are parts of their own: headlamp, lens, corner parking lamps and tinted covers light as the whole front lamp. No scripts or sounds in the model: the Krown Vik's engine, startup and horn. Its left rims and caps face into the car in the store model, so they are turned to face out (`wheelFlip`). Wheel SurfaceAppearances do not carry over. 27,355 to 27,017 triangles. Plate spots exact (`--spots`, the store plate brackets) |
| Tahu (`tahu`) | 1370195897 | `storecar.py` | Store meshes by id, interior kept; engine bay dropped; grille and tailgate bowties and the tailgate lettering are parts of their own and dropped; the model name over each front door's moulding cut out of the door chrome (generated `Chrome_3`, `Chrome_5`), the airbag's bowtie painted out (`uvFlatten`, generated `SteeringWheel`); the rims' texture (a bowtie on the cap) left off for plain metal (`wheelLook`). Its lamps are the kit's own lamp parts (F, FLI/FRI, R, RLI/RRI, RV, the fog and high brake lamps). Its own engine loop (refRpm 6936 from its kit's pitch rule), startup and horn. 44,112 to 31,321 triangles. Plate spots exact (`--spots`, the store plate parts) |
| Sonatta (`sonatta`) | 9547275128 | `storecar.py` | Store meshes by id, interior kept; engine dropped. Big shared meshes: the maker's badge front and back, its name, the model name and the engine badge are islands of the chrome and cut (generated `Chrome`); the window trim's texture carries the grille badge's backing (cut) and the tail lamps, whose islands are split out as the `TailLamps` piece (`split` by mesh-space `boxes`; generated `Trim_2`, `TailLamps`; red, amber and reverse glow as one); the airbag's badge painted out (generated `SteeringWheel`). Headlamps: the textured lamp units, whole. Its wheels are plain parts with decals, so the Batrol's wheel. Its own horn, startup and engine loop (refRpm a first guess). 64,800 store triangles (with the Batrol's wheels, 84,186). Plate spots exact (`--spots`, the store plate parts) |
| Akord (`akord`) | 4913850907 | `storecar.py` | Store meshes by id, interior kept; the maker's badge and its surround cut out of the grille chrome (generated `Chrome_6`), the boot badge and the script name out of the boot chrome (generated `Chrome_2`); no badge on its steering wheel. Lamps: the clear headlamp covers (the whole lamp face), the red cluster lenses with their cover and round lamps, the boot-lid bars, the kit's reverse lamps; the kit's light box inside the headlamps stays trim. No pipe in its meshes: a factory exhaust. Its own wheels, horn, startup and engine loop (refRpm 6650 from its kit's pitch rule). 89,797 to 87,874 triangles. Plate spots exact (`--spots`, the store plate parts) |
| Kamri SE (`kamri12`) | 17767054086 | `storecar.py` | Store meshes by id, interior kept. One part is nothing but badges (the maker's emblem front and back, the model name, the trim badge) and is dropped, with the shark-fin aerial (5,081 triangles), the horns behind the bumper and the invisible kit parts. The emblem's backing in the grille, cut, left a black oval, so it is split out and painted (a `split` with `paint`; generated `Trim_4`, `Body_7`); the tail and fog lamps are islands of the textured trim, split out (generated `Trim_3`, `TailLamps`, `FogLamps`); the airbag's emblem painted out (generated `SteeringWheel`); the tyres' lettered texture left off (`wheelLook`). Plates are decals on plain parts (dropped); their parts give the spots. Its own wheels and horn; no engine loop in its kit, so the shared one. 88,425 to 76,722 triangles |
| Kruzer 300 (`kruzer300`) | 116150803764919 | `storecar.py` | Store meshes by id, interior kept. Every badge is a part of its own and dropped: the maker's emblem on the grille, the tailgate, the airbag and the wheel centres, the tailgate lettering, the side trim badge; the tyres' lettered texture left off; the gauge display and the invisible kit parts dropped. The black oval behind the grille emblem split out of the grille plastic and painted (generated `Trim_19`, `Body_12`); a faint round recess stays moulded in the tailgate panel. Its lamps are the kit's own lamp parts with the red lenses lit as the lamp face. The steering wheel's eight parts are `SteeringWheel` pieces. No plate parts: plate spots from `carprobe.py` and checked by eye. No pipe in its meshes: a factory exhaust. Its own wheels, horn, chime, startup and engine loop (refRpm 7000). 95,805 to 88,763 triangles |

The pack cars (Hatch `hatch`, Pickup `pickup`, Cruiser `cruiser`) are older
single-mesh bodies, not store cars, so they are not in the table. Their plate
spots were measured by eye too: the Cruiser's painted boot recess, the
Pickup's rear bumper notch and the Hatch's rear panel, each with a front on
the bumper.
