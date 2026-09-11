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
		local model = AssetRegistry.place("scrub", base, size / 2, ctx.mps, parent, false)
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
	local sink = height * 0.25
	for _, side in { -1, 1 } do
		Build.wedge({
			name = "Dune",
			size = Vector3.new(length, height, width / 2),
			cframe = base * CFrame.new(0, height / 2 - sink, side * width / 4) * CFrame.Angles(0, if side > 0 then 0 else math.pi, 0),
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
	local function free(pos: Vector3, radius: number): boolean
		for _, t in taken do
			if (t - pos).Magnitude < radius then
				return false
			end
		end
		table.insert(taken, pos)
		return true
	end

	-- Position on the ground at (distance along, lateral metres from the centreline).
	local function ground(d: number, lateralM: number): (Vector3, RoadNetwork.PathPoint)
		local p = RoadNetwork.sample(path, math.clamp(d, 0, totalM))
		return p.position + p.cframe.RightVector * ctx.s(lateralM), p
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
				local count = rng:NextInteger(p.minPerClump, p.maxPerClump + 1)
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
				local pos = ground(along, side * (lay.totalM / 2 + edgeM))
				if free(pos, ctx.s(1.2)) then
					scrub(cfg, ctx, pos, rng, bushes)
				end
			end
			-- Sparse low scrub between the median palms.
			if rng:NextNumber() < s.medianChance then
				local half = lay.medianM / 2 - p.medianMarginM
				local pos = ground(along + rng:NextNumber(-6, 6), rng:NextNumber(-half, half))
				if free(pos, ctx.s(1.2)) then
					scrub(cfg, ctx, pos, rng, bushes)
				end
			end
			d += s.spacingM
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
				dune(cfg, ctx, pos, drng, dunes)
			end
			d += dn.spacingM
		end
	end

	return folder
end

return Scatter
