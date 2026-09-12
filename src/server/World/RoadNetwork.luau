--!strict
-- Road surface, markings, shoulders, kerbs, the parking bay and the ground
-- plane. Replaces the old RoadBuilder; the Phase 0 test road survives as the
-- "testRoad" preset so physics tuning still has its reference surface.
--
-- The road is generated from a waypoint list. A preset either supplies the
-- waypoints directly or supplies segment descriptors (straight, curve) that
-- expand into them. Everything downstream -- barriers, lamps, signs, scatter
-- -- places itself by sampling the path this module returns, so moving a
-- waypoint moves the whole world with it.
--
-- Two geometry decisions worth knowing about:
--
-- Merging. Consecutive path points whose headings agree within
-- straightThresholdDeg are emitted as ONE part, split only by the engine's
-- 2048 stud axis cap. A 2 km straight barrier is four parts, not fifty. On
-- Roblox, fewer parts beats fewer triangles.
--
-- Joints. Segments overlap only where the road actually turns. Overlapping on
-- a straight would put two coplanar top faces in the same place and z-fight;
-- on a curve the two faces meet at an angle, resolve cleanly, and the overlap
-- is what closes the wedge gap that would otherwise open on the outside edge.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Units = require(Shared.Units)
local WorldConfig = require(script.Parent.WorldConfig)
local Build = require(script.Parent.Build)

type Config = WorldConfig.Config
type Segment = WorldConfig.Segment
type Waypoint = WorldConfig.Waypoint

local RoadNetwork = {}

export type PathPoint = {
	position: Vector3, -- studs, on the road surface
	cframe: CFrame, -- at position, looking along the direction of travel
	halfWidth: number, -- studs
	distanceM: number, -- along the road from the start line
}
export type Path = { PathPoint }

export type Context = {
	cfg: Config,
	mps: number,
	s: (m: number) -> number, -- metres to studs
	world: Folder,
	surfaceY: number,
}

-- Heading convention: yaw 0 looks down -Z, matching the Phase 0 road. A
-- positive yaw turns right (+X), so a preset's direction = -1 turns left.
local function dirFromYaw(yaw: number): Vector3
	return Vector3.new(math.sin(yaw), 0, -math.cos(yaw))
end

--------------------------------------------------------------------------
-- Waypoints and the path
--------------------------------------------------------------------------

-- Expand segment descriptors into a waypoint list. Curves are chopped at
-- roughly curveSegmentM of arc; at a 400 m radius and 18 m steps the
-- polygonal road sits 10 cm inside the true arc, invisible on a 60 m width.
function RoadNetwork.expand(preset: WorldConfig.Preset, cfg: Config): { Waypoint }
	if preset.waypoints then
		return preset.waypoints
	end
	local out: { Waypoint } = {}
	local segments: { Segment } = preset.segments or {}
	local x, z, yaw = 0, 0, 0
	local width = if segments[1] then segments[1].widthM else 60
	table.insert(out, { xM = x, zM = z, widthM = width, bankingDeg = 0 })
	for _, seg in segments do
		local banking = seg.bankingDeg or 0
		if seg.kind == "straight" then
			local length = seg.lengthM or 0
			local steps = math.max(1, math.ceil(length / cfg.road.curveSegmentM))
			local step = length / steps
			for _ = 1, steps do
				local d = dirFromYaw(yaw)
				x += d.X * step
				z += d.Z * step
				table.insert(out, { xM = x, zM = z, widthM = seg.widthM, bankingDeg = banking })
			end
		elseif seg.kind == "curve" then
			local radius = seg.radiusM or 400
			local sweep = math.rad(seg.sweepDeg or 30)
			local turn = seg.direction or -1
			local arc = radius * sweep
			local steps = math.max(2, math.ceil(arc / cfg.road.curveSegmentM))
			local stepAngle = sweep / steps
			local chord = 2 * radius * math.sin(stepAngle / 2)
			for _ = 1, steps do
				-- Advance along the chord using the heading halfway through
				-- the step, which lands exactly on the arc.
				local midYaw = yaw + turn * stepAngle / 2
				local d = dirFromYaw(midYaw)
				x += d.X * chord
				z += d.Z * chord
				yaw += turn * stepAngle
				table.insert(out, { xM = x, zM = z, widthM = seg.widthM, bankingDeg = banking })
			end
		end
	end
	return out
end

-- Turn waypoints into path points carrying a stud position, a travel-aligned
-- CFrame, the half width and the distance travelled.
function RoadNetwork.toPath(waypoints: { Waypoint }, ctx: Context): Path
	local path: Path = {}
	local distance = 0
	for i, w in waypoints do
		local pos = Vector3.new(ctx.s(w.xM), ctx.surfaceY, ctx.s(w.zM))
		-- Look toward the next waypoint, or continue the last heading.
		local ahead: Vector3
		if i < #waypoints then
			local n = waypoints[i + 1]
			ahead = Vector3.new(ctx.s(n.xM), ctx.surfaceY, ctx.s(n.zM)) - pos
		else
			local prev = waypoints[i - 1]
			ahead = pos - Vector3.new(ctx.s(prev.xM), ctx.surfaceY, ctx.s(prev.zM))
		end
		if ahead.Magnitude < 1e-4 then
			ahead = Vector3.new(0, 0, -1)
		end
		local cf = CFrame.lookAt(pos, pos + ahead.Unit)
		if w.bankingDeg ~= 0 then
			cf = cf * CFrame.Angles(0, 0, math.rad(w.bankingDeg))
		end
		if i > 1 then
			local prev = path[i - 1]
			distance += (pos - prev.position).Magnitude * ctx.mps
		end
		table.insert(path, {
			position = pos,
			cframe = cf,
			halfWidth = ctx.s(w.widthM) / 2,
			distanceM = distance,
		})
	end
	return path
end

-- The dual carriageway layout, in metres, derived from the preset width.
export type Layout = {
	totalM: number, -- corridor width edge to edge
	medianM: number,
	carriagewayM: number, -- width of one carriageway
	centreM: number, -- lateral distance from the centreline to a carriageway centre
	innerEdgeM: number, -- centreline to the median-side asphalt edge
	outerEdgeM: number, -- centreline to the outer asphalt edge
}

function RoadNetwork.layout(path: Path, ctx: Context): Layout
	local totalM = path[1].halfWidth * 2 * ctx.mps
	local medianM = math.min(ctx.cfg.road.medianWidthM, totalM * 0.5)
	local cw = (totalM - medianM) / 2
	return {
		totalM = totalM,
		medianM = medianM,
		carriagewayM = cw,
		centreM = medianM / 2 + cw / 2,
		innerEdgeM = medianM / 2,
		outerEdgeM = medianM / 2 + cw,
	}
end

function RoadNetwork.lengthM(path: Path): number
	return path[#path].distanceM
end

-- Interpolated point at a distance along the road. Clamps at both ends.
function RoadNetwork.sample(path: Path, distanceM: number): PathPoint
	if distanceM <= 0 then
		return path[1]
	end
	local last = path[#path]
	if distanceM >= last.distanceM then
		return last
	end
	-- Linear scan is fine: this runs at build time only, and callers walk
	-- forward so the scan is short in practice.
	for i = 1, #path - 1 do
		local a, b = path[i], path[i + 1]
		if distanceM <= b.distanceM then
			local span = b.distanceM - a.distanceM
			local t = if span > 1e-6 then (distanceM - a.distanceM) / span else 0
			return {
				position = a.position:Lerp(b.position, t),
				cframe = a.cframe:Lerp(b.cframe, t),
				halfWidth = a.halfWidth + (b.halfWidth - a.halfWidth) * t,
				distanceM = distanceM,
			}
		end
	end
	return last
end

--------------------------------------------------------------------------
-- Ribbons: anything that runs along the road at a lateral offset
--------------------------------------------------------------------------

export type RibbonOpts = {
	name: string,
	parent: Instance,
	path: Path,
	ctx: Context,
	offsetM: number, -- lateral, positive is to the right of travel
	widthM: number,
	heightM: number,
	yM: number, -- centre height above the road surface
	color: Color3,
	material: Enum.Material?,
	collide: boolean?,
	query: boolean?,
	transparency: number?,
	fromM: number?,
	toM: number?,
	-- Follows the road half width instead of a fixed offset when set: used
	-- for edge lines and shoulders, which must track a widening road.
	edgeRelative: boolean?,
	-- Lateral position as a fraction of the road half width (-1 left edge,
	-- +1 right edge), plus offsetM. This is how lane-relative things stay put
	-- when the road widens.
	fracOffset: number?,
	-- Takes its width from the road itself rather than widthM. Used for the
	-- asphalt, whose width can vary per waypoint.
	widthFromPath: boolean?,
	castShadow: boolean?,
	-- Overrides road.maxMergedRunM for this ribbon. The 80 m cap exists so
	-- streamed parts appear when approached; the Road model is Persistent,
	-- so its long thin strips (tyre tracks, edge lines, shoulders, median)
	-- can run to the engine limit and cost a quarter of the parts.
	runCapM: number?,
	-- Replaces the default single box per run. The CFrame is at the middle
	-- of the run looking along the road, so in that frame local X is lateral,
	-- local Y is up and local Z is along the road. Used to build a profile
	-- (the jersey barrier) or a set of stripes instead of one slab.
	emit: ((cf: CFrame, length: number, width: number, runIndex: number) -> ())?,
}

-- Emits one part per straight run, splitting only at the 2048 stud cap.
function RoadNetwork.ribbon(o: RibbonOpts): number
	local ctx = o.ctx
	local cfg = ctx.cfg
	local path = o.path
	local fromM = o.fromM or 0
	local toM = o.toM or RoadNetwork.lengthM(path)
	if toM <= fromM then
		return 0
	end

	-- Collect the centre line of this ribbon, in order.
	local pts: { Vector3 } = {}
	local dirs: { Vector3 } = {}
	local widths: { number } = {}
	local function push(p: PathPoint)
		local lateral = ctx.s(o.offsetM)
		if o.fracOffset then
			lateral = o.fracOffset * p.halfWidth + ctx.s(o.offsetM)
		elseif o.edgeRelative then
			lateral = p.halfWidth + ctx.s(o.offsetM)
			if o.offsetM < 0 then
				lateral = -p.halfWidth + ctx.s(o.offsetM)
			end
		end
		local pos = p.position + p.cframe.RightVector * lateral + Vector3.new(0, ctx.s(o.yM), 0)
		table.insert(pts, pos)
		table.insert(dirs, p.cframe.LookVector)
		table.insert(widths, p.halfWidth * 2)
	end
	push(RoadNetwork.sample(path, fromM))
	for _, p in path do
		if p.distanceM > fromM and p.distanceM < toM then
			push(p)
		end
	end
	push(RoadNetwork.sample(path, toM))

	-- Group into runs of consistent heading.
	local threshold = math.cos(math.rad(cfg.road.straightThresholdDeg))
	local runs: { { number } } = {}
	local startIdx = 1
	for i = 2, #pts - 1 do
		if dirs[i]:Dot(dirs[i + 1]) < threshold then
			table.insert(runs, { startIdx, i })
			startIdx = i
		end
	end
	table.insert(runs, { startIdx, #pts })

	local made = 0
	local height = ctx.s(o.heightM)
	local overlap = ctx.s(cfg.road.jointOverlapM)
	local runIndex = 0
	for _, run in runs do
		runIndex += 1
		local a, b = pts[run[1]], pts[run[2]]
		-- A run that spans a widening stretch takes the widest width in it,
		-- so the asphalt never pinches in below the road it represents.
		local width = ctx.s(o.widthM)
		if o.widthFromPath then
			width = 0
			for i = run[1], run[2] do
				width = math.max(width, widths[i])
			end
		end
		local delta = b - a
		local span = delta.Magnitude
		if span > 1e-3 then
			local unit = delta.Unit
			-- A run that is a single curved step gets the joint overlap; a
			-- merged straight run butts exactly against its neighbours.
			local curved = (run[2] - run[1]) == 1 and #runs > 1
			-- Chop at the streaming-friendly length, never above the engine cap.
			local capStuds = math.min(ctx.s(o.runCapM or cfg.road.maxMergedRunM), Build.MAX_PART_STUDS)
			local pieces = math.max(1, math.ceil(span / capStuds))
			local pieceLen = span / pieces
			for i = 0, pieces - 1 do
				local segStart = a + unit * (i * pieceLen)
				local len = pieceLen + (if curved then overlap else 0)
				local mid = segStart + unit * (pieceLen / 2)
				local cf = CFrame.lookAt(mid, mid + unit)
				if o.emit then
					o.emit(cf, len, width, runIndex)
				else
					Build.part({
						name = o.name,
						size = Vector3.new(width, height, len),
						cframe = cf,
						color = o.color,
						material = o.material,
						parent = o.parent,
						collide = o.collide,
						query = o.query,
						transparency = o.transparency,
						castShadow = o.castShadow,
					})
				end
				made += 1
			end
		end
	end
	return made
end

-- Small parts repeated along the road: dashes, reflectors, markers.
function RoadNetwork.repeatAlong(
	path: Path,
	ctx: Context,
	spacingM: number,
	fromM: number,
	toM: number,
	place: (p: PathPoint, index: number) -> ()
): number
	if spacingM <= 0 then
		return 0
	end
	local n = 0
	local d = fromM
	while d <= toM do
		n += 1
		place(RoadNetwork.sample(path, d), n)
		d += spacingM
	end
	return n
end

--------------------------------------------------------------------------
-- Build
--------------------------------------------------------------------------

local function buildGround(ctx: Context, path: Path, parent: Instance): number
	local cfg = ctx.cfg
	local g = cfg.ground
	local minX, maxX = math.huge, -math.huge
	local minZ, maxZ = math.huge, -math.huge
	for _, p in path do
		minX = math.min(minX, p.position.X)
		maxX = math.max(maxX, p.position.X)
		minZ = math.min(minZ, p.position.Z)
		maxZ = math.max(maxZ, p.position.Z)
	end
	local margin = ctx.s(g.marginM)
	minX, maxX = minX - margin, maxX + margin
	minZ, maxZ = minZ - margin, maxZ + margin

	local tile = ctx.s(g.tileM)
	local thickness = ctx.s(g.thicknessM)
	local y = ctx.surfaceY - ctx.s(g.dropM) - thickness / 2
	local nearStart, farStart = ctx.s(g.nearStartM), ctx.s(g.farStartM)
	local splitDistance = ctx.s(g.splitDistanceM)
	local noiseScale = ctx.s(g.tintNoiseScaleM)
	local made = 0
	-- Nearest approach to the road, in studs.
	local function distance(cx: number, cz: number): number
		local nearest = math.huge
		for _, p in path do
			local dx, dz = p.position.X - cx, p.position.Z - cz
			nearest = math.min(nearest, dx * dx + dz * dz)
		end
		return math.sqrt(nearest)
	end
	-- Tone: a smooth blend from near to far by distance, then a slow noise
	-- tint so neighbouring pieces differ a little, like real ground.
	local function tone(cx: number, cz: number, nearest: number): Color3
		local t = math.clamp((nearest - nearStart) / math.max(farStart - nearStart, 1), 0, 1)
		local c = g.nearColor:Lerp(g.farColor, t)
		local n = math.noise(cx / noiseScale, cz / noiseScale, 7.31) * g.tintVariation
		return if n < 0 then c:Lerp(Color3.new(0, 0, 0), -n) else c:Lerp(Color3.new(1, 1, 1), n)
	end
	local function slab(cx: number, cz: number, size: number, nearest: number)
		Build.part({
			name = "Sand",
			size = Vector3.new(size, thickness, size),
			cframe = CFrame.new(cx, y, cz),
			color = tone(cx, cz, nearest),
			material = Enum.Material.Sand,
			parent = parent,
			collide = true,
		})
		made += 1
	end
	local nx = math.ceil((maxX - minX) / tile)
	local nz = math.ceil((maxZ - minZ) / tile)
	for ix = 0, nx - 1 do
		for iz = 0, nz - 1 do
			local cx = minX + (ix + 0.5) * tile
			local cz = minZ + (iz + 0.5) * tile
			local nearest = distance(cx, cz)
			if nearest < splitDistance and g.splitN > 1 then
				-- Near the road: cut the tile so the blend and the tint
				-- noise vary across it.
				local n = g.splitN
				local sub = tile / n
				for sx = 0, n - 1 do
					for sz = 0, n - 1 do
						local px = cx - tile / 2 + (sx + 0.5) * sub
						local pz = cz - tile / 2 + (sz + 0.5) * sub
						slab(px, pz, sub, distance(px, pz))
					end
				end
			else
				slab(cx, cz, tile, nearest)
			end
		end
	end
	return made
end

-- Tyre tracks, seams and patches, per carriageway. Everything here is
-- cosmetic and sits at markingEpsilon, so the suspension raycast never sees
-- a step.
local function buildWear(ctx: Context, path: Path, parent: Instance, asphalt: Color3, lay: Layout)
	local r = ctx.cfg.road
	local w = r.wear
	local rng = Build.rng(w.seed)
	local totalM = RoadNetwork.lengthM(path)
	local yM = r.markingEpsilonM * 0.5

	for _, side in { -1, 1 } do
		if w.tyreTracksEnabled then
			local dark = asphalt:Lerp(Color3.new(0, 0, 0), w.tyreTrackDarken)
			for lane = 1, r.laneCount do
				local laneCentre = lay.innerEdgeM + lay.carriagewayM * (lane - 0.5) / r.laneCount
				for _, sign in { -1, 1 } do
					RoadNetwork.ribbon({
						name = "TyreTrack",
						runCapM = r.longRunM,
						parent = parent,
						path = path,
						ctx = ctx,
						offsetM = side * (laneCentre + sign * w.tyreTrackGapM / 2),
						widthM = w.tyreTrackWidthM,
						heightM = r.markingThicknessM,
						yM = yM,
						color = dark,
						material = Enum.Material.Asphalt,
					})
				end
			end
		end

		if w.seamsEnabled then
			local seamColor = asphalt:Lerp(Color3.new(0, 0, 0), w.seamDarken)
			RoadNetwork.repeatAlong(path, ctx, r.maxMergedRunM, r.maxMergedRunM, totalM, function(p)
				local pos = p.position + p.cframe.RightVector * (side * ctx.s(lay.centreM)) + Vector3.new(0, ctx.s(yM), 0)
				Build.part({
					name = "Seam",
					size = Vector3.new(ctx.s(lay.carriagewayM), ctx.s(r.markingThicknessM), ctx.s(w.seamWidthM)),
					cframe = CFrame.lookAt(pos, pos + p.cframe.LookVector),
					color = seamColor,
					material = Enum.Material.Asphalt,
					parent = parent,
				})
			end)
		end

		if w.patchesEnabled then
			RoadNetwork.repeatAlong(path, ctx, w.patchSpacingM, w.patchSpacingM * (if side < 0 then 0.5 else 1), totalM, function(p)
				if rng:NextNumber() > w.patchChance then
					return
				end
				local tone = rng:NextNumber(-w.patchTone, w.patchTone)
				local color = if tone < 0
					then asphalt:Lerp(Color3.new(0, 0, 0), -tone)
					else asphalt:Lerp(Color3.new(1, 1, 1), tone)
				local length = ctx.s(rng:NextNumber(w.patchMinLengthM, w.patchMaxLengthM))
				local width = ctx.s(rng:NextNumber(2, 6))
				local lateral = side * ctx.s(lay.innerEdgeM + lay.carriagewayM * rng:NextNumber(0.08, 0.92))
				local pos = p.position + p.cframe.RightVector * lateral + Vector3.new(0, ctx.s(yM * 0.9), 0)
				Build.part({
					name = "Patch",
					size = Vector3.new(width, ctx.s(r.markingThicknessM), length),
					cframe = CFrame.lookAt(pos, pos + p.cframe.LookVector),
					color = color,
					material = Enum.Material.Asphalt,
					parent = parent,
				})
			end)
		end
	end
end

local function buildMarkings(ctx: Context, path: Path, parent: Instance, asphalt: Color3, lay: Layout)
	local cfg = ctx.cfg
	local r = cfg.road
	local w = r.wear
	local rng = Build.rng(w.seed + 1)
	local totalM = RoadNetwork.lengthM(path)
	local yM = r.markingEpsilonM
	local thick = r.markingThicknessM

	-- Paint is bleached and driven over, never crisp white.
	local function wornPaint(): (Color3, number)
		local amount = rng:NextNumber(0, w.markingWear)
		return r.paintColor:Lerp(asphalt, amount), rng:NextNumber(0, w.markingFadeMax)
	end

	local dashLen = ctx.s(r.dashLengthM)
	local dashWidth = ctx.s(r.dashWidthM)
	local cycle = r.dashLengthM + r.dashGapM
	for _, side in { -1, 1 } do
		-- Solid edge lines on both edges of each carriageway.
		for _, edge in { lay.innerEdgeM + 0.4, lay.outerEdgeM - 0.4 } do
			local color, fade = wornPaint()
			RoadNetwork.ribbon({
				name = "EdgeLine",
				runCapM = r.longRunM,
				parent = parent,
				path = path,
				ctx = ctx,
				offsetM = side * edge,
				widthM = r.edgeLineWidthM,
				heightM = thick,
				yM = yM,
				color = color,
				material = Enum.Material.Concrete,
				transparency = fade * 0.5,
			})
		end
		-- Dashed dividers between lanes.
		for lane = 1, math.max(0, r.laneCount - 1) do
			local lateralM = side * (lay.innerEdgeM + lay.carriagewayM * lane / r.laneCount)
			RoadNetwork.repeatAlong(path, ctx, cycle, r.dashLengthM / 2, totalM, function(p)
				local color, fade = wornPaint()
				local pos = p.position + p.cframe.RightVector * ctx.s(lateralM) + Vector3.new(0, ctx.s(yM), 0)
				Build.part({
					name = "Dash",
					size = Vector3.new(dashWidth, ctx.s(thick), dashLen * rng:NextNumber(0.94, 1.0)),
					cframe = CFrame.lookAt(pos, pos + p.cframe.LookVector),
					color = color,
					material = Enum.Material.Concrete,
					parent = parent,
					transparency = fade,
				})
			end)
		end
	end
end

function RoadNetwork.build(cfg: Config, world: Folder): (Model, Path, Context)
	local mps = cfg.units.metersPerStud
	local function s(m: number): number
		return Units.mToStuds(m, mps)
	end
	local ctx: Context = { cfg = cfg, mps = mps, s = s, world = world, surfaceY = 0 }

	local preset = cfg.presets[cfg.preset] or cfg.presets.testRoad
	local waypoints = RoadNetwork.expand(preset, cfg)
	local path = RoadNetwork.toPath(waypoints, ctx)
	local totalM = RoadNetwork.lengthM(path)
	local r = cfg.road

	local road = Instance.new("Model")
	road.Name = "Road"

	-- Ground first so the asphalt draws over it at the edges.
	local groundFolder = Build.folder("Ground", road)
	buildGround(ctx, path, groundFolder)

	local lay = RoadNetwork.layout(path, ctx)

	-- Median: a strip of ground between the carriageways, a hair below the
	-- asphalt, with a lip of kerb on each side. Collidable because it IS the
	-- ground the car drives onto when it runs wide on the inside.
	local medianFolder = Build.folder("Median", road)
	RoadNetwork.ribbon({
		name = "Median",
		runCapM = r.longRunM,
		parent = medianFolder,
		path = path,
		ctx = ctx,
		offsetM = 0,
		widthM = lay.medianM,
		heightM = r.thicknessM,
		yM = -r.thicknessM / 2 - r.medianDropM,
		color = r.medianColor,
		material = r.medianMaterial,
		collide = true,
	})
	for _, side in { -1, 1 } do
		RoadNetwork.ribbon({
			name = "Kerb",
			runCapM = r.longRunM,
			parent = medianFolder,
			path = path,
			ctx = ctx,
			offsetM = side * (lay.innerEdgeM - r.kerbWidthM / 2),
			widthM = r.kerbWidthM,
			heightM = r.kerbHeightM,
			yM = r.kerbHeightM / 2 - 0.01,
			color = r.kerbColor,
			material = Enum.Material.Concrete,
		})
	end

	-- Outer shoulders and kerbs. Shoulders are ground; kerbs are a lip.
	local shoulderFolder = Build.folder("Shoulders", road)
	for _, side in { -1, 1 } do
		RoadNetwork.ribbon({
			name = "Shoulder",
			runCapM = r.longRunM,
			parent = shoulderFolder,
			path = path,
			ctx = ctx,
			offsetM = side * (r.shoulderWidthM / 2),
			edgeRelative = true,
			widthM = r.shoulderWidthM,
			heightM = r.thicknessM,
			yM = -r.thicknessM / 2,
			color = r.shoulderColor,
			material = Enum.Material.Concrete,
			collide = true,
		})
		RoadNetwork.ribbon({
			name = "Kerb",
			runCapM = r.longRunM,
			parent = shoulderFolder,
			path = path,
			ctx = ctx,
			offsetM = side * (r.shoulderWidthM + r.kerbWidthM / 2),
			edgeRelative = true,
			widthM = r.kerbWidthM,
			heightM = r.kerbHeightM,
			yM = r.kerbHeightM / 2 - 0.01,
			color = r.kerbColor,
			material = Enum.Material.Concrete,
		})
	end

	-- Two carriageways. Every slab a slightly different shade: asphalt is
	-- laid in passes and weathers unevenly, and one flat colour over two
	-- kilometres is the tell.
	local surfaceFolder = Build.folder("Surface", road)
	local slabRng = Build.rng(r.wear.seed + 2)
	for _, side in { -1, 1 } do
		RoadNetwork.ribbon({
			name = "Asphalt",
			parent = surfaceFolder,
			path = path,
			ctx = ctx,
			offsetM = side * lay.centreM,
			widthM = lay.carriagewayM,
			heightM = r.thicknessM,
			yM = -r.thicknessM / 2,
			color = r.asphaltColor,
			material = Enum.Material.Asphalt,
			collide = true,
			emit = function(cf, length, width)
				local tone = slabRng:NextNumber(-r.wear.slabTone, r.wear.slabTone)
				local color = if tone < 0
					then r.asphaltColor:Lerp(Color3.new(0, 0, 0), -tone)
					else r.asphaltColor:Lerp(Color3.new(1, 1, 1), tone)
				Build.part({
					name = "Asphalt",
					size = Vector3.new(width, s(r.thicknessM), length),
					cframe = cf,
					color = color,
					material = Enum.Material.Asphalt,
					parent = surfaceFolder,
					collide = true,
				})
			end,
		})
	end

	-- Transition pad: flush wings outside each carriageway.
	local pad = preset.pad
	if pad and pad.widthM > 0 then
		local padFolder = Build.folder("TransitionPad", road)
		local wing = (pad.widthM - lay.totalM) / 2
		if wing > 0 then
			for _, side in { -1, 1 } do
				RoadNetwork.ribbon({
					name = "PadWing",
					parent = padFolder,
					path = path,
					ctx = ctx,
					offsetM = side * (wing / 2),
					edgeRelative = true,
					widthM = wing,
					heightM = r.thicknessM,
					yM = -r.thicknessM / 2,
					color = r.padColor,
					material = Enum.Material.Asphalt,
					collide = true,
					fromM = pad.startM,
					toM = pad.startM + pad.lengthM,
				})
			end
			road:SetAttribute("PadStartStuds", -s(pad.startM))
			road:SetAttribute("PadEndStuds", -(s(pad.startM + pad.lengthM)))
		end
	end

	-- Markings and wear go in a sibling model, not under Road. Road is
	-- Persistent so the car always has a surface, and a child of a
	-- Persistent model is Persistent too, which meant every client held all
	-- twelve hundred dashes and tyre tracks at all times. None of that is
	-- physics; it can stream in as the car approaches like any decoration.
	local detail = Instance.new("Model")
	detail.Name = "RoadDetail"
	local wearFolder = Build.folder("Wear", detail)
	buildWear(ctx, path, wearFolder, r.asphaltColor, lay)
	local markingFolder = Build.folder("Markings", detail)
	buildMarkings(ctx, path, markingFolder, r.asphaltColor, lay)
	detail.Parent = workspace

	-- Parking bay and the player spawn. On the transition pad's right-hand
	-- wing when the preset has one (the owner wanted to start in the wide
	-- section, off to the side of the traffic), behind the start line
	-- otherwise. The bay is a marked slab a centimetre proud of the wing so
	-- the two never z-fight; the car settles onto it on spawn.
	local bayLen = s(preset.bayLengthM)
	local start = path[1]
	local bayCf: CFrame
	local bayW: number
	if pad and pad.widthM > lay.totalM + 40 then
		local at = RoadNetwork.sample(path, pad.startM + pad.lengthM / 2)
		local wing = (pad.widthM - lay.totalM) / 2
		local lateral = at.halfWidth + s(wing / 2)
		bayW = s(math.min(wing - 8, 44))
		local pos = at.position + at.cframe.RightVector * lateral + Vector3.new(0, s(0.01) - s(r.thicknessM) / 2, 0)
		bayCf = CFrame.lookAt(pos, pos + at.cframe.LookVector)
	else
		bayW = start.halfWidth * 2
		local bayPos = start.position - start.cframe.LookVector * (bayLen / 2) - Vector3.new(0, s(r.thicknessM) / 2, 0)
		bayCf = CFrame.lookAt(bayPos, bayPos + start.cframe.LookVector)
	end
	local bay = Build.part({
		name = "Bay",
		size = Vector3.new(bayW, s(r.thicknessM), bayLen),
		cframe = bayCf,
		color = r.bayColor,
		material = Enum.Material.Concrete,
		parent = road,
		collide = true,
	})

	local existingSpawn = workspace:FindFirstChild("SpawnLocation")
	if existingSpawn then
		existingSpawn:Destroy()
	end
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "PlayerSpawn"
	spawn.Anchored = true
	spawn.CanCollide = true
	spawn.Size = Vector3.new(8, 1, 8)
	-- Behind the bay, not in it. CarSpawner parks cars across the bay's
	-- width, and a one stud collidable pad among the slots is something a car
	-- can end up balanced on.
	spawn.CFrame = bay.CFrame * CFrame.new(0, s(r.thicknessM) / 2 + 0.5, bayLen / 2 + s(6))
	spawn.Neutral = true
	spawn.CastShadow = false
	spawn.Parent = road

	-- Contract with the vehicle code. These names and meanings are read by
	-- CarSpawner and VehicleController and must not change.
	local straightM = totalM
	local presetSegments: { Segment } = preset.segments or {}
	local first = presetSegments[1]
	if first and first.kind == "straight" and first.lengthM then
		straightM = first.lengthM
	end
	road:SetAttribute("StartCFrame", CFrame.new(start.position))
	road:SetAttribute("LengthStuds", s(straightM))
	road:SetAttribute("HalfWidthStuds", start.halfWidth)
	road:SetAttribute("BayCFrame", bay.CFrame * CFrame.new(0, s(r.thicknessM) / 2, 0))
	road:SetAttribute("SurfaceY", ctx.surfaceY)
	road:SetAttribute("TotalLengthStuds", s(totalM))
	if cfg.streaming.enabled and cfg.streaming.roadPersistent then
		local ok = pcall(function()
			road.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
		end)
		if not ok then
			warn("[World] could not make the road persistent; the car may fall through unstreamed road")
		end
	end
	road.Parent = workspace

	return road, path, ctx
end

return RoadNetwork
