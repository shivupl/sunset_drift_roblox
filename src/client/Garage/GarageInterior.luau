--!strict
-- The garage's interior look (GarageThemes): the display bay's dressing,
-- built on this client over the server's shell, and the grading the view
-- brings while it is open (the studio sky the paint reflects, ambient, bloom,
-- colour, depth of field). Built on every client, so every player sees the
-- same room; nothing here replicates or collides.
--
-- GarageView calls apply() when it finds the garage, viewOpen()/viewClose()
-- around the view, lights() for the view's lights, and shadow() for the soft
-- shadow under the turntable car.
local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local ContentProvider = game:GetService("ContentProvider")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GarageThemes = require(Shared:WaitForChild("GarageThemes"))
local ConfigLoader = require(Shared:WaitForChild("ConfigLoader"))

local GarageInterior = {}

export type Garage = { folder: Folder, viewFrame: CFrame, turntable: BasePart }

local FOLDER = "GarageTheme"
local GRADE = "GarageGrade"
local FOCUS = "GarageFocus"
local FOCUS_STEP = "GarageFocusStep"
local FONT = Font.new("rbxasset://fonts/families/Oswald.json", Enum.FontWeight.Bold)

local current: Garage? = nil
-- The studio skies whose three images have loaded (see GarageThemes.skies).
local skyReady: { [string]: boolean } = {}
local built: Folder? = nil
local themeId = GarageThemes.resolve(nil)
-- Shell parts this look hides or restyles, with what they were, so another
-- look (or none) puts them back.
type Saved = { part: BasePart, transparency: number, color: Color3, material: Enum.Material, reflectance: number, guis: { [SurfaceGui]: boolean } }
local saved: { [BasePart]: Saved } = {}
local floorParts: { BasePart } = {}
local viewOpen = false
-- GarageView's: repaint the interior's painted-on light (bakedScale changed).
local rebake: () -> () = function() end
type EnvSaved = { ambient: Color3, sky: { [string]: any }?, bloom: { [string]: number }? }
local envSaved: EnvSaved? = nil

local function mps(): number
	return ConfigLoader.current().units.metersPerStud
end

local function theme(): GarageThemes.Theme
	return GarageThemes.themes[themeId]
end

-- A part at view-frame metres: `cf` is the part's centre and turn in the
-- view frame (metres), `sizeM` its size in metres.
local function part(parent: Instance, name: string, sizeM: Vector3, cf: CFrame, color: Color3, material: Enum.Material?): Part
	local g = current :: Garage
	local s = mps()
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Size = sizeM / s
	p.CFrame = g.viewFrame * CFrame.new(cf.Position / s) * cf.Rotation
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

-- A box between two corners (view-frame metres).
local function slab(parent: Instance, name: string, a: Vector3, b: Vector3, color: Color3, material: Enum.Material?): Part
	local lo = a:Min(b)
	local hi = a:Max(b)
	return part(parent, name, hi - lo, CFrame.new((lo + hi) / 2), color, material)
end

-- Where a shell part sits in the view frame, metres.
local function viewPos(p: BasePart): Vector3
	local g = current :: Garage
	return g.viewFrame:PointToObjectSpace(p.Position) * mps()
end

------------------------------------------------------------------------
-- The shell: hiding and restyling the server's parts on this client.
------------------------------------------------------------------------

local function remember(p: BasePart): Saved
	local had = saved[p]
	if had then
		return had
	end
	local guis = {}
	for _, c in p:GetChildren() do
		if c:IsA("SurfaceGui") then
			guis[c] = c.Enabled
		end
	end
	local s: Saved = { part = p, transparency = p.Transparency, color = p.Color, material = p.Material, reflectance = p.Reflectance, guis = guis }
	saved[p] = s
	return s
end

local function hide(p: BasePart)
	local s = remember(p)
	p.Transparency = 1
	for gui in s.guis do
		gui.Enabled = false
	end
end

local function restyle(p: BasePart, color: Color3?, material: Enum.Material?, keepGuis: boolean?)
	local s = remember(p)
	if color then
		p.Color = color
	end
	if material then
		p.Material = material
	end
	if not keepGuis then
		for gui in s.guis do
			gui.Enabled = false
		end
	end
end

local function restoreShell()
	for p, s in saved do
		if p.Parent then
			p.Transparency = s.transparency
			p.Color = s.color
			p.Material = s.material
			p.Reflectance = s.reflectance
			for gui, enabled in s.guis do
				gui.Enabled = enabled
			end
		end
	end
	table.clear(saved)
	table.clear(floorParts)
end

-- The display bay's own parts of the shell (left of the column line).
local function inDisplayBay(p: BasePart): boolean
	local r = GarageThemes.room
	local v = viewPos(p)
	return v.X < r.splitX - 0.25 and v.Z > r.backZ - 1 and v.Z < r.frontZ + 1
end

local function shellFor(t: GarageThemes.Theme)
	local g = current :: Garage
	local folder = g.folder
	local ring = folder:FindFirstChild("TurntableRing", true)
	if ring and ring:IsA("BasePart") and t.colors.ring then
		restyle(ring, t.colors.ring, Enum.Material.Neon)
	end
	if t.colors.plate then
		restyle(g.turntable, t.colors.plate, Enum.Material.Metal, true)
	end
	if t.kind == "workshop" then
		return
	end
	if t.kind == "cozy" then
		-- The real workshop: the photo backdrop goes so its back wall shows,
		-- and the strip fittings glow low and warm (or sit dark) instead of
		-- lighting the room flat.
		for _, name in { "Backdrop", "BackdropCove" } do
			local p = folder:FindFirstChild(name, true)
			if p and p:IsA("BasePart") then
				hide(p)
			end
		end
		local strips = folder:FindFirstChild("Strips")
		if strips and t.colors.strip then
			for _, d in strips:GetDescendants() do
				if d:IsA("BasePart") and d.Name == "StripLens" then
					restyle(d, t.colors.strip, Enum.Material.Neon, true)
					d.Transparency = 0.15
				end
			end
		end
		return
	end
	-- Studio and Gallery dress the whole display bay: the shell's backdrop,
	-- the workshop's strip fittings and the display bay's dressing go.
	for _, name in { "Backdrop", "BackdropCove" } do
		local p = folder:FindFirstChild(name, true)
		if p and p:IsA("BasePart") then
			hide(p)
		end
	end
	for _, fname in { "Strips", "Dressing" } do
		local f = folder:FindFirstChild(fname)
		if f then
			for _, d in f:GetDescendants() do
				if d:IsA("BasePart") and inDisplayBay(d) then
					hide(d)
				end
			end
		end
	end
end

------------------------------------------------------------------------
-- The dressing.
------------------------------------------------------------------------

-- The floor and the room's skin: a slab over the shell's floor, panels just
-- inside its walls and under its roof, so the shell does not show.
local function skin(f: Folder, t: GarageThemes.Theme, wallColor: Color3)
	local r = GarageThemes.room
	local c = t.colors
	local top = r.floorY + 0.012
	local fl = slab(f, "ThemeFloor", Vector3.new(r.leftX, top - 0.02, r.backZ), Vector3.new(r.splitX, top, r.frontZ), c.floor)
	fl.Reflectance = t.floorReflect
	table.insert(floorParts, fl)
	local inset = 0.03
	slab(f, "ThemeWall", Vector3.new(r.leftX, r.floorY, r.backZ + inset), Vector3.new(r.splitX, r.ceilingY, r.backZ + inset + 0.02), wallColor)
	slab(f, "ThemeWall", Vector3.new(r.leftX + inset, r.floorY, r.backZ), Vector3.new(r.leftX + inset + 0.02, r.ceilingY, r.frontZ), wallColor)
	-- The front wall round the open door.
	local fz = r.frontZ - inset
	local hw = r.door.halfWidthM
	slab(f, "ThemeWall", Vector3.new(r.leftX, r.floorY, fz), Vector3.new(-hw, r.ceilingY, fz - 0.02), wallColor)
	slab(f, "ThemeWall", Vector3.new(hw, r.floorY, fz), Vector3.new(r.splitX, r.ceilingY, fz - 0.02), wallColor)
	slab(f, "ThemeWall", Vector3.new(-hw, r.door.heightM, fz), Vector3.new(hw, r.ceilingY, fz - 0.02), wallColor)
	slab(f, "ThemeCeiling", Vector3.new(r.leftX, r.ceilingY, r.backZ), Vector3.new(r.splitX, r.ceilingY + 0.02, r.frontZ), c.ceiling)
end

-- A honeycomb of LED bars over the turntable (flat-topped hexagons, edge
-- `edgeM`), clipped to the rectangle, hung at y. The look of a detailing
-- studio's ceiling.
local function honeycomb(f: Folder, x0: number, x1: number, z0: number, z1: number, y: number, edgeM: number, barM: number, color: Color3): number
	local edges: { [string]: { Vector3 } } = {}
	local w = 1.5 * edgeM
	local h = math.sqrt(3) * edgeM
	local function key(p: Vector3): string
		return string.format("%.2f,%.2f", p.X, p.Z)
	end
	local col = 0
	local cx = x0 + edgeM
	while cx <= x1 - edgeM + 1e-6 do
		local offset = if col % 2 == 1 then h / 2 else 0
		local cz = z0 + h / 2 + offset
		while cz <= z1 - h / 2 + 1e-6 do
			local corners = {}
			for i = 0, 5 do
				local a = math.rad(60 * i)
				table.insert(corners, Vector3.new(cx + edgeM * math.cos(a), y, cz + edgeM * math.sin(a)))
			end
			for i = 1, 6 do
				local a, b = corners[i], corners[i % 6 + 1]
				local k1, k2 = key(a), key(b)
				local k = if k1 < k2 then k1 .. "|" .. k2 else k2 .. "|" .. k1
				edges[k] = { a, b }
			end
			cz += h
		end
		cx += w
		col += 1
	end
	local n = 0
	for _, e in edges do
		local a, b = e[1], e[2]
		local mid = (a + b) / 2
		local len = (b - a).Magnitude
		local bar = part(f, "HexBar", Vector3.new(barM, barM * 0.6, len + barM * 0.6), CFrame.lookAt(mid, b), color, Enum.Material.Neon)
		bar.Transparency = 0.05
		n += 1
	end
	return n
end

-- Text glowing on a wall: a thin board with a SurfaceGui, facing +Z (the
-- room) when on the back wall.
local function wallText(f: Folder, at: Vector3, sizeM: Vector2, text: string, color: Color3, cf: CFrame?)
	local board = part(f, "ThemeSign", Vector3.new(sizeM.X, sizeM.Y, 0.02), cf or CFrame.new(at), color)
	board.Transparency = 1
	local g = Instance.new("SurfaceGui")
	g.Face = Enum.NormalId.Back
	g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	g.PixelsPerStud = 40
	g.LightInfluence = 0
	g.Brightness = 1.4
	g.Parent = board
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Text = text
	label.TextScaled = true
	label.FontFace = FONT
	label.TextColor3 = color
	label.Parent = g
end

-- A part turned so a Cylinder (its axis along X) stands upright.
local UPRIGHT = CFrame.Angles(0, 0, math.rad(90))

local function cylinder(parent: Instance, name: string, diameterM: number, heightM: number, at: Vector3, color: Color3, material: Enum.Material?): Part
	local p = part(parent, name, Vector3.new(heightM, diameterM, diameterM), CFrame.new(at) * UPRIGHT, color, material)
	p.Shape = Enum.PartType.Cylinder
	return p
end

-- A hanging enamel lamp: cord to the ceiling, a wide shallow shade, a cap,
-- and the bulb glowing under the rim (Neon, so it blooms) when lit.
local function pendant(f: Folder, pd: GarageThemes.Pendant, c: { [string]: Color3 })
	local r = GarageThemes.room
	local at = pd.positionM
	slab(f, "LampCord", Vector3.new(at.X - 0.006, at.Y + 0.12, at.Z - 0.006), Vector3.new(at.X + 0.006, r.ceilingY + 0.3, at.Z + 0.006), c.cord)
	cylinder(f, "LampCap", 0.14, 0.1, at + Vector3.new(0, 0.1, 0), c.shade, Enum.Material.Metal)
	cylinder(f, "LampShade", 0.5, 0.16, at, c.shade, Enum.Material.Metal)
	-- The shade's flared rim, a little wider and thinner.
	cylinder(f, "LampShade", 0.56, 0.03, at - Vector3.new(0, 0.08, 0), c.shade, Enum.Material.Metal)
	local bulb = part(f, "LampBulb", Vector3.new(0.12, 0.12, 0.12), CFrame.new(at - Vector3.new(0, 0.1, 0)), c.bulb, if pd.brightness > 0 then Enum.Material.Neon else Enum.Material.Glass)
	bulb.Shape = Enum.PartType.Ball
end

-- The back wall of a working shop: a pegboard of tools, a steel shelf of oil
-- cans and boxes, a clock.
local function shopWall(f: Folder, c: { [string]: Color3 })
	local r = GarageThemes.room
	-- The brick face over the shell's back wall, then everything in front.
	if c.brick then
		local brick = slab(f, "Brick", Vector3.new(r.leftX, r.floorY, r.backZ + 0.03), Vector3.new(r.splitX, r.ceilingY, r.backZ + 0.05), c.brick, Enum.Material.Brick)
		brick.CastShadow = false
	end
	local z = r.backZ + 0.07
	-- Pegboard, 2 m by 1.2 m, and its tools hung on it.
	local px, py = -3.9, 1.0
	slab(f, "Pegboard", Vector3.new(px - 1.0, py, z), Vector3.new(px + 1.0, py + 1.2, z + 0.02), c.pegboard)
	local tz = z + 0.04
	local function tool(x: number, y: number, w: number, h: number, col: Color3)
		slab(f, "Tool", Vector3.new(px + x - w / 2, py + y, tz - 0.01), Vector3.new(px + x + w / 2, py + y + h, tz + 0.01), col, Enum.Material.Metal)
	end
	-- Spanners, longest first.
	tool(-0.8, 0.25, 0.04, 0.42, c.tool)
	tool(-0.7, 0.3, 0.04, 0.36, c.tool)
	tool(-0.6, 0.35, 0.035, 0.3, c.tool)
	tool(-0.5, 0.4, 0.03, 0.25, c.tool)
	-- A hammer.
	tool(-0.15, 0.3, 0.05, 0.5, c.tool)
	tool(-0.15, 0.72, 0.24, 0.08, c.tool)
	-- Screwdrivers with red handles.
	for i, x in { 0.2, 0.32, 0.44 } do
		local len = 0.3 - (i - 1) * 0.04
		tool(x, 0.3, 0.025, len, c.tool)
		tool(x, 0.3 + len, 0.05, 0.14, c.toolRed)
	end
	-- A rack of sockets.
	for _, y in { 0.25, 0.45, 0.65 } do
		tool(0.75, y, 0.3, 0.06, c.tool)
	end
	-- A steel shelf, 1.6 m wide, three boards of cans and boxes.
	local sx, sw, sd = 3.4, 1.6, 0.45
	for _, ux in { sx - sw / 2, sx + sw / 2 } do
		slab(f, "ShelfPost", Vector3.new(ux - 0.025, r.floorY, z), Vector3.new(ux + 0.025, 2.0, z + sd), c.shelf, Enum.Material.Metal)
	end
	local rng = Random.new(4127)
	local cans = { c.can1, c.can2, c.can3, c.can4 }
	for _, y in { 0.35, 1.0, 1.65 } do
		slab(f, "ShelfBoard", Vector3.new(sx - sw / 2, y - 0.03, z), Vector3.new(sx + sw / 2, y, z + sd), c.shelf, Enum.Material.Metal)
		local x = sx - sw / 2 + 0.12
		while x < sx + sw / 2 - 0.12 do
			if rng:NextNumber() < 0.25 then
				-- A cardboard box.
				local bw = 0.3
				slab(f, "ShelfBox", Vector3.new(x, y, z + 0.06), Vector3.new(x + bw, y + 0.24, z + 0.4), Color3.fromRGB(150, 112, 74))
				x += bw + 0.06
			else
				local h = 0.16 + rng:NextNumber() * 0.1
				cylinder(f, "OilCan", 0.11, h, Vector3.new(x + 0.06, y + h / 2, z + 0.2), cans[rng:NextInteger(1, #cans)], Enum.Material.SmoothPlastic)
				x += 0.15
			end
		end
	end
	-- A plain wall clock.
	local clock = part(f, "Clock", Vector3.new(0.04, 0.36, 0.36), CFrame.new(1.4, 3.6, z + 0.03) * CFrame.Angles(0, math.rad(90), 0), c.clock)
	clock.Shape = Enum.PartType.Cylinder
	slab(f, "ClockHand", Vector3.new(1.39, 3.6, z + 0.06), Vector3.new(1.41, 3.74, z + 0.07), c.tool)
	slab(f, "ClockHand", Vector3.new(1.4, 3.59, z + 0.06), Vector3.new(1.5, 3.61, z + 0.07), c.tool)
end

-- A sign on the back wall: a painted tin sign (lit by the room) or neon
-- tubes (glowing text, blooming).
local function sign(f: Folder, sg: GarageThemes.Sign)
	local at = sg.positionM
	local board = part(f, "ShopSign", Vector3.new(sg.sizeM.X, sg.sizeM.Y, 0.02), CFrame.new(at), sg.background or Color3.new(0, 0, 0))
	if sg.neon then
		board.Transparency = 1
	end
	local g = Instance.new("SurfaceGui")
	g.Face = Enum.NormalId.Back
	g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	g.PixelsPerStud = 40
	g.LightInfluence = if sg.neon then 0 else 1
	g.Brightness = if sg.neon then 2.2 else 1
	g.Parent = board
	local function label(text: string, y: number, h: number)
		local l = Instance.new("TextLabel")
		l.BackgroundTransparency = 1
		l.Position = UDim2.fromScale(0.06, y)
		l.Size = UDim2.fromScale(0.88, h)
		l.Text = text
		l.TextScaled = true
		l.FontFace = FONT
		l.TextColor3 = sg.color
		l.Parent = g
	end
	if sg.arabic then
		label(sg.text, 0.1, 0.46)
		label(sg.arabic, 0.56, 0.36)
	else
		label(sg.text, 0.05, 0.9)
	end
end

-- Dust drifting in the light over the turntable.
local function dust(f: Folder)
	local box = part(f, "DustVolume", Vector3.new(6, 3, 6), CFrame.new(0, 2, 0.5), Color3.new(1, 1, 1))
	box.Transparency = 1
	local e = Instance.new("ParticleEmitter")
	e.Shape = Enum.ParticleEmitterShape.Box
	e.ShapeInOut = Enum.ParticleEmitterShapeInOut.Outward
	e.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	e.Rate = 14
	e.Lifetime = NumberRange.new(6, 10)
	e.Speed = NumberRange.new(0.02, 0.08)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Size = NumberSequence.new(0.03 / mps())
	e.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.2, 0.5),
		NumberSequenceKeypoint.new(0.8, 0.5),
		NumberSequenceKeypoint.new(1, 1),
	})
	e.Color = ColorSequence.new(Color3.fromRGB(255, 220, 170))
	e.LightEmission = 0.3
	e.LightInfluence = 1
	e.Parent = box
end

-- A caged lamp on an arm off the back wall (its light is in lights()).
local function wallLamp(f: Folder, at: Vector3, c: { [string]: Color3 }, lit: boolean)
	local r = GarageThemes.room
	slab(f, "LampArm", Vector3.new(at.X - 0.015, at.Y + 0.1, r.backZ + 0.05), Vector3.new(at.X + 0.015, at.Y + 0.13, at.Z + 0.02), c.cord, Enum.Material.Metal)
	cylinder(f, "LampShade", 0.3, 0.14, at, c.shade, Enum.Material.Metal)
	local bulb = part(f, "LampBulb", Vector3.new(0.09, 0.09, 0.09), CFrame.new(at - Vector3.new(0, 0.08, 0)), c.bulb, if lit then Enum.Material.Neon else Enum.Material.Glass)
	bulb.Shape = Enum.PartType.Ball
end

-- A twin-tube shop light on two chains: a dark steel housing along X, two
-- tubes under it (Neon, so they glow like the bulbs). Its light is in lights().
local function shopLight(f: Folder, sl: GarageThemes.ShopLight, c: { [string]: Color3 })
	local r = GarageThemes.room
	local at = sl.positionM
	local half = sl.lengthM / 2
	for _, dx in { -half + 0.15, half - 0.15 } do
		slab(f, "ShopLightChain", Vector3.new(at.X + dx - 0.008, at.Y + 0.04, at.Z - 0.008), Vector3.new(at.X + dx + 0.008, r.ceilingY + 0.3, at.Z + 0.008), c.cord, Enum.Material.Metal)
	end
	slab(f, "ShopLightHousing", Vector3.new(at.X - half, at.Y, at.Z - 0.11), Vector3.new(at.X + half, at.Y + 0.05, at.Z + 0.11), c.shelf or c.cord, Enum.Material.Metal)
	for _, dz in { -0.05, 0.05 } do
		local tube = part(f, "ShopLightTube", Vector3.new(sl.lengthM - 0.08, 0.035, 0.035), CFrame.new(at + Vector3.new(0, -0.02, dz)), sl.color, if sl.brightness > 0 then Enum.Material.Neon else Enum.Material.Glass)
		tube.Shape = Enum.PartType.Cylinder
	end
end

local function buildCozy(f: Folder, t: GarageThemes.Theme)
	local c = t.colors
	local wl = t.wallLamp
	if wl then
		wallLamp(f, wl.positionM, c, wl.brightness > 0)
	end
	local pendants = t.pendants
	if pendants then
		for _, pd in pendants do
			pendant(f, pd, c)
		end
	end
	for _, sl in t.shopLights or ({} :: { GarageThemes.ShopLight }) do
		shopLight(f, sl, c)
	end
	shopWall(f, c)
	local signs = t.signs
	if signs then
		for _, sg in signs do
			sign(f, sg)
		end
	end
	if t.dust then
		dust(f)
	end
end

local function buildStudio(f: Folder, t: GarageThemes.Theme)
	local r = GarageThemes.room
	local c = t.colors
	skin(f, t, c.wall)
	local bz = r.backZ + 0.06
	-- The back wall: a lighter panel behind the turntable, and either side
	-- of it a tall softbox in a dark frame (the same boxes the studio sky
	-- puts in the paint, so what the car reflects is in the room).
	slab(f, "WallPanel", Vector3.new(-2.4, 0.3, bz), Vector3.new(2.4, r.ceilingY - 0.5, bz + 0.02), c.wallPanel)
	local function softbox(name: string, lo: Vector3, hi: Vector3, frame: Vector3)
		slab(f, name .. "Frame", lo - frame, hi + frame - Vector3.new(0, 0, frame.Z), c.trim)
		local face = slab(f, name, lo, hi, c.softbox, Enum.Material.Neon)
		face.Transparency = 0.35
	end
	for _, x in { -3.6, 3.6 } do
		softbox("Softbox", Vector3.new(x - 0.3, 0.7, bz + 0.03), Vector3.new(x + 0.3, 4.5, bz + 0.06), Vector3.new(0.06, 0.06, 0.03))
	end
	-- The left wall: two more, for the close shots that look that way.
	local lx = r.leftX + 0.06
	for _, z in { -1.4, 3.8 } do
		softbox("Softbox", Vector3.new(lx + 0.03, 0.7, z - 0.3), Vector3.new(lx + 0.06, 4.5, z + 0.3), Vector3.new(0.03, 0.06, 0.06))
	end
	-- An amber cove line where the walls meet the floor: the walls float.
	for _, cove in { { Vector3.new(r.leftX + 0.05, 0, bz), Vector3.new(r.splitX, 0.04, bz + 0.03) }, { Vector3.new(lx, 0, r.backZ), Vector3.new(lx + 0.03, 0.04, r.frontZ - 0.1) } } do
		local line = slab(f, "CoveLed", cove[1], cove[2], c.ring, Enum.Material.Neon)
		line.Transparency = 0.2
	end
	-- The partition to the workshop on the column line: a solid base, smoked
	-- glass to above head height, solid to the ceiling.
	local sx = r.splitX
	slab(f, "PartitionBase", Vector3.new(sx - 0.08, r.floorY, r.backZ), Vector3.new(sx, 1.0, r.frontZ), c.wall)
	local glass = slab(f, "PartitionGlass", Vector3.new(sx - 0.05, 1.0, r.backZ), Vector3.new(sx - 0.03, 3.4, r.frontZ), c.glass, Enum.Material.Glass)
	glass.Transparency = 0.45
	glass.Reflectance = 0.1
	slab(f, "PartitionHead", Vector3.new(sx - 0.08, 3.4, r.backZ), Vector3.new(sx, r.ceilingY, r.frontZ), c.wall)
	slab(f, "PartitionTrim", Vector3.new(sx - 0.1, 0.98, r.backZ), Vector3.new(sx - 0.07, 1.02, r.frontZ), c.trim, Enum.Material.Metal)
	slab(f, "PartitionTrim", Vector3.new(sx - 0.1, 3.38, r.backZ), Vector3.new(sx - 0.07, 3.42, r.frontZ), c.trim, Enum.Material.Metal)
	-- The honeycomb over the turntable. Hung at 4.5 m it filled the top of
	-- the full framing and pressed down on the car; at 5.5 it left the
	-- frame (measured live 2026-11-09). 5.1 keeps its near edge in the top
	-- of the frame.
	honeycomb(f, -3.4, 3.4, -3.0, 3.8, 5.1, 0.55, 0.045, c.led)
	-- The game's name, small and lit, on the panel behind the car.
	wallText(f, Vector3.new(0, 4.25, bz + 0.05), Vector2.new(1.7, 0.46), "HAJWALA", c.ring)
	wallText(f, Vector3.new(0, 3.8, bz + 0.05), Vector2.new(1.0, 0.34), "هجولة", c.led)
end

local function buildGallery(f: Folder, t: GarageThemes.Theme)
	local r = GarageThemes.room
	local c = t.colors
	skin(f, t, c.wall)
	-- The cyclorama: the back wall curves into the floor (a quarter circle
	-- of radius 1.4 m in slats), so the backdrop has no corner line.
	local rad = 1.4
	local n = 8
	local bz = r.backZ + 0.05
	for i = 0, n - 1 do
		local a0 = math.rad(90 * i / n)
		local a1 = math.rad(90 * (i + 1) / n)
		-- Centre of the curve at (y = rad, z = bz + rad); the arc runs from
		-- the floor (a = 0) to the wall (a = 90).
		local p0 = Vector3.new(0, rad - rad * math.cos(a0), bz + rad - rad * math.sin(a0))
		local p1 = Vector3.new(0, rad - rad * math.cos(a1), bz + rad - rad * math.sin(a1))
		local mid = (p0 + p1) / 2
		local len = (p1 - p0).Magnitude + 0.02
		local width = r.splitX - r.leftX
		local centre = Vector3.new((r.leftX + r.splitX) / 2, mid.Y, mid.Z)
		-- -Z along the arc, so the slat's length follows the curve.
		part(f, "Cyc", Vector3.new(width, 0.02, len), CFrame.lookAt(centre, centre + (p1 - p0)), c.wall)
	end
	-- The partition: a plain white wall, so the room is all studio.
	slab(f, "Partition", Vector3.new(r.splitX - 0.08, r.floorY, r.backZ), Vector3.new(r.splitX, r.ceilingY, r.frontZ), c.wall)
	-- The light box: one broad glowing panel over the turntable, framed.
	local y = r.ceilingY - 0.04
	local panel = slab(f, "LightBox", Vector3.new(-3.6, y - 0.03, -3.2), Vector3.new(3.6, y, 4.0), c.led, Enum.Material.Neon)
	panel.Transparency = 0.15
	slab(f, "LightBoxFrame", Vector3.new(-3.75, y - 0.06, -3.35), Vector3.new(3.75, y - 0.03, -3.2), c.trim)
	slab(f, "LightBoxFrame", Vector3.new(-3.75, y - 0.06, 4.0), Vector3.new(3.75, y - 0.03, 4.15), c.trim)
	slab(f, "LightBoxFrame", Vector3.new(-3.75, y - 0.06, -3.2), Vector3.new(-3.6, y - 0.03, 4.0), c.trim)
	slab(f, "LightBoxFrame", Vector3.new(3.6, y - 0.06, -3.2), Vector3.new(3.75, y - 0.03, 4.0), c.trim)
end

local function build()
	local g = current
	if not g or not g.folder.Parent then
		return
	end
	local old = built
	if old then
		old:Destroy()
	end
	restoreShell()
	local t = theme()
	local f = Instance.new("Folder")
	f.Name = FOLDER
	if t.kind == "cozy" then
		buildCozy(f, t)
	elseif t.kind == "studio" then
		buildStudio(f, t)
	elseif t.kind == "gallery" then
		buildGallery(f, t)
	end
	shellFor(t)
	f.Parent = g.folder
	built = f
	if viewOpen then
		for _, p in floorParts do
			p.Reflectance = t.floorReflectView
		end
	end
end

------------------------------------------------------------------------
-- The view's grading.
------------------------------------------------------------------------

local function bloomEffect(): BloomEffect?
	return Lighting:FindFirstChildOfClass("BloomEffect")
end

local function applyEnv()
	local t = theme()
	local env = t.env
	local sky = Lighting:FindFirstChildOfClass("Sky")
	local saves = envSaved
	if not saves then
		local s: EnvSaved = { ambient = Lighting.Ambient }
		if sky then
			s.sky = {
				SkyboxBk = sky.SkyboxBk,
				SkyboxFt = sky.SkyboxFt,
				SkyboxLf = sky.SkyboxLf,
				SkyboxRt = sky.SkyboxRt,
				SkyboxUp = sky.SkyboxUp,
				SkyboxDn = sky.SkyboxDn,
				CelestialBodiesShown = sky.CelestialBodiesShown,
			}
		end
		local b = bloomEffect()
		if b then
			s.bloom = { Intensity = b.Intensity, Size = b.Size, Threshold = b.Threshold }
		end
		saves = s
		envSaved = s
	end
	local box = GarageThemes.skies[env.sky]
	if sky and box and skyReady[env.sky] then
		local side = GarageThemes.skyImage(box.side)
		sky.SkyboxBk, sky.SkyboxFt, sky.SkyboxLf, sky.SkyboxRt = side, side, side, side
		sky.SkyboxUp, sky.SkyboxDn = GarageThemes.skyImage(box.up), GarageThemes.skyImage(box.down)
		sky.CelestialBodiesShown = false
	end
	Lighting.Ambient = env.ambient
	local b = bloomEffect()
	if b then
		b.Intensity, b.Size, b.Threshold = env.bloom.intensity, env.bloom.size, env.bloom.threshold
	end
	local grade = Lighting:FindFirstChild(GRADE) :: ColorCorrectionEffect?
	if not grade then
		local cc = Instance.new("ColorCorrectionEffect")
		cc.Name = GRADE
		cc.Parent = Lighting
		grade = cc
	end
	assert(grade)
	grade.Brightness = env.grade.brightness
	grade.Contrast = env.grade.contrast
	grade.Saturation = env.grade.saturation
	grade.TintColor = env.grade.tint
	local focus = Lighting:FindFirstChild(FOCUS) :: DepthOfFieldEffect?
	if env.dof then
		if not focus then
			local d = Instance.new("DepthOfFieldEffect")
			d.Name = FOCUS
			d.NearIntensity = 0
			d.Parent = Lighting
			focus = d
		end
		assert(focus)
		focus.FarIntensity = env.dof.farIntensity
		focus.InFocusRadius = env.dof.inFocusRadiusM / mps()
	elseif focus then
		focus:Destroy()
	end
	for _, p in floorParts do
		p.Reflectance = t.floorReflectView
	end
end

local function clearEnv()
	pcall(function()
		RunService:UnbindFromRenderStep(FOCUS_STEP)
	end)
	for _, name in { GRADE, FOCUS } do
		local e = Lighting:FindFirstChild(name)
		if e then
			e:Destroy()
		end
	end
	local s = envSaved
	envSaved = nil
	if s then
		Lighting.Ambient = s.ambient
		local sky = Lighting:FindFirstChildOfClass("Sky")
		if sky and s.sky then
			for k, v in s.sky do
				(sky :: any)[k] = v
			end
		end
		local b = bloomEffect()
		if b and s.bloom then
			b.Intensity, b.Size, b.Threshold = s.bloom.Intensity, s.bloom.Size, s.bloom.Threshold
		end
	end
	local t = theme()
	for _, p in floorParts do
		p.Reflectance = t.floorReflect
	end
end

------------------------------------------------------------------------
-- The API.
------------------------------------------------------------------------

-- The garage is here (or here again): dress it.
function GarageInterior.apply(g: Garage)
	if current and current.folder == g.folder and built and built.Parent then
		return
	end
	current = g
	build()
end

function GarageInterior.themeId(): string
	return themeId
end

-- The view's lights for this look (GarageView makes them).
function GarageInterior.lights(): { GarageThemes.Light }
	local t = theme()
	local out = table.clone(t.lights)
	local wl = t.wallLamp
	if wl and wl.brightness > 0 then
		table.insert(out, {
			type = "SpotLight",
			positionM = wl.positionM - Vector3.new(0, 0.1, 0),
			aimM = wl.aimM,
			brightness = wl.brightness,
			rangeM = wl.rangeM,
			angleDeg = wl.angleDeg,
			color = t.colors.bulb,
		})
	end
	for _, sl in t.shopLights or ({} :: { GarageThemes.ShopLight }) do
		if sl.brightness > 0 then
			table.insert(out, {
				type = "SpotLight",
				positionM = sl.positionM - Vector3.new(0, 0.06, 0),
				aimM = sl.aimM,
				brightness = sl.brightness,
				rangeM = sl.rangeM,
				angleDeg = sl.angleDeg,
				color = sl.color,
				shadows = true,
			})
		end
	end
	for _, pd in t.pendants or ({} :: { GarageThemes.Pendant }) do
		if pd.brightness > 0 then
			-- Straight down from the bulb, warm like it.
			local bulb = pd.positionM - Vector3.new(0, 0.12, 0)
			table.insert(out, {
				type = "SpotLight",
				positionM = bulb,
				aimM = bulb - Vector3.new(0, 4, 0),
				brightness = pd.brightness,
				rangeM = pd.rangeM,
				angleDeg = pd.angleDeg,
				color = t.colors.bulb,
			})
		end
	end
	return out
end

-- The factor on the interior's painted-on light (GarageConfig.bakedGlow)
-- while the view is open: the look's bakedGlowView, else 1.
function GarageInterior.bakedScale(): number
	if not viewOpen then
		return 1
	end
	return theme().bakedGlowView or 1
end

-- The view opened: the look's sky, ambient and grading, and depth of field
-- following the camera's distance to the turntable.
function GarageInterior.viewOpen()
	viewOpen = true
	applyEnv()
	rebake()
	local g = current
	if not g then
		return
	end
	pcall(function()
		RunService:UnbindFromRenderStep(FOCUS_STEP)
	end)
	RunService:BindToRenderStep(FOCUS_STEP, Enum.RenderPriority.Camera.Value + 2, function()
		local focus = Lighting:FindFirstChild(FOCUS) :: DepthOfFieldEffect?
		local cam = Workspace.CurrentCamera
		if focus and cam and current then
			local aim = current.viewFrame * Vector3.new(0, 0.6 / mps(), 0)
			focus.FocusDistance = (cam.CFrame.Position - aim).Magnitude
		end
	end)
end

function GarageInterior.viewClose()
	viewOpen = false
	clearEnv()
	rebake()
end

-- The soft shadow under the turntable car: a part the view moves with the
-- car (flat on the plate, centred on the axis), its footprint `sizeM`
-- (width, length) in metres. Rounded rectangles stacked from the footprint
-- inward, each faint, so it is darkest under the middle and fades out.
function GarageInterior.shadow(parent: Instance, sizeM: Vector2): Part
	local s = mps()
	local p = Instance.new("Part")
	p.Name = "GarageCarShadow"
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Transparency = 1
	local w, l = sizeM.X * 1.18 / s, sizeM.Y * 1.1 / s
	p.Size = Vector3.new(w, 0.02, l)
	local g = Instance.new("SurfaceGui")
	g.Face = Enum.NormalId.Top
	g.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
	local px = 256
	g.CanvasSize = Vector2.new(px, math.floor(px * l / w))
	g.LightInfluence = 0
	g.Parent = p
	local layers = 7
	for i = 0, layers - 1 do
		local k = 1 - i * 0.07
		local fr = Instance.new("Frame")
		fr.AnchorPoint = Vector2.new(0.5, 0.5)
		fr.Position = UDim2.fromScale(0.5, 0.5)
		fr.Size = UDim2.fromScale(k, k - (1 - k) * 0.4)
		fr.BackgroundColor3 = Color3.new(0, 0, 0)
		fr.BackgroundTransparency = 0.84
		fr.BorderSizePixel = 0
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0.45, 0)
		corner.Parent = fr
		fr.Parent = g
	end
	p.Parent = parent
	return p
end

-- Studio's T: the next look (only while the view is open).
function GarageInterior.cycle(): GarageThemes.Theme
	local i = table.find(GarageThemes.order, themeId) or 0
	local nextId = GarageThemes.order[i % #GarageThemes.order + 1]
	Players.LocalPlayer:SetAttribute(GarageThemes.ATTRIBUTE, nextId)
	return GarageThemes.themes[nextId]
end

-- The choice changed (T, or the attribute set by hand): rebuild, and if the
-- view is open regrade it; `relight` remakes the view's lights.
function GarageInterior.start(relight: () -> (), repaint: () -> ())
	rebake = repaint
	local player = Players.LocalPlayer
	-- Load the studio skies now, so they are ready by the time the view
	-- opens; a sky whose images do not load is never swapped in.
	task.spawn(function()
		for name, box in GarageThemes.skies do
			local images = { GarageThemes.skyImage(box.side), GarageThemes.skyImage(box.up), GarageThemes.skyImage(box.down) }
			local loaded = 0
			pcall(function()
				ContentProvider:PreloadAsync(images, function(_, status: Enum.AssetFetchStatus)
					if status == Enum.AssetFetchStatus.Success then
						loaded += 1
					end
				end)
			end)
			skyReady[name] = loaded == #images
		end
	end)
	themeId = GarageThemes.resolve(player:GetAttribute(GarageThemes.ATTRIBUTE))
	player:GetAttributeChangedSignal(GarageThemes.ATTRIBUTE):Connect(function()
		themeId = GarageThemes.resolve(player:GetAttribute(GarageThemes.ATTRIBUTE))
		build()
		if viewOpen then
			applyEnv()
			relight()
			rebake()
		end
	end)
end

return GarageInterior
