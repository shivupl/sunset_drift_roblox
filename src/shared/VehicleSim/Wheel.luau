--!strict
-- A wheel with its own spin. Pure: no Roblox instances.
--
-- The legacy model (Tire.compute) has no wheel speed. It asks whether the
-- driver's drive or brake demand fits in a friction circle, and if not the
-- tyre jumps to its sliding level: a switch, not a slip. So throttle cannot
-- dial a slide the way wheelspin does, a locked wheel is a grip multiplier,
-- and a spinning rear pushes the car along its nose only because a flag
-- says so.
--
-- Here each wheel carries an angular velocity. The tyre force comes from
-- two slips together: the slip angle (the patch moving across the wheel)
-- and the slip ratio (the tread moving faster or slower than the road).
-- Both are normalised by where they peak and combined into one slip, which
-- runs through the axle's existing grip curve, so a purely sideways tyre
-- behaves exactly as the tuned legacy tyre did. The force points the way
-- the combined slip points: a spinning rear in a slide gives most of its
-- grip to pushing forward and little to holding the tail, which is what
-- holds a hajwala slide on the gas and carries its speed; a locked rear
-- gives most of it to dragging backward and lets the tail go.
--
-- Grip also falls off with load (load sensitivity). A tyre carrying twice
-- the static load grips less than twice as hard, so weight moving across
-- or along the car changes the balance: lift and the nose bites while the
-- tail lightens, which is the physics a flick and a lift-off swing run on.
--
-- The wheel's spin is integrated in substeps with a linearised implicit
-- update, because the tyre's longitudinal stiffness is far too high for an
-- explicit step at 60 Hz. The chassis velocity is held constant across the
-- substeps and the forces averaged, which is what the chassis sees.
local Tire = require(script.Parent.Tire)

local Wheel = {}

export type SlipConfig = {
	enabled: boolean,
	peakSlipRatio: number, -- slip ratio where longitudinal grip peaks
	lowSpeedMps: number, -- floor on the slip ratio's denominator
	loadSensitivity: number, -- grip lost per unit of load over static
	loadFactorMin: number,
	loadFactorMax: number,
	wheelInertia: number, -- kg m^2 per wheel
	engineInertia: number, -- kg m^2 at the crank, reflected through the gearing onto the driven wheels
	substepSeconds: number,
	handbrakeTorque: number, -- Nm per rear wheel at full lever
	handbrakeGripCut: number, -- extra rear grip multiplier under the lever (1 = none, all physics)
	flickRearGripMultiplier: number, -- the flick's rear grip cut in this model
	slideRelief: number, -- slide momentum for this model (see Tire.scrubRelief)
	leverRelief: number,
}

export type Force = {
	fx: number, -- N along the wheel heading
	fy: number, -- N along the wheel right
	slipRatio: number,
	slipAngleDeg: number,
	combined: number, -- normalised combined slip, 1 = at the peak
}

-- Grip multiplier for a load against the static load.
function Wheel.loadFactor(cfg: SlipConfig, load: number, staticLoad: number): number
	if staticLoad <= 0 then
		return 1
	end
	return math.clamp(1 - cfg.loadSensitivity * (load / staticLoad - 1), cfg.loadFactorMin, cfg.loadFactorMax)
end

function Wheel.slipRatio(cfg: SlipConfig, vLong: number, omega: number, radius: number): number
	return (omega * radius - vLong) / math.max(math.abs(vLong), cfg.lowSpeedMps)
end

-- Tyre force at a given wheel spin. fMax is load x grip x every multiplier.
function Wheel.force(cfg: SlipConfig, axle: Tire.AxleConfig, vLong: number, vLat: number, omega: number, radius: number, fMax: number): Force
	local slipDeg = Tire.slipAngleDeg(vLong, vLat)
	local kappa = Wheel.slipRatio(cfg, vLong, omega, radius)
	if fMax <= 0 then
		return { fx = 0, fy = 0, slipRatio = kappa, slipAngleDeg = slipDeg, combined = 0 }
	end
	local sx = kappa / cfg.peakSlipRatio
	local sy = math.abs(slipDeg) / axle.peakSlipDeg
	local s = math.sqrt(sx * sx + sy * sy)
	if s < 1e-9 then
		return { fx = 0, fy = 0, slipRatio = kappa, slipAngleDeg = slipDeg, combined = 0 }
	end
	-- The combined slip, expressed as the lateral angle it is equivalent to,
	-- runs through the axle's own grip curve: rise, peak, falloff, floor,
	-- deep floor. With no slip ratio this is exactly the legacy tyre.
	local mu = Tire.gripCurve(s * axle.peakSlipDeg, axle)
	local f = fMax * mu
	local longGrip = axle.longitudinalGrip or 1
	return {
		fx = f * (sx / s) * longGrip,
		fy = -math.sign(vLat) * f * (sy / s),
		slipRatio = kappa,
		slipAngleDeg = slipDeg,
		combined = s,
	}
end

export type StepResult = {
	omega: number,
	fx: number, -- averaged over the substeps
	fy: number,
	slipRatio: number,
	slipAngleDeg: number,
	combined: number,
}

-- Advances one wheel through dt. driveTorque is signed (+ drives forward),
-- brakeTorque is a magnitude that stops the wheel relative to the car,
-- inertia includes any reflected engine inertia.
function Wheel.step(
	cfg: SlipConfig,
	axle: Tire.AxleConfig,
	omega: number,
	vLong: number,
	vLat: number,
	radius: number,
	fMax: number,
	inertia: number,
	driveTorque: number,
	brakeTorque: number,
	dt: number
): StepResult
	local n = math.clamp(math.ceil(dt / math.max(cfg.substepSeconds, 1e-4)), 1, 32)
	local h = dt / n
	local sumFx, sumFy = 0, 0
	local last: Force = Wheel.force(cfg, axle, vLong, vLat, omega, radius, fMax)
	-- Slope of the longitudinal force against wheel spin in the linear
	-- region, the upper bound on the real slope. Using the bound only adds
	-- damping to the implicit step, it never makes it unstable.
	local longGrip = axle.longitudinalGrip or 1
	local k = if fMax > 0 then fMax * longGrip * radius / (cfg.peakSlipRatio * math.max(math.abs(vLong), cfg.lowSpeedMps)) else 0
	for _ = 1, n do
		local fx = last.fx
		-- Drive and the tyre's reaction, implicit in the tyre term.
		local denom = 1 + h * radius * k / inertia
		local nextOmega = omega + h * (driveTorque - radius * fx) / inertia / denom
		-- Brakes: Coulomb friction between wheel and car, which can take the
		-- spin to zero but never through it.
		if brakeTorque > 0 then
			local dw = h * brakeTorque / inertia
			if math.abs(nextOmega) <= dw then
				nextOmega = 0
			else
				nextOmega -= math.sign(nextOmega) * dw
			end
		end
		omega = nextOmega
		last = Wheel.force(cfg, axle, vLong, vLat, omega, radius, fMax)
		sumFx += last.fx
		sumFy += last.fy
	end
	return {
		omega = omega,
		fx = sumFx / n,
		fy = sumFy / n,
		slipRatio = last.slipRatio,
		slipAngleDeg = last.slipAngleDeg,
		combined = last.combined,
	}
end

return Wheel
