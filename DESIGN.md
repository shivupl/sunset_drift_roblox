# DESIGN — why the car is built this way

## Rig and body
Phase 2 split every car into a rig and a body (RIG_SPEC.md). The rig is the
physics below, built from numbers; the body is massless, non-colliding
MeshParts welded to named attachments on it, built from meshes. The sim
only ever reads and writes the rig, so a car's look can change without
touching how it drives, and a new car is a catalog entry plus meshes. The
body adds nothing to the assembly: its mass and centre of mass measured the
same with and without it.

## One rigid body, raycast suspension
The car is a single physics assembly: a box, a hidden ballast, four wheel
hubs (which carry the body's wheel meshes) and a seat. Each corner fires a ray straight down (in the body frame)
from a hardpoint. The distance to the ground gives that corner's spring
compression, and the spring plus damper force is applied at the hardpoint.
Weight transfer is not scripted: when the car pitches sideways the outside
rays shorten, those springs load up, the inside springs unload, and the tire
model sees those loads. That is the "heavy sedan leaning into a slide" look.

We chose raycasts over SpringConstraint + CylindricalConstraint wheels
because Roblox's built-in tire friction is close to on/off and cannot give a
grip curve that peaks and then fades. With visual-only wheels every newton
of tire force comes from our own model. It is also one body instead of five
per car, which matters on phones, and one body means network ownership is
a single handoff.

The cost: wheels do not physically touch curbs or bumps. Phase 0 is a flat
road, so nothing is lost yet. Bump stops on the springs keep the body from
sinking through the wheels under hard loads.

## Gravity
Roblox gravity is 196.2 studs/s². At our scale (0.28 m per stud) that is
5.6 times real gravity. If the tire model used real spring loads under that
gravity the car would corner 5.6 times too hard and never slide, and body
roll and two-wheel balance would be wrong. Changing workspace gravity would
break characters and everything on foot in later phases, so the sim applies
an upward counter-force of mass × (196.2 − g/0.28) on the chassis only.
`CarConfig.units.gravity` sets g; 9.81 is honest, 54.9 turns the correction
off for A/B comparison. Parked cars keep sitting on their springs because the
server runs the same sim with zero input until they settle, then anchors them.

## Units
Config is in kilograms, metres, newtons, seconds. One Roblox mass unit is
treated as one kilogram (densities are set so the assembly mass equals the
config mass; verified 1600.0 in Studio). Forces are divided by 0.28 on the
way out, torques by 0.28².

## Tire model
For each grounded wheel we take the contact patch velocity, split it into
along-the-wheel and across-the-wheel, and compute the slip angle. Lateral
grip rises linearly to a peak slip angle, then decays to a sliding floor.
That fade is the whole point: past the peak the rear gives up some grip but
not all, so a slide is a balance you can hold rather than a switch that
flips. Front and rear have separate grip, peak, fade and floor numbers.

Longitudinal and lateral share a friction circle. Drive and brake demand is
taken first because the driver commands it; whatever is left of the circle
goes to lateral. So throttle in a slide eats rear lateral grip (more angle,
eventually a spin) and lifting gives it back (the car straightens). If
longitudinal demand exceeds the circle the wheel is spinning or locked and
both components drop to the sliding level.

Tire forces act at ground level and spring forces at the hardpoints, so the
lateral force times the centre-of-mass height is a real roll moment that
loads the outside springs in a slide.

**The slip model (wheels that spin).** The tyre above has no wheel speed:
drive and brake demand either fit in the friction circle or the tyre jumps
to its sliding level, so throttle cannot dial a slide, a locked wheel is a
grip multiplier and a spinning rear pushes along the nose only because a
flag says so. `VehicleSim/Wheel.luau` replaces that, behind
`tires.slipModel.enabled` so the old tyre stays as the A/B.

Each wheel carries an angular velocity. Engine torque through the gearing
and the diff, the brakes, engine braking and the handbrake are torques on
it; the tyre's longitudinal force pushes back. The force comes from two
slips together, the slip angle and the slip ratio, each normalised by where
it peaks and combined into one slip that runs through the axle's existing
grip curve. With no slip ratio that is exactly the old tyre, which is why
every lateral number the car was tuned on carried over. The force points
the way the combined slip points: a spinning rear in a slide gives most of
its grip to pushing along the nose and little to holding the tail, a locked
rear gives most of it to dragging. Grip also falls off with load (0.08 per
unit over static), so weight moving across and along the car changes the
balance. The engine turns with the rear wheels' own spin, so wheelspin
revs it to the limiter; gear changes still go by road speed. The spin is
integrated in 3 ms substeps with a linearised implicit update, because the
tyre's longitudinal stiffness is far too stiff for an explicit 60 Hz step;
the spec checks it settles at 14 fps as well.

What that let go of, and what it did not. The flick's rear grip cut, a
stand-in for weight transfer, is weaker (0.7 instead of 0.35), because real
weight transfer and wheelspin now swing the tail: at the old cut a
part-throttle flick rotated 85 to 89 degrees against the old car's 72 to 74.
The handbrake is now a brake torque on the rears (700 Nm) with a lighter
grip cut (0.6). A full physical lock (2,500 Nm) was tried first and is what
a real handbrake does, but it dragged a lever 360 from 110 down to 72 and
cost every throw 4 km/h. The slide momentum relief below is still needed:
with it off, pure physics took the held slide from 97 to 70, the chain from
96 to 76 and the 360's exit to 70. And the throw controller stays at full
strength: turning its torque caps down to 9,000 and 35,000 Nm spread the
chain's angles from 29-36 to 24-42 degrees, dropped the held angle from 41
to 33, slowed the 360 to 2.68 s and left the car 20 degrees sideways a
second after it. It is what makes the tricks repeatable.

Measured on the highway with the same harness inputs, old tyre against the
slip model on its committed values:

| Test | Old tyre | Slip model |
|---|---|---|
| Launch 0-30 / 0-70 / 0-100 | 1.03 / 2.62 / 3.95 s | 1.10 / 2.57 / 4.03 s |
| Full lock at 100 km/h, peak drift (planted) | 3.6° | 3.5° |
| Handbrake pull to 20° | 0.27 s | 0.27 s |
| Hands-off catch after a slide | 0.82 s | 0.53 s |
| Part-throttle flick from 100 km/h, peak | 72-74° | 76-81° |
| 41° slide held on the gas, 4 s from 98 km/h | loses 2 km/h | loses 6 km/h |
| Throw and four transitions on the gas from 96 | loses 9, 29-37° | loses 5, 29-36° |
| Lever 360 from 110 | 2.57 s, exit 85 | 2.60 s, exit 85 |
| Lever 720 from 110, exit | 63 | 62 |
| Two-wheel tap at 102 km/h | 42° at 0.61 s, down 2.6 s | 42° at 0.58 s, down 2.4 s |
| Two-wheel lean held 5 s | 54°, no topple | 54°, no topple |
| Full brake | 33 km/h per s | 33 km/h per s |

**Launch control.** With real wheels the old traction control fought the
tyres. It waits for a spin and winds the throttle back, but never below
0.7, and full launch torque is about twice what the rears can take; on the
old tyre a spin cost a little grip, on the slip model it drops the tyre to
its sliding floor. Measured: wheelspin from the first frame, 7 m/s² for the
first second, 0-30 in 1.20 s. So under 120 km/h, pointing straight, the
throttle is now capped at the torque the rear tyres can put down right now
(their load, grip, load sensitivity and drive grip at the peak slip,
through the gear) plus the torque it takes to spin the wheels and the
engine up with the car. Leaving that inertia out capped the launch 18%
short: no spin at all and 0-100 slower than before. The owner still found
the launch flat, and at that point it was at the rear tyres' limit, so the
rear's drive grip went from 1.55 to 1.9 and the shift from 0.15 to 0.08 s
(it left a quarter-second flat spot at the 1-2). The first half second is
still the softest part of a launch: the rears only carry their static load
until the car squats onto them.

**Two bugs found on the way.** A flick counted its window from the moment
the wheel first went hard over, and only reset on a change of direction,
so after any hard steer one way (a lane change, a 360) a later flick
starting the same way found a stale window and never tripped: it rotated
4 degrees instead of 76. This was in the old model too. The window now
runs from the last moment the wheel was hard over. And a reset (the R key,
the bay respawn) zeroes the car's velocity but left the slip model's wheels
spinning, so they drove the car off the spot at up to 11 km/h; a position
jump far bigger than the car could have travelled now stops them.

Measured after both, same harness:

| Test | Before launch control | Now |
|---|---|---|
| 0-10 / 0-30 / 0-50 / 0-70 / 0-100 | 0.46 / 1.20 / 1.83 / 2.75 / 4.1 s | 0.43 / 1.02 / 1.52 / 2.28 / 3.64 s |
| Speed 0.5 s after launch | 11 km/h | 12 km/h |
| Rear wheelspin during a launch | most of the first second | none |
| 41° slide held on the gas, 4 s | loses 6 | loses 6-7 |
| Chain from 96 | loses 5 | loses 5 |
| Flick after a right-hand 360 | 4° (the bug) | 71-76° |
| Lever 360 from 110, exit | 85 | 83 |
| Lever 720 from 110, exit | 62 | 57 |
| Power-over at 50 km/h, full lock | not measured | 0.8° |
| Two-wheel tap / 5 s hold | 42°, down 2.4 s / 54° | 41°, down 2.5 s / 53° |

**Slide momentum.** A slip-angle model turns every degree of slide into
drag: a tyre sideways to its travel pushes almost straight back against the
car. A real hajwala sedan sideways at 100 km/h carries its speed for
hundreds of metres, because the rears are spinning (their friction runs
mostly along the rolling direction) and sliding rubber grips less than
gripping rubber. The owner asked for exactly that: Tanteel chains and Sefty
360s that do not scrub the car to a halt, without ice.

So each step the sim splits the tyres' lateral forces into the part along
the car's velocity (the drag) and the part across it (what bends the path),
and hands back a fraction of the drag as a force at the centre of mass. The
across part and every yaw moment are untouched, which is why steering,
throws, holds and catches measure the same as before. The fraction
(`Tire.scrubRelief`) is zero below 10 degrees of drift, so cornering and the
grip limit are unchanged; zero below 30 km/h, so a slow slide still stops;
never all of the scrub; higher with the lever in, because a lever 360 sits
on locked rears; and the sim never lets it make the tyres push the car on,
so a slide can hold its speed on the gas but cannot gain it.

Measured on the highway, same inputs, before and after (slide 0.38, lever
0.6):

| Trick | Before | After |
|---|---|---|
| 43° slide held on the gas, 4 s from 98 km/h | 73 km/h | 97 km/h |
| Throw and four transitions on the gas from 96 km/h | 69 km/h | 87 km/h |
| Lever 360 from 110 km/h, exit | 69 km/h in 2.57 s | 85 km/h in 2.57 s |
| Lever 720 from 110 km/h, exit | 40 km/h | 63 km/h |

Drift angles through the chain (29 to 37 degrees) and the spin time did not
change. Lifting still scrubs: the held slide falls from 97 to 89 km/h in two
seconds hands off and straightens by itself, and a full brake takes 58 to
20 km/h in 1.2 s.

## Drivetrain
Torque curve by rpm, automatic gearbox, a differential that blends between
open and welded, on whichever axles the car drives (below). With the slip
model the driven wheels spin and the engine turns with them; the legacy
tyre reports when demand exceeded grip and the engine rpm floats up. Engine braking on
lift shifts weight forward, which is what makes a lift-and-flick transition
swing the rear across.

There is no manual shift and no clutch-kick button; the throttle stab
after a feather does its job mid-drift (below). The button was cut because
it never earned its place: the handbrake initiates a slide faster and is the
control a hajwala driver actually uses, and a second initiation method meant
a second set of grip numbers to keep honest. Reverse is not a selectable
gear either. Holding the brake for reverseHoldSeconds after the car has
stopped engages it and any throttle leaves it, so braking hard to a
standstill cannot drop the car into reverse the moment it settles.

## Drivetrains, drift styles and the feather

The owner asked (2026-10-05) for the drift to "differ slightly depending on
the drivestyle of the vehicle (awd,rwd,fwd,etc)", with "a couple different
styles (multiple for each)" to try in game, and for "the ability to kick off
the exhaust during a drift where the flames would also flutter like in
drifting videos". Research and spec in docs/superpowers/specs
(`2026-10-05-drift-feel-*`).

**Real drive layouts.** Every car used to drive its rear wheels. Hajwala is
mostly done in front-drive saloons (Camry, Accord, Sonata) thrown on the
lever, beside rear-drive saloons and 4x4s, so the sim now drives whichever
axles the car's `drivetrain.layout` says: each wheel gets its axle's share
of the torque through its own diff blend, the engine braking and the
crank's inertia go to the driven wheels, the gearbox and the engine read
the driven wheels, and launch control caps the throttle over every driven
axle (`Drivetrain.axleShares`, `Drivetrain.launchCap`). Rear drive is the
old code path exactly. So front drive is not a label: its fronts spin on
the launch and in a slide, the gas pulls along the way they point, and its
tyre smoke comes off the front (the heat model follows whichever wheels
slip). Front drive launches slower (0-100 4.2 s against 3.65: weight leaves
the fronts), and giving the fronts more drive grip to close that made them
scrub through a 360 (3.42 s against 2.5), so the tricks won.

**Styles are knobs on the pedals, never on the lever.** The throw
controller is what makes the 360, the chain and the catch repeatable, and
the owner rated the tricks' ease "pretty good", so the styles leave the
lever alone and change what the pedals do in a slide (`DriftControl`): how
a short lift and the stab after it move the angle, whether a gas-held slide
fades or settles into a band, and whether a lift or a power-over can start
a slide. The lever 360 measures 2.4-2.6 s on every style and drivetrain.
Each drivetrain's first style stays close to the car as it was (Rally lost a lift throw for this: an ordinary
keyboard lane change at 60 km/h threw the tail out); the others
go further (Power Over starts slides on the gas, which "throttle alone never
starts a slide" used to forbid; High Angle settles at 45 degrees).

**The feather.** A lift used to drop the gas hold at once, so a 0.25 s lift
took a 30-degree slide to 1 degree a second later: setting the exhaust off
mid-drift cost the drift. A lift under `featherSeconds` now keeps the hold,
the angle moving meanwhile (rear drive tightens, front drive's lift-off
oversteer swings it out), and the gas back kicks it (the clutch-kick feel on
rear drive; the fronts pull it in on front drive). Never with the lever in:
a lift under the lever drops the gas hold at once, so letting go of the
lever and the gas together is still the catch. The cost is a hands-off
catch that waits out the feather first: 0.59-0.68 s against 0.53, after the
feather's rate went up to 50 deg/s so the wait already straightens.

**The flutter.** That lift, when the car is sideways, fires the exhaust
style's flutter instead of its lift burst: a dense run of mostly small pops,
30-60 ms apart, whose flames overlap into a flickering tongue, cut when the
gas comes back. Feathering mid-drift flutters the flames in time with the
driver's foot, which is what the drift videos show (each lift is its own
overrun burst). It respects the 2026-09-22 ruling that pops come only on
letting off; limiter pops stay off.

## The drift overhaul: the line, the throttle's angle, modes

The owner asked (2026-10-05) for "a full overhaul and perfection of the
drifting system, different modes I can try different styles for each
drivetype. all research based ... from throlle bursts to stable trifting
and the standdard hajwala 360s", and then "make sure its easy to control
the sideway drifting within the highway boundries". Research and design in
docs/superpowers/specs (`2026-10-05-drift-overhaul-*`).

**The line.** The first measurement decided the overhaul. A slide held on
the gas from 100 km/h with the wheel centred held 41 degrees perfectly, but
its path turned 74 degrees and it went 79 m sideways in four seconds; a
carriageway is 38 m. A Tanteel chain wandered 49 m, a lever 360 left 20
degrees off its line. The throw controller holds the angle against the
path, so the tyres' lateral forces, all pointing inward in a slide, bend
the path round at 0.8 g: a real drift's circle, right for a corner, wrong
for a straight highway where hajwala lives. A real driver straightens the
line with countersteer and by swinging the other way; the research splits
the controls the same way (the rear's slip holds the angle, the front
steers the path). Our wheel is already the angle's dial, so the line is an
assist (`Line.luau`): while a slide is held, a sideways push at the centre
of mass takes `hold` of the slide's own curve out and adds `steerG` toward
the steered side. At the centre of mass it has no yaw moment, so every
angle, 360 and catch number is the throw controller's as before; square to
the velocity it does no work, so every speed number is the tyres'. Held
into the slide, the wheel lets the hold go (a drift taking a corner);
under the lever it has its own hold from straight up, faded in over 60-90
km/h, so a highway 360 goes on down the road and a city handbrake turn
stays a turn. It stays on through the throw's tail, because a 360's path
held at 0 degrees the whole way round and then turned 7 to 15 in the
wobble after the lever was let go.

**The throttle sets the angle.** The research is unanimous that the gas is
the angle in a real drift, that slow throttle build-up (10-20 deg/s) fails
far less than fast, and that countersteer should be quicker than steer-in.
So in the new modes a gas-held slide widens toward its band's top
(`holdDecayDegPerSec` < 0), a lift tightens it (and flutters the exhaust,
so the drift-video look comes from driving the slide, not from a separate
trick), a stab kicks it with a surge of drive (`kickDriveScale`: wheelspin,
revs and smoke from the physics), and steering into a gas-held slide turns
it at a share of the rate (`dialIntoScale`) and stops at a ceiling
(`dialMaxDeg`), where it used to spin; counter-steer keeps the whole rate,
so a transition swings through as before. A gamepad's part throttle keeps
the slide and tightens it in proportion (`keepThrottle`). The keyboard's
throttle is binary, so its angle control is the feather and the stab.

**Front drive and all-wheel drive follow their physics.** A front-drive car
can only hold a slide with its rear braked: Tafheet holds on the lever
(100 to 65 km/h over three seconds, the research's ʿaksiya bleed) and the
gas pulls it straight with no countersteer, gaining speed. All-wheel drive
flips strategy at about 25:75 front to rear: Rally (45:55) is shallow and
gas pulls it in and on, Drift Mode (20:80) widens on the gas like rear
drive, Tatweef (the Land Cruiser's 41:59) runs dead straight and is
steered across the lanes, with a heavier 3.2 s 360.

**New entries, each a mode's.** Power-over (gas and lock, 30-90 km/h: a
low-gear move, never on a highway lane change), the clutch-kick entry (a
lift and the gas back with the wheel turned: FR Legends' double tap,
hajwala's neutral drop), the brake entry (the braking drift, front drive's
left-foot brake), the pivot (brake and gas together on a held slide, on a
quarter of the brake), and the lift throw.

**Classic stays.** Each drivetrain's fourth mode is the drift-feel default
exactly, so the overhaul can be compared against the car as it was, on the
same car, in the same session. The lever's 360 is the same move on every
mode: lever and full lock, about 2.5 s, 27 km/h lost; a mode sets only its
rate (Rally 140 deg/s, Tatweef 125) and the line sends it straight on.

## Speed (speed-feel)

The owner, 2026-10-05: "overall game driving feels pretty slow, is there a
way to either increase speed or just make it feel faster, needs to feel at
least 50% faster if not 2x", and chose both. **Faster:** the engine's torque
times `powerScale` (1.45) on every car, a sixth gear, the top speed 300 from
210, and a launch grip on the driven tyres off the line (1.4), because below
about 100 km/h the launch was grip-limited and power alone did nothing
there. The launch grip only acts while traction control may (pointing
straight, lever out, four wheels), so no drift number moves. 0-100 is 1.3 to
1.4 times quicker; 0-200 1.6 to 1.7 times on the rear- and front-drive cars
(Krown Vik 14.1 to 8.9 s, Kamri 15.0 to 8.8), and the Batrol, which topped
out at 196, reaches 200 in 11.3 s. A Hajwala slide from 150 and a lever 360
from 160 measure as the same moves did from 100 and 110, and the natl is
unchanged (36-37 degrees, down after 3.4 s). Real
tafheet runs at 160-260, so ordinary drifting moving up from 100 to 150 is
closer to the real thing. **Feels faster:** the desert highway is wide and
sparse, so little streams past the camera. The view now widens further with
speed (92 degrees at 200 against 85 at the old cap), the follow carries most
of the car's velocity so a fast car no longer shrinks to a speck (the old
smoothing trailed 8.4 m extra at 240), a faint shake comes in from 130,
faint speed lines run out to the screen's edges from 140, and a wind roar
rises under the engine. World-space particle streaks were tried first: from
a chase camera they are seen end-on and read as smudges on the road, so the
lines are screen-space. The owner then asked for 20% more, found it too
fast, and settled on 10% more: powerScale 1.6, launchGrip 1.54, the top
speed 330, every number scaled and not re-measured (the measurements above
are at 1.45). The economy is untouched, which means slides pay
about half again per second at the new speeds; `scoring.referenceSpeedKmh`
is the knob if that should be held level.

## Tafheet moves
The reference is real tafheet: factory-setup cars at 160 to 260 km/h on a
straight highway, thrown left and right. The named moves are Ta'geed (a
full 360), Aksiyat (180 one way then a full 360 the other), Sefty (a 360,
a short slide, a 360 the other way), Tanteel (wiggling the rear at speed),
and Harakat Al-Mawt (a straight-line power slide held until the car stops
on its own). Two things in the model stand between the car and those moves.

A car thrown fully sideways has to keep rotating and carry its momentum. A
single sliding floor made a tire at 90° of slip scrub as hard as one at
30°, so a 360 from 160 km/h stalled at 177° with the speed gone. The grip
curve therefore has a second, deeper floor past 50° of slip. The rear eases
to 0.45 of peak so the car keeps turning and keeps its speed; the front
stays at 0.7, because the fronts are what drive the rotation in a throw,
and easing them measurably slowed the spin. Nothing in the 10 to 35° region
a held drift lives in changes. Measured from 160 km/h: 360 in 3.4 s with
109 km/h left.

The speed-sensitive lock has to get out of the way of a throw. At 160 km/h
it leaves 13° of steer, which cannot start a Ta'geed. A handbrake pull is an
explicit throw, so the taper lifts for that window, the same way it already
lifts for a correction. Turning alone at speed is still tapered, which is
the whole point of it.

A Ta'geed is driven with the handbrake held through the spin, and that is
not a limitation of the model but the physics of the move: once the car is
travelling backwards the rear tires roll again and their grip kills the
rotation, so a tapped handbrake stalls at about 260° at any setting, while
a locked rear has no cornering stiffness and comes round in about 3.4 s
from 110 to 160 km/h. The drift assist fades out past 45° so it does not
steer against the rotation, and the throw relief lingers after the lever
so the wheel is still there mid-spin.

The debug panel counts completed 360s while the car is sideways, so a
Ta'geed or a Sefty can be checked by number rather than by eye.

## Stability under steering alone
Three things keep the car from drifting when the driver only asked it to
turn, none of them a gate on the handbrake.

The rear tire gives up grip gradually instead of falling off a cliff. Past
the peak slip angle the loss starts almost flat and steepens further out
(`falloffShape` above 1), so the car moves under the driver well before the
grip is actually gone. That fade is also what a held slide balances on.

Steering lock tapers with speed. Full lock below 40 km/h for parking, about
a third of it past 150, from a curve in CarConfig. A flick of the wheel at
highway speed no longer has the authority to pitch the car sideways on its
own. The taper has one exception: steering toward the direction the car is
already travelling is a correction, not a request for more angle, so it
lifts back to full lock in proportion to the slip angle. Without that
exception a car tapered to a third of its lock could not physically catch a
big slide, and holding a drift would stop working at exactly the speeds it
matters.

The rear peaks later than the front, so the front reaches its limit first
and the car is stable-biased by default. That change has a trap in it. The
rise to peak was a straight line whose slope is 1/peakSlipDeg, which means
moving the rear peak later silently softened the rear at every angle below
it: measured, the rear made 26% less lateral force at 5 degrees of slip and
started stepping out under throttle at cruise, the opposite of the intent.
So the rise got its own shape parameter. Below 1 it is concave, keeping the
tire's bite near zero slip and rounding over into the peak, which makes
"where the axle lets go" and "how stiff the axle is" separate knobs.

Initiation had to be paid for afterwards, because a rear that holds more
grip is a rear that is harder to break loose on purpose, so the handbrake
cuts deeper than it used to. Measured against the old tires on the same
harness, handbrake initiation is unchanged at about 0.23 s to 20 degrees.

The clutch kick used to be the second way in. It was removed with the
control simplification, and the reason it is worth recording is that its
torque spike turned out to be inert on its own: once longitudinal demand
passes the friction circle the tire is already clamped to its sliding value,
so a bigger spike changes nothing. Only a grip cut broke the rear loose,
which made the kick a second copy of the handbrake with its own numbers to
keep honest.

## Driving rework (mission Part 2)

Three complaints: it lost control on its own, drift was hard to get on purpose,
and acceleration was sluggish with no top speed. Measured before and after,
from 95 km/h unless stated:

| | before | after |
|---|---|---|
| plain full steer held, peak drift | 7° | 4° |
| steady full lock at 130, peak | 11° | 6° |
| throttle alone at 60, steer 0.33, peak | 10° | 2° |
| handbrake to 20° | 0.35 s | 0.43 s |
| flick (reversal) to 20° | did not break | 0.62 s |
| released at 28° with hands off | spun to 180 | peaks 61°, returns |
| 0–100 km/h | 6.7 s | 6.3 s (grip ceiling ~5.3) |
| top speed | unbounded | 210, as a limiter |

What actually moved it, in order of how much it mattered:

**Yaw damping.** The central finding. In a slip-angle tyre model, once both
axles are saturated the front and rear lateral forces point the same way and
their moments about the centre of mass nearly cancel, so a sliding car has
almost no yaw stiffness. A released slide kept rotating at a constant
110 deg/s all the way to 180 with full counter-steer applied and half brake
made it worse. Real tyres self-align as the rear comes back; the model does
not, so `slideYawDamping` stands in for it, at full strength when the driver
is not throwing the car and a fraction under the lever. Every "on ice"
complaint traced back to this.

**The lever cuts to a locked tyre, not to ice.** The rear grip multiplier
under the handbrake had been driven down to 0.08 to make initiation fast.
That is what made every slide unrecoverable: with no rear friction the yaw
rate hit 176 deg/s by 28 degrees of drift and kept climbing after release.
It is 0.45 now, which is sliding friction, and initiation speed comes from an
onset impulse instead.

**The onset impulse.** A pull or a flick gets a yaw kick for a fifth of a
second in the direction of the wheel. It replaces the clutch kick's job and
the ice-cut's job in one knob, and it only fires on a deliberate throw, never
on a held turn. It was 15,000 Nm at one point, which met the 0.3 s criterion
and produced a car that could not be caught; 6,500 is where the two goals
balance, at 0.43 s.

**The flick.** A hard steer one way then the other inside 0.45 s is read as
a throw: it gets the taper relief, the impulse (scaled up, since it has to
reverse a yaw already under way) and a brief rear grip cut for the weight
transfer a real pendulum turn produces. A held turn never trips it, so the
speed-sensitive taper that keeps the car planted on a bend is untouched.

**Traction control.** A loop, not a cap: throttle winds down while the rear
spins and back up while it grips, so drive hunts the edge of traction. It
runs through the midrange but only while the drift angle is under 8 degrees
and the lever is out, so it never touches a slide. A fixed cap was tried
first and sat under the grip limit; 0-100 got slower.

**The criterion.** Phase 0 asked for 20 degrees in 0.3 s. The car does 0.43.
It can do 0.29, and did, and the same setting spun it to 180 every time it
was let go. The mission says not to tune to satisfy a test; 0.43 is the
number where a pull is quick and a mistake is recoverable.

## The throw controller and the 360

The Part 2 car could not do a hajwala 360. Measured: a held lever from
110 km/h with full lock rotated to 180 in 1.5 s and stalled there going
backwards, from 110 down to 49 km/h. Three things in the tyre model cause
that. The fronts have to build slip before they push, so the onset is slow.
Once both axles slide neither has yaw stiffness, so the rotation has nothing
holding it at a rate. And past 90 degrees the steered fronts push the wrong
way: a car reversing with the wheel turned right swings its nose left. A real
Ta'geed gets its rotation from the locked rears scrubbing and the driver's
throttle, neither of which the friction circle produces. The onset impulse
from Part 2 was an attempt to paper over the first of those, and a fixed kick
was always either too weak for a 360 or, at 15,000 Nm, an unrecoverable whip.

So the throw is a controller now. While the lever is in (or for the flick
window) the rate the drift angle changes is steered toward a target: the
wheel's direction times `throwYawRateDegPerSec`, scaled by how far the wheel
is turned, on top of the rate the path itself is turning. That last term is
what makes "centred" mean "hold the angle" on a curving path rather than
"stop yawing", since the drift angle only changes when the car yaws faster or
slower than its velocity turns. The lever is permission and the wheel is the
dial: full lock comes round for a 360, centred holds a slide, opposite lock
brings the angle back. A rate target cannot run away, which is what keeps
this off ice; the lever out means the target is gone and `slideYawDamping`
catches the car as before.

The held slide needed one more piece. A rate controller alone let the angle
creep at 13 deg/s from the tyres' own moment, so once the wheel is centred
the hold angle tracks the drift until it has stopped moving, then latches,
and the controller asks for a rate proportional to the error. The catch has
its own torque cap, higher than the onset's: the yaw a full-lock turn-in
built (160 deg/s) takes a couple of tenths to absorb at 60,000 Nm against
the chassis's ~3,600 kg m², and with the controller gain at 600 the time
constant is 0.07 s. A 0.2 s tap of full lock under the lever, the keyboard
case, settles at 39 degrees and stays there; a held full lock centred at 36
settles at 67, and that lead is the driver's to learn.

Numbers, from the same harness as Part 2:

| | Part 2 | now |
|---|---|---|
| held lever + full lock from 110, 360 | stalled at 180 | 2.6 s, exits 76 km/h |
| 720 from 150 | — | 2.7 s and 5.2 s |
| 720 from 110 | — | stalls backwards in the second turn |
| handbrake to 20° from 95 | 0.43 s | 0.30 s |
| flick to 20° from 95 | 0.62 s | 0.35 s |
| let go at 28°, hands off | peaks 61°, returns | peaks 40°, straight in 1.4 s |
| tap under the lever, centred | — | holds 22°; full lock centred at 34 settles 46 |
| plain full steer at 95 / lock at 130 / throttle-only at 60 | 4° / 6° / 2° | 3° / 5° / 2° |
| 0–60 / 0–100 | 3.8 s / 6.3 s | 2.6 s / 4.4 s |

The catch is the same controller. Two failure modes forced that. A 720
from 110 ran out of speed in the second turn and stalled at 180 with the
lever in, rolling backwards to a stop; and bailing out of a spin at 150
degrees left the car travelling backwards at 55 km/h with nothing the
assist could do. So past 90 degrees with the lever in the speed fade is
lifted to `throwFinishAuthority` and the spin finishes (a starved 720 exits
under 50 km/h, which is its cost), and with the lever out and the wheel
centred, past `throwFinishFromDeg` the same authority brings the car back
to straight, the short way, or on round if it is nearly backwards and still
rotating. The first version of that kept whatever rotation the car had,
which carried a 60-degree bail the long way through 180; the direction
rule is the fix. Measured hands off from 110: straight in 1.9 s from 150
degrees, 1.5 from 110, 0.9 from 60, 1.4 from 28, every one ending on zero
with no swing past. The wheel still overrides, and starting a spin is gated
as before.

The controller is its own pure module now, `Throw.luau`, with a spec that
pins the rate target, the hold latch, the finish direction rule and the
speed fade. The direction bug above would have been a one-line failure in
it instead of a car going the long way round in Studio.

A note on method: the harness's live-reload attribute was being clobbered
by the edge merge in the input layer, so three rounds of config trials
(gain, cap, launch, deep floors) were measured against stale values before
it was caught by the missing "config reloaded" line in the console. Every
number in this document was re-measured after the fix.

Throttle is the second permission. A slide started on the lever is held on
the gas: past `throwThrottleHold` with the car already past
`throwThrottleHoldFromDeg` the controller stays alive with the lever out,
full rear grip, no lever drag. It latches through the straight moment of a
transition (the first version dropped the permission at zero and every flick
on the gas died there) and lets go after half a second under the gate with
the wheel centred, or when the gas is lifted. Throttle alone never starts
a slide, so the planted numbers for turning under power are untouched.

The speed a held slide bled turned out to be the fronts, not the rear. With
the wheel centred the fronts sit 27 degrees off the velocity and scrub; a
real driver counter-steers, which aligns them. So the hands-off assist now
runs under a hold too. The controller owns the angle there, so the assist
is not a request to straighten; it just points the fronts down the path.
Measured at 27 degrees from 100 km/h: 98 to 92 over four seconds on the
gas, where it had been 98 to 73. Two flicks on the gas chain 30, 35 and 31
degrees at 85 to 89 km/h. A 360 on the gas after a 0.3 s lever tap comes
round in 2.3 s and exits at 63; on the lever, 2.6 s and 76. The lever's
cut rear scrubs less through a full rotation, the gas's gripping rear
bleeds less in a held angle, and the driver gets to pick.

Speed through a spin is the other half of "people will want to do this".
The lever's drag came down from 8,000 N (half a g on its own, 11 km/h for
every second of a spin) to 2,000, and the fronts' deep-slide floor from 0.75
to 0.5, since the rotation no longer needs front bite. The rear's deep floor
is unchanged; it is what a released slide stops on. The speed gate on the
controller, fading out below 70 km/h, is the difficulty curve: a 360 is easy,
a second one from the exit speed of the first is not, and a 720 needs 150 on
entry.

The launch is a separate fix. It was grip-limited with a round friction
circle and the traction control hunting under it. Tread bites harder along
its rolling direction than across, so the rear's circle is an ellipse
(`longitudinalGrip` 1.4): more drive before it spins, nothing different
sideways, so no drift number moved. Below 100 km/h that grip (8.6 kN on the
rear axle) is the whole story and torque does nothing; above it, in third,
the engine is the limit, so the curve went up 15% for 100 to 150. With the
TC floor at 0.6 and a faster recovery, 0–60 went from 3.8 s to 2.6, 0–100
from 6.3 to 4.4, and 0–150 is 7.4.

A 360 is scored. Scoring measures the drift angle unwrapped inside a slide,
and every full turn pays `spinBonusPoints` times the chain multiplier, on
the client for the HUD flash and on the server for the bank, since both run
the same pure module on the same two inputs. The sign flip a spin makes at
180 is not a chain transition; only a crossing through straight is. The
debug SPINS counter was rebuilt the same way: counting yaw over-counted on a
curving path and under-counted the angle built before the car was properly
sideways, so a 360 that was visibly complete read 263 and reset.

## Handbrake
Multiplies rear grip by a fraction and drags the rear wheels with a capped
force. The circle shrinks, the rear lets go, the car keeps most of its
speed (measured: 100 → 94 km/h over a 0.6 s pull). It cannot stop the car
because the front is untouched. Letting go ramps the grip back over a
quarter of a second rather than in one step, so a release mid-slide hands
the car to the throttle instead of jolting it straight.

## Steering and drift assist
Steer angle chases the input at a rate, faster on return. Drift assist adds
a fraction of the car's slip angle as automatic counter-steer. Default is
low; the physics already makes counter-steer effective because the front
tires are on the rising side of their curve while the rear is on the floor.
Assist is switched off on two wheels (see below).

## Two-wheel ("natl")
On two wheels the car is an inverted pendulum pivoting on the grounded
contact patches. Gravity restores it below the static tip angle
atan(halfTrack / comHeight) (about 56° for the default car) and pushes it
over above. The controller measures that geometry in the body frame every
step, cancels gravity's restoring torque, and adds a small constant outward
lean. Nothing pulls the car toward a target angle, so it never feels
magnetized.

Balance is its own input axis, not the steering wheel. Q and E (gamepad
bumpers, the touch LEAN pair) lean the car toward the lifted or the grounded
side, with separate gains because catching a lean needs more authority than
adding to one. Holding a lean control is also what opens the mode on keyboard
and gamepad, so the key you press picks the side and then keeps pushing that
way; touch has to open the mode with NATL first, since buttons cannot appear
before the thing they belong to exists. Steering stays steering throughout,
which is the point: on two wheels the car yaws, and the player needs the
wheel to correct it while the lean axis handles the lean.

Real sidewall skiing starts at speed, off a ramp or a sharp turn, and is
balanced with the steering, with the grounded tires softened to make it
easier. So the lift has no authority below a speed floor and full authority
from a higher one, and the balance controller's authority fades away at a
crawl: a car that has slowed down settles back onto four wheels on its own,
because nobody can balance a car that is barely moving. The lean keys are
taps rather than levers. A press lands its whole gain at once and decays
toward a floor while the key is held, so the way to stabilise is to tap
against the lean, the way a stick is balanced.

The car has to be able to run straight on two wheels, and the first
version could not: the sim was a welded differential, so the one grounded
rear wheel got all the drive and yawed the car away from the low side.
A stock Camry has an open diff, which sends the torque to the wheel with the
least grip, the one in the air, so the grounded wheel barely drives and the
car goes where it is pointed. diffLock is now a blend, open enough on two
wheels, close to welded in a four-wheel drift where the loads stay similar,
plus a steady yaw damping while lifted that stands in for the driver's
micro-corrections. Measured at full throttle: 3° of heading drift over four
seconds, holding 38° of roll.

Three levers act on the car once it is up, and the measurements below are
from 80 km/h. Steering is by far the strongest: a turn toward the low side
drops the car, a turn away lifts it, and at full lock a 0.3 s tap of 0.2
steer was enough to flip it, so the lock is scaled to about a fifth while
lifted and halved again in the away direction. Throttle is the second: only
the grounded rear wheel drives, so gas yaws the car away from the low side
and that turn's inertial torque holds it up. The lean taps are the trim on
top, with a gain per key so a tap of E lands its full catch even while Q is
still held. Left alone at 0.4 throttle the car wobbles from 40° up to 50°
and back to 28° over two seconds; three taps of E hold it at 40°.

Two pieces of honest physics shaped the tuning:

- The front carries more load than the rear, so on two wheels the front
  spring's horizontal component out-yaws the rear's and the car turns gently
  toward the grounded side. That turn's inertial torque brings the car back
  down by a few hundred newton-metres. Below about 600 Nm of lean torque the
  car therefore settles back onto four wheels if the player does nothing;
  above it, it keeps leaning and tips. The owner chose the settling
  behaviour for Phase 0. Steering toward the grounded side strengthens that
  turn and drops the car fast; steering away lifts it.
- Drift assist must be off on two wheels. It read the sideways creep as a
  slide and steered into it, which turned the car and brought it down on its
  own, exactly the "magnetized" feel we wanted to avoid. That is also why
  steering is no longer the balance input: the turn a steer produces has its
  own righting torque, so balancing with the wheel meant balance and yaw
  correction fought each other.
- On tread, tires slide out at atan(grip) ≈ 45° before the car can reach the
  static tip angle. Past `rimGripStartDeg` the grounded tires gain extra
  grip (rim and sidewall dig-in), which is what makes a real natl flip
  possible if `leanTorque` is raised.

The loaded side's springs are stiffened while lifted because two springs
now carry the whole car.

## Two-wheel balance, revisited

Measured after the driving rework: holding Q at 90 km/h lifted the car to
37 degrees and it sank back to 12 with the key still down. Nothing in the
controller pulls it down; the gravity cancel is a model of the restoring
torque, and the real one (grounded-side springs, tyre moments, whatever the
road adds) is larger. Chasing each source is a losing game, so the
controller got a spring about the target angle. It absorbs the model error
and no more: at 320 Nm per degree the car was a magnet and taps did nothing;
at 160 it holds hands-off at 24 to 30 degrees, an E tap dips it four degrees
and it comes back, a Q tap lifts it three.

The other rule is that a held key is not a long tap. The tap envelope decays
a held key to a third of its push, which the spring beats, so holding E
brought the car to four degrees and then watched it climb back to eleven.
Past `landHoldSeconds` the controller reads the held key as "down", lets go,
and the landing damping brings the car onto four wheels in half a second.

The HUD's NATL readout now colours by tip margin — blue with room to spare,
amber when a catch is due, red just before it goes — so the player has
something to tap against besides the horizon.

Lighter, and harder. After driving it the owner called the natl slow and
heavy and asked for something that drops back and has to be balanced. The
weight was the roll damping (80) and the fully cancelled pendulum: a car
that is neutral at every angle and heavily damped does nothing on its own
and answers a tap slowly. Now the lift is 15,000 Nm (30 degrees in 0.33 s,
peaking at 42; 20,000 overshot to 58 with the tip at 62), the damping is
60, only 93% of gravity is cancelled and the spring is 110. Left alone the
car sags and lands in three seconds; a tap every second and a half keeps it
swinging between 12 and 38 degrees, two and a half seconds is too slow, a
catch tap drops it 12 degrees, the catch key held lands it in 0.35 s, and a
0.3 steer toward the low side for a third of a second drops it 17. A tipped
car also returns to idle once it is on its wheels again; with the mode
latched on a tap there was no key release to clear it and it stayed
"tipped" for good.

Then the owner's spec for the tip: only from 90 km/h, a big first tip,
tap-tap to keep it, holding the key topples, speed lost brings it down. The
lift gate and the speed fade are two numbers; the big tip is 18,000 Nm of
lift (a tap at 100 peaks at 49 to 52 degrees, just under the 56-degree
static tip); the topple needed two changes. The key toward the lifted side
now keeps its full push while held instead of decaying to a third, and the
balance spring became one-sided, lifting a sagged car but doing nothing
above the target: symmetric, it pulled a held key back to a hover at 56
degrees and nothing ever went over. Measured: Q held after the lift topples
in 1.1 s; a tap every 1.5 to 2 s keeps the car up with the gas on; lifted
at 100 with the gas off and a light brake it is under 90 at 3.2 s and down
at 4.5 while still being tapped; the catch key held lands it in 0.7 s.

The ride scores. Scoring takes the roll as a third input alongside speed
and drift angle, on the client from the sim and on the server from the
replicated pose (the right vector's Y is the sine of the roll), and past
`natlMinRollDeg` the run pays `natlPointsPerSecond` scaled by speed. It
opens and closes a run the way a slide does, and sideways on two wheels
pays both. A six-second ride at 90 km/h banks about 430 points; the server
reproduces the client's number the way it does for drift.

## Two-wheel: tap to lift, tap to keep

The owner's brief for the natl was "first tap gets it up, subsequent taps
keep it". Holding a key to stay up was the opposite of that, so the mode
latches: a tap of Q or E from idle lifts the car onto that side and it stays
up with nothing pressed; the touch NATL toggle does the same job on a phone.
Landing is the other key held past half a second, or the toggle going off,
or slowing to a crawl.

"Keep it" needed the hold to be perishable. The balance spring winds down to
a tenth of itself over three seconds with no tap toward the lifted side, and
a tap winds it back to full. That alone was not enough: with the spring gone
the car hovered at 9 degrees for ever, because a fully cancelled pendulum is
neutral at every angle. So the gravity cancel winds down on the same
envelope, to 85% of itself, which leaves enough of gravity to bring the car
home. Measured at 90 km/h: one tap lifts to 34 degrees and the ignored car
lands itself at 4.0 s; a tap every two seconds holds 16 to 30; every three
seconds is the edge; a catch tap dips it 9; the catch key held lands in
0.5 s. The rhythm is the whole point: it is a thing you do, not a thing you
switch on.

## Drift feedback
Hajwala is watched as much as it is driven, so the car has to look like the
clips: smoke off the rears, rubber on the road, wheels visibly spinning up
when the rear breaks loose. All of it is driven by the per-wheel state the
sim already reports (slip angle, saturated, locked, grounded) and none of
it feeds back into the physics. The sim does not integrate wheel spin, so
the wheel models are the one place it is shown: a driven wheel past the
friction circle winds up toward the speed the engine is turning it, and a
locked wheel stops. Emitters and skid-mark attachments hang off the chassis
at each wheel's rest contact point rather than off the spinning wheel parts.
Sound is wired the same way (screech from rear slip, engine from rpm and
throttle) but plays nothing until asset ids are supplied in CarConfig; no
ids are invented here.

## Camera
Three profiles in CarConfig (normal, drift, two-wheel) cross-fade by rate.
The drift profile swings the look direction toward the velocity so the angle
is visible from behind and steps to the outside of the slide. The two-wheel
profile drops lower, steps toward the lifted side so the airborne wheels are
in frame, and tilts the horizon with a fraction of the car's roll.

## Road
Built from CarConfig.road: a 2 km straight, a 400 m transition pad from 900
to 1300 m where the straight widens to 160 m (two flush wings, no overlap,
so no z-fighting), a 400 m radius / 30° left curve at the end, and a sand
plane that covers the straight, the curve and 500 m of run-off. The pad is
where left-right transitions get practised without running off the 60 m road.

## Scoring and cash
Scoring lives in one pure module that both sides run. The client steps it on
its own VehicleState so the HUD number moves with the car and owes nothing to
the network. The server steps the same code on samples it takes itself from
each driven car's replicated pose and velocity, and that copy is the one that
decides a payout.

The inputs are deliberately just speed and drift angle. Anything else — a
spin counter, a wheel state, an input flag — would be something the server
cannot reproduce from replicated physics, and then the two totals would
diverge and the cap below would start punishing honest players. That is also
why a 360 has no special bonus: at a high angle the angle factor is already
at its ceiling, so a Ta'geed pays the top rate for as long as it takes to
come round, out of the same two numbers.

When a slide ends the client submits its figure as a claim and the server
banks `min(claim, its own total x serverTolerance)`. With no claim it banks
what it saw. So a claim can only ever lower a payout, never raise one, and
the worst a forged claim achieves is the tolerance itself: 1.25 means at most
25% over an honest run of the same slide, which is not worth writing an
exploit for. The tolerance exists because the two sides sample at different
rates, not as a concession. Samples that fail a plausibility check — a speed
no car reaches, or movement further than that speed allows in the interval —
throw the open slide away rather than score it. A player pressing reset trips
that same check, which is the right outcome.

Cash never travels on a remote. It lives in Economy and reaches the client as
a replicated Player attribute, which a client can write locally and change
nothing. The one rule that matters in Economy is that a profile whose load
failed is never saved: overwriting a real balance with a fresh zero is the
only unrecoverable mistake available here. Cross-server session locking is
not implemented; Roblox keeps a player in one server at a time, so the
exposure is a rejoin racing the old server's save, and the best score is
merged through UpdateAsync rather than overwritten. Worth revisiting when
teleports arrive.

Detecting a crash needed care. Differentiating speed frame to frame is
useless when the client steps at 240 Hz and the server samples at 20: the
same blip reads as a wildly different deceleration on each side. Instead both
keep an average of speed lagged by impactSmoothSeconds and compare the
current speed against it. How far speed has fallen below its own recent
average is a rate that barely moves for one bad sample and does not depend on
the step size. Hard braking reads about 40 km/h per second, a wall reads
several hundred.

A slide that never straightens is a spin-out, not a finish. The car falls
under minSpeedKmh long before it reaches spinOutSpeedKmh, so a car rotating
to a standstill would otherwise run out the grace window and bank the whole
slide. When the window expires the drift angle decides: still sideways means
the car never came back and the run is lost.

## Network
Server builds and parks cars and runs the sim with zero input for parked
ones. Sitting (through the ProximityPrompt) hands network ownership to the
driver; their client runs the sim on its own car and steers the camera.
Leaving returns ownership to the server. Reset is client-side while driving
because the client owns the assembly.

## Live reload
`ConfigLoader.reload()` clones the CarConfig ModuleScript and requires the
clone, which re-runs the current Source. Verified in Studio: a Source change
made on the server replicates to the client at runtime, and L reloads on
both sides.
