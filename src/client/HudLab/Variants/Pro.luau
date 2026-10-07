--!strict
-- PRO: after CarX Drift Racing 2 (hud-variants, 2026-10-07). A needle tacho
-- top right with the speed and a gear box in it, the drift score top centre
-- with its multiplier and chain bar, a drift-angle scale along the bottom.
-- Phone: a steering wheel you turn, metal pedals (a wide brake, a tall gas),
-- a handbrake lever you pull, NATL by the wheel. Graphite, white, sodium.
local GuiService = game:GetService("GuiService")

local HudLab = script.Parent.Parent
local W = require(HudLab:WaitForChild("Widgets"))
local Motion = require(HudLab:WaitForChild("Motion"))

local INK = Color3.fromRGB(16, 17, 19)
local GRAPHITE = Color3.fromRGB(34, 36, 40)
local WHITE = Color3.fromRGB(240, 240, 236)
local SOFT = Color3.fromRGB(176, 178, 182)
local SODIUM = Color3.fromRGB(255, 186, 92)
local RED = Color3.fromRGB(240, 70, 58)
local GREEN = Color3.fromRGB(92, 203, 138)

local NUM = W.font("Oswald", Enum.FontWeight.Bold)
local NUM_SEMI = W.font("Oswald", Enum.FontWeight.SemiBold)
local TAG = W.font("Michroma", Enum.FontWeight.Regular)
local SHOUT = W.font("BuilderSans", Enum.FontWeight.Heavy)

local Pro = {}
Pro.id = "pro"
Pro.name = "PRO"

local function inset(): number
	return GuiService:GetGuiInset().Y
end

function Pro.buildHud(gui: ScreenGui, touch: boolean, _api: any): any
	local root = W.frame(gui, "Pro")
	root.Size = UDim2.fromScale(1, 1)
	local glow = W.edgeGlow(root)
	local top = inset()

	-- Tacho.
	local tachoSize = if touch then 0.34 else 0.3
	local tachoBox = W.frame(root, "Tacho", INK, 0.35)
	W.square(tachoBox, tachoSize)
	tachoBox.AnchorPoint = Vector2.new(1, 0)
	tachoBox.Position = if touch then UDim2.new(0.86, 0, 0, top + 4) else UDim2.new(1, -24, 0, top + 12)
	W.corner(tachoBox)
	W.stroke(tachoBox, WHITE, 1.5, 0.75)
	local tacho = W.tacho(tachoBox, "Gauge", {
		fromDeg = -135,
		toDeg = 100,
		majors = 8,
		minors = 4,
		tick = WHITE,
		red = RED,
		tickWidth = 2,
		majorLen = 0.08,
		minorLen = 0.04,
		radius = 0.45,
		numerals = NUM_SEMI,
		numeralColor = WHITE,
		needle = WHITE,
		needleWidth = 3,
		needleLen = 0.43,
		hub = SODIUM,
	})
	tacho.root.Size = UDim2.fromScale(1, 1)
	local speed = W.text(tachoBox, "Speed", "0", NUM, WHITE)
	speed.AnchorPoint = Vector2.new(1, 0.5)
	speed.Position = UDim2.fromScale(0.62, 0.66)
	speed.Size = UDim2.fromScale(0.42, 0.22)
	speed.TextXAlignment = Enum.TextXAlignment.Right
	local unit = W.text(tachoBox, "Unit", "KM/H", TAG, SOFT)
	unit.AnchorPoint = Vector2.new(1, 0)
	unit.Position = UDim2.fromScale(0.62, 0.78)
	unit.Size = UDim2.fromScale(0.3, 0.06)
	unit.TextXAlignment = Enum.TextXAlignment.Right
	local gearBox = W.frame(tachoBox, "Gear", SODIUM, 0)
	gearBox.AnchorPoint = Vector2.new(0, 0.5)
	gearBox.Position = UDim2.fromScale(0.66, 0.7)
	gearBox.Size = UDim2.fromScale(0.17, 0.24)
	W.corner(gearBox, UDim.new(0.18, 0))
	local gear = W.text(gearBox, "N", "1", NUM, INK)
	W.at(gear, 0.5, 0.52)
	gear.Size = UDim2.fromScale(0.8, 0.8)
	local rpmTag = W.text(tachoBox, "Rpm", "x1000 RPM", TAG, SOFT)
	W.at(rpmTag, 0.5, 0.36)
	rpmTag.Size = UDim2.fromScale(0.42, 0.05)

	-- Score.
	local scoreBox = W.frame(root, "Score")
	W.box(scoreBox, if touch then 0.5 else 0.56, if touch then 0.19 else 0.2)
	scoreBox.AnchorPoint = Vector2.new(0.5, 0)
	scoreBox.Position = UDim2.new(0.5, 0, 0, top + (if touch then 2 else 10))
	local scoreScale = Instance.new("UIScale")
	scoreScale.Parent = scoreBox
	local tag = W.text(scoreBox, "Tag", "DRIFT", TAG, SODIUM)
	tag.Position = UDim2.fromScale(0, 0)
	tag.Size = UDim2.fromScale(1, 0.16)
	local points = W.text(scoreBox, "Points", "0", NUM, WHITE)
	points.Position = UDim2.fromScale(0, 0.15)
	points.Size = UDim2.fromScale(1, 0.56)
	W.stroke(points, INK, 2, 0.4)
	local mult = W.frame(scoreBox, "Mult", SODIUM, 0)
	mult.AnchorPoint = Vector2.new(0, 0.5)
	mult.Position = UDim2.fromScale(0.8, 0.44)
	mult.Size = UDim2.fromScale(0.2, 0.3)
	W.corner(mult, UDim.new(0.2, 0))
	local multText = W.text(mult, "T", "x1.0", NUM, INK)
	W.at(multText, 0.5, 0.52)
	multText.Size = UDim2.fromScale(0.84, 0.8)
	local multScale = Instance.new("UIScale")
	multScale.Parent = mult
	local barTrack = W.frame(scoreBox, "Chain", WHITE, 0.82)
	barTrack.AnchorPoint = Vector2.new(0.5, 0)
	barTrack.Position = UDim2.fromScale(0.5, 0.76)
	barTrack.Size = UDim2.fromScale(0.62, 0.06)
	W.corner(barTrack)
	local bar = W.frame(barTrack, "Fill", SODIUM, 0)
	bar.Size = UDim2.fromScale(1, 1)
	W.corner(bar)
	local result = W.text(scoreBox, "Result", "", NUM, GREEN)
	result.Position = UDim2.fromScale(0, 0.84)
	result.Size = UDim2.fromScale(1, 0.18)
	W.stroke(result, INK, 1.5, 0.3)

	-- NATL: the roll and how much is left before it tips.
	local natlBox = W.frame(root, "Natl")
	W.box(natlBox, 0.36, 0.07)
	natlBox.AnchorPoint = Vector2.new(0.5, 0)
	natlBox.Position = UDim2.new(0.5, 0, if touch then 0.2 else 0.21, top + 8)
	local natlText = W.text(natlBox, "T", "", NUM_SEMI, WHITE)
	natlText.Size = UDim2.fromScale(1, 0.6)
	W.stroke(natlText, INK, 1.5, 0.3)
	local marginTrack = W.frame(natlBox, "Margin", WHITE, 0.8)
	marginTrack.Position = UDim2.fromScale(0.1, 0.72)
	marginTrack.Size = UDim2.fromScale(0.8, 0.16)
	W.corner(marginTrack)
	local marginFill = W.frame(marginTrack, "Fill", WHITE, 0)
	marginFill.Size = UDim2.fromScale(1, 1)
	W.corner(marginFill)

	-- Drift angle scale: -90..90 with ticks, a marker that springs to the
	-- angle; the band from 20 to 60 degrees lit as the sweet spot.
	local angleBox = W.frame(root, "Angle")
	W.box(angleBox, if touch then 0.5 else 0.66, if touch then 0.085 else 0.09)
	angleBox.AnchorPoint = Vector2.new(0.5, 1)
	angleBox.Position = if touch then UDim2.new(0.5, 0, 1, -8) else UDim2.new(0.5, 0, 1, -22)
	for i = -6, 6 do
		local tk = W.frame(angleBox, "Tick", WHITE, if i == 0 then 0 else 0.45)
		tk.AnchorPoint = Vector2.new(0.5, 1)
		tk.Position = UDim2.fromScale(0.5 + i / 12 * 0.96, 0.7)
		tk.Size = UDim2.new(0, 2, if i % 2 == 0 then 0.36 else 0.2, 0)
	end
	for side = -1, 1, 2 do
		local band = W.frame(angleBox, "Sweet", SODIUM, 0.55)
		band.AnchorPoint = Vector2.new(0.5, 1)
		band.Position = UDim2.fromScale(0.5 + side * (40 / 90) * 0.48, 0.74)
		band.Size = UDim2.fromScale(40 / 90 * 0.48, 0.08)
	end
	local marker = W.frame(angleBox, "Marker", SODIUM, 0)
	marker.AnchorPoint = Vector2.new(0.5, 1)
	marker.Size = UDim2.new(0, 4, 0.62, 0)
	W.corner(marker)
	local angleText = W.text(angleBox, "Deg", "0°", NUM_SEMI, WHITE)
	angleText.AnchorPoint = Vector2.new(0.5, 0)
	angleText.Position = UDim2.fromScale(0.5, 0.74)
	angleText.Size = UDim2.fromScale(0.2, 0.34)
	W.stroke(angleText, INK, 1.5, 0.3)

	-- Cash, top left (under the buttons on a phone).
	local cashBox = W.frame(root, "Cash")
	W.box(cashBox, 0.3, if touch then 0.05 else 0.06)
	cashBox.Position = if touch then UDim2.new(0, 14, 0.12, top + 12) else UDim2.new(0, 22, 0, top + 12)
	local cash = W.text(cashBox, "T", "", NUM_SEMI, WHITE)
	cash.TextXAlignment = Enum.TextXAlignment.Left
	W.stroke(cash, INK, 1.5, 0.3)
	local bestBox = W.frame(root, "Best")
	W.box(bestBox, 0.4, 0.03)
	bestBox.Position = cashBox.Position + UDim2.new(0, 0, if touch then 0.06 else 0.07, 0)
	local best = W.text(bestBox, "T", "", TAG, SOFT)
	best.TextXAlignment = Enum.TextXAlignment.Left

	local shout = W.shout(root, "Shout", {
		font = SHOUT,
		color = WHITE,
		stroke = INK,
		strokeThickness = 4,
		subFont = NUM,
		subColor = SODIUM,
		tilt = -4,
	})
	W.box(shout.root, 0.5, 0.2)
	W.at(shout.root, 0.3, 0.44)

	local roller = Motion.roller()
	local multPop = Motion.spring(1, 5, 0.4)
	local scorePop = Motion.spring(1, 4, 0.5)
	local mark = Motion.spring(0, 3.5, 0.7)
	local glowAmt = Motion.spring(0, 2, 1)
	local resultUntil = 0
	local flashColor = SODIUM
	local flashUntil = 0

	local function update(v: any, dt: number)
		tacho.set(v.rpm, v.redline)
		tacho.update(dt)
		speed.Text = tostring(math.floor(v.speed + 0.5))
		gear.Text = if v.gear == -1 then "R" else tostring(v.gear)

		local live = v.sliding
		local now = os.clock()
		points.Text = Motion.comma(Motion.roll(roller, if live then v.points else roller.shown, dt, 9))
		scoreBox.Visible = live or now < resultUntil
		mult.Visible = live and v.mult > 1
		multText.Text = string.format("x%.1f", v.mult)
		multScale.Scale = Motion.step(multPop, 1, dt)
		scoreScale.Scale = Motion.step(scorePop, 1, dt)
		barTrack.Visible = live
		bar.Size = UDim2.fromScale(v.chain, 1)
		-- The chain bar heats from sodium to white as the multiplier climbs.
		bar.BackgroundColor3 = SODIUM:Lerp(WHITE, math.clamp((v.mult - 1) / math.max(v.multMax - 1, 1), 0, 1))
		result.Visible = not live and now < resultUntil

		natlBox.Visible = v.natl
		if v.natl then
			local m = v.margin
			local word = if m < 8 then "TIP!" elseif m < 16 then "CATCH" else "HOLD"
			natlText.Text = `NATL {math.floor(math.abs(v.roll) + 0.5)}°  {word}`
			local c = if m < 8 then RED elseif m < 16 then SODIUM else WHITE
			natlText.TextColor3 = c
			marginFill.BackgroundColor3 = c
			marginFill.Size = UDim2.fromScale(math.clamp(m / 30, 0, 1), 1)
		end

		local a = math.clamp(v.angle, -90, 90)
		local x = Motion.step(mark, a, dt)
		marker.Position = UDim2.fromScale(0.5 + x / 90 * 0.48, 0.74)
		local abs = math.abs(a)
		angleText.Text = `{math.floor(abs + 0.5)}°`
		marker.BackgroundColor3 = if abs >= 20 and abs <= 60 then SODIUM else WHITE

		cash.Text = `CASH  {Motion.comma(v.cash)}`
		best.Text = if v.serverBest > 0
			then `BEST {Motion.comma(v.best)}   SERVER {Motion.comma(v.serverBest)} {v.holder}`
			else `BEST {Motion.comma(v.best)}`

		local want = if live then 0.08 + 0.22 * math.clamp((v.mult - 1) / 4, 0, 1) else 0
		local g = Motion.step(glowAmt, want, dt)
		glow.set(if now < flashUntil then flashColor else SODIUM, if now < flashUntil then 0.35 else g)
		shout.update(dt)
	end

	local function event(kind: string, a: number, b: number)
		local now = os.clock()
		if kind == "mult" then
			Motion.kick(multPop, 9)
		elseif kind == "spin" then
			shout.fire("طارت!", `{if b > 1 then b * 360 else 360}  +{Motion.comma(a)}`)
			Motion.kick(scorePop, 4)
		elseif kind == "natl" then
			shout.fire("نطل!", "TWO WHEELS")
		elseif kind == "chain" then
			shout.fire("هجولة!", string.format("x%.1f CHAIN", a))
		elseif kind == "banked" then
			result.Text = if b > 0 then `BANKED  +{Motion.comma(b)} CASH` else "BANKED"
			result.TextColor3 = GREEN
			points.Text = Motion.comma(a)
			resultUntil = now + 2
			flashColor, flashUntil = GREEN, now + 0.35
			Motion.kick(scorePop, 5)
		elseif kind == "dropped" then
			result.Text = "DROPPED"
			result.TextColor3 = RED
			resultUntil = now + 1.6
			flashColor, flashUntil = RED, now + 0.45
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

function Pro.buildControls(gui: ScreenGui, api: any): any
	local t = W.tracker()
	local root = W.frame(gui, "ProControls")
	root.Size = UDim2.fromScale(1, 1)
	local top = inset()

	local wheel = W.wheel(root, "Wheel", {
		rim = GRAPHITE,
		rimThickness = 0.09,
		rimTransparency = 0,
		spoke = Color3.fromRGB(58, 60, 66),
		hub = Color3.fromRGB(150, 152, 158),
		hubEdge = GRAPHITE,
		marker = SODIUM,
		maxDeg = 150,
	}, t, function(frac)
		api.steerRaw(frac)
	end)
	W.square(wheel.root, 0.5)
	W.at(wheel.root, 0.16, 0.7)

	local metal = {
		plate = Color3.fromRGB(214, 216, 220),
		plateLow = Color3.fromRGB(128, 132, 140),
		edge = Color3.fromRGB(70, 72, 78),
		edgeThickness = 2,
		radius = UDim.new(0.08, 0),
		slots = 5,
		slot = Color3.fromRGB(24, 25, 28),
		slotTransparency = 0.1,
		label = "",
		labelFont = TAG,
		labelColor = Color3.fromRGB(40, 42, 46),
		labelStroke = nil,
		shadow = Color3.new(0, 0, 0),
		shadowTransparency = 0.55,
		depth = 0.06,
		fill = SODIUM,
		minValue = 0.45,
	}
	local brakeSkin = table.clone(metal)
	brakeSkin.label = "BRAKE"
	brakeSkin.slots = 4
	brakeSkin.fill = RED
	brakeSkin.minValue = 0.5
	local brake = W.pedal(root, "Brake", brakeSkin, t, function(v)
		api.brake(v)
	end)
	W.box(brake.root, 0.2, 0.25)
	W.at(brake.root, 0.745, 0.8)
	local gasSkin = table.clone(metal)
	gasSkin.label = "THROTTLE"
	gasSkin.slots = 7
	local gas = W.pedal(root, "Gas", gasSkin, t, function(v)
		api.throttle(v)
	end)
	W.box(gas.root, 0.16, 0.44)
	W.at(gas.root, 0.885, 0.7)

	local lever = W.lever(root, "Hand", {
		track = INK,
		trackTransparency = 0.35,
		trackEdge = Color3.fromRGB(90, 92, 98),
		handle = Color3.fromRGB(60, 62, 68),
		handleLow = Color3.fromRGB(26, 27, 30),
		handleEdge = Color3.fromRGB(120, 122, 128),
		grip = Color3.fromRGB(150, 152, 158),
		label = "HAND",
		labelFont = TAG,
		labelColor = WHITE,
		engageAt = 0.3,
		active = SODIUM,
	}, t, function(on)
		api.handbrake(on)
	end)
	W.box(lever.root, 0.11, 0.32)
	W.at(lever.root, 0.935, 0.33)

	local small: any = {
		fill = INK,
		fillTransparency = 0.35,
		lit = SODIUM,
		edge = WHITE,
		edgeThickness = 1.5,
		radius = UDim.new(0.25, 0),
		font = TAG,
		text = WHITE,
		litText = INK,
		textStroke = nil,
	}
	local natl = W.button(root, "Natl", "NATL", small, t, function()
		api.natl()
	end)
	W.square(natl.root, 0.13)
	W.at(natl.root, 0.335, 0.6)

	local lean = W.slider(root, "Lean", {
		track = INK,
		trackTransparency = 0.35,
		edge = SODIUM,
		edgeThickness = 1.5,
		knob = SODIUM,
		knobEdge = INK,
		radius = UDim.new(0.5, 0),
		marks = SODIUM,
		markFont = TAG,
		left = "‹",
		right = "›",
	}, t, function(frac)
		api.lean(frac)
	end)
	W.box(lean.root, 0.38, 0.1)
	W.at(lean.root, 0.16, 0.36)
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
			wheel.update(dt)
			brake.update(dt)
			gas.update(dt)
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

return Pro
