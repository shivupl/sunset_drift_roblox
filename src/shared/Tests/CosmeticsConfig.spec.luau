--!strict
local CosmeticsConfig = require(script.Parent.Parent.CosmeticsConfig)
local ConfigLoader = require(script.Parent.Parent.ConfigLoader)
local Tests = require(script.Parent)
type T = Tests.T

return function(t: T)
	local seen: { [string]: boolean } = {}
	local categorySet: { [string]: boolean } = {}
	for _, c in CosmeticsConfig.CATEGORIES do
		categorySet[c] = true
	end

	local zeroPriceCount: { [string]: number } = {}
	for _, item in CosmeticsConfig.items do
		t.ok(not seen[item.id], `id {item.id} is unique`)
		seen[item.id] = true

		t.ok(categorySet[item.category], `{item.id}'s category {item.category} is in CATEGORIES`)

		if item.price == 0 then
			zeroPriceCount[item.category] = (zeroPriceCount[item.category] or 0) + 1
			t.eq(CosmeticsConfig.stockId(item.category), item.id, `{item.id} is the stock id of {item.category}`)
		else
			t.ok(item.price > 0, `{item.id} (non-stock) has a positive price`)
		end

		if item.category == "paint" and item.id ~= "paint_stock" then
			t.ok(item.color ~= nil, `{item.id} has a color`)
		end

		if item.category == "finish" and item.id ~= "finish_stock" then
			t.ok(item.material ~= nil, `{item.id} has a material`)
		end

		if item.category == "rims" and item.id ~= "rims_stock" then
			t.ok(item.material ~= nil, `{item.id} has a material`)
		end

		if item.category == "exhaust" then
			t.ok(item.tips ~= nil, `{item.id} has tips`)
			t.ok(item.engineVolume ~= nil, `{item.id} has engineVolume`)
			t.ok(item.crackleChance ~= nil, `{item.id} has crackleChance`)
			-- The flame profile (garage round 2 §2).
			t.ok(item.flameSize ~= nil and (item.flameSize :: number) > 0, `{item.id} has a positive flameSize`)
			t.ok(item.flameCore ~= nil, `{item.id} has a flameCore`)
			t.ok(item.flameColor ~= nil, `{item.id} has a flameColor`)
			-- The most pops a lift-off can ask for fit in one relayed burst,
			-- for every car's engine audio.
			local most = 0
			for id in ConfigLoader.catalog().cars do
				local pops = ConfigLoader.forCar(id).effects.engineAudio.crackleBurstPops[2]
				most = math.max(most, math.ceil(pops * (item.crackleChance or 1)))
			end
			t.ok(most <= CosmeticsConfig.flames.maxPopsPerBurst, `{item.id}'s biggest burst ({most}) fits maxPopsPerBurst`)
		end
	end

	-- Window tint (garage round 2 §4): every film has a colour and both
	-- transparencies, the windscreen's always lighter than the sides' (a
	-- legal-looking windscreen), none opaque, and darker up the ladder.
	local films = {}
	for _, item in CosmeticsConfig.inCategory("tint") do
		if item.price > 0 then
			table.insert(films, item)
			local side, screen = item.glassTransparency, item.screenTransparency
			t.ok(item.glassColor ~= nil, `{item.id} has a glassColor`)
			t.ok(side ~= nil and side > 0 and side < 1, `{item.id} glassTransparency in (0, 1)`)
			t.ok(screen ~= nil and screen >= 0.5 and screen < 1, `{item.id} screenTransparency at least 0.5`)
			t.ok(side ~= nil and screen ~= nil and screen > side, `{item.id} windscreen lighter than the sides`)
		else
			t.eq(item.glassColor, nil, "the factory tint has no film")
		end
	end
	t.eq(#films, 3, "three tint films (Light, Dark, Limo)")
	for i = 2, #films do
		t.ok((films[i].glassTransparency :: number) < (films[i - 1].glassTransparency :: number), `{films[i].id} is darker than {films[i - 1].id}`)
	end

	-- Round 2's new items exist in their categories (ids are permanent).
	for id, category in {
		paint_clay = "paint", paint_teal = "paint", paint_gulf = "paint", paint_olive = "paint",
		rims_red = "rims", rims_champagne = "rims",
		decal_natl = "decal", decal_white = "decal",
		tint_stock = "tint", tint_light = "tint", tint_dark = "tint", tint_limo = "tint",
	} :: { [string]: string } do
		local item = CosmeticsConfig.find(id)
		t.ok(item ~= nil and (item.category :: string) == category, `{id} is a {category} item`)
	end
	-- A decal draws a strip with readable text (or none at all).
	for _, item in CosmeticsConfig.inCategory("decal") do
		if item.price > 0 then
			t.ok(item.stripColor ~= nil, `{item.id} has a stripColor`)
			t.ok(item.text ~= nil, `{item.id} has text ("" for none)`)
			if item.text ~= "" then
				t.ok(item.textColor ~= nil, `{item.id} has a textColor`)
			end
		end
	end
	-- tint is the last slot, so every look string written before it is
	-- unchanged.
	t.eq(CosmeticsConfig.CATEGORIES[#CosmeticsConfig.CATEGORIES], "tint", "tint is the last category")

	-- Flames get bigger up the exhaust ladder: factory smallest, titanium
	-- largest (the spec's "factory small ... sport tips larger").
	local size = function(id: string): number
		local item = CosmeticsConfig.find(id)
		return if item then item.flameSize or 0 else 0
	end
	t.ok(size("exhaust_stock") < size("exhaust_single"), "factory flame is smaller than a sport tip's")
	t.ok(size("exhaust_twin") <= size("exhaust_quad") and size("exhaust_quad") <= size("exhaust_titanium"), "titanium flame is the largest")

	-- Every flame layer: whole, ordered particle counts; lifetimes and
	-- keyframes that run 0 to 1.
	local flames = CosmeticsConfig.flames
	local total = 0
	for name, L in flames.layers :: { [string]: any } do
		t.ok(L.count[1] >= 0 and L.count[1] <= L.count[2] and math.floor(L.count[2]) == L.count[2], `flame layer {name}: count is a whole min..max`)
		t.ok(L.lifetime[1] > 0 and L.lifetime[1] <= L.lifetime[2], `flame layer {name}: lifetime range`)
		for _, seq in { L.size, L.transparency, L.squash } do
			t.eq(seq[1][1], 0, `flame layer {name}: a sequence starts at 0`)
			t.eq(seq[#seq][1], 1, `flame layer {name}: a sequence ends at 1`)
		end
		total += L.count[2]
	end
	-- Emit bursts only, and few: at most 30 particles per pop at one outlet
	-- (a quad at the titanium's 8-pop burst is then under 1,000 over half a
	-- second).
	t.ok(total <= 30, `at most 30 particles per pop per outlet (is {total})`)
	t.ok(flames.maxPopsPerBurst >= 1, "flame relay burst limit is set")
	t.ok(flames.relayPopsPerSecond >= flames.maxPopsPerBurst, "a second's relay budget holds the biggest burst")
	t.eq(flames.timeScale, 1, "flame timeScale is 1 (only a Studio harness changes it)")

	for _, c in CosmeticsConfig.CATEGORIES do
		t.eq(zeroPriceCount[c], 1, `{c} has exactly one price-0 item`)
	end

	t.eq(CosmeticsConfig.find("nope"), nil, "find refuses an unknown id")
end
