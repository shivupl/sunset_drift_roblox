--!strict
-- Street furniture and planting for the city: palms down the boulevard
-- medians and on the roundabout islands, street lamps on the pavements,
-- traffic signals where side streets meet boulevards, parked cars in the
-- parking lanes, bins and benches along the shop fronts, bollards and
-- planters around the plaza. Meshes from AssetRegistry where a box would
-- look wrong; boxes and cylinders where it would not. Nothing here collides.
--
-- Lamp heads carry the light manager's tag, so the city shares the same
-- twelve live lights as the highway; at golden hour they are dark anyway.
local CollectionService = game:GetService("CollectionService")
local Build = require(script.Parent.Parent.Build)
local RoadNetwork = require(script.Parent.Parent.RoadNetwork)
local AssetRegistry = require(script.Parent.Parent.AssetRegistry)
local WorldLighting = require(script.Parent.Parent.Lighting)
local CityConfig = require(script.Parent.CityConfig)
local Streets = require(script.Parent.Streets)

type Context = RoadNetwork.Context
type CCfg = CityConfig.Config
type Segment = Streets.Segment
type Parcel = Streets.Parcel

local Furniture = {}

local CAR_COLOURS = {
	Color3.fromRGB(236, 236, 232),
	Color3.fromRGB(220, 220, 218),
	Color3.fromRGB(200, 198, 190),
	Color3.fromRGB(40, 40, 44),
	Color3.fromRGB(120, 122, 128),
	Color3.fromRGB(90, 30, 30),
	Color3.fromRGB(30, 50, 90),
	Color3.fromRGB(180, 150, 100),
}

local function at(ctx: Context, xM: number, zM: number, yM: number?): Vector3
	return Vector3.new(ctx.s(xM), ctx.surfaceY + ctx.s(yM or 0), ctx.s(zM))
end

local function segAxis(seg: Segment): (boolean, number, number, number)
	local alongX = math.abs(seg.bx - seg.ax) > math.abs(seg.bz - seg.az)
	local len = if alongX then math.abs(seg.bx - seg.ax) else math.abs(seg.bz - seg.az)
	return alongX, len, math.min(seg.ax, seg.bx), math.min(seg.az, seg.bz)
end

-- Position d along a segment with a lateral offset (+ = +X for a Z street,
-- +Z for an X street).
local function along(seg: Segment, d: number, lateral: number): (number, number)
	local alongX, _, x0, z0 = segAxis(seg)
	if alongX then
		return x0 + d, (seg.az + seg.bz) / 2 + lateral
	end
	return (seg.ax + seg.bx) / 2 + lateral, z0 + d
end

local function palm(ctx: Context, c: CCfg, rng: Random, parent: Instance, xM: number, zM: number, yM: number)
	local key = if rng:NextNumber() < 0.3 then "fanPalm" else "datePalm"
	local base = CFrame.new(at(ctx, xM, zM, yM)) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0) * CFrame.Angles(rng:NextNumber(-0.06, 0.06), 0, rng:NextNumber(-0.06, 0.06))
	AssetRegistry.place(key, base, rng:NextNumber(0.8, 1.15), ctx.mps, parent, c.shadows.palms)
end

local function lamp(ctx: Context, c: CCfg, parent: Instance, xM: number, zM: number, yM: number, faceYaw: number)
	local f = c.furniture
	local base = CFrame.new(at(ctx, xM, zM, yM)) * CFrame.Angles(0, faceYaw, 0)
	local model = AssetRegistry.place("streetLamp", base, 0.16, ctx.mps, parent, c.shadows.lamps)
	if model then
		-- The head is the last piece; tag it for the light manager.
		local pieces = model:GetChildren()
		local head = pieces[#pieces]
		if head and head:IsA("BasePart") then
			CollectionService:AddTag(head, WorldLighting.LAMP_TAG)
		end
		return
	end
	-- Box fallback.
	local pole = Build.part({ name = "Pole", size = Vector3.new(ctx.s(f.poleWidthM), ctx.s(f.lampHeightM), ctx.s(f.poleWidthM)), cframe = base * CFrame.new(0, ctx.s(f.lampHeightM / 2), 0), color = f.poleColor, material = Enum.Material.Metal, parent = parent })
	local head = Build.part({ name = "Head", size = Vector3.new(ctx.s(f.headSizeM * 1.5), ctx.s(f.headSizeM * 0.4), ctx.s(f.headSizeM)), cframe = base * CFrame.new(0, ctx.s(f.lampHeightM - 0.3), ctx.s(f.lampArmM)), color = Color3.fromRGB(58, 58, 62), material = Enum.Material.Metal, parent = parent })
	CollectionService:AddTag(head, WorldLighting.LAMP_TAG)
	local _ = pole
end

local function signal(ctx: Context, parent: Instance, xM: number, zM: number, faceYaw: number)
	local base = CFrame.new(at(ctx, xM, zM, 0.12)) * CFrame.Angles(0, faceYaw, 0)
	local dark = Color3.fromRGB(44, 46, 50)
	Build.part({ name = "SignalPole", size = Vector3.new(ctx.s(0.25), ctx.s(5.2), ctx.s(0.25)), cframe = base * CFrame.new(0, ctx.s(2.6), 0), color = dark, material = Enum.Material.Metal, parent = parent })
	Build.part({ name = "SignalArm", size = Vector3.new(ctx.s(0.18), ctx.s(0.18), ctx.s(4.5)), cframe = base * CFrame.new(0, ctx.s(5.0), ctx.s(2.25)), color = dark, material = Enum.Material.Metal, parent = parent })
	Build.part({ name = "SignalHead", size = Vector3.new(ctx.s(0.35), ctx.s(1.1), ctx.s(0.4)), cframe = base * CFrame.new(0, ctx.s(4.4), ctx.s(4.2)), color = Color3.fromRGB(30, 30, 32), material = Enum.Material.Metal, parent = parent })
	-- One lit aspect, red or green, so it reads from a distance.
	local lit = if math.random() < 0.5 then Color3.fromRGB(255, 60, 50) else Color3.fromRGB(60, 230, 110)
	Build.part({ name = "Aspect", size = Vector3.new(ctx.s(0.22), ctx.s(0.22), ctx.s(0.08)), cframe = base * CFrame.new(0, ctx.s(4.4 + (if lit.R > 0.5 then 0.35 else -0.35)), ctx.s(4.2 - 0.24)), color = lit, material = Enum.Material.Neon, parent = parent })
end

local function parkedCar(ctx: Context, rng: Random, parent: Instance, xM: number, zM: number, yaw: number)
	local key = if rng:NextNumber() < 0.5 then "carA" else "carB"
	local base = CFrame.new(at(ctx, xM, zM, 0)) * CFrame.Angles(0, yaw + rng:NextNumber(-0.04, 0.04), 0)
	local model = AssetRegistry.place(key, base, 1, ctx.mps, parent, false)
	if not model then
		return
	end
	local colour = CAR_COLOURS[rng:NextInteger(1, #CAR_COLOURS)]
	for _, p in model:GetChildren() do
		if p:IsA("BasePart") then
			p.Color = colour
		end
	end
	-- Four wheels from the pack's own wheel mesh, axis X.
	local wb, tr = 1.4, 0.78
	for _, dx in { -tr, tr } do
		for _, dz in { -wb, wb } do
			AssetRegistry.place("wheel", base * CFrame.new(ctx.s(dx), 0, ctx.s(dz)), 1, ctx.mps, model, false)
		end
	end
end

local function bollard(ctx: Context, parent: Instance, xM: number, zM: number)
	local p = Build.part({ name = "Bollard", size = Vector3.new(ctx.s(0.9), ctx.s(0.22), ctx.s(0.22)), cframe = CFrame.new(at(ctx, xM, zM, 0.45)) * CFrame.Angles(0, 0, math.pi / 2), color = Color3.fromRGB(150, 146, 136), material = Enum.Material.Concrete, parent = parent })
	p.Shape = Enum.PartType.Cylinder
end

local function planter(ctx: Context, rng: Random, parent: Instance, xM: number, zM: number)
	Build.part({ name = "Planter", size = Vector3.new(ctx.s(1.6), ctx.s(0.7), ctx.s(1.6)), cframe = CFrame.new(at(ctx, xM, zM, 0.35)), color = Color3.fromRGB(176, 166, 148), material = Enum.Material.Concrete, parent = parent })
	local model = AssetRegistry.place("scrub", CFrame.new(at(ctx, xM, zM, 0.7)) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0), 0.5, ctx.mps, parent, false)
	if model then
		for _, p in model:GetChildren() do
			if p:IsA("BasePart") then
				p.Color = Color3.fromRGB(70, 96, 52)
			end
		end
	end
end

function Furniture.build(ctx: Context, c: CCfg, plan: Streets.Plan, parent: Instance): Folder
	local folder = Build.folder("Furniture", parent)
	local rng = Build.rng(c.seed + 13)
	local f = c.furniture
	local b = c.boulevard
	local s = c.surface
	local half = b.widthM / 2
	local medianTop = b.medianKerbHeightM + 0.02
	local pavementTop = s.pavementHeightM

	local palms = Build.folder("Palms", folder)
	local lamps = Build.folder("Lamps", folder)
	local cars = Build.folder("ParkedCars", folder)
	local street = Build.folder("Street", folder)

	-- Boulevards: median palms, lamps both pavements, parked cars in the
	-- parking lanes, bins and benches.
	for _, seg in plan.segments do
		local alongX, len = segAxis(seg)
		local yawAlong = if alongX then math.pi / 2 else 0
		if seg.boulevard then
			local d = f.medianPalmSpacingM / 2
			while d < len do
				local x, z = along(seg, d + rng:NextNumber(-f.medianPalmJitterM, f.medianPalmJitterM), rng:NextNumber(-1.2, 1.2))
				palm(ctx, c, rng, palms, x, z, medianTop)
				d += f.medianPalmSpacingM
			end
			local ld = f.lampSpacingM / 2
			while ld < len do
				for _, side in { -1, 1 } do
					local x, z = along(seg, ld, side * (half + b.kerbWidthM + f.lampSetbackM))
					-- Face the road: yaw so the bracket (+Z of the prop) points inward.
					local inward = if alongX then (if side > 0 then math.pi else 0) else (if side > 0 then -math.pi / 2 else math.pi / 2)
					lamp(ctx, c, lamps, x, z, pavementTop, inward)
				end
				ld += f.lampSpacingM
			end
			local pd = f.parkedCarSlotM
			while pd < len - f.parkedCarSlotM do
				for _, side in { -1, 1 } do
					if rng:NextNumber() < f.parkedCarChance then
						local x, z = along(seg, pd + rng:NextNumber(-0.6, 0.6), side * (half - b.parkingLaneM / 2))
						parkedCar(ctx, rng, cars, x, z, yawAlong + (if rng:NextNumber() < 0.5 then 0 else math.pi))
					end
				end
				pd += f.parkedCarSlotM
			end
			local bd = f.binSpacingM * 0.7
			while bd < len do
				for _, side in { -1, 1 } do
					if rng:NextNumber() < 0.6 then
						local x, z = along(seg, bd, side * (half + b.kerbWidthM + 1.6))
						AssetRegistry.place("bin", CFrame.new(at(ctx, x, z, pavementTop)), 1, ctx.mps, street, false)
					end
				end
				bd += f.binSpacingM
			end
			local ed = f.benchSpacingM * 0.4
			while ed < len do
				for _, side in { -1, 1 } do
					if rng:NextNumber() < 0.5 then
						local x, z = along(seg, ed, side * (half + b.kerbWidthM + 2.6))
						local face = if alongX then (if side > 0 then math.pi else 0) else (if side > 0 then -math.pi / 2 else math.pi / 2)
						AssetRegistry.place("bench", CFrame.new(at(ctx, x, z, pavementTop)) * CFrame.Angles(0, face + math.pi / 2, 0), 1, ctx.mps, street, false)
					end
				end
				ed += f.benchSpacingM
			end
		else
			-- Side streets: a lamp every 50 m on one side, a signal where the
			-- street meets a boulevard (its ends).
			local ld = f.sideStreetLampSpacingM / 2
			while ld < len do
				local x, z = along(seg, ld, (c.sideStreet.widthM / 2 + b.kerbWidthM + f.lampSetbackM))
				lamp(ctx, c, lamps, x, z, pavementTop, if alongX then math.pi else -math.pi / 2)
				ld += f.sideStreetLampSpacingM
			end
			for _, endAt in { 0, len } do
				-- Only the end that touches a boulevard: the block-centre crossing
				-- is the other end and has no signal.
				local x, z = along(seg, endAt, 0)
				local onBoulevard = false
				for _, n in plan.nodes do
					if n.roundabout and math.abs(n.x - x) < half + 2 and math.abs(n.z - z) < half + 2 then
						onBoulevard = true
					end
				end
				if onBoulevard then
					local sx, sz = along(seg, if endAt == 0 then 3 else len - 3, -(c.sideStreet.widthM / 2 + b.kerbWidthM + 0.8))
					signal(ctx, street, sx, sz, if alongX then (if endAt == 0 then -math.pi / 2 else math.pi / 2) else (if endAt == 0 then math.pi else 0))
				end
			end
		end
	end

	-- Roundabout islands.
	for _, n in plan.nodes do
		if n.roundabout then
			local r = c.roundabout.islandRadiusM - 4
			for i = 1, c.roundabout.palmsOnIsland do
				local a = (i / c.roundabout.palmsOnIsland) * math.pi * 2 + rng:NextNumber(-0.3, 0.3)
				local rr = rng:NextNumber(r * 0.3, r)
				palm(ctx, c, rng, palms, n.x + math.cos(a) * rr, n.z + math.sin(a) * rr, c.roundabout.islandHeightM + 0.12)
			end
		end
	end

	-- Plaza edges: bollards along the pavement line, planters at intervals.
	for _, p in plan.parcels do
		if p.district == "plaza" then
			local r = p.rect
			local inset = 1.0
			local function edge(x0: number, z0: number, x1: number, z1: number)
				local len = math.sqrt((x1 - x0) ^ 2 + (z1 - z0) ^ 2)
				local n = math.floor(len / 6)
				for i = 0, n do
					local t = if n > 0 then i / n else 0
					local x, z = x0 + (x1 - x0) * t, z0 + (z1 - z0) * t
					if i % 3 == 1 then
						planter(ctx, rng, street, x, z)
					else
						bollard(ctx, street, x, z)
					end
				end
			end
			edge(r.minX + inset, r.maxZ - inset, r.maxX - inset, r.maxZ - inset)
			edge(r.minX + inset, r.minZ + inset, r.maxX - inset, r.minZ + inset)
			edge(r.minX + inset, r.minZ + inset + 6, r.minX + inset, r.maxZ - inset - 6)
			edge(r.maxX - inset, r.minZ + inset + 6, r.maxX - inset, r.maxZ - inset - 6)
			-- Lamps through the plaza.
			local x = r.minX + 20
			while x < r.maxX - 10 do
				local z = r.minZ + 20
				while z < r.maxZ - 10 do
					lamp(ctx, c, lamps, x, z, 0, rng:NextNumber(0, math.pi * 2))
					z += f.plazaLampSpacingM * 1.5
				end
				x += f.plazaLampSpacingM * 1.5
			end
		end
	end

	return folder
end

return Furniture
