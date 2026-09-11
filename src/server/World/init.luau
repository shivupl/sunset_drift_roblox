--!strict
-- Builds the night highway once at server start, in a fixed order, and
-- reports what it cost. Nothing here runs again afterwards: the world is
-- static from this point on, and changing WorldConfig means restarting the
-- server. The one thing that keeps running is the client light manager,
-- which is a separate module and is throttled, not per frame.
--
-- Order matters. The road comes first because everything else places itself
-- by sampling the path it returns.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local WorldConfig = require(script.WorldConfig)
local Build = require(script.Build)
local RoadNetwork = require(script.RoadNetwork)
local AssetRegistry = require(script.AssetRegistry)
local WorldLighting = require(script.Lighting)
local Cityscape = require(script.Cityscape)
local Signage = require(script.Signage)
local Scatter = require(script.Scatter)

type Config = WorldConfig.Config

local World = {}

export type Result = {
	road: Model,
	path: RoadNetwork.Path,
	parts: number,
	triangles: number,
}

local function clearOld()
	for _, name in { "Road", "World", "Baseplate" } do
		local existing = workspace:FindFirstChild(name)
		if existing then
			existing:Destroy()
		end
	end
end

-- Streaming is a place setting, not a runtime one. Workspace.StreamingEnabled
-- can only be written from a plugin or the command bar, and the two radii
-- (StreamingTargetRadius, StreamingMinRadius) are not exposed to Lua at all --
-- they exist only in the Studio Properties panel. So WorldConfig.streaming is
-- the record of intent and this only reports drift on the one value a script
-- is allowed to read. WORLD.md lists the manual steps.
local function checkStreaming(cfg: Config)
	local st = cfg.streaming
	local ok, enabled = pcall(function()
		return workspace.StreamingEnabled
	end)
	if ok and enabled ~= st.enabled then
		warn(
			`[World] place has StreamingEnabled={enabled} but WorldConfig wants {st.enabled}. `
				.. `Set it on Workspace in Studio; a runtime script cannot.`
		)
	end
end

function World.build(): Result
	local cfg = WorldConfig
	clearOld()
	checkStreaming(cfg)

	local world = Instance.new("Folder")
	world.Name = "World"
	world.Parent = workspace

	local road, path, ctx = RoadNetwork.build(cfg, world)
	type Tally = { label: string, parts: number, tris: number }
	local counts: { Tally } = {}
	local function tally(label: string, root: Instance)
		table.insert(counts, { label = label, parts = Build.countParts(root), tris = Build.estimateTriangles(root) })
	end
	tally("road", road)

	-- Sky, atmosphere and the Lighting service, then the lamp geometry.
	WorldLighting.applyAtmosphere(cfg)
	if cfg.lamps.enabled then
		local folder = WorldLighting.buildLamps(cfg, ctx, path, world)
		tally("lamps", folder)
	end

	if cfg.cityscape.enabled then
		local folder = Cityscape.build(cfg, ctx, path, world)
		tally("cityscape", folder)
	end

	if cfg.signage.enabled then
		local folder = Signage.build(cfg, ctx, path, world)
		tally("signage", folder)
	end

	if cfg.scatter.enabled then
		-- Meshes load over the network once each, up front, so the scatter
		-- loop never yields part way through a clump.
		if cfg.scatter.useMeshes then
			local loaded = AssetRegistry.preload()
			print(`[World] {loaded} mesh pieces loaded`)
		end
		local folder = Scatter.build(cfg, ctx, path, world)
		tally("scatter", folder)
	end

	local totalParts = Build.countParts(road) + Build.countParts(world)
	local totalTris = Build.estimateTriangles(road) + Build.estimateTriangles(world)

	if cfg.debug.report then
		print(`[World] preset "{cfg.preset}", {math.floor(RoadNetwork.lengthM(path))} m of road`)
		for _, row in counts do
			print(string.format("[World]   %-10s %5d parts  ~%6d tris", row.label, row.parts, row.tris))
		end
		print(string.format("[World]   %-10s %5d parts  ~%6d tris (whole world, not one viewpoint)", "TOTAL", totalParts, totalTris))
	end

	-- Publish the lamp settings the client light manager needs, so it does
	-- not have to require a server module.
	-- Lamp light settings come from the active time of day, so golden hour
	-- ships dark lamps and night ships lit ones with no other change.
	local tod = WorldLighting.timeOfDay(cfg)
	local settings = Instance.new("Folder")
	settings.Name = "WorldSettings"
	settings:SetAttribute("LampsLit", tod.lamps.enabled)
	settings:SetAttribute("MaxLiveLights", cfg.lamps.maxLiveLights)
	settings:SetAttribute("LightUpdateInterval", cfg.lamps.lightUpdateInterval)
	settings:SetAttribute("LightColor", cfg.lamps.lightColor)
	settings:SetAttribute("LightBrightness", tod.lamps.brightness)
	settings:SetAttribute("LightRangeStuds", ctx.s(tod.lamps.rangeM))
	settings.Parent = ReplicatedStorage

	return { road = road, path = path, parts = totalParts, triangles = totalTris }
end

return World
