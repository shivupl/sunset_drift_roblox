--!strict
-- The distant Riyadh skyline, from a seeded random so every server draws the
-- same city.
--
-- One band of city along the right of the road, from behind the start line
-- to the city gateway, in two rows (low blocks in front, towers behind) with
-- a dense downtown cluster near the start and two landmark towers in it so
-- it reads as Riyadh and not as generic city. The sunset side stays empty.
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

-- The backdrop city is lit at every time of day: it sits away from the sun
-- with the sky to itself, and a dark silhouette there is worth nothing.
--
-- The one care needed is that haze swallows a building body long before it
-- swallows an emissive part, so in daylight every light here is pulled back
-- by dayDim or the windows and strips float free of the towers they belong
-- to. Both are decided once per build.
local litWindows = true
local dayDim = 0

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

local function smoothstepCurve(t: number): number
	t = math.clamp(t, 0, 1)
	return t * t * (3 - 2 * t)
end

local function tinted(colour: Color3, rng: Random, variation: number): Color3
	local tint = rng:NextNumber(-variation, variation)
	return if tint < 0 then colour:Lerp(Color3.new(0, 0, 0), -tint) else colour:Lerp(Color3.new(1, 1, 1), tint)
end

local MATERIALS = { Enum.Material.Concrete, Enum.Material.SmoothPlastic, Enum.Material.Metal, Enum.Material.Slate }

-- A colour from the weighted LED palette.
local function pickLed(L: typeof(WorldConfig.cityscape.lights), rng: Random): Color3
	local total = 0
	for _, e in L.ledPalette do
		total += e.weight
	end
	local r = rng:NextNumber(0, total)
	for _, e in L.ledPalette do
		r -= e.weight
		if r <= 0 then
			return e.color
		end
	end
	return L.ledPalette[1].color
end

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
	local bands = if site.tower then rng:NextInteger(c.towerBandsMin, c.towerBandsMax) else rng:NextInteger(c.blockBandsMin - 1, c.blockBandsMax)
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
				transparency = math.min(0.95, rng:NextNumber(0, 0.3) + dayDim),
			})
		end
	end

	-- Vertical LED strips up the corners of a share of the towers. At this
	-- distance the verticals are what read as a modern Gulf skyline; the
	-- window grid is already a smear by the time it gets to the road.
	local L = c.lights
	local ledColor = pickLed(L, rng)
	if site.tower and litWindows and rng:NextNumber() < L.ledStripChance then
		local sw = ctx.s(L.ledStripWidthM)
		local y0 = -height / 2 + height * L.ledStripFromFrac
		local sh = height * (L.ledStripToFrac - L.ledStripFromFrac)
		for _, sx in { -1, 1 } do
			Build.part({
				name = "LedStrip",
				size = Vector3.new(sw, sh, sw),
				cframe = cf * CFrame.new(sx * (width / 2 - sw / 2), y0 + sh / 2, -depth / 2 + sw / 2),
				color = ledColor,
				material = Enum.Material.Neon,
				parent = parent,
				transparency = math.min(0.9, L.ledTransparency + dayDim),
			})
		end
	end

	-- Lit rings round a share of the towers at random floors: one box a
	-- hair wider than the body each, so all four faces glow.
	if site.tower and litWindows and rng:NextNumber() < L.ringChance then
		local n = rng:NextInteger(L.ringsMin, L.ringsMax)
		local rh = ctx.s(L.ringHeightM)
		for i = 1, n do
			local frac = (i - rng:NextNumber(0, 0.6)) / n
			local y = -height / 2 + height * math.clamp(frac, 0.1, 0.95)
			Build.part({
				name = "LedRing",
				size = Vector3.new(width * 1.03, rh, depth * 1.03),
				cframe = cf * CFrame.new(0, y, 0),
				color = ledColor,
				material = Enum.Material.Neon,
				parent = parent,
				transparency = math.min(0.9, L.ledTransparency + dayDim),
			})
		end
	end

	-- A lit line along the roof of a share of the blocks, so the flat tops
	-- are not dead space between the towers.
	if not site.tower and litWindows and rng:NextNumber() < L.roofEdgeChance then
		Build.part({
			name = "RoofEdge",
			size = Vector3.new(width * 1.02, ctx.s(1.4), depth * 1.02),
			cframe = cf * CFrame.new(0, height / 2 - ctx.s(0.7), 0),
			color = L.roofEdgeColor,
			material = Enum.Material.Neon,
			parent = parent,
			transparency = math.min(0.92, 0.25 + dayDim),
		})
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
				transparency = math.min(0.9, 0.15 + dayDim),
			})
		end
		-- A lit needle on some towers, in the tower's LED colour.
		if litWindows and rng:NextNumber() < L.spireChance then
			local sh = ctx.s(L.spireHeightM)
			local sw = ctx.s(L.spireWidthM)
			Build.part({
				name = "Spire",
				size = Vector3.new(sw, sh, sw),
				cframe = cf * CFrame.new(0, topY + sh / 2, 0),
				color = ledColor,
				material = Enum.Material.Neon,
				parent = parent,
				transparency = math.min(0.9, L.ledTransparency + dayDim),
			})
			topY += sh
		elseif rng:NextNumber() < c.antennaChance then
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


-- The aura (WorldConfig.cityscape.aura): haze curtains between the rows and
-- a glowing dome behind the band. Each is a line of invisible panels facing
-- the road, carrying an unlit SurfaceGui gradient whose transparency is
-- given at four heights, top to foot. The panels abut exactly and the
-- gradient is the same on each, so there is no seam. Toward either end of
-- the band a panel is cut into strips that fade out sideways, over endFadeM.
local FADE_STRIPS = 16

type AuraLayer = {
	name: string,
	lateralM: number,
	heightM: number,
	groundColor: Color3,
	topColor: Color3,
	fade: { number }, -- transparency at the top, 2/3 up, 1/3 up and the foot
	brightness: number,
}

local function auraLayer(cfg: Config, ctx: Context, parent: Instance, frameAt: (number) -> CFrame, layer: AuraLayer)
	local c = cfg.cityscape
	local a = c.aura
	local band = c.band
	local fromM, toM = band.fromAlongM - a.endFadeM, band.toAlongM + a.endFadeM
	local count = math.ceil((toM - fromM) / a.panelM)
	local panelM = (toM - fromM) / count
	local transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, layer.fade[1]),
		NumberSequenceKeypoint.new(1 / 3, layer.fade[2]),
		NumberSequenceKeypoint.new(2 / 3, layer.fade[3]),
		NumberSequenceKeypoint.new(1, layer.fade[4]),
	})
	local colour = ColorSequence.new(layer.topColor, layer.groundColor)
	-- 0 at the faded-out tips of the band, 1 once endFadeM in.
	local function presence(alongM: number): number
		local t = math.min((alongM - fromM) / a.endFadeM, (toM - alongM) / a.endFadeM)
		return smoothstepCurve(t)
	end
	for i = 0, count - 1 do
		local startM = fromM + i * panelM
		local f = frameAt(startM + panelM / 2)
		local outward = f.RightVector * band.side
		local h = ctx.s(math.min(layer.heightM, 570))
		local pos = f.Position + outward * ctx.s(layer.lateralM) + Vector3.new(0, h / 2, 0)
		local panel = Build.part({
			name = layer.name,
			size = Vector3.new(ctx.s(panelM), h, ctx.s(1)),
			cframe = CFrame.lookAt(pos, pos - outward),
			color = layer.groundColor,
			parent = parent,
			transparency = 1,
		})
		local gui = Instance.new("SurfaceGui")
		gui.Name = "Gradient"
		gui.Face = Enum.NormalId.Front
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = a.pixelsPerStud
		gui.LightInfluence = 0
		gui.Brightness = layer.brightness
		gui.MaxDistance = 0 -- no limit: it is a backdrop
		gui.Parent = panel
		local faded = presence(startM) < 1 or presence(startM + panelM) < 1
		local strips = if faded then FADE_STRIPS else 1
		for k = 0, strips - 1 do
			-- The gui's left edge, seen from the road, is the part's +X. With
			-- the band on the right that is the later end of the stretch.
			local xc = (k + 0.5) / strips
			local alongM = if band.side > 0 then startM + panelM * (1 - xc) else startM + panelM * xc
			local strip = Instance.new("Frame")
			strip.Name = "Fill"
			strip.Position = UDim2.fromScale(k / strips, 0)
			strip.Size = UDim2.fromScale(1 / strips + 0.002, 1)
			strip.BorderSizePixel = 0
			strip.BackgroundColor3 = Color3.new(1, 1, 1)
			strip.BackgroundTransparency = if faded then 1 - presence(alongM) else 0
			strip.Parent = gui
			local grad = Instance.new("UIGradient")
			grad.Rotation = 90 -- top of the panel to its foot
			grad.Color = colour
			grad.Transparency = transparency
			grad.Parent = strip
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

	local lampsLit = WorldLighting.timeOfDay(cfg).lamps.enabled
	litWindows = c.lights.alwaysOn or lampsLit
	dayDim = if lampsLit then 0 else c.lights.dayExtraTransparency
	local rng = Build.rng(c.seed)
	local totalM = RoadNetwork.lengthM(path)

	-- The road frame at a distance along it, extrapolated straight past
	-- either end so the band can start behind the start line.
	local function frameAt(alongM: number): CFrame
		if alongM < 0 then
			local p = path[1]
			return p.cframe + p.cframe.LookVector * ctx.s(alongM)
		elseif alongM > totalM then
			local p = path[#path]
			return p.cframe + p.cframe.LookVector * ctx.s(alongM - totalM)
		end
		return RoadNetwork.sample(path, alongM).cframe
	end

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
	local band = c.band
	local function siteAt(alongM: number, lateralM: number, widthM: number, depthM: number, heightM: number, tower: boolean): Site
		local f = frameAt(alongM)
		local outward = f.RightVector * band.side
		return {
			base = f.Position + outward * ctx.s(lateralM),
			facing = -outward,
			widthM = widthM,
			depthM = depthM,
			heightM = heightM,
			tower = tower,
		}
	end
	-- Density along the band: 1 at densestAlongM, thinFraction at the ends.
	local function density(alongM: number): number
		local reach = math.max(band.densestAlongM - band.fromAlongM, band.toAlongM - band.densestAlongM)
		local t = math.clamp(math.abs(alongM - band.densestAlongM) / reach, 0, 1)
		local ease = t * t * (3 - 2 * t)
		return 1 - ease * (1 - band.thinFraction)
	end

	-- The band, row by row, stratified along its length so there are no
	-- bald patches, and thinned by the density curve so it has a middle.
	for _, row in band.rows do
		local slot = (band.toAlongM - band.fromAlongM) / row.count
		for i = 1, row.count do
			local alongM = band.fromAlongM + (i - 1) * slot + rng:NextNumber(0, slot)
			if rng:NextNumber() <= density(alongM) then
				local lateral = rng:NextNumber(row.nearM, row.farM)
				local tower = rng:NextNumber() < row.towerChance
				local width = rng:NextNumber(row.minWidthM, row.maxWidthM)
				local depth = rng:NextNumber(row.minWidthM, row.maxWidthM)
				local height = if tower then rng:NextNumber(row.towerMinHeightM, row.towerMaxHeightM) else rng:NextNumber(row.minHeightM, row.maxHeightM)
				if tower then
					width *= rng:NextNumber(0.35, 0.6)
					depth *= rng:NextNumber(0.35, 0.6)
				end
				local site = siteAt(alongM, lateral, width, depth, height, tower)
				if not inGrid(site.base) and not Dunes.behind(cfg, ctx, path, site.base) then
					building(cfg, ctx, rng, model, site)
				end
			end
		end
	end

	-- Downtown: the tall slim cluster, bunched toward its centre.
	local dt = c.downtown
	if dt.enabled then
		for _ = 1, dt.count do
			-- Two draws averaged: a tent over the centre, not a flat spread.
			local alongM = dt.alongM + (rng:NextNumber(-1, 1) + rng:NextNumber(-1, 1)) / 2 * dt.spreadM
			local lateral = rng:NextNumber(dt.nearM, dt.farM)
			local width = rng:NextNumber(dt.minWidthM, dt.maxWidthM)
			local depth = rng:NextNumber(dt.minWidthM, dt.maxWidthM)
			local height = rng:NextNumber(dt.minHeightM, dt.maxHeightM)
			local site = siteAt(alongM, lateral, width, depth, height, true)
			if not inGrid(site.base) then
				building(cfg, ctx, rng, model, site)
			end
		end
		if dt.glowEnabled then
			local f = frameAt(dt.alongM)
			local outward = f.RightVector * band.side
			local base = f.Position + outward * ctx.s((dt.nearM + dt.farM) / 2)
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

	-- The aura: haze between the rows, city glow behind.
	local a = c.aura
	if a.enabled then
		for i, cu in a.curtains do
			auraLayer(cfg, ctx, model, frameAt, {
				name = `Haze{i}`,
				lateralM = cu.lateralM,
				heightM = cu.heightM,
				groundColor = cu.color,
				topColor = cu.color,
				fade = cu.fade,
				brightness = 1,
			})
		end
		local g = a.glow
		auraLayer(cfg, ctx, model, frameAt, {
			name = "CityGlowDome",
			lateralM = g.lateralM,
			heightM = g.heightM,
			groundColor = g.groundColor,
			topColor = g.topColor,
			fade = g.fade,
			brightness = g.brightness,
		})
	end

	-- Landmarks.
	local lm = c.landmarks
	if lm.enabled then
		local function place(alongM: number, lateralM: number): (Vector3, Vector3)
			local f = frameAt(alongM)
			local outward = f.RightVector * band.side
			return f.Position + outward * ctx.s(lateralM), -outward
		end
		local kb, kf = place(lm.kingdom.alongM, lm.kingdom.lateralM)
		kingdom(cfg, ctx, rng, model, kb, kf)
		local fb, ff = place(lm.faisaliah.alongM, lm.faisaliah.lateralM)
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
