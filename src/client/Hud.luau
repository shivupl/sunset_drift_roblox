--!strict
-- Driver HUD: the few numbers a player wants while driving, top-centre,
-- sized to read on a phone. Speed and gear always; the drift angle lights
-- up past hud.driftHighlightDeg; SPINS shows while a 360 is under way or
-- banked; NATL shows the roll while the car is on two wheels. Everything
-- else stays in DebugPanel.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Types = require(Shared.Types)
local ConfigLoader = require(Shared.ConfigLoader)

type VehicleState = Types.VehicleState

local Hud = {}

local WHITE = Color3.new(1, 1, 1)
local MUTED = Color3.fromRGB(170, 170, 180)
local HOT = Color3.fromRGB(255, 165, 40)
local NATL = Color3.fromRGB(110, 205, 255)

local gui: ScreenGui? = nil
local speedLabel: TextLabel? = nil
local gearLabel: TextLabel? = nil
local driftLabel: TextLabel? = nil
local spinLabel: TextLabel? = nil
local natlLabel: TextLabel? = nil
local lastUpdate = 0

local function text(parent: Instance, name: string, font: Enum.Font, size: number, color: Color3, order: number): TextLabel
	local l = Instance.new("TextLabel")
	l.Name = name
	l.BackgroundTransparency = 1
	l.Font = font
	l.TextSize = size
	l.TextColor3 = color
	l.AutomaticSize = Enum.AutomaticSize.XY
	l.Size = UDim2.fromOffset(0, 0)
	l.LayoutOrder = order
	l.Text = ""
	l.Parent = parent
	return l
end

local function row(parent: Instance, name: string, gap: number, order: number): Frame
	local f = Instance.new("Frame")
	f.Name = name
	f.BackgroundTransparency = 1
	f.AutomaticSize = Enum.AutomaticSize.XY
	f.Size = UDim2.fromOffset(0, 0)
	f.LayoutOrder = order
	local list = Instance.new("UIListLayout")
	list.FillDirection = Enum.FillDirection.Horizontal
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	list.VerticalAlignment = Enum.VerticalAlignment.Center
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Padding = UDim.new(0, gap)
	list.Parent = f
	f.Parent = parent
	return f
end

local function build(): ScreenGui
	local g = Instance.new("ScreenGui")
	g.Name = "HajwalaHud"
	g.ResetOnSpawn = false
	g.IgnoreGuiInset = false
	g.DisplayOrder = 6

	local card = Instance.new("Frame")
	card.Name = "Card"
	card.BackgroundColor3 = Color3.fromRGB(15, 15, 18)
	card.BackgroundTransparency = 0.4
	card.BorderSizePixel = 0
	card.AnchorPoint = Vector2.new(0.5, 0)
	card.Position = UDim2.new(0.5, 0, 0, 8)
	card.AutomaticSize = Enum.AutomaticSize.XY
	card.Size = UDim2.fromOffset(0, 0)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = card
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, 4)
	pad.PaddingBottom = UDim.new(0, 6)
	pad.PaddingLeft = UDim.new(0, 14)
	pad.PaddingRight = UDim.new(0, 14)
	pad.Parent = card
	local list = Instance.new("UIListLayout")
	list.FillDirection = Enum.FillDirection.Vertical
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Padding = UDim.new(0, 0)
	list.Parent = card
	card.Parent = g

	local top = row(card, "Top", 6, 1)
	speedLabel = text(top, "Speed", Enum.Font.GothamBlack, 36, WHITE, 1)
	local unit = text(top, "Unit", Enum.Font.Gotham, 12, MUTED, 2)
	unit.Text = "km/h"
	gearLabel = text(top, "Gear", Enum.Font.GothamBold, 22, HOT, 3)
	local gearPad = Instance.new("UIPadding")
	gearPad.PaddingLeft = UDim.new(0, 10)
	gearPad.Parent = gearLabel

	local bottom = row(card, "Bottom", 14, 2)
	driftLabel = text(bottom, "Drift", Enum.Font.GothamBold, 14, MUTED, 1)
	spinLabel = text(bottom, "Spins", Enum.Font.GothamBold, 14, HOT, 2)
	natlLabel = text(bottom, "Natl", Enum.Font.GothamBold, 14, NATL, 3)

	g.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	gui = g
	return g
end

function Hud.update(state: VehicleState)
	local cfg = ConfigLoader.current()
	if not cfg.hud.enabled then
		Hud.hide()
		return
	end
	local now = os.clock()
	if now - lastUpdate < 1 / 30 then
		return
	end
	lastUpdate = now
	local g = gui or build()
	g.Enabled = true
	local speed, gear, drift, spins, natl = speedLabel, gearLabel, driftLabel, spinLabel, natlLabel
	if not (speed and gear and drift and spins and natl) then
		return
	end
	speed.Text = string.format("%d", math.floor(state.speedKmh + 0.5))
	gear.Text = if state.gear == -1 then "R" else tostring(state.gear)
	local angle = math.abs(state.driftAngleDeg)
	drift.Text = string.format("DRIFT %d°", math.floor(angle + 0.5))
	drift.TextColor3 = if angle >= cfg.hud.driftHighlightDeg then HOT else MUTED
	spins.Visible = state.spinCount > 0 or state.spinProgressDeg > 90
	spins.Text = string.format("SPINS %d", state.spinCount)
	local up = state.twoWheelMode == "lifting" or state.twoWheelMode == "balanced"
	natl.Visible = up
	natl.Text = string.format("NATL %d°", math.floor(math.abs(state.rollDeg) + 0.5))
end

function Hud.hide()
	if gui then
		gui.Enabled = false
	end
end

return Hud
