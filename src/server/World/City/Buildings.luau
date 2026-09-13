--!strict
-- The building generator. Every parcel the street grid left behind is
-- filled by its district: a commercial parcel gets a row of shop buildings
-- along its boulevard frontages, a residential parcel gets walled villa
-- compounds around its edges, the tower parcel gets podium-and-tower blocks,
-- the plaza is a flat painted car park, and a lot is left as sand. Boxes
-- and the odd cylinder from CityConfig and the seeded random, and on a
-- share of the shop slots and tower spots a textured store mesh building
-- from AssetRegistry (cityBlocks, cityTowers), which is where the real
-- facades come from.
--
-- Silhouettes are broken on purpose: widths, depths and heights vary per
-- building, rows have gaps, villas get a smaller upper tier, towers a
-- setback. Detail goes where a driver sees it: the bottom three storeys get
-- window strips split into lit and dark segments, an awning and a fascia at
-- shop level, a stain band at the base of the wall; above that the floors
-- are a single dark band each. Roofs get a parapet, AC units and a water
-- tank, which is what a Gulf skyline is made of from a car window.
--
-- Walls collide. Nothing else here does.
local Build = require(script.Parent.Parent.Build)
local RoadNetwork = require(script.Parent.Parent.RoadNetwork)
local AssetRegistry = require(script.Parent.Parent.AssetRegistry)
local CityConfig = require(script.Parent.CityConfig)
local Streets = require(script.Parent.Streets)

type Context = RoadNetwork.Context
type CCfg = CityConfig.Config
type Parcel = Streets.Parcel
type Rect = Streets.Rect

local Buildings = {}

local function tinted(colour: Color3, rng: Random, tone: number): Color3
	local t = rng:NextNumber(-tone, tone)
	return if t < 0 then colour:Lerp(Color3.new(0, 0, 0), -t) else colour:Lerp(Color3.new(1, 1, 1), t)
end

local function wallColour(c: CCfg, rng: Random): Color3
	local b = c.buildings
	local base = if rng:NextNumber() < b.accentChance then b.accentPalette[rng:NextInteger(1, #b.accentPalette)] else b.palette[rng:NextInteger(1, #b.palette)]
	return tinted(base, rng, b.tone)
end

local WALL_MATERIALS = { Enum.Material.Concrete, Enum.Material.Sandstone, Enum.Material.SmoothPlastic, Enum.Material.Limestone }
local SIDE_FACES = { Enum.NormalId.Front, Enum.NormalId.Back, Enum.NormalId.Left, Enum.NormalId.Right }

-- A tiled window grid on the body, three storeys per tile, tinted toward
-- the wall colour so the palette stays sand and cream. This replaced most
-- of the window-band parts: one texture per face instead of a part per
-- floor.
local function facade(ctx: Context, c: CCfg, rng: Random, part: BasePart, kind: string, tint: Color3)
	AssetRegistry.facade(part, kind, rng, SIDE_FACES, ctx.s(c.buildings.storeyM * 3), tint, 0.08)
end

-- Axis-aligned box in world metres. cy is the centre height above the
-- surface.
local function box(ctx: Context, parent: Instance, name: string, cx: number, cy: number, cz: number, sx: number, sy: number, sz: number, color: Color3, material: Enum.Material, collide: boolean, castShadow: boolean): Part
	return Build.part({
		name = name,
		size = Vector3.new(ctx.s(sx), ctx.s(sy), ctx.s(sz)),
		cframe = CFrame.new(ctx.s(cx), ctx.surfaceY + ctx.s(cy), ctx.s(cz)),
		color = color,
		material = material,
		parent = parent,
		collide = collide,
		castShadow = castShadow,
	})
end

-- A face of a building: which way it looks and where its outer plane is.
type Face = { dir: string, cx: number, cz: number, width: number } -- dir "N" (+Z) "S" (-Z) "E" (+X) "W" (-X); cx,cz = centre of the face at the wall plane

local function faceOf(dir: string, cx: number, cz: number, sx: number, sz: number): Face
	if dir == "N" then
		return { dir = dir, cx = cx, cz = cz + sz / 2, width = sx }
	elseif dir == "S" then
		return { dir = dir, cx = cx, cz = cz - sz / 2, width = sx }
	elseif dir == "E" then
		return { dir = dir, cx = cx + sx / 2, cz = cz, width = sz }
	end
	return { dir = dir, cx = cx - sx / 2, cz = cz, width = sz }
end

-- A thin box proud of a face: lateral offset along the face, height, size.
local function onFace(ctx: Context, parent: Instance, name: string, f: Face, along: number, y: number, len: number, h: number, depth: number, color: Color3, material: Enum.Material, transparency: number?): Part
	local out = depth / 2 + 0.01
	local p: Part
	if f.dir == "N" then
		p = box(ctx, parent, name, f.cx + along, y, f.cz + out, len, h, depth, color, material, false, false)
	elseif f.dir == "S" then
		p = box(ctx, parent, name, f.cx + along, y, f.cz - out, len, h, depth, color, material, false, false)
	elseif f.dir == "E" then
		p = box(ctx, parent, name, f.cx + out, y, f.cz + along, depth, h, len, color, material, false, false)
	else
		p = box(ctx, parent, name, f.cx - out, y, f.cz + along, depth, h, len, color, material, false, false)
	end
	if transparency then
		p.Transparency = transparency
	end
	return p
end

-- Window strips up a face: segmented and partly lit on the lower storeys,
-- one dark band per storey above.
local function windows(ctx: Context, c: CCfg, rng: Random, parent: Instance, f: Face, storeys: number, groundFloorShop: boolean)
	local b = c.buildings
	local usable = f.width * 0.82
	local segs = b.windowSegmentsPerFace
	local segW = usable / segs
	-- With the facade texture carrying the window grid, only the lit
	-- windows are parts now: a few glowing segments on the first two
	-- floors above the shop, which is what a driver sees at dusk.
	local first = if groundFloorShop then 2 else 1
	for st = first, math.min(storeys, first + 1) do
		local y = (st - 0.5) * b.storeyM + 0.2
		for i = 1, segs do
			if rng:NextNumber() < b.litChance then
				local along = -usable / 2 + segW * (i - 0.5)
				onFace(ctx, parent, "Window", f, along, y, segW * 0.7, b.windowBandHeightM * 0.8, b.windowInsetM, b.windowLit, Enum.Material.Neon, rng:NextNumber(0.5, 0.75))
			end
		end
	end
end

-- One lip slab proud of the roof edge instead of four walls: from the
-- street the silhouette is the same and it is a quarter of the parts.
local function parapet(ctx: Context, c: CCfg, parent: Instance, cx: number, cz: number, sx: number, sz: number, topY: number, color: Color3, castShadow: boolean)
	local b = c.buildings
	local h, t = b.parapetHeightM, b.parapetThicknessM
	box(ctx, parent, "Parapet", cx, topY + h / 2, cz, sx + t, h, sz + t, color, Enum.Material.Concrete, false, castShadow)
end

local function roofClutter(ctx: Context, c: CCfg, rng: Random, parent: Instance, cx: number, cz: number, sx: number, sz: number, topY: number)
	local b = c.buildings
	local inner = 1.5
	if rng:NextNumber() < b.acUnitChance then
		for _ = 1, rng:NextInteger(1, b.acUnitsMax) do
			local ax = cx + rng:NextNumber(-sx / 2 + inner, sx / 2 - inner)
			local az = cz + rng:NextNumber(-sz / 2 + inner, sz / 2 - inner)
			box(ctx, parent, "AC", ax, topY + 0.45, az, 1.1, 0.9, 0.9, tinted(Color3.fromRGB(190, 190, 186), rng, 0.1), Enum.Material.Metal, false, false)
		end
	end
	if rng:NextNumber() < b.waterTankChance then
		local tx = cx + rng:NextNumber(-sx / 2 + inner, sx / 2 - inner)
		local tz = cz + rng:NextNumber(-sz / 2 + inner, sz / 2 - inner)
		local tank = box(ctx, parent, "WaterTank", tx, topY + 1.1, tz, 2.2, 2.2, 2.2, tinted(Color3.fromRGB(232, 232, 226), rng, 0.05), Enum.Material.SmoothPlastic, false, false)
		tank.Shape = Enum.PartType.Cylinder
		tank.CFrame = tank.CFrame * CFrame.Angles(0, 0, math.pi / 2)
	end
end

-- Which face of an onFace() box looks out from the wall, for a SurfaceGui.
local function outwardFace(dir: string): Enum.NormalId
	if dir == "N" then
		return Enum.NormalId.Back
	elseif dir == "S" then
		return Enum.NormalId.Front
	elseif dir == "E" then
		return Enum.NormalId.Right
	end
	return Enum.NormalId.Left
end

-- A shop sign: a lit box on the fascia with the shop's name in Arabic over
-- English, the way every Riyadh shop fascia reads. Text is a SurfaceGui so
-- it needs no asset and stays crisp.
local function shopSign(ctx: Context, c: CCfg, rng: Random, parent: Instance, f: Face, along: number, y: number, widthM: number, heightM: number, panel: Color3)
	local cm = c.buildings.commercial
	local name = cm.shopNames[rng:NextInteger(1, #cm.shopNames)]
	-- Opaque, not Neon: a half-transparent Neon panel bloomed straight over
	-- its own lettering and the sign read as a blank white box.
	local sign = onFace(ctx, parent, "Sign", f, along, y, widthM, heightM, 0.22, panel, Enum.Material.SmoothPlastic)
	local gui = Instance.new("SurfaceGui")
	gui.Face = outwardFace(f.dir)
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.LightInfluence = 0
	gui.Brightness = 1.4 -- the letters glow a touch, like a backlit box
	gui.MaxDistance = 260
	gui.Parent = sign
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Vertical
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.Parent = gui
	local textColor = if (panel.R + panel.G + panel.B) / 3 > 0.6 then Color3.fromRGB(30, 30, 34) else Color3.fromRGB(250, 250, 245)
	type Line = { text: string, height: number, font: Enum.Font }
	local lines: { Line } = {
		{ text = name[1], height = 0.55, font = Enum.Font.GothamBold },
		{ text = name[2], height = 0.32, font = Enum.Font.GothamMedium },
	}
	for i, line in lines do
		local l = Instance.new("TextLabel")
		l.BackgroundTransparency = 1
		l.Size = UDim2.fromScale(0.92, line.height)
		l.Text = line.text
		l.Font = line.font
		l.TextScaled = true
		l.TextColor3 = textColor
		l.LayoutOrder = i
		l.Parent = gui
	end
end

-- A Najdi parapet: square crenellations along the roof edge of the main
-- face, on top of the plain parapet.
local function crenellations(ctx: Context, c: CCfg, parent: Instance, f: Face, topY: number, colour: Color3)
	local b = c.buildings
	local step = 2.2
	local n = math.max(2, math.floor(f.width / step))
	for i = 0, n - 1 do
		local along = -f.width / 2 + step / 2 + i * (f.width / n)
		onFace(ctx, parent, "Merlon", f, along, topY + b.parapetHeightM + 0.35, 0.9, 0.7, b.parapetThicknessM + 0.05, colour, Enum.Material.Concrete)
	end
end

-- A mesh building in a shop slot: one of AssetRegistry.cityBlocks scaled
-- so its long side fills the slot's frontage, its front on the same
-- setback line the box shops use, long axis along the street. Returns
-- false if no mesh is available, and the caller builds the box shop.
local function meshBlock(ctx: Context, c: CCfg, rng: Random, parent: Instance, cx: number, cz: number, sx: number, sz: number, mainDir: string): boolean
	local keys = AssetRegistry.cityBlocks
	local key = keys[rng:NextInteger(1, #keys)]
	if not AssetRegistry.hasProp(key) then
		return false
	end
	local size = AssetRegistry.sizeM(key)
	local long, short = math.max(size.X, size.Z), math.min(size.X, size.Z)
	local alongStreet = if mainDir == "N" or mainDir == "S" then sx else sz
	local scale = math.clamp(alongStreet / long, c.buildings.meshMinScale, c.buildings.meshMaxScale)
	local depth = short * scale
	-- The long axis along the street: for a north or south frontage the
	-- street runs along X, so a mesh whose long axis is Z turns a quarter.
	local longIsX = size.X >= size.Z
	local streetIsX = mainDir == "N" or mainDir == "S"
	local yaw = if longIsX == streetIsX then 0 else math.pi / 2
	if rng:NextNumber() < 0.5 then
		yaw += math.pi -- both facades get used
	end
	local px, pz: number
	if mainDir == "N" then
		px, pz = cx, cz + sz / 2 - depth / 2
	elseif mainDir == "S" then
		px, pz = cx, cz - sz / 2 + depth / 2
	elseif mainDir == "E" then
		px, pz = cx + sx / 2 - depth / 2, cz
	else
		px, pz = cx - sx / 2 + depth / 2, cz
	end
	local base = CFrame.new(ctx.s(px), ctx.surfaceY, ctx.s(pz)) * CFrame.Angles(0, yaw, 0)
	local model = AssetRegistry.place(key, base, scale, ctx.mps, parent, c.shadows.buildings, true)
	if not model then
		return false
	end
	model.Name = "MeshBlock"
	return true
end

-- One shop building: body, stain, windows on the street faces, awning and
-- fascia on the main face, parapet, roof clutter.
local function shop(ctx: Context, c: CCfg, rng: Random, parent: Instance, cx: number, cz: number, sx: number, sz: number, storeys: number, mainDir: string, otherDir: string?)
	local b = c.buildings
	local cm = b.commercial
	local h = storeys * b.storeyM
	-- A share of the slots take a mesh building instead of the box shop.
	if rng:NextNumber() < b.meshChance and meshBlock(ctx, c, rng, parent, cx, cz, sx, sz, mainDir) then
		return
	end
	local colour = wallColour(c, rng)
	local material = WALL_MATERIALS[rng:NextInteger(1, #WALL_MATERIALS)]
	local model = Instance.new("Model")
	model.Name = "Shop"
	model.Parent = parent
	local wall = box(ctx, model, "Wall", cx, h / 2, cz, sx, h, sz, colour, material, true, c.shadows.buildings)
	facade(ctx, c, rng, wall, "midRise", colour:Lerp(Color3.new(1, 1, 1), 0.35))
	local main = faceOf(mainDir, cx, cz, sx, sz)
	-- Pilasters on some, which breaks the box outline at street level.
	if rng:NextNumber() < 0.4 then
		for _, side in { -1, 1 } do
			onFace(ctx, model, "Pilaster", main, side * main.width * 0.42, h / 2, 0.8, h * 0.98, 0.35, colour:Lerp(Color3.new(1, 1, 1), 0.1), material)
		end
	end
	-- Arcade: a colonnade along the ground floor, the shopfront set back
	-- behind it. What most Gulf shop rows actually look like from a car.
	local arcade = rng:NextNumber() < cm.arcadeChance
	if arcade then
		local cols = math.max(3, math.floor(main.width / 5))
		for i = 0, cols do
			local along = -main.width / 2 + main.width * (i / cols)
			if math.abs(along) < main.width / 2 - 0.4 then
				onFace(ctx, model, "Column", main, along, cm.awningHeightM / 2 + 0.1, 0.6, cm.awningHeightM + 0.2, 2.4, colour:Lerp(Color3.new(1, 1, 1), 0.06), material)
			end
		end
		onFace(ctx, model, "ArcadeSlab", main, 0, cm.awningHeightM + 0.35, main.width * 0.98, 0.5, 2.6, colour:Lerp(Color3.new(0, 0, 0), 0.08), material)
	end
	-- Balconies on the second and third floors of some.
	if rng:NextNumber() < cm.balconyChance and storeys >= 3 then
		for st = 2, math.min(3, storeys) do
			local along = rng:NextNumber(-main.width * 0.3, main.width * 0.3)
			onFace(ctx, model, "Balcony", main, along, (st - 1) * b.storeyM + 0.15, 3.2, 0.25, 1.3, colour:Lerp(Color3.new(1, 1, 1), 0.1), Enum.Material.Concrete)
			onFace(ctx, model, "Rail", main, along, (st - 1) * b.storeyM + 0.75, 3.2, 1.0, 0.08, Color3.fromRGB(60, 60, 64), Enum.Material.Metal, 0.3)
			local _ = st
		end
	end
	-- AC units hung on the facade at first-floor height, the mesh.
	if rng:NextNumber() < cm.facadeAcChance and AssetRegistry.hasProp("acUnit") then
		for _ = 1, rng:NextInteger(1, 2) do
			local along = rng:NextNumber(-main.width * 0.4, main.width * 0.4)
			local y = b.storeyM + rng:NextNumber(0.6, 1.8)
			local px: number, pz: number, yaw: number
			if main.dir == "N" then
				px, pz, yaw = main.cx + along, main.cz + 0.2, math.pi / 2
			elseif main.dir == "S" then
				px, pz, yaw = main.cx + along, main.cz - 0.2, -math.pi / 2
			elseif main.dir == "E" then
				px, pz, yaw = main.cx + 0.2, main.cz + along, 0
			else
				px, pz, yaw = main.cx - 0.2, main.cz + along, math.pi
			end
			AssetRegistry.place("acUnit", CFrame.new(ctx.s(px), ctx.surfaceY + ctx.s(y), ctx.s(pz)) * CFrame.Angles(0, yaw, 0), 1, ctx.mps, model, false)
		end
	end
	-- A blade sign standing off the corner with the shop's Arabic name on
	-- it, the tall blue signs of Riyadh's Olaya and Tahlia streets.
	if rng:NextNumber() < cm.verticalSignChance then
		local blade = onFace(ctx, model, "VSign", main, main.width * 0.42, cm.awningHeightM + 3.0, 1.0, 3.6, 0.3, Color3.fromRGB(28, 64, 120), Enum.Material.SmoothPlastic)
		local name = cm.shopNames[rng:NextInteger(1, #cm.shopNames)]
		local gui = Instance.new("SurfaceGui")
		gui.Face = outwardFace(main.dir)
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 40
		gui.LightInfluence = 0
		gui.MaxDistance = 220
		gui.Parent = blade
		local l = Instance.new("TextLabel")
		l.BackgroundTransparency = 1
		l.Size = UDim2.fromScale(1, 1)
		l.Text = name[1]
		l.TextWrapped = true
		l.TextScaled = true
		l.Font = Enum.Font.GothamBold
		l.TextColor3 = Color3.fromRGB(250, 250, 245)
		l.Parent = gui
	end
	-- A rooftop billboard on some.
	if rng:NextNumber() < cm.billboardChance then
		local bw = math.min(12, sx * 0.7)
		local panel = cm.fasciaPalette[rng:NextInteger(1, #cm.fasciaPalette)]
		box(ctx, model, "BillboardFrame", cx, h + 2.2, cz, 0.25, 4.4, 0.25, Color3.fromRGB(80, 80, 84), Enum.Material.Metal, false, false)
		box(ctx, model, "Billboard", cx, h + 4.2, cz, bw, 3.6, 0.2, tinted(panel, rng, 0.1), Enum.Material.SmoothPlastic, false, false)
	end
	-- Stain at the base of the main wall.
	if rng:NextNumber() < b.stainChance then
		onFace(ctx, model, "Stain", main, 0, b.stainHeightM / 2, main.width * 0.98, b.stainHeightM, 0.03, colour:Lerp(Color3.new(0, 0, 0), rng:NextNumber(0.12, 0.28)), Enum.Material.Concrete)
	end
	windows(ctx, c, rng, model, main, storeys, true)
	if otherDir then
		windows(ctx, c, rng, model, faceOf(otherDir, cx, cz, sx, sz), math.min(storeys, 3), false)
	end
	-- Shop level: a dark glazed front, a fascia and an awning.
	onFace(ctx, model, "Shopfront", main, 0, 1.6, main.width * 0.86, 2.8, 0.1, b.windowDark, Enum.Material.Glass, 0.05)
	local fascia = cm.fasciaPalette[rng:NextInteger(1, #cm.fasciaPalette)]
	onFace(ctx, model, "Fascia", main, 0, cm.awningHeightM + cm.fasciaHeightM / 2, main.width * 0.9, cm.fasciaHeightM, 0.12, tinted(fascia, rng, 0.08), Enum.Material.SmoothPlastic)
	if rng:NextNumber() < cm.awningChance then
		onFace(ctx, model, "Awning", main, 0, cm.awningHeightM, main.width * rng:NextNumber(0.5, 0.85), 0.12, cm.awningDepthM, tinted(fascia, rng, 0.1):Lerp(Color3.new(1, 1, 1), 0.15), Enum.Material.Fabric)
	end
	if rng:NextNumber() < cm.signChance then
		local signW = math.min(6, main.width * 0.45)
		local signPanel = if rng:NextNumber() < 0.5 then Color3.fromRGB(240, 238, 230) else fascia
		shopSign(ctx, c, rng, model, main, rng:NextNumber(-main.width * 0.25, main.width * 0.25), cm.awningHeightM + cm.fasciaHeightM + 1.1, signW, 1.3, signPanel)
	end
	parapet(ctx, c, model, cx, cz, sx, sz, h, colour:Lerp(Color3.new(1, 1, 1), 0.08), c.shadows.buildings)
	if rng:NextNumber() < cm.crenellationChance then
		crenellations(ctx, c, model, main, h, colour:Lerp(Color3.new(1, 1, 1), 0.08))
	end
	roofClutter(ctx, c, rng, model, cx, cz, sx, sz, h)
end

-- A row of shops along one edge of a parcel. edge is the parcel side the
-- row fronts; the row runs from a to b along that side.
local function shopRow(ctx: Context, c: CCfg, rng: Random, parent: Instance, rect: Rect, edge: string, skipStart: number, skipEnd: number)
	local cm = c.buildings.commercial
	local b = c.buildings
	local along0: number, along1: number
	if edge == "N" or edge == "S" then
		along0, along1 = rect.minX + skipStart, rect.maxX - skipEnd
	else
		along0, along1 = rect.minZ + skipStart, rect.maxZ - skipEnd
	end
	local d = along0
	while d < along1 - cm.minWidthM do
		local w = math.min(rng:NextNumber(cm.minWidthM, cm.maxWidthM), along1 - d)
		local depth = rng:NextNumber(cm.minDepthM, cm.maxDepthM)
		local storeys = rng:NextInteger(cm.minStoreys, cm.maxStoreys)
		local mid = d + w / 2
		local cx: number, cz: number, sx: number, sz: number
		if edge == "N" then
			cx, cz, sx, sz = mid, rect.maxZ - cm.setbackM - depth / 2, w, depth
		elseif edge == "S" then
			cx, cz, sx, sz = mid, rect.minZ + cm.setbackM + depth / 2, w, depth
		elseif edge == "E" then
			cx, cz, sx, sz = rect.maxX - cm.setbackM - depth / 2, mid, depth, w
		else
			cx, cz, sx, sz = rect.minX + cm.setbackM + depth / 2, mid, depth, w
		end
		shop(ctx, c, rng, parent, cx, cz, sx, sz, storeys, edge, nil)
		d += w + (if rng:NextNumber() < cm.gapChance then cm.gapM else 0.6)
	end
	local _ = b
end

local function commercial(ctx: Context, c: CCfg, rng: Random, parent: Instance, p: Parcel)
	local cm = c.buildings.commercial
	local r = p.rect
	local depthMax = cm.maxDepthM + cm.setbackM
	-- Rows along the two boulevard sides, corner left to the first row.
	local rows: { string } = {}
	for _, side in { "N", "S", "E", "W" } do
		local facing = if side == "N" then p.north elseif side == "S" then p.south elseif side == "E" then p.east else p.west
		if facing == "boulevard" then
			table.insert(rows, side)
		end
	end
	-- One side street frontage too, so the block is not hollow.
	for _, side in { "N", "S", "E", "W" } do
		local facing = if side == "N" then p.north elseif side == "S" then p.south elseif side == "E" then p.east else p.west
		if facing == "side" and #rows < 3 then
			table.insert(rows, side)
			break
		end
	end
	local taken: { [string]: boolean } = {}
	for _, side in rows do
		-- Skip the corners already occupied by a perpendicular row.
		local skipStart, skipEnd = 0, 0
		if side == "N" or side == "S" then
			if taken.W then skipStart = depthMax end
			if taken.E then skipEnd = depthMax end
		else
			if taken.S then skipStart = depthMax end
			if taken.N then skipEnd = depthMax end
		end
		shopRow(ctx, c, rng, parent, r, side, skipStart, skipEnd)
		taken[side] = true
	end
	-- The interior is a car park.
	local inset = depthMax + 2
	local ix0, ix1 = r.minX + (if taken.W then inset else 2), r.maxX - (if taken.E then inset else 2)
	local iz0, iz1 = r.minZ + (if taken.S then inset else 2), r.maxZ - (if taken.N then inset else 2)
	if ix1 - ix0 > 10 and iz1 - iz0 > 10 then
		box(ctx, parent, "CarPark", (ix0 + ix1) / 2, -0.1, (iz0 + iz1) / 2, ix1 - ix0, 0.2, iz1 - iz0, tinted(c.surface.sideStreetColor, rng, 0.04), Enum.Material.Asphalt, true, false)
	end
end

-- One walled villa compound. gateDir is the street side.
local function villa(ctx: Context, c: CCfg, rng: Random, parent: Instance, cx: number, cz: number, sx: number, sz: number, gateDir: string)
	local b = c.buildings
	local rs = b.residential
	local model = Instance.new("Model")
	model.Name = "Villa"
	model.Parent = parent
	local wallColour3 = wallColour(c, rng)
	local wh, wt = rs.wallHeightM, rs.wallThicknessM
	-- Compound wall with a gate gap on the street side.
	local function wall(dir: string)
		local gap = if dir == gateDir then rs.gateWidthM else 0
		if dir == "N" or dir == "S" then
			local z = if dir == "N" then cz + sz / 2 - wt / 2 else cz - sz / 2 + wt / 2
			if gap > 0 then
				local seg = (sx - gap) / 2
				box(ctx, model, "Wall", cx - sx / 2 + seg / 2, wh / 2, z, seg, wh, wt, wallColour3, Enum.Material.Concrete, true, c.shadows.compoundWalls)
				box(ctx, model, "Wall", cx + sx / 2 - seg / 2, wh / 2, z, seg, wh, wt, wallColour3, Enum.Material.Concrete, true, c.shadows.compoundWalls)
				box(ctx, model, "Gate", cx, rs.gateHeightM / 2, z, gap, rs.gateHeightM, 0.08, tinted(rs.gateColor, rng, 0.1), Enum.Material.Metal, true, false)
			else
				box(ctx, model, "Wall", cx, wh / 2, z, sx, wh, wt, wallColour3, Enum.Material.Concrete, true, c.shadows.compoundWalls)
			end
		else
			local x = if dir == "E" then cx + sx / 2 - wt / 2 else cx - sx / 2 + wt / 2
			if gap > 0 then
				local seg = (sz - gap) / 2
				box(ctx, model, "Wall", x, wh / 2, cz - sz / 2 + seg / 2, wt, wh, seg, wallColour3, Enum.Material.Concrete, true, c.shadows.compoundWalls)
				box(ctx, model, "Wall", x, wh / 2, cz + sz / 2 - seg / 2, wt, wh, seg, wallColour3, Enum.Material.Concrete, true, c.shadows.compoundWalls)
				box(ctx, model, "Gate", x, rs.gateHeightM / 2, cz, 0.08, rs.gateHeightM, gap, tinted(rs.gateColor, rng, 0.1), Enum.Material.Metal, true, false)
			else
				box(ctx, model, "Wall", x, wh / 2, cz, wt, wh, sz, wallColour3, Enum.Material.Concrete, true, c.shadows.compoundWalls)
			end
		end
	end
	wall("N")
	wall("S")
	wall("E")
	wall("W")
	-- The house, set back, its own colour, sometimes with an upper tier.
	local vw = math.min(rng:NextNumber(rs.villaMinWidthM, rs.villaMaxWidthM), sx - 2 * rs.villaSetbackM)
	local vd = math.min(rng:NextNumber(rs.villaMinDepthM, rs.villaMaxDepthM), sz - 2 * rs.villaSetbackM)
	local storeys = rng:NextInteger(rs.minStoreys, rs.maxStoreys)
	local h = storeys * b.storeyM
	local vx = cx + rng:NextNumber(-(sx - vw) / 2 + rs.villaSetbackM, (sx - vw) / 2 - rs.villaSetbackM)
	local vz = cz + rng:NextNumber(-(sz - vd) / 2 + rs.villaSetbackM, (sz - vd) / 2 - rs.villaSetbackM)
	local houseColour = wallColour(c, rng)
	local material = WALL_MATERIALS[rng:NextInteger(1, #WALL_MATERIALS)]
	box(ctx, model, "House", vx, h / 2, vz, vw, h, vd, houseColour, material, true, c.shadows.buildings)
	local street = faceOf(gateDir, vx, vz, vw, vd)
	windows(ctx, c, rng, model, street, storeys, false)
	local topY = h
	if rng:NextNumber() < rs.tierChance then
		local tw, td, th = vw * rng:NextNumber(0.45, 0.7), vd * rng:NextNumber(0.5, 0.75), b.storeyM * 0.9
		box(ctx, model, "Tier", vx + rng:NextNumber(-0.2, 0.2) * (vw - tw), h + th / 2, vz + rng:NextNumber(-0.2, 0.2) * (vd - td), tw, th, td, houseColour, material, false, c.shadows.buildings)
		topY = h + th
		parapet(ctx, c, model, vx, vz, vw, vd, h, houseColour, false)
	else
		parapet(ctx, c, model, vx, vz, vw, vd, h, houseColour, false)
	end
	roofClutter(ctx, c, rng, model, vx, vz, vw, vd, topY)
	-- A satellite dish on most roofs: a tilted disc on a stub, pointing
	-- the same way across the whole city, which is what a real skyline of
	-- dishes does.
	if rng:NextNumber() < rs.dishChance then
		local dx = vx + rng:NextNumber(-vw * 0.35, vw * 0.35)
		local dz = vz + rng:NextNumber(-vd * 0.35, vd * 0.35)
		local dish = box(ctx, model, "Dish", dx, topY + 1.0, dz, 0.06, 1.1, 1.1, Color3.fromRGB(226, 226, 220), Enum.Material.Metal, false, false)
		dish.Shape = Enum.PartType.Cylinder
		dish.CFrame = CFrame.new(ctx.s(dx), ctx.surfaceY + ctx.s(topY + 1.0), ctx.s(dz)) * CFrame.Angles(0, math.rad(35), math.rad(40))
		box(ctx, model, "DishStub", dx, topY + 0.45, dz, 0.1, 0.9, 0.1, Color3.fromRGB(120, 120, 116), Enum.Material.Metal, false, false)
	end
	-- A wall-mounted AC or two on the street face, at first-floor height:
	-- the mesh if it loaded, a box if not.
	if rng:NextNumber() < 0.6 then
		local along = rng:NextNumber(-vw * 0.3, vw * 0.3)
		local y = b.storeyM + 1.2
		local placed = false
		if AssetRegistry.hasProp("acUnit") then
			local px: number, pz: number, yaw: number
			if street.dir == "N" then
				px, pz, yaw = street.cx + along, street.cz + 0.2, math.pi / 2
			elseif street.dir == "S" then
				px, pz, yaw = street.cx + along, street.cz - 0.2, -math.pi / 2
			elseif street.dir == "E" then
				px, pz, yaw = street.cx + 0.2, street.cz + along, 0
			else
				px, pz, yaw = street.cx - 0.2, street.cz + along, math.pi
			end
			placed = AssetRegistry.place("acUnit", CFrame.new(ctx.s(px), ctx.surfaceY + ctx.s(y - 0.45), ctx.s(pz)) * CFrame.Angles(0, yaw, 0), 1, ctx.mps, model, false) ~= nil
		end
		if not placed then
			onFace(ctx, model, "AC", street, along, y, 0.9, 0.7, 0.4, Color3.fromRGB(200, 200, 196), Enum.Material.Metal)
		end
	end
end

local function residential(ctx: Context, c: CCfg, rng: Random, parent: Instance, p: Parcel)
	local rs = c.buildings.residential
	local r = p.rect
	local lw, ld, gap = rs.lotWidthM, rs.lotDepthM, rs.lotGapM
	-- North and south rows across the full width, east and west rows between.
	local function row(edge: string)
		local a0: number, a1: number
		if edge == "N" or edge == "S" then
			a0, a1 = r.minX, r.maxX
		else
			a0, a1 = r.minZ + ld + gap, r.maxZ - ld - gap
		end
		local n = math.floor((a1 - a0 + gap) / (lw + gap))
		if n < 1 then
			return
		end
		local used = n * lw + (n - 1) * gap
		local start = a0 + (a1 - a0 - used) / 2
		for i = 0, n - 1 do
			-- An empty plot now and then: a city edge is never full.
			if rng:NextNumber() < 0.1 then
				continue
			end
			local mid = start + i * (lw + gap) + lw / 2
			if edge == "N" then
				villa(ctx, c, rng, parent, mid, r.maxZ - ld / 2, lw, ld, "N")
			elseif edge == "S" then
				villa(ctx, c, rng, parent, mid, r.minZ + ld / 2, lw, ld, "S")
			elseif edge == "E" then
				villa(ctx, c, rng, parent, r.maxX - ld / 2, mid, ld, lw, "E")
			else
				villa(ctx, c, rng, parent, r.minX + ld / 2, mid, ld, lw, "W")
			end
		end
	end
	row("N")
	row("S")
	row("E")
	row("W")
	-- The interior is unbuilt ground: a few bushes so it is not a bare
	-- sheet where the gaps between compounds show it.
	for _ = 1, 6 do
		local x = rng:NextNumber(r.minX + ld + 4, r.maxX - ld - 4)
		local z = rng:NextNumber(r.minZ + ld + 4, r.maxZ - ld - 4)
		AssetRegistry.place("scrub", CFrame.new(ctx.s(x), ctx.surfaceY, ctx.s(z)) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0), rng:NextNumber(0.4, 0.8), ctx.mps, parent, false)
	end
end

local function tower(ctx: Context, c: CCfg, rng: Random, parent: Instance, cx: number, cz: number, faceDir: string)
	local b = c.buildings
	local tw = b.towers
	local model = Instance.new("Model")
	model.Name = "Tower"
	model.Parent = parent
	-- A share of the tower spots take a mesh tower: a real office tower
	-- with its own podium, plant room and curtain wall, scaled within the
	-- range CityConfig gives it and never wider than a podium slot.
	if rng:NextNumber() < tw.meshChance then
		local keys = AssetRegistry.cityTowers
		local key = keys[rng:NextInteger(1, #keys)]
		local range = tw.meshScales[key]
		if range and AssetRegistry.hasProp(key) then
			local size = AssetRegistry.sizeM(key)
			local scale = rng:NextNumber(range[1], range[2])
			local foot = math.max(size.X, size.Z) * scale
			if foot > tw.podiumMaxM then
				scale *= tw.podiumMaxM / foot
			end
			local yaw = rng:NextInteger(0, 3) * math.pi / 2
			local base = CFrame.new(ctx.s(cx), ctx.surfaceY, ctx.s(cz)) * CFrame.Angles(0, yaw, 0)
			if AssetRegistry.place(key, base, scale, ctx.mps, model, c.shadows.buildings, true) then
				local topY = size.Y * scale
				box(ctx, model, "Beacon", cx, topY + 0.8, cz, 0.8, 0.8, 0.8, Color3.fromRGB(255, 70, 60), Enum.Material.Neon, false, false)
				return
			end
		end
	end
	local podium = rng:NextNumber(tw.podiumMinM, tw.podiumMaxM)
	local ph = tw.podiumStoreys * b.storeyM
	local podiumColour = wallColour(c, rng)
	local podiumPart = box(ctx, model, "Podium", cx, ph / 2, cz, podium, ph, podium, podiumColour, Enum.Material.Concrete, true, c.shadows.buildings)
	facade(ctx, c, rng, podiumPart, "midRise", podiumColour:Lerp(Color3.new(1, 1, 1), 0.35))
	-- Shop level on every face of the podium: a driver sees the podium,
	-- not the tower. Glazed front, a stone band above it, windows up.
	for _, dir in { "N", "S", "E", "W" } do
		local pf = faceOf(dir, cx, cz, podium, podium)
		onFace(ctx, model, "Shopfront", pf, 0, 1.8, pf.width * 0.86, 3.2, 0.1, b.windowDark, Enum.Material.Glass, 0.05)
		onFace(ctx, model, "Band", pf, 0, 3.8, pf.width * 0.98, 0.6, 0.14, podiumColour:Lerp(Color3.new(0, 0, 0), 0.25), Enum.Material.Slate)
		windows(ctx, c, rng, model, pf, tw.podiumStoreys, true)
	end
	local _ = faceDir
	parapet(ctx, c, model, cx, cz, podium, podium, ph, podiumColour, false)
	local w = rng:NextNumber(tw.minWidthM, tw.maxWidthM)
	local d = rng:NextNumber(tw.minWidthM, tw.maxWidthM)
	local storeys = rng:NextInteger(tw.minStoreys, tw.maxStoreys)
	local h = storeys * b.storeyM
	local glass = tinted(tw.glassColor, rng, 0.12)
	local tx = cx + rng:NextNumber(-(podium - w) / 2 + 2, (podium - w) / 2 - 2)
	local tz = cz + rng:NextNumber(-(podium - d) / 2 + 2, (podium - d) / 2 - 2)
	local shaft = box(ctx, model, "Shaft", tx, ph + h / 2, tz, w, h, d, glass, Enum.Material.Glass, true, c.shadows.buildings)
	-- The curtain wall is a texture; the mullion and band parts it
	-- replaced were forty parts a tower.
	AssetRegistry.facade(shaft, "glass", rng, SIDE_FACES, ctx.s(b.storeyM * 3), glass:Lerp(Color3.new(1, 1, 1), 0.45), 0.05)
	local _ = faceDir
	local topY = ph + h
	if rng:NextNumber() < tw.setbackChance then
		local sw, sd, sh = w * 0.6, d * 0.6, b.storeyM * rng:NextInteger(3, 6)
		local setback = box(ctx, model, "Setback", tx, topY + sh / 2, tz, sw, sh, sd, glass, Enum.Material.Glass, false, c.shadows.buildings)
		AssetRegistry.facade(setback, "glass", rng, SIDE_FACES, ctx.s(b.storeyM * 3), glass:Lerp(Color3.new(1, 1, 1), 0.45), 0.05)
		topY += sh
	end
	-- A lit rim round the roof edge: four thin strips, not a slab. A
	-- Neon box the size of the roof was a lime lid on every tower from
	-- the gateway, because Neon blooms and a metre of it reads as three.
	local rim = 0.35
	for _, e in { { tx, tz + d / 2, w + rim, rim }, { tx, tz - d / 2, w + rim, rim }, { tx + w / 2, tz, rim, d + rim }, { tx - w / 2, tz, rim, d + rim } } do
		box(ctx, model, "Crown", e[1], topY - 0.25, e[2], e[3], 0.5, e[4], tw.crownColor, Enum.Material.Neon, false, false).Transparency = 0.5
	end
	box(ctx, model, "Plant", tx, topY + 1.5, tz, w * 0.3, 3, d * 0.3, Color3.fromRGB(120, 120, 116), Enum.Material.Metal, false, false)
end

local function towers(ctx: Context, c: CCfg, rng: Random, parent: Instance, p: Parcel)
	local tw = c.buildings.towers
	local r = p.rect
	local half = tw.podiumMaxM / 2 + 6
	type Spot = { x: number, z: number, dir: string }
	local spots: { Spot } = {
		{ x = r.minX + half, z = r.maxZ - half, dir = if p.north == "boulevard" then "N" else "W" },
		{ x = r.maxX - half, z = r.maxZ - half, dir = if p.north == "boulevard" then "N" else "E" },
		{ x = r.minX + half, z = r.minZ + half, dir = if p.south == "boulevard" then "S" else "W" },
		{ x = r.maxX - half, z = r.minZ + half, dir = if p.south == "boulevard" then "S" else "E" },
	}
	for i = 1, math.min(tw.count, #spots) do
		local s = spots[i]
		tower(ctx, c, rng, parent, s.x, s.z, s.dir)
	end
	-- Landscaped ground between: a paved plane a hair up.
	box(ctx, parent, "Piazza", (r.minX + r.maxX) / 2, 0.05, (r.minZ + r.maxZ) / 2, r.maxX - r.minX, 0.1, r.maxZ - r.minZ, tinted(c.surface.pavementColor, rng, 0.04), Enum.Material.Concrete, true, false)
end

local function plaza(ctx: Context, c: CCfg, rng: Random, parent: Instance, p: Parcel)
	local pz = c.buildings.plaza
	local r = p.rect
	local w, h = r.maxX - r.minX, r.maxZ - r.minZ
	local cx, cz = (r.minX + r.maxX) / 2, (r.minZ + r.maxZ) / 2
	box(ctx, parent, "Plaza", cx, -0.1, cz, w, 0.2, h, tinted(c.surface.asphaltColor, rng, 0.03), Enum.Material.Asphalt, true, false)
	local paint = c.surface.paintColor:Lerp(c.surface.asphaltColor, 0.45)
	local eps = c.surface.markingEpsilonM + c.surface.markingThicknessM / 2
	-- A few rows of bays across the middle, worn, with a tick every fourth
	-- bay: enough to say car park, sparse enough to leave the plaza flat
	-- and open. The first version ticked every bay of every row and the
	-- plaza read as a chessboard.
	local rows = 3
	local z = cz - (rows - 1) / 2 * pz.rowSpacingM
	for _ = 1, rows do
		for _, side in { -1, 1 } do
			box(ctx, parent, "BayLine", cx, eps, z + side * pz.bayLengthM, w * 0.6, c.surface.markingThicknessM, pz.bayLineWidthM, paint, Enum.Material.SmoothPlastic, false, false).Transparency = 0.3
		end
		local x = cx - w * 0.3
		while x < cx + w * 0.3 do
			box(ctx, parent, "BayTick", x, eps, z, pz.bayLineWidthM, c.surface.markingThicknessM, pz.bayLengthM * 2, paint, Enum.Material.SmoothPlastic, false, false).Transparency = 0.3
			x += pz.bayWidthM * 4
		end
		z += pz.rowSpacingM
	end
	local _ = h
end

function Buildings.build(ctx: Context, c: CCfg, plan: Streets.Plan, parent: Instance): Folder
	local folder = Build.folder("Buildings", parent)
	local rng = Build.rng(c.seed + 7)
	for _, p in plan.parcels do
		local holder = Build.folder(p.district, folder)
		if p.district == "commercial" then
			commercial(ctx, c, rng, holder, p)
		elseif p.district == "residential" then
			residential(ctx, c, rng, holder, p)
		elseif p.district == "towers" then
			towers(ctx, c, rng, holder, p)
		elseif p.district == "plaza" then
			-- All four plaza parcels are the open lot that is the meet spot.
			-- One used to be a mosque; the owner had it removed.
			plaza(ctx, c, rng, holder, p)
		end
		-- "lot": left as sand.
	end
	return folder
end

return Buildings
