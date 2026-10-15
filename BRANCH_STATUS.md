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

**`ui-flow` (2026-10-12, branched from `tweaks-2` at `b2166f3`; merged into `main` by fast-forward
on 2026-10-14 at `9e46cea`, not yet pushed; the local branch is kept for now): the whole phone UI as
one frame.** The owner: "string together the entire UI from here for mobile. make
a couple different complete layouts but just stop it from being so choppy and disconnected". The
menu (`src/client/Menu`: CARS, PLATES, SETTINGS) draws through the garage's layouts, so the menu and
the garage share the words, EXIT, the HUD's own coins, the column, the action and one motion; one
layout choice (`UiLayout`: SHOWCASE, GLASS, FRAME, DOCK) for every screen. The car picker's layouts
(COMPACT, SHOWROOM, STRIP) and the old PLATES and SETTINGS panels are gone on this branch (they are
on `tweaks-2`). CARS and PLATES are then the old picker's SHOWROOM (two panels, its wide cards, a CARS | PLATES
switch, CUSTOMIZE on the car's stage; PICKER, FRAME, a side RAIL and a CUSTOMIZE button were tried
and went), and SETTINGS the BOARD (one panel: time-of-day tiles, HUD finish cards, the camera and
HUD layout as slanted choices). UI_SYSTEM.md "One frame for every screen" has the whole of it. Its last five commits were the owner's phone fixes, tested
one by one on `mobile-fixes` (deleted after merging): landscape lock, EXIT on the top row while driving,
tabs 40 tall with the art at 2x, the garage doorway as a box you are in at any speed, and MY CARS boxes
one size per tab.

**`desktop-ui` (2026-10-14, branched from `main` at `71b0fda`; not merged): the PC screen.** The
owner: "put a small guide on which keys are for what", "the odometer and stuff should go on the
right", "the buttons and everything needs to be redone and spaced for pc", "make a couple different
full UI options ... implement them in game for me to switch between". Three desktop layouts (DASH,
STRIP, CLUSTER, at `a669f1a`) of where the readouts, the key guide (`HudLab/KeyGuide.luau`) and the
top row's tabs go; the top bar on a desktop with the keys on its tabs, the CARS button gone. The
owner picked DASH and asked for polish and variants, so the layouts are now DASH, DASH THIN and DASH
FADE (`HudLab/Desk.luau`, K or Settings' PC LAYOUT rows): the dial bottom right in all, the key guide
faint in three forms, the tabs' keys centred and light. UI_SYSTEM.md "The desktop HUD" has it; the canvas "Hajwala desktop
HUD" the drawings. The garage on a PC: 22 px margins; three sizes of SHOWCASE and three price
styles for its blocks were tried (K and J cycled them, `c9c6646`); the owner picked BIGGER and
BAND and had the others and the keys removed, so a PC's SHOWCASE is at BIGGER's numbers with the
price on a band. UI_SYSTEM.md "On a PC" has the numbers.

**`tweaks` (merged into `main` 2026-10-04 by fast-forward, pushed; the local branch is kept for now):
auto-flip and tyre smoke.** A capsized car is rolled back onto its wheels by a real torque about its long
axis (client and shared `AutoFlip`, `CarConfig.autoFlip`): steer and it heaves up off its edge and drops
onto its springs, even while it still slides; untouched, it rolls itself after 0.8 s at rest; the old
scripted roll is only the last resort for a car wedged where it can't roll. White tyre smoke from a
per-wheel tread-heat model (shared `TireHeat`, client `TireSmoke`): drifts, lock-ups, handbrake and
burnouts smoke, grip doesn't; it builds in and tails off; heat follows each tyre's load; every player
sees every car's smoke through a server-stamped `TireSmoke` attribute (`CarControls`). Roblox's
realistic smoke texture; road smoke laid by distance from the live contact patch as a continuous trail
(trail and wisps, a billow, a faint haze on a light breeze), hidden by the car's body (ZOffset 0.15 m);
the fronts' load shares swapped at the owner's request (`frontLoadSwap`); tan dust instead of smoke on
sand or dirt, its settings kept exactly as the owner signed them off. Specs in `AutoFlip.spec` and
`TireHeat.spec`; tuning history in TUNING.md (autoFlip, effects).

**`exhaust-flames` (merged into `main` 2026-10-05 by fast-forward and pushed with it; the local branch
is kept for now): exhaust pop styles.** The owner asked for "different exhaust flame variants but really cool ones" with audio "like the
sputter". Three new styles plus today's look as Classic (`ExhaustStyles`): Crackle (the default; a
thinning, irregular string of cracks), Blue Flame (even cracks, blue-violet torches) and 2-Step (an
even machine-gun beat). A fourth, Anti-Lag (a few big bangs and fireballs), was taken out completely
at the owner's word on 2026-10-05 ("get rid of the anti-lag one completely for now"); its last
version is commit `ca776e7`. A seeded rhythm (`ExhaustSputter`)
makes each burst; every pop is a real pop cut from a measured Creator Store recording
(`Sound.PlaybackRegion`) with its animated flipbook flame and a pooled flash light on the same frame
(`ExhaustPops`, `ExhaustFlames.flame`); the relay is one message a burst, rebuilt from its seed on every
client. In Studio, P cycles the style. Spec, research and plan in docs/superpowers
(`2026-10-04-exhaust-flame-*`); measurements in TUNING.md (`ExhaustStyles`). The owner tried them in
Play ("i think they work great") and asked for the rest to be merged. A final whole-branch review found
no critical issues; its fixes (texture fallback, the flash light's range, Classic's count, 2-Step's
beat, stale docs) went in before the merge. Open for the owner: the pop volumes (set by measured
peaks, not by ear). The styles became garage flames on `garage-tyres-flames`.

**`drift-feel` (2026-10-05, branched from `main` at `2d3e066`; merged into `main` the same day with
`drift-overhaul` and `speed-feel`, and deleted): drivetrains, drift styles, the feather and the drift
flutter.** The owner asked for the drift to differ by drivetrain
with several styles each to try in game, and for "the ability to kick off the exhaust during a drift
where the flames would also flutter". The sim drives front, rear or all four wheels
(`drivetrain.layout`; rear drive is the old path exactly); the Kamri and Hatch are front drive, the
Batrol and Kruzer 80 four-wheel drive, the rest rear drive. Seven styles (`DriftStyles`): Classic,
Power Over and High Angle on rear drive, Handbrake and Lift-Off on front drive, Rally and Drift Mode
on all-wheel drive, picked in the menu's Settings tab (per drivetrain, for the session) or with O /
Shift+O in Studio; none touches the lever, so the lever 360 measures 2.4-2.6 s on every one. A short
lift mid-drift (a feather) no longer ends the drift, and fires the exhaust style's flutter (dense
pops, overlapping flames) instead of its burst. Spec, research and plan in docs/superpowers
(`2026-10-05-drift-feel-*`); measurements in TUNING.md (`drift`, `DriftStyles`). Open for the
owner: which style each drivetrain defaults to, whether the choice is saved to the profile, front
drive's slower launch (0-100 4.2 s against 3.65), and the catch that now waits out a feather
(0.59-0.68 s against 0.53).

**`drift-overhaul` (2026-10-05, branched from `drift-feel` at `8574a08`; merged into `main` the same
day with `speed-feel`, and deleted): the drift overhaul.** The owner asked for "a full overhaul and perfection of the drifting system ... from throlle
bursts to stable trifting and the standdard hajwala 360s" with modes per drivetrain, and to keep the
sideways drifting "within the highway boundries". The line (`VehicleSim/Line.luau`) keeps a held slide,
a chain and a 360 on the highway (a held slide went 79 m sideways in 4 s; now 0-13 m by mode); in the
new modes the throttle sets the angle (gas widens, a lift tightens and flutters, a stab kicks with a
surge of drive), the wheel's into-dial is slower and capped, and new entries (power-over, the
double-tap clutch kick, the brake tap, the pivot) belong to their modes. Twelve modes: Hajwala, Kick,
High Angle (rear); Tafheet, Lift-Off, Pivot (front); Rally, Drift Mode, Tatweef (all-wheel); and
Classic on each, the drift-feel default kept for A/B. Studio's `DriftLab` attribute tries numbers live.
Research and design in docs/superpowers/specs (`2026-10-05-drift-overhaul-*`); measurements in TUNING.md
(`drift`, `line`, `DriftStyles`). Open for the owner: the defaults per drivetrain, how strong the line
is (`line.hold`), and whether the choice is saved to the profile.

**`speed-feel` (2026-10-05, branched from `drift-overhaul` at `78d12c3`; merged into `main` the same
day with `drift-overhaul` and `drift-feel`, and deleted): the driving made faster and made to feel
faster.** The owner: "overall game driving feels pretty slow ... needs to
feel at least 50% faster if not 2x", and chose both. More torque on every car (`drivetrain.powerScale`, 1.6),
a sixth gear, the top speed 330, a launch grip off the line; a wider speed view, a camera that no longer
trails a fast car, a faint high-speed shake, faint screen-edge speed lines and a wind roar
(`client/SpeedFeel`). Measured in TUNING.md (`drivetrain`, `camera`, `speedFeel`). Open for the owner:
whether earnings should be held level (`scoring.referenceSpeedKmh`), the wind sound (picked unheard),
and how strong the lines and shake are.

**`garage-tyres-flames` (2026-10-05, branched from `main` at `3b4116b`; merged into `main` with
`garage-polish` on 2026-10-06, and deleted): drift modes as tyres, flame styles as garage items.** The owner: "make the differnt driftmodes we made different
tire options in the garage instead of drift options in the car menu. by default start all at classic
... same for the tire flames. have classic be the default and the other flames purchasable in the
garage". Two new cosmetic slots, `tyre` and `flame`, appended after `tint` so every saved look reads
the same. Every car starts on Classic tyres (its drivetrain's Classic mode) and the Classic flame
(now `ExhaustStyles.default`); the nine other modes are tyres at 25,000 that fit only their
drivetrain (the server refuses the rest), and Crackle, 2-Step and Blue Flame are flames at 20,000,
30,000 and 40,000. WHEELS shows the car's tyres under its rims with the showing tyre's blurb; EXHAUST
shows the flames under the tips, and REV plays the flame showing. The DRIFT MODE section left the
Settings tab. This settles three open calls: the drift defaults (Classic), saving the choice (per car,
with the look), and whether flame styles become garage items (yes). Studio's O, Shift+O, P and
`DriftLab` still override what is fitted. Checked in Play: the rows and preview drew, buy and fit
worked, a rear-drive tyre was refused on the front-drive Hatch, and the fitted tyre and flame resolved
to their mode and style; specs 12587 passed, 14 failed (the VehicleRig baseline). Open for the owner:
the prices.

**`garage-polish` (2026-10-05, branched from `garage-tyres-flames` at `2c9f3ca`; merged into `main`
on 2026-10-06, and deleted): the garage made to go to each part.** The owner: "when selecting exhaust tips or flames, it should like
zoom into that part and for the flames, shoudl do a quick play of it ... overall improve and polish the
garage", choosing panel layout and sound and motion on top. Close camera shots per part
(`GarageConfig.shots`: the wheel, the windows, each lamp corner, the windscreen, the plate, the
exhaust), the car turned and held, the camera eased in; a drag goes back out. Tapping tips or a flame
plays a burst once the camera is there; headlight colours blink the lamps; TAIL LIGHTS has the brake
lights on. Sub-tabs replace the title rows (PAINT: COLOUR, TINT; WHEELS: RIMS, TYRES; LIGHTS;
EXHAUST: TIPS, FLAMES, REV); the badge moved onto the tile's corner, so cards are shorter. Sounds
(tab, tap, an impact wrench on a fit, a cash register on a purchase, error; picked unheard), a press
and pop on cards, the cash counting down, the grid sliding in. Spec
`docs/superpowers/specs/2026-10-05-garage-polish-design.md`. Light testing at the owner's word: specs
12682 passed, 14 failed (the VehicleRig baseline, on the branch and again on `main` after the merge); in Play the wheel, tail and exhaust shots framed,
a Blue Flame tap fired its burst from the preview's exhaust as the camera arrived, no errors. Open for
the owner: the shots' framings and the sounds (by ear), and the phone layout (not checked).

**`garage-ui-overhaul` (2026-10-06, branched from `main` at `60cdede`; merged into `main` on 2026-10-10,
fast-forward, with `hud-variants` on top of it; the local branch is kept for now): the garage panel redrawn.** The owner (a /goal): "polish the UI of the garage, a complete overhaul to make the UI
look better and more organized + appealing. try different styles". Three styles were mocked in the
Client over the real garage (a boxed panel with a swatch grid, full-bleed paint-chip cards, and a
box-less shade with a list) and the hybrid built: no panel box but a shade that fades into the garage
(its tail lets drags reach the turntable), one header row (GARAGE and the Arabic, the cash, a close
button), the categories as a rail of words with a sliding sodium marker, sub-tabs as words with a
sliding underline, FINISH a PAINT sub-tab of its own (its pills took three rows), colours as a
palette grid and everything else as a list, each item's state a word under its name, and a foot that
names what BUY buys. The panel is 420 px (46% of a phone). Spec
`docs/superpowers/specs/2026-10-06-garage-ui-overhaul-design.md`; rules in UI_SYSTEM.md. Specs 12692
passed, 14 failed (the VehicleRig baseline). In Play (desktop and `ForceTouch`): every category drew,
15 paints in view (was 4), a tip and a finish previewed with the foot naming them, a purchase counted
the cash down with its toast, collapse and the close button worked, no errors. Open for the owner: the
look itself, and a real phone (a 350 px tall screen fits the rail only at 40 px rows; checked in a
mock, not a device).

**`hud-variants` (2026-10-07, branched from `garage-ui-overhaul` at `da2cfc0`; merged into `main` on
2026-10-10, fast-forward at `d6733eb`; specs 12692 passed, 14 failed, the VehicleRig baseline; the local
branch is kept for now): driving
HUD and phone-control variants to try.** The owner, on the theme mockups: "these really arent that
good... for the phone it should be actual gas/break pedals and whatnot. i need a way more alive UI",
then "just take refference from any of those games, make some better variants for me to try", then
"the 'art' looks pretty bad... would benefit from some sort of image generation or higher detail".
Three variants (`src/client/HudLab`), switched by the STYLE button on screen, U on a keyboard, or the
`HudVariant` attribute; CLASSIC is the old HUD and controls (Hud.luau and Touch.luau hand over while a
variant is on): PRO after CarX Drift Racing 2 (a steering wheel, brushed pedals, a pull handbrake, a
chrome needle tacho, a drift-angle scale), MIDNIGHT after Midnight Racing: Tokyo (glass pedals and
slider, a see-through dial with a red needle, a timing bar, chevrons toward the slide), ARCADE after
Driving Empire (glossy toy pedals, a thumb pad, an LED speed dial, a coin cash pill the banked cash
flies into). All three: pedals give part throttle low on the plate, the needle springs and trembles
on the limiter, numbers roll, the screen edge glows with the chain, Arabic shouts on a 360, a natl and
x3. The art is SVG in `art/hud/<variant>/` rendered by `art/hud/render.py` (resvg; headless Chrome
hung on this Mac) and uploaded from Studio; ids in `HudLab/Art.luau`. Checked in Play with
ForceTouch: every variant drew and drove, the art loaded; type check clean. Round two: the owner liked
ARCADE's layout but "feels really ai, need deep UI" and wanted "the actual odometer and stuff", so
cluster variants on ARCADE's controls (`ArcadeControls.luau`, gauges in `Instruments.luau`), art
rendered by `art/hud/kit.py` (height maps lit as materials: rubber, leather, chrome, glass) and
`parts.py`: KRUZER (Tokyo Xtreme Racer 2025, the Land Cruiser's amber cluster: needle tacho with an LCD
speed and odometer, gear window, telltales, an inclinometer for the natl, a drift-angle gauge, a
dot-matrix drift display), STREET (Initial D Arcade Stage, CarX Street: white-face tacho, peak needle,
shift light, odometer drums, big italic gear and speed, red LED board, drilled pedals, a missile switch)
and KABRIS (the box Caprice's cluster: sweep speedometer, C-to-H tyre gauge, text lamps, sliding gear
pointer, walnut, a vacuum-fluorescent score display, a spinner knob, a pull knob). The odometer starts at
a per-car used mileage and adds the distance really driven; tyre heat is a slide's, cooling with grip. Round
three (2026-10-08): the owner's own mobile layout from the mockups (`LayoutD.luau`, `StreetHud.luau`) in
STREET's look, as STREET D (machined) and GHOST (smoked glass). On 2026-10-10 the owner kept STREET D and
had every other style removed, CLASSIC included ("remove all the other HUD layouts we have and keep
this"): `HudLab` is now the only HUD and phone controls, and Hud.luau and Touch.luau only hand over to it.
Then (same day) "make a couple variants of the same deisgn i can cycle through", "2 natl buttons that
show up one left one right" and subtler opacity: three finishes of layout D (`Finishes.luau`: STREET D,
SODIUM on the game's own UI_SYSTEM palette, CARBON), cycled by STYLE / U / Settings; NATL◀ and NATL▶ over
the steer buttons as the Q and E lean keys (the NATL toggle and lean slider are gone); every hit box the
shape you see; see-through faces and slots. Then "add some life to the UI as a whole, its very plain and
boring right now and blocky": versions of the whole HUD (`Versions.luau`, the UI button / Y): FLOW (no
plates, a small floating score with a grace-ring badge, a coin chip the banked cash flies into), SIDE (the
score as a combo meter down the right), BOARD (as it was). The owner liked FLOW; the live controls (ripples,
glints, glows, pedal strips) and the coin's spin and pop went ("remove all the wierd effects"). Open for the
owner: which finish, and the layout on a phone.

**`garage` (merged into `main` 2026-09-29 with `garage-r3`, and deleted).** The UI design system
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
and the pickup's pipe through its bumper.

**`garage-r3` (merged into `main` 2026-09-29, fast-forward, and deleted): garage round 3, branched
from `garage`.** Commits `0ee650f` (spec and plan) through the final pass ("Garage round 3: sun
strips rename, docs, final pass"); spec and plan in docs/superpowers, `2026-09-28-garage-round3-*`.
Exhaust tips modelled in Blender (rolled, quad pair, slash titanium, the new Big Oval) on EditableMesh
templates with a cylinder fallback and an optional uploaded-mesh path; pipes routed up into each car
(`riseM` per car); the windscreen strip moulded to each car's glass as 14 slats and renamed SUN STRIPS
in the panel (ids and the `decal` slot key unchanged). Final Play pass: drive-in, walk-in and two
drive-outs worked; every exhaust item's outlets sat on its tip mouths (0.12 mm at worst) and REV
flamed from them; strips shown on five cars; lift-off pops and flames on the same frame; specs 10189
passed, 14 failed (the VehicleRig baseline). The four tip meshes are uploaded (2026-09-29, `meshAssetId`, the slash with its heat
colours as a texture), so tips no longer use EditableMesh slots. Open for the owner: prices of the new items; once the owner's CarCatalog
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
