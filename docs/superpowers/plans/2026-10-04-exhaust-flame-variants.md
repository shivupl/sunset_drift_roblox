# Exhaust Flame Variants Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Four new exhaust pop styles (Crackle, Anti-Lag, Blue Flame, 2-Step) plus today's look as Classic, each a sputter rhythm of real pop sounds with a flame per pop, switchable in Studio to try.

**Architecture:** A pure seeded sequencer (`ExhaustSputter`) turns a style's rhythm into pops (time, size class, level). A client player (`ExhaustPops`) plays each pop as a grain cut from a real recording (`Sound.PlaybackRegion`) and fires `ExhaustFlames.flame` on the same frame, which emits a style's layers sized by the pop's class, plus one pooled flash light. The driver relays one message a burst (kind, style, seed, scale); every client rebuilds the same burst.

**Tech Stack:** Roblox strict Luau, Rojo 7.7, Studio MCP (execute_luau, screen_capture), the repo's spec runner (`src/shared/Tests`).

**Spec:** `docs/superpowers/specs/2026-10-04-exhaust-flame-variants-design.md`

## Global Constraints

- `--!strict` on every file; no invented or deprecated APIs.
- Tunables live in config modules (`ExhaustStyles`, `CosmeticsConfig`, `CarConfig`) with the why and the owner's request beside each number.
- Pops stay as the owner ruled on 2026-09-22: a burst only on a fast lift-off; upshift and limiter single pops exist and stay 0 (off).
- Every pop heard is a flame seen, on the same frame.
- No Light beyond one pooled PointLight per client (structural cap, like the twelve street lights).
- At most 40 particles per pop per outlet, at the heaviest style's big class.
- Classic is today's flame and pop, unchanged in look and sound.
- Stage specific files only; never commit the owner's uncommitted rig files (RIG_SPEC.md, RigBuilder, CarCatalog, VehicleRig, VehicleRig.spec, tools/carbody).
- Specs run by the clone-swap in CLAUDE.md; baseline 14 VehicleRig.spec failures.
- Docs travel with the change (TUNING.md flames section, BEHAVIOURS.md lessons, BRANCH_STATUS.md).

## Review Focus

1. A car destroyed or respawned mid-burst: scheduled pops must skip quietly (no errors from a parentless model or chassis). Pinned in Task 4, step 5.
2. The exhaust look changed mid-burst (garage): outlets are rebuilt; a pop on a dead outlet is skipped, the next pop builds on the new outlets. Pinned in Task 4, step 5.
3. A grain clip that fails to load (moderated asset): that bank falls back to Classic's pop; flames still fire. Pinned in Task 4, step 3 (`ensureLoaded`) and checked in Task 4, step 5.
4. Switching style (P) mid-burst: the running burst finishes in its own style; the next uses the new one. Pinned in Task 4, step 5.
5. An old client sending the old relay shape (`FireServer(pops)`) to the new server: rejected without error. Pinned in Task 2's `validRelay` spec.

---

### Task 1: The sputter sequencer

**Files:**
- Create: `src/shared/ExhaustSputter.luau`
- Test: `src/shared/Tests/ExhaustSputter.spec.luau`

**Interfaces:**
- Produces: `ExhaustSputter.Class = "small" | "mid" | "big"`; `ExhaustSputter.Pop = { t: number, class: Class, level: number }`; `ExhaustSputter.Pattern` (fields below); `ExhaustSputter.count(p, rng: Random, scale): number`; `ExhaustSputter.generate(p, seed: number, scale: number): { Pop }`.

- [ ] **Step 1: Write the failing spec** `src/shared/Tests/ExhaustSputter.spec.luau`:

```lua
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
```

- [ ] **Step 2: Run the specs and see this one fail** (clone-swap command from CLAUDE.md, Edit datamodel). Expected: `ExhaustSputter.spec: error ... ExhaustSputter is not a valid member` (module missing); other totals unchanged (14 VehicleRig failures).

- [ ] **Step 3: Write `src/shared/ExhaustSputter.luau`:**

```lua
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
	local times = if p.kind == "uniform" then uniformTimes(p, rng, n) else burbleTimes(p, rng, n)
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
```

- [ ] **Step 4: Run the specs.** Expected: ExhaustSputter.spec all pass; total failures 14 (VehicleRig baseline). `bash scripts/analyze.sh` shows no new errors in the two files.

- [ ] **Step 5: Commit** `src/shared/ExhaustSputter.luau`, `src/shared/Tests/ExhaustSputter.spec.luau`: "Exhaust sputter: a seeded pop rhythm (burble and uniform)".

---

### Task 2: The styles config and relay check

**Files:**
- Create: `src/shared/ExhaustStyles.luau`
- Test: `src/shared/Tests/ExhaustStyles.spec.luau`
- Modify: `src/shared/Tests/CosmeticsConfig.spec.luau:49-56` (the relay-burst check moves to ExhaustStyles.spec), `src/shared/CosmeticsConfig.luau` flames block (drop `relayPopsPerSecond`, `maxPopsPerBurst`, `relayMinGapSeconds`, `soundPool`, `revPops`, `burstSeconds`; keep `layers` and the rest as Classic's look), `src/shared/CarConfig.luau` engineAudio (drop `crackleSoundId`, `crackleVolume`, `crackleVolumeRange`, `cracklePitch`, `crackleBurstPops`, `crackleBurstSeconds`, which move into Classic; add `crackleRevFloor = 0.6`).

**Interfaces:**
- Consumes: `ExhaustSputter.Pattern`, `ExhaustSputter.Class`.
- Produces:
  - `ExhaustStyles.order: { string }` = `{ "crackle", "antilag", "blue", "twostep", "classic" }`; `ExhaustStyles.default = "crackle"`.
  - `ExhaustStyles.styles: { [string]: Style }`, `Style = { name: string, pattern: Pattern, chanceGain: number, sounds: { small: Bank, mid: Bank, big: Bank }, classes: { small: ClassLook, mid: ClassLook, big: ClassLook }, light: Light?, layers: { [string]: Layer }?, layerOrder: { string }? }` (`layers` nil = Classic's `CosmeticsConfig.flames.layers`, coloured by the item as today).
  - `Bank = { grains: { Grain }, pitch: { number }, volume: number }`, `Grain = { id: string, from: number, to: number, gain: number }` (from/to seconds into the clip; from 0 and to = clip length = the whole clip).
  - `ClassLook = { size: number, count: number, speed: number, light: number }` (multipliers on the layer's size, particle count, speed, and the light's brightness).
  - `Light = { color: Color3, brightness: number, rangeM: number, seconds: number }`.
  - `Layer` = CosmeticsConfig's flame layer fields plus `flipbook: { layout: string, mode: string }?`, `colors: { { number } | any }?` (keyframes `{ time, Color3 }`), `from: Class` (smallest class that emits it), `turn: boolean?` (random rotation, camera-facing layers only).
  - `ExhaustStyles.clipSeconds: { [string]: number }` (measured lengths, for the spec).
  - `ExhaustStyles.relayPerSecond = 8`, `ExhaustStyles.maxScale = 4`.
  - `ExhaustStyles.KIND = { burst = 1, single = 2, cut = 3 }`.
  - `ExhaustStyles.index(id: string): number?`, `ExhaustStyles.validRelay(kind: any, style: any, seed: any, scale: any): boolean`.
  - `ExhaustStyles.scaleFor(style: Style, crackleChance: number, rev: number): number` = `math.clamp((1 + (crackleChance - 1) * style.chanceGain) * rev, 0, ExhaustStyles.maxScale)`.

- [ ] **Step 1: Write the failing spec** `src/shared/Tests/ExhaustStyles.spec.luau`:

```lua
--!strict
local ExhaustStyles = require(script.Parent.Parent.ExhaustStyles)
local ExhaustSputter = require(script.Parent.Parent.ExhaustSputter)
local CosmeticsConfig = require(script.Parent.Parent.CosmeticsConfig)
local Tests = require(script.Parent)
type T = Tests.T

local CLASSES = { "small", "mid", "big" }
local RANK = { small = 1, mid = 2, big = 3 }

local function sequenceOk(seq: any): boolean
	return type(seq) == "table" and seq[1][1] == 0 and seq[#seq][1] == 1
end

return function(t: T)
	t.ok(ExhaustStyles.styles[ExhaustStyles.default] ~= nil, "the default style exists")
	t.eq(#ExhaustStyles.order, 5, "five styles in the cycle")
	for i, id in ExhaustStyles.order do
		local s = ExhaustStyles.styles[id]
		t.ok(s ~= nil, `{id} is defined`)
		if not s then
			continue
		end
		t.eq(ExhaustStyles.index(id), i, `{id} has its index`)
		t.ok(s.name ~= "", `{id} has a name`)
		-- Every class has sound, and every grain sits inside its clip.
		for _, c in CLASSES do
			local bank = (s.sounds :: any)[c]
			t.ok(bank and #bank.grains > 0, `{id}.{c} has grains`)
			t.ok(bank and bank.pitch[1] > 0 and bank.pitch[1] <= bank.pitch[2], `{id}.{c} pitch range`)
			for _, g in (bank and bank.grains or {}) do
				local len = ExhaustStyles.clipSeconds[g.id]
				t.ok(len ~= nil, `{id}.{c}: clip {g.id} has a measured length`)
				t.ok(g.from >= 0 and g.from < g.to and g.to <= (len or 0) + 1e-6, `{id}.{c}: grain {g.from}-{g.to} inside {g.id}`)
				t.ok(g.gain > 0 and g.gain <= 4, `{id}.{c}: grain gain in (0, 4]`)
			end
			local look = (s.classes :: any)[c]
			t.ok(look and look.size > 0 and look.count > 0, `{id}.{c} has a look`)
		end
		-- Layers: well formed, and the big class stays in the particle budget.
		local layers = s.layers or CosmeticsConfig.flames.layers
		local most = 0
		for name, L in layers :: { [string]: any } do
			t.ok(L.count[1] >= 0 and L.count[1] <= L.count[2] and math.floor(L.count[2]) == L.count[2], `{id}.{name}: count`)
			t.ok(L.lifetime[1] > 0 and L.lifetime[1] <= L.lifetime[2] and L.lifetime[2] <= 1.5, `{id}.{name}: lifetime`)
			for _, seq in { L.size, L.transparency, L.squash } do
				t.ok(sequenceOk(seq), `{id}.{name}: sequences run 0..1`)
			end
			if L.colors then
				t.ok(sequenceOk(L.colors), `{id}.{name}: colours run 0..1`)
			end
			t.ok(s.layers == nil or RANK[L.from] ~= nil, `{id}.{name}: from is a class`)
			most += math.ceil(L.count[2] * (s.classes :: any).big.count)
		end
		t.ok(most <= 40, `{id}: at most 40 particles per big pop per outlet (is {most})`)
		-- The biggest burst the relay can ask for stays inside maxSeconds.
		local pops = ExhaustSputter.generate(s.pattern, 99, ExhaustStyles.maxScale)
		t.ok(#pops <= s.pattern.maxPops, `{id}: maxPops holds at the largest scale`)
	end

	-- The relay message.
	local K = ExhaustStyles.KIND
	t.ok(ExhaustStyles.validRelay(K.burst, 1, 12345, 1.2), "a burst is valid")
	t.ok(ExhaustStyles.validRelay(K.single, 5, 1, 1), "a single pop is valid")
	t.ok(ExhaustStyles.validRelay(K.cut, 0, 0, 0), "a cut is valid")
	t.ok(not ExhaustStyles.validRelay(1, nil, nil, nil), "the old one-number message is rejected")
	t.ok(not ExhaustStyles.validRelay(4, 1, 1, 1), "an unknown kind is rejected")
	t.ok(not ExhaustStyles.validRelay(K.burst, 0, 1, 1), "style 0 is rejected")
	t.ok(not ExhaustStyles.validRelay(K.burst, 1.5, 1, 1), "a fractional style is rejected")
	t.ok(not ExhaustStyles.validRelay(K.burst, #ExhaustStyles.order + 1, 1, 1), "a style past the list is rejected")
	t.ok(not ExhaustStyles.validRelay(K.burst, 1, 0, 1), "seed 0 is rejected")
	t.ok(not ExhaustStyles.validRelay(K.burst, 1, 2.5, 1), "a fractional seed is rejected")
	t.ok(not ExhaustStyles.validRelay(K.burst, 1, 1, 0 / 0), "a NaN scale is rejected")
	t.ok(not ExhaustStyles.validRelay(K.burst, 1, 1, ExhaustStyles.maxScale + 0.01), "a scale past maxScale is rejected")
	t.ok(not ExhaustStyles.validRelay(K.burst, 1, 1, -1), "a negative scale is rejected")

	-- The exhaust's crackleChance scales the count gently.
	local crackle = ExhaustStyles.styles.crackle
	t.near(ExhaustStyles.scaleFor(crackle, 1, 1), 1, 1e-9, "factory at full revs: scale 1")
	t.ok(ExhaustStyles.scaleFor(crackle, 2.5, 1) < 2, "titanium does not double a crackle")
	t.ok(ExhaustStyles.scaleFor(crackle, 2.5, 0.6) < ExhaustStyles.scaleFor(crackle, 2.5, 1), "lower revs, fewer pops")
end
```

- [ ] **Step 2: Run the specs; expect ExhaustStyles.spec to error (module missing).**

- [ ] **Step 3: Write `src/shared/ExhaustStyles.luau`** with the type definitions and functions from Interfaces, a header comment carrying the owner's request and the research (pops are fuel lighting in the hot pipe; crackle maps, anti-lag, 2-step, lean blue jets; blue core = clean burn, orange = soot), and these exact values.

  `relayPerSecond = 8` (a driver sends at most a burst, a cut and a single in a second; 8 never clips play and stops a flood); `maxScale = 4`.

  `clipSeconds` (measured 2026-10-04, `Sound.TimeLength` after PreloadAsync):

  | id | seconds |
  |---|---|
  | 129025289910636 | 1.297 |
  | 17651974920 | 0.594 |
  | 17651322643 | 0.549 |
  | 17865169434 | 0.158 |
  | 86084579153761 | 0.232 |
  | 1001293842 | 0.302 |
  | 112720519011313 | 0.444 |

  Grain sets (from, to in seconds; gain), cut at each pop's onset minus 3 ms to where it falls under 12% of its peak plus 20 ms, never into the next pop (AudioAnalyzer at 0.1 speed):

  - `POPS_BIG` (129025289910636, peaks at clip level): 0.052-0.090, 0.158-0.197, 0.239-0.271, 0.366-0.431, 0.440-0.467, 0.466-0.504, 0.810-0.836, 0.944-0.972, 1.015-1.071, 1.162-1.200; gain 1.
  - `POPS_MID` (same clip, peaks 0.43-0.88): 0.004-0.049, 0.270-0.298, 0.297-0.347, 0.513-0.559, 0.558-0.589, 0.617-0.643, 0.642-0.677, 0.676-0.704, 1.081-1.109, 1.211-1.257; gain 1.4.
  - `POPS_SMALL` (same clip, peaks 0.24-0.49): 0.096-0.143, 0.588-0.618, 0.835-0.865, 0.864-0.911, 0.971-1.016, 1.108-1.151; gain 2.2.
  - `CLEAN` (17651322643, peaks 0.22-0.32): 0.015-0.075, 0.096-0.165, 0.189-0.246, 0.280-0.334, 0.394-0.453, 0.477-0.527; gain 3.
  - `DENSE` (17651974920, clipped): 0.011-0.061, 0.062-0.088, 0.087-0.116, 0.115-0.147, 0.156-0.184, 0.183-0.227, 0.226-0.252, 0.251-0.307, 0.319-0.354, 0.388-0.416, 0.415-0.439, 0.470-0.497, 0.496-0.523, 0.522-0.551, 0.550-0.577; gain 0.8.
  - `CRACK` 17865169434 0-0.158 gain 1.6; `BIGPOP` 86084579153761 0-0.232 gain 1.1; `BANG` 1001293842 0-0.302 gain 0.7; `CLASSIC` 112720519011313 0-0.444 gain 1.

  Styles:

  | style | name | pattern | chanceGain | sounds (grains; pitch; volume) per class small / mid / big | light |
  |---|---|---|---|---|---|
  | crackle | Crackle | burble; count 7-14; maxPops 22; minGap 0.012; maxSeconds 2.2; first mid; weightsStart s0.45 m0.4 b0.15; weightsEnd s0.8 m0.17 b0.03; fade 0.45; levelJitter 0.35; gapStart 0.03-0.07; gapEnd 0.12-0.3; jitter 0.5; doubleChance 0.2; doubleGap 0.015-0.035 | 0.35 | POPS_SMALL+CLEAN+CRACK; 0.95-1.2; 0.3 / POPS_MID; 0.9-1.1; 0.38 / POPS_BIG; 0.85-1.0; 0.45 | #FF8A3A, 3, 8 m, 0.08 s |
  | antilag | Anti-Lag | burble; count 2-4; maxPops 6; minGap 0.1; maxSeconds 1.6; first big; weightsStart s0 m0.1 b0.9; weightsEnd s0 m0.3 b0.7; fade 0.8; levelJitter 0.2; gapStart 0.12-0.2; gapEnd 0.18-0.28; jitter 0.25 | 0.25 | POPS_MID; 0.8-0.95; 0.4 / POPS_BIG+BIGPOP; 0.75-0.9; 0.5 / BANG+BIGPOP; 0.8-0.95; 0.55 | #FF7A2A, 6, 12 m, 0.14 s |
  | blue | Blue Flame | burble; count 3-6; maxPops 9; minGap 0.02; maxSeconds 1.2; first big; weightsStart s0.25 m0.55 b0.2; weightsEnd s0.5 m0.45 b0.05; fade 0.6; levelJitter 0.25; gapStart 0.07-0.09; gapEnd 0.09-0.11; jitter 0.15; doubleChance 0.05; doubleGap 0.025-0.04 | 0.3 | POPS_SMALL+CRACK; 1.15-1.4; 0.3 / POPS_MID; 1.1-1.3; 0.36 / POPS_BIG; 1.0-1.2; 0.42 | #6A8CFF, 3.5, 9 m, 0.08 s |
  | twostep | 2-Step | burble; count 6-10; maxPops 14; minGap 0.06; maxSeconds 1.6; first big; weightsStart s0 m0.85 b0.15; weightsEnd same; fade 0.85; levelJitter 0.1; gapStart 0.08-0.1; gapEnd 0.085-0.1; jitter 0.08 | 0.3 | DENSE; 0.95-1.05; 0.3 / DENSE; 0.9-1.0; 0.36 / DENSE+BIGPOP; 0.85-0.95; 0.42 | #FF8A3A, 4, 10 m, 0.09 s |
  | classic | Classic | uniform; count 1-3; maxPops 8; minGap 0.04; maxSeconds 0.6; spanSeconds 0.5; weights all mid; fade 1; levelJitter 0.45 | 1 | CLASSIC in all three; 0.85-1.2; 0.35 | none |

  Classes (`size`, `count`, `speed`, `light`): crackle small 0.55/0.6/0.7/0.35, mid 0.8/0.8/0.85/0.65, big 1/1/1/1; antilag small 0.7/0.7/0.8/0.5, mid 0.85/0.85/0.9/0.75, big 1/1/1/1; blue small 0.6/0.7/0.75/0.4, mid 0.85/0.85/0.9/0.7, big 1/1/1/1; twostep small 0.7/0.7/0.8/0.5, mid 0.9/0.9/0.95/0.8, big 1/1/1/1; classic all 1/1/1/0.

  Layers (metres before the car's scale and the item's flameSize; size keyframes `{time, value}`; lifetime and speed min-max). Textures: `FIRE` = rbxassetid://9968039364 (Grid4x4, additive, LightEmission 1), `WHITEFIRE` = rbxassetid://17703378809 (Grid4x4), `FIREBALL` = rbxassetid://9636673935 (Grid8x8), `STAR` = rbxassetid://12156297119 (Grid4x4), `PUFF` = rbxassetid://13346862770 (Grid4x4), `HOT` = rbxasset://textures/particles/explosion01_implosion_main.dds. Every flipbook OneShot (its frames over each particle's life).

  - crackle: `root` HOT, from small, locked, along, count 3-4, jet 0.05, life 0.04-0.07, speed 1-2, size 0:0.06 0.3:0.09 1:0.03, transp 0:0 0.6:0.25 1:1, squash 0:-1.2 1:-0.8, colors 0:#E8F0FF 0.3:#4A7BFF 1:#4A7BFF, LE 0.3, br 1.2, z 0.08; `lick` FIRE, from small, locked, along, count 2-3, jet 0.05, life 0.08-0.16, speed 4-9, drag 6, rise 6, size 0:0.18 0.25:0.32 1:0.12, transp 0:0.1 0.6:0.3 1:1, squash 0:-1 1:-0.6, colors 0:#FFE6A0 0.35:#FF8A2A 1:#C83A0A, LE 1, br 1.6, z 0.04; `flash` STAR, from mid, locked, facing, count 1, life 0.06-0.09, speed 0, size 0:0.5 1:0.25, transp 0:0.2 1:1, squash 0:0 1:0, colors 0:#FFD9A0 1:#FFB060, LE 1, br 2, z 0.1; (no sparks: the research keeps them for the sooty styles) `wisp` PUFF, from mid, world, facing, turn, delay 0.05, count 1, life 0.5-0.8, speed 0.5-1, spread 15, drag 1, rise 0.4, size 0:0.15 1:0.6, transp 0:0.85 1:1, squash 0:0 1:0, colors 0:#2A2622 1:#4A4540, LE 0, br 1, z -0.03.
  - antilag: `core` as crackle root but count 4-5, size 0:0.08 0.3:0.12 1:0.04; `ball` FIREBALL, from small, world, facing, turn, count 2-3, life 0.22-0.32, speed 2-5, spread 15, drag 5, rise 3, size 0:0.35 0.3:0.75 1:0.9, transp 0:0 0.7:0.2 1:1, squash 0:0 1:0, LE 0.6, br 1.6, z 0.05; `tongue` FIRE as crackle lick but from mid, count 3-4, speed 6-11; `flash` STAR from small, size 0:0.9 1:0.4, colors 0:#FFF2D0 1:#FFB060, br 2.2; `sparks` HOT, from mid, world, along, count 6-12, life 0.25-0.5, speed 6-12, spread 20, drag 1.5, rise -4, size 0:0.025 1:0, transp 0:0 1:0.4, squash 0:-2.5 1:-2.5, colors 0:#FFE2A0 1:#FF5A14, LE 1, br 3, z 0; `soot` PUFF from big, world, facing, turn, delay 0.08, count 1-2, life 0.8-1.2, speed 0.6-1.2, spread 20, drag 1, rise 0.6, size 0:0.3 1:1.1, transp 0:0.7 1:1, colors 0:#1E1B18 1:#3A3632, LE 0, br 1.
  - blue: `core` HOT, from small, locked, along, count 4-5, jet 0.06, life 0.05-0.09, speed 1.5-3, size 0:0.07 0.3:0.11 1:0.04, transp 0:0 0.6:0.2 1:1, squash 0:-1.6 1:-1, colors 0:#FFFFFF 0.3:#9FC0FF 1:#5A86FF, LE 0.4, br 1.2, z 0.08; `jet` WHITEFIRE, from small, locked, along, count 4-6, jet 0.07, life 0.1-0.18, speed 6-12, drag 5, rise 2, size 0:0.14 0.3:0.26 1:0.08, transp 0:0.15 0.6:0.35 1:1, squash 0:-1.4 1:-0.8, colors 0:#9FC4FF 0.4:#3A6BFF 1:#7A3CFF, LE 1, br 1.3, z 0.04; `fringe` WHITEFIRE, from mid, locked, along, count 2-3, jet 0.07, life 0.12-0.2, speed 5-10, spread 12, drag 5, rise 4, size 0:0.18 0.3:0.3 1:0.1, transp 0:0.5 0.5:0.55 1:1, squash 0:-1.2 1:-0.7, colors 0:#6A3CFF 1:#C04CFF, LE 1, br 1.1, z 0; `flash` STAR from mid, colors 0:#BFD2FF 1:#6A8CFF, size 0:0.45 1:0.2, br 1.8; `sparks` as anti-lag's sparks but from big, count 0-2, colors 0:#E8F0FF 1:#6A8CFF.
  - twostep: `core` as crackle root; `ball` FIREBALL, from small, world, facing, turn, count 1-2, life 0.12-0.18, speed 2-4, spread 12, drag 5, rise 2, size 0:0.25 0.3:0.55 1:0.6, transp 0:0 0.7:0.25 1:1, LE 0.7, br 1.5, z 0.05; `lick` as crackle lick, count 2-3; `flash` STAR from small, size 0:0.6 1:0.3; `sparks` as anti-lag's sparks, count 3-6; `puff` PUFF from mid, world, facing, turn, delay 0.04, count 0-1, life 0.5-0.8, size 0:0.2 1:0.7, transp 0:0.8 1:1, colors 0:#3A3632 1:#5A5550.
  - Every layer not given drag/rise/spread above: drag 0, rise 0, spread 6.

- [ ] **Step 4: Update `CosmeticsConfig.spec`:** delete the relay-burst check (lines 49-56) and the `relayPopsPerSecond`/`maxPopsPerBurst` assertions (lines 180-181); the particle-budget and timeScale checks for Classic's layers stay.

- [ ] **Step 5: Run the specs.** Expected: ExhaustStyles.spec and ExhaustSputter.spec pass; 14 failures total. Analyze: no new errors.

- [ ] **Step 6: Commit** the four files plus `CosmeticsConfig.luau` and `CarConfig.luau` (`crackleRevFloor` added; the moved sound fields removed): "Exhaust styles: Crackle, Anti-Lag, Blue Flame, 2-Step and Classic, with measured pop grains".

---

### Task 3: Flames per style and pop size

**Files:**
- Modify: `src/client/ExhaustFlames.luau` (whole module: builders, `dress`, `pop`; the sound, burst, relay and REV functions move to ExhaustPops in Task 4)

**Interfaces:**
- Consumes: `ExhaustStyles.styles`, `ExhaustSputter.Pop`.
- Produces: `ExhaustFlames.flame(model: Model, styleId: string, pop: ExhaustSputter.Pop, item: CosmeticsConfig.Item?): Attachment?` (fires the pop's flame at every outlet; returns the first mouth, where ExhaustPops hangs the flash light).

- [ ] **Step 1:** Emitters are built lazily under each outlet's `FlameMouth` attachment, one per (style, layer, class at or above the layer's `from`), named `"{style}:{layer}:{class}"`. `Size` = layer size x class.size x item flameSize x studs per metre; `Color` from `colors` (or the item's colours for Classic, as `dress` does today); `FlipbookLayout`/`FlipbookMode` from `flipbook`; LightEmission 1 layers are drawn additive. Sizes are set once per mouth and scale key (an attribute `ScaleKey` on the emitter); never per pop, because Size and Colour reach particles already out.
- [ ] **Step 2:** `flame` emits, per layer whose `from` <= the pop's class: count = round(rng(count) x class.count), speed = rng(speed) x class.speed x (0.75 + 0.25 x level) x trail reach (locked layers, as today). `jetSeconds` and `delaySeconds` work as today; the tip glow fires on mid and big pops.
- [ ] **Step 3:** Classic builds today's six layers with today's values and colours (item flameColor/flameCore) and emits all of them on every pop: unchanged.
- [ ] **Step 4: Check in Edit:** clone a car into Workspace (the WorldPreview pattern), call `flame` for each style and class at TimeScale 0.1 and freeze (BEHAVIOURS "Freeze a particle effect"); screen_capture from the side and from behind at 7.5 m. Expected: big crackle about 0.6-0.9 m, anti-lag fireball about 1-1.4 m, blue jet about 1 m, every flipbook animating (not a whole sheet).
- [ ] **Step 5: Commit** `src/client/ExhaustFlames.luau`: "Exhaust flames per style and pop size".

---

### Task 4: The pop player, relay and style switch

**Files:**
- Create: `src/client/ExhaustPops.luau`
- Modify: `src/client/EngineAudio.luau` (pop pool and queue out; hooks `onLift(model, rev)`, `onSingle(model)`, `onCut(model)` in), `src/client/init.client.luau:41-48`, `src/client/Garage/GaragePanel.luau:1462-1463`, `src/server/CarControls.luau` (relay), `src/server/Remotes.luau:14` (comment)

**Interfaces:**
- Consumes: `ExhaustSputter.generate`, `ExhaustStyles.*`, `ExhaustFlames.flame`.
- Produces: `ExhaustPops.lift(model, rev: number)`, `ExhaustPops.single(model)`, `ExhaustPops.cut(model)`, `ExhaustPops.rev(model, item): number` (garage; returns the burst's length in seconds), `ExhaustPops.styleId(): string`, `ExhaustPops.start(remotes: Folder)`.

- [ ] **Step 1: EngineAudio.** Remove `pops`, `nextPop`, `popQueue`, `pop()` and the crackle Sound pool. On a fast lift (same condition as today) call `EngineAudio.onLift(model, rev)` with `rev = crackleRevFloor + (1 - crackleRevFloor) * clamp((simRpm - crackleMinRpm) / (redlineRpm - crackleMinRpm), 0, 1)`. When the throttle rises through 0.1, call `EngineAudio.onCut(model)`. The upshift and limiter chances (still 0) call `EngineAudio.onSingle(model)`.
- [ ] **Step 2: Server relay** (`CarControls`): replace `popAllowed` with a per-player message budget of `ExhaustStyles.relayPerSecond`; accept `(kind, style, seed, scale)` only if `ExhaustStyles.validRelay` passes and the sender drives a car; relay `(model, kind, style, seed, scale)` to every other player.
- [ ] **Step 3: `ExhaustPops`:**
  - Per car: a burst token; `burst(model, styleId, seed, scale)` bumps it and schedules `ExhaustSputter.generate(...)` with `task.delay(pop.t, ...)`; each fires only if the token is unchanged and `model.Parent` and the chassis exist. `cut` bumps the token.
  - A pop: pick a grain from the style's bank for its class, play it on that car's pool for the clip (3 Sounds per clip id on the chassis, `PlaybackRegionsEnabled`, `PlaybackRegion = NumberRange.new(from, to)` unless the grain is the whole clip), `PlaybackSpeed` from the bank's pitch, `Volume = bank.volume x grain.gain x pop.level`; then `ExhaustFlames.flame(model, styleId, pop, item)`, then the light.
  - `ensureLoaded`: on start, preload every clip in `clipSeconds`; a clip that fails is marked, and a bank whose grains all failed plays Classic's clip.
  - The light: one PointLight (Shadows off), parented to the newest pop's mouth, brightness `light.brightness x class.light x level` fading as `(1 - age / seconds)^2`, disabled after.
  - Style: LocalPlayer attribute `FlameStyle` if it names a style, else `ExhaustStyles.default`. In Studio only (`RunService:IsStudio()`), P (not when typing) cycles through `ExhaustStyles.order` and shows the style's name for 1.5 s in a small label (UITheme display font, paint on asphalt900 at alpha.hud).
  - Driver: `lift` makes a seed (`Random:NextInteger(1, 2^31 - 1)`), plays the burst and sends `(KIND.burst, index, seed, scale)`; `cut` sends `(KIND.cut, 0, 0, 0)` only when a burst is running; `single` plays one mid pop and sends `KIND.single`.
  - Relay in: `OnClientEvent(model, kind, style, seed, scale)` validated again with `validRelay`, model in Workspace; burst/single/cut as above with the sent style.
  - `rev(model, item)`: a local burst of the current style at `scaleFor(style, item.crackleChance, 1)`, returning the last pop's time plus 0.3 s.
- [ ] **Step 4: Wire** `init.client` (`EngineAudio.onLift/onSingle/onCut` to ExhaustPops; `ExhaustPops.start(remotes)`) and GaragePanel REV (`revUntil = os.clock() + ExhaustPops.rev(m, item)`).
- [ ] **Step 5: Play check with the harness** (kamri07, then a quad exhaust): for each style (P), drive to 120 km/h, lift; confirm in the output and by a capture that each pop's sound and flame land on the same frame (log `os.clock()` in both for one burst), that a throttle stab mid-burst stops it, that P mid-burst leaves the running burst in its style, that respawning mid-burst logs no error, that a garage look change mid-burst logs no error, and that the server log shows one relay message per burst. Set a grain id to a bad asset in a scratch config reload and confirm Classic's pop plays instead.
- [ ] **Step 6: Commit** the six files: "Exhaust pops: sputter player, one relay message a burst, style switch (P in Studio)".

---

### Task 5: Tune each style in Play and measure

**Files:**
- Modify: `src/shared/ExhaustStyles.luau` (values only)

- [ ] **Step 1:** For each style, freeze a big, a mid and a small pop at 0.05, 0.1 and 0.2 s of age (TimeScale 0.1, re-applied every Heartbeat until captured) in the chase view at rest and at 100 km/h, and from the side; adjust sizes, counts, colours and the light until each reads at 7.5 m and the styles read clearly apart.
- [ ] **Step 2:** Frame time: median of 300 frames over 5 s with a quad exhaust bursting every 1.5 s, per style, against no bursts. Expected: within 1 ms of no bursts; if not, cut the heaviest layer's count or lifetime and say so.
- [ ] **Step 3: Commit** "Exhaust styles tuned in Play" with the before/after numbers in the message.

---

### Task 6: Docs and the final pass

**Files:**
- Modify: `TUNING.md` (flames section: styles, sequencer fields, classes, grains, light, the P switch; engineAudio rows for the moved crackle fields and `crackleRevFloor`), `BEHAVIOURS.md` (audio envelope by slowed AudioAnalyzer; PlaybackRegion grains; FlipbookIncompatible stale in Edit; black-ground flipbooks drawn additive; assetdelivery needs sign-in for some images), `BRANCH_STATUS.md` (the branch).

- [ ] **Step 1:** Write the docs with the measured numbers from Tasks 3-5.
- [ ] **Step 2:** Full spec run (expected: only the 14 VehicleRig failures) and `bash scripts/analyze.sh` (no new errors in touched files).
- [ ] **Step 3: Commit** the docs.

---

## Execution

Ruling (2026-10-05, under the owner's /goal, no execution method given):
**native**. I implement every task in this session, because Tasks 3 to 5
depend on live Studio iteration (freezing flames, captures, frame timing)
that a fresh subagent per task could not hold, and the tasks share
interfaces tightly. One fresh reviewer on the most capable model checks the
whole branch at the end. Tasks 3 and 4 are written as precise prose steps
rather than full code for the same reason: their values are settled in
Studio in Task 5.
