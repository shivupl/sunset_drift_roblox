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
-- remembered on the first apply.
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

type Original = { part: BasePart, color: Color3, material: Enum.Material, reflectance: number, sa: SurfaceAppearance?, saColor: Color3? }

type State = {
	paint: { Original },
	rims: { Original },
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
		sa = sa,
		saColor = if sa then sa.Color else nil,
	}
end

-- The painted pieces (BodyBuilder stamps `Painted`) and the rim pieces:
-- wheel pieces named *Rim* (not a Rim_Disc, which is the brake disc behind
-- the rim), or, on a car without one, its Metal wheel pieces.
local function collect(model: Model, body: Instance, carId: string): State
	local entry = ConfigLoader.entry(carId)
	local wheelNames: { [string]: boolean } = {}
	for _, piece in entry.body.wheelPieces do
		for _, w in VehicleRig.WHEELS do
			wheelNames[`{piece.name}_{w.name}`] = true
		end
	end
	local s: State = { paint = {}, rims = {} }
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

local function darken(c: Color3, by: number): Color3
	return Color3.new(c.R * (1 - by), c.G * (1 - by), c.B * (1 - by))
end

local function paint(s: State, look: CarLook.Look)
	local colour = CarLook.item(look, "paint").color
	local finish = CarLook.item(look, "finish")
	local matte = finish.id == "finish_matte"
	for _, o in s.paint do
		local c = colour or o.color
		if o.sa then
			-- A SurfaceAppearance carries its own material maps: it takes
			-- the colour only.
			o.sa.Color = colour or (o.saColor :: Color3)
			continue
		end
		o.part.Color = if matte then darken(c, R.matteDarken) else c
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
		if s.strip then
			s.strip.part.Transparency = 1
			s.strip.frame.Visible = false
		end
		return
	end
	assert(spot)
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

local function tipOffsets(n: number, spread: number): { number }
	if n == 1 then
		return { -spread / 2 }
	elseif n == 2 then
		return { -spread / 2, spread / 2 }
	elseif n >= 4 then
		local g = R.quadPairGapM / 2
		return { -spread / 2 - g, -spread / 2 + g, spread / 2 - g, spread / 2 + g }
	end
	return {}
end

local function exhaust(s: State, model: Model, body: Instance, carId: string, look: CarLook.Look)
	if s.exhaust then
		s.exhaust:Destroy()
		s.exhaust = nil
	end
	local item = CarLook.item(look, "exhaust")
	local mounts = CarCosmeticMounts.cars[carId]
	local spot = mounts and mounts.exhaust
	local n = item.tips or 0
	if not spot or n <= 0 then
		return
	end
	local handles = VehicleRig.handles(model)
	local k = VehicleRig.scaleOf(ConfigLoader.entry(carId))
	local mps = ConfigLoader.forCar(carId).units.metersPerStud
	local folder = Instance.new("Folder")
	folder.Name = "LookExhaust"
	-- A Cylinder's axis is its X; turned a quarter about Y it runs along Z.
	local alongZ = CFrame.Angles(0, math.pi / 2, 0)
	for i, dx in tipOffsets(n, spot.spreadM) do
		local at = CarCosmeticMounts.cframe({ spot.posM[1] + dx, spot.posM[2], spot.posM[3] }, 0, k, mps)
		local tip = visualPart(`Tip{i}`, handles, at * alongZ)
		tip.Shape = Enum.PartType.Cylinder
		tip.Size = Vector3.new(R.tipLengthM, R.tipRadiusM * 2, R.tipRadiusM * 2) * (k / mps)
		tip.Color = item.tipColor or Color3.fromRGB(200, 200, 200)
		tip.Material = item.tipMaterial or Enum.Material.Metal
		tip.Parent = folder
		-- The bore: flush with the tip's open (rear, +Z) end, hidden inside
		-- it everywhere else.
		local boreAt = at * CFrame.new(0, 0, 0.002 * k / mps)
		local bore = visualPart(`Bore{i}`, handles, boreAt * alongZ)
		bore.Shape = Enum.PartType.Cylinder
		bore.Size = Vector3.new(R.tipLengthM, R.boreRadiusM * 2, R.boreRadiusM * 2) * (k / mps)
		bore.Color = R.boreColor
		bore.Material = Enum.Material.SmoothPlastic
		bore.Parent = folder
	end
	folder.Parent = body
	s.exhaust = folder
end

-- Puts this look on a car's built body. Safe to call again with a new look.
function CarCosmetics.apply(model: Model, look: CarLook.Look, carId: string)
	local body = VehicleRig.handles(model).body
	if not body then
		return
	end
	local s = states[model]
	if not s then
		s = collect(model, body, carId)
		states[model] = s
		model.Destroying:Once(function()
			states[model] = nil
		end)
	end
	assert(s)
	paint(s, look)
	rims(s, look)
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
