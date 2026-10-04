--!strict
local TireHeat = require(script.Parent.Parent.TireHeat)
local CarConfig = require(script.Parent.Parent.CarConfig)
local Tests = require(script.Parent)
type T = Tests.T

local P: TireHeat.Params = CarConfig.effects.tireHeat
local DT = 1 / 60

-- Runs a tyre through `seconds` at a slide speed; returns its heat and the
-- smoke level at the end, and the first time it smoked (or nil).
local function run(heat: number, slide: number, seconds: number, grounded: boolean?): (number, number, number?)
	local g = if grounded == nil then true else grounded
	local first: number? = nil
	local level = 0
	for i = 1, math.floor(seconds / DT + 0.5) do
		heat = TireHeat.step(P, heat, slide, g, DT)
		level = TireHeat.intensity(P, heat, slide, g)
		if level > 0 and not first then
			first = i * DT
		end
	end
	return heat, level, first
end

return function(t: T)
	-- Slide speed of the contact patch ----------------------------------
	local fwd = Vector3.new(0, 0, -1)
	t.near(TireHeat.slideSpeed(P, Vector3.new(0, 0, -20), fwd, 20), 0, 1e-9, "a rolling, gripping tyre doesn't slide")
	local locked = TireHeat.slideSpeed(P, Vector3.new(0, 0, -20), fwd, 0)
	t.ok(locked > 17 and locked <= 20, `a locked tyre slides at about the car's speed ({locked})`)
	t.near(TireHeat.slideSpeed(P, Vector3.zero, fwd, 15), 15 * (1 - P.gripSlipRatio), 1e-6, "a burnout slides at the tread's speed, standing still")
	-- A drift: 60 km/h at 35 degrees to where the rear tyre points: it slides
	-- sideways at 16.7 sin 35, less the grip's share.
	local v = 60 / 3.6
	local a = math.rad(35)
	local drift = Vector3.new(v * math.sin(a), 0, -v * math.cos(a))
	local driftSlide = TireHeat.slideSpeed(P, drift, fwd, v * math.cos(a))
	t.ok(driftSlide > 6, `a 35 degree drift at 60 km/h slides hard ({driftSlide} m/s)`)
	t.near(TireHeat.slideSpeed(P, Vector3.new(0, 5, -20), fwd, 20), 0, 1e-9, "vertical motion (a bump) isn't sliding")
	-- Grip at any speed: 7 degrees of slip angle at 150 km/h, 8% spin under
	-- power at 100 km/h: no sliding.
	local fast = 150 / 3.6
	local corner = Vector3.new(fast * math.sin(math.rad(7)), 0, -fast * math.cos(math.rad(7)))
	t.near(TireHeat.slideSpeed(P, corner, fwd, fast * math.cos(math.rad(7))), 0, 1e-9, "a fast grippy corner isn't sliding")
	local pull = 100 / 3.6
	t.near(TireHeat.slideSpeed(P, Vector3.new(0, 0, -pull), fwd, pull * 1.08), 0, 1e-9, "hard acceleration on grip isn't sliding")

	-- Grip never smokes ------------------------------------------------
	local _, level, first = run(0, 1.0, 5)
	t.eq(first, nil, "hard cornering on grip (1 m/s slide) never smokes")
	t.eq(level, 0, "no smoke on grip")

	-- A drift: builds in, not on at once ----------------------------------
	local heat, full, smokedAt = run(0, 10, 2)
	t.ok(smokedAt ~= nil and (smokedAt :: number) >= 0.08, `smoke builds in after the slide starts (first at {smokedAt})`)
	t.ok(smokedAt ~= nil and (smokedAt :: number) <= 0.4, `but comes within a moment of it (first at {smokedAt})`)
	t.ok(full > 0.95, `a sustained full drift smokes fully ({full})`)
	local _, at03 = run(0, 10, 0.3)
	local _, at07 = run(0, 10, 0.7)
	t.ok(at03 < at07 and at07 > 0.8, `it thickens over the first second ({at03} at 0.3 s, {at07} at 0.7 s)`)

	-- Grip comes back: drops to wisps at once, then dies away --------------
	local h1 = TireHeat.step(P, heat, 0, true, DT)
	local justAfter = TireHeat.intensity(P, h1, 0, true)
	t.ok(justAfter > 0 and justAfter <= P.wisp + 1e-6, `the moment it grips, only wisps ({justAfter})`)
	local prev = justAfter
	local rising = false
	local hh = h1
	local goneAt: number? = nil
	for i = 1, 180 do
		hh = TireHeat.step(P, hh, 0, true, DT)
		local l = TireHeat.intensity(P, hh, 0, true)
		if l > prev + 1e-9 then
			rising = true
		end
		if l == 0 and not goneAt then
			goneAt = i * DT
		end
		prev = l
	end
	t.ok(not rising, "after the slide the smoke only ever thins")
	t.ok(goneAt ~= nil and (goneAt :: number) > 0.4 and (goneAt :: number) < 2, `the last wisps go within a second or so ({goneAt} s)`)

	-- A light slide smokes lightly ------------------------------------------
	local _, light = run(0, 4, 3)
	t.ok(light > 0 and light < 0.4, `a light slide gives light smoke ({light})`)
	local _, mid = run(0, 6, 3)
	t.ok(mid > light, "more slide, more smoke")

	-- Burnout: full smoke standing still -------------------------------------
	local _, burnout = run(0, 15, 2)
	t.ok(burnout > 0.95, `a burnout (tread 15 m/s, car still) smokes fully ({burnout})`)

	-- Lock-up from speed, then stopped -----------------------------------------
	-- Braking 30 m/s to 0 over 3 s with the wheels locked: it smokes while
	-- it skids and dies away once stopped.
	local lh, lockLevel = 0, 0
	local peak = 0
	for i = 1, 180 do
		local speed = math.max(0, 30 - 10 * i * DT)
		lh = TireHeat.step(P, lh, speed, true, DT)
		lockLevel = TireHeat.intensity(P, lh, speed, true)
		peak = math.max(peak, lockLevel)
	end
	t.ok(peak > 0.7, `a long lock-up smokes ({peak})`)
	t.ok(lockLevel < 0.15, `and once it has skidded to a stop it is nearly gone ({lockLevel})`)
	local _, stopped = run(lh, 0, 1.5)
	t.eq(stopped, 0, "stopped and cooled: no smoke")

	-- In the air: nothing ------------------------------------------------------
	local hotAir, airLevel = run(1, 20, 0.5, false)
	t.eq(airLevel, 0, "a wheel in the air gives no smoke")
	t.ok(hotAir < 1, "and cools")

	-- A short flick (0.1 s) doesn't smoke ----------------------------------------
	local _, _, flick = run(0, 10, 0.06)
	t.eq(flick, nil, "a 0.06 s twitch doesn't puff")

	-- The relay packing ---------------------------------------------------------
	local packed = TireHeat.pack({ 0, 1, 0.5, 0.2 })
	local back = TireHeat.unpack(packed)
	t.near(back[1], 0, 1e-9, "pack FL")
	t.near(back[2], 1, 1e-9, "pack FR")
	t.near(back[3], 0.5, 1 / 30, "pack RL (to a 15th)")
	t.near(back[4], 0.2, 1 / 30, "pack RR (to a 15th)")
	t.eq(TireHeat.pack({ 0, 0, 0, 0 }), 0, "no smoke packs to 0")
	t.ok(TireHeat.pack({ 1, 1, 1, 1 }) <= 65535, "fits 16 bits")
	t.near(TireHeat.unpack(-5)[1], 0, 1e-9, "junk unpacks to nothing")
end
