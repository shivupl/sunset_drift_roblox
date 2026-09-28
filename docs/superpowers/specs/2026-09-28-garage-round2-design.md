# Garage round 2: exhaust standard, flames, drive-in, polish

Asked by the owner on 2026-09-28 after the garage MVP: "continue to perfect
it ... make sure the exhaust tips system as a whole works well, as in
formatted uniformly throughout cars so when i add exhaust flames it works
and looks good, exhausts should be attached in some sense to the car - not
floating. make some really refined and polished exhaust flame animations.
also add the ability to not only walk in but drive a car in as well (either
one). continue to create tests, and polish customisations, don't need to add
too too many tho. focus on perfecting core right now."

Builds on `2026-09-28-garage-design.md`. The parked `car-backfire` branch
(BRANCH_STATUS.md) is the lesson: its triggers and relay worked; its flame
(0.09 s puffs of one texture) was judged poor. Keep the idea, replace the
look.

## 1. One exhaust standard for every car

Today `CarCosmeticMounts.exhaust` is one centre point and a spread for the
aftermarket tips only; the factory exhaust has no defined outlet, and the
tips float behind the bumper.

**Decision: every car defines its exhaust in one uniform shape.**

```
exhaust = {
    stock = { { posM = {x, y, z} }, ... },   -- the car's own pipe mouth(s)
    tips = { posM = {x, y, z}, spreadM = n,  -- where aftermarket tips go
             pipeLengthM = n },              -- pipe run forward into the body
    bumperZ = n,                             -- the rear bumper's face at tip height
}
```

- **Stock outlets** are measured on each car's real tailpipe mesh (by eye in
  Studio, like the plates). A car whose model has no visible pipe gets a
  plain factory pipe built at its outlet, so every car has at least one.
- **Aftermarket tips are attached:** each tip is the tip cylinder, its bore,
  and a pipe of the same run going forward (`pipeLengthM`) up under the
  bumper, ending hidden inside the body; the tip's mouth sits 2–5 cm past
  `bumperZ`. No gap between tip and car from any camera angle at driving
  distance.
- **Outlets are the flame contract.** Whatever exhaust is on the car (stock
  or tips), the client puts one Attachment named `ExhaustOutlet` per pipe
  mouth under the car's body, its +Z (Axis/LookVector per the code comment)
  pointing out of the pipe. Flames and any future exhaust effect use only
  these. Switching the exhaust item moves the outlets.
- A spec holds every catalog car to the standard: at least one stock
  outlet, tips behind the bumper by 2–5 cm, pipe length positive, all
  outlets at or behind the rear axle and below the boot line.

## 2. Flames

- **When:** from the driver's sim, as `EngineAudio` already decides pops:
  a burst on a fast lift-off above the crackle rpm, a single pop on an
  upshift from high rpm, random pops on the limiter. Each pop fires a flame
  at every outlet, synchronised with its sound.
- **Who sees it:** everyone. The driver's client plays it at once and sends
  the event (car, pop count) to the server, which checks the sender is the
  seated driver, rate-limits (config), and relays it to every other client.
  Same shape as the lamp relay in `CarControls`.
- **Look (the bar is "really refined and polished"):** layered, all from
  Roblox's built-in particle textures (no uploads):
  1. a short blue-white core cone at the mouth (the hot gas),
  2. an orange-yellow flame tongue that stretches, licks upward slightly and
     tapers (size and transparency sequences, drag, a little acceleration
     up),
  3. a few sparks thrown back,
  4. a faint dark smoke wisp after,
  and a brief glow on the tip itself (the tip part's colour and emission),
  **no Light instance** (the live-light cap). Bursts via `Emit`, never a
  running emitter. Scaled by car speed (flames trail back at speed).
- **Per exhaust item:** a flame profile in `CosmeticsConfig` (size, core
  colour, flame colour, pop multiplier): factory small and orange; sport
  tips larger; burnt titanium with a blue-violet core. Tunables in config.
- **Preview:** the garage EXHAUST category gets a `REV` button that plays a
  burst of pops and flames on the turntable car.

## 3. Driving in

- The doorway zone reacts to the player driving too: when the car's chassis
  crosses into the garage at low speed (config, ~20 km/h), the view opens
  with that car.
- **Server:** a `GarageAction("driveIn")` remote: checks the sender is the
  seated driver and the car is inside the doorway zone and slow; unseats
  them and parks the car on a drive-out spot on the apron, facing away
  from the door, anchored while parked.
- **Leaving** after a drive-in seats the player back in their car on that
  spot, facing out, ready to drive away (`GarageAction("driveOut")`); a
  walk-in leave stays as today.
- The preview is still a fresh static car; the real car shows the new look
  the moment it is equipped (Look attribute).

## 4. Polish and options

- A handful more options, not many: 4 paints, 2 rim finishes, 2 decals,
  and window tint (glass colour and transparency, per car, under PAINT as a
  third row).
- Tests: a server-side spec for `Economy`'s encode/readProfile (raw merge,
  unknown cars, stock clears) against FakeDataStore; the mounts spec;
  catalog and flame-profile integrity.
- Every option checked on at least three cars in screenshots; anything that
  looks wrong on a car is fixed or hidden for that car.

## Constraints (unchanged)

Cosmetic only; config-driven; live-light cap (no new Lights outside the
view); report parts and triangles; never touch VehicleSim or scoring; the
owner's uncommitted rig files untouched.
