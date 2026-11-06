--!strict
-- The arcade drive's laws on a flat 2D car: the accelerations it asks for,
-- integrated with no engine, springs or collisions. Studio is where the feel
-- is measured (TUNING.md); this pins what the laws promise.
local Arcade = require(script.Parent.Parent.VehicleSim.Arcade)
local CarConfig = require(script.Parent.Parent.CarConfig)
local Tests = require(script.Parent)
type T = Tests.T

return function(t: T)
	local cfg = CarConfig.arcade :: Arcade.Config

	-- A car at kmh heading along +x, run for seconds with fixed inputs per
	-- phase. Returns the nose angle (deg, + = right of the path) at the end
	-- of each phase and the largest seen.
	local function drive(kmh: number, phases: { { any } }): ({ number }, number)
		local st = Arcade.new()
		local heading = 0 -- rad, + = right
		local vx, vy = kmh / 3.6, 0 -- world, y = right
		local yawRate = 0 -- deg/s
		local dt = 1 / 60
		local ends = {}
		local biggest = 0
		for _, ph in phases do
			local inp = ph[2]
			for _ = 1, math.floor(ph[1] / dt + 0.5) do
				local fx, fy = math.cos(heading), math.sin(heading)
				local vLong = vx * fx + vy * fy
				local vLat = -vx * fy + vy * fx
				local out = Arcade.step(cfg, st, {
					throttle = inp.t or 0,
					steer = inp.s or 0,
					handbrake = inp.h == true,
					vLong = vLong,
					vLat = vLat,
					yawRateDeg = yawRate,
					lockDeg = 38,
					wheelbaseM = 2.7,
					gravity = 9.81,
					grounded = 1,
					dt = dt,
				})
				-- Hold the speed (the engine's job) so the laws alone are tested.
				local ax = out.longAccel * fx - out.latAccel * fy
				local ay = out.longAccel * fy + out.latAccel * fx
				vx += ax * dt
				vy += ay * dt
				yawRate += out.yawAccelDeg * dt
				heading += math.rad(yawRate) * dt
				biggest = math.max(biggest, math.abs(out.noseDeg))
				t.ok(out.latAccel == out.latAccel and out.yawAccelDeg == out.yawAccelDeg, "never NaN")
			end
			local fx, fy = math.cos(heading), math.sin(heading)
			table.insert(ends, -math.deg(math.atan2(-vx * fy + vy * fx, vx * fx + vy * fy)))
		end
		return ends, biggest
	end

	local _, gentle = drive(100, { { 2, { s = 0.4 } } })
	t.ok(gentle < cfg.slideStartDeg, `0.4 steer at 100 km/h is a clean turn (nose {gentle})`)

	local full = drive(100, { { 2, { s = 1, t = 1 } }, { 2, { s = 0 } } })
	t.ok(full[1] > 35 and full[1] < 70, `full lock at 100 km/h holds a slide (nose {full[1]})`)
	t.ok(math.abs(full[2]) < 5, `let go and it straightens (nose {full[2]})`)

	local flick = drive(100, { { 1.5, { s = 1, t = 1 } }, { 2, { s = -1, t = 1 } } })
	t.ok(flick[1] > 30 and flick[2] < -30, `the other way swings it across ({flick[1]} then {flick[2]})`)

	local _, spun = drive(80, { { 2, { s = 1, h = true } } })
	t.ok(spun > 150, `the lever with full lock brings it round (largest nose {spun})`)

	local still = Arcade.step(cfg, Arcade.new(), {
		throttle = 0,
		steer = 1,
		handbrake = true,
		vLong = 0,
		vLat = 0,
		yawRateDeg = 0,
		lockDeg = 38,
		wheelbaseM = 2.7,
		gravity = 9.81,
		grounded = 1,
		dt = 1 / 60,
	})
	t.near(still.yawAccelDeg, 0, 1e-9, "parked, the lever and the wheel do not spin it")
	t.ok(not still.drifting, "parked is not a slide")
end
