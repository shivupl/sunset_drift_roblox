--!strict
-- Raycast suspension for one corner. Pure: no Roblox instances.
--
-- Why raycast (see DESIGN.md): one rigid body, per-corner spring loads that
-- shift with weight transfer, no constraint jitter, cheap on mobile, and the
-- tire model gets a clean normal load per wheel.
--
-- Geometry: the ray starts at the hardpoint and points along -body up.
-- Uncompressed, the wheel centre is restLength below the hardpoint and the
-- ground is restLength + wheelRadius below it. Compression is how much
-- closer the ground is than that.
local Suspension = {}

export type Config = {
	restLength: number,
	travel: number,
	stiffness: number,
	damping: number,
	bumpStopStiffness: number,
	antiRollFront: number,
	antiRollRear: number,
}

export type Result = {
	compression: number, -- m, 0..travel
	force: number, -- N along body up, >= 0
	grounded: boolean,
}

local RAY_MARGIN_M = 0.05

function Suspension.rayLengthM(cfg: Config, wheelRadius: number): number
	return cfg.restLength + wheelRadius + RAY_MARGIN_M
end

function Suspension.step(
	prevCompression: number,
	hitDistanceM: number?,
	cfg: Config,
	wheelRadius: number,
	stiffnessMult: number,
	dt: number
): Result
	if hitDistanceM == nil then
		return { compression = 0, force = 0, grounded = false }
	end
	local raw = cfg.restLength - (hitDistanceM - wheelRadius)
	if raw <= 0 then
		-- Ray hit beyond full droop: wheel is hanging, no load.
		return { compression = 0, force = 0, grounded = true }
	end
	local x = math.min(raw, cfg.travel)
	local dx = if dt > 0 then (x - prevCompression) / dt else 0
	-- Spring + damper. Damping on compression velocity is what makes the
	-- body "load up and settle" instead of bouncing; ~0.35 damping ratio.
	local force = cfg.stiffness * stiffnessMult * x + cfg.damping * dx
	if raw > cfg.travel then
		-- Bump stop: stiff extra spring past full travel so the body cannot
		-- sink through the wheels under two-wheel loads or hard landings.
		force += cfg.bumpStopStiffness * (raw - cfg.travel)
	end
	-- A spring cannot pull the chassis toward the ground.
	return { compression = x, force = math.max(force, 0), grounded = true }
end

-- Anti-roll bar: transfers load across an axle in proportion to the
-- compression difference. Returns the force to ADD to the left corner; the
-- right corner gets the negative. Stiffer front bar -> more understeer
-- (front loses grip first); stiffer rear bar -> more oversteer.
function Suspension.antiRoll(k: number, compressionLeft: number, compressionRight: number): number
	return k * (compressionLeft - compressionRight)
end

return Suspension
