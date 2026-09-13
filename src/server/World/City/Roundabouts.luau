--!strict
-- Real roundabouts at every boulevard crossing.
--
-- The street grid lays its crossings as squares. This module turns each one
-- into a roundabout after everything else is built: it carves a circle out
-- of every road surface, verge, median, kerb and marking that reaches into
-- the crossing (GeometryService subtraction, so the cut edges are true
-- arcs), removes the props that would stand in the ring, and then lays the
-- roundabout itself:
--
--   * a circular carriageway, one Asphalt cylinder, collidable;
--   * an outer kerb that follows the circle and breaks for every approach;
--   * a raised island with a kerb, an LED ring, lawn, a stone planter,
--     date palms with uplights and scrub;
--   * a monument in the middle: a gold dallah (the Arabic coffee pot every
--     Gulf city puts on a roundabout), a KAFD-style lit glass obelisk, a lit
--     fountain, and on the gateway the futuristic Riyadh arch;
--   * splitter noses where each boulevard median meets the ring, lane and
--     edge lines round the ring, give-way teeth on every entry;
--   * the highway's mesh lamp post round the outside, arms over the ring.
--
-- Carving runs over the city streets and furniture and, at the gateway,
-- over the highway's own road, markings, lamps and planting too, because
-- the highway runs into the gateway ring. The sand plane is never carved.
local GeometryService = game:GetService("GeometryService")
local WorldConfig = require(script.Parent.Parent.WorldConfig)
local Build = require(script.Parent.Parent.Build)
local RoadNetwork = require(script.Parent.Parent.RoadNetwork)
local AssetRegistry = require(script.Parent.Parent.AssetRegistry)
local WorldLighting = require(script.Parent.Parent.Lighting)
local CityConfig = require(script.Parent.CityConfig)
local Streets = require(script.Parent.Streets)

type Context = RoadNetwork.Context
type CCfg = CityConfig.Config
type Plan = Streets.Plan
type Node = Streets.Node

local Roundabouts = {}

-- An approach into a ring: outward unit direction from the centre, half
-- width of the corridor, and half width of its median.
-- kerbLateralM is how far the approach's own kerb centreline sits from
-- the mouth's axis: the ring kerb stops exactly there so the two meet.
type Mouth = { dir: Vector3, halfM: number, medianHalfM: number, kerbLateralM: number }

local function tinted(colour: Color3, rng: Random, tone: number): Color3
	local t = rng:NextNumber(-tone, tone)
	return if t < 0 then colour:Lerp(Color3.new(0, 0, 0), -t) else colour:Lerp(Color3.new(1, 1, 1), t)
end

--------------------------------------------------------------------------
-- Carving
--------------------------------------------------------------------------

-- Names of median pieces, which are carved back further so a rounded
-- splitter nose can close them off at the ring.
local MEDIAN_NAMES = { Median = true, MedianKerb = true, MedianLed = true }

local function isMedian(p: BasePart): boolean
	if MEDIAN_NAMES[p.Name] then
		return true
	end
	local parent = p.Parent
	return parent ~= nil and parent.Name == "Median" -- the highway's median folder
end

-- A flat box is carved; anything else inside the circle is removed with
-- its small container (a lamp folder, a palm model, a parked car).
local function isFlat(ctx: Context, p: BasePart): boolean
	-- 1.2 m, because the highway's slabs are a metre thick.
	return p.ClassName == "Part" and (p :: Part).Shape == Enum.PartType.Block and p.Size.Y <= ctx.s(1.2)
end

local function container(p: Instance, roots: { [Instance]: boolean }): Instance
	local c = p
	while c.Parent and not roots[c.Parent] and (c.Parent:IsA("Model") or c.Parent:IsA("Folder")) and #c.Parent:GetDescendants() <= 14 do
		c = c.Parent
	end
	return c
end

-- Distance in the ground plane from `centre` to the part's footprint, and
-- whether all four footprint corners are within `radius`.
local function footprint(p: BasePart, centre: Vector3, radius: number): (number, boolean)
	local cf, size = p.CFrame, p.Size
	local localC = cf:PointToObjectSpace(Vector3.new(centre.X, cf.Position.Y, centre.Z))
	local cx = math.clamp(localC.X, -size.X / 2, size.X / 2)
	local cz = math.clamp(localC.Z, -size.Z / 2, size.Z / 2)
	local nearest = cf:PointToWorldSpace(Vector3.new(cx, 0, cz))
	local dist = Vector2.new(nearest.X - centre.X, nearest.Z - centre.Z).Magnitude
	local all = true
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			local w = cf:PointToWorldSpace(Vector3.new(sx * size.X / 2, 0, sz * size.Z / 2))
			if Vector2.new(w.X - centre.X, w.Z - centre.Z).Magnitude > radius then
				all = false
			end
		end
	end
	return dist, all
end

local function cutter(ctx: Context, centre: Vector3, radius: number): Part
	local p = Instance.new("Part")
	p.Shape = Enum.PartType.Cylinder
	p.Anchored = true
	p.Size = Vector3.new(ctx.s(12), radius * 2, radius * 2)
	p.CFrame = CFrame.new(centre) * CFrame.Angles(0, 0, math.pi / 2)
	return p
end

-- A cylinder cutter is a polygon to the CSG kernel, so one cut leaves the
-- edge up to a quarter of a metre inside the circle on a ring this size, far
-- enough to poke out from under the kerb. The same cylinder turned through a
-- fraction of a facet, four times over, puts the edge within a few
-- centimetres of the true circle.
local CUTTER_TURNS_DEG = { 0, 2.5, 5, 7.5 }

local function subtract(ctx: Context, p: BasePart, centre: Vector3, radius: number): boolean
	local cuts: { BasePart } = {}
	for _, turn in CUTTER_TURNS_DEG do
		local cut = cutter(ctx, centre, radius)
		cut.CFrame = CFrame.new(centre) * CFrame.Angles(0, math.rad(turn), 0) * CFrame.Angles(0, 0, math.pi / 2)
		table.insert(cuts, cut)
	end
	local ok, result = pcall(function()
		return GeometryService:SubtractAsync(p, cuts, {
			CollisionFidelity = Enum.CollisionFidelity.Box,
			RenderFidelity = Enum.RenderFidelity.Precise,
			SplitApart = false,
		})
	end)
	for _, cut in cuts do
		cut:Destroy()
	end
	if not ok or type(result) ~= "table" or #result == 0 then
		warn(`[City] could not carve {p:GetFullName()} for a roundabout: {tostring(result)}`)
		return false
	end
	for _, piece in result do
		piece.Name = p.Name
		piece.Anchored = true
		piece.CanCollide = p.CanCollide
		piece.CanQuery = p.CanQuery
		piece.CanTouch = false
		piece.CastShadow = p.CastShadow
		piece.Color = p.Color
		piece.Material = p.Material
		piece.MaterialVariant = p.MaterialVariant
		piece.Transparency = p.Transparency
		if piece:IsA("PartOperation") then
			piece.UsePartColor = true
		end
		piece.Parent = p.Parent
	end
	p:Destroy()
	return true
end

-- A thin strip (a marking, a kerb, an LED line, a tyre track) is clipped
-- rather than subtracted: along its long axis the part of it inside the
-- circle is a single interval, so it is shortened, or split in two, with
-- plain arithmetic. Exact for anything this narrow, and it keeps the carve
-- from spending seconds of GeometryService on hundreds of paint lines.
local function clipStrip(p: BasePart, centre: Vector3, radius: number): number
	local cf, size = p.CFrame, p.Size
	local alongX = size.X >= size.Z
	local axis = if alongX then cf.RightVector else cf.LookVector
	local half = (if alongX then size.X else size.Z) / 2
	local rel = Vector3.new(centre.X - cf.Position.X, 0, centre.Z - cf.Position.Z)
	local flatAxis = Vector3.new(axis.X, 0, axis.Z)
	if flatAxis.Magnitude < 1e-3 then
		return 0
	end
	flatAxis = flatAxis.Unit
	local t0 = rel:Dot(flatAxis)
	local lateral = (rel - flatAxis * t0).Magnitude
	if lateral >= radius then
		return 0
	end
	local h = math.sqrt(radius * radius - lateral * lateral)
	local pieces: { { number } } = {}
	if t0 - h > -half then
		table.insert(pieces, { -half, math.min(half, t0 - h) })
	end
	if t0 + h < half then
		table.insert(pieces, { math.max(-half, t0 + h), half })
	end
	local kept = 0
	local original = true
	for _, piece in pieces do
		local len = piece[2] - piece[1]
		if len > 0.05 then
			local target = if original then p else p:Clone()
			original = false
			local mid = (piece[1] + piece[2]) / 2
			target.Size = if alongX then Vector3.new(len, size.Y, size.Z) else Vector3.new(size.X, size.Y, len)
			target.CFrame = cf + flatAxis * mid
			if target ~= p then
				target.Parent = p.Parent
			end
			kept += 1
		end
	end
	if original then
		p:Destroy()
	end
	return 1
end

-- Carves one ring out of everything under `roots`. Returns parts carved and
-- containers removed.
local function carve(ctx: Context, c: CCfg, roots: { Instance }, centre: Vector3, radiusM: number): (number, number)
	local r = c.roundabout
	local rootSet: { [Instance]: boolean } = {}
	for _, root in roots do
		rootSet[root] = true
	end
	local road = ctx.s(radiusM)
	local k = c.boulevard.kerbWidthM
	-- Raised surfaces (verge lawn, pavement) stop under the ring kerb, not
	-- at its outer face. Their tops were level with the kerb's and the CSG
	-- cut is a polygon, so along the whole ring the lawn and the kerb
	-- z-fought, and at every facet the lawn's cut edge poked out. Now the
	-- cut edge sits under the kerb, which stands a little proud of the lawn.
	-- Thin raised strips (the boulevard kerbs) are clipped to the kerb's
	-- centreline instead, so they end exactly where the ring kerb picks up.
	local raised = ctx.s(radiusM + k * 0.75)
	local raisedClip = ctx.s(radiusM + k / 2)
	local median = ctx.s(radiusM + r.splitterNoseRadiusM)
	local reach = median + ctx.s(2)
	local carved, removed = 0, 0
	local doomed: { [Instance]: boolean } = {}
	local toCarve: { { part: BasePart, radius: number } } = {}
	local toClip: { { part: BasePart, radius: number } } = {}
	for _, root in roots do
		for _, d in root:GetDescendants() do
			if not d:IsA("BasePart") then
				continue
			end
			local p = d :: BasePart
			-- The sand plane is never cut.
			local parent = p.Parent
			if parent and parent.Name == "Ground" then
				continue
			end
			local dist, _ = footprint(p, centre, reach)
			if dist > reach then
				continue
			end
			if isFlat(ctx, p) and math.max(p.Size.X, p.Size.Z) > ctx.s(3) then
				local topM = (p.Position.Y + p.Size.Y / 2 - ctx.surfaceY) * ctx.mps
				local radius = if isMedian(p) then median elseif topM > 0.05 then raised else road
				local near, all = footprint(p, centre, radius)
				if all then
					doomed[p] = true
				elseif near < radius then
					-- Medians are clipped too: they collide, and a carved union
					-- keeps its whole box as collision, which left an invisible
					-- 17 cm median lip across the ring. Clipping an 8 m strip by
					-- its centreline is 15 cm out at the edges, under the nose.
					if isMedian(p) or math.min(p.Size.X, p.Size.Z) < ctx.s(1.5) then
						table.insert(toClip, { part = p, radius = if radius == raised then raisedClip else radius })
					else
						table.insert(toCarve, { part = p, radius = radius })
					end
				end
			else
				local flat = Vector2.new(p.Position.X - centre.X, p.Position.Z - centre.Z).Magnitude
				local radius = if isMedian(p) then median else raised
				if flat < radius + ctx.s(1) then
					doomed[container(p, rootSet)] = true
				end
			end
		end
	end
	for inst in doomed do
		if inst.Parent then
			inst:Destroy()
			removed += 1
		end
	end
	for _, job in toClip do
		if job.part.Parent then
			carved += clipStrip(job.part, centre, job.radius)
		end
	end
	for _, job in toCarve do
		if job.part.Parent and subtract(ctx, job.part, centre, job.radius) then
			carved += 1
		end
	end
	return carved, removed
end

--------------------------------------------------------------------------
-- Pieces
--------------------------------------------------------------------------

-- A flat cylinder standing on the ground at `centre`, top at topM.
local function disc(ctx: Context, parent: Instance, name: string, centre: Vector3, radiusM: number, topM: number, thickM: number, color: Color3, material: Enum.Material, collide: boolean): Part
	local p = Build.part({
		name = name,
		size = Vector3.new(ctx.s(thickM), ctx.s(radiusM * 2), ctx.s(radiusM * 2)),
		cframe = CFrame.new(centre + Vector3.new(0, ctx.s(topM - thickM / 2), 0)) * CFrame.Angles(0, 0, math.pi / 2),
		color = color,
		material = material,
		parent = parent,
		collide = collide,
		query = collide,
	})
	p.Shape = Enum.PartType.Cylinder
	return p
end

-- A box at polar (radius, angle) round `centre`, its length along the
-- tangent. Used for ring markings, the kerb LED ring and teeth.
local function onArc(ctx: Context, parent: Instance, name: string, centre: Vector3, radiusM: number, angle: number, lengthM: number, widthM: number, topM: number, thickM: number, color: Color3, material: Enum.Material, transparency: number?): Part
	local dir = Vector3.new(math.cos(angle), 0, math.sin(angle))
	local tangent = Vector3.new(-math.sin(angle), 0, math.cos(angle))
	local pos = centre + dir * ctx.s(radiusM) + Vector3.new(0, ctx.s(topM - thickM / 2), 0)
	return Build.part({
		name = name,
		size = Vector3.new(ctx.s(widthM), ctx.s(thickM), ctx.s(lengthM)),
		cframe = CFrame.lookAt(pos, pos + tangent),
		color = color,
		material = material,
		parent = parent,
		transparency = transparency,
	})
end

-- A box between two points, for sculpture members.
local function member(parent: Instance, name: string, a: Vector3, b: Vector3, width: number, depth: number, color: Color3, material: Enum.Material, transparency: number?): Part
	local mid = (a + b) / 2
	return Build.part({
		name = name,
		size = Vector3.new(width, depth, (b - a).Magnitude),
		cframe = CFrame.lookAt(mid, b),
		color = color,
		material = material,
		parent = parent,
		castShadow = true,
		transparency = transparency,
	})
end

-- A cylinder between two points (Roblox cylinders run along local X).
local function rod(parent: Instance, name: string, a: Vector3, b: Vector3, diameter: number, color: Color3, material: Enum.Material, transparency: number?): Part
	local mid = (a + b) / 2
	local p = Build.part({
		name = name,
		size = Vector3.new((b - a).Magnitude, diameter, diameter),
		cframe = CFrame.lookAt(mid, b) * CFrame.Angles(0, math.pi / 2, 0),
		color = color,
		material = material,
		parent = parent,
		castShadow = true,
		transparency = transparency,
	})
	p.Shape = Enum.PartType.Cylinder
	return p
end

local function inMouth(mouths: { Mouth }, angle: number, radiusM: number, marginM: number): boolean
	local v = Vector3.new(math.cos(angle), 0, math.sin(angle))
	for _, m in mouths do
		if v:Dot(m.dir) > 0 then
			local lateral = math.abs(v.X * m.dir.Z - v.Z * m.dir.X) * radiusM
			if lateral < m.halfM + marginM then
				return true
			end
		end
	end
	return false
end

--------------------------------------------------------------------------
-- Monuments. Every one stands on the island's planter at `base` (studs,
-- at the planter top) and is sized in metres times `k`.
--------------------------------------------------------------------------

local GOLD = Color3.fromRGB(206, 164, 76)
local STONE = Color3.fromRGB(214, 196, 162)

-- A stepped square plinth turned 45 degrees with an LED line on each step.
local function plinth(ctx: Context, c: CCfg, parent: Instance, base: Vector3, k: number, tiers: number): Vector3
	local L = c.lights
	local y = 0
	for t = 1, tiers do
		local w = ctx.s((9 - (t - 1) * 2) * k)
		local h = ctx.s(0.9 * k)
		local cf = CFrame.new(base + Vector3.new(0, y + h / 2, 0)) * CFrame.Angles(0, math.pi / 4, 0)
		Build.part({ name = "Plinth", size = Vector3.new(w, h, w), cframe = cf, color = STONE:Lerp(Color3.new(1, 1, 1), t * 0.03), material = Enum.Material.Limestone, parent = parent, castShadow = true })
		for _, e in { { 0, w / 2 }, { 0, -w / 2 }, { w / 2, 0 }, { -w / 2, 0 } } do
			local along = if e[1] == 0 then Vector3.new(w, ctx.s(0.08), ctx.s(0.08)) else Vector3.new(ctx.s(0.08), ctx.s(0.08), w)
			Build.part({ name = "PlinthLed", size = along, cframe = cf * CFrame.new(e[1], h / 2 - ctx.s(0.04), e[2]), color = L.warmLed, material = Enum.Material.Neon, parent = parent })
		end
		y += h
	end
	return base + Vector3.new(0, y, 0)
end

-- The dallah: the Arabic coffee pot on a stepped plinth, in gold.
local function dallah(ctx: Context, c: CCfg, parent: Instance, base: Vector3, k: number)
	local s = function(m: number): number
		return ctx.s(m * k)
	end
	local top = plinth(ctx, c, parent, base, k, 3)
	local function at(x: number, y: number, z: number): Vector3
		return top + Vector3.new(s(x), s(y), s(z))
	end
	local function gold(p: BasePart)
		p.Reflectance = 0.22
	end
	-- Body: a wide ellipsoid, then a waist band.
	gold(Build.ellipsoid({ name = "DallahBody", size = Vector3.new(s(5.6), s(6.2), s(5.6)), cframe = CFrame.new(at(0, 3.0, 0)), color = GOLD, material = Enum.Material.Metal, parent = parent, castShadow = true }))
	gold(Build.ellipsoid({ name = "DallahFoot", size = Vector3.new(s(4.2), s(1.2), s(4.2)), cframe = CFrame.new(at(0, 0.4, 0)), color = GOLD:Lerp(Color3.new(0, 0, 0), 0.12), material = Enum.Material.Metal, parent = parent, castShadow = true }))
	gold(rod(parent, "DallahBand", at(0, 5.7, 0), at(0, 6.2, 0), s(4.3), GOLD:Lerp(Color3.new(0, 0, 0), 0.18), Enum.Material.Metal))
	-- Neck: two narrowing drums.
	gold(rod(parent, "DallahNeck", at(0, 6.2, 0), at(0, 8.6, 0), s(2.9), GOLD, Enum.Material.Metal))
	gold(rod(parent, "DallahNeck", at(0, 8.6, 0), at(0, 9.6, 0), s(2.2), GOLD:Lerp(Color3.new(1, 1, 1), 0.08), Enum.Material.Metal))
	-- Lid: a dome, a bead, a spike.
	gold(Build.ellipsoid({ name = "DallahLid", size = Vector3.new(s(2.6), s(1.8), s(2.6)), cframe = CFrame.new(at(0, 9.9, 0)), color = GOLD, material = Enum.Material.Metal, parent = parent, castShadow = true }))
	gold(Build.ellipsoid({ name = "DallahBead", size = Vector3.new(s(0.9), s(0.9), s(0.9)), cframe = CFrame.new(at(0, 11.0, 0)), color = GOLD, material = Enum.Material.Metal, parent = parent, castShadow = true }))
	gold(rod(parent, "DallahSpike", at(0, 11.3, 0), at(0, 12.6, 0), s(0.35), GOLD, Enum.Material.Metal))
	-- Spout: a long beak rising out of the body, thinning, with a tip.
	local spout = { at(2.3, 4.0, 0), at(3.8, 5.8, 0), at(5.0, 7.9, 0), at(6.1, 9.4, 0) }
	local dias = { 1.3, 1.0, 0.75 }
	for i = 1, 3 do
		gold(rod(parent, "DallahSpout", spout[i], spout[i + 1], s(dias[i]), GOLD, Enum.Material.Metal))
	end
	gold(rod(parent, "DallahBeak", spout[4], at(7.0, 9.7, 0), s(0.55), GOLD, Enum.Material.Metal))
	-- Handle: an arc of short members on the far side.
	local prev = at(-1.4, 8.2, 0)
	for i = 1, 6 do
		local a = (i / 6) * math.pi
		local nextP = at(-1.8 - math.sin(a) * 2.6, 8.2 - (i / 6) * 4.6, 0)
		gold(member(parent, "DallahHandle", prev, nextP, s(0.5), s(0.5), GOLD, Enum.Material.Metal))
		prev = nextP
	end
	-- Uplights round the plinth.
	for i = 0, 3 do
		local a = i * math.pi / 2
		Build.part({ name = "Uplight", size = Vector3.new(s(0.9), s(0.2), s(0.9)), cframe = CFrame.new(base + Vector3.new(math.cos(a) * s(6.2), s(0.1), math.sin(a) * s(6.2))), color = c.lights.warmLed, material = Enum.Material.Neon, parent = parent })
	end
end

-- The obelisk: four leaning glass pillars meeting at a lit crystal, with
-- LED frames every few metres. The KAFD towers in miniature.
local function obelisk(ctx: Context, c: CCfg, parent: Instance, base: Vector3, k: number)
	local L = c.lights
	local s = function(m: number): number
		return ctx.s(m * k)
	end
	local top = plinth(ctx, c, parent, base, k, 1)
	local H = 34
	local glass = Color3.fromRGB(80, 124, 160)
	local function corner(sx: number, sz: number, y: number): Vector3
		local t = y / H
		local half = 3.6 * (1 - t) + 0.5 * t
		return top + Vector3.new(s(sx * half), s(y), s(sz * half))
	end
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			member(parent, "ObeliskPillar", corner(sx, sz, 0), corner(sx, sz, H), s(1.0), s(1.0), glass, Enum.Material.Glass, 0.1)
			member(parent, "ObeliskEdge", corner(sx, sz, 0) + Vector3.new(0, 0, 0), corner(sx, sz, H), s(0.18), s(0.18), L.coolLed, Enum.Material.Neon)
		end
	end
	for y = 5, H - 3, 5 do
		local ring = { corner(-1, -1, y), corner(1, -1, y), corner(1, 1, y), corner(-1, 1, y) }
		for i = 1, 4 do
			member(parent, "ObeliskRing", ring[i], ring[i % 4 + 1], s(0.22), s(0.22), L.coolLed, Enum.Material.Neon)
		end
	end
	local crystal = Build.part({ name = "ObeliskCrystal", size = Vector3.new(s(2.4), s(2.4), s(2.4)), cframe = CFrame.new(top + Vector3.new(0, s(H + 1.2), 0)) * CFrame.Angles(math.pi / 4, 0, math.pi / 4), color = Color3.fromRGB(220, 240, 255), material = Enum.Material.Neon, parent = parent, transparency = 0.15 })
	local _ = crystal
	Build.part({ name = "Beacon", size = Vector3.new(s(0.8), s(0.8), s(0.8)), cframe = CFrame.new(top + Vector3.new(0, s(H + 3.2), 0)), color = Color3.fromRGB(255, 70, 60), material = Enum.Material.Neon, parent = parent })
end

-- The fountain: a stone pool with lit water, a tier, a bowl and a jet.
local function fountain(ctx: Context, c: CCfg, parent: Instance, base: Vector3, k: number)
	local L = c.lights
	local r = function(m: number): number
		return m * k
	end
	local centre = base
	disc(ctx, parent, "FountainRim", centre, r(9), 0.7, 0.7, STONE, Enum.Material.Limestone, true)
	local water = disc(ctx, parent, "FountainWater", centre, r(8.4), 0.62, 0.1, Color3.fromRGB(60, 140, 170), Enum.Material.Glass, false)
	water.Transparency = 0.3
	water.Reflectance = 0.35
	disc(ctx, parent, "FountainGlow", centre, r(8.2), 0.5, 0.05, L.coolLed, Enum.Material.Neon, false)
	disc(ctx, parent, "FountainTier", centre, r(3.4), 2.2, 1.7, STONE, Enum.Material.Limestone, false)
	disc(ctx, parent, "FountainBowl", centre, r(2.6), 3.8, 0.4, STONE:Lerp(Color3.new(1, 1, 1), 0.1), Enum.Material.Limestone, false)
	local jetBase = centre + Vector3.new(0, ctx.s(3.8), 0)
	rod(parent, "FountainJet", jetBase, jetBase + Vector3.new(0, ctx.s(r(7)), 0), ctx.s(r(0.6)), Color3.fromRGB(230, 245, 255), Enum.Material.Neon, 0.45)
	-- A ring of lower jets leaning out from the tier, instead of a spray
	-- cap, which read as a white mushroom.
	for i = 0, 7 do
		local a = i / 8 * math.pi * 2
		local foot = centre + Vector3.new(math.cos(a) * ctx.s(r(3.0)), ctx.s(2.2), math.sin(a) * ctx.s(r(3.0)))
		local tip = centre + Vector3.new(math.cos(a) * ctx.s(r(5.6)), ctx.s(r(4.2)), math.sin(a) * ctx.s(r(5.6)))
		rod(parent, "FountainJet", foot, tip, ctx.s(r(0.25)), Color3.fromRGB(230, 245, 255), Enum.Material.Neon, 0.55)
	end
end

-- The gateway: two crossing parabolic ribbons of white steel with LED
-- undersides over the island, and a stone wall facing the highway with
-- الرياض / RIYADH in gold.
local function gatewayArch(ctx: Context, c: CCfg, parent: Instance, base: Vector3, spanM: number, facing: Vector3)
	local L = c.lights
	local H = 30
	local steel = Color3.fromRGB(236, 236, 232)
	for _, yaw in { math.rad(22), math.rad(-22) } do
		local across = CFrame.Angles(0, yaw, 0):VectorToWorldSpace(Vector3.new(facing.Z, 0, -facing.X))
		local prev: Vector3? = nil
		local segs = 22
		for i = 0, segs do
			local t = -1 + 2 * i / segs
			local p = base + across * ctx.s(t * spanM / 2) + Vector3.new(0, ctx.s(H * (1 - t * t)), 0)
			if prev then
				member(parent, "ArchRibbon", prev, p, ctx.s(1.6), ctx.s(0.7), steel, Enum.Material.Metal)
				member(parent, "ArchLed", prev - Vector3.new(0, ctx.s(0.4), 0), p - Vector3.new(0, ctx.s(0.4), 0), ctx.s(0.5), ctx.s(0.12), L.coolLed, Enum.Material.Neon)
			end
			prev = p
		end
	end
	-- The name wall, facing the highway.
	local wallPos = base + facing * ctx.s(9) + Vector3.new(0, ctx.s(1.8), 0)
	local wall = Build.part({ name = "NameWall", size = Vector3.new(ctx.s(18), ctx.s(3.6), ctx.s(1.4)), cframe = CFrame.lookAt(wallPos, wallPos + facing), color = STONE, material = Enum.Material.Limestone, parent = parent, castShadow = true })
	Build.part({ name = "NameWallLed", size = Vector3.new(ctx.s(18.2), ctx.s(0.12), ctx.s(1.5)), cframe = wall.CFrame * CFrame.new(0, ctx.s(1.82), 0), color = L.warmLed, material = Enum.Material.Neon, parent = parent })
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 24
	gui.LightInfluence = 0
	gui.Brightness = 1.6
	gui.MaxDistance = 900
	gui.Parent = wall
	local layout = Instance.new("UIListLayout")
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.Parent = gui
	for i, line in { { text = "الرياض", h = 0.6 }, { text = "RIYADH", h = 0.3 } } do
		local l = Instance.new("TextLabel")
		l.BackgroundTransparency = 1
		l.Size = UDim2.fromScale(0.9, line.h)
		l.Text = line.text
		l.TextScaled = true
		l.Font = Enum.Font.GothamBold
		l.TextColor3 = Color3.fromRGB(236, 196, 110)
		l.LayoutOrder = i
		l.Parent = gui
	end
end

--------------------------------------------------------------------------
-- Build
--------------------------------------------------------------------------

local function highwayHalfM(): number
	local presets = WorldConfig.presets :: any
	local preset = presets[WorldConfig.preset] or presets.testRoad
	local width = 72
	if preset.segments and preset.segments[1] then
		width = preset.segments[1].widthM
	end
	return width / 2 + WorldConfig.road.shoulderWidthM + WorldConfig.road.kerbWidthM
end

local function mouthsFor(c: CCfg, plan: Plan, node: Node): { Mouth }
	local mouths: { Mouth } = {}
	local reach = node.widthM / 2 + 0.5
	for _, seg in plan.segments do
		if seg.boulevard then
			for _, e in { { seg.ax, seg.az }, { seg.bx, seg.bz } } do
				local dx, dz = e[1] - node.x, e[2] - node.z
				if (math.abs(dx) < 0.5 and math.abs(math.abs(dz) - node.widthM / 2) < reach) or (math.abs(dz) < 0.5 and math.abs(math.abs(dx) - node.widthM / 2) < reach) then
					local d = Vector3.new(dx, 0, dz)
					if d.Magnitude > 1 and d.Magnitude < node.widthM then
						local half = c.boulevard.widthM / 2
						table.insert(mouths, { dir = d.Unit, halfM = half, medianHalfM = c.boulevard.medianWidthM / 2, kerbLateralM = half + c.boulevard.kerbWidthM / 2 })
					end
				end
			end
		end
	end
	if node.gateway then
		-- The highway comes in from +Z, the direction of the start line.
		local half = highwayHalfM()
		table.insert(mouths, { dir = Vector3.new(0, 0, 1), halfM = half, medianHalfM = WorldConfig.road.medianWidthM / 2, kerbLateralM = half - WorldConfig.road.kerbWidthM / 2 })
	end
	return mouths
end

function Roundabouts.build(ctx: Context, c: CCfg, plan: Plan, parent: Instance, carveRoots: { Instance }): (Folder, number, number)
	local r = c.roundabout
	local L = c.lights
	local s = c.surface
	local folder = Build.folder("Roundabouts", parent)
	local rng = Build.rng(c.seed + 29)
	local kerbColour = s.kerbColor:Lerp(WorldConfig.ground.color, s.kerbDust)
	local paint = s.paintColor:Lerp(s.asphaltColor, 0.25)
	local totalCarved, totalRemoved = 0, 0
	local monumentIndex = 0

	for _, node in plan.nodes do
		if not node.roundabout then
			continue
		end
		local R = if node.gateway then r.gatewayRadiusM else r.radiusM
		local Ri = if node.gateway then r.gatewayIslandRadiusM else r.islandRadiusM
		local centre = Vector3.new(ctx.s(node.x), ctx.surfaceY, ctx.s(node.z))
		local mouths = mouthsFor(c, plan, node)

		local carved, removed = carve(ctx, c, carveRoots, centre, R)
		totalCarved += carved
		totalRemoved += removed

		local ring = Build.folder(if node.gateway then "GatewayRoundabout" else "Roundabout", folder)

		-- The carriageway.
		local ringTone = tinted(s.asphaltColor, rng, s.slabTone)
		disc(ctx, ring, "RingAsphalt", centre, R, 0, s.thicknessM, ringTone, Enum.Material.Asphalt, true)

		-- Outer kerb: short straight pieces round each arc between two
		-- approaches. A kerb carved as one thin CSG ring rendered as filled
		-- pale wedges, so it is built from segments instead. Each arc ends
		-- exactly on the centreline of the approach's own kerb, with a
		-- round post over the joint: the pieces used to be dropped whole at
		-- the mouths, leaving a notch of lawn on one side of each corner and
		-- the approach kerb poking into the ring on the other.
		local k = c.boulevard.kerbWidthM
		local kerbR = R + k / 2
		-- A band of asphalt all the way round, from inside the ring's edge
		-- to under the kerb. A cylinder this big renders as a polygon, and
		-- between its corners the sand showed through at the kerb and across
		-- the mouths, where the streets are carved to the true circle. Half a
		-- centimetre proud of the carriageway so the two tops never z-fight.
		local rimCount = math.ceil(2 * math.pi * R / r.kerbSegmentM)
		for i = 0, rimCount - 1 do
			local a = (i + 0.5) / rimCount * math.pi * 2
			local rim = onArc(ctx, ring, "RingRim", centre, R - r.rimWidthM / 2 + k / 2, a, 2 * math.pi * R / rimCount + 0.08, r.rimWidthM + k, 0.005, s.thicknessM, ringTone, Enum.Material.Asphalt)
			rim.CanCollide = true
			rim.CanQuery = true
		end
		local kerbTop = c.boulevard.kerbHeightM + r.kerbProudM
		local gaps: { { number } } = {}
		for _, m in mouths do
			local centreA = math.atan2(m.dir.Z, m.dir.X)
			local halfA = math.asin(math.clamp(m.kerbLateralM / kerbR, 0, 1))
			table.insert(gaps, { centreA - halfA, centreA + halfA })
		end
		table.sort(gaps, function(g1, g2)
			return g1[1] < g2[1]
		end)
		local arcs: { { number } } = {}
		if #gaps == 0 then
			table.insert(arcs, { 0, math.pi * 2, 0 })
		else
			for gi, g in gaps do
				local nextStart = if gi < #gaps then gaps[gi + 1][1] else gaps[1][1] + math.pi * 2
				if nextStart > g[2] then
					table.insert(arcs, { g[2], nextStart, 1 })
				end
			end
		end
		for _, arc in arcs do
			local span = arc[2] - arc[1]
			local n = math.max(1, math.ceil(span * kerbR / r.kerbSegmentM))
			for i = 0, n - 1 do
				local a = arc[1] + (i + 0.5) / n * span
				onArc(ctx, ring, "RingKerb", centre, kerbR, a, span * kerbR / n + 0.08, k, kerbTop, kerbTop + 0.1, tinted(kerbColour, rng, 0.04), Enum.Material.Concrete)
			end
			if arc[3] == 1 then
				for _, a in { arc[1], arc[2] } do
					local post = centre + Vector3.new(math.cos(a) * ctx.s(kerbR), 0, math.sin(a) * ctx.s(kerbR))
					disc(ctx, ring, "RingKerbJoint", post, k * 0.55, kerbTop + 0.005, kerbTop + 0.105, kerbColour, Enum.Material.Concrete, false)
				end
			end
		end

		-- Markings: an edge line inside the kerb, lane lines round the ring,
		-- an edge line round the island. Solid lines break at the mouths.
		local eps = s.markingEpsilonM + s.markingThicknessM
		local function circleLine(radiusM: number, dashM: number, gapM: number, widthM: number, skipMouths: boolean)
			local circumference = 2 * math.pi * radiusM
			local step = dashM + gapM
			local n = math.floor(circumference / step)
			for i = 0, n - 1 do
				local a = (i + 0.5) / n * math.pi * 2
				if not (skipMouths and inMouth(mouths, a, radiusM, 1)) then
					onArc(ctx, ring, "RingLine", centre, radiusM, a, dashM, widthM, eps, s.markingThicknessM, paint, Enum.Material.SmoothPlastic, 0.1)
				end
			end
		end
		circleLine(R - 0.9, 3.2, 0.05, s.edgeLineWidthM, true)
		circleLine(Ri + 1.0, 3.2, 0.05, s.edgeLineWidthM, false)
		local laneCount = math.max(2, math.floor((R - Ri - 2) / r.laneWidthM))
		for lane = 1, laneCount - 1 do
			circleLine(Ri + 1 + (R - Ri - 2) * lane / laneCount, 3, 6, s.dashWidthM, false)
		end

		-- Entries: give-way teeth across the entering half of each approach,
		-- and a splitter nose closing off the median at the ring.
		for _, m in mouths do
			local right = Vector3.new(m.dir.Z, 0, -m.dir.X) -- driver's right, heading into the ring
			local lateral = m.medianHalfM + 0.8
			while lateral < m.halfM - 0.8 do
				local p = centre + m.dir * ctx.s(R + 1.6) + right * ctx.s(lateral) + Vector3.new(0, ctx.s(eps - s.markingThicknessM / 2), 0)
				local tooth = Build.part({ name = "GiveWay", size = Vector3.new(ctx.s(0.55), ctx.s(s.markingThicknessM), ctx.s(0.55)), cframe = CFrame.lookAt(p, p + m.dir) * CFrame.Angles(0, math.pi / 4, 0), color = paint, material = Enum.Material.SmoothPlastic, parent = ring })
				local _ = tooth
				lateral += 1.3
			end
			local nose = centre + m.dir * ctx.s(R + r.splitterNoseRadiusM)
			disc(ctx, ring, "SplitterKerb", nose, r.splitterNoseRadiusM, c.boulevard.medianKerbHeightM, c.boulevard.medianKerbHeightM + 0.1, kerbColour, Enum.Material.Concrete, false)
			disc(ctx, ring, "SplitterFill", nose, r.splitterNoseRadiusM - k, c.boulevard.medianKerbHeightM + 0.02, c.boulevard.medianKerbHeightM + 0.12, s.medianColor, Enum.Material.Ground, false)
			-- A lit keep-right bollard on the nose.
			local bollard = nose + Vector3.new(0, ctx.s(c.boulevard.medianKerbHeightM), 0)
			rod(ring, "NoseBollard", bollard, bollard + Vector3.new(0, ctx.s(1.1), 0), ctx.s(0.35), Color3.fromRGB(40, 42, 46), Enum.Material.Metal)
			rod(ring, "NoseBollardLed", bollard + Vector3.new(0, ctx.s(0.8), 0), bollard + Vector3.new(0, ctx.s(1.05), 0), ctx.s(0.37), L.coolLed, Enum.Material.Neon)
		end

		-- The island: kerb, LED ring, lawn, stone planter.
		disc(ctx, ring, "IslandKerb", centre, Ri, r.islandHeightM, r.islandHeightM + 0.2, kerbColour, Enum.Material.Concrete, true)
		disc(ctx, ring, "IslandLawn", centre, Ri - 0.7, r.islandHeightM + 0.1, r.islandHeightM + 0.3, r.lawnColor, Enum.Material.Grass, false)
		local ledCount = math.floor(2 * math.pi * Ri / 2.2)
		for i = 0, ledCount - 1 do
			local a = i / ledCount * math.pi * 2
			onArc(ctx, ring, "IslandLed", centre, Ri - 0.35, a, 2.0, 0.14, r.islandHeightM + 0.03, 0.06, L.coolLed, Enum.Material.Neon)
		end
		local planterR = Ri * 0.45
		disc(ctx, ring, "IslandPlanter", centre, planterR, r.islandHeightM + 1.0, 1.0, STONE, Enum.Material.Limestone, false)
		disc(ctx, ring, "IslandPlanterTop", centre, planterR - 0.5, r.islandHeightM + 1.05, 0.3, r.lawnColor, Enum.Material.Grass, false)

		-- Date palms in a ring, each with an uplight, and scrub between.
		local palmCount = if node.gateway then r.palmsOnIsland + 4 else r.palmsOnIsland
		for i = 0, palmCount - 1 do
			local a = (i + 0.5) / palmCount * math.pi * 2
			local pr = (Ri + planterR) / 2 + 1
			local pos = centre + Vector3.new(math.cos(a) * ctx.s(pr), ctx.s(r.islandHeightM + 0.1), math.sin(a) * ctx.s(pr))
			AssetRegistry.place("datePalm", CFrame.new(pos) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0), rng:NextNumber(0.95, 1.15), ctx.mps, ring, c.shadows.palms)
			local up = pos + Vector3.new(math.cos(a) * ctx.s(1.4), ctx.s(0.08), math.sin(a) * ctx.s(1.4))
			Build.part({ name = "Uplight", size = Vector3.new(ctx.s(0.5), ctx.s(0.12), ctx.s(0.5)), cframe = CFrame.new(up), color = L.warmLed, material = Enum.Material.Neon, parent = ring })
			for _ = 1, 2 do
				local sa = a + rng:NextNumber(-0.25, 0.25)
				local sr = pr + rng:NextNumber(-2.5, 2.5)
				local key = AssetRegistry.scrubs[rng:NextInteger(1, #AssetRegistry.scrubs)]
				local spos = centre + Vector3.new(math.cos(sa) * ctx.s(sr), ctx.s(r.islandHeightM + 0.1), math.sin(sa) * ctx.s(sr))
				local unit = if key == "scrub" then 2 else 1.12
				local bush = AssetRegistry.place(key, CFrame.new(spos) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0), rng:NextNumber(1.2, 1.9) / unit, ctx.mps, ring, false)
				if bush then
					for _, part in bush:GetChildren() do
						if part:IsA("BasePart") then
							part.Color = r.shrubColor
						end
					end
				end
			end
		end

		-- The monument.
		local top = centre + Vector3.new(0, ctx.s(r.islandHeightM + 1.05), 0)
		if node.gateway then
			gatewayArch(ctx, c, ring, top, Ri * 1.7, Vector3.new(0, 0, 1))
		else
			monumentIndex += 1
			local kind = r.monuments[(monumentIndex - 1) % #r.monuments + 1]
			if kind == "dallah" then
				dallah(ctx, c, ring, top, r.monumentScale)
			elseif kind == "obelisk" then
				obelisk(ctx, c, ring, top, r.monumentScale * 0.8)
			elseif kind == "fountain" then
				fountain(ctx, c, ring, top, r.monumentScale * 0.75)
			end
		end

		-- Lamps round the outside, arms over the ring.
		local lampR = R + r.lampSetbackM
		local step = math.rad(r.lampSpacingDeg)
		local a = step / 2
		while a < math.pi * 2 do
			if not inMouth(mouths, a, lampR, 3) then
				local dir = Vector3.new(math.cos(a), 0, math.sin(a))
				local foot = centre + dir * ctx.s(lampR) + Vector3.new(0, ctx.s(s.pavementHeightM), 0)
				local lampFolder = Build.folder("Lamp", ring)
				WorldLighting.meshLamp(WorldConfig, ctx, lampFolder, foot, -dir, c.furniture.lampMeshScale * 1.1, false)
			end
			a += step
		end
	end

	return folder, totalCarved, totalRemoved
end

return Roundabouts
