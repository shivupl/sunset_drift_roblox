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
		end
	end

	for _, c in CosmeticsConfig.CATEGORIES do
		t.eq(zeroPriceCount[c], 1, `{c} has exactly one price-0 item`)
	end

	t.eq(CosmeticsConfig.find("nope"), nil, "find refuses an unknown id")
end
