--!strict
-- Palms, scrub, rocks and dune ridges, placed by rule from a seeded random so
-- every server grows the same desert.
--
-- The central reservation is the signature planting. Palms go down it in
-- loose clumps of two to four, jittered along and across the median, with
-- varied height, lean and a second variety mixed in, because evenly spaced
-- identical trees read as generated and clumped varied ones read as planted.
-- The outer shoulders get the same treatment at a lower density that falls
-- off with distance from the road, so the near verge looks maintained and
-- the far desert looks empty.
--
-- Real meshes come from AssetRegistry; the primitive stand-ins only appear if
-- a mesh fails to load. Nothing here is collidable.
local WorldConfig = require(script.Parent.WorldConfig)
local Build = require(script.Parent.Build)
local RoadNetwork = require(script.Parent.RoadNetwork)
local AssetRegistry = require(script.Parent.AssetRegistry)
local Relief = require(script.Parent.Relief)
local Station = require(script.Parent.Station)

type Config = WorldConfig.Config
type Context = RoadNetwork.Context
type Path = RoadNetwork.Path

local Scatter = {}

-- 1 near the road, falling toward a floor at falloffEndM. Callers roll
-- against it.
local function density(cfg: Config, edgeDistanceM: number): number
	local s = cfg.scatter
	if edgeDistanceM <= s.falloffStartM then
		return 1
	end
	if edgeDistanceM >= s.falloffEndM then
		return 0.08 -- never quite zero: a bare horizon looks wrong too
	end
	local t = (edgeDistanceM - s.falloffStartM) / (s.falloffEndM - s.falloffStartM)
	return 1 - t * 0.92
end

-- Primitive date palm, used only when the mesh is unavailable.
local function primitivePalm(cfg: Config, ctx: Context, base: CFrame, rng: Random, parent: Instance, scale: number)
	local p = cfg.scatter.palm
	local trunkH = ctx.s(p.trunkHeightM * scale)
	local trunkW = ctx.s(p.trunkWidthM * scale)
	Build.part({
		name = "PalmTrunk",
		size = Vector3.new(trunkW, trunkH, trunkW),
		cframe = base * CFrame.new(0, trunkH / 2, 0),
		color = p.trunkColor,
		material = Enum.Material.Wood,
		parent = parent,
		castShadow = cfg.shadows.palms,
	})
	local frondLen = ctx.s(p.frondLengthM * scale)
	local frondW = ctx.s(p.frondWidthM * scale)
	for i = 1, p.frondCount do
		local yaw = (i / p.frondCount) * math.pi * 2 + rng:NextNumber(-0.2, 0.2)
		local droop = rng:NextNumber(0.3, 0.62)
		Build.part({
			name = "PalmFrond",
			size = Vector3.new(frondW, ctx.s(0.06), frondLen),
			cframe = base * CFrame.new(0, trunkH, 0) * CFrame.Angles(0, yaw, 0) * CFrame.Angles(-droop, 0, 0) * CFrame.new(0, 0, -frondLen / 2),
			color = p.frondColor,
			material = Enum.Material.Grass,
			parent = parent,
			castShadow = cfg.shadows.palms,
		})
	end
end

local function palm(cfg: Config, ctx: Context, at: Vector3, rng: Random, parent: Instance)
	local p = cfg.scatter.palm
	local scale = rng:NextNumber(p.minScale, p.maxScale)
	local lean = p.leanMaxRad
	local base = CFrame.new(at)
		* CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)
		* CFrame.Angles(rng:NextNumber(-lean, lean), 0, rng:NextNumber(-lean, lean))
	if cfg.scatter.useMeshes then
		local key = if rng:NextNumber() < p.varietyFraction then "fanPalm" else "datePalm"
		if AssetRegistry.place(key, base, scale, ctx.mps, parent, cfg.shadows.palms) then
			return
		end
	end
	primitivePalm(cfg, ctx, base, rng, parent, scale)
end

local function scrub(cfg: Config, ctx: Context, at: Vector3, rng: Random, parent: Instance)
	local sc = cfg.scatter.scrub
	local size = rng:NextNumber(sc.minSizeM, sc.maxSizeM)
	local base = CFrame.new(at) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)
	if cfg.scatter.useMeshes then
		-- One of the desert clumps at random: grasses, a broad-leaf shrub,
		-- the low bush. A verge of one bush repeated reads as a stamp.
		local key = AssetRegistry.scrubs[rng:NextInteger(1, #AssetRegistry.scrubs)]
		local unit = if key == "scrub" then 2 else 1.12
		local model = AssetRegistry.place(key, base, size / unit, ctx.mps, parent, false)
		if model then
			local tint = rng:NextNumber(-sc.colorVariation, sc.colorVariation)
			for _, part in model:GetChildren() do
				if part:IsA("BasePart") then
					part.Color = if tint < 0
						then sc.color:Lerp(Color3.new(0, 0, 0), -tint)
						else sc.color:Lerp(Color3.new(1, 1, 1), tint)
				end
			end
			return
		end
	end
	-- Two crossed flat boxes read as a bush from any road distance.
	for _, yaw in { 0, math.pi / 2 } do
		Build.part({
			name = "Scrub",
			size = Vector3.new(ctx.s(size), ctx.s(size * 0.45), ctx.s(size * 0.4)),
			cframe = base * CFrame.Angles(0, yaw, 0) * CFrame.new(0, ctx.s(size * 0.2), 0),
			color = sc.color,
			material = Enum.Material.Grass,
			parent = parent,
		})
	end
end

local function rock(cfg: Config, ctx: Context, at: Vector3, rng: Random, parent: Instance)
	local rk = cfg.scatter.rock
	local size = rng:NextNumber(rk.minSizeM, rk.maxSizeM)
	local base = CFrame.new(at) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)
	if cfg.scatter.useMeshes then
		local key = if rng:NextNumber() < 0.5 then "rockA" else "rockB"
		if AssetRegistry.place(key, base, size / 1.6, ctx.mps, parent, cfg.shadows.rocks) then
			return
		end
	end
	Build.part({
		name = "Rock",
		size = Vector3.new(ctx.s(size), ctx.s(size * rng:NextNumber(0.5, 0.9)), ctx.s(size * rng:NextNumber(0.7, 1.2))),
		cframe = base * CFrame.new(0, ctx.s(size * 0.25), 0) * CFrame.Angles(rng:NextNumber(-0.3, 0.3), 0, rng:NextNumber(-0.3, 0.3)),
		color = rk.color,
		material = Enum.Material.Rock,
		parent = parent,
		castShadow = cfg.shadows.rocks,
	})
end

-- A ridge: two wedges back to back, most of it below the sand plane, so it
-- reads as a low dune rather than a placed object. Sixteen triangles.
local function dune(cfg: Config, ctx: Context, at: Vector3, rng: Random, parent: Instance)
	local d = cfg.ground.dunes
	local length = ctx.s(rng:NextNumber(d.minLengthM, d.maxLengthM))
	local width = ctx.s(rng:NextNumber(d.minWidthM, d.maxWidthM))
	local height = ctx.s(rng:NextNumber(d.minHeightM, d.maxHeightM))
	local yaw = rng:NextNumber(0, math.pi)
	local base = CFrame.new(at) * CFrame.Angles(0, yaw, 0)
	local tint = rng:NextNumber(-0.08, 0.08)
	local color = if tint < 0 then d.color:Lerp(Color3.new(0, 0, 0), -tint) else d.color:Lerp(Color3.new(1, 1, 1), tint)
	-- Sunk a quarter so the foot of the ridge disappears into the plane.
	-- A WedgePart's tall face is at its +Z end and the slope runs down to
	-- -Z, so the half on the +Z side is turned round to put its tall face
	-- at the ridge line.
	local sink = height * 0.25
	for _, side in { -1, 1 } do
		Build.wedge({
			name = "Dune",
			size = Vector3.new(length, height, width / 2),
			cframe = base * CFrame.new(0, height / 2 - sink, side * width / 4) * CFrame.Angles(0, if side > 0 then math.pi else 0, 0),
			color = color,
			material = Enum.Material.Sand,
			parent = parent,
		})
	end
end

function Scatter.build(cfg: Config, ctx: Context, path: Path, parent: Instance): Folder
	local sc = cfg.scatter
	local folder = Build.folder("Scatter", parent)
	local totalM = RoadNetwork.lengthM(path)
	local rng = Build.rng(sc.seed)
	local lay = RoadNetwork.layout(path, ctx)
	-- Outer edge of the corridor proper: shoulder plus kerb.
	local vergeM = cfg.road.shoulderWidthM + cfg.road.kerbWidthM

	-- Occupied spots, so two props never land on top of each other.
	local taken: { Vector3 } = {}
	-- Nothing lands on the petrol station's site.
	local onStation = Station.keepOut(cfg, ctx, path)
	-- Nor on the border dunes: a palm or a camp on a dune face reads as
	-- floating, and anything past the crest is out of sight. Scrub is the
	-- exception and climbs part way up the windward slope.
	local border = if cfg.relief.enabled then Relief.border(cfg, ctx, path) else nil
	local function onDune(pos: Vector3, climbs: boolean): boolean
		if not border or not border.enabled then
			return false
		end
		local along, lateral = Relief.roadCoords(ctx, path, pos)
		if along > border.endM then
			return false
		end
		local side = if lateral >= 0 then 1 else -1
		-- Outside the fence is open desert again: props there show through
		-- the mesh.
		if border.fenceEnabled and along >= -border.fenceBehindM and along <= border.fenceEndM and math.abs(lateral) > border.fenceAt(side, along) + 3 then
			return false
		end
		-- Off the mounds entirely, except scrub, which may stand on a low
		-- flank. Between the mounds and past them is open sand again.
		local duneM = border.heightAt(along, lateral) - border.sinkM
		return duneM > (if climbs then 0.8 else -border.sinkM)
	end
	local function free(pos: Vector3, radius: number, climbs: boolean?): boolean
		if onStation(pos) or onDune(pos, climbs == true) then
			return false
		end
		for _, t in taken do
			if (t - pos).Magnitude < radius then
				return false
			end
		end
		table.insert(taken, pos)
		return true
	end

	-- Position on the ground at (distance along, lateral metres from the
	-- centreline), sat on the terrain relief where there is any.
	local function ground(d: number, lateralM: number): (Vector3, RoadNetwork.PathPoint)
		local p = RoadNetwork.sample(path, math.clamp(d, 0, totalM))
		local pos = p.position + p.cframe.RightVector * ctx.s(lateralM)
		local y = Relief.surfaceY(pos)
		if y then
			pos = Vector3.new(pos.X, y, pos.Z)
		end
		return pos, p
	end

	local p = sc.palm
	if p.enabled then
		-- A Model so it can be Persistent. Measured at 161 km/h with the
		-- default streaming radius: zero palm meshes in frustum, the median
		-- bare ahead of the car. The palms are the signature of the map and
		-- have to be there at speed, so they do not stream.
		local palms = Instance.new("Model")
		palms.Name = "Palms"
		palms.Parent = folder
		if cfg.streaming.enabled and cfg.streaming.palmsPersistent then
			pcall(function()
				palms.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
			end)
		end

		-- Median. Clumps at a spacing, each clump a few trees spread across
		-- the width of the reservation. This is the shot the map is built for.
		if p.medianEnabled then
			local half = lay.medianM / 2 - p.medianMarginM
			local d = p.medianClumpSpacingM * 0.5
			while d < totalM do
				local centreD = d + rng:NextNumber(-p.medianJitterM, p.medianJitterM)
				local count = rng:NextInteger(1, p.medianMaxPerClump)
				for _ = 1, count do
					local along = centreD + rng:NextNumber(-p.spreadM, p.spreadM)
					local lateral = rng:NextNumber(-half, half)
					local pos = ground(along, lateral)
					if free(pos, ctx.s(2.2)) then
						palm(cfg, ctx, pos, rng, palms)
					end
				end
				d += p.medianClumpSpacingM
			end
		end

		-- Outer shoulders, in clumps, thinning with distance.
		local d = p.clumpSpacingM
		while d < totalM do
			local centreD = d + rng:NextNumber(-p.clumpJitterM, p.clumpJitterM)
			local side = if rng:NextNumber() < 0.5 then -1 else 1
			local edgeM = rng:NextNumber(math.max(p.minEdgeM, vergeM + 2), p.maxEdgeM)
			if rng:NextNumber() <= density(cfg, edgeM) then
				for _ = 1, rng:NextInteger(p.minPerClump, p.maxPerClump) do
					local pos = ground(
						centreD + rng:NextNumber(-p.spreadM, p.spreadM),
						side * (lay.totalM / 2 + edgeM + rng:NextNumber(-p.spreadM, p.spreadM))
					)
					if free(pos, ctx.s(2.5)) then
						palm(cfg, ctx, pos, rng, palms)
					end
				end
			end
			d += p.clumpSpacingM
		end
	end

	if sc.scrub.enabled then
		local bushes = Build.folder("Scrub", folder)
		local s = sc.scrub
		local d = s.spacingM
		while d < totalM do
			local along = d + rng:NextNumber(-s.jitterM, s.jitterM)
			local side = if rng:NextNumber() < 0.5 then -1 else 1
			local edgeM = rng:NextNumber(math.max(s.minEdgeM, vergeM + 1), s.maxEdgeM)
			if rng:NextNumber() <= density(cfg, edgeM) then
				-- A cluster, not one clump: desert scrub grows where the
				-- last plant held the sand.
				for _ = 1, rng:NextInteger(s.clusterMin, s.clusterMax) do
					local pos = ground(along + rng:NextNumber(-s.clusterSpreadM, s.clusterSpreadM), side * (lay.totalM / 2 + edgeM + rng:NextNumber(-s.clusterSpreadM, s.clusterSpreadM)))
					if free(pos, ctx.s(0.9), true) then
						scrub(cfg, ctx, pos, rng, bushes)
					end
				end
			end
			-- Sparse low scrub between the median palms.
			if rng:NextNumber() < s.medianChance then
				local half = lay.medianM / 2 - p.medianMarginM
				local pos = ground(along + rng:NextNumber(-6, 6), rng:NextNumber(-half, half))
				if free(pos, ctx.s(1.2), true) then
					scrub(cfg, ctx, pos, rng, bushes)
				end
			end
			d += s.spacingM
		end
	end

	-- Desert trees: the odd acacia out on the verge, the one thing besides
	-- the palms that breaks the horizon line at a driver's eye height.
	if sc.tree.enabled and AssetRegistry.hasProp("desertTree") then
		local trees = Build.folder("Trees", folder)
		local t = sc.tree
		local d = t.spacingM
		while d < totalM do
			local along = d + rng:NextNumber(-t.jitterM, t.jitterM)
			local side = if rng:NextNumber() < 0.5 then -1 else 1
			local edgeM = rng:NextNumber(math.max(t.minEdgeM, vergeM + 3), t.maxEdgeM)
			if rng:NextNumber() < t.chance then
				local pos = ground(along, side * (lay.totalM / 2 + edgeM))
				if free(pos, ctx.s(4)) then
					local base = CFrame.new(pos) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)
					AssetRegistry.place("desertTree", base, rng:NextNumber(t.minScale, t.maxScale), ctx.mps, trees, cfg.shadows.palms)
				end
			end
			d += t.spacingM
		end
	end

	if sc.rock.enabled then
		local rocks = Build.folder("Rocks", folder)
		local rk = sc.rock
		local d = rk.spacingM
		while d < totalM do
			local along = d + rng:NextNumber(-rk.jitterM, rk.jitterM)
			local side = if rng:NextNumber() < 0.5 then -1 else 1
			local edgeM = rng:NextNumber(math.max(rk.minEdgeM, vergeM + 2), rk.maxEdgeM)
			if rng:NextNumber() <= density(cfg, edgeM) then
				local pos = ground(along, side * (lay.totalM / 2 + edgeM))
				if free(pos, ctx.s(rk.maxSizeM)) then
					rock(cfg, ctx, pos, rng, rocks)
				end
			end
			d += rk.spacingM
		end
	end

	if sc.debris.enabled then
		local debris = Build.folder("Debris", folder)
		local db = sc.debris
		local d = db.spacingM
		while d < totalM do
			local along = d + rng:NextNumber(-db.jitterM, db.jitterM)
			local side = if rng:NextNumber() < 0.5 then -1 else 1
			local pos = ground(along, side * (lay.totalM / 2 + rng:NextNumber(db.minEdgeM, db.maxEdgeM)))
			local size = ctx.s(rng:NextNumber(db.minSizeM, db.maxSizeM))
			if free(pos, size) then
				Build.part({
					name = "Debris",
					size = Vector3.new(size, size * 0.25, size * rng:NextNumber(0.6, 1.4)),
					cframe = CFrame.new(pos + Vector3.new(0, size * 0.1, 0)) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0),
					color = db.color,
					material = Enum.Material.Slate,
					parent = debris,
				})
			end
			d += db.spacingM
		end
	end

	-- Roadside camps: a tent, a carpet laid out in front, a few camels; and
	-- the odd camel on its own between them. Out past the verge, never in
	-- the median, never collidable.
	local af = sc.artifacts
	if af.enabled then
		local camps = Build.folder("Camps", folder)
		local arng = Build.rng(af.seed)
		local carpetDecal = AssetRegistry.decals.carpet

		local function camel(at: Vector3, facingYaw: number)
			local base = CFrame.new(at) * CFrame.Angles(0, facingYaw, 0)
			if sc.useMeshes and AssetRegistry.place("camel", base, arng:NextNumber(0.9, 1.1), ctx.mps, camps, cfg.shadows.palms) then
				return
			end
			-- Stand-in: a body and a neck. Only ever seen if the mesh fails.
			Build.part({
				name = "CamelBody",
				size = Vector3.new(ctx.s(2.2), ctx.s(1.2), ctx.s(0.9)),
				cframe = base * CFrame.new(0, ctx.s(1.5), 0),
				color = Color3.fromRGB(176, 142, 96),
				material = Enum.Material.Fabric,
				parent = camps,
			})
			Build.part({
				name = "CamelNeck",
				size = Vector3.new(ctx.s(0.5), ctx.s(1.4), ctx.s(0.45)),
				cframe = base * CFrame.new(ctx.s(1.1), ctx.s(2.4), 0) * CFrame.Angles(0, 0, math.rad(-25)),
				color = Color3.fromRGB(176, 142, 96),
				material = Enum.Material.Fabric,
				parent = camps,
			})
		end

		local function carpet(at: Vector3, yaw: number)
			local size = af.carpetSizeM
			local part = Build.part({
				name = "Carpet",
				size = Vector3.new(ctx.s(size.X), ctx.s(0.04), ctx.s(size.Y)),
				cframe = CFrame.new(at + Vector3.new(0, ctx.s(0.03), 0)) * CFrame.Angles(0, yaw, 0),
				color = Color3.fromRGB(150, 60, 50),
				material = Enum.Material.Fabric,
				parent = camps,
			})
			if carpetDecal > 0 then
				local d = Instance.new("Decal")
				d.Name = "Pattern"
				d.Face = Enum.NormalId.Top
				d.Texture = `rbxassetid://{carpetDecal}`
				d.Parent = part
			end
		end

		local d = af.campSpacingM * 0.5
		while d < totalM do
			local along = d + arng:NextNumber(-af.campJitterM, af.campJitterM)
			if arng:NextNumber() < af.campChance then
				local side = if arng:NextNumber() < 0.5 then -1 else 1
				local edgeM = arng:NextNumber(math.max(af.minEdgeM, vergeM + 6), af.maxEdgeM)
				local centre, pt = ground(along, side * (lay.totalM / 2 + edgeM))
				-- Tent faces the road; carpet in front of its door; camels
				-- loitering to one side.
				local toRoad = -pt.cframe.RightVector * side
				local yaw = math.atan2(toRoad.X, -toRoad.Z)
				if free(centre, ctx.s(6)) then
					local tentBase = CFrame.new(centre) * CFrame.Angles(0, yaw + arng:NextNumber(-0.3, 0.3), 0)
					if not (sc.useMeshes and AssetRegistry.place("tent", tentBase, arng:NextNumber(0.9, 1.15), ctx.mps, camps, cfg.shadows.palms)) then
						Build.wedge({
							name = "TentStandIn",
							size = Vector3.new(ctx.s(4.5), ctx.s(2.4), ctx.s(4)),
							cframe = tentBase * CFrame.new(0, ctx.s(1.2), 0),
							color = Color3.fromRGB(196, 176, 140),
							material = Enum.Material.Fabric,
							parent = camps,
						})
					end
					if arng:NextNumber() < af.carpetChance then
						carpet(centre + toRoad * ctx.s(4.2), yaw + arng:NextNumber(-0.4, 0.4))
					end
					local count = arng:NextInteger(af.camelsMin, af.camelsMax)
					local sideways = pt.cframe.LookVector
					for i = 1, count do
						local pos = centre
							+ sideways * ctx.s(arng:NextNumber(3, af.camelSpreadM) * (if i % 2 == 0 then 1 else -1))
							+ toRoad * ctx.s(arng:NextNumber(-2, 3))
						if free(pos, ctx.s(2.2)) then
							camel(pos, arng:NextNumber(0, math.pi * 2))
						end
					end
				end
			end
			d += af.campSpacingM
		end

		-- Strays.
		local sd = af.strayCamelSpacingM
		while sd < totalM do
			local along = sd + arng:NextNumber(-af.campJitterM, af.campJitterM)
			if arng:NextNumber() < af.strayCamelChance then
				local side = if arng:NextNumber() < 0.5 then -1 else 1
				local edgeM = arng:NextNumber(math.max(af.minEdgeM, vergeM + 4), af.maxEdgeM)
				local pos = ground(along, side * (lay.totalM / 2 + edgeM))
				if free(pos, ctx.s(2.2)) then
					camel(pos, arng:NextNumber(0, math.pi * 2))
				end
			end
			sd += af.strayCamelSpacingM
		end
	end

	-- Sand drifts on the shoulder, banked against the outer kerb: the
	-- wedge's tall face sits at the kerb and its thin edge feathers toward
	-- the road. A WedgePart's slope runs down to its -Z, so the yaw puts -Z
	-- toward the road.
	local dr = sc.drift
	if dr.enabled then
		local drifts = Build.folder("Drifts", folder)
		local drng = Build.rng(sc.seed + 41)
		local d = dr.spacingM * 0.5
		while d < totalM do
			local along = d + drng:NextNumber(-dr.jitterM, dr.jitterM)
			if drng:NextNumber() < dr.chance then
				local side = if drng:NextNumber() < 0.5 then -1 else 1
				local width = drng:NextNumber(dr.minWidthM, dr.maxWidthM)
				local height = drng:NextNumber(dr.minHeightM, dr.maxHeightM)
				local length = drng:NextNumber(dr.minLengthM, dr.maxLengthM)
				local kerbM = lay.totalM / 2 + cfg.road.shoulderWidthM
				local pos, pt = ground(along, side * (kerbM - width / 2))
				local yaw = side * math.pi / 2
				Build.wedge({
					name = "Drift",
					size = Vector3.new(ctx.s(length), ctx.s(height), ctx.s(width)),
					cframe = CFrame.new(pos + Vector3.new(0, ctx.s(height) / 2 - ctx.s(0.02), 0)) * pt.cframe.Rotation * CFrame.Angles(0, yaw, 0),
					color = dr.color,
					material = Enum.Material.Sand,
					parent = drifts,
				})
			end
			d += dr.spacingM
		end
	end

	local dn = cfg.ground.dunes
	if dn.enabled then
		local dunes = Build.folder("Dunes", folder)
		local drng = Build.rng(dn.seed)
		local d = 0
		while d < totalM do
			local along = d + drng:NextNumber(-dn.jitterM, dn.jitterM)
			for _, side in { -1, 1 } do
				local edgeM = drng:NextNumber(dn.minEdgeM, dn.maxEdgeM)
				local pos = ground(along, side * (lay.totalM / 2 + edgeM))
				if not onStation(pos) then
					dune(cfg, ctx, pos, drng, dunes)
				end
			end
			d += dn.spacingM
		end
	end

	return folder
end

return Scatter
