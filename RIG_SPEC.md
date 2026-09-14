# RIG_SPEC — the contract every car follows

A car is two separate things:

- **Rig**: the physics. One collision box, a hidden ballast, four
  suspension ray origins, four wheel hubs, the seat and the force
  actuators. Built from numbers by `src/server/RigBuilder.luau`. The sim
  (`src/shared/VehicleSim`) only ever touches the rig.
- **Body**: the look. MeshParts only, welded to named mount attachments on
  the rig. Built from meshes by `src/server/BodyBuilder.luau`. It never
  takes part in the physics.

Adding a car is an entry in `src/shared/CarCatalog.luau` plus its meshes.
No code changes. `src/shared/VehicleRig.luau` is this document in code:
names, geometry, validation and `handles()`. `src/shared/Tests/VehicleRig.spec.luau`
holds it to the numbers below.

---

## 1. Units and car space

Every catalog number is in **metres** and **kilograms**. Studs appear only
inside the builders (1 stud = `CarConfig.units.metersPerStud` = 0.28 m).

**Car space** is the frame body meshes are authored in:

| Axis | Direction |
|---|---|
| +X | right |
| +Y | up |
| −Z | **forward** (the way a Roblox CFrame looks) |

**Origin:** on the ground, directly under the centre of the collision box,
with the car **at rest**. At rest means sitting on its springs under its own
weight.

Two derived heights tie car space to the rig:

```
staticSag  = massKg × gravity / 4 / suspension.stiffness     (per spring)
restHeight = collisionHeight / 2 − staticSag + wheelRadiusM  (box centre above the ground)
```

The chassis carries an attachment, `BodyMount`, at the car-space origin:
chassis-local `(0, −restHeight, 0)`. For the sedan that is 0.868 m, and
0.867 m was measured in play.

## 2. Orientation and origin of the model

| Thing | Rule |
|---|---|
| Car model pivot | The Chassis (it is the Model's `PrimaryPart`). Its CFrame is the collision box centre. |
| Forward | Chassis `LookVector` (−Z local). |
| Up | Chassis `UpVector`. |
| Spawn | Spawn and reset place the box centre at `restHeight + spawn.spawnHeightM`, upright, and let it settle. |

## 3. Instance tree

```
Car_<player>          Model   PrimaryPart = Rig.Chassis, attribute CarId = "<catalog id>"
├─ Rig                Model
│  ├─ Chassis         Part    the ONLY colliding part; invisible unless spawn.showRig
│  │  ├─ RayOrigin_FL/FR/RL/RR   Attachment   suspension ray origins
│  │  ├─ BodyMount    Attachment   car-space origin
│  │  ├─ Center       Attachment   actuator attachment
│  │  ├─ SimForce     VectorForce  written by the sim every frame
│  │  ├─ SimTorque    Torque       written by the sim every frame
│  │  └─ EnterPrompt  ProximityPrompt
│  ├─ Ballast         Part    hidden, non-colliding; places the centre of mass
│  ├─ Hub_FL/FR/RL/RR Part    massless, invisible, non-colliding
│  │  ├─ WheelWeld    Weld    Part0 = Chassis; the sim writes C0 (drop, steer, spin)
│  │  └─ WheelMount   Attachment   the wheel centre
│  └─ DriverSeat      VehicleSeat  massless, non-colliding, entered by the prompt
└─ Body               Folder  MeshParts, each with a WeldConstraint to its mount's part
```

The names are constants in `VehicleRig` (`VehicleRig.CHASSIS`,
`VehicleRig.rayOriginName("FL")`, …). Code finds them through
`VehicleRig.handles(model)`, which errors with the name of the first
missing piece. Nothing searches for parts by name anywhere else.

## 4. The collision box (bounding box)

`rig.collisionSizeM = { width X, height Y, length Z }`.

- It is the car's only collision, and what hits walls, kerbs and the ground
  if the suspension bottoms out. Make it the car's real footprint, slightly
  inside the visible body, so contact looks right.
- **Its bottom face is the wheel centre height at full droop.** The
  suspension hardpoints (ray origins) sit `suspension.restLength` above the
  bottom face. So box height, wheel radius and rest length together set
  ground clearance: bottom of the box above the ground at rest =
  `wheelRadiusM − staticSag`.
- `wheelbaseM` must be shorter than the box length, and `trackWidthM` no
  more than 0.5 m wider than the box. `validate` checks both.

## 5. Wheels

**Order:** `FL, FR, RL, RR`. Front is −Z and left is −X.

**Ray origins**, chassis-local metres:

```
RayOrigin = ( ±trackWidthM/2,  −collisionHeight/2 + suspension.restLength,  ∓wheelbaseM/2 )
             left −, right +                                                front −, rear +
```

Each frame the sim casts from the origin along the chassis's −Up, ray length
`restLength + wheelRadiusM + rayMarginM`.

**Wheel radius convention.** `wheelRadiusM` is the rolling radius: the
distance from the wheel centre to the ground at the contact patch. It is
the radius the physics rolls on (gearing, drive force, wheel spin), and the
ray stops `wheelRadiusM` short of the ground. The tyre mesh's **outer
diameter must be 2 × wheelRadiusM**. `validate` rejects a largest wheel
piece more than 10% off. `wheelWidthM` sets the width of the skid marks.

**Hubs.** `Hub_XX` is the wheel centre. The sim sets
`WheelWeld.C0 = CFrame(RayOrigin − (0, drop, 0)) × steer yaw × spin about X`,
where `drop` is the spring's current length. At rest the hub is exactly the
car-space wheel centre `(±track/2, wheelRadiusM, ∓wheelbase/2)`.

**Wheel space** (for `body.wheelPieces`): origin at the wheel centre, axle
along X, authored as a **left** wheel with its **outer face toward −X**.
The builder mounts the same pieces on the right-hand hubs turned 180° about
Y. Never model separate right wheels.

## 6. Mass, centre of mass, seat

| Field | Meaning |
|---|---|
| `rig.massKg` | Total mass (the assembly mass equals it exactly; the seated driver adds about 12 kg on top). |
| `rig.shellMassFraction` | Share of the mass in the collision box, between 0 and 1. The rest goes into the ballast. |
| `rig.centerOfMassM` | Centre of mass from the box centre, **car space** (so forward is −Z). The ballast is placed to put it there. |
| `rig.seatM` | Seat centre from the box centre, car space. A seated Roblox avatar's head, hair included, is 1.2 m above the seat centre (measured), so seat height + 1.2 m must stay under the roof. |

## 7. The body

Every body part is a **MeshPart** made by `AssetService:CreateMeshPartAsync`
from a bare mesh id, so no store model or script ever enters the game. Each
part is set to:

- `Massless = true`
- `CanCollide = false`, `CanQuery = false`, `CanTouch = false`
- `Anchored = false`, `EnableFluidForces = false`
- welded with a `WeldConstraint` to its mount's part

It adds nothing to the physics. Built both ways in Studio, the sedan is
1600 kg at (0, −0.35, −0.2) m and the hatch 1250 kg at (0, −0.2, −0.15) m,
identical with and without the body. The suspension rays exclude the whole
car model.

A **piece**:

| Field | Meaning |
|---|---|
| `name` | Unique within its list. Wheel pieces become `<name>_FL` and so on. |
| `meshId` | The mesh asset id (required). |
| `textureId` | Optional colour map; nil or 0 colours the mesh instead. A textured piece ignores `paint`. |
| `sizeM` | Size of the piece's **bounding box** in metres, `{X, Y, Z}` of the mount's space. The mesh is scaled to it. |
| `offsetM` | Centre of that bounding box: car space for `pieces`, wheel space for `wheelPieces`. |
| `rotationDeg` | Optional extra rotation `{X, Y, Z}` degrees (applied Y, X, Z) for a mesh not authored facing −Z. |
| `paint` | `true` takes `body.paint` (the car's colour). |
| `color`, `material`, `transparency` | Otherwise. |
| `castShadow` | Default true. Set false on lamps and small trim. |

`body.pieces` mount to `BodyMount`; `body.wheelPieces` mount to every
`WheelMount`. A mesh that fails to load gets a plain box of the same size
and a warning, so a bad id shows as a grey block, never as nothing.

## 8. Handling: shared plus overrides

`CarConfig` is the handling **every car shares**: suspension, tyres,
drivetrain, steering, two-wheel, camera. Its `body` table holds only aero
and rolling losses, plus zero placeholders for the geometry.

`VehicleRig.configFor(CarConfig, entry)` builds the config a car drives on:

1. A deep copy of `CarConfig`.
2. `entry.tuning` deep-merged over it. Dictionaries merge field by field;
   **arrays replace whole** (so `gearRatios = {…}` swaps the whole set).
3. The rig's geometry and mass written into `body`.

`ConfigLoader.forCar(id)` caches that per car and rebuilds it on every
reload (L key). Handling changes apply to a car you are driving. Changes to
a rig's geometry or the body show on the next car built: get out, or change
car.

## 8b. Scale

`entry.scale` (optional, 0.5 to 2, default 1) makes a car bigger or smaller
without re-measuring it. The rig and body numbers in the entry stay as
measured off the meshes. The builders multiply every length by `scale`:
the box, centre of mass, wheelbase, track, wheel radius and width, seat,
and every piece's size and offset. Mass does not change.

A bigger car would drive differently for size alone, so `configFor` also
rescales the terms that depend on size and nothing else
(`VehicleRig.sizeCompensation`):

| Term | Factor | Keeps |
|---|---|---|
| `drivetrain.finalDrive` | × k | force at the tyre, and rpm at a given speed |
| `tires.slipModel.wheelInertia` | × k² | wheel spin-up |
| `tires.slipModel.handbrakeTorque` | × k | locking force at the tyre |
| `body.shellMassFraction` | ÷ k² | yaw, roll and pitch inertia |
| `twoWheel` lift, lean and balance torques, spring, instability, roll and landing damping | × k | natl against gravity's k-times-longer lever |

Grip, springs, aero, steering and the throw controller are not touched.
Measured at 1.2 they need no help (§11).

The two current cars are at 1.2. At the pack's real 4.9 m the sedan read
small next to the wide lanes, and a seated Roblox avatar, whose head
(hair included) is 1.2 m above the seat centre, came through its 1.37 m
roof. At 1.2 the sedan is 5.9 m with a 1.65 m roof, and the seat sits
0.35 m off the ground.

## 9. Choosing a car

Players start on foot with the **spawn menu** open (`src/client/SpawnMenu.luau`).
It has one card per catalog entry, sorted by `order` then `displayName`,
showing the paint colour, `blurb`, length, mass and a SPAWN button. The
button fires the `SpawnCar` remote. The server checks the id, a cooldown
(`spawn.spawnCooldownSeconds`) and whether a spawn is already building. It
then replaces the player's car with that one in their bay slot, sets their
`CarId` attribute and seats them. M or the CARS button reopens the menu.
`spawn.autoSpawnOnJoin = true` brings back a parked car at join instead.

When a car is respawned any other way (the attribute changing, a car that
fell out of the world), a player gets the first of these that names a
catalog car:

1. Their `CarId` player attribute (the future garage sets this).
2. `CarConfig.spawn.carId`.
3. `CarCatalog.defaultCarId`.

Changing the attribute swaps the car at once if it is parked, or when they
get out if they are driving. An unknown id falls back to the default. An
entry that fails validation is reported at server start and never spawns
(the player gets the default).

## 10. What a new car must supply

One entry in `CarCatalog.cars`:

```lua
mycar = {
	displayName = "My Car",
	blurb = "One line for the spawn menu.",   -- optional
	order = 3,                               -- optional: position in the menu
	rig = {
		massKg = 1450,
		collisionSizeM = { 1.85, 1.2, 4.6 },   -- width, height, length
		centerOfMassM = { 0, -0.3, -0.15 },    -- from box centre, car space
		shellMassFraction = 0.35,
		wheelbaseM = 2.7,
		trackWidthM = 1.56,
		wheelRadiusM = 0.33,
		wheelWidthM = 0.22,
		seatM = { -0.4, -0.4, -0.1 },
	},
	body = {
		paint = Color3.fromRGB(240, 240, 240),
		pieces = { { name = "Shell", meshId = 123, sizeM = {...}, offsetM = {...}, paint = true }, ... },
		wheelPieces = { { name = "Tyre", meshId = 456, sizeM = { 0.25, 0.66, 0.66 }, offsetM = { 0, 0, 0 } }, ... },
	},
	tuning = { suspension = { stiffness = 30000 } }, -- optional
}
```

Checklist:

1. **Meshes.** Upload them, or use public store mesh ids with no brands.
   Author the body facing −Z. Author the wheel as a left wheel, axle along
   X, outer face −X. The tyre's diameter is the rolling diameter.
2. **Measure in car space.** Find the four wheel centres on the model.
   Their midpoint is the car-space origin in X and Z, and the ground is one
   tyre radius under them. `wheelbaseM` and `trackWidthM` are the distances
   between the centres. For each piece, record its bounding-box size and its
   centre relative to that origin, scaled to metres. `CarCatalog.luau`
   documents how the two current cars were measured off their pack.
3. **Rig numbers.** Mass. A box that sits just inside the body. A centre of
   mass low and slightly forward. A seat that keeps the driver's head under
   the roof. If the car is the right shape but the wrong size against the
   world, set `scale` rather than re-measuring (§8b).
4. **Tuning.** Only what differs from the shared handling. A much lighter
   or heavier car wants springs scaled with its mass, so it sits at the same
   sag.
5. **Check.** Run the spec suite (`VehicleRig.spec` validates every entry).
   Set `CarConfig.spawn.showRig = true` to see the box, hubs and seat over
   the body, set your `CarId` attribute to the new id, and drive it.

## 11. Verified in Studio (Sep 2026)

| | Before (Phase 0 CarBuilder) | After (rig + body) |
|---|---|---|
| Assembly mass (with driver) | 1611.74 kg | 1611.74 kg |
| Centre of mass, chassis-local | (0, −0.345, −0.200) | (0, −0.348, −0.200)¹ |
| Box centre above the road at rest | 0.867 m | 0.867 m |
| 0–100 km/h, two runs | 3.61, 3.62 s | 3.68, 3.65 s |
| Planted corner at 94 km/h, steer 0.35 | 15.1 °/s yaw, 2.9° drift, 3.2° roll | 14.8 °/s, 2.8°, 3.2° |
| Flick from 100 km/h, two runs | 1 spin, 55/56 km/h after | 1 spin, 55/56 km/h after |

¹ The seat moved 0.45 m down so the driver sits inside the new body. The
12 kg driver moves with it. Nothing else changed.

The sedan's natl on a lean tap at 105 km/h lifts to 43° and is back on four
wheels at 2.7 s; Phase 0 was 41° and 2.5 s. The hatch was added with a
catalog entry only. Before `scale`:
- **Launch:** 0–100 in 3.15–3.18 s.
- **Natl:** a tap lifts it to 49° and it is down at 2.9 s.
- **Lever throw:** from 110 km/h it completes a 360 at 2.5 s.
- **Rest:** 0.632 m, which is exactly the `BodyMount` prediction.

**At scale 1.2** (Sep 2026). The same protocol with Studio focused,
compared with the unscaled sedan above:

| | Scale 1 | Scale 1.2 |
|---|---|---|
| Length / roof | 4.9 m / 1.37 m | 5.9 m / 1.65 m |
| Box centre above the road at rest | 0.867 m | 1.063 m |
| Seated head top vs roof | 0.25 m through it | 0.16 m under it |
| 0–30 / 0–100 km/h | 1.03 / 3.65–3.68 s | 1.10 / 3.66–3.67 s |
| Planted corner at 94 km/h | 14.8 °/s, 2.8° drift, 3.2° roll | 14.9 °/s, 2.8°, 2.8° |
| Flick from 100, two runs | 1 spin, 55/56 km/h after | 1 spin, 54/55 km/h after |
| Lever from 110 | 360 at 2.55 s, 61 km/h at 4 s | 360 at 2.57/2.58 s, 60 km/h |
| Natl tap at 105 | 43°, down at 2.7 s | 42°, down at 2.7 s |

Before the two-wheel torques joined the compensation, the scaled natl only
reached 35° and was down at 2.5 s: the other size terms alone left it weak.
The hatch at 1.2 against its unscaled numbers:
- **Launch:** 0–100 in 3.20 s against 3.15–3.18 s.
- **Natl:** 48° and down at 2.9 s, against 49° and 2.9 s.
- **Lever 360:** 2.53 s against 2.52 s.

The hatch is a low car, so a seated avatar's head still shows over its roof.

**The pickup and the cruiser** (Sep 2026) were added the way §10 says: a
catalog entry and a mesh each, no code. Each body is one textured store mesh
with empty wheel arches and no brand, measured in Studio for its arch
positions, well spacing, width and ground clearance. The source and the
measurements are in the comment above each entry. The rig contract held on the
first build: rest heights came out at 1.085 m and 0.864 m (predicted 1.085 and
0.859), and both masses matched `massKg` plus the 12 kg driver. Their
handling personalities, and the numbers behind them, are in TUNING.md under
"Car personalities".

A body piece with a `textureId` shows its texture and ignores `body.paint`.
Paint only colours untextured pieces, so both of these cars show their mesh's
own colours. Their `paint` value is used only by the spawn-menu swatch.
