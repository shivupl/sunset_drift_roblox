--!strict
-- The garage: a two-bay workshop on the transition pad's left wing, across
-- the highway from the spawn bay, with its doors facing the road. A player
-- walks in through the open door and the customisation view takes over
-- (the client's GarageView); the car stands on the turntable in the
-- display bay. Asked by the owner on 2026-09-28; the look and the reasons
-- are in docs/superpowers/specs/2026-09-28-garage-design.md section 1.
--
-- Built from primitives like the station, for the same reason: a box's
-- cost is known exactly (12 triangles), a mesh's is not. Detail that can
-- be paint is paint: the floor's saw cuts, tyre marks and oil stains, the
-- apron's bay lines, hatch and lettering, the shutter's slats, the roof
-- edge's ribs, the drawer fronts and the sign are Frames and text on
-- SurfaceGuis on faces that exist anyway (two triangles each, no image
-- assets). Geometry goes on what has a silhouette: the lift, the benches,
-- the shelving, the tyres, the tools on the boards.
--
-- Everything comes from WorldConfig.garage in a local frame (metres from
-- the building's centre on the ground): u along the front, + to your right
-- as you face the doors; v into the building; y up. Walls, the closed
-- shutter, the columns, the floor and the turntable collide; the dressing
-- does not (the world's rule). The strip lights' lenses are lamp heads to
-- the client light pool; the garage makes no Light instances.
--
-- Contract with the client (GarageView), found by name directly under the
-- Garage folder, which carries the attribute GarageRoot = true:
--   Turntable    the steel plate (GarageRole = "turntable"); its top centre
--                is where the preview car stands. ViewFrame attribute: that
--                point, looking into the garage.
--   DoorZone     invisible threshold box across the open door; LookVector
--                points into the garage.
--   ExitSpot     invisible, outM outside the door, facing out, its centre
--                at a character's root height.
--   LiftCarSpot  invisible; the raised car's tyre-bottom centre, nose to
--                the back wall.
--   Backdrop     the flat grey wall behind the turntable.
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local WorldConfig = require(script.Parent.WorldConfig)
local Build = require(script.Parent.Build)
local RoadNetwork = require(script.Parent.RoadNetwork)
local WorldLighting = require(script.Parent.Lighting)
local UITheme = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("UITheme"))

type Config = WorldConfig.Config
type Context = RoadNetwork.Context
type Path = RoadNetwork.Path
type Prop = WorldConfig.GarageProp

local Garage = {}

local function tinted(colour: Color3, rng: Random, tone: number): Color3
	local t = rng:NextNumber(-tone, tone)
	return if t < 0 then colour:Lerp(Color3.new(0, 0, 0), -t) else colour:Lerp(Color3.new(1, 1, 1), t)
end

-- The building frame: on the ground at the building's centre, looking into
-- it (away from the road). Right is +u, look is +v.
local function originFrame(cfg: Config, ctx: Context, path: Path): CFrame
	local g = cfg.garage
	local p = RoadNetwork.sample(path, g.alongM)
	local pos = p.position + p.cframe.RightVector * ctx.s(g.lateralM)
	-- The doors face yawDeg right of the direction of travel; the frame
	-- looks the other way, into the building.
	return CFrame.new(pos.X, ctx.surfaceY, pos.Z) * p.cframe.Rotation * CFrame.Angles(0, math.pi - math.rad(g.yawDeg), 0)
end

-- The scatter asks thousands of times, and sampling the path is a scan.
-- Cleared by every build, so a rebuild that moves or turns the garage
-- never answers from the old frame.
local frames: { [Path]: CFrame } = setmetatable({}, { __mode = "k" }) :: any
local function frameFor(cfg: Config, ctx: Context, path: Path): CFrame
	local o = frames[path]
	if not o then
		o = originFrame(cfg, ctx, path)
		frames[path] = o
	end
	return o
end

-- The site rectangle in the local frame: the building with its roof
-- overhang, and the apron out to the painted lettering.
local function siteRect(cfg: Config): (number, number, number, number)
	local g = cfg.garage
	local hw = g.widthM / 2 + g.roof.overhangM
	local front = math.min(g.apron.textV, g.apron.arrowV, -g.depthM / 2 - g.doorApronM - g.apron.bayDepthM) - 3
	return -hw, hw, front, g.depthM / 2 + g.roof.overhangM
end

-- True where p (a world position) is on the garage's site or within
-- marginM metres of it (keepOutMarginM when nil). Scatter and dune life
-- ask this so nothing is planted on the building or its apron.
function Garage.keepOut(cfg: Config, ctx: Context, path: Path, p: Vector3, marginM: number?): boolean
	local g = cfg.garage
	if not g.enabled then
		return false
	end
	local l = frameFor(cfg, ctx, path):PointToObjectSpace(p)
	local u, v = l.X * ctx.mps, -l.Z * ctx.mps
	local u0, u1, v0, v1 = siteRect(cfg)
	local m = marginM or g.keepOutMarginM
	return u > u0 - m and u < u1 + m and v > v0 - m and v < v1 + m
end

-- A SurfaceGui on one face of a part. lit = 1 shades with the surface;
-- lower values make it glow a little (the sign).
local function faceGui(part: BasePart, face: Enum.NormalId, pps: number, lightInfluence: number): SurfaceGui
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = pps
	gui.LightInfluence = lightInfluence
	gui.MaxDistance = 600
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

local function label(parent: Instance, text: string, x: number, y: number, w: number, h: number, colour: Color3, xAlign: Enum.TextXAlignment?): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Position = UDim2.fromScale(x, y)
	l.Size = UDim2.fromScale(w, h)
	l.Text = text
	l.TextScaled = true
	l.FontFace = UITheme.font("display")
	l.TextColor3 = colour
	l.TextXAlignment = xAlign or Enum.TextXAlignment.Center
	l.Parent = parent
	return l
end

-- A filled disc, size a fraction of the canvas's shorter side; rings are
-- discs stacked on discs. Opaque parts only (BEHAVIOURS.md, section 4).
local function disc(parent: Instance, x: number, y: number, size: number, colour: Color3)
	local f = Instance.new("Frame")
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.Position = UDim2.fromScale(x, y)
	f.Size = UDim2.fromScale(size, size)
	f.BorderSizePixel = 0
	f.BackgroundColor3 = colour
	f.Parent = parent
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0.5, 0)
	c.Parent = f
	local a = Instance.new("UIAspectRatioConstraint")
	a.Parent = f
end

function Garage.build(cfg: Config, ctx: Context, path: Path, parent: Instance): Folder
	local g = cfg.garage
	local C = g.colors
	table.clear(frames)
	local rng = Build.rng(g.seed)
	local folder = Build.folder("Garage", parent)
	folder:SetAttribute("GarageRoot", true)
	local o = originFrame(cfg, ctx, path)
	local S = ctx.s
	local hw, hd = g.widthM / 2, g.depthM / 2
	local H, t = g.eavesM, g.wallM
	local door = g.door
	local lamps = 0

	-- Parts go into whichever section folder is current.
	local current: Instance = folder
	local function section(name: string)
		current = Build.folder(name, folder)
	end

	-- World CFrame at (x, y, z) metres in a frame, z along its look (for the
	-- building frame: u, y, v), turned yawDeg to the right.
	local function place(frame: CFrame, x: number, y: number, z: number, yawDeg: number?): CFrame
		return frame * CFrame.new(S(x), S(y), -S(z)) * CFrame.Angles(0, -math.rad(yawDeg or 0), 0)
	end

	type Opts = { collide: boolean?, shadow: boolean?, transparency: number?, tilt: CFrame? }
	-- A box in a frame by its footprint centre (x, z), bottom y0 and size
	-- sx across, sy up, sz along the frame's look.
	local function boxIn(frame: CFrame, name: string, x: number, y0: number, z: number, sx: number, sy: number, sz: number, colour: Color3, material: Enum.Material, opts: Opts?): Part
		local op: Opts = opts or {}
		local cf = place(frame, x, y0 + sy / 2, z)
		if op.tilt then
			cf *= op.tilt
		end
		return Build.part({
			name = name,
			size = Vector3.new(S(sx), S(sy), S(sz)),
			cframe = cf,
			color = colour,
			material = material,
			parent = current,
			collide = op.collide,
			query = op.collide,
			transparency = op.transparency,
			castShadow = op.shadow,
		})
	end
	local function box(name: string, u: number, y0: number, v: number, su: number, sy: number, sv: number, colour: Color3, material: Enum.Material, opts: Opts?): Part
		return boxIn(o, name, u, y0, v, su, sy, sv, colour, material, opts)
	end
	-- A cylinder by its centre, diameter and length along the frame's x, y
	-- or z axis.
	local function cylIn(frame: CFrame, name: string, x: number, y: number, z: number, diameter: number, length: number, axis: string, colour: Color3, material: Enum.Material, opts: Opts?): Part
		local op: Opts = opts or {}
		local cf = place(frame, x, y, z)
		if axis == "y" then
			cf *= CFrame.Angles(0, 0, math.pi / 2)
		elseif axis == "z" then
			cf *= CFrame.Angles(0, math.pi / 2, 0)
		end
		local p = Build.part({
			name = name,
			size = Vector3.new(S(length), S(diameter), S(diameter)),
			cframe = cf,
			color = colour,
			material = material,
			parent = current,
			collide = op.collide,
			query = op.collide,
			castShadow = op.shadow,
		})
		p.Shape = Enum.PartType.Cylinder
		return p
	end
	-- A square rod between two points of a frame.
	local function rodIn(frame: CFrame, name: string, a: Vector3, b: Vector3, width: number, colour: Color3, material: Enum.Material): Part
		local p0 = place(frame, a.X, a.Y, a.Z).Position
		local p1 = place(frame, b.X, b.Y, b.Z).Position
		return Build.part({
			name = name,
			size = Vector3.new(S(width), S(width), (p1 - p0).Magnitude),
			cframe = CFrame.lookAt((p0 + p1) / 2, p1),
			color = colour,
			material = material,
			parent = current,
		})
	end

	-- Paint on the top of a part laid square to the building frame, centred
	-- at (uc, vc) and su x sv metres. On a Top face the canvas X runs along
	-- +v from the front edge and Y along +u from the left edge.
	type Painter = {
		gui: SurfaceGui,
		mark: (u: number, v: number, lenM: number, widthM: number, dirU: number, dirV: number, colour: Color3, transparency: number, round: boolean?) -> Frame,
		text: (text: string, u: number, v: number, widthM: number, heightM: number, colour: Color3, transparency: number) -> TextLabel,
	}
	local function painter(part: BasePart, uc: number, vc: number, su: number, sv: number, pps: number, glow: number?, base: Color3?): Painter
		local gui = faceGui(part, Enum.NormalId.Top, pps, glow or 1)
		if base then
			rect(gui, 0, 0, 1, 1, base)
		end
		local function px(m: number): number
			return S(m) * pps
		end
		local function mark(u: number, v: number, lenM: number, widthM: number, dirU: number, dirV: number, colour: Color3, transparency: number, round: boolean?): Frame
			local f = Instance.new("Frame")
			f.BorderSizePixel = 0
			f.AnchorPoint = Vector2.new(0.5, 0.5)
			f.Position = UDim2.fromOffset(px(v - vc + sv / 2), px(u - uc + su / 2))
			f.Size = UDim2.fromOffset(px(widthM), px(lenM))
			f.Rotation = math.deg(math.atan2(-dirV, dirU))
			f.BackgroundColor3 = colour
			f.BackgroundTransparency = transparency
			if round then
				local c = Instance.new("UICorner")
				c.CornerRadius = UDim.new(0.5, 0)
				c.Parent = f
			end
			f.Parent = gui
			return f
		end
		-- Lettering that reads left to right for someone facing the doors
		-- (along +u, tops of the letters toward the building).
		local function text(s: string, u: number, v: number, widthM: number, heightM: number, colour: Color3, transparency: number): TextLabel
			local l = Instance.new("TextLabel")
			l.BackgroundTransparency = 1
			l.AnchorPoint = Vector2.new(0.5, 0.5)
			l.Position = UDim2.fromOffset(px(v - vc + sv / 2), px(u - uc + su / 2))
			l.Size = UDim2.fromOffset(px(widthM), px(heightM))
			l.Rotation = 90
			l.Text = s
			l.TextScaled = true
			l.FontFace = UITheme.font("display")
			l.TextColor3 = colour
			l.TextTransparency = transparency
			l.Parent = gui
			return l
		end
		return { gui = gui, mark = mark, text = text }
	end

	------------------------------------------------------------------
	-- Floor: sealed concrete, its saw cuts, tyre marks and oil.
	------------------------------------------------------------------
	section("Floor")
	local fl = g.floor
	local floorPart = box("Floor", 0, fl.topM - fl.thicknessM, 0, g.widthM, fl.thicknessM, g.depthM, C.floor, Enum.Material.Concrete, { collide = true })
	-- The concrete strip outside the doors, between the floor and the pad.
	box("DoorApron", 0, 0.015 - fl.thicknessM, -hd - g.doorApronM / 2, g.widthM, fl.thicknessM, g.doorApronM, C.doorApron, Enum.Material.Concrete, { collide = true })
	-- The floor carries its lit tone as paint (see bakedLight in the config).
	local bl = g.bakedLight
	local floorPaint = painter(floorPart, 0, 0, g.widthM, g.depthM, 8, bl.floor, C.floor)
	local jointC = C.joint
	do
		local u = -hw + fl.jointM
		while u < hw - 0.5 do
			floorPaint.mark(u, 0, g.depthM, 0.05, 0, 1, jointC, 0.35)
			u += fl.jointM
		end
		local v = -hd + fl.jointM
		while v < hd - 0.5 do
			floorPaint.mark(0, v, g.widthM, 0.05, 1, 0, jointC, 0.35)
			v += fl.jointM
		end
	end
	-- Tyre marks: arcs of short straight pieces sweeping in from each door
	-- and curling one way or the other.
	local tm = g.tyreMarks
	for i = 1, tm.count do
		local bayU = if i % 2 == 1 then g.liftU else g.displayU
		local u, v = bayU + rng:NextNumber(-1.6, 1.6), -hd + 0.3
		local heading = math.rad(rng:NextNumber(-10, 10)) -- from +v, positive toward +u
		local turn = math.rad(rng:NextNumber(5, 11)) * (if rng:NextNumber() < 0.5 then -1 else 1)
		local step = rng:NextNumber(0.7, 1.1)
		local transparency = rng:NextNumber(tm.transparency[1], tm.transparency[2])
		for _ = 1, rng:NextInteger(6, 9) do
			local du, dv = math.sin(heading), math.cos(heading)
			floorPaint.mark(u + du * step / 2, v + dv * step / 2, step, tm.widthM, du, dv, C.tyre, transparency)
			u += du * step
			v += dv * step
			heading += turn
			transparency = math.min(0.95, transparency + 0.02) -- fading as the rubber wears off
		end
	end
	-- Oil: most of it under the lift, one or two by the doors and benches.
	local os_ = g.oilStains
	for i = 1, os_.count do
		local u, v
		if i <= os_.count - 2 then
			u, v = g.liftU + rng:NextNumber(-1.2, 1.2), g.lift.v + rng:NextNumber(-1.8, 1.8)
		else
			u, v = rng:NextNumber(1, hw - 2), rng:NextNumber(-hd + 1.5, hd - 2)
		end
		local size = rng:NextNumber(os_.sizeM[1], os_.sizeM[2])
		local a = rng:NextNumber(0, math.pi)
		floorPaint.mark(u, v, size, size * rng:NextNumber(0.55, 0.95), math.cos(a), math.sin(a), C.stain, rng:NextNumber(os_.transparency[1], os_.transparency[2]), true)
	end
	-- The lift's working area: a yellow outline and hatched post bases.
	local lf = g.lift
	do
		local lu, lv = g.liftU, lf.v
		local w2, d2 = lf.postSpanM / 2 + 0.7, 3.2
		for _, side in { -1, 1 } do
			floorPaint.mark(lu + side * w2, lv, d2 * 2, 0.1, 0, 1, C.hatch, 0.1)
			floorPaint.mark(lu, lv + side * d2, w2 * 2 + 0.1, 0.1, 1, 0, C.hatch, 0.1)
			local base = floorPaint.mark(lu + side * lf.postSpanM / 2, lv, 0.9, 0.9, 1, 0, C.hatch, 0.05)
			local stroke = Instance.new("UIStroke")
			stroke.Color = Color3.fromRGB(24, 24, 24)
			stroke.Thickness = 6
			stroke.Parent = base
		end
		-- A floor drain between the posts.
		floorPaint.mark(lu, lv, 0.5, 0.5, 1, 0, Color3.fromRGB(46, 46, 46), 0)
	end

	------------------------------------------------------------------
	-- The shell: walls, piers and lintels, plinth, linings, window,
	-- columns, beams, roof.
	------------------------------------------------------------------
	section("Shell")
	local wallOpts: Opts = { collide = true, shadow = true }
	local function stone(): Color3
		return tinted(C.sandstone, rng, 0.03)
	end
	local sideWalls: { Part } = {}
	for _, side in { -1, 1 } do
		table.insert(sideWalls, box("WallSide", side * (hw - t / 2), 0, 0, t, H, g.depthM, stone(), Enum.Material.Sandstone, wallOpts))
	end
	-- Back: solid behind the display bay, a high window strip in the lift bay.
	local wn = g.window
	box("WallBack", -hw / 2, 0, hd - t / 2, hw, H, t, stone(), Enum.Material.Sandstone, wallOpts)
	box("WallBack", hw / 2, 0, hd - t / 2, hw, wn.bottomM, t, stone(), Enum.Material.Sandstone, wallOpts)
	box("WallBack", hw / 2, wn.bottomM + wn.heightM, hd - t / 2, hw, H - wn.bottomM - wn.heightM, t, stone(), Enum.Material.Sandstone, wallOpts)
	box("WallBack", wn.u0 / 2, wn.bottomM, hd - t / 2, wn.u0, wn.heightM, t, stone(), Enum.Material.Sandstone, wallOpts)
	box("WallBack", (wn.u1 + hw) / 2, wn.bottomM, hd - t / 2, hw - wn.u1, wn.heightM, t, stone(), Enum.Material.Sandstone, wallOpts)
	box("Window", (wn.u0 + wn.u1) / 2, wn.bottomM, hd - t / 2, wn.u1 - wn.u0, wn.heightM, 0.06, C.glass, Enum.Material.Glass, { collide = true, transparency = 0.35 })
	do
		local u = wn.u0 + wn.mullionM
		while u < wn.u1 - 0.3 do
			box("Mullion", u, wn.bottomM, hd - t / 2, 0.06, wn.heightM, 0.12, C.steel, Enum.Material.SmoothPlastic)
			u += wn.mullionM
		end
	end
	-- Front: piers either side of the two openings, a lintel over each.
	local doorUs = { g.displayU, g.liftU }
	local edges = { -hw }
	for _, du in doorUs do
		table.insert(edges, du - door.widthM / 2)
		table.insert(edges, du + door.widthM / 2)
	end
	table.insert(edges, hw)
	for i = 1, #edges, 2 do
		local a, b = edges[i], edges[i + 1]
		box("Pier", (a + b) / 2, 0, -hd + t / 2, b - a, H, t, stone(), Enum.Material.Sandstone, wallOpts)
		-- The plinth: a darker band at the foot, 5 cm proud.
		box("Plinth", (a + b) / 2, 0, -hd - 0.025, b - a, g.plinthM, 0.05, tinted(C.sandstoneDark, rng, 0.02), Enum.Material.Sandstone)
	end
	for _, du in doorUs do
		box("Lintel", du, door.heightM, -hd + t / 2, door.widthM, H - door.heightM, t, tinted(C.sandstoneDark, rng, 0.02), Enum.Material.Sandstone, wallOpts)
	end
	for _, side in { -1, 1 } do
		box("Plinth", side * (hw + 0.025), 0, 0, 0.05, g.plinthM, g.depthM + 0.1, tinted(C.sandstoneDark, rng, 0.02), Enum.Material.Sandstone)
	end
	box("Plinth", 0, 0, hd + 0.025, g.widthM + 0.1, g.plinthM, 0.05, tinted(C.sandstoneDark, rng, 0.02), Enum.Material.Sandstone)

	-- Painted block inside: pale above, a dark dado band below 1.2 m.
	local function lining(u: number, v: number, su: number, sv: number, y0: number, h: number, face: Enum.NormalId)
		local p = box("Lining", u, y0, v, su, h, sv, C.lining, Enum.Material.SmoothPlastic)
		local gui = faceGui(p, face, 4, bl.lining)
		rect(gui, 0, 0, 1, 1, C.lining)
		if y0 < 1.2 then
			local band = (1.2 - y0) / h
			rect(gui, 0, 1 - band, 1, band, C.dado)
			rect(gui, 0, 1 - band - 0.012 * 6 / h, 1, 0.012 * 6 / h, C.hatch)
		end
	end
	lining(-hw + t + 0.01, 0, 0.02, g.depthM - 2 * t, 0.02, H - 0.02, Enum.NormalId.Right)
	lining(hw - t - 0.01, 0, 0.02, g.depthM - 2 * t, 0.02, H - 0.02, Enum.NormalId.Left)
	-- The front wall's piers and the lintels over the doors.
	local fv = -hd + t + 0.01
	for i = 1, #edges, 2 do
		local a, b = edges[i] + (if i == 1 then t else 0), edges[i + 1] - (if i + 1 == #edges then t else 0)
		lining((a + b) / 2, fv, b - a, 0.02, 0.02, H - 0.02, Enum.NormalId.Front)
	end
	for _, du in doorUs do
		lining(du, fv, door.widthM, 0.02, door.heightM, H - door.heightM, Enum.NormalId.Front)
	end
	-- The lift bay's back wall, round the window strip.
	local lb0, lb1, bv = 0.05, hw - t, hd - t - 0.01
	lining((lb0 + lb1) / 2, bv, lb1 - lb0, 0.02, 0.02, wn.bottomM - 0.02, Enum.NormalId.Back)
	lining((lb0 + lb1) / 2, bv, lb1 - lb0, 0.02, wn.bottomM + wn.heightM, H - wn.bottomM - wn.heightM, Enum.NormalId.Back)
	lining((lb0 + wn.u0) / 2, bv, wn.u0 - lb0, 0.02, wn.bottomM, wn.heightM, Enum.NormalId.Back)
	lining((wn.u1 + lb1) / 2, bv, lb1 - wn.u1, 0.02, wn.bottomM, wn.heightM, Enum.NormalId.Back)

	-- Steel: two columns on the line between the bays, a beam over them,
	-- and roof beams front to back.
	local cl, bm = g.columns, g.beams
	for _, cv in cl.v do
		box("Column", 0, 0.02, cv, cl.sizeM, H - bm.depthM - 0.02, cl.sizeM, C.steel, Enum.Material.Metal, { collide = true, shadow = true })
	end
	box("Beam", 0, H - bm.depthM, 0, bm.widthM + 0.05, bm.depthM, g.depthM - 2 * t, C.steel, Enum.Material.Metal)
	for _, bu in bm.u do
		box("RoofBeam", bu, H - bm.depthM, 0, bm.widthM, bm.depthM, g.depthM - 2 * t, C.steel, Enum.Material.Metal)
	end

	-- The roof, and a ribbed steel edge round it (ribs painted on the
	-- faces seen from the road and from either end).
	local rf = g.roof
	local roof = box("Roof", 0, H, 0, g.widthM + 2 * rf.overhangM, rf.thicknessM, g.depthM + 2 * rf.overhangM, C.roofEdge, Enum.Material.SmoothPlastic, { collide = true, shadow = true })
	rect(faceGui(roof, Enum.NormalId.Bottom, 2, bl.ceiling), 0, 0, 1, 1, C.ceiling)
	local ow, od = hw + rf.overhangM, hd + rf.overhangM
	local edgeY = H - 0.05
	type Edge = { u: number, v: number, su: number, sv: number, face: Enum.NormalId?, lenM: number }
	local edgesRoof: { Edge } = {
		{ u = 0, v = -od - 0.03, su = 2 * ow + 0.12, sv = 0.06, face = Enum.NormalId.Back, lenM = 2 * ow },
		{ u = 0, v = od + 0.03, su = 2 * ow + 0.12, sv = 0.06, face = nil, lenM = 2 * ow },
		{ u = -ow - 0.03, v = 0, su = 0.06, sv = 2 * od, face = Enum.NormalId.Left, lenM = 2 * od },
		{ u = ow + 0.03, v = 0, su = 0.06, sv = 2 * od, face = Enum.NormalId.Right, lenM = 2 * od },
	}
	for _, e in edgesRoof do
		local p = box("RoofEdge", e.u, edgeY, e.v, e.su, rf.edgeM, e.sv, C.roofEdge, Enum.Material.SmoothPlastic, { shadow = true })
		if e.face then
			local gui = faceGui(p, e.face, 10, 1)
			local n = math.floor(e.lenM / rf.ribPitchM)
			for k = 0, n - 1 do
				rect(gui, (k + 0.5) / n, 0, 0.14 / n, 1, C.shutterLine, 0.2)
			end
			rect(gui, 0, 0.94, 1, 0.06, C.shutterLine)
		end
	end
	-- Downpipes at the front corners.
	for _, side in { -1, 1 } do
		box("Downpipe", side * (hw - 0.25), 0, -hd - 0.07, 0.11, H, 0.11, C.roofEdge, Enum.Material.SmoothPlastic)
	end

	------------------------------------------------------------------
	-- Doors: the open display door (shutter rolled into its box), the
	-- closed lift-bay shutter, guide rails, the threshold.
	------------------------------------------------------------------
	section("Doors")
	local sb = g.shutterBox
	for _, du in doorUs do
		box("ShutterBox", du, door.heightM, -hd - sb.depthM / 2, door.widthM + 0.35, sb.heightM, sb.depthM, C.shutter, Enum.Material.SmoothPlastic, { shadow = true })
		for _, side in { -1, 1 } do
			box("ShutterRail", du + side * (door.widthM / 2 + 0.06), 0, -hd - 0.06, 0.12, door.heightM, 0.12, C.steel, Enum.Material.SmoothPlastic)
		end
	end
	local shutter = box("Shutter", g.liftU, 0, -hd + 0.08, door.widthM, door.heightM, 0.08, C.shutter, Enum.Material.SmoothPlastic, { collide = true, shadow = true })
	for _, face in { Enum.NormalId.Back, Enum.NormalId.Front } do
		local gui = faceGui(shutter, face, 8, 1)
		local n = math.floor(door.heightM / g.shutterSlatM)
		for k = 1, n - 1 do
			rect(gui, 0, k / n, 1, 0.12 / n, C.shutterLine, 0.1)
		end
		rect(gui, 0, 0.965, 1, 0.035, C.steel) -- the bottom rail
		if face == Enum.NormalId.Back then
			rect(gui, 0.47, 0.9, 0.06, 0.025, C.steel) -- the lock
		end
	end
	box("Threshold", g.displayU, 0, -hd + t / 2, door.widthM, fl.topM + 0.008, t + 0.1, C.steel, Enum.Material.DiamondPlate)

	------------------------------------------------------------------
	-- The sign: GARAGE / كراج on a dark fascia across the front, lit by
	-- three sodium lamps on arms from the roof edge.
	------------------------------------------------------------------
	section("Sign")
	local fz = g.fascia
	local fascia = box("Fascia", 0, fz.bottomM, -hd - fz.projectM / 2, g.widthM, fz.heightM, fz.projectM, C.fascia, Enum.Material.SmoothPlastic, { shadow = true })
	do
		local gui = faceGui(fascia, Enum.NormalId.Back, 20, 0.35)
		rect(gui, 0, 0.9, 1, 0.035, C.sodium) -- a sodium line along the foot
		local mid = 0.5
		label(gui, fz.english, mid - 0.175, 0.14, 0.16, 0.66, C.fasciaText, Enum.TextXAlignment.Right)
		label(gui, fz.arabic, mid + 0.015, 0.06, 0.12, 0.78, C.fasciaArabic, Enum.TextXAlignment.Left)
		-- A turned square between the two scripts.
		local aspect = fascia.Size.Y / fascia.Size.X
		local diamond = rect(gui, mid, 0.47, 0.165 * aspect, 0.165, C.sodium)
		diamond.AnchorPoint = Vector2.new(0.5, 0.5)
		diamond.Rotation = 45
		-- The trades at either end, small.
		label(gui, "SERVICE  ·  TYRES  ·  OIL", 0.03, 0.34, 0.2, 0.32, C.fasciaText, Enum.TextXAlignment.Left)
		label(gui, "صيانة  ·  كفرات  ·  زيوت", 0.77, 0.3, 0.2, 0.4, C.fasciaText, Enum.TextXAlignment.Right)
	end
	for _, lu in { -8, 0, 8 } do
		local top = Vector3.new(lu, H + 0.35, -hd - rf.overhangM - 0.03)
		local tip = Vector3.new(lu, fz.bottomM + fz.heightM + 0.3, -hd - fz.projectM - 0.8)
		rodIn(o, "SignLampArm", top, tip, 0.05, C.steel, Enum.Material.SmoothPlastic)
		local head = box("SignLamp", lu, tip.Y - 0.08, tip.Z, 0.34, 0.08, 0.16, C.sodium, Enum.Material.Neon)
		head.CFrame *= CFrame.Angles(math.rad(-25), 0, 0)
	end

	------------------------------------------------------------------
	-- The display bay: the backdrop with its cove, and the turntable.
	------------------------------------------------------------------
	section("Display")
	local tt = g.turntable
	-- From the left lining to just short of the columns' line.
	local bu0, bu1 = -hw + t + 0.02, 0.05
	local backdropW, backdropU = bu1 - bu0, (bu0 + bu1) / 2
	local backdrop = box("Backdrop", backdropU, 0.02, hd - t - 0.07, backdropW, H - 0.04, 0.1, C.backdrop, Enum.Material.SmoothPlastic, { collide = true })
	backdrop.Parent = folder
	rect(faceGui(backdrop, Enum.NormalId.Back, 2, bl.backdrop), 0, 0, 1, 1, C.backdrop)
	do
		-- A 45 degree cove where the backdrop meets the floor, so there is no
		-- hard line behind the car. A wedge's tall face is at its +Z: turned
		-- to face the backdrop.
		local cove = g.backdrop.coveM
		local coveWedge = Build.wedge({
			name = "BackdropCove",
			size = Vector3.new(S(backdropW), S(cove), S(cove)),
			cframe = place(o, backdropU, fl.topM + cove / 2, hd - t - 0.12 - cove / 2) * CFrame.Angles(0, math.pi, 0),
			color = C.backdrop,
			material = Enum.Material.SmoothPlastic,
			parent = current,
		})
		-- A wedge's sloped face takes a SurfaceGui as its Front (measured).
		rect(faceGui(coveWedge, Enum.NormalId.Front, 2, bl.backdrop), 0, 0, 1, 1, C.backdrop)
	end
	local ringD = tt.diameterM + 2 * tt.ringM
	local ringPart = cylIn(o, "TurntableRing", g.displayU, tt.ringTopM - tt.thicknessM / 2, tt.v, ringD, tt.thicknessM, "y", C.ring, Enum.Material.Metal, { collide = true })
	local plate = cylIn(o, "Turntable", g.displayU, tt.topM - tt.thicknessM / 2, tt.v, tt.diameterM, tt.thicknessM, "y", C.turntable, Enum.Material.DiamondPlate, { collide = true })
	-- The same painted-on light over both, as discs on the top end (a
	-- cylinder's +X end, turned up), half clear so the plate's tread shows.
	for _, top in { ringPart, plate } do
		local gui = faceGui(top, Enum.NormalId.Right, 4, bl.turntable)
		local f = rect(gui, 0, 0, 1, 1, top.Color, 0.35)
		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(0.5, 0)
		c.Parent = f
	end
	plate:SetAttribute("GarageRole", "turntable")
	plate:SetAttribute("ViewFrame", place(o, g.displayU, tt.topM, tt.v))
	plate.Parent = folder

	------------------------------------------------------------------
	-- The lift bay: a two-post lift, arms out under a car the client builds.
	------------------------------------------------------------------
	section("Lift")
	do
		local lu, lv = g.liftU, lf.v
		local half = lf.postSpanM / 2
		local padY = lf.raiseM + 0.18 -- the sills, above the tyres' bottoms
		for _, side in { -1, 1 } do
			local pu = lu + side * half
			box("LiftBase", pu, 0.02, lv, 0.75, 0.03, 0.6, C.steel, Enum.Material.DiamondPlate)
			box("LiftPost", pu, 0.02, lv, 0.34, lf.heightM, 0.28, C.lift, Enum.Material.SmoothPlastic, { shadow = true })
			box("LiftCarriage", pu - side * 0.04, padY - 0.5, lv, 0.4, 0.55, 0.4, Color3.fromRGB(40, 42, 46), Enum.Material.SmoothPlastic)
			-- Two arms from each carriage to pads under the car's jacking points.
			for _, fb in { -1, 1 } do
				local a = Vector3.new(pu - side * 0.12, padY - 0.1, lv + fb * 0.12)
				local b = Vector3.new(lu + side * 0.62, padY - 0.1, lv + fb * 1.3)
				rodIn(o, "LiftArm", a, b, 0.12, Color3.fromRGB(40, 42, 46), Enum.Material.SmoothPlastic)
				box("LiftPad", b.X, padY - 0.06, b.Z, 0.2, 0.06, 0.2, Color3.fromRGB(24, 24, 24), Enum.Material.Rubber)
			end
		end
		box("LiftBeam", lu, lf.heightM, lv, lf.postSpanM + 0.34, 0.22, 0.28, C.lift, Enum.Material.SmoothPlastic, { shadow = true })
		box("LiftMotor", lu + half + 0.3, 1.0, lv + 0.05, 0.26, 0.5, 0.3, Color3.fromRGB(40, 42, 46), Enum.Material.SmoothPlastic)
		-- Yellow and black on the post feet.
		for _, side in { -1, 1 } do
			local stripe = box("LiftGuard", lu + side * half, 0.05, lv - 0.17, 0.34, 0.5, 0.02, C.hatch, Enum.Material.SmoothPlastic)
			local gui = faceGui(stripe, Enum.NormalId.Back, 20, 1)
			for k = 0, 2 do
				rect(gui, 0, k * 0.33 + 0.1, 1, 0.14, Color3.fromRGB(24, 24, 24))
			end
		end
		local spot = Build.part({
			name = "LiftCarSpot",
			size = Vector3.new(S(1.8), S(0.1), S(4.4)),
			cframe = place(o, lu, lf.raiseM, lv),
			color = C.hatch,
			parent = folder,
			transparency = 1,
		})
		spot:SetAttribute("CarId", "kamri07")
	end

	------------------------------------------------------------------
	-- Strip lighting: two rows per bay of long warm fittings on hangers.
	------------------------------------------------------------------
	section("Strips")
	local sp = g.strips
	for _, bu in doorUs do
		for _, side in { -1, 1 } do
			local su = bu + side * sp.rowOffsetM
			for i = 1, sp.perRow do
				local sv = (i - (sp.perRow + 1) / 2) * sp.spacingM
				local y = H - sp.dropM
				box("StripHousing", su, y - 0.09, sv, 0.24, 0.09, sp.lengthM + 0.1, C.housing, Enum.Material.SmoothPlastic)
				local lens = box("StripLens", su, y - 0.12, sv, 0.13, 0.03, sp.lengthM, C.strip, Enum.Material.Neon)
				CollectionService:AddTag(lens, WorldLighting.LAMP_TAG)
				lamps += 1
				for _, e in { -1, 1 } do
					local hv = sv + e * (sp.lengthM / 2 - 0.3)
					box("StripHanger", su, y, hv, 0.02, sp.dropM, 0.02, C.steel, Enum.Material.SmoothPlastic)
				end
			end
		end
	end

	------------------------------------------------------------------
	-- Workshop dressing, from WorldConfig.garage.props.
	------------------------------------------------------------------
	section("Dressing")
	local dark = Color3.fromRGB(34, 35, 38)
	local builders: { [string]: (pr: Prop, pf: CFrame) -> () } = {}

	-- A bench: steel frame, wooden top, a drawer unit, a vice on the right.
	builders.workbench = function(_pr: Prop, pf: CFrame)
		local w, d = 2.4, 0.75
		boxIn(pf, "BenchTop", 0, 0.86, -d / 2, w, 0.05, d, C.wood, Enum.Material.WoodPlanks)
		for _, x in { -w / 2 + 0.05, w / 2 - 0.05 } do
			for _, z in { -0.06, -d + 0.06 } do
				boxIn(pf, "BenchLeg", x, 0, z, 0.06, 0.86, 0.06, C.steel, Enum.Material.SmoothPlastic)
			end
		end
		boxIn(pf, "BenchShelf", 0, 0.14, -d / 2, w - 0.1, 0.03, d - 0.1, C.steel, Enum.Material.SmoothPlastic)
		local drawers = boxIn(pf, "BenchDrawers", -w / 2 + 0.4, 0.17, -d / 2 - 0.02, 0.6, 0.66, d - 0.12, C.rollCab, Enum.Material.SmoothPlastic)
		local gui = faceGui(drawers, Enum.NormalId.Back, 30, 1)
		for k = 1, 3 do
			rect(gui, 0, k / 4, 1, 0.012, dark)
			rect(gui, 0.35, k / 4 - 0.1, 0.3, 0.025, C.shelf)
		end
		-- The vice.
		boxIn(pf, "ViceBase", w / 2 - 0.3, 0.91, -d + 0.14, 0.18, 0.1, 0.26, C.lift, Enum.Material.SmoothPlastic)
		boxIn(pf, "ViceJaw", w / 2 - 0.3, 0.97, -d + 0.02, 0.2, 0.12, 0.07, C.lift, Enum.Material.SmoothPlastic)
		rodIn(pf, "ViceHandle", Vector3.new(w / 2 - 0.46, 0.99, -d - 0.04), Vector3.new(w / 2 - 0.14, 0.99, -d - 0.04), 0.02, C.shelf, Enum.Material.SmoothPlastic)
		-- A red toolbox and a parts tray on the top.
		boxIn(pf, "Toolbox", -0.2, 0.91, -0.3, 0.5, 0.22, 0.24, C.red, Enum.Material.SmoothPlastic)
		boxIn(pf, "PartsTray", 0.45, 0.91, -0.4, 0.4, 0.05, 0.3, Color3.fromRGB(62, 90, 60), Enum.Material.SmoothPlastic)
	end

	-- A shadow board with spanners, a hammer and screwdrivers hung on it.
	builders.toolBoard = function(pr: Prop, pf: CFrame)
		local w, h, y = pr.widthM or 1.8, pr.heightM or 1, pr.y or 1.2
		local board = boxIn(pf, "ToolBoard", 0, y, -0.015, w, h, 0.03, C.board, Enum.Material.SmoothPlastic)
		local gui = faceGui(board, Enum.NormalId.Back, 20, bl.lining)
		rect(gui, 0, 0, 1, 1, C.board)
		rect(gui, 0, 0, 1, 0.03, dark)
		rect(gui, 0, 0.97, 1, 0.03, dark)
		local x = -w / 2 + 0.14
		local top = y + h - 0.12
		local zf = -0.04
		-- Spanners, a hammer, screwdrivers, in turn from a random start.
		local pick = rng:NextInteger(0, 2)
		while x < w / 2 - 0.2 do
			pick = pick % 3 + 1
			if pick == 1 then
				-- A run of spanners, longest first.
				for k = 0, 3 do
					local len = 0.3 - k * 0.04
					boxIn(pf, "Spanner", x + k * 0.07, top - len, zf, 0.025, len, 0.015, C.tool, Enum.Material.SmoothPlastic)
				end
				x += 0.38
			elseif pick == 2 then
				boxIn(pf, "HammerHandle", x + 0.06, top - 0.34, zf, 0.035, 0.3, 0.025, C.wood, Enum.Material.SmoothPlastic)
				boxIn(pf, "HammerHead", x + 0.06, top - 0.06, zf, 0.14, 0.04, 0.04, C.tool, Enum.Material.SmoothPlastic)
				x += 0.26
			else
				local handles = { C.red, Color3.fromRGB(232, 184, 40), Color3.fromRGB(44, 79, 124) }
				for k = 1, 3 do
					local hx = x + (k - 1) * 0.08
					boxIn(pf, "Screwdriver", hx, top - 0.1, zf, 0.035, 0.1, 0.03, handles[k], Enum.Material.SmoothPlastic)
					boxIn(pf, "Screwdriver", hx, top - 0.26, zf, 0.012, 0.16, 0.012, C.tool, Enum.Material.SmoothPlastic)
				end
				x += 0.3
			end
		end
	end

	-- A red roll cab on castors with a top chest; drawers painted on.
	builders.rollCab = function(_pr: Prop, pf: CFrame)
		local w, d = 1.4, 0.6
		for _, x in { -w / 2 + 0.08, w / 2 - 0.08 } do
			for _, z in { -0.08, -d + 0.08 } do
				boxIn(pf, "Castor", x, 0, z, 0.08, 0.1, 0.08, dark, Enum.Material.SmoothPlastic)
			end
		end
		local body = boxIn(pf, "RollCab", 0, 0.1, -d / 2, w, 0.95, d, C.rollCab, Enum.Material.SmoothPlastic)
		boxIn(pf, "RollCabMat", 0, 1.05, -d / 2, w + 0.02, 0.02, d + 0.02, dark, Enum.Material.Rubber)
		local chest = boxIn(pf, "RollCabChest", 0, 1.07, -0.27, w - 0.04, 0.42, 0.5, C.rollCab, Enum.Material.SmoothPlastic)
		for _, part in { body, chest } do
			local gui = faceGui(part, Enum.NormalId.Back, 30, 1)
			local n = if part == body then 5 else 3
			for k = 1, n - 1 do
				rect(gui, 0, k / n, 1, 0.012, dark)
			end
			for k = 0, n - 1 do
				rect(gui, 0.12, (k + 0.18) / n, 0.76, 0.03, C.shelf)
			end
		end
		rodIn(pf, "RollCabHandle", Vector3.new(w / 2 + 0.03, 0.9, -0.12), Vector3.new(w / 2 + 0.03, 0.9, -d + 0.12), 0.03, C.shelf, Enum.Material.SmoothPlastic)
	end

	-- An air compressor: a horizontal tank on feet, motor and pump on top.
	builders.compressor = function(_pr: Prop, pf: CFrame)
		for _, x in { -0.38, 0.38 } do
			boxIn(pf, "CompressorFoot", x, 0, -0.27, 0.08, 0.14, 0.36, dark, Enum.Material.SmoothPlastic)
		end
		cylIn(pf, "CompressorTank", 0, 0.36, -0.27, 0.46, 1.15, "x", C.compressor, Enum.Material.SmoothPlastic)
		boxIn(pf, "CompressorMotor", -0.22, 0.58, -0.27, 0.34, 0.28, 0.28, dark, Enum.Material.SmoothPlastic)
		boxIn(pf, "CompressorPump", 0.22, 0.58, -0.27, 0.24, 0.36, 0.24, Color3.fromRGB(150, 152, 150), Enum.Material.SmoothPlastic)
		boxIn(pf, "CompressorGuard", 0, 0.62, -0.47, 0.62, 0.22, 0.05, C.red, Enum.Material.SmoothPlastic)
		-- The air line up the wall and across to the hose reel.
		rodIn(pf, "AirLine", Vector3.new(0.22, 0.95, -0.2), Vector3.new(0.22, 2.62, -0.03), 0.04, C.steel, Enum.Material.SmoothPlastic)
		rodIn(pf, "AirLine", Vector3.new(0.24, 2.6, -0.03), Vector3.new(-1.9, 2.6, -0.03), 0.04, C.steel, Enum.Material.SmoothPlastic)
	end

	-- A coil of yellow air hose on a wall bracket, its end hanging down.
	builders.hoseReel = function(pr: Prop, pf: CFrame)
		local y = pr.y or 1.8
		boxIn(pf, "HoseBracket", 0, y + 0.22, -0.06, 0.08, 0.1, 0.12, dark, Enum.Material.SmoothPlastic)
		-- The reel's drum, its end toward the room (a cylinder's -X end, turned
		-- along the frame's look) painted with the wound hose.
		local coil = cylIn(pf, "HoseCoil", 0, y + 0.3, -0.12, 0.6, 0.1, "z", C.steel, Enum.Material.SmoothPlastic)
		local gui = faceGui(coil, Enum.NormalId.Left, 60, 1)
		local hose = Color3.fromRGB(214, 170, 36)
		disc(gui, 0.5, 0.5, 0.96, hose:Lerp(Color3.new(0, 0, 0), 0.35))
		disc(gui, 0.5, 0.5, 0.9, hose)
		disc(gui, 0.5, 0.5, 0.72, hose:Lerp(Color3.new(0, 0, 0), 0.35))
		disc(gui, 0.5, 0.5, 0.66, hose)
		disc(gui, 0.5, 0.5, 0.4, dark)
		rodIn(pf, "HoseEnd", Vector3.new(0.22, y + 0.1, -0.12), Vector3.new(0.26, y - 0.8, -0.14), 0.03, Color3.fromRGB(214, 170, 36), Enum.Material.Rubber)
	end

	-- A steel rack: four uprights, four shelves, tyres or boxes on it.
	local function tyre(pf: CFrame, x: number, y: number, z: number, axis: string)
		cylIn(pf, "Tyre", x, y, z, 0.64, 0.22, axis, C.tyre, Enum.Material.Rubber)
	end
	builders.shelf = function(pr: Prop, pf: CFrame)
		local w, d = 1.8, 0.55
		for _, x in { -w / 2 + 0.03, w / 2 - 0.03 } do
			for _, z in { -0.03, -d + 0.03 } do
				boxIn(pf, "RackUpright", x, 0, z, 0.05, 2.12, 0.05, C.rack, Enum.Material.SmoothPlastic)
			end
		end
		local levels = { 0.08, 0.8, 1.5, 2.08 }
		for _, y in levels do
			boxIn(pf, "RackShelf", 0, y, -d / 2, w, 0.03, d, C.shelf, Enum.Material.SmoothPlastic)
		end
		local function boxesOn(y: number, fill: number)
			local x = -w / 2 + 0.08
			while x < w / 2 - 0.25 do
				local bw = rng:NextNumber(0.25, 0.5)
				if x + bw > w / 2 - 0.05 then
					break
				end
				if rng:NextNumber() < fill then
					local bh = rng:NextNumber(0.2, 0.45)
					local bd = rng:NextNumber(0.3, 0.45)
					local colour = if rng:NextNumber() < 0.75 then tinted(C.cardboard, rng, 0.08) else ({ C.red, Color3.fromRGB(232, 184, 40), Color3.fromRGB(40, 110, 70) })[rng:NextInteger(1, 3)]
					boxIn(pf, "Stock", x + bw / 2, y + 0.03, -0.05 - bd / 2, bw, bh, bd, colour, Enum.Material.SmoothPlastic)
				end
				x += bw + rng:NextNumber(0.03, 0.12)
			end
		end
		if pr.load == "tyres" then
			for k = 0, 2 do
				tyre(pf, -0.55 + k * 0.52, 0.83 + 0.32, -d / 2, "x")
			end
			for k = 0, 1 do
				tyre(pf, -0.4 + k * 0.6, 1.53 + 0.32, -d / 2, "x")
			end
			boxesOn(0.08, 0.8)
			boxesOn(2.08, 0.6)
		else
			boxesOn(0.08, 0.7)
			boxesOn(0.8, 0.9)
			boxesOn(1.5, 0.9)
			boxesOn(2.08, 0.6)
		end
	end

	-- Tyres stacked flat, each a little off the one below.
	builders.tyreStack = function(pr: Prop, pf: CFrame)
		for k = 0, (pr.count or 4) - 1 do
			tyre(pf, rng:NextNumber(-0.04, 0.04), 0.115 + k * 0.225, rng:NextNumber(-0.04, 0.04), "y")
		end
	end

	builders.drum = function(_pr: Prop, pf: CFrame)
		cylIn(pf, "Drum", 0, 0.44, 0, 0.58, 0.88, "y", Color3.fromRGB(39, 70, 110), Enum.Material.SmoothPlastic)
		cylIn(pf, "DrumFunnel", 0.1, 0.92, 0.05, 0.22, 0.08, "y", dark, Enum.Material.SmoothPlastic)
	end

	-- A trolley jack: a low body on wheels, a saddle, a long handle.
	builders.jack = function(_pr: Prop, pf: CFrame)
		boxIn(pf, "Jack", 0, 0.05, 0, 0.3, 0.14, 0.78, C.red, Enum.Material.SmoothPlastic)
		boxIn(pf, "JackSaddle", 0, 0.12, -0.45, 0.16, 0.08, 0.16, dark, Enum.Material.SmoothPlastic)
		for _, x in { -0.17, 0.17 } do
			boxIn(pf, "JackWheel", x, 0, 0.28, 0.05, 0.1, 0.1, dark, Enum.Material.Rubber)
			boxIn(pf, "JackWheel", x, 0, -0.3, 0.05, 0.08, 0.08, dark, Enum.Material.Rubber)
		end
		rodIn(pf, "JackHandle", Vector3.new(0, 0.16, 0.36), Vector3.new(0, 0.95, 1.05), 0.04, C.red, Enum.Material.SmoothPlastic)
	end

	-- A red extinguisher on a bracket, with its sign above.
	builders.extinguisher = function(pr: Prop, pf: CFrame)
		local y = pr.y or 0.8
		boxIn(pf, "ExtBracket", 0, y + 0.3, -0.03, 0.12, 0.08, 0.06, dark, Enum.Material.SmoothPlastic)
		cylIn(pf, "Extinguisher", 0, y + 0.3, -0.13, 0.17, 0.6, "y", C.red, Enum.Material.SmoothPlastic)
		boxIn(pf, "ExtHead", 0, y + 0.6, -0.13, 0.06, 0.1, 0.06, dark, Enum.Material.SmoothPlastic)
		rodIn(pf, "ExtHose", Vector3.new(0.04, y + 0.64, -0.13), Vector3.new(0.11, y + 0.1, -0.12), 0.025, dark, Enum.Material.Rubber)
		local sign = boxIn(pf, "ExtSign", 0, y + 0.85, -0.006, 0.3, 0.3, 0.012, C.red, Enum.Material.SmoothPlastic)
		local gui = faceGui(sign, Enum.NormalId.Back, 60, 1)
		label(gui, "حريق", 0.1, 0.1, 0.8, 0.45, Color3.new(1, 1, 1))
		label(gui, "FIRE", 0.1, 0.58, 0.8, 0.3, Color3.new(1, 1, 1))
	end

	for _, pr in g.props do
		local b = builders[pr.kind]
		if b then
			b(pr, place(o, pr.u, 0, pr.v, pr.yawDeg))
		else
			warn(`[World] garage: no builder for prop "{pr.kind}"`)
		end
	end

	------------------------------------------------------------------
	-- Outside: an AC unit and painted trades on the end wall the spawn
	-- sees, bollards at the piers, wheel stops.
	------------------------------------------------------------------
	section("Outside")
	do
		local wall = sideWalls[1] -- the left end, toward the spawn
		local gui = faceGui(wall, Enum.NormalId.Left, 6, 1)
		rect(gui, 0.08, 0.3, 0.6, 0.012, C.fascia, 0.2)
		label(gui, "كراج  ·  صيانة عامة", 0.08, 0.16, 0.6, 0.12, C.fascia)
		label(gui, "GARAGE  ·  GENERAL SERVICE", 0.08, 0.33, 0.6, 0.07, C.fascia)
		local ac = box("AcUnit", -hw - 0.22, 2.8, 4.2, 0.42, 0.62, 0.9, Color3.fromRGB(226, 226, 220), Enum.Material.SmoothPlastic, { shadow = true })
		local ag = faceGui(ac, Enum.NormalId.Left, 40, 1)
		disc(ag, 0.62, 0.5, 0.8, Color3.fromRGB(80, 82, 84))
		disc(ag, 0.62, 0.5, 0.7, Color3.fromRGB(206, 206, 200))
		disc(ag, 0.62, 0.5, 0.2, Color3.fromRGB(80, 82, 84))
		box("AcPipe", -hw - 0.06, 0.4, 4.7, 0.06, 2.4, 0.06, Color3.fromRGB(226, 226, 220), Enum.Material.SmoothPlastic)
		box("AcBracket", -hw - 0.22, 2.7, 4.2, 0.42, 0.06, 0.8, C.steel, Enum.Material.SmoothPlastic)
	end
	for _, bu in { g.displayU + door.widthM / 2 + 0.35, g.liftU - door.widthM / 2 - 0.35, -hw + 0.35, hw - 0.35 } do
		local b = box("Bollard", bu, 0, -hd - g.doorApronM + 0.4, 0.2, 0.95, 0.2, C.hatch, Enum.Material.SmoothPlastic)
		local gui = faceGui(b, Enum.NormalId.Back, 40, 1)
		rect(gui, 0, 0.62, 1, 0.12, dark)
		rect(gui, 0, 0.82, 1, 0.12, dark)
	end

	------------------------------------------------------------------
	-- The apron on the pad: three bays in front of the lift bay, a
	-- keep-clear hatch in front of the open door, an arrow and GARAGE.
	------------------------------------------------------------------
	section("Apron")
	local ap = g.apron
	local apFront = math.min(ap.textV, ap.arrowV) - 2.5
	local apBack = -hd - g.doorApronM
	local apVc = (apFront + apBack) / 2
	local sheet = box("ApronPaint", 0, 0.012, apVc, g.widthM, 0.02, apBack - apFront, C.paint, Enum.Material.SmoothPlastic, { transparency = 1 })
	local apronPaint = painter(sheet, 0, apVc, g.widthM, apBack - apFront, 6)
	local bayEnd = apBack - ap.bayDepthM
	for k = 0, ap.bays do
		local bu = ap.bayU0 + k * ap.bayWidthM
		apronPaint.mark(bu, (apBack + bayEnd) / 2 - 0.1, ap.bayDepthM - 0.2, ap.lineM, 0, 1, C.paint, 0.15)
	end
	for k = 0, ap.bays - 1 do
		local bu = ap.bayU0 + (k + 0.5) * ap.bayWidthM
		box("WheelStop", bu, 0, apBack - 0.9, 1.7, 0.12, 0.2, Color3.fromRGB(200, 196, 186), Enum.Material.Concrete)
	end
	-- The hatch: a yellow box and diagonal stripes clipped to it.
	do
		local u0, u1 = g.displayU - door.widthM / 2, g.displayU + door.widthM / 2
		local v1, v0 = apBack - 0.15, apBack - 0.15 - ap.hatchDepthM
		local lw = 0.12
		apronPaint.mark(u0, (v0 + v1) / 2, v1 - v0, lw, 0, 1, C.hatch, 0.1)
		apronPaint.mark(u1, (v0 + v1) / 2, v1 - v0, lw, 0, 1, C.hatch, 0.1)
		apronPaint.mark((u0 + u1) / 2, v0, u1 - u0, lw, 1, 0, C.hatch, 0.1)
		apronPaint.mark((u0 + u1) / 2, v1, u1 - u0, lw, 1, 0, C.hatch, 0.1)
		-- Lines u - v = c, clipped to the box.
		local c = (u0 - v1) + 0.6
		while c < u1 - v0 - 0.3 do
			local va, vb = math.max(v0, u0 - c) + 0.08, math.min(v1, u1 - c) - 0.08
			if vb > va then
				local len = (vb - va) * math.sqrt(2)
				local vm = (va + vb) / 2
				apronPaint.mark(vm + c, vm, len, 0.22, 1, 1, C.hatch, 0.15)
			end
			c += 0.75
		end
	end
	-- The arrow toward the open door, and the lettering on the road side.
	do
		local au, av = g.displayU, ap.arrowV
		apronPaint.mark(au, av - 0.4, 3.2, 0.3, 0, 1, C.paint, 0.15)
		for _, side in { -1, 1 } do
			local a = math.rad(side * 35)
			local du, dv = math.sin(a), -math.cos(a)
			apronPaint.mark(au + du * 0.6, av + 1.2 + dv * 0.6, 1.4, 0.3, du, dv, C.paint, 0.15)
		end
		apronPaint.text(fz.english, g.displayU, ap.textV + 0.4, 5.5, 1.6, C.paint, 0.2)
		apronPaint.text(fz.arabic, g.displayU, ap.textV - 1.3, 3.2, 1.6, C.paint, 0.2)
	end

	------------------------------------------------------------------
	-- The client's handles: the threshold and where a leaving player
	-- stands.
	------------------------------------------------------------------
	local doorFrame = place(o, g.displayU, door.heightM / 2, -hd + t / 2)
	Build.part({
		name = "DoorZone",
		size = Vector3.new(S(door.widthM), S(door.heightM), S(g.doorZoneDepthM)),
		cframe = doorFrame,
		color = C.hatch,
		parent = folder,
		transparency = 1,
	})
	-- Where the door is, on the folder (always on every client, where the
	-- parts stream): the menu's CUSTOMIZE streams the garage in around it
	-- before the view opens (GarageView.visit).
	folder:SetAttribute("DoorPosition", doorFrame.Position)
	Build.part({
		name = "ExitSpot",
		size = Vector3.new(S(0.6), S(0.6), S(0.6)),
		cframe = place(o, g.displayU, g.exitSpot.rootHeightM, -hd - g.exitSpot.outM, 180),
		color = C.hatch,
		parent = folder,
		transparency = 1,
	})

	folder:SetAttribute("StripLamps", lamps)
	return folder
end

return Garage
