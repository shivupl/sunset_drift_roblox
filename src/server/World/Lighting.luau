--!strict
-- Lamp posts and every Lighting service setting.
--
-- The lamps themselves carry no Light instance. The server builds the post
-- and a lens under the head, then tags the lens so the client light manager
-- can hang one of its twelve pooled SpotLights from the nearest ones. That is the whole
-- reason the world can have two hundred lamps and still run: Roblox degrades
-- badly past a handful of live lights, and an unlit Neon head still reads as
-- a lamp from a distance.
--
-- The post itself is one store mesh (AssetRegistry.highwayLamp): a concrete
-- pedestal, a tapering pole and the curved cobra arm in a single textured
-- piece, cloned from one template. The box pole and box arm that used to be
-- built here are kept as the stand-in for when that mesh cannot load.
local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local WorldConfig = require(script.Parent.WorldConfig)
local Build = require(script.Parent.Build)
local RoadNetwork = require(script.Parent.RoadNetwork)
local AssetRegistry = require(script.Parent.AssetRegistry)

type Config = WorldConfig.Config
type Context = RoadNetwork.Context
type Path = RoadNetwork.Path

local WorldLighting = {}

WorldLighting.LAMP_TAG = "HajwalaLamp"

-- The active time-of-day preset. Everything about the look comes from here.
function WorldLighting.timeOfDay(cfg: Config)
	return cfg.timesOfDay[cfg.timeOfDay] or cfg.timesOfDay.goldenHour
end

function WorldLighting.applyAtmosphere(cfg: Config)
	local t = WorldLighting.timeOfDay(cfg)

	Lighting.ClockTime = t.clockTime
	Lighting.GeographicLatitude = t.geographicLatitude
	Lighting.Ambient = t.ambient
	Lighting.OutdoorAmbient = t.outdoorAmbient
	Lighting.Brightness = t.brightness
	Lighting.ExposureCompensation = t.exposureCompensation
	-- ColorShift tints the lit and unlit halves of every surface. At golden
	-- hour this is what stops the asphalt reading as grey plastic: the lit
	-- faces pick up the sun's orange and the shadowed ones go cool.
	Lighting.ColorShift_Top = t.colorShiftTop
	Lighting.ColorShift_Bottom = t.colorShiftBottom
	Lighting.GlobalShadows = t.globalShadows
	Lighting.FogEnd = if cfg.fogEnabled then 5000 else 1e6

	-- Lighting.Technology is a place setting; a script can neither write nor
	-- read it back, so this cannot be checked or fixed from here. It matters:
	-- under Voxel the raking shadows this hour is built around do not render
	-- at all, and the scene falls flat.
	if t.globalShadows then
		print(
			`[World] shadows need Lighting.Technology = {cfg.technology}. `
				.. `Set it on Lighting in the Studio Properties panel; it is not scriptable.`
		)
	end

	local oldSky = Lighting:FindFirstChildOfClass("Sky")
	if oldSky then
		oldSky:Destroy()
	end
	-- No Sky object by default, and that is the whole trick for the sky.
	-- A Sky instance with no textures does not fall back to something
	-- procedural: it renders Roblox's default skybox, which is a painted
	-- daytime blue that darkens at night but never turns warm at sunset. With
	-- no Sky object at all the engine draws its procedural dome, which tracks
	-- ClockTime properly and lets the Atmosphere below colour the horizon.
	-- useSkyObject stays as the hook for a painted skybox once six texture
	-- ids have been vetted.
	if t.sky.useSkyObject then
		local sky = Instance.new("Sky")
		sky.Name = "SkyDome"
		sky.StarCount = t.sky.starCount
		sky.CelestialBodiesShown = t.sky.celestialBodiesShown
		sky.SunAngularSize = t.sky.sunAngularSize
		local box = t.sky.skybox
		if box then
			sky.SkyboxBk = `rbxassetid://{box.bk}`
			sky.SkyboxDn = `rbxassetid://{box.dn}`
			sky.SkyboxFt = `rbxassetid://{box.ft}`
			sky.SkyboxLf = `rbxassetid://{box.lf}`
			sky.SkyboxRt = `rbxassetid://{box.rt}`
			sky.SkyboxUp = `rbxassetid://{box.up}`
		end
		sky.Parent = Lighting
	end

	local oldAtmos = Lighting:FindFirstChildOfClass("Atmosphere")
	if oldAtmos then
		oldAtmos:Destroy()
	end
	local a = Instance.new("Atmosphere")
	a.Name = "Haze"
	a.Density = t.atmosphere.density
	a.Offset = t.atmosphere.offset
	a.Color = t.atmosphere.color
	a.Decay = t.atmosphere.decay
	a.Glare = t.atmosphere.glare
	a.Haze = t.atmosphere.haze
	a.Parent = Lighting

	local oldRays = Lighting:FindFirstChildOfClass("SunRaysEffect")
	if oldRays then
		oldRays:Destroy()
	end
	if t.sunRays.enabled then
		local rays = Instance.new("SunRaysEffect")
		rays.Name = "SunShafts"
		rays.Intensity = t.sunRays.intensity
		rays.Spread = t.sunRays.spread
		rays.Parent = Lighting
	end
end

-- One mesh lamp post: foot on the ground at `foot`, arm reaching along
-- `armDir`, at `scale` of the 10.6 m mesh. The lens is a separate thin
-- part under the head, Neon when the hour lights the lamps and dark glass
-- otherwise, and it carries the tag the client light manager looks for;
-- its bottom face points down, which is where the pooled SpotLight shines
-- from. Used by the highway and by the city. Returns false if the mesh is
-- not available, so the caller can build its box stand-in.
function WorldLighting.meshLamp(cfg: Config, ctx: Context, parent: Instance, foot: Vector3, armDir: Vector3, scale: number, castShadow: boolean): boolean
	local l = cfg.lamps
	if not l.useMesh or not AssetRegistry.hasProp("highwayLamp") then
		return false
	end
	local lit = WorldLighting.timeOfDay(cfg).lamps.enabled
	-- lookAt puts -Z on the target; a quarter turn about Y then puts the
	-- mesh's +X (the arm) along armDir.
	local cf = CFrame.lookAt(foot, foot + armDir) * CFrame.Angles(0, math.pi / 2, 0)
	local model = AssetRegistry.place("highwayLamp", cf, scale, ctx.mps, parent, castShadow)
	if not model then
		return false
	end
	model.Name = "Post"
	local lensSize = Vector3.new(ctx.s(l.lensSizeM.X), ctx.s(l.lensSizeM.Y), ctx.s(l.lensSizeM.Z))
	local lens = Build.part({
		name = "Head",
		size = lensSize * scale,
		cframe = cf * CFrame.new(AssetRegistry.highwayLampLensOffsetM * scale / ctx.mps),
		color = if lit then l.lensLitColor else l.lensOffColor,
		material = if lit then Enum.Material.Neon else Enum.Material.Glass,
		parent = parent,
		transparency = if lit then l.lensLitTransparency else l.lensOffTransparency,
	})
	CollectionService:AddTag(lens, WorldLighting.LAMP_TAG)
	return true
end

function WorldLighting.buildLamps(cfg: Config, ctx: Context, path: Path, parent: Instance): Folder
	local l = cfg.lamps
	local r = cfg.road
	local folder = Build.folder("Lamps", parent)
	local totalM = RoadNetwork.lengthM(path)
	-- Just past the kerb, where a real post stands. Nothing here collides.
	local standoff = r.shoulderWidthM + r.kerbWidthM + l.setbackM

	local poleW = ctx.s(l.poleWidthM)
	local poleH = ctx.s(l.poleHeightM)
	local armLen = ctx.s(l.armLengthM)
	local headSize = ctx.s(l.headSizeM)

	local rng = Build.rng(l.jitterSeed)
	local castShadow = cfg.shadows.lamps
	-- A glowing bulb in daylight is one of the more obvious tells. At an hour
	-- where the lamps are not lit, the head is just a dark metal housing.
	local lit = WorldLighting.timeOfDay(cfg).lamps.enabled
	local headColor = if lit then l.bulbColor else l.headOffColor
	local headMaterial = if lit then Enum.Material.Neon else Enum.Material.Metal

	-- The stand-in: pole, arm and head from boxes.
	local function boxPost(lamp: Folder, base: Vector3, p: RoadNetwork.PathPoint, arms: { number }, yaw: number, heightScale: number)
		local thisPoleH = poleH * heightScale
		Build.part({
			name = "Pole",
			size = Vector3.new(poleW, thisPoleH, poleW),
			cframe = CFrame.new(base + Vector3.new(0, thisPoleH / 2, 0)) * CFrame.Angles(0, yaw, 0),
			color = l.poleColor:Lerp(Color3.new(0, 0, 0), rng:NextNumber(0, 0.12)),
			material = Enum.Material.Metal,
			parent = lamp,
			castShadow = castShadow,
		})
		for _, dir in arms do
			local armMid = base + Vector3.new(0, thisPoleH - poleW, 0) + p.cframe.RightVector * (dir * armLen / 2)
			Build.part({
				name = "Arm",
				size = Vector3.new(armLen, poleW * 0.8, poleW * 0.8),
				cframe = CFrame.lookAt(armMid, armMid + p.cframe.LookVector) * CFrame.Angles(0, math.rad(90), 0),
				color = l.poleColor,
				material = Enum.Material.Metal,
				parent = lamp,
				castShadow = castShadow,
			})
			local headPos = base + Vector3.new(0, thisPoleH - poleW * 1.6, 0) + p.cframe.RightVector * (dir * armLen)
			local head = Build.part({
				name = "Head",
				size = Vector3.new(headSize * 1.6, headSize * 0.45, headSize),
				cframe = CFrame.lookAt(headPos, headPos + p.cframe.LookVector),
				color = headColor,
				material = headMaterial,
				parent = lamp,
				castShadow = castShadow,
			})
			CollectionService:AddTag(head, WorldLighting.LAMP_TAG)
		end
	end

	-- One post. arms lists the directions the arms reach, in units of the
	-- road's RightVector: { -1 } for an outer post on the right shoulder,
	-- { -1, 1 } for a median post. A median post is two mesh posts back to
	-- back, the second a hand's width along the road so the two poles read
	-- as one thick pole rather than two coincident surfaces shimmering.
	local function post(base: Vector3, p: RoadNetwork.PathPoint, arms: { number })
		local lamp = Build.folder("Lamp", folder)
		local yaw = math.rad(rng:NextNumber(-l.yawJitterDeg, l.yawJitterDeg))
		local heightScale = 1 + rng:NextNumber(-l.heightJitter, l.heightJitter)
		local yawed = CFrame.Angles(0, yaw, 0)
		local ok = true
		for i, dir in arms do
			local foot = base + p.cframe.LookVector * ((i - 1) * ctx.s(l.pairGapM))
			local armDir = yawed:VectorToWorldSpace(p.cframe.RightVector * dir)
			ok = WorldLighting.meshLamp(cfg, ctx, lamp, foot, armDir, l.meshScale * heightScale, castShadow) and ok
		end
		if ok then
			return
		end
		lamp:ClearAllChildren()
		boxPost(lamp, base, p, arms, yaw, heightScale)
	end

	local index = 0
	RoadNetwork.repeatAlong(path, ctx, l.spacingM, l.spacingM, totalM, function(p)
		index += 1
		local sides: { number } = if l.bothSides then { -1, 1 } else { if index % 2 == 0 then 1 else -1 }
		for _, side in sides do
			local base = p.position + p.cframe.RightVector * (side * (p.halfWidth + ctx.s(standoff)))
			post(base, p, { -side }) -- arm reaches back over the road
		end
	end)
	if l.medianLamps then
		-- Offset by half a spacing so the median row interleaves the outer rows.
		RoadNetwork.repeatAlong(path, ctx, l.medianSpacingM, l.medianSpacingM / 2, totalM, function(p)
			post(p.position, p, { -1, 1 })
		end)
	end

	return folder
end

return WorldLighting
