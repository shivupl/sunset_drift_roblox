--!strict
-- The driver's arms in first person, hands on the wheel (the owner,
-- 2026-11-07: "can u try make it so that the characters arms also show?
-- maybe as an experiment"). Branch first-person-arms.
--
-- The avatar itself sits 0.1 to 0.4 m ahead of and below the first-person
-- eye (Roblox avatars are small beside these cars), so its own shoulders
-- would float in front of the camera. These are copies of its arm parts
-- instead, in a model with a Humanoid, its Shirt and its BodyColors so they
-- wear its colours and sleeves, parented to the camera so only this client
-- draws them. Each frame (CameraRig) every arm reaches from a shoulder under
-- the eye to its grip on the rim with a two-bone bend: the elbow drops and
-- swings out, the wrist stays straight. The grips turn with the wheel up to
-- arms.followDeg (past every wheel turn, so the hands hold on and the arms
-- cross over).
--
-- Settings: camera.firstPerson.arms; on or off in SETTINGS (ARMS), the
-- LocalPlayer attribute FirstPersonArms.
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local ConfigLoader = require(Shared:WaitForChild("ConfigLoader"))
local CarCockpits = require(Shared:WaitForChild("CarCockpits"))

local CockpitArms = {}

local ATTRIBUTE = "FirstPersonArms"
CockpitArms.ATTRIBUTE = ATTRIBUTE

function CockpitArms.on(): boolean
	return Players.LocalPlayer:GetAttribute(ATTRIBUTE) ~= false
end

function CockpitArms.set(on: boolean)
	Players.LocalPlayer:SetAttribute(ATTRIBUTE, on)
end

type Arm = { upper: BasePart, lower: BasePart?, hand: BasePart?, side: number }
type Built = { character: Model, model: Model, arms: { Arm }, widthScale: { [BasePart]: Vector3 } }

local built: Built? = nil

local R15 = {
	{ side = -1, names = { "LeftUpperArm", "LeftLowerArm", "LeftHand" } },
	{ side = 1, names = { "RightUpperArm", "RightLowerArm", "RightHand" } },
}
local R6 = {
	{ side = -1, names = { "Left Arm" } },
	{ side = 1, names = { "Right Arm" } },
}

-- A body part copied to draw only: no joints, no physics.
local function copyPart(source: BasePart): BasePart
	local was = source.Archivable
	source.Archivable = true
	local part = source:Clone()
	source.Archivable = was
	for _, d in part:GetChildren() do
		if not (d:IsA("SurfaceAppearance") or d:IsA("Decal") or d:IsA("SpecialMesh")) then
			d:Destroy()
		end
	end
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Massless = true
	part.Transparency = 0
	part.LocalTransparencyModifier = 0
	return part
end

local function build(character: Model): Built?
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return nil
	end
	local model = Instance.new("Model")
	model.Name = "FirstPersonArms"
	local h = Instance.new("Humanoid")
	h.RigType = humanoid.RigType
	h.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	h.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	h.Parent = model
	for _, d in character:GetChildren() do
		if d:IsA("Shirt") or d:IsA("BodyColors") then
			local item = d :: Instance
			local was = item.Archivable
			item.Archivable = true
			item:Clone().Parent = model
			item.Archivable = was
		end
	end
	local arms: { Arm } = {}
	local sizes: { [BasePart]: Vector3 } = {}
	local specs: { { side: number, names: { string } } } = if humanoid.RigType == Enum.HumanoidRigType.R15 then R15 else R6
	for _, spec in specs do
		local parts: { BasePart } = {}
		for _, name in spec.names do
			local source = character:FindFirstChild(name)
			if not source or not source:IsA("BasePart") then
				break
			end
			local part = copyPart(source)
			sizes[part] = source.Size
			part.Parent = model
			table.insert(parts, part)
		end
		if #parts == #spec.names then
			table.insert(arms, { upper = parts[1], lower = parts[2], hand = parts[3], side = spec.side })
		end
	end
	if #arms == 0 then
		model:Destroy()
		return nil
	end
	return { character = character, model = model, arms = arms, widthScale = sizes }
end

-- Puts a limb part between two points: its +Y (toward the shoulder on an
-- avatar's arm) along end -> start, its length `len`, its width scaled.
local function place(part: BasePart, from: Vector3, to: Vector3, len: number, width: number, original: Vector3, rightHint: Vector3)
	local d = from - to
	local up = if d.Magnitude > 1e-4 then d.Unit else Vector3.yAxis
	local r = rightHint - up * rightHint:Dot(up)
	r = if r.Magnitude > 1e-4 then r.Unit else up:Cross(Vector3.zAxis).Unit
	part.Size = Vector3.new(original.X * width, len, original.Z * width)
	part.CFrame = CFrame.fromMatrix(from - up * (len / 2), r, up)
end

function CockpitArms.hide()
	if built and built.model.Parent then
		built.model.Parent = nil
	end
end

-- Poses the arms for this frame. eyeBase: the eye with the cabin's
-- rotation (not the head's), mount: the car's body mount, f: studs per car
-- metre, wheelDeg: the wheel's turn.
function CockpitArms.update(carId: string?, eyeBase: CFrame, mount: CFrame, f: number, wheelDeg: number)
	local cockpit = CarCockpits.of(carId)
	local wheel = cockpit and cockpit.wheel
	local character = Players.LocalPlayer.Character
	if not wheel or not character or not CockpitArms.on() then
		CockpitArms.hide()
		return
	end
	if not built or built.character ~= character then
		if built then
			built.model:Destroy()
		end
		built = build(character)
	end
	local b = built
	if not b then
		return
	end
	local cfg = ConfigLoader.current().camera.firstPerson.arms
	local carUp, carRight = mount.UpVector, mount.RightVector
	local p, a = wheel.pivotM, wheel.axis
	local pivot = mount * Vector3.new(p[1] * f, p[2] * f, p[3] * f)
	local axis = mount:VectorToWorldSpace(Vector3.new(a[1], a[2], a[3]).Unit)
	local up = (carUp - axis * carUp:Dot(axis)).Unit
	local right = up:Cross(axis)
	local radius = wheel.radiusM * f
	local turn = math.clamp(wheelDeg, -cfg.followDeg, cfg.followDeg)

	local upperLen, foreLen, handLen = cfg.upperArmM * f, cfg.forearmM * f, cfg.handM * f
	for _, arm in b.arms do
		-- Ten to two, turned with the wheel (clockwise as the driver sees
		-- it is + about the top, toward the right).
		local theta = math.rad(arm.side * cfg.gripDeg + turn)
		local grip = pivot + (up * math.cos(theta) + right * math.sin(theta)) * radius
		local s = cfg.shoulderM
		local shoulder = eyeBase * Vector3.new(arm.side * s[1] * f, s[2] * f, s[3] * f)
		local side = carRight * arm.side
		local lower, hand = arm.lower, arm.hand
		if not lower or not hand then
			-- R6: one straight arm to the grip.
			local len = (grip - shoulder).Magnitude
			place(arm.upper, shoulder, grip, len, cfg.thickness, b.widthScale[arm.upper], carRight)
			continue
		end
		local width = foreLen / b.widthScale[lower].Y * cfg.thickness
		local la, lb = upperLen, foreLen + handLen
		local toGrip = grip - shoulder
		local d = math.clamp(toGrip.Magnitude, math.abs(la - lb) + 1e-3, la + lb - 1e-3)
		local dir = toGrip.Unit
		local cosA = math.clamp((la * la + d * d - lb * lb) / (2 * la * d), -1, 1)
		local sinA = math.sqrt(1 - cosA * cosA)
		-- The elbow drops and swings out.
		local hint = -carUp + side * 0.6
		local perp = hint - dir * hint:Dot(dir)
		perp = if perp.Magnitude > 1e-4 then perp.Unit else -carUp
		local elbow = shoulder + dir * (la * cosA) + perp * (la * sinA)
		local toHand = grip - elbow
		local fdir = if toHand.Magnitude > 1e-4 then toHand.Unit else dir
		local wrist = elbow + fdir * foreLen
		local palm = wrist + fdir * handLen
		place(arm.upper, shoulder, elbow, la, width, b.widthScale[arm.upper], carRight)
		place(lower, elbow, wrist, foreLen, width, b.widthScale[lower], carRight)
		place(hand, wrist, palm, handLen, width, b.widthScale[hand], carRight)
	end
	local camera = Workspace.CurrentCamera
	if camera and b.model.Parent ~= camera then
		b.model.Parent = camera
	end
end

return CockpitArms
