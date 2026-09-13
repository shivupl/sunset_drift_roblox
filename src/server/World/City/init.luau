--!strict
-- The city section: a Riyadh-style edge-of-town grid attached to the
-- highway by an off-ramp and an on-ramp. Streets first, which leaves a plan
-- of parcels; buildings fill the parcels by district; furniture and planting
-- follow the streets. Everything from CityConfig and a seeded random.
local WorldConfig = require(script.Parent.WorldConfig)
local Build = require(script.Parent.Build)
local RoadNetwork = require(script.Parent.RoadNetwork)
local CityConfig = require(script.CityConfig)
local Streets = require(script.Streets)
local Buildings = require(script.Buildings)
local Furniture = require(script.Furniture)
local Roundabouts = require(script.Roundabouts)
local AssetRegistry = require(script.Parent.AssetRegistry)

type Context = RoadNetwork.Context

local City = {}

export type Tally = { label: string, parts: number, tris: number }

function City.build(ctx: Context, parent: Instance): { Tally }
	local c = CityConfig
	local counts: { Tally } = {}
	if not c.enabled then
		return counts
	end
	local folder = Build.folder("City", parent)
	local plan, streets, detail = Streets.build(ctx, c, folder)
	table.insert(counts, { label = "city streets", parts = Build.countParts(streets), tris = Build.estimateTriangles(streets) })
	table.insert(counts, { label = "city detail", parts = Build.countParts(detail), tris = Build.estimateTriangles(detail) })
	AssetRegistry.preload()
	local buildings = Buildings.build(ctx, c, plan, folder)
	table.insert(counts, { label = "city bldgs", parts = Build.countParts(buildings), tris = Build.estimateTriangles(buildings) })
	local furniture = Furniture.build(ctx, c, plan, folder)
	-- Roundabouts last: they carve their rings out of everything already
	-- laid, the highway's end included, then build the ring and island.
	local carveRoots: { Instance } = { streets, detail, furniture }
	for _, name in { "Road", "RoadDetail" } do
		local root = workspace:FindFirstChild(name)
		if root then
			table.insert(carveRoots, root)
		end
	end
	for _, name in { "Lamps", "Scatter", "Signage" } do
		local root = parent:FindFirstChild(name)
		if root then
			table.insert(carveRoots, root)
		end
	end
	local t0 = os.clock()
	local rings, carved, removed = Roundabouts.build(ctx, c, plan, folder, carveRoots)
	print(string.format("[City] roundabouts: %d parts carved, %d props removed, %.1f s", carved, removed, os.clock() - t0))
	table.insert(counts, { label = "city props", parts = Build.countParts(furniture), tris = Build.estimateTriangles(furniture) })
	table.insert(counts, { label = "roundabouts", parts = Build.countParts(rings), tris = Build.estimateTriangles(rings) })
	local _ = WorldConfig
	return counts
end

return City
