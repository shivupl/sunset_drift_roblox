--!strict
-- MIDNIGHT: after Midnight Racing: Tokyo (hud-variants, 2026-10-07). A thin
-- white analog tacho bottom right with a red needle, the gear in a ring and
-- a digital speed; a timing bar across the top (SCORE, CHAIN, BEST) over a
-- hairline; cyan chevrons that run toward the side the car is sliding, faster
-- as the chain grows; a horizon line that tilts with the car on two wheels.
-- Phone: glass pedals and lever, a slider to steer. White, cyan, red.
local GuiService = game:GetService("GuiService")

local HudLab = script.Parent.Parent
local W = require(HudLab:WaitForChild("Widgets"))
local Motion = require(HudLab:WaitForChild("Motion"))
local Art = require(HudLab:WaitForChild("Art")).midnight

-- The dial art's scale (art/hud/midnight/make.py): 0 rpm at -132 degrees,
-- 8000 at +112.
local TACHO_FROM, TACHO_TO, TACHO_MAX = -132, 112, 8000

local GLASS = Color3.fromRGB(7, 10, 13)
local WHITE = Color3.fromRGB(242, 244, 245)
local DIM = Color3.fromRGB(150, 160, 168)
local CYAN = Color3.fromRGB(58, 220, 242)
local RED = Color3.fromRGB(255, 62, 62)
local AMBER = Color3.fromRGB(255, 186, 92)

local DIGI = W.font("Zekton", Enum.FontWeight.Regular)
local LABEL = W.font("TitilliumWeb", Enum.FontWeight.SemiBold)
local LABEL_BOLD = W.font("TitilliumWeb", Enum.FontWeight.Bold)
local SHOUT = W.font("BuilderSans", Enum.FontWeight.Heavy)

local Midnight = {}
Midnight.id = "midnight"
Midnight.name = "MIDNIGHT"

local function inset(): number
	return GuiService:GetGuiInset().Y
end

-- A labelled field of the timing bar.
local function field(parent: Instance, name: string, label: string, order: number, width: number): (Frame, TextLabel)
	local f = W.frame(parent, name)
	W.box(f, width, 0.085)
	f.LayoutOrder = order
	local l = W.text(f, "Label", label, LABEL, DIM)
	l.Size = UDim2.fromScale(1, 0.34)
	local v = W.text(f, "Value", "", DIGI, WHITE)
	v.Position = UDim2.fromScale(0, 0.32)
	v.Size = UDim2.fromScale(1, 0.68)
	return f, v
end

function Midnight.buildHud(gui: ScreenGui, touch: boolean, _api: any): any
	local root = W.frame(gui, "Midnight")
	root.Size = UDim2.fromScale(1, 1)
	local glow = W.edgeGlow(root)
	local top = inset()

	-- Timing bar.
	-- Full screen size, so its fields' RelativeYY sizes are of the screen;
	-- on a phone it sits under the button row.
	local barY = if touch then UDim2.new(0, 0, 0.12, top + 8) else UDim2.new(0, 0, 0, top + 6)
	local barRow = W.frame(root, "Timing")
	barRow.Size = UDim2.fromScale(1, 1)
	barRow.AnchorPoint = Vector2.new(0.5, 0)
	barRow.Position = UDim2.new(0.5, 0, 0, 0) + barY
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.Padding = UDim.new(0.04, 0)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = barRow
	local _, scoreValue = field(barRow, "Score", "SCORE", 1, 0.26)
	local chainField = W.frame(barRow, "Chain")
	W.box(chainField, 0.24, 0.085)
	chainField.LayoutOrder = 2
	local chainLabel = W.text(chainField, "Label", "CHAIN", LABEL, DIM)
	chainLabel.Size = UDim2.fromScale(1, 0.34)
	local multText = W.text(chainField, "Mult", "x1.0", DIGI, CYAN)
	multText.Position = UDim2.fromScale(0, 0.32)
	multText.Size = UDim2.fromScale(0.5, 0.5)
	multText.TextXAlignment = Enum.TextXAlignment.Left
	local multScale = Instance.new("UIScale")
	multScale.Parent = multText
	local track = W.frame(chainField, "Track", WHITE, 0.82)
	track.Position = UDim2.fromScale(0.5, 0.52)
	track.Size = UDim2.fromScale(0.5, 0.1)
	local fill = W.frame(track, "Fill", CYAN, 0)
	fill.Size = UDim2.fromScale(1, 1)
	local _, bestValue = field(barRow, "Best", "BEST", 3, 0.22)
	local rule = W.frame(root, "Rule", WHITE, 0.55)
	rule.AnchorPoint = Vector2.new(0.5, 0)
	rule.Position = UDim2.new(0.5, 0, 0.09, 0) + barY
	rule.Size = UDim2.new(if touch then 0.46 else 0.6, 0, 0, 1)
	local resultText = W.text(root, "Result", "", DIGI, CYAN)
	W.box(resultText, 0.6, 0.05)
	resultText.AnchorPoint = Vector2.new(0.5, 0)
	resultText.Position = UDim2.new(0.5, 0, 0.1, 4) + barY
	resultText.Visible = false

	-- Chevrons on each side, lit toward the slide.
	local chevrons: { { l: TextLabel, side: number, i: number } } = {}
	for side = -1, 1, 2 do
		for i = 1, 5 do
			local c = W.text(root, "Chevron", if side > 0 then "›" else "‹", DIGI, CYAN)
			W.square(c, 0.09)
			c.AnchorPoint = Vector2.new(0.5, 0.5)
			c.Position = UDim2.fromScale(0.5 + side * (0.17 + i * 0.035), 0.4)
			c.TextTransparency = 1
			table.insert(chevrons, { l = c, side = side, i = i })
		end
	end

	-- Tacho.
	local size = if touch then 0.3 else 0.44
	local tachoBox = W.frame(root, "Tacho")
	W.square(tachoBox, size)
	tachoBox.AnchorPoint = if touch then Vector2.new(1, 0) else Vector2.new(1, 1)
	tachoBox.Position = if touch then UDim2.new(1, -10, 0, top + 2) else UDim2.new(1, -28, 1, -16)
	local tacho = W.tachoImage(tachoBox, "Gauge", Art.tachoFace, Art.needle, TACHO_FROM, TACHO_TO, TACHO_MAX)
	tacho.root.Size = UDim2.fromScale(1, 1)
	local ring = W.frame(tachoBox, "GearRing", GLASS, 0.3)
	ring.ZIndex = 4
	W.at(ring, 0.5, 0.5)
	ring.Size = UDim2.fromScale(0.26, 0.26)
	W.corner(ring)
	W.stroke(ring, WHITE, 1.5, 0.1)
	local gear = W.text(ring, "Gear", "1", DIGI, WHITE)
	gear.ZIndex = 4
	W.at(gear, 0.5, 0.5)
	gear.Size = UDim2.fromScale(0.62, 0.62)
	local speed = W.text(tachoBox, "Speed", "0", DIGI, WHITE)
	speed.AnchorPoint = Vector2.new(1, 0)
	speed.Position = UDim2.fromScale(0.96, 0.7)
	speed.Size = UDim2.fromScale(0.42, 0.16)
	speed.TextXAlignment = Enum.TextXAlignment.Right
	local unit = W.text(tachoBox, "Unit", "km/h", LABEL, DIM)
	unit.AnchorPoint = Vector2.new(1, 0)
	unit.Position = UDim2.fromScale(0.96, 0.86)
	unit.Size = UDim2.fromScale(0.2, 0.07)
	unit.TextXAlignment = Enum.TextXAlignment.Right

	-- Horizon for NATL: a line tilting with the roll, its ends coloured by
	-- how much is left before it tips.
	local horizon = W.frame(root, "Horizon")
	W.box(horizon, 0.5, 0.12)
	W.at(horizon, 0.5, 0.62)
	local line = W.frame(horizon, "Line", WHITE, 0)
	W.at(line, 0.5, 0.5)
	line.Size = UDim2.new(1, 0, 0, 2)
	local endL = W.frame(line, "L", CYAN, 0)
	endL.AnchorPoint = Vector2.new(0, 0.5)
	endL.Position = UDim2.fromScale(0, 0.5)
	endL.Size = UDim2.new(0.12, 0, 0, 6)
	local endR = W.frame(line, "R", CYAN, 0)
	endR.AnchorPoint = Vector2.new(1, 0.5)
	endR.Position = UDim2.fromScale(1, 0.5)
	endR.Size = UDim2.new(0.12, 0, 0, 6)
	local natlText = W.text(horizon, "T", "", DIGI, WHITE)
	natlText.AnchorPoint = Vector2.new(0.5, 0)
	natlText.Position = UDim2.fromScale(0.5, 0.62)
	natlText.Size = UDim2.fromScale(0.5, 0.36)
	horizon.Visible = false

	local cashBox = W.frame(root, "Cash")
	W.box(cashBox, 0.36, 0.05)
	cashBox.Position = if touch then UDim2.new(0, 14, 0.12, top + 12) else UDim2.new(0, 22, 0, top + 12)
	local cash = W.text(cashBox, "T", "", DIGI, WHITE)
	cash.TextXAlignment = Enum.TextXAlignment.Left

	local shout = W.shout(root, "Shout", {
		font = SHOUT,
		color = WHITE,
		stroke = CYAN,
		strokeThickness = 2,
		subFont = DIGI,
		subColor = CYAN,
		tilt = 0,
	})
	W.box(shout.root, 0.5, 0.18)
	W.at(shout.root, 0.5, 0.3)

	local roller = Motion.roller()
	local multPop = Motion.spring(1, 5, 0.4)
	local tilt = Motion.spring(0, 3, 0.6)
	local glowAmt = Motion.spring(0, 2, 1)
	local wave = 0
	local resultUntil = 0
	local flash = CYAN
	local flashUntil = 0

	local function update(v: any, dt: number)
		tacho.set(v.rpm, v.redline)
		tacho.update(dt)
		speed.Text = tostring(math.floor(v.speed + 0.5))
		gear.Text = if v.gear == -1 then "R" else tostring(v.gear)

		local now = os.clock()
		local live = v.sliding
		scoreValue.Text = Motion.comma(Motion.roll(roller, if live then v.points else roller.shown, dt, 9))
		scoreValue.TextColor3 = if live then WHITE else DIM
		multText.Text = string.format("x%.1f", v.mult)
		multText.TextColor3 = if live then CYAN else DIM
		multScale.Scale = Motion.step(multPop, 1, dt)
		fill.Size = UDim2.fromScale(if live then v.chain else 0, 1)
		bestValue.Text = Motion.comma(math.max(v.best, 0))
		resultText.Visible = now < resultUntil

		-- Chevrons: a wave running outward on the slide's side.
		wave += dt * (3 + 2.5 * v.mult)
		local side = if v.angle >= 0 then 1 else -1
		for _, c in chevrons do
			local on = live and c.side == side and math.abs(v.angle) > 8
			local phase = (wave - c.i * 0.9) % 5
			local lit = if on then math.clamp(1 - math.abs(phase - 1) / 1.6, 0, 1) else 0
			c.l.TextTransparency = 1 - (0.15 + 0.85 * lit) * (if on then 1 else 0)
		end

		horizon.Visible = v.natl
		if v.natl then
			line.Rotation = Motion.step(tilt, -v.roll, dt)
			local m = v.margin
			local c = if m < 8 then RED elseif m < 16 then AMBER else CYAN
			endL.BackgroundColor3, endR.BackgroundColor3 = c, c
			natlText.Text = `NATL {math.floor(math.abs(v.roll) + 0.5)}°`
			natlText.TextColor3 = c
		end

		cash.Text = `CASH {Motion.comma(v.cash)}`

		local want = if live then 0.06 + 0.2 * math.clamp((v.mult - 1) / 4, 0, 1) else 0
		local g = Motion.step(glowAmt, want, dt)
		glow.set(if now < flashUntil then flash else CYAN, if now < flashUntil then 0.32 else g)
		shout.update(dt)
	end

	local function event(kind: string, a: number, b: number)
		local now = os.clock()
		if kind == "mult" then
			Motion.kick(multPop, 10)
		elseif kind == "spin" then
			shout.fire("طارت!", `{if b > 1 then b * 360 else 360} +{Motion.comma(a)}`)
		elseif kind == "natl" then
			shout.fire("نطل!", "TWO WHEELS")
		elseif kind == "chain" then
			shout.fire("هجولة!", string.format("x%.1f", a))
		elseif kind == "banked" then
			resultText.Text = if b > 0 then `BANKED {Motion.comma(a)}  +{Motion.comma(b)}` else `BANKED {Motion.comma(a)}`
			resultText.TextColor3 = CYAN
			resultUntil = now + 2
			flash, flashUntil = CYAN, now + 0.35
		elseif kind == "dropped" then
			resultText.Text = "DROPPED"
			resultText.TextColor3 = RED
			resultUntil = now + 1.6
			flash, flashUntil = RED, now + 0.45
		end
	end

	return {
		update = update,
		event = event,
		destroy = function()
			root:Destroy()
		end,
	}
end

function Midnight.buildControls(gui: ScreenGui, api: any): any
	local t = W.tracker()
	local root = W.frame(gui, "MidnightControls")
	root.Size = UDim2.fromScale(1, 1)
	local top = inset()

	local glassPedal: W.PedalSkin = {
		plate = Color3.fromRGB(30, 38, 46),
		plateLow = GLASS,
		edge = WHITE,
		edgeThickness = 1.5,
		radius = UDim.new(0.14, 0),
		slots = 3,
		slot = WHITE,
		slotTransparency = 0.7,
		label = "",
		labelFont = LABEL_BOLD,
		labelColor = WHITE,
		labelStroke = nil,
		shadow = CYAN,
		shadowTransparency = 0.82,
		depth = 0.05,
		fill = nil,
		minValue = 0.45,
		image = Art.pedalGas,
	}
	local brakeSkin = table.clone(glassPedal)
	brakeSkin.label = "BRAKE"
	brakeSkin.minValue = 0.5
	brakeSkin.image = Art.pedalBrake
	local brake = W.pedal(root, "Brake", brakeSkin, t, function(v)
		api.brake(v)
	end)
	-- The art's own proportions: brake 560x520, gas 400x1000.
	W.box(brake.root, 0.24, 0.223)
	W.at(brake.root, 0.735, 0.81)
	local gasSkin = table.clone(glassPedal)
	gasSkin.label = "GAS"
	gasSkin.slots = 5
	local gas = W.pedal(root, "Gas", gasSkin, t, function(v)
		api.throttle(v)
	end)
	W.box(gas.root, 0.18, 0.45)
	W.at(gas.root, 0.885, 0.71)

	local lever = W.lever(root, "Hand", {
		track = GLASS,
		trackTransparency = 0.3,
		trackEdge = WHITE,
		handle = Color3.fromRGB(40, 48, 56),
		handleLow = GLASS,
		handleEdge = WHITE,
		grip = CYAN,
		label = "HAND",
		labelFont = LABEL_BOLD,
		labelColor = WHITE,
		engageAt = 0.3,
		active = CYAN,
		trackImage = Art.leverTrack,
		handleImage = Art.leverHandle,
	}, t, function(on)
		api.handbrake(on)
	end)
	W.box(lever.root, 0.11, 0.3)
	W.at(lever.root, 0.745, 0.42)

	local steer = W.slider(root, "Steer", {
		track = GLASS,
		trackTransparency = 0.35,
		edge = WHITE,
		edgeThickness = 1.5,
		knob = WHITE,
		knobEdge = CYAN,
		radius = UDim.new(0.5, 0),
		marks = CYAN,
		markFont = DIGI,
		left = "‹‹",
		right = "››",
		trackImage = Art.sliderTrack,
		knobImage = Art.sliderKnob,
	}, t, function(frac)
		api.steerRaw(frac)
	end)
	-- The track art's proportions, 900x200.
	W.box(steer.root, 0.72, 0.16)
	W.at(steer.root, 0.22, 0.85)

	local lean = W.slider(root, "Lean", {
		track = GLASS,
		trackTransparency = 0.35,
		edge = CYAN,
		edgeThickness = 1.5,
		knob = CYAN,
		knobEdge = WHITE,
		radius = UDim.new(0.5, 0),
		marks = CYAN,
		markFont = DIGI,
		left = "‹",
		right = "›",
		trackImage = Art.sliderTrack,
		knobImage = Art.sliderKnob,
	}, t, function(frac)
		api.lean(frac)
	end)
	W.box(lean.root, 0.5, 0.11)
	W.at(lean.root, 0.22, 0.66)
	lean.root.Visible = false

	local small: any = {
		fill = GLASS,
		fillTransparency = 0.3,
		lit = CYAN,
		edge = WHITE,
		edgeThickness = 1.5,
		radius = UDim.new(0.5, 0),
		font = LABEL_BOLD,
		text = WHITE,
		litText = GLASS,
		textStroke = nil,
	}
	local natlSkin: any = table.clone(small)
	natlSkin.image = Art.natlOff
	natlSkin.litImage = Art.natlOn
	-- The label is in the art.
	local natl = W.button(root, "Natl", "", natlSkin, t, function()
		api.natl()
	end)
	W.square(natl.root, 0.16)
	W.at(natl.root, 0.065, 0.5)

	local row = W.frame(root, "Buttons")
	row.Position = UDim2.new(0, 12, 0, top + 6)
	-- Full screen size, so the buttons' RelativeYY sizes are of the screen.
	row.Size = UDim2.fromScale(1, 1)
	local list = Instance.new("UIListLayout")
	list.FillDirection = Enum.FillDirection.Horizontal
	list.Padding = UDim.new(0, 8)
	list.Parent = row
	local pill: any = table.clone(small)
	pill.radius = UDim.new(0.5, 0)
	pill.image = Art.pill
	pill.slice = Rect.new(60, 56, 240, 64)
	pill.sliceHeight = 120
	local buttons = {
		W.button(row, "Exit", "EXIT", pill, t, function()
			api.exit()
		end),
		W.button(row, "Reset", "RESET", pill, t, function()
			api.reset()
		end),
		W.button(row, "Style", api.styleName(), pill, t, function()
			api.cycle()
		end),
	}
	for _, b in buttons do
		W.box(b.root, 0.2, 0.1)
	end

	return {
		update = function(dt: number)
			brake.update(dt)
			gas.update(dt)
			lever.update(dt)
			steer.update(dt)
			lean.update(dt)
			natl.update(dt)
			for _, b in buttons do
				b.update(dt)
			end
		end,
		setLean = function(visible: boolean)
			lean.root.Visible = visible
			if not visible then
				api.lean(0)
			end
		end,
		setNatl = function(on: boolean)
			natl.setLit(on)
		end,
		destroy = function()
			W.release(t)
			root:Destroy()
		end,
	}
end

return Midnight
