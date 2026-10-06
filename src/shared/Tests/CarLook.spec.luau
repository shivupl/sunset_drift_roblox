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

	-- The tint slot (garage round 2 §4): round trips, sits last in the
	-- string, and a string written before tint existed decodes the same.
	local tinted: CarLook.Look = { paint = "paint_teal", exhaust = "exhaust_quad", tint = "tint_limo" }
	local tintString = CarLook.encode(tinted)
	t.eq(tintString, "paint=paint_teal;exhaust=exhaust_quad;tint=tint_limo", "tint is written last")
	local tintBack = CarLook.decode(tintString)
	t.eq(tintBack.tint, "tint_limo", "round trip keeps tint")
	t.eq(tintBack.paint, "paint_teal", "round trip with tint keeps paint")
	t.eq(tintBack.exhaust, "exhaust_quad", "round trip with tint keeps exhaust")
	local before = CarLook.decode("paint=paint_pearl;rims=rims_gold;decal=decal_hajwala")
	t.eq(before.paint, "paint_pearl", "an old string still decodes its paint")
	t.eq(before.decal, "decal_hajwala", "an old string still decodes its decal")
	t.eq(before.tint, nil, "an old string has no tint")
	t.eq(CarLook.encode(before), "paint=paint_pearl;rims=rims_gold;decal=decal_hajwala", "an old look re-encodes to the same string")
	t.eq(CarLook.encode({ tint = "tint_stock" }), "", "the stock tint is not written")
	t.ok(isEmpty(CarLook.decode("tint=paint_red")), "decode drops a paint in the tint slot")
	t.eq(CarLook.item({}, "tint").id, "tint_stock", "an empty look's tint is the stock item")

	-- Tyre and flame (garage-tyres-flames): written after tint, an older
	-- string decodes and re-encodes the same, the stock ones are not written.
	local fitted: CarLook.Look = { tint = "tint_dark", tyre = "tyre_hajwala", flame = "flame_blue" }
	t.eq(CarLook.encode(fitted), "tint=tint_dark;tyre=tyre_hajwala;flame=flame_blue", "tyre and flame are written after tint")
	local fittedBack = CarLook.decode(CarLook.encode(fitted))
	t.eq(fittedBack.tyre, "tyre_hajwala", "round trip keeps the tyre")
	t.eq(fittedBack.flame, "flame_blue", "round trip keeps the flame")
	t.eq(CarLook.encode({ tyre = "tyre_classic", flame = "flame_classic" }), "", "the stock tyre and flame are not written")
	t.eq(CarLook.encode(CarLook.decode(tintString)), tintString, "a string written before tyres re-encodes the same")
	t.ok(isEmpty(CarLook.decode("tyre=flame_blue")), "decode drops a flame in the tyre slot")
	t.eq(CarLook.item({}, "tyre").id, "tyre_classic", "an empty look's tyre is Classic")
	t.eq(CarLook.item({}, "flame").id, "flame_classic", "an empty look's flame is Classic")

	t.eq(CarLook.item({}, "paint").id, "paint_stock", "an empty look's paint is the stock item")
	t.eq(CarLook.item({}, "paint").id, CosmeticsConfig.stockId("paint"), "matches CosmeticsConfig.stockId")
end
