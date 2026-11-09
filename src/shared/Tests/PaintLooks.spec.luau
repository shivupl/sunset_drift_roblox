--!strict
-- PaintLooks: the clear coat and sun-hour variants switch on, in Studio, with
-- B. The main look comes first and an unknown id falls back to it; "As
-- before" must be exactly the look the game had (no coat, the picked sun);
-- the coat reaches only the cars it is being tried on and never a matte
-- finish; and a finish's own reflectance is never lowered by it.
local PaintLooks = require(script.Parent.Parent.PaintLooks)
local CosmeticsConfig = require(script.Parent.Parent.CosmeticsConfig)
local SkyConfig = require(script.Parent.Parent.SkyConfig)
local ConfigLoader = require(script.Parent.Parent.ConfigLoader)
local Tests = require(script.Parent)
type T = Tests.T

return function(t: T)
	t.eq(PaintLooks.order[1], "main", "the main look is first")
	local listed = {}
	for _, id in PaintLooks.order do
		listed[id] = true
		t.ok(PaintLooks.looks[id] ~= nil, `{id} in order is a look`)
	end
	for id, look in PaintLooks.looks do
		t.ok(listed[id] == true, `{id} is in the cycle order`)
		t.ok(look.clearcoat >= 0 and look.clearcoat <= 0.5, `{id}: clear coat {look.clearcoat} in 0..0.5`)
	end
	t.eq(PaintLooks.resolve(nil), "main", "no choice: main")
	t.eq(PaintLooks.resolve("nope"), "main", "unknown choice: main")
	t.eq(PaintLooks.resolve("old"), "old", "a known choice stays")

	local cars = ConfigLoader.catalog().cars
	for id in PaintLooks.cars do
		t.ok(cars[id] ~= nil, `{id} is a catalog car`)
	end

	local factory = CosmeticsConfig.find("finish_stock") :: CosmeticsConfig.Item
	local matte = CosmeticsConfig.find("finish_matte") :: CosmeticsConfig.Item
	local chrome = CosmeticsConfig.find("finish_chrome") :: CosmeticsConfig.Item
	t.eq(matte.clearcoat, false, "matte is the one finish without a clear coat")

	-- "As before": nothing changes.
	t.eq(PaintLooks.reflectance("old", "kamri07", factory, 0), 0, "old: factory paint stays at its own reflectance")
	local chromeOwn = chrome.reflectance :: number
	t.eq(PaintLooks.reflectance("old", "kamri07", chrome, chromeOwn), chromeOwn, "old: chrome stays")
	for _, o in SkyConfig.options do
		t.eq(PaintLooks.sunClockTime("old", o.id), nil, `old: the {o.id} sky keeps its hour`)
	end

	local coat = PaintLooks.looks.main.clearcoat
	t.ok(coat > 0, "main has a clear coat")
	t.eq(PaintLooks.reflectance("main", "kamri07", factory, 0), coat, "main: the Kamri's factory paint takes the coat")
	t.eq(PaintLooks.reflectance("main", "tahu", factory, 0), 0, "main: a car the coat is not tried on is untouched")
	t.eq(PaintLooks.reflectance("main", "kamri07", matte, matte.reflectance :: number), matte.reflectance, "main: matte stays flat")
	t.eq(PaintLooks.reflectance("main", "kamri07", chrome, chromeOwn), math.max(chromeOwn, coat), "main: chrome is never duller")
	t.eq(PaintLooks.reflectance("main", "kamri07", factory, 0.5), 0.5, "a factory piece already shinier than the coat keeps its own")

	-- The sun hours: still a sunset (after 17:00, earlier than the picked
	-- Sunset so the sun is higher), only on the sunset option.
	local sunset = SkyConfig.find("sunset") :: SkyConfig.Option
	for id in PaintLooks.looks do
		local h = PaintLooks.sunClockTime(id, "sunset")
		if h then
			t.ok(h > 17 and h < sunset.clockTime, `{id}: sunset at {h} is a higher sun, still a sunset`)
		end
		t.eq(PaintLooks.sunClockTime(id, "night"), nil, `{id}: the night sky keeps its hour`)
	end
	t.ok(PaintLooks.sunClockTime("main", "sunset") ~= nil, "main raises the sunset sun")
end
