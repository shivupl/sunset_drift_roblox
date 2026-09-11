--!strict
local Tire = require(script.Parent.Parent.VehicleSim.Tire)
local Tests = require(script.Parent)
type T = Tests.T

return function(t: T)
	local axle = { grip = 1.0, peakSlipDeg = 8, slideSlipDeg = 24, slideGripRatio = 0.7 }

	-- Grip curve: linear rise, peak, linear decay, floor
	t.near(Tire.gripCurve(0, axle), 0, 1e-9, "zero slip")
	t.near(Tire.gripCurve(4, axle), 0.5, 1e-9, "half peak")
	t.near(Tire.gripCurve(8, axle), 1, 1e-9, "peak")
	t.near(Tire.gripCurve(16, axle), 0.85, 1e-9, "halfway down")
	t.near(Tire.gripCurve(24, axle), 0.7, 1e-9, "floor reached")
	t.near(Tire.gripCurve(80, axle), 0.7, 1e-9, "stays at floor")
	t.near(Tire.gripCurve(-8, axle), 1, 1e-9, "symmetric")

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
