--!strict
-- Two-wheel ("natl") mode. Pure: no Roblox instances.
--
-- The car is an inverted pendulum pivoting on the two grounded contact
-- patches. Gravity's torque about that line is
--   m g (halfTrack cos(roll) - comHeight sin(roll))
-- which restores the car while roll is below the static tip angle
-- atan(halfTrack / comHeight) and pushes it over past that.
--
-- While balanced the controller cancels a configurable fraction of that
-- restoring torque and adds a small divergence (instability) so the
-- equilibrium is slightly unstable: ignore it and the car leans further,
-- correct it with steer and it comes back. Nothing here ever pulls the car
-- back toward the target angle by itself, so it is never "magnetized".
-- Past tipRollDeg the controller lets go and gravity finishes the job.
--
-- Frame: all torques are computed "toward the chosen side" (positive =
-- rolling further onto two wheels) and converted to the world roll sign
-- (+ = right side lower) by multiplying with side on return.
local TwoWheel = {}

export type Config = {
	liftTorque: number,
	gravityCancel: number,
	targetRollDeg: number,
	instability: number,
	rollDamping: number,
	balanceTorque: number,
	tipRollDeg: number,
	landingDamping: number,
	suspensionBias: number,
}

export type Body = {
	massKg: number,
	gravity: number,
	comHeightM: number,
	halfTrackM: number,
}

export type State = {
	mode: string, -- idle | lifting | balanced | tipped | landing
	side: number, -- +1 roll right (left wheels lift), -1 roll left
	rollDeg: number,
	marginDeg: number, -- degrees left before tipRollDeg
}

local SIDE_PICK_STEER = 0.2
local BALANCED_ENTRY_MARGIN_DEG = 5
local LANDED_ROLL_DEG = 3

function TwoWheel.new(): State
	return { mode = "idle", side = -1, rollDeg = 0, marginDeg = 0 }
end

function TwoWheel.isActive(state: State): boolean
	return state.mode == "lifting" or state.mode == "balanced"
end

-- Gravity's torque about the grounded contact line. Positive pushes the car
-- back down onto four wheels; negative (past the tip angle) pushes it over.
function TwoWheel.gravityRestoringTorque(body: Body, rollTowardDeg: number): number
	local th = math.rad(rollTowardDeg)
	return body.massKg * body.gravity * (body.halfTrackM * math.cos(th) - body.comHeightM * math.sin(th))
end

function TwoWheel.step(
	state: State,
	cfg: Config,
	body: Body,
	held: boolean,
	steer: number,
	rollDeg: number,
	rollRateDegPerSec: number,
	groundedLeft: number,
	groundedRight: number,
	dt: number
): number
	state.rollDeg = rollDeg

	if state.mode == "idle" then
		if not held then
			state.marginDeg = cfg.tipRollDeg
			return 0
		end
		state.side = if steer > SIDE_PICK_STEER then 1 elseif steer < -SIDE_PICK_STEER then -1 else -1
		state.mode = "lifting"
	elseif not held and state.mode ~= "landing" then
		state.mode = if state.mode == "tipped" then "idle" else "landing"
		if state.mode == "idle" then
			return 0
		end
	end

	local s = state.side
	local roll = rollDeg * s -- + = leaning onto the chosen side
	local rate = rollRateDegPerSec * s
	local torque = 0

	if state.mode == "lifting" then
		torque = cfg.liftTorque
		if roll >= cfg.targetRollDeg - BALANCED_ENTRY_MARGIN_DEG then
			state.mode = "balanced"
		end
	end

	if state.mode == "balanced" then
		if roll >= cfg.tipRollDeg then
			state.mode = "tipped"
			state.marginDeg = 0
			return 0
		end
		if roll < LANDED_ROLL_DEG then
			-- Came back down while still held: allow a fresh lift next press.
			state.mode = "idle"
			return 0
		end
		-- Cancel (most of) gravity's restoring torque, then diverge gently
		-- from the target so the player has to keep balancing.
		local cancel = math.max(TwoWheel.gravityRestoringTorque(body, roll), 0) * cfg.gravityCancel
		torque = cancel + cfg.instability * (roll - cfg.targetRollDeg) - cfg.rollDamping * rate
	end

	if state.mode == "lifting" or state.mode == "balanced" then
		-- Balance input: steering toward the grounded side brings the car
		-- down, steering away lifts it further. Same on every platform.
		torque -= cfg.balanceTorque * steer * s
	elseif state.mode == "landing" then
		torque = -cfg.landingDamping * rate
		if groundedLeft + groundedRight >= 4 or roll < LANDED_ROLL_DEG then
			state.mode = "idle"
		end
	elseif state.mode == "tipped" then
		torque = 0
	end

	state.marginDeg = cfg.tipRollDeg - roll
	return torque * s
end

return TwoWheel
