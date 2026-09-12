# WORLD — the Riyadh highway environment

Everything in the world is built from code at server start, from
`src/server/World/WorldConfig.luau`. Nothing is hand-placed and nothing lives
only in the place file. Change a number in the config and restart the server.

## Modules

| Module | Builds |
|---|---|
| `init.luau` | Entry point. Builds once, in order, and prints a part and triangle report. |
| `WorldConfig.luau` | Every tunable, in metres and degrees, grouped by system. |
| `RoadNetwork.luau` | The path, both carriageways, the median, shoulders, kerbs, ground, bay, spawn; and the markings and wear, which it puts in a separate streamed `RoadDetail` model. |
| `Lighting.luau` | Lamp posts on both shoulders and down the median, sky, atmosphere, every Lighting setting. |
| `Signage.luau` | Overhead gantries with a panel over each carriageway, roadside signs. |
| `Cityscape.luau` | The skyline: two rings, a downtown cluster ahead of the road, two landmarks. |
| `Scatter.luau` | Palms, scrub, rocks, debris, dune ridges, and the roadside camps: tent, carpet, camels. |
| `AssetRegistry.luau` | Mesh props by id, the loader, and the provenance of everything vetted. |

There is no barrier module any more. Nothing stands between the road and the
sand, and nothing on the map collides except the ground: the asphalt, the
median strip, the shoulders and the sand tiles. Kerbs are a 7 cm visual lip
with collision off, because a collidable step at 200 km/h is a launch ramp.
| `Build.luau` | Part and wedge construction. Not in the original module list; it exists so the performance flags are set in exactly one place instead of six. |
| `src/client/WorldLights.luau` | The light manager. Client-side because "nearest to the camera" only means something there. |

## The path is the backbone

A preset is a list of segment descriptors (`straight`, `curve`) that expands
into a waypoint list, or an explicit waypoint list. `RoadNetwork.toPath` turns
that into path points carrying a stud position, a travel-aligned CFrame, the
half width and the distance travelled.

Every other system places itself by sampling that path, so moving a waypoint
moves the lamps, signs and planting with it. Two helpers do most of
the work:

- `ribbon` emits anything that runs along the road at a lateral offset —
  asphalt, median, shoulders, kerbs, edge lines, tyre tracks.
- `repeatAlong` places a thing every N metres — dashes, markers, lamps,
  gantries, posts.

`testRoad` keeps the Phase 0 layout — 2 km straight, a 400 m transition pad
at 900 m, a 400 m radius 30 degree curve — widened to a 120 m dual
carriageway. A preset's `widthM` is the whole corridor; `road.medianWidthM`
comes out of the middle and each carriageway gets half of what is left, so
120 with a 14 m median is two 53 m five-lane carriageways.
`RoadNetwork.layout` is the one place that arithmetic lives, and lamps,
signs, markings, wear and planting all read from it. The `Road` model
keeps the attributes `CarSpawner` and `VehicleController` read
(`HalfWidthStuds`, `LengthStuds`, `SurfaceY`, `BayCFrame`, `StartCFrame`), so
the vehicle code needed no changes.

## Geometry decisions

**Merging, and its limit.** Consecutive path points whose headings agree
within `straightThresholdDeg` are emitted as one part. But merging to the
engine's 2048 stud cap is a trap: a part belongs to the streaming region
containing its *centre*, so a 2048 stud slab is absent until you are nearly on
top of it. The first build did exactly that and the client held six road
parts while the car drove into a void. `maxMergedRunM` (80 m) is the
compromise — a 2 km carriageway is 28 slabs instead of a thousand, and each
streams when you approach it.

**Joints.** Segments overlap only where the road turns. Overlapping on a
straight puts two coplanar top faces in the same place and z-fights; on a
curve the faces meet at an angle, resolve cleanly, and the overlap closes the
wedge gap on the outside edge.

**Boxes, not cylinders.** A Roblox cylinder is roughly 100 triangles and a box
is 12. Lamp poles are 26 cm square boxes. Nobody can tell at that section, and
across 200 lamps it is the difference between 3,600 and 30,000 triangles.

**Windows are parts, not a texture.** A texture would be one draw per building
instead of three or four, but it needs an asset to vet and upload, it is a
large-surface draw, and at 2.6 km a window grid resolves to a smear anyway.
Three or four Neon bands per building cost 12 triangles each and need no
asset.

**Meshes load one way only.** `MeshPart.MeshId` is not writable from a
script, so a registry that news up a MeshPart and sets the id is a silent
no-op. The loader uses `AssetService:CreateMeshPartAsync` once per mesh id,
caches the result, and clones it for every placement. That is what makes
planting six hundred mesh pieces at server start take under two seconds, and
it is also the anti-script guarantee: the Creator Store model the id came from
never enters the game, only the bare mesh does.

**Terrain is parts, and sized under the cap.** The sand is 550 m tiles. The
first pass used 900 m tiles, a Part axis silently caps at 2,048 studs, and
the desert had holes in it near the curve. Undulation is low ridges built from
two wedges back to back, most of each sunk into the plane, scattered beyond
the shoulder band from the same seeded random as everything else.

**The skyline is a ring, not a band.** Two bands parallel to the road are
invisible *from* the road: looking down the straight you see the gap between
them. A ring puts skyline in every viewing direction.

## Lighting and the time of day

`timeOfDay` selects a preset from `timesOfDay`: `goldenHour` (default),
`dusk`, `blueHour`, `night`. Each carries its own ClockTime, latitude,
ambient, brightness, colour shift, atmosphere, sun rays, whether street lamps
are lit and whether to use a painted skybox.

**Sun azimuth is a latitude, not a setting.** Roblox exposes no azimuth
control. Measured with `Lighting:GetSunDirection`: at Riyadh's real 24.7
degrees the evening sun sits exactly 90 degrees off the road, so driving down
it you look at a blue sky with the sunset off-screen to both sides and every
shadow runs straight across. At latitude 60 the sun swings to 127 degrees —
ahead and to the left — so the warm sky is in the windscreen and palm shadows
run diagonally across the asphalt toward the camera. That is what golden hour
uses. The number is a lever on the look, not a claim about geography.

**The skybox is painted, and that is why the sky is warm.** The procedural
dome stays day-blue until the sun is actually on the horizon and only then
turns warm, by which point the road is too dark. Golden hour uses a
photographed sunset skybox (six textures, no scripts, nothing branded; the
provenance is in `AssetRegistry.skyboxes`). Dusk and night keep the procedural
dome, which is correct for them because they want it dark.

**Lamps are off at golden hour.** A lit head is a Neon slab, and in daylight a
Neon slab reads as a yellow sticker; a dark housing reads as a lamp. Dusk and
night light them, through the same twelve-light manager, with the head going
Neon only in a preset where the lights are actually on.

### Two settings a script cannot touch

Both must be set by hand in Studio. A runtime script cannot write them, and
`Lighting.Technology` cannot even be read back.

| Setting | Where | Value |
|---|---|---|
| `Lighting.Technology` | Lighting, Properties panel | `ShadowMap` |
| `Workspace.StreamingTargetRadius` / `StreamingMinRadius` | Workspace, Properties panel | 2048 / 512 |

`Workspace.StreamingEnabled` is already on. Under Voxel the raking shadows
this hour is built around do not render, and the scene falls flat.

## The city section (`src/server/World/City/`)

A Riyadh-style city where the highway is going. The 2 km straight ends in
the city's gateway roundabout, a 72 m square the full 64 m of highway
lands on; the highway centreline is the grid's central boulevard, the grid
grows two blocks either side of it and two blocks south, and the skyline's
downtown cluster with its two landmarks stands beyond the grid's far edge,
so the towers rise dead ahead down the highway. The first build sat the
city off to one side with ramps and ringed the whole desert with low
blocks; the owner read the rings as random clusters of tiny buildings and
wanted the city ahead, so the rings and the ramps went (the ramp code
stays, driven by empty lists) and the old 30 degree curve at the end of
the straight went with them. Nothing hand-placed: `CityConfig.luau` and a
seeded random.

**Streets** (`Streets.luau`). A 3 x 2 grid of blocks 420 m across.
Boulevards are 44 m kerb to kerb: an 8 m palm median, three 5 m lanes and a
3 m parking lane each way. Every boulevard crossing is a roundabout with a
15 m island (kerb ring, ground fill, five palms), sized so it is a drift
spot; the gateway one is a 72 m square and the two parcels that touch it
back off to its edge. Each block has one 16 m side street each way through its middle,
meeting at a plain crossing and ending at the boulevard kerbs, which cuts
the block into four parcels. Streets are slabs at the highway surface
height with the sand 5 cm below, so a slab that has not streamed in is a
step, not a hole; roundabout squares are their own slab and segments run
between them so nothing coplanar overlaps. Kerbs and pavements are drawn
per parcel (which is what leaves the kerb gap where a side street enters)
and do not collide. Boulevard markings are in a streamed `StreetDetail`
folder: worn dashes, parking-lane and median lines, tyre tracks in the
inner two lanes. Ramps, when a preset lists any, are waypoint paths
through the same `RoadNetwork.ribbon` the highway uses.

**Buildings** (`Buildings.luau`). Each parcel is filled by its block's
district. The owner cut the villa blocks after the first build, so the eight
blocks are commercial, towers, towers, commercial / commercial, plaza,
commercial, commercial: one dense core with the tower blocks either side
of the highway's arrival, and the skyline's downtown behind its far edge
(with a keep-out so no backdrop building lands in a street). *Commercial*: rows of shops along both boulevard frontages and one
side street, 18 to 36 m wide, 3 to 7 storeys, gaps between some; each has a
glazed shopfront, a coloured fascia, an awning on most, a lit sign on some,
a ground-floor colonnade on a third, balconies on the second and third
floors of nearly half, AC units hung on the front (the mesh), a vertical
lit sign box off the corner on some, a rooftop billboard on a fifth,
pilasters on some, a stain band at the base, window strips on the lower
three storeys split into lit and dark segments and one dark band per storey
above, a parapet lip, AC units and a water tank on the roof. The interior
is a car park. *Residential*: walled villa compounds 28 x 30 m around all
four edges, one in ten left empty; each a 2.4 m compound wall with a gate
on the street side, a 2 or 3 storey house set back inside it, half with a
smaller upper tier, a dish on most roofs, a wall AC unit (the mesh) at
first-floor height. *Towers*: four podium-and-tower blocks, the podium
three storeys with shopfronts on every face, the tower 14 to 30 storeys of
glass with mullions and floor bands, half with a setback, a lit crown, a
plant room. *Plaza*: three of its four parcels are one flat asphalt slab each with a
few worn rows of bays through the middle, bollards and planters along the
edges, lamps through it; this is the meet spot. The fourth parcel is the
mosque: courtyard wall, prayer hall with arched openings, a drum, a lit
band and a dome, two minarets with galleries, palms in the corners.
*Residential* and *lot* still exist in the generator but no block uses
them.

Walls collide (compound walls, houses, shops, podiums, shafts, gates);
nothing else in the buildings does.

**Furniture** (`Furniture.luau`). Palms down every boulevard median (two
meshes, date and fan) and on the islands; street lamps (mesh, ItsLassie's
pack, lamp 6 at 0.16) on both pavements every 60 m and one side of side
streets every 75 m, heads tagged for the twelve-light manager; a traffic
signal (boxes) where each side street meets a boulevard; parked cars (two
unbranded bodies from a low-poly pack plus its wheel mesh, five parts each)
in the parking lanes at 18% of slots; bins and benches (meshes) along the
pavements; clipped hedges between the median palms; fan palms along the
shop fronts; bus shelters on the boulevards; zebra crossings across every
side-street mouth; bollards and planters round the plaza. Nothing here
collides.

**Counts.** City streets 691, street detail 1,660, buildings 9,046,
furniture 5,605; skyline 940 (downtown and landmarks only). Whole world
20,791 parts. The city is streamed; the highway road, its palms and the
skyline stay Persistent.

**Verified.** A raycast sweep every 2 m down the highway's right
carriageway into the gateway and on down the central boulevard (500
samples), and earlier along a boulevard through three roundabouts, a side
street and the plaza: no gaps, the surface within 5 cm everywhere except
the roundabout islands.

**Assets vetted and rejected.** In `AssetRegistry.luau`. The traffic light
and satellite dish listings were plain-part builds with scripts and are
built from boxes instead; the car pack's Cybertruck and Rimac are brands
and are not used; "Pacifico Parked Cars" are named after real models. No
paid kit was needed.

**Frame rate.** Not measured from a focused window: the Studio window
cannot be focused from the MCP session and throttles to 15 fps unfocused.
The shadow caster count is the number to watch on a phone (about 900 in
the whole city, of which a few hundred are in view at once); `shadows` in
CityConfig turns palms or buildings off per type.

## Performance

**The twelve lights.** No lamp carries a Light instance. The server tags each
Neon head and the client keeps a pool of exactly `maxLiveLights` PointLights,
moving them to the nearest tagged heads every `lightUpdateInterval` (0.25 s).
The pool is a fixed size, so the cap is structural rather than a policy
something can violate. Measured at 12 live lights with 34 lamps streamed in.

**Shadows are counted, not sized.** Shadow cost scales with the number of
casters. An earlier pass with a kilometre of barrier casting put 643 casters
in frustum at once and cost 45 fps. The rule is few and tall: lamps, gantries
and palms cast because their long raking shadows are what make the hour
read; markings, scrub, rocks and the skyline do not.

**Guard rail posts.** Real posts are about 2 m apart. At 2.2 km that is 1,100
posts a side. `railPostSpacingM` is 12 m; it is the most expensive single
number in the config.

**The road's paint streams; the road does not.** Road is Persistent so the
car always has a surface, and a child of a Persistent model is Persistent
too, which meant every client held all twelve hundred dashes and tyre
tracks at all times. They now live in a sibling `RoadDetail` model that
streams like any decoration. None of it is physics.

**Streaming and client-side physics.** The client owns its car's physics, so
the suspension raycast runs against whatever the *client* has. A car at
240 km/h outruns the streamer, finds no road under it and falls out of the
world — which is what happened before `roadPersistent` was turned on. The road
is `ModelStreamingMode.Persistent`. The skyline is Persistent too, so
the horizon never pops. Everything else streams.

**Every scenery part** is Anchored, `CanTouch = false`, `CanQuery = false` and
`CanCollide = false`. The exceptions are the road surface, shoulders, kerbs,
ground, which need collision and queries so the
car can find them.

**Nothing loops.** The world is built once and never rebuilt. The only thing
still running is the light manager, on a timed loop with an exit flag.

## Measured

Whole world, `testRoad` preset, six lanes each way in a 64 m corridor with an
8 m median:

| system | parts | of which meshes |
|---|---|---|
| road (carriageways, median, shoulders, ground, bay) | 483 | 0 |
| road detail (markings, wear; streamed) | 1,603 | 0 |
| lamps (both shoulders, and the median at twice the density) | 794 | 0 |
| cityscape (two rings, downtown, two landmarks; Persistent) | 2,071 | 0 |
| signage | 40 | 0 |
| scatter (palms, scrub, rocks, dunes, camps, camels) | 629 | ~520 |
| **total** | **5,620** | **~520** |

The skyline is the biggest change from the first pass, which was ninety
boxes in one ring at 2.6 km and read as a bar chart. It is now two rings
(1,350 m and 1,900 m) of blocks and towers with tiers, lit crowns, antennas
and per-floor window segments, a dense downtown cluster of 44 slim towers
in the sector the road points at, and two landmark towers in that cluster:
a Kingdom-Centre style arch (slab, two pillars, sky bridge) and a Faisaliah
style pyramid from four corner wedges with a globe near the tip. All boxes
and wedges, no meshes, about 25,000 triangles, all Persistent so the horizon
never pops. A CornerWedgePart's tall corner is at its local (+X, -Z), found
by raycast; the docs do not say.

In frustum from the driver's seat, primitives only (mesh triangles are not
countable, see below):

| | parts | mesh pieces | primitive tris | shadow casters |
|---|---|---|---|---|
| parked at the start line | 1,178 | 59 | 13,400 | 95 |
| 105 km/h | 1,041 | 20 | 12,200 | 33 |
| 161 km/h | 838 | 0 | 10,000 | 0 |

That last row is why the palms are now Persistent: with the default streaming
radius nothing planted was in view at speed.

Only the asphalt, median, shoulders, pad, bay, spawn and sand collide. The
build-time audit printed exactly those names and nothing else.

Triangle counts for the meshes are the honest gap. Roblox does not expose
them to Lua, and `EditableMesh` refuses assets the place owner did not upload,
so the date palms, scrub and rocks cannot be counted from here. Read them from
Studio's Asset Manager, or from the render stats with the window focused.

Frame rate cannot be read from an MCP session: Studio throttles an unfocused
window to a flat 15 fps regardless of load (hiding every scenery part changed
nothing), and a scripted click into the viewport does not take focus. The
debug panel now shows FPS on its first line; press play, click the viewport,
and read it there.
