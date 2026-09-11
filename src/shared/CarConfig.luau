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
		front = {
			grip = 1.05,
			peakSlipDeg = 8,
			riseShape = 0.85,
			slideSlipDeg = 25,
			slideGripRatio = 0.75,
			falloffShape = 1.2,
		},
		rear = {
			grip = 1.0,
			peakSlipDeg = 9.5,
			riseShape = 0.55,
			slideSlipDeg = 32,
			slideGripRatio = 0.75,
			falloffShape = 1.8,
		},
		speedFadeMps = 1.0, -- lateral force fades to zero below this speed
	},

	drivetrain = {
		torqueCurve = { { 1000, 180 }, { 2500, 260 }, { 4000, 300 }, { 5500, 290 }, { 6500, 240 }, { 7000, 0 } },
		gearRatios = { 3.5, 2.1, 1.4, 1.0, 0.8 },
		reverseRatio = 3.2,
		finalDrive = 3.9,
		drivelineEfficiency = 0.9,
		idleRpm = 900,
		redlineRpm = 6800,
		upshiftRpm = 6400,
		downshiftRpm = 3000,
		shiftTime = 0.15,
		spinRpmRate = 6000, -- rpm/s the engine climbs while the rear spins
		engineBrakeTorque = 40, -- Nm at redline, scales with rpm
		brakeForce = 14000, -- N total at full pedal
		brakeBias = 0.65, -- fraction on the front axle
		brakeFadeMps = 0.5, -- brakes fade to zero below this speed (no jitter at rest)
		reverseEngageMps = 0.5, -- below this speed, brake with no throttle selects reverse
	},

	steering = {
		maxSteerDeg = 38,
		steerSpeedDegPerSec = 180,
		steerReturnDegPerSec = 360,
		driftAssist = 0.15, -- 0..1, adds this fraction of the drift angle as counter-steer
		-- Speed-sensitive lock: km/h -> fraction of maxSteerDeg. Full lock for
		-- parking and low-speed work, tapering at highway speed so turning
		-- alone cannot pitch the car sideways.
		speedLockCurve = { { 0, 1 }, { 40, 1 }, { 90, 0.6 }, { 150, 0.35 }, { 260, 0.35 } },
		-- The taper lifts back toward full lock as the car goes sideways, so a
		-- slide stays catchable at speed. Degrees of slip for full relief, and
		-- how much of the taper it lifts (0 disables it, 1 gives the whole
		-- wheel back).
		counterSteerReliefDeg = 25,
		counterSteerRelief = 1,
	},

	handbrake = {
		-- Lowered from 0.35 alongside the softer rear falloff. The rear now
		-- holds far more grip a few degrees past peak, which slowed the pull
		-- from 0.24 s to 0.33 s to reach 20 deg; cutting deeper puts that back
		-- without touching the falloff that made the car stable.
		rearGripMultiplier = 0.25,
		brakeForce = 6000, -- N total on the rear axle
	},

	clutchKick = {
		-- The torque spike only bites while the rear is still inside its
		-- friction circle; past that the tire is clamped to its sliding value
		-- and a bigger multiplier does nothing. rearGripMultiplier is what
		-- breaks the rear loose, the same way the handbrake does, and it is
		-- the knob to reach for if kicks stop initiating.
		multiplier = 2.5,
		rearGripMultiplier = 0.5,
		duration = 0.3,
	},

	twoWheel = {
		liftTorque = 12000, -- Nm extra while lifting
		gravityCancel = 1.0, -- fraction of gravity's restoring torque cancelled while balanced (>1 leans off faster)
		targetRollDeg = 35, -- keep below atan(tire grip) or the base slides out from under the car
		leanTorque = 400, -- Nm outward lean while balanced. Below ~600 the natural front-heavy yaw wins and the car settles back onto four wheels if ignored; above it, it tips
		instability = 10, -- Nm/deg extra outward push above targetRollDeg
		rollDamping = 60, -- Nm per deg/s; kills the lift-in roll rate in ~0.3 s
		-- Lean input (Q/E, gamepad bumpers, touch LEAN buttons). Two gains
		-- because catching a lean needs more authority than adding to one.
		-- Sized against rollDamping: leanIn/rollDamping is roughly the degrees
		-- per second the car climbs while you hold the key, so 450/60 is about
		-- 7°/s in and 1800/60 about 30°/s back down.
		leanInTorque = 450, -- Nm at full lean toward the lifted side (go further up)
		leanOutTorque = 1800, -- Nm at full lean toward the grounded side (come back down)
		tipRollDeg = 62, -- past this the mode releases and gravity finishes the fall (static tip is atan(halfTrack/comHeight) ≈ 56°)
		rimGripStartDeg = 42, -- roll where the tires start biting on rim/sidewall
		rimGripBoost = 0.7, -- extra grip fraction at full dig-in (10° past the start)
		landingDamping = 60, -- Nm per deg/s while coming down
		suspensionBias = 1.8, -- grounded-side stiffness multiplier while lifted
		sidePickLean = 0.2, -- |lean| above this picks the roll side; with none held the car rolls left
		sidePickRollDeg = 15, -- while lifting below this roll a lean the other way still flips the side
		balancedEntryMarginDeg = 5, -- lifting hands over to balancing this many degrees before targetRollDeg
		landedRollDeg = 3, -- below this roll the car counts as back on four wheels
	},

	input = {
		keyboardSteerRampPerSec = 4,
		keyboardSteerReturnPerSec = 8,
		touchSteerRampPerSec = 3,
		touchSteerReturnPerSec = 6,
		touchSteerCurve = 1.5, -- exponent on the ramped touch steer
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

	debug = {
		enabled = true,
		updateHz = 10,
	},
}

export type Config = typeof(config)

return config
