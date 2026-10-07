--!strict
-- ARCADE: after Driving Empire (hud-variants, 2026-10-07). Chunky rounded
-- type with thick dark outlines, an LED speed arc bottom right, a big yellow
-- score with a multiplier badge that spins and pops, a fat chain bar that runs
-- yellow to orange to red, a cash pill bottom left that the banked cash
-- flies into. Phone: big coloured pedals, a thumb pad, an orange lever.
local GuiService = game:GetService("GuiService")
local TweenService = game:GetService("TweenService")

local HudLab = script.Parent.Parent
local W = require(HudLab:WaitForChild("Widgets"))
local Motion = require(HudLab:WaitForChild("Motion"))

local OUT = Color3.fromRGB(15, 20, 24)
local PANEL = Color3.fromRGB(28, 35, 42)
local WHITE = Color3.fromRGB(251, 251, 247)
local YELLOW = Color3.fromRGB(255, 210, 63)
local ORANGE = Color3.fromRGB(255, 159, 28)
local RED = Color3.fromRGB(255, 77, 77)
local CYAN = Color3.fromRGB(46, 230, 255)
local GREEN = Color3.fromRGB(61, 220, 110)
local OFF = Color3.fromRGB(58, 68, 77)

local FAT = W.font("FredokaOne", Enum.FontWeight.Regular)
local SHOUT = W.font("LuckiestGuy", Enum.FontWeight.Regular)
local ARABIC = W.font("BuilderSans", Enum.FontWeight.Heavy)

local Arcade = {}
Arcade.id = "arcade"
Arcade.name = "ARCADE"

local function inset(): number
	return GuiService:GetGuiInset().Y
end

local function outlined(parent: Instance, name: string, text: string, color: Color3, thick: number): TextLabel
	local t = W.text(parent, name, text, FAT, color)
	W.stroke(t, OUT, thick)
	return t
end

local function pill(parent: Instance, name: string): Frame
	local f = W.frame(parent, name, PANEL, 0.12)
	W.corner(f)
	W.stroke(f, OUT, 3)
	return f
end

function Arcade.buildHud(gui: ScreenGui, touch: boolean, _api: any): any
	local root = W.frame(gui, "Arcade")
	root.Size = UDim2.fromScale(1, 1)
	local glow = W.edgeGlow(root)
	local top = inset()

	-- Speed: LED arc, the number, a gear pill.
	local size = if touch then 0.3 else 0.36
	local gauge = W.frame(root, "Speed", PANEL, 0.25)
	W.square(gauge, size)
	gauge.AnchorPoint = if touch then Vector2.new(0.5, 0) else Vector2.new(1, 1)
	gauge.Position = if touch then UDim2.new(0.72, 0, 0, top + 4) else UDim2.new(1, -26, 1, -20)
	W.corner(gauge)
	W.stroke(gauge, OUT, 3)
	local tacho = W.tacho(gauge, "Leds", {
		fromDeg = -125,
		toDeg = 125,
		majors = 8,
		minors = 1,
		tick = OFF,
		red = RED,
		tickWidth = 2,
		majorLen = 0.1,
		minorLen = 0.1,
		radius = 0.44,
		numerals = nil,
		numeralColor = WHITE,
		needle = WHITE,
		needleWidth = 2,
		needleLen = 0.4,
		hub = WHITE,
		leds = 30,
		ledOn = CYAN,
		ledOff = OFF,
		ledRed = RED,
	})
	tacho.root.Size = UDim2.fromScale(1, 1)
	local speed = outlined(gauge, "Number", "0", WHITE, 3)
	W.at(speed, 0.5, 0.5)
	speed.Size = UDim2.fromScale(0.62, 0.3)
	local gearPill = pill(gauge, "Gear")
	W.at(gearPill, 0.5, 0.78)
	gearPill.Size = UDim2.fromScale(0.42, 0.14)
	local gear = W.text(gearPill, "T", "1 GEAR", FAT, WHITE)
	W.at(gear, 0.5, 0.5)
	gear.Size = UDim2.fromScale(0.8, 0.7)

	-- Score, the badge, the chain bar.
	local scoreBox = W.frame(root, "Score")
	W.box(scoreBox, if touch then 0.6 else 0.7, 0.22)
	scoreBox.AnchorPoint = Vector2.new(0.5, 0)
	scoreBox.Position = UDim2.new(if touch then 0.42 else 0.5, 0, 0, top + 4)
	local scoreScale = Instance.new("UIScale")
	scoreScale.Parent = scoreBox
	local points = outlined(scoreBox, "Points", "0", YELLOW, 4)
	points.Size = UDim2.fromScale(0.72, 0.62)
	points.Position = UDim2.fromScale(0.08, 0)
	local badge = W.frame(scoreBox, "Badge", ORANGE, 0)
	badge.SizeConstraint = Enum.SizeConstraint.RelativeYY
	badge.Size = UDim2.fromScale(0.58, 0.58)
	badge.AnchorPoint = Vector2.new(0.5, 0.5)
	badge.Position = UDim2.fromScale(0.84, 0.32)
	W.corner(badge, UDim.new(0.3, 0))
	W.stroke(badge, OUT, 3)
	local badgeScale = Instance.new("UIScale")
	badgeScale.Parent = badge
	local badgeText = outlined(badge, "T", "x1", WHITE, 2.5)
	W.at(badgeText, 0.5, 0.5)
	badgeText.Size = UDim2.fromScale(0.8, 0.6)
	local barTrack = W.frame(scoreBox, "Chain", PANEL, 0.1)
	barTrack.AnchorPoint = Vector2.new(0.5, 0)
	barTrack.Position = UDim2.fromScale(0.5, 0.66)
	barTrack.Size = UDim2.fromScale(0.62, 0.14)
	W.corner(barTrack)
	W.stroke(barTrack, OUT, 3)
	local bar = W.frame(barTrack, "Fill", YELLOW, 0)
	bar.Size = UDim2.fromScale(1, 1)
	W.corner(bar)
	local angleChip = pill(scoreBox, "Angle")
	angleChip.AnchorPoint = Vector2.new(0.5, 0)
	angleChip.Position = UDim2.fromScale(0.5, 0.84)
	angleChip.Size = UDim2.fromScale(0.26, 0.16)
	local angleText = W.text(angleChip, "T", "DRIFT 0°", FAT, WHITE)
	W.at(angleText, 0.5, 0.5)
	angleText.Size = UDim2.fromScale(0.86, 0.72)

	-- Cash pill bottom left (top left on a phone, clear of the pad).
	local cashPill = pill(root, "Cash")
	W.box(cashPill, 0.34, 0.085)
	cashPill.AnchorPoint = if touch then Vector2.new(0, 0) else Vector2.new(0, 1)
	cashPill.Position = if touch then UDim2.new(0, 14, 0.12, top + 12) else UDim2.new(0, 22, 1, -22)
	local coin = W.frame(cashPill, "Coin", YELLOW, 0)
	coin.SizeConstraint = Enum.SizeConstraint.RelativeYY
	coin.Size = UDim2.fromScale(0.62, 0.62)
	coin.AnchorPoint = Vector2.new(0, 0.5)
	coin.Position = UDim2.fromScale(0.05, 0.5)
	W.corner(coin)
	W.stroke(coin, OUT, 2.5)
	local cashText = outlined(cashPill, "T", "0", WHITE, 2)
	cashText.AnchorPoint = Vector2.new(0, 0.5)
	cashText.Position = UDim2.fromScale(0.3, 0.5)
	cashText.Size = UDim2.fromScale(0.64, 0.6)
	cashText.TextXAlignment = Enum.TextXAlignment.Left
	local cashScale = Instance.new("UIScale")
	cashScale.Parent = cashPill
	local bestPill = pill(root, "Best")
	W.box(bestPill, 0.3, 0.055)
	bestPill.AnchorPoint = cashPill.AnchorPoint
	bestPill.Position = cashPill.Position + (if touch then UDim2.new(0, 0, 0.1, 0) else UDim2.new(0, 0, -0.1, 0))
	local bestText = W.text(bestPill, "T", "", FAT, WHITE)
	W.at(bestText, 0.5, 0.5)
	bestText.Size = UDim2.fromScale(0.86, 0.66)

	-- NATL badge and margin.
	local natlBox = W.frame(root, "Natl")
	W.box(natlBox, 0.34, 0.12)
	natlBox.AnchorPoint = Vector2.new(0.5, 0)
	natlBox.Position = UDim2.new(if touch then 0.42 else 0.5, 0, 0.24, top)
	local natlPill = W.frame(natlBox, "Pill", CYAN, 0)
	natlPill.Size = UDim2.fromScale(1, 0.6)
	W.corner(natlPill)
	W.stroke(natlPill, OUT, 3)
	local natlText = outlined(natlPill, "T", "", WHITE, 2.5)
	W.at(natlText, 0.5, 0.5)
	natlText.Size = UDim2.fromScale(0.86, 0.7)
	local marginTrack = W.frame(natlBox, "Margin", PANEL, 0.1)
	marginTrack.Position = UDim2.fromScale(0.1, 0.7)
	marginTrack.Size = UDim2.fromScale(0.8, 0.22)
	W.corner(marginTrack)
	W.stroke(marginTrack, OUT, 2.5)
	local marginFill = W.frame(marginTrack, "Fill", GREEN, 0)
	marginFill.Size = UDim2.fromScale(1, 1)
	W.corner(marginFill)

	local shout = W.shout(root, "Shout", {
		font = ARABIC,
		color = YELLOW,
		stroke = OUT,
		strokeThickness = 5,
		subFont = SHOUT,
		subColor = WHITE,
		tilt = -6,
	})
	W.box(shout.root, 0.56, 0.22)
	W.at(shout.root, if touch then 0.42 else 0.32, 0.48)

	local roller = Motion.roller()
	local cashRoller = Motion.roller()
	local badgePop = Motion.spring(1, 5, 0.35)
	local scorePop = Motion.spring(1, 4, 0.45)
	local cashPop = Motion.spring(1, 5, 0.35)
	local glowAmt = Motion.spring(0, 2, 1)
	local spin = 0
	local showUntil = 0
	local flash = YELLOW
	local flashUntil = 0
	cashRoller.shown = -1

	-- Banked cash flies from the score into the cash pill.
	local function fly(amount: number)
		local coinText = outlined(root, "Fly", `+{Motion.comma(amount)}`, YELLOW, 3)
		W.box(coinText, 0.3, 0.08)
		coinText.AnchorPoint = Vector2.new(0.5, 0.5)
		local from = scoreBox.AbsolutePosition + scoreBox.AbsoluteSize / 2
		local to = cashPill.AbsolutePosition + cashPill.AbsoluteSize / 2
		coinText.Position = UDim2.fromOffset(from.X, from.Y)
		local tw = TweenService:Create(coinText, TweenInfo.new(0.75, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			Position = UDim2.fromOffset(to.X, to.Y),
		})
		tw.Completed:Once(function()
			coinText:Destroy()
			Motion.kick(cashPop, 8)
		end)
		tw:Play()
	end

	local function update(v: any, dt: number)
		tacho.set(v.rpm, v.redline)
		tacho.update(dt)
		speed.Text = tostring(math.floor(v.speed + 0.5))
		gear.Text = if v.gear == -1 then "R GEAR" else `{v.gear} GEAR`

		local now = os.clock()
		local live = v.sliding
		scoreBox.Visible = live or now < showUntil
		points.Text = Motion.comma(Motion.roll(roller, if live then v.points else roller.shown, dt, 9))
		badge.Visible = live and v.mult > 1
		badgeText.Text = if v.mult % 1 == 0 then string.format("x%d", v.mult) else string.format("x%.1f", v.mult)
		spin += dt * (20 + 30 * v.mult)
		badge.Rotation = math.sin(spin * 0.05) * 8
		badgeScale.Scale = Motion.step(badgePop, 1, dt)
		scoreScale.Scale = Motion.step(scorePop, 1, dt)
		barTrack.Visible = live
		bar.Size = UDim2.fromScale(v.chain, 1)
		local heat = math.clamp((v.mult - 1) / math.max(v.multMax - 1, 1), 0, 1)
		bar.BackgroundColor3 = if heat < 0.5 then YELLOW:Lerp(ORANGE, heat * 2) else ORANGE:Lerp(RED, (heat - 0.5) * 2)
		angleChip.Visible = live
		angleText.Text = `DRIFT {math.floor(math.abs(v.angle) + 0.5)}°`

		natlBox.Visible = v.natl
		if v.natl then
			local m = v.margin
			natlText.Text = `NATL {math.floor(math.abs(v.roll) + 0.5)}°`
			natlPill.BackgroundColor3 = if m < 8 then RED elseif m < 16 then ORANGE else CYAN
			marginFill.Size = UDim2.fromScale(math.clamp(m / 30, 0, 1), 1)
			marginFill.BackgroundColor3 = if m < 8 then RED elseif m < 16 then ORANGE else GREEN
		end

		if cashRoller.shown < 0 then
			cashRoller.shown = v.cash
		end
		cashText.Text = Motion.comma(Motion.roll(cashRoller, v.cash, dt, 4))
		cashScale.Scale = Motion.step(cashPop, 1, dt)
		bestText.Text = if v.serverBest > 0 then `BEST {Motion.comma(v.best)}  SERVER {Motion.comma(v.serverBest)}` else `BEST {Motion.comma(v.best)}`

		local want = if live then 0.08 + 0.24 * heat else 0
		local g = Motion.step(glowAmt, want, dt)
		glow.set(if now < flashUntil then flash else YELLOW, if now < flashUntil then 0.4 else g)
		shout.update(dt)
	end

	local function event(kind: string, a: number, b: number)
		local now = os.clock()
		if kind == "mult" then
			Motion.kick(badgePop, 12)
		elseif kind == "spin" then
			shout.fire("طارت!", `{if b > 1 then b * 360 else 360}!  +{Motion.comma(a)}`)
			Motion.kick(scorePop, 6)
		elseif kind == "natl" then
			shout.fire("نطل!", "TWO WHEELS!")
		elseif kind == "chain" then
			shout.fire("هجولة!", string.format("x%.1f COMBO!", a))
		elseif kind == "banked" then
			showUntil = now + 1.2
			flash, flashUntil = GREEN, now + 0.35
			Motion.kick(scorePop, 6)
			if b > 0 then
				fly(b)
			end
		elseif kind == "dropped" then
			showUntil = now + 0.8
			flash, flashUntil = RED, now + 0.45
			shout.fire("DROPPED", "")
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

function Arcade.buildControls(gui: ScreenGui, api: any): any
	local t = W.tracker()
	local root = W.frame(gui, "ArcadeControls")
	root.Size = UDim2.fromScale(1, 1)
	local top = inset()

	local pad = W.pad(root, "Steer", {
		base = PANEL,
		baseTransparency = 0.2,
		edge = OUT,
		edgeThickness = 3,
		knob = WHITE,
		knobLow = Color3.fromRGB(190, 200, 210),
		knobEdge = OUT,
		arrows = WHITE,
		arrowFont = FAT,
	}, t, function(frac)
		api.steerRaw(frac)
	end)
	W.square(pad.root, 0.42)
	W.at(pad.root, 0.15, 0.72)

	local chunky = {
		plate = GREEN,
		plateLow = Color3.fromRGB(30, 160, 70),
		edge = OUT,
		edgeThickness = 3,
		radius = UDim.new(0.2, 0),
		slots = 3,
		slot = WHITE,
		slotTransparency = 0.55,
		label = "GAS",
		labelFont = FAT,
		labelColor = WHITE,
		labelStroke = OUT,
		shadow = OUT,
		shadowTransparency = 0.2,
		depth = 0.07,
		fill = nil,
		minValue = 0.45,
	}
	local gas = W.pedal(root, "Gas", chunky, t, function(v)
		api.throttle(v)
	end)
	W.box(gas.root, 0.17, 0.42)
	W.at(gas.root, 0.885, 0.71)
	local brakeSkin = table.clone(chunky)
	brakeSkin.plate = RED
	brakeSkin.plateLow = Color3.fromRGB(190, 40, 40)
	brakeSkin.label = "BRAKE"
	brakeSkin.minValue = 0.5
	local brake = W.pedal(root, "Brake", brakeSkin, t, function(v)
		api.brake(v)
	end)
	W.box(brake.root, 0.2, 0.25)
	W.at(brake.root, 0.74, 0.8)

	local lever = W.lever(root, "Hand", {
		track = PANEL,
		trackTransparency = 0.15,
		trackEdge = OUT,
		handle = ORANGE,
		handleLow = Color3.fromRGB(220, 120, 10),
		handleEdge = OUT,
		grip = WHITE,
		label = "HAND",
		labelFont = FAT,
		labelColor = WHITE,
		engageAt = 0.3,
		active = ORANGE,
	}, t, function(on)
		api.handbrake(on)
	end)
	W.box(lever.root, 0.12, 0.32)
	W.at(lever.root, 0.935, 0.31)

	local small: any = {
		fill = PANEL,
		fillTransparency = 0.12,
		lit = CYAN,
		edge = OUT,
		edgeThickness = 3,
		radius = UDim.new(0.5, 0),
		font = FAT,
		text = WHITE,
		litText = OUT,
		textStroke = nil,
	}
	local natl = W.button(root, "Natl", "NATL", small, t, function()
		api.natl()
	end)
	W.square(natl.root, 0.15)
	W.at(natl.root, 0.33, 0.6)

	local lean = W.slider(root, "Lean", {
		track = PANEL,
		trackTransparency = 0.15,
		edge = OUT,
		edgeThickness = 3,
		knob = CYAN,
		knobEdge = OUT,
		radius = UDim.new(0.5, 0),
		marks = WHITE,
		markFont = FAT,
		left = "◀",
		right = "▶",
	}, t, function(frac)
		api.lean(frac)
	end)
	W.box(lean.root, 0.4, 0.11)
	W.at(lean.root, 0.15, 0.36)
	lean.root.Visible = false

	local row = W.frame(root, "Buttons")
	row.Position = UDim2.new(0, 12, 0, top + 6)
	-- Full screen size, so the buttons' RelativeYY sizes are of the screen.
	row.Size = UDim2.fromScale(1, 1)
	local list = Instance.new("UIListLayout")
	list.FillDirection = Enum.FillDirection.Horizontal
	list.Padding = UDim.new(0, 8)
	list.Parent = row
	local buttons = {
		W.button(row, "Exit", "EXIT", small, t, function()
			api.exit()
		end),
		W.button(row, "Reset", "RESET", small, t, function()
			api.reset()
		end),
		W.button(row, "Style", api.styleName(), small, t, function()
			api.cycle()
		end),
	}
	for _, b in buttons do
		W.box(b.root, 0.2, 0.1)
	end

	return {
		update = function(dt: number)
			pad.update(dt)
			gas.update(dt)
			brake.update(dt)
			lever.update(dt)
			natl.update(dt)
			lean.update(dt)
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

return Arcade
