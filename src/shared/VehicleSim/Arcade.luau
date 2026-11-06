--!strict
-- The arcade drive (2026-11-06). The owner: "please just perfect the
-- drifting here - its been so long and i really dont like anything of what
-- we have - it needs to feel really good for like the 10 year olds that are
-- going to play this".
--
-- Every earlier drive stacked assists on a tyre model: a throw controller,
-- a flick timer, a gas hold, a feather, a kick, a line, each with its own
-- gate, latch and timer. Those gates are where the snaps and "limit stops"
-- came from. This is one small set of continuous laws instead. Nothing in it
-- switches on a threshold: the one drift flag only moves how much grip the
-- tyres have, and that grip eases in and out.
--
--   * The car goes where its nose points, as fast as the tyres allow. The
--     velocity turns toward the nose at alignRate (gripping) or
--     driftAlignRate (sliding), never harder than gripG / driftG. That cap
--     is the drift: turn the nose faster than the tyres can bend the path
--     and the car slides.
--   * The wheel turns the nose. Gently it is a road car (the yaw rate a
--     wheel at that angle gives). Hard over at speed it asks for more yaw
--     than the tyres can follow, so the tail steps out on its own: no button
--     needed. Once sliding, the wheel sets the angle (full lock = driftAngle,
--     half = half), the other way swings it across, let go and it
--     straightens.
--   * The handbrake (Space, the phone's lever) lets the tyres go and the
--     wheel spins the car round: a tap swings it out, held it goes all the
--     way round, and on release it finishes the turn the way it was going.
--   * A slide keeps its speed: most of the sideways speed the tyres take
--     away is handed back along the path (keepSpeed).
--
-- Pure: no Roblox instances. VehicleSim turns the accelerations into forces.
local Arcade = {}

export type Config = {
	enabled: boolean,
	gripG: number,
	driftG: number,
	driftGSlow: number,
	slowKmh: number,
	fastKmh: number,
	alignRate: number,
	driftAlignRate: number,
	keepSpeed: number,
	gripKeepSpeed: number,
	maxYawRateDegPerSec: number,
	steerAsk: number,
	slideFromSteer: number,
	yawResponseSeconds: number,
	driftYawResponseSeconds: number,
	maxYawAccelDegPerSec2: number,
	driftAngleDeg: number,
	liftAngleScale: number,
	angleResponseSeconds: number,
	slideStartDeg: number,
	slideKeepDeg: number,
	slideMinKmh: number,
	gripLoseSeconds: number,
	gripReturnSeconds: number,
	handbrakeSpinDegPerSec: number,
	handbrakeDecel: number,
	finishTurnFromDeg: number,
	driftDragG: number,
	launchG: number,
	brakeG: number,
}

export type State = {
	grip: number, -- 1 = the tyres hold, 0 = fully sliding
	drifting: boolean,
}

export type Input = {
	throttle: number, -- 0..1
	steer: number, -- -1..1, + = right
	handbrake: boolean,
	vLong: number, -- m/s along the nose
	vLat: number, -- m/s to the nose's right
	yawRateDeg: number, -- + = turning right
	lockDeg: number, -- steering lock (steering.maxSteerDeg)
	wheelbaseM: number,
	gravity: number, -- m/s²
	grounded: number, -- 0..1, the share of wheels on the ground
	dt: number,
}

export type Output = {
	latAccel: number, -- m/s², along the body's right
	longAccel: number, -- m/s², along the nose (speed kept, slide drag, handbrake)
	yawAccelDeg: number, -- deg/s², + = right
	noseDeg: number, -- the nose's angle right of the velocity, ±180
	visualSteerDeg: number, -- the front wheels as drawn
	drifting: boolean,
	grip: number,
}

function Arcade.new(): State
	return { grip = 1, drifting = false }
end

local function lerp(a: number, b: number, t: number): number
	return a + (b - a) * t
end

-- ±180
local function wrap(deg: number): number
	return (deg + 180) % 360 - 180
end

function Arcade.step(cfg: Config, state: State, inp: Input): Output
	local dt = math.max(inp.dt, 1e-4)
	local vLong, vLat = inp.vLong, inp.vLat
	local speed = math.sqrt(vLong * vLong + vLat * vLat)
	local kmh = speed * 3.6
	local steer = math.clamp(inp.steer, -1, 1)
	-- The nose's angle right of the velocity: + = nose right of the path.
	local nose = if speed > 1 then -math.deg(math.atan2(vLat, vLong)) else 0
	local forward = vLong > -0.5

	-- 1. Sliding or not. Only moves the tyres' grip, which eases.
	local slideAngle = math.abs(nose)
	if inp.handbrake and kmh >= cfg.slideMinKmh * 0.4 and forward then
		state.drifting = true
	elseif not state.drifting then
		state.drifting = forward and kmh >= cfg.slideMinKmh and slideAngle >= cfg.slideStartDeg
	else
		state.drifting = kmh >= cfg.slideMinKmh * 0.6 and slideAngle >= cfg.slideKeepDeg
	end
	local gripTarget = if state.drifting then 0 else 1
	local tau = if gripTarget < state.grip then cfg.gripLoseSeconds else cfg.gripReturnSeconds
	state.grip += (gripTarget - state.grip) * (1 - math.exp(-dt / math.max(tau, 1e-3)))
	local grip = state.grip
	local loose = 1 - grip

	-- 2. The path follows the nose: sideways speed dies away, capped by what
	-- the tyres can do. Sliding, most of what it takes is handed back along
	-- the path so the slide keeps its speed.
	local rate = lerp(cfg.driftAlignRate, cfg.alignRate, grip)
	-- Sliding grip by speed: in town (slowKmh and under) a slide still takes
	-- the corner (driftGSlow); on the highway (fastKmh and over) it runs on
	-- down the road (driftG).
	local fast = math.clamp((kmh - cfg.slowKmh) / math.max(cfg.fastKmh - cfg.slowKmh, 1), 0, 1)
	local slideG = lerp(cfg.driftGSlow, cfg.driftG, fast)
	local capG = lerp(slideG, cfg.gripG, grip)
	-- Past 60 degrees the tyres are scrubbing sideways and bite harder, so
	-- the car comes round to follow its nose rather than skate backwards.
	local scrub = math.clamp((slideAngle - 60) / 60, 0, 1)
	capG += scrub * (cfg.gripG - capG) * 0.5
	local cap = capG * inp.gravity * inp.grounded
	local latAccel = math.clamp(-vLat * (1 - math.exp(-rate * dt)) / dt, -cap, cap)
	local longAccel = 0
	if forward and speed > 1 then
		local vLat2 = vLat + latAccel * dt
		local lost = speed - math.sqrt(vLong * vLong + vLat2 * vLat2)
		local keep = lerp(cfg.keepSpeed, cfg.gripKeepSpeed, grip)
		longAccel += keep * math.max(lost, 0) / dt
		-- A little drag sideways, more the further round.
		longAccel -= cfg.driftDragG * inp.gravity * math.abs(math.sin(math.rad(nose))) * loose * inp.grounded
	end
	if inp.handbrake and speed > 0.5 then
		longAccel -= cfg.handbrakeDecel * inp.grounded * (if vLong >= 0 then 1 else -1)
	end
	-- How fast the path is turning, + = right, from the push just worked out.
	local pathRate = if speed > 1 then math.deg((latAccel * vLong - longAccel * vLat) / (speed * speed)) else 0

	-- 3. The nose. Gripping, the wheel asks for the yaw a car at that steer
	-- angle makes (reversing turns the other way), capped. Sliding, the
	-- wheel sets the angle and the nose turns with the path to hold it.
	local steerRad = math.rad(steer * inp.lockDeg)
	local geometric = math.deg(vLong * math.tan(steerRad) / math.max(inp.wheelbaseM, 0.5))
	-- At speed a wheel at any angle asks for more yaw than the tyres can
	-- bend the path (0.3 steer at 100 km/h asked for 118 deg/s against 23):
	-- every lane change slid. So the ask is also held to what the tyres can
	-- follow at this speed. Up to slideFromSteer of the wheel that is all it
	-- asks, so the car corners; from there to full lock the ask climbs to
	-- steerAsk times it, so the tail steps out, and at full lock at once.
	local follow = math.deg(cfg.gripG * inp.gravity / math.max(speed, 1))
	local mag = math.abs(steer)
	local over = math.clamp((mag - cfg.slideFromSteer) / math.max(1 - cfg.slideFromSteer, 1e-3), 0, 1)
	over = over * over * (3 - 2 * over)
	-- Reversing never asks past what the tyres follow: full lock backwards
	-- slid 45 degrees at 46 km/h.
	local reach = 1 + (cfg.steerAsk - 1) * over
	if not forward then
		reach = 0.7
	end
	local limit = math.min(cfg.maxYawRateDegPerSec, mag * follow * reach)
	local gripYaw = math.clamp(geometric, -limit, limit)
	-- The gas widens it: full throttle holds driftAngle, a lift tightens it
	-- toward liftAngleScale of that, so the angle breathes with the pedal.
	local wantNose = steer * cfg.driftAngleDeg * lerp(cfg.liftAngleScale, 1, math.clamp(inp.throttle, 0, 1))
	local err = wrap(wantNose - nose)
	-- Far round and still turning: finish the turn the way it is going
	-- rather than unwinding it.
	if slideAngle >= cfg.finishTurnFromDeg and inp.yawRateDeg * err < 0 then
		err += if err < 0 then 360 else -360
	end
	local driftYaw = pathRate + err / math.max(cfg.angleResponseSeconds, 1e-3)
	local yawTarget = lerp(driftYaw, gripYaw, grip)
	if inp.handbrake and forward then
		-- The lever: the wheel spins it, slower near a standstill.
		local spin = steer * cfg.handbrakeSpinDegPerSec * math.clamp(speed / 6, 0, 1)
		yawTarget = if math.abs(steer) > 0.1 then pathRate + spin else inp.yawRateDeg
	end
	local response = lerp(cfg.driftYawResponseSeconds, cfg.yawResponseSeconds, grip)
	local yawAccel = (yawTarget - inp.yawRateDeg) / math.max(response, 1e-3)
	yawAccel = math.clamp(yawAccel, -cfg.maxYawAccelDegPerSec2, cfg.maxYawAccelDegPerSec2) * inp.grounded

	-- The front wheels as drawn: the wheel's angle gripping; sliding they
	-- point down the path, the countersteer a real slide shows.
	local counter = math.clamp(-nose, -inp.lockDeg, inp.lockDeg)
	local visual = lerp(counter + steer * inp.lockDeg * 0.3, steer * inp.lockDeg, grip)

	return {
		latAccel = latAccel,
		longAccel = longAccel,
		yawAccelDeg = yawAccel,
		noseDeg = nose,
		visualSteerDeg = math.clamp(visual, -inp.lockDeg, inp.lockDeg),
		drifting = state.drifting,
		grip = grip,
	}
end

return Arcade
