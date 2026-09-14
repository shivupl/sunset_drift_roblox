--!strict
-- Exhaust bangs and flame for the driver's car: the anti-lag / 2-step sound
-- of a drift car. Unburnt fuel lighting off in a hot exhaust gives a burst
-- of sharp pops and a lick of flame. Here a clutch kick fires a burst, a
-- held kick keeps popping at the limiter, and lifting off from high revs
-- crackles on the overrun. Sounds and numbers are CarConfig.kick.
--
-- Visual and audio only; driven from DriftEffects with the sim's state.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Types = require(Shared.Types)
local CarConfig = require(Shared.CarConfig)

type VehicleState = Types.VehicleState
type Config = CarConfig.Config

local Exhaust = {}

local POOL = 6

local tip: Attachment? = nil
local flame: ParticleEmitter? = nil
local glow: PointLight? = nil
local sounds: { Sound } = {}
local nextSound = 1
local queue: { number } = {} -- os.clock() times still to pop
local lastKickCount = 0
local lastThrottle = 0
local holdCarry = 0
local lastUpdate = 0
local rng = Random.new()

function Exhaust.attach(chassis: BasePart, cfg: Config, kickCount: number)
	Exhaust.detach()
	local mps = cfg.units.metersPerStud
	local b = cfg.body
	-- Legacy bodySize is length, height, width. The pipe exits under the
	-- rear bumper on the left, pointing back (+Z).
	local a = Instance.new("Attachment")
	a.Name = "ExhaustTip"
	a.Position = Vector3.new(-b.bodySize[3] * 0.25, -b.bodySize[2] / 2 + 0.12 * (b.wheelRadius / 0.33), b.bodySize[1] / 2) / mps
	a:SetAttribute("DriftEffect", true)
	a.Parent = chassis
	tip = a

	if cfg.kick.flame then
		local p = Instance.new("ParticleEmitter")
		p.Name = "ExhaustFlame"
		p.Texture = "rbxasset://textures/particles/fire_main.dds"
		p.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(150, 190, 255)),
			ColorSequenceKeypoint.new(0.25, Color3.fromRGB(255, 190, 90)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 70, 20)),
		})
		p.LightEmission = 1
		p.LightInfluence = 0
		local s = 0.35 / mps
		p.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, s * 0.5), NumberSequenceKeypoint.new(0.3, s), NumberSequenceKeypoint.new(1, s * 0.2) })
		p.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 1) })
		p.Lifetime = NumberRange.new(0.06, 0.14)
		p.Speed = NumberRange.new(4 / mps, 8 / mps)
		p.SpreadAngle = Vector2.new(12, 12)
		p.EmissionDirection = Enum.NormalId.Back
		p.Rate = 0
		p.Parent = a
		flame = p
		local l = Instance.new("PointLight")
		l.Color = Color3.fromRGB(255, 150, 60)
		l.Range = 3 / mps
		l.Brightness = 0
		l.Shadows = false
		l.Parent = a
		glow = l
	end

	for i = 1, POOL do
		local snd = Instance.new("Sound")
		snd.Name = "Pop" .. i
		snd.RollOffMaxDistance = 160
		snd.Parent = a
		table.insert(sounds, snd)
	end
	lastKickCount = kickCount
end

local function schedule(count: number, gapMin: number, gapMax: number)
	local t = os.clock()
	for _ = 1, count do
		table.insert(queue, t)
		t += rng:NextNumber(gapMin, gapMax)
	end
end

local function pop(cfg: typeof(CarConfig.kick))
	local ids = cfg.popSoundIds
	if #ids > 0 and #sounds > 0 then
		local snd = sounds[nextSound]
		nextSound = nextSound % #sounds + 1
		snd.SoundId = ids[rng:NextInteger(1, #ids)]
		snd.PlaybackSpeed = rng:NextNumber(cfg.popPitchMin, cfg.popPitchMax)
		snd.Volume = cfg.popVolume * rng:NextNumber(0.75, 1)
		snd.TimePosition = 0
		snd:Play()
	end
	if flame then
		flame:Emit(rng:NextInteger(6, 12))
	end
	if glow then
		glow.Brightness = 6
	end
end

function Exhaust.update(state: VehicleState, cfg: Config)
	if not tip then
		return
	end
	local clock = os.clock()
	local dt = math.clamp(clock - lastUpdate, 0, 0.1)
	lastUpdate = clock
	local kc = cfg.kick
	if state.kickCount ~= lastKickCount then
		lastKickCount = state.kickCount
		schedule(rng:NextInteger(kc.kickPopsMin, kc.kickPopsMax), kc.popGapMin, kc.popGapMax)
	elseif state.kicking then
		-- Held at the limiter: pops at about holdPopsPerSecond, unevenly.
		holdCarry += kc.holdPopsPerSecond * dt * rng:NextNumber(0.4, 1.6)
		if holdCarry >= 1 then
			holdCarry -= 1
			table.insert(queue, os.clock())
		end
	end
	-- Overrun: a lift from high revs crackles.
	local overrun = cfg.drivetrain.redlineRpm > 0 and state.rpm >= kc.overrunRpm
	if overrun and lastThrottle > 0.5 and state.throttle < 0.1 and not state.kicking then
		schedule(rng:NextInteger(kc.overrunPopsMin, kc.overrunPopsMax), kc.popGapMin * 1.5, kc.popGapMax * 1.8)
	end
	lastThrottle = state.throttle

	local now = os.clock()
	for i = #queue, 1, -1 do
		if queue[i] <= now then
			table.remove(queue, i)
			pop(kc)
		end
	end
	if glow and glow.Brightness > 0 then
		glow.Brightness = math.max(0, glow.Brightness - dt * 60)
	end
end

function Exhaust.detach()
	if tip then
		tip:Destroy()
		tip = nil
	end
	flame = nil
	glow = nil
	table.clear(sounds)
	table.clear(queue)
	nextSound = 1
	holdCarry = 0
	lastThrottle = 0
end

return Exhaust
