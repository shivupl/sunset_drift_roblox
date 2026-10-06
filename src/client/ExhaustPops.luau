--!strict
-- Exhaust pops (2026-10-04; the owner: "way cooler" flames and audio "like
-- the sputter"): plays a burst of pops on any car in the car's exhaust
-- style (ExhaustStyles). A burst is a list of pops (ExhaustSputter: when,
-- how big) made from a seed; each pop plays one real pop cut from a
-- recording (a Sound's PlaybackRegion, from a small pool per clip on the
-- car) and fires its flame (ExhaustFlames.flame) on the same frame, and the
-- newest pop of any car moves the one flash light.
--
-- Who calls it:
--   * the driver's client, from EngineAudio's hooks (init.client): lift
--     starts a burst and sends (burst, style, seed, scale) to the server,
--     a lift with the car sideways starts the style's flutter instead (the
--     drift flutter, 2026-10-05) and sends it as a flutter,
--     cut stops what is left of it (the throttle back on) and sends a cut,
--     single fires one pop (upshift and limiter; 0, off, by default);
--   * every other client, as the server relays a driver's messages: the
--     same seed rebuilds the same burst;
--   * the garage's REV button (rev), on the turntable car, unrelayed.
--
-- Which style: the flame fitted to the car (CarLook's flame slot), bought
-- in the garage, Classic until one is (garage-tyres-flames; the owner,
-- 2026-10-05: "have classic be the default and the other flames
-- purchasable in the garage"). A driver's bursts carry their style, so
-- other clients see the driver's flame. In Studio only, P cycles this
-- client's style over the fitted one (the LocalPlayer attribute
-- FlameStyle, shown for a moment on screen).
local ContentProvider = game:GetService("ContentProvider")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local VehicleRig = require(Shared:WaitForChild("VehicleRig"))
local ConfigLoader = require(Shared:WaitForChild("ConfigLoader"))
local CarLook = require(Shared:WaitForChild("CarLook"))
local CosmeticsConfig = require(Shared:WaitForChild("CosmeticsConfig"))
local ExhaustStyles = require(Shared:WaitForChild("ExhaustStyles"))
local ExhaustSputter = require(Shared:WaitForChild("ExhaustSputter"))
local UITheme = require(Shared:WaitForChild("UITheme"))
local ExhaustFlames = require(script.Parent:WaitForChild("ExhaustFlames"))

local ExhaustPops = {}

type Pop = ExhaustSputter.Pop
type Style = ExhaustStyles.Style

local KIND = ExhaustStyles.KIND
-- Sounds per clip on each car, so pops overlap (a crackle's doubles come
-- 15 ms apart; a grain lasts 30-70 ms, a whole clip up to 0.44 s).
local POOL = 3
-- Name of the attribute that picks this client's style (Studio).
local STYLE_ATTRIBUTE = "FlameStyle"
-- The style switch's label: how long it stays up.
local LABEL_SECONDS = 1.5

local rng = Random.new()
local remote: RemoteEvent? = nil
-- Per car: the burst token (a new burst or a cut bumps it; pops of an older
-- burst then skip) and until when its burst plays (os.clock). Strong
-- tables, cleared on Destroying (BEHAVIOURS: never a weak table keyed by
-- Instance).
local tokens: { [Model]: number } = {}
local playingUntil: { [Model]: number } = {}
local watched: { [Model]: boolean } = {}
-- Clips that failed to load here (a moderated or private asset): their
-- grains are skipped, and a bank with none left plays Classic's pop.
local failed: { [string]: boolean } = {}

local function watch(model: Model)
	if watched[model] then
		return
	end
	watched[model] = true
	model.Destroying:Once(function()
		tokens[model] = nil
		playingUntil[model] = nil
		watched[model] = nil
	end)
end

local function chassisOf(model: Model): BasePart?
	local ok, handles = pcall(VehicleRig.handles, model)
	return if ok then handles.chassis else nil
end

-- The car's own exhaust item (its Look attribute).
local function lookOf(model: Model): CarLook.Look
	return CarLook.decode(model:GetAttribute(CarLook.ATTRIBUTE))
end

local function exhaustItem(model: Model): CosmeticsConfig.Item
	return CarLook.item(lookOf(model), "exhaust")
end

-- A free Sound for this clip on the car, from its pool (the first one not
-- playing, else the first: a cut-off tail is better than a dropped pop).
local function soundFor(chassis: BasePart, id: string): Sound
	local key = "ExhaustPop" .. (string.match(id, "%d+") or "0")
	local first: Sound? = nil
	for i = 1, POOL do
		local name = `{key}_{i}`
		local found = chassis:FindFirstChild(name)
		local s: Sound
		if found and found:IsA("Sound") then
			s = found
		else
			s = Instance.new("Sound")
			s.Name = name
			s.SoundId = id
			s.RollOffMaxDistance = 120
			s.Parent = chassis
		end
		if not s.IsPlaying then
			return s
		end
		first = first or s
	end
	return first :: Sound
end

local function classicGrain(): ExhaustStyles.Grain
	return ExhaustStyles.styles.classic.sounds.mid.grains[1]
end

-- One pop's sound: a grain of its size from the style's bank, at a random
-- pitch in the bank's range, as loud as the bank, the grain's gain and the
-- pop's level say.
local function playGrain(chassis: BasePart, style: Style, pop: Pop)
	local bank = style.sounds[pop.class]
	local usable: { ExhaustStyles.Grain } = {}
	for _, g in bank.grains do
		if not failed[g.id] then
			table.insert(usable, g)
		end
	end
	local g = if #usable > 0 then usable[rng:NextInteger(1, #usable)] else classicGrain()
	local s = soundFor(chassis, g.id)
	local whole = g.from <= 0 and g.to >= (ExhaustStyles.clipSeconds[g.id] or math.huge) - 1e-6
	s.PlaybackRegionsEnabled = not whole
	if not whole then
		s.PlaybackRegion = NumberRange.new(g.from, g.to)
	end
	s.PlaybackSpeed = rng:NextNumber(bank.pitch[1], bank.pitch[2])
	s.Volume = bank.volume * g.gain * pop.level
	s.TimePosition = g.from
	s:Play()
end

-- The flash: one PointLight per client, hung on the newest pop's mouth, so
-- the bumper and the road light up with each pop. The cap is structural,
-- like the twelve street lights (WORLD.md): there is only ever this one.
local light: PointLight? = nil
local lightPeak, lightAt, lightSeconds = 0, 0, 0.1
local lightConn: RBXScriptConnection? = nil

local function stepLight()
	local l = light
	local age = os.clock() - lightAt
	if not l or not l.Parent or age >= lightSeconds then
		if l then
			l.Enabled = false
		end
		if lightConn then
			lightConn:Disconnect()
			lightConn = nil
		end
		return
	end
	l.Brightness = lightPeak * (1 - age / lightSeconds) ^ 2
end

local function flash(mouth: Attachment, style: Style, pop: Pop)
	local L = style.light
	if not L then
		return
	end
	local peak = L.brightness * style.classes[pop.class].light * pop.level
	if peak <= 0 then
		return
	end
	-- Only pops near the camera take the one light (a car across the map
	-- would take it from the one in front of you).
	local camera = Workspace.CurrentCamera
	local mps = ConfigLoader.current().units.metersPerStud
	if camera and not ExhaustStyles.lightInRange((camera.CFrame.Position - mouth.WorldPosition).Magnitude * mps) then
		return
	end
	-- The last mouth it hung on may have gone with an exhaust change, and
	-- the light with it: a destroyed instance's Parent is locked.
	local l = light
	if not l or not pcall(function()
		(l :: PointLight).Parent = mouth
	end) then
		local new = Instance.new("PointLight")
		new.Name = "ExhaustFlash"
		new.Shadows = false
		new.Parent = mouth
		light = new
		l = new
	end
	local p = l :: PointLight
	p.Color = L.color
	p.Range = math.min(L.rangeM / mps, 60)
	p.Brightness = peak
	p.Enabled = true
	lightPeak, lightAt, lightSeconds = peak, os.clock(), L.seconds
	if not lightConn then
		lightConn = RunService.Heartbeat:Connect(stepLight)
	end
end

-- One pop on a car: its sound, its flame, the flash. A car destroyed or an
-- exhaust rebuilt between pops is skipped quietly.
local function firePop(model: Model, styleId: string, pop: Pop, item: CosmeticsConfig.Item?)
	local style = ExhaustStyles.styles[styleId]
	local chassis = chassisOf(model)
	if not style or not chassis or not model:IsDescendantOf(Workspace) then
		return
	end
	playGrain(chassis, style, pop)
	local mouth = ExhaustFlames.flame(model, styleId, pop, item)
	if mouth then
		flash(mouth, style, pop)
	end
end

-- A burst on a car: its pops at their times, unless a newer burst or a cut
-- comes first. flutter: the style's drift flutter instead of its burst.
-- Returns the pops.
local function burst(model: Model, styleId: string, seed: number, scale: number, item: CosmeticsConfig.Item?, flutter: boolean?): { Pop }
	local style = ExhaustStyles.styles[styleId]
	if not style then
		return {}
	end
	watch(model)
	local token = (tokens[model] or 0) + 1
	tokens[model] = token
	local pops = ExhaustSputter.generate(if flutter then style.flutter else style.pattern, seed, scale)
	playingUntil[model] = os.clock() + pops[#pops].t + 0.05
	for _, pop in pops do
		local function fire()
			if tokens[model] == token and model.Parent then
				firePop(model, styleId, pop, item)
			end
		end
		if pop.t <= 0 then
			fire()
		else
			task.delay(pop.t, fire)
		end
	end
	return pops
end

local function stop(model: Model)
	tokens[model] = (tokens[model] or 0) + 1
	playingUntil[model] = 0
end

local function send(kind: number, style: number, seed: number, scale: number)
	if remote then
		remote:FireServer(kind, style, seed, scale)
	end
end

-- A look's flame style: in Studio, this client's FlameStyle pick (P) if it
-- names one; else the look's flame, or the default (Classic).
function ExhaustPops.styleId(look: CarLook.Look): string
	if RunService:IsStudio() then
		local a = Players.LocalPlayer:GetAttribute(STYLE_ATTRIBUTE)
		if type(a) == "string" and ExhaustStyles.styles[a] then
			return a
		end
	end
	local id = CarLook.item(look, "flame").flameStyle
	if id and ExhaustStyles.styles[id] then
		return id
	end
	return ExhaustStyles.default
end

-- The driver lifted off fast: a burst in the car's flame style, scaled by the
-- exhaust and how high the revs were (rev, EngineAudio), sent on for
-- everyone else.
function ExhaustPops.lift(model: Model, rev: number)
	local styleId = ExhaustPops.styleId(lookOf(model))
	local style = ExhaustStyles.styles[styleId]
	local scale = ExhaustStyles.scaleFor(style, exhaustItem(model).crackleChance or 1, rev)
	local seed = rng:NextInteger(1, 2 ^ 31 - 1)
	burst(model, styleId, seed, scale, nil)
	send(KIND.burst, ExhaustStyles.index(styleId) or 1, seed, scale)
end

-- The driver lifted while sideways: the style's flutter instead of its
-- burst, at full revs (a drift sits high), sent on as a flutter so every
-- client rebuilds the same one. The throttle back on cuts it like a burst.
function ExhaustPops.flutter(model: Model)
	local styleId = ExhaustPops.styleId(lookOf(model))
	local style = ExhaustStyles.styles[styleId]
	local scale = ExhaustStyles.scaleFor(style, exhaustItem(model).crackleChance or 1, 1)
	local seed = rng:NextInteger(1, 2 ^ 31 - 1)
	burst(model, styleId, seed, scale, nil, true)
	send(KIND.flutter, ExhaustStyles.index(styleId) or 1, seed, scale)
end

-- The driver is back on the throttle: what is left of the burst stops,
-- here and for everyone (sent only when one is playing).
function ExhaustPops.cut(model: Model)
	if os.clock() >= (playingUntil[model] or 0) then
		return
	end
	stop(model)
	send(KIND.cut, 0, 0, 0)
end

-- One pop (an upshift or the limiter), sent on.
function ExhaustPops.single(model: Model)
	local styleId = ExhaustPops.styleId(lookOf(model))
	firePop(model, styleId, { t = 0, class = "mid", level = 1 }, nil)
	send(KIND.single, ExhaustStyles.index(styleId) or 1, rng:NextInteger(1, 2 ^ 31 - 1), 1)
end

-- The garage REV button: a burst with the exhaust and flame on the
-- turntable car (look: bought or only previewed), at full revs. Returns how
-- long it lasts, so the button waits it out.
function ExhaustPops.rev(model: Model, look: CarLook.Look): number
	local item = CarLook.item(look, "exhaust")
	local styleId = ExhaustPops.styleId(look)
	local style = ExhaustStyles.styles[styleId]
	local pops = burst(model, styleId, rng:NextInteger(1, 2 ^ 31 - 1), ExhaustStyles.scaleFor(style, item.crackleChance or 1, 1), item)
	return (if #pops > 0 then pops[#pops].t else 0) + 0.3
end

-- The style switch's label, top centre for a moment.
local labelToken = 0
local function showStyle(styleId: string)
	local gui = Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
	if not gui then
		return
	end
	local screen = gui:FindFirstChild("FlameStyleLabel") :: ScreenGui?
	if not screen then
		local s = Instance.new("ScreenGui")
		s.Name = "FlameStyleLabel"
		s.ResetOnSpawn = false
		s.DisplayOrder = 50
		local text = Instance.new("TextLabel")
		text.Name = "Text"
		text.AnchorPoint = Vector2.new(0.5, 0)
		text.Position = UDim2.fromScale(0.5, 0.16)
		text.AutomaticSize = Enum.AutomaticSize.XY
		text.BackgroundColor3 = UITheme.color.asphalt900
		text.BackgroundTransparency = UITheme.alpha.hud
		text.TextColor3 = UITheme.color.paint
		text.FontFace = UITheme.font("title")
		text.TextSize = UITheme.textSize("title", false)
		local pad = Instance.new("UIPadding")
		pad.PaddingLeft = UDim.new(0, UITheme.space.lg)
		pad.PaddingRight = UDim.new(0, UITheme.space.lg)
		pad.PaddingTop = UDim.new(0, UITheme.space.sm)
		pad.PaddingBottom = UDim.new(0, UITheme.space.sm)
		pad.Parent = text
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, UITheme.radius.md)
		corner.Parent = text
		text.Parent = s
		s.Parent = gui
		screen = s
	end
	local label = (screen :: ScreenGui):FindFirstChild("Text") :: TextLabel
	label.Text = `FLAMES: {string.upper(ExhaustStyles.styles[styleId].name)}`
	;(screen :: ScreenGui).Enabled = true
	labelToken += 1
	local mine = labelToken
	task.delay(LABEL_SECONDS, function()
		if labelToken == mine and screen then
			screen.Enabled = false
		end
	end)
end

local function cycleStyle()
	local order = ExhaustStyles.order
	local i = ExhaustStyles.index(ExhaustPops.styleId({})) or 0
	local nextId = order[i % #order + 1]
	Players.LocalPlayer:SetAttribute(STYLE_ATTRIBUTE, nextId)
	showStyle(nextId)
end

-- Every client: load the pop clips, play the bursts the server relays from
-- other drivers, and in Studio the style switch.
function ExhaustPops.start(remotes: Folder)
	local r = remotes:WaitForChild("ExhaustPops") :: RemoteEvent
	remote = r
	task.spawn(function()
		-- Sounds, not id strings: PreloadAsync fetches a bare id as an
		-- image, so every audio id "failed" that way (Play, 2026-10-05).
		local folder = Instance.new("Folder")
		folder.Name = "ExhaustPopPreload"
		local sounds: { Sound } = {}
		for id in ExhaustStyles.clipSeconds do
			local s = Instance.new("Sound")
			s.SoundId = id
			s.Parent = folder
			table.insert(sounds, s)
		end
		folder.Parent = game:GetService("SoundService")
		ContentProvider:PreloadAsync(sounds, function(id: string, status: Enum.AssetFetchStatus)
			if status ~= Enum.AssetFetchStatus.Success then
				failed[id] = true
				warn(`[ExhaustPops] pop clip {id} did not load ({status.Name}); its pops fall back`)
			end
		end)
		folder:Destroy()
		-- The flame textures (image ids preload as strings), so the first
		-- pops draw them, and any that fail draw a built-in stand-in.
		local textures: { string } = {}
		for id in ExhaustStyles.textureFallback do
			table.insert(textures, id)
		end
		ContentProvider:PreloadAsync(textures, function(id: string, status: Enum.AssetFetchStatus)
			if status ~= Enum.AssetFetchStatus.Success then
				ExhaustFlames.textureFailed(id)
				warn(`[ExhaustPops] flame texture {id} did not load ({status.Name}); its layers use a built-in one`)
			end
		end)
	end)
	r.OnClientEvent:Connect(function(model: any, kind: any, style: any, seed: any, scale: any)
		if typeof(model) ~= "Instance" or not model:IsA("Model") or not model:IsDescendantOf(Workspace) then
			return
		end
		if not ExhaustStyles.validRelay(kind, style, seed, scale) then
			return
		end
		if kind == KIND.cut then
			stop(model)
			return
		end
		local styleId = ExhaustStyles.order[style]
		if kind == KIND.single then
			firePop(model, styleId, { t = 0, class = "mid", level = 1 }, nil)
		else
			burst(model, styleId, seed, scale, nil, kind == KIND.flutter)
		end
	end)
	if RunService:IsStudio() then
		UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
			if not processed and input.KeyCode == Enum.KeyCode.P then
				cycleStyle()
			end
		end)
	end
end

return ExhaustPops
