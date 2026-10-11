--!strict
-- The driving HUD for layout D (hud-variants, 2026-10-08), in STREET's look
-- with the machined finish (STREET D; the only HUD since 2026-10-10, when
-- the owner had the other styles removed). From the owner's notes on the
-- STREET trial: the tacho "bottom middle, remove the white and change the
-- opacity... remove the tyre monitor", "remove the 'trip' thing and move the
-- cash to the top right", then on the mockups "make odometer smaller".
--
--   Tacho   small, bottom middle, a smoked see-through face; the gear above
--           the cap, the speed below it in big italic digits.
--   Cash    top right (EXIT / RESET are left of it, LayoutD).
--   Board   the drift score, top middle, only while sliding (and a moment
--           after): points, the multiplier, the angle as a bar.
-- The art is Art.luau.
local HudLab = script.Parent
local W = require(HudLab:WaitForChild("Widgets"))
local I = require(HudLab:WaitForChild("Instruments"))
local Motion = require(HudLab:WaitForChild("Motion"))
local LayoutD = require(HudLab:WaitForChild("LayoutD"))
local Art = require(HudLab:WaitForChild("Art"))

local RED = Color3.fromRGB(255, 50, 32)
local AMBER = Color3.fromRGB(255, 176, 0)
local GREEN = Color3.fromRGB(80, 230, 120)
local WHITE = Color3.fromRGB(251, 250, 246)
local INK = Color3.fromRGB(12, 12, 13)
local DIM = Color3.fromRGB(70, 20, 16)

local NUM_ORDER = "0123456789,.x+-°"
local NUM_CELL = Vector2.new(80, 150)
local FROM, TO, MAX = -135, 135, 9000
local BAR = 18 -- angle bar segments, 5 degrees each

local SHOUT = W.font("BuilderSans", Enum.FontWeight.Heavy, true)
local LABEL = W.font("BuilderSans", Enum.FontWeight.Bold)

local StreetHud = {}

local function rect(o: GuiObject, x: number, y: number, w: number, h: number)
	o.AnchorPoint = Vector2.new(0, 0)
	o.Position = UDim2.fromScale(x, y)
	o.Size = UDim2.fromScale(w, h)
end

local function nums(parent: Instance, name: string, count: number, align: string?): I.Chars
	local c = I.chars(parent, name, { atlas = Art.num, order = NUM_ORDER, cell = NUM_CELL, cols = 8, count = count, align = align })
	c.root.ZIndex = 3
	return c
end

local function label(parent: Instance, name: string, text: string, color: Color3): TextLabel
	local t = W.text(parent, name, text, LABEL, color)
	t.ZIndex = 3
	return t
end

function StreetHud.build(gui: ScreenGui, touch: boolean): any
	gui.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets
	local root = W.frame(gui, "StreetHud")
	root.Size = UDim2.fromScale(1, 1)
	-- The edge glow fills the whole screen, notch and all: inside the
	-- safe area it stopped in hard lines short of the sides (the owner,
	-- 2026-10-08: "again with the boundries, whats going on? its cut off").
	local glowGui = Instance.new("ScreenGui")
	glowGui.Name = "HajwalaHudLabGlow"
	glowGui.ResetOnSpawn = false
	glowGui.IgnoreGuiInset = true
	glowGui.ScreenInsets = Enum.ScreenInsets.None
	glowGui.DisplayOrder = gui.DisplayOrder - 1
	glowGui.Parent = gui.Parent
	local glow = W.edgeGlow(glowGui)
	local right = LayoutD.corner(root, "Right", true)
	local ex = LayoutD.EDGE_X

	-- The tacho, bottom middle.
	local size = if touch then 0.237 else 0.3
	local tacho = I.dial(root, "Tacho", {
		face = Art.tachoFace,
		needle = Art.tachoNeedle,
		glass = Art.tachoGlass,
		fromDeg = FROM,
		toDeg = TO,
		max = MAX,
		jitterAbove = 6650,
	})
	W.square(tacho.root, size)
	tacho.root.AnchorPoint = Vector2.new(0.5, 1)
	tacho.root.Position = UDim2.new(0.5, 0, 1 - LayoutD.EDGE_B, 0)
	local gear = I.chars(tacho.under, "Gear", { atlas = Art.gear, order = "123456RN", cell = Vector2.new(112, 160), cols = 8, count = 1 })
	rect(gear.root, 0.43, 0.2, 0.14, 0.2)
	local speed = nums(tacho.under, "Speed", 3)
	rect(speed.root, 0.29, 0.56, 0.42, 0.24)
	local kmh = label(tacho.under, "Kmh", "km/h", Color3.fromRGB(200, 200, 205))
	rect(kmh, 0.38, 0.79, 0.24, 0.08)
	local gearScale = Instance.new("UIScale")
	gearScale.Parent = gear.root
	local gearPop = Motion.spring(1, 6, 0.4)
	local lastGear = 0

	-- Cash, top right.
	local pill = W.image(right, "Cash", Art.pill)
	pill.ScaleType = Enum.ScaleType.Slice
	pill.SliceCenter = Rect.new(40, 30, 260, 82)
	pill.AnchorPoint = Vector2.new(1, 0)
	pill.Position = UDim2.fromScale(1 - ex, LayoutD.CASH_Y)
	pill.Size = UDim2.fromScale(LayoutD.CASH_W, LayoutD.CASH_H)
	local cashLabel = label(pill, "Label", "CASH", Color3.fromRGB(170, 170, 176))
	rect(cashLabel, 0.04, 0.3, 0.13, 0.36)
	local cash = nums(pill, "Value", 9, "left")
	rect(cash.root, 0.17, 0.14, 0.52, 0.68)
	local best = label(pill, "Best", "", Color3.fromRGB(170, 170, 176))
	rect(best, 0.68, 0.32, 0.28, 0.34)
	best.TextXAlignment = Enum.TextXAlignment.Right
	local cashScale = Instance.new("UIScale")
	cashScale.Parent = pill

	-- The drift board, top middle (660x170 art).
	local board = W.image(root, "Board", Art.board)
	W.box(board, 0.611, 0.157)
	board.AnchorPoint = Vector2.new(0.5, 0)
	board.Position = UDim2.new(0.5, 0, 0.18, 0)
	local points = nums(board, "Points", 7)
	points.tint(RED)
	rect(points.root, 0.05, 0.08, 0.5, 0.6)
	local mult = nums(board, "Mult", 4)
	mult.tint(AMBER)
	rect(mult.root, 0.62, 0.14, 0.33, 0.46)
	local info = label(board, "Info", "", RED)
	rect(info, 0.06, 0.66, 0.36, 0.2)
	info.TextXAlignment = Enum.TextXAlignment.Left
	local bar: { Frame } = {}
	for i = 1, BAR do
		local f = W.frame(board, "Bar" .. i, DIM, 0)
		rect(f, 0.44 + (i - 1) * 0.5 / BAR, 0.68, 0.5 / BAR - 0.006, 0.15)
		f.ZIndex = 3
		W.corner(f, UDim.new(0.25, 0))
		table.insert(bar, f)
	end
	local boardScale = Instance.new("UIScale")
	boardScale.Parent = board

	local shout = W.shout(root, "Shout", {
		font = SHOUT,
		color = WHITE,
		stroke = INK,
		strokeThickness = 5,
		subFont = LABEL,
		subColor = RED,
		tilt = -6,
	})
	W.box(shout.root, 0.56, 0.2)
	W.at(shout.root, 0.5, 0.46)

	local roller = Motion.roller()
	local cashRoller = Motion.roller()
	cashRoller.shown = -1
	local cashPop = Motion.spring(1, 5, 0.35)
	local boardPop = Motion.spring(1, 4, 0.45)
	local glowAmt = Motion.spring(0, 2, 1)
	local held, heldUntil = 0, 0
	local message, messageUntil, messageColor = "", 0, RED
	local pointsTint = RED
	local flash, flashUntil = RED, 0
	local clock = 0

	local function update(v: any, dt: number)
		clock += dt
		local now = os.clock()
		tacho.set(v.rpm)
		tacho.update(dt)
		gear.set(if v.gear == -1 then "R" elseif v.gear == 0 then "N" else tostring(v.gear))
		if v.gear ~= lastGear then
			lastGear = v.gear
			Motion.kick(gearPop, 7)
		end
		gearScale.Scale = Motion.step(gearPop, 1, dt)
		speed.set(tostring(math.clamp(math.floor(v.speed + 0.5), 0, 999)))

		pill.SliceScale = math.max(pill.AbsoluteSize.Y, 1) / 120
		if cashRoller.shown < 0 then
			cashRoller.shown = v.cash
		end
		cash.set(Motion.comma(Motion.roll(cashRoller, v.cash, dt, 4)))
		cashScale.Scale = Motion.step(cashPop, 1, dt)
		best.Text = if v.serverBest > 0 and (clock % 6) > 3 then `SERVER {Motion.comma(v.serverBest)}` else `BEST {Motion.comma(v.best)}`

		local live = v.sliding
		if live then
			held, heldUntil = v.points, now + 1.4
			pointsTint = RED
		end
		local showing = live or now < heldUntil or now < messageUntil
		board.Visible = showing
		if showing then
			local p = Motion.roll(roller, if live then v.points else held, dt, 9)
			points.set(if p > 0 then Motion.comma(p) else "0")
			points.tint(pointsTint)
			mult.set(if live and v.mult > 1 then (if v.mult % 1 == 0 then string.format("x%d", v.mult) else string.format("x%.1f", v.mult)) else "")
			local deg = math.floor(math.abs(v.angle) + 0.5)
			if now < messageUntil then
				info.Text = message
				info.TextColor3 = messageColor
			else
				info.Text = `ANGLE {math.min(deg, 999)}°`
				info.TextColor3 = RED
			end
			local heat = math.clamp((v.mult - 1) / math.max(v.multMax - 1, 1), 0, 1)
			local on = RED:Lerp(AMBER, heat)
			for i, f in bar do
				f.BackgroundColor3 = if live and deg >= i * 5 - 2.5 then on else DIM
			end
		end
		boardScale.Scale = Motion.step(boardPop, 1, dt)

		local heat = math.clamp((v.mult - 1) / math.max(v.multMax - 1, 1), 0, 1)
		local want = if live then 0.05 + 0.18 * heat else 0
		local g = Motion.step(glowAmt, want, dt)
		glow.set(if now < flashUntil then flash else RED, if now < flashUntil then 0.3 else g)
		shout.update(dt)
	end

	local function event(kind: string, a: number, b: number)
		local now = os.clock()
		if kind == "mult" then
			Motion.kick(boardPop, 3)
		elseif kind == "spin" then
			shout.fire("طارت!", `{if b > 1 then b * 360 else 360}  +{Motion.comma(a)}`)
			Motion.kick(boardPop, 5)
		elseif kind == "natl" then
			shout.fire("نطل!", "TWO WHEELS")
		elseif kind == "chain" then
			shout.fire("هجولة!", string.format("x%.1f CHAIN", a))
		elseif kind == "banked" then
			held, heldUntil = a, now + 1.6
			pointsTint = GREEN
			message, messageUntil, messageColor = `BANKED +{Motion.comma(b)}`, now + 1.6, GREEN
			flash, flashUntil = GREEN, now + 0.3
			Motion.kick(boardPop, 5)
			if b > 0 then
				Motion.kick(cashPop, 8)
			end
		elseif kind == "dropped" then
			held, heldUntil = 0, 0
			message, messageUntil, messageColor = "DROPPED", now + 1.2, RED
			flash, flashUntil = RED, now + 0.4
		end
	end

	return {
		update = update,
		event = event,
		destroy = function()
			root:Destroy()
			glowGui:Destroy()
		end,
	}
end

return StreetHud
