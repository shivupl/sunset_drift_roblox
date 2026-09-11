# WORLD — the Riyadh highway environment

Everything in the world is built from code at server start, from
`src/server/World/WorldConfig.luau`. Nothing is hand-placed and nothing lives
only in the place file. Change a number in the config and restart the server.

## Modules

| Module | Builds |
|---|---|
| `init.luau` | Entry point. Builds once, in order, and prints a part and triangle report. |
| `WorldConfig.luau` | Every tunable, in metres and degrees, grouped by system. |
| `RoadNetwork.luau` | The path, asphalt, shoulders, kerbs, markings, wear, ground, bay, spawn. |
| `Barriers.luau` | Jersey barriers, reflective markers, guard rail. |
| `Lighting.luau` | Lamp posts and every Lighting service setting. |
| `Signage.luau` | Overhead gantries with Arabic and English panels, roadside signs. |
| `Cityscape.luau` | The skyline ring. |
| `Scatter.luau` | Palms, rocks, debris. |
| `AssetRegistry.luau` | Mesh ids with the metadata each was vetted on. |
| `Build.luau` | Part and wedge construction. Not in the original module list; it exists so the performance flags are set in exactly one place instead of six. |
| `src/client/WorldLights.luau` | The light manager. Client-side because "nearest to the camera" only means something there. |

## The path is the backbone

A preset is a list of segment descriptors (`straight`, `curve`) that expands
into a waypoint list, or an explicit waypoint list. `RoadNetwork.toPath` turns
that into path points carrying a stud position, a travel-aligned CFrame, the
half width and the distance travelled.

Every other system places itself by sampling that path, so moving a waypoint
moves the barriers, lamps, signs and scatter with it. Two helpers do most of
the work:

- `ribbon` emits anything that runs along the road at a lateral offset —
  asphalt, shoulders, kerbs, edge lines, barriers, guard rails, tyre tracks.
- `repeatAlong` places a thing every N metres — dashes, markers, lamps,
  gantries, posts.

`testRoad` reproduces the Phase 0 physics road exactly: 2 km straight, a 400 m
transition pad at 900 m, a 400 m radius 30 degree curve. The `Road` model
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
compromise — a 2 km barrier is 25 parts instead of a thousand, and each
streams when you approach it.

**Joints.** Segments overlap only where the road turns. Overlapping on a
straight puts two coplanar top faces in the same place and z-fights; on a
curve the faces meet at an angle, resolve cleanly, and the overlap closes the
wedge gap on the outside edge.

**Boxes, not cylinders.** A Roblox cylinder is roughly 100 triangles and a box
is 12. Lamp poles are 26 cm square boxes. Nobody can tell at that section, and
across 200 lamps it is the difference between 3,600 and 30,000 triangles.

**The jersey profile.** A plain cuboid is the most obvious tell on a highway,
because the flared foot catches light differently from the wall and a box has
no foot. The barrier is a full-height body at the top width (the only
collidable piece, so the car slides along one flat wall), a wide flat base,
and a `WedgePart` flare on each side.

**Windows are parts, not a texture.** A texture would be one draw per building
instead of three or four, but it needs an asset to vet and upload, it is a
large-surface draw, and at 2.6 km a window grid resolves to a smear anyway.
Three or four Neon bands per building cost 12 triangles each and need no
asset.

**The skyline is a ring, not a band.** Two bands parallel to the road are
invisible *from* the road: looking down the straight you see the gap between
them. A ring puts skyline in every viewing direction.

## Lighting and the time of day

`timeOfDay` selects a preset from `timesOfDay`: `dusk` (default), `goldenHour`,
`blueHour`, `night`. Each carries its own ClockTime, ambient, brightness,
colour shift, atmosphere, sun rays and whether street lamps are lit.

Sun position is ClockTime plus GeographicLatitude; Roblox exposes no azimuth
control. Measured with `Lighting:GetSunDirection` at latitude 24.7, the sun
sits 91 degrees to the road at every evening hour, which is as close to
raking straight across the asphalt as the engine allows. ClockTime 17.7 puts
it 4 degrees up, 17.95 on the horizon, 18.2 three degrees under.

**No Sky object, and that is the whole trick.** A `Sky` instance with no
textures does not fall back to something procedural: it renders Roblox's
default skybox, a painted daytime blue that darkens at night but never turns
warm at sunset. With no Sky object the engine draws its procedural dome, which
tracks ClockTime and lets Atmosphere colour the horizon. `useSkyObject` stays
as the hook for a painted skybox once six texture ids are vetted.

Atmosphere `Haze` smears the atmosphere colour across the whole dome, not just
the horizon. Above about 1 the warm tint reaches the zenith and mixes with the
blue into olive.

### Two settings a script cannot touch

Both must be set by hand in Studio. A runtime script cannot write them, and
`Lighting.Technology` cannot even be read back.

| Setting | Where | Value |
|---|---|---|
| `Lighting.Technology` | Lighting, Properties panel | `ShadowMap` |
| `Workspace.StreamingTargetRadius` / `StreamingMinRadius` | Workspace, Properties panel | 2048 / 512 |

`Workspace.StreamingEnabled` is already on. Under Voxel the raking shadows
this hour is built around do not render, and the scene falls flat.

## Performance

**The twelve lights.** No lamp carries a Light instance. The server tags each
Neon head and the client keeps a pool of exactly `maxLiveLights` PointLights,
moving them to the nearest tagged heads every `lightUpdateInterval` (0.25 s).
The pool is a fixed size, so the cap is structural rather than a policy
something can violate. Measured at 12 live lights with 34 lamps streamed in.

**Shadows are counted, not sized.** Shadow cost scales with the number of
casters. With barriers casting, 643 casters sat in frustum at once. The rule
is few and tall: lamps, gantries and palms cast because their long raking
shadows are what make the hour read; barriers and the guard rail do not,
because a kilometre of barrier throws a thin strip nobody looks at.

**Guard rail posts.** Real posts are about 2 m apart. At 2.2 km that is 1,100
posts a side. `railPostSpacingM` is 12 m; it is the most expensive single
number in the config.

**Streaming and client-side physics.** The client owns its car's physics, so
the suspension raycast runs against whatever the *client* has. A car at
240 km/h outruns the streamer, finds no road under it and falls out of the
world — which is what happened before `roadPersistent` was turned on. The road
and the barriers are `ModelStreamingMode.Persistent`; a barrier that has not
streamed in is one the car drives through. The skyline is Persistent too, so
the horizon never pops. Everything else streams.

**Every scenery part** is Anchored, `CanTouch = false`, `CanQuery = false` and
`CanCollide = false`. The exceptions are the road surface, shoulders, kerbs,
ground and the jersey barrier body, which need collision and queries so the
car can find them.

**Nothing loops.** The world is built once and never rebuilt. The only thing
still running is the light manager, on a timed loop with an exit flag.

## Measured

Scenery in frustum from the driver's camera at 181 km/h, `testRoad` preset:

| | parts | est. triangles |
|---|---|---|
| in frustum | 1,803 | 21,164 |
| shadow casters in frustum | 119 | |
| whole world | 3,600 | 43,000 |

Roblox does not expose triangle counts to Lua, so these are the standard
per-shape figures: box 12, wedge 8, cylinder ~100. Read the real number from
Studio's own performance stats.

Frame rate from this session is **not reportable**. Studio pinned at exactly
15.0 fps regardless of load; hiding all 2,884 scenery parts moved it to 14.7,
which proves it was a window throttle and not render cost. Earlier in the same
session, focused, the same scene ran at 59–60 fps. Measure it with the Studio
window focused, or on a device.
