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
-- Who calls it: ExhaustPops, once per pop it plays, for the driver's car,
-- every relayed car and the garage's REV (the sounds, bursts and relay are
-- ExhaustPops'; 2026-10-04).
--
-- The emitters live under the outlet's own holder part, so they go when
-- the look changes and CarCosmetics rebuilds the outlets.
--
-- Styles (2026-10-04, ExhaustStyles): every style but Classic has its own
-- layers, built at each outlet the first time they are used, one emitter
-- per layer and pop size, named "style:layer:size". A pop's size picks the
-- emitters, so a small crack and a big bang are drawn at their own sizes
-- without touching a live emitter's Size (Size, Colour and Transparency
-- reach particles already out, so changing them per pop made earlier flames
-- jump). Classic is the garage round 2 flame above, unchanged.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local VehicleRig = require(Shared:WaitForChild("VehicleRig"))
local ConfigLoader = require(Shared:WaitForChild("ConfigLoader"))
local CarLook = require(Shared:WaitForChild("CarLook"))
local CarCosmeticMounts = require(Shared:WaitForChild("CarCosmeticMounts"))
local CosmeticsConfig = require(Shared:WaitForChild("CosmeticsConfig"))
local ExhaustStyles = require(Shared:WaitForChild("ExhaustStyles"))
local ExhaustSputter = require(Shared:WaitForChild("ExhaustSputter"))
local CarCosmetics = require(script.Parent:WaitForChild("CarCosmetics"))

local ExhaustFlames = {}

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
-- The tip's colour before any glow, kept on the part. It goes stale only if
-- something recolours a tip in place; CarCosmetics rebuilds tips instead.
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
		e.TimeScale = F.timeScale
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
	table.insert(jets, { e = e, left = n - 1, rate = (n - 1) / seconds * F.timeScale, owed = 0 })
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
		task.delay(L.delaySeconds / F.timeScale, function()
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
	local id = model:GetAttribute(VehicleRig.CAR_ID_ATTRIBUTE)
	local mps = ConfigLoader.forCar(if type(id) == "string" then id else nil).units.metersPerStud
	local kmh = handles.chassis.AssemblyLinearVelocity.Magnitude * mps * 3.6
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
function ExhaustFlames.pop(model: Model, item: CosmeticsConfig.Item?): Attachment?
	local outlets = CarCosmetics.outlets(model)
	if #outlets == 0 then
		return nil
	end
	local sc, spot = scaleOf(model)
	local it = exhaustItem(model, item)
	local trail = trailOf(model)
	local first: Attachment? = nil
	for _, outlet in outlets do
		local mouth = mouthOf(outlet) or buildMouth(outlet, sc, spot)
		if not mouth then
			continue
		end
		first = first or mouth
		dress(mouth, it, sc, trail)
		for _, name in LAYERS do
			emit(mouth, name)
		end
		glow(outlet)
	end
	return first
end

-- A style layer's emitter at one mouth for one pop size, built on first
-- use and rebuilt only if the car's scale changes (sizeKey: the layer's
-- size multiplier in studs).
local function styleEmitter(mouth: Attachment, styleId: string, name: string, class: string, L: ExhaustStyles.Layer, sizeKey: number, sc: number): ParticleEmitter
	local id = `{styleId}:{name}:{class}`
	local found = mouth:FindFirstChild(id)
	if found and found:IsA("ParticleEmitter") and found:GetAttribute("SizeKey") == sizeKey then
		return found
	end
	if found then
		found:Destroy()
	end
	local e = Instance.new("ParticleEmitter")
	e.Name = id
	e.Enabled = false
	e.Rate = 0
	e.Texture = L.texture
	if L.flipbook then
		e.FlipbookLayout = (Enum.ParticleFlipbookLayout :: any)[L.flipbook.layout]
		e.FlipbookMode = (Enum.ParticleFlipbookMode :: any)[L.flipbook.mode]
	end
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
	e.Size = numbers(L.size, sizeKey)
	e.Transparency = numbers(L.transparency, 1)
	e.Squash = numbers(L.squash, 1)
	e.Acceleration = Vector3.new(0, L.riseMps2 * sc, 0)
	-- Only camera-facing layers turn (BEHAVIOURS: a turned particle drawn
	-- along its motion splays into a starburst).
	if L.turn and not L.alongMotion then
		e.Rotation = NumberRange.new(0, 360)
		e.RotSpeed = NumberRange.new(-40, 40)
	end
	e.ZOffset = L.zOffsetM * sc
	if L.colors then
		local keys: { ColorSequenceKeypoint } = {}
		for _, k in L.colors do
			table.insert(keys, ColorSequenceKeypoint.new(k[1] :: number, k[2] :: Color3))
		end
		e.Color = ColorSequence.new(keys)
	end
	e:SetAttribute("SizeKey", sizeKey)
	e.Parent = mouth
	return e
end

-- n particles from one emitter, as the layer says: after a delay, let out
-- as a jet, or all at once.
local function emitLayer(e: ParticleEmitter, L: ExhaustStyles.Layer, n: number)
	if n <= 0 then
		return
	end
	if L.delaySeconds then
		task.delay(L.delaySeconds / F.timeScale, function()
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

-- One pop of a style at every outlet of the car, drawn at the pop's size:
-- the layers its size reaches (ExhaustStyles.layersFor), each emitter's
-- particles scaled by the size's count, and its speed (so its length) by
-- the size and the pop's level. Classic draws as pop does. item overrides
-- the car's own exhaust (the garage preview). Returns the first outlet's
-- mouth, where ExhaustPops hangs the flash light.
function ExhaustFlames.flame(model: Model, styleId: string, pop: ExhaustSputter.Pop, item: CosmeticsConfig.Item?): Attachment?
	local style = ExhaustStyles.styles[styleId]
	if not style or not style.layers then
		return ExhaustFlames.pop(model, item)
	end
	local layers = style.layers :: { [string]: ExhaustStyles.Layer }
	local outlets = CarCosmetics.outlets(model)
	if #outlets == 0 then
		return nil
	end
	local sc, spot = scaleOf(model)
	local it = exhaustItem(model, item)
	local k = (it.flameSize or 1) * sc
	local trail = trailOf(model)
	local look = style.classes[pop.class]
	local names = ExhaustStyles.layersFor(style, pop.class)
	local first: Attachment? = nil
	for _, outlet in outlets do
		local mouth = mouthOf(outlet) or buildMouth(outlet, sc, spot)
		if not mouth then
			continue
		end
		first = first or mouth
		for _, name in names do
			local L = layers[name]
			local e = styleEmitter(mouth, styleId, name, pop.class, L, k * look.size, sc)
			e.TimeScale = F.timeScale
			local reach = if L.locked then 1 + F.trailGain * trail else 1
			local v = k * look.speed * (0.75 + 0.25 * pop.level) * reach
			e.Speed = NumberRange.new(L.speed[1] * v, L.speed[2] * v)
			emitLayer(e, L, math.round(rng:NextInteger(L.count[1], L.count[2]) * look.count))
		end
		if pop.class ~= "small" then
			glow(outlet)
		end
	end
	return first
end

return ExhaustFlames
