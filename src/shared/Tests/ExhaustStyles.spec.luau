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
	-- Which layers a pop emits: every layer whose from is at or below its
	-- size, in name order.
	local S = ExhaustStyles.styles
	t.eq(table.concat(ExhaustStyles.layersFor(S.antilag, "small"), ","), "ball,core,flash", "a small anti-lag pop: fireball, core and flash only")
	t.eq(table.concat(ExhaustStyles.layersFor(S.antilag, "big"), ","), "ball,core,flash,soot,sparks,tongue", "a big anti-lag pop: every layer")
	t.eq(table.concat(ExhaustStyles.layersFor(S.crackle, "small"), ","), "lick,root", "a small crackle: licks over the root")
	t.eq(table.concat(ExhaustStyles.layersFor(S.crackle, "mid"), ","), "flash,lick,root,wisp", "a mid crackle adds the flash and a wisp")
	t.eq(#ExhaustStyles.layersFor(S.classic, "mid"), 0, "Classic has no layers of its own (CosmeticsConfig's)")
end
