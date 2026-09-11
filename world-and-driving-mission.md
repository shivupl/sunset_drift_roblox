# Two-Part Mission — World Rework, then Driving Rework

Paste Part 1 as a normal message. Run the `/goal` line for Part 1. When it's
done and I've looked at it, paste Part 2 and run its `/goal`.

---

# PART 1 — The World

## What I want

A wide Gulf highway at golden hour that feels good to be on. Not a dark
empty test track and not a neon racing game. The word I keep coming back to
is cozy: warm light, open space, a road that invites you to go fast and
come back tomorrow.

You have latitude here. I'm giving you the constraints and the feeling —
the rest of the design is yours. If you think something I've specified is
wrong once you see it in the viewport, tell me and propose better.

## The road

- **Dual carriageway.** Two directions, several lanes each, with a wide
  central reservation between them. Overall roughly double the current
  width. It should feel like there's room to make a mistake.
- **No barriers anywhere.** Remove jersey barriers and guard rails
  entirely. Nothing between the road and the sand. Running wide should
  cost you speed and dignity, not the run.
- **Nothing on the map collides except the ground.** Lamps, palms, signs,
  rocks, everything: CanCollide false. I never want a drift ended by
  scenery.
- **Keep the straight, the transition pad and the curve** as the core
  layout, but widen them to match and give the whole thing more room.
- The road should read as maintained and used — worn tyre lines in the
  lanes, faded markings, tonal variation in the asphalt — not as a fresh
  grey ribbon.

## Lighting and time of day

- Golden hour, sun low and raking across the road. Long shadows are doing
  most of the work here, so make sure they land across the asphalt rather
  than away from the camera.
- Sky: warm gradient, orange and pink low, deepening upward. Dusty haze on
  the horizon so distance fades rather than ends.
- Lamp posts down both outer shoulders and along the central reservation.
  At golden hour they can be off or just warming up — your call on which
  looks better. Keep the existing 12-live-light manager for when I want a
  night variant.
- Everything must stay readable at speed. If the sun blows out the view
  from any camera angle, fix the exposure rather than adding effects.

## Planting and terrain

- **Palms down the central reservation.** Evenly spaced but not
  mechanically so — clumps, gaps, varied height and lean. This is the
  signature visual of the map, so spend time on it.
- Palms and low scrub along the outer shoulders too, thinning out with
  distance from the road.
- **Expand the terrain substantially.** The sand should run far enough that
  the horizon is haze, not an edge. Gentle undulation rather than a flat
  plane if you can do it cheaply.
- Rocks and scrub scattered by rule, seeded so every server is identical.

## Meshes

The primitive fallbacks look bad and I'm not shipping them. Pick and wire
up real meshes for palms, rocks, lamp housings, and anything else you judge
worth it. You already have candidates in AssetRegistry.candidates; find
better ones if those are weak.

Rules: no scripts shipped (build your own MeshPart from the MeshId, as you
already do), no real-world brands, low poly. Check triangle counts yourself
in Studio where you can and report what you find. Use your judgement on
what looks right — you can see the viewport, so use it.

If a paid Creator Store environment kit would get us dramatically closer
than free assets, say so with a link and a price and I'll buy it.

## Constraints

- 60fps target on mid-range Android with 30 cars. Report part and triangle
  counts as you go.
- Config-driven, built at runtime, nothing hand-placed. Same module
  structure.
- No per-frame loops over scenery. No unions. Don't touch vehicle code in
  this part.
- Report frame rate from a focused window, since the unfocused throttle
  gave a false 15fps last time.

## How to show me

Screenshots from the driver's camera at speed, looking down the road. Not
top-down layout shots. I'm judging how it feels to drive through, so show
me that view. Several, from different points on the map.

```
/goal the world builds at server start with no errors as a barrier-free dual carriageway with a planted central reservation, real meshes wired up for palms rocks and lamps rather than primitive fallbacks, golden-hour lighting with long shadows and haze, terrain extending to a hazed horizon, every scenery object CanCollide false, part and triangle counts reported, focused-window frame rate reported, driver-camera screenshots posted for my review, and WORLD.md plus TUNING.md updated and everything committed
```

---

# PART 2 — The Driving

Run this only after Part 1 is done and I've approved the look.

## What's wrong now

Three things, in order of how much they bother me:

1. **It loses control too easily.** Turning at speed breaks the rear loose
   on its own. I want a car that stays planted unless I ask it not to.
2. **Drift is too hard to get on purpose.** When I do want it, it should
   come easily and hold.
3. **Acceleration is sluggish and top speed is unbounded.** I want it to
   pick up quickly and then sit at a sensible ceiling.

## The feeling I'm after

The car should feel confident. Flat out on the straight is stable and
unremarkable — I can hold a lane and look around. The moment I deliberately
provoke it, handbrake or a hard flick, it goes sideways willingly and stays
there while I steer it. Coming back is predictable, not a coin flip.

Put differently: the difference between "driving fast" and "drifting"
should be a decision I make, not something the physics decides for me.

## Direction

- **Acceleration:** brisk off the line and through the midrange. Getting to
  usable speed should take a couple of seconds, not ten.
- **Top speed:** capped at something manageable — fast enough to feel
  quick, slow enough that the map and my reaction time keep up. Pick a
  number you think is right, tell me what you picked and why, and make it
  config.
- **Stability:** grip should give warning before it goes. No snap
  transitions from planted to spinning. Speed-sensitive steering limits are
  probably part of this.
- **Intentional drift:** handbrake and a hard steer flick at speed should
  break it loose reliably and quickly. Once sideways, holding it should
  feel like balancing, not fighting — countersteer must have authority at
  large angles.
- **Recovery:** predictable. Lift and straighten should bring it back
  without snapping.

How you achieve all that is yours. Tyre curves, steering limits, torque
curve, assist behaviour, grip bias — use whatever combination works. I care
about the result, not the mechanism.

## Rules

- Every value you touch stays in CarConfig with a TUNING.md note on which
  way to move it.
- **Do not build a scripted driver to test this.** A bot holding a slide is
  not the test. Verify only what has an objective answer — does handbrake
  break traction within X seconds, does the car spin from throttle alone at
  low steer, what's the 0-to-top-speed time. Report those numbers and stop.
- **Do not tune to satisfy a test.** If a measurement looks wrong but the
  car might be fine, say so and leave it to me.
- Steering lock stays realistic. If you believe it genuinely needs to go
  above 38°, argue for it with reasoning and I'll decide.
- Criterion 1 from Phase 0 must keep passing: handbrake and a flick both
  reach 20° of drift within 0.3s from 90–100 km/h.
- Don't touch the world code in this part.
