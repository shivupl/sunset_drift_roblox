# Hajwala (Roblox)

A Roblox game about Saudi hajwala: highway drifting and two-wheel ("natl") driving. It runs on a desert highway that leads into a small Riyadh-style city.

## Read first
- **`BEHAVIOURS.md`:** engine traps, the Studio MCP workflow, the owner's preferences and past mistakes. Read it before any Studio work, and add to it when something surprises you.
- **`WORLD.md`:** how the world is built and why, with measured numbers.
- **`TUNING.md`:** every config field, what it does and which way to move it.
- **`DESIGN.md`:** the vehicle model (suspension, tyres).
- **`RIG_SPEC.md`:** the car rig and body contract.
- **Design docs:** `hajwala-game-design.md`, `hajwala-niche-thesis.md`, `hajwala-project-phases.md`.
- **`BRANCH_STATUS.md`:** what is parked and why.

## Layout
| Path | Maps to | What is in it |
|---|---|---|
| `src/server` | ServerScriptService/Server | Spawning, rigs, scoring, economy |
| `src/server/World` | ServerScriptService/Server/World | The world build: road, relief (terrain dunes), fence, scatter, dune life, skyline (Cityscape), station, lighting, city (`City/`) |
| `src/client` | StarterPlayerScripts/Client | Input, camera, HUD, vehicle controller, effects |
| `src/shared` | ReplicatedStorage/Shared | CarConfig, CarCatalog, VehicleSim, VehicleRig, tests |

Where the settings live:
- **World:** `src/server/World/WorldConfig.luau` and `City/CityConfig.luau`.
- **Car:** `src/shared/CarConfig.luau` and `CarCatalog.luau`.

## Commands
- **Type check:** `bash scripts/analyze.sh` (strict luau-lsp). World/init.luau and Station.luau have known baseline errors; only new errors in files you touched matter.
- **Rojo sync:** `rojo serve` (Rojo 7.7 via Rokit).
- **MCP sync:** when Rojo is not connected, sync through the Studio MCP: `python3 scripts/mcp_sync.py --manifest`, serve the repo on `127.0.0.1:8765`, then run `scripts/studio_loader.luau` with `execute_luau` in Edit. Details in BEHAVIOURS.md §2.
- **Specs:** in Studio, `require(game.ReplicatedStorage.Shared:Clone().Tests)()`.

## Conventions
- **Strict Luau.** `--!strict` on every file.
- **No invented or deprecated APIs.** No BodyVelocity, BodyGyro or BodyPosition. If unsure an API exists, check the Roblox docs first.
- **Tunables live in the config modules**, never inline. Comment the why, including the owner's request history, next to each number.
- **Units:** world code is in metres; convert with `ctx.s(m)` (studs = m / 0.28).
- **Scenery** is anchored and non-colliding unless the car must hit it. Anything that collides must also be queryable.
- **No real brands**, badges or logos.
- **Docs travel with the change:** update WORLD.md or TUNING.md in the same commit, with measured numbers.

## How to work here
- **Measure in Studio and report before and after numbers.** Drive with the input-override harness, never a scripted driver. Never tune to pass a test. Leave feel calls to the owner and name the knob.
- **Show screenshots for visual changes.** Capture in Edit with the real editor camera moved to the spot first (BEHAVIOURS.md §2).
- **Check before taking over a running Play session.** The owner often leaves Play running to test by hand, so check the driver seat first.
- **Keep every step committed and working.** The owner redirects mid-task.
- **Git:**
  - Stage specific files only.
  - The working tree holds uncommitted car-rig changes that are not ours: RIG_SPEC.md, RigBuilder, CarCatalog, VehicleRig, VehicleRig.spec, tools/carbody. Do not commit or discard them without being asked.
  - End commits with the session's Co-Authored-By and Claude-Session trailers.
- **Branches:** `phase3-cars` is marked inactive for the Kamri car-body work (see BRANCH_STATUS.md), but world work since 2026-09-13 has been committed on it at the owner's direction.
