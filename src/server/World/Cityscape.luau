--!strict
-- The distant Riyadh skyline, from a seeded random so every server draws the
-- same city.
--
-- Three layers. Two rings of ordinary city around the middle of the road (a
-- ring, not two bands beside the road: bands parallel to the road are
-- invisible from the road), a dense downtown cluster in a sector centred on
-- the road's direction of travel, which is where the player looks all
-- session, and two landmark towers in that cluster so it reads as Riyadh and
-- not as generic city.
--
-- Buildings are boxes with a few emissive bands, not textures. A texture
-- would be one draw per building, but it needs an asset to vet and upload
-- and at this distance a window grid resolves to a smear anyway. The bands
-- are split into segments of different brightness so floors read as lit and
-- unlit rather than one bar, towers get a lit crown and sometimes an
-- antenna, and a share of everything gets a narrower tier on top. About
-- 1,300 parts for the whole horizon, all Persistent: a skyline that pops
-- while driving is worse than the memory it costs.
local WorldConfig = require(script.Parent.WorldConfig)
local Build = require(script.Parent.Build)
local RoadNetwork = require(script.Parent.RoadNetwork)
local CityConfig = require(script.Parent.City.CityConfig)
local AssetRegistry = require(script.Parent.AssetRegistry)
local Dunes = require(script.Parent.Dunes)
local WorldLighting = require(script.Parent.Lighting)

-- Whether the skyline's windows are lit, decided once per build from the
-- time of day. This is the same rule the street lamps follow, and for the
-- same reason: a Neon slab in daylight is not a lit window, it is a sticker.
-- Seen through golden-hour haze, which swallows the building bodies long
-- before it swallows an emissive part, unlit-time Neon bands read as orange
-- bars floating on the horizon with nothing behind them.
local litWindows = true

local SIDE_FACES = { Enum.NormalId.Front, Enum.NormalId.Back, Enum.NormalId.Left, Enum.NormalId.Right }

type Config = WorldConfig.Config
type Context = RoadNetwork.Context
type Path = RoadNetwork.Path

local Cityscape = {}

type Site = {
	base: Vector3, -- ground position, studs
	facing: Vector3, -- toward the road
	widthM: number,
	depthM: number,
	heightM: number,
	tower: boolean,
}

local function tinted(colour: Color3, rng: Random, variation: number): Color3
	local tint = rng:NextNumber(-variation, variation)
	return if tint < 0 then colour:Lerp(Color3.new(0, 0, 0), -tint) else colour:Lerp(Color3.new(1, 1, 1), tint)
end

local MATERIALS = { Enum.Material.Concrete, Enum.Material.SmoothPlastic, Enum.Material.Metal, Enum.Material.Slate }

local function building(cfg: Config, ctx: Context, rng: Random, parent: Instance, site: Site)
	local c = cfg.cityscape
	local width, depth, height = ctx.s(site.widthM), ctx.s(site.depthM), ctx.s(site.heightM)
	local bodyColor = tinted(if site.tower then c.towerColor else c.color, rng, c.colorVariation)
	local material = MATERIALS[rng:NextInteger(1, #MATERIALS)]
	local yaw = rng:NextNumber(-0.25, 0.25)
	local up = Vector3.new(0, height / 2, 0)
	local cf = CFrame.lookAt(site.base + up, site.base + up + site.facing) * CFrame.Angles(0, yaw, 0)

	local body = Build.part({
		name = if site.tower then "Tower" else "Block",
		size = Vector3.new(width, height, depth),
		cframe = cf,
		color = bodyColor,
		material = material,
		parent = parent,
		castShadow = cfg.shadows.cityscape,
	})
	-- Tiled facade, three storeys a tile, tinted toward the body colour.
	AssetRegistry.facade(body, if site.tower then "glass" else "midRise", rng, SIDE_FACES, ctx.s(11), bodyColor:Lerp(Color3.new(1, 1, 1), 0.4), 0.1)

	-- A narrower tier on top of some, which breaks the box outline.
	local topY = height / 2
	if rng:NextNumber() < c.tierChance then
		local tw, td = width * rng:NextNumber(0.45, 0.75), depth * rng:NextNumber(0.5, 0.8)
		local th = height * rng:NextNumber(0.15, 0.35)
		Build.part({
			name = "Tier",
			size = Vector3.new(tw, th, td),
			cframe = cf * CFrame.new(rng:NextNumber(-0.15, 0.15) * width, height / 2 + th / 2, 0),
			color = bodyColor,
			material = material,
			parent = parent,
			castShadow = cfg.shadows.cityscape,
		})
		topY = height / 2 + th
	end

	-- Lit window bands on the road-facing face, fewer now that the facade
	-- texture carries the grid; these are the floors that glow at dusk.
	local bands = if site.tower then rng:NextInteger(2, 4) else rng:NextInteger(0, 2)
	local windowColor = if rng:NextNumber() < c.coolFraction then c.windowColorCool else c.windowColorWarm
	local inset = ctx.s(c.windowInsetM)
	for i = 1, bands do
		local frac = (i + rng:NextNumber(-0.2, 0.2)) / (bands + 1)
		local y = -height / 2 + height * math.clamp(frac, 0.08, 0.92)
		local segs = c.windowSegments
		local usable = width * rng:NextNumber(0.6, 0.92)
		local segW = usable / segs
		for sIdx = 1, segs do
			local x = -usable / 2 + segW * (sIdx - 0.5)
			Build.part({
				name = "Windows",
				size = Vector3.new(segW * rng:NextNumber(0.7, 0.98), ctx.s(c.windowHeightM), inset),
				cframe = cf * CFrame.new(x, y, -depth / 2 - inset / 2),
				color = if litWindows then windowColor else bodyColor:Lerp(Color3.fromRGB(46, 54, 70), 0.55),
				material = if litWindows then Enum.Material.Neon else Enum.Material.Glass,
				parent = parent,
				transparency = rng:NextNumber(0.25, 0.8),
			})
		end
	end

	if site.tower then
		if rng:NextNumber() < c.crownChance then
			Build.part({
				name = "Crown",
				size = Vector3.new(width * 1.02, ctx.s(1.6), depth * 1.02),
				cframe = cf * CFrame.new(0, topY - ctx.s(1.2), 0),
				color = if litWindows then c.crownColor else bodyColor,
				material = if litWindows then Enum.Material.Neon else Enum.Material.Metal,
				parent = parent,
				transparency = 0.35,
			})
		end
		if rng:NextNumber() < c.antennaChance then
			local ah = ctx.s(c.antennaHeightM)
			Build.part({
				name = "Antenna",
				size = Vector3.new(ctx.s(1.2), ah, ctx.s(1.2)),
				cframe = cf * CFrame.new(rng:NextNumber(-0.3, 0.3) * width, topY + ah / 2, 0),
				color = Color3.fromRGB(60, 60, 64),
				parent = parent,
			})
			topY += ah
		end
		if rng:NextNumber() < c.beaconChance then
			Build.part({
				name = "Beacon",
				size = Vector3.new(ctx.s(1.6), ctx.s(1.6), ctx.s(1.6)),
				cframe = cf * CFrame.new(0, topY + ctx.s(1), 0),
				color = c.beaconColor,
				material = Enum.Material.Neon,
				parent = parent,
			})
		end
	end
end

-- Kingdom-Centre style: a slab, two pillars rising from it, and a sky bridge
-- across their tops, so the silhouette carries the arch.
local function kingdom(cfg: Config, ctx: Context, rng: Random, parent: Instance, base: Vector3, facing: Vector3)
	local k = cfg.cityscape.landmarks.kingdom
	local c = cfg.cityscape
	local h, w, d = ctx.s(k.heightM), ctx.s(k.widthM), ctx.s(k.depthM)
	local colour = tinted(c.towerColor, rng, 0.05)
	local cf = CFrame.lookAt(base, base + facing)
	local slabH = h * k.archStartFrac
	Build.part({ name = "KingdomSlab", size = Vector3.new(w, slabH, d), cframe = cf * CFrame.new(0, slabH / 2, 0), color = colour, material = Enum.Material.Metal, parent = parent })
	local pillarW = w * 0.24
	local pillarH = h * (k.bridgeFrac - k.archStartFrac)
	for _, side in { -1, 1 } do
		Build.part({ name = "KingdomPillar", size = Vector3.new(pillarW, pillarH, d), cframe = cf * CFrame.new(side * (w / 2 - pillarW / 2), slabH + pillarH / 2, 0), color = colour, material = Enum.Material.Metal, parent = parent })
	end
	local bridgeH = h * (1 - k.bridgeFrac)
	Build.part({ name = "KingdomBridge", size = Vector3.new(w, bridgeH, d), cframe = cf * CFrame.new(0, slabH + pillarH + bridgeH / 2, 0), color = colour, material = Enum.Material.Metal, parent = parent })
	-- Lit edges: one band across the bridge and one strip up each pillar.
	Build.part({ name = "Windows", size = Vector3.new(w * 0.9, ctx.s(2.4), ctx.s(0.5)), cframe = cf * CFrame.new(0, slabH + pillarH + bridgeH / 2, -d / 2 - ctx.s(0.3)), color = if litWindows then c.windowColorCool else Color3.fromRGB(52, 62, 82), material = if litWindows then Enum.Material.Neon else Enum.Material.Glass, parent = parent, transparency = 0.2 })
	for i = 1, 6 do
		local y = slabH * (i / 7)
		Build.part({ name = "Windows", size = Vector3.new(w * 0.86, ctx.s(c.windowHeightM), ctx.s(0.5)), cframe = cf * CFrame.new(0, y, -d / 2 - ctx.s(0.3)), color = if litWindows then c.windowColorCool else Color3.fromRGB(52, 62, 82), material = if litWindows then Enum.Material.Neon else Enum.Material.Glass, parent = parent, transparency = rng:NextNumber(0.15, 0.5) })
	end
	Build.part({ name = "Beacon", size = Vector3.new(ctx.s(2), ctx.s(2), ctx.s(2)), cframe = cf * CFrame.new(0, h + ctx.s(1), 0), color = c.beaconColor, material = Enum.Material.Neon, parent = parent })
end

-- Faisaliah style: a square pyramid from four corner wedges, a globe near
-- the tip, a lit ring under it.
local function faisaliah(cfg: Config, ctx: Context, rng: Random, parent: Instance, base: Vector3, facing: Vector3)
	local f = cfg.cityscape.landmarks.faisaliah
	local c = cfg.cityscape
	local h, w = ctx.s(f.heightM), ctx.s(f.baseWidthM)
	local colour = tinted(c.towerColor, rng, 0.05)
	local cf = CFrame.lookAt(base, base + facing)
	-- A CornerWedgePart's tall corner is at its local (+X, -Z) corner
	-- (probed with a raycast, since the docs do not say). Four of them, each
	-- a quarter footprint, rotated a quarter turn each with that corner at
	-- the centre, make a square pyramid with the apex in the middle.
	local half = w / 2
	for i = 0, 3 do
		local rot = CFrame.Angles(0, i * math.pi / 2, 0)
		Build.cornerWedge({
			name = "FaisaliahFace",
			size = Vector3.new(half, h, half),
			cframe = cf * rot * CFrame.new(-half / 2, h / 2, half / 2),
			color = colour,
			material = Enum.Material.Metal,
			parent = parent,
		})
	end
	local globeD = ctx.s(f.globeDiameterM)
	local globe = Build.part({ name = "FaisaliahGlobe", size = Vector3.new(globeD, globeD, globeD), cframe = cf * CFrame.new(0, h * f.globeFrac, 0), color = if litWindows then c.windowColorWarm else Color3.fromRGB(74, 70, 62), material = if litWindows then Enum.Material.Neon else Enum.Material.Glass, parent = parent, transparency = 0.15 })
	globe.Shape = Enum.PartType.Ball
	-- Lit floors up the near face.
	for i = 1, 8 do
		local frac = i / 10
		local y = h * frac
		local wAt = w * (1 - frac) * 0.8
		Build.part({ name = "Windows", size = Vector3.new(wAt, ctx.s(c.windowHeightM), ctx.s(0.5)), cframe = cf * CFrame.new(0, y, -w * (1 - frac) / 2 - ctx.s(0.3)), color = if litWindows then c.windowColorWarm else Color3.fromRGB(74, 70, 62), material = if litWindows then Enum.Material.Neon else Enum.Material.Glass, parent = parent, transparency = rng:NextNumber(0.2, 0.55) })
	end
	Build.part({ name = "Beacon", size = Vector3.new(ctx.s(2), ctx.s(2), ctx.s(2)), cframe = cf * CFrame.new(0, h + ctx.s(1), 0), color = c.beaconColor, material = Enum.Material.Neon, parent = parent })
end

function Cityscape.build(cfg: Config, ctx: Context, path: Path, parent: Instance): Folder
	local c = cfg.cityscape
	local folder = Build.folder("Cityscape", parent)
	local model = Instance.new("Model")
	model.Name = "Skyline"
	model.Parent = folder

	litWindows = WorldLighting.timeOfDay(cfg).lamps.enabled
	local rng = Build.rng(c.seed)
	local mid = path[math.max(1, math.floor(#path / 2))]
	local centre = mid.position
	-- The road's direction of travel, for the downtown sector.
	local travel = path[#path].position - path[1].position
	travel = Vector3.new(travel.X, 0, travel.Z)
	local forwardAngle = if travel.Magnitude > 1 then math.atan2(travel.Z, travel.X) else -math.pi / 2

	-- Nothing from the backdrop may land in the city grid's streets.
	local keep = {
		minX = ctx.s(CityConfig.originM.x - 60),
		maxX = ctx.s(CityConfig.originM.x + CityConfig.blocksX * CityConfig.blockM + 60),
		minZ = ctx.s(CityConfig.originM.z - CityConfig.blocksZ * CityConfig.blockM - 60),
		maxZ = ctx.s(CityConfig.originM.z + 60),
	}
	local function inGrid(pos: Vector3): boolean
		return CityConfig.enabled and pos.X > keep.minX and pos.X < keep.maxX and pos.Z > keep.minZ and pos.Z < keep.maxZ
	end
	local function siteAt(angle: number, radiusM: number, widthM: number, depthM: number, heightM: number, tower: boolean): Site
		local outward = Vector3.new(math.cos(angle), 0, math.sin(angle))
		return {
			base = centre + outward * ctx.s(radiusM),
			facing = -outward,
			widthM = widthM,
			depthM = depthM,
			heightM = heightM,
			tower = tower,
		}
	end

	-- The rings, stratified by angle so there are no bald patches.
	for _, ring in c.rings do
		local slice = (math.pi * 2) / ring.count
		for i = 1, ring.count do
			local angle = (i - 1) * slice + rng:NextNumber(0, slice)
			local radius = ring.distanceM + rng:NextNumber() * ring.depthM
			local tower = rng:NextNumber() < ring.towerChance
			local width = rng:NextNumber(ring.minWidthM, ring.maxWidthM)
			local depth = rng:NextNumber(ring.minWidthM, ring.maxWidthM)
			local height = if tower then rng:NextNumber(ring.towerMinHeightM, ring.towerMaxHeightM) else rng:NextNumber(ring.minHeightM, ring.maxHeightM)
			if tower then
				width *= rng:NextNumber(0.35, 0.6)
				depth *= rng:NextNumber(0.35, 0.6)
			end
			local site = siteAt(angle, radius, width, depth, height, tower)
			if not inGrid(site.base) and not Dunes.behind(cfg, ctx, path, site.base) then
				building(cfg, ctx, rng, model, site)
			end
		end
	end

	-- Downtown.
	local dt = c.downtown
	if dt.enabled then
		local halfSector = math.rad(dt.sectorDeg)
		local centreAngle = forwardAngle + math.rad(dt.sectorOffsetDeg)
		for _ = 1, dt.count do
			local angle = centreAngle + rng:NextNumber(-halfSector, halfSector)
			local radius = rng:NextNumber(dt.minDistanceM, dt.maxDistanceM)
			local width = rng:NextNumber(dt.minWidthM, dt.maxWidthM)
			local depth = rng:NextNumber(dt.minWidthM, dt.maxWidthM)
			local height = rng:NextNumber(dt.minHeightM, dt.maxHeightM)
			local site = siteAt(angle, radius, width, depth, height, true)
			if not inGrid(site.base) then
				building(cfg, ctx, rng, model, site)
			end
		end
		if dt.glowEnabled then
			local outward = Vector3.new(math.cos(centreAngle), 0, math.sin(centreAngle))
			local base = centre + outward * ctx.s((dt.minDistanceM + dt.maxDistanceM) / 2)
			local gh = ctx.s(dt.glowHeightM)
			Build.part({
				name = "CityGlow",
				size = Vector3.new(ctx.s(dt.glowWidthM), gh, ctx.s(40)),
				cframe = CFrame.lookAt(base + Vector3.new(0, gh / 2, 0), base + Vector3.new(0, gh / 2, 0) - outward),
				color = dt.glowColor,
				material = Enum.Material.Neon,
				parent = model,
				transparency = dt.glowTransparency,
			})
		end
	end

	-- Landmarks.
	local lm = c.landmarks
	if lm.enabled then
		local function place(offsetDeg: number, distanceM: number): (Vector3, Vector3)
			local angle = forwardAngle + math.rad(offsetDeg)
			local outward = Vector3.new(math.cos(angle), 0, math.sin(angle))
			return centre + outward * ctx.s(distanceM), -outward
		end
		local kb, kf = place(lm.kingdom.offsetDeg, lm.kingdom.distanceM)
		kingdom(cfg, ctx, rng, model, kb, kf)
		local fb, ff = place(lm.faisaliah.offsetDeg, lm.faisaliah.distanceM)
		faisaliah(cfg, ctx, rng, model, fb, ff)
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
