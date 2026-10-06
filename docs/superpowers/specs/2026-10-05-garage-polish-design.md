# Garage polish: camera focus, auto-preview, sub-tabs, sound and motion

Date: 2026-10-05. Branch `garage-polish`, on top of `garage-tyres-flames`.

## Why

The owner, 2026-10-05: "now for the garage. it works well but can you overall
enhance the ui as well as user facing functionality. for instance, when
selecting exhaust tips or flames, it should like zoom into that part and for
the flames, should do a quick play of it right. thats just an example but
overall improve and polish the garage." Asked to choose, the owner picked
**panel layout** and **sound and motion** on top of the camera focus and
auto-preview; item details and new tiles were left out. "Write spec and
implement, do only light testing."

This reverses one line of the 2026-09-28 brief ("No zoom, no camera
presets"): the owner now wants the camera to go to the part.

What stays: every change previews live on the car, nothing is charged
without the confirm sheet, owned against unowned stays unmistakable
(UI_SYSTEM.md "Shop items"), and the panel works at phone size.

## 1. Camera focus (GarageView, GarageConfig.shots)

A **shot** is where the camera looks. `full` is today's framing: the whole
car, the turntable turning slowly. A close shot turns the turntable to
show one side of the car, holds it there, and moves the camera in toward a
point on the car:

| Shot | Car faces the camera | Aim | Used by |
|---|---|---|---|
| full | turning (as today) | the whole car | MY CARS, PAINT · COLOUR |
| side | the right side, square on | the side windows | PAINT · TINT |
| wheel | the right side, a little from the front | the front-right hub, low and close | WHEELS · RIMS, TYRES |
| head | front three-quarter | the front-right corner | LIGHTS · HEADLIGHTS |
| tail | rear three-quarter, brake lights on | the rear-right corner | LIGHTS · TAIL LIGHTS |
| windscreen | the front, from above | the windscreen's top | SUN STRIPS |
| plate | the rear | the rear plate's height | PLATES |
| exhaust | rear three-quarter (REV's old angle) | the exhaust outlets | EXHAUST · TIPS, FLAMES |

- A shot is data in `GarageConfig.shots`: `faceDeg` (which way the car faces
  the camera: 0 the nose, 90 its right side, 180 the rear), the aim
  (`hub`, `outlets`, or a point in the body's box as fractions), `distanceM`
  (eye to aim), `eyeHeightM` (above the turntable), optional `fovDeg`, and
  `brake` (brake lights on).
- The camera stays on the full framing's bearing and only comes closer, so
  it never meets a wall: the eye is the aim point moved `distanceM` back
  toward the full framing's eye, at `eyeHeightM`. The panel offset
  (`screenOffset`) applies as before.
- A move takes `UITheme.motion.camera` (0.8 s, Sine in-out) from wherever
  the camera was; the turntable eases to its angle meanwhile. The aim
  follows the car live, so a car switch mid-move lands right.
- In a close shot the car does not turn. A drag goes back out to `full` (the
  player wants to look round); tapping the sub-tab again goes back in.
- A missing part (no exhaust outlets) aims at the shot's box point instead.
- `GarageConfig.views` maps each category and sub-tab to its shot.

## 2. Auto-preview (GaragePanel)

- **Tips or a flame tapped:** the exhaust shot, then once it has arrived a
  burst with the exhaust and flame showing (ExhaustPops.rev). A new tap
  starts a new burst at once (a new burst already replaces the old one).
  REV stays, on the sub-tab row.
- **A headlight colour tapped:** the headlights blink twice
  (`GarageConfig.headFlash`).
- **TAIL LIGHTS:** the tail shot has the brake lights on.

## 3. Panel layout: sub-tabs and shorter cards

- A category with more than one set of items gets a row of sub-tab chips
  under the category chips: PAINT (COLOUR, TINT), WHEELS (RIMS, TYRES),
  LIGHTS (HEADLIGHTS, TAIL LIGHTS), EXHAUST (TIPS, FLAMES; REV at the row's
  end). One grid per sub-tab; the title rows they replace go. PAINT's finish
  pills stay above the colours. Each category remembers its sub-tab for the
  visit; an unbought preview survives switching, as it survives switching
  category today.
- The tyres' note names the drivetrain: "Rear-wheel drive: <the showing
  tyre's blurb>".
- Item cards are shorter: the badge (ON CAR, OWNED, price) sits on the
  tile's top-right corner instead of a row of its own, and the tile's dots
  sit at its left. Plates keep the badge row (the plate art fills the tile).

## 4. Sound and motion

- **Sounds** (`GarageConfig.sounds`, client `Garage/GarageSounds`): `tab`
  (a category or sub-tab), `tap` (an unowned item previewed), `fit` (an
  owned item fitted), `buy` (a purchase), `error` (an error message). Played
  for this player only, preloaded as Sounds, each with a volume; a sound
  that fails to load is skipped.
- **Motion** (`GarageConfig.feel`): a card shrinks to `pressScale` while
  pressed and pops to `popScale` and back when its item is fitted or
  bought; after a purchase the cash readout counts down over
  `cashCountSeconds`; a new grid slides up into place
  (`UITheme.motion.panel`).

## 5. Testing (light, the owner's call)

- Spec `GarageConfig.spec`: every view names a shot; every shot's numbers
  are in range; sub-tab ids are unique; every sound has an id and a volume
  in 0..1.
- Type check (`scripts/analyze.sh`) on the touched files.
- Play: screenshots of a few shots, a flame tapped, and the sub-tab rows.

## Files

| File | Change |
|---|---|
| `src/shared/GarageConfig.luau` | `shots`, `views`, `focus`, `headFlash`, `sounds`, `feel`; `revPresent` folded into the exhaust shot and `focus` |
| `src/client/Garage/GarageView.luau` | shots: `focus`, the close framing, the eased move, hold and drag-out, brake lights; `present` is the exhaust shot; `flashHeadlights` |
| `src/client/Garage/GaragePanel.luau` | sub-tabs, shots per view, auto-preview, cards with the badge on the tile, sounds, press and pop, cash count, grid slide |
| `src/client/Garage/GarageSounds.luau` | new: preload and play the panel's sounds |
| `src/shared/Tests/GarageConfig.spec.luau` | new |
| `UI_SYSTEM.md`, `TUNING.md`, `BRANCH_STATUS.md` | the sub-tab rule, the badge on the tile, GarageConfig rows, the branch |
