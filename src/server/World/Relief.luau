--!strict
-- The near desert and the edge of the world, as one continuous surface.
--
-- A strip of smooth terrain runs either side of the road. It carries the
-- whole cross-section from one height function: the desert floor from just
-- past the shoulder, the border dune rising out of that floor to a crest the
-- car can drive up, and the dune's slip face down to the sand plane again.
-- Because it is one function there is no seam in it anywhere.
--
-- The border is a dune line, not a berm: a gentle windward slope toward the
-- road, a sharp brink, a steep slip face behind, humps and saddles along it
-- and a foot that wanders in and out. It bends out round the spawn pad and
-- the petrol station, closes across behind the start line and sinks away
-- before the city. Its shape along the road is worked out once into a
-- lookup (Relief.border), which the terrain, the crest wall and Scatter all
-- read, so they always agree.
--
-- Terrain is the right tool here and nowhere else in the world: it only
-- reaches the client inside the streaming radius, and this strip is the one
-- piece of sand the car is ever near. It all collides, at real slopes, so
-- running wide feels like sand. The only parts in the module are the
-- invisible wall on the crest and the scrub on the hummocks.
--
-- Cost is kept down two ways: the sand is a shell a few metres thick rather
-- than solid down to the plane (nothing digs), and each chunk writes only
-- the vertical band its own surface occupies.
local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")
local MaterialService = game:GetService("MaterialService")
local WorldConfig = require(script.Parent.WorldConfig)
local Build = require(script.Parent.Build)
local RoadNetwork = require(script.Parent.RoadNetwork)
local AssetRegistry = require(script.Parent.AssetRegistry)
local Dunes = require(script.Parent.Dunes)
local Station = require(script.Parent.Station)
local Materials = require(script.Parent.Materials)

type Config = WorldConfig.Config
type Context = RoadNetwork.Context
type Path = RoadNetwork.Path
type PathPoint = RoadNetwork.PathPoint

local Relief = {}

-- Roblox terrain is a 4-stud voxel grid; this is not a tunable.
local VOXEL = 4
-- The border's along-road lookup resolution, metres.
local STEP = 5

type Hummock = { x: number, z: number, r: number, h: number }

-- 0 at t<=0, 1 at t>=1, flat at both ends.
local function smoothstep(t: number): number
	if t <= 0 then
		return 0
	elseif t >= 1 then
		return 1
	end
	return t * t * (3 - 2 * t)
end

-- Metres along the road (extrapolated straight past either end) and signed
-- lateral metres (+ is the road's right) of a world position.
function Relief.roadCoords(ctx: Context, path: Path, pos: Vector3): (number, number)
	local best = path[1]
	local bestDist = math.huge
	for _, p in path do
		local dx, dz = pos.X - p.position.X, pos.Z - p.position.Z
		local d = dx * dx + dz * dz
		if d < bestDist then
			best, bestDist = p, d
		end
	end
	local rel = pos - best.position
	return best.distanceM + rel:Dot(best.cframe.LookVector) * ctx.mps, rel:Dot(best.cframe.RightVector) * ctx.mps
end

export type Border = {
	enabled: boolean,
	-- For a side (+1 right, -1 left) and metres along the road: the dune's
	-- foot from the centreline and its crest height, in metres.
	at: (side: number, alongM: number) -> (number, number),
	riseM: { [number]: number }, -- windward slope width per side
	backM: { [number]: number }, -- slip face width per side
	capBehindM: number,
	endM: number,
	maxReachM: number, -- farthest foot + rise + back anywhere
	-- The fence (WorldConfig.fence): its distance from the centreline for a
	-- side and metres along the road, and where it runs.
	fenceEnabled: boolean,
	fenceAt: (side: number, alongM: number) -> number,
	fenceBehindM: number,
	fenceEndM: number,
}

local borders: { [Path]: Border } = {}

-- The border's shape, worked out once per path.
function Relief.border(cfg: Config, ctx: Context, path: Path): Border
	local cached = borders[path]
	if cached then
		return cached
	end
	local r = cfg.relief
	local b = r.berm
	local totalM = RoadNetwork.lengthM(path)
	local sunSide = Dunes.sideSign(cfg, path)
	local endM = math.min(b.endM, totalM)
	local startM = -(b.startCapBehindM + math.max(b.sun.riseWidthM, b.other.riseWidthM) + math.max(b.sun.backWidthM, b.other.backWidthM) + 20)
	local count = math.floor((endM - startM) / STEP) + 2
	local seed = r.seed
	local seedFoot, seedHump, seedDetail = (seed % 401) / 11, (seed % 499) / 13, (seed % 613) / 17
	local seedWobble = (seed % 719) / 19

	-- What the dunes must stand back from: the pad's wings (both sides)
	-- and the station's site (whichever side it is on), found by probing
	-- the station's own keep-out rectangle outward from the road.
	local preset = cfg.presets[cfg.preset] :: any
	local pad = preset.pad
	local onStation = Station.keepOut(cfg, ctx, path)
	-- How far from the centreline something stands at this spot (0 for
	-- nothing): the pad's wing, the station's site.
	local function siteExtent(side: number, along: number, withPad: boolean): number
		local need = 0
		if withPad and pad and pad.widthM > 0 and along >= pad.startM and along <= pad.startM + pad.lengthM then
			need = pad.widthM / 2
		end
		if cfg.station.enabled and along >= 0 and along <= totalM then
			local p = RoadNetwork.sample(path, along)
			local lat = 40
			while lat < 500 do
				if onStation(p.position + p.cframe.RightVector * ctx.s(side * lat)) then
					need = math.max(need, lat)
				end
				lat += 6
			end
		end
		return need
	end

	local fc = cfg.fence
	local fenceOn = fc.enabled
	local roadEdgeM = RoadNetwork.layout(path, ctx).totalM / 2 + cfg.road.shoulderWidthM + cfg.road.kerbWidthM
	local fenceStartM = -(fc.behindStartM + 10)
	local fenceCount = math.floor((fc.endM - fenceStartM) / STEP) + 2

	local foot: { [number]: { number } } = {}
	local crest: { [number]: { number } } = {}
	local fence: { [number]: { number } } = {}
	local maxReach = 0
	for _, side in { -1, 1 } do
		local prof = if side == sunSide then b.sun else b.other
		local base = table.create(count)
		local height = table.create(count)
		-- Where a dune would come within clearanceGapM of the pad or the
		-- station it fades out: clear[i] is how much, 0..1.
		local clear = table.create(count, 0)
		local blendSteps = math.ceil(b.clearanceBlendM / STEP)
		for i = 1, count do
			local a = startM + (i - 1) * STEP
			local extent = siteExtent(side, a, true)
			if extent > 0 and extent + b.clearanceGapM > prof.footM then
				for j = math.max(1, i - blendSteps), math.min(count, i + blendSteps) do
					local t = 1 - smoothstep(math.abs(j - i) * STEP / b.clearanceBlendM)
					if t > clear[j] then
						clear[j] = t
					end
				end
			end
		end
		for i = 1, count do
			local a = startM + (i - 1) * STEP
			-- footM is the nearest the dune ever comes: the wander and the
			-- wobble only push it out, so the border is never closer than asked.
			base[i] = prof.footM
				+ math.clamp(math.noise(a / b.wanderWavelengthM, side * 7.3, seedFoot) + 0.5, 0, 1) * 2 * b.footJitterM
				+ math.clamp(math.noise(a / b.footWobbleWavelengthM, side * 11.1, seedWobble) + 0.5, 0, 1) * 2 * b.footWobbleM
			-- Noise sharpened toward its extremes, so the crest actually reaches
			-- its humps and saddles instead of hovering near the middle.
			local swing = 1
				+ math.clamp(math.noise(a / b.humpWavelengthM, side * 19.7, seedHump) * 2.5, -1, 1) * b.humpVariation
				+ math.clamp(math.noise(a / b.detailWavelengthM, side * 3.1, seedDetail) * 2.5, -1, 1) * b.detailVariation
			local taper = 1 - smoothstep((a - (endM - b.endTaperM)) / math.max(b.endTaperM, 1))
			-- A saddle never drops below minCrestFraction: the invisible wall on
			-- a 2 m hump reads as a barrier in the middle of flat sand.
			height[i] = math.max(0, prof.crestHeightM * math.max(swing, b.minCrestFraction) * taper * (1 - clear[i]))
		end
		for i = 1, count do
			maxReach = math.max(maxReach, base[i] + prof.riseWidthM + prof.backWidthM)
		end
		foot[side], crest[side] = base, height

		-- The fence line: fromRoadEdgeM past the road edge, pushed out behind the
		-- station (not the pad: its wing is well inside) and eased back.
		local line = table.create(fenceCount, roadEdgeM + fc.fromRoadEdgeM)
		if fenceOn then
			local fenceBlend = math.ceil(fc.clearanceBlendM / STEP)
			for i = 1, fenceCount do
				local a = fenceStartM + (i - 1) * STEP
				local extent = siteExtent(side, a, false)
				if extent > 0 then
					local want = extent + fc.clearanceGapM
					for j = math.max(1, i - fenceBlend), math.min(fenceCount, i + fenceBlend) do
						local t = smoothstep(math.abs(j - i) * STEP / fc.clearanceBlendM)
						local v = want - (want - (roadEdgeM + fc.fromRoadEdgeM)) * t
						if v > line[j] then
							line[j] = v
						end
					end
				end
			end
		end
		fence[side] = line
	end

	local function at(side: number, along: number): (number, number)
		local s = if side >= 0 then 1 else -1
		local x = math.clamp((along - startM) / STEP + 1, 1, count)
		local i = math.floor(x)
		local j = math.min(i + 1, count)
		local t = x - i
		local f, c = foot[s], crest[s]
		local h = c[i] + (c[j] - c[i]) * t
		if along > endM then
			h = 0
		end
		return f[i] + (f[j] - f[i]) * t, h
	end

	local function fenceAt(side: number, along: number): number
		local s = if side >= 0 then 1 else -1
		local x = math.clamp((along - fenceStartM) / STEP + 1, 1, fenceCount)
		local i = math.floor(x)
		local j = math.min(i + 1, fenceCount)
		local l = fence[s]
		return l[i] + (l[j] - l[i]) * (x - i)
	end

	local sunProf, otherProf = b.sun, b.other
	local border: Border = {
		enabled = r.enabled and b.enabled,
		at = at,
		riseM = { [sunSide] = sunProf.riseWidthM, [-sunSide] = otherProf.riseWidthM },
		backM = { [sunSide] = sunProf.backWidthM, [-sunSide] = otherProf.backWidthM },
		capBehindM = b.startCapBehindM,
		endM = endM,
		maxReachM = maxReach,
		fenceEnabled = fenceOn,
		fenceAt = fenceAt,
		fenceBehindM = fc.behindStartM,
		fenceEndM = fc.endM,
	}
	borders[path] = border
	return border
end

function Relief.build(cfg: Config, ctx: Context, path: Path, parent: Instance): (number, number, number)
	local r = cfg.relief
	local b = r.berm
	local terrain = Workspace.Terrain
	terrain:SetMaterialColor(Enum.Material.Sand, r.sandColor)
	terrain:SetMaterialColor(r.gravel.material, r.gravelColor)
	-- The dunes are the same sand as the desert plane: the plane's parts
	-- name the sand MaterialVariant, and terrain takes it through the base
	-- material override, so the grain and the tone carry straight across
	-- the dune's foot.
	if cfg.ground.sand.enabled and MaterialService:FindFirstChild(Materials.SAND) then
		local ok, err = pcall(function()
			MaterialService:SetBaseMaterialOverride(Enum.Material.Sand, Materials.SAND)
		end)
		if not ok then
			warn(`[World] could not give the terrain the sand variant ({err}); the dunes use stock sand`)
		end
	end

	local rng = Build.rng(r.seed)
	local totalM = RoadNetwork.lengthM(path)
	local groundY = ctx.surfaceY - ctx.s(cfg.ground.dropM)
	local border = Relief.border(cfg, ctx, path)
	local dunesOn = border.enabled

	-- Everything below is in studs unless it ends in M.
	local lift = ctx.s(r.liftM)
	local sink = ctx.s(r.sinkM)
	local shell = ctx.s(r.shellM)
	local innerGap = ctx.s(r.innerGapM)
	local feather = ctx.s(r.featherM)
	local swellRamp = ctx.s(r.swellRampM)
	local swellScale, rippleScale = ctx.s(r.swellWavelengthM), ctx.s(r.rippleWavelengthM)
	local swellAmp, rippleAmp = ctx.s(r.swellAmplitudeM), ctx.s(r.rippleAmplitudeM)
	local seedA, seedB = (r.seed % 101) / 3, (r.seed % 211) / 5
	local rise = { [-1] = ctx.s(border.riseM[-1]), [1] = ctx.s(border.riseM[1]) }
	local back = { [-1] = ctx.s(border.backM[-1]), [1] = ctx.s(border.backM[1]) }
	local capBehind = ctx.s(border.capBehindM)
	local backPower = b.backPower

	-- Where the drivable surface ends: the carriageway's shoulder, or the
	-- transition pad's wing (with its tapers) beside the spawn bay. The sand
	-- starts past this, so the pad is never buried.
	local preset = cfg.presets[cfg.preset] :: any
	local pad = preset.pad
	local vergeM = cfg.road.shoulderWidthM + cfg.road.kerbWidthM
	local padTaper = cfg.road.padTaperM
	local vergeStuds = ctx.s(vergeM)
	local function edgeStuds(halfWidth: number, along: number): number
		-- The carriageway's half width stops at the lane edge; the shoulder
		-- and kerb are outside it.
		halfWidth += vergeStuds
		if not pad or pad.widthM <= 0 then
			return halfWidth
		end
		local padEnd = pad.startM + pad.lengthM
		local t = 0
		if along >= pad.startM and along <= padEnd then
			t = 1
		elseif along < pad.startM and along > pad.startM - padTaper then
			t = (along - (pad.startM - padTaper)) / padTaper
		elseif along > padEnd and along < padEnd + padTaper then
			t = 1 - (along - padEnd) / padTaper
		end
		return math.max(halfWidth, halfWidth + (ctx.s(pad.widthM / 2 + vergeM) - halfWidth) * t)
	end
	-- The station's forecourt stays on the plane: the sand thins to nothing
	-- at its keep-out rectangle.
	local stationDistance = Station.keepOutDistance(cfg, ctx, path)

	-- The dune's height at `d` studs outward from its foot.
	local function duneHeight(side: number, d: number, crestStuds: number): number
		if d <= 0 or crestStuds <= 0 then
			return 0
		end
		local w = rise[side]
		if d <= w then
			return crestStuds * smoothstep(d / w)
		end
		local u = math.clamp((d - w) / back[side], 0, 1)
		return crestStuds * (1 - u) ^ backPower
	end

	-- Hummocks on the floor, placed first so a chunk can ask which ones
	-- touch it. Never on a dune: they would read as lumps on its face.
	local hummocks: { Hummock } = {}
	local hm = r.hummocks
	for _ = 1, math.floor(totalM / 1000 * hm.perKm) do
		for _, side in { -1, 1 } do
			local along = rng:NextNumber(0, totalM)
			local p = RoadNetwork.sample(path, along)
			local radius = ctx.s(rng:NextNumber(hm.minRadiusM, hm.maxRadiusM))
			local footM = border.at(side, along)
			local inner = edgeStuds(p.halfWidth, along) + innerGap + radius
			local outer = ctx.s(footM) - radius
			if outer > inner then
				local pos = p.position + p.cframe.RightVector * (side * rng:NextNumber(inner, outer))
				if stationDistance(pos) > ctx.mps * radius + r.featherM then
					table.insert(hummocks, { x = pos.X, z = pos.Z, r = radius, h = ctx.s(rng:NextNumber(hm.minHeightM, hm.maxHeightM)) })
				end
			end
		end
	end

	-- World bounding box of the strip, with room behind the start line for
	-- the cap.
	local reach = ctx.s(border.maxReachM)
	local behind = capBehind + math.max(rise[-1], rise[1]) + math.max(back[-1], back[1])
	local minX, maxX, minZ, maxZ = math.huge, -math.huge, math.huge, -math.huge
	local first = path[1]
	for _, pos in { first.position - first.cframe.LookVector * behind } do
		minX, maxX = math.min(minX, pos.X - reach), math.max(maxX, pos.X + reach)
		minZ, maxZ = math.min(minZ, pos.Z - reach), math.max(maxZ, pos.Z + reach)
	end
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
	local tallest = { [-1] = 0, [1] = 0 } -- crest angle from the road, degrees

	local cx = math.floor(minX / chunk) * chunk
	while cx < maxX do
		local cz = math.floor(minZ / chunk) * chunk
		while cz < maxZ do
			-- Path points this chunk could be nearest to. Scanning only
			-- these per column keeps the lateral distance exact through a
			-- curve, where one frame for the whole chunk would step.
			local candidates: { PathPoint } = {}
			local span = chunk * 0.71 + reach + behind
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
						local along = best.distanceM + (relX * look.X + relZ * look.Z) * ctx.mps
						local behindStart = -along / ctx.mps -- studs behind the start line (negative ahead of it)

						local footM, crestM = border.at(side, along)
						local foot = ctx.s(footM)
						local crest = if dunesOn then ctx.s(crestM) else 0
						-- How far outward from the dune's foot: sideways along
						-- the road, and round a rounded corner into the cap
						-- across behind the start line.
						local sideD = latAbs - foot
						local d = sideD
						if dunesOn and behindStart > 0 then
							local capD = behindStart - capBehind
							d = if capD > 0 and sideD > 0 then math.sqrt(capD * capD + sideD * sideD) else math.max(capD, sideD)
						end
						local outerD = rise[side] + back[side]
						-- Distance in from the strip's inner edge: the shoulder,
						-- or behind the start line where there is no road.
						local innerD = latAbs - (edgeStuds(best.halfWidth, along) + innerGap)
						if behindStart > 0 then
							innerD = math.max(innerD, behindStart - innerGap)
						end
						if innerD > 0 and latAbs < reach then
							innerD = math.min(innerD, ctx.s(stationDistance(Vector3.new(wx, groundY, wz))))
						end

						-- The strip stops before the city: nothing of it reaches
						-- the gateway or the streets.
						local endD = (border.endM - along) / ctx.mps
						-- Terrain is the dune and nothing else: the flat sand
						-- between the road and the dune's foot is the desert plane
						-- itself, so it is dead flat and the same sand.
						local surface = -math.huge
						local material = Enum.Material.Sand
						if dunesOn and d > 0 and innerD > 0 and d < outerD and endD > 0 then
							-- Undulation only ever rises from the floor: a dip below
							-- the sand plane lets the plane's flat part show through
							-- the terrain in patches.
							local ramp = smoothstep(d / swellRamp)
							local swell = math.max(0, math.noise(wx / swellScale, wz / swellScale, seedA) + 0.5) * swellAmp * ramp
							local floor = lift + swell + math.max(0, math.noise(wx / rippleScale, wz / rippleScale, seedB) + 0.5) * rippleAmp * ramp
							for _, h in touching do
								local dx, dz = wx - h.x, wz - h.z
								local d2 = dx * dx + dz * dz
								if d2 < h.r * h.r then
									local t = 1 - d2 / (h.r * h.r)
									floor += h.h * t * t
								end
							end
							local dune = duneHeight(side, d, crest)
							-- Both edges of the strip sink under the plane, so
							-- it has no rim.
							-- Sunk a little, so the dune breaks the plane where its
							-- slope is already rising: a surface only just above the
							-- plane renders as a voxel-high ledge along the foot.
							local f = math.clamp(math.min(d, innerD, outerD - d, endD) / feather, 0, 1)
							surface = groundY - sink + (floor + dune) * f
							if dune > 0 and d <= rise[side] + VOXEL and along >= 0 then
								local eyeM = 1.5
								local angle = math.deg(math.atan(((surface - groundY) * ctx.mps - eyeM) / math.max(latAbs * ctx.mps, 1)))
								tallest[side] = math.max(tallest[side], angle)
							end
							lo, hi = math.min(lo, surface), math.max(hi, surface)
						end
						srow[iz] = surface
						mrow[iz] = material
					end
				end
			end

			if hi > -math.huge then
				-- Every chunk writes down to the same depth. A per-chunk floor
				-- left the voxels under neighbouring chunks different, and the
				-- smoothing drew a seam up the dune face at every chunk edge.
				local yLo = math.floor((groundY - sink - shell) / VOXEL) * VOXEL
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

	-- The invisible stop, on the crest the terrain just built: short pieces
	-- that follow the wandering foot and the clearances, then one across
	-- behind the start line. Queryable: a colliding part with CanQuery off
	-- is not honoured reliably, and nothing else raycasts out here.
	local walls = 0
	if dunesOn and not border.fenceEnabled then
		local wallH = ctx.s(b.wallHeightM)
		local piece = b.wallPieceM
		local function wall(cf: CFrame, width: number, length: number)
			Build.part({
				name = "BermWall",
				size = Vector3.new(width, wallH, length),
				cframe = cf,
				color = r.sandColor,
				parent = folder,
				collide = true,
				query = true,
				transparency = 1,
			})
			walls += 1
		end
		local capM = border.capBehindM + math.max(border.riseM[-1], border.riseM[1])
		local crestLat = { [-1] = 0, [1] = 0 }
		for _, side in { -1, 1 } do
			local along = -capM
			while along < border.endM do
				local mid = along + piece / 2
				local footM = border.at(side, mid)
				local lat = footM + border.riseM[side]
				crestLat[side] = math.max(crestLat[side], if mid < 0 then lat else 0)
				local p = RoadNetwork.sample(path, math.clamp(mid, 0, totalM))
				local pos = p.position + p.cframe.LookVector * ctx.s(math.min(mid, 0)) + p.cframe.RightVector * ctx.s(side * lat)
				wall(CFrame.lookAt(Vector3.new(pos.X, groundY + wallH / 2, pos.Z), Vector3.new(pos.X, groundY + wallH / 2, pos.Z) + p.cframe.LookVector), ctx.s(1), ctx.s(piece + 1))
				along += piece
			end
		end
		-- Across behind the start line, joining the two side walls.
		local s = path[1]
		local centre = s.position - s.cframe.LookVector * ctx.s(capM)
		local widthM = crestLat[-1] + crestLat[1]
		local mid = centre + s.cframe.RightVector * ctx.s((crestLat[1] - crestLat[-1]) / 2)
		wall(CFrame.lookAt(Vector3.new(mid.X, groundY + wallH / 2, mid.Z), Vector3.new(mid.X, groundY + wallH / 2, mid.Z) + s.cframe.RightVector), ctx.s(1), ctx.s(widthM))
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

	if cfg.debug.report and dunesOn then
		local sunSide = Dunes.sideSign(cfg, path)
		local sunDeg = math.deg(math.asin(math.clamp(Lighting:GetSunDirection().Y, -1, 1)))
		print(string.format(
			"[World] border dunes: tallest crest %.1f deg above the driver's eye on the sun side, %.1f deg on the skyline side; sun at %.1f deg",
			tallest[sunSide],
			tallest[-sunSide],
			sunDeg
		))
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
