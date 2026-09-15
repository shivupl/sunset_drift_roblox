--!strict
-- The near desert and the edge of the world, as one continuous surface.
--
-- Low dunes over all the sand between a flat strip beside the road and the
-- fence, both sides and behind the start line: a random field of soft
-- mounds, each a different size and turned a little, thick in places and
-- thin in others, with bays of flat sand between. Every mound leaves the
-- sand plane at a grazing angle, so there is no foot line to see, and there
-- is no small-scale noise on them: calm shapes, nothing to bump over. They
-- keep clear of the petrol station and the fence, and sink away before the
-- city. The whole field is one height function worked out once
-- (Relief.border), which the terrain, the wall and Scatter all read, so
-- they always agree.
--
-- Terrain is the right tool here and nowhere else in the world: it only
-- reaches the client inside the streaming radius, and this strip is the one
-- piece of sand the car is ever near. It all collides, so running wide feels
-- like sand. The only parts in the module are the invisible wall (only when
-- the fence is off) and the scrub on the hummocks.
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
	-- The dunes' height function: metres of dune under a spot given as metres
	-- along the road (extrapolated past the start) and signed lateral metres.
	-- The terrain surface there is the sand plane - sinkM + this, so the dune
	-- only shows where it is above sinkM; 0 is no dune at all.
	heightAt: (alongM: number, lateralM: number) -> number,
	sinkM: number,
	nearM: number, -- nothing of a dune shows nearer the centreline than this
	capNearM: number, -- nor nearer the start line, behind it
	endM: number,
	maxReachM: number, -- farthest lateral reach of any mound
	capReachM: number, -- farthest reach behind the start line
	moundCount: number,
	anyNear: (alongM: number, lateralM: number, radiusM: number) -> boolean,
	-- The fence (WorldConfig.fence): its distance from the centreline for a
	-- side and metres along the road, and where it runs.
	fenceEnabled: boolean,
	fenceAt: (side: number, alongM: number) -> number,
	fenceBehindM: number,
	fenceEndM: number,
}

-- One mound: an ellipse in (along, lateral) metres, longer than it is wide,
-- turned a little off the road, with a longer slope on the side facing the
-- road than behind.
type Mound = {
	along: number,
	lateral: number,
	ax: number, -- long axis, (along, lateral) components
	al: number,
	nx: number, -- across it, pointing away from the road
	nl: number,
	halfLength: number,
	near: number, -- half width on the road side
	far: number, -- half width behind
	height: number,
	reach: number, -- farthest any of it gets from the centre
}

local borders: { [Path]: Border } = {}

-- Squared flat distance from path point k to (x, z).
local function dist2(points: { PathPoint }, k: number, x: number, z: number): number
	local q = points[k].position
	local dx, dz = q.X - x, q.Z - z
	return dx * dx + dz * dz
end

-- A mound's height at (du, dl) metres from its centre. (1 - q)^3 over the
-- ellipse: flat at the top and, more to the point, flat at the rim -- the
-- slope and the curvature both run out to nothing, so the mound leaves the
-- sand plane at a grazing angle instead of a crease.
local function moundHeight(m: Mound, du: number, dl: number): number
	local u = (du * m.ax + dl * m.al) / m.halfLength
	local v = du * m.nx + dl * m.nl
	v /= if v > 0 then m.far else m.near
	local q = u * u + v * v
	if q >= 1 then
		return 0
	end
	local k = 1 - q
	return m.height * k * k * k
end

-- Where a mound of this height meets the plane, as a fraction of its half
-- width: (1 - r^2)^3 = sink / height.
local function rimFraction(height: number, sink: number): number
	if height <= sink then
		return 0
	end
	return math.sqrt(1 - (sink / height) ^ (1 / 3))
end

-- The border's shape, worked out once per path.
function Relief.border(cfg: Config, ctx: Context, path: Path): Border
	local cached = borders[path]
	if cached then
		return cached
	end
	local r = cfg.relief
	local b = r.berm
	local totalM = RoadNetwork.lengthM(path)
	local endM = math.min(b.endM, totalM)
	local sinkM = r.sinkM
	local seed = r.seed
	local seedWander, seedYaw = (seed % 401) / 11, (seed % 499) / 13
	local rng = Random.new(seed * 7 + 131)

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

	-- The fence line, both sides: fromRoadEdgeM past the road edge, pushed
	-- out behind the station (not the pad: its wing is well inside) and
	-- eased back.
	local fence: { [number]: { number } } = {}
	for _, side in { -1, 1 } do
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

	local function fenceAt(side: number, along: number): number
		local s = if side >= 0 then 1 else -1
		local x = math.clamp((along - fenceStartM) / STEP + 1, 1, fenceCount)
		local i = math.floor(x)
		local j = math.min(i + 1, fenceCount)
		local l = fence[s]
		return l[i] + (l[j] - l[i]) * (x - i)
	end

	-- The mounds: a random field over all the sand between the flat strip
	-- beside the road and the fence, both sides and behind the start line.
	-- Every mound a different length, height and width, turned a little;
	-- denser in some stretches and thin in others (a slow noise), leaving
	-- bays of flat sand. Each keeps its whole visible rim out of the flat
	-- strip, clear of the fence, and clear of the station.
	local mounds: { Mound } = {}
	local BUCKET = 40
	local buckets: { [number]: { Mound } } = {}
	local maxReach, capReach = 0, 0
	local function between(range: { number }): number
		return rng:NextNumber(range[1], range[2])
	end

	-- Raw summed height of the mounds placed so far.
	local function sumAt(along: number, lateral: number): number
		local list = buckets[math.floor(along / BUCKET)]
		if not list then
			return 0
		end
		local sum = 0
		for _, m in list do
			local dl = lateral - m.lateral
			if dl < m.reach and dl > -m.reach then
				sum += moundHeight(m, along - m.along, dl)
			end
		end
		return sum
	end

	-- A spot as a world position, straight on past either end of the road.
	local function world(along: number, lateral: number): Vector3
		local p = RoadNetwork.sample(path, math.clamp(along, 0, totalM))
		local extra = if along < 0 then along elseif along > totalM then along - totalM else 0
		return p.position + p.cframe.LookVector * ctx.s(extra) + p.cframe.RightVector * ctx.s(lateral)
	end

	local f = b.field
	local fenceFar = roadEdgeM + fc.fromRoadEdgeM
	local fromAlong = if fenceOn then -(fc.behindStartM - f.fenceGapM) else -(b.capNearM + 300)
	local toAlong = endM
	-- Rim points (at half the sink, like the placement) round a mound, grown
	-- by `grow` metres: the whole visible mound lies inside them.
	local RIM_POINTS = 24
	local function fits(m: Mound): boolean
		local rim = rimFraction(m.height, sinkM * 0.5)
		for k = 0, RIM_POINTS - 1 do
			local t = k / RIM_POINTS * 2 * math.pi
			local cu, sv = math.cos(t), math.sin(t)
			local u = cu * m.halfLength * rim
			local vBase = if sv > 0 then m.far else m.near
			for _, grow in { 0, b.clearanceGapM } do
				local uu = u + cu * grow
				local vv = sv * (vBase * rim + grow)
				local a = m.along + uu * m.ax + vv * m.nx
				local l = m.lateral + uu * m.al + vv * m.nl
				if grow == 0 then
					-- Out of the flat strip beside the road (and its run on
					-- behind the start line), inside the fence, short of the city.
					if a >= -b.capNearM and math.abs(l) < b.nearM then
						return false
					end
					if a < fromAlong or a > toAlong + b.endTaperM then
						return false
					end
					if math.abs(l) > (if fenceOn then fenceAt(l, a) else fenceFar) - f.fenceGapM then
						return false
					end
				elseif cfg.station.enabled and a > 0 and a < totalM and onStation(world(a, l)) then
					return false
				end
			end
		end
		return true
	end

	local sideFar = fenceFar - f.fenceGapM
	local areaKm2 = ((toAlong - fromAlong) * 2 * sideFar - (toAlong + b.capNearM) * 2 * b.nearM) / 1e6
	local target = math.floor(areaKm2 * f.perKm2)
	local attempts = target * 12
	local placed = 0
	while placed < target and attempts > 0 do
		attempts -= 1
		local along = rng:NextNumber(fromAlong, toAlong)
		local lateral = rng:NextNumber(-sideFar, sideFar)
		-- Patchiness: where the slow noise is low, most tries are thrown away.
		local patch = math.noise(along / f.patchWavelengthM, lateral / f.patchWavelengthM, seedWander) * 2 + 0.5
		if rng:NextNumber() > math.clamp(patch, f.minDensity, 1) then
			continue
		end
		local halfLength = between(b.lengthM) / 2
		local height = b.heightM[1] + (b.heightM[2] - b.heightM[1]) * rng:NextNumber() ^ 1.4
		local k = math.sqrt(height / b.heightM[2]) -- low ones are smaller all round
		local near, far = between(b.nearSpreadM) * (0.6 + 0.4 * k), between(b.farSpreadM) * (0.6 + 0.4 * k)
		halfLength *= 0.6 + 0.4 * k
		-- Mostly lined up with a slow drift (the wind), each a little off it.
		local yaw = math.rad(b.yawDeg) * math.clamp(math.noise(along / 700, lateral / 700, seedYaw) * 2 + rng:NextNumber(-0.6, 0.6), -1, 1)
		local c, s = math.cos(yaw), math.sin(yaw)
		local side = if lateral >= 0 then 1 else -1
		local m: Mound
		if along < -b.capNearM and math.abs(lateral) < b.nearM + 40 then
			-- Behind the start line: long axis across, the gentle side facing it.
			m = { along = along, lateral = lateral, ax = -s, al = c, nx = -c, nl = -s, halfLength = halfLength, near = near, far = far, height = height, reach = math.max(halfLength, near, far) }
		else
			m = { along = along, lateral = lateral, ax = c, al = s, nx = -s * side, nl = c * side, halfLength = halfLength, near = near, far = far, height = height, reach = math.max(halfLength, near, far) }
		end
		-- Not stacked on another: overlapping tails are fine, a mound on a
		-- mound's shoulder is a lump.
		if sumAt(along, lateral) > f.maxOverlapM or not fits(m) then
			continue
		end
		table.insert(mounds, m)
		placed += 1
		local spread = m.reach
		for kb = math.floor((m.along - spread) / BUCKET), math.floor((m.along + spread) / BUCKET) do
			local list = buckets[kb]
			if not list then
				list = {}
				buckets[kb] = list
			end
			table.insert(list, m)
		end
		maxReach = math.max(maxReach, math.abs(m.lateral) + spread)
		capReach = math.max(capReach, -(m.along - spread))
	end

	-- Whether any mound comes within radius metres of a spot.
	local function anyNear(along: number, lateral: number, radius: number): boolean
		for kb = math.floor((along - radius) / BUCKET), math.floor((along + radius) / BUCKET) do
			local list = buckets[kb]
			if list then
				for _, m in list do
					if math.abs(along - m.along) < m.reach + radius and math.abs(lateral - m.lateral) < m.reach + radius then
						return true
					end
				end
			end
		end
		return false
	end

	local shoulder, ceiling = b.overlapM[1], b.overlapM[2]
	local function heightAt(along: number, lateral: number): number
		if along > endM then
			return 0
		end
		local sum = sumAt(along, lateral)
		if sum <= 0 then
			return 0
		end
		-- Where mounds overlap, their heights add, eased toward a ceiling
		-- past a shoulder (smoothly: same slope either side of it) so two
		-- tall ones make a broad hill rather than a spike.
		if sum > shoulder then
			sum = shoulder + (ceiling - shoulder) * math.tanh((sum - shoulder) / (ceiling - shoulder))
		end
		-- Sunk away before the city.
		return sum * (1 - smoothstep((along - (endM - b.endTaperM)) / math.max(b.endTaperM, 1)))
	end

	local border: Border = {
		enabled = r.enabled and b.enabled,
		heightAt = heightAt,
		sinkM = sinkM,
		nearM = b.nearM,
		capNearM = b.capNearM,
		endM = endM,
		maxReachM = maxReach,
		capReachM = capReach,
		moundCount = #mounds,
		anyNear = anyNear,
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
	local borderClock = os.clock()
	local border = Relief.border(cfg, ctx, path)
	borderClock = os.clock() - borderClock
	local dunesOn = border.enabled

	-- Everything below is in studs unless it ends in M.
	local sink = ctx.s(r.sinkM)
	local shell = ctx.s(r.shellM)
	local innerGap = ctx.s(r.innerGapM)
	local feather = ctx.s(r.featherM)

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

	-- Hummocks on the floor, placed first so a chunk can ask which ones
	-- touch it. Never on a dune: they would read as lumps on its face.
	local hummocks: { Hummock } = {}
	local hm = r.hummocks
	for _ = 1, math.floor(totalM / 1000 * hm.perKm) do
		for _, side in { -1, 1 } do
			local along = rng:NextNumber(0, totalM)
			local p = RoadNetwork.sample(path, along)
			local radius = ctx.s(rng:NextNumber(hm.minRadiusM, hm.maxRadiusM))
			local inner = edgeStuds(p.halfWidth, along) + innerGap + radius
			local outer = ctx.s(border.nearM) - radius
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
	local behind = ctx.s(border.capReachM)
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
			-- Path points this chunk could be nearest to: none further from
			-- its centre than the nearest one plus the chunk's width. Scanning
			-- only these per column keeps the lateral distance exact through
			-- a curve, where one frame for the whole chunk would step.
			local candidates: { PathPoint } = {}
			local ccx, ccz = cx + chunk / 2, cz + chunk / 2
			local centreBest, centreD = path[1], math.huge
			for _, p in path do
				local dx, dz = p.position.X - ccx, p.position.Z - ccz
				local d = dx * dx + dz * dz
				if d < centreD then
					centreBest, centreD = p, d
				end
			end
			local span = math.sqrt(centreD) + chunk * 1.42 + VOXEL
			-- Only where a mound is near: most of the sand is flat.
			local cRel = Vector3.new(ccx - centreBest.position.X, 0, ccz - centreBest.position.Z)
			local cAlong = centreBest.distanceM + cRel:Dot(centreBest.cframe.LookVector) * ctx.mps
			local cLateral = cRel:Dot(centreBest.cframe.RightVector) * ctx.mps
			if dunesOn and math.sqrt(centreD) < reach + behind and border.anyNear(cAlong, cLateral, chunk * 0.71 * ctx.mps + 20) then
				for _, p in path do
					local dx, dz = p.position.X - ccx, p.position.Z - ccz
					if dx * dx + dz * dz < span * span then
						table.insert(candidates, p)
					end
				end
			end
			local hint = 1

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
						-- The nearest candidate, walked downhill from the last
						-- column's: distance along the road to a point is
						-- one-dipped, and neighbouring columns share a nearest.
						local bestD = dist2(candidates, hint, wx, wz)
						while hint > 1 and dist2(candidates, hint - 1, wx, wz) < bestD do
							hint -= 1
							bestD = dist2(candidates, hint, wx, wz)
						end
						while hint < #candidates and dist2(candidates, hint + 1, wx, wz) < bestD do
							hint += 1
							bestD = dist2(candidates, hint, wx, wz)
						end
						local best = candidates[hint]
						local relX, relZ = wx - best.position.X, wz - best.position.Z
						local right, look = best.cframe.RightVector, best.cframe.LookVector
						local lateral = relX * right.X + relZ * right.Z
						local side = if lateral >= 0 then 1 else -1
						local latAbs = math.abs(lateral)
						local along = best.distanceM + (relX * look.X + relZ * look.Z) * ctx.mps
						local behindStart = -along / ctx.mps -- studs behind the start line (negative ahead of it)

						local duneM = if dunesOn then border.heightAt(along, lateral * ctx.mps) else 0
						-- Distance in from the strip's inner edge: the shoulder,
						-- or behind the start line where there is no road.
						local innerD = 0
						if duneM > 0 then
							innerD = latAbs - (edgeStuds(best.halfWidth, along) + innerGap)
							if behindStart > 0 then
								innerD = math.max(innerD, behindStart - innerGap)
							end
							if innerD > 0 then
								innerD = math.min(innerD, ctx.s(stationDistance(Vector3.new(wx, groundY, wz))))
							end
						end

						-- Terrain is the dune and nothing else: the flat sand
						-- between the road and the dunes is the desert plane
						-- itself, so it is dead flat and the same sand.
						local surface = -math.huge
						local material = Enum.Material.Sand
						if duneM > 0 and innerD > 0 then
							local floor = 0
							for _, h in touching do
								local dx, dz = wx - h.x, wz - h.z
								local d2 = dx * dx + dz * dz
								if d2 < h.r * h.r then
									local t = 1 - d2 / (h.r * h.r)
									floor += h.h * t * t
								end
							end
							-- Sunk sinkM, so the mound breaks the plane where its
							-- slope has already begun: a surface only just above
							-- the plane renders as a voxel-high ledge. The feather
							-- is only a safety for the pad and the station; the
							-- mounds are faded out well before either.
							local f = math.clamp(innerD / feather, 0, 1)
							surface = groundY - sink + (floor + ctx.s(duneM)) * f
							if along >= 0 and surface - groundY > 0 then
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
							-- Terrain renders a column's surface half a voxel above
							-- where its occupancy says (measured: filling to t
							-- draws the top at t + 2 studs, exactly, on flats), so
							-- fill to half a voxel under the surface wanted. The
							-- old berm stood 0.56 m proud everywhere, which is
							-- the ledge its foot always had.
							local bottom = yLo + (iy - 1) * VOXEL
							local occ = math.clamp((surface - VOXEL / 2 - bottom) / VOXEL, 0, 1)
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

	-- The invisible stop, only when there is no fence: short pieces along
	-- where the fence would be, then one across behind the start line. Queryable: a colliding part with CanQuery off
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
		local capM = border.fenceBehindM
		local crestLat = { [-1] = 0, [1] = 0 }
		for _, side in { -1, 1 } do
			local along = -capM
			while along < border.endM do
				local mid = along + piece / 2
				local lat = border.fenceAt(side, mid)
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
				local top = Relief.surfaceY(Vector3.new(h.x, groundY, h.z)) or (groundY + h.h)
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
			"[World] border dunes: %d mounds laid out in %.1f s; tallest crest %.1f deg above the driver's eye on the sun side, %.1f deg on the skyline side; sun at %.1f deg",
			border.moundCount,
			borderClock,
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
