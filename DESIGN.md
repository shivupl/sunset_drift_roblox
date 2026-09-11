# DESIGN — why the car is built this way

## One rigid body, raycast suspension
The car is a single physics assembly: a box, a hidden ballast, four visual
wheels and a seat. Each corner fires a ray straight down (in the body frame)
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

## Drivetrain
Torque curve by rpm, automatic gearbox, welded-diff behaviour (equal drive
to both rear wheels). Wheel spin is not integrated; the tire reports when
demand exceeded grip and the engine rpm floats up while it does. Clutch kick
is a short torque multiplier. Engine braking on lift shifts weight forward,
which is what makes a lift-and-flick transition swing the rear across.

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
it leaves 13° of steer, which cannot start a Ta'geed. A handbrake pull or a
clutch kick is an explicit throw, so the taper lifts for that window, the
same way it already lifts for a correction. Turning alone at speed is still
tapered, which is the whole point of it.

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

Both initiation methods had to be paid for afterwards, because a rear that
holds more grip is a rear that is harder to break loose on purpose. The
handbrake cuts deeper than it used to. The clutch kick gained a grip cut of
its own, because its torque spike turned out to be inert: once longitudinal
demand passes the friction circle the tire is already clamped to its sliding
value and a bigger spike changes nothing. Measured against the old tires on
the same harness, handbrake initiation is unchanged at about 0.23 s to 20
degrees and the kick at about 0.33 s.

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
