--!strict
-- Driver HUD. Top centre on every platform, clear of both thumbs, sized off
-- hud.scale so it can be read at arm's length on a phone.
--
-- Four rows, and the middle two only appear when they have something to say:
--   speed, gear
--   the slide in progress: points counting up and the chain multiplier,
--     replaced for a moment by what the server banked, or by DROPPED
--   drift angle, spins, natl roll
--   cash, your session best, the server best and who holds it
--
-- The live number comes from the client's own copy of Scoring so it moves
-- with the car. The banked number comes back from the server, because that
-- is the one that was actually paid.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Types = require(Shared.Types)
local ConfigLoader = require(Shared.ConfigLoader)
local Scoring = require(Shared.Scoring)

type VehicleState = Types.VehicleState

local Hud = {}

local WHITE = Color3.new(1, 1, 1)
local MUTED = Color3.fromRGB(165, 165, 175)
local HOT = Color3.fromRGB(255, 165, 40)
local CASH = Color3.fromRGB(95, 220, 130)
local NATL = Color3.fromRGB(110, 205, 255)
local BAD = Color3.fromRGB(245, 85, 85)

local gui: ScreenGui? = nil
local scaler: UIScale? = nil
local labels: { [string]: TextLabel } = {}
local rows: { [string]: Frame } = {}
local flashText = ""
local flashColor = HOT
local flashUntil = 0
local lastUpdate = 0

local function comma(n: number): string
	local digits = tostring(math.floor(math.abs(n)))
	local out, count = "", 0
	for i = #digits, 1, -1 do
		out = digits:sub(i, i) .. out
		count += 1
		if count % 3 == 0 and i > 1 then
			out = "," .. out
		end
	end
	return (if n < 0 then "-" else "") .. out
end

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
	labels[name] = l
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
	rows[name] = f
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
	card.BackgroundTransparency = 0.35
	card.BorderSizePixel = 0
	card.AnchorPoint = Vector2.new(0.5, 0)
	card.Position = UDim2.new(0.5, 0, 0, 6)
	card.AutomaticSize = Enum.AutomaticSize.XY
	card.Size = UDim2.fromOffset(0, 0)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = card
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, 4)
	pad.PaddingBottom = UDim.new(0, 7)
	pad.PaddingLeft = UDim.new(0, 16)
	pad.PaddingRight = UDim.new(0, 16)
	pad.Parent = card
	local list = Instance.new("UIListLayout")
	list.FillDirection = Enum.FillDirection.Vertical
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = card
	local s = Instance.new("UIScale")
	s.Parent = card
	scaler = s
	card.Parent = g

	local top = row(card, "Top", 6, 1)
	text(top, "Speed", Enum.Font.GothamBlack, 34, WHITE, 1)
	local unit = text(top, "Unit", Enum.Font.Gotham, 12, MUTED, 2)
	unit.Text = "km/h"
	local gear = text(top, "Gear", Enum.Font.GothamBold, 20, HOT, 3)
	local gearPad = Instance.new("UIPadding")
	gearPad.PaddingLeft = UDim.new(0, 10)
	gearPad.Parent = gear

	-- The slide row: live points and multiplier, or the result of the last one.
	local slide = row(card, "Slide", 8, 2)
	text(slide, "Points", Enum.Font.GothamBlack, 26, HOT, 1)
	text(slide, "Mult", Enum.Font.GothamBold, 18, HOT, 2)
	text(slide, "Flash", Enum.Font.GothamBold, 20, HOT, 3)

	local bottom = row(card, "Bottom", 14, 3)
	text(bottom, "Drift", Enum.Font.GothamBold, 14, MUTED, 1)
	text(bottom, "Spins", Enum.Font.GothamBold, 14, HOT, 2)
	text(bottom, "Natl", Enum.Font.GothamBold, 14, NATL, 3)

	local records = row(card, "Records", 12, 4)
	text(records, "Cash", Enum.Font.GothamBold, 13, CASH, 1)
	text(records, "Best", Enum.Font.GothamBold, 13, MUTED, 2)
	text(records, "Server", Enum.Font.GothamBold, 13, MUTED, 3)

	g.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	gui = g
	return g
end

-- Called when the server reports what a finished slide was worth. points of
-- zero means the slide was lost rather than banked.
function Hud.flashResult(points: number, cash: number)
	local cfg = ConfigLoader.current().hud
	if points > 0 then
		flashText = if cash > 0 then `BANKED {comma(points)}  +{comma(cash)}` else `BANKED {comma(points)}`
		flashColor = CASH
	else
		flashText = "DROPPED"
		flashColor = BAD
	end
	flashUntil = os.clock() + cfg.flashSeconds
end

function Hud.update(state: VehicleState, score: Scoring.State)
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
	if scaler then
		scaler.Scale = cfg.hud.scale
	end

	labels.Speed.Text = comma(math.floor(state.speedKmh + 0.5))
	labels.Gear.Text = if state.gear == -1 then "R" else tostring(state.gear)

	-- Slide row: the live counter takes over from a flash as soon as the
	-- next slide starts, so a chain never hides behind the previous result.
	local flashing = now < flashUntil and not score.active
	labels.Points.Visible = score.active
	labels.Mult.Visible = score.active and score.multiplier > 1
	labels.Flash.Visible = flashing
	rows.Slide.Visible = score.active or flashing
	if score.active then
		labels.Points.Text = comma(score.points)
		labels.Mult.Text = string.format("x%.1f", score.multiplier)
	end
	if flashing then
		labels.Flash.Text = flashText
		labels.Flash.TextColor3 = flashColor
	end

	local angle = math.abs(state.driftAngleDeg)
	labels.Drift.Text = `DRIFT {math.floor(angle + 0.5)}°`
	labels.Drift.TextColor3 = if angle >= cfg.hud.driftHighlightDeg then HOT else MUTED
	labels.Spins.Visible = state.spinCount > 0 or state.spinProgressDeg > 90
	labels.Spins.Text = `SPINS {state.spinCount}`
	local up = state.twoWheelMode == "lifting" or state.twoWheelMode == "balanced"
	labels.Natl.Visible = up
	labels.Natl.Text = `NATL {math.floor(math.abs(state.rollDeg) + 0.5)}°`

	-- Cash and the records replicate as attributes, so there is nothing to
	-- ask for here and nothing a client can write back.
	local player = Players.LocalPlayer
	labels.Cash.Text = `CASH {comma(tonumber(player:GetAttribute("Cash")) or 0)}`
	labels.Best.Text = `BEST {comma(tonumber(player:GetAttribute("SessionBest")) or 0)}`
	local records = ReplicatedStorage:FindFirstChild("Records")
	local serverBest = if records then tonumber(records:GetAttribute("BestScore")) or 0 else 0
	local holder = if records then tostring(records:GetAttribute("BestHolder") or "") else ""
	labels.Server.Visible = serverBest > 0
	labels.Server.Text = if holder ~= "" then `SERVER {comma(serverBest)} {holder}` else `SERVER {comma(serverBest)}`
end

function Hud.hide()
	if gui then
		gui.Enabled = false
	end
end

return Hud
