# Behaviours: Roblox development on this project

Lessons from building Hajwala. Each one cost real time at least once. The notes are grouped into:
1. What the engine actually does.
2. How work gets done here.
3. What the owner wants.
4. Mistakes made and how they were corrected.

Add to it whenever something surprises you; correct it when a note turns out wrong.

Units: world code works in metres and converts with `ctx.s(m)` (studs = metres / 0.28).

---

## 1. Engine facts and traps

### Parts and geometry
- **A part axis caps at 2,048 studs (573 m).** Anything larger silently shrinks: ground tiles, haze panels and fence walls all have to be split.
- **Plain Parts are invisible to `Stats.SceneTriangleCount`.** 100 boxes added 0. Count box and wedge geometry by hand (12 or 8 triangles each), plus 2 per SurfaceGui frame or glyph.
- **A colliding part with `CanQuery = false` did not stop the car.** Keep any colliding scenery queryable; the car's suspension raycasts are how it finds anything.
- **Coplanar faces z-fight.** Never leave two tops at the same height where parts overlap (lawn against kerb, marking against road); lift one by a marking epsilon.
- **Shapes:**
  - A `WedgePart`'s tall face is at its +Z end.
  - A Ball part with non-uniform size still renders as a sphere; a Part with a sphere `SpecialMesh` renders as an ellipsoid.
  - A big Cylinder part is visibly faceted.
- **Materials:**
  - `Metal` in a light colour renders as chrome. Use `SmoothPlastic` for painted steel.
  - `Sandstone` renders pink unless the colour is kept dark (about 150/112/78 for mud brick).
- **Script `Source` is capped at 200,000 characters.** Split generated data into chunk modules.

### Terrain
- **Terrain renders a surface half a voxel above its occupancy.** Filling a 4-stud-voxel column to height t draws its top at t + 2 studs, exactly. Fill to `surface - VOXEL / 2`; otherwise every landform stands 0.56 m proud with a ledge where it meets a part plane.
- **Voxels written by `WriteVoxels` are not raycastable straight away**, and big writes take longer. Anything that snaps to the terrain (fence posts, props) must wait until a probe over a known dune reads as sand (see `Fence.luau`). A single `task.wait()` is not enough.
- **Terrain streams to clients only within about 573 m** (StreamingTargetRadius 2,048 studs). Streaming radius is a place setting that scripts can neither read nor write. Terrain further out does not exist for the player until they drive toward it.
- **Gentle terrain slopes show faint voxel-layer shading rings** from above. Accept it, or keep slopes varied.
- **Cost:**
  - The height function per column is what dominates build time. Evaluate on a coarse grid (two voxels) and interpolate; skip chunks with nothing in them; walk to the nearest road point from the previous column instead of scanning the whole path.
  - Keep the solid shell thin (2 m); nothing digs.
  - Always print the build time.

### Lighting, sky and post effects
- **`Lighting.Technology` cannot be set from a script.** It is a place setting in the Studio Properties panel.
- **Sun azimuth is `GeographicLatitude`.** Roblox has no azimuth control; latitude 60 swings the evening sun ahead-left of the highway.
- **An untextured `Sky` object renders Roblox's default day skybox, not the procedural dome.** No Sky object at all gives the procedural dome.
- **Atmosphere haze swallows building bodies long before emissive parts.** Neon survives distance, so a lit skyline needs dark bodies and Neon lights, or the lights float free of their buildings.
- **Bloom** (`BloomEffect`) catches Neon, SurfaceGuis with `Brightness > 1`, and the sun. A low threshold blows the sun out into a white ball; about 1.1 to 1.2 at golden hour is safe.

### Materials and textures
- **A MaterialVariant's colour map is multiplied by the part's Color.** A dark map cannot be lightened by tint, so keep tints near white and let the map carry the tone. At lower graphics quality the map detail drops, and a near-white tint can read bright.
- **Creating MaterialVariant maps needs plugin capability.** A server script that tries it errors and can kill the world build. Declare variants in the place (`default.project.json` MaterialService); `MaterialService:SetBaseMaterialOverride` does work from the server.
- **A MaterialVariant roughness map can read glossy.** Leaving it out made the sand matte. A road without one can still show sheen toward a low sun.

### GUIs in the world
- **SurfaceGui renders at 9,000+ studs** with `MaxDistance = 0` (no limit). `LightInfluence = 0` plus a UIGradient makes a smooth, edgeless, unlit haze or glow layer with no texture upload.
- **A UIGradient on a CanvasGroup inside a SurfaceGui did not fade.** For a two-axis fade, use strips of frames with stepped `BackgroundTransparency`, each carrying the vertical gradient.
- **SurfaceGui text shows only from the second frame after the camera moves.** Capture twice before calling a sign blank.

### Meshes and assets
- **EditableMesh is locked** unless the experience enables "Allow Mesh / Image APIs", which needs an ID-verified owner.
  - `AssetService:CreateAssetAsync` is not available to us.
  - `PublishService:PublishDescendantAssets` needs the RobloxScript capability.
  - Generated meshes need a manual 3D Importer upload instead.
- **`AssetService:CreateMeshPartAsync`** yields and hits the network. Load each id once, then Clone; preload before scatter loops.
- **Store vetting:**
  - Most free "mesh building" and "highway sign" models are hundreds of plain parts plus scripts.
  - Decal ids are not image ids; get the image id with `InsertService:LoadAsset(decalId)` in Studio.
  - `LoadAsset` refuses free models in Edit; use the MCP `insert_asset` tool.
  - Look at every face of a mesh: a pack passed a front check and still had Cyrillic shop signs on its long faces.
  - No real brands, badges or logos anywhere: the sedan is the "Kamri".

---

## 2. Working in Studio through the MCP

### The sync cycle
1. `python3 scripts/mcp_sync.py --manifest` writes `build/manifest.json`, with `python3 -m http.server 8765 --bind 127.0.0.1` running in the repo root.
2. Run the loader (`scripts/studio_loader.luau`) through `execute_luau` in the Edit datamodel. It creates or updates script Sources but never deletes, so remove stale modules by hand.
3. **Server or world code needs a Play restart.** Stop Play, sync in Edit, start Play.
4. **Config-only changes can go live** with the loader in the Server datamodel during Play, then set `OvReload = true` from the Client datamodel. Prove the reload with an observable change; the console line only shows once.

### Previews and screenshots
- **`screen_capture` renders only in Edit.** To preview the world:
  1. Clone `ServerScriptService.Server.World` into ServerStorage as `WorldPreview`.
  2. Call `require(clone).build()`.
  3. Capture.
  4. Destroy workspace `World`, `Road`, `RoadDetail` and `City`, run `Terrain:Clear()`, and remove the clone.
- **Move the real editor camera first.** A capture far from `workspace.CurrentCamera` draws terrain at coarse level of detail; low props looked buried in blobs that were not there. Set `CurrentCamera.CFrame` and `.Focus` to the spot in a loop for about 5 s, then capture with the same camera.
- **Take captures one at a time**; parallel calls time out.
- **Clear `Selection` first**, or a white selection box appears in the shot.
- **An identical camera can return a stale frame.** Nudge the position when checking a change.
- **Focus Studio before anything timed:** `osascript -e 'tell application "RobloxStudio" to activate'`. Unfocused Studio runs at about 15 fps: builds run 2 to 4 times slower, and physics measurements come out pessimistic.

### Harness and chunk traps
- **`execute_luau` chunks longer than about 120 s get backgrounded.** Keep each under about 100 s and collect backgrounded results with TaskOutput.
- **Module caching:** the Edit datamodel caches `require` of shared modules for the whole session, so require a `:Clone()` in harness chunks. A cloned module outside its hierarchy cannot require its siblings; rebuild through the World clone instead.
- **Driving harness:**
  - Set `InputOverride = true` on the LocalPlayer, then drive with `OvThrottle`, `OvSteer` and `OvBrake` (numbers).
  - `OvHandbrake` and `OvLean*` must be the boolean `true`.
  - Spawn with `Remotes.SpawnCar:FireServer(id)`; the car is `Humanoid.SeatPart.Parent.Parent`.
  - The client owns its car, so reset it from the Client datamodel with `PivotTo` and zeroed velocities.
- **After teleporting the car far out, wait a few seconds** for terrain to stream in before driving.
- **Before taking the car, check `DriverSeat.Occupant`** and whether the car has moved; the owner often leaves Play running to test by hand.
- **Specs:** `require(ReplicatedStorage.Shared:Clone().Tests)()`. `bash scripts/analyze.sh` runs strict luau-lsp. World/init.luau and Station.luau carry baseline errors; only new errors in touched files matter.

### Measuring instead of guessing
- **Terrain:** measure with raycasts on a grid (`Include` Terrain), reporting nearest and farthest visible points, cover per distance band, steepest slope, and the height of the first visible sample (flushness).
- **Collision:** drive into the thing at full throttle with the harness and report furthest point, top speed and minimum upright.
- **Build time and cost:** read from the `[World]` report lines (parts, triangles, seconds).
- **Before redesigning something that "does not render"**, prove it:
  - Raycast from the camera to the object (occlusion?).
  - Put a bright marker in open ground at the same distance (distance culling?).
  - Nudge the camera (stale frame?).

  The SurfaceGui glow dome only looked missing because it stood behind the towers.

### Git
- **Stage specific files only.** The working tree carries uncommitted car-rig changes that are not ours: RIG_SPEC.md, RigBuilder, CarCatalog, VehicleRig, its spec and tools/carbody. Never commit them without the owner saying so.
- **End commit messages** with the Co-Authored-By and Claude-Session trailers.
- **Update WORLD.md or TUNING.md in the same commit as the change**, with the measured numbers.

---

## 3. What the owner wants

### Working style
- **Measure, then report numbers.** Every driving or world change gets before and after figures from Studio, not "should feel better". Lead with a table.
- **No scripted drivers.** Use the input-override harness.
- **Never tune to satisfy a test.** A criterion missed honestly beats one met by a hack.
- **Leave feel judgements to them.** Name the knob for each.
- **Show screenshots** for visual work, from the driver's view where it matters.
- **Remove features completely when asked** ("remove this ability completely" means revert, not disable).
- **Subtle means subtle.** "Very slightly more night" was a 1-degree sun change and a small exposure drop; "slightly darker road" was a 12% tint.
- **They stop mid-task and redirect often.** Keep each step committed and working so a redirect never leaves the world broken.

### Taste in the world
- **Calm, natural randomness, never lines.**
  - Dunes went from one ridge, to a chain of mounds, to a scattered field, to rolling waves out to the fence, each time because the previous one "read as a line".
  - Nothing may start with a visible edge or ledge; no small bumps.
- **Generous distances.** Every border gap was increased at least once ("way way too small"). When unsure, go bigger.
- **Sparse props.** Scenes are a few of each, spaced 150 m apart, never crowded.
- **Middle Eastern flavour without cliché overload:** camps, majlis, dallah, areesh, wells, mud-brick ruins, camels, tyre stacks, drift wrecks.
- **The skyline needs aura.** Haze in front, glow behind, lights that pop against dark bodies; not "just blocks".
- **No real brands**, anywhere.

### Driving feel targets (Sep 2026)
- **Tricks:** 360s easy, chained tricks keep speed, 720s may stay hard.
- **Grip and launch:** nothing feels like ice, and launch is quick "off rip".
- **Natl:** "first tap gets it up, later taps keep it".
- **Steering lock** stays 38 degrees unless argued for.

---

## 4. Mistakes made, and the correction

| What went wrong | Correction |
|---|---|
| Fence posts were placed on the flat plane, buried in the dunes, because the terrain was not raycastable yet. | Wait on a probe over a known dune before snapping anything to terrain. |
| The doubled dune field took 40 s to build and was only noticed when measured. | Print build times every pass; grid-interpolate heights; thin the shell. Now about 10 s. |
| Close-up screenshots showed props buried in terrain that physics said was flat. | Coarse terrain LOD far from the editor camera; move the real camera first. |
| The glow dome was judged "not rendering" and alternatives (Beams, slabs) were tried. | It was occluded by towers and too transparent where visible. Prove culling with an open-ground marker first. |
| Two identical capture calls returned the same frame, hiding a scene change. | Nudge the camera for every verification capture. |
| Dune edges showed a ledge through several redesigns. | The cause was the half-voxel render offset, found by measuring written against rendered heights on a test patch. Measure the engine before redesigning shapes. |
| A regex-style multi-edit failed half-way on an indentation mismatch. | Assert every replacement matched before writing; re-read the exact whitespace (`sed -n l`) on failure. |
| Band-end fades used a CanvasGroup UIGradient that did nothing. | Strips with stepped transparency. |
| A "shift boost" feature was built, tuned for rocket-like thrust, then removed entirely at the owner's request. | Confirm the intended feel (the owner's words: "not super acceleration like rockets") before tuning, and keep features easy to revert. |
| Dunes were made so flush and low they vanished from the road. | Check the driver's view, not only an aerial, when making things "calm". |
