--!strict
-- A player's chosen cosmetics for one car, and how it travels: a compact
-- string on the `Look` attribute (CarLook.ATTRIBUTE), same idea as a car's
-- `Plate` attribute carries its plate. Only non-stock choices are written,
-- so an empty look (everything factory) is the empty string.
--
-- The plate itself is not part of the encoded string: it already lives on
-- the car's own `Plate` attribute (PlateConfig/PlateStyles), so `Look` only
-- ever carries the other slots. `plate` is kept in the in-memory `Look`
-- table purely so callers can pass one value around; encode() ignores it.
local CosmeticsConfig = require(script.Parent.CosmeticsConfig)

type Category = CosmeticsConfig.Category

export type Look = {
	paint: string?,
	finish: string?,
	rims: string?,
	head: string?,
	tail: string?,
	decal: string?,
	exhaust: string?,
	tint: string?, -- garage round 2 §4; absent from every string written before it
	plate: string?,
}

local CarLook = {}

CarLook.ATTRIBUTE = "Look"

-- Same categories, same order, as CosmeticsConfig.CATEGORIES; `plate` is not
-- a slot here (it never goes through encode/decode).
CarLook.SLOTS = CosmeticsConfig.CATEGORIES :: { Category }

-- "slot=id" pairs joined by ";", in SLOTS order. Nil and stock ids are
-- skipped (stock is the default, so there is nothing to say); `plate` is
-- never written.
function CarLook.encode(look: Look): string
	local parts: { string } = {}
	for _, slot in CarLook.SLOTS do
		local id = (look :: any)[slot]
		if typeof(id) == "string" and not CosmeticsConfig.isStock(id) then
			table.insert(parts, `{slot}={id}`)
		end
	end
	return table.concat(parts, ";")
end

-- The inverse of encode(). Anything that is not a plain string, or that does
-- not parse into known "slot=id" pairs, yields an empty look ({}). A pair is
-- kept only when its slot is one of SLOTS and CosmeticsConfig.find(id)
-- exists with that same category; junk pairs and wrong-category pairs are
-- dropped silently.
function CarLook.decode(s: any): Look
	local look: Look = {}
	if typeof(s) ~= "string" then
		return look
	end
	for pair in string.gmatch(s, "[^;]+") do
		local slot, id = string.match(pair, "^([^=]+)=([^=]+)$")
		if slot and id then
			local item = CosmeticsConfig.find(id)
			if item and (item.category :: string) == slot and table.find(CarLook.SLOTS, slot :: Category) then
				(look :: any)[slot] = id
			end
		end
	end
	return look
end

-- The chosen item for a slot, or the stock one if nothing is chosen or the
-- chosen id no longer resolves.
function CarLook.item(look: Look, slot: Category): CosmeticsConfig.Item
	local id = (look :: any)[slot]
	local chosen = if typeof(id) == "string" then CosmeticsConfig.find(id) else nil
	if chosen then
		return chosen
	end
	local stock = CosmeticsConfig.find(CosmeticsConfig.stockId(slot))
	assert(stock, `no stock item for slot {slot}`)
	return stock
end

-- A look with anything untrustworthy removed: unknown ids, ids in the wrong
-- category for their slot, and non-stock ids the player does not own
-- (`owns(id)` is asked only for non-stock ids). `plate` is kept as-is when
-- it is a string; it is not one of SLOTS and is not checked against owns.
function CarLook.clean(look: any, owns: (id: string) -> boolean): Look
	local out: Look = {}
	if typeof(look) ~= "table" then
		return out
	end
	for _, slot in CarLook.SLOTS do
		local id = look[slot]
		if typeof(id) == "string" then
			local item = CosmeticsConfig.find(id)
			if item and (item.category :: string) == slot and (CosmeticsConfig.isStock(id) or owns(id)) then
				(out :: any)[slot] = id
			end
		end
	end
	if typeof(look.plate) == "string" then
		out.plate = look.plate
	end
	return out
end

return CarLook
