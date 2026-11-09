--!strict
-- Which drift mode the car this client drives is on (DriftStyles): the
-- mode of the tyre fitted to it, read from the car's Look attribute
-- (CarLook's tyre slot), Classic until one is bought. Tyres are bought and
-- fitted in the garage and saved per car with the rest of its look
-- (garage-tyres-flames; the owner, 2026-10-05: "make the differnt
-- driftmodes we made different tire options in the garage instead of drift
-- options in the car menu"). A tyre fitted while driving takes at once.
--
-- In Studio, I cycles the arcade drive's feel (ArcadeFeels; the attribute
-- ArcadeFeel); on a phone the top row's DRIFT tab does (TopBar, any
-- server, while ArcadeFeels.phoneButton). In Studio only, O cycles the
-- current car's modes (the LocalPlayer attributes DriftStyle_RWD,
-- DriftStyle_FWD, DriftStyle_AWD, which win over the tyre) and Shift+O
-- every mode, any drivetrain (for comparing them on one car: the
-- DriftStyleAny attribute, which O clears), each shown at the top of the
-- screen for a moment, like the flames' P.
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ConfigLoader = require(Shared:WaitForChild("ConfigLoader"))
local CarLook = require(Shared:WaitForChild("CarLook"))
local UITheme = require(Shared:WaitForChild("UITheme"))
local ArcadeFeels = require(Shared:WaitForChild("ArcadeFeels"))

local DriftStyle = {}

-- The live drift styles: a config reload (L) re-reads them too.
local function S(): ConfigLoader.Styles
	return ConfigLoader.driftStyles()
end

-- The sim swaps its config when the mode changes (VehicleController).
DriftStyle.changed = nil :: (() -> ())?

-- Studio's any-drivetrain pick.
local ANY_ATTRIBUTE = "DriftStyleAny"
-- Studio only: a JSON partial config merged over the styled config, for
-- trying numbers live (`{"line":{"hold":0.8}}`); empty or unset is off.
local LAB_ATTRIBUTE = "DriftLab"
-- The arcade drive's side variant (ArcadeFeels; Studio's I and the phone's
-- DRIFT tab cycle it).
local FEEL_ATTRIBUTE = "ArcadeFeel"
-- The Studio switch's label: how long it stays up.
local LABEL_SECONDS = 1.5

-- The car this client drives, or drove last, and its model (whose Look
-- carries the tyre); nil before the first.
local car: string? = nil
local carModel: Model? = nil
local lookConn: RBXScriptConnection? = nil
-- The mode the car was last on, so a look change that leaves the tyre
-- alone (a paint) does not swap the sim's config.
local lastStyle: string? = nil
-- Configs with a style on, per car and style, until a config reload.
local cache: { [string]: ConfigLoader.Config } = {}

local function attr(layout: string): string
	return "DriftStyle_" .. layout
end

-- The drivetrain of the car this client drives, or drove last (the default
-- car's before any).
local function carLayout(): string
	return S().layoutOf(ConfigLoader.forCar(car))
end

-- The mode of the tyre on the car this client drives, for its drivetrain:
-- a tyre that does not fit it (the catalog changed the car's drivetrain),
-- or none, is the drivetrain's Classic (DriftStyles.resolve).
local function tyreStyle(layout: string): string
	local model = carModel
	local look = if model then CarLook.decode(model:GetAttribute(CarLook.ATTRIBUTE)) else {}
	return S().resolve(layout, CarLook.item(look, "tyre").driftStyle)
end

-- The mode a car drives on: in Studio, the any-drivetrain pick or O's pick
-- for the drivetrain if one is set; else its tyre's.
function DriftStyle.forCar(carId: string?): string
	local layout = S().layoutOf(ConfigLoader.forCar(carId))
	if RunService:IsStudio() then
		local any = Players.LocalPlayer:GetAttribute(ANY_ATTRIBUTE)
		if type(any) == "string" and S().styles[any] then
			return any
		end
		local picked = Players.LocalPlayer:GetAttribute(attr(layout))
		if picked ~= nil then
			return S().resolve(layout, picked)
		end
	end
	return tyreStyle(layout)
end

-- The config a car's sim drives on: the car's own with its style on.
function DriftStyle.configFor(carId: string?): ConfigLoader.Config
	local id = ConfigLoader.resolveCarId(carId)
	local styleId = DriftStyle.forCar(id)
	local key = id .. "|" .. styleId
	local cfg = cache[key]
	if not cfg then
		cfg = S().apply(ConfigLoader.forCar(id), styleId) :: ConfigLoader.Config
		cache[key] = cfg
	end
	local feel = ArcadeFeels.feels[ArcadeFeels.resolve(Players.LocalPlayer:GetAttribute(FEEL_ATTRIBUTE))]
	if next(feel.over) ~= nil then
		cfg = S().merge(cfg, feel.over) :: ConfigLoader.Config
	end
	local lab = if RunService:IsStudio() then Players.LocalPlayer:GetAttribute(LAB_ATTRIBUTE) else nil
	if type(lab) == "string" and lab ~= "" then
		local ok, over = pcall(HttpService.JSONDecode, HttpService, lab)
		if ok and type(over) == "table" then
			return S().merge(cfg, over) :: ConfigLoader.Config
		end
		warn(`[DriftStyle] DriftLab is not a JSON object: {lab}`)
	end
	return cfg
end

-- After a config reload (L): the styled configs are rebuilt from the new
-- ones.
function DriftStyle.clearCache()
	table.clear(cache)
end

local function notify()
	lastStyle = DriftStyle.forCar(car)
	if DriftStyle.changed then
		DriftStyle.changed()
	end
end

-- The car this client now drives (VehicleController): its tyre is watched,
-- so one fitted in the garage takes at once.
function DriftStyle.setCar(carId: string?, model: Model?)
	if carId then
		car = carId
	end
	if lookConn then
		lookConn:Disconnect()
		lookConn = nil
	end
	carModel = model
	lastStyle = DriftStyle.forCar(car)
	if model then
		lookConn = model:GetAttributeChangedSignal(CarLook.ATTRIBUTE):Connect(function()
			if DriftStyle.forCar(car) ~= lastStyle then
				notify()
			end
		end)
	end
end

-- Studio's O: a mode for its own drivetrain; clears the any-drivetrain
-- pick. The attributes' change signals tell the sim (start), so a harness
-- setting them directly works the same.
local function set(id: string)
	local style = S().styles[id]
	if not style then
		return
	end
	Players.LocalPlayer:SetAttribute(ANY_ATTRIBUTE, nil)
	Players.LocalPlayer:SetAttribute(attr(style.layout), id)
end

-- The Studio switch's label, top centre for a moment (the flames' look).
local labelToken = 0
local function showText(message: string)
	local gui = Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
	if not gui then
		return
	end
	local screen = gui:FindFirstChild("DriftStyleLabel") :: ScreenGui?
	if not screen then
		local s = Instance.new("ScreenGui")
		s.Name = "DriftStyleLabel"
		s.ResetOnSpawn = false
		s.DisplayOrder = 50
		local text = Instance.new("TextLabel")
		text.Name = "Text"
		text.AnchorPoint = Vector2.new(0.5, 0)
		text.Position = UDim2.fromScale(0.5, 0.22)
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
	label.Text = message
	;(screen :: ScreenGui).Enabled = true
	labelToken += 1
	local mine = labelToken
	task.delay(LABEL_SECONDS, function()
		if labelToken == mine and screen then
			screen.Enabled = false
		end
	end)
end

local function showLabel(id: string)
	local style = S().styles[id]
	showText(`DRIFT: {string.upper(style.name)} ({style.layout})`)
end

-- The same label for other Studio switches (PaintLook's B).
DriftStyle.say = showText

-- I, or the phone's DRIFT tab: the next arcade feel.
function DriftStyle.cycleFeel()
	local player = Players.LocalPlayer
	local current = ArcadeFeels.resolve(player:GetAttribute(FEEL_ATTRIBUTE))
	local i = table.find(ArcadeFeels.order, current) or 0
	local nextId = ArcadeFeels.order[i % #ArcadeFeels.order + 1]
	player:SetAttribute(FEEL_ATTRIBUTE, nextId)
	local feel = ArcadeFeels.feels[nextId]
	showText(`DRIFT MODE: {string.upper(feel.name)} ({feel.blurb})`)
end

-- O: the next style of the car's drivetrain. Shift+O: the next of all.
local function cycle(all: boolean)
	local current = DriftStyle.forCar(car)
	local list = if all then S().order else S().forLayout(carLayout())
	local i = table.find(list, current) or 0
	local nextId = list[i % #list + 1]
	if all then
		Players.LocalPlayer:SetAttribute(ANY_ATTRIBUTE, nextId)
	else
		set(nextId)
	end
	showLabel(nextId)
end

function DriftStyle.start()
	local player = Players.LocalPlayer
	for _, layout in S().layouts do
		player:GetAttributeChangedSignal(attr(layout)):Connect(notify)
	end
	player:GetAttributeChangedSignal(ANY_ATTRIBUTE):Connect(notify)
	player:GetAttributeChangedSignal(LAB_ATTRIBUTE):Connect(notify)
	player:GetAttributeChangedSignal(FEEL_ATTRIBUTE):Connect(notify)
	if RunService:IsStudio() then
		UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
			if not processed and input.KeyCode == Enum.KeyCode.I then
				DriftStyle.cycleFeel()
				return
			end
			if processed or input.KeyCode ~= Enum.KeyCode.O then
				return
			end
			local shift = UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) or UserInputService:IsKeyDown(Enum.KeyCode.RightShift)
			cycle(shift)
		end)
	end
end

return DriftStyle
