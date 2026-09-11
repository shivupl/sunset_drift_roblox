--!strict
local Scoring = require(script.Parent.Parent.Scoring)
local Tests = require(script.Parent)
type T = Tests.T

return function(t: T)
	local cfg: Scoring.Config = {
		minAngleDeg = 12,
		minSpeedKmh = 30,
		graceSeconds = 1.2,
		spinOutSpeedKmh = 12,
		impactDecelKmhPerSec = 250,
		impactSmoothSeconds = 0.15,
		pointsPerSecond = 100,
		referenceAngleDeg = 45,
		referenceSpeedKmh = 100,
		maxAngleFactor = 2.5,
		chainStep = 0.5,
		chainMax = 5,
		minBankPoints = 50,
		cashPerPoint = 0.01,
		maxPlausibleSpeedKmh = 320,
		teleportToleranceM = 8,
		serverTolerance = 1.25,
		claimWindowSeconds = 1.5,
		sampleHz = 20,
	}

	-- Rate: the reference angle and speed are worth pointsPerSecond
	t.near(Scoring.rate(cfg, 100, 45), 100, 1e-9, "reference pays the base rate")
	t.near(Scoring.rate(cfg, 200, 45), 200, 1e-9, "twice the speed pays twice")
	t.near(Scoring.rate(cfg, 100, 90), 200, 1e-9, "twice the angle pays twice")
	t.near(Scoring.rate(cfg, 100, 45 * 4), 250, 1e-9, "angle factor stops at maxAngleFactor")
	t.near(Scoring.rate(cfg, 100, -45), 100, 1e-9, "sign of the angle does not matter")

	-- A steady slide accrues at that rate and holds multiplier 1.
	-- banked and dropped last a single step, so the helper collects them the
	-- way a caller stepping the sim every frame would.
	type Run = { banked: number, dropped: boolean, reason: string }
	local function run(state, speed: number, angle: number, seconds: number, dt: number): Run
		local got: Run = { banked = 0, dropped = false, reason = "" }
		for _ = 1, math.round(seconds / dt) do
			Scoring.step(state, cfg, { speedKmh = speed, driftAngleDeg = angle }, dt)
			got.banked += state.banked
			if state.dropped then
				got.dropped = true
				got.reason = state.reason
			end
		end
		return got
	end
	-- A slide bleeding off speed, the way losing one actually looks.
	local function coast(state, from: number, to: number, angle: number, seconds: number, dt: number): Run
		local got: Run = { banked = 0, dropped = false, reason = "" }
		local steps = math.round(seconds / dt)
		for i = 1, steps do
			local speed = from + (to - from) * (i / steps)
			Scoring.step(state, cfg, { speedKmh = speed, driftAngleDeg = angle }, dt)
			got.banked += state.banked
			if state.dropped then
				got.dropped = true
				got.reason = state.reason
			end
		end
		return got
	end

	local s = Scoring.new()
	run(s, 100, 45, 1, 0.05)
	t.ok(s.active, "a slide is open")
	t.near(s.points, 100, 1e-6, "one second at the reference pays 100")
	t.near(s.multiplier, 1, 1e-9, "no transitions yet")

	-- Straight for less than the grace window keeps the slide alive
	local mid = run(s, 100, 0, 1.0, 0.05)
	t.ok(s.active, "still open inside the grace window")
	t.eq(mid.banked, 0, "nothing banked yet")
	-- ...and past it, it banks
	local done = run(s, 100, 0, 0.3, 0.05)
	t.eq(s.active, false, "the slide closed")
	t.eq(done.banked, 100, "banked the points it had")
	t.eq(s.points, 0, "and reset")

	-- A direction change inside the grace window links the slides
	local c = Scoring.new()
	run(c, 100, 40, 0.5, 0.05)
	t.near(c.multiplier, 1, 1e-9, "first slide is x1")
	run(c, 100, 5, 0.5, 0.05) -- straight, inside the grace window
	run(c, 100, -40, 0.5, 0.05) -- now the other way
	t.near(c.multiplier, 1.5, 1e-9, "one transition steps the multiplier")
	run(c, 100, 40, 0.2, 0.05)
	t.near(c.multiplier, 2, 1e-9, "and again")
	t.ok(c.active, "the chain is one slide, not three")

	-- The multiplier is capped
	local cap = Scoring.new()
	for i = 1, 20 do
		run(cap, 100, if i % 2 == 0 then 40 else -40, 0.1, 0.05)
	end
	t.near(cap.multiplier, cfg.chainMax, 1e-9, "multiplier stops at chainMax")

	-- Bleeding all your speed away mid-slide is a spin-out, not a crash
	local out = Scoring.new()
	run(out, 100, 60, 2, 0.05)
	t.ok(out.points > cfg.minBankPoints, "there was something to lose")
	local lost = coast(out, 100, 5, 170, 2, 0.05)
	t.eq(lost.banked, 0, "a spin-out banks nothing")
	t.ok(lost.dropped, "and reports the drop")
	t.eq(lost.reason, "spun out", "with a reason")

	-- Spinning to a standstill is a spin-out even when it happens slowly.
	-- The car drops under minSpeedKmh while still sideways, so the grace
	-- window runs out with the car pointing the wrong way.
	-- 20 km/h is under minSpeedKmh but still over spinOutSpeedKmh, so the
	-- immediate spin-out test cannot fire and the grace window decides.
	local bogged = Scoring.new()
	run(bogged, 90, 120, 2, 0.05)
	t.ok(bogged.points > cfg.minBankPoints, "the slide was worth something")
	coast(bogged, 90, 20, 120, 2, 0.05)
	local died = run(bogged, 20, 120, 2, 0.05) -- still sideways, too slow to count
	t.eq(died.banked, 0, "a slide that never straightens banks nothing")
	t.ok(died.dropped, "it drops instead")
	t.eq(died.reason, "spun out", "as a spin-out")

	-- The same slowdown, but the driver straightens up: that is a finish
	local saved = Scoring.new()
	run(saved, 90, 120, 2, 0.05)
	coast(saved, 90, 20, 120, 2, 0.05)
	local kept = run(saved, 20, 3, 2, 0.05) -- straight now, just slow
	t.ok(kept.banked > 0, "straightening out banks it even at low speed")
	t.eq(kept.dropped, false, "and is not a drop")

	-- A hard hit drops it; hard braking does not
	local hit = Scoring.new()
	run(hit, 120, 50, 2, 0.05)
	local braked = coast(hit, 120, 20, 50, 2.5, 0.05) -- 40 km/h per second
	t.eq(braked.dropped, false, "braking hard is not a crash")
	t.ok(hit.active, "and the slide survives it")
	local crash = Scoring.new()
	run(crash, 120, 50, 2, 0.05)
	local wall = coast(crash, 120, 0, 50, 0.2, 0.05) -- 600 km/h per second
	t.ok(wall.dropped, "a decel spike drops the slide")
	t.eq(wall.reason, "impact", "and names it")

	-- The same crash at the client's step size reads the same way
	local fast = Scoring.new()
	run(fast, 120, 50, 2, 1 / 240)
	local fastWall = coast(fast, 120, 0, 50, 0.2, 1 / 240)
	t.ok(fastWall.dropped, "impact detection does not depend on the step size")
	local fastBrake = Scoring.new()
	run(fastBrake, 120, 50, 2, 1 / 240)
	t.eq(coast(fastBrake, 120, 20, 50, 2.5, 1 / 240).dropped, false, "nor does braking")

	-- Slides too small to bother with are silent
	local tiny = Scoring.new()
	run(tiny, 40, 13, 0.1, 0.05)
	t.ok(tiny.points < cfg.minBankPoints, "a twitch is worth almost nothing")
	local tinyEnd = run(tiny, 40, 0, 1.5, 0.05)
	t.eq(tinyEnd.banked, 0, "and banks nothing")
	t.eq(tinyEnd.dropped, false, "without a drop message either")

	-- Under the thresholds nothing opens at all
	local none = Scoring.new()
	run(none, 100, 8, 2, 0.05)
	t.eq(none.active, false, "under minAngleDeg is not a slide")
	local slow = Scoring.new()
	run(slow, 20, 60, 2, 0.05)
	t.eq(slow.active, false, "under minSpeedKmh is not a slide")

	-- clear() throws the slide away without banking
	local cleared = Scoring.new()
	run(cleared, 100, 60, 2, 0.05)
	Scoring.clear(cleared)
	t.eq(cleared.active, false, "cleared")
	t.eq(cleared.points, 0, "with nothing left")
	-- and the next sample after a reset cannot read as an impact
	local after = run(cleared, 100, 60, 0.5, 0.05)
	t.eq(after.dropped, false, "a reset does not look like a crash")

	-- Cash conversion
	t.eq(Scoring.cashFor(cfg, 1000), 10, "1000 points is 10 cash at 0.01")
	t.eq(Scoring.cashFor(cfg, 49), 0, "and rounds down")

	-- Settling a claim against what the server saw
	t.eq(Scoring.settle(cfg, 1000, nil), 1000, "no claim, bank what the server saw")
	t.eq(Scoring.settle(cfg, 1000, 990), 990, "an honest claim is paid in full")
	t.eq(Scoring.settle(cfg, 1000, 1200), 1200, "small differences are inside the tolerance")
	t.eq(Scoring.settle(cfg, 1000, 50000), 1250, "an inflated claim is capped")

	-- Plausibility
	local a, b = Vector3.new(0, 0, 0), Vector3.new(0, 0, -10)
	t.ok(Scoring.plausible(cfg, a, b, 150, 0.05, 0.28), "normal movement passes")
	t.eq(Scoring.plausible(cfg, a, Vector3.new(0, 0, -2000), 150, 0.05, 0.28), false, "a teleport fails")
	t.eq(Scoring.plausible(cfg, a, b, 900, 0.05, 0.28), false, "an impossible speed fails")

	-- observe(): speed and drift angle from a pose and a velocity
	local idle = CFrame.new() -- identity looks down -Z
	local sp, ang = Scoring.observe(idle, Vector3.new(0, 0, -100), 0.28)
	t.near(sp, 100 * 0.28 * 3.6, 1e-6, "speed converts studs to km/h")
	t.near(ang, 0, 1e-6, "straight ahead is zero drift")
	local _, right = Scoring.observe(idle, Vector3.new(100, 0, -100), 0.28)
	t.near(right, 45, 1e-6, "velocity to the car's right is positive")
	local _, left = Scoring.observe(idle, Vector3.new(-100, 0, -100), 0.28)
	t.near(left, -45, 1e-6, "and to the left is negative")
	local _, back = Scoring.observe(idle, Vector3.new(0, 0, 100), 0.28)
	t.near(math.abs(back), 180, 1e-6, "travelling backwards is 180")
	local turned = CFrame.Angles(0, math.rad(90), 0) -- now looking down -X
	local _, turnedAngle = Scoring.observe(turned, Vector3.new(-100, 0, 0), 0.28)
	t.near(turnedAngle, 0, 1e-4, "the angle is relative to the heading, not the world")
end
