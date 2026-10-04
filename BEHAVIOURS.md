# Rules of thumb for Roblox game development

These are general lessons, drawn from building a driving game with a large procedural world (highway, terrain dunes, props, a city and a distant skyline). They are written to apply to any Roblox project.

Add to them whenever the engine surprises you, and correct them when one turns out wrong.

---

## 1. Before building anything

- **Check that the API exists and is current.** Never invent a method; look it up.
  - Avoid deprecated movers (BodyVelocity, BodyGyro, BodyPosition). Use constraints and forces instead: VectorForce, AlignOrientation, LinearVelocity.
- **Check the platform gates before committing to a technique.** Several things look scriptable and are not:
  - `Lighting.Technology` and the streaming radii are place settings; scripts can neither read nor write them.
  - EditableMesh and EditableImage need the experience's "Allow Mesh / Image APIs" setting, which needs an ID-verified owner.
  - **A client holds at most 8 EditableMeshes, whatever their size.** In a Studio Play client (2026-09-28) exactly 8 more could be made at boot, with 1 vertex or 3,000 each; the 9th returns nil ("Failed to create empty EditableMesh ... memory budget limits"), and the developer forum reports the same 8. The generated car pieces (kamri 5, krownvik 4, lekzas, batrol and fleet 1 each) and the garage's exhaust tips draw on the same 8. Share templates across cars, count them per feature, free them when unused, and give every EditableMesh feature a fallback. To see how many are left, make empty ones until nil and destroy them at once (as the local `freeMeshSlots` in CarCosmetics does).
  - **An EditableMesh must outlive every MeshPart made from it.** Tested in Edit and in a Play client (2026-09-28): a MeshPart from `CreateMeshPartAsync(Content.fromObject(em))` goes blank when `em` is destroyed, whether it was parented before the destroy, is a clone made after it, or is a clone made while `em` was alive; its `MeshContent` still names the EditableMesh object. Destroying does free the slot (8 free, then 7 with one alive and four destroyed). So a template holds its slot for as long as anything shows it; the only way to free a slot and keep the look is an uploaded mesh (`Content.fromUri`).
  - **Uploading a mesh from a script isn't possible here.** `AssetService:CreateAssetAsync` answers "CreateAssetAsync and CreateAssetVersionAsync are not available yet", and `AssetImportService` isn't reachable from the Studio MCP (2026-09-29). Meshes go up through Studio's File → Import by hand; images can go up through the MCP's `upload_image` tool from an `http://localhost` URL (not `127.0.0.1`, not a file path).
  - **Studio's 3D importer turns an OBJ half round about Y and drops its vertex colours** (2026-09-29, the exhaust tips). Sizes come through exactly. Carry colours as texture coordinates into an uploaded image instead (tools/cosmetics/README.md).
  - `AssetService:CreateAssetAsync` and `PublishService` need capabilities a normal game does not have.
  - MaterialVariant texture maps can only be set with plugin security. Declare variants in the place file, not from a server script.

  If a technique depends on one of these, prove it with a quick spike first.
- **Pin down the feel in the owner's words before tuning.** "A boost like drifters' exhaust pops, not rockets" is a spec. Tuning first and asking later wastes passes and sometimes the whole feature.
- **Translate magnitude words literally.** "Slightly" and "very slightly" mean single-digit percentages or a degree or two. "Way way too small" means double it or more.

---

## 2. Architecture and code

- **Use strict Luau with real tooling:** `--!strict` everywhere, Rojo for sync, luau-lsp for analysis. Know which errors are pre-existing baseline so new ones stand out.
- **Put every tunable in a config module**, never inline. Next to each number, comment why it has that value and what it used to be. The history is what stops the next person reverting a fix.
- **Make config reloadable at runtime** (a key or an attribute), so tuning does not need a rejoin. Always prove a reload happened with a visible change.
- **Split authority clearly:**
  - The server owns spawning and anything competitive.
  - The client owns input, and the physics of the assembly it has network ownership of (its own car).
- **Local changes do not replicate.** A Weld C0 set on one client, an EditableMesh, or a SurfaceAppearance built at runtime exists only for that client. Anything visual that must match for everyone either comes from the server or is rebuilt by every client from replicated state (for example, run the suspension maths on each client for other players' wheels).
- **Seats and characters have race conditions.** When swapping a player between seats:
  1. Wait for the old seat to clear.
  2. Sit them.
  3. Confirm `Occupant`.
  4. Retry a few times.
- **Seed all procedural content.** With `Random.new(seed)`, every server builds the same world and a bug can be reproduced.
- **Give every system one shared lookup.** When terrain, props, fences and collision all need "where is the border", compute it once and have each system read it, so they can never disagree.
- **Keep features easy to remove.** When someone says "remove it completely", revert it; do not leave a disabled flag behind.
- **Script `Source` caps at 200,000 characters.** Split generated data into several modules.
- **Never key a weak table by Instance.** An Instance whose only Lua reference is a weak key can lose its entry while the Instance still exists (the garage's night glow silently never applied, 2026-09-28). Use a strong table and drop entries on `Destroying`.
- **Find the PlayerModule without waiting, and never require a second copy.** The documented route is `require(LocalPlayer.PlayerScripts.PlayerModule):GetControls()`. In one Studio session (2026-09-28) PlayerScripts held no PlayerModule at all (a copy sat under `StarterPlayer`), so `WaitForChild` there yielded forever. Requiring the StarterPlayer copy's ControlModule gives a separate instance whose `Enable` can build a second set of controls. Use `FindFirstChild`, and to drop a character's control also anchor its root on the client.

---

## 3. Physics and vehicles

- **Test driving with an input-override harness,** so real player input code is exercised. Never test with a scripted driver that bypasses it.
- **Never tune to pass a test.** A criterion missed honestly is better than one met by a hack. Fix the mechanism.
- **A new force must work with the systems already there.** A boost that ignores the drift-assist or grip model will fight it: the car snaps back, or energy appears from nowhere. Route it through the same model.
- **A part the car can hit must be queryable** (`CanQuery = true`). Raycast-based vehicles do not see non-queryable parts, and a colliding but non-queryable part may not stop anything.
- **Make invisible walls tall** (100+ m) and reach them slightly below the ground. Test them at full speed from several angles.
- **Report results as numbers:** top speed, furthest point reached, minimum upright value, time to catch a slide. "Feels better" is not a measurement.

---

## 4. Building the world

### Scale and streaming
- **A part axis caps at 2,048 studs (about 573 m).** Anything larger silently shrinks, so tile big surfaces.
- **Streaming decides what the player has.** With StreamingEnabled, parts and terrain only reach the client within the target radius (2,048 studs by default).
  - Make distant backdrops (skyline, horizon) `Persistent` models so they never pop.
  - Remember that terrain far from the player does not exist for them yet.
- **Wait for streaming after teleports** before anything depends on the ground there.

### Terrain
- **Terrain renders half a voxel above what occupancy implies.** Filling to height t draws the top at t + half a voxel. Write to `surface - voxel / 2`, or landforms stand proud with a ledge where they meet other geometry.
- **New terrain is not raycastable immediately**, and big writes take longer. Anything that snaps to it (fence posts, props) must wait until a probe over a known spot returns the new surface.
- **Terrain is the right tool near the player and the wrong one far away.** It streams by radius; distant landforms are better as meshes or parts.
- **Keep terrain generation cheap:**
  - Evaluate the height function on a coarse grid (every 2 voxels) and interpolate per column.
  - Skip chunks with nothing to write.
  - Keep the solid shell thin; nobody digs.
  - Print the build time every run; a slow world build is a slow server start.
- **Gentle slopes show faint shading rings** at voxel layer boundaries. Varied slopes hide them.

### Making things look natural
- **Randomness must not read as a line.**
  - Vary size, rotation and spacing, and cluster things with gaps between.
  - Use slow noise for density (thick and thin stretches) as well as for position.
  - Scatter over areas, not along a curve.
- **Nothing should start with a visible edge.** Landforms leave the ground at a grazing angle. A profile like (1 - r²)³ has both slope and curvature at zero at the rim. Sink the base slightly under the ground plane.
- **Calm beats busy.** Small bumps and noise on every surface look like errors. A few broad shapes plus one gentle wave layer read as dunes.
- **Be generous with distances.** Gaps between the road, features and borders that look fine in an aerial view feel cramped at driving speed.
- **Keep props sparse and purposeful.** A handful of distinct scenes (a camp, a ruin, a wreck), each on a flat spot, well spaced and off slopes, beat many repeated props.
- **Check the player's eye view, not only an aerial.** Something made calm enough can vanish entirely from the road.

### Parts and materials
- **Coplanar faces z-fight.** Never leave two top faces at the same height where parts overlap; lift one a hair.
- **Some materials render unexpectedly:**
  - `Metal` in a light colour looks like chrome; painted steel is `SmoothPlastic`.
  - `Sandstone` goes pink unless kept dark.
  - `Neon` glows and survives haze; use it for lights, not surfaces.
- **A MaterialVariant's colour map is multiplied by the part colour.** A dark map cannot be lightened, so keep the tint near white and let the map carry the tone. At low graphics quality the map detail drops, so check how the tint alone reads.
- **Leaving out a roughness map can mean sheen.** Low sun and bloom turn that sheen into glare. Check surfaces facing the sun.
- **Vertex colours on an EditableMesh render, multiplied by the part's Color.** Measured 2026-09-28: `AddColor` / `SetFaceColors` show on the MeshPart from `CreateMeshPartAsync`, on SmoothPlastic, Metal and Foil, and survive `Clone` and resizing. The garage's titanium tips carry their heat colours this way on a near-white part.
- **Metal and Foil mirror the world whatever the colour.** A tip's bore painted near-black by vertex colour on a Foil shell still showed the bumper and the car's own pipes reflected in it (2026-09-28). A surface that must read dark needs a matte material: the tips' bores are their own SmoothPlastic parts.
- **Shapes:**
  - A cylinder `SpecialMesh` does not stretch to an oval; a sphere `SpecialMesh` does. A flat dark oval disc (the Big Oval tip's bore) is a Part with a sphere SpecialMesh a centimetre deep (2026-09-28).
  - Big Cylinder parts are visibly faceted.
  - A Ball part never stretches (use a sphere SpecialMesh for ellipsoids).
  - A WedgePart's tall face is at +Z. A SurfaceGui on its sloped face is `Face = Front`, not Top.
- **A SurfaceGui behind Glass-material glass does not draw.** The garage's sun strip slats (opaque SmoothPlastic cards with a SurfaceGui each) sat 6 mm behind the Batrol's windscreen (Glass material, Transparency 0.7): the cards' own colour showed through, their text and gradient did not; with the glass hidden the same guis drew (2026-09-28). Behind SmoothPlastic glass (Lekzas 0.8, Kruzer 80 0.65) they draw. On Glass-material glass put the card outside it.
- **A Front-face SurfaceGui's canvas starts at the part's +X side.** Seen from in front of the face, the viewer's left is the part's +X, and that is where the canvas's left edge (x = 0) is drawn. A strip split across several parts, each showing a slice of one canvas, must count its slices from the +X end, or the text comes out in reverse order ("A NAUAJ H" for HAJWALA, the garage's sun strip slats, 2026-09-28).
- **Rounded frames on a fully transparent part do not render.** A Frame with a UICorner in a SurfaceGui on a `Transparency = 1` part is invisible, although square frames and text on the same kind of sheet show (the station's forecourt paint, the garage apron). The garage's hose coil failed this way. Put rounded paint on an opaque part instead: the coil became a thin cylinder with its discs on the end face.
- **Nothing on a fully transparent part draws behind glass.** A SurfaceGui on a `Transparency = 1` card sitting just behind a car's windscreen (itself transparent) vanished; the same card made opaque showed through the glass. Behind opaque glass (a black glass mesh, or glass painted into a textured shell) nothing behind shows at all, so the garage's sun strip sits outside those like a sticker (`CarCosmeticMounts`).

### Distant backdrops and atmosphere
- **Atmosphere haze swallows solid bodies long before emissive parts.** A distant city needs dark bodies with Neon lights. In daylight, dim the lights too, or they float free of their buildings.
- **Give backdrops aura with layers:** unlit gradient haze in front, dense at the ground and clear at the top, and a bright glow behind.
  - A SurfaceGui with `LightInfluence = 0`, `MaxDistance = 0` and a UIGradient gives an edgeless gradient without uploading a texture.
  - It renders at 9,000+ studs, and `Brightness > 1` makes it bloom.
- **Fade the ends of any layered effect.** Hard vertical edges give it away. A UIGradient on a CanvasGroup inside a SurfaceGui did not fade; strips of frames with stepped transparency do.
- **Bloom:** a low threshold blows out the sun and bright sand. Tune it with the sun in frame.

### Lighting and sky
- **Sun direction is set by `GeographicLatitude`** together with ClockTime. There is no azimuth property, so use latitude to put a sunset in the player's windscreen.
- **An untextured Sky object renders the default day skybox.** Use no Sky object for the procedural dome, or a real six-texture skybox for a painted sunset.
- **Lights are expensive.** Pool a handful of real lights and move them to the nearest lamps; let Neon lenses stand in for the rest.
- **Make lighting changes small**, and compare the same camera view before and after.

### Particles
- **A turned particle drawn along its motion splays into a starburst.** With `Orientation = VelocityParallel`, any `Rotation` spins the stretched particle off its line of travel: a flame of stretched particles became radiating rays (exhaust flames, 2026-09-28). Keep Rotation 0 on VelocityParallel layers; turn only camera-facing ones (smoke).
- **Colour past 1 goes white.** `Brightness` above 1, or LightEmission stacking several particles, clips a coloured particle toward white, and bloom finishes the job: a blue exhaust core at Brightness 1.6 read as white, and at Brightness 1 with little LightEmission it stayed blue. Keep a colour you need to see at Brightness 1 and pick a saturated value (#3A6BFF read blue where #A9CCFF read white).
- **A burst emitted in one frame is a clump, not a flame.** All particles leave together and the flame detaches from the pipe. Letting them out a few a frame over ~0.08 s (still `Emit`, never a running emitter) gives a continuous tongue with particles of every age along it.
- **A flame pointing at the camera foreshortens to a dot.** From a chase cam straight behind, an exhaust flame shows only as a blob; a short camera-facing glow at the mouth carries the pop from that angle.

---

- **ParticleEmitter sizes and speeds are studs, not metres.** The old tyre smoke passed its "1.6 m" straight to `Size`, which drew a 0.45 m puff (found 2026-10-04). Divide by metresPerStud.
- **Big particles slice into the ground.** A particle is a flat card facing the camera; a large one low over the road cuts into the asphalt and lane paint in a hard straight line. `ZOffset` (studs toward the camera) clears it: 0.84 m for tyre smoke seen from the chase camera. Start puffs small and grow them as they rise.
- **Smoke reads grey at golden hour.** The scene's light greys it; white smoke wants low `LightInfluence` (0.25), a little `LightEmission` (0.12) and `Brightness` 1.5, checked at sunset and night (2026-10-04).
- **The built-in smoke texture can never be thick.** `rbxasset://textures/particles/smoke_main.dds` is a 128 px grey blob whose alpha never passes 85/255, so however it is tinted it reads as a soft grey ball. Roblox's own realistic smoke (rbxassetid://16830673704, from their volcano VFX tutorial) is wispy, turbulent and near white with a nearly opaque core; the tyre smoke uses it (2026-10-04). Built-in textures can be inspected: they sit in `RobloxStudio.app/Contents/Resources/content/textures/particles/` and Pillow reads the .dds.
- **A particle's cost is the screen area it covers, not the count.** Tyre smoke at 30 / 12 / 2.5 puffs a second per layer growing to 1.8 / 5 / 8.5 m took the median frame from 16.6 to 38.4 ms with four tyres at full round a parked car; cutting to 20 / 8 / 0.8 growing to 1.6 / 4 / 5.5 m brought it back to 16.3 (2026-10-04). Big long-lived layers (a lingering haze) are the expensive ones; time the worst case (all emitters at full round the camera) before settling.
- **`Drag` halves a particle's speed `Drag` times a second.** So it pulls toward still air at k = Drag ln 2, and a constant `Acceleration` of k times a velocity settles the particle at that velocity: a climb, or a breeze, without touching `workspace.GlobalWind` (which also moves the sky's clouds). `WindAffectsDrag` only matters when GlobalWind is set (it is 0 here).
- **Flatten big low puffs with negative `Squash`.** Below 0 a card is wider than tall, so less of it reaches under the road: billow puffs at -0.4 softened the hard line where smoke met the asphalt, and the cloud reads as spreading along the ground (2026-10-04).
- **An emitter on an Attachment throws along the attachment's axes.** Turning the attachment every step (`EmissionDirection = Front` is its LookVector) aims each new particle, and particles already out keep their course. The tyre smoke turns its attachment to the tread's slide every step. `Speed` set each step works the same way.
- **A capsized car's wheels hang at full droop.** Anything that sets it back upright on those hanging tyres lands it on unloaded springs and it drops (0.18 m at 1.6 m/s, measured). Put the tyres where they sit at rest and land the body at its rest height (client AutoFlip).

## 5. Assets from the Creator Store

- **Most free models are not what their title says.** "Mesh building", "highway sign" and "camel" often turn out to be hundreds of plain parts, bundled scripts, or the wrong object. Count MeshParts, parts and scripts before using one.
- **Look at every face.** A model can pass a front check and carry foreign text or branding on its sides.
- **No real brands, badges or logos.** Rename lookalikes.
- **Decal ids are not image ids.** Resolve the image id inside Studio before using it in a Texture. `InsertService:LoadAsset(decalId)` from `execute_luau` works and gives a Decal whose Texture is the image; the MCP `insert_asset` tool's Decal only carries the decal id back.
- **Roblox's own tutorial assets are the safest textures.** Their docs' VFX tutorials list image ids (the volcano tutorial's smoke, 16830673704) from Roblox itself: realistic, and not going to be moderated away. Still load them with a fallback (`ContentProvider:PreloadAsync` with a status callback).
- **Load each mesh once, then clone.** `CreateMeshPartAsync` yields and hits the network; preload everything before a placement loop.
- **Record provenance next to the asset id:** creator, store id, what was checked, what was rejected and why.

---

## 6. Performance

- **Print cost on every build:** parts, estimated triangles, and seconds per system. Regressions are then noticed immediately, not after they ship.
- **`Stats.SceneTriangleCount` ignores plain Parts.** Estimate parts by hand (a box is 12 triangles).
- **Merge repeated geometry.** One long panel per straight run instead of one per bay; merge wherever the shape stays within a tolerance.
- **Skip empty work before optimising busy work.** Culling chunks with nothing in them is usually the biggest win.
- **A follow camera smooths by simulated time, not render time.** Physics moves a part by whole steps (a fixed quantum, usually one per frame) while RenderStepped's dt jitters by several milliseconds. Exponential smoothing on render dt makes the camera lag and lurch against a steadily moving car, and the whole world judders. Accumulate PreSimulation dt and smooth by that; a frame with no physics step moves the camera nothing.
- **Measure frame rate with the Studio window focused.** Unfocused Studio throttles to about 15 fps and makes everything look slower.
- **On phones, count see-through surface before triangles.** A few hundred draw calls and a few hundred thousand triangles are fine; thousands of semi-transparent parts are not, because each is sorted and drawn alone and phone GPUs are fill-rate bound. Never use Transparency for a cosmetic fade: mix the fade into the colour.
- **Shadow stats read 0 in Edit.** `Stats.ShadowsDrawcallCount` and `ShadowsTriangleCount` only report in Play.
- **A world built at server start is a join delay.** A solo tester starts a new server with every join. Create the Remotes and boot the client UI before the build, publish a ready flag after it, and cover the screen in between. Anything that reads what the build leaves behind waits for the flag.
- **Persistent is for small, essential things.** Persistent models go to every client at join and never unload. Keep them to a few hundred instances: the driving surface, a low-detail silhouette of a distant landmark. Stream the detail.

---

## 7. Testing and verification

- **Measure, don't eyeball:**
  - Raycast grids for terrain: nearest and farthest points, cover per distance band, steepest slope, height at the edge.
  - Drive-into-it tests for collision.
  - Build logs for cost.
- **Report before and after in a table.**
- **Diagnose "it doesn't render" before redesigning.** Work through the cheap checks in order:
  1. **Occlusion:** raycast from the camera to the object.
  2. **Distance culling:** place a bright marker in open ground at the same distance.
  3. **Stale frame:** nudge the camera and capture again.
  4. **Level of detail:** terrain and meshes render coarsely far from the editor's real camera.
  5. **Loading:** meshes, textures and SurfaceGui text can take a frame or more.
- **When a shape looks wrong, measure the engine on a test patch first.** Write known values and read back what renders, before redesigning the shape.
- **Remember the player's graphics quality.** Screenshots at maximum quality can differ from a player on Automatic.
- **Run the type checker and the spec suite after every change.** Keep known failures listed so new ones stand out.

---

## 8. Driving Studio from tools (MCP, command bar, scripts)

- **Server code needs a Play restart.** Config can often be hot-reloaded; world or server modules cannot.
- **Edit mode caches `require` for the whole session.** Require a `:Clone()` of a module to see fresh code. A cloned module outside its original hierarchy cannot require its siblings.
  - A clone only helps for its own code: a module that finds its siblings by path (`ReplicatedStorage:WaitForChild("Shared")`) still gets the stale cached siblings. To load a client module against fresh shared code in Edit, clone `Shared`, rename the original aside, parent the clone as `Shared`, require, then rename back, all in one `execute_luau` call (2026-09-28, exhaust standard).
- **Keep scripted chunks short** (under about 100 s); long ones get backgrounded or time out.
- **Raycasts on a store car's own parts do not measure it; measure it by eye with a near-orthographic camera, or raycast precise-collision copies (below).** Raycasts hit a MeshPart's collision hull (Box on the store cars), a script cannot change `CollisionFidelity`, and `AssetService:CreateEditableMeshAsync` is refused for store meshes ("no permission"). `screen_capture` keeps `workspace.CurrentCamera.FieldOfView`: at FieldOfView 3 with the camera 30 m out, a capture is close to orthographic (about 700 px per metre on the 1285 x 1080 capture), so a point reads straight off the pixels. Calibrate each view with small neon balls at known car-space points, hide the other body pieces to see a pipe inside the body, and set FieldOfView back to 70 afterwards. A camera looking straight up has no defined roll; offset it a little along the car (2026-09-28, exhaust standard).
  - A script *can* measure one another way: `AssetService:CreateMeshPartAsync(Content.fromUri(part.MeshId), { CollisionFidelity = Enum.CollisionFidelity.PreciseConvexDecomposition })` works on the store cars' meshes in Edit. Give the copy the piece's Size and CFrame, anchor it, CanQuery on, Transparency 1, and raycast against the copies only (an Include filter), one piece at a time to get each piece's bottom (ray up) and top (ray down) in a column. Convex decomposition fills concave shells, so a hull reads lower than a thin floor panel really is: check the numbers by eye from under the car. Used for every car's exhaust `riseM` (garage round 3 task 2, 2026-09-28).
- **Screenshots:**
  - Capture only in Edit mode, one at a time; parallel captures time out.
  - Clear the Selection first.
  - Move the real editor camera to the spot and wait a few seconds so level of detail and streaming catch up.
- **Build previews in Edit from a clone of the world module, then clean up everything they created**, including terrain.
- **Before taking over a running Play session, check whether someone is using it.** Is the seat occupied? Has the car moved?
- **Sync tools often create and update but never delete.** Remove stale modules by hand.
- **`execute_luau` runs in its own VM.** Requiring a game module from it gives a fresh copy, not the running script's; editing a config table there changes nothing live. Change instances (lights, attributes) directly, or edit the file and restart Play.
  - That VM keeps its module cache across calls, so a copy of a client module required in one call reads the config table you edit in the next: a live tuning loop for the copy (the tyre smoke's layer rates, 2026-10-04).
  - Threads it spawns keep running after the call returns, so a harness drive can run in the background while you capture. A `screen_capture` can take 10 s or more, so hold the state to be captured (a sustained drift, a parked car) for longer than that.
- **Holding the brake from rest selects reverse.** A harness car "parked" with `OvBrake = 1` backs off at up to 60 km/h. Park it with `OvHandbrake = true` and the brake at 0.
- **Rojo 7.7 can crash on an editor's temporary file.** "Rojo crashed! ... Canonicalize ... CarConfig.luau.tmp.<n>" on 2026-10-04: a file written via a temporary and renamed. Restart `rojo serve`; the Studio plugin then needs Connect (and Accept) again, which only the owner can click. Until then a changed module can be brought into the Edit tree from `execute_luau` (`.Source` is writable there); compare its length with the file on disk.
- **Virtual input cannot press Escape or gamepad B** (bound to CoreGui actions); test those paths through the on-screen button that does the same thing.
- **A capture right after new lights appear can be dim and flat.** The renderer takes a few seconds to take new lights in; wait about 3 s before judging light.
- **Freeze a particle effect with a slow-motion timescale, not a wait.** The Edit viewport runs at about 16 fps even focused, so waiting 0.1 s then setting `TimeScale = 0` froze a 0.2 s flame at a different age every time (and sometimes after it died). Run the emitters at `TimeScale = 0.1` (and any scripted emission to match), wait ten times the age, then set 0: the freeze lands within a few ms (ExhaustFlames.timeScale, 2026-09-28).
  - In Play, a script that sets `TimeScale` on every emit (ExhaustFlames' `dress` does, per pop) undoes a one-off freeze at the next pop, and the frozen flame is gone by the capture. Re-apply `TimeScale = 0` every Heartbeat until the capture is taken, then disconnect and set it back to 1 (round-2 final pass, 2026-09-28).
- **Do not un-anchor a parked raycast car before its driver's sim runs.** Seating un-anchors the car and hands it to the driver's client, which starts VehicleSim only after DriveStart arrives (20 to 75 ms, more while the client is busy). Nothing holds the car up meanwhile: it falls 0.02 to 0.29 m, and the first suspension step on that compression threw it up at 4.6 m/s and onto its side (garage drive-out, 2 of 5 and 1 of 5 in two loops, 2026-09-28). Keep it anchored through the seat and let go once the client's controller runs (CarSpawner.seatOwner hold / letGo). The ordinary prompt and spawn seatings still un-anchor first.
- **Anchoring a driven car's chassis pauses its sim.** VehicleSim on an anchored chassis only produced "[VehicleSim] non-finite force, zeroing this step" every step (reproduced by anchoring for 1.5 s at rest, 2026-09-28), so VehicleController now skips the step while the chassis is anchored (the drive-out hold relies on it; exit still works). To hold a shot, freeze only the particles; an anchored car will not run its lamps' or audio's updates meanwhile.
- **`user_mouse_input` with an `instance_path` takes the first of two same-named siblings.** The garage panel has two `Grid` frames (paints, then tints), so `Items.Grid.Card_tint_dark` did not resolve. Aim by x/y instead: the coordinates are the viewport's (1097 x 683 here, not the 1734 x 1080 capture), and a ScreenGui with `IgnoreGuiInset = false` sits under the 58 px top bar, so the point is the GuiObject's `AbsolutePosition + AbsoluteSize / 2 + (0, 58)`. Mouse-wheel `scrollDown` with the pointer on a card inside the ScrollingFrame scrolls it.
- **Studio's mesh cache can decode to NaN bounds.** A few cached meshes (4 of 1,245 on 2026-09-28) decode with NaN extents; one NaN in a ranking scrambles a Python sort, so a mesh that matched exactly ranked below misses and looked uncached. Drop non-finite bounds before ranking (`rbxcache.find`, `strip_shapes.py`).
- **A test triangle settles winding.** An EditableMesh triangle is drawn from the side where its corners run counter-clockwise, and nothing from the back (Studio 2026-09-28). Blender previews draw both sides, so a mesh can look right there and still be inside out in the game; check the signed volume of a closed mesh in the generator.
- **A harness that builds bodies and looks in its own `execute_luau` VM spends the client's EditableMesh slots** (above) on top of the game's. Prefer store-mesh cars (kamri07, kruzer80, hatch) for such shots, and call `BodyBuilder.preload(entry)` before `mount`, or a store body comes out empty.
- **Low graphics quality stops drawing parts past a distance.** At Automatic quality in a Studio running at ~14 fps, plain parts past about 80-85 m were not drawn at all (the garage from the spawn bay, 100 m, 2026-09-28), while the mesh lamp posts further out still showed (far palms and scatter vanished too). `settings().Rendering.QualityLevel` can be set from `execute_luau` to check a view at a real quality; set it back to Automatic afterwards. Judge "can you see it from X" at a stated quality level.

---

- **Start Play right after Stop and Studio can stay in Edit.** `start_stop_play(true)` straight after a stop reported "Game Started" but left Studio in Edit several times (2026-10-04). Check `get_studio_state` and start again.
- **Studio's camera script wins over yours while you are seated.** The game's `CameraRig` sets the camera in `RenderStepped`, after `BindToRenderStep`. For a fixed shot while driving, override `Camera:GetPropertyChangedSignal("CFrame")` (with a re-entry guard), or get out of the car.
- **A second player can't be started from the MCP.** To test what other players see of an effect relayed through the server, require a fresh copy of the client module from `execute_luau` (it gets its own module instance) and point it at your own car.

## 9. Working with the owner

- **Lead with numbers and show images.** Name the config knob for every judgement call and leave feel decisions to the owner.
- **Do exactly the scope asked.** State trade-offs a change forces, for example a wider feature eating into a gap the owner asked to keep. Offer the fix rather than silently changing something else.
- **Expect redirects mid-task.** Commit each working step, so a change of direction never leaves the game broken.
- **Keep docs in the same commit as the change,** with the measured numbers and the reason.
- **Never commit or discard someone else's uncommitted work.** Stage specific files only.
- **When asked to remove something, remove it completely.**

---

## 10. General lessons from mistakes

| Mistake | Rule |
|---|---|
| Objects snapped to terrain the same frame it was written, and ended up buried. | Wait until the terrain answers raycasts before placing on it. |
| A world build grew from 7 s to 40 s unnoticed until measured. | Print build time on every run; optimise empty work first. |
| Props looked buried in terrain that was really flat. | Suspect coarse level of detail in captures; move the real camera first. |
| An effect judged "not rendering" was only hidden behind geometry. | Rule out occlusion and culling with a marker before switching techniques. |
| A ledge at every landform edge survived several redesigns. | Measure the engine (half-voxel offset) before redesigning shapes. |
| A feature was tuned before its feel was agreed, then removed. | Get the feel spec in the owner's words first; keep features revertible. |
| Something was made so subtle it disappeared from the player's view. | Check the player's eye view whenever toning something down. |
| A two-axis gradient fade silently did nothing. | Verify each effect in isolation; fall back to simple stepped geometry. |
