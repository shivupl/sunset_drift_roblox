--!strict
local Tire = require(script.Parent.Parent.VehicleSim.Tire)
local Tests = require(script.Parent)
type T = Tests.T

return function(t: T)
	local axle =
		{ grip = 1.0, peakSlipDeg = 8, riseShape = 1, slideSlipDeg = 24, slideGripRatio = 0.7, falloffShape = 1 }

	-- Grip curve: linear rise, peak, linear decay, floor
	t.near(Tire.gripCurve(0, axle), 0, 1e-9, "zero slip")
	t.near(Tire.gripCurve(4, axle), 0.5, 1e-9, "half peak")
	t.near(Tire.gripCurve(8, axle), 1, 1e-9, "peak")
	t.near(Tire.gripCurve(16, axle), 0.85, 1e-9, "halfway down")
	t.near(Tire.gripCurve(24, axle), 0.7, 1e-9, "floor reached")
	t.near(Tire.gripCurve(80, axle), 0.7, 1e-9, "stays at floor")
	t.near(Tire.gripCurve(-8, axle), 1, 1e-9, "symmetric")

	-- Shaped falloff: above 1 the first degrees past peak barely cost grip
	local soft =
		{ grip = 1.0, peakSlipDeg = 8, riseShape = 1, slideSlipDeg = 24, slideGripRatio = 0.7, falloffShape = 2 }
	t.near(Tire.gripCurve(8, soft), 1, 1e-9, "peak is unchanged by the shape")
	t.near(Tire.gripCurve(24, soft), 0.7, 1e-9, "floor is unchanged by the shape")
	t.near(Tire.gripCurve(16, soft), 1 - 0.3 * 0.25, 1e-9, "shape 2 is quadratic through the decay")
	t.ok(Tire.gripCurve(12, soft) > Tire.gripCurve(12, axle), "softer falloff holds more grip near the limit")
	t.ok(Tire.gripCurve(22, soft) > Tire.gripCurve(22, axle), "and still more further out")

	-- Rise shape: below 1 the tire keeps its bite near zero slip, without
	-- moving where the peak is. This is what lets an axle peak later and
	-- still be stiff, rather than going soft everywhere below the peak.
	local stiff =
		{ grip = 1.0, peakSlipDeg = 8, riseShape = 0.5, slideSlipDeg = 24, slideGripRatio = 0.7, falloffShape = 1 }
	t.near(Tire.gripCurve(0, stiff), 0, 1e-9, "still zero at zero slip")
	t.near(Tire.gripCurve(8, stiff), 1, 1e-9, "still peaks at the same angle")
	t.near(Tire.gripCurve(2, stiff), 0.5, 1e-9, "shape 0.5 is the square root of the linear rise")
	t.ok(Tire.gripCurve(4, stiff) > Tire.gripCurve(4, axle), "stiffer below the peak")
	t.near(Tire.gripCurve(20, stiff), Tire.gripCurve(20, axle), 1e-9, "rise shape does not touch the falloff")

	-- Slip angle sign: sliding right (+vLat) => positive angle
	t.near(Tire.slipAngleDeg(10, 10), 45, 1e-9, "45 deg")
	t.near(Tire.slipAngleDeg(10, -10), -45, 1e-9, "-45 deg")
	t.near(Tire.slipAngleDeg(-10, 10), 45, 1e-9, "reversing uses |vLong|")

	-- Friction circle
	local fx, fy, sat = Tire.combine(0, 5000, 4000, 0.7)
	t.near(fx, 0, 1e-9, "no long demand")
	t.near(fy, 4000, 1e-9, "lateral clamps to circle")
	t.eq(sat, false, "not saturated")
	fx, fy, sat = Tire.combine(3000, 4000, 5000, 0.7)
	t.near(fx, 3000, 1e-9, "long has priority")
	t.near(fy, 4000, 1e-9, "3-4-5 fits")
	fx, fy, sat = Tire.combine(3000, -4000, 4000, 0.7)
	t.near(fy, -math.sqrt(4000 ^ 2 - 3000 ^ 2), 1e-6, "lateral reduced by long")
	fx, fy, sat = Tire.combine(6000, 2000, 4000, 0.7)
	t.eq(sat, true, "over the circle -> saturated")
	t.near(fx, 2800, 1e-9, "spinning long force = fMax * slide ratio")
	t.near(fy, 1400, 1e-9, "spinning lateral = demand * slide ratio")

	-- compute: sliding right at 20 m/s, 4000 N load -> leftward force
	local out = Tire.compute(20, 20, 4000, axle, 1, 0, 1)
	t.near(out.slipAngleDeg, 45, 1e-9, "slip angle")
	t.ok(out.fy < 0, "force opposes slide")
	t.near(out.fy, -4000 * Tire.gripCurve(45, axle), 1e-6, "magnitude from curve")
	-- speed fade at 0.14 m/s
	local slow = Tire.compute(0.1, 0.1, 4000, axle, 1, 0, 1)
	t.ok(math.abs(slow.fy) < 0.15 * 4000, "fades at low speed")
	-- drive force is not faded
	local drive = Tire.compute(0, 0, 4000, axle, 1, 1000, 1)
	t.near(drive.fx, 1000, 1e-9, "drive force at standstill")
	-- grip multiplier (handbrake) shrinks the circle
	local hb = Tire.compute(20, 20, 4000, axle, 0.35, 0, 1)
	t.near(hb.fy, -4000 * 0.35 * Tire.gripCurve(45, axle), 1e-6, "handbrake multiplier")
	-- no load, no force
	local air = Tire.compute(20, 20, 0, axle, 1, 500, 1)
	t.eq(air.fx, 0, "airborne fx")
	t.eq(air.fy, 0, "airborne fy")
end
