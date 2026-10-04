--!strict
-- Drift feedback on the driver's client: skid marks and the screech, driven
-- by the per-wheel state the sim already reports. Everything here is visual.
-- The physics never reads it, and it only runs for the car this client is
-- driving. Tyre smoke is TireSmoke's, on every car.
--
-- Emitters and trail attachments hang off the chassis at each wheel's rest
-- contact point rather than off the hubs, because the hubs spin and would
-- carry a fixed attachment around with them.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Types = require(Shared.Types)
local ConfigLoader = require(Shared.ConfigLoader)
local VehicleRig = require(Shared.VehicleRig)

type VehicleState = Types.VehicleState
type WheelState = Types.WheelState

type WheelFx = {
	name: string,
	front: boolean,
	trail: Trail,
}

local DriftEffects = {}

local wheels: { WheelFx } = {}
local folder: Folder? = nil
local screech: Sound? = nil
local screechLevel = 0
local carId: string? = nil -- the car attached, so a car's tuning overrides apply here too

local WHEEL_DEFS = VehicleRig.WHEELS

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

local function makeSound(parent: BasePart, name: string, id: string, volume: number): Sound?
	if id == "" then
		return nil
	end
	local s = Instance.new("Sound")
	s.Name = name
	s.SoundId = id
	s.Looped = true
	s.Volume = 0
	s.RollOffMaxDistance = 120
	s.Parent = parent
	s:Play()
	return s
end

function DriftEffects.attach(model: Model)
	DriftEffects.detach()
	local id = model:GetAttribute(VehicleRig.CAR_ID_ATTRIBUTE)
	carId = if type(id) == "string" then id else nil
	local cfg = ConfigLoader.forCar(carId)
	if not cfg.effects.enabled then
		return
	end
	local rig = VehicleRig.handles(model)
	local chassis = rig.chassis
	screech = makeSound(chassis, "Screech", cfg.effects.screechSoundId, cfg.effects.screechMaxVolume)
	if screech then
		-- Take the shrill top off the skid loop.
		local eq = Instance.new("EqualizerSoundEffect")
		eq.LowGain = cfg.effects.screechEq[1]
		eq.MidGain = cfg.effects.screechEq[2]
		eq.HighGain = cfg.effects.screechEq[3]
		eq.Parent = screech
	end
	local mps = cfg.units.metersPerStud
	local f = Instance.new("Folder")
	f.Name = "DriftEffects"
	f.Parent = chassis
	folder = f

	-- Rest contact height below the hardpoint: droop minus static sag, plus
	-- the wheel radius. Close enough to the road for the marks.
	local staticSag = VehicleRig.staticSagM(cfg)
	local contactDrop = (cfg.suspension.restLength - staticSag + cfg.body.wheelRadius) / mps
	local halfWidth = cfg.body.wheelWidth / 2 / mps

	for _, def in WHEEL_DEFS do
		local hp = rig.rayOrigins[def.name]
		local base = hp.Position - Vector3.new(0, contactDrop - 0.05 / mps, 0)

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
		for _, a in { left, right } do
			a:SetAttribute("DriftEffect", true)
		end
		table.insert(wheels, {
			name = def.name,
			front = def.front,
			trail = makeTrail(left, right, cfg.effects),
		})
	end
end

function DriftEffects.update(state: VehicleState)
	if #wheels == 0 then
		return
	end
	local carCfg = ConfigLoader.forCar(carId)
	local cfg = carCfg.effects
	if not cfg.enabled then
		for _, w in wheels do
			w.trail.Enabled = false
		end
		return
	end
	for i, w in wheels do
		local ws: WheelState = state.wheels[i]
		local slip = math.abs(ws.slipAngleDeg)
		local moving = state.speedMps >= cfg.smokeMinSpeedMps
		w.trail.Enabled = ws.grounded and moving and (slip >= cfg.skidSlipDeg or ws.saturated)
	end

	-- Screech follows the louder of the two rears, smoothed so it swells and
	-- fades rather than clicking on and off.
	if screech then
		local rl, rr = state.wheels[3], state.wheels[4]
		local slip = math.max(math.abs(rl.slipAngleDeg), math.abs(rr.slipAngleDeg))
		local target = if state.speedMps >= cfg.smokeMinSpeedMps
			then math.clamp((slip - cfg.screechSlipStartDeg) / (cfg.screechSlipFullDeg - cfg.screechSlipStartDeg), 0, 1)
			else 0
		if (rl.saturated or rr.saturated) and state.speedMps >= cfg.smokeMinSpeedMps then
			target = math.max(target, cfg.screechSpinLevel)
		end
		screechLevel += (target - screechLevel) * 0.25
		screech.Volume = cfg.screechMaxVolume * screechLevel
		screech.PlaybackSpeed = cfg.screechMinPitch + (cfg.screechMaxPitch - cfg.screechMinPitch) * screechLevel
	end
end

function DriftEffects.detach()
	for _, w in wheels do
		w.trail.Enabled = false
	end
	table.clear(wheels)
	if screech then
		screech:Destroy()
		screech = nil
	end
	screechLevel = 0
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
