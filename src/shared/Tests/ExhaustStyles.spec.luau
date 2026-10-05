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
	t.eq(#ExhaustStyles.order, 4, "four styles in the cycle")
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
	t.ok(ExhaustStyles.validRelay(K.single, #ExhaustStyles.order, 1, 1), "a single pop in the last style is valid")
	t.ok(ExhaustStyles.validRelay(K.cut, 0, 0, 0), "a cut is valid")
	t.ok(not ExhaustStyles.validRelay(1, nil, nil, nil), "the old one-number message is rejected")
	t.ok(not ExhaustStyles.validRelay(99, 1, 1, 1), "an unknown kind is rejected (4 is the flutter now)")
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
	-- Which layers a pop emits: every layer whose from is at or below its
	-- size, in name order.
	local S = ExhaustStyles.styles
	t.eq(table.concat(ExhaustStyles.layersFor(S.twostep, "small"), ","), "ball,core,flash,lick", "a small 2-Step pop: no sparks or smoke")
	t.eq(table.concat(ExhaustStyles.layersFor(S.twostep, "big"), ","), "ball,core,flash,lick,puff,sparks", "a big 2-Step pop: every layer")
	t.eq(table.concat(ExhaustStyles.layersFor(S.crackle, "small"), ","), "lick,root", "a small crackle: licks over the root")
	t.eq(table.concat(ExhaustStyles.layersFor(S.crackle, "mid"), ","), "flash,lick,root,wisp", "a mid crackle adds the flash and a wisp")
	t.eq(#ExhaustStyles.layersFor(S.classic, "mid"), 0, "Classic has no layers of its own (CosmeticsConfig's)")
	-- Fewer pops lifting from lower revs: the floor at crackleMinRpm, all of
	-- them at the redline.
	t.near(ExhaustStyles.revFactor(4000, 4000, 7000, 0.6), 0.6, 1e-9, "at the crackle rpm: the floor")
	t.near(ExhaustStyles.revFactor(7000, 4000, 7000, 0.6), 1, 1e-9, "at the redline: all of them")
	t.near(ExhaustStyles.revFactor(5500, 4000, 7000, 0.6), 0.8, 1e-9, "halfway: halfway")
	t.near(ExhaustStyles.revFactor(2000, 4000, 7000, 0.6), 0.6, 1e-9, "below: the floor")
	t.near(ExhaustStyles.revFactor(9000, 4000, 7000, 0.6), 1, 1e-9, "past the redline: 1")
	-- Every exhaust item's burst fits the relay at full revs, in every style.
	for _, item in CosmeticsConfig.inCategory("exhaust") do
		for _, id in ExhaustStyles.order do
			local scale = ExhaustStyles.scaleFor(ExhaustStyles.styles[id], item.crackleChance or 1, 1)
			t.ok(scale > 0 and scale < ExhaustStyles.maxScale, `{item.id} in {id}: scale {scale} under maxScale`)
		end
	end
	-- Final review fixes (2026-10-05) -------------------------------------
	-- Every Creator Store texture a layer uses has a built-in fallback, and a
	-- texture that failed to load falls back to it with no flipbook.
	for _, id in ExhaustStyles.order do
		for name, L in (ExhaustStyles.styles[id].layers or {}) :: { [string]: any } do
			if string.find(L.texture, "^rbxassetid://") then
				local fb = ExhaustStyles.textureFallback[L.texture]
				t.ok(fb ~= nil and string.find(fb, "^rbxasset://") ~= nil, `{id}.{name}: {L.texture} has a built-in fallback`)
			end
		end
	end
	local lick = ((ExhaustStyles.styles.crackle.layers :: any) :: { [string]: any }).lick
	local tex, book = ExhaustStyles.textureFor(lick, {})
	t.ok(tex == lick.texture and book == lick.flipbook, "a loaded texture is used as it is")
	tex, book = ExhaustStyles.textureFor(lick, { [lick.texture] = true })
	t.ok(tex == ExhaustStyles.textureFallback[lick.texture] and book == nil, "a failed texture falls back, without its flipbook")

	-- The one flash light only answers pops near the camera.
	t.ok(ExhaustStyles.lightInRange(10), "a pop 10 m away lights up")
	t.ok(not ExhaustStyles.lightInRange(ExhaustStyles.lightMaxDistanceM + 1), "a pop past lightMaxDistanceM does not take the light")

	-- Classic is the garage round 2 burst: the revs don't change its count.
	local classic = ExhaustStyles.styles.classic
	t.near(ExhaustStyles.scaleFor(classic, 2.5, 0.6), ExhaustStyles.scaleFor(classic, 2.5, 1), 1e-9, "Classic's count ignores the revs")

	-- Every shipped style's bursts end inside its maxSeconds, at any scale.
	for _, id in ExhaustStyles.order do
		local p = ExhaustStyles.styles[id].pattern
		local late = 0
		for seed = 1, 50 do
			for _, scale in { 0.6, 1, ExhaustStyles.maxScale } do
				local pops = ExhaustSputter.generate(p, seed, scale)
				late = math.max(late, pops[#pops].t)
			end
		end
		t.ok(late <= p.maxSeconds, `{id}: the latest pop ({late} s) is inside maxSeconds`)
	end

	-- The shipped 2-Step keeps an even beat: every gap of a burst within 17%
	-- of the others.
	local worst = 0
	for seed = 1, 100 do
		local pops = ExhaustSputter.generate(ExhaustStyles.styles.twostep.pattern, seed, 1)
		local g0, g1, sum = math.huge, 0, 0
		for i = 2, #pops do
			local g = pops[i].t - pops[i - 1].t
			g0, g1, sum = math.min(g0, g), math.max(g1, g), sum + g
		end
		if #pops > 2 then
			worst = math.max(worst, (g1 - g0) / (sum / (#pops - 1)))
		end
	end
	t.ok(worst <= 0.17, `2-Step's beat stays even (worst spread {worst})`)
	-- The drift flutter: every style has one, dense at the start, ending in its window
	for _, id in ExhaustStyles.order do
		local style = ExhaustStyles.styles[id]
		local p = style.flutter
		t.ok(p ~= nil, `{id} has a flutter`)
		if p then
			local worstFirstGap = 0
			for seed = 1, 40 do
				local pops = ExhaustSputter.generate(p, seed, 1)
				t.ok(pops[#pops].t <= p.maxSeconds + 1e-9, `{id} flutter ends inside maxSeconds (seed {seed})`)
				if #pops >= 3 then
					worstFirstGap = math.max(worstFirstGap, (pops[3].t - pops[1].t) / 2)
				end
				t.ok(#pops >= 3, `{id} flutter has at least three pops (seed {seed})`)
			end
			t.ok(worstFirstGap <= 0.09, `{id} flutter's first pops come 90 ms apart or closer (worst {worstFirstGap})`)
		end
	end
	t.eq(ExhaustStyles.KIND.flutter, 4, "the flutter is relay kind 4")
	t.ok(ExhaustStyles.validRelay(4, 1, 123, 1), "a flutter relays like a burst")
	t.ok(not ExhaustStyles.validRelay(4, 0, 123, 1), "a flutter names a style")
	t.ok(not ExhaustStyles.validRelay(5, 1, 123, 1), "kind 5 does not exist")
	-- Feathering four times a second sends a flutter and a cut each time
	t.ok(ExhaustStyles.relayPerSecond >= 4 * 2 + 2, "the budget covers four feathers a second with room")
end
