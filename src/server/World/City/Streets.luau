--!strict
-- The city street grid: boulevards with palm medians, side streets,
-- roundabouts at every boulevard crossing, kerbs and pavements around every
-- parcel, and the two ramps that tie the grid to the highway. Everything is
-- axis-aligned boxes from CityConfig and a seeded random; the parcels the
-- grid leaves behind are handed to the building generator as the Plan.
--
-- Geometry. Streets are asphalt slabs whose top sits at the highway surface
-- height, the same level the sand sits 5 cm under, so a slab that has not
-- streamed in yet is a step, not a hole. Boulevard segments run from one
-- roundabout square to the next and the square is its own slab, so no two
-- coplanar slabs ever overlap and nothing z-fights at a crossing. Kerbs and
-- pavements belong to the parcels, not the streets, which is what leaves a
-- kerb gap wherever a side street meets a boulevard. Only the asphalt and
-- the roundabout islands collide: kerbs and pavements are a 12 cm lip that
-- would launch a car at speed, so the car drives over them onto the sand a
-- few centimetres below. The islands are the one raised thing that stops a
-- car, on purpose; a roundabout you can drive through is not a roundabout.
local WorldConfig = require(script.Parent.Parent.WorldConfig)
local Build = require(script.Parent.Parent.Build)
local RoadNetwork = require(script.Parent.Parent.RoadNetwork)
local CityConfig = require(script.Parent.CityConfig)

type Context = RoadNetwork.Context
type CCfg = CityConfig.Config

local Streets = {}

export type Rect = { minX: number, maxX: number, minZ: number, maxZ: number } -- world metres
export type Segment = {
	ax: number, -- world metres, start
	az: number,
	bx: number, -- end
	bz: number,
	widthM: number,
	boulevard: boolean,
}
export type Node = { x: number, z: number, widthM: number, roundabout: boolean }
-- What each side of a parcel faces: "boulevard" or "side".
export type Parcel = {
	rect: Rect,
	district: string,
	block: { i: number, j: number },
	north: string,
	south: string,
	east: string,
	west: string,
}
export type Plan = {
	nodes: { Node },
	segments: { Segment },
	parcels: { Parcel },
	blocks: { Rect },
	rampPaths: { RoadNetwork.Path },
}

local function tinted(colour: Color3, rng: Random, tone: number): Color3
	local t = rng:NextNumber(-tone, tone)
	return if t < 0 then colour:Lerp(Color3.new(0, 0, 0), -t) else colour:Lerp(Color3.new(1, 1, 1), t)
end

-- A box in world metres: centre x/z, size x/z, top height above the surface
-- and thickness.
local function slab(
	ctx: Context,
	parent: Instance,
	name: string,
	cx: number,
	cz: number,
	sx: number,
	sz: number,
	topM: number,
	thickM: number,
	color: Color3,
	material: Enum.Material,
	collide: boolean
): Part
	return Build.part({
		name = name,
		size = Vector3.new(ctx.s(sx), ctx.s(thickM), ctx.s(sz)),
		cframe = CFrame.new(ctx.s(cx), ctx.surfaceY + ctx.s(topM - thickM / 2), ctx.s(cz)),
		color = color,
		material = material,
		parent = parent,
		collide = collide,
		query = collide,
	})
end

-- A slab chopped along its long axis at maxRunM, each piece its own tone.
local function slabRun(
	ctx: Context,
	c: CCfg,
	rng: Random,
	parent: Instance,
	name: string,
	ax: number,
	az: number,
	bx: number,
	bz: number,
	widthM: number,
	color: Color3,
	material: Enum.Material
)
	local dx, dz = bx - ax, bz - az
	local len = math.sqrt(dx * dx + dz * dz)
	if len < 0.5 then
		return
	end
	local along = if math.abs(dx) > math.abs(dz) then "x" else "z"
	local n = math.max(1, math.ceil(len / c.surface.maxRunM))
	for i = 1, n do
		local t0, t1 = (i - 1) / n, i / n
		local cx = ax + dx * (t0 + t1) / 2
		local cz = az + dz * (t0 + t1) / 2
		local seg = len / n
		local sx = if along == "x" then seg else widthM
		local sz = if along == "x" then widthM else seg
		slab(ctx, parent, name, cx, cz, sx, sz, 0, c.surface.thicknessM, tinted(color, rng, c.surface.slabTone), material, true)
	end
end

-- Thin painted strip on the asphalt.
local function paint(ctx: Context, c: CCfg, parent: Instance, name: string, cx: number, cz: number, sx: number, sz: number, color: Color3, transparency: number?)
	local p = slab(ctx, parent, name, cx, cz, sx, sz, c.surface.markingEpsilonM + c.surface.markingThicknessM, c.surface.markingThicknessM, color, Enum.Material.SmoothPlastic, false)
	if transparency then
		p.Transparency = transparency
	end
end

-- Boulevard markings along one segment: lane dashes, the parking-lane and
-- median edge lines, and tyre tracks in the inner lanes.
local function boulevardMarkings(ctx: Context, c: CCfg, rng: Random, detail: Instance, seg: Segment)
	local b = c.boulevard
	local s = c.surface
	local alongX = math.abs(seg.bx - seg.ax) > math.abs(seg.bz - seg.az)
	local len = if alongX then math.abs(seg.bx - seg.ax) else math.abs(seg.bz - seg.az)
	local x0 = math.min(seg.ax, seg.bx)
	local z0 = math.min(seg.az, seg.bz)
	local cwM = (b.widthM - b.medianWidthM) / 2
	local laneW = (cwM - b.parkingLaneM) / b.laneCount
	local innerM = b.medianWidthM / 2
	local function strip(lateral: number, fromD: number, toD: number, w: number, color: Color3, name: string, transparency: number?)
		local cd = (fromD + toD) / 2
		local l = toD - fromD
		if alongX then
			paint(ctx, c, detail, name, x0 + cd, (seg.az + seg.bz) / 2 + lateral, l, w, color, transparency)
		else
			paint(ctx, c, detail, name, (seg.ax + seg.bx) / 2 + lateral, z0 + cd, w, l, color, transparency)
		end
	end
	local worn = s.paintColor:Lerp(c.surface.asphaltColor, 0.35)
	for _, side in { -1, 1 } do
		-- Lane dividers, dashed.
		for lane = 1, b.laneCount - 1 do
			local lateral = side * (innerM + laneW * lane)
			local d = s.dashGapM / 2
			while d + s.dashLengthM < len do
				strip(lateral, d, d + s.dashLengthM, s.dashWidthM, worn, "Dash", rng:NextNumber(0, 0.3))
				d += s.dashLengthM + s.dashGapM
			end
		end
		-- Parking lane line and median edge line, solid.
		strip(side * (innerM + laneW * b.laneCount), 0, len, s.edgeLineWidthM, worn, "Line", 0.15)
		strip(side * (innerM + 0.3), 0, len, s.edgeLineWidthM, worn, "Line", 0.15)
		-- Tyre tracks: the inner two lanes, where the traffic actually runs.
		if s.tyreTracksEnabled then
			local dark = c.surface.asphaltColor:Lerp(Color3.new(0, 0, 0), s.tyreTrackDarken)
			for lane = 1, math.min(2, b.laneCount) do
				local centre = side * (innerM + laneW * (lane - 0.5))
				for _, t in { -1, 1 } do
					strip(centre + t * s.tyreTrackGapM / 2, 2, len - 2, s.tyreTrackWidthM, dark, "Track", 0.25)
				end
			end
		end
	end
end

-- Kerb and pavement ring around a parcel, and the parcel's own ground.
local function parcelRing(ctx: Context, c: CCfg, rng: Random, parent: Instance, rect: Rect)
	local s = c.surface
	local k = c.boulevard.kerbWidthM
	local pw = s.pavementWidthM
	local kerb = s.kerbColor:Lerp(WorldConfig.ground.nearColor, s.kerbDust)
	local pave = s.pavementColor
	-- Pavement ring: the north and south slabs span the corners.
	local w = rect.maxX - rect.minX
	local h = rect.maxZ - rect.minZ
	local cx, cz = (rect.minX + rect.maxX) / 2, (rect.minZ + rect.maxZ) / 2
	local top = s.pavementHeightM
	local thick = s.pavementHeightM + 0.1
	slab(ctx, parent, "Pavement", cx, rect.maxZ + pw / 2, w + 2 * pw, pw, top, thick, tinted(pave, rng, 0.05), Enum.Material.Concrete, false)
	slab(ctx, parent, "Pavement", cx, rect.minZ - pw / 2, w + 2 * pw, pw, top, thick, tinted(pave, rng, 0.05), Enum.Material.Concrete, false)
	slab(ctx, parent, "Pavement", rect.minX - pw / 2, cz, pw, h, top, thick, tinted(pave, rng, 0.05), Enum.Material.Concrete, false)
	slab(ctx, parent, "Pavement", rect.maxX + pw / 2, cz, pw, h, top, thick, tinted(pave, rng, 0.05), Enum.Material.Concrete, false)
	-- Kerb lip on the street side of the pavement.
	local kh = c.boulevard.kerbHeightM
	slab(ctx, parent, "Kerb", cx, rect.maxZ + pw + k / 2, w + 2 * (pw + k), k, kh, kh + 0.05, tinted(kerb, rng, 0.06), Enum.Material.Concrete, false)
	slab(ctx, parent, "Kerb", cx, rect.minZ - pw - k / 2, w + 2 * (pw + k), k, kh, kh + 0.05, tinted(kerb, rng, 0.06), Enum.Material.Concrete, false)
	slab(ctx, parent, "Kerb", rect.minX - pw - k / 2, cz, k, h + 2 * pw, kh, kh + 0.05, tinted(kerb, rng, 0.06), Enum.Material.Concrete, false)
	slab(ctx, parent, "Kerb", rect.maxX + pw + k / 2, cz, k, h + 2 * pw, kh, kh + 0.05, tinted(kerb, rng, 0.06), Enum.Material.Concrete, false)
end

local function roundabout(ctx: Context, c: CCfg, rng: Random, parent: Instance, node: Node)
	local r = c.roundabout
	local function disc(name: string, radiusM: number, heightM: number, color: Color3, material: Enum.Material)
		local p = Build.part({
			name = name,
			size = Vector3.new(ctx.s(heightM), ctx.s(radiusM * 2), ctx.s(radiusM * 2)),
			cframe = CFrame.new(ctx.s(node.x), ctx.surfaceY + ctx.s(heightM / 2), ctx.s(node.z)) * CFrame.Angles(0, 0, math.pi / 2),
			color = color,
			material = material,
			parent = parent,
			collide = true,
			query = true,
		})
		p.Shape = Enum.PartType.Cylinder
		return p
	end
	local kerb = c.surface.kerbColor:Lerp(WorldConfig.ground.nearColor, c.surface.kerbDust)
	disc("IslandKerb", r.islandRadiusM, r.islandHeightM, tinted(kerb, rng, 0.05), Enum.Material.Concrete)
	disc("Island", r.islandRadiusM - 0.8, r.islandHeightM + 0.12, c.surface.medianColor, Enum.Material.Ground)
end

local function ramp(ctx: Context, c: CCfg, rng: Random, parent: Instance, detail: Instance, points: { { number } }): RoadNetwork.Path
	local waypoints: { WorldConfig.Waypoint } = {}
	for _, pt in points do
		table.insert(waypoints, { xM = pt[1], zM = pt[2], widthM = pt[3] or c.ramp.widthM, bankingDeg = 0 })
	end
	local path = RoadNetwork.toPath(waypoints, ctx)
	RoadNetwork.ribbon({
		name = "Ramp",
		parent = parent,
		path = path,
		ctx = ctx,
		offsetM = 0,
		widthM = c.ramp.widthM,
		widthFromPath = true,
		heightM = c.surface.thicknessM,
		yM = -c.surface.thicknessM / 2,
		color = tinted(c.surface.asphaltColor, rng, 0.03),
		material = Enum.Material.Asphalt,
		collide = true,
		runCapM = c.surface.maxRunM,
	})
	for _, side in { -1, 1 } do
		RoadNetwork.ribbon({
			name = "RampLine",
			parent = detail,
			path = path,
			ctx = ctx,
			offsetM = side * (c.ramp.widthM / 2 - 0.5),
			widthM = c.surface.edgeLineWidthM,
			heightM = c.surface.markingThicknessM,
			yM = c.surface.markingEpsilonM + c.surface.markingThicknessM / 2,
			color = c.surface.paintColor:Lerp(c.surface.asphaltColor, 0.35),
			runCapM = c.surface.maxRunM,
		})
	end
	return path
end

function Streets.build(ctx: Context, c: CCfg, parent: Instance): (Plan, Folder, Folder)
	local rng = Build.rng(c.seed)
	local folder = Build.folder("Streets", parent)
	local detail = Build.folder("StreetDetail", parent)
	local b = c.boulevard
	local ss = c.sideStreet
	local s = c.surface
	local half = b.widthM / 2
	local sHalf = ss.widthM / 2
	local pw = s.pavementWidthM + b.kerbWidthM

	local nodes: { Node } = {}
	local segments: { Segment } = {}
	local parcels: { Parcel } = {}
	local blocks: { Rect } = {}

	local function bx(i: number): number
		return c.originM.x + i * c.blockM
	end
	local function bz(j: number): number
		return c.originM.z - j * c.blockM
	end
	-- The gateway square is wider than the others so the whole highway
	-- lands on it; everything that touches that node backs off to its edge.
	local function nodeHalf(i: number, j: number): number
		if j == 0 and i == c.gateway.i then
			return c.gateway.widthM / 2
		end
		return half
	end

	-- Boulevard crossings: roundabouts.
	for i = 0, c.blocksX do
		for j = 0, c.blocksZ do
			table.insert(nodes, { x = bx(i), z = bz(j), widthM = nodeHalf(i, j) * 2, roundabout = true })
		end
	end
	-- Boulevard segments between crossings.
	for i = 0, c.blocksX do
		for j = 0, c.blocksZ - 1 do
			table.insert(segments, { ax = bx(i), az = bz(j) - nodeHalf(i, j), bx = bx(i), bz = bz(j + 1) + nodeHalf(i, j + 1), widthM = b.widthM, boulevard = true })
		end
	end
	for j = 0, c.blocksZ do
		for i = 0, c.blocksX - 1 do
			table.insert(segments, { ax = bx(i) + nodeHalf(i, j), az = bz(j), bx = bx(i + 1) - nodeHalf(i + 1, j), bz = bz(j), widthM = b.widthM, boulevard = true })
		end
	end
	-- Side streets: one each way through the middle of every block, meeting
	-- at a plain crossing, ending at the boulevard kerbs.
	for i = 0, c.blocksX - 1 do
		for j = 0, c.blocksZ - 1 do
			local mx, mz = bx(i) + c.blockM / 2, bz(j) - c.blockM / 2
			table.insert(nodes, { x = mx, z = mz, widthM = ss.widthM, roundabout = false })
			table.insert(segments, { ax = mx, az = bz(j) - half, bx = mx, bz = mz + sHalf, widthM = ss.widthM, boulevard = false })
			table.insert(segments, { ax = mx, az = mz - sHalf, bx = mx, bz = bz(j + 1) + half, widthM = ss.widthM, boulevard = false })
			table.insert(segments, { ax = bx(i) + half, az = mz, bx = mx - sHalf, bz = mz, widthM = ss.widthM, boulevard = false })
			table.insert(segments, { ax = mx + sHalf, az = mz, bx = bx(i + 1) - half, bz = mz, widthM = ss.widthM, boulevard = false })
			table.insert(blocks, { minX = bx(i) + half, maxX = bx(i + 1) - half, minZ = bz(j + 1) + half, maxZ = bz(j) - half })
			-- Four parcels, inside the pavements.
			local row = c.districts[j + 1]
			local district = if row then (row[i + 1] or "residential") else "residential"
			local function parcel(minX: number, maxX: number, minZ: number, maxZ: number, north: string, south: string, east: string, west: string)
				table.insert(parcels, {
					rect = { minX = minX, maxX = maxX, minZ = minZ, maxZ = maxZ },
					district = district,
					block = { i = i, j = j },
					north = north,
					south = south,
					east = east,
					west = west,
				})
			end
			-- north is +Z here (toward the highway start), south is -Z. A
			-- parcel whose corner touches the gateway node backs off to that
			-- node's larger square on both of its boulevard sides.
			local nwH, neH, swH, seH = nodeHalf(i, j), nodeHalf(i + 1, j), nodeHalf(i, j + 1), nodeHalf(i + 1, j + 1)
			parcel(bx(i) + nwH + pw, mx - sHalf - pw, mz + sHalf + pw, bz(j) - nwH - pw, "boulevard", "side", "side", "boulevard")
			parcel(mx + sHalf + pw, bx(i + 1) - neH - pw, mz + sHalf + pw, bz(j) - neH - pw, "boulevard", "side", "boulevard", "side")
			parcel(bx(i) + swH + pw, mx - sHalf - pw, bz(j + 1) + swH + pw, mz - sHalf - pw, "side", "boulevard", "side", "boulevard")
			parcel(mx + sHalf + pw, bx(i + 1) - seH - pw, bz(j + 1) + seH + pw, mz - sHalf - pw, "side", "boulevard", "boulevard", "side")
		end
	end

	-- Emit. Nodes first (their own slab), then segments, then rings.
	local asphalt = Build.folder("Asphalt", folder)
	for _, n in nodes do
		slab(ctx, asphalt, if n.roundabout then "Roundabout" else "Crossing", n.x, n.z, n.widthM, n.widthM, 0, s.thicknessM, tinted(s.asphaltColor, rng, s.slabTone), Enum.Material.Asphalt, true)
		if n.roundabout then
			roundabout(ctx, c, rng, asphalt, n)
		end
	end
	local medians = Build.folder("Medians", folder)
	for _, seg in segments do
		if seg.boulevard then
			local cwM = (b.widthM - b.medianWidthM) / 2
			local alongX = math.abs(seg.bx - seg.ax) > math.abs(seg.bz - seg.az)
			-- Two carriageways either side of the median, then the median.
			for _, side in { -1, 1 } do
				local off = side * (b.medianWidthM / 2 + cwM / 2)
				if alongX then
					slabRun(ctx, c, rng, asphalt, "Asphalt", seg.ax, seg.az + off, seg.bx, seg.bz + off, cwM, s.asphaltColor, Enum.Material.Asphalt)
				else
					slabRun(ctx, c, rng, asphalt, "Asphalt", seg.ax + off, seg.az, seg.bx + off, seg.bz, cwM, s.asphaltColor, Enum.Material.Asphalt)
				end
			end
			-- Median: ground a hair up, kerbed both sides.
			local mk = b.kerbWidthM
			local mkh = b.medianKerbHeightM
			local kerb = s.kerbColor:Lerp(WorldConfig.ground.nearColor, s.kerbDust)
			local len = if alongX then math.abs(seg.bx - seg.ax) else math.abs(seg.bz - seg.az)
			local cx, cz = (seg.ax + seg.bx) / 2, (seg.az + seg.bz) / 2
			if alongX then
				slab(ctx, medians, "Median", cx, cz, len, b.medianWidthM - 2 * mk, mkh + 0.02, mkh + 0.2, s.medianColor, Enum.Material.Ground, true)
				for _, side in { -1, 1 } do
					slab(ctx, medians, "MedianKerb", cx, cz + side * (b.medianWidthM / 2 - mk / 2), len, mk, mkh, mkh + 0.1, tinted(kerb, rng, 0.05), Enum.Material.Concrete, false)
				end
			else
				slab(ctx, medians, "Median", cx, cz, b.medianWidthM - 2 * mk, len, mkh + 0.02, mkh + 0.2, s.medianColor, Enum.Material.Ground, true)
				for _, side in { -1, 1 } do
					slab(ctx, medians, "MedianKerb", cx + side * (b.medianWidthM / 2 - mk / 2), cz, mk, len, mkh, mkh + 0.1, tinted(kerb, rng, 0.05), Enum.Material.Concrete, false)
				end
			end
			boulevardMarkings(ctx, c, rng, detail, seg)
		else
			slabRun(ctx, c, rng, asphalt, "SideStreet", seg.ax, seg.az, seg.bx, seg.bz, seg.widthM, s.sideStreetColor, Enum.Material.Asphalt)
		end
	end
	local rings = Build.folder("Pavements", folder)
	for _, p in parcels do
		parcelRing(ctx, c, rng, rings, p.rect)
	end

	-- Ramps, if the preset has any.
	local ramps = Build.folder("Ramps", folder)
	local rampPaths: { RoadNetwork.Path } = {}
	for _, pts in { c.ramp.offRamp, c.ramp.onRamp } do
		if #pts >= 2 then
			table.insert(rampPaths, ramp(ctx, c, rng, ramps, detail, pts))
		end
	end

	return { nodes = nodes, segments = segments, parcels = parcels, blocks = blocks, rampPaths = rampPaths }, folder, detail
end

return Streets
