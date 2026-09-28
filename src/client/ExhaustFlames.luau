--!strict
-- Exhaust flames (garage round 2 §2): a layered burst at every exhaust
-- outlet of a car, one per pop. CarCosmetics puts an ExhaustOutlet
-- Attachment at each pipe mouth (LookVector out of the pipe); this module
-- hangs a small set of ParticleEmitters beside each one, never enabled, and
-- Emits a burst per pop: a blue-white core at the mouth, a stretched flame
-- tongue that tapers into thinner licks, a few sparks and a smoke wisp,
-- plus a brief glow on the tip itself. No Light (the live-light cap). The
-- look is CosmeticsConfig.flames, scaled per exhaust item (flameSize,
-- flameCore, flameColor).
--
-- Who calls it:
--   * the driver's client, once per pop EngineAudio plays (pop), and once
--     per burst it decides on (send, which tells the server);
--   * every other client, when the server relays a driver's burst (start
--     listens; burst plays the pops with their sound over the window);
--   * the garage's REV button, on the turntable car (burst with sound).
--
-- The emitters live under the outlet's own holder part, so they go when
-- the look changes and CarCosmetics rebuilds the outlets.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local VehicleRig = require(Shared:WaitForChild("VehicleRig"))
local ConfigLoader = require(Shared:WaitForChild("ConfigLoader"))
local CarLook = require(Shared:WaitForChild("CarLook"))
local CarCosmeticMounts = require(Shared:WaitForChild("CarCosmeticMounts"))
local CosmeticsConfig = require(Shared:WaitForChild("CosmeticsConfig"))
local CarCosmetics = require(script.Parent:WaitForChild("CarCosmetics"))

local ExhaustFlames = {}

-- For inspecting the effect in Studio: particle time runs at this rate (each
-- emitter's TimeScale) and jets and delays stretch to match, so a 0.2 s pop
-- can be frozen and captured at any age. 1 in play; nothing sets it.
ExhaustFlames.timeScale = 1

type Key = { number }
type Layer = {
	texture: string,
	count: { number },
	lifetime: { number },
	speed: { number },
	spreadDeg: number,
	drag: number,
	riseMps2: number,
	size: { Key },
	transparency: { Key },
	squash: { Key },
	color: { from: Color3, to: Color3 }?,
	hot: Color3?,
	whiteAtBirth: number?,
	dying: Color3?,
	lightEmission: number,
	brightness: number,
	locked: boolean,
	alongMotion: boolean,
	delaySeconds: number?,
	jetSeconds: number?,
	zOffsetM: number,
}

local LAYERS = { "smoke", "sparks", "flash", "lick", "tongue", "core" }
local MOUTH = "FlameMouth"
local EXHAUST_FOLDER = "LookExhaust"
local GLOW_BASE = "FlameBaseColor"
-- Parts in the exhaust folder that glow after a pop: built tips and factory
-- pipes (a car's own mesh pipe is left alone).
local GLOWS = { "Tip", "FactoryPipe" }

local F = CosmeticsConfig.flames
local rng = Random.new()

local function layer(name: string): Layer
	return ((F.layers :: any)[name]) :: Layer
end

local function numbers(keys: { Key }, scale: number): NumberSequence
	local out: { NumberSequenceKeypoint } = {}
	for _, k in keys do
		table.insert(out, NumberSequenceKeypoint.new(k[1], k[2] * scale))
	end
	return NumberSequence.new(out)
end

-- The item whose flame this car shows: an override (the garage's draft
-- look), else the car's Look attribute.
local function exhaustItem(model: Model, item: CosmeticsConfig.Item?): CosmeticsConfig.Item
	return item or CarLook.item(CarLook.decode(model:GetAttribute(CarLook.ATTRIBUTE)), "exhaust")
end

-- Studs per car metre, and the car's exhaust mounts, or nil.
local function scaleOf(model: Model): (number, CarCosmeticMounts.Exhaust?)
	local id = model:GetAttribute(VehicleRig.CAR_ID_ATTRIBUTE)
	local carId = if type(id) == "string" then id else nil
	if not carId then
		return 1 / 0.28, nil
	end
	local k = VehicleRig.scaleOf(ConfigLoader.entry(carId))
	local mps = ConfigLoader.forCar(carId).units.metersPerStud
	local mounts = CarCosmeticMounts.cars[carId]
	return k / mps, mounts and mounts.exhaust
end

-- The emitters at one outlet, built on first use (buildMouth) and found
-- again by the ObjectValue that names their outlet.
local function mouthOf(outlet: Attachment): Attachment?
	local holder = outlet.Parent
	if not holder then
		return nil
	end
	for _, child in holder:GetChildren() do
		if child.Name == MOUTH and child:IsA("Attachment") then
			local of = child:FindFirstChild("Outlet")
			if of and of:IsA("ObjectValue") and of.Value == outlet then
				return child
			end
		end
	end
	return nil
end

-- An Attachment beside the outlet, moved out along it past the bumper,
-- with one emitter per layer.
local function buildMouth(outlet: Attachment, sc: number, spot: CarCosmeticMounts.Exhaust?): Attachment?
	local holder = outlet.Parent
	if not holder or not holder:IsA("BasePart") then
		return nil
	end
	-- How far this mouth sits inside the bumper (outlet frames are car
	-- studs from the body mount, where the holder sits).
	local zM = outlet.CFrame.Position.Z / sc
	local inside = if spot then math.max(0, spot.bumperZ - zM) else 0
	local look = outlet.CFrame.LookVector
	local lead = (F.mouthLeadM + inside / math.max(look.Z, 0.3)) * sc
	local mouth = Instance.new("Attachment")
	mouth.Name = MOUTH
	local of = Instance.new("ObjectValue")
	of.Name = "Outlet"
	of.Value = outlet
	of.Parent = mouth
	mouth.CFrame = outlet.CFrame * CFrame.new(0, 0, -lead)
	for _, name in LAYERS do
		local L = layer(name)
		local e = Instance.new("ParticleEmitter")
		e.Name = name
		e.Enabled = false
		e.Rate = 0
		e.Texture = L.texture
		e.EmissionDirection = Enum.NormalId.Front
		e.Orientation = if L.alongMotion then Enum.ParticleOrientation.VelocityParallel else Enum.ParticleOrientation.FacingCamera
		e.LightInfluence = if L.lightEmission > 0 then 0 else 1
		e.LightEmission = L.lightEmission
		e.Brightness = L.brightness
		e.LockedToPart = L.locked
		e.VelocityInheritance = if L.locked then 0 else F.inheritVelocity
		e.Drag = L.drag
		e.SpreadAngle = Vector2.new(L.spreadDeg, L.spreadDeg)
		e.Lifetime = NumberRange.new(L.lifetime[1], L.lifetime[2])
		e.Transparency = numbers(L.transparency, 1)
		e.Squash = numbers(L.squash, 1)
		-- Only a camera-facing layer (the smoke) turns: a turned flame particle, drawn along its
		-- motion, splays off the flame's axis into a starburst.
		if not L.alongMotion then
			e.Rotation = NumberRange.new(0, 360)
			e.RotSpeed = NumberRange.new(-40, 40)
		end
		-- Drawn nearer the camera than it is: the core over the tongue over
		-- the rest, so the blue shows through the flame seen from behind.
		e.ZOffset = L.zOffsetM * sc
		if L.color then
			e.Color = ColorSequence.new(L.color.from, L.color.to)
		end
		e.Parent = mouth
	end
	mouth.Parent = holder
	return mouth
end

-- The per-car, per-item parts of each emitter, set before every pop (the
-- item can change under the same outlets in the garage preview).
local function dress(mouth: Attachment, item: CosmeticsConfig.Item, sc: number, trail: number)
	local k = (item.flameSize or 1) * sc
	local flame = item.flameColor or Color3.fromHex("#FF7A22")
	local core = item.flameCore or Color3.fromHex("#CFE0FF")
	for _, name in LAYERS do
		local e = mouth:FindFirstChild(name)
		if not e or not e:IsA("ParticleEmitter") then
			continue
		end
		local L = layer(name)
		local reach = if L.locked then 1 + F.trailGain * trail else 1
		e.TimeScale = ExhaustFlames.timeScale
		e.Size = numbers(L.size, k)
		e.Speed = NumberRange.new(L.speed[1] * k * reach, L.speed[2] * k * reach)
		e.Acceleration = Vector3.new(0, L.riseMps2 * sc, 0)
		if name == "core" then
			e.Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, core:Lerp(Color3.new(1, 1, 1), L.whiteAtBirth or 0)),
				ColorSequenceKeypoint.new(0.25, core),
				ColorSequenceKeypoint.new(1, core),
			})
		elseif name == "flash" then
			e.Color = ColorSequence.new(flame)
		elseif name == "tongue" or name == "lick" then
			local T = layer("tongue")
			e.Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, T.hot or flame),
				ColorSequenceKeypoint.new(0.35, flame),
				ColorSequenceKeypoint.new(1, T.dying or flame),
			})
		end
	end
end

-- Jets: a layer with jetSeconds is let out over that long, a few particles
-- a frame, rather than all in one frame, so the flame is one continuous
-- tongue from the mouth out (particles of every age along it) instead of a
-- clump that leaves the pipe. Still Emit only: nothing here is a running
-- emitter.
type Jet = { e: ParticleEmitter, left: number, rate: number, owed: number }
local jets: { Jet } = {}
local jetConn: RBXScriptConnection? = nil

local function stepJets(dt: number)
	for i = #jets, 1, -1 do
		local j = jets[i]
		if not j.e.Parent then
			table.remove(jets, i)
			continue
		end
		j.owed += j.rate * dt
		local n = math.min(math.floor(j.owed), j.left)
		if n > 0 then
			j.e:Emit(n)
			j.owed -= n
			j.left -= n
		end
		if j.left <= 0 then
			table.remove(jets, i)
		end
	end
	if #jets == 0 and jetConn then
		jetConn:Disconnect()
		jetConn = nil
	end
end

local function jet(e: ParticleEmitter, n: number, seconds: number)
	-- The first particle at once, so the flame starts with its pop.
	e:Emit(1)
	if n <= 1 then
		return
	end
	table.insert(jets, { e = e, left = n - 1, rate = (n - 1) / seconds * ExhaustFlames.timeScale, owed = 0 })
	if not jetConn then
		jetConn = RunService.Heartbeat:Connect(stepJets)
	end
end

local function emit(mouth: Attachment, name: string)
	local e = mouth:FindFirstChild(name)
	if not e or not e:IsA("ParticleEmitter") then
		return
	end
	local L = layer(name)
	local n = rng:NextInteger(L.count[1], L.count[2])
	if n <= 0 then
		return
	end
	if L.delaySeconds then
		task.delay(L.delaySeconds / ExhaustFlames.timeScale, function()
			if e.Parent then
				e:Emit(n)
			end
		end)
	elseif L.jetSeconds then
		jet(e, n, L.jetSeconds)
	else
		e:Emit(n)
	end
end

-- The tip nearest this outlet glows for a moment: its colour pulled toward
-- the glow colour and eased back. The base colour is kept on the part so
-- overlapping pops never creep it.
local function glow(outlet: Attachment)
	local holder = outlet.Parent
	local folder = holder and holder.Parent
	if not folder or folder.Name ~= EXHAUST_FOLDER then
		return
	end
	local at = outlet.WorldPosition
	local best: BasePart? = nil
	local bestD = math.huge
	for _, p in folder:GetChildren() do
		if not p:IsA("BasePart") then
			continue
		end
		local glows = false
		for _, prefix in GLOWS do
			if string.sub(p.Name, 1, #prefix) == prefix then
				glows = true
			end
		end
		if glows then
			local d = (p.Position - at).Magnitude
			if d < bestD then
				best, bestD = p, d
			end
		end
	end
	local part = best
	if not part then
		return
	end
	local base = part:GetAttribute(GLOW_BASE)
	if typeof(base) ~= "Color3" then
		base = part.Color
		part:SetAttribute(GLOW_BASE, base)
	end
	local b = base :: Color3
	part.Color = b:Lerp(F.glowColor, F.glowAmount)
	TweenService:Create(part, TweenInfo.new(F.glowSeconds, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Color = b }):Play()
end

-- 0 at rest to 1 at trailFullKmh, from the car's own velocity.
local function trailOf(model: Model): number
	local ok, handles = pcall(VehicleRig.handles, model)
	if not ok then
		return 0
	end
	local kmh = handles.chassis.AssemblyLinearVelocity.Magnitude * ConfigLoader.current().units.metersPerStud * 3.6
	return math.clamp(kmh / F.trailFullKmh, 0, 1)
end

-- Particles emitted per pop at one outlet, most and least (for the report
-- and the spec).
function ExhaustFlames.particlesPerPop(): (number, number)
	local lo, hi = 0, 0
	for _, name in LAYERS do
		local L = layer(name)
		lo += L.count[1]
		hi += L.count[2]
	end
	return lo, hi
end

-- One pop: a flame at every outlet of the car. item overrides the car's
-- own exhaust (the garage preview's draft look).
function ExhaustFlames.pop(model: Model, item: CosmeticsConfig.Item?)
	local outlets = CarCosmetics.outlets(model)
	if #outlets == 0 then
		return
	end
	local sc, spot = scaleOf(model)
	local it = exhaustItem(model, item)
	local trail = trailOf(model)
	for _, outlet in outlets do
		local mouth = mouthOf(outlet) or buildMouth(outlet, sc, spot)
		if not mouth then
			continue
		end
		dress(mouth, it, sc, trail)
		for _, name in LAYERS do
			emit(mouth, name)
		end
		glow(outlet)
	end
end

-- A pop sound on the car, from a small pool so pops overlap: the crackle
-- EngineAudio plays for the driver (CarConfig effects.engineAudio).
local function popSound(model: Model)
	local ok, handles = pcall(VehicleRig.handles, model)
	if not ok then
		return
	end
	local id = model:GetAttribute(VehicleRig.CAR_ID_ATTRIBUTE)
	local audio = ConfigLoader.forCar(if type(id) == "string" then id else nil).effects.engineAudio
	if audio.crackleSoundId == "" then
		return
	end
	local chassis = handles.chassis
	local pool: { Sound } = {}
	for i = 1, F.soundPool do
		local name = `FlamePop{i}`
		local s = chassis:FindFirstChild(name)
		if not s or not s:IsA("Sound") then
			local new = Instance.new("Sound")
			new.Name = name
			new.SoundId = audio.crackleSoundId
			new.RollOffMaxDistance = 120
			new.Parent = chassis
			s = new
		end
		table.insert(pool, s :: Sound)
	end
	-- The least recently started one.
	local pick = pool[1]
	for _, s in pool do
		if not s.IsPlaying then
			pick = s
			break
		end
	end
	pick.PlaybackSpeed = rng:NextNumber(audio.cracklePitch[1], audio.cracklePitch[2])
	pick.Volume = audio.crackleVolume * rng:NextNumber(audio.crackleVolumeRange[1], audio.crackleVolumeRange[2])
	pick.TimePosition = 0
	pick:Play()
end

-- A burst: pops pops over burstSeconds, the first at once, each a flame
-- at every outlet with its pop sound (for cars this client does not drive,
-- and the garage preview). item as for pop.
function ExhaustFlames.burst(model: Model, pops: number, item: CosmeticsConfig.Item?)
	local n = math.clamp(math.floor(pops), 0, F.maxPopsPerBurst)
	for i = 1, n do
		local at = if i == 1 then 0 else rng:NextNumber(0.05, F.burstSeconds)
		task.delay(at, function()
			if model.Parent then
				popSound(model)
				ExhaustFlames.pop(model, item)
			end
		end)
	end
end

-- The garage REV button's burst size for an exhaust item.
function ExhaustFlames.revPops(item: CosmeticsConfig.Item): number
	local scaled = rng:NextInteger(F.revPops[1], F.revPops[2]) * (item.crackleChance or 1)
	return math.min(math.round(scaled), F.maxPopsPerBurst)
end

local remote: RemoteEvent? = nil

-- The driver's burst, for the server to relay to everyone else (the driver
-- has already played it).
function ExhaustFlames.send(pops: number)
	if remote and pops > 0 then
		remote:FireServer(math.min(math.floor(pops), F.maxPopsPerBurst))
	end
end

-- Every client: play the bursts the server relays from other drivers.
function ExhaustFlames.start(remotes: Folder)
	local r = remotes:WaitForChild("ExhaustPops") :: RemoteEvent
	remote = r
	r.OnClientEvent:Connect(function(model: any, pops: any)
		if typeof(model) ~= "Instance" or not model:IsA("Model") or type(pops) ~= "number" then
			return
		end
		if not model:IsDescendantOf(Workspace) then
			return
		end
		ExhaustFlames.burst(model, pops)
	end)
end

return ExhaustFlames
