--!strict
-- Palms, rocks and roadside debris, placed by rule from a seeded random so
-- every server grows the same desert.
--
-- Palms go in loose clumps of two or three rather than at an even spacing,
-- because evenly spaced trees read as generated and clumped ones read as
-- planted. Everything else is jittered around a nominal spacing with a
-- density that falls off as you get further from the road, so the near
-- shoulder looks maintained and the far desert looks empty.
--
-- Nothing here is collidable and nothing is inside the barrier line.
local WorldConfig = require(script.Parent.WorldConfig)
local Build = require(script.Parent.Build)
local RoadNetwork = require(script.Parent.RoadNetwork)
local AssetRegistry = require(script.Parent.AssetRegistry)

type Config = WorldConfig.Config
type Context = RoadNetwork.Context
type Path = RoadNetwork.Path

local Scatter = {}

-- 1 near the road, falling to 0 at falloffEndM. Callers roll against it.
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

-- Primitive date palm: a leaning trunk with fronds fanned off the top. Swaps
-- for a MeshPart the moment AssetRegistry has an approved id.
local function palm(cfg: Config, ctx: Context, at: Vector3, rng: Random, parent: Instance, scale: number)
	local p = cfg.scatter.palm
	local mesh = AssetRegistry.createMesh("datePalm")
	if mesh then
		mesh.Name = "Palm"
		mesh.Anchored = true
		mesh.CanCollide = false
		mesh.CanQuery = false
		mesh.CanTouch = false
		mesh.CastShadow = false
		local h = ctx.s(p.trunkHeightM * scale)
		mesh.Size = Vector3.new(h * 0.6, h, h * 0.6)
		mesh.CFrame = CFrame.new(at + Vector3.new(0, h / 2, 0)) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)
		mesh.Parent = parent
		return
	end

	local trunkH = ctx.s(p.trunkHeightM * scale)
	local trunkW = ctx.s(p.trunkWidthM * scale)
	local maxLean = p.leanMaxRad
	local lean = CFrame.Angles(rng:NextNumber(-maxLean, maxLean), rng:NextNumber(0, math.pi * 2), rng:NextNumber(-maxLean, maxLean))
	local baseCf = CFrame.new(at) * lean
	Build.part({
		name = "PalmTrunk",
		size = Vector3.new(trunkW, trunkH, trunkW),
		cframe = baseCf * CFrame.new(0, trunkH / 2, 0),
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
			cframe = baseCf
				* CFrame.new(0, trunkH, 0)
				* CFrame.Angles(0, yaw, 0)
				* CFrame.Angles(-droop, 0, 0)
				* CFrame.new(0, 0, -frondLen / 2),
			color = p.frondColor,
			material = Enum.Material.Grass,
			parent = parent,
			castShadow = cfg.shadows.palms,
		})
	end
end

function Scatter.build(cfg: Config, ctx: Context, path: Path, parent: Instance): Folder
	local sc = cfg.scatter
	local folder = Build.folder("Scatter", parent)
	local totalM = RoadNetwork.lengthM(path)
	local rng = Build.rng(sc.seed)
	-- Barrier line: nothing is ever placed inside it.
	local barrierEdgeM = cfg.road.shoulderWidthM + cfg.road.kerbWidthM + cfg.barriers.offsetM + cfg.barriers.baseWidthM

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

	-- Palms, in clumps.
	if sc.palm.enabled then
		local palms = Build.folder("Palms", folder)
		local p = sc.palm
		local d = p.clumpSpacingM
		while d < totalM do
			local at = RoadNetwork.sample(path, math.clamp(d + rng:NextNumber(-p.clumpJitterM, p.clumpJitterM), 0, totalM))
			local side = if rng:NextNumber() < 0.5 then -1 else 1
			local edgeM = rng:NextNumber(math.max(p.minEdgeM, barrierEdgeM + 2), p.maxEdgeM)
			if rng:NextNumber() <= density(cfg, edgeM) then
				local centre = at.position + at.cframe.RightVector * (side * (at.halfWidth + ctx.s(edgeM)))
				for _ = 1, rng:NextInteger(p.minPerClump, p.maxPerClump) do
					local jitter = Vector3.new(
						rng:NextNumber(-ctx.s(p.spreadM), ctx.s(p.spreadM)),
						0,
						rng:NextNumber(-ctx.s(p.spreadM), ctx.s(p.spreadM))
					)
					local pos = centre + jitter
					if free(pos, ctx.s(2.5)) then
						palm(cfg, ctx, pos, rng, palms, rng:NextNumber(0.75, 1.15))
					end
				end
			end
			d += p.clumpSpacingM
		end
	end

	-- Rocks.
	if sc.rock.enabled then
		local rocks = Build.folder("Rocks", folder)
		local rk = sc.rock
		local d = rk.spacingM
		while d < totalM do
			local at = RoadNetwork.sample(path, math.clamp(d + rng:NextNumber(-rk.jitterM, rk.jitterM), 0, totalM))
			local side = if rng:NextNumber() < 0.5 then -1 else 1
			local edgeM = rng:NextNumber(math.max(rk.minEdgeM, barrierEdgeM + 2), rk.maxEdgeM)
			if rng:NextNumber() <= density(cfg, edgeM) then
				local pos = at.position + at.cframe.RightVector * (side * (at.halfWidth + ctx.s(edgeM)))
				local size = ctx.s(rng:NextNumber(rk.minSizeM, rk.maxSizeM))
				if free(pos, size) then
					local mesh = AssetRegistry.createMesh("desertRock")
					if mesh then
						mesh.Name = "Rock"
						mesh.Anchored = true
						mesh.CanCollide = false
						mesh.CanQuery = false
						mesh.CanTouch = false
						mesh.CastShadow = false
						mesh.Size = Vector3.new(size, size * 0.8, size)
						mesh.CFrame = CFrame.new(pos + Vector3.new(0, size * 0.3, 0))
							* CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)
						mesh.Parent = rocks
					else
						Build.part({
							name = "Rock",
							size = Vector3.new(size, size * rng:NextNumber(0.5, 0.9), size * rng:NextNumber(0.7, 1.2)),
							cframe = CFrame.new(pos + Vector3.new(0, size * 0.25, 0))
								* CFrame.Angles(
									rng:NextNumber(-0.3, 0.3),
									rng:NextNumber(0, math.pi * 2),
									rng:NextNumber(-0.3, 0.3)
								),
							color = rk.color,
							material = Enum.Material.Rock,
							parent = rocks,
							castShadow = cfg.shadows.rocks,
						})
					end
				end
			end
			d += rk.spacingM
		end
	end

	-- Debris close to the shoulder: small, flat, and sparse.
	if sc.debris.enabled then
		local debris = Build.folder("Debris", folder)
		local db = sc.debris
		local d = db.spacingM
		while d < totalM do
			local at = RoadNetwork.sample(path, math.clamp(d + rng:NextNumber(-db.jitterM, db.jitterM), 0, totalM))
			local side = if rng:NextNumber() < 0.5 then -1 else 1
			local edgeM = rng:NextNumber(db.minEdgeM, db.maxEdgeM)
			local pos = at.position + at.cframe.RightVector * (side * (at.halfWidth + ctx.s(edgeM)))
			local size = ctx.s(rng:NextNumber(db.minSizeM, db.maxSizeM))
			if free(pos, size) then
				Build.part({
					name = "Debris",
					size = Vector3.new(size, size * 0.25, size * rng:NextNumber(0.6, 1.4)),
					cframe = CFrame.new(pos + Vector3.new(0, size * 0.1, 0))
						* CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0),
					color = db.color,
					material = Enum.Material.Slate,
					parent = debris,
				})
			end
			d += db.spacingM
		end
	end

	return folder
end

return Scatter
