--!strict
local TwoWheel = require(script.Parent.Parent.VehicleSim.TwoWheel)
local Tests = require(script.Parent)
type T = Tests.T

return function(t: T)
	local cfg = {
		liftTorque = 12000,
		gravityCancel = 1.0,
		targetRollDeg = 42,
		leanTorque = 300,
		instability = 5,
		rollDamping = 20,
		leanInTorque = 1500,
		leanOutTorque = 2500,
		tipRollDeg = 60,
		landingDamping = 60,
		suspensionBias = 1.8,
		sidePickLean = 0.2,
		sidePickRollDeg = 15,
		balancedEntryMarginDeg = 5,
		landedRollDeg = 3,
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

	-- Held with no lean (the touch NATL button): lifts to the left, side -1
	local tq = TwoWheel.step(st, cfg, body, true, 0, 0, 0, 2, 2, dt)
	t.eq(st.mode, "lifting", "enters lifting")
	t.eq(st.side, -1, "default side left")
	t.near(tq, -12000, 1e-9, "lift torque toward left")
	t.eq(TwoWheel.isActive(st), true, "lifting active")

	-- Lean right at the press picks the right side and adds lean-in torque
	st = TwoWheel.new()
	tq = TwoWheel.step(st, cfg, body, true, 1, 0, 0, 2, 2, dt)
	t.eq(st.side, 1, "lean picks the side")
	t.near(tq, 12000 + 1500, 1e-9, "lift plus lean-in")

	-- Early in the lift a lean the other way still flips the side (touch flow)
	st = TwoWheel.new()
	TwoWheel.step(st, cfg, body, true, 0, 0, 0, 2, 2, dt)
	t.eq(st.side, -1, "started left")
	TwoWheel.step(st, cfg, body, true, 1, -5, 0, 2, 2, dt)
	t.eq(st.side, 1, "lean re-picks the side below sidePickRollDeg")

	-- Past that window the side is locked in
	st = TwoWheel.new()
	TwoWheel.step(st, cfg, body, true, 0, 0, 0, 2, 2, dt)
	TwoWheel.step(st, cfg, body, true, 1, -20, 0, 2, 2, dt)
	t.eq(st.side, -1, "side locked once the car is up")

	-- Balanced: gravity cancel + lean torque + damping, no divergence below target
	st = TwoWheel.new()
	TwoWheel.step(st, cfg, body, true, 1, 0, 0, 2, 2, dt)
	tq = TwoWheel.step(st, cfg, body, true, 0, 38, 10, 0, 2, dt)
	t.eq(st.mode, "balanced", "enters balanced")
	local expected = TwoWheel.gravityRestoringTorque(body, 38) * 1.0 + 300 - 20 * 10
	t.near(tq, expected, 1e-6, "balanced torque (no divergence below target)")
	t.near(st.marginDeg, 60 - 38, 1e-9, "margin to tip")
	local above = TwoWheel.step(st, cfg, body, true, 0, 50, 0, 0, 2, dt)
	t.near(above, TwoWheel.gravityRestoringTorque(body, 50) + 300 + 5 * 8, 1e-6, "divergence above target")

	-- Lean in and lean out have separate gains
	local leanIn = TwoWheel.step(st, cfg, body, true, 1, 38, 0, 0, 2, dt)
	local neutral = TwoWheel.step(st, cfg, body, true, 0, 38, 0, 0, 2, dt)
	local leanOut = TwoWheel.step(st, cfg, body, true, -1, 38, 0, 0, 2, dt)
	t.near(leanIn - neutral, 1500, 1e-6, "lean toward the lifted side adds leanInTorque")
	t.near(neutral - leanOut, 2500, 1e-6, "lean toward the grounded side subtracts leanOutTorque")

	-- Steering is not a balance input any more: it never reaches this module.
	-- Past the tip angle: tipped, zero torque
	tq = TwoWheel.step(st, cfg, body, true, 0, 61, 0, 0, 2, dt)
	t.eq(st.mode, "tipped", "tips")
	t.near(tq, 0, 1e-9, "no torque when tipped")
	t.eq(TwoWheel.isActive(st), false, "tipped inactive")
	TwoWheel.step(st, cfg, body, false, 0, 80, 0, 0, 0, dt)
	t.eq(st.mode, "idle", "release after tip -> idle")

	-- Release while balanced -> landing with damping, then idle when all four touch
	st = TwoWheel.new()
	TwoWheel.step(st, cfg, body, true, 1, 0, 0, 2, 2, dt)
	TwoWheel.step(st, cfg, body, true, 0, 40, 0, 0, 2, dt)
	tq = TwoWheel.step(st, cfg, body, false, 0, 40, 30, 0, 2, dt)
	t.eq(st.mode, "landing", "release -> landing")
	t.near(tq, -60 * 30, 1e-6, "landing damping opposes roll rate")
	TwoWheel.step(st, cfg, body, false, 0, 1, 5, 2, 2, dt)
	t.eq(st.mode, "idle", "landed")

	-- Leaning back down while still held lands it, and it does not fling
	-- itself up again until the lean is released and pressed afresh.
	st = TwoWheel.new()
	TwoWheel.step(st, cfg, body, true, 1, 0, 0, 2, 2, dt)
	TwoWheel.step(st, cfg, body, true, 0, 40, 0, 0, 2, dt)
	TwoWheel.step(st, cfg, body, true, -1, 2, -50, 2, 2, dt)
	t.eq(st.mode, "idle", "leaned back down while held -> idle")
	local stillHeld = TwoWheel.step(st, cfg, body, true, -1, 0, 0, 2, 2, dt)
	t.eq(st.mode, "idle", "stays down while the lean is still held")
	t.near(stillHeld, 0, 1e-9, "no torque while disarmed")
	TwoWheel.step(st, cfg, body, false, 0, 0, 0, 2, 2, dt)
	TwoWheel.step(st, cfg, body, true, -1, 0, 0, 2, 2, dt)
	t.eq(st.mode, "lifting", "re-lifts after the lean is released and pressed again")
	t.eq(st.side, -1, "lean left picks the left side")
end
