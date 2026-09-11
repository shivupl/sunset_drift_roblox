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
-- restoring torque, then adds a constant outward lean (leanTorque) plus
-- extra divergence above the target angle (instability). The player rides
-- that with the lean axis: toward the lifted side to climb, toward the
-- grounded side to catch it. Nothing here ever pulls the car toward a
-- target angle, so it is never "magnetized". Past tipRollDeg the
-- controller lets go and gravity finishes the job.
--
-- Lean is its own input, separate from steering, so the player can correct
-- the car's yaw with the wheel while balancing on the lean axis.
--
-- Speed matters twice, the way it does for a real sidewall skier. The lift
-- only has authority above minLiftSpeedKmh (nothing happens at parking
-- speed), and the balance controller's authority fades below
-- holdFadeSpeedKmh so a car that has slowed to a crawl settles back onto
-- four wheels on its own. And the lean keys are taps, not levers: a press
-- gives its full push at once and that push decays while the key is held,
-- so the way to stabilise is to tap against the lean, not to hold. Each
-- key has its own envelope, so tapping E while Q is held is a full catch
-- against Q's faded push, and letting E go does not re-fire Q.
--
-- Frame: all torques are computed "toward the chosen side" (positive =
-- rolling further onto two wheels) and converted to the world roll sign
-- (+ = right side lower) by multiplying with side on return.
local TwoWheel = {}

export type Config = {
	liftTorque: number,
	gravityCancel: number,
	targetRollDeg: number,
	leanTorque: number,
	instability: number,
	rollDamping: number,
	leanInTorque: number,
	leanOutTorque: number,
	tipRollDeg: number,
	landingDamping: number,
	suspensionBias: number,
	sidePickLean: number,
	sidePickRollDeg: number,
	balancedEntryMarginDeg: number,
	landedRollDeg: number,
	minLiftSpeedKmh: number,
	fullLiftSpeedKmh: number,
	holdFadeSpeedKmh: number,
	leanHoldDecaySeconds: number,
	leanHoldFloor: number,
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
	armed: boolean, -- a fresh lift needs the hold released first
	envLeft: number, -- 0..1 strength of the left key's press
	envRight: number, -- 0..1 strength of the right key's press
	prevLeft: number, -- last step's left input, to detect a fresh press
	prevRight: number,
	authority: number, -- 0..1 how much the controller can do at this speed
}

function TwoWheel.new(): State
	return {
		mode = "idle",
		side = -1,
		rollDeg = 0,
		marginDeg = 0,
		armed = true,
		envLeft = 0,
		envRight = 0,
		prevLeft = 0,
		prevRight = 0,
		authority = 0,
	}
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
	leanLeft: number,
	leanRight: number,
	rollDeg: number,
	rollRateDegPerSec: number,
	groundedLeft: number,
	groundedRight: number,
	dt: number,
	speedKmh: number
): number
	state.rollDeg = rollDeg

	-- Lift authority by speed: none at parking speed, full from fullLiftSpeedKmh.
	local liftAuthority = math.clamp(
		(speedKmh - cfg.minLiftSpeedKmh) / math.max(cfg.fullLiftSpeedKmh - cfg.minLiftSpeedKmh, 1),
		0,
		1
	)
	-- Hold authority fades out below holdFadeSpeedKmh: you cannot balance a
	-- car that is barely moving, so it settles down on its own.
	local holdAuthority = math.clamp(
		(speedKmh - cfg.holdFadeSpeedKmh) / math.max(cfg.minLiftSpeedKmh - cfg.holdFadeSpeedKmh, 1),
		0,
		1
	)
	state.authority = if state.mode == "lifting" then liftAuthority else holdAuthority

	-- Tap envelopes, one per key: a fresh press starts at 1 and decays
	-- toward leanHoldFloor while the key stays down; released is 0.
	local function envelope(env: number, now: number, prev: number): number
		if now ~= 0 and prev == 0 then
			return 1
		elseif now ~= 0 then
			local k = 1 - math.exp(-dt / math.max(cfg.leanHoldDecaySeconds, 1e-3))
			return env + (cfg.leanHoldFloor - env) * k
		end
		return 0
	end
	state.envLeft = envelope(state.envLeft, leanLeft, state.prevLeft)
	state.envRight = envelope(state.envRight, leanRight, state.prevRight)
	state.prevLeft, state.prevRight = leanLeft, leanRight
	local lean = leanRight - leanLeft -- for side picking

	if not held then
		-- Re-arm on release, so coming back down while still holding a lean
		-- key does not immediately fling the car up again.
		state.armed = true
	end

	if state.mode == "idle" then
		if not (held and state.armed) or liftAuthority <= 0 then
			state.marginDeg = cfg.tipRollDeg
			return 0
		end
		state.side = if lean > cfg.sidePickLean then 1 elseif lean < -cfg.sidePickLean then -1 else -1
		state.armed = false
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
		-- Early in the lift the side is still negotiable. This is what makes
		-- the touch flow work: NATL starts the lift, then whichever LEAN
		-- button the player reaches for picks the side.
		if roll < cfg.sidePickRollDeg and math.abs(lean) > cfg.sidePickLean then
			local wanted = math.sign(lean)
			if wanted ~= s then
				state.side = wanted
				s = wanted
				roll = rollDeg * s
				rate = rollRateDegPerSec * s
			end
		end
		torque = cfg.liftTorque * liftAuthority
		if roll >= cfg.targetRollDeg - cfg.balancedEntryMarginDeg then
			state.mode = "balanced"
		end
	end

	if state.mode == "balanced" then
		if roll >= cfg.tipRollDeg then
			state.mode = "tipped"
			state.marginDeg = 0
			return 0
		end
		if roll < cfg.landedRollDeg then
			-- Came back down while still held: allow a fresh lift next press.
			state.mode = "idle"
			return 0
		end
		-- Cancel (most of) gravity's restoring torque, then lean outward so
		-- the player has to keep balancing. One-sided on purpose: below the
		-- target this must not turn into a restoring spring.
		-- All of it scales with hold authority, so at a crawl the cancel and
		-- the lean die away and gravity puts the car back down honestly.
		local cancel = math.max(TwoWheel.gravityRestoringTorque(body, roll), 0) * cfg.gravityCancel
		torque = (cancel + cfg.leanTorque + cfg.instability * math.max(roll - cfg.targetRollDeg, 0)) * holdAuthority
			- cfg.rollDamping * rate
	end

	if state.mode == "lifting" or state.mode == "balanced" then
		-- Lean input: toward the lifted side pushes further up, toward the
		-- grounded side brings it back down. Steering is left alone so the
		-- player can correct the car's yaw while balancing.
		-- Each key carries its own gain, so a tap of the catch key lands its
		-- full leanOutTorque on top of whatever the held key is still pushing.
		local inKey = if s > 0 then state.envRight * leanRight else state.envLeft * leanLeft
		local outKey = if s > 0 then state.envLeft * leanLeft else state.envRight * leanRight
		torque += cfg.leanInTorque * inKey - cfg.leanOutTorque * outKey
	elseif state.mode == "landing" then
		torque = -cfg.landingDamping * rate
		if groundedLeft + groundedRight >= 4 or roll < cfg.landedRollDeg then
			state.mode = "idle"
		end
	elseif state.mode == "tipped" then
		torque = 0
	end

	state.marginDeg = cfg.tipRollDeg - roll
	return torque * s
end

return TwoWheel
