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
--   * a textured lamp piece (the Kruzer 80's lenses carry photos of its
--     lamps) drops its texture while lit, since a textured mesh shows its
--     texture whatever the material, and gets it back when off. No overlays:
--     the car's own lenses light (owner, 2026-09-25).
-- Nothing lights the ground: no beams and no brake glow (owner, 2026-09-25).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local VehicleRig = require(Shared.VehicleRig)
local ConfigLoader = require(Shared.ConfigLoader)

local CarLamps = {}

-- Attributes on the car Model.
CarLamps.HEAD = "LampHead"
CarLamps.BRAKE = "LampBrake"
CarLamps.REVERSE = "LampReverse"

local KIND_OF_PREFIX: { { string } } = { { "HeadLamps", "head" }, { "TailLamps", "tail" }, { "ReverseLamps", "reverse" } }

type Built = {
	lenses: { { part: BasePart, kind: string, color: Color3, material: Enum.Material, transparency: number, texture: string? } },
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

-- Builds the lamps on a car whose body is mounted. Safe to call again.
function CarLamps.build(model: Model): boolean
	if built[model] then
		return true
	end
	local ok = pcall(VehicleRig.handles, model)
	if not ok then
		return false
	end
	local body = model:FindFirstChild(VehicleRig.BODY)
	if not body then
		return false
	end
	local b: Built = { lenses = {} }

	-- Lens pieces.
	for _, part in body:GetChildren() do
		if part:IsA("BasePart") then
			local kind = kindOf(part.Name)
			if kind then
				local texture = if part:IsA("MeshPart") and part.TextureID ~= "" then part.TextureID else nil
				table.insert(b.lenses, { part = part, kind = kind, color = part.Color, material = part.Material, transparency = part.Transparency, texture = texture })
			end
		end
	end

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
			if lens.texture then
				(lens.part :: MeshPart).TextureID = if on then "" else lens.texture
			end
		end
	end
end

return CarLamps
