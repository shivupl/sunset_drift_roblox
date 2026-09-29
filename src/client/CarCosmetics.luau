--!strict
-- A car's garage look on this client's copy of its body (garage spec §4-5):
-- paint and finish on the painted pieces, a rim finish, head and tail lamp
-- colours, a windscreen strip and exhaust tips. The server stamps the look
-- on the car Model's `Look` attribute (CarLook); watch() applies it now and
-- on every change, so a change shows on every client without a respawn.
-- apply() also serves the garage's client-only preview car.
--
-- Everything here is visual: the strip and tips are massless, non-colliding,
-- unqueryable parts welded to the chassis, like the plates (CarPlates).
-- Stock in every slot puts back what BodyBuilder built: the originals are
-- remembered on the first apply to a body, and again whenever the model gets
-- a new body or car id (the garage preview re-mounts on the same model).
--
-- The exhaust follows one standard on every car (CarCosmeticMounts, garage
-- round 2 §1): the car's own pipes or a built factory one, or aftermarket
-- tips on pipes running forward into the body; either way an ExhaustOutlet
-- Attachment at each mouth of the exhaust fitted (only the tips once tips
-- are on), LookVector out of the pipe (outlets()).
--
-- Paint and finish need `paint = true` body pieces. The pickup and cruiser
-- are single textured shells with none, so paint does nothing on them;
-- paintable() tells the garage panel to grey those out. Owner follow-up:
-- a paint split of those shells in CarCatalog (garage plan, task 3 fix 1).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local VehicleRig = require(Shared:WaitForChild("VehicleRig"))
local ConfigLoader = require(Shared:WaitForChild("ConfigLoader"))
local CarLook = require(Shared:WaitForChild("CarLook"))
local CarLamps = require(Shared:WaitForChild("CarLamps"))
local CarCosmeticMounts = require(Shared:WaitForChild("CarCosmeticMounts"))
local UITheme = require(Shared:WaitForChild("UITheme"))
local CosmeticsConfig = require(Shared:WaitForChild("CosmeticsConfig"))

local CarCosmetics = {}

local R = CosmeticsConfig.render

-- The exhaust outlets' names (outlets()): the flame contract.
local OUTLET = "ExhaustOutlet"
local OUTLETS = "ExhaustOutlets"

type Original = { part: BasePart, color: Color3, material: Enum.Material, reflectance: number, transparency: number, sa: SurfaceAppearance?, saColor: Color3? }
-- A window piece and its role (CarCosmeticMounts windows).
type WindowRole = "side" | "screen" | "whole"
type Window = { o: Original, role: WindowRole }

type State = {
	body: Instance,
	carId: string,
	paint: { Original },
	rims: { Original },
	windows: { Window },
	strip: { part: Part, frame: Frame, gradient: UIGradient, label: TextLabel }?,
	exhaust: Folder?,
}

local states: { [Model]: State } = {}
local watching: { [Model]: RBXScriptConnection } = {}

local function remember(part: BasePart): Original
	local sa = part:FindFirstChildOfClass("SurfaceAppearance")
	return {
		part = part,
		color = part.Color,
		material = part.Material,
		reflectance = part.Reflectance,
		transparency = part.Transparency,
		sa = sa,
		saColor = if sa then sa.Color else nil,
	}
end

-- The painted pieces (BodyBuilder stamps `Painted`) and the rim pieces:
-- wheel pieces named *Rim* (not a Rim_Disc, which is the brake disc behind
-- the rim), or, on a car without one, its Metal wheel pieces.
local function collect(body: Instance, carId: string): State
	local entry = ConfigLoader.entry(carId)
	local wheelNames: { [string]: boolean } = {}
	for _, piece in entry.body.wheelPieces do
		for _, w in VehicleRig.WHEELS do
			wheelNames[`{piece.name}_{w.name}`] = true
		end
	end
	local s: State = { body = body, carId = carId, paint = {}, rims = {}, windows = {} }
	local mounts = CarCosmeticMounts.cars[carId]
	local windows = mounts and mounts.windows
	local function addWindows(names: { string }?, role: WindowRole)
		if not names then
			return
		end
		for _, name in names do
			local part = body:FindFirstChild(name)
			if part and part:IsA("BasePart") then
				table.insert(s.windows, { o = remember(part), role = role })
			end
		end
	end
	if windows then
		addWindows(windows.side, "side")
		addWindows(windows.screen, "screen")
		addWindows(windows.whole, "whole")
	end
	local metal: { Original } = {}
	for _, part in body:GetChildren() do
		if not part:IsA("BasePart") then
			continue
		end
		if part:GetAttribute("Painted") == true then
			table.insert(s.paint, remember(part))
		elseif wheelNames[part.Name] then
			local lower = string.lower(part.Name)
			if string.find(lower, "rim", 1, true) and not string.find(lower, "disc", 1, true) then
				table.insert(s.rims, remember(part))
			elseif part.Material == Enum.Material.Metal then
				table.insert(metal, remember(part))
			end
		end
	end
	if #s.rims == 0 then
		s.rims = metal
	end
	return s
end

-- A finish's colour treatment (CosmeticsConfig FINISH): value and
-- saturation lowered by its darken and desaturate.
local function treat(c: Color3, finish: CosmeticsConfig.Item): Color3
	if not finish.darken and not finish.desaturate then
		return c
	end
	local h, s, v = c:ToHSV()
	return Color3.fromHSV(h, s * (1 - (finish.desaturate or 0)), v * (1 - (finish.darken or 0)))
end

local function paint(s: State, look: CarLook.Look)
	local colour = CarLook.item(look, "paint").color
	local finish = CarLook.item(look, "finish")
	for _, o in s.paint do
		local c = colour or o.color
		if o.sa then
			-- A SurfaceAppearance carries its own material maps: it takes
			-- the colour only.
			o.sa.Color = colour or (o.saColor :: Color3)
			continue
		end
		o.part.Color = treat(c, finish)
		o.part.Material = finish.material or o.material
		o.part.Reflectance = if finish.material then finish.reflectance or 0 else o.reflectance
	end
end

local function rims(s: State, look: CarLook.Look)
	local item = CarLook.item(look, "rims")
	for _, o in s.rims do
		if o.sa then
			o.sa.Color = item.color or (o.saColor :: Color3)
			continue
		end
		o.part.Color = item.color or o.color
		o.part.Material = item.material or o.material
		o.part.Reflectance = if item.material then item.reflectance or 0 else o.reflectance
	end
end

-- Window tint (CosmeticsConfig TINT): the film's colour on SmoothPlastic, at
-- its transparency for the piece's role; an all-round piece takes halfway
-- between the side and windscreen values. SmoothPlastic whatever the
-- factory glass was: a Glass-material piece reads by its colour (the
-- krownvik's is white at 0.3 and looks clear), so a dark film on Glass went
-- pitch black at the same transparency (lab check, 2026-09-28). Stock puts
-- every piece back as it was built.
local function tint(s: State, look: CarLook.Look)
	local item = CarLook.item(look, "tint")
	local side, screen = item.glassTransparency, item.screenTransparency
	for _, w in s.windows do
		local o = w.o
		if o.sa then
			-- A SurfaceAppearance piece keeps its own maps; tint would not read
			-- on it. CarCosmeticMounts.spec keeps such pieces out of windows.
			continue
		end
		if item.glassColor and side and screen then
			o.part.Color = item.glassColor
			o.part.Material = Enum.Material.SmoothPlastic
			o.part.Transparency = if w.role == "side" then side elseif w.role == "screen" then screen else (side + screen) / 2
		else
			o.part.Color = o.color
			o.part.Material = o.material
			o.part.Transparency = o.transparency
		end
	end
end

local function lamps(model: Model, look: CarLook.Look)
	model:SetAttribute(CarLamps.LOOK_HEAD, CarLook.item(look, "head").color)
	model:SetAttribute(CarLamps.LOOK_TAIL, CarLook.item(look, "tail").color)
	CarLamps.apply(model)
end

-- A part that is only ever seen: welded to the chassis at the body mount
-- plus this offset, and nothing to the physics.
local function visualPart(name: string, handles: VehicleRig.Handles, offset: CFrame): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = false
	part.Massless = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.EnableFluidForces = false
	part.CastShadow = false
	part.CFrame = handles.bodyMount.WorldCFrame * offset
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = handles.chassis
	weld.Part1 = part
	weld.Parent = part
	return part
end

local function strip(s: State, model: Model, body: Instance, carId: string, look: CarLook.Look)
	local item = CarLook.item(look, "decal")
	local mounts = CarCosmeticMounts.cars[carId]
	local spot = mounts and mounts.windscreen
	local show = spot ~= nil and item.stripColor ~= nil
	if not show then
		-- None means none: the card goes, and is built again when a strip is.
		if s.strip then
			s.strip.part:Destroy()
			s.strip = nil
		end
		return
	end
	assert(spot)
	if s.strip and s.strip.part.Parent ~= body then
		s.strip = nil -- destroyed with its body or by someone else
	end
	if not s.strip then
		local handles = VehicleRig.handles(model)
		local k = VehicleRig.scaleOf(ConfigLoader.entry(carId))
		local mps = ConfigLoader.forCar(carId).units.metersPerStud
		local part = visualPart("LookStrip", handles, CarCosmeticMounts.cframe(spot.posM, spot.tiltDeg, k, mps))
		part.Size = Vector3.new(spot.widthM, spot.heightM, R.stripThicknessM) * (k / mps)
		-- Opaque, in the strip's colour: a SurfaceGui on a fully transparent
		-- part behind the (transparent) windscreen does not draw at all.
		part.Material = Enum.Material.SmoothPlastic
		local gui = Instance.new("SurfaceGui")
		-- The Front face (-Z) looks forward out through the glass: read from
		-- in front of the car.
		gui.Face = Enum.NormalId.Front
		gui.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
		gui.CanvasSize = Vector2.new(spot.widthM, spot.heightM) * R.stripPixelsPerM
		gui.LightInfluence = 1 -- lit like the car, not glowing at night
		gui.MaxDistance = R.stripDrawStuds
		gui.Parent = part
		local frame = Instance.new("Frame")
		frame.Size = UDim2.fromScale(1, 1)
		frame.BorderSizePixel = 0
		frame.Parent = gui
		local gradient = Instance.new("UIGradient")
		gradient.Parent = frame
		local label = Instance.new("TextLabel")
		label.BackgroundTransparency = 1
		label.AnchorPoint = Vector2.new(0.5, 0.5)
		label.Position = UDim2.fromScale(0.5, 0.5)
		label.Size = UDim2.fromScale(0.92, 0.8)
		label.TextScaled = true
		label.FontFace = UITheme.font("display")
		label.Parent = frame
		part.Parent = body
		s.strip = { part = part, frame = frame, gradient = gradient, label = label }
	end
	local st = s.strip :: any
	local c1 = item.stripColor :: Color3
	st.part.Transparency = 0
	st.part.Color = c1
	st.frame.Visible = true
	st.frame.BackgroundColor3 = Color3.new(1, 1, 1)
	st.gradient.Color = ColorSequence.new(c1, item.stripColor2 or c1)
	st.label.Text = item.text or ""
	st.label.TextColor3 = item.textColor or Color3.new(1, 1, 1)
	st.label.Visible = (item.text or "") ~= ""
end

-- A pipe or tip: a cylinder along the car's Z (a Cylinder's axis is its X;
-- turned a quarter about Y it runs along Z), centred at `at` (car metres),
-- `length` long. s is studs per car metre.
local ALONG_Z = CFrame.Angles(0, math.pi / 2, 0)
local function cylinder(name: string, handles: VehicleRig.Handles, s: number, at: Vector3, length: number, radius: number): Part
	local part = visualPart(name, handles, CFrame.new(at * s) * ALONG_Z)
	part.Shape = Enum.PartType.Cylinder
	part.Size = Vector3.new(length, radius * 2, radius * 2) * s
	return part
end

-- The dark bore of a pipe whose open end is at z: as long as the pipe's
-- visible length, flush with (2 mm past) its open end, hidden inside it
-- everywhere else, so the mouth reads as a hole.
local function bore(name: string, handles: VehicleRig.Handles, s: number, x: number, y: number, z: number, length: number, radius: number): Part
	local part = cylinder(name, handles, s, Vector3.new(x, y, z + 0.002 - length / 2), length, radius)
	part.Color = R.boreColor
	part.Material = Enum.Material.SmoothPlastic
	return part
end

-- The exhaust fitted to the car (garage round 2 §1, the exhaust standard):
-- stock (no tips) builds a plain pipe at each stock outlet whose body has
-- none (factory = true) and leaves the car's own pipes be; tips build each
-- tip, its bore and the pipe it sits on, running forward under the car (a
-- tip over one of the car's own pipes hides that pipe's mouth inside it).
-- One ExhaustOutlet Attachment goes at each mouth of the exhaust fitted: the
-- stock outlets, or with tips on only the tips (they replace the whole
-- exhaust; an own pipe left showing, like the hatch's, gets none)
-- (CarCosmeticMounts.outletFrames), on an invisible part welded at the body
-- mount: flames and any other exhaust effect use only those (outlets()).
local function exhaust(s: State, model: Model, body: Instance, carId: string, look: CarLook.Look)
	if s.exhaust then
		s.exhaust:Destroy()
		s.exhaust = nil
	end
	local item = CarLook.item(look, "exhaust")
	local mounts = CarCosmeticMounts.cars[carId]
	local spot = mounts and mounts.exhaust
	if not spot then
		return
	end
	local n = item.tips or 0
	local handles = VehicleRig.handles(model)
	local k = VehicleRig.scaleOf(ConfigLoader.entry(carId))
	local mps = ConfigLoader.forCar(carId).units.metersPerStud
	local sc = k / mps
	local folder = Instance.new("Folder")
	folder.Name = "LookExhaust"
	if n > 0 then
		local tips = spot.tips
		for i, mouth in CarCosmeticMounts.tipMouths(spot, n, R.quadPairGapM) do
			local x, y, mouthZ = mouth.X, mouth.Y, mouth.Z
			local frontZ = mouthZ - R.tipLengthM
			local tip = cylinder(`Tip{i}`, handles, sc, Vector3.new(x, y, mouthZ - R.tipLengthM / 2), R.tipLengthM, R.tipRadiusM)
			tip.Color = item.tipColor or Color3.fromRGB(200, 200, 200)
			tip.Material = item.tipMaterial or Enum.Material.Metal
			tip.Parent = folder
			bore(`Bore{i}`, handles, sc, x, y, mouthZ, R.tipLengthM, R.boreRadiusM).Parent = folder
			-- The pipe: from pipeOverlapM inside the tip's front end forward
			-- pipeLengthM, into the body or the car's own muffler.
			local len = tips.pipeLengthM + R.pipeOverlapM
			local pipe = cylinder(`Pipe{i}`, handles, sc, Vector3.new(x, y, frontZ + R.pipeOverlapM - len / 2), len, R.pipeRadiusM)
			pipe.Color = R.pipeColor
			pipe.Material = Enum.Material.Metal
			pipe.Parent = folder
		end
	else
		for i, o in spot.stock do
			if not o.factory then
				continue
			end
			local x, y, z = o.posM[1], o.posM[2], o.posM[3]
			local len = o.pipeLengthM or spot.tips.pipeLengthM
			local pipe = cylinder(`FactoryPipe{i}`, handles, sc, Vector3.new(x, y, z - len / 2), len, R.factoryPipeRadiusM)
			pipe.Color = R.factoryPipeColor
			pipe.Material = Enum.Material.Metal
			pipe.Parent = folder
			bore(`FactoryBore{i}`, handles, sc, x, y, z, len, R.factoryBoreRadiusM).Parent = folder
		end
	end
	-- The outlets' holder: invisible, at the body mount, so each outlet's
	-- CFrame is its car-space frame in studs.
	local holder = visualPart(OUTLETS, handles, CFrame.identity)
	holder.Size = Vector3.one * 0.05
	holder.Transparency = 1
	for _, frame in CarCosmeticMounts.outletFrames(spot, n, R.quadPairGapM) do
		local a = Instance.new("Attachment")
		a.Name = OUTLET
		a.CFrame = CarCosmeticMounts.toStuds(frame, k, mps)
		a.Parent = holder
	end
	holder.Parent = folder
	folder.Parent = body
	s.exhaust = folder
end

-- The car's exhaust outlets, for flames and any other exhaust effect: one
-- Attachment per pipe mouth of the exhaust fitted now (stock or tips), at the
-- centre of the mouth. Orientation convention: WorldCFrame.LookVector (the
-- attachment's -Z, Enum.NormalId.Front) points out of the pipe, the way the
-- gas leaves, following the pipe (straight back for tips, the stock pipe's
-- own angle where it has one); UpVector is as near car-up as that allows. A
-- ParticleEmitter under one with EmissionDirection = Front shoots out of the
-- pipe. Rebuilt (new instances) whenever the look changes; empty on a car
-- with no built body or no exhaust spot.
function CarCosmetics.outlets(model: Model): { Attachment }
	local out: { Attachment } = {}
	local ok, handles = pcall(VehicleRig.handles, model)
	local body = if ok then handles.body else nil
	local folder = body and body:FindFirstChild("LookExhaust")
	local holder = folder and folder:FindFirstChild(OUTLETS)
	if not holder then
		return out
	end
	for _, a in holder:GetChildren() do
		if a:IsA("Attachment") and a.Name == OUTLET then
			table.insert(out, a)
		end
	end
	return out
end

-- Whether paint and finish show on this car: its body has a painted piece.
function CarCosmetics.paintable(carId: string): boolean
	for _, piece in ConfigLoader.entry(carId).body.pieces do
		if piece.paint then
			return true
		end
	end
	return false
end

-- Whether this car has a spot for a windscreen strip, exhaust tips or
-- window tint (CarCosmeticMounts); the garage panel greys DECALS / EXHAUST /
-- TINT items out on a car without one, like paint on a car with no painted
-- piece. Every catalog car has a strip and exhaust spot
-- (CarCosmeticMounts.spec); the hatch, pickup and cruiser have no windows
-- tint can show on.
function CarCosmetics.hasSpot(carId: string, spot: "windscreen" | "exhaust" | "windows"): boolean
	local mounts = CarCosmeticMounts.cars[carId]
	if not mounts then
		return false
	end
	if spot == "windscreen" then
		return mounts.windscreen ~= nil
	elseif spot == "exhaust" then
		return mounts.exhaust ~= nil
	end
	return mounts.windows ~= nil
end

-- Puts this look on a car's built body. Safe to call again with a new look.
function CarCosmetics.apply(model: Model, look: CarLook.Look, carId: string)
	local body = VehicleRig.handles(model).body
	if not body then
		return
	end
	local s: State? = states[model]
	if s and (s.body ~= body or s.carId ~= carId or not s.body.Parent) then
		-- A new body (or car) on the same model: the remembered pieces and the
		-- built strip and tips belong to the old one.
		if s.strip then
			s.strip.part:Destroy()
		end
		if s.exhaust then
			s.exhaust:Destroy()
		end
		s = nil
	end
	if not s then
		if not states[model] then
			model.Destroying:Once(function()
				states[model] = nil
			end)
		end
		s = collect(body, carId)
		states[model] = s
	end
	assert(s)
	paint(s, look)
	rims(s, look)
	tint(s, look)
	lamps(model, look)
	strip(s, model, body, carId, look)
	exhaust(s, model, body, carId, look)
end

-- Applies the model's Look attribute now and whenever it changes.
function CarCosmetics.watch(model: Model)
	if watching[model] then
		return
	end
	local function update()
		local id = model:GetAttribute(VehicleRig.CAR_ID_ATTRIBUTE)
		if type(id) ~= "string" then
			return
		end
		local look = CarLook.decode(model:GetAttribute(CarLook.ATTRIBUTE))
		local ok, err = pcall(function()
			CarCosmetics.apply(model, look, id)
		end)
		if not ok then
			warn(`[CarCosmetics] {model.Name} ({id}): {err}`)
		end
	end
	watching[model] = model:GetAttributeChangedSignal(CarLook.ATTRIBUTE):Connect(update)
	model.Destroying:Once(function()
		local c = watching[model]
		if c then
			c:Disconnect()
			watching[model] = nil
		end
	end)
	update()
end

return CarCosmetics
