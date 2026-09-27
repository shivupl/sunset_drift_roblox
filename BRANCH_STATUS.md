# Branch status

**`main` is the only branch** (tidied 2026-09-22). Everything from `phase0-vehicle`,
`phase2-rig-body`, `phase3-cars` and `mobile-perf` is on it; those branches were fully merged
and deleted. Work happens on `main`, or on a short-lived branch merged back into it.
`car-lights-sounds` (lamps, horn, ignition, the store engine sets, the Batrol and Kruzer 80)
was merged into `main` and deleted on 2026-09-25.
`car-ls430` (the Lekzas) was merged into `main` and deleted on 2026-09-26.
`car-crownvic` (the Krown Vik and Krown Vik Fleet) was merged into `main` and deleted on 2026-09-26.
`plates` (number plates: Saudi, cash, unique registry; spec and plan in docs/superpowers) was
merged into `main` and deleted on 2026-09-27.

## Parked: exhaust backfire (`car-backfire`, local only, commit `d1f82d6`)

Pops and a flame burst at the exhaust tips, from the Kruzer 80 store model's A-Chassis
Backfire plugin, rebuilt on our sim (`src/client/Backfire.luau`, relayed by the server
`CarControls`, `effects.backfire` in CarConfig, on for the Kruzer only). The triggers worked
in a harness drive: a burst of 2-4 pops on lift-off above 4500 rpm and one on an upshift from
above 5500 rpm.

Why it is parked: the owner judged the flame animation poor (2026-09-25) and left it for now.
The store emitter (0.09 s puffs of one texture) is the weak part; the triggers and relay can
be kept if it is picked up again with a better flame.

## Parked: the Kamri car body (uncommitted in the working tree)

The Kamri is a car body generated in the repo (`tools/carbody/kamri.py`), 10,108 triangles,
with baked textures on SurfaceAppearance looks and RIG_SPEC.md §7b describing the pipeline.
Bodies are mounted per client (`src/client/CarBodies.luau`, `src/shared/BodyBuilder.luau`),
and wheel travel comes from the suspension compression (`src/client/WheelVisuals.luau`).
Those parts are committed.

The latest car-rig changes (RIG_SPEC.md, RigBuilder, CarCatalog, VehicleRig, VehicleRig.spec,
tools/carbody) are deliberately **left uncommitted** at the owner's direction.

Why it is parked: the owner is making car models externally (2026-09-22) and the store cars
replaced it. Generated meshes no longer block it: the owner turned on "Allow Mesh / Image APIs"
on 2026-09-26, so generated pieces (the Batrol and Lekzas chrome) show in play without uploads.
