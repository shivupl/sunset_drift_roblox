--!strict
-- Slip-angle tire model for one wheel. Pure: no Roblox instances.
--
-- Lateral grip rises linearly with slip angle to a peak, then decays to a
-- sliding floor. The falloff is what makes drift controllable: past the
-- peak the rear gives up some grip but not all, so a held slide is a
-- balance rather than a switch. Front and rear axles are tuned separately.
--
-- falloffShape bends that decay. At 1 it is the straight line from peak to
-- floor. Above 1 the first few degrees past peak barely cost any grip and
-- the loss steepens further out, which is the warning the driver needs: the
-- car starts moving under them well before the grip actually goes.
--
-- riseShape bends the way up. The rise is otherwise a straight line whose
-- slope is 1/peakSlipDeg, which means moving an axle's peak later silently
-- makes that axle softer at every angle below it, and a rear set up to be
-- stable would step out under power instead. Below 1 the curve is concave:
-- the tire keeps its bite near zero slip and rounds over into the peak,
-- so where the peak sits and how stiff the tire is become separate knobs.
--
-- Combined force uses a friction circle with longitudinal demand taking
-- priority (the driver commands it): throttle eats rear lateral grip, so
-- too much throttle spins and too little straightens.
local Tire = {}

export type AxleConfig = {
	grip: number, -- peak friction coefficient
	peakSlipDeg: number, -- slip angle where grip peaks
	riseShape: number, -- 1 = straight line up to peak, <1 = stiffer near zero slip
	slideSlipDeg: number, -- slip angle where grip reaches the floor
	slideGripRatio: number, -- floor as a fraction of peak
	falloffShape: number, -- 1 = straight line peak to floor, >1 = gentle at first
}

export type Output = {
	fx: number, -- N along wheel heading (+ forward)
	fy: number, -- N along wheel right (+ right)
	slipAngleDeg: number,
	saturated: boolean, -- longitudinal demand exceeded the circle (spin/lock)
}

function Tire.gripCurve(slipDeg: number, axle: AxleConfig): number
	local a = math.abs(slipDeg)
	if a <= axle.peakSlipDeg then
		return (a / axle.peakSlipDeg) ^ axle.riseShape
	end
	if a >= axle.slideSlipDeg then
		return axle.slideGripRatio
	end
	local t = (a - axle.peakSlipDeg) / (axle.slideSlipDeg - axle.peakSlipDeg)
	return 1 - (1 - axle.slideGripRatio) * t ^ axle.falloffShape
end

-- + when the contact patch moves to the right of the wheel heading.
function Tire.slipAngleDeg(vLong: number, vLat: number): number
	return math.deg(math.atan2(vLat, math.abs(vLong)))
end

function Tire.combine(fxDemand: number, fyDemand: number, fMax: number, slideGripRatio: number): (number, number, boolean)
	if fMax <= 0 then
		return 0, 0, false
	end
	if math.abs(fxDemand) > fMax then
		-- Wheel spinning or locked: both components drop to the sliding level.
		return math.sign(fxDemand) * fMax * slideGripRatio, fyDemand * slideGripRatio, true
	end
	local fyMax = math.sqrt(fMax * fMax - fxDemand * fxDemand)
	return fxDemand, math.clamp(fyDemand, -fyMax, fyMax), false
end

function Tire.compute(
	vLong: number,
	vLat: number,
	load: number,
	axle: AxleConfig,
	gripMultiplier: number,
	fxDemand: number,
	speedFadeMps: number
): Output
	if load <= 0 then
		return { fx = 0, fy = 0, slipAngleDeg = 0, saturated = false }
	end
	local slip = Tire.slipAngleDeg(vLong, vLat)
	local fMax = load * axle.grip * gripMultiplier
	local fyDemand = -math.sign(vLat) * fMax * Tire.gripCurve(slip, axle)
	local fx, fy, saturated = Tire.combine(fxDemand, fyDemand, fMax, axle.slideGripRatio)
	-- Lateral force fades out near standstill so a parked car does not
	-- twitch from numerical noise. Drive/brake demand is not faded here;
	-- braking is faded by the caller.
	local speed = math.sqrt(vLong * vLong + vLat * vLat)
	local fade = math.clamp(speed / speedFadeMps, 0, 1)
	return { fx = fx, fy = fy * fade, slipAngleDeg = slip, saturated = saturated }
end

return Tire
