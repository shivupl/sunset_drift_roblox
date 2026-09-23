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
		idleRpm = 900,
		redlineRpm = 6800,
		upshiftRpm = 6400,
		downshiftRpm = 3000,
		shiftTime = 0.08, -- torque is cut for this long; 0.15 left a quarter-second flat spot at the 1-2
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
		slotStartM = -18, -- first bay slot, lateral; ten slots at the spacing must fit the bay width
		slotSpacingM = 4,
		settleSpeedMps = 0.5, -- a driverless car below this speed...
		settleSeconds = 1, -- ...for this long gets anchored
		fallBelowM = 30, -- a car this far under the road surface is re-parked
	},

	-- Drift feedback on the client: tire smoke, skid marks, and wheel models
	-- that spin up when driven loose or stop when locked. Purely visual; the
	-- physics never reads any of this.
	effects = {
		enabled = true,
		smokeSlipStartDeg = 10, -- rear slip angle where smoke begins
		smokeSlipFullDeg = 35, -- and where it reaches smokeMaxRate
		smokeMaxRate = 70, -- particles per second per wheel
		smokeMinSpeedMps = 3, -- no smoke from a stationary tire
		smokeLifetime = 1.4, -- seconds a puff lasts
		smokeSize = 1.6, -- metres at the end of its life
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
		-- For now (the owner's option 3, 2026-09-22) every layer is the one
		-- free loop, Roblox Resources' "Car-Engine-Loop" (80317022777602,
		-- 9.2 s). Layers that share an id share one Sound, and their EQ and
		-- volume blend, so the layers are tone, not separate recordings.
		-- The tone is a calm sedan four-cylinder to suit the Kamri: warm
		-- and muffled at idle and off throttle, opening up under load. A
		-- matched pack later only changes the ids, refRpm and exponent.
		-- refRpm 2300 with exponent 0.55 keeps the old single-loop pitch
		-- (0.6 at 900 rpm idle, 1.8 at the 6800 redline); one loop
		-- stretched over the whole rev range at exponent 1 sounds sped up.
		engineAudio = {
			masterVolume = 0.5, -- the old single loop peaked at 0.5
			pitchExponent = 0.55, -- 1 = pitch exactly proportional to rpm
			idleFadeRpm = 700, -- idle is gone this far above idleRpm
			loadBlendStartRpm = 2500, -- low load starts handing to high load
			loadBlendEndRpm = 5000, -- and is gone by here
			gainSmoothSeconds = 0.05, -- de-click only; longer lags throttle
			-- volume is relative to masterVolume; eq is dB {low, mid, high}.
			layers = {
				idle = { soundId = "rbxassetid://80317022777602", refRpm = 2300, volume = 0.45, eq = { 2, -3, -12 } },
				lowLoad = { soundId = "rbxassetid://80317022777602", refRpm = 2300, volume = 0.8, eq = { 3, 0, -6 } },
				highLoad = { soundId = "rbxassetid://80317022777602", refRpm = 2300, volume = 1, eq = { 0, 2, 0 } },
				overrun = { soundId = "rbxassetid://80317022777602", refRpm = 2300, volume = 0.5, eq = { 0, -6, -14 } },
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
			-- crackleBurstPops (min, max) pops over crackleBurstSeconds, and
			-- nothing else pops. The owner (2026-09-22): only when going
			-- fast and letting off, 1 to 3 times; the stray pops while
			-- coasting and braking are gone. Every pop gets a random pitch in
			-- cracklePitch and volume in crackleVolumeRange (times
			-- crackleVolume), so no two bursts match. The pop is Mor5464's
			-- "Car Backfire Exhaust" (112720519011313, 0.44 s), checked to
			-- load in this place.
			crackleSoundId = "rbxassetid://112720519011313",
			crackleVolume = 0.35,
			crackleVolumeRange = { 0.55, 1 },
			cracklePitch = { 0.85, 1.2 },
			crackleMinRpm = 4000,
			crackleMinKmh = 80,
			crackleLiftFrom = 0.6,
			crackleBurstPops = { 1, 3 },
			crackleBurstSeconds = 0.5,
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
			limiterBandRpm = 100,
			limiterHz = 16,
			limiterDipGain = 0.35,
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
