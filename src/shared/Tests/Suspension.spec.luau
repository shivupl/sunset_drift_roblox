--!strict
local Suspension = require(script.Parent.Parent.VehicleSim.Suspension)
local Tests = require(script.Parent)
type T = Tests.T

return function(t: T)
	local cfg = { restLength = 0.35, travel = 0.2, stiffness = 35000, damping = 2600, bumpStopStiffness = 350000, antiRollFront = 8000, antiRollRear = 4000 }
	local r = 0.33

	local miss = Suspension.step(0.1, nil, cfg, r, 1, 1 / 60)
	t.eq(miss.grounded, false, "no hit -> not grounded")
	t.eq(miss.force, 0, "no hit -> zero force")

	-- Ground exactly at full droop: hit distance = rest + radius
	local droop = Suspension.step(0, 0.68, cfg, r, 1, 1 / 60)
	t.eq(droop.grounded, true, "hit -> grounded")
	t.near(droop.compression, 0, 1e-9, "full droop compression")
	t.near(droop.force, 0, 1e-6, "full droop force")

	-- 0.1 m compression, no velocity: force = k x
	local st = Suspension.step(0.1, 0.58, cfg, r, 1, 1 / 60)
	t.near(st.compression, 0.1, 1e-9, "compression")
	t.near(st.force, 3500, 1e-6, "spring force")

	-- Compressing at 0.6 m/s adds damping
	local dyn = Suspension.step(0.09, 0.58, cfg, r, 1, 1 / 60)
	t.near(dyn.force, 3500 + 2600 * 0.6, 1e-3, "damping adds")

	-- Rebounding fast: force clamps at zero (a spring cannot pull the car down)
	local reb = Suspension.step(0.19, 0.58, cfg, r, 1, 1 / 60)
	t.near(reb.force, 0, 1e-9, "no negative force")

	-- Past full travel: bump stop
	local bump = Suspension.step(0.2, 0.46, cfg, r, 1, 1 / 60) -- raw = 0.35 - 0.13 = 0.22
	t.near(bump.compression, 0.2, 1e-9, "compression clamps at travel")
	t.near(bump.force, 35000 * 0.2 + 350000 * 0.02, 1e-3, "bump stop adds")

	-- Stiffness multiplier (two-wheel bias)
	local biased = Suspension.step(0.1, 0.58, cfg, r, 2, 1 / 60)
	t.near(biased.force, 7000, 1e-6, "stiffness multiplier")

	t.near(Suspension.antiRoll(8000, 0.12, 0.08), 320, 1e-9, "anti-roll")
	t.near(Suspension.rayLengthM(cfg, r), 0.68 + 0.05, 1e-9, "ray length")
end
