--!strict
-- The dune field: a natural border on the sunset side of the highway.
--
-- Everything here is a sand ellipsoid (a Part with a sphere SpecialMesh,
-- which unlike a Ball part renders at any aspect) rolled about its long axis
-- so the side facing the road is the steep slip face and the far side the
-- gentle windward slope, then sunk so the foot is buried in the sand plane.
-- Long ridges run parallel to the road, crescents point their horns at it,
-- and low mounds fade the field in from the inner edge. Sandstone outcrops
-- are store meshes from AssetRegistry.
--
-- The field starts far enough out that no crest rises above the sun: the
-- build prints the tallest crest angle seen from the road next to the sun's
-- elevation so that stays checked. Nothing in it is collidable, and the
-- whole model is Persistent because it sits past the streaming radius.
local Lighting = game:GetService("Lighting")
local WorldConfig = require(script.Parent.WorldConfig)
local Build = require(script.Parent.Build)
local RoadNetwork = require(script.Parent.RoadNetwork)
local AssetRegistry = require(script.Parent.AssetRegistry)

type Config = WorldConfig.Config
type Context = RoadNetwork.Context
type Path = RoadNetwork.Path

local Dunes = {}

-- Which side of the road the field is on: +1 is the road's right (its
-- RightVector), -1 its left. "sun" reads Lighting at build time, so a
-- change of time-of-day preset moves the field with the sunset.
function Dunes.sideSign(cfg: Config, path: Path): number
	local f = cfg.duneField
	if f.side == "right" then
		return 1
	elseif f.side == "left" then
		return -1
	end
	local mid = path[math.max(1, math.floor(#path / 2))]
	local sun = Lighting:GetSunDirection()
	return if sun:Dot(mid.cframe.RightVector) >= 0 then 1 else -1
end

-- Road-relative coordinates of a world position: metres along the road,
-- extrapolated in a straight line past either end, and signed lateral
-- metres (+ is the road's right).
local function roadCoords(ctx: Context, path: Path, pos: Vector3): (number, number)
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
	local along = best.distanceM + rel:Dot(best.cframe.LookVector) * ctx.mps
	local lateral = rel:Dot(best.cframe.RightVector) * ctx.mps
	return along, lateral
end

-- True when a skyline site would stand behind the field as seen from the
-- road. Cityscape drops those so the sunset side is dunes against sky.
function Dunes.behind(cfg: Config, ctx: Context, path: Path, pos: Vector3): boolean
	local f = cfg.duneField
	if not f.enabled or not f.clearSkylineBehind then
		return false
	end
	local along, lateral = roadCoords(ctx, path, pos)
	local side = Dunes.sideSign(cfg, path)
	return lateral * side > f.innerM and along > f.startM - f.skylineMarginM and along < f.endM + f.skylineMarginM
end

local function tint(rng: Random, base: Color3, variation: number): Color3
	local t = rng:NextNumber(-variation, variation)
	return if t < 0 then base:Lerp(Color3.new(0, 0, 0), -t) else base:Lerp(Color3.new(1, 1, 1), t)
end

function Dunes.build(cfg: Config, ctx: Context, path: Path, parent: Instance): Model
	local f = cfg.duneField
	local model = Instance.new("Model")
	model.Name = "Dunes"
	model.Parent = parent
	local rng = Build.rng(f.seed)
	local side = Dunes.sideSign(cfg, path)
	local depthM = f.outerM - f.innerM
	local totalM = RoadNetwork.lengthM(path)
	local groundY = ctx.surfaceY - ctx.s(cfg.ground.dropM)

	-- Road frame at a distance along it, continuing straight past the ends.
	local function frame(d: number): (Vector3, CFrame)
		if d < 0 then
			local p = path[1]
			return p.position + p.cframe.LookVector * ctx.s(d), p.cframe
		elseif d > totalM then
			local p = path[#path]
			return p.position + p.cframe.LookVector * ctx.s(d - totalM), p.cframe
		end
		local p = RoadNetwork.sample(path, d)
		return p.position, p.cframe
	end

	-- World position of a spot (along the road, depth into the field from
	-- its inner edge), plus the road's rotation there.
	local function at(along: number, depth: number): (Vector3, CFrame)
		local pos, cf = frame(along)
		local p = pos + cf.RightVector * ctx.s(side * (f.innerM + depth))
		return Vector3.new(p.X, groundY, p.Z), cf.Rotation
	end

	-- Crest height envelope by depth: a smooth rise to full height.
	local function envelope(depth: number): number
		local t = math.clamp(depth / f.fullDepthM, 0, 1)
		t = t * t * (3 - 2 * t)
		return f.edgeHeightM + (f.fullHeightM - f.edgeHeightM) * t
	end

	local noiseZ = (f.seed % 977) / 7.3
	local function open(along: number, depth: number): boolean
		return math.noise(along / f.gapNoiseScaleM, depth / f.gapNoiseScaleM, noiseZ) > f.gapThreshold
	end

	-- The tallest crest as an angle above the horizon from the road centre
	-- at the same distance along, for the sun check in the report.
	local tallestDeg = 0
	local function note(heightM: number, depth: number)
		tallestDeg = math.max(tallestDeg, math.deg(math.atan(heightM / (f.innerM + depth))))
	end

	-- Spacing lists, one per kind: ridges keep clear of ridges, crescents
	-- of crescents, and the kinds are free to overlap each other, which is
	-- what makes the field read as one surface.
	type Spot = { pos: Vector3, radius: number }
	local function free(list: { Spot }, pos: Vector3, radius: number): boolean
		for _, t in list do
			if (t.pos - pos).Magnitude < t.radius + radius then
				return false
			end
		end
		table.insert(list, { pos = pos, radius = radius })
		return true
	end
	local ridgeSpots: { Spot } = {}
	local seifSpots: { Spot } = {}
	local barchanSpots: { Spot } = {}

	local forms = 0

	-- One ellipsoid. widthM is across the form (the roll axis is its
	-- length), heightM is the crest height above the sand after the roll
	-- and the sink, lengthM runs along local Z. rot is the road's rotation;
	-- yaw turns the length off the road line; roll is signed so that a
	-- positive value lifts local +X, which makes that side the steep one.
	local function ellipsoid(
		name: string,
		widthM: number,
		heightM: number,
		lengthM: number,
		pos: Vector3,
		rot: CFrame,
		yaw: number,
		roll: number,
		sinkFrac: number,
		color: Color3,
		castShadow: boolean
	): Part
		local a = ctx.s(widthM) / 2
		local b = ctx.s(heightM / (1 - sinkFrac)) / 2
		-- Highest point of the rolled ellipse above its centre.
		local top = math.sqrt((a * math.sin(roll)) ^ 2 + (b * math.cos(roll)) ^ 2)
		local centreY = groundY + ctx.s(heightM) - top
		local p = Instance.new("Part")
		p.Name = name
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = castShadow
		p.Material = Enum.Material.Sand
		p.Color = color
		p.Size = Vector3.new(a * 2, b * 2, ctx.s(lengthM))
		p.CFrame = CFrame.new(pos.X, centreY, pos.Z) * rot * CFrame.Angles(0, yaw, 0) * CFrame.Angles(0, 0, roll)
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Parent = p
		p.Parent = model
		forms += 1
		return p
	end

	-- In the road frame local +X is the road's right. On the left side the
	-- road lies at local +X of a form, on the right side at local -X, so
	-- rolling by -side * tilt always steepens the road-facing side.
	local towardRoad = -side

	-- Broad flat sheets first, under everything else.
	local sh = f.sheets
	for _ = 1, sh.count do
		local along = rng:NextNumber(f.startM, f.endM)
		local depth = rng:NextNumber(0, depthM)
		local pos, rot = at(along, depth)
		local length = rng:NextNumber(sh.minLengthM, sh.maxLengthM)
		local width = rng:NextNumber(sh.minWidthM, sh.maxWidthM)
		local height = rng:NextNumber(sh.minHeightM, sh.maxHeightM)
		local yaw = math.rad(rng:NextNumber(-30, 30))
		ellipsoid("Sheet", width, height, length, pos, rot, yaw, 0, sh.sink, tint(rng, f.moundColor, f.colorVariation), false)
	end

	-- Long seif ridges parallel to the road, the bulk of the silhouette.
	local r = f.ridges
	for _ = 1, r.count do
		local along = rng:NextNumber(f.startM, f.endM)
		local depth = rng:NextNumber(60, depthM - 40)
		if not open(along, depth) then
			continue
		end
		local length = rng:NextNumber(r.minLengthM, r.maxLengthM)
		local pos, rot = at(along, depth)
		if not free(ridgeSpots, pos, ctx.s(length * r.spacingFrac)) then
			continue
		end
		local height = envelope(depth) * rng:NextNumber(r.minHeightFrac, r.maxHeightFrac)
		local width = rng:NextNumber(r.minWidthM, r.maxWidthM)
		local yaw = math.rad(rng:NextNumber(-r.yawJitterDeg, r.yawJitterDeg))
		local roll = towardRoad * math.rad(rng:NextNumber(r.minTiltDeg, r.maxTiltDeg))
		ellipsoid("Ridge", width, height, length, pos, rot, yaw, roll, r.sink, tint(rng, f.color, f.colorVariation), cfg.shadows.dunes)
		note(height, depth)
	end

	-- Sharp-crested seifs. A WedgePart's tall face is at its +Z end and the
	-- slope runs down to -Z, so each half is yawed to put its tall face on
	-- the crest line: the windward half slopes away from the road, the
	-- slip face toward it. The prism is buried by its sink and its cut ends
	-- are covered by a mound each.
	local sf = f.seifs
	for _ = 1, sf.count do
		local along = rng:NextNumber(f.startM, f.endM)
		local depth = rng:NextNumber(80, depthM - 60)
		if not open(along, depth) then
			continue
		end
		local length = rng:NextNumber(sf.minLengthM, sf.maxLengthM)
		local pos, rot = at(along, depth)
		if not free(seifSpots, pos, ctx.s(length * sf.spacingFrac)) then
			continue
		end
		local height = envelope(depth) * rng:NextNumber(sf.minHeightFrac, sf.maxHeightFrac)
		local full = height * (1 + sf.sink) -- prism height including the buried part
		local lee = full / math.tan(math.rad(sf.slipFaceDeg))
		local wind = full / math.tan(math.rad(sf.windwardDeg))
		local yaw = math.rad(rng:NextNumber(-sf.yawJitterDeg, sf.yawJitterDeg))
		local color = tint(rng, f.color, f.colorVariation)
		local base = CFrame.new(pos) * rot * CFrame.Angles(0, yaw, 0)
		local centreY = ctx.s(full) / 2 - ctx.s(height * sf.sink)
		for _, half in { { width = wind, dir = -towardRoad }, { width = lee, dir = towardRoad } } do
			-- Local -Z (the slope's low edge) must point along half.dir.
			local wyaw = -half.dir * math.pi / 2
			Build.wedge({
				name = "Seif",
				size = Vector3.new(ctx.s(length), ctx.s(full), ctx.s(half.width)),
				cframe = base * CFrame.new(half.dir * ctx.s(half.width) / 2, centreY, 0) * CFrame.Angles(0, wyaw, 0),
				color = color,
				material = Enum.Material.Sand,
				parent = model,
				castShadow = cfg.shadows.dunes,
			})
			forms += 1
		end
		-- End mounds, centred on the crest line at each end of the prism.
		local across = wind + lee
		local crestX = towardRoad * (lee - wind) / 2
		for _, sgn in { -1, 1 } do
			local endPos = pos + rot:VectorToWorldSpace(Vector3.new(0, 0, 0))
			local offset = base:VectorToWorldSpace(Vector3.new(ctx.s(crestX), 0, sgn * ctx.s(length) / 2))
			ellipsoid("SeifEnd", across * 0.85, height * 0.8, across * 0.7, endPos + offset, rot, yaw, 0, 0.45, color, cfg.shadows.dunes)
		end
		note(height, depth)
	end

	-- Crescents: a body lying across the wind (so along the road) with two
	-- horns swept toward the road.
	local bc = f.barchans
	for _ = 1, bc.count do
		local along = rng:NextNumber(f.startM, f.endM)
		local depth = rng:NextNumber(40, depthM - 60)
		if not open(along, depth) then
			continue
		end
		local body = rng:NextNumber(bc.minBodyM, bc.maxBodyM)
		local pos, rot = at(along, depth)
		if not free(barchanSpots, pos, ctx.s(body * 0.45)) then
			continue
		end
		local height = envelope(depth) * rng:NextNumber(bc.minHeightFrac, bc.maxHeightFrac)
		local across = rng:NextNumber(bc.minDepthM, bc.maxDepthM)
		local color = tint(rng, f.color, f.colorVariation)
		local roll = towardRoad * math.rad(bc.tiltDeg)
		ellipsoid("Barchan", across, height, body, pos, rot, 0, roll, bc.sink, color, cfg.shadows.dunes)
		local hornLen = body * bc.hornLengthFrac
		local hornW = body * bc.hornWidthFrac
		local hornH = height * bc.hornHeightFrac
		local phi = math.rad(bc.hornAngleDeg)
		for _, sgn in { -1, 1 } do
			-- Horn direction in the road frame: toward the road, splayed
			-- outward along the road line.
			local dir = Vector3.new(towardRoad * math.cos(phi), 0, sgn * math.sin(phi))
			local centreM = Vector3.new(towardRoad * across * 0.2, 0, sgn * body * 0.36) + dir * (hornLen * 0.5)
			local hornPos = pos + rot:VectorToWorldSpace(Vector3.new(ctx.s(centreM.X), 0, ctx.s(centreM.Z)))
			-- Yaw so the horn's length (local Z) follows dir.
			local yaw = math.atan2(dir.X, dir.Z)
			ellipsoid("Horn", hornW, hornH, hornLen, hornPos, rot, yaw, 0, bc.sink, color, cfg.shadows.dunes)
		end
		note(height, depth)
	end

	-- Low mounds and sheets, thickest near the inner edge.
	local m = f.mounds
	for _ = 1, m.count do
		local along = rng:NextNumber(f.startM, f.endM)
		local depth = (rng:NextNumber() ^ m.innerBias) * depthM
		local width = rng:NextNumber(m.minWidthM, m.maxWidthM)
		local pos, rot = at(along, depth)
		local height = rng:NextNumber(m.minHeightM, m.maxHeightM)
		local length = width * rng:NextNumber(1, m.elongation)
		local yaw = rng:NextNumber(-math.pi, math.pi)
		ellipsoid("Mound", width, height, length, pos, rot, yaw, 0, m.sink, tint(rng, f.moundColor, f.colorVariation), false)
	end

	-- Sandstone outcrops between the dunes.
	local oc = f.outcrops
	local outcropKeys = {}
	for _, key in AssetRegistry.outcrops do
		if AssetRegistry.hasProp(key) then
			table.insert(outcropKeys, key)
		end
	end
	local outcrops = 0
	local rockSpots: { Vector3 } = {}
	if #outcropKeys > 0 then
		for i = 1, oc.count do
			local along = rng:NextNumber(f.startM, f.endM)
			local depth = rng:NextNumber(oc.minDepthFrac, oc.maxDepthFrac) * depthM
			local pos, rot = at(along, depth)
			local scale = rng:NextNumber(oc.minScale, oc.maxScale)
			-- Rocks may sit against dunes; they only keep clear of each other.
			local crowded = false
			for _, spot in rockSpots do
				if (spot - pos).Magnitude < ctx.s(60 * scale) then
					crowded = true
					break
				end
			end
			if crowded then
				continue
			end
			table.insert(rockSpots, pos)
			local key = outcropKeys[(i - 1) % #outcropKeys + 1]
			local base = CFrame.new(pos) * rot * CFrame.Angles(0, rng:NextNumber(-math.pi, math.pi), 0)
			if AssetRegistry.place(key, base, scale, ctx.mps, model, cfg.shadows.dunes) then
				outcrops += 1
			end
		end
	end

	-- Scrub at the foot of the field.
	local scrubs = 0
	if AssetRegistry.hasProp("scrub") then
		local sc = cfg.scatter.scrub
		for _ = 1, f.scrubCount do
			local along = rng:NextNumber(f.startM, f.endM)
			local depth = rng:NextNumber(-40, f.scrubDepthM)
			local pos, rot = at(along, depth)
			local base = CFrame.new(pos) * rot * CFrame.Angles(0, rng:NextNumber(-math.pi, math.pi), 0)
			local size = rng:NextNumber(sc.minSizeM, sc.maxSizeM)
			local bush = AssetRegistry.place("scrub", base, size / 2, ctx.mps, model, false)
			if bush then
				local color = tint(rng, sc.color, sc.colorVariation)
				for _, part in bush:GetChildren() do
					if part:IsA("BasePart") then
						part.Color = color
					end
				end
				scrubs += 1
			end
		end
	end

	if cfg.streaming.enabled and cfg.streaming.dunesPersistent then
		local ok = pcall(function()
			model.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
		end)
		if not ok then
			warn("[World] could not set ModelStreamingMode on the dunes")
		end
	end

	local sunDeg = math.deg(math.asin(Lighting:GetSunDirection().Y))
	print(
		string.format(
			"[World] dunes: %d sand forms, %d outcrops, %d scrub on the %s; tallest crest %.1f deg above the road horizon, sun at %.1f deg",
			forms,
			outcrops,
			scrubs,
			if side > 0 then "right" else "left",
			tallestDeg,
			sunDeg
		)
	)
	return model
end

return Dunes
