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
| `Lighting.luau` | Lamp posts on both shoulders and down the median (one store mesh each), sky, atmosphere, every Lighting setting. |
| `Signage.luau` | Lattice gantries with a framed board over each carriageway, roadside boards on twin posts, speed-limit signs. |
| `Cityscape.luau` | The backdrop skyline: a band along the right of the road, a downtown cluster near the start, two landmarks. |
| `Scatter.luau` | Palms, scrub clusters, acacia trees, rocks, debris, dune ridges, and the roadside camps: tent, carpet, camels. |
| `Dunes.luau` | The far dune field on the sunset side: sheets, ridges, seifs, crescents, mounds, sandstone outcrops. Persistent. |
| `Relief.luau` | The near desert and the edge of the world as one terrain surface: floor, berm, crest, back slope, plus the invisible stop. |
| `Materials.luau` | The sand and asphalt MaterialVariants, stamped across everything after the build. |
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
is 12.

**Signs are modelled, not sourced.** Every "highway sign" on the store is
a plain-part build of a US exit sign, so the gantries are built here the
way a Saudi motorway gantry is built: a lattice portal frame, each leg two
galvanised columns with ties and diagonals on a concrete base, the beam a
truss of two chords with verticals and a diagonal every bay, and a green
board hung under it on brackets over each carriageway, with a white border
strip round the face and stiffening rails on the back. Roadside boards
stand on twin posts and alternate green direction boards with blue
distance boards; a red-ring speed sign stands every 500 m on both
shoulders. About 130 parts a gantry, four gantries.

**The lamp post is one mesh.** A box pole with a box arm and a box head never
read as a lamp, from any distance: the owner called them out. The post is now
a single textured store mesh (BryanROBLOXgamer10's "Street Lamp Light",
`AssetRegistry.highwayLamp`: concrete pedestal, tapering pole, the curved
cobra arm and the head in one piece), cloned from one template at 1.15 for a
12.2 m highway post with the head 5.1 m out, and the pole a hand past the
kerb so the head hangs over the outer lane. The lens under the head is a
separate thin part, because the mesh has none: warm-white Neon at an hour
whose lamps are lit, pale glass otherwise, and it carries the light manager's
tag. A median post is two of the mesh back to back, the second 12 cm along
the road so the poles never share a surface and shimmer. The box build
survives only as the stand-in for when the mesh cannot load.

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

**The dune field is ellipsoids, because nothing else was available.** The
sunset side of the road gets a border of dunes from 750 m to 1.9 km out,
running from 900 m behind the start line to past the city. Terrain was the
obvious tool and is ruled out by streaming: terrain past the streaming radius
never reaches the client, and the field is entirely past it. EditableMesh
heightfields are locked behind an Experience security setting. The Creator
Store's only smooth dune shapes are Unions, which cannot be rebuilt from an
id at runtime, and the AI mesh generator produced a blob and a cone. So every
dune is a Part with a sphere SpecialMesh, which renders at any aspect (a Ball
part does not), rolled about its long axis so the road-facing side is a steep
slip face and sunk so the foot is buried. Five kinds layer up: broad flat
sheets so the floor rolls, long ridges parallel to the road, sharp-crested
seifs (two wedges at 33 and 17 degrees, a mound over each cut end), crescents
with horns toward the road, and low mounds that fade the field in from its
inner edge. Sandstone outcrops are store meshes. The tallest crest is 50 m at
1.3 km, a 2.2 degree silhouette that clears the sun-side berm crest at 1.3
degrees and stays well under a sun at 5.4; the build prints both numbers, and the skyline ring drops any site that would stand behind the
field so that side is dunes against sky. A field this far out is soft in the
golden-hour haze by design; the knob for that is the preset's atmosphere
density. Nothing in the field collides, and the whole model is Persistent.

**All the sand comes from one palette.** Six different sand colours had
accumulated across the ground plane, the dune field, the berm, the terrain,
the drifts and the median, which is why nothing matched. `WorldConfig` now
opens with three: a ground tone, a lighter wind-blown tone for crests and
drifts, and a darker one for compacted and shadowed ground. Every sand
surface in the world takes one of those three. Terrain renders about 1.15
times brighter than a part for the same tint, so the terrain tints sit one
step darker to come out as the same sand; that was matched from the air,
where the strip and the plane meet over the berm's back.

**The borders are off: plain flat sand.** The terrain strip, the berm and
the far dune field are all built and all disabled (`relief.enabled`,
`duneField.enabled`, `ground.dunes.enabled`). The owner asked for the desert
to go back to a plain flat plane, so it is the plane, the sand material, the
roadside scatter and nothing else; nothing stops the car leaving the road,
and running wide costs speed, not the run. The paragraphs below describe the
borders as built, for when they are wanted back.

**The near desert and the berm are one terrain surface.** A strip of smooth
terrain runs either side of the road, and it carries the whole cross-section
from a single height function: the desert floor from 40 m past the asphalt,
the berm rising out of that same floor to a crest, and a back slope down to
the plane. Because it is one function there is no seam in it. The berm used
to be a separate stack of wedges and boxes standing on the plane and every
one of its cut edges showed. The rise is a smoothstep, so it has no kink
where it leaves the floor and none at the crest, and its steepest point is
exactly 1.5 × height ÷ rise width: 15.6° on the driving side, 7.7° on the
sun side. The foot and the crest height wander along the road from a slow
noise, so the crest is a dune line rather than an extruded ramp. Two octaves
of undulation, a few hundred hummocks with scrub tufts (a nabkha is a bush
that caught sand) and gravel patches as a second terrain material run over
the whole strip, berm included.

Terrain is used here and nowhere else in the world because it only reaches
the client inside the streaming radius, and this strip is the one piece of
sand the car is ever near. Cost is held down two ways: the sand is a shell
3.5 m thick rather than solid to the plane, since nothing digs, and each
chunk writes only the vertical band its own surface occupies. 4.5 M cells,
about 2 s of the build.

**Measured from the driver's seat.** On the driving side the car climbs from
166 m out, reaches the crest at 237 m and 13.8 m up, and is held there with
98 km/h scrubbed down to 8. On the sun side it climbs from 250 m, tops out at
275 m and 6.8 m, and rolls back down to the road at 125 km/h, so that side
doubles as a banked turn-around rather than a stop.

**The invisible stop belongs to the terrain module.** It is a queryable
colliding ribbon on the crest, built from the same crest number the
heightfield used, so it cannot drift off the top. Queryable because a
colliding part with `CanQuery` off is not honoured reliably, and nothing else
raycasts out there.

**The ground plane is one tone.** An earlier pass split the near tiles four
by four and gave each a noise tint to break up the sheet. From the air that
drew the tile grid on the desert as hard-edged rectangles, which is worse
than a flat sheet, and it cost 600 parts. The plane is only ever seen beyond
the berm anyway, where the haze has it.

**Two material variants, both place assets.** Sand is a CC0 PBR set
(3Dtextures "Sand 005" via PixelHix: colour and normal; the set's roughness
map reads as glossy in Roblox and gave the desert a wet sheen with specular
glints on every crest toward the sun, so it is left out). Asphalt is
ambientCG Road007 colour via Euvanoa with a Poly Haven asphalt_01 normal via
dorndaft, tiled at 7 m. Only the carriageways, pad and bay are Asphalt;
kerbs, shoulders and every marking are Concrete, so the paint stays crisp
over a grainy surface. A MaterialVariant's maps cannot be written by a game
script — it needs plugin capability, and trying it in a server script throws
and takes the whole world build down — so both are declared in
`default.project.json` under MaterialService and the runtime only looks them
up, warning and falling back to the stock material if one is missing.

**The skyline's windows follow the lamps.** They are Neon only at a time of
day whose lamps are lit. A Neon slab in daylight is not a lit window, it is a
sticker, and golden-hour haze swallows a building body long before it
swallows an emissive part, so unlit-time Neon bands read as orange bars
floating on the horizon with nothing behind them. At golden hour they are
glass instead. The city's own shopfronts are left lit: they only read as bars
from an altitude no player reaches.

**The backdrop skyline is a band along the right of the road.** It used to
be a ring all round the road, then one cluster off the middle of it; both put
the city where the driver was not looking for most of the drive, and the
cluster was invisible from the start. Now it is a band on the side away from
the sun, from 1.1 km behind the start line to the city gateway, in two rows:
a low front row at 1.3 to 1.6 km so the towers behind have a foot, and the
tall row at 1.6 to 2.4 km. Density follows a curve along the band, full at
350 m from the start and easing to a third at the ends, and the dense
downtown cluster with the two landmarks sits at that peak, so from the start
line and from the spawn bay the city is square on the right, and it is still
there, thinner, at the far end. It stays inside 2.5 km because golden-hour
haze takes nearly everything past that; and the golden-hour atmosphere
density came down from 0.26 to 0.2 for the same reason, at which the city
reads as a lit city and the sunset side keeps its warm band.

**And it is lit at every time of day.** A dark silhouette out there is worth
nothing, and away from the sun the city has the sky to itself. Warm and cool
window bands, a lit crown on most of the towers, a lit roofline on more than
half the blocks, red beacons, vertical LED strips up the corners of seven in
ten towers, lit rings round half of them at random floors, and a lit needle
spire on a fifth; the strips, rings and spires draw from one weighted
palette, mostly gold and cool white with the odd magenta, cyan and green,
the way Riyadh's towers actually light up. The verticals are what read as a
modern Gulf skyline at this distance: they still catch the eye long after
the window grid has become a smear. A wide, low, faint slab of sodium haze washes the base of
the cluster; narrower or more solid and it stops being haze and becomes an
orange slab standing in the desert. The one care needed is that haze swallows
a building body long before it swallows an emissive part, so in daylight
every light here is pulled back by `lights.dayExtraTransparency`, or the
windows and strips float free of the towers they belong to.

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

**Lamps are on at golden hour, gently.** With the box heads a lit Neon slab
in daylight read as a yellow sticker; under the mesh head a warm-white lens
reads as a highway coming on at sunset, which is the hour this is. The
twelve pooled lights are SpotLights now, hung under the lens and shining
straight down in a 120 degree cone, so the light lands on the road as a pool
rather than glowing the air above the head; brightness and range still come
from the time of day, so night is brighter and longer than golden hour.

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
grows one block either side of it and two blocks south, and the skyline's
downtown cluster with its two landmarks stands beyond the grid's far edge,
so the towers rise dead ahead down the highway. The first build sat the
city off to one side with ramps and ringed the whole desert with low
blocks; the owner read the rings as random clusters of tiny buildings and
wanted the city ahead, so the rings and the ramps went (the ramp code
stays, driven by empty lists) and the old 30 degree curve at the end of
the straight went with them. Nothing hand-placed: `CityConfig.luau` and a
seeded random.

**Spawn.** The parking bay and the player spawn are on the transition
pad's right-hand wing (900 to 1,300 m down the road, off to the side of
the traffic) whenever the preset has a pad; a 40 m marked slab a
centimetre proud of the wing so the two never fight, ten slots across it,
with a painted line each side of every slot. Without a pad they fall back
to behind the start line. The spawn pad itself is invisible; it used to be
a white block on the wing.

**The pad is part of the road.** Each wing now widens in over a 60 m flat
asphalt triangle (a WedgePart on its side) at both ends instead of starting
with a square corner, a painted edge line runs round the wing and along the
diagonals, and the outer shoulder and kerb follow the wing's outer edge
rather than cutting straight across the pad, which used to split the wing
from the carriageway with a kerb line.

**Skyline.** The backdrop band along the right of the road, densest near
the start with the downtown cluster and the two landmarks there; see the
skyline notes above. It skips the city grid.

**Streets** (`Streets.luau`). A 2 x 2 grid of blocks 360 m across, about
770 m on a side. It was 4 x 2 at 420 m (1.7 km wide); the owner asked for
smaller and more refined, so the detail goes into each frontage instead.
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
district. The owner cut the villa blocks after the first build, and the
grid later came down to four blocks: commercial and towers either side of
the highway's arrival, then the plaza (the meet spot) and commercial
behind them, and the skyline's downtown beyond the far edge
(with a keep-out so no backdrop building lands in a street). *Commercial*: rows of shops along both boulevard frontages and one
side street, 18 to 36 m wide, 3 to 7 storeys, gaps between some; each has a
glazed shopfront, a coloured fascia, an awning on most, a lit sign on some,
a ground-floor colonnade on a third, balconies on the second and third
floors of nearly half, AC units hung on the front (the mesh), a blue blade
sign off the corner on some, a rooftop billboard on a tenth, pilasters on
some, a stain band at the base, a parapet lip with a row of Najdi
crenellations on two in five, AC units and a water tank on the roof. Most
carry a shop sign with the name in Arabic over English (pharmacy, grocery,
laundry, gold, perfumes and so on), an opaque box so the lettering reads;
a half-transparent Neon box bloomed over its own text. The lit window
strips are off: on a textured wall at golden hour they read as blank pale
panels. The interior
is a car park. *Residential*: walled villa compounds 28 x 30 m around all
four edges, one in ten left empty; each a 2.4 m compound wall with a gate
on the street side, a 2 or 3 storey house set back inside it, half with a
smaller upper tier, a dish on most roofs, a wall AC unit (the mesh) at
first-floor height. *Towers*: four podium-and-tower blocks, the podium
three storeys with shopfronts on every face, the tower 14 to 30 storeys of
glass with mullions and floor bands, half with a setback, a lit crown, a
plant room. *Plaza*: all four parcels are one flat asphalt slab each with a
few worn rows of bays through the middle, bollards and planters along the
edges, lamps through it; this is the meet spot. One parcel used to be a
mosque; the owner had it removed.
*Residential* and *lot* still exist in the generator but no block uses
them.

Walls collide (compound walls, houses, shops, podiums, shafts, gates);
nothing else in the buildings does.

**Furniture** (`Furniture.luau`). Palms down every boulevard median (two
meshes, date and fan) and on the islands; street lamps on both pavements
every 45 m and one side of side streets every 60 m, which are the
highway's cobra-head mesh post at 0.85 (a 9 m boulevard post, arm over the
road, warm-white lens tagged for the twelve-light manager; the owner found
the old low-poly bracket lamp poor); a traffic
signal (boxes) where each side street meets a boulevard; parked cars (two
unbranded bodies from a low-poly pack plus its wheel mesh, five parts each)
in the parking lanes at 18% of slots; bins and benches (meshes) along the
pavements; clipped hedges between the median palms; fan palms along the
shop fronts; bus shelters on the boulevards; zebra crossings across every
side-street mouth; bollards and planters round the plaza. Nothing here
collides.

**Counts.** City streets 691, street detail 1,660, buildings 6,013
(1,588 facade textures), furniture 5,605; skyline 1,145 parts (696
textures). Whole world 17,963 parts. The city is streamed; the highway
road, its palms and the skyline stay Persistent.

**Verified.** A raycast sweep every 2 m down the highway's right
carriageway into the gateway and on down the central boulevard (500
samples), and earlier along a boulevard through three roundabouts, a side
street and the plaza: no gaps, the surface within 5 cm everywhere except
the roundabout islands.

**Mesh buildings.** Two in five shop slots and half the tower spots take a
textured store mesh instead of a box: three office buildings from one pack
(a 71 m curtain-wall tower on a podium, a 37 m grey block, a 27 m cream
block with green glass), the plain modern offices a Riyadh business
district is full of. Each
is one MeshPart, cloned from a template loaded once by id, so nothing from
the store model itself ships. A block is scaled so its long side fills the
slot's frontage and its front sits on the shops' setback line, turned so
its long axis runs along the street; a tower is scaled within a per-mesh
range and never wider than a podium slot. This is where the real facades,
recessed windows and plant rooms come from; the box buildings around them
carry the tiled textures below.

**No Russian.** The owner saw Russian words in the city. They came from a
second facade pack whose blocks are St Petersburg streets with the shop
signs baked into the texture (СУПЕРМАРКЕТ, КАФЕ, ИГРОВОЙ). All of that pack
is out, along with its Soviet five-storey block, the slab tower (loose
wires and spikes round its base) and one classical European facade
texture. A pass over every TextLabel in the built world finds no Cyrillic,
and no rejected texture id is left on any part.

**Facade textures.** Every building body in the city and the skyline
carries a tiled window-grid texture on its four sides, three storeys a
tile, tinted toward the wall colour, with a random tile offset per
building so neighbours never line up: five mid-rise grids and five glass
grids from the Creator Store, all put on boards in the viewport and
looked at (no brands, no text). A decal id from the store does not load in
a Texture; the image behind it does, and the only way to get that id was
`InsertService:LoadAsset` on the decal inside Studio and reading
`Decal.Texture` (the public asset-delivery endpoint wants a login). The
textures replaced the window-band and mullion parts: city buildings went
from 9,046 parts to 6,013, and the skyline lost its per-floor bands too.
The lit window strip parts are now off in the city (litChance 0).

**Assets vetted and rejected.** In `AssetRegistry.luau`. The traffic light
and satellite dish listings were plain-part builds with scripts and are
built from boxes instead; the car pack's Cybertruck and Rimac are brands
and are not used; "Pacifico Parked Cars" are named after real models. Of
twenty-five "mesh building", "highway sign" and "desert bush" listings put
in the viewport for that pass, eight buildings, five plant clumps and one
tree were real single meshes; the rest were hundreds of plain parts, a
1.7 m prop titled as a building, or a green box. Five of the eight
buildings were later pulled for being European (see above). No paid kit
was needed.

**Scrub and trees.** The verge scrub draws from five desert grass and
shrub clumps (two free foliage sets that share meshes) plus the old bush,
all coloured to one olive, placed in clusters of one to four every 9 m
because desert scrub grows where the last plant held the sand; and an
acacia-style tree (a textured crown over a trunk) stands on the verge
every 150 m or so, the one thing besides the palms that breaks the horizon
at a driver's eye height.

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
| dune field (sheets, ridges, seifs, crescents, mounds, outcrops, scrub; Persistent) | 1,011 | ~90 |
| relief: near desert, berm and crest (terrain, not parts) | 4.5 M cells | 0 |
| relief walls (invisible, collide) | 10 | 0 |
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
