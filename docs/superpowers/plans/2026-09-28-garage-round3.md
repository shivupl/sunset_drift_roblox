# Garage Round 3 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Blender-modelled exhaust tips, pipes that route up into each car, sun strips moulded to each windscreen, and the DECALS → SUN STRIPS rename.

**Architecture:** Tip meshes come from a headless-Blender script as MeshData modules (the `src/shared/CarMeshes` path) decoded into EditableMesh templates on each client; pipes are swept tubes built at runtime; strip slat frames are generated offline from each car's windscreen mesh into a data module and built as SurfaceGui slats by `CarCosmetics`.

**Tech Stack:** Roblox Luau (`--!strict`), Rojo, luau-lsp, Blender 4.x headless (`/opt/homebrew/bin/blender`), Python 3, the repo spec runner, Roblox Studio MCP.

**Spec:** `docs/superpowers/specs/2026-09-28-garage-round3-design.md` (and round 2's `2026-09-28-garage-round2-design.md`).

## Global Constraints

- `--!strict`; no invented/deprecated APIs; `bash scripts/analyze.sh` clean for touched files (baseline errors in World/init.luau, Station.luau, BodyBuilder.luau).
- Specs: run per CLAUDE.md "Specs" (swap a fresh `Shared` clone in, one `execute_luau`); 14 VehicleRig.spec failures are baseline. No tuple table types.
- Cosmetic only: never touch VehicleSim, scoring, handling or physics values; every added part CanCollide/CanQuery/CanTouch false, Massless, welded (`visualPart` in CarCosmetics).
- The `ExhaustOutlet` contract (round 2 §1) is unchanged: outlets exactly at the tip mouths, LookVector out of the pipe; flames must still work.
- Tunables in config modules (CosmeticsConfig `render`, CarCosmeticMounts) with a why-comment. UI via UIKit/UITheme only.
- No new Light instances. Report parts and triangles per car look.
- Item ids and the `decal` slot key never change (stored on profiles).
- Stage specific files only; never stage/commit/discard RIG_SPEC.md, src/server/RigBuilder.luau, src/shared/CarCatalog.luau, src/shared/VehicleRig.luau, src/shared/Tests/VehicleRig.spec.luau, tools/carbody/kamri.py, tools/carbody/meshkit.py, the deleted tools/carbody/plate.py and apply_catalog.py, assets/cars/kruzer100.
- Commits end with `Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>` and `Claude-Session: https://claude.ai/code/session_01PWSgvAKV3x1En9iuoQun7D`. Branch `garage-r3`; don't push.
- Studio: one agent at a time. Focus Studio first (`osascript -e 'tell application "RobloxStudio" to activate'`); if Play is running with a seated player the owner is testing — report BLOCKED. Stop Play you start. Rojo is already serving (syncs into Edit). Measure in Studio; save screenshots' descriptions in the report.
- Docs travel with the change (TUNING.md, WORLD.md, UI_SYSTEM.md, tools/carbody/README.md where the generated-mesh path is described, BEHAVIOURS.md for engine surprises).

---

### Task 1: Modelled exhaust tips

**Files:** Create `tools/cosmetics/exhaust_tips.py` (headless Blender: builds each tip style, writes MeshData modules via the same encoding as `tools/carbody` — reuse its writer, don't fork the format), `tools/cosmetics/README.md`; create `src/shared/CosmeticMeshes/` (generated); modify `src/client/CarCosmetics.luau` (tips from mesh templates; quad as two Y pairs; no separate bore cylinder), `src/shared/CosmeticsConfig.luau` (per-item `tipStyle`, new `exhaust_oval` item, render knobs), `src/shared/CarCosmeticMounts.luau` only if the mouth math must know the Y-pair, `src/shared/Tests/*` (catalog integrity: every tip item names a style that exists), TUNING.md.

- [ ] Spike first (Studio Edit): does an EditableMesh's per-vertex/face colour render on a MeshPart made with `AssetService:CreateMeshPartAsync(Content.fromObject(em))`? Record the answer in BEHAVIOURS.md. Pick the titanium heat-colour route from it.
- [ ] Blender script: styles rolled, quad (joined pair, one inlet), slash (titanium), oval (new). Mouth centre at a documented local point, axis +Z out of the mouth; inner wall dark (vertex colour or separate inner mesh); ≤1,500 tris each. Render a preview PNG per style in Blender (to the scratchpad) and look at it.
- [ ] CarCosmetics: tips from templates (clone, scale by car scale), same mouth positions (`tipMouths`), quad pairs share one inlet; outlets unchanged. Materials per item (chrome/black/titanium) look right under the garage lights and outside (screenshots, 3 cars minimum, all five items).
- [ ] Commit ("Exhaust tips modelled in Blender: rolled, quad pair, slash titanium, oval").

### Task 2: Pipes routed into the car

**Files:** `src/client/CarCosmetics.luau` (swept pipe builder, cached by shape; hanger), `src/shared/CarCosmeticMounts.luau` (`riseM` on every car's exhaust, measured, why-comment; type), `src/shared/Tests/CarCosmeticMounts.spec.luau`, `src/shared/CosmeticsConfig.luau` (bend radius, segments, hanger knobs), TUNING.md.

- [ ] Swept tube: forward `pipeLengthM` from the tip inlet (or factory mouth), bend up `riseM` with a config bend radius, ending hidden in the underbody; one tube per tip (one per quad pair). Factory pipes the same way.
- [ ] Measure `riseM` on all 10 cars (below and side captures with body pieces hidden as in round 2); spec: `riseM > 0` everywhere.
- [ ] Screenshots from rear 3/4 low and side on every car: no pipe end visible, nothing floats; commit ("Exhaust pipes routed up into the body").

### Task 3: Sun strips moulded to the windscreen

**Files:** Create `tools/cosmetics/strip_shapes.py` (reads each car's windscreen: store glass via `tools/carbody/rbxcache.py` from Studio's cache, generated glass from its MeshData module, placed in car space as the catalog places the piece; fits slats), `src/shared/CarStripShapes.luau` (generated); modify `src/client/CarCosmetics.luau` (slats with sliced SurfaceGuis), `src/shared/CarCosmeticMounts.luau` (windscreen spot keeps what the generator needs: which piece, inside/outside, strip height), `src/shared/CosmeticsConfig.luau` (slat count, overlap, offset), specs, TUNING.md.

- [ ] Generator: for each car, the windscreen faces (the glass piece, faces facing forward-up), its top edge; N slats across, each centred on the surface a strip-height below the top edge, normal from the surface, width to the outline (ends cut at the pillars). Hand-tune fallback for cars where the mesh gives no clean screen (say which).
- [ ] Runtime: slats with one SurfaceGui each showing its slice of the canvas; text and gradient continuous; overlap so no seams.
- [ ] Screenshots front 3/4 and front on every car, all six strip items on at least three; commit ("Sun strips moulded to each windscreen").

### Task 4: Rename, docs, final pass

**Files:** `src/client/Garage/GaragePanel.luau` (chip `SUN STRIPS`, title `SUN STRIPS` / `شريط`), `src/shared/CosmeticsConfig.luau` (comments/names), UI_SYSTEM.md, TUNING.md, WORLD.md, BRANCH_STATUS.md, CLAUDE.md layout line if it names decals.

- [ ] Rename in UI (ids and slot key unchanged); chips still fit on desktop and ForceTouch.
- [ ] End-to-end Play pass: garage, every exhaust item + REV flames from the new tips, strips on several cars, drive with tips (flames sync); console clean; specs; parts/tris table; commit.
