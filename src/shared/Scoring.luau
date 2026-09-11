--!strict
-- Drift scoring. Pure: no Roblox instances and no services, so the same
-- module runs on the client for the live HUD and on the server as the
-- authoritative ceiling. Both sides step it with the same kind of sample --
-- speed and drift angle, nothing else -- so their totals track each other
-- closely and the server can cap a claim without shortchanging an honest
-- player. See DESIGN.md "Scoring and cash" for the trust model.
--
-- A slide is open while the car is past minAngleDeg of drift and above
-- minSpeedKmh. Points accrue as angle x speed x time x multiplier. Going
-- straight for longer than graceSeconds banks it. Losing all your speed or
-- taking a hard hit drops it. The grace window is what makes a left-right
-- transition one long slide instead of two short ones, and every direction
-- change inside a slide steps the multiplier.
--
-- A 360 pays a bonus on top. It is measured on the drift angle, unwrapped:
-- one full turn of the car relative to where it is going is one spin,
-- whatever the path did, and the server sees the same angle at 20 Hz (a
-- 150 deg/s spin moves 7.5 degrees a sample, nowhere near the wrap). Keeping
-- the inputs to speed and angle is what lets the server reproduce the
-- client's number.
local Scoring = {}

export type Config = {
	minAngleDeg: number,
	minSpeedKmh: number,
	graceSeconds: number,
	spinOutSpeedKmh: number,
	impactDecelKmhPerSec: number,
	impactSmoothSeconds: number,
	pointsPerSecond: number,
	referenceAngleDeg: number,
	referenceSpeedKmh: number,
	maxAngleFactor: number,
	chainStep: number,
	chainMax: number,
	minBankPoints: number,
	spinBonusPoints: number,
	cashPerPoint: number,
	maxPlausibleSpeedKmh: number,
	teleportToleranceM: number,
	serverTolerance: number,
	claimWindowSeconds: number,
	sampleHz: number,
}

export type Sample = {
	speedKmh: number,
	driftAngleDeg: number, -- + = velocity to the right of the heading
}

export type State = {
	active: boolean,
	points: number,
	multiplier: number,
	transitions: number,
	slideTime: number,
	graceTime: number,
	side: number, -- sign of the drift angle the slide is currently on
	speedAvg: number, -- speed lagged by impactSmoothSeconds, for the impact test
	primed: boolean, -- speedAvg has seen at least one sample
	spinTravelDeg: number, -- signed, unwrapped drift-angle travel inside this slide
	lastAngleDeg: number, -- previous sample's signed drift angle, for the unwrap
	spins: number, -- full 360s paid in this slide
	-- One-step events, cleared at the top of every step.
	banked: number, -- points banked this step, 0 for none
	dropped: boolean,
	reason: string, -- why it dropped: "impact" | "spun out" | ""
	spun: number, -- bonus points paid this step for a completed 360, 0 for none
}

function Scoring.new(): State
	return {
		active = false,
		points = 0,
		multiplier = 1,
		transitions = 0,
		slideTime = 0,
		graceTime = 0,
		side = 0,
		speedAvg = 0,
		primed = false,
		spinTravelDeg = 0,
		lastAngleDeg = 0,
		spins = 0,
		banked = 0,
		dropped = false,
		reason = "",
		spun = 0,
	}
end

-- Wipe the slide in progress without banking it. Used on a reset, on getting
-- out of the car, and by the server when a sample fails validation.
function Scoring.clear(state: State)
	state.active = false
	state.points = 0
	state.multiplier = 1
	state.transitions = 0
	state.slideTime = 0
	state.graceTime = 0
	state.side = 0
	state.spinTravelDeg = 0
	state.spins = 0
	-- Re-seed the impact filter: after a reset or a teleport the old average
	-- would read as a crash on the next sample.
	state.primed = false
end

function Scoring.cashFor(cfg: Config, points: number): number
	return math.floor(points * cfg.cashPerPoint)
end

-- Points per second at this angle and speed, before the multiplier. Exposed
-- so TUNING numbers can be checked directly.
function Scoring.rate(cfg: Config, speedKmh: number, driftAngleDeg: number): number
	local angleFactor = math.min(math.abs(driftAngleDeg) / cfg.referenceAngleDeg, cfg.maxAngleFactor)
	local speedFactor = speedKmh / cfg.referenceSpeedKmh
	return cfg.pointsPerSecond * angleFactor * speedFactor
end

local function bank(state: State, cfg: Config)
	local amount = math.floor(state.points)
	local worth = amount >= cfg.minBankPoints
	Scoring.clear(state)
	if worth then
		state.banked = amount
	end
end

local function drop(state: State, cfg: Config, reason: string)
	local worth = state.points >= cfg.minBankPoints
	Scoring.clear(state)
	if worth then
		state.dropped = true
		state.reason = reason
	end
end

function Scoring.step(state: State, cfg: Config, sample: Sample, dt: number): State
	state.banked = 0
	state.dropped = false
	state.reason = ""
	state.spun = 0
	if dt <= 0 then
		return state
	end

	local speed = sample.speedKmh
	local angle = math.abs(sample.driftAngleDeg)
	-- Unwrapped change in the signed drift angle since the last sample, so
	-- a spin passing through 180 does not read as a jump of 360.
	local dAngle = sample.driftAngleDeg - state.lastAngleDeg
	if dAngle > 180 then
		dAngle -= 360
	elseif dAngle < -180 then
		dAngle += 360
	end
	state.lastAngleDeg = sample.driftAngleDeg

	-- Impact test. Differentiating speed frame to frame is useless here: the
	-- client steps at 240 Hz and the server samples replicated physics at 20,
	-- so the same blip reads as a wildly different deceleration on each side.
	-- Instead keep an average of speed that lags by impactSmoothSeconds and
	-- compare the current speed against it. How far the real speed has fallen
	-- below its own recent average is a rate, in km/h per second, that barely
	-- moves for one bad sample and does not depend on the step size. Hard
	-- braking reads about 40 (a 1600 kg sedan stops from 100 km/h in three
	-- seconds); a wall reads several hundred.
	local tau = math.max(cfg.impactSmoothSeconds, 1e-3)
	if not state.primed then
		state.speedAvg = speed
		state.primed = true
	end
	state.speedAvg += (speed - state.speedAvg) * math.min(dt / tau, 1)
	local decel = (state.speedAvg - speed) / tau

	if state.active then
		if decel >= cfg.impactDecelKmhPerSec then
			drop(state, cfg, "impact")
			return state
		end
		if speed < cfg.spinOutSpeedKmh then
			drop(state, cfg, "spun out")
			return state
		end
	end

	local sliding = angle >= cfg.minAngleDeg and speed >= cfg.minSpeedKmh
	if sliding then
		local side = if sample.driftAngleDeg >= 0 then 1 else -1
		if state.active then
			-- A direction change links the next slide onto this one. Works
			-- both for a flick that crosses zero in a frame and for a swing
			-- that spends time straight inside the grace window. The sign
			-- also flips when a spin passes through 180, and that is not a
			-- transition, so the crossing has to happen on the straight side.
			if state.side ~= 0 and side ~= state.side and angle < 90 then
				state.transitions += 1
				state.multiplier = math.min(1 + state.transitions * cfg.chainStep, cfg.chainMax)
			end
		else
			state.active = true
			state.points = 0
			state.multiplier = 1
			state.transitions = 0
			state.slideTime = 0
			-- Seed the spin travel with the angle already built, so a full
			-- turn back to straight reads as exactly 360.
			state.spinTravelDeg = sample.driftAngleDeg - dAngle
			state.spins = 0
		end
		state.side = side
		state.graceTime = 0
		state.points += Scoring.rate(cfg, speed, sample.driftAngleDeg) * state.multiplier * dt
		state.slideTime += dt
	elseif state.active then
		state.graceTime += dt
		if state.graceTime >= cfg.graceSeconds then
			-- The slide stopped counting for one of two very different
			-- reasons, and where the car is pointing now tells them apart.
			-- Straightened out: a finished drift, bank it. Still sideways
			-- past minAngleDeg: the car never came back, it just ran out of
			-- speed spinning, and that is a spin-out however slowly it
			-- happened. Without this check a car rotating to a standstill
			-- banks the whole slide, because it falls under minSpeedKmh long
			-- before it reaches spinOutSpeedKmh.
			if angle >= cfg.minAngleDeg then
				drop(state, cfg, "spun out")
			else
				bank(state, cfg)
			end
		end
	end

	-- The 360. Travel keeps accumulating through the brief straight moment
	-- at the end of a rotation (the slide is still open inside its grace
	-- window), so a 720 pays twice.
	if state.active then
		state.spinTravelDeg += dAngle
		if math.abs(state.spinTravelDeg) >= 360 then
			state.spinTravelDeg -= math.sign(state.spinTravelDeg) * 360
			state.spins += 1
			local bonus = cfg.spinBonusPoints * state.multiplier
			state.points += bonus
			state.spun = bonus
		end
	end

	return state
end

-- Speed and drift angle from a chassis pose and its velocity. The server
-- derives its own samples this way from replicated physics; the client reads
-- the same quantities straight off VehicleState.
function Scoring.observe(cf: CFrame, velocity: Vector3, metersPerStud: number): (number, number)
	local flat = Vector3.new(velocity.X, 0, velocity.Z)
	local speedKmh = flat.Magnitude * metersPerStud * 3.6
	if flat.Magnitude < 1e-3 then
		return speedKmh, 0
	end
	local look = cf.LookVector
	local fwd = Vector3.new(look.X, 0, look.Z)
	if fwd.Magnitude < 1e-3 then
		return speedKmh, 0
	end
	fwd = fwd.Unit
	-- Right derived from the flattened heading rather than cf.RightVector,
	-- which points at the sky when the car is up on two wheels.
	local right = Vector3.new(-fwd.Z, 0, fwd.X)
	local dir = flat.Unit
	return speedKmh, math.deg(math.atan2(dir:Dot(right), dir:Dot(fwd)))
end

-- Server-side plausibility. False means this sample cannot have come from a
-- car driving normally, so whatever slide is open gets thrown away: either
-- the client is reporting a speed no car reaches, or the chassis moved
-- further in one sample than that speed allows (a teleport).
function Scoring.plausible(cfg: Config, prevPos: Vector3, pos: Vector3, speedKmh: number, dt: number, metersPerStud: number): boolean
	if speedKmh > cfg.maxPlausibleSpeedKmh then
		return false
	end
	local movedM = (pos - prevPos).Magnitude * metersPerStud
	local allowedM = (speedKmh / 3.6) * dt + cfg.teleportToleranceM
	return movedM <= allowedM
end

-- What the server actually banks. The claim is the client's figure, used
-- only when it is no higher than the server's own total times the tolerance;
-- with no claim the server banks what it saw itself.
function Scoring.settle(cfg: Config, serverPoints: number, claim: number?): number
	if claim == nil then
		return math.floor(serverPoints)
	end
	return math.floor(math.min(claim, serverPoints * cfg.serverTolerance))
end

return Scoring
