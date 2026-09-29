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
`plates-dubai` (Dubai, Abu Dhabi and Kuwait plate styles; the Kamri's grille badge spot filled; Kamri and
Lekzas front plates on the bumper) was merged into `main` and deleted on 2026-09-27.

**`garage` (open, 2026-09-28): ready for owner review, not merged.** The UI design system
(UI_SYSTEM.md, UITheme, UIKit; menus and HUD moved onto it), cosmetics (CosmeticsConfig, CarLook,
per-car looks saved on the server, drawn on every client), the garage workshop on the pad's left
wing, the walk-in customisation view and its panel (buy with confirm, equip). Spec and plan in
docs/superpowers. Open owner calls: finish look (mirror chrome needs Future lighting or
SurfaceAppearance maps), prices, `lights.key.brightness`, paintable pickup and cruiser shells.

Round 2 on `garage` (2026-09-28, commits `dde1061`..`e95b019`, the docs pass, `992a021` and the drive-out hold fixes; spec and plan in
docs/superpowers, `2026-09-28-garage-round2-*`): one exhaust standard on all ten cars (stock
outlets, attached tips and pipes, `ExhaustOutlet` attachments); layered exhaust flames seen by
everyone (`ExhaustFlames`, relayed by `CarControls`) and the REV preview; driving into the garage
and leaving seated in the car (`GarageService`); four paints, two rim finishes, two decals and
window tint, with Economy codec tests. Final Play pass: drive-in, buy and equip, REV, leave
seated, flames at speed, walk-in and the phone layout all worked; specs 3058 passed, 14 failed
(the VehicleRig baseline). One drive-out in five left the car on its side; fixed in `992a021`
(the car is held anchored through the seat until the driver's sim runs): 16 of 16 clean after,
dip at most 0.01 m. Still open for the owner: upshift and limiter pops (off by default), tint's mixed-version rollout,
and the pickup's pipe through its bumper. Not merged, not pushed.

**`garage-r3` (open, 2026-09-29): garage round 3, branched from `garage`, ready for owner review, not
merged, not pushed.** Commits `0ee650f` (spec and plan) through the final pass ("Garage round 3: sun
strips rename, docs, final pass"); spec and plan in docs/superpowers, `2026-09-28-garage-round3-*`.
Exhaust tips modelled in Blender (rolled, quad pair, slash titanium, the new Big Oval) on EditableMesh
templates with a cylinder fallback and an optional uploaded-mesh path; pipes routed up into each car
(`riseM` per car); the windscreen strip moulded to each car's glass as 14 slats and renamed SUN STRIPS
in the panel (ids and the `decal` slot key unchanged). Final Play pass: drive-in, walk-in and two
drive-outs worked; every exhaust item's outlets sat on its tip mouths (0.12 mm at worst) and REV
flamed from them; strips shown on five cars; lift-off pops and flames on the same frame; specs 10189
passed, 14 failed (the VehicleRig baseline). Open for the owner: upload the four tip meshes
(`meshAssetId`), since a client that has shown a Krown Vik and a Batrol has too few EditableMesh slots
left for mesh tips and falls back to cylinders; prices of the new items; once the owner's CarCatalog
changes (the kamri's new Body, Glass and Interior) are committed, rerun `python3 tools/cosmetics/strip_shapes.py`:
the committed kamri strip was fitted to the working copy's Glass, and on the committed catalog's Glass
it floats about 3.5 cm off the screen. With a kamri in view a client now keeps 5 EditableMesh slots
free for bodies (`tipMeshReserve` derives it from the catalog), so its tips are cylinders.

## Parked, superseded: exhaust backfire (`car-backfire`, local only, commit `d1f82d6`)

Pops and a flame burst at the exhaust tips, from the Kruzer 80 store model's A-Chassis
Backfire plugin, rebuilt on our sim (`src/client/Backfire.luau`, relayed by the server
`CarControls`, `effects.backfire` in CarConfig, on for the Kruzer only). The triggers worked
in a harness drive: a burst of 2-4 pops on lift-off above 4500 rpm and one on an upshift from
above 5500 rpm.

Why it is parked: the owner judged the flame animation poor (2026-09-25) and left it for now.
The store emitter (0.09 s puffs of one texture) is the weak part; the triggers and relay can
be kept if it is picked up again with a better flame.

Superseded on `garage` (round 2, 2026-09-28): `src/client/ExhaustFlames.luau` is the new
layered flame on every car's exhaust outlets, hooked to EngineAudio's pops (the lift-off burst;
upshift and limiter pops exist but are 0, off, by default, per the owner's 2026-09-22 ruling) and relayed through server `CarControls` (`ExhaustPops`). Its trigger and
relay ideas came from this branch; nothing of its code or look was merged. The branch can be
deleted once the owner agrees.

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
