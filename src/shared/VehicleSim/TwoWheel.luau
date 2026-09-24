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
-- The mode latches. A tap of a lean key from idle lifts the car onto that
-- side and it stays up with nothing held; the touch NATL toggle does the
-- same (held = the toggle). The spring that holds the angle then decays
-- toward a floor, so an ignored car sinks back onto four wheels over a few
-- seconds, and every tap toward the lifted side winds the spring back up:
-- the first tap gets it up, the next ones keep it there. A tap toward the
-- grounded side is a catch; that key held past landHoldSeconds, or the
-- toggle going off, lands it.
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
	leanHoldFloor: number, -- the catch key held decays to this
	leanInHoldFloor: number, -- the key toward the lifted side held decays to this; 1 keeps pushing, which is the topple
	balanceSpring: number, -- Nm per degree of error from targetRollDeg while balanced
	-- One-sided: the spring lifts a sagging car and does nothing above the
	-- target, so leaning on the in-key carries the car over. Symmetric: it
	-- also pulls the car back down from above, which is what makes a held
	-- key settle to a hover instead of toppling.
	balanceSpringOneSided: boolean,
	balanceSpringDecaySeconds: number, -- the spring winds down to its floor over this long with no in-tap
	balanceSpringFloor: number, -- fraction of balanceSpring left once it has wound down
	balanceCancelFloor: number, -- fraction of gravityCancel left once the spring has wound down
	landHoldSeconds: number, -- the opposite key held this long means "land", not "tap"
	tapBoost: number, -- a fresh tap toward the lifted side adds this fraction of liftTorque at full sag
	tapBoostFullDeg: number, -- sagged this far below the target or more is full sag
	tapBoostSeconds: number, -- and the boost fades over this long
	dropReleaseDeg: number, -- sagged under this with no in-key held, the controller lets go and the car drops; 0 never
	touchdownSeconds: number, -- after a two-wheel landing the suspension runs soft this long (see touchdown)
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
	outHeld: number, -- seconds the key toward the grounded side has been held
	prevHeld: boolean, -- last step's toggle, to land when it goes off
	springEnv: number, -- 0..1 how much of balanceSpring is live right now
	boost: number, -- 0..1 what is left of the last tap's boost
	touchdown: number, -- seconds left of the soft suspension after a landing
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
		outHeld = 0,
		prevHeld = false,
		springEnv = 1,
		boost = 0,
		touchdown = 0,
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
	state.touchdown = math.max(0, state.touchdown - dt)

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

	-- Fresh presses, before the envelopes consume them.
	local freshLeft = leanLeft ~= 0 and state.prevLeft == 0
	local freshRight = leanRight ~= 0 and state.prevRight == 0

	-- Tap envelopes, one per key: a fresh press starts at 1 and decays
	-- toward leanHoldFloor while the key stays down; released is 0.
	local function envelope(env: number, now: number, prev: number, floor: number): number
		if now ~= 0 and prev == 0 then
			return 1
		elseif now ~= 0 then
			local k = 1 - math.exp(-dt / math.max(cfg.leanHoldDecaySeconds, 1e-3))
			return env + (floor - env) * k
		end
		return 0
	end
	-- The key toward the lifted side keeps its own floor: held, it goes on
	-- pushing, and a car pushed past the tip goes over. That is the price
	-- of leaning on the key instead of tapping it.
	local inIsLeft = state.side < 0
	state.envLeft = envelope(state.envLeft, leanLeft, state.prevLeft, if inIsLeft then cfg.leanInHoldFloor else cfg.leanHoldFloor)
	state.envRight = envelope(state.envRight, leanRight, state.prevRight, if inIsLeft then cfg.leanHoldFloor else cfg.leanInHoldFloor)
	state.prevLeft, state.prevRight = leanLeft, leanRight
	local lean = leanRight - leanLeft -- for side picking

	if not held then
		-- Re-arm on release, so coming back down while still holding a lean
		-- key does not immediately fling the car up again.
		state.armed = true
	end

	local toggledOff = state.prevHeld and not held
	state.prevHeld = held
	-- A tipped car is back in play once it is on its wheels again (a reset,
	-- or it rolled back). With the mode latched on a tap there is no key
	-- release to clear it, and without this it stayed "tipped" for good.
	if state.mode == "tipped" and (groundedLeft + groundedRight >= 4 or math.abs(rollDeg) < cfg.landedRollDeg) then
		state.mode = "idle"
	end
	if state.mode == "idle" then
		-- A tap of either lean key, or the toggle, starts a lift. The key
		-- picks the side; the toggle takes the lean axis or defaults left.
		local tap = freshLeft or freshRight
		if not ((held and state.armed) or tap) or liftAuthority <= 0 then
			state.marginDeg = cfg.tipRollDeg
			return 0
		end
		if freshRight and not freshLeft then
			state.side = 1
		elseif freshLeft and not freshRight then
			state.side = -1
		else
			state.side = if lean > cfg.sidePickLean then 1 elseif lean < -cfg.sidePickLean then -1 else -1
		end
		state.armed = false
		state.mode = "lifting"
		state.springEnv = 1
		state.outHeld = 0
	elseif toggledOff and state.mode ~= "landing" then
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
			state.touchdown = cfg.touchdownSeconds
			return 0
		end
		-- Sagged low with no tap toward the lifted side: let go and let
		-- gravity drop it, so the lifted wheels land with speed and the
		-- suspension takes the hit. Lowered by the controller all the way,
		-- the car touched down at a crawl and did not move afterwards.
		local inHeld = if s > 0 then leanRight ~= 0 else leanLeft ~= 0
		if cfg.dropReleaseDeg > 0 and roll < cfg.dropReleaseDeg and not inHeld then
			state.mode = "landing"
		end
	end

	if state.mode == "balanced" then
		-- Cancel (most of) gravity's restoring torque, then lean outward so
		-- the player has to keep balancing. One-sided on purpose: below the
		-- target this must not turn into a restoring spring.
		-- All of it scales with hold authority, so at a crawl the cancel and
		-- the lean die away and gravity puts the car back down honestly.
		-- The spring is the part that makes a natl holdable. The gravity
		-- cancel is a model of the restoring torque, and anything the model
		-- misses (grounded-side springs, tyre moments, the road) shows up
		-- as the car drifting off its angle with the key held. A spring
		-- about the target absorbs that error; the taps and the steering
		-- then move the car about that hold instead of fighting to keep it.
		-- It winds down with time and every tap toward the lifted side
		-- winds it back up: that is the "keep tapping to keep it up" of a
		-- real sidewall ride, and with nothing pressed the car comes home.
		local inFresh = if s > 0 then freshRight else freshLeft
		if inFresh then
			state.springEnv = 1
			state.boost = 1
		end
		state.springEnv = math.max(cfg.balanceSpringFloor, state.springEnv - dt / math.max(cfg.balanceSpringDecaySeconds, 1e-3))
		-- Symmetric by default: the spring lifts a sagging car and pulls a
		-- high one back down, so the car settles to a hover near the target
		-- and a held key does not carry it over. One-sided (lift only, and
		-- silent above the target) is what makes leaning on the in-key
		-- topple, which is a much less forgiving feel.
		local err = cfg.targetRollDeg - roll
		if cfg.balanceSpringOneSided then
			err = math.max(err, 0)
		end
		local spring = cfg.balanceSpring * state.springEnv * err
		-- The gravity cancel winds down with the same envelope, to
		-- balanceCancelFloor of itself. A fully cancelled pendulum is
		-- neutral at every angle, so with the spring gone the car just
		-- hovered at 9 degrees; leaving a little of gravity uncancelled is
		-- what brings it home.
		local cancelScale = cfg.balanceCancelFloor + (1 - cfg.balanceCancelFloor) * state.springEnv
		local cancel = math.max(TwoWheel.gravityRestoringTorque(body, roll), 0) * cfg.gravityCancel * cancelScale
		-- The tap boost: a short lift back toward the target, full once the
		-- car has sagged tapBoostFullDeg and less the closer it is, so a tap
		-- at 15 degrees puts it back up and a tap at the target adds nothing
		-- (tapping cannot flip the car). Measured without it: a tap every
		-- 1.5 s hovered the car at 9-15.
		local sag = if cfg.tapBoostFullDeg > 0 then math.clamp((cfg.targetRollDeg - roll) / cfg.tapBoostFullDeg, 0, 1) else 0
		local boost = cfg.liftTorque * cfg.tapBoost * sag * state.boost
		state.boost = math.max(0, state.boost - dt / math.max(cfg.tapBoostSeconds, 1e-3))
		torque = (cancel + spring + boost + cfg.leanTorque + cfg.instability * math.max(roll - cfg.targetRollDeg, 0)) * holdAuthority
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
		-- A tap against the lean is a catch; the same key held on is the
		-- driver saying "down". Past landHoldSeconds the controller lets
		-- go and the landing damping takes over, so the balance spring
		-- cannot pull the car back up against a held key.
		local outRaw = if s > 0 then leanLeft else leanRight
		state.outHeld = if outRaw ~= 0 then state.outHeld + dt else 0
		if state.mode == "balanced" and state.outHeld >= cfg.landHoldSeconds then
			state.mode = "landing"
			state.outHeld = 0
		end
	elseif state.mode == "landing" then
		torque = -cfg.landingDamping * rate
		if groundedLeft + groundedRight >= 4 or roll < cfg.landedRollDeg then
			state.mode = "idle"
			state.touchdown = cfg.touchdownSeconds
		end
	elseif state.mode == "tipped" then
		torque = 0
	end

	state.marginDeg = cfg.tipRollDeg - roll
	return torque * s
end

return TwoWheel
