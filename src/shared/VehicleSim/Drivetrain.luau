--!strict
-- Engine, automatic gearbox, brakes. Pure: no Roblox instances.
--
-- The gearbox is automatic and there is no manual shift input. Reverse is
-- not a gear the player selects either: holding the brake at a standstill
-- for reverseHoldSeconds engages it, and any throttle puts the car back in
-- drive. The hold is what stops a hard stop from snapping into reverse the
-- instant the car settles.
--
-- Wheel spin is not integrated as a wheel angular velocity (too stiff for a
-- 60 Hz step). Instead the tire reports whether longitudinal demand exceeded
-- the friction circle; while it does, the engine rpm floats toward redline
-- and the drive force sits at the sliding level. Rpm otherwise derives from
-- rear wheel speed through the gearing, like a locked diff.
local Curve = require(script.Parent.Parent.Curve)

local Drivetrain = {}

export type Config = {
	torqueCurve: Curve.Points,
	gearRatios: { number },
	reverseRatio: number,
	finalDrive: number,
	drivelineEfficiency: number,
	idleRpm: number,
	redlineRpm: number,
	upshiftRpm: number,
	downshiftRpm: number,
	shiftTime: number,
	spinRpmRate: number,
	engineBrakeTorque: number,
	brakeForce: number,
	brakeBias: number,
	brakeFadeMps: number,
	reverseEngageMps: number,
	reverseHoldSeconds: number,
	topSpeedKmh: number,
	topSpeedFadeKmh: number,
	tractionControlBelowKmh: number,
	tractionControlMin: number,
	tractionControlCutRate: number,
	tractionControlRecoverRate: number,
	-- In a slide, shift up by the engine's own rpm (spin included) and
	-- never down. Off is the road-speed box everywhere.
	slideShift: boolean?,
}

export type State = {
	gear: number, -- -1 reverse, 1..n
	rpm: number,
	spinRpm: number,
	shiftTimer: number,
	reverseHold: number, -- seconds the brake has been held at a standstill
	tc: number, -- traction control throttle multiplier, 0..1
}

export type Output = {
	drivePerRearWheel: number, -- N, signed (+ forward)
	brakePerFrontWheel: number, -- N magnitude
	brakePerRearWheel: number,
	engineBrakePerRearWheel: number, -- N magnitude
	rpm: number,
	gear: number,
	torque: number, -- Nm at the crank after throttle and cut
}

local RPM_PER_RAD_S = 60 / (2 * math.pi)

function Drivetrain.new(cfg: Config): State
	return { gear = 1, rpm = cfg.idleRpm, spinRpm = 0, shiftTimer = 0, reverseHold = 0, tc = 1 }
end

function Drivetrain.step(
	state: State,
	cfg: Config,
	wheelRadius: number,
	dt: number,
	throttleIn: number,
	brakeIn: number,
	rearWheelSpeedMps: number,
	rearSpinning: boolean,
	tractionControlAllowed: boolean,
	-- The driven wheels' own surface speed, when the caller integrates wheel
	-- spin (Wheel.luau). The engine then turns with the wheels, spin and
	-- all, and the float-to-redline stand-in is off. Gear changes still go
	-- by road speed, so wheelspin never upshifts, except in a slide.
	spinSpeedMps: number?,
	-- The car is sideways (the caller decides how far). With slideShift on
	-- the box then goes by the engine's rpm and only upward.
	sliding: boolean?
): Output
	local speed = rearWheelSpeedMps
	local throttle, brake = throttleIn, brakeIn

	-- Launch traction control. Off the line the rear spins at anything past
	-- half throttle and the car crawls away in a cloud of its own smoke. A
	-- fixed cap was tried and sat under the grip limit for most of the
	-- launch (0-100 got slower, not faster). This is a loop: while the rear
	-- is spinning the multiplier winds down, while it grips it winds back
	-- up, so the drive hunts the edge of traction the way a real TC does.
	-- Only below tractionControlBelowKmh; power-over at speed and a
	-- handbrake launch are untouched.
	-- The caller withholds permission while the car is sliding sideways, so
	-- a power-over drift keeps every bit of throttle the driver gives it.
	if tractionControlAllowed and math.abs(speed) * 3.6 < cfg.tractionControlBelowKmh then
		if rearSpinning then
			state.tc = math.max(cfg.tractionControlMin, state.tc - cfg.tractionControlCutRate * dt)
		else
			state.tc = math.min(1, state.tc + cfg.tractionControlRecoverRate * dt)
		end
		throttle *= state.tc
	else
		state.tc = math.min(1, state.tc + cfg.tractionControlRecoverRate * dt)
	end

	-- Reverse. Coming to a stop on the brakes is the common case and must not
	-- select reverse, so the brake has to stay down for reverseHoldSeconds
	-- after the car is already stopped. Any throttle returns to drive.
	if state.gear == -1 then
		if throttleIn > 0 and speed > -cfg.reverseEngageMps then
			state.gear = 1
			state.reverseHold = 0
		end
	elseif brakeIn > 0 and throttleIn == 0 and math.abs(speed) < cfg.reverseEngageMps then
		state.reverseHold += dt
		if state.reverseHold >= cfg.reverseHoldSeconds then
			state.gear = -1
			state.reverseHold = 0
		end
	else
		state.reverseHold = 0
	end

	local ratio: number
	if state.gear == -1 then
		ratio = -cfg.reverseRatio
		throttle, brake = brakeIn, throttleIn -- pedals swap meaning in reverse
	else
		ratio = cfg.gearRatios[state.gear]
	end
	local overall = ratio * cfg.finalDrive

	-- Rpm from the wheels, or floating up while the rear spins.
	local rpmFromWheel = math.abs(speed / wheelRadius * overall) * RPM_PER_RAD_S
	local rpmFromSpin = if spinSpeedMps then math.abs(spinSpeedMps / wheelRadius * overall) * RPM_PER_RAD_S else rpmFromWheel
	if spinSpeedMps then
		state.spinRpm = rpmFromSpin
	elseif rearSpinning and throttle > 0.1 then
		state.spinRpm = math.min(cfg.redlineRpm, math.max(state.spinRpm, rpmFromWheel) + cfg.spinRpmRate * throttle * dt)
	else
		state.spinRpm = math.max(rpmFromWheel, state.spinRpm - cfg.spinRpmRate * 2 * dt)
	end
	local rpm = math.clamp(if spinSpeedMps then rpmFromSpin else math.max(rpmFromWheel, state.spinRpm), cfg.idleRpm, cfg.redlineRpm)
	state.rpm = rpm

	-- Automatic gearbox on wheel-derived rpm (wheelspin never upshifts).
	-- In a slide it goes by the engine's rpm instead, spin included, and only
	-- up: held drifts sat on the limiter in 2nd (the rears spun the engine
	-- to 6800 while road speed said 4400), and a handbrake throw that locked
	-- the rears could knock it down to 1st mid-slide.
	if state.shiftTimer > 0 then
		state.shiftTimer -= dt
	end
	local slideBox = cfg.slideShift == true and sliding == true
	if state.gear >= 1 and state.shiftTimer <= 0 and slideBox then
		if rpm >= cfg.upshiftRpm and state.gear < #cfg.gearRatios then
			state.gear += 1
			state.shiftTimer = cfg.shiftTime
		end
	elseif state.gear >= 1 and state.shiftTimer <= 0 then
		if rpmFromWheel >= cfg.upshiftRpm and state.gear < #cfg.gearRatios then
			state.gear += 1
			state.shiftTimer = cfg.shiftTime
		elseif rpmFromWheel <= cfg.downshiftRpm and state.gear > 1 then
			state.gear -= 1
			state.shiftTimer = cfg.shiftTime
		end
	end

	-- Crank torque. Zero during a shift and at the rev limiter.
	-- The top speed is a limiter, not a physics outcome: drive fades to
	-- nothing over the last topSpeedFadeKmh so the car sits at the ceiling
	-- instead of hitting a wall, the way a governor feels.
	local torque = 0
	if state.shiftTimer <= 0 and rpm < cfg.redlineRpm then
		local speedKmh = math.abs(speed) * 3.6
		local ceiling = math.clamp((cfg.topSpeedKmh - speedKmh) / math.max(cfg.topSpeedFadeKmh, 1), 0, 1)
		torque = Curve.lookup(cfg.torqueCurve, rpm) * throttle * ceiling
	end
	local drivePerRearWheel = torque * overall * cfg.drivelineEfficiency / wheelRadius / 2

	-- Engine braking on lift: moves weight forward, which is what makes a
	-- lift-and-flick transition swing the rear.
	local engineBrake = 0
	if throttle < 0.05 and state.gear >= 1 then
		engineBrake = cfg.engineBrakeTorque * math.abs(overall) / wheelRadius / 2 * (rpm / cfg.redlineRpm)
	end

	local brakeTotal = cfg.brakeForce * brake
	return {
		drivePerRearWheel = drivePerRearWheel,
		brakePerFrontWheel = brakeTotal * cfg.brakeBias / 2,
		brakePerRearWheel = brakeTotal * (1 - cfg.brakeBias) / 2,
		engineBrakePerRearWheel = engineBrake,
		rpm = rpm,
		gear = state.gear,
		torque = torque,
	}
end

return Drivetrain
