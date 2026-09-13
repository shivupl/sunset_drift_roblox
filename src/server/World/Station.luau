--!strict
-- The petrol station beside the parking bay: a ring-road station of the
-- kind every Saudi highway has, and the first structure in the game.
--
-- Built from primitives, not a store kit. The free kits were either a
-- branded US or Russian station, 24 unions, or 268 parts with 12 meshes and
-- a brand's red and yellow: all of them over the triangle budget before a
-- single detail. A canopy is a slab, columns and a fascia; a shop is walls
-- and glass. Boxes are exactly that, at twelve triangles each.
--
-- No meshes at all, palms and parked cars included. The date-palm mesh the
-- highway uses measured up to about 1,500 triangles on its own, most of the
-- whole station's budget, and Roblox gives no reliable triangle count for
-- a mesh, so a site built only from parts is the only one whose cost is
-- known exactly: a box is 12 triangles, a wedge 8.
--
-- The detail that sells it costs no triangles at all where it can: lane
-- arrows, oil stains, tyre scuffs, drain grates and bay lines are Frames on
-- one SurfaceGui laid over the forecourt; the brand stripe and name on the
-- fascia, the pump screens and the shelves behind the glass are Frames and
-- text on the faces of parts that are already there. Geometry is spent on
-- silhouettes: the canopy edge, the columns, the pumps and their hoses, the
-- shop's pilasters, the rooftop plant.
--
-- Everything is generated from WorldConfig.station in a local frame (u
-- across the road, v along it, metres) so the whole site moves, turns and
-- scales from the config. Nothing collides except the ground surfaces the
-- car drives on, the shop's walls and glass, and the canopy columns, which
-- stand inside the pump islands so the lanes stay clear for a drift. The
-- canopy's warm strips are lamp heads to the client light manager, so they
-- draw from the same twelve live lights as every street lamp.
local CollectionService = game:GetService("CollectionService")

local WorldConfig = require(script.Parent.WorldConfig)
local Build = require(script.Parent.Build)
local RoadNetwork = require(script.Parent.RoadNetwork)
local WorldLighting = require(script.Parent.Lighting)

type Config = WorldConfig.Config
type Context = RoadNetwork.Context
type Path = RoadNetwork.Path

local Station = {}

-- Paint canvas resolution, pixels per stud. Enough for a 0.12 m line.
local PAINT_PPS = 4

local function tinted(colour: Color3, rng: Random, tone: number): Color3
	local t = rng:NextNumber(-tone, tone)
	return if t < 0 then colour:Lerp(Color3.new(0, 0, 0), -t) else colour:Lerp(Color3.new(1, 1, 1), t)
end

-- The station origin: on the ground beside the road at alongM, lateralM,
-- facing the direction of travel. Local +X is u, local -Z is v.
local function originFrame(cfg: Config, ctx: Context, path: Path): CFrame
	local st = cfg.station
	local p = RoadNetwork.sample(path, st.alongM)
	local pos = p.position + p.cframe.RightVector * ctx.s(st.lateralM)
	return CFrame.new(pos.X, ctx.surfaceY, pos.Z) * p.cframe.Rotation * CFrame.Angles(0, -math.rad(st.yawDeg), 0)
end

-- The outer edge of the drivable surface beside the station, in metres
-- from the centreline: the transition pad's wing if the station sits
-- beside it, the kerb otherwise.
local function roadEdgeM(cfg: Config, path: Path, ctx: Context): number
	local presets = cfg.presets :: any
	local preset = presets[cfg.preset]
	local pad = preset and preset.pad
	local st = cfg.station
	if pad and pad.widthM > 0 and st.alongM > pad.startM and st.alongM < pad.startM + pad.lengthM then
		return pad.widthM / 2
	end
	return RoadNetwork.layout(path, ctx).totalM / 2 + cfg.road.shoulderWidthM + cfg.road.kerbWidthM
end

-- Whole-site rectangle in the local frame (metres, scale 1), aprons, pylon
-- and palms included.
local function siteRect(cfg: Config, path: Path, ctx: Context): (number, number, number, number)
	local st = cfg.station
	local k = st.scale
	local fc = st.forecourt
	local u0 = math.min(fc.u0, (roadEdgeM(cfg, path, ctx) - st.lateralM) / k, st.pylon.u - 2)
	local u1, v0, v1 = fc.u1, math.min(fc.v0, st.pylon.v - 2), fc.v1
	for _, palm in st.palms do
		u0 = math.min(u0, palm[1] - 4)
		u1 = math.max(u1, palm[1] + 4)
		v0 = math.min(v0, palm[2] - 4)
		v1 = math.max(v1, palm[2] + 4)
	end
	return u0, u1, v0, v1
end

-- A test the scatter uses so nothing it plants lands on the site.
function Station.keepOut(cfg: Config, ctx: Context, path: Path): (pos: Vector3) -> boolean
	local st = cfg.station
	if not st.enabled then
		return function(_pos: Vector3): boolean
			return false
		end
	end
	local o = originFrame(cfg, ctx, path)
	local u0, u1, v0, v1 = siteRect(cfg, path, ctx)
	local m = st.keepOutMarginM
	local k = st.scale
	return function(pos: Vector3): boolean
		local l = o:PointToObjectSpace(pos)
		local u, v = l.X * ctx.mps / k, -l.Z * ctx.mps / k
		return u > u0 - m and u < u1 + m and v > v0 - m and v < v1 + m
	end
end

-- A SurfaceGui on one face of a part, lit like the surface it is on.
local function faceGui(part: BasePart, face: Enum.NormalId, pps: number, lit: boolean): SurfaceGui
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = pps
	gui.LightInfluence = if lit then 1 else 0
	gui.MaxDistance = 1200
	gui.Adornee = part
	gui.Parent = part
	return gui
end

local function rect(parent: Instance, x: number, y: number, w: number, h: number, colour: Color3, transparency: number?): Frame
	local f = Instance.new("Frame")
	f.BorderSizePixel = 0
	f.Position = UDim2.fromScale(x, y)
	f.Size = UDim2.fromScale(w, h)
	f.BackgroundColor3 = colour
	f.BackgroundTransparency = transparency or 0
	f.Parent = parent
	return f
end

local function label(parent: Instance, text: string, x: number, y: number, w: number, h: number, colour: Color3, font: Enum.Font): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Position = UDim2.fromScale(x, y)
	l.Size = UDim2.fromScale(w, h)
	l.Text = text
	l.TextScaled = true
	l.Font = font
	l.TextColor3 = colour
	l.Parent = parent
	return l
end

-- Clips the painted pad edge line where an apron crosses it, so the
-- entrance reads as an opening in the lot's edge.
local function openEdgeLine(road: Instance, centre: Vector3, across: Vector3, halfStuds: number)
	for _, d in road:GetDescendants() do
		if d.Name ~= "PadEdgeLine" or not d:IsA("BasePart") then
			continue
		end
		local p = d :: BasePart
		local rel = centre - p.Position
		if math.abs(rel:Dot(across)) > 12 then
			continue
		end
		local axis = p.CFrame.LookVector
		local half = p.Size.Z / 2
		local t0 = rel:Dot(axis)
		if t0 + halfStuds < -half or t0 - halfStuds > half then
			continue
		end
		local keep: { { number } } = {}
		if t0 - halfStuds > -half then
			table.insert(keep, { -half, t0 - halfStuds })
		end
		if t0 + halfStuds < half then
			table.insert(keep, { t0 + halfStuds, half })
		end
		local cf, size = p.CFrame, p.Size
		for i, piece in keep do
			local target = if i == 1 then p else p:Clone()
			target.Size = Vector3.new(size.X, size.Y, piece[2] - piece[1])
			target.CFrame = cf + axis * ((piece[1] + piece[2]) / 2)
			target.Parent = p.Parent
		end
		if #keep == 0 then
			p:Destroy()
		end
	end
end

function Station.build(cfg: Config, ctx: Context, path: Path, parent: Instance, road: Instance): Folder
	local st = cfg.station
	local C = st.colors
	local k = st.scale
	local rng = Build.rng(st.seed)
	local folder = Build.folder("Station", parent)
	local o = originFrame(cfg, ctx, path)
	local uDir, vDir = o.RightVector, o.LookVector

	local function S(m: number): number
		return ctx.s(m * k)
	end
	-- World CFrame at local (u, y, v), turned yawDeg to the right of +v.
	local function at(u: number, y: number, v: number, yawDeg: number?): CFrame
		return o * CFrame.new(S(u), S(y), -S(v)) * CFrame.Angles(0, -math.rad(yawDeg or 0), 0)
	end

	type BoxOpts = { yaw: number?, collide: boolean?, shadow: boolean?, transparency: number?, parent: Instance?, tilt: CFrame? }
	-- A box by its footprint centre (u, v), bottom height y0 and size in
	-- metres: su across, sy up, sv along.
	local function box(name: string, u: number, y0: number, v: number, su: number, sy: number, sv: number, colour: Color3, material: Enum.Material, opts: BoxOpts?): Part
		local op: BoxOpts = opts or {}
		local cf = at(u, y0 + sy / 2, v, op.yaw)
		if op.tilt then
			cf *= op.tilt
		end
		return Build.part({
			name = name,
			size = Vector3.new(S(su), S(sy), S(sv)),
			cframe = cf,
			color = colour,
			material = material,
			parent = op.parent or folder,
			collide = op.collide,
			query = op.collide,
			transparency = op.transparency,
			castShadow = op.shadow,
		})
	end

	------------------------------------------------------------------
	-- Ground: aprons from the pad's edge, the concrete forecourt.
	------------------------------------------------------------------
	local ground = Build.folder("Ground", folder)
	local fc = st.forecourt
	local uEdge = (roadEdgeM(cfg, path, ctx) - st.lateralM) / k
	local slabM = 0.3
	local w, F = st.apronWidthM, st.apronFlareM
	for _, va in { st.entryV, st.exitV } do
		local len = fc.u0 - uEdge
		-- Asphalt like the pad it leaves, 6 mm proud so the tops never
		-- z-fight where it meets the wing.
		box("Apron", uEdge + len / 2, 0.006 - slabM, va, len, slabM, w, C.apron, Enum.Material.Asphalt, { collide = true, parent = ground })
		-- Flares: flat triangles at the pad edge, so the mouth is wider than
		-- the drive and a car can swing in at speed.
		for _, side in { -1, 1 } do
			local corner = at(uEdge, 0.006 - slabM / 2, va + side * w / 2).Position
			local vAxis = if side < 0 then vDir else -vDir
			local centre = corner + uDir * (S(F) / 2) + vDir * (side * S(F) / 2)
			Build.wedge({
				name = "ApronFlare",
				size = Vector3.new(S(slabM), S(F), S(F)),
				cframe = CFrame.fromMatrix(centre, uDir:Cross(vAxis), uDir, vAxis),
				color = C.apron,
				material = Enum.Material.Asphalt,
				parent = ground,
				collide = true,
			})
		end
		openEdgeLine(road, at(uEdge, 0, va).Position, uDir, S(w / 2 + F + 0.5))
	end

	-- Concrete bays, each its own tone: a poured forecourt is never one
	-- colour. Tops a centimetre above the road, so the aprons step up to
	-- them by 6 mm.
	local na, nl = st.forecourtPanels.across, st.forecourtPanels.along
	local du, dv = (fc.u1 - fc.u0) / na, (fc.v1 - fc.v0) / nl
	for i = 0, na - 1 do
		for j = 0, nl - 1 do
			local pu, pv = fc.u0 + du * (i + 0.5), fc.v0 + dv * (j + 0.5)
			box("Forecourt", pu, 0.012 - slabM, pv, du, slabM, dv, tinted(C.concrete, rng, 0.05), Enum.Material.Concrete, { collide = true, parent = ground })
		end
	end

	-- One transparent sheet over the whole forecourt carries the paint and
	-- the dirt as Frames: no triangles, and it shades with the concrete.
	local fu, fv = (fc.u0 + fc.u1) / 2, (fc.v0 + fc.v1) / 2
	local hu, hv = (fc.u1 - fc.u0) / 2, (fc.v1 - fc.v0) / 2
	local sheet = box("ForecourtPaint", fu, 0.013, fv, fc.u1 - fc.u0, 0.02, fc.v1 - fc.v0, C.paint, Enum.Material.SmoothPlastic, { transparency = 1, parent = ground })
	local paint = faceGui(sheet, Enum.NormalId.Top, PAINT_PPS, true)
	-- On a Top face the canvas X runs along the part's -Z (here +v) and Y
	-- along +X (+u), from the (-X, +Z) corner.
	local function mark(u: number, v: number, lenM: number, widthM: number, dirU: number, dirV: number, colour: Color3, transparency: number, round: boolean?): Frame
		local f = Instance.new("Frame")
		f.BorderSizePixel = 0
		f.AnchorPoint = Vector2.new(0.5, 0.5)
		f.Position = UDim2.fromOffset(S(hv + (v - fv)) * PAINT_PPS, S(u - fu + hu) * PAINT_PPS)
		f.Size = UDim2.fromOffset(S(widthM) * PAINT_PPS, S(lenM) * PAINT_PPS)
		f.Rotation = math.deg(math.atan2(dirV, -dirU))
		f.BackgroundColor3 = colour
		f.BackgroundTransparency = transparency
		if round then
			local c = Instance.new("UICorner")
			c.CornerRadius = UDim.new(0.5, 0)
			c.Parent = f
		end
		f.Parent = paint
		return f
	end
	local function arrow(u: number, v: number, dirU: number, dirV: number)
		local len = 5.5
		local mag = math.sqrt(dirU * dirU + dirV * dirV)
		local du1, dv1 = dirU / mag, dirV / mag
		mark(u, v, len, 0.3, du1, dv1, C.paint, 0.15)
		local tipU, tipV = u + du1 * len / 2, v + dv1 * len / 2
		for _, side in { -1, 1 } do
			local a = math.rad(180 + side * 32)
			local au = du1 * math.cos(a) - dv1 * math.sin(a)
			local av = du1 * math.sin(a) + dv1 * math.cos(a)
			mark(tipU + au * 0.8, tipV + av * 0.8, 1.7, 0.3, au, av, C.paint, 0.15)
		end
	end
	local cn = st.canopy
	-- Lane arrows: in at the entry, down the lanes, out at the exit.
	arrow(-19, st.entryV + 8, 0.35, 1)
	arrow(-15, cn.v - cn.alongM / 2 - 7, 0, 1)
	arrow(-6, cn.v - cn.alongM / 2 - 7, 0, 1)
	arrow(-18, st.exitV - 6, -0.45, 1)
	-- Drain grates across the lanes at both canopy edges, and two covers.
	for _, gv in { cn.v - cn.alongM / 2 - 1.5, cn.v + cn.alongM / 2 + 1.5 } do
		mark(cn.u, gv, cn.acrossM + 2, 0.45, 1, 0, Color3.fromRGB(58, 58, 56), 0)
		mark(cn.u, gv, cn.acrossM + 2, 0.12, 1, 0, Color3.fromRGB(96, 94, 90), 0.2)
	end
	mark(8, 40, 1.1, 1.1, 1, 0, Color3.fromRGB(72, 70, 66), 0)
	mark(-20, -24, 1.1, 1.1, 1, 0, Color3.fromRGB(72, 70, 66), 0)
	-- Oil under every pump position, darker nearer the hose, and the
	-- general grime of the lanes under the canopy.
	mark(cn.u, cn.v, cn.alongM - 2, cn.acrossM - 2, 0, 1, C.stain, 0.88)
	for _, iu in st.islands.u do
		for _, side in { -1, 1 } do
			do
				local sv = cn.v + rng:NextNumber(-10, 10)
				local size = rng:NextNumber(0.8, 1.8)
				mark(iu + side * rng:NextNumber(1.8, 3.2), sv, size, size * rng:NextNumber(0.6, 1), 0, 1, C.stain, rng:NextNumber(0.55, 0.75), true)
			end
		end
	end
	-- Tyre scuffs where cars swing in and out, and a few hard stops.
	for _, sc in { { -21, st.entryV + 3, 9, 0.6, 1 }, { -17, st.exitV - 3, 10, -0.5, 1 }, { 4, -20, 6, 1, 0.4 }, { -9, -12, 4, 0, 1 } } do
		mark(sc[1], sc[2], sc[3], 0.28, sc[4], sc[5], Color3.fromRGB(30, 30, 30), 0.72)
	end

	------------------------------------------------------------------
	-- Canopy.
	------------------------------------------------------------------
	local canopy = Build.folder("Canopy", folder)
	local hA, hL = cn.acrossM / 2, cn.alongM / 2
	local clear = cn.clearanceM
	-- One slab: its underside is the soffit, and inside the fascia nobody
	-- ever sees its top, so there is no separate deck.
	box("Soffit", cn.u, clear, cn.v, cn.acrossM - 0.4, 0.9, cn.alongM - 0.4, C.soffit, Enum.Material.SmoothPlastic, { shadow = true, parent = canopy })
	-- Fascia: four bands hanging 0.2 m below the soffit so the edge has a
	-- lip; the brand stripe and name are paint on the outer faces.
	local fasciaY = clear - 0.2
	type Fascia = { name: string, u: number, v: number, su: number, sv: number, face: Enum.NormalId, long: boolean }
	local fascias: { Fascia } = {
		{ name = "FasciaRoad", u = cn.u - hA + 0.15, v = cn.v, su = 0.3, sv = cn.alongM, face = Enum.NormalId.Left, long = true },
		{ name = "FasciaBack", u = cn.u + hA - 0.15, v = cn.v, su = 0.3, sv = cn.alongM, face = Enum.NormalId.Right, long = true },
		{ name = "FasciaIn", u = cn.u, v = cn.v - hL + 0.15, su = cn.acrossM - 0.6, sv = 0.3, face = Enum.NormalId.Back, long = false },
		{ name = "FasciaOut", u = cn.u, v = cn.v + hL - 0.15, su = cn.acrossM - 0.6, sv = 0.3, face = Enum.NormalId.Front, long = false },
	}
	for _, fa in fascias do
		local part = box(fa.name, fa.u, fasciaY, fa.v, fa.su, cn.fasciaM, fa.sv, C.fascia, Enum.Material.SmoothPlastic, { shadow = true, parent = canopy })
		local gui = faceGui(part, fa.face, 12, true)
		rect(gui, 0, 0.68, 1, 0.32, C.brand)
		rect(gui, 0, 0.62, 1, 0.04, C.brandGold)
		-- The name centred on each face with the mark between the two
		-- scripts: a gold eight-point star, two turned squares.
		-- The short ends carry the Arabic alone; every glyph is two
		-- triangles and the long faces are the ones the road sees.
		if fa.long then
			label(gui, st.nameArabic, 0.27, 0.04, 0.2, 0.56, C.brand, Enum.Font.GothamBold)
			label(gui, st.nameEnglish, 0.53, 0.12, 0.2, 0.42, C.brand, Enum.Font.GothamBlack)
		else
			label(gui, st.nameArabic, 0.2, 0.04, 0.36, 0.56, C.brand, Enum.Font.GothamBold)
		end
		-- A warm LED line along the fascia's bottom edge, unlit by the sun
		-- so it holds its colour against a low sky and marks the canopy
		-- edge from the highway.
		local led = faceGui(part, fa.face, 12, false)
		rect(led, 0, 0.95, 1, 0.05, Color3.fromRGB(255, 214, 150))
		local aspect = part.Size.Y / math.max(part.Size.X, part.Size.Z)
		for _, turn in { 0, 45 } do
			local star = rect(gui, if fa.long then 0.5 else 0.66, 0.31, 0.36 * aspect, 0.36, C.brandGold)
			star.AnchorPoint = Vector2.new(0.5, 0.5)
			star.Rotation = turn
		end
	end
	-- Warm strips recessed in the soffit, one over each lane position.
	-- They are lamp heads to the light manager: whichever are nearest the
	-- camera get one of its SpotLights, the rest are glowing geometry.
	local lensRows = { cn.u - hA + 2.6, cn.u, cn.u + hA - 2.6 }
	for _, lu in lensRows do
		for _, lv in { cn.v - hL / 2, cn.v + hL / 2 } do
			local lens = box("CanopyLight", lu, clear - 0.06, lv, 0.5, 0.06, 9, C.light, Enum.Material.Neon, { transparency = 0.1, parent = canopy })
			CollectionService:AddTag(lens, WorldLighting.LAMP_TAG)
		end
	end
	-- Columns near the ends of each island, the only thing under the canopy
	-- that collides: one slim steel shaft each, guarded by the bumpers.
	for _, iu in st.islands.u do
		for _, side in { -1, 1 } do
			local cv = cn.v + side * cn.columnInsetV
			box("Column", iu, 0, cv, cn.columnM, clear, cn.columnM, C.column, Enum.Material.Metal, { collide = true, shadow = true, parent = canopy })
		end
	end

	------------------------------------------------------------------
	-- Islands and pumps.
	------------------------------------------------------------------
	local pumps = Build.folder("Pumps", folder)
	local isl = st.islands
	local perIsland = math.ceil(math.clamp(st.pumpCount, 4, 6) / 2)
	local placed = 0
	for ii, iu in isl.u do
		box("Island", iu, 0, cn.v, isl.widthM, isl.heightM, isl.lengthM, tinted(C.kerb, rng, 0.03), Enum.Material.Concrete, { parent = pumps })
		for _, side in { -1, 1 } do
			-- Striped crash bumper on each end.
			local bump = box("IslandBumper", iu, isl.heightM, cn.v + side * (isl.lengthM / 2 - 0.35), isl.widthM - 0.2, 0.9, 0.5, C.bumper, Enum.Material.SmoothPlastic, { parent = pumps })
			local g = faceGui(bump, if side < 0 then Enum.NormalId.Back else Enum.NormalId.Front, 20, true)
			for s = 0, 1 do
				rect(g, 0, s * 0.5 + 0.18, 1, 0.16, Color3.fromRGB(28, 28, 28))
			end
		end
		local spacing = (isl.lengthM - 2 * (isl.lengthM / 2 - cn.columnInsetV) - 2) / perIsland
		for pi = 1, perIsland do
			placed += 1
			if placed > st.pumpCount then
				break
			end
			local pv = cn.v - cn.columnInsetV + 1 + spacing * (pi - 0.5)
			local y = isl.heightM
			-- No shadows: under the canopy there is no sun to cast them.
			local body = box("Pump", iu, y, pv, 0.6, 1.85, 1.15, tinted(C.pumpBody, rng, 0.02), Enum.Material.SmoothPlastic, { parent = pumps })
			local header = box("PumpHeader", iu, y + 1.85, pv, 0.7, 0.38, 1.3, C.brand, Enum.Material.SmoothPlastic, { parent = pumps })
			for _, face in { Enum.NormalId.Left, Enum.NormalId.Right } do
				local g = faceGui(body, face, 40, true)
				rect(g, 0.12, 0.1, 0.76, 0.2, Color3.fromRGB(40, 92, 80)) -- the screen, glowing green
				rect(g, 0, 0.36, 1, 0.05, C.brand)
				label(g, if (ii + pi) % 2 == 0 then "91" else "95", 0.3, 0.46, 0.4, 0.16, C.brand, Enum.Font.GothamBlack)
				local hg = faceGui(header, face, 40, true)
				rect(hg, 0, 0.8, 1, 0.08, C.brandGold)
			end
			-- One hose, hanging from the top of the body on alternate sides down
			-- the island, so every lane has a hose beside it. A second hose and
			-- a nozzle part cost 216 triangles across six pumps and neither
			-- read from the lane.
			local side = if pi % 2 == 0 then 1 else -1
			box("Hose", iu + side * 0.38, y + 0.55, pv + 0.25, 0.07, 1.25, 0.07, Color3.fromRGB(26, 26, 28), Enum.Material.Rubber, { parent = pumps, tilt = CFrame.Angles(math.rad(12), 0, math.rad(side * 10)) })
		end
	end

	------------------------------------------------------------------
	-- Shop.
	------------------------------------------------------------------
	local shop = Build.folder("Shop", folder)
	local sh = st.shop
	local su0, su1 = sh.u - sh.depthM / 2, sh.u + sh.depthM / 2
	local sv0, sv1 = sh.v - sh.lengthM / 2, sh.v + sh.lengthM / 2
	local wallH = sh.heightM + sh.parapetM
	local t = 0.3
	local sandstone = function(): Color3
		return tinted(C.sandstone, rng, 0.035)
	end
	local walled: BoxOpts = { collide = true, shadow = true, parent = shop }
	box("ShopBack", su1 - t / 2, 0, sh.v, t, wallH, sh.lengthM, sandstone(), Enum.Material.Sandstone, walled)
	for _, side in { -1, 1 } do
		box("ShopSide", sh.u, 0, sh.v + side * (sh.lengthM / 2 - t / 2), sh.depthM, wallH, t, sandstone(), Enum.Material.Sandstone, walled)
	end
	-- Front, road side: pilaster, glass, pilaster, door, pilaster, glass,
	-- pilaster, under a deep lintel that carries the sign.
	local lintelY = 3.1
	local front = su0 + t / 2
	local spanNames = { "Pilaster", "Glass", "Pilaster", "Door", "Pilaster", "Glass", "Pilaster" }
	local spanWidths = { 1.2, 0, 0.8, 3.2, 0.8, 0, 1.2 }
	local fixed = 1.2 + 0.8 + 3.2 + 0.8 + 1.2
	local glassW = (sh.lengthM - fixed) / 2
	local cursor = sv0
	for si, name in spanNames do
		local width = spanWidths[si]
		if width == 0 then
			width = glassW
		end
		local cv = cursor + width / 2
		if name == "Pilaster" then
			box("Pilaster", front - 0.1, 0, cv, t + 0.2, lintelY, width, sandstone(), Enum.Material.Sandstone, walled)
		elseif name == "Glass" then
			box("Glazing", front, 0.16, cv, 0.08, lintelY - 0.16, width, C.glass, Enum.Material.Glass, { collide = true, transparency = 0.6, parent = shop })
		else
			box("Door", front, 0.16, cv, 0.1, 2.5, width, C.glass:Lerp(Color3.new(0, 0, 0), 0.2), Enum.Material.Glass, { collide = true, transparency = 0.25, parent = shop })
		end
		cursor += width
	end
	local lintel = box("Lintel", front - 0.1, lintelY, sh.v, t + 0.2, wallH - lintelY, sh.lengthM, tinted(C.sandstoneDark, rng, 0.02), Enum.Material.Sandstone, walled)
	local lg = faceGui(lintel, Enum.NormalId.Left, 10, true)
	rect(lg, 0.3, 0.2, 0.4, 0.62, C.brand)
	rect(lg, 0.3, 0.8, 0.4, 0.04, C.brandGold)
	label(lg, st.shopArabic, 0.32, 0.24, 0.17, 0.52, Color3.new(1, 1, 1), Enum.Font.GothamBold)
	label(lg, st.shopEnglish, 0.51, 0.3, 0.17, 0.4, Color3.new(1, 1, 1), Enum.Font.GothamBlack)
	box("ShopRoof", sh.u, sh.heightM - 0.3, sh.v, sh.depthM - 2 * t, 0.3, sh.lengthM - 2 * t, tinted(C.sandstone, rng, 0.02), Enum.Material.Concrete, { parent = shop })
	box("Awning", front - 1.2, lintelY - 0.05, sh.v, 2.4, 0.22, 6, C.brand, Enum.Material.SmoothPlastic, { shadow = true, parent = shop })
	-- Behind the glass: a lit back wall and two shelf runs with stock on
	-- their faces. Nothing you can walk into.
	local inside: BoxOpts = { parent = shop }
	box("Interior", su1 - t - 0.06, 0.16, sh.v, 0.1, sh.heightM - 0.5, sh.lengthM - 1.2, C.interior, Enum.Material.SmoothPlastic, inside)
	for _, side in { -1, 1 } do
		local shelf = box("Shelf", sh.u + 1.2, 0.16, sh.v + side * 7, 1.0, 1.7, 7.5, Color3.fromRGB(220, 220, 214), Enum.Material.Metal, inside)
		local g = faceGui(shelf, Enum.NormalId.Left, 16, true)
		local stock = { Color3.fromRGB(200, 60, 50), Color3.fromRGB(40, 110, 190), Color3.fromRGB(240, 190, 40), Color3.fromRGB(60, 150, 80), Color3.fromRGB(230, 230, 230) }
		for row = 0, 2 do
			for col = 0, 3 do
				rect(g, col / 4 + 0.01, row * 0.33 + 0.05, 1 / 4 - 0.02, 0.22, stock[rng:NextInteger(1, #stock)])
			end
		end
	end
	-- Roof plant, above the parapet line so it shows from the road.
	for _, pv in { sh.v - 6, sh.v + 5 } do
		local unit = box("RoofUnit", sh.u + 1.5, sh.heightM, pv, 1.8, 1.4, 2.4, Color3.fromRGB(206, 206, 200), Enum.Material.Metal, { shadow = true, parent = shop })
		local g = faceGui(unit, Enum.NormalId.Top, 20, true)
		for _, cy in { 0.28, 0.72 } do
			local fan = rect(g, 0.2, cy - 0.17, 0.6, 0.34, Color3.fromRGB(50, 52, 54))
			local c = Instance.new("UICorner")
			c.CornerRadius = UDim.new(0.5, 0)
			c.Parent = fan
		end
	end
	-- A square fibreglass water tank: a cylinder part costs about nine boxes.
	box("WaterTank", sh.u + 3, sh.heightM, sh.v + 10.5, 1.6, 1.9, 1.6, Color3.fromRGB(226, 220, 204), Enum.Material.SmoothPlastic, { shadow = true, parent = shop })

	------------------------------------------------------------------
	-- Detail: bollards, bins, the air post, the price pylon, parked cars,
	-- palms. None of it collides.
	------------------------------------------------------------------
	local detail = Build.folder("Detail", folder)
	local dopts: BoxOpts = { parent = detail }
	-- Either side of the door, where a car nosing in would hit the glass.
	for _, side in { -1, 1 } do
		box("Bollard", su0 - 1.4, 0, sh.v + side * 2.2, 0.26, 0.95, 0.26, Color3.fromRGB(70, 72, 74), Enum.Material.Metal, dopts)
	end
	-- On the island between a column and the first pump, where they stand.
	box("Bin", st.islands.u[1], st.islands.heightM, cn.v - cn.columnInsetV + 1.2, 0.55, 0.95, 0.55, C.brand, Enum.Material.Metal, dopts)
	-- Air and water: one post, its head painted on.
	local airPost = box("AirPost", su0 + 1, 0, sv1 + 3, 0.45, 1.6, 0.4, Color3.fromRGB(230, 228, 222), Enum.Material.Metal, dopts)
	local ag = faceGui(airPost, Enum.NormalId.Left, 60, true)
	rect(ag, 0, 0.42, 1, 0.58, C.brand)
	label(ag, "هواء  AIR", 0.05, 0.03, 0.9, 0.16, C.brand, Enum.Font.GothamBold)
	label(ag, "ماء  WATER", 0.05, 0.2, 0.9, 0.14, C.brand, Enum.Font.GothamBold)

	-- Price pylon at the entrance, turned toward oncoming traffic.
	local py = st.pylon
	local pyaw = 180 + py.yawTowardRoadDeg
	box("PylonBase", py.u, 0, py.v, py.widthM + 0.4, 0.9, 1.2, tinted(C.sandstoneDark, rng, 0.02), Enum.Material.Sandstone, { yaw = pyaw, shadow = true, parent = detail })
	local panel = box("PylonPanel", py.u, 0.9, py.v, py.widthM, py.heightM - 0.9, 0.6, C.fascia, Enum.Material.SmoothPlastic, { yaw = pyaw, shadow = true, parent = detail })
	-- Printed on the face toward oncoming traffic only.
	do
		local g = faceGui(panel, Enum.NormalId.Front, 16, true)
		rect(g, 0, 0, 1, 0.24, C.brand)
		rect(g, 0, 0.24, 1, 0.015, C.brandGold)
		label(g, st.nameArabic, 0.08, 0.02, 0.84, 0.12, Color3.new(1, 1, 1), Enum.Font.GothamBold)
		label(g, st.nameEnglish, 0.08, 0.14, 0.84, 0.07, C.brandGold, Enum.Font.GothamBlack)
		for i, pr in st.prices do
			local y0 = 0.3 + (i - 1) * 0.2
			rect(g, 0.06, y0, 0.88, 0.16, Color3.fromRGB(30, 32, 34))
			label(g, pr[1], 0.08, y0 + 0.03, 0.4, 0.1, Color3.new(1, 1, 1), Enum.Font.GothamBold)
			label(g, pr[2], 0.52, y0 + 0.01, 0.4, 0.14, Color3.fromRGB(255, 196, 70), Enum.Font.Code)
		end
	end

	-- Parked cars nose-in at the shop front, in painted bays.
	local bayU = su0 - 4.2
	for i = 0, 3 do
		mark(bayU, sv0 + 4 + i * 3, 5.2, 0.14, 1, 0, C.paint, 0.2)
	end
	-- Two parked cars, built from parts: a body, a glasshouse, wedge
	-- screens front and back, four wheels. Windows and lamps are paint.
	local carColours = { Color3.fromRGB(236, 236, 232), Color3.fromRGB(28, 28, 30), Color3.fromRGB(170, 172, 176), Color3.fromRGB(120, 18, 24) }
	local glassC = Color3.fromRGB(28, 34, 40)
	for c = 0, st.parkedCars - 1 do
		local cv = sv0 + 5.5 + c * 6
		-- Nose toward the shop: the car's own forward is +u here.
		local colour = carColours[rng:NextInteger(1, #carColours)]
		local function carBox(name: string, fwd: number, y0: number, lenM: number, h: number, widthM: number, col: Color3, mat: Enum.Material): Part
			return box(name, bayU + fwd, y0, cv, lenM, h, widthM, col, mat, { parent = detail })
		end
		local body = carBox("CarBody", 0, 0.28, 4.6, 0.72, 1.82, colour, Enum.Material.SmoothPlastic)
		for _, face in { Enum.NormalId.Right, Enum.NormalId.Left } do
			-- Right is the nose (+u), Left the tail.
			local g = faceGui(body, face, 30, true)
			local lamp = if face == Enum.NormalId.Right then Color3.fromRGB(235, 235, 220) else Color3.fromRGB(170, 20, 20)
			rect(g, 0.06, 0.2, 0.2, 0.22, lamp)
			rect(g, 0.74, 0.2, 0.2, 0.22, lamp)
		end
		local cabin = carBox("CarCabin", -0.35, 1.0, 1.9, 0.58, 1.6, glassC, Enum.Material.Glass)
		carBox("CarRoof", -0.35, 1.58, 1.9, 0.06, 1.6, colour, Enum.Material.SmoothPlastic)
		for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
			local g = faceGui(cabin, face, 30, true)
			rect(g, 0.47, 0, 0.06, 1, colour) -- the B pillar
		end
		-- Screens: a wedge's tall face is at its local +Z, so each one faces
		-- +Z at the cabin: the windscreen turned to look along +u, the rear
		-- screen along -u.
		for _, e in { { 0.95, 90 }, { -1.65, -90 } } do
			Build.wedge({
				name = "CarScreen",
				size = Vector3.new(S(1.6), S(0.58), S(0.7)),
				cframe = at(bayU + e[1], 1.0 + 0.29, cv, e[2]),
				color = glassC,
				material = Enum.Material.Glass,
				parent = detail,
			})
		end
		for _, wpos in { { 1.45, -0.86 }, { 1.45, 0.86 }, { -1.45, -0.86 }, { -1.45, 0.86 } } do
			box("CarWheel", bayU + wpos[1], 0, cv + wpos[2], 0.66, 0.66, 0.24, Color3.fromRGB(24, 24, 26), Enum.Material.Rubber, { parent = detail })
		end
	end

	-- Date palms at the edges of the site, from parts: a two-piece trunk
	-- that narrows and leans, and two tiers of flat triangular fronds
	-- (wedges laid on their sides), a lower ring arching out and drooping
	-- and a smaller upper ring standing up. 96 triangles a tree.
	local frondC = Color3.fromRGB(78, 98, 52)
	local trunkC = Color3.fromRGB(118, 98, 78)
	for _, pl in st.palms do
		local height = rng:NextNumber(7.5, 9.5)
		local leanX, leanZ = math.rad(rng:NextNumber(-5, 5)), math.rad(rng:NextNumber(-5, 5))
		local lower = height * 0.55
		local base = at(pl[1], 0, pl[2]) * CFrame.Angles(leanX, 0, leanZ)
		Build.part({ name = "PalmTrunk", size = Vector3.new(S(0.62), S(lower), S(0.62)), cframe = base * CFrame.new(0, S(lower / 2), 0), color = trunkC, material = Enum.Material.Wood, parent = detail, castShadow = cfg.shadows.palms })
		local upperBase = base * CFrame.new(0, S(lower), 0) * CFrame.Angles(leanX * 0.8, 0, leanZ * 0.8)
		Build.part({ name = "PalmTrunk", size = Vector3.new(S(0.48), S(height - lower), S(0.48)), cframe = upperBase * CFrame.new(0, S((height - lower) / 2), 0), color = trunkC:Lerp(Color3.new(1, 1, 1), 0.06), material = Enum.Material.Wood, parent = detail, castShadow = cfg.shadows.palms })
		local top = (upperBase * CFrame.new(0, S(height - lower), 0)).Position
		local turn = rng:NextNumber(0, math.pi * 2)
		type Tier = { count: number, pitch0: number, pitch1: number, len0: number, len1: number, width: number }
		local tiers: { Tier } = {
			{ count = 6, pitch0 = 28, pitch1 = 55, len0 = 3.8, len1 = 4.8, width = 1.4 },
			{ count = 3, pitch0 = -35, pitch1 = -10, len0 = 2.6, len1 = 3.2, width = 0.9 },
		}
		for ti, tier in tiers do
			for f = 1, tier.count do
				local a = turn + (f + ti * 0.5) / tier.count * math.pi * 2 + rng:NextNumber(-0.15, 0.15)
				local pitch = math.rad(rng:NextNumber(tier.pitch0, tier.pitch1))
				local len = S(rng:NextNumber(tier.len0, tier.len1))
				local d = Vector3.new(math.cos(a) * math.cos(pitch), -math.sin(pitch), math.sin(a) * math.cos(pitch))
				local wAxis = Vector3.new(-math.sin(a), 0, math.cos(a))
				local zAxis = -d -- the wedge's full end at the trunk, its point at the tip
				local xAxis = wAxis:Cross(zAxis)
				Build.wedge({
					name = "PalmFrond",
					size = Vector3.new(S(0.05), S(tier.width), len),
					cframe = CFrame.fromMatrix(top + d * (len / 2) - wAxis * S(tier.width) * 0.25, xAxis, wAxis, zAxis),
					color = tinted(frondC, rng, 0.1),
					material = Enum.Material.Grass,
					parent = detail,
					castShadow = cfg.shadows.palms,
				})
			end
		end
	end

	return folder
end

return Station
