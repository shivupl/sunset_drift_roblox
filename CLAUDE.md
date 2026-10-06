# Hajwala (Roblox)

A Roblox game about Saudi hajwala: highway drifting and two-wheel ("natl") driving. It runs on a desert highway that leads into a small Riyadh-style city.

## Read first
- **`BEHAVIOURS.md`:** general rules of thumb for Roblox development: engine traps, terrain, atmosphere, assets, performance, verification, working with the owner. Follow it, and add to it when the engine surprises you.
- **`WORLD.md`:** how this world is built and why, with measured numbers.
- **`TUNING.md`:** every config field, what it does and which way to move it.
- **`UI_SYSTEM.md`:** the UI's design tokens (`src/shared/UITheme.luau`) and the rules for using them: one sodium accent, bilingual titles, tap targets, shop item states.
- **`DESIGN.md`:** the vehicle model (suspension, tyres).
- **`RIG_SPEC.md`:** the car rig and body contract.
- **`tools/carbody/README.md`:** the store-car standard: how every car is split, named and debadged, which store-script features we keep (engine sounds, ignition, horn; the car's own lamp parts driven by our `CarLamps`), and the steps to add a car. Keep it current when the standard changes.
- **Design docs:** `hajwala-game-design.md`, `hajwala-niche-thesis.md`, `hajwala-project-phases.md`.
- **`BRANCH_STATUS.md`:** branch layout, and what is parked and why.

## Layout
| Path | Maps to | What is in it |
|---|---|---|
| `src/server` | ServerScriptService/Server | Spawning, rigs, scoring, economy |
| `src/server/World` | ServerScriptService/Server/World | The world build: RoadNetwork, Relief (terrain dunes and the shared `Relief.border` lookup), Fence, Scatter, DuneLife, Cityscape (skyline and aura), Station, Garage (the walk-in workshop), Lighting, City (`City/`) |
| `src/client` | StarterPlayerScripts/Client | Input, camera, HUD, menus, vehicle controller, effects, car looks (`CarCosmetics`), the garage view and panel (`Garage/`) |
| `src/shared` | ReplicatedStorage/Shared | CarConfig, CarCatalog, VehicleSim, VehicleRig, UITheme, CosmeticsConfig, GarageConfig, CarLook, tests |

Where the settings live:
- **World:** `src/server/World/WorldConfig.luau` and `City/CityConfig.luau`.
- **Car:** `src/shared/CarConfig.luau` and `CarCatalog.luau` (each car's `drivetrain.layout`); drift modes per drivetrain in `DriftStyles.luau` (Settings tab in game; O / Shift+O in Studio; L reloads them; the line that keeps a held slide on the highway is `CarConfig.line`).
- **Garage and UI:** `WorldConfig.garage` (the building), `src/shared/GarageConfig.luau` (the view), `CosmeticsConfig.luau` (items and how looks are drawn), `UITheme.luau` (UI tokens).

World code works in metres; convert with `ctx.s(m)` (studs = m / 0.28). The road starts at the origin and runs along -Z; +X is the road's right; the sunset is on the left.

## Commands
- **Type check:** `bash scripts/analyze.sh` (strict luau-lsp). `World/init.luau` and `Station.luau` have known baseline errors, so only new errors in touched files matter. The uncommitted car-rig changes add BodyBuilder errors.
- **Specs:** in Studio Edit, swap a fresh clone in as `Shared` for the run, because server modules under test (Economy, PlateRegistry) require `ReplicatedStorage.Shared` by path and Edit caches the old one: `local o = game.ReplicatedStorage.Shared; local c = o:Clone(); o.Name = "Shared_orig"; c.Parent = game.ReplicatedStorage; task.wait(1); local ok, p, f = pcall(require(c.Tests)); c:Destroy(); o.Name = "Shared"; return p.." "..f`, all in one `execute_luau`. A plain `require(game.ReplicatedStorage.Shared:Clone().Tests)()` gave 9 false EconomyCodec.spec failures (stale CosmeticsConfig without tint) on 2026-09-28. 14 VehicleRig.spec failures come from the uncommitted car-rig changes.
- **Rojo:** `rojo serve` (Rojo 7.7 via Rokit).

## Studio workflow (MCP)
- **Studio id:** changes between sessions (it was `9a8b2d85-e643-4b20-81cd-c7a90005d565` on 2026-09-15); call `list_roblox_studios` each session.
- **Sync with Rojo, not HTTP:** newer Studio MCP builds run executed code without the Network capability, so `HttpService:GetAsync` (the `scripts/mcp_sync.py` + loader route) and `VirtualInputManager` both fail. Run `rojo serve` and connect the Rojo plugin; Rojo syncs into the **Edit** tree, so a running Play session keeps the old modules until Play is restarted.
- **Driving the UI:** the MCP `user_mouse_input` / `user_keyboard_input` tools send real input (`instance_path` aims at a GuiObject). Mouse drags do **not** scroll a ScrollingFrame (only touch does); use `scrollUp`/`scrollDown` to test scrolling.
- **Phone UI without a device:** set the LocalPlayer attribute `ForceTouch = true`, then reopen the menu (M) so it re-lays out in touch metrics.
- **Old HTTP sync (only where executed code still has Network):** `python3 scripts/mcp_sync.py --manifest` with `python3 -m http.server 8765 --bind 127.0.0.1` in the repo root, then run `scripts/studio_loader.luau` via `execute_luau` in Edit.
- **Either way, server or world code needs Play stopped and started again.**
- **World preview in Edit:**
  1. Clone `ServerScriptService.Server.World` into ServerStorage as `WorldPreview` and call `require(clone).build()`.
  2. Move `workspace.CurrentCamera` (CFrame and Focus) to the spot for a few seconds, then `screen_capture`.
  3. Clean up: destroy workspace `World`, `Road`, `RoadDetail` and `City`, run `Terrain:Clear()`, and destroy the clone.
- **Driving harness** (Client datamodel):
  - Set `InputOverride = true` on the LocalPlayer, then `OvThrottle`, `OvSteer`, `OvBrake` (numbers) and `OvHandbrake`, `OvLeanLeft`, `OvLeanRight` (booleans).
  - Spawn with `ReplicatedStorage.Remotes.SpawnCar:FireServer(id)`; the car is `Humanoid.SeatPart.Parent.Parent`.
  - Reset the car from the client with `PivotTo` and zeroed velocities, and turn `InputOverride` off afterwards.
  - Live config reload: set `OvReload = true` from the Client datamodel.
  - Trying drift numbers live: set the LocalPlayer attribute `DriftLab` to a JSON partial config (`{"line":{"hold":0.8}}`); it is merged over the car's styled config at once (Studio only), and `""` turns it off. `DriftStyleAny` forces a mode on any car.
  - The override bypasses the keyboard's steer ramp (4/s out, 8/s back); ramp `OvSteer` per frame to measure what a keyboard player gets.
  - Framing speed effects: set the LocalPlayer attribute `SpeedFeelKmh` (Studio only) to the speed the camera's view, shake, speed lines and wind should read, anchor the car, then capture. `screen_capture` of a moving car takes about 30 s, so the car must stay on the 3.6 km straight that long.
- **Trying sky values live:** the client resets `Lighting.ClockTime`, `Brightness` and `ExposureCompensation` to the player's Sunset/Night choice (`SkyConfig`, `client/Sky.luau`). In Studio, tick the LocalPlayer attribute `SkyFree` (Client view: Players > you > Attributes) to stop that; untick to restore. Tell the owner about it when they want to experiment with the sky.
- **Debug readouts:** `Dbg*` attributes on the LocalPlayer, updated at 30 Hz.
- **Focus Studio first** (`osascript -e 'tell application "RobloxStudio" to activate'`) before builds, captures or timing.
- **Check `DriverSeat.Occupant` before taking the car:** the owner often leaves Play running to test by hand.

## Conventions
- **Strict Luau.** `--!strict` on every file.
- **No invented or deprecated APIs.**
- **Tunables live in the config modules**, never inline. Comment the why, including the owner's request history, next to each number.
- **Shared lookups:** terrain, fence, props and dune life all read `Relief.border` (`heightAt`, `layersAt`, `insideFence`, `clearOf`, the city circle). Keep them agreeing through it.
- **Scenery** is anchored and non-colliding unless the car must hit it; anything that collides is also queryable.
- **No real brands.** The sedan is the "Kamri".
- **Docs travel with the change:** update WORLD.md or TUNING.md in the same commit, with measured numbers. Print build cost in `[World]` report lines.

## What the owner expects
- **Measure in Studio and report before and after numbers in a table.**
  - Drive with the harness, never a scripted driver.
  - Never tune to pass a test.
  - Leave feel calls to the owner and name the knob.
- **Show screenshots for visual changes**, from the driver's view where it matters.
- **Subtle means subtle.** Remove means remove completely. Distances: err generous. Scenery: calm, natural, sparse, never in lines.
- **Driving feel targets:**
  - 360s easy, chained tricks keep speed, 720s may stay hard.
  - Nothing feels like ice; launch is quick "off rip".
  - Natl: "first tap gets it up, later taps keep it".
  - Steering lock stays 38 degrees unless argued for.
- **Keep every step committed and working.** The owner redirects mid-task.

## Git
- **Stage specific files only.** The working tree holds uncommitted car-rig changes that are not ours: RIG_SPEC.md, RigBuilder, CarCatalog, VehicleRig, VehicleRig.spec, tools/carbody (`kamri.py`, `meshkit.py`; `plate.py` and `apply_catalog.py` deleted). Do not commit or discard them without being asked.
- **End commits** with the session's Co-Authored-By and Claude-Session trailers.
- **Give the owner a link for every commit:** `https://github.com/shivupl/sunset_drift_roblox/commit/<sha>`. A link only works once the branch is pushed; ask before pushing.
- **Branches:** `main`, plus parked local branches listed in BRANCH_STATUS.md (the exhaust backfire). Work on `main` or a short-lived branch merged back into it, and record a parked branch there.
- **Switching branches with the owner's uncommitted CarCatalog:** back the file up, `git stash push -- src/shared/CarCatalog.luau`, switch or merge, `git stash pop`, then `cmp` against the backup. To commit our own CarCatalog lines, build the staged file from `HEAD` with only our car's entry block swapped in from the working copy, then `git hash-object -w` it and `git update-index --cacheinfo`; check `git diff --stat` then shows only the owner's lines unstaged. (A hand-made `--unidiff-zero` hunk patch once put a pure insertion in the wrong table.)
