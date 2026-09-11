--!strict
local TwoWheel = require(script.Parent.Parent.VehicleSim.TwoWheel)
local Tests = require(script.Parent)
type T = Tests.T

return function(t: T)
	local cfg = {
		liftTorque = 12000,
		gravityCancel = 1.0,
		targetRollDeg = 42,
		instability = 5,
		rollDamping = 20,
		balanceTorque = 1500,
		tipRollDeg = 60,
		landingDamping = 60,
		suspensionBias = 1.8,
	}
	local body = { massKg = 1600, gravity = 9.81, comHeightM = 0.52, halfTrackM = 0.775 }
	local dt = 1 / 60

	-- Gravity torque: full restoring at 0 roll, zero at the static tip angle
	t.near(TwoWheel.gravityRestoringTorque(body, 0), 1600 * 9.81 * 0.775, 1e-6, "restoring at level")
	local tipDeg = math.deg(math.atan(0.775 / 0.52))
	t.near(TwoWheel.gravityRestoringTorque(body, tipDeg), 0, 1e-6, "zero at tip angle")
	t.ok(TwoWheel.gravityRestoringTorque(body, 70) < 0, "negative past tip")

	-- Idle, not held: nothing
	local st = TwoWheel.new()
	t.near(TwoWheel.step(st, cfg, body, false, 0, 0, 0, 2, 2, dt), 0, 1e-9, "idle no torque")
	t.eq(st.mode, "idle", "stays idle")
	t.eq(TwoWheel.isActive(st), false, "idle inactive")

	-- Press with no steer: lifts to the left (side -1), world torque negative
	local tq = TwoWheel.step(st, cfg, body, true, 0, 0, 0, 2, 2, dt)
	t.eq(st.mode, "lifting", "enters lifting")
	t.eq(st.side, -1, "default side left")
	t.near(tq, -12000, 1e-9, "lift torque toward left")
	t.eq(TwoWheel.isActive(st), true, "lifting active")

	-- Press with right steer: side +1
	st = TwoWheel.new()
	TwoWheel.step(st, cfg, body, true, 0.6, 0, 0, 2, 2, dt)
	t.eq(st.side, 1, "steer picks side")

	-- Reaching target-5 while lifting -> balanced; torque = gravity cancel + instability + damping
	st = TwoWheel.new()
	TwoWheel.step(st, cfg, body, true, 0.6, 0, 0, 2, 2, dt)
	tq = TwoWheel.step(st, cfg, body, true, 0, 38, 10, 0, 2, dt)
	t.eq(st.mode, "balanced", "enters balanced")
	local expected = TwoWheel.gravityRestoringTorque(body, 38) * 1.0 + 5 * (38 - 42) - 20 * 10
	t.near(tq, expected, 1e-6, "balanced torque")
	t.near(st.marginDeg, 60 - 38, 1e-9, "margin to tip")

	-- Steering toward the grounded side (steer +, side +) reduces the torque
	local withBalance = TwoWheel.step(st, cfg, body, true, 1, 38, 0, 0, 2, dt)
	local noBalance = TwoWheel.step(st, cfg, body, true, 0, 38, 0, 0, 2, dt)
	t.near(withBalance, noBalance - 1500, 1e-6, "balance input reduces roll")

	-- Past the tip angle: tipped, zero torque
	tq = TwoWheel.step(st, cfg, body, true, 0, 61, 0, 0, 2, dt)
	t.eq(st.mode, "tipped", "tips")
	t.near(tq, 0, 1e-9, "no torque when tipped")
	t.eq(TwoWheel.isActive(st), false, "tipped inactive")
	TwoWheel.step(st, cfg, body, false, 0, 80, 0, 0, 0, dt)
	t.eq(st.mode, "idle", "release after tip -> idle")

	-- Release while balanced -> landing with damping, then idle when all four touch
	st = TwoWheel.new()
	TwoWheel.step(st, cfg, body, true, 0.6, 0, 0, 2, 2, dt)
	TwoWheel.step(st, cfg, body, true, 0, 40, 0, 0, 2, dt)
	tq = TwoWheel.step(st, cfg, body, false, 0, 40, -30, 0, 2, dt)
	t.eq(st.mode, "landing", "release -> landing")
	t.near(tq, -60 * -30, 1e-6, "landing damping opposes roll rate (world sign)")
	TwoWheel.step(st, cfg, body, false, 0, 1, -5, 2, 2, dt)
	t.eq(st.mode, "idle", "landed")

	-- Balanced with roll falling back to level -> idle
	st = TwoWheel.new()
	TwoWheel.step(st, cfg, body, true, 0.6, 0, 0, 2, 2, dt)
	TwoWheel.step(st, cfg, body, true, 0, 40, 0, 0, 2, dt)
	TwoWheel.step(st, cfg, body, true, 0, 2, -50, 2, 2, dt)
	t.eq(st.mode, "idle", "came back down while held -> idle (can re-lift)")
end
