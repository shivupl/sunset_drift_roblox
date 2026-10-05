--!strict
-- The rhythm of an exhaust burst: when each pop in it comes and how big it
-- is (client ExhaustPops plays them; owner, 2026-10-04: "really cool"
-- exhaust flames, "the audio has to be like the sputter").
--
-- A crackle tune keeps injecting fuel on the overrun with the spark
-- retarded, so a lift from high revs sets off a string of small explosions
-- in the pipe: fast and irregular at first, thinning out as the revs fall,
-- mostly small cracks with the odd big bang, now and then two almost on top
-- of each other. Anti-lag fires a few big bangs; launch control's 2-step
-- bangs on an even beat. One pattern shape covers all of those (burble);
-- the old look's pops at random times in a window is the other (uniform).
--
-- Pure and seeded: every client rebuilds the same burst from the seed the
-- driver sends, so the relay carries one message a burst, not one a pop.
local ExhaustSputter = {}

export type Class = "small" | "mid" | "big"
export type Pop = { t: number, class: Class, level: number }
export type Weights = { small: number, mid: number, big: number }

export type Pattern = {
	kind: "burble" | "uniform",
	count: { number }, -- pops at scale 1 (min, max, whole)
	maxPops: number, -- never more, whatever the scale
	minGap: number, -- no two pops closer than this (s)
	maxSeconds: number, -- no pop later than this after the first (s)
	first: Class?, -- the first pop's class; drawn from the weights if nil
	weightsStart: Weights, -- how likely each class is at the start
	weightsEnd: Weights, -- and at the end (eased between)
	fade: number, -- the last pop's level relative to the first (0..1)
	levelJitter: number, -- each level times 1 - levelJitter * u, u in 0..1
	-- burble only
	gapStart: { number }?, -- seconds between the first pops (min, max)
	gapEnd: { number }?, -- and between the last ones
	jitter: number?, -- each gap times 1 +- this (uniform)
	doubleChance: number?, -- chance a gap is a quick double instead
	doubleGap: { number }?, -- that double's gap (min, max)
	-- uniform only
	spanSeconds: number?, -- the pops after the first fall at random in (0, span]
}

local function draw(rng: Random, r: { number }): number
	return r[1] + (r[2] - r[1]) * rng:NextNumber()
end

local function pick(rng: Random, w: Weights): Class
	local r = rng:NextNumber() * (w.small + w.mid + w.big)
	if r < w.small then
		return "small"
	elseif r < w.small + w.mid then
		return "mid"
	end
	return "big"
end

-- How many pops: a whole count from the pattern's range, times scale (the
-- fraction left over is the chance of one more), at least one, at most
-- maxPops.
function ExhaustSputter.count(p: Pattern, rng: Random, scale: number): number
	local scaled = rng:NextInteger(p.count[1], p.count[2]) * math.max(scale, 0)
	local n = math.floor(scaled)
	if rng:NextNumber() < scaled - n then
		n += 1
	end
	return math.clamp(n, 1, p.maxPops)
end

-- Gaps easing from gapStart to gapEnd over the burst, each jittered; now
-- and then a quick double instead.
local function burbleTimes(p: Pattern, rng: Random, n: number): { number }
	local times = { 0 }
	local t = 0
	for i = 2, n do
		local u = if n > 2 then (i - 2) / (n - 2) else 0
		local gap
		if p.doubleChance and p.doubleGap and rng:NextNumber() < p.doubleChance then
			gap = draw(rng, p.doubleGap)
		else
			local a = draw(rng, p.gapStart or { p.minGap, p.minGap })
			local b = draw(rng, p.gapEnd or { p.minGap, p.minGap })
			gap = (a + (b - a) * u) * (1 + (p.jitter or 0) * (2 * rng:NextNumber() - 1))
		end
		t += math.max(gap, p.minGap)
		if t > p.maxSeconds then
			break
		end
		table.insert(times, t)
	end
	return times
end

-- The first pop at once, the rest at random in the window, pushed apart to
-- minGap so two never land together.
local function uniformTimes(p: Pattern, rng: Random, n: number): { number }
	local drawn = {}
	for _ = 2, n do
		table.insert(drawn, rng:NextNumber() * (p.spanSeconds or 0))
	end
	table.sort(drawn)
	local times = { 0 }
	for _, d in drawn do
		local t = math.max(d, times[#times] + p.minGap)
		if t > p.maxSeconds then
			break
		end
		table.insert(times, t)
	end
	return times
end

-- The pops of one burst, the first at t = 0, in time order.
function ExhaustSputter.generate(p: Pattern, seed: number, scale: number): { Pop }
	local rng = Random.new(seed)
	local n = ExhaustSputter.count(p, rng, scale)
	local times: { number } = if p.kind == "uniform" then uniformTimes(p, rng, n) else burbleTimes(p, rng, n)
	local pops: { Pop } = {}
	for i, t in times do
		local u = if #times > 1 then (i - 1) / (#times - 1) else 0
		local w = {
			small = p.weightsStart.small + (p.weightsEnd.small - p.weightsStart.small) * u,
			mid = p.weightsStart.mid + (p.weightsEnd.mid - p.weightsStart.mid) * u,
			big = p.weightsStart.big + (p.weightsEnd.big - p.weightsStart.big) * u,
		}
		local class: Class = if i == 1 and p.first then p.first else pick(rng, w)
		local level = (1 + (p.fade - 1) * u) * (1 - p.levelJitter * rng:NextNumber())
		table.insert(pops, { t = t, class = class, level = math.clamp(level, 1e-3, 1) })
	end
	return pops
end

return ExhaustSputter
