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
}

export type State = {
	gear: number, -- -1 reverse, 1..n
	rpm: number,
	spinRpm: number,
	shiftTimer: number,
	reverseHold: number, -- seconds the brake has been held at a standstill
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
	return { gear = 1, rpm = cfg.idleRpm, spinRpm = 0, shiftTimer = 0, reverseHold = 0 }
end

function Drivetrain.step(
	state: State,
	cfg: Config,
	wheelRadius: number,
	dt: number,
	throttleIn: number,
	brakeIn: number,
	rearWheelSpeedMps: number,
	rearSpinning: boolean
): Output
	local speed = rearWheelSpeedMps
	local throttle, brake = throttleIn, brakeIn

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
	if rearSpinning and throttle > 0.1 then
		state.spinRpm = math.min(cfg.redlineRpm, math.max(state.spinRpm, rpmFromWheel) + cfg.spinRpmRate * throttle * dt)
	else
		state.spinRpm = math.max(rpmFromWheel, state.spinRpm - cfg.spinRpmRate * 2 * dt)
	end
	local rpm = math.clamp(math.max(rpmFromWheel, state.spinRpm), cfg.idleRpm, cfg.redlineRpm)
	state.rpm = rpm

	-- Automatic gearbox on wheel-derived rpm (wheelspin never upshifts).
	if state.shiftTimer > 0 then
		state.shiftTimer -= dt
	end
	if state.gear >= 1 and state.shiftTimer <= 0 then
		if rpmFromWheel >= cfg.upshiftRpm and state.gear < #cfg.gearRatios then
			state.gear += 1
			state.shiftTimer = cfg.shiftTime
		elseif rpmFromWheel <= cfg.downshiftRpm and state.gear > 1 then
			state.gear -= 1
			state.shiftTimer = cfg.shiftTime
		end
	end

	-- Crank torque. Zero during a shift and at the rev limiter.
	local torque = 0
	if state.shiftTimer <= 0 and rpm < cfg.redlineRpm then
		torque = Curve.lookup(cfg.torqueCurve, rpm) * throttle
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
