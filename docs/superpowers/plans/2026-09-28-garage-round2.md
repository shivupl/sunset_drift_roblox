# Garage Round 2 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A uniform, attached exhaust on every car; polished exhaust flames everyone sees; driving into the garage; a few more polished options and tests.

**Architecture:** `CarCosmeticMounts.exhaust` becomes one standard shape (stock outlets + aftermarket tip layout + bumper face); `CarCosmetics` builds pipes/tips and publishes `ExhaustOutlet` attachments; a new client `ExhaustFlames` renders layered bursts at those outlets, triggered by `EngineAudio`'s pop decisions and relayed by the server; `GarageView` + a server `GarageService` handle drive-in/drive-out.

**Tech Stack:** Roblox Luau (`--!strict`), Rojo, luau-lsp, the repo spec runner, Roblox Studio MCP.

**Spec:** `docs/superpowers/specs/2026-09-28-garage-round2-design.md` (and the round-1 spec `2026-09-28-garage-design.md`).

## Global Constraints

- `--!strict`; no invented/deprecated APIs; `bash scripts/analyze.sh` clean for touched files (baseline errors in World/init.luau, Station.luau, BodyBuilder.luau).
- Specs in Studio Edit: `task.wait(1); local p,f = require(game.ReplicatedStorage.Shared:Clone().Tests)(); return p.." "..f` — 14 VehicleRig.spec failures are baseline. No tuple table types.
- Cosmetic only: never touch VehicleSim, scoring, handling or physics values; every added part CanCollide/CanQuery/CanTouch false, Massless, welded.
- Tunables in config modules (CosmeticsConfig, GarageConfig, CarConfig effects), with a why-comment.
- UI via UIKit/UITheme only.
- Live-light cap: no new Light instances outside the garage view.
- Stage specific files only; never stage/commit/discard RIG_SPEC.md, src/server/RigBuilder.luau, src/shared/CarCatalog.luau, src/shared/VehicleRig.luau, src/shared/Tests/VehicleRig.spec.luau, tools/carbody/*, assets/cars/kruzer100.
- Commits end with `Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>` and `Claude-Session: https://claude.ai/code/session_01PWSgvAKV3x1En9iuoQun7D`. Branch `garage`; don't push.
- Studio: one agent at a time. Focus Studio before Play (`osascript -e 'tell application "RobloxStudio" to activate'`); if Play is running with a seated player the owner is testing — report BLOCKED. Stop Play you start. Measure in Studio and describe screenshots in the report.
- Docs travel with the change (TUNING.md, WORLD.md, BEHAVIOURS.md for engine surprises).

---

### Task 1: The exhaust standard

**Files:** Modify `src/shared/CarCosmeticMounts.luau` (new exhaust shape for all 10 cars), `src/client/CarCosmetics.luau` (stock outlets, factory pipe where needed, attached tips + pipe, `ExhaustOutlet` attachments), `src/shared/CosmeticsConfig.luau` (render knobs), `src/shared/Tests/CarCosmeticMounts.spec.luau` (standard checks), TUNING.md.

**Interfaces — produces:**
- `CarCosmeticMounts.cars[id].exhaust = { stock: { { posM: {number} } }, tips: { posM: {number}, spreadM: number, pipeLengthM: number }, bumperZ: number }`.
- On every built body, for the current exhaust (stock or tips): Attachments named `ExhaustOutlet` (one per mouth) parented under the body folder, CFrame so that its LookVector points out of the pipe (toward +Z car-rear, following the pipe's direction), positioned exactly at the mouth. `CarCosmetics.outlets(model): { Attachment }` returns them (empty table if none).

- [ ] Measure every car's real stock pipe mouth(s) in Studio Edit (build car via RigBuilder.build + BodyBuilder.mount, anchored; screenshot the rear from 3/4 low; list body pieces named like Exhaust/Muffler/Pipe or read the mesh from the catalog), and where a car has no visible pipe add a factory pipe (a short dark pipe + bore under the bumper) at a sensible outlet.
- [ ] Re-measure the aftermarket tip layout per car so tips sit 2–5 cm past `bumperZ` with the pipe running forward under the body; check from rear 3/4, side, and a low chase-cam angle that nothing floats.
- [ ] Build outlets and pipes; write the spec checks listed in the round-2 spec §1; screenshot every car with stock, single, twin and quad; commit ("Exhaust standard: outlets on every car, tips attached").

### Task 2: Exhaust flames

**Files:** Create `src/client/ExhaustFlames.luau`; modify `src/client/EngineAudio.luau` (hook pops → flames), `src/server/CarControls.luau` (relay, validated, rate-limited) or a new small server module, `src/server/Remotes.luau`, `src/client/init.client.luau`, `src/shared/CosmeticsConfig.luau` (flame profile per exhaust item + shared flame look in `render` or a `flames` table), `src/client/Garage/GaragePanel.luau` (REV button in EXHAUST), docs.

**Interfaces:** consumes `CarCosmetics.outlets(model)`; produces `ExhaustFlames.burst(model: Model, pops: number)` (plays flames at every outlet for `pops` pops over the burst window) and the relay remote.

- [ ] Build the layered burst per the spec §2 with Roblox built-in textures only (e.g. `rbxasset://textures/particles/fire_main.dds`, `smoke_main.dds`, `sparkles_main.dds` — verify each id exists in Studio before using). Iterate with screen captures (Emit then capture within the flame's life; freeze time is not available, so capture right after Emit, several tries) until it reads as a hot, stretched, tapering flame with a blue core, not a puff. Scale with speed and exhaust profile.
- [ ] Hook to EngineAudio's pop decisions (same moments as the crackle sound), relay through the server to other clients, validate driver + rate limit.
- [ ] REV preview button on the garage EXHAUST tab (plays a burst on the turntable car, with the pop sound).
- [ ] Test in Play: driving with the harness (lift off at high rpm) produces flames synced with pops; a second client isn't available — verify the relay by checking the server receives and re-fires (log) and the client handler renders; screenshots; commit.

### Task 3: Drive into the garage

**Files:** Create `src/server/GarageService.luau`; modify `src/client/Garage/GarageView.luau`, `src/server/Remotes.luau`, `src/server/init.server.luau`, `src/server/CarSpawner.luau` only if a seat/unseat/park helper must be exported (read-only use preferred), `src/shared/GarageConfig.luau` (drive-in speed, drive-out spot), `src/server/World/Garage.luau` + WorldConfig.garage only to add a `DriveOutSpot` marker if needed, docs.

- [ ] Client: while seated as driver, detect the car chassis crossing the doorway zone below the config speed → call `GarageAction:InvokeServer("driveIn")`; on success open the view with that car id.
- [ ] Server: validate (driver seated, car inside zone, slow), unseat, pivot the car to the drive-out spot facing out, zero velocities, anchor while parked; on `"driveOut"` unanchor and seat the player; guard every edge (car destroyed, player left, second request).
- [ ] Leave after drive-in → seated in the car facing out; walk-in leave unchanged.
- [ ] Test in Play with the driving harness (drive in slowly; drive in fast → nothing happens; leave → seated and can drive off); screenshots; commit.

### Task 4: Options polish and tests

**Files:** `src/shared/CosmeticsConfig.luau` (4 paints, 2 rim finishes, 2 decals, window tint items), `src/client/CarCosmetics.luau` (tint), `src/client/Garage/GaragePanel.luau` (tint row under PAINT), `src/shared/CarLook.luau` (new slot `tint` if used — keep encode/decode compatible), server `Economy`/`CosmeticsService` only if a new slot needs it, new spec `src/shared/Tests/EconomyEncode.spec.luau` or a server-side test harness for Economy encode/readProfile, docs.

- [ ] Add the options; check each on three cars (screenshots); hide or fix anything that looks wrong on a car.
- [ ] Economy encode/readProfile tests (raw merge of unknown ids, unknown-car looks carried, stock clears, empty looks dropped) — Economy is server code: test it in Studio Edit by requiring a clone with FakeDataStore, or restructure the pure encode/readProfile into a shared module if that is cleaner (say which).
- [ ] Commit.

### Task 5: Docs, final pass

- [ ] Docs coherent (TUNING, WORLD, UI_SYSTEM, BEHAVIOURS, BRANCH_STATUS: the parked `car-backfire` branch is superseded — note it).
- [ ] End-to-end Play pass: drive in, customise exhaust, REV, leave seated, drive and pop flames; walk-in still works; screenshots; console clean; specs; commit.
