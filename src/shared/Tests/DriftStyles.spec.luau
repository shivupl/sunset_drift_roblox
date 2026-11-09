--!strict
local Shared = script.Parent.Parent
local DriftStyles = require(Shared.DriftStyles)
local CarConfig = require(Shared.CarConfig)
local CarCatalog = require(Shared.CarCatalog)
local Tests = require(script.Parent)
type T = Tests.T

-- Every leaf path of a nested table ("tires.front.grip"); arrays are leaves.
local function paths(tbl: { [string]: any }, prefix: string, out: { [string]: boolean })
	for k, v in tbl do
		local p = if prefix == "" then tostring(k) else prefix .. "." .. tostring(k)
		local first = if type(v) == "table" then (next(v)) else nil
		if type(v) == "table" and type(k) == "string" and #v == 0 and type(first) == "string" then
			paths(v, p, out)
		else
			out[p] = true
		end
	end
end

local function at(tbl: any, path: string): any
	local v = tbl
	for part in string.gmatch(path, "[^%.]+") do
		if type(v) ~= "table" then
			return nil
		end
		v = v[part]
	end
	return v
end

return function(t: T)
	-- Every layout has styles, its first is its default, and the order lists every style once
	local seen: { [string]: boolean } = {}
	for _, id in DriftStyles.order do
		t.ok(DriftStyles.styles[id] ~= nil, `order names a style: {id}`)
		t.ok(not seen[id], `listed once: {id}`)
		seen[id] = true
	end
	for id in DriftStyles.styles do
		t.ok(seen[id], `every style is in the order: {id}`)
	end
	for _, layout in DriftStyles.layouts do
		local ids = DriftStyles.forLayout(layout)
		t.ok(#ids >= 2, `{layout} has at least two styles`)
		t.eq(DriftStyles.default(layout), ids[1], `{layout}'s default is its first`)
		t.ok(DriftStyles.layoutName[layout] ~= nil, `{layout} has a name`)
		for _, id in ids do
			t.eq(DriftStyles.styles[id].layout, layout, `forLayout only lists its own: {id}`)
		end
	end

	-- A style sets only keys CarConfig has, and none a catalog car tunes
	local carKeys: { [string]: string } = {}
	for carId, entry in CarCatalog.cars do
		if entry.tuning then
			local p: { [string]: boolean } = {}
			paths(entry.tuning, "", p)
			for k in p do
				carKeys[k] = carId
			end
		end
	end
	for id, style in DriftStyles.styles do
		t.ok(#style.name > 0 and #style.blurb > 0, `{id} has a name and a blurb`)
		local p: { [string]: boolean } = {}
		paths(style.tuning, "", p)
		for k in p do
			t.ok(at(CarConfig, k) ~= nil, `{id}: {k} is a CarConfig key`)
			if k ~= "drivetrain.layout" then
				t.ok(carKeys[k] == nil, `{id}: {k} is not tuned by a car ({carKeys[k] or ""})`)
			end
		end
	end

	-- apply: the style's numbers over a copy of the car's config, the layout set
	local base = CarConfig
	for id, style in DriftStyles.styles do
		local cfg = DriftStyles.apply(base, id)
		t.eq(cfg.drivetrain.layout, style.layout, `apply sets the layout: {id}`)
		t.ok(cfg ~= base and cfg.drift ~= base.drift and cfg.tires ~= base.tires, `apply copies: {id}`)
		local p: { [string]: boolean } = {}
		paths(style.tuning, "", p)
		for k in p do
			t.eq(at(cfg, k), at(style.tuning, k), `apply sets {k}: {id}`)
		end
		-- ranges
		local d = cfg.drift
		t.ok(d.featherSeconds >= 0 and d.featherSeconds <= 0.6, `{id}: feather 0..0.6 s`)
		t.ok(math.abs(d.kickDeg) <= 20, `{id}: kick within 20 degrees`)
		t.ok(d.holdMinDeg < d.holdMaxDeg, `{id}: a band with room in it`)
		t.ok(d.liftThrow >= 0 and d.liftThrow <= 1, `{id}: liftThrow 0..1`)
		t.ok(cfg.drivetrain.frontShare >= 0 and cfg.drivetrain.frontShare <= 1, `{id}: frontShare 0..1`)
	end
	t.eq(CarConfig.drivetrain.layout, "RWD", "apply leaves the shared config alone")

	-- resolve: the id if it fits the layout, else the layout's default
	t.eq(DriftStyles.resolve("RWD", "power"), "power", "a rear-drive style on a rear-drive car")
	t.eq(DriftStyles.resolve("FWD", "power"), DriftStyles.default("FWD"), "a style of another layout falls back")
	t.eq(DriftStyles.resolve("RWD", "gone"), DriftStyles.default("RWD"), "an unknown id falls back")
	t.eq(DriftStyles.resolve("RWD", 7), DriftStyles.default("RWD"), "a non-string falls back")
	t.eq(DriftStyles.layoutOf({ drivetrain = { layout = "AWD" } }), "AWD", "layoutOf reads the config")
	t.eq(DriftStyles.layoutOf({ drivetrain = {} }), "RWD", "no layout is rear drive")
	t.eq(DriftStyles.layoutOf({ drivetrain = { layout = "4WD" } }), "RWD", "an unknown layout is rear drive")

	-- The cars' real drivetrains
	local function layoutOfCar(id: string): string
		local e = CarCatalog.cars[id]
		local tun = e and e.tuning
		return DriftStyles.layoutOf({ drivetrain = (tun and tun.drivetrain) or {} })
	end
	t.eq(layoutOfCar("kamri07"), "FWD", "the Kamri (a Camry) is front drive")
	t.eq(layoutOfCar("batrol"), "AWD", "the Batrol (a Patrol) is four-wheel drive")
	t.eq(layoutOfCar("kruzer80"), "AWD", "the Kruzer 80 (a Land Cruiser) is four-wheel drive")
	for _, id in { "krownvik", "krownvikfleet", "lekzas" } do
		t.eq(layoutOfCar(id), "RWD", `{id} is rear drive`)
	end
end
