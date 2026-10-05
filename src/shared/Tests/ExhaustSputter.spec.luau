--!strict
local ExhaustSputter = require(script.Parent.Parent.ExhaustSputter)
local Tests = require(script.Parent)
type T = Tests.T
type Pattern = ExhaustSputter.Pattern
type Pop = ExhaustSputter.Pop

local even = { small = 0, mid = 1, big = 0 }

-- Test patterns of each kind, independent of the tuned styles.
local crackle: Pattern = {
	kind = "burble", count = { 8, 12 }, maxPops = 20, minGap = 0.012, maxSeconds = 2,
	first = "big", weightsStart = { small = 0.4, mid = 0.4, big = 0.2 }, weightsEnd = { small = 0.9, mid = 0.1, big = 0 },
	fade = 0.4, levelJitter = 0.2,
	gapStart = { 0.03, 0.05 }, gapEnd = { 0.14, 0.16 }, jitter = 0.3, doubleChance = 0.2, doubleGap = { 0.015, 0.03 },
}
local beat: Pattern = {
	kind = "burble", count = { 8, 8 }, maxPops = 8, minGap = 0.05, maxSeconds = 2,
	weightsStart = even, weightsEnd = even, fade = 1, levelJitter = 0,
	gapStart = { 0.09, 0.09 }, gapEnd = { 0.09, 0.09 }, jitter = 0.08,
}
local window: Pattern = {
	kind = "uniform", count = { 1, 3 }, maxPops = 8, minGap = 0.04, maxSeconds = 0.6,
	weightsStart = even, weightsEnd = even, fade = 1, levelJitter = 0.45, spanSeconds = 0.5,
}

local function shapeOk(p: Pattern, pops: { Pop }): (boolean, string)
	if #pops < 1 then
		return false, "no pops"
	end
	if pops[1].t ~= 0 then
		return false, "first pop not at 0"
	end
	for i, pop in pops do
		if pop.level <= 0 or pop.level > 1 then
			return false, `level {pop.level} out of (0, 1]`
		end
		if pop.t > p.maxSeconds + 1e-9 then
			return false, `pop at {pop.t} past maxSeconds`
		end
		if i > 1 and pop.t - pops[i - 1].t < p.minGap - 1e-9 then
			return false, `gap {pop.t - pops[i - 1].t} under minGap`
		end
	end
	return true, ""
end

return function(t: T)
	-- The same seed gives the same burst (every client rebuilds it).
	local a = ExhaustSputter.generate(crackle, 1234, 1)
	local b = ExhaustSputter.generate(crackle, 1234, 1)
	local same = #a == #b
	for i = 1, math.min(#a, #b) do
		same = same and a[i].t == b[i].t and a[i].class == b[i].class and a[i].level == b[i].level
	end
	t.ok(same, "a seed gives the same pops")
	local c = ExhaustSputter.generate(crackle, 1235, 1)
	t.ok(#c ~= #a or c[2].t ~= a[2].t, "another seed gives another burst")

	-- Counts: the pattern's range times scale, at least one, at most maxPops.
	local rng = Random.new(7)
	local lo, hi = math.huge, 0
	for _ = 1, 400 do
		local n = ExhaustSputter.count(crackle, rng, 2)
		lo, hi = math.min(lo, n), math.max(hi, n)
	end
	t.ok(lo >= 16 and hi <= 20, `scale 2 gives 16..20 pops (got {lo}..{hi})`)
	t.eq(ExhaustSputter.count(crackle, Random.new(1), 0), 1, "scale 0 still pops once")
	t.eq(ExhaustSputter.count(crackle, Random.new(1), 10), crackle.maxPops, "a huge scale is capped at maxPops")

	-- Every burst's shape, over many seeds.
	local bad = ""
	local firstGaps, lastGaps, lateSmall, late = 0, 0, 0, 0
	local firstLevel, lastLevel = 0, 0
	for seed = 1, 300 do
		local pops = ExhaustSputter.generate(crackle, seed, 1)
		local ok, why = shapeOk(crackle, pops)
		if not ok and bad == "" then
			bad = `seed {seed}: {why}`
		end
		if pops[1].class ~= "big" and bad == "" then
			bad = `seed {seed}: first pop is {pops[1].class}`
		end
		if #pops >= 7 then
			for i = 2, 4 do
				firstGaps += pops[i].t - pops[i - 1].t
			end
			for i = #pops - 2, #pops do
				lastGaps += pops[i].t - pops[i - 1].t
			end
			firstLevel += pops[2].level
			lastLevel += pops[#pops].level
		end
		for i = math.ceil(#pops / 2) + 1, #pops do
			late += 1
			if pops[i].class == "small" then
				lateSmall += 1
			end
		end
	end
	t.eq(bad, "", "every crackle is in order, inside its span, gaps over minGap, levels in (0, 1], first pop big")
	t.ok(lastGaps > 1.8 * firstGaps, `a crackle thins out (last gaps {lastGaps} vs first {firstGaps})`)
	t.ok(lastLevel < firstLevel, "a crackle fades")
	t.ok(late > 0 and lateSmall / late > 0.6, `the late pops are mostly small ({lateSmall}/{late})`)

	-- An even beat (2-Step): every gap within the jitter of the beat.
	local spread = 0
	for seed = 1, 50 do
		local pops = ExhaustSputter.generate(beat, seed, 1)
		t.eq(#pops, 8, "the beat has its 8 pops")
		local g0, g1 = math.huge, 0
		for i = 2, #pops do
			local g = pops[i].t - pops[i - 1].t
			g0, g1 = math.min(g0, g), math.max(g1, g)
		end
		spread = math.max(spread, (g1 - g0) / 0.09)
	end
	t.ok(spread <= 0.17, `the beat stays even (spread {spread} of a beat)`)

	-- Uniform (Classic): 1 to 3 pops inside the window, first at once.
	local wbad = ""
	for seed = 1, 200 do
		local pops = ExhaustSputter.generate(window, seed, 1)
		local ok, why = shapeOk(window, pops)
		if (not ok or #pops > 3) and wbad == "" then
			wbad = `seed {seed}: {why} n={#pops}`
		end
	end
	t.eq(wbad, "", "every Classic burst is 1-3 pops inside its window")
end
