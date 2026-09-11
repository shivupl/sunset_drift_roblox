# Environment Build — Agent Prompt

Copy everything below the line into the agent.

---

Build the night-time Riyadh highway environment. Everything is procedural,
config-driven, and constructed at runtime from code in the repo. Nothing is
hand-placed in Studio and nothing lives only in the place file.

## Scope of this task

In: road network, barriers, lighting, signage, buildings, terrain, sky and
atmosphere, prop scattering, performance budget, and a small set of vetted
mesh assets referenced by ID.

Out: vehicles, UI, scoring, gameplay systems. Do not touch VehicleSim,
CarConfig, or anything under src/client/Vehicle.

## The vibe

A Riyadh ring road at night. Warm sodium lamps at regular spacing over dark
asphalt, a city glow on the horizon, palm silhouettes along the shoulder,
occasional overhead gantries. It should feel alive but empty — the road
belongs to the drivers. Think a real highway at 1am, not a neon racing game
and not a dead grey void.

Specifically:
- Warm amber pools of light with dark gaps between them. Rhythm matters more
  than brightness; a car passing under lamps should pulse light-dark-light.
- A visible city skyline in the distance, mostly silhouette with scattered
  lit windows. Never reachable, never collidable.
- Desert sand beyond the shoulder, fading into haze.
- Deep blue-black sky with stars, not pure black.
- Clean and readable at speed. The player is reading drift angle and road
  edges, not scenery. Anything that competes with that is wrong.

## Architecture

Create `src/server/World/` with:

- `init.luau` — entry point, builds the world once at server start, in order
- `WorldConfig.luau` — every tunable, in real units, same style as CarConfig
- `RoadNetwork.luau` — road, markings, shoulders from a waypoint table
- `Barriers.luau` — jersey barriers, guard rails, fences
- `Lighting.luau` — lamp posts, their emitters, and all Lighting service setup
- `Signage.luau` — overhead gantries, road signs
- `Cityscape.luau` — distant skyline
- `Scatter.luau` — rule-based prop placement (palms, rocks, debris)
- `AssetRegistry.luau` — table of mesh asset IDs with metadata

Existing `RoadBuilder.luau` gets folded into `RoadNetwork.luau`. Keep the
test road buildable from a config flag so I can still tune physics on it.

## Primitives vs meshes

**Build from primitives (Parts, WedgeParts, unions avoided):**
Road segments, lane markings, shoulders, kerbs, jersey barriers, guard rails,
chain-link fence posts and panels, lamp post poles and arms, sign gantry
frames, distant building blocks, ground plane. These are boxes, cylinders and
wedges. They cost almost nothing and I can retune spacing without re-placing
anything.

**Use meshes (from Creator Store, by asset ID):**
Date palms, lamp housings if a primitive one looks wrong, fuel station canopy
if we add one later, a rock or two for the desert. That's it. Roughly five
to eight distinct meshes for the whole scene.

Before using any mesh, check via the Studio MCP if you can, otherwise ask me
to check: triangle count under 3,000, zero scripts, creator has a real upload
history. Reject anything with a real-world brand modeled or named. Report
each candidate to me with ID, creator, triangle count and script count, and
wait for my pick. Do not insert anything permanently into the place — the
IDs go in `AssetRegistry.luau` and the builder loads them at runtime.

If you cannot search assets through the MCP, say so and I will supply IDs.
In the meantime build with primitive stand-ins so the layout is testable.

## Rules per asset type

**Road**
- Defined by a waypoint table: position, width, banking, segment type.
- Generate segments between waypoints, no gaps, no z-fighting at joins.
- Lane markings as separate thin parts offset above the surface by a config
  epsilon. Dashed with config dash length and gap.
- Shoulder strip either side, slightly different colour, then sand.
- Keep the 2km straight, the 400m transition pad and the 400m radius curve
  from the current test road as a named config preset.

**Jersey barriers**
- Both sides of the road, continuous, at config distance from the edge.
- Built as one part per segment, not per barrier, where the run is straight —
  a 200m straight barrier is one part, not fifty.
- CanCollide true. This is the only scenery the car should ever hit.

**Lamp posts**
- Config spacing (default 40m), alternating sides or both sides, config.
- Pole, arm, housing. Emitter is a small part with a SurfaceLight or
  PointLight, warm amber, config range and brightness.
- CanCollide FALSE on everything. A lamp post should never stop a drifting
  car. Same for signs, fences, palms and all scatter.
- Crucially: only the nearest N lamps have active Light instances (config,
  default 12). The rest are unlit geometry. See performance below.

**Signage**
- Overhead gantries every config distance (default 600m), spanning the road.
- Green sign panels with Arabic and English text via SurfaceGui. Text content
  from a config table — I will supply real road names later; use placeholders
  now and mark them clearly as placeholder.
- Small roadside signs scattered by rule at lower frequency.

**Cityscape**
- A band of simple box buildings on the horizon, config distance out,
  generated with varied heights and widths from a seeded random.
- Windows as an emissive texture or scattered small emissive parts — pick
  whichever is cheaper and say which you chose and why.
- CanCollide false, CastShadow false, and far enough out that it never
  streams in as detail. This is a backdrop, not a place.

**Scatter (palms, rocks, debris)**
- Rule-based: config spacing, jitter range, minimum and maximum distance
  from road edge, density falloff with distance, seeded random so the world
  is identical every server.
- Palms cluster loosely rather than spacing evenly — clumps of two or three
  with gaps between, which reads as planted rather than generated.
- Never inside the barrier line. Never on the road. Never overlapping.
- CanCollide false on all of it.

**Ground**
- Large sand plane well beyond the road so running off never falls.
- Slight colour variation between near and far, or a subtle texture, so it
  isn't a flat colour sheet.

**Sky and atmosphere**
- Deep blue-black sky with stars, not pure black. Custom Sky with a starfield
  or a tuned default.
- Atmosphere with config density and haze colour to fade the horizon and sell
  distance. This is what makes the cityscape read as far away.
- ClockTime for night, ambient tuned so the car is readable in the dark gaps
  between lamps — the player must never lose the car.
- Lighting technology: use Future if it holds frame rate on mobile, otherwise
  Voxel. Test both, report the frame cost, and put the choice in config.
- No fog so thick it hides the road edge. Readability beats mood.

## Performance — the hard constraint

Target: 60fps on a mid-range Android with 30 cars on screen. This governs
every decision above.

- Whole visible scene under 20,000 triangles at any viewpoint.
- **Hard cap on live Light instances: 12.** Roblox degrades badly past a
  small number of dynamic lights. Implement a manager that enables lights on
  the nearest lamps to the local player's camera and disables the rest,
  updated on a throttled interval (config, default 0.25s), not every frame.
- StreamingEnabled on, with tuned StreamingTargetRadius and
  StreamingMinRadius. Cityscape and distant scatter must be outside the
  streaming radius or permanently replicated as low-detail — decide which and
  explain the choice.
- CastShadow false on everything except what genuinely needs it. Probably
  nothing needs it at night on a highway.
- Merge static geometry where possible: long barrier runs, road segments,
  repeated markings. Fewer parts beats fewer triangles on Roblox.
- Every scenery part: Anchored true, CanTouch false, CanQuery false unless
  needed, CanCollide false unless it's a barrier.

## What to avoid

- **No per-frame loops over scenery.** The light manager runs on a throttled
  interval. Nothing else in the world system runs on Heartbeat or
  RenderStepped at all. If you think something needs a loop, tell me why
  first.
- **No while-true loops without a wait and an exit condition.**
- **No rebuilding the world at runtime.** Built once at server start, then
  static. If I change config I restart the server.
- **No unions or CSG.** They cost more than they save and break streaming.
- **No hand-placement.** If it's in the world, code put it there from config.
- **No collidable scenery except barriers.** A car should never be stopped by
  a lamp post, a sign, a palm or a rock.
- **No Terrain objects.** Parts only — cheaper and more predictable.
- **No decals or textures on large surfaces** without checking the frame cost
  first. Report before adding any.
- **No particle emitters, no post-processing effects** beyond Atmosphere in
  this pass. If you want bloom, ask me first and show me the frame cost.
- **Don't touch the vehicle code.** If the environment needs something from
  the car, expose it through a module boundary and tell me.
- **Don't invent Roblox APIs.** Check create.roblox.com/docs when unsure. No
  deprecated instances.

## Deliverables

1. All modules above, strict Luau, commented where a choice is non-obvious.
2. `WorldConfig.luau` with every tunable, real units, grouped by system.
3. `WORLD.md`: what each module builds, the placement rules, and the
   performance decisions with the numbers behind them.
4. Additions to TUNING.md: each world config field, what it does, and which
   direction to move it for a given effect.
5. A triangle count and part count report for the built scene, plus the
   frame rate you measured in Studio with the car driving.
6. The list of mesh candidates for my approval, with their stats.

## Order of work

Road network → barriers → ground and sky → lighting with the light manager →
cityscape → signage → scatter → performance pass → docs.

After each step: tell me what to look at in Studio and what the part and
triangle count is so far. Stop and ask before doing anything not listed here.
