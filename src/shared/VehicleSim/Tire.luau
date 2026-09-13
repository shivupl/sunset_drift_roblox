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
	-- Past deepSlideSlipDeg the floor eases down again toward deepSlideGripRatio
	-- by 90 deg. A tire going fully sideways at 160 km/h scrubs less than one at
	-- 30 deg, which is what lets a tafheet 360 carry its momentum through
	-- instead of stopping the car halfway round.
	deepSlideSlipDeg: number,
	deepSlideGripRatio: number,
	-- Longitudinal grip as a multiple of the lateral peak (1 = a round
	-- friction circle). A driven tyre's tread bites harder along its rolling
	-- direction than across it, so the circle is really an ellipse: above 1
	-- the axle puts more drive down before it spins, without changing what
	-- it does sideways. Optional; nil is 1.
	longitudinalGrip: number?,
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
		if a <= axle.deepSlideSlipDeg then
			return axle.slideGripRatio
		end
		local t = math.clamp((a - axle.deepSlideSlipDeg) / math.max(90 - axle.deepSlideSlipDeg, 1), 0, 1)
		return axle.slideGripRatio + (axle.deepSlideGripRatio - axle.slideGripRatio) * t
	end
	local t = (a - axle.peakSlipDeg) / (axle.slideSlipDeg - axle.peakSlipDeg)
	return 1 - (1 - axle.slideGripRatio) * t ^ axle.falloffShape
end

-- + when the contact patch moves to the right of the wheel heading.
function Tire.slipAngleDeg(vLong: number, vLat: number): number
	return math.deg(math.atan2(vLat, math.abs(vLong)))
end

function Tire.combine(
	fxDemand: number,
	fyDemand: number,
	fMax: number,
	slideGripRatio: number,
	longitudinalGrip: number?
): (number, number, boolean)
	if fMax <= 0 then
		return 0, 0, false
	end
	-- The ellipse: longitudinal demand is measured against fMax x longGrip,
	-- and eats lateral grip as if it were fxDemand / longGrip on a circle.
	local longGrip = math.max(longitudinalGrip or 1, 1e-3)
	local fxScaled = fxDemand / longGrip
	if math.abs(fxScaled) > fMax then
		-- Wheel spinning or locked: both components drop to the sliding level.
		return math.sign(fxDemand) * fMax * longGrip * slideGripRatio, fyDemand * slideGripRatio, true
	end
	local fyMax = math.sqrt(fMax * fMax - fxScaled * fxScaled)
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
	local fx, fy, saturated = Tire.combine(fxDemand, fyDemand, fMax, axle.slideGripRatio, axle.longitudinalGrip)
	-- Lateral force fades out near standstill so a parked car does not
	-- twitch from numerical noise. Drive/brake demand is not faded here;
	-- braking is faded by the caller.
	local speed = math.sqrt(vLong * vLong + vLat * vLat)
	local fade = math.clamp(speed / speedFadeMps, 0, 1)
	return { fx = fx, fy = fy * fade, slipAngleDeg = slip, saturated = saturated }
end

-- SLIDE MOMENTUM. A hajwala car sideways at 100 km/h carries its speed for
-- hundreds of metres: the rears are spinning, so their friction is mostly
-- along their rolling direction, and a sliding tyre's friction is lower than
-- a gripping one's. A slip-angle model gets neither, so every degree of
-- slide turns lateral grip straight into drag and the car scrubs to a stop.
--
-- This is the fraction of that scrub to hand back. The caller splits each
-- tyre's lateral force into the part along the car's velocity (the drag) and
-- the part across it (what bends the path), and cancels this fraction of the
-- drag with a force at the centre of mass. The across part, every yaw
-- moment and so the whole steering, throw and catch feel are untouched;
-- the car just stops bleeding speed as hard while it is sideways.
--
-- Not ice: nothing below fromDeg of drift (cornering and the grip limit are
-- as before), nothing below minSpeedKmh (a slow slide still stops), never
-- all of the scrub, and the caller never lets it make the tyres push the
-- car forward on their own.
--
-- Two levels. slideRelief is any slide, gas or lift: lifting still costs
-- speed because the drive goes and the engine brakes. leverRelief applies
-- while the handbrake is in, blending with its level: a lever 360 spends
-- two and a half seconds fully sideways on locked rears and was losing 40
-- of its 110 km/h.
export type MomentumConfig = {
	slideRelief: number, -- fraction of scrub cancelled in a slide
	leverRelief: number, -- ...and with the handbrake held
	fromDeg: number, -- drift angle where it starts
	fullDeg: number, -- and is full
	minSpeedKmh: number, -- speed where it starts
	fullSpeedKmh: number, -- and is full
}

function Tire.scrubRelief(cfg: MomentumConfig, driftAngleDeg: number, speedKmh: number, leverLevel: number): number
	-- Past 90 the car is going tail first through a spin, which is still
	-- fully sideways as far as the scrub goes.
	local a = math.min(math.abs(driftAngleDeg), 90)
	local angle = math.clamp((a - cfg.fromDeg) / math.max(cfg.fullDeg - cfg.fromDeg, 1e-3), 0, 1)
	local speed = math.clamp((speedKmh - cfg.minSpeedKmh) / math.max(cfg.fullSpeedKmh - cfg.minSpeedKmh, 1e-3), 0, 1)
	local base = cfg.slideRelief + (cfg.leverRelief - cfg.slideRelief) * math.clamp(leverLevel, 0, 1)
	return math.clamp(base, 0, 0.95) * angle * speed
end

return Tire
