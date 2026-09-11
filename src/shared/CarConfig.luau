--!strict
-- Every tunable for the Phase 0 car. SI units unless the name says otherwise.
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
		massKg = 1600,
		bodySize = { 4.9, 1.3, 1.8 }, -- length (Z), height (Y), width (X), metres
		-- From the box centre: {lateral, up, forward}. Low and slightly forward.
		centerOfMassOffset = { 0, -0.35, 0.2 },
		wheelbase = 2.8,
		trackWidth = 1.55,
		wheelRadius = 0.33,
		wheelWidth = 0.22,
		shellMassFraction = 0.35, -- rest of the mass goes into the hidden ballast
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
			slideGripRatio = 0.75,
			falloffShape = 1.2,
			-- Fronts stay grippy when deep: they are what drives the rotation
			-- in a throw, so easing them off slows a 360 down.
			deepSlideSlipDeg = 50,
			deepSlideGripRatio = 0.6,
		},
		rear = {
			grip = 1.0,
			peakSlipDeg = 9.5,
			riseShape = 0.55,
			-- The gentle falloff ends at 26 deg and the deep floor starts at 30:
			-- below ~25 deg (a held drift) the rear is still near full grip,
			-- past 30 it lets go progressively. With the first floor lasting to
			-- 40 deg the rear had 98% grip at 40 and a tapped handbrake snapped
			-- the car straight instead of letting it come round.
			slideSlipDeg = 26,
			slideGripRatio = 0.75,
			falloffShape = 1.8,
			-- Rear lets go deep: this is what lets the car keep rotating and
			-- carry its speed through a Ta'geed instead of scrubbing to a stop.
			deepSlideSlipDeg = 30,
			deepSlideGripRatio = 0.3,
		},
		speedFadeMps = 1.0, -- lateral force fades to zero below this speed
	},

	drivetrain = {
		-- Tafheet lives at 160-260 km/h. Bumped about a third over the first
		-- pass so highway speed arrives in a few seconds rather than ten.
		torqueCurve = { { 1000, 240 }, { 2500, 350 }, { 4000, 405 }, { 5500, 390 }, { 6500, 320 }, { 7000, 0 } },
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
		shiftTime = 0.15,
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
	},

	steering = {
		maxSteerDeg = 38,
		steerSpeedDegPerSec = 180,
		steerReturnDegPerSec = 360,
		driftAssist = 0.15, -- 0..1, adds this fraction of the drift angle as counter-steer
		-- The assist fades out past these angles so it stops fighting a spin:
		-- at 90 deg of drift it was steering 13 deg against the rotation.
		driftAssistFadeStartDeg = 45,
		driftAssistFadeEndDeg = 75,
		-- Speed-sensitive lock: km/h -> fraction of maxSteerDeg. Full lock for
		-- parking and low-speed work, tapering at highway speed so turning
		-- alone cannot pitch the car sideways.
		speedLockCurve = { { 0, 1 }, { 40, 1 }, { 90, 0.6 }, { 150, 0.35 }, { 220, 0.3 }, { 300, 0.3 } },
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
	},

	handbrake = {
		-- Lowered from 0.35 alongside the softer rear falloff. The rear now
		-- holds far more grip a few degrees past peak, which slowed the pull
		-- from 0.24 s to 0.33 s to reach 20 deg; cutting deeper puts that back
		-- without touching the falloff that made the car stable.
		rearGripMultiplier = 0.25,
		brakeForce = 6000, -- N total on the rear axle
		-- Grip comes back over this long after the lever is let go instead of
		-- snapping back in one step, so releasing mid-slide reads as a hand-off
		-- to throttle rather than a jolt.
		-- A tapped handbrake will not complete a 360 at any setting here
		-- (measured 255-346 deg): once the car travels backwards the rears
		-- roll again and their grip kills the rotation. A held handbrake
		-- keeps them locked and comes round in ~3.4 s, which is the real
		-- Ta'geed technique. 0.4 keeps a release mid-slide soft.
		releaseSeconds = 0.4,
	},

	twoWheel = {
		liftTorque = 12000, -- Nm extra while lifting
		gravityCancel = 1.0, -- fraction of gravity's restoring torque cancelled while balanced (>1 leans off faster)
		targetRollDeg = 35, -- keep below atan(tire grip) or the base slides out from under the car
		-- Outward lean while balanced. Throttle already pushes the car outward
		-- on its own (only the grounded rear drives, so gas yaws the car away
		-- from the low side), so this stays small: at 400 the car leaned in at
		-- 12 deg/s under 0.4 throttle and a tap was erased in half a second.
		leanTorque = 150,
		instability = 6, -- Nm/deg extra outward push above targetRollDeg
		rollDamping = 60, -- Nm per deg/s; kills the lift-in roll rate in ~0.3 s
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
		leanInTorque = 1200, -- Nm at a fresh press toward the lifted side (go further up)
		leanOutTorque = 4000, -- Nm at a fresh press toward the grounded side (come back down)
		tipRollDeg = 62, -- past this the mode releases and gravity finishes the fall (static tip is atan(halfTrack/comHeight) ≈ 56°)
		rimGripStartDeg = 42, -- roll where the tires start biting on rim/sidewall
		rimGripBoost = 0.7, -- extra grip fraction at full dig-in (10° past the start)
		landingDamping = 60, -- Nm per deg/s while coming down
		suspensionBias = 1.8, -- grounded-side stiffness multiplier while lifted
		-- Speed gates, like a real sidewall skier: nothing lifts at parking
		-- speed, full lift from fullLiftSpeedKmh, and the balance fades away
		-- below holdFadeSpeedKmh so a car that has slowed down settles.
		minLiftSpeedKmh = 45,
		fullLiftSpeedKmh = 80,
		holdFadeSpeedKmh = 30,
		-- Tap balance: a press gives its whole push at once, then decays
		-- toward leanHoldFloor over leanHoldDecaySeconds while held.
		-- Stabilise by tapping against the lean, not by holding.
		leanHoldDecaySeconds = 0.45,
		leanHoldFloor = 0.3,
		-- Steering is the strongest balance lever there is on two wheels: a
		-- turn toward the low side drops the car, away lifts it, and at 80 km/h
		-- a 0.3 s tap of 0.2 steer was enough to flip it. Scale the lock while
		-- lifted so a touch tap (which ramps to ~0.9 steer in 0.3 s) is a
		-- correction, not a roll-over. Measured at 0.35: a 0.5 tap away
		-- still tipped it; 0.22 leaves that as a catchable lean.
		steerScale = 0.22,
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
		spawnHeightM = 0.45, -- above rest height; the car drops and settles on spawn
		slotStartM = -20, -- first bay slot, lateral
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
		-- Audio hooks. Empty ids play nothing; paste "rbxassetid://..." ids
		-- you own or have licensed. Screech follows rear slip, engine follows
		-- rpm and throttle.
		screechSoundId = "",
		screechMaxVolume = 0.6,
		engineSoundId = "",
		engineMaxVolume = 0.5,
		engineMinPitch = 0.6, -- playback speed at idle
		engineMaxPitch = 1.8, -- playback speed at redline
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
		updateHz = 10,
		spinSlipDeg = 45, -- yaw counts toward a 360 while |drift| is above this
		spinResetDeg = 15, -- and the count clears once the car is back under this
	},
}

export type Config = typeof(config)

return config
