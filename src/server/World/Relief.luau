--!strict
-- The near desert and the edge of the world, as one continuous surface.
--
-- A strip of smooth terrain runs either side of the road. It carries the
-- whole cross-section from one height function: the desert floor from just
-- past the verge, the berm rising out of that floor to a crest the car can
-- drive up, and a back slope down to the sand plane again. Because it is one
-- function there is no seam in it anywhere. The berm used to be a separate
-- stack of wedges and boxes sitting on the plane, and every one of its cut
-- edges showed.
--
-- Terrain is the right tool here and nowhere else in the world: it only
-- reaches the client inside the streaming radius, and this strip is the one
-- piece of sand the car is ever near. It all collides, at real slopes, so
-- running wide feels like sand. The only part in the module is the invisible
-- wall on the crest, which is built from the same crest number the terrain
-- uses, so it can never drift off the top.
--
-- Cost is kept down two ways: the sand is a shell a few metres thick rather
-- than solid down to the plane (nothing digs), and each chunk writes only
-- the vertical band its own surface occupies.
local Workspace = game:GetService("Workspace")
local WorldConfig = require(script.Parent.WorldConfig)
local Build = require(script.Parent.Build)
local RoadNetwork = require(script.Parent.RoadNetwork)
local AssetRegistry = require(script.Parent.AssetRegistry)
local Dunes = require(script.Parent.Dunes)

type Config = WorldConfig.Config
type Context = RoadNetwork.Context
type Path = RoadNetwork.Path
type PathPoint = RoadNetwork.PathPoint

local Relief = {}

-- Roblox terrain is a 4-stud voxel grid; this is not a tunable.
local VOXEL = 4

type Hummock = { x: number, z: number, r: number, h: number }

-- 0 at t<=0, 1 at t>=1, flat at both ends. The berm's rise and its back
-- slope are both this curve, which is why neither has a kink.
local function smoothstep(t: number): number
	if t <= 0 then
		return 0
	elseif t >= 1 then
		return 1
	end
	return t * t * (3 - 2 * t)
end

function Relief.build(cfg: Config, ctx: Context, path: Path, parent: Instance): (number, number, number)
	local r = cfg.relief
	local b = r.berm
	local terrain = Workspace.Terrain
	terrain:SetMaterialColor(Enum.Material.Sand, r.sandColor)
	terrain:SetMaterialColor(r.gravel.material, r.gravelColor)

	local rng = Build.rng(r.seed)
	local totalM = RoadNetwork.lengthM(path)
	local groundY = ctx.surfaceY - ctx.s(cfg.ground.dropM)
	local sunSide = Dunes.sideSign(cfg, path)
	local bermEndM = math.min(b.endM, totalM)

	-- Everything below is in studs unless it ends in M.
	local lift = ctx.s(r.liftM)
	local shell = ctx.s(r.shellM)
	local innerGap = ctx.s(r.innerGapM)
	local feather = ctx.s(r.featherM)
	local swellScale, rippleScale = ctx.s(r.swellWavelengthM), ctx.s(r.rippleWavelengthM)
	local swellAmp, rippleAmp = ctx.s(r.swellAmplitudeM), ctx.s(r.rippleAmplitudeM)
	local gravelScale = ctx.s(r.gravel.scaleM)
	local seedA, seedB, seedC = (r.seed % 101) / 3, (r.seed % 211) / 5, (r.seed % 307) / 7
	local seedD, seedE = (r.seed % 401) / 11, (r.seed % 499) / 13

	-- The berm profile for a side, in studs. The sun side is farther out,
	-- lower and gentler so the sunset stays in view over it.
	type Profile = { foot: number, rise: number, crest: number, back: number, reach: number }
	local function profileFor(side: number): Profile
		local p = if side == sunSide then b.sun else b.other
		local foot, rise, back = ctx.s(p.footM), ctx.s(p.riseWidthM), ctx.s(p.backWidthM)
		return { foot = foot, rise = rise, crest = ctx.s(p.crestHeightM), back = back, reach = foot + rise + back }
	end
	local profile = { [-1] = profileFor(-1), [1] = profileFor(1) }
	local wanderScale = ctx.s(b.wanderWavelengthM)
	local footJitter = ctx.s(b.footJitterM)

	-- Hummocks on the floor, placed first so a chunk can ask which ones
	-- touch it. Never on the berm: they would read as lumps on a dune face.
	local hummocks: { Hummock } = {}
	local hm = r.hummocks
	for _ = 1, math.floor(totalM / 1000 * hm.perKm) do
		for _, side in { -1, 1 } do
			local p = RoadNetwork.sample(path, rng:NextNumber(0, totalM))
			local radius = ctx.s(rng:NextNumber(hm.minRadiusM, hm.maxRadiusM))
			local inner = p.halfWidth + innerGap + radius
			local outer = profile[side].foot - footJitter - radius
			if outer > inner then
				local pos = p.position + p.cframe.RightVector * (side * rng:NextNumber(inner, outer))
				table.insert(hummocks, { x = pos.X, z = pos.Z, r = radius, h = ctx.s(rng:NextNumber(hm.minHeightM, hm.maxHeightM)) })
			end
		end
	end

	-- World bounding box of the strip.
	local reach = math.max(profile[-1].reach, profile[1].reach)
	local minX, maxX, minZ, maxZ = math.huge, -math.huge, math.huge, -math.huge
	for _, p in path do
		minX, maxX = math.min(minX, p.position.X - reach), math.max(maxX, p.position.X + reach)
		minZ, maxZ = math.min(minZ, p.position.Z - reach), math.max(maxZ, p.position.Z + reach)
	end

	local chunk = r.chunkStuds
	local n = chunk // VOXEL
	local chunks = 0
	local surfaces = table.create(n) -- reused per chunk: [ix][iz] = surface Y, or -math.huge
	local mats = table.create(n)
	for ix = 1, n do
		surfaces[ix] = table.create(n)
		mats[ix] = table.create(n)
	end

	local cx = math.floor(minX / chunk) * chunk
	while cx < maxX do
		local cz = math.floor(minZ / chunk) * chunk
		while cz < maxZ do
			-- Path points this chunk could be nearest to. Scanning only
			-- these per column keeps the lateral distance exact through a
			-- curve, where one frame for the whole chunk would step.
			local candidates: { PathPoint } = {}
			local span = chunk * 0.71 + reach
			local ccx, ccz = cx + chunk / 2, cz + chunk / 2
			for _, p in path do
				local dx, dz = p.position.X - ccx, p.position.Z - ccz
				if dx * dx + dz * dz < span * span then
					table.insert(candidates, p)
				end
			end

			local lo, hi = math.huge, -math.huge
			if #candidates > 0 then
				local touching: { Hummock } = {}
				for _, h in hummocks do
					if h.x + h.r > cx and h.x - h.r < cx + chunk and h.z + h.r > cz and h.z - h.r < cz + chunk then
						table.insert(touching, h)
					end
				end

				for ix = 1, n do
					local wx = cx + (ix - 0.5) * VOXEL
					local srow, mrow = surfaces[ix], mats[ix]
					for iz = 1, n do
						local wz = cz + (iz - 0.5) * VOXEL
						local best, bestD = candidates[1], math.huge
						for _, p in candidates do
							local dx, dz = p.position.X - wx, p.position.Z - wz
							local d = dx * dx + dz * dz
							if d < bestD then
								best, bestD = p, d
							end
						end
						local relX, relZ = wx - best.position.X, wz - best.position.Z
						local right, look = best.cframe.RightVector, best.cframe.LookVector
						local lateral = relX * right.X + relZ * right.Z
						local side = if lateral >= 0 then 1 else -1
						local latAbs = math.abs(lateral)
						local inner = best.halfWidth + innerGap
						local prof = profile[side]

						-- The berm's foot and crest height wander along the
						-- road, so the crest is a dune line, not a ramp.
						local along = best.distanceM + (relX * look.X + relZ * look.Z) * ctx.mps
						local foot, crest = prof.foot, prof.crest
						if b.enabled and along > 0 and along < bermEndM then
							foot += math.noise(along / wanderScale, side * 7.3, seedD) * 2 * footJitter
							crest *= 1 + math.noise(along / (wanderScale * 0.6), side * 19.7, seedE) * 2 * b.heightVariation
						else
							crest = 0
						end
						local outer = foot + prof.rise + prof.back

						local surface = -math.huge
						local material = Enum.Material.Sand
						if latAbs > inner and latAbs < outer then
							local floor = lift
								+ math.noise(wx / swellScale, wz / swellScale, seedA) * swellAmp
								+ math.noise(wx / rippleScale, wz / rippleScale, seedB) * rippleAmp
							for _, h in touching do
								local dx, dz = wx - h.x, wz - h.z
								local d2 = dx * dx + dz * dz
								if d2 < h.r * h.r then
									local t = 1 - d2 / (h.r * h.r)
									floor += h.h * t * t
								end
							end
							-- The berm, out of the same floor.
							local d = latAbs - foot
							local rise = 0
							if d > 0 and d <= prof.rise then
								rise = crest * smoothstep(d / prof.rise)
							elseif d > prof.rise then
								rise = crest * (1 - smoothstep((d - prof.rise) / prof.back))
							end
							-- Both edges of the strip sink under the plane,
							-- so it has no rim.
							local edge = math.min(latAbs - inner, outer - latAbs)
							local f = math.clamp(edge / feather, 0, 1)
							surface = groundY - VOXEL * 0.25 + (floor + rise + VOXEL * 0.25) * f
							if math.noise(wx / gravelScale, wz / gravelScale, seedC) > r.gravel.threshold then
								material = r.gravel.material
							end
							lo, hi = math.min(lo, surface), math.max(hi, surface)
						end
						srow[iz] = surface
						mrow[iz] = material
					end
				end
			end

			if hi > -math.huge then
				local yLo = math.floor((lo - shell) / VOXEL) * VOXEL
				local yHi = math.ceil((hi + VOXEL) / VOXEL) * VOXEL
				local ny = (yHi - yLo) // VOXEL
				local materials, occupancy = table.create(n), table.create(n)
				for ix = 1, n do
					local mCol, oCol = table.create(ny), table.create(ny)
					for iy = 1, ny do
						mCol[iy], oCol[iy] = table.create(n), table.create(n)
					end
					local srow, mrow = surfaces[ix], mats[ix]
					for iz = 1, n do
						local surface, material = srow[iz], mrow[iz]
						for iy = 1, ny do
							local bottom = yLo + (iy - 1) * VOXEL
							local occ = math.clamp((surface - bottom) / VOXEL, 0, 1)
							oCol[iy][iz] = occ
							mCol[iy][iz] = if occ > 0 then material else Enum.Material.Air
						end
					end
					materials[ix], occupancy[ix] = mCol, oCol
				end
				terrain:WriteVoxels(Region3.new(Vector3.new(cx, yLo, cz), Vector3.new(cx + chunk, yHi, cz + chunk)), VOXEL, materials, occupancy)
				chunks += 1
			end
			cz += chunk
		end
		cx += chunk
	end

	-- Voxels written this frame are not raycastable until the next one, and
	-- the tufts below and Scatter after us both sit props on the surface.
	task.wait()

	local folder = Build.folder("Relief", parent)

	-- The invisible stop, on the crest the terrain just built. It is
	-- queryable: a colliding part with CanQuery off is not honoured
	-- reliably, and nothing else raycasts out here.
	local walls = 0
	if b.enabled then
		for _, side in { -1, 1 } do
			local prof = profile[side]
			local crestM = (prof.foot + prof.rise) * ctx.mps
			RoadNetwork.ribbon({
				name = "BermWall",
				parent = folder,
				path = path,
				ctx = ctx,
				offsetM = 0,
				widthM = 1,
				heightM = 1,
				yM = 0,
				color = r.sandColor,
				toM = bermEndM,
				runCapM = b.wallRunCapM,
				emit = function(cf: CFrame, length: number)
					Build.part({
						name = "BermWall",
						size = Vector3.new(ctx.s(1), ctx.s(b.wallHeightM), length),
						cframe = cf * CFrame.new(side * ctx.s(crestM), groundY - cf.Y + ctx.s(b.wallHeightM) / 2, 0),
						color = r.sandColor,
						parent = folder,
						collide = true,
						query = true,
						transparency = 1,
					})
					walls += 1
				end,
			})
		end
	end

	-- Scrub tufts on the hummocks: a nabkha is a bush that caught sand.
	local tufts = 0
	if AssetRegistry.hasProp("scrub") then
		local sc = cfg.scatter.scrub
		for _, h in hummocks do
			if rng:NextNumber() < hm.scrubChance then
				local top = Relief.surfaceY(Vector3.new(h.x, groundY, h.z)) or (groundY + lift + h.h)
				local base = CFrame.new(h.x, top, h.z) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)
				local bush = AssetRegistry.place("scrub", base, rng:NextNumber(sc.minSizeM, sc.maxSizeM) / 2, ctx.mps, folder, false)
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

	return chunks, tufts, walls
end

-- Height of the terrain surface under a position, or nil off the strip.
-- Scatter uses it to sit props on the relief instead of the plane.
local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Include
params.FilterDescendantsInstances = { Workspace.Terrain }
function Relief.surfaceY(pos: Vector3): number?
	local hit = Workspace:Raycast(pos + Vector3.new(0, 60, 0), Vector3.new(0, -120, 0), params)
	return if hit then hit.Position.Y else nil
end

return Relief
