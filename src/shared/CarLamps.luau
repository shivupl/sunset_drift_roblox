--!strict
-- Headlights, tail and brake lights and reverse lights on a mounted body,
-- the same way on every car (tools/carbody/README.md, the body standard).
--
-- The lamp state lives in attributes on the car Model, so every client
-- shows the same lamps: the driver's client sets them locally at once and
-- sends them to the server, which copies them onto the model for everyone
-- (CarControls on both sides). Each client builds the lamps on its own copy
-- of the body (the body is visual and built per client, CarBodies) and
-- applies the attributes whenever they change (CarLights).
--
-- What lights up:
--   * pieces named HeadLamps*, TailLamps*, ReverseLamps* turn Neon in the
--     lamp's colour (their own material, colour and transparency come back
--     when off);
--   * a car listed in CarLampSpots gets thin Neon panels over lamps that
--     cannot glow (a textured mesh shows its texture whatever the material).
-- Nothing lights the ground: no beams and no brake glow (owner, 2026-09-25).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local VehicleRig = require(Shared.VehicleRig)
local ConfigLoader = require(Shared.ConfigLoader)
local CarLampSpots = require(Shared.CarLampSpots)

local CarLamps = {}

-- Attributes on the car Model.
CarLamps.HEAD = "LampHead"
CarLamps.BRAKE = "LampBrake"
CarLamps.REVERSE = "LampReverse"

local KIND_OF_PREFIX: { { string } } = { { "HeadLamps", "head" }, { "TailLamps", "tail" }, { "ReverseLamps", "reverse" } }
local LAMPS = "Lamps" -- folder in Body for the panels and lights

type Built = {
	lenses: { { part: BasePart, kind: string, color: Color3, material: Enum.Material, transparency: number } },
	panels: { { part: BasePart, kind: string } },
}

local built: { [Model]: Built } = {}

local function kindOf(name: string): string?
	for _, pair in KIND_OF_PREFIX do
		if string.sub(name, 1, #pair[1]) == pair[1] then
			return pair[2]
		end
	end
	return nil
end

local function weldTo(part: BasePart, to: BasePart)
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = to
	weld.Part1 = part
	weld.Parent = part
end

-- Builds the lamps on a car whose body is mounted. Safe to call again.
function CarLamps.build(model: Model): boolean
	if built[model] then
		return true
	end
	local ok, handles = pcall(VehicleRig.handles, model)
	if not ok then
		return false
	end
	local body = model:FindFirstChild(VehicleRig.BODY)
	if not body then
		return false
	end
	local carId = handles.carId
	local cfg = ConfigLoader.forCar(carId)
	local entry = ConfigLoader.entry(carId)
	local k = VehicleRig.scaleOf(entry)
	local mps = cfg.units.metersPerStud
	local origin = handles.bodyMount.WorldCFrame
	local chassis = handles.chassis

	local b: Built = { lenses = {}, panels = {} }
	local folder = Instance.new("Folder")
	folder.Name = LAMPS

	-- Lens pieces.
	for _, part in body:GetChildren() do
		if part:IsA("BasePart") then
			local kind = kindOf(part.Name)
			if kind then
				table.insert(b.lenses, { part = part, kind = kind, color = part.Color, material = part.Material, transparency = part.Transparency })
			end
		end
	end

	-- Glow panels for lamps that cannot glow (CarLampSpots).
	local spots = CarLampSpots[ConfigLoader.resolveCarId(carId)]
	if spots then
		for kindKey, list in spots :: any do
			local kind: string = tostring(kindKey)
			for _, spot in list :: { CarLampSpots.Spot } do
				local p = Vector3.new(spot.pos[1], spot.pos[2], spot.pos[3]) * (k / mps)
				local front = spot.pos[3] < 0
				local panel = Instance.new("Part")
				panel.Name = `{kind}Panel`
				panel.Size = Vector3.new(spot.size[1] * k / mps, spot.size[2] * k / mps, 0.02)
				panel.CFrame = origin * CFrame.new(p) * (if front then CFrame.identity else CFrame.Angles(0, math.pi, 0))
				panel.Material = Enum.Material.Neon
				panel.Transparency = 1
				panel.CastShadow = false
				panel.CanCollide, panel.CanQuery, panel.CanTouch = false, false, false
				panel.Massless = true
				panel.Anchored = false
				weldTo(panel, chassis)
				panel.Parent = folder
				table.insert(b.panels, { part = panel :: BasePart, kind = kind })
			end
		end
	end

	folder.Parent = body
	built[model] = b
	model.Destroying:Once(function()
		built[model] = nil
	end)
	CarLamps.apply(model)
	return true
end

-- Shows the lamp attributes on this client's copy of the body.
function CarLamps.apply(model: Model)
	local b = built[model]
	if not b then
		return
	end
	local lampsCfg = ConfigLoader.forCar(model:GetAttribute(VehicleRig.CAR_ID_ATTRIBUTE) :: string?).effects.lamps
	local head = model:GetAttribute(CarLamps.HEAD) == true
	local brake = model:GetAttribute(CarLamps.BRAKE) == true
	local reverse = model:GetAttribute(CarLamps.REVERSE) == true
	local function look(kind: string): (boolean, Color3)
		if kind == "head" then
			return head, lampsCfg.headColor
		elseif kind == "tail" then
			return head or brake, if brake then lampsCfg.brakeColor else lampsCfg.tailColor
		else
			return reverse, lampsCfg.reverseColor
		end
	end
	for _, lens in b.lenses do
		if lens.part.Parent then
			local on, color = look(lens.kind)
			lens.part.Material = if on then Enum.Material.Neon else lens.material
			lens.part.Color = if on then color else lens.color
			lens.part.Transparency = if on then math.min(lens.transparency, 0.2) else lens.transparency
		end
	end
	for _, panel in b.panels do
		local on, color = look(panel.kind)
		panel.part.Transparency = if on then 0 else 1
		panel.part.Color = color
	end
end

return CarLamps
