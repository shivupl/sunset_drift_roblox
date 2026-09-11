--!strict
-- The distant Riyadh skyline: a band of box buildings on the horizon, from a
-- seeded random so every server draws the same city.
--
-- Windows are small emissive parts, not a texture. A texture would be one
-- draw per building instead of three or four, but it needs a texture asset to
-- vet and upload, it is a large-surface draw the brief says to measure first,
-- and at this distance a window grid resolves to a smear anyway. Three or
-- four Neon bands per building cost 12 triangles each, need no asset, and
-- read correctly as lit floors from two and a half kilometres away. Ninety
-- buildings plus their bands come to roughly 300 parts and 3,600 triangles
-- for the entire horizon.
--
-- The model is Persistent rather than streamed. A skyline that pops in and
-- out as the player drives is worse than the memory it saves, and 300 small
-- boxes is a rounding error against the streaming budget.
local WorldConfig = require(script.Parent.WorldConfig)
local Build = require(script.Parent.Build)
local RoadNetwork = require(script.Parent.RoadNetwork)

type Config = WorldConfig.Config
type Context = RoadNetwork.Context
type Path = RoadNetwork.Path

local Cityscape = {}

function Cityscape.build(cfg: Config, ctx: Context, path: Path, parent: Instance): Folder
	local c = cfg.cityscape
	local folder = Build.folder("Cityscape", parent)
	local model = Instance.new("Model")
	model.Name = "Skyline"
	model.Parent = folder

	local rng = Build.rng(c.seed)

	-- A ring around the middle of the road, not two bands beside it. Bands
	-- parallel to the road are invisible from the road: looking down the
	-- straight you see the gap between them. A ring puts skyline in every
	-- viewing direction, which is what "a city on the horizon" has to mean
	-- when the player spends the whole session looking forward.
	local mid = path[math.max(1, math.floor(#path / 2))]
	local centre = mid.position

	for i = 1, c.count do
		-- Stratified by angle so the ring has no bald patches, jittered
		-- inside its slice so it does not read as a fence of towers.
		local slice = (math.pi * 2) / c.count
		local angle = (i - 1) * slice + rng:NextNumber(0, slice)
		local radius = ctx.s(c.distanceM) + rng:NextNumber() * ctx.s(c.bandDepthM)
		local width = ctx.s(rng:NextNumber(c.minWidthM, c.maxWidthM))
		local depthM = ctx.s(rng:NextNumber(c.minWidthM, c.maxWidthM))
		-- Mostly blocks, occasionally a tower.
		local isTower = rng:NextNumber() < c.towerChance
		local height = ctx.s(
			if isTower
				then rng:NextNumber(c.towerMinHeightM, c.towerMaxHeightM)
				else rng:NextNumber(c.minHeightM, c.maxHeightM)
		)
		if isTower then
			width *= rng:NextNumber(0.4, 0.7) -- towers are slim
		end
		local tint = rng:NextNumber(-c.colorVariation, c.colorVariation)
		local bodyColor = if tint < 0
			then c.color:Lerp(Color3.new(0, 0, 0), -tint)
			else c.color:Lerp(Color3.new(1, 1, 1), tint)

		local outward = Vector3.new(math.cos(angle), 0, math.sin(angle))
		local base = centre + outward * radius
		-- Face the road, so the lit side is the side the player sees.
		local facing = -outward
		local cf = CFrame.lookAt(base + Vector3.new(0, height / 2, 0), base + Vector3.new(0, height / 2, 0) + facing)
			* CFrame.Angles(0, rng:NextNumber(-0.25, 0.25), 0)

		Build.part({
			name = "Tower",
			size = Vector3.new(width, height, depthM),
			cframe = cf,
			color = bodyColor,
			material = Enum.Material.Concrete,
			parent = model,
			castShadow = cfg.shadows.cityscape,
		})

		-- Window bands on the road-facing face, inset so they do not z-fight
		-- with the wall they sit on.
		local bands = rng:NextInteger(c.windowBandsMin, c.windowBandsMax)
		for i = 1, bands do
			local frac = (i + rng:NextNumber(-0.2, 0.2)) / (bands + 1)
			local y = -height / 2 + height * math.clamp(frac, 0.1, 0.92)
			Build.part({
				name = "Windows",
				size = Vector3.new(width * rng:NextNumber(0.5, 0.9), ctx.s(c.windowHeightM), ctx.s(c.windowInsetM)),
				cframe = cf * CFrame.new(0, y, -depthM / 2 - ctx.s(c.windowInsetM) / 2),
				color = c.windowColor,
				material = Enum.Material.Neon,
				parent = model,
				transparency = rng:NextNumber(0.15, 0.5),
			})
		end

		if rng:NextNumber() < c.beaconChance then
			Build.part({
				name = "Beacon",
				size = Vector3.new(ctx.s(1.5), ctx.s(1.5), ctx.s(1.5)),
				cframe = cf * CFrame.new(0, height / 2 + ctx.s(1), 0),
				color = c.beaconColor,
				material = Enum.Material.Neon,
				parent = model,
			})
		end
	end

	-- Never streamed out: the horizon must not pop while driving.
	if cfg.streaming.enabled and cfg.streaming.cityscapePersistent then
		local ok = pcall(function()
			model.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
		end)
		if not ok then
			warn("[World] could not set ModelStreamingMode on the skyline")
		end
	end

	return folder
end

return Cityscape
