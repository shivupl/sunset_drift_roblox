--!strict
-- Drift feedback on the driver's client: tire smoke and skid marks driven by
-- the per-wheel state the sim already reports. Everything here is visual.
-- The physics never reads it, and it only runs for the car this client is
-- driving (other players' cars are a later phase).
--
-- Emitters and trail attachments hang off the chassis at each wheel's rest
-- contact point rather than off the wheel parts, because the wheel parts
-- spin and would carry a fixed attachment around with them.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Types = require(Shared.Types)
local ConfigLoader = require(Shared.ConfigLoader)

type VehicleState = Types.VehicleState
type WheelState = Types.WheelState

type WheelFx = {
	name: string,
	front: boolean,
	smoke: ParticleEmitter,
	trail: Trail,
}

local DriftEffects = {}

local wheels: { WheelFx } = {}
local folder: Folder? = nil

local WHEEL_DEFS = {
	{ name = "FL", front = true, x = -1, z = -1 },
	{ name = "FR", front = true, x = 1, z = -1 },
	{ name = "RL", front = false, x = -1, z = 1 },
	{ name = "RR", front = false, x = 1, z = 1 },
}

local function makeSmoke(parent: Attachment, cfg: typeof(ConfigLoader.current().effects)): ParticleEmitter
	local e = Instance.new("ParticleEmitter")
	e.Name = "Smoke"
	e.Rate = 0
	e.Lifetime = NumberRange.new(cfg.smokeLifetime * 0.7, cfg.smokeLifetime)
	e.Speed = NumberRange.new(2, 5)
	e.SpreadAngle = Vector2.new(35, 35)
	e.Rotation = NumberRange.new(0, 360)
	e.RotSpeed = NumberRange.new(-40, 40)
	e.Acceleration = Vector3.new(0, 1.5, 0)
	e.Drag = 2
	e.LightEmission = 0
	e.Color = ColorSequence.new(Color3.fromRGB(215, 215, 220), Color3.fromRGB(170, 170, 178))
	e.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.6),
		NumberSequenceKeypoint.new(0.3, cfg.smokeSize * 0.6),
		NumberSequenceKeypoint.new(1, cfg.smokeSize),
	})
	e.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.55),
		NumberSequenceKeypoint.new(0.5, 0.75),
		NumberSequenceKeypoint.new(1, 1),
	})
	e.Texture = "rbxasset://textures/particles/smoke_main.dds"
	e.Parent = parent
	return e
end

local function makeTrail(a0: Attachment, a1: Attachment, cfg: typeof(ConfigLoader.current().effects)): Trail
	local t = Instance.new("Trail")
	t.Name = "Skid"
	t.Attachment0 = a0
	t.Attachment1 = a1
	t.Enabled = false
	t.Lifetime = cfg.skidLifetime
	t.MinLength = 0.05
	t.FaceCamera = false
	t.LightEmission = 0
	t.LightInfluence = 1
	t.Color = ColorSequence.new(Color3.fromRGB(22, 22, 24))
	t.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, cfg.skidTransparency),
		NumberSequenceKeypoint.new(0.85, cfg.skidTransparency + 0.2),
		NumberSequenceKeypoint.new(1, 1),
	})
	t.WidthScale = NumberSequence.new(1)
	t.Parent = a0
	return t
end

function DriftEffects.attach(model: Model)
	DriftEffects.detach()
	local cfg = ConfigLoader.current()
	if not cfg.effects.enabled then
		return
	end
	local chassis = model.PrimaryPart :: BasePart
	local mps = cfg.units.metersPerStud
	local f = Instance.new("Folder")
	f.Name = "DriftEffects"
	f.Parent = chassis
	folder = f

	-- Rest contact height below the hardpoint: droop minus static sag, plus
	-- the wheel radius. Close enough to the road for smoke and marks.
	local staticSag = cfg.body.massKg * cfg.units.gravity / 4 / cfg.suspension.stiffness
	local contactDrop = (cfg.suspension.restLength - staticSag + cfg.body.wheelRadius) / mps
	local halfWidth = cfg.body.wheelWidth / 2 / mps

	for _, def in WHEEL_DEFS do
		local hp = chassis:FindFirstChild("Hardpoint_" .. def.name) :: Attachment
		local base = hp.Position - Vector3.new(0, contactDrop - 0.05 / mps, 0)

		local smokeAt = Instance.new("Attachment")
		smokeAt.Name = "Smoke_" .. def.name
		smokeAt.Position = base
		smokeAt.Parent = chassis

		local left = Instance.new("Attachment")
		left.Name = "SkidL_" .. def.name
		left.Position = base + Vector3.new(-halfWidth, 0, 0)
		left.Parent = chassis
		local right = Instance.new("Attachment")
		right.Name = "SkidR_" .. def.name
		right.Position = base + Vector3.new(halfWidth, 0, 0)
		right.Parent = chassis

		-- Attachments have to live on the part to follow it, so they are
		-- tagged for cleanup instead of parented under the folder.
		for _, a in { smokeAt, left, right } do
			a:SetAttribute("DriftEffect", true)
		end
		table.insert(wheels, {
			name = def.name,
			front = def.front,
			smoke = makeSmoke(smokeAt, cfg.effects),
			trail = makeTrail(left, right, cfg.effects),
		})
	end
end

function DriftEffects.update(state: VehicleState)
	if #wheels == 0 then
		return
	end
	local cfg = ConfigLoader.current().effects
	if not cfg.enabled then
		for _, w in wheels do
			w.smoke.Rate = 0
			w.trail.Enabled = false
		end
		return
	end
	for i, w in wheels do
		local ws: WheelState = state.wheels[i]
		local slip = math.abs(ws.slipAngleDeg)
		local moving = state.speedMps >= cfg.smokeMinSpeedMps
		local sliding = ws.grounded and moving and (slip >= cfg.skidSlipDeg or ws.saturated)

		-- Smoke: rear tires by slip angle or wheelspin, fronts only when locked.
		local rate = 0
		if ws.grounded and moving then
			if not w.front then
				local bySlip = math.clamp((slip - cfg.smokeSlipStartDeg) / (cfg.smokeSlipFullDeg - cfg.smokeSlipStartDeg), 0, 1)
				local bySpin = if ws.saturated and not ws.locked then 0.8 else 0
				rate = math.max(bySlip, bySpin) * cfg.smokeMaxRate
			elseif ws.locked then
				rate = 0.6 * cfg.smokeMaxRate
			end
		end
		w.smoke.Rate = rate
		w.trail.Enabled = sliding
	end
end

function DriftEffects.detach()
	for _, w in wheels do
		w.smoke.Rate = 0
		w.trail.Enabled = false
	end
	table.clear(wheels)
	if folder then
		local chassis = folder.Parent
		folder:Destroy()
		folder = nil
		if chassis then
			for _, child in chassis:GetChildren() do
				if child:IsA("Attachment") and child:GetAttribute("DriftEffect") then
					child:Destroy()
				end
			end
		end
	end
end

return DriftEffects
