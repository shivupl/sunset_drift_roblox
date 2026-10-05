--!strict
-- Handling shared by every car. SI units unless the name says otherwise. Per-car geometry,
-- mass and meshes are in CarCatalog; a car's entry can override anything here.
-- See TUNING.md for what each field does and which way to move it.
-- Reloadable in play with the L key (ConfigLoader clones and re-requires this module).

local config = {
	units = {
		metersPerStud = 0.28,
		-- Effective gravity on the car in m/s². workspace.Gravity stays 196.2;
		-- the sim adds an upward counter-force so the car falls at this rate.
		-- 54.936 (= 196.2 * 0.28) makes the counter-force zero for A/B tests.
		gravity = 9.81,
	},

	body = {
		-- A car's geometry and mass are not here: each car's rig in
		-- CarCatalog supplies them, and VehicleRig.configFor writes them into
		-- a per-car copy of this config. These placeholders only give the
		-- fields their types; anything that reads them straight from CarConfig
		-- instead of the car's config gets zeros.
		massKg = 0,
		bodySize = { 0, 0, 0 }, -- length (Z), height (Y), width (X), metres
		centerOfMassOffset = { 0, 0, 0 }, -- from the box centre: {lateral, up, forward}
		wheelbase = 0,
		trackWidth = 0,
		wheelRadius = 0,
		wheelWidth = 0,
		shellMassFraction = 0,
		-- Aero and rolling losses are shared by every car unless an entry's
		-- tuning overrides them.
		dragCoefficient = 0.32,
		frontalArea = 2.2,
		airDensity = 1.2,
		rollingResistance = 0.015,
	},

	suspension = {
		restLength = 0.35, -- hardpoint to wheel centre at full droop
		travel = 0.2,
		rayMarginM = 0.05, -- extra ray length past full droop so a hanging wheel still reports the ground
		stiffness = 35000, -- N/m per corner
		damping = 2600, -- Ns/m per corner
		bumpStopStiffness = 350000, -- N/m past full travel
		antiRollFront = 8000, -- N/m of compression difference, front axle
		antiRollRear = 4000,
	},

	tires = {
		-- The rear peaks slightly later than the front and decays far more
		-- gently past it, so the front reaches its limit first (stable bias)
		-- and the rear gives warning before it lets go instead of stepping
		-- out the moment you turn at speed.
		-- falloffShape: 1 is a straight line from peak to floor, above 1 is
		-- shallow at first and steepens further out.
		-- riseShape: 1 is a straight line up to the peak, below 1 keeps the
		-- tire's bite near zero slip. The rear needs this, because moving its
		-- peak later would otherwise soften it everywhere below that peak and
		-- it would step out under power at cruise.
		-- deepSlideSlipDeg / deepSlideGripRatio: past the first floor the grip
		-- eases down again toward the deep ratio by 90 deg of slip. This is the
		-- 360 knob: it does not touch the 10-35 deg region a held drift lives
		-- in, but a car thrown fully sideways scrubs less and keeps turning.
		front = {
			grip = 1.05,
			peakSlipDeg = 8,
			riseShape = 0.85,
			slideSlipDeg = 25,
			-- Fronts keep most of their bite when thrown. They are what turns
			-- the car in a handbrake pull and what catches it at 40 degrees of
			-- counter-steer, so this is both initiation speed and authority
			-- at large angles.
			slideGripRatio = 0.85,
			falloffShape = 1.2,
			deepSlideSlipDeg = 50,
			-- 0.5, down from 0.75: in a 360 the fronts spend a second near 90
			-- degrees of slip, and at 0.75 they were the biggest single drag
			-- on the car. The rotation comes from the throw controller now,
			-- not from front bite, so the deep floor is a speed-carry knob.
			deepSlideGripRatio = 0.5,
			longitudinalGrip = 1,
		},
		rear = {
			-- Above the front now. A rear that out-grips the front is what
			-- "planted" means: turning at speed runs the fronts out first and
			-- the car pushes wide rather than stepping out. The handbrake cut
			-- was deepened to match so a deliberate throw still breaks it.
			grip = 1.06,
			peakSlipDeg = 9.5,
			riseShape = 0.55,
			-- The gentle falloff ends at 26 deg and the deep floor starts at 30:
			-- below ~25 deg (a held drift) the rear is still near full grip,
			-- past 30 it lets go progressively. With the first floor lasting to
			-- 40 deg the rear had 98% grip at 40 and a tapped handbrake snapped
			-- the car straight instead of letting it come round.
			slideSlipDeg = 26,
			-- Higher floor and a straighter falloff: grip goes away gradually
			-- past the peak, which is the warning the driver feels before it
			-- lets go, instead of holding then dropping off a cliff.
			slideGripRatio = 0.82,
			falloffShape = 1.4,
			-- Rear lets go deep: this is what lets the car keep rotating and
			-- carry its speed through a Ta'geed instead of scrubbing to a stop.
			-- Raised twice from 0.3 at 30 degrees. At 0.3 and again at 0.5 a
			-- car let go at 43 degrees with hands off kept rotating to 180.
			-- This floor only matters once the lever is released: a held
			-- handbrake cuts the rear to 0.08 regardless, so a Ta'geed still
			-- comes round, and a released slide now has enough rear to stop.
			deepSlideSlipDeg = 45,
			deepSlideGripRatio = 0.55,
			-- Drive grip as a multiple of the lateral peak. Launch was grip
			-- limited with the circle round: 0-60 in 3.8 s with the traction
			-- control hunting the edge. Tread bites harder along its rolling
			-- direction than across, so the rear gets an ellipse. This only
			-- touches how much throttle the rear takes before it spins; what
			-- it does sideways, and so every drift number, is unchanged.
			-- 1.55 with the TC floor at 0.7: 0-70 in 2.65 s and 0-100 in 3.9
			-- (1.4 / 0.6 was 3.0 and 4.35). Power-over at 40-60 km/h under
			-- full lock still peaks at 1-3 degrees, so the drift is untouched.
			-- 1.9 with the slip model's launch control: the owner found the
			-- launch still flat. 0-30 1.07 -> 1.0 s, 0-100 4.1 -> 3.6 s. It
			-- also pushes harder on the gas in a slide (a spinning rear's
			-- force is drive grip), so slipModel.slideRelief came down to match.
			longitudinalGrip = 1.9,
		},
		speedFadeMps = 1.0, -- lateral force fades to zero below this speed
		-- Slide momentum (Tire.scrubRelief): while the car is sideways, this
		-- fraction of the drag the tyres' lateral forces put against the
		-- velocity is handed back at the centre of mass. The force that bends
		-- the path and every yaw moment are untouched, so steering, throws and
		-- catches feel the same; a Tanteel chain or a Sefty 360 just stops
		-- scrubbing the car to a halt. Never below fromDeg of drift or
		-- minSpeedKmh, and never enough to push the car on.
		slideMomentum = {
			slideRelief = 0.38,
			leverRelief = 0.6,
			fromDeg = 10,
			fullDeg = 25,
			minSpeedKmh = 30,
			fullSpeedKmh = 60,
		},
		-- THE SLIP MODEL (VehicleSim/Wheel.luau). Each wheel carries its own
		-- spin; drive, brakes, engine braking and the handbrake are torques on
		-- it, and the tyre force comes from the slip angle and the slip ratio
		-- together, through the axle curves above, with grip falling off under
		-- load. A spinning rear in a slide pushes along its nose and lets the
		-- tail hang; a locked rear drags and lets it go. Off (enabled = false)
		-- is the legacy friction-circle tyre, kept as the A/B.
		slipModel = {
			enabled = true,
			peakSlipRatio = 0.12, -- a road tyre peaks around 10-15% slip
			lowSpeedMps = 3, -- floor on the slip ratio's denominator, for a calm standstill
			-- Grip lost per unit of load over static: the outside tyres in a
			-- slide and the rears under a launch grip less than their load
			-- alone says. Real road tyres are around 0.1.
			loadSensitivity = 0.08,
			loadFactorMin = 0.6,
			loadFactorMax = 1.25,
			wheelInertia = 1.4, -- kg m^2, a 17" road wheel and tyre
			-- Crank-side inertia reflected onto the rears through the gearing,
			-- so first gear spins up slowly and fifth flares.
			engineInertia = 0.15,
			substepSeconds = 0.003,
			-- The lever is a brake torque on the rears plus a grip cut. A full
			-- lock (2,500 Nm, past the ~2,200 the tyre can react) is what a
			-- real handbrake does, and measured it dragged a lever 360 from
			-- 110 down to 72 and cost every throw 4 km/h. 700 drags the rears
			-- well into slip without locking them, and the 0.6 cut lets the
			-- tail go: 20 degrees in 0.28 s, the 360 exits at 85.
			handbrakeTorque = 700,
			handbrakeGripCut = 0.6,
			-- The flick's rear grip cut for this model (steering has the
			-- legacy one). Real weight transfer and a spinning rear already
			-- swing the tail, so less of the stand-in is needed: at the
			-- legacy 0.35 a part-throttle flick from 100 rotated to 85-89
			-- degrees against the legacy car's 72-74; 0.5 gave 82-84 and
			-- 0.7 gives 76-79.
			flickRearGripMultiplier = 0.7,
			-- Launch control: under tractionControlBelowKmh, pointing straight,
			-- the throttle is capped at this fraction of the drive the rear
			-- tyres can put down at their peak slip, so a launch grips at the
			-- limit instead of spinning onto the sliding floor. Measured
			-- without it (the spin-and-cut loop only): 0-30 in 1.20 s and 7
			-- m/s^2 for the first second. Above 1 lets the rears spin up.
			launchGripUse = 1.0,
			-- Slide momentum for this model (see slideMomentum above). Pure
			-- physics scrubs almost as hard as the legacy tyre did (held slide
			-- 97 to 70, chain 96 to 76, lever 360 exit 70 with both at 0),
			-- so the relief stays. With the rear's drive grip at 1.9 a spinning
			-- rear pushes harder on the gas, so less is needed: at 0.25 / 0.7
			-- the held slide loses 6-7 km/h in 4 s, the chain 5, the lever 360
			-- exits at 83. The held slide is sensitive here: 0.2 lost 13, 0.3 lost 4.
			slideRelief = 0.25,
			leverRelief = 0.7,
		},
	},

	drivetrain = {
		-- Tafheet lives at 160-260 km/h. Bumped about a third over the first
		-- pass so highway speed arrives in a few seconds rather than ten,
		-- and another 15% later. Below about 100 km/h the launch is grip
		-- limited (8.6 kN on the rear axle, traction control hunting the
		-- edge) and torque makes no difference to it; above that, in third
		-- and up, the engine is the limit and this is what pulls 100-150.
		torqueCurve = { { 1000, 380 }, { 2500, 550 }, { 4000, 640 }, { 5500, 620 }, { 6500, 500 }, { 7000, 0 } },
		gearRatios = { 3.5, 2.1, 1.4, 1.0, 0.8 },
		reverseRatio = 3.2,
		finalDrive = 3.9,
		drivelineEfficiency = 0.9,
		-- Differential lock, 0 open to 1 welded. An open diff sends torque to
		-- the wheel with the least grip, so on two wheels the airborne rear
		-- takes it and the grounded one barely drives, which is why a real
		-- natl can run straight. A welded diff drives the grounded wheel
		-- alone and yaws the car. Partial lock keeps the welded feel in a
		-- four-wheel drift (loads stay close) and opens up when one lifts.
		diffLock = 0.25,
		-- Which wheels drive (DESIGN.md, Drivetrains). "RWD" is every car
		-- until the catalog says otherwise (the owner, 2026-10-05: "the drift
		-- style to differ slightly depending on the drivestyle of the vehicle
		-- (awd,rwd,fwd,etc)"). FWD drives the fronts; AWD splits by
		-- frontShare through a fixed centre diff. Drift styles set the split
		-- (DriftStyles).
		layout = "RWD",
		frontShare = 0.5,
		-- The front axle's diff under FWD and AWD, like diffLock for the
		-- rear: open enough that a lifted wheel on two wheels does not yaw
		-- the car.
		frontDiffLock = 0.25,
		idleRpm = 900,
		redlineRpm = 6800,
		upshiftRpm = 6400,
		downshiftRpm = 3000,
		shiftTime = 0.08, -- torque is cut for this long; 0.15 left a quarter-second flat spot at the 1-2
		-- In a slide (drift angle past slideShiftFromDeg) the box shifts up by
		-- the engine's own rpm, spin included, and never down. Measured
		-- before (2026-09-23): a held drift in 2nd at 70 km/h sat at
		-- 6720-6800 rpm on the limiter 94% of the time, because road speed
		-- said 4400 and wheelspin never upshifted; a handbrake throw could
		-- drop it to 1st mid-slide. Only above slideShiftMinKmh: a wheelspin
		-- launch wags the tail past 15 degrees, and without the floor the box
		-- shifted up under the spin (0-100 went from 3.6 s to 4.9 and 8.7).
		-- false is the old road-speed box everywhere.
		slideShift = true,
		slideShiftFromDeg = 15,
		slideShiftMinKmh = 40,
		-- A slide lasts this long after the angle drops back under
		-- slideShiftFromDeg (a transition swings through zero; the box hunted
		-- 3>4>3>2 through a chain), and takes the box up at most
		-- slideShiftMaxUpshifts gears (uncapped, a held drift at full
		-- throttle climbed 3>4>5). With 1, strong wheelspin brushes the
		-- limiter for part of a held slide (measured 16-42%, against 93%
		-- with no slide shifting); 2 keeps the revs lower but lets the box
		-- run up the gears. The owner's feel call.
		slideShiftHoldSeconds = 0.6,
		slideShiftMaxUpshifts = 1,
		spinRpmRate = 6000, -- rpm/s the engine climbs while the rear spins
		-- Lift-off is how a transition swings: engine braking loads the nose
		-- and lightens the rear for the flick. 40 was too little to feel.
		engineBrakeTorque = 90, -- Nm at redline, scales with rpm
		brakeForce = 14000, -- N total at full pedal
		brakeBias = 0.65, -- fraction on the front axle
		brakeFadeMps = 0.5, -- brakes fade to zero below this speed (no jitter at rest)
		reverseEngageMps = 0.5, -- below this speed, brake with no throttle selects reverse
		-- ...and only after the brake has been held that long while stopped,
		-- so braking to a standstill does not snap into reverse.
		reverseHoldSeconds = 0.4,
		-- Top speed as a limiter. 210 km/h: the map's 400 m curve is at the
		-- grip limit at 220 (v^2/r = 9.3 m/s^2), the 2 km straight takes 34 s,
		-- and it is still 20 over what most players will hold a lane at. Drive
		-- fades over the last topSpeedFadeKmh so the ceiling is a plateau.
		topSpeedKmh = 210,
		topSpeedFadeKmh = 20,
		-- Launch traction control, active under this speed. A loop, not a
		-- cap: the throttle multiplier winds down at cutRate while the rear
		-- spins and back up at recoverRate while it grips, never below min.
		-- With no TC the first two seconds of a launch sat at 7-23 km/h in
		-- wheelspin; a fixed 0.55 cap was slower still. The grip ceiling for
		-- 1,600 kg at this rear grip is about 5.3 s to 100.
		-- Active through the midrange too: measured at 64 km/h the rear was
		-- spinning at 82% of peak grip and the car pulled 3.6 m/s^2 instead of
		-- 4.7. Gated off above tractionControlMaxDriftDeg of slide and while the
		-- lever is in, so it never touches a drift.
		tractionControlBelowKmh = 120,
		tractionControlMaxDriftDeg = 8,
		-- Floor raised and recovery quickened for the launch: at 0.35 and
		-- 1.2/s each spin cost half a second of throttle before the loop
		-- wound back to the edge.
		tractionControlMin = 0.7,
		tractionControlCutRate = 5,
		tractionControlRecoverRate = 4,
	},

	steering = {
		maxSteerDeg = 38,
		-- Quick hands. Lock to lock in a flick took 0.26 s at 240/360, a third
		-- of the whole initiation time.
		steerSpeedDegPerSec = 320,
		steerReturnDegPerSec = 520,
		-- Back to 0.15 from a trial at 0.2: the assist counter-steers against
		-- every initiation too, and at 0.2 it cost the handbrake a tenth of a
		-- second to 20 degrees. The taper and the rear bias do the stability.
		driftAssist = 0.15, -- 0..1, adds this fraction of the drift angle as counter-steer
		-- The assist fades out past these angles so it stops fighting a spin:
		-- at 90 deg of drift it was steering 13 deg against the rotation.
		driftAssistFadeStartDeg = 45,
		driftAssistFadeEndDeg = 75,
		-- When the driver's hands are off the wheel (|steer| under
		-- driftAssistHandsOffBelow) the assist rises to this, so lifting and
		-- straightening brings the car back on its own. Hands on, the driver's
		-- authority is untouched. It also runs under a held slide (lever or
		-- gas, wheel centred): there the controller holds the angle and the
		-- assist only aligns the fronts with the path, which is what keeps
		-- the speed in.
		driftAssistHandsOff = 0.7, -- 0.4 was 17 deg of counter-steer at 43 deg of slide, not enough to catch it
		driftAssistHandsOffBelow = 0.1,
		-- Speed-sensitive lock: km/h -> fraction of maxSteerDeg. Full lock for
		-- parking and low-speed work, tapering at highway speed so turning
		-- alone cannot pitch the car sideways.
		speedLockCurve = { { 0, 1 }, { 40, 1 }, { 90, 0.55 }, { 150, 0.32 }, { 220, 0.28 }, { 300, 0.28 } },
		-- The taper lifts back toward full lock as the car goes sideways, so a
		-- slide stays catchable at speed. Degrees of slip for full relief, and
		-- how much of the taper it lifts (0 disables it, 1 gives the whole
		-- wheel back).
		counterSteerReliefDeg = 25,
		counterSteerRelief = 1,
		-- A handbrake pull is a deliberate throw, so the taper
		-- lifts for that window (1 = full wheel, 0 = taper still applies).
		-- Without it a Ta'geed at 160 km/h has 13 deg of steer to start with.
		throwRelief = 1,
		-- Keep the throw relief for this long after the handbrake is let go
		-- so the wheel does not shrink to a third mid-spin.
		throwReliefTailSeconds = 1.5,
		-- The flick: a hard steer past flickFromLock one way, then the other
		-- way within flickWindowSeconds, is read as a deliberate throw and gets
		-- flickRelief of the taper back (1 = the whole wheel) for the throw
		-- tail. A held turn never trips it, so the taper that keeps the car
		-- planted on a bend is untouched. 0 disables the flick.
		flickFromLock = 0.5,
		flickWindowSeconds = 0.45,
		flickRelief = 1,
		-- The reversal also cuts rear grip for flickGripSeconds, standing in
		-- for the weight transfer a real pendulum turn gets. Without it the
		-- relief alone peaked at 10 degrees from 95 km/h.
		flickRearGripMultiplier = 0.35,
		flickGripSeconds = 0.5,
		-- The throw controller. While the lever is in (or for the flick
		-- window) the rate the drift angle changes is steered toward a
		-- target: the wheel's direction times throwYawRateDegPerSec, scaled
		-- by how far the wheel is turned. Full lock under the lever comes
		-- round for a 360; centred, the car holds whatever angle it has,
		-- which is a held slide; counter-steered, the angle comes back. The
		-- lever is permission. This replaced an onset impulse: a fixed kick
		-- was either too weak to start a 360 or, at 15,000 Nm, an
		-- unrecoverable whip. A rate target cannot run away, which is what
		-- keeps this off ice. Measured without any of it, a held lever from
		-- 110 km/h stalled at 180 degrees going backwards: the steered fronts
		-- fight the rotation past 90.
		-- Rate: 150 deg/s brings a 360 round in about 2.6 s. Higher spins
		-- faster and harder to time; lower is lazier and scrubs more speed
		-- because the car spends longer sideways.
		throwYawRateDegPerSec = 150,
		-- Nm per deg/s of error, capped at throwYawMaxTorque. The cap sets
		-- how hard the onset kicks and whether the controller can overpower
		-- the fronts in the backwards half of a spin; the gain sets how
		-- tightly the rate is held once there. The car's yaw inertia over
		-- this gain is the catch's time constant: at 250 it was 0.17 s and
		-- a full-lock turn-in carried 26 degrees past where the wheel was
		-- centred before the hold took; 600 makes it 0.07 s.
		throwYawGain = 600,
		throwYawMaxTorque = 16000,
		-- Filter on the path's own turn rate, which the controller adds to
		-- its target so "centred" means "hold the angle" on a curving path.
		throwPathFilterSeconds = 0.05,
		-- Centred wheel under the lever: once the angle has stopped moving
		-- (under throwHoldSettleDegPerSec) it is latched, and the controller
		-- asks for throwHoldGain deg/s of correction per degree off it,
		-- capped at the throw rate. Higher gain is a stiffer hold.
		-- 6, from 3: at 3 a slide handed to the gas at 14 degrees faded to
		-- straight in two seconds, the tyres' realigning beating a 12 deg/s
		-- correction; small angles need a stiffer hold than big ones.
		throwHoldGain = 6,
		throwHoldSettleDegPerSec = 25,
		-- Torque cap for the catch when the wheel is centred, higher than
		-- the onset cap so the yaw a full-lock turn-in built is absorbed
		-- in a few tenths instead of carrying the car 40 degrees past
		-- where the wheel was centred. The chassis has about 3,600 kg m^2
		-- of yaw inertia, so 60,000 stops 160 deg/s in 0.17 s, which is
		-- 13 degrees of travel; 32,000 was 25.
		throwHoldMaxTorque = 60000,
		-- The target fades to nothing below throwMinSpeedKmh and is full from
		-- throwFullSpeedKmh, so a second spin from a car that has scrubbed
		-- down to 50 is a struggle and a parking-lot pull does nothing. This
		-- is the "crazier tricks stay hard" knob: raise throwFullSpeedKmh and
		-- a 720 needs more entry speed.
		throwMinSpeedKmh = 30,
		throwFullSpeedKmh = 70,
		-- Past 90 degrees of drift the fade is lifted to this much authority
		-- so a spin that has run out of speed still comes round instead of
		-- stalling backwards with the lever in. Starting a spin is still
		-- gated by the speeds above.
		throwFinishAuthority = 0.6,
		-- With the lever out and the wheel centred the same authority brings
		-- the car back from anything past this angle, so letting go is
		-- always a catch. Under it the damping and the hands-off assist do
		-- the job on their own. The wheel overrides.
		throwFinishFromDeg = 25,
		-- Hands off past this angle and still rotating, the car carries on
		-- round rather than coming back the short way.
		throwFinishCarryDeg = 120,
		-- Throttle is the second permission. Gas past throwThrottleHold with
		-- the car already past throwThrottleHoldFromDeg of drift keeps the
		-- controller alive with the lever out, so a slide started on the
		-- lever is held on the gas: full rear grip, no lever drag, the
		-- wheel still the dial. Lift and the car comes back. Throttle alone
		-- never starts a slide (the angle gate), so the planted numbers for
		-- turning under power are untouched.
		throwThrottleHold = 0.8,
		throwThrottleHoldFromDeg = 20,
		-- Once on, the gas permission survives the straight moment of a
		-- transition and only drops after this long under the gate with
		-- the wheel centred (or when the gas is lifted).
		throwThrottleHoldGraceSeconds = 0.5,
		-- The lever arms the gas permission as well, so a hand-off from the
		-- lever to the gas holds whatever angle the car has; once on it
		-- keeps down to this angle, a lower bar than starting.
		throwThrottleHoldKeepDeg = 10,
		-- Yaw damping while the car is NOT being thrown (no lever, no flick
		-- window), Nm per degree per second of yaw rate. A slip-angle tyre
		-- model has almost no yaw stiffness once both axles are sliding: the
		-- front and rear forces point the same way and their moments cancel,
		-- so a released slide kept rotating at a constant 110 deg/s all the way
		-- to 180 with full counter-steer applied. Real tyres self-align as
		-- the rear comes back; this stands in for that. Off under the lever
		-- (the controller holds the rate there). Raise it for a car that
		-- settles faster after a slide, lower it for one that swings further.
		slideYawDamping = 130,
	},

	handbrake = {
		-- Lowered from 0.35 alongside the softer rear falloff. The rear now
		-- holds far more grip a few degrees past peak, which slowed the pull
		-- from 0.24 s to 0.33 s to reach 20 deg; cutting deeper puts that back
		-- without touching the falloff that made the car stable.
		-- 0.4 is a locked tyre, not ice. It was cut to 0.08 to make the pull
		-- fast enough, and that is what made every slide unrecoverable: with
		-- no rear friction the yaw rate hit 176 deg/s by 28 degrees of drift
		-- and kept climbing after the lever was let go. A locked wheel keeps
		-- sliding friction that damps yaw. The throw impulse in `steering`
		-- now does the initiation work instead.
		rearGripMultiplier = 0.45,
		-- 2,000, down from 8,000: at 8,000 the lever alone was 0.5 g of drag,
		-- 11 km/h for every second of a spin, before the tyres scrubbed
		-- anything. The rotation no longer needs it; what is left is the
		-- locked-rear feel and a little speed bleed under the lever.
		brakeForce = 1000, -- N total on the rear axle
		-- Grip comes back over this long after the lever is let go instead of
		-- snapping back in one step, so releasing mid-slide reads as a hand-off
		-- to throttle rather than a jolt.
		-- A tapped handbrake will not complete a 360 at any setting here
		-- (measured 255-346 deg): once the car travels backwards the rears
		-- roll again and their grip kills the rotation. A held handbrake
		-- keeps them locked and comes round in ~3.4 s, which is the real
		-- Ta'geed technique. 0.4 keeps a release mid-slide soft.
		-- 0.2, down from 0.4: with the lever let go at 43 degrees and hands off,
		-- 0.4 s of a still-cut rear was enough to spin the car to 175.
		releaseSeconds = 0.15,
	},

	-- How the pedals work a slide (VehicleSim/DriftControl.luau). These are
	-- the Classic style's numbers; DriftStyles sets them per style (the
	-- owner, 2026-10-05: drift styles by drivetrain, and "the ability to
	-- kick off the exhaust during a drift"). None of it acts while the lever
	-- is in, so the lever's 360s, holds and catches are the same everywhere.
	drift = {
		-- The feather: a lift this short keeps a gas-held slide (it used to
		-- drop at once: a 0.25 s lift took 30 degrees to 1 a second later,
		-- measured 2026-10-05), with the angle moving this fast toward
		-- straight meanwhile (- grows it: front drive's lift-off oversteer).
		-- The gas back on inside it kicks kickDeg more angle over kickSeconds
		-- (- pulls it in: the fronts pull straight). Lifting longer than this
		-- is the catch, as before.
		featherSeconds = 0.3,
		-- 50 and 8 from 25 and 5: a hands-off catch (lift and centre) waits out
		-- the feather first, and at 25 it took 0.82 s against 0.53 before
		-- the feather; at 50 it takes 0.63-0.68, and a 0.2 s feather dips the
		-- slide 3 degrees and the kick puts back all but 1-2 (Play,
		-- 2026-10-05).
		featherDegPerSec = 50,
		kickDeg = 8,
		kickSeconds = 0.2,
		-- A gas-held slide's angle eases toward straight this fast (front
		-- drive's slides fade), and is kept between holdMinDeg and
		-- holdMaxDeg at holdEaseDegPerSec.
		holdDecayDegPerSec = 0,
		holdMinDeg = 0,
		holdMaxDeg = 180,
		holdEaseDegPerSec = 30,
		-- The lift throw (0 off): lifting fast with the wheel past
		-- liftThrowSteer at liftThrowMinKmh or more, before the car is
		-- sideways, throws it with this permission and the rear's grip times
		-- liftThrowRearGrip, for liftThrowSeconds. Lift-off oversteer.
		liftThrow = 0,
		liftThrowSeconds = 0.5,
		liftThrowMinKmh = 60,
		liftThrowSteer = 0.5,
		liftThrowRearGrip = 1,
		-- Power-over: past this much steer launch and traction control step
		-- aside (above 1: never), and the gas hold arms from
		-- steering.throwThrottleHoldFromDeg times gasHoldFromScale. With
		-- powerOverThrow above 0 the gas and that much wheel at
		-- powerOverMinKmh or more throw the car (that permission, the rear's
		-- grip times powerOverRearGrip) until the gas hold takes it.
		powerOverSteer = 2,
		powerOverMinKmh = 30,
		powerOverThrow = 0,
		powerOverRearGrip = 1,
		gasHoldFromScale = 1,
		-- Times the car's slide momentum relief (slipModel.slideRelief); the
		-- lever's (leverRelief) is left alone.
		slideReliefScale = 1,
	},

	twoWheel = {
		-- 20,000 from 12,000: the owner called the lift slow and heavy. With
		-- the roll damping it reached 30 degrees in about a second; this is
		-- about half that.
		-- 15,000. 18,000 was tried for a bigger first tip and came back as
		-- too strong and overwhelming, so this is back where it was.
		liftTorque = 15000, -- Nm extra while lifting
		-- 0.9 from 1.0: a fully cancelled pendulum is neutral and needs
		-- nothing from the driver. Leaving a tenth of gravity in makes the
		-- car want to come down the whole time, so it has to be worked.
		gravityCancel = 0.93, -- fraction of gravity's restoring torque cancelled while balanced (>1 leans off faster); 0.9 needed a tap every second
		targetRollDeg = 35, -- keep below atan(tire grip) or the base slides out from under the car
		-- Outward lean while balanced. Throttle already pushes the car outward
		-- on its own (only the grounded rear drives, so gas yaws the car away
		-- from the low side), so this stays small: at 400 the car leaned in at
		-- 12 deg/s under 0.4 throttle and a tap was erased in half a second.
		leanTorque = 150,
		instability = 8, -- Nm/deg extra outward push above targetRollDeg; 8 from 6 so a lean past the target runs away a little faster
		-- Spring about targetRollDeg while balanced, Nm per degree. Measured
		-- without it: holding Q at 90 km/h peaked at 37 degrees and sank
		-- back to 12 with the key still down, because the gravity cancel is
		-- a model and the real restoring torque was larger. The spring soaks
		-- up that error so the car holds; taps and steering move it about
		-- the hold. 0 restores the pure pendulum. Higher = stickier hold,
		-- less to do; lower = more balancing to do.
		-- 320 was a magnet: taps did nothing and holding the opposite key could
		-- not land the car. 120 covers the model error and leaves the rest to
		-- the driver.
		-- 90 from 160: less of a hold, more of a pendulum. The spring only
		-- has to cover the model error now that gravity itself does the
		-- pulling down.
		balanceSpring = 110,
		-- Symmetric: the spring holds the car near the target from both
		-- sides, so it hovers instead of going over. true is lift-only,
		-- which is what made a held key topple.
		balanceSpringOneSided = false,
		-- The spring winds down to balanceSpringFloor of itself over
		-- balanceSpringDecaySeconds with no tap toward the lifted side, and a
		-- tap winds it back to full. At the floor the model error wins and
		-- the car sinks home, so an ignored natl lands itself in a few
		-- seconds and a tap every couple of seconds keeps it up. Longer
		-- decay or a higher floor is a lazier ride; floor 1 never sinks.
		-- Measured at 90 km/h: a floor of 0.3 parked the ignored car at 15
		-- degrees for ever; 0.1 lets it come home.
		balanceSpringDecaySeconds = 3,
		balanceSpringFloor = 0.1,
		-- The gravity cancel winds down on the same envelope, to this
		-- fraction of itself. Needed because a fully cancelled pendulum is
		-- neutral at every angle: with the spring at its floor the ignored
		-- car hovered at 9 degrees instead of coming home. 0.8: at 0.85 the
		-- engine's extra torque on the grounded rear held an ignored car up
		-- for 7 s.
		balanceCancelFloor = 0.8,
		rollDamping = 60, -- Nm per deg/s; 60 from 80: 45 let a 20,000 lift overshoot to 58 degrees
		-- Lean input (Q/E, gamepad bumpers, touch LEAN buttons). Two gains
		-- because catching a lean needs more authority than adding to one.
		-- Sized against rollDamping: leanIn/rollDamping is roughly the degrees
		-- per second the car climbs while you hold the key, so 450/60 is about
		-- 7°/s in and 1800/60 about 30°/s back down.
		-- Taps have to compete with the two big levers the physics already
		-- gives the player: steering (a turn toward the low side drops the car,
		-- away lifts it) and throttle (only the grounded rear drives, so gas
		-- yaws the car away from the low side and holds it up). With the tap
		-- envelope a press lands its whole gain at once, then decays.
		leanInTorque = 5500, -- Nm at a fresh press toward the lifted side (go further up); a tap should visibly lift against the sag
		leanOutTorque = 4500, -- Nm at a fresh press toward the grounded side (come back down); 6000 dropped 16 degrees a tap, holding it lands the car
		tipRollDeg = 62, -- past this the mode releases and gravity finishes the fall (static tip is atan(halfTrack/comHeight) ≈ 56°)
		rimGripStartDeg = 42, -- roll where the tires start biting on rim/sidewall
		rimGripBoost = 0.7, -- extra grip fraction at full dig-in (10° past the start)
		landingDamping = 30, -- Nm per deg/s while coming down; 30 from 60 so the drop is a drop, not a float
		suspensionBias = 1.8, -- grounded-side stiffness multiplier while lifted
		-- Speed gates, like a real sidewall skier: nothing lifts at parking
		-- speed, full lift from fullLiftSpeedKmh, and the balance fades away
		-- below holdFadeSpeedKmh so a car that has slowed down settles.
		-- The owner's rule: nothing tips under 90 km/h. Full lift from 100.
		-- The hold fades out below 90 and is gone by 60, so a car that does
		-- not keep its speed up comes back down on its own, slowly.
		minLiftSpeedKmh = 90,
		fullLiftSpeedKmh = 100,
		holdFadeSpeedKmh = 60,
		-- Tap balance: a press gives its whole push at once, then decays
		-- toward leanHoldFloor over leanHoldDecaySeconds while held.
		-- Stabilise by tapping against the lean, not by holding.
		leanHoldDecaySeconds = 0.45,
		-- A fresh press ramps to full over this long rather than landing on
		-- one frame (with the tap boost, a tap jolted the roll rate by up to
		-- 106 deg/s in a step). Short enough that a tap still reads as a tap.
		leanAttackSeconds = 0.06,
		leanHoldFloor = 0.3,
		-- Same floor as the catch key: the in-key decays when held, so
		-- leaning on it stops pushing rather than carrying the car over.
		-- 1 makes a held key topple, which was tried and was too punishing.
		leanInHoldFloor = 0.3,
		-- The key toward the grounded side held this long is a landing, not a
		-- catch: the controller lets go and the car comes down. Measured
		-- without it, a held E got the car to 4 degrees and the spring then
		-- lifted it back to 11.
		landHoldSeconds = 0.5,
		-- The launch, the hang, the keep-up taps and the drop (the owner,
		-- 2026-09-24: "the first tap launches it into the tilt angle, later
		-- ones help keep it, and when it drops the bounce"). Measured before
		-- at 100 km/h: one tap reached 30 degrees in 0.49 s, overshot to 40.5
		-- at 0.79 and sank straight back, landing at 2.7 s; a tap every
		-- 1.5 s hovered at 9-15; the landing was lowered in and settled in
		-- 0.35 s with no rebound (0.95 degrees past level).
		-- Tried and taken out: easing the lift off near the target (the
		-- 39.6 peak is momentum, the easing moved it 0.9 degrees) and a
		-- full-spring hang after the handover (0.91 s above 28 against
		-- 0.75; the sag is the model error, not the spring winding down).
		-- A fresh tap toward the lifted side adds tapBoost of liftTorque,
		-- full once the car has sagged tapBoostFullDeg below the target and
		-- less the closer it is, fading over tapBoostSeconds. Nothing above
		-- the target, so tapping cannot flip it. At 0.5 sized by the sag as
		-- a fraction of the whole target, a tap at 25 degrees was 2,000 Nm
		-- and the car sagged 20 degrees a second between taps anyway.
		-- 0.6 over 0.5 s from 1 over 0.3 s (2026-09-24, the owner: taps
		-- "less jerky"); the carry below does the lingering now, so the
		-- boost only has to lift, not hold.
		tapBoost = 0.6,
		tapBoostFullDeg = 15,
		tapBoostSeconds = 0.5,
		-- The carry (the owner, 2026-09-24: "let the initial one carry out
		-- for a good amount, subsequent taps help it linger a bit more").
		-- After the launch the balance holds firmer for carrySeconds: all of
		-- gravity cancelled and carrySpring extra balanceSprings on top of
		-- the normal one, at full until the last carryFadeSeconds and then
		-- fading back to normal. A tap toward the lifted side opens a carry
		-- of carryTapSeconds. The catch key ends it. Measured before: one
		-- tap was above 25 degrees for 1.17 s and down at 2.6 s; a tap every
		-- 2 s was above 25 for 3 of 9 s. A spring that multiplied the normal
		-- one and faded over the whole carry barely helped (3x: 1.34 s above
		-- 25; 7x: 1.58; 21x: 2.1, holding 33 for a second and a half).
		carrySeconds = 2.5,
		carryTapSeconds = 1.2,
		carrySpring = 12,
		carryFadeSeconds = 1,
		-- The carry spring's torque is capped, so it holds near the angle but
		-- does not snatch a sagging car up (uncapped, a tap at 15 degrees
		-- jolted 214 deg/s in one step). The tap boost does the lifting.
		carryMaxTorque = 3000,
		-- Sagged under this with nothing pushing it up, the controller lets
		-- go and gravity drops the car, so it lands with speed (measured
		-- 66 deg/s at touchdown, against 20 when lowered all the way in).
		-- 0 lowers it all the way in, as before.
		dropReleaseDeg = 10,
		-- ...over this long, so the release is a fade, not a jolt (cut on one
		-- frame: 28 deg/s of roll-rate change in a step). A tap toward the
		-- lifted side during the fade catches it.
		dropFadeSeconds = 0.3,
		-- For touchdownSeconds after a two-wheel landing the suspension
		-- damping runs at touchdownDampingScale, so the drop rocks the car
		-- on its springs. With full damping it stopped dead: 1 degree past
		-- level, settled in 0.3 s. Only after a natl landing; ordinary
		-- driving never sees it.
		-- Smoothed (the owner, 2026-09-24: "smoothen out the jerk and the
		-- drop/post stop"): at 0.35 for 0.6 s and then snapping back, the
		-- touchdown hit 91 deg/s in a step and bounced the car back up to
		-- 11.8 degrees at 214 deg/s; now it starts at 0.6 and eases back to
		-- full damping across the window.
		touchdownSeconds = 0.8,
		touchdownDampingScale = 0.6,
		-- Steering is the strongest balance lever there is on two wheels: a
		-- turn toward the low side drops the car, away lifts it, and at 80 km/h
		-- a 0.3 s tap of 0.2 steer was enough to flip it. Scale the lock while
		-- lifted so a touch tap (which ramps to ~0.9 steer in 0.3 s) is a
		-- correction, not a roll-over. Measured at 0.35: a 0.5 tap away
		-- still tipped it; 0.22 leaves that as a catchable lean.
		steerScale = 0.3, -- 0.3 from 0.22: the wheel is the real balance lever and it should be felt
		-- Extra scale on a turn AWAY from the low side while lifted. That is
		-- the direction that flips the car; toward the low side is the catch
		-- and keeps the full steerScale.
		steerAwayScale = 0.5,
		-- Yaw damping while lifted, Nm per deg/s. The front-heavy spring yaw
		-- and any drive on the grounded rear turn the car; this is the
		-- driver's steady micro-corrections, so a natl can run straight.
		yawDamping = 250,
		sidePickLean = 0.2, -- |lean| above this picks the roll side; with none held the car rolls left
		sidePickRollDeg = 15, -- while lifting below this roll a lean the other way still flips the side
		balancedEntryMarginDeg = 5, -- lifting hands over to balancing this many degrees before targetRollDeg
		landedRollDeg = 3, -- below this roll the car counts as back on four wheels
	},

	input = {
		keyboardSteerRampPerSec = 4,
		keyboardSteerReturnPerSec = 8,
		-- Touch steer pad: the thumb's position across the pad is the steer
		-- angle. Full lock at touchPadFullAt of the half-width, nothing inside
		-- the deadzone, curve > 1 for finer control near centre, and the wheel
		-- follows the thumb at touchSteerRatePerSec (1/s of full lock).
		touchSteerRatePerSec = 8,
		touchPadDeadzone = 0.06,
		touchPadFullAt = 0.8,
		touchPadCurve = 1.3,
		-- Lean slider (two-wheel only): how far it must travel from centre
		-- before it counts as a lean, as a fraction of its half-width. The
		-- slider springs back, so a flick out and back is one tap.
		touchLeanDeadzone = 0.25,
		touchScale = 1, -- overall size of the touch controls
		gamepadDeadzone = 0.12,
		triggerDeadzone = 0.05,
	},

	camera = {
		positionLag = 8, -- 1/s, how fast the camera position catches up
		directionLag = 4, -- 1/s, how fast the look direction catches up
		profileBlendRate = 3, -- 1/s, how fast profile parameters cross-fade
		minSpeedForSwingMps = 3, -- below this the camera ignores the velocity direction
		driftProfileEnterDeg = 25, -- |drift angle| that switches to the drift profile
		driftProfileExitDeg = 12, -- and back to normal (hysteresis)
		-- Profiles: normal driving, sliding, and two-wheel. All distances in
		-- metres. lateralOffset is toward the lifted side while on two wheels
		-- (so the airborne wheels are in frame), toward the outside of the
		-- slide otherwise. rollFollow tilts the horizon with the car's roll.
		profiles = {
			normal = {
				distance = 7.5,
				height = 2.6,
				lookHeight = 0.8,
				lateralOffset = 0,
				driftSwing = 0.3, -- 0 follow heading, 1 follow velocity
				baseFov = 70,
				fovPerKmh = 0.08,
				maxFov = 85,
				rollFollow = 0,
			},
			drift = {
				distance = 8.5,
				height = 3.0,
				lookHeight = 0.8,
				lateralOffset = 0,
				driftSwing = 0.7,
				baseFov = 74,
				fovPerKmh = 0.08,
				maxFov = 88,
				rollFollow = 0,
			},
			twoWheel = {
				distance = 8.0,
				height = 2.0,
				lookHeight = 1.0,
				lateralOffset = 2.5,
				driftSwing = 0.15,
				baseFov = 72,
				fovPerKmh = 0.05,
				maxFov = 82,
				rollFollow = 0.35,
			},
		},
	},

	road = {
		lengthM = 2000, -- straight
		widthM = 60,
		thicknessM = 1,
		dashLengthM = 6,
		dashGapM = 6,
		dashWidthM = 0.3,
		curveRadiusM = 400,
		curveSweepDeg = 30,
		curveSegments = 24,
		-- Transition pad: a wider stretch of the straight for left-right swings.
		padStartM = 900, -- distance from the start line
		padLengthM = 400,
		padWidthM = 160, -- total width including the road
		bayLengthM = 40,
		groundTileM = 500,
	},

	spawn = {
		-- Players start on foot and pick a car from the spawn menu. true
		-- parks their car in the bay at join instead, the Phase 0 way.
		autoSpawnOnJoin = false,
		-- Shortest gap between two spawn requests from one player.
		spawnCooldownSeconds = 1.5,
		-- Which CarCatalog car a player gets unless their "CarId" attribute
		-- names another. nil means the catalog's own default.
		carId = nil :: string?,
		-- Show the rig's collision box, ray origins and hubs as translucent
		-- parts over the body. For checking a new car's fit.
		showRig = false,
		spawnHeightM = 0.45, -- above rest height; the car drops and settles on spawn
		-- Leaving a car puts the driver beside the driver's door (ExitSpot):
		-- this much clear space from the car's side, and this far above the
		-- chassis centre so they land on their feet. The owner exited right
		-- under the car (2026-09-27).
		exitGapM = 1.0,
		exitLiftM = 0.5,
		slotStartM = -18, -- first bay slot, lateral; ten slots at the spacing must fit the bay width
		slotSpacingM = 4,
		settleSpeedMps = 0.5, -- a driverless car below this speed...
		settleSeconds = 1, -- ...for this long gets anchored
		fallBelowM = 30, -- a car this far under the road surface is re-parked
	},

	-- Auto-flip (client AutoFlip, shared AutoFlip). Asked by the owner on
	-- 2026-10-04: "flips the car back over if it capsizes", seamlessly and
	-- naturally. A car you are driving that lies past tiltDeg (on its side or
	-- roof) and has come to rest for settleSeconds rolls back onto its wheels
	-- over its own edge, keeping its heading, in flipSeconds per 90 degrees of
	-- roll. The R reset (back to the road) is unchanged.
	autoFlip = {
		enabled = true,
		-- 75: well past a natl, which balances at 35 and lets go at 62
		-- (twoWheel.targetRollDeg / tipRollDeg), so a held natl never trips it.
		-- Capsized also means no wheel on the ground.
		tiltDeg = 75,
		-- Rolling it back (owner, 2026-10-04: the scripted roll was "to
		-- robotic"; "if i get into a flipped (upside down or flat state) i
		-- can like turn my wheels to reflip back to normal", and not wait).
		-- A capsized car resting on something is rolled by a real torque
		-- about its long axis while you steer: on its side either way rolls it
		-- back up the short way, on its roof (past roofChoiceDeg of roll) the
		-- way you steer picks the side it goes over. It heaves up off its
		-- edge, tips past the balance point and drops onto its springs; let
		-- go and it falls back. Untouched, after settleSeconds at rest it
		-- rolls itself the short way.
		steerDeadzone = 0.15,
		roofChoiceDeg = 135,
		-- It rolls at about this rate (degrees a second).
		rollRateDegPerSec = 120,
		-- How hard it chases that rate (per second; high, so it pushes at
		-- the cap until it is rolling) and the most torque it may use, as a
		-- multiple of what holds the car's weight at half its height off the
		-- edge it pivots on. At 2 it jumped to 115 deg/s within 0.05 s, which
		-- read as a machine (Studio, 2026-10-04); 1.5 and a push that builds
		-- over rollRampSeconds heave it up instead.
		rollGain = 20,
		rollTorqueG = 1.5,
		rollRampSeconds = 0.35,
		-- It lets go once this upright, and gravity and the springs finish.
		releaseTiltDeg = 40,
		-- Only a car lying on something can be rolled, so a tumble through
		-- the air can't be steered: the car's centre within half its
		-- cross-section's diagonal plus this of the ground, slower than
		-- rollMaxSpeedMps. That was 6 m/s, and a car on its roof slid a long
		-- way before it got that slow (owner, 2026-10-04: "make it so that i
		-- can flip back before coming to a complete halt ... right now i have
		-- to wait/slide quite a distance"): 40 lets it be rolled while it
		-- still slides. Rolling itself still waits for it to stop (restSpeedMps).
		groundGapM = 0.5,
		rollMaxSpeedMps = 40,
		-- And a roll only starts once it has stopped falling (m/s down).
		rollMaxFallMps = 1.5,
		-- If rolling itself hasn't got it up in this long (wedged against a
		-- wall, say), the scripted roll below takes over as a last resort.
		giveUpSeconds = 3,
		-- At rest means slower than this, turning slower than this, for this
		-- long: the roll has finished and the car is not about to right itself
		-- or still sliding on its side. Long enough to read as "it's over",
		-- short enough not to feel like waiting.
		restSpeedMps = 2,
		restSpinDegPerSec = 45,
		settleSeconds = 0.8,
		-- The scripted roll (last resort): 0.75 s for a car on its side, 1.5 s
		-- off its roof.
		flipSecondsPer90 = 0.75,
		-- Kept between its lowest corner and the ground while it rolls, so the
		-- edge it pivots on doesn't scrape through; 0 at the start and the landing.
		clearanceM = 0.03,
		-- After a flip it waits this long before it can flip again, so a car
		-- that lands on a slope and tips once more isn't flipped back and forth.
		cooldownSeconds = 2,
		-- Where it would stand up must be clear of walls, pillars and other
		-- cars. These sideways shifts (metres along its right) are tried in
		-- turn; if none is clear it stays down and R resets it.
		clearShiftsM = { 0, 0.5, -0.5, 1, -1, 1.5, -1.5, 2.2, -2.2 },
	},

	-- Drift feedback on the client: tire smoke, skid marks, and wheel models
	-- that spin up when driven loose or stop when locked. Purely visual; the
	-- physics never reads any of this.
	effects = {
		enabled = true,
		-- Below this speed there are no skid marks and no screech (smoke has
		-- its own rules below: a burnout smokes standing still).
		smokeMinSpeedMps = 3,
		-- White tyre smoke (client TireSmoke, shared TireHeat; owner,
		-- 2026-10-04: "create white tiresmoke while drifting", then "a fully
		-- comprehensive tire smoke system" that fades in and out "at
		-- appropriate times (i.e. drifting, starting stopping etc.)"). It was a
		-- faint grey (215 to 170, 0.55 see-through), driven by rear slip
		-- angle, only on your own car, and its sizes were passed to Roblox as
		-- studs, so the "1.6 m" puff was 0.45 m.
		--
		-- Real smoke is the tread vaporising once sliding has heated it, so
		-- each wheel has a heat: it rises with how fast the contact patch
		-- slides over the road (sideways in a drift, spinning in a burnout,
		-- dragged in a lock-up), cools when it grips, and the smoke follows
		-- the heat. All four wheels; everyone sees every car's smoke.
		tireHeat = {
			-- What a gripping tyre takes up without its tread sliding: a few
			-- degrees of slip angle, a few percent of spin or lock. Only the
			-- motion beyond it is sliding. Without it, plain cornering at 40
			-- km/h (fronts at 7 degrees, measured) slid 1.35 m/s and fast
			-- grippy corners would have smoked.
			gripSlipDeg = 8,
			gripSlipRatio = 0.12,
			-- Share of a front tyre's sideways slide that heats it. Owner,
			-- 2026-10-04: "tone it down a bit" (0.4: then the fronts smoked
			-- only when truly sideways), then "the front wheels have no tire
			-- smoke, make it more like it was before", with the front on the
			-- camera's side smoking: back to 1. In a drift the chase camera
			-- looks at the outside of the turn, and the outside front carries
			-- the weight, so it is the one that smokes (the far one less, and
			-- the body hides it). Sideways only: a front lock-up under braking
			-- (all along the tyre) smokes in full whatever this is.
			frontSideShare = 1,
			-- The two fronts take each other's load share (TireHeat.loadShares),
			-- so their smoke is the other way round: the front that would
			-- smoke hardest (the loaded outside one) smokes least, and the
			-- light inside one most. Owner, 2026-10-04: "the way the front 2
			-- tires smoke works, reverse it". false puts it back.
			frontLoadSwap = true,
			-- Slide speed (m/s, beyond the grip's share) where the tread
			-- starts heating, and where it heats flat out. 9: a committed
			-- drift at 60 km/h slides the rears about 7-9 m/s sideways past
			-- grip; a burnout's tread runs past it.
			slideStartMps = 1.5,
			slideFullMps = 8,
			-- Heating and cooling (per second). With these a full slide
			-- starts smoking after about 0.15 s and is at full smoke after
			-- about 0.7 s; once it grips, the wisps die away over about 1 s.
			-- Faster heating = smoke snaps on; slower cooling = longer tails.
			heatPerSec = 2.2,
			coolPerSec = 1.3,
			smokeHeat = 0.3, -- heat (0..1) where smoke starts
			wisp = 0.18, -- share of smoke a hot tyre keeps giving off once it grips again
		},
		-- How it looks (owner, 2026-10-04, second pass: "not bad but could
		-- definately be a lot better, more accurate and realistic"). The first
		-- pass drew Roblox's built-in smoke_main.dds: a 128 px grey blob that
		-- is never more than a third opaque, so however it was tinted it read
		-- as a soft grey ball. This is Roblox's own realistic smoke texture
		-- (from their volcano VFX tutorial): wispy, turbulent, near white. If
		-- it ever fails to load the built-in one stands in.
		smokeTexture = "rbxassetid://16830673704",
		smokeTextureFallback = "rbxasset://textures/particles/smoke_main.dds",
		smokeColor = Color3.fromRGB(255, 255, 255), -- at the tyre
		smokeColorEnd = Color3.fromRGB(232, 234, 238), -- as it thins out, a touch of blue-grey
		-- How much the scene's light tints it, and how much it glows by itself.
		-- Golden hour greys smoke that takes the scene's light fully (0.55
		-- influence with no glow read as fog in Studio, 2026-10-04).
		smokeLightInfluence = 0.25,
		smokeLightEmission = 0.12,
		-- The texture is a light warm grey at its brightest, and lit from
		-- behind at sunset the cloud read grey; 1.5 brings it back to white
		-- (Studio, 2026-10-04). Smoke only; dust keeps its ground colour.
		smokeBrightness = 1.5,
		-- Road smoke, from the tyre outward (drift footage; racing-sim smoke
		-- threads: it "doesn't have much velocity", "just hangs in the air,
		-- slowly ascending and dissolving"):
		--   trail: the fresh smoke, born where the tyre touches the road and
		--     left lying along its track;
		--   wisp: the trail's light twin, filling the stretches the trail
		--     leaves when the level is low;
		--   billow: the softer cloud it spreads into, rising slowly;
		--   haze: a faint bank left hanging for a few seconds on the breeze.
		-- Owner, 2026-10-04 (third pass): on the road it was "patchy", it
		-- "bursts clouds and doesn't follow the wheels", and "a bit too much
		-- ... smoke and opacity". It was thrown up to 6 m/s off the tread,
		-- emitted at a fixed rate a second with the rate swelling and dipping
		-- by 0.6 (so at 70 km/h puffs landed 1-2 m apart, in bunches), and
		-- born at the wheel's rest height whatever the springs were doing. Now
		-- each layer is laid by distance (shared TireHeat.puffRate: one puff
		-- every 1 / perMetre metres the tyre travels, never fewer than
		-- perSecond, for a burnout), born at the live contact patch and barely
		-- thrown, and thinner throughout.
		-- Per layer: `perMetre` and `perSecond` at full smoke, times the
		-- smoke level to `power` (2: only a real slide billows); `sizeM` at
		-- birth, a quarter of the way through and at the end (it spreads
		-- fastest at first); `transparency` at birth and halfway (clear at the
		-- end), reached `fadeIn` of the way through its life; `throw` the share of the tread's slide velocity it leaves with,
		-- up to `maxSpeedMps`; `drag` how many times a second it loses half
		-- its speed (Roblox's Drag); `riseMps` the speed it settles into
		-- climbing; `inherit` the share of the car's own velocity it keeps;
		-- `squash` at birth, a third of the way and at the end (Roblox's
		-- Squash: below 0 is wider than tall). A puff is a flat card facing
		-- the camera, and a round one low over the road cuts into it in a
		-- hard line; flattened, the cloud spreads along the road like real
		-- smoke settling, and the line all but goes (Studio, 2026-10-04).
		--
		-- The cost is the screen area the puffs cover, not their number: the
		-- second pass's first sizes (up to 5 and 8.5 m) took four tyres at full
		-- round a parked car from a 16.6 to a 38.4 ms median frame on the Mac.
		smokeLayers = {
			trail = {
				perMetre = 3,
				perSecond = 14,
				power = 1,
				lifetime = { 0.8, 1.3 },
				sizeM = { 0.35, 0.9, 1.7 },
				transparency = { 0.45, 0.72 },
				fadeIn = 0.06,
				throw = 0.12,
				maxSpeedMps = 1.5,
				spreadDeg = 20,
				drag = 3,
				riseMps = 0.25,
				inherit = 0,
				rotSpeedDeg = 30,
				squash = { 0, -0.2, -0.2 },
			},
			-- The trail's light twin: let out at its own rate times (1 - level),
			-- so with the trail's (times level) every stretch of road gets a
			-- puff, full or light, whatever the level. A fading slide thins
			-- to wisps instead of breaking into dots (owner, 2026-10-04: "make
			-- sure it is continuous also").
			wisp = {
				perMetre = 3,
				perSecond = 14,
				power = 1,
				lifetime = { 0.6, 1 },
				sizeM = { 0.25, 0.6, 1.1 },
				transparency = { 0.75, 0.88 },
				fadeIn = 0.06,
				throw = 0.12,
				maxSpeedMps = 1.5,
				spreadDeg = 20,
				drag = 3,
				riseMps = 0.25,
				inherit = 0,
				rotSpeedDeg = 30,
				squash = { 0, -0.2, -0.2 },
			},
			billow = {
				perMetre = 1,
				perSecond = 5,
				power = 2,
				lifetime = { 2, 3 },
				sizeM = { 0.6, 1.8, 3.2 },
				transparency = { 0.6, 0.82 },
				-- Seen only once it has grown into the trail, so the cloud
				-- never shows as separate small balls.
				fadeIn = 0.18,
				throw = 0.1,
				maxSpeedMps = 1,
				spreadDeg = 40,
				drag = 1.5,
				riseMps = 0.4,
				inherit = 0,
				rotSpeedDeg = 12,
				squash = { 0, -0.4, -0.25 },
			},
			haze = {
				perMetre = 0.08,
				perSecond = 0.5,
				power = 2,
				lifetime = { 4, 6 },
				sizeM = { 2, 3.5, 4.5 },
				transparency = { 0.88, 0.93 },
				fadeIn = 0.2,
				throw = 0.03,
				maxSpeedMps = 0.4,
				spreadDeg = 180,
				drag = 0.6,
				riseMps = 0.25,
				inherit = 0,
				rotSpeedDeg = 5,
				squash = { -0.2, -0.35, -0.5 },
			},
		},
		-- Below this level the wisps thin out as well (TireHeat.streamShares),
		-- so a stream that is dying ends gently instead of stopping dead.
		smokeWispTaper = 0.15,
		-- Travel counted for laying smoke stops here (m/s), so a very fast
		-- slide doesn't pour out puffs without end.
		smokeTravelCapMps = 30,
		-- Fresh smoke rolls up off the road at this angle, not skimming it.
		smokePitchDeg = 10,
		-- The level the puffs are laid at eases toward the heat model's over
		-- these times (up, down), so a tyre whose load or slip flickers over
		-- a bump doesn't stutter puffs out in bursts.
		smokeAttackSeconds = 0.1,
		smokeReleaseSeconds = 0.3,
		-- The breeze the smoke drifts on, m/s along world X and Z. North is
		-- -Z (the sunset is on the left of a car heading down -Z, so west is
		-- -X); Riyadh's prevailing shamal comes from the north-north-west, so
		-- this blows it gently south-south-east. Smoke only: the world's
		-- GlobalWind (sky clouds) is untouched.
		smokeWindMps = { 0.4, 1.0 },
		-- Each puff is drawn this far toward the camera. It was 0.84 m, to keep
		-- big low puffs from cutting into the road in a hard line, but that
		-- also drew smoke up to 0.84 m behind the car's body in front of it:
		-- a far front wheel's smoke showed through the bonnet and wing while
		-- turning (owner, 2026-10-04: smoke "should only come from the wheels
		-- that are visable to me", the far one's "should not be visable
		-- through the car"). At 0.15 the body hides what is behind it, and
		-- the flattened, slowly rising puffs no longer cut the road (Studio,
		-- four tyres at full, chase view). Dust keeps its own 0.84.
		smokeZOffsetM = 0.15,
		-- Off the road: a tyre on sand or dirt doesn't smoke (it never grips
		-- hard enough to cook its tread), it throws the ground up as dust, at
		-- once, the colour of what it is on (a little paler: fine dust in the
		-- air). `amount` is when (shared TireHeat.dust): sliding from
		-- slideStartMps, full at slideFullMps; rolling fast lifts a thin trail
		-- too (up to rollMax at rollFullMps). It eases in over attackSeconds
		-- and settles over releaseSeconds. The ground under each tyre is
		-- checked by a ray, a few times a second.
		dust = {
			amount = {
				slideStartMps = 1,
				slideFullMps = 6,
				rollStartMps = 8,
				rollFullMps = 30,
				rollMax = 0.3,
			},
			attackSeconds = 0.08,
			releaseSeconds = 0.4,
			materials = {
				Enum.Material.Sand,
				Enum.Material.Ground,
				Enum.Material.Grass,
				Enum.Material.LeafyGrass,
				Enum.Material.Mud,
				Enum.Material.Snow,
				Enum.Material.Salt,
			},
			lighten = 0.3, -- share of the way from the ground's colour to white
			-- Its own look, copied from the smoke's when the owner signed it
			-- off (2026-10-04: on sand "it is perfect so preserve the way it
			-- works on sand exactly as is"), so tuning the road smoke never
			-- moves it: texture, light (influence, glow, brightness), how far
			-- toward the camera it is drawn, the breeze, the angle it is
			-- thrown up at, and its rate puffing by up to `pulse` about
			-- `pulseHz` times a second.
			texture = "rbxassetid://16830673704",
			lightInfluence = 0.25,
			lightEmission = 0.12,
			brightness = 1,
			zOffsetM = 0.84,
			windMps = { 0.4, 1.0 },
			pitchDeg = 15,
			pulse = 0.6,
			pulseHz = 1.8,
			layer = {
				rate = 28,
				power = 1,
				lifetime = { 1, 2 },
				sizeM = { 0.4, 1.6, 3.2 },
				transparency = { 0.3, 0.6 },
				throw = 0.55,
				maxSpeedMps = 7,
				spreadDeg = 35,
				drag = 2.2,
				riseMps = 0.1, -- fine dust barely climbs; it hangs and drifts
				inherit = 0,
				rotSpeedDeg = 20,
				squash = { 0, -0.3, -0.3 },
			},
		},
		-- The driver's client sends its four smoke levels to the server at
		-- most this often, and only when they change; the server puts them on
		-- the car for everyone (CarControls, TireSmoke attribute).
		smokeRelayHz = 10,
		-- Other players' cars smoke within this distance of the camera.
		remoteSmokeMaxM = 150,
		-- Smoke is the costliest effect on a phone (overdraw). Below this
		-- graphics quality level (1-10) the rates are scaled down by
		-- lowQualitySmokeScale.
		lowQualityLevel = 4,
		lowQualitySmokeScale = 0.5,
		skidSlipDeg = 9, -- lay rubber above this slip angle, or whenever the wheel is saturated
		skidLifetime = 8, -- seconds a mark stays on the road
		skidTransparency = 0.45,
		wheelSpinUpRate = 6, -- 1/s, how quickly a spinning wheel model winds up to engine speed
		-- Audio. Free Creator Store loops, checked to load and play in this
		-- place: the screech is zdjack's "skid_loop_01" (4842084452, 1.7 s)
		-- and follows rear slip. Empty ids play nothing.
		screechSoundId = "rbxassetid://4842084452",
		-- Mellowed a lot at the owner's request (2026-09-22, "remove the
		-- screechy tire noise or mellow it out a lot more"): a third of the
		-- old 0.6 volume, pitched down (was 0.9 to 1.3), highs cut, and it
		-- starts at 18 degrees of rear slip instead of smoke's 10, so a
		-- brisk corner is quiet and only a real slide is heard. Wheelspin
		-- alone holds it at screechSpinLevel (was 0.7).
		screechMaxVolume = 0.2,
		screechSlipStartDeg = 18,
		screechSlipFullDeg = 45,
		screechSpinLevel = 0.3,
		screechMinPitch = 0.8,
		screechMaxPitch = 0.95,
		screechEq = { 0, -3, -12 }, -- dB low, mid, high
		-- The engine: four layers crossfaded by rpm and throttle (client
		-- EngineAudio). Idle fades out just above idle rpm; low load hands
		-- to high load across loadBlendStartRpm..EndRpm; off throttle the
		-- two load layers hand to overrun. Each layer plays at
		-- (rpm / refRpm) ^ pitchExponent, so a real recorded loop wants its
		-- recorded rpm as refRpm and an exponent of 1.
		--
		-- The owner picked the SR20 set (2026-09-23): RedfieldBSAA's free
		-- "240sx" loops, a petrol four-cylinder recorded on and off throttle
		-- at fixed rpms, each checked to load in this place. refRpm is the
		-- rpm in each file's name. Other sets considered are listed on the
		-- engine-loops page; any of them swaps in by id and refRpm alone.
		-- Before this, all four layers were one free loop told apart by EQ
		-- ("Car-Engine-Loop", 80317022777602) at exponent 0.55. Layers that
		-- share an id still share one Sound and blend its EQ.
		engineAudio = {
			masterVolume = 0.5, -- the old single loop peaked at 0.5
			pitchExponent = 1, -- 1 = pitch exactly proportional to rpm
			idleFadeRpm = 700, -- idle is gone this far above idleRpm
			loadBlendStartRpm = 2500, -- low load starts handing to high load
			loadBlendEndRpm = 5000, -- and is gone by here
			gainSmoothSeconds = 0.05, -- de-click only; longer lags throttle
			-- The throttle the layers hear. Pressing blends to the on-load
			-- layers over loadAttackSeconds; lifting hands to overrun over
			-- loadReleaseSeconds, so the engine tapers off instead of
			-- dropping to half volume in one frame (measured before: 0.50 to
			-- 0.24 inside 50 ms; the owner, 2026-09-23: "the engine doesn't
			-- just go mute immediately, there is a taper"). Pops, punch and
			-- blips still read the pedal itself.
			loadAttackSeconds = 0.08,
			loadReleaseSeconds = 0.4,
			-- volume is relative to masterVolume; eq is dB {low, mid, high}.
			layers = {
				idle = { soundId = "rbxassetid://18964098649", refRpm = 1000, volume = 0.45, eq = { 0, 0, 0 } },
				lowLoad = { soundId = "rbxassetid://18964097758", refRpm = 2000, volume = 0.8, eq = { 0, 0, 0 } },
				highLoad = { soundId = "rbxassetid://18964096622", refRpm = 5000, volume = 1, eq = { 0, 0, 0 } },
				overrun = { soundId = "rbxassetid://18964097591", refRpm = 4000, volume = 0.5, eq = { 0, 0, 0 } },
			},
			-- One-shot events on top of the layers, each set off by the sim's
			-- own gear, rpm and throttle (the owner picked these four,
			-- 2026-09-22). Multipliers apply to every layer at once.
			--
			-- Upshift: the engine drops to shiftDipGain for shiftDipSeconds,
			-- the torque cut you hear on a real automatic. shiftSoundId adds
			-- a mechanical thunk; empty for now, the store had nothing that
			-- was not a metal crash.
			shiftDipGain = 0.55,
			shiftDipSeconds = 0.12,
			shiftSoundId = "",
			shiftSoundVolume = 0.4,
			-- Downshift off throttle: a rev-match blip, pitch up by blipPitch
			-- (a fraction) over blipRiseSeconds, back down over
			-- blipFallSeconds, a little louder while it lasts.
			blipPitch = 0.15,
			blipRiseSeconds = 0.05,
			blipFallSeconds = 0.3,
			-- Overrun crackle: lifting from above crackleLiftFrom throttle
			-- while over crackleMinKmh and crackleMinRpm fires a burst of
			-- exhaust pops. The owner (2026-09-22): only when going fast and
			-- letting off; the stray pops while coasting and braking are gone.
			-- (Single pops on hard upshifts and the limiter exist below, off
			-- by default under this ruling.) How the burst comes, sounds and
			-- looks is the exhaust style's (ExhaustStyles, 2026-10-04: the
			-- owner asked for "way cooler" flames and audio "like the
			-- sputter"); the garage round 2 pop and its 1-3 pops in 0.5 s
			-- are the Classic style. A lift from higher revs pops more: the
			-- burst's size is crackleRevFloor at crackleMinRpm, rising to all
			-- of it at the redline (ExhaustStyles.revFactor).
			crackleMinRpm = 4000,
			crackleMinKmh = 80,
			crackleLiftFrom = 0.6,
			crackleRevFloor = 0.6,
			-- The drift flutter: a lift with the car at least this far
			-- sideways and this fast fires the exhaust style's flutter instead
			-- of its burst (ExhaustStyles), at any revs, so feathering
			-- mid-drift flutters the flames while the drift carries on
			-- (drift.featherSeconds). The owner, 2026-10-05: "kick off the
			-- exhaust during a drift where the flames would also flutter".
			driftFlutterFromDeg = 12,
			driftFlutterMinKmh = 40,
			-- Single pops, each with its exhaust flame: an upshift from above
			-- crackleShiftRpm pops with crackleShiftChance, and sitting on the
			-- limiter pops about crackleLimiterPerSecond times a second, both
			-- times the exhaust item's crackleChance. The round-2 design
			-- (2026-09-28) asked for them, but the owner's 2026-09-22 ruling
			-- stands: pops only when going fast and letting off. So both are 0,
			-- off, by default; turning them on is the owner's call. 6000 rpm is
			-- a full-throttle shift (the box shifts at 6400), never a
			-- short-shift; about 0.35 and 1.2 were tried in Play (twin tips:
			-- two upshift pops in 9 s of full throttle).
			crackleShiftRpm = 6000,
			crackleShiftChance = 0,
			crackleLimiterPerSecond = 0,
			-- Punch, in sound only (the owner, 2026-09-22: getting back on
			-- the gas should rev it back up, the punch depending on speed).
			-- The sim's rpm is locked to the wheels, so this is an rpm offset
			-- for the audio, like a torque converter's slip. Pressing the
			-- throttle kicks the note up by punchRpm (times how far the pedal
			-- moved), falling back over punchDecaySeconds. The kick is full
			-- up to punchFullKmh and tapers to punchMinFactor by
			-- punchFadeKmh, since a slipping converter flares most at low
			-- speed. Lifting off has no offset: the owner wanted the
			-- slowdown natural, so the note falls only as the sim's rpm does
			-- (a 300 rpm artificial sag was tried and taken out).
			punchRpm = 1100,
			punchDecaySeconds = 0.5,
			punchFullKmh = 40,
			punchFadeKmh = 160,
			punchMinFactor = 0.35,
			-- Rev limiter: on throttle within limiterBandRpm of redline the
			-- engine cuts in and out limiterHz times a second, down to
			-- limiterDipGain. The gearbox upshifts at 6400, so in drive this
			-- is mostly wheelspin on a launch or in a slide, and reverse.
			-- Softened on the slide-gearbox branch (2026-09-23): 16 Hz hard
			-- cuts to 0.35 were a harsh buzz. Now each cut eases in and out
			-- (a raised cosine), about 11 a second, down to 0.6, with the
			-- pitch sagging limiterPitchDip at the bottom of each cut.
			limiterBandRpm = 100,
			limiterHz = 11,
			limiterDipGain = 0.6,
			limiterPitchDip = 0.04,
			-- Ignition, from the store Camry's own A-Chassis sounds (the owner,
			-- 2026-09-25: keep the engine sets, ignition, horn and start
			-- chime from the store cars' scripts). Getting in plays the chime
			-- for chimeSeconds (the file is a 5.5 s sequence; its first chime
			-- is enough), the starter startDelaySeconds later, and the engine
			-- layers fade in over fadeSeconds once crankSeconds have passed,
			-- so the car is heard starting rather than already running.
			-- Getting out plays offSoundId. Empty ids skip that sound.
			chimeSoundId = "rbxassetid://6183854229",
			chimeVolume = 0.35,
			chimeSeconds = 1.1,
			startSoundId = "rbxassetid://1235894410",
			startVolume = 0.8,
			startDelaySeconds = 0.35,
			crankSeconds = 0.9,
			fadeSeconds = 0.5,
			offSoundId = "rbxassetid://203785492",
			offVolume = 0.5,
		},
		-- The horn: H held (ButtonL3 on a pad). Played on the server so every
		-- player hears it, looped while held. From the store Camry's scripts;
		-- a car overrides the id in its tuning (the Kruzer 80 has its own).
		horn = {
			soundId = "rbxassetid://4896498829",
			volume = 0.8,
			rollOffMaxDistance = 300, -- studs
		},
		-- Lamps (CarLamps). G toggles the headlights (DPad up on a pad); the
		-- brake lights follow the brakes and the reverse lights the gear, and
		-- every player sees them (the server copies them onto the car).
		-- Plain lamp pieces (named by role: HeadLamps, TailLamps,
		-- ReverseLamps) turn Neon in these colours; a textured lamp piece
		-- drops its texture while lit (a texture hides the glow).
		-- Tail lamps sit at tailColor with the headlights on and brighten to
		-- brakeColor under braking. Only the lamps themselves light: no beams
		-- or glow on the ground (owner, 2026-09-25).
		lamps = {
			headlightsOnAtStart = true, -- the world is at sunset
			headColor = Color3.fromRGB(255, 244, 222),
			tailColor = Color3.fromRGB(130, 8, 10),
			brakeColor = Color3.fromRGB(255, 26, 26),
			reverseColor = Color3.fromRGB(245, 245, 240),
		},
	},

	-- Drift scoring. A slide opens past minAngleDeg above minSpeedKmh and
	-- banks after graceSeconds of going straight. See TUNING.md; the last
	-- block is server-side validation and is not a feel knob.
	scoring = {
		minAngleDeg = 12, -- drift angle a slide needs to stay open
		minSpeedKmh = 30, -- and the speed it needs
		graceSeconds = 1.2, -- straight for this long banks the slide
		spinOutSpeedKmh = 12, -- dropping under this mid-slide is a spin-out
		impactDecelKmhPerSec = 250, -- a sustained decel this hard is a crash
		impactSmoothSeconds = 0.15, -- window the speed drop is measured over
		-- Points per second at referenceAngleDeg and referenceSpeedKmh, x1.
		pointsPerSecond = 100,
		referenceAngleDeg = 45,
		referenceSpeedKmh = 100,
		maxAngleFactor = 2.5, -- ceiling on angle / referenceAngleDeg
		chainStep = 0.5, -- each direction change adds this to the multiplier
		chainMax = 5,
		minBankPoints = 50, -- anything smaller banks silently
		-- A completed 360 (the drift angle travelling a full turn inside one
		-- slide) adds this, times the chain multiplier, to the slide. About
		-- what two seconds fully sideways at 100 km/h pays, so a Ta'geed is
		-- worth roughly double the same time spent in a plain slide.
		spinBonusPoints = 500,
		-- Two wheels: past this roll the run pays natlPointsPerSecond at
		-- referenceSpeedKmh, scaled by speed, on top of any drift points.
		-- A natl at 90 km/h is worth about what a 30-degree slide is.
		natlMinRollDeg = 15,
		natlPointsPerSecond = 80,
		cashPerPoint = 0.01,
		-- Validation. The server scores every driven car from its own
		-- samples and never banks more than it saw.
		maxPlausibleSpeedKmh = 320,
		teleportToleranceM = 8, -- movement beyond speed x dt plus this is a teleport
		serverTolerance = 1.25, -- how far a claim may exceed the server's own total
		claimWindowSeconds = 1.5, -- how long a claim stays usable
		sampleHz = 20, -- server sampling rate
		autosaveSeconds = 120, -- cash autosave interval
	},

	-- Driver HUD: speed, gear, drift angle, spins, natl roll, live slide
	-- score, cash and records. Top centre.
	hud = {
		enabled = true,
		driftHighlightDeg = 20, -- the drift readout lights up from here
		scale = 1, -- overall HUD size
		flashSeconds = 2, -- how long a banked or dropped slide stays on screen
	},

	debug = {
		enabled = true,
		showOnTouch = false, -- hidden on phones until the DBG button is tapped
		updateHz = 30, -- 10 quantised every timing measurement to a tenth of a second
		-- A spin is counted on the drift angle, unwrapped, from the moment
		-- the car is sideways past spinSlipDeg; straight (under it) for
		-- spinResetSeconds clears the count, and the short straight moment
		-- at the end of each rotation does not.
		spinSlipDeg = 20,
		spinResetSeconds = 0.5,
	},
}

export type Config = typeof(config)

return config
