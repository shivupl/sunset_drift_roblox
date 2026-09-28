--!strict
local CarLook = require(script.Parent.Parent.CarLook)
local CosmeticsConfig = require(script.Parent.Parent.CosmeticsConfig)
local Tests = require(script.Parent)
type T = Tests.T

local function isEmpty(look: CarLook.Look): boolean
	return next(look :: any) == nil
end

return function(t: T)
	t.eq(CarLook.encode({}), "", "an empty look encodes to the empty string")

	-- Round trip: a look with four non-stock slots survives encode/decode,
	-- checked field by field (the tables are not the same reference).
	local look: CarLook.Look = {
		paint = "paint_pearl",
		rims = "rims_gold",
		head = "head_ice",
		exhaust = "exhaust_twin",
	}
	local roundTripped = CarLook.decode(CarLook.encode(look))
	t.eq(roundTripped.paint, look.paint, "round trip keeps paint")
	t.eq(roundTripped.finish, look.finish, "round trip keeps finish (nil)")
	t.eq(roundTripped.rims, look.rims, "round trip keeps rims")
	t.eq(roundTripped.head, look.head, "round trip keeps head")
	t.eq(roundTripped.tail, look.tail, "round trip keeps tail (nil)")
	t.eq(roundTripped.decal, look.decal, "round trip keeps decal (nil)")
	t.eq(roundTripped.exhaust, look.exhaust, "round trip keeps exhaust")

	-- encode skips stock ids: only the non-stock slot is written.
	local mixed: CarLook.Look = { paint = "paint_stock", finish = "finish_gloss" }
	t.eq(CarLook.encode(mixed), "finish=finish_gloss", "encode skips stock ids")

	-- decode drops a pair whose id is not in the pair's own category.
	t.ok(isEmpty(CarLook.decode("paint=finish_gloss")), "decode drops the wrong-category pair")

	-- decode is robust to junk.
	t.ok(isEmpty(CarLook.decode("junk;;=;paint=")), "decode ignores unparseable junk")
	t.ok(isEmpty(CarLook.decode(42)), "decode of a non-string is empty")

	-- clean() drops an unowned paid id, keeps a stock id, keeps plate as-is.
	local function ownsNothing(_: string): boolean
		return false
	end
	local dirty: any = { paint = "paint_pearl", rims = "rims_stock", plate = "SA-1-A-1234" }
	local cleaned = CarLook.clean(dirty, ownsNothing)
	t.eq(cleaned.paint, nil, "clean drops an unowned paid id")
	t.eq(cleaned.rims, "rims_stock", "clean keeps a stock id without asking owns")
	t.eq(cleaned.plate, "SA-1-A-1234", "clean keeps plate")

	t.eq(CarLook.item({}, "paint").id, "paint_stock", "an empty look's paint is the stock item")
	t.eq(CarLook.item({}, "paint").id, CosmeticsConfig.stockId("paint"), "matches CosmeticsConfig.stockId")
end
