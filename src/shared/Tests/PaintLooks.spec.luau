--!strict
-- PaintLooks: the finish and sun-hour variants switch on, in Studio, with B.
-- The main look comes first and an unknown id falls back to it; "As before"
-- must be exactly the paint the game had (the CosmeticsConfig finish, the
-- picked sun); the looks reach only the cars they are tried on; and under
-- every look each finish must read as its own (the owner, 2026-11-09: "make
-- sure there is an actual difference between the finishes"): factory the
-- least shine of the shiny ones, gloss and metallic clearly above it,
-- chrome the most, matte flat and darkest of the paints that keep their hue.
local PaintLooks = require(script.Parent.Parent.PaintLooks)
local CosmeticsConfig = require(script.Parent.Parent.CosmeticsConfig)
local SkyConfig = require(script.Parent.Parent.SkyConfig)
local ConfigLoader = require(script.Parent.Parent.ConfigLoader)
local Tests = require(script.Parent)
type T = Tests.T

local SMOOTH = Enum.Material.SmoothPlastic
local GLASS = Enum.Material.Glass

return function(t: T)
	t.eq(PaintLooks.order[1], "main", "the main look is first")
	local listed = {}
	for _, id in PaintLooks.order do
		listed[id] = true
		t.ok(PaintLooks.looks[id] ~= nil, `{id} in order is a look`)
	end
	for id in PaintLooks.looks do
		t.ok(listed[id] == true, `{id} is in the cycle order`)
	end
	t.eq(PaintLooks.resolve(nil), "main", "no choice: main")
	t.eq(PaintLooks.resolve("nope"), "main", "unknown choice: main")
	t.eq(PaintLooks.resolve("old"), "old", "a known choice stays")

	local cars = ConfigLoader.catalog().cars
	for id in PaintLooks.cars do
		t.ok(cars[id] ~= nil, `{id} is a catalog car`)
	end

	local finishes: { [string]: CosmeticsConfig.Item } = {}
	for _, item in CosmeticsConfig.items do
		if item.category == "finish" then
			finishes[item.id] = item
		end
	end
	local function paint(lookId: string, carId: string, finishId: string, ownRefl: number?, outdoors: boolean?): PaintLooks.Paint
		return PaintLooks.paint(lookId, carId, finishId, finishes[finishId], SMOOTH, ownRefl or 0, outdoors ~= false)
	end

	-- "As before" and cars the looks are not tried on, on the road and on
	-- the garage's turntable: the CosmeticsConfig finish exactly as
	-- CarCosmetics applied it.
	local cases: { { look: string, car: string, outdoors: boolean } } = {
		{ look = "old", car = "kamri07", outdoors = true },
		{ look = "old", car = "kamri07", outdoors = false },
		{ look = "main", car = "tahu", outdoors = true },
		{ look = "main", car = "tahu", outdoors = false },
	}
	for _, case in cases do
		local lookId, carId, outdoors = case.look, case.car, case.outdoors
		for id, item in finishes do
			local p = paint(lookId, carId, id, 0.07, outdoors)
			t.eq(p.material, item.material or SMOOTH, `{lookId} {carId} {id}: its own material`)
			local refl = if item.material then item.reflectance or 0 else 0.07
			t.eq(p.reflectance, refl, `{lookId} {carId} {id}: its own reflectance`)
			t.eq(p.darken, item.darken or 0, `{lookId} {carId} {id}: its own darkening`)
			t.eq(p.desaturate, item.desaturate or 0, `{lookId} {carId} {id}: its own desaturation`)
		end
	end
	for _, o in SkyConfig.options do
		t.eq(PaintLooks.sunClockTime("old", o.id), nil, `old: the {o.id} sky keeps its hour`)
	end

	-- Every other look on the Kamri: the finishes apart. Measured outdoors,
	-- SmoothPlastic's reflectance barely shows (0.04 and 0.25 looked alike);
	-- Glass is what reads as shine, so gloss, metallic and chrome are Glass
	-- and factory is not.
	for _, lookId in PaintLooks.order do
		if lookId == "old" then
			continue
		end
		local f = paint(lookId, "kamri07", "finish_stock")
		local g = paint(lookId, "kamri07", "finish_gloss")
		local m = paint(lookId, "kamri07", "finish_matte")
		local mt = paint(lookId, "kamri07", "finish_metallic")
		local c = paint(lookId, "kamri07", "finish_chrome")
		t.eq(f.material, SMOOTH, `{lookId}: factory keeps the car's own material`)
		t.eq(m.material, SMOOTH, `{lookId}: matte is smooth plastic`)
		t.eq(m.reflectance, 0, `{lookId}: matte shows no sky`)
		local shiny: { [string]: PaintLooks.Paint } = { gloss = g, metallic = mt, chrome = c }
		for name, p in shiny do
			t.eq(p.material, GLASS, `{lookId}: {name} is glass`)
		end
		t.ok(g.reflectance >= 0.2, `{lookId}: gloss shines ({g.reflectance})`)
		t.ok(mt.reflectance >= g.reflectance, `{lookId}: metallic at least as shiny as gloss`)
		t.ok(mt.darken >= 0.3, `{lookId}: metallic is a deeper colour than gloss ({mt.darken})`)
		t.ok(c.reflectance >= mt.reflectance + 0.25, `{lookId}: chrome far shinier than metallic`)
		t.ok(m.darken >= 0.3 and m.desaturate >= 0.3, `{lookId}: matte clearly duller than factory`)
		t.ok(f.darken == 0 and g.darken == 0, `{lookId}: factory and gloss keep the paint's colour`)
		local own = paint(lookId, "kamri07", "finish_stock", 0.5)
		t.eq(own.reflectance, 0.5, `{lookId}: a factory piece already shinier keeps its own`)
	end

	-- The garage's turntable under every other look (the owner, 2026-11-09:
	-- "gloss and factory looks the same" there, where gloss was Glass 0).
	-- Its lit bay washes Glass past about 0.05 toward coral and pink (0.1 was
	-- coral, 0.3 a pink car), so gloss gets a little Glass, more than none,
	-- metallic sits on a much darker base, and chrome stays the shiniest.
	for _, lookId in PaintLooks.order do
		if lookId == "old" then
			continue
		end
		local f = paint(lookId, "kamri07", "finish_stock", 0, false)
		local g = paint(lookId, "kamri07", "finish_gloss", 0, false)
		local m = paint(lookId, "kamri07", "finish_matte", 0, false)
		local mt = paint(lookId, "kamri07", "finish_metallic", 0, false)
		local c = paint(lookId, "kamri07", "finish_chrome", 0, false)
		t.eq(f.material, SMOOTH, `{lookId} garage: factory keeps the car's own material`)
		t.eq(f.reflectance, 0, `{lookId} garage: factory keeps its own reflectance`)
		t.eq(g.material, GLASS, `{lookId} garage: gloss is glass`)
		t.ok(g.reflectance > 0 and g.reflectance <= 0.06, `{lookId} garage: gloss shines without washing out ({g.reflectance})`)
		t.ok(mt.darken >= g.darken + 0.3, `{lookId} garage: metallic much deeper than gloss`)
		t.ok(c.reflectance > mt.reflectance and c.reflectance > g.reflectance, `{lookId} garage: chrome the shiniest`)
		t.ok(m.reflectance == 0 and (m.darken > 0 or m.desaturate > 0), `{lookId} garage: matte flat and dull`)
	end

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
