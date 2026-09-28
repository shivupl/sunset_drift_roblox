--!strict
local CosmeticsConfig = require(script.Parent.Parent.CosmeticsConfig)
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
			-- The most pops a lift-off can ask for fit in one relayed burst.
			local most = math.ceil(3 * (item.crackleChance or 1))
			t.ok(most <= CosmeticsConfig.flames.maxPopsPerBurst, `{item.id}'s biggest burst ({most}) fits maxPopsPerBurst`)
		end
	end

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
	t.ok(flames.relayPerSecond >= 1 and flames.maxPopsPerBurst >= 1, "flame relay limits are set")

	for _, c in CosmeticsConfig.CATEGORIES do
		t.eq(zeroPriceCount[c], 1, `{c} has exactly one price-0 item`)
	end

	t.eq(CosmeticsConfig.find("nope"), nil, "find refuses an unknown id")
end
