--!strict
-- Which drift style this player drives (DriftStyles; the owner, 2026-10-05:
-- "implement a couple different styles (multiple for each) that i can test
-- and try out in game"). One choice per drivetrain, kept as LocalPlayer
-- attributes (DriftStyle_RWD, DriftStyle_FWD, DriftStyle_AWD) for the
-- session, so swapping cars keeps it. Not saved to the profile until the
-- owner picks the styles to keep.
--
-- The menu's Settings tab sets it (SettingsPanel). In Studio only, O cycles
-- the current car's styles and Shift+O every style, any drivetrain (for
-- comparing them on one car: the DriftStyleAny attribute, which O and the
-- Settings tab clear), each shown at the top of the screen for a moment,
-- like the flames' P.
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ConfigLoader = require(Shared:WaitForChild("ConfigLoader"))
local UITheme = require(Shared:WaitForChild("UITheme"))

local DriftStyle = {}

-- The live drift styles: a config reload (L) re-reads them too.
local function S(): ConfigLoader.Styles
	return ConfigLoader.driftStyles()
end

-- The sim swaps its config when the choice changes (VehicleController); the
-- Settings tab repaints, and rebuilds its chips when the car's drivetrain
-- changes.
DriftStyle.changed = nil :: (() -> ())?
DriftStyle.panelChanged = nil :: (() -> ())?

-- Studio's any-drivetrain pick.
local ANY_ATTRIBUTE = "DriftStyleAny"
-- Studio only: a JSON partial config merged over the styled config, for
-- trying numbers live (`{"line":{"hold":0.8}}`); empty or unset is off.
local LAB_ATTRIBUTE = "DriftLab"
-- The Studio switch's label: how long it stays up.
local LABEL_SECONDS = 1.5

-- The car this client drives, or drove last (its drivetrain is what the
-- Settings tab offers); nil before the first.
local car: string? = nil
-- Configs with a style on, per car and style, until a config reload.
local cache: { [string]: ConfigLoader.Config } = {}

local function attr(layout: string): string
	return "DriftStyle_" .. layout
end

-- The drivetrain of the car this client drives, or drove last (the default
-- car's before any).
function DriftStyle.carLayout(): string
	return S().layoutOf(ConfigLoader.forCar(car))
end

-- This player's style for a drivetrain.
function DriftStyle.current(layout: string): string
	return S().resolve(layout, Players.LocalPlayer:GetAttribute(attr(layout)))
end

-- The style a car drives on: Studio's any-drivetrain pick if one is set,
-- else this player's style for the car's drivetrain.
function DriftStyle.forCar(carId: string?): string
	local any = Players.LocalPlayer:GetAttribute(ANY_ATTRIBUTE)
	if RunService:IsStudio() and type(any) == "string" and S().styles[any] then
		return any
	end
	return DriftStyle.current(S().layoutOf(ConfigLoader.forCar(carId)))
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

-- The car this client now drives (VehicleController).
function DriftStyle.setCar(carId: string?)
	if carId then
		car = carId
	end
	if DriftStyle.panelChanged then
		DriftStyle.panelChanged()
	end
end

local function notify()
	if DriftStyle.changed then
		DriftStyle.changed()
	end
	if DriftStyle.panelChanged then
		DriftStyle.panelChanged()
	end
end

-- Pick a style, for its own drivetrain; clears Studio's any-drivetrain
-- pick. The attributes' change signals tell the sim and the panel (start),
-- so a harness setting them directly works the same.
function DriftStyle.set(id: string)
	local style = S().styles[id]
	if not style then
		return
	end
	Players.LocalPlayer:SetAttribute(ANY_ATTRIBUTE, nil)
	Players.LocalPlayer:SetAttribute(attr(style.layout), id)
end

-- The Studio switch's label, top centre for a moment (the flames' look).
local labelToken = 0
local function showLabel(id: string)
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
	local style = S().styles[id]
	local label = (screen :: ScreenGui):FindFirstChild("Text") :: TextLabel
	label.Text = `DRIFT: {string.upper(style.name)} ({style.layout})`
	;(screen :: ScreenGui).Enabled = true
	labelToken += 1
	local mine = labelToken
	task.delay(LABEL_SECONDS, function()
		if labelToken == mine and screen then
			screen.Enabled = false
		end
	end)
end

-- O: the next style of the car's drivetrain. Shift+O: the next of all.
local function cycle(all: boolean)
	local current = DriftStyle.forCar(car)
	local list = if all then S().order else S().forLayout(DriftStyle.carLayout())
	local i = table.find(list, current) or 0
	local nextId = list[i % #list + 1]
	if all then
		Players.LocalPlayer:SetAttribute(ANY_ATTRIBUTE, nextId)
	else
		DriftStyle.set(nextId)
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
	if RunService:IsStudio() then
		UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
			if processed or input.KeyCode ~= Enum.KeyCode.O then
				return
			end
			local shift = UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) or UserInputService:IsKeyDown(Enum.KeyCode.RightShift)
			cycle(shift)
		end)
	end
end

return DriftStyle
