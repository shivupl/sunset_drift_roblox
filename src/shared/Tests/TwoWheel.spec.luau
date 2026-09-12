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
		minLiftSpeedKmh = 45,
		fullLiftSpeedKmh = 80,
		holdFadeSpeedKmh = 30,
		leanHoldDecaySeconds = 0.45,
		leanHoldFloor = 0.3,
		leanInHoldFloor = 0.3, -- the topple is exercised below with its own config
		balanceSpring = 0, -- specs exercise the pure pendulum
		balanceSpringOneSided = true, -- the symmetric spring gets its own case below
		balanceSpringDecaySeconds = 3,
		balanceSpringFloor = 0.3,
		balanceCancelFloor = 1, -- and never let gravity back in
		landHoldSeconds = 99, -- and never auto-land
	}
	local FAST = 100 -- km/h, full authority everywhere
	local body = { massKg = 1600, gravity = 9.81, comHeightM = 0.52, halfTrackM = 0.775 }
	local dt = 1 / 60

	-- Gravity torque: full restoring at 0 roll, zero at the static tip angle
	t.near(TwoWheel.gravityRestoringTorque(body, 0), 1600 * 9.81 * 0.775, 1e-6, "restoring at level")
	local tipDeg = math.deg(math.atan(0.775 / 0.52))
	t.near(TwoWheel.gravityRestoringTorque(body, tipDeg), 0, 1e-6, "zero at tip angle")
	t.ok(TwoWheel.gravityRestoringTorque(body, 70) < 0, "negative past tip")

	-- A tipped car comes back to idle once it is on its wheels again
	do
		local tipped = TwoWheel.new()
		tipped.mode = "tipped"
		TwoWheel.step(tipped, cfg, body, false, 0, 0, 70, 0, 0, 2, dt, FAST)
		t.eq(tipped.mode, "tipped", "still over: still tipped")
		TwoWheel.step(tipped, cfg, body, false, 0, 0, 1, 0, 2, 2, dt, FAST)
		t.eq(tipped.mode, "idle", "back on four wheels: idle again")
		TwoWheel.step(tipped, cfg, body, false, 1, 0, 0, 0, 2, 2, dt, FAST)
		t.eq(tipped.mode, "lifting", "and a tap lifts it again")
	end

	-- The balance spring lifts below the target and does nothing above it
	do
		local sprung = table.clone(cfg)
		sprung.balanceSpring = 100
		local st3 = TwoWheel.new()
		TwoWheel.step(st3, sprung, body, true, 0, 1, 0, 0, 2, 2, dt, FAST)
		TwoWheel.step(st3, sprung, body, true, 0, 0, 38, 0, 0, 2, dt, FAST)
		local below = TwoWheel.step(st3, sprung, body, true, 0, 0, 32, 0, 0, 2, dt, FAST)
		local expectBelow = TwoWheel.gravityRestoringTorque(body, 32) * 1.0 + 300 + 100 * st3.springEnv * 10
		t.near(below, expectBelow, 1e-6, "below the target the spring lifts")
		local above = TwoWheel.step(st3, sprung, body, true, 0, 0, 50, 0, 0, 2, dt, FAST)
		t.near(above, TwoWheel.gravityRestoringTorque(body, 50) + 300 + 5 * 8, 1e-6, "above it the spring is silent")
	end

	-- Symmetric (the shipped setting): above the target the spring pulls the
	-- car back down, which is what stops a held key carrying it over.
	do
		local sym = table.clone(cfg)
		sym.balanceSpring = 100
		sym.balanceSpringOneSided = false
		local st4 = TwoWheel.new()
		TwoWheel.step(st4, sym, body, true, 0, 1, 0, 0, 2, 2, dt, FAST)
		TwoWheel.step(st4, sym, body, true, 0, 0, 38, 0, 0, 2, dt, FAST)
		local above = TwoWheel.step(st4, sym, body, true, 0, 0, 50, 0, 0, 2, dt, FAST)
		local expectAbove = TwoWheel.gravityRestoringTorque(body, 50) + 300 + 5 * 8 + 100 * st4.springEnv * (42 - 50)
		t.near(above, expectAbove, 1e-6, "above the target the symmetric spring pulls back down")
		t.ok(100 * st4.springEnv * (42 - 50) < 0, "and that pull is negative, toward level")
	end

	-- Held in-key with leanInHoldFloor 1 never lets up (the topple); the
	-- catch key still decays.
	do
		local topple = table.clone(cfg)
		topple.leanInHoldFloor = 1
		local st2 = TwoWheel.new()
		TwoWheel.step(st2, cfg, body, true, 0, 1, 0, 0, 2, 2, dt, FAST) -- right side
		TwoWheel.step(st2, cfg, body, true, 0, 0, 38, 0, 0, 2, dt, FAST)
		local base = TwoWheel.step(st2, topple, body, true, 0, 0, 38, 0, 0, 2, dt, FAST)
		local pushed = base
		for _ = 1, 120 do
			pushed = TwoWheel.step(st2, topple, body, true, 0, 1, 38, 0, 0, 2, dt, FAST)
		end
		t.near(pushed - base, 1500, 1e-6, "the in-key held 2 s still pushes at full leanInTorque")
		local caught = base
		TwoWheel.step(st2, topple, body, true, 0, 0, 38, 0, 0, 2, dt, FAST)
		for _ = 1, 120 do
			caught = TwoWheel.step(st2, topple, body, true, 1, 0, 38, 0, 0, 2, dt, FAST)
		end
		t.near(base - caught, 2500 * 0.3, 30, "the catch key held 2 s has decayed to the floor")
	end

	-- Idle, not held: nothing
	local st = TwoWheel.new()
	t.near(TwoWheel.step(st, cfg, body, false, 0, 0, 0, 0, 2, 2, dt, FAST), 0, 1e-9, "idle no torque")
	t.eq(st.mode, "idle", "stays idle")
	t.eq(TwoWheel.isActive(st), false, "idle inactive")

	-- Held with no lean (the touch NATL button): lifts to the left, side -1
	local tq = TwoWheel.step(st, cfg, body, true, 0, 0, 0, 0, 2, 2, dt, FAST)
	t.eq(st.mode, "lifting", "enters lifting")
	t.eq(st.side, -1, "default side left")
	t.near(tq, -12000, 1e-9, "lift torque toward left")
	t.eq(TwoWheel.isActive(st), true, "lifting active")

	-- Lean right at the press picks the right side and adds lean-in torque
	st = TwoWheel.new()
	tq = TwoWheel.step(st, cfg, body, true, 0, 1, 0, 0, 2, 2, dt, FAST)
	t.eq(st.side, 1, "lean picks the side")
	t.near(tq, 12000 + 1500, 1e-9, "lift plus lean-in")

	-- Early in the lift a lean the other way still flips the side (touch flow)
	st = TwoWheel.new()
	TwoWheel.step(st, cfg, body, true, 0, 0, 0, 0, 2, 2, dt, FAST)
	t.eq(st.side, -1, "started left")
	TwoWheel.step(st, cfg, body, true, 0, 1, -5, 0, 2, 2, dt, FAST)
	t.eq(st.side, 1, "lean re-picks the side below sidePickRollDeg")

	-- Past that window the side is locked in
	st = TwoWheel.new()
	TwoWheel.step(st, cfg, body, true, 0, 0, 0, 0, 2, 2, dt, FAST)
	TwoWheel.step(st, cfg, body, true, 0, 1, -20, 0, 2, 2, dt, FAST)
	t.eq(st.side, -1, "side locked once the car is up")

	-- Balanced: gravity cancel + lean torque + damping, no divergence below target
	st = TwoWheel.new()
	TwoWheel.step(st, cfg, body, true, 0, 1, 0, 0, 2, 2, dt, FAST)
	tq = TwoWheel.step(st, cfg, body, true, 0, 0, 38, 10, 0, 2, dt, FAST)
	t.eq(st.mode, "balanced", "enters balanced")
	local expected = TwoWheel.gravityRestoringTorque(body, 38) * 1.0 + 300 - 20 * 10
	t.near(tq, expected, 1e-6, "balanced torque (no divergence below target)")
	t.near(st.marginDeg, 60 - 38, 1e-9, "margin to tip")
	local above = TwoWheel.step(st, cfg, body, true, 0, 0, 50, 0, 0, 2, dt, FAST)
	t.near(above, TwoWheel.gravityRestoringTorque(body, 50) + 300 + 5 * 8, 1e-6, "divergence above target")

	-- Lean in and lean out have separate gains
	local leanIn = TwoWheel.step(st, cfg, body, true, 0, 1, 38, 0, 0, 2, dt, FAST)
	local neutral = TwoWheel.step(st, cfg, body, true, 0, 0, 38, 0, 0, 2, dt, FAST)
	local leanOut = TwoWheel.step(st, cfg, body, true, 1, 0, 38, 0, 0, 2, dt, FAST)
	t.near(leanIn - neutral, 1500, 1e-6, "lean toward the lifted side adds leanInTorque")
	t.near(neutral - leanOut, 2500, 1e-6, "lean toward the grounded side subtracts leanOutTorque")

	-- Speed gates: no lift at parking speed, partial lift between the gates,
	-- and the hold fades away at a crawl so the car settles by itself.
	st = TwoWheel.new()
	t.near(TwoWheel.step(st, cfg, body, true, 1, 0, 0, 0, 2, 2, dt, 20), 0, 1e-9, "no lift at 20 km/h")
	t.eq(st.mode, "idle", "stays idle below minLiftSpeedKmh")
	st = TwoWheel.new()
	local partial = TwoWheel.step(st, cfg, body, true, 0, 0, 0, 0, 2, 2, dt, 62.5)
	t.eq(st.mode, "lifting", "lifts between the gates")
	t.near(partial, -12000 * 0.5, 1e-6, "half lift authority halfway between the gates")
	st = TwoWheel.new()
	TwoWheel.step(st, cfg, body, true, 0, 1, 0, 0, 2, 2, dt, FAST)
	TwoWheel.step(st, cfg, body, true, 0, 0, 38, 0, 0, 2, dt, FAST)
	local slow = TwoWheel.step(st, cfg, body, true, 0, 0, 38, 0, 0, 2, dt, 30)
	t.near(slow, 0, 1e-9, "hold authority is zero at holdFadeSpeedKmh: gravity takes it down")
	local midSlow = TwoWheel.step(st, cfg, body, true, 0, 0, 38, 0, 0, 2, dt, 37.5)
	t.near(midSlow, (TwoWheel.gravityRestoringTorque(body, 38) + 300) * 0.5, 1e-6, "half authority halfway to minLiftSpeedKmh")

	-- Tap envelope: a fresh press is full strength, holding decays toward the floor
	st = TwoWheel.new()
	TwoWheel.step(st, cfg, body, true, 0, 1, 0, 0, 2, 2, dt, FAST)
	TwoWheel.step(st, cfg, body, true, 0, 0, 38, 0, 0, 2, dt, FAST)
	local base = TwoWheel.step(st, cfg, body, true, 0, 0, 38, 0, 0, 2, dt, FAST)
	local tap = TwoWheel.step(st, cfg, body, true, 0, 1, 38, 0, 0, 2, dt, FAST)
	t.near(tap - base, 1500, 1e-6, "fresh press pushes at full leanInTorque")
	local heldTorque = tap
	for _ = 1, 120 do
		heldTorque = TwoWheel.step(st, cfg, body, true, 0, 1, 38, 0, 0, 2, dt, FAST)
	end
	t.near(heldTorque - base, 1500 * 0.3, 15, "held for 2 s it has decayed to the floor")
	TwoWheel.step(st, cfg, body, true, 0, 0, 38, 0, 0, 2, dt, FAST)
	local retap = TwoWheel.step(st, cfg, body, true, 0, 1, 38, 0, 0, 2, dt, FAST)
	t.near(retap - base, 1500, 1e-6, "release and press again is full strength again")
	local flip = TwoWheel.step(st, cfg, body, true, 1, 0, 38, 0, 0, 2, dt, FAST)
	t.near(base - flip, 2500, 1e-6, "switching direction is a fresh press the other way")

	-- Tapping the other key while one is held is a full catch against the
	-- held key's faded push, and letting it go does not re-fire the held key.
	st = TwoWheel.new()
	TwoWheel.step(st, cfg, body, true, 0, 1, 0, 0, 2, 2, dt, FAST)
	TwoWheel.step(st, cfg, body, true, 0, 1, 38, 0, 0, 2, dt, FAST)
	local heldRef = 0
	for _ = 1, 120 do
		heldRef = TwoWheel.step(st, cfg, body, true, 0, 1, 38, 0, 0, 2, dt, FAST)
	end
	local both = TwoWheel.step(st, cfg, body, true, 1, 1, 38, 0, 0, 2, dt, FAST)
	t.near(heldRef - both, 2500, 5, "tap the other key: full leanOut against the faded hold")
	local after = TwoWheel.step(st, cfg, body, true, 0, 1, 38, 0, 0, 2, dt, FAST)
	t.near(after, heldRef, 25, "releasing the tap does not re-fire the held key")

	-- Steering is not a balance input any more: it never reaches this module.
	-- Past the tip angle: tipped, zero torque
	tq = TwoWheel.step(st, cfg, body, true, 0, 0, 61, 0, 0, 2, dt, FAST)
	t.eq(st.mode, "tipped", "tips")
	t.near(tq, 0, 1e-9, "no torque when tipped")
	t.eq(TwoWheel.isActive(st), false, "tipped inactive")
	TwoWheel.step(st, cfg, body, false, 0, 0, 80, 0, 0, 0, dt, FAST)
	t.eq(st.mode, "idle", "release after tip -> idle")

	-- Release while balanced -> landing with damping, then idle when all four touch
	st = TwoWheel.new()
	TwoWheel.step(st, cfg, body, true, 0, 1, 0, 0, 2, 2, dt, FAST)
	TwoWheel.step(st, cfg, body, true, 0, 0, 40, 0, 0, 2, dt, FAST)
	tq = TwoWheel.step(st, cfg, body, false, 0, 0, 40, 30, 0, 2, dt, FAST)
	t.eq(st.mode, "landing", "release -> landing")
	t.near(tq, -60 * 30, 1e-6, "landing damping opposes roll rate")
	TwoWheel.step(st, cfg, body, false, 0, 0, 1, 5, 2, 2, dt, FAST)
	t.eq(st.mode, "idle", "landed")

	-- Leaning back down while still held lands it, and it does not fling
	-- itself up again until the lean is released and pressed afresh.
	st = TwoWheel.new()
	TwoWheel.step(st, cfg, body, true, 0, 1, 0, 0, 2, 2, dt, FAST)
	TwoWheel.step(st, cfg, body, true, 0, 0, 40, 0, 0, 2, dt, FAST)
	TwoWheel.step(st, cfg, body, true, 1, 0, 2, -50, 2, 2, dt, FAST)
	t.eq(st.mode, "idle", "leaned back down while held -> idle")
	local stillHeld = TwoWheel.step(st, cfg, body, true, 1, 0, 0, 0, 2, 2, dt, FAST)
	t.eq(st.mode, "idle", "stays down while the lean is still held")
	t.near(stillHeld, 0, 1e-9, "no torque while disarmed")
	TwoWheel.step(st, cfg, body, false, 0, 0, 0, 0, 2, 2, dt, FAST)
	TwoWheel.step(st, cfg, body, true, 1, 0, 0, 0, 2, 2, dt, FAST)
	t.eq(st.mode, "lifting", "re-lifts after the lean is released and pressed again")
	t.eq(st.side, -1, "lean left picks the left side")
end
