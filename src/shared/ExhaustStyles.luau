--!strict
-- Exhaust pop styles (owner, 2026-10-04: "create different exhaust flame
-- variants but really cool ones. what i have now is not bad but is kind of
-- just like a spark, i need way cooler ones and the audio has to be like
-- the sputter. do some research on this exaust bursts/pops and implement a
-- couple varitations to try"). Design and research:
-- docs/superpowers/specs/2026-10-04-exhaust-flame-variants-design.md and
-- 2026-10-04-exhaust-flame-research.md.
--
-- A pop is unburnt fuel lighting in the hot pipe. How it comes decides how
-- it looks and sounds:
--   Crackle    a "pops and bangs" map: on a lift from high revs, a dense
--              string of small cracks that thins out as the revs fall,
--              mostly small, the odd big one; orange licks over a blue root
--   Anti-Lag   rally ALS: a few big bangs, mushrooming orange fireballs,
--              sparks and soot (rich, so sooty)
--   Blue Flame a lean race overrun: sharp, even cracks, long blue-violet
--              jets, clean (a clean burn's core is blue: CH and C2 radicals)
--   2-Step     launch control's skip-fire: bangs on an even beat
--   Classic    the garage round 2 flame and pop, unchanged, to compare
--
-- Each style is a rhythm (ExhaustSputter.Pattern), a sound bank per pop
-- size (small, mid, big: real pops cut from Creator Store recordings, each
-- a Sound.PlaybackRegion), how each size scales the look, a flash light,
-- and the flame layers (ExhaustFlames). Lengths are metres before the car's
-- scale and the exhaust item's flameSize.
local ExhaustSputter = require(script.Parent.ExhaustSputter)

type Class = ExhaustSputter.Class
type Pattern = ExhaustSputter.Pattern

local ExhaustStyles = {}

-- One pop cut out of a recording: seconds into the clip. A grain from 0 to
-- the clip's length plays the whole clip.
export type Grain = { id: string, from: number, to: number, gain: number }
-- The pops a style plays for one size: Volume = volume x gain x the pop's
-- level, PlaybackSpeed drawn from pitch.
export type Bank = { grains: { Grain }, pitch: { number }, volume: number }
-- How a pop of this size scales the layers: their size, particle counts,
-- speed (so length), and the flash light's brightness.
export type ClassLook = { size: number, count: number, speed: number, light: number }
-- The flash on the bumper and the road (one pooled PointLight per client):
-- brightness at a full big pop, its range, and how long it takes to fade.
-- Kept to the bumper and the road just behind: Anti-Lag's first 6 at 12 m
-- washed the whole car and the road orange-white (Play, 2026-10-05).
export type Light = { color: Color3, brightness: number, rangeM: number, seconds: number }

-- A flame layer. As CosmeticsConfig.flames' layers, plus:
--   flipbook  a sprite sheet's grid and mode (each particle plays it once
--             over its life: OneShot)
--   from      the smallest pop size that emits this layer
--   colors    keyframes { time, Color3 }; none = the texture's own colours
--   turn      a camera-facing layer drawn at a random angle, slowly turning
export type Layer = {
	texture: string,
	flipbook: { layout: string, mode: string }?,
	from: Class,
	count: { number },
	lifetime: { number },
	speed: { number },
	spreadDeg: number,
	drag: number,
	riseMps2: number,
	size: { { number } },
	transparency: { { number } },
	squash: { { number } },
	colors: { { any } }?,
	lightEmission: number,
	brightness: number,
	locked: boolean,
	alongMotion: boolean,
	turn: boolean?,
	delaySeconds: number?,
	jetSeconds: number?,
	zOffsetM: number,
}

export type Style = {
	name: string,
	pattern: Pattern,
	-- How the exhaust item's crackleChance (1 factory to 2.5 titanium)
	-- scales the pop count: 1 + (crackleChance - 1) x chanceGain. At 1 a
	-- titanium 14-pop crackle would be 35.
	chanceGain: number,
	-- How much further the car-locked layers reach at speed: their speed
	-- times 1 + trailGain x (km/h / CosmeticsConfig.flames.trailFullKmh,
	-- capped at 1). nil: Classic's flames.trailGain (1.2). The new layers are
	-- already fast, and at 1.2 Blue Flame's jets flew 2-4 m behind the car at
	-- 110 km/h, cut off from the pipe (Play, 2026-10-05).
	trailGain: number?,
	sounds: { small: Bank, mid: Bank, big: Bank },
	classes: { small: ClassLook, mid: ClassLook, big: ClassLook },
	light: Light?,
	-- nil: Classic's layers (CosmeticsConfig.flames.layers, coloured by the
	-- exhaust item's flameColor and flameCore as before).
	layers: { [string]: Layer }?,
}

local hex = Color3.fromHex

-- A colour keyframe: { time, Color3 }.
local function ck(t: number, c: Color3): { any }
	return { t, c }
end

-- The clips, and their lengths as measured here (Sound.TimeLength after
-- ContentProvider:PreloadAsync, 2026-10-04; all loaded in this place).
local POPS = "rbxassetid://129025289910636" -- "pop backfire sound": a real pops-and-bangs run, 28 pops
local DENSE_ID = "rbxassetid://17651974920" -- "exhaust crackles": dense, loud, near clipping
local CLEAN_ID = "rbxassetid://17651322643" -- "exhaust crackle 3": six clean, quiet pops
local CRACK_ID = "rbxassetid://17865169434" -- "Backfire Pop": one small sharp crack
local BIGPOP_ID = "rbxassetid://86084579153761" -- "zx6r backfire pop": one medium-big pop
local BANG_ID = "rbxassetid://1001293842" -- "Anti-Lag": one huge saturated bang
local CLASSIC_ID = "rbxassetid://112720519011313" -- "Car Backfire Exhaust": the garage round 2 pop

ExhaustStyles.clipSeconds = {
	[POPS] = 1.297,
	[DENSE_ID] = 0.594,
	[CLEAN_ID] = 0.549,
	[CRACK_ID] = 0.158,
	[BIGPOP_ID] = 0.232,
	[BANG_ID] = 0.302,
	[CLASSIC_ID] = 0.444,
} :: { [string]: number }

-- Grains cut from a clip at (from, to) seconds. The cuts were found by
-- playing each clip at 0.1 speed into an AudioAnalyzer (a frame is then
-- about 2 ms of the clip): from a pop's rise less 3 ms to where it falls
-- under 12% of its peak plus 20 ms, never into the next pop.
local function cut(id: string, gain: number, spans: { { number } }): { Grain }
	local out: { Grain } = {}
	for _, s in spans do
		table.insert(out, { id = id, from = s[1], to = s[2], gain = gain })
	end
	return out
end

local function whole(id: string, gain: number): Grain
	return { id = id, from = 0, to = ExhaustStyles.clipSeconds[id], gain = gain }
end

local function join(...: { Grain }): { Grain }
	local out: { Grain } = {}
	for _, list in { ... } do
		for _, g in list do
			table.insert(out, g)
		end
	end
	return out
end

-- The pops-and-bangs run by size: peaks at the clip's level (big), 0.43 to
-- 0.88 of it (mid, lifted 1.4x), 0.24 to 0.49 (small, lifted 2.2x).
local POPS_BIG = cut(POPS, 1, {
	{ 0.052, 0.090 }, { 0.158, 0.197 }, { 0.239, 0.271 }, { 0.366, 0.431 }, { 0.440, 0.467 },
	{ 0.466, 0.504 }, { 0.810, 0.836 }, { 0.944, 0.972 }, { 1.015, 1.071 }, { 1.162, 1.200 },
})
local POPS_MID = cut(POPS, 1.4, {
	{ 0.004, 0.049 }, { 0.270, 0.298 }, { 0.297, 0.347 }, { 0.513, 0.559 }, { 0.558, 0.589 },
	{ 0.617, 0.643 }, { 0.642, 0.677 }, { 0.676, 0.704 }, { 1.081, 1.109 }, { 1.211, 1.257 },
})
local POPS_SMALL = cut(POPS, 2.2, {
	{ 0.096, 0.143 }, { 0.588, 0.618 }, { 0.835, 0.865 }, { 0.864, 0.911 }, { 0.971, 1.016 }, { 1.108, 1.151 },
})
-- Six clean pops, peaks 0.22 to 0.32 of full scale: lifted 3x.
local CLEAN = cut(CLEAN_ID, 3, {
	{ 0.015, 0.075 }, { 0.096, 0.165 }, { 0.189, 0.246 }, { 0.280, 0.334 }, { 0.394, 0.453 }, { 0.477, 0.527 },
})
-- The dense crackle's pops, most at clipping: taken down a little.
local DENSE = cut(DENSE_ID, 0.8, {
	{ 0.011, 0.061 }, { 0.062, 0.088 }, { 0.087, 0.116 }, { 0.115, 0.147 }, { 0.156, 0.184 },
	{ 0.183, 0.227 }, { 0.226, 0.252 }, { 0.251, 0.307 }, { 0.319, 0.354 }, { 0.388, 0.416 },
	{ 0.415, 0.439 }, { 0.470, 0.497 }, { 0.496, 0.523 }, { 0.522, 0.551 }, { 0.550, 0.577 },
})
local CRACK = { whole(CRACK_ID, 1.6) }
local BIGPOP = { whole(BIGPOP_ID, 1.1) }
local BANG = { whole(BANG_ID, 0.7) }
local CLASSIC = { whole(CLASSIC_ID, 1) }

-- Textures. Flipbooks from the Creator Store, each checked in Studio to play
-- as a 1024 px sheet (FlipbookIncompatible still reads "must be 1024 by
-- 1024" in Edit; BEHAVIOURS). FIRE sits on black, so it is drawn additive
-- (LightEmission 1: the black adds nothing).
local FIRE = "rbxassetid://9968039364" -- realistic orange flame licks, 4x4
local WHITEFIRE = "rbxassetid://17703378809" -- realistic white fire to tint, 4x4
local FIREBALL = "rbxassetid://9636673935" -- a fireball turning to smoke, 8x8
local STAR = "rbxassetid://12156297119" -- a starburst flash that shrinks, 4x4
local PUFF = "rbxassetid://13346862770" -- a soft smoke puff, 4x4
local HOT = "rbxasset://textures/particles/explosion01_implosion_main.dds" -- the built-in hot blob
local GRID4 = { layout = "Grid4x4", mode = "OneShot" }
local GRID8 = { layout = "Grid8x8", mode = "OneShot" }

-- A layer with the common defaults filled in: no drag or rise, a 6 degree
-- spread, no squash, emitted in one frame.
local function layer(t: { [string]: any }): Layer
	local out = table.clone(t)
	out.spreadDeg = out.spreadDeg or 6
	out.drag = out.drag or 0
	out.riseMps2 = out.riseMps2 or 0
	out.squash = out.squash or { { 0, 0 }, { 1, 0 } }
	out.zOffsetM = out.zOffsetM or 0
	return (out :: any) :: Layer
end

-- The blue root at the mouth: the clean-burning gas, short and stretched
-- along the pipe.
local function root(count: { number }, size: { { number } }): Layer
	return layer({
		texture = HOT, from = "small", locked = true, alongMotion = true,
		count = count, jetSeconds = 0.07, lifetime = { 0.05, 0.08 }, speed = { 1, 2 },
		size = size,
		transparency = { { 0, 0 }, { 0.6, 0.25 }, { 1, 1 } },
		squash = { { 0, -1.2 }, { 1, -0.8 } },
		colors = { ck(0, hex("#E8F0FF")), ck(0.3, hex("#4A7BFF")), ck(1, hex("#4A7BFF")) },
		lightEmission = 0.3, brightness = 1.2, zOffsetM = 0.08,
	})
end

-- Ragged animated flame licks out of the pipe: let out over 0.1 s so the
-- flame stays joined to the mouth while it lasts (particles of every age
-- along it), and full rather than stretched thin (Play, 2026-10-05: at
-- 0.18-0.32 m and squash -1 a big pop was a 0.5 m streak from the side;
-- at these sizes it is a ~1 m plume, about 60-120 px from the chase cam).
local function licks(from: Class, count: { number }, speed: { number }): Layer
	return layer({
		texture = FIRE, flipbook = GRID4, from = from, locked = true, alongMotion = true,
		count = count, jetSeconds = 0.1, lifetime = { 0.07, 0.12 }, speed = speed,
		drag = 3, riseMps2 = 6,
		size = { { 0, 0.32 }, { 0.3, 0.62 }, { 1, 0.3 } },
		transparency = { { 0, 0.1 }, { 0.6, 0.3 }, { 1, 1 } },
		squash = { { 0, -0.5 }, { 1, -0.2 } },
		colors = { ck(0, hex("#FFE6A0")), ck(0.35, hex("#FF8A2A")), ck(1, hex("#C83A0A")) },
		-- 1.7, not 2: from behind, overlapping licks at 2 burnt to near
		-- white at 110 km/h (Play, 2026-10-05).
		lightEmission = 1, brightness = 1.7, zOffsetM = 0.04,
	})
end

-- The starburst at the mouth, facing the camera so the pop reads from
-- straight behind (where a flame along the pipe foreshortens to a dot).
-- Small and coloured: from behind two outlets' flashes overlap, and at
-- 1.3 m and Brightness 2.2 they burnt to a white blob over the whole rear
-- (Play, 2026-10-05, Anti-Lag at 110 km/h).
local function flash(from: Class, size: { { number } }, colors: { { any } }, brightness: number): Layer
	return layer({
		texture = STAR, flipbook = GRID4, from = from, locked = true, alongMotion = false,
		count = { 1, 1 }, lifetime = { 0.07, 0.11 }, speed = { 0, 0 }, spreadDeg = 0,
		size = size,
		transparency = { { 0, 0.2 }, { 1, 1 } },
		colors = colors,
		lightEmission = 1, brightness = brightness, zOffsetM = 0.1,
	})
end

-- Hot flecks thrown back and falling: the sooty styles only (a clean burn
-- has nothing to throw).
local function sparks(from: Class, count: { number }, speed: { number }, colors: { { any } }): Layer
	return layer({
		texture = HOT, from = from, locked = false, alongMotion = true,
		count = count, lifetime = { 0.25, 0.5 }, speed = speed, spreadDeg = 20,
		drag = 1.5, riseMps2 = -4,
		size = { { 0, 0.025 }, { 1, 0 } },
		transparency = { { 0, 0 }, { 1, 0.4 } },
		squash = { { 0, -2.5 }, { 1, -2.5 } },
		colors = colors,
		lightEmission = 1, brightness = 3,
	})
end

local SPARK_COLORS = { ck(0, hex("#FFE2A0")), ck(1, hex("#FF5A14")) }

ExhaustStyles.styles = {
	crackle = {
		name = "Crackle",
		-- A dense cluster at the lift thinning to the odd pop over about
		-- 0.8-2 s (research: "pop pop pop... BANG... pop pop"); gaps from
		-- 30-70 ms out to 120-300 ms, each jittered by half; one gap in five
		-- a quick double.
		pattern = {
			kind = "burble", count = { 7, 14 }, maxPops = 22, minGap = 0.012, maxSeconds = 2.2,
			first = "mid",
			weightsStart = { small = 0.45, mid = 0.4, big = 0.15 },
			weightsEnd = { small = 0.8, mid = 0.17, big = 0.03 },
			fade = 0.45, levelJitter = 0.35,
			gapStart = { 0.03, 0.07 }, gapEnd = { 0.12, 0.3 }, jitter = 0.5,
			doubleChance = 0.2, doubleGap = { 0.015, 0.035 },
		},
		chanceGain = 0.35,
		trailGain = 0.4,
		sounds = {
			small = { grains = join(POPS_SMALL, CLEAN, CRACK), pitch = { 0.95, 1.2 }, volume = 0.3 },
			mid = { grains = POPS_MID, pitch = { 0.9, 1.1 }, volume = 0.38 },
			big = { grains = POPS_BIG, pitch = { 0.85, 1.0 }, volume = 0.45 },
		},
		classes = {
			small = { size = 0.55, count = 0.6, speed = 0.7, light = 0.35 },
			mid = { size = 0.8, count = 0.8, speed = 0.85, light = 0.65 },
			big = { size = 1, count = 1, speed = 1, light = 1 },
		},
		light = { color = hex("#FF8A3A"), brightness = 1.5, rangeM = 5, seconds = 0.08 },
		layers = {
			root = root({ 4, 5 }, { { 0, 0.09 }, { 0.3, 0.13 }, { 1, 0.05 } }),
			lick = licks("small", { 6, 8 }, { 5, 10 }),
			flash = flash("mid", { { 0, 0.55 }, { 1, 0.3 } }, { ck(0, hex("#FFD27A")), ck(1, hex("#FF8A2A")) }, 1.2),
			wisp = layer({
				texture = PUFF, flipbook = GRID4, from = "mid", locked = false, alongMotion = false, turn = true,
				delaySeconds = 0.05, count = { 1, 1 }, lifetime = { 0.5, 0.8 }, speed = { 0.5, 1 }, spreadDeg = 15,
				drag = 1, riseMps2 = 0.4,
				size = { { 0, 0.15 }, { 1, 0.6 } },
				transparency = { { 0, 0.85 }, { 1, 1 } },
				colors = { ck(0, hex("#2A2622")), ck(1, hex("#4A4540")) },
				lightEmission = 0, brightness = 1, zOffsetM = -0.03,
			}),
		},
	},
	antilag = {
		name = "Anti-Lag",
		-- A few big bangs, 120-280 ms apart, every one a fireball.
		pattern = {
			kind = "burble", count = { 2, 4 }, maxPops = 6, minGap = 0.1, maxSeconds = 1.6,
			first = "big",
			weightsStart = { small = 0, mid = 0.1, big = 0.9 },
			weightsEnd = { small = 0, mid = 0.3, big = 0.7 },
			fade = 0.8, levelJitter = 0.2,
			gapStart = { 0.12, 0.2 }, gapEnd = { 0.18, 0.28 }, jitter = 0.25,
		},
		chanceGain = 0.25,
		trailGain = 0.4,
		sounds = {
			small = { grains = POPS_MID, pitch = { 0.8, 0.95 }, volume = 0.4 },
			-- Pitched down for weight: the research's bassy "whump".
			mid = { grains = join(POPS_BIG, BIGPOP), pitch = { 0.75, 0.9 }, volume = 0.5 },
			big = { grains = join(BANG, BIGPOP), pitch = { 0.8, 0.95 }, volume = 0.55 },
		},
		classes = {
			small = { size = 0.7, count = 0.7, speed = 0.8, light = 0.5 },
			mid = { size = 0.85, count = 0.85, speed = 0.9, light = 0.75 },
			big = { size = 1, count = 1, speed = 1, light = 1 },
		},
		light = { color = hex("#FF7A2A"), brightness = 2.5, rangeM = 7, seconds = 0.14 },
		layers = {
			core = root({ 4, 5 }, { { 0, 0.1 }, { 0.3, 0.15 }, { 1, 0.06 } }),
			-- Locked to the car: in the world, its drag shed the car's speed in
			-- a tenth of a second and the fireball fell ~3.5 m behind at
			-- 110 km/h (Play, 2026-10-05). Locked layers reach further back at
			-- speed instead (CosmeticsConfig.flames trailGain).
			ball = layer({
				texture = FIREBALL, flipbook = GRID8, from = "small", locked = true, alongMotion = false, turn = true,
				count = { 2, 3 }, lifetime = { 0.22, 0.32 }, speed = { 2, 5 }, spreadDeg = 15,
				drag = 5, riseMps2 = 3,
				-- The fireball sheet starts as a point, so it is sized for its
				-- middle frames: about 1.2 m across at 0.12 s (Play, 2026-10-05).
				size = { { 0, 0.5 }, { 0.3, 1.05 }, { 1, 1.25 } },
				transparency = { { 0, 0 }, { 0.7, 0.2 }, { 1, 1 } },
				lightEmission = 0.6, brightness = 1.6, zOffsetM = 0.05,
			}),
			tongue = licks("mid", { 5, 7 }, { 6, 12 }),
			flash = flash("small", { { 0, 0.7 }, { 1, 0.35 } }, { ck(0, hex("#FFD27A")), ck(1, hex("#FF8A2A")) }, 1.2),
			sparks = sparks("mid", { 6, 12 }, { 6, 12 }, SPARK_COLORS),
			soot = layer({
				texture = PUFF, flipbook = GRID4, from = "big", locked = false, alongMotion = false, turn = true,
				delaySeconds = 0.08, count = { 1, 2 }, lifetime = { 0.8, 1.2 }, speed = { 0.6, 1.2 }, spreadDeg = 20,
				drag = 1, riseMps2 = 0.6,
				size = { { 0, 0.3 }, { 1, 1.1 } },
				transparency = { { 0, 0.7 }, { 1, 1 } },
				colors = { ck(0, hex("#1E1B18")), ck(1, hex("#3A3632")) },
				lightEmission = 0, brightness = 1, zOffsetM = -0.03,
			}),
		},
	},
	blue = {
		name = "Blue Flame",
		-- Sharp cracks on a near-even 70-110 ms, each a long blue jet. No
		-- "shock diamonds": they need a supersonic jet, which no tailpipe is.
		pattern = {
			kind = "burble", count = { 3, 6 }, maxPops = 9, minGap = 0.02, maxSeconds = 1.2,
			first = "big",
			weightsStart = { small = 0.25, mid = 0.55, big = 0.2 },
			weightsEnd = { small = 0.5, mid = 0.45, big = 0.05 },
			fade = 0.6, levelJitter = 0.25,
			gapStart = { 0.07, 0.09 }, gapEnd = { 0.09, 0.11 }, jitter = 0.15,
			doubleChance = 0.05, doubleGap = { 0.025, 0.04 },
		},
		chanceGain = 0.3,
		trailGain = 0.4,
		sounds = {
			-- Pitched up: crisp and high, a lean bark.
			small = { grains = join(POPS_SMALL, CRACK), pitch = { 1.15, 1.4 }, volume = 0.3 },
			mid = { grains = POPS_MID, pitch = { 1.1, 1.3 }, volume = 0.36 },
			big = { grains = POPS_BIG, pitch = { 1.0, 1.2 }, volume = 0.42 },
		},
		classes = {
			small = { size = 0.6, count = 0.7, speed = 0.75, light = 0.4 },
			mid = { size = 0.85, count = 0.85, speed = 0.9, light = 0.7 },
			big = { size = 1, count = 1, speed = 1, light = 1 },
		},
		light = { color = hex("#6A8CFF"), brightness = 1.8, rangeM = 5, seconds = 0.08 },
		layers = {
			core = layer({
				texture = HOT, from = "small", locked = true, alongMotion = true,
				count = { 4, 5 }, jetSeconds = 0.06, lifetime = { 0.05, 0.09 }, speed = { 1.5, 3 },
				size = { { 0, 0.1 }, { 0.3, 0.15 }, { 1, 0.06 } },
				transparency = { { 0, 0 }, { 0.6, 0.2 }, { 1, 1 } },
				squash = { { 0, -1.6 }, { 1, -1 } },
				colors = { ck(0, hex("#FFFFFF")), ck(0.3, hex("#9FC0FF")), ck(1, hex("#5A86FF")) },
				lightEmission = 0.4, brightness = 1.2, zOffsetM = 0.08,
			}),
			-- Saturated blues at Brightness near 1: brighter, or more light
			-- emission, and the blue clips to white under bloom (BEHAVIOURS).
			jet = layer({
				texture = WHITEFIRE, flipbook = GRID4, from = "small", locked = true, alongMotion = true,
				count = { 4, 6 }, jetSeconds = 0.1, lifetime = { 0.08, 0.14 }, speed = { 6, 11 },
				drag = 4, riseMps2 = 2,
				-- A ~1 m torch from the side (Play, 2026-10-05; at 0.26 m wide it
				-- was a pale 0.6 m streak).
				size = { { 0, 0.2 }, { 0.3, 0.38 }, { 1, 0.14 } },
				transparency = { { 0, 0.05 }, { 0.6, 0.25 }, { 1, 1 } },
				squash = { { 0, -1 }, { 1, -0.6 } },
				colors = { ck(0, hex("#7FA8FF")), ck(0.4, hex("#2E5BFF")), ck(1, hex("#6A2CFF")) },
				lightEmission = 1, brightness = 1.1, zOffsetM = 0.04,
			}),
			fringe = layer({
				texture = WHITEFIRE, flipbook = GRID4, from = "mid", locked = true, alongMotion = true,
				count = { 2, 3 }, jetSeconds = 0.1, lifetime = { 0.12, 0.2 }, speed = { 5, 9 }, spreadDeg = 12,
				drag = 5, riseMps2 = 4,
				size = { { 0, 0.26 }, { 0.3, 0.42 }, { 1, 0.16 } },
				transparency = { { 0, 0.35 }, { 0.5, 0.45 }, { 1, 1 } },
				squash = { { 0, -1.2 }, { 1, -0.7 } },
				colors = { ck(0, hex("#5A2CFF")), ck(1, hex("#B040FF")) },
				lightEmission = 1, brightness = 1.1,
			}),
			flash = flash("mid", { { 0, 0.45 }, { 1, 0.25 } }, { ck(0, hex("#9FBCFF")), ck(1, hex("#4A6CFF")) }, 1.2),
			sparks = sparks("big", { 0, 2 }, { 6, 12 }, { ck(0, hex("#E8F0FF")), ck(1, hex("#6A8CFF")) }),
		},
	},
	twostep = {
		name = "2-Step",
		-- Launch control's machine gun: an even beat, 80-100 ms (8% jitter),
		-- all one size bar the first.
		pattern = {
			kind = "burble", count = { 6, 10 }, maxPops = 14, minGap = 0.06, maxSeconds = 1.6,
			first = "big",
			weightsStart = { small = 0, mid = 0.85, big = 0.15 },
			weightsEnd = { small = 0, mid = 0.85, big = 0.15 },
			fade = 0.85, levelJitter = 0.1,
			gapStart = { 0.08, 0.1 }, gapEnd = { 0.085, 0.1 }, jitter = 0.08,
		},
		chanceGain = 0.3,
		trailGain = 0.4,
		sounds = {
			small = { grains = DENSE, pitch = { 0.95, 1.05 }, volume = 0.3 },
			mid = { grains = DENSE, pitch = { 0.9, 1.0 }, volume = 0.36 },
			big = { grains = join(DENSE, BIGPOP), pitch = { 0.85, 0.95 }, volume = 0.42 },
		},
		classes = {
			small = { size = 0.7, count = 0.7, speed = 0.8, light = 0.5 },
			mid = { size = 0.9, count = 0.9, speed = 0.95, light = 0.8 },
			big = { size = 1, count = 1, speed = 1, light = 1 },
		},
		light = { color = hex("#FF8A3A"), brightness = 2, rangeM = 6, seconds = 0.09 },
		layers = {
			core = root({ 4, 5 }, { { 0, 0.09 }, { 0.3, 0.13 }, { 1, 0.05 } }),
			-- Locked to the car, as Anti-Lag's.
			ball = layer({
				texture = FIREBALL, flipbook = GRID8, from = "small", locked = true, alongMotion = false, turn = true,
				count = { 1, 2 }, lifetime = { 0.12, 0.18 }, speed = { 2, 4 }, spreadDeg = 12,
				drag = 5, riseMps2 = 2,
				size = { { 0, 0.25 }, { 0.3, 0.55 }, { 1, 0.6 } },
				transparency = { { 0, 0 }, { 0.7, 0.25 }, { 1, 1 } },
				lightEmission = 0.7, brightness = 1.5, zOffsetM = 0.05,
			}),
			lick = licks("small", { 4, 6 }, { 5, 10 }),
			flash = flash("small", { { 0, 0.55 }, { 1, 0.3 } }, { ck(0, hex("#FFD27A")), ck(1, hex("#FF8A2A")) }, 1.2),
			sparks = sparks("mid", { 3, 6 }, { 6, 12 }, SPARK_COLORS),
			puff = layer({
				texture = PUFF, flipbook = GRID4, from = "mid", locked = false, alongMotion = false, turn = true,
				delaySeconds = 0.04, count = { 0, 1 }, lifetime = { 0.5, 0.8 }, speed = { 0.5, 1 }, spreadDeg = 15,
				drag = 1, riseMps2 = 0.4,
				size = { { 0, 0.2 }, { 1, 0.7 } },
				transparency = { { 0, 0.8 }, { 1, 1 } },
				colors = { ck(0, hex("#3A3632")), ck(1, hex("#5A5550")) },
				lightEmission = 0, brightness = 1, zOffsetM = -0.03,
			}),
		},
	},
	classic = {
		name = "Classic",
		-- Garage round 2 as it was: 1-3 pops at random in half a second, one
		-- size, the "Car Backfire Exhaust" pop at 0.35 x (0.55 to 1) volume
		-- and 0.85-1.2 pitch (the old engineAudio.crackle* settings).
		pattern = {
			kind = "uniform", count = { 1, 3 }, maxPops = 8, minGap = 0.04, maxSeconds = 0.6, spanSeconds = 0.5,
			weightsStart = { small = 0, mid = 1, big = 0 },
			weightsEnd = { small = 0, mid = 1, big = 0 },
			fade = 1, levelJitter = 0.45,
		},
		-- The full crackleChance, as before (titanium: up to 8 pops).
		chanceGain = 1,
		sounds = {
			small = { grains = CLASSIC, pitch = { 0.85, 1.2 }, volume = 0.35 },
			mid = { grains = CLASSIC, pitch = { 0.85, 1.2 }, volume = 0.35 },
			big = { grains = CLASSIC, pitch = { 0.85, 1.2 }, volume = 0.35 },
		},
		classes = {
			small = { size = 1, count = 1, speed = 1, light = 0 },
			mid = { size = 1, count = 1, speed = 1, light = 0 },
			big = { size = 1, count = 1, speed = 1, light = 0 },
		},
	},
} :: { [string]: Style }

-- The styles in the order the Studio switch (P) cycles them; the index is
-- what the relay sends.
ExhaustStyles.order = { "crackle", "antilag", "blue", "twostep", "classic" }
-- The style every car uses until the owner picks (the Studio switch only
-- changes it on that client).
ExhaustStyles.default = "crackle"

-- Relay (client ExhaustPops, server CarControls). A driver sends one
-- message a burst, (kind, style index, seed, scale); every client rebuilds
-- the burst from the seed. A cut stops what is left of the car's burst.
ExhaustStyles.KIND = { burst = 1, single = 2, cut = 3 }
-- Messages a driver may send a second: a lift-off burst, its cut and a
-- single pop at most in a second, so 8 never clips play and drops a flood.
ExhaustStyles.relayPerSecond = 8
-- The largest scale a burst may carry (the titanium's at full revs is
-- under 1.6 for every style but Classic's 2.5).
ExhaustStyles.maxScale = 4

-- A style's place in the cycle (the relay's style number), or nil.
function ExhaustStyles.index(id: string): number?
	return table.find(ExhaustStyles.order, id)
end

local function wholeIn(x: any, lo: number, hi: number): boolean
	return type(x) == "number" and x == x and x >= lo and x <= hi and math.floor(x) == x
end

-- Whether a relay message is well formed: a burst or single names a style,
-- a whole positive seed and a scale in 0..maxScale; a cut is (cut, 0, 0, 0).
-- The garage round 2 message (one pop count) fails, so an old client's pops
-- are dropped, not misread.
function ExhaustStyles.validRelay(kind: any, style: any, seed: any, scale: any): boolean
	local K = ExhaustStyles.KIND
	if kind == K.cut then
		return style == 0 and seed == 0 and scale == 0
	end
	if kind ~= K.burst and kind ~= K.single then
		return false
	end
	if not wholeIn(style, 1, #ExhaustStyles.order) or not wholeIn(seed, 1, 2 ^ 31 - 1) then
		return false
	end
	return type(scale) == "number" and scale == scale and scale >= 0 and scale <= ExhaustStyles.maxScale
end

local RANK = { small = 1, mid = 2, big = 3 }

-- The layers a pop of this size emits: every layer whose from is at or
-- below it, in name order (ZOffset, not this order, decides what draws on
-- top). Classic has none of its own; ExhaustFlames draws its six.
function ExhaustStyles.layersFor(style: Style, class: Class): { string }
	local out: { string } = {}
	local layers: { [string]: Layer } = style.layers or {}
	for name, L in layers do
		if RANK[L.from] <= RANK[class] then
			table.insert(out, name)
		end
	end
	table.sort(out)
	return out
end

-- The rev factor of a lift: floor at minRpm (the crackle rpm) rising to 1
-- at the redline, since a lift from higher revs dumps more fuel for longer.
function ExhaustStyles.revFactor(rpm: number, minRpm: number, redlineRpm: number, floor: number): number
	local u = math.clamp((rpm - minRpm) / math.max(redlineRpm - minRpm, 1), 0, 1)
	return floor + (1 - floor) * u
end

-- How much a burst is scaled: the exhaust's crackleChance through the
-- style's chanceGain, times the rev factor (EngineAudio: fewer pops lifting
-- from lower revs).
function ExhaustStyles.scaleFor(style: Style, crackleChance: number, rev: number): number
	return math.clamp((1 + (crackleChance - 1) * style.chanceGain) * rev, 0, ExhaustStyles.maxScale)
end

return ExhaustStyles
