--!strict
-- The line: where a held slide goes. Pure: no Roblox instances.
--
-- The owner, 2026-10-05: "make sure its easy to control the sideway
-- drifting within the highway boundries". Measured on the drift-feel car,
-- a slide held on the gas from 100 km/h with the wheel centred turned its
-- path 74 degrees and went 79 m sideways in four seconds, a lever-held
-- slide 42 degrees and 24 m in three, and a six-swing Tanteel chain
-- wandered 49 m across: a carriageway is 38 m (six 5.3 m lanes and the
-- shoulder). The throw controller holds the angle against the path, so the
-- tyres' lateral forces, all pointing inward in a slide, bend the path
-- round at 0.8 g. That is a real drift's circle, and right for a corner,
-- but hajwala is a straight highway: the car slides down it, sideways,
-- and the driver picks the lane.
--
-- A real driver on a straight straightens the line with countersteer
-- (the fronts pushing outward) and by sliding the other way; Stanford's
-- drifting work splits it the same way, the rear's slip holding the
-- angle and the front steering the path (Hindiyeh and Gerdes, 2014). The
-- wheel here is already the angle's dial, so the line is an assist: while
-- a slide is held (the gas hold or the lever), a sideways acceleration at
-- the centre of mass takes `hold` of the tyres' own curve out and adds
-- `steerG` toward the steered side at full lock. At the centre of mass it
-- has no yaw moment, so the angle, the 360 and the catch are the throw
-- controller's as before, and square to the velocity it does no work, so
-- the speed is the tyres' as before.
--
-- Steering into the slide lets the hold go (intoRelease): the wheel held
-- into a drift is a corner being taken, so the tyres' own curve comes back
-- and the drift turns with the road (the city's corners). Centred, it runs
-- straight; counter-steered, it holds and is aimed the other way.
--
-- Under the lever the wheel is the spin's (full lock comes round), so only
-- leverSteerShare of it aims the line, and the lever has its own hold from
-- straight up (a spin's onset is where its path turns) and its own speeds:
-- a highway 360 goes straight on down the road, a handbrake turn at city
-- speed stays a turn.
local Line = {}

export type Config = {
	hold: number, -- 0..1 of the held slide's own curve taken out with the wheel centred
	steerG: number, -- g toward the steered side at full steer
	leverSteerShare: number, -- share of steerG while the lever is in
	maxG: number, -- the most the line adds, g
	fromDeg: number, -- fades in from this drift angle...
	fullDeg: number, -- ...to full here
	minKmh: number, -- and from this speed...
	fullKmh: number, -- ...to full here
	intoRelease: number, -- 0..1 of the hold let go at full steer into the slide
	leverHold: number, -- the hold while the lever is in, from straight up
	leverMinKmh: number, -- the lever's hold fades in from this speed...
	leverFullKmh: number, -- ...to full here
}

export type Input = {
	held: boolean, -- a slide is held: the gas hold, or the lever in
	lever: boolean, -- the lever is in
	steer: number, -- -1..1, + right
	driftAngleDeg: number,
	speedKmh: number,
	tyreLatAccel: number, -- m/s^2 the tyres put square to the velocity, + right of it
	gravity: number, -- m/s^2
}

local function ramp(x: number, from: number, full: number): number
	if full <= from then
		return if x >= from then 1 else 0
	end
	return math.clamp((x - from) / (full - from), 0, 1)
end

-- The sideways acceleration to add at the centre of mass, m/s^2, + right
-- of the velocity.
function Line.accel(cfg: Config, inp: Input): number
	if not inp.held then
		return 0
	end
	local fade, hold, share
	if inp.lever then
		fade = ramp(inp.speedKmh, cfg.leverMinKmh, cfg.leverFullKmh)
		hold = cfg.leverHold
		share = cfg.leverSteerShare
	else
		fade = ramp(math.abs(inp.driftAngleDeg), cfg.fromDeg, cfg.fullDeg) * ramp(inp.speedKmh, cfg.minKmh, cfg.fullKmh)
		local into = if inp.steer * inp.driftAngleDeg < 0 then math.abs(inp.steer) else 0
		hold = cfg.hold * (1 - cfg.intoRelease * math.min(into, 1))
		share = 1
	end
	if fade <= 0 then
		return 0
	end
	local want = inp.steer * cfg.steerG * share * inp.gravity
	local cap = cfg.maxG * inp.gravity
	return math.clamp(want - hold * inp.tyreLatAccel, -cap, cap) * fade
end

return Line
