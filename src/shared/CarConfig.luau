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
		stiffness = 35000, -- N/m per corner
		damping = 2600, -- Ns/m per corner
		bumpStopStiffness = 350000, -- N/m past full travel
		antiRollFront = 8000, -- N/m of compression difference, front axle
		antiRollRear = 4000,
	},

	tires = {
		front = { grip = 1.05, peakSlipDeg = 8, slideSlipDeg = 25, slideGripRatio = 0.75 },
		rear = { grip = 1.0, peakSlipDeg = 7, slideSlipDeg = 22, slideGripRatio = 0.7 },
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
	},

	steering = {
		maxSteerDeg = 38,
		steerSpeedDegPerSec = 180,
		steerReturnDegPerSec = 360,
		driftAssist = 0.15, -- 0..1, adds this fraction of the drift angle as counter-steer
	},

	handbrake = {
		rearGripMultiplier = 0.35,
		brakeForce = 6000, -- N total on the rear axle
	},

	clutchKick = {
		multiplier = 2.5,
		duration = 0.3,
	},

	twoWheel = {
		liftTorque = 12000, -- Nm extra while lifting
		gravityCancel = 1.0, -- fraction of gravity's restoring torque cancelled while balanced (>1 leans off faster)
		targetRollDeg = 35, -- keep below atan(tire grip) or the base slides out from under the car
		leanTorque = 400, -- Nm outward lean while balanced. Below ~600 the natural front-heavy yaw wins and the car settles back onto four wheels if ignored; above it, it tips
		instability = 10, -- Nm/deg extra outward push above targetRollDeg
		rollDamping = 60, -- Nm per deg/s; kills the lift-in roll rate in ~0.3 s
		balanceTorque = 1500, -- Nm at full steer
		tipRollDeg = 62, -- past this the mode releases and gravity finishes the fall (static tip is atan(halfTrack/comHeight) ≈ 56°)
		rimGripStartDeg = 42, -- roll where the tires start biting on rim/sidewall
		rimGripBoost = 0.7, -- extra grip fraction at full dig-in (10° past the start)
		landingDamping = 60, -- Nm per deg/s while coming down
		suspensionBias = 1.8, -- grounded-side stiffness multiplier while lifted
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
		distance = 7.5,
		height = 2.6,
		lookHeight = 0.8,
		positionLag = 8, -- 1/s
		directionLag = 4, -- 1/s
		driftSwing = 0.6, -- 0 follow heading, 1 follow velocity
		baseFov = 70,
		fovPerKmh = 0.08,
		maxFov = 85,
		minSpeedForSwingMps = 3,
	},

	debug = {
		enabled = true,
		updateHz = 10,
	},
}

export type Config = typeof(config)

return config
