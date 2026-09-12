--!strict
-- The near desert floor: a strip of smooth terrain either side of the road,
-- from just past the verge to the berm's foot, with the gentle undulation a
-- real desert floor has. Terrain is the right tool here and nowhere else in
-- the world: it only reaches the client inside the streaming radius, and
-- this strip is the one piece of sand the car is always near.
--
-- The strip is written as a heightfield in 4-stud voxels: a base lift over
-- the sand plane so the plane never shows through, two octaves of noise for
-- swells and ripples, small hummocks (with a scrub tuft on many, which is a
-- nabkha), and patches of a darker gravel material from a third noise so the
-- floor is not one colour. Everything collides, at real slopes of a few
-- degrees, so running wide feels like sand and not like a floor. Scatter
-- snaps its props to this surface afterwards.
local Workspace = game:GetService("Workspace")
local WorldConfig = require(script.Parent.WorldConfig)
local Build = require(script.Parent.Build)
local RoadNetwork = require(script.Parent.RoadNetwork)
local AssetRegistry = require(script.Parent.AssetRegistry)
local Dunes = require(script.Parent.Dunes)

type Config = WorldConfig.Config
type Context = RoadNetwork.Context
type Path = RoadNetwork.Path

local Relief = {}

local VOXEL = 4

type Hummock = { x: number, z: number, r: number, h: number }

-- Berm foot on a side, or the configured outer edge if the berm is off.
local function outerM(cfg: Config, path: Path, side: number): number
	local r = cfg.relief
	if cfg.berm.enabled then
		local prof = if side == Dunes.sideSign(cfg, path) then cfg.berm.sun else cfg.berm.other
		return prof.footM - r.outerMarginM
	end
	return r.outerM
end

function Relief.build(cfg: Config, ctx: Context, path: Path, parent: Instance): (number, number)
	local r = cfg.relief
	local terrain = Workspace.Terrain
	terrain:SetMaterialColor(Enum.Material.Sand, r.sandColor)
	terrain:SetMaterialColor(r.gravel.material, r.gravelColor)

	local rng = Build.rng(r.seed)
	local totalM = RoadNetwork.lengthM(path)
	local groundY = ctx.surfaceY - ctx.s(cfg.ground.dropM)
	local lift = ctx.s(r.liftM)
	local depth = ctx.s(r.depthM)
	local outer = { [-1] = ctx.s(outerM(cfg, path, -1)), [1] = ctx.s(outerM(cfg, path, 1)) }
	local innerGap = ctx.s(r.innerGapM)

	-- Hummocks, placed first so each chunk can ask which ones touch it.
	local hummocks: { Hummock } = {}
	local hm = r.hummocks
	local count = math.floor(totalM / 1000 * hm.perKm)
	for _ = 1, count do
		for _, side in { -1, 1 } do
			local along = rng:NextNumber(0, totalM)
			local p = RoadNetwork.sample(path, along)
			local radius = ctx.s(rng:NextNumber(hm.minRadiusM, hm.maxRadiusM))
			local inner = p.halfWidth + innerGap
			local lateral = rng:NextNumber(inner + radius, outer[side] - radius)
			local pos = p.position + p.cframe.RightVector * (side * lateral)
			table.insert(hummocks, { x = pos.X, z = pos.Z, r = radius, h = ctx.s(rng:NextNumber(hm.minHeightM, hm.maxHeightM)) })
		end
	end

	-- Bounding box of the strip, in world space.
	local minX, maxX, minZ, maxZ = math.huge, -math.huge, math.huge, -math.huge
	local reach = math.max(outer[-1], outer[1])
	for _, p in path do
		minX = math.min(minX, p.position.X - reach)
		maxX = math.max(maxX, p.position.X + reach)
		minZ = math.min(minZ, p.position.Z - reach)
		maxZ = math.max(maxZ, p.position.Z + reach)
	end
	local chunk = r.chunkStuds
	local yLo = math.floor((groundY - depth) / VOXEL) * VOXEL
	local yHi = math.ceil((groundY + lift + ctx.s(r.swellAmplitudeM + r.rippleAmplitudeM + hm.maxHeightM) + VOXEL) / VOXEL) * VOXEL
	local ny = (yHi - yLo) / VOXEL
	local n = chunk / VOXEL

	local swellScale = ctx.s(r.swellWavelengthM)
	local rippleScale = ctx.s(r.rippleWavelengthM)
	local swellAmp = ctx.s(r.swellAmplitudeM)
	local rippleAmp = ctx.s(r.rippleAmplitudeM)
	local gravelScale = ctx.s(r.gravel.scaleM)
	local seedA, seedB, seedC = (r.seed % 101) / 3, (r.seed % 211) / 5, (r.seed % 307) / 7

	-- Nearest path point to a world position: used once per chunk.
	local function nearest(x: number, z: number): RoadNetwork.PathPoint
		local best = path[1]
		local bestD = math.huge
		for _, p in path do
			local dx, dz = p.position.X - x, p.position.Z - z
			local d = dx * dx + dz * dz
			if d < bestD then
				best, bestD = p, d
			end
		end
		return best
	end

	local chunks = 0
	local x0 = math.floor(minX / chunk) * chunk
	local z0 = math.floor(minZ / chunk) * chunk
	local cx = x0
	while cx < maxX do
		local cz = z0
		while cz < maxZ do
			local mid = Vector3.new(cx + chunk / 2, 0, cz + chunk / 2)
			local p = nearest(mid.X, mid.Z)
			local rel = mid - p.position
			local lateralMid = rel:Dot(p.cframe.RightVector)
			local side = if lateralMid >= 0 then 1 else -1
			local inner = p.halfWidth + innerGap
			local half = chunk * 0.71
			if math.abs(lateralMid) + half > inner and math.abs(lateralMid) - half < outer[side] then
				-- Hummocks touching this chunk.
				local local_h: { Hummock } = {}
				for _, h in hummocks do
					if h.x + h.r > cx and h.x - h.r < cx + chunk and h.z + h.r > cz and h.z - h.r < cz + chunk then
						table.insert(local_h, h)
					end
				end
				local materials = table.create(n)
				local occupancy = table.create(n)
				local any = false
				for ix = 1, n do
					local mCol = table.create(ny)
					local oCol = table.create(ny)
					local wx = cx + (ix - 0.5) * VOXEL
					for iy = 1, ny do
						mCol[iy] = table.create(n)
						oCol[iy] = table.create(n)
					end
					for iz = 1, n do
						local wz = cz + (iz - 0.5) * VOXEL
						local relc = Vector3.new(wx - p.position.X, 0, wz - p.position.Z)
						local lateral = math.abs(relc:Dot(p.cframe.RightVector))
						local surface = -math.huge
						local material = Enum.Material.Sand
						if lateral > inner and lateral < outer[side] then
							local s = groundY + lift
								+ math.noise(wx / swellScale, wz / swellScale, seedA) * swellAmp
								+ math.noise(wx / rippleScale, wz / rippleScale, seedB) * rippleAmp
							for _, h in local_h do
								local dx, dz = wx - h.x, wz - h.z
								local d2 = dx * dx + dz * dz
								if d2 < h.r * h.r then
									local t = 1 - d2 / (h.r * h.r)
									s += h.h * t * t
								end
							end
							-- Feather the strip's edges down to the plane so
							-- there is no step at the verge or the berm foot.
							local edge = math.min(lateral - inner, outer[side] - lateral)
							local feather = math.clamp(edge / ctx.s(r.featherM), 0, 1)
							surface = groundY - VOXEL * 0.25 + (s - groundY + VOXEL * 0.25) * feather
							if math.noise(wx / gravelScale, wz / gravelScale, seedC) > r.gravel.threshold then
								material = r.gravel.material
							end
							any = true
						end
						for iy = 1, ny do
							local bottom = yLo + (iy - 1) * VOXEL
							local occ = math.clamp((surface - bottom) / VOXEL, 0, 1)
							oCol[iy][iz] = occ
							mCol[iy][iz] = if occ > 0 then material else Enum.Material.Air
						end
					end
					materials[ix] = mCol
					occupancy[ix] = oCol
				end
				if any then
					local region = Region3.new(Vector3.new(cx, yLo, cz), Vector3.new(cx + chunk, yHi, cz + chunk))
					terrain:WriteVoxels(region, VOXEL, materials, occupancy)
					chunks += 1
				end
			end
			cz += chunk
		end
		cx += chunk
	end

	-- Voxels written this frame are not raycastable until the next one, and
	-- the tufts below and Scatter after us both sit props on the surface.
	task.wait()

	-- Scrub tufts on the hummocks: a nabkha is a bush that caught sand.
	local tufts = 0
	local folder = Build.folder("Nabkha", parent)
	if AssetRegistry.hasProp("scrub") then
		local sc = cfg.scatter.scrub
		for _, h in hummocks do
			if rng:NextNumber() < hm.scrubChance then
				local top = Relief.surfaceY(Vector3.new(h.x, groundY, h.z)) or (groundY + lift + h.h)
				local base = CFrame.new(h.x, top, h.z) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)
				local size = rng:NextNumber(sc.minSizeM, sc.maxSizeM)
				local bush = AssetRegistry.place("scrub", base, size / 2, ctx.mps, folder, false)
				if bush then
					local t = rng:NextNumber(-sc.colorVariation, sc.colorVariation)
					local color = if t < 0 then sc.color:Lerp(Color3.new(0, 0, 0), -t) else sc.color:Lerp(Color3.new(1, 1, 1), t)
					for _, part in bush:GetChildren() do
						if part:IsA("BasePart") then
							part.Color = color
						end
					end
					tufts += 1
				end
			end
		end
	end
	return chunks, tufts
end

-- Height of the terrain surface under a position, or nil off the strip.
-- Scatter uses it to sit props on the relief instead of the plane.
local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Include
params.FilterDescendantsInstances = { Workspace.Terrain }
function Relief.surfaceY(pos: Vector3): number?
	local hit = Workspace:Raycast(pos + Vector3.new(0, 40, 0), Vector3.new(0, -80, 0), params)
	return if hit then hit.Position.Y else nil
end

return Relief
