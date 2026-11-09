--!strict
-- The working dash gauges (CarDashes) in the car this client drives: the
-- speed and rev needles, the backlit numbers and the gear and clock
-- screen, rebuilt where the store model had them and driven from the
-- car's state each frame. Only for the driver's own car, the one whose
-- state this client has; built on the client, so nothing replicates.
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local VehicleRig = require(Shared:WaitForChild("VehicleRig"))
local ConfigLoader = require(Shared:WaitForChild("ConfigLoader"))
local CarDashes = require(Shared:WaitForChild("CarDashes"))

local DashGauges = {}

local FOLDER = "DashGauges"
local KMH_PER_MPH = 1.609344
local FONT = Font.fromEnum(Enum.Font.SourceSans)
local WHITE = Color3.fromRGB(255, 255, 255)
local RED = Color3.fromRGB(255, 0, 0)

type Built = {
	model: Model,
	folder: Folder,
	needles: { { dial: CarDashes.Dial, holder: Frame } },
	gear: TextLabel?,
	clock: TextLabel?,
	lastClock: string,
	lastGear: string,
}

local built: Built? = nil

local function placePart(name: string, folder: Folder, mount: Attachment, f: number, posM: { number }, rotDeg: { number }, sizeM: { number }): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Transparency = 1
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Massless = true
	p.Size = Vector3.new(sizeM[1], sizeM[2], sizeM[3]) * f
	p.CFrame = mount.WorldCFrame
		* CFrame.new(posM[1] * f, posM[2] * f, posM[3] * f)
		* CFrame.fromEulerAnglesYXZ(math.rad(rotDeg[1]), math.rad(rotDeg[2]), math.rad(rotDeg[3]))
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = mount.Parent :: BasePart
	weld.Part1 = p
	weld.Parent = p
	p.Parent = folder
	return p
end

local function surface(part: Part, face: Enum.NormalId, w: number, h: number, light: number): SurfaceGui
	local g = Instance.new("SurfaceGui")
	g.Face = face
	g.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
	g.CanvasSize = Vector2.new(w, h)
	g.LightInfluence = light
	g.ResetOnSpawn = false
	g.Parent = part
	return g
end

-- A full-canvas frame turned about the canvas centre: what the kit's
-- needles and numbers hang off.
local function turner(parent: Instance, deg: number): Frame
	local fr = Instance.new("Frame")
	fr.Size = UDim2.fromScale(1, 1)
	fr.BackgroundTransparency = 1
	fr.Rotation = deg
	fr.Parent = parent
	return fr
end

local function text(parent: Instance, s: string, size: number, color: Color3): TextLabel
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.Text = s
	t.TextSize = size
	t.TextColor3 = color
	t.FontFace = FONT
	t.Parent = parent
	return t
end

local function buildDial(dial: CarDashes.Dial, part: Part): Frame
	local c = CarDashes.CANVAS
	local g = surface(part, dial.face, c, c, dial.lightInfluence)
	local labels = dial.labels
	if labels then
		-- The numbers: each on a turned frame at the left edge, turned back
		-- upright, as the kit drew them.
		for i, s in labels.texts do
			local deg = labels.startDeg + (i - 1) * labels.stepDeg
			local t = text(turner(g, deg), s, labels.textSize, if labels.redFrom and i >= labels.redFrom then RED else WHITE)
			t.Position = UDim2.fromScale(0.05, 0.45)
			t.Size = UDim2.fromScale(0.1, 0.1)
			t.Rotation = -deg
		end
	end
	local holder = turner(g, dial.zeroDeg)
	holder.ZIndex = 4
	-- The bar runs left from startPx out from the centre to lengthPx.
	local start = dial.needle.startPx or 0
	local bar = Instance.new("Frame")
	bar.AnchorPoint = Vector2.new(1, 0.5)
	bar.Position = UDim2.new(0.5, -start, 0.5, 0)
	bar.Size = UDim2.fromOffset(dial.needle.lengthPx - start, dial.needle.widthPx)
	bar.BackgroundColor3 = dial.needle.color
	bar.BorderSizePixel = 0
	bar.ZIndex = 4
	bar.Parent = holder
	return holder
end

local function buildScreen(screen: CarDashes.Screen, part: Part): (TextLabel, TextLabel)
	local w, h = screen.canvas[1], screen.canvas[2]
	local g = surface(part, screen.face, w, h, screen.lightInfluence)
	local bg = screen.background
	if bg then
		local img = Instance.new("ImageLabel")
		img.Size = UDim2.fromScale(1, 1)
		img.BackgroundTransparency = 1
		img.Image = bg.image
		img.ImageColor3 = bg.color
		img.ImageTransparency = bg.transparency
		img.Parent = g
	end
	local clock = text(g, "", screen.clockSize, WHITE)
	clock.AnchorPoint = Vector2.new(0.5, 0.5)
	clock.Position = UDim2.fromOffset(w / 2, screen.clockY)
	clock.Size = UDim2.fromOffset(w, screen.clockSize)
	clock.ZIndex = 2
	local gear = text(g, "N", screen.gearSize, WHITE)
	gear.AnchorPoint = Vector2.new(0.5, 0.5)
	gear.Position = UDim2.fromOffset(w / 2, screen.gearY)
	gear.Size = UDim2.fromOffset(w, screen.gearSize)
	gear.ZIndex = 3
	return clock, gear
end

function DashGauges.detach()
	local b = built
	built = nil
	if b then
		b.folder:Destroy()
	end
end

local function attach(model: Model): Built?
	local carId = model:GetAttribute(VehicleRig.CAR_ID_ATTRIBUTE)
	local dash = CarDashes.of(if type(carId) == "string" then carId else nil)
	if not dash or type(carId) ~= "string" then
		return nil
	end
	local ok, handles = pcall(VehicleRig.handles, model)
	if not ok then
		return nil
	end
	local cfg = ConfigLoader.forCar(carId)
	local f = VehicleRig.scaleOf(ConfigLoader.entry(carId)) / cfg.units.metersPerStud
	local mount = handles.bodyMount
	local folder = Instance.new("Folder")
	folder.Name = FOLDER
	local needles = {}
	for _, dial in dash.dials do
		local part = placePart(dial.name, folder, mount, f, dial.posM, dial.rotationDeg, dial.sizeM)
		table.insert(needles, { dial = dial, holder = buildDial(dial, part) })
	end
	local clock, gear = nil, nil
	if dash.screen then
		local s = dash.screen
		local part = placePart("Screen", folder, mount, f, s.posM, s.rotationDeg, s.sizeM)
		clock, gear = buildScreen(s, part)
	end
	folder.Parent = model
	return { model = model, folder = folder, needles = needles, gear = gear, clock = clock, lastClock = "", lastGear = "" }
end

local function gearText(gear: number): string
	return if gear < 0 then "R" elseif gear == 0 then "N" else tostring(gear)
end

-- Each frame from the driving loop, with the car and its state.
function DashGauges.update(model: Model?, state: any)
	local current = built
	if current and (current.model ~= model or not current.folder.Parent) then
		DashGauges.detach()
		current = nil
	end
	if not model then
		return
	end
	if not current then
		current = attach(model)
		built = current
	end
	if not current then
		return
	end
	local b: Built = current
	local mph = (tonumber(state.speedKmh) or 0) / KMH_PER_MPH
	local rpm = tonumber(state.rpm) or 0
	for _, n in b.needles do
		n.holder.Rotation = CarDashes.needleDeg(n.dial, if n.dial.reads == "speedMph" then mph else rpm)
	end
	local gear = b.gear
	if gear then
		local g = gearText(tonumber(state.gear) or 0)
		if g ~= b.lastGear then
			b.lastGear = g
			gear.Text = g
		end
	end
	local clock = b.clock
	if clock then
		local t = string.sub(Lighting.TimeOfDay, 1, 5)
		if t ~= b.lastClock then
			b.lastClock = t
			clock.Text = t
		end
	end
end

return DashGauges
